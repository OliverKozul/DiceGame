extends Trinket
## +1 cunning every turn, plus 1 for every cunning face rolled.


func on_roll(totals: Dictionary, kinds: PackedInt32Array) -> void:
	totals.cunning += 1 + kinds.count(Face.Kind.CUNNING)
