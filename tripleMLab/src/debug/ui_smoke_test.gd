extends Node
## Headless smoke test for the UI architecture: game phases, pause stack,
## settings, transitions, map camera and the run-end flow.
## Run: godot --headless res://src/debug/UiSmokeTest.tscn
## Exits with code 0 when all checks pass, otherwise the number of failures.

const MAIN_GAME_SCENE_UID: String = "uid://ccxuyq6o8k8ca"

var _failures: int = 0
var main: MainGame


func _ready() -> void:
	await _run()
	print("UI SMOKE TEST: %s" % ("ALL PASS" if _failures == 0 else "%d FAILURES" % _failures))
	get_tree().quit(_failures)


func _check(condition: bool, what: String) -> void:
	if condition:
		print("  PASS: %s" % what)
	else:
		_failures += 1
		print("  FAIL: %s" % what)


## Waits (frame by frame) until the predicate holds, up to max_frames.
func _await_until(predicate: Callable, max_frames: int = 300) -> bool:
	for i: int in max_frames:
		if predicate.call():
			return true
		await get_tree().process_frame
	return predicate.call()


func _run() -> void:
	main = (load(MAIN_GAME_SCENE_UID) as PackedScene).instantiate()
	add_child(main)
	await get_tree().process_frame

	# --- Boot: start menu phase ---
	_check(main.phase == MainGame.GamePhase.MENU, "boots into MENU phase")
	_check(main.ui_root.get_child_count() == 1 and main.ui_root.get_child(0) is StartMenu,
			"start menu loaded into UI container")
	_check(main.transition != null, "screen transition is wired")
	main.pause_game()
	_check(not get_tree().paused, "pausing is rejected on the start menu")

	# --- Settings autoload ---
	_check(AudioServer.get_bus_index(&"Music") >= 0, "Music audio bus exists")
	_check(AudioServer.get_bus_index(&"SFX") >= 0, "SFX audio bus exists")
	Settings.master_volume = 0.5
	_check(is_equal_approx(AudioServer.get_bus_volume_db(0), linear_to_db(0.5)),
			"volume setting applies to the audio bus")
	Settings.master_volume = 0.8

	# --- Start a run ---
	main.load_game()
	var reached_map: bool = await _await_until(func() -> bool:
		return main.phase == MainGame.GamePhase.MAP and not main._busy)
	_check(reached_map, "Play reaches MAP phase through the fade")
	_check(main.map != null and main.map.is_inside_tree(), "map is loaded and in the tree")

	# --- Map camera ---
	var map: Map = main.map
	_check(map._min_camera_y <= map._max_camera_y, "camera bounds are sane")
	_check(map._target_y >= map._min_camera_y and map._target_y <= map._max_camera_y,
			"initial camera target is inside bounds")
	map.focus_row(MapGenerator.HEIGHT - 1)
	_check(is_equal_approx(map._target_y, map._min_camera_y),
			"focusing the top row clamps to the top bound")
	map.focus_row(0)
	var converged: bool = await _await_until(func() -> bool:
		return absf(map.camera.position.y - map._target_y) < 1.0, 120)
	_check(converged, "camera glides to its target")

	# --- Pause on the map ---
	main.pause_game()
	_check(get_tree().paused, "pause engages on the map")
	_check(main._pause_menu != null, "pause menu is up")

	# --- Settings as a pause submenu ---
	var pause_menu: PauseMenu = main._pause_menu
	pause_menu.open_submenu(pause_menu.SETTINGS_SCENE)
	await get_tree().process_frame
	var settings_open: bool = false
	for child: Node in main.pause_root.get_children():
		if child is SettingsMenu:
			settings_open = true
	_check(settings_open and not pause_menu.visible, "settings opens over a hidden pause menu")
	pause_menu._submenu.back_requested.emit()
	var back_to_pause: bool = await _await_until(func() -> bool:
		return pause_menu.visible and pause_menu._submenu == null, 60)
	_check(back_to_pause, "backing out of settings restores the pause menu")

	# --- Resume ---
	main.resume_game()
	var resumed: bool = await _await_until(func() -> bool:
		return not get_tree().paused and main.pause_root.get_child_count() == 0, 60)
	_check(resumed, "resume unpauses and clears the pause layer")

	# --- Enter a room from the map ---
	var picked: MapNode = null
	for map_node: MapNode in map.nodes.get_children():
		if map_node.available:
			picked = map_node
			break
	_check(picked != null, "row 0 has an available node")
	picked._select()
	var in_level: bool = await _await_until(func() -> bool:
		return main.phase == MainGame.GamePhase.LEVEL and not main._busy)
	_check(in_level, "selecting a node enters the level")
	_check(main.player.visible, "player is active in the level")
	_check(RunState.ticking, "countdown ticks in the level")
	_check(not map.is_inside_tree(), "map is parked while a level runs")

	# --- Pause inside the level ---
	main.pause_game()
	_check(get_tree().paused, "pause engages inside a level")
	var time_at_pause: float = RunState.time_remaining
	for i: int in 10:
		await get_tree().process_frame
	_check(is_equal_approx(RunState.time_remaining, time_at_pause),
			"countdown freezes while paused")
	main.resume_game()
	await _await_until(func() -> bool: return not get_tree().paused, 60)

	# --- Time running out ends the run ---
	RunState._set_time(0.0)
	var run_ended: bool = await _await_until(func() -> bool:
		return main.phase == MainGame.GamePhase.RUN_END and not main._busy)
	_check(run_ended, "time expiring reaches RUN_END phase")
	var end_screen: RunEndScreen = main.ui_root.get_child(0) as RunEndScreen
	_check(end_screen != null, "run end screen is showing")
	_check(not main.player.visible, "player is hidden on the run end screen")
	_check(main.map == null, "map was torn down with the run")

	# --- Retry starts a fresh run ---
	end_screen.retry_requested.emit()
	var retried: bool = await _await_until(func() -> bool:
		return main.phase == MainGame.GamePhase.MAP and not main._busy)
	_check(retried, "retry starts a new run")
	_check(is_equal_approx(RunState.time_remaining, RunState.STARTING_TIME_SECONDS),
			"new run resets the countdown")

	# --- Abandon from the pause menu ---
	main.pause_game()
	main._pause_menu.abandon_requested.emit()
	var abandoned: bool = await _await_until(func() -> bool:
		return main.phase == MainGame.GamePhase.MENU and not main._busy)
	_check(abandoned, "abandon run returns to the start menu")
	_check(not get_tree().paused, "abandon leaves the tree unpaused")
	_check(main.ui_root.get_child(0) is StartMenu, "start menu is back")
