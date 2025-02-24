extends Node


var phase_dict: Dictionary = {
	"roll": _on_roll_phase,
	"intention": _on_intention_phase,
	"action": _on_action_phase,
	"resolve": _on_resolve_phase,
	"loot_distribution": _on_loot_distribution_phase,
	"bid": _on_bid_phase,
}

signal update_hp_label()
signal update_gold_label()
signal update_combat_label()
signal update_cunning_label()
signal update_trinkets_label()

signal sync_player_info(player_id: int)
signal sync_roll_result(player_id: int, roll_result: String)

signal _on_new_turn()
signal _on_roll_phase()
signal _on_intention_phase()
signal _on_action_phase()
signal _on_resolve_phase()
signal _on_loot_distribution_phase()
signal _on_bid_phase()

signal _on_combat_roll(player_id: int, combat_amount: int)
signal _on_gold_roll(player_id: int, gold_amount: int)
signal _on_cunning_roll(player_id: int, cunning_amount: int)

signal _on_any_attacked(player_id: int, combat_amount: int)
signal _on_player_attacked(player_id: int, combat_amount: int)
signal _on_mob_attacked(player_id: int, combat_amount: int, mob_id: int)
signal _on_boss_attacked(player_id: int, combat_amount: int)

signal _on_player_defeated(attacker_id: int, defeated_id: int, combat_amount: int)
signal _on_mob_defeated(mob_id: int, player_id: int, combat_amount: int)
signal _on_boss_defeated(player_id: int, combat_amount: int)

signal _on_player_sabotaged(attacker_id: int, sabotaged_id:int, combat_amount: int)

signal _on_boss_attack(player_id: int)
signal _on_mob_attack(player_id: int, mob_id: int)
