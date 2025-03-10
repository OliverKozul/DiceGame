extends Panel
class_name Shop


@onready var upgrade_buttons = {
	"attack": %UpgradeAttackButton,
	"gold": %UpgradeGoldButton,
	"cunning": %UpgradeCunningButton
}
@onready var exit_button = %ExitButton
@onready var gold_label: Label = %GoldLabel

var player_ui: PlayerUI
var player_id: int
var can_sabotage: bool = false

var resource_upgrade_counts: Dictionary = {
	"attack": 0, 
	"gold": 0, 
	"cunning": 0
}

signal shop_closed


func _ready() -> void:
	player_ui = get_parent()
	
	for key in upgrade_buttons.keys():
		upgrade_buttons[key].pressed.connect(Callable(self, "_on_upgrade_button_pressed").bind(key))
		
	exit_button.pressed.connect(_on_exit_button_pressed)

func initialize(ui: PlayerUI, id: int) -> void:
	player_ui = ui
	player_id = id

func update_button_label(type: String) -> void:
	upgrade_buttons[type].text = "Upgrade " + type.capitalize() + " Faces (" + str(resource_upgrade_counts[type] + 1) + " 💰)"
	
func open(has_combat: bool) -> void:
	gold_label.text = "💰 Gold: " + str(Global.player_info[player_id].gold)
	can_sabotage = has_combat
	
	for type in upgrade_buttons.keys():
		update_button_label(type)
		
	show()

func _on_upgrade_button_pressed(type: String) -> void:
	var upgrade_cost = resource_upgrade_counts[type] + 1
	
	if Global.player_info[player_id].gold >= upgrade_cost:
		Global.player_info[player_id].gold -= upgrade_cost
		resource_upgrade_counts[type] += 1
		update_button_label(type)
		
		for die in Global.player_info[player_id].die_face_values:
			die[get_die_face(type)] += 1
			
		print(type.capitalize() + " dice upgraded!")
		player_ui.status_labels.gold.text = "💰 Gold: " + str(Global.player_info[player_id].gold)
		gold_label.text = player_ui.status_labels.gold.text
		player_ui.sync_manager.rpc("sync_player_info", player_id, Global.player_info[player_id])
	else:
		print("Not enough gold to upgrade " + type + " dice.")

func get_die_face(type: String) -> String:
	match type:
		"attack":
			return "⚔"
		"gold":
			return "💰"
		"cunning":
			return "🧠"
			
	return ""

func _on_exit_button_pressed() -> void:
	player_ui.sync_manager.rpc("sync_player_info", player_id, Global.player_info[player_id])
	
	if not can_sabotage:
		player_ui.turn_manager.rpc_id(Global.host_id, "advance_to_next_player")
		
	emit_signal("shop_closed")
	hide()
