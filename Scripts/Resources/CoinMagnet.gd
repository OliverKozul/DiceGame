extends Trinket


func _on_player_sabotaged(attacker_id: int, sabotaged_id:int, _combat_amount: int) -> void:
	if Global.player_info[sabotaged_id].gold >= 1:
		Global.player_info[sabotaged_id].gold -= 1
		Global.player_info[attacker_id].gold += 1
