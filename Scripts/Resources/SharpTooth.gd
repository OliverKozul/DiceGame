extends Trinket


func _on_combat_roll(player_id: int) -> void:
	Global.player_info[player_id].combat += 1
