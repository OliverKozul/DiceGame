class_name GameScreen
extends Control
## The tavern table. Each update from the host is queued; its events are played by the
## Presenter and only then is the new view drawn, so players can follow what happened.

const PHASE_TITLES: Dictionary = {
	GameState.Phase.SETUP: "The table is being set",
	GameState.Phase.ROLL: "The Roll",
	GameState.Phase.DECLARE: "Declarations",
	GameState.Phase.PLAN: "Secret Plans",
	GameState.Phase.RESOLVE: "The Reveal",
	GameState.Phase.LOOT: "Spoils",
	GameState.Phase.BID: "Sealed Bids",
	GameState.Phase.GAME_OVER: "The Final Count",
}
const TIPS: Dictionary = {
	"roll": "Click dice in the tray to choose which to reroll. The first reroll each turn is free; each further one costs 1 {cunning}, and {cunning} decides who acts first.",
	"declare": "Say what you will do. Everyone sees it. Keep your word in your secret plan to earn {renown}, or break it to catch them out.",
	"plan": "Now choose what you really do, and split your {combat} into attack, {guard} guard and {sabotage} sabotage. Sabotage hits a player's attack if they act after you.",
	"resolve": "Plans play out from the most cunning player down. The Chronicle on the right records every hit, theft and broken promise.",
	"shop": "Click a face in the market on the right, then click the face on your dice it should replace.",
	"loot": "Pick one item in secret. If someone else wants it too, you will bid for it.",
	"bid": "Bid {gold} and {renown}. The highest total wins and pays; ties go to the more cunning player.",
}

var shown: GameState
var me := 0

var _queue: Array[Array] = []
var _playing := false
var _skip := false
var _speed := 1.0
var _cards: Dictionary[int, SeatCard] = {}
var _presenter: Presenter
var _pause := PauseMenu.new()
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

@onready var margin: Control = %Margin
@onready var boss_card: Control = %BossCard
@onready var mobs_card: Control = %MobsCard
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
	_presenter = Presenter.new(self)
	add_child(_pause)
	add_child(_end)
	add_child(_confirm)
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


## Space, Enter or a click on the table skips the animations that are playing.
func _unhandled_input(event: InputEvent) -> void:
	if not _playing:
		return
	var click := event as InputEventMouseButton
	if event.is_action_pressed("ui_accept") or (click and click.pressed and click.button_index == MOUSE_BUTTON_LEFT):
		_skip = true


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


## How long an animation should take right now (0 = instantly).
func duration(base: float) -> float:
	if _skip or _speed <= 0.0:
		return 0.0
	return base * Settings.animation_scale() / _speed


# --- Drawing ---------------------------------------------------------------------

func render(view: GameState) -> void:
	shown = view
	me = Session.local_id()
	_render_header(view)
	_render_seats(view)
	_render_boss(view)
	_render_mobs(view)
	_render_market(view)
	_render_chronicle(view)
	_sync_tray(view)
	_action_panel.render(view, me)
	_update_tip(view)
	if view.phase == GameState.Phase.GAME_OVER and not _end_shown:
		_end_shown = true
		_end.show_results(view, me)


func _render_header(view: GameState) -> void:
	_phase_label.text = "Turn %d of %d · %s" % [view.turn, view.max_turns, PHASE_TITLES[view.phase]]
	var hint := ""
	match view.phase:
		GameState.Phase.ROLL:
			hint = "Everyone rolls at once. One free reroll, then each costs 1 cunning."
		GameState.Phase.DECLARE:
			hint = "Intentions are spoken aloud, least cunning first."
		GameState.Phase.PLAN:
			hint = "Everyone locks a secret plan."
		GameState.Phase.RESOLVE:
			hint = "Plans play out, most cunning first."
		GameState.Phase.LOOT:
			hint = "The boss slayers pick their spoils in secret."
		GameState.Phase.BID:
			hint = "Contested spoils go to sealed bids."
		GameState.Phase.GAME_OVER:
			hint = "Trophies plus unspent renown decide the winner."
	var waiting := view.waiting_on()
	if not waiting.is_empty() and view.phase != GameState.Phase.GAME_OVER:
		hint += "  Waiting for %s." % view.names_of(waiting)
	_hint_label.text = hint


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
			card.gui_input.connect(_on_seat_input.bind(id))
			_seats.add_child(card)
			_cards[id] = card
	for i in order.size():
		var card := _cards[order[i]]
		_seats.move_child(card, i)
		card.refresh(view, view.player(order[i]), me, waiting.has(order[i]))


func _render_boss(view: GameState) -> void:
	var boss := view.boss()
	if boss == null:
		return
	_boss_name.text = boss.display_name
	_boss_bar.max_value = view.boss_max_hp
	if _boss_shown_hp != view.boss_hp:
		_boss_bar.value = view.boss_hp
		_boss_shown_hp = view.boss_hp
	var lines := PackedStringArray()
	if view.boss_alive():
		lines.append("%s %d of %d  ·  strikes each attacker for [b]%d[/b] if it survives the turn" % [Icons.bb("heal", 16), view.boss_hp, view.boss_max_hp, boss.damage])
	else:
		lines.append("[b]Slain this turn.[/b]")
	if not view.boss_damage.is_empty():
		var hits := PackedStringArray()
		for id in view.boss_damage:
			hits.append("%s %d" % [Icons.rich(view.player(id).name), view.boss_damage[id]])
		lines.append("Wounded by " + ", ".join(hits))
	_boss_info.text = "\n".join(lines)


