class_name StrategyBot
extends RefCounted
## A bot with a play style: the Normal and Hard opponents (see BotTable) and the players of the
## strategy simulations. Like BotBrain it sees only one player's view of the table plus the
## public events, but what it values comes from a style dictionary, and it remembers who keeps
## their word.
## Values are in score points; resources convert to points at UNITS_PER_POINT.
##
## How it reads the table is set by `reads` (the simulator sets it for every bot):
##   NAIVE       ignores threats when choosing (like BotBrain): lying never pays against it.
##   GULLIBLE    believes every declaration and reacts to declared attacks (guards, or picks
##               a safer action): the most a lie can ever earn.
##   SUSPICIOUS  reacts too, but discounts each declaration by that player's public record of
##               broken words, and expects some hidden attacks from anyone.
## Liars (every style that does not insist on keeping its word) lie when the ambush is worth
## more than the oath progress plus the damage to their reputation.
##
## Tactics on top of the one-turn values: endgame awareness (oaths that cannot complete are
## worthless, HP matters less as the end nears, the leader is the target late on), bluffs
## (declaring an attack it will not make, to tie up a leader's combat), boss coalitions that
## trust each declaration only as far as that player's record, and no kingmaking (it goes easy
## on players far behind).

enum Reads { NAIVE, GULLIBLE, SUSPICIOUS }

## Resource units (roughly gold) one score point is worth.
const UNITS_PER_POINT := 3.5
## What a trinket from a mob, and an item from a boss, is worth in points at the start of the game.
const TRINKET_POINTS := 1.2
const BOSS_ITEM_POINTS := 2.5
## Chance that a lying player's hidden plan is an attack on some player (spread over targets).
const HIDDEN_ATTACK := 0.5
## Chance that a player who has not declared yet attacks a player (spread over targets).
const UNDECLARED_ATTACK := 0.25
## What one lost HP costs in points, and what a lost turn costs (both shrink near the end).
const HP_POINTS := 0.12
const LOST_TURN_POINTS := 1.2
## In the last this many turns, the leader is everyone's target.
const ENDGAME_TURNS := 3
## What a point of stolen renown is worth (it is also a point for the thief).
const STEAL_POINTS := 1.3

## Every key a style may set. Styles in STYLES override some of these.
const BASE: Dictionary = {
	"honesty": 1.0, # chance it declares sincerely at all; otherwise a random decoy
	"word_value": 0.0, # extra value (beyond the renown) it puts on keeping its word; >= 50 never lies
	"rep_cost": 0.3, # points it thinks one broken word costs in future credibility
	"bluff": 0.0, # chance to declare a fake attack on the leader when its oath has nothing to lose
	"mob": 1.0, "boss": 1.0, "pvp": 1.0, "shop": 1.0, "rest": 1.0, # option weights
	"shop_until": 99, # after this turn the shop weight drops to a third
	"rest_hp": 6,
	"max_dice": 4,
	"spend_renown": false, # pay with renown when gold runs short
	"buy_ratio": 0.3, # minimum resource units gained per gold spent (leftover gold is worthless)
	"guard_share": 0.34, # NAIVE only: most of its combat it guards with when attacking under threat
	"wild": Face.Kind.COMBAT,
	"extra_rerolls": 0, # rerolls it pays cunning for
	"random": false, # pick uniformly among legal options (a floor to compare against)
	"faces": {
		Face.Kind.NONE: 0.0, Face.Kind.COMBAT: 1.2, Face.Kind.GOLD: 1.0, Face.Kind.CUNNING: 0.5,
		Face.Kind.GUARD: 0.7, Face.Kind.HEAL: 0.6, Face.Kind.WILD: 1.3, Face.Kind.RENOWN: 3.0,
		Face.Kind.DOUBLE: 2.0,
	},
}

