extends SceneTree
## Plays many complete bot games straight through GameRules (no networking) and checks
## invariants after every request. Also checks determinism, view round-trips, hidden
## information, that bad requests are refused, every trinket effect, and that every Chronicle
## message of those games is translated into every language with the same placeholders.
##   godot --headless --path . --script res://tests/test_rules.gd -- [games]

var failures := 0
var _exit_code := -1
## Every event type seen in any game, to check the presentation layer gets them all.
var event_types := {}
## Every Chronicle msgid seen in any game (the dynamic list messages excluded).
var message_keys := {}
var _placeholder := RegEx.create_from_string("\\{([a-z_0-9]+)\\}")
const CORE_EVENTS: Array[String] = ["turn_start", "reroll", "kept", "initiative", "declare", "locked", "reveal",
	"steal", "attack", "mob_kill", "mob_fail", "boss_hit", "boss_slain", "boss_strike", "rest", "knockout",
	"trinket", "shop", "buy_face", "shop_done", "loot", "loot_taken", "auction", "auction_won", "mob_spawn",
	"new_boss", "comeback", "game_over", "boss_reward", "upgrade", "buy_renown", "refresh", "act"]


func _init() -> void:
	var games := 300
	var args := OS.get_cmdline_user_args()
	if not args.is_empty() and args[0].is_valid_int():
		games = args[0].to_int()

	_test_refusals()
	_test_economy()
	_test_mob_fail()
	_test_trinkets()
	_test_bosses()
	_test_determinism()
	_test_bot_ids()
	_test_recap()
	_test_achievements()

	var stats := _blank_stats()
	var started := Time.get_ticks_usec()
	for g in games:
		_play(g, _seats_for(g), stats)
	var elapsed := (Time.get_ticks_usec() - started) / 1000.0
	_report("normal rules", stats, elapsed)

	# Bots rarely coordinate on the full-strength boss, so also play games with a weak boss
	# to exercise boss kills, loot picks and auctions.
	var weak := _blank_stats()
	for g in floori(games / 3.0):
		_play(100000 + g, _seats_for(g), weak, 2)
	_report("weak boss", weak, 0.0)
	if weak.boss_kills == 0 or weak.auctions == 0:
		_fail("weak-boss games never killed the boss or never held an auction")
	for type in CORE_EVENTS:
		if not event_types.has(type):
			_fail("event type never emitted: " + type)
	print("event types seen: %d" % event_types.size())
	_test_translations()
	Content.clear_cache()
	_exit_code = 0


# Finish on the first frame rather than inside _init: the autoloads have started by then (the
# pad bindings are set up by one), and they stop cleanly.
func _process(_delta: float) -> bool:
	if _exit_code >= 0:
		_test_pad_bindings()
		if failures == 0:
			print("ALL RULE TESTS PASSED")
		else:
			print("FAILURES: %d" % failures)
		root.get_node("Transition").call("quit_game", 1 if failures else 0)
		_exit_code = -1
	return false


func _seats_for(g: int) -> int:
	return Content.MIN_SEATS + g % (Content.MAX_SEATS - Content.MIN_SEATS + 1)


func _report(title: String, stats: Dictionary, elapsed: float) -> void:

	var n := maxi(int(stats.games), 1)
	print("[%s] games=%d  requests=%d  %.2f ms/game" % [title, stats.games, stats.requests, elapsed / n])
	print("per game: KOs %.1f, mob kills %.1f, boss kills %.2f, auctions %.2f, purchases %.1f" % [
		stats.kos / float(n), stats.mob_kills / float(n), stats.boss_kills / float(n),
		stats.auctions / float(n), stats.purchases / float(n)])
	print("intentions kept %.0f%%, avg final score %.1f, avg winner score %.1f" % [
		100.0 * stats.kept / maxi(int(stats.kept + stats.broke), 1),
		stats.score_total / maxf(stats.seats, 1.0), stats.winner_score / float(n)])


