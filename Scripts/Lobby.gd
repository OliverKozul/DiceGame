extends CanvasLayer


@onready var status_label = %ConnectionStatusLabel
@onready var ip_input = %ServerIPTextEdit

@onready var host_game_button = %HostGameButton
@onready var join_game_button = %JoinGameButton
@onready var start_game_button = %StartGameButton

const PORT: int = 7777
var peer = ENetMultiplayerPeer.new()
var game_started: bool = false


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	
	host_game_button.pressed.connect(_on_host_button_pressed)
	join_game_button.pressed.connect(_on_join_button_pressed)
	start_game_button.pressed.connect(_on_start_game_pressed)
	rpc("update_player_array", multiplayer.get_unique_id())

# Host a Game
func _on_host_button_pressed() -> void:
	peer.create_server(PORT, 4)  # Max 4 players
	multiplayer.multiplayer_peer = peer
	status_label.text = "Hosting game..."
	print("Server started on port ", PORT)

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

# Connection Success
func _on_peer_connected(id: int) -> void:
	print("Player ", id, " joined.")
	rpc("update_player_array", id)

func _on_peer_disconnected(id: int) -> void:
	print("Player ", id, " left.")

func _on_connected_to_server() -> void:
	status_label.text = "Connected to server!"
	print("Connected to server!")

func _on_connection_failed() -> void:
	status_label.text = "Connection failed."
	print("Failed to connect.")

func _on_start_game_pressed() -> void:
	if multiplayer.is_server():
		start_game.rpc()  # Broadcast to all players

@rpc("any_peer", "call_local")
func update_player_array(id: int):
	if not Global.players.has(id):
		Global.players.append(id)
		Global.players.sort()

@rpc("any_peer", "call_local")
func start_game() -> void:
	if not is_inside_tree():
		return

	if multiplayer.is_server():
		if game_started:
			return  # Prevent multiple calls
		game_started = true
		start_game.rpc()  # Broadcast to all clients

	get_tree().change_scene_to_file("res://Scenes/PlayerUI.tscn")
