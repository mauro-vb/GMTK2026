extends Node
## Headless sanity check for the treasure rooms:
##     godot --headless res://src/debug/TreasureCheck.tscn
##
## Runs as a scene rather than via `--script`, for the same reason
## [WorkshopCheck] does: autoloads only exist for a scene run and half of this
## touches Global.
##
## Three halves, really. The first loads every treasure resource and hammers the
## odds — a chest whose advertised percentages and actual draw disagree is the
## one bug in here that a playtest would never catch. The second checks the map
## deals the chest row out as three different chests. The third boots the real
## MainGame and plays all three minigames end to end, with charms equipped, and
## checks the clock came out the other side by exactly the amount the chest said.
##
## Not a test framework — it prints what it found and quits non-zero if something
## is wrong.

const MAIN_SCENE_UID: String = "uid://ccxuyq6o8k8ca"

## Rolls per table when checking that the advertised odds are the real ones.
## Big enough that a 3-percentage-point tolerance is not luck.
const ODDS_SAMPLES: int = 20000
const ODDS_TOLERANCE: float = 0.03

var _failures: int = 0
## A member, not a local: GDScript lambdas capture locals by value, so a flag set
## inside a signal handler would never be seen out here.
var _room_closed: bool = false


func _ready() -> void:
	# Awaited: the coin group tosses real coins and takes real seconds, and
	# without this the groups after it start printing over the top of it — and
	# _finish() could quit the run before it has finished tossing.
	await _check_resources()
	_check_map_deal()
	await _check_live_rooms()
	_finish()


# --- Resources ---------------------------------------------------------------
## The coin's one promise: **the face it comes down on and the outcome it pays
## always agree.** Called right pays the better outcome; called wrong pays the
## worse one; and the side facing up when it stops is the side that means.
##
## This is a regression guard, not a formality. The resting face used to be
## derived from where the spin stopped — and `11 * PI / PI` is 10.999999999999998
## in floating point, which floors to 10 and reads as the wrong face. Eleven
## half-turns is exactly the case where the coin must land on the opposite side
## from the one it started on, so *every* toss that should have come down tails
## came down heads, while still paying out for tails. It looked like the chest
## was handing out free seconds for a wrong call.
##
## All four combinations are forced rather than sampled: a random toss only
## catches this half the time, which is the sort of bug that ships.
func _check_coin() -> void:
	var table: TreasureTable = load(UIDs.TREASURE_EVEN_SPLIT_UID) as TreasureTable
	for called_heads: bool in [true, false]:
		for called_right: bool in [true, false]:
			await _check_toss(table, called_heads, called_right)


func _check_toss(table: TreasureTable, called_heads: bool, called_right: bool) -> void:
	# A deep copy, so weighting one outcome out of the draw can't reach back into
	# the real table's slices — they are shared resources.
	var forced: TreasureTable = table.duplicate(true)
	var wanted: TreasureSlice = forced.best_slice() if called_right else forced.worst_slice()
	for slice: TreasureSlice in forced.slices:
		slice.weight = 1.0 if slice == wanted else 0.0

	var coin: CoinFlipGame = (load(UIDs.TREASURE_COIN_GAME_UID) as PackedScene).instantiate()
	coin.setup(forced)
	add_child(coin)

	var paid: Array[TreasureSlice] = []
	coin.resolved.connect(func(slice: TreasureSlice) -> void: paid.append(slice))

	coin._on_side_called(called_heads)
	await get_tree().create_timer(2.0).timeout

	var call_text: String = "heads" if called_heads else "tails"
	if not _check(paid.size() == 1, "calling %s resolves once" % call_text):
		coin.queue_free()
		return

	var landed_heads: bool = coin.get("_showing_heads")
	var was_right: bool = paid[0] == forced.best_slice()
	_check(was_right == called_right, "calling %s and being %s pays %s" % [
		call_text, "right" if called_right else "wrong", paid[0].get_label()])
	_check(landed_heads == (called_heads == was_right),
		"...and it comes down %s, which is what being %s means" % [
			"heads" if landed_heads else "tails", "right" if was_right else "wrong"])

	coin.queue_free()


func _check_resources() -> void:
	print("\n[ tables ]")
	var treasure_set: TreasureSet = load(UIDs.TREASURE_SET_UID) as TreasureSet
	if not _check(treasure_set != null, "treasure_set.tres loads as a TreasureSet"):
		return

	_check(treasure_set.tables.size() == 3, "the set holds three chests (%d)" % treasure_set.tables.size())

	var names: Dictionary[String, bool] = {}
	for table: TreasureTable in treasure_set.tables:
		if table == null:
			_check(false, "a chest in the set is null")
			continue

		_check(table.is_valid(), "'%s' is a valid table" % table.table_name)
		_check(not names.has(table.table_name), "'%s' is named uniquely" % table.table_name)
		names[table.table_name] = true
		_check(table.games != 0, "'%s' allows at least one game" % table.table_name)
		_check(table.best_slice().seconds > 0.0 and table.worst_slice().seconds < 0.0,
			"'%s' can both pay and bite" % table.table_name)

	print("\n[ scenes ]")
	_check(load(UIDs.TREASURE_ROOM_SCENE_UID) is PackedScene, "TreasureRoom.tscn loads")
	_check(load(UIDs.TREASURE_COIN_GAME_UID) is PackedScene, "CoinFlipGame.tscn loads")
	_check(load(UIDs.TREASURE_WHEEL_GAME_UID) is PackedScene, "WheelGame.tscn loads")
	_check(load(UIDs.TREASURE_PLINKO_GAME_UID) is PackedScene, "PlinkoGame.tscn loads")

	print("\n[ odds ]")
	for table: TreasureTable in treasure_set.tables:
		_check_odds(table)

	print("\n[ the shipped shapes ]")
	_check_shipped_shapes()

	print("\n[ the coin ]")
	await _check_coin()

	print("\n[ the board ]")
	for table: TreasureTable in treasure_set.tables:
		if table.allows(TreasureTable.Game.PLINKO):
			_check_board(table)

	print("\n[ hooks ]")
	_check_hooks()


