class_name MapNode
extends Area2D

signal selected(node: MapNodeData)
## Fired on hover start/end while available — the map brightens the path
## segment leading to this node.
signal hover_changed(node: MapNodeData, hovered: bool)

const ICONS: Dictionary[MapNodeData.Type, String] = {
	MapNodeData.Type.NOT_ASSIGNED: "NA",
	MapNodeData.Type.LEVEL: "LEVEL",
	MapNodeData.Type.SHOP: "SHOP",
	MapNodeData.Type.HEAL: "HEAL",
	MapNodeData.Type.FINAL: "FINAL",
}

## Placeholder type indication until nodes get real per-type icons.
const TYPE_COLORS: Dictionary[MapNodeData.Type, Color] = {
	MapNodeData.Type.NOT_ASSIGNED: Color.WHITE,
	MapNodeData.Type.LEVEL: Color.WHITE,
	MapNodeData.Type.SHOP: Color(1.0, 0.82, 0.2),
	MapNodeData.Type.HEAL: Color(0.5, 0.95, 0.55),
	MapNodeData.Type.FINAL: Color(0.95, 0.35, 0.35),
}

const SCENE: PackedScene = preload("res://src/gameplay/map/visuals/MapNode.tscn")

const HOVER_SCALE: Vector2 = Vector2(1.15, 1.15)
const HOVER_TIME: float = 0.15
## Alpha for nodes on rows the player has passed without picking them.
const DIMMED_ALPHA: float = 0.35
## Press and release must land within this world-space distance to count as a
## click — a press that turns into a map pan never selects the node.
const CLICK_SLOP: float = 6.0

var available: bool = false: set = _set_available
var node: MapNodeData: set = _set_node

var _press_position: Vector2 = Vector2.INF
var _hovered: bool = false
var _hover_tween: Tween = null

@onready var visuals: Node2D = $Visuals
@onready var sprite: Sprite2D = $Visuals/Sprite2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var label: Label = %Label


static func new_map_node(node_data: MapNodeData) -> MapNode:
	var map_node: MapNode = SCENE.instantiate()
	map_node.node = node_data
	return map_node


func _ready() -> void:
	input_event.connect(_on_input_event)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	sprite.modulate = TYPE_COLORS.get(node.type, Color.WHITE)
	label.text = ICONS.get(node.type, "?")[0]


func show_selected() -> void:
	animation_player.play("selected")


## Fades out a node on a row the player passed without choosing it. The path
## not taken stays legible but clearly dead.
func set_dimmed() -> void:
	input_pickable = false
	create_tween().tween_property(self, ^"modulate:a", DIMMED_ALPHA, 0.2)


func _set_available(value: bool) -> void:
	available = value

	if available:
		animation_player.play("highlight")
	elif not node.selected:
		animation_player.play("RESET")
		if _hovered:
			_set_hovered(false)


func _set_node(value: MapNodeData) -> void:
	node = value
	position = node.position


func _on_mouse_entered() -> void:
	if available:
		_set_hovered(true)


func _on_mouse_exited() -> void:
	_press_position = Vector2.INF
	if _hovered:
		_set_hovered(false)


func _set_hovered(hovered: bool) -> void:
	_hovered = hovered
	hover_changed.emit(node, hovered)
	Input.set_default_cursor_shape(
		Input.CURSOR_POINTING_HAND if hovered else Input.CURSOR_ARROW
	)
	if _hover_tween != null and _hover_tween.is_valid():
		_hover_tween.kill()
	# TRANS_BACK overshoots slightly and settles — the standard "juicy" hover pop.
	_hover_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_hover_tween.tween_property(
		visuals, ^"scale", HOVER_SCALE if hovered else Vector2.ONE, HOVER_TIME
	)


## Selection happens on release, not press, so starting a camera drag on top
## of a node doesn't accidentally commit to it (see CLICK_SLOP).
func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if not available:
		return
	if event.is_action_pressed(&"left_mouse"):
		_press_position = get_global_mouse_position()
	elif event.is_action_released(&"left_mouse") and _press_position != Vector2.INF:
		var was_click: bool = get_global_mouse_position().distance_to(_press_position) < CLICK_SLOP
		_press_position = Vector2.INF
		if was_click:
			_select()


func _select() -> void:
	node.selected = true
	if _hovered:
		_set_hovered(false)
	animation_player.play("selected")


# Called from animation player
func _on_map_room_selected() -> void:
	selected.emit(node)