func _blank_stats() -> Dictionary:
	return {"games": 0, "seats": 0, "requests": 0, "kos": 0, "mob_kills": 0, "boss_kills": 0, "kept": 0,
		"broke": 0, "auctions": 0, "purchases": 0, "score_total": 0, "winner_score": 0}


func _roster(seats: int) -> Array[Dictionary]:
	var roster: Array[Dictionary] = []
	for i in seats:
		roster.append({"id": 100 + i, "name": "Bot%d" % i, "bot": true})
	return roster


## Plays one game to the end and returns its full history. A positive boss_cap limits
## the boss's HP so tests can reach loot and auctions.
func _play(seed_value: int, seats: int, stats: Dictionary, boss_cap: int = 0) -> String:
	var rules := GameRules.new()
	rules.setup(_roster(seats), seed_value)
	var brain_rng := RandomNumberGenerator.new()
	brain_rng.seed = seed_value * 7919 + 1
	var steps := 0
	var last_seq := 0
	while rules.state.phase != GameState.Phase.GAME_OVER:
		var waiting := rules.state.waiting_on()
		if waiting.is_empty():
			_fail("seed %d: nobody to wait on in phase %d" % [seed_value, rules.state.phase])
			return ""
		if boss_cap > 0 and rules.state.phase == GameState.Phase.ROLL and rules.state.boss_max_hp > boss_cap:
			rules.state.boss_max_hp = boss_cap
			rules.state.boss_hp = boss_cap
		var pid := waiting[0]
		var view_dict := rules.state.to_view(pid)
		var view := GameState.from_view(view_dict)
		_check_view(rules.state, view, view_dict, pid, seed_value)
		var request := BotBrain.decide(view, pid, brain_rng)
		if request.is_empty():
			_fail("seed %d: bot %d had no move in phase %d" % [seed_value, pid, rules.state.phase])
			return ""
		if request[0] in [&"buy_face", &"buy_die"]:
			stats.purchases += 1
		var err := rules.apply(pid, request[0], request[1])
		if not err.is_empty():
			_fail("seed %d: bot request %s %s refused: %s" % [seed_value, request[0], request[1], Loc.text(err)])
			return ""
		_check_invariants(rules.state, seed_value)
		for event in rules.events_since(last_seq):
			if event.seq != last_seq + 1:
				_fail("seed %d: event sequence jumped from %d to %d" % [seed_value, last_seq, event.seq])
			last_seq = event.seq
			event_types[str(event.type)] = true
			_count_event(event, stats)
		steps += 1
		if steps > 20000:
			_fail("seed %d: game did not finish" % seed_value)
			return ""
	var s := rules.state
	if s.turn != s.max_turns or s.standings.size() != s.players.size():
		_fail("seed %d: bad ending turn=%d standings=%d" % [seed_value, s.turn, s.standings.size()])
	stats.games += 1
	stats.seats += s.players.size()
	stats.requests += steps
	for p in s.players:
		stats.score_total += s.final_score(p)
	stats.winner_score += s.final_score(s.player(s.standings[0]))
	for entry in rules.history:
		_collect_keys(entry)
		for found in _placeholder.search_all(Loc.text(entry)):
			if not Icons.NAMES.has(found.get_string(1)):
				_fail("seed %d: unfilled placeholder in %s" % [seed_value, entry.k])
	return var_to_str(rules.history)


## Records a message's msgid and those of the messages nested in it.
func _collect_keys(message: Dictionary) -> void:
	var key := str(message.k)
	if not key.begins_with("{item"):
		message_keys[key] = true
	for value: Variant in (message.a as Dictionary).values():
		if value is Dictionary and (value as Dictionary).has("k"):
			_collect_keys(value)


func _count_event(event: Dictionary, stats: Dictionary) -> void:
	match str(event.type):
		"knockout":
			stats.kos += 1
		"mob_kill":
			stats.mob_kills += 1
		"boss_slain":
			stats.boss_kills += 1
		"reveal":
			stats.kept += 1 if event.kept else 0
			stats.broke += 0 if event.kept else 1
		"auction":
			stats.auctions += 1


