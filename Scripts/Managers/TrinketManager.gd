extends Manager
class_name TrinketManager


var trinkets: Array[Trinket] = []


func _ready() -> void:
	SignalBus.connect("_on_combat_roll", _on_combat_roll)
	SignalBus.connect("_on_gold_roll", _on_gold_roll)
	SignalBus.connect("_on_cunning_roll", _on_cunning_roll)
	SignalBus.connect("_on_mob_defeated", _on_mob_defeated)
	SignalBus.connect("_on_boss_defeated", _on_boss_defeated)
	SignalBus.connect("_on_player_attacked", _on_player_attacked)
	SignalBus.connect("_on_player_defeated", _on_player_defeated)
	SignalBus.connect("_on_player_sabotaged", _on_player_sabotaged)
	SignalBus.connect("_on_boss_attack", _on_boss_attack)
	SignalBus.connect("_on_mob_attack", _on_mob_attack)
	
func add_trinket(player_id: int, trinket: Trinket) -> void:
	trinkets.append(trinket)
	
	if trinket.has_method("on_added"):
		trinket.on_added(player_id, self)  # Allow trinkets to register for events
	
	Global.player_info[player_id]["trinkets"].append({"name": trinket.name, "description": trinket.description})
	player_ui.sync_manager.rpc("sync_player_info", player_id, Global.player_info[player_id])

func remove_trinket(player_id: int, trinket: Trinket) -> void:
	trinkets.erase(trinket)
	
	if trinket.has_method("on_removed"):
		trinket.on_removed(self)
		
	for player_trinket in Global.player_info[player_id]["trinkets"]:
		if player_trinket.name == trinket.name:
			Global.player_info[player_id]["trinkets"].erase(player_trinket)
			break
			
	player_ui.sync_manager.rpc("sync_player_info", player_id, Global.player_info[player_id])
		
func _on_combat_roll(player_id: int, combat_amount: int) -> void:
	if multiplayer.get_unique_id() != player_id:
		return
		
	Global.player_info[player_id].combat += combat_amount
		
	for trinket in trinkets:
		if trinket.has_method("_on_combat_roll"):
			trinket._on_combat_roll(player_id)
	
func _on_gold_roll(player_id: int, gold_amount: int) -> void:
	if multiplayer.get_unique_id() != player_id:
		return
		
	Global.player_info[player_id].gold += gold_amount
		
	for trinket in trinkets:
		if trinket.has_method("_on_gold_roll"):
			trinket._on_gold_roll(player_id)

func _on_cunning_roll(player_id: int, cunning_amount: int) -> void:
	if multiplayer.get_unique_id() != player_id:
		return
		
	Global.player_info[player_id].cunning += cunning_amount
		
	for trinket in trinkets:
		if trinket.has_method("_on_cunning_roll"):
			trinket._on_cunning_roll(player_id)
	
func _on_player_defeated(attacker_id: int, defeated_id: int, combat_amount: int) -> void:
	player_ui.rpc("show_defeat_ui", defeated_id)
	Global.players.erase(defeated_id)
	Global.player_order.erase(defeated_id)
	player_ui.sync_manager.rpc("sync_players", Global.players)
	player_ui.sync_manager.rpc("sync_player_order", Global.player_order)
	
	if len(Global.players) == 1:
		player_ui.rpc_id(Global.players[0], "show_victory_ui")
		
	if multiplayer.get_unique_id() != attacker_id:
		return
	
	for trinket in trinkets:
		if trinket.has_method("_on_player_defeated"):
			trinket._on_player_defeated(attacker_id, combat_amount)

func _on_mob_defeated(player_id: int, combat_amount: int) -> void:
	Global.mob_kills += 1
	
	if multiplayer.get_unique_id() != player_id:
		return
	
	for trinket in trinkets:
		if trinket.has_method("_on_mob_defeated"):
			trinket._on_mob_defeated(player_id, combat_amount)
	
	add_trinket(player_id, Global.mob.drops.pick_random())

func _on_boss_defeated(player_id: int, combat_amount: int, killing_blow: bool) -> void:
	Global.boss_kills += 1
	rpc_id(player_id, "_on_boss_defeated_rpc", player_id, combat_amount, killing_blow)
	
@rpc("any_peer", "call_local", "reliable")
func _on_boss_defeated_rpc(player_id: int, combat_amount: int, killing_blow: bool) -> void:
	for trinket in trinkets:
		if trinket.has_method("_on_boss_defeated"):
			combat_amount = trinket._on_boss_defeated(player_id, combat_amount, killing_blow)
	
func _on_player_sabotaged(attacker_id: int, sabotaged_id: int, combat_amount: int) -> void:
	if multiplayer.get_unique_id() != attacker_id:
		return
	
	for trinket in trinkets:
		if trinket.has_method("_on_player_sabotaged"):
			trinket._on_player_sabotaged(attacker_id, sabotaged_id, combat_amount)
			
	Global.player_info[sabotaged_id].combat = max(Global.player_info[sabotaged_id].combat - combat_amount, 0)
	player_ui.sync_manager.rpc("sync_player_info", sabotaged_id, Global.player_info[sabotaged_id])

func _on_player_attacked(attacker_id: int, defender_id: int, combat_amount: int):
	if multiplayer.get_unique_id() != attacker_id:
		return
	
	for trinket in trinkets:
		if trinket.has_method("_on_player_attacked"):
			trinket._on_player_attacked(attacker_id, combat_amount)
			
	Global.player_info[defender_id].hp = max(Global.player_info[defender_id].hp - combat_amount, 0)
	player_ui.sync_manager.rpc("sync_player_info", defender_id, Global.player_info[defender_id])

func _on_boss_attack(player_id: int) -> void:
	if multiplayer.get_unique_id() != player_id:
		return
	
	for trinket in trinkets:
		if trinket.has_method("_on_boss_attack"):
			trinket._on_boss_attack(player_id)
	
	Global.player_info[player_id].hp = max(Global.player_info[player_id].hp - Global.boss.damage, 0)
	player_ui.sync_manager.rpc("sync_player_info", player_id, Global.player_info[player_id])
	
func _on_mob_attack(player_id: int) -> void:
	if multiplayer.get_unique_id() != player_id:
		return
	
	for trinket in trinkets:
		if trinket.has_method("_on_mob_attack"):
			trinket._on_mob_attack(player_id)
	
	Global.player_info[player_id].hp = max(Global.player_info[player_id].hp - Global.mob.damage, 0)
	player_ui.sync_manager.rpc("sync_player_info", player_id, Global.player_info[player_id])
