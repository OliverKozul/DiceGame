class_name BotTable
extends RefCounted
## The bots at one table. Each seat gets a brain for the game's difficulty; every brain watches
## the public events from the first turn, so a bot that takes over from a player who left already
## knows who has been lying. Bots only ever see the view a player at the table would see.

enum Difficulty { EASY, NORMAL, HARD }

## Play styles each difficulty deals out, one per seat at random, so tables differ.
const STYLES: Dictionary = {
	Difficulty.NORMAL: ["honest", "rational", "farmer", "boss_hunter", "builder"],
	Difficulty.HARD: ["builder", "builder", "opportunist", "rational"],
}
## How each difficulty reads declarations (see StrategyBot.Reads).
const READS: Dictionary = {
	Difficulty.NORMAL: StrategyBot.Reads.GULLIBLE,
	Difficulty.HARD: StrategyBot.Reads.SUSPICIOUS,
}

var _rng: RandomNumberGenerator
## Seats with a StrategyBot; the others play BotBrain, the Easy bot.
var _brains: Dictionary[int, StrategyBot] = {}


func _init(rng: RandomNumberGenerator) -> void:
	_rng = rng


## The difficulty's translated name.
static func difficulty_name(difficulty: int) -> String:
	match difficulty:
		Difficulty.EASY:
			return Loc.t("Easy")
		Difficulty.HARD:
			return Loc.t("Hard")
	return Loc.t("Normal")


func add_seat(pid: int, difficulty: int) -> void:
	if not STYLES.has(difficulty):
		return
	var styles: Array = STYLES[difficulty]
	_brains[pid] = StrategyBot.new(styles[_rng.randi_range(0, styles.size() - 1)], READS[difficulty])


func observe(event: Dictionary) -> void:
	if StrategyBot.OBSERVED.has(event.type):
		for brain: StrategyBot in _brains.values():
			brain.observe(event)


## The seat's next request as [op, args], or [] when it has nothing to do.
func decide(view: GameState, pid: int) -> Array:
	if _brains.has(pid):
		return _brains[pid].decide(view, pid, _rng)
	return BotBrain.decide(view, pid, _rng)
