class_name Player
extends CharacterBody2D

const JUMP_THROUGH_PLATFORMS_LAYER: int = 9
# Slack added on top of the per-frame fall distance, so a platform is picked up on
# the frame before the feet reach it rather than exactly on contact
const FLOOR_CHECK_LOOKAHEAD_MARGIN: float = 2.0

# Movement abilities a modifier can grant or take away (see GrantAbilityModifier)
enum Ability { DASH, DOUBLE_JUMP, POGO }

@export var stats: PlayerStats

# abilities
var has_pogo_ability: bool = true
var has_double_jump_ability: bool = true
var has_dash_ability: bool = true

# Seconds charged to the TimeSystem each time an ability is used. Written by
# AbilityCostModifier; a missing entry means that ability is free.
var ability_time_costs: Dictionary[Ability, float] = {}

# Ability uses that skip their time cost. Refilled at level start by the
# "Primed" modifier (FreeAbilityModifier).
var free_ability_uses: int = 0

# While false the player is frozen in place — used by the "Cold Fuse" modifier.
var can_move: bool = true

# basic jump behavior
var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var is_jump_cut: bool = false

# pogo behavior
var pogo_buffer_timer: float = 0.0
var pogo_grace_timer: float = 0.0
var _last_pogo_area: PogoArea = null
var _is_whiffing: bool = false # pogoing outside of pogo area

# double jump behavior
var air_jumps_used: int = 0

# dash behavior
var is_dashing: bool = false
var dash_used: bool = false
var _is_dash_animating: bool = false
var _dash_anim_token: int = 0

# drop-through behavior
var _drop_through_timer: float = 0.0
var _dropped_platforms: Array[DropThroughPlatform] = []

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

# Clears carried-over motion, ability state and held input, so a room never
# starts mid-dash, mid-fall or still drifting. The player node is reused across
# rooms (only re-parented, so _ready() doesn't run again) — every bit of state
# that isn't reset here survives the swap. Called by MainGame.enter_level()
func reset_for_new_room() -> void:
	can_move = true
	sprite.visible = true
	velocity = Vector2.ZERO
	coyote_timer = 0.0
	jump_buffer_timer = 0.0
	is_jump_cut = false
	pogo_buffer_timer = 0.0
	pogo_grace_timer = 0.0
	_is_whiffing = false
	_last_pogo_area = null
	air_jumps_used = 0
	is_dashing = false
	dash_used = false
	_direction_stack.clear()
	_drop_through_timer = 0.0
	_end_drop_through()
	# Last, so the state it enters sees the cleared flags — play_animation() is
	# swallowed while _is_whiffing is still set
	state_machine.reset()

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
	# `can_move` covers being frozen ("Cold Fuse") and being blown up: a whiff
	# would play an animation over a death that is meant to be the last thing on
	# screen. Direction bookkeeping above still runs either way, so a key held
	# through a freeze isn't lost.
	elif event.is_action_pressed("attack") and can_move and pogo_grace_timer <= 0.0 and not _is_whiffing:
		play_pogo_whiff()
		

func _physics_process(delta: float) -> void:
	if not can_move:
		velocity = Vector2.ZERO
		move_and_slide()
		return

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
	
	var touching_pogo_area := _find_pogo_area()
	if touching_pogo_area != null:
		_last_pogo_area = touching_pogo_area

	var touching_pogoable := touching_pogo_area != null or pogo_detector.has_overlapping_bodies()
	pogo_grace_timer = stats.pogo_grace_time if touching_pogoable else max(pogo_grace_timer - delta, 0.0)

	if Input.is_action_just_pressed("attack"):
		pogo_buffer_timer = stats.pogo_buffer_time
	else:
		pogo_buffer_timer = max(pogo_buffer_timer - delta, 0.0)

	if _drop_through_timer > 0.0:
		_drop_through_timer = max(_drop_through_timer - delta, 0.0)
		if _drop_through_timer == 0.0:
			_end_drop_through()

# Falling gravity > rising gravity, and gravity is reduced near the jump apex
# (jump_hang_threshold) for a brief "float" feeling. See PlayerStats for tuning
func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		return
	if is_dashing:
		return
	var gravity_multiplier := 1.0

	# Releasing jump can still flip is_jump_cut true while pogoing — the player
	# is often still holding jump from the jump that led into the pogo — but a
	# pogo's arc isn't a jump and must never be cut short by it. Scoped to state
	# rather than cleared harder on entry, since the release can happen at any
	# point during the bounce, not just at the start of it.
	if is_jump_cut and velocity.y < 0 and state_machine.current_state.get_state_id() != PlayerState.STATE_ID.POGO:
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
	pay_ability_cost(Ability.POGO)
	if _last_pogo_area != null:
		_last_pogo_area.bounced.emit()
		_last_pogo_area = null

func _find_pogo_area() -> PogoArea:
	for area: Area2D in pogo_detector.get_overlapping_areas():
		if area is PogoArea:
			return area
	return null
	
