extends MarginContainer
class_name CombatDistribution


@onready var combat_distribution_vbox: VBoxContainer = $CombatDistributionVBox
const TARGET = preload("res://Scenes/Target.tscn")
const DROPDOWN_TARGET = preload("res://Scenes/DropdownTarget.tscn")

var player_ui: PlayerUI = null
var dropdown_target_ui: DropdownTarget = null


func initialize(ui: PlayerUI) -> void:
	player_ui = ui

func show_combat_ui(target: Enums.Target) -> void:
	var player_id = multiplayer.get_unique_id()
		
	if target != Enums.Target.NONE:
		dropdown_target_ui = DROPDOWN_TARGET.instantiate()
		var attack_label = Label.new()
		attack_label.label_settings = Global.default_label_settings
		attack_label.text = "Attack your enemies! (" + str(Global.player_info[player_id].combat) + "⚔)"
		attack_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		attack_label.vertical_alignment = HORIZONTAL_ALIGNMENT_CENTER
		combat_distribution_vbox.add_child(attack_label)
		combat_distribution_vbox.add_child(dropdown_target_ui)
		
	var sabotage_label = Label.new()
	sabotage_label.label_settings = Global.default_label_settings
	sabotage_label.text = "Sabotage your enemies!"
	sabotage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sabotage_label.vertical_alignment = HORIZONTAL_ALIGNMENT_CENTER
	combat_distribution_vbox.add_child(sabotage_label)
	
	for id in Global.players:
		if id != player_id:
			if target == Enums.Target.PLAYER:
				var player_text_hp = Global.player_names[id] + " (" + str(Global.player_info[id].hp) + "❤️ HP)"
				dropdown_target_ui.target_list.add_item(player_text_hp)
				
			var player_text_combat = Global.player_names[id] + " (" + str(Global.player_info[id].combat) + "⚔)"
			var target_ui = TARGET.instantiate()
			combat_distribution_vbox.add_child(target_ui)
			target_ui.target_name.text = player_text_combat
			
	if target == Enums.Target.MOB:
		dropdown_target_ui.target_list.custom_minimum_size = Vector2(250, len(Global.mobs) * 30)
		
		for mob in Global.mobs:
			var mob_text = mob.name + " (" + str(mob.hp) + "❤️ HP)"
			dropdown_target_ui.target_list.add_item(mob_text)
	elif target == Enums.Target.BOSS:
		var boss_text = Global.boss.name + " (" + str(Global.boss.current_hp) + "❤️ HP)"
		
		if Global.boss.current_hp <= 0:
			boss_text = Global.boss.name + " (Dead)"
			
		dropdown_target_ui.target_list.add_item(boss_text)
	
	if dropdown_target_ui != null and dropdown_target_ui.target_list.item_count == 1:
		dropdown_target_ui.target_list.select(0)
	
	var submit_button = Button.new()
	submit_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	submit_button.text = "Submit"
	submit_button.pressed.connect(_on_submit_button_pressed)
	combat_distribution_vbox.add_child(submit_button)
		
func _on_submit_button_pressed():
	var children = combat_distribution_vbox.get_children()
	var player_id = multiplayer.get_unique_id()
	var targets = extract_targets(children)
			
	var combat_total = 0
	var invalid_inputs = false
	
	for target in targets:
		if target["combat_taken"] < 0:
			invalid_inputs = true
			
		combat_total += target["combat_taken"]
	
	if (combat_total > Global.player_info[player_id].combat and combat_total != 0) or invalid_inputs:
		player_ui.current_player_label.text = "Bad inputs, try again!"
	else:
		player_ui.combat_manager.handle_combat(player_id, targets)
		
		for child in children:
			child.queue_free()
			
		player_ui.turn_manager.rpc_id(Global.host_id, "advance_to_next_player")
		
func extract_targets(children: Array) -> Array:
	var targets = []
	
	for child in children:
		if child is Target:
			var target = Global.player_names.find_key(child.target_name.text.split("(")[0].rstrip(" "))
			var combat_taken = child.target_combat_taken.text
			
			if combat_taken.is_valid_int() or combat_taken == "":
				combat_taken = int(combat_taken)
			else:
				combat_taken = -1
			
			if combat_taken != 0:
				targets.push_front({"target": target, "combat_taken": combat_taken, "type": "sabotage"})
		elif child is DropdownTarget:
			var selected_items = child.target_list.get_selected_items()
			
			if len(selected_items) > 0:
				var target = child.target_list.get_item_text(selected_items[0]).split("(")[0].rstrip(" ")
				var combat_taken = child.target_combat_taken.text
				
				if combat_taken.is_valid_int() or combat_taken == "":
					combat_taken = int(combat_taken)
				else:
					combat_taken = -1
				
				if Global.player_names.find_key(target) != null:
					target = Global.player_names.find_key(target)
				elif Global.enemy_ids.has(target):
					target = Global.enemy_ids[target]
				
				targets.push_back({"target": target, "combat_taken": combat_taken, "type": "damage"})
			
	return targets
