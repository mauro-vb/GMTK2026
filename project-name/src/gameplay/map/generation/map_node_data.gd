class_name MapNodeData
extends Resource

enum Type { NOT_ASSIGNED, LEVEL, SHOP, HEAL, FINAL }

@export var type: Type 
@export var position: Vector2
@export var coordinates: Vector2i
@export var next_nodes: Array[MapNodeData]
@export var selected: bool = false
var parents: Array[MapNodeData] = []

func _to_string() -> String:
	return "%s: (%s)" % [coordinates, Type.keys()[type][0]]
