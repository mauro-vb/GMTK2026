extends PlayerState
class_name StateJump

func get_state_id() -> PlayerState.STATE_ID:
	return PlayerState.STATE_ID.JUMP

func enter() -> void:
	player.velocity.y = stats.jump_velocity
	player.consume_jump()

func physics_update(delta: float) -> void:
	player.apply_horizontal_movement(delta)

	if player.velocity.y >= 0:
		transitioned.emit(PlayerState.STATE_ID.FALL)
