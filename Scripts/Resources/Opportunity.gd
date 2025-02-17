extends Trinket


func on_added(player_id: int, _trinket_manager: Manager) -> void:
	Global.player_info[player_id].die_faces.append(["⚔", "⚔", "💰", "💰", "🧠", "🧠"])
	Global.player_info[player_id].die_face_values.append({"⚔": 1, "💰": 1, "🧠": 1})
	
