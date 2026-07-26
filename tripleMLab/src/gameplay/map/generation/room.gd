class_name Room
extends Resource

## TREASURE sits where HEAL used to, in the same enum position — enum values
## serialise as ints, so nothing that stored a room type was invalidated by the
## rename. The room was never a heal: it is a chest you gamble the clock on (see
## [TreasureRoom]), and calling it what it is stops the generator's rules from
## reading as though they were protecting a rest stop.
enum Type { NOT_ASSIGNED, LEVEL, WORKSHOP, TREASURE, EVENT, FINAL }

@export var type: Type
@export var scene_uid: String = UIDs.TEST_LEVEL_UID
var position: Vector2
var coordinates: Vector2i
var next_nodes: Array[Room]
var selected: bool = false
var parents: Array[Room] = []

## Which chest this is, for TREASURE rooms only. Dealt by [MapGenerator] so the
## chests along one row are three different bets rather than three rolls of the
## same one, and read by [MapNode] for its icon and by [TreasureRoom] for the
## game it lays on. Null on every other room type.
var treasure: TreasureTable = null

func _to_string() -> String:
	return "%s: (%s)" % [coordinates, get_type()[0]]

func get_type() -> String:
	return Type.keys()[type]

## Points `scene_uid` at whatever this room's type loads. Called once the
## generator has finished assigning types, so a room is never left pointing at
## the test level just because it turned out to be a workshop.
##
## Types not listed keep whatever `scene_uid` they already have — LEVEL rooms
## are meant to vary, so they are nobody's business but the level pool's.
func apply_type_scene() -> void:
	match type:
		Type.WORKSHOP:
			scene_uid = UIDs.WORKSHOP_SCENE_UID
		Type.TREASURE:
			scene_uid = UIDs.TREASURE_ROOM_SCENE_UID
