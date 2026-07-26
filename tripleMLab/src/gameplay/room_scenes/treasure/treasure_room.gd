class_name TreasureRoom
extends RoomScene
## The chest room: one gamble with the clock, played out as a minigame.
##
## Halfway through a run every path crosses a row of three chests and the player
## has to take one (see [method MapGenerator._assign_treasure_tables]). Which
## chest they took is the decision; this room is where it is paid off.
##
## The room itself knows nothing about coins, wheels or plinko boards. It reads
## the chest's [TreasureTable] off the map node the player clicked, asks it which
## minigames may present it, lays one of them out, and waits to be told an
## outcome. Everything else here is bookkeeping: the chest's odds are run past
## every held modifier on the way *in* and its seconds on the way out (see
## [TreasureModifier]), and the result is announced.
##
## Which way round those two happen is the whole of the room's honesty. Odds are
## asked for before a game is laid out, so a wheel's wedges and a board's row are
## cut from the tilted numbers and the player can see the tilt before committing
## to it. Seconds are asked for after the outcome is known, where nothing is left
## to advertise.
##
## The room states no odds of its own. Each game is drawn so that its terms are
## legible from the thing itself — the size of a wheel's wedges, the row of
## numbers under a plinko board, the two sides of a coin — and a line of
## percentages on top of that is the same information twice, in the form nobody
## reads.
##
## Structurally this is the [Workshop] again — a full-screen takeover loaded into
## SceneContainer.LEVEL, carrying its own clock and carried-modifier strip
## because the map HUD comes down for the duration. The clock is off while a
## chest is open (`should_tick_time` is false in the scene): a gamble is not a
## time trial.

# Signals
# Enums

# Constants
## The floor a chest will not take the clock below. A chest is a gamble on the
## run, not the end of it — and a run that walks into the next level on nothing
## is over anyway, without ever being told why. Set it to 0.0 to let chests kill.
const SURVIVAL_FLOOR: float = 2.0

## The beat between a chest biting and the same chest being opened again, for a
## run carrying a second chance. Long enough to read what was just dodged.
const RETRY_PAUSE: float = 0.9

# Exports
## Used when the room is loaded without a map behind it — the debug harness, or
## running the scene straight out of the editor. A real visit always takes the
## chest the player actually clicked.
@export var fallback_table: TreasureTable
## The coin-flip shape of the same fallback chest — see [member Room.treasure_coin].
@export var fallback_coin_table: TreasureTable
## Whether the fallback chest (standalone runs only) is the corrupted one.
@export var fallback_corrupted: bool = false

## Where a card found in a chest's lining comes from. Left null it falls back to
## the workshop's own pool, which is almost always what is wanted: a chest that
## hands out modifiers should be handing out the same modifiers a bench does, and
## the pool's `min_depth` terms then hold for both.
@export var card_pool: WorkshopPool

# Public

# Private
var _modifiers_system: ModifiersSystem
var _time_system: TimeSystem

var _table: TreasureTable
## The same chest, coin-shaped — see [member Room.treasure_coin].
var _coin_table: TreasureTable
## Whether this visit's chest always bites. Read off the map once, in
## [method _ready], and used only for phrasing — the tables themselves already
## enforce it via which slices exist.
var _corrupted: bool = false
var _game: TreasureGame
var _closing: bool = false
## The signed seconds the chest actually moved the clock by, once modifiers have
## had their say. Zero until it pays out.
var _applied: float = 0.0
## Seconds the chest was owed but the clock had no room for — a payout hitting
## the tank's ceiling, or a bite stopped by [constant SURVIVAL_FLOOR]. Always
## positive, and zero when the chest paid in full.
var _withheld: float = 0.0
## How many times a second chance has reopened this chest. Bounded by the
## modifiers that pay for them — each is spent on the reopening it buys — and
## kept here so the room can say it happened.
var _retries: int = 0
## The modifier a chest coughed up alongside the seconds, if any (see
## [method _offer_card]).
var _card: Modifier

# On Ready
@onready var ui: Control = %UI
@onready var backdrop: ColorRect = %Backdrop
@onready var time_label: Label = %TimeLabel
@onready var carry_row: HBoxContainer = %CarryRow
@onready var location_label: Label = %Location
@onready var instruction_label: Label = %Instruction
@onready var board: PanelContainer = %Board
@onready var result_panel: PanelContainer = %Result
@onready var result_label: Label = %ResultLabel
@onready var leave_button: Button = %LeaveButton

