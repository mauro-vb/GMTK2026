class_name Map
extends Node2D
## The Slay-the-Spire-style run map. Owns the map camera and all the ways to
## move it (mouse wheel, click-drag panning, keyboard/stick scrolling), plus
## the visual state of nodes and path lines as the run progresses. Camera
## motion is smoothed toward _target_y; dragging writes the camera directly so
## panning stays 1:1 under the cursor.

signal node_selected(node: MapNodeData)

const MAP_LINE: PackedScene = preload("res://src/gameplay/map/visuals/MapLine.tscn")

# Camera feel
const WHEEL_STEP: float = 28.0
const KEY_SCROLL_SPEED: float = 220.0
## Multiplier for two-finger trackpad panning (InputEventPanGesture deltas
## arrive small and rapid). Tune to taste.
const TRACKPAD_PAN_SPEED: float = 4.0
const CAMERA_SMOOTHING: float = 10.0
## Padding kept visible above the final node and below the first row.
const EDGE_MARGIN: float = 40.0
## The focused row sits in the lower third of the screen so the branches
## ahead of the player get most of the space.
const ROW_FOCUS_OFFSET: float = 60.0
## Mouse travel (in viewport pixels) before a press counts as a pan, not a click.
const DRAG_THRESHOLD: float = 5.0

const LINE_COLOR_DEFAULT: Color = Color(0.45, 0.42, 0.55, 0.7)
const LINE_COLOR_TRAVELED: Color = Color(1.0, 0.851, 0.4, 0.9)
const LINE_COLOR_HOVER: Color = Color(0.88, 0.85, 1.0, 0.95)

@onready var camera: Camera2D = %Camera2D
@onready var visuals: Node2D = %Visuals
@onready var lines: Node2D = %Lines
@onready var nodes: Node2D = %MapNodes
@onready var map_generator: MapGenerator = %MapGenerator

var map_data: Array[Array]
var progress: int
var last_node: MapNodeData

var _target_y: float
var _min_camera_y: float
var _max_camera_y: float
var _mouse_down: bool = false
var _dragging: bool = false
var _drag_start: Vector2 = Vector2.ZERO
## The path chosen so far, one node per completed row — drives line highlights.
var _visited: Array[MapNodeData] = []
## One entry per drawn Line2D: { line, from, to }.
var _line_records: Array[Dictionary] = []


func _ready() -> void:
	camera.position.x = get_viewport_rect().size.x * 0.5
	generate_new_map()
	unlock_row(0)
	_compute_camera_bounds()
	_target_y = _max_camera_y
	camera.position.y = _target_y
	focus_row(0)


func _process(delta: float) -> void:
	var axis: float = Input.get_axis(&"up", &"down")
	if axis != 0.0:
		_target_y = clampf(_target_y + axis * KEY_SCROLL_SPEED * delta, _min_camera_y, _max_camera_y)
	camera.position.y = lerpf(camera.position.y, _target_y, 1.0 - exp(-CAMERA_SMOOTHING * delta))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"scroll_up"):
		_target_y = clampf(_target_y - WHEEL_STEP, _min_camera_y, _max_camera_y)
	elif event.is_action_pressed(&"scroll_down"):
		_target_y = clampf(_target_y + WHEEL_STEP, _min_camera_y, _max_camera_y)
	elif event is InputEventPanGesture:
		# Two-finger trackpad scroll (macOS delivers it as a pan gesture).
		_target_y = clampf(
			_target_y + event.delta.y * TRACKPAD_PAN_SPEED, _min_camera_y, _max_camera_y
		)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_mouse_down = event.pressed
		if event.pressed:
			_drag_start = event.position
		_dragging = false
	elif event is InputEventMouseMotion and _mouse_down:
		if not _dragging and _drag_start.distance_to(event.position) > DRAG_THRESHOLD:
			_dragging = true
		if _dragging:
			_target_y = clampf(_target_y - event.relative.y, _min_camera_y, _max_camera_y)
			camera.position.y = _target_y


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
	var map_width_pixels: int = MapGenerator.X_DIST * (MapGenerator.WIDTH - 1)
	visuals.position.x = (get_viewport_rect().size.x - map_width_pixels) / 2
	visuals.position.y = 0


func show_map() -> void:
	show()
	camera.enabled = true


func hide_map() -> void:
	hide()
	camera.enabled = false


## Glides the camera so `row` sits in the lower third of the screen.
func focus_row(row: int) -> void:
	var row_world_y: float = -row * MapGenerator.Y_DIST
	_target_y = clampf(row_world_y - ROW_FOCUS_OFFSET, _min_camera_y, _max_camera_y)


func unlock_row(row: int = progress) -> void:
	for map_node: MapNode in nodes.get_children():
		if map_node.node.coordinates.y == row:
			map_node.available = true


func unlock_next_nodes() -> void:
	for map_node: MapNode in nodes.get_children():
		if last_node.next_nodes.has(map_node.node):
			map_node.available = true
	focus_row(progress)


func _compute_camera_bounds() -> void:
	var half_height: float = get_viewport_rect().size.y * 0.5
	var content_top: float = -(MapGenerator.HEIGHT * MapGenerator.Y_DIST) - EDGE_MARGIN
	var content_bottom: float = EDGE_MARGIN
	_min_camera_y = content_top + half_height
	_max_camera_y = content_bottom - half_height
	if _min_camera_y > _max_camera_y:
		# Content shorter than the viewport: lock the camera on its middle.
		var middle: float = (content_top + content_bottom) * 0.5
		_min_camera_y = middle
		_max_camera_y = middle


func _add_map_node(node: MapNodeData) -> void:
	var new_map_node: MapNode = MapNode.new_map_node(node)
	new_map_node.selected.connect(_on_node_selected)
	new_map_node.hover_changed.connect(_on_node_hover_changed)
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
		new_map_line.default_color = LINE_COLOR_DEFAULT
		lines.add_child(new_map_line)
		_line_records.append({"line": new_map_line, "from": node, "to": next})


## Hovering a candidate node brightens the specific edge you would walk to
## reach it, so branching choices read at a glance. Row 0 has no incoming
## edges (last_node is null there), which falls out naturally.
func _on_node_hover_changed(node: MapNodeData, hovered: bool) -> void:
	for record: Dictionary in _line_records:
		if record["to"] == node and record["from"] == last_node:
			var line: Line2D = record["line"]
			line.default_color = LINE_COLOR_HOVER if hovered else LINE_COLOR_DEFAULT


## Brightens every line segment along the path actually walked this run.
func _update_traveled_lines() -> void:
	for record: Dictionary in _line_records:
		var line: Line2D = record["line"]
		if _visited.has(record["from"]) and _visited.has(record["to"]):
			line.default_color = LINE_COLOR_TRAVELED


func _on_node_selected(node: MapNodeData) -> void:
	for map_node: MapNode in nodes.get_children():
		if map_node.node.coordinates.y == node.coordinates.y:
			map_node.available = false
			if map_node.node != node:
				map_node.set_dimmed()

	_visited.append(node)
	_update_traveled_lines()
	last_node = node
	progress += 1
	node_selected.emit(node)
