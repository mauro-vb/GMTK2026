extends Node
## Shared bus for every non-music sound effect: player actions and the clock.
## A second bus rather than routing effects through "Music" or leaving them on
## Master, so the start menu can offer independent sliders for each — one for
## the soundtrack, one for everything else.

const BUS_NAME: StringName = &"Sfx"
const DEFAULT_VOLUME_DB: float = -6.0

func _ready() -> void:
	_ensure_bus()


func set_volume_db(value: float) -> void:
	var index: int = AudioServer.get_bus_index(BUS_NAME)
	if index != -1:
		AudioServer.set_bus_volume_db(index, value)


func get_volume_db() -> float:
	var index: int = AudioServer.get_bus_index(BUS_NAME)
	return AudioServer.get_bus_volume_db(index) if index != -1 else DEFAULT_VOLUME_DB


## Idempotent: the bus is created once per game launch and survives every run
## after that, same as this autoload does.
func _ensure_bus() -> void:
	if AudioServer.get_bus_index(BUS_NAME) != -1:
		return

	var index: int = AudioServer.bus_count
	AudioServer.add_bus(index)
	AudioServer.set_bus_name(index, BUS_NAME)
	AudioServer.set_bus_volume_db(index, DEFAULT_VOLUME_DB)
