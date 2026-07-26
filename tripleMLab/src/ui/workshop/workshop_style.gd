class_name WorkshopStyle
extends RefCounted
## The workshop's design language in one place: palette, metrics, timings, and
## the styleboxes built from them.
##
## Everything visual about the workshop resolves through here so the whole screen
## can be re-tuned without going card-hunting. Every box below is now cut from
## the run's own UI sheet — the same four sprites main_theme.tres dresses the
## menus and the HUD in — so a bench and a start screen are visibly the same
## game rather than two that happen to share a font.
##
## Sized against the 320x180 viewport. Every number here is whole pixels on
## purpose: the project renders at integer scale, and a half-pixel margin is a
## row of blurred pixels on a 6x screen. The nine-slice margins are read off the
## sprites themselves — see [constant CARD_BAND] — so nothing stretches a border
## that was drawn one pixel wide.
##
## Cards come in exactly two kinds — plain, and carrying a trade-off. That single
## distinction is all the palette below has to carry, and it is the only thing a
## player has to read off a card at a glance.

# Constants

# --- Art ---------------------------------------------------------------------
## The card face, at rest and lit. Both are 29x32 with a fixed 8px header band
## across the top and a 1px border; the lit one adds a parchment ring around the
## outside, which is the whole of what "this is the one you're pointing at" has
## to say.
const CARD_NEUTRAL: Texture2D = preload("uid://dmkncxmp38d52")
const CARD_SELECTED: Texture2D = preload("uid://t1llgg0ij8l0")
## The panel pair the theme already dresses Panel and RaisedPanel in: a sunken
## box and a raised one. Reused here rather than re-drawn so a workshop panel and
## a menu panel are the same object.
const BOX_SUNKEN: Texture2D = preload("uid://djdruc00lp0f5")
const BOX_RAISED: Texture2D = preload("uid://b6ovd623mb0m4")

# --- Palette -----------------------------------------------------------------
## Every colour below is lifted straight off the UI sprites or out of
## main_theme.tres. Nothing in the workshop invents a shade of its own: a value
## that isn't in the sheet is a value the rest of the game can't match.

## Near-black indigo. The scrim over the backdrop, and the theme's own shadow.
const INK: Color = Color(0.043, 0.039, 0.078)
## The sunken box's fill — #2B4377, the mid blue of UITextBox.
const PANEL: Color = Color(0.169, 0.263, 0.467)
## The raised box's fill — #5177AC, the light blue of UITextBox2 and of a card
## body.
const PANEL_RAISED: Color = Color(0.318, 0.467, 0.675)
## Body text. The theme's Label and Button font colour — #E1EED8, which is also
## the ring drawn around a lit card.
const PARCHMENT: Color = Color(0.882, 0.933, 0.847)
## Secondary text — labels that shouldn't compete with what they describe. The
## theme's HintLabel colour.
const MUTED: Color = Color(0.541, 0.549, 0.639)
## The run's accent: burning fuse. The theme's SubtitleLabel and TimerLabel
## colour. Reserved for the instruction at the top of the screen — the thing the
## player is here to do — never for decoration.
const EMBER: Color = Color(0.964, 0.529, 0.235)
## The hot core of the ember, for flashes. The theme's button focus colour.
const SPARK: Color = Color(1.0, 0.898, 0.612)

## The line every box on the sheet is bordered in — #1F2D4B. The edge of an
## ordinary card, and the ruled line between two things that belong together.
const EDGE: Color = Color(0.122, 0.176, 0.294)
## The edge and seam of a card that costs you something. A dusty red, kept clear
## of EMBER so "this is what you're here for" and "this one bites" never read as
## the same colour on the same screen — and the one colour here that isn't on the
## sheet, because the sheet has nothing that means "careful".
const CAUTION: Color = Color(0.855, 0.361, 0.333)

## How far the room dims the cave behind it. The start menu scrims the same
## image at 0.45; a bench carries more small text over it, so it goes a step
## further — but never to opaque, because the workshop is a moment in the run,
## not a different screen.
const BACKDROP_ALPHA: float = 0.58

# --- Metrics -----------------------------------------------------------------
## Cards fill the row rather than sitting at a fixed width — see the
## `size_flags_horizontal` set in Workshop._lay_out_bench(). That is what makes a
## bench line up edge-for-edge with the description panel under it, and it means
## a wider bench divides the same span instead of drifting inside it. The value
## below is only a floor, for a bench wide enough to reach it.
const CARD_MIN_WIDTH: float = 44.0
const CARD_HEIGHT: float = 64.0
const CARD_GAP: float = 5.0

## The header band drawn across the top of both card sprites, and the 1px rule
## under it. Fixed rather than stretched — it is 8 pixels of art, and a nine
## slice that stretched it would land the rule on a half pixel. Everything the
## card puts inside itself starts below this.
const CARD_BAND: int = 8
## The 1px border ring, plus the parchment ring the lit card adds outside it.
const CARD_BORDER: int = 2

