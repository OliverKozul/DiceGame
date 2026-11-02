class_name EndOverlay
extends Overlay
## The final count: winner, standings with every player's score, and where to go next.

var _title: Label
var _rows: VBoxContainer
var _return: Button


func _init() -> void:
	panel_size = Vector2(560, 0)


func _make_panel() -> PanelContainer:
	return Parchment.new()


func _build() -> void:
	var crown := TextureRect.new()
	crown.texture = Icons.texture("crown")
	crown.custom_minimum_size = Vector2(72, 72)
	crown.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	crown.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	content.add_child(crown)
	_title = add_label(content, "", &"InkHeading")
	_title.add_theme_font_size_override("font_size", 44)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_label(content, "Final score: trophies plus unspent renown.", &"InkDim").horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 8)
	content.add_child(_rows)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 10)
	content.add_child(buttons)
	_return = add_button(buttons, "Back to the lobby", Network.return_to_lobby)
	add_button(buttons, "View the table", close)
	add_button(buttons, "Leave", func() -> void: Network.leave())


func show_results(view: GameState, me: int) -> void:
	var winner := view.player(view.standings[0])
	_title.text = "You win!" if winner.id == me else "%s wins!" % winner.name
	for child in _rows.get_children():
		child.queue_free()
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
		text.text = "[b]%s[/b]   %d   [color=#5a4128](%s %d + %s %d)[/color]" % [Icons.rich(p.name), view.final_score(p),
			Icons.bb("score", 16), p.score, Icons.bb("renown", 16), p.renown]
		row.add_child(text)
		_rows.add_child(row)
	_return.visible = Network.is_host()
	if winner.id == me:
		Audio.play(&"coins", 0.0)
	open()