## Named play styles: overrides of BASE. "baseline" is not here: it is BotBrain itself.
const STYLES: Dictionary = {
	# Balanced and always keeps its word.
	"honest": {"word_value": 99.0},
	# Balanced and rational: lies whenever the numbers say so.
	"rational": {"bluff": 0.15},
	# Declares a random decoy every turn and does what is best.
	"liar": {"honesty": 0.0},
	# Rational with a taste for ambushes and little care for its reputation.
	"opportunist": {"pvp": 1.3, "rep_cost": 0.1, "bluff": 0.3},
	# Kills mobs, buys combat.
	"farmer": {"mob": 1.6, "pvp": 0.4, "boss": 0.6,
		"faces": {Face.Kind.NONE: 0.0, Face.Kind.COMBAT: 1.6, Face.Kind.GOLD: 0.9, Face.Kind.CUNNING: 0.3,
			Face.Kind.GUARD: 0.5, Face.Kind.HEAL: 0.5, Face.Kind.WILD: 1.6, Face.Kind.RENOWN: 2.5, Face.Kind.DOUBLE: 2.0}},
	# Hunts players, buys combat.
	"warlord": {"pvp": 2.5, "mob": 0.8, "guard_share": 0.2, "rep_cost": 0.0, "bluff": 0.2,
		"faces": {Face.Kind.NONE: 0.0, Face.Kind.COMBAT: 1.8, Face.Kind.GOLD: 0.8, Face.Kind.CUNNING: 0.6,
			Face.Kind.GUARD: 0.4, Face.Kind.HEAL: 0.4, Face.Kind.WILD: 1.7, Face.Kind.RENOWN: 2.0, Face.Kind.DOUBLE: 2.0}},
	# Builds an engine early (dice and gold), fights late.
	"builder": {"shop": 1.8, "shop_until": 8, "max_dice": 5, "buy_ratio": 0.15, "spend_renown": true, "wild": Face.Kind.GOLD,
		"faces": {Face.Kind.NONE: 0.0, Face.Kind.COMBAT: 1.3, Face.Kind.GOLD: 1.3, Face.Kind.CUNNING: 0.4,
			Face.Kind.GUARD: 0.5, Face.Kind.HEAL: 0.4, Face.Kind.WILD: 1.5, Face.Kind.RENOWN: 2.5, Face.Kind.DOUBLE: 2.2}},
	# Goes for the boss whenever it can.
	"boss_hunter": {"boss": 2.0, "mob": 0.8, "pvp": 0.4},
	# Never fights: rests or shops and always keeps its word.
	"turtle": {"mob": 0.0, "boss": 0.0, "pvp": 0.0, "word_value": 99.0, "rest_hp": 12,
		"faces": {Face.Kind.NONE: 0.0, Face.Kind.COMBAT: 0.5, Face.Kind.GOLD: 1.2, Face.Kind.CUNNING: 0.3,
			Face.Kind.GUARD: 1.0, Face.Kind.HEAL: 0.8, Face.Kind.WILD: 1.2, Face.Kind.RENOWN: 3.5, Face.Kind.DOUBLE: 1.5}},
	# Hoards renown: never spends it, prizes renown faces, keeps its word.
	"miser": {"word_value": 99.0, "spend_renown": false,
		"faces": {Face.Kind.NONE: 0.0, Face.Kind.COMBAT: 1.1, Face.Kind.GOLD: 1.1, Face.Kind.CUNNING: 0.3,
			Face.Kind.GUARD: 0.6, Face.Kind.HEAL: 0.5, Face.Kind.WILD: 1.2, Face.Kind.RENOWN: 5.0, Face.Kind.DOUBLE: 1.5}},
	# Pays cunning for extra rerolls and prizes cunning (tempo).
	"schemer": {"extra_rerolls": 2, "rep_cost": 0.15, "bluff": 0.3,
		"faces": {Face.Kind.NONE: 0.0, Face.Kind.COMBAT: 1.2, Face.Kind.GOLD: 1.0, Face.Kind.CUNNING: 1.1,
			Face.Kind.GUARD: 0.6, Face.Kind.HEAL: 0.5, Face.Kind.WILD: 1.3, Face.Kind.RENOWN: 3.0, Face.Kind.DOUBLE: 2.0}},
	# Uniformly random legal play.
	"random": {"random": true},
}

const TRINKET_WORTH: Dictionary = {
	&"sharp_tooth": 1.5, &"backstab_dagger": 0.6, &"coin_magnet": 0.7, &"goblet_of_blood": 0.8,
	&"third_eye": 1.0, &"opportunity": 2.5, &"crown_of_honor": 1.5, &"golden_idol": 2.2, &"dragonscale": 1.8,
	&"war_banner": 2.2, &"wyrm_heart": 1.2, &"lucky_coin": 1.0, &"fox_mask": 0.6, &"bone_dice": 0.5,
	&"herbal_pouch": 0.4, &"hunters_horn": 1.0, &"silver_tongue": 0.8, &"smoke_bomb": 0.5, &"thorned_mail": 0.6,
	&"liars_mask": 1.6, &"phoenix_feather": 0.9, &"merchants_seal": 1.6,
}

