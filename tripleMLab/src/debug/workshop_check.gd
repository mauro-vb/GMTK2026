extends Node
## Headless sanity check for the workshop:
##     godot --headless res://src/debug/WorkshopCheck.tscn
##
## Runs as a scene rather than via `--script` on purpose: autoloads only exist
## for a scene run, and half of this touches Global.
##
## Two halves. The first loads every workshop resource and exercises the draw and
## the modifier hooks in isolation. The second boots the real MainGame, walks
## into a real workshop with real perks equipped, takes cards, and checks the run
## came out the other side changed in the way the cards said it would.
##
## Not a test framework — it prints what it found and quits non-zero if something
## is wrong, which is enough to catch a broken uid or a bad .tres before it
## reaches a playtest.

const MAIN_SCENE_UID: String = "uid://ccxuyq6o8k8ca"

var _failures: int = 0
## A member, not a local: GDScript lambdas capture locals by value, so a flag
## set inside a signal handler would never be seen out here.
var _bench_closed: bool = false


func _ready() -> void:
	_check_resources()
	await _check_live_workshop()
	_finish()


# --- Resources ---------------------------------------------------------------
func _check_resources() -> void:
	print("\n[ pool ]")
	var pool: WorkshopPool = load(UIDs.WORKSHOP_DEFAULT_POOL_UID) as WorkshopPool
	if not _check(pool != null, "default_pool.tres loads as a WorkshopPool"):
		return

	_check(not pool.entries.is_empty(), "pool has entries (%d)" % pool.entries.size())
	_check_entries(pool)
	_check(load(UIDs.WORKSHOP_SCENE_UID) is PackedScene, "Workshop.tscn loads")
	_check(load(UIDs.WORKSHOP_CARD_SCENE_UID) is PackedScene, "WorkshopCard.tscn loads")

	print("\n[ draw ]")
	_check_draw(pool)

	print("\n[ hooks ]")
	_check_hooks()

	print("\n[ overlapping clock modifiers ]")
	_check_rate_contributions()

	print("\n[ dead picks ]")
	_check_dead_picks(pool)


## "Primed" refunds an ability's time cost, and abilities are free until
## something prices them — so on a run with nothing priced it is a card that does
## nothing at all. A bench must not offer it there.
func _check_dead_picks(pool: WorkshopPool) -> void:
	var primed: Modifier = load(UIDs.PRIMED_UID) as Modifier
	var costly_dash: Modifier = load(UIDs.COSTLY_DASH_UID) as Modifier

	var bare: ModifiersSystem = ModifiersSystem.new()
	_check(not primed.is_useful(bare), "Primed is useless on a run with nothing priced")
	_check(not _pool_can_offer(pool, primed.id, bare), "...so the bench won't lay it out")

	# Kick Start is what normally brings Costly Dash along; adding the price
	# directly is the same thing without needing a level to trigger in.
	bare.modifiers.append(costly_dash)
	_check(primed.is_useful(bare), "pricing an ability makes Primed useful")
	_check(_pool_can_offer(pool, primed.id, bare), "...and the bench will offer it again")

	# The escape hatch: with nobody to ask, a card is not hidden.
	_check(primed.is_useful(null), "with no system to ask, nothing is hidden")

	# Everything else is unconditional and must be unaffected by any of this.
	var plain: Modifier = load(UIDs.SPARE_FUSE_UID) as Modifier
	_check(plain.is_useful(bare) and plain.is_useful(null),
		"an ordinary modifier is always useful")

	bare.free()


## Whether `id` survives the pool's availability filter for this run. Checked at
## a depth past every gate so only usefulness can be the reason it's missing.
func _pool_can_offer(pool: WorkshopPool, id: String, modifiers_system: ModifiersSystem) -> bool:
	for entry: WorkshopEntry in pool.entries:
		if entry != null and entry.modifier != null and entry.modifier.id == id:
			return entry.is_available(99, modifiers_system)

	return false


