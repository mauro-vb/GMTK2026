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
##
## Read this freely; don't assign to it. It is the product of every registered
## contribution (see [method set_rate_contribution]) and is recomputed whenever
## one of those changes, so a direct write is silently thrown away at the next
## change.
var tick_rate: float = 1.0

# Private
var _expired_emitted: bool = false

## Every modifier currently scaling the clock, keyed per instance.
##
## This replaces each modifier saving and restoring `tick_rate` around itself.
## That worked for one at a time and broke as soon as two overlapped: whoever
## expired last restored the snapshot it took on the way in, which was already
## somebody else's altered value. A freeze (rate 0) overlapping a slow-burn was
## the bad case — the slow-burn snapshotted 0, and when it expired it put 0 back
## and the clock never ticked again for the rest of the run.
##
## Multiplying a list has no ordering to get wrong: a contribution only ever
## adds or removes itself, and the rate is derived from whatever is left.
var _rate_contributions: Dictionary[StringName, float] = {}

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

## Registers (or replaces) one modifier's multiplier on the clock. `key` must be
## unique per modifier *instance*, so two stacks of the same modifier each count.
func set_rate_contribution(key: StringName, multiplier: float) -> void:
	_rate_contributions[key] = multiplier
	_refresh_tick_rate()

## Drops a contribution. Safe to call for a key that was never registered.
func clear_rate_contribution(key: StringName) -> void:
	if not _rate_contributions.erase(key):
		return
	_refresh_tick_rate()

func reset() -> void:
	current_time = max_time
	_expired_emitted = false
	ticking = false
	_rate_contributions.clear()
	_refresh_tick_rate()


# Private
func _refresh_tick_rate() -> void:
	var rate: float = 1.0
	for contribution: float in _rate_contributions.values():
		rate *= contribution

	tick_rate = rate

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
