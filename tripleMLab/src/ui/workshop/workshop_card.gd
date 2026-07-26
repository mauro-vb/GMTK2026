class_name WorkshopCard
extends Button
## One modifier laid out on the workshop bench.
##
## A Button underneath, so focus, keyboard and gamepad confirmation, and click
## handling are the engine's problem rather than this script's. Everything the
## theme's own button art would draw is stripped off and replaced with the
## workshop's frame — see [WorkshopStyle], which owns every number used here.
##
## Hover and focus are deliberately the same state: pointing at a card moves
## focus to it, so there is only ever one card lit and the mouse and the stick
## can never disagree about which one it is. That single state rides on
## `_emphasis`, 0 at rest and 1 lit, and everything — border, glow, lift, scale —
## is a read of it.

# Signals
## Emitted when this card is taken. The bench decides what that means.
signal chosen(card: WorkshopCard)
## Emitted when this card becomes the lit one, so the detail panel can follow it.
signal highlighted(card: WorkshopCard)

# Enums
# Constants
const SCENE: PackedScene = preload("uid://dp5nt8crj4wxb")

# Exports

# Public
var entry: WorkshopEntry

## Set once the player takes this card. A taken card stays on the bench rather
## than vanishing, so a second pick still reads against what the first one was.
var taken: bool = false

# Private
var _emphasis: float = 0.0
var _emphasis_tween: Tween
var _motion_tween: Tween

# On Ready
@onready var visual: Control = %Visual
## Sits behind the card face, offset down and right — a shadow, not a halo. See
## [method WorkshopStyle.card_glow]; the node keeps its old name because it is
## still "the thing under a lifted card".
@onready var glow: Panel = %Glow
@onready var frame: PanelContainer = %Frame
@onready var seam: PanelContainer = %Seam
@onready var seam_label: Label = %SeamLabel
@onready var plinth: PanelContainer = %Plinth
@onready var icon_rect: TextureRect = %Icon
@onready var name_label: Label = %NameLabel
@onready var taken_overlay: Control = %TakenOverlay
@onready var taken_label: Label = %TakenLabel

# Static
static func new_card(workshop_entry: WorkshopEntry) -> WorkshopCard:
	var card: WorkshopCard = SCENE.instantiate()
	card.entry = workshop_entry
	return card

# Lifecycle
func _ready() -> void:
	_strip_theme_button()

	focus_mode = Control.FOCUS_ALL
	# The detail panel carries the description, so a tooltip would only be the
	# same text a second time, half a second later, over the top of the bench.
	tooltip_text = ""

	resized.connect(_on_resized)
	mouse_entered.connect(_on_mouse_entered)
	focus_entered.connect(_on_focus_entered)
	focus_exited.connect(_on_focus_exited)
	pressed.connect(_on_pressed)

	_apply_entry()
	_apply_emphasis(0.0)

# Public
## Lays the card on the bench: it rises into place and fades up, `delay` seconds
## after the sweep started. Cards are staggered so the bench is being set in
## front of the player rather than appearing around them.
func deal_in(delay: float) -> void:
	modulate.a = 0.0
	visual.position.y = WorkshopStyle.DEAL_RISE
	visual.scale = Vector2(0.92, 0.92)
	disabled = true

	# Every beat is a delayed parallel tweener rather than a chained sequence:
	# the stagger is just a delay, and there is no ordering left to get wrong.
	_motion_tween = _restart(_motion_tween).set_parallel(true)
	_motion_tween.tween_property(self, ^"modulate:a", 1.0, WorkshopStyle.DEAL_DURATION) \
		.set_delay(delay)
	_motion_tween.tween_property(visual, ^"position:y", 0.0, WorkshopStyle.DEAL_DURATION) \
		.set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_motion_tween.tween_property(visual, ^"scale", Vector2.ONE, WorkshopStyle.DEAL_DURATION) \
		.set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Live the moment it lands, so the first card is pickable while the last is
	# still on its way down.
	_motion_tween.tween_callback(func() -> void: disabled = taken) \
		.set_delay(delay + WorkshopStyle.DEAL_DURATION)

	await _motion_tween.finished


## Clears the card off the bench — a reroll, or leaving. Awaitable so the bench
## can wait for the last card before laying out the next set.
func sweep_out(delay: float) -> void:
	disabled = true
	_set_emphasis(false)

	_motion_tween = _restart(_motion_tween).set_parallel(true)
	_motion_tween.tween_property(self, ^"modulate:a", 0.0, WorkshopStyle.SWEEP_DURATION) \
		.set_delay(delay)
	_motion_tween.tween_property(visual, ^"position:y", WorkshopStyle.SWEEP_DROP, WorkshopStyle.SWEEP_DURATION) \
		.set_delay(delay).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	await _motion_tween.finished


## The card the player took: punches out, flashes white at the peak, settles
## back stamped. Same beats as a charge going off on the map, on purpose.
func play_taken() -> void:
	taken = true
	disabled = true
	# Keyboard and gamepad navigation walks focus_mode, not `disabled`, so a
	# taken card has to leave the running order or the stick still stops on it.
	focus_mode = Control.FOCUS_NONE
	_set_emphasis(false)

	var punch: float = WorkshopStyle.TAKE_PUNCH
	_motion_tween = _restart(_motion_tween).set_parallel(true)
	_motion_tween.tween_property(visual, ^"scale", Vector2.ONE * WorkshopStyle.TAKE_SCALE, punch) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_motion_tween.tween_property(self, ^"modulate", WorkshopStyle.TAKE_FLASH, punch)

	_motion_tween.tween_callback(func() -> void: taken_overlay.visible = true).set_delay(punch)
	_motion_tween.tween_property(visual, ^"scale", Vector2.ONE, WorkshopStyle.TAKE_SETTLE) \
		.set_delay(punch).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_motion_tween.tween_property(self, ^"modulate", WorkshopStyle.SPENT_MODULATE, WorkshopStyle.TAKE_SETTLE) \
		.set_delay(punch)
	_motion_tween.tween_property(taken_overlay, ^"modulate:a", 1.0, WorkshopStyle.TAKE_SETTLE) \
		.set_delay(punch)

	await _motion_tween.finished


