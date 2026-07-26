class_name TreasureStyle
extends RefCounted
## The treasure room's design language: the two colours a result can be, the
## board furniture the minigames draw themselves out of, and the timings they
## share.
##
## Deliberately thin. The palette, the type and the text helpers are
## [WorkshopStyle]'s — the treasure room is another moment in the same run, not
## another game, and duplicating the ink and the parchment here is how two
## screens drift apart. Only what a chest needs and a bench doesn't lives below.
##
## Sized against the 320x180 viewport, in whole pixels, for the same reason the
## workshop is: the project renders at integer scale and a half-pixel is a row of
## blurred pixels on a 6x screen.

# Constants

# --- Palette -----------------------------------------------------------------
## Seconds going onto the clock. A cold green, well clear of [constant
## WorkshopStyle.EMBER] — ember is the fuse burning down, and it must never be
## the colour of good news.
const GAIN: Color = Color(0.353, 0.788, 0.482)
## Seconds coming off it. The workshop's warning red, reused on purpose: the same
## colour means "this one bites" on a bench and in a chest.
const LOSS: Color = WorkshopStyle.CAUTION

## The board a minigame is drawn on, and the ruled lines across it.
const BOARD: Color = Color(0.078, 0.071, 0.129)
const BOARD_EDGE: Color = Color(0.207, 0.196, 0.298)
## Pegs, the wheel's hub, the coin's rim: metal in the dark.
const METAL: Color = Color(0.612, 0.639, 0.714)

# --- Metrics -----------------------------------------------------------------
## Floor for the slot a minigame is laid out in. It takes whatever vertical slack
## the screen has spare on top of this, and every game reads its geometry off the
## size it ends up with rather than assuming one.
const BOARD_HEIGHT: float = 84.0
## The line under the board that says what just happened.
const RESULT_HEIGHT: float = 12.0
## Clock and carried-modifier strip along the top, matching the bench's.
const STRIP_HEIGHT: float = 12.0

const SIZE_RESULT: int = 10
const SIZE_ODDS: int = 6

# --- Timings -----------------------------------------------------------------
## The result lands the way a card is taken and a room detonates: punch out,
## flash at the peak, settle. Same beats, same family of flash colour.
const RESULT_PUNCH: float = 0.10
const RESULT_SETTLE: float = 0.30
const RESULT_SCALE: float = 1.35

## A beat between the outcome being known and it being spent, so the payout reads
## as a consequence of the coin landing rather than as part of the same frame.
const PAYOUT_DELAY: float = 0.35

# Static
## Which of the two colours a number is. Zero counts as a payout: a chest that
## pays nothing is a let-down, not a wound.
static func outcome_color(seconds: float) -> Color:
	return GAIN if seconds >= 0.0 else LOSS


## The same colour as a wash, for filling a wedge or a bin behind its label.
static func outcome_fill(seconds: float, emphasis: float = 0.0) -> Color:
	var color: Color = outcome_color(seconds)
	color.a = lerpf(0.28, 0.62, clampf(emphasis, 0.0, 1.0))
	return color


## The board every minigame draws on.
##
## ART: a nine-sliced panel drops in here; keep the content margins so the
## geometry the games compute inside it doesn't move.
static func board_panel() -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = BOARD
	box.set_border_width_all(1)
	box.border_color = BOARD_EDGE
	box.set_corner_radius_all(1)
	box.set_content_margin_all(3)
	return box


## The strip under the board carrying the result.
static func result_panel() -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = WorkshopStyle.PANEL * Color(1, 1, 1, 0.9)
	box.set_corner_radius_all(1)
	box.set_content_margin_all(2)
	return box


## A choice the player is being offered — a coin's side, a plinko slot. Reads as
## a raised key rather than a card: it is a control, not a thing you take.
##
## `padding` is the side margin: two sides of a coin have room to breathe, nine
## plinko slots sharing one board do not.
## Where the keyboard cursor is sitting — which is *not* the same thing as what
## the player has chosen, and must not look like it.
##
## A two-button call with one of them lit in the run's accent reads as "heads is
## already picked", and the player is then correcting a decision they were never
## asked to make. So the cursor is a wash and nothing else: visible enough to
## navigate by, quiet enough that the two sides still look equal.
##
## Borderless on purpose. Godot draws the focus box *over* the button's current
## state, so a bordered one would paint out the hover it is sitting on top of and
## the mouse would lose its own feedback.
static func cursor_button(accent: Color, padding: int = 3) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = accent * Color(1, 1, 1, 0.14)
	box.set_border_width_all(0)
	box.set_corner_radius_all(1)
	box.content_margin_left = padding
	box.content_margin_right = padding
	box.content_margin_top = 2
	box.content_margin_bottom = 2
	return box


static func choice_button(accent: Color, emphasis: float, padding: int = 3) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = WorkshopStyle.PANEL.lerp(WorkshopStyle.PANEL_RAISED, emphasis)
	box.set_border_width_all(1)
	box.border_color = accent * Color(1, 1, 1, lerpf(0.55, 1.0, emphasis))
	box.set_corner_radius_all(1)
	box.content_margin_left = padding
	box.content_margin_right = padding
	box.content_margin_top = 2
	box.content_margin_bottom = 2
	return box
