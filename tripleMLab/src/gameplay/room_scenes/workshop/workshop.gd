class_name Workshop
extends RoomScene
## The bench between levels: a handful of modifiers laid out, and the player
## takes one.
##
## The workshop never asks *which* modifiers the player is carrying. Every number
## it runs on — how many go on the bench, how many may be taken, how many sweeps
## it allows, what the draw favours, what walking away is worth — is a question
## put to [ModifiersSystem], which puts it to each held modifier in turn. That is
## the whole extension point: a modifier that widens the bench or buys a second
## pick is a .tres, not a change in here (see [WorkshopModifier]).
##
## The clock is off while the bench is open (`should_tick_time` is false in the
## scene), so choosing is never a time trial — except for a player carrying
## "Live Wire", which switches the clock back on for exactly this reason.

# Signals
# Enums

# Constants
## What a workshop is worth before any modifier has its say. Three cards is the
## shape the layout is tuned for; the bench stays readable up to about six.
const BASE_OFFERS: int = 3
const BASE_PICKS: int = 1
const BASE_REROLLS: int = 0

## Seconds paid for leaving a bench untouched, before modifiers. Zero: walking
## away is worth nothing until something says otherwise.
const BASE_SKIP_BONUS: float = 0.0

const DETAIL_FADE_OUT: float = 0.06
const DETAIL_FADE_IN: float = 0.12

# Exports
@export var pool: WorkshopPool

# Public

# Private
var _modifiers_system: ModifiersSystem
var _time_system: TimeSystem

var _offers: int = BASE_OFFERS
var _picks_remaining: int = BASE_PICKS
var _picks_taken: int = 0
var _rerolls_total: int = BASE_REROLLS
var _rerolls_remaining: int = BASE_REROLLS
var _skip_bonus: float = BASE_SKIP_BONUS

var _cards: Array[WorkshopCard] = []
## True while an animation owns the bench. Every entry point checks it, so a
## second click during the take animation can't spend a pick that isn't there.
var _busy: bool = false
var _closing: bool = false
## False until a draw has actually been attempted. Without it the header reads
## "the bench is bare" during the opening fade, when the truth is only that the
## cards haven't been dealt yet.
var _bench_drawn: bool = false

var _detail_tween: Tween

# On Ready
@onready var ui: Control = %UI
@onready var backdrop: Control = %Backdrop
@onready var scrim: ColorRect = %Scrim
@onready var carry_row: HBoxContainer = %CarryRow
@onready var location_label: Label = %Location
@onready var instruction_label: Label = %Instruction
@onready var card_row: HBoxContainer = %CardRow
@onready var detail_panel: PanelContainer = %Detail
@onready var detail_box: VBoxContainer = %DetailBox
@onready var detail_name: Label = %DetailName
@onready var detail_meta: Label = %DetailMeta
@onready var detail_body: Label = %DetailBody
@onready var detail_cost: Label = %DetailCost
@onready var reroll_button: Button = %RerollButton
@onready var leave_button: Button = %LeaveButton

# Static

# Lifecycle
func _ready() -> void:
	_modifiers_system = _resolve_modifiers_system()
	_time_system = _resolve_time_system()

	_style_chrome()
	_build_strip()
	reroll_button.pressed.connect(_on_reroll_pressed)
	leave_button.pressed.connect(_on_leave_pressed)

	_read_terms()
	_refresh_header()
	_refresh_footer()
	_clear_detail()

	await _open()

# Public

# Private
## Asks the run what this particular workshop is worth. Done once, on arrival:
## the terms of a bench shouldn't shift underneath the player because taking the
## first card changed what they're carrying.
func _read_terms() -> void:
	if _modifiers_system == null:
		return

	_offers = _modifiers_system.get_workshop_offers(BASE_OFFERS)
	_picks_remaining = _modifiers_system.get_workshop_picks(BASE_PICKS)
	_rerolls_total = _modifiers_system.get_workshop_rerolls(BASE_REROLLS)
	_rerolls_remaining = _rerolls_total
	_skip_bonus = _modifiers_system.get_workshop_skip_bonus(BASE_SKIP_BONUS)


