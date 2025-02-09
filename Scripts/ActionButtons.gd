extends Control


@onready var roll = %RollButton
@onready var attack_player = %AttackPlayerButton
@onready var attack_mobs = %AttackMobsButton
@onready var attack_boss = %AttackBossButton
@onready var shop = %ShopButton
@onready var skip = %SkipButton

var player_ui : CanvasLayer
var player_id : int

	
func initialize(ui : CanvasLayer, id : int) -> void:
	player_ui = ui
	player_id = id
	
	roll.pressed.connect(player_ui.sync_manager._on_roll_button_pressed)
	attack_player.pressed.connect(player_ui.action_manager._on_attack_player_button_pressed)
	attack_mobs.pressed.connect(player_ui.action_manager._on_attack_mobs_button_pressed)
	attack_boss.pressed.connect(player_ui.action_manager._on_attack_boss_button_pressed)
	shop.pressed.connect(player_ui.action_manager._on_shop_button_pressed)
	skip.pressed.connect(player_ui.action_manager._on_skip_button_pressed)
	
	show_buttons("roll")

func show_buttons(phase : String) -> void:
	roll.visible = true if phase == "roll" else false
	attack_player.visible = false if phase == "roll" or phase == "wait" else true
	attack_mobs.visible = false if phase == "roll" or phase == "wait" else true
	attack_boss.visible = false if phase == "roll" or phase == "wait" else true
	shop.visible = false if phase == "roll" or phase == "wait" else true
	skip.visible = false if phase == "roll" or phase == "wait" else true
