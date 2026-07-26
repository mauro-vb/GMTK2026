class_name LevelPool
extends RefCounted
## The run's levels, dealt out of a directory rather than named one by one.
##
## Dropping a `.tscn` into [constant LEVEL_DIR] puts it in the rotation — nothing
## has to be registered, and no uid has to be copied into [UIDs]. That is the
## whole point: levels are being authored right up to submission, and a pool that
## has to be edited every time one lands is a pool that goes stale.
##
## Levels are dealt from a shuffled bag rather than rolled independently, so a
## nine-room run uses nine *different* levels before it repeats any of them. An
## independent roll per room would hand a player the same level twice in a row
## often enough to be the thing they remember about the run.
##
## The final room draws from its own directory ([constant FINAL_LEVEL_DIR]) so
## the run's last level is authored deliberately instead of pulled at random. If
## that directory is empty the pool falls back to an ordinary level, so a build
## still finishes rather than dead-ending on a room that won't load.

# Constants
## Every `.tscn` in here is a level the run can deal.
const LEVEL_DIR: String = "res://src/levels/initial_levels"
## The last room of the run. Usually exactly one scene.
const FINAL_LEVEL_DIR: String = "res://src/levels/final_level"

# Private
var _levels: Array[String] = []
var _finals: Array[String] = []
## What is left of the current shuffle. Refilled from [member _levels] when empty.
var _bag: Array[String] = []

# Lifecycle
func _init() -> void:
	_levels = scan(LEVEL_DIR)
	_finals = scan(FINAL_LEVEL_DIR)

	if _levels.is_empty():
		push_error("LevelPool: no levels found in %s" % LEVEL_DIR)

# Public
## The next level for an ordinary LEVEL room.
func next_level_uid() -> String:
	if _levels.is_empty():
		return UIDs.FALLBACK_LEVEL_UID

	if _bag.is_empty():
		_bag = _levels.duplicate()
		_bag.shuffle()

	return _bag.pop_back()


## The level the run ends on.
func final_level_uid() -> String:
	if _finals.is_empty():
		push_warning("LevelPool: %s is empty, ending the run on an ordinary level." % FINAL_LEVEL_DIR)
		return next_level_uid()

	return _finals.pick_random()


# Static
## Every scene in `dir_path`, as `uid://` references.
##
## Two things make this less direct than a directory listing. Exported builds
## ship scenes as `<name>.tscn.remap` next to the binary the remap points at, so
## the suffix has to come off before the name means anything. And a uid is worth
## resolving rather than handing the path straight back — the rest of the project
## addresses scenes by uid, so a level stays findable after somebody moves it.
static func scan(dir_path: String) -> Array[String]:
	var found: Array[String] = []

	for file: String in DirAccess.get_files_at(dir_path):
		if file.ends_with(".remap"):
			file = file.trim_suffix(".remap")
		if not file.ends_with(".tscn"):
			continue

		var path: String = dir_path.path_join(file)
		var id: int = ResourceLoader.get_resource_uid(path)
		# A scene with no uid still loads perfectly well by path; it just can't
		# be moved without breaking. Better a level in the rotation than a gap.
		found.append(ResourceUID.id_to_text(id) if id != ResourceUID.INVALID_ID else path)

	# DirAccess makes no promise about order, and an unstable order would make a
	# seeded shuffle unreproducible. Sorting first means the shuffle is the only
	# randomness in play.
	found.sort()
	return found