## The invariant the whole room rests on: what a chest *says* on the map is what
## it actually does. Rolls the table thousands of times and compares.
func _check_odds(table: TreasureTable) -> void:
	var counts: Dictionary[TreasureSlice, int] = {}
	for _index: int in ODDS_SAMPLES:
		var slice: TreasureSlice = table.roll()
		counts[slice] = counts.get(slice, 0) + 1

	var worst_drift: float = 0.0
	for slice: TreasureSlice in table.slices:
		var actual: float = float(counts.get(slice, 0)) / float(ODDS_SAMPLES)
		worst_drift = maxf(worst_drift, absf(actual - table.chance_of(slice)))

	_check(worst_drift < ODDS_TOLERANCE,
		"'%s' rolls what it advertises (%s, worst drift %.1f%%)"
			% [table.table_name, table.get_odds_text(), worst_drift * 100.0])


## The three chests are meant to be three different bets, not three skins. This
## is the design stated as an assertion, so a retune that flattens them says so.
func _check_shipped_shapes() -> void:
	var even_split: TreasureTable = load(UIDs.TREASURE_EVEN_SPLIT_UID) as TreasureTable
	var rich_seam: TreasureTable = load(UIDs.TREASURE_RICH_SEAM_UID) as TreasureTable
	var dead_drop: TreasureTable = load(UIDs.TREASURE_DEAD_DROP_UID) as TreasureTable

	_check(is_equal_approx(even_split.chance_of(even_split.best_slice()), 0.5),
		"Even Split is a coin toss")
	_check(even_split.allows(TreasureTable.Game.COIN) and not even_split.allows(TreasureTable.Game.WHEEL),
		"...and is the coin's chest, not the wheel's")
	_check(is_equal_approx(even_split.best_slice().seconds, -even_split.worst_slice().seconds),
		"...paying and biting exactly the same")

	_check(rich_seam.chance_of(rich_seam.best_slice()) > 0.65,
		"Rich Seam usually pays (%d%%)" % roundi(rich_seam.chance_of(rich_seam.best_slice()) * 100.0))
	_check(absf(rich_seam.worst_slice().seconds) > rich_seam.best_slice().seconds,
		"...and the rare outcome is the one that hurts")

	_check(dead_drop.chance_of(dead_drop.worst_slice()) > 0.65,
		"Dead Drop usually bites (%d%%)" % roundi(dead_drop.chance_of(dead_drop.worst_slice()) * 100.0))
	_check(dead_drop.best_slice().seconds > absf(dead_drop.worst_slice().seconds),
		"...and the rare outcome is the one worth having")

	for table: TreasureTable in [rich_seam, dead_drop]:
		_check(table.allows(TreasureTable.Game.WHEEL) and table.allows(TreasureTable.Game.PLINKO),
			"'%s' can be played either way" % table.table_name)
		_check(table.rarest_slice() == _least_likely(table),
			"'%s' knows which of its outcomes is the rare one" % table.table_name)


## The board is where the chest's odds and its payouts part company: the odds of
## an outcome are the table's, but what a bin pays depends on how far out it sits.
## Both halves of that are checked here, on a real board built from a real table.
func _check_board(table: TreasureTable) -> void:
	var board: PlinkoGame = (load(UIDs.TREASURE_PLINKO_GAME_UID) as PackedScene).instantiate()
	board.setup(table)
	add_child(board)
	# The size the room's board slot gives it. Without it the board is 0x0 — no
	# container out here to stretch it — and every geometry check below would
	# compare zero against zero and pass without meaning anything. The scene's
	# full-rect anchors have to come off first or the engine takes the size back.
	board.anchor_right = 0.0
	board.anchor_bottom = 0.0
	board.size = Vector2(298.0, 94.0)

	var bins: Array = board.get("_bins")
	var payouts: Array = board.get("_payouts")
	var rare: TreasureSlice = table.rarest_slice()

	if not _check(bins.size() == PlinkoGame.BINS and payouts.size() == PlinkoGame.BINS,
		"'%s' lays out %d bins" % [table.table_name, PlinkoGame.BINS]):
		board.queue_free()
		return

	# The row is a picture of the odds: a 30% outcome takes 3 bins of 9.
	var rare_bins: int = 0
	var longest_run: int = 1
	var run: int = 1
	var pattern: Array[String] = []
	for index: int in PlinkoGame.BINS:
		if bins[index] == rare:
			rare_bins += 1
		if index > 0:
			run = run + 1 if bins[index] == bins[index - 1] else 1
			longest_run = maxi(longest_run, run)

		pattern.append(payouts[index].get_label())

	_check(absf(float(rare_bins) / float(PlinkoGame.BINS) - table.chance_of(rare)) < 0.06,
		"'%s': %d of %d bins are the %d%% outcome" % [
			table.table_name, rare_bins, PlinkoGame.BINS, roundi(table.chance_of(rare) * 100.0)])

	# Spread, not blocked. Two of a kind in a row is the pattern; three is a wall
	# of one colour and the board stops being a gamble at every slot.
	_check(longest_run <= 2, "...spread across the row, never more than 2 alike (run of %d)" % longest_run)
	_check(bins[0] == rare, "...with the rare one on the edge, where the multiplier is biggest")
	print("       %s" % "  ".join(pattern))

	# Values get wilder outward and tamer inward, and never change sign.
	var centre: int = PlinkoGame.BINS / 2
	for index: int in PlinkoGame.BINS:
		var expected: float = bins[index].seconds * board._wildness(index)
		if not is_equal_approx(payouts[index].seconds, expected):
			_check(false, "bin %d pays %.1f, not the %.1f its position is worth" % [
				index, payouts[index].seconds, expected])
			break
		if signf(payouts[index].seconds) != signf(bins[index].seconds):
			_check(false, "bin %d flipped an outcome's sign" % index)
			break

	_check(true, "...every bin pays its own outcome, scaled by how far out it sits")
	_check(absf(payouts[0].seconds) > absf(payouts[centre].seconds)
		and absf(payouts[PlinkoGame.BINS - 1].seconds) > absf(payouts[centre].seconds),
		"...the edges are worth more than the middle (%s / %s vs %s)" % [
			payouts[0].get_label(), payouts[PlinkoGame.BINS - 1].get_label(), payouts[centre].get_label()])

	_check_fall(board, table, rare)
	board.queue_free()


