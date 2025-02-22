extends Manager
class_name ResolveManager


@rpc("any_peer", "call_local", "reliable")
func resolve_current_player_turn(player_id: int) -> void:
	Global.players_resolved[player_id] = true
	player_ui.buttons.show_buttons("wait")
	
	if player_id != multiplayer.get_unique_id():
		return
		
	var action = Global.players_acted[player_id]
	
	match action["action"]:
		Enums.Action.SHOP:
			show_shop(player_id)
			
			if Global.player_info[player_id].combat > 0 and len(Global.players) > 1:
				player_ui.combat_distribution.show_combat_ui(Enums.Target.NONE)
			else:
				player_ui.turn_manager.rpc_id(Global.host_id, "advance_to_next_player")
		Enums.Action.ATTACK:
			player_ui.combat_distribution.show_combat_ui(action["target"])
		Enums.Action.SKIP:
			perform_skip(player_id)
		_:
			print("Unknown action for player: ", player_id)
	
	Global.players_acted[player_id] = false

@rpc("any_peer", "call_local", "reliable")
func show_shop(player_id: int) -> void:
	player_ui.shop.open()
	print("Showing shop to player: ", Global.player_names[player_id])

@rpc("any_peer", "call_local", "reliable")
func perform_skip(player_id: int) -> void:
	print("Player ", Global.player_names[player_id], " is skipping")
	player_ui.turn_manager.rpc_id(Global.host_id, "advance_to_next_player")
	
