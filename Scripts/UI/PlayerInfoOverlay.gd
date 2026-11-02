class_name PlayerInfoOverlay
extends Overlay
## A player's sheet: resources, every face of every die, and trinkets.

var _title: Label
var _body: RichTextLabel


func _init() -> void:
	panel_size = Vector2(560, 440)


func _make_panel() -> PanelContainer:
	return Parchment.new()


func _build() -> void:
	var header := HBoxContainer.new()
	content.add_child(header)
	_title = add_label(header, "", &"InkHeading")
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_button(header, "Close", close)
	_body = RichTextLabel.new()
	_body.bbcode_enabled = true
	_body.theme_type_variation = &"InkRich"
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(_body)


func show_player(view: GameState, pid: int) -> void:
	var p := view.player(pid)
	if p == null:
		return
	_title.text = p.name
	var lines := PackedStringArray()
	lines.append("%s %d/%d    %s %d    %s %d    %s %d" % [Icons.bb("heal"), p.hp, p.max_hp, Icons.bb("score"), p.score,
		Icons.bb("renown"), p.renown, Icons.bb("gold"), p.gold])
	lines.append("")
	lines.append("[b]Dice[/b]")
	for i in p.dice.size():
		var faces := PackedStringArray()
		for face in p.dice[i]:
			faces.append(Icons.rich(Face.label(face), 22))
		lines.append("Die %d:   %s" % [i + 1, "    ".join(faces)])
	lines.append("")
	lines.append("[b]Trinkets[/b]")
	if p.trinkets.is_empty():
		lines.append("[color=#5a4128]None yet.[/color]")
	for trinket_id in p.trinkets:
		var trinket := Content.trinket(trinket_id)
		if trinket:
			lines.append("%s [b]%s[/b]: %s" % [Icons.bb("trinket"), trinket.display_name, Icons.rich(trinket.description, 18, false)])
	_body.text = "\n".join(lines)
	open()
