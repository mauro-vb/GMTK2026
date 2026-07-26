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
## outcome. Everything else here is bookkeeping: the seconds are run past every
## held modifier on the way out (see [TreasureModifier]), and the result is
## announced.
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

# Exports
## Used when the room is loaded without a map behind it — the debug harness, or
## running the scene straight out of the editor. A real visit always takes the
## chest the player actually clicked.
@export var fallback_table: TreasureTable

# Public

# Private
var _modifiers_system: ModifiersSystem
var _time_system: TimeSystem

var _table: TreasureTable
var _game: TreasureGame
var _closing: bool = false
## The signed seconds the chest actually moved the clock by, once modifiers have
## had their say. Zero until it pays out.
var _applied: float = 0.0
## Seconds the chest was owed but the clock had no room for — a payout hitting
## the tank's ceiling, or a bite stopped by [constant SURVIVAL_FLOOR]. Always
## positive, and zero when the chest paid in full.
var _withheld: float = 0.0

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
	_table = _resolve_table()

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
func _open() -> void:
	backdrop.color.a = 0.0
	ui.modulate.a = 0.0

	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(backdrop, ^"color:a", WorkshopStyle.BACKDROP_ALPHA, WorkshopStyle.FADE_DURATION)
	tween.tween_property(ui, ^"modulate:a", 1.0, WorkshopStyle.FADE_DURATION)
	await tween.finished

	_lay_out_game()


## Picks a game the chest allows and hands it the table.
##
## A chest usually allows two, and the pick is per visit — so meeting the same
## chest twice in a run isn't the same event twice. A game that can't present
## this particular table says so and the next one is tried (see
## [method TreasureGame.can_present]).
func _lay_out_game() -> void:
	if _table == null:
		_pay_out_without_a_game()
		return

	var candidates: Array[TreasureTable.Game] = []
	for game: TreasureTable.Game in [TreasureTable.Game.COIN, TreasureTable.Game.WHEEL, TreasureTable.Game.PLINKO]:
		if _table.allows(game):
			candidates.append(game)

	candidates.shuffle()

	for game: TreasureTable.Game in candidates:
		var instance: TreasureGame = _instance_game(game)
		if instance == null:
			continue

		instance.setup(_table)
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

	push_error("TreasureRoom: no minigame can present '%s'." % _table.table_name)
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


## Last resort: a chest with no game that can show it still pays out rather than
## stranding the run on a room that can't be left.
func _pay_out_without_a_game() -> void:
	if _table == null:
		_settle(null)
		return

	_settle(_table.roll())


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

	# Last thing, as with a workshop visit: one-shot charms spend themselves here
	# and they need to know what the chest actually did.
	if _modifiers_system != null:
		_modifiers_system.notify_treasure_opened(_applied)

	_show_leave(true)
	leave_button.grab_focus()


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

	WorkshopStyle.apply_text(time_label, WorkshopStyle.FONT_TEXT, WorkshopStyle.SIZE_BODY, WorkshopStyle.MUTED)
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

	location_label.text = _table.table_name.to_upper()
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
	_settle(slice)


func _on_leave_pressed() -> void:
	_close()
