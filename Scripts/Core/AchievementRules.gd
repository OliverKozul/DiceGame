class_name AchievementRules
extends RefCounted
## Which achievements a finished game earned for one player. Pure, so it can be tested without
## Steam. The ids are the API names to enter in Steamworks (steam/SETUP.md lists them all).

const IDS: Array[StringName] = [
	&"ACH_FIRST_GAME", &"ACH_FIRST_WIN", &"ACH_BEAT_HARD", &"ACH_WIN_ONLINE", &"ACH_WORD_IS_BOND",
	&"ACH_FAITHLESS", &"ACH_THREE_OATHS", &"ACH_AMBUSH_KO", &"ACH_BOSS_SLAIN", &"ACH_LAST_BOSS",
	&"ACH_WINNING_BID", &"ACH_FIVE_DICE", &"ACH_MASTER_SMITH", &"ACH_COLLECTOR", &"ACH_COMEBACK",
	&"ACH_ROBBER",
]
const ONLINE_HUMANS := 3
## Kept words needed for "not one broken word": most of a full game, a knockout or two allowed.
const BOND_WORDS := 9
const FIVE_DICE := 5
const COLLECTION := 5
const STOLEN_RENOWN := 5
const OATHS := 3


static func earned(view: GameState, me: int, difficulty: int, offline: bool) -> Array[StringName]:
	var ids: Array[StringName] = []
	var stats: Dictionary = view.recap.get("players", {}).get(me, {})
	var p := view.player(me)
	if stats.is_empty() or p == null or view.standings.is_empty():
		return ids
	var won: bool = view.standings[0] == me
	ids.append(&"ACH_FIRST_GAME")
	if won:
		ids.append(&"ACH_FIRST_WIN")
		if offline and difficulty == BotTable.Difficulty.HARD:
			ids.append(&"ACH_BEAT_HARD")
		if int(view.recap.get("humans", 0)) >= ONLINE_HUMANS:
			ids.append(&"ACH_WIN_ONLINE")
		if stats.broke > stats.kept:
			ids.append(&"ACH_FAITHLESS")
		if stats.knocked_out > 0:
			ids.append(&"ACH_COMEBACK")
	if stats.broke == 0 and stats.kept >= BOND_WORDS:
		ids.append(&"ACH_WORD_IS_BOND")
	if stats.oaths >= OATHS:
		ids.append(&"ACH_THREE_OATHS")
	if stats.ambush_kos > 0:
		ids.append(&"ACH_AMBUSH_KO")
	if stats.bosses > 0:
		ids.append(&"ACH_BOSS_SLAIN")
	if stats.last_stage_bosses > 0:
		ids.append(&"ACH_LAST_BOSS")
	if stats.auctions > 0:
		ids.append(&"ACH_WINNING_BID")
	if p.dice.size() >= FIVE_DICE:
		ids.append(&"ACH_FIVE_DICE")
	if _has_top_face(p):
		ids.append(&"ACH_MASTER_SMITH")
	if p.trinkets.size() >= COLLECTION:
		ids.append(&"ACH_COLLECTOR")
	if stats.stolen >= STOLEN_RENOWN:
		ids.append(&"ACH_ROBBER")
	return ids


static func _has_top_face(p: PlayerState) -> bool:
	for die in p.dice:
		for face in die:
			if Face.value_of(face) >= Content.UPGRADE_MAX:
				return true
	return false


## The achievement's name in the player's language.
static func title(id: StringName) -> String:
	match id:
		&"ACH_FIRST_GAME":
			return Loc.t("A Seat at the Table")
		&"ACH_FIRST_WIN":
			return Loc.t("Toast of the Tavern")
		&"ACH_BEAT_HARD":
			return Loc.t("Nobody's Fool")
		&"ACH_WIN_ONLINE":
			return Loc.t("Among Friends")
		&"ACH_WORD_IS_BOND":
			return Loc.t("My Word Is My Bond")
		&"ACH_FAITHLESS":
			return Loc.t("Faithless")
		&"ACH_THREE_OATHS":
			return Loc.t("Thrice Sworn")
		&"ACH_AMBUSH_KO":
			return Loc.t("Knife in the Dark")
		&"ACH_BOSS_SLAIN":
			return Loc.t("Boss Slayer")
		&"ACH_LAST_BOSS":
			return Loc.t("Bane of the Ancients")
		&"ACH_WINNING_BID":
			return Loc.t("Going, Going, Gone")
		&"ACH_FIVE_DICE":
			return Loc.t("A Fistful of Dice")
		&"ACH_MASTER_SMITH":
			return Loc.t("Master Smith")
		&"ACH_COLLECTOR":
			return Loc.t("Magpie")
		&"ACH_COMEBACK":
			return Loc.t("Back from the Floor")
		&"ACH_ROBBER":
			return Loc.t("Highway Robbery")
	return String(id)
