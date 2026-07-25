class_name ModifierIcon
extends TextureRect
## A single modifier icon. Owns its hover animation and custom tooltip.

const SCENE: PackedScene = preload("uid://dvry5nrjrrnif")
const ICON_SIZE: Vector2 = Vector2(16, 16)
const HOVER_SCALE: float = 1.25
const HOVER_DURATION: float = 0.12

var modifier: Modifier

var _hover_tween: Tween

static func new_modifier_icon(m: Modifier) -> ModifierIcon:
	var new_icon: ModifierIcon = SCENE.instantiate()
	new_icon.modifier = m
	return new_icon

func _ready() -> void:
	custom_minimum_size = ICON_SIZE
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mouse_filter = Control.MOUSE_FILTER_STOP
	pivot_offset = ICON_SIZE / 2.0

	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func setup(p_modifier: Modifier, p_texture: Texture2D) -> void:
	modifier = p_modifier
	texture = p_texture
	# Non-empty tooltip_text is what makes the engine call _make_custom_tooltip at all;
	# the actual content is built there instead.
	tooltip_text = "%s\n%s" % [modifier.modifier_name, modifier.get_description()]

func play_trigger_animation() -> void:
	# Call this when the modifier actually procs/triggers, separate from hover.
	var tween: Tween = create_tween()
	tween.tween_property(self, "scale", Vector2.ONE * 1.4, 0.08) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2.ONE, 0.15) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

func _on_mouse_entered() -> void:
	_animate_scale(Vector2.ONE * HOVER_SCALE)

func _on_mouse_exited() -> void:
	_animate_scale(Vector2.ONE)

func _animate_scale(target: Vector2) -> void:
	if _hover_tween != null and _hover_tween.is_valid():
		_hover_tween.kill()
	_hover_tween = create_tween()
	_hover_tween.tween_property(self, "scale", target, HOVER_DURATION) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _make_custom_tooltip(_text: String) -> Object:
	var panel: PanelContainer = PanelContainer.new()
	var vbox: VBoxContainer = VBoxContainer.new()
	panel.add_child(vbox)

	var name_label: Label = Label.new()
	name_label.text = modifier.modifier_name
	name_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(name_label)

	var desc_label: Label = Label.new()
	desc_label.text = modifier.get_description()
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_label.custom_minimum_size.x = 200
	vbox.add_child(desc_label)

	return panel
