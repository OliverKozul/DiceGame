class_name Trinket
extends Resource
## A permanent passive effect. Subclasses override only the hooks they need; the rules call
## every hook on every trinket a player owns. Hooks run on the host only, except on_roll,
## free_rerolls and market_discount, which are pure so clients can preview their roll and
## their prices.

@export var id: StringName
@export var display_name: String = "Unnamed trinket"
@export_multiline var description: String = ""


## The name in the player's language.
func name_text() -> String:
	return Loc.t(display_name)


## The description in the player's language, with {icon} tokens.
func description_text() -> String:
	return Loc.t(description)


## Called once when the owner gains this trinket.
func on_acquired(_rules: GameRules, _owner: PlayerState) -> void:
	pass


## Adjust roll totals. `totals` has the keys of PlayerState.empty_totals();
## `kinds` holds the resolved kind of every face rolled (wilds already chosen).
func on_roll(_totals: Dictionary, _kinds: PackedInt32Array) -> void:
	pass


## Called at the reveal, once the owner's plan is public and kept_word and attack_left are set.
func on_reveal(_rules: GameRules, _owner: PlayerState) -> void:
	pass


## Called when the owner's attack deals `damage` > 0 to another player.
func on_player_hit(_rules: GameRules, _owner: PlayerState, _target: PlayerState, _damage: int) -> void:
	pass


## Called when another player's attack deals `damage` > 0 to the owner.
func on_hit_by_player(_rules: GameRules, _owner: PlayerState, _attacker: PlayerState, _damage: int) -> void:
	pass


## Called when the owner's attack deals `amount` > 0 damage to a player, mob or boss.
func on_damage_dealt(_rules: GameRules, _owner: PlayerState, _amount: int) -> void:
	pass


## Extra renown when the owner completes an oath.
func honesty_bonus() -> int:
	return 0


## Rerolls each turn that cost no cunning, on top of the one everyone gets.
func free_rerolls() -> int:
	return 0


## Extra health when the owner rests.
func rest_bonus() -> int:
	return 0


## Gold off every face, upgrade and die the owner buys (never below 1).
func market_discount() -> int:
	return 0


## True if breaking a word leaves the owner's oath where it was instead of starting it over.
func keeps_oath_when_lying() -> bool:
	return false


## True if the owner returns from a knockout at full health instead of half.
func full_comeback() -> bool:
	return false
