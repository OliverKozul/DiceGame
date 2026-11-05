class_name MarketTile
extends Button
## A face tile in the market: an ivory die face (icon and value) with its price on a gold
## coin chip. It lifts when chosen and pops when hovered; outside your shopping turn it can
## still be read but does not respond. It takes keyboard and pad focus while you shop.

const INK := Color("2b1c10")
const IVORY := Color("efe2c4")
const IVORY_HOVER := Color("f8eed6")
const CHOSEN := Color("f3d27a")
const EDGE := Color("7a5418")

func setup(face: int, price: int, shopping: bool, affordable: bool, chosen: bool) -> void:
	text = ""
	custom_minimum_size = Vector2(104, 46)
	toggle_mode = shopping
	button_pressed = chosen
	disabled = shopping and not affordable
	tooltip_text = tr("{face} for {price} gold").format({"face": Face.describe(face), "price": price})
	if shopping and not affordable:
		tooltip_text += " " + tr("(you cannot afford it)")
	if not shopping:
		mouse_filter = Control.MOUSE_FILTER_PASS
		focus_mode = Control.FOCUS_NONE
	add_theme_stylebox_override("normal", _box(IVORY, EDGE, 2))
	add_theme_stylebox_override("hover", _box(IVORY_HOVER if shopping else IVORY, Color("c9952f") if shopping else EDGE, 2))
	add_theme_stylebox_override("pressed", _box(CHOSEN, Color("8a5a10"), 3))
	add_theme_stylebox_override("hover_pressed", _box(CHOSEN, Color("8a5a10"), 3))
	add_theme_stylebox_override("disabled", _box(IVORY.darkened(0.35), EDGE.darkened(0.3), 2))
	var focus := _box(Color.TRANSPARENT, Color("f3d27a"), 3)
	focus.draw_center = false
	focus.shadow_size = 0
	focus.set_expand_margin_all(3)
	add_theme_stylebox_override("focus", focus)

	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", 6)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	var symbol := TextureRect.new()
	symbol.texture = Icons.texture(Icons.for_kind(Face.kind_of(face)))
	symbol.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	symbol.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	symbol.custom_minimum_size = Vector2(26, 26)
	symbol.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(symbol)
	var value := Label.new()
	value.text = "x2" if Face.kind_of(face) == Face.Kind.DOUBLE else str(Face.value_of(face))
	value.add_theme_font_size_override("font_size", 22)
	value.add_theme_color_override("font_color", INK)
	value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(value)
	var chip := HBoxContainer.new()
	chip.add_theme_constant_override("separation", 1)
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var coin := TextureRect.new()
	coin.texture = Icons.texture("gold")
	coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	coin.custom_minimum_size = Vector2(16, 16)
	coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(coin)
	var cost := Label.new()
	cost.text = str(price)
	cost.add_theme_font_size_override("font_size", 15)
	cost.add_theme_color_override("font_color", Color("6b4a10") if affordable or not shopping else Color("9b2416"))
	cost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(cost)
	row.add_child(chip)
	if disabled:
		modulate = Color(1, 1, 1, 0.7)
	if chosen:
		pivot_offset = custom_minimum_size / 2.0
		scale = Vector2(1.07, 1.07)


func _box(color: Color, border: Color, width: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = border
	box.set_border_width_all(width)
	box.set_corner_radius_all(7)
	box.shadow_color = Color(0, 0, 0, 0.35)
	box.shadow_size = 3
	box.shadow_offset = Vector2(0, 2)
	return box
