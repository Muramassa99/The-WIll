extends SceneTree

# Static reconstruction of recorded torso/arm/helper bones on the real mesh.
# Missing finger/opposite-arm poses stay at rest: this is NOT live grip evidence.
const MODEL = preload("res://Josie/josie.tscn")
var options: Dictionary = {}

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--") and arg.contains("="):
			options[arg.get_slice("=", 0).trim_prefix("--")] = arg.substr(arg.find("=") + 1)
	call_deferred("_run")

func _vector(value: Array) -> Vector3:
	return Vector3(float(value[0]), float(value[1]), float(value[2]))

func _rows(folder: String) -> Dictionary:
	var selected: Dictionary = {}
	for line: String in FileAccess.get_file_as_string(folder.path_join("samples.jsonl")).split("\n", false):
		var row: Dictionary = JSON.parse_string(line)
		if (row.phase == "retracted_held" or row.phase == "elbow_corrected_released" or int(row.step) == 24) and not str(row.case).begins_with("R_pass_1"):
			selected[str(row.case).left(1) + "_" + str(row.step)] = row
	return selected

func _run() -> void:
	if not options.has("before") or not options.has("after") or not options.has("out"):
		push_error("Requires --before=<run> --after=<run> --out=<new folder>")
		quit(1)
		return
	var out: String = options.out
	DirAccess.make_dir_recursive_absolute(out)
	var datasets: Array[Dictionary] = [_rows(options.before), _rows(options.after)]
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1024, 768)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.13, 0.16, 0.19)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.7
	viewport.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, -35, 0)
	light.light_energy = 1.5
	viewport.add_child(light)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.current = true
	viewport.add_child(camera)
	var manifest: Dictionary = {"scope": "Static real-mesh arm reconstruction; missing fingers/opposite body remain at rest; no live grip certification.", "images": []}
	for key: String in datasets[0]:
		if not datasets[1].has(key):
			continue
		var side: String = key.left(1)
		var prefix: String = "CC_Base_" + side + "_"
		var reference: Dictionary = datasets[0][key].bones
		var shoulder := _vector(reference[prefix + "Upperarm"].world_position)
		var elbow := _vector(reference[prefix + "Forearm"].world_position)
		var wrist := _vector(reference[prefix + "Hand"].world_position)
		var center: Vector3 = (shoulder + wrist) * 0.5
		var normal: Vector3 = (elbow - shoulder).cross(wrist - elbow).normalized()
		for run_index: int in range(2):
			var model: Node3D = MODEL.instantiate()
			viewport.add_child(model)
			(model.get_node("AnimationPlayer") as AnimationPlayer).stop()
			model.process_mode = Node.PROCESS_MODE_DISABLED
			var sk: Skeleton3D = model.get_node("Josie/Skeleton3D")
			sk.reset_bone_poses()
			var mesh: MeshInstance3D = sk.get_node("Mesh")
			mesh.material_overlay = null
			var material := StandardMaterial3D.new()
			material.albedo_color = Color(0.72, 0.74, 0.77)
			material.roughness = 0.8
			mesh.material_override = material
			var row: Dictionary = datasets[run_index][key]
			var uniform_scale: float = (_vector(row.bones[prefix + "Forearm"].world_position) - _vector(row.bones[prefix + "Upperarm"].world_position)).length() / sk.get_bone_rest(sk.find_bone(prefix + "Forearm")).origin.length()
			for index: int in range(sk.get_bone_count()):
				var name: String = sk.get_bone_name(index)
				if row.bones.has(name):
					var bone: Dictionary = row.bones[name]
					var q: Array = bone.world_quaternion
					sk.set_bone_global_pose(index, Transform3D(Basis(Quaternion(q[0], q[1], q[2], q[3]).normalized()).scaled(Vector3.ONE * uniform_scale), _vector(bone.world_position)))
			for view: int in range(2):
				camera.size = maxf(0.9, (wrist - shoulder).length() * 1.5)
				camera.position = center + (normal + (wrist - shoulder).normalized() * (0.55 if view == 1 else 0.0)).normalized() * 2.0
				camera.look_at(center, Vector3.UP if absf(normal.dot(Vector3.UP)) < 0.95 else Vector3.FORWARD)
				await process_frame
				await RenderingServer.frame_post_draw
				var path: String = out.path_join(("before" if run_index == 0 else "after") + "_" + key + "_view" + str(view) + ".png")
				var error: Error = viewport.get_texture().get_image().save_png(path)
				manifest.images.append({"path": path, "error": error, "phase": row.phase, "case": row.case, "recorded_bones": row.bones.size(), "scale": uniform_scale})
			model.queue_free()
			await process_frame
	FileAccess.open(out.path_join("manifest.json"), FileAccess.WRITE).store_string(JSON.stringify(manifest, "\t"))
	quit()
