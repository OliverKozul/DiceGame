extends SceneTree
## Plays many complete bot games straight through GameRules (no networking) and checks
## invariants after every request. Also checks determinism, view round-trips, hidden
## information and that bad requests are refused.
##   godot --headless --path . --script res://tests/test_rules.gd -- [games]

var failures := 0
var _exit_code := -1
## Every event type seen in any game, to check the presentation layer gets them all.
var event_types := {}
const CORE_EVENTS: Array[String] = ["turn_start", "reroll", "kept", "initiative", "declare", "locked", "reveal",
	"sabotage", "attack", "mob_kill", "mob_fail", "boss_hit", "boss_slain", "boss_strike", "rest", "knockout",
	"trinket", "shop", "buy_face", "shop_done", "loot", "loot_taken", "auction", "auction_won", "mob_spawn",
	"new_boss", "comeback", "game_over", "boss_reward"]


func _init() -> void:
	var games := 300
	var args := OS.get_cmdline_user_args()
	if not args.is_empty() and args[0].is_valid_int():
		games = args[0].to_int()

	_test_refusals()
	_test_determinism()

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

	Content.clear_cache()
	if failures == 0:
		print("ALL RULE TESTS PASSED")
	else:
		print("FAILURES: %d" % failures)
	_exit_code = 1 if failures else 0


# Quit on the first frame rather than inside _init, so the autoloads start and stop cleanly.
func _process(_delta: float) -> bool:
	if _exit_code >= 0:
		root.get_node("Transition").call("quit_game", _exit_code)
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
			_fail("seed %d: bot request %s %s refused: %s" % [seed_value, request[0], request[1], err])
			return ""
		_check_invariants(rules.state, seed_value)
		for event in rules.events_since(last_seq):
			if event.seq != last_seq + 1:
				_fail("seed %d: event sequence jumped from %d to %d" % [seed_value, last_seq, event.seq])
			last_seq = event.seq
			event_types[str(event.type)] = true
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
	for line in rules.history:
		if line.contains("knocks out") or line.contains("is knocked out"):
			stats.kos += 1
		if line.contains(" slays the "):
			stats.mob_kills += 1
		if line.ends_with(" is slain!"):
			stats.boss_kills += 1
		if line.contains("kept their word"):
			stats.kept += 1
		if line.contains("broke their word"):
			stats.broke += 1
		if line.contains("sealed bids"):
			stats.auctions += 1
	return "\n".join(rules.history)


func _check_invariants(s: GameState, seed_value: int) -> void:
	for p in s.players:
		var bad := p.hp < 0 or p.hp > p.max_hp or p.gold < 0 or p.renown < 0 or p.score < 0
		bad = bad or p.combat < 0 or p.cunning < 0 or p.attack_left < 0 or p.guard_left < 0
		bad = bad or p.knocked_out != (p.hp == 0) or p.showing.size() != p.dice.size()
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
	_expect_refused(rules.apply(p0.id, &"lock_plan", [PlayerState.Action.REST, 0, 0, p0.combat + 1, {}]), "overspend")
	_expect_refused(rules.apply(p0.id, &"lock_plan", [PlayerState.Action.REST, 0, 1, 0, {}]), "attack combat on rest")
	_expect_refused(rules.apply(p0.id, &"lock_plan", [PlayerState.Action.REST, 0, 0, 0, {"x": 1}]), "bad sabotage")


func _expect_refused(err: String, what: String) -> void:
	if err.is_empty():
		_fail("expected refusal: " + what)


func _expect_ok(err: String, what: String) -> void:
	if not err.is_empty():
		_fail("expected success (%s): %s" % [what, err])


func _fail(message: String) -> void:
	failures += 1
	if failures <= 20:
		printerr("FAIL: " + message)
