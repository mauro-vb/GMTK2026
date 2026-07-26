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
## Registers itself as one contribution to TimeSystem's rate rather than saving
## and restoring the whole thing, so any number of these can overlap — with each
## other and with a freeze — and unwind in any order.

# Signals
# Enums
# Constants

# Exports
@export var multiplier: float = 1.0
# Public

# Private
## ENTER_LEVEL modifiers get triggered once per level, so without this guard a
## multi-level modifier would register itself afresh on every level.
var _applied: bool = false
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
	time_system.set_rate_contribution(_rate_key(), multiplier)


func deactivate_modifier() -> void:
	if not _applied:
		return
	_applied = false
	var time_system: TimeSystem = _get_time_system()
	if time_system == null:
		return
	time_system.clear_rate_contribution(_rate_key())

# Public

# Private
## Per instance, not per id: two stacks of the same modifier each slow the clock.
func _rate_key() -> StringName:
	return StringName("tick_rate:%d" % get_instance_id())

# Callbacks
