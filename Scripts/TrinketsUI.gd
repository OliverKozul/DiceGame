extends Panel
class_name TrinketsUI


var player_ui: PlayerUI
var player_id: int
var trinkets: Array = []

@onready var trinket_panel: PackedScene = preload("res://Scenes/TrinketPanel.tscn")
@onready var trinkets_v_box: VBoxContainer = %TrinketsVBox
@onready var exit_button: Button = %ExitButton

signal trinkets_ui_closed

func initialize(ui: PlayerUI, id: int) -> void:
	player_ui = ui
	player_id = id
	
	var trinket = trinket_panel.instantiate()
	trinkets_v_box.add_child(trinket)
	
	trinket.name_label.text = "Trinket Name"
	trinket.description_label.text =  "Trinket Description"
	
	exit_button.pressed.connect(_on_exit_button_pressed)

func open() -> void:
	for i in range(len(trinkets), len(player_ui.trinket_manager.trinkets)):
		var trinket = trinket_panel.instantiate()
		trinkets_v_box.add_child(trinket)
		trinket.name_label.text = player_ui.trinket_manager.trinkets[i].name
		trinket.description_label.text = player_ui.trinket_manager.trinkets[i].description
		trinkets.append(trinket)
			
	show()

func _on_exit_button_pressed() -> void:
	emit_signal("trinkets_ui_closed")
	hide()
