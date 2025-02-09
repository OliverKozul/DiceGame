extends CanvasLayer


@onready var current_player_label = %CurrentPlayerLabel  # Add a label for current player
@onready var status_labels = %StatusLabels
@onready var turn_info_labels = %TurnInfoLabels
@onready var buttons = %Buttons
@onready var shop = %Shop

@onready var roll_manager = %RollManager
@onready var sync_manager = %SyncManager

var rng = RandomNumberGenerator.new()  # Create a RandomNumberGenerator instance

signal update_all_status_labels

func _ready():
	var player_id = multiplayer.get_unique_id()
	rng.seed = 32  # Set the seed to 0
	initialize(player_id)

	if multiplayer.is_server():
		Global.current_turn = 1
	else:
		rpc_id(1, "request_turn_sync")

func initialize(player_id : int):
	if not Global.player_info.has(player_id):
		Global.player_info[player_id] = {
			"gold": 0,
			"cunning": 0,
			"hp": 10,
			"trinkets": [],
			"die_faces": ["⚔", "⚔", "💰", "💰", "🧠", "🧠"],
			"die_face_values": {"⚔": 1, "💰": 1, "🧠": 1}
		}
		
	status_labels.initialize(self, player_id)
	turn_info_labels.initialize(self, player_id)
	buttons.initialize(self, player_id)
	shop.initialize(self, player_id)
	
	roll_manager.initialize(self)
	sync_manager.initialize(self)
	
	current_player_label.text = "Roll the dice!"

### **Player Rolls**
@rpc("any_peer", "call_local")
func transition_to_action_phase():
	rpc("sync_phase", "action")  # Synchronize phase transition
	print("All players have rolled. Transitioning to action phase.")
	determine_action_order()
	rpc("allow_current_player_action")

@rpc("any_peer", "call_local")
func sync_phase(new_phase):
	Global.current_phase = new_phase
		
#### **Sync Roll Result for Everyone**
#@rpc("any_peer", "call_local")
#func sync_player_info(player_id, player_info):
	#Global.player_info[player_id] = player_info
	#if multiplayer.get_unique_id() == player_id:
		#status_labels.gold.text = "💰 count: " + str(Global.player_info[player_id].gold)
		#status_labels.cunning.text = "🧠 count: " + str(Global.player_info[player_id].cunning)
		#status_labels.hp.text = "❤️ HP: " + str(Global.player_info[player_id].hp)
		#status_labels.trinkets.text = "Trinkets: " + str(Global.player_info[player_id].trinkets)
#
#### **Sync Roll Result for Everyone**
#@rpc("any_peer", "call_local")
#func sync_roll_result(player_id, roll_result):
	#Global.players_rolled[player_id] = true
	#print(Global.current_turn, ". turn, Player %s rolled: %s" % [player_id, roll_result])

### **Check if All Players Have Rolled**
func check_all_players_rolled():
	var all_players = multiplayer.get_peers()
	all_players.append(multiplayer.get_unique_id())  # Include the host in the list

	var all_rolled = true
	for id in all_players:
		if not Global.players_rolled.get(id, false):
			all_rolled = false
			break

	return all_rolled

### **Check if All Players Have Performed an Action**
func check_all_players_acted():
	return Global.current_action_index >= Global.action_order.size()

### **Determine Action Order**
func determine_action_order():
	var all_players = multiplayer.get_peers()
	all_players.append(multiplayer.get_unique_id())  # Include the host in the list
	Global.action_order = Array(all_players)
	if multiplayer.is_server():
		Global.action_order.sort_custom(_compare_players)
		rpc("sync_action_order", Global.action_order)
	else:
		rpc_id(1, "request_action_order")
	
	Global.current_action_index = 0

@rpc("any_peer", "call_local")
func sync_action_order(new_action_order):
	Global.action_order = new_action_order

@rpc("any_peer", "call_local")
func request_action_order():
	if multiplayer.is_server():
		rpc_id(multiplayer.get_remote_sender_id(), "sync_action_order", Global.action_order)

### **Compare Players for Sorting**
func _compare_players(player_b, player_a):
	var cunning_a = Global.player_info[player_a].cunning
	var cunning_b = Global.player_info[player_b].cunning
	if cunning_a != cunning_b:
		return true if cunning_a - cunning_b > 0 else false
	
	var gold_a = Global.player_info[player_a].gold
	var gold_b = Global.player_info[player_b].gold
	
	if gold_a != gold_b:
		return true if gold_a - gold_b > 0 else false
	
	return true if rng.randi() % 2 == 0 else false  # Random tie-breaker using rng

### **Allow Current Player Action**
@rpc("any_peer", "call_local")
func allow_current_player_action():
	var current_player = Global.action_order[Global.current_action_index]
	print("Entered allow! ", current_player, " ", multiplayer.get_unique_id())
	if multiplayer.get_unique_id() == current_player:
		#_show_action_buttons()
		buttons.show_buttons("action")
		current_player_label.text = "It's your turn!"
	else:
		#_hide_action_buttons()
		buttons.show_buttons("wait")
		current_player_label.text = "Waiting for player %s" % str(current_player)

### **Next Phase (Only Host Can Trigger)**
@rpc("authority", "call_local")
func _on_next_turn_button_pressed():
	if Global.current_phase != "action":
		print("Cannot transition to next turn. It's not the action phase!")
		return
	
	if not check_all_players_acted():
		print("Not all players have performed an action!")
		return
	
	Global.current_turn += 1
	rpc("sync_turn", Global.current_turn)
	print("Turn ", Global.current_turn)

