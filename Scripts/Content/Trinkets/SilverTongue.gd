extends Trinket
## +1 gold whenever you keep your word.


func on_reveal(rules: GameRules, owner: PlayerState) -> void:
	if not owner.kept_word:
		return
	owner.gold += 1
	rules.emit_event(&"gold", {"pid": owner.id, "amount": 1})
	rules.log_event("{player}'s {trinket} earns 1 {gold}.", {"player": Loc.player(owner), "trinket": Loc.trinket(id)})
