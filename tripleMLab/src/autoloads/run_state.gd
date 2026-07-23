extends Node
## Autoload holding the state of the current run: the countdown timer, coins,
## relics and consumables. Other systems react to changes via signals.

signal time_changed(seconds_remaining: float)
signal time_expired
signal coins_changed(coins: int)
signal relic_added(id: StringName)
signal consumable_added(id: StringName)

const STARTING_TIME_SECONDS: float = 300.0
const STARTING_COINS: int = 50

var time_remaining: float = STARTING_TIME_SECONDS
var coins: int = STARTING_COINS
var relics: Array[StringName] = []
var consumables: Array[StringName] = []
## Whether the countdown is currently running. Controlled by MainGame per room
## (see BaseLevel.should_tick_time).
var ticking: bool = false

var _expired_emitted: bool = false


func _process(delta: float) -> void:
	if not ticking:
		return
	_set_time(time_remaining - delta)


func start_run() -> void:
	time_remaining = STARTING_TIME_SECONDS
	coins = STARTING_COINS
	relics = []
	consumables = []
	ticking = false
	_expired_emitted = false
	time_changed.emit(time_remaining)
	coins_changed.emit(coins)


func set_ticking(value: bool) -> void:
	ticking = value and not _expired_emitted


func add_time(seconds: float) -> void:
	_set_time(time_remaining + seconds)


func add_coins(amount: int) -> void:
	coins += amount
	coins_changed.emit(coins)


func can_spend_time(seconds: float) -> bool:
	# A purchase may never zero out the run on the spot.
	return time_remaining > seconds


func can_spend_coins(amount: int) -> bool:
	return coins >= amount


func try_spend_time(seconds: float) -> bool:
	if not can_spend_time(seconds):
		return false
	_set_time(time_remaining - seconds)
	return true


func try_spend_coins(amount: int) -> bool:
	if not can_spend_coins(amount):
		return false
	coins -= amount
	coins_changed.emit(coins)
	return true


func add_relic(id: StringName) -> void:
	relics.append(id)
	relic_added.emit(id)


func has_relic(id: StringName) -> bool:
	return relics.has(id)


func add_consumable(id: StringName) -> void:
	consumables.append(id)
	consumable_added.emit(id)


func _set_time(value: float) -> void:
	time_remaining = maxf(value, 0.0)
	time_changed.emit(time_remaining)
	if time_remaining == 0.0 and not _expired_emitted:
		_expired_emitted = true
		ticking = false
		time_expired.emit()
