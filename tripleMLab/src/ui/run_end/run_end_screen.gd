class_name RunEndScreen
extends Control
## The screen at both ends of a run: the fuse ran out, or it didn't.
##
## One scene for win and loss on purpose. They are the same moment structurally
## — the run is over, here is how it went, here is the way back in — and two
## scenes would be two places for the wording, the layout and the button order
## to drift apart. What actually differs is a headline, a line of text and a
## button label, so that is all [method setup] changes.
##
## Emits rather than acting: [MainGame] owns what "try again" means, and this
## screen is torn down by the same call that answers it.

# Signals
signal retry_pressed
signal menu_pressed

# Constants
const FADE_IN: float = 0.35
## The loss screen arrives on the back of an explosion, so it flashes up in the
## detonation's own colour before settling to the backdrop.
const FLASH_COLOR: Color = Color(1.0, 0.72, 0.35, 0.85)

# On Ready
@onready var backdrop: ColorRect = %Backdrop
@onready var headline: Label = %Headline
@onready var detail: Label = %Detail
@onready var retry_button: Button = %RetryButton
@onready var menu_button: Button = %MenuButton

# Lifecycle
func _ready() -> void:
	retry_button.pressed.connect(func() -> void: retry_pressed.emit())
	menu_button.pressed.connect(func() -> void: menu_pressed.emit())
	retry_button.grab_focus()

# Public
## Dresses the screen for how the run ended and plays it in.
##
## `rooms_cleared` counts rooms actually finished, so a death in the first room
## reads "0 rooms" rather than crediting the room it happened in.
func setup(victory: bool, rooms_cleared: int) -> void:
	if victory:
		headline.text = "YOU MADE IT"
		detail.text = "Out the far side with the fuse still lit.\n%s cleared." % _rooms(rooms_cleared)
		retry_button.text = "Run It Again"
	else:
		headline.text = "BOOM"
		detail.text = "The fuse ran out.\n%s cleared." % _rooms(rooms_cleared)
		retry_button.text = "Try Again"

	_play_in(victory)

# Private
static func _rooms(count: int) -> String:
	return "1 room" if count == 1 else "%d rooms" % count


func _play_in(victory: bool) -> void:
	var settled: Color = backdrop.color
	modulate = Color(1, 1, 1, 0)

	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, ^"modulate:a", 1.0, FADE_IN)

	# Only a death gets the flash. A win has just come off a level exit, not a
	# charge going off, and a blast of orange over it would say otherwise.
	if not victory:
		backdrop.color = FLASH_COLOR
		tween.tween_property(backdrop, ^"color", settled, FADE_IN)
