class_name GameState
extends RefCounted
## The public table. The host keeps the authoritative copy inside GameRules and sends each
## peer a view of it (to_view) that hides what that player could not see at a real table.

enum Phase { SETUP, ROLL, DECLARE, PLAN, RESOLVE, LOOT, BID, GAME_OVER }

const PHASE_NAMES: Dictionary = {
	Phase.SETUP: "Setup",
	Phase.ROLL: "Roll",
	Phase.DECLARE: "Declare",
	Phase.PLAN: "Plan",
	Phase.RESOLVE: "Resolve",
	Phase.LOOT: "Loot",
	Phase.BID: "Auction",
	Phase.GAME_OVER: "Game over",
}

const LOG_LIMIT := 80

var turn: int = 0
var max_turns: int = Content.MAX_TURNS
var phase: Phase = Phase.SETUP
var players: Array[PlayerState] = []
## Seat holding the first-player token; it breaks initiative ties and passes left each turn.
var first_seat: int = 0
## Active player ids, highest initiative first. Declare runs backwards, resolve forwards.
var initiative: Array[int] = []
## Position in the declare or resolve sequence.
var cursor: int = 0
## The player whose shopping the resolution is waiting on, or 0.
var shopping: int = 0

## Mob slots: {"id": StringName, "killed": bool}; id is &"" when the slot is empty.
var mobs: Array[Dictionary] = []
var boss_id: StringName = &""
var boss_hp: int = 0
var boss_max_hp: int = 0
## Damage dealt to the boss this turn by each attacker.
var boss_damage: Dictionary[int, int] = {}

var market: PackedInt32Array = PackedInt32Array()
var market_die: bool = true

## Boss loot on offer; loot_waiting holds who still has to pick.
var loot: Array[StringName] = []
var loot_eligible: Array[int] = []
var loot_waiting: Array[int] = []
## One auction per contested item: {"item": int, "bidders": Array[int]}.
var auctions: Array[Dictionary] = []
var bid_waiting: Array[int] = []

var log_lines: Array[String] = []
## Final ranking, best first: ids.
var standings: Array[int] = []


func player(id: int) -> PlayerState:
	for p in players:
		if p.id == id:
			return p
	return null


func active_ids() -> Array[int]:
	var ids: Array[int] = []
	for p in players:
		if p.is_active():
			ids.append(p.id)
	return ids


func boss() -> Boss:
	return Content.boss(boss_id)


func boss_alive() -> bool:
	return boss_hp > 0


## Declare order: lowest initiative first.
func declare_order() -> Array[int]:
	var order := initiative.duplicate()
	order.reverse()
	return order


## The one player the table is waiting on in a sequential step, or 0.
func current_actor() -> int:
	match phase:
		Phase.DECLARE:
			var order := declare_order()
			return order[cursor] if cursor < order.size() else 0
		Phase.RESOLVE:
			return initiative[cursor] if cursor < initiative.size() else 0
	return 0


## Everyone the game is currently waiting on.
func waiting_on() -> Array[int]:
	var ids: Array[int] = []
	match phase:
		Phase.ROLL:
			for p in players:
				if p.is_active() and not p.roll_done:
					ids.append(p.id)
		Phase.DECLARE:
			var actor := current_actor()
			if actor != 0:
				ids.append(actor)
		Phase.RESOLVE:
			if shopping != 0:
				ids.append(shopping)
		Phase.PLAN:
			for p in players:
				if p.is_active() and not p.plan_locked:
					ids.append(p.id)
		Phase.LOOT:
			ids.assign(loot_waiting)
		Phase.BID:
			ids.assign(bid_waiting)
	return ids


func is_waiting_on(id: int) -> bool:
	return waiting_on().has(id)


## Players whose plans everyone may see: after the reveal, and always your own.
func plans_public() -> bool:
	return phase in [Phase.RESOLVE, Phase.LOOT, Phase.BID, Phase.GAME_OVER]


static func is_attack(action: int) -> bool:
	return action in [PlayerState.Action.ATTACK_PLAYER, PlayerState.Action.ATTACK_MOB, PlayerState.Action.ATTACK_BOSS]