func _check_invariants(s: GameState, seed_value: int) -> void:
	for p in s.players:
		var bad := p.hp < 0 or p.hp > p.max_hp or p.gold < 0 or p.renown < 0 or p.score < 0
		bad = bad or p.combat < 0 or p.cunning < 0 or p.attack_left < 0 or p.guard_left < 0
		bad = bad or p.knocked_out != (p.hp == 0) or p.showing.size() != p.dice.size()
		bad = bad or p.oath < 0 or p.oath >= Content.OATH_LENGTH
		if bad:
			_fail("seed %d turn %d: invariant broken for %s: %s" % [seed_value, s.turn, p.name, p.to_dict(true)])
	if s.boss_hp < 0 or s.boss_hp > s.boss_max_hp:
		_fail("seed %d: boss hp out of range" % seed_value)


func _check_view(s: GameState, view: GameState, view_dict: Dictionary, viewer: int, seed_value: int) -> void:
	if view.to_view(viewer) != view_dict:
		_fail("seed %d: view does not round-trip" % seed_value)
	if s.phase == GameState.Phase.PLAN:
		for pd: Dictionary in view_dict.players:
			if pd.id != viewer and pd.has("plan_action"):
				_fail("seed %d: %d can see %d's plan before the reveal" % [seed_value, viewer, pd.id])


func _test_determinism() -> void:
	var a := _play(4242, 5, _blank_stats())
	var b := _play(4242, 5, _blank_stats())
	if a != b or a.is_empty():
		_fail("same seed produced different games")


## Bots have negative ids in real games: a knockout must be credited to them, and the boss must
## not be mistaken for the first bot.
func _test_bot_ids() -> void:
	var rules := GameRules.new()
	var roster: Array[Dictionary] = [{"id": 2, "name": "Human", "bot": false}, {"id": -1, "name": "Bot1", "bot": true}, {"id": -2, "name": "Bot2", "bot": true}]
	rules.setup(roster, 3)
	var bot := rules.state.player(-1)
	var score := bot.score
	rules.hurt(rules.state.player(2), rules.state.player(2).hp, -1)
	if bot.score != score + Content.KO_ATTACKER_SCORE:
		_fail("a knockout by a bot was not credited to it")
	rules.hurt(rules.state.player(-2), rules.state.player(-2).hp, GameRules.SOURCE_BOSS)
	if bot.score != score + Content.KO_ATTACKER_SCORE:
		_fail("a knockout by the boss was credited to the first bot")


