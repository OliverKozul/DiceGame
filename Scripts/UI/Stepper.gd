class_name Stepper
extends HBoxContainer
## A whole number with − and + buttons, for use with a mouse, keys or a pad: it takes focus
## as one control, left and right (or the mouse wheel) change the value, and up and down move
## on to the next control. Replaces SpinBox, whose text field gets in the way of a pad.

signal value_changed(value: int)

## The width of a value that is a word.
const VALUE_WIDTH := 118.0

var min_value := 0
var max_value := 99
var value := 0
var editable := true:
	set(on):
		editable = on
		focus_mode = Control.FOCUS_ALL if on else Control.FOCUS_NONE
		_refresh()
## Words to show instead of the number (see setup_choices).
var choices := PackedStringArray()

var _minus := Button.new()
var _plus := Button.new()
var _label := Label.new()


func _init() -> void:
	focus_mode = Control.FOCUS_ALL
	add_theme_constant_override("separation", 4)
	for button in [_minus, _plus]:
		# step() clicks for keys and mouse alike, so the buttons stay quiet themselves.
		button.set_meta(&"silent", true)
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(34, 34)
	_minus.text = "−"
	_plus.text = "+"
	_minus.pressed.connect(step.bind(-1))
	_plus.pressed.connect(step.bind(1))
	_label.custom_minimum_size = Vector2(36, 0)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_minus)
	add_child(_label)
	add_child(_plus)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	_refresh()


## Sets how wide the value is shown, so steppers above each other line up.
func set_value_width(width: float) -> void:
	_label.custom_minimum_size.x = width


## Sets the range and value without emitting value_changed.
func setup(minimum: int, maximum: int, start: int, label_variation: StringName = &"") -> void:
	min_value = minimum
	max_value = maxi(minimum, maximum)
	value = clampi(start, min_value, max_value)
	_label.theme_type_variation = label_variation
	_refresh()


## A list to choose from: the value is the index of the word shown.
func setup_choices(words: PackedStringArray, start: int) -> void:
	choices = words
	set_value_width(VALUE_WIDTH)
	setup(0, words.size() - 1, start)


func set_value_no_signal(new_value: int) -> void:
	value = clampi(new_value, min_value, max_value)
	_refresh()


func step(delta: int) -> void:
	if not editable:
		return
	var new_value := clampi(value + delta, min_value, max_value)
	if new_value == value:
		return
	value = new_value
	_refresh()
	Audio.play(&"click", -10.0)
	value_changed.emit(value)


func _gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_left", true):
		step(-1)
		accept_event()
	elif event.is_action_pressed("ui_right", true):
		step(1)
		accept_event()
	var wheel := event as InputEventMouseButton
	if wheel and wheel.pressed and wheel.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		step(1 if wheel.button_index == MOUSE_BUTTON_WHEEL_UP else -1)
		accept_event()


func _draw() -> void:
	if has_focus():
		draw_style_box(get_theme_stylebox("focus", "Button"), Rect2(Vector2.ZERO, size))


func _refresh() -> void:
	_label.text = choices[value] if value < choices.size() else str(value)
	_minus.disabled = not editable or value <= min_value
	_plus.disabled = not editable or value >= max_value
	modulate.a = 1.0 if editable else 0.55
