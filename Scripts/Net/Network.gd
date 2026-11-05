extends Node
## Owns the connection and the pre-game room: hosting and joining (offline, direct IP or
## Steam), the version handshake, the roster of seats, bots, starting the game and every
## way of leaving it. The host is the only authority; clients only ever send requests.
##
## Rejoining: when a game starts, the host gives every remote player a secret token for their
## seat. A player who loses the connection keeps the table on screen and reconnects on their
## own for a while; a bot plays their seat until they are back. The token is also saved to
## disk, so after a crash the main menu offers to rejoin. A seat is identified by its player
## id (the peer id the player had when the game started); after a rejoin the host maps the
## player's new peer id to it.

signal roster_changed
signal room_changed(in_room: bool)
signal status_changed(text: String)
## Reconnecting started, made another attempt, or ended (see `reconnecting`).
signal reconnect_changed

enum Mode { NONE, OFFLINE, ENET, STEAM }

## Bump whenever the network messages or rules change incompatibly.
const PROTOCOL := 2
const PORT := 7777
const HELLO_TIMEOUT := 10.0
## ENet drops a silent peer after this long (ms), so a crashed player is replaced quickly.
const ENET_TIMEOUT_MIN := 5000
const ENET_TIMEOUT_MAX := 15000
## Connections the host accepts beyond the seats: a returning player may connect again
## before the host has noticed that their old connection is gone.
const SPARE_CONNECTIONS := 3
const KICK_DELAY := 0.5
const NAME_MAX_LENGTH := 20
## How long a client keeps trying to get back to the table, and how often.
const RECONNECT_WINDOW := 90.0
const RECONNECT_INTERVAL := 3.0
## Where the seat of the game in progress is remembered, and for how long it is worth offering.
const REJOIN_PATH := "user://rejoin.cfg"
const REJOIN_MAX_AGE := 4 * 3600
const MENU_SCENE := "res://Scenes/Menu.tscn"
const GAME_SCENE := "res://Scenes/Game.tscn"
const BOT_NAMES: Array[String] = ["Ada", "Bram", "Cora", "Dax", "Elin", "Fenn", "Gus", "Hela"]

var mode := Mode.NONE
## Seats in order: {"id": int, "name": String, "bot": bool, "connected": bool}.
## Humans use their player id, bots negative ids.
var roster: Array[Dictionary] = []
var in_game := false
var local_name := "Player"
## Why the last session ended; the menu shows it.
var leave_reason := ""
## True while this client is trying to get back to a game it lost the connection to.
var reconnecting := false
var reconnect_attempt := 0

var _next_bot_id := -1
var _awaiting_hello: Dictionary[int, bool] = {}
var _kick_reason := ""
## The local player's seat in the current game (0 outside a game).
var _my_pid := 0
## Host: each remote seat's token, and which peer plays which seat (both ways).
var _tokens: Dictionary[int, String] = {}
var _peer_of_pid: Dictionary[int, int] = {}
var _pid_of_peer: Dictionary[int, int] = {}
## Client: how to get back to the game in progress:
## {"token", "pid", "mode", "address", "lobby", "name", "time"}.
var _ticket: Dictionary = {}
var _reconnect_until := 0.0
## Where the ticket is saved; tests running several players on one machine give each its own.
var rejoin_path := REJOIN_PATH
var _retry_timer := Timer.new()


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	SteamService.lobby_created.connect(_on_steam_lobby_created)
	SteamService.lobby_joined.connect(_on_steam_lobby_joined)
	SteamService.join_requested.connect(_on_steam_join_requested)
	_retry_timer.one_shot = true
	_retry_timer.timeout.connect(_attempt_reconnect)
	add_child(_retry_timer)


# Say goodbye properly on exit so the host replaces this seat at once instead of waiting
# for the connection to time out.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and mode != Mode.NONE:
		_close()


func _exit_tree() -> void:
	if mode != Mode.NONE:
		_close()


func is_host() -> bool:
	return mode != Mode.NONE and not reconnecting and multiplayer.is_server()


## This connection's peer id (the seat id in the room before a game).
func local_id() -> int:
	return multiplayer.get_unique_id()


