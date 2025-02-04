extends CanvasLayer

@onready var roll_button = %RollButton
@onready var action_buttons = %ActionButtons

@onready var turn_label = %TurnLabel
@onready var roll_result_label = %RollResultLabel
@onready var action_label = %ActionLabel
@onready var gold_label = %GoldLabel
@onready var cunning_label = %CunningLabel  # Add a label for Cunning
@onready var hp_label = %HPLabel  # Add a label for HP
@onready var trinkets_label = %TrinketsLabel  # Add a label for Trinkets
@onready var current_player_label = %CurrentPlayerLabel  # Add a label for current player

@onready var shop = %Shop

var current_phase = "roll"  # New variable to track the current phase
var action_order = []  # New variable to track action order
var current_action_index = 0  # New variable to track the current player in action phase

var rng = RandomNumberGenerator.new()  # Create a RandomNumberGenerator instance

func _ready():
	rng.seed = 32  # Set the seed to 0
	var player_id = multiplayer.get_unique_id()
	initialize(player_id)

	roll_button.pressed.connect(_on_roll_button_pressed)
	action_buttons.next_turn_button.pressed.connect(_on_next_turn_button_pressed)
	action_buttons.attack_player_button.pressed.connect(_on_attack_player_button_pressed)
	action_buttons.attack_mobs_button.pressed.connect(_on_attack_mobs_button_pressed)
	action_buttons.attack_boss_button.pressed.connect(_on_attack_boss_button_pressed)
	action_buttons.shop_button.pressed.connect(_on_shop_button_pressed)
	action_buttons.skip_button.pressed.connect(_on_skip_button_pressed)

	# Hide action buttons initially
	_hide_action_buttons()

	if multiplayer.is_server():
		Global.current_turn = 1
		turn_label.text = "Current turn: 1"
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

	gold_label.text = "💰 count: " + str(Global.player_info[player_id].gold)
	cunning_label.text = "🧠 count: " + str(Global.player_info[player_id].cunning)
	hp_label.text = "❤️ HP: " + str(Global.player_info[player_id].hp)
	trinkets_label.text = "Trinkets: " + str(Global.player_info[player_id].trinkets)
	current_player_label.text = "Roll the dice!"

### **Player Rolls**
@rpc("any_peer", "call_local")
func _on_roll_button_pressed():
	if current_phase != "roll":
		print("It's not the roll phase!")
		return
	
	var player_id = multiplayer.get_unique_id()
	roll_button.visible = false
	
	# Prevent rolling more than once per turn
	if Global.players_rolled.get(player_id, false):
		print("You already rolled this turn!")
		return
	
	var roll_result = Global.player_info[player_id].die_faces[randi() % Global.player_info[player_id].die_faces.size()]
	roll_result_label.text = "You rolled: " + str(Global.player_info[player_id].die_face_values[roll_result]) + " " + roll_result
	
	if roll_result == "💰":
		Global.player_info[player_id].gold += Global.player_info[player_id].die_face_values[roll_result]
		gold_label.text = "💰 count: " + str(Global.player_info[player_id].gold)
		rpc("sync_player_info", player_id, Global.player_info[player_id])
	elif roll_result == "🧠":
		Global.player_info[player_id].cunning += Global.player_info[player_id].die_face_values[roll_result]
		cunning_label.text = "🧠 count: " + str(Global.player_info[player_id].cunning)
		rpc("sync_player_info", player_id, Global.player_info[player_id])

	Global.players_rolled[player_id] = true  # Mark as rolled
	
	# Send result to all players
	rpc("sync_roll_result", player_id, roll_result)
	rpc("sync_player_info", player_id, Global.player_info[player_id])

	# Check if all players have rolled
	if check_all_players_rolled():
		rpc("transition_to_action_phase")
		
@rpc("any_peer", "call_local")
func transition_to_action_phase():
	rpc("sync_phase", "action")  # Synchronize phase transition
	print("All players have rolled. Transitioning to action phase.")
	determine_action_order()
	rpc("allow_current_player_action")

@rpc("any_peer", "call_local")
func sync_phase(new_phase):
	current_phase = new_phase
		
