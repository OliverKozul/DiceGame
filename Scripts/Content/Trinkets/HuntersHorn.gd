extends Trinket
## +2 attack when you attack a mob.

const BONUS := 2


func on_reveal(_rules: GameRules, owner: PlayerState) -> void:
	if owner.plan_action == PlayerState.Action.ATTACK_MOB:
		owner.attack_left += BONUS
