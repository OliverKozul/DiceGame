class_name DiceTray
extends SubViewportContainer
## Your dice as real 3D dice on a felt tray. Throws are physical; once the dice settle,
## any die that landed on the wrong face tips over onto the face the host rolled, so the
## picture always matches the game. Click dice to choose which ones to reroll.

signal selection_changed

## Local outward normal of each face index (faces[0] is on top, faces[1] underneath, ...).
const NORMALS: Array[Vector3] = [Vector3.UP, Vector3.DOWN, Vector3.RIGHT, Vector3.LEFT, Vector3.BACK, Vector3.FORWARD]
const TRAY_HALF := Vector2(4.4, 1.35)
const SETTLE_TIMEOUT := 2.6
const TIP_TIME := 0.22
const INK := Color("2b1c10")
const IVORY := Color("f3ead6")
const SELECTED := Color("f0c66a")

var selectable := false:
	set(value):
		selectable = value
		if not value:
			clear_selection()

var _viewport := SubViewport.new()
var _world := Node3D.new()
var _dice: Array[RigidBody3D] = []
var _faces: Array[PackedInt32Array] = []
var _selected: Dictionary[int, bool] = {}
var _font: Font = load("res://Assets/Fonts/Lora-VariableFont_wght.ttf")
var _rng := RandomNumberGenerator.new()
var _throw_id := 0
## True while a throw is animating.
var busy := false


func _ready() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_rng.randomize()
	_viewport.own_world_3d = true
	_viewport.physics_object_picking = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	_viewport.size = Vector2i(640, 200)
	add_child(_viewport)
	_viewport.add_child(_world)
	_build_room()


## Shows these dice at rest with the given faces up, without animation.
func set_dice(faces: Array[PackedInt32Array], showing: PackedInt32Array) -> void:
	_throw_id += 1
	_ensure_dice(faces)
	for i in _dice.size():
		var body := _dice[i]
		body.freeze = true
		var x := (i - (_dice.size() - 1) / 2.0) * 1.45
		body.transform = Transform3D(_upright(maxi(showing[i] if i < showing.size() else 0, 0), _rng.randf_range(-0.3, 0.3)), Vector3(x, 0.5, 0.0))


## Stops any throw in progress at its next step.
func cancel() -> void:
	_throw_id += 1


## Throws the given dice and lands each on its face in `showing`. Awaitable.
func throw(indices: PackedInt32Array, faces: Array[PackedInt32Array], showing: PackedInt32Array) -> void:
	_throw_id += 1
	var my_throw := _throw_id
	_ensure_dice(faces)
	if Settings.reduced_motion() or indices.is_empty():
		set_dice(faces, showing)
		return
	busy = true
	await _throw(my_throw, indices, showing)
	busy = false


func _throw(my_throw: int, indices: PackedInt32Array, showing: PackedInt32Array) -> void:
	Audio.play(&"dice_shake", -4.0)
	var count := indices.size()
	for k in count:
		var body := _dice[indices[k]]
		body.freeze = false
		body.sleeping = false
		var z := (k - (count - 1) / 2.0) * 0.9
		body.global_position = Vector3(-TRAY_HALF.x + 0.7 + (k % 3) * 1.1, 1.8 + k * 0.3, clampf(z, -0.9, 0.9))
		body.global_basis = Basis.from_euler(Vector3(_rng.randf() * TAU, _rng.randf() * TAU, _rng.randf() * TAU))
		body.linear_velocity = Vector3(_rng.randf_range(4.0, 6.5), _rng.randf_range(-0.5, 0.5), _rng.randf_range(-1.5, 1.5))
		body.angular_velocity = Vector3(_rng.randf_range(-18, 18), _rng.randf_range(-18, 18), _rng.randf_range(-18, 18))
	await get_tree().create_timer(0.12).timeout
	Audio.play(&"dice_throw", -2.0)

	var waited := 0.0
	while waited < SETTLE_TIMEOUT:
		await get_tree().physics_frame
		if my_throw != _throw_id:
			return
		waited += get_physics_process_delta_time()
		var moving := false
		for index in indices:
			var body := _dice[index]
			if body.linear_velocity.length() > 0.08 or body.angular_velocity.length() > 0.15:
				moving = true
		if not moving and waited > 0.5:
			break

	for index in indices:
		var body := _dice[index]
		body.freeze = true
		await _settle_on(body, showing[index] if index < showing.size() else 0)
		if my_throw != _throw_id:
			return
	await _spread_out()


