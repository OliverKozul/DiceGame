class_name GameScreen
extends Control
## The tavern table. Each update from the host is queued; its events are played by the
## Presenter and only then is the new view drawn, so players can follow what happened.
##
## Keys and pads: focus moves over the action panel, the dice tray, the market and the seats.
## Space or X skips animations, 1 to 9 pick dice to reroll, I or Y opens the player sheets,
## F1 or Back the rules, Page Up and Page Down (or the right stick) scroll the Chronicle.

## How strongly the table shakes at most, in pixels, at full trauma.
const SHAKE_PIXELS := 14.0
const EDGE_SHADER := preload("res://Assets/Shaders/edge_pulse.gdshader")
## How fast trauma fades, per second.
const TRAUMA_DECAY := 1.8
## The smallest space the table is laid out in, in canvas units. A fixed size, because the table's
## own minimum height changes with how its text wraps, which would feed back into the fit.
const TABLE_MIN := Vector2(1150, 700)

var shown: GameState
var me := 0
## Full-screen layer above the table for effects: floating text, flying icons, particles.
var fx := Control.new()

var _queue: Array[Array] = []
var _playing := false
var _skip := false
var _speed := 1.0
var _cards: Dictionary[int, SeatCard] = {}
var _presenter: Presenter
var _pause := PauseMenu.new()
var _reconnect := ReconnectOverlay.new()
var _end := EndOverlay.new()
var _confirm := ConfirmOverlay.new()
var _confirm_action := Callable()
var _end_shown := false
var _market_selected := -1
var _tip_id := ""
var _tray_faces: Array[PackedInt32Array] = []
var _tray_showing := PackedInt32Array()
var _dice_rolling := false
var _boss_shown_hp := -1
var _trauma := 0.0
var _boss_bar_view := BossBar.new()
var _mob_rows: Array[MobRow] = []
var _mob_box := VBoxContainer.new()
var _edges: ColorRect
var _shake_origin := Vector2.ZERO
var _shaking := false
## The turn the animations have reached; render() resets it to the view's turn.
var _anim_turn := 0
## The heading's font size from the theme; long titles (some languages) are set smaller.
var _phase_font_size := 0

@onready var margin: Control = %Margin
@onready var boss_card: Control = %BossCard
@onready var mobs_card: Control = %MobsCard
@onready var market_card: Control = $Margin/Columns/Right/MarketCard
@onready var _action_card: Control = $Margin/Columns/Center/ActionCard
@onready var tray: DiceTray = %DiceTray
@onready var _seats: VBoxContainer = %Seats
@onready var _phase_label: Label = %PhaseLabel
@onready var _hint_label: Label = %HintLabel
@onready var _action_panel: ActionPanel = %ActionPanel
@onready var _boss_name: Label = %BossName
@onready var _boss_bar: ProgressBar = %BossBar
@onready var _boss_info: RichTextLabel = %BossInfo
@onready var _mobs_text: RichTextLabel = %MobsText
@onready var _market_tiles: HFlowContainer = %MarketTiles
@onready var _market_note: Label = %MarketNote
@onready var _chronicle: RichTextLabel = %ChronicleText
@onready var _banner: Control = %Banner
@onready var _banner_ribbon: Control = %BannerRibbon
@onready var _banner_label: Label = %BannerLabel
@onready var _tip_note: Control = %TipNote
@onready var _tip_text: RichTextLabel = %TipText
@onready var _toast: Label = %Toast
@onready var _toast_timer: Timer = %ToastTimer