## The cards the player didn't take, once the bench is closed: they sink back
## and lose their colour instead of just freezing where they are.
func pass_over() -> void:
	if taken:
		return
	disabled = true
	focus_mode = Control.FOCUS_NONE
	_set_emphasis(false)

	_motion_tween = _restart(_motion_tween)
	_motion_tween.set_parallel(true)
	_motion_tween.tween_property(self, ^"modulate", WorkshopStyle.SPENT_MODULATE, WorkshopStyle.FADE_DURATION)
	_motion_tween.tween_property(visual, ^"position:y", 2.0, WorkshopStyle.FADE_DURATION) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

# Private
## The global theme dresses every Button in the run's button art, which is the
## wrong shape for a card. Emptying all five states hands the drawing to Frame.
func _strip_theme_button() -> void:
	for state: StringName in [&"normal", &"hover", &"pressed", &"focus", &"disabled"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())


func _apply_entry() -> void:
	if entry == null or entry.modifier == null:
		push_error("WorkshopCard: no modifier to show.")
		return

	var modifier: Modifier = entry.modifier
	var texture: Texture2D = modifier.icon as Texture2D

	# ART: the icon is the one place a real sprite drops straight in — a modifier
	# with its `icon` set already renders it, placeholder or not.
	icon_rect.texture = texture if texture != null else ModifierDisplay.PLACEHOLDER_ICON
	icon_rect.custom_minimum_size = WorkshopStyle.ICON_SIZE
	plinth.custom_minimum_size = WorkshopStyle.PLINTH_SIZE
	plinth.add_theme_stylebox_override(&"panel", WorkshopStyle.icon_plinth())

	name_label.text = modifier.modifier_name
	WorkshopStyle.apply_text(name_label, WorkshopStyle.FONT_DISPLAY, WorkshopStyle.SIZE_CARD_NAME, WorkshopStyle.PARCHMENT)

	# The seam names what the card costs, taken straight from the trade-off it
	# links — so a combined card can never advertise a drawback it doesn't grant.
	# A plain card has no seam at all and gives the space back to its own name.
	var combined: bool = entry.is_combined()
	seam.visible = combined
	if combined:
		seam_label.text = modifier.linked_modifier.modifier_name.to_upper()
		WorkshopStyle.apply_text(seam_label, WorkshopStyle.FONT_TEXT, WorkshopStyle.SIZE_SEAM, WorkshopStyle.CAUTION)
		seam.add_theme_stylebox_override(&"panel", WorkshopStyle.card_seam())
		seam.custom_minimum_size.y = WorkshopStyle.SEAM_HEIGHT

	glow.add_theme_stylebox_override(&"panel", WorkshopStyle.card_glow(combined))

	WorkshopStyle.apply_text(taken_label, WorkshopStyle.FONT_TEXT, WorkshopStyle.SIZE_SEAM, WorkshopStyle.SPARK)
	taken_overlay.visible = false
	taken_overlay.modulate.a = 0.0


func _set_emphasis(lit: bool) -> void:
	var target: float = 1.0 if lit else 0.0
	if is_equal_approx(_emphasis, target):
		return

	_emphasis_tween = _restart(_emphasis_tween)
	_emphasis_tween.tween_method(_apply_emphasis, _emphasis, target, WorkshopStyle.HOVER_DURATION) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Single read of the lit state. Lift is rounded to whole pixels — the card art
## is pixel art and a card resting on a half pixel shimmers as it moves.
func _apply_emphasis(value: float) -> void:
	_emphasis = value
	if entry == null:
		return

	frame.add_theme_stylebox_override(&"panel", WorkshopStyle.card_frame(entry.is_combined(), value))
	glow.modulate.a = value

	if not taken:
		visual.position.y = -roundf(WorkshopStyle.HOVER_LIFT * value)
		visual.scale = Vector2.ONE * lerpf(1.0, WorkshopStyle.HOVER_SCALE, value)

	# A lifted card overlaps its neighbours, so it has to be the one on top.
	z_index = 1 if value > 0.01 else 0


func _restart(tween: Tween) -> Tween:
	if tween != null and tween.is_valid():
		tween.kill()
	return create_tween()

# Callbacks
func _on_resized() -> void:
	# Scaling has to happen about the middle of the card, not its top-left
	# corner, or a lifted card slides right as it grows.
	visual.pivot_offset = size * 0.5


func _on_mouse_entered() -> void:
	# Pointing at a card is the same act as selecting it with a stick: both move
	# focus, and focus is the only thing that lights a card.
	if not disabled:
		grab_focus()


func _on_focus_entered() -> void:
	_set_emphasis(true)
	highlighted.emit(self)


func _on_focus_exited() -> void:
	_set_emphasis(false)


func _on_pressed() -> void:
	chosen.emit(self)
