extends MarginContainer


@onready var turn = %TurnLabel
@onready var roll_result = %RollResultLabel
@onready var action = %ActionLabel

var player_ui : CanvasLayer
var player_id : int

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	turn.text = "Current turn: 1"

func initialize(ui : CanvasLayer, id : int):
	player_ui = ui
	player_id = id

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass
