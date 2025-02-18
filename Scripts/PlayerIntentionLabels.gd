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
		player_intentions[Global.player_order[i]] = len(Global.player_order) - i - 1
		labels[player_intentions[Global.player_order[i]]].text = str(Global.player_names[Global.player_order[i]]) + ": No intention"

@rpc("any_peer", "call_local")
func update_intention(player_id: int, intention: String) -> void:
	labels[player_intentions[player_id]].text = str(Global.player_names[player_id]) + ": " + intention
