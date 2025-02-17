extends Trinket


func _on_player_sabotaged(_attacker_id: int, sabotaged_id: int, _combat_amount: int) -> void:
	Global.player_info[sabotaged_id].combat = max(Global.player_info[sabotaged_id].combat - 1, 0)
