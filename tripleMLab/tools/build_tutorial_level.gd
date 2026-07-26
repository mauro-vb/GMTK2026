extends SceneTree
## Builds the tutorial's rooms from the ASCII maps below.
##
## The tutorial is the one place whose geometry has to be *exact* — every jump in
## it is sized against PlayerStats, and a tile in the wrong place turns "teach the
## dash" into "the dash is optional". Authoring it as text keeps those distances
## readable and re-tunable: move a character, re-run this, and the terrain
## autotiling is redone from the tileset's terrain rules rather than hand-edited
## into the scene's tile_map_data blob.
##
## Run from the project root:
##   godot --headless --editor --path tripleMLab --script res://tools/build_tutorial_level.gd
##   godot --headless --path tripleMLab --import
##
## --editor is load-bearing, and the error it avoids is a quiet one. Plain
## --script mode adds the autoloads to the tree but never registers their names
## as global identifiers for the compiler, so Orb's `Global.main_game` fails to
## resolve, orb.gd does not compile, the instantiated orbs come out scriptless,
## and `set("type", ...)` below no-ops — leaving every red orb packed as a blue
## one. Nothing errors; the level is just wrong. Under --editor the autoloads
## register and the type is stored.
##
## The second pass matters too: a freshly written .tscn has no uid registered
## until the importer has seen it, and UIDs.TUTORIAL_ROOM_* load them by uid.
##
## ## Why two rooms
##
## A level is one fixed screen — 320x180, and there is no Camera2D anywhere in
## the game to scroll one. Move, jump, double jump, drop-through, dash, pogo and
## both orbs do not fit in that with any air around them, and the first version
## of this proved it. The course is split in half instead: room one is the ground
## moves and the orbs, room two is dash and pogo. MainGame chains them.
##
## ## Why nothing is hard-gated any more
##
## The original room gated every mechanic — you could not pass the dash without
## dashing. On one screen, against a 55px double jump, every such gate works out
## to about 4px of margin, and 4px is the difference between "teaches you" and
## "traps you". The pogo gate is what players actually got stuck on: the bumper
## sat past the right edge of the exit ledge, so the bounce apexed off the end of
## it and only a frame-perfect apex-pogo made the drift.
##
## So the mechanics are signposted and made the obvious, easy route, and the
## failure of each one drops you somewhere you can simply walk out of. A player
## determined to double-jump past the dash can. That trade is deliberate: this is
## the room where the controls are learned, and nobody may be stuck in it.

const OUT_DIR: String = "res://src/levels/tutorial"

const BASE_LEVEL_SCRIPT: String = "res://src/gameplay/room_scenes/base_level.gd"
const TILESET: String = "res://src/levels/tilesets/level_tileset.tres"
const PLAYER_SPAWN_SCENE: String = "res://src/levels/level_objects/player_spawn/PlayerSpawn.tscn"
const LEVEL_EXIT_SCENE: String = "res://src/levels/level_objects/level_exit/LevelExit.tscn"
const DROP_THROUGH_SCENE: String = "res://src/levels/level_objects/platforms/dropthrough_platforms/DropThroughPlatform.tscn"
const POGOABLE_SCENE: String = "res://src/levels/level_objects/pogoables/Pogoable.tscn"
const ORB_SCENE: String = "res://src/levels/level_objects/orb/Orb.tscn"

const TILE: int = 8

## Every map is this size, which is the size every other level in the game is.
const MAP_WIDTH: int = 42
const MAP_HEIGHT: int = 23

## Tile coordinates of a map's top-left character.
##
## Column 0 is therefore tile x = -1: the side walls are two tiles thick with the
## outer one off-screen, which is what every other level does. That is not
## decoration — the tileset paints terrain from a 3x3 nine-slice, so anything
## thinner than two tiles in either direction has no tile to match and is
## silently dropped by set_cells_terrain_connect. Every slab here is 2 tiles
## thick for that reason.
const MAP_ORIGIN: Vector2i = Vector2i(-1, 0)

