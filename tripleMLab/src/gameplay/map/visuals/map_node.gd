class_name MapNode
extends Area2D
## One room on the map, drawn as the thing you are about to blow up.
##
## Each room type has exactly two faces: Default (not yet detonated) and
## Activated (chosen and blown up). Availability itself has no dedicated
## art — it's just a tint on Default plus the "highlight" pulse animation.

signal selected(node: Room)

## Fired only while [member available] is true — hover has nothing to say
## about a room the player cannot pick.
signal hover_entered(room: Room)
signal hover_exited(room: Room)

const SCENE: PackedScene = preload("res://src/gameplay/map/visuals/MapNode.tscn")

## Index into a [Default, Activated] pair.
const FACE_DEFAULT: int = 0
const FACE_ACTIVATED: int = 1

const ROOM_ART: Dictionary[Room.Type, Array] = {
	Room.Type.NOT_ASSIGNED: [
		preload("res://assets/art/map/icons/LevelDefault.png"),
		preload("res://assets/art/map/icons/LevelActivated.png"),
	],
	Room.Type.LEVEL: [
		preload("res://assets/art/map/icons/LevelDefault.png"),
		preload("res://assets/art/map/icons/LevelActivated.png"),
	],
	Room.Type.WORKSHOP: [
		preload("res://assets/art/map/icons/WorkBenchDefault.png"),
		preload("res://assets/art/map/icons/WorkBenchActivated.png"),
	],
	Room.Type.TREASURE: [
		preload("res://assets/art/map/icons/ChestDefault.png"),
		preload("res://assets/art/map/icons/ChestActivated.png"),
	],
	# The final room is a level like any other — the last one — so it wears the
	# level's own face rather than a chest's. FINAL_SCALE is what marks it out.
	Room.Type.FINAL: [
		preload("res://assets/art/map/icons/LevelDefault.png"),
		preload("res://assets/art/map/icons/LevelActivated.png"),
	],
}

const EVENT_ART_POSITIVE: Array = [
	preload("res://assets/art/map/icons/AddedTimeDefault.png"),
	preload("res://assets/art/map/icons/AddedTimeActivated.png"),
]
const EVENT_ART_NEGATIVE: Array = [
	preload("res://assets/art/map/icons/LostTimeDefault.png"),
	preload("res://assets/art/map/icons/LostTimeActivated.png"),
]

## The barrel every path converges on is the payoff, so it outsizes the rooms
## feeding it. Applied to Visuals, not the root, because the root's scale is
## the highlight animation's to drive.
const FINAL_SCALE: float = 1.35

## Rooms the spark cannot reach this turn sink back toward the dirt; rooms it
## has already been through sink further and lose their colour.
const AVAILABLE_MODULATE: Color = Color.WHITE
const UNAVAILABLE_MODULATE: Color = Color(0.66, 0.63, 0.68, 1.0)
const SPENT_MODULATE: Color = Color(0.5, 0.48, 0.5, 1.0)

## A corrupted chest wears a red tint until its own art exists — see
## [method _refresh_art]. Multiplied on top of the usual modulate rather than
## replacing it, so it still dims/greys out the same way as it goes unavailable
## or spent.
const CORRUPTED_TINT: Color = Color(1.6, 0.55, 0.55, 1.0)

## The charge going off. The player is looking straight at the map when this
## fires — it runs the moment they get back from the room — so the swap punches
## out, changes tint at the peak while it is blown white, and settles.
const DETONATE_SCALE: float = 1.3
const DETONATE_OUT: float = 0.09
const DETONATE_SETTLE: float = 0.24
const DETONATE_FLASH: Color = Color(2.4, 2.0, 1.5, 1.0)

## The hovered room steps forward; every other room still in play steps back
## a little to sell that one choice, without fighting the highlight pulse or
## the detonate punch, both of which animate [member scale] instead of
## [member Node2D.scale] on [member visuals].
const HOVER_SCALE: float = 1.15
const HOVER_NEIGHBOR_SCALE: float = 0.8
const HOVER_TWEEN_TIME: float = 0.12

var available: bool = false: set = _set_available
var room: Room: set = _set_room

var _spent: bool = false
## visuals.scale at rest — Vector2.ONE for most rooms, FINAL_SCALE for the
## final room. Hover multiplies against this rather than against whatever
## visuals.scale happens to be mid-tween.
var _visuals_base_scale: Vector2 = Vector2.ONE

@onready var visuals: Node2D = $Visuals
@onready var shadow: Sprite2D = $Visuals/Shadow
@onready var sprite: Sprite2D = $Visuals/Sprite2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer


static func new_map_node(node_data: Room) -> MapNode:
	var map_node: MapNode = SCENE.instantiate()
	map_node.room = node_data
	return map_node


func _ready() -> void:
	input_event.connect(_on_input_event)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

	if room.type == Room.Type.FINAL:
		_visuals_base_scale = Vector2.ONE * FINAL_SCALE
	visuals.scale = _visuals_base_scale

	_refresh_art()