## Slides dice apart so none rest on or inside another after squaring up.
func _spread_out() -> void:
	var tween: Tween = null
	var placed: Array[Vector3] = []
	var targets: Dictionary[RigidBody3D, Vector3] = {}
	for body in _dice:
		var spot := body.global_position
		var tries := 0
		while _crowded(spot, placed) and tries < 40:
			tries += 1
			var ring := 1.15 * (1 + floori(tries / 8.0))
			var angle := tries * TAU / 8.0
			spot = body.global_position + Vector3(cos(angle), 0, sin(angle)) * ring
			spot.x = clampf(spot.x, -TRAY_HALF.x + 0.6, TRAY_HALF.x - 0.6)
			spot.z = clampf(spot.z, -TRAY_HALF.y + 0.6, TRAY_HALF.y - 0.6)
		placed.append(spot)
		if spot.distance_to(body.global_position) > 0.01:
			targets[body] = spot
			if tween == null:
				tween = create_tween().set_parallel()
			tween.tween_property(body, "global_position", spot, 0.18).set_ease(Tween.EASE_OUT)
	if tween:
		await tween.finished
		for body in targets:
			body.global_position = targets[body]


func _crowded(spot: Vector3, placed: Array[Vector3]) -> bool:
	for other in placed:
		if Vector2(spot.x - other.x, spot.z - other.z).length() < 1.08:
			return true
	return false


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


func _toggle(index: int) -> void:
	if not selectable:
		return
	_selected[index] = not _selected.get(index, false)
	Audio.play(&"die_hit", -8.0)
	_mark(index)
	selection_changed.emit()


func _mark(index: int) -> void:
	var mesh: MeshInstance3D = _dice[index].get_node("Mesh")
	var paint: StandardMaterial3D = mesh.material_override
	paint.albedo_color = SELECTED if _selected.get(index, false) else IVORY
	paint.emission_enabled = _selected.get(index, false)


## Basis that puts face `face_index` on top, turned `yaw` radians around the vertical.
func _upright(face_index: int, yaw: float) -> Basis:
	var normal := NORMALS[clampi(face_index, 0, 5)]
	var to_top: Basis
	if normal == Vector3.DOWN:
		to_top = Basis(Vector3.RIGHT, PI)
	elif normal == Vector3.UP:
		to_top = Basis.IDENTITY
	else:
		to_top = Basis(Quaternion(normal, Vector3.UP))
	return Basis(Vector3.UP, yaw) * to_top


func _top_face(body: RigidBody3D) -> int:
	var best := 0
	var best_dot := -2.0
	for i in NORMALS.size():
		var dot := (body.global_basis * NORMALS[i]).dot(Vector3.UP)
		if dot > best_dot:
			best_dot = dot
			best = i
	return best


## Rolls the die over its edges until `target` faces up, then squares it to the table.
func _settle_on(body: RigidBody3D, target: int) -> void:
	for _step in 3:
		if _top_face(body) == target:
			break
		var normal := (body.global_basis * NORMALS[target]).normalized()
		var direction := Vector3(normal.x, 0.0, normal.z)
		if direction.length() < 0.5:
			# The target face is underneath: tip towards any side first.
			var side := body.global_basis * NORMALS[2]
			direction = Vector3(side.x, 0.0, side.z)
		# Rolling away from the target face brings it up.
		await _tip(body, -direction.normalized())
	var start := body.global_transform
	var squared := _square_up(start, target)
	var tween := create_tween()
	tween.tween_method(func(t: float) -> void:
		body.global_transform = start.interpolate_with(squared, t), 0.0, 1.0, 0.12)
	await tween.finished
	body.global_transform = squared
	Audio.play(&"die_hit", -10.0)


