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
## Dead weight until something has put a price on an ability — Player.pay_ability_cost()
## returns on `cost <= 0.0` before it ever looks at the free uses. So this is only
## worth offering to a run that already carries an AbilityCostModifier ("Costly
## Dash", which rides along with "Kick Start", or "Costly Pogo").
##
## Asks by class rather than by id: any future modifier that prices an ability
## makes this offerable again on its own.
func is_useful(modifiers_system: ModifiersSystem) -> bool:
	# Not knowing is not the same as knowing it's useless — don't hide the card
	# just because there's nobody to ask.
	if modifiers_system == null:
		return true

	for modifier: Modifier in modifiers_system.modifiers:
		if modifier is AbilityCostModifier:
			return true

	return false

# Private

# Callbacks
