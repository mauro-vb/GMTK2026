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

	move_and_slide()
	
func reset_physics() -> void:
	velocity = Vector2.ZERO
