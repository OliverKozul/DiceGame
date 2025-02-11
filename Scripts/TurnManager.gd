extends Manager

# Constants for phases
const PHASES = {
	"intention": "intention",
	"action": "action",
	"resolve": "resolve"
}

# Transition to Intention Phase
@rpc("any_peer", "call_local")
func transition_to_intention_phase() -> void:
	_sync_phase(PHASES.intention)
	_show_phase_ui("intention", "Declare your intention!")
	_create_and_animate_rect()

# Transition to Action Phase
@rpc("any_peer", "call_local")
func transition_to_action_phase() -> void:
	_sync_phase(PHASES.action)
	_sync_current_player_index(0)
	_show_phase_ui("action", "All players have declared their intention. Transitioning to action phase.")
	rpc("_determine_player_order")
	rpc("allow_current_player_play")

# Transition to Resolve Phase
@rpc("any_peer", "call_local")
func transition_to_resolve_phase() -> void:
	_sync_phase(PHASES.resolve)
	_sync_current_player_index(0)
	_show_phase_ui("resolve", "All players have acted. Transitioning to resolve phase.")
	_flip_player_order()
	rpc("allow_current_player_play")

# Check if All Players Have Performed an Action
func check_all_players_played() -> bool:
	return Global.current_player_index >= Global.player_order.size()

# Determine Action Order
@rpc("any_peer", "call_local")
func _determine_player_order() -> void:
	var all_players = multiplayer.get_peers()
	all_players.append(multiplayer.get_unique_id())  # Include the host in the list
	Global.player_order = Array(all_players)
	Global.player_order.sort_custom(_compare_players)
	#player_ui.sync_manager.rpc("sync_player_order", Global.player_order)
	
# Compare Players for Sorting
func _compare_players(player_b_id : int, player_a_id : int) -> bool:
	var cunning_a = Global.player_info[player_a_id].cunning
	var cunning_b = Global.player_info[player_b_id].cunning
	if cunning_a != cunning_b:
		return cunning_a > cunning_b
	
	var gold_a = Global.player_info[player_a_id].gold
	var gold_b = Global.player_info[player_b_id].gold
	if gold_a != gold_b:
		return gold_a > gold_b
	
	return player_ui.rng.randi() % 2 == 0  # Random tie-breaker using rng
	#return false  # Random tie-breaker using rng
	
func _flip_player_order() -> void:
	if multiplayer.is_server():
		Global.player_order.reverse()
		player_ui.sync_manager.rpc("sync_player_order", Global.player_order)

# Request Player Order
@rpc("any_peer", "call_local")
func request_player_order() -> void:
	if multiplayer.is_server():
		player_ui.sync_manager.rpc_id(multiplayer.get_remote_sender_id(), "sync_player_order", Global.player_order)

# Request Turn Sync (For Late Joiners)
@rpc("any_peer", "call_local")
func request_turn_sync() -> void:
	if multiplayer.is_server():
		player_ui.sync_manager.rpc_id(multiplayer.get_remote_sender_id(), "sync_turn", Global.current_turn)

# Allow Current Player Action
@rpc("any_peer", "call_local")
func allow_current_player_play() -> void:
	var current_player = Global.player_order[Global.current_player_index]
	if multiplayer.get_unique_id() == current_player:
		if Global.current_phase == PHASES.action:
			_show_phase_ui("action", "It's your turn!")
		elif Global.current_phase == PHASES.resolve:
			_show_phase_ui("resolve", "It's your turn!")
	else:
		_show_phase_ui("wait", "Waiting for player %s" % str(current_player))

# Initiate Next Turn (Only Host Can Trigger)
@rpc("authority", "call_local")
func initiate_next_turn() -> void:
	Global.current_turn += 1
	player_ui.sync_manager.rpc("sync_turn", Global.current_turn)
	print("Turn ", Global.current_turn)

# Advance to Next Player
@rpc("any_peer", "call_local")
func advance_to_next_player() -> void:
	Global.current_player_index += 1
	player_ui.current_player_label.text = "Waiting for next turn."
	player_ui.sync_manager.rpc("sync_current_player_index", Global.current_player_index)
	if check_all_players_played():
		if Global.current_phase == PHASES.action:
			print("All players have acted. Transitioning to resolve phase.")
			rpc("transition_to_resolve_phase")
		elif Global.current_phase == PHASES.resolve:
			print("All players have been resolved. Transitioning to next turn.")
			initiate_next_turn()
	else:
		rpc("allow_current_player_play")

# Helper Functions
func _sync_phase(phase: String) -> void:
	player_ui.sync_manager.rpc("sync_phase", phase)

func _sync_current_player_index(index: int) -> void:
	player_ui.sync_manager.rpc("sync_current_player_index", index)

func _show_phase_ui(buttons: String, label_text: String) -> void:
	player_ui.buttons.show_buttons(buttons)
	player_ui.current_player_label.text = label_text

func _create_and_animate_rect() -> void:
	var rect = Utils.create_rect()
	player_ui.add_child(rect)
	var tween = get_tree().create_tween()
	tween.tween_property(rect, "scale", Vector2(0, 0), 1.0)  # 5-second shrink
	tween.finished.connect(_on_tween_completed.bind(rect))

func _on_tween_completed(rect: TextureRect) -> void:
	rect.queue_free()  # Remove the TextureRect
	rpc("transition_to_action_phase")
