extends Trinket
## When your attack damages a player, you also steal 1 gold from them.


func on_player_hit(rules: GameRules, owner: PlayerState, target: PlayerState, _damage: int) -> void:
	if target.gold > 0:
		target.gold -= 1
		owner.gold += 1
		rules.emit_event(&"steal", {"pid": owner.id, "target": target.id, "amount": 1, "what": "gold"})
		rules.log_event("{player}'s {trinket} steals 1 {gold} from {target}.", {
			"player": Loc.player(owner), "trinket": Loc.trinket(id), "target": Loc.player(target)})
