extends Manager


var trinkets: Array[Trinket] = []


func _ready() -> void:
	SignalBus.connect("_on_combat_roll", _on_combat_roll)

func add_trinket(trinket : Trinket) -> void:
	trinkets.append(trinket)
	if trinket.has_method("on_added"):
		trinket.on_added(self)  # Allow trinkets to register for events

func remove_trinket(trinket : Trinket) -> void:
	trinkets.erase(trinket)
	if trinket.has_method("on_removed"):
		trinket.on_removed(self)
		
func _on_combat_roll(player_id : int, combat_amount : int) -> void:
	if multiplayer.get_unique_id() != player_id:
		return
		
	for trinket in trinkets:
		if trinket.has_method("_on_combat_roll"):
			combat_amount = trinket._on_combat_roll(player_id)
			
	Global.player_info[player_id].combat += combat_amount
