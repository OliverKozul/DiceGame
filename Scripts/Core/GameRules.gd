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
	&"lock_plan": [TYPE_INT, TYPE_INT, TYPE_INT, TYPE_INT],
	&"buy_face": [TYPE_INT, TYPE_INT, TYPE_INT, TYPE_INT],
	&"upgrade_face": [TYPE_INT, TYPE_INT, TYPE_INT],
	&"buy_die": [TYPE_INT],
	&"buy_renown": [],
	&"refresh_market": [TYPE_INT],
	&"finish_shop": [],
	&"pick_loot": [TYPE_INT],
	&"bid": [TYPE_INT, TYPE_INT],
}

## Sources of damage that are not players. Player ids are never 0, and bots have small negative ones.
const SOURCE_MOB := 0
const SOURCE_BOSS := -1000000
const EVENT_LIMIT := 400

var state := GameState.new()
var rng := RandomNumberGenerator.new()
## Every Chronicle entry of the game, as messages (see Loc); the state only keeps the most
## recent ones for clients.
var history: Array[Dictionary] = []
## Structured, public events for clients to animate: {"seq", "type", ...data}.
var events: Array[Dictionary] = []
## The story of the game so far, shown when it ends.
var recap: GameRecap

var _market_deck := PackedInt32Array()
var _market_discard := PackedInt32Array()
## One shuffled deck per mob tier; the act decides which one is drawn from.
var _mob_decks: Dictionary[int, Array] = {}
var _act := 1
## How many bosses have been slain: the next boss comes from the stage after that.
var _boss_index := 0
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
	recap = GameRecap.new(state.players)

	_market_deck = _shuffled(Content.market_deck())
	_market_discard = PackedInt32Array()
	var market := PackedInt32Array()
	market.resize(Content.MARKET_SIZE)
	market.fill(0)
	state.market = market
	_refill_market()

	_mob_decks.clear()
	_act = 1
	for i in Content.MOB_SLOTS:
		state.mobs.append({"id": _draw_mob(), "killed": false})
	_boss_index = 0
	_set_boss()

	log_event("The game begins: {players} players, {turns} turns.", {"players": state.players.size(), "turns": state.max_turns})
	_start_turn()
	_progress()


## Validates and performs one request. Returns {} on success, otherwise a message (see Loc)
## saying why it was refused.
func apply(pid: int, op: StringName, args: Array) -> Dictionary:
	if not OPS.has(op):
		return Loc.msg("Unknown request.")
	var types: Array = OPS[op]
	if args.size() != types.size():
		return Loc.msg("Malformed request.")
	for i in types.size():
		if typeof(args[i]) != types[i]:
			return Loc.msg("Malformed request.")
	if state.player(pid) == null:
		return Loc.msg("You are not in this game.")
	if state.phase == GameState.Phase.GAME_OVER:
		return Loc.msg("The game is over.")
	var err: Dictionary = callv("_op_" + op, [pid] + args)
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
			return [&"lock_plan", [PlayerState.Action.REST, 0, 0, p.combat if p else 0]]
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


## Adds a Chronicle entry: a msgid and its arguments (see Loc).
func log_event(key: String, args: Dictionary = {}) -> void:
	var entry := Loc.msg(key, args)
	history.append(entry)
	state.log_lines.append(entry)
	if state.log_lines.size() > GameState.LOG_LIMIT:
		state.log_lines.assign(state.log_lines.slice(state.log_lines.size() - GameState.LOG_LIMIT))


## Records something that happened, for clients to animate. Every event is public.
func emit_event(type: StringName, data: Dictionary = {}) -> void:
	_event_seq += 1
	var event := data.duplicate()
	event["seq"] = _event_seq
	event["type"] = type
	events.append(event)
	recap.observe(event, state)
	if events.size() > EVENT_LIMIT:
		events.assign(events.slice(events.size() - EVENT_LIMIT))


