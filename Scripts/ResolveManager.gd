extends Manager


@rpc("any_peer", "call_local")
func resolve_button_pressed(player_id : int) -> void:
	Global.players_resolved[player_id] = true
	
	if Global.players_acted.has(player_id) and Global.players_acted[player_id]:
		resolve_current_player_turn(player_id)
	
	if player_id != multiplayer.get_unique_id():
		return

func resolve_current_player_turn(player_id: int) -> void:
	print("Resolving turn for player: ", player_id)
	
	var action = Global.players_acted[player_id]
	
	match action["action"]:
		Enums.Action.SHOP:
			show_shop(player_id)
			player_ui.combat_distribution.show_combat_ui(player_id, Enums.Target.NONE)
		Enums.Action.ATTACK:
			player_ui.combat_distribution.show_combat_ui(player_id, action["target"])
		Enums.Action.SKIP:
			perform_skip(player_id)
		_:
			print("Unknown action for player: ", player_id)
	
	Global.players_acted[player_id] = false

func show_shop(player_id: int) -> void:
	if player_id == multiplayer.get_unique_id():
		player_ui.shop.show()
	print("Showing shop to player: ", player_id)

func perform_skip(player_id: int) -> void:
	print("Player ", player_id, " is skipping")
	if player_id == multiplayer.get_unique_id():
		player_ui.turn_manager.advance_to_next_player()
	
