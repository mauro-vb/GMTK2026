class_name StartMenu
extends Control

# Constants
## The logo drifts rather than sits. One pixel, slowly — enough that the screen
## isn't a still image, small enough that it never reads as an animation.
const BOB_PIXELS: float = 1.0
const BOB_PERIOD: float = 2.4

## The slider's own 0-1 range, mapped onto a dB span rather than fed straight
## to the bus — a linear volume_db would make the bottom half of the slider
## sound identical and the top half do all the work.
const MIN_VOLUME_DB: float = -40.0
const MAX_VOLUME_DB: float = 0.0

# On Ready
@onready var title: TextureRect = %Title
@onready var play_button: Button = %PlayButton
@onready var difficulty_button: Button = %DifficultyButton
@onready var difficulty_hint: Label = %DifficultyHint
@onready var quit_button: Button = %QuitButton
@onready var volume_slider: HSlider = %VolumeSlider
@onready var sfx_volume_slider: HSlider = %SfxVolumeSlider

# Lifecycle
func _ready() -> void:
	play_button.pressed.connect(_on_play_button_pressed)
	difficulty_button.pressed.connect(_on_difficulty_button_pressed)
	quit_button.pressed.connect(_on_quit_button_pressed)

	# The picker is not on the menu at all until there is a second mode to pick:
	# a locked or greyed-out button on the title screen tells a first-time player
	# there is something they are missing before they have played a single room.
	var has_choice: bool = Global.unlocked_difficulty > Global.Difficulty.NORMAL
	difficulty_button.visible = has_choice
	difficulty_hint.visible = has_choice
	_refresh_difficulty()
	# There is no quitting a browser tab from inside it, and a dead button on the
	# title screen is the first thing a jam player clicks.
	quit_button.visible = not OS.has_feature("web")
	play_button.grab_focus()

	# Reads MusicPlayer's own volume rather than assuming its default, so the
	# slider always starts wherever the music actually is.
	volume_slider.value = inverse_lerp(MIN_VOLUME_DB, MAX_VOLUME_DB, MusicPlayer.get_volume_db())
	volume_slider.value_changed.connect(_on_volume_changed)

	sfx_volume_slider.value = inverse_lerp(MIN_VOLUME_DB, MAX_VOLUME_DB, SfxBus.get_volume_db())
	sfx_volume_slider.value_changed.connect(_on_sfx_volume_changed)

	_start_bob()

# Private
## Waits a frame before reading the logo's resting y: the VBox above it has not
## sorted its children yet during _ready(), so the position captured there is the
## one the logo was authored at, not the one it ends up at — and the bob would
## yank it back there on its first swing.
func _start_bob() -> void:
	await get_tree().process_frame

	var base: float = title.position.y
	var tween: Tween = create_tween().set_loops()
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(title, ^"position:y", base - BOB_PIXELS, BOB_PERIOD * 0.5)
	tween.tween_property(title, ^"position:y", base, BOB_PERIOD * 0.5)

## The choice is spelled out in the label rather than left to any pressed
## styling. It is read at a glance before pressing Play, and "is that button
## darker than the other one?" is not a readable answer at 320x180 — nor could it
## ever say which of four modes is set.
##
## The hint under it carries what the mode actually takes away, because the names
## above hard mode do not tell you: nothing about "XTREME" says "no second jump",
## and finding that out mid-run, one room in, is finding it out too late.
func _refresh_difficulty() -> void:
	difficulty_button.text = "Difficulty: %s" % Global.display_name(Global.difficulty)
	difficulty_hint.text = Global.tagline(Global.difficulty)

# Callbacks
func _on_play_button_pressed() -> void:
	Global.main_game.load_game()


## Steps to the next earned mode, wrapping back to normal past the top. Cycling
## rather than a list of buttons: the ladder is short, it is in a fixed order,
## and four buttons on a title screen this size would crowd out the title.
func _on_difficulty_button_pressed() -> void:
	var available: Array[Global.Difficulty] = Global.available_difficulties()
	var index: int = available.find(Global.difficulty)
	Global.difficulty = available[(index + 1) % available.size()]
	_refresh_difficulty()


func _on_quit_button_pressed() -> void:
	Global.main_game.quit_game()


func _on_volume_changed(value: float) -> void:
	MusicPlayer.set_volume_db(lerpf(MIN_VOLUME_DB, MAX_VOLUME_DB, value))


func _on_sfx_volume_changed(value: float) -> void:
	SfxBus.set_volume_db(lerpf(MIN_VOLUME_DB, MAX_VOLUME_DB, value))
