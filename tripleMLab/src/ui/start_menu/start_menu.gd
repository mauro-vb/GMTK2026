class_name StartMenu
extends UIScreen
## Title screen. Play starts a run via MainGame; Settings opens as a submenu
## on the same layer; Quit only exists on desktop builds.

const SETTINGS_SCENE: PackedScene = preload("res://src/ui/settings_menu/SettingsMenu.tscn")

@onready var play_button: Button = %PlayButton
@onready var settings_button: Button = %SettingsButton
@onready var quit_button: Button = %QuitButton
@onready var version_label: Label = %VersionLabel


func _ready() -> void:
	super()
	play_button.pressed.connect(_on_play_button_pressed)
	settings_button.pressed.connect(func() -> void: open_submenu(SETTINGS_SCENE))
	quit_button.visible = not OS.has_feature("web")
	quit_button.pressed.connect(func() -> void: Global.main_game.quit_game())
	version_label.text = "v%s" % ProjectSettings.get_setting("application/config/version", "0.0.0")


func _on_play_button_pressed() -> void:
	Global.main_game.load_game()
