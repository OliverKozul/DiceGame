extends Manager
class_name TurnManager


const PHASES = {
	"intention": "intention",
	"action": "action",
	"resolve": "resolve",
	"loot_distribution": "loot_distribution",
	"bid": "bid"
}

# Initiate Next Turn
@rpc("any_peer", "call_local", "reliable")
func initiate_next_turn() -> void:
	if Global.boss.current_hp > 0:
		player_ui.combat_manager.rpc("deal_boss_damage")
		
	Global.current_turn += 1
	player_ui.sync_manager.rpc("sync_turn", Global.current_turn)
	player_ui.sync_manager.rpc("sync_player_order", Global.player_order)
	player_ui.player_intention_labels.rpc("update_players")
	print("Turn ", Global.current_turn)

# Transition to Intention Phase
@rpc("any_peer", "call_local", "reliable")
func transition_to_intention_phase() -> void:
	player_ui.sync_manager.rpc("sync_phase", PHASES.intention)
	player_ui.sync_manager.rpc("sync_current_player_index", 0)
	determine_player_order(Global.players)
	player_ui.sync_manager.rpc("sync_player_order", Global.player_order)
	player_ui.player_intention_labels.rpc("update_players")
	SignalBus._on_intention_phase.emit()
	rpc("show_phase_ui", "intention", "Declare your intention!")
	rpc("create_and_animate_rect")

# Transition to Action Phase
@rpc("any_peer", "call_local", "reliable")
func transition_to_action_phase() -> void:
	player_ui.sync_manager.rpc("sync_phase", PHASES.action)
	player_ui.sync_manager.rpc("sync_current_player_index", 0)
	
	rpc_id(Global.host_id, "allow_current_player_play")

# Transition to Resolve Phase
@rpc("any_peer", "call_local", "reliable")
func transition_to_resolve_phase() -> void:
	player_ui.sync_manager.rpc("sync_phase", PHASES.resolve)
	player_ui.sync_manager.rpc("sync_current_player_index", 0)
	
	Global.player_order.reverse()
	player_ui.sync_manager.rpc("sync_player_order", Global.player_order)
	rpc_id(Global.host_id, "allow_current_player_play")
	
@rpc("any_peer", "call_local", "reliable")
func transition_to_loot_distribution_phase() -> void:
	player_ui.sync_manager.rpc("sync_phase", PHASES.loot_distribution)
	determine_player_order(Global.boss_attackers.keys())
	player_ui.sync_manager.rpc("sync_player_order", Global.player_order)
	player_ui.sync_manager.rpc("sync_current_player_index", 0)
	
	rpc_id(Global.host_id, "allow_current_player_play")
	
@rpc("any_peer", "call_local", "reliable")
func transition_to_bidding_phase() -> void:
	player_ui.sync_manager.rpc("sync_phase", PHASES.bid)
	player_ui.sync_manager.rpc("sync_current_bid_item", 0)
	player_ui.sync_manager.rpc("sync_current_player_index", 0)
	determine_player_order(Global.selected_item_indices[Global.bid_item_indices[Global.current_bid_item]])
	player_ui.sync_manager.rpc("sync_player_order", Global.player_order)
	
	rpc_id(Global.host_id, "allow_current_player_play")

# Check if All Players Have Performed an Action
func check_all_players_played() -> bool:
	return Global.current_player_index >= Global.player_order.size()

# Determine Action Order
func determine_player_order(players: Array) -> void:
	Global.player_order = players
	Global.player_order.sort_custom(_compare_players)
	
# Compare Players for Sorting
func _compare_players(player_b_id: int, player_a_id: int) -> bool:
	var cunning_a = Global.player_info[player_a_id].cunning
	var cunning_b = Global.player_info[player_b_id].cunning
	
	if cunning_a != cunning_b:
		return cunning_a > cunning_b
	
	var gold_a = Global.player_info[player_a_id].gold
	var gold_b = Global.player_info[player_b_id].gold
	
	if gold_a != gold_b:
		return gold_a > gold_b
	
	return player_a_id > player_b_id

