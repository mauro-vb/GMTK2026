class_name PlinkoGame
extends TreasureGame
## Put the ball where you like and let go. The chest that decides nothing in
## advance.
##
## The bins along the bottom alternate — good, bad, bad, good, bad, bad — with
## the *rare* outcome leading from the left edge and taking a share of the row
## equal to its share of the odds. A chest that pays seven times in ten has six
## paying bins in nine; the chest that bites seven times in ten is the same row
## inverted. It comes out deliberately lopsided, so the two ends of the board are
## two different bets and the player has to look at it.
##
## **The bins get wilder toward the edges.** An edge bin pays [constant
## WILD_SCALE] times what the table says and the middle pays [constant
## MILD_SCALE] times, so the middle is small money either way and the edges are
## where a run gets decided. Every bin prints exactly what it is worth: that is
## the whole of what the player needs, and the only thing this board states in
## numbers.
##
## **Nothing else is stated, because nothing else is promised.** Unlike the coin
## and the wheel, this board does not roll an outcome and then drive the ball to
## it. The ball takes a real walk down real pegs, bounces off the walls, and pays
## whatever bin it finds. Dropping down one side makes that side's bins likely —
## not certain, and never a fixed percentage anyone could print on a button.
##
## Because the row is built from the chest's own ratio and its two outcomes
## alternate, a drop lands on the rare outcome at close to the chest's own odds
## from almost anywhere on the board. The slot is a choice about *stakes* far more
## than about odds, which is exactly the choice worth giving.

# Signals
# Enums
# Constants
## The board. Nine bins is what the alternating row needs to carry a 70/30 split
## as two-thirds-and-a-third; ten rows of pegs is a long enough fall to cross the
## board and back on the way down.
const BINS: int = 9
const PEG_ROWS: int = 10

## The board is drawn as a centred column rather than across the whole screen: a
## lattice as wide as the viewport makes the ball travel further sideways than it
## ever falls, which reads as sliding, not dropping.
const BOARD_WIDTH: float = 160.0

## What the outermost bins multiply the table's seconds by, and what the middle
## one does. Symmetric around the centre, and they average out to about 1.0
## across the row — so the board pays what the chest is worth overall, just never
## evenly.
const WILD_SCALE: float = 1.5
const MILD_SCALE: float = 0.5

const PEG_RADIUS: float = 1.0
const BALL_RADIUS: float = 2.5
## The ball waiting in the chute over whichever slot is being pointed at.
const GHOST_ALPHA: float = 0.6
const BIN_HEIGHT: float = 11.0
const SLOT_HEIGHT: float = 8.0
const SLOT_GAP: float = 5.0

## Per row of pegs, before the jitter each bounce takes.
const ROW_TIME: float = 0.12
const HOP_JITTER: Vector2 = Vector2(0.7, 1.4)
const DROP_TIME: float = 0.2

# Exports
## ART: the thing that falls. The same coin the toss uses works here, which is
## why the artist only has to draw one. Null falls back to a plain ball.
@export var ball_texture: Texture2D

# Public

# Private
## Which of the table's outcomes each bin belongs to, left to right. Only used to
## build the row; once the board is up, the ball answers to the bins.
var _bins: Array[TreasureSlice] = []
## What each bin actually pays: the outcome above, amplified by how far out it
## sits. Drawn on the bin and handed back as the result, so the number the player
## watched the ball land on is the number the clock gets.
var _payouts: Array[TreasureSlice] = []

## Where the ball is, in board pixels, while it is falling.
var _ball: Vector2 = Vector2.ZERO
var _ball_visible: bool = false
## The bin it came to rest in, or -1 while it is still in the air. Kept in bin
## space rather than pixels because the board is resized underneath it the moment
## the result lands — a pixel position would leave the ball hanging where the
## board used to be.
var _landed_bin: int = -1
## The slot the player is pointing at, so the ball can sit in its chute before
## they commit. -1 when nothing is pointed at.
var _aimed_slot: int = -1

var _dropped: bool = false
var _slot_buttons: Array[Button] = []

