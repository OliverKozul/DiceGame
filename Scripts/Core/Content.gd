class_name Content
extends RefCounted
## Static registry of all game content and tuning numbers. Ids, not resources, travel over
## the network; both host and clients look them up here.

const STARTING_HP := 14
const MAX_TURNS := 15
const MIN_SEATS := 3
const MAX_SEATS := 6
const MOB_SLOTS := 3
const MARKET_SIZE := 5
const DIE_PRICE := 5
const REFRESH_PRICE := 1
const REROLL_CUNNING_COST := 1
const REST_HEAL := 3
## Kept words needed to complete an oath, and the renown a completed oath earns.
const OATH_LENGTH := 3
const OATH_RENOWN := 1
## Gold one renown is worth when spent.
const RENOWN_GOLD := 3
## Gold that buys one renown at the market.
const RENOWN_PRICE := 5
## Renown a hit that damages a player steals from them, if they hold more renown than the attacker.
const HIT_RENOWN_STEAL := 1
## A face can be upgraded up to this value; an upgrade costs the new value.
const UPGRADE_MAX := 5
const UPGRADE_KINDS: Array[Face.Kind] = [Face.Kind.COMBAT, Face.Kind.GOLD, Face.Kind.CUNNING, Face.Kind.GUARD, Face.Kind.HEAL]
## A boss slayer must deal at least 1/BOSS_LOOT_SHARE of the boss's health to score it and share its loot.
const BOSS_LOOT_SHARE := 4
## The game has this many acts; each act's mobs come from the tier of the same number.
const MOB_ACTS := 3
## Trophies for slaying a mob of tier 1, 2 and 3.
const MOB_TIER_SCORE: Array[int] = [1, 2, 2]
const BOSS_KILL_SCORE := 3
const KO_ATTACKER_SCORE := 1
const KO_VICTIM_PENALTY := 1

## Market face tiles: [kind, value, price, copies in the deck].
const FACE_CATALOG: Array = [
	[Face.Kind.COMBAT, 2, 2, 4],
	[Face.Kind.GOLD, 2, 2, 4],
	[Face.Kind.CUNNING, 2, 2, 3],
	[Face.Kind.GUARD, 2, 2, 3],
	[Face.Kind.COMBAT, 3, 4, 3],
	[Face.Kind.GOLD, 3, 4, 3],
	[Face.Kind.GUARD, 3, 4, 2],
	[Face.Kind.HEAL, 2, 4, 3],
	[Face.Kind.WILD, 1, 4, 3],
	[Face.Kind.COMBAT, 4, 6, 2],
	[Face.Kind.GOLD, 4, 6, 2],
	[Face.Kind.CUNNING, 3, 6, 2],
	[Face.Kind.WILD, 2, 6, 2],
	[Face.Kind.RENOWN, 1, 6, 2],
	[Face.Kind.DOUBLE, 2, 6, 2],
]

const TRINKET_PATHS: Array[String] = [
	"res://Resources/Trinkets/SharpTooth.tres",
	"res://Resources/Trinkets/BackstabDagger.tres",
	"res://Resources/Trinkets/CoinMagnet.tres",
	"res://Resources/Trinkets/GobletOfBlood.tres",
	"res://Resources/Trinkets/ThirdEye.tres",
	"res://Resources/Trinkets/Opportunity.tres",
	"res://Resources/Trinkets/CrownOfHonor.tres",
	"res://Resources/Trinkets/GoldenIdol.tres",
	"res://Resources/Trinkets/Dragonscale.tres",
	"res://Resources/Trinkets/WarBanner.tres",
	"res://Resources/Trinkets/WyrmHeart.tres",
	"res://Resources/Trinkets/LuckyCoin.tres",
	"res://Resources/Trinkets/FoxMask.tres",
	"res://Resources/Trinkets/BoneDice.tres",
	"res://Resources/Trinkets/HerbalPouch.tres",
	"res://Resources/Trinkets/HuntersHorn.tres",
	"res://Resources/Trinkets/SilverTongue.tres",
	"res://Resources/Trinkets/SmokeBomb.tres",
	"res://Resources/Trinkets/ThornedMail.tres",
	"res://Resources/Trinkets/LiarsMask.tres",
	"res://Resources/Trinkets/PhoenixFeather.tres",
	"res://Resources/Trinkets/MerchantsSeal.tres",
]

