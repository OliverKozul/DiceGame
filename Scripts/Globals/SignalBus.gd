extends Node


signal update_hp_label()
signal update_gold_label()
signal update_combat_label()
signal update_cunning_label()
signal update_trinkets_label()

signal sync_player_info(player_id: int)
signal sync_roll_result(player_id: int, roll_result: String)

signal _on_combat_roll(player_id: int, combat_amount: int)
signal _on_gold_roll(player_id: int, gold_amount: int)
signal _on_cunning_roll(player_id: int, cunning_amount: int)

signal _on_player_attacked(player_id: int, combat_amount: int)
signal _on_mob_attacked(player_id: int, combat_amount: int)
signal _on_boss_attacked(player_id: int, combat_amount: int)

signal _on_player_defeated(attacker_id: int, defeated_id: int, combat_amount: int)
signal _on_mob_defeated(player_id: int, combat_amount: int)
signal _on_boss_defeated(player_id: int, combat_amount: int)

signal _on_player_sabotage(player_id: int, combat_amount: int)
