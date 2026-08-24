extends SceneTree

const ForgeV2StageControllerScript = preload(
	"res://runtime/forge_v2/forge_v2_stage_controller.gd"
)
const ForgeV2VolumePreviewPresenterScript = preload(
	"res://runtime/forge_v2/forge_v2_volume_preview_presenter.gd"
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

const RESULT_PATH := (
	"C:/WORKSPACE/godot_runs/"
	+ "verify_forge_v2_workpiece_solid_end_to_end_2026-08-15.txt"
)
const BACKEND_ID := &"chunked_labelled_solid_v1"
const MATERIAL_ID := &"mat_iron_gray"
const MATERIAL_SURFACE_COLLISION_LAYER := 1 << 20

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(RESULT_PATH.get_base_dir())
	var controller: Node = ForgeV2StageControllerScript.new()
	root.add_child(controller)
	var state: Resource = controller.call(
		"ensure_authoring_state",
		"Chunk Solid End To End Gate"
	) as Resource
	_require(state != null, "controller did not create authoring state")

	var presenter: Node3D = ForgeV2VolumePreviewPresenterScript.new()
	presenter.set("surface_targeting_enabled", true)
	root.add_child(presenter)
	presenter.call("bind_stage_controller", controller)
	await process_frame

	_append_pending_profile_body(state, &"e2e_base")
	var base_layer: Resource = controller.call(
		"commit_pending_material_bodies_as_layer"
	) as Resource
	_require(base_layer != null, "supported profile body did not commit")
	await process_frame

	var base_snapshot: Dictionary = controller.call(
		"get_workpiece_render_snapshot"
	) as Dictionary
	_require(
		StringName(base_snapshot.get("backend_id")) == BACKEND_ID,
		"controller did not publish the chunk-solid backend"
	)
	_require(
		int(base_snapshot.get("revision", 0)) == 1,
		"first accepted body did not publish revision one"
	)
	var mesh_root := presenter.get_node_or_null(
		"ChunkWorkpieceRoot/ChunkMeshes"
	) as Node3D
	_require(
		mesh_root != null and mesh_root.get_child_count() > 0,
		"real controller signal did not publish chunk meshes"
	)
	var surface_body := presenter.get_node_or_null(
		"ChunkWorkpieceRoot/ChunkWorkpieceSurfaceBody"
	) as StaticBody3D
	_require(surface_body != null, "targeting presenter omitted surface body")
	_require(
		surface_body.collision_layer == MATERIAL_SURFACE_COLLISION_LAYER
		and bool(surface_body.get_meta("forge_v2_material_surface", false))
		and StringName(surface_body.get_meta(
			"forge_v2_surface_target_id",
			StringName()
		)) == StringName(base_snapshot.get("surface_target_id"))
		and StringName(surface_body.get_meta(
			"forge_v2_material_variant_id",
			StringName()
		)) == MATERIAL_ID,
		"real workpiece collision metadata is invalid"
	)
	_require(
		surface_body.get_child_count() == mesh_root.get_child_count(),
		"chunk mesh/collider publication counts diverged"
	)
	await physics_frame
	var ray_query := PhysicsRayQueryParameters3D.create(
		Vector3(0.0, 0.0, 1.0),
		Vector3(0.0, 0.0, -1.0),
		MATERIAL_SURFACE_COLLISION_LAYER
	)
	ray_query.collide_with_areas = false
	ray_query.collide_with_bodies = true
	var ray_hit: Dictionary = root.world_3d.direct_space_state.intersect_ray(
		ray_query
	)
	_require(
		ray_hit.get("collider", null) == surface_body,
		"workspace-local physics ray did not hit the chunk workpiece"
	)
	_require(
		presenter.get_node_or_null("MaterialBodyCsgRoot") == null
		and _count_csg_shapes(
			presenter.get_node("ChunkWorkpieceRoot")
		) == 0,
		"committed workpiece route contains live CSG"
	)

	var epoch_before_noop := int(base_snapshot.get("engine_epoch", -1))
	var mesh_instances_before := _capture_chunk_instance_ids(mesh_root)
	var collision_instances_before := _capture_chunk_instance_ids(surface_body)
	_append_pending_profile_body(state, &"e2e_noop")
	var noop_layer: Resource = controller.call(
		"commit_pending_material_bodies_as_layer"
	) as Resource
	_require(noop_layer != null, "valid full-overlap no-op did not commit")
	await process_frame

	var noop_snapshot: Dictionary = controller.call(
		"get_workpiece_render_snapshot"
	) as Dictionary
	_require(
		int(noop_snapshot.get("engine_epoch", -2)) == epoch_before_noop,
		"ordinary no-op replaced the engine instance"
	)
	_require(
		int(noop_snapshot.get("revision", 0)) == 2,
		"accepted no-op did not advance source revision"
	)
	_require(
		(noop_layer.get("ledger_delta") as Dictionary).is_empty(),
		"full-overlap no-op consumed material"
	)
	_require(
		mesh_instances_before == _capture_chunk_instance_ids(mesh_root),
		"no-op replaced an unchanged chunk MeshInstance"
	)
	_require(
		collision_instances_before == _capture_chunk_instance_ids(surface_body),
		"no-op rebuilt an unchanged chunk collider"
	)
	_require(
		presenter.get_node_or_null("MaterialBodyCsgRoot") == null
		and _count_csg_shapes(
			presenter.get_node("ChunkWorkpieceRoot")
		) == 0,
		"no-op publication reintroduced committed CSG"
	)

	var visual_presenter: Node3D = ForgeV2VolumePreviewPresenterScript.new()
	root.add_child(visual_presenter)
	visual_presenter.call("bind_stage_controller", controller)
	await process_frame
	_require(
		visual_presenter.get_node_or_null(
			"ChunkWorkpieceRoot/ChunkWorkpieceSurfaceBody"
		) == null,
		"visual-only presenter created targeting collision"
	)
	var visual_mesh_root := visual_presenter.get_node_or_null(
		"ChunkWorkpieceRoot/ChunkMeshes"
	) as Node3D
	_require(
		visual_mesh_root != null
		and visual_mesh_root.get_child_count() == mesh_root.get_child_count(),
		"visual-only presenter did not consume the same solid snapshot"
	)

	var ok := failures.is_empty()
	var file := FileAccess.open(RESULT_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("ok=%s\n" % str(ok))
		file.store_string("backend_id=%s\n" % String(BACKEND_ID))
		file.store_string("real_controller_presenter_signal=true\n")
		file.store_string("target_collision=true\n")
		file.store_string("physics_raycast=true\n")
		file.store_string("committed_csg_count=0\n")
		file.store_string("no_op_chunk_resources_reused=true\n")
		for failure: String in failures:
			file.store_string("failure=%s\n" % failure)
		file.close()

	visual_presenter.call("bind_stage_controller", null)
	presenter.call("bind_stage_controller", null)
	visual_presenter.queue_free()
	presenter.queue_free()
	controller.queue_free()
	await process_frame
	print("Forge V2 workpiece solid end-to-end: %s" % (
		"PASS" if ok else "FAIL"
	))
	quit(0 if ok else 1)


func _append_pending_profile_body(state: Resource, body_id: StringName) -> void:
	var body: Resource = ForgeV2MaterialBodyScript.new()
	var points := PackedVector3Array()
	var normals := PackedVector3Array()
	var contacts := PackedVector3Array()
	for point_index in range(5):
		var ratio := float(point_index) / 4.0
		points.append(Vector3(lerpf(-0.32, 0.32, ratio), 0.0, 0.0))
		normals.append(Vector3.BACK)
		contacts.append(Vector3.FORWARD)
	body.set("body_id", body_id)
	body.set("source_record_id", StringName("source_%s" % String(body_id)))
	body.set("body_kind", ForgeV2MaterialBodyScript.BODY_KIND_VOLUME_STROKE)
	body.set("material_variant_id", MATERIAL_ID)
	body.set(
		"operation_mode",
		ForgeV2VolumeStrokeScript.OPERATION_ADD_MATERIAL
	)
	body.set(
		"placement_policy",
		ForgeV2VolumeStrokeScript.PLACEMENT_REPLACE_EXISTING
	)
	body.set("shape_kind", ForgeV2MaterialBodyScript.SHAPE_KIND_PROFILE_PATH)
	body.set("path_points", points)
	body.set("path_surface_normals", normals)
	body.set("path_contact_directions", contacts)
	body.set("profile_id", &"e2e_asymmetric_profile_v1")
	body.set("profile_display_name", "End To End Asymmetric Profile")
	body.set("profile_polygon_2d_meters", PackedVector2Array([
		Vector2(-0.020, -0.016),
		Vector2(0.026, -0.013),
		Vector2(0.033, 0.006),
		Vector2(0.009, 0.026),
		Vector2(-0.022, 0.018),
	]))
	body.set("profile_anchor_2d_meters", Vector2.ZERO)
	body.set(
		"profile_contact_point_relative_2d_meters",
		Vector2(0.0, -0.016)
	)
	body.set(
		"profile_contact_direction_2d",
		ForgeV2ProfileShapeLibraryScript.BASIC_PROFILE_LOCAL_SIX
	)
	body.set("profile_contact_distance_meters", 0.016)
	body.set("profile_runtime_schema_version", 1)
	body.call("normalize")
	var material_bodies: Array = state.get("material_bodies") as Array
	material_bodies.append(body)
	state.set("material_bodies", material_bodies)


func _capture_chunk_instance_ids(parent: Node) -> Dictionary:
	var result: Dictionary = {}
	if parent == null:
		return result
	for child: Node in parent.get_children():
		var chunk_coord: Variant = child.get_meta(
			"forge_v2_chunk_coord",
			null
		)
		if chunk_coord is Vector3i:
			result[chunk_coord] = child.get_instance_id()
	return result


func _count_csg_shapes(node: Node) -> int:
	if node == null:
		return 0
	var count := 1 if node is CSGShape3D else 0
	for child: Node in node.get_children():
		count += _count_csg_shapes(child)
	return count


func _require(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	push_error(message)