func last_event_seq() -> int:
	return _event_seq


func events_since(seq: int) -> Array[Dictionary]:
	var newer: Array[Dictionary] = []
	if events.is_empty():
		return newer
	# Sequence numbers are consecutive, so the oldest kept event gives the index directly.
	var start := clampi(seq - int(events[0].seq) + 1, 0, events.size())
	newer.assign(events.slice(start))
	return newer


# --- Requests ---------------------------------------------------------------

func _op_reroll(pid: int, dice: PackedInt32Array) -> Dictionary:
	var p := state.player(pid)
	var err := _check_roller(p)
	if not err.is_empty():
		return err
	if dice.is_empty():
		return Loc.msg("Choose at least one die to reroll.")
	var seen := {}
	for i in dice:
		if i < 0 or i >= p.dice.size() or seen.has(i):
			return Loc.msg("Invalid die.")
		seen[i] = true
	var cost := p.reroll_cost()
	if cost > 0 and p.roll_totals().cunning < cost:
		return Loc.msg("Rerolling again costs {cost} {cunning}.", {"cost": cost})
	p.cunning_spent += cost
	p.rerolls += 1
	for i in dice:
		p.showing[i] = rng.randi_range(0, p.dice[i].size() - 1)
	emit_event(&"reroll", {"pid": pid, "dice": dice})
	return {}


func _op_finish_roll(pid: int, wild_kinds: PackedInt32Array) -> Dictionary:
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
	log_event("{player} rolls {faces}: {gains}.", {"player": Loc.player(p), "faces": " ".join(faces), "gains": gains})
	return {}


func _op_declare(pid: int, action: int, target: int) -> Dictionary:
	if state.phase != GameState.Phase.DECLARE:
		return Loc.msg("It is not time to declare.")
	if state.current_actor() != pid:
		return Loc.msg("It is not your turn to declare.")
	var err := _check_choice(pid, action, target)
	if not err.is_empty():
		return err
	var p := state.player(pid)
	p.declared = true
	p.intention_action = action as PlayerState.Action
	p.intention_target = target
	state.cursor += 1
	var said := state.choice_message(action, target)
	emit_event(&"declare", {"pid": pid, "action": action, "target": target, "said": said})
	log_event("{player} declares: {choice}.", {"player": Loc.player(p), "choice": said})
	return {}


func _op_lock_plan(pid: int, action: int, target: int, attack: int, guard: int) -> Dictionary:
	if state.phase != GameState.Phase.PLAN:
		return Loc.msg("It is not time to plan.")
	var p := state.player(pid)
	if not p.is_active():
		return Loc.msg("You are knocked out this turn.")
	if p.plan_locked:
		return Loc.msg("Your plan is already locked.")
	var err := _check_choice(pid, action, target)
	if not err.is_empty():
		return err
	if attack < 0 or guard < 0:
		return Loc.msg("Combat amounts cannot be negative.")
	if attack > 0 and not GameState.is_attack(action):
		return Loc.msg("Only attacks use attack combat.")
	# Compared this way round, because a client could make the sum of huge amounts overflow.
	if attack > p.combat or guard > p.combat - attack:
		return Loc.msg("You only have {amount} {combat} to split.", {"amount": p.combat})
	p.plan_action = action as PlayerState.Action
	p.plan_target = target
	p.plan_attack = attack
	p.plan_guard = guard
	p.plan_locked = true
	emit_event(&"locked", {"pid": pid})
	return {}


