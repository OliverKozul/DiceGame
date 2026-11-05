extends Trinket
## +2 guard on a turn you break your word.

const BONUS := 2


func on_reveal(rules: GameRules, owner: PlayerState) -> void:
	if owner.kept_word:
		return
	owner.guard_left += BONUS
	rules.emit_event(&"guard", {"pid": owner.id, "amount": BONUS})
	rules.log_event("{player}'s {trinket} adds {amount} {guard}.", {
		"player": Loc.player(owner), "trinket": Loc.trinket(id), "amount": BONUS})