## The die's transform with face `target` exactly on top and resting on the felt.
func _square_up(from: Transform3D, target: int) -> Transform3D:
	var current_normal := (from.basis * NORMALS[target]).normalized()
	var fix := Basis(Quaternion(current_normal, Vector3.UP)) if current_normal.dot(Vector3.UP) < 0.9999 else Basis.IDENTITY
	var basis := (fix * from.basis).orthonormalized()
	# Turn the die to face the camera squarely, give or take a few degrees, so faces read well.
	var yaw := atan2(-basis.x.z, basis.x.x)
	var square_yaw := roundf(yaw / (PI / 2.0)) * (PI / 2.0) + _rng.randf_range(-0.12, 0.12)
	basis = (Basis(Vector3.UP, square_yaw - yaw) * basis).orthonormalized()
	var origin := from.origin
	origin.y = 0.5
	origin.x = clampf(origin.x, -TRAY_HALF.x + 0.6, TRAY_HALF.x - 0.6)
	origin.z = clampf(origin.z, -TRAY_HALF.y + 0.6, TRAY_HALF.y - 0.6)
	return Transform3D(basis, origin)


## Rolls the die 90 degrees over its bottom edge towards `direction`.
func _tip(body: RigidBody3D, direction: Vector3) -> void:
	var start := body.global_transform
	var pivot := Vector3(start.origin.x, 0.0, start.origin.z) + direction * 0.5
	var axis := Vector3.UP.cross(direction).normalized()
	if axis.length() < 0.5:
		return
	var tween := create_tween()
	tween.tween_method(func(t: float) -> void:
		var turn := Basis(axis, t * PI / 2.0)
		var origin := pivot + turn * (start.origin - pivot)
		origin.y += sin(t * PI) * 0.12
		body.global_transform = Transform3D(turn * start.basis, origin), 0.0, 1.0, TIP_TIME).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	var turned := Basis(axis, PI / 2.0)
	body.global_transform = Transform3D(turned * start.basis, pivot + turned * (start.origin - pivot))
	Audio.play(&"die_hit", -12.0)


func _ensure_dice(faces: Array[PackedInt32Array]) -> void:
	while _dice.size() > faces.size():
		_dice.pop_back().queue_free()
	while _dice.size() < faces.size():
		_dice.append(_make_die(_dice.size()))
	for i in faces.size():
		if i >= _faces.size() or _faces[i] != faces[i]:
			_paint(_dice[i], faces[i])
	_faces = faces.duplicate()


func _make_die(index: int) -> RigidBody3D:
	var body := RigidBody3D.new()
	body.mass = 0.25
	body.continuous_cd = true
	body.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	body.freeze = true
	var physics := PhysicsMaterial.new()
	physics.bounce = 0.35
	physics.friction = 0.7
	body.physics_material_override = physics
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3.ONE
	shape.shape = box
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	mesh.name = "Mesh"
	var cube := BoxMesh.new()
	cube.size = Vector3(0.98, 0.98, 0.98)
	mesh.mesh = cube
	var paint := StandardMaterial3D.new()
	paint.albedo_color = IVORY
	paint.roughness = 0.45
	paint.emission = Color("6b4a10")
	paint.emission_energy_multiplier = 0.6
	mesh.material_override = paint
	body.add_child(mesh)
	var faces := Node3D.new()
	faces.name = "Faces"
	body.add_child(faces)
	body.input_event.connect(func(_camera: Node, event: InputEvent, _pos: Vector3, _normal: Vector3, _shape: int) -> void:
		var click := event as InputEventMouseButton
		if click and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
			_toggle(index))
	_world.add_child(body)
	return body


