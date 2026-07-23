class_name ShopItem
extends Resource
## Data for a single purchasable shop entry.
## Effects are identified by `id` only — the systems that implement relic /
## consumable behavior match on it (e.g. RunState.has_relic(&"chrono_anchor")).

enum Kind { RELIC, CONSUMABLE, TIME_BUY, TIME_SELL }
enum Currency { COINS, SECONDS }

const SALE_MULTIPLIER: float = 0.5

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export var kind: Kind = Kind.RELIC
@export var currency: Currency = Currency.COINS
@export var price: int = 10
## What the purchase grants: seconds for TIME_BUY, coins for TIME_SELL.
## Unused for RELIC / CONSUMABLE (the id carries the effect).
@export var effect_value: int = 0
@export var on_sale: bool = false


static func make(p_id: StringName, p_name: String, p_description: String, p_kind: Kind,
		p_currency: Currency, p_price: int, p_effect_value: int = 0) -> ShopItem:
	var item: ShopItem = ShopItem.new()
	item.id = p_id
	item.display_name = p_name
	item.description = p_description
	item.kind = p_kind
	item.currency = p_currency
	item.price = p_price
	item.effect_value = p_effect_value
	return item


func final_price() -> int:
	if on_sale:
		return maxi(1, roundi(price * SALE_MULTIPLIER))
	return price


func price_text() -> String:
	var suffix: String = "c" if currency == Currency.COINS else "s"
	if on_sale:
		return "SALE %d%s" % [final_price(), suffix]
	return "%d%s" % [final_price(), suffix]