var style: Dictionary = {}
var reads: Reads = Reads.NAIVE
## Public record of every player's revealed plans: pid -> (kept, broken).
var record: Dictionary[int, Vector2i] = {}
## How often each player has hit the boss, and how many turns have been seen.
var boss_joins: Dictionary[int, int] = {}
var turns_seen := 0

# The style unpacked into typed fields, because the hot loops read them.
var _face_weight := PackedFloat64Array()
var _honesty := 1.0
var _word_value := 0.0
var _rep_cost := 0.0
var _bluff := 0.0
var _w_mob := 1.0
var _w_boss := 1.0
var _w_pvp := 1.0
var _w_shop := 1.0
var _w_rest := 1.0
var _shop_until := 99
var _rest_hp := 6
var _max_dice := 4
var _spend_renown := false
var _buy_ratio := 0.3
var _guard_share := 0.34
var _wild := 0
var _extra_rerolls := 0
var _random := false
## What a market die adds per roll, and market prices by face.
var _basic_die_per_roll := 0.0
var _prices: Dictionary[int, int] = {}
var _upgrades: Dictionary[int, int] = {}

# Worked out once per decision by _prepare (the view does not change while deciding).
var _index: Dictionary[int, int] = {}
var _share := PackedFloat64Array()
var _chance := PackedFloat64Array()
var _my_pvp_guard := 0
var _my_leader := 0
var _turns_left_now := 0


func _init(style_name: String, how_it_reads: Reads = Reads.NAIVE) -> void:
	style = BASE.duplicate(true)
	style.merge(STYLES.get(style_name, {}), true)
	reads = how_it_reads
	var weights: Dictionary = style.faces
	for kind in Face.Kind.size():
		_face_weight.append(float(weights.get(kind, 0.0)))
	_honesty = float(style.honesty)
	_word_value = float(style.word_value)
	_rep_cost = float(style.rep_cost)
	_bluff = float(style.bluff)
	_w_mob = float(style.mob)
	_w_boss = float(style.boss)
	_w_pvp = float(style.pvp)
	_w_shop = float(style.shop)
	_w_rest = float(style.rest)
	_shop_until = int(style.shop_until)
	_rest_hp = int(style.rest_hp)
	_max_dice = int(style.max_dice)
	_spend_renown = bool(style.spend_renown)
	_buy_ratio = float(style.buy_ratio)
	_guard_share = float(style.guard_share)
	_wild = int(style.wild)
	_extra_rerolls = int(style.extra_rerolls)
	_random = bool(style.random)
	for face in Content.basic_die():
		_basic_die_per_roll += face_worth(face) / 6.0


## Events it learns from (all public): see observe().
const OBSERVED: Array[StringName] = [&"reveal", &"boss_hit", &"turn_start"]


## Called with public events, so the bot remembers who keeps their word and who joins boss fights.
func observe(event: Dictionary) -> void:
	match event.get("type"):
		&"reveal":
			var r: Vector2i = record.get(event.pid, Vector2i.ZERO)
			if event.kept:
				r.x += 1
			else:
				r.y += 1
			record[event.pid] = r
		&"boss_hit":
			boss_joins[event.pid] = boss_joins.get(event.pid, 0) + 1
		&"turn_start":
			turns_seen += 1


func decide(view: GameState, me: int, rng: RandomNumberGenerator) -> Array:
	if not view.is_waiting_on(me):
		return []
	var p := view.player(me)
	match view.phase:
		GameState.Phase.ROLL:
			return _roll(p)
		GameState.Phase.DECLARE:
			_prepare(view, p)
			return _declare(view, p, rng)
		GameState.Phase.PLAN:
			_prepare(view, p)
			return _plan(view, p, rng)
		GameState.Phase.RESOLVE:
			return _shop(view, p)
		GameState.Phase.LOOT:
			return [&"pick_loot", [_best_loot(view, rng)]]
		GameState.Phase.BID:
			return [&"bid", [_bid(view, p), 0]]
	return []


func face_worth(face: int) -> float:
	var kind := Face.kind_of(face)
	if kind == Face.Kind.DOUBLE:
		return _face_weight[kind]
	return Face.value_of(face) * _face_weight[kind]


# --- Roll ---------------------------------------------------------------------

