class_name Player
extends CharacterBody2D

const JUMP_THROUGH_PLATFORMS_LAYER: int = 9
# Slack added on top of the per-frame fall distance, so a platform is picked up on
# the frame before the feet reach it rather than exactly on contact
const FLOOR_CHECK_LOOKAHEAD_MARGIN: float = 2.0

@export var stats: PlayerStats

# abilities
var has_pogo_ability: bool = true
var has_double_jump_ability: bool = true
var has_dash_ability: bool = true

# basic jump behavior
var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var is_jump_cut: bool = false

# pogo behavior
var pogo_buffer_timer: float = 0.0
var pogo_grace_timer: float = 0.0
var _is_whiffing: bool = false # pogoing outside of pogo area

# double jump behavior
var air_jumps_used: int = 0

# dash behavior
var is_dashing: bool = false
var dash_used: bool = false

# Tracks held direction keys in press order (most recent = last).
var _direction_stack: Array[String] = []

# FloorCheck's authored cast length, used whenever the look-ahead doesn't need more
var _floor_check_reach: float = 0.0

@onready var state_machine: PlayerStateMachine = %StateMachine
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

@onready var pogo_detector: Area2D = $PogoDetector
@onready var floor_check: ShapeCast2D = %FloorCheck


func _ready() -> void:
	_floor_check_reach = floor_check.target_position.y
	state_machine.setup(self, stats)

# Clears carried-over motion and held input when the player leaves a room, so a
# run isn't resumed mid-fall or still drifting. Called by MainGame.exit_room()
func reset_physics() -> void:
	velocity = Vector2.ZERO
	coyote_timer = 0.0
	jump_buffer_timer = 0.0
	_direction_stack.clear()

# Newly-pressed direction overrides already-held opposite direction, instead of canceling out
func _unhandled_input(event: InputEvent) -> void:
	
	if event.is_action_released("left"):
		_pop_direction("left")
	elif event.is_action_released("right"):
		_pop_direction("right")
	if is_dashing:
		return

	if event.is_action_pressed("left"):
		_push_direction("left")
	elif event.is_action_pressed("right"):
		_push_direction("right")
	elif event.is_action_released("jump") and velocity.y < 0:
		is_jump_cut = true
	elif event.is_action_pressed("attack") and pogo_grace_timer <= 0.0 and not _is_whiffing:
		play_pogo_whiff()

func _physics_process(delta: float) -> void:
	_update_timers(delta)
	_apply_gravity(delta)
	update_facing()
	state_machine.physics_update(delta)
	# Runs last so the look-ahead sees the velocity move_and_slide will actually use
	_update_platform_collision(delta)
	move_and_slide()

# Ticks the coyote-time and jump-buffer windows each physics frame:
# coyote_timer resets while grounded, jump_buffer_timer resets on jump press.
# Both count down otherwise
func _update_timers(delta: float) -> void:
	if is_on_floor():
		coyote_timer = stats.coyote_time
		air_jumps_used = 0
		dash_used = false
	else:
		coyote_timer = max(coyote_timer - delta, 0.0)
		
	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = stats.jump_buffer_time

	else:
		jump_buffer_timer = max(jump_buffer_timer - delta, 0.0)
	
	var touching_pogoable := pogo_detector.has_overlapping_bodies() or pogo_detector.has_overlapping_areas()
	pogo_grace_timer = stats.pogo_grace_time if touching_pogoable else max(pogo_grace_timer - delta, 0.0)

	if Input.is_action_just_pressed("attack"):
		pogo_buffer_timer = stats.pogo_buffer_time
	else:
		pogo_buffer_timer = max(pogo_buffer_timer - delta, 0.0)
		
# Falling gravity > rising gravity, and gravity is reduced near the jump apex
# (jump_hang_threshold) for a brief "float" feeling. See PlayerStats for tuning
func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		return
	if is_dashing:
		return
	var gravity_multiplier := 1.0

	if is_jump_cut and velocity.y < 0:
		gravity_multiplier = stats.jump_cut_gravity_mult
	elif abs(velocity.y) < stats.jump_hang_threshold:
		gravity_multiplier = stats.jump_hang_gravity_mult
	elif velocity.y < 0:
		gravity_multiplier = stats.ascend_gravity_mult
	elif velocity.y > 0:
		gravity_multiplier = stats.fall_gravity_mult

	velocity.y = min(velocity.y + stats.gravity * gravity_multiplier * delta, stats.max_fall_speed)

