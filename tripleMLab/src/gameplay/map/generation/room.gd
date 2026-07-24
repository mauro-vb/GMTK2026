class_name Room
extends Resource

enum Type { NOT_ASSIGNED, LEVEL, SHOP, HEAL, EVENT, FINAL }

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