# On Ready
@onready var slots: HBoxContainer = %Slots

# Static

# Lifecycle
func _draw() -> void:
	_draw_pegs()
	_draw_bins()

	if not _ball_visible:
		# Before the drop, the ball sits in the chute above whichever slot is
		# being pointed at — which is what makes this "put the ball somewhere"
		# rather than "press one of nine buttons".
		if _aimed_slot >= 0:
			_draw_ball(Vector2(_bin_x(float(_aimed_slot)), _pegs_top()), GHOST_ALPHA)
		return

	if _landed_bin >= 0:
		_draw_ball(Vector2(_bin_x(float(_landed_bin)), size.y - BIN_HEIGHT * 0.5), 1.0)
		return

	_draw_ball(_ball, 1.0)

# Public
func begin() -> void:
	_announce("DROP IT")
	if not _slot_buttons.is_empty():
		_slot_buttons[BINS / 2].grab_focus()

# Private
func _build() -> void:
	_lay_out_bins()
	_build_slots()
	resized.connect(_fit_slots)
	_fit_slots()


## Deals the bins out, rarest outcome first, spread at even intervals from bin 0.
##
## Counts are proportional — a 30% outcome takes three bins of nine — by largest
## remainder, so the row always adds up. Spreading rather than blocking is what
## makes the board a gamble at every slot instead of a choice between a green
## half and a red half, and starting from bin 0 is what puts the rare outcome on
## the edge, where the multiplier is biggest.
func _lay_out_bins() -> void:
	_bins.clear()
	_payouts.clear()
	if table == null or not table.is_valid():
		return

	var slices: Array[TreasureSlice] = []
	for slice: TreasureSlice in table.slices:
		if slice != null and slice.weight > 0.0:
			slices.append(slice)

	if slices.is_empty():
		return

	slices.sort_custom(func(a: TreasureSlice, b: TreasureSlice) -> bool: return a.weight < b.weight)

	_bins.resize(BINS)
	for index: int in slices.size():
		_place_evenly(slices[index], _bin_count(slices, index))

	# Rounding, or a table with more outcomes than bins, can leave holes; the
	# commonest outcome fills them rather than leaving a dead bin.
	for index: int in BINS:
		if _bins[index] == null:
			_bins[index] = slices[slices.size() - 1]

	_scale_payouts()


## How many bins an outcome gets: its share of the row, rounded, and never zero.
## The last one named — the commonest, since the list is sorted — takes whatever
## the rounding left over, so the counts always sum to [constant BINS].
##
## Nine bins is chosen for this: a 30% outcome rounds to exactly three of them,
## which is the good-bad-bad the row is meant to read as.
func _bin_count(slices: Array[TreasureSlice], index: int) -> int:
	if index == slices.size() - 1:
		var taken: int = 0
		for other: int in slices.size() - 1:
			taken += maxi(1, roundi(table.chance_of(slices[other]) * float(BINS)))

		return maxi(BINS - taken, 1)

	return maxi(1, roundi(table.chance_of(slices[index]) * float(BINS)))


## Spreads `count` bins across the row at even intervals, starting at bin 0 and
## stepping over anything already taken.
func _place_evenly(slice: TreasureSlice, count: int) -> void:
	for step: int in count:
		var target: int = roundi(float(step) * float(BINS) / float(count))
		for offset: int in BINS:
			var index: int = (target + offset) % BINS
			if _bins[index] == null:
				_bins[index] = slice
				break


## Amplifies each bin by how far out it sits. A copy per bin, not a shared
## resource: the bin's label and the seconds the clock gets are then literally
## the same object, and neither can drift from the other.
func _scale_payouts() -> void:
	_payouts.resize(BINS)
	for index: int in BINS:
		var payout: TreasureSlice = _bins[index].duplicate()
		payout.seconds = _bins[index].seconds * _wildness(index)
		# The row is tight, so bins print the number without its unit.
		payout.label = "%+d" % roundi(payout.seconds)
		_payouts[index] = payout