## The fall is the part with no safety net in it: nothing is rolled in advance,
## so whatever the walk does *is* the result. These are the properties that have
## to hold for that to be safe to ship.
func _check_fall(board: PlinkoGame, table: TreasureTable, rare: TreasureSlice) -> void:
	const DROPS: int = 4000

	var off_board: int = 0
	var bad_landings: int = 0
	var rare_total: int = 0
	var guaranteed: Array[int] = []
	var edge_rare: float = 0.0
	var middle_rare: float = 0.0

	for slot: int in PlinkoGame.BINS:
		var rare_here: int = 0
		var reached: Dictionary[int, bool] = {}

		for _drop: int in DROPS:
			var columns: Array[float] = board._fall_columns(slot)
			if columns.size() != PlinkoGame.PEG_ROWS:
				bad_landings += 1
				continue

			for column: float in columns:
				if column < 0.0 or column > float(PlinkoGame.BINS - 1):
					off_board += 1

			var landed: int = roundi(columns[columns.size() - 1])
			if landed < 0 or landed >= PlinkoGame.BINS:
				bad_landings += 1
				continue
			# Ten rows of half-bin steps from a whole bin must end on a whole bin,
			# or the ball comes to rest between two of them.
			if not is_equal_approx(columns[columns.size() - 1], float(landed)):
				bad_landings += 1

			reached[landed] = true
			if board._bins[landed] == rare:
				rare_here += 1

		rare_total += rare_here
		var rate: float = float(rare_here) / float(DROPS)
		# The whole of what the player was promised: no slot is a sure thing.
		if rate < 0.02 or rate > 0.98:
			guaranteed.append(slot)
		if slot == 0 or slot == PlinkoGame.BINS - 1:
			edge_rare += rate * 0.5
		if slot == PlinkoGame.BINS / 2:
			middle_rare = rate

	_check(off_board == 0, "...the ball never leaves the board (%d times it did)" % off_board)
	_check(bad_landings == 0, "...and always comes to rest in a bin (%d times it didn't)" % bad_landings)
	_check(guaranteed.is_empty(), "...no slot is a guarantee %s" % ("" if guaranteed.is_empty() else guaranteed))

	# The board is built from the chest's ratio, so it plays close to it — but the
	# ball is what decides, so this is a band, not an equality.
	var measured: float = float(rare_total) / float(DROPS * PlinkoGame.BINS)
	_check(absf(measured - table.chance_of(rare)) < 0.10,
		"...and lands '%s' %d%% of the time across the board, against the chest's %d%%" % [
			rare.get_label(), roundi(measured * 100.0), roundi(table.chance_of(rare) * 100.0)])
	_check(absf(middle_rare - table.chance_of(rare)) < 0.10,
		"...%d%% of the time from the middle" % roundi(middle_rare * 100.0))
	print("       middle %d%%   edges %d%%   (chest %d%%)" % [
		roundi(middle_rare * 100.0), roundi(edge_rare * 100.0), roundi(table.chance_of(rare) * 100.0)])


func _least_likely(table: TreasureTable) -> TreasureSlice:
	var rarest: TreasureSlice = table.slices[0]
	for slice: TreasureSlice in table.slices:
		if table.chance_of(slice) < table.chance_of(rarest):
			rarest = slice

	return rarest


