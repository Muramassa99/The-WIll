extends RefCounted
class_name ForgeV2PlacementTargetResolver

const TARGET_KIND_NONE := &"target_none"
const TARGET_KIND_PLACEMENT_PLANE := &"target_placement_plane"
const TARGET_KIND_WORKSPACE_BOX_FACE := &"target_workspace_box_face"
const TARGET_KIND_MATERIAL_SURFACE := &"target_material_surface"

const REJECT_NO_CAMERA := &"reject_no_camera"
const REJECT_NO_WORKSPACE := &"reject_no_workspace"
const REJECT_NO_CONTRACT := &"reject_no_contract"
const REJECT_UNSUPPORTED_MODE := &"reject_unsupported_mode"
const REJECT_PARALLEL_RAY := &"reject_parallel_ray"
const REJECT_BEHIND_CAMERA := &"reject_behind_camera"

func resolve_from_camera(
	camera: Camera3D,
	screen_position: Vector2,
	workspace_node: Node3D,
	workspace_contract,
	ray_plane_epsilon: float
) -> Dictionary:
	if camera == null:
		return _build_invalid_result(REJECT_NO_CAMERA)
	if workspace_node == null:
		return _build_invalid_result(REJECT_NO_WORKSPACE)
	if workspace_contract == null:
		return _build_invalid_result(REJECT_NO_CONTRACT)
	if workspace_contract.has_method("normalize"):
		workspace_contract.call("normalize")
	var ray_origin: Vector3 = camera.project_ray_origin(screen_position)
	var ray_direction: Vector3 = camera.project_ray_normal(screen_position).normalized()
	var placement_mode := StringName(workspace_contract.get("placement_mode"))
	match placement_mode:
		&"placement_mode_plane":
			return _resolve_placement_plane(
				ray_origin,
				ray_direction,
				workspace_node,
				workspace_contract,
				ray_plane_epsilon
			)
	return _build_invalid_result(REJECT_UNSUPPORTED_MODE, {
		"placement_mode": placement_mode,
		"ray_origin": ray_origin,
		"ray_direction": ray_direction,
	})

func _resolve_placement_plane(
	ray_origin: Vector3,
	ray_direction: Vector3,
	workspace_node: Node3D,
	workspace_contract,
	ray_plane_epsilon: float
) -> Dictionary:
	var plane_origin_local: Vector3 = workspace_contract.call("get_placement_plane_origin_local")
	var plane_origin_world: Vector3 = workspace_node.to_global(plane_origin_local)
	var local_normal := Vector3(0.0, 0.0, 1.0)
	var world_normal: Vector3 = workspace_node.global_transform.basis * local_normal
	world_normal = world_normal.normalized()
	var denominator: float = world_normal.dot(ray_direction)
	if absf(denominator) <= ray_plane_epsilon:
		return _build_invalid_result(REJECT_PARALLEL_RAY, {
			"target_kind": TARGET_KIND_PLACEMENT_PLANE,
			"ray_origin": ray_origin,
			"ray_direction": ray_direction,
			"world_normal": world_normal,
		})
	var hit_distance: float = world_normal.dot(plane_origin_world - ray_origin) / denominator
	if hit_distance <= 0.0:
		return _build_invalid_result(REJECT_BEHIND_CAMERA, {
			"target_kind": TARGET_KIND_PLACEMENT_PLANE,
			"ray_origin": ray_origin,
			"ray_direction": ray_direction,
			"world_normal": world_normal,
			"hit_distance": hit_distance,
		})
	var raw_world_position: Vector3 = ray_origin + (ray_direction * hit_distance)
	var raw_local_position: Vector3 = workspace_node.to_local(raw_world_position)
	raw_local_position.z = float(workspace_contract.get("placement_plane_z"))
	var local_position: Vector3 = workspace_contract.call("clamp_local_position", raw_local_position)
	var world_position: Vector3 = workspace_node.to_global(local_position)
	return {
		"valid": true,
		"target_kind": TARGET_KIND_PLACEMENT_PLANE,
		"placement_mode": StringName(workspace_contract.get("placement_mode")),
		"local_position": local_position,
		"world_position": world_position,
		"raw_local_position": raw_local_position,
		"raw_world_position": raw_world_position,
		"local_normal": local_normal,
		"world_normal": world_normal,
		"hit_distance": hit_distance,
		"source_body_id": StringName(),
		"source_record_id": StringName(),
		"is_clamped": not raw_local_position.is_equal_approx(local_position),
		"ray_origin": ray_origin,
		"ray_direction": ray_direction,
	}

func _build_invalid_result(reason: StringName, extras: Dictionary = {}) -> Dictionary:
	var result := {
		"valid": false,
		"target_kind": TARGET_KIND_NONE,
		"reject_reason": reason,
		"local_position": Vector3.ZERO,
		"world_position": Vector3.ZERO,
		"local_normal": Vector3.ZERO,
		"world_normal": Vector3.ZERO,
		"source_body_id": StringName(),
		"source_record_id": StringName(),
	}
	for key: Variant in extras.keys():
		result[key] = extras[key]
	return result
