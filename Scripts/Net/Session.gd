extends Node
## The game channel. On the host it owns GameRules: it accepts requests, plays the bot seats
## and sends every human their own view after each change. On clients it only keeps the
## latest view. The UI talks to the game exclusively through submit() and view_changed.

signal view_changed(view: GameState)
## The new view plus the events that led to it, for the presentation layer to animate.
signal update_received(view: GameState, events: Array)
## Why a request was refused, translated.
signal request_failed(message: String)

const BOT_DELAY := 0.6
## Seconds a remote human may stay idle before they automatically rest. 0 disables it.
const AFK_TIMEOUT := 120.0

## The latest view of the game for the local player; null before the game starts.
var view: GameState
## Host only.
var rules: GameRules
## Pause between bot moves so humans can follow; tests set it to 0.
var bot_delay := BOT_DELAY
var afk_timeout := AFK_TIMEOUT
## Lets BotBrain play the local seat (used by automated tests).
var autoplay := false
## Set by the game screen while it is animating; the host's bots wait for it so a local
## human can follow what happens.
var presentation_busy := false

var _roster: Array[Dictionary] = []
var _seed := 0
var _max_turns := Content.MAX_TURNS
var _ready_peers: Dictionary[int, bool] = {}
var _bot_rng := RandomNumberGenerator.new()
var _bot_timer := Timer.new()
var _afk_timer := Timer.new()
var _waiting_since: Dictionary[int, float] = {}
## Last event each peer has been sent.
var _sent_seq: Dictionary[int, int] = {}
var _autoplay_queued := false
## What the local seat looked like when autoplay last submitted; used to avoid sending the
## same move twice while the host's answer is still on its way.
var _autoplay_signature := ""


func _ready() -> void:
	_bot_timer.one_shot = true
	_bot_timer.timeout.connect(_run_bot)
	add_child(_bot_timer)
	_afk_timer.wait_time = 1.0
	_afk_timer.timeout.connect(_check_afk)
	add_child(_afk_timer)


func reset() -> void:
	view = null
	rules = null
	_roster = []
	_ready_peers.clear()
	_waiting_since.clear()
	_sent_seq.clear()
	presentation_busy = false
	_autoplay_signature = ""
	_bot_timer.stop()
	_afk_timer.stop()


## The local player's seat id (stays the same when they rejoin on a new connection).
func local_id() -> int:
	return Network.local_pid()


## Host: remember who plays and how, before the game scene loads everywhere.
func prepare_host(roster: Array[Dictionary], seed_value: int, max_turns: int) -> void:
	reset()
	_roster = roster.duplicate(true)
	_seed = seed_value
	_max_turns = max_turns
	_bot_rng.seed = seed_value + 1


## Every peer calls this once its game scene is ready to receive views.
func scene_ready() -> void:
	if Network.is_host() or Network.mode == Network.Mode.OFFLINE:
		_mark_ready(local_id())
	elif not Network.reconnecting:
		_rpc_scene_ready.rpc_id(1)


## Sends a request for the local player. The host applies it directly.
func submit(op: StringName, args: Array = []) -> void:
	if Network.reconnecting:
		return
	if Network.is_host() or Network.mode == Network.Mode.OFFLINE:
		_handle(local_id(), op, args)
	else:
		_rpc_request.rpc_id(1, op, args)


## Host: a human left. Before the start their seat simply becomes a bot; during the game a
## bot takes over their seat.
func on_peer_left(id: int) -> void:
	for seat in _roster:
		if seat.id == id:
			seat.bot = true
			seat.connected = false
	if rules == null:
		_try_start()
		return
	var p := rules.state.player(id)
	if p == null:
		return
	rules.set_bot(id, true, false)
	rules.emit_event(&"left", {"pid": id})
	rules.log_event("{player} lost the connection; a bot plays their seat until they return.", {"player": Loc.player(p)})
	_after_change()


## Host: a player who lost the connection is back on a new one and takes their seat again.
func on_peer_rejoined(id: int) -> void:
	for seat in _roster:
		if seat.id == id:
			seat.bot = false
			seat.connected = true
	if rules == null:
		return
	var p := rules.state.player(id)
	if p == null:
		return
	rules.set_bot(id, false, true)
	rules.emit_event(&"rejoined", {"pid": id})
	rules.log_event("{player} is back at the table.", {"player": Loc.player(p)})
	# They get the table as it is now, without a backlog of animations, and a fresh AFK clock.
	_sent_seq[id] = rules.last_event_seq()
	_waiting_since.erase(id)
	_after_change()


# --- Host internals -----------------------------------------------------------

func _mark_ready(id: int) -> void:
	if rules != null:
		_send_view(id)
		return
	_ready_peers[id] = true
	_try_start()


func _try_start() -> void:
	if _roster.is_empty():
		return
	for seat in _roster:
		if not seat.bot and seat.connected and not _ready_peers.has(seat.id):
			return
	rules = GameRules.new()
	rules.setup(_roster, _seed, _max_turns)
	for seat in _roster:
		if not seat.bot:
			_sent_seq[seat.id] = 0
	if afk_timeout > 0.0:
		_afk_timer.start()
	_after_change()


