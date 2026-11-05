class_name EndOverlay
extends Overlay
## The final count: winner and standings on one side, the story of the game on the other (the
## betrayal of the night, the titles earned, new achievements), and where to go next.

const CONFETTI: Array[Color] = [Color("e9c46a"), Color("e76f51"), Color("2a9d8f"), Color("f4a261"), Color("8ab17d")]
const DIM_INK := "5a4128"

var _title: Label
var _rows: VBoxContainer
var _story: VBoxContainer
var _return: Button
var _crown: TextureRect
var _view_button: Button


func _init() -> void:
	panel_size = Vector2(920, 0)


func _make_panel() -> PanelContainer:
	return Parchment.new()


func _build() -> void:
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 28)
	content.add_child(columns)

	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.1
	left.add_theme_constant_override("separation", 8)
	columns.add_child(left)
	_crown = TextureRect.new()
	_crown.texture = Icons.texture("crown")
	_crown.custom_minimum_size = Vector2(64, 64)
	_crown.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_crown.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	left.add_child(_crown)
	_title = add_label(left, "", &"InkHeading")
	_title.add_theme_font_size_override("font_size", 40)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_label(left, tr("Final score: trophies plus unspent renown."), &"InkDim").horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 6)
	left.add_child(_rows)

	_story = VBoxContainer.new()
	_story.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_story.add_theme_constant_override("separation", 5)
	columns.add_child(_story)

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
	var players: Dictionary = view.recap.get("players", {})
	for i in view.standings.size():
		var p := view.player(view.standings[i])
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var place := add_label(row, "%d." % (i + 1), &"Ink")
		place.custom_minimum_size = Vector2(28, 0)
		row.add_child(SeatStyle.make_seal(p.seat, p.name, 26))
		var text := _rich()
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var stats: Dictionary = players.get(p.id, {})
		var words := tr("Words kept {kept}, broken {broken}").format({"kept": stats.get("kept", 0), "broken": stats.get("broke", 0)})
		# {total} is filled in as the score counts up (names are escaped, so cannot clash with it).
		var line := "[b]%s[/b]   {total}   [color=#%s](%s %d + %s %d)\n[font_size=14]%s[/font_size][/color]" % [Icons.rich(p.name),
			DIM_INK, Icons.bb("score", 16), p.score, Icons.bb("renown", 16), p.renown, words]
		text.text = line.replace("{total}", str(view.final_score(p)))
		row.add_child(text)
		_rows.add_child(row)
		rows.append(row)
		counters.append([text, line, view.final_score(p)])
	_write_story(view)
	_return.visible = Network.is_host()
	if winner.id == me:
		Audio.play(&"coins", 0.0)
	open()
	# Once the panel is laid out; deferred rather than awaited, so nothing waits on a freed node.
	_celebrate.call_deferred(rows, counters)


## The betrayal of the night, who earned which title, and the achievements this game unlocked.
func _write_story(view: GameState) -> void:
	for child in _story.get_children():
		child.queue_free()
	add_label(_story, tr("The night in review"), &"InkHeading").add_theme_font_size_override("font_size", 26)
	var betrayal: Dictionary = view.recap.get("betrayal", {})
	if not betrayal.is_empty():
		var traitor := view.player(betrayal.pid)
		var victim := view.player(betrayal.target)
		var told := _rich()
		told.text = "[b]%s[/b]\n%s" % [tr("The betrayal of the night"), Loc.rich(Loc.msg(
			"Turn {turn}: {player} said “{said}”, then hit {target} for {damage}.", {"turn": betrayal.turn,
			"player": Loc.player(traitor), "said": betrayal.said, "target": Loc.player(victim), "damage": betrayal.damage}), 16, true)]
		_story.add_child(told)
	for award: Dictionary in view.recap.get("awards", []):
		var names := PackedStringArray()
		for pid: int in award.pids:
			names.append("[b]%s[/b]" % Loc.rich(Loc.msg("{player}", {"player": Loc.player(view.player(pid))}), 16, true))
		var line := _rich()
		line.text = "[b]%s:[/b] %s  [color=#%s][font_size=14]%s[/font_size][/color]" % [award_title(award.id), ", ".join(names),
			DIM_INK, award_detail(award.id, award.value)]
		_story.add_child(line)
	var unlocked: Array[StringName] = Achievements.new_this_game
	if not unlocked.is_empty():
		var titles := PackedStringArray()
		for id in unlocked:
			titles.append(AchievementRules.title(id))
		var line := _rich()
		line.text = "[b]%s[/b] %s" % [tr("New achievements:"), Icons.rich(", ".join(titles))]
		_story.add_child(line)


func _rich() -> RichTextLabel:
	var text := RichTextLabel.new()
	text.bbcode_enabled = true
	text.fit_content = true
	text.scroll_active = false
	text.theme_type_variation = &"InkRich"
	return text


## The title's name in the player's language.
func award_title(id: StringName) -> String:
	match id:
		&"traitor":
			return tr("The Traitor")
		&"honest":
			return tr("The Honest One")
		&"backstabber":
			return tr("The Backstabber")
		&"monster_hunter":
			return tr("The Monster Hunter")
		&"dragonslayer":
			return tr("The Dragonslayer")
		&"brawler":
			return tr("The Brawler")
		&"thief":
			return tr("The Thief")
		&"merchant":
			return tr("The Merchant")
		&"punching_bag":
			return tr("The Punching Bag")
	return String(id)


func award_detail(id: StringName, value: int) -> String:
	var text := ""
	match id:
		&"traitor":
			text = tr("Words broken: {value}")
		&"honest":
			text = tr("Words kept: {value}")
		&"backstabber":
			text = tr("Ambush damage: {value}")
		&"monster_hunter":
			text = tr("Mobs slain: {value}")
		&"dragonslayer":
			text = tr("Bosses slain: {value}")
		&"brawler":
			text = tr("Knockouts: {value}")
		&"thief":
			text = tr("Renown stolen: {value}")
		&"merchant":
			text = tr("Purchases: {value}")
		&"punching_bag":
			text = tr("Damage taken: {value}")
	return text.format({"value": value})


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
