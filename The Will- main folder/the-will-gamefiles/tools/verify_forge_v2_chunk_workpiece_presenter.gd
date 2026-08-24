extends SceneTree

const ForgeV2VolumePreviewPresenterScript = preload(
	"res://runtime/forge_v2/forge_v2_volume_preview_presenter.gd"
)
const ForgeV2WorkspacePreviewScript = preload(
	"res://runtime/forge_v2/forge_v2_workspace_preview.gd"
)

const MATERIAL_SURFACE_COLLISION_LAYER := 1 << 20
const SURFACE_TARGET_ID := &"forge_v2_workpiece_presenter_verify"


class StubStageController:
	extends Node

	signal authoring_state_changed(state)
	signal material_body_preview_changed(state)
	signal placement_cursor_changed(
		local_position: Vector3,
		is_valid: bool,
		radius_meters: float
	)
	signal workpiece_geometry_changed(snapshot: Dictionary)

	var snapshot: Dictionary = {}
	var active_tool_id := &"tool_volume_stroke"
	var has_geometry := true

	func get_active_authoring_state() -> Resource:
		return null

	func get_workpiece_render_snapshot() -> Dictionary:
		return snapshot

	func get_placement_cursor_state() -> Dictionary:
		return {
			"local_position": Vector3.ZERO,
			"is_valid": false,
			"radius_meters": 0.02,
		}

	func get_active_placement_body_id() -> StringName:
		return StringName()

	func has_workpiece_geometry() -> bool:
		return has_geometry

	func get_status_summary() -> Dictionary:
		return {"active_tool": active_tool_id}

	func publish(next_snapshot: Dictionary) -> void:
		snapshot = next_snapshot
		workpiece_geometry_changed.emit(snapshot)