# --- The numbers every distance below is measured against ---------------------
# Read off player_stats.tres. Kept here as a comment rather than loaded, because
# they are what the maps were drawn to and a silent change to them should show up
# as "the tutorial stopped making sense", not as a generator that re-tunes itself.
#
#   player box     7 x 12px, feet at origin+8
#   jump           26px of rise
#   double jump    55px of rise total
#   dash           36px flat, y frozen, then the fall carries it further
#   pogo bounce    41px of rise from wherever it triggers
#
# The one consequence worth holding on to: a ceiling 4px over the player's head
# caps a jump at 4px, which is what makes the dash corridor a dash corridor.

## Room one: the ground moves, and the two orbs.
##
##   #  solid terrain      =  drop-through platform      .  empty
##
## Left to right: flat ground (move) -> a 16px step (jump) -> a 48px wall, which
## one jump is 22px short of (double jump) -> a drop-through platform on top of
## that wall with a full-height pillar closing off the way forward, so down+jump
## is the only way on (drop through) -> a red orb sitting in the corridor and a
## blue orb on the block past it (the orbs) -> the door.
##
## The ground on row 21 is unbroken, and every raised thing here can be walked
## off, so a missed jump costs a walk back and never a restart.
const ROOM_1_MAP: PackedStringArray = [
	#0        1         2         3         4
	#12345678901234567890123456789012345678901
	"..........................................", # 0
	"##......................##..............##", # 1
	"##......................##..............##", # 2
	"##......................##..............##", # 3
	"##......................##..............##", # 4
	"##......................##..............##", # 5
	"##......................##..............##", # 6
	"##......................##..............##", # 7
	"##......................##..............##", # 8
	"##......................##..............##", # 9
	"##......................##..............##", # 10
	"##......................##..............##", # 11
	"##......................##..............##", # 12
	"##......................##..............##", # 13
	"##......................##..............##", # 14
	"##..................##==##..............##", # 15  wall top + drop-through
	"##..................##..##..............##", # 16  pillar ends here
	"##..................##..................##", # 17
	"##..................##..................##", # 18
	"##..........###.....##........###.......##", # 19  jump step / orb block
	"##..........###.....##........###.......##", # 20
	"##########################################", # 21  ground
	"##########################################", # 22
]

## Room two: dash and pogo.
##
## Left to right: a 16px step then a 16px step onto the plateau (top at y=136),
## which is roofed 4px over the player's head — a jump there rises 4px and
## crosses 32px, and the gap is 40px, so the dash is the way over. Miss it and
## you drop into the pit (there is a red orb down there, which is the only thing
## missing the dash costs), and hop 16px out of it onto the far terrace.
##
## Then the pogo: the bumper sits at the right-hand edge of that terrace, close
## enough to overlap the player *standing still*, so pressing pogo from a
## standstill is enough to make the exit ledge with 9px to spare. Jumping into it
## first gives 35px. Falling into the gap costs a 16px hop back onto the terrace.
const ROOM_2_MAP: PackedStringArray = [
	#0        1         2         3         4
	#12345678901234567890123456789012345678901
	"..........................................", # 0
	"##......................................##", # 1
	"##......................................##", # 2
	"##......................................##", # 3
	"##......................................##", # 4
	"##......................................##", # 5
	"##......................................##", # 6
	"##......................................##", # 7
	"##......................................##", # 8
	"##......................................##", # 9
	"##......................................##", # 10
	"##......................................##", # 11
	"##...........############...............##", # 12  dash-corridor roof
	"##...........############...............##", # 13
	"##...........############...............##", # 14
	"##..............................##########", # 15  exit ledge
	"##..............................##########", # 16
	"##...........######.....................##", # 17  dash plateau
	"##...........######.....................##", # 18
	"##......###..######.....######..........##", # 19  climb step / landing terrace
	"##......###..######.....######..........##", # 20
	"##########################################", # 21  ground
	"##########################################", # 22
]

