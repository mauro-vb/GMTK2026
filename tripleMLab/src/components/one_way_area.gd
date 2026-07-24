class_name OneWayArea2D
extends Area2D
## Detects bodies entering this area while moving in a specific direction.
## Pure detection only — no collision response. Useful alongside a real
## solid collider (e.g. a platform's own CollisionShape2D) when you just
## need to know *which way* something was moving when it overlapped.

## Local-space direction that counts as "entering" (rotates with the node).
## Vector2.DOWN = only trigger when a body is falling/moving downward into it.
@export var detect_direction: Vector2 = Vector2.DOWN

signal one_way_entered(body: Node2D)
signal one_way_exited(body: Node2D)

var _entered_bodies: Dictionary = {} # body -> true, for bodies that triggered one_way_entered


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	var world_dir := detect_direction.rotated(global_rotation).normalized()

	# Velocity is unreliable here: body_entered is a deferred signal, so it
	# fires just after the physics step where the overlap happened — by which
	# point move_and_slide() has often already zeroed the body's velocity
	# (e.g. landing on a floor stops vertical velocity the same step it
	# occurs). Position isn't affected by that, so use where the body is
	# relative to this area instead: if it's on the "upstream" side of
	# detect_direction, it must have arrived by moving that way.
	var offset := body.global_position - global_position
	var dot := offset.dot(-world_dir)


	if dot > 0.0:
		_entered_bodies[body] = true
		one_way_entered.emit(body)
	
func _on_body_exited(body: Node2D) -> void:
	if _entered_bodies.erase(body):
		one_way_exited.emit(body)
