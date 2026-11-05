class_name ActionPanel
extends VBoxContainer
## The controls for whatever the local player has to do now, on the parchment card. It is
## rebuilt only when the situation changes for this player, so half-made choices survive
## updates caused by others. Dice are chosen in the 3D tray, market faces in the market.
## With keys or a pad, each rebuild puts the focus on the step's main control.

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
## The control the focus goes to after a rebuild (keys and pad only).
var _primary: Control

# Roll
var _wild_options: Array[OptionButton] = []
var _roll_preview: RichTextLabel
var _reroll_button: Button

# Declare / plan
var _action_option: OptionButton
var _target_option: OptionButton
var _target_values: Array[int] = []
var _attack_step: Stepper
var _guard_step: Stepper
var _budget_label: RichTextLabel
var _lock_button: Button

# Shop / bid
var _renown_step: Stepper
var _bid_gold: Stepper
var _bid_renown: Stepper


func setup(screen: GameScreen) -> void:
	_screen = screen
	screen.add_child.call_deferred(_info)
	screen.tray.selection_changed.connect(func() -> void:
		if _reroll_button:
			_update_roll())


func show_player_info(view: GameState, pid: int) -> void:
	_info.show_player(view, pid)


func info_open() -> bool:
	return _info.visible


## The control a key or pad press should land on when nothing has focus.
func default_focus() -> Control:
	return _primary if is_instance_valid(_primary) and _primary.is_visible_in_tree() else null


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


## Forces a rebuild on the next render (e.g. after reconnecting).
func invalidate() -> void:
	_key = ""


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
	var focused := get_viewport().gui_get_focus_owner()
	var had_focus := focused != null and is_ancestor_of(focused)
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_waiting_label = null
	_reroll_button = null
	_roll_preview = null
	_attack_step = null
	_guard_step = null
	_budget_label = null
	_lock_button = null
	_primary = null
	_screen.tray.selectable = false
	_build_step()
	# Keys and pads follow the step. A focus elsewhere on the table is left alone, unless it
	# was in this panel (and so has just been freed) or on the market face that was just
	# chosen (the next step is choosing the face it replaces).
	focused = get_viewport().gui_get_focus_owner()
	if _primary and (had_focus or focused == null or focused is MarketTile):
		Controls.focus(_primary)


func _build_step() -> void:
	if _me == null:
		_add_text(tr("You are watching this game."))
		return
	if _view.phase == GameState.Phase.GAME_OVER:
		_add_title(tr("The final count"))
		_add_text(tr("The game is over. The results are on the table."))
		return
	if _me.knocked_out:
		_add_title(tr("Knocked out"))
		_add_text(tr("You are back on your feet after turn {turn}. Until then the table plays on without you.").format({"turn": _me.out_until_turn}))
		_add_waiting()
		return
	var mine := _view.is_waiting_on(_me.id)
	match _view.phase:
		GameState.Phase.ROLL:
			if mine:
				_build_roll()
				return
			_add_title(tr("Dice kept"))
			_add_text(tr("Waiting for the others to finish rolling."))
		GameState.Phase.DECLARE:
			if mine:
				_build_declare()
				return
			_add_title(tr("Declarations"))
			if _me.declared:
				_add_rich(Loc.rich(Loc.msg("You said: {choice}. The others are speaking.", {
					"choice": _view.choice_message(_me.intention_action, _me.intention_target)})))
			else:
				_add_text(tr("{player} is declaring. Listen carefully.").format({"player": _view.player(_view.current_actor()).name}))
		GameState.Phase.PLAN:
			if mine:
				_build_plan()
				return
			_add_title(tr("Plan locked"))
			_add_rich(Loc.rich(Loc.msg("Your plan: {plan}.", {"plan": _view.plan_message(_me)})))
		GameState.Phase.RESOLVE:
			if mine:
				_build_shop()
				return
			_add_title(tr("The reveal"))
			if _view.shopping != 0:
				_add_text(tr("{player} is shopping.").format({"player": _view.player(_view.shopping).name}))
			else:
				_add_text(tr("Plans are playing out. Watch the table and the Chronicle."))
		GameState.Phase.LOOT:
			if mine:
				_build_loot()
				return
			_add_title(tr("Spoils"))
			_add_text(tr("The boss slayers pick their spoils, most damage first: {players}.").format({"players": _view.names_of(_view.loot_order)}))
			_add_auction_note()
		GameState.Phase.BID:
			if mine:
				_build_bid()
				return
			_add_title(tr("Sealed bid"))
			_add_text(tr("Your bid is in. Waiting for the others."))
	_add_waiting()


