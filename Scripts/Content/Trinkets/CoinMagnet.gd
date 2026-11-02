extends Trinket
## Each of your sabotages also steals 1 gold from the target.


func on_sabotage(rules: GameRules, owner: PlayerState, target: PlayerState) -> void:
	if target.gold > 0:
		target.gold -= 1
		owner.gold += 1
		rules.log_event("%s's Coin Magnet steals 1 💰 from %s." % [owner.name, target.name])