# Static

# Lifecycle
func _ready() -> void:
	_modifiers_system = _resolve_modifiers_system()
	_time_system = _resolve_time_system()
	_corrupted = _resolve_corrupted()
	# Tilted here, before anything is drawn: every game downstream reads its odds
	# off these tables, so this is the one place a charm can lean on a chest
	# without the chest ever misrepresenting itself.
	_table = _tilt(_resolve_table())
	_coin_table = _tilt(_resolve_coin_table())
	_read_clock_terms()

	_style_chrome()
	_build_strip()
	leave_button.pressed.connect(_on_leave_pressed)
	# Nothing to leave with until the chest has been opened, and no way to walk
	# away from it either: the choice was made on the map.
	#
	# Hidden by alpha rather than by `visible`, so it still holds its place in
	# the column. A button that appears at the moment of the result would shrink
	# the board it appears under — and the board is where the player is looking.
	_show_leave(false)
	result_panel.modulate.a = 0.0

	_refresh_header()

	await _open()

# Public

# Private
## Whether this particular visit is on a running clock.
##
## `should_tick_time` is false in the scene, because a gamble is not a time
## trial. A run carrying the drawback half of a combined card flips it back —
## and it is flipped **here, in `_ready`**, because `MainGame.enter_room()` reads
## the flag off the room immediately after loading it (`time_system.ticking =
## _current_room.should_tick_time`). Writing to `ticking` directly instead would
## be overwritten one line later; changing what the room *says about itself* is
## read by the thing that asks.
##
## The header says so too. A clock that has quietly started running is the one
## thing in this room the player must not have to notice for themselves.
func _read_clock_terms() -> void:
	if _modifiers_system == null or not _modifiers_system.is_treasure_clock_running():
		return

	should_tick_time = true


func _open() -> void:
	backdrop.color.a = 0.0
	ui.modulate.a = 0.0

	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(backdrop, ^"color:a", WorkshopStyle.BACKDROP_ALPHA, WorkshopStyle.FADE_DURATION)
	tween.tween_property(ui, ^"modulate:a", 1.0, WorkshopStyle.FADE_DURATION)
	await tween.finished

	await _play_entry_line()
	_lay_out_game()


## The room's own tiny event beat — a line about what this chest is, held long
## enough to read before the minigame takes the instruction line over. Sourced
## from `_table` rather than `_coin_table`: which minigame plays is chosen
## after this beat, so the line has to describe the chest, not the game.
func _play_entry_line() -> void:
	var line: String = _table.entry_line if _table != null else ""
	if line.is_empty():
		return

	instruction_label.text = line
	await get_tree().create_timer(TreasureStyle.ENTRY_LINE_HOLD).timeout


## Picks a game the chest allows and hands it the table.
##
## A chest usually allows two, and the pick is per visit — so meeting the same
## chest twice in a run isn't the same event twice. A game that can't present
## this particular table says so and the next one is tried (see
## [method TreasureGame.can_present]).
func _lay_out_game() -> void:
	if _table == null and _coin_table == null:
		_pay_out_without_a_game()
		return

	# Coin plays from `_coin_table` rather than `_table` — it needs exactly two
	# outcomes for two faces, and `_table` now carries a third, middling one for
	# the wheel and the board (see [member Room.treasure_coin]).
	var candidates: Array[Dictionary] = []
	for game: TreasureTable.Game in [TreasureTable.Game.WHEEL, TreasureTable.Game.PLINKO]:
		if _table != null and _table.allows(game):
			candidates.append({"game": game, "table": _table})
	if _coin_table != null and _coin_table.allows(TreasureTable.Game.COIN):
		candidates.append({"game": TreasureTable.Game.COIN, "table": _coin_table})

	candidates.shuffle()

	for candidate: Dictionary in candidates:
		var game: TreasureTable.Game = candidate["game"]
		var table: TreasureTable = candidate["table"]
		var instance: TreasureGame = _instance_game(game)
		if instance == null:
			continue

		instance.setup(table)
		if not instance.can_present():
			instance.queue_free()
			continue

		_game = instance
		_game.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_game.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_game.resolved.connect(_on_game_resolved)
		_game.prompt_changed.connect(_on_prompt_changed)
		board.add_child(_game)
		_game.begin()
		return

	push_error("TreasureRoom: no minigame can present this chest.")
	_pay_out_without_a_game()