## The local player's seat id in the game.
func local_pid() -> int:
	return _my_pid if _my_pid != 0 else local_id()


## Host: the peer currently playing a seat.
func peer_of(pid: int) -> int:
	return _peer_of_pid.get(pid, pid)


## Host: the seat a peer plays (0 if none).
func pid_of(peer: int) -> int:
	if in_game:
		return _pid_of_peer.get(peer, 0)
	return peer


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


## Returns "" or why hosting failed (translated).
func host_enet(player_name: String) -> String:
	_close()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(PORT, Content.MAX_SEATS - 1 + SPARE_CONNECTIONS)
	if err != OK:
		return tr("Could not host on port {port}: {error}.").format({"port": PORT, "error": error_string(err)})
	mode = Mode.ENET
	_use_peer(peer)
	_open_room(player_name)
	return ""


## Returns "" or why joining failed (translated).
func join_enet(player_name: String, address: String) -> String:
	_close()
	address = address.strip_edges()
	if address.is_empty():
		return tr("Enter the host's IP address.")
	var err := _connect_enet(address)
	if err != OK:
		return tr("Could not connect: {error}.").format({"error": error_string(err)})
	mode = Mode.ENET
	local_name = _clean_name(player_name)
	_ticket = {"mode": Mode.ENET, "address": address}
	status_changed.emit(tr("Connecting to {address}…").format({"address": address}))
	return ""


func host_steam() -> String:
	if not SteamService.available:
		return SteamService.status
	_close()
	mode = Mode.STEAM
	local_name = _clean_name(SteamService.persona_name())
	SteamService.create_lobby(Content.MAX_SEATS)
	status_changed.emit(tr("Creating a Steam lobby…"))
	return ""


func join_steam(lobby_id: int) -> String:
	if not SteamService.available:
		return SteamService.status
	_close()
	mode = Mode.STEAM
	local_name = _clean_name(SteamService.persona_name())
	_ticket = {"mode": Mode.STEAM, "lobby": lobby_id}
	SteamService.join_lobby(lobby_id)
	status_changed.emit(tr("Joining the lobby…"))
	return ""


func invite_friends() -> void:
	SteamService.invite_friends()


## Leaves the room or game on purpose. `reason` (already translated) is shown in the menu.
func leave(reason: String = "") -> void:
	_close()
	_forget_ticket()
	leave_reason = reason
	room_changed.emit(false)
	if reason != "":
		status_changed.emit(reason)
	_change_scene(MENU_SCENE)


# --- Rejoining -----------------------------------------------------------------

## Whether a game this player was in can still be rejoined (after a crash or a quit).
func saved_rejoin_available() -> bool:
	return not _load_ticket().is_empty()


## Tries to get back into the saved game from the main menu.
func rejoin_saved_game() -> void:
	var ticket := _load_ticket()
	if ticket.is_empty():
		return
	_close()
	_ticket = ticket
	local_name = str(ticket.get("name", local_name))
	in_game = true
	_begin_reconnect()


## Stops trying to reconnect and returns to the menu.
func give_up_reconnecting() -> void:
	leave(tr("You left the game."))


## Development: drops the connection as if the network had failed, then reconnects.
func simulate_connection_loss() -> void:
	if not in_game or is_host() or _ticket.is_empty() or mode == Mode.OFFLINE:
		return
	_begin_reconnect()


func _begin_reconnect() -> void:
	_drop_peer()
	mode = int(_ticket.get("mode", Mode.ENET)) as Mode
	reconnecting = true
	reconnect_attempt = 0
	_reconnect_until = Time.get_ticks_msec() / 1000.0 + RECONNECT_WINDOW
	status_changed.emit(tr("Lost the connection to the host. Reconnecting…"))
	reconnect_changed.emit()
	_attempt_reconnect()