class StubPlacementTargetResolver:
	extends RefCounted

	var last_query := StringName()

	func resolve_from_camera(
		_camera: Camera3D,
		_screen_position: Vector2,
		_workspace_node: Node3D,
		_workspace_contract,
		_ray_plane_epsilon: float
	) -> Dictionary:
		last_query = &"hybrid"
		return {"valid": true, "query": last_query}

	func resolve_material_surface_from_camera(
		_camera: Camera3D,
		_screen_position: Vector2,
		_workspace_node: Node3D,
		_workspace_contract
	) -> Dictionary:
		last_query = &"material"
		return {"valid": true, "query": last_query}

	func resolve_placement_plane_from_camera(
		_camera: Camera3D,
		_screen_position: Vector2,
		_workspace_node: Node3D,
		_workspace_contract,
		_ray_plane_epsilon: float
	) -> Dictionary:
		last_query = &"plane"
		return {"valid": true, "query": last_query}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var first_mesh := _build_test_mesh(0.0)
	var revised_mesh := _build_test_mesh(0.2)
	var second_mesh := _build_test_mesh(1.0)
	var controller := StubStageController.new()
	root.add_child(controller)
	controller.snapshot = _build_snapshot(1, 1, [
		_build_chunk_record(Vector3i.ZERO, first_mesh, 1),
	])

	var visual_presenter: Node3D = ForgeV2VolumePreviewPresenterScript.new()
	var legacy_root := Node3D.new()
	legacy_root.name = "MaterialBodyCsgRoot"
	legacy_root.add_child(CSGBox3D.new())
	visual_presenter.add_child(legacy_root)
	root.add_child(visual_presenter)
	visual_presenter.call("bind_stage_controller", controller)
	await process_frame

	_require(
		visual_presenter.get_node_or_null("MaterialBodyCsgRoot") == null,
		"legacy committed CSG root survived presenter startup"
	)
	var visual_mesh_root := visual_presenter.get_node_or_null(
		"ChunkWorkpieceRoot/ChunkMeshes"
	) as Node3D
	_require(
		visual_mesh_root != null and visual_mesh_root.get_child_count() == 1,
		"visual presenter did not publish the first chunk"
	)
	_require(
		visual_presenter.get_node_or_null(
			"ChunkWorkpieceRoot/ChunkWorkpieceSurfaceBody"
		) == null,
		"visual-only presenter created authoring collision"
	)
	var first_visual_node := visual_mesh_root.get_child(0) as MeshInstance3D
	var first_visual_id := first_visual_node.get_instance_id()

	controller.publish(_build_snapshot(1, 2, [
		_build_chunk_record(Vector3i.ZERO, first_mesh, 1),
		_build_chunk_record(Vector3i.RIGHT, second_mesh, 1),
	]))
	await process_frame
	_require(
		visual_mesh_root.get_child_count() == 2,
		"second chunk was not published"
	)
	var reused_first_node := _find_chunk_mesh(
		visual_mesh_root,
		Vector3i.ZERO
	)
	_require(
		reused_first_node != null
		and reused_first_node.get_instance_id() == first_visual_id,
		"unchanged chunk MeshInstance3D was replaced"
	)
	var second_visual_node := _find_chunk_mesh(
		visual_mesh_root,
		Vector3i.RIGHT
	)
	_require(second_visual_node != null, "second chunk node was not found")
	var second_visual_id := second_visual_node.get_instance_id()

	controller.publish(_build_snapshot(1, 3, [
		_build_chunk_record(Vector3i.RIGHT, second_mesh, 1),
	]))
	await process_frame
	_require(
		visual_mesh_root.get_child_count() == 1
		and not is_instance_valid(first_visual_node)
		and _find_chunk_mesh(
			visual_mesh_root,
			Vector3i.RIGHT
		).get_instance_id() == second_visual_id,
		"stale removal did not preserve the surviving chunk node"
	)
	_require(
		_count_csg_shapes(
			visual_presenter.get_node("ChunkWorkpieceRoot")
		) == 0,
		"chunk workpiece root contains live CSG"
	)

	var targeting_presenter: Node3D = ForgeV2VolumePreviewPresenterScript.new()
	targeting_presenter.set("surface_targeting_enabled", true)
	root.add_child(targeting_presenter)
	controller.snapshot = _build_snapshot(7, 1, [
		_build_chunk_record(Vector3i.ZERO, first_mesh, 4),
	])
	targeting_presenter.call("bind_stage_controller", controller)
	await process_frame
	var surface_body := targeting_presenter.get_node_or_null(
		"ChunkWorkpieceRoot/ChunkWorkpieceSurfaceBody"
	) as StaticBody3D
	_require(surface_body != null, "targeting presenter omitted StaticBody3D")
	_require(
		surface_body.collision_layer == MATERIAL_SURFACE_COLLISION_LAYER
		and surface_body.collision_mask == 0
		and bool(surface_body.get_meta("forge_v2_material_surface", false))
		and StringName(surface_body.get_meta(
			"forge_v2_surface_target_id",
			StringName()
		)) == SURFACE_TARGET_ID
		and StringName(surface_body.get_meta(
			"forge_v2_material_variant_id",
			StringName()
		)) == &"mat_iron_gray",
		"target collider layer or shared workpiece metadata is invalid"
	)
	_require(
		surface_body.get_child_count() == 1
		and surface_body.get_child(0) is CollisionShape3D
		and (surface_body.get_child(0) as CollisionShape3D).shape
		is ConcavePolygonShape3D,
		"targeting presenter did not publish local concave chunk collision"
	)
	var collision_node := surface_body.get_child(0) as CollisionShape3D
	var collision_node_id := collision_node.get_instance_id()
	var first_shape_id := collision_node.shape.get_instance_id()
	var targeting_mesh_node := _find_chunk_mesh(
		targeting_presenter.get_node("ChunkWorkpieceRoot/ChunkMeshes") as Node3D,
		Vector3i.ZERO
	)
	_require(
		targeting_mesh_node != null
		and targeting_mesh_node.transform == Transform3D.IDENTITY
		and collision_node.transform == Transform3D.IDENTITY,
		"full workspace-local chunk geometry was offset by its chunk coordinate"
	)
	controller.publish(_build_snapshot(7, 2, [
		_build_chunk_record(Vector3i.ZERO, _build_test_mesh(0.0), 4),
	]))
	await process_frame
	_require(
		(surface_body.get_child(0) as CollisionShape3D).get_instance_id()
		== collision_node_id
		and (surface_body.get_child(0) as CollisionShape3D).shape.get_instance_id()
		== first_shape_id,
		"unchanged chunk revision rebuilt collision for a republished mesh"
	)
	_require(
		targeting_mesh_node.mesh == first_mesh,
		"unchanged chunk revision replaced its published mesh resource"
	)
	controller.publish(_build_snapshot(7, 3, [
		_build_chunk_record(Vector3i.ZERO, revised_mesh, 5),
	]))
	await process_frame
	_require(
		(surface_body.get_child(0) as CollisionShape3D).get_instance_id()
		== collision_node_id
		and (surface_body.get_child(0) as CollisionShape3D).shape.get_instance_id()
		!= first_shape_id,
		"changed chunk collision did not update in place"
	)

	var workspace := ForgeV2WorkspacePreviewScript.new()
	var workspace_controller := StubStageController.new()
	var target_resolver := StubPlacementTargetResolver.new()
	workspace.set("active_stage_controller", workspace_controller)
	workspace.set("placement_target_resolver", target_resolver)
	root.add_child(workspace)
	await process_frame
	workspace.call("resolve_placement_target", Vector2.ZERO)
	_require(
		target_resolver.last_query == &"material",
		"Volume Stroke retained plane fallback after workpiece creation"
	)
	workspace_controller.active_tool_id = &"tool_spline_line"
	workspace.call("resolve_placement_target", Vector2.ZERO)
	_require(
		target_resolver.last_query == &"hybrid",
		"future free-space Spline routing was incorrectly made material-only"
	)
	var workspace_presenter := workspace.get_node_or_null(
		"VolumePreviewPresenter"
	) as Node3D
	_require(
		workspace_presenter != null
		and bool(workspace_presenter.get("surface_targeting_enabled")),
		"WorkspacePreview did not opt its presenter into surface targeting"
	)

	visual_presenter.call("bind_stage_controller", null)
	targeting_presenter.call("bind_stage_controller", null)
	if workspace_presenter != null:
		workspace_presenter.call("bind_stage_controller", null)
	workspace.queue_free()
	targeting_presenter.queue_free()
	visual_presenter.queue_free()
	controller.queue_free()
	workspace_controller.free()
	await process_frame
	print("FORGE_V2_CHUNK_WORKPIECE_PRESENTER_VERIFY: PASS")
	quit(0)


