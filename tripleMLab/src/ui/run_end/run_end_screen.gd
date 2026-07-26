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
## where the next rung of the ladder is announced and offered — the moment a mode
## is earned is the only moment the player is definitely looking. Beating death
## march, the top of it, is the one ending with nothing to offer after it, and it
## says so rather than quietly dropping the button.
##
## Emits rather than acting: [MainGame] owns what "try again" and "play that
## mode" mean, and this screen is torn down by the same call that answers it.

# Signals
signal retry_pressed
## The player took the mode on offer. Carries which one, so [MainGame] never has
## to re-derive the choice this screen already made.
signal difficulty_pressed(difficulty: Global.Difficulty)
signal menu_pressed

# Constants
const FADE_IN: float = 0.35
## The loss screen arrives on the back of an explosion, so it flashes up in the
## detonation's own colour before settling to the backdrop.
const FLASH_COLOR: Color = Color(1.0, 0.72, 0.35, 0.85)

# Private
## The mode [member difficulty_button] is currently offering. Only meaningful
## while that button is visible.
var _offered: Global.Difficulty = Global.Difficulty.NORMAL

# On Ready
@onready var backdrop: ColorRect = %Backdrop
@onready var headline: Label = %Headline
@onready var detail: Label = %Detail
@onready var unlock_line: Label = %UnlockLine
@onready var retry_button: Button = %RetryButton
@onready var difficulty_button: Button = %DifficultyButton
@onready var menu_button: Button = %MenuButton

# Lifecycle
func _ready() -> void:
	retry_button.pressed.connect(func() -> void: retry_pressed.emit())
	difficulty_button.pressed.connect(func() -> void: difficulty_pressed.emit(_offered))
	menu_button.pressed.connect(func() -> void: menu_pressed.emit())

# Public
## Dresses the screen for how the run ended and plays it in.
##
## `rooms_cleared` counts rooms actually finished, so a death in the first room
## reads "0 rooms" rather than crediting the room it happened in.
##
## `newly_unlocked` is the mode this run just earned, or [constant
## Global.Difficulty.NORMAL] for none (see [method
## Global.unlock_next_difficulty]) — it separates announcing a mode from simply
## offering it again, which is the difference between a reward and a reminder.
func setup(
	victory: bool,
	rooms_cleared: int,
	newly_unlocked: Global.Difficulty = Global.Difficulty.NORMAL,
) -> void:
	if victory:
		_setup_victory(rooms_cleared, newly_unlocked)
	else:
		_setup_defeat(rooms_cleared)

	_setup_offer(newly_unlocked)

	# The default answer to this screen is "again", so that is what the pad lands
	# on: a harder mode is a thing you choose, never a thing you fall into by
	# mashing the button that ended the last run.
	retry_button.grab_focus()
	_play_in(victory)

# Private
## The game has been beaten. Which reading of that depends on what is left above
## the mode it was beaten on: a rung just earned, a rung already sitting there
## unclaimed, or nothing at all.
func _setup_victory(rooms_cleared: int, newly_unlocked: Global.Difficulty) -> void:
	retry_button.text = "Run It Again"

	var cleared: String = "%s cleared." % _rooms(rooms_cleared)
	var standing: String = "The barrage stopped and you were still standing"

	if Global.difficulty == Global.Difficulty.DEATH_MARCH:
		# The end of the whole thing: no unlock, no offer, and a headline no
		# other win uses. This is the run that finishes the game rather than a
		# mode of it, and the screen should not read like every other victory.
		headline.text = "NOTHING LEFT"
		detail.text = "%s —\nhalf a fuse, no second jump, no dash.\n%s" % [standing, cleared]
		unlock_line.show()
		unlock_line.text = "THE DEATH MARCH IS OVER\nThere is nothing harder left to give you."
		return

	headline.text = "YOU BEAT IT"

	if Global.difficulty == Global.Difficulty.NORMAL:
		detail.text = "%s.\n%s" % [standing, cleared]
	else:
		detail.text = "%s —\non %s.\n%s" % [
			standing, Global.display_name(Global.difficulty), cleared,
		]

	unlock_line.show()
	if newly_unlocked != Global.Difficulty.NORMAL:
		unlock_line.text = "%s UNLOCKED\n%s" % [
			Global.display_name(newly_unlocked).to_upper(),
			Global.tagline(newly_unlocked),
		]
	else:
		unlock_line.text = "%s is still waiting." % Global.display_name(Global.unlocked_difficulty)


func _setup_defeat(rooms_cleared: int) -> void:
	headline.text = "BOOM"
	retry_button.text = "Try Again"
	unlock_line.hide()

	if Global.difficulty == Global.Difficulty.NORMAL:
		detail.text = "The fuse ran out.\n%s cleared." % _rooms(rooms_cleared)
	else:
		detail.text = "The fuse ran out on %s.\n%s cleared." % [
			Global.display_name(Global.difficulty),
			_rooms(rooms_cleared),
		]


## Puts the hardest earned mode on the button, unless the run was already on it.
##
## Offered after a death too, not only after a win: a player who has beaten this
## game and is now losing runs to it is exactly who the ladder is for. A mode
## just earned always wins the slot over one earned earlier, because that is the
## thing the screen has just spent a line announcing.
func _setup_offer(newly_unlocked: Global.Difficulty) -> void:
	_offered = (
		newly_unlocked
		if newly_unlocked != Global.Difficulty.NORMAL
		else Global.unlocked_difficulty
	)

	difficulty_button.visible = _offered != Global.difficulty and _offered != Global.Difficulty.NORMAL
	if not difficulty_button.visible:
		return

	difficulty_button.text = (
		"Take On %s" % Global.display_name(_offered)
		if _offered == newly_unlocked
		else Global.display_name(_offered)
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
