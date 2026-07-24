class_name MapGenerator
extends Node

# Visual
const X_DIST: int = 40
const Y_DIST: int = 30
const PLACEMENT_RANDOMNESS: int = 8

# Size
const HEIGHT: int = 13
const WIDTH: int = 8
const PATHS: int = 5

# Room type distribution
const LEVEL_ROOM_WEIGHT: float = 10.0
const SHOP_ROOM_WEIGHT: float = 2.5
const HEAL_ROOM_WEIGHT: float = 4.0

var random_node_type_total_weights: Dictionary[Room.Type, float] = {
	Room.Type.LEVEL: 0.0,
	Room.Type.SHOP: 0.0,
	Room.Type.HEAL: 0.0,
}

var random_node_type_total_weight: float = 0.0

var map_data: Array[Array]

func generate_map() -> Array[Array]:
	map_data = _generate_initial_grid()
	var starting_points: Array[int] = _get_random_starting_points()
	
	for x: int in starting_points:
		var current_x: int = x
		for y in HEIGHT - 1:
			current_x = _setup_connection(y, current_x)
	
	_setup_final_node()
	_setup_random_node_weights()
	_setup_node_types()
	
	return map_data
	
func _generate_initial_grid() -> Array[Array]:
	var result: Array[Array] = []
	
	for y: int in HEIGHT:
		var adjacent_rooms: Array[Room] = []
		for x: int in WIDTH:
			var current_map_node: Room = Room.new()
			var offset: Vector2 = Vector2(randf(), randf()) * PLACEMENT_RANDOMNESS
			current_map_node.position = Vector2(x * X_DIST, y * -Y_DIST) + offset
			current_map_node.coordinates = Vector2i(x, y)
			current_map_node.next_nodes = []
			
			# Final Room shouldn't be random
			if y == HEIGHT - 1:
				current_map_node.position.y = (y + 1) * -Y_DIST
			
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
	var final_node: Room = map_data[HEIGHT - 1][middle]
	
	for x: int in WIDTH:
		var current_node: Room = map_data[HEIGHT - 2][x]
		if current_node.next_nodes.size() > 0:
			current_node.next_nodes = [final_node] as Array[Room]
		
	final_node.type =  Room.Type.FINAL

func _setup_random_node_weights() -> void:
	random_node_type_total_weights[Room.Type.LEVEL] = LEVEL_ROOM_WEIGHT
	random_node_type_total_weights[Room.Type.HEAL] = LEVEL_ROOM_WEIGHT + HEAL_ROOM_WEIGHT
	random_node_type_total_weights[Room.Type.SHOP] = LEVEL_ROOM_WEIGHT + HEAL_ROOM_WEIGHT + SHOP_ROOM_WEIGHT
	
	random_node_type_total_weight = random_node_type_total_weights[Room.Type.SHOP]
	
func _setup_node_types() -> void:
	var set_full_row: Callable = func(y: int, type: Room.Type) -> void:
		for node: Room in map_data[y]:
			node.type = type
			
	# TODO: Come up with custom rules
	# Example set first floor always to LEVEL
	set_full_row.call(0, Room.Type.LEVEL)
	# Example set last floor always to HEAL
	set_full_row.call(floori(HEIGHT * .5), Room.Type.HEAL)
	
	for current_row: Array[Room] in map_data:
		for node: Room in current_row:
			for next_node: Room in node.next_nodes:
				if next_node.type == Room.Type.NOT_ASSIGNED:
					_set_node_randomly(next_node)
	
func _set_node_randomly(node: Room) -> void:
	var is_consecutive_type: Callable = func(candidate: Room.Type, type: Room.Type) -> bool:
		return candidate == type and _node_has_parent_of_type(node, type)
	# TODO: Setup Custom Rules
	# Examples: 
	# No heal below 4
	var heal_before_4: bool = true
	# No consecutive heals
	var consecutive_heal: bool = true
	# No consecutive shops
	var consecutive_shop: bool = true
	# No heals after specified row (that is forced to be heal)
	var heal_on_specific_row: bool = true

	var type_candidate: Room.Type = Room.Type.NOT_ASSIGNED
	
	while heal_before_4 or consecutive_heal or consecutive_shop or heal_on_specific_row:
		type_candidate = _get_random_node_type_by_weight()
		
		heal_before_4 = type_candidate == Room.Type.HEAL and node.coordinates.y < 3
		consecutive_heal = is_consecutive_type.call(type_candidate, Room.Type.HEAL)
		consecutive_shop = is_consecutive_type.call(type_candidate, Room.Type.SHOP)
		heal_on_specific_row = type_candidate == Room.Type.HEAL and node.coordinates.y == floori(HEIGHT * .5) + 1
		
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
	
