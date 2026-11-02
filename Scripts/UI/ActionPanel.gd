class_name ActionPanel
extends VBoxContainer
## The controls for whatever the local player has to do now, on the parchment card. It is
## rebuilt only when the situation changes for this player, so half-made choices survive
## updates caused by others. Dice are chosen in the 3D tray, market faces in the market.

const ACTIONS: Array[PlayerState.Action] = [
	PlayerState.Action.ATTACK_PLAYER,
	PlayerState.Action.ATTACK_MOB,
	PlayerState.Action.ATTACK_BOSS,
	PlayerState.Action.SHOP,
	PlayerState.Action.REST,
]

var _screen: GameScreen
var _view: GameState
var _me: PlayerState
var _key := ""
var _waiting_label: Label
var _info := PlayerInfoOverlay.new()

# Roll
var _wild_options: Array[OptionButton] = []
var _roll_preview: RichTextLabel
var _reroll_button: Button

# Declare / plan
var _action_option: OptionButton
var _target_option: OptionButton
var _target_values: Array[int] = []
var _attack_spin: SpinBox
var _guard_spin: SpinBox
var _sabotage_spins: Dictionary[int, SpinBox] = {}
var _budget_label: RichTextLabel
var _lock_button: Button

# Shop / bid
var _renown_spin: SpinBox
var _bid_gold: SpinBox
var _bid_renown: SpinBox


func setup(screen: GameScreen) -> void:
	_screen = screen
	screen.add_child.call_deferred(_info)
	screen.tray.selection_changed.connect(func() -> void:
		if _reroll_button:
			_update_roll())


func show_player_info(view: GameState, pid: int) -> void:
	_info.show_player(view, pid)


func render(view: GameState, me_id: int) -> void:
	if view == null:
		return
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
				parts.append_array([_me.gold, _me.renown, _me.dice, _view.market, _view.market_die, _screen.market_selection()])
	return var_to_str(parts)


func _rebuild() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_waiting_label = null
	_reroll_button = null
	_roll_preview = null
	_attack_spin = null
	_guard_spin = null
	_budget_label = null
	_lock_button = null
	_sabotage_spins.clear()
	_screen.tray.selectable = false
	if _me == null:
		_add_text("You are watching this game.")
		return
	if _view.phase == GameState.Phase.GAME_OVER:
		_add_title("The final count")
		_add_text("The game is over. The results are on the table.")
		return
	if _me.knocked_out:
		_add_title("Knocked out")
		_add_text("You are back on your feet after turn %d. Until then the table plays on without you." % _me.out_until_turn)
		_add_waiting()
		return
	var mine := _view.is_waiting_on(_me.id)
	match _view.phase:
		GameState.Phase.ROLL:
			if mine:
				_build_roll()
				return
			_add_title("Dice kept")
			_add_text("Waiting for the others to finish rolling.")
		GameState.Phase.DECLARE:
			if mine:
				_build_declare()
				return
			_add_title("Declarations")
			if _me.declared:
				_add_text("You said: %s. The others are speaking." % _view.describe_choice(_me.intention_action, _me.intention_target))
			else:
				_add_text("%s is declaring. Listen carefully." % _view.player(_view.current_actor()).name)
		GameState.Phase.PLAN:
			if mine:
				_build_plan()
				return
			_add_title("Plan locked")
			_add_text("Your plan: %s." % Icons.plain(_view.describe_plan(_me)))
		GameState.Phase.RESOLVE:
			if mine:
				_build_shop()
				return
			_add_title("The reveal")
			if _view.shopping != 0:
				_add_text("%s is shopping." % _view.player(_view.shopping).name)
			else:
				_add_text("Plans are playing out. Watch the table and the Chronicle.")
		GameState.Phase.LOOT:
			if mine:
				_build_loot()
				return
			_add_title("Spoils")
			_add_text("The boss slayers are choosing their loot in secret.")
		GameState.Phase.BID:
			if mine:
				_build_bid()
				return
			_add_title("Sealed bids")
			_add_text("Contested loot is being bid for.")
	_add_waiting()


