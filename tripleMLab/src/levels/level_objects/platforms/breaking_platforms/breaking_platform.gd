class_name BreakingPlatform
extends AnimatableBody2D

# Signals

# Constants
const RECONSTRUCT_TIME: float = 1.75
const ONE_WAY_COLLISION_MARGIN: float = 4
# Exports
@export var break_on_jump: bool = false
@export_range(2, 100, 1) var size: int = 3
# Public
# Private
var _entered_detection_area: bool = false
# On Ready
@onready var detection_area: Area2D = %Area2D
@onready var detection_collision_shape: CollisionShape2D = %DetectionCollisionShape2D
@onready var visuals: Node2D = %Visuals
@onready var center_sprite: Sprite2D = %CenterSprite
@onready var left_sprite: Sprite2D = %LeftSprite
@onready var right_sprite: Sprite2D = %RightSprite
@onready var collision_shape: CollisionShape2D = %CollisionShape2D
@onready var animation_player: AnimationPlayer = %AnimationPlayer
@onready var timer: Timer = %Timer


# Lifecycle
func _ready() -> void:
	detection_area.monitoring = true
	collision_shape.disabled = false
	collision_shape.one_way_collision_margin = ONE_WAY_COLLISION_MARGIN
	
	_dynamic_sizing()
	
	timer.wait_time = RECONSTRUCT_TIME
	timer.timeout.connect(_enable)
	
	detection_area.body_entered.connect(_on_body_entered)
	if break_on_jump:
		center_sprite.texture = load("res://assets/art/platforms/breaking_platforms/CenterBreakonJump.png")
		left_sprite.texture = load("res://assets/art/platforms/breaking_platforms/LeftBreakonJump.png")
		right_sprite.texture = load("res://assets/art/platforms/breaking_platforms/RightBreakonJump.png")

		detection_area.body_exited.connect(_on_body_exited)

# Private
func _dynamic_sizing() -> void:
	collision_shape.shape.size = Vector2(8 * size, 6)
	detection_collision_shape.shape.size = Vector2(8 * size, 1)
	
	var center_width: float = max(size - 2, 0) * 8
	var half_center_width: float = center_width * .5
	
	left_sprite.position = Vector2(-half_center_width - 4, 3)
	right_sprite.position = Vector2(half_center_width + 4, 3)
	center_sprite.region_rect = Rect2(0, 0, center_width, 6)

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
	
