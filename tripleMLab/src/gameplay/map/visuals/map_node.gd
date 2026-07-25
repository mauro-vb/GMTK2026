class_name MapNode
extends Area2D
## One room on the map, drawn as the thing you are about to blow up.
##
## Icons are baked at [constant ICON_SIZE] and centred on the room's position,
## so the cords running into a node disappear under it: a fuse plugs into the
## crate rather than stopping short of it. Nothing here sets a z_index — the
## ordering that keeps fuses behind icons lives on the containers in Map.tscn.

signal selected(node: Room)

const SCENE: PackedScene = preload("res://src/gameplay/map/visuals/MapNode.tscn")

## Longest side of every icon, in map pixels. Mirrors ICON_BOX in
## tools/slice_room_art.py, which is what actually bakes them.
const ICON_SIZE: int = 26

## Indices into a face pair: what a room looks like before and after its charge
## goes off.
const FACE_OPEN: int = 0
const FACE_SPENT: int = 1

## Every face a LEVEL room can wear, each paired with its own blown-up twin.
##
## Pairing the two ends rather than picking each at random is what sells the
## swap: the crate you were looking at is the crate now in pieces, the timbered
## mouth is the one that came down. Several faces so a screen holding twenty
## levels does not read as one stamp repeated; the pick comes from the room's
## coordinates, so rebuilding the map keeps every face where it was.
##
## Note every open face carries a light frame or a lit side. The background's
## rock band is nearly black in places, and an unframed icon on it disappears —
## which is why the black cave mouth is only ever a spent face.
const LEVEL_FACES: Array[Array] = [
	[
		preload("res://assets/art/map/rooms/crate.png"),
		preload("res://assets/art/map/rooms/crate_burnt.png"),
	],
	[
		preload("res://assets/art/map/rooms/crate_tarp.png"),
		preload("res://assets/art/map/rooms/crate_burnt.png"),
	],
	[
		preload("res://assets/art/map/rooms/entrance_timber.png"),
		preload("res://assets/art/map/rooms/entrance_collapsed.png"),
	],
	[
		preload("res://assets/art/map/rooms/entrance_door.png"),
		preload("res://assets/art/map/rooms/entrance_boarded.png"),
	],
	[
		preload("res://assets/art/map/rooms/entrance_tunnel.png"),
		preload("res://assets/art/map/rooms/entrance_rails_boarded.png"),
	],
	[
		preload("res://assets/art/map/rooms/entrance_tunnel_lit.png"),
		preload("res://assets/art/map/rooms/entrance_cave.png"),
	],
]

## Everything that is not a LEVEL is a one-off prop, which is most of what makes
## those rooms readable at a glance. They have no blown-up twin on the sheets,
## so they only take [constant SPENT_MODULATE] once they are behind the run.
##
## EVENT is here for completeness; the generator does not produce them yet.
const ROOM_ART: Dictionary[Room.Type, Texture2D] = {
	Room.Type.NOT_ASSIGNED: preload("res://assets/art/map/rooms/crate.png"),
	Room.Type.SHOP: preload("res://assets/art/map/rooms/shop_cart.png"),
	Room.Type.HEAL: preload("res://assets/art/map/rooms/chest.png"),
	Room.Type.EVENT: preload("res://assets/art/map/rooms/crate.png"),
	Room.Type.FINAL: preload("res://assets/art/map/rooms/barrel.png"),
}

## The barrel every path converges on is the payoff, so it outsizes the rooms
## feeding it. Applied to Visuals, not the root, because the root's scale is
## the highlight animation's to drive.
const FINAL_SCALE: float = 1.35

## Rooms the spark cannot reach this turn sink back toward the dirt; rooms it
## has already been through sink further and lose their colour.
const AVAILABLE_MODULATE: Color = Color.WHITE
const UNAVAILABLE_MODULATE: Color = Color(0.66, 0.63, 0.68, 1.0)
const SPENT_MODULATE: Color = Color(0.5, 0.48, 0.5, 1.0)

## The charge going off. The player is looking straight at the map when this
## fires — it runs the moment they get back from the room — so the swap punches
## out, changes face at the peak while it is blown white, and settles.
const DETONATE_SCALE: float = 1.3
const DETONATE_OUT: float = 0.09
const DETONATE_SETTLE: float = 0.24
const DETONATE_FLASH: Color = Color(2.4, 2.0, 1.5, 1.0)

var available: bool = false: set = _set_available
var room: Room: set = _set_room

var _spent: bool = false

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

	if room.type == Room.Type.FINAL:
		visuals.scale = Vector2.ONE * FINAL_SCALE

	_refresh_art()

## Restores a room the run has already burnt past: sealed art, no animation.
func show_spent() -> void:
	_spent = true
	_refresh_art()

## Blows the room open and swaps it to its spent face, animated.
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

	if available:
		await get_tree().create_timer(randf_range(.0, .25)).timeout
		animation_player.play("highlight")
	elif not room.selected:
		animation_player.play("RESET")

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

func _texture_for_room() -> Texture2D:
	if room.type == Room.Type.LEVEL:
		var pair: Array = LEVEL_FACES[_variant() % LEVEL_FACES.size()]
		return pair[FACE_SPENT] if _spent else pair[FACE_OPEN]

	return ROOM_ART.get(room.type, ROOM_ART[Room.Type.NOT_ASSIGNED])

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
