class_name SettingsPanel
extends Overlay
## Display, audio, gameplay and language settings. Changes apply and save immediately.
## The language can only be changed from the main menu, which then redraws itself.

## Emitted when the player picks another language (the menu reloads to redraw its text).
signal language_changed

const PAGES: Array[String] = ["display", "audio", "gameplay"]

## Set by the escape menu: during a game the language stays as it is.
var language_locked := false

var _pages: Dictionary[String, Control] = {}
var _tabs: Dictionary[String, Button] = {}
var _refreshers: Array[Callable] = []
var _page := "display"


func _init() -> void:
	panel_size = Vector2(660, 520)


func _build() -> void:
	add_label(content, tr("Settings"), &"Heading")
	var tab_row := HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 8)
	content.add_child(tab_row)
	var group := ButtonGroup.new()
	var titles := {"display": tr("Display"), "audio": tr("Audio"), "gameplay": tr("Gameplay")}
	for page_name in PAGES:
		var tab := Button.new()
		tab.text = titles[page_name]
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

	var display := _pages["display"]
	_language(display)
	_check(display, tr("Fullscreen"), "display", "fullscreen")
	_check(display, tr("Vertical sync"), "display", "vsync")
	_choice(display, tr("Interface size"), "display", "ui_scale", Settings.UI_SCALES, func(v: float) -> String: return "%d%%" % roundi(v * 100))

	var audio := _pages["audio"]
	_slider(audio, tr("Master volume"), "audio", "master")
	_slider(audio, tr("Music"), "audio", "music")
	_slider(audio, tr("Sound effects"), "audio", "sfx")
	_slider(audio, tr("Fireplace"), "audio", "ambience")

	var gameplay := _pages["gameplay"]
	_choice(gameplay, tr("Animation speed"), "gameplay", "animation_speed", Settings.ANIMATION_SPEEDS, func(v: float) -> String: return "%sx" % str(v))
	_check(gameplay, tr("Reduced motion"), "gameplay", "reduced_motion")
	_check(gameplay, tr("Confirm before locking a plan"), "gameplay", "confirm_lock")
	_check(gameplay, tr("High-contrast stamps"), "gameplay", "high_contrast")
	_check(gameplay, tr("First-game tips"), "gameplay", "tips")
	add_label(gameplay, "")
	var reset_tips := add_button(gameplay, tr("Show all tips again"), Settings.reset_tips)
	reset_tips.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	content.add_child(footer)
	add_button(footer, tr("Reset to defaults"), _reset)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(spacer)
	add_button(footer, tr("Done"), close)

	_tabs["display"].button_pressed = true
	_show_page("display")


func open() -> void:
	for refresh in _refreshers:
		refresh.call()
	super.open()


## Opens the panel without its easing, e.g. after the menu reloaded for a new language.
func open_at(page_name: String) -> void:
	open()
	_tabs[page_name].button_pressed = true
	_show_page(page_name)


## Q and E (or the shoulder buttons) switch tabs.
func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed(&"prev_tab") or event.is_action_pressed(&"next_tab")):
		var step := -1 if event.is_action_pressed(&"prev_tab") else 1
		var next := PAGES[posmod(PAGES.find(_page) + step, PAGES.size())]
		_tabs[next].button_pressed = true
		_show_page(next)
		Controls.focus(_tabs[next])
		get_viewport().set_input_as_handled()
		return
	super._unhandled_input(event)


func _show_page(page_name: String) -> void:
	_page = page_name
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


func _language(page: Control) -> void:
	_row_label(page, tr("Language"))
	var option := OptionButton.new()
	option.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	option.custom_minimum_size = Vector2(200, 40)
	var codes: Array[String] = [""]
	option.add_item(tr("System language"))
	for code: String in Loc.LANGUAGES:
		codes.append(code)
		option.add_item(Loc.LANGUAGES[code])
	option.disabled = language_locked
	if language_locked:
		option.tooltip_text = tr("Change the language from the main menu.")
	option.item_selected.connect(func(index: int) -> void:
		Settings.set_value("language", "locale", codes[index])
		language_changed.emit())
	page.add_child(option)
	_refreshers.append(func() -> void: option.select(maxi(codes.find(str(Settings.get_value("language", "locale"))), 0)))


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
