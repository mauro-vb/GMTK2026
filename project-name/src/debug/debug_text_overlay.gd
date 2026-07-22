class_name DebugTextOverlay
extends Control

const VERSION_SETTING: String = "application/config/version"
const NAME_SETTING: String = "application/config/name"

@onready var fps_label: Label = %FPSLabel
@onready var version_label: Label = %VersionLabel
@onready var debug_label: Label = %DebugLabel


func _ready() -> void:
	_set_version_label()
	_set_debug_label()

func _process(delta: float) -> void:
	_set_fps_label()

func _set_fps_label() -> void:
	var fps: float = Engine.get_frames_per_second()
	var color: Color = Color(0.049, 0.834, 0.0, 1.0)
	fps_label.set_text("FPS: " + str(fps))
	if fps < 45:
		color = Color(1.0, 0.164, 0.119, 1.0)
	fps_label.add_theme_color_override("font_color", color)

func _set_version_label() -> void:
	var version_str: String = ProjectSettings.get_setting(VERSION_SETTING)
	version_label.set_text("Build: " + version_str)

func _set_debug_label() -> void:
	var version_str: String = ProjectSettings.get_setting(NAME_SETTING)
	debug_label.set_text("Proejct: " + version_str)
