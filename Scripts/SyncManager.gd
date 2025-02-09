extends Node


var player_ui : CanvasLayer


func initialize(ui : CanvasLayer):
	player_ui = ui
	
	SignalBus.connect("sync_player_info", _on_sync_player_info)
	SignalBus.connect("sync_roll_result", _on_sync_roll_result)

func _on_roll_button_pressed():
	player_ui.roll_manager.rpc("roll_button_pressed", multiplayer.get_unique_id())
	
func _on_sync_player_info(player_id : int, player_info):
	rpc("sync_player_info", player_id, player_info)
	
### **Sync Roll Result for Everyone**
@rpc("any_peer", "call_local")
func sync_player_info(player_id : int, player_info):
	Global.player_info[player_id] = player_info
	if multiplayer.get_unique_id() == player_id:
		player_ui.update_all_status_labels.emit()
	
	
func _on_sync_roll_result(player_id : int, roll_result : String):
	rpc("sync_roll_result", player_id, roll_result)

### **Sync Roll Result for Everyone**
@rpc("any_peer", "call_local")
func sync_roll_result(player_id : int, roll_result : String):
	Global.players_rolled[player_id] = true
	print(Global.current_turn, ". turn, Player %s rolled: %s" % [player_id, roll_result])
