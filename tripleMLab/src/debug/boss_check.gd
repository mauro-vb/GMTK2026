extends Node
## Headless sanity check for the final boss:
##     godot --headless res://src/debug/BossCheck.tscn
##
## Same shape as [WorkshopCheck] — a scene rather than a `--script` run, because
## autoloads only exist for a scene run and all of this goes through Global.
##
## The fight is seventy seconds long, which is far too long to sit through on
## every change, so the phases are reached by writing [member BossLevel._fight_time]
## directly rather than by waiting. Everything downstream of that — phase entry,
## telegraphs, spawning, the win — is the real code path.
##
## Not a test framework. It prints what it found and quits non-zero if something
## is wrong, which is enough to catch a broken uid or a phase that stopped
## telegraphing before it reaches a playtest.

const MAIN_SCENE_UID: String = "uid://ccxuyq6o8k8ca"

## Long enough for a physics frame to have run, short enough to stay inside a
## telegraph's wind-up.
const BEAT: float = 0.15

var _failures: int = 0


func _ready() -> void:
	_check_wiring()
	await _check_fight()
	_finish()


# --- Wiring ------------------------------------------------------------------
## The three edits that took FINAL from a dead end to a room.
func _check_wiring() -> void:
	print("\n[ wiring ]")

	var finals: Array[String] = LevelPool.scan(LevelPool.FINAL_LEVEL_DIR)
	if not _check(finals.size() == 1, "final_level/ holds exactly one scene (found %d)" % finals.size()):
		return

	_check(load(finals[0]) is PackedScene, "...and it loads")

	# The pool is what deals the last room, so this is the real question: does a
	# FINAL room end up pointing at the boss without anything registering it?
	var room: Room = Room.new()
	room.type = Room.Type.FINAL
	room.apply_type_scene(LevelPool.new())
	_check(room.scene_uid == finals[0], "a FINAL room is dealt the boss level")


# --- The fight ---------------------------------------------------------------
func _check_fight() -> void:
	print("\n[ entering the boss room ]")

	var main_scene: PackedScene = load(MAIN_SCENE_UID) as PackedScene
	if not _check(main_scene != null, "main scene loads"):
		return

	add_child(main_scene.instantiate())
	await get_tree().process_frame

	var game: MainGame = Global.main_game
	if not _check(game != null, "MainGame registered itself with Global"):
		return

	game.load_game()
	game.enter_room(_boss_uid(), Room.Type.FINAL)

	var level: BossLevel = game.get("_current_room") as BossLevel
	if not _check(level != null, "a FINAL room loads a BossLevel"):
		return

	_check(not level.should_tick_time, "the room does not tick the clock")
	_check(not game.time_system.ticking, "...so the run clock is stopped for the fight")
	_check(game.player.global_position == level.player_spawn.global_position,
		"the player starts on the spawn")

	# Two physics frames past the point LevelExit re-enables its own monitoring.
	await get_tree().create_timer(0.3).timeout
	_check(not level.level_exit.visible, "the exit starts hidden")
	_check(not level.level_exit.monitoring, "...and stays switched off after LevelExit's own _ready")
	_check(not _platforms_solid(level), "the phase 2 platforms start intangible")
	_check(is_zero_approx(level.phase_2_platforms.modulate.a), "...and invisible")

	await _check_ground_rush(level)
	await _check_rain(level)
	await _check_crossfire(level)
	await _check_hits(game, level)
	# Survival last of the three, because winning ends the run — the defeat check
	# below deals itself a fresh one rather than carrying on in a finished room.
	await _check_survival(game, level)
	await _check_defeat(game)


func _check_ground_rush(level: BossLevel) -> void:
	print("\n[ phase 1: ground rush ]")

	await get_tree().create_timer(BossLevel.RUSH_INTERVAL.x + BEAT).timeout

	var live: Array[BossProjectile] = _projectiles(level)
	if not _check(not live.is_empty(), "the rush is spawning"):
		return

	var horizontal: bool = true
	var at_floor: bool = true
	for projectile: BossProjectile in live:
		horizontal = horizontal and is_zero_approx(projectile.velocity.y) and projectile.velocity.x < 0.0
		at_floor = at_floor and is_equal_approx(projectile.position.y, BossLevel.RUSH_Y)

	_check(horizontal, "every rush orb travels flat, leftwards")
	_check(at_floor, "...at floor height, so the answer is always a jump")
	_check(level.markers.get_child_count() == 0, "phase 1 needs no telegraphs")
	# A second of standing still is enough to fall out of a floor that isn't
	# there, which is the only way the hand-authored tile data can be wrong in a
	# way nothing else here would notice.
	_check(Global.main_game.player.global_position.y < level.player_spawn.global_position.y + 8.0,
		"the arena floor holds the player up")


