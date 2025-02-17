extends Manager


### **Player Rolls**
@rpc("any_peer", "call_local")
func roll_button_pressed(player_id: int) -> void:
	# Prevent rolling more than once per turn
	if Global.players_rolled.get(player_id, false):
		print("You already rolled this turn!")
		return
		
	var roll_results = []
	var roll_results_text = "You rolled: ["
	var die_count = len(Global.player_info[player_id].die_faces)
	
	for i in die_count:
		var roll_result = Global.player_info[player_id].die_faces[i][randi() % Global.player_info[player_id].die_faces[i].size()]
		roll_results_text += str(Global.player_info[player_id].die_face_values[i][roll_result]) + " " + roll_result
		
		if i != die_count - 1:
			roll_results_text += ", "
		
		match roll_result:
			"💰":
				SignalBus._on_gold_roll.emit(player_id, Global.player_info[player_id].die_face_values[i][roll_result])
			"🧠":
				SignalBus._on_cunning_roll.emit(player_id, Global.player_info[player_id].die_face_values[i][roll_result])
			"⚔":
				SignalBus._on_combat_roll.emit(player_id, Global.player_info[player_id].die_face_values[i][roll_result])
				
		roll_results.append(roll_result)
		
	# Send result to all players
	player_ui.turn_info_labels.roll_result.text = roll_results_text + "]"
	player_ui.sync_manager.rpc("sync_roll_results", player_id, roll_results)
	player_ui.sync_manager.rpc("sync_player_info", player_id, Global.player_info[player_id])
		
	Global.players_rolled[player_id] = true  # Mark as rolled

	# Check if all players have rolled
	if check_all_players_rolled():
		player_ui.turn_manager.rpc_id(1, "transition_to_intention_phase")
		
### **Check if All Players Have Rolled**
func check_all_players_rolled() -> bool:
	for id in Global.players:
		if not Global.players_rolled.get(id, false):
			return false

	return true
