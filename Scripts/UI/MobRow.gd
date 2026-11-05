class_name MobRow
extends PanelContainer
## One mob on the table: a tier badge, its name, and chips for health, damage and the
## trophies it is worth, with its possible trinkets underneath. A slain mob burns away; a new
## one slides in.

const TIER_COLORS: Array[Color] = [Color("5d8a4a"), Color("b7832a"), Color("a33a2a")]
const NUMERALS: Array[String] = ["I", "II", "III"]
const BURN := Color("ff8c3a")

var _badge := Label.new()
var _name := Label.new()
var _chips := RichTextLabel.new()
var _rewards := RichTextLabel.new()
var _burn := ColorRect.new()
var _mob_id := &""
var _slain := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.0, 0.0, 0.0, 0.22)
	box.set_corner_radius_all(6)
	box.content_margin_left = 6
	box.content_margin_right = 8
	box.content_margin_top = 4
	box.content_margin_bottom = 4
	add_theme_stylebox_override("panel", box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	_badge.custom_minimum_size = Vector2(30, 30)
	_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_badge.add_theme_font_size_override("font_size", 13)
	_badge.add_theme_color_override("font_color", Color("fff3e0"))
	row.add_child(_badge)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(column)
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(top)
	_name.add_theme_font_size_override("font_size", 16)
	_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_name)
	for rich in [_chips, _rewards]:
		rich.bbcode_enabled = true
		rich.fit_content = true
		rich.scroll_active = false
		rich.autowrap_mode = TextServer.AUTOWRAP_OFF
		rich.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chips.size_flags_horizontal = Control.SIZE_SHRINK_END
	_chips.add_theme_font_size_override("normal_font_size", 15)
	top.add_child(_chips)
	_rewards.add_theme_font_size_override("normal_font_size", 13)
	# Long reward lists (and longer languages) wrap instead of widening the column.
	_rewards.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_rewards.add_theme_color_override("default_color", Color("cdb48c"))
	column.add_child(_rewards)
	# The burn: a glowing sheet that sweeps across a slain mob. It lives on a plain overlay,
	# because the panel would stretch a direct child over the whole card.
	var overlay := Control.new()
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)
	_burn.color = BURN
	_burn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_burn.modulate.a = 0.0
	overlay.add_child(_burn)


## Shows this mob; `seconds` animates a new mob sliding in (0 = at once).
func show_mob(mob: Mob, slain: bool, seconds: float) -> void:
	var fresh := mob.id != _mob_id
	_mob_id = mob.id
	var badge := StyleBoxFlat.new()
	badge.bg_color = TIER_COLORS[clampi(mob.tier - 1, 0, TIER_COLORS.size() - 1)]
	badge.set_corner_radius_all(15)
	badge.set_border_width_all(2)
	badge.border_color = Color("e9c46a").darkened(0.3)
	_badge.add_theme_stylebox_override("normal", badge)
	_badge.text = NUMERALS[clampi(mob.tier - 1, 0, NUMERALS.size() - 1)]
	_name.text = mob.name_text()
	_chips.text = "%s%d  %s%d  %s+%d" % [Icons.bb("heal", 15), mob.hp, Icons.bb("combat", 15), mob.damage,
		Icons.bb("score", 15), Content.mob_score(mob)]
	var rewards := PackedStringArray()
	for reward in mob.rewards:
		rewards.append(reward.name_text())
	_rewards.text = "%s %s" % [Icons.bb("trinket", 13), " / ".join(rewards)]
	tooltip_text = tr("{mob}: {hp} health, hits back for {damage} if you fail. Worth {score} trophies and one of: {rewards}.").format({
		"mob": mob.name_text(), "hp": mob.hp, "damage": mob.damage, "score": Content.mob_score(mob), "rewards": ", ".join(rewards)})
	_set_slain(slain)
	if fresh and not slain and Juice.enabled(seconds):
		modulate.a = 0.0
		pivot_offset = size / 2.0
		scale = Vector2(0.85, 0.85)
		var tween := create_tween().set_parallel()
		tween.tween_property(self, "modulate:a", 1.0, seconds * 0.6)
		tween.tween_property(self, "scale", Vector2.ONE, seconds).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _set_slain(slain: bool) -> void:
	_slain = slain
	if slain:
		modulate = Color(0.55, 0.5, 0.45, 0.75)
		_name.text = tr("{mob} (slain)").format({"mob": _name.text})
	else:
		modulate = Color.WHITE


## The mob burns away: a glowing sheet sweeps across it and it darkens. Awaitable.
func burn(seconds: float) -> void:
	if not Juice.enabled(seconds):
		_set_slain(true)
		return
	_burn.position = Vector2.ZERO
	_burn.size = Vector2(0.0, size.y)
	_burn.modulate.a = 0.85
	var tween := create_tween()
	tween.tween_property(_burn, "size:x", size.x, seconds * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void: _set_slain(true))
	tween.tween_property(_burn, "modulate:a", 0.0, seconds * 0.5)
	await tween.finished