## Each treasure perk is asked the question the room would ask it, and — the
## point of putting the hooks on Modifier — everything else is asked too.
func _check_hooks() -> void:
	var charm: Modifier = load(UIDs.LUCKY_CHARM_UID) as Modifier
	_check(is_equal_approx(charm.modify_treasure_gain(10.0), 15.0), "Lucky Charm turns a 10s payout into 15s")
	_check(is_equal_approx(charm.modify_treasure_loss(10.0), 10.0), "...and does nothing about a bite")

	var crate: Modifier = load(UIDs.PADDED_CRATE_UID) as Modifier
	_check(is_equal_approx(crate.modify_treasure_loss(18.0), 9.0), "Padded Crate halves an 18s bite")
	_check(is_equal_approx(crate.modify_treasure_gain(10.0), 10.0), "...and doesn't touch a payout")

	var plain: Modifier = load(UIDs.SPARE_FUSE_UID) as Modifier
	_check(is_equal_approx(plain.modify_treasure_gain(10.0), 10.0)
		and is_equal_approx(plain.modify_treasure_loss(10.0), 10.0),
		"a non-treasure modifier changes nothing about a chest")
	_check(not plain.on_treasure_opened(10.0), "...and is not spent by one")

	# Stacked, through the system, the way the room actually asks.
	var system: ModifiersSystem = ModifiersSystem.new()
	system.add_modifier(charm)
	system.add_modifier(crate)
	_check(is_equal_approx(system.get_treasure_gain(10.0), 15.0), "the system folds the charm into a payout")
	_check(is_equal_approx(system.get_treasure_loss(18.0), 9.0), "and the crate into a bite")
	_check(is_equal_approx(system.get_treasure_loss(-5.0), 0.0), "a negative amount can never become a payout")
	_check(is_equal_approx(system.get_treasure_weight(70.0, true), 70.0)
		and is_equal_approx(system.get_treasure_weight(30.0, false), 30.0),
		"neither of them touches a chest's odds")
	_check(not system.claim_treasure_retry(-18.0), "and neither buys a second opening")
	_check(is_zero_approx(system.get_treasure_card_chance(true))
		and is_zero_approx(system.get_treasure_card_chance(false)),
		"a chest hands out no cards until something says otherwise")
	system.free()

	_check_odds_hooks()
	_check_retry_hook()
	_check_card_hooks()


## The odds hook, which is the one with a rule attached: it is asked *before* the
## chest is laid out, so whatever it returns is what the wheel and the board are
## built out of. Checked here as arithmetic; §"a tilted chest" plays one.
func _check_odds_hooks() -> void:
	var thumb: Modifier = load(UIDs.THUMB_ON_THE_SCALE_UID) as Modifier
	_check(thumb != null and not thumb.stackable, "Thumb On The Scale is one card, not a stack")
	_check(is_equal_approx(thumb.modify_treasure_weight(70.0, true), 112.0),
		"...and leans a paying outcome from 70 to 112")
	_check(is_equal_approx(thumb.modify_treasure_weight(30.0, false), 30.0),
		"...leaving the biting one where it was")
	_check(is_equal_approx(thumb.modify_treasure_gain(10.0), 10.0)
		and is_equal_approx(thumb.modify_treasure_loss(10.0), 10.0),
		"...and changing nothing about what either is worth")

	var seam: Modifier = load(UIDs.SHALLOW_SEAM_UID) as Modifier
	_check(is_equal_approx(seam.modify_treasure_weight(70.0, true), 140.0)
		and is_equal_approx(seam.modify_treasure_gain(10.0), 6.0),
		"Shallow Seam pays twice as often and 40% less")

	# The cost half. Better odds are bought with a burning fuse, which is the one
	# price a treasure room can charge that isn't just a smaller payout.
	var clock: Modifier = thumb.linked_modifier
	if not _check(clock != null, "Thumb On The Scale drags a drawback along with it"):
		return

	_check(clock.modifier_name == "On The Clock", "...and it is '%s'" % clock.modifier_name)
	_check(clock.runs_clock_in_treasure(), "...which runs the fuse while a chest is open")
	_check(is_equal_approx(clock.modify_treasure_weight(70.0, true), 70.0)
		and is_equal_approx(clock.modify_treasure_gain(10.0), 10.0),
		"...and bends nothing else — the cost is the clock, and only the clock")
	_check(not thumb.runs_clock_in_treasure(), "the bonus half doesn't charge for itself twice")

	# One thumb turns a 70/30 chest into a 79/21 one — and grants both halves,
	# because a linked modifier comes with the card that carries it.
	var system: ModifiersSystem = ModifiersSystem.new()
	system.add_modifier(thumb)
	_check(system.has_modifier("thumb_on_the_scale") and system.has_modifier("on_the_clock"),
		"taking the card grants both halves")
	_check(system.is_treasure_clock_running(), "...so the next chest is on a running clock")

	var gain: float = system.get_treasure_weight(70.0, true)
	var loss: float = system.get_treasure_weight(30.0, false)
	var share: float = gain / (gain + loss)
	_check(is_equal_approx(gain, 112.0), "the tilt reaches the fold intact (%.1f)" % gain)
	_check(absf(share - 0.79) < 0.01, "a 70%% chest opens as a %.0f%% one" % [share * 100.0])

	# Everything else leaves the room's usual "a gamble is not a time trial" alone.
	var plain_system: ModifiersSystem = ModifiersSystem.new()
	plain_system.add_modifier(load(UIDs.LUCKY_CHARM_UID))
	_check(not plain_system.is_treasure_clock_running(),
		"a run carrying anything else opens chests on a stopped clock")
	plain_system.free()

	# A tilt can shrink a side away to nothing; it can never invert one.
	var flattened: TreasureModifier = TreasureModifier.new()
	flattened.gain_weight_scale = -5.0
	system.add_modifier(flattened)
	_check(system.get_treasure_weight(70.0, true) >= 0.0, "a negative tilt clamps at zero, not below")
	system.free()


