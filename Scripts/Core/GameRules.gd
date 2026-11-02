class_name GameRules
extends RefCounted
## Host-only game logic. Requests go through apply(): it validates them, mutates the state
## and then advances the game on its own until it needs someone's input again.
## Every random draw uses `rng`, so a seed reproduces a whole game.

## Requests a player may make: name -> argument types (the player id is implicit).
const OPS: Dictionary = {
	&"reroll": [TYPE_PACKED_INT32_ARRAY],
	&"finish_roll": [TYPE_PACKED_INT32_ARRAY],
	&"declare": [TYPE_INT, TYPE_INT],
	&"lock_plan": [TYPE_INT, TYPE_INT, TYPE_INT, TYPE_INT, TYPE_DICTIONARY],
	&"buy_face": [TYPE_INT, TYPE_INT, TYPE_INT, TYPE_INT],
	&"buy_die": [TYPE_INT],
	&"refresh_market": [TYPE_INT],
	&"finish_shop": [],
	&"pick_loot": [TYPE_INT],
	&"bid": [TYPE_INT, TYPE_INT],
}

const SOURCE_MOB := 0
const SOURCE_BOSS := -1
const EVENT_LIMIT := 400

var state := GameState.new()
var rng := RandomNumberGenerator.new()
## Every log line of the game; the state only keeps the most recent ones for clients.
var history: Array[String] = []
## Structured, public events for clients to animate: {"seq", "type", ...data}.
var events: Array[Dictionary] = []

var _market_deck := PackedInt32Array()
var _market_discard := PackedInt32Array()
var _mob_deck: Array[StringName] = []
var _boss_index := 0
var _loot_picks: Dictionary[int, int] = {}
var _bids: Dictionary[int, Vector2i] = {}
var _event_seq := 0


## roster: [{"id": int, "name": String, "bot": bool}, ...] in seat order.
func setup(roster: Array[Dictionary], seed_value: int, max_turns: int = Content.MAX_TURNS) -> void:
	rng.seed = seed_value
	state = GameState.new()
	history = []
	events = []
	_event_seq = 0
	state.max_turns = max_turns
	for i in roster.size():
		var p := PlayerState.new()
		p.id = roster[i].id
		p.name = roster[i].name
		p.is_bot = roster[i].get("bot", false)
		p.seat = i
		p.dice = Content.starting_dice()
		state.players.append(p)
	state.first_seat = rng.randi_range(0, state.players.size() - 1)

	_market_deck = _shuffled(Content.market_deck())
	_market_discard = PackedInt32Array()
	var market := PackedInt32Array()
	market.resize(Content.MARKET_SIZE)
	market.fill(0)
	state.market = market
	_refill_market()

	_build_mob_deck()
	for i in Content.MOB_SLOTS:
		state.mobs.append({"id": _draw_mob(), "killed": false})
	_boss_index = 0
	_set_boss()

	log_event("The game begins: %d players, %d turns." % [state.players.size(), state.max_turns])
	_start_turn()
	_progress()


## Validates and performs one request. Returns "" on success, otherwise why it was refused.
func apply(pid: int, op: StringName, args: Array) -> String:
	if not OPS.has(op):
		return "Unknown request."
	var types: Array = OPS[op]
	if args.size() != types.size():
		return "Malformed request."
	for i in types.size():
		if typeof(args[i]) != types[i]:
			return "Malformed request."
	if state.player(pid) == null:
		return "You are not in this game."
	if state.phase == GameState.Phase.GAME_OVER:
		return "The game is over."
	var err: String = callv("_op_" + op, [pid] + args)
	if err.is_empty():
		_progress()
	return err


## The request an idle player makes automatically (AFK timeout).
func default_request(pid: int) -> Array:
	var p := state.player(pid)
	match state.phase:
		GameState.Phase.ROLL:
			return [&"finish_roll", [PackedInt32Array()]]
		GameState.Phase.DECLARE:
			return [&"declare", [PlayerState.Action.REST, 0]]
		GameState.Phase.PLAN:
			return [&"lock_plan", [PlayerState.Action.REST, 0, 0, p.combat if p else 0, {}]]
		GameState.Phase.RESOLVE:
			return [&"finish_shop", []]
		GameState.Phase.LOOT:
			return [&"pick_loot", [0]]
		GameState.Phase.BID:
			return [&"bid", [0, 0]]
	return []


