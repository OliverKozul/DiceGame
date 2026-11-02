class_name SettingsPanel
extends Overlay
## Display, audio and gameplay settings. Changes apply and save immediately.

var _pages: Dictionary[String, Control] = {}
var _tabs: Dictionary[String, Button] = {}
var _refreshers: Array[Callable] = []


func _init() -> void:
	panel_size = Vector2(640, 500)


func _build() -> void:
	add_label(content, "Settings", &"Heading")
	var tab_row := HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 8)
	content.add_child(tab_row)
	var group := ButtonGroup.new()
	for page_name in ["Display", "Audio", "Gameplay"]:
		var tab := Button.new()
		tab.text = page_name
		tab.toggle_mode = true
		tab.button_group = group
		tab.custom_minimum_size = Vector2(120, 40)
		tab.pressed.connect(_show_page.bind(page_name))
		tab_row.add_child(tab)
		_tabs[page_name] = tab
		var page := GridContainer.new()
		page.columns = 2
		page.add_theme_constant_override("h_separation", 24)
		page.add_theme_constant_override("v_separation", 12)
		page.size_flags_vertical = Control.SIZE_EXPAND_FILL
		content.add_child(page)
		_pages[page_name] = page

	var display := _pages["Display"]
	_check(display, "Fullscreen", "display", "fullscreen")
	_check(display, "Vertical sync", "display", "vsync")
	_choice(display, "Interface size", "display", "ui_scale", Settings.UI_SCALES, func(v: float) -> String: return "%d%%" % roundi(v * 100))

	var audio := _pages["Audio"]
	_slider(audio, "Master volume", "audio", "master")
	_slider(audio, "Music", "audio", "music")
	_slider(audio, "Sound effects", "audio", "sfx")
	_slider(audio, "Fireplace", "audio", "ambience")

	var gameplay := _pages["Gameplay"]
	_choice(gameplay, "Animation speed", "gameplay", "animation_speed", Settings.ANIMATION_SPEEDS, func(v: float) -> String: return "%sx" % str(v))
	_check(gameplay, "Reduced motion", "gameplay", "reduced_motion")
	_check(gameplay, "Confirm before locking a plan", "gameplay", "confirm_lock")
	_check(gameplay, "High-contrast stamps", "gameplay", "high_contrast")
	_check(gameplay, "First-game tips", "gameplay", "tips")
	add_label(gameplay, "")
	var reset_tips := add_button(gameplay, "Show all tips again", Settings.reset_tips)
	reset_tips.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	content.add_child(footer)
	add_button(footer, "Reset to defaults", _reset)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(spacer)
	add_button(footer, "Done", close)

	_tabs["Display"].button_pressed = true
	_show_page("Display")


func open() -> void:
	for refresh in _refreshers:
		refresh.call()
	super.open()


func _show_page(page_name: String) -> void:
	for key in _pages:
		_pages[key].visible = key == page_name


func _reset() -> void:
	Settings.reset_to_defaults()
	for refresh in _refreshers:
		refresh.call()


func _row_label(page: Control, text: String) -> void:
	var label := add_label(page, text)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.custom_minimum_size = Vector2(260, 0)


func _check(page: Control, text: String, section: String, key: String) -> void:
	_row_label(page, text)
	var toggle := CheckButton.new()
	toggle.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	toggle.toggled.connect(func(on: bool) -> void: Settings.set_value(section, key, on))
	page.add_child(toggle)
	_refreshers.append(func() -> void: toggle.set_pressed_no_signal(bool(Settings.get_value(section, key))))


func _slider(page: Control, text: String, section: String, key: String) -> void:
	_row_label(page, text)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	page.add_child(row)
	var slider := HSlider.new()
	slider.max_value = 1.0
	slider.step = 0.05
	slider.custom_minimum_size = Vector2(220, 28)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(slider)
	var value_label := Label.new()
	value_label.custom_minimum_size = Vector2(52, 0)
	row.add_child(value_label)
	slider.value_changed.connect(func(value: float) -> void:
		value_label.text = "%d%%" % roundi(value * 100)
		Settings.set_value(section, key, value))
	slider.drag_ended.connect(func(_changed: bool) -> void: Audio.play(&"coins", -8.0))
	_refreshers.append(func() -> void:
		slider.set_value_no_signal(float(Settings.get_value(section, key)))
		value_label.text = "%d%%" % roundi(slider.value * 100))


func _choice(page: Control, text: String, section: String, key: String, values: Array[float], describe: Callable) -> void:
	_row_label(page, text)
	var option := OptionButton.new()
	option.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	option.custom_minimum_size = Vector2(140, 40)
	for value in values:
		option.add_item(describe.call(value))
	option.item_selected.connect(func(index: int) -> void: Settings.set_value(section, key, values[index]))
	page.add_child(option)
	_refreshers.append(func() -> void:
		var current := float(Settings.get_value(section, key))
		var best := 0
		for i in values.size():
			if absf(values[i] - current) < absf(values[best] - current):
				best = i
		option.select(best))
