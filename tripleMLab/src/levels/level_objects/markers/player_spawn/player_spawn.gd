@tool
class_name PlayerSpawn
extends Node2D

const PLAYER_PREVIEW = preload("res://src/gameplay/player/Player.tscn")

func _ready():
	if Engine.is_editor_hint():
		add_child(PLAYER_PREVIEW.instantiate())
