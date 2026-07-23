extends CharacterBody2D
class_name Player

@export var stats: PlayerStats

@onready var state_machine: PlayerStateMachine = $StateMachine

var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0

func _ready() -> void:
	state_machine.setup(self, stats)

func _physics_process(delta: float) -> void:
	_update_timers(delta)
	_apply_gravity(delta)
	state_machine.physics_update(delta)
	move_and_slide()

func _update_timers(delta: float) -> void:
	coyote_timer = stats.coyote_time if is_on_floor() else max(coyote_timer - delta, 0.0)

	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = stats.jump_buffer_time
	else:
		jump_buffer_timer = max(jump_buffer_timer - delta, 0.0)

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y = min(velocity.y + stats.gravity * delta, stats.max_fall_speed)

func can_jump() -> bool:
	return coyote_timer > 0.0 and jump_buffer_timer > 0.0

func consume_jump() -> void:
	coyote_timer = 0.0
	jump_buffer_timer = 0.0

func apply_horizontal_movement(delta: float) -> void:
	var direction := Input.get_axis("left", "right")
	if direction != 0:
		velocity.x = move_toward(velocity.x, direction * stats.move_speed, stats.acceleration * delta)
	else:
		velocity.x = move_toward(velocity.x, 0, stats.friction * delta)
