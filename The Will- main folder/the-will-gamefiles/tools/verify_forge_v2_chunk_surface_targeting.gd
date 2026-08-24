extends SceneTree

const ForgeV2StageControllerScript = preload(
	"res://runtime/forge_v2/forge_v2_stage_controller.gd"
)
const ForgeV2WorkspacePreviewScript = preload(
	"res://runtime/forge_v2/forge_v2_workspace_preview.gd"
)
const ForgeV2MaterialBodyScript = preload(
	"res://runtime/forge_v2/forge_v2_material_body.gd"
)
const ForgeV2ProfileShapeLibraryScript = preload(
	"res://runtime/forge_v2/forge_v2_profile_shape_library.gd"
)
const ForgeV2VolumeStrokeScript = preload(
	"res://runtime/forge_v2/forge_v2_volume_stroke.gd"
)

const MATERIAL_SURFACE_COLLISION_LAYER := 1 << 20
const MATERIAL_ID := &"mat_iron_gray"

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var controller: Node = ForgeV2StageControllerScript.new()
	root.add_child(controller)
	var state: Resource = controller.call(
		"ensure_authoring_state",
		"Chunk Surface Targeting Gate"
	) as Resource
	var workspace: Node3D = ForgeV2WorkspacePreviewScript.new()
	root.add_child(workspace)
	workspace.call("bind_stage_controller", controller)
	await process_frame

	_append_pending_profile_body(state)
	var accept_start_usec := Time.get_ticks_usec()
	var committed_layer: Resource = controller.call(
		"commit_pending_material_bodies_as_layer"
	) as Resource
	var accept_end_usec := Time.get_ticks_usec()
	_require(committed_layer != null, "real controller rejected test stroke")

	var presenter := workspace.get_node_or_null(
		"VolumePreviewPresenter"
	) as Node3D
	var surface_body := presenter.get_node_or_null(
		"ChunkWorkpieceRoot/ChunkWorkpieceSurfaceBody"
	) as StaticBody3D
	_require(surface_body != null, "accepted stroke omitted surface collider")
	var snapshot: Dictionary = controller.call(
		"get_workpiece_render_snapshot"
	) as Dictionary
	var expected_target_id := StringName(snapshot.get(
		"surface_target_id",
		StringName()
	))
	_require(
		expected_target_id != StringName()
		and StringName(surface_body.get_meta(
			"forge_v2_surface_target_id",
			StringName()
		)) == expected_target_id,
		"accepted collider did not publish its stable surface target id"
	)

	var target_local := Vector3.ZERO
	var camera := workspace.get("camera") as Camera3D
	var target_screen := camera.unproject_position(
		workspace.to_global(target_local)
	)
	var immediate_result: Dictionary = workspace.call(
		"resolve_material_surface_target",
		target_screen
	) as Dictionary
	await process_frame
	var after_process_result: Dictionary = workspace.call(
		"resolve_material_surface_target",
		target_screen
	) as Dictionary
	await physics_frame
	var after_physics_result: Dictionary = workspace.call(
		"resolve_material_surface_target",
		target_screen
	) as Dictionary
	_require(
		bool(after_physics_result.get("valid", false)),
		"real workspace resolver could not target accepted geometry after physics sync"
	)
	_require(
		StringName(after_physics_result.get(
			"surface_target_id",
			StringName()
		)) == expected_target_id,
		"resolver changed the accepted workpiece target identity"
	)

	var mesh_root := presenter.get_node(
		"ChunkWorkpieceRoot/ChunkMeshes"
	) as Node3D
	var local_aabb := _resolve_mesh_root_aabb(mesh_root)
	_require(local_aabb.size.length_squared() > 0.0, "published mesh AABB is empty")
	var center := local_aabb.get_center()
	var margin := 0.25
	var rays := [
		[center + Vector3(local_aabb.size.x * 0.5 + margin, 0.0, 0.0), Vector3.LEFT],
		[center + Vector3(-local_aabb.size.x * 0.5 - margin, 0.0, 0.0), Vector3.RIGHT],
		[center + Vector3(0.0, local_aabb.size.y * 0.5 + margin, 0.0), Vector3.DOWN],
		[center + Vector3(0.0, -local_aabb.size.y * 0.5 - margin, 0.0), Vector3.UP],
		[center + Vector3(0.0, 0.0, local_aabb.size.z * 0.5 + margin), Vector3.FORWARD],
		[center + Vector3(0.0, 0.0, -local_aabb.size.z * 0.5 - margin), Vector3.BACK],
	]
	var directional_hit_count := 0
	for ray: Array in rays:
		var from_local: Vector3 = ray[0]
		var direction_local: Vector3 = ray[1]
		var from_world := workspace.to_global(from_local)
		var to_world := workspace.to_global(
			from_local + direction_local * 1.5
		)
		var query := PhysicsRayQueryParameters3D.create(
			from_world,
			to_world,
			MATERIAL_SURFACE_COLLISION_LAYER
		)
		query.collide_with_areas = false
		query.collide_with_bodies = true
		var hit: Dictionary = root.world_3d.direct_space_state.intersect_ray(
			query
		)
		if hit.get("collider", null) == surface_body:
			directional_hit_count += 1
	_require(
		directional_hit_count == rays.size(),
		"only %d/%d outside-to-workpiece rays hit generated faces" % [
			directional_hit_count,
			rays.size(),
		]
	)

	var backface_enabled_count := 0
	for child: Node in surface_body.get_children():
		if (
			child is CollisionShape3D
			and (child as CollisionShape3D).shape is ConcavePolygonShape3D
			and bool((child as CollisionShape3D).shape.get(
				"backface_collision"
			))
		):
			backface_enabled_count += 1

	print(
		"Forge V2 chunk surface targeting: commit=%.3f ms immediate=%s process=%s physics=%s rays=%d/%d backface=%d/%d"
		% [
			float(accept_end_usec - accept_start_usec) / 1000.0,
			str(bool(immediate_result.get("valid", false))),
			str(bool(after_process_result.get("valid", false))),
			str(bool(after_physics_result.get("valid", false))),
			directional_hit_count,
			rays.size(),
			backface_enabled_count,
			surface_body.get_child_count(),
		]
	)

	var ok := failures.is_empty()
	workspace.call("clear_stage_controller")
	workspace.queue_free()
	controller.queue_free()
	await process_frame
	quit(0 if ok else 1)


