class_name WorkshopPool
extends Resource
## Everything a workshop is allowed to put on its bench, and the draw that picks
## from it.
##
## The draw is weighted and without replacement: a bench never shows the same
## modifier twice, and running short of candidates lays out a smaller bench
## rather than repeating itself or failing.

# Exports
@export var entries: Array[WorkshopEntry] = []

# Public
## Picks up to `count` distinct entries for a bench `depth` rows into the run.
## Returns fewer than asked for only when the pool genuinely runs out of things
## the player can still be offered.
func draw(count: int, depth: int, modifiers_system: ModifiersSystem) -> Array[WorkshopEntry]:
	var drawn: Array[WorkshopEntry] = []
	if count <= 0:
		return drawn

	var candidates: Array[WorkshopEntry] = []
	var weights: Array[float] = []
	var total: float = 0.0

	for entry: WorkshopEntry in entries:
		if entry == null or not entry.is_available(depth, modifiers_system):
			continue
		var weight: float = entry.get_draw_weight(depth, modifiers_system)
		if weight <= 0.0:
			continue

		candidates.append(entry)
		weights.append(weight)
		total += weight

	while drawn.size() < count and not candidates.is_empty():
		var index: int = _pick_index(weights, total)
		drawn.append(candidates[index])

		# Without replacement: pull the winner out and drop its weight from the
		# running total rather than re-summing the whole list each round.
		total -= weights[index]
		candidates.remove_at(index)
		weights.remove_at(index)

	if drawn.size() < count:
		push_warning("WorkshopPool: only %d of %d offers available at depth %d." % [drawn.size(), count, depth])

	return drawn

# Private
func _pick_index(weights: Array[float], total: float) -> int:
	var roll: float = randf() * total
	for index: int in weights.size():
		roll -= weights[index]
		if roll <= 0.0:
			return index

	# Only reachable through float drift on the last sliver of the range.
	return weights.size() - 1