func _test_recap() -> void:
	# A scripted ambush: declared Rest, attacked instead.
	var rules := GameRules.new()
	rules.setup(_roster(3), 5)
	var s := rules.state
	if not GameState.from_view(s.to_view(100)).recap.is_empty():
		_fail("the recap is visible before the game ends")
	for p in s.players:
		_expect_ok(rules.apply(p.id, &"finish_roll", [PackedInt32Array()]), "finish roll")
	for id in s.declare_order():
		_expect_ok(rules.apply(id, &"declare", [PlayerState.Action.REST, 0]), "declare")
	s.player(100).combat = 5
	_expect_ok(rules.apply(100, &"lock_plan", [PlayerState.Action.ATTACK_PLAYER, 101, 5, 0]), "ambush")
	_expect_ok(rules.apply(101, &"lock_plan", [PlayerState.Action.REST, 0, 0, 0]), "rest")
	_expect_ok(rules.apply(102, &"lock_plan", [PlayerState.Action.REST, 0, 0, 0]), "rest")
	var recap := rules.recap.to_dict()
	var attacker: Dictionary = recap.players[100]
	if attacker.broke != 1 or attacker.ambush_damage != 5 or recap.players[101].kept != 1 or recap.players[101].damage_taken != 5:
		_fail("the recap did not count the ambush: %s" % [recap.players])
	var betrayal: Dictionary = recap.betrayal
	if betrayal.get("pid") != 100 or betrayal.get("target") != 101 or betrayal.get("damage") != 5 or betrayal.get("turn") != 1:
		_fail("the recap missed the betrayal: %s" % [betrayal])
	if Loc.text(betrayal.get("said", {})) != Loc.text(Loc.msg("Rest")):
		_fail("the recap should remember what the traitor said")
	for award: Dictionary in recap.awards:
		if award.id == &"traitor" and award.pids != [100]:
			_fail("the traitor's title went to %s" % [award.pids])
		if award.id == &"honest" and award.pids.size() != 2:
			_fail("a tie should share the title: %s" % [award.pids])

	# A whole game: the recap reaches the players at the end, and its counts add up.
	var game := GameRules.new()
	game.setup(_roster(4), 77)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var reveals := 0
	var last := 0
	while game.state.phase != GameState.Phase.GAME_OVER:
		var pid: int = game.state.waiting_on()[0]
		var request := BotBrain.decide(GameState.from_view(game.state.to_view(pid)), pid, rng)
		_expect_ok(game.apply(pid, request[0], request[1]), "bot move")
		for event in game.events_since(last):
			last = event.seq
			if event.type == &"reveal":
				reveals += 1
	var final := GameState.from_view(game.state.to_view(100)).recap
	var counted := 0
	for pid: int in final.players:
		counted += final.players[pid].kept + final.players[pid].broke
	if counted != reveals or final.humans != 0:
		_fail("the recap counted %d words of %d" % [counted, reveals])
	for award: Dictionary in final.awards:
		for pid: int in award.pids:
			if game.state.player(pid) == null or award.value <= 0:
				_fail("a bad award: %s" % [award])


func _blank_recap_stats() -> Dictionary:
	return {"kept": 0, "broke": 0, "oaths": 0, "ambush_damage": 0, "ambush_kos": 0, "damage_taken": 0, "kos": 0,
		"knocked_out": 0, "mobs": 0, "bosses": 0, "last_stage_bosses": 0, "stolen": 0, "purchases": 0, "auctions": 0}


func _test_achievements() -> void:
	var view := GameState.new()
	var me := PlayerState.new()
	me.id = 1
	me.dice = Content.starting_dice()
	var rival := PlayerState.new()
	rival.id = 2
	view.players.assign([me, rival])
	view.standings.assign([1, 2])
	var stats := _blank_recap_stats()
	view.recap = {"players": {1: stats}, "humans": 1}
	var check := func(what: String, want: Array[StringName], refuse: Array[StringName], difficulty: int, offline: bool) -> void:
		var got := AchievementRules.earned(view, 1, difficulty, offline)
		for id in want:
			if not got.has(id):
				_fail("%s: should have earned %s, got %s" % [what, id, got])
		for id in refuse:
			if got.has(id):
				_fail("%s: should not have earned %s" % [what, id])
	check.call("a plain win", [&"ACH_FIRST_GAME", &"ACH_FIRST_WIN"] as Array[StringName], [&"ACH_BEAT_HARD", &"ACH_WIN_ONLINE", &"ACH_FIVE_DICE"] as Array[StringName], BotTable.Difficulty.NORMAL, true)
	check.call("a win against hard bots", [&"ACH_BEAT_HARD"] as Array[StringName], [] as Array[StringName], BotTable.Difficulty.HARD, true)
	check.call("hard online is not solo", [] as Array[StringName], [&"ACH_BEAT_HARD"] as Array[StringName], BotTable.Difficulty.HARD, false)
	view.recap.humans = 3
	stats.broke = 5
	stats.kept = 4
	stats.knocked_out = 1
	check.call("a treacherous comeback online", [&"ACH_WIN_ONLINE", &"ACH_FAITHLESS", &"ACH_COMEBACK"] as Array[StringName], [&"ACH_WORD_IS_BOND"] as Array[StringName], BotTable.Difficulty.NORMAL, false)
	stats.broke = 0
	stats.kept = AchievementRules.BOND_WORDS
	check.call("an honest game", [&"ACH_WORD_IS_BOND"] as Array[StringName], [&"ACH_FAITHLESS"] as Array[StringName], BotTable.Difficulty.NORMAL, false)
	view.standings.assign([2, 1])
	check.call("a loss", [&"ACH_FIRST_GAME", &"ACH_WORD_IS_BOND"] as Array[StringName], [&"ACH_FIRST_WIN", &"ACH_COMEBACK"] as Array[StringName], BotTable.Difficulty.NORMAL, false)
	var setup := FileAccess.get_file_as_string("res://steam/SETUP.md")
	for id in AchievementRules.IDS:
		if AchievementRules.title(id) == String(id):
			_fail("achievement %s has no name" % id)
		if not setup.contains("| %s | %s |" % [id, AchievementRules.title(id)]):
			_fail("achievement %s is missing from steam/SETUP.md" % id)