# True only within both the coyote-time window (recently left ground)
# AND the jump-buffer window (recently pressed jump) — see _update_timers().
func can_jump() -> bool:
	return coyote_timer > 0.0 and jump_buffer_timer > 0.0

func consume_jump() -> void:
	coyote_timer = 0.0
	jump_buffer_timer = 0.0
	is_jump_cut = false

func can_pogo() -> bool:
	return has_pogo_ability and pogo_grace_timer > 0.0 and pogo_buffer_timer > 0.0

func consume_pogo() -> void:
	pogo_grace_timer = 0.0
	pogo_buffer_timer = 0.0
	is_jump_cut = false
	
func can_double_jump() -> bool:
	log(has_double_jump_ability)
	return has_double_jump_ability and not is_on_floor() and air_jumps_used < stats.max_air_jumps and jump_buffer_timer > 0.0

func consume_double_jump() -> void:
	air_jumps_used += 1
	jump_buffer_timer = 0.0
	is_jump_cut = false

func can_dash() -> bool:
	return has_dash_ability and not dash_used

func consume_dash() -> void:
	dash_used = true

func get_dash_direction() -> float:
	var direction := get_movement_direction()
	if direction != 0:
		return direction
	return 1.0 if sprite.flip_h else -1.0

func get_movement_direction() -> float:
	if _direction_stack.is_empty():
		return 0.0
	return -1.0 if _direction_stack.back() == "left" else 1.0

func play_animation(anim_name: String) -> void:
	if _is_whiffing and anim_name != "pogo":
		return
	if sprite.animation != anim_name:
		sprite.play(anim_name)

func play_pogo_whiff() -> void:
	_is_whiffing = true
	play_animation("pogo")
	await sprite.animation_finished
	_is_whiffing = false
	_resume_state_animation()

func _resume_state_animation() -> void:
	var state_name: String = PlayerState.STATE_ID.find_key(state_machine.current_state.get_state_id())
	play_animation(state_name.to_lower())
	
func update_facing() -> void:
	var direction := get_movement_direction()
	if direction != 0:
		sprite.flip_h = direction > 0
		
func apply_horizontal_movement(delta: float) -> void:
	var direction := get_movement_direction()
	var target_speed := direction * stats.move_speed
	var accel := stats.acceleration
	if not is_on_floor() and abs(velocity.y) < stats.jump_hang_threshold:
		target_speed *= stats.jump_hang_max_speed_mult
		accel *= stats.jump_hang_accel_mult
	if direction != 0:
		velocity.x = move_toward(velocity.x, target_speed, accel * delta)
	else:
		velocity.x = move_toward(velocity.x, 0, stats.friction * delta)

# Only collides with jump-through platforms when a short raycast from the
# feet detects one within landing range directly below. This avoids the
# false positives you get from checking velocity.y alone: a ray pointed
# straight down can't be triggered by a platform's side edge, only by
# something actually beneath the player's feet.
#
# The cast has to reach at least as far as the player will move this frame.
# Its resting length only clears the feet by half a pixel, but a fall at
# max_fall_speed covers 15px per physics tick — without the look-ahead the feet
# step straight over that band, the mask never gets enabled, and the player
# tunnels through the platform.
func _update_platform_collision(delta: float) -> void:
	var reach := _floor_check_reach
	if velocity.y > 0.0:
		reach = max(reach, velocity.y * delta + FLOOR_CHECK_LOOKAHEAD_MARGIN)
	floor_check.target_position.y = reach

	floor_check.force_shapecast_update()
	set_collision_mask_value(JUMP_THROUGH_PLATFORMS_LAYER, floor_check.is_colliding())

func _push_direction(dir: String) -> void:
	_direction_stack.erase(dir)
	_direction_stack.append(dir)


func _pop_direction(dir: String) -> void:
	_direction_stack.erase(dir)
