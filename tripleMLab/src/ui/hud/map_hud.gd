class_name MapHud
extends Control

# Signals
# Enums
# Constants

# Exports

# Public
# Private
# On Ready
@onready var time_label: Label = %TimeLabel

# Static

# Lifecycle
func _ready() -> void:
	if Global.main_game == null:
		push_error("MainGame reference is missing.")
		return

	if Global.main_game.time_system == null:
		push_error("MainGame has no TimeSystem assigned.")
		return
	time_label.text = str(ceil(Global.main_game.time_system.current_time))
	Global.main_game.time_system.time_changed.connect(_on_time_changed)

func _on_time_changed(value: float) -> void:
	time_label.text = str(ceil(value))

# Public

# Private

# Callbacks
