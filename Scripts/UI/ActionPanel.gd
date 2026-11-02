class_name ActionPanel
extends VBoxContainer
## The controls for whatever the local player has to do right now. The panel is rebuilt only
## when the situation changes for this player, so half-entered choices survive updates
## caused by other players.

const DIM := Color(0.67, 0.69, 0.72)
const ACTIONS: Array[PlayerState.Action] = [
	PlayerState.Action.ATTACK_PLAYER,
	PlayerState.Action.ATTACK_MOB,
	PlayerState.Action.ATTACK_BOSS,
	PlayerState.Action.SHOP,
	PlayerState.Action.REST,
]

var _view: GameState
var _me: PlayerState
var _key := ""
var _waiting_label: Label

# Roll
var _reroll_toggles: Array[Button] = []
var _wild_options: Array[OptionButton] = []
var _roll_preview: Label
var _reroll_button: Button

# Declare / plan
var _action_option: OptionButton
var _target_option: OptionButton
var _target_values: Array[int] = []
var _attack_spin: SpinBox
var _guard_spin: SpinBox
var _sabotage_spins: Dictionary[int, SpinBox] = {}
var _budget_label: Label
var _lock_button: Button

# Shop / bid
var _selected_slot := -1
var _renown_spin: SpinBox
var _bid_gold: SpinBox
var _bid_renown: SpinBox


func render(view: GameState, me_id: int) -> void:
	_view = view
	_me = view.player(me_id)
	var key := _context_key()
	if key != _key:
		_key = key
		_rebuild()
	_update_waiting()


func _context_key() -> String:
	if _me == null:
		return "spectator"
	var parts: Array = [_view.turn, _view.phase, _view.cursor, _view.shopping, _view.is_waiting_on(_me.id), _me.knocked_out]
	match _view.phase:
		GameState.Phase.ROLL:
			parts.append_array([_me.showing, _me.rerolls, _me.roll_done])
		GameState.Phase.PLAN:
			parts.append(_me.plan_locked)
		GameState.Phase.RESOLVE:
			if _view.shopping == _me.id:
				parts.append_array([_me.gold, _me.renown, _me.dice, _view.market, _view.market_die, _selected_slot])
	return var_to_str(parts)


func _rebuild() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_waiting_label = null
	_attack_spin = null
	_guard_spin = null
	_budget_label = null
	_lock_button = null
	_sabotage_spins.clear()
	if _me == null:
		_add_label("You are watching this game.")
		return
	if _view.phase == GameState.Phase.GAME_OVER:
		_add_label("The game is over.")
		return
	if _me.knocked_out:
		_add_label("You are knocked out. You are back after turn %d." % _me.out_until_turn)
		_add_waiting()
		return
	var mine := _view.is_waiting_on(_me.id)
	match _view.phase:
		GameState.Phase.ROLL:
			if mine:
				_build_roll()
				return
			_add_label("Dice kept. Waiting for the others to finish rolling.")
		GameState.Phase.DECLARE:
			if mine:
				_build_declare()
				return
			_add_label("%s is declaring." % _view.player(_view.current_actor()).name)
		GameState.Phase.PLAN:
			if mine:
				_build_plan()
				return
			_add_label("Your plan is locked: %s." % _view.describe_plan(_me))
		GameState.Phase.RESOLVE:
			if mine:
				_build_shop()
				return
			if _view.shopping != 0:
				_add_label("%s is shopping." % _view.player(_view.shopping).name)
			else:
				_add_label("Resolving plans.")
		GameState.Phase.LOOT:
			if mine:
				_build_loot()
				return
			_add_label("Boss loot is being picked.")
		GameState.Phase.BID:
			if mine:
				_build_bid()
				return
			_add_label("Sealed bids are being placed.")
	_add_waiting()


func _update_waiting() -> void:
	if _waiting_label == null:
		return
	var waiting := _view.waiting_on()
	_waiting_label.text = "Waiting for: %s" % _view.names_of(waiting) if not waiting.is_empty() else ""


# --- Roll -------------------------------------------------------------------------

