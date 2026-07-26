extends Node
## The one thing that outlives a run.
##
## [MainGame] rebuilds every system, the player and the map per run (see
## [method MainGame._teardown_run]), so nothing held by a run can remember
## anything about it. What the player has *proved* — how far up the ladder of
## difficulties they have carried a win — has to sit above all of that, and be
## on disk, so it survives the window closing too.

## The ladder. Each rung is the one below it plus one thing taken away, and each
## is unlocked by beating the one below it: beat the game to earn [constant
## Difficulty.HARD], beat that to earn [constant Difficulty.XTREME], beat that to
## earn [constant Difficulty.DEATH_MARCH]. Order matters — the enum's own
## ordering is what "harder than" means everywhere below.
enum Difficulty {
	NORMAL,
	HARD,
	XTREME,
	DEATH_MARCH,
}

# Constants
## Where progress is kept. One small file: there is one thing to remember.
const PROGRESS_PATH: String = "user://progress.cfg"
const PROGRESS_SECTION: String = "progress"
const UNLOCKED_DIFFICULTY_KEY: String = "unlocked_difficulty"
## The pre-ladder save format, when there was only hard mode to have earned.
## Read once on load so nobody who already beat the game loses their unlock.
const LEGACY_HARD_MODE_UNLOCKED_KEY: String = "hard_mode_unlocked"

## What every mode above [constant Difficulty.NORMAL] starts with, as a fraction
## of [constant TimeSystem.STARTING_TIME]. The short fuse is the first thing the
## ladder takes and it is never given back — the rungs above hard mode keep it
## and take a movement ability on top.
const SHORT_FUSE_SCALE: float = 0.5

const TIME_SCALES: Dictionary[Difficulty, float] = {
	Difficulty.NORMAL: 1.0,
	Difficulty.HARD: SHORT_FUSE_SCALE,
	Difficulty.XTREME: SHORT_FUSE_SCALE,
	Difficulty.DEATH_MARCH: SHORT_FUSE_SCALE,
}

## The rung at which each movement ability is taken away. Written as a threshold
## rather than a per-mode list because that is what the ladder actually is: a
## mode loses everything the modes below it lost, plus its own. [Player] is not
## named here on purpose — it reaches for [Global] itself, and a class the
## autoload also reaches for would be a cycle.
const DOUBLE_JUMP_LOST_AT: Difficulty = Difficulty.XTREME
const DASH_LOST_AT: Difficulty = Difficulty.DEATH_MARCH

const DISPLAY_NAMES: Dictionary[Difficulty, String] = {
	Difficulty.NORMAL: "Normal",
	Difficulty.HARD: "Hard",
	Difficulty.XTREME: "XTREME",
	Difficulty.DEATH_MARCH: "Death March",
}

## One line saying exactly what the mode costs, in the order it was taken. Shown
## on the menu next to the choice and on the screen that hands the mode over, so
## the player never has to find out by dying.
const TAGLINES: Dictionary[Difficulty, String] = {
	Difficulty.NORMAL: "The full minute.",
	Difficulty.HARD: "Half the fuse. Same job.",
	Difficulty.XTREME: "Half the fuse. No second jump.",
	Difficulty.DEATH_MARCH: "Half the fuse. No second jump. No dash.",
}

var main_game: MainGame

## The hardest mode the player is allowed to pick, i.e. the top of what they have
## earned. Persisted; only ever climbs.
var unlocked_difficulty: Difficulty = Difficulty.NORMAL

## What the *next* run is set to. Deliberately not persisted: it is a choice made
## per session at the menu or off the run-end screen, and a game that silently
## reopens on death march is a game that looks broken.
var difficulty: Difficulty = Difficulty.NORMAL


# Lifecycle
func _ready() -> void:
	_load_progress()


# Public
## Records that [member difficulty] has just been beaten, and hands over the rung
## above it.
##
## Returns the difficulty this win newly unlocked, or [constant
## Difficulty.NORMAL] for "nothing new" — normal is the floor, so it can never
## itself be an unlock, which makes it a sentinel nobody has to explain. That
## covers both beating a mode whose successor was already earned and beating the
## top of the ladder, which the run-end screen tells apart by looking at the
## ladder rather than at this.
func unlock_next_difficulty() -> Difficulty:
	var next: Difficulty = next_difficulty(difficulty)
	if next <= unlocked_difficulty:
		return Difficulty.NORMAL

	unlocked_difficulty = next
	_save_progress()
	return next


## The rung above [param from], or [param from] itself at the top of the ladder.
func next_difficulty(from: Difficulty) -> Difficulty:
	return mini(from + 1, Difficulty.DEATH_MARCH) as Difficulty


## Every mode the player may currently pick, easiest first. Always at least one
## entry, because normal is never locked.
func available_difficulties() -> Array[Difficulty]:
	var available: Array[Difficulty] = []
	for value: Difficulty in Difficulty.values():
		if value <= unlocked_difficulty:
			available.append(value)
	return available


## Whether there is anything left above what has been earned. False only once
## death march has been unlocked, which is the end of the game's demands.
func has_locked_difficulties() -> bool:
	return unlocked_difficulty < Difficulty.DEATH_MARCH


## The run's share of [constant TimeSystem.STARTING_TIME].
func time_scale() -> float:
	return TIME_SCALES.get(difficulty, 1.0)


## Whether this run gets to keep its second jump. False from XTREME up.
func keeps_double_jump() -> bool:
	return difficulty < DOUBLE_JUMP_LOST_AT


## Whether this run gets to keep its dash. False on death march.
func keeps_dash() -> bool:
	return difficulty < DASH_LOST_AT


static func display_name(value: Difficulty) -> String:
	return DISPLAY_NAMES.get(value, "Normal")


static func tagline(value: Difficulty) -> String:
	return TAGLINES.get(value, "")


# Private
func _load_progress() -> void:
	var config: ConfigFile = ConfigFile.new()
	# A missing file is the normal first-launch case, not something to report.
	if config.load(PROGRESS_PATH) != OK:
		return

	# The old save only knew "has hard mode been earned", which is exactly one
	# rung of the ladder — so an old file reads as hard mode unlocked and nothing
	# above it, and the player picks the climb back up from there.
	var legacy: bool = config.get_value(PROGRESS_SECTION, LEGACY_HARD_MODE_UNLOCKED_KEY, false)
	var fallback: Difficulty = Difficulty.HARD if legacy else Difficulty.NORMAL

	var stored: int = config.get_value(PROGRESS_SECTION, UNLOCKED_DIFFICULTY_KEY, fallback)
	# Clamped rather than trusted: this file is on the player's disk, and a
	# nonsense value in it must not become a nonsense difficulty at runtime.
	unlocked_difficulty = clampi(stored, Difficulty.NORMAL, Difficulty.DEATH_MARCH) as Difficulty


func _save_progress() -> void:
	var config: ConfigFile = ConfigFile.new()
	config.set_value(PROGRESS_SECTION, UNLOCKED_DIFFICULTY_KEY, unlocked_difficulty)
	# Kept written so a save that has climbed the ladder still opens correctly in
	# a build from before it existed.
	config.set_value(PROGRESS_SECTION, LEGACY_HARD_MODE_UNLOCKED_KEY,
		unlocked_difficulty >= Difficulty.HARD)

	var error: int = config.save(PROGRESS_PATH)
	if error != OK:
		push_error("Could not save progress to '%s' (error %d)" % [PROGRESS_PATH, error])