func _update_waiting() -> void:
	if _waiting_label == null:
		return
	var waiting := _view.waiting_on()
	_waiting_label.text = tr("Waiting for {players}.").format({"players": _view.names_of(waiting)}) if not waiting.is_empty() else ""


# --- Roll -------------------------------------------------------------------------

func _build_roll() -> void:
	_add_title(tr("Your roll"))
	_add_text(tr("Choose dice in the tray below to reroll (click them, press 1 to 9, or move onto the tray), or keep what you have."))
	_screen.tray.selectable = true
	_wild_options.clear()
	for face in _me.showing_faces():
		if Face.kind_of(face) != Face.Kind.WILD:
			continue
		var row := HBoxContainer.new()
		row.add_child(_label(tr("Wild face counts as")))
		var option := OptionButton.new()
		for kind in Face.WILD_CHOICES:
			option.add_icon_item(Icons.texture(Icons.for_kind(kind)), Face.kind_name(kind), kind)
		option.item_selected.connect(func(_index: int) -> void: _update_roll())
		row.add_child(option)
		_wild_options.append(option)
		add_child(row)
	_roll_preview = _add_rich("")
	var buttons := _flow()
	_reroll_button = _add_button(buttons, "", _on_reroll_pressed)
	_primary = _add_button(buttons, tr("Keep these dice"), func() -> void: Session.submit(&"finish_roll", [_wild_kinds()]))
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
	_roll_preview.text = "%s   %s" % [Icons.rich(tr("Worth:")), "     ".join(parts)]
	var selected := _screen.tray.selected().size()
	var cost := _me.reroll_cost()
	if cost == 0:
		_reroll_button.text = tr("Reroll {count} (free)").format({"count": selected})
	else:
		_reroll_button.text = tr("Reroll {count} (costs {cost} cunning)").format({"count": selected, "cost": cost})
	_reroll_button.disabled = selected == 0 or totals.cunning < cost


func _on_reroll_pressed() -> void:
	var dice := _screen.tray.selected()
	_screen.tray.clear_selection()
	Session.submit(&"reroll", [dice])


## Number keys toggle dice while rolling.
func toggle_die(index: int) -> void:
	if _reroll_button != null:
		_screen.tray.toggle(index)


## The reroll shortcut: rerolls the chosen dice if that is allowed now.
func reroll_shortcut() -> void:
	if _reroll_button != null and not _reroll_button.disabled:
		_on_reroll_pressed()


# --- Declare and plan -------------------------------------------------------------

func _build_declare() -> void:
	_add_title(tr("Declare your intention"))
	_add_text(tr("Everyone will see it. Keep your word in your secret plan to advance your oath ({oath}/{length}): every {length} kept words earn renown. Break it to surprise them, and your oath starts over.").format({
		"oath": _me.oath, "length": Content.OATH_LENGTH}))
	_build_choice(PlayerState.Action.ATTACK_BOSS, 0)
	var buttons := _flow()
	_add_button(buttons, tr("Declare"), func() -> void:
		var choice := _choice()
		Session.submit(&"declare", [choice.x, choice.y]))


func _build_plan() -> void:
	_add_title(tr("Your secret plan"))
	_add_rich(Loc.rich(Loc.msg("You said: {choice}. Choose what you will really do.", {
		"choice": _view.choice_message(_me.intention_action, _me.intention_target)})))
	_build_choice(_me.intention_action, _me.intention_target)
	var steppers := _flow()
	_attack_step = _add_stepper(steppers, tr("Attack"), "combat", _me.combat)
	_guard_step = _add_stepper(steppers, tr("Guard"), "guard", _me.combat)
	_budget_label = _add_rich("")
	var buttons := _flow()
	_lock_button = _add_button(buttons, tr("Lock plan"), _on_lock_pressed)
	_on_choice_changed()


