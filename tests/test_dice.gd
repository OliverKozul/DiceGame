extends Node
## Throws the 3D dice many times at random target faces and checks every die comes to rest
## showing exactly the face the game rolled. A scene (not a --script) so autoloads exist.
##   godot --headless --path . res://tests/test_dice.tscn -- [throws]

var _failures := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var throws := 12
	var args := OS.get_cmdline_user_args()
	if not args.is_empty() and args[0].is_valid_int():
		throws = args[0].to_int()
	var tray := DiceTray.new()
	tray.size = Vector2(640, 200)
	add_child(tray)
	await get_tree().process_frame
	var faces: Array[PackedInt32Array] = Content.starting_dice()
	faces.append(Content.basic_die())
	faces.append(Content.basic_die())
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var checked := 0
	for n in throws:
		var showing := PackedInt32Array()
		for _i in faces.size():
			showing.append(rng.randi_range(0, 5))
		var indices := PackedInt32Array(range(faces.size())) if n % 3 == 0 else PackedInt32Array([rng.randi_range(0, faces.size() - 1)])
		await tray.throw(indices, faces, showing)
		for i in indices:
			var body: RigidBody3D = tray.get("_dice")[i]
			var top: int = tray.call("_top_face", body)
			var up := (body.global_basis * DiceTray.NORMALS[showing[i]]).dot(Vector3.UP)
			checked += 1
			if top != showing[i] or up < 0.999 or absf(body.global_position.y - 0.5) > 0.01:
				_failures += 1
				printerr("throw %d die %d: wanted face %d, got %d (up %.4f, y %.3f)" % [n, i, showing[i], top, up, body.global_position.y])
		var dice: Array = tray.get("_dice")
		for i in dice.size():
			for j in range(i + 1, dice.size()):
				var a: Vector3 = dice[i].global_position
				var b: Vector3 = dice[j].global_position
				if Vector2(a.x - b.x, a.z - b.z).length() < 1.0:
					_failures += 1
					printerr("throw %d: dice %d and %d overlap" % [n, i, j])
	print("dice checked: %d, failures: %d" % [checked, _failures])
	print("ALL DICE TESTS PASSED" if _failures == 0 else "DICE TESTS FAILED")
	Content.clear_cache()
	Transition.quit_game(1 if _failures else 0)
