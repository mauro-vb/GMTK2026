class_name ScreenTransition
extends ColorRect
## Full-screen fade overlay living permanently on the TransitionLayer.
## MainGame awaits fade_out() before swapping scenes and fade_in() after, so
## room changes never pop instantly. While any fade is covering the screen,
## mouse input is swallowed so the player can't click things mid-swap.

const FADE_TIME: float = 0.2

var _tween: Tween = null


func _ready() -> void:
	modulate.a = 0.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Fades to black. Await before unloading the outgoing scene.
func fade_out(time: float = FADE_TIME) -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	await _fade_to(1.0, time)


## Fades back to transparent. Await after the incoming scene is ready.
func fade_in(time: float = FADE_TIME) -> void:
	await _fade_to(0.0, time)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _fade_to(alpha: float, time: float) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, ^"modulate:a", alpha, time)
	await _tween.finished
