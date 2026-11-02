extends Node
## Owns the connection and the pre-game room: hosting and joining (offline, direct IP or
## Steam), the version handshake, the roster of seats, bots, starting the game and every
## way of leaving it. The host is the only authority; clients only ever send requests.

signal roster_changed
signal room_changed(in_room: bool)
signal status_changed(text: String)

enum Mode { NONE, OFFLINE, ENET, STEAM }

## Bump whenever the network messages or rules change incompatibly.
const PROTOCOL := 1
const PORT := 7777
const HELLO_TIMEOUT := 10.0
## ENet drops a silent peer after this long (ms), so a crashed player is replaced quickly.
const ENET_TIMEOUT_MIN := 5000
const ENET_TIMEOUT_MAX := 15000
const KICK_DELAY := 0.5
const NAME_MAX_LENGTH := 20
const MENU_SCENE := "res://Scenes/Menu.tscn"
const GAME_SCENE := "res://Scenes/Game.tscn"
const BOT_NAMES: Array[String] = ["Ada", "Bram", "Cora", "Dax", "Elin", "Fenn", "Gus", "Hela"]

var mode := Mode.NONE
## Seats in order: {"id": int, "name": String, "bot": bool, "connected": bool}.
## Humans use their peer id, bots negative ids.
var roster: Array[Dictionary] = []
var in_game := false
var local_name := "Player"
## Why the last session ended; the menu shows it.
var leave_reason := ""

var _next_bot_id := -1
var _awaiting_hello: Dictionary[int, bool] = {}
var _kick_reason := ""


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	SteamService.lobby_created.connect(_on_steam_lobby_created)
	SteamService.lobby_joined.connect(_on_steam_lobby_joined)
	SteamService.join_requested.connect(_on_steam_join_requested)


# Say goodbye properly on exit so the host replaces this seat at once instead of waiting
# for the connection to time out.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and mode != Mode.NONE:
		_close()


func _exit_tree() -> void:
	if mode != Mode.NONE:
		_close()


func is_host() -> bool:
	return mode != Mode.NONE and multiplayer.is_server()


func local_id() -> int:
	return multiplayer.get_unique_id()


func in_room() -> bool:
	return mode != Mode.NONE


## True while a message can still be delivered to this peer (not merely half-disconnected).
func peer_is_reachable(id: int) -> bool:
	if not multiplayer.get_peers().has(id):
		return false
	var enet := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if enet:
		var packet_peer := enet.get_peer(id)
		return packet_peer != null and packet_peer.get_state() == ENetPacketPeer.STATE_CONNECTED
	return true


func can_start() -> bool:
	return is_host() and not in_game and roster.size() >= Content.MIN_SEATS


func human_count() -> int:
	return roster.filter(func(seat: Dictionary) -> bool: return not seat.bot).size()


# --- Starting a session -----------------------------------------------------

func play_offline(player_name: String, bots: int, seed_value: int = -1, max_turns: int = Content.MAX_TURNS) -> void:
	_close()
	mode = Mode.OFFLINE
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	_open_room(player_name)
	for _i in bots:
		add_bot()
	start_game(seed_value, max_turns)


func host_enet(player_name: String) -> String:
	_close()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(PORT, Content.MAX_SEATS - 1)
	if err != OK:
		return "Could not host on port %d: %s." % [PORT, error_string(err)]
	mode = Mode.ENET
	_use_peer(peer)
	_open_room(player_name)
	return ""


func join_enet(player_name: String, address: String) -> String:
	_close()
	address = address.strip_edges()
	if address.is_empty():
		return "Enter the host's IP address."
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, PORT)
	if err != OK:
		return "Could not connect: %s." % error_string(err)
	mode = Mode.ENET
	local_name = _clean_name(player_name)
	_use_peer(peer)
	status_changed.emit("Connecting to %s…" % address)
	return ""


func host_steam() -> String:
	if not SteamService.available:
		return SteamService.status
	_close()
	mode = Mode.STEAM
	local_name = _clean_name(SteamService.persona_name())
	SteamService.create_lobby(Content.MAX_SEATS)
	status_changed.emit("Creating a Steam lobby…")
	return ""


func join_steam(lobby_id: int) -> String:
	if not SteamService.available:
		return SteamService.status
	_close()
	mode = Mode.STEAM
	local_name = _clean_name(SteamService.persona_name())
	SteamService.join_lobby(lobby_id)
	status_changed.emit("Joining the lobby…")
	return ""


