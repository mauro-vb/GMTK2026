extends PlayerState
class_name StateRun

func get_state_id() -> PlayerState.STATE_ID:
	return PlayerState.STATE_ID.RUN

func enter() -> void:
	player.play_animation("run")

func physics_update(delta: float) -> void:
	player.apply_horizontal_movement(delta)

	if player.can_dash() and Input.is_action_just_pressed("dash"):
		transitioned.emit(PlayerState.STATE_ID.DASH)
		return
		
	if player.can_pogo():
		transitioned.emit(PlayerState.STATE_ID.POGO)
		return

	if not player.is_on_floor():
		transitioned.emit(PlayerState.STATE_ID.FALL)
		return

	# Checked before the jump so down + jump drops through instead of jumping
	if player.can_drop_through():
		player.consume_drop_through()
		transitioned.emit(PlayerState.STATE_ID.FALL)
		return

	if player.can_jump():
		transitioned.emit(PlayerState.STATE_ID.JUMP)
		return

	if player.get_movement_direction() == 0:
		transitioned.emit(PlayerState.STATE_ID.IDLE)