func _op_buy_face(pid: int, slot: int, die: int, face_index: int, renown: int) -> Dictionary:
	var p := state.player(pid)
	var err := _check_shopper(pid)
	if not err.is_empty():
		return err
	if slot < 0 or slot >= state.market.size() or state.market[slot] == 0:
		return Loc.msg("That market slot is empty.")
	if die < 0 or die >= p.dice.size() or face_index < 0 or face_index >= p.dice[die].size():
		return Loc.msg("Choose one of your faces to replace.")
	var face := state.market[slot]
	var price := p.price(Content.face_price(face))
	err = _pay(p, price, renown)
	if not err.is_empty():
		return err
	var faces := p.dice[die]
	var old := faces[face_index]
	faces[face_index] = face
	p.dice[die] = faces
	state.market[slot] = 0
	emit_event(&"buy_face", {"pid": pid, "face": face, "die": die, "index": face_index, "old": old})
	log_event("{player} buys {face} for {price} and replaces {old} on die {die}.", {
		"player": Loc.player(p), "face": Loc.face(face), "price": price, "old": Loc.face(old), "die": die + 1})
	return {}


func _op_upgrade_face(pid: int, die: int, face_index: int, renown: int) -> Dictionary:
	var p := state.player(pid)
	var err := _check_shopper(pid)
	if not err.is_empty():
		return err
	if die < 0 or die >= p.dice.size() or face_index < 0 or face_index >= p.dice[die].size():
		return Loc.msg("Choose one of your faces to upgrade.")
	var old := p.dice[die][face_index]
	var price := p.price(Content.upgrade_price(old))
	if price == 0:
		return Loc.msg("That face cannot be upgraded.")
	err = _pay(p, price, renown)
	if not err.is_empty():
		return err
	var face := Face.make(Face.kind_of(old), Face.value_of(old) + 1)
	var faces := p.dice[die]
	faces[face_index] = face
	p.dice[die] = faces
	emit_event(&"upgrade", {"pid": pid, "face": face, "die": die, "index": face_index, "old": old})
	log_event("{player} upgrades {old} to {face} on die {die} for {price}.", {
		"player": Loc.player(p), "old": Loc.face(old), "face": Loc.face(face), "die": die + 1, "price": price})
	return {}


func _op_buy_renown(pid: int) -> Dictionary:
	var p := state.player(pid)
	var err := _check_shopper(pid)
	if not err.is_empty():
		return err
	if p.gold < Content.RENOWN_PRICE:
		return Loc.msg("Renown costs {price} {gold}.", {"price": Content.RENOWN_PRICE})
	p.gold -= Content.RENOWN_PRICE
	p.renown += 1
	emit_event(&"buy_renown", {"pid": pid})
	log_event("{player} buys 1 {renown} for {price} {gold}.", {"player": Loc.player(p), "price": Content.RENOWN_PRICE})
	return {}


func _op_buy_die(pid: int, renown: int) -> Dictionary:
	var p := state.player(pid)
	var err := _check_shopper(pid)
	if not err.is_empty():
		return err
	if not state.market_die:
		return Loc.msg("The market's die is sold out this turn.")
	err = _pay(p, p.price(Content.DIE_PRICE), renown)
	if not err.is_empty():
		return err
	p.add_die(Content.basic_die())
	state.market_die = false
	emit_event(&"buy_die", {"pid": pid})
	log_event("{player} buys a new die.", {"player": Loc.player(p)})
	return {}


func _op_refresh_market(pid: int, renown: int) -> Dictionary:
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
	state.refreshed = true
	emit_event(&"refresh", {"pid": pid})
	log_event("{player} refreshes the market.", {"player": Loc.player(p)})
	return {}


func _op_finish_shop(pid: int) -> Dictionary:
	var err := _check_shopper(pid)
	if not err.is_empty():
		return err
	state.player(pid).resolved = true
	emit_event(&"shop_done", {"pid": pid})
	state.shopping = 0
	state.refreshed = false
	state.cursor += 1
	return {}


