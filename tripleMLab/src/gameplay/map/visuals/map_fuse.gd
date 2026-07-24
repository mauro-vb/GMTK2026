class_name MapFuse
extends Node2D
## One cord between two map positions, drawn as a fuse that can be burnt.
##
## A fuse knows nothing about the map's layout: it is handed two arbitrary world
## positions and burns from the first to the second at any angle, so the map can
## be reoriented without touching this file.
##
## Drawing note: [member unburnt] always keeps its full [code][from, to][/code]
## points and is never re-pointed. A tiled [Line2D] anchors its texture at its
## first point, so shrinking the unburnt line from the front would make the rope
## twist visibly crawl along the cord for the whole animation. Instead the burnt
## line grows from [code]from[/code] on top of it, and the spark rides the seam
## where the burnt line's own trailing tile is unstable.

signal burn_finished

enum State { LIVE, BURNING, BURNT, DUD }

const CORD_LIVE: Texture2D = preload("res://assets/art/map/fuse/fuse_cord.png")
const CORD_BURNT: Texture2D = preload("res://assets/art/map/fuse/fuse_cord_burnt.png")
const CORD_DUD: Texture2D = preload("res://assets/art/map/fuse/fuse_cord_dud.png")

## Pixels per second. Duration is derived from segment length so that long
## diagonal edges do not burn faster than short straight ones.
const BURN_SPEED: float = 55.0
const MIN_BURN_DURATION: float = 0.25
## Grid hops are 30-50px and land well inside this. It only bites on the last
## row, where every path converges on the castle from up to ~160px away and
## would otherwise crawl for nearly 3 seconds.
const MAX_BURN_DURATION: float = 1.1

## Slightly dimmed and slightly transparent, so a dead cord sinks toward the
## background instead of competing with the live ones.
const DUD_MODULATE: Color = Color(0.92, 0.9, 0.89, 0.85)
const HINT_MODULATE: Color = Color(1.35, 1.18, 0.95, 1.0)
const HINT_PERIOD: float = 1.1

var state: State = State.LIVE

var _from: Vector2 = Vector2.ZERO
var _to: Vector2 = Vector2.ZERO
var _hint_tween: Tween = null

@onready var unburnt: Line2D = $Unburnt
@onready var burnt: Line2D = $Burnt
@onready var smoke: CPUParticles2D = $Smoke
@onready var arrival_burst: CPUParticles2D = $ArrivalBurst
@onready var spark_head: Node2D = $SparkHead
@onready var spark: AnimatedSprite2D = $SparkHead/Spark
@onready var ember_trail: CPUParticles2D = $SparkHead/EmberTrail
@onready var hiss: AudioStreamPlayer2D = $SparkHead/Hiss
@onready var pop: AudioStreamPlayer2D = $Pop


## Places the cord. Must be called after the fuse is inside the tree.
func setup(from: Vector2, to: Vector2) -> void:
	_from = from
	_to = to

	unburnt.points = PackedVector2Array([_from, _to])
	burnt.points = PackedVector2Array()

	spark_head.position = _from
	arrival_burst.position = _to
	pop.position = _to

	_place_smoke_along_cord()


## Animates the spark from end to end. Awaitable.
func burn() -> void:
	if state == State.BURNT:
		return

	_stop_hint()
	state = State.BURNING
	unburnt.texture = CORD_LIVE
	modulate = Color.WHITE
	spark.visible = true
	spark.play(&"burn")
	ember_trail.emitting = true
	if hiss.stream != null:
		hiss.play()

	var tween: Tween = create_tween()
	# A fuse burns at a constant rate; easing would make it feel like a UI
	# animation rather than a physical object.
	tween.set_trans(Tween.TRANS_LINEAR)
	tween.tween_method(_set_burn_progress, 0.0, 1.0, get_burn_duration())
	await tween.finished

	_set_burn_progress(1.0)
	state = State.BURNT
	spark.visible = false
	ember_trail.emitting = false
	if hiss.playing:
		hiss.stop()
	if pop.stream != null:
		pop.play()
	arrival_burst.emitting = true
	smoke.emitting = true

	burn_finished.emit()


## Instantly charred, for restoring a path that was already travelled.
func set_burnt() -> void:
	_stop_hint()
	state = State.BURNT
	unburnt.texture = CORD_LIVE
	modulate = Color.WHITE
	burnt.points = PackedVector2Array([_from, _to])
	spark.visible = false
	ember_trail.emitting = false
	smoke.emitting = false


## Instantly unlit and dead: a road that can never be taken.
func set_dud() -> void:
	if state == State.BURNT:
		return

	_stop_hint()
	state = State.DUD
	unburnt.texture = CORD_DUD
	burnt.points = PackedVector2Array()
	spark.visible = false
	ember_trail.emitting = false
	smoke.emitting = false
	modulate = DUD_MODULATE


## Subtle brightness pulse marking a cord the player can still light.
func set_hinted(value: bool) -> void:
	if not value or state != State.LIVE:
		_stop_hint()
		return

	if _hint_tween != null and _hint_tween.is_valid():
		return

	_hint_tween = create_tween().set_loops()
	_hint_tween.set_trans(Tween.TRANS_SINE)
	_hint_tween.tween_property(unburnt, ^"modulate", HINT_MODULATE, HINT_PERIOD * 0.5)
	_hint_tween.tween_property(unburnt, ^"modulate", Color.WHITE, HINT_PERIOD * 0.5)


func get_burn_duration() -> float:
	return clampf(_from.distance_to(_to) / BURN_SPEED, MIN_BURN_DURATION, MAX_BURN_DURATION)


func get_end_position() -> Vector2:
	return _to


func get_spark_position() -> Vector2:
	return spark_head.position


## Widens both cords. Used for the master fuses feeding the final room.
func set_cord_width(value: float) -> void:
	unburnt.width = value
	burnt.width = value


func _set_burn_progress(t: float) -> void:
	var head: Vector2 = _from.lerp(_to, t)
	burnt.points = PackedVector2Array([_from, head])
	spark_head.position = head


func _place_smoke_along_cord() -> void:
	var delta: Vector2 = _to - _from
	smoke.position = _from + delta * 0.5
	smoke.rotation = delta.angle()
	smoke.emission_rect_extents = Vector2(delta.length() * 0.5, 1.0)


func _stop_hint() -> void:
	if _hint_tween != null:
		_hint_tween.kill()
		_hint_tween = null
	unburnt.modulate = Color.WHITE
