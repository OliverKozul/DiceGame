class_name SeatStyle
extends RefCounted
## Each seat's colour and crest, used wherever a player's name appears.

const COLORS: Array[Color] = [
	Color("b8402f"),
	Color("3f6fb0"),
	Color("3e8a4f"),
	Color("c98b1c"),
	Color("7d4ba8"),
	Color("2f8f8a"),
]
const NAMES: Array[String] = ["Crimson", "Azure", "Forest", "Amber", "Violet", "Teal"]


static func color(seat: int) -> Color:
	return COLORS[posmod(seat, COLORS.size())]


static func hex(seat: int) -> String:
	return color(seat).to_html(false)


## A wax seal: a coloured disc with the player's initial.
static func make_seal(seat: int, player_name: String, size: float = 30.0) -> Control:
	var seal := Panel.new()
	seal.custom_minimum_size = Vector2(size, size)
	seal.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var box := StyleBoxFlat.new()
	box.bg_color = color(seat)
	box.set_corner_radius_all(int(size / 2.0))
	box.border_color = color(seat).darkened(0.45)
	box.set_border_width_all(2)
	box.shadow_color = Color(0, 0, 0, 0.5)
	box.shadow_size = 3
	box.shadow_offset = Vector2(0, 2)
	seal.add_theme_stylebox_override("panel", box)
	var letter := Label.new()
	letter.text = player_name.left(1).to_upper() if not player_name.is_empty() else "?"
	letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	letter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	letter.add_theme_color_override("font_color", Color("fff2dc"))
	letter.add_theme_font_size_override("font_size", int(size * 0.55))
	letter.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	seal.add_child(letter)
	return seal