func _roll(p: PlayerState) -> Array:
	var allowed := 1 + _extra_rerolls
	if p.rerolls < allowed:
		var cost := p.reroll_cost()
		if cost == 0 or p.roll_totals().cunning >= cost:
			var reroll := PackedInt32Array()
			for i in p.dice.size():
				var total := 0.0
				for face in p.dice[i]:
					total += face_worth(face)
				var face_now := p.dice[i][p.showing[i]]
				# Paid rerolls must not throw away the cunning that pays for them.
				if cost > 0 and Face.kind_of(face_now) == Face.Kind.CUNNING:
					continue
				if face_worth(face_now) < total / p.dice[i].size():
					reroll.append(i)
			if not reroll.is_empty():
				return [&"reroll", [reroll]]
	var wilds := PackedInt32Array()
	for _i in p.wild_count():
		wilds.append(_wild)
	return [&"finish_roll", [wilds]]


# --- Reading the table ------------------------------------------------------------

## Caches every player's attack chance against every other, p's guard for a player attack
## and the leader, so the option values do not recompute them.
func _prepare(view: GameState, p: PlayerState) -> void:
	var n := view.players.size()
	_index.clear()
	for i in n:
		_index[view.players[i].id] = i
	_share.resize(n * n)
	_chance.resize(n * n)
	var weights := PackedFloat64Array()
	weights.resize(n)
	for a in n:
		var attacker := view.players[a]
		var total := 0.0
		for v in n:
			var t := view.players[v]
			weights[v] = 0.0
			if t.id == attacker.id or not t.is_active():
				continue
			weights[v] = 1.0 + 0.15 * view.final_score(t)
			if attacker.combat >= t.hp:
				weights[v] += 2.0
			total += weights[v]
		for v in n:
			_share[a * n + v] = weights[v] / total if total > 0.0 else 0.0
	for a in n:
		for v in n:
			_chance[a * n + v] = _compute_chance(view.players[a], view.players[v])
	_my_pvp_guard = _compute_pvp_guard(view, p)
	_my_leader = _compute_leader(view, p)
	_turns_left_now = _turns_left(view)


## Chance that this player's declaration is a lie, from their public record.
func lie_chance(pid: int) -> float:
	if reads != Reads.SUSPICIOUS:
		return 0.0
	var r: Vector2i = record.get(pid, Vector2i.ZERO)
	return (r.y + 1.0) / (r.x + r.y + 4.0)


## Of the targets `attacker` could pick, the share that would be `victim`: players they
## could knock out and players with a high score draw more fire.
func _target_share(view: GameState, attacker: PlayerState, victim: PlayerState) -> float:
	return _share[_index[attacker.id] * view.players.size() + _index[victim.id]]


## Chance that `o` attacks `victim` this turn, as `victim` would judge it.
func attack_chance(view: GameState, o: PlayerState, victim: PlayerState) -> float:
	return _chance[_index[o.id] * view.players.size() + _index[victim.id]]


func _compute_chance(o: PlayerState, victim: PlayerState) -> float:
	if o.id == victim.id or not o.is_active() or o.combat <= 0:
		return 0.0
	var share := _share[_index[o.id] * _index.size() + _index[victim.id]]
	if not o.declared:
		return UNDECLARED_ATTACK * share
	var lie := lie_chance(o.id)
	if o.intention_action == PlayerState.Action.ATTACK_PLAYER and o.intention_target == victim.id:
		return 1.0 - lie
	return lie * HIDDEN_ATTACK * share


## Points p expects to lose to attacks this turn if it holds `guard` (NAIVE: none).
func _risk(view: GameState, p: PlayerState, guard: int) -> float:
	if reads == Reads.NAIVE:
		return 0.0
	var cost := 0.0
	for o in view.players:
		var chance := attack_chance(view, o, p)
		if chance > 0.0:
			cost += chance * _hit_cost(view, o, p, o.combat - guard)
	return cost


## Combat p expects to be attacked with this turn.
func _incoming(view: GameState, p: PlayerState) -> float:
	var total := 0.0
	for o in view.players:
		total += attack_chance(view, o, p) * o.combat
	return total


func _hit_cost(view: GameState, attacker: PlayerState, t: PlayerState, damage: int) -> float:
	if damage <= 0:
		return 0.0
	var hp_weight := _hp_weight(view)
	var cost := HP_POINTS * damage * hp_weight + STEAL_POINTS * _stolen(attacker, t, damage)
	if damage >= t.hp:
		cost += Content.KO_VICTIM_PENALTY + 0.5 * Content.KO_ATTACKER_SCORE + LOST_TURN_POINTS * hp_weight
	return cost


