class_name Juice
extends RefCounted
## The table's shared motion vocabulary: pops, punches, wobbles, flashes, number counters,
## hit-stop, particle bursts and icons that fly between places. Callers pass durations from
## GameScreen.duration(), so animation speed and skipping apply; a duration of 0, or reduced
## motion, turns every effect into an instant change.
##
## Effects move controls by scale and rotation only, never by position, so they are safe on
## children of containers (which reset positions whenever they sort).

## Points along a streak's path; more make smoother arcs.
const STREAK_POINTS := 16
## The most a pop may widen a control, in pixels; wide panels would otherwise burst their frame.
const MAX_SWELL := 14.0

static var _dot: Texture2D


static func enabled(duration: float = 1.0) -> bool:
	return duration > 0.0 and not Settings.reduced_motion()


## Scales up and springs back around the centre.
static func pop(node: Control, amount: float = 0.18, duration: float = 0.35) -> void:
	if not enabled(duration) or not is_instance_valid(node):
		return
	node.pivot_offset = node.size / 2.0
	var swell := minf(amount, MAX_SWELL / maxf(maxf(node.size.x, node.size.y), 1.0))
	var tween := node.create_tween()
	tween.tween_property(node, "scale", Vector2.ONE * (1.0 + swell), duration * 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "scale", Vector2.ONE, duration * 0.7).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## A blow: squashes, tilts away from it (`direction` -1 left, 1 right) and springs back.
static func punch(node: Control, direction: float = 1.0, strength: float = 1.0, duration: float = 0.4) -> void:
	if not enabled(duration) or not is_instance_valid(node):
		return
	node.pivot_offset = node.size / 2.0
	var tween := node.create_tween().set_parallel()
	node.rotation_degrees = 3.5 * strength * signf(direction if direction != 0.0 else 1.0)
	node.scale = Vector2(1.0 + 0.06 * strength, 1.0 - 0.08 * strength)
	tween.tween_property(node, "rotation_degrees", 0.0, duration).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "scale", Vector2.ONE, duration).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## A few quick, decaying rotations: a shiver rather than a blow.
static func wobble(node: Control, degrees: float = 4.0, duration: float = 0.35) -> void:
	if not enabled(duration) or not is_instance_valid(node):
		return
	node.pivot_offset = node.size / 2.0
	var tween := node.create_tween()
	var steps := 6
	for i in steps:
		var side := 1.0 if i % 2 == 0 else -1.0
		tween.tween_property(node, "rotation_degrees", degrees * side * (1.0 - float(i) / steps), duration / (steps + 1))
	tween.tween_property(node, "rotation_degrees", 0.0, duration / (steps + 1))


