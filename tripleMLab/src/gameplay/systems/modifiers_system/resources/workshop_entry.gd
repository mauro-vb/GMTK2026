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
## Relative draw weight. 1.0 is the norm; drop it for something that should be a
## treat, raise it for something the run wants seen often.
@export var weight: float = 1.0
## Map row before which this never appears. Use it for anything that reads as a
## payoff — offering a run-defining modifier on the first bench spends it. With
## no rarity tiers, this and `weight` are the whole of the pool's pacing.
@export var min_depth: int = 0

# Public
## A card is combined when its modifier drags a trade-off along with it. Nothing
## marks this in the data: carrying a `linked_modifier` *is* what being combined
## means, so an entry can never disagree with the modifier it points at.
func is_combined() -> bool:
	return modifier != null and modifier.linked_modifier != null

## Whether a workshop this deep into a run may offer this at all. Modifiers the
## player already holds are filtered out too, unless the modifier stacks — and so
## are ones that would do nothing for this particular run (see
## [method Modifier.is_useful]), because a bench slot spent on a card that can't
## help is worse than a slot spent on a boring one.
func is_available(depth: int, modifiers_system: ModifiersSystem) -> bool:
	if modifier == null:
		return false
	if depth < min_depth:
		return false
	if modifiers_system != null and modifiers_system.has_modifier(modifier.id) and not modifier.stackable:
		return false
	if not modifier.is_useful(modifiers_system):
		return false

	return true

## Weight this entry draws with, after the player's own modifiers have had their
## say — which is how a perk tilts a bench toward or away from trade-off cards.
func get_draw_weight(modifiers_system: ModifiersSystem) -> float:
	var value: float = maxf(weight, 0.0)
	if modifiers_system != null:
		value = modifiers_system.get_workshop_offer_weight(value, is_combined())

	return value
