extends Panel

@onready var upgrade_attack_button = %UpgradeAttackButton
@onready var upgrade_gold_button = %UpgradeGoldButton
@onready var upgrade_cunning_button = %UpgradeCunningButton
@onready var exit_button = %ExitButton

var player_ui : CanvasLayer

signal shop_closed

func _ready() -> void:
	player_ui = get_parent()
	upgrade_attack_button.pressed.connect(_on_upgrade_attack_button_pressed)
	upgrade_gold_button.pressed.connect(_on_upgrade_gold_button_pressed)
	upgrade_cunning_button.pressed.connect(_on_upgrade_cunning_button_pressed)
	exit_button.pressed.connect(_on_exit_button_pressed)

func _on_upgrade_attack_button_pressed():
	if player_ui.gold_count > 0:
		player_ui.gold_count -= 1
		for i in range(player_ui.die_faces.size()):
			if player_ui.die_faces[i] == "⚔":
				player_ui.die_faces[i] = "⚔⚔"  # Increase potency
		print("Attack dice upgraded!")
		player_ui.gold_label.text = "💰 count: " + str(player_ui.gold_count)
	else:
		print("Not enough gold to upgrade attack dice.")

func _on_upgrade_gold_button_pressed():
	if player_ui.gold_count > 0:
		player_ui.gold_count -= 1
		for i in range(player_ui.die_faces.size()):
			if player_ui.die_faces[i] == "💰":
				player_ui.die_faces[i] = "💰💰"  # Increase potency
		print("Gold dice upgraded!")
		player_ui.gold_label.text = "💰 count: " + str(player_ui.gold_count)
	else:
		print("Not enough gold to upgrade gold dice.")

func _on_upgrade_cunning_button_pressed():
	if player_ui.gold_count > 0:
		player_ui.gold_count -= 1
		for i in range(player_ui.die_faces.size()):
			if player_ui.die_faces[i] == "🧠":
				player_ui.die_faces[i] = "🧠🧠"  # Increase potency
		print("Cunning dice upgraded!")
		player_ui.gold_label.text = "💰 count: " + str(player_ui.gold_count)
	else:
		print("Not enough gold to upgrade cunning dice.")

func _on_exit_button_pressed():
	emit_signal("shop_closed")
	hide()
