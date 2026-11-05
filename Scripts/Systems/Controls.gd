extends Node
## Keyboard and controller support. Godot's ui_* actions already move focus between controls
## with the arrow keys, the d-pad and the left stick, press the focused control with Enter,
## Space or the A button, and go back with Esc or the B button. This adds:
##   - the game's own actions (below), so every screen reads the same bindings;
##   - which kind of input the player is using: with keys or a pad, screens put the focus on
##     the control that matters; with a mouse they leave it alone;
##   - a fallback: if nothing has focus when a key or button is pressed, the open overlay or
##     the current screen gets it;
##   - overlays keep the focus inside them while they are open.

signal mode_changed(using_keys: bool)

## Action -> [keys, joypad buttons]. Defined here rather than in project.godot so the
## bindings live next to the code that documents them (see also the rules book's Controls page).
const ACTIONS: Dictionary[StringName, Array] = {
	&"menu": [[KEY_ESCAPE], [JOY_BUTTON_START]],
	&"skip": [[KEY_SPACE], [JOY_BUTTON_X]],
	&"rules": [[KEY_F1], [JOY_BUTTON_BACK]],
	&"players": [[KEY_I], [JOY_BUTTON_Y]],
	&"prev_tab": [[KEY_Q], [JOY_BUTTON_LEFT_SHOULDER]],
	&"next_tab": [[KEY_E], [JOY_BUTTON_RIGHT_SHOULDER]],
	&"scroll_up": [[KEY_PAGEUP], []],
	&"scroll_down": [[KEY_PAGEDOWN], []],
}
const STICK_DEADZONE := 0.5
const NAVIGATION: Array[StringName] = [&"ui_up", &"ui_down", &"ui_left", &"ui_right", &"ui_accept", &"ui_focus_next", &"ui_focus_prev"]

## True after a key or pad press, false after the mouse is used.
var using_keys := false

## Where focus goes when nothing has it: the latest provider whose control is usable.
var _defaults: Array[Callable] = []
## Overlays that are open, innermost last; focus stays inside the last one.
var _scopes: Array[Control] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for action: StringName in ACTIONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.5)
		for key: int in ACTIONS[action][0]:
			var event := InputEventKey.new()
			event.physical_keycode = key as Key
			InputMap.action_add_event(action, event)
		for button: int in ACTIONS[action][1]:
			var pad := InputEventJoypadButton.new()
			pad.button_index = button as JoyButton
			InputMap.action_add_event(action, pad)
	# Godot gives the d-pad and left stick to the ui_ actions, but no pad button presses or
	# goes back: the bottom face button (A) presses, the right one (B) goes back.
	for pair: Array in [[&"ui_accept", JOY_BUTTON_A], [&"ui_cancel", JOY_BUTTON_B]]:
		var face := InputEventJoypadButton.new()
		face.button_index = pair[1]
		if not InputMap.action_has_event(pair[0], face):
			InputMap.action_add_event(pair[0], face)
	for pair: Array in [[&"scroll_up", -1.0], [&"scroll_down", 1.0]]:
		var stick := InputEventJoypadMotion.new()
		stick.axis = JOY_AXIS_RIGHT_Y
		stick.axis_value = pair[1]
		InputMap.action_add_event(pair[0], stick)
	get_viewport().gui_focus_changed.connect(_on_focus_changed)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton or (event is InputEventMouseMotion and (event as InputEventMouseMotion).relative.length() > 2.0):
		_set_mode(false)
		return
	var pressed := (event is InputEventKey and event.is_pressed()) or (event is InputEventJoypadButton and event.is_pressed())
	pressed = pressed or (event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) > STICK_DEADZONE)
	if not pressed:
		return
	_set_mode(true)
	if get_viewport().gui_get_focus_owner() != null:
		return
	for action in NAVIGATION:
		if event.is_action_pressed(action):
			var target := default_focus()
			if target:
				target.grab_focus()
				get_viewport().set_input_as_handled()
			return


## Gives `control` the focus if the player is using keys or a pad (deferred, so it may be
## called while the control is being built).
func focus(control: Control) -> void:
	if using_keys and control:
		_grab.call_deferred(control)


## Registers a callable returning the control to focus when nothing has focus (or null).
## Later providers win while their control is usable.
func add_default(provider: Callable) -> void:
	_defaults.append(provider)


func remove_default(provider: Callable) -> void:
	_defaults.erase(provider)


## An overlay opened: focus stays inside `scope` until it closes.
func push_scope(scope: Control) -> void:
	_scopes.erase(scope)
	_scopes.append(scope)


func pop_scope(scope: Control) -> void:
	_scopes.erase(scope)


## The control focus would go to now: the first one in the innermost overlay, else the
## screen's default.
func default_focus() -> Control:
	_prune()
	if not _scopes.is_empty():
		return first_focusable(_scopes[-1])
	for i in range(_defaults.size() - 1, -1, -1):
		if not _defaults[i].is_valid():
			continue
		var control: Control = _defaults[i].call()
		if _usable(control):
			return control
	return null


## The first visible, enabled, focusable control under `root`, in tree order.
func first_focusable(root: Node) -> Control:
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_front()
		var control := node as Control
		if control and control != root and _usable(control):
			return control
		var children := node.get_children()
		for i in range(children.size() - 1, -1, -1):
			stack.push_front(children[i])
	return null


static func _usable(control: Control) -> bool:
	if control == null or not is_instance_valid(control) or not control.is_visible_in_tree():
		return false
	if control.focus_mode == Control.FOCUS_NONE:
		return false
	return not (control is BaseButton and (control as BaseButton).disabled)


func _grab(control: Control) -> void:
	if is_instance_valid(control) and _usable(control) and _inside_scope(control):
		control.grab_focus()


func _set_mode(keys: bool) -> void:
	if keys == using_keys:
		return
	using_keys = keys
	mode_changed.emit(keys)


func _prune() -> void:
	_scopes.assign(_scopes.filter(func(scope: Control) -> bool: return is_instance_valid(scope) and scope.is_visible_in_tree()))


func _inside_scope(control: Control) -> bool:
	_prune()
	return _scopes.is_empty() or _scopes[-1].is_ancestor_of(control)


## Focus that wanders out of an open overlay (onto the table behind it) is brought back.
func _on_focus_changed(control: Control) -> void:
	if _inside_scope(control):
		return
	var target := first_focusable(_scopes[-1])
	if target and target != control:
		target.grab_focus.call_deferred()
