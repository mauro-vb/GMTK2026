extends PlayerState
class_name StateFall

func physics_update(delta: float) -> void:
	player.apply_horizontal_movement(delta)

	if player.is_on_floor():
		transitioned.emit("StateRun" if Input.get_axis("left", "right") != 0 else "StateIdle")
		return

	if player.can_jump():
		transitioned.emit("StateJump")
