extends Trinket
## Gain an extra die with combat 2, combat 2, gold 2, gold 2, cunning 1, cunning 1.


func on_acquired(rules: GameRules, owner: PlayerState) -> void:
	owner.add_die(Content.boss_die())
	rules.emit_event(&"new_die", {"pid": owner.id})
	rules.log_event("{player} gains an extra die.", {"player": Loc.player(owner)})
