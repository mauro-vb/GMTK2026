class_name StartMenu
extends Control

# Constants
## The logo drifts rather than sits. One pixel, slowly — enough that the screen
## isn't a still image, small enough that it never reads as an animation.
const BOB_PIXELS: float = 1.0
const BOB_PERIOD: float = 2.4

# On Ready
@onready var title: TextureRect = %Title
@onready var play_button: Button = %PlayButton
@onready var hard_mode_button: Button = %HardModeButton
@onready var quit_button: Button = %QuitButton

# Lifecycle
func _ready() -> void:
	play_button.pressed.connect(_on_play_button_pressed)
	hard_mode_button.toggled.connect(_on_hard_mode_toggled)
	quit_button.pressed.connect(_on_quit_button_pressed)

	# The toggle is not on the menu at all until it has been earned: a locked or
	# greyed-out button on the title screen tells a first-time player there is
	# something they are missing before they have played a single room.
	hard_mode_button.visible = Global.hard_mode_unlocked
	hard_mode_button.button_pressed = Global.hard_mode
	_refresh_hard_mode_label()
	# There is no quitting a browser tab from inside it, and a dead button on the
	# title screen is the first thing a jam player clicks.
	quit_button.visible = not OS.has_feature("web")
	play_button.grab_focus()

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

## The state is spelled out in the label rather than left to the button's
## pressed styling. This is the one setting in the game, it is read at a glance
## before pressing Play, and "is that button darker than the other one?" is not
## a readable answer at 320x180.
func _refresh_hard_mode_label() -> void:
	hard_mode_button.text = "Hard Mode: On" if Global.hard_mode else "Hard Mode: Off"

# Callbacks
func _on_play_button_pressed() -> void:
	Global.main_game.load_game()


func _on_hard_mode_toggled(pressed: bool) -> void:
	Global.hard_mode = pressed
	_refresh_hard_mode_label()


func _on_quit_button_pressed() -> void:
	Global.main_game.quit_game()
