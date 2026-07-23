class_name LevelExit
extends Area2D

signal reached_exit

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	
func _on_body_entered(_body: Node2D) -> void:
	reached_exit.emit()
