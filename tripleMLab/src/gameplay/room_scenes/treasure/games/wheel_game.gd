class_name WheelGame
extends TreasureGame
## Spin it and watch. The chest that gives you no way to cheat the odds — which
## is exactly why it is worth having next to the plinko board, where you can.
##
## The wedges are cut *by weight*: a 70/30 chest is 70% of the wheel and 30% of
## it, and every slice is chopped into several wedges dealt alternately around
## the rim so it reads as a wheel rather than as a pie chart. Because the angles
## stay exactly proportional, where the pointer lands is the table's odds and
## nothing else.
##
## Holding the button winds the spin up. That is drama, not odds — a longer spin
## travels further and lands nowhere more or less likely, and the code says so
## plainly in [method _spin_to] so nobody has to take it on trust.

# Signals
# Enums
# Constants
## Wedges the rim is cut into, before the split by weight rounds it. Eight is the
## most a 320x180 wheel can carry and still label them.
const TARGET_WEDGES: int = 8
const MAX_RADIUS: float = 40.0
## Wedges narrower than this are drawn but not labelled; the text would spill
## over its own borders.
const LABEL_MIN_SPAN: float = 0.45
## Labels ride well out toward the rim: wedges are widest there, so two labels on
## neighbouring wedges have the most room between them.
const LABEL_RADIUS_SCALE: float = 0.72

## The pointer sits at the top and points down into the rim.
const POINTER_WIDTH: float = 5.0
const POINTER_DEPTH: float = 6.0
const HUB_RADIUS: float = 4.0

## Winding up. A full charge is a long spin; a tap is a short one.
const CHARGE_TIME: float = 0.9
const MIN_TURNS: float = 2.0
const MAX_TURNS: float = 6.0
const SPIN_DURATION: float = 2.3
## Kept off the borders, so a wedge that won never looks like the one next to it.
const LANDING_MARGIN: float = 0.12

# Exports

# Public

# Private
## The rim, in order: each entry is a slice and the arc it owns.
var _wedges: Array[Dictionary] = []

var _rotation: float = 0.0
var _charging: bool = false
var _charge: float = 0.0
var _spinning: bool = false

# On Ready
@onready var choices: HBoxContainer = %Choices
@onready var spin_button: Button = %SpinButton

# Static

# Lifecycle
func _process(delta: float) -> void:
	super(delta)

	if not _charging:
		return

	_charge = minf(_charge + delta / CHARGE_TIME, 1.0)
	queue_redraw()


func _draw() -> void:
	var radius: float = _radius()
	var centre: Vector2 = _centre(radius)

	for wedge: Dictionary in _wedges:
		_draw_wedge(centre, radius, wedge)

	draw_circle(centre, HUB_RADIUS, TreasureStyle.METAL)
	draw_circle(centre, HUB_RADIUS, WorkshopStyle.INK, false, 1.0)
	_draw_pointer(centre, radius)
	_draw_charge(centre, radius)

# Public
func begin() -> void:
	_announce("HOLD TO WIND IT UP")
	spin_button.grab_focus()

# Private
func _build() -> void:
	_cut_wedges()

	WorkshopStyle.apply_button_text(spin_button, WorkshopStyle.SIZE_SUBTITLE)
	# The wheel has one control, so — unlike the coin's two calls — lighting it is
	# not a claim about a decision the player hasn't made yet. Focus and hover are
	# the same raised box, and the crank is the only thing on the board to press.
	spin_button.add_theme_stylebox_override(&"normal", TreasureStyle.choice_button(0.0))
	spin_button.add_theme_stylebox_override(&"hover", TreasureStyle.choice_button(1.0))
	spin_button.add_theme_stylebox_override(&"focus", TreasureStyle.choice_button(1.0))
	spin_button.add_theme_stylebox_override(&"pressed", TreasureStyle.choice_button(1.0))
	spin_button.add_theme_stylebox_override(&"disabled", TreasureStyle.choice_button(0.0))

	spin_button.button_down.connect(_on_wind_up)
	spin_button.button_up.connect(_on_let_go)


## Cuts the rim by weight, then deals the pieces out alternately.
##
## Each slice keeps exactly its share of the circle — that is the invariant the
## whole game rests on — but hands that share to several wedges so the rare
## outcome appears at two or three places around the rim instead of as one solid
## block the player can watch approaching.
func _cut_wedges() -> void:
	_wedges.clear()
	if table == null or not table.is_valid():
		return

	var per_slice: Array[Array] = []
	for slice: TreasureSlice in table.slices:
		if slice == null:
			continue

		var share: float = table.chance_of(slice)
		if share <= 0.0:
			continue

		var count: int = maxi(1, roundi(share * float(TARGET_WEDGES)))
		var spans: Array[Dictionary] = []
		for _index: int in count:
			spans.append({"slice": slice, "span": share * TAU / float(count)})

		per_slice.append(spans)

	# Round-robin, so no slice's wedges end up adjacent while another has none
	# on that side of the wheel.
	var placed: int = 0
	var angle: float = 0.0
	var total: int = 0
	for spans: Array in per_slice:
		total += spans.size()

	while placed < total:
		for spans: Array in per_slice:
			if spans.is_empty():
				continue

			var wedge: Dictionary = spans.pop_back()
			wedge["start"] = angle
			angle += wedge["span"]
			_wedges.append(wedge)
			placed += 1