## 0 dead centre, 1 at either edge.
func _extremity(bin: int) -> float:
	var centre: float = float(BINS - 1) * 0.5
	if centre <= 0.0:
		return 0.0

	return absf(float(bin) - centre) / centre


func _wildness(bin: int) -> float:
	return lerpf(MILD_SCALE, WILD_SCALE, _extremity(bin))


## One slot per bin, so the ball goes in exactly above the column it falls down.
##
## They carry no text. A percentage on a drop slot is a promise the board does
## not make — the ball has ten rows of pegs and two walls to argue with — and
## printing one would be both a lie and the least readable thing on screen. What
## a slot is worth is the row of bins underneath it, which is already drawn.
func _build_slots() -> void:
	for child: Node in slots.get_children():
		slots.remove_child(child)
		child.queue_free()

	_slot_buttons.clear()
	var accent: Color = TreasureStyle.METAL

	for index: int in BINS:
		var button: Button = Button.new()
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size.y = SLOT_HEIGHT
		button.add_theme_stylebox_override(&"normal", TreasureStyle.choice_button(accent * Color(1, 1, 1, 0.45), 0.0, 1))
		button.add_theme_stylebox_override(&"hover", TreasureStyle.choice_button(WorkshopStyle.EMBER, 1.0, 1))
		button.add_theme_stylebox_override(&"focus", TreasureStyle.cursor_button(WorkshopStyle.EMBER, 1))
		button.add_theme_stylebox_override(&"pressed", TreasureStyle.choice_button(WorkshopStyle.SPARK, 1.0, 1))
		button.add_theme_stylebox_override(&"disabled", TreasureStyle.choice_button(WorkshopStyle.EDGE, 0.0, 1))
		button.pressed.connect(_on_slot_chosen.bind(index))
		# Pointing at a slot moves focus to it, the way a workshop card works, so
		# the mouse and the stick can never disagree about where the ball is. One
		# cursor, one ball in the chute.
		button.mouse_entered.connect(_on_slot_hovered.bind(index))
		button.focus_entered.connect(_on_slot_aimed.bind(index))

		slots.add_child(button)
		_slot_buttons.append(button)


## Pins the row of slots to the board's own column rather than the full width, so
## every slot still sits over the bin it drops into.
func _fit_slots() -> void:
	var width: float = _board_width()
	slots.anchor_left = 0.5
	slots.anchor_right = 0.5
	slots.offset_left = -width * 0.5
	slots.offset_right = width * 0.5

# --- Geometry ----------------------------------------------------------------
## Bin space runs 0 to BINS-1 across the board's column; everything the game
## draws or animates is a read of these, so the board and the ball can't
## disagree.
func _board_width() -> float:
	return minf(size.x, BOARD_WIDTH)


func _bin_width() -> float:
	return _board_width() / float(BINS)


func _bin_x(bin_position: float) -> float:
	return (size.x - _board_width()) * 0.5 + (bin_position + 0.5) * _bin_width()


func _pegs_top() -> float:
	return slots.size.y + SLOT_GAP


func _row_y(row: int) -> float:
	var bottom: float = size.y - BIN_HEIGHT
	return _pegs_top() + (bottom - _pegs_top()) * float(row + 1) / float(PEG_ROWS + 1)


func _draw_ball(at: Vector2, alpha: float) -> void:
	if ball_texture != null:
		var texture_size: Vector2 = ball_texture.get_size()
		draw_texture_rect(ball_texture, Rect2(at - texture_size * 0.5, texture_size), false,
			Color(1, 1, 1, alpha))
		return

	draw_circle(at, BALL_RADIUS, WorkshopStyle.SPARK * Color(1, 1, 1, alpha))
	draw_circle(at, BALL_RADIUS, WorkshopStyle.INK * Color(1, 1, 1, alpha), false, 1.0)


func _draw_pegs() -> void:
	for row: int in PEG_ROWS:
		# Alternate rows are offset half a bin — that offset is the deflection.
		var offset: float = 0.0 if row % 2 == 0 else 0.5
		var y: float = _row_y(row)
		var column: float = -offset
		while column <= float(BINS - 1) + offset:
			draw_circle(Vector2(_bin_x(column), y), PEG_RADIUS, TreasureStyle.METAL)
			column += 1.0