@rpc("any_peer", "call_local")
func sync_turn(new_turn):
	Global.players_rolled.clear()
	Global.players_acted.clear()
	Global.current_turn = new_turn
	#buttons.roll.visible = true
	buttons.show_buttons("roll")
	current_player_label.text = "Roll the dice!"
	rpc("sync_phase", "roll")
	rpc("sync_current_action_index", 0)
	
	turn_info_labels.turn.text = "Current turn: " + str(Global.current_turn)

### **Attack Player**
@rpc("any_peer", "call_local")
func _on_attack_player_button_pressed():
	if Global.current_phase != "action":
		print("It's not the action phase!")
		return
	
	var player_id = multiplayer.get_unique_id()
	
	# Prevent performing action more than once per turn
	if Global.players_acted.get(player_id, false):
		print("You already performed an action this turn!")
		return
	
	if turn_info_labels.roll_result.text.contains("⚔"):
		turn_info_labels.action.text = "You attacked another player."
		Global.players_acted[player_id] = true  # Mark as acted
		# Implement damage to another player here
		advance_to_next_player()
	else:
		turn_info_labels.action.text = "You didn't roll an attack, try something else."

### **Attack Mobs**
@rpc("any_peer", "call_local")
func _on_attack_mobs_button_pressed():
	if Global.current_phase != "action":
		print("It's not the action phase!")
		return
	
	var player_id = multiplayer.get_unique_id()
	
	# Prevent performing action more than once per turn
	if Global.players_acted.get(player_id, false):
		print("You already performed an action this turn!")
		return
	
	if turn_info_labels.roll_result.text.contains("⚔"):
		turn_info_labels.action.text = "You attacked a mob."
		Global.players_acted[player_id] = true  # Mark as acted
		# Implement mob defeat and trinket reward here
		advance_to_next_player()
	else:
		turn_info_labels.action.text = "You didn't roll an attack, try something else."
	

### **Attack Boss**
@rpc("any_peer", "call_local")
func _on_attack_boss_button_pressed():
	if Global.current_phase != "action":
		print("It's not the action phase!")
		return
	
	var player_id = multiplayer.get_unique_id()
	
	# Prevent performing action more than once per turn
	if Global.players_acted.get(player_id, false):
		print("You already performed an action this turn!")
		return
	
	if turn_info_labels.roll_result.text.contains("⚔"):
		turn_info_labels.action.text = "You attacked the boss."
		Global.players_acted[player_id] = true  # Mark as acted
		# Implement boss fight logic here
		advance_to_next_player()
	else:
		turn_info_labels.action.text = "You didn't roll an attack, try something else."

### **Shop**
@rpc("any_peer", "call_local")
func _on_shop_button_pressed():
	if Global.current_phase != "action":
		print("It's not the action phase!")
		return
	
	var player_id = multiplayer.get_unique_id()
	
	# Prevent performing action more than once per turn
	if Global.players_acted.get(player_id, false):
		print("You already performed an action this turn!")
		return
		
	Global.players_acted[player_id] = true  # Mark as acted
	shop.show()
	
	advance_to_next_player()

### **Skip**
@rpc("any_peer", "call_local")
func _on_skip_button_pressed():
	if Global.current_phase != "action":
		print("It's not the action phase!")
		return
	
	var player_id = multiplayer.get_unique_id()
	
	# Prevent performing action more than once per turn
	if Global.players_acted.get(player_id, false):
		print("You already performed an action this turn!")
		return
		
	Global.players_acted[player_id] = true  # Mark as acted
	turn_info_labels.action.text = "Turn skipped."
	
	advance_to_next_player()

### **Advance to Next Player**
@rpc("any_peer", "call_local")
func advance_to_next_player():
	Global.current_action_index += 1
	current_player_label.text = "Waiting for next turn."
	rpc("sync_current_action_index", Global.current_action_index)
	
	if check_all_players_acted():
		print("All players have acted. Transitioning to next turn.")
		_on_next_turn_button_pressed()
	else:
		rpc("allow_current_player_action")

@rpc("any_peer", "call_local")
func sync_current_action_index(new_index):
	Global.current_action_index = new_index

### **Request Turn Sync (For Late Joiners)**
@rpc("any_peer", "call_local")
func request_turn_sync():
	if multiplayer.is_server():
		rpc_id(multiplayer.get_remote_sender_id(), "sync_turn", Global.current_turn)

### **Handle Player Damage**
func apply_damage(player_id, damage):
	Global.player_info[player_id].hp -= damage
	status_labels.hp.text = "HP: " + str(Global.player_info[player_id].hp)
	if Global.player_info[player_id].hp <= 0:
		eliminate_player(player_id)

### **Eliminate Player**
func eliminate_player(player_id):
	print("Player %s eliminated!" % player_id)
	# Implement player elimination logic here

### **Handle Trinket Rewards**
func add_trinket(player_id, trinket):
	Global.player_info[player_id].trinkets.append(trinket)
	status_labels.trinkets.text = "Trinkets: " + str(Global.player_info[player_id].trinkets)
	# Implement trinket effect here

### **Handle Boss Fight Logic**
func handle_boss_fight():
	# Implement boss fight logic here
	# Example: Check if all players attacked the boss and distribute loot
	pass
