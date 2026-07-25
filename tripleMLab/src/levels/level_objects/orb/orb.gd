class_name Orb
extends Node2D

signal collected(orb_type)

enum Type { COLD, HOT }

const TIME_ADDED: int = 2
const TEXTURE_UIDs: Dictionary[Type, Texture2D] = {
	Type.COLD: preload("uid://bcvwcjovn3urq"),
	Type.HOT: preload("uid://dl6hdiixm8xoi")
}

@export var type: Type = Type.COLD
@onready var area: Area2D = %Area2D
@onready var sprite: Sprite2D = %Sprite2D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	sprite.texture = TEXTURE_UIDs[type]
	area.body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if body is not Player:
		return
	var value: int = TIME_ADDED if type == Type.COLD else -TIME_ADDED
	var modifier_type: Modifier.Type = Modifier.Type.COLD_ORB_TOUCHED if type == Type.COLD else Modifier.Type.HOT_ORB_TOUCHED
	Global.main_game.time_system.add_time(value)
	Global.main_game.modifiers_system.activate_modifiers(modifier_type)
	collected.emit(type)
	queue_free()
