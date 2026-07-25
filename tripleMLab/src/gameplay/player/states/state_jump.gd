extends PlayerState
class_name StateJump

func get_state_id() -> PlayerState.STATE_ID:
	return PlayerState.STATE_ID.JUMP

func enter() -> void:
	player.velocity.y = stats.jump_velocity
	player.consume_jump()
	player.play_animation("jump")

func physics_update(delta: float) -> void:
	player.apply_horizontal_movement(delta)

	if player.can_pogo():
		transitioned.emit(PlayerState.STATE_ID.POGO)
		return

	if player.can_double_jump():
		transitioned.emit(PlayerState.STATE_ID.DOUBLE_JUMP)
		return

	if player.velocity.y >= 0:
		transitioned.emit(PlayerState.STATE_ID.FALL)
