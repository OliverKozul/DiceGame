class_name PlayerState
extends RefCounted
## Everything about one seat. The host owns the real values; clients get a copy in which
## another player's plan stays hidden until the reveal.

enum Action { NONE, ATTACK_PLAYER, ATTACK_MOB, ATTACK_BOSS, SHOP, REST }

const ACTION_NAMES: Dictionary = {
	Action.NONE: "Nothing",
	Action.ATTACK_PLAYER: "Attack player",
	Action.ATTACK_MOB: "Attack mob",
	Action.ATTACK_BOSS: "Attack boss",
	Action.SHOP: "Shop",
	Action.REST: "Rest",
}

var id: int = 0
var name: String = ""
var seat: int = 0
var is_bot: bool = false
var connected: bool = true

var hp: int = Content.STARTING_HP
var max_hp: int = Content.STARTING_HP
var gold: int = 0
var renown: int = 0
var score: int = 0
var dice: Array[PackedInt32Array] = []
var trinkets: Array[StringName] = []

var knocked_out: bool = false
## A knocked-out player sits out until the end of this turn, then returns.
var out_until_turn: int = 0

# --- This turn ---------------------------------------------------------------
## Face index shown by each die; -1 while not rolled.
var showing: PackedInt32Array = PackedInt32Array()
var rerolls: int = 0
var cunning_spent: int = 0
var roll_done: bool = false
var combat: int = 0
var guard_bonus: int = 0
var cunning: int = 0

var declared: bool = false
var intention_action: Action = Action.NONE
var intention_target: int = 0

var plan_locked: bool = false
var plan_action: Action = Action.NONE
var plan_target: int = 0
var plan_attack: int = 0
var plan_guard: int = 0
var plan_sabotage: Dictionary[int, int] = {}

var kept_word: bool = false
var resolved: bool = false
var attack_left: int = 0
var guard_left: int = 0


func is_active() -> bool:
	return not knocked_out


## Heals up to max HP and returns how much was healed.
func heal(amount: int) -> int:
	var before := hp
	hp = mini(max_hp, hp + maxi(amount, 0))
	return hp - before


func add_die(faces: PackedInt32Array) -> void:
	dice.append(faces)
	showing.append(-1)


func showing_faces() -> PackedInt32Array:
	var faces := PackedInt32Array()
	for i in dice.size():
		if i < showing.size() and showing[i] >= 0:
			faces.append(dice[i][showing[i]])
	return faces


func wild_count() -> int:
	var count := 0
	for face in showing_faces():
		if Face.kind_of(face) == Face.Kind.WILD:
			count += 1
	return count


func reroll_cost() -> int:
	return 0 if rerolls == 0 else Content.REROLL_CUNNING_COST


static func empty_totals() -> Dictionary:
	return {"combat": 0, "gold": 0, "cunning": 0, "guard": 0, "heal": 0, "renown": 0}


## What the dice currently showing are worth, after wild choices, doubles, trinkets and
## cunning already spent on rerolls. Pure, so clients can preview it.
func roll_totals(wild_kinds: PackedInt32Array = PackedInt32Array()) -> Dictionary:
	var kinds := PackedInt32Array()
	var values := PackedInt32Array()
	var wild_index := 0
	for face in showing_faces():
		var kind := Face.kind_of(face)
		if kind == Face.Kind.WILD:
			kind = Face.Kind.COMBAT
			if wild_index < wild_kinds.size() and Face.WILD_CHOICES.has(wild_kinds[wild_index]):
				kind = wild_kinds[wild_index] as Face.Kind
			wild_index += 1
		kinds.append(kind)
		values.append(Face.value_of(face))

	var doubled := {}
	for i in kinds.size():
		if kinds[i] != Face.Kind.DOUBLE:
			continue
		var best := -1
		for j in kinds.size():
			if kinds[j] == Face.Kind.DOUBLE or kinds[j] == Face.Kind.NONE or doubled.has(j):
				continue
			if best < 0 or values[j] > values[best]:
				best = j
		if best >= 0:
			values[best] *= 2
			doubled[best] = true

	var totals := empty_totals()
	for i in kinds.size():
		match kinds[i]:
			Face.Kind.COMBAT:
				totals.combat += values[i]
			Face.Kind.GOLD:
				totals.gold += values[i]
			Face.Kind.CUNNING:
				totals.cunning += values[i]
			Face.Kind.GUARD:
				totals.guard += values[i]
			Face.Kind.HEAL:
				totals.heal += values[i]
			Face.Kind.RENOWN:
				totals.renown += values[i]
	for trinket_id in trinkets:
		var trinket := Content.trinket(trinket_id)
		if trinket:
			trinket.on_roll(totals, kinds)
	totals.cunning = maxi(0, totals.cunning - cunning_spent)
	return totals


