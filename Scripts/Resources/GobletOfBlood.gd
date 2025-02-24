extends Trinket


func _on_any_attacked(player_id: int, combat_dealt: int) -> void:
	Global.player_info[player_id].hp += int(combat_dealt / 5) + 1
