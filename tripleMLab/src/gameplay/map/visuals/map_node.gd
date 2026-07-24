class_name MapNode
extends Area2D

signal selected(node: Room)

const ICONS: Dictionary[Room.Type, String] = {
	Room.Type.NOT_ASSIGNED: "NA",
	Room.Type.SHOP: "SHOP",
	Room.Type.LEVEL: "LEVEL",
	Room.Type.HEAL: "HEAL",
	Room.Type.EVENT: "EVENT",
	Room.Type.FINAL: "FINAL",
}

const SCENE: PackedScene = preload("res://src/gameplay/map/visuals/MapNode.tscn")

var available: bool = false: set = _set_available
var room: Room: set = _set_room

@onready var sprite: Sprite2D = $Visuals/Sprite2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var label: Label = %Label


static func new_map_node(node_data: Room) -> MapNode:
	var map_node: MapNode = SCENE.instantiate()
	map_node.room = node_data
	return map_node

	
func _ready() -> void:
	input_event.connect(_on_input_event)
	
func show_selected() -> void:
	animation_player.play("selected")

func _set_available(value: bool) -> void:
	available = value
	
	if available:
		await get_tree().create_timer(randf_range(.0,.25)).timeout
		animation_player.play("highlight")
	elif not room.selected:
		animation_player.play("RESET")

func _set_room(value: Room) -> void:
	room = value
	position = room.position
	%Label.text = room.get_type()
	#sprite.texture = ICONS[node.type]

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if not available or not event.is_action_pressed("left_mouse"):
		return
		
	room.selected = true
	animation_player.play("selected")
	await animation_player.animation_finished
	_on_map_room_selected()
	
# Called from animation player
func _on_map_room_selected() -> void:
	selected.emit(room)
	
