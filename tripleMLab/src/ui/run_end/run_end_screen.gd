class_name RunEndScreen
extends UIScreen
## Shown when a run ends, either way: the countdown hitting zero (defeat) or
## clearing the final room (victory). One scene, two moods — call setup()
## before adding it to the tree.

signal retry_requested
signal menu_requested

const DEFEAT_TITLE: String = "TIME'S UP"
const VICTORY_TITLE: String = "RUN COMPLETE"
const COLOR_DEFEAT: Color = Color(0.949, 0.294, 0.294)
const COLOR_VICTORY: Color = Color(1.0, 0.851, 0.4)

var _victory: bool = false
var _stats: Dictionary = {}

@onready var title_label: Label = %TitleLabel
@onready var stats_label: Label = %StatsLabel
@onready var retry_button: Button = %RetryButton
@onready var menu_button: Button = %MenuButton


## stats keys: rooms (int), coins (int), relics (int), time_left (float)
func setup(victory: bool, stats: Dictionary) -> void:
	_victory = victory
	_stats = stats


func _ready() -> void:
	super()
	title_label.text = VICTORY_TITLE if _victory else DEFEAT_TITLE
	title_label.modulate = COLOR_VICTORY if _victory else COLOR_DEFEAT
	stats_label.text = _stats_text()
	retry_button.text = "NEW RUN" if _victory else "TRY AGAIN"
	retry_button.pressed.connect(func() -> void: retry_requested.emit())
	menu_button.pressed.connect(func() -> void: menu_requested.emit())
	back_requested.connect(func() -> void: menu_requested.emit())


func _stats_text() -> String:
	var lines: PackedStringArray = []
	lines.append("Rooms cleared: %d" % int(_stats.get("rooms", 0)))
	lines.append("Coins held: %d" % int(_stats.get("coins", 0)))
	lines.append("Relics found: %d" % int(_stats.get("relics", 0)))
	if _victory:
		var seconds: int = ceili(float(_stats.get("time_left", 0.0)))
		@warning_ignore("integer_division")
		lines.append("Time to spare: %d:%02d" % [seconds / 60, seconds % 60])
	return "\n".join(lines)
