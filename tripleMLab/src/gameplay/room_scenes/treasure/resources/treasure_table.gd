class_name TreasureTable
extends Resource
## One kind of chest: what it can pay out, how likely each outcome is, and which
## minigames are allowed to present it.
##
## This is the whole of a chest's design. Three tables ship — an even coin toss,
## a chest that usually pays and occasionally bites hard, and a chest that
## usually bites and occasionally pays hard — and a fourth is a `.tres`, not a
## change to any of the code below.
##
## The odds live here, and every game is built out of them — but not all of them
## resolve the same way. The coin and the wheel ask the table to [method roll]
## and then spend their animation arriving at that answer. A plinko board instead
## lays its bins out *from* these weights and lets the ball find one, so its odds
## come out close to the table's without being dictated by it. Which is the point
## of a board: nothing about where you drop it is a guarantee.
##
## What the games never do is print a percentage. A wheel says its odds with the
## size of its wedges and a board says them with the shape of its row; a line of
## numbers over the top of that is the same information twice, in the least
## readable form.

# Enums
## Which minigames may present this table, as bit flags — a table usually allows
## two of them and picks between them per visit, so the same chest doesn't play
## out the same way twice in a run.
enum Game {
	COIN = 1,
	WHEEL = 2,
	PLINKO = 4,
}

# Exports
@export var table_name: String = ""
## One line of flavour, shown under the chest's name while the player decides.
@export_multiline var description: String = ""
## A short, all-caps beat shown in the room's instruction line for a moment
## after the chest opens and before the minigame lays out — the room's own
## tiny "event" line. Kept terse on purpose: the instruction label has no
## word-wrap, so this has to read at a glance on a 320px-wide screen.
@export var entry_line: String = ""
@export_flags("Coin Flip:1", "Wheel:2", "Plinko:4") var games: int = Game.WHEEL | Game.PLINKO
@export var slices: Array[TreasureSlice] = []

@export_group("Map")
## ART: the chest as it sits on the map, and the same chest once it's been
## opened. Both fall back to the shared `chest.png` while the art is being drawn,
## so a table with neither still shows something readable (see [MapNode]).
@export var map_icon: Texture2D
@export var spent_icon: Texture2D

# Public
func is_valid() -> bool:
	return slices.size() >= 2 and total_weight() > 0.0


func allows(game: Game) -> bool:
	return (games & game) != 0


func total_weight() -> float:
	var total: float = 0.0
	for slice: TreasureSlice in slices:
		if slice == null:
			continue
		total += maxf(slice.weight, 0.0)

	return total


## Draws an outcome, exactly as authored. The coin and the wheel resolve through
## this; a plinko board does not — its bins are built from these weights and then
## the ball decides, which is a different and deliberate thing (see [PlinkoGame]).
func roll() -> TreasureSlice:
	var total: float = total_weight()
	if total <= 0.0:
		push_error("TreasureTable '%s': nothing to roll." % table_name)
		return null

	var target: float = randf() * total
	for slice: TreasureSlice in slices:
		if slice == null:
			continue
		target -= maxf(slice.weight, 0.0)
		if target <= 0.0:
			return slice

	# Only reachable through float drift on the last sliver of the range.
	return slices[slices.size() - 1]


## This slice's share of the draw, 0-1. Nothing in the game prints it — the
## chests state their odds by how they are drawn, not in percentages — but it is
## what a plinko board sizes its row of bins against, and what the debug tools
## report.
func chance_of(slice: TreasureSlice) -> float:
	var total: float = total_weight()
	if total <= 0.0 or slice == null:
		return 0.0

	return maxf(slice.weight, 0.0) / total


## The least likely outcome — the one a chest is really about, whichever
## direction it points. On "Rich Seam" it is the disaster; on "Dead Drop" it is
## the jackpot. Both are the thing worth playing for.
func rarest_slice() -> TreasureSlice:
	var rarest: TreasureSlice = null
	for slice: TreasureSlice in slices:
		if slice == null:
			continue
		if rarest == null or slice.weight < rarest.weight:
			rarest = slice

	return rarest


func best_slice() -> TreasureSlice:
	var best: TreasureSlice = null
	for slice: TreasureSlice in slices:
		if slice == null:
			continue
		if best == null or slice.seconds > best.seconds:
			best = slice

	return best


func worst_slice() -> TreasureSlice:
	var worst: TreasureSlice = null
	for slice: TreasureSlice in slices:
		if slice == null:
			continue
		if worst == null or slice.seconds < worst.seconds:
			worst = slice

	return worst


## The odds, spelled out: "70%  +10s   ·   30%  -18s".
##
## For debug output and tooling only. The rooms deliberately print no percentages
## at all: a wheel says its odds with the size of its wedges and a board says
## them with the shape of its row, and a line of numbers over the top of that is
## the same information twice, in the least readable form.
func get_odds_text() -> String:
	var parts: Array[String] = []
	for slice: TreasureSlice in slices:
		if slice == null:
			continue
		parts.append("%d%% %s" % [roundi(chance_of(slice) * 100.0), slice.get_label()])

	return "   ·   ".join(parts)