func set_bot(pid: int, is_bot: bool, connected: bool) -> void:
	var p := state.player(pid)
	if p:
		p.is_bot = is_bot
		p.connected = connected


func log_event(text: String) -> void:
	history.append(text)
	state.log_lines.append(text)
	if state.log_lines.size() > GameState.LOG_LIMIT:
		state.log_lines.assign(state.log_lines.slice(state.log_lines.size() - GameState.LOG_LIMIT))


## Records something that happened, for clients to animate. Every event is public.
func emit_event(type: StringName, data: Dictionary = {}) -> void:
	_event_seq += 1
	var event := data.duplicate()
	event["seq"] = _event_seq
	event["type"] = type
	events.append(event)
	if events.size() > EVENT_LIMIT:
		events.assign(events.slice(events.size() - EVENT_LIMIT))


func last_event_seq() -> int:
	return _event_seq


func events_since(seq: int) -> Array[Dictionary]:
	var newer: Array[Dictionary] = []
	for event in events:
		if event.seq > seq:
			newer.append(event)
	return newer


# --- Requests ---------------------------------------------------------------

func _op_reroll(pid: int, dice: PackedInt32Array) -> String:
	var p := state.player(pid)
	var err := _check_roller(p)
	if not err.is_empty():
		return err
	if dice.is_empty():
		return "Choose at least one die to reroll."
	var seen := {}
	for i in dice:
		if i < 0 or i >= p.dice.size() or seen.has(i):
			return "Invalid die."
		seen[i] = true
	var cost := p.reroll_cost()
	if cost > 0 and p.roll_totals().cunning < cost:
		return "Rerolling again costs %d {cunning}." % cost
	p.cunning_spent += cost
	p.rerolls += 1
	for i in dice:
		p.showing[i] = rng.randi_range(0, p.dice[i].size() - 1)
	emit_event(&"reroll", {"pid": pid, "dice": dice})
	return ""


func _op_finish_roll(pid: int, wild_kinds: PackedInt32Array) -> String:
	var p := state.player(pid)
	var err := _check_roller(p)
	if not err.is_empty():
		return err
	var totals := p.roll_totals(wild_kinds)
	p.combat = totals.combat
	p.guard_bonus = totals.guard
	p.cunning = totals.cunning
	p.gold += totals.gold
	p.renown += totals.renown
	var healed := p.heal(totals.heal)
	p.roll_done = true
	emit_event(&"kept", {"pid": pid, "combat": totals.combat, "gold": totals.gold, "cunning": totals.cunning, "guard": totals.guard, "healed": healed, "renown": totals.renown})

	var faces := PackedStringArray()
	for face in p.showing_faces():
		faces.append(Face.label(face))
	var gains := "{combat}%d {gold}%d {cunning}%d" % [totals.combat, totals.gold, totals.cunning]
	if totals.guard > 0:
		gains += " {guard}%d" % totals.guard
	if healed > 0:
		gains += " {heal}+%d" % healed
	if totals.renown > 0:
		gains += " {renown}+%d" % totals.renown
	log_event("%s rolls [%s]: %s." % [p.name, " ".join(faces), gains])
	return ""


func _op_declare(pid: int, action: int, target: int) -> String:
	if state.phase != GameState.Phase.DECLARE:
		return "It is not time to declare."
	if state.current_actor() != pid:
		return "It is not your turn to declare."
	var err := _check_choice(pid, action, target)
	if not err.is_empty():
		return err
	var p := state.player(pid)
	p.declared = true
	p.intention_action = action as PlayerState.Action
	p.intention_target = target
	state.cursor += 1
	emit_event(&"declare", {"pid": pid, "action": action, "target": target})
	log_event("%s declares: %s." % [p.name, state.describe_choice(action, target)])
	return ""


