extends Manager
class_name ActionManager


@rpc("any_peer", "call_local")
func attack_player_button_pressed(player_id: int) -> void:
	perform_action(player_id, Enums.Action.ATTACK, Enums.Target.PLAYER, Global.player_info[player_id].combat, "You attacked another player.")

@rpc("any_peer", "call_local")
func attack_mobs_button_pressed(player_id: int) -> void:
	perform_action(player_id, Enums.Action.ATTACK, Enums.Target.MOB, Global.player_info[player_id].combat, "You attacked a mob.")

@rpc("any_peer", "call_local")
func attack_boss_button_pressed(player_id: int) -> void:
	perform_action(player_id, Enums.Action.ATTACK, Enums.Target.BOSS, Global.player_info[player_id].combat, "You attacked the boss.")

@rpc("any_peer", "call_local")
func shop_button_pressed(player_id: int) -> void:
	perform_action(player_id, Enums.Action.SHOP, Enums.Target.NONE, 0, "")

@rpc("any_peer", "call_local")
func skip_button_pressed(player_id: int) -> void:
	perform_action(player_id, Enums.Action.SKIP, Enums.Target.NONE, 0, "Turn skipped.")

func perform_action(player_id: int, action: Enums.Action, target: Enums.Target, amount: int, message: String) -> void:
	Global.players_acted[player_id] = {
		"action": action,
		"target": target,
		"amount": amount
	}
	
	if player_id != multiplayer.get_unique_id():
		return
	
	if message != "":
		player_ui.turn_info_labels.action.text = message
	
	player_ui.turn_manager.advance_to_next_player()
