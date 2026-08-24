extends RefCounted
class_name ForgeV2PlacementTargetResolver

const TARGET_KIND_NONE := &"target_none"
const TARGET_KIND_PLACEMENT_PLANE := &"target_placement_plane"
const TARGET_KIND_WORKSPACE_BOX_FACE := &"target_workspace_box_face"
const TARGET_KIND_MATERIAL_SURFACE := &"target_material_surface"
const SURFACE_TARGET_ID_PLACEMENT_PLANE := &"forge_v2_surface_placement_plane"

const MATERIAL_SURFACE_COLLISION_LAYER := 1 << 20

const REJECT_NO_CAMERA := &"reject_no_camera"
const REJECT_NO_WORKSPACE := &"reject_no_workspace"
const REJECT_NO_CONTRACT := &"reject_no_contract"
const REJECT_UNSUPPORTED_MODE := &"reject_unsupported_mode"
const REJECT_PARALLEL_RAY := &"reject_parallel_ray"
const REJECT_BEHIND_CAMERA := &"reject_behind_camera"
const REJECT_OUTSIDE_BUILD_AREA := &"reject_outside_build_area"
const REJECT_INVALID_SURFACE_NORMAL := &"reject_invalid_surface_normal"

const ABC_DOT_EPSILON := 0.000001

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

func resolve_material_surface_from_camera(
	camera: Camera3D,
	screen_position: Vector2,
	workspace_node: Node3D,
	workspace_contract
) -> Dictionary:
	if camera == null:
		return _build_invalid_result(REJECT_NO_CAMERA, {
			"target_kind": TARGET_KIND_MATERIAL_SURFACE,
		})
	if workspace_node == null:
		return _build_invalid_result(REJECT_NO_WORKSPACE, {
			"target_kind": TARGET_KIND_MATERIAL_SURFACE,
		})
	if workspace_contract == null:
		return _build_invalid_result(REJECT_NO_CONTRACT, {
			"target_kind": TARGET_KIND_MATERIAL_SURFACE,
		})
	if workspace_contract.has_method("normalize"):
		workspace_contract.call("normalize")
	var ray_origin: Vector3 = camera.project_ray_origin(screen_position)
	var ray_direction: Vector3 = camera.project_ray_normal(
		screen_position
	).normalized()
	return _resolve_material_surface(
		ray_origin,
		ray_direction,
		camera.far,
		workspace_node,
		workspace_contract
	)

