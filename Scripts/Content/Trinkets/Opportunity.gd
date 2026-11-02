extends Trinket
## Gain an extra basic die.


func on_acquired(rules: GameRules, owner: PlayerState) -> void:
	owner.add_die(Content.basic_die())
	rules.log_event("%s gains an extra die." % owner.name)
