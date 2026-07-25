class_name OrbWindowModifier
extends Modifier
## Changes how one kind of orb behaves for the first `window_seconds` of a level.
## Covers "Coating" (BLOCK hot orbs) and "Warm Catch" (hot orbs pay a flat bonus
## instead of their usual value).

# Signals
# Enums
enum Effect {
	BLOCK,          ## Orb is absorbed: no time change, no orb-touched modifiers.
	OVERRIDE_VALUE, ## Orb pays `override_value` seconds instead of its own value.
}
# Constants

# Exports
## Which orb this applies to — COLD_ORB_TOUCHED or HOT_ORB_TOUCHED.
@export var affected_orb: Modifier.Type = Modifier.Type.HOT_ORB_TOUCHED
@export var effect: Effect = Effect.BLOCK
## Only read when `effect` is OVERRIDE_VALUE.
@export var override_value: float = 1.0
@export var window_seconds: float = 5.0
# Public

# Private
var _window_remaining: float = 0.0
# On Ready

# Static

# Lifecycle
func trigger_modifier() -> void:
	_window_remaining = window_seconds


func deactivate_modifier() -> void:
	_window_remaining = 0.0


func tick(delta: float) -> void:
	_window_remaining = max(_window_remaining - delta, 0.0)

# Public
func blocks_orb(orb_trigger: Modifier.Type) -> bool:
	return effect == Effect.BLOCK and _is_active(orb_trigger)


func modify_orb_value(orb_trigger: Modifier.Type, value: float) -> float:
	if effect != Effect.OVERRIDE_VALUE or not _is_active(orb_trigger):
		return value
	return override_value

# Private
func _is_active(orb_trigger: Modifier.Type) -> bool:
	return _window_remaining > 0.0 and orb_trigger == affected_orb

# Callbacks
