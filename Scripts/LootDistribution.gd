class_name LootDistribution
extends MarginContainer


@onready var loot_list: ItemList = %LootList
@onready var item_description_label: Label = %ItemDescriptionLabel
@onready var submit_button: Button = %SubmitButton

var player_ui: PlayerUI


func initialize(ui: PlayerUI) -> void:
	player_ui = ui
	submit_button.pressed.connect(_on_submit_button_pressed)
	loot_list.item_clicked.connect(_on_item_clicked)

func reset() -> void:
	loot_list.clear()
	
@rpc("any_peer", "call_local", "reliable")
func allow_item_choice() -> void:
	for item in Global.boss_drops:
		loot_list.add_item(item.name)
		
	loot_list.select(0)
	loot_list.custom_minimum_size = Vector2(150, loot_list.item_count * 30)
	item_description_label.text = Global.boss_drops[0].description
	show()
		
func _on_submit_button_pressed() -> void:
	var player_id = multiplayer.get_unique_id()
	var selected_item_index = loot_list.get_selected_items()[0]
	
	if Global.selected_item_indices.has(selected_item_index):
		Global.selected_item_indices[selected_item_index].append(player_id)
	else:
		Global.selected_item_indices[selected_item_index] = [player_id]
		
	player_ui.sync_manager.rpc("sync_selected_item_indices", Global.selected_item_indices)
	player_ui.turn_manager.rpc_id(Global.host_id, "advance_to_next_player")
	hide()
		
func _on_item_clicked(index: int, _at_position: Vector2, mouse_button_index: int) -> void:
	if mouse_button_index != 1:
		return
		
	var item = loot_list.get_item_text(index)
	
	for drop in Global.boss_drops:
		if item == drop.name:
			item_description_label.text = drop.description
			break
