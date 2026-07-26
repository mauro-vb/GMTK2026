class_name TreasureSet
extends Resource
## The two chests the map is allowed to place, and the deal that spreads them
## across a row.
##
## Every TREASURE room always pays or always bites — decided here, at map-gen
## time, not by a roll inside the room. A row is dealt from a shuffled bag
## weighted 2:1 good, so three chests side by side trend toward two good and
## one corrupted without ever being locked to exactly that split.

# Exports
@export var good_table: TreasureTable
@export var corrupted_table: TreasureTable

## Coin flip needs exactly two outcomes to have two faces, and this branch
## wants that call to be a clean "something or nothing" — so coin gets its own
## two-slice table (a stake and a zero) rather than sharing [member good_table]
## / [member corrupted_table], which now carry a third, middling outcome for
## the wheel and the board.
@export var good_coin_table: TreasureTable
@export var corrupted_coin_table: TreasureTable

# Public
## Deals `count` corruption flags for one row, from a bag weighted 2 good : 1
## corrupted. A row wider than the bag reshuffles and carries on, the same way
## chest dealing always has.
func deal(count: int) -> Array[bool]:
	var dealt: Array[bool] = []
	if count <= 0:
		return dealt

	var remaining: Array[bool] = []
	while dealt.size() < count:
		if remaining.is_empty():
			remaining = [false, false, true]
			remaining.shuffle()

		dealt.append(remaining.pop_back())

	return dealt


func table_for(corrupted: bool) -> TreasureTable:
	return corrupted_table if corrupted else good_table


func coin_table_for(corrupted: bool) -> TreasureTable:
	return corrupted_coin_table if corrupted else good_coin_table
