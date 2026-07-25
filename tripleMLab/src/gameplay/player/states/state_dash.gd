extends PlayerState
class_name StateDash

var _dash_timer: float = 0.0
var _dash_direction: float = 1.0

func get_state_id() -> PlayerState.STATE_ID:
	return PlayerState.STATE_ID.DASH

func enter() -> void:
	_dash_direction = player.get_dash_direction()
	_dash_timer = stats.dash_duration
	player.is_dashing = true
	player.velocity.y = 0.0 
	player.velocity.x = stats.dash_speed * _dash_direction
	player.consume_dash()
	player.play_dash_animation()
	
func exit() -> void:
	player.is_dashing = false
	var carry_speed: float = stats.move_speed
	player.velocity.x = clamp(player.velocity.x, -carry_speed, carry_speed)

func physics_update(delta: float) -> void:
	_dash_timer -= delta
	player.velocity.x = stats.dash_speed * _dash_direction
	player.velocity.y = 0.0

	if player.can_pogo():
		transitioned.emit(PlayerState.STATE_ID.POGO)
		return

	if _dash_timer <= 0.0:
		if player.is_on_floor():
			transitioned.emit(PlayerState.STATE_ID.RUN if player.get_movement_direction() != 0 else PlayerState.STATE_ID.IDLE)
		else:
			transitioned.emit(PlayerState.STATE_ID.FALL)