func _op_pick_loot(pid: int, item: int) -> Dictionary:
	if state.phase != GameState.Phase.LOOT or state.loot_order.is_empty() or state.loot_order[0] != pid:
		return Loc.msg("It is not your turn to pick loot.")
	if item < 0 or item >= state.loot.size():
		return Loc.msg("Choose one of the items.")
	var p := state.player(pid)
	var trinket := Content.trinket(state.loot[item])
	state.loot.remove_at(item)
	state.loot_order.remove_at(0)
	log_event("{player} takes {trinket}.", {"player": Loc.player(p), "trinket": Loc.trinket(trinket.id)})
	emit_event(&"loot_taken", {"pid": pid, "trinket": trinket.id})
	_grant_trinket(p, trinket.id)
	return {}


func _op_bid(pid: int, gold: int, renown: int) -> Dictionary:
	if state.phase != GameState.Phase.BID or not state.bid_waiting.has(pid):
		return Loc.msg("You are not bidding.")
	var p := state.player(pid)
	if gold < 0 or renown < 0 or gold > p.gold or renown > p.renown:
		return Loc.msg("You cannot bid more than you have.")
	_bids[pid] = Vector2i(gold, renown)
	state.bid_waiting.erase(pid)
	return {}


func _check_roller(p: PlayerState) -> Dictionary:
	if state.phase != GameState.Phase.ROLL:
		return Loc.msg("It is not time to roll.")
	if not p.is_active():
		return Loc.msg("You are knocked out this turn.")
	if p.roll_done:
		return Loc.msg("You already kept your dice.")
	return {}


func _check_shopper(pid: int) -> Dictionary:
	if state.phase != GameState.Phase.RESOLVE or state.shopping != pid:
		return Loc.msg("You are not shopping right now.")
	return {}


func _check_choice(pid: int, action: int, target: int) -> Dictionary:
	match action:
		PlayerState.Action.ATTACK_PLAYER:
			var t := state.player(target)
			if t == null or t.id == pid or not t.is_active():
				return Loc.msg("Choose a player who is in the game.")
		PlayerState.Action.ATTACK_MOB:
			if target < 0 or target >= state.mobs.size() or state.mobs[target].id == &"":
				return Loc.msg("Choose one of the mobs.")
		PlayerState.Action.ATTACK_BOSS, PlayerState.Action.SHOP, PlayerState.Action.REST:
			if target != 0:
				return Loc.msg("That action has no target.")
		_:
			return Loc.msg("Choose an action.")
	return {}


## Pays `price` gold, `renown` of it in renown worth Content.RENOWN_GOLD each. Renown that
## would only pay for gold already covered is refused rather than wasted.
func _pay(p: PlayerState, price: int, renown: int) -> Dictionary:
	if renown < 0 or renown > mini(ceili(price / float(Content.RENOWN_GOLD)), p.renown):
		return Loc.msg("You cannot pay that much renown.")
	var gold := maxi(0, price - renown * Content.RENOWN_GOLD)
	if gold > p.gold:
		return Loc.msg("You cannot afford that.")
	p.renown -= renown
	p.gold -= gold
	return {}


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
				if not state.loot_order.is_empty() and not state.loot.is_empty():
					return
				_start_auction()
			GameState.Phase.BID:
				if not state.bid_waiting.is_empty():
					return
				_settle_bids()
			_:
				return


func _start_turn() -> void:
	state.turn += 1
	if _mob_act() != _act:
		_begin_act(_mob_act())
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
	log_event("── Turn {turn} of {turns} ──", {"turn": state.turn, "turns": state.max_turns})


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
	log_event("Initiative: {order}.", {"order": ", ".join(order)})


