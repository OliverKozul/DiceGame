extends Node
## Thin wrapper around the GodotSteam singleton. Steam is looked up at runtime, so the
## project also runs in stock Godot, where only direct IP connections are offered.

signal lobby_created(lobby_id: int)
signal lobby_joined(lobby_id: int, error: String)
signal join_requested(lobby_id: int)
## The answer to request_public_lobbies(): [{"lobby", "name", "seats", "turns"}].
signal public_lobbies_found(lobbies: Array[Dictionary])

## 480 is Valve's shared test app (Spacewar); lobbies are tagged so we only see our own.
const APP_ID := 480
const GAME_TAG := "DiceGame"
const RESULT_OK := 1
const ENTER_SUCCESS := 1
const LOBBY_FRIENDS_ONLY := 1
const LOBBY_PUBLIC := 2
const LOBBY_DISTANCE_WORLDWIDE := 3
const LOBBY_COMPARE_EQUAL := 0
const LOBBIES_LISTED := 50
const FRIEND_FLAG_IMMEDIATE := 4

var available := false
## What the menu says about Steam, in the player's language.
var status: String:
	get:
		return tr(_status_key).format({"value": _status_value})
var lobby_id := 0
var _steam: Object
## The status as a msgid and the value it mentions (the player's name or an error).
var _status_key := Loc.n("Steam is not available in this build.")
var _status_value := ""
## The rich presence last set, so only changes reach Steam.
var _presence: Dictionary = {}


func _ready() -> void:
	set_process(false)
	if not Engine.has_singleton("Steam"):
		return
	_steam = Engine.get_singleton("Steam")
	var result: Dictionary = _steam.call("steamInitEx", APP_ID, false)
	match int(result.get("status", -1)):
		0:
			pass
		2:
			_status_key = Loc.n("Steam isn't running. Start Steam to host or join online tables.")
			return
		3:
			_status_key = Loc.n("Steam needs an update before you can play online.")
			return
		_:
			_status_key = Loc.n("Steam is unavailable: {value}")
			_status_value = str(result.get("verbal", "?"))
			return
	available = true
	_status_key = Loc.n("Signed in to Steam as {value}.")
	_status_value = persona_name()
	_steam.connect("lobby_created", _on_lobby_created)
	_steam.connect("lobby_joined", _on_lobby_joined)
	_steam.connect("join_requested", _on_join_requested)
	_steam.connect("join_game_requested", _on_join_game_requested)
	_steam.connect("lobby_match_list", _on_lobby_match_list)
	_steam.call("initRelayNetworkAccess")
	set_process(true)


func _process(_delta: float) -> void:
	_steam.call("run_callbacks")


func persona_name() -> String:
	return _steam.call("getPersonaName") if available else ""


func steam_id() -> int:
	return _steam.call("getSteamID") if available else 0


## Sets the keys of `values` and clears the keys set last time that it no longer has. Text shown
## to friends comes from the tokens in steam/rich_presence.vdf.
func set_presence(values: Dictionary) -> void:
	if not available or values == _presence:
		return
	for key: String in _presence:
		if not values.has(key):
			_steam.call("setRichPresence", key, "")
	for key: String in values:
		if _presence.get(key) != values[key]:
			_steam.call("setRichPresence", key, values[key])
	_presence = values.duplicate()


## Unlocks achievements (ids from AchievementRules). Steam shows its own notification.
func unlock_achievements(ids: Array[StringName]) -> void:
	if not available or ids.is_empty():
		return
	for id in ids:
		_steam.call("setAchievement", String(id))
	_steam.call("storeStats")


## Host: who may find the lobby, how many people may join it, and what the lobby list shows.
func update_lobby(public: bool, member_limit: int, info: Dictionary) -> void:
	if not available or lobby_id == 0:
		return
	_steam.call("setLobbyType", lobby_id, LOBBY_PUBLIC if public else LOBBY_FRIENDS_ONLY)
	_steam.call("setLobbyMemberLimit", lobby_id, member_limit)
	for key: String in info:
		_steam.call("setLobbyData", lobby_id, key, info[key])


## Asks Steam for public tables of this version of the game; public_lobbies_found answers.
func request_public_lobbies() -> void:
	if not available:
		return
	_steam.call("addRequestLobbyListStringFilter", "game", GAME_TAG, LOBBY_COMPARE_EQUAL)
	_steam.call("addRequestLobbyListStringFilter", "protocol", str(Network.PROTOCOL), LOBBY_COMPARE_EQUAL)
	_steam.call("addRequestLobbyListDistanceFilter", LOBBY_DISTANCE_WORLDWIDE)
	_steam.call("addRequestLobbyListResultCountFilter", LOBBIES_LISTED)
	_steam.call("requestLobbyList")


