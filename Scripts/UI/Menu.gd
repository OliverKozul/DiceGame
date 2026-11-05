extends Control
## Main menu and pre-game room. All session state lives in Network; this screen reflects it.
## Every page puts the focus on its first control for keys and pads.

## Room kept free above and below the sign and the card.
const LAYOUT_TOP := 36.0
const LAYOUT_BOTTOM := 20.0

## Steam's "+connect_lobby" launch argument is handled once per run.
static var _launch_lobby_checked := false
## After a language change the menu reloads to redraw its text, then reopens the settings.
static var _reopen_settings := false

## The tables listed on the online page: friends' first, then public ones.
var _tables: Array[Dictionary] = []
var _page: Control
var _settings := SettingsPanel.new()
var _rules := RulesBook.new()
var _confirm := ConfirmOverlay.new()
var _licenses := LicensesOverlay.new()
var _rejoin_button := Button.new()
## The room's options, as host controls or (for the others) a read-only display.
var _room_turns := Stepper.new()
var _room_difficulty := Stepper.new()
var _room_afk := Stepper.new()
var _room_public := Stepper.new()
var _public_row: Control
var _solo_turns := Stepper.new()
var _solo_difficulty := Stepper.new()

@onready var _pages: Array[Control] = [%MainPage, %SoloPage, %OnlinePage, %RoomPage, %CreditsPage]
@onready var _name_edit: LineEdit = %NameEdit
@onready var _bots_spin: Stepper = %BotsSpin
@onready var _steam_label: Label = %SteamLabel
@onready var _host_steam_button: Button = %HostSteamButton
@onready var _refresh_friends_button: Button = %RefreshFriendsButton
@onready var _friend_list: ItemList = %FriendList
@onready var _join_friend_button: Button = %JoinFriendButton
@onready var _address_edit: LineEdit = %AddressEdit
@onready var _room_title: Label = %RoomTitle
@onready var _roster_list: VBoxContainer = %RosterList
@onready var _room_hint: Label = %RoomHint
@onready var _host_row: Control = %HostRow
@onready var _add_bot_button: Button = %AddBotButton
@onready var _remove_bot_button: Button = %RemoveBotButton
@onready var _invite_button: Button = %InviteButton
@onready var _start_button: Button = %StartButton
@onready var _status_label: Label = %StatusLabel
@onready var _sign: Control = %Sign
@onready var _layout: Control = $Layout


