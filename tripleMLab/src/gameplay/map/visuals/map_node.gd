class_name MapNode
extends Area2D

signal selected(node: MapNodeData)

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

var available: bool = false: set = _set_available
var node: MapNodeData: set = _set_node

@onready var sprite: Sprite2D = $Visuals/Sprite2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var label: Label = %Label


static func new_map_node(node_data: MapNodeData) -> MapNode:
	var map_node: MapNode = SCENE.instantiate()
	map_node.node = node_data
	return map_node

	
func _ready() -> void:
	input_event.connect(_on_input_event)
	sprite.modulate = TYPE_COLORS.get(node.type, Color.WHITE)
	label.text = ICONS.get(node.type, "?")[0]

func show_selected() -> void:
	animation_player.play("selected")

func _set_available(value: bool) -> void:
	available = value
	
	if available:
		animation_player.play("highlight")
	elif not node.selected:
		animation_player.play("RESET")

func _set_node(value: MapNodeData) -> void:
	node = value
	position = node.position
	#label.text = ICONS[node.type]
	#sprite.texture = ICONS[node.type]

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if not available or not event.is_action_pressed("left_mouse"):
		return
		
	node.selected = true
	animation_player.play("selected")
	
# Called from animation player
func _on_map_room_selected() -> void:
	selected.emit(node)
	
