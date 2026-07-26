class_name MainGame
extends Node
## Main entry point for the game
## Responsible for world setup and coordinating high level systems.

enum SceneContainer { WORLD, LEVEL, UI, TRANSITION, PAUSE }

var time_system: TimeSystem = null
var modifiers_system: ModifiersSystem = null
var player: Player = null
var map: Map = null

## Rooms actually finished this run. Counted on the way out of a room, so dying
## in one doesn't credit it. Reported on the run-end screen.
var rooms_cleared: int = 0

var _container_roots: Dictionary[SceneContainer, Node] = {}
var _loaded_scenes: Dictionary[SceneContainer, Node] = {}
var _current_room: RoomScene = null

## Set on the way into the last room of the map. Leaving that room ends the run
## in a win instead of dropping back to a map with nothing left on it.
var _in_final_room: bool = false
## Guards the run-end handoff. The clock can expire on the same frame the player
## reaches an exit, and either path alone is a perfectly good ending — both at
## once is two end screens stacked on each other.
var _run_ended: bool = false

# System root node
@onready var systems: Node = %Systems

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
	rooms_cleared = 0
	_in_final_room = false
	_run_ended = false

	_load_systems()
	_init_player()
	time_system.time_expired.connect(_on_time_expired)

	change_scene(UIDs.MAP_HUD_SCENE_UID, SceneContainer.UI)
	map = load_scene(UIDs.MAP_SCENE_UID) as Map
	if map == null:
		push_error("MAP_SCENE_UID did not resolve to a Map instance")
		return

	# Rooms carry their own type and scene (dealt in MapGenerator._apply_scene_uids),
	# so a click is just "load what that node says it is".
	map.selected.connect(func(room): enter_room(room.scene_uid, room.type))


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
	_in_final_room = room_type == Room.Type.FINAL

	match room_type:
		# The final room is an ordinary level to load and play; all that is
		# different about it is that leaving it ends the run (see exit_room).
		Room.Type.LEVEL, Room.Type.FINAL:
			enter_level(room_uid)
		Room.Type.WORKSHOP:
			enter_workshop(room_uid)
		Room.Type.EVENT:
			enter_event(room_uid)
		Room.Type.TREASURE:
			enter_treasure(room_uid)
		_:
			push_error("Unhandled RoomType %s" % Room.Type.keys()[room_type])
			
	if _current_room == null:
		push_error("Failed to load room '%s' as RoomType %s" % [room_uid, Room.Type.keys()[room_type]])
		return
	time_system.ticking = _current_room.should_tick_time
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
	# Before the modifiers run, so anything they apply to the player isn't wiped
	player.reset_for_new_room()
	modifiers_system.activate_modifiers(Modifier.Type.ENTER_LEVEL)
	

	# TODO: this is where EntityRoot gets populated — currently levels presumably
	#       spawn their own enemies via spawners inside the level scene itself.
	#       If that stays true, nothing extra is needed here. If MainGame ever
	#       needs to drive spawning explicitly (e.g. difficulty scaling based on
	#       run progress), it happens after _current_level is confirmed non-null.


## Workshop rooms: no EntityRoot population, no combat, no player in world-space
## — the whole room is the bench of modifiers on offer. It still loads into
## SceneContainer.LEVEL so exit_room() tears it down like any other room; the
## Workshop puts its own UI on a CanvasLayer, so it needs no camera of its own.
##
## The HUD comes down for the duration: a workshop is a full-screen takeover and
## the map HUD anchors its clock and its modifier row into the same corners the
## bench uses. The Workshop carries its own copy of both instead, and exit_room()
## puts the map HUD back on the way out.
func enter_workshop(workshop_uid: String) -> void:
	unload_scene(SceneContainer.UI)

	_current_room = load_scene(workshop_uid, SceneContainer.LEVEL) as Workshop
	if _current_room == null:
		push_error("'%s' did not resolve to a Workshop instance" % workshop_uid)


## Event rooms: narrative/choice scenes, likely UI-driven with no combat.
func enter_event(_event_uid: String) -> void:
	# TODO: similar to enter_workshop — probably a UI/dialogue scene rather than
	#       a BaseLevel. Consider whether events ever need the player visible
	#       in world-space or if they're presented purely as UI.
	push_error("enter_event not yet implemented")


## Treasure rooms: a chest, and one gamble with the clock. Handled exactly like a
## workshop — no EntityRoot population, no player in world-space, loaded into
## SceneContainer.LEVEL so exit_room() tears it down like any other room, and the
## map HUD comes down because the room carries its own clock and modifier strip.
func enter_treasure(treasure_uid: String) -> void:
	unload_scene(SceneContainer.UI)

	_current_room = load_scene(treasure_uid, SceneContainer.LEVEL) as TreasureRoom
	if _current_room == null:
		push_error("'%s' did not resolve to a TreasureRoom instance" % treasure_uid)


