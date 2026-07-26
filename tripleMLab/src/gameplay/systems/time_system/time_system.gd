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

## Placeholder sfx from the team — single-note clips, looped here rather than
## shipped pre-looped. clock_down doubles as the ambient tick (while [member
## ticking]) and the quicker loss flourish (see [method remove_time]); there is
## no ambient equivalent for a gain, so clock_up only ever plays the flourish.
const TICK_SFX: AudioStreamWAV = preload("res://assets/audio/sfx/clock_down.wav")
const GAIN_SFX: AudioStreamWAV = preload("res://assets/audio/sfx/clock_up.wav")
const TICK_VOLUME_DB: float = -14.0
const BURST_VOLUME_DB: float = -6.0
## How long a burst's quicker flourish runs before dropping back to the ambient
## tick (or, for a gain, back to silence).
const BURST_DURATION: float = 0.5
const BURST_PITCH: float = 1.6

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

## The ambient tick — playing for exactly as long as [member ticking] is true.
var _tick_audio: AudioStreamPlayer
## The quicker flourish layered over a loss or a gain. Two players rather than
## one so a loss and a gain landing in the same frame don't cut each other off.
var _loss_audio: AudioStreamPlayer
var _gain_audio: AudioStreamPlayer
## One counter per burst player, bumped on every (re)trigger — mirrors
## Player._dash_anim_token: a stale delayed stop() checks its own number against
## the current one and does nothing if a newer burst has already taken over.
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
	AudioUtil.configure_loop(TICK_SFX)
	AudioUtil.configure_loop(GAIN_SFX)

	_tick_audio = AudioStreamPlayer.new()
	_tick_audio.stream = TICK_SFX
	_tick_audio.volume_db = TICK_VOLUME_DB
	add_child(_tick_audio)

	_loss_audio = AudioStreamPlayer.new()
	_loss_audio.stream = TICK_SFX
	_loss_audio.volume_db = BURST_VOLUME_DB
	_loss_audio.pitch_scale = BURST_PITCH
	add_child(_loss_audio)

	_gain_audio = AudioStreamPlayer.new()
	_gain_audio.stream = GAIN_SFX
	_gain_audio.volume_db = BURST_VOLUME_DB
	_gain_audio.pitch_scale = BURST_PITCH
	add_child(_gain_audio)

# Public
func add_time(amount: float) -> void:
	current_time += amount
	# Guarded rather than left to the burst itself: a whiffed treasure chest
	# calls this with 0 and must stay silent, not play a "you gained something"
	# flourish for nothing.
	if amount > 0.0:
		_play_burst(_gain_audio)

func add_max_time(amount: float) -> void:
	max_time = max_time + amount
	current_time = min(current_time + amount, max_time)

func remove_time(amount: float) -> void:
	current_time = max(current_time - amount, 0.0)
	if amount > 0.0:
		_play_burst(_loss_audio)

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

	if _tick_audio == null:
		return
	if ticking:
		if not _tick_audio.playing:
			_tick_audio.play()
	else:
		_tick_audio.stop()

## Restarts rather than queues: a second loss landing mid-flourish is heard as
## one longer flourish, not cut off by an earlier trigger's stop() firing
## partway through the new one.
func _play_burst(player: AudioStreamPlayer) -> void:
	player.play()
	var token: int = _burst_tokens.get(player, 0) + 1
	_burst_tokens[player] = token

	var timer: SceneTreeTimer = get_tree().create_timer(BURST_DURATION)
	timer.timeout.connect(func() -> void:
		if _burst_tokens.get(player, 0) == token:
			player.stop()
	, CONNECT_ONE_SHOT)
	
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