func _attempt_reconnect() -> void:
	if not reconnecting:
		return
	if Time.get_ticks_msec() / 1000.0 > _reconnect_until:
		leave(tr("Could not get back to the table."))
		return
	reconnect_attempt += 1
	reconnect_changed.emit()
	_drop_peer()
	if mode == Mode.STEAM:
		if not SteamService.available:
			leave(SteamService.status)
			return
		SteamService.join_lobby(int(_ticket.get("lobby", 0)))
	elif _connect_enet(str(_ticket.get("address", ""))) != OK:
		_retry_timer.start(RECONNECT_INTERVAL)


func _connect_enet(address: String) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, PORT)
	if err == OK:
		_use_peer(peer)
	return err


func _save_ticket() -> void:
	var file := ConfigFile.new()
	for key: String in _ticket:
		file.set_value("rejoin", key, _ticket[key])
	file.save(rejoin_path)


func _load_ticket() -> Dictionary:
	var file := ConfigFile.new()
	if file.load(rejoin_path) != OK or not file.has_section("rejoin"):
		return {}
	var ticket := {}
	for key in file.get_section_keys("rejoin"):
		ticket[key] = file.get_value("rejoin", key)
	var age := Time.get_unix_time_from_system() - float(ticket.get("time", 0.0))
	if str(ticket.get("token", "")).is_empty() or age < 0.0 or age > REJOIN_MAX_AGE:
		return {}
	return ticket


func _forget_ticket() -> void:
	_ticket = {}
	if FileAccess.file_exists(rejoin_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(rejoin_path))


## The game in progress has ended: there is nothing left to rejoin.
func game_finished() -> void:
	if not is_host():
		_forget_ticket()


# --- Room -------------------------------------------------------------------

func add_bot() -> void:
	if not is_host() or in_game or roster.size() >= Content.MAX_SEATS:
		return
	var used := roster.map(func(seat: Dictionary) -> String: return seat.name)
	var bot_name := tr("Bot")
	for candidate in BOT_NAMES:
		var full := tr("Bot {name}").format({"name": candidate})
		if not used.has(full):
			bot_name = full
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
	_tokens.clear()
	_peer_of_pid.clear()
	_pid_of_peer.clear()
	var crypto := Crypto.new()
	for seat in roster:
		if not seat.bot:
			_peer_of_pid[seat.id] = seat.id
			_pid_of_peer[seat.id] = seat.id
	_update_lock()
	Session.prepare_host(roster, seed_value if seed_value >= 0 else randi(), max_turns)
	if mode != Mode.OFFLINE:
		for seat in roster:
			if not seat.bot and seat.id != local_id():
				_tokens[seat.id] = crypto.generate_random_bytes(16).hex_encode()
				_rpc_load_game.rpc_id(seat.id, roster, _tokens[seat.id])
	_change_scene(GAME_SCENE)


## Host: brings everyone back to the room after a game. Seats of players who left are freed.
func return_to_lobby() -> void:
	if not is_host() or not in_game:
		return
	in_game = false
	roster.assign(roster.filter(func(seat: Dictionary) -> bool: return seat.connected))
	# In the room a seat is known by its player's current connection.
	for seat in roster:
		if not seat.bot:
			seat.id = peer_of(seat.id)
	_tokens.clear()
	_peer_of_pid.clear()
	_pid_of_peer.clear()
	_update_lock()
	Session.reset()
	if mode != Mode.OFFLINE:
		_rpc_return_to_lobby.rpc(roster)
	_change_scene(MENU_SCENE)


# --- Host side ----------------------------------------------------------------

func _open_room(player_name: String) -> void:
	local_name = _clean_name(player_name)
	_my_pid = local_id()
	roster = [{"id": local_id(), "name": local_name, "bot": false, "connected": true}]
	room_changed.emit(true)
	roster_changed.emit()


func _use_peer(peer: MultiplayerPeer) -> void:
	multiplayer.multiplayer_peer = peer
	# Clients only talk to the host; nothing is relayed between them.
	(multiplayer as SceneMultiplayer).server_relay = false


## Sends the roster to everyone, then tells this screen. In that order: a listener may start
## the game, and the clients must have the roster before they are told to load it.
func _publish_roster() -> void:
	if mode != Mode.OFFLINE and multiplayer.is_server():
		_rpc_roster.rpc(roster)
	roster_changed.emit()