func _build_choice(action: int, target: int) -> void:
	var row := _row()
	_action_option = OptionButton.new()
	_action_option.custom_minimum_size = Vector2(170, 40)
	for a in ACTIONS:
		_action_option.add_item(PlayerState.action_name(a), a)
	_action_option.select(maxi(ACTIONS.find(action as PlayerState.Action), 0))
	row.add_child(_action_option)
	_target_option = OptionButton.new()
	_target_option.custom_minimum_size = Vector2(0, 40)
	_target_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# A long target ("Swamp Witch (6 health, hits 2)") shortens rather than widening the panel.
	_target_option.fit_to_longest_item = false
	_target_option.clip_text = true
	_target_option.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(_target_option)
	_fill_targets(target)
	_action_option.item_selected.connect(func(_index: int) -> void:
		_fill_targets(0)
		_on_choice_changed())
	_target_option.item_selected.connect(func(_index: int) -> void: _on_choice_changed())
	_primary = _action_option


func _fill_targets(preferred: int) -> void:
	_target_option.clear()
	_target_values.clear()
	match _action_option.get_selected_id():
		PlayerState.Action.ATTACK_PLAYER:
			for p in _view.players:
				if p.id != _me.id and p.is_active():
					_target_option.add_item(tr("{player} ({hp} health)").format({"player": p.name, "hp": p.hp}))
					_target_values.append(p.id)
		PlayerState.Action.ATTACK_MOB:
			for i in _view.mobs.size():
				var mob := Content.mob(_view.mobs[i].id)
				if mob:
					_target_option.add_item(tr("{mob} ({hp} health, hits {damage})").format({"mob": mob.name_text(), "hp": mob.hp, "damage": mob.damage}))
					_target_values.append(i)
		_:
			_target_option.add_item(tr("No target"))
			_target_values.append(0)
	_target_option.disabled = not GameState.needs_target(_action_option.get_selected_id())
	_target_option.focus_mode = Control.FOCUS_NONE if _target_option.disabled else Control.FOCUS_ALL
	_target_option.select(maxi(_target_values.find(preferred), 0))


func _choice() -> Vector2i:
	var index := _target_option.selected
	return Vector2i(_action_option.get_selected_id(), _target_values[index] if index >= 0 else 0)


func _on_choice_changed() -> void:
	if _attack_step == null:
		return
	# A sensible default split: everything into the attack when attacking, otherwise guard.
	var attacking := GameState.is_attack(_action_option.get_selected_id())
	_attack_step.editable = attacking
	_attack_step.focus_mode = Control.FOCUS_ALL if attacking else Control.FOCUS_NONE
	_attack_step.set_value_no_signal(_me.combat if attacking else 0)
	_guard_step.set_value_no_signal(0 if attacking else _me.combat)
	_update_budget()


func _update_budget() -> void:
	var used := _attack_step.value + _guard_step.value
	var text := Icons.rich(tr("{combat} used {used} of {total}").format({"used": used, "total": _me.combat}), 20)
	if _me.guard_bonus > 0:
		text += "   " + Icons.rich(tr("(plus {guard} {amount} always guarding)").format({"amount": _me.guard_bonus}), 20)
	if used > _me.combat:
		text += "   [color=#9b2416]%s[/color]" % Icons.rich(tr("too much"))
	_budget_label.text = text
	_lock_button.disabled = used > _me.combat


