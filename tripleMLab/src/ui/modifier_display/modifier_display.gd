class_name ModifierDisplay
extends Control
## A row of icons for the modifiers the player is currently carrying. Hovering an
## icon shows that modifier's name and description as a tooltip.
##
## Every modifier draws the same placeholder icon unless it brought its own —
## there is no per-modifier icon set yet.

# Signals
# Enums
# Constants
const PLACEHOLDER_ICON: Texture2D = preload("uid://ck9wv4mrh6tzb")
const ICON_SIZE: Vector2 = Vector2(16, 16)

# Exports

# Public
# Private
var _icons: Dictionary[Modifier, TextureRect] = {}
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

	var icon: TextureRect = TextureRect.new()
	icon.texture = texture if texture != null else PLACEHOLDER_ICON
	icon.custom_minimum_size = ICON_SIZE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_STOP
	icon.tooltip_text = "%s\n%s" % [modifier.modifier_name, modifier.get_description()]

	icon_container.add_child(icon)
	_icons[modifier] = icon


func _on_modifier_removed(modifier: Modifier) -> void:
	var icon: TextureRect = _icons.get(modifier)
	if icon == null:
		return
	_icons.erase(modifier)
	icon.queue_free()
