extends Manager
class_name RollManager


### **Player Rolls**
@rpc("any_peer", "call_local")
func roll_button_pressed(player_id: int) -> void:
	# Prevent rolling more than once per turn
	if Global.players_rolled.get(player_id, false):
		print("You already rolled this turn!")
		return
		
	var roll_results = []
	var roll_results_text = Global.player_names[player_id] + " rolled: ["
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
		
	roll_results_text += "]"
	player_ui.current_player_label.text = "Wait for other players to roll."
	player_ui.sync_manager.rpc("sync_roll_results", player_id, roll_results, roll_results_text)
	player_ui.sync_manager.rpc("sync_player_info", player_id, Global.player_info[player_id])
		
	Global.players_rolled[player_id] = true

	if check_all_players_rolled():
		player_ui.turn_manager.rpc_id(1, "transition_to_intention_phase")
		
### **Check if All Players Have Rolled**
func check_all_players_rolled() -> bool:
	for id in Global.players:
		if not Global.players_rolled.get(id, false):
			return false

	return true
