extends Manager
class_name RollManager


### **Player Rolls**
@rpc("any_peer", "call_local", "reliable")
func roll_button_pressed(player_id: int) -> void:
	if Global.players_rolled.get(player_id, false):
		print("You already rolled this turn!")
		return
		
	var roll_results = []
	var roll_results_text = Global.player_names[player_id] + " rolled: ["
	var die_count = len(Global.player_info[player_id].die_faces)
	
	for i in die_count:
		var roll_result = Global.player_info[player_id].die_faces[i][randi() % Global.player_info[player_id].die_faces[i].size()]
		var resource = 0
		
		match roll_result:
			"💰":
				var resource_before = Global.player_info[player_id].gold
				SignalBus._on_gold_roll.emit(player_id, Global.player_info[player_id].die_face_values[i][roll_result])
				resource = Global.player_info[player_id].gold - resource_before
			"🧠":
				var resource_before = Global.player_info[player_id].cunning
				SignalBus._on_cunning_roll.emit(player_id, Global.player_info[player_id].die_face_values[i][roll_result])
				resource = Global.player_info[player_id].cunning - resource_before
			"⚔":
				var resource_before = Global.player_info[player_id].combat
				SignalBus._on_combat_roll.emit(player_id, Global.player_info[player_id].die_face_values[i][roll_result])
				resource = Global.player_info[player_id].combat - resource_before
				
		roll_results_text += str(resource) + " " + roll_result
		
		if i != die_count - 1:
			roll_results_text += ", "
		
		roll_results.append(roll_result)
		
	roll_results_text += "]"
	player_ui.current_player_label.text = "Wait for other players to roll."
	player_ui.sync_manager.rpc("sync_roll_results", player_id, roll_results, roll_results_text)
	player_ui.sync_manager.rpc("sync_player_info", player_id, Global.player_info[player_id])
	
