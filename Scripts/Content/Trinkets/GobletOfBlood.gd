extends Trinket
## When your attack deals damage, heal 1 plus 1 for every 5 damage.


func on_damage_dealt(rules: GameRules, owner: PlayerState, amount: int) -> void:
	var healed := owner.heal(1 + floori(amount / 5.0))
	if healed > 0:
		rules.emit_event(&"heal", {"pid": owner.id, "amount": healed})
		rules.log_event("%s's Goblet of Blood heals %d {heal}." % [owner.name, healed])