## Regression guard. Modifiers used to save and restore TimeSystem.tick_rate
## around themselves, which broke the moment two overlapped: a freeze (rate 0)
## running under a slow-burn meant the slow-burn had snapshotted 0, and putting
## that back when it expired killed the clock for the rest of the run.
##
## Combined cards made that pairing common — Frost Grip carries a freeze, and
## several cards carry tick-rate drawbacks — so it is worth a standing check.
func _check_rate_contributions() -> void:
	var clock: TimeSystem = TimeSystem.new()

	clock.set_rate_contribution(&"slow_burn", 0.5)
	_check(is_equal_approx(clock.tick_rate, 0.5), "one contribution sets the rate")

	clock.set_rate_contribution(&"freeze", 0.0)
	_check(is_zero_approx(clock.tick_rate), "a freeze on top of it stops the clock")

	clock.clear_rate_contribution(&"freeze")
	_check(is_equal_approx(clock.tick_rate, 0.5), "thawing gives the slow-burn back, not 1.0")

	clock.set_rate_contribution(&"double_time", 2.0)
	_check(is_equal_approx(clock.tick_rate, 1.0), "contributions multiply (0.5 x 2.0)")

	# Dropped in the order they were added, which is the order that used to break.
	clock.clear_rate_contribution(&"slow_burn")
	_check(is_equal_approx(clock.tick_rate, 2.0), "dropping the older one leaves the newer")

	clock.clear_rate_contribution(&"double_time")
	_check(is_equal_approx(clock.tick_rate, 1.0), "the clock comes back to normal, never 0")

	clock.clear_rate_contribution(&"never_registered")
	_check(is_equal_approx(clock.tick_rate, 1.0), "clearing an unknown key is a no-op")

	clock.free()


func _check_entries(pool: WorkshopPool) -> void:
	var seen: Dictionary[String, bool] = {}
	var broken: int = 0
	for index: int in pool.entries.size():
		var entry: WorkshopEntry = pool.entries[index]
		if entry == null or entry.modifier == null:
			broken += 1
			continue
		if entry.modifier.modifier_name.is_empty() or entry.modifier.id.is_empty():
			broken += 1
			continue
		if seen.has(entry.modifier.id):
			broken += 1
			continue
		seen[entry.modifier.id] = true

	_check(broken == 0, "every entry resolves a named, uniquely-ided modifier")
	_check_combined(pool)


## The invariant that makes combined cards safe to author: a drawback is only
## ever reachable as the second half of something else. If one ever leaks into
## the pool as its own entry, the workshop would offer the player a pure penalty.
func _check_combined(pool: WorkshopPool) -> void:
	var offered: Dictionary[String, bool] = {}
	for entry: WorkshopEntry in pool.entries:
		if entry != null and entry.modifier != null:
			offered[entry.modifier.id] = true

	var combined: int = 0
	var leaked: Array[String] = []
	for entry: WorkshopEntry in pool.entries:
		if entry == null or entry.modifier == null:
			continue
		if not entry.is_combined():
			continue

		combined += 1
		var drawback: Modifier = entry.modifier.linked_modifier
		if offered.has(drawback.id):
			leaked.append(drawback.id)
		# The seam and the detail panel both print this, so it has to be there.
		if drawback.modifier_name.is_empty() or drawback.get_description().is_empty():
			leaked.append(entry.modifier.id)

	_check(combined > 0, "the pool offers combined cards (%d of %d)" % [combined, pool.entries.size()])
	_check(leaked.is_empty(), "no drawback is offered on its own %s" % ("" if leaked.is_empty() else leaked))
	_check(combined < pool.entries.size(), "and not every card is combined")


## The draw is the part with real logic in it: weighted, without replacement, and
## depth-gated. Checked at both ends of a run.
func _check_draw(pool: WorkshopPool) -> void:
	for depth: int in [0, 4, 8]:
		var drawn: Array[WorkshopEntry] = pool.draw(3, depth, null)
		_check(drawn.size() == 3, "depth %d draws 3 offers (got %d)" % [depth, drawn.size()])

		var unique: Dictionary[String, bool] = {}
		var too_deep: int = 0
		for entry: WorkshopEntry in drawn:
			unique[entry.modifier.id] = true
			if entry.min_depth > depth:
				too_deep += 1

		_check(unique.size() == drawn.size(), "depth %d draws no duplicates" % depth)
		_check(too_deep == 0, "depth %d offers nothing gated deeper" % depth)

	_check(pool.draw(0, 0, null).is_empty(), "a zero-card draw is empty, not an error")