func _test_refusals() -> void:
	var rules := GameRules.new()
	rules.setup(_roster(3), 1)
	var s := rules.state
	var a := s.players[0].id
	_expect_refused(rules.apply(a, &"declare", [PlayerState.Action.REST, 0]), "declare during roll")
	_expect_refused(rules.apply(a, &"finish_roll", ["nope"]), "wrong argument type")
	_expect_refused(rules.apply(a, &"teleport", []), "unknown op")
	_expect_refused(rules.apply(999, &"finish_roll", [PackedInt32Array()]), "unknown player")
	_expect_refused(rules.apply(a, &"reroll", [PackedInt32Array([7])]), "invalid die")
	_expect_refused(rules.apply(a, &"finish_shop", []), "shop when not shopping")
	_expect_ok(rules.apply(a, &"reroll", [PackedInt32Array([0])]), "free reroll")
	for p in s.players:
		_expect_ok(rules.apply(p.id, &"finish_roll", [PackedInt32Array()]), "finish roll")
	_expect_refused(rules.apply(a, &"finish_roll", [PackedInt32Array()]), "roll twice")
	if s.phase != GameState.Phase.DECLARE:
		_fail("expected declare phase after everyone kept their dice")
		return
	var declarer := s.current_actor()
	var other := s.declare_order()[1]
	_expect_refused(rules.apply(other, &"declare", [PlayerState.Action.REST, 0]), "declare out of turn")
	_expect_refused(rules.apply(declarer, &"declare", [PlayerState.Action.ATTACK_PLAYER, declarer]), "attack yourself")
	_expect_refused(rules.apply(declarer, &"declare", [PlayerState.Action.REST, 5]), "target on rest")
	for id in s.declare_order():
		_expect_ok(rules.apply(id, &"declare", [PlayerState.Action.REST, 0]), "declare")
	var p0 := s.players[0]
	_expect_refused(rules.apply(p0.id, &"lock_plan", [PlayerState.Action.REST, 0, 0, p0.combat + 1]), "overspend")
	_expect_refused(rules.apply(p0.id, &"lock_plan", [PlayerState.Action.REST, 0, 1, 0]), "attack combat on rest")
	var biggest := 9223372036854775807
	_expect_refused(rules.apply(p0.id, &"lock_plan", [PlayerState.Action.ATTACK_BOSS, 0, biggest, 1]), "attack and guard that overflow")
	_expect_refused(rules.apply(p0.id, &"lock_plan", [PlayerState.Action.ATTACK_BOSS, 0, 1, biggest]), "guard that overflows")
	_expect_refused(rules.apply(p0.id, &"lock_plan", [PlayerState.Action.REST, 0, 0, 0, {}]), "old five-argument plan")
	_expect_refused(rules.apply(p0.id, &"upgrade_face", [0, 0, 0]), "upgrade when not shopping")
	_expect_refused(rules.apply(p0.id, &"buy_renown", []), "buy renown when not shopping")
	_expect_refused(rules.apply(p0.id, &"pick_loot", [0]), "pick loot with no loot")


