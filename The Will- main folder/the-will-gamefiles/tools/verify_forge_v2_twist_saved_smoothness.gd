extends SceneTree

# Read-only reproduction of the user's saved multi-plane path. Optional rendered
# output shows the actual CSG mesh and its guide edges in one fixed viewport.
const Presenter = preload("res://runtime/forge_v2/forge_v2_volume_preview_presenter.gd")
const Controller = preload("res://runtime/forge_v2/forge_v2_stage_controller.gd")
const Roll = preload("res://runtime/forge_v2/forge_v2_path_roll.gd")
const SOURCE := "user://forge/player_wip_library_state.tres"
const OUTPUT := "C:/WORKSPACE/test_artifacts/forge_v2_twist_saved_smoothness_20261018"
var failures := PackedStringArray()
var checks := 0
var evidence: Dictionary = {}

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var hash_before := FileAccess.get_sha256(SOURCE)
	var library: Resource = load(SOURCE)
	var state: Resource
	for wip: Resource in library.get("saved_wips"):
		if wip.get("forge_project_name") == "TWIST TEST":
			state = (wip.get("forge_v2_authoring_state") as Resource).duplicate(true)
			break
	if state == null:
		push_error("TWIST TEST draft missing")
		quit(1)
		return
	var stage := Controller.new()
	root.add_child(stage)
	stage.active_authoring_state = state
	var presenter := Presenter.new()
	root.add_child(presenter)
	presenter.active_stage_controller = stage
	var body: Resource = state.call("build_spline_roll_preview_body")
	var source_points: PackedVector3Array = body.get("path_points")
	var interval := float(presenter.call("_resolve_body_path_sampling_interval", body))
	var zero_mesh: ArrayMesh = presenter.call("_build_active_material_body_sweep_mesh", body)
	var guide := Roll.build_body_curve(body, interval)
	var native_mesh := await _bake(presenter, body)
	var guides: Dictionary = guide.get_meta(Roll.FRAME_METADATA)
	var polygon: PackedVector2Array = presenter.call("_resolve_active_body_sweep_polygon", body)
	var native_vertices: PackedVector3Array = native_mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var largest_error := 0.0
	# Compare outer authored edges with the actual CSG result, not another
	# call to the preview frame construction.
	for i in range((guides.points as PackedVector3Array).size()):
		for p: Vector2 in [polygon[1], polygon[5]]:
			var target: Vector3 = guides.points[i] + guides.axis_x[i] * p.x + guides.axis_y[i] * p.y
			var nearest := INF
			for vertex: Vector3 in native_vertices:
				nearest = minf(nearest, target.distance_squared_to(vertex))
			largest_error = maxf(largest_error, sqrt(nearest))
	_check(largest_error < 0.00001, "TWIST TEST guide edges match generated CSG vertices")
	evidence["guide_to_generated_vertex_error_mm"] = largest_error * 1000
	var fine := Roll.build_body_curve(body, 0.0005)
	var fine_data: Dictionary = fine.get_meta(Roll.FRAME_METADATA)
	var angles := []
	var maximum_turn := 0.0
	for i in range(1, source_points.size() - 1):
		var s := float(fine_data.source_offsets[i])
		var angle := _turn(fine, s, polygon[5])
		angles.append({"point": i + 1, "outer_guide_turn_degrees": angle})
		maximum_turn = maxf(maximum_turn, angle)
	_check(maximum_turn < 5.0, "TWIST TEST zero-roll outer guide passes smoothly through dots")
	evidence["dots"] = angles
	var changed_normals := body.duplicate(true)
	var normals: PackedVector3Array = changed_normals.get("path_surface_normals")
	for i in range(1, normals.size()):
		normals[i] = Vector3.DOWN
	changed_normals.set("path_surface_normals", normals)
	var other := Roll.build_body_curve(changed_normals, interval)
	_check((other.get_meta(Roll.FRAME_METADATA) as Dictionary).axis_y == guides.axis_y, "later placement planes cannot add hidden twist")
	var uniform := body.duplicate(true)
	var rolls := PackedFloat64Array()
	rolls.resize(source_points.size())
	rolls.fill(360.0)
	uniform.set("path_roll_degrees", rolls)
	var uniform_mesh: ArrayMesh = presenter.call("_build_active_material_body_sweep_mesh", uniform)
	var zero_vertices: PackedVector3Array = zero_mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var uniform_vertices: PackedVector3Array = uniform_mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var uniform_error := 0.0
	if zero_vertices.size() == uniform_vertices.size():
		for i in range(zero_vertices.size()):
			uniform_error = maxf(uniform_error, zero_vertices[i].distance_to(uniform_vertices[i]))
	else:
		uniform_error = INF
	_check(uniform_error < 0.00001, "uniform full turn preserves actual saved-path surface")
	_check(bool(stage.call("generate_spline_line_csg_noodle")), "Generate succeeds on saved draft clone")
	_check(bool(stage.call("undo_latest_action")), "Generate undo restores pending path")
	var restored: Resource = state.call("build_spline_roll_preview_body")
	_check(restored != null and restored.get("path_points") == source_points, "undo preserves all saved points")
	_check(bool(stage.call("redo_latest_action")), "Generate redo succeeds")
	var generated: Resource = state.call("get_selected_material_body")
	var redo_mesh: ArrayMesh = presenter.call("_build_active_material_body_sweep_mesh", generated)
	_check(redo_mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] == zero_vertices, "redo surface exactly matches pending guide authority")
	_check(FileAccess.get_sha256(SOURCE) == hash_before, "actual player library unchanged")
	if "--render" in OS.get_cmdline_user_args():
		await _render(native_mesh, guides, polygon)
	var report := {"ok": failures.is_empty(), "checks": checks, "failures": failures, "evidence": evidence}
	FileAccess.open(OUTPUT + ".json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	for failure in failures:
		push_error(failure)
	print("Saved TWIST TEST smoothness: %d checks, %d failures; %s" % [checks, failures.size(), JSON.stringify(evidence)])
	presenter.active_stage_controller = null
	presenter.free()
	stage.free()
	quit(0 if failures.is_empty() else 1)

func _turn(curve: Curve3D, station: float, vertex: Vector2) -> float:
	var points := PackedVector3Array()
	for offset: float in [station - 0.0001, station, station + 0.0001]:
		var f := Roll.sample_frame(curve, offset)
		points.append(f.position + f.axis_x * vertex.x + f.axis_y * vertex.y)
	return rad_to_deg((points[1] - points[0]).angle_to(points[2] - points[1]))

func _bake(presenter: Node3D, body: Resource) -> ArrayMesh:
	var csg := CSGCombiner3D.new()
	presenter.add_child(csg)
	presenter.call("_append_csg_body_shape", csg, body, &"mat_iron_gray", false, 0)
	for _frame in range(120):
		await process_frame
		if presenter.call("_csg_shape_generated_mesh_is_ready", csg):
			var mesh := csg.bake_static_mesh()
			csg.free()
			return mesh
	csg.free()
	return ArrayMesh.new()

func _render(mesh: ArrayMesh, data: Dictionary, polygon: PackedVector2Array) -> void:
	root.size = Vector2i(1400, 900)
	var world := Node3D.new()
	root.add_child(world)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("20252b")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.65
	world.add_child(environment)
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("d4dbe2")
	material.roughness = 0.6
	instance.material_override = material
	world.add_child(instance)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, -30, 0)
	world.add_child(light)
	var lines := ImmediateMesh.new()
	var line_material := StandardMaterial3D.new()
	line_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	line_material.albedo_color = Color("ed3760")
	line_material.no_depth_test = true
	lines.surface_begin(Mesh.PRIMITIVE_LINES, line_material)
	for p: Vector2 in [polygon[1], polygon[5]]:
		for i in range(1, (data.points as PackedVector3Array).size()):
			for j in [i - 1, i]:
				lines.surface_add_vertex(data.points[j] + data.axis_x[j] * p.x + data.axis_y[j] * p.y)
	lines.surface_end()
	var rails := MeshInstance3D.new()
	rails.mesh = lines
	world.add_child(rails)
	var center := mesh.get_aabb().get_center()
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = center + Vector3(0.1, 0.5, 2.8)
	camera.look_at(center)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 1.15
	camera.current = true
	var label := Label.new()
	label.text = "TWIST TEST | generated solid + actual guide edges | all 15 twist values = 0"
	label.position = Vector2(24, 20)
	label.add_theme_font_size_override("font_size", 21)
	root.add_child(label)
	for _frame in range(5):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUTPUT + ".png")
	label.free()
	world.free()

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
