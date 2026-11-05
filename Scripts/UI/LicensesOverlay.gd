class_name LicensesOverlay
extends Overlay
## The licence texts the game must carry: its fonts, GodotSteam, and the Godot Engine with
## everything built into it. English, as licences are; filled in when first opened, as it is long.

const FILES: Array[Array] = [
	["Grenze Gotisch (font)", "res://Assets/Licenses/GrenzeGotisch-OFL.txt"],
	["Lora (font)", "res://Assets/Licenses/Lora-OFL.txt"],
	["GodotSteam", "res://Assets/Licenses/GodotSteam-MIT.txt"],
]

var _text := RichTextLabel.new()


func _init() -> void:
	panel_size = Vector2(760, 560)


func _build() -> void:
	add_label(content, tr("Licences"), &"Heading").horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text.bbcode_enabled = false
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text.focus_mode = Control.FOCUS_ALL
	_text.add_theme_font_size_override("normal_font_size", 14)
	content.add_child(_text)
	add_button(content, tr("Back"), close)


func open() -> void:
	if _text.get_parsed_text().is_empty():
		_text.text = notices()
	super()


## Every notice as plain text.
static func notices() -> String:
	var parts := PackedStringArray()
	for entry: Array in FILES:
		parts.append("%s\n\n%s" % [entry[0], FileAccess.get_file_as_string(entry[1]).strip_edges()])
	parts.append("Godot Engine\n\n" + Engine.get_license_text().strip_edges())
	var components := PackedStringArray()
	for component: Dictionary in Engine.get_copyright_info():
		for part: Dictionary in component.parts:
			components.append("%s\n%s\nLicense: %s" % [component.name, "\n".join(part.copyright), part.license])
	parts.append("Parts of the Godot Engine\n\n" + "\n\n".join(components))
	var licenses: Dictionary = Engine.get_license_info()
	for license: String in licenses:
		parts.append("License: %s\n\n%s" % [license, str(licenses[license]).strip_edges()])
	return "\n\n\n".join(parts)
