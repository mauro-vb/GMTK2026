@tool
class_name PogoArea
extends Area2D

signal bounced
@onready var animated_sprite_2d: AnimatedSprite2D = %AnimatedSprite2D


func _init() -> void:
	collision_layer = 1 << 6  # bit value 64 -> layer 7
	collision_mask = 0

func _ready() -> void:
	bounced.connect(animate)

func animate() -> void:
	if animated_sprite_2d == null:
		return
	animated_sprite_2d.play("triggered")