## Brightens (or tints) a node for a moment.
static func flash(node: CanvasItem, color: Color = Color(1.7, 1.5, 1.2), duration: float = 0.3) -> void:
	if not enabled(duration) or not is_instance_valid(node):
		return
	node.self_modulate = color
	var tween := node.create_tween()
	tween.tween_property(node, "self_modulate", Color.WHITE, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## Counts from `from` to `to`, calling `apply` with each whole number on the way.
static func count(owner: Node, from: int, to: int, duration: float, apply: Callable) -> void:
	if from == to or not enabled(duration) or not is_instance_valid(owner):
		apply.call(to)
		return
	var tween := owner.create_tween()
	tween.tween_method(func(value: float) -> void: apply.call(roundi(value)), float(from), float(to), duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## Freezes the game clock for a moment, so a big impact lands. Awaitable.
static func hit_stop(tree: SceneTree, seconds: float = 0.08) -> void:
	if not enabled(seconds) or tree == null:
		return
	Engine.time_scale = 0.03
	await tree.create_timer(seconds, true, false, true).timeout
	Engine.time_scale = 1.0


## A one-shot burst of soft dots (sparks, dust, coins) at `at` in `parent`'s coordinates.
static func burst(parent: CanvasItem, at: Vector2, color: Color, amount: int = 16, speed: float = 180.0,
		lifetime: float = 0.6, gravity: float = 320.0, size: float = 1.0) -> void:
	if not enabled() or not is_instance_valid(parent):
		return
	var particles := CPUParticles2D.new()
	particles.one_shot = true
	particles.amount = amount
	particles.lifetime = lifetime
	particles.explosiveness = 0.95
	particles.spread = 180.0
	particles.direction = Vector2.UP
	particles.initial_velocity_min = speed * 0.45
	particles.initial_velocity_max = speed
	particles.gravity = Vector2(0.0, gravity)
	particles.damping_min = speed * 0.4
	particles.damping_max = speed * 0.8
	particles.scale_amount_min = 0.35 * size
	particles.scale_amount_max = 0.8 * size
	particles.texture = dot()
	var ramp := Gradient.new()
	ramp.set_color(0, color)
	ramp.set_color(1, Color(color, 0.0))
	particles.color_ramp = ramp
	particles.position = at
	particles.finished.connect(particles.queue_free)
	parent.add_child(particles)
	particles.emitting = true


## Flies an icon from `from` to `to` (both in `layer`'s coordinates) along an arc. Awaitable.
static func fly(layer: Control, from: Vector2, to: Vector2, icon_name: String, duration: float = 0.6,
		icon_size: float = 30.0, delay: float = 0.0) -> void:
	if not enabled(duration) or not is_instance_valid(layer):
		return
	var rect := TextureRect.new()
	rect.texture = Icons.texture(icon_name)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.size = Vector2.ONE * icon_size
	rect.pivot_offset = rect.size / 2.0
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.position = from - rect.size / 2.0
	rect.modulate.a = 0.0
	layer.add_child(rect)
	var lift := maxf(70.0, from.distance_to(to) * 0.35)
	var control := (from + to) / 2.0 + Vector2(0.0, -lift)
	var tween := rect.create_tween()
	tween.tween_interval(delay)
	tween.tween_property(rect, "modulate:a", 1.0, 0.0)
	tween.tween_method(func(t: float) -> void:
		var a := from.lerp(control, t)
		var b := control.lerp(to, t)
		rect.position = a.lerp(b, t) - rect.size / 2.0
		rect.scale = Vector2.ONE * (1.0 + 0.5 * sin(t * PI))
		rect.rotation = sin(t * TAU) * 0.3, 0.0, 1.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	rect.queue_free()


## A slash of light from `from` to `to` (in `layer`'s coordinates): the head races ahead, the
## tapered tail follows and fades. `bend` bows the path sideways (to the right of a downward
## path; negative bows the other way), so slashes between stacked seats arc out over the
## table. Awaitable; returns when the head arrives.
static func streak(layer: Control, from: Vector2, to: Vector2, color: Color, duration: float = 0.25,
		width: float = 12.0, bend: float = 0.0) -> void:
	if not enabled(duration) or not is_instance_valid(layer):
		return
	var normal := (to - from).orthogonal().normalized()
	if normal.x < 0.0:
		normal = -normal
	var control := (from + to) / 2.0 + normal * bend
	var path := PackedVector2Array()
	for i in STREAK_POINTS + 1:
		var t := float(i) / STREAK_POINTS
		path.append(from.lerp(control, t).lerp(control.lerp(to, t), t))
	var line := Line2D.new()
	line.width = width
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	var taper := Curve.new()
	taper.add_point(Vector2(0.0, 0.1))
	taper.add_point(Vector2(1.0, 1.0))
	line.width_curve = taper
	var fade := Gradient.new()
	fade.set_color(0, Color(color, 0.0))
	fade.set_color(1, color)
	line.gradient = fade
	layer.add_child(line)
	var tween := line.create_tween()
	tween.tween_method(func(t: float) -> void:
		# The visible stretch runs from the tail (lagging behind) to the head.
		var head := t * STREAK_POINTS
		var tail := maxf(0.0, head - STREAK_POINTS * 0.55)
		var points := PackedVector2Array()
		var i := floori(tail)
		while i < ceili(head):
			points.append(_along(path, maxf(float(i), tail)))
			i += 1
		points.append(_along(path, head))
		if points.size() < 2:
			points.append(points[0])
		line.points = points, 0.0, 1.0, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	var tail_fade := line.create_tween()
	tail_fade.tween_interval(duration)
	tail_fade.tween_property(line, "modulate:a", 0.0, duration * 0.8)
	tail_fade.tween_callback(line.queue_free)
	await tween.finished


static func _along(path: PackedVector2Array, at: float) -> Vector2:
	var i := clampi(floori(at), 0, path.size() - 2)
	return path[i].lerp(path[i + 1], clampf(at - i, 0.0, 1.0))


## A soft round dot, used by the particle bursts.
static func dot() -> Texture2D:
	if _dot == null:
		var gradient := Gradient.new()
		gradient.set_color(0, Color.WHITE)
		gradient.set_color(1, Color(1, 1, 1, 0))
		var texture := GradientTexture2D.new()
		texture.gradient = gradient
		texture.fill = GradientTexture2D.FILL_RADIAL
		texture.fill_from = Vector2(0.5, 0.5)
		texture.fill_to = Vector2(0.5, 0.0)
		texture.width = 32
		texture.height = 32
		_dot = texture
	return _dot


## Where a control's centre is, in `layer`'s coordinates.
static func center_in(control: Control, layer: Control) -> Vector2:
	return layer.get_global_transform().affine_inverse() * control.get_global_rect().get_center()
