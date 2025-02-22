extends Manager
class_name IntentionManager

### **Update Intention**
@rpc("any_peer", "call_local", "reliable")
func update_intention(player_id: int, intention: String) -> void:
	player_ui.player_intention_labels.rpc("update_intention", player_id, intention)

### **Attack Player**
@rpc("any_peer", "call_local", "reliable")
func attack_player_button_pressed(player_id: int) -> void:
	update_intention(player_id, "⚔ Player")

### **Attack Mobs**
@rpc("any_peer", "call_local", "reliable")
func attack_mobs_button_pressed(player_id: int) -> void:
	update_intention(player_id, "⚔ Mob")

### **Attack Boss**
@rpc("any_peer", "call_local", "reliable")
func attack_boss_button_pressed(player_id: int) -> void:
	update_intention(player_id, "⚔ Boss")

### **Shop**
@rpc("any_peer", "call_local", "reliable")
func shop_button_pressed(player_id: int) -> void:
	update_intention(player_id, "💰")

### **Skip**
@rpc("any_peer", "call_local", "reliable")
func skip_button_pressed(player_id: int) -> void:
	update_intention(player_id, "⏭️")
