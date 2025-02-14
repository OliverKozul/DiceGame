extends MarginContainer


@onready var combat_distribution_vbox = $CombatDistributionVBox
const TARGET = preload("res://Scenes/Target.tscn")
const DROPDOWN_TARGET = preload("res://Scenes/DropdownTarget.tscn")

var player_ui: CanvasLayer
var dropdown_target_ui: DropdownTarget


func initialize(ui: CanvasLayer) -> void:
	player_ui = ui

func show_combat_ui(target: Enums.Target) -> void:
	var player_id = multiplayer.get_unique_id()
		
	if target != Enums.Target.NONE:
		dropdown_target_ui = DROPDOWN_TARGET.instantiate()
		combat_distribution_vbox.add_child(dropdown_target_ui)
		
	var label = Label.new()
	label.text = "Sabotage your enemies!"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = HORIZONTAL_ALIGNMENT_CENTER
	combat_distribution_vbox.add_child(label)
	
	for id in Global.players:
		if id != player_id:
			if target == Enums.Target.PLAYER:
				dropdown_target_ui.target_list.add_item(str(id))
				
			var target_ui = TARGET.instantiate()
			combat_distribution_vbox.add_child(target_ui)
			target_ui.target_name.text = str(id)
			
	if target == Enums.Target.MOB:
		dropdown_target_ui.target_list.add_item("Mob")
	elif target == Enums.Target.BOSS:
		dropdown_target_ui.target_list.add_item("Boss")
	
	if dropdown_target_ui and dropdown_target_ui.target_list.item_count == 1:
		dropdown_target_ui.target_list.select(0)
	
	var submit_button = Button.new()
	submit_button.text = "Submit"
	submit_button.pressed.connect(_on_submit_button_pressed)
	combat_distribution_vbox.add_child(submit_button)
		
func _on_submit_button_pressed():
	var children = combat_distribution_vbox.get_children()
	var player_id = multiplayer.get_unique_id()
	var targets = extract_targets(children)
			
	var combat_total = 0
	var has_negative = false
	
	for target in targets:
		if target[1] < 0:
			has_negative = true
			
		combat_total += target[1]
	
	if (combat_total > Global.player_info[player_id].combat and combat_total != 0) or has_negative:
		player_ui.current_player_label.text = "Bad inputs, try again!"
	else:
		player_ui.combat_manager.handle_combat(player_id, targets)
		
		for child in children:
			child.queue_free()
			
		player_ui.turn_manager.advance_to_next_player()
		
func extract_targets(children: Array) -> Array:
	var targets = []
	
	for child in children:
		if child is Target:
			var target = child.target_name.text
			var combat_taken = int(child.target_combat_taken.text)
			
			targets.push_front([target, combat_taken, "sabotage"])
		elif child is DropdownTarget:
			var selected_items = child.target_list.get_selected_items()
			if len(selected_items) != 0:
				var target = child.target_list.get_item_text(selected_items[0])
				var combat_taken = int(child.target_combat_taken.text)
				
				targets.push_back([target, combat_taken, "damage"])
			
	return targets
