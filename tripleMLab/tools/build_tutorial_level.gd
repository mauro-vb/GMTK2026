extends SceneTree
## Builds src/levels/tutorial/TutorialLevel.tscn from the ASCII map below.
##
## The tutorial is the one level whose geometry has to be *exact* — every jump in
## it is sized against PlayerStats, and a tile in the wrong place turns "teach the
## dash" into "the dash is optional". Authoring it as text keeps those distances
## readable and re-tunable: move a character, re-run this, and the terrain
## autotiling is redone from the tileset's terrain rules rather than hand-edited
## into the scene's tile_map_data blob.
##
## Run from the project root:
##   godot --headless --path tripleMLab --script res://tools/build_tutorial_level.gd
##   godot --headless --path tripleMLab --import
##
## The second pass matters: a freshly written .tscn has no uid registered until
## the importer has seen it, and UIDs.TUTORIAL_LEVEL_UID loads it by uid.

const OUT_PATH: String = "res://src/levels/tutorial/TutorialLevel.tscn"

const BASE_LEVEL_SCRIPT: String = "res://src/gameplay/room_scenes/base_level.gd"
const TILESET: String = "res://src/levels/tilesets/level_tileset.tres"
const PLAYER_SPAWN_SCENE: String = "res://src/levels/level_objects/player_spawn/PlayerSpawn.tscn"
const LEVEL_EXIT_SCENE: String = "res://src/levels/level_objects/level_exit/LevelExit.tscn"
const DROP_THROUGH_SCENE: String = "res://src/levels/level_objects/platforms/dropthrough_platforms/DropThroughPlatform.tscn"
const POGOABLE_SCENE: String = "res://src/levels/level_objects/pogoables/Pogoable.tscn"

const TILE: int = 8

## The level, one character per 8x8 tile.
##
##   #  solid terrain      =  drop-through platform      .  empty
##
## Column 0 of the map is tile x = -1 (see MAP_ORIGIN): the side walls are two
## tiles thick with the outer one off-screen, which is what every other level
## does. That is not decoration — the tileset paints terrain from a 3x3
## nine-slice, so anything thinner than two tiles in either direction has no tile
## to match and is silently dropped on the floor by set_cells_terrain_connect.
## Every slab here is 2 tiles thick for that reason.
##
## Read left to right, the course is: ground (move) -> 16px step (jump) -> 48px
## wall (double jump) -> pocket on top of it, roofed in by the pillar (drop
## through) -> a 40px gap under a low ceiling, which caps a jump at 4px of rise
## so only a dash crosses it (dash) -> landing block with a pogo bumper over it,
## bouncing the player onto the exit ledge (pogo). The ledge and the ceiling over
## the gap are the same slab.
##
## Two rules hold the whole thing together:
##   * The ground on row 21 is unbroken, so a missed jump costs a walk back and
##     never a restart.
##   * The way back up is always open from where the player lands: the plateau
##     has head-height under it, so falling into the dash gap leads back to the
##     climb step rather than into a hole.
const MAP: PackedStringArray = [
	#0        1         2         3         4
	#12345678901234567890123456789012345678901
	"..........................................", # 0
	"##.....................##...............##", # 1
	"##.....................##...............##", # 2
	"##.....................##...............##", # 3
	"##.....................##...............##", # 4
	"##.....................##...............##", # 5
	"##.....................##...............##", # 6
	"##.....................##...............##", # 7
	"##.....................##...............##", # 8
	"##.....................##...............##", # 9
	"##.....................##...............##", # 10
	"##.....................##...............##", # 11
	"##.....................#############....##", # 12  exit ledge / dash-corridor roof
	"##.....................#############....##", # 13
	"##.....................##...............##", # 14
	"##.................##==##...............##", # 15  wall top + drop-through pocket
	"##.................##..##..###..........##", # 16  plateau
	"##.................##......###..........##", # 17
	"##.................##....##.............##", # 18  climb step
	"##......###........##....##........#######", # 19  jump step / dash landing
	"##......###........##....##........#######", # 20
	"##########################################", # 21  ground
	"##########################################", # 22
]

## Tile coordinates of MAP's top-left character.
const MAP_ORIGIN: Vector2i = Vector2i(-1, 0)

## Drop-through platforms are placed from the '=' runs in MAP, but the pogo
## bumper, the spawn and the exit are single points that want to sit off the tile
## grid, so they are given in pixels.
const PLAYER_SPAWN_POS: Vector2 = Vector2(28, 160)
const LEVEL_EXIT_POS: Vector2 = Vector2(252, 88)
const POGO_POS: Vector2 = Vector2(300, 128)

## Every hint the level shows, as [text, top-left position, box width].
##
## Each one is parked in open air next to the obstacle it explains rather than
## over it: at 6px the font needs the contrast, and a label on top of terrain at
## this resolution reads as part of the terrain.
const HINTS: Array = [
	["ARROWS\nMOVE", Vector2(8, 130), 80],
	["SPACE\nJUMP", Vector2(44, 112), 64],
	["SPACE AGAIN\nDOUBLE JUMP", Vector2(88, 74), 80],
	["DOWN + SPACE\nDROP THROUGH", Vector2(96, 98), 80],
	["V\nDASH", Vector2(236, 118), 32],
	["C\nPOGO", Vector2(280, 98), 36],
	["EXIT", Vector2(202, 78), 40],
]