func _op_lock_plan(pid: int, action: int, target: int, attack: int, guard: int, sabotage: Dictionary) -> String:
	if state.phase != GameState.Phase.PLAN:
		return "It is not time to plan."
	var p := state.player(pid)
	if not p.is_active():
		return "You are knocked out this turn."
	if p.plan_locked:
		return "Your plan is already locked."
	var err := _check_choice(pid, action, target)
	if not err.is_empty():
		return err
	if attack < 0 or guard < 0:
		return "Combat amounts cannot be negative."
	if attack > 0 and not GameState.is_attack(action):
		return "Only attacks use attack combat."
	var total := attack + guard
	var clean: Dictionary[int, int] = {}
	for key: Variant in sabotage:
		var amount: Variant = sabotage[key]
		if typeof(key) != TYPE_INT or typeof(amount) != TYPE_INT or amount < 0:
			return "Malformed sabotage."
		if amount == 0:
			continue
		var t := state.player(key)
		if t == null or t.id == pid or not t.is_active():
			return "You can only sabotage players who are in the game."
		clean[key] = amount
		total += amount
	if total > p.combat:
		return "You only have %d {combat} to split." % p.combat
	p.plan_action = action as PlayerState.Action
	p.plan_target = target
	p.plan_attack = attack
	p.plan_guard = guard
	p.plan_sabotage = clean
	p.plan_locked = true
	emit_event(&"locked", {"pid": pid})
	return ""


func _op_buy_face(pid: int, slot: int, die: int, face_index: int, renown: int) -> String:
	var p := state.player(pid)
	var err := _check_shopper(pid)
	if not err.is_empty():
		return err
	if slot < 0 or slot >= state.market.size() or state.market[slot] == 0:
		return "That market slot is empty."
	if die < 0 or die >= p.dice.size() or face_index < 0 or face_index >= p.dice[die].size():
		return "Choose one of your faces to replace."
	var face := state.market[slot]
	var price := Content.face_price(face)
	err = _pay(p, price, renown)
	if not err.is_empty():
		return err
	var faces := p.dice[die]
	var old := faces[face_index]
	faces[face_index] = face
	p.dice[die] = faces
	state.market[slot] = 0
	emit_event(&"buy_face", {"pid": pid, "face": face, "die": die, "index": face_index, "old": old})
	log_event("%s buys %s for %d and replaces %s on die %d." % [p.name, Face.label(face), price, Face.label(old), die + 1])
	return ""


func _op_buy_die(pid: int, renown: int) -> String:
	var p := state.player(pid)
	var err := _check_shopper(pid)
	if not err.is_empty():
		return err
	if not state.market_die:
		return "The market's die is sold out this turn."
	err = _pay(p, Content.DIE_PRICE, renown)
	if not err.is_empty():
		return err
	p.add_die(Content.basic_die())
	state.market_die = false
	emit_event(&"buy_die", {"pid": pid})
	log_event("%s buys a new die." % p.name)
	return ""


func _op_refresh_market(pid: int, renown: int) -> String:
	var p := state.player(pid)
	var err := _check_shopper(pid)
	if not err.is_empty():
		return err
	err = _pay(p, Content.REFRESH_PRICE, renown)
	if not err.is_empty():
		return err
	for i in state.market.size():
		if state.market[i] != 0:
			_market_discard.append(state.market[i])
			state.market[i] = 0
	_refill_market()
	emit_event(&"refresh", {"pid": pid})
	log_event("%s refreshes the market." % p.name)
	return ""


func _op_finish_shop(pid: int) -> String:
	var err := _check_shopper(pid)
	if not err.is_empty():
		return err
	state.player(pid).resolved = true
	emit_event(&"shop_done", {"pid": pid})
	state.shopping = 0
	state.cursor += 1
	return ""


func _op_pick_loot(pid: int, item: int) -> String:
	if state.phase != GameState.Phase.LOOT or not state.loot_waiting.has(pid):
		return "You have no loot to pick."
	if item < 0 or item >= state.loot.size():
		return "Choose one of the items."
	_loot_picks[pid] = item
	state.loot_waiting.erase(pid)
	return ""