## The cave fades up under the bench rather than the bench appearing over a hole
## in the screen. The whole backdrop — image and scrim together — rides one
## `modulate`, so the scrim can never be caught halfway up over a cave that has
## already arrived.
func _open() -> void:
	backdrop.modulate.a = 0.0
	ui.modulate.a = 0.0

	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(backdrop, ^"modulate:a", 1.0, WorkshopStyle.FADE_DURATION)
	tween.tween_property(ui, ^"modulate:a", 1.0, WorkshopStyle.FADE_DURATION)
	await tween.finished

	await _lay_out_bench()


## Rolls a bench and deals it. Also the reroll path, so it is responsible for
## clearing whatever was there before it.
func _lay_out_bench() -> void:
	_busy = true
	_clear_cards()

	var entries: Array[WorkshopEntry] = _draw_entries()
	_bench_drawn = true
	if entries.is_empty():
		_show_empty_bench()
		_busy = false
		leave_button.grab_focus()
		return

	for entry: WorkshopEntry in entries:
		var card: WorkshopCard = WorkshopCard.new_card(entry)
		card.custom_minimum_size = Vector2(WorkshopStyle.CARD_MIN_WIDTH, WorkshopStyle.CARD_HEIGHT)
		# Every card claims an equal share of the row, so the bench spans the full
		# column and its outer edges land exactly on the description panel's. A
		# fixed width would leave the row floating inside the panel below it, and
		# a wider bench would shrink away from it rather than divide it.
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		# Vertically the cards keep the height they were drawn at rather than
		# stretching into whatever slack the row has.
		card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		card.chosen.connect(_on_card_chosen)
		card.highlighted.connect(_on_card_highlighted)
		card_row.add_child(card)
		_cards.append(card)

	await _deal_cards()

	_busy = false
	_refresh_header()
	_refresh_footer()
	_focus_first_available()


func _draw_entries() -> Array[WorkshopEntry]:
	if pool == null:
		push_error("Workshop: no WorkshopPool assigned.")
		return []

	return pool.draw(_offers, _depth(), _modifiers_system)


func _deal_cards() -> void:
	for index: int in _cards.size():
		_cards[index].deal_in(float(index) * WorkshopStyle.DEAL_STAGGER)

	# One timer for the whole deal rather than awaiting each card: the cards are
	# staggered, so awaiting them in order would wait for the first to land
	# before the second had even been told to move.
	await _wait(float(_cards.size() - 1) * WorkshopStyle.DEAL_STAGGER + WorkshopStyle.DEAL_DURATION)


func _sweep_cards() -> void:
	for index: int in _cards.size():
		_cards[index].sweep_out(float(index) * WorkshopStyle.DEAL_STAGGER)

	await _wait(float(_cards.size() - 1) * WorkshopStyle.DEAL_STAGGER + WorkshopStyle.SWEEP_DURATION)


## Detached before freeing, not just queued: a card that is still a child of the
## row when the next bench is built would be laid out alongside it for a frame.
func _clear_cards() -> void:
	for card: WorkshopCard in _cards:
		card_row.remove_child(card)
		card.queue_free()
	_cards.clear()


## Closes the bench for good and hands the room back to MainGame.
func _close() -> void:
	if _closing:
		return
	_closing = true
	_busy = true

	if _picks_taken == 0 and _skip_bonus > 0.0 and _time_system != null:
		_time_system.add_time(_skip_bonus)

	# Last thing before the fade: one-shot workshop perks spend themselves here,
	# and they need to know what the player actually walked away with.
	if _modifiers_system != null:
		_modifiers_system.notify_workshop_visited(_picks_taken)

	for card: WorkshopCard in _cards:
		card.pass_over()

	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(ui, ^"modulate:a", 0.0, WorkshopStyle.FADE_DURATION) \
		.set_delay(WorkshopStyle.FADE_DURATION)
	tween.tween_property(backdrop, ^"modulate:a", 0.0, WorkshopStyle.FADE_DURATION) \
		.set_delay(WorkshopStyle.FADE_DURATION)
	await tween.finished

	exit()