func _reveal() -> void:
	for id in state.initiative:
		var p := state.player(id)
		p.kept_word = p.declared and p.plan_action == p.intention_action and p.plan_target == p.intention_target
		p.attack_left = p.plan_attack
		p.guard_left = p.plan_guard + p.guard_bonus
		var did := state.plan_message(p)
		var args := {"player": Loc.player(p), "plan": did}
		var gained := 0
		if p.kept_word:
			p.oath += 1
			if p.oath >= Content.OATH_LENGTH:
				p.oath = 0
				gained = Content.OATH_RENOWN
				for trinket_id in p.trinkets:
					gained += Content.trinket(trinket_id).honesty_bonus()
				p.renown += gained
				args["amount"] = gained
				log_event("{player} reveals: {plan} — kept their word and completed an oath (+{amount} {renown}).", args)
			else:
				args.merge({"oath": p.oath, "length": Content.OATH_LENGTH})
				log_event("{player} reveals: {plan} — kept their word (oath {oath}/{length}).", args)
		elif p.has_effect(&"keeps_oath_when_lying"):
			args.merge({"oath": p.oath, "length": Content.OATH_LENGTH})
			log_event("{player} reveals: {plan} — broke their word, but their oath holds ({oath}/{length}).", args)
		else:
			p.oath = 0
			log_event("{player} reveals: {plan} — broke their word; their oath is broken.", args)
		emit_event(&"reveal", {"pid": id, "kept": p.kept_word, "renown": gained, "oath": p.oath, "action": p.plan_action, "did": did})
		for trinket_id in p.trinkets:
			Content.trinket(trinket_id).on_reveal(self, p)
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
			log_event("{player} is down; their action is lost.", {"player": Loc.player(p)})
			p.resolved = true
			state.cursor += 1
			continue
		if p.plan_action == PlayerState.Action.SHOP:
			state.shopping = p.id
			state.refreshed = false
			emit_event(&"shop", {"pid": p.id})
			log_event("{player} goes shopping.", {"player": Loc.player(p)})
			return false
		_resolve_action(p)
		p.resolved = true
		state.cursor += 1
	return true


