extends PlayerState
class_name StateIdle

func physics_update(delta: float) -> void:
	player.apply_horizontal_movement(delta)

	if not player.is_on_floor():
		transitioned.emit("StateFall")
		return

	if player.can_jump():
		transitioned.emit("StateJump")
		return

	if Input.get_axis("left", "right") != 0:
		transitioned.emit("StateRun")