## The room is closed to newcomers during a game, except while a seat waits for its player.
func _update_lock() -> void:
	var waiting := false
	for seat in roster:
		if _tokens.has(seat.id) and not seat.connected:
			waiting = true
	var locked := in_game and not waiting
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
	if not in_game:
		var index := _seat_of(id)
		if index >= 0:
			roster.remove_at(index)
			_publish_roster()
		return
	# A connection that was already replaced by a rejoin is no seat's any more.
	if not _pid_of_peer.has(id):
		return
	var pid: int = _pid_of_peer[id]
	_pid_of_peer.erase(id)
	_peer_of_pid.erase(pid)
	var seat := _seat_of(pid)
	if seat < 0:
		return
	roster[seat].connected = false
	roster[seat].bot = true
	_update_lock()
	Session.on_peer_left(pid)


## A returning player: their new connection takes over their seat.
func _rejoin(peer: int, pid: int) -> void:
	var old_peer: int = _peer_of_pid.get(pid, 0)
	if old_peer != 0 and old_peer != peer:
		# The old connection has not timed out yet; it is no longer this seat's.
		_pid_of_peer.erase(old_peer)
		_disconnect_peer(old_peer)
	_peer_of_pid[pid] = peer
	_pid_of_peer[peer] = pid
	var seat := _seat_of(pid)
	roster[seat].connected = true
	roster[seat].bot = false
	_update_lock()
	_rpc_rejoined.rpc_id(peer, roster, pid)
	Session.on_peer_rejoined(pid)


func _pid_for_token(token: String) -> int:
	if token.is_empty():
		return 0
	for pid in _tokens:
		if _tokens[pid] == token:
			return pid
	return 0


## Tells a peer why it is refused (a msgid; the peer translates it), then drops it.
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
	return cleaned if not cleaned.is_empty() else tr("Player")


# --- Client side ----------------------------------------------------------------

func _set_enet_timeout(peer_id: int) -> void:
	var enet := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if enet and enet.get_peer(peer_id):
		enet.get_peer(peer_id).set_timeout(0, ENET_TIMEOUT_MIN, ENET_TIMEOUT_MAX)


func _on_connected_to_server() -> void:
	_set_enet_timeout(1)
	if not reconnecting:
		status_changed.emit(tr("Connected. Waiting for the host…"))
	_rpc_hello.rpc_id(1, PROTOCOL, local_name, str(_ticket.get("token", "")) if reconnecting else "")


func _on_connection_failed() -> void:
	if reconnecting:
		_drop_peer()
		_retry_timer.start(RECONNECT_INTERVAL)
		return
	leave(tr("Could not connect to the host."))


func _on_server_disconnected() -> void:
	if not _kick_reason.is_empty():
		leave(tr(_kick_reason))
	elif reconnecting:
		_drop_peer()
		_retry_timer.start(RECONNECT_INTERVAL)
	elif in_game and not str(_ticket.get("token", "")).is_empty():
		_begin_reconnect()
	else:
		leave(tr("Lost the connection to the host."))


func _on_steam_lobby_created(lobby_id: int) -> void:
	if mode != Mode.STEAM:
		return
	if lobby_id == 0:
		leave(tr("Steam could not create a lobby."))
		return
	var peer := SteamService.make_peer()
	var err: Error = peer.call("create_host", 0)
	if err != OK:
		leave(tr("Could not host over Steam: {error}.").format({"error": error_string(err)}))
		return
	_use_peer(peer)
	_open_room(local_name)


func _on_steam_lobby_joined(lobby_id: int, error: String) -> void:
	# The host is told about joining its own lobby too; the owner check below skips that.
	if mode != Mode.STEAM:
		return
	if not error.is_empty():
		if reconnecting:
			_retry_timer.start(RECONNECT_INTERVAL)
		else:
			leave(error)
		return
	var owner_id := SteamService.lobby_owner(lobby_id)
	if owner_id == SteamService.steam_id():
		return
	var peer := SteamService.make_peer()
	var err: Error = peer.call("create_client", owner_id, 0)
	if err != OK:
		if reconnecting:
			_retry_timer.start(RECONNECT_INTERVAL)
		else:
			leave(tr("Could not connect over Steam: {error}.").format({"error": error_string(err)}))
		return
	_use_peer(peer)
	if not reconnecting:
		status_changed.emit(tr("Connecting to the host…"))