## Restores a room the run has already burnt past: dim art, no animation.
func show_spent() -> void:
	_spent = true
	_refresh_art()

## Blows the room open, animated. Settles into the spent (dimmed) look.
func detonate() -> void:
	if _spent:
		return

	# The highlight loop owns scale; it has to let go before the tween takes it.
	animation_player.stop()

	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.tween_property(self, ^"scale", Vector2.ONE * DETONATE_SCALE, DETONATE_OUT).set_ease(Tween.EASE_OUT)
	tween.tween_callback(_flash_to_spent)
	tween.tween_property(self, ^"scale", Vector2.ONE, DETONATE_SETTLE).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(self, ^"modulate", SPENT_MODULATE, DETONATE_SETTLE)

func _flash_to_spent() -> void:
	show_spent()
	# _refresh_art has just set the resting spent tint; the settle tweens back
	# down to it from here.
	modulate = DETONATE_FLASH

func _set_available(value: bool) -> void:
	available = value
	_refresh_art()
	set_hover_scale(1.0)

	if available:
		await get_tree().create_timer(randf_range(.0, .25)).timeout
		animation_player.play("highlight")
	elif not room.selected:
		animation_player.play("RESET")

## Tweens visuals to [param factor] times its resting scale. Map calls this
## on every available node when any one of them is hovered: 1.15 for the
## room under the cursor, 0.9 for its still-available siblings, 1.0 to reset.
func set_hover_scale(factor: float) -> void:
	var tween: Tween = create_tween()
	tween.tween_property(visuals, ^"scale", _visuals_base_scale * factor, HOVER_TWEEN_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _on_mouse_entered() -> void:
	if available:
		hover_entered.emit(room)

func _on_mouse_exited() -> void:
	if available:
		hover_exited.emit(room)

func _set_room(value: Room) -> void:
	# Runs from new_map_node() before the node is in the tree, so it may only
	# touch the node's own properties. Art is applied in _ready().
	room = value
	position = room.position

func _refresh_art() -> void:
	# _set_available can fire before the node is in the tree.
	if sprite == null:
		return

	# The shadow is the same silhouette offset a couple of pixels, which is what
	# stops an icon reading as a sticker pasted onto the dirt.
	sprite.texture = _texture_for_room()
	shadow.texture = sprite.texture

	if _spent:
		modulate = SPENT_MODULATE
	elif available:
		modulate = AVAILABLE_MODULATE
	else:
		modulate = UNAVAILABLE_MODULATE

	# A corrupted chest is told apart before it's opened — until its own art
	# exists, that's a tint rather than a different sprite (see is_corrupted).
	if room.type == Room.Type.TREASURE and room.is_corrupted:
		modulate *= CORRUPTED_TINT

func _texture_for_room() -> Texture2D:
	var pair: Array = _art_pair_for_room()
	return pair[FACE_ACTIVATED] if _spent else pair[FACE_DEFAULT]

func _art_pair_for_room() -> Array:
	if room.type == Room.Type.EVENT:
		# TODO: point this at whatever field your Room class actually uses
		# to mark an event as good vs bad.
		return EVENT_ART_POSITIVE if room.event_positive else EVENT_ART_NEGATIVE

	# ART: a chest wears its own faces when its [TreasureTable] has them, so a
	# good and a corrupted chest can be told apart by their sprite rather than
	# just a tint (see CORRUPTED_TINT). Drop the sprites into the tables'
	# `map_icon` / `spent_icon` and nothing here changes; until then both share
	# the fallback chest pair below, tinted.
	var chest: Array = _chest_art_pair()
	if not chest.is_empty():
		return chest

	return ROOM_ART.get(room.type, ROOM_ART[Room.Type.NOT_ASSIGNED])

## The chest's own [Default, Activated] pair, or an empty array to fall back to
## the shared chest art. Spent art is optional on its own: a table with an
## open-chest sprite and no closed one just repeats it for [FACE_ACTIVATED]
## rather than being odd or broken.
func _chest_art_pair() -> Array:
	if room.type != Room.Type.TREASURE or room.treasure == null or room.treasure.map_icon == null:
		return []

	var activated: Texture2D = room.treasure.spent_icon if room.treasure.spent_icon != null else room.treasure.map_icon
	return [room.treasure.map_icon, activated]

## A stable per-room number. Two odd primes so neighbouring rooms, which differ
## by one lane and one step, never land on the same face.
func _variant() -> int:
	return absi(room.coordinates.x * 7 + room.coordinates.y * 3)

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if not available or not event.is_action_pressed("left_mouse"):
		return

	room.selected = true
	animation_player.play("selected")
	await animation_player.animation_finished
	_on_map_room_selected()

# Called from animation player
func _on_map_room_selected() -> void:
	selected.emit(room)
