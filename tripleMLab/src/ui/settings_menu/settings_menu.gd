class_name SettingsMenu
extends UIScreen
## Settings panel usable from both the start menu and the pause menu (it is
## opened via UIScreen.open_submenu in both cases). Pure view: every control
## writes straight to the Settings autoload, which applies + owns the values.
## Persisted once on teardown, whichever way the menu closes.

@onready var master_slider: HSlider = %MasterSlider
@onready var music_slider: HSlider = %MusicSlider
@onready var sfx_slider: HSlider = %SfxSlider
@onready var master_value: Label = %MasterValue
@onready var music_value: Label = %MusicValue
@onready var sfx_value: Label = %SfxValue
@onready var fullscreen_check: CheckButton = %FullscreenCheck
@onready var shake_check: CheckButton = %ShakeCheck
@onready var back_button: Button = %BackButton


func _ready() -> void:
	super()
	master_slider.value = Settings.master_volume
	music_slider.value = Settings.music_volume
	sfx_slider.value = Settings.sfx_volume
	fullscreen_check.button_pressed = Settings.fullscreen
	shake_check.button_pressed = Settings.screen_shake
	_update_value_labels()

	master_slider.value_changed.connect(func(v: float) -> void:
		Settings.master_volume = v
		_update_value_labels())
	music_slider.value_changed.connect(func(v: float) -> void:
		Settings.music_volume = v
		_update_value_labels())
	sfx_slider.value_changed.connect(func(v: float) -> void:
		Settings.sfx_volume = v
		_update_value_labels())
	fullscreen_check.toggled.connect(func(on: bool) -> void: Settings.fullscreen = on)
	shake_check.toggled.connect(func(on: bool) -> void: Settings.screen_shake = on)
	back_button.pressed.connect(func() -> void: back_requested.emit())

	# Fullscreen is meaningless inside a browser page.
	fullscreen_check.get_parent().visible = not OS.has_feature("web")


func _exit_tree() -> void:
	Settings.save_settings()


func _update_value_labels() -> void:
	master_value.text = "%d%%" % roundi(master_slider.value * 100.0)
	music_value.text = "%d%%" % roundi(music_slider.value * 100.0)
	sfx_value.text = "%d%%" % roundi(sfx_slider.value * 100.0)
