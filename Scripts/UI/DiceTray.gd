class_name DiceTray
extends Control
## Your dice as 3D dice on a felt tray, rendered at the screen's real resolution (a
## SubViewportContainer would render at the canvas size and blur when the window is larger).
## A throw is choreographed rather than simulated: each
## die arcs in from your side of the table, bounces two or three times resting on its true
## corner or edge, and tumbles to a stop on exactly the face the host rolled (its rotation is
## built backwards from that final face), so the picture always matches the game and nothing
## has to be nudged afterwards. Click dice to choose which ones to reroll; with keys or a pad,
## move onto the tray, pick a die with left and right (it glows faintly) and press it.

signal selection_changed

## Local outward normal of each face index (faces[0] is on top, faces[1] underneath, ...).
const NORMALS: Array[Vector3] = [Vector3.UP, Vector3.DOWN, Vector3.RIGHT, Vector3.LEFT, Vector3.BACK, Vector3.FORWARD]
const TRAY_HALF := Vector2(3.4, 1.25)
const DIE_SHADER := preload("res://Assets/Shaders/die.gdshader")
const INK := Color("2b1c10")
## Half a die's edge, and the radius of its rounded edges and corners.
const DIE_HALF := 0.49
const DIE_ROUND := 0.085
## How far the rounding is divided; more makes smoother highlights.
const ROUND_STEPS := 4
const DIE_BOX := AABB(Vector3(-0.5, -0.5, -0.5), Vector3.ONE)
## The camera: how far it looks down, and how wide a view it has (narrow, so the dice keep
## their shape from one end of the tray to the other).
const CAMERA_PITCH := 66.0
const CAMERA_FOV := 26.0
const RIM := 0.3
const SPACING := 1.35
## How far the two rows of a large set of dice sit from the middle of the tray.
const ROW_OFFSET := 0.62
## A throw's length in seconds at normal animation speed, and the delay between dice.
const THROW_TIME := 1.05
const STAGGER := 0.07
## Bounces: [time the die touches the felt (0..1 of the throw), height of the hop that follows].
const BOUNCES: Array[Vector2] = [Vector2(0.42, 0.62), Vector2(0.7, 0.22), Vector2(0.86, 0.06)]
const LIFT := 0.28

var selectable := false:
	set(value):
		selectable = value
		focus_mode = Control.FOCUS_ALL if value else Control.FOCUS_NONE
		for hint in _key_hints:
			hint.visible = value
		if not value:
			_set_hovered(-1)
			if has_focus():
				release_focus()
			clear_selection()

var _viewport := SubViewport.new()
var _world := Node3D.new()
var _camera := Camera3D.new()
var _candle := OmniLight3D.new()
var _dice: Array[Node3D] = []
## Small numbers on the felt: the key that picks each die while rerolling.
var _key_hints: Array[Label3D] = []
var _faces: Array[PackedInt32Array] = []
var _selected: Dictionary[int, bool] = {}
## The die keys and pads point at while the tray has focus.
var _cursor := 0
## The die under the mouse (-1 if none).
var _hovered := -1
var _font := FontVariation.new()
var _rng := RandomNumberGenerator.new()
var _throw_id := 0
var _camera_rest := Vector3.ZERO
var _time := 0.0
## True while a throw is animating.
var busy := false

static var _die_mesh: ArrayMesh
static var _icon_textures: Dictionary[String, Texture2D] = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	focus_entered.connect(_on_focus_changed)
	focus_exited.connect(_on_focus_changed)
	mouse_exited.connect(_set_hovered.bind(-1))
	resized.connect(queue_redraw)
	_rng.randomize()
	_font.base_font = load("res://Assets/Fonts/Lora-VariableFont_wght.ttf")
	_font.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 600}
	_viewport.own_world_3d = true
	_viewport.gui_disable_input = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	_viewport.size = Vector2i(640, 200)
	add_child(_viewport)
	_viewport.add_child(_world)
	_build_room()
	_frame_camera(float(_viewport.size.x) / _viewport.size.y)
	_match_screen()


