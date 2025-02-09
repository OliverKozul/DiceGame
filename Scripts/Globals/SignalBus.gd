extends Node


signal update_hp_label()
signal update_gold_label()
signal update_combat_label()
signal update_cunning_label()
signal update_trinkets_label()

signal sync_player_info(player_id : int)
signal sync_roll_result(player_id : int, roll_result : String)
