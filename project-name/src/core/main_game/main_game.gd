class_name MainGame
extends Node
## Main entry point for the game
## Responsible for world setup and coordianting high level systems.

# Game World root nodes
@onready var level_root: Node2D = $World/LevelRoot
@onready var entity_root: Node2D = $World/EntityRoot
@onready var effects_root: Node2D = $World/EffectsRoot


func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