func _check_rain(level: BossLevel) -> void:
	print("\n[ phase 2: rain ]")

	_jump_to(level, BossLevel.PHASE_END_TIMES[BossLevel.Phase.GROUND_RUSH])
	await get_tree().create_timer(BEAT).timeout

	_check(level.markers.get_child_count() > 0, "a drop is announced before it exists")
	_check(_falling(level).is_empty(), "...and nothing has fallen yet")

	await get_tree().create_timer(BossLevel.RAIN_TELEGRAPH).timeout
	_check(not _falling(level).is_empty(), "the announced drop arrives")

	# The reveal tween has to finish before the platforms are stood on.
	await get_tree().create_timer(BossLevel.PLATFORM_REVEAL_TIME + BEAT).timeout
	_check(_platforms_solid(level), "the phase 2 platforms are solid once they land")
	_check(is_equal_approx(level.phase_2_platforms.modulate.a, 1.0), "...and visible")


func _check_crossfire(level: BossLevel) -> void:
	print("\n[ phase 3: crossfire ]")

	_jump_to(level, BossLevel.PHASE_END_TIMES[BossLevel.Phase.RAIN])
	await get_tree().create_timer(BEAT).timeout

	_check(level.markers.get_child_count() >= 2, "a sweep announces both edges of its gap")

	await get_tree().create_timer(BossLevel.SWEEP_TELEGRAPH).timeout

	var heights: Array[float] = []
	for projectile: BossProjectile in _projectiles(level):
		if is_equal_approx(projectile.velocity.x, -BossLevel.SWEEP_SPEED):
			heights.append(projectile.position.y)
	heights.sort()

	if not _check(heights.size() > 5, "the wall arrived (%d orbs)" % heights.size()):
		return

	# Sweeps cycle their gap in order, so the first one is always the low gap —
	# which sits against the floor, and so leaves no hole *between* two orbs.
	# Checking the band is clear covers all three positions the same way.
	var gap_centre: float = BossLevel.SWEEP_GAP_CENTRES[0]
	var intruders: int = 0
	var breaks: int = 0
	for index: int in heights.size():
		if absf(heights[index] - gap_centre) < BossLevel.SWEEP_GAP_HALF_HEIGHT:
			intruders += 1
		if index > 0 and heights[index] - heights[index - 1] > BossLevel.SWEEP_ORB_SPACING * 1.5:
			breaks += 1

	_check(intruders == 0, "the gap at y=%.0f is clear" % gap_centre)
	_check(breaks == 0, "and it is the wall's only hole")


func _check_hits(game: MainGame, level: BossLevel) -> void:
	print("\n[ getting hit ]")

	# Both calls happen inside this frame, so no live orb can land between the
	# reading and the check.
	level.set("_invulnerable_time", 0.0)
	game.time_system.current_time = 40.0
	var before: float = game.time_system.current_time

	_check(level.report_hit(), "a hit lands")
	_check(is_equal_approx(game.time_system.current_time, before - BossLevel.HIT_COST),
		"...and costs %.0f seconds (%.1f -> %.1f)" % [BossLevel.HIT_COST, before, game.time_system.current_time])
	_check(not level.report_hit(), "the next orb is refused while invulnerable")
	_check(is_equal_approx(game.time_system.current_time, before - BossLevel.HIT_COST),
		"...and takes nothing")

	# The flash itself is the Player's, and it lands a frame later — the boss
	# only asks for it. Red channel up, green down: a tint, not a dimming.
	await get_tree().create_timer(0.05).timeout
	var tint: Color = game.player.modulate
	_check(tint.r > tint.g and tint.r > tint.b,
		"the player flashes red (%.2f, %.2f, %.2f)" % [tint.r, tint.g, tint.b])