func _update_waiting() -> void:
	if _waiting_label == null:
		return
	var waiting := _view.waiting_on()
	_waiting_label.text = "Waiting for %s." % _view.names_of(waiting) if not waiting.is_empty() else ""


# --- Roll -------------------------------------------------------------------------

func _build_roll() -> void:
	_add_title("Your roll")
	_add_text("Click dice in the tray below to choose which to reroll, or keep what you have.")
	_screen.tray.selectable = true
	_wild_options.clear()
	for face in _me.showing_faces():
		if Face.kind_of(face) != Face.Kind.WILD:
			continue
		var row := HBoxContainer.new()
		row.add_child(_label("Wild face counts as"))
		var option := OptionButton.new()
		for kind in Face.WILD_CHOICES:
			option.add_icon_item(Icons.texture(Icons.for_kind(kind)), Face.NAMES[kind], kind)
		option.item_selected.connect(func(_index: int) -> void: _update_roll())
		row.add_child(option)
		_wild_options.append(option)
		add_child(row)
	_roll_preview = _add_rich("")
	var buttons := _row()
	_reroll_button = _add_button(buttons, "Reroll", _on_reroll_pressed)
	_add_button(buttons, "Keep these dice", func() -> void: Session.submit(&"finish_roll", [_wild_kinds()]))
	_update_roll()


func _wild_kinds() -> PackedInt32Array:
	var kinds := PackedInt32Array()
	for option in _wild_options:
		kinds.append(option.get_selected_id())
	return kinds


func _update_roll() -> void:
	if _roll_preview == null or _me == null:
		return
	var totals := _me.roll_totals(_wild_kinds())
	var parts := PackedStringArray()
	for key: String in ["combat", "gold", "cunning", "guard", "heal", "renown"]:
		if totals[key] > 0 or key in ["combat", "gold", "cunning"]:
			parts.append("%s [b]%d[/b]" % [Icons.bb(key, 22), totals[key]])
	_roll_preview.text = "Worth:   " + "     ".join(parts)
	var selected := _screen.tray.selected().size()
	var cost := _me.reroll_cost()
	if cost == 0:
		_reroll_button.text = "Reroll %d (free)" % selected
	else:
		_reroll_button.text = "Reroll %d (costs %d cunning)" % [selected, cost]
	_reroll_button.disabled = selected == 0 or totals.cunning < cost


func _on_reroll_pressed() -> void:
	var dice := _screen.tray.selected()
	_screen.tray.clear_selection()
	Session.submit(&"reroll", [dice])


# --- Declare and plan -------------------------------------------------------------

func _build_declare() -> void:
	_add_title("Declare your intention")
	_add_text("Everyone will see it. Keep your word in your secret plan to earn renown; break it to surprise them.")
	_build_choice(PlayerState.Action.ATTACK_BOSS, 0)
	var buttons := _row()
	_add_button(buttons, "Declare", func() -> void:
		var choice := _choice()
		Session.submit(&"declare", [choice.x, choice.y]))


func _build_plan() -> void:
	_add_title("Your secret plan")
	_add_text("You said: %s. Choose what you will really do." % _view.describe_choice(_me.intention_action, _me.intention_target))
	_build_choice(_me.intention_action, _me.intention_target)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 6)
	add_child(grid)
	_attack_spin = _add_spin(grid, "Attack", "combat", _me.combat)
	_guard_spin = _add_spin(grid, "Guard", "guard", _me.combat)
	_sabotage_spins.clear()
	for p in _view.players:
		if p.id != _me.id and p.is_active():
			_sabotage_spins[p.id] = _add_spin(grid, "Sabotage %s" % p.name, "sabotage", _me.combat)
	_budget_label = _add_rich("")
	var buttons := _row()
	_lock_button = _add_button(buttons, "Lock plan", _on_lock_pressed)
	_on_choice_changed()


