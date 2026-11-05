extends Trinket
## +2 attack when you attack a player you did not declare.

const BONUS := 2


func on_reveal(rules: GameRules, owner: PlayerState) -> void:
	if owner.kept_word or owner.plan_action != PlayerState.Action.ATTACK_PLAYER:
		return
	owner.attack_left += BONUS
	rules.emit_event(&"backstab", {"pid": owner.id, "amount": BONUS})
	rules.log_event("{player}'s {trinket} adds {amount} to the ambush.", {
		"player": Loc.player(owner), "trinket": Loc.trinket(id), "amount": BONUS})
