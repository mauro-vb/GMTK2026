class_name MapGenerator
extends Node

# Visual
## The map runs left to right: a row of the grid is one step along the run and
## is spaced by [constant STEP_DIST] on x, while the parallel branches within a
## row fan out down the screen, spaced by [constant LANE_DIST] on y. Both are
## sized so the whole tree fits one 640x360 screen without scrolling.
const STEP_DIST: int = 32
const LANE_DIST: int = 24
## Kept small: room icons are 26px and cords pass under them, so a big jitter
## would let neighbours touch and swallow the fuse between them.
const PLACEMENT_RANDOMNESS: int = 4

# Size
const LENGTH: int = 9
const WIDTH: int = 5
const PATHS: int = 3

# Room type distribution
const LEVEL_ROOM_WEIGHT: float = 10.0
const WORKSHOP_ROOM_WEIGHT: float = 2.5
const TREASURE_ROOM_WEIGHT: float = 4.0

var random_node_type_total_weights: Dictionary[Room.Type, float] = {
	Room.Type.LEVEL: 0.0,
	Room.Type.WORKSHOP: 0.0,
	Room.Type.TREASURE: 0.0,
}

var random_node_type_total_weight: float = 0.0

var map_data: Array[Array]

func generate_map() -> Array[Array]:
	map_data = _generate_initial_grid()
	var starting_points: Array[int] = _get_random_starting_points()
	
	for x: int in starting_points:
		var current_x: int = x
		for y in LENGTH - 1:
			current_x = _setup_connection(y, current_x)
	
	_setup_final_node()
	_setup_random_node_weights()
	_setup_node_types()
	_assign_treasure_tables()
	_apply_scene_uids()

	return map_data
	
func _generate_initial_grid() -> Array[Array]:
	var result: Array[Array] = []
	
	for y: int in LENGTH:
		var adjacent_rooms: Array[Room] = []
		for x: int in WIDTH:
			var current_map_node: Room = Room.new()
			var offset: Vector2 = Vector2(randf(), randf()) * PLACEMENT_RANDOMNESS
			current_map_node.position = Vector2(y * STEP_DIST, x * LANE_DIST) + offset
			current_map_node.coordinates = Vector2i(x, y)
			current_map_node.next_nodes = []

			# Final Room shouldn't be random: it sits one step past the last row
			# and dead centre of the lanes, so the master fuses visibly converge.
			if y == LENGTH - 1:
				current_map_node.position = Vector2((y + 1) * STEP_DIST, (WIDTH - 1) * .5 * LANE_DIST)

			adjacent_rooms.append(current_map_node)
		result.append(adjacent_rooms)
	return result

func _get_random_starting_points() -> Array[int]:
	var starting_points: Array[int]
	var unique_points: int = 0
	
	while unique_points < 2:
		unique_points = 0
		starting_points = []
		
		for x: int in PATHS:
			var starting_point: int = randi_range(0, WIDTH - 1)
			if not starting_points.has(starting_point):
				unique_points += 1
			
			starting_points.append(starting_point)
		
	return starting_points

func _setup_connection(y: int, x: int) -> int:
	var next_node: Room = null
	var current_node: Room = map_data[y][x]
	
	while not next_node or _would_cross_existing_path(y, x, next_node):
		var randx: int = clampi(randi_range(x - 1, x + 1), 0, WIDTH - 1)
		next_node = map_data[y + 1][randx]
		
	current_node.next_nodes.append(next_node)
	next_node.parents.append(current_node)
	
	return next_node.coordinates.x

func _would_cross_existing_path(y: int, x: int, node: Room) -> bool:
	var left_n: Room = null
	var right_n: Room = null
	
	if x > 0:
		left_n = map_data[y][x - 1]
	if x < WIDTH - 1:
		right_n = map_data[y][x + 1]
	
	if right_n and node.coordinates.x > x:
		for next_node: Room in right_n.next_nodes:
			if next_node.coordinates.x <= x:
				return true
	
	if left_n and node.coordinates.x < x:
		for next_node: Room in left_n.next_nodes:
			if next_node.coordinates.x >= x:
				return true
	
	return false

func _setup_final_node() -> void:
	var middle: int = floori(WIDTH * .5)
	var final_node: Room = map_data[LENGTH - 1][middle]
	
	for x: int in WIDTH:
		var current_node: Room = map_data[LENGTH - 2][x]
		if current_node.next_nodes.size() > 0:
			current_node.next_nodes = [final_node] as Array[Room]
		
	final_node.type =  Room.Type.FINAL