func _op_bid(pid: int, gold: int, renown: int) -> String:
	if state.phase != GameState.Phase.BID or not state.bid_waiting.has(pid):
		return "You are not bidding."
	var p := state.player(pid)
	if gold < 0 or renown < 0 or gold > p.gold or renown > p.renown:
		return "You cannot bid more than you have."
	_bids[pid] = Vector2i(gold, renown)
	state.bid_waiting.erase(pid)
	return ""


func _check_roller(p: PlayerState) -> String:
	if state.phase != GameState.Phase.ROLL:
		return "It is not time to roll."
	if not p.is_active():
		return "You are knocked out this turn."
	if p.roll_done:
		return "You already kept your dice."
	return ""


func _check_shopper(pid: int) -> String:
	if state.phase != GameState.Phase.RESOLVE or state.shopping != pid:
		return "You are not shopping right now."
	return ""


func _check_choice(pid: int, action: int, target: int) -> String:
	match action:
		PlayerState.Action.ATTACK_PLAYER:
			var t := state.player(target)
			if t == null or t.id == pid or not t.is_active():
				return "Choose a player who is in the game."
		PlayerState.Action.ATTACK_MOB:
			if target < 0 or target >= state.mobs.size() or state.mobs[target].id == &"":
				return "Choose one of the mobs."
		PlayerState.Action.ATTACK_BOSS, PlayerState.Action.SHOP, PlayerState.Action.REST:
			if target != 0:
				return "That action has no target."
		_:
			return "Choose an action."
	return ""


func _pay(p: PlayerState, price: int, renown: int) -> String:
	if renown < 0 or renown > mini(price, p.renown):
		return "You cannot pay that much renown."
	if price - renown > p.gold:
		return "You cannot afford that."
	p.renown -= renown
	p.gold -= price - renown
	return ""


# --- Flow ---------------------------------------------------------------------

## Advances through every step that needs no input. Each branch either returns (waiting
## for someone) or moves to a later phase, so the loop always terminates.
func _progress() -> void:
	while true:
		match state.phase:
			GameState.Phase.ROLL:
				if not state.waiting_on().is_empty():
					return
				_begin_declare()
			GameState.Phase.DECLARE:
				if state.cursor < state.initiative.size():
					return
				state.phase = GameState.Phase.PLAN
			GameState.Phase.PLAN:
				if not state.waiting_on().is_empty():
					return
				_reveal()
			GameState.Phase.RESOLVE:
				if not _run_resolution():
					return
				_end_of_turn()
			GameState.Phase.LOOT:
				if not state.loot_waiting.is_empty():
					return
				_settle_loot()
			GameState.Phase.BID:
				if not state.bid_waiting.is_empty():
					return
				_settle_bids()
			_:
				return


func _start_turn() -> void:
	state.turn += 1
	state.cursor = 0
	state.initiative = []
	state.shopping = 0
	state.boss_hp = state.boss_max_hp
	state.boss_damage = {}
	for p in state.players:
		p.reset_for_turn()
		if p.is_active():
			for i in p.dice.size():
				p.showing[i] = rng.randi_range(0, p.dice[i].size() - 1)
	state.phase = GameState.Phase.ROLL
	emit_event(&"turn_start", {"turn": state.turn})
	log_event("── Turn %d of %d ──" % [state.turn, state.max_turns])


func _begin_declare() -> void:
	var seats := state.players.size()
	var ids := state.active_ids()
	ids.sort_custom(func(a: int, b: int) -> bool:
		var pa := state.player(a)
		var pb := state.player(b)
		if pa.cunning != pb.cunning:
			return pa.cunning > pb.cunning
		if pa.gold != pb.gold:
			return pa.gold < pb.gold
		return posmod(pa.seat - state.first_seat, seats) < posmod(pb.seat - state.first_seat, seats))
	state.initiative = ids
	state.cursor = 0
	state.phase = GameState.Phase.DECLARE
	emit_event(&"initiative", {"order": ids.duplicate()})
	var order := PackedStringArray()
	for id in ids:
		order.append("%s {cunning}%d" % [state.player(id).name, state.player(id).cunning])
	log_event("Initiative: %s." % ", ".join(order))


