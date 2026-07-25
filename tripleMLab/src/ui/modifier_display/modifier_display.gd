class_name ModifierDisplay
extends Control
## A row of icons for the modifiers the player is currently carrying. Hovering an
## icon shows that modifier's name and description as a tooltip.

# Signals
# Enums

# Constants
const PLACEHOLDER_ICON: Texture2D = preload("res://assets/art/ui/icons/uglyface.png")
# Exports
# Public

# Private
var _icons: Dictionary[Modifier, ModifierIcon] = {}
# On Ready
@onready var icon_container: HBoxContainer = %IconContainer
# Static

# Lifecycle
func _ready() -> void:
	if Global.main_game == null or Global.main_game.modifiers_system == null:
		push_error("ModifierDisplay: ModifiersSystem is missing.")
		return
	var modifiers_system: ModifiersSystem = Global.main_game.modifiers_system
	# The display is created per HUD swap, so catch up on what's already held.
	for modifier: Modifier in modifiers_system.modifiers:
		_on_modifier_added(modifier)
	modifiers_system.modifier_added.connect(_on_modifier_added)
	modifiers_system.modifier_removed.connect(_on_modifier_removed)
# Public
# Private

# Callbacks
func _on_modifier_added(modifier: Modifier) -> void:
	var texture: Texture2D = modifier.icon as Texture2D
	var icon: ModifierIcon = ModifierIcon.new_modifier_icon(modifier)
	icon.setup(modifier, texture if texture != null else PLACEHOLDER_ICON)
	icon_container.add_child(icon)
	_icons[modifier] = icon
	
func _on_modifier_removed(modifier: Modifier) -> void:
	var icon: ModifierIcon = _icons.get(modifier)
	if icon == null:
		return
	_icons.erase(modifier)
	icon.queue_free()