func invite_friends() -> void:
	SteamService.invite_friends()


func leave(reason: String = "") -> void:
	_close()
	leave_reason = reason
	room_changed.emit(false)
	if reason != "":
		status_changed.emit(reason)
	_change_scene(MENU_SCENE)


# --- Room -------------------------------------------------------------------

func add_bot() -> void:
	if not is_host() or in_game or roster.size() >= Content.MAX_SEATS:
		return
	var used := roster.map(func(seat: Dictionary) -> String: return seat.name)
	var bot_name := "Bot"
	for candidate in BOT_NAMES:
		if not used.has("Bot " + candidate):
			bot_name = "Bot " + candidate
			break
	roster.append({"id": _next_bot_id, "name": bot_name, "bot": true, "connected": true})
	_next_bot_id -= 1
	_publish_roster()


func remove_bot() -> void:
	if not is_host() or in_game:
		return
	for i in range(roster.size() - 1, -1, -1):
		if roster[i].bot:
			roster.remove_at(i)
			_publish_roster()
			return


func start_game(seed_value: int = -1, max_turns: int = Content.MAX_TURNS) -> void:
	if not can_start():
		return
	in_game = true
	_set_locked(true)
	Session.prepare_host(roster, seed_value if seed_value >= 0 else randi(), max_turns)
	if mode != Mode.OFFLINE:
		_rpc_load_game.rpc(roster)
	_change_scene(GAME_SCENE)


## Host: brings everyone back to the room after a game. Seats of players who left are freed.
func return_to_lobby() -> void:
	if not is_host() or not in_game:
		return
	in_game = false
	roster.assign(roster.filter(func(seat: Dictionary) -> bool: return seat.connected))
	_set_locked(false)
	Session.reset()
	if mode != Mode.OFFLINE:
		_rpc_return_to_lobby.rpc(roster)
	_change_scene(MENU_SCENE)


# --- Host side ----------------------------------------------------------------

func _open_room(player_name: String) -> void:
	local_name = _clean_name(player_name)
	roster = [{"id": local_id(), "name": local_name, "bot": false, "connected": true}]
	room_changed.emit(true)
	roster_changed.emit()


func _use_peer(peer: MultiplayerPeer) -> void:
	multiplayer.multiplayer_peer = peer
	# Clients only talk to the host; nothing is relayed between them.
	(multiplayer as SceneMultiplayer).server_relay = false


func _publish_roster() -> void:
	roster_changed.emit()
	if mode != Mode.OFFLINE and multiplayer.is_server():
		_rpc_roster.rpc(roster)


func _set_locked(locked: bool) -> void:
	if mode == Mode.STEAM:
		SteamService.set_joinable(not locked)
	if multiplayer.multiplayer_peer and mode != Mode.OFFLINE:
		multiplayer.multiplayer_peer.refuse_new_connections = locked


func _seat_of(id: int) -> int:
	for i in roster.size():
		if roster[i].id == id:
			return i
	return -1


func _on_peer_connected(id: int) -> void:
	if not multiplayer.is_server():
		return
	_set_enet_timeout(id)
	_awaiting_hello[id] = true
	get_tree().create_timer(HELLO_TIMEOUT).timeout.connect(_on_hello_timeout.bind(id))


func _on_hello_timeout(id: int) -> void:
	if _awaiting_hello.erase(id):
		_disconnect_peer(id)


func _on_peer_disconnected(id: int) -> void:
	if not multiplayer.is_server():
		return
	_awaiting_hello.erase(id)
	var seat := _seat_of(id)
	if seat < 0:
		return
	if in_game:
		roster[seat].connected = false
		roster[seat].bot = true
		Session.on_peer_left(id)
	else:
		roster.remove_at(seat)
		_publish_roster()


func _kick(id: int, reason: String) -> void:
	_rpc_kicked.rpc_id(id, reason)
	get_tree().create_timer(KICK_DELAY).timeout.connect(_disconnect_peer.bind(id))


func _disconnect_peer(id: int) -> void:
	if multiplayer.multiplayer_peer and multiplayer.get_peers().has(id):
		multiplayer.multiplayer_peer.disconnect_peer(id)


