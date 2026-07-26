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
##     Q W E A S   pick up a charm — Thumb On The Scale (+ On The Clock) /
##                 Second Chance / Magpie's Eye / Salvage Rights / Shallow Seam
##     C           drop everything
##
## Q is the combined card, so it brings its drawback with it: better odds bought
## with a fuse that keeps burning while the lid is up. Press it and the next
## chest opens on a running clock.
##
## Leaving a chest re-opens the picker with the next one along, so the three can
## be played back to back.
##
## The charm keys work **while a chest is open** and land on the *next* one,
## which is the only shape that works here: a chest reads the odds it is opened
## on once, at `_ready`, and this demo opens the next chest the instant you leave
## the last one — so there is no gap between rooms to equip anything in. Press a
## couple of charms, leave the chest you are on, and the one after it is the
## charmed one.

const MAIN_SCENE_UID: String = "uid://ccxuyq6o8k8ca"

## The clock a chest is opened on. Mid-range on purpose: at full, a payout clamps
## against max_time and looks like it paid nothing.
const STARTING_CLOCK: float = 34.0

var _tables: Array[String] = []
## Key → charm uid. Built in `_ready` rather than declared const, because the
## uids are autoload member accesses and those are not constant expressions —
## the same trap [method Room.apply_type_scene] documents.
var _charms: Dictionary[Key, String] = {}
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
	_charms = {
		KEY_Q: UIDs.THUMB_ON_THE_SCALE_UID,
		KEY_W: UIDs.SECOND_CHANCE_UID,
		KEY_E: UIDs.MAGPIES_EYE_UID,
		KEY_A: UIDs.SALVAGE_RIGHTS_UID,
		KEY_S: UIDs.SHALLOW_SEAM_UID,
	}

	add_child((load(MAIN_SCENE_UID) as PackedScene).instantiate())
	await get_tree().process_frame

	_game = Global.main_game
	_game.load_game()

	print("\ntreasure demo:  [1] Even Split  [2] Rich Seam  [3] Dead Drop  [R] again  [ESC] quit")
	print("charms (land on the NEXT chest):  [Q] Thumb On The Scale + On The Clock  [W] Second Chance")
	print("                                  [E] Magpie's Eye  [A] Salvage Rights  [S] Shallow Seam  [C] drop all\n")
	_open(_index)


func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return

	var key: InputEventKey = event as InputEventKey
	if key.keycode == KEY_ESCAPE:
		get_tree().quit()
		return

	# Charms first, and deliberately *not* behind the room guard below: this demo
	# opens the next chest the instant you leave the last one, so a key that only
	# worked between rooms would never be reachable. What is picked up here lands
	# on the next chest, which is the same rule the game has — a chest reads its
	# odds once, on arrival.
	if _charms.has(key.keycode):
		_pick_up(_charms[key.keycode])
		return

	if key.keycode == KEY_C:
		_drop_everything()
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


## Picks a charm up, or puts it back down if it is already held and doesn't
## stack — so one key covers both halves of "let me see this with and without".
func _pick_up(uid: String) -> void:
	var modifier: Modifier = load(uid) as Modifier
	if modifier == null:
		return

	var modifiers: ModifiersSystem = _game.modifiers_system
	if modifiers.has_modifier(modifier.id) and not modifier.stackable:
		# Both halves of a combined card go back down together — putting a bonus
		# back and keeping the cost it came with is not a state the game has.
		_drop(modifiers, modifier.id)
		if modifier.linked_modifier != null:
			_drop(modifiers, modifier.linked_modifier.id)
	else:
		modifiers.add_modifier(modifier)

	_print_carried()


func _drop(modifiers: ModifiersSystem, id: String) -> void:
	for held: Modifier in modifiers.modifiers.duplicate():
		if held.id == id:
			modifiers.remove_modifier(held)
			return


func _drop_everything() -> void:
	for held: Modifier in _game.modifiers_system.modifiers.duplicate():
		_game.modifiers_system.remove_modifier(held)

	_print_carried()


func _print_carried() -> void:
	var names: Array[String] = []
	for held: Modifier in _game.modifiers_system.modifiers:
		names.append(held.modifier_name)

	print("  carrying: %s   (lands on the next chest)" % [
		"nothing" if names.is_empty() else ", ".join(names)])


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
	if _room == null:
		return

	_room.exited.connect(_on_room_left, CONNECT_DEFERRED | CONNECT_ONE_SHOT)

	# What the chest was actually opened at, when a charm leaned on it. The wheel
	# and the board are cut from these numbers, so this line and the thing on
	# screen are two readings of the same table — and if they ever disagree, the
	# tilt is going in somewhere it shouldn't.
	var played: TreasureTable = _room.get("_table") as TreasureTable
	if played != null and played != room_data.treasure:
		print("  charmed:  %s" % played.get_odds_text())


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

		# The two things a charm does that the clock alone can't show.
		var retries: int = int(_room.get("_retries"))
		if retries > 0:
			print("  reopened %d time(s) by a second chance" % retries)

		var card: Modifier = _room.get("_card") as Modifier
		if card != null:
			print("  and handed over '%s'" % card.modifier_name)

	_room = null
	await get_tree().process_frame
	_open(_index + 1)
