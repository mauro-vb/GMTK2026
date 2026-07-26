class_name FuseBar
extends Control
## The clock, drawn as the thing it already is everywhere else in the game: a
## burning fuse.
##
## The map draws its edges as fuses ([MapFuse]) and a room going off is a charge
## detonating, so the player's own timer being a plain progress bar was the one
## place the game stopped speaking its own language. This is the same cord art,
## the same spark, running the same direction — the unburnt length on the right
## is the time you have left, and the spark is where it has burnt to.
##
## Both HUDs use it, which is the point: the number in the corner of a level and
## the number in the corner of the map are the same fuse, so it never looks like
## two different timers.

# Constants
## Cord thickness, in pixels. The art is 4px tall and is drawn 1:1 — a fuse
## stretched to 5px on a 320x180 screen is a visibly blurred fuse.
const CORD_HEIGHT: float = 4.0

## Below this many seconds the readout starts flashing. Long enough to still be
## a warning rather than an obituary.
const LOW_TIME: float = 10.0
const FLASH_PERIOD: float = 0.4

## The ember the fuse and the readout burn at, and the red the last seconds go.
const EMBER: Color = Color(0.964, 0.529, 0.235)
const ALARM: Color = Color(0.855, 0.361, 0.333)

# Exports
## Size of the seconds readout. The HUD wants it big — it is the only number in
## the game that matters. The workshop and the chest room sit it in a 12px strip
## alongside other chrome, where a 16px readout would shove their layouts down.
@export var readout_size: int = 16

# Private
var _time_system: TimeSystem = null
var _flash_tween: Tween = null
var _is_low: bool = false

# On Ready
@onready var bar: Control = %Bar
@onready var track: TextureRect = %Track
@onready var fill: TextureRect = %Fill
@onready var spark: AnimatedSprite2D = %Spark
@onready var time_label: Label = %TimeLabel

# Lifecycle
func _ready() -> void:
	bar.resized.connect(_redraw)
	time_label.add_theme_font_size_override(&"font_size", readout_size)
	# Reserved width scales with the type, so a compact readout doesn't sit at the
	# far end of a gap sized for the big one. Two mono digits plus a little slack.
	time_label.custom_minimum_size.x = ceilf(readout_size * 1.6)

	if Global.main_game == null or Global.main_game.time_system == null:
		push_error("FuseBar: no TimeSystem to read.")
		return

	_time_system = Global.main_game.time_system
	_time_system.time_changed.connect(_on_time_changed)
	# Modifiers can lengthen the fuse mid-run ("Bigger Tank"), which changes what
	# a full bar means — the bar has to be redrawn against the new maximum.
	_time_system.max_time_changed.connect(_redraw)

	# The HUD is rebuilt on every room swap, so it starts mid-run more often than
	# it starts at full: catch up rather than waiting for the next tick.
	_redraw()

# Private
## Lays the cord out against whatever width the HUD gave the bar.
##
## The unburnt length is anchored to the *right* so the spark travels left to
## right as time drains, toward the end of the fuse. A bar that empties from the
## right instead would put the spark in retreat, which reads as the fuse growing
## back.
func _redraw() -> void:
	var ratio: float = 0.0
	if _time_system != null and _time_system.max_time > 0.0:
		ratio = clampf(_time_system.current_time / _time_system.max_time, 0.0, 1.0)

	var full_width: float = bar.size.x
	var y: float = floorf((bar.size.y - CORD_HEIGHT) * 0.5)
	# Whole pixels: the project renders at integer scale, and a cord ending on a
	# half pixel is a column of blur at the one place the eye is already looking.
	var lit_width: float = floorf(full_width * ratio)

	track.position = Vector2(0.0, y)
	track.size = Vector2(full_width, CORD_HEIGHT)

	fill.position = Vector2(full_width - lit_width, y)
	fill.size = Vector2(lit_width, CORD_HEIGHT)

	# Nothing to burn at either extreme: at full there is no charred cord behind
	# the spark, and at zero the charge has already gone off.
	spark.visible = lit_width > 0.0 and lit_width < full_width
	spark.position = Vector2(full_width - lit_width, y + CORD_HEIGHT * 0.5)

	if _time_system != null:
		time_label.text = str(int(ceil(_time_system.current_time)))
		_set_low(_time_system.current_time <= LOW_TIME)


## Flashes the readout once the fuse is short. Driven by a looping tween rather
## than a per-frame check so it keeps a steady beat instead of stuttering with
## whatever the clock's tick rate has been modified to.
func _set_low(value: bool) -> void:
	if value == _is_low:
		return

	_is_low = value

	if _flash_tween != null:
		_flash_tween.kill()
		_flash_tween = null

	if not _is_low:
		time_label.add_theme_color_override(&"font_color", EMBER)
		return

	_flash_tween = create_tween().set_loops()
	_flash_tween.tween_callback(time_label.add_theme_color_override.bind(&"font_color", ALARM))
	_flash_tween.tween_interval(FLASH_PERIOD * 0.5)
	_flash_tween.tween_callback(time_label.add_theme_color_override.bind(&"font_color", EMBER))
	_flash_tween.tween_interval(FLASH_PERIOD * 0.5)

# Callbacks
func _on_time_changed(_value: float) -> void:
	_redraw()
