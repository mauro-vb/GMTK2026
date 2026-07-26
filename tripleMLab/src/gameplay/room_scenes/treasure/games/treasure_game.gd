class_name TreasureGame
extends Control
## Base for the three ways a chest can be opened.
##
## A minigame is a *presentation of a [TreasureTable]* and nothing more. It never
## invents an outcome: it asks the table to roll, and then spends its animation
## arriving somewhere that shows the player the same answer. That is what lets
## one chest be played three ways, and what stops a wheel's wedges from ever
## disagreeing with the odds the chest advertised on the map.
##
## Every game is drawn procedurally out of [TreasureStyle], with `_draw()` reading
## its geometry off whatever size the room's board slot ends up at. Art drops in
## where a game exports a texture (the coin's two faces, the plinko ball) and is
## never required: a null texture falls back to the shape underneath it.
##
## The player-facing rule they share: **the player commits before the outcome is
## rolled.** Calling a side, choosing a slot, letting go of the spin — the roll
## happens after the input, so the choice is real.

# Signals
## The outcome, once the animation has finished selling it. The room turns this
## into seconds; the game never touches the clock itself.
signal resolved(slice: TreasureSlice)
## What the player should be doing right now, for the room's header to print.
signal prompt_changed(prompt: String)

# Enums
# Constants

# Exports

# Public
var table: TreasureTable

# Private
## Whatever is currently moving. The base redraws while it runs, so a subclass
## only has to tween its own numbers and draw them.
var _animation: Tween
var _finished: bool = false

# On Ready

# Static

# Lifecycle
func _ready() -> void:
	# The board is sized by the room's layout, and everything a game draws is a
	# fraction of that size, so a resize is a redraw.
	resized.connect(queue_redraw)
	# Nothing a game draws belongs outside the board it is drawn on. Cheap
	# insurance: a stale coordinate is then an invisible bug rather than a coin
	# sitting in the middle of the room's chrome.
	clip_contents = true

	# Built here rather than in setup() because a game's own controls are
	# @onready children: they don't exist until the game is in the tree, and the
	# room has to be able to ask can_present() before it puts it there.
	if table != null:
		_build()


func _process(_delta: float) -> void:
	if _animation != null and _animation.is_valid():
		queue_redraw()

# Public
## Hands the game its chest, before it goes into the tree. The game builds itself
## out of the table when it gets there (see `_ready`), and nothing is playable
## until [method begin] is called.
func setup(p_table: TreasureTable) -> void:
	table = p_table


## Whether this game can present the table it was given at all. The coin needs
## exactly two outcomes to have two faces; the others cope with any table. The
## room asks before it commits to a game, so an awkward table falls through to
## one that can show it rather than being drawn wrong.
func can_present() -> bool:
	return table != null and table.is_valid()


## Opens the game up to the player. Called by the room once it has faded in, so
## nothing is clickable underneath a fade.
func begin() -> void:
	pass

# Private
func _build() -> void:
	pass


## Says what the player should do next. Kept as a signal rather than a label of
## its own so the room's header is the only place instructions ever appear.
func _announce(prompt: String) -> void:
	prompt_changed.emit(prompt)


## One outcome per game, guarded: a stray second input during a spin can't
## resolve a chest twice.
func _finish(slice: TreasureSlice) -> void:
	if _finished:
		return

	_finished = true
	resolved.emit(slice)


## Mirrors [WorkshopCard]'s tween handling: kill whatever was running before
## starting the next thing, so two animations can't fight over the same numbers.
func _restart_animation() -> Tween:
	if _animation != null and _animation.is_valid():
		_animation.kill()

	_animation = create_tween()
	return _animation


func _wait(seconds: float) -> void:
	await get_tree().create_timer(maxf(seconds, 0.0)).timeout


## Text centred on a point rather than left-aligned from one. Used for every
## label a game draws, because all of them label a *thing* — a wedge, a bin, a
## coin face — rather than a line of prose.
func _draw_centered_text(text: String, centre: Vector2, font: Font, font_size: int, color: Color) -> void:
	var extents: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	var origin: Vector2 = Vector2(
		roundf(centre.x - extents.x * 0.5),
		roundf(centre.y + font.get_ascent(font_size) * 0.5),
	)
	draw_string(font, origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)

# Callbacks