## Paying with renown, upgrading faces and buying renown, on a hand-made shopping turn.
func _test_economy() -> void:
	var rules := GameRules.new()
	rules.setup(_roster(3), 7)
	var s := rules.state
	var p := s.players[0]
	# A shopping turn as the resolution would leave it: p is the only one to resolve.
	s.phase = GameState.Phase.RESOLVE
	s.initiative = [p.id]
	s.cursor = 0
	s.shopping = p.id
	p.dice[0][0] = Face.make(Face.Kind.COMBAT, 2)
	p.gold = 1
	p.renown = 2
	# Upgrading combat 2 to 3 costs 3: one renown (3 gold) covers it, a second would be wasted.
	_expect_refused(rules.apply(p.id, &"upgrade_face", [0, 0, 2]), "renown beyond the price")
	_expect_ok(rules.apply(p.id, &"upgrade_face", [0, 0, 1]), "upgrade paid in renown")
	if p.dice[0][0] != Face.make(Face.Kind.COMBAT, 3) or p.renown != 1 or p.gold != 1:
		_fail("upgrade or payment wrong: face %d renown %d gold %d" % [p.dice[0][0], p.renown, p.gold])
	p.dice[0][1] = Face.make(Face.Kind.COMBAT, Content.UPGRADE_MAX)
	p.gold = 20
	_expect_refused(rules.apply(p.id, &"upgrade_face", [0, 1, 0]), "upgrade past the maximum")
	p.dice[0][2] = Face.make(Face.Kind.DOUBLE, 2)
	_expect_refused(rules.apply(p.id, &"upgrade_face", [0, 2, 0]), "upgrade a double")
	_expect_ok(rules.apply(p.id, &"buy_renown", []), "buy renown")
	if p.gold != 20 - Content.RENOWN_PRICE or p.renown != 2:
		_fail("buying renown: gold %d renown %d" % [p.gold, p.renown])
	p.gold = Content.RENOWN_PRICE - 1
	_expect_refused(rules.apply(p.id, &"buy_renown", []), "renown without the gold")


## A scripted turn where one player attacks a mob too strong for them: it must hit back.
func _test_mob_fail() -> void:
	var rules := GameRules.new()
	rules.setup(_roster(3), 11)
	var s := rules.state
	for p in s.players:
		_expect_ok(rules.apply(p.id, &"finish_roll", [PackedInt32Array()]), "finish roll")
	var attacker := s.player(s.declare_order()[0])
	var slot := 0
	for i in s.mobs.size():
		if Content.mob(s.mobs[i].id).hp > Content.mob(s.mobs[slot].id).hp:
			slot = i
	var mob := Content.mob(s.mobs[slot].id)
	attacker.combat = mob.hp - 1
	for id in s.declare_order():
		var declared := [PlayerState.Action.ATTACK_MOB, slot] if id == attacker.id else [PlayerState.Action.REST, 0]
		_expect_ok(rules.apply(id, &"declare", declared), "declare")
	var since := rules.last_event_seq()
	for p in s.players:
		var plan := [PlayerState.Action.ATTACK_MOB, slot, p.combat, 0] if p == attacker else [PlayerState.Action.REST, 0, 0, p.combat]
		_expect_ok(rules.apply(p.id, &"lock_plan", plan), "lock plan")
	var failed := false
	for event in rules.events_since(since):
		event_types[str(event.type)] = true
		if event.type == &"mob_fail" and event.pid == attacker.id:
			failed = true
	if not failed:
		_fail("attacking a mob with too little combat did not fail")


func _expect_refused(err: Dictionary, what: String) -> void:
	if err.is_empty():
		_fail("expected refusal: " + what)


func _expect_ok(err: Dictionary, what: String) -> void:
	if not err.is_empty():
		_fail("expected success (%s): %s" % [what, Loc.text(err)])


## A game at the start of its first roll, with trinkets handed to the first player.
func _game_with(trinkets: Array[StringName], seats: int = 3) -> GameRules:
	var rules := GameRules.new()
	rules.setup(_roster(seats), 7)
	var p := rules.state.players[0]
	for id in trinkets:
		p.trinkets.append(id)
	return rules


