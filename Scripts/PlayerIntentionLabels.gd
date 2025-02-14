extends MarginContainer


@onready var label_container = $LabelVBox
var player_intentions = {}


func _ready() -> void:
	update_players(Global.players)

func update_players(player_list: Array) -> void:
	for player_id in player_list:
		var label = Label.new()
		label.text = "Player " + str(player_id) + ": No intention"
		label_container.add_child(label)
		player_intentions[player_id] = label

@rpc("any_peer", "call_local")
func update_intention(player_id: int, intention: String) -> void:
	player_intentions[player_id].text = "Player " + str(player_id) + ": " + intention
