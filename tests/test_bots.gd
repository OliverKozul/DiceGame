extends SceneTree
## The difficulty ladder: a proxy for a person (play styles that keep their word, lie and farm mobs)
## sits at a table of each difficulty, on the same seeds, and must score less against each harder
## table. Also fails if a bot makes a refused request or has no move.
##   godot --headless --path . --script res://tests/test_bots.gd -- [games per table] [first seed]

const HEROES: Array[String] = ["honest", "opportunist", "farmer"]
const TABLES: Array[int] = [BotTable.Difficulty.EASY, BotTable.Difficulty.NORMAL, BotTable.Difficulty.HARD]

var failures := 0
var _exit_code := -1


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var games := int(args[0]) if args.size() > 0 else 200
	var start := int(args[1]) if args.size() > 1 else 0
	var margins: Array[PackedFloat64Array] = []
	for difficulty in TABLES:
		var margin := PackedFloat64Array()
		var wins := 0
		for g in games:
			for hero in HEROES:
				var played := _play(start + g, difficulty, hero)
				if played.is_empty():
					_exit_code = 1
					return
				margin.append(played.margin)
				wins += played.won
		margins.append(margin)
		print("%-7s the proxy's score lead %+.2f, wins %.0f%%" % [BotTable.Difficulty.find_key(difficulty), _mean(margin), 100.0 * wins / margin.size()])
	for i in range(1, TABLES.size()):
		var gap := _mean(margins[i - 1]) - _mean(margins[i])
		if gap <= 0.0:
			failures += 1
			printerr("FAIL: %s is not harder than %s (%.2f)" % [BotTable.Difficulty.find_key(TABLES[i]), BotTable.Difficulty.find_key(TABLES[i - 1]), gap])
	_exit_code = 1 if failures else 0


func _process(_delta: float) -> bool:
	if _exit_code >= 0:
		if failures == 0:
			print("BOT LADDER PASSED")
		Content.clear_cache()
		root.get_node("Transition").call("quit_game", _exit_code)
		_exit_code = -1
	return false


func _mean(values: PackedFloat64Array) -> float:
	var total := 0.0
	for value in values:
		total += value
	return total / maxi(values.size(), 1)


## One game with bot ids as in a real game (negative). Returns the hero's score lead over the
## mean of the table and whether it won; {} on a bad move.
func _play(seed_value: int, difficulty: int, hero_style: String) -> Dictionary:
	var pick := RandomNumberGenerator.new()
	pick.seed = seed_value * 7919 + 17
	var seats := pick.randi_range(3, 6)
	var hero_id := -1 - pick.randi_range(0, seats - 1)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 104729 + 7
	var bots := BotTable.new(rng)
	var roster: Array[Dictionary] = []
	for i in seats:
		var pid := -1 - i
		roster.append({"id": pid, "name": "B%d" % i, "bot": true})
		if pid != hero_id:
			bots.add_seat(pid, difficulty)
	var hero := StrategyBot.new(hero_style, StrategyBot.Reads.SUSPICIOUS)
	var rules := GameRules.new()
	rules.setup(roster, seed_value)
	var last := 0
	while rules.state.phase != GameState.Phase.GAME_OVER:
		var pid: int = rules.state.waiting_on()[0]
		var view := GameState.from_view(rules.state.to_view(pid))
		var request: Array = hero.decide(view, pid, rng) if pid == hero_id else bots.decide(view, pid)
		if request.is_empty():
			printerr("FAIL: seed %d: no move for %d in phase %d" % [seed_value, pid, rules.state.phase])
			failures += 1
			return {}
		var err := rules.apply(pid, request[0], request[1])
		if not err.is_empty():
			printerr("FAIL: seed %d: %s refused: %s" % [seed_value, request, Loc.text(err)])
			failures += 1
			return {}
		for event in rules.events_since(last):
			last = event.seq
			bots.observe(event)
			if StrategyBot.OBSERVED.has(event.type):
				hero.observe(event)
	var state := rules.state
	var total := 0.0
	for p in state.players:
		total += state.final_score(p)
	var own := state.final_score(state.player(hero_id))
	return {"margin": own - (total - own) / (seats - 1), "won": 1 if state.standings[0] == hero_id else 0}
