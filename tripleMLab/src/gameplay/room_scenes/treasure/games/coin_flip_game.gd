class_name CoinFlipGame
extends TreasureGame
## Call it in the air. The chest with two outcomes and no middle.
##
## The player picks a side *before* the toss, and calling it right is worth the
## table's better outcome. On the 50/50 chest that is exactly a fair coin; the
## table is still what decides, so a chest authored 60/40 would come out 60/40
## with the same animation over the top — the coin never hard-codes a half.
##
## Two slices is a hard requirement, which is what [method can_present] is for:
## a coin with three faces is not a coin.

# Signals
# Enums
# Constants
const COIN_RADIUS: float = 17.0
## The rim, so the coin reads as a disc rather than a hole when it is edge-on.
const RIM_WIDTH: float = 2.0

## Half-turns in the air. Odd or even is decided by which face has to land, so
## this is the floor rather than the count — see [method _toss].
const FLIP_HALF_TURNS: int = 10
const FLIP_DURATION: float = 1.15
## How far the coin rises at the top of its arc.
const FLIP_HEIGHT: float = 26.0
## What the two calls fade back to once one of them has been made. They stay on
## screen — the player should be able to see what they called while it is in the
## air — but they are no longer anything to act on.
const CALLED_MODULATE: float = 0.4

## The squash at the moment it lands, so it hits the board rather than stopping.
const LAND_SQUASH: float = 0.72
const LAND_DURATION: float = 0.14

# Exports
## ART: the two faces. Drawn centred and squashed with the toss, so a plain
## 16-24px coin sprite is all this needs. Either one left null falls back to the
## disc below it, which is what ships today.
@export var heads_texture: Texture2D
@export var tails_texture: Texture2D

# Public

# Private
## What the player called, and what the coin is showing. The coin rests on heads.
var _called_heads: bool = true
var _showing_heads: bool = true

## The toss, 0 at rest in the hand and 1 back in it.
var _flight: float = 0.0
var _spin: float = 0.0
var _squash: float = 1.0
var _rise: float = 0.0

var _tossed: bool = false

# On Ready
@onready var choices: HBoxContainer = %Choices
@onready var heads_button: Button = %HeadsButton
@onready var tails_button: Button = %TailsButton

# Static

# Lifecycle
func _draw() -> void:
	var centre: Vector2 = Vector2(size.x * 0.5, _coin_centre_y() - _rise)
	var radius: Vector2 = Vector2(COIN_RADIUS * _squash, COIN_RADIUS)
	var face: Color = TreasureStyle.METAL if _showing_heads else TreasureStyle.METAL.darkened(0.45)

	_draw_disc(centre, radius, face)

	# Edge-on there is nothing to letter, and a squashed glyph reads as a bug.
	if _squash < 0.35:
		return

	var texture: Texture2D = heads_texture if _showing_heads else tails_texture
	if texture != null:
		var texture_size: Vector2 = Vector2(texture.get_size().x * _squash, texture.get_size().y)
		draw_texture_rect(texture, Rect2(centre - texture_size * 0.5, texture_size), false)
		return

	_draw_centered_text(
		"H" if _showing_heads else "T",
		centre,
		WorkshopStyle.FONT_DISPLAY,
		WorkshopStyle.SIZE_CARD_NAME,
		WorkshopStyle.INK,
	)

# Public
## Two faces, two outcomes. Anything else is a table for the wheel or the board.
func can_present() -> bool:
	return super() and table.slices.size() == 2


func begin() -> void:
	_announce("CALL IT")
	heads_button.grab_focus()

# Private
func _build() -> void:
	# Focus is the keyboard cursor, not the call: the two sides have to look
	# equally unchosen until one of them is pressed.
	for button: Button in [heads_button, tails_button]:
		WorkshopStyle.apply_button_text(button, WorkshopStyle.SIZE_SUBTITLE)
		button.add_theme_stylebox_override(&"normal", TreasureStyle.choice_button(WorkshopStyle.EDGE, 0.0))
		button.add_theme_stylebox_override(&"hover", TreasureStyle.choice_button(WorkshopStyle.EMBER, 1.0))
		button.add_theme_stylebox_override(&"focus", TreasureStyle.cursor_button(WorkshopStyle.EDGE))
		button.add_theme_stylebox_override(&"pressed", TreasureStyle.choice_button(WorkshopStyle.SPARK, 1.0))
		button.add_theme_stylebox_override(&"disabled", TreasureStyle.choice_button(WorkshopStyle.EDGE, 0.0))

	heads_button.pressed.connect(_on_side_called.bind(true))
	tails_button.pressed.connect(_on_side_called.bind(false))
	# Pointing at a side moves focus to it, so there is only ever one cursor on
	# screen and the mouse and the stick can't disagree about where it is.
	heads_button.mouse_entered.connect(_on_side_hovered.bind(heads_button))
	tails_button.mouse_entered.connect(_on_side_hovered.bind(tails_button))


