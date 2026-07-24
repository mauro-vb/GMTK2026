class_name MainGame
extends Node
## Main entry point for the game
## Responsible for world setup and coordinating high level systems.

enum SceneContainer { WORLD, LEVEL, UI, TRANSITION, PAUSE }

# TODO: Map node data needs to carry a room type + its own level UID instead of
#       enter_room always being handed TEST_LEVEL_UID. Once Map exposes that,
#       this enum is what enter_room will switch on to route to the right
#       enter_* method below.
#enum RoomType { COMBAT, ELITE, BOSS, SHOP, EVENT, REST }


var player: Player = null
var map: Map = null

var _container_roots: Dictionary[SceneContainer, Node] = {}
var _loaded_scenes: Dictionary[SceneContainer, Node] = {}
var _current_room: RoomScene = null

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
	load_scene(UIDs.START_MENU_SCENE_UID, SceneContainer.UI)
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
		push_error("Failed to load scene '%s'" % scene_uid)
		return null

	var root: Node = _container_roots.get(container)
	if root == null:
		push_error("No root registered for container %s" % SceneContainer.keys()[container])
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
	change_scene(UIDs.MAP_HUD_SCENE_UID, SceneContainer.UI)
	map = load_scene(UIDs.MAP_SCENE_UID) as Map
	if map == null:
		push_error("MAP_SCENE_UID did not resolve to a Map instance")
		return

	# TODO: node_selected currently ignores the clicked node's data and always
	#       goes to enter_room(TEST_LEVEL_UID) as RoomType.COMBAT. Once Map
	#       nodes carry their own {type, level_uid}, this becomes:
	#       map.node_selected.connect(func(node_data):
	#           enter_room(node_data.level_uid, node_data.room_type)
	#       )
	map.selected.connect(func(room): enter_room(room.scene_uid, Room.Type.LEVEL))


## Leaves the map and hands off to the correct room handler based on type.
## Common map <-> room bookkeeping (hiding the map, restoring it, HUD swap)
## lives here; the type-specific handlers below only deal with what's
## unique to that room type.
func enter_room(room_uid: String, room_type: Room.Type) -> void:
	# TODO: play a transition (fade/wipe/loading screen) via SceneContainer.TRANSITION
	#       before removing the map, so the swap isn't an instant pop.
	#       e.g.:
	#       await _play_transition_out()
	world.remove_child(map)

	match room_type:
		Room.Type.LEVEL:#, RoomType.ELITE, RoomType.BOSS:
			enter_level(room_uid)
		Room.Type.SHOP:
			enter_shop(room_uid)
		Room.Type.EVENT:
			enter_event(room_uid)
		Room.Type.HEAL:
			enter_rest(room_uid)
		_:
			push_error("Unhandled RoomType %s" % Room.Type.keys()[room_type])
			
	if _current_room == null:
		push_error("Failed to load room '%s' as RoomType %s" % [room_uid, Room.Type.keys()[room_type]])
		return
	_current_room.exited.connect(exit_room, CONNECT_DEFERRED | CONNECT_ONE_SHOT)

	# TODO: await _play_transition_in() here once transitions exist, so every
	#       room type gets the fade-in for free without repeating it in each
	#       enter_* method.


## Level rooms: loads a BaseLevel scene, spawns the player.
func enter_level(level_uid: String) -> void:
	change_scene(UIDs.LEVEL_HUD_SCENE_UID, SceneContainer.UI)


	_current_room = load_scene(level_uid, SceneContainer.LEVEL) as BaseLevel
	if _current_room == null:
		push_error("'%s' did not resolve to a BaseLevel instance" % level_uid)
		return

	player_root.add_child(player)
	

	# TODO: this is where EntityRoot gets populated — currently levels presumably
	#       spawn their own enemies via spawners inside the level scene itself.
	#       If that stays true, nothing extra is needed here. If MainGame ever
	#       needs to drive spawning explicitly (e.g. difficulty scaling based on
	#       run progress), it happens after _current_level is confirmed non-null.


## Shop rooms: no EntityRoot population, no combat — just a UI-driven scene
## the player browses. Doesn't need a BaseLevel or player spawn positioning
## the way a combat room does.
func enter_shop(_shop_uid: String) -> void:
	# TODO: load a lightweight shop scene/UI instead of a full BaseLevel.
	#       Shops probably don't need EntityRoot/VisualEffectsRoot touched at
	#       all, and the player likely doesn't need to be repositioned in
	#       world-space, since a shop may just be a UI overlay rather than
	#       something in SceneContainer.LEVEL. Decide whether player needs
	#       add_child(player_root) here at all, or if shops are UI-only.
	push_error("enter_shop not yet implemented")


## Event rooms: narrative/choice scenes, likely UI-driven with no combat.
func enter_event(_event_uid: String) -> void:
	# TODO: similar to enter_shop — probably a UI/dialogue scene rather than
	#       a BaseLevel. Consider whether events ever need the player visible
	#       in world-space or if they're presented purely as UI.
	push_error("enter_event not yet implemented")


## Rest rooms: heal/upgrade choice, no combat.
func enter_rest(_rest_uid: String) -> void:
	# TODO: likely UI-only like shop/event. May still want the player parented
	#       and visible standing in a rest-site background scene depending on
	#       art direction — decide once the rest room's visual design exists.
	push_error("enter_rest not yet implemented")


func exit_room() -> void:
	# TODO: transition out before unloading, mirroring enter_room's transition,
	#       so leaving a room doesn't just snap back to the map instantly either.
	#       e.g.:
	#       await _play_transition_out()
	unload_scene(SceneContainer.LEVEL)
	change_scene(UIDs.MAP_HUD_SCENE_UID, SceneContainer.UI)
	_current_room = null
	player_root.remove_child(player)
	world.add_child(map)
	map.unlock_next_nodes()
	# TODO: await _play_transition_in() here once transitions exist.


## Instantiates the player. Not added to the tree here — it's parented under
## player_root only while a level is active (see enter_level / exit_room).
func _init_player() -> void:
	var player_scene: PackedScene = ResourceLoader.load(UIDs.PLAYER_SCENE_UID)
	if player_scene == null:
		push_error("Could not load player scene: " + UIDs.PLAYER_SCENE_UID)
		return

	player = player_scene.instantiate() as Player
	if player == null:
		push_error("Loaded player scene does not extend Player or DNE: " + UIDs.PLAYER_SCENE_UID)
		return
