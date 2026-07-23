extends Node
## Headless smoke test for the shop system.
## Run: godot --headless res://src/debug/ShopSmokeTest.tscn
## Exits with code 0 when all checks pass, otherwise the number of failures.

const PLAYER_SCENE_UID: String = "uid://kwjq37d8yab5"
const SHOP_LEVEL_SCENE: String = "res://src/levels/shop/ShopLevel.tscn"

var _failures: int = 0


func _ready() -> void:
	await _run()
	print("SHOP SMOKE TEST: %s" % ("ALL PASS" if _failures == 0 else "%d FAILURES" % _failures))
	get_tree().quit(_failures)


func _check(condition: bool, what: String) -> void:
	if condition:
		print("  PASS: %s" % what)
	else:
		_failures += 1
		print("  FAIL: %s" % what)


func _run() -> void:
	RunState.start_run()
	var shop: ShopLevel = (load(SHOP_LEVEL_SCENE) as PackedScene).instantiate()
	add_child(shop)
	await get_tree().process_frame

	_check(is_equal_approx(RunState.time_remaining,
			RunState.STARTING_TIME_SECONDS + ShopLevel.ENTRY_BONUS_SECONDS),
			"entry bonus granted on shop enter")

	# --- Purchase logic: a seconds-priced item on sale ---
	var pedestal: ShopPedestal = shop.item_pedestals.get_child(0)
	var test_item: ShopItem = ShopItem.make(&"test_relic", "Test Relic", "Test.",
			ShopItem.Kind.RELIC, ShopItem.Currency.SECONDS, 15)
	test_item.on_sale = true
	pedestal.set_item(test_item)
	var time_before: float = RunState.time_remaining
	shop._try_purchase(pedestal)
	_check(pedestal.sold, "seconds-priced sale item can be bought")
	_check(is_equal_approx(RunState.time_remaining, time_before - 8.0), "sale price (8s of 15s) deducted")
	_check(RunState.has_relic(&"test_relic"), "relic lands in RunState")
	_check(shop._card_open, "purchase card opens")
	_check(not RunState.ticking, "countdown paused while card open")
	shop._close_purchase_card()
	_check(not shop._card_open, "card closes")

	# --- Time exchange: one deal per visit ---
	var coins_before: int = RunState.coins
	shop._try_purchase(shop.buy_time_pedestal)
	_check(shop.buy_time_pedestal.sold, "time buy works")
	_check(RunState.coins == coins_before - 40, "coins deducted for time buy")
	_check(shop.sell_time_pedestal.locked, "sell side locks after buying time")
	shop._close_purchase_card()
	var time_locked: float = RunState.time_remaining
	shop._try_purchase(shop.sell_time_pedestal)
	_check(not shop.sell_time_pedestal.sold and is_equal_approx(RunState.time_remaining, time_locked),
			"locked exchange refuses a second deal")

	# --- Input path: a real player stands at a pedestal and presses interact ---
	var player: Player = (load(PLAYER_SCENE_UID) as PackedScene).instantiate()
	add_child(player)
	var target: ShopPedestal = shop.item_pedestals.get_child(1)
	target.set_item(ShopItem.make(&"test_cheap", "Cheap Test Item", "Test.",
			ShopItem.Kind.CONSUMABLE, ShopItem.Currency.COINS, 5))
	RunState.add_coins(100)
	player.global_position = target.global_position + Vector2(0, -20)
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(shop._focused_pedestal() == target, "standing at a pedestal focuses it")

	_press_interact()
	_check(target.sold, "interact keypress buys the focused item")
	_check(shop._card_open, "keypress purchase opens the card")
	_press_interact()
	_check(not shop._card_open, "second keypress dismisses the card")
	_check(RunState.ticking == shop.should_tick_time(), "countdown resumes per level rules")


func _press_interact() -> void:
	var press: InputEventKey = InputEventKey.new()
	press.physical_keycode = KEY_UP
	press.pressed = true
	get_viewport().push_input(press)
	var release: InputEventKey = InputEventKey.new()
	release.physical_keycode = KEY_UP
	release.pressed = false
	get_viewport().push_input(release)
