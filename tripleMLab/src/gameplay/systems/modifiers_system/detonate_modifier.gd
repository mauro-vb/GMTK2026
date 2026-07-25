class_name DetonateModifier
extends Modifier
## "Detonate" — touching a hot orb burns the whole remaining clock, not just its
## usual cost. Typed HOT_ORB_TOUCHED so the orb itself fires it.

# Signals
# Enums
# Constants

# Exports
# Public

# Private
# On Ready

# Static

# Lifecycle
func trigger_modifier() -> void:
	var time_system: TimeSystem = _get_time_system()
	if time_system == null:
		return
	time_system.remove_time(time_system.current_time)

# Public

# Private

# Callbacks