## How much health still matters: fully until the last few turns, a quarter on the last one.
func _hp_weight(view: GameState) -> float:
	return clampf((_turns_left(view) + 1) / 4.0, 0.25, 1.0)


## Chance that a faster player slays this mob first (a mob falls once per turn): faster players
## who declared it, discounted by their record; undeclared fast players might too.
func _mob_taken(view: GameState, p: PlayerState, slot: int) -> float:
	var mob := Content.mob(view.mobs[slot].id)
	var my_rank := view.initiative.find(p.id)
	var free := 1.0
	for other in view.players:
		if other.id == p.id or not other.is_active() or other.combat < mob.hp:
			continue
		if view.initiative.find(other.id) > my_rank:
			continue
		var chance := 0.3
		if other.declared:
			if other.intention_action == PlayerState.Action.ATTACK_MOB and other.intention_target == slot:
				chance = 1.0 - lie_chance(other.id)
			else:
				chance = lie_chance(other.id) * 0.3
		free *= 1.0 - chance
	return 1.0 - free


## Renown `attacker` steals from `t` with a hit dealing `damage`.
func _stolen(attacker: PlayerState, t: PlayerState, damage: int) -> int:
	return Content.renown_stolen(attacker.renown, t.renown) if damage > 0 else 0


## What `t` will probably guard with against p's attack. `open` means p declared the attack
## on t; otherwise t only guards against p as much as p's record makes it fear an ambush.
func _expected_guard(view: GameState, p: PlayerState, t: PlayerState, open: bool) -> int:
	var guard := t.combat
	if not t.declared:
		guard = ceili(t.combat / 2.0)
	else:
		match t.intention_action:
			PlayerState.Action.ATTACK_PLAYER, PlayerState.Action.ATTACK_BOSS:
				guard = floori(t.combat / 4.0)
			PlayerState.Action.ATTACK_MOB:
				guard = maxi(0, t.combat - Content.mob(view.mobs[t.intention_target].id).hp)
	if reads == Reads.NAIVE:
		return guard + t.guard_bonus
	# A worried target holds back more of its combat, or gives up its plan to guard.
	var calm := 1.0
	for o in view.players:
		if o.id == t.id:
			continue
		var chance := attack_chance(view, o, t)
		if o.id == p.id:
			chance = 1.0 if open else lie_chance(p.id) * HIDDEN_ATTACK * _target_share(view, p, t)
		calm *= 1.0 - clampf(chance, 0.0, 1.0)
	return guard + roundi((t.combat - guard) * (1.0 - calm)) + t.guard_bonus


## Guard the deciding player keeps back when it attacks a player.
func _pvp_guard() -> int:
	return _my_pvp_guard


func _compute_pvp_guard(view: GameState, p: PlayerState) -> int:
	if reads == Reads.NAIVE:
		return mini(_threat_against(view, p.id), floori(p.combat * _guard_share))
	return clampi(roundi(_incoming(view, p)), 0, maxi(0, p.combat - 1))


func _pvp_value(view: GameState, p: PlayerState, t: PlayerState, open: bool) -> float:
	var attack := p.combat - _pvp_guard()
	var damage := attack - _expected_guard(view, p, t, open)
	var w_pvp := _w_pvp
	if attack <= 0 or damage <= 0:
		return -0.1
	var value := STEAL_POINTS * _stolen(p, t, damage)
	# Hurting the leader helps; hurting someone far behind only helps the leader.
	var focus := 1.0
	if t.id == _my_leader:
		focus = 2.0 if _turns_left(view) < ENDGAME_TURNS else 1.4
	elif view.final_score(t) + 3 <= view.final_score(p):
		focus = 0.5
	if damage >= t.hp:
		return value + w_pvp * focus * (Content.KO_ATTACKER_SCORE + 0.5 * Content.KO_VICTIM_PENALTY + 0.5 * _hp_weight(view))
	return value + w_pvp * focus * 0.12 * damage


## Renown at stake when p keeps (or breaks) its word this turn. A kept word moves the oath on;
## a broken one throws away the steps already taken, so the stake is the oath's share for every
## step up to this one; the completing step is worth the whole oath. An oath that can no longer
## complete before the game ends is worth nothing.
func _honesty_renown(p: PlayerState, _action: int) -> float:
	var renown := float(Content.OATH_RENOWN)
	for trinket_id in p.trinkets:
		renown += Content.trinket(trinket_id).honesty_bonus()
	var steps := Content.OATH_LENGTH - p.oath
	if steps > _turns_left_now + 1:
		return 0.0
	if steps == 1:
		return renown
	return renown * (p.oath + 1) / Content.OATH_LENGTH


