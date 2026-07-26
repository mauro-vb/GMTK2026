class_name BossProjectile
extends Area2D
## One red orb of the final boss's barrage.
##
## Deliberately *not* an [Orb]. An Orb is a pickup: it asks [ModifiersSystem]
## whether it is blocked, runs its value past every held modifier, and fires
## HOT_ORB_TOUCHED. Every one of those hooks is a way for a run to switch the
## boss off — "Coating" alone would make the whole fight free. The barrage is the
## boss, so its damage goes straight to [TimeSystem] and nothing gets a vote.
##
## The projectile carries no damage rule of its own either. It reports the hit to
## the [BossLevel] that spawned it and lets the level decide, because the level is
## what owns the invulnerability window — see [method BossLevel.report_hit].

# Signals
# Enums
# Constants
## How far outside the 320x180 arena a projectile may travel before it is
## dropped. Generous enough that an orb spawned off-screen isn't freed on its
## first frame, tight enough that nothing accumulates.
const DESPAWN_MARGIN: float = 32.0
const ARENA_SIZE: Vector2 = Vector2(320.0, 180.0)

# Exports
## Pixels per second, applied in [method _physics_process]. Written by the level
## at spawn time; every pattern in the fight is just a different value here.
@export var velocity: Vector2 = Vector2.ZERO

# Public
## The fight that spawned this. Set by [BossLevel] immediately after
## instantiating, before the orb enters the tree.
var boss_level: BossLevel = null

# Private
# On Ready

# Lifecycle
func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	position += velocity * delta

	if not _is_in_bounds():
		queue_free()


# Public

# Private
func _is_in_bounds() -> bool:
	return (
		position.x > -DESPAWN_MARGIN
		and position.x < ARENA_SIZE.x + DESPAWN_MARGIN
		and position.y > -DESPAWN_MARGIN
		and position.y < ARENA_SIZE.y + DESPAWN_MARGIN
	)


# Callbacks
func _on_body_entered(body: Node2D) -> void:
	if body is not Player:
		return

	if boss_level == null:
		push_error("BossProjectile hit the player with no BossLevel to report to.")
		return

	# A hit refused by the level is one landing inside the invulnerability
	# window. The orb keeps flying rather than being consumed — "further
	# projectiles pass through" has to mean the wall behind this one is still
	# there when the window closes, not that the player is briefly a vacuum.
	if not boss_level.report_hit():
		return

	queue_free()
