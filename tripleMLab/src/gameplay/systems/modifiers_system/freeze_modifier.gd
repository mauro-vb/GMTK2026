class_name FreezeModifier
extends Modifier
## "Cold Fuse" — the clock stops and the player is frozen in place for the first
## `freeze_seconds` of a level. The window runs on real seconds, because game
## time is exactly what this modifier switches off.

# Signals
# Enums
# Constants

# Exports
@export var freeze_seconds: float = 2.0
# Public

# Private
var _remaining: float = 0.0
var _previous_tick_rate: float = 1.0
# On Ready

# Static

# Lifecycle
func trigger_modifier() -> void:
	var time_system: TimeSystem = _get_time_system()
	var player: Player = _get_player()
	if time_system == null or player == null:
		return
	if _remaining > 0.0:
		return

	_remaining = freeze_seconds
	_previous_tick_rate = time_system.tick_rate
	time_system.tick_rate = 0.0
	player.can_move = false


func deactivate_modifier() -> void:
	if _remaining <= 0.0:
		return
	_remaining = 0.0
	_thaw()


func tick(delta: float) -> void:
	if _remaining <= 0.0:
		return
	_remaining -= delta
	if _remaining <= 0.0:
		_thaw()

# Public

# Private
func _thaw() -> void:
	var time_system: TimeSystem = _get_time_system()
	if time_system != null:
		time_system.tick_rate = _previous_tick_rate

	var player: Player = _get_player()
	if player != null:
		player.can_move = true

# Callbacks
