extends Node
## The one thing that outlives a run.
##
## [MainGame] rebuilds every system, the player and the map per run (see
## [method MainGame._teardown_run]), so nothing held by a run can remember
## anything about it. What the player has *proved* — that they beat the barrage
## once — has to sit above all of that, and be on disk, so it survives the
## window closing too.

# Constants
## Where the unlock is kept. One small file: there is one thing to remember.
const PROGRESS_PATH: String = "user://progress.cfg"
const PROGRESS_SECTION: String = "progress"
const HARD_MODE_UNLOCKED_KEY: String = "hard_mode_unlocked"

## What a hard-mode run starts with, as a fraction of [constant
## TimeSystem.STARTING_TIME]. Hard mode is only ever this number — the map, the
## rooms, the boss and every modifier are untouched, so what the mode asks is
## "do all of that on half the fuse" rather than "do a different game".
const HARD_MODE_TIME_SCALE: float = 0.5

var main_game: MainGame

## Whether the player has ever survived the barrage. Persisted; set once and
## never cleared.
var hard_mode_unlocked: bool = false

## Whether the *next* run starts on the short fuse. Deliberately not persisted:
## it is a choice made per session at the menu or off the win screen, and a game
## that silently reopens in hard mode is a game that looks broken.
var hard_mode: bool = false


# Lifecycle
func _ready() -> void:
	_load_progress()


# Public
## Records that the game has been beaten. Returns true only the first time, so
## the run-end screen can tell "you just unlocked this" from "this was already
## yours" without having to track it itself.
func unlock_hard_mode() -> bool:
	if hard_mode_unlocked:
		return false

	hard_mode_unlocked = true
	_save_progress()
	return true


# Private
func _load_progress() -> void:
	var config: ConfigFile = ConfigFile.new()
	# A missing file is the normal first-launch case, not something to report.
	if config.load(PROGRESS_PATH) != OK:
		return

	hard_mode_unlocked = config.get_value(PROGRESS_SECTION, HARD_MODE_UNLOCKED_KEY, false)


func _save_progress() -> void:
	var config: ConfigFile = ConfigFile.new()
	config.set_value(PROGRESS_SECTION, HARD_MODE_UNLOCKED_KEY, hard_mode_unlocked)

	var error: int = config.save(PROGRESS_PATH)
	if error != OK:
		push_error("Could not save progress to '%s' (error %d)" % [PROGRESS_PATH, error])