func _ready() -> void:
	fx.set_anchors_preset(Control.PRESET_FULL_RECT)
	fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fx)
	move_child(fx, margin.get_index() + 1)
	resized.connect(_fit_table)
	_fit_table()
	_fade_chronicle_top()
	_phase_font_size = _phase_label.get_theme_font_size("font_size")
	_phase_label.resized.connect(_fit_phase_label)
	_boss_bar.get_parent().add_child(_boss_bar_view)
	_boss_bar.get_parent().move_child(_boss_bar_view, _boss_bar.get_index())
	_boss_bar.hide()
	_mob_box.add_theme_constant_override("separation", 5)
	_mobs_text.get_parent().add_child(_mob_box)
	_mobs_text.hide()
	_presenter = Presenter.new(self)
	add_child(_pause)
	add_child(_end)
	add_child(_confirm)
	add_child(_reconnect)
	Controls.add_default(_default_focus)
	Network.reconnect_changed.connect(_on_reconnect_changed)
	_confirm.confirmed.connect(func() -> void:
		if _confirm_action.is_valid():
			_confirm_action.call())
	Session.update_received.connect(_on_update)
	Session.request_failed.connect(show_toast)
	%MenuButton.pressed.connect(_pause.open)
	%TipOkButton.pressed.connect(_dismiss_tip)
	%TipOffButton.pressed.connect(func() -> void:
		Settings.set_value("gameplay", "tips", false)
		_dismiss_tip())
	_toast_timer.timeout.connect(_toast.hide)
	_action_panel.setup(self)
	if Session.view:
		_on_update(Session.view, [])
	Session.scene_ready()


func _process(delta: float) -> void:
	if not _shaking:
		return
	_trauma = maxf(0.0, _trauma - delta * TRAUMA_DECAY)
	var power := _trauma * _trauma
	margin.position = _shake_origin + Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * SHAKE_PIXELS * power
	if _trauma <= 0.0:
		margin.position = _shake_origin
		_shaking = false


func _exit_tree() -> void:
	Controls.remove_default(_default_focus)


## Keeps the whole table on the screen: when a large interface size (or a small window) leaves
## less room than the table needs, the table is drawn smaller instead of being cut off.
func _fit_table() -> void:
	# Not laid out yet: a resize follows.
	if size.x < 1.0 or size.y < 1.0:
		return
	var fit := minf(1.0, minf(size.x / TABLE_MIN.x, size.y / TABLE_MIN.y))
	margin.scale = Vector2.ONE * fit
	margin.size = size / fit


## Space (or the pad's X) skips the animations that are playing, even while a button has
## the focus; so does a click on the table.
func _input(event: InputEvent) -> void:
	if _playing and event.is_action_pressed(&"skip") and not _overlay_open():
		_skip = true
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if _playing and click and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		_skip = true
		return
	if _overlay_open() or shown == null:
		return
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and key.keycode >= KEY_1 and key.keycode <= KEY_9:
		_action_panel.toggle_die(key.keycode - KEY_1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"players"):
		_action_panel.show_player_info(shown, me if shown.player(me) else shown.players[0].id)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"rules"):
		_pause.open_rules()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"scroll_up", true) or event.is_action_pressed(&"scroll_down", true):
		var bar := _chronicle.get_v_scroll_bar()
		bar.value += bar.page * 0.5 * (-1.0 if event.is_action_pressed(&"scroll_up", true) else 1.0)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel") and _market_selected >= 0:
		clear_market_selection()
		get_viewport().set_input_as_handled()


func _overlay_open() -> bool:
	for overlay: Overlay in [_pause, _end, _confirm, _reconnect]:
		if overlay.visible:
			return true
	return _action_panel.info_open()


## Where a key or pad press lands when nothing has focus: the step's main control, the dice,
## the market, then the menu button.
func _default_focus() -> Control:
	var target := _action_panel.default_focus()
	if target == null and tray.selectable:
		target = tray
	if target == null:
		target = first_market_tile()
	return target if target else %MenuButton


func _on_reconnect_changed() -> void:
	if not Network.reconnecting:
		# Back at the table: draw it afresh when the host's view arrives.
		_action_panel.invalidate()


# --- Queue -----------------------------------------------------------------------

func _on_update(view: GameState, events: Array) -> void:
	_queue.append([view, events])
	if not _playing:
		_drain()