func _reveal() -> void:
	for id in state.initiative:
		var p := state.player(id)
		p.kept_word = p.declared and p.plan_action == p.intention_action and p.plan_target == p.intention_target
		p.attack_left = p.plan_attack
		p.guard_left = p.plan_guard + p.guard_bonus
		var text := "%s reveals: %s" % [p.name, state.describe_plan(p)]
		var gained := 0
		if p.kept_word:
			var bonus := Content.HONESTY_RENOWN
			for trinket_id in p.trinkets:
				bonus += Content.trinket(trinket_id).honesty_bonus()
			p.renown += bonus
			gained = bonus
			text += " — kept their word (+%d {renown})." % bonus
		else:
			text += " — broke their word."
		log_event(text)
		emit_event(&"reveal", {"pid": id, "kept": p.kept_word, "renown": gained})
	state.phase = GameState.Phase.RESOLVE
	state.cursor = 0


## Resolves players in initiative order. Returns false while waiting on a shopper.
func _run_resolution() -> bool:
	while state.cursor < state.initiative.size():
		var p := state.player(state.initiative[state.cursor])
		if state.shopping == p.id:
			return false
		if p.resolved:
			state.cursor += 1
			continue
		if not p.is_active():
			emit_event(&"lost", {"pid": p.id})
			log_event("%s is down; their action is lost." % p.name)
			p.resolved = true
			state.cursor += 1
			continue
		_resolve_sabotage(p)
		if p.plan_action == PlayerState.Action.SHOP:
			state.shopping = p.id
			emit_event(&"shop", {"pid": p.id})
			log_event("%s goes shopping." % p.name)
			return false
		_resolve_action(p)
		p.resolved = true
		state.cursor += 1
	return true


func _resolve_sabotage(p: PlayerState) -> void:
	var bonus := 0
	for trinket_id in p.trinkets:
		bonus += Content.trinket(trinket_id).sabotage_bonus()
	for target_id in p.plan_sabotage:
		var t := state.player(target_id)
		if not t.is_active():
			log_event("%s's sabotage on %s fizzles; they are down." % [p.name, t.name])
			continue
		var amount: int = p.plan_sabotage[target_id] + bonus
		var removed := 0
		var what := ""
		if t.resolved:
			removed = mini(amount, t.guard_left)
			t.guard_left -= removed
			what = "guard"
		else:
			removed = mini(amount, t.attack_left)
			t.attack_left -= removed
			what = "attack"
		emit_event(&"sabotage", {"pid": p.id, "target": t.id, "amount": removed, "what": what})
		log_event("%s sabotages %s: −%d %s." % [p.name, t.name, removed, what])
		for trinket_id in p.trinkets:
			Content.trinket(trinket_id).on_sabotage(self, p, t)


