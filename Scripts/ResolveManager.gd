extends Manager


@rpc("any_peer", "call_local")
func resolve_button_pressed(player_id : int) -> void:
	Global.players_resolved[player_id] = true  # Mark as resolved
	
	# Check if the current player has acted
	if Global.players_acted.has(player_id) and Global.players_acted[player_id]:
		# Resolve the current player's turn
		resolve_current_player_turn(player_id)
	
	if player_id != multiplayer.get_unique_id():
		return
	
	player_ui.turn_manager.advance_to_next_player()

func resolve_current_player_turn(player_id: int) -> void:
	# Add logic to resolve the current player's turn
	print("Resolving turn for player: ", player_id)
	
	# Get the player's action
	var action = Global.players_acted[player_id]
	
	match action["action"]:
		Enums.Action.SHOP:
			show_shop(player_id)
			player_ui.combat_distribution.show_combat_ui(player_id, Enums.Target.NONE)
		Enums.Action.ATTACK:
			player_ui.combat_distribution.show_combat_ui(player_id, Enums.Target.PLAYER)
		Enums.Action.SKIP:
			perform_skip(player_id)
		_:
			print("Unknown action for player: ", player_id)
	
	# Clear the player's actions
	Global.players_acted[player_id] = false

func show_shop(player_id: int) -> void:
	# Logic to show the shop to the player
	if player_id == multiplayer.get_unique_id():
		player_ui.shop.show()
	print("Showing shop to player: ", player_id)

func perform_skip(player_id: int) -> void:
	# Logic to perform a defend
	print("Player ", player_id, " is skipping")
	
