class_name Mob
extends Resource
## A mob card. A single player kills it by attacking with at least `hp` combat.

@export var id: StringName
@export var display_name: String = "Unnamed mob"
@export_multiline var description: String = ""
@export_range(1, 3) var tier: int = 1
@export var copies: int = 3
@export var hp: int = 2
@export var damage: int = 1
## One of these is awarded at random to each player who kills the mob.
@export var rewards: Array[Trinket] = []


## The name in the player's language.
func name_text() -> String:
	return Loc.t(display_name)


func description_text() -> String:
	return Loc.t(description)
