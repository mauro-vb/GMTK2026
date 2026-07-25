class_name ConditionalTimeModifier
extends Modifier
## Pays out time at the end of a level, but only if the level was cleared slower
## or faster than `threshold_seconds`. Covers "Overtime" (SLOWER_THAN) and
## "Barely Made It" (FASTER_THAN). A negative `amount` gives the downgrade
## version — a penalty for dawdling or for rushing.

# Signals
# Enums
enum Comparison { SLOWER_THAN, FASTER_THAN }
# Constants

# Exports
@export var comparison: Comparison = Comparison.SLOWER_THAN
@export var threshold_seconds: float = 30.0
@export var amount: float = 5.0
# Public

# Private
# On Ready

# Static

# Lifecycle
func trigger_modifier() -> void:
	var time_system: TimeSystem = _get_time_system()
	var modifiers_system: ModifiersSystem = _get_modifiers_system()
	if time_system == null or modifiers_system == null:
		return

	var taken: float = modifiers_system.level_time_taken
	var passed: bool = taken > threshold_seconds
	if comparison == Comparison.FASTER_THAN:
		passed = taken < threshold_seconds
	if not passed:
		return

	time_system.add_time(amount)

# Public

# Private

# Callbacks