func _ready() -> void:
	add_child(_settings)
	add_child(_rules)
	add_child(_confirm)
	add_child(_licenses)
	_layout.set_anchors_preset(Control.PRESET_TOP_LEFT)
	resized.connect(_fit_layout)
	_layout.minimum_size_changed.connect(_fit_layout)
	_fit_layout.call_deferred()
	_confirm.confirmed.connect(func() -> void: Transition.quit_game())

	var wood: ShaderMaterial = $Backdrop/Wood.material
	wood.set_shader_parameter("horizontal", true)
	wood.set_shader_parameter("plank_width", 96.0)
	var seed_value := 0.0
	for candle_name in ["CandleLeft", "CandleLeft2", "CandleRight"]:
		var flame: ShaderMaterial = get_node(candle_name + "/Flame").material
		flame.set_shader_parameter("seed", seed_value)
		seed_value += 0.37

	%SoloButton.pressed.connect(_show_page.bind(%SoloPage))
	%OnlineButton.pressed.connect(_show_page.bind(%OnlinePage))
	%RulesButton.pressed.connect(_rules.open)
	%SettingsButton.pressed.connect(_settings.open)
	%CreditsButton.pressed.connect(_show_page.bind(%CreditsPage))
	%QuitButton.pressed.connect(func() -> void: _confirm.ask(tr("Leave the tavern?"), tr("The game closes."), tr("Quit")))
	_bots_spin.setup(2, Content.MAX_SEATS - 1, 3)
	_bots_spin.set_value_width(Stepper.VALUE_WIDTH)
	%StartSoloButton.pressed.connect(func() -> void: Network.play_offline(_player_name(), _bots_spin.value))
	%SoloBackButton.pressed.connect(_show_page.bind(%MainPage))
	_host_steam_button.pressed.connect(func() -> void: _show_error(Network.host_steam()))
	_refresh_friends_button.pressed.connect(_refresh_tables)
	SteamService.public_lobbies_found.connect(_on_public_lobbies_found)
	_build_solo_options()
	_build_room_options()
	_friend_list.item_selected.connect(func(_index: int) -> void: _join_friend_button.disabled = false)
	_join_friend_button.pressed.connect(_on_join_friend_pressed)
	%HostLanButton.pressed.connect(func() -> void: _show_error(Network.host_enet(_player_name())))
	%JoinLanButton.pressed.connect(func() -> void: _show_error(Network.join_enet(_player_name(), _address_edit.text)))
	%OnlineBackButton.pressed.connect(_show_page.bind(%MainPage))
	_add_bot_button.pressed.connect(Network.add_bot)
	_remove_bot_button.pressed.connect(Network.remove_bot)
	_invite_button.pressed.connect(Network.invite_friends)
	_start_button.pressed.connect(func() -> void: Network.start_game())
	%LeaveRoomButton.pressed.connect(func() -> void: Network.leave())
	%CreditsBackButton.pressed.connect(_show_page.bind(%MainPage))
	%CreditsText.text = _credits()
	var licenses := Button.new()
	licenses.text = tr("Licences")
	licenses.theme_type_variation = &"TextButton"
	licenses.pressed.connect(_licenses.open)
	%CreditsPage.add_child(licenses)
	%CreditsPage.move_child(licenses, %CreditsBackButton.get_index())
	_settings.language_changed.connect(_on_language_changed)
	_add_rejoin_button()
	Controls.add_default(_default_focus)

	Network.roster_changed.connect(_refresh)
	Network.room_changed.connect(func(_in_room: bool) -> void: _refresh())
	Network.status_changed.connect(_show_status)
	Network.reconnect_changed.connect(_update_rejoin)

	_name_edit.text = Network.local_name if Network.local_name != "Player" else ""
	if SteamService.available and _name_edit.text.is_empty():
		_name_edit.text = SteamService.persona_name()
	_steam_label.text = SteamService.status
	_host_steam_button.disabled = not SteamService.available
	_refresh_friends_button.disabled = not SteamService.available
	_show_status(Network.leave_reason)
	Network.leave_reason = ""
	_page = %MainPage
	_refresh()
	_update_rejoin()
	_sway_sign()
	Controls.focus(Controls.first_focusable(_page))
	if _reopen_settings:
		_reopen_settings = false
		_settings.open_at.call_deferred("display")

	if not _launch_lobby_checked:
		_launch_lobby_checked = true
		var lobby := SteamService.launch_lobby()
		if lobby != 0:
			_show_error(Network.join_steam(lobby))


## Keeps the sign and the card on the screen: at a large interface size, or on a tall page, they
## are drawn smaller rather than cut off.
func _fit_layout() -> void:
	var room := size - Vector2(0.0, LAYOUT_TOP + LAYOUT_BOTTOM)
	var needed := _layout.get_combined_minimum_size()
	var fit := minf(1.0, minf(room.x / maxf(needed.x, 1.0), room.y / maxf(needed.y, 1.0)))
	_layout.scale = Vector2.ONE * fit
	_layout.position = Vector2(0.0, LAYOUT_TOP)
	_layout.size = Vector2(size.x, room.y) / fit


func _exit_tree() -> void:
	Controls.remove_default(_default_focus)


func _player_name() -> String:
	return _name_edit.text


func _credits() -> String:
	return "\n\n".join(PackedStringArray([
		"[b]%s[/b]\n%s" % [tr("Game design and code"), "Oliver Kozul, with Claude."],
		"[b]%s[/b]\n%s" % [tr("Sound effects"), "Casino Audio, RPG Audio and UI SFX Set by Kenney (kenney.nl), CC0."],
		"[b]%s[/b]\n%s" % [tr("Music and ambience"), "The Old Tower Inn and Medieval: Kings Feast by RandomMind, CC0.\nFireplace Sound Loop by PagDev, CC0."],
		"[b]%s[/b]\n%s" % [tr("Fonts"), "Lora by Cyreal, Grenze Gotisch by Renata Polastri and Omnibus-Type (both SIL Open Font License)."],
		"[b]%s[/b]\n%s" % [tr("Made with"), "Godot Engine, GodotSteam and Steamworks."],
		tr("Icons, shaders, dice and everything else were made for this game."),
	]))


