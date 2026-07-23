class_name RunStats
extends HBoxContainer
## Always-visible run info: countdown timer and coin balance.
## Shared between MapHud and LevelHud.

const LOW_TIME_THRESHOLD: float = 30.0
const COLOR_NORMAL: Color = Color.WHITE
const COLOR_LOW_TIME: Color = Color(0.95, 0.3, 0.3)
const COLOR_COINS: Color = Color(1.0, 0.85, 0.4)

@onready var time_label: Label = %TimeLabel
@onready var coins_label: Label = %CoinsLabel


func _ready() -> void:
	coins_label.modulate = COLOR_COINS
	RunState.time_changed.connect(_on_time_changed)
	RunState.coins_changed.connect(_on_coins_changed)
	_on_time_changed(RunState.time_remaining)
	_on_coins_changed(RunState.coins)


func _on_time_changed(seconds_remaining: float) -> void:
	var total: int = ceili(seconds_remaining)
	@warning_ignore("integer_division")
	time_label.text = "%d:%02d" % [total / 60, total % 60]
	time_label.modulate = COLOR_LOW_TIME if seconds_remaining <= LOW_TIME_THRESHOLD else COLOR_NORMAL


func _on_coins_changed(coins: int) -> void:
	coins_label.text = "%d coins" % coins
