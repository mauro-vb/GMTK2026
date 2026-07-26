class_name TreasureModifier
extends Modifier
## Changes the terms of a chest rather than anything inside a level: what a
## payout pays, what a bite takes, how likely each of those is, whether a bad
## chest gets opened a second time, and whether one hands over a card as well as
## seconds.
##
## The workshop's counterpart is [WorkshopModifier], and this is deliberately the
## same shape — one class answering a small family of passive hooks, every field
## defaulting to "changes nothing", so a .tres only fills in what it is about.
##
## The odds *are* on offer here, unlike the first pass at this file, but only on
## one condition: they are asked for before the chest draws itself, so the wheel
## and the board are built out of the tilted numbers (see
## [method Modifier.modify_treasure_weight]). A chest never advertises one thing
## and does another; it just advertises the chest the player is actually holding.

# Signals
# Enums
# Constants

# Exports
## Multiplier on seconds won from a chest. 1.5 is a half again on every payout.
@export var gain_scale: float = 1.0
## Multiplier on seconds lost to a chest. 0.5 halves the damage; 0.0 makes the
## chest harmless, which is a very expensive thing to hand out.
@export var loss_scale: float = 1.0

@export_group("Odds")
## Multipliers on how likely each side of a chest is, applied before the chest
## lays itself out. 1.5 on the gain gives every paying outcome half again its
## share of the wheel — and the wedge really is that much bigger, because the
## wheel is cut after this runs.
##
## Both sides are offered because the interesting cards are the ones that pay
## for a tilt: leaning a chest toward paying and shrinking what it pays is one
## card, not a bonus.
@export var gain_weight_scale: float = 1.0
@export var loss_weight_scale: float = 1.0

@export_group("Extras")
## Flat seconds added on top of a payout, after `gain_scale`. Only ever applied
## to a win, so it can't accidentally soften a loss.
@export var gain_bonus_seconds: float = 0.0

## Buys one more opening of a chest that has just bitten — a different minigame
## as often as not — and the second outcome is the one that counts. Spent the
## moment it is used, by [method ModifiersSystem.claim_treasure_retry], so it
## can't hand out retries forever.
@export var retry_on_loss: bool = false

## Odds that a chest also coughs up a modifier, split by what the chest did.
## Zero on both is the default: seconds are what a chest owes.
@export_range(0.0, 1.0) var gain_card_chance: float = 0.0
@export_range(0.0, 1.0) var loss_card_chance: float = 0.0

## Keeps the fuse burning while a chest is open, instead of the room's usual
## "a gamble is not a time trial". This is the drawback half of a combined card
## and nothing else: it is the only price a treasure room can charge that isn't
## just a smaller payout.
@export var runs_clock: bool = false

## One-shot charms spend themselves on the first chest they actually changed. A
## chest that paid out nothing the modifier could touch doesn't burn it.
@export var consume_on_use: bool = false

# Public

# Private
# On Ready

# Static

# Lifecycle

# Public
func modify_treasure_gain(seconds: float) -> float:
	return seconds * gain_scale + gain_bonus_seconds


func modify_treasure_loss(seconds: float) -> float:
	return seconds * loss_scale


func modify_treasure_weight(weight: float, is_gain: bool) -> float:
	return weight * (gain_weight_scale if is_gain else loss_weight_scale)


func wants_treasure_retry(_seconds: float) -> bool:
	return retry_on_loss


func runs_clock_in_treasure() -> bool:
	return runs_clock


## Folded as an independent chance rather than added on, so two charms that each
## pay half the time come out at three quarters and no stack ever reaches
## certainty by arithmetic alone.
func modify_treasure_card_chance(chance: float, was_gain: bool) -> float:
	var own: float = gain_card_chance if was_gain else loss_card_chance
	if own <= 0.0:
		return chance

	return 1.0 - (1.0 - clampf(chance, 0.0, 1.0)) * (1.0 - own)


func on_treasure_opened(seconds: float) -> bool:
	if not consume_on_use:
		return false

	# "Did this do anything?" — a charm that only sweetens wins is not spent by a
	# loss, and one that only softens losses is not spent by a win.
	if seconds >= 0.0:
		return not is_equal_approx(gain_scale, 1.0) or not is_zero_approx(gain_bonus_seconds)

	return not is_equal_approx(loss_scale, 1.0)


func get_description() -> String:
	# A retry spends itself on the chest it rescues, so it says so for the same
	# reason a one-shot charm does: the card is the last warning.
	if consume_on_use or retry_on_loss:
		return "%s\nSpent once used." % description

	return description

# Private

# Callbacks