func _resolve_action(p: PlayerState) -> void:
	match p.plan_action:
		PlayerState.Action.ATTACK_PLAYER:
			var t := state.player(p.plan_target)
			if not t.is_active():
				emit_event(&"whiff", {"pid": p.id, "target": t.id})
				log_event("{player} attacks {target}, but they are already down.", {"player": Loc.player(p), "target": Loc.player(t)})
				return
			var blocked := mini(p.attack_left, t.guard_left)
			t.guard_left -= blocked
			var damage := p.attack_left - blocked
			emit_event(&"attack", {"pid": p.id, "target": t.id, "attack": p.attack_left, "blocked": blocked, "damage": damage})
			log_event("{player} attacks {target} with {combat}{attack}: {blocked} blocked, {damage} damage.", {
				"player": Loc.player(p), "target": Loc.player(t), "attack": p.attack_left, "blocked": blocked, "damage": damage})
			if damage > 0:
				var stolen := Content.renown_stolen(p.renown, t.renown)
				if stolen > 0:
					t.renown -= stolen
					p.renown += stolen
					emit_event(&"steal", {"pid": p.id, "target": t.id, "amount": stolen, "what": "renown"})
					log_event("{player} takes {amount} {renown} from {target}.", {"player": Loc.player(p), "amount": stolen, "target": Loc.player(t)})
				_damage_dealt(p, damage)
				for trinket_id in p.trinkets:
					Content.trinket(trinket_id).on_player_hit(self, p, t, damage)
				_deal_damage(t, damage, p.id)
				for trinket_id in t.trinkets:
					Content.trinket(trinket_id).on_hit_by_player(self, t, p, damage)
		PlayerState.Action.ATTACK_MOB:
			var slot: Dictionary = state.mobs[p.plan_target]
			var mob := Content.mob(slot.id)
			if slot.killed:
				# A mob falls once per turn: a faster player got there first.
				emit_event(&"whiff", {"pid": p.id, "target": 0})
				log_event("{player} attacks the {mob}, but it is already slain.", {"player": Loc.player(p), "mob": Loc.mob(mob.id)})
				return
			if p.attack_left > 0:
				_damage_dealt(p, p.attack_left)
			if p.attack_left >= mob.hp:
				slot.killed = true
				var gained := Content.mob_score(mob)
				p.score += gained
				var reward: Trinket = mob.rewards[rng.randi_range(0, mob.rewards.size() - 1)]
				log_event("{player} slays the {mob} (+{amount} {score}) and gains {trinket}.", {
					"player": Loc.player(p), "mob": Loc.mob(mob.id), "amount": gained, "trinket": Loc.trinket(reward.id)})
				emit_event(&"mob_kill", {"pid": p.id, "slot": p.plan_target, "trinket": reward.id, "score": gained})
				_grant_trinket(p, reward.id)
			else:
				var blocked := mini(mob.damage, p.guard_left)
				p.guard_left -= blocked
				var damage := mob.damage - blocked
				log_event("{player} fails to slay the {mob} ({combat}{attack} of {hp}) and takes {damage} damage.", {
					"player": Loc.player(p), "mob": Loc.mob(mob.id), "attack": p.attack_left, "hp": mob.hp, "damage": damage})
				emit_event(&"mob_fail", {"pid": p.id, "slot": p.plan_target, "damage": damage})
				if damage > 0:
					_deal_damage(p, damage, SOURCE_MOB)
		PlayerState.Action.ATTACK_BOSS:
			var boss := state.boss()
			if not state.boss_alive():
				emit_event(&"whiff", {"pid": p.id, "target": 0})
				log_event("{player} attacks the {boss}, but it is already slain.", {"player": Loc.player(p), "boss": Loc.boss(boss.id)})
				return
			state.boss_damage[p.id] = state.boss_damage.get(p.id, 0) + p.attack_left
			state.boss_hp = maxi(0, state.boss_hp - p.attack_left)
			emit_event(&"boss_hit", {"pid": p.id, "damage": p.attack_left, "hp": state.boss_hp})
			log_event("{player} hits the {boss} for {damage} ({hp}/{max} left).", {
				"player": Loc.player(p), "boss": Loc.boss(boss.id), "damage": p.attack_left, "hp": state.boss_hp, "max": state.boss_max_hp})
			if p.attack_left > 0:
				_damage_dealt(p, p.attack_left)
			if not state.boss_alive():
				emit_event(&"boss_slain")
				log_event("The {boss} is slain!", {"boss": Loc.boss(boss.id)})
		PlayerState.Action.REST:
			var amount := Content.REST_HEAL
			for trinket_id in p.trinkets:
				amount += Content.trinket(trinket_id).rest_bonus()
			var healed := p.heal(amount)
			emit_event(&"rest", {"pid": p.id, "healed": healed})
			log_event("{player} rests and heals {amount} {heal}.", {"player": Loc.player(p), "amount": healed})


func _damage_dealt(p: PlayerState, amount: int) -> void:
	for trinket_id in p.trinkets:
		Content.trinket(trinket_id).on_damage_dealt(self, p, amount)


## Damage from a trinket effect. source: the player the damage counts as coming from.
func hurt(target: PlayerState, amount: int, source: int) -> void:
	_deal_damage(target, amount, source)


