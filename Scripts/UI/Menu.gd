extends Control
## Main menu and pre-game room. All session state lives in Network; this screen reflects it.

const CREDITS := """[b]Game design and code[/b]
Oliver Kozul, with Claude.

[b]Sound effects[/b]
Casino Audio, RPG Audio and UI SFX Set by Kenney (kenney.nl), CC0.

[b]Music and ambience[/b]
The Old Tower Inn and Medieval: Kings Feast by RandomMind, CC0.
Fireplace Sound Loop by PagDev, CC0.

[b]Fonts[/b]
Lora by Cyreal (SIL Open Font License). Cloister Black by Dieter Steffmann.

Icons, shaders, dice and everything else were made for this game."""

## Steam's "+connect_lobby" launch argument is handled once per run.
static var _launch_lobby_checked := false

var _friend_lobbies: Array[Dictionary] = []
var _page: Control
var _settings := SettingsPanel.new()
var _rules := RulesBook.new()
var _confirm := ConfirmOverlay.new()

@onready var _pages: Array[Control] = [%MainPage, %SoloPage, %OnlinePage, %RoomPage, %CreditsPage]
@onready var _name_edit: LineEdit = %NameEdit
@onready var _bots_spin: SpinBox = %BotsSpin
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


func _ready() -> void:
	add_child(_settings)
	add_child(_rules)
	add_child(_confirm)
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
	%QuitButton.pressed.connect(func() -> void: _confirm.ask("Leave the tavern?", "The game closes.", "Quit"))
	%StartSoloButton.pressed.connect(func() -> void: Network.play_offline(_player_name(), int(_bots_spin.value)))
	%SoloBackButton.pressed.connect(_show_page.bind(%MainPage))
	_host_steam_button.pressed.connect(func() -> void: _show_error(Network.host_steam()))
	_refresh_friends_button.pressed.connect(_refresh_friend_lobbies)
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
	%CreditsText.text = CREDITS

	Network.roster_changed.connect(_refresh)
	Network.room_changed.connect(func(_in_room: bool) -> void: _refresh())
	Network.status_changed.connect(_show_status)

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
	_sway_sign()

	if not _launch_lobby_checked:
		_launch_lobby_checked = true
		var lobby := SteamService.launch_lobby()
		if lobby != 0:
			_show_error(Network.join_steam(lobby))


func _player_name() -> String:
	return _name_edit.text


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
	page.modulate.a = 0.0 if duration > 0.0 else 1.0
	if duration > 0.0:
		create_tween().tween_property(page, "modulate:a", 1.0, duration)
	if page == %OnlinePage and SteamService.available:
		_refresh_friend_lobbies()


func _sway_sign() -> void:
	if Settings.reduced_motion():
		return
	await get_tree().process_frame
	_sign.pivot_offset = Vector2(_sign.size.x / 2.0, -36.0)
	var tween := create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_sign, "rotation_degrees", 0.9, 3.0)
	tween.tween_property(_sign, "rotation_degrees", -0.9, 3.0)


func _refresh_friend_lobbies() -> void:
	_friend_lobbies = SteamService.friend_lobbies()
	_friend_list.clear()
	for lobby in _friend_lobbies:
		_friend_list.add_item("%s's table" % lobby.name)
	_join_friend_button.disabled = true
	if _friend_lobbies.is_empty():
		_friend_list.add_item("No friends are hosting right now.")
		_friend_list.set_item_disabled(0, true)
		_friend_list.set_item_selectable(0, false)


func _on_join_friend_pressed() -> void:
	var selected := _friend_list.get_selected_items()
	if not selected.is_empty() and selected[0] < _friend_lobbies.size():
		_show_error(Network.join_steam(_friend_lobbies[selected[0]].lobby))


func _refresh() -> void:
	var in_room := Network.in_room() and not Network.roster.is_empty()
	if in_room and _page != %RoomPage:
		Audio.play(&"door_open", -6.0)
		_show_page(%RoomPage)
	elif not in_room and _page == %RoomPage:
		Audio.play(&"door_close", -6.0)
		_show_page(%MainPage)
	if not in_room:
		return
	var host := Network.is_host()
	_room_title.text = "The table (%d of %d seats)" % [Network.roster.size(), Content.MAX_SEATS]
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
			tags.append("bot")
		if seat.id == 1 and not seat.bot:
			tags.append("host")
		if seat.id == Network.local_id():
			tags.append("you")
		label.text = seat.name + (" (%s)" % ", ".join(tags) if not tags.is_empty() else "")
		row.add_child(label)
		_roster_list.add_child(row)
	_host_row.visible = host
	_start_button.visible = host
	_add_bot_button.disabled = Network.roster.size() >= Content.MAX_SEATS
	_remove_bot_button.disabled = not Network.roster.any(func(seat: Dictionary) -> bool: return seat.bot)
	_invite_button.visible = Network.mode == Network.Mode.STEAM
	_start_button.disabled = not Network.can_start()
	if host:
		_room_hint.text = "%d to %d players. Add bots to fill empty seats." % [Content.MIN_SEATS, Content.MAX_SEATS]
	else:
		_room_hint.text = "Waiting for the host to deal you in."


func _show_error(message: String) -> void:
	if not message.is_empty():
		_show_status(message)


func _show_status(message: String) -> void:
	_status_label.text = message
