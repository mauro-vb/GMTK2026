class_name MainGame
extends Node
## Main entry point for the game.
## Owns the high-level game flow as a small state machine (GamePhase), the
## scene containers, the pause stack and screen transitions. UI screens emit
## intent signals; every actual state change happens here, in one place.

enum SceneContainer { WORLD, LEVEL, UI, TRANSITION, PAUSE }

## Where the player currently is in the game flow. Guards what input means:
## pausing is only valid inside a run (MAP / LEVEL).
enum GamePhase { MENU, MAP, LEVEL, RUN_END }

const START_MENU_SCENE_UID: String = "uid://decj2y8v3qpdf"
const MAP_HUD_SCENE_UID: String = "uid://ogipvp6hivr7"
const LEVEL_HUD_SCENE_UID: String = "uid://4o0nmaeak4ns"
const MAP_SCENE_UID: String = "uid://ipmc68r6n333"
const PLAYER_SCENE_UID: String = "uid://kwjq37d8yab5"
const TEST_LEVEL_UID: String = "uid://bm4yugu5nagbx"
const SHOP_LEVEL_SCENE: String = "res://src/levels/shop/ShopLevel.tscn"
const PAUSE_MENU_SCENE: String = "res://src/ui/pause_menu/PauseMenu.tscn"
const RUN_END_SCENE: String = "res://src/ui/run_end/RunEndScreen.tscn"

var player: Player = null
var map: Map = null
var phase: GamePhase = GamePhase.MENU

var _container_roots: Dictionary[SceneContainer, Node] = {}
var _loaded_scenes: Dictionary[SceneContainer, Node] = {}
var _current_level: BaseLevel = null
var _current_node_type: MapNodeData.Type = MapNodeData.Type.NOT_ASSIGNED
var _pause_menu: PauseMenu = null
var _rooms_cleared: int = 0
## True while a fade/scene swap is in flight; blocks re-entrant flow changes
## (double-clicking a map node, pausing mid-transition, etc.).
var _busy: bool = false

# Game World root nodes
@onready var world: Node2D = %World
@onready var player_root: Node2D = %PlayerRoot
@onready var level_root: Node2D = %LevelRoot
@onready var entity_root: Node2D = %EntityRoot
@onready var visual_effects_root: Node2D = %VisualEffectsRoot

# UI root nodes
@onready var ui_root: Control = %UIRoot
@onready var transition_root: Control = %TransitionRoot
@onready var debug_root: Control = %DebugRoot
@onready var pause_root: Control = %PauseRoot
@onready var transition: ScreenTransition = %ScreenTransition


func _ready() -> void:
	Global.main_game = self
	_container_roots = {
		SceneContainer.WORLD: world,
		SceneContainer.LEVEL: level_root,
		SceneContainer.UI: ui_root,
		SceneContainer.TRANSITION: transition_root,
		SceneContainer.PAUSE: pause_root,
	}
	RunState.time_expired.connect(_on_time_expired)
	load_scene(START_MENU_SCENE_UID, SceneContainer.UI)
	_init_player()


func _input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return
	if event.is_action_pressed(&"debug_quit"):
		quit_game()


func _unhandled_input(event: InputEvent) -> void:
	# The pause menu consumes ui_cancel (ESC) itself while open, so reaching
	# here with the pause action means either "open the menu" or a controller
	# start-press while paused, which also means "close it".
	if event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		toggle_pause()


func quit_game() -> void:
	get_tree().root.propagate_notification(NOTIFICATION_WM_CLOSE_REQUEST)
	get_tree().quit()


# --- Pause -------------------------------------------------------------------


func toggle_pause() -> void:
	if _pause_menu != null:
		resume_game()
	else:
		pause_game()


func pause_game() -> void:
	if _busy or _pause_menu != null:
		return
	if phase != GamePhase.MAP and phase != GamePhase.LEVEL:
		return
	get_tree().paused = true
	_pause_menu = load_scene(PAUSE_MENU_SCENE, SceneContainer.PAUSE) as PauseMenu
	if _pause_menu == null:
		get_tree().paused = false
		return
	_pause_menu.resume_requested.connect(resume_game)
	_pause_menu.abandon_requested.connect(_abandon_run)