func _resolve_action(p: PlayerState) -> void:
	match p.plan_action:
		PlayerState.Action.ATTACK_PLAYER:
			var t := state.player(p.plan_target)
			if not t.is_active():
				emit_event(&"whiff", {"pid": p.id, "target": t.id})
				log_event("%s attacks %s, but they are already down." % [p.name, t.name])
				return
			var blocked := mini(p.attack_left, t.guard_left)
			t.guard_left -= blocked
			var damage := p.attack_left - blocked
			emit_event(&"attack", {"pid": p.id, "target": t.id, "attack": p.attack_left, "blocked": blocked, "damage": damage})
			log_event("%s attacks %s with {combat}%d: %d blocked, %d damage." % [p.name, t.name, p.attack_left, blocked, damage])
			if damage > 0:
				_damage_dealt(p, damage)
				_deal_damage(t, damage, p.id)
		PlayerState.Action.ATTACK_MOB:
			var slot: Dictionary = state.mobs[p.plan_target]
			var mob := Content.mob(slot.id)
			if p.attack_left > 0:
				_damage_dealt(p, p.attack_left)
			if p.attack_left >= mob.hp:
				slot.killed = true
				p.score += Content.MOB_KILL_SCORE
				var reward: Trinket = mob.rewards[rng.randi_range(0, mob.rewards.size() - 1)]
				log_event("%s slays the %s (+%d {score}) and gains %s." % [p.name, mob.display_name, Content.MOB_KILL_SCORE, reward.display_name])
				emit_event(&"mob_kill", {"pid": p.id, "slot": p.plan_target, "trinket": reward.id})
				_grant_trinket(p, reward.id)
			else:
				var blocked := mini(mob.damage, p.guard_left)
				p.guard_left -= blocked
				var damage := mob.damage - blocked
				log_event("%s fails to slay the %s ({combat}%d of %d) and takes %d damage." % [p.name, mob.display_name, p.attack_left, mob.hp, damage])
				emit_event(&"mob_fail", {"pid": p.id, "slot": p.plan_target, "damage": damage})
				if damage > 0:
					_deal_damage(p, damage, SOURCE_MOB)
		PlayerState.Action.ATTACK_BOSS:
			var boss := state.boss()
			if not state.boss_alive():
				emit_event(&"whiff", {"pid": p.id, "target": 0})
				log_event("%s attacks the %s, but it is already slain." % [p.name, boss.display_name])
				return
			state.boss_damage[p.id] = state.boss_damage.get(p.id, 0) + p.attack_left
			state.boss_hp = maxi(0, state.boss_hp - p.attack_left)
			emit_event(&"boss_hit", {"pid": p.id, "damage": p.attack_left, "hp": state.boss_hp})
			log_event("%s hits the %s for %d (%d/%d left)." % [p.name, boss.display_name, p.attack_left, state.boss_hp, state.boss_max_hp])
			if p.attack_left > 0:
				_damage_dealt(p, p.attack_left)
			if not state.boss_alive():
				emit_event(&"boss_slain")
				log_event("The %s is slain!" % boss.display_name)
		PlayerState.Action.REST:
			var healed := p.heal(Content.REST_HEAL)
			emit_event(&"rest", {"pid": p.id, "healed": healed})
			log_event("%s rests and heals %d {heal}." % [p.name, healed])


func _damage_dealt(p: PlayerState, amount: int) -> void:
	for trinket_id in p.trinkets:
		Content.trinket(trinket_id).on_damage_dealt(self, p, amount)


## source: a player id, SOURCE_MOB or SOURCE_BOSS.
func _deal_damage(target: PlayerState, amount: int, source: int) -> void:
	target.hp = maxi(0, target.hp - amount)
	if target.hp > 0 or target.knocked_out:
		return
	target.knocked_out = true
	emit_event(&"knockout", {"pid": target.id, "by": source})
	target.out_until_turn = state.turn + 1
	target.score = maxi(0, target.score - Content.KO_VICTIM_PENALTY)
	var attacker := state.player(source) if source > 0 else null
	if attacker:
		attacker.score += Content.KO_ATTACKER_SCORE
		log_event("%s knocks out %s! (%s +%d {score}, %s −%d {score})" % [attacker.name, target.name, attacker.name, Content.KO_ATTACKER_SCORE, target.name, Content.KO_VICTIM_PENALTY])
	else:
		log_event("%s is knocked out! (−%d {score})" % [target.name, Content.KO_VICTIM_PENALTY])


func _grant_trinket(p: PlayerState, trinket_id: StringName) -> void:
	p.trinkets.append(trinket_id)
	emit_event(&"trinket", {"pid": p.id, "trinket": trinket_id})
	Content.trinket(trinket_id).on_acquired(self, p)


