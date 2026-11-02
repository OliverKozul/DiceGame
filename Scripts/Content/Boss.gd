class_name Boss
extends Resource
## A boss card. Its HP (base plus a share per seat) resets every turn.

@export var id: StringName
@export var display_name: String = "Unnamed boss"
@export_multiline var description: String = ""
@export var base_hp: int = 2
@export var hp_per_player: int = 1
@export var damage: int = 3


func max_hp(seats: int) -> int:
	return base_hp + hp_per_player * seats
