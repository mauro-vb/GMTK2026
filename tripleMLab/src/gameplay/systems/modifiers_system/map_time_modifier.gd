class_name MapTimeModifier
extends Modifier
## "Live Wire" — the clock keeps draining while the player is sitting on the map,
## instead of only inside rooms.
##
## Typed EXIT_LEVEL rather than EVENT_BASED: MainGame.exit_room() switches the
## clock off just *before* it runs the EXIT_LEVEL modifiers, so that's the one
## moment where it can be switched back on for the map screen without fighting
## MainGame over who owns `ticking`.

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
	time_system.ticking = true


func deactivate_modifier() -> void:
	var time_system: TimeSystem = _get_time_system()
	if time_system == null:
		return
	time_system.ticking = false

# Public

# Private

# Callbacks