func _check_retry_hook() -> void:
	var second: Modifier = load(UIDs.SECOND_CHANCE_UID) as Modifier
	_check(second != null and second.wants_treasure_retry(-18.0), "Second Chance buys a reopening")
	_check(second.get_description().contains("Spent once used"), "...and says on the card that it is spent")

	var system: ModifiersSystem = ModifiersSystem.new()
	system.add_modifier(second)
	system.add_modifier(load(UIDs.LUCKY_CHARM_UID))
	_check(system.claim_treasure_retry(-18.0), "the system finds it")
	_check(not system.has_modifier("second_chance"), "...spends it on the spot")
	_check(system.has_modifier("lucky_charm"), "...and leaves everything else alone")
	_check(not system.claim_treasure_retry(-18.0), "so a chest can't be reopened forever")
	system.free()


func _check_card_hooks() -> void:
	var magpie: Modifier = load(UIDs.MAGPIES_EYE_UID) as Modifier
	_check(is_equal_approx(magpie.modify_treasure_card_chance(0.0, true), 0.5),
		"Magpie's Eye searches half the chests that pay")
	_check(is_zero_approx(magpie.modify_treasure_card_chance(0.0, false)),
		"...and none of the ones that bite")

	var salvage: Modifier = load(UIDs.SALVAGE_RIGHTS_UID) as Modifier
	_check(is_equal_approx(salvage.modify_treasure_card_chance(0.0, false), 0.6),
		"Salvage Rights takes 60% of what bites you")
	_check(is_zero_approx(salvage.modify_treasure_card_chance(0.0, true)),
		"...and leaves the payouts alone")

	# Independent rather than additive: two half-chances are three quarters, and
	# no stack of them reaches certainty by arithmetic.
	_check(is_equal_approx(magpie.modify_treasure_card_chance(0.5, true), 0.75),
		"a second searcher folds in as an independent chance, not as an addition")

	var second_eye: TreasureModifier = TreasureModifier.new()
	second_eye.id = "test_second_eye"
	second_eye.gain_card_chance = 0.5

	var system: ModifiersSystem = ModifiersSystem.new()
	system.add_modifier(magpie)
	system.add_modifier(second_eye)
	_check(is_equal_approx(system.get_treasure_card_chance(true), 0.75),
		"the system folds two of them to 75%, not to 100%")
	_check(system.get_treasure_card_chance(true) <= 1.0, "and the chance can never pass certainty")
	_check(is_zero_approx(system.get_treasure_card_chance(false)),
		"neither of them searches a chest that bit")
	system.free()

	# The pool a chest draws from is the workshop's own, so anything it hands out
	# is something a bench that deep could have laid out.
	var pool: WorkshopPool = load(UIDs.WORKSHOP_DEFAULT_POOL_UID) as WorkshopPool
	if not _check(pool != null, "the workshop pool loads for a chest to draw from"):
		return

	var ids: Dictionary[String, bool] = {}
	for entry: WorkshopEntry in pool.entries:
		if entry != null and entry.modifier != null:
			ids[entry.modifier.id] = true

	for id: String in ["lucky_charm", "padded_crate", "thumb_on_the_scale", "second_chance",
			"magpies_eye", "salvage_rights", "shallow_seam"]:
		_check(ids.has(id), "'%s' is reachable from a bench" % id)


# --- The map -----------------------------------------------------------------
## The chest row is a choice, and it is only a choice if the chests differ. The
## generator deals them rather than rolling each one, so this is a hard check
## rather than a statistical one.
func _check_map_deal() -> void:
	print("\n[ the chest row ]")

	var generator: MapGenerator = MapGenerator.new()
	add_child(generator)

	var rows_checked: int = 0
	var rows_with_duplicates: int = 0
	var chests_without_a_table: int = 0

	for _attempt: int in 20:
		var map_data: Array[Array] = generator.generate_map()
		for row: Array in map_data:
			var kinds: Array[String] = []
			for room: Room in row:
				if room.type != Room.Type.TREASURE or room.next_nodes.is_empty():
					continue
				if room.treasure == null:
					chests_without_a_table += 1
					continue

				_check_scene_uid(room)
				kinds.append(room.treasure.table_name)

			if kinds.size() < 2:
				continue

			rows_checked += 1
			var unique: Dictionary[String, bool] = {}
			for kind: String in kinds:
				unique[kind] = true

			# Three kinds ship, so up to three chests in a row must all differ.
			if unique.size() < mini(kinds.size(), 3):
				rows_with_duplicates += 1

	_check(rows_checked > 0, "runs put chests side by side to choose between (%d rows)" % rows_checked)
	_check(chests_without_a_table == 0, "every chest on the map knows which chest it is")
	_check(rows_with_duplicates == 0, "no row offers the same chest twice (%d bad rows)" % rows_with_duplicates)

	generator.queue_free()


func _check_scene_uid(room: Room) -> void:
	if room.scene_uid == UIDs.TREASURE_ROOM_SCENE_UID:
		return

	_check(false, "a chest at %s points at '%s'" % [room.coordinates, room.scene_uid])