## Running the clock out in the boss room has to end the run exactly the way it
## ends anywhere else. It cannot be left to MainGame's time_expired handler,
## because that signal never fires in a room with the clock stopped — so this is
## the check that the room notices its own death.
func _check_defeat(game: MainGame) -> void:
	print("\n[ running out of seconds ]")

	# A fresh run: the previous check ended the last one in a win.
	game.restart_run()
	await get_tree().process_frame
	game.enter_room(_boss_uid(), Room.Type.FINAL)

	var level: BossLevel = game.get("_current_room") as BossLevel
	if not _check(level != null, "a second visit loads a fresh fight"):
		return

	await get_tree().create_timer(0.3).timeout

	level.set("_invulnerable_time", 0.0)
	game.time_system.current_time = 2.0
	_check(level.report_hit(), "the last hit lands")
	_check(is_zero_approx(game.time_system.current_time), "the clock is empty")
	_check(_projectiles(level).is_empty(), "the field is cleared")

	# Long enough for the detonation animation and the handoff behind it.
	await get_tree().create_timer(2.0).timeout

	_check(game.get("_run_ended"), "the run is over")
	var screen: RunEndScreen = _run_end_screen(game)
	if _check(screen != null, "the run-end screen is up"):
		_check(screen.headline.text == "BOOM",
			"and it says the run was lost ('%s')" % screen.headline.text)
	_check(not game.player.can_move, "the player stays dead behind it")


func _check_survival(game: MainGame, level: BossLevel) -> void:
	print("\n[ surviving ]")

	var duration: float = BossLevel.PHASE_END_TIMES[BossLevel.PHASE_END_TIMES.size() - 1]
	_jump_to(level, duration)
	await get_tree().create_timer(BEAT).timeout

	_check(level.level_exit.visible, "the exit appears")
	_check(level.projectiles.get_child_count() == 0, "every live orb is cleared")
	_check(level.markers.get_child_count() == 0, "...and every pending telegraph with it")

	await get_tree().create_timer(BossLevel.EXIT_REVEAL_TIME + BEAT).timeout
	_check(level.level_exit.monitoring, "the exit is live once it has faded in")

	# The rest is BaseLevel's: walking into the exit ends the room.
	var exited: Array[bool] = [false]
	level.exited.connect(func() -> void: exited[0] = true)
	game.player.global_position = level.level_exit.global_position
	await get_tree().create_timer(0.3).timeout
	_check(exited[0], "reaching the exit ends the room")

	# FINAL is the last room of the map, so walking out of it is the run's win
	# rather than another trip to the map (MainGame.exit_room).
	_check(game.get("_run_ended"), "...and ends the run")
	var screen: RunEndScreen = _run_end_screen(game)
	if _check(screen != null, "the run-end screen is up"):
		_check(screen.headline.text == "YOU MADE IT",
			"and it says the run was won ('%s')" % screen.headline.text)


# --- Plumbing ----------------------------------------------------------------
## Drops the fight straight onto a phase boundary. The one thing this harness
## fakes; everything it triggers is the real path.
func _jump_to(level: BossLevel, time: float) -> void:
	level.set("_fight_time", time)


func _projectiles(level: BossLevel) -> Array[BossProjectile]:
	var live: Array[BossProjectile] = []
	for child: Node in level.projectiles.get_children():
		var projectile: BossProjectile = child as BossProjectile
		if projectile != null and not projectile.is_queued_for_deletion():
			live.append(projectile)

	return live


func _falling(level: BossLevel) -> Array[BossProjectile]:
	var falling: Array[BossProjectile] = []
	for projectile: BossProjectile in _projectiles(level):
		if projectile.velocity.y > 0.0:
			falling.append(projectile)

	return falling


## The run-end screen, if MainGame has put one up.
func _run_end_screen(game: MainGame) -> RunEndScreen:
	for child: Node in game.ui_root.get_children():
		if child is RunEndScreen:
			return child

	return null


func _platforms_solid(level: BossLevel) -> bool:
	for platform: JumpThroughPlatform in level.phase_2_platforms.get_children():
		if not platform.get_collision_layer_value(JumpThroughPlatform.COLLISION_LAYER):
			return false

	return true


func _check(condition: bool, label: String) -> bool:
	if condition:
		print("  ok   %s" % label)
	else:
		print("  FAIL %s" % label)
		_failures += 1

	return condition


func _finish() -> void:
	if _failures == 0:
		print("\nboss_check: all checks passed.")
	else:
		printerr("\nboss_check: %d check(s) failed." % _failures)

	get_tree().quit(0 if _failures == 0 else 1)


## The boss level, found the way the run finds it: by scanning
## LevelPool.FINAL_LEVEL_DIR. Nothing registers the final level in [UIDs] any
## more, so neither does this.
func _boss_uid() -> String:
	var finals: Array[String] = LevelPool.scan(LevelPool.FINAL_LEVEL_DIR)
	return finals[0] if not finals.is_empty() else ""