func _on_lock_pressed() -> void:
	var choice := _choice()
	var args := [choice.x, choice.y, _attack_step.value, _guard_step.value]
	if not Settings.get_value("gameplay", "confirm_lock"):
		Session.submit(&"lock_plan", args)
		return
	var keeps := choice.x == _me.intention_action and choice.y == _me.intention_target
	var verdict := tr("You keep your word (oath {oath}/{length}).").format({"oath": mini(_me.oath + 1, Content.OATH_LENGTH), "length": Content.OATH_LENGTH})
	if not keeps:
		verdict = tr("You break your word: your oath starts over.")
		if _me.has_effect(&"keeps_oath_when_lying"):
			verdict = tr("You break your word, but your Liar's Mask keeps your oath.")
	_screen.confirm(tr("Lock this plan?"), "%s.\n%s" % [Icons.plain(_view.describe_choice(choice.x, choice.y)), verdict], tr("Lock it"),
		func() -> void: Session.submit(&"lock_plan", args))


# --- Shop -------------------------------------------------------------------------

func _build_shop() -> void:
	_add_title(tr("Your turn at the market"))
	_add_rich(Icons.rich(tr("You have {gold} {amount} and {renown} {renown_amount} (each worth {rate} {gold} when spent).").format({
		"amount": _me.gold, "renown_amount": _me.renown, "rate": Content.RENOWN_GOLD}), 20))
	var pay_row := _row()
	pay_row.add_child(_label(tr("Pay with renown up to")))
	_renown_step = Stepper.new()
	_renown_step.setup(0, _me.renown, 0, &"Ink")
	pay_row.add_child(_renown_step)

	var slot := _screen.market_selection()
	var replacing := slot >= 0 and slot < _view.market.size() and _view.market[slot] != 0
	if replacing:
		_add_rich(Icons.rich(tr("Replace which face with {face}?").format({"face": Face.label(_view.market[slot])}), 22))
	else:
		_add_rich(Icons.rich(tr("Pick a face in the market to buy it, or one of your faces to upgrade it by 1 (it costs the new value).")))
	var first_face: Button = null
	for d in _me.dice.size():
		var row := HFlowContainer.new()
		row.add_theme_constant_override("h_separation", 6)
		var label := _label(tr("Die {number}").format({"number": d + 1}))
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
			button.custom_minimum_size = Vector2(62, 40)
			if replacing:
				button.tooltip_text = Face.describe(face)
				button.pressed.connect(_buy_face.bind(slot, d, f))
			else:
				var price := _me.price(Content.upgrade_price(face))
				button.disabled = price == 0 or price > _me.spending_power()
				if price > 0:
					button.tooltip_text = tr("{face}. Upgrade for {price} gold.").format({"face": Face.describe(face), "price": price})
				else:
					button.tooltip_text = tr("{face}. Cannot be upgraded.").format({"face": Face.describe(face)})
				button.pressed.connect(_upgrade_face.bind(d, f))
			if first_face == null and not button.disabled:
				first_face = button
			row.add_child(button)
		add_child(row)

	var buttons := _flow()
	var die_price := _me.price(Content.DIE_PRICE)
	var die_button := _add_button(buttons, tr("Buy a die ({price})").format({"price": die_price}), func() -> void:
		Session.submit(&"buy_die", [_renown_for(die_price)]))
	die_button.disabled = not _view.market_die or die_price > _me.spending_power()
	var refresh_button := _add_button(buttons, tr("Refresh the row ({price})").format({"price": Content.REFRESH_PRICE}), func() -> void:
		_screen.clear_market_selection()
		Session.submit(&"refresh_market", [_renown_for(Content.REFRESH_PRICE)]))
	refresh_button.disabled = Content.REFRESH_PRICE > _me.spending_power()
	var renown_button := _add_button(buttons, tr("Buy 1 renown ({price} gold)").format({"price": Content.RENOWN_PRICE}), func() -> void:
		Session.submit(&"buy_renown", []))
	renown_button.disabled = _me.gold < Content.RENOWN_PRICE
	var done := _add_button(buttons, tr("Done shopping"), func() -> void:
		_screen.clear_market_selection()
		Session.submit(&"finish_shop", []))
	# Choosing the face to replace comes first; otherwise the market row is where shopping starts.
	_primary = first_face if replacing and first_face else _screen.first_market_tile()
	if _primary == null:
		_primary = done