func _build_roll() -> void:
	_add_title("Your roll")
	_add_label("Select dice to reroll, or keep what you have.")
	_reroll_toggles.clear()
	_wild_options.clear()
	var row := HFlowContainer.new()
	add_child(row)
	var faces := _me.showing_faces()
	for i in faces.size():
		var toggle := Button.new()
		toggle.toggle_mode = true
		toggle.custom_minimum_size = Vector2(84, 52)
		toggle.text = "%s\ndie %d" % [Face.label(faces[i]), i + 1]
		toggle.tooltip_text = Face.describe(faces[i])
		toggle.toggled.connect(func(_on: bool) -> void: _update_roll())
		row.add_child(toggle)
		_reroll_toggles.append(toggle)
	for face in faces:
		if Face.kind_of(face) != Face.Kind.WILD:
			continue
		var wild_row := HBoxContainer.new()
		var label := Label.new()
		label.text = "Wild %s counts as" % Face.label(face)
		wild_row.add_child(label)
		var option := OptionButton.new()
		for kind in Face.WILD_CHOICES:
			option.add_item("%s %s" % [Face.icon(kind), Face.NAMES[kind]], kind)
		option.item_selected.connect(func(_index: int) -> void: _update_roll())
		wild_row.add_child(option)
		_wild_options.append(option)
		add_child(wild_row)
	_roll_preview = _add_label("")
	var buttons := HBoxContainer.new()
	add_child(buttons)
	_reroll_button = _add_button(buttons, "Reroll", _on_reroll_pressed)
	_add_button(buttons, "Keep dice", func() -> void: Session.submit(&"finish_roll", [_wild_kinds()]))
	_update_roll()


func _wild_kinds() -> PackedInt32Array:
	var kinds := PackedInt32Array()
	for option in _wild_options:
		kinds.append(option.get_selected_id())
	return kinds


func _update_roll() -> void:
	var totals := _me.roll_totals(_wild_kinds())
	var preview := "Worth: ⚔ %d   💰 %d   🧠 %d" % [totals.combat, totals.gold, totals.cunning]
	for key: String in ["guard", "heal", "renown"]:
		if totals[key] > 0:
			preview += "   %s %d" % [{"guard": "🛡", "heal": "❤", "renown": "⭐"}[key], totals[key]]
	_roll_preview.text = preview
	var selected := _reroll_toggles.filter(func(t: Button) -> bool: return t.button_pressed).size()
	var cost := _me.reroll_cost()
	_reroll_button.text = "Reroll (free)" if cost == 0 else "Reroll (costs %d 🧠)" % cost
	_reroll_button.disabled = selected == 0 or totals.cunning < cost


func _on_reroll_pressed() -> void:
	var dice := PackedInt32Array()
	for i in _reroll_toggles.size():
		if _reroll_toggles[i].button_pressed:
			dice.append(i)
	Session.submit(&"reroll", [dice])


# --- Declare and plan -------------------------------------------------------------

func _build_declare() -> void:
	_add_title("Declare your intention")
	_add_label("Everyone will see it. Keep your word in your secret plan to earn ⭐; break it to surprise them.")
	_build_choice(PlayerState.Action.ATTACK_BOSS, 0)
	var buttons := HBoxContainer.new()
	add_child(buttons)
	_add_button(buttons, "Declare", func() -> void:
		var choice := _choice()
		Session.submit(&"declare", [choice.x, choice.y]))


func _build_plan() -> void:
	_add_title("Your secret plan")
	_add_label("You said: %s. Choose what you will really do." % _view.describe_choice(_me.intention_action, _me.intention_target))
	_build_choice(_me.intention_action, _me.intention_target)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 12)
	add_child(grid)
	_attack_spin = _add_spin(grid, "⚔ Attack", _me.combat)
	_guard_spin = _add_spin(grid, "🛡 Guard", _me.combat)
	_sabotage_spins.clear()
	for p in _view.players:
		if p.id != _me.id and p.is_active():
			_sabotage_spins[p.id] = _add_spin(grid, "Sabotage %s" % p.name, _me.combat)
	_budget_label = _add_label("")
	var buttons := HBoxContainer.new()
	add_child(buttons)
	_lock_button = _add_button(buttons, "Lock plan", _on_lock_pressed)
	_on_choice_changed()