func _build_choice(action: int, target: int) -> void:
	var row := _row()
	_action_option = OptionButton.new()
	_action_option.custom_minimum_size = Vector2(170, 40)
	for a in ACTIONS:
		_action_option.add_item(PlayerState.ACTION_NAMES[a], a)
	_action_option.select(maxi(ACTIONS.find(action as PlayerState.Action), 0))
	row.add_child(_action_option)
	_target_option = OptionButton.new()
	_target_option.custom_minimum_size = Vector2(0, 40)
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
					_target_option.add_item("%s (%d health)" % [p.name, p.hp])
					_target_values.append(p.id)
		PlayerState.Action.ATTACK_MOB:
			for i in _view.mobs.size():
				var mob := Content.mob(_view.mobs[i].id)
				if mob:
					_target_option.add_item("%s (%d health, hits %d)" % [mob.display_name, mob.hp, mob.damage])
					_target_values.append(i)
		_:
			_target_option.add_item("No target")
			_target_values.append(0)
	_target_option.disabled = not GameState.needs_target(_action_option.get_selected_id())
	_target_option.select(maxi(_target_values.find(preferred), 0))


func _choice() -> Vector2i:
	var index := _target_option.selected
	return Vector2i(_action_option.get_selected_id(), _target_values[index] if index >= 0 else 0)


func _on_choice_changed() -> void:
	if _attack_spin == null:
		return
	# A sensible default split: everything into the attack when attacking, otherwise guard.
	var attacking := GameState.is_attack(_action_option.get_selected_id())
	var free := maxi(0, _me.combat - _sabotage_total())
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


func _sabotage_total() -> int:
	var total := 0
	for amount: int in _sabotage().values():
		total += amount
	return total


func _update_budget() -> void:
	var used := int(_attack_spin.value) + int(_guard_spin.value) + _sabotage_total()
	var text := "%s used [b]%d[/b] of [b]%d[/b]" % [Icons.bb("combat", 20), used, _me.combat]
	if _me.guard_bonus > 0:
		text += "   (plus %s %d from your dice, always guarding)" % [Icons.bb("guard", 20), _me.guard_bonus]
	if used > _me.combat:
		text += "   [color=#9b2416]too much[/color]"
	_budget_label.text = text
	_lock_button.disabled = used > _me.combat


func _on_lock_pressed() -> void:
	var choice := _choice()
	var args := [choice.x, choice.y, int(_attack_spin.value), int(_guard_spin.value), _sabotage()]
	if not Settings.get_value("gameplay", "confirm_lock"):
		Session.submit(&"lock_plan", args)
		return
	var keeps := choice.x == _me.intention_action and choice.y == _me.intention_target
	var verdict := "You keep your word." if keeps else "You break your word: no renown this turn."
	_screen.confirm("Lock this plan?", "%s.\n%s" % [_view.describe_choice(choice.x, choice.y), verdict], "Lock it",
		func() -> void: Session.submit(&"lock_plan", args))


# --- Shop -------------------------------------------------------------------------

func _build_shop() -> void:
	_add_title("Your turn at the market")
	_add_rich("You have %s [b]%d[/b] and %s [b]%d[/b]. Pick a face in the market on the right, then the face on your dice it replaces." % [
		Icons.bb("gold", 20), _me.gold, Icons.bb("renown", 20), _me.renown])
	var pay_row := _row()
	pay_row.add_child(_label("Pay with renown up to"))
	_renown_spin = SpinBox.new()
	_renown_spin.max_value = _me.renown
	pay_row.add_child(_renown_spin)

	var slot := _screen.market_selection()
	if slot >= 0 and slot < _view.market.size() and _view.market[slot] != 0:
		_add_rich("Replace which face with %s?" % Icons.rich(Face.label(_view.market[slot]), 22))
		for d in _me.dice.size():
			var row := HFlowContainer.new()
			row.add_theme_constant_override("h_separation", 6)
			var label := _label("Die %d" % (d + 1))
			label.custom_minimum_size = Vector2(56, 0)
			row.add_child(label)
			for f in _me.dice[d].size():
				var face := _me.dice[d][f]
				var button := Button.new()
				button.icon = Icons.texture(Icons.for_kind(Face.kind_of(face)))
				button.expand_icon = false
				button.add_theme_constant_override("icon_max_width", 24)
				if Face.kind_of(face) == Face.Kind.DOUBLE:
					button.text = "x2"
				elif Face.kind_of(face) != Face.Kind.NONE:
					button.text = str(Face.value_of(face))
				button.tooltip_text = Face.describe(face)
				button.custom_minimum_size = Vector2(62, 40)
				button.pressed.connect(_buy_face.bind(slot, d, f))
				row.add_child(button)
			add_child(row)

	var buttons := _row()
	var die_button := _add_button(buttons, "Buy a die (%d)" % Content.DIE_PRICE, func() -> void:
		Session.submit(&"buy_die", [_renown_for(Content.DIE_PRICE)]))
	die_button.disabled = not _view.market_die or Content.DIE_PRICE > _me.gold + _me.renown
	var refresh_button := _add_button(buttons, "Refresh the row (%d)" % Content.REFRESH_PRICE, func() -> void:
		_screen.clear_market_selection()
		Session.submit(&"refresh_market", [_renown_for(Content.REFRESH_PRICE)]))
	refresh_button.disabled = Content.REFRESH_PRICE > _me.gold + _me.renown
	_add_button(buttons, "Done shopping", func() -> void:
		_screen.clear_market_selection()
		Session.submit(&"finish_shop", []))


