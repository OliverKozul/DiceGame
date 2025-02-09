extends Node


var player_ui : CanvasLayer


func initialize(ui : CanvasLayer) -> void:
	player_ui = ui

### **Player Rolls**
@rpc("any_peer", "call_local")
func transition_to_action_phase() -> void:
	player_ui.sync_manager.rpc("sync_phase", "action")  # Synchronize phase transition
	print("All players have rolled. Transitioning to action phase.")
	determine_action_order()
	rpc("allow_current_player_action")

@rpc("any_peer", "call_local")
func sync_phase(new_phase : String) -> void:
	Global.current_phase = new_phase

### **Check if All Players Have Performed an Action**
func check_all_players_acted() -> bool:
	return Global.current_action_index >= Global.action_order.size()

### **Determine Action Order**
func determine_action_order() -> void:
	var all_players = multiplayer.get_peers()
	all_players.append(multiplayer.get_unique_id())  # Include the host in the list
	Global.action_order = Array(all_players)
	if multiplayer.is_server():
		Global.action_order.sort_custom(_compare_players)
		player_ui.sync_manager.rpc("sync_action_order", Global.action_order)
	else:
		rpc_id(1, "request_action_order")
	
	Global.current_action_index = 0

@rpc("any_peer", "call_local")
func request_action_order() -> void:
	if multiplayer.is_server():
		player_ui.sync_manager.rpc_id(multiplayer.get_remote_sender_id(), "sync_action_order", Global.action_order)
		
### **Request Turn Sync (For Late Joiners)**
@rpc("any_peer", "call_local")
func request_turn_sync() -> void:
	if multiplayer.is_server():
		player_ui.sync_manager.rpc_id(multiplayer.get_remote_sender_id(), "sync_turn", Global.current_turn)

### **Compare Players for Sorting**
func _compare_players(player_b_id : int, player_a_id : int) -> bool:
	var cunning_a = Global.player_info[player_a_id].cunning
	var cunning_b = Global.player_info[player_b_id].cunning
	if cunning_a != cunning_b:
		return true if cunning_a - cunning_b > 0 else false
	
	var gold_a = Global.player_info[player_a_id].gold
	var gold_b = Global.player_info[player_b_id].gold
	
	if gold_a != gold_b:
		return true if gold_a - gold_b > 0 else false
	
	return true if player_ui.rng.randi() % 2 == 0 else false  # Random tie-breaker using rng

### **Allow Current Player Action**
@rpc("any_peer", "call_local")
func allow_current_player_action() -> void:
	var current_player = Global.action_order[Global.current_action_index]
	
	if multiplayer.get_unique_id() == current_player:
		player_ui.buttons.show_buttons("action")
		player_ui.current_player_label.text = "It's your turn!"
	else:
		player_ui.buttons.show_buttons("wait")
		player_ui.current_player_label.text = "Waiting for player %s" % str(current_player)

### **Next Phase (Only Host Can Trigger)**
@rpc("authority", "call_local")
func initiate_next_turn() -> void:
	if Global.current_phase != "action":
		print("Cannot transition to next turn. It's not the action phase!")
		return
	
	if not check_all_players_acted():
		print("Not all players have performed an action!")
		return
	
	Global.current_turn += 1
	player_ui.sync_manager.rpc("sync_turn", Global.current_turn)
	print("Turn ", Global.current_turn)
	
### **Advance to Next Player**
@rpc("any_peer", "call_local")
func advance_to_next_player() -> void:
	Global.current_action_index += 1
	player_ui.current_player_label.text = "Waiting for next turn."
	player_ui.sync_manager.rpc("sync_current_action_index", Global.current_action_index)
	
	if check_all_players_acted():
		print("All players have acted. Transitioning to next turn.")
		initiate_next_turn()
	else:
		rpc("allow_current_player_action")
