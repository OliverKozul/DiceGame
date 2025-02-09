extends Node


var player_ui : CanvasLayer


func initialize(ui : CanvasLayer):
	player_ui = ui

### **Attack Player**
@rpc("any_peer", "call_local")
func _on_attack_player_button_pressed() -> void:
	if Global.current_phase != "action":
		print("It's not the action phase!")
		return
	
	var player_id = multiplayer.get_unique_id()
	
	# Prevent performing action more than once per turn
	if Global.players_acted.get(player_id, false):
		print("You already performed an action this turn!")
		return
	
	if player_ui.turn_info_labels.roll_result.text.contains("⚔"):
		player_ui.turn_info_labels.action.text = "You attacked another player."
		Global.players_acted[player_id] = true  # Mark as acted
		# Implement damage to another player here
		player_ui.turn_manager.advance_to_next_player()
	else:
		player_ui.turn_info_labels.action.text = "You didn't roll an attack, try something else."

### **Attack Mobs**
@rpc("any_peer", "call_local")
func _on_attack_mobs_button_pressed() -> void:
	if Global.current_phase != "action":
		print("It's not the action phase!")
		return
	
	var player_id = multiplayer.get_unique_id()
	
	# Prevent performing action more than once per turn
	if Global.players_acted.get(player_id, false):
		print("You already performed an action this turn!")
		return
	
	if player_ui.turn_info_labels.roll_result.text.contains("⚔"):
		player_ui.turn_info_labels.action.text = "You attacked a mob."
		Global.players_acted[player_id] = true  # Mark as acted
		# Implement mob defeat and trinket reward here
		player_ui.turn_manager.advance_to_next_player()
	else:
		player_ui.turn_info_labels.action.text = "You didn't roll an attack, try something else."
	

### **Attack Boss**
@rpc("any_peer", "call_local")
func _on_attack_boss_button_pressed() -> void:
	if Global.current_phase != "action":
		print("It's not the action phase!")
		return
	
	var player_id = multiplayer.get_unique_id()
	
	# Prevent performing action more than once per turn
	if Global.players_acted.get(player_id, false):
		print("You already performed an action this turn!")
		return
	
	if player_ui.turn_info_labels.roll_result.text.contains("⚔"):
		player_ui.turn_info_labels.action.text = "You attacked the boss."
		Global.players_acted[player_id] = true  # Mark as acted
		# Implement boss fight logic here
		player_ui.turn_manager.advance_to_next_player()
	else:
		player_ui.turn_info_labels.action.text = "You didn't roll an attack, try something else."

### **Shop**
@rpc("any_peer", "call_local")
func _on_shop_button_pressed() -> void:
	if Global.current_phase != "action":
		print("It's not the action phase!")
		return
	
	var player_id = multiplayer.get_unique_id()
	
	# Prevent performing action more than once per turn
	if Global.players_acted.get(player_id, false):
		print("You already performed an action this turn!")
		return
		
	Global.players_acted[player_id] = true  # Mark as acted
	player_ui.shop.show()
	
	player_ui.turn_manager.advance_to_next_player()

### **Skip**
@rpc("any_peer", "call_local")
func _on_skip_button_pressed() -> void:
	if Global.current_phase != "action":
		print("It's not the action phase!")
		return
	
	var player_id = multiplayer.get_unique_id()
	
	# Prevent performing action more than once per turn
	if Global.players_acted.get(player_id, false):
		print("You already performed an action this turn!")
		return
		
	Global.players_acted[player_id] = true  # Mark as acted
	player_ui.turn_info_labels.action.text = "Turn skipped."
	
	player_ui.turn_manager.advance_to_next_player()
