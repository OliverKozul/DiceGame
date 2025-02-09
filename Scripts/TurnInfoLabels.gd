extends MarginContainer


@onready var turn = %TurnLabel
@onready var roll_result = %RollResultLabel
@onready var action = %ActionLabel

var player_ui : CanvasLayer
var player_id : int


func initialize(ui : CanvasLayer, id : int) -> void:
	turn.text = "Current turn: 1"
	player_ui = ui
	player_id = id
