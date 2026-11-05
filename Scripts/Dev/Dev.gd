extends Node
## Command-line automation for testing; inert unless arguments follow "--":
##   --autohost=offline|enet   host (offline = solo vs bots) as soon as the menu loads
##   --autojoin=ADDRESS        join a direct-IP host
##   --name=NAME               player name
##   --bots=N                  bots to add before starting
##   --expect=N                host starts once N humans (including itself) are in the room
##   --seed=N --turns=N        game seed and length
##   --autoplay                the bot brain plays the local seat
##   --bot-delay=SECONDS       pause between bot moves (default 0.6; 0 also skips animations)
##   --instant                 skip all animations
##   --afk=SECONDS             idle timeout for remote players (0 disables)
##   --leave-at-turn=N         quit abruptly when turn N starts (tests disconnects)
##   --drop-at-turn=N          lose the connection when turn N starts, then rejoin (tests reconnecting)
##   --rejoin-file=PATH        where this instance saves its rejoin ticket (several players, one machine)
##   --rejoin-saved            rejoin the saved game from the menu, as after a crash
##   --keys-test               play the local seat with key presses only (arrows and Enter), checking
##                             that every step can be reached and done; prints KEYS TEST PASSED/FAILED
##   --pad                     with --keys-test, press controller buttons (d-pad, A) instead of keys
##   --key-pause=SECONDS       with --keys-test, wait this long on each step (time to take screenshots)
##   --locale=CODE             play in this language (e.g. de)
##   --quit-on-end             print a RESULT line and quit when the game ends
##   --screenshots=DIR         save a screenshot whenever the phase changes (windowed only)
##   --menu-shots=DIR          screenshot every menu page and overlay, then quit (windowed only)
##   --shot-interval=SECONDS   with --screenshots, also save a screenshot this often
##   --layout-check            report whenever the table needs more room than the window has, and
##                             what is asking for it; prints LAYOUT OK or LAYOUT OVERFLOW on quitting

var options: Dictionary = {}
var _started := false
var _finished := false
var _last_shot := ""
var _dropped := false
var _layout_problems: Dictionary[String, bool] = {}


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--"):
			var parts := arg.substr(2).split("=", true, 1)
			options[parts[0]] = parts[1] if parts.size() > 1 else "true"
	if options.is_empty():
		return
	if options.has("bot-delay"):
		Session.bot_delay = float(options["bot-delay"])
	# Fast automated runs skip animations entirely.
	if options.has("instant") or (options.has("bot-delay") and Session.bot_delay <= 0.0):
		Settings.instant_animations = true
	if options.has("afk"):
		Session.afk_timeout = float(options["afk"])
	Session.autoplay = options.has("autoplay")
	if options.has("locale"):
		TranslationServer.set_locale(options["locale"])
	if options.has("rejoin-file"):
		Network.rejoin_path = options["rejoin-file"]
	Network.roster_changed.connect(_on_roster_changed)
	Session.view_changed.connect(_on_view_changed)
	if options.has("keys-test"):
		_keys_test.call_deferred()
	if options.has("screenshots") and options.has("shot-interval"):
		var timer := Timer.new()
		timer.wait_time = float(options["shot-interval"])
		timer.timeout.connect(_interval_shot)
		add_child(timer)
		timer.start()
	set_process(options.has("layout-check"))
	_start.call_deferred()


func _process(_delta: float) -> void:
	var screen := get_tree().current_scene as GameScreen
	if screen == null or not screen.is_node_ready():
		return
	var room := screen.get_viewport_rect().size
	var needed := screen.margin.get_combined_minimum_size() * screen.margin.scale
	# Fitting by shrinking is fine, unless the table has shrunk out of sight.
	if screen.margin.scale.x >= 0.5 and needed.x <= room.x + 0.5 and needed.y <= room.y + 0.5:
		return
	var axis := 0 if needed.x > room.x + 0.5 else 1
	var problem := "needs %v of %v at scale %.2f: %s" % [needed.ceil(), room.ceil(), screen.margin.scale.x, _largest_path(screen.margin, axis)]
	if not _layout_problems.has(problem):
		_layout_problems[problem] = true
		printerr("LAYOUT " + problem)


