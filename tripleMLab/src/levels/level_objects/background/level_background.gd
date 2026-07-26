class_name LevelBackground
extends Node2D
## The wall every level is played against.
##
## A pale field, a colonnade standing on whatever floor the level actually has,
## and a sparse scatter of brick. All of it drawn, none of it authored: levels
## are built by hand and there are more of them coming, so the background has to
## be something a level *gets* rather than something a level *contains*.
## `BaseLevel` hangs one of these off every room at load.
##
## The seed comes from the level's own scene path, so a room's wall is its own
## and is the same wall every time you walk back into it. In a game you die in
## and immediately retry, a background that reshuffled on death would read as a
## different room — or as a bug.


# Static
const PILLAR: Texture2D = preload("uid://btuo3f15fwbl5")
const BRICKS: Texture2D = preload("uid://dsel8ij1b6ksp")

const TILE: int = 8

## The pillar sheet, cut into the three pieces a column is made of. The shaft is
## the tileable middle — flecked with red every few pixels, which is why it is
## repeated rather than stretched.
const PILLAR_W: float = 8.0
const CAP: Rect2 = Rect2(0, 0, 8, 2)
const SHAFT: Rect2 = Rect2(0, 2, 8, 20)
const BASE: Rect2 = Rect2(0, 22, 8, 2)

## Every loose brick on the sheet, found by flood fill rather than by grid — the
## sheet is a scatter of decals on four courses, not an atlas, and the widths run
## 3px to 8px. Mixing them is the whole point; a wall of one brick reads as a
## pattern, and a pattern reads as wallpaper.
const BRICK_RECTS: Array[Rect2] = [
	Rect2(0, 0, 3, 2),
	Rect2(4, 0, 8, 2),
	Rect2(13, 0, 6, 2),
	Rect2(20, 0, 6, 2),
	Rect2(5, 3, 3, 2),
	Rect2(9, 3, 3, 2),
	Rect2(14, 3, 4, 2),
	Rect2(6, 6, 6, 2),
	Rect2(13, 6, 6, 2),
	Rect2(20, 6, 8, 2),
	Rect2(14, 9, 4, 2),
	Rect2(20, 9, 3, 2),
	Rect2(24, 9, 3, 2),
]

# Exports

## Not pure white. The terrain's top edge is `#e1eed8`, which is within a
## whisker of white — on `#ffffff` every platform loses its cap and the level
## flattens into navy blocks. This leans warm and pink, away from the terrain's
## green, so the bone edge still reads.
@export var field_color: Color = Color("f5ece6")

## Pillars land on a multiple of `TILE`, so a column never sits half a pixel off
## the grid the rest of the art is drawn on.
@export var pillar_spacing_min: int = 48
@export var pillar_spacing_max: int = 80

## Columns are bounded rather than run floor-to-ceiling. A pillar that leaves the
## top of the screen loses its capital, and a shaft with no capital and no base
## is a pole — it reads as scaffolding standing in the play area instead of as
## masonry standing behind it. Given in whole tiles, varied per column so the
## colonnade has a skyline.
@export var pillar_tiles_min: int = 5
@export var pillar_tiles_max: int = 11

## The background's whole job is to be behind something. Both of these are held
## well back on purpose: at full strength the colonnade competes with the orbs,
## and the orbs are what the player is reading.
@export_range(0.0, 1.0) var pillar_alpha: float = 0.5
@export_range(0.0, 1.0) var brick_alpha: float = 0.38

## Chance that any given 32x24 patch of open wall gets a brick.
@export_range(0.0, 1.0) var brick_density: float = 0.45


# State
var _tiles: TileMapLayer
var _bounds: Rect2i


# Lifecycle
func _ready() -> void:
	# Behind the level's own children, and behind the player — who lives under a
	# different root entirely, at z 0.
	z_index = -100
	_tiles = _find_tile_layer()
	_bounds = _resolve_bounds()
	queue_redraw()


func _draw() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _resolve_seed()

	draw_rect(Rect2(_bounds), field_color)

	# Bricks first, then the colonnade over them: a column is masonry standing in
	# front of the wall, not lying flush with it.
	_draw_bricks(rng)
	_draw_colonnade(rng)