func _drain() -> void:
	_playing = true
	Session.presentation_busy = true
	while not _queue.is_empty():
		var item: Array = _queue.pop_front()
		var view: GameState = item[0]
		me = Session.local_id()
		# Fall behind and the animations speed up; fall far behind and they are skipped.
		_speed = 1.0 if _queue.size() < 2 else (2.5 if _queue.size() < 5 else 0.0)
		if shown == null:
			render(view)
		await _presenter.play(item[1], view)
		if not is_inside_tree():
			return
		render(view)
	_skip = false
	_playing = false
	Session.presentation_finished()


## Called before the table is freed: skips what is left to animate and waits (briefly) for
## the presenter and the dice to finish, so nothing is left awaiting a freed node.
func wind_down() -> void:
	_queue.clear()
	_skip = true
	tray.cancel()
	var deadline := Time.get_ticks_msec() + 2000
	while (_playing or tray.busy) and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame


## True while updates are still being animated (the table is not yet showing the latest view).
func is_animating() -> bool:
	return _playing


## How long an animation should take right now (0 = instantly).
func duration(base: float) -> float:
	if _skip or _speed <= 0.0:
		return 0.0
	return base * Settings.animation_scale() / _speed


# --- Drawing ---------------------------------------------------------------------

func render(view: GameState) -> void:
	shown = view
	_anim_turn = view.turn
	me = Session.local_id()
	_render_header(view)
	_render_seats(view)
	_render_boss(view)
	_render_mobs(view)
	_render_market(view)
	_render_chronicle(view)
	_sync_tray(view)
	_action_panel.render(view, me)
	_action_panel.modulate.a = 1.0
	_update_tip(view)
	if view.phase == GameState.Phase.GAME_OVER and not _end_shown:
		_end_shown = true
		_end.show_results(view, me)


func _render_header(view: GameState) -> void:
	_set_phase_text(tr("Turn {turn} of {turns} · {phase}").format({"turn": view.turn, "turns": view.max_turns, "phase": phase_title(view.phase)}))
	var hint := phase_hint(view.phase)
	var waiting := view.waiting_on()
	if not waiting.is_empty() and view.phase != GameState.Phase.GAME_OVER:
		hint += "  " + tr("Waiting for {players}.").format({"players": view.names_of(waiting)})
	_hint_label.text = hint


func phase_title(phase: GameState.Phase) -> String:
	match phase:
		GameState.Phase.ROLL:
			return tr("The Roll")
		GameState.Phase.DECLARE:
			return tr("Declarations")
		GameState.Phase.PLAN:
			return tr("Secret Plans")
		GameState.Phase.RESOLVE:
			return tr("The Reveal")
		GameState.Phase.LOOT:
			return tr("Spoils")
		GameState.Phase.BID:
			return tr("Sealed Bids")
		GameState.Phase.GAME_OVER:
			return tr("The Final Count")
	return tr("The table is being set")


func phase_hint(phase: GameState.Phase) -> String:
	match phase:
		GameState.Phase.ROLL:
			return tr("Everyone rolls at once. One free reroll, then each costs 1 cunning.")
		GameState.Phase.DECLARE:
			return tr("Intentions are spoken aloud, least cunning first.")
		GameState.Phase.PLAN:
			return tr("Everyone locks a secret plan.")
		GameState.Phase.RESOLVE:
			return tr("Plans play out, most cunning first.")
		GameState.Phase.LOOT:
			return tr("The boss slayers pick their spoils, most damage first.")
		GameState.Phase.BID:
			return tr("Everyone bids in secret for the last spoil.")
		GameState.Phase.GAME_OVER:
			return tr("Trophies plus unspent renown decide the winner.")
	return ""


## Shows the phase the animations have reached, so the header never lags behind the table.
## `turn` 0 keeps the turn the animations are on.
func show_phase(phase: GameState.Phase, turn: int = 0) -> void:
	if turn > 0:
		_anim_turn = turn
	var max_turns := shown.max_turns if shown else Content.MAX_TURNS
	_set_phase_text(tr("Turn {turn} of {turns} · {phase}").format({"turn": _anim_turn, "turns": max_turns, "phase": phase_title(phase)}))
	_hint_label.text = phase_hint(phase)


