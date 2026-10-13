extends SceneTree

## Render the already exported captured meshes from three sides. This tool has
## no access to the live grip owners and never solves or changes their pose.
func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var path := OS.get_environment("THE_WILL_GRIP_MESH_JSON").replace("\\", "/").simplify_path()
	if not path.to_lower().begins_with("c:/workspace/"): quit(1); return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary or data.get("geometry_reposed", true): quit(1); return
	var first := true
	var bounds := AABB()
	for face: Array in data.hand:
		for raw: Array in face:
			var point := Vector3(raw[0], raw[1], raw[2]) * 0.001
			if first: bounds = AABB(point, Vector3.ZERO); first = false
			else: bounds = bounds.expand(point)
	var center := bounds.get_center()
	var span := maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))
	var viewports: Array[SubViewport] = []
	var directions := [Vector3(1,0.5,1), Vector3(-1,0.5,-1), Vector3(0.2,-1,0.2)]
	for direction: Vector3 in directions:
		var viewport := SubViewport.new()
		viewport.size = Vector2i(800, 800)
		viewport.own_world_3d = true
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		viewport.msaa_3d = Viewport.MSAA_4X
		root.add_child(viewport)
		var world := Node3D.new(); viewport.add_child(world)
		var environment := WorldEnvironment.new()
		environment.environment = Environment.new()
		environment.environment.background_mode = Environment.BG_COLOR
		environment.environment.background_color = Color(0.13, 0.15, 0.18)
		environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		environment.environment.ambient_light_color = Color.WHITE
		environment.environment.ambient_light_energy = 0.65
		world.add_child(environment)
		_mesh(world, data.hand, Color(0.96,0.73,0.60))
		_mesh(world, data.weapon, Color(0.45,0.62,0.72))
		var camera := Camera3D.new(); world.add_child(camera)
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = span * 1.3
		camera.near = 0.001; camera.far = 10.0
		camera.position = center + direction.normalized() * span * 3.0
		camera.look_at(center, Vector3.UP)
		var light := DirectionalLight3D.new(); camera.add_child(light)
		light.light_energy = 0.7
		viewports.append(viewport)
	for frame: int in 4: await process_frame
	await RenderingServer.frame_post_draw
	var combined := Image.create(2400,800,false,Image.FORMAT_RGBA8)
	for index: int in viewports.size():
		var capture := viewports[index].get_texture().get_image()
		if capture == null or capture.is_empty(): quit(1); return
		capture.convert(Image.FORMAT_RGBA8)
		combined.blit_rect(capture, Rect2i(0,0,800,800), Vector2i(index*800,0))
	var output := path.trim_suffix(".json") + "_rendered.png"
	if FileAccess.file_exists(output): quit(1); return
	var error := combined.save_png(output)
	print("SURFACE_GRIP_RENDER ", output, " error=", error)
	quit(error)

func _mesh(parent: Node3D, faces: Array, color: Color) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for face: Array in faces:
		for raw: Array in face: surface.add_vertex(Vector3(raw[0],raw[1],raw[2]) * 0.001)
	surface.generate_normals()
	var instance := MeshInstance3D.new()
	instance.mesh = surface.commit()
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = 0.9
	instance.material_override = material
	parent.add_child(instance)
