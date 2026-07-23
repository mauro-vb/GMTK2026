class_name PlatformingLevel
extends BaseLevel

@onready var player_spawn: PlayerSpawn = %PlayerSpawn
@onready var level_exit: LevelExit = %LevelExit

func _ready() -> void:
	assert(player_spawn != null, "Level is missing a PlayerSpawn node.")
	assert(level_exit != null, "Level is missing a LevelExit node.")
	level_exit.reached_exit.connect(_on_exit_reached)
	
func get_default_player_spawn() -> Vector2:
	return player_spawn.global_position

func _on_exit_reached() -> void:
	Global.main_game.exit_room()