# --- The real thing ----------------------------------------------------------
## Boots MainGame and plays each chest through each of its games, on a clock with
## room to move in both directions.
func _check_live_rooms() -> void:
	print("\n[ live rooms ]")

	var main_scene: PackedScene = load(MAIN_SCENE_UID) as PackedScene
	if not _check(main_scene != null, "main scene loads"):
		return

	add_child(main_scene.instantiate())
	await get_tree().process_frame

	var game: MainGame = Global.main_game
	if not _check(game != null, "MainGame registered itself with Global"):
		return

	game.load_game()

	await _play(game, UIDs.TREASURE_EVEN_SPLIT_UID, TreasureTable.Game.COIN, "the coin")
	await _play(game, UIDs.TREASURE_RICH_SEAM_UID, TreasureTable.Game.WHEEL, "the wheel")
	await _play(game, UIDs.TREASURE_DEAD_DROP_UID, TreasureTable.Game.PLINKO, "the board")
	await _check_charms(game)
	await _check_tilt(game)
	await _check_second_chance(game)
	await _check_lining(game)


## One full visit: enter the room, play whatever it laid out, and check the clock
## moved by exactly what the outcome said — no more, and in the right direction.
func _play(game: MainGame, table_uid: String, expect: TreasureTable.Game, label: String) -> TreasureSlice:
	var table: TreasureTable = load(table_uid) as TreasureTable
	# Half a clock, so a payout has somewhere to go and a bite has something to
	# take. At full, a win would clamp against max_time and measure as nothing.
	game.time_system.current_time = 30.0

	var room: TreasureRoom = await _enter(game, table)
	if room == null:
		return null

	var minigame: TreasureGame = room.get("_game") as TreasureGame
	if not _check(minigame != null, "%s: a minigame was laid out" % label):
		return null

	_check(table.allows(expect), "%s: '%s' allows it" % [label, table.table_name])

	var time_system: TimeSystem = game.time_system
	var before: float = time_system.current_time

	_room_closed = false
	room.exited.connect(_on_room_closed)

	_play_minigame(minigame)
	# Long enough for the longest animation (a full-charge spin) plus the payout
	# beat that follows it.
	await get_tree().create_timer(4.0).timeout

	var slice: TreasureSlice = _last_resolved(room)
	if not _check(slice != null, "%s: the chest resolved" % label):
		return null

	var applied: float = room.get("_applied")
	_check(is_equal_approx(time_system.current_time, before + applied),
		"%s: the clock moved by exactly %+.1fs (%.1f -> %.1f)" % [label, applied, before, time_system.current_time])
	_check(signf(applied) == signf(slice.seconds) or is_zero_approx(applied),
		"%s: '%s' moved the clock the way it said" % [label, slice.get_label()])
	_check(not room.leave_button.disabled, "%s: the way out only opens once it has paid" % label)

	room._on_leave_pressed()
	await get_tree().create_timer(0.5).timeout
	_check(_room_closed, "%s: leaving closes the room" % label)

	return slice


## Presses whatever this game asks the player to press. Each one commits the
## player before the roll, so this is the same act a player performs.
func _play_minigame(minigame: TreasureGame) -> void:
	if minigame is CoinFlipGame:
		(minigame as CoinFlipGame).heads_button.pressed.emit()
	elif minigame is WheelGame:
		var wheel: WheelGame = minigame as WheelGame
		wheel.spin_button.button_down.emit()
		wheel.spin_button.button_up.emit()
	elif minigame is PlinkoGame:
		var board: PlinkoGame = minigame as PlinkoGame
		var slots: Array = board.get("_slot_buttons")
		_check(slots.size() == PlinkoGame.BINS, "the board has one slot per bin (%d)" % slots.size())
		(slots[0] as Button).pressed.emit()
	else:
		_check(false, "an unknown minigame was laid out")


## Enters a treasure room carrying a specific chest. A real visit gets the chest
## off the map node the player clicked; forcing it here is what lets all three be
## walked in one run.
func _enter(game: MainGame, table: TreasureTable, on_the_clock: bool = false) -> TreasureRoom:
	var room_data: Room = Room.new()
	room_data.type = Room.Type.TREASURE
	room_data.treasure = table
	room_data.apply_type_scene()
	game.map.last_room = room_data

	game.enter_room(room_data.scene_uid, Room.Type.TREASURE)
	var room: TreasureRoom = game.get("_current_room") as TreasureRoom
	if not _check(room != null, "entering a TREASURE room loads a TreasureRoom"):
		return null

	if on_the_clock:
		_check(room.should_tick_time, "the fuse is burning while this chest is open")
	else:
		_check(not room.should_tick_time, "the clock is off while a chest is open")

	# The opening fade, then the game is live.
	await get_tree().create_timer(0.6).timeout
	return room


