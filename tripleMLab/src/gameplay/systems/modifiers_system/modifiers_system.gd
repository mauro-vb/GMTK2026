class_name ModifiersSystem
extends Node
## Owns the modifiers the player is carrying: adds and drops them, ages their
## durations, and fires them when MainGame reports a level boundary or an orb
## reports a touch.
##
## SUGGESTION (not done here, would touch every modifier at once): modifiers
## currently reach *up* through `Global.main_game` to find TimeSystem and Player,
## which is the opposite of "call down, signal up". The cheap fix is to pass what
## they need in instead of letting them go looking: give the three lifecycle
## methods a parameter — `trigger_modifier(system: ModifiersSystem)` and the same
## for `deactivate_modifier()` / `tick()` — and have this system pass `self`. It
## already knows TimeSystem and Player, so the `Modifier._get_*` helpers and every
## `Global` read inside a modifier disappear, and `Global` stays where it belongs:
## in MainGame. Orb is the same story in miniature — it already emits
## `collected(type)`, so the time/modifier bookkeeping in `_on_body_entered` could
## move up into whoever spawns the orb and listens to that signal.

# Signals
signal modifier_added(modifier: Modifier)
signal modifier_removed(modifier: Modifier)

# Enums
# Constants

# Exports

# Public
var modifiers: Array[Modifier] = []

## Seconds spent inside the current level. Measured in real time so it keeps
## counting while the clock is frozen — it answers "how long did that take?",
## not "how much fuse did that burn". Read by modifiers that reward fast or
## slow clears (see ConditionalTimeModifier, GainModifierModifier).
var level_time_taken: float = 0.0

# Private
var _in_level: bool = false

# On Ready

# Static

# Lifecycle
func _ready() -> void:
	pass

func _process(delta: float) -> void:
	if _in_level:
		level_time_taken += delta

	# Real delta: an effect window has to keep running even when time is frozen.
	for modifier: Modifier in modifiers:
		modifier.tick(delta)

	# Scaled delta: SECONDS durations burn down with the clock, not with the engine.
	_tick_second_durations(_get_time_delta(delta))

# Public
func activate_modifiers(type: Modifier.Type) -> void:
	if type == Modifier.Type.EVENT_BASED:
		return

	if type == Modifier.Type.ENTER_LEVEL:
		level_time_taken = 0.0
		_in_level = true

	# Snapshot first: a modifier can hand out another modifier while it triggers,
	# and something gained on the way out of a level shouldn't have that level
	# counted against its level-duration.
	var held: Array[Modifier] = modifiers.duplicate()
	var filter: Callable = func(m: Modifier) -> bool: return m.type == type
	for modifier: Modifier in held.filter(filter):
		_try_trigger(modifier)

	if type == Modifier.Type.EXIT_LEVEL:
		_in_level = false
		_tick_level_durations(held)


func add_modifier(modifier: Modifier, from_link: bool = false) -> void:
	if modifier == null:
		push_error("Tried to add a null modifier.")
		return
	if has_modifier(modifier.id) and not modifier.stackable:
		return

	# Added modifiers are copies, so runtime state (duration counters, effect
	# windows) never writes back into the shared .tres, and two stacks of the
	# same modifier each get their own countdown.
	var instance: Modifier = modifier.duplicate()
	instance.levels_remaining = instance.duration_levels
	instance.seconds_remaining = instance.duration_seconds

	modifiers.append(instance)
	modifier_added.emit(instance)

	if instance.type == Modifier.Type.EVENT_BASED:
		_try_trigger(instance)

	# Trade-off pairs: an upgrade can pull its matching downgrade in with it.
	if not from_link and instance.linked_modifier != null:
		add_modifier(instance.linked_modifier, true)


func remove_modifier(modifier: Modifier) -> void:
	if not modifiers.has(modifier):
		push_error("Couldn't remove %s, because it doesn't exist" % [modifier.modifier_name])
		return
	modifier.deactivate_modifier()
	modifiers.erase(modifier)
	modifier_removed.emit(modifier)


func has_modifier(id: String) -> bool:
	for modifier: Modifier in modifiers:
		if modifier.id == id:
			return true

	return false


## True when a modifier is absorbing this kind of orb entirely (see "Coating").
func is_orb_blocked(orb_trigger: Modifier.Type) -> bool:
	for modifier: Modifier in modifiers:
		if modifier.blocks_orb(orb_trigger):
			return true

	return false


## Runs an orb's time value past every active modifier before the orb applies it.
func modify_orb_value(orb_trigger: Modifier.Type, value: float) -> float:
	for modifier: Modifier in modifiers:
		value = modifier.modify_orb_value(orb_trigger, value)

	return value


## Workshop numbers, each run past every held modifier the same way orb values
## are. The workshop asks for these instead of reading modifiers itself, so it
## never has to know which modifier types exist.
func get_workshop_offers(base: int) -> int:
	var count: int = base
	for modifier: Modifier in modifiers:
		count = modifier.modify_workshop_offers(count)

	return maxi(count, 1)


func get_workshop_picks(base: int) -> int:
	var count: int = base
	for modifier: Modifier in modifiers:
		count = modifier.modify_workshop_picks(count)

	return maxi(count, 0)


func get_workshop_rerolls(base: int) -> int:
	var count: int = base
	for modifier: Modifier in modifiers:
		count = modifier.modify_workshop_rerolls(count)

	return maxi(count, 0)


func get_workshop_offer_weight(weight: float, is_combined: bool) -> float:
	for modifier: Modifier in modifiers:
		weight = modifier.modify_workshop_offer_weight(weight, is_combined)

	return maxf(weight, 0.0)


func get_workshop_skip_bonus(base: float) -> float:
	var seconds: float = base
	for modifier: Modifier in modifiers:
		seconds = modifier.modify_workshop_skip_bonus(seconds)

	return maxf(seconds, 0.0)


## Closes out a workshop visit: any modifier that spends itself on a visit says
## so here and is dropped. Iterates a copy because that removal mutates the list.
func notify_workshop_visited(picks_taken: int) -> void:
	for modifier: Modifier in modifiers.duplicate():
		if not modifiers.has(modifier):
			continue
		if modifier.on_workshop_visited(picks_taken):
			remove_modifier(modifier)

# Private
func _try_trigger(modifier: Modifier) -> void:
	if modifier.chance < 1.0 and randf() > modifier.chance:
		return
	modifier.trigger_modifier()


func _tick_second_durations(time_delta: float) -> void:
	if time_delta <= 0.0:
		return
	for modifier: Modifier in modifiers.duplicate():
		if modifier.duration != Modifier.Duration.SECONDS:
			continue
		modifier.seconds_remaining -= time_delta
		if modifier.seconds_remaining <= 0.0:
			remove_modifier(modifier)


func _tick_level_durations(held: Array[Modifier]) -> void:
	for modifier: Modifier in held:
		if modifier.duration != Modifier.Duration.LEVELS:
			continue
		if not modifiers.has(modifier):
			continue
		modifier.levels_remaining -= 1
		if modifier.levels_remaining <= 0:
			remove_modifier(modifier)


## Delta scaled the way TimeSystem drains the clock, so SECONDS durations run on
## game time. Returns 0.0 whenever the clock isn't running.
func _get_time_delta(delta: float) -> float:
	if Global.main_game == null or Global.main_game.time_system == null:
		return 0.0
	var time_system: TimeSystem = Global.main_game.time_system
	if not time_system.ticking:
		return 0.0
	return delta * time_system.tick_rate

# Callbacks
