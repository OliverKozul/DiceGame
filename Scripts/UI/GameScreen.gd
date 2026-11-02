extends Control
## The table. Renders the latest view from Session; all input goes through the action panel.

const DIM := "#aab0b8"
const GOOD := "#8fd18f"
const BAD := "#e08a7a"
const HIGHLIGHT := "#ffd27a"

var _view: GameState
var _info_player := 0
var _end_shown := false

@onready var _phase_label: Label = %PhaseLabel
@onready var _hint_label: Label = %HintLabel
@onready var _player_rows: VBoxContainer = %PlayerRows
@onready var _stats_label: RichTextLabel = %StatsLabel
@onready var _enemy_label: RichTextLabel = %EnemyLabel
@onready var _market_label: RichTextLabel = %MarketLabel
@onready var _log_text: RichTextLabel = %LogText
@onready var _action_panel: ActionPanel = %ActionPanel
@onready var _info_popup: Control = %InfoPopup
@onready var _info_title: Label = %InfoTitle
@onready var _info_body: RichTextLabel = %InfoBody
@onready var _end_screen: Control = %EndScreen
@onready var _end_title: Label = %EndTitle
@onready var _end_body: RichTextLabel = %EndBody
@onready var _return_button: Button = %ReturnButton
@onready var _toast: Label = %Toast
@onready var _toast_timer: Timer = %ToastTimer
@onready var _leave_dialog: ConfirmationDialog = %LeaveDialog


func _ready() -> void:
	Session.view_changed.connect(_render)
	Session.request_failed.connect(_show_toast)
	%LeaveButton.pressed.connect(_leave_dialog.popup_centered)
	_leave_dialog.confirmed.connect(func() -> void: Network.leave())
	%InfoCloseButton.pressed.connect(_close_info)
	_return_button.pressed.connect(Network.return_to_lobby)
	%ViewTableButton.pressed.connect(_end_screen.hide)
	%EndLeaveButton.pressed.connect(func() -> void: Network.leave())
	_toast_timer.timeout.connect(_toast.hide)
	if Session.view:
		_render(Session.view)
	Session.scene_ready()


## BBCode-safe text.
static func esc(text: String) -> String:
	return text.replace("[", "[lb]")


func _render(view: GameState) -> void:
	_view = view
	var me := Session.local_id()
	_render_header(view)
	_render_players(view, me)
	_render_stats(view, me)
	_render_enemies(view)
	_render_market(view)
	_log_text.text = "\n".join(view.log_lines)
	_action_panel.render(view, me)
	if _info_player != 0:
		_open_info(_info_player)
	if view.phase == GameState.Phase.GAME_OVER and not _end_shown:
		_end_shown = true
		_show_end(view, me)


func _render_header(view: GameState) -> void:
	_phase_label.text = "Turn %d of %d · %s" % [view.turn, view.max_turns, GameState.PHASE_NAMES[view.phase]]
	var hint := ""
	match view.phase:
		GameState.Phase.ROLL:
			hint = "Reroll any dice once for free; each further reroll costs 1 🧠. Then keep your dice."
		GameState.Phase.DECLARE:
			hint = "Everyone announces an intention, lowest initiative first. Keeping your word earns ⭐."
		GameState.Phase.PLAN:
			hint = "Lock your real plan in secret: action, target and how to split your ⚔."
		GameState.Phase.RESOLVE:
			hint = "Plans resolve automatically, highest initiative first."
		GameState.Phase.LOOT:
			hint = "Boss slayers pick loot in secret. Items picked by several players go to sealed bids."
		GameState.Phase.BID:
			hint = "Sealed bids for contested loot. Pay with 💰 and ⭐."
		GameState.Phase.GAME_OVER:
			hint = "Final score = 🏆 + unspent ⭐."
	var waiting := view.waiting_on()
	if not waiting.is_empty() and view.phase != GameState.Phase.GAME_OVER:
		hint += "  Waiting for: %s." % view.names_of(waiting)
	_hint_label.text = hint


func _seat_order(view: GameState) -> Array[int]:
	var order: Array[int] = view.initiative.duplicate()
	for p in view.players:
		if not order.has(p.id):
			order.append(p.id)
	return order


func _render_players(view: GameState, me: int) -> void:
	for child in _player_rows.get_children():
		child.queue_free()
	var waiting := view.waiting_on()
	for id in _seat_order(view):
		var p := view.player(id)
		var row := HBoxContainer.new()
		var text := RichTextLabel.new()
		text.bbcode_enabled = true
		text.fit_content = true
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.text = _player_text(view, p, me, waiting.has(id))
		row.add_child(text)
		var info := Button.new()
		info.text = "Info"
		info.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		info.pressed.connect(_open_info.bind(id))
		row.add_child(info)
		_player_rows.add_child(row)
		_player_rows.add_child(HSeparator.new())


