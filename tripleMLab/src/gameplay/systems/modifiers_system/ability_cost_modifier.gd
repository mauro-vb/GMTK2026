class_name AbilityCostModifier
extends Modifier
## Puts a price on a movement ability: every use of it burns `cost` seconds off
## the clock. See Player.pay_ability_cost().

# Signals
# Enums
# Constants

# Exports
@export var ability: Player.Ability = Player.Ability.DASH
@export var cost: float = 1.0
# Public

# Private
# On Ready

# Static

# Lifecycle
func trigger_modifier() -> void:
	var player: Player = _get_player()
	if player == null:
		return
	player.ability_time_costs[ability] = cost


func deactivate_modifier() -> void:
	var player: Player = _get_player()
	if player == null:
		return
	player.ability_time_costs.erase(ability)

# Public

# Private

# Callbacks