func resume_game() -> void:
	if _pause_menu == null:
		return
	var menu: PauseMenu = _pause_menu
	_pause_menu = null
	await menu.dismiss()
	_clear_container(SceneContainer.PAUSE)
	get_tree().paused = false


## Pause-menu "abandon": tear the run down and return to the start menu.
func _abandon_run() -> void:
	if _busy:
		return
	_busy = true
	_pause_menu = null
	await transition.fade_out()
	_clear_container(SceneContainer.PAUSE)
	get_tree().paused = false
	_end_run_cleanup()
	phase = GamePhase.MENU
	change_scene(START_MENU_SCENE_UID, SceneContainer.UI)
	await transition.fade_in()
	_busy = false


# --- Scene containers --------------------------------------------------------


## Loads a scene into the given container, tracking it as that container's active instance.
func load_scene(scene_uid: String, container: SceneContainer = SceneContainer.WORLD) -> Node:
	var packed_scene: PackedScene = ResourceLoader.load(scene_uid)
	if packed_scene == null:
		push_error("MainGame: failed to load scene '%s'" % scene_uid)
		return null

	var root: Node = _container_roots.get(container)
	if root == null:
		push_error("MainGame: no root registered for container %s" % SceneContainer.keys()[container])
		return null

	var instance: Node = packed_scene.instantiate()
	root.add_child(instance)
	_loaded_scenes[container] = instance
	return instance


## Frees the container's currently tracked scene instance, if any.
func unload_scene(container: SceneContainer) -> void:
	var current: Node = _loaded_scenes.get(container)
	if current == null:
		return
	current.queue_free()
	_loaded_scenes.erase(container)


func change_scene(new_scene_uid: String, container: SceneContainer = SceneContainer.WORLD) -> Node:
	unload_scene(container)
	return load_scene(new_scene_uid, container)


## Frees everything under a container root, tracked or not (e.g. a settings
## submenu spawned as a sibling of the pause menu).
func _clear_container(container: SceneContainer) -> void:
	var root: Node = _container_roots.get(container)
	if root == null:
		return
	for child: Node in root.get_children():
		child.queue_free()
	_loaded_scenes.erase(container)


# --- Run flow ----------------------------------------------------------------


func load_game() -> void:
	if _busy:
		return
	_busy = true
	await transition.fade_out()
	RunState.start_run()
	_rooms_cleared = 0
	change_scene(MAP_HUD_SCENE_UID, SceneContainer.UI)
	if map != null:
		unload_scene(SceneContainer.WORLD)
	map = load_scene(MAP_SCENE_UID) as Map
	if map == null:
		push_error("MainGame: MAP_SCENE_UID did not resolve to a Map instance")
		_busy = false
		return
	map.node_selected.connect(_on_map_node_selected)
	phase = GamePhase.MAP
	await transition.fade_in()
	_busy = false


func _on_map_node_selected(node: MapNodeData) -> void:
	if _current_level != null:
		return
	_current_node_type = node.type
	match node.type:
		MapNodeData.Type.SHOP:
			enter_room(SHOP_LEVEL_SCENE)
		_:
			# TODO: HEAL and FINAL still need their own scenes.
			enter_room(TEST_LEVEL_UID)


func enter_room(level_uid: String) -> void:
	if _busy:
		return
	_busy = true
	await transition.fade_out()
	change_scene(LEVEL_HUD_SCENE_UID, SceneContainer.UI)
	world.remove_child(map)

	# TODO: different level types will likely need different loading behavior
	#       (e.g. combat spawns enemies via EntityRoot, shop/rest rooms may not
	#       need EntityRoot at all, boss rooms may need a special camera setup).
	#       Consider a per-type loader (e.g. a `level_type` enum -> handler dict,
	#       similar to _container_roots) instead of always going through the
	#       same load_scene call.
	_current_level = load_scene(level_uid, SceneContainer.LEVEL) as BaseLevel
	if _current_level == null:
		push_error("MainGame: '%s' did not resolve to a BaseLevel instance" % level_uid)
		_busy = false
		return

	_place_player_at_level_spawn()
	set_player_active(true)
	phase = GamePhase.LEVEL
	RunState.set_ticking(_current_level.should_tick_time())
	await transition.fade_in()
	_busy = false