func _draw_bins() -> void:
	var top: float = size.y - BIN_HEIGHT
	var left: float = (size.x - _board_width()) * 0.5
	var width: float = _bin_width()

	for index: int in _payouts.size():
		var payout: TreasureSlice = _payouts[index]
		if payout == null:
			continue

		var rect: Rect2 = Rect2(Vector2(left + float(index) * width, top), Vector2(width, BIN_HEIGHT))
		# The further out a bin is, the harder its colour reads — the wild ones
		# should be visible from across the board before any number is.
		draw_rect(rect, TreasureStyle.outcome_fill(payout.seconds, _extremity(index)))
		draw_rect(rect, TreasureStyle.BOARD_EDGE, false, 1.0)
		_draw_centered_text(
			payout.get_label(),
			rect.get_center(),
			WorkshopStyle.FONT_TEXT,
			TreasureStyle.SIZE_ODDS,
			WorkshopStyle.PARCHMENT,
		)

# --- The drop ----------------------------------------------------------------
## The fall, decided one peg at a time: half a bin left or right at each row, an
## even chance each way, and a bounce that would carry the ball off the board
## taken the other way instead — there are walls.
##
## Nothing is fixed in advance. The bin the ball ends in is wherever this walk
## finishes, which is why no slot can be labelled with a number and why dropping
## down one side is a lean rather than a lock.
##
## Ten rows is an even count, so a walk that starts over a bin ends over one too.
func _fall_columns(from_bin: int) -> Array[float]:
	var columns: Array[float] = []
	var column: float = float(from_bin)

	for row: int in PEG_ROWS:
		var going_right: bool = randi() % 2 == 0
		if going_right and column >= float(BINS - 1):
			going_right = false
		elif not going_right and column <= 0.0:
			going_right = true

		column += 0.5 if going_right else -0.5
		columns.append(column)

	return columns


## Each hop is two tweens running together, which is what makes the fall read as
## a ball rather than a cursor: sideways overshoots the peg and comes back — the
## ricochet — while downwards accelerates into it. Every hop takes a slightly
## different length of time, so the rhythm never settles into a metronome.
func _animate_fall(columns: Array[float], landed_bin: int) -> Tween:
	var tween: Tween = _restart_animation()
	for row: int in columns.size():
		var hop: float = ROW_TIME * randf_range(HOP_JITTER.x, HOP_JITTER.y)
		tween.tween_property(self, ^"_ball:x", _bin_x(columns[row]), hop) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(self, ^"_ball:y", _row_y(row), hop) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	# ...and into whichever bin it ended up over.
	tween.tween_property(self, ^"_ball", Vector2(_bin_x(float(landed_bin)), size.y - BIN_HEIGHT * 0.5), DROP_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	return tween

# Callbacks
func _on_slot_hovered(bin: int) -> void:
	if _dropped:
		return

	_slot_buttons[bin].grab_focus()


func _on_slot_aimed(bin: int) -> void:
	if _dropped:
		return

	_aimed_slot = bin
	queue_redraw()


func _on_slot_chosen(bin: int) -> void:
	if _dropped:
		return

	_dropped = true
	for button: Button in _slot_buttons:
		button.disabled = true
		button.focus_mode = Control.FOCUS_NONE

	_announce("...")

	var columns: Array[float] = _fall_columns(bin)
	var landed: int = clampi(roundi(columns[columns.size() - 1]), 0, BINS - 1)

	_ball = Vector2(_bin_x(float(bin)), _pegs_top())
	_ball_visible = true

	await _animate_fall(columns, landed).finished

	# From here the ball sits in its bin, wherever the bin ends up.
	_landed_bin = landed
	queue_redraw()

	# The bin's own amplified payout, not the table's flat one: it is the number
	# the player just watched the ball land on.
	_finish(_payouts[landed])