func _process(delta: float) -> void:
	_match_screen()
	# The candle breathes, and selected dice bob gently.
	_time += delta
	_candle.light_energy = 1.25 + 0.12 * sin(_time * 7.1) + 0.07 * sin(_time * 13.3 + 1.2)
	if busy:
		return
	for i in _dice.size():
		if _selected.get(i, false) and not Settings.reduced_motion():
			var body := _dice[i]
			body.position.y = 0.5 + LIFT + 0.05 * sin(_time * 4.0 + i)


## Renders one pixel per screen pixel, whatever the window size, interface size or table fit,
## and keeps the whole tray in view.
func _match_screen() -> void:
	var pixels := Vector2i((size * get_screen_transform().get_scale()).ceil()).maxi(2)
	if pixels != _viewport.size:
		_viewport.size = pixels
		_frame_camera(float(pixels.x) / pixels.y)


## Backs the camera away along its view just far enough to see the tray's whole rim.
func _frame_camera(aspect: float) -> void:
	var view := Basis.from_euler(Vector3(deg_to_rad(-CAMERA_PITCH), 0.0, 0.0))
	var forward := -view.z
	var tall := tan(deg_to_rad(CAMERA_FOV) / 2.0)
	var wide := tall * aspect
	var center := Vector3(0.0, 0.0, 0.1)
	var distance := 0.0
	for corner_x: float in [-1.0, 1.0]:
		for corner_z: float in [-1.0, 1.0]:
			var corner := Vector3(corner_x * (TRAY_HALF.x + RIM), 0.36, corner_z * (TRAY_HALF.y + RIM)) - center
			var depth := corner.dot(forward)
			distance = maxf(distance, maxf(absf(corner.dot(view.x)) / wide, absf(corner.dot(view.y)) / tall) - depth)
	_camera.basis = view
	_camera.position = center - forward * distance * 1.01
	_camera_rest = _camera.position


## Where die `index` of `count` rests: one row, or two when there are more than five.
func _slot(index: int, count: int) -> Vector3:
	var per_row := count if count <= 5 else ceili(count / 2.0)
	var row := floori(index / float(per_row)) if count > 5 else 0
	var column := index % per_row
	var in_row := per_row if row == 0 or count <= 5 else count - per_row
	var x := (column - (in_row - 1) / 2.0) * SPACING
	var z := 0.0 if count <= 5 else (-ROW_OFFSET if row == 0 else ROW_OFFSET)
	return Vector3(x, 0.5, z)


## Shows these dice at rest with the given faces up, without animation.
func set_dice(faces: Array[PackedInt32Array], showing: PackedInt32Array) -> void:
	_throw_id += 1
	busy = false
	_ensure_dice(faces)
	for i in _dice.size():
		var body := _dice[i]
		var face := maxi(showing[i] if i < showing.size() else 0, 0)
		body.transform = Transform3D(_upright(face, _rng.randf_range(-0.25, 0.25)), _slot(i, _dice.size()))
		_mark(i)


## Stops any throw in progress at its next step.
func cancel() -> void:
	_throw_id += 1


## Throws the given dice and lands each on its face in `showing`. `speed` scales the throw's
## length (the table's animation speed). Awaitable.
func throw(indices: PackedInt32Array, faces: Array[PackedInt32Array], showing: PackedInt32Array, speed: float = 1.0) -> void:
	_throw_id += 1
	var my_throw := _throw_id
	_ensure_dice(faces)
	if Settings.reduced_motion() or indices.is_empty() or speed <= 0.0:
		set_dice(faces, showing)
		return
	busy = true
	await _throw(my_throw, indices, showing, speed)
	if my_throw == _throw_id:
		busy = false


