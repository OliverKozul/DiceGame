extends Trinket


func _on_cunning_roll(player_id: int) -> void:
	Global.player_info[player_id].cunning += 3
	Global.player_info[player_id].gold += 3
