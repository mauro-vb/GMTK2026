extends Node
## Throwaway diagnostic: stand the player at every pedestal in the shop and
## report whether it focuses and the speech bubble shows.
## Run: godot --headless res://src/debug/PedestalProbe.tscn

const PLAYER_SCENE_UID: String = "uid://kwjq37d8yab5"
const SHOP_LEVEL_SCENE: String = "res://src/levels/shop/ShopLevel.tscn"


func _ready() -> void:
	RunState.start_run()
	var shop: ShopLevel = (load(SHOP_LEVEL_SCENE) as PackedScene).instantiate()
	add_child(shop)
	var player: Player = (load(PLAYER_SCENE_UID) as PackedScene).instantiate()
	add_child(player)
	await get_tree().process_frame

	var pedestals: Array[Node] = []
	pedestals.append_array(shop.relic_pedestals.get_children())
	pedestals.append_array(shop.item_pedestals.get_children())
	pedestals.append(shop.buy_time_pedestal)
	pedestals.append(shop.sell_time_pedestal)

	for pedestal: ShopPedestal in pedestals:
		# Park the player away first so exit/enter ordering matches real play.
		player.global_position = Vector2(-500, -500)
		player.velocity = Vector2.ZERO
		for i: int in 4:
			await get_tree().physics_frame
		# Stand slightly beside the stand, the way a player naturally stops so
		# their character doesn't cover the item.
		player.global_position = pedestal.global_position + Vector2(-28, -20)
		player.velocity = Vector2.ZERO
		for i: int in 4:
			await get_tree().physics_frame
		var item_desc: String = "EMPTY/locked" if pedestal.item == null else str(pedestal.item.id)
		# The bubble grows upward from a pinned bottom edge, so the tail must sit
		# at the same world-space anchor above the shopkeeper for every pitch.
		var tail_at_bottom: bool = (
			shop.speech_tail.global_position.distance_to(Vector2(320, 264)) < 0.5
		)
		print("%s | item=%s | focused=%s | bubble=%s | tail_at_bottom=%s | text='%s'" % [
			pedestal.name,
			item_desc,
			shop._focused_pedestal() == pedestal,
			shop.speech_bubble.visible,
			tail_at_bottom,
			shop.speech_label.text,
		])

	get_tree().quit(0)