func _build_snapshot(
	engine_epoch: int,
	revision: int,
	chunk_records: Array
) -> Dictionary:
	return {
		"ok": true,
		"engine_epoch": engine_epoch,
		"revision": revision,
		"surface_target_id": SURFACE_TARGET_ID,
		"chunk_records": chunk_records,
		"summary": {
			"chunk_count": chunk_records.size(),
			"occupied_cell_count": chunk_records.size(),
		},
		"last_result": {"ok": true, "total_ms": 1.0},
		"status_label": "Chunk-local workpiece ready",
	}


func _build_chunk_record(
	chunk_coord: Vector3i,
	mesh: ArrayMesh,
	mesh_revision: int
) -> Dictionary:
	return {
		"chunk_coord": chunk_coord,
		"mesh": mesh,
		"mesh_revision": mesh_revision,
		"material_variant_id": &"mat_iron_gray",
	}


func _build_test_mesh(x_offset: float) -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([
		Vector3(x_offset, 0.0, 0.0),
		Vector3(x_offset + 0.5, 0.0, 0.0),
		Vector3(x_offset, 0.5, 0.0),
	])
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([
		Vector3.BACK,
		Vector3.BACK,
		Vector3.BACK,
	])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _find_chunk_mesh(
	mesh_root: Node3D,
	chunk_coord: Vector3i
) -> MeshInstance3D:
	for child: Node in mesh_root.get_children():
		if (
			child is MeshInstance3D
			and child.get_meta("forge_v2_chunk_coord", Vector3i.ZERO)
			== chunk_coord
		):
			return child as MeshInstance3D
	return null


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
	push_error(
		"FORGE_V2_CHUNK_WORKPIECE_PRESENTER_VERIFY: FAIL: %s" % message
	)
	quit(1)
	await process_frame
