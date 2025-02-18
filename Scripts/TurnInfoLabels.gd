extends MarginContainer
class_name TurnInfoLabels


@onready var turn = %TurnLabel
@onready var roll_results: Dictionary = {}
@onready var roll_results_v_box: VBoxContainer = %RollResultsVBox
@onready var action = %ActionLabel

var player_ui: PlayerUI


func initialize(ui: PlayerUI) -> void:
	turn.text = "Current turn: 1"
	player_ui = ui
	
	for player_id in Global.players:
		var label = Label.new()
		label.text = "Player " + Global.player_names[player_id] + " rolled: N/A"
		roll_results_v_box.add_child(label)
		roll_results[player_id] = label