func _instance_game(game: TreasureTable.Game) -> TreasureGame:
	# Not a const Dictionary: the uids are autoload member accesses, which are
	# not constant expressions — the same trap Room.apply_type_scene() documents.
	var scene_uid: String = ""
	match game:
		TreasureTable.Game.COIN:
			scene_uid = UIDs.TREASURE_COIN_GAME_UID
		TreasureTable.Game.WHEEL:
			scene_uid = UIDs.TREASURE_WHEEL_GAME_UID
		TreasureTable.Game.PLINKO:
			scene_uid = UIDs.TREASURE_PLINKO_GAME_UID
		_:
			return null

	var scene: PackedScene = ResourceLoader.load(scene_uid)
	if scene == null:
		push_error("TreasureRoom: could not load '%s'." % scene_uid)
		return null

	return scene.instantiate() as TreasureGame


## Whether something the player is carrying will pay for this bite to be torn up.
##
## Only ever asked about a bite: a second chance is insurance, not a reroll of a
## payout the player is happy with. Whoever agrees is spent inside
## [method ModifiersSystem.claim_treasure_retry], so a chest can only be reopened
## as many times as the run brought charms to reopen it with.
func _claim_retry(slice: TreasureSlice) -> bool:
	if slice == null or slice.is_gain() or _modifiers_system == null:
		return false

	return _modifiers_system.claim_treasure_retry(slice.seconds)


## Throws the outcome away and opens the same chest again.
##
## The game is laid out from scratch rather than replayed, so the second opening
## is often a different one of the chest's games — which is the honest reading of
## "open it again", and stops the retry from being a button that rerolls a wheel.
func _retry() -> void:
	_retries += 1
	instruction_label.text = "IT BIT  ·  SECOND CHANCE"

	_clear_game()
	await get_tree().create_timer(RETRY_PAUSE).timeout
	_lay_out_game()


## Detached before freeing rather than only queued: a game still parented to the
## board when the next one is built would be laid out alongside it for a frame,
## and both would be listening for input.
func _clear_game() -> void:
	if _game == null:
		return

	board.remove_child(_game)
	_game.queue_free()
	_game = null


## Last resort: a chest with no game that can show it still pays out rather than
## stranding the run on a room that can't be left.
func _pay_out_without_a_game() -> void:
	var table: TreasureTable = _table if _table != null else _coin_table
	if table == null:
		_settle(null)
		return

	_settle(table.roll())


## Turns an outcome into seconds. The only place in the room that touches the
## clock.
##
## A payout and a bite are run past different hooks on the way out, and both are
## handed to modifiers as a positive amount — so a modifier that halves losses
## can't accidentally halve a win, and neither can flip a sign.
func _settle(slice: TreasureSlice) -> void:
	if slice != null and _time_system != null:
		# Measured rather than assumed: the clock has a ceiling, so a jackpot
		# landing on a nearly-full clock is worth less than it says on the tin.
		# The room reports what the run actually got, because the alternative is
		# a number on screen that the clock disagrees with.
		var before: float = _time_system.current_time
		var owed: float = 0.0
		if slice.is_gain():
			owed = _gain_seconds(slice.seconds)
			_time_system.add_time(owed)
		else:
			owed = _lose_seconds(-slice.seconds)
			_time_system.remove_time(owed)

		_applied = _time_system.current_time - before
		_withheld = maxf(owed - absf(_applied), 0.0)

	_show_result(slice)

	# Last things, as with a workshop visit: one-shot charms spend themselves
	# here and they need to know what the chest actually did — and then, for a
	# run carrying the right charm, the chest is searched for anything that isn't
	# seconds. In that order, so a card found in the lining can't be burned by
	# the chest that handed it over.
	if _modifiers_system != null:
		_modifiers_system.notify_treasure_opened(_applied)

	_offer_card(slice)

	_show_leave(true)
	leave_button.grab_focus()


