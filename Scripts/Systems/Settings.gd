extends Node
## Player preferences, applied as soon as they change. Saved to user://settings.cfg, which Steam
## Cloud carries between machines, except the display settings, which belong to one machine.

signal changed

const PATH := "user://settings.cfg"
const DISPLAY_PATH := "user://display.cfg"
const DEFAULTS: Dictionary = {
	"display": {"fullscreen": false, "vsync": true, "ui_scale": 1.0},
	"audio": {"master": 0.8, "music": 0.55, "sfx": 0.8, "ambience": 0.6},
	"gameplay": {"animation_speed": 1.0, "reduced_motion": false, "confirm_lock": true, "high_contrast": false, "tips": true},
	# "" follows the system language (see Loc.resolve_language).
	"language": {"locale": ""},
	# The host's choices for a new table (see Network.room). turns and afk are in turns and seconds.
	"table": {"turns": Content.MAX_TURNS, "difficulty": 1, "afk": 120, "public": false},
}
const UI_SCALES: Array[float] = [0.85, 1.0, 1.15, 1.3, 1.5]
const ANIMATION_SPEEDS: Array[float] = [0.75, 1.0, 1.5, 2.0]

## Not saved: automated tests switch animations off entirely.
var instant_animations := false

var _config := ConfigFile.new()
var _display := ConfigFile.new()


func _ready() -> void:
	_config.load(PATH)
	_display.load(DISPLAY_PATH)
	apply()


func get_value(section: String, key: String) -> Variant:
	var file := _display if section == "display" else _config
	return file.get_value(section, key, DEFAULTS[section][key])


func set_value(section: String, key: String, value: Variant) -> void:
	if get_value(section, key) == value:
		return
	if section == "display":
		_display.set_value(section, key, value)
		_display.save(DISPLAY_PATH)
	else:
		_config.set_value(section, key, value)
		_config.save(PATH)
	apply()
	changed.emit()


## Everything back to the defaults, except the language.
func reset_to_defaults() -> void:
	var language: Variant = get_value("language", "locale")
	_config = ConfigFile.new()
	_config.set_value("language", "locale", language)
	_config.save(PATH)
	_display = ConfigFile.new()
	_display.save(DISPLAY_PATH)
	apply()
	changed.emit()


## First-game tips: shown once each while tips are switched on.
func should_show_tip(id: String) -> bool:
	return bool(get_value("gameplay", "tips")) and not _config.get_value("tips_seen", id, false)


func mark_tip_seen(id: String) -> void:
	_config.set_value("tips_seen", id, true)
	_config.save(PATH)


func reset_tips() -> void:
	if _config.has_section("tips_seen"):
		_config.erase_section("tips_seen")
	_config.save(PATH)
	changed.emit()


## Multiplier for every animation duration (0 when animations are off).
func animation_scale() -> float:
	if instant_animations:
		return 0.0
	return 1.0 / maxf(float(get_value("gameplay", "animation_speed")), 0.1)


func reduced_motion() -> bool:
	return instant_animations or bool(get_value("gameplay", "reduced_motion"))


func apply() -> void:
	var locale := Loc.resolve_language(str(get_value("language", "locale")))
	if TranslationServer.get_locale() != locale:
		TranslationServer.set_locale(locale)
	if DisplayServer.get_name() != "headless":
		var fullscreen: bool = get_value("display", "fullscreen")
		var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != mode:
			DisplayServer.window_set_mode(mode)
		var vsync := DisplayServer.VSYNC_ENABLED if get_value("display", "vsync") else DisplayServer.VSYNC_DISABLED
		DisplayServer.window_set_vsync_mode(vsync)
	get_tree().root.content_scale_factor = float(get_value("display", "ui_scale"))
	for bus in ["Master", "Music", "SFX", "Ambience"]:
		var index := AudioServer.get_bus_index(bus)
		if index >= 0:
			var volume := float(get_value("audio", bus.to_lower()))
			AudioServer.set_bus_volume_db(index, linear_to_db(maxf(volume, 0.0001)))
			AudioServer.set_bus_mute(index, volume <= 0.001)
