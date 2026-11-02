extends SceneTree
## Generates res://Assets/Theme.tres, the tavern UI theme. Edit the colours and sizes here
## and rerun:  godot --headless --path . --script res://tools/build_theme.gd

const BODY_FONT := "res://Assets/Fonts/Lora-VariableFont_wght.ttf"
const TITLE_FONT := "res://Assets/Fonts/CloisterBlack.ttf"

const TEXT := Color("f1e4c6")
const TEXT_DIM := Color("cdb48c")
const INK := Color("2b1c10")
const INK_DIM := Color("5a4128")
const GOLD := Color("f7d9a2")
const WOOD_DARK := Color("2a190e")
const WOOD := Color("3c2413")
const WOOD_EDGE := Color("74482a")
const PLANK := Color("c08a45")
const PLANK_HOVER := Color("d29b52")
const PLANK_PRESSED := Color("a8722f")
const PLANK_EDGE := Color("5e3a17")
const PLANK_DEEP := Color("40250f")
const PAPER := Color("eadcbc")
const PAPER_EDGE := Color("7a5428")


func _init() -> void:
	var theme := Theme.new()
	var body: FontFile = load(BODY_FONT)
	var title: FontFile = load(TITLE_FONT)
	theme.default_font = body
	theme.default_font_size = 18

	_labels(theme, title)
	_buttons(theme)
	_inputs(theme)
	_panels(theme)
	_lists(theme)
	_ranges(theme)

	var err := ResourceSaver.save(theme, "res://Assets/Theme.tres")
	print("Theme saved: %s" % error_string(err))
	quit(0 if err == OK else 1)


func _box(bg: Color, border: Color = Color.TRANSPARENT, width: int = 0, radius: int = 6, margin: Vector4 = Vector4(14, 8, 14, 8)) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(width)
	box.set_corner_radius_all(radius)
	box.content_margin_left = margin.x
	box.content_margin_top = margin.y
	box.content_margin_right = margin.z
	box.content_margin_bottom = margin.w
	box.anti_aliasing = true
	return box


func _labels(theme: Theme, title: FontFile) -> void:
	theme.set_color("font_color", "Label", TEXT)
	theme.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.0))
	theme.set_color("default_color", "RichTextLabel", TEXT)

	_variation(theme, "Title", "Label")
	theme.set_font("font", "Title", title)
	theme.set_font_size("font_size", "Title", 72)
	theme.set_color("font_color", "Title", GOLD)
	theme.set_color("font_shadow_color", "Title", Color(0.12, 0.05, 0.01, 0.9))
	theme.set_constant("shadow_offset_y", "Title", 3)
	theme.set_constant("shadow_offset_x", "Title", 0)

	_variation(theme, "Heading", "Label")
	theme.set_font("font", "Heading", title)
	theme.set_font_size("font_size", "Heading", 36)
	theme.set_color("font_color", "Heading", GOLD)
	theme.set_color("font_shadow_color", "Heading", Color(0.12, 0.05, 0.01, 0.8))
	theme.set_constant("shadow_offset_y", "Heading", 2)

	_variation(theme, "InkHeading", "Label")
	theme.set_font("font", "InkHeading", title)
	theme.set_font_size("font_size", "InkHeading", 32)
	theme.set_color("font_color", "InkHeading", Color("5e1a10"))

	_variation(theme, "Ink", "Label")
	theme.set_color("font_color", "Ink", INK)

	_variation(theme, "InkDim", "Label")
	theme.set_color("font_color", "InkDim", INK_DIM)
	theme.set_font_size("font_size", "InkDim", 15)

	_variation(theme, "Dim", "Label")
	theme.set_color("font_color", "Dim", TEXT_DIM)
	theme.set_font_size("font_size", "Dim", 15)

	_variation(theme, "Caps", "Label")
	theme.set_color("font_color", "Caps", Color("d8b98a"))
	theme.set_font_size("font_size", "Caps", 13)

	_variation(theme, "InkRich", "RichTextLabel")
	theme.set_color("default_color", "InkRich", INK)