### **Sync Roll Result for Everyone**
@rpc("any_peer", "call_local")
func sync_player_info(player_id, player_info):
	Global.player_info[player_id] = player_info
	#print("Player ID: ", player_id)
	#print("Player INFO: ", Global.player_info[player_id])
	if multiplayer.get_unique_id() == player_id:
		gold_label.text = "💰 count: " + str(Global.player_info[player_id].gold)
		cunning_label.text = "🧠 count: " + str(Global.player_info[player_id].cunning)
		hp_label.text = "❤️ HP: " + str(Global.player_info[player_id].hp)
		trinkets_label.text = "Trinkets: " + str(Global.player_info[player_id].trinkets)

### **Sync Roll Result for Everyone**
@rpc("any_peer", "call_local")
func sync_roll_result(player_id, roll_result):
	Global.players_rolled[player_id] = true
	print(Global.current_turn, ". turn, Player %s rolled: %s" % [player_id, roll_result])

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
	return current_action_index >= action_order.size()

### **Determine Action Order**
func determine_action_order():
	var all_players = multiplayer.get_peers()
	all_players.append(multiplayer.get_unique_id())  # Include the host in the list
	action_order = Array(all_players)
	print(multiplayer.get_unique_id()," BEFORE Action order is: ", action_order)
	if multiplayer.is_server():
		action_order.sort_custom(_compare_players)
		rpc("sync_action_order", action_order)
	else:
		rpc_id(1, "request_action_order")
	
	current_action_index = 0
	print(multiplayer.get_unique_id(), " AFTER Action order is: ", action_order)

@rpc("any_peer", "call_local")
func sync_action_order(new_action_order):
	action_order = new_action_order

@rpc("any_peer", "call_local")
func request_action_order():
	if multiplayer.is_server():
		rpc_id(multiplayer.get_remote_sender_id(), "sync_action_order", action_order)

### **Compare Players for Sorting**
func _compare_players(player_b, player_a):
	var cunning_a = Global.player_info[player_a].cunning
	var cunning_b = Global.player_info[player_b].cunning
	#print("Player A: ", player_a)
	#print("Player INFO: ", Global.player_info[player_a])
	#print("Player B: ", player_b)
	#print("Player INFO: ", Global.player_info[player_b])
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
	var current_player = action_order[current_action_index]
	#print("Current player ", current_player)
	#print("Multiplayer ID ", multiplayer.get_unique_id())
	if multiplayer.get_unique_id() == current_player:
		_show_action_buttons()
		current_player_label.text = "It's your turn!"
	else:
		_hide_action_buttons()
		current_player_label.text = "Waiting for player %s" % str(current_player)

### **Next Phase (Only Host Can Trigger)**
@rpc("authority", "call_local")
func _on_next_turn_button_pressed():
	if current_phase != "action":
		print("Cannot transition to next turn. It's not the action phase!")
		return
	
	if not check_all_players_acted():
		print("Not all players have performed an action!")
		return
	
	Global.current_turn += 1
	rpc("sync_turn", Global.current_turn)
	print("Turn ", Global.current_turn)
	_hide_action_buttons()

@rpc("any_peer", "call_local")
func sync_turn(new_turn):
	Global.players_rolled.clear()
	Global.players_acted.clear()
	Global.current_turn = new_turn
	roll_button.visible = true
	current_player_label.text = "Roll the dice!"
	rpc("sync_phase", "roll")
	rpc("sync_current_action_index", 0)
	
	turn_label.text = "Current turn: " + str(Global.current_turn)

### **Attack Player**
@rpc("any_peer", "call_local")
func _on_attack_player_button_pressed():
	if current_phase != "action":
		print("It's not the action phase!")
		return
	
	var player_id = multiplayer.get_unique_id()
	
	# Prevent performing action more than once per turn
	if Global.players_acted.get(player_id, false):
		print("You already performed an action this turn!")
		return
	
	if roll_result_label.text.contains("⚔"):
		action_label.text = "You attacked another player."
		Global.players_acted[player_id] = true  # Mark as acted
		# Implement damage to another player here
		advance_to_next_player()
	else:
		action_label.text = "You didn't roll an attack, try something else."

