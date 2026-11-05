class_name Overlay
extends Control
## Base for modal panels (settings, rules, confirmations, the escape menu): a dimmed
## backdrop, a centred panel that eases in and out, and Esc (or the pad's B button) to close.
## While open, keyboard and pad focus stays inside the panel and returns where it was after.
## Subclasses add their controls to `content` in _build().

signal closed

const OPEN_TIME := 0.18

var panel: PanelContainer
var content: VBoxContainer
var panel_size := Vector2(620, 520)
## Centres the panel; drawn smaller when the panel would not otherwise fit on the screen.
var _center := CenterContainer.new()
var _tween: Tween
var _focus_before: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.01, 0.0, 0.62)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	add_child(_center)
	panel = _make_panel()
	panel.custom_minimum_size = panel_size
	_center.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 26)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	panel.add_child(margin)
	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	margin.add_child(content)
	_build()
	resized.connect(fit_panel)
	panel.minimum_size_changed.connect(fit_panel)


## The panel style; override for parchment.
func _make_panel() -> PanelContainer:
	var wood := PanelContainer.new()
	wood.theme_type_variation = &"WoodPanel"
	return wood


## Override to add controls to `content`.
func _build() -> void:
	pass


func open() -> void:
	if visible:
		return
	_focus_before = get_viewport().gui_get_focus_owner()
	show()
	Controls.push_scope(self)
	Audio.play(&"cloth", -6.0)
	fit_panel()
	_animate(true)
	_focus_first.call_deferred()


func close() -> void:
	if not visible:
		return
	Controls.pop_scope(self)
	await _animate(false)
	hide()
	if is_instance_valid(_focus_before) and _focus_before.is_visible_in_tree():
		Controls.focus(_focus_before)
	_focus_before = null
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


## Draws the panel smaller if it needs more room than the window has (a large interface size).
## The container is scaled, not the panel: containers reset the scale of what they hold.
func fit_panel() -> void:
	if not visible:
		return
	var room := size - Vector2(16, 16)
	var needed := panel.get_combined_minimum_size()
	var fit := minf(1.0, minf(room.x / maxf(needed.x, 1.0), room.y / maxf(needed.y, 1.0)))
	_center.scale = Vector2.ONE * fit
	_center.size = size / fit


func _animate(opening: bool) -> void:
	if _tween:
		_tween.kill()
	var duration := 0.0 if Settings.reduced_motion() else OPEN_TIME
	panel.pivot_offset = panel.size / 2.0
	if duration <= 0.0:
		modulate.a = 1.0 if opening else 0.0
		panel.scale = Vector2.ONE
		return
	if opening:
		modulate.a = 0.0
		panel.scale = Vector2(0.94, 0.94)
	_tween = create_tween().set_parallel().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	_tween.tween_property(self, "modulate:a", 1.0 if opening else 0.0, duration)
	_tween.tween_property(panel, "scale", Vector2.ONE if opening else Vector2(0.96, 0.96), duration)
	await _tween.finished


## Focuses the first control a player would use (keys and pad only; see Controls).
func _focus_first() -> void:
	Controls.focus(_first_control())


## The control focus starts on; override to start somewhere else than the first button.
func _first_control() -> Control:
	return Controls.first_focusable(content)


## A label with a theme variation, added to `parent`.
static func add_label(parent: Node, text: String, variation: StringName = &"") -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = variation
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label


static func add_button(parent: Node, text: String, on_pressed: Callable, variation: StringName = &"") -> Button:
	var button := Button.new()
	button.text = text
	button.theme_type_variation = variation
	button.custom_minimum_size = Vector2(0, 44)
	button.pressed.connect(on_pressed)
	parent.add_child(button)
	return button
