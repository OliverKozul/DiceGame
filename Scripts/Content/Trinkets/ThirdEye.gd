extends Trinket
## +2 cunning every turn, plus 2 more for every cunning face rolled; each cunning face heals 1.


func on_roll(totals: Dictionary, kinds: PackedInt32Array) -> void:
	var count := kinds.count(Face.Kind.CUNNING)
	totals.cunning += 2 + 2 * count
	totals.heal += count