# --- Chrome ------------------------------------------------------------------
## Everything the scene file can't carry.
##
## The room's name, its instruction and its two buttons are all plain theme
## types now — HintLabel, SubtitleLabel and Button, set in the scene — so a bench
## is dressed by main_theme.tres exactly as the start menu is. What is left here
## is the paperwork inside the description panel, which has no theme entry of its
## own and would otherwise come out at Godot's default 16px on a 320x180 screen,
## and the panel itself.
func _style_chrome() -> void:
	scrim.color = WorkshopStyle.INK
	scrim.color.a = WorkshopStyle.BACKDROP_ALPHA

	WorkshopStyle.apply_text(detail_name, WorkshopStyle.FONT_DISPLAY, WorkshopStyle.SIZE_CARD_NAME, WorkshopStyle.PARCHMENT)
	WorkshopStyle.apply_text(detail_meta, WorkshopStyle.FONT_TEXT, WorkshopStyle.SIZE_SEAM, WorkshopStyle.MUTED)
	WorkshopStyle.apply_text(detail_cost, WorkshopStyle.FONT_TEXT, WorkshopStyle.SIZE_BODY, WorkshopStyle.CAUTION)
	WorkshopStyle.apply_text(detail_body, WorkshopStyle.FONT_TEXT, WorkshopStyle.SIZE_BODY, WorkshopStyle.MUTED)

	detail_panel.add_theme_stylebox_override(&"panel", WorkshopStyle.detail_panel())
	detail_panel.custom_minimum_size.y = WorkshopStyle.DETAIL_HEIGHT
	card_row.custom_minimum_size.y = WorkshopStyle.CARD_HEIGHT
	card_row.add_theme_constant_override(&"separation", int(WorkshopStyle.CARD_GAP))
	carry_row.custom_minimum_size.y = WorkshopStyle.STRIP_HEIGHT


## The map HUD is down while the bench is open (see MainGame.enter_workshop), so
## the row of what the player already has is rebuilt here. The clock beside it is
## a [FuseBar] straight out of the HUD and wires itself up, which is the point:
## the bench shows the same fuse the level did, not a second opinion about it.
##
## The clock is usually frozen in a workshop and is shown anyway — a player
## carrying "Live Wire" is on a timer while they browse, and that is exactly the
## moment they must not have to guess how long they have been standing here.
func _build_strip() -> void:
	if _modifiers_system == null:
		return

	# ModifierIcon rather than the whole ModifierDisplay: the display anchors
	# itself into the bottom-right corner, which is where the buttons are. The
	# icon is the reusable part, tooltip and hover animation included.
	for modifier: Modifier in _modifiers_system.modifiers:
		_add_carried(modifier)

	# Taking a card lands its icon in the strip on the spot, so the pick has a
	# visible consequence beyond the card going grey.
	_modifiers_system.modifier_added.connect(_add_carried)


func _add_carried(modifier: Modifier) -> void:
	var texture: Texture2D = modifier.icon as Texture2D
	var icon: ModifierIcon = ModifierIcon.new_modifier_icon(modifier)
	carry_row.add_child(icon)
	icon.setup(modifier, texture if texture != null else ModifierDisplay.PLACEHOLDER_ICON)


## The instruction is the header, not the room's name: it is the thing that
## changes, and the thing the player is here to act on.
func _refresh_header() -> void:
	location_label.text = "WORKSHOP"
	instruction_label.text = _subtitle_text()


func _subtitle_text() -> String:
	if _bench_drawn and _cards.is_empty() and _picks_taken == 0 and not _closing:
		return "THE BENCH IS BARE"
	if _picks_remaining <= 0:
		return "BENCH CLOSED"

	var total: int = _picks_remaining + _picks_taken
	if total <= 1:
		return "TAKE ONE"

	return "TAKE %d  ·  %d LEFT" % [total, _picks_remaining]


func _refresh_footer() -> void:
	# The sweep button is shown whenever the run grants sweeps at all, and only
	# greys out once they're spent — hiding it would make the perk look broken.
	reroll_button.visible = _rerolls_total > 0
	reroll_button.disabled = _rerolls_remaining <= 0 or _busy
	reroll_button.text = "Sweep (%d)" % _rerolls_remaining

	# The skip bonus is only ever paid for an untouched bench, so it stops being
	# advertised the moment it stops being on offer.
	if _picks_taken == 0 and _skip_bonus > 0.0:
		leave_button.text = "Leave  +%ds" % roundi(_skip_bonus)
	else:
		leave_button.text = "Leave"


# --- Detail panel ------------------------------------------------------------
func _show_detail(entry: WorkshopEntry) -> void:
	if entry == null or entry.modifier == null:
		return

	# Cross-faded rather than swapped: at this size a hard text change between
	# two cards reads as a flicker, not as new information.
	if _detail_tween != null and _detail_tween.is_valid():
		_detail_tween.kill()

	_detail_tween = create_tween()
	_detail_tween.tween_property(detail_box, ^"modulate:a", 0.0, DETAIL_FADE_OUT)
	_detail_tween.tween_callback(_write_detail.bind(entry))
	_detail_tween.tween_property(detail_box, ^"modulate:a", 1.0, DETAIL_FADE_IN)