## A chest that owes more than time. Nothing offers this until the player is
## carrying something that does (the base chance is zero), which is why the roll
## is the first thing here and usually the last.
##
## The card is drawn from the workshop's own pool at the run's current depth, so
## a chest can only hand over what a bench that deep could have laid out — no
## first-row run gets handed a run-defining modifier out of a hole in the ground.
func _offer_card(slice: TreasureSlice) -> void:
	if _modifiers_system == null:
		return

	var was_gain: bool = slice.is_gain() if slice != null else _applied >= 0.0
	var chance: float = _modifiers_system.get_treasure_card_chance(was_gain)
	if chance <= 0.0 or randf() > chance:
		return

	var pool: WorkshopPool = _card_pool()
	if pool == null:
		return

	var entries: Array[WorkshopEntry] = pool.draw(1, _depth(), _modifiers_system)
	if entries.is_empty() or entries[0].modifier == null:
		return

	_card = entries[0].modifier
	# The icon lands in the carry strip on its own — the strip is listening (see
	# `_build_strip`) — so all the header has to do is name it. Without the name
	# the player is left to work out which of the icons is new.
	_modifiers_system.add_modifier(_card)
	instruction_label.text = "%s  ·  %s" % [instruction_label.text, _card.modifier_name.to_upper()]


func _card_pool() -> WorkshopPool:
	if card_pool != null:
		return card_pool

	return ResourceLoader.load(UIDs.WORKSHOP_DEFAULT_POOL_UID) as WorkshopPool


func _gain_seconds(seconds: float) -> float:
	if _modifiers_system == null:
		return seconds

	return _modifiers_system.get_treasure_gain(seconds)


## Losses are clamped so a chest can never take the last of the clock — see
## [constant SURVIVAL_FLOOR].
func _lose_seconds(seconds: float) -> float:
	var loss: float = seconds
	if _modifiers_system != null:
		loss = _modifiers_system.get_treasure_loss(seconds)

	if _time_system == null:
		return loss

	return minf(loss, maxf(_time_system.current_time - SURVIVAL_FLOOR, 0.0))


# --- Chrome ------------------------------------------------------------------
## Everything the scene file can't carry, in the workshop's own hand: Labels have
## no entry in the project theme, so without this they'd render at Godot's
## default 16px on a 320x180 screen.
func _style_chrome() -> void:
	backdrop.color = WorkshopStyle.INK
	backdrop.color.a = WorkshopStyle.BACKDROP_ALPHA

	# A clock that is running reads in the run's warning colour rather than as
	# quiet furniture — the number moving is the whole of the drawback, and it
	# sits in the corner where a static number has been every other visit.
	WorkshopStyle.apply_text(time_label, WorkshopStyle.FONT_TEXT, WorkshopStyle.SIZE_BODY,
		WorkshopStyle.CAUTION if should_tick_time else WorkshopStyle.MUTED)
	WorkshopStyle.apply_text(location_label, WorkshopStyle.FONT_TEXT, WorkshopStyle.SIZE_SEAM, WorkshopStyle.MUTED)
	WorkshopStyle.apply_text(instruction_label, WorkshopStyle.FONT_DISPLAY, WorkshopStyle.SIZE_TITLE, WorkshopStyle.EMBER)
	WorkshopStyle.apply_text(result_label, WorkshopStyle.FONT_DISPLAY, TreasureStyle.SIZE_RESULT, WorkshopStyle.PARCHMENT)

	board.add_theme_stylebox_override(&"panel", TreasureStyle.board_panel())
	board.custom_minimum_size.y = TreasureStyle.BOARD_HEIGHT
	result_panel.add_theme_stylebox_override(&"panel", TreasureStyle.result_panel())
	result_panel.custom_minimum_size.y = TreasureStyle.RESULT_HEIGHT
	carry_row.custom_minimum_size.y = TreasureStyle.STRIP_HEIGHT

	WorkshopStyle.apply_button_text(leave_button, WorkshopStyle.SIZE_SUBTITLE)


