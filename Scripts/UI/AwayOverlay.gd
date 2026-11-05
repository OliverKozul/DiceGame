class_name AwayOverlay
extends Overlay
## Shown when the local player was idle for so long that a bot took over their seat. The game goes
## on underneath until they take it back.


func _init() -> void:
	panel_size = Vector2(440, 0)


func _build() -> void:
	add_label(content, tr("Still there?"), &"Heading")
	add_label(content, tr("You were idle, so a bot is playing your seat. It plays until you take your seat back."))
	add_button(content, tr("Take my seat back"), Session.take_seat_back, &"PlankButton")


## Esc and B do nothing here: the table has to know the player is back.
func _unhandled_input(_event: InputEvent) -> void:
	pass
