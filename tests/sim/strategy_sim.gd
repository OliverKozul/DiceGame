extends SceneTree
## Strategy simulator: plays bot games where each seat has a play style (see
## strategy_bot.gd; "baseline" is the shipping BotBrain) and writes one JSON line per game
## with every player's score breakdown. tools/strategy_sim.py runs it in parallel and
## analyses the results.
##   godot --headless --path . --script res://tests/sim/strategy_sim.gd -- \
##       --mode=mixed|field|mirror --games=N --start=SEED --out=FILE [--pool=a,b] [--hero=X] [--field=Y]
##       [--seats=3-6] [--reads=naive|gullible|suspicious]
## mixed: every seat draws a style from the pool. field: one hero seat, the rest play the
## field style. mirror: every seat plays the hero style.

const StrategyBot := preload("res://tests/sim/strategy_bot.gd")
const BASELINE := "baseline"
const READS: Dictionary = {
	"naive": StrategyBot.Reads.NAIVE, "gullible": StrategyBot.Reads.GULLIBLE, "suspicious": StrategyBot.Reads.SUSPICIOUS,
}

var _exit_code := -1
var _reads: StrategyBot.Reads = StrategyBot.Reads.NAIVE


func _init() -> void:
	var opts := _parse_args()
	var mode: String = opts.get("mode", "mixed")
	var games := int(opts.get("games", "100"))
	var start := int(opts.get("start", "0"))
	var pool: PackedStringArray = String(opts.get("pool", "baseline,honest,rational,liar,opportunist,farmer,warlord,builder,boss_hunter,turtle,miser,schemer")).split(",")
	var hero: String = opts.get("hero", "honest")
	var field: String = opts.get("field", BASELINE)
	var seat_range: PackedStringArray = String(opts.get("seats", "3-6")).split("-")
	var min_seats := int(seat_range[0])
	var max_seats := int(seat_range[seat_range.size() - 1])
	var reads_name: String = opts.get("reads", "naive")
	if not READS.has(reads_name):
		printerr("unknown --reads: " + reads_name)
		_exit_code = 1
		return
	_reads = READS[reads_name]
	var out := FileAccess.open(opts.get("out", "user://strategy_sim.jsonl"), FileAccess.WRITE)
	if out == null:
		printerr("cannot open output file")
		_exit_code = 1
		return
	for style in pool + PackedStringArray([hero, field]):
		if style != BASELINE and not StrategyBot.STYLES.has(style):
			printerr("unknown style: " + style)
			_exit_code = 1
			return

	for g in games:
		var seed_value := start + g
		var pick := RandomNumberGenerator.new()
		pick.seed = seed_value * 7919 + 17
		var seats := pick.randi_range(min_seats, max_seats)
		var styles: Array[String] = []
		match mode:
			"field":
				var hero_seat := pick.randi_range(0, seats - 1)
				for i in seats:
					styles.append(hero if i == hero_seat else field)
			"mirror":
				for i in seats:
					styles.append(hero)
			_:
				for i in seats:
					styles.append(pool[pick.randi_range(0, pool.size() - 1)])
		var record := _play(seed_value, styles)
		if record.is_empty():
			_exit_code = 1
			return
		record["mode"] = mode
		record["reads"] = reads_name
		out.store_line(JSON.stringify(record))
	out.close()
	_exit_code = 0


func _process(_delta: float) -> bool:
	if _exit_code >= 0:
		Content.clear_cache()
		root.get_node("Transition").call("quit_game", _exit_code)
		_exit_code = -1
	return false


func _parse_args() -> Dictionary:
	var opts := {}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--"):
			var parts := arg.substr(2).split("=", true, 1)
			opts[parts[0]] = parts[1] if parts.size() > 1 else "true"
	return opts


func _blank_stats(style: String, seat: int) -> Dictionary:
	return {
		"style": style, "seat": seat, "mob_kills": 0, "mob_fails": 0, "boss_kills": 0, "boss_attempts": 0,
		"kos_dealt": 0, "kos_taken": 0, "ko_by_enemy": 0, "kept": 0, "broke": 0, "honesty_renown": 0, "face_renown": 0,
		"pvp_attacks": 0, "pvp_damage": 0, "damage_taken": 0, "renown_stolen": 0, "renown_lost": 0, "shops": 0, "rests": 0,
		"upgrades": 0, "renown_bought": 0, "refreshes": 0, "loot_picks": 0, "auctions_won": 0, "renown_spent": 0,
		"faces_bought": 0, "dice_bought": 0, "gold_earned": 0, "combat_rolled": 0, "cunning_rolled": 0,
		"initiative_rank": 0.0, "turns_active": 0, "bought": {}, "lied_attacks": 0, "lied_attack_damage": 0,
		"min_hp": Content.STARTING_HP, "mob_kills_by_tier": [0, 0, 0],
	}


