class_name TimeSystem
extends Node

# Signals
signal time_changed(current_time: float)
signal max_time_changed
signal time_expired

# Constants
const STARTING_TIME: float = 60.0

# Exports

# Public
## Whether the countdown is currently running. Controlled by MainGame per room
## (see Room.should_tick_time).
var ticking: bool = false: set = _set_ticking

## Current amount of time remaining.
var current_time: float: set = _set_current_time

## Maximum amount of time the player can have.
var max_time: float = STARTING_TIME: set = _set_max_time

## Multiplier applied to time drain.
## 1.0 = normal
## 0.5 = twice as slow
## 2.0 = twice as fast
## 0.0 = paused
var tick_rate: float = 1.0

# Private
var _expired_emitted: bool = false

# On Ready

# Lifecycle
func _ready() -> void:
	current_time = max_time

func _process(delta: float) -> void:
	if not ticking:
		return

	current_time = max(current_time - delta * tick_rate, 0.0)

	if current_time == 0.0 and not _expired_emitted:
		_expired_emitted = true
		ticking = false
		time_expired.emit()

# Public
func add_time(amount: float) -> void:
	current_time += amount

func add_max_time(amount: float) -> void:
	max_time = max_time + amount
	current_time = min(current_time + amount, max_time)

func remove_time(amount: float) -> void:
	current_time = max(current_time - amount, 0.0)

func reset() -> void:
	current_time = max_time
	_expired_emitted = false
	ticking = false


# Private
func _set_ticking(value: bool) -> void:
	ticking = value and not _expired_emitted
	
func _set_current_time(value: float) -> void:
	value = clampf(value, 0.0, max_time)
	if is_equal_approx(current_time, value):
		return
	current_time = value
	time_changed.emit(current_time)
	
func _set_max_time(value: float) -> void:
	max_time = value
	max_time_changed.emit()
	current_time = min(current_time, max_time)
	

# Callbacks