func can_double_jump() -> bool:
	log(has_double_jump_ability)
	return has_double_jump_ability and not is_on_floor() and air_jumps_used < stats.max_air_jumps and jump_buffer_timer > 0.0

func consume_double_jump() -> void:
	air_jumps_used += 1
	jump_buffer_timer = 0.0
	is_jump_cut = false
	pay_ability_cost(Ability.DOUBLE_JUMP)

# Jump + down while standing on drop-through platforms falls through them instead of
# jumping. Reuses the jump buffer so the two presses don't have to land on the same frame.
# Every body under the feet has to be droppable — at a seam with a solid platform the
# player would stay put anyway, and consuming the jump for nothing eats an input
func can_drop_through() -> bool:
	if not is_on_floor() or jump_buffer_timer <= 0.0:
		return false
	if not Input.is_action_pressed("down"):
		return false
	return not _get_platforms_underfoot().is_empty()

# The exceptions target only the platforms being dropped through, not the whole layer,
# so anything else in the fall path still catches the player. They're lifted on a timer
# rather than on losing contact: the one-way margin can still shove the player back up
# just after the feet clear the shape
func consume_drop_through() -> void:
	_dropped_platforms = _get_platforms_underfoot()
	for platform in _dropped_platforms:
		add_collision_exception_with(platform)
	_drop_through_timer = stats.drop_through_time
	velocity.y = stats.drop_through_velocity
	consume_jump()

func _end_drop_through() -> void:
	for platform in _dropped_platforms:
		if is_instance_valid(platform):
			remove_collision_exception_with(platform)
	_dropped_platforms.clear()

# Returns the drop-through platforms directly beneath the feet, or nothing at all if
# any of the bodies down there isn't one
func _get_platforms_underfoot() -> Array[DropThroughPlatform]:
	var platforms: Array[DropThroughPlatform] = []
	# Cast at its resting length: a look-ahead left over from a fall would reach past
	# the platform being stood on and pick up whatever sits below it
	floor_check.target_position.y = _floor_check_reach
	floor_check.force_shapecast_update()
	for i in floor_check.get_collision_count():
		var collider: Object = floor_check.get_collider(i)
		if not collider is DropThroughPlatform:
			return []
		platforms.append(collider)
	return platforms

func can_dash() -> bool:
	return has_dash_ability and not dash_used

func consume_dash() -> void:
	dash_used = true
	pay_ability_cost(Ability.DASH)

# Charges the ability's time cost to the clock. Abilities are free unless a
# modifier priced them, and "Primed" hands out a few uses that skip the bill.
func pay_ability_cost(ability: Ability) -> void:
	var cost: float = ability_time_costs.get(ability, 0.0)
	if cost <= 0.0:
		return
	if free_ability_uses > 0:
		free_ability_uses -= 1
		return
	if Global.main_game == null or Global.main_game.time_system == null:
		return
	Global.main_game.time_system.remove_time(cost)

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
	if _is_dash_animating and anim_name != "dash":
		return
	if sprite.animation != anim_name:
		sprite.play(anim_name)

## The fuse ran out. Blows the player up and leaves the debris on screen for the
## last frame of it. Awaitable, so MainGame can hold the run-end screen back
## until the charge has actually gone off.
##
## Goes straight to `sprite.play()` rather than through [method play_animation]:
## that one is written to be interruptible by the state machine, and a death is
## the one animation nothing gets to talk over. The whiff and dash guards are
## cleared for the same reason — either could still be mid-await and would put
## its own animation back on top a frame later.
func explode() -> void:
	can_move = false
	velocity = Vector2.ZERO
	_is_whiffing = false
	_is_dash_animating = false
	_dash_anim_token += 1

	sprite.play(&"detonation")
	await sprite.animation_finished


func play_pogo_whiff() -> void:
	_is_whiffing = true
	play_animation("pogo")
	await sprite.animation_finished
	_is_whiffing = false
	_resume_state_animation()

func play_dash_animation() -> void:
	_dash_anim_token += 1
	var token := _dash_anim_token
	_is_dash_animating = true
	play_animation("dash")
	await sprite.animation_finished
	if token == _dash_anim_token:
		_is_dash_animating = false
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
# max_fall_speed covers several pixels per physics tick — without the look-ahead
# the feet step straight over that band, the mask never gets enabled, and the
# player tunnels through the platform.
#
# Rising is excluded outright. The cast box starts 2.5px inside the body rather
# than at its lower edge, so on the way up a platform enters that band while it
# still overlaps the player. Enabling the mask there hands move_and_slide an
# already-overlapping one-way shape, and it resolves the overlap the only way it
# can — upward — which reads as the player teleporting onto the platform.
# You can't land on anything while moving up, so there is nothing to detect yet.
func _update_platform_collision(delta: float) -> void:
	if velocity.y < 0.0:
		set_collision_mask_value(JUMP_THROUGH_PLATFORMS_LAYER, false)
		return

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
