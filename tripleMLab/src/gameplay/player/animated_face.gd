class_name PlayerFaceAnimatedSprite
extends AnimatedSprite2D
const FRAME_OFFSETS: Dictionary = {
	"pogo": {
		0: Vector2(0, -1),
		1: Vector2(3, -1),
		2: Vector2(6, -4),
		5: Vector2(-1, 0),
	},
	"double_jump": {
		0: Vector2(0, -1),
		1: Vector2(3, -1),
		2: Vector2(6, -4),
		5: Vector2(-1, 0),
	},
	"fall": {
		0: Vector2(0, -1),
		1: Vector2(0, 1),
		2: Vector2(0, 3),
	},
	"idle": {
		0: Vector2(0, 0),
		1: Vector2(0, 0),
		2: Vector2(0, 1),
		3: Vector2(0, 1),
		4: Vector2(0, 0),
		5: Vector2(0, 0),
		6: Vector2(0, 0),
	},
	"jump": {
		0: Vector2(0, 1),
		1: Vector2(0, -6),
		2: Vector2(0, -6),
		3: Vector2(0, -4),
	},
	"run": {
		0: Vector2(-1, -2),
		1: Vector2(0, -1),
		2: Vector2(1, 0),
		3: Vector2(2, -2),
		4: Vector2(2, -3),
		5: Vector2(1, 0),
		6: Vector2(-1, -1),
	},
}
const ALWAYS_HIDDEN_ANIMATIONS: Array[String] = ["dash"]
@export var _parent_sprite: AnimatedSprite2D
var _base_position: Vector2
var _current_offset: Vector2 = Vector2.ZERO
var _current_frame_visible: bool = true
var _last_flip_h: bool = false
func _ready() -> void:
	assert(
		_parent_sprite is AnimatedSprite2D,
		"%s expects its parent to be an AnimatedSprite2D" % name
	)
	_base_position = position
	_last_flip_h = _parent_sprite.flip_h
	_parent_sprite.frame_changed.connect(_on_parent_frame_changed)
	_parent_sprite.animation_changed.connect(_on_parent_frame_changed)
	_on_parent_frame_changed()
	
	Global.main_game.time_system.tick_rate_changed.connect(
		func(tick_rate: float) -> void: speed_scale = tick_rate
	)

	
func _process(_delta: float) -> void:
	var flip: bool = _parent_sprite.flip_h
	if flip != _last_flip_h:
		_last_flip_h = flip
		_apply_current_frame()
		
func _on_parent_frame_changed() -> void:
	var anim_name: StringName = _parent_sprite.animation
	var frame_index: int = _parent_sprite.frame
	if anim_name in ALWAYS_HIDDEN_ANIMATIONS:
		_current_frame_visible = false
		_apply_current_frame()
		return
	if not FRAME_OFFSETS.has(anim_name):
		_current_frame_visible = true
		_current_offset = Vector2.ZERO
		_apply_current_frame()
		return
	var frame_map: Dictionary = FRAME_OFFSETS[anim_name]
	if not frame_map.has(frame_index):
		_current_frame_visible = false
		_apply_current_frame()
		return
	_current_frame_visible = true
	_current_offset = frame_map[frame_index] 
	_apply_current_frame()
	
func _apply_current_frame() -> void:
	visible = _current_frame_visible
	if not visible:
		return
	var _offset := _current_offset
	if _parent_sprite.flip_h:
		_offset.x = -_offset.x + 5
	position = _base_position + _offset