func _on_steam_join_requested(lobby_id: int) -> void:
	if in_game:
		return
	join_steam(lobby_id)


## Closes the connection but keeps the game: the roster, the seat and the last view stay.
func _drop_peer() -> void:
	_retry_timer.stop()
	if mode == Mode.STEAM:
		SteamService.leave_lobby()
	if multiplayer.multiplayer_peer and multiplayer.multiplayer_peer is not OfflineMultiplayerPeer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()


func _close() -> void:
	_drop_peer()
	mode = Mode.NONE
	roster = []
	in_game = false
	reconnecting = false
	reconnect_attempt = 0
	_awaiting_hello.clear()
	_kick_reason = ""
	_next_bot_id = -1
	_my_pid = 0
	_tokens.clear()
	_peer_of_pid.clear()
	_pid_of_peer.clear()
	Session.reset()
	reconnect_changed.emit()


func _change_scene(path: String) -> void:
	var current := get_tree().current_scene
	if current and current.scene_file_path == path and path == MENU_SCENE:
		roster_changed.emit()
		return
	Transition.change_scene(path)


# --- RPCs -------------------------------------------------------------------------

@rpc("any_peer", "call_remote", "reliable")
func _rpc_hello(protocol: int, player_name: String, token: String) -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	if not _awaiting_hello.erase(id):
		return
	if protocol != PROTOCOL:
		_kick(id, Loc.n("The host runs a different version of the game."))
	elif in_game:
		var pid := _pid_for_token(token)
		if pid == 0:
			_kick(id, Loc.n("That game has already started."))
		else:
			_rejoin(id, pid)
	elif roster.size() >= Content.MAX_SEATS:
		_kick(id, Loc.n("The lobby is full."))
	else:
		roster.append({"id": id, "name": _unique_name(_clean_name(player_name)), "bot": false, "connected": true})
		_publish_roster()


@rpc("authority", "call_remote", "reliable")
func _rpc_roster(new_roster: Array) -> void:
	if in_game and not reconnecting:
		return
	if in_game:
		# Back from a lost connection after the game had ended: the host is in the room again.
		in_game = false
		reconnecting = false
		_forget_ticket()
		reconnect_changed.emit()
		roster.assign(new_roster)
		room_changed.emit(true)
		_change_scene(MENU_SCENE)
		return
	var entered := roster.is_empty()
	roster.assign(new_roster)
	if entered:
		room_changed.emit(true)
	roster_changed.emit()


## The host messages are msgids; they are translated here.
@rpc("authority", "call_remote", "reliable")
func _rpc_kicked(reason: String) -> void:
	_kick_reason = reason


@rpc("authority", "call_remote", "reliable")
func _rpc_load_game(new_roster: Array, token: String) -> void:
	roster.assign(new_roster)
	in_game = true
	_my_pid = local_id()
	_ticket.merge({"token": token, "pid": _my_pid, "name": local_name, "time": Time.get_unix_time_from_system()}, true)
	_save_ticket()
	Session.reset()
	_change_scene(GAME_SCENE)


@rpc("authority", "call_remote", "reliable")
func _rpc_rejoined(new_roster: Array, pid: int) -> void:
	roster.assign(new_roster)
	in_game = true
	reconnecting = false
	_my_pid = pid
	_ticket["time"] = Time.get_unix_time_from_system()
	_save_ticket()
	status_changed.emit(tr("Back at the table."))
	reconnect_changed.emit()
	print("REJOINED as seat %d" % pid)
	var current := get_tree().current_scene
	if current and current.scene_file_path == GAME_SCENE:
		Session.scene_ready()
	else:
		_change_scene(GAME_SCENE)


@rpc("authority", "call_remote", "reliable")
func _rpc_return_to_lobby(new_roster: Array) -> void:
	roster.assign(new_roster)
	in_game = false
	_forget_ticket()
	Session.reset()
	_change_scene(MENU_SCENE)
