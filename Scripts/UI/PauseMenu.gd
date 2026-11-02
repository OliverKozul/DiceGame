class_name PauseMenu
extends Overlay
## The escape menu. Online play cannot pause, so the table keeps going underneath.

var _settings := SettingsPanel.new()
var _rules := RulesBook.new()
var _confirm := ConfirmOverlay.new()
var _pending := ""


func _init() -> void:
	panel_size = Vector2(380, 0)


func _build() -> void:
	add_label(content, "The Tavern", &"Heading").horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_label(content, "The table keeps playing while this menu is open.", &"Dim").horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_button(content, "Back to the table", close, &"PlankButton")
	add_button(content, "How to play", _rules.open)
	add_button(content, "Settings", _settings.open)
	add_button(content, "Leave the table", _ask.bind("leave"))
	add_button(content, "Quit to desktop", _ask.bind("quit"))
	add_child(_settings)
	add_child(_rules)
	add_child(_confirm)
	_confirm.confirmed.connect(_on_confirmed)


## Esc opens the menu during the game and closes it (or the panel on top) again.
func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if _settings.visible or _rules.visible or _confirm.visible:
		return
	get_viewport().set_input_as_handled()
	if visible:
		close()
	else:
		open()


func _ask(what: String) -> void:
	_pending = what
	var host_note := " The game ends for everyone, because you are hosting." if Network.is_host() and Network.mode != Network.Mode.OFFLINE else " A bot takes over your seat."
	if Network.mode == Network.Mode.OFFLINE:
		host_note = " This game will be lost."
	if what == "leave":
		_confirm.ask("Leave the table?", "You return to the main menu." + host_note, "Leave")
	else:
		_confirm.ask("Quit to desktop?", "The game closes." + host_note, "Quit")


func _on_confirmed() -> void:
	if _pending == "leave":
		Network.leave()
	else:
		Transition.quit_game()
