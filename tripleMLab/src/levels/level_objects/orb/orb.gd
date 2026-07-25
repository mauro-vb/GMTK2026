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
	var modifier_type: Modifier.Type = Modifier.Type.COLD_ORB_TOUCHED if type == Type.COLD else Modifier.Type.HOT_ORB_TOUCHED
	var modifiers_system: ModifiersSystem = Global.main_game.modifiers_system

	# A blocking modifier ("Coating") eats the orb whole: it's still picked up,
	# but it neither changes the clock nor fires its orb-touched modifiers.
	if modifiers_system.is_orb_blocked(modifier_type):
		collected.emit(type)
		queue_free()
		return

	var value: float = TIME_ADDED if type == Type.COLD else -TIME_ADDED
	value = modifiers_system.modify_orb_value(modifier_type, value)
	Global.main_game.time_system.add_time(value)
	modifiers_system.activate_modifiers(modifier_type)
	collected.emit(type)
	queue_free()