func _unique_name(wanted: String) -> String:
	var used := roster.map(func(seat: Dictionary) -> String: return seat.name)
	var candidate := wanted
	var n := 2
	while used.has(candidate):
		candidate = "%s %d" % [wanted, n]
		n += 1
	return candidate


func _clean_name(raw: String) -> String:
	var cleaned := raw.strip_edges().left(NAME_MAX_LENGTH)
	return cleaned if not cleaned.is_empty() else "Player"


# --- Client side ----------------------------------------------------------------

func _set_enet_timeout(peer_id: int) -> void:
	var enet := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if enet and enet.get_peer(peer_id):
		enet.get_peer(peer_id).set_timeout(0, ENET_TIMEOUT_MIN, ENET_TIMEOUT_MAX)


func _on_connected_to_server() -> void:
	_set_enet_timeout(1)
	status_changed.emit("Connected. Waiting for the host…")
	_rpc_hello.rpc_id(1, PROTOCOL, local_name)


func _on_connection_failed() -> void:
	leave("Could not connect to the host.")


func _on_server_disconnected() -> void:
	leave(_kick_reason if not _kick_reason.is_empty() else "Lost connection to the host.")


func _on_steam_lobby_created(lobby_id: int) -> void:
	if mode != Mode.STEAM:
		return
	if lobby_id == 0:
		leave("Steam could not create a lobby.")
		return
	var peer := SteamService.make_peer()
	var err: Error = peer.call("create_host", 0)
	if err != OK:
		leave("Could not host over Steam: %s." % error_string(err))
		return
	_use_peer(peer)
	_open_room(local_name)


func _on_steam_lobby_joined(lobby_id: int, error: String) -> void:
	if mode != Mode.STEAM or is_host():
		return
	if not error.is_empty():
		leave(error)
		return
	var owner_id := SteamService.lobby_owner(lobby_id)
	if owner_id == SteamService.steam_id():
		return
	var peer := SteamService.make_peer()
	var err: Error = peer.call("create_client", owner_id, 0)
	if err != OK:
		leave("Could not connect over Steam: %s." % error_string(err))
		return
	_use_peer(peer)
	status_changed.emit("Connecting to the host…")


func _on_steam_join_requested(lobby_id: int) -> void:
	if in_game:
		return
	join_steam(lobby_id)


func _close() -> void:
	SteamService.leave_lobby()
	if multiplayer.multiplayer_peer and multiplayer.multiplayer_peer is not OfflineMultiplayerPeer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	mode = Mode.NONE
	roster = []
	in_game = false
	_awaiting_hello.clear()
	_kick_reason = ""
	_next_bot_id = -1
	Session.reset()


func _change_scene(path: String) -> void:
	var current := get_tree().current_scene
	if current and current.scene_file_path == path and path == MENU_SCENE:
		roster_changed.emit()
		return
	get_tree().change_scene_to_file.call_deferred(path)


# --- RPCs -------------------------------------------------------------------------

@rpc("any_peer", "call_remote", "reliable")
func _rpc_hello(protocol: int, player_name: String) -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	if not _awaiting_hello.erase(id):
		return
	if protocol != PROTOCOL:
		_kick(id, "The host runs a different version of the game.")
	elif in_game:
		_kick(id, "That game has already started.")
	elif roster.size() >= Content.MAX_SEATS:
		_kick(id, "The lobby is full.")
	else:
		roster.append({"id": id, "name": _unique_name(_clean_name(player_name)), "bot": false, "connected": true})
		_publish_roster()


@rpc("authority", "call_remote", "reliable")
func _rpc_roster(new_roster: Array) -> void:
	var entered := roster.is_empty()
	roster.assign(new_roster)
	if entered:
		room_changed.emit(true)
	roster_changed.emit()


@rpc("authority", "call_remote", "reliable")
func _rpc_kicked(reason: String) -> void:
	_kick_reason = reason


@rpc("authority", "call_remote", "reliable")
func _rpc_load_game(new_roster: Array) -> void:
	roster.assign(new_roster)
	in_game = true
	Session.reset()
	_change_scene(GAME_SCENE)


@rpc("authority", "call_remote", "reliable")
func _rpc_return_to_lobby(new_roster: Array) -> void:
	roster.assign(new_roster)
	in_game = false
	Session.reset()
	_change_scene(MENU_SCENE)
