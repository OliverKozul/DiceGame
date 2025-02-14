extends Manager


### **Player Rolls**
@rpc("any_peer", "call_local")
func roll_button_pressed(roller_id: int) -> void:
	var player_id = multiplayer.get_unique_id()
	
	if roller_id != player_id:
		return
		
	if Global.current_phase != "roll":
		print("It's not the roll phase!")
		return
	
	# Prevent rolling more than once per turn
	if Global.players_rolled.get(player_id, false):
		print("You already rolled this turn!")
		return
	
	var roll_result = Global.player_info[player_id].die_faces[randi() % Global.player_info[player_id].die_faces.size()]
	player_ui.turn_info_labels.roll_result.text = "You rolled: " + str(Global.player_info[player_id].die_face_values[roll_result]) + " " + roll_result
	
	match roll_result:
		"💰":
			SignalBus._on_gold_roll.emit(player_id, Global.player_info[player_id].die_face_values[roll_result])
		"🧠":
			SignalBus._on_cunning_roll.emit(player_id, Global.player_info[player_id].die_face_values[roll_result])
		"⚔":
			SignalBus._on_combat_roll.emit(player_id, Global.player_info[player_id].die_face_values[roll_result])
		
	Global.players_rolled[player_id] = true  # Mark as rolled
	
	# Send result to all players
	player_ui.sync_manager.rpc("sync_roll_result", player_id, roll_result)
	player_ui.sync_manager.rpc("sync_player_info", player_id, Global.player_info[player_id])

	# Check if all players have rolled
	if check_all_players_rolled():
		player_ui.turn_manager.rpc_id(1, "transition_to_intention_phase")
		
### **Check if All Players Have Rolled**
func check_all_players_rolled() -> bool:
	var all_players = multiplayer.get_peers()
	all_players.append(multiplayer.get_unique_id())  # Include the host in the list

	var all_rolled = true
	for id in all_players:
		if not Global.players_rolled.get(id, false):
			all_rolled = false
			break

	return all_rolled
