class_name WorkshopModifier
extends Modifier
## Changes the terms of the deal at a workshop rather than anything inside a
## level: how much is laid out, how much you may take, how many times the bench
## can be swept, what tends to be on it, and what walking away is worth.
##
## One class covers all of it because these are the same kind of thing — numbers
## the workshop asks for before it lays out — and because a single modifier often
## wants two of them at once (a wider bench that skews cheap, say). Every field
## defaults to "changes nothing", so a .tres only fills in what it is about.
##
## Nothing here triggers: these are answered through the passive workshop hooks
## on [Modifier], the same way "Coating" answers orb hooks instead of firing.

# Signals
# Enums
# Constants

# Exports
## Extra modifiers laid out on the bench. Negative narrows it — that's the
## downgrade version, and what "Cluttered Bench" is.
@export var extra_offers: int = 0
## Extra modifiers the player may walk away with. This is the pick-two perk.
@export var extra_picks: int = 0
## Extra sweeps of the bench, each one re-laying it from scratch.
@export var extra_rerolls: int = 0
## Seconds paid out for leaving a workshop without taking anything.
@export var skip_bonus_seconds: float = 0.0

@export_group("Odds")
## Multipliers on each tier's share of the draw. 1.0 leaves the tier alone;
## dropping commons and lifting exotics is what "skews rare" means in practice.
@export var common_weight_scale: float = 1.0
@export var rare_weight_scale: float = 1.0
@export var exotic_weight_scale: float = 1.0

@export_group("Extras")
## One-shot perks spend themselves on the first workshop the player actually
## takes something from. Leaving empty-handed doesn't burn it — the perk did
## nothing, so it keeps.
@export var consume_on_use: bool = false

# Public

# Private
# On Ready

# Static

# Lifecycle

# Public
func modify_workshop_offers(count: int) -> int:
	return count + extra_offers


func modify_workshop_picks(count: int) -> int:
	return count + extra_picks


func modify_workshop_rerolls(count: int) -> int:
	return count + extra_rerolls


func modify_workshop_offer_weight(weight: float, tier: Rarity.Tier) -> float:
	return weight * _scale_for(tier)


func modify_workshop_skip_bonus(seconds: float) -> float:
	return seconds + skip_bonus_seconds


func on_workshop_visited(picks_taken: int) -> bool:
	return consume_on_use and picks_taken > 0


func get_description() -> String:
	if consume_on_use:
		return "%s\nSpent once used." % description
	return description

# Private
func _scale_for(tier: Rarity.Tier) -> float:
	match tier:
		Rarity.Tier.RARE:
			return rare_weight_scale
		Rarity.Tier.EXOTIC:
			return exotic_weight_scale
		_:
			return common_weight_scale

# Callbacks
