extends SceneTree
## Where does a simulated game spend its time? Splits engine (apply), view building
## (to_view + from_view) and bot decisions.


var _quit := false


func _init() -> void:
	var t_apply := 0
	var t_to := 0
	var t_from := 0
	var t_bot := 0
	var t_events := 0
	var requests := 0
	var by_phase := {}
	var games := 40
	var started := Time.get_ticks_usec()
	for g in games:
		var roster: Array[Dictionary] = []
		var bots := {}
		for i in 5:
			roster.append({"id": 100 + i, "name": "b%d" % i, "bot": true})
			bots[100 + i] = StrategyBot.new("rational", StrategyBot.Reads.SUSPICIOUS)
		var rules := GameRules.new()
		rules.setup(roster, g)
		var rng := RandomNumberGenerator.new()
		rng.seed = g
		var last := 0
		while rules.state.phase != GameState.Phase.GAME_OVER:
			var pid := rules.state.waiting_on()[0]
			var a := Time.get_ticks_usec()
			var d := rules.state.to_view(pid)
			var b := Time.get_ticks_usec()
			var view := GameState.from_view(d)
			var c := Time.get_ticks_usec()
			var phase := view.phase
			var req: Array = bots[pid].decide(view, pid, rng)
			var e := Time.get_ticks_usec()
			by_phase[phase] = by_phase.get(phase, 0) + (e - c)
			rules.apply(pid, req[0], req[1])
			var f := Time.get_ticks_usec()
			for ev in rules.events_since(last):
				last = ev.seq
				if StrategyBot.OBSERVED.has(ev.type):
					for bot: Variant in bots.values():
						bot.observe(ev)
			var h := Time.get_ticks_usec()
			t_to += b - a
			t_from += c - b
			t_bot += e - c
			t_apply += f - e
			t_events += h - f
			requests += 1
	var total := Time.get_ticks_usec() - started
	print("games %d requests %d (%.0f/game) total %.1f ms/game" % [games, requests, requests / float(games), total / 1000.0 / games])
	for pair in [["to_view", t_to], ["from_view", t_from], ["bot decide", t_bot], ["rules.apply", t_apply], ["events", t_events]]:
		print("  %-12s %6.1f ms/game  %4.1f%%" % [pair[0], pair[1] / 1000.0 / games, 100.0 * pair[1] / total])
	for ph: int in by_phase:
		print("  bot in %-8s %6.1f ms/game" % [GameState.PHASE_NAMES[ph], by_phase[ph] / 1000.0 / games])
	_quit = true


func _process(_delta: float) -> bool:
	if _quit:
		Content.clear_cache()
		quit()
	return false
