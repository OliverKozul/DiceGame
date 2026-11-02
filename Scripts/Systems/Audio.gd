extends Node
## Sound effects, music and ambience. Every button in the game clicks and every hover ticks
## automatically; everything else calls play().

## Effect name -> number of variants (files res://Assets/Audio/sfx/<name>_<n>.ogg).
const SFX: Dictionary = {
	&"attack": 3, &"book_close": 1, &"book_open": 1, &"card_flip": 4, &"card_slide": 4,
	&"click": 3, &"cloth": 3, &"coins": 4, &"creak": 3, &"dice_shake": 3, &"dice_throw": 3,
	&"die_hit": 4, &"door_close": 2, &"door_open": 2, &"hit": 3, &"hover": 2, &"knockout": 1,
	&"lock": 1, &"page": 3, &"stamp": 3, &"toggle": 2,
}
const MUSIC: Dictionary = {
	&"menu": "res://Assets/Audio/music/old_tower_inn.ogg",
	&"game": "res://Assets/Audio/music/kings_feast.ogg",
}
const AMBIENCE := "res://Assets/Audio/music/fireplace.ogg"
const VOICES := 10
const MUSIC_FADE := 1.6

var _streams: Dictionary[StringName, Array] = {}
var _voices: Array[AudioStreamPlayer] = []
var _next_voice := 0
var _music: Array[AudioStreamPlayer] = []
var _music_index := 0
var _current_music: StringName = &""
var _ambience := AudioStreamPlayer.new()
var _rng := RandomNumberGenerator.new()
## Headless runs (tests, servers) have no audio device; playing there only leaks playbacks.
var _enabled := DisplayServer.get_name() != "headless"


func _ready() -> void:
	_rng.randomize()
	for i in VOICES:
		var voice := AudioStreamPlayer.new()
		voice.bus = &"SFX"
		add_child(voice)
		_voices.append(voice)
	for i in 2:
		var player := AudioStreamPlayer.new()
		player.bus = &"Music"
		player.volume_db = -80.0
		add_child(player)
		_music.append(player)
	_ambience.bus = &"Ambience"
	add_child(_ambience)
	get_tree().node_added.connect(_on_node_added)


## Silences everything; streams still playing when the engine shuts down show up as leaks.
func stop_all() -> void:
	var players: Array[AudioStreamPlayer] = []
	players.append_array(_voices)
	players.append_array(_music)
	players.append(_ambience)
	for player in players:
		player.stop()
		player.stream = null
	_streams.clear()


## Plays a random variant of an effect. pitch_jitter keeps repeats from sounding identical.
func play(effect: StringName, volume_db: float = 0.0, pitch_jitter: float = 0.06) -> void:
	if not _enabled:
		return
	var variants := _variants(effect)
	if variants.is_empty():
		return
	var voice := _voices[_next_voice]
	_next_voice = (_next_voice + 1) % _voices.size()
	voice.stream = variants[_rng.randi_range(0, variants.size() - 1)]
	voice.volume_db = volume_db
	voice.pitch_scale = 1.0 + _rng.randf_range(-pitch_jitter, pitch_jitter)
	voice.play()


## Cross-fades to a music track (&"menu" or &"game"); &"" fades the music out.
func play_music(track: StringName) -> void:
	if track == _current_music or not _enabled:
		return
	_current_music = track
	var old := _music[_music_index]
	_music_index = 1 - _music_index
	var new := _music[_music_index]
	var tween := create_tween().set_parallel()
	tween.tween_property(old, "volume_db", -80.0, MUSIC_FADE)
	if track != &"":
		new.stream = _looping(MUSIC[track])
		new.volume_db = -40.0
		new.play()
		tween.tween_property(new, "volume_db", 0.0, MUSIC_FADE)


func set_ambience(on: bool) -> void:
	if not _enabled:
		return
	if on and not _ambience.playing:
		if _ambience.stream == null:
			_ambience.stream = _looping(AMBIENCE)
		_ambience.play()
	elif not on:
		_ambience.stop()


func _variants(effect: StringName) -> Array:
	if not _streams.has(effect):
		var list: Array = []
		for i in SFX.get(effect, 0):
			list.append(load("res://Assets/Audio/sfx/%s_%d.ogg" % [effect, i + 1]))
		_streams[effect] = list
	return _streams[effect]


func _looping(path: String) -> AudioStream:
	var stream := load(path) as AudioStreamOggVorbis
	stream.loop = true
	return stream


func _on_node_added(node: Node) -> void:
	var button := node as BaseButton
	if button == null or button.has_meta(&"silent"):
		return
	button.pressed.connect(func() -> void: play(&"click", -4.0))
	button.mouse_entered.connect(func() -> void:
		if not button.disabled:
			play(&"hover", -16.0))
