extends Node
class_name PlayerState

enum STATE_ID { IDLE, RUN, JUMP, FALL, POGO }

@warning_ignore("unused_signal")
signal transitioned(new_state_id: PlayerState.STATE_ID)

var player: CharacterBody2D
var stats: PlayerStats

func setup(_player: CharacterBody2D, _stats: PlayerStats) -> void:
	player = _player
	stats = _stats

func get_state_id() -> PlayerState.STATE_ID:
	push_error("get_state_id() not implemented for %s" % get_class())
	return STATE_ID.IDLE
	
func enter() -> void:
	pass

func exit() -> void:
	pass

func physics_update(_delta: float) -> void:
	pass
