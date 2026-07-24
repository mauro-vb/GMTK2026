extends Node
## Autoload owning user preferences: audio volumes, fullscreen, screen shake.
## Values apply immediately when set and persist to user://settings.cfg, so
## the settings menu is a dumb view over this node. Read `Settings.screen_shake`
## etc. from gameplay code; never touch AudioServer/DisplayServer directly.

const SAVE_PATH: String = "user://settings.cfg"
const SECTION: String = "settings"

const BUS_MASTER: StringName = &"Master"
const BUS_MUSIC: StringName = &"Music"
const BUS_SFX: StringName = &"SFX"

var master_volume: float = 0.8:
	set(value):
		master_volume = clampf(value, 0.0, 1.0)
		_apply_bus_volume(BUS_MASTER, master_volume)

var music_volume: float = 1.0:
	set(value):
		music_volume = clampf(value, 0.0, 1.0)
		_apply_bus_volume(BUS_MUSIC, music_volume)

var sfx_volume: float = 1.0:
	set(value):
		sfx_volume = clampf(value, 0.0, 1.0)
		_apply_bus_volume(BUS_SFX, sfx_volume)

var fullscreen: bool = false:
	set(value):
		fullscreen = value
		_apply_fullscreen()

## Consumed by camera/VFX code; the setting just lives here.
var screen_shake: bool = true


func _ready() -> void:
	load_settings()


func load_settings() -> void:
	var config: ConfigFile = ConfigFile.new()
	# A missing file on first launch is fine — setters below apply defaults.
	config.load(SAVE_PATH)
	master_volume = config.get_value(SECTION, "master_volume", master_volume)
	music_volume = config.get_value(SECTION, "music_volume", music_volume)
	sfx_volume = config.get_value(SECTION, "sfx_volume", sfx_volume)
	fullscreen = config.get_value(SECTION, "fullscreen", fullscreen)
	screen_shake = config.get_value(SECTION, "screen_shake", screen_shake)


func save_settings() -> void:
	var config: ConfigFile = ConfigFile.new()
	config.set_value(SECTION, "master_volume", master_volume)
	config.set_value(SECTION, "music_volume", music_volume)
	config.set_value(SECTION, "sfx_volume", sfx_volume)
	config.set_value(SECTION, "fullscreen", fullscreen)
	config.set_value(SECTION, "screen_shake", screen_shake)
	var err: Error = config.save(SAVE_PATH)
	if err != OK:
		push_error("Settings: failed to save to %s (error %d)" % [SAVE_PATH, err])


func _apply_bus_volume(bus: StringName, linear: float) -> void:
	var index: int = AudioServer.get_bus_index(bus)
	if index < 0:
		push_warning("Settings: audio bus '%s' not found" % bus)
		return
	AudioServer.set_bus_volume_db(index, linear_to_db(linear))
	AudioServer.set_bus_mute(index, is_zero_approx(linear))


func _apply_fullscreen() -> void:
	if OS.has_feature("web"):
		return
	var mode: DisplayServer.WindowMode = (
		DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen
		else DisplayServer.WINDOW_MODE_WINDOWED
	)
	DisplayServer.window_set_mode(mode)