## Renown to spend: the chosen amount, never more than needed, always enough to cover what
## gold cannot.
func _renown_for(price: int) -> int:
	var renown := mini(int(_renown_spin.value), price)
	return clampi(maxi(renown, price - _me.gold), 0, _me.renown)


func _buy_face(slot: int, die: int, face_index: int) -> void:
	var price := Content.face_price(_view.market[slot])
	_screen.clear_market_selection()
	Session.submit(&"buy_face", [slot, die, face_index, _renown_for(price)])


# --- Loot and bids ----------------------------------------------------------------

func _build_loot() -> void:
	_add_title("Spoils of the hunt")
	_add_text("Pick one item in secret. If others pick the same item, it goes to a sealed bid.")
	for i in _view.loot.size():
		var trinket := Content.trinket(_view.loot[i])
		var button := Button.new()
		button.icon = Icons.texture("trinket")
		button.expand_icon = false
		button.add_theme_constant_override("icon_max_width", 28)
		button.text = "%s: %s" % [trinket.display_name, Icons.plain(trinket.description)]
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(0, 48)
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
	_add_rich("%s\nAgainst %s. The highest total wins and pays; ties go to the more cunning player." % [
		Icons.rich(trinket.description, 18, false), _view.names_of(rivals)])
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 12)
	add_child(grid)
	_bid_gold = _add_spin(grid, "Gold", "gold", _me.gold)
	_bid_renown = _add_spin(grid, "Renown", "renown", _me.renown)
	var buttons := _row()
	_add_button(buttons, "Place bid", func() -> void:
		Session.submit(&"bid", [int(_bid_gold.value), int(_bid_renown.value)]))


# --- Helpers ----------------------------------------------------------------------

func _add_title(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = &"InkHeading"
	add_child(label)


func _label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = &"Ink"
	return label


func _add_text(text: String) -> Label:
	var label := _label(text)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(label)
	return label


func _add_rich(text: String) -> RichTextLabel:
	var rich := RichTextLabel.new()
	rich.bbcode_enabled = true
	rich.fit_content = true
	rich.scroll_active = false
	rich.theme_type_variation = &"InkRich"
	rich.text = text
	add_child(rich)
	return rich


func _add_waiting() -> void:
	_waiting_label = _add_text("")
	_waiting_label.theme_type_variation = &"InkDim"


func _row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	add_child(row)
	return row


func _add_button(parent: Node, text: String, on_pressed: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 42)
	button.pressed.connect(on_pressed)
	parent.add_child(button)
	return button


func _add_spin(grid: GridContainer, text: String, icon_name: String, max_value: int) -> SpinBox:
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.theme_type_variation = &"InkRich"
	label.custom_minimum_size = Vector2(150, 0)
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	label.text = "%s %s" % [Icons.bb(icon_name, 20), Icons.rich(text)]
	grid.add_child(label)
	var spin := SpinBox.new()
	spin.max_value = max_value
	spin.value_changed.connect(func(_value: float) -> void:
		if _budget_label:
			_update_budget())
	grid.add_child(spin)
	return spin
