extends PlayerState
class_name StateJump

func enter() -> void:
	player.velocity.y = stats.jump_velocity
	player.consume_jump()

func physics_update(delta: float) -> void:
	player.apply_horizontal_movement(delta)

	if Input.is_action_just_released("jump") and player.velocity.y < 0:
		player.velocity.y *= stats.jump_cut_multiplier

	if player.velocity.y >= 0:
		transitioned.emit("StateFall")