func _build_choice(action: int, target: int) -> void:
	var row := HBoxContainer.new()
	add_child(row)
	_action_option = OptionButton.new()
	for a in ACTIONS:
		_action_option.add_item(PlayerState.ACTION_NAMES[a], a)
	_action_option.select(maxi(ACTIONS.find(action as PlayerState.Action), 0))
	row.add_child(_action_option)
	_target_option = OptionButton.new()
	_target_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_target_option)
	_fill_targets(target)
	_action_option.item_selected.connect(func(_index: int) -> void:
		_fill_targets(0)
		_on_choice_changed())
	_target_option.item_selected.connect(func(_index: int) -> void: _on_choice_changed())


func _fill_targets(preferred: int) -> void:
	_target_option.clear()
	_target_values.clear()
	match _action_option.get_selected_id():
		PlayerState.Action.ATTACK_PLAYER:
			for p in _view.players:
				if p.id != _me.id and p.is_active():
					_target_option.add_item("%s (❤ %d)" % [p.name, p.hp])
					_target_values.append(p.id)
		PlayerState.Action.ATTACK_MOB:
			for i in _view.mobs.size():
				var mob := Content.mob(_view.mobs[i].id)
				if mob:
					_target_option.add_item("%s (❤ %d, hits %d)" % [mob.display_name, mob.hp, mob.damage])
					_target_values.append(i)
		_:
			_target_option.add_item("No target")
			_target_values.append(0)
	_target_option.disabled = _target_values.size() <= 1 and not GameState.needs_target(_action_option.get_selected_id())
	_target_option.select(maxi(_target_values.find(preferred), 0))


func _choice() -> Vector2i:
	var index := _target_option.selected
	return Vector2i(_action_option.get_selected_id(), _target_values[index] if index >= 0 else 0)


func _on_choice_changed() -> void:
	if _attack_spin == null:
		return
	# A sensible default split: everything into the attack when attacking, otherwise guard.
	var attacking := GameState.is_attack(_action_option.get_selected_id())
	var sabotage_total := 0
	for amount: int in _sabotage().values():
		sabotage_total += amount
	var free := maxi(0, _me.combat - sabotage_total)
	_attack_spin.editable = attacking
	_attack_spin.set_value_no_signal(free if attacking else 0)
	_guard_spin.set_value_no_signal(0 if attacking else free)
	_update_budget()


func _sabotage() -> Dictionary:
	var sabotage := {}
	for id in _sabotage_spins:
		var amount := int(_sabotage_spins[id].value)
		if amount > 0:
			sabotage[id] = amount
	return sabotage


func _update_budget() -> void:
	var used := int(_attack_spin.value) + int(_guard_spin.value)
	for amount: int in _sabotage().values():
		used += amount
	var text := "Combat used: %d of %d" % [used, _me.combat]
	if _me.guard_bonus > 0:
		text += "  (plus 🛡 %d from your dice, always guarding)" % _me.guard_bonus
	_budget_label.text = text
	_lock_button.disabled = used > _me.combat


func _on_lock_pressed() -> void:
	var choice := _choice()
	Session.submit(&"lock_plan", [choice.x, choice.y, int(_attack_spin.value), int(_guard_spin.value), _sabotage()])


# --- Shop -------------------------------------------------------------------------