## The chain of controls that sets a control's minimum size along `axis` (0 width, 1 height),
## ending in the one asking for it.
func _largest_path(control: Control, axis: int) -> String:
	var largest: Control = null
	for child in control.get_children():
		var item := child as Control
		if item and item.visible and (largest == null or item.get_combined_minimum_size()[axis] > largest.get_combined_minimum_size()[axis]):
			largest = item
	var own := "%s(%d)" % [control.name, ceili(control.get_combined_minimum_size()[axis])]
	if largest == null:
		var rich := control as RichTextLabel
		return own + (" '%s'" % rich.get_parsed_text() if rich else "")
	return own + " > " + _largest_path(largest, axis)


func _exit_tree() -> void:
	if options.has("layout-check"):
		print("LAYOUT OVERFLOW (%d cases)" % _layout_problems.size() if not _layout_problems.is_empty() else "LAYOUT OK")


func _start() -> void:
	if options.has("menu-shots"):
		_menu_shots(options["menu-shots"])
		return
	if options.has("rejoin-saved"):
		if not Network.saved_rejoin_available():
			printerr("ERROR: no saved game to rejoin")
			Transition.quit_game(1)
			return
		_started = true
		Network.rejoin_saved_game()
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
	if options.has("drop-at-turn") and not _dropped and view.turn >= int(options["drop-at-turn"]):
		_dropped = true
		print("DROPPING the connection at turn %d" % view.turn)
		Network.simulate_connection_loss.call_deferred()
		return
	if view.phase != GameState.Phase.GAME_OVER or _finished:
		return
	_finished = true
	var standings := []
	for id in view.standings:
		var p := view.player(id)
		standings.append([p.name, view.final_score(p)])
	var summary := {"turn": view.turn, "standings": standings, "log": var_to_str(view.log_lines).hash()}
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


var _interval_count := 0


func _interval_shot() -> void:
	if DisplayServer.get_name() == "headless" or not get_tree().current_scene is GameScreen:
		return
	_interval_count += 1
	await RenderingServer.frame_post_draw
	var dir: String = options["screenshots"]
	DirAccess.make_dir_recursive_absolute(dir)
	get_viewport().get_texture().get_image().save_png(dir.path_join("i%03d.png" % _interval_count))


func _screenshot(view: GameState) -> void:
	var key := "t%02d_%s_%d" % [view.turn, GameState.PHASE_NAMES[view.phase], view.cursor]
	if key == _last_shot or DisplayServer.get_name() == "headless":
		return
	_last_shot = key
	await RenderingServer.frame_post_draw
	var dir: String = options["screenshots"]
	DirAccess.make_dir_recursive_absolute(dir)
	get_viewport().get_texture().get_image().save_png(dir.path_join(key + ".png"))


# --- Keyboard test ----------------------------------------------------------------

## Plays the local seat until the game ends using nothing but key presses, the way a keyboard
## or pad player would: the focus must land where each step needs it, and pressing must work.
func _keys_test() -> void:
	await _press(KEY_SHIFT)
	var steps := 0
	while true:
		await get_tree().process_frame
		var screen := get_tree().current_scene as GameScreen
		var view := Session.view
		if screen == null or view == null:
			continue
		if view.phase == GameState.Phase.GAME_OVER:
			print("KEYS TEST PASSED (%d steps)" % steps)
			Transition.quit_game()
			return
		var me := Session.local_id()
		if screen.is_animating() or not view.is_waiting_on(me):
			continue
		for _i in 3:
			await get_tree().process_frame
		if options.has("key-pause"):
			await get_tree().create_timer(float(options["key-pause"])).timeout
		var before := _signature(view, me)
		var problem: String = await _key_step(view)
		if problem.is_empty():
			problem = "the step had no effect"
			for _i in 180:
				await get_tree().process_frame
				if Session.view and _signature(Session.view, me) != before:
					problem = ""
					break
		if not problem.is_empty():
			printerr("ERROR: KEYS TEST FAILED in phase %s turn %d: %s (focus on %s)" % [
				GameState.PHASE_NAMES[view.phase], view.turn, problem, _describe_focus()])
			Transition.quit_game(1)
			return
		steps += 1


