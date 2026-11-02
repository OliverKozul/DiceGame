extends Trinket
## +1 combat for every combat face rolled.


func on_roll(totals: Dictionary, kinds: PackedInt32Array) -> void:
	totals.combat += kinds.count(Face.Kind.COMBAT)
