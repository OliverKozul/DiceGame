extends Control
class_name Buttons


@onready var buttons = {
	"roll": %RollButton,
	"attack_player": %AttackPlayerButton,
	"attack_mobs": %AttackMobsButton,
	"attack_boss": %AttackBossButton,
	"shop": %ShopButton,
	"skip": %SkipButton,
}

var player_ui: PlayerUI


func initialize(ui: PlayerUI) -> void:
	player_ui = ui
	
	buttons["roll"].pressed.connect(player_ui.button_manager._on_roll_button_pressed)
	buttons["attack_player"].pressed.connect(player_ui.button_manager._on_attack_player_button_pressed)
	buttons["attack_mobs"].pressed.connect(player_ui.button_manager._on_attack_mobs_button_pressed)
	buttons["attack_boss"].pressed.connect(player_ui.button_manager._on_attack_boss_button_pressed)
	buttons["shop"].pressed.connect(player_ui.button_manager._on_shop_button_pressed)
	buttons["skip"].pressed.connect(player_ui.button_manager._on_skip_button_pressed)
	
	buttons["attack_mobs"].text += (" (" + str(Global.mob.hp) + " HP)")
	buttons["attack_boss"].text += (" (" + str(Global.boss.max_hp) + " HP)")
	
	show_buttons("roll")

func show_buttons(phase: String) -> void:
	var visibility = {
		"roll": phase == "roll",
		"attack_player": phase == "intention" or phase == "action",
		"attack_mobs": phase == "intention" or phase == "action",
		"attack_boss": phase == "intention" or phase == "action",
		"shop": phase == "intention" or phase == "action",
		"skip": phase == "intention" or phase == "action",
	}
	
	for button_name in buttons.keys():
		buttons[button_name].visible = visibility[button_name]
