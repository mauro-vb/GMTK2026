class_name TickRateModifier
extends Modifier
## Scales how fast the clock drains, via TimeSystem.tick_rate.
## 0.0 = frozen, 0.8 = 20% slower, 1.25 = 25% faster, 2.0 = double speed.
##
## Combined with the duration modes this covers a lot of ground:
##   multiplier 0.0 + LEVELS 1                → time doesn't tick next level
##   multiplier 0.0 + LEVELS 1 + chance 0.25  → time *might* not tick next level
##   multiplier 2.0 + LEVELS 3                → double speed for the next 3 levels
##   multiplier 0.8 + PERMANENT               → 20% slower for the rest of the run
##
## Known limitation: this saves and restores tick_rate, so two overlapping tick-rate
## modifiers only unwind cleanly if they expire in reverse order. Fine for one at a
## time; if overlapping ones become common, TimeSystem should multiply a list of
## contributions instead of holding a single tick_rate.

# Signals
# Enums
# Constants

# Exports
@export var multiplier: float = 1.0
# Public

# Private
## ENTER_LEVEL modifiers get triggered once per level, so without this guard a
## multi-level modifier would stack its multiplier again on every level.
var _applied: bool = false
var _previous_rate: float = 1.0
# On Ready

# Static

# Lifecycle
func trigger_modifier() -> void:
	if _applied:
		return
	var time_system: TimeSystem = _get_time_system()
	if time_system == null:
		return

	_applied = true
	_previous_rate = time_system.tick_rate
	time_system.tick_rate = _previous_rate * multiplier


func deactivate_modifier() -> void:
	if not _applied:
		return
	_applied = false
	var time_system: TimeSystem = _get_time_system()
	if time_system == null:
		return
	time_system.tick_rate = _previous_rate

# Public

# Private

# Callbacks
