class_name SeatCard
extends PanelContainer
## One player's place at the table: seal, rank and name; a health bar; trophies, renown with
## the oath's three pips, gold, and this turn's combat and cunning; and a strip that shows
## what they said, then what they did. Numbers tick to new values and pop when they change.
## It takes keyboard and pad focus (Enter or A opens the player's sheet).

const KEPT := Color("e9c46a")
const LIED := Color("9b2416")
const LIED_CONTRAST := Color("ff5a3c")
const GAIN := Color(1.6, 1.5, 0.9)
const LOSS := Color(1.8, 0.7, 0.6)
const PIP_ON := Color("f2c14e")
const PIP_OFF := Color(0.0, 0.0, 0.0, 0.35)
const PIP_EDGE := Color("b8862b")
const DIM := Color("cdb48c")

var player_id := 0
## The table's effects layer; floating text rises there so it is never clipped or covered.
var fx_layer: Control

var _seal_holder := HBoxContainer.new()
var _title := RichTextLabel.new()
var _health := HealthBar.new()
var _chips := HBoxContainer.new()
var _strip := PanelContainer.new()
var _strip_text := RichTextLabel.new()
var _overlay := Control.new()
var _stamp: Label
var _seat := -1
var _name := ""
## Floating texts still rising from this card: each new one starts above the last.
var _floating := 0
var _values: Dictionary[String, int] = {}
var _labels: Dictionary[String, Label] = {}
var _chip_nodes: Dictionary[String, Control] = {}
var _pips: Array[Panel] = []
var _oath := -1
var _waiting_tween: Tween


func _ready() -> void:
	theme_type_variation = &"SeatPanel"
	mouse_filter = Control.MOUSE_FILTER_PASS
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	add_child(column)
	_seal_holder.add_theme_constant_override("separation", 8)
	column.add_child(_seal_holder)
	for rich in [_title, _strip_text]:
		rich.bbcode_enabled = true
		rich.fit_content = true
		rich.scroll_active = false
		# Wrapping, not a single line: an unwrapped label would widen the column to fit its text.
		rich.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rich.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rich.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.add_theme_font_size_override("normal_font_size", 17)
	_title.add_theme_font_size_override("bold_font_size", 17)
	_seal_holder.add_child(_title)
	column.add_child(_health)

	_chips.add_theme_constant_override("separation", 12)
	column.add_child(_chips)
	_add_chip("score", "score")
	_add_chip("renown", "renown")
	var pips := HBoxContainer.new()
	pips.add_theme_constant_override("separation", 3)
	pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in Content.OATH_LENGTH:
		var pip := Panel.new()
		pip.custom_minimum_size = Vector2(9, 9)
		pip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pips.add_child(pip)
		_pips.append(pip)
	_chip_nodes["renown"].add_child(pips)
	_add_chip("gold", "gold")
	_add_chip("combat", "combat")
	_add_chip("cunning", "cunning")

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


func _add_chip(key: String, icon_name: String) -> void:
	var chip := HBoxContainer.new()
	chip.add_theme_constant_override("separation", 3)
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon := TextureRect.new()
	icon.texture = Icons.texture(icon_name)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(17, 17)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(icon)
	var label := Label.new()
	label.add_theme_font_size_override("font_size", 16)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(label)
	_chips.add_child(chip)
	_labels[key] = label
	_chip_nodes[key] = chip


## Draws `p`. `seconds` animates what changed since the last refresh (0 = at once).
func refresh(view: GameState, p: PlayerState, me: int, waiting: bool, leader: bool, seconds: float) -> void:
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
	_set_waiting(waiting)
	modulate = Color(0.55, 0.55, 0.55) if p.knocked_out else Color.WHITE

	var rank := view.initiative.find(p.id)
	var title := "[b]%s%s[/b]" % ["#%d  " % (rank + 1) if rank >= 0 else "", Icons.rich(p.name)]
	if leader:
		title += " " + Icons.bb("crown", 17)
	var tags := PackedStringArray()
	if p.id == me:
		tags.append(tr("you"))
	if p.is_bot:
		tags.append(tr("bot") if p.connected else tr("away · bot plays"))
	if not tags.is_empty():
		title += " [color=#%s]%s[/color]" % [DIM.to_html(false), ", ".join(tags)]
	if p.plan_locked and not view.plans_public():
		title += "  " + Icons.bb("lock", 16)
	if waiting:
		title += "  [color=#f7d9a2]…[/color]"
	_title.text = title

	_health.set_hp(p.hp, p.max_hp, seconds)
	_set_stat("score", p.score, seconds)
	_set_stat("renown", p.renown, seconds)
	_set_stat("gold", p.gold, seconds)
	var rolled := p.roll_done and view.phase != GameState.Phase.ROLL
	_chip_nodes["combat"].visible = rolled
	_chip_nodes["cunning"].visible = rolled
	if rolled:
		_set_stat("combat", p.combat, 0.0)
		_set_stat("cunning", p.cunning, 0.0)
	_set_oath(p.oath, seconds)
	var oath_args := {"renown": p.renown, "oath": p.oath, "length": Content.OATH_LENGTH}
	if p.oath == Content.OATH_LENGTH - 1:
		_chip_nodes["renown"].tooltip_text = tr("{renown} renown. Oath: {oath} of {length} kept words in a row; the next completes it.").format(oath_args)
	else:
		_chip_nodes["renown"].tooltip_text = tr("{renown} renown. Oath: {oath} of {length} kept words in a row.").format(oath_args)
	_strip_text.text = _strip_for(view, p)