# --- Declare and plan ------------------------------------------------------------

func _declare(view: GameState, p: PlayerState, rng: RandomNumberGenerator) -> Array:
	var options := _options(view, p)
	if _random:
		var pick: Array = options[rng.randi_range(0, options.size() - 1)]
		return [&"declare", [pick[0], pick[1]]]
	var best: Array = options[0]
	var sincere := rng.randf() < _honesty
	if sincere and _word_value < 50.0 and _w_pvp > 0.0:
		# Would an ambush behind a decoy beat the best honest plan plus its renown?
		var guard := _pvp_guard()
		var honest_value := float(best[2]) + _honesty_renown(p, best[0]) + _word_value
		for t in view.players:
			if t.id == p.id or not t.is_active():
				continue
			var ambush := _pvp_value(view, p, t, false) - _rep_cost - _risk(view, p, guard)
			if ambush > honest_value:
				sincere = false
				break
	if sincere and _bluff > 0.0 and _my_leader != 0 and view.player(_my_leader).is_active() \
			and best[0] != PlayerState.Action.ATTACK_PLAYER \
			and _honesty_renown(p, best[0]) < 0.4 and rng.randf() < _bluff:
		# A bluff: threaten the leader so they spend their combat guarding instead of scoring.
		return [&"declare", [PlayerState.Action.ATTACK_PLAYER, _my_leader]]
	if sincere or options.size() == 1:
		return [&"declare", [best[0], best[1]]]
	# A believable decoy: the best plan that does not threaten anyone.
	for option: Array in options:
		if option[0] != PlayerState.Action.ATTACK_PLAYER and (option[0] != best[0] or option[1] != best[1]):
			return [&"declare", [option[0], option[1]]]
	var other: Array = options[1]
	return [&"declare", [other[0], other[1]]]


func _plan(view: GameState, p: PlayerState, rng: RandomNumberGenerator) -> Array:
	var options := _options(view, p)
	var choice: Array = options[0]
	if _random:
		choice = options[rng.randi_range(0, options.size() - 1)]
	else:
		# Breaking the word costs the renown and some credibility.
		var keep_bonus := _honesty_renown(p, p.intention_action) + _word_value + _rep_cost
		for option: Array in options:
			if option[0] == p.intention_action and option[1] == p.intention_target:
				if float(option[2]) + keep_bonus >= float(choice[2]):
					choice = option
				break
	var action: int = choice[0]
	var target: int = choice[1]
	var combat := p.combat
	var attack := 0
	var guard := combat
	match action:
		PlayerState.Action.ATTACK_MOB:
			attack = mini(combat, Content.mob(view.mobs[target].id).hp)
			guard = combat - attack
		PlayerState.Action.ATTACK_BOSS:
			guard = mini(_threat_against(view, p.id), floori(combat * _guard_share))
			guard = maxi(guard, mini(_boss_spare(view, p), view.boss().damage))
			attack = combat - guard
		PlayerState.Action.ATTACK_PLAYER:
			guard = _pvp_guard()
			attack = combat - guard
	return [&"lock_plan", [action, target, attack, guard]]


## Combat p can hold back from a boss attack that the declared attackers still finish, while
## still dealing the share that scores.
func _boss_spare(view: GameState, p: PlayerState) -> int:
	var others := roundi(_boss_power(view, p)) - p.combat
	var share := Content.boss_loot_threshold(view.boss_max_hp)
	return maxi(0, p.combat - maxi(share, view.boss_hp - others))