# Drawing
func _draw_colonnade(rng: RandomNumberGenerator) -> void:
	var tint := Color(1.0, 1.0, 1.0, pillar_alpha)
	var x: int = _bounds.position.x + rng.randi_range(TILE, pillar_spacing_max)

	while x < _bounds.end.x:
		var snapped_x: int = int(floor(float(x) / TILE)) * TILE
		var bottom: float = _floor_at(snapped_x)
		var height: int = rng.randi_range(pillar_tiles_min, pillar_tiles_max) * TILE
		var top: float = maxf(float(_bounds.position.y), bottom - height)
		# A column buried in solid tile has nothing to show, and a stub too short
		# to take a capital and a base is just a smudge.
		if bottom - top >= CAP.size.y + BASE.size.y + TILE:
			_draw_pillar(float(snapped_x), top, bottom, tint)
		x += rng.randi_range(pillar_spacing_min, pillar_spacing_max)


## One column, from `top` down to `bottom`, built the way a column is built:
## capital, as many drums of shaft as the gap takes, base sitting on the floor.
func _draw_pillar(x: float, top: float, bottom: float, tint: Color) -> void:
	draw_texture_rect_region(PILLAR, Rect2(x, top, PILLAR_W, CAP.size.y), CAP, tint)
	draw_texture_rect_region(
		PILLAR, Rect2(x, bottom - BASE.size.y, PILLAR_W, BASE.size.y), BASE, tint
	)

	var y: float = top + CAP.size.y
	var shaft_end: float = bottom - BASE.size.y
	while y < shaft_end:
		# The last drum is clipped rather than squashed — the flecks stay on the
		# pixel grid that way.
		var h: float = minf(SHAFT.size.y, shaft_end - y)
		var region := Rect2(SHAFT.position, Vector2(SHAFT.size.x, h))
		draw_texture_rect_region(PILLAR, Rect2(x, y, PILLAR_W, h), region, tint)
		y += h


func _draw_bricks(rng: RandomNumberGenerator) -> void:
	var tint := Color(1.0, 1.0, 1.0, brick_alpha)
	const CELL_W: int = 32
	const CELL_H: int = 24

	var y: int = _bounds.position.y
	while y < _bounds.end.y:
		var x: int = _bounds.position.x
		while x < _bounds.end.x:
			if rng.randf() < brick_density:
				var at := Vector2(
					x + rng.randi_range(0, CELL_W - 8), y + rng.randi_range(0, CELL_H - 2)
				)
				# Brick behind terrain is brick nobody sees. Skipping it keeps the
				# density the player actually reads even across a cluttered level.
				if not _is_solid_at(at):
					var brick: Rect2 = BRICK_RECTS[rng.randi_range(0, BRICK_RECTS.size() - 1)]
					draw_texture_rect_region(BRICKS, Rect2(at, brick.size), brick, tint)
			x += CELL_W
		y += CELL_H


# Terrain queries
## The top of the stack of solid tiles at the bottom of this column, in pixels —
## the floor a pillar in that column would stand on. Falls back to the bottom of
## the room where the column has no floor at all.
func _floor_at(x: int) -> float:
	if _tiles == null:
		return float(_bounds.end.y)

	var tx: int = int(floor(float(x) / TILE))
	var ty: int = int(floor(float(_bounds.end.y) / TILE)) - 1
	var lowest: int = int(floor(float(_bounds.position.y) / TILE))
	while ty >= lowest and _tiles.get_cell_source_id(Vector2i(tx, ty)) != -1:
		ty -= 1
	return float((ty + 1) * TILE)


func _is_solid_at(point: Vector2) -> bool:
	if _tiles == null:
		return false
	var cell := Vector2i(int(floor(point.x / TILE)), int(floor(point.y / TILE)))
	return _tiles.get_cell_source_id(cell) != -1


# Resolution
func _find_tile_layer() -> TileMapLayer:
	var room := get_parent()
	if room == null:
		return null
	for child in room.get_children():
		if child is TileMapLayer:
			return child
	return null


## The screen, widened to cover the tilemap if a level ever outgrows it.
func _resolve_bounds() -> Rect2i:
	var screen := Rect2i(
		0,
		0,
		int(ProjectSettings.get_setting("display/window/size/viewport_width", 320)),
		int(ProjectSettings.get_setting("display/window/size/viewport_height", 180))
	)
	if _tiles == null:
		return screen

	var used: Rect2i = _tiles.get_used_rect()
	if used.size == Vector2i.ZERO:
		return screen
	return screen.merge(Rect2i(used.position * TILE, used.size * TILE))


func _resolve_seed() -> int:
	var room := get_parent()
	if room == null:
		return 0
	var key: String = room.scene_file_path
	if key.is_empty():
		key = room.name
	return hash(key)
