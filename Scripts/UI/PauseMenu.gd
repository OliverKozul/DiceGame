class_name PauseMenu
extends Overlay
## The escape menu (Esc or the pad's Start button). Online play cannot pause, so the table
## keeps going underneath.

var _settings := SettingsPanel.new()
var _rules := RulesBook.new()
var _confirm := ConfirmOverlay.new()
var _pending := ""


func _init() -> void:
	panel_size = Vector2(380, 0)


func _build() -> void:
	add_label(content, tr("The Tavern"), &"Heading").horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_label(content, tr("The table keeps playing while this menu is open."), &"Dim").horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_button(content, tr("Back to the table"), close, &"PlankButton")
	add_button(content, tr("How to play"), _rules.open)
	add_button(content, tr("Settings"), _settings.open)
	add_button(content, tr("Leave the table"), _ask.bind("leave"))
	add_button(content, tr("Quit to desktop"), _ask.bind("quit"))
	_settings.language_locked = true
	add_child(_settings)
	add_child(_rules)
	add_child(_confirm)
	_confirm.confirmed.connect(_on_confirmed)


## Opens the rules book from the table (F1 or the pad's Back button).
func open_rules() -> void:
	_rules.open()


## Esc or Start opens the menu during the game and closes it again; B also closes it. The
## panels on top of it close themselves first.
func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"menu") and not (visible and event.is_action_pressed("ui_cancel")):
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
	var note := tr("A bot takes over your seat.")
	if Network.mode == Network.Mode.OFFLINE:
		note = tr("This game will be lost.")
	elif Network.is_host():
		note = tr("The game ends for everyone, because you are hosting.")
	if what == "leave":
		_confirm.ask(tr("Leave the table?"), "%s %s" % [tr("You return to the main menu."), note], tr("Leave"))
	else:
		_confirm.ask(tr("Quit to desktop?"), "%s %s" % [tr("The game closes."), note], tr("Quit"))


func _on_confirmed() -> void:
	if _pending == "leave":
		Network.leave()
	else:
		Transition.quit_game()