## Fades the action panel back while the middle of the table is used as a stage; render()
## brings it back.
func focus_stage() -> void:
	if _action_panel.modulate.a < 1.0:
		return
	var tween := _action_panel.create_tween()
	tween.tween_property(_action_panel, "modulate:a", 0.12, duration(0.25))


func _set_phase_text(text: String) -> void:
	if _phase_label.text == text:
		return
	_phase_label.text = text
	_fit_phase_label()
	Juice.pop(_phase_label, 0.06, duration(0.4))


## Shrinks the heading's font until the title fits beside the menu button; the label clips
## rather than widening the column, so a long title never pushes the table off the screen.
func _fit_phase_label() -> void:
	var font := _phase_label.get_theme_font("font")
	var width := _phase_label.size.x
	if font == null or width <= 0.0:
		return
	var font_size := _phase_font_size
	while font_size > 16 and font.get_string_size(_phase_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > width:
		font_size -= 1
	_phase_label.add_theme_font_size_override("font_size", font_size)


func _seat_order(view: GameState) -> Array[int]:
	var order: Array[int] = view.initiative.duplicate()
	for p in view.players:
		if not order.has(p.id):
			order.append(p.id)
	return order


func _render_seats(view: GameState) -> void:
	var order := _seat_order(view)
	var waiting := view.waiting_on()
	for id in order:
		if not _cards.has(id):
			var card := SeatCard.new()
			card.fx_layer = fx
			card.focus_mode = Control.FOCUS_ALL
			card.gui_input.connect(_on_seat_input.bind(id))
			_seats.add_child(card)
			_cards[id] = card
	var before: Dictionary[int, float] = {}
	var reordered := false
	for i in order.size():
		var card := _cards[order[i]]
		before[order[i]] = card.position.y
		if card.get_index() != i:
			reordered = true
			_seats.move_child(card, i)
	var leader := _leader(view)
	for id in order:
		_cards[id].refresh(view, view.player(id), me, waiting.has(id), id == leader, duration(0.7))
	if reordered:
		_slide_seats(before)


## The player with the highest score, if nobody shares it (0 otherwise).
func _leader(view: GameState) -> int:
	var best := 0
	var leader := 0
	for p in view.players:
		var score := view.final_score(p)
		if score > best:
			best = score
			leader = p.id
		elif score == best:
			leader = 0
	return leader


## After the seats change order, each card glides from where it was to its new place.
func _slide_seats(before: Dictionary[int, float]) -> void:
	var seconds := duration(0.35)
	if seconds <= 0.0 or Settings.reduced_motion():
		return
	await get_tree().process_frame
	for id in before:
		var card: SeatCard = _cards.get(id)
		if card == null or absf(card.position.y - before[id]) < 1.0:
			continue
		var target := card.position.y
		card.position.y = before[id]
		card.create_tween().tween_property(card, "position:y", target, seconds).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _render_boss(view: GameState) -> void:
	var boss := view.boss()
	if boss == null:
		return
	_boss_name.text = boss.name_text()
	var wounds: Array[Array] = []
	for id in view.boss_damage:
		var attacker := view.player(id)
		if attacker:
			wounds.append([SeatStyle.color(attacker.seat), view.boss_damage[id]])
	var share := Content.boss_loot_threshold(view.boss_max_hp)
	_boss_bar_view.show_state(view.boss_hp, view.boss_max_hp, wounds, share)
	_boss_shown_hp = view.boss_hp
	var lines := PackedStringArray()
	if view.boss_alive():
		lines.append(Icons.rich(tr("{heal} {hp} of {max}  ·  strikes each attacker for {damage} if it survives. Slayers deal {share}+.").format({
			"hp": view.boss_hp, "max": view.boss_max_hp, "damage": boss.damage, "share": share}), 16))
	else:
		lines.append("[b]%s[/b]" % Icons.rich(tr("Slain this turn.")))
	if not view.boss_damage.is_empty():
		var hits := PackedStringArray()
		for id in view.boss_damage:
			hits.append("%s %d" % [Icons.rich(view.player(id).name), view.boss_damage[id]])
		lines.append("%s %s" % [Icons.rich(tr("Wounded by")), ", ".join(hits)])
	_boss_info.text = "\n".join(lines)


func _render_mobs(view: GameState) -> void:
	while _mob_rows.size() < view.mobs.size():
		var row := MobRow.new()
		_mob_box.add_child(row)
		_mob_rows.append(row)
	for i in _mob_rows.size():
		var mob := Content.mob(view.mobs[i].id) if i < view.mobs.size() else null
		_mob_rows[i].visible = mob != null
		if mob:
			_mob_rows[i].show_mob(mob, view.mobs[i].killed, duration(0.4))


## The row showing the mob in this slot (for effects).
func mob_row(slot: int) -> Control:
	return _mob_rows[slot] if slot >= 0 and slot < _mob_rows.size() else mobs_card


func _render_market(view: GameState) -> void:
	var focused := get_viewport().gui_get_focus_owner()
	var refocus := focused != null and _market_tiles.is_ancestor_of(focused)
	# Removed at once: old tiles waiting to be freed would still take up rows for a frame.
	for child in _market_tiles.get_children():
		_market_tiles.remove_child(child)
		child.queue_free()
	var shopping := view.phase == GameState.Phase.RESOLVE and view.shopping == me
	var p := view.player(me)
	if not shopping:
		_market_selected = -1
	for slot in view.market.size():
		var face := view.market[slot]
		if face == 0:
			continue
		var price := p.price(Content.face_price(face)) if p else Content.face_price(face)
		var tile := MarketTile.new()
		tile.setup(face, price, shopping, p != null and price <= p.spending_power(), slot == _market_selected)
		tile.pressed.connect(_select_market.bind(slot))
		_market_tiles.add_child(tile)
		if refocus and slot == _market_selected:
			Controls.focus(tile)
	if shopping:
		_market_note.text = tr("Your turn to shop: pick a face, then the face it replaces.")
	else:
		_market_note.text = tr("A new die costs {price}. Shoppers buy in initiative order.").format({"price": Content.DIE_PRICE})


## The first market face that can be bought now, for keys and pads (null if none).
func first_market_tile() -> Control:
	for tile in _market_tiles.get_children():
		var button := tile as Button
		if button and not button.is_queued_for_deletion() and button.focus_mode != Control.FOCUS_NONE and not button.disabled:
			return button
	return null


## The Chronicle: the host's log entries in this player's language, with icons and each
## player's name in their seat colour.
func _render_chronicle(view: GameState) -> void:
	var lines := PackedStringArray()
	for entry in view.log_lines:
		var text := Loc.rich(entry, 15, true)
		if str(entry.get("k", "")).begins_with("── Turn"):
			text = "\n[b]%s[/b]" % text
		lines.append(text)
	_chronicle.text = "\n".join(lines)


func _sync_tray(view: GameState) -> void:
	var p := view.player(me)
	if p == null or _dice_rolling:
		return
	if p.dice != _tray_faces or (p.showing != _tray_showing and view.phase == GameState.Phase.ROLL):
		tray.set_dice(p.dice, p.showing)
		_tray_faces = p.dice.duplicate()
		_tray_showing = p.showing


# --- Called by the presenter and the action panel -------------------------------

func seat_card(pid: int) -> SeatCard:
	return _cards.get(pid)


func seat_cards() -> Array[SeatCard]:
	var cards: Array[SeatCard] = []
	cards.assign(_cards.values())
	return cards


func throw_my_dice(indices: PackedInt32Array, view: GameState) -> void:
	var p := view.player(me)
	if p == null:
		return
	_dice_rolling = true
	_tray_faces = p.dice.duplicate()
	_tray_showing = p.showing
	if duration(1.0) <= 0.0:
		tray.set_dice(p.dice, p.showing)
	else:
		await tray.throw(indices, p.dice, p.showing, duration(1.0))
	_dice_rolling = false


## Shows a face you just bought or upgraded: the die turns it to the top in the tray.
func present_my_face(die: int, index: int, face: int) -> void:
	if die < _tray_faces.size() and index < _tray_faces[die].size():
		var faces := _tray_faces[die].duplicate()
		faces[index] = face
		_tray_faces[die] = faces
	if duration(1.0) > 0.0:
		await tray.present_face(die, index, face)


func wait_for_dice() -> void:
	while _dice_rolling:
		if duration(1.0) <= 0.0:
			tray.set_dice(_tray_faces, _tray_showing)
			_dice_rolling = false
			return
		await get_tree().process_frame


func banner(text: String, seconds: float) -> void:
	if seconds <= 0.0:
		return
	_banner_label.text = text
	_banner.show()
	_banner.modulate.a = 0.0
	await get_tree().process_frame
	_banner_ribbon.pivot_offset = _banner_ribbon.size / 2.0
	_banner_ribbon.scale = Vector2(1.25, 1.25)
	Audio.play(&"page", -2.0)
	var tween := create_tween()
	tween.set_parallel()
	tween.tween_property(_banner, "modulate:a", 1.0, seconds * 0.2)
	tween.tween_property(_banner_ribbon, "scale", Vector2.ONE, seconds * 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.chain().tween_interval(seconds * 0.5)
	tween.chain().tween_property(_banner, "modulate:a", 0.0, seconds * 0.25)
	await tween.finished
	_banner.hide()


## A hit on the boss: the wound in the attacker's seat colour, and the ghost drains. Awaitable.
func boss_hit(pid: int, hp: int, damage: int, seconds: float) -> void:
	_boss_shown_hp = hp
	var attacker := shown.player(pid) if shown else null
	var color := SeatStyle.color(attacker.seat) if attacker else Color.WHITE
	_boss_bar_view.hit(hp, color, damage, seconds)
	if seconds > 0.0:
		await get_tree().create_timer(seconds).timeout


## The middle of the table, where reveals play out (on the effects layer).
func stage_center() -> Vector2:
	return Juice.center_in(_action_card, fx)


## A coloured glow creeping in from the screen edges for a moment (ambushes, knockouts).
func pulse_edges(color: Color, strength: float, seconds: float) -> void:
	if seconds <= 0.0 or Settings.reduced_motion():
		return
	if _edges == null:
		_edges = ColorRect.new()
		var edge_material := ShaderMaterial.new()
		edge_material.shader = EDGE_SHADER
		_edges.material = edge_material
		_edges.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_edges.set_anchors_preset(Control.PRESET_FULL_RECT)
		fx.add_child(_edges)
	var paint: ShaderMaterial = _edges.material
	paint.set_shader_parameter("tint", color)
	var tween := _edges.create_tween()
	tween.tween_method(func(v: float) -> void: paint.set_shader_parameter("strength", v), 0.0, strength, seconds * 0.25)
	tween.tween_method(func(v: float) -> void: paint.set_shader_parameter("strength", v), strength, 0.0, seconds * 0.75)


## Shakes the whole table; trauma adds up and fades, and the shake grows with its square.
func add_trauma(amount: float) -> void:
	if Settings.reduced_motion() or duration(1.0) <= 0.0:
		return
	if not _shaking:
		_shake_origin = margin.position
		_shaking = true
	_trauma = minf(1.0, _trauma + amount)


func flash(node: Control) -> void:
	Juice.flash(node, Color(1.4, 1.25, 0.9), duration(0.5))


func market_selection() -> int:
	return _market_selected


func clear_market_selection() -> void:
	_market_selected = -1
	if shown:
		_render_market(shown)


func confirm(title: String, message: String, button: String, action: Callable) -> void:
	_confirm_action = action
	_confirm.ask(title, message, button)


func show_toast(message: String) -> void:
	_toast.text = message
	_toast.show()
	_toast_timer.start()
	Audio.play(&"creak", -6.0)


func _select_market(slot: int) -> void:
	if shown == null or shown.shopping != me:
		return
	_market_selected = -1 if _market_selected == slot else slot
	_render_market.call_deferred(shown)
	_action_panel.render.call_deferred(shown, me)


func _on_seat_input(event: InputEvent, pid: int) -> void:
	var click := event as InputEventMouseButton
	var pressed := click and click.pressed and click.button_index == MOUSE_BUTTON_LEFT
	if (pressed or event.is_action_pressed("ui_accept")) and shown:
		_action_panel.show_player_info(shown, pid)
		_cards[pid].accept_event()


## Fades the chronicle's top edge, so a line scrolled half out of view fades instead of being cut.
func _fade_chronicle_top() -> void:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.1, 1.0])
	gradient.colors = PackedColorArray([Color(1, 1, 1, 0), Color.WHITE, Color.WHITE])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0, 0)
	texture.fill_to = Vector2(0, 1)
	texture.width = 4
	texture.height = 64
	var mask := TextureRect.new()
	mask.texture = texture
	mask.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mask.stretch_mode = TextureRect.STRETCH_SCALE
	mask.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	mask.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var box := _chronicle.get_parent()
	box.add_child(mask)
	box.move_child(mask, _chronicle.get_index())
	_chronicle.reparent(mask, false)
	_chronicle.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


