extends CanvasLayer
## Scene changes behind a "candle being snuffed" transition, and the music for each scene.

const SHADER := preload("res://Assets/Shaders/transition.gdshader")
const DURATION := 0.45
## Longest animation timer that may still be pending when the game quits.
const QUIT_GRACE := 0.6
const SCENE_MUSIC: Dictionary = {
	"res://Scenes/Menu.tscn": &"menu",
	"res://Scenes/Game.tscn": &"game",
}

var _cover := ColorRect.new()
var _material := ShaderMaterial.new()
var _busy := false
var _queued := ""
var _quitting := false


func _ready() -> void:
	get_tree().auto_accept_quit = false
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_material.shader = SHADER
	_material.set_shader_parameter("progress", 0.0)
	_cover.material = _material
	_cover.set_anchors_preset(Control.PRESET_FULL_RECT)
	_cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_cover)
	_set_progress(0.0)
	Audio.set_ambience(true)
	_play_music_for.call_deferred(get_tree().current_scene)


func change_scene(path: String) -> void:
	if _busy:
		_queued = path
		return
	_busy = true
	_cover.mouse_filter = Control.MOUSE_FILTER_STOP
	var duration := 0.0 if Settings.reduced_motion() else DURATION
	if duration > 0.0:
		var tween := create_tween()
		tween.tween_method(_set_progress, 0.0, 1.0, duration).set_trans(Tween.TRANS_SINE)
		await tween.finished
	_set_progress(1.0)
	await _wind_down_current_scene()
	Audio.play_music(SCENE_MUSIC.get(path, &""))
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	await get_tree().process_frame
	if duration > 0.0:
		var tween := create_tween()
		tween.tween_method(_set_progress, 1.0, 0.0, duration).set_trans(Tween.TRANS_SINE)
		await tween.finished
	_set_progress(0.0)
	_cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false
	if not _queued.is_empty():
		var next := _queued
		_queued = ""
		change_scene(next)


## The one way out of the game: leaves any session, frees the current scene (stopping its
## animations), lets in-flight timers run out, silences audio and only then quits, so the
## engine shuts down with nothing still running.
func quit_game(exit_code: int = 0) -> void:
	if _quitting:
		return
	_quitting = true
	if Network.in_room():
		Network._close()
	await _wind_down_current_scene()
	get_tree().unload_current_scene()
	Audio.stop_all()
	await get_tree().create_timer(QUIT_GRACE).timeout
	await get_tree().process_frame
	get_tree().quit(exit_code)


## Lets a scene finish its animations before it is freed (see GameScreen.wind_down), so no
## coroutine is left waiting on something that no longer exists.
func _wind_down_current_scene() -> void:
	var scene := get_tree().current_scene
	if scene and scene.has_method("wind_down"):
		await scene.call("wind_down")


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		quit_game()


func _set_progress(value: float) -> void:
	_material.set_shader_parameter("progress", value)
	# At rest the cover is hidden: its noisy edge would otherwise leave embers in the corners.
	_cover.visible = value > 0.0


func _play_music_for(scene: Node) -> void:
	if scene:
		Audio.play_music(SCENE_MUSIC.get(scene.scene_file_path, &"menu"))