func _player_text(view: GameState, p: PlayerState, me: int, waiting: bool) -> String:
	var rank := view.initiative.find(p.id)
	var title := "[b]%s%s[/b]" % ["#%d " % (rank + 1) if rank >= 0 else "", esc(p.name)]
	if waiting:
		title = "[color=%s]%s ⏳[/color]" % [HIGHLIGHT, title]
	var tags := PackedStringArray()
	if p.id == me:
		tags.append("you")
	if p.is_bot:
		tags.append("bot" if p.connected else "left, bot plays")
	if not tags.is_empty():
		title += " [color=%s](%s)[/color]" % [DIM, ", ".join(tags)]
	var lines := PackedStringArray([title])
	lines.append("❤ %d/%d   🏆 %d   ⭐ %d   💰 %d" % [p.hp, p.max_hp, p.score, p.renown, p.gold])
	if p.knocked_out:
		lines.append("[color=%s]Knocked out, back after turn %d[/color]" % [BAD, p.out_until_turn])
		return "\n".join(lines)
	if view.phase == GameState.Phase.ROLL:
		var faces := PackedStringArray()
		for face in p.showing_faces():
			faces.append(Face.label(face))
		lines.append("[color=%s]Rolled [%s]%s[/color]" % [DIM, " ".join(faces), " ✔" if p.roll_done else ""])
		return "\n".join(lines)
	lines.append("⚔ %d   🧠 %d%s" % [p.combat, p.cunning, "   🛡 %d" % p.guard_bonus if p.guard_bonus > 0 else ""])
	if p.declared:
		lines.append("Says: %s" % esc(view.describe_choice(p.intention_action, p.intention_target)))
	if view.plans_public() and p.plan_locked:
		var mark := "[color=%s]kept word[/color]" % GOOD if p.kept_word else "[color=%s]lied[/color]" % BAD
		lines.append("Did: %s · %s" % [esc(view.describe_plan(p)), mark])
	elif p.plan_locked:
		lines.append("[color=%s]Plan locked[/color]" % DIM)
	return "\n".join(lines)


func _render_stats(view: GameState, me: int) -> void:
	var p := view.player(me)
	if p == null:
		_stats_label.text = ""
		return
	_stats_label.text = "[b]%s[/b]\n❤ %d/%d   💰 %d   ⭐ %d   🏆 %d\n⚔ %d   🧠 %d   🛡 %d   Dice: %d   Trinkets: %d" % [
		esc(p.name), p.hp, p.max_hp, p.gold, p.renown, p.score, p.combat, p.cunning, p.guard_bonus,
		p.dice.size(), p.trinkets.size()]


func _render_enemies(view: GameState) -> void:
	var lines := PackedStringArray()
	var boss := view.boss()
	if boss:
		var state := "[color=%s]slain[/color]" % GOOD if not view.boss_alive() else "❤ %d/%d" % [view.boss_hp, view.boss_max_hp]
		lines.append("[b]Boss: %s[/b]  %s" % [boss.display_name, state])
		lines.append("[color=%s]Strikes each attacker for %d if it survives the turn.[/color]" % [DIM, boss.damage])
		for id in view.boss_damage:
			lines.append("  %s dealt %d" % [esc(view.player(id).name), view.boss_damage[id]])
	lines.append("[b]Mobs[/b]")
	for slot in view.mobs:
		var mob := Content.mob(slot.id)
		if mob == null:
			continue
		var rewards := PackedStringArray()
		for reward in mob.rewards:
			rewards.append(reward.display_name)
		var line := "%s  ❤ %d · hits %d → %s" % [mob.display_name, mob.hp, mob.damage, " / ".join(rewards)]
		if slot.killed:
			line = "[s]%s[/s] [color=%s]slain[/color]" % [line, GOOD]
		lines.append(line)
	_enemy_label.text = "\n".join(lines)


func _render_market(view: GameState) -> void:
	var lines := PackedStringArray(["[b]Market[/b] [color=%s](replace a face on one of your dice)[/color]" % DIM])
	for face in view.market:
		if face != 0:
			lines.append("%s  for %d · %s" % [Face.label(face), Content.face_price(face), Face.describe(face)])
	lines.append("New die  for %d%s" % [Content.DIE_PRICE, "" if view.market_die else " (sold out)"])
	lines.append("[color=%s]Refresh the row for %d.[/color]" % [DIM, Content.REFRESH_PRICE])
	_market_label.text = "\n".join(lines)


func _open_info(id: int) -> void:
	var p := _view.player(id) if _view else null
	if p == null:
		return
	_info_player = id
	_info_title.text = p.name
	var lines := PackedStringArray()
	lines.append("❤ %d/%d   💰 %d   ⭐ %d   🏆 %d" % [p.hp, p.max_hp, p.gold, p.renown, p.score])
	lines.append("")
	lines.append("[b]Dice[/b]")
	for i in p.dice.size():
		var faces := PackedStringArray()
		for face in p.dice[i]:
			faces.append(Face.label(face))
		lines.append("Die %d:  %s" % [i + 1, "  ".join(faces)])
	lines.append("")
	lines.append("[b]Trinkets[/b]")
	if p.trinkets.is_empty():
		lines.append("[color=%s]None yet.[/color]" % DIM)
	for trinket_id in p.trinkets:
		var trinket := Content.trinket(trinket_id)
		lines.append("%s: [color=%s]%s[/color]" % [trinket.display_name, DIM, trinket.description])
	_info_body.text = "\n".join(lines)
	_info_popup.show()


func _close_info() -> void:
	_info_player = 0
	_info_popup.hide()


func _show_end(view: GameState, me: int) -> void:
	var winner := view.player(view.standings[0])
	_end_title.text = "You win!" if winner.id == me else "%s wins!" % winner.name
	var lines := PackedStringArray()
	for i in view.standings.size():
		var p := view.player(view.standings[i])
		lines.append("%d. %s — %d  [color=%s](🏆 %d + ⭐ %d)[/color]" % [
			i + 1, esc(p.name), view.final_score(p), DIM, p.score, p.renown])
	_end_body.text = "\n".join(lines)
	_return_button.visible = Network.is_host()
	_end_screen.show()


func _show_toast(message: String) -> void:
	_toast.text = message
	_toast.show()
	_toast_timer.start()
