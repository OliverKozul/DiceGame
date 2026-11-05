extends Trinket
## +1 gold for every gold face rolled.


func on_roll(totals: Dictionary, kinds: PackedInt32Array) -> void:
	totals.gold += kinds.count(Face.Kind.GOLD)
