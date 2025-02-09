extends Panel

@onready var upgrade_attack_button = %UpgradeAttackButton
@onready var upgrade_gold_button = %UpgradeGoldButton
@onready var upgrade_cunning_button = %UpgradeCunningButton
@onready var exit_button = %ExitButton

var player_ui : CanvasLayer
var player_id : int

signal shop_closed

func _ready() -> void:
	player_ui = get_parent()
	upgrade_attack_button.pressed.connect(_on_upgrade_attack_button_pressed)
	upgrade_gold_button.pressed.connect(_on_upgrade_gold_button_pressed)
	upgrade_cunning_button.pressed.connect(_on_upgrade_cunning_button_pressed)
	exit_button.pressed.connect(_on_exit_button_pressed)

func initialize(ui : CanvasLayer, id : int):
	player_ui = ui
	player_id = id

func _on_upgrade_attack_button_pressed():
	if Global.player_info[player_id].gold > 0:
		Global.player_info[player_id].gold -= 1
		Global.player_info[player_id].die_face_values["⚔"] += 1  # Increase value
		print("Attack dice upgraded!")
		player_ui.status_labels.gold.text = "💰 count: " + str(Global.player_info[player_id].gold)
	else:
		print("Not enough gold to upgrade attack dice.")

func _on_upgrade_gold_button_pressed():
	if Global.player_info[player_id].gold > 0:
		Global.player_info[player_id].gold -= 1
		Global.player_info[player_id].die_face_values["💰"] += 1  # Increase value
		print("Gold dice upgraded!")
		player_ui.status_labels.gold.text = "💰 count: " + str(Global.player_info[player_id].gold)
	else:
		print("Not enough gold to upgrade gold dice.")

func _on_upgrade_cunning_button_pressed():
	if Global.player_info[player_id].gold > 0:
		Global.player_info[player_id].gold -= 1
		Global.player_info[player_id].die_face_values["🧠"] += 1  # Increase value
		print("Cunning dice upgraded!")
		player_ui.status_labels.gold.text = "💰 count: " + str(Global.player_info[player_id].gold)
	else:
		print("Not enough gold to upgrade cunning dice.")

func _on_exit_button_pressed():
	emit_signal("shop_closed")
	hide()
