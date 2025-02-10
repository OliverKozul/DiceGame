extends MarginContainer


@onready var combat_distribution_vbox = $CombatDistributionVBox
const TARGET = preload("res://Scenes/Target.tscn")
const DROPDOWN_TARGET = preload("res://Scenes/DropdownTarget.tscn")


func show_combat_ui(player_id : int, target: Enums.Target) -> void:
	if player_id == multiplayer.get_unique_id():
		var dropdown_target_ui
		
		if target != Enums.Target.NONE:
			dropdown_target_ui = DROPDOWN_TARGET.instantiate()
			combat_distribution_vbox.add_child(dropdown_target_ui)
			
		var label = Label.new()
		label.text = "Sabotage your enemies!"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = HORIZONTAL_ALIGNMENT_CENTER
		combat_distribution_vbox.add_child(label)
		
		for id in Global.players:
			if id != multiplayer.get_unique_id():
				if target == Enums.Target.PLAYER:
					dropdown_target_ui.target_list.add_item(str(id))
					
				var target_ui = TARGET.instantiate()
				combat_distribution_vbox.add_child(target_ui)
				target_ui.target_name.text = str(id)
				
		if target == Enums.Target.MOB:
			dropdown_target_ui.target_list.add_item("Mob")
			dropdown_target_ui.target_list.select(0)
		elif target == Enums.Target.BOSS:
			dropdown_target_ui.target_list.add_item("Boss")
			dropdown_target_ui.target_list.select(0)
