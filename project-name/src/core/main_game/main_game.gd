class_name MainGame
extends Node
## Main entry point for the game
## Responsible for world setup and coordianting high level systems.

const PLAYER_SCENE_UID: String = "uid://kwjq37d8yab5"
const TEST_LEVEL_UID: String = "uid://bm4yugu5nagbx"

var player : Player = null
var _current_level : BaseLevel = null


#var _current_level : BaseLevel = null

# Game World root nodes
@onready var level_root: Node2D = %LevelRoot
@onready var entity_root: Node2D = %EntityRoot
@onready var effects_root: Node2D = %VisualEffectsRoot

# UI root nodes
@onready var hud_root: Control = %HudRoot
@onready var transition_root: Control = %TransitionRoot
@onready var debug_root: Control = %DebugRoot
@onready var pause_root: Control = %PauseRoot


func _ready() -> void:
	print_tree_pretty()
	_init_player()
	load_level(TEST_LEVEL_UID)

func _input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return

	if event.is_action_pressed(&"debug_quit"):
		quit_game()
		
func quit_game() -> void:
	get_tree().root.propagate_notification(NOTIFICATION_WM_CLOSE_REQUEST)
	get_tree().quit()
	
## Instantiates the player and adds it to the entity layer
func _init_player() -> void:
	var player_scene : PackedScene = ResourceLoader.load(PLAYER_SCENE_UID) as PackedScene
	if player_scene == null:
		push_error("Could not load player scene: " + PLAYER_SCENE_UID)
		return

	player = player_scene.instantiate() as Player
	if player == null:
		push_error("Loaded player scene does not extend player or DNE: " + PLAYER_SCENE_UID)
		return

	entity_root.add_child(player)


func load_level(level_scene : String) -> void:
	# Make sure this is called during idle time
	_deferred_load_level.call_deferred(level_scene)

func _deferred_load_level(level_scene_uid : String) -> void:
	if _current_level != null:
		_current_level.queue_free()
		_current_level = null

	# Allow the old level to finish freeing before adding the new one
	await get_tree().process_frame

	var new_level_packed : PackedScene = ResourceLoader.load(level_scene_uid, "PackedScene") as PackedScene
	if new_level_packed == null:
		push_error("Could not load level as a packed scene: " + level_scene_uid)
		return

	_current_level = new_level_packed.instantiate() as BaseLevel
	if _current_level == null:
		push_error("Loaded level is not of type Level or does not exist")
		return
		# FUTURE (main menu): Should have a fall back scene

	level_root.add_child(_current_level)

	# Allow level to fully process before accessing it
	await get_tree().process_frame
	_place_player_at_level_spawn()
	#_setup_level_camera()
	
## Finds the default spawn location in currently loaded level, and places
##  the Player at that position.
func _place_player_at_level_spawn() -> void:
	if player == null:
		push_error("Cannot place player in level because it is null")
		return
	if _current_level == null:
		push_error("Cannot place player into level because level is null")
		return

	player.global_position = _current_level.get_default_player_spawn()
