extends Manager
class_name CombatManager


func handle_combat(player_id: int, targets: Array) -> void:
	player_ui.current_player_label.text = "You attacked the enemy!"
	
	for target in targets:
		Global.player_info[player_id].combat -= target[1]
		player_ui.sync_manager.rpc("sync_player_info", player_id, Global.player_info[player_id])
		
		if str(target[0]) == "Mob":
			handle_mob_combat(player_id, target)
		elif str(target[0]) == "Boss":
			handle_boss_combat(player_id, target)
		else:
			handle_player_combat(player_id, target)

func handle_mob_combat(player_id: int, target: Array) -> void:
	SignalBus._on_mob_attacked.emit(player_id, target[1])
	
	if target[1] >= Global.mob.hp:
		SignalBus._on_mob_defeated.emit(player_id, target[1])
	else:
		SignalBus._on_mob_attack.emit(player_id)
		
		if Global.player_info[player_id].hp <= 0:
			SignalBus._on_player_defeated.emit(-1, player_id, Global.mob.damage)
			print(Global.player_names[player_id], " defeated!")
	
func handle_boss_combat(player_id: int, target: Array) -> void:
	if Global.boss.current_hp <= 0:
		print("Boss already dead!")
		return
		
	SignalBus._on_boss_attacked.emit(player_id, target[1])
	Global.boss.current_hp -= target[1]
	Global.boss_attackers[player_id] = target[1]
	
	player_ui.sync_manager.rpc("sync_boss_current_hp", Global.boss.current_hp)
	player_ui.sync_manager.rpc("sync_boss_attackers", Global.boss_attackers)
	
	if Global.boss.current_hp <= 0:
		for attacker in Global.boss_attackers.keys():
			if attacker == player_id:
				SignalBus._on_boss_defeated.emit(attacker, target[1], true)
			else:
				SignalBus._on_boss_defeated.emit(attacker, Global.boss_attackers[attacker], false)
				
		for i in int((len(Global.boss_attackers.keys()) + 1) / 2):
			Global.boss_drops.append(Global.boss.drops.pick_random())
				
	player_ui.sync_manager.rpc("sync_boss_drops", Global.boss_drops)

func handle_player_combat(player_id: int,target: Array) -> void:
	target[0] = int(target[0])
		
	if target[2] == "sabotage":
		SignalBus._on_player_sabotaged.emit(player_id, target[0], target[1])
	elif target[2] == "damage":
		SignalBus._on_player_attacked.emit(player_id, target[0], target[1])
	
	if Global.player_info[target[0]].hp <= 0:
		SignalBus._on_player_defeated.emit(player_id, target[0], target[1])
		print(Global.player_names[target[0]], " defeated!")

@rpc("any_peer", "call_local")
func deal_boss_damage() -> void:
	for attacker in Global.boss_attackers.keys():
		SignalBus._on_boss_attack.emit(attacker)
		
		if Global.player_info[attacker].hp <= 0:
			SignalBus._on_player_defeated.emit(-1, attacker, Global.boss.damage)
			print(Global.player_names[attacker], " defeated!")
