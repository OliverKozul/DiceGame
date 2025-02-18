extends CanvasLayer


@onready var status_label = %ConnectionStatusLabel
@onready var lobby_text_label: Label = %LobbyTextLabel
@onready var player_list_label: Label = %PlayerListLabel

@onready var ip_input = %ServerIPTextEdit
@onready var player_name_text_edit: LineEdit = %PlayerNameTextEdit

@onready var host_game_button = %HostGameButton
@onready var join_game_button = %JoinGameButton
@onready var start_game_button = %StartGameButton
@onready var player_name_button: Button = %PlayerNameButton

@onready var player_name_h_box: HBoxContainer = %PlayerNameHBox
@onready var server_iph_box: HBoxContainer = %ServerIPHBox
@onready var player_list_v_box: VBoxContainer = $PlayerListMargin/PlayerListVBox

const PORT: int = 7777
var peer = ENetMultiplayerPeer.new()
var game_started: bool = false
var player_labels: Dictionary = {}


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	
	host_game_button.pressed.connect(_on_host_button_pressed)
	join_game_button.pressed.connect(_on_join_button_pressed)
	start_game_button.pressed.connect(_on_start_game_pressed)
	player_name_button.pressed.connect(_on_player_name_button_pressed)

# Host a Game
func _on_host_button_pressed() -> void:
	var player_id = multiplayer.get_unique_id()
	peer.create_server(PORT, 4)  # Max 4 players
	multiplayer.multiplayer_peer = peer
	status_label.text = "Hosting game..."
	print("Server started on port ", PORT)
	rpc_id(player_id, "hide_ui")
	rpc_id(player_id, "update_player_array_host", player_id)
	lobby_text_label.text = "Start the game when ready."
	player_list_label.show()

# Join a Game
func _on_join_button_pressed() -> void:
	var ip = ip_input.text.strip_edges()
	
	if ip.is_empty():
		status_label.text = "Enter a valid IP."
		return
	
	peer.create_client(ip, PORT)
	multiplayer.multiplayer_peer = peer
	status_label.text = "Joining server..."
	print("Attempting to connect to ", ip)
	
func _on_player_name_button_pressed() -> void:
	if player_name_text_edit.text in Global.player_names.values():
		status_label.text = "Name already taken."
	elif player_name_text_edit.text in ["Mob", "Boss"]:
		status_label.text = "Name invalid."
	else:
		status_label.text = "Set name to: " + player_name_text_edit.text
		rpc("update_player_name", multiplayer.get_unique_id(), player_name_text_edit.text)

# Connection Success
func _on_peer_connected(player_id: int) -> void:
	print("Player ", player_id, " joined.")
	rpc_id(1, "update_player_name_dict_host")
	rpc_id(1, "update_player_array_host", player_id)
	rpc_id(player_id, "hide_ui")
	player_list_label.show()
	
	if multiplayer.get_unique_id() != 1:
		lobby_text_label.text = "Wait for the host to start the game."

func _on_peer_disconnected(player_id: int) -> void:
	print("Player ", player_id, " left.")

func _on_connected_to_server() -> void:
	status_label.text = "Connected to server!"
	player_name_h_box.visible = true
	print("Connected to server!")

func _on_connection_failed() -> void:
	status_label.text = "Connection failed."
	print("Failed to connect.")

func _on_start_game_pressed() -> void:
	var valid_names = true
		
	if multiplayer.is_server():
		for player_id in Global.players:
			if Global.player_names.get(player_id, "") == "":
				status_label.text = str(player_id) + " didn't enter a name."
				valid_names = false
				break
		
		if valid_names:
			start_game.rpc()

@rpc("any_peer", "call_local")
func update_player_array_host(player_id: int):
	if not Global.players.has(player_id):
		Global.players.append(player_id)
		
	rpc("update_player_array", Global.players)

@rpc("any_peer", "call_local")
func update_player_array(players_array: Array) -> void:
	Global.players = players_array
	
	for player_id in players_array:
		if player_labels.get(player_id, null) == null:
			var label = Label.new()
		
			if Global.player_names.get(player_id, "") == "":
				label.text = str(player_id)
			else:
				label.text = Global.player_names[player_id]
				
			player_labels[player_id] = label
			player_list_v_box.add_child(label)

@rpc("any_peer", "call_local")
func update_player_name_dict_host() -> void:
	rpc("update_player_name_dict", Global.player_names)

@rpc("any_peer", "call_local")
func update_player_name_dict(player_name_array: Dictionary) -> void:
	Global.player_names = player_name_array

@rpc("any_peer", "call_local")
func update_player_name(player_id: int, player_name: String) -> void:
	Global.player_names[player_id] = player_name
	player_labels[player_id].text = player_name

@rpc("any_peer", "call_local")
func start_game() -> void:
	if not is_inside_tree():
		return
		
	Global.player_order = Global.players
	
	if multiplayer.is_server():
		if game_started:
			return
		game_started = true
		start_game.rpc()

	get_tree().change_scene_to_file("res://Scenes/PlayerUI.tscn")
	
@rpc("any_peer", "call_local")
func hide_ui() -> void:
	host_game_button.visible = false
	join_game_button.visible = false
	player_name_h_box.visible = true
	server_iph_box.visible = false
	
	if multiplayer.get_unique_id() != 1:
		start_game_button.visible = false