func _append_pending_profile_body(state: Resource) -> void:
	var body: Resource = ForgeV2MaterialBodyScript.new()
	var points := PackedVector3Array()
	var normals := PackedVector3Array()
	var contacts := PackedVector3Array()
	for point_index in range(5):
		var ratio := float(point_index) / 4.0
		points.append(Vector3(lerpf(-0.24, 0.24, ratio), 0.0, 0.0))
		normals.append(Vector3.BACK)
		contacts.append(Vector3.FORWARD)
	body.set("body_id", &"targeting_body")
	body.set("source_record_id", &"targeting_source")
	body.set("body_kind", ForgeV2MaterialBodyScript.BODY_KIND_VOLUME_STROKE)
	body.set("material_variant_id", MATERIAL_ID)
	body.set("operation_mode", ForgeV2VolumeStrokeScript.OPERATION_ADD_MATERIAL)
	body.set("placement_policy", ForgeV2VolumeStrokeScript.PLACEMENT_REPLACE_EXISTING)
	body.set("shape_kind", ForgeV2MaterialBodyScript.SHAPE_KIND_PROFILE_PATH)
	body.set("path_points", points)
	body.set("path_surface_normals", normals)
	body.set("path_contact_directions", contacts)
	body.set("profile_id", &"targeting_profile")
	body.set("profile_display_name", "Targeting Profile")
	body.set("profile_polygon_2d_meters", PackedVector2Array([
		Vector2(-0.028, -0.020),
		Vector2(0.028, -0.020),
		Vector2(0.028, 0.020),
		Vector2(-0.028, 0.020),
	]))
	body.set("profile_anchor_2d_meters", Vector2.ZERO)
	body.set("profile_contact_point_relative_2d_meters", Vector2(0.0, -0.020))
	body.set(
		"profile_contact_direction_2d",
		ForgeV2ProfileShapeLibraryScript.BASIC_PROFILE_LOCAL_SIX
	)
	body.set("profile_contact_distance_meters", 0.020)
	body.set("profile_runtime_schema_version", 1)
	body.call("normalize")
	var material_bodies: Array = state.get("material_bodies") as Array
	material_bodies.append(body)
	state.set("material_bodies", material_bodies)


func _resolve_mesh_root_aabb(mesh_root: Node3D) -> AABB:
	var result := AABB()
	var has_result := false
	for child: Node in mesh_root.get_children():
		if not child is MeshInstance3D:
			continue
		var mesh_instance := child as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		var child_aabb := mesh_instance.transform * mesh_instance.mesh.get_aabb()
		if not has_result:
			result = child_aabb
			has_result = true
		else:
			result = result.merge(child_aabb)
	return result


func _require(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	push_error("FORGE_V2_CHUNK_SURFACE_TARGETING: %s" % message)
