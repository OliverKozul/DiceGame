extends Node
## Works out what a finished game earned the local player (see AchievementRules), remembers it in
## user://profile.cfg (Steam Cloud carries it) and passes it on to Steam, also later if Steam was
## away at the time. Automated test runs (any Dev option) print what they earned and save nothing.

const PATH := "user://profile.cfg"
const SECTION := "achievements"

## What the last finished game unlocked for the first time, for the end screen.
var new_this_game: Array[StringName] = []

var _file := ConfigFile.new()
var _counted := false


func _ready() -> void:
	_file.load(PATH)
	Session.view_changed.connect(_on_view_changed)
	SteamService.unlock_achievements(_unlocked())


func _unlocked() -> Array[StringName]:
	var ids: Array[StringName] = []
	if _file.has_section(SECTION):
		for key in _file.get_section_keys(SECTION):
			ids.append(StringName(key))
	return ids


func _on_view_changed(view: GameState) -> void:
	if view.phase != GameState.Phase.GAME_OVER:
		_counted = false
		new_this_game.clear()
		return
	if _counted:
		return
	_counted = true
	var offline := Network.mode == Network.Mode.OFFLINE
	var earned := AchievementRules.earned(view, Session.local_id(), int(Network.room.get("difficulty", BotTable.Difficulty.NORMAL)), offline)
	if not Dev.options.is_empty():
		print("ACHIEVEMENTS %s" % [earned])
		return
	for id in earned:
		if not _file.has_section_key(SECTION, id):
			_file.set_value(SECTION, id, true)
			new_this_game.append(id)
	_file.save(PATH)
	SteamService.unlock_achievements(earned)