## Rolls for everyone and declares rest for everyone, so the game waits in the plan phase.
func _to_plan(rules: GameRules) -> void:
	for p in rules.state.players:
		if p.is_active():
			_expect_ok(rules.apply(p.id, &"finish_roll", [PackedInt32Array()]), "finish roll")
	for id in rules.state.declare_order():
		_expect_ok(rules.apply(id, &"declare", [PlayerState.Action.REST, 0]), "declare")


func _test_trinkets() -> void:
	# Every trinket loads, has a name and a description, and boss loot exists.
	for trinket in Content.trinkets():
		if trinket == null or trinket.id == &"" or trinket.display_name.is_empty() or trinket.description.is_empty():
			_fail("a trinket is missing its id, name or description")
	for id in Content.BOSS_LOOT:
		if Content.trinket(id) == null:
			_fail("boss loot %s does not exist" % id)
	for mob in Content.mobs():
		for reward in mob.rewards:
			if not Content.TRINKET_PATHS.has(reward.resource_path):
				_fail("%s drops %s, which is not in TRINKET_PATHS" % [mob.id, reward.id])

	# Bone Dice: the second reroll is free too.
	var rules := _game_with([&"bone_dice"])
	var p := rules.state.players[0]
	_expect_ok(rules.apply(p.id, &"reroll", [PackedInt32Array([0])]), "first reroll")
	if p.reroll_cost() != 0:
		_fail("Bone Dice: the second reroll should be free")
	_expect_ok(rules.apply(p.id, &"reroll", [PackedInt32Array([0])]), "second reroll")
	if p.cunning_spent != 0 or p.reroll_cost() != Content.REROLL_CUNNING_COST:
		_fail("Bone Dice: the third reroll should cost cunning")

	# Merchant's Seal: a die costs 1 less, never below 1.
	p = _game_with([&"merchants_seal"]).state.players[0]
	if p.price(Content.DIE_PRICE) != Content.DIE_PRICE - 1 or p.price(1) != 1 or p.price(0) != 0:
		_fail("Merchant's Seal: wrong prices")

	# Lucky Coin and Fox Mask add per face rolled.
	p = _game_with([&"lucky_coin", &"fox_mask"]).state.players[0]
	var plain := PlayerState.new()
	plain.dice = p.dice.duplicate()
	plain.showing = p.showing.duplicate()
	var with_trinkets := p.roll_totals()
	var without := plain.roll_totals()
	var kinds := PackedInt32Array()
	for face in p.showing_faces():
		kinds.append(Face.kind_of(face))
	if with_trinkets.gold != without.gold + kinds.count(Face.Kind.GOLD) or with_trinkets.cunning != without.cunning + 1 + kinds.count(Face.Kind.CUNNING):
		_fail("Lucky Coin / Fox Mask: wrong roll totals")

	# Herbal Pouch: rest heals 2 more.
	rules = _game_with([&"herbal_pouch"])
	p = rules.state.players[0]
	p.hp = 2
	_to_plan(rules)
	for q in rules.state.players:
		_expect_ok(rules.apply(q.id, &"lock_plan", [PlayerState.Action.REST, 0, 0, 0]), "lock rest")
	if p.hp != 2 + Content.REST_HEAL + 2:
		_fail("Herbal Pouch: rest healed to %d" % p.hp)

	# Liar's Mask: a broken word keeps the oath; without it the oath starts over.
	for masked in [true, false]:
		var worn: Array[StringName] = []
		if masked:
			worn.append(&"liars_mask")
		rules = _game_with(worn)
		p = rules.state.players[0]
		p.oath = 2
		_to_plan(rules)
		for q in rules.state.players:
			var plan := [PlayerState.Action.ATTACK_BOSS, 0, q.combat, 0] if q == p else [PlayerState.Action.REST, 0, 0, 0]
			_expect_ok(rules.apply(q.id, &"lock_plan", plan), "lock plan")
		if p.oath != (2 if masked else 0):
			_fail("Liar's Mask (%s): oath is %d after a lie" % [masked, p.oath])

	# Thorned Mail: whoever damages the wearer takes 1; Hunter's Horn adds 2 against mobs.
	rules = _game_with([&"thorned_mail"])
	var wearer := rules.state.players[0]
	var attacker := rules.state.players[1]
	attacker.trinkets.append(&"war_banner")
	_to_plan(rules)
	var attacker_hp := attacker.hp
	for q in rules.state.players:
		var plan := [PlayerState.Action.REST, 0, 0, 0]
		if q == attacker:
			plan = [PlayerState.Action.ATTACK_PLAYER, wearer.id, 0, 0]
		_expect_ok(rules.apply(q.id, &"lock_plan", plan), "lock plan")
	if attacker.hp != attacker_hp - 1:
		_fail("Thorned Mail: attacker has %d health, expected %d" % [attacker.hp, attacker_hp - 1])

	# Phoenix Feather: back from a knockout at full health.
	rules = _game_with([&"phoenix_feather"])
	p = rules.state.players[0]
	p.max_hp = 20
	rules.hurt(p, p.hp, GameRules.SOURCE_MOB)
	while rules.state.turn < 3 and rules.state.phase != GameState.Phase.GAME_OVER:
		_play_round(rules)
	if p.knocked_out or p.hp != p.max_hp:
		_fail("Phoenix Feather: came back with %d of %d" % [p.hp, p.max_hp])