func _render_mobs(view: GameState) -> void:
	var lines := PackedStringArray()
	for slot in view.mobs:
		var mob := Content.mob(slot.id)
		if mob == null:
			continue
		var rewards := PackedStringArray()
		for reward in mob.rewards:
			rewards.append(reward.display_name)
		var line := "[b]%s[/b]  %s%d  hits %d\n[color=#cdb48c]%s %s[/color]" % [mob.display_name, Icons.bb("heal", 15), mob.hp, mob.damage, Icons.bb("trinket", 15), " / ".join(rewards)]
		if slot.killed:
			line = "[s]%s[/s]  [color=#8fd18f]slain[/color]" % mob.display_name
		lines.append(line)
	_mobs_text.text = "\n".join(lines)


func _render_market(view: GameState) -> void:
	for child in _market_tiles.get_children():
		child.queue_free()
	var shopping := view.phase == GameState.Phase.RESOLVE and view.shopping == me
	var p := view.player(me)
	if not shopping:
		_market_selected = -1
	for slot in view.market.size():
		var face := view.market[slot]
		if face == 0:
			continue
		var price := Content.face_price(face)
		var tile := Button.new()
		tile.toggle_mode = true
		tile.icon = Icons.texture(Icons.for_kind(Face.kind_of(face)))
		tile.expand_icon = false
		tile.add_theme_constant_override("icon_max_width", 26)
		tile.text = "%s · %dg" % ["x2" if Face.kind_of(face) == Face.Kind.DOUBLE else str(Face.value_of(face)), price]
		tile.tooltip_text = "%s for %d" % [Face.describe(face), price]
		tile.custom_minimum_size = Vector2(92, 40)
		tile.button_pressed = slot == _market_selected
		# Outside your shopping turn the tiles stay readable, they just do not respond.
		tile.disabled = shopping and (p == null or price > p.gold + p.renown)
		if not shopping:
			tile.mouse_filter = Control.MOUSE_FILTER_PASS
			tile.focus_mode = Control.FOCUS_NONE
			tile.toggle_mode = false
		tile.pressed.connect(_select_market.bind(slot))
		_market_tiles.add_child(tile)
	if shopping:
		_market_note.text = "Your turn to shop: pick a face, then the face it replaces."
	else:
		_market_note.text = "A new die costs %d. Shoppers buy in initiative order." % Content.DIE_PRICE


func _render_chronicle(view: GameState) -> void:
	var lines := PackedStringArray()
	for line in view.log_lines:
		lines.append(_chronicle_line(view, line))
	_chronicle.text = "\n".join(lines)


## A log line with icons and each player's name in their seat colour.
func _chronicle_line(view: GameState, line: String) -> String:
	var players: Array[PlayerState] = view.players.duplicate()
	players.sort_custom(func(a: PlayerState, b: PlayerState) -> bool: return a.name.length() > b.name.length())
	var text := line
	for i in players.size():
		text = text.replace(players[i].name, "\u0001%d\u0002" % i)
	text = Icons.rich(text, 15)
	for i in players.size():
		var p := players[i]
		text = text.replace("\u0001%d\u0002" % i, "[color=#%s][b]%s[/b][/color]" % [SeatStyle.color(p.seat).darkened(0.35).to_html(false), Icons.rich(p.name)])
	if line.begins_with("── Turn"):
		text = "\n[b]%s[/b]" % text
	return text


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
		await tray.throw(indices, p.dice, p.showing)
	_dice_rolling = false


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


func animate_boss_hp(hp: int, seconds: float) -> void:
	_boss_shown_hp = hp
	if seconds <= 0.0:
		_boss_bar.value = hp
		return
	var tween := create_tween()
	tween.tween_property(_boss_bar, "value", float(hp), seconds).set_ease(Tween.EASE_OUT)
	await tween.finished


func shake_node(node: Control, strength: float) -> void:
	if Settings.reduced_motion() or duration(1.0) <= 0.0:
		return
	var origin := node.position
	var tween := create_tween()
	for i in 6:
		var offset := Vector2(strength if i % 2 == 0 else -strength, strength * 0.4 if i % 3 == 0 else 0.0)
		tween.tween_property(node, "position", origin + offset * (1.0 - i / 6.0), 0.04)
	tween.tween_property(node, "position", origin, 0.04)


func flash(node: Control) -> void:
	if Settings.reduced_motion() or duration(1.0) <= 0.0:
		return
	var tween := create_tween()
	tween.tween_property(node, "self_modulate", Color(1.4, 1.25, 0.9), 0.1)
	tween.tween_property(node, "self_modulate", Color.WHITE, 0.4)


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
	if click and click.pressed and click.button_index == MOUSE_BUTTON_LEFT and shown:
		_action_panel.show_player_info(shown, pid)


# --- Tips ------------------------------------------------------------------------

func _update_tip(view: GameState) -> void:
	if view.phase == GameState.Phase.GAME_OVER:
		_tip_note.hide()
		return
	var id := _tip_for(view)
	if id.is_empty() or id == _tip_id or not Settings.should_show_tip(id):
		return
	_tip_id = id
	_tip_text.text = Icons.rich(TIPS[id], 18, false)
	_tip_note.show()


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
