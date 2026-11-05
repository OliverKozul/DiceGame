class_name ReconnectOverlay
extends Overlay
## Shown over the table while the connection to the host is lost and the game is trying to
## get back. A bot plays the seat meanwhile. It cannot be closed, only left.

var _status: Label


func _init() -> void:
	panel_size = Vector2(460, 0)


func _build() -> void:
	add_label(content, tr("Connection lost"), &"Heading")
	add_label(content, tr("A bot plays your seat until you are back. The game tries to reconnect on its own."))
	_status = add_label(content, "", &"Dim")
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	content.add_child(row)
	add_button(row, tr("Leave the game"), Network.give_up_reconnecting)
	Network.reconnect_changed.connect(_refresh)
	_refresh()


## Esc and B do nothing here: the only way out is leaving.
func _unhandled_input(_event: InputEvent) -> void:
	pass


func _refresh() -> void:
	if not is_inside_tree():
		return
	if Network.reconnecting:
		_status.text = tr("Reconnecting… (attempt {attempt})").format({"attempt": Network.reconnect_attempt})
		open()
	elif visible:
		close()