func resolve_placement_plane_from_camera(
	camera: Camera3D,
	screen_position: Vector2,
	workspace_node: Node3D,
	workspace_contract,
	ray_plane_epsilon: float
) -> Dictionary:
	var plane_result_defaults := {
		"target_kind": TARGET_KIND_PLACEMENT_PLANE,
		"surface_target_id": SURFACE_TARGET_ID_PLACEMENT_PLANE,
	}
	if camera == null:
		return _build_invalid_result(REJECT_NO_CAMERA, plane_result_defaults)
	if workspace_node == null:
		return _build_invalid_result(REJECT_NO_WORKSPACE, plane_result_defaults)
	if workspace_contract == null:
		return _build_invalid_result(REJECT_NO_CONTRACT, plane_result_defaults)
	if workspace_contract.has_method("normalize"):
		workspace_contract.call("normalize")
	var ray_origin: Vector3 = camera.project_ray_origin(screen_position)
	var ray_direction: Vector3 = camera.project_ray_normal(
		screen_position
	).normalized()
	return _resolve_placement_plane(
		ray_origin,
		ray_direction,
		workspace_node,
		workspace_contract,
		ray_plane_epsilon
	)

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
	# Forge authoring surfaces are intentionally two-sided. Native exact output
	# does not promise the camera-facing winding used by Godot ray queries.
	ray_query.hit_back_faces = true
	var hit: Dictionary = world_3d.direct_space_state.intersect_ray(ray_query)
	if hit.is_empty():
		return _build_invalid_result(REJECT_UNSUPPORTED_MODE, {
			"target_kind": TARGET_KIND_MATERIAL_SURFACE,
			"ray_origin": ray_origin,
			"ray_direction": ray_direction,
		})
	var collider: Object = hit.get("collider", null) as Object
	var surface_target_id := _read_collider_string_name_meta(
		collider,
		&"forge_v2_surface_target_id"
	)
	var source_body_id := _read_collider_string_name_meta(
		collider,
		&"forge_v2_body_id"
	)
	var source_record_id := _read_collider_string_name_meta(
		collider,
		&"forge_v2_material_variant_id"
	)
	var raw_world_position: Vector3 = hit.get("position", Vector3.ZERO) as Vector3
	var raw_local_position: Vector3 = workspace_node.to_local(raw_world_position)
	if not bool(workspace_contract.call("contains_local_position", raw_local_position)):
		return _build_invalid_result(REJECT_OUTSIDE_BUILD_AREA, {
			"target_kind": TARGET_KIND_MATERIAL_SURFACE,
			"surface_target_id": surface_target_id,
			"raw_local_position": raw_local_position,
			"raw_world_position": raw_world_position,
			"source_body_id": source_body_id,
			"source_record_id": source_record_id,
			"ray_origin": ray_origin,
			"ray_direction": ray_direction,
			"collider": collider,
		})
	var local_position: Vector3 = workspace_contract.call("clamp_local_position", raw_local_position)
	var world_position: Vector3 = workspace_node.to_global(local_position)
	var world_normal: Vector3 = hit.get("normal", Vector3.ZERO) as Vector3
	if world_normal.length_squared() <= 0.000001:
		return _build_invalid_result(REJECT_INVALID_SURFACE_NORMAL, {
			"target_kind": TARGET_KIND_MATERIAL_SURFACE,
			"surface_target_id": surface_target_id,
			"raw_local_position": raw_local_position,
			"raw_world_position": raw_world_position,
			"source_body_id": source_body_id,
			"source_record_id": source_record_id,
			"ray_origin": ray_origin,
			"ray_direction": ray_direction,
			"collider": collider,
		})
	world_normal = world_normal.normalized()
	var local_normal: Vector3 = workspace_node.global_transform.basis.inverse() * world_normal
	if local_normal.length_squared() <= 0.000001:
		return _build_invalid_result(REJECT_INVALID_SURFACE_NORMAL, {
			"target_kind": TARGET_KIND_MATERIAL_SURFACE,
			"surface_target_id": surface_target_id,
			"raw_local_position": raw_local_position,
			"raw_world_position": raw_world_position,
			"source_body_id": source_body_id,
			"source_record_id": source_record_id,
			"ray_origin": ray_origin,
			"ray_direction": ray_direction,
			"world_normal": world_normal,
			"collider": collider,
		})
	local_normal = local_normal.normalized()
	var world_contact_direction := _resolve_world_contact_direction_for_abc(
		ray_origin,
		world_position,
		world_normal,
		ray_direction
	)
	var local_contact_direction := (
		workspace_node.global_transform.basis.inverse()
		* world_contact_direction
	).normalized()
	return {
		"valid": true,
		"target_kind": TARGET_KIND_MATERIAL_SURFACE,
		"surface_target_id": surface_target_id,
		"placement_mode": StringName(workspace_contract.get("placement_mode")),
		"local_position": local_position,
		"world_position": world_position,
		"raw_local_position": raw_local_position,
		"raw_world_position": raw_world_position,
		"local_normal": local_normal,
		"world_normal": world_normal,
		"local_contact_direction": local_contact_direction,
		"world_contact_direction": world_contact_direction,
		"hit_distance": raw_world_position.distance_to(ray_origin),
		"source_body_id": source_body_id,
		"source_record_id": source_record_id,
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
	var canonical_local_normal := Vector3(0.0, 0.0, 1.0)
	var world_normal: Vector3 = (
		workspace_node.global_transform.basis
		* canonical_local_normal
	).normalized()
	var local_normal: Vector3 = (
		workspace_node.global_transform.basis.inverse()
		* world_normal
	)
	if local_normal.length_squared() <= 0.000001:
		local_normal = canonical_local_normal
	local_normal = local_normal.normalized()
	var denominator: float = world_normal.dot(ray_direction)
	if absf(denominator) <= ray_plane_epsilon:
		return _build_invalid_result(REJECT_PARALLEL_RAY, {
			"target_kind": TARGET_KIND_PLACEMENT_PLANE,
			"surface_target_id": SURFACE_TARGET_ID_PLACEMENT_PLANE,
			"ray_origin": ray_origin,
			"ray_direction": ray_direction,
			"world_normal": world_normal,
		})
	var hit_distance: float = world_normal.dot(plane_origin_world - ray_origin) / denominator
	if hit_distance <= 0.0:
		return _build_invalid_result(REJECT_BEHIND_CAMERA, {
			"target_kind": TARGET_KIND_PLACEMENT_PLANE,
			"surface_target_id": SURFACE_TARGET_ID_PLACEMENT_PLANE,
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
			"surface_target_id": SURFACE_TARGET_ID_PLACEMENT_PLANE,
			"raw_local_position": raw_local_position,
			"raw_world_position": raw_world_position,
			"ray_origin": ray_origin,
			"ray_direction": ray_direction,
			"world_normal": world_normal,
			"hit_distance": hit_distance,
		})
	var local_position: Vector3 = workspace_contract.call("clamp_local_position", raw_local_position)
	var world_position: Vector3 = workspace_node.to_global(local_position)
	var world_contact_direction := _resolve_world_contact_direction_for_abc(
		ray_origin,
		world_position,
		world_normal,
		ray_direction
	)
	var local_contact_direction := (
		workspace_node.global_transform.basis.inverse()
		* world_contact_direction
	).normalized()
	return {
		"valid": true,
		"target_kind": TARGET_KIND_PLACEMENT_PLANE,
		"surface_target_id": SURFACE_TARGET_ID_PLACEMENT_PLANE,
		"placement_mode": StringName(workspace_contract.get("placement_mode")),
		"local_position": local_position,
		"world_position": world_position,
		"raw_local_position": raw_local_position,
		"raw_world_position": raw_world_position,
		"local_normal": local_normal,
		"world_normal": world_normal,
		"local_contact_direction": local_contact_direction,
		"world_contact_direction": world_contact_direction,
		"hit_distance": hit_distance,
		"source_body_id": StringName(),
		"source_record_id": StringName(),
		"is_clamped": not raw_local_position.is_equal_approx(local_position),
		"ray_origin": ray_origin,
		"ray_direction": ray_direction,
	}

func _resolve_world_contact_direction_for_abc(
	ray_origin: Vector3,
	hit_position: Vector3,
	raw_world_normal: Vector3,
	ray_direction: Vector3
) -> Vector3:
	var candidate_positive := raw_world_normal.normalized()
	if candidate_positive.length_squared() <= 0.000001:
		return Vector3.ZERO
	var from_b_to_a := ray_origin - hit_position
	if from_b_to_a.length_squared() <= 0.000001:
		from_b_to_a = -ray_direction
	if from_b_to_a.length_squared() <= 0.000001:
		return candidate_positive
	from_b_to_a = from_b_to_a.normalized()
	var candidate_negative := -candidate_positive
	var positive_abc_dot := from_b_to_a.dot(candidate_positive)
	var negative_abc_dot := from_b_to_a.dot(candidate_negative)
	var positive_is_valid := positive_abc_dot <= ABC_DOT_EPSILON
	var negative_is_valid := negative_abc_dot <= ABC_DOT_EPSILON
	if positive_is_valid and not negative_is_valid:
		return candidate_positive
	if negative_is_valid and not positive_is_valid:
		return candidate_negative
	if absf(positive_abc_dot - negative_abc_dot) <= ABC_DOT_EPSILON:
		return candidate_positive
	return (
		candidate_positive
		if positive_abc_dot < negative_abc_dot
		else candidate_negative
	)

func _build_invalid_result(reason: StringName, extras: Dictionary = {}) -> Dictionary:
	var result := {
		"valid": false,
		"target_kind": TARGET_KIND_NONE,
		"surface_target_id": StringName(),
		"reject_reason": reason,
		"local_position": Vector3.ZERO,
		"world_position": Vector3.ZERO,
		"local_normal": Vector3.ZERO,
		"world_normal": Vector3.ZERO,
		"local_contact_direction": Vector3.ZERO,
		"world_contact_direction": Vector3.ZERO,
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
