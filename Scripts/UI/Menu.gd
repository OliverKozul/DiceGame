extends Control
## Main menu and pre-game room. All state lives in Network; this screen only reflects it.

## Steam's "+connect_lobby" launch argument is handled once per run.
static var _launch_lobby_checked := false

var _friend_lobbies: Array[Dictionary] = []

@onready var _main_panel: Control = %MainPanel
@onready var _room_panel: Control = %RoomPanel
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


func _ready() -> void:
	%SoloButton.pressed.connect(_on_solo_pressed)
	_host_steam_button.pressed.connect(func() -> void: _show_error(Network.host_steam()))
	_refresh_friends_button.pressed.connect(_refresh_friend_lobbies)
	_friend_list.item_selected.connect(func(_index: int) -> void: _join_friend_button.disabled = false)
	_join_friend_button.pressed.connect(_on_join_friend_pressed)
	%HostLanButton.pressed.connect(func() -> void: _show_error(Network.host_enet(_player_name())))
	%JoinLanButton.pressed.connect(func() -> void: _show_error(Network.join_enet(_player_name(), _address_edit.text)))
	_add_bot_button.pressed.connect(Network.add_bot)
	_remove_bot_button.pressed.connect(Network.remove_bot)
	_invite_button.pressed.connect(Network.invite_friends)
	_start_button.pressed.connect(func() -> void: Network.start_game())
	%LeaveRoomButton.pressed.connect(func() -> void: Network.leave())

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
	_refresh()

	if not _launch_lobby_checked:
		_launch_lobby_checked = true
		var lobby := SteamService.launch_lobby()
		if lobby != 0:
			_show_error(Network.join_steam(lobby))


func _player_name() -> String:
	return _name_edit.text


func _on_solo_pressed() -> void:
	Network.play_offline(_player_name(), int(_bots_spin.value))


func _refresh_friend_lobbies() -> void:
	_friend_lobbies = SteamService.friend_lobbies()
	_friend_list.clear()
	for lobby in _friend_lobbies:
		_friend_list.add_item("%s's lobby" % lobby.name)
	_join_friend_button.disabled = true
	if _friend_lobbies.is_empty():
		_show_status("No friends are hosting right now.")


func _on_join_friend_pressed() -> void:
	var selected := _friend_list.get_selected_items()
	if not selected.is_empty():
		_show_error(Network.join_steam(_friend_lobbies[selected[0]].lobby))


func _refresh() -> void:
	var in_room := Network.in_room() and not Network.roster.is_empty()
	_main_panel.visible = not in_room
	_room_panel.visible = in_room
	if not in_room:
		return
	var host := Network.is_host()
	_room_title.text = "Lobby (%d/%d)" % [Network.roster.size(), Content.MAX_SEATS]
	for child in _roster_list.get_children():
		child.queue_free()
	for seat in Network.roster:
		var label := Label.new()
		var tags := PackedStringArray()
		if seat.bot:
			tags.append("bot")
		if seat.id == 1 and not seat.bot:
			tags.append("host")
		if seat.id == Network.local_id():
			tags.append("you")
		label.text = seat.name + (" (%s)" % ", ".join(tags) if not tags.is_empty() else "")
		_roster_list.add_child(label)
	_host_row.visible = host
	_add_bot_button.disabled = Network.roster.size() >= Content.MAX_SEATS
	_remove_bot_button.disabled = not Network.roster.any(func(seat: Dictionary) -> bool: return seat.bot)
	_invite_button.visible = Network.mode == Network.Mode.STEAM
	_start_button.disabled = not Network.can_start()
	if host:
		_room_hint.text = "Start when everyone is here. %d to %d players; bots fill empty seats." % [Content.MIN_SEATS, Content.MAX_SEATS]
	else:
		_room_hint.text = "Waiting for the host to start the game."


func _show_error(message: String) -> void:
	if not message.is_empty():
		_show_status(message)


func _show_status(message: String) -> void:
	_status_label.text = message
