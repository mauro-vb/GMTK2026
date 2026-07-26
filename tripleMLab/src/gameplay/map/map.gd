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

## The dirt inside the stone frame of assets/art/map/background.png, which is
## the whole of where the tree belongs. Measured off the art on a 320x180 screen
## and then pulled a pixel or two further in, so a room never sits half on the
## stonework.
##
## Not a symmetric inset: the frame is not symmetric. The side pillars end at
## x=17 and x=304 and the bottom course starts at y=166, but the top of the wall
## is a deep band of rubble reaching down to y≈43 — three times the bottom. An
## even margin therefore reads as the whole map sitting too high, so this is
## measured against each edge's own masonry rather than one number applied four
## times.
const PLAY_AREA: Rect2 = Rect2(18, 32, 284, 138)

## Half of the space one room icon occupies: icons are 20x26 at the largest, the
## final room wears [constant MapNode.FINAL_SCALE] on top of that, and every one
## of them carries a shadow a couple of pixels down and right. The tree is fitted
## by node *centres*, so this is the slack that keeps the outermost icons clear
## of the frame rather than merely their middles.
const ICON_HALF_EXTENTS: Vector2 = Vector2(16, 16)

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
## What one grid unit of the generator's layout is worth on screen, per axis, so
## that the whole grid lands inside [constant PLAY_AREA] — under 1 on x, which
## the frame is too narrow for, and over 1 on y, which it has room to spare on.
## See [method _fit_layout].
var _layout_scale: Vector2 = Vector2.ONE


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

	_fit_layout()
	var drawn: Array[Room] = _drawn_rooms()

	for room: Room in drawn:
		_add_map_node(room)

	_centre_visuals()

	# Rebuilding a map mid-run: everything already cut off stays a dud.
	_refresh_dud_fuses()

## Every room that ends up on screen, in draw order. A room with no outgoing
## cords is one no path reaches, and the final room hangs off the end of the
## grid rather than being connected out of it, so neither falls out of a plain
## sweep of the rows.
func _drawn_rooms() -> Array[Room]:
	var drawn: Array[Room] = []

	for current_row: Array in map_data:
		for room: Room in current_row:
			if room.next_nodes.size() > 0:
				drawn.append(room)

	# Final Room Needs Manual Spawning (once, not per row)
	var middle: int = floori(MapGenerator.WIDTH * .5)
	drawn.append(map_data[MapGenerator.LENGTH - 1][middle])

	return drawn

## Fits the generator's grid to the dirt, so a step and a lane are worth whatever
## the frame has room for.
##
## [MapGenerator] lays rooms out on a grid of fixed pixel distances ([constant
## MapGenerator.STEP_DIST] per step, [constant MapGenerator.LANE_DIST] per lane),
## sized against the bare 320x180 screen — nine steps of which come to more than
## the framed area, while the five lanes come to less than it. Rather than
## re-tune those constants against the art every time either changes, the room
## *positions* are scaled and the icons are left alone: scaling [member visuals]
## instead would put every sprite on a fractional scale, and this is pixel art.
##
## Fitted against the nominal grid rather than against the rooms actually dealt,
## and per axis. Against the grid, because a run whose paths only ever touch two
## lanes would otherwise have those two lanes stretched to the full height of the
## frame, and a map's spacing would change with its luck. Per axis, because the
## two axes are wrong in opposite directions here, and one uniform number would
## have to pick which of them to keep.
func _fit_layout() -> void:
	# What is left of the play area once a half-icon is set aside at each end,
	# because what is being fitted is the span between icon *centres*.
	var available: Vector2 = PLAY_AREA.size - ICON_HALF_EXTENTS * 2.0
	# The grid at full extent: every step out to the final room, which sits one
	# step past the last row, and every lane. Placement jitter rides on top of
	# that (see MapGenerator.PLACEMENT_RANDOMNESS) and is counted so the shove it
	# gives the outermost rooms cannot push them into the stonework.
	var grid: Vector2 = Vector2(
		MapGenerator.LENGTH * MapGenerator.STEP_DIST,
		(MapGenerator.WIDTH - 1) * MapGenerator.LANE_DIST + MapGenerator.PLACEMENT_RANDOMNESS,
	)

	_layout_scale = available / grid

## The on-screen position of a room, i.e. its generated position after
## [method _fit_layout]. Floored so icons stay on whole pixels.
func _layout_position(room: Room) -> Vector2:
	return (room.position * _layout_scale).floor()

## Centres on the rooms that actually exist rather than on the nominal grid, and
## within the framed dirt rather than the whole screen. Paths only drift one lane
## per step, so a run's five paths routinely leave whole lanes of the grid empty;
## centring on the grid would then pin a perfectly good tree against one edge
## with dead dirt opposite it.
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
	# every side. That cancels out of the centring, but it is what _fit_layout
	# has already made room for.
	var occupied: Vector2 = bottom_right - top_left
	visuals.position = (PLAY_AREA.position + ((PLAY_AREA.size - occupied) * .5) - top_left).floor()

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
	var new_map_node: MapNode = MapNode.new_map_node(room, _layout_position(room))
	new_map_node.selected.connect(_on_node_selected)
	new_map_node.hover_entered.connect(_on_node_hover_entered)
	new_map_node.hover_exited.connect(_on_node_hover_exited)
	nodes.add_child(new_map_node)
	_connect_fuses(room)

	if room.selected and room.coordinates.y < progress:
		new_map_node.show_spent()

func _connect_fuses(room: Room) -> void:
	if room.next_nodes.size() < 1:
		return

	for next: Room in room.next_nodes:
		var fuse: MapFuse = _add_fuse(
			room.coordinates, _layout_position(room),
			next.coordinates, _layout_position(next),
		)

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

	# The click's whole answer: the spark leaves the last room, runs down the
	# cord and the level loads where it lands. Nothing animates on the node
	# itself first — that only delayed the one thing worth watching.
	await _burn_to(room)

	last_room = room
	progress += 1
	_refresh_dud_fuses()
	selected.emit(room)

## The room the cursor just entered steps forward; every other still-available
## room steps back a touch so the one under the cursor reads as the pick.
func _on_node_hover_entered(room: Room) -> void:
	for map_node: MapNode in nodes.get_children():
		if not map_node.available:
			continue

		if map_node.room == room:
			map_node.set_hover_scale(MapNode.HOVER_SCALE)
		else:
			map_node.set_hover_scale(MapNode.HOVER_NEIGHBOR_SCALE)

## Only resets once the cursor has actually left a room, not on every exit
## event a fast mouse can fire while crossing between two adjacent nodes.
func _on_node_hover_exited(_room: Room) -> void:
	for map_node: MapNode in nodes.get_children():
		if map_node.available:
			map_node.set_hover_scale(1.0)

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
