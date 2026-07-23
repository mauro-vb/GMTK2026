extends Node
class_name PlayerStateMachine

@export var initial_state_id: PlayerState.STATE_ID = PlayerState.STATE_ID.IDLE

var current_state: PlayerState
var states: Dictionary = {}

func setup(player: CharacterBody2D, stats: PlayerStats) -> void:
	for child in get_children():
		if child is PlayerState:
			states[child.get_state_id()] = child
			child.setup(player, stats)
			child.transitioned.connect(_on_state_transitioned)

	current_state = states[initial_state_id]
	current_state.enter()

func physics_update(delta: float) -> void:
	if current_state:
		current_state.physics_update(delta)

func _on_state_transitioned(new_state_id: PlayerState.STATE_ID) -> void:
	var new_state: PlayerState = states.get(new_state_id)
	if new_state == null or new_state == current_state:
		return
	current_state.exit()
	current_state = new_state
	current_state.enter()
