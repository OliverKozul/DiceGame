class_name EndOverlay
extends Overlay
## The final count: winner, standings with every player's score, and where to go next.

const CONFETTI: Array[Color] = [Color("e9c46a"), Color("e76f51"), Color("2a9d8f"), Color("f4a261"), Color("8ab17d")]

var _title: Label
var _rows: VBoxContainer
var _return: Button
var _crown: TextureRect
var _view_button: Button


func _init() -> void:
	panel_size = Vector2(560, 0)


func _make_panel() -> PanelContainer:
	return Parchment.new()


func _build() -> void:
	_crown = TextureRect.new()
	_crown.texture = Icons.texture("crown")
	_crown.custom_minimum_size = Vector2(72, 72)
	_crown.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_crown.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	content.add_child(_crown)
	_title = add_label(content, "", &"InkHeading")
	_title.add_theme_font_size_override("font_size", 44)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_label(content, tr("Final score: trophies plus unspent renown."), &"InkDim").horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 8)
	content.add_child(_rows)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 10)
	content.add_child(buttons)
	_return = add_button(buttons, tr("Back to the lobby"), Network.return_to_lobby)
	_view_button = add_button(buttons, tr("View the table"), close)
	add_button(buttons, tr("Leave"), func() -> void: Network.leave())


func show_results(view: GameState, me: int) -> void:
	var winner := view.player(view.standings[0])
	_title.text = tr("You win!") if winner.id == me else tr("{player} wins!").format({"player": winner.name})
	for child in _rows.get_children():
		child.queue_free()
	var rows: Array[Control] = []
	var counters: Array[Array] = []
	for i in view.standings.size():
		var p := view.player(view.standings[i])
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var place := add_label(row, "%d." % (i + 1), &"Ink")
		place.custom_minimum_size = Vector2(28, 0)
		row.add_child(SeatStyle.make_seal(p.seat, p.name, 26))
		var text := RichTextLabel.new()
		text.bbcode_enabled = true
		text.fit_content = true
		text.theme_type_variation = &"InkRich"
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		# {total} is filled in as the score counts up (names are escaped, so cannot clash with it).
		var line := "[b]%s[/b]   {total}   [color=#5a4128](%s %d + %s %d)[/color]" % [Icons.rich(p.name),
			Icons.bb("score", 16), p.score, Icons.bb("renown", 16), p.renown]
		text.text = line.replace("{total}", str(view.final_score(p)))
		row.add_child(text)
		_rows.add_child(row)
		rows.append(row)
		counters.append([text, line, view.final_score(p)])
	_return.visible = Network.is_host()
	if winner.id == me:
		Audio.play(&"coins", 0.0)
	open()
	# Once the panel is laid out; deferred rather than awaited, so nothing waits on a freed node.
	_celebrate.call_deferred(rows, counters)


## The crown drops in, the standings slide in one by one with their scores counting up, and
## confetti bursts over the winner.
func _celebrate(rows: Array[Control], counters: Array[Array]) -> void:
	if not Juice.enabled() or not is_inside_tree():
		return
	_crown.pivot_offset = _crown.size / 2.0
	_crown.scale = Vector2(0.2, 0.2)
	_crown.rotation_degrees = -25.0
	var drop := _crown.create_tween().set_parallel()
	drop.tween_property(_crown, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	drop.tween_property(_crown, "rotation_degrees", 0.0, 0.6).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	var at := get_global_transform().affine_inverse() * _crown.get_global_rect().get_center()
	for color in CONFETTI:
		Juice.burst(self, at, color, 14, 520.0, 1.6, 420.0, 1.2)
	for i in rows.size():
		var row := rows[i]
		row.modulate.a = 0.0
		var tween := row.create_tween()
		tween.tween_interval(0.25 + 0.12 * i)
		tween.tween_property(row, "modulate:a", 1.0, 0.25)
		var text: RichTextLabel = counters[i][0]
		var line: String = counters[i][1]
		var score: int = counters[i][2]
		tween.tween_callback(func() -> void:
			Juice.count(text, 0, score, 0.6, func(v: int) -> void: text.text = line.replace("{total}", str(v))))


func _first_control() -> Control:
	return _return if _return.visible else _view_button
