extends Panel
class_name PlayerInfoUI


var player_ui: PlayerUI
var player_id: int
var player_info_labels: Array = []
@onready var player_info_v_box: VBoxContainer = %PlayerInfoVBox
@onready var items_h_box: HBoxContainer = %ItemsHBox

var dice: Array = []
var dice_panel: PackedScene = load("res://Scenes/DicePanel.tscn")
@onready var dice_v_box: VBoxContainer = %DiceVBox
@onready var exit_button: Button = %ExitButton
signal dice_ui_closed

var trinkets: Array = []
var trinket_panel: PackedScene = load("res://Scenes/TrinketPanel.tscn")
@onready var trinkets_v_box: VBoxContainer = %TrinketsVBox
signal trinkets_ui_closed


func initialize(ui: PlayerUI, id: int) -> void:
	player_ui = ui
	player_id = id
	
	create_player_info_ui(id)
	create_die_ui()
	create_trinket_ui()
	
	exit_button.pressed.connect(_on_exit_button_pressed)

func create_player_info_ui(id: int) -> void:
	add_player_label("Name: ", Global.player_names[id])
	add_player_label("❤️ HP: ", str(Global.player_info[id].hp))
	add_player_label("💰 Gold: ", str(Global.player_info[id].gold))
	add_player_label("⚔ Combat: ", str(Global.player_info[id].combat))
	add_player_label("🧠 Cunning: ", str(Global.player_info[id].cunning))
	
	player_info_v_box.move_child(items_h_box, player_info_v_box.get_child_count() - 1)

func add_player_label(text: String, info: String) -> void:
	var label = Label.new()
	label.text = text + info
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = HORIZONTAL_ALIGNMENT_CENTER
	player_info_v_box.add_child(label)
	player_info_labels.append(label)
	
func create_die_ui() -> void:
	var die = dice_panel.instantiate()
	dice_v_box.add_child(die)
	
	die.type_label.text = "Die Type"
	die.sides_label.text =  "Die Sides"
	die.values_label.text = "Side Values"
	
func create_trinket_ui() -> void:
	var trinket = trinket_panel.instantiate()
	trinkets_v_box.add_child(trinket)
	
	trinket.name_label.text = "Trinket Name"
	trinket.description_label.text =  "Trinket Description"
	
func open() -> void:
	player_info_labels[0].text = "Name: " + Global.player_names[player_id]
	player_info_labels[1].text = "❤️ HP: " + str(Global.player_info[player_id].hp)
	player_info_labels[2].text = "💰 Gold: " + str(Global.player_info[player_id].gold)
	player_info_labels[3].text = "⚔ Combat: " + str(Global.player_info[player_id].combat)
	player_info_labels[4].text = "🧠 Cunning: " + str(Global.player_info[player_id].cunning)
	
	for i in len(Global.player_info[player_id].die_faces):
		if i < len(dice):
			update_die_info(i)
			
		else:
			var die = dice_panel.instantiate()
			dice_v_box.add_child(die)
			dice.append(die)
			update_die_info(i)
			
	for i in range(len(trinkets), len(Global.player_info[player_id].trinkets)):
		var trinket = trinket_panel.instantiate()
		
		trinkets_v_box.add_child(trinket)
		trinket.name_label.text = Global.player_info[player_id].trinkets[i].name
		trinket.description_label.text = Global.player_info[player_id].trinkets[i].description
		trinkets.append(trinket)
	
	show()
	
func update_die_info(index: int) -> void:
	dice[index].type_label.text = "D" + str(len(Global.player_info[player_id].die_faces[index]))
	dice[index].sides_label.text =  str(Global.player_info[player_id].die_faces[index])
	dice[index].values_label.text = str(Global.player_info[player_id].die_face_values[index])
	
func _on_exit_button_pressed() -> void:
	emit_signal("dice_ui_closed")
	emit_signal("trinkets_ui_closed")
	hide()
