class_name ShopLevel
extends BaseLevel
## The shop room: a small platforming level with item pedestals and a
## one-deal-per-visit time exchange (buy seconds with coins OR sell seconds
## for coins — using either closes both).

## Small gift of seconds for visiting — makes shop detours less punishing.
const ENTRY_BONUS_SECONDS: float = 10.0

@onready var player_spawn: PlayerSpawn = %PlayerSpawn
@onready var level_exit: LevelExit = %LevelExit
@onready var relic_pedestals: Node2D = %RelicPedestals
@onready var item_pedestals: Node2D = %ItemPedestals
@onready var buy_time_pedestal: ShopPedestal = %BuyTimePedestal
@onready var sell_time_pedestal: ShopPedestal = %SellTimePedestal
@onready var speech_bubble: PanelContainer = %SpeechBubble
@onready var speech_label: Label = %SpeechLabel
@onready var purchase_card: PanelContainer = %PurchaseCard
@onready var card_name_label: Label = %CardNameLabel
@onready var card_description_label: Label = %CardDescriptionLabel
@onready var card_effect_label: Label = %CardEffectLabel

var _exchange_used: bool = false
var _card_open: bool = false
## Pedestals the player currently overlaps, in entry order. The last entry is
## the active one — a plain "current pedestal" variable desyncs when detection
## zones are entered before the previous one is exited.
var _focus_stack: Array[ShopPedestal] = []


## The pedestal the player is actively standing at (null if none).
func _focused_pedestal() -> ShopPedestal:
	return null if _focus_stack.is_empty() else _focus_stack.back()


func _ready() -> void:
	assert(player_spawn != null, "Level is missing a PlayerSpawn node.")
	assert(level_exit != null, "Level is missing a LevelExit node.")
	level_exit.reached_exit.connect(_on_exit_reached)

	RunState.add_time(ENTRY_BONUS_SECONDS)

	var relics: Array[ShopItem] = ShopCatalog.random_relics(relic_pedestals.get_child_count())
	var consumables: Array[ShopItem] = ShopCatalog.random_consumables(item_pedestals.get_child_count())
	var all_stock: Array[ShopItem] = relics + consumables
	if all_stock.size() > 0:
		all_stock.pick_random().on_sale = true

	_stock_pedestals(relic_pedestals, relics)
	_stock_pedestals(item_pedestals, consumables)

	buy_time_pedestal.set_item(ShopCatalog.time_buy_offer())
	sell_time_pedestal.set_item(ShopCatalog.time_sell_offer())
	buy_time_pedestal.focus_changed.connect(_on_pedestal_focus_changed)
	sell_time_pedestal.focus_changed.connect(_on_pedestal_focus_changed)

	speech_bubble.hide()
	purchase_card.hide()


## The shop owns the interact press: dismiss the purchase card if one is open,
## otherwise buy at the pedestal the player is standing at.
func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"interact"):
		return
	if _card_open:
		get_viewport().set_input_as_handled()
		_close_purchase_card()
	elif _focused_pedestal() != null:
		get_viewport().set_input_as_handled()
		_try_purchase(_focused_pedestal())


func _stock_pedestals(container: Node2D, stock: Array[ShopItem]) -> void:
	var pedestals: Array[Node] = container.get_children()
	for i: int in pedestals.size():
		var pedestal: ShopPedestal = pedestals[i]
		if i < stock.size():
			pedestal.set_item(stock[i])
		else:
			pedestal.set_locked("EMPTY")
		pedestal.focus_changed.connect(_on_pedestal_focus_changed)


func get_default_player_spawn() -> Vector2:
	return player_spawn.global_position


## The Chrono Anchor relic freezes the countdown while browsing shops.
func should_tick_time() -> bool:
	return not RunState.has_relic(&"chrono_anchor")


func _on_exit_reached() -> void:
	Global.main_game.exit_room()


func _try_purchase(pedestal: ShopPedestal) -> void:
	if _card_open or pedestal.sold or pedestal.locked:
		return
	var item: ShopItem = pedestal.item
	var is_exchange: bool = item.kind == ShopItem.Kind.TIME_BUY or item.kind == ShopItem.Kind.TIME_SELL
	if is_exchange and _exchange_used:
		return

	var paid: bool
	if item.currency == ShopItem.Currency.COINS:
		paid = RunState.try_spend_coins(item.final_price())
	else:
		paid = RunState.try_spend_time(item.final_price())
	if not paid:
		_say("Not enough %s, friend!" % ("coins" if item.currency == ShopItem.Currency.COINS else "seconds"))
		return

	match item.kind:
		ShopItem.Kind.RELIC:
			RunState.add_relic(item.id)
		ShopItem.Kind.CONSUMABLE:
			RunState.add_consumable(item.id)
		ShopItem.Kind.TIME_BUY:
			RunState.add_time(item.effect_value)
		ShopItem.Kind.TIME_SELL:
			RunState.add_coins(item.effect_value)

	pedestal.mark_sold()

	if is_exchange:
		_exchange_used = true
		var other: ShopPedestal = sell_time_pedestal if pedestal == buy_time_pedestal else buy_time_pedestal
		other.set_locked("CLOSED")

	_show_purchase_card(item)


## The purchase moment: the countdown pauses and the player freezes so they
## can actually read what they bought. Dismissed with the interact action
## (see _unhandled_input).
func _show_purchase_card(item: ShopItem) -> void:
	_card_open = true
	RunState.set_ticking(false)
	if Global.main_game != null:
		Global.main_game.set_player_frozen(true)
	card_name_label.text = item.display_name
	card_description_label.text = item.description
	card_effect_label.text = _effect_text(item)
	purchase_card.show()
	_say("Pleasure doing business!")


func _close_purchase_card() -> void:
	_card_open = false
	purchase_card.hide()
	if Global.main_game != null:
		Global.main_game.set_player_frozen(false)
	RunState.set_ticking(should_tick_time())


func _effect_text(item: ShopItem) -> String:
	match item.kind:
		ShopItem.Kind.RELIC:
			return "Relic added to your collection."
		ShopItem.Kind.CONSUMABLE:
			return "Consumable added to your pack."
		ShopItem.Kind.TIME_BUY:
			return "+%d seconds on the countdown!" % item.effect_value
		ShopItem.Kind.TIME_SELL:
			return "+%d coins!" % item.effect_value
	return ""


func _on_pedestal_focus_changed(pedestal: ShopPedestal, focused: bool) -> void:
	_focus_stack.erase(pedestal)
	if focused:
		_focus_stack.append(pedestal)
	var current: ShopPedestal = _focused_pedestal()
	if current != null:
		_say(_pitch_for(current))
	else:
		speech_bubble.hide()


func _pitch_for(pedestal: ShopPedestal) -> String:
	if pedestal.sold:
		return "That one's gone. Fine choice, though!"
	if pedestal.locked:
		if pedestal.item != null and (pedestal.item.kind == ShopItem.Kind.TIME_BUY
				or pedestal.item.kind == ShopItem.Kind.TIME_SELL):
			return "One time deal per visit, friend. No exceptions."
		return "Nothing on that stand today."
	var item: ShopItem = pedestal.item
	var price_words: String = "%d %s" % [item.final_price(),
			"coins" if item.currency == ShopItem.Currency.COINS else "seconds"]
	var pitch: String = "%s! %s That'll be %s." % [item.display_name, item.description, price_words]
	if item.on_sale:
		pitch += " Half off, today only!"
	return pitch


func _say(text: String) -> void:
	speech_label.text = text
	speech_bubble.show()