func _throw(my_throw: int, indices: PackedInt32Array, showing: PackedInt32Array, speed: float) -> void:
	Audio.play(&"dice_shake", -4.0)
	var count := _dice.size()
	var plans: Array[Dictionary] = []
	for k in indices.size():
		var index := indices[k]
		if index >= count:
			continue
		var target := Transform3D(_upright(maxi(showing[index] if index < showing.size() else 0, 0), _rng.randf_range(-0.3, 0.3)),
			_slot(index, count) + Vector3(_rng.randf_range(-0.1, 0.1), 0.0, _rng.randf_range(-0.08, 0.08)))
		# Thrown from your side of the table (near the camera), slightly to the left.
		var start := Vector3(target.origin.x * 0.35 - 1.6 + _rng.randf_range(-0.6, 0.6), 2.4 + _rng.randf_range(0.0, 0.5), TRAY_HALF.y + 1.6)
		# Tumble about an axis across the direction of travel, so the die rolls forwards.
		var travel := (target.origin - start)
		travel.y = 0.0
		var axis := Vector3.UP.cross(travel.normalized()).rotated(Vector3.UP, _rng.randf_range(-0.5, 0.5)).normalized()
		plans.append({
			"body": _dice[index], "start": start, "target": target, "axis": axis,
			"turns": _rng.randf_range(2.2, 3.2) * TAU, "delay": k * STAGGER,
			"wobble": Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), _rng.randf_range(-1, 1)).normalized(),
			"bounce": 0,
		})
		_selected.erase(index)
		_mark(index)
	if plans.is_empty():
		return
	await get_tree().create_timer(0.12 * speed).timeout
	if my_throw != _throw_id:
		return
	Audio.play(&"dice_throw", -2.0)
	var length := THROW_TIME * speed
	var total := length + STAGGER * speed * (plans.size() - 1)
	var elapsed := 0.0
	while elapsed < total:
		await get_tree().process_frame
		if my_throw != _throw_id:
			return
		elapsed += get_process_delta_time()
		for plan in plans:
			var t := clampf((elapsed - float(plan.delay) * speed) / length, 0.0, 1.0)
			_pose(plan, t)
	for plan in plans:
		var body: Node3D = plan.body
		body.transform = plan.target
		_flash(body, 0.6)


## Places one die at moment `t` (0..1) of its throw, and plays its bounces as they happen.
func _pose(plan: Dictionary, t: float) -> void:
	var body: Node3D = plan.body
	var target: Transform3D = plan.target
	# Spin fast at first and come to rest exactly on the target orientation.
	var settle := 1.0 - pow(1.0 - t, 3.0)
	var spin := Basis(plan.axis, float(plan.turns) * (1.0 - settle))
	var wobble := Basis(plan.wobble, 0.5 * (1.0 - settle) * sin(t * 9.0))
	var basis := (spin * wobble * target.basis).orthonormalized()
	# Across the table: fast at first, easing into place.
	var across := 1.0 - pow(1.0 - t, 2.2)
	var start: Vector3 = plan.start
	var ground := start.lerp(target.origin, across)
	# Up and down: the first fall, then hops of shrinking height between the bounces.
	var height := 0.0
	var first: Vector2 = BOUNCES[0]
	if t < first.x:
		var s := t / first.x
		height = (start.y - 0.5) * (1.0 - s * s)
	else:
		for i in BOUNCES.size():
			var from: Vector2 = BOUNCES[i]
			var until := BOUNCES[i + 1].x if i + 1 < BOUNCES.size() else 1.0
			if t >= from.x and t < until:
				var s := (t - from.x) / (until - from.x)
				height = from.y * 4.0 * s * (1.0 - s)
	# Rest on the lowest corner or edge, never sunk into the felt.
	var half_height := 0.5 * (absf(basis.x.y) + absf(basis.y.y) + absf(basis.z.y))
	body.transform = Transform3D(basis, Vector3(ground.x, half_height + height, ground.z))
	var bounce: int = plan.bounce
	if bounce < BOUNCES.size() and t >= BOUNCES[bounce].x:
		plan.bounce = bounce + 1
		_impact(body, bounce)


## A die hits the felt: a knock (quieter each time), a puff of dust and, on the first hit, a nudge.
func _impact(body: Node3D, bounce: int) -> void:
	Audio.play(&"die_hit", -2.0 - 5.0 * bounce)
	_dust(Vector3(body.position.x, 0.02, body.position.z), 1.0 - 0.35 * bounce)
	if bounce == 0:
		_nudge_camera(0.05)


