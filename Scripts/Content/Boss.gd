class_name Boss
extends Resource
## A boss card. Its HP scales with the number of seats and resets every turn.

@export var id: StringName
@export var display_name: String = "Unnamed boss"
@export_multiline var description: String = ""
@export var hp_per_player: int = 4
@export var damage: int = 3


func max_hp(seats: int) -> int:
	return hp_per_player * seats
