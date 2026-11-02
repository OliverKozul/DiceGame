extends Node
## Thin wrapper around the GodotSteam singleton. Steam is looked up at runtime, so the
## project also runs in stock Godot, where only direct IP connections are offered.

signal lobby_created(lobby_id: int)
signal lobby_joined(lobby_id: int, error: String)
signal join_requested(lobby_id: int)

## 480 is Valve's shared test app (Spacewar); lobbies are tagged so we only see our own.
const APP_ID := 480
const GAME_TAG := "DiceGame"
const RESULT_OK := 1
const ENTER_SUCCESS := 1
const LOBBY_FRIENDS_ONLY := 1
const FRIEND_FLAG_IMMEDIATE := 4
const ENTER_ERRORS: Dictionary = {
	2: "That lobby no longer exists.",
	3: "You are not allowed to join that lobby.",
	4: "That lobby is full.",
}

var available := false
var status := "Steam is not available in this build."
var lobby_id := 0
var _steam: Object


func _ready() -> void:
	set_process(false)
	if not Engine.has_singleton("Steam"):
		return
	_steam = Engine.get_singleton("Steam")
	var result: Dictionary = _steam.call("steamInitEx", APP_ID, false)
	if int(result.get("status", -1)) != 0:
		status = "Steam unavailable: %s" % result.get("verbal", "is Steam running?")
		return
	available = true
	status = "Signed in to Steam as %s." % persona_name()
	_steam.connect("lobby_created", _on_lobby_created)
	_steam.connect("lobby_joined", _on_lobby_joined)
	_steam.connect("join_requested", _on_join_requested)
	_steam.call("initRelayNetworkAccess")
	set_process(true)


func _process(_delta: float) -> void:
	_steam.call("run_callbacks")


func persona_name() -> String:
	return _steam.call("getPersonaName") if available else ""


func steam_id() -> int:
	return _steam.call("getSteamID") if available else 0


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
		lobby_joined.emit(id, ENTER_ERRORS.get(response, "Could not join the lobby (code %d)." % response))
		return
	lobby_id = id
	# Steam also reports the creator as joining their own lobby; nothing to check then.
	if lobby_owner(id) == steam_id():
		return
	if _steam.call("getLobbyData", id, "game") != GAME_TAG:
		leave_lobby()
		lobby_joined.emit(id, "That lobby is not a DiceGame lobby.")
		return
	if _steam.call("getLobbyData", id, "protocol") != str(Network.PROTOCOL):
		leave_lobby()
		lobby_joined.emit(id, "That lobby runs a different version of the game.")
		return
	lobby_joined.emit(id, "")


func _on_join_requested(id: int, _friend: int) -> void:
	join_requested.emit(id)
