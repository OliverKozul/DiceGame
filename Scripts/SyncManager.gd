extends Node


var player_ui : CanvasLayer


func initialize(ui : CanvasLayer) -> void:
	player_ui = ui

### **Sync Roll Result for Everyone**
@rpc("any_peer", "call_local")
func sync_player_info(player_id : int, player_info : Dictionary) -> void:
	Global.player_info[player_id] = player_info
	if multiplayer.get_unique_id() == player_id:
		player_ui.update_all_status_labels.emit()

### **Sync Roll Result for Everyone**
@rpc("any_peer", "call_local")
func sync_roll_result(player_id : int, roll_result : String) -> void:
	Global.players_rolled[player_id] = true
	print(Global.current_turn, ". turn, Player %s rolled: %s" % [player_id, roll_result])

@rpc("any_peer", "call_local")
func sync_turn(new_turn : int) -> void:
	var player_id = multiplayer.get_unique_id()
	Global.player_info[player_id].combat = 0
	Global.players_rolled.clear()
	Global.players_acted.clear()
	Global.current_turn = new_turn
	#buttons.roll.visible = true
	player_ui.buttons.show_buttons("roll")
	player_ui.current_player_label.text = "Roll the dice!"
	player_ui.status_labels.combat.text = "⚔ count: " + str(Global.player_info[player_id].combat)
	rpc("sync_phase", "roll")
	rpc("sync_current_player_index", 0)
	
	player_ui.turn_info_labels.turn.text = "Current turn: " + str(Global.current_turn)

@rpc("any_peer", "call_local")
func sync_player_order(new_player_order : Array) -> void:
	Global.player_order = new_player_order
	
@rpc("any_peer", "call_local")
func sync_current_player_index(new_index : int) -> void:
	Global.current_player_index = new_index
	
@rpc("any_peer", "call_local")
func sync_phase(new_phase : String) -> void:
	Global.current_phase = new_phase