## Each workshop perk is asked the question the workshop would ask it.
func _check_hooks() -> void:
	var second_hands: Modifier = load(UIDs.SECOND_SET_OF_HANDS_UID) as Modifier
	_check(second_hands.modify_workshop_picks(1) == 2, "Second Set of Hands turns 1 pick into 2")
	_check(second_hands.on_workshop_visited(1), "Second Set of Hands is spent after a pick")
	_check(not second_hands.on_workshop_visited(0), "Second Set of Hands keeps if nothing was taken")

	_check((load(UIDs.OPEN_BENCH_UID) as Modifier).modify_workshop_offers(3) == 5,
		"Open Bench turns 3 offers into 5")
	_check((load(UIDs.CLUTTERED_BENCH_UID) as Modifier).modify_workshop_offers(3) == 2,
		"Cluttered Bench turns 3 offers into 2")
	_check((load(UIDs.SCRAP_HEAP_UID) as Modifier).modify_workshop_rerolls(0) == 1,
		"Scrap Heap grants a sweep")
	_check(is_equal_approx((load(UIDs.UNION_BREAK_UID) as Modifier).modify_workshop_skip_bonus(0.0), 8.0),
		"Union Break pays 8 seconds for walking away")

	var blueprints: Modifier = load(UIDs.BLUEPRINTS_UID) as Modifier
	_check(blueprints.modify_workshop_offer_weight(1.0, false) > 1.0
		and blueprints.modify_workshop_offer_weight(1.0, true) < 1.0,
		"Blueprints tilts the bench toward cards with no catch")
	_check(blueprints.linked_modifier != null, "Blueprints drags its trade-off along")

	var danger_money: Modifier = load(UIDs.DANGER_MONEY_UID) as Modifier
	_check(danger_money.modify_workshop_offer_weight(1.0, true) > 1.0
		and danger_money.modify_workshop_offer_weight(1.0, false) < 1.0,
		"Danger Money tilts it the other way")

	# The whole point of putting the hooks on Modifier is that everything else
	# inherits a "changes nothing" answer for free.
	var plain: Modifier = load(UIDs.SPARE_FUSE_UID) as Modifier
	_check(plain.modify_workshop_offers(3) == 3 and plain.modify_workshop_picks(1) == 1,
		"a non-workshop modifier changes nothing about a bench")
	_check(is_equal_approx(plain.modify_workshop_offer_weight(1.0, true), 1.0),
		"...including the draw")


# --- The real thing ----------------------------------------------------------
## Boots MainGame, equips two workshop perks, and walks into a workshop.
func _check_live_workshop() -> void:
	print("\n[ live workshop ]")

	var main_scene: PackedScene = load(MAIN_SCENE_UID) as PackedScene
	if not _check(main_scene != null, "main scene loads"):
		return

	add_child(main_scene.instantiate())
	await get_tree().process_frame

	var game: MainGame = Global.main_game
	if not _check(game != null, "MainGame registered itself with Global"):
		return

	game.load_game()
	var modifiers: ModifiersSystem = game.modifiers_system
	if not _check(modifiers != null, "the run has a ModifiersSystem"):
		return

	# Equipped before the bench is laid out, which is the only time the terms
	# are read.
	modifiers.add_modifier(load(UIDs.OPEN_BENCH_UID))
	modifiers.add_modifier(load(UIDs.SECOND_SET_OF_HANDS_UID))
	_check(modifiers.get_workshop_offers(Workshop.BASE_OFFERS) == 5, "the run now offers 5")
	_check(modifiers.get_workshop_picks(Workshop.BASE_PICKS) == 2, "the run now picks 2")

	game.enter_room(UIDs.WORKSHOP_SCENE_UID, Room.Type.WORKSHOP)
	var workshop: Workshop = game.get("_current_room") as Workshop
	if not _check(workshop != null, "entering a WORKSHOP room loads a Workshop"):
		return

	_check(not workshop.should_tick_time, "the clock is off while the bench is open")

	# Long enough for the backdrop fade and the full staggered deal.
	await get_tree().create_timer(1.5).timeout

	var cards: Array = workshop.get("_cards")
	_check(cards.size() == 5, "the bench laid out 5 cards (got %d)" % cards.size())
	_check(workshop.get("_picks_remaining") == 2, "two picks are on the table")

	var held_before: int = modifiers.modifiers.size()
	var first: WorkshopCard = cards[0]
	var first_id: String = first.entry.modifier.id
	workshop._on_card_chosen(first)
	await get_tree().create_timer(0.8).timeout

	_check(modifiers.has_modifier(first_id), "taking a card grants '%s'" % first_id)
	_check(first.taken, "the taken card is stamped")
	_check(workshop.get("_picks_remaining") == 1, "one pick is left")
	_check(is_instance_valid(workshop), "the bench stays open on the first of two picks")

	workshop.exited.connect(_on_bench_closed)

	var second: WorkshopCard = cards[1]
	var second_id: String = second.entry.modifier.id
	workshop._on_card_chosen(second)
	await get_tree().create_timer(1.5).timeout

	_check(modifiers.has_modifier(second_id), "the second pick grants '%s'" % second_id)
	_check(_bench_closed, "spending the last pick closes the bench")
	_check(not modifiers.has_modifier("second_set_of_hands"), "Second Set of Hands was spent")
	_check(modifiers.has_modifier("open_bench"), "Open Bench is permanent and stayed")
	# Two picks, minus the spent one-shot, plus anything a linked trade-off
	# dragged in — so the count has to have moved, and upward.
	_check(modifiers.modifiers.size() > held_before - 1, "the run came out of the bench richer")

	await _check_sweep_and_leave(game, modifiers)
	await _check_combined_pick(game, modifiers)


