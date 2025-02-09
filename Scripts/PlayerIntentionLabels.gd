extends MarginContainer


@onready var label_container = $LabelVBoxContainer
var player_intentions = {}  # Dictionary to store player IDs and their labels


func _ready() -> void:
	update_players(Global.players)  # Assume Global.lobby_players stores player IDs

func update_players(player_list : Array) -> void:
	for player_id in player_list:
		var label = Label.new()
		label.text = "Player " + str(player_id) + ": No intention"
		label_container.add_child(label)
		player_intentions[player_id] = label

@rpc("any_peer", "call_local")
func update_intention(player_id: int, intention: String) -> void:
	print("Updating intention for: ", player_id, " to: ", intention)
	player_intentions[player_id].text = "Player " + str(player_id) + ": " + intention
