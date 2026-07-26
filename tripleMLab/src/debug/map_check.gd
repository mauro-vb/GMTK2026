extends Node
## Headless sanity check for the map's fit inside its frame:
##     godot --headless res://src/debug/MapCheck.tscn
##
## Runs as a scene rather than via `--script` on purpose: the map needs a
## viewport and a tree, and half of this touches Global.
##
## The map is laid out fresh every run and the paths wander, so "does it fit?"
## is not a question one screenshot answers — a tree that clears the stonework
## on the map in front of you can still be dealt one lane wider next run. So this
## deals a lot of maps and checks every drawn room against the frame, which is
## the only way to be sure of a layout nobody authored by hand.
##
## Not a test framework — it prints what it found and quits non-zero if something
## is wrong.

## Enough maps that a lane the generator only rarely reaches still shows up.
const MAPS: int = 300

var _failures: int = 0
## The tightest fit seen, as the gap in pixels between the tree and the nearest
## edge of the play area. Printed rather than asserted on: the axis the squeeze
## fitted lands on 0 by construction — that is what fitting means — and it is the
## slack already built into [constant Map.ICON_HALF_EXTENTS] that keeps the art
## itself off the stonework. A *negative* number here is the thing to fear, and
## the pass/fail above is what catches that.
var _tightest: float = INF


func _ready() -> void:
	await _check_fit()
	_finish()


func _check_fit() -> void:
	print("\n[ map fit ]  %d maps against %s" % [MAPS, Map.PLAY_AREA])

	var map_scene: PackedScene = load(UIDs.MAP_SCENE_UID)
	if not _check(map_scene != null, "the map scene loads"):
		return

	var overflowed: int = 0
	for index: int in MAPS:
		var map: Map = map_scene.instantiate() as Map
		add_child(map)

		var occupied: Rect2 = _occupied_rect(map)
		if not Map.PLAY_AREA.encloses(occupied):
			overflowed += 1
			if overflowed == 1:
				print("  first overflow, map %d: %s pokes out of %s" % [
					index, occupied, Map.PLAY_AREA,
				])

		_tightest = minf(_tightest, _clearance(occupied))

		map.queue_free()
		await map.tree_exited

	_check(overflowed == 0, "every map fits the frame (%d of %d overflowed)" % [overflowed, MAPS])
	print("  tightest clearance seen: %.1fpx" % _tightest)


## What the drawn tree covers, icons included — the rooms are positioned by their
## centres, so the rect their positions span is a half-icon short on every side
## of what is actually on screen.
func _occupied_rect(map: Map) -> Rect2:
	var covered: Rect2 = Rect2()
	var first: bool = true

	for map_node: MapNode in map.nodes.get_children():
		var centre: Vector2 = map.visuals.position + map_node.position
		var icon: Rect2 = Rect2(centre - Map.ICON_HALF_EXTENTS, Map.ICON_HALF_EXTENTS * 2.0)
		covered = icon if first else covered.merge(icon)
		first = false

	return covered


## The smallest gap between the tree and any edge of the play area. Negative
## means it has escaped.
func _clearance(occupied: Rect2) -> float:
	return minf(
		minf(occupied.position.x - Map.PLAY_AREA.position.x,
			occupied.position.y - Map.PLAY_AREA.position.y),
		minf(Map.PLAY_AREA.end.x - occupied.end.x,
			Map.PLAY_AREA.end.y - occupied.end.y),
	)


func _check(condition: bool, description: String) -> bool:
	print("  %s %s" % ["PASS" if condition else "FAIL", description])
	if not condition:
		_failures += 1
	return condition


func _finish() -> void:
	print("\n%s (%d failure(s))\n" % ["OK" if _failures == 0 else "FAILED", _failures])
	get_tree().quit(0 if _failures == 0 else 1)
