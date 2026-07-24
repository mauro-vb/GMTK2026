class_name LevelExit
extends Area2D

signal reached_exit

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	# Stay disarmed for the first physics tick. When the player is carried over
	# from a previous level, its physics body re-enters the space at the old
	# level's exit position (node position only syncs to the physics server on
	# the first step), so an armed exit would see a ghost overlap and fire
	# body_entered immediately, ending the level on arrival.
	monitoring = false
	await get_tree().physics_frame
	await get_tree().physics_frame
	monitoring = true

func _on_body_entered(_body: Node2D) -> void:
	reached_exit.emit()
