extends CanvasLayer

@onready var roll_button = %RollButton
@onready var action_buttons = %ActionButtons

@onready var turn_label = %TurnLabel
@onready var roll_result_label = %RollResultLabel
@onready var action_label = %ActionLabel
@onready var gold_label = %GoldLabel
@onready var cunning_label = %CunningLabel  # Add a label for Cunning

@onready var shop = %Shop

var die_faces = ["⚔", "⚔", "💰", "💰", "🧠", "🧠"]
var gold_count : int = 0
var cunning_count : int = 0  # New variable to track Cunning
var current_phase = "roll"  # New variable to track the current phase

func _ready():
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

### **Player Rolls**
@rpc("any_peer", "call_local")
func _on_roll_button_pressed():
	if current_phase != "roll":
		print("It's not the roll phase!")
		return
	
	var player_id = multiplayer.get_unique_id()
	
	# Prevent rolling more than once per turn
	if Global.players_rolled.get(player_id, false):
		print("You already rolled this turn!")
		return
	
	var roll_result = die_faces[randi() % die_faces.size()]
	roll_result_label.text = "You rolled: " + roll_result
	
	if roll_result == "💰":
		gold_count += 1
		gold_label.text = "💰 count: " + str(gold_count)
	elif roll_result == "🧠":
		cunning_count += 1
		cunning_label.text = "🧠 count: " + str(cunning_count)

	Global.players_rolled[player_id] = true  # Mark as rolled
	
	# Send result to all players
	rpc("sync_roll_result", player_id, roll_result)

	# Check if all players have rolled
	if check_all_players_rolled():
		current_phase = "action"  # Transition to action phase
		print("All players have rolled. Transitioning to action phase.")
		_show_action_buttons()

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
	var all_players = multiplayer.get_peers()
	all_players.append(multiplayer.get_unique_id())  # Include the host in the list

	var all_acted = true
	for id in all_players:
		if not Global.players_acted.get(id, false):
			all_acted = false
			break

	return all_acted

### **Next Phase (Only Host Can Trigger)**
@rpc("authority", "call_local")
func _on_next_turn_button_pressed():
	if multiplayer.is_server():
		if current_phase != "action":
			print("Cannot transition to next turn. It's not the action phase!")
			return
		
		if not check_all_players_acted():
			print("Not all players have performed an action!")
			return
		
		Global.current_turn += 1
		rpc("sync_turn", Global.current_turn)
		current_phase = "roll"  # Reset to roll phase for the next turn
		Global.players_acted.clear()  # Clear actions for the next turn
		print("Turn ", Global.current_turn)
		_hide_action_buttons()

@rpc("any_peer", "call_local")
func sync_turn(new_turn):
	Global.players_rolled.clear()
	Global.current_turn = new_turn
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
		
	shop.show()
	Global.players_acted[player_id] = true  # Mark as acted
	
	#if gold_count > 0:
		#gold_count -= 1
		#gold_label.text = "💰 count: " + str(gold_count)
		#action_label.text = "You bought an item."
		#Global.players_acted[player_id] = true  # Mark as acted
	#else:
		#action_label.text = "Not enough gold to buy an item."
		
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

### **Request Turn Sync (For Late Joiners)**
@rpc("any_peer", "call_local")
func request_turn_sync():
	if multiplayer.is_server():
		rpc_id(multiplayer.get_remote_sender_id(), "sync_turn", Global.current_turn)

### **Show Action Buttons**
func _show_action_buttons():
	roll_button.visible = false
	action_buttons.next_turn_button.visible = true
	action_buttons.attack_player_button.visible = true
	action_buttons.attack_mobs_button.visible = true
	action_buttons.attack_boss_button.visible = true
	action_buttons.shop_button.visible = true
	action_buttons.skip_button.visible = true

### **Hide Action Buttons**
func _hide_action_buttons():
	roll_button.visible = true
	action_buttons.next_turn_button.visible = false
	action_buttons.attack_player_button.visible = false
	action_buttons.attack_mobs_button.visible = false
	action_buttons.attack_boss_button.visible = false
	action_buttons.shop_button.visible = false
	action_buttons.skip_button.visible = false
