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
##
## The deal is then corrected so that every set of chests the player is asked to
## pick between holds one of each — see [method _mixed_deal]. The weighting
## survives it: the correction moves as few chests as it can.
func _assign_treasure_tables() -> void:
	var treasure_set: TreasureSet = ResourceLoader.load(UIDs.TREASURE_SET_UID) as TreasureSet
	if treasure_set == null or treasure_set.good_table == null or treasure_set.corrupted_table == null \
			or treasure_set.good_coin_table == null or treasure_set.corrupted_coin_table == null:
		push_error("MapGenerator: no TreasureSet to deal chests from.")
		return

	var all_chests: Array[Room] = []

	for current_row: Array[Room] in map_data:
		var chests: Array[Room] = []
		for node: Room in current_row:
			if node.type == Room.Type.TREASURE and node.next_nodes.size() > 0:
				chests.append(node)

		var dealt: Array[bool] = _mixed_deal(treasure_set.deal(chests.size()), chests)
		for index: int in chests.size():
			_stock_chest(chests[index], dealt[index], treasure_set)

		all_chests.append_array(chests)

	_guarantee_both_chests(all_chests, treasure_set)

func _stock_chest(chest: Room, corrupted: bool, treasure_set: TreasureSet) -> void:
	chest.is_corrupted = corrupted
	chest.treasure = treasure_set.table_for(corrupted)
	chest.treasure_coin = treasure_set.coin_table_for(corrupted)

## Corrects a row's deal so that no set of chests the player picks between comes
## up all good or all corrupted, because a row of chests that all pay — or all
## bite — is not a decision, it is a formality with extra steps.
##
## A chest wears its fate on its face (see [method MapNode._art_pair_for_room]),
## so this is the whole of what the chest row asks: look at what is on offer and
## take the one you want. That only exists if there is something to weigh.
##
## Two things count as a set: the row as a whole, and the chests any one room
## leads into — the row can hold both kinds and still deal a given player two
## good ones, if those happen to be the only two cords out of where they stand.
##
## Rather than reroll until the deal happens to come out mixed, every pattern of
## fates the row could wear is scored — there are at most 2^[constant WIDTH] of
## them — and the winner is the one satisfying the most sets, breaking ties
## toward whatever is closest to the weighted deal it was handed. So the 2:1
## lean is kept wherever it does not cost the player a choice, and the smallest
## possible number of chests are turned over where it does.
##
## Scored rather than solved because the sets can genuinely conflict: three rooms
## offering the pairs (a,b), (b,c) and (a,c) cannot all be mixed with two kinds
## of chest. Rare, but the generator is free to build it, so this settles for the
## best available instead of hunting for a perfection that may not exist.
func _mixed_deal(dealt: Array[bool], chests: Array[Room]) -> Array[bool]:
	var count: int = chests.size()
	if count < 2:
		return dealt

	var sets: Array[Array] = _chest_choice_sets(chests)

	var best: Array[bool] = dealt
	var best_satisfied: int = -1
	var best_distance: int = 0

	for pattern: int in 1 << count:
		var candidate: Array[bool] = []
		for index: int in count:
			candidate.append(pattern & (1 << index) != 0)

		var satisfied: int = _sets_satisfied(candidate, sets)
		var distance: int = _deal_distance(candidate, dealt)

		if satisfied > best_satisfied or (satisfied == best_satisfied and distance < best_distance):
			best = candidate
			best_satisfied = satisfied
			best_distance = distance

	return best

## Every group of chests in a row that has to hold one of each, as indices into
## [param chests]: the row itself, plus one group per room feeding into it.
##
## A room offering only one chest is left out — there is nothing to pick between
## — and so is any chest with no cords out of it, since those are never drawn and
## the player can never stand in front of them.
func _chest_choice_sets(chests: Array[Room]) -> Array[Array]:
	var sets: Array[Array] = []

	var whole_row: Array[int] = []
	for index: int in chests.size():
		whole_row.append(index)
	sets.append(whole_row)

	var parents: Array[Room] = []
	for chest: Room in chests:
		for parent: Room in chest.parents:
			if not parents.has(parent):
				parents.append(parent)

	for parent: Room in parents:
		var offered: Array[int] = []
		for next: Room in parent.next_nodes:
			var index: int = chests.find(next)
			if index >= 0 and not offered.has(index):
				offered.append(index)

		if offered.size() > 1:
			sets.append(offered)

	return sets

func _sets_satisfied(candidate: Array[bool], sets: Array[Array]) -> int:
	var satisfied: int = 0

	for choice: Array in sets:
		var has_good: bool = false
		var has_corrupted: bool = false
		for index: int in choice:
			if candidate[index]:
				has_corrupted = true
			else:
				has_good = true

		if has_good and has_corrupted:
			satisfied += 1

	return satisfied

## How many chests [param candidate] turns over relative to the weighted deal.
func _deal_distance(candidate: Array[bool], dealt: Array[bool]) -> int:
	var distance: int = 0
	for index: int in candidate.size():
		if candidate[index] != dealt[index]:
			distance += 1

	return distance

## The backstop for a map whose chests never share a row: [method _mixed_deal]
## can only mix a row it is given two chests of, so a run that scatters its
## chests one to a row could still come up all good or all corrupted. One chest
## is turned over so the run has seen both kinds by the end of it.
func _guarantee_both_chests(chests: Array[Room], treasure_set: TreasureSet) -> void:
	if chests.size() < 2:
		return

	var good: Array[Room] = []
	var corrupted: Array[Room] = []
	for chest: Room in chests:
		if chest.is_corrupted:
			corrupted.append(chest)
		else:
			good.append(chest)

	if not good.is_empty() and not corrupted.is_empty():
		return

	var all_alike: Array[Room] = corrupted if good.is_empty() else good
	var odd_one_out: Room = all_alike[randi_range(0, all_alike.size() - 1)]
	_stock_chest(odd_one_out, not odd_one_out.is_corrupted, treasure_set)

## Types are picked first and the scene each one loads is resolved after, so a
## room only has to be told what it is, never what file that means.
##
## Only rooms the player can actually reach are dealt a scene. Rooms with no
## outgoing cords are the ones no path leads to and [method Map.create_map]
## never draws them — dealing them a level would spend entries out of the pool's
## bag on rooms nobody visits, and the run would start repeating levels early.
func _apply_scene_uids() -> void:
	var pool: LevelPool = LevelPool.new()
	for current_row: Array[Room] in map_data:
		for node: Room in current_row:
			if node.next_nodes.is_empty() and node.type != Room.Type.FINAL:
				continue
			node.apply_type_scene(pool)

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
	
