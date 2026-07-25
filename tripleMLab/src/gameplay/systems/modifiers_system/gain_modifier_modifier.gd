class_name GainModifierModifier
extends Modifier
## Hands the player a random modifier out of `pool`. Set the inherited `chance`
## below 1.0 for a "sometimes you get something" reward, and/or `max_level_time`
## to only pay out on a fast clear.

# Signals
# Enums
# Constants

# Exports
@export var pool: Array[Modifier] = []
## Only pay out when the level was cleared in under this many seconds. 0 = no condition.
@export var max_level_time: float = 0.0
# Public

# Private
# On Ready

# Static

# Lifecycle
func trigger_modifier() -> void:
	var modifiers_system: ModifiersSystem = _get_modifiers_system()
	if modifiers_system == null:
		return
	if pool.is_empty():
		push_error("%s: modifier pool is empty." % modifier_name)
		return
	if max_level_time > 0.0 and modifiers_system.level_time_taken >= max_level_time:
		return

	modifiers_system.add_modifier(pool.pick_random())

# Public

# Private

# Callbacks
