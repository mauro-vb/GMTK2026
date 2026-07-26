class_name Room
extends Resource

## TREASURE sits where HEAL used to, in the same enum position — enum values
## serialise as ints, so nothing that stored a room type was invalidated by the
## rename. The room was never a heal: it is a chest you gamble the clock on (see
## [TreasureRoom]), and calling it what it is stops the generator's rules from
## reading as though they were protecting a rest stop.
enum Type { NOT_ASSIGNED, LEVEL, WORKSHOP, TREASURE, EVENT, FINAL }

@export var type: Type
@export var scene_uid: String = UIDs.FALLBACK_LEVEL_UID
var position: Vector2
var coordinates: Vector2i
var next_nodes: Array[Room]
var selected: bool = false
var parents: Array[Room] = []

## Which chest this is, for TREASURE rooms only. Dealt by [MapGenerator] —
## [member is_corrupted] decides whether it's the good or the corrupted table —
## and read by [MapNode] for its icon and by [TreasureRoom] for the game it
## lays on. Null on every other room type.
var treasure: TreasureTable = null

## The same chest, shaped for a coin flip instead: coin needs exactly two
## outcomes, so it plays from its own table rather than [member treasure]
## (which carries a third, middling outcome for the wheel and the board).
## Null on every other room type.
var treasure_coin: TreasureTable = null

## Whether this TREASURE room always bites (true) or always pays (false).
## Decided once, at map-gen time, by [method MapGenerator._assign_treasure_tables]
## — a chest's fate isn't a roll inside the room, it's a fact about the room
## before the player ever walks in. [MapNode] reads it to tint the chest on the
## map. Meaningless on every other room type.
var is_corrupted: bool = false

## Whether an EVENT room is the good or the bad kind, for [MapNode]'s art —
## unset by anything yet, since [MapGenerator] doesn't produce EVENT rooms.
var event_positive: bool = false

func _to_string() -> String:
	return "%s: (%s)" % [coordinates, get_type()[0]]

func get_type() -> String:
	return Type.keys()[type]

## Points `scene_uid` at whatever this room's type loads. Called once the
## generator has finished assigning types, so a room is never left pointing at
## the fallback level just because it turned out to be a workshop.
##
## Workshops and chests are one scene each; levels are dealt by `pool`, which is
## why it is passed in rather than built here — one pool per map is what stops
## the same level turning up twice in a run (see [LevelPool]).
func apply_type_scene(pool: LevelPool) -> void:
	match type:
		Type.WORKSHOP:
			scene_uid = UIDs.WORKSHOP_SCENE_UID
		Type.TREASURE:
			scene_uid = UIDs.TREASURE_ROOM_SCENE_UID
		Type.LEVEL:
			scene_uid = pool.next_level_uid()
		Type.FINAL:
			scene_uid = pool.final_level_uid()
