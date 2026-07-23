class_name ShopCatalog
extends RefCounted
## Placeholder item pool and stock generation for shops.
## Replace the pools with designed .tres resources once the relic/consumable
## systems land — everything else (pedestals, purchase flow) stays the same.


static func random_relics(count: int) -> Array[ShopItem]:
	return _random_from(_relic_pool(), count)


static func random_consumables(count: int) -> Array[ShopItem]:
	return _random_from(_consumable_pool(), count)


static func _random_from(pool: Array[ShopItem], count: int) -> Array[ShopItem]:
	pool.shuffle()
	return pool.slice(0, count)


## The one-per-visit time exchange offers. Rates worsen with map progress
## later if we want (pass the row in and scale).
static func time_buy_offer() -> ShopItem:
	return ShopItem.make(&"time_buy", "Buy Time", "Gain 30 seconds on the countdown.",
			ShopItem.Kind.TIME_BUY, ShopItem.Currency.COINS, 40, 30)


static func time_sell_offer() -> ShopItem:
	return ShopItem.make(&"time_sell", "Sell Time", "Trade 20 seconds for 50 coins.",
			ShopItem.Kind.TIME_SELL, ShopItem.Currency.SECONDS, 20, 50)


static func _relic_pool() -> Array[ShopItem]:
	return [
		ShopItem.make(&"chrono_anchor", "Chrono Anchor",
				"Time stands still while you browse shops.",
				ShopItem.Kind.RELIC, ShopItem.Currency.COINS, 45),
		ShopItem.make(&"placeholder_relic_a", "Relic A",
				"Placeholder relic. Does nothing yet.",
				ShopItem.Kind.RELIC, ShopItem.Currency.COINS, 30),
		ShopItem.make(&"placeholder_relic_b", "Relic B",
				"Placeholder relic paid in seconds. Does nothing yet.",
				ShopItem.Kind.RELIC, ShopItem.Currency.SECONDS, 15),
		ShopItem.make(&"placeholder_relic_c", "Relic C",
				"Placeholder relic. Does nothing yet.",
				ShopItem.Kind.RELIC, ShopItem.Currency.COINS, 60),
	]


static func _consumable_pool() -> Array[ShopItem]:
	return [
		ShopItem.make(&"placeholder_consumable_a", "Consumable A",
				"Placeholder consumable. Does nothing yet.",
				ShopItem.Kind.CONSUMABLE, ShopItem.Currency.COINS, 15),
		ShopItem.make(&"placeholder_consumable_b", "Consumable B",
				"Placeholder consumable paid in seconds. Does nothing yet.",
				ShopItem.Kind.CONSUMABLE, ShopItem.Currency.SECONDS, 8),
		ShopItem.make(&"placeholder_consumable_c", "Consumable C",
				"Placeholder consumable. Does nothing yet.",
				ShopItem.Kind.CONSUMABLE, ShopItem.Currency.COINS, 20),
	]
