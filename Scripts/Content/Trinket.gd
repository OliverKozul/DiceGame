class_name Trinket
extends Resource
## A permanent passive effect. Subclasses override only the hooks they need; the rules call
## every hook on every trinket a player owns. Hooks run on the host only, except on_roll,
## which is pure so clients can preview their roll totals.

@export var id: StringName
@export var display_name: String = "Unnamed trinket"
@export_multiline var description: String = ""


## Called once when the owner gains this trinket.
func on_acquired(_rules: GameRules, _owner: PlayerState) -> void:
	pass


## Adjust roll totals. `totals` has the keys of PlayerState.empty_totals();
## `kinds` holds the resolved kind of every face rolled (wilds already chosen).
func on_roll(_totals: Dictionary, _kinds: PackedInt32Array) -> void:
	pass


## Extra combat removed by each of the owner's sabotages.
func sabotage_bonus() -> int:
	return 0


## Called after one of the owner's sabotages lands on `target`.
func on_sabotage(_rules: GameRules, _owner: PlayerState, _target: PlayerState) -> void:
	pass


## Called when the owner's attack deals `amount` > 0 damage to a player, mob or boss.
func on_damage_dealt(_rules: GameRules, _owner: PlayerState, _amount: int) -> void:
	pass


## Extra renown when the owner keeps their intention.
func honesty_bonus() -> int:
	return 0