## Strip along the bottom of a combined card, naming what it costs. A plain card
## has no seam and gives the space back to its own name.
const SEAM_HEIGHT: float = 10.0
## Card padding, inside the frame and below the band.
const CARD_PADDING: float = 3.0
const ICON_SIZE: Vector2 = Vector2(16, 16)
## The plinth the icon sits on: a sunken box on a raised card face, so a 16px
## icon reads as set into the card rather than laid on top of it.
const PLINTH_SIZE: Vector2 = Vector2(21, 21)

## Floor for the description panel; it takes whatever vertical slack the screen
## has spare on top of this. Text is what benefits from the room, and the panel
## never changes size as the player moves along the bench, so nothing jitters.
const DETAIL_HEIGHT: float = 32.0
## Clock and carried-modifier strip along the top.
const STRIP_HEIGHT: float = 12.0

## What the room's own margins have to clear. The backdrop is a framed cave
## mouth, not a flat colour: pit props run down the outside 16 pixels of each
## side, and small text laid over them is small text nobody can read.
##
## The top is the exception, and deliberately so. The cave's rock lip runs from
## y17 to about y42, and there is a clean strip above it — so the clock and the
## room's name sit in that strip, and the instruction lands on the rock. A line
## of large ember type on a dark shelf is the one thing on this screen that gains
## from the backdrop instead of fighting it.
const ROOM_MARGIN_SIDE: int = 16
const ROOM_MARGIN_TOP: int = 3
const ROOM_MARGIN_BOTTOM: int = 6
## Between the rows of the column. Tight: a 320x180 screen has no air to spend on
## separations, and every row below is doing work.
const ROOM_SEPARATION: int = 3

# --- Type --------------------------------------------------------------------
## Display face: headings, card names, buttons. Already the theme's button font.
const FONT_DISPLAY: Font = preload("uid://bn7xy5s6ubsuj")
## Text face: descriptions, seams, counters. A mono holds its shape at 6-7px
## where the display face closes up, and reads as the workshop's paperwork.
const FONT_TEXT: Font = preload("uid://dumnwgfl70q28")

## The room headings are theme types now — SubtitleLabel for the instruction,
## HintLabel for the room's name — so the only sizes left here are the ones the
## theme has no entry for.
const SIZE_SUBTITLE: int = 7
const SIZE_CARD_NAME: int = 8
const SIZE_SEAM: int = 6
const SIZE_BODY: int = 7

# --- Timings -----------------------------------------------------------------
## Cards are laid out one at a time rather than appearing together — the bench is
## being set in front of you.
const DEAL_STAGGER: float = 0.05
const DEAL_DURATION: float = 0.26
const DEAL_RISE: float = 10.0

const HOVER_DURATION: float = 0.10
const HOVER_LIFT: float = 2.0
const HOVER_SCALE: float = 1.06

## Taking a modifier borrows the map's detonation language — punch out, flash at
## the peak, settle — so picking something reads as the same kind of event as a
## charge going off.
const TAKE_PUNCH: float = 0.09
const TAKE_SETTLE: float = 0.24
const TAKE_SCALE: float = 1.16
const TAKE_FLASH: Color = Color(2.4, 2.0, 1.5, 1.0)

const SWEEP_DURATION: float = 0.16
const SWEEP_DROP: float = 8.0
const FADE_DURATION: float = 0.18

## What a card that has been taken, or passed over, fades back to.
const SPENT_MODULATE: Color = Color(0.45, 0.45, 0.52, 0.75)

# Static
## The colour a card is edged and lit in. Asked for by hand rather than looked up
## in a table: there are two kinds of card, and there will only ever be two.
static func card_accent(is_combined: bool) -> Color:
	return CAUTION if is_combined else EDGE

# --- Styleboxes --------------------------------------------------------------
## Cut from a sprite once and handed out by reference. A card asks for its frame
## on every step of the hover tween, and the two faces below are the same two
## objects every time — building a fresh StyleBoxTexture per frame per card would
## be a lot of garbage for a screen that never changes what it is drawing.
static var _card_faces: Dictionary = {}
static var _boxes: Dictionary = {}


## A nine-sliced box off the UI sheet.
##
## `slice` is what the sprite keeps unstretched — read off the art, not guessed:
## a panel is a 1px border, a card is a 2px ring with an 8px header band above
## it. `content` is what the box then holds its children in. Both are
## left/top/right/bottom.
##
## Cached on everything that distinguishes one box from another, so the same
## panel asked for by three screens is one object.
static func sheet_box(
	texture: Texture2D,
	slice: Vector4i,
	content: Vector4i,
	modulate: Color = Color.WHITE,
) -> StyleBoxTexture:
	var key: String = "%s|%s|%s|%s" % [texture.resource_path, slice, content, modulate]
	if _boxes.has(key):
		return _boxes[key]

	var box: StyleBoxTexture = StyleBoxTexture.new()
	box.texture = texture
	box.texture_margin_left = slice.x
	box.texture_margin_top = slice.y
	box.texture_margin_right = slice.z
	box.texture_margin_bottom = slice.w
	box.content_margin_left = content.x
	box.content_margin_top = content.y
	box.content_margin_right = content.z
	box.content_margin_bottom = content.w
	box.modulate_color = modulate

	_boxes[key] = box
	return box