static func needs_target(action: int) -> bool:
	return action in [PlayerState.Action.ATTACK_PLAYER, PlayerState.Action.ATTACK_MOB]


func describe_choice(action: int, target: int) -> String:
	match action:
		PlayerState.Action.ATTACK_PLAYER:
			var t := player(target)
			return "Attack %s" % (t.name if t else "?")
		PlayerState.Action.ATTACK_MOB:
			if target >= 0 and target < mobs.size() and mobs[target].id != &"":
				return "Attack %s" % Content.mob(mobs[target].id).display_name
			return "Attack a mob"
		PlayerState.Action.ATTACK_BOSS:
			return "Attack the boss"
		PlayerState.Action.SHOP:
			return "Shop"
		PlayerState.Action.REST:
			return "Rest"
	return "Nothing"


func describe_plan(p: PlayerState) -> String:
	var parts := PackedStringArray()
	if p.plan_attack > 0:
		parts.append("⚔%d" % p.plan_attack)
	if p.plan_guard + p.guard_bonus > 0:
		parts.append("🛡%d" % (p.plan_guard + p.guard_bonus))
	for target_id in p.plan_sabotage:
		var t := player(target_id)
		parts.append("sabotage %s %d" % [t.name if t else "?", p.plan_sabotage[target_id]])
	var text := describe_choice(p.plan_action, p.plan_target)
	if not parts.is_empty():
		text += " (%s)" % ", ".join(parts)
	return text


func names_of(ids: Array[int]) -> String:
	var names := PackedStringArray()
	for id in ids:
		var p := player(id)
		names.append(p.name if p else "?")
	return ", ".join(names)


func auction_for(id: int) -> Dictionary:
	for auction in auctions:
		if (auction.bidders as Array).has(id):
			return auction
	return {}


func final_score(p: PlayerState) -> int:
	return p.score + p.renown


func to_view(viewer: int) -> Dictionary:
	var player_dicts: Array[Dictionary] = []
	for p in players:
		player_dicts.append(p.to_dict(plans_public() or p.id == viewer))
	return {
		"viewer": viewer,
		"turn": turn,
		"max_turns": max_turns,
		"phase": phase,
		"players": player_dicts,
		"first_seat": first_seat,
		"initiative": initiative.duplicate(),
		"cursor": cursor,
		"shopping": shopping,
		"mobs": mobs.duplicate(true),
		"boss_id": boss_id,
		"boss_hp": boss_hp,
		"boss_max_hp": boss_max_hp,
		"boss_damage": boss_damage.duplicate(),
		"market": market,
		"market_die": market_die,
		"loot": loot.duplicate(),
		"loot_eligible": loot_eligible.duplicate(),
		"loot_waiting": loot_waiting.duplicate(),
		"auctions": auctions.duplicate(true),
		"bid_waiting": bid_waiting.duplicate(),
		"log": log_lines.duplicate(),
		"standings": standings.duplicate(),
	}


static func from_view(d: Dictionary) -> GameState:
	var s := GameState.new()
	s.turn = d.turn
	s.max_turns = d.max_turns
	s.phase = d.phase
	for pd: Dictionary in d.players:
		s.players.append(PlayerState.from_dict(pd))
	s.first_seat = d.first_seat
	s.initiative.assign(d.initiative)
	s.cursor = d.cursor
	s.shopping = d.shopping
	s.mobs.assign(d.mobs)
	s.boss_id = d.boss_id
	s.boss_hp = d.boss_hp
	s.boss_max_hp = d.boss_max_hp
	s.boss_damage.assign(d.boss_damage)
	s.market = d.market
	s.market_die = d.market_die
	s.loot.assign(d.loot)
	s.loot_eligible.assign(d.loot_eligible)
	s.loot_waiting.assign(d.loot_waiting)
	s.auctions.assign(d.auctions)
	s.bid_waiting.assign(d.bid_waiting)
	s.log_lines.assign(d.log)
	s.standings.assign(d.standings)
	return s
