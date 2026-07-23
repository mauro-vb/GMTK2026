extends PlayerState
class_name StateRun

func get_state_id() -> PlayerState.ID:
	return PlayerState.ID.RUN

func physics_update(delta: float) -> void:
	player.apply_horizontal_movement(delta)

	if not player.is_on_floor():
		transitioned.emit(PlayerState.ID.FALL)
		return

	if player.can_jump():
		transitioned.emit(PlayerState.ID.JUMP)
		return

	if Input.get_axis("left", "right") == 0:
		transitioned.emit(PlayerState.ID.IDLE)
