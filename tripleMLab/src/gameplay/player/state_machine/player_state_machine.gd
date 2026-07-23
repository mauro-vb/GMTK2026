extends Node
class_name PlayerStateMachine

@export var initial_state_path: NodePath

var current_state: PlayerState
var states: Dictionary = {}

func setup(player: CharacterBody2D, stats: PlayerStats) -> void:
	for child in get_children():
		if child is PlayerState:
			states[child.name] = child
			child.setup(player, stats)
			child.transitioned.connect(_on_state_transitioned)

	current_state = get_node(initial_state_path) if initial_state_path else get_children()[0]
	current_state.enter()

func physics_update(delta: float) -> void:
	if current_state:
		current_state.physics_update(delta)

func _on_state_transitioned(new_state_name: String) -> void:
	var new_state: PlayerState = states.get(new_state_name)
	if new_state == null or new_state == current_state:
		return
	current_state.exit()
	current_state = new_state
	current_state.enter()
