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

## Rebalances the draw. Called once per candidate entry, with that entry's own
## weight and whether the card it would become carries a trade-off.
func modify_workshop_offer_weight(weight: float, _is_combined: bool) -> float:
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

# Treasure hooks. Same shape again: a chest pays out through these rather than
# straight into the clock, so a modifier can sweeten a win, soften a loss, lean
# on the odds or buy a second go without the treasure room knowing it exists.
# See [TreasureModifier].
#
# The one rule they all obey: **a chest never says one thing and does another.**
# The payout hooks are asked after the outcome is known, so they can't; the odds
# hook is asked *before the chest is laid out*, so the wheel's wedges and the
# board's row are cut from whatever it returns and the tilt is on screen before
# the player commits to it.

## Seconds a chest is about to pay out. `seconds` is positive.
func modify_treasure_gain(seconds: float) -> float:
	return seconds

## Seconds a chest is about to take. `seconds` is positive — it's an amount, not
## a signed change, so scaling it down is always the kind thing to do.
func modify_treasure_loss(seconds: float) -> float:
	return seconds

## One outcome's share of a chest's odds, asked once per outcome before the room
## lays the chest out. `is_gain` says which side of the table the weight belongs
## to, so a charm can lean a chest toward paying without knowing what any
## particular chest pays.
##
## This is the only hook that has to be answered early, and the reason is the
## rule above: a wheel cuts its wedges and a board deals its row from these
## numbers, so a tilt applied here is a tilt the player can read off the game in
## front of them. Bending the odds *after* a chest had drawn itself would make
## the drawing a lie, which is why there is no such hook.
func modify_treasure_weight(weight: float, _is_gain: bool) -> float:
	return weight

## Asked when a chest has bitten, before a single second is taken: return true to
## buy the player one more opening of the same chest, and the second outcome
## stands. Whoever says yes is spent on the spot (see
## [method ModifiersSystem.claim_treasure_retry]), which is what stops a retry
## from looping.
func wants_treasure_retry(_seconds: float) -> bool:
	return false

## Odds that a chest hands over a modifier as well as seconds, asked once the
## chest has settled. Zero on every chest until something the player is carrying
## says otherwise: a chest pays in time, and anything in the lining is something
## the player brought with them.
func modify_treasure_card_chance(chance: float, _was_gain: bool) -> float:
	return chance

## Whether the fuse keeps burning while a chest is open. False for everyone by
## default — a gamble is not a time trial — and the drawback half of a combined
## card is the only thing that says otherwise.
##
## The counterpart to "Live Wire" running the clock on the map screen, and the
## only kind of cost a treasure room has to offer: everything else it could take
## is seconds off a payout, and a card that pays for better odds with a worse
## payout is not a trade so much as a wash.
func runs_clock_in_treasure() -> bool:
	return false

## Called on every held modifier once a chest has paid out. Return true to be
## dropped. `seconds` is the signed change that was actually applied, so a
## one-shot charm can decline to spend itself on a chest it didn't help with.
func on_treasure_opened(_seconds: float) -> bool:
	return false

## Whether this modifier would do anything at all for the run as it stands.
##
## Almost everything is unconditionally useful and inherits `true`. The exception
## is a modifier that only modifies *another* modifier's effect — "Primed"
## refunds an ability's time cost, and abilities cost nothing until something has
## priced them, so on a run with nothing priced it is a card that does literally
## nothing.
##
## A workshop won't lay out a dead pick (see [WorkshopEntry.is_available]). Asked
## of the modifier rather than encoded in the pool so the answer can't go stale:
## adding a third modifier that prices an ability makes Primed offerable again
## without anyone remembering to update a list.
func is_useful(_modifiers_system: ModifiersSystem) -> bool:
	return true

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