func reset_for_turn() -> void:
	showing = PackedInt32Array()
	showing.resize(dice.size())
	showing.fill(-1)
	rerolls = 0
	cunning_spent = 0
	roll_done = false
	combat = 0
	guard_bonus = 0
	cunning = 0
	declared = false
	intention_action = Action.NONE
	intention_target = 0
	clear_plan()
	kept_word = false
	resolved = false
	attack_left = 0
	guard_left = 0


func clear_plan() -> void:
	plan_locked = false
	plan_action = Action.NONE
	plan_target = 0
	plan_attack = 0
	plan_guard = 0
	plan_sabotage = {}


func to_dict(include_plan: bool) -> Dictionary:
	var d := {
		"id": id, "name": name, "seat": seat, "is_bot": is_bot, "connected": connected,
		"hp": hp, "max_hp": max_hp, "gold": gold, "renown": renown, "score": score,
		"dice": dice.duplicate(true), "trinkets": trinkets.duplicate(),
		"knocked_out": knocked_out, "out_until_turn": out_until_turn,
		"showing": showing, "rerolls": rerolls, "cunning_spent": cunning_spent, "roll_done": roll_done,
		"combat": combat, "guard_bonus": guard_bonus, "cunning": cunning,
		"declared": declared, "intention_action": intention_action, "intention_target": intention_target,
		"plan_locked": plan_locked, "kept_word": kept_word, "resolved": resolved,
		"attack_left": attack_left, "guard_left": guard_left,
	}
	if include_plan:
		d.merge({
			"plan_action": plan_action, "plan_target": plan_target, "plan_attack": plan_attack,
			"plan_guard": plan_guard, "plan_sabotage": plan_sabotage.duplicate(),
		})
	return d


static func from_dict(d: Dictionary) -> PlayerState:
	var p := PlayerState.new()
	p.id = d.id
	p.name = d.name
	p.seat = d.seat
	p.is_bot = d.is_bot
	p.connected = d.connected
	p.hp = d.hp
	p.max_hp = d.max_hp
	p.gold = d.gold
	p.renown = d.renown
	p.score = d.score
	p.dice.assign(d.dice)
	p.trinkets.assign(d.trinkets)
	p.knocked_out = d.knocked_out
	p.out_until_turn = d.out_until_turn
	p.showing = d.showing
	p.rerolls = d.rerolls
	p.cunning_spent = d.cunning_spent
	p.roll_done = d.roll_done
	p.combat = d.combat
	p.guard_bonus = d.guard_bonus
	p.cunning = d.cunning
	p.declared = d.declared
	p.intention_action = d.intention_action
	p.intention_target = d.intention_target
	p.plan_locked = d.plan_locked
	p.kept_word = d.kept_word
	p.resolved = d.resolved
	p.attack_left = d.attack_left
	p.guard_left = d.guard_left
	if d.has("plan_action"):
		p.plan_action = d.plan_action
		p.plan_target = d.plan_target
		p.plan_attack = d.plan_attack
		p.plan_guard = d.plan_guard
		p.plan_sabotage.assign(d.plan_sabotage)
	return p
