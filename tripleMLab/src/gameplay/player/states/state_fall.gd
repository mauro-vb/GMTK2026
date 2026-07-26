extends PlayerState
class_name StateFall

func get_state_id() -> PlayerState.STATE_ID:
	return PlayerState.STATE_ID.FALL

func enter() -> void:
	player.play_animation("fall")
	
func physics_update(delta: float) -> void:
	player.apply_horizontal_movement(delta)

	if player.can_dash() and Input.is_action_just_pressed("dash"):
		transitioned.emit(PlayerState.STATE_ID.DASH)
		return
		
	if player.can_pogo():
		transitioned.emit(PlayerState.STATE_ID.POGO)
		return

	if player.is_on_floor():
		transitioned.emit(PlayerState.STATE_ID.RUN if player.get_movement_direction() != 0 else PlayerState.STATE_ID.IDLE)
		return

	if player.can_jump():
		transitioned.emit(PlayerState.STATE_ID.JUMP)
		return

	if player.can_double_jump():
		transitioned.emit(PlayerState.STATE_ID.DOUBLE_JUMP)