## Every legal choice as [action, target, value in points], best first. Each value already
## counts the damage p expects to take with the guard that choice leaves it.
func _options(view: GameState, p: PlayerState) -> Array:
	var options: Array = []
	var combat := p.combat
	var bonus := p.guard_bonus
	var left := float(view.max_turns - view.turn) / view.max_turns
	var w_mob := _w_mob
	var w_boss := _w_boss

	for slot in view.mobs.size():
		var mob := Content.mob(view.mobs[slot].id)
		if mob == null or w_mob <= 0.0:
			continue
		var value := -0.15 * mob.damage - _risk(view, p, bonus)
		if combat >= mob.hp:
			var kill := w_mob * (Content.mob_score(mob) + TRINKET_POINTS * left + 0.05 * mob.tier)
			value = kill * (1.0 - _mob_taken(view, p, slot)) - _risk(view, p, combat - mob.hp + bonus)
		options.append([PlayerState.Action.ATTACK_MOB, slot, value])

	var boss_value := -0.2 * view.boss().damage if w_boss > 0.0 else -9.0
	var share := Content.boss_loot_threshold(view.boss_max_hp)
	var win := Content.BOSS_KILL_SCORE + 0.5 * BOSS_ITEM_POINTS * left
	if combat >= share and _boss_power(view, p) >= view.boss_hp:
		boss_value = w_boss * win
	elif view.phase == GameState.Phase.DECLARE and combat >= share:
		# Propose a boss fight when the players still to declare are likely to finish it.
		var expected := _boss_power(view, p) + _likely_joiners(view, p)
		if expected >= view.boss_hp:
			boss_value = w_boss * win * clampf(view.boss_hp / maxf(expected, 1.0), 0.4, 0.8)
	options.append([PlayerState.Action.ATTACK_BOSS, 0, boss_value - _risk(view, p, _boss_spare(view, p) + bonus)])

	if _w_pvp > 0.0:
		var guard := _pvp_guard()
		var risk := _risk(view, p, guard + bonus)
		for other in view.players:
			if other.id == p.id or not other.is_active():
				continue
			# Declaring: the value of attacking openly. Planning: open only if it was declared.
			var open := view.phase == GameState.Phase.DECLARE or (p.intention_action == PlayerState.Action.ATTACK_PLAYER and p.intention_target == other.id)
			options.append([PlayerState.Action.ATTACK_PLAYER, other.id, _pvp_value(view, p, other, open) - risk])

	var full_guard := _risk(view, p, combat + bonus)
	var w_shop := _w_shop if view.turn <= _shop_until else _w_shop / 3.0
	options.append([PlayerState.Action.SHOP, 0, w_shop * _shop_units(view, p) / UNITS_PER_POINT - full_guard])

	var healable := mini(Content.REST_HEAL, p.max_hp - p.hp)
	var rest_value := _w_rest * healable * (0.5 if p.hp <= _rest_hp else 0.05)
	options.append([PlayerState.Action.REST, 0, rest_value - full_guard])

	options.sort_custom(func(a: Array, b: Array) -> bool: return a[2] > b[2])
	return options


## p's combat plus what the declared boss attackers will probably bring, each trusted as far
## as their record of keeping their word.
func _boss_power(view: GameState, p: PlayerState) -> float:
	var power := float(p.combat)
	for other in view.players:
		if other.id != p.id and other.is_active() and other.declared and other.intention_action == PlayerState.Action.ATTACK_BOSS:
			power += other.combat * (1.0 - lie_chance(other.id))
	return power


## Combat the players who have not declared yet will probably add, from how often each has
## joined boss fights so far.
func _likely_joiners(view: GameState, p: PlayerState) -> float:
	var power := 0.0
	for other in view.players:
		if other.id == p.id or not other.is_active() or other.declared:
			continue
		var join: float = (boss_joins.get(other.id, 0) + 0.5) / (turns_seen + 3.0)
		power += other.combat * clampf(join, 0.0, 0.8)
	return power


## The rival with the highest score if they lead this player by 2 or more, else 0.
func _compute_leader(view: GameState, p: PlayerState) -> int:
	var leader := 0
	var best := view.final_score(p) + 1
	for other in view.players:
		if other.id != p.id and view.final_score(other) > best:
			best = view.final_score(other)
			leader = other.id
	return leader


func _threat_against(view: GameState, id: int) -> int:
	var threat := 0
	for other in view.players:
		if other.id != id and other.declared and other.intention_action == PlayerState.Action.ATTACK_PLAYER and other.intention_target == id:
			threat += other.combat
	return threat


# --- Shop -----------------------------------------------------------------------

## Turns left in which something bought now will be rolled.
func _turns_left(view: GameState) -> int:
	return view.max_turns - view.turn


func _budget(p: PlayerState) -> int:
	return p.gold + (p.renown * Content.RENOWN_GOLD if _spend_renown else 0)


## Resource units the best affordable purchases would add over the rest of the game.
func _shop_units(view: GameState, p: PlayerState) -> float:
	var budget := _budget(p)
	var total := 0.0
	var dice := p.dice.size()
	var bought := {}
	while true:
		var best := _best_purchase(view, p, budget, bought, dice)
		if best.is_empty():
			break
		total += float(best.units)
		budget -= int(best.price)
		if best.slot == -1:
			dice += 1
			bought[-1] = true
		elif best.slot >= 0:
			bought[best.slot] = true
	return total


