extends Manager
class_name SyncManager

### **Sync Roll Result for Everyone**
@rpc("any_peer", "call_local")
func sync_player_info(player_id: int, player_info: Dictionary) -> void:
	Global.player_info[player_id] = player_info
	
	if multiplayer.get_unique_id() == player_id:
		player_ui.update_all_status_labels.emit()

### **Sync Roll Result for Everyone**
@rpc("any_peer", "call_local")
func sync_roll_results(player_id: int, roll_results: Array, roll_text: String) -> void:
	Global.players_rolled[player_id] = true
	player_ui.turn_info_labels.roll_results[player_id].text = roll_text
	
	if multiplayer.get_unique_id() == player_id:
		print(Global.current_turn, ". turn, Player %s rolled: %s" % [Global.player_names[player_id], roll_results])

@rpc("any_peer", "call_local")
func sync_turn(new_turn: int) -> void:
	rpc("sync_current_player_index", 0)
	var player_id = multiplayer.get_unique_id()
	Global.player_info[player_id].combat = 0
	Global.players_rolled.clear()
	Global.players_acted.clear()
	Global.players_resolved.clear()
	Global.boss_attackers.clear()
	Global.current_turn = new_turn
	Global.mob.hp = 1 + int(new_turn / 3)
	Global.boss.max_hp = new_turn + len(Global.players)
	Global.boss.current_hp = Global.boss.max_hp
	
	player_ui.buttons.show_buttons("roll")
	player_ui.buttons.buttons["attack_mobs"].text = "Attack Mobs" + " (" + str(Global.mob.hp) + " HP)"
	player_ui.buttons.buttons["attack_boss"].text = "Attack Boss" + " (" + str(Global.boss.max_hp) + " HP)"
	
	for id in Global.player_order:
		player_ui.turn_info_labels.roll_results[id].text = Global.player_names[id] + " rolled: N/A"
	
	player_ui.current_player_label.text = "Roll the dice!"
	player_ui.status_labels.combat.text = "⚔ count: " + str(Global.player_info[player_id].combat)
	
	rpc("sync_phase", "roll")
	
	player_ui.turn_info_labels.turn.text = "Current turn: " + str(Global.current_turn)

@rpc("any_peer", "call_local")
func sync_players(new_players: Array) -> void:
	Global.players = new_players

@rpc("any_peer", "call_local")
func sync_player_order(new_player_order: Array) -> void:
	Global.player_order = new_player_order
	
@rpc("any_peer", "call_local")
func sync_current_player_index(new_index: int) -> void:
	Global.current_player_index = new_index
	#print("INSYNC")
	#print(Global.player_names[multiplayer.get_unique_id()])
	#print(Global.current_player_index)
	
@rpc("any_peer", "call_local")
func sync_phase(new_phase: String) -> void:
	Global.current_phase = new_phase
	
@rpc("any_peer", "call_local")
func sync_boss_current_hp(new_current_hp: int) -> void:
	Global.boss.current_hp = new_current_hp
	
@rpc("any_peer", "call_local")
func sync_boss_attackers(new_boss_attackers: Array) -> void:
	Global.boss_attackers = new_boss_attackers