## Drop-through platforms are placed from the '=' runs in the map, but spawns,
## exits, bumpers and orbs are single points that want to sit off the tile grid,
## so they are given in pixels.
##
## Each room is [map, out file, spawn, exit, pogo positions, orbs, hints].
## Orbs are [Orb.Type, position]; hints are [text, top-left, box width].
##
## Every hint is parked in open air next to the obstacle it explains rather than
## over it: at 6px the font needs the contrast, and a label on top of terrain at
## this resolution reads as part of the terrain.
##
## The key names are copied from project.godot's [input] map and nothing checks
## them, so a remap silently turns this room into a liar. As of writing: move is
## the arrow keys, `jump` is SPACE (or Z), `dash` is C, and the pogo is the
## `attack` action on X — note the name, it is not called "pogo".
func _rooms() -> Array[Dictionary]:
	return [
		{
			"map": ROOM_1_MAP,
			"path": OUT_DIR + "/TutorialLevel.tscn",
			"title": "HOW TO PLAY",
			"subtitle": "REACH THE DOOR TO GO ON",
			"spawn": Vector2(24, 160),
			"exit": Vector2(300, 160),
			"pogos": [] as Array[Vector2],
			"orbs": [
				[Orb.Type.HOT, Vector2(214, 162)],
				[Orb.Type.COLD, Vector2(244, 144)],
			],
			"hints": [
				["ARROWS\nMOVE", Vector2(16, 132), 56],
				["SPACE\nJUMP", Vector2(76, 112), 48],
				["SPACE AGAIN\nDOUBLE JUMP", Vector2(88, 72), 80],
				["DOWN + SPACE\nDROP THROUGH", Vector2(100, 98), 80],
				["RED ORB\n-2 SEC", Vector2(202, 118), 48],
				["BLUE ORB\n+2 SEC", Vector2(254, 96), 52],
			],
		},
		{
			"map": ROOM_2_MAP,
			"path": OUT_DIR + "/TutorialLevel2.tscn",
			"title": "HOW TO PLAY",
			"subtitle": "REACH THE DOOR TO FINISH",
			"spawn": Vector2(24, 160),
			"exit": Vector2(288, 112),
			"pogos": [Vector2(236, 140)] as Array[Vector2],
			"orbs": [
				[Orb.Type.HOT, Vector2(164, 162)],
				[Orb.Type.COLD, Vector2(292, 160)],
			],
			"hints": [
				["C\nDASH", Vector2(140, 64), 48],
				["-2 SEC", Vector2(146, 128), 36],
				["X\nPOGO", Vector2(206, 88), 52],
				["EXIT", Vector2(266, 96), 40],
				["+2 SEC", Vector2(252, 142), 36],
			],
		},
	]


func _initialize() -> void:
	for room: Dictionary in _rooms():
		_build(room)
	quit()


func _build(room: Dictionary) -> void:
	var map: PackedStringArray = room["map"]
	_validate(map, room["path"])

	var root: Node2D = Node2D.new()
	# Named off the file rather than a constant: the rooms are loaded back to
	# back and the outgoing one is only queued for free, so two roots sharing a
	# name means the second gets renamed to something like @Node2D@2 on the way in.
	root.name = room["path"].get_file().get_basename()
	root.set_script(load(BASE_LEVEL_SCRIPT))
	# No fuse in the tutorial: it is the one room in the game with nothing to
	# lose, so the clock has no business running in it.
	root.set("should_tick_time", false)

	_add_terrain(root, map)
	_add_drop_through_platforms(root, map)
	_add_entities(root, room)
	# Last, so they draw over the terrain rather than under it.
	_add_hints(root, room)

	_save(root, room["path"])


## Catches the two mistakes a hand-edited map actually makes: a row that is the
## wrong length (which silently shifts everything after it) and a shape thinner
## than the terrain's nine-slice can paint.
func _validate(map: PackedStringArray, path: String) -> void:
	assert(map.size() == MAP_HEIGHT,
		"%s: map is %d rows, expected %d" % [path, map.size(), MAP_HEIGHT])
	for y in map.size():
		assert(map[y].length() == MAP_WIDTH,
			"%s: row %d is %d characters, expected %d" % [path, y, map[y].length(), MAP_WIDTH])


