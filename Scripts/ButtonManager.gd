extends Node


var player_ui : CanvasLayer


func initialize(ui : CanvasLayer) -> void:
	player_ui = ui

func _on_roll_button_pressed() -> void:
	player_ui.roll_manager.rpc("roll_button_pressed", multiplayer.get_unique_id())
	
func _on_attack_player_button_pressed() -> void:
	var player_id = multiplayer.get_unique_id()
	
	if Global.current_phase == "intention":
		player_ui.intention_manager.rpc("attack_player_button_pressed", player_id)
		return
	if Global.current_phase == "action" and not Global.players_acted.get(player_id, false):
		player_ui.action_manager.rpc("attack_player_button_pressed", player_id)
		return
	
	# Prevent performing action more than once per turn
	if Global.players_acted.get(player_id, false):
		print("You already performed an action this turn!")
		return

func _on_attack_mobs_button_pressed() -> void:
	var player_id = multiplayer.get_unique_id()
	
	if Global.current_phase == "intention":
		player_ui.intention_manager.rpc("attack_mobs_button_pressed", player_id)
		return
	if Global.current_phase == "action" and not Global.players_acted.get(player_id, false):
		player_ui.action_manager.rpc("attack_mobs_button_pressed", player_id)
		return
	
	# Prevent performing action more than once per turn
	if Global.players_acted.get(player_id, false):
		print("You already performed an action this turn!")
		return
	
func _on_attack_boss_button_pressed() -> void:
	var player_id = multiplayer.get_unique_id()
	
	if Global.current_phase == "intention":
		player_ui.intention_manager.rpc("attack_boss_button_pressed", player_id)
		return
	if Global.current_phase == "action" and not Global.players_acted.get(player_id, false):
		player_ui.action_manager.rpc("attack_boss_button_pressed", player_id)
		return
	
	# Prevent performing action more than once per turn
	if Global.players_acted.get(player_id, false):
		print("You already performed an action this turn!")
		return

func _on_shop_button_pressed() -> void:
	var player_id = multiplayer.get_unique_id()
	
	if Global.current_phase == "intention":
		player_ui.intention_manager.rpc("shop_button_pressed", player_id)
		return
	if Global.current_phase == "action" and not Global.players_acted.get(player_id, false):
		player_ui.action_manager.rpc("shop_button_pressed", player_id)
		return
	
	# Prevent performing action more than once per turn
	if Global.players_acted.get(player_id, false):
		print("You already performed an action this turn!")
		return

func _on_skip_button_pressed() -> void:
	var player_id = multiplayer.get_unique_id()
	
	if Global.current_phase == "intention":
		player_ui.intention_manager.rpc("skip_button_pressed", player_id)
		return
	if Global.current_phase == "action" and not Global.players_acted.get(player_id, false):
		player_ui.action_manager.rpc("skip_button_pressed", player_id)
		return
	
	# Prevent performing action more than once per turn
	if Global.players_acted.get(player_id, false):
		print("You already performed an action this turn!")
		return

func _on_resolve_button_pressed() -> void:
	var player_id = multiplayer.get_unique_id()
	
	player_ui.resolve_manager.rpc("resolve_button_pressed", player_id)
