extends Node
## Drops straight into the boss fight, for tuning it:
##     godot res://src/debug/BossPlaytest.tscn
##
## Boots the real MainGame and walks into the FINAL room without the menu or a
## map run in between. Everything else is the real path — the player arrives on
## STARTING_TIME seconds with no modifiers, which is the plainest version of the
## fight there is.
##
## Debug keys, on top of the normal controls:
##   1 / 2 / 3   jump to the start of that phase
##   R           restart the fight

const MAIN_SCENE_UID: String = "uid://ccxuyq6o8k8ca"

var _level: BossLevel = null


func _ready() -> void:
	add_child((load(MAIN_SCENE_UID) as PackedScene).instantiate())
	await get_tree().process_frame

	var game: MainGame = Global.main_game
	game.load_game()
	game.enter_room(_boss_uid(), Room.Type.FINAL)
	_level = game.get("_current_room") as BossLevel


func _unhandled_key_input(event: InputEvent) -> void:
	if _level == null or not event.is_pressed():
		return

	var key: Key = (event as InputEventKey).keycode
	match key:
		KEY_1:
			_skip_to(BossLevel.Phase.GROUND_RUSH)
		KEY_2:
			_skip_to(BossLevel.Phase.RAIN)
		KEY_3:
			_skip_to(BossLevel.Phase.CROSSFIRE)
		KEY_R:
			_level.call("_start_fight")
			print("[playtest] restarted")


## Phases start where the previous one ends, and phase 1 starts at zero.
func _skip_to(phase: BossLevel.Phase) -> void:
	var start: float = 0.0 if phase == BossLevel.Phase.GROUND_RUSH else BossLevel.PHASE_END_TIMES[phase - 1]
	_level.set("_fight_time", start)
	print("[playtest] %s at %.0fs" % [BossLevel.Phase.keys()[phase], start])


## The boss level, found the way the run finds it: by scanning
## LevelPool.FINAL_LEVEL_DIR. Nothing registers the final level in [UIDs] any
## more, so neither does this.
func _boss_uid() -> String:
	var finals: Array[String] = LevelPool.scan(LevelPool.FINAL_LEVEL_DIR)
	return finals[0] if not finals.is_empty() else ""
