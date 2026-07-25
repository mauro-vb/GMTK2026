class_name PogoArea
extends Area2D

func _ready() -> void:
	collision_layer = 1 << 6  # bit value 64 -> layer 7
	collision_mask = 0
