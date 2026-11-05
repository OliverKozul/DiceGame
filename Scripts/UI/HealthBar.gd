class_name HealthBar
extends Control
## A health bar with a "ghost": on damage the bar drops at once and a pale ghost of the old
## health drains after a beat, so you see how much was lost; on healing a green ghost grows
## first and the bar follows. Draws its own "hp / max" text.

const BACK := Color(0.0, 0.0, 0.0, 0.38)
const FILL := Color("c9442f")
const FILL_LIGHT := Color("e86a4c")
const LOSS := Color("f3d2a6")
const GAIN := Color("8fe08f")
const TEXT := Color("fff3e0")

var _max := 1
var _shown := -1.0
var _ghost := -1.0
var _ghost_color := LOSS
var _text := ""
var _tweens: Array[Tween] = []


func _init() -> void:
	custom_minimum_size = Vector2(0, 17)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Shows `hp` of `max_hp`, animating the change over about `seconds` (0 = at once).
func set_hp(hp: int, max_hp: int, seconds: float) -> void:
	_max = maxi(1, max_hp)
	_text = "%d / %d" % [hp, max_hp]
	for tween in _tweens:
		tween.kill()
	_tweens.clear()
	if _shown < 0.0 or seconds <= 0.0 or Settings.reduced_motion():
		_shown = hp
		_ghost = hp
		queue_redraw()
		return
	if hp < _shown:
		_ghost_color = LOSS
		_ghost = maxf(_ghost, _shown)
		_tweens.append(_tween_value("_shown", hp, seconds * 0.2, 0.0))
		_tweens.append(_tween_value("_ghost", hp, seconds * 0.7, seconds * 0.45))
	elif hp > _shown:
		_ghost_color = GAIN
		_ghost = hp
		_tweens.append(_tween_value("_shown", hp, seconds * 0.6, seconds * 0.15))
	queue_redraw()


func _tween_value(property: String, to: float, seconds: float, delay: float) -> Tween:
	var tween := create_tween()
	tween.tween_interval(delay)
	tween.tween_method(func(v: float) -> void:
		set(property, v)
		queue_redraw(), float(get(property)), to, seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	return tween


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, BACK)
	var ghost := clampf(_ghost / _max, 0.0, 1.0)
	var fill := clampf(_shown / _max, 0.0, 1.0)
	if ghost > fill:
		draw_rect(Rect2(Vector2.ZERO, Vector2(size.x * ghost, size.y)), _ghost_color)
	if fill > 0.0:
		draw_rect(Rect2(Vector2.ZERO, Vector2(size.x * fill, size.y)), FILL)
		draw_rect(Rect2(Vector2.ZERO, Vector2(size.x * fill, size.y * 0.4)), FILL_LIGHT)
	var font := get_theme_default_font()
	var font_size := 13
	var width := font.get_string_size(_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var at := Vector2((size.x - width) / 2.0, size.y / 2.0 + font_size * 0.36)
	draw_string_outline(font, at, _text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 4, Color(0, 0, 0, 0.8))
	draw_string(font, at, _text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, TEXT)