## The border ring on the two panel sprites: one pixel, all round.
static func panel_slice() -> Vector4i:
	return Vector4i(1, 1, 1, 1)


## The card sprites: the same ring at 2px — the lit face adds a parchment ring
## outside the border, and the two have to slice identically or a card would
## shift as it lit — with the header band held above it.
static func card_slice() -> Vector4i:
	return Vector4i(CARD_BORDER, CARD_BAND, CARD_BORDER, CARD_BORDER)


## The card face. `emphasis` runs 0 (at rest) to 1 (hovered or focused) and is
## what the sprite swap rides on, so hover and keyboard focus are the same state
## rather than two that can disagree.
##
## Two sprites rather than a lerp: the lit card is *drawn* lit, ring and all, and
## crossfading between two pieces of pixel art would only blur the ring it was
## trying to introduce. The motion in [WorkshopCard] — the lift and the scale —
## is what carries the half-states.
##
## Content starts below the header band, so nothing the card puts inside itself
## ever lands on the band's rule.
static func card_frame(_is_combined: bool, emphasis: float) -> StyleBoxTexture:
	var lit: bool = emphasis >= 0.5
	if _card_faces.has(lit):
		return _card_faces[lit]

	var pad: int = int(CARD_PADDING)
	var face: StyleBoxTexture = sheet_box(
		CARD_SELECTED if lit else CARD_NEUTRAL,
		card_slice(),
		Vector4i(pad, CARD_BAND + 1, pad, pad),
	)

	_card_faces[lit] = face
	return face


## What sits behind a lifted card: its shadow on the bench, not a halo.
##
## It used to be an aura in the card's own accent, which the placeholder art
## could carry because nothing else on screen was coloured. Against the real
## sprite it can't — a light wash bleeding out from under a card reads as a
## smudge on the backdrop, and the lit card already says it is lit, in the
## parchment ring it is drawn with. So this is ink, and its whole job is depth.
static func card_glow(_is_combined: bool) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = INK * Color(1, 1, 1, 0.5)
	box.set_corner_radius_all(2)
	return box


## The strip along the bottom of a combined card. A ruled line over a wash rather
## than a solid block: the drawback belongs to the card, it isn't a second card
## stuck underneath it — and it is the one thing on the bench that is allowed a
## colour the sheet doesn't have, because it is the one thing that means
## "careful".
static func card_seam() -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = CAUTION * Color(1, 1, 1, 0.16)
	box.border_width_top = 1
	box.border_color = CAUTION * Color(1, 1, 1, 0.65)
	box.content_margin_left = 2
	box.content_margin_right = 2
	return box


## The plinth under the icon: the sunken box, on a card face cut from the raised
## one. The same pairing the theme uses for Panel against RaisedPanel, at 21px.
static func icon_plinth() -> StyleBoxTexture:
	return sheet_box(BOX_SUNKEN, panel_slice(), Vector4i(2, 2, 2, 2))


## The description panel under the bench: the theme's own sunken box, so the
## bench's paperwork and the run-end screen's are the same panel.
static func detail_panel() -> StyleBoxTexture:
	return sheet_box(BOX_SUNKEN, panel_slice(), Vector4i(4, 3, 4, 3))


## The raised box, for anything that has to sit forward of the panel it is on.
static func raised_panel() -> StyleBoxTexture:
	return sheet_box(BOX_RAISED, panel_slice(), Vector4i(4, 3, 4, 3))


## Applies a face, size and colour to a label in one call. Labels have no entry
## in main_theme.tres, so without this every one of them would come out at
## Godot's default 16px — three times too big for a 320x180 screen.
static func apply_text(label: Label, font: Font, size: int, color: Color) -> void:
	label.add_theme_font_override(&"font", font)
	label.add_theme_font_size_override(&"font_size", size)
	label.add_theme_color_override(&"font_color", color)


## Same for buttons — but only for the compact ones a minigame draws inside its
## own board, where the theme's 12px face would be taller than the control.
##
## The rooms' own buttons (Leave, Sweep) are left alone on purpose: they are the
## same button the start menu and the run-end screen use, and the theme already
## says what that looks like.
static func apply_button_text(button: Button, size: int) -> void:
	button.add_theme_font_override(&"font", FONT_DISPLAY)
	button.add_theme_font_size_override(&"font_size", size)
	button.add_theme_color_override(&"font_color", PARCHMENT)
	button.add_theme_color_override(&"font_hover_color", SPARK)
	button.add_theme_color_override(&"font_disabled_color", MUTED * Color(1, 1, 1, 0.5))
