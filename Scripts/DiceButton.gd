extends CanvasLayer

@onready var next_turn_button = %NextTurnButton
@onready var roll_button = %RollButton
@onready var attack_button = %AttackButton

@onready var turn_label = %TurnLabel
@onready var roll_result_label = %RollResultLabel
@onready var attack_label = %AttackLabel
@onready var gold_label = %GoldLabel


var die_faces = ["⚔", "⚔", "💰", "💰", "🎁", "🎁"]
var roll_result : String = ""
var gold_count : int = 0

func _ready():
	roll_result_label.text = str(Global.current_turn)
	roll_button.pressed.connect(_on_roll_button_pressed)
	next_turn_button.pressed.connect(_on_next_turn_button_pressed)
	attack_button.pressed.connect(_on_attack_button_pressed)

func _on_roll_button_pressed():
	roll_result = die_faces[randi() % die_faces.size()]
	roll_result_label.text = "You rolled: " + roll_result
	
	match roll_result:
		"💰":
			gold_count += 1
			
	gold_label.text = "💰 count: " + str(gold_count)
	
func _on_next_turn_button_pressed():
	Global.current_turn += 1
	turn_label.text = "Current turn: " + str(Global.current_turn)
	
func _on_attack_button_pressed():
	if roll_result == "⚔":
		attack_label.text = "You killed the enemy."
	else:
		attack_label.text = "You didn't roll an attack, try something else."