func _initialize() -> void:
	var root: Node2D = Node2D.new()
	root.name = "TutorialLevel"
	root.set_script(load(BASE_LEVEL_SCRIPT))
	# No fuse in the tutorial: it is the one room in the game with nothing to
	# lose, so the clock has no business running in it.
	root.set("should_tick_time", false)

	_add_terrain(root)
	_add_drop_through_platforms(root)
	_add_entities(root)
	# Last, so they draw over the terrain rather than under it.
	_add_hints(root)

	_save(root)
	quit()


func _add_terrain(root: Node2D) -> void:
	var layer: TileMapLayer = TileMapLayer.new()
	layer.name = "TileMapLayer"
	layer.tile_set = load(TILESET)
	root.add_child(layer)
	layer.owner = root

	var solid: Array[Vector2i] = []
	for y in MAP.size():
		var row: String = MAP[y]
		for x in row.length():
			if row[x] == "#":
				solid.append(MAP_ORIGIN + Vector2i(x, y))

	# Terrain-connect rather than set_cell: the tileset carries the corner and
	# edge pieces as a terrain set, and painting them by hand means picking atlas
	# coordinates for every one of ~250 cells.
	layer.set_cells_terrain_connect(solid, 0, 0)

	# A cell the terrain has no tile for is dropped without a word, and a hole in
	# a wall the map says is solid is the kind of thing that is only found by
	# falling through it. See MAP on why that happens.
	for cell: Vector2i in solid:
		assert(layer.get_cell_source_id(cell) != -1,
			"No terrain tile matched %s — the shape it belongs to is thinner than two tiles." % cell)


func _add_drop_through_platforms(root: Node2D) -> void:
	var parent: Node2D = Node2D.new()
	parent.name = "Platforms"
	root.add_child(parent)
	parent.owner = root

	var scene: PackedScene = load(DROP_THROUGH_SCENE)
	var index: int = 0
	for y in MAP.size():
		var row: String = MAP[y]
		var x: int = 0
		while x < row.length():
			if row[x] != "=":
				x += 1
				continue

			# A run of '=' is one platform: `size` is in tiles, and its origin is
			# the middle of the run at the top edge of the row (the platform's
			# collision hangs below its position, like the tile surface does).
			var start: int = x
			while x < row.length() and row[x] == "=":
				x += 1
			var length: int = x - start

			var platform: Node2D = scene.instantiate()
			index += 1
			platform.name = "DropThroughPlatform%d" % index
			platform.position = Vector2(
				(MAP_ORIGIN.x + start + length * 0.5) * TILE,
				(MAP_ORIGIN.y + y) * TILE)
			platform.set("size", length)
			parent.add_child(platform)
			platform.owner = root


func _add_entities(root: Node2D) -> void:
	var spawn: Node2D = load(PLAYER_SPAWN_SCENE).instantiate()
	spawn.name = "PlayerSpawn"
	spawn.position = PLAYER_SPAWN_POS
	root.add_child(spawn)
	spawn.owner = root
	# BaseLevel finds both of these with %, so the unique names are load-bearing.
	spawn.unique_name_in_owner = true

	var exit: Node2D = load(LEVEL_EXIT_SCENE).instantiate()
	exit.name = "LevelExit"
	exit.position = LEVEL_EXIT_POS
	root.add_child(exit)
	exit.owner = root
	exit.unique_name_in_owner = true

	var pogos: Node2D = Node2D.new()
	pogos.name = "Pogos"
	root.add_child(pogos)
	pogos.owner = root

	var pogo: Node2D = load(POGOABLE_SCENE).instantiate()
	pogo.name = "PogoArea"
	pogo.position = POGO_POS
	pogos.add_child(pogo)
	pogo.owner = root


func _add_hints(root: Node2D) -> void:
	var parent: Node2D = Node2D.new()
	parent.name = "Hints"
	root.add_child(parent)
	parent.owner = root

	for hint: Array in HINTS:
		var label: Label = Label.new()
		label.name = "Hint%d" % (parent.get_child_count() + 1)
		label.text = hint[0]
		label.position = hint[1]
		label.size = Vector2(hint[2], 20)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.theme_type_variation = &"HintLabel"
		# Nothing here is clickable, and a Control sitting over the play area that
		# eats mouse events is a bug waiting for the first UI added on top.
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(label)
		label.owner = root

	var title: Label = Label.new()
	title.name = "Title"
	title.text = "HOW TO PLAY"
	title.position = Vector2(8, 6)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(title)
	title.owner = root

	var subtitle: Label = Label.new()
	subtitle.name = "Subtitle"
	subtitle.text = "REACH THE DOOR TO GO BACK"
	subtitle.position = Vector2(8, 20)
	subtitle.theme_type_variation = &"HintLabel"
	subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(subtitle)
	subtitle.owner = root


func _save(root: Node2D) -> void:
	DirAccess.make_dir_recursive_absolute(OUT_PATH.get_base_dir())

	var packed: PackedScene = PackedScene.new()
	var packed_result: int = packed.pack(root)
	assert(packed_result == OK, "Failed to pack the tutorial level")

	# Reuse the uid the file already carries rather than minting one per run:
	# UIDs.TUTORIAL_LEVEL_UID names this scene by uid, and a rebuild that changed
	# it would break the menu until somebody noticed and pasted the new one in.
	var uid: int = ResourceLoader.get_resource_uid(OUT_PATH)
	if uid == ResourceUID.INVALID_ID:
		uid = ResourceUID.create_id()

	var save_result: int = ResourceSaver.save(packed, OUT_PATH)
	assert(save_result == OK, "Failed to save the tutorial level")

	ResourceSaver.set_uid(OUT_PATH, uid)
	print("Wrote %s (%s)" % [OUT_PATH, ResourceUID.id_to_text(uid)])