## The map HUD is down while a chest is open (see MainGame.enter_treasure), so
## the clock and the row of what the player is carrying are rebuilt here, exactly
## as the workshop rebuilds them.
func _build_strip() -> void:
	if _time_system != null:
		_time_system.time_changed.connect(_on_time_changed)
		_on_time_changed(_time_system.current_time)

	if _modifiers_system == null:
		return

	for modifier: Modifier in _modifiers_system.modifiers:
		_add_carried(modifier)

	# A chest that hands over a card puts it in the strip on the spot, the way a
	# workshop does when a card is taken — otherwise the only sign of it is a
	# name in the header and an icon that shows up two rooms later.
	_modifiers_system.modifier_added.connect(_add_carried)


func _add_carried(modifier: Modifier) -> void:
	var texture: Texture2D = modifier.icon as Texture2D
	var icon: ModifierIcon = ModifierIcon.new_modifier_icon(modifier)
	carry_row.add_child(icon)
	icon.setup(modifier, texture if texture != null else ModifierDisplay.PLACEHOLDER_ICON)


## The chest names itself, and the game under it says the rest.
func _refresh_header() -> void:
	if _table == null:
		location_label.text = "CHEST"
		instruction_label.text = "EMPTY"
		return

	# The chest names itself — and, when the fuse is burning, says so next to its
	# own name. A clock that has quietly started running is the one thing in this
	# room the player must not be left to notice for themselves.
	location_label.text = _table.table_name.to_upper()
	if should_tick_time:
		location_label.text += "  ·  ON THE CLOCK"

	instruction_label.text = "OPEN IT"


## The payoff, in the map's own language: punch out, flash at the peak, settle.
## Taking a card on a bench does the same thing, and for the same reason — this
## is the moment the room existed for.
func _show_result(slice: TreasureSlice) -> void:
	instruction_label.text = "" if slice == null else _result_text(slice)
	result_label.text = "%+ds" % roundi(_applied)
	result_label.add_theme_color_override(&"font_color", TreasureStyle.outcome_color(_applied))

	result_panel.pivot_offset = result_panel.size * 0.5
	result_panel.modulate.a = 1.0

	var tween: Tween = create_tween()
	tween.tween_property(result_panel, ^"scale", Vector2.ONE * TreasureStyle.RESULT_SCALE, TreasureStyle.RESULT_PUNCH) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(result_panel, ^"scale", Vector2.ONE, TreasureStyle.RESULT_SETTLE) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## The way out, on or off. It keeps its space in the column either way (see
## `_ready`), so the only thing that changes is whether it can be seen or used.
func _show_leave(shown: bool) -> void:
	leave_button.disabled = not shown
	leave_button.focus_mode = Control.FOCUS_ALL if shown else Control.FOCUS_NONE
	leave_button.modulate.a = 1.0 if shown else 0.0


## What just happened, and — when the clock couldn't take all of it — why the
## number is smaller than the wedge or the bin said.
##
## Without this the room looks like it is lying. A chest that rolls +12s onto a
## clock six seconds short of full pays exactly +6s, which is the truth and reads
## as a bug: the player saw +12 promised and got half of it with no explanation.
func _result_text(slice: TreasureSlice) -> String:
	# The chest's own miss: a rolled zero, applied as zero. Checked against the
	# slice itself rather than `_applied` so a charm that bonuses a "nothing"
	# into a real number falls through to PAID OUT below instead of lying about
	# it, and so a bite the clock floor swallowed entirely (`_applied` also
	# zero, but the slice wasn't) still reads as NOTHING LEFT further down.
	if is_zero_approx(slice.seconds) and is_zero_approx(_applied):
		return "YOU GOT LUCKY THIS TIME" if _corrupted else "BETTER LUCK NEXT TIME"

	if is_zero_approx(_withheld):
		return "PAID OUT" if slice.is_gain() else "IT BITES"

	# A payout that overflowed the tank, or a bite the run was too short to take.
	if slice.is_gain():
		return "PAID OUT  ·  TANK FULL"

	return "IT BITES  ·  NOTHING LEFT"


## Closes the room and hands it back to MainGame.
func _close() -> void:
	if _closing:
		return
	_closing = true

	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(ui, ^"modulate:a", 0.0, WorkshopStyle.FADE_DURATION)
	tween.tween_property(backdrop, ^"color:a", 0.0, WorkshopStyle.FADE_DURATION)
	await tween.finished

	exit()


