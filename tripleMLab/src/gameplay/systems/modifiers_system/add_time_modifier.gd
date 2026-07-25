class_name AddTimeModifier
extends Modifier

# Signals
# Enums
# Constants

# Exports
@export var amount: int
# Public

# Private
# On Ready

# Static

# Lifecycle
func trigger_modifier() -> void:
	var time_system: TimeSystem = Global.main_game.time_system
	if time_system == null:
		push_error("TimeSystem not found.")
		return
	time_system.add_time(amount)

# Public

# Private

# Callbacks