## The best purchase by units per gold: {"slot", "die", "face", "units", "price"}; slot is a
## market slot, or -1 for the die, -2 for renown, -3 to upgrade the die's face.
func _best_purchase(view: GameState, p: PlayerState, budget: int, skip: Dictionary, dice: int) -> Dictionary:
	var turns := _turns_left(view)
	var best := {}
	var best_ratio := _buy_ratio
	var low_die := 0
	var low_face := 0
	var low_worth := INF
	for d in p.dice.size():
		for f in p.dice[d].size():
			var worth := face_worth(p.dice[d][f])
			if worth < low_worth:
				low_worth = worth
				low_die = d
				low_face = f
	for slot in view.market.size():
		var face := view.market[slot]
		if face == 0 or skip.has(slot):
			continue
		var price := p.price(_price(face))
		if price > budget:
			continue
		var units := (face_worth(face) - low_worth) * turns / 6.0
		if units / price > best_ratio:
			best_ratio = units / price
			best = {"slot": slot, "die": low_die, "face": low_face, "units": units, "price": price}
	var die_price := p.price(Content.DIE_PRICE)
	if view.market_die and not skip.has(-1) and dice < _max_dice and die_price <= budget:
		var units := _basic_die_per_roll * turns
		if units / die_price > best_ratio:
			best_ratio = units / die_price
			best = {"slot": -1, "die": 0, "face": 0, "units": units, "price": die_price}
	for d in p.dice.size():
		for f in p.dice[d].size():
			var face := p.dice[d][f]
			var price := p.price(_upgrade_price(face))
			if price == 0 or price > budget:
				continue
			var units := (face_worth(Face.make(Face.kind_of(face), Face.value_of(face) + 1)) - face_worth(face)) * turns / 6.0
			if units / price > best_ratio:
				best_ratio = units / price
				best = {"slot": -3, "die": d, "face": f, "units": units, "price": price}
	# Renown is a point for 5 gold, paid in gold only.
	if p.gold >= Content.RENOWN_PRICE and budget >= Content.RENOWN_PRICE and UNITS_PER_POINT / Content.RENOWN_PRICE > best_ratio:
		best = {"slot": -2, "die": 0, "face": 0, "units": UNITS_PER_POINT, "price": Content.RENOWN_PRICE}
	return best


func _upgrade_price(face: int) -> int:
	if not _upgrades.has(face):
		_upgrades[face] = Content.upgrade_price(face)
	return _upgrades[face]


func _price(face: int) -> int:
	if not _prices.has(face):
		_prices[face] = Content.face_price(face)
	return _prices[face]


func _shop(view: GameState, p: PlayerState) -> Array:
	if view.shopping != p.id:
		return []
	var best := _best_purchase(view, p, _budget(p), {}, p.dice.size())
	if best.is_empty():
		# Nothing worth buying: look at a fresh row once, while it can still pay off.
		if not view.refreshed and p.gold >= Content.REFRESH_PRICE + 2 and _turns_left(view) >= 3:
			return [&"refresh_market", [0]]
		return [&"finish_shop", []]
	var renown := ceili(maxi(0, int(best.price) - p.gold) / float(Content.RENOWN_GOLD))
	match int(best.slot):
		-1:
			return [&"buy_die", [renown]]
		-2:
			return [&"buy_renown", []]
		-3:
			return [&"upgrade_face", [best.die, best.face, renown]]
	return [&"buy_face", [best.slot, best.die, best.face, renown]]


## Bids gold up to what the item is worth to it (points at 3.5 gold each), less late in the game.
func _bid(view: GameState, p: PlayerState) -> int:
	if _random:
		return floori(p.gold / 2.0)
	var left := float(view.max_turns - view.turn) / view.max_turns
	var worth := float(TRINKET_WORTH.get(view.auction_item, 0.8)) * UNITS_PER_POINT * (0.3 + left)
	return clampi(roundi(worth), 0, p.gold)


func _best_loot(view: GameState, rng: RandomNumberGenerator) -> int:
	if _random:
		return rng.randi_range(0, view.loot.size() - 1)
	var best := 0
	for i in view.loot.size():
		if float(TRINKET_WORTH.get(view.loot[i], 0.5)) > float(TRINKET_WORTH.get(view.loot[best], 0.5)):
			best = i
	return best
