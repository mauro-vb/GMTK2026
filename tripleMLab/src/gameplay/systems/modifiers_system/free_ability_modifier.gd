class_name FreeAbilityModifier
extends Modifier
## "Primed" — the first `uses` movement abilities of a level don't pay their time
## cost. Only does something while an ability actually costs time (see
## AbilityCostModifier), which is why it pairs well as a linked upgrade.

# Signals
# Enums
# Constants

# Exports
@export var uses: int = 1
# Public

# Private
# On Ready

# Static

# Lifecycle
func trigger_modifier() -> void:
	var player: Player = _get_player()
	if player == null:
		return
	player.free_ability_uses = uses


func deactivate_modifier() -> void:
	var player: Player = _get_player()
	if player == null:
		return
	player.free_ability_uses = 0

# Public

# Private

# Callbacks
