extends Manager


@rpc("any_peer", "call_local")
func resolve_button_pressed(player_id: int) -> void:
	Global.players_resolved[player_id] = true
	player_ui.buttons.show_buttons("wait")
	
	if Global.players_acted.has(player_id) and Global.players_acted[player_id] and player_id == multiplayer.get_unique_id():
		resolve_current_player_turn(player_id)
		
	Global.players_acted[player_id] = false

func resolve_current_player_turn(player_id: int) -> void:
	var action = Global.players_acted[player_id]
	
	match action["action"]:
		Enums.Action.SHOP:
			show_shop(player_id)
			player_ui.combat_distribution.show_combat_ui(Enums.Target.NONE)
		Enums.Action.ATTACK:
			player_ui.combat_distribution.show_combat_ui(action["target"])
		Enums.Action.SKIP:
			perform_skip(player_id)
		_:
			print("Unknown action for player: ", player_id)
	
	Global.players_acted[player_id] = false

@rpc("any_peer", "call_local")
func show_shop(player_id: int) -> void:
	player_ui.shop.show()
	print("Showing shop to player: ", player_id)

@rpc("any_peer", "call_local")
func perform_skip(player_id: int) -> void:
	print("Player ", player_id, " is skipping")
	player_ui.turn_manager.advance_to_next_player()
	