## Charms are the extension point; this is the whole of their promise, measured.
func _check_charms(game: MainGame) -> void:
	print("\n[ charms ]")

	var modifiers: ModifiersSystem = game.modifiers_system
	modifiers.add_modifier(load(UIDs.LUCKY_CHARM_UID))
	modifiers.add_modifier(load(UIDs.PADDED_CRATE_UID))

	var time_system: TimeSystem = game.time_system
	time_system.current_time = 40.0

	var table: TreasureTable = load(UIDs.TREASURE_EVEN_SPLIT_UID) as TreasureTable
	var room: TreasureRoom = await _enter(game, table)
	if room == null:
		return

	var before: float = time_system.current_time
	_play_minigame(room.get("_game") as TreasureGame)
	await get_tree().create_timer(3.0).timeout

	var slice: TreasureSlice = _last_resolved(room)
	if not _check(slice != null, "the charmed chest resolved"):
		return

	var moved: float = time_system.current_time - before
	if slice.is_gain():
		_check(is_equal_approx(moved, slice.seconds * 1.5),
			"Lucky Charm turned %+.0fs into %+.1fs" % [slice.seconds, moved])
	else:
		_check(is_equal_approx(moved, slice.seconds * 0.5),
			"Padded Crate softened %+.0fs to %+.1fs" % [slice.seconds, moved])

	room._on_leave_pressed()
	await get_tree().create_timer(0.5).timeout

	# A payout bigger than the room left in the tank. It pays what fits — and has
	# to say why, or the number reads as the chest short-changing the player.
	# Forced rather than sampled: a coin that happened to bite would pass this
	# without ever testing the ceiling.
	var always_pays: TreasureTable = table.duplicate(true)
	for forced: TreasureSlice in always_pays.slices:
		forced.weight = 1.0 if forced == always_pays.best_slice() else 0.0

	time_system.current_time = time_system.max_time - 3.0
	var brimming: TreasureRoom = await _enter(game, always_pays)
	if brimming == null:
		return

	var brim_before: float = time_system.current_time
	_play_minigame(brimming.get("_game") as TreasureGame)
	await get_tree().create_timer(3.0).timeout

	_check(is_equal_approx(time_system.current_time, time_system.max_time),
		"a payout past the ceiling fills the tank and no more (%.1f -> %.1f of %.1f)" % [
			brim_before, time_system.current_time, time_system.max_time])
	_check(is_equal_approx(float(brimming.get("_applied")), 3.0),
		"...and reports the 3s that actually landed, not the %s it rolled" % always_pays.best_slice().get_label())
	_check(float(brimming.get("_withheld")) > 0.0
		and brimming.instruction_label.text.contains("TANK FULL"),
		"...saying why: '%s'" % brimming.instruction_label.text)

	brimming._on_leave_pressed()
	await get_tree().create_timer(0.5).timeout

	# The floor exists so a chest can never end a run outright.
	time_system.current_time = 4.0
	var floored: TreasureRoom = await _enter(game, load(UIDs.TREASURE_RICH_SEAM_UID))
	if floored == null:
		return

	_play_minigame(floored.get("_game") as TreasureGame)
	await get_tree().create_timer(4.0).timeout
	_check(time_system.current_time >= TreasureRoom.SURVIVAL_FLOOR,
		"a chest can't take the last of the clock (%.1fs left)" % time_system.current_time)

	floored._on_leave_pressed()
	await get_tree().create_timer(0.5).timeout


## A tilted chest, played. The rule the odds hook exists under is that the game
## in front of the player is built out of the tilt — so this checks the room's
## table really is the leaned-on one, that the minigame was handed that same
## table, and that the authored .tres on disk came through untouched.
##
## And the other half of the same card: the fuse burning while the lid is up.
func _check_tilt(game: MainGame) -> void:
	print("\n[ a tilted chest ]")

	var modifiers: ModifiersSystem = game.modifiers_system
	_clear_carried(modifiers)
	modifiers.add_modifier(load(UIDs.THUMB_ON_THE_SCALE_UID))
	_check(modifiers.has_modifier("on_the_clock"), "the card brought its drawback into the run")

	var authored: TreasureTable = load(UIDs.TREASURE_RICH_SEAM_UID) as TreasureTable
	var before: float = authored.chance_of(authored.best_slice())

	game.time_system.current_time = 30.0
	var room: TreasureRoom = await _enter(game, authored, true)
	if room == null:
		return

	# The cost, measured on the real clock: this room is the one place in the
	# game where a chest is a time trial, and it has to say so.
	_check(game.time_system.ticking, "...and MainGame started the clock on the room's say-so")
	_check(game.time_system.current_time < 30.0,
		"...so the chest has already cost %.1fs just standing here" % [30.0 - game.time_system.current_time])
	_check(room.location_label.text.contains("ON THE CLOCK"),
		"...and the room says so: '%s'" % room.location_label.text)

	var played: TreasureTable = room.get("_table") as TreasureTable
	var after: float = played.chance_of(played.best_slice())
	_check(played != authored, "a chest leaned on by a charm is a copy, not the .tres")
	_check(absf(authored.chance_of(authored.best_slice()) - before) < 0.0001,
		"...so the authored chest is still %.0f%% on disk" % [before * 100.0])
	# 70% × 1.6 against an untouched 30% is 78.9%, so this is the tilt landing in
	# full rather than merely landing.
	_check(absf(after - 0.789) < 0.01, "the chest is opened at %.0f%% rather than %.0f%%" % [
		after * 100.0, before * 100.0])

	var minigame: TreasureGame = room.get("_game") as TreasureGame
	_check(minigame != null and minigame.table == played,
		"the game the player is looking at was cut from the tilted odds")

	_play_minigame(minigame)
	await get_tree().create_timer(4.0).timeout
	_check(not room.leave_button.disabled, "a tilted chest still pays out and lets go")

	room._on_leave_pressed()
	await get_tree().create_timer(0.5).timeout


