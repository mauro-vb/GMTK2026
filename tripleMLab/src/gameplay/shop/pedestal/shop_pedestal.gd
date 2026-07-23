class_name ShopPedestal
extends Area2D
## One item stand in the shop. This node is purely a VIEW:
##  - shows the item icon (color-coded by kind), a price tag, and a context
##    prompt ("UP: buy" / "Can't afford" / "SOLD") while the player is in range
##  - reports the player standing at it via `focus_changed`
## It never handles input or money — all purchase logic lives in ShopLevel,
## so there is exactly one place where buying can happen.

signal focus_changed(pedestal: ShopPedestal, focused: bool)

const KIND_COLORS: Dictionary[ShopItem.Kind, Color] = {
	ShopItem.Kind.RELIC: Color(0.72, 0.45, 0.95),
	ShopItem.Kind.CONSUMABLE: Color(0.45, 0.9, 0.5),
	ShopItem.Kind.TIME_BUY: Color(0.4, 0.85, 0.95),
	ShopItem.Kind.TIME_SELL: Color(0.95, 0.65, 0.35),
}
const COLOR_AFFORDABLE: Color = Color(1.0, 0.9, 0.55)
const COLOR_UNAFFORDABLE: Color = Color(0.9, 0.3, 0.3)
const COLOR_INACTIVE: Color = Color(0.55, 0.55, 0.55)

var item: ShopItem = null
var sold: bool = false
var locked: bool = false

var _player_in_range: bool = false
var _base_icon_color: Color = Color.WHITE
var _locked_reason: String = ""

@onready var icon: Polygon2D = %Icon
@onready var price_label: Label = %PriceLabel
@onready var prompt_label: Label = %PromptLabel


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	# Live affordability feedback: price tags react to every coin/second change.
	RunState.coins_changed.connect(func(_c: int) -> void: _refresh())
	RunState.time_changed.connect(func(_t: float) -> void: _refresh())
	prompt_label.hide()
	_refresh()


func set_item(new_item: ShopItem) -> void:
	item = new_item
	if not is_node_ready():
		await ready
	_base_icon_color = KIND_COLORS.get(item.kind, Color.WHITE)
	_refresh()


func mark_sold() -> void:
	sold = true
	_refresh()


## Disables the pedestal without a purchase (empty stand, or the other half of
## the one-deal-per-visit time exchange).
func set_locked(reason: String) -> void:
	locked = true
	_locked_reason = reason
	_refresh()


func can_afford() -> bool:
	if item == null:
		return false
	if item.currency == ShopItem.Currency.COINS:
		return RunState.can_spend_coins(item.final_price())
	return RunState.can_spend_time(item.final_price())


func _refresh() -> void:
	if sold:
		icon.color = _base_icon_color.darkened(0.6)
		price_label.text = "SOLD"
		price_label.modulate = COLOR_INACTIVE
		prompt_label.text = "SOLD"
	elif locked:
		icon.color = _base_icon_color.darkened(0.6)
		price_label.text = _locked_reason
		price_label.modulate = COLOR_INACTIVE
		prompt_label.text = _locked_reason
	elif item != null:
		icon.color = _base_icon_color
		price_label.text = item.price_text()
		price_label.modulate = COLOR_AFFORDABLE if can_afford() else COLOR_UNAFFORDABLE
		prompt_label.text = "UP: buy" if can_afford() else "Can't afford"
	prompt_label.modulate = price_label.modulate


func _on_body_entered(_body: Node2D) -> void:
	_player_in_range = true
	prompt_label.show()
	_refresh()
	focus_changed.emit(self, true)


func _on_body_exited(_body: Node2D) -> void:
	_player_in_range = false
	prompt_label.hide()
	focus_changed.emit(self, false)