func _end_of_turn() -> void:
	var boss := state.boss()
	if state.boss_alive():
		for id in state.boss_damage:
			var a := state.player(id)
			if not a.is_active():
				continue
			var blocked := mini(boss.damage, a.guard_left)
			a.guard_left -= blocked
			var damage := boss.damage - blocked
			emit_event(&"boss_strike", {"pid": a.id, "blocked": blocked, "damage": damage})
			log_event("The %s strikes %s: %d blocked, %d damage." % [boss.display_name, a.name, blocked, damage])
			if damage > 0:
				_deal_damage(a, damage, SOURCE_BOSS)
		_cleanup()
		return

	var dealers: Array[int] = []
	for id in state.boss_damage:
		if state.boss_damage[id] >= 1:
			dealers.append(id)
	for id in dealers:
		state.player(id).score += Content.BOSS_KILL_SCORE
	emit_event(&"boss_reward", {"pids": dealers.duplicate()})
	if not dealers.is_empty():
		var slayer_names := PackedStringArray()
		for id in dealers:
			slayer_names.append(state.player(id).name)
		log_event("Boss slayers: %s (+%d {score} each)." % [", ".join(slayer_names), Content.BOSS_KILL_SCORE])

	state.loot_eligible.assign(dealers.filter(func(id: int) -> bool: return state.player(id).is_active()))
	var pool := Content.BOSS_LOOT.duplicate()
	_shuffle_names(pool)
	var count := mini(ceili(state.loot_eligible.size() / 2.0), pool.size())
	state.loot.assign(pool.slice(0, count))
	if state.loot.is_empty():
		_cleanup()
		return
	state.loot_waiting = state.loot_eligible.duplicate()
	_loot_picks.clear()
	state.phase = GameState.Phase.LOOT
	emit_event(&"loot", {"items": state.loot.duplicate()})
	var loot_names := PackedStringArray()
	for item in state.loot:
		loot_names.append(Content.trinket(item).display_name)
	log_event("Loot on offer: %s. Pick in secret." % ", ".join(loot_names))


func _settle_loot() -> void:
	var pickers_by_item: Dictionary[int, Array] = {}
	for pid in state.loot_eligible:
		if not _loot_picks.has(pid):
			continue
		var item := _loot_picks[pid]
		if not pickers_by_item.has(item):
			pickers_by_item[item] = []
		pickers_by_item[item].append(pid)
	state.auctions = []
	var items := pickers_by_item.keys()
	items.sort()
	for item: int in items:
		var pickers: Array = pickers_by_item[item]
		var trinket := Content.trinket(state.loot[item])
		if pickers.size() == 1:
			var p := state.player(pickers[0])
			log_event("%s takes %s." % [p.name, trinket.display_name])
			emit_event(&"loot_taken", {"pid": p.id, "item": item})
			_grant_trinket(p, trinket.id)
		else:
			var names := PackedStringArray()
			for pid: int in pickers:
				names.append(state.player(pid).name)
			log_event("%s is contested by %s: sealed bids!" % [trinket.display_name, ", ".join(names)])
			var bidders: Array[int] = []
			bidders.assign(pickers)
			state.auctions.append({"item": item, "bidders": bidders})
			emit_event(&"auction", {"item": item, "bidders": bidders.duplicate()})
	if state.auctions.is_empty():
		_cleanup()
		return
	state.bid_waiting = []
	for auction in state.auctions:
		state.bid_waiting.append_array(auction.bidders)
	_bids.clear()
	state.phase = GameState.Phase.BID


func _settle_bids() -> void:
	for auction in state.auctions:
		var bidders: Array[int] = []
		bidders.assign(auction.bidders)
		bidders.sort_custom(func(a: int, b: int) -> bool: return _initiative_rank(a) < _initiative_rank(b))
		var winner := 0
		var best := -1
		var shown := PackedStringArray()
		for pid in bidders:
			var bid: Vector2i = _bids.get(pid, Vector2i.ZERO)
			shown.append("%s %d" % [state.player(pid).name, bid.x + bid.y])
			if bid.x + bid.y > best:
				best = bid.x + bid.y
				winner = pid
		var p := state.player(winner)
		var paid: Vector2i = _bids.get(winner, Vector2i.ZERO)
		p.gold -= paid.x
		p.renown -= paid.y
		var trinket := Content.trinket(state.loot[auction.item])
		emit_event(&"auction_won", {"pid": winner, "item": auction.item, "paid": paid.x + paid.y})
		log_event("%s wins %s (bids: %s)." % [p.name, trinket.display_name, ", ".join(shown)])
		_grant_trinket(p, trinket.id)
	_cleanup()


