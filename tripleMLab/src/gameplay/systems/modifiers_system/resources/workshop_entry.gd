class_name WorkshopEntry
extends Resource
## One line in a [WorkshopPool]: a modifier plus the terms on which a workshop is
## allowed to offer it.
##
## Kept separate from the modifier itself on purpose. "How good is this?" is a
## property of the modifier; "how often does it turn up on a bench, and how early"
## is a property of the run's pacing, and the same modifier can arrive by other
## routes (Lucky Find, a linked trade-off) that these terms have no say over.

# Exports
@export var modifier: Modifier

@export_group("Terms")
@export var tier: Rarity.Tier = Rarity.Tier.COMMON
## Relative draw weight *within* the tier, before rarity and depth are folded in.
## Leave at 1.0 unless a modifier should be notably more or less common than its
## tier-mates.
@export var weight: float = 1.0
## Map row before which this never appears. Use it for anything that reads as a
## payoff — offering a run-defining modifier on the first bench spends it.
@export var min_depth: int = 0

# Public
## Whether a workshop this deep into a run may offer this at all. Modifiers the
## player already holds are filtered out too, unless the modifier stacks.
func is_available(depth: int, modifiers_system: ModifiersSystem) -> bool:
	if modifier == null:
		return false
	if depth < min_depth:
		return false
	if modifiers_system != null and modifiers_system.has_modifier(modifier.id) and not modifier.stackable:
		return false

	return true

## Weight this entry draws with on a bench that deep into the run, after the
## player's own modifiers have had their say (see "Blueprints").
func get_draw_weight(depth: int, modifiers_system: ModifiersSystem) -> float:
	var value: float = maxf(weight, 0.0) * Rarity.depth_weight(tier, depth)
	if modifiers_system != null:
		value = modifiers_system.get_workshop_offer_weight(value, tier)

	return value
