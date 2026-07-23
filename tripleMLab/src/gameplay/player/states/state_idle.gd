extends PlayerState
class_name StateIdle

func get_state_id() -> PlayerState.STATE_ID:
	return PlayerState.STATE_ID.IDLE
	
func physics_update(delta: float) -> void:
	player.apply_horizontal_movement(delta)

	if not player.is_on_floor():
		transitioned.emit(PlayerState.STATE_ID.FALL)
		return

	if player.can_jump():
		transitioned.emit(PlayerState.STATE_ID.JUMP)
		return

	if player.get_movement_direction() != 0:
		transitioned.emit(PlayerState.STATE_ID.RUN)
