class_name BossBar
extends Control
## The boss's health as one segment per point. Wounds this turn are painted in the colour of
## the seat that dealt them, so the table sees who is pulling their weight; a gold tick marks
## the share a slayer must deal. Lost health drains through a pale ghost.

const BACK := Color(0.0, 0.0, 0.0, 0.35)
const ALIVE := Color("b8321f")
const ALIVE_LIGHT := Color("e2563b")
const GHOST := Color("f3d2a6")
const TICK := Color("f2c14e")
const GAP := 2.0

var _max := 1
var _hp := 1
var _ghost := 1.0
## Who dealt each wound this turn, in order: [seat colour, damage].
var _wounds: Array[Array] = []
var _share := 0
var _ghost_tween: Tween


func _init() -> void:
	custom_minimum_size = Vector2(0, 16)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Sets the bar at once from a view: health, and this turn's wounds by seat colour.
func show_state(hp: int, max_hp: int, wounds: Array[Array], share: int) -> void:
	_max = maxi(1, max_hp)
	_hp = clampi(hp, 0, _max)
	_wounds = wounds
	_share = share
	if _ghost_tween:
		_ghost_tween.kill()
	_ghost = _hp
	queue_redraw()


## A hit lands: the wound appears in the attacker's colour and the ghost drains after a beat.
func hit(hp: int, color: Color, damage: int, seconds: float) -> void:
	var from := float(_hp)
	_hp = clampi(hp, 0, _max)
	if damage > 0:
		_wounds.append([color, damage])
	if _ghost_tween:
		_ghost_tween.kill()
	if seconds <= 0.0 or Settings.reduced_motion():
		_ghost = _hp
		queue_redraw()
		return
	_ghost = maxf(_ghost, from)
	_ghost_tween = create_tween()
	_ghost_tween.tween_interval(seconds * 0.35)
	_ghost_tween.tween_method(func(v: float) -> void:
		_ghost = v
		queue_redraw(), _ghost, float(_hp), seconds * 0.65).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	queue_redraw()


func _draw() -> void:
	var width := (size.x - GAP * (_max - 1)) / _max
	# Segments from the left are the health still standing. Wounds fill from the right edge,
	# in the order they were dealt: the first wound is the rightmost segment.
	var dealt_by: Array[Color] = []
	for wound in _wounds:
		for i in int(wound[1]):
			dealt_by.append(wound[0])
	for i in _max:
		var rect := Rect2(i * (width + GAP), 0.0, width, size.y)
		draw_rect(rect, BACK)
		if i < _hp:
			draw_rect(rect, ALIVE)
			draw_rect(Rect2(rect.position, Vector2(rect.size.x, rect.size.y * 0.4)), ALIVE_LIGHT)
		else:
			if i < _ghost:
				draw_rect(Rect2(rect.position, Vector2(rect.size.x * clampf(_ghost - i, 0.0, 1.0), rect.size.y)), GHOST)
			var index := _max - 1 - i
			if index < dealt_by.size():
				var seat_color: Color = dealt_by[index]
				draw_rect(Rect2(rect.position + Vector2(0, rect.size.y * 0.6), Vector2(rect.size.x, rect.size.y * 0.4)), seat_color)
	if _share > 0 and _share < _max:
		var x := size.x - _share * (width + GAP) + GAP / 2.0
		draw_line(Vector2(x, -3.0), Vector2(x, size.y + 3.0), TICK, 2.0)