func _initiative_rank(pid: int) -> int:
	var rank := state.initiative.find(pid)
	return rank if rank >= 0 else state.initiative.size() + state.player(pid).seat


func _cleanup() -> void:
	for slot in state.mobs:
		if slot.killed:
			slot.id = _draw_mob()
			emit_event(&"mob_spawn", {"mob": slot.id})
			slot.killed = false
	if not state.boss_alive():
		_boss_index += 1
		_set_boss()
		emit_event(&"new_boss", {"boss": state.boss_id})
		log_event("A new boss appears: the %s." % state.boss().display_name)
	_refill_market()
	state.market_die = true
	state.first_seat = (state.first_seat + 1) % state.players.size()
	state.loot.clear()
	state.loot_eligible.clear()
	state.loot_waiting.clear()
	state.auctions.clear()
	state.bid_waiting.clear()
	state.shopping = 0
	for p in state.players:
		if p.knocked_out and p.out_until_turn <= state.turn:
			p.knocked_out = false
			p.hp = ceili(p.max_hp / 2.0)
			emit_event(&"comeback", {"pid": p.id, "hp": p.hp})
			log_event("%s is back on their feet with %d {heal}." % [p.name, p.hp])
	if state.turn >= state.max_turns:
		_finish_game()
	else:
		_start_turn()


func _finish_game() -> void:
	var ids: Array[int] = []
	for p in state.players:
		ids.append(p.id)
	ids.sort_custom(func(a: int, b: int) -> bool:
		var pa := state.player(a)
		var pb := state.player(b)
		if state.final_score(pa) != state.final_score(pb):
			return state.final_score(pa) > state.final_score(pb)
		if pa.hp != pb.hp:
			return pa.hp > pb.hp
		if pa.gold != pb.gold:
			return pa.gold > pb.gold
		return pa.seat < pb.seat)
	state.standings = ids
	state.phase = GameState.Phase.GAME_OVER
	emit_event(&"game_over", {"standings": ids.duplicate()})
	var lines := PackedStringArray()
	for i in ids.size():
		var p := state.player(ids[i])
		lines.append("%d. %s %d" % [i + 1, p.name, state.final_score(p)])
	log_event("Game over! %s" % ", ".join(lines))


# --- Decks --------------------------------------------------------------------

func _set_boss() -> void:
	var bosses := Content.bosses()
	var boss: Boss = bosses[mini(_boss_index, bosses.size() - 1)]
	state.boss_id = boss.id
	state.boss_max_hp = boss.max_hp(state.players.size())
	state.boss_hp = state.boss_max_hp
	state.boss_damage = {}


func _refill_market() -> void:
	for i in state.market.size():
		if state.market[i] != 0:
			continue
		if _market_deck.is_empty():
			if _market_discard.is_empty():
				return
			_market_deck = _shuffled(_market_discard)
			_market_discard = PackedInt32Array()
		state.market[i] = _market_deck[_market_deck.size() - 1]
		_market_deck.remove_at(_market_deck.size() - 1)


func _build_mob_deck() -> void:
	_mob_deck.clear()
	for tier in [1, 2, 3]:
		_mob_deck.append_array(_mob_tier(tier))


func _mob_tier(tier: int) -> Array[StringName]:
	var cards: Array[StringName] = []
	for mob in Content.mobs():
		if mob.tier == tier:
			for _i in mob.copies:
				cards.append(mob.id)
	_shuffle_names(cards)
	return cards


func _draw_mob() -> StringName:
	if _mob_deck.is_empty():
		_mob_deck = _mob_tier(3)
	return _mob_deck.pop_front()


func _shuffled(values: PackedInt32Array) -> PackedInt32Array:
	var out := values.duplicate()
	for i in range(out.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := out[i]
		out[i] = out[j]
		out[j] = tmp
	return out


func _shuffle_names(values: Array[StringName]) -> void:
	for i in range(values.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := values[i]
		values[i] = values[j]
		values[j] = tmp
