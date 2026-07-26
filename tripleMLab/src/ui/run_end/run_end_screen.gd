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
## A win is not "a run that went well", it is the end of the game: the only way
## to reach one is out the far side of the barrage (see [method
## MainGame.exit_room]). So the victory wording says so, and the screen is also
## where hard mode is announced and offered — the moment it is earned is the
## only moment the player is definitely looking.
##
## Emits rather than acting: [MainGame] owns what "try again" and "hard mode"
## mean, and this screen is torn down by the same call that answers it.

# Signals
signal retry_pressed
signal hard_mode_pressed
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
@onready var unlock_line: Label = %UnlockLine
@onready var retry_button: Button = %RetryButton
@onready var hard_mode_button: Button = %HardModeButton
@onready var menu_button: Button = %MenuButton

# Lifecycle
func _ready() -> void:
	retry_button.pressed.connect(func() -> void: retry_pressed.emit())
	hard_mode_button.pressed.connect(func() -> void: hard_mode_pressed.emit())
	menu_button.pressed.connect(func() -> void: menu_pressed.emit())

# Public
## Dresses the screen for how the run ended and plays it in.
##
## `rooms_cleared` counts rooms actually finished, so a death in the first room
## reads "0 rooms" rather than crediting the room it happened in.
##
## `newly_unlocked` is true only on the run that earns hard mode — it separates
## announcing the unlock from simply offering it again, which is the difference
## between a reward and a reminder.
func setup(victory: bool, rooms_cleared: int, newly_unlocked: bool = false) -> void:
	if victory:
		_setup_victory(rooms_cleared, newly_unlocked)
	else:
		headline.text = "BOOM"
		detail.text = "The fuse ran out.\n%s cleared." % _rooms(rooms_cleared)
		retry_button.text = "Try Again"
		unlock_line.hide()

	# Offered wherever it is owned and not already running: after a death too,
	# because a player who has beaten this game and is now losing runs to it is
	# exactly who the mode is for.
	hard_mode_button.visible = Global.hard_mode_unlocked and not Global.hard_mode
	hard_mode_button.text = "Hard Mode"

	# The default answer to this screen is "again", so that is what the pad lands
	# on: hard mode is a thing you choose, never a thing you fall into by mashing
	# the button that ended the last run.
	retry_button.grab_focus()
	_play_in(victory)

# Private
## The game has been beaten. Three readings of that, in the order a player meets
## them: the first time, every time after, and the first time on half a fuse.
func _setup_victory(rooms_cleared: int, newly_unlocked: bool) -> void:
	headline.text = "YOU BEAT IT"
	retry_button.text = "Run It Again"

	if Global.hard_mode:
		detail.text = (
			"The barrage stopped and you were still standing —\non half a fuse.\n%s cleared."
			% _rooms(rooms_cleared)
		)
		unlock_line.hide()
		return

	detail.text = (
		"The barrage stopped and you were still standing.\n%s cleared." % _rooms(rooms_cleared)
	)
	unlock_line.show()
	unlock_line.text = (
		"HARD MODE UNLOCKED\nHalf the fuse. Same job."
		if newly_unlocked
		else "Hard mode is still waiting."
	)


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
