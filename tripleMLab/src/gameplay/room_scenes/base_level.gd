class_name BaseLevel
extends RoomScene

@onready var player_spawn: PlayerSpawn = %PlayerSpawn
@onready var level_exit: LevelExit = %LevelExit


func _ready() -> void:
	assert(player_spawn != null, "Level is missing a PlayerSpawn node.")
	assert(level_exit != null, "Level is missing a LevelExit node.")

	_add_background()
	_place_player_at_spawn()
	level_exit.reached_exit.connect(_on_exit_reached)


## Hung here rather than saved into each level scene, so a room that gets built
## tomorrow is already standing in front of a wall, and so the look of every
## room can be changed in one file instead of seven.
func _add_background() -> void:
	if has_node("LevelBackground"):
		return
	var background := LevelBackground.new()
	background.name = "LevelBackground"
	add_child(background)


func _place_player_at_spawn() -> void:
	if Global.main_game == null:
		return
	var player: Player = Global.main_game.player
	if player == null:
		push_error("Cannot place player at spawn, Global.main_game.player is null")
		return
	
	player.global_position = player_spawn.global_position
	

func _on_exit_reached() -> void:
	exit()
