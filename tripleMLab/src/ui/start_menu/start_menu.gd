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
@onready var quit_button: Button = %QuitButton

# Lifecycle
func _ready() -> void:
	play_button.pressed.connect(_on_play_button_pressed)
	quit_button.pressed.connect(_on_quit_button_pressed)
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

# Callbacks
func _on_play_button_pressed() -> void:
	Global.main_game.load_game()


func _on_quit_button_pressed() -> void:
	Global.main_game.quit_game()
