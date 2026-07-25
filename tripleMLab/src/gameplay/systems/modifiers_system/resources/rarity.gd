class_name Rarity
extends RefCounted
## How hard a modifier is to come by, plus everything that follows from it: the
## odds it turns up on a workshop bench, the colour of the card it arrives on,
## and the word printed across that card's ribbon.
##
## Deliberately dependency-free — Modifier's workshop hooks, WorkshopEntry's data
## and WorkshopCard's styling all speak this vocabulary, and none of them should
## have to know about the other two to do it. Never instantiated; it is a
## namespace with an enum in it.

# Enums
enum Tier { COMMON, RARE, EXOTIC }

# Constants
## Printed on the card. Colour alone can't carry rarity — brass and fuse-green
## are close enough for a red-green colourblind player that the word has to be
## there too.
const NAMES: Dictionary[Tier, String] = {
	Tier.COMMON: "COMMON",
	Tier.RARE: "RARE",
	Tier.EXOTIC: "EXOTIC",
}

## Slate, brass, fuse-green: dug up, worth keeping, and shouldn't be in here.
const COLORS: Dictionary[Tier, Color] = {
	Tier.COMMON: Color(0.478, 0.522, 0.596),
	Tier.RARE: Color(0.929, 0.706, 0.290),
	Tier.EXOTIC: Color(0.400, 0.902, 0.573),
}

## Share of the draw at the very start of a run, before depth is applied.
const BASE_WEIGHT: Dictionary[Tier, float] = {
	Tier.COMMON: 1.0,
	Tier.RARE: 0.50,
	Tier.EXOTIC: 0.15,
}

## How that share moves per map row travelled. Commons thin out slowly while the
## good stuff climbs, so a bench late in a run reads as a reward for getting
## there rather than as the same bench with different names on it.
const DEPTH_GAIN: Dictionary[Tier, float] = {
	Tier.COMMON: -0.045,
	Tier.RARE: 0.05,
	Tier.EXOTIC: 0.14,
}

## Commons never vanish entirely — a bench with nothing plain on it has no floor
## for the rare things to stand out against.
const MIN_WEIGHT: float = 0.02

# Static
## Named `display_*` rather than `get_*`: these are called on the class itself,
## and a static `get_name` there is shadowed by GDScript's own `get_name` on the
## script object — it resolves, then fails at runtime on the argument count.
static func display_name(tier: Tier) -> String:
	return NAMES.get(tier, NAMES[Tier.COMMON])

static func display_color(tier: Tier) -> Color:
	return COLORS.get(tier, COLORS[Tier.COMMON])

## Draw weight for a tier this far into a run. `depth` is the map row reached.
static func depth_weight(tier: Tier, depth: int) -> float:
	var base: float = BASE_WEIGHT.get(tier, 1.0)
	var gain: float = DEPTH_GAIN.get(tier, 0.0)
	return maxf(base * (1.0 + gain * float(depth)), MIN_WEIGHT)
