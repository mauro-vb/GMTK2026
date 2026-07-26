class_name TreasureSet
extends Resource
## Every kind of chest the map is allowed to place, and the deal that spreads
## them across a row.
##
## The point of a treasure row is the choice: three chests side by side, one on
## each path, each a different bet. So the row is *dealt* from a shuffled set
## rather than each chest rolling independently — three independent rolls would
## routinely hand out the same chest twice and quietly turn the choice into a
## formality.

# Exports
@export var tables: Array[TreasureTable] = []

# Public
## Deals `count` chests, all different while the set has different ones left. A
## row wider than the set reshuffles and carries on, so a five-chest row is two
## repeats rather than five of the same.
func deal(count: int) -> Array[TreasureTable]:
	var dealt: Array[TreasureTable] = []
	if count <= 0 or tables.is_empty():
		return dealt

	var remaining: Array[TreasureTable] = []
	while dealt.size() < count:
		if remaining.is_empty():
			remaining = tables.duplicate()
			remaining.shuffle()

		dealt.append(remaining.pop_back())

	return dealt


func pick() -> TreasureTable:
	if tables.is_empty():
		return null

	return tables[randi() % tables.size()]
