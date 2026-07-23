extends Node
class_name PlayerState

signal transitioned(new_state_name: String)

var player: CharacterBody2D
var stats: PlayerStats

func setup(_player: CharacterBody2D, _stats: PlayerStats) -> void:
	player = _player
	stats = _stats

func enter() -> void:
	pass

func exit() -> void:
	pass

func physics_update(_delta: float) -> void:
	pass
