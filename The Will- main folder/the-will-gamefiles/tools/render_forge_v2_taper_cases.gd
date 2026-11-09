extends SceneTree

# Read-only gallery of meshes emitted by verify_forge_v2_point_transform.gd.
# Run with a rendering driver (not --headless). No Forge/player library loads.
const CASE_DIRECTORY := "C:/WORKSPACE/godot_runs/forge_profile_transform_fluted"
const CASES := [
	["diamond", "Diamond", "Fixed 1 | Expand 3 | Fixed 5\nX +100% | Y +100%"],
	["hard_stop_contract", "Contracted hard stop", "Fixed 2 | Expand 4\nX -95% | Y -95%"],
	["hard_stop_cross_axes", "Independent axes / T step", "Fixed 2 | Expand 4\nX +100% | Y -50%"],
	["pointed_tip", "Pointed endpoint", "Fixed 1 | Expand 6\nX -100% | Y -100%"],
]

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("TAPER_GALLERY: requires a rendering display; no image written")
		quit(2)
		return
	root.size = Vector2i(1700, 1050)
	root.title = "Forge V2 profile Transform - generated mesh inspection"
	var scene := Node3D.new()
	root.add_child(scene)
	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("161e28")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("b6c7db")
	environment.ambient_light_energy = 0.7
	environment_node.environment = environment
	scene.add_child(environment_node)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-32, -28, 0)
	light.light_energy = 1.4
	scene.add_child(light)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(20, 145, 0)
	fill.light_color = Color("9cbfe8")
	fill.light_energy = 0.65
	scene.add_child(fill)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.25
	camera.position = Vector3(0, 0, 4)
	camera.current = true
	scene.add_child(camera)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("ced7e3")
	material.metallic = 0.25
	material.roughness = 0.38
	material.cull_mode = BaseMaterial3D.CULL_BACK
	var canvas := CanvasLayer.new()
	root.add_child(canvas)
	var controls := Control.new()
	controls.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(controls)
	_label(controls, "FORGE V2 | ACTUAL GENERATED FLUTED-BLADE MESHES", Vector2(28, 20), Vector2(1644, 42), 25, Color("e9edf4"))
	_label(controls, "Same original profile and 0.75 m centreline; six spline points spaced 0.15 m apart. All four use the same display scale.", Vector2(28, 62), Vector2(1644, 35), 19, Color("9baec6"))
	var mesh_records: Array[Dictionary] = []
	for index in range(CASES.size()):
		var entry: Array = CASES[index]
		var mesh_path := CASE_DIRECTORY.path_join(String(entry[0]) + "_mesh.res")
		var mesh := ResourceLoader.load(mesh_path, "ArrayMesh", ResourceLoader.CACHE_MODE_IGNORE) as ArrayMesh
		if mesh == null or mesh.get_surface_count() == 0:
			printerr("TAPER_GALLERY: missing generated mesh: ", mesh_path)
			quit(2)
			return
		var bounds := mesh.get_aabb()
		# The fixture runs along X. Turn that axis vertical; view whichever
		# transverse axis is wider so a thin blade's taper remains readable.
		var wide_axis := Vector3.UP if bounds.size.y >= bounds.size.z else Vector3.BACK
		var orient := Basis(Quaternion(Vector3.RIGHT, Vector3.UP))
		var viewed_wide := orient * wide_axis
		var face_angle := atan2(Vector3.UP.dot(viewed_wide.cross(Vector3.RIGHT)), viewed_wide.dot(Vector3.RIGHT))
		orient = Basis(Vector3.UP, face_angle) * orient
		orient = Basis(Vector3.UP, deg_to_rad(-18.0)) * orient
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.mesh = mesh
		mesh_instance.material_override = material
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var display_basis := orient.scaled(Vector3.ONE * 2.0)
		var center := Vector3(-1.2 + 0.8 * index, -0.12, 0)
		mesh_instance.transform = Transform3D(display_basis, center - display_basis * bounds.get_center())
		scene.add_child(mesh_instance)
		var left := 425.0 * index + 12.0
		_label(controls, String(entry[1]), Vector2(left, 115), Vector2(401, 35), 22, Color("efbb63"))
		_label(controls, String(entry[2]), Vector2(left, 155), Vector2(401, 65), 18, Color("b1bfd1"))
		mesh_records.append({"case": entry[0], "mesh": mesh_path, "bounds": {"position": bounds.position, "size": bounds.size}})
	_label(controls, "Two-point selections stop at their chosen boundary. Three-point selections return to the fixed cross-section at both boundaries.", Vector2(28, 984), Vector2(1644, 40), 19, Color("9baec6"))
	for frame_index in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	var output := OS.get_environment("THE_WILL_TAPER_GALLERY_SCREENSHOT").strip_edges()
	if output.is_empty():
		output = CASE_DIRECTORY.path_join("overview.png")
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	var screenshot := root.get_texture().get_image()
	var result := screenshot.save_png(output)
	print("TAPER_GALLERY: ", JSON.stringify({"ok": result == OK, "image": output, "cases": mesh_records}))
	quit(0 if result == OK else 1)

func _label(parent: Control, text: String, position: Vector2, size: Vector2, font_size: int, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.position = position
	label.size = size
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(label)
