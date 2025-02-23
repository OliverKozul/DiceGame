extends Manager
class_name SyncManager


@rpc("any_peer", "call_local", "reliable")
func sync_player_info(player_id: int, player_info: Dictionary) -> void:
	Global.player_info[player_id] = player_info
	
	if multiplayer.get_unique_id() == player_id:
		player_ui.update_all_status_labels.emit()


@rpc("any_peer", "call_local", "reliable")
func sync_roll_results(player_id: int, roll_results: Array, roll_text: String) -> void:
	Global.players_rolled[player_id] = true
	player_ui.turn_info_labels.roll_results[player_id].text = roll_text
	
	if multiplayer.get_unique_id() == Global.host_id:
		for id in Global.players:
			if not Global.players_rolled.get(id, false):
				return
				
		player_ui.turn_manager.rpc_id(Global.host_id, "transition_to_intention_phase")

@rpc("any_peer", "call_local", "reliable")
func sync_turn(new_turn: int) -> void:
	rpc("sync_current_player_index", 0)
	var player_id = multiplayer.get_unique_id()
	Global.current_turn = new_turn
	
	Global.player_info[player_id].combat = 0
	Global.players_rolled.clear()
	Global.players_acted.clear()
	Global.players_resolved.clear()
	
	Global.bid_item_indices.clear()
	Global.selected_item_indices.clear()
	Global.player_bids.clear()
	Global.current_bid_item = 0
	
	Global.boss_attackers.clear()
	Global.mob.hp = 1 + Global.mob_kills + int(new_turn / 10)
	#Global.mob.hp = 1 + int(new_turn / 3)
	#Global.boss.max_hp = len(Global.players) + int(new_turn / 2)
	Global.boss.max_hp = len(Global.players) + Global.boss_kills + int(new_turn / 5)
	Global.boss_drops = []
	Global.boss.current_hp = Global.boss.max_hp
	
	player_ui.buttons.show_buttons("roll")
	player_ui.buttons.buttons["attack_mobs"].text = "Attack Mobs" + " (" + str(Global.mob.hp) + " HP)"
	player_ui.buttons.buttons["attack_boss"].text = "Attack Boss" + " (" + str(Global.boss.max_hp) + " HP)"
	player_ui.loot_distribution.reset()
	
	for id in Global.player_order:
		player_ui.turn_info_labels.roll_results[id].text = Global.player_names[id] + " rolled: N/A"
	
	player_ui.current_player_label.text = "Roll the dice!"
	player_ui.status_labels.combat.text = "⚔ count: " + str(Global.player_info[player_id].combat)
	player_ui.turn_info_labels.turn.text = "Current turn: " + str(Global.current_turn)
	
	rpc("sync_phase", "roll")

@rpc("any_peer", "call_local", "reliable")
func sync_players(new_players: Array, defeated_id: int = -1) -> void:
	Global.players = new_players
	
	if defeated_id != -1:
		player_ui.player_intention_labels._on_player_defeated(defeated_id)

@rpc("any_peer", "call_local", "reliable")
func sync_player_order(new_player_order: Array) -> void:
	Global.player_order = new_player_order
	
@rpc("any_peer", "call_local", "reliable")
func sync_current_player_index(new_index: int) -> void:
	Global.current_player_index = new_index
	
@rpc("any_peer", "call_local", "reliable")
func sync_phase(new_phase: String) -> void:
	Global.current_phase = new_phase
	
@rpc("any_peer", "call_local", "reliable")
func sync_boss_current_hp(new_current_hp: int) -> void:
	Global.boss.current_hp = new_current_hp
	
@rpc("any_peer", "call_local", "reliable")
func sync_boss_attackers(new_boss_attackers: Dictionary) -> void:
	Global.boss_attackers = new_boss_attackers
	
@rpc("any_peer", "call_local", "reliable")
func sync_boss_kills(new_boss_kills: int) -> void:
	Global.boss_kills = new_boss_kills
	
@rpc("any_peer", "call_local", "reliable")
func sync_boss_drops(new_boss_drops: Array) -> void:
	var new_array = []
	
	for drop in new_boss_drops:
		if drop is not Resource:
			new_array.append(instance_from_id(drop.object_id).duplicate())
		else:
			new_array.append(drop)
			
	Global.boss_drops = new_array
	
@rpc("any_peer", "call_local", "reliable")
func sync_mob_kills(new_mob_kills: int) -> void:
	Global.mob_kills = new_mob_kills

@rpc("any_peer", "call_local", "reliable")
func sync_selected_item_indices(new_selected_item_indices: Dictionary) -> void:
	Global.selected_item_indices = new_selected_item_indices
	
@rpc("any_peer", "call_local", "reliable")
func sync_bid_item_indices(new_bid_item_indices: Array) -> void:
	Global.bid_item_indices = new_bid_item_indices

@rpc("any_peer", "call_local", "reliable")
func sync_current_bid_item(new_current_bid_item: int) -> void:
	Global.current_bid_item = new_current_bid_item
	
@rpc("any_peer", "call_local", "reliable")
func sync_player_bids(new_player_bids: Dictionary) -> void:
	Global.player_bids = new_player_bids
	
@rpc("any_peer", "call_local", "reliable")
func add_trinket_and_sync(new_trinket_index: int) -> void:
	player_ui.turn_info_labels.action.text = "Won trinket: " + Global.boss_drops[new_trinket_index].name
	player_ui.trinket_manager.add_trinket(multiplayer.get_unique_id(), Global.boss_drops[new_trinket_index])
