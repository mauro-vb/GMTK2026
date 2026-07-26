@tool
class_name JumpThroughPlatform
extends AnimatableBody2D
# Signals
# Constants
const COLLISION_LAYER: int = 9
# Keep this well under platform_height. The margin is how deep the player may
# sink into the shape and still get pushed back out the top, so a margin taller
# than the platform itself grabs a player who has already cleared it from below
# and snaps them up onto it. 2px is enough to catch a fast landing.
const ONE_WAY_COLLISION_MARGIN: float = 2.0
# Exports
## Setter fires as soon as this changes in the Inspector, so the platform
## resizes live in the editor instead of only after a reload.
@export var size: int = 3:
	set(value):
		size = value
		_dynamic_sizing()
# Public
# Height of one platform tile in pixels — subclasses set this before super._ready()
# when their art isn't the standard 6px tall. Also live-updating for the same
# reason size is: a subclass may set it from its own @export setter too.
var platform_height: float = 6.0:
	set(value):
		platform_height = value
		_dynamic_sizing()
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
	collision_shape.one_way_collision_margin = ONE_WAY_COLLISION_MARGIN
	collision_shape.one_way_collision_direction = Vector2(0, 1)
	
	collision_layer = 0
	collision_mask = 0
	
	set_collision_layer_value(COLLISION_LAYER, true)
	_dynamic_sizing()
	center_sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	
# Private
func _dynamic_sizing() -> void:
	# The size/platform_height setters can fire before @onready has run — the
	# default `size = 3` assignment happens at construction, and subclasses
	# are documented to set platform_height before super._ready() even runs.
	if collision_shape == null:
		return

	var center_width: float = 8
	var half_height: float = platform_height * .5
	if size == 1:
		left_sprite.modulate.a = 0
		right_sprite.modulate.a = 0
	else:
		left_sprite.modulate.a = 1
		right_sprite.modulate.a = 1
		center_width = max(size - 2, 0) * 8
		var half_center_width: float = center_width * .5
		left_sprite.position = Vector2(-half_center_width - 4, half_height)
		right_sprite.position = Vector2(half_center_width + 4, half_height)
	collision_shape.shape.size = Vector2(8 * size, platform_height)
	center_sprite.region_rect = Rect2(0, 0, center_width, platform_height)
