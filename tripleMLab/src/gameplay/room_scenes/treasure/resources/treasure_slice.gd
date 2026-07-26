class_name TreasureSlice
extends Resource
## One outcome a chest can produce: how likely it is, and what it does to the
## clock.
##
## A slice is deliberately dumb — a weight and a number of seconds. It knows
## nothing about coins, wheels or plinko boards; each minigame is a different way
## of *drawing* the same list of slices, which is what lets one table be played
## three ways (see [TreasureTable]).

# Exports
## What the player reads on a wheel wedge, a plinko bin or a coin face. Left
## empty it prints the seconds, which is usually the honest thing to say.
@export var label: String = ""
## Relative odds within its table. Written as percentages in the shipped tables
## (70.0 / 30.0) because that is how the design talks about them, but only the
## ratio matters.
@export var weight: float = 1.0
## Seconds the clock moves by. Positive is a payout, negative is a bite.
@export var seconds: float = 0.0

# Public
func is_gain() -> bool:
	return seconds >= 0.0


## The short form, for a wedge or a bin: "+10s", "-18s".
func get_label() -> String:
	if not label.is_empty():
		return label

	return "%+ds" % roundi(seconds)
