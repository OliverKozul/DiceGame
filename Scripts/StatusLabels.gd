extends VBoxContainer


@onready var hp = %HPLabel
@onready var gold = %GoldLabel
@onready var cunning = %CunningLabel
@onready var trinkets = %TrinketsLabel

var player_ui : CanvasLayer
var player_id : int

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	SignalBus.connect("update_hp_label", _on_update_hp_label)
	SignalBus.connect("update_gold_label", _on_update_gold_label)
	SignalBus.connect("update_cunning_label", _on_update_cunning_label)
	SignalBus.connect("update_trinkets_label", _on_update_trinkets_label)

func initialize(ui : CanvasLayer, id : int) -> void:
	player_id = id
	player_ui = ui
	player_ui.connect("update_all_status_labels", _on_update_all_status_labels)
	_on_update_all_status_labels()
	
func _on_update_all_status_labels() -> void:
	_on_update_hp_label()
	_on_update_gold_label()
	_on_update_cunning_label()
	_on_update_trinkets_label()

func _on_update_hp_label() -> void:
	hp.text = "❤️ HP: " + str(Global.player_info[player_id].hp)
	
func _on_update_gold_label() -> void:
	gold.text = "💰 count: " + str(Global.player_info[player_id].gold)
	
func _on_update_cunning_label() -> void:
	cunning.text = "🧠 count: " + str(Global.player_info[player_id].cunning)
	
func _on_update_trinkets_label() -> void:
	trinkets.text = "Trinkets: " + str(Global.player_info[player_id].trinkets)
