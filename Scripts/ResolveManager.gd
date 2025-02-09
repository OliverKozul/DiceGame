extends Node


var player_ui : CanvasLayer


func initialize(ui : CanvasLayer) -> void:
	player_ui = ui
	
@rpc("any_peer", "call_local")
func resolve_button_pressed(player_id : int) -> void:
	Global.players_resolved[player_id] = true  # Mark as resolved
	if player_id != multiplayer.get_unique_id():
		return
	
	player_ui.turn_manager.advance_to_next_player()