## A chest that bites with a Second Chance in the player's pocket: the outcome is
## torn up, the same chest is opened again, and the charm is gone.
func _check_second_chance(game: MainGame) -> void:
	print("\n[ a second chance ]")

	var modifiers: ModifiersSystem = game.modifiers_system
	_clear_carried(modifiers)
	modifiers.add_modifier(load(UIDs.SECOND_CHANCE_UID))

	# Forced to bite, both times. A chest that happened to pay would walk this
	# check straight past the thing it is here to prove.
	var biting: TreasureTable = _forced(load(UIDs.TREASURE_EVEN_SPLIT_UID), false)
	game.time_system.current_time = 40.0

	var room: TreasureRoom = await _enter(game, biting)
	if room == null:
		return

	var before: float = game.time_system.current_time
	var first: TreasureGame = room.get("_game") as TreasureGame
	_play_minigame(first)
	# The toss, the payout beat, and the pause the room holds before it opens the
	# same chest again.
	await get_tree().create_timer(4.0).timeout

	_check(int(room.get("_retries")) == 1, "the bite bought a reopening")
	_check(not modifiers.has_modifier("second_chance"), "...and spent the charm doing it")
	_check(is_equal_approx(game.time_system.current_time, before),
		"the clock has not moved yet (%.1fs)" % game.time_system.current_time)
	_check(room.leave_button.disabled, "and there is still no way out")

	var second: TreasureGame = room.get("_game") as TreasureGame
	if not _check(second != null and second != first, "the chest was laid out again from scratch"):
		return

	_play_minigame(second)
	await get_tree().create_timer(4.0).timeout

	_check(game.time_system.current_time < before, "the second outcome is the one that counts (%.1fs)"
		% game.time_system.current_time)
	_check(int(room.get("_retries")) == 1, "and it is not reopened a third time on an empty pocket")
	_check(not room.leave_button.disabled, "the way out opens once the second one has paid")

	room._on_leave_pressed()
	await get_tree().create_timer(0.5).timeout


## A chest that hands over a card as well as seconds. Forced to certainty rather
## than sampled: at 50% this would pass half the time whatever the code did.
func _check_lining(game: MainGame) -> void:
	print("\n[ something in the lining ]")

	var modifiers: ModifiersSystem = game.modifiers_system
	_clear_carried(modifiers)

	var certain: TreasureModifier = TreasureModifier.new()
	certain.modifier_name = "Test Lining"
	certain.id = "test_lining"
	certain.gain_card_chance = 1.0
	modifiers.add_modifier(certain)

	var paying: TreasureTable = _forced(load(UIDs.TREASURE_EVEN_SPLIT_UID), true)
	game.time_system.current_time = 30.0

	var room: TreasureRoom = await _enter(game, paying)
	if room == null:
		return

	var carried: int = modifiers.modifiers.size()
	var icons: int = room.carry_row.get_child_count()
	_play_minigame(room.get("_game") as TreasureGame)
	await get_tree().create_timer(3.0).timeout

	var card: Modifier = room.get("_card") as Modifier
	if not _check(card != null, "a chest that pays out coughed up a card as well"):
		return

	_check(modifiers.modifiers.size() > carried, "...the run is carrying it (%d -> %d)" % [
		carried, modifiers.modifiers.size()])
	_check(modifiers.has_modifier(card.id), "...and it is the card the room named ('%s')" % card.modifier_name)
	_check(room.carry_row.get_child_count() > icons, "...its icon landed in the strip on the spot")
	_check(room.instruction_label.text.contains(card.modifier_name.to_upper()),
		"...and the header says which it was: '%s'" % room.instruction_label.text)

	room._on_leave_pressed()
	await get_tree().create_timer(0.5).timeout

	# A chest with nothing carried is still a chest that only pays in seconds.
	_clear_carried(modifiers)
	var plain: TreasureRoom = await _enter(game, paying)
	if plain == null:
		return

	_play_minigame(plain.get("_game") as TreasureGame)
	await get_tree().create_timer(3.0).timeout
	_check(plain.get("_card") == null, "a run carrying nothing gets seconds and nothing else")

	plain._on_leave_pressed()
	await get_tree().create_timer(0.5).timeout


## A copy of a table that can only do one thing, so a check about what happens
## *after* an outcome never has to gamble on getting that outcome.
func _forced(source: TreasureTable, pays: bool) -> TreasureTable:
	var table: TreasureTable = source.duplicate(true) as TreasureTable
	var wanted: TreasureSlice = table.best_slice() if pays else table.worst_slice()
	for slice: TreasureSlice in table.slices:
		slice.weight = 1.0 if slice == wanted else 0.0

	return table


## Empties the run's pockets between groups, so a charm from one check can't
## quietly change the arithmetic of the next.
func _clear_carried(modifiers: ModifiersSystem) -> void:
	for modifier: Modifier in modifiers.modifiers.duplicate():
		modifiers.remove_modifier(modifier)


## The outcome a room settled on, read back off the room rather than off a signal
## — the room has already spent it by the time this runs.
##
## Which slice it was is recovered from the direction the clock moved. Every
## shipped table has exactly one payout and one bite, so direction is enough; a
## table with two payouts would need the room to record the slice itself.
func _last_resolved(room: TreasureRoom) -> TreasureSlice:
	var minigame: TreasureGame = room.get("_game") as TreasureGame
	if minigame == null or not minigame.get("_finished"):
		return null

	var table: TreasureTable = room.get("_table")
	return table.best_slice() if float(room.get("_applied")) > 0.0 else table.worst_slice()


# --- Plumbing ----------------------------------------------------------------
func _on_room_closed() -> void:
	_room_closed = true


func _check(condition: bool, label: String) -> bool:
	if condition:
		print("  ok   %s" % label)
	else:
		print("  FAIL %s" % label)
		_failures += 1

	return condition


func _finish() -> void:
	if _failures == 0:
		print("\ntreasure_check: all checks passed.")
	else:
		printerr("\ntreasure_check: %d check(s) failed." % _failures)

	get_tree().quit(0 if _failures == 0 else 1)