func _buttons(theme: Theme) -> void:
	var normal := _box(PLANK, PLANK_EDGE, 2, 6, Vector4(18, 8, 18, 10))
	normal.border_color = PLANK_EDGE
	normal.border_width_bottom = 5
	normal.shadow_color = Color(0, 0, 0, 0.45)
	normal.shadow_size = 6
	normal.shadow_offset = Vector2(0, 4)
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = PLANK_HOVER
	var pressed: StyleBoxFlat = normal.duplicate()
	pressed.bg_color = PLANK_PRESSED
	pressed.border_width_bottom = 2
	pressed.border_width_top = 4
	pressed.shadow_size = 2
	pressed.shadow_offset = Vector2(0, 1)
	var disabled: StyleBoxFlat = normal.duplicate()
	disabled.bg_color = Color("7a6146")
	disabled.border_color = Color("4a3622")
	disabled.shadow_size = 2
	var focus := _box(Color.TRANSPARENT, GOLD, 2, 8)
	focus.draw_center = false
	focus.expand_margin_left = 3
	focus.expand_margin_right = 3
	focus.expand_margin_top = 3
	focus.expand_margin_bottom = 3

	for type in ["Button", "OptionButton", "MenuButton"]:
		theme.set_stylebox("normal", type, normal)
		theme.set_stylebox("hover", type, hover)
		theme.set_stylebox("pressed", type, pressed)
		theme.set_stylebox("hover_pressed", type, pressed)
		theme.set_stylebox("disabled", type, disabled)
		theme.set_stylebox("focus", type, focus)
		theme.set_color("font_color", type, INK)
		theme.set_color("font_hover_color", type, INK)
		theme.set_color("font_pressed_color", type, INK)
		theme.set_color("font_hover_pressed_color", type, INK)
		theme.set_color("font_focus_color", type, INK)
		theme.set_color("font_disabled_color", type, Color("3a2a1a"))
		theme.set_color("icon_normal_color", type, Color.WHITE)
		theme.set_constant("h_separation", type, 8)

	# A selected toggle (a chosen die, an active tab) glows gold.
	var toggled: StyleBoxFlat = pressed.duplicate()
	toggled.bg_color = Color("e9c46a")
	toggled.border_color = Color("fff1c4")
	theme.set_stylebox("pressed", "Button", toggled)
	theme.set_stylebox("hover_pressed", "Button", toggled)

	_variation(theme, "PlankButton", "Button")
	theme.set_font_size("font_size", "PlankButton", 20)

	_variation(theme, "TextButton", "Button")
	var flat := _box(Color.TRANSPARENT, Color.TRANSPARENT, 0, 4, Vector4(8, 4, 8, 4))
	var flat_hover := _box(Color(1, 0.85, 0.6, 0.08), Color.TRANSPARENT, 0, 4, Vector4(8, 4, 8, 4))
	for state in ["normal", "pressed", "disabled", "hover_pressed"]:
		theme.set_stylebox(state, "TextButton", flat)
	theme.set_stylebox("hover", "TextButton", flat_hover)
	for color in ["font_color", "font_pressed_color", "font_focus_color"]:
		theme.set_color(color, "TextButton", TEXT)
	theme.set_color("font_hover_color", "TextButton", GOLD)
	theme.set_color("font_disabled_color", "TextButton", TEXT_DIM)

	theme.set_color("font_color", "CheckBox", TEXT)
	theme.set_color("font_hover_color", "CheckBox", GOLD)
	theme.set_color("font_pressed_color", "CheckBox", TEXT)
	theme.set_color("font_color", "CheckButton", TEXT)
	theme.set_color("font_hover_color", "CheckButton", GOLD)
	theme.set_color("font_pressed_color", "CheckButton", TEXT)
	var empty := StyleBoxEmpty.new()
	for type in ["CheckBox", "CheckButton"]:
		for state in ["normal", "pressed", "hover", "hover_pressed", "disabled"]:
			theme.set_stylebox(state, type, empty)
		theme.set_stylebox("focus", type, focus)


