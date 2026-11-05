extends Trinket
## When another player's attack damages you, they take 1 damage.

const THORNS := 1


func on_hit_by_player(rules: GameRules, owner: PlayerState, attacker: PlayerState, _damage: int) -> void:
	if not attacker.is_active():
		return
	rules.emit_event(&"thorns", {"pid": owner.id, "target": attacker.id, "damage": THORNS})
	rules.log_event("{player}'s {trinket} pricks {target} for {amount}.", {
		"player": Loc.player(owner), "trinket": Loc.trinket(id), "target": Loc.player(attacker), "amount": THORNS})
	rules.hurt(attacker, THORNS, owner.id)
