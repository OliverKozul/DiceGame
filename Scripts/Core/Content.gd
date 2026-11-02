class_name Content
extends RefCounted
## Static registry of all game content and tuning numbers. Ids, not resources, travel over
## the network; both host and clients look them up here.

const STARTING_HP := 20
const MAX_TURNS := 15
const MIN_SEATS := 3
const MAX_SEATS := 6
const MOB_SLOTS := 3
const MARKET_SIZE := 5
const DIE_PRICE := 5
const REFRESH_PRICE := 1
const REROLL_CUNNING_COST := 1
const REST_HEAL := 3
const HONESTY_RENOWN := 1
const MOB_KILL_SCORE := 1
const BOSS_KILL_SCORE := 2
const KO_ATTACKER_SCORE := 2
const KO_VICTIM_PENALTY := 1

## Market face tiles: [kind, value, price, copies in the deck].
const FACE_CATALOG: Array = [
	[Face.Kind.COMBAT, 2, 2, 4],
	[Face.Kind.GOLD, 2, 2, 4],
	[Face.Kind.CUNNING, 2, 2, 3],
	[Face.Kind.GUARD, 2, 2, 3],
	[Face.Kind.COMBAT, 3, 4, 3],
	[Face.Kind.GOLD, 3, 4, 3],
	[Face.Kind.HEAL, 2, 4, 3],
	[Face.Kind.WILD, 1, 4, 3],
	[Face.Kind.COMBAT, 4, 6, 2],
	[Face.Kind.CUNNING, 3, 6, 2],
	[Face.Kind.RENOWN, 1, 6, 2],
	[Face.Kind.DOUBLE, 2, 6, 2],
]

const TRINKET_PATHS: Array[String] = [
	"res://Resources/Trinkets/SharpTooth.tres",
	"res://Resources/Trinkets/SaboteurDagger.tres",
	"res://Resources/Trinkets/CoinMagnet.tres",
	"res://Resources/Trinkets/GobletOfBlood.tres",
	"res://Resources/Trinkets/ThirdEye.tres",
	"res://Resources/Trinkets/Opportunity.tres",
	"res://Resources/Trinkets/CrownOfHonor.tres",
]

const MOB_PATHS: Array[String] = [
	"res://Resources/Enemies/RatKing.tres",
	"res://Resources/Enemies/GoblinThief.tres",
	"res://Resources/Enemies/VampireLord.tres",
	"res://Resources/Enemies/CaveTroll.tres",
	"res://Resources/Enemies/Wraith.tres",
	"res://Resources/Enemies/OgreChief.tres",
]

## Bosses appear in this order; the last one repeats.
const BOSS_PATHS: Array[String] = [
	"res://Resources/Enemies/RedDragon.tres",
	"res://Resources/Enemies/EldritchHorror.tres",
	"res://Resources/Enemies/AncientWyrm.tres",
]

## Boss loot is drawn from this pool without repeats.
const BOSS_LOOT: Array[StringName] = [&"third_eye", &"opportunity", &"crown_of_honor"]

# Loaded on first use rather than preloaded: the trinket scripts refer to GameRules, which
# refers to this class, so preloading here would create a load cycle.
static var _trinkets: Array[Trinket] = []
static var _mobs: Array[Mob] = []
static var _bosses: Array[Boss] = []


static func trinkets() -> Array[Trinket]:
	if _trinkets.is_empty():
		for path in TRINKET_PATHS:
			_trinkets.append(load(path) as Trinket)
	return _trinkets


static func mobs() -> Array[Mob]:
	if _mobs.is_empty():
		for path in MOB_PATHS:
			_mobs.append(load(path) as Mob)
	return _mobs


static func bosses() -> Array[Boss]:
	if _bosses.is_empty():
		for path in BOSS_PATHS:
			_bosses.append(load(path) as Boss)
	return _bosses


static func starting_dice() -> Array[PackedInt32Array]:
	var c := Face.Kind.COMBAT
	var g := Face.Kind.GOLD
	var k := Face.Kind.CUNNING
	return [
		PackedInt32Array([Face.make(c, 1), Face.make(c, 1), Face.make(c, 1), Face.make(g, 1), Face.make(g, 1), Face.make(k, 1)]),
		PackedInt32Array([Face.make(c, 1), Face.make(c, 1), Face.make(g, 1), Face.make(g, 1), Face.make(g, 1), Face.make(k, 1)]),
	]


## The die bought from the market or granted by Opportunity.
static func basic_die() -> PackedInt32Array:
	var c := Face.Kind.COMBAT
	var g := Face.Kind.GOLD
	var k := Face.Kind.CUNNING
	return PackedInt32Array([Face.make(c, 1), Face.make(c, 1), Face.make(g, 1), Face.make(g, 1), Face.make(k, 1), Face.make(k, 1)])


static func face_price(face: int) -> int:
	for entry: Array in FACE_CATALOG:
		if Face.make(entry[0], entry[1]) == face:
			return entry[2]
	return 0


static func market_deck() -> PackedInt32Array:
	var deck := PackedInt32Array()
	for entry: Array in FACE_CATALOG:
		for _i in entry[3]:
			deck.append(Face.make(entry[0], entry[1]))
	return deck


static func trinket(id: StringName) -> Trinket:
	for t in trinkets():
		if t.id == id:
			return t
	return null


static func mob(id: StringName) -> Mob:
	for m in mobs():
		if m.id == id:
			return m
	return null


static func boss(id: StringName) -> Boss:
	for b in bosses():
		if b.id == id:
			return b
	return null