func _inputs(theme: Theme) -> void:
	var field := _box(PAPER, PAPER_EDGE, 2, 4, Vector4(12, 6, 12, 6))
	var field_focus: StyleBoxFlat = field.duplicate()
	field_focus.border_color = Color("c8452f")
	var field_disabled: StyleBoxFlat = field.duplicate()
	field_disabled.bg_color = Color("b9a988")
	theme.set_stylebox("normal", "LineEdit", field)
	theme.set_stylebox("focus", "LineEdit", field_focus)
	theme.set_stylebox("read_only", "LineEdit", field_disabled)
	theme.set_color("font_color", "LineEdit", INK)
	theme.set_color("font_placeholder_color", "LineEdit", Color("8a7458"))
	theme.set_color("caret_color", "LineEdit", INK)
	theme.set_color("selection_color", "LineEdit", Color("c8452f66"))
	theme.set_color("font_uneditable_color", "LineEdit", INK_DIM)


func _panels(theme: Theme) -> void:
	var wood := _box(WOOD, WOOD_EDGE, 1, 8, Vector4(14, 12, 14, 12))
	wood.shadow_color = Color(0, 0, 0, 0.5)
	wood.shadow_size = 10
	wood.shadow_offset = Vector2(0, 6)
	theme.set_stylebox("panel", "PanelContainer", wood)
	theme.set_stylebox("panel", "Panel", wood)

	_variation(theme, "WoodPanel", "PanelContainer")
	theme.set_stylebox("panel", "WoodPanel", wood)

	_variation(theme, "SeatPanel", "PanelContainer")
	var seat := _box(Color("4a2c16"), WOOD_EDGE, 1, 8, Vector4(12, 10, 12, 10))
	seat.shadow_color = Color(0, 0, 0, 0.45)
	seat.shadow_size = 8
	seat.shadow_offset = Vector2(0, 5)
	theme.set_stylebox("panel", "SeatPanel", seat)

	_variation(theme, "ActiveSeatPanel", "PanelContainer")
	var active: StyleBoxFlat = seat.duplicate()
	active.border_color = GOLD
	active.set_border_width_all(2)
	active.shadow_color = Color(1, 0.7, 0.3, 0.35)
	active.shadow_size = 14
	active.shadow_offset = Vector2.ZERO
	theme.set_stylebox("panel", "ActiveSeatPanel", active)

	_variation(theme, "PaperPanel", "PanelContainer")
	# No content margin: the parchment texture fills the whole panel; content brings its own margin.
	var paper := _box(PAPER, PAPER_EDGE, 0, 4, Vector4(0, 0, 0, 0))
	paper.shadow_color = Color(0, 0, 0, 0.5)
	paper.shadow_size = 10
	paper.shadow_offset = Vector2(0, 6)
	theme.set_stylebox("panel", "PaperPanel", paper)

	_variation(theme, "FeltPanel", "PanelContainer")
	var felt := _box(Color("1d3328"), WOOD, 6, 10, Vector4(12, 10, 12, 10))
	felt.shadow_color = Color(0, 0, 0, 0.5)
	felt.shadow_size = 10
	theme.set_stylebox("panel", "FeltPanel", felt)

	_variation(theme, "ClearPanel", "PanelContainer")
	theme.set_stylebox("panel", "ClearPanel", StyleBoxEmpty.new())

	var popup := _box(WOOD, WOOD_EDGE, 1, 6, Vector4(8, 8, 8, 8))
	theme.set_stylebox("panel", "PopupMenu", popup)
	theme.set_stylebox("hover", "PopupMenu", _box(Color("6b4423"), Color.TRANSPARENT, 0, 4))
	theme.set_color("font_color", "PopupMenu", TEXT)
	theme.set_color("font_hover_color", "PopupMenu", GOLD)
	theme.set_stylebox("panel", "PopupPanel", popup)
	theme.set_stylebox("panel", "AcceptDialog", popup)
	theme.set_stylebox("embedded_border", "Window", popup)
	theme.set_stylebox("embedded_unfocused_border", "Window", popup)
	theme.set_color("title_color", "Window", GOLD)

	var tooltip := _box(PAPER, PAPER_EDGE, 1, 4, Vector4(10, 6, 10, 6))
	theme.set_stylebox("panel", "TooltipPanel", tooltip)
	theme.set_color("font_color", "TooltipLabel", INK)

	var line := StyleBoxLine.new()
	line.color = WOOD_EDGE
	line.thickness = 1
	theme.set_stylebox("separator", "HSeparator", line)
	var vline := StyleBoxLine.new()
	vline.color = WOOD_EDGE
	vline.vertical = true
	theme.set_stylebox("separator", "VSeparator", vline)


