extends Manager
class_name ButtonManager


func _on_roll_button_pressed() -> void:
	player_ui.roll_manager.rpc_id(multiplayer.get_unique_id(), "roll_button_pressed", multiplayer.get_unique_id())

func _on_attack_player_button_pressed() -> void:
	handle_button_pressed("attack_player_button_pressed")

func _on_attack_mobs_button_pressed() -> void:
	handle_button_pressed("attack_mobs_button_pressed")

func _on_attack_boss_button_pressed() -> void:
	handle_button_pressed("attack_boss_button_pressed")

func _on_shop_button_pressed() -> void:
	handle_button_pressed("shop_button_pressed")

func _on_skip_button_pressed() -> void:
	handle_button_pressed("skip_button_pressed")

func handle_button_pressed(action: String) -> void:
	var player_id = multiplayer.get_unique_id()

	if Global.current_phase == "intention":
		player_ui.intention_manager.rpc(action, player_id)
	elif Global.current_phase == "action" and not Global.players_acted.get(player_id, false):
		#player_ui.intention_manager.rpc(action, player_id)
		player_ui.action_manager.rpc(action, player_id)
	else:
		if Global.players_acted.get(player_id, false):
			print("You already performed an action this turn!")