## Puts each face's icon and value on the cube.
func _paint(body: RigidBody3D, faces: PackedInt32Array) -> void:
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
		icon.texture = Icons.texture(Icons.for_kind(kind))
		icon.pixel_size = 0.0042
		icon.position = Vector3(0, 0.13, 0.006)
		icon.shaded = true
		icon.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		face_node.add_child(icon)
		if kind != Face.Kind.NONE:
			var value := Label3D.new()
			value.text = "x2" if kind == Face.Kind.DOUBLE else str(Face.value_of(faces[i]))
			value.font = _font
			value.font_size = 96
			value.pixel_size = 0.0042
			value.modulate = INK
			value.outline_size = 0
			value.position = Vector3(0, -0.24, 0.006)
			value.shaded = true
			value.double_sided = false
			face_node.add_child(value)
		holder.add_child(face_node)


func _build_room() -> void:
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("1d3328")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("e8c39a")
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment = env
	_world.add_child(environment)

	# Keep the tray's width in view whatever the panel's aspect ratio.
	var camera := Camera3D.new()
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.fov = 55.0
	camera.position = Vector3(0, 10.0, 3.0)
	_world.add_child(camera)
	camera.look_at(Vector3(0, 0, 0.1), Vector3.UP)
	camera.current = true

	var key := DirectionalLight3D.new()
	key.light_color = Color("ffd7a0")
	key.light_energy = 1.1
	key.shadow_enabled = true
	key.rotation_degrees = Vector3(-62, 28, 0)
	_world.add_child(key)
	var candle := OmniLight3D.new()
	candle.light_color = Color("ff9d4a")
	candle.light_energy = 1.4
	candle.omni_range = 9.0
	candle.position = Vector3(-4.5, 3.0, -1.5)
	_world.add_child(candle)

	var felt := StandardMaterial3D.new()
	felt.albedo_color = Color("24412f")
	felt.roughness = 1.0
	var felt_noise := NoiseTexture2D.new()
	felt_noise.noise = FastNoiseLite.new()
	felt_noise.noise.frequency = 0.2
	felt_noise.seamless = true
	felt.albedo_texture = felt_noise
	felt.uv1_scale = Vector3(6, 6, 6)
	_add_box(Vector3(TRAY_HALF.x * 2.0 + 2.0, 0.2, TRAY_HALF.y * 2.0 + 2.0), Vector3(0, -0.1, 0), felt, true)
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color("4a2c16")
	wood.roughness = 0.8
	var depth := TRAY_HALF.y * 2.0 + 0.6
	var width := TRAY_HALF.x * 2.0 + 0.6
	_add_box(Vector3(width, 0.6, 0.3), Vector3(0, 0.3, -TRAY_HALF.y - 0.15), wood, true)
	_add_box(Vector3(width, 4.0, 0.3), Vector3(0, 2.0, TRAY_HALF.y + 0.15), null, true)
	_add_box(Vector3(0.3, 0.6, depth), Vector3(-TRAY_HALF.x - 0.15, 0.3, 0), wood, true)
	_add_box(Vector3(0.3, 0.6, depth), Vector3(TRAY_HALF.x + 0.15, 0.3, 0), wood, true)
	# Invisible walls above the rim keep wild throws inside the tray.
	_add_box(Vector3(width, 3.4, 0.3), Vector3(0, 2.3, -TRAY_HALF.y - 0.15), null, true)
	_add_box(Vector3(0.3, 3.4, depth), Vector3(-TRAY_HALF.x - 0.15, 2.3, 0), null, true)
	_add_box(Vector3(0.3, 3.4, depth), Vector3(TRAY_HALF.x + 0.15, 2.3, 0), null, true)
	# An invisible lid keeps wild throws inside the tray.
	_add_box(Vector3(width, 0.2, depth), Vector3(0, 4.0, 0), null, true)


func _add_box(extent: Vector3, at: Vector3, paint: Material, solid: bool) -> void:
	var body := StaticBody3D.new()
	body.position = at
	if solid:
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = extent
		shape.shape = box
		body.add_child(shape)
	if paint:
		var mesh := MeshInstance3D.new()
		var cube := BoxMesh.new()
		cube.size = extent
		mesh.mesh = cube
		mesh.material_override = paint
		body.add_child(mesh)
	_world.add_child(body)