func exit_room() -> void:
	if _busy:
		return
	_busy = true
	RunState.set_ticking(false)
	_rooms_cleared += 1
	await transition.fade_out()
	set_player_active(false)
	unload_scene(SceneContainer.LEVEL)
	_current_level = null

	# Clearing the FINAL room is the win condition — no map to return to.
	if _current_node_type == MapNodeData.Type.FINAL:
		await _show_run_end(true)
		return

	change_scene(MAP_HUD_SCENE_UID, SceneContainer.UI)
	phase = GamePhase.MAP
	world.add_child(map)
	map.unlock_next_nodes()
	await transition.fade_in()
	_busy = false


func _on_time_expired() -> void:
	if phase != GamePhase.LEVEL and phase != GamePhase.MAP:
		return
	# The countdown can only hit zero mid-room; freeze the player where they
	# stand so the defeat doesn't keep simulating underneath the fade.
	set_player_frozen(true)
	while _busy:
		# A room transition is mid-flight; let it finish before taking over.
		await get_tree().process_frame
	_busy = true
	await transition.fade_out()
	await _show_run_end(false)


## Common endpoint for victory and defeat. Assumes the screen is already
## faded to black and _busy is held by the caller.
func _show_run_end(victory: bool) -> void:
	phase = GamePhase.RUN_END
	var stats: Dictionary = {
		"rooms": _rooms_cleared,
		"coins": RunState.coins,
		"relics": RunState.relics.size(),
		"time_left": RunState.time_remaining,
	}
	_end_run_cleanup()

	var packed: PackedScene = ResourceLoader.load(RUN_END_SCENE)
	unload_scene(SceneContainer.UI)
	var screen: RunEndScreen = packed.instantiate() as RunEndScreen
	screen.setup(victory, stats)
	screen.retry_requested.connect(_on_run_end_retry)
	screen.menu_requested.connect(_on_run_end_menu)
	ui_root.add_child(screen)
	_loaded_scenes[SceneContainer.UI] = screen

	await transition.fade_in()
	_busy = false


func _on_run_end_retry() -> void:
	load_game()


func _on_run_end_menu() -> void:
	if _busy:
		return
	_busy = true
	await transition.fade_out()
	phase = GamePhase.MENU
	change_scene(START_MENU_SCENE_UID, SceneContainer.UI)
	await transition.fade_in()
	_busy = false


## Tears down everything belonging to the current run. The map may be detached
## from the tree (levels swap it out), so unload_scene still reaching it via
## the container tracking is what makes this safe in both phases.
func _end_run_cleanup() -> void:
	RunState.set_ticking(false)
	set_player_active(false)
	unload_scene(SceneContainer.LEVEL)
	_current_level = null
	_current_node_type = MapNodeData.Type.NOT_ASSIGNED
	if map != null:
		unload_scene(SceneContainer.WORLD)
		map = null


# --- Player ------------------------------------------------------------------


## Instantiates the player and adds it to the player layer.
func _init_player() -> void:
	var player_scene: PackedScene = ResourceLoader.load(PLAYER_SCENE_UID)
	if player_scene == null:
		push_error("Could not load player scene: " + PLAYER_SCENE_UID)
		return

	player = player_scene.instantiate() as Player
	if player == null:
		push_error("Loaded player scene does not extend Player or DNE: " + PLAYER_SCENE_UID)
		return

	player_root.add_child(player)
	set_player_active(false)


## Shows and simulates the player only while a level is active. Outside levels
## (start menu, map) the player would otherwise fall through empty space and
## stay visible behind the UI.
func set_player_active(active: bool) -> void:
	if player == null:
		return
	set_player_frozen(not active)
	player.visible = active


## Halts player physics/input while keeping them visible — used for modal
## moments inside a level (e.g. the shop's purchase card).
func set_player_frozen(frozen: bool) -> void:
	if player == null:
		return
	player.velocity = Vector2.ZERO
	player.process_mode = Node.PROCESS_MODE_DISABLED if frozen else Node.PROCESS_MODE_INHERIT


## Finds the default spawn location in the currently loaded level and places the Player there.
func _place_player_at_level_spawn() -> void:
	if player == null:
		push_error("Cannot place player in level because player is null")
		return
	if _current_level == null:
		push_error("Cannot place player into level because level is null")
		return

	player.global_position = _current_level.get_default_player_spawn()
