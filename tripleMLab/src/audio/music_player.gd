extends Node
## Background music for the whole game: one track for real levels (the run
## itself), one for everything else — the start menu, a workshop bench, a
## treasure chest. An autoload rather than something MainGame owns, so it
## already exists and can start playing before a run does (the start menu).
##
## Owns the only "Music" audio bus, created here at runtime rather than baked
## into a bus layout resource — one less file that could disagree with the
## code that reads it. The start menu's volume slider talks to that bus
## directly (see StartMenu), not to this script.

const LEVEL_TRACK: AudioStreamMP3 = preload("res://assets/audio/music/level_1.mp3")
const AMBIENT_TRACK: AudioStreamMP3 = preload("res://assets/audio/music/level_2.mp3")

const BUS_NAME: StringName = &"Music"
## Quiet by default — these are rough placeholder tracks, not mixed, and a
## background loop must never fight the sound effects for attention.
const DEFAULT_VOLUME_DB: float = -18.0

var _player: AudioStreamPlayer
var _current_track: AudioStream

func _ready() -> void:
	LEVEL_TRACK.loop = true
	AMBIENT_TRACK.loop = true

	_ensure_bus()
	_player = AudioStreamPlayer.new()
	_player.bus = BUS_NAME
	add_child(_player)


## The run itself — levels and the map between them.
func play_level_track() -> void:
	_play(LEVEL_TRACK)


## Everywhere that isn't the run in motion: the start menu, a bench, a chest.
func play_ambient_track() -> void:
	_play(AMBIENT_TRACK)


func set_volume_db(value: float) -> void:
	var index: int = AudioServer.get_bus_index(BUS_NAME)
	if index != -1:
		AudioServer.set_bus_volume_db(index, value)


func get_volume_db() -> float:
	var index: int = AudioServer.get_bus_index(BUS_NAME)
	return AudioServer.get_bus_volume_db(index) if index != -1 else DEFAULT_VOLUME_DB


func _play(track: AudioStream) -> void:
	if _current_track == track and _player.playing:
		return
	_current_track = track
	_player.stream = track
	_player.play()


## Idempotent: the bus is created once per game launch and survives every run
## after that, same as this autoload does.
func _ensure_bus() -> void:
	if AudioServer.get_bus_index(BUS_NAME) != -1:
		return

	var index: int = AudioServer.bus_count
	AudioServer.add_bus(index)
	AudioServer.set_bus_name(index, BUS_NAME)
	AudioServer.set_bus_volume_db(index, DEFAULT_VOLUME_DB)
