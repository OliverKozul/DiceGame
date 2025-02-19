extends MarginContainer
class_name PlayerIntentionLabels


var player_ui: PlayerUI
@onready var label_container = %PlayerInfoVBox
var player_intentions = {}
var labels = []
var buttons = []


func initialize(ui: PlayerUI) -> void:
	player_ui = ui
	
func _ready() -> void:
	for i in len(Global.player_order):
		var hbox = HBoxContainer.new()
		var label = Label.new()
		var button = Button.new()
		button.text = "Show"
		hbox.add_theme_constant_override("separation", 8)
		
		hbox.add_child(button)
		buttons.append(button)
		
		hbox.add_child(label)
		labels.append(label)
		
		label_container.add_child(hbox)
		
		player_intentions[Global.player_order[i]] = i

@rpc("any_peer", "call_local")
func update_players() -> void:
	for i in len(Global.player_order):
		var player_id = Global.player_order[i]
		var reverse_index = len(Global.player_order) - i - 1
		
		player_intentions[player_id] = reverse_index
		labels[player_intentions[player_id]].text = str(Global.player_names[player_id])
		
		if player_id == multiplayer.get_unique_id():
			labels[player_intentions[Global.player_order[i]]].text += " (You) "
			
		labels[player_intentions[player_id]].text += ": No intention"
		
		for id in Global.player_order: 
			if buttons[reverse_index].pressed.is_connected(player_ui.player_info_uis[id].open):
				buttons[reverse_index].pressed.disconnect(player_ui.player_info_uis[id].open)
			
		buttons[reverse_index].pressed.connect(player_ui.player_info_uis[player_id].open)

@rpc("any_peer", "call_local")
func update_intention(player_id: int, intention: String) -> void:
	labels[player_intentions[player_id]].text = str(Global.player_names[player_id])
	
	if player_id == multiplayer.get_unique_id():
		labels[player_intentions[player_id]].text += " (You) "
		
	labels[player_intentions[player_id]].text += ": " + intention
