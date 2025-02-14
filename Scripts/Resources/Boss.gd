extends Resource
class_name Boss

@export var name: String = "Unnamed boss."
@export var current_hp: int = 3
@export var max_hp: int = 3
@export var damage: int = 2
@export var description: String = "No description."
@export var drops: Array[Trinket]