func _add_terrain(root: Node2D, map: PackedStringArray) -> void:
	var layer: TileMapLayer = TileMapLayer.new()
	layer.name = "TileMapLayer"
	layer.tile_set = load(TILESET)
	root.add_child(layer)
	layer.owner = root

	var solid: Array[Vector2i] = []
	for y in map.size():
		var row: String = map[y]
		for x in row.length():
			if row[x] == "#":
				solid.append(MAP_ORIGIN + Vector2i(x, y))

	# Terrain-connect rather than set_cell: the tileset carries the corner and
	# edge pieces as a terrain set, and painting them by hand means picking atlas
	# coordinates for every one of ~250 cells.
	layer.set_cells_terrain_connect(solid, 0, 0)

	# A cell the terrain has no tile for is dropped without a word, and a hole in
	# a wall the map says is solid is the kind of thing that is only found by
	# falling through it. See MAP_ORIGIN on why that happens.
	for cell: Vector2i in solid:
		assert(layer.get_cell_source_id(cell) != -1,
			"No terrain tile matched %s — the shape it belongs to is thinner than two tiles." % cell)


func _add_drop_through_platforms(root: Node2D, map: PackedStringArray) -> void:
	var parent: Node2D = Node2D.new()
	parent.name = "Platforms"
	root.add_child(parent)
	parent.owner = root

	var scene: PackedScene = load(DROP_THROUGH_SCENE)
	var index: int = 0
	for y in map.size():
		var row: String = map[y]
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


func _add_entities(root: Node2D, room: Dictionary) -> void:
	var spawn: Node2D = load(PLAYER_SPAWN_SCENE).instantiate()
	spawn.name = "PlayerSpawn"
	spawn.position = room["spawn"]
	root.add_child(spawn)
	spawn.owner = root
	# BaseLevel finds both of these with %, so the unique names are load-bearing.
	spawn.unique_name_in_owner = true

	var exit: Node2D = load(LEVEL_EXIT_SCENE).instantiate()
	exit.name = "LevelExit"
	exit.position = room["exit"]
	root.add_child(exit)
	exit.owner = root
	exit.unique_name_in_owner = true

	var pogos: Node2D = Node2D.new()
	pogos.name = "Pogos"
	root.add_child(pogos)
	pogos.owner = root

	for pogo_position: Vector2 in room["pogos"]:
		var pogo: Node2D = load(POGOABLE_SCENE).instantiate()
		pogo.name = "PogoArea%d" % (pogos.get_child_count() + 1)
		pogo.position = pogo_position
		pogos.add_child(pogo)
		pogo.owner = root

	var orbs: Node2D = Node2D.new()
	orbs.name = "Orbs"
	root.add_child(orbs)
	orbs.owner = root

	var orb_scene: PackedScene = load(ORB_SCENE)
	for entry: Array in room["orbs"]:
		var orb: Node2D = orb_scene.instantiate()
		orb.name = "Orb%d" % (orbs.get_child_count() + 1)
		# The sprite is picked in Orb._ready(): the setter here runs before the
		# node is in a tree, so %Sprite2D is still null and it no-ops. Only the
		# type is being stored, which is all the packed scene needs to carry.
		orb.set("type", entry[0])
		orb.position = entry[1]
		orbs.add_child(orb)
		orb.owner = root


func _add_hints(root: Node2D, room: Dictionary) -> void:
	var parent: Node2D = Node2D.new()
	parent.name = "Hints"
	root.add_child(parent)
	parent.owner = root

	for hint: Array in room["hints"]:
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
	title.text = room["title"]
	title.position = Vector2(8, 6)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(title)
	title.owner = root

	var subtitle: Label = Label.new()
	subtitle.name = "Subtitle"
	subtitle.text = room["subtitle"]
	subtitle.position = Vector2(8, 20)
	subtitle.theme_type_variation = &"HintLabel"
	subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(subtitle)
	subtitle.owner = root


func _save(root: Node2D, path: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())

	var packed: PackedScene = PackedScene.new()
	var packed_result: int = packed.pack(root)
	assert(packed_result == OK, "Failed to pack %s" % path)

	# Reuse the uid the file already carries rather than minting one per run:
	# UIDs names these scenes by uid, and a rebuild that changed one would break
	# the menu until somebody noticed and pasted the new one in.
	var uid: int = ResourceLoader.get_resource_uid(path)
	if uid == ResourceUID.INVALID_ID:
		uid = ResourceUID.create_id()

	var save_result: int = ResourceSaver.save(packed, path)
	assert(save_result == OK, "Failed to save %s" % path)

	ResourceSaver.set_uid(path, uid)
	print("Wrote %s (%s)" % [path, ResourceUID.id_to_text(uid)])
