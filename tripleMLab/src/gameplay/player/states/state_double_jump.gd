extends PlayerState
class_name StateDoubleJump

func get_state_id() -> PlayerState.STATE_ID:
	return PlayerState.STATE_ID.DOUBLE_JUMP

func enter() -> void:
	player.velocity.y = stats.double_jump_velocity
	player.consume_double_jump()
	player.play_animation("double_jump")

func physics_update(delta: float) -> void:
	player.apply_horizontal_movement(delta)

	if player.can_dash() and Input.is_action_just_pressed("dash"):
		transitioned.emit(PlayerState.STATE_ID.DASH)
		return
		
	if player.can_pogo():
		transitioned.emit(PlayerState.STATE_ID.POGO)
		return

	if player.velocity.y >= 0:
		transitioned.emit(PlayerState.STATE_ID.FALL)
