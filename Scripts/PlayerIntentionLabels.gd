extends MarginContainer
class_name PlayerIntentionLabels


@onready var label_container = $LabelVBox
var player_intentions = {}
var labels = []


func _ready() -> void:
	for i in len(Global.player_order):
		var label = Label.new()
		label_container.add_child(label)
		player_intentions[Global.player_order[i]] = i
		labels.append(label)
		
	update_players()

@rpc("any_peer", "call_local")
func update_players() -> void:
	for i in len(Global.player_order):
		var player_id = Global.player_order[i]
		player_intentions[player_id] = len(Global.player_order) - i - 1
		labels[player_intentions[player_id]].text = str(Global.player_names[player_id])
		
		if player_id == multiplayer.get_unique_id():
			labels[player_intentions[Global.player_order[i]]].text += " (You) "
			
		labels[player_intentions[player_id]].text += ": No intention"

@rpc("any_peer", "call_local")
func update_intention(player_id: int, intention: String) -> void:
	labels[player_intentions[player_id]].text = str(Global.player_names[player_id]) + ": " + intention
