class_name ConfirmOverlay
extends Overlay
## "Are you sure?" with a confirm and a cancel button.

signal confirmed

var _title: Label
var _message: Label
var _confirm: Button


func _init() -> void:
	panel_size = Vector2(460, 0)


func _build() -> void:
	_title = add_label(content, "", &"Heading")
	_message = add_label(content, "")
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 12)
	content.add_child(row)
	add_button(row, tr("Cancel"), close)
	_confirm = add_button(row, tr("Confirm"), _on_confirm)


func ask(title: String, message: String, confirm_text: String) -> void:
	_title.text = title
	_message.text = message
	_confirm.text = confirm_text
	open()


func _on_confirm() -> void:
	await close()
	confirmed.emit()
