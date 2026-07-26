extends Node
## Opens a chest without walking a run to one:
##     godot res://src/debug/TreasureDemo.tscn
##
## The chest row sits halfway through the map, so seeing one in a real run costs
## four levels of platforming first. This boots the real MainGame with the real
## systems and drops straight into a treasure room — the same room, the same
## minigames, the same clock. It is for looking at chests and for handing the art
## a thing to look at, not for testing the map.
##
##     1 / 2 / 3   open Even Split / Rich Seam / Dead Drop
##     R           open the same chest again
##     ESC         quit
##
## Leaving a chest re-opens the picker with the next one along, so the three can
## be played back to back.

const MAIN_SCENE_UID: String = "uid://ccxuyq6o8k8ca"

## The clock a chest is opened on. Mid-range on purpose: at full, a payout clamps
## against max_time and looks like it paid nothing.
const STARTING_CLOCK: float = 34.0

var _tables: Array[String] = []
var _index: int = 0
var _game: MainGame
## The chest currently open. MainGame.enter_room() doesn't unload the room that
## is already there, so opening a second one on top of the first would leave two
## live rooms fighting over one clock — and make any number on screen impossible
## to trust.
var _room: TreasureRoom = null


func _ready() -> void:
	_tables = [
		UIDs.TREASURE_EVEN_SPLIT_UID,
		UIDs.TREASURE_RICH_SEAM_UID,
		UIDs.TREASURE_DEAD_DROP_UID,
	]

	add_child((load(MAIN_SCENE_UID) as PackedScene).instantiate())
	await get_tree().process_frame

	_game = Global.main_game
	_game.load_game()

	print("\ntreasure demo:  [1] Even Split  [2] Rich Seam  [3] Dead Drop  [R] again  [ESC] quit\n")
	_open(_index)


func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return

	var key: InputEventKey = event as InputEventKey
	if key.keycode == KEY_ESCAPE:
		get_tree().quit()
		return

	# Finish the chest you are standing at first. Chests can't be declined by
	# design, and stacking rooms here would only produce numbers that lie.
	if is_instance_valid(_room):
		return

	match key.keycode:
		KEY_1, KEY_2, KEY_3:
			_open(key.keycode - KEY_1)
		KEY_R:
			_open(_index)


## Enters a treasure room carrying a specific chest. A real visit gets its chest
## off the map node the player clicked (see TreasureRoom._resolve_table), so
## setting `last_room` is all it takes to choose one from out here.
func _open(index: int) -> void:
	_index = wrapi(index, 0, _tables.size())

	var room_data: Room = Room.new()
	room_data.type = Room.Type.TREASURE
	room_data.treasure = load(_tables[_index]) as TreasureTable
	room_data.apply_type_scene()
	_game.map.last_room = room_data
	_game.time_system.current_time = STARTING_CLOCK

	print("\nopening '%s' on a %.0fs clock  (%s)" % [
		room_data.treasure.table_name, STARTING_CLOCK, room_data.treasure.get_odds_text()])
	_game.enter_room(room_data.scene_uid, Room.Type.TREASURE)

	_room = _game.get("_current_room") as TreasureRoom
	if _room != null:
		_room.exited.connect(_on_room_left, CONNECT_DEFERRED | CONNECT_ONE_SHOT)


## Straight into the next chest along, so all three can be played in a row.
##
## Prints what the chest actually did on the way out: if a number on screen ever
## looks wrong, the console says what the room thought it paid and what the clock
## did about it, which is the difference between a bug report and a guess.
func _on_room_left() -> void:
	if is_instance_valid(_room):
		print("  paid %+.1fs   clock %.1f -> %.1f of %.1f" % [
			_room.get("_applied"),
			STARTING_CLOCK,
			_game.time_system.current_time,
			_game.time_system.max_time,
		])

	_room = null
	await get_tree().process_frame
	_open(_index + 1)
