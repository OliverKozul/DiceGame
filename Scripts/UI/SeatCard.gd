class_name SeatCard
extends PanelContainer
## One player's place at the table: seal, rank and name; health, score, renown and gold;
## and a strip that shows what they said, flipping over to what they did at the reveal.

const KEPT := Color("e9c46a")
const LIED := Color("9b2416")
const LIED_CONTRAST := Color("ff5a3c")

var player_id := 0

var _seal_holder := HBoxContainer.new()
var _title := RichTextLabel.new()
var _stats := RichTextLabel.new()
var _strip := PanelContainer.new()
var _strip_text := RichTextLabel.new()
var _overlay := Control.new()
var _stamp: Label
var _seat := -1
var _name := ""


func _ready() -> void:
	theme_type_variation = &"SeatPanel"
	mouse_filter = Control.MOUSE_FILTER_PASS
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 3)
	add_child(column)
	_seal_holder.add_theme_constant_override("separation", 8)
	column.add_child(_seal_holder)
	for rich in [_title, _stats, _strip_text]:
		rich.bbcode_enabled = true
		rich.fit_content = true
		rich.scroll_active = false
		rich.autowrap_mode = TextServer.AUTOWRAP_OFF
		rich.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rich.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.add_theme_font_size_override("normal_font_size", 17)
	_title.add_theme_font_size_override("bold_font_size", 17)
	_seal_holder.add_child(_title)
	_stats.add_theme_font_size_override("normal_font_size", 15)
	column.add_child(_stats)
	var strip_box := StyleBoxFlat.new()
	strip_box.bg_color = Color(0, 0, 0, 0.22)
	strip_box.set_corner_radius_all(4)
	strip_box.content_margin_left = 8
	strip_box.content_margin_right = 8
	strip_box.content_margin_top = 2
	strip_box.content_margin_bottom = 2
	_strip.add_theme_stylebox_override("panel", strip_box)
	_strip_text.add_theme_font_size_override("normal_font_size", 15)
	_strip_text.add_theme_font_size_override("bold_font_size", 15)
	_strip.add_child(_strip_text)
	column.add_child(_strip)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)


func refresh(view: GameState, p: PlayerState, me: int, waiting: bool) -> void:
	player_id = p.id
	if p.seat != _seat or p.name != _name:
		_seat = p.seat
		_name = p.name
		for child in _seal_holder.get_children():
			if child != _title:
				child.queue_free()
		var seal := SeatStyle.make_seal(p.seat, p.name, 28)
		_seal_holder.add_child(seal)
		_seal_holder.move_child(seal, 0)
	theme_type_variation = &"ActiveSeatPanel" if waiting else &"SeatPanel"
	modulate = Color(0.6, 0.6, 0.6) if p.knocked_out else Color.WHITE

	var rank := view.initiative.find(p.id)
	var title := "[b]%s%s[/b]" % ["#%d  " % (rank + 1) if rank >= 0 else "", Icons.rich(p.name)]
	var tags := PackedStringArray()
	if p.id == me:
		tags.append("you")
	if p.is_bot:
		tags.append("bot" if p.connected else "left · bot plays")
	if not tags.is_empty():
		title += " [color=#cdb48c]%s[/color]" % ", ".join(tags)
	if p.plan_locked and not view.plans_public():
		title += "  " + Icons.bb("lock", 16)
	if waiting:
		title += "  [color=#f7d9a2]…[/color]"
	_title.text = title

	var stats := "%s %d/%d   %s %d   %s %d   %s %d" % [Icons.bb("heal", 16), p.hp, p.max_hp, Icons.bb("score", 16), p.score,
		Icons.bb("renown", 16), p.renown, Icons.bb("gold", 16), p.gold]
	if p.roll_done and view.phase != GameState.Phase.ROLL:
		stats += "   %s %d  %s %d" % [Icons.bb("combat", 16), p.combat, Icons.bb("cunning", 16), p.cunning]
	_stats.text = stats
	_strip_text.text = _strip_for(view, p)


func _strip_for(view: GameState, p: PlayerState) -> String:
	if p.knocked_out:
		return "%s [color=#e8a090]Knocked out, back after turn %d[/color]" % [Icons.bb("knockout", 16), p.out_until_turn]
	if view.phase == GameState.Phase.ROLL:
		var faces := PackedStringArray()
		for face in p.showing_faces():
			faces.append(Icons.rich(Face.label(face), 16))
		return "%s  %s" % [" ".join(faces), "[color=#cdb48c]kept[/color]" if p.roll_done else "[color=#cdb48c]rolling…[/color]"]
	if view.plans_public() and p.plan_locked:
		var verdict := "[color=#%s]kept word[/color]" % KEPT.to_html(false) if p.kept_word else "[color=#%s]lied[/color]" % _lied_color().to_html(false)
		return "Did: [b]%s[/b] · %s" % [Icons.rich(view.describe_plan(p), 16), verdict]
	if p.declared:
		return "Says: [b]%s[/b]" % Icons.rich(view.describe_choice(p.intention_action, p.intention_target), 16)
	return "[color=#cdb48c]…[/color]"


