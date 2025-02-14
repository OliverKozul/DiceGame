extends Manager


var trinkets: Array[Trinket] = []


func _ready() -> void:
	SignalBus.connect("_on_combat_roll", _on_combat_roll)
	SignalBus.connect("_on_gold_roll", _on_gold_roll)
	SignalBus.connect("_on_cunning_roll", _on_cunning_roll)
	SignalBus.connect("_on_player_defeated", _on_player_defeated)
	SignalBus.connect("_on_mob_defeated", _on_mob_defeated)
	SignalBus.connect("_on_boss_defeated", _on_boss_defeated)

func add_trinket(player_id: int, trinket: Trinket) -> void:
	trinkets.append(trinket)
	
	if trinket.has_method("on_added"):
		trinket.on_added(self)  # Allow trinkets to register for events
	
	Global.player_info[player_id]["trinkets"].append(trinket.name)
	player_ui.sync_manager.rpc("sync_player_info", player_id, Global.player_info[player_id])

func remove_trinket(player_id: int, trinket: Trinket) -> void:
	trinkets.erase(trinket)
	
	if trinket.has_method("on_removed"):
		trinket.on_removed(self)
		
	Global.player_info[player_id]["trinkets"].erase(trinket.name)
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
	
func _on_player_defeated(attacker_id: int, _defeated_id: int, combat_amount: int) -> void:
	if multiplayer.get_unique_id() != attacker_id:
		return
	
	for trinket in trinkets:
		if trinket.has_method("_on_player_defeated"):
			trinket._on_player_defeated(attacker_id, combat_amount)

func _on_mob_defeated(player_id: int, combat_amount: int) -> void:
	if multiplayer.get_unique_id() != player_id:
		return
	
	for trinket in trinkets:
		if trinket.has_method("_on_mob_defeated"):
			trinket._on_mob_defeated(player_id, combat_amount)
	
	add_trinket(player_id, Global.mob.drops.pick_random())

func _on_boss_defeated(player_id: int, combat_amount: int, killing_blow: bool) -> void:
	rpc_id(player_id, "_on_boss_defeated_rpc", player_id, combat_amount, killing_blow)
	
@rpc("any_peer", "call_local")
func _on_boss_defeated_rpc(player_id: int, combat_amount: int, killing_blow: bool) -> void:
	for trinket in trinkets:
		if trinket.has_method("_on_boss_defeated"):
			combat_amount = trinket._on_boss_defeated(player_id, combat_amount, killing_blow)
	
	add_trinket(player_id, Global.boss.drops.pick_random())
