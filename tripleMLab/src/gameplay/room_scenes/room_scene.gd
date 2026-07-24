class_name RoomScene
extends Node2D
## Base for anything MainGame can load into SceneContainer.WORLD
## (or a future room-specific container) — levels, shops, events, etc.
## Subclasses are responsible for emitting `exited` when the room is done

signal exited

@export var should_tick_time: bool = true

func exit() -> void:
	exited.emit()
