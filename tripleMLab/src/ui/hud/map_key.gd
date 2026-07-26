class_name MapKey
extends Control
## The little card in the corner of the map that says what the room icons mean.
##
## Folded away by default, and not out of shyness: the map screen is 320x180 and
## a room icon is 20x23, so four of them with labels beside them is a third of
## the screen. A player who has already learned the icons should not have to look
## at that all run — so it rests as a KEY tab in the bottom-right corner and
## unfolds only while the cursor is on it.
##
## Both halves take mouse input ([constant Control.MOUSE_FILTER_STOP]), which is
## also what stops a click meant for the key from falling through onto whatever
## room happens to sit behind it.

## How far the card is offset to the right before it settles, i.e. it slides in
## from under the corner. Small: this is a 320-wide screen and the card only has
## a few pixels of margin to travel across.
const SLIDE: float = 4.0
const UNFOLD_TIME: float = 0.1
## Folding is quicker than unfolding — the card is on its way out and the player
## has already moved on to the map.
const FOLD_TIME: float = 0.07

@onready var chip: PanelContainer = %Chip
@onready var card: PanelContainer = %Card

## Where [member card] rests once laid out. The card is anchored into the
## corner, so this is only true after the container has worked out how big it is.
var _card_home: Vector2
var _tween: Tween


func _ready() -> void:
	card.hide()
	card.modulate.a = 0.0

	chip.mouse_entered.connect(_unfold)
	# The whole card is one rect and it covers the chip, so leaving it is the
	# only exit — crossing from the chip up into the card never leaves anything.
	card.mouse_exited.connect(_fold)
	visibility_changed.connect(_on_visibility_changed)

	await get_tree().process_frame
	_card_home = card.position

func _unfold() -> void:
	if card.visible:
		return

	if _tween:
		_tween.kill()

	chip.hide()
	card.show()
	_slide(SLIDE)
	card.modulate.a = 0.0

	_tween = create_tween().set_parallel()
	_tween.tween_property(card, ^"modulate:a", 1.0, UNFOLD_TIME)
	_tween.tween_method(_slide, SLIDE, 0.0, UNFOLD_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _fold() -> void:
	if not card.visible:
		return

	if _tween:
		_tween.kill()

	_tween = create_tween().set_parallel()
	_tween.tween_property(card, ^"modulate:a", 0.0, FOLD_TIME)
	_tween.tween_method(_slide, 0.0, SLIDE, FOLD_TIME)
	_tween.chain().tween_callback(_rest)

func _rest() -> void:
	card.hide()
	chip.show()

## Floored, because the card is a pixel-art panel and a stylebox landing on half
## a pixel is where the nine-slice corners start shimmering.
func _slide(amount: float) -> void:
	card.position = (_card_home + Vector2(amount, 0.0)).floor()

## The map is hidden wholesale while a room is being played. Coming back to it
## with the card still spread open — and no cursor anywhere near it — would leave
## nothing able to close it, since the exit is a mouse event that already fired.
func _on_visibility_changed() -> void:
	if visible:
		return

	if _tween:
		_tween.kill()

	_rest()
