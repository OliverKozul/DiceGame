extends Node
## Command-line automation for testing; inert unless arguments follow "--":
##   --autohost=offline|enet   host (offline = solo vs bots) as soon as the menu loads
##   --autojoin=ADDRESS        join a direct-IP host
##   --name=NAME               player name
##   --bots=N                  bots to add before starting
##   --expect=N                host starts once N humans (including itself) are in the room
##   --seed=N --turns=N        game seed and length
##   --autoplay                the bot brain plays the local seat
##   --bot-delay=SECONDS       pause between bot moves (default 0.6)
##   --afk=SECONDS             idle timeout for remote players (0 disables)
##   --leave-at-turn=N         quit abruptly when turn N starts (tests disconnects)
##   --quit-on-end             print a RESULT line and quit when the game ends
##   --screenshots=DIR         save a screenshot whenever the phase changes (windowed only)
##   --menu-shots=DIR          screenshot every menu page and overlay, then quit (windowed only)

var options: Dictionary = {}
var _started := false
var _finished := false
var _last_shot := ""


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--"):
			var parts := arg.substr(2).split("=", true, 1)
			options[parts[0]] = parts[1] if parts.size() > 1 else "true"
	if options.is_empty():
		return
	if options.has("bot-delay"):
		Session.bot_delay = float(options["bot-delay"])
	if options.has("afk"):
		Session.afk_timeout = float(options["afk"])
	Session.autoplay = options.has("autoplay")
	Network.roster_changed.connect(_on_roster_changed)
	Session.view_changed.connect(_on_view_changed)
	_start.call_deferred()


func _start() -> void:
	if options.has("menu-shots"):
		_menu_shots(options["menu-shots"])
		return
	var player_name: String = options.get("name", "Tester")
	match options.get("autohost", ""):
		"offline":
			_started = true
			Network.play_offline(player_name, int(options.get("bots", "2")), _seed(), _turns())
		"enet":
			var err := Network.host_enet(player_name)
			if not err.is_empty():
				printerr(err)
				Transition.quit_game(1)
	if options.has("autojoin"):
		var err := Network.join_enet(player_name, options["autojoin"])
		if not err.is_empty():
			printerr(err)
			Transition.quit_game(1)


func _seed() -> int:
	return int(options.get("seed", "-1"))


func _turns() -> int:
	return int(options.get("turns", str(Content.MAX_TURNS)))


func _on_roster_changed() -> void:
	if _started or not Network.is_host() or Network.in_game:
		return
	if Network.human_count() < int(options.get("expect", "1")):
		return
	_started = true
	for _i in int(options.get("bots", "0")):
		Network.add_bot()
	Network.start_game(_seed(), _turns())


func _on_view_changed(view: GameState) -> void:
	if options.has("screenshots"):
		_screenshot(view)
	if options.has("leave-at-turn") and view.turn >= int(options["leave-at-turn"]):
		print("LEAVING at turn %d" % view.turn)
		Transition.quit_game()
		return
	if view.phase != GameState.Phase.GAME_OVER or _finished:
		return
	_finished = true
	var standings := []
	for id in view.standings:
		var p := view.player(id)
		standings.append([p.name, view.final_score(p)])
	var summary := {"turn": view.turn, "standings": standings, "log": "\n".join(view.log_lines).hash()}
	print("RESULT " + JSON.stringify(summary))
	if options.has("quit-on-end"):
		# The host lingers so the final view reaches every client before it disconnects.
		get_tree().create_timer(2.0 if Network.is_host() else 0.5).timeout.connect(func() -> void: Transition.quit_game())


func _menu_shots(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	await get_tree().create_timer(1.2).timeout
	var menu := get_tree().current_scene
	var steps: Array = [
		["main", func() -> void: pass],
		["solo", func() -> void: menu.call("_show_page", menu.get_node("%SoloPage"))],
		["online", func() -> void: menu.call("_show_page", menu.get_node("%OnlinePage"))],
		["credits", func() -> void: menu.call("_show_page", menu.get_node("%CreditsPage"))],
		["settings", func() -> void: menu.get("_settings").call("open")],
		["rules", func() -> void:
			menu.get("_settings").call("close")
			menu.get("_rules").call("open")],
		["rules_faces", func() -> void: menu.get("_rules").call("_show", 9)],
	]
	for step: Array in steps:
		(step[1] as Callable).call()
		await get_tree().create_timer(0.6).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(dir.path_join("menu_%s.png" % step[0]))
	Transition.quit_game()


func _screenshot(view: GameState) -> void:
	var key := "t%02d_%s_%d" % [view.turn, GameState.PHASE_NAMES[view.phase], view.cursor]
	if key == _last_shot or DisplayServer.get_name() == "headless":
		return
	_last_shot = key
	await RenderingServer.frame_post_draw
	var dir: String = options["screenshots"]
	DirAccess.make_dir_recursive_absolute(dir)
	get_viewport().get_texture().get_image().save_png(dir.path_join(key + ".png"))
