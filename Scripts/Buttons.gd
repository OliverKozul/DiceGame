extends Control


@onready var roll = %RollButton
@onready var attack_player = %AttackPlayerButton
@onready var attack_mobs = %AttackMobsButton
@onready var attack_boss = %AttackBossButton
@onready var shop = %ShopButton
@onready var skip = %SkipButton
@onready var resolve = %ResolveButton

var player_ui : CanvasLayer
var player_id : int

	
func initialize(ui : CanvasLayer, id : int) -> void:
	player_ui = ui
	player_id = id
	
	roll.pressed.connect(player_ui.button_manager._on_roll_button_pressed)
	attack_player.pressed.connect(player_ui.button_manager._on_attack_player_button_pressed)
	attack_mobs.pressed.connect(player_ui.button_manager._on_attack_mobs_button_pressed)
	attack_boss.pressed.connect(player_ui.button_manager._on_attack_boss_button_pressed)
	shop.pressed.connect(player_ui.button_manager._on_shop_button_pressed)
	skip.pressed.connect(player_ui.button_manager._on_skip_button_pressed)
	resolve.pressed.connect(player_ui.button_manager._on_resolve_button_pressed)
	
	show_buttons("roll")

func show_buttons(phase : String) -> void:
	print(multiplayer.get_unique_id(), " ", phase)
	roll.visible = true if phase == "roll" else false
	attack_player.visible = true if phase == "intention" or phase == "action" else false
	attack_mobs.visible = true if phase == "intention" or phase == "action" else false
	attack_boss.visible = true if phase == "intention" or phase == "action" else false
	shop.visible = true if phase == "intention" or phase == "action" else false
	skip.visible = true if phase == "intention" or phase == "action" else false
	resolve.visible = true if phase == "resolve" else false
