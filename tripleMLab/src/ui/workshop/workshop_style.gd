class_name WorkshopStyle
extends RefCounted
## The workshop's design language in one place: palette, metrics, timings, and
## the styleboxes built from them.
##
## Everything visual about the workshop resolves through here so the whole screen
## can be re-tuned — or handed over to real art — without going card-hunting. The
## boxes below are procedural placeholders sized to the pixel grid; each one is a
## drop-in for a NinePatchRect once the sprites exist, which is why the metrics
## are named after what they are rather than after their current colour.
##
## Sized against the 320x180 viewport. Every number here is whole pixels on
## purpose: the project renders at integer scale, and a half-pixel margin is a
## row of blurred pixels on a 6x screen.
##
## Cards come in exactly two kinds — plain, and carrying a trade-off. That single
## distinction is all the palette below has to carry, and it is the only thing a
## player has to read off a card at a glance.

# Constants

# --- Palette -----------------------------------------------------------------
## Near-black indigo. The screen behind the bench.
const INK: Color = Color(0.043, 0.039, 0.078)
## Card and panel fill, one step up from the ink.
const PANEL: Color = Color(0.106, 0.098, 0.169)
## Plinths and raised areas, one step up again.
const PANEL_RAISED: Color = Color(0.149, 0.137, 0.227)
## Body text. Matches the button font colour already in main_theme.tres, so the
## workshop and the rest of the game are speaking the same off-white.
const PARCHMENT: Color = Color(0.882, 0.933, 0.847)
## Secondary text — labels that shouldn't compete with what they describe.
const MUTED: Color = Color(0.541, 0.549, 0.639)
## The run's accent: burning fuse. Reserved for the instruction at the top of the
## screen — the thing the player is here to do — never for decoration.
const EMBER: Color = Color(0.964, 0.529, 0.235)
## The hot core of the ember, for flashes.
const SPARK: Color = Color(1.0, 0.898, 0.612)

## The edge of an ordinary card.
const EDGE: Color = Color(0.360, 0.380, 0.463)
## The edge and seam of a card that costs you something. A dusty red, kept clear
## of EMBER so "this is what you're here for" and "this one bites" never read as
## the same colour on the same screen.
const CAUTION: Color = Color(0.855, 0.361, 0.333)

## How dark the bench goes over whatever is behind it. Not fully opaque: the
## workshop is a moment in the run, not a different screen.
const BACKDROP_ALPHA: float = 0.88

# --- Metrics -----------------------------------------------------------------
## Cards fill the row rather than sitting at a fixed width — see the
## `size_flags_horizontal` set in Workshop._lay_out_bench(). That is what makes a
## bench line up edge-for-edge with the description panel under it, and it means
## a wider bench divides the same span instead of drifting inside it. The value
## below is only a floor, for a bench wide enough to reach it.
const CARD_MIN_WIDTH: float = 44.0
const CARD_HEIGHT: float = 56.0
const CARD_GAP: float = 6.0

## Strip along the bottom of a combined card, naming what it costs. A plain card
## has no seam and gives the space back to its own name.
const SEAM_HEIGHT: float = 11.0
## Card padding, inside the frame.
const CARD_PADDING: float = 4.0
const ICON_SIZE: Vector2 = Vector2(16, 16)
## The lit plinth the icon sits on, so a 16px icon doesn't float in the middle of
## an empty card while the art is still a placeholder.
const PLINTH_SIZE: Vector2 = Vector2(22, 22)

## Floor for the description panel; it takes whatever vertical slack the screen
## has spare on top of this. Text is what benefits from the room, and the panel
## never changes size as the player moves along the bench, so nothing jitters.
const DETAIL_HEIGHT: float = 40.0
## Clock and carried-modifier strip along the top.
const STRIP_HEIGHT: float = 12.0

# --- Type --------------------------------------------------------------------
## Display face: headings, card names, buttons. Already the theme's button font.
const FONT_DISPLAY: Font = preload("uid://bn7xy5s6ubsuj")
## Text face: descriptions, seams, counters. A mono holds its shape at 6-7px
## where the display face closes up, and reads as the workshop's paperwork.
const FONT_TEXT: Font = preload("uid://dumnwgfl70q28")

const SIZE_TITLE: int = 10
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
## The card body. `emphasis` runs 0 (at rest) to 1 (hovered or focused) and is
## what the border rides on, so hover and keyboard focus are the same state
## rather than two that can disagree.
##
## ART: replace with a StyleBoxTexture over a nine-sliced card frame; keep the
## content margins so the layout inside doesn't move.
static func card_frame(is_combined: bool, emphasis: float) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = PANEL.lerp(PANEL_RAISED, emphasis)
	box.set_border_width_all(1)
	box.border_color = card_accent(is_combined) * Color(1, 1, 1, lerpf(0.6, 1.0, emphasis))
	box.set_corner_radius_all(1)
	box.set_content_margin_all(CARD_PADDING)

	# A real shadow rather than a darker outline: it is what separates a lifted
	# card from the ones still lying on the bench.
	box.shadow_color = Color(0.0, 0.0, 0.0, lerpf(0.35, 0.55, emphasis))
	box.shadow_size = int(roundf(lerpf(1.0, 3.0, emphasis)))
	box.shadow_offset = Vector2(0, roundf(lerpf(1.0, 3.0, emphasis)))
	return box


## The aura behind a lifted card, in that card's own accent — so a trade-off card
## lights the bench a different colour to a plain one.
static func card_glow(is_combined: bool) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = card_accent(is_combined) * Color(1, 1, 1, 0.16)
	box.set_corner_radius_all(2)
	return box


## The strip along the bottom of a combined card. A ruled line over a wash rather
## than a solid block: the drawback belongs to the card, it isn't a second card
## stuck underneath it.
static func card_seam() -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = CAUTION * Color(1, 1, 1, 0.14)
	box.border_width_top = 1
	box.border_color = CAUTION * Color(1, 1, 1, 0.55)
	box.content_margin_left = 2
	box.content_margin_right = 2
	return box


## The plinth under the icon.
static func icon_plinth() -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = INK * Color(1, 1, 1, 0.55)
	box.set_corner_radius_all(1)
	return box


## The description panel under the bench.
##
## ART: a nine-sliced parchment or slate panel drops in here.
static func detail_panel() -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = PANEL * Color(1, 1, 1, 0.9)
	box.set_border_width_all(1)
	box.border_color = PANEL_RAISED
	box.set_corner_radius_all(1)
	box.set_content_margin_all(4)
	return box


## Applies a face, size and colour to a label in one call. Labels have no entry
## in main_theme.tres, so without this every one of them would come out at
## Godot's default 16px — three times too big for a 320x180 screen.
static func apply_text(label: Label, font: Font, size: int, color: Color) -> void:
	label.add_theme_font_override(&"font", font)
	label.add_theme_font_size_override(&"font_size", size)
	label.add_theme_color_override(&"font_color", color)


## Same for buttons, which do have theme styling but not at this size.
static func apply_button_text(button: Button, size: int) -> void:
	button.add_theme_font_override(&"font", FONT_DISPLAY)
	button.add_theme_font_size_override(&"font_size", size)
	button.add_theme_color_override(&"font_color", PARCHMENT)
	button.add_theme_color_override(&"font_hover_color", SPARK)
	button.add_theme_color_override(&"font_disabled_color", MUTED * Color(1, 1, 1, 0.5))