## source: a player id, SOURCE_MOB or SOURCE_BOSS.
func _deal_damage(target: PlayerState, amount: int, source: int) -> void:
	target.hp = maxi(0, target.hp - amount)
	if target.hp > 0 or target.knocked_out:
		return
	target.knocked_out = true
	emit_event(&"knockout", {"pid": target.id, "by": source})
	target.out_until_turn = state.turn + 1
	target.score = maxi(0, target.score - Content.KO_VICTIM_PENALTY)
	var attacker := state.player(source)
	if attacker:
		attacker.score += Content.KO_ATTACKER_SCORE
		log_event("{player} knocks out {target}! ({player} +{gain} {score}, {target} −{loss} {score})", {
			"player": Loc.player(attacker), "target": Loc.player(target), "gain": Content.KO_ATTACKER_SCORE, "loss": Content.KO_VICTIM_PENALTY})
	else:
		log_event("{player} is knocked out! (−{loss} {score})", {"player": Loc.player(target), "loss": Content.KO_VICTIM_PENALTY})


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
			log_event("The {boss} strikes {player}: {blocked} blocked, {damage} damage.", {
				"boss": Loc.boss(boss.id), "player": Loc.player(a), "blocked": blocked, "damage": damage})
			if damage > 0:
				_deal_damage(a, damage, SOURCE_BOSS)
		_cleanup()
		return

	# Only attackers who dealt a real share of the damage count as slayers.
	var threshold := Content.boss_loot_threshold(state.boss_max_hp)
	var dealers: Array[int] = []
	for id in state.boss_damage:
		if state.boss_damage[id] >= threshold:
			dealers.append(id)
	for id in dealers:
		state.player(id).score += Content.BOSS_KILL_SCORE
	emit_event(&"boss_reward", {"pids": dealers.duplicate()})
	if not dealers.is_empty():
		log_event("Boss slayers: {players} (+{amount} {score} each).", {"players": state.names_of(dealers), "amount": Content.BOSS_KILL_SCORE})

	# Slayers pick loot, most damage first; one more item goes to a sealed bid that every
	# player may join.
	var pickers: Array[int] = []
	for id in dealers:
		if state.player(id).is_active():
			pickers.append(id)
	pickers.sort_custom(func(a: int, b: int) -> bool:
		if state.boss_damage[a] != state.boss_damage[b]:
			return state.boss_damage[a] > state.boss_damage[b]
		return _initiative_rank(a) < _initiative_rank(b))
	var pool := Content.BOSS_LOOT.duplicate()
	_shuffle_names(pool)
	var picks := mini(ceili(pickers.size() / 2.0), pool.size())
	state.loot.assign(pool.slice(0, picks))
	state.loot_order.assign(pickers.slice(0, picks))
	state.auction_item = pool[picks] if picks < pool.size() else &""
	if state.loot.is_empty() and state.auction_item == &"":
		_cleanup()
		return
	state.phase = GameState.Phase.LOOT
	emit_event(&"loot", {"items": state.loot.duplicate(), "order": state.loot_order.duplicate(), "auction": state.auction_item})
	if not state.loot.is_empty():
		# The items form a list message of their own, so each name is translated by the reader.
		var items := {}
		var listed := PackedStringArray()
		for i in state.loot.size():
			items["item%d" % i] = Loc.trinket(state.loot[i])
			listed.append("{item%d}" % i)
		log_event("Spoils: {items}. {players} pick first, most damage first (at least {share} to share).", {
			"items": Loc.msg(", ".join(listed), items), "players": state.names_of(state.loot_order), "share": threshold})


## After the picks: everyone still in the game may bid for the auction item.
func _start_auction() -> void:
	state.loot.clear()
	state.loot_order.clear()
	if state.auction_item == &"":
		_cleanup()
		return
	state.bid_waiting = state.active_ids()
	_bids.clear()
	state.phase = GameState.Phase.BID
	var trinket := Content.trinket(state.auction_item)
	emit_event(&"auction", {"trinket": trinket.id})
	log_event("{trinket} goes to a sealed bid. Everyone may bid {gold} and {renown} (worth {rate} {gold} each).", {
		"trinket": Loc.trinket(trinket.id), "rate": Content.RENOWN_GOLD})


