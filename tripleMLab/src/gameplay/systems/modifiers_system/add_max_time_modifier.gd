class_name AddMaxTimeModifier
extends Modifier
## Raises (or with a negative amount, lowers) the ceiling on how much time the
## player can hold. A negative amount is the ready-made downgrade version.

# Signals
# Enums
# Constants

# Exports
@export var amount: float = 10.0
# Public

# Private
# On Ready

# Static

# Lifecycle
func trigger_modifier() -> void:
	var time_system: TimeSystem = _get_time_system()
	if time_system == null:
		return
	time_system.add_max_time(amount)


func deactivate_modifier() -> void:
	var time_system: TimeSystem = _get_time_system()
	if time_system == null:
		return
	time_system.add_max_time(-amount)

# Public

# Private

# Callbacks
