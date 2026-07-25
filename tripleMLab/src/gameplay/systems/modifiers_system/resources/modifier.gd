class_name Modifier
extends Resource

# Signals
# Enums
enum Type { ENTER_LEVEL, EXIT_LEVEL, EVENT_BASED, COLD_ORB_TOUCHED, HOT_ORB_TOUCHED }

## How long the player keeps this modifier once it has been added.
## PERMANENT — stays for the rest of the run.
## LEVELS    — dropped once `duration_levels` more levels have been completed.
## SECONDS   — dropped after `duration_seconds` of *time system* time, so a frozen
##             or slowed clock freezes/slows the countdown with it.
enum Duration { PERMANENT, LEVELS, SECONDS }
# Constants

# Exports
@export var type: Type = Type.EVENT_BASED
@export var stackable: bool = false
@export var modifier_name: String
@export var id: String
@export var icon: Texture
@export_multiline var description: String

@export_group("Duration")
@export var duration: Duration = Duration.PERMANENT
@export var duration_levels: int = 1
@export var duration_seconds: float = 10.0

@export_group("Extras")
## Odds of actually firing when triggered. 1.0 = always, 0.25 = a quarter of the time.
@export_range(0.0, 1.0) var chance: float = 1.0
## Trade-off partner: gaining this modifier also grants `linked_modifier`, so an
## upgrade can drag a downgrade along with it. Only followed one level deep — a
## linked modifier's own link is ignored.
@export var linked_modifier: Modifier

# Public
## Duration bookkeeping, seeded and ticked by ModifiersSystem.
var levels_remaining: int = 0
var seconds_remaining: float = 0.0

# Private
# On Ready

# Static

# Lifecycle
func trigger_modifier() -> void:
	pass

func deactivate_modifier() -> void:
	pass

## Called every frame by ModifiersSystem with the *real* delta. Modifiers with their
## own effect window override this. Real time is used on purpose, so a window still
## runs out while the clock is frozen (see FreezeModifier).
func tick(_delta: float) -> void:
	pass

# Public
## Lets a modifier swallow an orb whole — no time change and no orb trigger.
func blocks_orb(_orb_trigger: Type) -> bool:
	return false

## Lets a modifier rewrite an orb's time value before it is applied.
func modify_orb_value(_orb_trigger: Type, value: float) -> float:
	return value

# Workshop hooks. Same shape as the orb hooks above: the workshop asks every
# held modifier to adjust its numbers before it lays the bench out, so a
# modifier changes what a workshop *is* without the workshop knowing it exists.
# All of them are pass-through by default; see WorkshopModifier for the ones
# that actually answer.

## How many modifiers get laid out on the bench.
func modify_workshop_offers(count: int) -> int:
	return count

## How many of those the player is allowed to walk away with.
func modify_workshop_picks(count: int) -> int:
	return count

## How many times the bench can be swept and re-laid.
func modify_workshop_rerolls(count: int) -> int:
	return count

## Rebalances the draw — the hook behind "offers skew rare". Called once per
## candidate entry, with that entry's own weight.
func modify_workshop_offer_weight(weight: float, _tier: Rarity.Tier) -> float:
	return weight

## Seconds paid out for walking away from the bench without taking anything.
func modify_workshop_skip_bonus(seconds: float) -> float:
	return seconds

## Called on every held modifier once a workshop visit ends. Return true to be
## dropped — that's how a one-shot workshop perk spends itself. `picks_taken` is
## what the player actually left with, so a perk can decline to be spent on a
## visit where it did nothing.
func on_workshop_visited(_picks_taken: int) -> bool:
	return false

func get_description() -> String:
	return description

# Private
## Shared accessors so subclasses reach the run's systems the same way instead of
## each repeating the same null checks.
func _get_time_system() -> TimeSystem:
	if Global.main_game == null or Global.main_game.time_system == null:
		push_error("%s: TimeSystem not found." % modifier_name)
		return null
	return Global.main_game.time_system

func _get_modifiers_system() -> ModifiersSystem:
	if Global.main_game == null or Global.main_game.modifiers_system == null:
		push_error("%s: ModifiersSystem not found." % modifier_name)
		return null
	return Global.main_game.modifiers_system

func _get_player() -> Player:
	if Global.main_game == null or Global.main_game.player == null:
		push_error("%s: Player not found." % modifier_name)
		return null
	return Global.main_game.player

# Callbacks