# Advance to Next Player
@rpc("any_peer", "call_local", "reliable")
func advance_to_next_player() -> void:
	# Increment current player index first.
	Global.current_player_index += 1
	player_ui.sync_manager.rpc("sync_current_player_index", Global.current_player_index)
	
	if check_all_players_played():
		match Global.current_phase:
			PHASES.action:
				print("All players have acted. Transitioning to resolve phase.")
				rpc_id(Global.host_id, "transition_to_resolve_phase")
			PHASES.resolve:
				if Global.boss.current_hp <= 0:
					print("The boss has been killed. Transitioning to loot distribution phase.")
					rpc_id(Global.host_id, "transition_to_loot_distribution_phase")
				else:
					print("All players have been resolved. Transitioning to next turn.")
					rpc_id(Global.host_id, "initiate_next_turn")
			PHASES.loot_distribution:
				var bid = false
				
				for index in Global.selected_item_indices:
					if len(Global.selected_item_indices[index]) > 1:
						bid = true
						Global.bid_item_indices.append(index)
					else:
						player_ui.sync_manager.rpc_id(Global.selected_item_indices[index][0], "add_trinket_and_sync", index)
						
				if bid:
					player_ui.sync_manager.rpc("sync_bid_item_indices", Global.bid_item_indices)
					print("Conflicting item choices. Transitioning to bidding phase.")
					rpc_id(Global.host_id, "transition_to_bidding_phase")
				else:
					print("All players have chosen a unique item. Transitioning to next turn.")
					rpc_id(Global.host_id, "initiate_next_turn")
			PHASES.bid:
				give_auction_winner_trinket()
				player_ui.sync_manager.rpc("sync_current_bid_item", Global.current_bid_item + 1)
				player_ui.sync_manager.rpc("sync_player_bids", {})
				
				if Global.current_bid_item >= len(Global.bid_item_indices):
					print("All players have finished bidding. Transitioning to next turn.")
					rpc_id(Global.host_id, "initiate_next_turn")
				else:
					player_ui.sync_manager.rpc("sync_current_player_index", 0)
					determine_player_order(Global.selected_item_indices[Global.bid_item_indices[Global.current_bid_item]])
					player_ui.sync_manager.rpc("sync_player_order", Global.player_order)
					rpc_id(Global.host_id, "allow_current_player_play")
	else:
		rpc_id(Global.host_id, "allow_current_player_play")
		
# Allow Current Player Action
@rpc("any_peer", "call_local", "reliable")
func allow_current_player_play() -> void:
	var current_player = Global.player_order[Global.current_player_index]
	
	for player_id in Global.players:
		if player_id == current_player:
			match Global.current_phase:
				PHASES.action:
					rpc_id(player_id, "show_phase_ui", "action", "It's your turn!")
				PHASES.resolve:
					rpc_id(player_id, "show_phase_ui", "resolve", "It's your turn!")
					player_ui.resolve_manager.rpc("resolve_current_player_turn", player_id)
				PHASES.loot_distribution:
					if player_id in Global.boss_attackers.keys():
						rpc_id(player_id, "show_phase_ui", "loot_distribution", "It's your turn!")
						player_ui.loot_distribution.rpc_id(player_id, "allow_item_choice")
				PHASES.bid:
					if player_id in Global.selected_item_indices[Global.bid_item_indices[Global.current_bid_item]]:
						rpc_id(player_id, "show_phase_ui", "bid", "It's your turn!")
						player_ui.bid_distribution.rpc_id(player_id, "allow_bid")
		else:
			rpc_id(player_id, "show_phase_ui", "wait", "Waiting for player %s" % Global.player_names[current_player])

@rpc("any_peer", "call_local", "reliable")
func show_phase_ui(buttons: String, label_text: String) -> void:
	player_ui.buttons.show_buttons(buttons)
	player_ui.current_player_label.text = label_text

@rpc("any_peer", "call_local", "reliable")
func create_and_animate_rect() -> void:
	var rect = Utils.create_rect()
	player_ui.add_child(rect)
	var tween = get_tree().create_tween()
	tween.tween_property(rect, "scale", Vector2(0, 0), 1.0)  # 5-second shrink
	tween.finished.connect(_on_tween_completed.bind(rect))

func _on_tween_completed(rect: TextureRect) -> void:
	rect.queue_free()
	
	if multiplayer.is_server():
		rpc_id(Global.host_id, "transition_to_action_phase")
		
func give_auction_winner_trinket() -> void:
	var max_bid_id = null
	
	for player_id in Global.player_bids.keys():
		if max_bid_id == null or Global.player_bids[player_id] > Global.player_bids[max_bid_id]:
			max_bid_id = player_id
		elif Global.player_bids[player_id] == Global.player_bids[max_bid_id]:
			if Global.player_info[player_id].cunning > Global.player_info[max_bid_id].cunning:
				max_bid_id = player_id
				
	if max_bid_id != null:
		Global.player_info[max_bid_id].gold -= Global.player_bids[max_bid_id]
		player_ui.sync_manager.rpc("sync_player_info", max_bid_id, Global.player_info[max_bid_id])
		player_ui.sync_manager.rpc_id(max_bid_id, "add_trinket_and_sync", Global.bid_item_indices[Global.current_bid_item])