func create_lobby(max_members: int) -> void:
	_steam.call("createLobby", LOBBY_FRIENDS_ONLY, max_members)


func join_lobby(id: int) -> void:
	_steam.call("joinLobby", id)


func leave_lobby() -> void:
	if available and lobby_id != 0:
		_steam.call("leaveLobby", lobby_id)
	lobby_id = 0


func set_joinable(joinable: bool) -> void:
	if available and lobby_id != 0:
		_steam.call("setLobbyJoinable", lobby_id, joinable)


func invite_friends() -> void:
	if available and lobby_id != 0:
		_steam.call("activateGameOverlayInviteDialog", lobby_id)


func lobby_owner(id: int) -> int:
	return _steam.call("getLobbyOwner", id)


## Lobbies of friends who are playing this game right now: [{"lobby": int, "name": String}].
func friend_lobbies() -> Array[Dictionary]:
	var lobbies: Array[Dictionary] = []
	if not available:
		return lobbies
	var app_id: int = _steam.call("getAppID")
	var count: int = _steam.call("getFriendCount", FRIEND_FLAG_IMMEDIATE)
	for i in count:
		var friend: int = _steam.call("getFriendByIndex", i, FRIEND_FLAG_IMMEDIATE)
		var game: Dictionary = _steam.call("getFriendGamePlayed", friend)
		var lobby := int(game.get("lobby", 0))
		if int(game.get("id", 0)) == app_id and lobby > 0:
			lobbies.append({"lobby": lobby, "name": _steam.call("getFriendPersonaName", friend)})
	return lobbies


## A new SteamMultiplayerPeer (typed loosely: the class only exists in GodotSteam builds).
func make_peer() -> MultiplayerPeer:
	return ClassDB.instantiate("SteamMultiplayerPeer") as MultiplayerPeer


## Lobby id passed on the command line when Steam launches the game from an invite.
func launch_lobby() -> int:
	var args := OS.get_cmdline_args()
	var index := args.find("+connect_lobby")
	if index >= 0 and index + 1 < args.size() and args[index + 1].is_valid_int():
		return args[index + 1].to_int()
	return 0


func _on_lobby_created(result: int, id: int) -> void:
	if result != RESULT_OK:
		lobby_created.emit(0)
		return
	lobby_id = id
	_steam.call("setLobbyData", id, "game", GAME_TAG)
	_steam.call("setLobbyData", id, "protocol", str(Network.PROTOCOL))
	lobby_created.emit(id)


func _on_lobby_joined(id: int, _permissions: int, _locked: bool, response: int) -> void:
	if response != ENTER_SUCCESS:
		lobby_joined.emit(id, _enter_error(response))
		return
	lobby_id = id
	# Steam also reports the creator as joining their own lobby; nothing to check then.
	if lobby_owner(id) == steam_id():
		return
	if _steam.call("getLobbyData", id, "game") != GAME_TAG:
		leave_lobby()
		lobby_joined.emit(id, tr("That lobby is not a game of this kind."))
		return
	if _steam.call("getLobbyData", id, "protocol") != str(Network.PROTOCOL):
		leave_lobby()
		lobby_joined.emit(id, tr("That lobby runs a different version of the game."))
		return
	lobby_joined.emit(id, "")


## Why Steam refused to let us into a lobby, translated.
func _enter_error(response: int) -> String:
	match response:
		2:
			return tr("That lobby no longer exists.")
		3:
			return tr("You are not allowed to join that lobby.")
		4:
			return tr("That lobby is full.")
	return tr("Could not join the lobby (code {code}).").format({"code": response})


func _on_join_requested(id: int, _friend: int) -> void:
	join_requested.emit(id)


## "Join game" on a friend's rich presence: the connect string this game set for them.
func _on_join_game_requested(_friend: int, connect_string: String) -> void:
	var parts := connect_string.split(" ", false)
	var index := parts.find("+connect_lobby")
	if index >= 0 and index + 1 < parts.size() and parts[index + 1].is_valid_int():
		join_requested.emit(parts[index + 1].to_int())


func _on_lobby_match_list(found: Array) -> void:
	var lobbies: Array[Dictionary] = []
	for id: int in found:
		lobbies.append({"lobby": id, "name": _steam.call("getLobbyData", id, "host"),
			"seats": _steam.call("getLobbyData", id, "seats"), "turns": _steam.call("getLobbyData", id, "turns")})
	public_lobbies_found.emit(lobbies)
