class_name Map
extends Node2D

signal selected(room: Room)

## The whole tree is laid out to fit one screen (see [MapGenerator]), so the
## camera is parked at the viewport centre and never moves: no scrolling, and
## no panning while a fuse burns. Only the arrival shake touches it.
const MAP_FUSE: PackedScene = preload("res://src/gameplay/map/visuals/MapFuse.tscn")

## Every path converges on the final room, so those last cords are drawn a
## little thicker: one braided master fuse feeding the castle.
const MASTER_CORD_WIDTH: float = 6.0

const SHAKE_PIXELS: float = 2.0
const SHAKE_DURATION: float = 0.15
const SHAKE_STEPS: int = 3

@onready var camera: Camera2D = %Camera2D
@onready var visuals: Node2D = %Visuals
@onready var lines: Node2D = %Lines
@onready var nodes: Node2D = %MapNodes
@onready var map_generator: MapGenerator = %MapGenerator

var map_data: Array[Array]
var progress: int
var last_room: Room

var _fuses: Dictionary[Vector4i, MapFuse] = {}


func _ready() -> void:
	# Centring the camera on the viewport makes the visible world rect exactly
	# (0, 0)-(viewport), which is what create_map() lays the tree out against.
	camera.position = get_viewport_rect().size * .5

	generate_new_map()
	unlock_row(0)

func generate_new_map() -> void:
	progress = 0
	map_data = map_generator.generate_map()
	create_map()

func create_map() -> void:
	_clear_map_visuals()

	for current_row: Array in map_data:
		for room: Room in current_row:
			if room.next_nodes.size() > 0:
				_add_map_node(room)

	# Final Room Needs Manual Spawning (once, not per row)
	var middle: int = floori(MapGenerator.WIDTH * .5)
	_add_map_node(map_data[MapGenerator.LENGTH - 1][middle])

	_centre_visuals()

	# Rebuilding a map mid-run: everything already cut off stays a dud.
	_refresh_dud_fuses()

## Centres on the rooms that actually exist rather than on the nominal grid.
## Paths only drift one lane per step, so a run's five paths routinely leave
## whole lanes of the grid empty; centring on the grid would then pin a
## perfectly good tree against one edge with dead dirt opposite it.
func _centre_visuals() -> void:
	var children: Array[Node] = nodes.get_children()
	if children.is_empty():
		return

	var top_left: Vector2 = (children[0] as MapNode).position
	var bottom_right: Vector2 = top_left
	for map_node: MapNode in children:
		top_left = top_left.min(map_node.position)
		bottom_right = bottom_right.max(map_node.position)

	# Positions are icon centres, so the occupied rect is a half-icon wider on
	# every side. That cancels out of the centring, but it is what guarantees
	# the tree clears the edges of the screen.
	var occupied: Vector2 = bottom_right - top_left
	visuals.position = (((get_viewport_rect().size - occupied) * .5) - top_left).floor()

func show_map() -> void:
	show()
	camera.enabled = true

func hide_map() -> void:
	hide()
	camera.enabled = false

func unlock_row(row: int = progress) -> void:
	for map_node: MapNode in nodes.get_children():
		if map_node.room.coordinates.y == row:
			map_node.available = true

	_refresh_path_hints()

## Called when the player comes back from a room, which is the one moment the
## map knows that room is finished — so it is also where the charge goes off
## and the room swaps to its blown-up face.
func unlock_next_nodes() -> void:
	if last_room == null:
		return

	_seal_room(last_room)

	for map_node: MapNode in nodes.get_children():
		if last_room.next_nodes.has(map_node.room):
			map_node.available = true

	_refresh_path_hints()

func _add_map_node(room: Room) -> void:
	var new_map_node: MapNode = MapNode.new_map_node(room)
	new_map_node.selected.connect(_on_node_selected)
	nodes.add_child(new_map_node)
	_connect_fuses(room)

	if room.selected and room.coordinates.y < progress:
		new_map_node.show_spent()

func _connect_fuses(room: Room) -> void:
	if room.next_nodes.size() < 1:
		return

	for next: Room in room.next_nodes:
		var fuse: MapFuse = _add_fuse(room.coordinates, room.position, next.coordinates, next.position)

		if next.type == Room.Type.FINAL:
			fuse.set_cord_width(MASTER_CORD_WIDTH)

		# Both ends already behind the run's progress means this edge was
		# travelled before the map was rebuilt: char it without animating.
		if room.selected and next.selected and next.coordinates.y < progress:
			fuse.set_burnt()

