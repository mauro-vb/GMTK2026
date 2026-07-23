class_name PlatformingLevel
extends BaseLevel

@onready var player_spawn: PlayerSpawn = %PlayerSpawn

func _ready() -> void:
	assert(player_spawn != null, "Level is missing a PlayerSpawn node.")
	
func get_default_player_spawn() -> Vector2:
	return player_spawn.global_position
