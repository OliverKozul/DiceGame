extends Manager
class_name TurnManager

# Constants for phases
const PHASES = {
	"intention": "intention",
	"action": "action",
	"resolve": "resolve"
}

# Transition to Intention Phase
@rpc("any_peer", "call_local")
func transition_to_intention_phase() -> void:
	player_ui.sync_manager.rpc("sync_phase", PHASES.intention)
	player_ui.sync_manager.rpc("sync_current_player_index", 0)
	determine_player_order()
	player_ui.sync_manager.rpc("sync_player_order", Global.player_order)
	player_ui.player_intention_labels.rpc("update_players")
	rpc("show_phase_ui", "intention", "Declare your intention!")
	rpc("create_and_animate_rect")

# Transition to Action Phase
@rpc("any_peer", "call_local")
func transition_to_action_phase() -> void:
	player_ui.sync_manager.rpc("sync_phase", PHASES.action)
	player_ui.sync_manager.rpc("sync_current_player_index", 0)
	
	rpc_id(1, "allow_current_player_play")

# Transition to Resolve Phase
@rpc("any_peer", "call_local")
func transition_to_resolve_phase() -> void:
	player_ui.sync_manager.rpc("sync_phase", PHASES.resolve)
	player_ui.sync_manager.rpc("sync_current_player_index", 0)
	
	Global.player_order.reverse()
	player_ui.sync_manager.rpc("sync_player_order", Global.player_order)
	rpc_id(1, "allow_current_player_play")

# Check if All Players Have Performed an Action
func check_all_players_played() -> bool:
	return Global.current_player_index >= Global.player_order.size()

# Determine Action Order
func determine_player_order() -> void:
	Global.player_order = Global.players
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
	
	return player_a_id > player_b_id  # Random tie-breaker using rng

# Allow Current Player Action
@rpc("any_peer", "call_local")
func allow_current_player_play() -> void:
	var current_player = Global.player_order[Global.current_player_index]
	
	for player_id in Global.player_order:
		if player_id == current_player:
			if Global.current_phase == PHASES.action:
				rpc_id(player_id, "show_phase_ui", "action", "It's your turn!")
			elif Global.current_phase == PHASES.resolve:
				rpc_id(player_id, "show_phase_ui", "resolve", "It's your turn!")
				player_ui.resolve_manager.rpc("resolve_current_player_turn", player_id)
		else:
			rpc_id(player_id, "show_phase_ui", "wait", "Waiting for player %s" % Global.player_names[current_player])

# Initiate Next Turn (Only Host Can Trigger)
@rpc("any_peer", "call_local")
func initiate_next_turn() -> void:
	if Global.boss.current_hp > 0:
		player_ui.combat_manager.rpc("deal_boss_damage")
		
	Global.current_turn += 1
	player_ui.sync_manager.rpc("sync_turn", Global.current_turn)
	print("Turn ", Global.current_turn)

# Advance to Next Player
@rpc("any_peer", "call_local")
func advance_to_next_player() -> void:
	#player_ui.current_player_label.text = "Waiting for next turn."
	player_ui.sync_manager.rpc("sync_current_player_index", Global.current_player_index + 1)
	
	if check_all_players_played():
		if Global.current_phase == PHASES.action:
			print("All players have acted. Transitioning to resolve phase.")
			rpc_id(1, "transition_to_resolve_phase")
		elif Global.current_phase == PHASES.resolve:
			print("All players have been resolved. Transitioning to next turn.")
			rpc_id(1, "initiate_next_turn")
	else:
		rpc_id(1, "allow_current_player_play")

@rpc("any_peer", "call_local")
func show_phase_ui(buttons: String, label_text: String) -> void:
	player_ui.buttons.show_buttons(buttons)
	player_ui.current_player_label.text = label_text

@rpc("any_peer", "call_local")
func create_and_animate_rect() -> void:
	var rect = Utils.create_rect()
	player_ui.add_child(rect)
	var tween = get_tree().create_tween()
	tween.tween_property(rect, "scale", Vector2(0, 0), 1.0)  # 5-second shrink
	tween.finished.connect(_on_tween_completed.bind(rect))

func _on_tween_completed(rect: TextureRect) -> void:
	rect.queue_free()
	
	if multiplayer.is_server():
		rpc_id(1, "transition_to_action_phase")
