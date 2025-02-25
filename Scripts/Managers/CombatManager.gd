extends Manager
class_name CombatManager


func handle_combat(player_id: int, targets: Array) -> void:
	player_ui.current_player_label.text = "You attacked the enemy!"
	
	for target in targets:
		Global.player_info[player_id].combat -= target["combat_taken"]
		player_ui.sync_manager.rpc("sync_player_info", player_id, Global.player_info[player_id])
		
		if target["target"] == Global.enemy_ids[Global.enemy_ids.keys()[0]]:
			handle_boss_combat(player_id, target)
		elif target["target"] <= 0:
			handle_mob_combat(player_id, target)
		else:
			handle_player_combat(player_id, target)

func handle_mob_combat(player_id: int, target: Dictionary) -> void:
	SignalBus._on_mob_attacked.emit(player_id, target["combat_taken"], target["target"])
	SignalBus._on_any_attacked.emit(player_id, target["combat_taken"])
	
	if target["combat_taken"] >= Global.mobs[-target["target"]].hp:
		SignalBus._on_mob_defeated.emit(player_id, target["combat_taken"], target["target"])
		player_ui.sync_manager.rpc("sync_mob_kills", Global.mob_kills + 1)
	else:
		SignalBus._on_mob_attack.emit(player_id, target["target"])
		
		if Global.player_info[player_id].hp <= 0:
			SignalBus._on_player_defeated.emit(target["target"], player_id, Global.mobs[-target["target"]].damage)
			print(Global.player_names[player_id], " defeated!")
	
func handle_boss_combat(player_id: int, target: Dictionary) -> void:
	if Global.boss.current_hp <= 0:
		print("Boss already dead!")
		return
		
	SignalBus._on_boss_attacked.emit(player_id, target["combat_taken"])
	SignalBus._on_any_attacked.emit(player_id, target["combat_taken"])
	Global.boss.current_hp -= target["combat_taken"]
	Global.boss_attackers[player_id] = target["combat_taken"]
	
	player_ui.sync_manager.rpc("sync_boss_current_hp", Global.boss.current_hp)
	player_ui.sync_manager.rpc("sync_boss_attackers", Global.boss_attackers)
	
	if Global.boss.current_hp <= 0:
		player_ui.sync_manager.rpc("sync_boss_kills", Global.boss_kills + 1)
		
		for attacker in Global.boss_attackers.keys():
			if attacker == player_id:
				SignalBus._on_boss_defeated.emit(attacker, target["combat_taken"], true)
			else:
				SignalBus._on_boss_defeated.emit(attacker, Global.boss_attackers[attacker], false)
				
		for i in int((len(Global.boss_attackers.keys()) + 1) / 2):
			var index = randi_range(0, len(Global.boss.drops) - 1)
			Global.boss_drop_indices.append(index)
				
	player_ui.sync_manager.rpc("sync_boss_drops", Global.boss_drop_indices)

func handle_player_combat(player_id: int, target: Dictionary) -> void:
	if target["type"] == "sabotage":
		SignalBus._on_player_sabotaged.emit(player_id, target["target"], target["combat_taken"])
	elif target["type"] == "damage":
		SignalBus._on_player_attacked.emit(player_id, target["target"], target["combat_taken"])
		SignalBus._on_any_attacked.emit(player_id, target["combat_taken"])
	
	if Global.player_info[target["target"]].hp <= 0:
		SignalBus._on_player_defeated.emit(player_id, target["target"], target["combat_taken"])
		print(Global.player_names[target["target"]], " defeated!")

@rpc("any_peer", "call_local", "reliable")
func deal_boss_damage() -> void:
	for attacker in Global.boss_attackers.keys():
		SignalBus._on_boss_attack.emit(attacker)
		
		if Global.player_info[attacker].hp <= 0:
			SignalBus._on_player_defeated.emit(Global.enemy_ids[Global.enemy_ids.keys()[0]], attacker, Global.boss.damage)
			print(Global.player_names[attacker], " defeated!")