func _radius() -> float:
	var available: float = size.y - choices.size.y - 4.0
	return maxf(minf(available * 0.5, minf(size.x * 0.5, MAX_RADIUS)), HUB_RADIUS * 2.0)


func _centre(radius: float) -> Vector2:
	return Vector2(roundf(size.x * 0.5), roundf(radius + POINTER_DEPTH * 0.5))


func _draw_wedge(centre: Vector2, radius: float, wedge: Dictionary) -> void:
	const SEGMENTS: int = 8
	var slice: TreasureSlice = wedge["slice"]
	var start: float = wedge["start"] + _rotation
	var span: float = wedge["span"]

	var points: PackedVector2Array = PackedVector2Array([centre])
	for index: int in SEGMENTS + 1:
		var angle: float = start + span * float(index) / float(SEGMENTS)
		points.append(centre + Vector2(cos(angle), sin(angle)) * radius)

	draw_colored_polygon(points, TreasureStyle.outcome_fill(slice.seconds, 0.45))
	# The border doubles as the spoke between neighbouring wedges.
	draw_line(centre, points[1], TreasureStyle.BOARD_EDGE, 1.0)
	draw_polyline(points.slice(1), TreasureStyle.BOARD_EDGE, 1.0)

	if span < LABEL_MIN_SPAN:
		return

	var middle: float = start + span * 0.5
	var label_at: Vector2 = centre + Vector2(cos(middle), sin(middle)) * radius * LABEL_RADIUS_SCALE
	_draw_centered_text(
		slice.get_label(),
		label_at,
		WorkshopStyle.FONT_TEXT,
		TreasureStyle.SIZE_ODDS,
		WorkshopStyle.PARCHMENT,
	)


## The marker the rim has to stop under, drawn biting into the wheel so there is
## never a gap to argue about.
func _draw_pointer(centre: Vector2, radius: float) -> void:
	var tip: Vector2 = centre + Vector2(0.0, -radius + POINTER_DEPTH)
	var points: PackedVector2Array = PackedVector2Array([
		tip,
		Vector2(centre.x - POINTER_WIDTH, tip.y - POINTER_DEPTH - 1.0),
		Vector2(centre.x + POINTER_WIDTH, tip.y - POINTER_DEPTH - 1.0),
	])
	draw_colored_polygon(points, WorkshopStyle.EMBER)


## The wind-up, drawn as a ring filling around the hub: the player is looking at
## the wheel, so the meter has to be on it.
func _draw_charge(centre: Vector2, radius: float) -> void:
	if _charge <= 0.0 or _spinning:
		return

	draw_arc(centre, radius * 0.5, -PI * 0.5, -PI * 0.5 + TAU * _charge, 20, WorkshopStyle.SPARK, 2.0)


## Where the wheel has to stop for `slice` to be the honest answer.
##
## The outcome is drawn from the table first and the rotation is worked out
## backwards from it. The charge only picks how many whole turns are travelled on
## the way — whole turns land in the same place, which is the entire reason it is
## safe to let the player wind it up.
func _spin_to(slice: TreasureSlice) -> float:
	var candidates: Array[Dictionary] = []
	for wedge: Dictionary in _wedges:
		if wedge["slice"] == slice:
			candidates.append(wedge)

	if candidates.is_empty():
		push_error("WheelGame: no wedge for the rolled outcome.")
		return _rotation

	var wedge: Dictionary = candidates[randi() % candidates.size()]
	var span: float = wedge["span"]
	var margin: float = span * LANDING_MARGIN
	var landing: float = wedge["start"] + randf_range(margin, span - margin)

	# The pointer sits at the top of the circle.
	var pointer: float = -PI * 0.5
	var turns: float = lerpf(MIN_TURNS, MAX_TURNS, _charge)
	var settled: float = pointer - landing

	# Always forward from where the rim is now, however many turns that takes.
	while settled < _rotation:
		settled += TAU

	return settled + ceilf(turns) * TAU


func _apply_rotation(value: float) -> void:
	_rotation = value

# Callbacks
func _on_wind_up() -> void:
	if _spinning:
		return

	_charging = true
	_charge = 0.0
	_announce("LET GO TO SPIN")


func _on_let_go() -> void:
	if _spinning or not _charging:
		return

	_charging = false
	_spinning = true
	spin_button.disabled = true
	spin_button.focus_mode = Control.FOCUS_NONE
	_announce("...")

	var slice: TreasureSlice = table.roll()
	var tween: Tween = _restart_animation()
	tween.tween_method(_apply_rotation, _rotation, _spin_to(slice), SPIN_DURATION) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	await tween.finished
	_finish(slice)