func _write_detail(entry: WorkshopEntry) -> void:
	var modifier: Modifier = entry.modifier
	detail_name.text = modifier.modifier_name
	detail_meta.text = _meta_text(entry)
	detail_meta.add_theme_color_override(&"font_color", WorkshopStyle.card_accent(entry.is_combined()))
	detail_body.text = modifier.get_description()

	# The cost gets its own line in its own colour rather than being tacked onto
	# the end of the description — on a combined card it is half the decision,
	# and it should not read as a footnote to the good half.
	detail_cost.visible = entry.is_combined()
	if entry.is_combined():
		detail_cost.text = "%s: %s" % [
			modifier.linked_modifier.modifier_name,
			modifier.linked_modifier.get_description(),
		]


## The small print, in the order it matters: how likely, how long, how it stacks.
func _meta_text(entry: WorkshopEntry) -> String:
	var modifier: Modifier = entry.modifier
	var parts: Array[String] = []

	if modifier.chance < 1.0:
		parts.append("%d%%" % roundi(modifier.chance * 100.0))

	match modifier.duration:
		Modifier.Duration.LEVELS:
			var levels: int = modifier.duration_levels
			parts.append("%d LEVEL%s" % [levels, "" if levels == 1 else "S"])
		Modifier.Duration.SECONDS:
			parts.append("%dS" % roundi(modifier.duration_seconds))

	if modifier.stackable:
		parts.append("STACKS")

	return "  ·  ".join(parts)


func _clear_detail() -> void:
	detail_name.text = ""
	detail_meta.text = ""
	detail_body.text = "Pick something up to read it."
	detail_cost.visible = false


func _show_empty_bench() -> void:
	_refresh_header()
	detail_name.text = "Nothing on the bench"
	detail_meta.text = ""
	detail_body.text = "You already have everything this workshop had to offer."
	detail_cost.visible = false


# --- Helpers -----------------------------------------------------------------
## Focus is what lights a card, so after every change to the bench something has
## to be holding it — otherwise a keyboard player is left with no cursor.
func _focus_first_available() -> void:
	for card: WorkshopCard in _cards:
		if not card.taken and not card.disabled:
			card.grab_focus()
			return

	leave_button.grab_focus()


## How far into the run this bench is. Entries use it to hold themselves back
## until the run has earned them (see [WorkshopEntry.min_depth]).
func _depth() -> int:
	if Global.main_game == null or Global.main_game.map == null:
		return 0

	return Global.main_game.map.progress


func _wait(seconds: float) -> void:
	await get_tree().create_timer(maxf(seconds, 0.0)).timeout


func _resolve_modifiers_system() -> ModifiersSystem:
	if Global.main_game == null or Global.main_game.modifiers_system == null:
		push_error("Workshop: ModifiersSystem not found.")
		return null

	return Global.main_game.modifiers_system


func _resolve_time_system() -> TimeSystem:
	if Global.main_game == null or Global.main_game.time_system == null:
		push_error("Workshop: TimeSystem not found.")
		return null

	return Global.main_game.time_system

# Callbacks
func _on_card_highlighted(card: WorkshopCard) -> void:
	_show_detail(card.entry)


func _on_card_chosen(card: WorkshopCard) -> void:
	if _busy or _closing or card.taken or _picks_remaining <= 0:
		return
	if _modifiers_system == null:
		return

	_busy = true
	_picks_remaining -= 1
	_picks_taken += 1
	_refresh_header()
	_refresh_footer()

	# Banked before the animation, not after: whatever else happens, the player
	# pressed the button and the modifier is theirs.
	_modifiers_system.add_modifier(card.entry.modifier)

	await card.play_taken()

	if _picks_remaining <= 0:
		_close()
		return

	_busy = false
	_refresh_footer()
	_focus_first_available()


func _on_reroll_pressed() -> void:
	if _busy or _closing or _rerolls_remaining <= 0:
		return

	_busy = true
	_rerolls_remaining -= 1
	_refresh_footer()

	await _sweep_cards()
	await _lay_out_bench()

	_refresh_header()
	_refresh_footer()


func _on_leave_pressed() -> void:
	if _busy or _closing:
		return

	_close()
