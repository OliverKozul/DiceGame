extends Panel
class_name DiceUI


var player_ui: PlayerUI
var player_id: int
var dice: Array = []

@onready var dice_panel: PackedScene = preload("res://Scenes/DicePanel.tscn")
@onready var dice_v_box: VBoxContainer = %DiceVBox
@onready var exit_button: Button = %ExitButton

signal dice_ui_closed

func initialize(ui: PlayerUI, id: int) -> void:
	player_ui = ui
	player_id = id
	
	var die = dice_panel.instantiate()
	dice_v_box.add_child(die)
	
	die.type_label.text = "Die Type"
	die.sides_label.text =  "Die Sides"
	die.values_label.text = "Side Values"
	
	exit_button.pressed.connect(_on_exit_button_pressed)

func open() -> void:
	for i in len(Global.player_info[player_id].die_faces):
		if i < len(dice):
			update_die_info(i)
			
		else:
			var die = dice_panel.instantiate()
			dice_v_box.add_child(die)
			dice.append(die)
			update_die_info(i)
			
	show()
	
func update_die_info(index: int) -> void:
	dice[index].type_label.text = "D" + str(len(Global.player_info[player_id].die_faces[index]))
	dice[index].sides_label.text =  str(Global.player_info[player_id].die_faces[index])
	dice[index].values_label.text = str(Global.player_info[player_id].die_face_values[index])
	
func _on_exit_button_pressed() -> void:
	emit_signal("dice_ui_closed")
	hide()
