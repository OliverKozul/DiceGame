extends CanvasLayer

@onready var next_turn_button = %NextTurnButton
@onready var roll_button = %RollButton
@onready var attack_button = %AttackButton

@onready var turn_label = %TurnLabel
@onready var roll_result_label = %RollResultLabel
@onready var attack_label = %AttackLabel
@onready var gold_label = %GoldLabel

var die_faces = ["⚔", "⚔", "💰", "💰", "🎁", "🎁"]
var gold_count : int = 0

func _ready():
	roll_button.pressed.connect(_on_roll_button_pressed)
	next_turn_button.pressed.connect(_on_next_turn_button_pressed)
	attack_button.pressed.connect(_on_attack_button_pressed)

	if multiplayer.is_server():
		Global.current_turn = 1
		turn_label.text = "Current turn: 1"
	else:
		rpc_id(1, "request_turn_sync")

### **Player Rolls**
@rpc("any_peer", "call_local")
func _on_roll_button_pressed():
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

	Global.players_rolled[player_id] = true  # Mark as rolled
	
	# Send result to all players
	rpc("sync_roll_result", player_id, roll_result)

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

### **Next Phase (Only Host Can Trigger)**
@rpc("authority", "call_local")
func _on_next_turn_button_pressed():
	if multiplayer.is_server() and check_all_players_rolled():
		Global.current_turn += 1
		rpc("sync_turn", Global.current_turn)

@rpc("any_peer", "call_local")
func sync_turn(new_turn):
	Global.players_rolled.clear()
	Global.current_turn = new_turn
	turn_label.text = "Current turn: " + str(Global.current_turn)

### **Attack System**
@rpc("any_peer", "call_local")
func _on_attack_button_pressed():
	if roll_result_label.text.contains("⚔"):
		attack_label.text = "You killed the enemy."
	else:
		attack_label.text = "You didn't roll an attack, try something else."

### **Request Turn Sync (For Late Joiners)**
@rpc("any_peer", "call_local")
func request_turn_sync():
	if multiplayer.is_server():
		rpc_id(multiplayer.get_remote_sender_id(), "sync_turn", Global.current_turn)
