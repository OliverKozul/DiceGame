extends SceneTree
## Balance report: plays bot games and prints how often each kind of action and event
## happens, for tuning the numbers in Content and Resources.
##   godot --headless --path . --script res://tests/balance_report.gd

var _done := false


func _process(_delta: float) -> bool:
	if _done:
		Content.clear_cache()
		quit()
	return false


func _init() -> void:
	var n := 200
	var c := {"attack": 0, "damage": 0, "blocked": 0, "mob_kill": 0, "mob_fail": 0, "boss_hit": 0, "rest": 0, "shop": 0, "turns": 0, "combat": 0, "seats": 0, "actions": {}}
	for g in n:
		var seats := 3 + g % 4
		var rules := GameRules.new()
		var roster: Array[Dictionary] = []
		for i in seats:
			roster.append({"id": 100 + i, "name": "B%d" % i, "bot": true})
		rules.setup(roster, g)
		var rng := RandomNumberGenerator.new()
		rng.seed = g
		var last := 0
		while rules.state.phase != GameState.Phase.GAME_OVER:
			var s := rules.state
			var pid := s.waiting_on()[0]
			var req := BotBrain.decide(GameState.from_view(s.to_view(pid)), pid, rng)
			rules.apply(pid, req[0], req[1])
			for e in rules.events_since(last):
				last = e.seq
				match str(e.type):
					"attack":
						c.attack += 1
						c.damage += e.damage
						c.blocked += e.blocked
					"mob_kill", "mob_fail", "boss_hit", "rest", "shop":
						c[str(e.type)] += 1
					"kept":
						c.combat += e.combat
						c.turns += 1
					"reveal":
						var key := str(PlayerState.Action.find_key(int(e.action)))
						c.actions[key] = c.actions.get(key, 0) + 1
	print("per game: attacks %.1f dmg/attack %.2f blocked/attack %.2f mob kills %.1f mob fails %.1f boss hits %.1f rests %.1f shops %.1f" % [
		c.attack / float(n), c.damage / maxf(c.attack, 1), c.blocked / maxf(c.attack, 1), c.mob_kill / float(n), c.mob_fail / float(n), c.boss_hit / float(n), c.rest / float(n), c.shop / float(n)])
	print("avg combat per player-turn: %.2f" % (c.combat / float(c.turns)))
	print("plan actions: %s" % c.actions)
	_done = true
