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
## The whiff: neither a gain nor a loss, so it gets neither colour. A flat grey
## reads as "nothing happened" at a glance, distinct from a small win or a
## small bite rather than looking like a washed-out version of either.
const NEUTRAL: Color = Color(0.55, 0.53, 0.58)

## The board a minigame is drawn on, and the ruled lines across it — the sunken
## box's own fill and border, so a wedge drawn on the board and the panel it is
## drawn on came out of the same sprite.
const BOARD: Color = WorkshopStyle.PANEL
const BOARD_EDGE: Color = WorkshopStyle.EDGE
## Pegs, the wheel's hub, the coin's rim: metal in the dark. The one thing on a
## board that has to read as an object rather than as furniture, so it takes the
## sheet's lightest blue and goes a step past it.
const METAL: Color = Color(0.694, 0.776, 0.855)

# --- Metrics -----------------------------------------------------------------
## Floor for the slot a minigame is laid out in. It takes whatever vertical slack
## the screen has spare on top of this, and every game reads its geometry off the
## size it ends up with rather than assuming one.
const BOARD_HEIGHT: float = 78.0
## The line under the board that says what just happened.
const RESULT_HEIGHT: float = 14.0
## Clock and carried-modifier strip along the top, matching the bench's.
const STRIP_HEIGHT: float = 12.0

## The row of controls a game puts along the bottom of its own board — the coin's
## two calls, the wheel's crank. Tall enough for the slim box below plus a 7px
## face, and no taller: the board above it is what the player is looking at.
const CHOICE_HEIGHT: float = 17.0

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

## How long the chest's entry line holds before the minigame takes the
## instruction line over. Long enough to read a short phrase, short enough that
## "a nice short interaction" doesn't turn into a wait.
const ENTRY_LINE_HOLD: float = 1.4

# Static
## Which of the three colours a number is. Zero is its own colour now that a
## whiff is a real, authored outcome on every game rather than an edge case —
## see [constant NEUTRAL].
static func outcome_color(seconds: float) -> Color:
	if is_zero_approx(seconds):
		return NEUTRAL

	return GAIN if seconds >= 0.0 else LOSS


## The same colour as a wash, for filling a wedge or a bin behind its label.
static func outcome_fill(seconds: float, emphasis: float = 0.0) -> Color:
	var color: Color = outcome_color(seconds)
	color.a = lerpf(0.28, 0.62, clampf(emphasis, 0.0, 1.0))
	return color


## The board every minigame draws on: the sheet's sunken box, which is the same
## panel the workshop reads its descriptions off and the run-end screen sits in.
##
## The 3px content margin is load-bearing — the games compute their geometry
## inside it — so it survives the change of art unchanged.
static func board_panel() -> StyleBoxTexture:
	return WorkshopStyle.sheet_box(
		WorkshopStyle.BOX_SUNKEN, WorkshopStyle.panel_slice(), Vector4i(3, 3, 3, 3)
	)


## The strip under the board carrying the result. The *raised* box against the
## board's sunken one: the number that just landed is the one thing in the room
## that should look like it is sitting forward of everything else.
static func result_panel() -> StyleBoxTexture:
	return WorkshopStyle.raised_panel()


## A choice the player is being offered — a coin's side, the wheel's crank, a
## plinko slot. Cut from the same sheet as everything else, at the one size the
## theme's own button can't reach: a Button dressed in ButtonDefault is 25px
## tall, and these rows are 17 and 8.
##
## Always the *raised* box, because the board it sits on is the sunken one. The
## two-box pairing that reads as "control on a panel" everywhere else in this
## game reads as "disabled" here if it is used the other way round: a dark key on
## a dark board is a key the player assumes is spent. That matters most on the
## coin, where the two calls must look equally unchosen until one is pressed, and
## on the plinko row, where nine dark keys on a dark board vanish into it.
##
## `emphasis` is 0 at rest and 1 lit, and it brightens the same sprite rather
## than swapping it — the difference between a key and a lit key, not between two
## kinds of key.
##
## `padding` is the side margin: two sides of a coin have room to breathe, nine
## plinko slots sharing one board do not.
static func choice_button(emphasis: float, padding: int = 3) -> StyleBoxTexture:
	var lit: bool = emphasis >= 0.5
	return WorkshopStyle.sheet_box(
		WorkshopStyle.BOX_RAISED,
		WorkshopStyle.panel_slice(),
		Vector4i(padding, 2, padding, 2),
		Color(1.3, 1.25, 1.05) if lit else Color.WHITE,
	)


## Where the keyboard cursor is sitting — which is *not* the same thing as what
## the player has chosen, and must not look like it.
##
## A two-button call with one of them lit in the run's accent reads as "heads is
## already picked", and the player is then correcting a decision they were never
## asked to make. So the cursor is a wash and nothing else: visible enough to
## navigate by, quiet enough that the two sides still look equal.
##
## Borderless on purpose, and still a flat box rather than a sprite. Godot draws
## the focus style *over* the button's current state — a box with art in it would
## paint out the hover underneath it and the mouse would lose its own feedback,
## which is exactly what a translucent wash avoids.
static func cursor_button(accent: Color, padding: int = 3) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = accent * Color(1, 1, 1, 0.22)
	box.set_border_width_all(0)
	box.content_margin_left = padding
	box.content_margin_right = padding
	box.content_margin_top = 2
	box.content_margin_bottom = 2
	return box
