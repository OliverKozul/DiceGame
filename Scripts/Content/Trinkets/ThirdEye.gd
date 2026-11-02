extends Trinket
## Every cunning face rolled gives 3 more cunning and heals 1.


func on_roll(totals: Dictionary, kinds: PackedInt32Array) -> void:
	var count := kinds.count(Face.Kind.CUNNING)
	totals.cunning += 3 * count
	totals.heal += count
