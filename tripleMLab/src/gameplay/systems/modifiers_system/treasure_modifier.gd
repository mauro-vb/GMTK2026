class_name TreasureModifier
extends Modifier
## Changes what a chest is worth rather than anything inside a level: how much a
## payout pays, and how much a bite takes.
##
## The workshop's counterpart is [WorkshopModifier], and this is deliberately the
## same shape — one class answering a small family of passive hooks, every field
## defaulting to "changes nothing", so a .tres only fills in what it is about.
##
## What is *not* here is any way to bend a chest's odds. A chest states its
## percentages on the map and again in the room before the player commits, and a
## modifier that quietly altered them would turn that statement into a lie. These
## change the stakes, never the dice.

# Signals
# Enums
# Constants

# Exports
## Multiplier on seconds won from a chest. 1.5 is a half again on every payout.
@export var gain_scale: float = 1.0
## Multiplier on seconds lost to a chest. 0.5 halves the damage; 0.0 makes the
## chest harmless, which is a very expensive thing to hand out.
@export var loss_scale: float = 1.0

@export_group("Extras")
## Flat seconds added on top of a payout, after `gain_scale`. Only ever applied
## to a win, so it can't accidentally soften a loss.
@export var gain_bonus_seconds: float = 0.0

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


func on_treasure_opened(seconds: float) -> bool:
	if not consume_on_use:
		return false

	# "Did this do anything?" — a charm that only sweetens wins is not spent by a
	# loss, and one that only softens losses is not spent by a win.
	if seconds >= 0.0:
		return not is_equal_approx(gain_scale, 1.0) or not is_zero_approx(gain_bonus_seconds)

	return not is_equal_approx(loss_scale, 1.0)


func get_description() -> String:
	if consume_on_use:
		return "%s\nSpent once used." % description

	return description

# Private

# Callbacks