func _setup_random_node_weights() -> void:
	random_node_type_total_weights[Room.Type.LEVEL] = LEVEL_ROOM_WEIGHT
	random_node_type_total_weights[Room.Type.TREASURE] = LEVEL_ROOM_WEIGHT + TREASURE_ROOM_WEIGHT
	random_node_type_total_weights[Room.Type.WORKSHOP] = LEVEL_ROOM_WEIGHT + TREASURE_ROOM_WEIGHT + WORKSHOP_ROOM_WEIGHT
	
	random_node_type_total_weight = random_node_type_total_weights[Room.Type.WORKSHOP]
	
func _setup_node_types() -> void:
	var set_full_row: Callable = func(y: int, type: Room.Type) -> void:
		for node: Room in map_data[y]:
			node.type = type
			
	# TODO: Come up with custom rules
	# Example set first floor always to LEVEL
	set_full_row.call(0, Room.Type.LEVEL)
	# The chest row. Every path crosses it, so halfway through a run every player
	# stands in front of a row of chests and has to pick one — which is the whole
	# point of dealing that row three different chests (see _assign_treasure_tables).
	set_full_row.call(floori(LENGTH * .5), Room.Type.TREASURE)
	
	for current_row: Array[Room] in map_data:
		for node: Room in current_row:
			for next_node: Room in node.next_nodes:
				if next_node.type == Room.Type.NOT_ASSIGNED:
					_set_node_randomly(next_node)
	
## Hands every chest on the map its fate.
##
## Dealt per row rather than rolled per room, weighted 2:1 good, so a row of
## three trends toward two good and one corrupted instead of each chest
## independently coming up however it likes. Rooms with no outgoing cords are
## the ones no path reaches and [method Map.create_map] never draws them, so
## they are left out of the deal rather than eating a slot in it.
func _assign_treasure_tables() -> void:
	var treasure_set: TreasureSet = ResourceLoader.load(UIDs.TREASURE_SET_UID) as TreasureSet
	if treasure_set == null or treasure_set.good_table == null or treasure_set.corrupted_table == null:
		push_error("MapGenerator: no TreasureSet to deal chests from.")
		return

	for current_row: Array[Room] in map_data:
		var chests: Array[Room] = []
		for node: Room in current_row:
			if node.type == Room.Type.TREASURE and node.next_nodes.size() > 0:
				chests.append(node)

		var dealt: Array[bool] = treasure_set.deal(chests.size())
		for index: int in chests.size():
			chests[index].is_corrupted = dealt[index]
			chests[index].treasure = treasure_set.table_for(dealt[index])

## Types are picked first and the scene each one loads is resolved after, so a
## room only has to be told what it is, never what file that means.
func _apply_scene_uids() -> void:
	for current_row: Array[Room] in map_data:
		for node: Room in current_row:
			node.apply_type_scene()

func _set_node_randomly(node: Room) -> void:
	var is_consecutive_type: Callable = func(candidate: Room.Type, type: Room.Type) -> bool:
		return candidate == type and _node_has_parent_of_type(node, type)
	# TODO: Setup Custom Rules
	# Examples:
	# No chests in the first three rows
	var treasure_before_3: bool = true
	# No consecutive chests
	var consecutive_treasure: bool = true
	# No consecutive workshops
	var consecutive_workshop: bool = true
	# No chest immediately after the row that is forced to be chests
	var treasure_on_forced_row: bool = true

	var type_candidate: Room.Type = Room.Type.NOT_ASSIGNED
	
	while treasure_before_3 or consecutive_treasure or consecutive_workshop or treasure_on_forced_row:
		type_candidate = _get_random_node_type_by_weight()
		
		treasure_before_3 = type_candidate == Room.Type.TREASURE and node.coordinates.y < 3
		consecutive_treasure = is_consecutive_type.call(type_candidate, Room.Type.TREASURE)
		consecutive_workshop = is_consecutive_type.call(type_candidate, Room.Type.WORKSHOP)
		treasure_on_forced_row = type_candidate == Room.Type.TREASURE and node.coordinates.y == floori(LENGTH * .5) + 1
		
	node.type = type_candidate
	
	
func _get_random_node_type_by_weight() -> Room.Type:
	var roll: float = randf_range(.0, random_node_type_total_weight)
	
	for type: Room.Type in random_node_type_total_weights:
		if random_node_type_total_weights[type] > roll:
			return type
			
	return Room.Type.LEVEL
	
func _node_has_parent_of_type(node: Room, type: Room.Type) -> bool:
	for parent: Room in node.parents:
		if parent.type == type:
			return true
			
	return false
	