func exit_room() -> void:
	# TODO: transition out before unloading, mirroring enter_room's transition,
	#       so leaving a room doesn't just snap back to the map instantly either.
	#       e.g.:
	#       await _play_transition_out()
	if _run_ended:
		return

	time_system.ticking = false
	if _current_room is BaseLevel:
		modifiers_system.activate_modifiers(Modifier.Type.EXIT_LEVEL)
		player_root.remove_child(player)
	unload_scene(SceneContainer.LEVEL)
	_current_room = null
	rooms_cleared += 1

	# Nothing to go back to: the last room of the map was the whole point of the
	# run, so walking out of it is the win rather than another trip to the map.
	if _in_final_room:
		end_run(true)
		return

	change_scene(UIDs.MAP_HUD_SCENE_UID, SceneContainer.UI)
	world.add_child(map)
	map.unlock_next_nodes()
	# TODO: await _play_transition_in() here once transitions exist.


## Ends the run either way and hands over to the run-end screen.
##
## Everything from the run is left standing behind the screen — the level the
## player died in, the debris, the map. It is only cleared once they choose what
## to do next, so the last thing they see is the thing that killed them rather
## than an empty stage.
##
## Callers are responsible for having claimed the ending first (see
## [member _run_ended]); this does the work and does not second-guess it.
func end_run(victory: bool) -> void:
	_run_ended = true
	time_system.ticking = false

	var screen: RunEndScreen = change_scene(UIDs.RUN_END_SCENE_UID, SceneContainer.UI) as RunEndScreen
	if screen == null:
		push_error("RUN_END_SCENE_UID did not resolve to a RunEndScreen instance")
		return

	screen.setup(victory, rooms_cleared)
	screen.retry_pressed.connect(restart_run, CONNECT_ONE_SHOT)
	screen.menu_pressed.connect(return_to_menu, CONNECT_ONE_SHOT)


## Tears the finished run down and deals a fresh one, straight back into a level
## rather than back out to the title.
func restart_run() -> void:
	_teardown_run()
	load_game()


func return_to_menu() -> void:
	_teardown_run()
	change_scene(UIDs.START_MENU_SCENE_UID, SceneContainer.UI)


## Frees everything a run owns, so the next one starts from nothing.
##
## The player and the map are re-parented rather than kept in one place — the
## player only lives under PlayerRoot while a level is up, and the map is lifted
## out of the world for the duration of a room. Either can therefore be sitting
## outside the tree when a run ends, which is why each is detached from whatever
## parent it happens to have instead of from the one it usually has.
func _teardown_run() -> void:
	unload_scene(SceneContainer.LEVEL)
	unload_scene(SceneContainer.UI)
	_current_room = null

	for orphan: Node in [player, map]:
		if orphan == null:
			continue
		if orphan.get_parent() != null:
			orphan.get_parent().remove_child(orphan)
		orphan.queue_free()

	player = null
	map = null

	# Systems are rebuilt per run rather than reset: a fresh TimeSystem cannot be
	# carrying an expired flag or a leftover rate contribution, and a fresh
	# ModifiersSystem cannot be holding last run's cards.
	for system: Node in systems.get_children():
		systems.remove_child(system)
		system.queue_free()

	time_system = null
	modifiers_system = null


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


## The fuse reached the end. Blows the player up where they stand, then ends the
## run — the explosion is awaited so the run-end screen lands on the debris
## rather than wiping the death off the screen mid-animation.
func _on_time_expired() -> void:
	if _run_ended:
		return

	# Claimed before the await, not after: the explosion takes half a second, and
	# a level exit reached in that window must not be allowed to turn a death
	# into a room clear behind the animation's back.
	_run_ended = true

	if _current_room is BaseLevel and player != null:
		await player.explode()

	end_run(false)


func _load_system(system_uid: String) -> Node:
	var system_scene: PackedScene = ResourceLoader.load(system_uid)
	if system_scene == null:
		push_error("Could not load system scene: " + system_uid)
		return

	var system_node: Node = system_scene.instantiate()
	if system_node == null:
		push_error("Loaded system scene does not extend Player or DNE: " + UIDs.PLAYER_SCENE_UID)
		return
	systems.add_child(system_node)
	return system_node
	
func _load_systems() -> void:
	time_system = _load_system(UIDs.TIME_SYSTEM_UID)
	modifiers_system = _load_system(UIDs.MODIFIERS_SYSTEM_UID)
