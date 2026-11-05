extends Trinket
## +2 guard every turn.


func on_roll(totals: Dictionary, _kinds: PackedInt32Array) -> void:
	totals.guard += 2
