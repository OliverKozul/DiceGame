class_name BotBrain
extends RefCounted
## Plays one seat using only what that player can see (a GameState view). decide() returns
## the next request as [op, args], or [] when the bot has nothing to do right now.
## Simple heuristics: good enough to play against, not meant to be strong.

## Chance the bot declares what it really plans to do.
const HONESTY := 0.7
## Keep the declared intention when it is at least this good compared to the best option.
const KEEP_WORD_RATIO := 0.75
const LOW_HP := 8

const FACE_WEIGHTS: Dictionary = {
	Face.Kind.NONE: 0.0,
	Face.Kind.COMBAT: 1.2,
	Face.Kind.GOLD: 1.0,
	Face.Kind.CUNNING: 0.7,
	Face.Kind.GUARD: 0.9,
	Face.Kind.HEAL: 0.8,
	Face.Kind.WILD: 1.3,
	Face.Kind.RENOWN: 2.0,
	Face.Kind.DOUBLE: 1.5,
}


static func decide(view: GameState, me: int, rng: RandomNumberGenerator) -> Array:
	if not view.is_waiting_on(me):
		return []
	var p := view.player(me)
	match view.phase:
		GameState.Phase.ROLL:
			return _roll(p)
		GameState.Phase.DECLARE:
			return _declare(view, p, rng)
		GameState.Phase.PLAN:
			return _plan(view, p)
		GameState.Phase.RESOLVE:
			return _shop(view, p)
		GameState.Phase.LOOT:
			return [&"pick_loot", [rng.randi_range(0, view.loot.size() - 1)]]
		GameState.Phase.BID:
			return [&"bid", [rng.randi_range(0, mini(p.gold, 4)), 0]]
	return []


static func face_worth(face: int) -> float:
	return Face.value_of(face) * float(FACE_WEIGHTS.get(Face.kind_of(face), 0.0))


static func _roll(p: PlayerState) -> Array:
	if p.rerolls == 0:
		var reroll := PackedInt32Array()
		for i in p.dice.size():
			var total := 0.0
			for face in p.dice[i]:
				total += face_worth(face)
			if face_worth(p.dice[i][p.showing[i]]) < total / p.dice[i].size():
				reroll.append(i)
		if not reroll.is_empty():
			return [&"reroll", [reroll]]
	var wilds := PackedInt32Array()
	for _i in p.wild_count():
		wilds.append(Face.Kind.COMBAT)
	return [&"finish_roll", [wilds]]


static func _declare(view: GameState, p: PlayerState, rng: RandomNumberGenerator) -> Array:
	var options := _options(view, p)
	var best: Array = options[0]
	if rng.randf() < HONESTY or options.size() == 1:
		return [&"declare", [best[0], best[1]]]
	var decoy: Array = options[rng.randi_range(1, options.size() - 1)]
	return [&"declare", [decoy[0], decoy[1]]]


static func _plan(view: GameState, p: PlayerState) -> Array:
	var options := _options(view, p)
	var choice: Array = options[0]
	for option: Array in options:
		if option[0] == p.intention_action and option[1] == p.intention_target:
			if option[2] >= choice[2] * KEEP_WORD_RATIO:
				choice = option
			break
	var action: int = choice[0]
	var target: int = choice[1]
	var combat := p.combat
	var threat := _threat_against(view, p.id)
	var attack := 0
	var guard := 0
	var sabotage := {}

	if action == PlayerState.Action.ATTACK_MOB:
		attack = mini(combat, Content.mob(view.mobs[target].id).hp)
		guard = combat - attack
	elif GameState.is_attack(action):
		guard = mini(threat, floori(combat / 3.0))
		attack = combat - guard
	else:
		var attacker := _slower_attacker(view, p)
		if attacker != 0 and combat > 1:
			var amount := mini(view.player(attacker).combat, floori(combat / 2.0))
			if amount > 0:
				sabotage[attacker] = amount
				combat -= amount
		guard = combat
	return [&"lock_plan", [action, target, attack, guard, sabotage]]


static func _shop(view: GameState, p: PlayerState) -> Array:
	if view.shopping != p.id:
		return []
	var best_slot := -1
	var best_die := 0
	var best_face := 0
	var best_gain := 0.3
	for slot in view.market.size():
		var face := view.market[slot]
		if face == 0 or Content.face_price(face) > p.gold:
			continue
		for d in p.dice.size():
			for f in p.dice[d].size():
				var gain := (face_worth(face) - face_worth(p.dice[d][f])) / Content.face_price(face)
				if gain > best_gain:
					best_gain = gain
					best_slot = slot
					best_die = d
					best_face = f
	if best_slot >= 0:
		return [&"buy_face", [best_slot, best_die, best_face, 0]]
	if view.market_die and p.gold >= Content.DIE_PRICE and p.dice.size() < 4:
		return [&"buy_die", [0]]
	return [&"finish_shop", []]


## Every legal choice with a rough value, best first.
static func _options(view: GameState, p: PlayerState) -> Array:
	var options: Array = []
	var combat := p.combat

	for slot in view.mobs.size():
		var mob := Content.mob(view.mobs[slot].id)
		if mob == null:
			continue
		var value := 3.0 + mob.tier - mob.hp * 0.1 if combat >= mob.hp else 0.2
		options.append([PlayerState.Action.ATTACK_MOB, slot, value])

	# Join a boss attack that the declared attackers can finish; propose one when the whole
	# table could, hoping others join (in the plan phase only declared attackers count).
	var boss_power := combat
	var table_power := 0
	for other in view.players:
		if not other.is_active():
			continue
		table_power += other.combat
		if other.id != p.id and other.declared and other.intention_action == PlayerState.Action.ATTACK_BOSS:
			boss_power += other.combat
	var boss_value := 0.4
	if combat > 0 and boss_power >= view.boss_hp:
		boss_value = 3.5
	elif view.phase == GameState.Phase.DECLARE and combat >= 2 and table_power >= view.boss_hp:
		boss_value = 2.2
	options.append([PlayerState.Action.ATTACK_BOSS, 0, boss_value])

	var leader := 0
	for other in view.players:
		if other.id == p.id or not other.is_active():
			continue
		var value := 0.8 + combat * 0.3
		if combat == 0:
			value = 0.05
		elif other.hp <= combat:
			value = 4.0
		if leader == 0 or view.final_score(other) > view.final_score(view.player(leader)):
			leader = other.id
		options.append([PlayerState.Action.ATTACK_PLAYER, other.id, value + (0.3 if other.id == leader else 0.0)])

	options.append([PlayerState.Action.SHOP, 0, 1.5 + 0.2 * p.gold if p.gold >= 2 else 0.1])
	options.append([PlayerState.Action.REST, 0, 3.0 if p.hp <= LOW_HP else 0.3])

	options.sort_custom(func(a: Array, b: Array) -> bool: return a[2] > b[2])
	return options


## Combat of players who declared they will attack this player.
static func _threat_against(view: GameState, id: int) -> int:
	var threat := 0
	for other in view.players:
		if other.id != id and other.declared and other.intention_action == PlayerState.Action.ATTACK_PLAYER and other.intention_target == id:
			threat += other.combat
	return threat


## Someone who declared an attack on p and resolves after p, so sabotage hits their attack.
static func _slower_attacker(view: GameState, p: PlayerState) -> int:
	var my_rank := view.initiative.find(p.id)
	for i in range(my_rank + 1, view.initiative.size()):
		var other := view.player(view.initiative[i])
		if other.intention_action == PlayerState.Action.ATTACK_PLAYER and other.intention_target == p.id and other.combat > 0:
			return other.id
	return 0
