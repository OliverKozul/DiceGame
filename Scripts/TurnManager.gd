extends Node


var player_ui : CanvasLayer


func initialize(ui : CanvasLayer) -> void:
	player_ui = ui
	
@rpc("any_peer", "call_local")
func transition_to_intention_phase() -> void:
	player_ui.sync_manager.rpc("sync_phase", "intention")  
	print("All players have rolled. Transitioning to intention phase.")
	
	player_ui.buttons.show_buttons("action")
	player_ui.current_player_label.text = "Declare your intention!"
	var rect = Utils.create_rect()
	player_ui.add_child(rect)
	var tween = get_tree().create_tween()
	tween.tween_property(rect, "scale", Vector2(0, 0), 5.0)  # 5-second shrink
	tween.finished.connect(_on_tween_completed.bind(rect))

func _on_tween_completed(rect: TextureRect) -> void:
	rect.queue_free()  # Remove the TextureRect
	rpc("transition_to_action_phase")

### **Player Rolls**
@rpc("any_peer", "call_local")
func transition_to_action_phase() -> void:
	player_ui.sync_manager.rpc("sync_phase", "action")  # Synchronize phase transition
	print("All players have shown their intentions. Transitioning to action phase.")
	determine_player_order()
	rpc("allow_current_player_action")
	
@rpc("any_peer", "call_local")
func transition_to_resolve_phase() -> void:
	player_ui.sync_manager.rpc("sync_phase", "resolve")  # Synchronize phase transition
	print("All players have acted. Transitioning to resolve phase.")
	rpc("allow_current_player_action")

@rpc("any_peer", "call_local")
func sync_phase(new_phase : String) -> void:
	Global.current_phase = new_phase

### **Check if All Players Have Performed an Action**
func check_all_players_acted() -> bool:
	return Global.current_player_index >= Global.player_order.size()

### **Determine Action Order**
func determine_player_order() -> void:
	var all_players = multiplayer.get_peers()
	all_players.append(multiplayer.get_unique_id())  # Include the host in the list
	Global.player_order = Array(all_players)
	if multiplayer.is_server():
		Global.player_order.sort_custom(_compare_players)
		player_ui.sync_manager.rpc("sync_player_order", Global.player_order)
	else:
		rpc_id(1, "request_player_order")
	
	Global.current_player_index = 0

@rpc("any_peer", "call_local")
func request_player_order() -> void:
	if multiplayer.is_server():
		player_ui.sync_manager.rpc_id(multiplayer.get_remote_sender_id(), "sync_player_order", Global.player_order)
		
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
	var current_player = Global.player_order[Global.current_player_index]
	
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
	Global.current_player_index += 1
	player_ui.current_player_label.text = "Waiting for next turn."
	player_ui.sync_manager.rpc("sync_current_player_index", Global.current_player_index)
	
	if check_all_players_acted():
		print("All players have acted. Transitioning to next turn.")
		initiate_next_turn()
	else:
		rpc("allow_current_player_action")
