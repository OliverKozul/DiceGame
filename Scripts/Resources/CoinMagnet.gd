extends Trinket


func _on_intention_phase(player_id: int) -> void:
	for id in Global.players:
		if id != player_id and Global.player_info[id].gold >= 1:
			Global.player_info[id].gold -= 1
			Global.player_info[player_id].gold += 1
