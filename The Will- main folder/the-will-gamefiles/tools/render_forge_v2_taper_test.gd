extends SceneTree

# Read-only visual check of the Handle and blade exported by the real Save test.
const DIRECTORY := "C:/WORKSPACE/godot_runs/forge_v2_taper_test"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1600, 800)
	root.title = "Taper_test - saved melee weapon"
	var scene := Node3D.new()
	root.add_child(scene)
	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("1b222b")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("c6d1e0")
	environment.ambient_light_energy = 0.65
	environment_node.environment = environment
	scene.add_child(environment_node)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, -30, 0)
	light.light_energy = 1.6
	scene.add_child(light)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(20, 140, 0)
	fill.light_energy = 0.8
	scene.add_child(fill)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 0.46
	camera.position = Vector3(0.235, 0, 3)
	camera.current = true
	scene.add_child(camera)
	for part: String in ["handle", "blade"]:
		var mesh := load(DIRECTORY.path_join(part + "_mesh.res")) as ArrayMesh
		if mesh == null:
			quit(1)
			return
		var instance := MeshInstance3D.new()
		instance.mesh = mesh
		instance.rotation_degrees.x = 78
		var material := StandardMaterial3D.new()
		material.albedo_color = Color("bac6d8") if part == "blade" else Color("667a91")
		material.metallic = 0.4
		material.roughness = 0.4
		instance.material_override = material
		scene.add_child(instance)
	var canvas := CanvasLayer.new()
	root.add_child(canvas)
	_label(canvas, "Taper_test | Melee Weapon | Fluted Blade", Vector2(40, 36), 28)
	_label(canvas, "Diamond + two tapered steps. 15 cm between spline points. Interior necks 5%; final tip 0%.", Vector2(40, 88), 21)
	for index in range(5):
		var position := camera.unproject_position(Vector3(index * 0.15, -0.13, 0))
		_label(canvas, str(index + 1), position - Vector2(10, 0), 20)
	_label(canvas, "Saved Handle remains unchanged.", Vector2(40, 730), 20)
	for frame_index in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png(DIRECTORY.path_join("overview.png"))
	print("TAPER_TEST_RENDER ", error)
	quit(0 if error == OK else 1)

func _label(parent: Node, text: String, position: Vector2, font_size: int) -> void:
	var label := Label.new()
	label.text = text
	label.position = position
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("d2dce9"))
	parent.add_child(label)
