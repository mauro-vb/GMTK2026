class_name BaseLevel
extends RoomScene

@onready var player_spawn: PlayerSpawn = %PlayerSpawn
@onready var level_exit: LevelExit = %LevelExit


func _ready() -> void:
	assert(player_spawn != null, "Level is missing a PlayerSpawn node.")
	assert(level_exit != null, "Level is missing a LevelExit node.")

	
	_place_player_at_spawn()
	level_exit.reached_exit.connect(_on_exit_reached)


func _place_player_at_spawn() -> void:
	var player: Player = Global.main_game.player
	if player == null:
		push_error("Cannot place player at spawn, Global.main_game.player is null")
		return
	
	player.global_position = player_spawn.global_position


func _on_exit_reached() -> void:
	exit()
