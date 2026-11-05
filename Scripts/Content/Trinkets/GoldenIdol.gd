extends Trinket
## +2 gold every turn.


func on_roll(totals: Dictionary, _kinds: PackedInt32Array) -> void:
	totals.gold += 2
