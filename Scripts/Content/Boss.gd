class_name Boss
extends Resource
## A boss card. Its HP (base plus a share per seat) resets every turn. Each new boss is drawn
## at random from the next stage: the first boss from stage 1, the one after it from stage 2,
## and every later one from the last stage.

@export var id: StringName
@export var display_name: String = "Unnamed boss"
@export_multiline var description: String = ""
@export_range(1, 3) var stage: int = 1
@export var base_hp: int = 2
@export var hp_per_player: int = 1
@export var damage: int = 3


func max_hp(seats: int) -> int:
	return base_hp + hp_per_player * seats


## The name in the player's language.
func name_text() -> String:
	return Loc.t(display_name)


func description_text() -> String:
	return Loc.t(description)