## Renown to spend on a price: the chosen amount, never more than the price needs, always
## enough to cover what gold cannot.
func _renown_for(price: int) -> int:
	var most := ceili(price / float(Content.RENOWN_GOLD))
	var needed := ceili(maxi(0, price - _me.gold) / float(Content.RENOWN_GOLD))
	return clampi(maxi(mini(_renown_step.value, most), needed), 0, mini(_me.renown, most))


func _buy_face(slot: int, die: int, face_index: int) -> void:
	var price := _me.price(Content.face_price(_view.market[slot]))
	_screen.clear_market_selection()
	Session.submit(&"buy_face", [slot, die, face_index, _renown_for(price)])


func _upgrade_face(die: int, face_index: int) -> void:
	Session.submit(&"upgrade_face", [die, face_index, _renown_for(_me.price(Content.upgrade_price(_me.dice[die][face_index])))])


# --- Loot and bids ----------------------------------------------------------------

func _build_loot() -> void:
	_add_title(tr("Spoils of the hunt"))
	_add_text(tr("You dealt the most damage of those still to choose, so you pick now. Take one item."))
	for i in _view.loot.size():
		var trinket := Content.trinket(_view.loot[i])
		var button := Button.new()
		button.icon = Icons.texture("trinket")
		button.expand_icon = false
		button.add_theme_constant_override("icon_max_width", 28)
		button.text = "%s: %s" % [trinket.name_text(), Icons.plain(trinket.description_text())]
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(0, 48)
		button.pressed.connect(func() -> void: Session.submit(&"pick_loot", [i]))
		add_child(button)
		if _primary == null:
			_primary = button
	_add_auction_note()


func _add_auction_note() -> void:
	var item := Content.trinket(_view.auction_item)
	if item:
		_add_rich(Icons.rich(tr("Then {item} goes to a sealed bid open to everyone.").format({"item": item.name_text()})))


func _build_bid() -> void:
	var trinket := Content.trinket(_view.auction_item)
	_add_title(tr("Sealed bid: {item}").format({"item": trinket.name_text()}))
	_add_rich("%s\n%s" % [Icons.rich(trinket.description_text(), 18), Icons.rich(tr("Everyone bids in secret. The highest bid (at least 1) wins and pays; {renown} counts as {rate} {gold}. Ties go to whoever hurt the boss more.").format({
		"rate": Content.RENOWN_GOLD}), 18)])
	var steppers := _flow()
	_bid_gold = _add_stepper(steppers, tr("Gold"), "gold", _me.gold)
	_bid_renown = _add_stepper(steppers, tr("Renown"), "renown", _me.renown)
	var buttons := _flow()
	_add_button(buttons, tr("Place bid"), func() -> void:
		Session.submit(&"bid", [_bid_gold.value, _bid_renown.value]))
	_add_button(buttons, tr("Pass"), func() -> void:
		Session.submit(&"bid", [0, 0]))
	_primary = _bid_gold


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


## A row that wraps onto further lines when the panel is too narrow for it.
func _flow() -> HFlowContainer:
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 12)
	flow.add_theme_constant_override("v_separation", 8)
	add_child(flow)
	return flow


func _add_button(parent: Node, text: String, on_pressed: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 42)
	button.pressed.connect(on_pressed)
	parent.add_child(button)
	return button


func _add_stepper(parent: HFlowContainer, text: String, icon_name: String, max_value: int) -> Stepper:
	var item := HBoxContainer.new()
	item.add_theme_constant_override("separation", 8)
	parent.add_child(item)
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.theme_type_variation = &"InkRich"
	label.custom_minimum_size = Vector2(96, 0)
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	label.text = "%s %s" % [Icons.bb(icon_name, 20), Icons.rich(text)]
	item.add_child(label)
	var stepper := Stepper.new()
	stepper.setup(0, max_value, 0, &"Ink")
	stepper.value_changed.connect(func(_value: int) -> void:
		if _budget_label:
			_update_budget())
	item.add_child(stepper)
	return stepper
