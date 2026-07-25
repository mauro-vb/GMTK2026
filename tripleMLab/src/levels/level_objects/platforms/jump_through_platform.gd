class_name JumpThroughPlatform
extends AnimatableBody2D

# Signals
# Constants
const COLLISION_LAYER: int = 9

# Exports
@export_range(2, 100, 1) var size: int = 3
@export var one_way_collision_margin: float = 7.0

# Public
# Private
# On Ready
@onready var visuals: Node2D = %Visuals
@onready var center_sprite: Sprite2D = %CenterSprite
@onready var left_sprite: Sprite2D = %LeftSprite
@onready var right_sprite: Sprite2D = %RightSprite
@onready var collision_shape: CollisionShape2D = %CollisionShape2D

# Lifecycle
func _ready() -> void:
	collision_shape.one_way_collision = true
	collision_shape.one_way_collision_margin = one_way_collision_margin
	collision_shape.one_way_collision_direction = Vector2(0, 1)
	
	collision_layer = 0
	collision_mask = 0
	
	set_collision_layer_value(COLLISION_LAYER, true)
	_dynamic_sizing()
	center_sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	
# Private
func _dynamic_sizing() -> void:
	collision_shape.shape.size = Vector2(8 * size, 6)
	
	var center_width: float = max(size - 2, 0) * 8
	var half_center_width: float = center_width * .5
	
	left_sprite.position = Vector2(-half_center_width - 4, 3)
	right_sprite.position = Vector2(half_center_width + 4, 3)
	center_sprite.region_rect = Rect2(0, 0, center_width, 6)