func _lists(theme: Theme) -> void:
	theme.set_stylebox("panel", "ItemList", _box(WOOD_DARK, WOOD_EDGE, 1, 6, Vector4(6, 6, 6, 6)))
	theme.set_stylebox("focus", "ItemList", StyleBoxEmpty.new())
	theme.set_stylebox("selected", "ItemList", _box(Color("6b4423"), Color.TRANSPARENT, 0, 4))
	theme.set_stylebox("selected_focus", "ItemList", _box(Color("7a4f29"), Color.TRANSPARENT, 0, 4))
	theme.set_stylebox("hovered", "ItemList", _box(Color("4a2c16"), Color.TRANSPARENT, 0, 4))
	theme.set_color("font_color", "ItemList", TEXT)
	theme.set_color("font_selected_color", "ItemList", GOLD)
	theme.set_color("font_hovered_color", "ItemList", GOLD)


func _ranges(theme: Theme) -> void:
	var track := _box(WOOD_DARK, WOOD_EDGE, 1, 4, Vector4(0, 4, 0, 4))
	var fill := _box(PLANK, PLANK_EDGE, 1, 4, Vector4(0, 4, 0, 4))
	theme.set_stylebox("slider", "HSlider", track)
	theme.set_stylebox("grabber_area", "HSlider", fill)
	theme.set_stylebox("grabber_area_highlight", "HSlider", fill)
	var bar := _box(WOOD_DARK, WOOD_EDGE, 1, 4, Vector4(0, 0, 0, 0))
	var bar_fill := _box(Color("b8402f"), Color.TRANSPARENT, 0, 4, Vector4(0, 0, 0, 0))
	theme.set_stylebox("background", "ProgressBar", bar)
	theme.set_stylebox("fill", "ProgressBar", bar_fill)
	theme.set_color("font_color", "ProgressBar", TEXT)
	var grabber := _box(Color("6b4423"), Color.TRANSPARENT, 0, 4, Vector4(4, 4, 4, 4))
	for type in ["VScrollBar", "HScrollBar"]:
		theme.set_stylebox("scroll", type, _box(Color(0, 0, 0, 0.2), Color.TRANSPARENT, 0, 4, Vector4(4, 4, 4, 4)))
		theme.set_stylebox("grabber", type, grabber)
		theme.set_stylebox("grabber_highlight", type, _box(Color("8c5b31"), Color.TRANSPARENT, 0, 4, Vector4(4, 4, 4, 4)))
		theme.set_stylebox("grabber_pressed", type, _box(Color("a8722f"), Color.TRANSPARENT, 0, 4, Vector4(4, 4, 4, 4)))


func _variation(theme: Theme, name: String, base: String) -> void:
	theme.set_type_variation(name, base)
