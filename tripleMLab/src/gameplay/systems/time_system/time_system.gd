class_name TimeSystem
extends Node

# Signals
signal time_changed(current_time: float)
signal tick_rate_changed(current_tick_rate: float)
signal max_time_changed
signal time_expired
signal ticking_changed(ticking: bool)

# Constants
const STARTING_TIME: float = 60.0

## Placeholder sfx from the team. clock_down is the ambient tick (while
## [member ticking]) and the loss flourish (see [method remove_time]); clock_up
## only ever plays the gain flourish, since there's no ambient equivalent for
## a gain.
const TICK_SFX: AudioStreamWAV = preload("res://assets/audio/sfx/clock_down.wav")
const GAIN_SFX: AudioStreamWAV = preload("res://assets/audio/sfx/clock_up.wav")
const TICK_VOLUME_DB: float = -14.0
const BURST_VOLUME_DB: float = -6.0

## Retrigger interval for the ambient tick, at tick_rate 1.0 — a real clock's
## second hand, not the length of the recording (see Player.STEP_INTERVAL for
## the same reasoning). Alternating pitch each retrigger gives it a mechanical
## tick-TOCK instead of one flat repeating note.
const TICK_INTERVAL: float = 1.0
const TOCK_PITCH: float = 0.9

## A pickup's flourish is a quick run of ticks with the pitch sliding up (gain)
## or down (loss) across them, like a clock's hands being wound rapidly rather
## than one single "ding". Tick count scales with how much time changed, so a
## big swing gets a longer wind-up than a one-second nudge.
const FLOURISH_TICK_INTERVAL: float = 0.09
const FLOURISH_PITCH_STEP: float = 0.06
const FLOURISH_BASE_PITCH: float = 1.3
const SECONDS_PER_FLOURISH_TICK: float = 1.0
const MIN_FLOURISH_TICKS: int = 3
const MAX_FLOURISH_TICKS: int = 10

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

## The ambient tick — retriggered for exactly as long as [member ticking] is true.
var _tick_audio: AudioStreamPlayer
var _tick_timer: Timer
var _tick_is_tock: bool = false
## The flourish layered over a loss or a gain. Two players rather than one so a
## loss and a gain landing in the same frame don't cut each other off.
var _loss_audio: AudioStreamPlayer
var _gain_audio: AudioStreamPlayer
## One counter per flourish player, bumped on every (re)trigger — mirrors
## Player._dash_anim_token: a stale queued tick checks its own number against
## the current one and stops running if a newer flourish has taken over.
var _burst_tokens: Dictionary[AudioStreamPlayer, int] = {}

# On Ready

# Lifecycle
func _ready() -> void:
	current_time = max_time
	_build_sfx_players()

func _process(delta: float) -> void:
	if not ticking:
		return

	current_time = max(current_time - delta * tick_rate, 0.0)

	if current_time == 0.0 and not _expired_emitted:
		_expired_emitted = true
		ticking = false
		time_expired.emit()

## Built here rather than authored on TimeSystem.tscn, so the raw sfx can drop
## straight in without an editor pass over the scene.
func _build_sfx_players() -> void:
	_tick_audio = AudioStreamPlayer.new()
	_tick_audio.stream = TICK_SFX
	_tick_audio.volume_db = TICK_VOLUME_DB
	add_child(_tick_audio)

	_tick_timer = Timer.new()
	_tick_timer.wait_time = TICK_INTERVAL
	_tick_timer.timeout.connect(_on_tick_timer_timeout)
	add_child(_tick_timer)

	_loss_audio = AudioStreamPlayer.new()
	_loss_audio.stream = TICK_SFX
	_loss_audio.volume_db = BURST_VOLUME_DB
	add_child(_loss_audio)

	_gain_audio = AudioStreamPlayer.new()
	_gain_audio.stream = GAIN_SFX
	_gain_audio.volume_db = BURST_VOLUME_DB
	add_child(_gain_audio)

# Public
func add_time(amount: float) -> void:
	current_time += amount
	# Guarded rather than left to the flourish itself: a whiffed treasure chest
	# calls this with 0 and must stay silent, not play a "you gained something"
	# flourish for nothing.
	if amount > 0.0:
		_play_flourish(_gain_audio, amount, true)

func add_max_time(amount: float) -> void:
	max_time = max_time + amount
	current_time = min(current_time + amount, max_time)

func remove_time(amount: float) -> void:
	current_time = max(current_time - amount, 0.0)
	if amount > 0.0:
		_play_flourish(_loss_audio, amount, false)

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
	ticking_changed.emit(ticking)

	if _tick_timer == null:
		return
	if ticking:
		if _tick_timer.is_stopped():
			_on_tick_timer_timeout()
			_tick_timer.start()
	else:
		_tick_timer.stop()

## Alternates tick/tock pitch each retrigger rather than looping one flat note
## on repeat — see TICK_INTERVAL.
func _on_tick_timer_timeout() -> void:
	_tick_audio.pitch_scale = TOCK_PITCH if _tick_is_tock else 1.0
	_tick_is_tock = not _tick_is_tock
	_tick_audio.play()

## A newer flourish on the same player bumps the token and the older
## coroutine's loop notices and stops on its next iteration, so a second pickup
## landing mid-flourish is heard as one restarted flourish, not two overlapping.
func _play_flourish(player: AudioStreamPlayer, amount: float, rising: bool) -> void:
	var ticks: int = clampi(roundi(amount / SECONDS_PER_FLOURISH_TICK), MIN_FLOURISH_TICKS, MAX_FLOURISH_TICKS)
	var token: int = _burst_tokens.get(player, 0) + 1
	_burst_tokens[player] = token

	for i in range(ticks):
		if _burst_tokens.get(player, 0) != token:
			return
		var step: float = i * FLOURISH_PITCH_STEP
		player.pitch_scale = FLOURISH_BASE_PITCH + (step if rising else -step)
		player.play()
		await get_tree().create_timer(FLOURISH_TICK_INTERVAL).timeout

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
	
func _set_tick_rate(value: float) -> void:
	tick_rate = max(0.0, value)
	tick_rate_changed.emit(tick_rate)

# Callbacks