# --- Tips ------------------------------------------------------------------------

func _update_tip(view: GameState) -> void:
	if view.phase == GameState.Phase.GAME_OVER:
		_tip_note.hide()
		return
	var id := _tip_for(view)
	if id.is_empty() or id == _tip_id or not Settings.should_show_tip(id):
		return
	_tip_id = id
	_tip_text.text = Icons.rich(_tip_text_for(id), 18, false)
	_tip_note.show()


func _tip_text_for(id: String) -> String:
	match id:
		"roll":
			return tr("Choose dice in the tray to reroll: click them, press 1 to 9, or move onto the tray with the arrow keys or the pad. The first reroll each turn is free; each further one costs 1 {cunning}, and {cunning} decides who acts first.")
		"declare":
			return tr("Say what you will do. Everyone sees it. Every third word you keep in a row completes an oath worth {renown}; breaking your word catches them out but resets your oath.")
		"plan":
			return tr("Now choose what you really do, and split your {combat} into attack and {guard} guard. A hit on a player with more {renown} than you steals 1 {renown}.")
		"resolve":
			return tr("Plans play out from the most cunning player down. The Chronicle on the right records every hit, theft and broken promise.")
		"shop":
			return tr("Pick a face in the market on the right, then the face on your dice it replaces. Or pick one of your faces to upgrade it. {renown} spends as 3 {gold}.")
		"loot":
			return tr("Slayers pick spoils one at a time, most damage first.")
		"bid":
			return tr("Everyone bids {gold} and {renown} in secret ({renown} counts as 3 {gold}). The highest bid wins and pays.")
	return ""


func _tip_for(view: GameState) -> String:
	var mine := view.is_waiting_on(me)
	match view.phase:
		GameState.Phase.ROLL:
			return "roll" if mine else ""
		GameState.Phase.DECLARE:
			return "declare" if mine else ""
		GameState.Phase.PLAN:
			return "plan" if mine else ""
		GameState.Phase.RESOLVE:
			return "shop" if mine else "resolve"
		GameState.Phase.LOOT:
			return "loot" if mine else ""
		GameState.Phase.BID:
			return "bid" if mine else ""
	return ""


func _dismiss_tip() -> void:
	if not _tip_id.is_empty():
		Settings.mark_tip_seen(_tip_id)
	_tip_note.hide()