## A label and a control beside it, for a table option.
func _option_row(parent: Node, text: String, control: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var label := Label.new()
	label.text = text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	row.add_child(control)
	parent.add_child(row)
	return row


func _difficulty_words() -> PackedStringArray:
	return PackedStringArray([BotTable.difficulty_name(BotTable.Difficulty.EASY),
		BotTable.difficulty_name(BotTable.Difficulty.NORMAL), BotTable.difficulty_name(BotTable.Difficulty.HARD)])


func _turn_words() -> PackedStringArray:
	var words := PackedStringArray()
	for turns in Network.TURN_CHOICES:
		words.append(tr("{turns} turns").format({"turns": turns}))
	return words


## Solo games remember their options in the same place as hosted tables.
func _build_solo_options() -> void:
	var page := %SoloPage
	var before: int = %StartSoloButton.get_index()
	_solo_difficulty.setup_choices(_difficulty_words(), int(Settings.get_value("table", "difficulty")))
	_solo_difficulty.value_changed.connect(func(value: int) -> void: Settings.set_value("table", "difficulty", value))
	_solo_turns.setup_choices(_turn_words(), maxi(0, Network.TURN_CHOICES.find(int(Settings.get_value("table", "turns")))))
	_solo_turns.value_changed.connect(func(value: int) -> void: Settings.set_value("table", "turns", Network.TURN_CHOICES[value]))
	page.move_child(_option_row(page, tr("Difficulty"), _solo_difficulty), before)
	page.move_child(_option_row(page, tr("Length"), _solo_turns), before + 1)


func _build_room_options() -> void:
	var options := %RoomOptions
	var afk_words := PackedStringArray()
	for seconds in Network.AFK_CHOICES:
		afk_words.append(tr("{seconds} s").format({"seconds": seconds}) if seconds > 0 else tr("No limit"))
	_room_turns.setup_choices(_turn_words(), 0)
	_room_difficulty.setup_choices(_difficulty_words(), 0)
	_room_afk.setup_choices(afk_words, 0)
	_room_public.setup_choices(PackedStringArray([tr("Friends only"), tr("Public")]), 0)
	_room_turns.value_changed.connect(func(value: int) -> void: Network.set_room_option("turns", Network.TURN_CHOICES[value]))
	_room_difficulty.value_changed.connect(func(value: int) -> void: Network.set_room_option("difficulty", value))
	_room_afk.value_changed.connect(func(value: int) -> void: Network.set_room_option("afk", Network.AFK_CHOICES[value]))
	_room_public.value_changed.connect(func(value: int) -> void: Network.set_room_option("public", value == 1))
	_option_row(options, tr("Length"), _room_turns)
	_option_row(options, tr("Difficulty"), _room_difficulty)
	_option_row(options, tr("Time to act"), _room_afk)
	_public_row = _option_row(options, tr("Who can join"), _room_public)


## The room's options as the host has set them; only the host can change them.
func _refresh_room_options(host: bool) -> void:
	if Network.room.is_empty():
		return
	_room_turns.set_value_no_signal(maxi(0, Network.TURN_CHOICES.find(int(Network.room.turns))))
	_room_difficulty.set_value_no_signal(int(Network.room.difficulty))
	_room_afk.set_value_no_signal(maxi(0, Network.AFK_CHOICES.find(int(Network.room.afk))))
	_room_public.set_value_no_signal(1 if Network.room.public else 0)
	for stepper: Stepper in [_room_turns, _room_difficulty, _room_afk, _room_public]:
		stepper.editable = host
	_public_row.visible = Network.mode == Network.Mode.STEAM


## The page's first control, for a key or pad press when nothing has focus.
func _default_focus() -> Control:
	return Controls.first_focusable(_page) if _page else null


## "Rejoin your game": shown when a game this player was in is still going (after a crash or
## a lost connection); while it tries, the same button stops trying.
func _add_rejoin_button() -> void:
	_rejoin_button.custom_minimum_size = Vector2(0, 48)
	_rejoin_button.theme_type_variation = &"PlankButton"
	_rejoin_button.pressed.connect(func() -> void:
		if Network.reconnecting:
			Network.give_up_reconnecting()
		else:
			Network.rejoin_saved_game())
	var main := %MainPage
	main.add_child(_rejoin_button)
	main.move_child(_rejoin_button, %SoloButton.get_index())


func _update_rejoin() -> void:
	_rejoin_button.visible = Network.reconnecting or (not Network.in_room() and Network.saved_rejoin_available())
	_rejoin_button.text = tr("Stop rejoining") if Network.reconnecting else tr("Rejoin your game")
	if Network.reconnecting:
		_show_status(tr("Rejoining your game… (attempt {attempt})").format({"attempt": Network.reconnect_attempt}))


func _on_language_changed() -> void:
	_reopen_settings = true
	Transition.change_scene(Network.MENU_SCENE)


func _show_page(page: Control) -> void:
	if page == _page:
		return
	var old := _page
	_page = page
	var duration := 0.0 if Settings.reduced_motion() else 0.14
	if duration > 0.0 and old.visible:
		var out := create_tween()
		out.tween_property(old, "modulate:a", 0.0, duration)
		await out.finished
	for p in _pages:
		p.visible = p == page
	Controls.focus(Controls.first_focusable(page))
	page.modulate.a = 0.0 if duration > 0.0 else 1.0
	if duration > 0.0:
		create_tween().tween_property(page, "modulate:a", 1.0, duration)
	if page == %OnlinePage and SteamService.available:
		_refresh_tables()


func _sway_sign() -> void:
	if Settings.reduced_motion():
		return
	await get_tree().process_frame
	_sign.pivot_offset = Vector2(_sign.size.x / 2.0, -36.0)
	var tween := create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_sign, "rotation_degrees", 0.9, 3.0)
	tween.tween_property(_sign, "rotation_degrees", -0.9, 3.0)


