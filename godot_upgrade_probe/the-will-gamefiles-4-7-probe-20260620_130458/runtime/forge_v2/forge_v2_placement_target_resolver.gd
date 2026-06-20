extends RefCounted
class_name ForgeV2PlacementTargetResolver

const TARGET_KIND_NONE := &"target_none"
const TARGET_KIND_PLACEMENT_PLANE := &"target_placement_plane"
const TARGET_KIND_WORKSPACE_BOX_FACE := &"target_workspace_box_face"
const TARGET_KIND_MATERIAL_SURFACE := &"target_material_surface"

const MATERIAL_SURFACE_COLLISION_LAYER := 1 << 20

const REJECT_NO_CAMERA := &"reject_no_camera"
const REJECT_NO_WORKSPACE := &"reject_no_workspace"
const REJECT_NO_CONTRACT := &"reject_no_contract"
const REJECT_UNSUPPORTED_MODE := &"reject_unsupported_mode"
const REJECT_PARALLEL_RAY := &"reject_parallel_ray"
const REJECT_BEHIND_CAMERA := &"reject_behind_camera"
const REJECT_OUTSIDE_BUILD_AREA := &"reject_outside_build_area"

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
			var material_surface_result := _resolve_material_surface(
				ray_origin,
				ray_direction,
				camera.far,
				workspace_node,
				workspace_contract
			)
			if bool(material_surface_result.get("valid", false)):
				return material_surface_result
			if StringName(material_surface_result.get("reject_reason", StringName())) == REJECT_OUTSIDE_BUILD_AREA:
				return material_surface_result
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

func _resolve_material_surface(
	ray_origin: Vector3,
	ray_direction: Vector3,
	ray_length_meters: float,
	workspace_node: Node3D,
	workspace_contract
) -> Dictionary:
	var world_3d: World3D = workspace_node.get_world_3d()
	if world_3d == null:
		return _build_invalid_result(REJECT_NO_WORKSPACE)
	var ray_end: Vector3 = ray_origin + (ray_direction * maxf(ray_length_meters, 1.0))
	var ray_query := PhysicsRayQueryParameters3D.create(
		ray_origin,
		ray_end,
		MATERIAL_SURFACE_COLLISION_LAYER
	)
	ray_query.collide_with_areas = false
	ray_query.collide_with_bodies = true
	var hit: Dictionary = world_3d.direct_space_state.intersect_ray(ray_query)
	if hit.is_empty():
		return _build_invalid_result(REJECT_UNSUPPORTED_MODE, {
			"target_kind": TARGET_KIND_MATERIAL_SURFACE,
			"ray_origin": ray_origin,
			"ray_direction": ray_direction,
		})
	var raw_world_position: Vector3 = hit.get("position", Vector3.ZERO) as Vector3
	var raw_local_position: Vector3 = workspace_node.to_local(raw_world_position)
	if not bool(workspace_contract.call("contains_local_position", raw_local_position)):
		return _build_invalid_result(REJECT_OUTSIDE_BUILD_AREA, {
			"target_kind": TARGET_KIND_MATERIAL_SURFACE,
			"raw_local_position": raw_local_position,
			"raw_world_position": raw_world_position,
			"ray_origin": ray_origin,
			"ray_direction": ray_direction,
		})
	var local_position: Vector3 = workspace_contract.call("clamp_local_position", raw_local_position)
	var world_position: Vector3 = workspace_node.to_global(local_position)
	var world_normal: Vector3 = hit.get("normal", -ray_direction) as Vector3
	if world_normal.length_squared() <= 0.000001:
		world_normal = -ray_direction
	world_normal = world_normal.normalized()
	var local_normal: Vector3 = workspace_node.global_transform.basis.inverse() * world_normal
	if local_normal.length_squared() <= 0.000001:
		local_normal = Vector3(0.0, 0.0, 1.0)
	local_normal = local_normal.normalized()
	var collider: Object = hit.get("collider", null) as Object
	return {
		"valid": true,
		"target_kind": TARGET_KIND_MATERIAL_SURFACE,
		"placement_mode": StringName(workspace_contract.get("placement_mode")),
		"local_position": local_position,
		"world_position": world_position,
		"raw_local_position": raw_local_position,
		"raw_world_position": raw_world_position,
		"local_normal": local_normal,
		"world_normal": world_normal,
		"hit_distance": raw_world_position.distance_to(ray_origin),
		"source_body_id": _read_collider_string_name_meta(collider, &"forge_v2_body_id"),
		"source_record_id": _read_collider_string_name_meta(collider, &"forge_v2_material_variant_id"),
		"is_clamped": not raw_local_position.is_equal_approx(local_position),
		"ray_origin": ray_origin,
		"ray_direction": ray_direction,
		"collider": collider,
	}

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
	if not bool(workspace_contract.call("contains_local_position", raw_local_position)):
		return _build_invalid_result(REJECT_OUTSIDE_BUILD_AREA, {
			"target_kind": TARGET_KIND_PLACEMENT_PLANE,
			"raw_local_position": raw_local_position,
			"raw_world_position": raw_world_position,
			"ray_origin": ray_origin,
			"ray_direction": ray_direction,
			"world_normal": world_normal,
			"hit_distance": hit_distance,
		})
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

func _read_collider_string_name_meta(collider: Object, meta_key: StringName) -> StringName:
	if collider == null or not collider.has_method("has_meta") or not collider.has_method("get_meta"):
		return StringName()
	if not bool(collider.call("has_meta", meta_key)):
		return StringName()
	return StringName(collider.call("get_meta", meta_key))