func _lied_color() -> Color:
	return LIED_CONTRAST if Settings.get_value("gameplay", "high_contrast") else Color("e08a7a")


# --- Animations used by the presenter -------------------------------------------

## Flips the strip over, revealing `text`.
func flip_strip(text: String, duration: float) -> void:
	_strip.pivot_offset = _strip.size / 2.0
	Audio.play(&"card_flip", -4.0)
	if duration <= 0.0:
		_strip_text.text = text
		return
	var tween := create_tween()
	tween.tween_property(_strip, "scale:y", 0.0, duration / 2.0).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void: _strip_text.text = text)
	tween.tween_property(_strip, "scale:y", 1.0, duration / 2.0).set_ease(Tween.EASE_OUT)
	await tween.finished


func set_strip(text: String) -> void:
	_strip_text.text = text


## A rubber stamp slammed onto the card ("Word kept", "Liar", "Knocked out").
func stamp(text: String, kind: String, duration: float) -> void:
	clear_stamp()
	_stamp = Label.new()
	_stamp.text = text.to_upper()
	var box := StyleBoxFlat.new()
	box.set_corner_radius_all(4)
	box.set_border_width_all(2)
	box.content_margin_left = 10
	box.content_margin_right = 10
	box.content_margin_top = 2
	box.content_margin_bottom = 2
	match kind:
		"kept":
			box.bg_color = KEPT
			box.border_color = Color("7a5418")
			_stamp.add_theme_color_override("font_color", Color("2a1a0c"))
		_:
			box.bg_color = LIED_CONTRAST.darkened(0.2) if Settings.get_value("gameplay", "high_contrast") else LIED
			box.border_color = Color("f0b48a")
			_stamp.add_theme_color_override("font_color", Color("fff3e4"))
	_stamp.add_theme_stylebox_override("normal", box)
	_stamp.add_theme_font_size_override("font_size", 14)
	_overlay.add_child(_stamp)
	await get_tree().process_frame
	_stamp.position = Vector2(size.x - _stamp.size.x - 12, size.y * 0.3)
	_stamp.pivot_offset = _stamp.size / 2.0
	_stamp.rotation_degrees = -7.0
	Audio.play(&"stamp", -2.0)
	if duration <= 0.0:
		return
	_stamp.scale = Vector2(2.4, 2.4)
	_stamp.modulate.a = 0.0
	var tween := create_tween().set_parallel()
	tween.tween_property(_stamp, "scale", Vector2.ONE, duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_stamp, "modulate:a", 1.0, duration * 0.5)
	await tween.finished
	# The strip already says who kept their word; the stamp is a flourish that fades away.
	if _stamp:
		var fade := _stamp.create_tween()
		fade.tween_interval(3.0)
		fade.tween_property(_stamp, "modulate:a", 0.0, 0.6)
		fade.tween_callback(clear_stamp)


func clear_stamp() -> void:
	if _stamp:
		_stamp.queue_free()
		_stamp = null


## Text that rises off the card and fades, e.g. "-4" damage or "+1 renown".
func float_text(text: String, color: Color, duration: float) -> void:
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("normal_font_size", 22)
	label.add_theme_color_override("default_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("outline_size", 6)
	label.text = Icons.rich(text, 20)
	label.custom_minimum_size = Vector2(160, 0)
	_overlay.add_child(label)
	label.position = Vector2(size.x * 0.55, size.y * 0.35)
	if duration <= 0.0:
		label.queue_free()
		return
	var tween := create_tween().set_parallel()
	tween.tween_property(label, "position:y", label.position.y - 34.0, duration).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, duration).set_delay(duration * 0.45)
	tween.chain().tween_callback(label.queue_free)


func shake(strength: float = 6.0) -> void:
	if Settings.reduced_motion():
		return
	var tween := create_tween()
	for i in 5:
		tween.tween_property(self, "position:x", position.x + (strength if i % 2 == 0 else -strength), 0.04)
	tween.tween_property(self, "position:x", position.x, 0.04)


func pulse(color: Color) -> void:
	if Settings.reduced_motion():
		return
	var tween := create_tween()
	tween.tween_property(self, "self_modulate", color, 0.12)
	tween.tween_property(self, "self_modulate", Color.WHITE, 0.35)
