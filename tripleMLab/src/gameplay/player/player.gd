extends CharacterBody2D
class_name Player

@export var stats: PlayerStats

@onready var state_machine: PlayerStateMachine = $StateMachine

var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0

# Tracks held direction keys in press order (most recent = last).
var _direction_stack: Array[String] = []

func _ready() -> void:
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
	if event.is_action_pressed("left"):
		_push_direction("left")
	elif event.is_action_pressed("right"):
		_push_direction("right")
	elif event.is_action_released("left"):
		_pop_direction("left")
	elif event.is_action_released("right"):
		_pop_direction("right")

func _physics_process(delta: float) -> void:
	_update_timers(delta)
	_apply_gravity(delta)
	state_machine.physics_update(delta)
	move_and_slide()

# Ticks the coyote-time and jump-buffer windows each physics frame:
# coyote_timer resets while grounded, jump_buffer_timer resets on jump press.
# Both count down otherwise
func _update_timers(delta: float) -> void:
	coyote_timer = stats.coyote_time if is_on_floor() else max(coyote_timer - delta, 0.0)

	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = stats.jump_buffer_time
	else:
		jump_buffer_timer = max(jump_buffer_timer - delta, 0.0)

# Falling gravity > rising gravity, and gravity is reduced near the jump apex
# (jump_hang_threshold) for a brief "float" feeling. See PlayerStats for tuning
func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		return

	var gravity_multiplier := 1.0

	if abs(velocity.y) < stats.jump_hang_threshold:
		gravity_multiplier = stats.jump_hang_gravity_mult
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

func get_movement_direction() -> float:
	if _direction_stack.is_empty():
		return 0.0
	return -1.0 if _direction_stack.back() == "left" else 1.0

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

func _push_direction(dir: String) -> void:
	_direction_stack.erase(dir)
	_direction_stack.append(dir)

func _pop_direction(dir: String) -> void:
	_direction_stack.erase(dir)