# --- Helpers -----------------------------------------------------------------
## Which chest this is. The map sets `last_room` before it announces the pick, so
## by the time this room exists the room the player clicked is already on record
## — which is how the chest gets here without every room type having to carry a
## payload through MainGame.
func _resolve_table() -> TreasureTable:
	if Global.main_game != null and Global.main_game.map != null:
		var room: Room = Global.main_game.map.last_room
		if room != null and room.treasure != null:
			return room.treasure

	if fallback_table == null:
		push_error("TreasureRoom: no chest to open.")

	return fallback_table


## The same chest's coin-flip shape — see [member Room.treasure_coin].
func _resolve_coin_table() -> TreasureTable:
	if Global.main_game != null and Global.main_game.map != null:
		var room: Room = Global.main_game.map.last_room
		if room != null and room.treasure_coin != null:
			return room.treasure_coin

	return fallback_coin_table


## Whether this chest always bites. Only used for phrasing (see
## [method _result_text]) — the tables themselves already carry the terms.
func _resolve_corrupted() -> bool:
	if Global.main_game != null and Global.main_game.map != null:
		var room: Room = Global.main_game.map.last_room
		if room != null:
			return room.is_corrupted

	return fallback_corrupted


## The chest the player will actually play: the authored one with every held
## modifier's say over its odds folded in.
##
## Done once, on arrival, and *before* a game is laid out — which is the whole
## condition on which the odds may be touched at all. A wheel cuts its wedges and
## a board deals its row out of `_table`, so a chest leaned on by a charm draws
## itself leaned on and the player reads the tilt off the game in front of them.
##
## A copy per visit, slices and all, so nothing here writes back into the shared
## .tres and the next chest of the same kind is the authored one again. Returns
## the original untouched when no modifier had anything to say, which is the
## usual case — and refuses a tilt that would leave a chest with no outcomes at
## all rather than laying out a chest that cannot resolve.
func _tilt(source: TreasureTable) -> TreasureTable:
	if source == null or _modifiers_system == null:
		return source

	var slices: Array[TreasureSlice] = []
	var changed: bool = false
	for slice: TreasureSlice in source.slices:
		if slice == null:
			continue

		var copy: TreasureSlice = slice.duplicate() as TreasureSlice
		copy.weight = _modifiers_system.get_treasure_weight(slice.weight, slice.is_gain())
		changed = changed or not is_equal_approx(copy.weight, slice.weight)
		slices.append(copy)

	if not changed:
		return source

	var tilted: TreasureTable = source.duplicate() as TreasureTable
	tilted.slices = slices
	if not tilted.is_valid():
		push_warning("TreasureRoom: a tilt emptied '%s'; opening it as authored." % source.table_name)
		return source

	return tilted


## How far into the run this chest is, for the pool a card in the lining is drawn
## from. The workshop asks the same question of the same place.
func _depth() -> int:
	if Global.main_game == null or Global.main_game.map == null:
		return 0

	return Global.main_game.map.progress


func _resolve_modifiers_system() -> ModifiersSystem:
	if Global.main_game == null or Global.main_game.modifiers_system == null:
		push_error("TreasureRoom: ModifiersSystem not found.")
		return null

	return Global.main_game.modifiers_system


func _resolve_time_system() -> TimeSystem:
	if Global.main_game == null or Global.main_game.time_system == null:
		push_error("TreasureRoom: TimeSystem not found.")
		return null

	return Global.main_game.time_system

# Callbacks
## Matches the HUD's rounding so the number doesn't appear to jump when the room
## hands the clock back.
func _on_time_changed(value: float) -> void:
	time_label.text = str(ceil(value))


func _on_prompt_changed(prompt: String) -> void:
	instruction_label.text = prompt


func _on_game_resolved(slice: TreasureSlice) -> void:
	# A beat between the coin landing and the clock moving, so the payout reads
	# as a consequence of it rather than as part of the same frame.
	await get_tree().create_timer(TreasureStyle.PAYOUT_DELAY).timeout

	# ...and, for a run that brought one, the beat where a bad outcome is torn up
	# instead. Asked before the clock is touched, so a second chance is a chest
	# reopened rather than a refund.
	if _claim_retry(slice):
		_retry()
		return

	_settle(slice)


func _on_leave_pressed() -> void:
	_close()
