@tool
class_name Orb
extends Node2D

signal collected(orb_type)

enum Type { COLD, HOT }

const TIME_ADDED: float = 2.5
const TIME_REMOVED: float = -5

const TEXTURES: Dictionary[Type, Texture2D] = {
	Type.COLD: preload("uid://bcvwcjovn3urq"),
	Type.HOT: preload("uid://dl6hdiixm8xoi"),
}

## Setter fires as soon as you change this in the Inspector, so the sprite
## updates live in the editor instead of only after a reload.
@export var type: Type = Type.COLD:
	set(value):
		type = value
		_refresh_sprite()

@onready var area: Area2D = %Area2D
@onready var sprite: Sprite2D = %Sprite2D


func _ready() -> void:
	# %Sprite2D isn't resolvable until the node is in the tree, which _init()
	# runs before — that's why the old version never painted in the editor.
	# _ready() runs both at runtime and in-editor (this script is @tool), so
	# this is the one place both need.
	_refresh_sprite()

	if Engine.is_editor_hint():
		return

	area.body_entered.connect(_on_body_entered)

func _refresh_sprite() -> void:
	# The @export setter can fire before @onready has run (e.g. right after
	# the node is constructed), so sprite may still be null here.
	if sprite == null:
		return

	sprite.texture = TEXTURES[type]

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

	var value: float = TIME_ADDED if type == Type.COLD else TIME_REMOVED
	value = modifiers_system.modify_orb_value(modifier_type, value)

	# add_time()/remove_time() aren't interchangeable with a signed amount: each
	# plays its own burst sfx, and add_time() only ever fires the gain flourish.
	# A modifier can flip the sign, so this reads what the value actually ended
	# up as rather than the orb's own type.
	var time_system: TimeSystem = Global.main_game.time_system
	if value > 0.0:
		time_system.add_time(value)
	elif value < 0.0:
		time_system.remove_time(-value)

	# Off the value, not off the orb's type: a modifier is allowed to turn the
	# sign around, and the flash has to report what actually happened to the
	# clock rather than what the sprite was going to do. A value modified to
	# nothing gets no flash, because nothing is what it did.
	if value < 0.0:
		(body as Player).play_hurt()
	elif value > 0.0:
		(body as Player).play_heal()

	modifiers_system.activate_modifiers(modifier_type)
	collected.emit(type)
	queue_free()