## Plays one game and returns its record, or {} if a bot got stuck.
func _play(seed_value: int, styles: Array[String]) -> Dictionary:
	var roster: Array[Dictionary] = []
	var bots: Dictionary = {}
	var stats: Dictionary = {}
	for i in styles.size():
		var pid := 100 + i
		roster.append({"id": pid, "name": "%s%d" % [styles[i], i], "bot": true})
		if styles[i] != BASELINE:
			bots[pid] = StrategyBot.new(styles[i], _reads)
		stats[pid] = _blank_stats(styles[i], i)
	var rules := GameRules.new()
	rules.setup(roster, seed_value)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 104729 + 3
	var last := 0
	var steps := 0
	var game := {"boss_kills": [], "boss_reached": 0}
	while rules.state.phase != GameState.Phase.GAME_OVER:
		var live := rules.state
		var pid := live.waiting_on()[0]
		var view := GameState.from_view(live.to_view(pid))
		var request: Array = bots[pid].decide(view, pid, rng) if bots.has(pid) else BotBrain.decide(view, pid, rng)
		if request.is_empty():
			printerr("seed %d: %s had no move in phase %d" % [seed_value, styles[pid - 100], live.phase])
			return {}
		var err := rules.apply(pid, request[0], request[1])
		if not err.is_empty():
			printerr("seed %d: %s request %s %s refused: %s" % [seed_value, styles[pid - 100], request[0], request[1], Loc.text(err)])
			return {}
		for e in rules.events_since(last):
			last = e.seq
			_count(rules.state, stats, game, e)
			if StrategyBot.OBSERVED.has(e.type):
				for bot: Variant in bots.values():
					bot.observe(e)
		for p in rules.state.players:
			if p.hp < int(stats[p.id].min_hp):
				stats[p.id].min_hp = p.hp
		steps += 1
		if steps > 50000:
			printerr("seed %d: game did not finish" % seed_value)
			return {}

	var s := rules.state
	var players: Array = []
	for p in s.players:
		var st: Dictionary = stats[p.id]
		st["rank"] = s.standings.find(p.id)
		st["final"] = s.final_score(p)
		st["score"] = p.score
		st["renown"] = p.renown
		st["hp"] = p.hp
		st["gold"] = p.gold
		st["dice"] = p.dice.size()
		st["trinkets"] = p.trinkets.map(func(t: StringName) -> String: return str(t))
		st["initiative_rank"] = float(st.initiative_rank) / maxi(int(st.turns_active), 1)
		var kinds := {}
		for die in p.dice:
			for face in die:
				var key := str(Face.NAMES[Face.kind_of(face)])
				kinds[key] = int(kinds.get(key, 0)) + 1
		st["final_faces"] = kinds
		players.append(st)
	return {"seed": seed_value, "seats": s.players.size(), "players": players, "boss_kills": game.boss_kills}


func _count(s: GameState, stats: Dictionary, game: Dictionary, e: Dictionary) -> void:
	var type := str(e.type)
	if type == "boss_reward":
		for pid: int in e.pids:
			stats[pid].boss_kills += 1
		var damage := {}
		for pid: int in s.boss_damage:
			damage[str(stats[pid].style)] = int(damage.get(str(stats[pid].style), 0)) + s.boss_damage[pid]
		game.boss_kills.append({"turn": s.turn, "boss": str(s.boss_id), "hp": s.boss_max_hp,
			"attackers": s.boss_damage.size(), "dealers": e.pids.size(),
			"damages": s.boss_damage.values(), "threshold": Content.boss_loot_threshold(s.boss_max_hp)})
		return
	if type == "initiative":
		var order: Array = e.order
		for i in order.size():
			var seat_stats: Dictionary = stats[order[i]]
			seat_stats.initiative_rank += float(i) / maxi(order.size() - 1, 1)
			seat_stats.turns_active += 1
		return
	if not e.has("pid"):
		return
	var st: Dictionary = stats[e.pid]
	match type:
		"kept":
			st.gold_earned += e.gold
			st.combat_rolled += e.combat
			st.cunning_rolled += e.cunning
			st.face_renown += e.renown
		"reveal":
			var p := s.player(e.pid)
			if e.kept:
				st.kept += 1
				st.honesty_renown += e.renown
			else:
				st.broke += 1
				if p.plan_action == PlayerState.Action.ATTACK_PLAYER:
					st.lied_attacks += 1
			match p.plan_action:
				PlayerState.Action.SHOP:
					st.shops += 1
				PlayerState.Action.REST:
					st.rests += 1
				PlayerState.Action.ATTACK_BOSS:
					st.boss_attempts += 1
		"attack":
			st.pvp_attacks += 1
			st.pvp_damage += e.damage
			stats[e.target].damage_taken += e.damage
			if not s.player(e.pid).kept_word:
				st.lied_attack_damage += e.damage
		"mob_kill":
			st.mob_kills += 1
			var tier: int = Content.mob(s.mobs[e.slot].id).tier
			st.mob_kills_by_tier[tier - 1] += 1
		"mob_fail":
			st.mob_fails += 1
			st.damage_taken += e.damage
		"boss_strike":
			st.damage_taken += e.damage
		"knockout":
			st.kos_taken += 1
			if int(e.by) > 0:
				st.ko_by_enemy += 1
				stats[e.by].kos_dealt += 1
		"steal":
			if e.what == "renown":
				st.renown_stolen += e.amount
				stats[e.target].renown_lost += e.amount
		"upgrade":
			st.upgrades += 1
		"buy_renown":
			st.renown_bought += 1
		"refresh":
			st.refreshes += 1
		"loot_taken":
			st.loot_picks += 1
		"auction_won":
			st.auctions_won += 1
		"buy_face":
			st.faces_bought += 1
			var key := "%s %d" % [Face.NAMES[Face.kind_of(e.face)], Face.value_of(e.face)]
			st.bought[key] = int(st.bought.get(key, 0)) + 1
		"buy_die":
			st.dice_bought += 1
