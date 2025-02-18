extends VBoxContainer
class_name StatusLabels


@onready var hp = %HPLabel
@onready var gold = %GoldLabel
@onready var combat = %CombatLabel
@onready var cunning = %CunningLabel
@onready var trinkets = %TrinketsLabel

var player_ui: PlayerUI
var player_id: int


func initialize(ui: PlayerUI, id: int) -> void:
	player_id = id
	player_ui = ui
	player_ui.connect("update_all_status_labels", _on_update_all_status_labels)
	_on_update_all_status_labels()
	
func _on_update_all_status_labels() -> void:
	_on_update_hp_label()
	_on_update_gold_label()
	_on_update_combat_label()
	_on_update_cunning_label()
	_on_update_trinkets_label()

func _on_update_hp_label() -> void:
	hp.text = "❤️ HP: " + str(Global.player_info[player_id].hp)
	
func _on_update_gold_label() -> void:
	gold.text = "💰 count: " + str(Global.player_info[player_id].gold)
	
func _on_update_combat_label() -> void:
	combat.text = "⚔ count: " + str(Global.player_info[player_id].combat)
	
func _on_update_cunning_label() -> void:
	cunning.text = "🧠 count: " + str(Global.player_info[player_id].cunning)
	
func _on_update_trinkets_label() -> void:
	trinkets.text = "Trinkets: " + str(Global.player_info[player_id].trinkets)