func _set_stat(key: String, value: int, seconds: float) -> void:
	var label := _labels[key]
	var old: int = _values.get(key, value)
	_values[key] = value
	if old == value or seconds <= 0.0:
		label.text = str(value)
		return
	Juice.count(label, old, value, seconds * 0.8, func(v: int) -> void: label.text = str(v))
	Juice.pop(_chip_nodes[key], 0.3, seconds * 0.7)
	Juice.flash(label, GAIN if value > old else LOSS, seconds)


func _set_oath(oath: int, seconds: float) -> void:
	var before := _oath
	_oath = oath
	for i in _pips.size():
		_pips[i].add_theme_stylebox_override("panel", _pip_style(i < oath))
	if before < 0 or seconds <= 0.0 or oath == before:
		return
	if oath > before:
		Juice.pop(_pips[oath - 1], 0.8, seconds)
	else:
		# Emptied: a broken word shivers red; a completed oath glows gold.
		for pip in _pips:
			Juice.flash(pip, LOSS if oath == 0 and before < Content.OATH_LENGTH - 1 else GAIN, seconds)
		Juice.wobble(_chip_nodes["renown"], 6.0, seconds * 0.6)


func _pip_style(on: bool) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.set_corner_radius_all(5)
	box.bg_color = PIP_ON if on else PIP_OFF
	box.set_border_width_all(1)
	box.border_color = PIP_EDGE
	return box


## A soft, slow glow on the card the table is waiting for.
func _set_waiting(waiting: bool) -> void:
	if waiting == (_waiting_tween != null):
		return
	if _waiting_tween:
		_waiting_tween.kill()
		_waiting_tween = null
		self_modulate = Color.WHITE
	if waiting and not Settings.reduced_motion():
		_waiting_tween = create_tween().set_loops()
		_waiting_tween.tween_property(self, "self_modulate", Color(1.18, 1.12, 0.95), 0.7).set_trans(Tween.TRANS_SINE)
		_waiting_tween.tween_property(self, "self_modulate", Color.WHITE, 0.7).set_trans(Tween.TRANS_SINE)


func _strip_for(view: GameState, p: PlayerState) -> String:
	if p.knocked_out:
		return "%s [color=#e8a090]%s[/color]" % [Icons.bb("knockout", 16), Icons.rich(tr("Knocked out, back after turn {turn}").format({"turn": p.out_until_turn}))]
	var dim := DIM.to_html(false)
	if view.phase == GameState.Phase.ROLL:
		var faces := PackedStringArray()
		for face in p.showing_faces():
			faces.append(Icons.rich(Face.label(face), 16))
		return "%s  [color=#%s]%s[/color]" % [" ".join(faces), dim, tr("kept") if p.roll_done else tr("rolling…")]
	if view.plans_public() and p.plan_locked:
		return reveal_line(Loc.rich(view.plan_message(p), 16), p.kept_word)
	if p.declared:
		return says(Loc.rich(view.choice_message(p.intention_action, p.intention_target), 16))
	return "[color=#%s]…[/color]" % dim


## The strip's "Says: ..." line around a choice already in BBCode.
static func says(choice_bbcode: String) -> String:
	return Icons.rich(Loc.t("Says: {choice}")).replace("{choice}", "[b]%s[/b]" % choice_bbcode)


## The strip's "Did: ..." line around a plan already in BBCode.
static func did(plan_bbcode: String) -> String:
	return Icons.rich(Loc.t("Did: {plan}")).replace("{plan}", "[b]%s[/b]" % plan_bbcode)


## The strip after the reveal: what they did, and whether that was what they said.
func reveal_line(plan_bbcode: String, kept: bool) -> String:
	var verdict := "[color=#%s]%s[/color]" % [KEPT.to_html(false), tr("kept word")] if kept else "[color=#%s]%s[/color]" % [_lied_color().to_html(false), tr("lied")]
	return "%s · %s" % [did(plan_bbcode), verdict]