## Builds one fuse and files it under both endpoints so it can be found again.
func _add_fuse(from_coordinates: Vector2i, from_position: Vector2, to_coordinates: Vector2i, to_position: Vector2) -> MapFuse:
	var fuse: MapFuse = MAP_FUSE.instantiate()
	# Added first: setup() reaches for the fuse's own @onready children.
	lines.add_child(fuse)
	fuse.setup(from_position, to_position)

	_fuses[_fuse_key(from_coordinates, to_coordinates)] = fuse
	return fuse

func _clear_map_visuals() -> void:
	_fuses.clear()

	var stale: Array[Node] = []
	stale.append_array(lines.get_children())
	stale.append_array(nodes.get_children())

	for child: Node in stale:
		child.get_parent().remove_child(child)
		child.queue_free()

func _on_node_selected(room: Room) -> void:
	for map_node: MapNode in nodes.get_children():
		if map_node.room.coordinates.y == room.coordinates.y:
			map_node.available = false

	# The node's own 0.5s selected animation has already played, so the player
	# reads it as: node reacts -> spark travels -> level loads.
	await _burn_to(room)

	last_room = room
	progress += 1
	_refresh_dud_fuses()
	selected.emit(room)

func _seal_room(room: Room) -> void:
	if room == null:
		return

	for map_node: MapNode in nodes.get_children():
		if map_node.room == room:
			map_node.detonate()
			return

func _burn_to(room: Room) -> void:
	# The opening pick has nothing behind it to burn: row 0 has no parents.
	if last_room == null:
		return

	var fuse: MapFuse = _fuses.get(_fuse_key(last_room.coordinates, room.coordinates), null)
	if fuse == null:
		push_warning("Map: no fuse between %s and %s" % [last_room.coordinates, room.coordinates])
		return

	_clear_path_hints()
	# No camera work here: the spark is already on screen wherever it travels.
	await fuse.burn()
	await _shake_camera()

## Shakes via offset rather than position so the camera always settles back on
## the centred map, and is awaited so the shake finishes before the level loads.
func _shake_camera() -> void:
	var step_time: float = SHAKE_DURATION / float(SHAKE_STEPS + 1)
	var tween: Tween = create_tween()
	for step: int in SHAKE_STEPS:
		var offset: Vector2 = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * SHAKE_PIXELS
		tween.tween_property(camera, ^"offset", offset, step_time)
	tween.tween_property(camera, ^"offset", Vector2.ZERO, step_time)

	await tween.finished

## Any cord whose source room can no longer be reached is a road that closed.
func _refresh_dud_fuses() -> void:
	if last_room == null:
		return

	var reachable: Dictionary[Vector2i, bool] = {}
	var pending: Array[Room] = []
	pending.append(last_room)

	while not pending.is_empty():
		var room: Room = pending.pop_back()
		if reachable.has(room.coordinates):
			continue

		reachable[room.coordinates] = true
		for next: Room in room.next_nodes:
			pending.append(next)

	for key: Vector4i in _fuses:
		var fuse: MapFuse = _fuses[key]
		# Already travelled: charred wins over dud, they mean opposite things.
		if fuse.state == MapFuse.State.BURNT:
			continue

		if not reachable.has(Vector2i(key.x, key.y)):
			fuse.set_dud()

func _refresh_path_hints() -> void:
	_clear_path_hints()

	# Nothing leads into row 0, so there is no cord to advertise on the first pick.
	if last_room == null:
		return

	for map_node: MapNode in nodes.get_children():
		if not map_node.available:
			continue

		var fuse: MapFuse = _fuses.get(_fuse_key(last_room.coordinates, map_node.room.coordinates), null)
		if fuse != null:
			fuse.set_hinted(true)

func _clear_path_hints() -> void:
	for fuse: MapFuse in _fuses.values():
		fuse.set_hinted(false)

static func _fuse_key(from_coordinates: Vector2i, to_coordinates: Vector2i) -> Vector4i:
	return Vector4i(from_coordinates.x, from_coordinates.y, to_coordinates.x, to_coordinates.y)
