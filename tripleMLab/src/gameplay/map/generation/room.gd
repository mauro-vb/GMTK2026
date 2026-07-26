class_name Room
extends Resource

enum Type { NOT_ASSIGNED, LEVEL, WORKSHOP, HEAL, EVENT, FINAL }

@export var type: Type
@export var scene_uid: String = UIDs.TEST_LEVEL_UID
var position: Vector2
var coordinates: Vector2i
var next_nodes: Array[Room]
var selected: bool = false
var parents: Array[Room] = []

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
