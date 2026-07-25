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
	# A contribution of zero rather than an assignment of zero: a slow-burn
	# running at the same time keeps its own contribution, and gets it back
	# intact when this one thaws.
	time_system.set_rate_contribution(_rate_key(), 0.0)
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
		time_system.clear_rate_contribution(_rate_key())

	var player: Player = _get_player()
	if player != null:
		player.can_move = true


func _rate_key() -> StringName:
	return StringName("freeze:%d" % get_instance_id())

# Callbacks
