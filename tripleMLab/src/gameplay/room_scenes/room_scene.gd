class_name RoomScene
extends Node2D
## Base for anything MainGame can load into SceneContainer.WORLD
## (or a future room-specific container) — levels, shops, events, etc.
## Subclasses are responsible for emitting `finished` when the room is done

signal exited

func exit() -> void:
	exited.emit()
