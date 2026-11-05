extends Trinket
## +4 maximum health, and heal to full.

const BONUS := 4


func on_acquired(rules: GameRules, owner: PlayerState) -> void:
	owner.max_hp += BONUS
	owner.hp = owner.max_hp
	rules.emit_event(&"heal", {"pid": owner.id, "amount": BONUS})
	rules.log_event("{player}'s {trinket}: +{amount} maximum health, fully healed.", {
		"player": Loc.player(owner), "trinket": Loc.trinket(id), "amount": BONUS})
