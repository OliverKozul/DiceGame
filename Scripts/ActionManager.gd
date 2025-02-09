extends Node


var player_ui : CanvasLayer


func initialize(ui : CanvasLayer):
	player_ui = ui

### **Attack Player**
@rpc("any_peer", "call_local")
func attack_player_button_pressed(player_id : int) -> void:
	Global.players_acted[player_id] = true  # Mark as acted
	
	if player_id != multiplayer.get_unique_id():
		return
		
	
	player_ui.turn_info_labels.action.text = "You attacked another player."
	distribute_combat("player")
	player_ui.turn_manager.advance_to_next_player()

### **Attack Mobs**
@rpc("any_peer", "call_local")
func attack_mobs_button_pressed(player_id : int) -> void:
	Global.players_acted[player_id] = true  # Mark as acted
	
	if player_id != multiplayer.get_unique_id():
		return
		
	player_ui.turn_info_labels.action.text = "You attacked a mob."
	distribute_combat("mob")
	player_ui.turn_manager.advance_to_next_player()

### **Attack Boss**
@rpc("any_peer", "call_local")
func attack_boss_button_pressed(player_id : int) -> void:
	Global.players_acted[player_id] = true  # Mark as acted
	
	if player_id != multiplayer.get_unique_id():
		return
		
	player_ui.turn_info_labels.action.text = "You attacked the boss."
	distribute_combat("boss")
	player_ui.turn_manager.advance_to_next_player()

### **Shop**
@rpc("any_peer", "call_local")
func shop_button_pressed(player_id : int) -> void:
	Global.players_acted[player_id] = true  # Mark as acted
	if player_id != multiplayer.get_unique_id():
		return
		
	player_ui.shop.show()
	
	player_ui.turn_manager.advance_to_next_player()

### **Skip**
@rpc("any_peer", "call_local")
func skip_button_pressed(player_id : int) -> void:
	Global.players_acted[player_id] = true  # Mark as acted
	if player_id != multiplayer.get_unique_id():
		return
		
	player_ui.turn_info_labels.action.text = "Turn skipped."
	
	player_ui.turn_manager.advance_to_next_player()
	
func distribute_combat(str):
	pass
