class_name MainGame
extends Node
## Main entry point for the game
## Responsible for world setup and coordinating high level systems.

enum SceneContainer { WORLD, LEVEL, UI, TRANSITION, PAUSE }

const START_MENU_SCENE_UID: String = "uid://decj2y8v3qpdf"
const MAP_HUD_SCENE_UID: String = "uid://ogipvp6hivr7"
const LEVEL_HUD_SCENE_UID: String = "uid://4o0nmaeak4ns"
const MAP_SCENE_UID: String = "uid://ipmc68r6n333"
const PLAYER_SCENE_UID: String = "uid://kwjq37d8yab5"
const TEST_LEVEL_UID: String = "uid://bm4yugu5nagbx"

var player: Player = null
var map: Map = null

var _container_roots: Dictionary[SceneContainer, Node] = {}
var _loaded_scenes: Dictionary[SceneContainer, Node] = {}
var _current_level: BaseLevel = null

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


func _ready() -> void:
	Global.main_game = self
	_container_roots = {
		SceneContainer.WORLD: world,
		SceneContainer.LEVEL: level_root,
		SceneContainer.UI: ui_root,
		SceneContainer.TRANSITION: transition_root,
		SceneContainer.PAUSE: pause_root,
	}
	load_scene(START_MENU_SCENE_UID, SceneContainer.UI)
	_init_player()


func _input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return
	if event.is_action_pressed(&"debug_quit"):
		quit_game()


func quit_game() -> void:
	get_tree().root.propagate_notification(NOTIFICATION_WM_CLOSE_REQUEST)
	get_tree().quit()


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


func load_game() -> void:
	change_scene(MAP_HUD_SCENE_UID, SceneContainer.UI)
	map = load_scene(MAP_SCENE_UID) as Map
	if map == null:
		push_error("MainGame: MAP_SCENE_UID did not resolve to a Map instance")
		return
	map.node_selected.connect(func(_l): enter_room(TEST_LEVEL_UID))
	# TODO: node_selected currently ignores `l` and always loads TEST_LEVEL_UID.
	#       Map nodes should carry their own level type/UID (combat, event, shop,
	#       rest, elite, boss...) so enter_room can load the right scene per node
	#       instead of hardcoding one test level.


func enter_room(level_uid: String) -> void:
	# TODO: play a transition (fade/wipe/loading screen) via SceneContainer.TRANSITION
	#       before removing the map and loading the level, so the swap isn't an
	#       instant pop. Something like:
	#       await play_transition_out()
	#       ...load level...
	#       await play_transition_in()
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
		return

	_place_player_at_level_spawn()


func exit_room() -> void:
	# TODO: transition out before unloading, mirroring enter_room, so leaving
	#       a room doesn't just snap back to the map instantly either.
	unload_scene(SceneContainer.LEVEL)
	change_scene(MAP_HUD_SCENE_UID, SceneContainer.UI)
	_current_level = null
	world.add_child(map)
	map.unlock_next_nodes()


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


## Finds the default spawn location in the currently loaded level and places the Player there.
func _place_player_at_level_spawn() -> void:
	if player == null:
		push_error("Cannot place player in level because player is null")
		return
	if _current_level == null:
		push_error("Cannot place player into level because level is null")
		return

	player.global_position = _current_level.get_default_player_spawn()
