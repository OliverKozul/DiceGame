extends Node


var player_ui : CanvasLayer


func initialize(ui : CanvasLayer):
	player_ui = ui

### **Attack Player**
@rpc("any_peer", "call_local")
func attack_player_button_pressed(player_id : int) -> void:
	player_ui.player_intention_labels.rpc("update_intention", player_id, "⚔ Player")

### **Attack Mobs**
@rpc("any_peer", "call_local")
func attack_mobs_button_pressed(player_id : int) -> void:
	player_ui.player_intention_labels.rpc("update_intention", player_id, "⚔ Mob")

### **Attack Boss**
@rpc("any_peer", "call_local")
func attack_boss_button_pressed(player_id : int) -> void:
	player_ui.player_intention_labels.rpc("update_intention", player_id, "⚔ Boss")

### **Shop**
@rpc("any_peer", "call_local")
func shop_button_pressed(player_id : int) -> void:
	player_ui.player_intention_labels.rpc("update_intention", player_id, "💰")

### **Skip**
@rpc("any_peer", "call_local")
func skip_button_pressed(player_id : int) -> void:
	player_ui.player_intention_labels.rpc("update_intention", player_id, "⏭️")