func _draw() -> void:
	if has_focus():
		draw_style_box(get_theme_stylebox("focus", "Button"), Rect2(Vector2.ZERO, size))


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


## A rubber stamp slammed onto the card's top corner ("Word kept", "Liar", "Knocked out").
func stamp(text: String, kind: String, duration: float) -> void:
	clear_stamp()
	var label := Label.new()
	_stamp = label
	label.text = text.to_upper()
	var box := StyleBoxFlat.new()
	box.set_corner_radius_all(4)
	box.set_border_width_all(2)
	box.content_margin_left = 10
	box.content_margin_right = 10
	box.content_margin_top = 1
	box.content_margin_bottom = 1
	match kind:
		"kept":
			box.bg_color = KEPT
			box.border_color = Color("7a5418")
			label.add_theme_color_override("font_color", Color("2a1a0c"))
		_:
			box.bg_color = LIED_CONTRAST.darkened(0.2) if Settings.get_value("gameplay", "high_contrast") else LIED
			box.border_color = Color("f0b48a")
			label.add_theme_color_override("font_color", Color("fff3e4"))
	label.add_theme_stylebox_override("normal", box)
	label.add_theme_font_size_override("font_size", 13)
	label.modulate.a = 0.0
	_overlay.add_child(label)
	# Placed once the frame is laid out; a deferred call (not an await) so a card freed in the
	# meantime leaves nothing waiting.
	_land_stamp.call_deferred(label.get_instance_id(), duration)


func _land_stamp(label_id: int, duration: float) -> void:
	var label := instance_from_id(label_id) as Label
	if label == null or _stamp != label:
		return
	label.reset_size()
	label.position = Vector2(size.x - label.size.x - 14, 8)
	label.pivot_offset = label.size / 2.0
	label.rotation_degrees = -6.0
	Audio.play(&"stamp", -2.0)
	# Tweens owned by the label die with it. The strip keeps saying who kept their word, so the
	# stamp is the moment of the reveal: it slams down, waits, and fades away.
	var tween := label.create_tween()
	if duration > 0.0:
		label.scale = Vector2(2.4, 2.4)
		tween.tween_property(label, "scale", Vector2.ONE, duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(label, "modulate:a", 1.0, duration * 0.5)
	else:
		label.modulate.a = 1.0
	tween.tween_interval(3.0)
	tween.tween_property(label, "modulate:a", 0.0, 0.6)
	tween.tween_callback(func() -> void:
		if _stamp == label:
			clear_stamp())


func clear_stamp() -> void:
	if _stamp:
		_stamp.queue_free()
		_stamp = null


## Text that rises off the card and fades, e.g. "-4" damage or "+1 renown". Several at once
## stack upwards instead of covering each other, and they never cover the stats.
func float_text(text: String, color: Color, duration: float, big: bool = false) -> void:
	if duration <= 0.0 or fx_layer == null:
		return
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("normal_font_size", 30 if big else 22)
	label.add_theme_color_override("default_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("outline_size", 6)
	label.text = Icons.rich(text, 26 if big else 20)
	label.custom_minimum_size = Vector2(200, 0)
	fx_layer.add_child(label)
	var rect := get_global_rect()
	var start := fx_layer.get_global_transform().affine_inverse() * Vector2(rect.position.x + rect.size.x * 0.52, rect.position.y + rect.size.y * 0.15)
	# Low enough that the whole rise stays on the screen, even from the top seat.
	label.position = start + Vector2(randf_range(-8.0, 8.0), -26.0 * _floating)
	label.position.y = maxf(label.position.y, 44.0)
	label.pivot_offset = Vector2(20, 14)
	label.scale = Vector2(0.4, 0.4)
	_floating += 1
	var tween := label.create_tween().set_parallel()
	tween.tween_property(label, "scale", Vector2.ONE, duration * 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "position:y", label.position.y - 40.0, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, duration * 0.4).set_delay(duration * 0.6)
	tween.chain().tween_callback(func() -> void:
		_floating = maxi(0, _floating - 1)
		label.queue_free())


## Takes a blow: the card squashes and tilts away from it (it sits in a container, so it
## must not be moved by position).
func shake(strength: float = 6.0) -> void:
	Juice.punch(self, -1.0, strength / 6.0, 0.4)


func pulse(color: Color) -> void:
	if Settings.reduced_motion():
		return
	var tween := create_tween()
	tween.tween_property(self, "self_modulate", color, 0.12)
	tween.tween_property(self, "self_modulate", Color.WHITE, 0.35)
