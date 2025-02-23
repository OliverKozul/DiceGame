extends Manager
class_name RollManager


### **Player Rolls**
@rpc("any_peer", "call_local", "reliable")
func roll_button_pressed(player_id: int) -> void:
	if Global.players_rolled.get(player_id, false):
		print("You already rolled this turn!")
		return
		
	var roll_results = []
	var roll_texts = []
	var die_count = len(Global.player_info[player_id].die_faces)
	var mapping = {
		"💰": {"attr": "gold", "signal": SignalBus._on_gold_roll},
		"🧠": {"attr": "cunning", "signal": SignalBus._on_cunning_roll},
		"⚔": {"attr": "combat", "signal": SignalBus._on_combat_roll}
	}
	
	for i in range(die_count):
		var die_faces = Global.player_info[player_id].die_faces[i]
		var roll_result = die_faces[randi() % die_faces.size()]
		
		if not mapping.has(roll_result):
			continue
			
		roll_results.append(roll_result)
		
		var attr = mapping[roll_result].attr
		var signal_func = mapping[roll_result].signal
		var resource_before = Global.player_info[player_id][attr]
		signal_func.emit(player_id, Global.player_info[player_id].die_face_values[i][roll_result])
		var resource = Global.player_info[player_id][attr] - resource_before
		
		roll_texts.append(str(resource) + " " + roll_result)
		
	var roll_results_text = Global.player_names[player_id] + " rolled: [" + ", ".join(roll_texts) + "]"
	player_ui.current_player_label.text = "Wait for other players to roll."
	player_ui.sync_manager.rpc("sync_roll_results", player_id, roll_results, roll_results_text)
	player_ui.sync_manager.rpc("sync_player_info", player_id, Global.player_info[player_id])
