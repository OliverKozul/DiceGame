extends Trinket
## +1 attack on every attack you make.


func on_reveal(_rules: GameRules, owner: PlayerState) -> void:
	if GameState.is_attack(owner.plan_action):
		owner.attack_left += 1