const MOB_PATHS: Array[String] = [
	"res://Resources/Enemies/RatKing.tres",
	"res://Resources/Enemies/GoblinThief.tres",
	"res://Resources/Enemies/GiantBats.tres",
	"res://Resources/Enemies/Highwayman.tres",
	"res://Resources/Enemies/VampireLord.tres",
	"res://Resources/Enemies/CaveTroll.tres",
	"res://Resources/Enemies/Werewolf.tres",
	"res://Resources/Enemies/SwampWitch.tres",
	"res://Resources/Enemies/Wraith.tres",
	"res://Resources/Enemies/OgreChief.tres",
	"res://Resources/Enemies/StoneGolem.tres",
	"res://Resources/Enemies/Lich.tres",
]

## Every boss; each one has a stage (see Boss).
const BOSS_PATHS: Array[String] = [
	"res://Resources/Enemies/RedDragon.tres",
	"res://Resources/Enemies/TrollKing.tres",
	"res://Resources/Enemies/EldritchHorror.tres",
	"res://Resources/Enemies/BoneColossus.tres",
	"res://Resources/Enemies/AncientWyrm.tres",
	"res://Resources/Enemies/DemonPrince.tres",
]
const BOSS_STAGES := 3

## Boss loot is drawn from this pool without repeats. These items are stronger than mob trinkets.
const BOSS_LOOT: Array[StringName] = [&"third_eye", &"opportunity", &"crown_of_honor", &"golden_idol",
	&"dragonscale", &"war_banner", &"wyrm_heart", &"liars_mask", &"phoenix_feather", &"merchants_seal"]

# Loaded on first use rather than preloaded: the trinket scripts refer to GameRules, which
# refers to this class, so preloading here would create a load cycle.
static var _trinkets: Array[Trinket] = []
static var _mobs: Array[Mob] = []
static var _bosses: Array[Boss] = []


## Drops the loaded content (used by test scripts before they quit).
static func clear_cache() -> void:
	_trinkets.clear()
	_mobs.clear()
	_bosses.clear()


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


## Renown an attacker holding `thief_renown` steals by damaging a player holding `victim_renown`:
## only the richer can be robbed.
static func renown_stolen(thief_renown: int, victim_renown: int) -> int:
	return mini(victim_renown, HIT_RENOWN_STEAL) if victim_renown > thief_renown else 0


## Trophies a mob is worth.
static func mob_score(card: Mob) -> int:
	return MOB_TIER_SCORE[clampi(card.tier, 1, MOB_TIER_SCORE.size()) - 1]


## The better die that Opportunity grants.
static func boss_die() -> PackedInt32Array:
	var c := Face.Kind.COMBAT
	var g := Face.Kind.GOLD
	var k := Face.Kind.CUNNING
	return PackedInt32Array([Face.make(c, 2), Face.make(c, 2), Face.make(g, 2), Face.make(g, 2), Face.make(k, 1), Face.make(k, 1)])


## The die bought from the market.
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


## Price of raising this face by one, or 0 if it cannot be upgraded.
static func upgrade_price(face: int) -> int:
	var value := Face.value_of(face)
	if not UPGRADE_KINDS.has(Face.kind_of(face)) or value >= UPGRADE_MAX:
		return 0
	return value + 1


## Damage a player must deal to a boss with this much health to score it and share its loot.
static func boss_loot_threshold(boss_max_hp: int) -> int:
	return maxi(1, ceili(boss_max_hp / float(BOSS_LOOT_SHARE)))


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


## The bosses of one stage, in BOSS_PATHS order.
static func bosses_of_stage(stage: int) -> Array[Boss]:
	var found: Array[Boss] = []
	for b in bosses():
		if b.stage == stage:
			found.append(b)
	return found


static func boss(id: StringName) -> Boss:
	for b in bosses():
		if b.id == id:
			return b
	return null