## The highest bid of at least 1 wins and pays; ties go to whoever hurt the boss more, then
## to initiative. With no bids the item is lost.
func _settle_bids() -> void:
	var trinket := Content.trinket(state.auction_item)
	var bidders: Array[int] = []
	bidders.assign(_bids.keys())
	bidders.sort_custom(func(a: int, b: int) -> bool:
		var va := _bid_value(a)
		var vb := _bid_value(b)
		if va != vb:
			return va > vb
		var da: int = state.boss_damage.get(a, 0)
		var db: int = state.boss_damage.get(b, 0)
		if da != db:
			return da > db
		return _initiative_rank(a) < _initiative_rank(b))
	var shown := PackedStringArray()
	for pid in bidders:
		shown.append("%s %d" % [state.player(pid).name, _bid_value(pid)])
	if bidders.is_empty() or _bid_value(bidders[0]) < 1:
		emit_event(&"auction_unsold", {"trinket": trinket.id})
		log_event("Nobody bids for {trinket}; it is lost.", {"trinket": Loc.trinket(trinket.id)})
	else:
		var winner := state.player(bidders[0])
		var paid: Vector2i = _bids[winner.id]
		winner.gold -= paid.x
		winner.renown -= paid.y
		emit_event(&"auction_won", {"pid": winner.id, "trinket": trinket.id, "paid": _bid_value(winner.id)})
		log_event("{player} wins {trinket} (bids: {bids}).", {"player": Loc.player(winner), "trinket": Loc.trinket(trinket.id), "bids": ", ".join(shown)})
		_grant_trinket(winner, trinket.id)
	_cleanup()


func _bid_value(pid: int) -> int:
	var bid: Vector2i = _bids.get(pid, Vector2i.ZERO)
	return bid.x + bid.y * Content.RENOWN_GOLD


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
		log_event("A new boss appears: the {boss}.", {"boss": Loc.boss(state.boss_id)})
	_refill_market()
	state.market_die = true
	state.first_seat = (state.first_seat + 1) % state.players.size()
	state.loot.clear()
	state.loot_order.clear()
	state.auction_item = &""
	state.bid_waiting.clear()
	state.shopping = 0
	state.refreshed = false
	for p in state.players:
		if p.knocked_out and p.out_until_turn <= state.turn:
			p.knocked_out = false
			p.hp = p.max_hp if p.has_effect(&"full_comeback") else ceili(p.max_hp / 2.0)
			emit_event(&"comeback", {"pid": p.id, "hp": p.hp})
			log_event("{player} is back on their feet with {amount} {heal}.", {"player": Loc.player(p), "amount": p.hp})
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
	state.recap = recap.to_dict()
	state.phase = GameState.Phase.GAME_OVER
	emit_event(&"game_over", {"standings": ids.duplicate()})
	var lines := PackedStringArray()
	for i in ids.size():
		var p := state.player(ids[i])
		lines.append("%d. %s %d" % [i + 1, p.name, state.final_score(p)])
	log_event("Game over! {standings}", {"standings": ", ".join(lines)})


# --- Decks --------------------------------------------------------------------

func _set_boss() -> void:
	var stage := mini(_boss_index + 1, Content.BOSS_STAGES)
	var bosses := Content.bosses_of_stage(stage)
	var boss: Boss = bosses[rng.randi_range(0, bosses.size() - 1)]
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


func _mob_tier(tier: int) -> Array[StringName]:
	var cards: Array[StringName] = []
	for mob in Content.mobs():
		if mob.tier == tier:
			for _i in mob.copies:
				cards.append(mob.id)
	_shuffle_names(cards)
	return cards


## The act of the current turn: the turns are split evenly into Content.MOB_ACTS acts.
func _mob_act() -> int:
	return clampi(ceili(maxi(state.turn, 1) * float(Content.MOB_ACTS) / state.max_turns), 1, Content.MOB_ACTS)


## A new act: every mob on the table is replaced by one of the act's tier.
func _begin_act(act: int) -> void:
	_act = act
	emit_event(&"act", {"act": act})
	log_event("Act {act} begins: stronger mobs take the table.", {"act": act})
	for slot in state.mobs:
		slot.id = _draw_mob()
		slot.killed = false
		emit_event(&"mob_spawn", {"mob": slot.id})


func _draw_mob() -> StringName:
	var tier := _mob_act()
	if not _mob_decks.has(tier) or _mob_decks[tier].is_empty():
		_mob_decks[tier] = _mob_tier(tier)
	return _mob_decks[tier].pop_front()


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