## Lists friends' tables at once; public ones are added when Steam answers.
func _refresh_tables() -> void:
	_tables = SteamService.friend_lobbies()
	_draw_tables()
	SteamService.request_public_lobbies()


func _on_public_lobbies_found(lobbies: Array[Dictionary]) -> void:
	var known := {}
	for table in _tables:
		known[table.lobby] = true
	for lobby in lobbies:
		if not known.has(lobby.lobby):
			_tables.append(lobby)
	_draw_tables()


func _draw_tables() -> void:
	_friend_list.clear()
	for table in _tables:
		var text := tr("{player}'s table").format({"player": table.name})
		if table.has("seats"):
			text += "  " + tr("({seats} of {max} seats, {turns} turns)").format({"seats": table.seats, "max": Content.MAX_SEATS, "turns": table.turns})
		_friend_list.add_item(text)
	_join_friend_button.disabled = true
	if _tables.is_empty():
		_friend_list.add_item(tr("No tables are open right now. Host one!"))
		_friend_list.set_item_disabled(0, true)
		_friend_list.set_item_selectable(0, false)


func _on_join_friend_pressed() -> void:
	var selected := _friend_list.get_selected_items()
	if not selected.is_empty() and selected[0] < _tables.size():
		_show_error(Network.join_steam(_tables[selected[0]].lobby))


func _refresh() -> void:
	var in_room := Network.in_room() and not Network.roster.is_empty()
	if in_room and _page != %RoomPage:
		Audio.play(&"door_open", -6.0)
		_show_page(%RoomPage)
	elif not in_room and _page == %RoomPage:
		Audio.play(&"door_close", -6.0)
		_show_page(%MainPage)
	_update_rejoin()
	if not in_room:
		return
	var host := Network.is_host()
	_room_title.text = tr("The table ({seats} of {max} seats)").format({"seats": Network.roster.size(), "max": Content.MAX_SEATS})
	for child in _roster_list.get_children():
		child.queue_free()
	for i in Network.roster.size():
		var seat: Dictionary = Network.roster[i]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row.add_child(SeatStyle.make_seal(i, seat.name, 28))
		var label := Label.new()
		var tags := PackedStringArray()
		if seat.bot:
			tags.append(tr("bot"))
		if seat.id == 1 and not seat.bot:
			tags.append(tr("host"))
		if seat.id == Network.local_id():
			tags.append(tr("you"))
		label.text = seat.name + (" (%s)" % ", ".join(tags) if not tags.is_empty() else "")
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.clip_text = true
		row.add_child(label)
		if host and not seat.bot and seat.id != Network.local_id():
			var kick := Button.new()
			kick.text = tr("Remove")
			kick.theme_type_variation = &"TextButton"
			kick.pressed.connect(Network.kick.bind(seat.id))
			row.add_child(kick)
		_roster_list.add_child(row)
	_refresh_room_options(host)
	_host_row.visible = host
	_start_button.visible = host
	_add_bot_button.disabled = Network.roster.size() >= Content.MAX_SEATS
	_remove_bot_button.disabled = not Network.roster.any(func(seat: Dictionary) -> bool: return seat.bot)
	_invite_button.visible = Network.mode == Network.Mode.STEAM
	_start_button.disabled = not Network.can_start()
	if host:
		_room_hint.text = tr("{min} to {max} players. Add bots to fill empty seats.").format({"min": Content.MIN_SEATS, "max": Content.MAX_SEATS})
	else:
		_room_hint.text = tr("Waiting for the host to deal you in.")


func _show_error(message: String) -> void:
	if not message.is_empty():
		_show_status(message)


func _show_status(message: String) -> void:
	_status_label.text = message
