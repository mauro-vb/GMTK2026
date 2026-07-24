class_name LevelExit
extends Area2D

signal reached_exit

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	monitoring = false
	await get_tree().physics_frame
	await get_tree().physics_frame
	monitoring = true
	
func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		reached_exit.emit()