func _dust(at: Vector3, strength: float) -> void:
	var puff := CPUParticles3D.new()
	puff.one_shot = true
	puff.amount = 10
	puff.lifetime = 0.45
	puff.explosiveness = 1.0
	puff.direction = Vector3.UP
	puff.spread = 80.0
	puff.initial_velocity_min = 0.6 * strength
	puff.initial_velocity_max = 1.4 * strength
	puff.gravity = Vector3(0, -1.5, 0)
	puff.damping_min = 2.0
	puff.damping_max = 3.0
	var mesh := SphereMesh.new()
	mesh.radius = 0.05
	mesh.height = 0.1
	var paint := StandardMaterial3D.new()
	paint.albedo_color = Color(0.85, 0.78, 0.62, 0.55)
	paint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = paint
	puff.mesh = mesh
	puff.scale_amount_min = 0.6
	puff.scale_amount_max = 1.3
	var fade := Curve.new()
	fade.add_point(Vector2(0.0, 1.0))
	fade.add_point(Vector2(1.0, 0.0))
	puff.scale_amount_curve = fade
	puff.position = at
	puff.finished.connect(puff.queue_free)
	_world.add_child(puff)
	puff.emitting = true


func _nudge_camera(amount: float) -> void:
	var tween := _camera.create_tween()
	tween.tween_property(_camera, "position", _camera_rest + _camera.basis.z * -amount * 2.0, 0.04)
	tween.tween_property(_camera, "position", _camera_rest, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## Lights a die up for a moment (it landed, or a face changed).
func _flash(body: Node3D, strength: float) -> void:
	var paint := _paint_of(body)
	paint.set_shader_parameter("flash", strength)
	var tween := body.create_tween()
	tween.tween_method(func(v: float) -> void: paint.set_shader_parameter("flash", v), strength, 0.0, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## Shows a newly bought or upgraded face: the die lifts, turns that face to the top, glows
## and settles. Awaitable.
func present_face(die: int, face_index: int, face: int) -> void:
	if die < 0 or die >= _dice.size() or face_index < 0 or face_index >= _faces[die].size():
		return
	var faces := _faces[die]
	faces[face_index] = face
	_faces[die] = faces
	_paint(_dice[die], faces)
	var body := _dice[die]
	var rest := Transform3D(_upright(face_index, _rng.randf_range(-0.2, 0.2)), _slot(die, _dice.size()))
	if Settings.reduced_motion():
		body.transform = rest
		return
	var from := body.transform
	var tween := body.create_tween()
	tween.tween_method(func(t: float) -> void:
		var lifted := rest.origin + Vector3(0, 0.9 * sin(t * PI), 0)
		body.transform = Transform3D(from.basis.slerp(rest.basis, t), from.origin.lerp(lifted, t)), 0.0, 1.0, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	body.transform = rest
	Audio.play(&"die_hit", -6.0)
	_dust(Vector3(rest.origin.x, 0.02, rest.origin.z), 0.6)
	_flash(body, 1.0)


func selected() -> PackedInt32Array:
	var out := PackedInt32Array()
	for i in _dice.size():
		if _selected.get(i, false):
			out.append(i)
	return out


func clear_selection() -> void:
	_selected.clear()
	for i in _dice.size():
		_mark(i)
	selection_changed.emit()


## Selects or unselects a die for the reroll (number keys).
func toggle(index: int) -> void:
	if index >= 0 and index < _dice.size():
		_cursor = index
		_toggle(index)


func _gui_input(event: InputEvent) -> void:
	if not selectable or _dice.is_empty():
		return
	var pointer := event as InputEventMouse
	if pointer:
		_set_hovered(_die_at(pointer.position))
		var click := event as InputEventMouseButton
		if click and click.pressed and click.button_index == MOUSE_BUTTON_LEFT and _hovered >= 0:
			_cursor = _hovered
			_toggle(_hovered)
			accept_event()
		return
	if event.is_action_pressed("ui_left", true) and _cursor > 0:
		_move_cursor(-1)
		accept_event()
	elif event.is_action_pressed("ui_right", true) and _cursor < _dice.size() - 1:
		_move_cursor(1)
		accept_event()
	elif event.is_action_pressed("ui_accept"):
		_toggle(_cursor)
		accept_event()


## The nearest die under a point of this control (-1 if none).
func _die_at(point: Vector2) -> int:
	var pixel := point * Vector2(_viewport.size) / size
	var from := _camera.project_ray_origin(pixel)
	var along := _camera.project_ray_normal(pixel)
	var best := -1
	var nearest := INF
	for i in _dice.size():
		var inverse := _dice[i].global_transform.affine_inverse()
		var hit: Variant = DIE_BOX.intersects_ray(inverse * from, inverse.basis * along)
		if hit != null:
			var distance := from.distance_squared_to(_dice[i].global_transform * (hit as Vector3))
			if distance < nearest:
				nearest = distance
				best = i
	return best


func _set_hovered(index: int) -> void:
	if index == _hovered:
		return
	var before := _hovered
	_hovered = index
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if index >= 0 else Control.CURSOR_ARROW
	if before >= 0:
		_mark(before, false)
	if index >= 0:
		_mark(index, false)
		Audio.play(&"hover", -16.0)


func _move_cursor(step: int) -> void:
	var before := _cursor
	_cursor = clampi(_cursor + step, 0, _dice.size() - 1)
	_mark(before)
	_mark(_cursor)
	Audio.play(&"hover", -12.0)


func _on_focus_changed() -> void:
	_cursor = clampi(_cursor, 0, maxi(_dice.size() - 1, 0))
	for i in _dice.size():
		_mark(i)
	queue_redraw()


func _draw() -> void:
	draw_texture_rect(_viewport.get_texture(), Rect2(Vector2.ZERO, size), false)
	if has_focus():
		draw_style_box(get_theme_stylebox("focus", "Button"), Rect2(Vector2.ZERO, size))


func _toggle(index: int) -> void:
	if not selectable or busy:
		return
	_selected[index] = not _selected.get(index, false)
	Audio.play(&"die_hit", -8.0)
	_mark(index)
	selection_changed.emit()


## Selected dice lift off the felt and glow; the one pointed at glows faintly; the others rest.
func _mark(index: int, settle: bool = true) -> void:
	if index >= _dice.size():
		return
	var body := _dice[index]
	var on: bool = _selected.get(index, false)
	var pointed := index == _hovered or (has_focus() and index == _cursor)
	var paint := _paint_of(body)
	paint.set_shader_parameter("glow", 0.9 if on else (0.35 if pointed else 0.0))
	if busy or not settle:
		return
	var height := 0.5 + (LIFT if on else 0.0)
	if Settings.reduced_motion():
		body.position.y = height
		return
	body.create_tween().tween_property(body, "position:y", height, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _paint_of(body: Node3D) -> ShaderMaterial:
	var mesh: MeshInstance3D = body.get_node("Mesh")
	return mesh.material_override


## Basis that puts face `face_index` on top, turned `yaw` radians around the vertical, with the
## top face's symbol reading upright from the camera.
func _upright(face_index: int, yaw: float) -> Basis:
	var normal := NORMALS[clampi(face_index, 0, 5)]
	var to_top: Basis
	if normal == Vector3.DOWN:
		to_top = Basis(Vector3.RIGHT, PI)
	elif normal == Vector3.UP:
		to_top = Basis.IDENTITY
	else:
		to_top = Basis(Quaternion(normal, Vector3.UP))
	var basis := to_top
	var reading_up := basis * _face_up(face_index)
	var turn := PI - atan2(reading_up.x, reading_up.z) + yaw
	return (Basis(Vector3.UP, turn) * basis).orthonormalized()


func _top_face(body: Node3D) -> int:
	var best := 0
	var best_dot := -2.0
	for i in NORMALS.size():
		var dot := (body.global_basis * NORMALS[i]).dot(Vector3.UP)
		if dot > best_dot:
			best_dot = dot
			best = i
	return best


## The die-local direction that is "up" for the symbol printed on face `index`.
func _face_up(index: int) -> Vector3:
	var normal := NORMALS[index]
	var hint := Vector3.BACK if absf(normal.y) > 0.5 else Vector3.UP
	return (hint - normal * hint.dot(normal)).normalized()


func _ensure_dice(faces: Array[PackedInt32Array]) -> void:
	var added := false
	while _dice.size() > faces.size():
		_dice.pop_back().queue_free()
		_key_hints.pop_back().queue_free()
		_hovered = -1
	while _dice.size() < faces.size():
		_dice.append(_make_die())
		_key_hints.append(_make_key_hint(_dice.size()))
		added = true
	for i in _key_hints.size():
		var at := _slot(i, _dice.size())
		_key_hints[i].position = Vector3(at.x, 0.012, minf(at.z + ROW_OFFSET, TRAY_HALF.y - 0.12))
	for i in faces.size():
		if i >= _faces.size() or _faces[i] != faces[i]:
			_paint(_dice[i], faces[i])
	_faces = faces.duplicate()
	if added:
		_selected.clear()


func _make_die() -> Node3D:
	var body := Node3D.new()
	var mesh := MeshInstance3D.new()
	mesh.name = "Mesh"
	mesh.mesh = _rounded_cube()
	var paint := ShaderMaterial.new()
	paint.shader = DIE_SHADER
	mesh.material_override = paint
	body.add_child(mesh)
	var faces := Node3D.new()
	faces.name = "Faces"
	body.add_child(faces)
	_world.add_child(body)
	return body


func _make_key_hint(number: int) -> Label3D:
	var hint := Label3D.new()
	hint.text = str(number)
	hint.font = _font
	hint.font_size = 64
	hint.pixel_size = 0.0034
	hint.modulate = Color(0.93, 0.87, 0.68, 0.6)
	hint.outline_size = 0
	hint.rotation_degrees = Vector3(-90, 0, 0)
	hint.visible = selectable
	_world.add_child(hint)
	return hint


## One rounded cube shared by all the dice: a grid on each side of a cube, each point pushed
## onto the surface of a smaller cube grown by the rounding radius.
static func _rounded_cube() -> ArrayMesh:
	if _die_mesh:
		return _die_mesh
	var inner := DIE_HALF - DIE_ROUND
	var stops := PackedFloat32Array()
	for i in ROUND_STEPS + 1:
		stops.append(-DIE_HALF + DIE_ROUND * i / ROUND_STEPS)
	for i in ROUND_STEPS + 1:
		stops.append(inner + DIE_ROUND * i / ROUND_STEPS)
	var count := stops.size()
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	for side in NORMALS:
		var across := Vector3.RIGHT if absf(side.x) < 0.5 else Vector3.BACK
		var down := side.cross(across)
		var first := vertices.size()
		for u in count:
			for v in count:
				var point := side * DIE_HALF + across * stops[u] + down * stops[v]
				var core := point.clamp(Vector3.ONE * -inner, Vector3.ONE * inner)
				var normal := (point - core).normalized()
				vertices.append(core + normal * DIE_ROUND)
				normals.append(normal)
		for u in count - 1:
			for v in count - 1:
				var a := first + u * count + v
				var b := a + count
				var corners: Array[PackedInt32Array] = [PackedInt32Array([a, b, b + 1]), PackedInt32Array([a, b + 1, a + 1])]
				for tri in corners:
					# Godot's front faces wind clockwise seen from outside.
					var facing := (vertices[tri[1]] - vertices[tri[0]]).cross(vertices[tri[2]] - vertices[tri[0]]).dot(side)
					indices.append_array(tri if facing < 0.0 else PackedInt32Array([tri[0], tri[2], tri[1]]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	_die_mesh = ArrayMesh.new()
	_die_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return _die_mesh


## The icon with mipmaps, so it stays smooth when drawn smaller than its pixels.
static func _icon_texture(icon_name: String) -> Texture2D:
	if not _icon_textures.has(icon_name):
		var image := Icons.texture(icon_name).get_image()
		if image.is_compressed():
			image.decompress()
		image.generate_mipmaps()
		_icon_textures[icon_name] = ImageTexture.create_from_image(image)
	return _icon_textures[icon_name]


## Puts each face's icon and value on the cube.
func _paint(body: Node3D, faces: PackedInt32Array) -> void:
	var holder: Node3D = body.get_node("Faces")
	for child in holder.get_children():
		child.queue_free()
	for i in mini(faces.size(), NORMALS.size()):
		var normal := NORMALS[i]
		var face_node := Node3D.new()
		var up_hint := Vector3.BACK if absf(normal.y) > 0.5 else Vector3.UP
		face_node.transform = Transform3D(Basis.looking_at(-normal, up_hint), normal * 0.495)
		var kind := Face.kind_of(faces[i])
		var icon := Sprite3D.new()
		icon.texture = _icon_texture(Icons.for_kind(kind))
		icon.pixel_size = 0.0044
		icon.position = Vector3(0, 0.12, 0.006)
		icon.shaded = true
		icon.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		face_node.add_child(icon)
		if kind != Face.Kind.NONE:
			var value := Label3D.new()
			value.text = "x2" if kind == Face.Kind.DOUBLE else str(Face.value_of(faces[i]))
			value.font = _font
			value.font_size = 128
			value.pixel_size = 0.0034
			value.modulate = INK
			value.outline_size = 0
			value.position = Vector3(0, -0.24, 0.006)
			value.shaded = true
			value.double_sided = false
			value.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
			face_node.add_child(value)
		holder.add_child(face_node)


func _build_room() -> void:
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("1c120b")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("e8c39a")
	env.ambient_light_energy = 0.42
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.ssao_enabled = true
	env.ssao_radius = 0.6
	env.ssao_intensity = 1.2
	environment.environment = env
	_world.add_child(environment)

	_camera.keep_aspect = Camera3D.KEEP_HEIGHT
	_camera.fov = CAMERA_FOV
	_world.add_child(_camera)
	_camera.current = true

	var key := DirectionalLight3D.new()
	key.light_color = Color("ffe0b0")
	key.light_energy = 1.05
	key.shadow_enabled = true
	key.shadow_blur = 1.4
	# All the shadow map goes on the tray, which keeps the dice's shadows crisp.
	key.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	key.directional_shadow_max_distance = 40.0
	key.rotation_degrees = Vector3(-62, 28, 0)
	_world.add_child(key)
	_candle.light_color = Color("ff9d4a")
	_candle.light_energy = 1.3
	_candle.omni_range = 9.0
	_candle.shadow_enabled = true
	_candle.position = Vector3(-3.9, 2.6, -1.2)
	_world.add_child(_candle)

	var felt := StandardMaterial3D.new()
	felt.albedo_color = Color("2f5a3f")
	felt.roughness = 1.0
	var weave := FastNoiseLite.new()
	weave.frequency = 0.35
	var felt_noise := NoiseTexture2D.new()
	felt_noise.noise = weave
	felt_noise.seamless = true
	felt.albedo_texture = felt_noise
	var bumps := NoiseTexture2D.new()
	bumps.noise = weave
	bumps.seamless = true
	bumps.as_normal_map = true
	bumps.bump_strength = 4.0
	felt.normal_enabled = true
	felt.normal_texture = bumps
	felt.normal_scale = 0.35
	felt.uv1_scale = Vector3(4, 4, 4)
	_add_box(Vector3(TRAY_HALF.x * 2.0 + RIM, 0.2, TRAY_HALF.y * 2.0 + RIM), Vector3(0, -0.1, 0), felt)
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color("5d3719")
	wood.roughness = 0.55
	var grain := FastNoiseLite.new()
	grain.frequency = 0.08
	grain.fractal_octaves = 3
	var grain_texture := NoiseTexture2D.new()
	grain_texture.noise = grain
	grain_texture.seamless = true
	wood.albedo_texture = grain_texture
	# Projected from the world rather than stretched over each box; the grain runs along x.
	wood.uv1_triplanar = true
	wood.uv1_scale = Vector3(0.05, 0.35, 0.35)
	# The tray's walls, with a low one at the front so it never hides the dice.
	var depth := TRAY_HALF.y * 2.0 + RIM * 2.0
	var width := TRAY_HALF.x * 2.0 + RIM * 2.0
	_add_box(Vector3(width, 0.36, RIM), Vector3(0, 0.18, -TRAY_HALF.y - RIM / 2.0), wood)
	_add_box(Vector3(width, 0.2, RIM), Vector3(0, 0.1, TRAY_HALF.y + RIM / 2.0), wood)
	_add_box(Vector3(RIM, 0.36, depth), Vector3(-TRAY_HALF.x - RIM / 2.0, 0.18, 0), wood)
	_add_box(Vector3(RIM, 0.36, depth), Vector3(TRAY_HALF.x + RIM / 2.0, 0.18, 0), wood)
	# The table beneath it, darker, filling whatever the view shows beyond the walls.
	var table: StandardMaterial3D = wood.duplicate()
	table.albedo_color = Color("2e1c0f")
	_add_box(Vector3(60, 0.2, 60), Vector3(0, -0.3, 0), table)


func _add_box(extent: Vector3, at: Vector3, paint: Material) -> void:
	var mesh := MeshInstance3D.new()
	var cube := BoxMesh.new()
	cube.size = extent
	mesh.mesh = cube
	mesh.material_override = paint
	mesh.position = at
	_world.add_child(mesh)