## Plays whatever is pending with the bot brain until the turn changes.
func _play_round(rules: GameRules) -> void:
	var rng := RandomNumberGenerator.new()
	var turn := rules.state.turn
	var guard := 0
	while rules.state.turn == turn and rules.state.phase != GameState.Phase.GAME_OVER and guard < 500:
		guard += 1
		var pid := rules.state.waiting_on()[0]
		var request := BotBrain.decide(GameState.from_view(rules.state.to_view(pid)), pid, rng)
		_expect_ok(rules.apply(pid, request[0], request[1]), "bot move")


## Each boss comes from its stage, and every stage has a boss.
func _test_bosses() -> void:
	for stage in range(1, Content.BOSS_STAGES + 1):
		if Content.bosses_of_stage(stage).is_empty():
			_fail("no boss for stage %d" % stage)
	for seed_value in 20:
		var rules := GameRules.new()
		rules.setup(_roster(4), seed_value)
		if rules.state.boss().stage != 1:
			_fail("the first boss is not from stage 1")


## Every Chronicle message, refusal and interface text the games produced exists in every
## translation, with the same placeholders.
func _test_translations() -> void:
	for code: String in Loc.LANGUAGES:
		if code == "en":
			continue
		var translation := TranslationServer.get_translation_object(code)
		if translation == null:
			_fail("no translation loaded for %s" % code)
			continue
		var missing := 0
		for key: String in message_keys:
			var text := String(translation.get_message(key))
			if text.is_empty():
				missing += 1
				if missing <= 5:
					_fail("%s: no translation for %s" % [code, key])
				continue
			var wanted := {}
			for found in _placeholder.search_all(key):
				wanted[found.get_string(1)] = true
			var got := {}
			for found in _placeholder.search_all(text):
				got[found.get_string(1)] = true
			if wanted != got:
				_fail("%s: placeholders differ for %s" % [code, key])
		print("%s: %d Chronicle messages checked" % [code, message_keys.size()])


func _fail(message: String) -> void:
	failures += 1
	if failures <= 20:
		printerr("FAIL: " + message)


## Every action a controller player needs has a pad binding (Controls adds the ones Godot lacks).
func _test_pad_bindings() -> void:
	for action in [&"ui_up", &"ui_down", &"ui_left", &"ui_right", &"ui_accept", &"ui_cancel", &"menu", &"skip",
			&"rules", &"players", &"prev_tab", &"next_tab", &"scroll_up", &"scroll_down"]:
		var pad := InputMap.action_get_events(action).filter(func(e: InputEvent) -> bool:
			return e is InputEventJoypadButton or e is InputEventJoypadMotion)
		if pad.is_empty():
			_fail("no controller binding for %s" % action)