## Where the coin sits when it is not in the air: centred in the space the
## buttons leave, so the toss has the top of the board to travel into.
func _coin_centre_y() -> float:
	return maxf(size.y - choices.size.y, COIN_RADIUS * 2.0) * 0.5 + COIN_RADIUS * 0.5


## An ellipse plus a rim. Godot draws circles, not ellipses, so the disc is a
## polygon — which is also what lets it squash to nothing edge-on.
func _draw_disc(centre: Vector2, radius: Vector2, fill: Color) -> void:
	const SEGMENTS: int = 24
	var points: PackedVector2Array = PackedVector2Array()
	for index: int in SEGMENTS:
		var angle: float = TAU * float(index) / float(SEGMENTS)
		points.append(centre + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))

	draw_colored_polygon(points, fill)
	points.append(points[0])
	draw_polyline(points, TreasureStyle.METAL.lightened(0.25), RIM_WIDTH)


## The toss itself. The table decides first, and the coin is then told which face
## it has to land on for that answer to be true.
func _toss(slice: TreasureSlice) -> void:
	var called_right: bool = slice == table.best_slice()
	var landing_heads: bool = _called_heads if called_right else not _called_heads

	# Every half-turn swaps the face, so the parity of the count *is* the face it
	# lands on: one more half-turn if the coin would otherwise come down wrong.
	var half_turns: int = FLIP_HALF_TURNS
	if landing_heads != _showing_heads:
		half_turns += 1

	var spin_to: float = float(half_turns) * PI

	# Linear rather than eased: a tossed coin spins at the rate it left the hand,
	# and the arc it travels is what makes it read as thrown.
	var tween: Tween = _restart_animation()
	tween.tween_method(_apply_flight.bind(spin_to), 0.0, 1.0, FLIP_DURATION)
	# The face it comes down on is *assigned*, never derived from where the spin
	# stopped. `half_turns * PI / PI` is not reliably `half_turns` in floating
	# point — 11 * PI / PI is 10.999999999999998, which floors to 10 and reads as
	# the wrong face — and eleven half-turns is exactly the case where the coin
	# has to land on the opposite side from the one it started on. Derived, every
	# toss that should have come down tails came down heads while still paying
	# out for tails, which is the one thing this game must never do.
	tween.tween_callback(_land_on.bind(landing_heads))
	tween.tween_method(_apply_landing, 0.0, 1.0, LAND_DURATION)


## Mid-air only: which face is toward the player is read off the spin, which is
## fine while it is a blur. Where it comes to rest is [method _land_on]'s to say.
func _apply_flight(value: float, spin_to: float) -> void:
	_flight = value
	_spin = value * spin_to
	_rise = sin(value * PI) * FLIP_HEIGHT
	_squash = absf(cos(_spin))
	_showing_heads = (floori(_spin / PI) % 2 == 0)


## Caught. The face here is the one the outcome was decided against.
func _land_on(heads: bool) -> void:
	_showing_heads = heads
	_rise = 0.0
	_squash = 1.0
	queue_redraw()


## The bounce as it lands: flattens against the board and comes back.
func _apply_landing(value: float) -> void:
	_rise = 0.0
	_squash = lerpf(LAND_SQUASH, 1.0, value)

# Callbacks
func _on_side_hovered(button: Button) -> void:
	if not button.disabled:
		button.grab_focus()


func _on_side_called(heads: bool) -> void:
	if _tossed:
		return

	_tossed = true
	_called_heads = heads
	heads_button.disabled = true
	tails_button.disabled = true
	choices.modulate.a = CALLED_MODULATE
	# Focus is what lights a button; a called coin has neither side lit.
	heads_button.focus_mode = Control.FOCUS_NONE
	tails_button.focus_mode = Control.FOCUS_NONE
	_announce("HEADS" if heads else "TAILS")

	var slice: TreasureSlice = table.roll()
	_toss(slice)
	await _animation.finished
	_finish(slice)
