class_name PlayerInfoOverlay
extends Overlay
## A player's sheet: resources, every face of every die, and trinkets. Q and E (or the
## shoulder buttons) page through the other players.

var _title: Label
var _body: RichTextLabel
var _view: GameState
var _pid := 0


func _init() -> void:
	panel_size = Vector2(580, 460)


func _make_panel() -> PanelContainer:
	return Parchment.new()


func _build() -> void:
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	content.add_child(header)
	_title = add_label(header, "", &"InkHeading")
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_button(header, "‹", _cycle.bind(-1)).tooltip_text = tr("Previous player (Q)")
	add_button(header, "›", _cycle.bind(1)).tooltip_text = tr("Next player (E)")
	add_button(header, tr("Close"), close)
	_body = RichTextLabel.new()
	_body.bbcode_enabled = true
	_body.theme_type_variation = &"InkRich"
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.focus_mode = Control.FOCUS_NONE
	content.add_child(_body)


func show_player(view: GameState, pid: int) -> void:
	var p := view.player(pid)
	if p == null:
		return
	_view = view
	_pid = pid
	_title.text = p.name
	var lines := PackedStringArray()
	lines.append("%s %d/%d    %s %d    %s %d    %s %d" % [Icons.bb("heal"), p.hp, p.max_hp, Icons.bb("score"), p.score,
		Icons.bb("renown"), p.renown, Icons.bb("gold"), p.gold])
	lines.append(Icons.rich(tr("Oath: {oath} of {length} kept words (a broken word starts it over).").format({
		"oath": p.oath, "length": Content.OATH_LENGTH})))
	lines.append("")
	lines.append("[b]%s[/b]" % Icons.rich(tr("Dice")))
	for i in p.dice.size():
		var faces := PackedStringArray()
		for face in p.dice[i]:
			faces.append(Icons.rich(Face.label(face), 22))
		lines.append("%s   %s" % [Icons.rich(tr("Die {number}:").format({"number": i + 1})), "    ".join(faces)])
	lines.append("")
	lines.append("[b]%s[/b]" % Icons.rich(tr("Trinkets")))
	if p.trinkets.is_empty():
		lines.append("[color=#5a4128]%s[/color]" % Icons.rich(tr("None yet.")))
	for trinket_id in p.trinkets:
		var trinket := Content.trinket(trinket_id)
		if trinket:
			lines.append("%s [b]%s[/b]: %s" % [Icons.bb("trinket"), Icons.rich(trinket.name_text()), Icons.rich(trinket.description_text(), 18)])
	_body.text = "\n".join(lines)
	open()


func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed(&"prev_tab") or event.is_action_pressed(&"next_tab")):
		_cycle(-1 if event.is_action_pressed(&"prev_tab") else 1)
		get_viewport().set_input_as_handled()
		return
	super._unhandled_input(event)


func _cycle(step: int) -> void:
	if _view == null or _view.players.is_empty():
		return
	var index := 0
	for i in _view.players.size():
		if _view.players[i].id == _pid:
			index = i
	var next := _view.players[posmod(index + step, _view.players.size())]
	Audio.play(&"page", -8.0)
	show_player(_view, next.id)
