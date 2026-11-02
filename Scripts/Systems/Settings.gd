extends Node
## Player preferences. Saved to user://settings.cfg and applied as soon as they change.

signal changed

const PATH := "user://settings.cfg"
const DEFAULTS: Dictionary = {
	"display": {"fullscreen": false, "vsync": true, "ui_scale": 1.0},
	"audio": {"master": 0.8, "music": 0.55, "sfx": 0.8, "ambience": 0.6},
	"gameplay": {"animation_speed": 1.0, "reduced_motion": false, "confirm_lock": true, "high_contrast": false},
}
const UI_SCALES: Array[float] = [0.85, 1.0, 1.15, 1.3, 1.5]
const ANIMATION_SPEEDS: Array[float] = [0.75, 1.0, 1.5, 2.0]

## Not saved: automated tests switch animations off entirely.
var instant_animations := false

var _config := ConfigFile.new()


func _ready() -> void:
	_config.load(PATH)
	apply()


func get_value(section: String, key: String) -> Variant:
	return _config.get_value(section, key, DEFAULTS[section][key])


func set_value(section: String, key: String, value: Variant) -> void:
	if get_value(section, key) == value:
		return
	_config.set_value(section, key, value)
	_config.save(PATH)
	apply()
	changed.emit()


func reset_to_defaults() -> void:
	_config = ConfigFile.new()
	_config.save(PATH)
	apply()
	changed.emit()


## Multiplier for every animation duration (0 when animations are off).
func animation_scale() -> float:
	if instant_animations:
		return 0.0
	return 1.0 / maxf(float(get_value("gameplay", "animation_speed")), 0.1)


func reduced_motion() -> bool:
	return instant_animations or bool(get_value("gameplay", "reduced_motion"))


func apply() -> void:
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