func _handle(pid: int, op: StringName, args: Array) -> void:
	if rules == null:
		return
	var err := rules.apply(pid, op, args)
	if err.is_empty():
		_after_change()
	else:
		print("Request refused (%s %s from %d): %s" % [op, args, pid, Loc.text(err)])
		_send_error(pid, err)


func _after_change() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var waiting := rules.state.waiting_on()
	for id in _waiting_since.keys():
		if not waiting.has(id):
			_waiting_since.erase(id)
	for id in waiting:
		if not _waiting_since.has(id):
			_waiting_since[id] = now
	for p in rules.state.players:
		if not p.is_bot and p.connected:
			_send_view(p.id)
	if rules.state.phase == GameState.Phase.GAME_OVER:
		_afk_timer.stop()
	_schedule_bot()


func _send_view(id: int) -> void:
	var data := rules.state.to_view(id)
	# A peer that joins the view stream late gets the current table without a backlog.
	var since: int = _sent_seq.get(id, rules.last_event_seq())
	data["events"] = rules.events_since(since)
	_sent_seq[id] = rules.last_event_seq()
	if id == local_id():
		_apply_view(data)
	elif Network.peer_is_reachable(Network.peer_of(id)):
		_rpc_view.rpc_id(Network.peer_of(id), data)


## `message` is a Loc message, translated by whoever receives it.
func _send_error(id: int, message: Dictionary) -> void:
	if id == local_id():
		_on_request_failed(message)
	elif Network.peer_is_reachable(Network.peer_of(id)):
		_rpc_error.rpc_id(Network.peer_of(id), message)


## Called by the game screen when it has finished animating.
func presentation_finished() -> void:
	presentation_busy = false
	if rules != null:
		_schedule_bot()


func _schedule_bot() -> void:
	if not _bot_timer.is_stopped() or presentation_busy:
		return
	for id in rules.state.waiting_on():
		if rules.state.player(id).is_bot:
			_bot_timer.start(maxf(bot_delay, 0.001))
			return


## Plays one bot move, then lets _after_change schedule the next one.
func _run_bot() -> void:
	if rules == null or presentation_busy:
		return
	for id in rules.state.waiting_on():
		var p := rules.state.player(id)
		if not p.is_bot:
			continue
		var request := BotBrain.decide(GameState.from_view(rules.state.to_view(id)), id, _bot_rng)
		var err: Dictionary = {"k": "no move", "a": {}} if request.is_empty() else rules.apply(id, request[0], request[1])
		if not err.is_empty():
			push_error("Bot %s could not act (%s); using the default move." % [p.name, Loc.text(err)])
			request = rules.default_request(id)
			rules.apply(id, request[0], request[1])
		_after_change()
		return


func _check_afk() -> void:
	if rules == null or afk_timeout <= 0.0:
		return
	var now := Time.get_ticks_msec() / 1000.0
	for id in rules.state.waiting_on():
		var p := rules.state.player(id)
		if p.is_bot or id == local_id() or now - _waiting_since.get(id, now) < afk_timeout:
			continue
		var request := rules.default_request(id)
		if request.is_empty():
			continue
		rules.log_event("{player} was idle too long and acts automatically.", {"player": Loc.player(p)})
		rules.apply(id, request[0], request[1])
		_after_change()
		return


# --- Every peer ---------------------------------------------------------------

func _apply_view(data: Dictionary) -> void:
	view = GameState.from_view(data)
	if view.phase == GameState.Phase.GAME_OVER:
		Network.game_finished()
	update_received.emit(view, data.get("events", []))
	view_changed.emit(view)
	if autoplay:
		_queue_autoplay()


func _on_request_failed(message: Dictionary) -> void:
	request_failed.emit(Loc.text(message))
	if autoplay:
		push_error("Autoplay request refused: %s" % Loc.text(message))


func _queue_autoplay() -> void:
	if _autoplay_queued:
		return
	_autoplay_queued = true
	get_tree().create_timer(maxf(bot_delay, 0.001)).timeout.connect(_autoplay_step)


func _autoplay_step() -> void:
	_autoplay_queued = false
	if not autoplay or view == null:
		return
	var me := view.player(local_id())
	if me == null:
		return
	var signature := var_to_str([view.turn, view.phase, view.cursor, view.shopping, me.to_dict(true)])
	if signature == _autoplay_signature:
		return
	var request := BotBrain.decide(view, local_id(), _bot_rng)
	if not request.is_empty():
		_autoplay_signature = signature
		submit(request[0], request[1])


# --- RPCs ----------------------------------------------------------------------

@rpc("any_peer", "call_remote", "reliable")
func _rpc_scene_ready() -> void:
	if Network.is_host():
		var pid := Network.pid_of(multiplayer.get_remote_sender_id())
		if pid != 0:
			_mark_ready(pid)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_request(op: StringName, args: Array) -> void:
	if not Network.is_host() or rules == null:
		return
	var pid := Network.pid_of(multiplayer.get_remote_sender_id())
	var p := rules.state.player(pid)
	if p == null or p.is_bot:
		return
	_handle(pid, op, args)


@rpc("authority", "call_remote", "reliable")
func _rpc_view(data: Dictionary) -> void:
	_apply_view(data)


@rpc("authority", "call_remote", "reliable")
func _rpc_error(message: Dictionary) -> void:
	_on_request_failed(message)