func _build_shop() -> void:
	_add_title("Market")
	_add_label("You have 💰 %d and ⭐ %d. Buy a face, then click the face on your dice it replaces." % [_me.gold, _me.renown])
	var pay_row := HBoxContainer.new()
	add_child(pay_row)
	var pay_label := Label.new()
	pay_label.text = "Pay with ⭐ up to"
	pay_row.add_child(pay_label)
	_renown_spin = SpinBox.new()
	_renown_spin.max_value = _me.renown
	pay_row.add_child(_renown_spin)

	var market := HFlowContainer.new()
	add_child(market)
	for slot in _view.market.size():
		var face := _view.market[slot]
		if face == 0:
			continue
		var price := Content.face_price(face)
		var button := Button.new()
		button.toggle_mode = true
		button.button_pressed = slot == _selected_slot
		button.custom_minimum_size = Vector2(90, 52)
		button.text = "%s\n%d" % [Face.label(face), price]
		button.tooltip_text = Face.describe(face)
		button.disabled = price > _me.gold + _me.renown
		button.pressed.connect(func() -> void:
			_selected_slot = -1 if _selected_slot == slot else slot
			render.call_deferred(_view, _me.id))
		market.add_child(button)

	if _selected_slot >= 0 and _selected_slot < _view.market.size() and _view.market[_selected_slot] != 0:
		_add_label("Replace which face with %s?" % Face.label(_view.market[_selected_slot]))
		for d in _me.dice.size():
			var row := HFlowContainer.new()
			var label := Label.new()
			label.text = "Die %d" % (d + 1)
			label.custom_minimum_size = Vector2(56, 0)
			row.add_child(label)
			for f in _me.dice[d].size():
				var face_button := Button.new()
				face_button.text = Face.label(_me.dice[d][f])
				face_button.custom_minimum_size = Vector2(52, 36)
				face_button.pressed.connect(_buy_face.bind(_selected_slot, d, f))
				row.add_child(face_button)
			add_child(row)

	var buttons := HBoxContainer.new()
	add_child(buttons)
	var die_button := _add_button(buttons, "Buy die (%d)" % Content.DIE_PRICE, func() -> void:
		Session.submit(&"buy_die", [_renown_for(Content.DIE_PRICE)]))
	die_button.disabled = not _view.market_die or Content.DIE_PRICE > _me.gold + _me.renown
	var refresh_button := _add_button(buttons, "Refresh row (%d)" % Content.REFRESH_PRICE, func() -> void:
		_selected_slot = -1
		Session.submit(&"refresh_market", [_renown_for(Content.REFRESH_PRICE)]))
	refresh_button.disabled = Content.REFRESH_PRICE > _me.gold + _me.renown
	_add_button(buttons, "Done shopping", func() -> void:
		_selected_slot = -1
		Session.submit(&"finish_shop", []))


## Renown to spend on a purchase: the chosen amount, but never more than needed and always
## enough to cover what gold cannot.
func _renown_for(price: int) -> int:
	var renown := mini(int(_renown_spin.value), price)
	return clampi(maxi(renown, price - _me.gold), 0, _me.renown)


func _buy_face(slot: int, die: int, face_index: int) -> void:
	_selected_slot = -1
	Session.submit(&"buy_face", [slot, die, face_index, _renown_for(Content.face_price(_view.market[slot]))])


# --- Loot and bids ----------------------------------------------------------------

func _build_loot() -> void:
	_add_title("Boss loot")
	_add_label("Pick one item in secret. If others pick the same item, it goes to a sealed bid.")
	for i in _view.loot.size():
		var trinket := Content.trinket(_view.loot[i])
		var button := Button.new()
		button.text = "%s: %s" % [trinket.display_name, trinket.description]
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.pressed.connect(func() -> void: Session.submit(&"pick_loot", [i]))
		add_child(button)


func _build_bid() -> void:
	var auction := _view.auction_for(_me.id)
	var trinket := Content.trinket(_view.loot[auction.item])
	var rivals: Array[int] = []
	for id: int in auction.bidders:
		if id != _me.id:
			rivals.append(id)
	_add_title("Sealed bid: %s" % trinket.display_name)
	_add_label("%s\nAgainst %s. The highest bid wins and pays; ties go to higher initiative." % [
		trinket.description, _view.names_of(rivals)])
	var grid := GridContainer.new()
	grid.columns = 2
	add_child(grid)
	_bid_gold = _add_spin(grid, "💰 Gold", _me.gold)
	_bid_renown = _add_spin(grid, "⭐ Renown", _me.renown)
	var buttons := HBoxContainer.new()
	add_child(buttons)
	_add_button(buttons, "Place bid", func() -> void:
		Session.submit(&"bid", [int(_bid_gold.value), int(_bid_renown.value)]))


# --- Helpers ----------------------------------------------------------------------

func _add_title(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 22)
	add_child(label)


func _add_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(label)
	return label


func _add_waiting() -> void:
	_waiting_label = _add_label("")
	_waiting_label.add_theme_color_override("font_color", DIM)


func _add_button(parent: Node, text: String, on_pressed: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 38)
	button.pressed.connect(on_pressed)
	parent.add_child(button)
	return button


func _add_spin(grid: GridContainer, text: String, max_value: int) -> SpinBox:
	var label := Label.new()
	label.text = text
	grid.add_child(label)
	var spin := SpinBox.new()
	spin.max_value = max_value
	spin.value_changed.connect(func(_value: float) -> void:
		if _budget_label:
			_update_budget())
	grid.add_child(spin)
	return spin
