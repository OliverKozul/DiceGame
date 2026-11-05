extends Node
## Tells Steam what this player is doing, for the friends list: the status text, the group they
## play with, and how to join them ("Join game" works while they wait at a table). The status
## text comes from the tokens in steam/rich_presence.vdf, which go up to Steamworks.


func _ready() -> void:
	Network.roster_changed.connect(_update)
	Network.room_changed.connect(func(_in_room: bool) -> void: _update())
	Session.view_changed.connect(func(_view: GameState) -> void: _update())
	_update()


func _update() -> void:
	var values := {"steam_display": "#Status_Menu"}
	var lobby: int = SteamService.lobby_id
	if Network.in_game and Session.view:
		values = {"steam_display": "#Status_Game", "turn": str(Session.view.turn), "turns": str(Session.view.max_turns)}
	elif Network.in_room():
		values = {"steam_display": "#Status_Room", "seats": str(Network.roster.size()), "max": str(Content.MAX_SEATS)}
		if lobby != 0:
			values["connect"] = "+connect_lobby %d" % lobby
	if lobby != 0 and Network.in_room():
		values["steam_player_group"] = str(lobby)
		values["steam_player_group_size"] = str(Network.human_count())
	SteamService.set_presence(values)