### **Attack Mobs**
@rpc("any_peer", "call_local")
func _on_attack_mobs_button_pressed():
	if current_phase != "action":
		print("It's not the action phase!")
		return
	
	var player_id = multiplayer.get_unique_id()
	
	# Prevent performing action more than once per turn
	if Global.players_acted.get(player_id, false):
		print("You already performed an action this turn!")
		return
	
	if roll_result_label.text.contains("⚔"):
		action_label.text = "You attacked a mob."
		Global.players_acted[player_id] = true  # Mark as acted
		# Implement mob defeat and trinket reward here
		advance_to_next_player()
	else:
		action_label.text = "You didn't roll an attack, try something else."
	

### **Attack Boss**
@rpc("any_peer", "call_local")
func _on_attack_boss_button_pressed():
	if current_phase != "action":
		print("It's not the action phase!")
		return
	
	var player_id = multiplayer.get_unique_id()
	
	# Prevent performing action more than once per turn
	if Global.players_acted.get(player_id, false):
		print("You already performed an action this turn!")
		return
	
	if roll_result_label.text.contains("⚔"):
		action_label.text = "You attacked the boss."
		Global.players_acted[player_id] = true  # Mark as acted
		# Implement boss fight logic here
		advance_to_next_player()
	else:
		action_label.text = "You didn't roll an attack, try something else."

### **Shop**
@rpc("any_peer", "call_local")
func _on_shop_button_pressed():
	if current_phase != "action":
		print("It's not the action phase!")
		return
	
	var player_id = multiplayer.get_unique_id()
	
	# Prevent performing action more than once per turn
	if Global.players_acted.get(player_id, false):
		print("You already performed an action this turn!")
		return
		
	shop.activate(player_id)
	
	advance_to_next_player()

### **Skip**
@rpc("any_peer", "call_local")
func _on_skip_button_pressed():
	if current_phase != "action":
		print("It's not the action phase!")
		return
	
	var player_id = multiplayer.get_unique_id()
	
	# Prevent performing action more than once per turn
	if Global.players_acted.get(player_id, false):
		print("You already performed an action this turn!")
		return
		
	Global.players_acted[player_id] = true  # Mark as acted
	action_label.text = "Turn skipped."
	
	advance_to_next_player()

### **Advance to Next Player**
@rpc("any_peer", "call_local")
func advance_to_next_player():
	current_action_index += 1
	current_player_label.text = "Waiting for next turn."
	rpc("sync_current_action_index", current_action_index)
	
	if check_all_players_acted():
		print("All players have acted. Transitioning to next turn.")
		_on_next_turn_button_pressed()
	else:
		rpc("allow_current_player_action")

@rpc("any_peer", "call_local")
func sync_current_action_index(new_index):
	current_action_index = new_index

### **Request Turn Sync (For Late Joiners)**
@rpc("any_peer", "call_local")
func request_turn_sync():
	if multiplayer.is_server():
		rpc_id(multiplayer.get_remote_sender_id(), "sync_turn", Global.current_turn)

### **Show Action Buttons**
func _show_action_buttons():
	action_buttons.next_turn_button.visible = true
	action_buttons.attack_player_button.visible = true
	action_buttons.attack_mobs_button.visible = true
	action_buttons.attack_boss_button.visible = true
	action_buttons.shop_button.visible = true
	action_buttons.skip_button.visible = true

### **Hide Action Buttons**
func _hide_action_buttons():
	action_buttons.next_turn_button.visible = false
	action_buttons.attack_player_button.visible = false
	action_buttons.attack_mobs_button.visible = false
	action_buttons.attack_boss_button.visible = false
	action_buttons.shop_button.visible = false
	action_buttons.skip_button.visible = false

### **Handle Player Damage**
func apply_damage(player_id, damage):
	Global.player_info[player_id].hp -= damage
	hp_label.text = "HP: " + str(Global.player_info[player_id].hp)
	if Global.player_info[player_id].hp <= 0:
		eliminate_player(player_id)

### **Eliminate Player**
func eliminate_player(player_id):
	print("Player %s eliminated!" % player_id)
	# Implement player elimination logic here

### **Handle Trinket Rewards**
func add_trinket(player_id, trinket):
	Global.player_info[player_id].trinkets.append(trinket)
	trinkets_label.text = "Trinkets: " + str(Global.player_info[player_id].trinkets)
	# Implement trinket effect here

### **Handle Boss Fight Logic**
func handle_boss_fight():
	# Implement boss fight logic here
	# Example: Check if all players attacked the boss and distribute loot
	pass