## Taking a combined card has to land *both* halves — that is the whole promise
## the card's seam makes.
func _check_combined_pick(game: MainGame, modifiers: ModifiersSystem) -> void:
	print("\n[ taking a combined card ]")

	# Danger Money makes the bench overwhelmingly two-edged, so a combined card
	# is almost certainly on it; the loop below still copes if one isn't.
	modifiers.add_modifier(load(UIDs.DANGER_MONEY_UID))
	game.enter_room(UIDs.WORKSHOP_SCENE_UID, Room.Type.WORKSHOP)
	var workshop: Workshop = game.get("_current_room") as Workshop
	if not _check(workshop != null, "a third workshop opens"):
		return

	await get_tree().create_timer(1.5).timeout

	var target: WorkshopCard = null
	for card: WorkshopCard in workshop.get("_cards"):
		if card.entry.is_combined():
			target = card
			break

	if not _check(target != null, "Danger Money put a combined card on the bench"):
		return

	var bonus: Modifier = target.entry.modifier
	var drawback: Modifier = bonus.linked_modifier
	_check(target.seam.visible, "the combined card wears its seam")
	_check(target.seam_label.text == drawback.modifier_name.to_upper(),
		"the seam names the drawback ('%s')" % target.seam_label.text)

	workshop._on_card_chosen(target)
	await get_tree().create_timer(1.2).timeout

	_check(modifiers.has_modifier(bonus.id), "the bonus half landed ('%s')" % bonus.id)
	_check(modifiers.has_modifier(drawback.id), "the drawback half landed too ('%s')" % drawback.id)


## Second visit, with the other two perks on: sweeping the bench, and walking out
## of it empty-handed for the money.
func _check_sweep_and_leave(game: MainGame, modifiers: ModifiersSystem) -> void:
	print("\n[ sweep and leave ]")

	modifiers.add_modifier(load(UIDs.SCRAP_HEAP_UID))
	modifiers.add_modifier(load(UIDs.UNION_BREAK_UID))

	var time_system: TimeSystem = game.time_system
	# The skip bonus tops the clock up, so it has to have room to move — at full
	# it would clamp and the payout would be invisible.
	time_system.current_time = 30.0

	game.enter_room(UIDs.WORKSHOP_SCENE_UID, Room.Type.WORKSHOP)
	var workshop: Workshop = game.get("_current_room") as Workshop
	if not _check(workshop != null, "a second workshop opens"):
		return

	await get_tree().create_timer(1.5).timeout
	_check(workshop.get("_rerolls_remaining") == 1, "Scrap Heap put a sweep on the table")

	var before: Array[String] = _card_ids(workshop)
	workshop._on_reroll_pressed()
	await get_tree().create_timer(1.5).timeout

	var after: Array[String] = _card_ids(workshop)
	_check(not after.is_empty(), "sweeping lays out a fresh bench (%d cards)" % after.size())
	_check(after != before, "the fresh bench is not the same bench")
	_check(workshop.get("_rerolls_remaining") == 0, "the sweep was spent")

	_bench_closed = false
	workshop.exited.connect(_on_bench_closed)

	var clock_before: float = time_system.current_time
	workshop._on_leave_pressed()
	await get_tree().create_timer(1.5).timeout

	_check(_bench_closed, "leaving closes the bench")
	_check(is_equal_approx(time_system.current_time, clock_before + 8.0),
		"Union Break paid 8 seconds for the empty-handed exit (%.1f -> %.1f)" % [clock_before, time_system.current_time])


func _card_ids(workshop: Workshop) -> Array[String]:
	var ids: Array[String] = []
	for card: WorkshopCard in workshop.get("_cards"):
		ids.append(card.entry.modifier.id)

	return ids


# --- Plumbing ----------------------------------------------------------------
func _on_bench_closed() -> void:
	_bench_closed = true


func _check(condition: bool, label: String) -> bool:
	if condition:
		print("  ok   %s" % label)
	else:
		print("  FAIL %s" % label)
		_failures += 1

	return condition


func _finish() -> void:
	if _failures == 0:
		print("\nworkshop_check: all checks passed.")
	else:
		printerr("\nworkshop_check: %d check(s) failed." % _failures)

	get_tree().quit(0 if _failures == 0 else 1)
