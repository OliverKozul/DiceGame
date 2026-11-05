class_name GameRecap
extends RefCounted
## The story of one game, for the end screen and the achievements. The rules feed it every
## event as it happens; it uses no randomness and changes nothing, so it cannot affect the game.
## Everything here is public by the time it is shown, when the game is over.

## The titles handed out at the end: [id, the stat that earns it]. Whoever has the most of the
## stat holds the title, ties share it, and nobody holds it for a stat of zero.
const AWARDS: Array = [
	[&"traitor", "broke"],
	[&"honest", "kept"],
	[&"backstabber", "ambush_damage"],
	[&"monster_hunter", "mobs"],
	[&"dragonslayer", "bosses"],
	[&"brawler", "kos"],
	[&"thief", "stolen"],
	[&"merchant", "purchases"],
	[&"punching_bag", "damage_taken"],
]

var _players: Dictionary = {}
var _humans := 0
## The ambush that hurt most: {"turn", "pid", "target", "damage", "said"}.
var _betrayal: Dictionary = {}


func _init(players: Array[PlayerState]) -> void:
	for p in players:
		_players[p.id] = {
			"kept": 0, "broke": 0, "oaths": 0, "ambush_damage": 0, "ambush_kos": 0, "damage_taken": 0,
			"kos": 0, "knocked_out": 0, "mobs": 0, "bosses": 0, "last_stage_bosses": 0, "stolen": 0,
			"purchases": 0, "auctions": 0,
		}
		if not p.is_bot:
			_humans += 1


func observe(event: Dictionary, state: GameState) -> void:
	match event.type:
		&"reveal":
			var stats: Dictionary = _players[event.pid]
			stats[&"kept" if event.kept else &"broke"] += 1
			if event.renown > 0:
				stats.oaths += 1
		&"attack":
			_players[event.target].damage_taken += event.damage
			var attacker := state.player(event.pid)
			if not attacker.kept_word and event.damage > 0:
				_players[event.pid].ambush_damage += event.damage
				if event.damage > int(_betrayal.get("damage", 0)):
					_betrayal = {"turn": state.turn, "pid": event.pid, "target": event.target, "damage": event.damage,
						"said": state.choice_message(attacker.intention_action, attacker.intention_target)}
		&"mob_fail", &"boss_strike":
			_players[event.pid].damage_taken += event.damage
		&"mob_kill":
			_players[event.pid].mobs += 1
		&"boss_reward":
			var last_stage := state.boss().stage >= Content.BOSS_STAGES
			for pid: int in event.pids:
				_players[pid].bosses += 1
				if last_stage:
					_players[pid].last_stage_bosses += 1
		&"knockout":
			_players[event.pid].knocked_out += 1
			var attacker := state.player(event.by)
			if attacker:
				_players[event.by].kos += 1
				if not attacker.kept_word and attacker.plan_action == PlayerState.Action.ATTACK_PLAYER:
					_players[event.by].ambush_kos += 1
		&"steal":
			if event.what == "renown":
				_players[event.pid].stolen += event.amount
		&"buy_face", &"upgrade", &"buy_die":
			_players[event.pid].purchases += 1
		&"auction_won":
			_players[event.pid].auctions += 1


## {"players": {pid: stats}, "awards": [{"id", "pids", "value"}], "betrayal": {}, "humans": int}.
func to_dict() -> Dictionary:
	return {"players": _players.duplicate(true), "awards": _awards(), "betrayal": _betrayal.duplicate(true), "humans": _humans}


func _awards() -> Array:
	var awards := []
	for entry: Array in AWARDS:
		var best := 0
		var pids: Array[int] = []
		for pid: int in _players:
			var value: int = _players[pid][entry[1]]
			if value > best:
				best = value
				pids = [pid]
			elif value == best and best > 0:
				pids.append(pid)
		if best > 0:
			awards.append({"id": entry[0], "pids": pids, "value": best})
	return awards
