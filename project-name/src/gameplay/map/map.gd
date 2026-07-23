class_name Map
extends Node2D

signal node_selected(node: MapNodeData)

const SCROLL_SPEED: int = 15
const MAP_LINE: PackedScene = preload("res://src/gameplay/map/visuals/MapLine.tscn")

@onready var camera: Camera2D = %Camera2D
@onready var visuals: Node2D = %Visuals
@onready var lines: Node2D = %Lines
@onready var nodes: Node2D = %MapNodes
@onready var map_generator: MapGenerator = %MapGenerator

var map_data: Array[Array]
var progress: int
var last_node: MapNodeData
var camera_edge_y: float

func _ready() -> void:
	camera.position = Vector2(get_viewport_rect().size.x * .5,get_viewport_rect().size.y * .5)
	camera_edge_y = MapGenerator.Y_DIST * (MapGenerator.HEIGHT - 1)
	
	generate_new_map()
	unlock_row(0)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("scroll_up"):
		camera.position.y -= SCROLL_SPEED
	if event.is_action_pressed("scroll_down"):
		camera.position.y += SCROLL_SPEED
		
	camera.position.y = clamp(camera.position.y, -camera_edge_y, 0)
	
func generate_new_map() -> void:
	progress = 0
	map_data = map_generator.generate_map()
	create_map()

func create_map() -> void:
	for current_row: Array in map_data:
		for node: MapNodeData in current_row:
			if node.next_nodes.size() > 0:
				_add_map_node(node)
	
	# Final Room Needs Manual Spawning (once, not per row)
	var middle: int = floori(MapGenerator.WIDTH * .5)
	_add_map_node(map_data[MapGenerator.HEIGHT - 1][middle])
	
	# Map Visuals Placement (also once)
	var map_widht_pixels: int = MapGenerator.X_DIST * (MapGenerator.WIDTH - 1)
	visuals.position.x = (get_viewport_rect().size.x - map_widht_pixels) / 2
	visuals.position.y = 0

func show_map() -> void:
	show()
	camera.enabled = true

func hide_map() -> void:
	hide()
	camera.enabled = false

func unlock_row(row: int = progress) -> void:
	for map_node: MapNode in nodes.get_children():
		if map_node.node.coordinates.y == row:
			map_node.available = true

func unlock_next_nodes() -> void:
	for map_node: MapNode in nodes.get_children():
		if last_node.next_nodes.has(map_node):
			map_node.available = true
	
func _add_map_node(node: MapNodeData) -> void:
	var new_map_node: MapNode = MapNode.new_map_node(node)
	new_map_node.selected.connect(_on_node_selected)
	nodes.add_child(new_map_node)
	_connect_lines(node)

	if node.selected and node.coordinates.y < progress:
		new_map_node.show_selected()

func _connect_lines(node: MapNodeData) -> void:
	if node.next_nodes.size() < 1:
		return
		
	for next: MapNodeData in node.next_nodes:
		var new_map_line: Line2D = MAP_LINE.instantiate()
		new_map_line.add_point(node.position)
		new_map_line.add_point(next.position)
		lines.add_child(new_map_line)
	
	
func _on_node_selected(node: MapNodeData) -> void:
	for map_node: MapNode in nodes.get_children():
		if map_node.node.coordinates.y == node.coordinates.y:
			map_node.available = false
	
	last_node = node
	progress += 1
	node_selected.emit(node)
