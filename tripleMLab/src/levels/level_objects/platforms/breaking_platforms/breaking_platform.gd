class_name BreakingPlatform
extends AnimatableBody2D

# Signals

# Constants
const RECONSTRUCT_TIME: float = 1.75

# Exports
@export var break_on_jump: bool = false

# Public
# Private
var _entered_detection_area: bool = false
# On Ready
@onready var detection_area: Area2D = %Area2D
@onready var sprite: Sprite2D = %Sprite2D
@onready var collision_shape: CollisionShape2D = %CollisionShape2D
@onready var animation_player: AnimationPlayer = %AnimationPlayer
@onready var timer: Timer = %Timer


# Lifecycle
func _ready() -> void:
	detection_area.monitoring = true
	collision_shape.disabled = false
	
	timer.wait_time = RECONSTRUCT_TIME
	timer.timeout.connect(_enable)
	
	detection_area.body_entered.connect(_on_body_entered)
	if break_on_jump:
		modulate = Color() # TODO: Change texture maybe?
		detection_area.body_exited.connect(_on_body_exited)

# Private
func _disable() -> void:
	collision_shape.disabled = true
	detection_area.monitoring = false
	timer.start()

func _enable() -> void:
	collision_shape.disabled = false
	detection_area.monitoring = true
	animation_player.play("reconstruct")
	
# Callbacks
func _on_body_entered(body: Node2D) -> void:
	if body is not Player:
		return
	if body.floor_check.is_colliding():
		if break_on_jump:
			_entered_detection_area = true
			animation_player.play("initial_break")
		else:
			animation_player.play("break")
			await animation_player.animation_finished
			_disable()
		

func _on_body_exited(body: Node2D) -> void:
	if body is not Player:
		return
	if _entered_detection_area:
		_entered_detection_area = false
		if animation_player.current_animation != "":
			await animation_player.animation_finished
		animation_player.play("break_on_jump")
		await animation_player.animation_finished
		_disable()
	
