class_name StartMenu
extends Control

@onready var play_button: Button = %PlayButton

func _ready() -> void:
	play_button.pressed.connect(_on_play_button_pressed)

func _on_play_button_pressed() -> void:
	Global.main_game.load_game()
