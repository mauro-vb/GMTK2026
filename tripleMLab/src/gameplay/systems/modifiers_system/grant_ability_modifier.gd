class_name GrantAbilityModifier
extends Modifier
## Unlocks one of the player's movement abilities. Flip `granted` to false for the
## obvious downgrade version, which takes the ability away instead — handy as the
## linked partner of a strong upgrade.

# Signals
# Enums
# Constants

# Exports
@export var ability: Player.Ability = Player.Ability.DASH
@export var granted: bool = true
# Public

# Private
# On Ready

# Static

# Lifecycle
func trigger_modifier() -> void:
	_set_ability(granted)


func deactivate_modifier() -> void:
	_set_ability(not granted)

# Public

# Private
func _set_ability(value: bool) -> void:
	var player: Player = _get_player()
	if player == null:
		return

	match ability:
		Player.Ability.DASH:
			player.has_dash_ability = value
		Player.Ability.DOUBLE_JUMP:
			player.has_double_jump_ability = value
		Player.Ability.POGO:
			player.has_pogo_ability = value

# Callbacks
