extends CanvasLayer

var peer = ENetMultiplayerPeer.new()

@onready var status_label = %ConnectionStatusLabel
@onready var ip_input = %ServerIPTextEdit

@onready var host_game_button = %HostGameButton
@onready var join_game_button = %JoinGameButton
@onready var start_game_button = %StartGameButton

const PORT = 7777
var game_started : bool = false

func _ready():
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	
	host_game_button.pressed.connect(_on_host_button_pressed)
	join_game_button.pressed.connect(_on_join_button_pressed)
	start_game_button.pressed.connect(_on_start_game_pressed)

# Host a Game
func _on_host_button_pressed():
	peer.create_server(PORT, 4)  # Max 4 players
	multiplayer.multiplayer_peer = peer
	status_label.text = "Hosting game..."
	print("Server started on port ", PORT)

# Join a Game
func _on_join_button_pressed():
	var ip = ip_input.text.strip_edges()
	if ip.is_empty():
		status_label.text = "Enter a valid IP."
		return
	
	peer.create_client(ip, PORT)
	multiplayer.multiplayer_peer = peer
	status_label.text = "Joining server..."
	print("Attempting to connect to ", ip)

# Connection Success
func _on_peer_connected(id):
	print("Player ", id, " joined.")

func _on_peer_disconnected(id):
	print("Player ", id, " left.")

func _on_connected_to_server():
	status_label.text = "Connected to server!"
	print("Connected to server!")

func _on_connection_failed():
	status_label.text = "Connection failed."
	print("Failed to connect.")

func _on_start_game_pressed():
	if multiplayer.is_server():
		start_game.rpc()  # Broadcast to all players

@rpc("any_peer", "call_local")
func start_game():
	if not is_inside_tree():
		print("Error: Node is not inside the scene tree yet!")
		return

	if multiplayer.is_server():
		if game_started:
			return  # Prevent multiple calls
		game_started = true
		start_game.rpc()  # Broadcast to all clients

	print("Changing scene for peer:", multiplayer.get_unique_id())
	get_tree().change_scene_to_file("res://Scenes/PlayerUI.tscn")