## One step of the local player's turn by keys. Returns "" or what went wrong.
func _key_step(view: GameState) -> String:
	match view.phase:
		GameState.Phase.ROLL:
			if _focus_text() != tr("Keep these dice"):
				return "the focus is not on Keep these dice"
			await _press(KEY_ENTER)
		GameState.Phase.DECLARE:
			# Every other turn, open the action list with Enter and pick Shop, so the market and
			# its face picking are played by keys too.
			if view.turn % 2 == 0:
				var list := get_viewport().gui_get_focus_owner() as OptionButton
				if list == null:
					return "the focus is not on the action list"
				# The open list starts on the current choice.
				var downs := posmod(ActionPanel.ACTIONS.find(PlayerState.Action.SHOP) - list.selected, list.item_count)
				# Popup menus ignore pad presses that come faster than a person makes them.
				await _press(KEY_ENTER, true)
				for _i in downs:
					await _press(KEY_DOWN, true)
				await _press(KEY_ENTER, true)
				var shown := _focus_text()
				if shown != PlayerState.action_name(PlayerState.Action.SHOP):
					return "picking Shop from the action list gave '%s'" % shown
			if not await _move_to([tr("Declare")], KEY_DOWN, 5):
				return "Declare cannot be reached"
			await _press(KEY_ENTER)
		GameState.Phase.PLAN:
			if not await _move_to([tr("Lock plan")], KEY_DOWN, 8):
				return "Lock plan cannot be reached"
			await _press(KEY_ENTER)
			for _i in 3:
				await get_tree().process_frame
			if _focus_text() == tr("Cancel"):
				await _press(KEY_RIGHT)
				if _focus_text() != tr("Lock it"):
					return "the confirmation cannot be reached"
				await _press(KEY_ENTER)
		GameState.Phase.RESOLVE:
			var focused := get_viewport().gui_get_focus_owner()
			if focused is MarketTile:
				# Choose the face, then the face it replaces: the focus must move to one of ours.
				await _press(KEY_ENTER)
				for _i in 3:
					await get_tree().process_frame
				focused = get_viewport().gui_get_focus_owner()
				if focused == null or focused is MarketTile:
					return "after choosing a market face the focus is not on a face to replace"
				await _press(KEY_ENTER)
			elif _focus_text() == tr("Done shopping"):
				await _press(KEY_ENTER)
			else:
				return "the focus is neither on a market face nor on Done shopping"
		GameState.Phase.LOOT:
			await _press(KEY_ENTER)
		GameState.Phase.BID:
			if not await _move_to([tr("Place bid"), tr("Pass")], KEY_DOWN, 6):
				return "the bid buttons cannot be reached"
			await _press(KEY_ENTER)
	return ""


## Presses `key` until the focus is on a button with one of these texts.
func _move_to(texts: Array[String], key: Key, tries: int) -> bool:
	for _i in tries:
		if texts.has(_focus_text()):
			return true
		await _press(key)
	return texts.has(_focus_text())


## The controller button a key stands for in --pad runs.
const PAD_FOR_KEY: Dictionary[Key, JoyButton] = {
	KEY_ENTER: JOY_BUTTON_A, KEY_DOWN: JOY_BUTTON_DPAD_DOWN, KEY_UP: JOY_BUTTON_DPAD_UP,
	KEY_LEFT: JOY_BUTTON_DPAD_LEFT, KEY_RIGHT: JOY_BUTTON_DPAD_RIGHT, KEY_SHIFT: JOY_BUTTON_LEFT_STICK,
}


## Presses and releases a key, or with --pad the controller button standing for it.
func _press(key: Key, human_pace: bool = false) -> void:
	for pressed in [true, false]:
		if options.has("pad"):
			# Through the Input singleton, as real hardware: popup menus only take a pad press
			# Input has seen (is_action_just_pressed_by_event).
			var button := InputEventJoypadButton.new()
			button.button_index = PAD_FOR_KEY[key]
			button.pressed = pressed
			Input.parse_input_event(button)
			Input.flush_buffered_events()
		else:
			# Straight into the window: the same _input, GUI and unhandled path as a real key.
			var typed := InputEventKey.new()
			typed.keycode = key
			typed.physical_keycode = key
			typed.pressed = pressed
			get_tree().root.push_input(typed)
		await get_tree().process_frame
	await get_tree().process_frame
	if human_pace and options.has("pad"):
		await get_tree().create_timer(0.6).timeout


func _focus_text() -> String:
	var button := get_viewport().gui_get_focus_owner() as Button
	return button.text if button else ""


func _describe_focus() -> String:
	var focused := get_viewport().gui_get_focus_owner()
	if focused == null:
		return "nothing"
	return "%s '%s'" % [focused.get_class(), _focus_text()]


func _signature(view: GameState, me: int) -> String:
	var p := view.player(me)
	if p == null:
		return ""
	return var_to_str([view.turn, view.phase, view.cursor, view.shopping, p.roll_done, p.declared, p.plan_locked,
		p.dice, p.gold, view.bid_waiting, view.loot])
