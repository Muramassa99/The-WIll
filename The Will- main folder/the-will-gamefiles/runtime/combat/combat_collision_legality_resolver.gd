extends RefCounted
class_name CombatCollisionLegalityResolver

func evaluate_weapon_pose(
	body_restriction_root: Node3D,
	held_item: Node3D,
	solved_transform: Transform3D,
	constraint_solver
) -> Dictionary:
	var samples: Array[Dictionary] = _collect_weapon_proxy_local_samples(held_item)
	var result := {
		"legal": true,
		"pose_legal": true,
		"sample_count": samples.size(),
		"illegal_sample_count": 0,
		"first_collision": {},
		"colliding_body_region": "",
		"colliding_body_attachment_name": "",
		"colliding_sample_name": "",
		"estimated_clearance_meters": INF,
		"suggested_correction_world": Vector3.ZERO,
	}
	if body_restriction_root == null or held_item == null or constraint_solver == null:
		result["estimated_clearance_meters"] = -1.0
		return result
	var min_clearance: float = INF
	for sample: Dictionary in samples:
		var sample_world: Vector3 = solved_transform * (sample.get("local_position", Vector3.ZERO) as Vector3)
		var point_result: Dictionary = _query_body_point(
			body_restriction_root,
			sample_world,
			constraint_solver
		)
		var clearance: float = float(point_result.get("estimated_clearance_meters", INF))
		if clearance < min_clearance:
			min_clearance = clearance
		if bool(point_result.get("inside", false)) or not bool(point_result.get("legal", true)):
			var collision := {
				"sample_name": String(sample.get("name", "")),
				"sample_world": sample_world,
				"body_region": String(point_result.get("body_region", "")),
				"attachment_name": String(point_result.get("attachment_name", "")),
				"shape_kind": point_result.get("shape_kind", StringName()),
				"estimated_clearance_meters": clearance,
				"suggested_correction_world": point_result.get("suggested_correction_world", Vector3.ZERO),
			}
			result["legal"] = false
			result["pose_legal"] = false
			result["illegal_sample_count"] = int(result.get("illegal_sample_count", 0)) + 1
			if (result.get("first_collision", {}) as Dictionary).is_empty():
				result["first_collision"] = collision
				result["colliding_body_region"] = collision.get("body_region", "")
				result["colliding_body_attachment_name"] = collision.get("attachment_name", "")
				result["colliding_sample_name"] = collision.get("sample_name", "")
				result["suggested_correction_world"] = collision.get("suggested_correction_world", Vector3.ZERO)
				result["estimated_clearance_meters"] = clearance
	if bool(result.get("legal", true)):
		result["estimated_clearance_meters"] = min_clearance if min_clearance < INF else -1.0
	return result

func evaluate_weapon_path(
	body_restriction_root: Node3D,
	held_item: Node3D,
	solved_transforms: Array[Transform3D],
	constraint_solver
) -> Dictionary:
	var result := {
		"legal": true,
		"path_legal": true,
		"path_sample_count": solved_transforms.size(),
		"illegal_pose_count": 0,
		"first_illegal_path_index": -1,
		"first_collision": {},
		"colliding_body_region": "",
		"colliding_body_attachment_name": "",
		"colliding_sample_name": "",
		"estimated_clearance_meters": INF,
		"suggested_correction_world": Vector3.ZERO,
	}
	var min_clearance: float = INF
	for transform_index: int in range(solved_transforms.size()):
		var pose_result: Dictionary = evaluate_weapon_pose(
			body_restriction_root,
			held_item,
			solved_transforms[transform_index],
			constraint_solver
		)
		var clearance: float = float(pose_result.get("estimated_clearance_meters", INF))
		if clearance < min_clearance:
			min_clearance = clearance
		if not bool(pose_result.get("legal", true)):
			result["legal"] = false
			result["path_legal"] = false
			result["illegal_pose_count"] = int(result.get("illegal_pose_count", 0)) + 1
			if int(result.get("first_illegal_path_index", -1)) < 0:
				result["first_illegal_path_index"] = transform_index
				result["first_collision"] = pose_result.get("first_collision", {})
				result["colliding_body_region"] = String(pose_result.get("colliding_body_region", ""))
				result["colliding_body_attachment_name"] = String(pose_result.get("colliding_body_attachment_name", ""))
				result["colliding_sample_name"] = String(pose_result.get("colliding_sample_name", ""))
				result["estimated_clearance_meters"] = clearance
				result["suggested_correction_world"] = pose_result.get("suggested_correction_world", Vector3.ZERO)
	if bool(result.get("legal", true)):
		result["estimated_clearance_meters"] = min_clearance if min_clearance < INF else -1.0
	return result

func _collect_weapon_proxy_local_samples(held_item: Node3D) -> Array[Dictionary]:
	var samples: Array[Dictionary] = []
	if held_item == null:
		return samples
	var proxy_root: Node3D = held_item.get_node_or_null("WeaponBodyRestrictionProxy") as Node3D
	if proxy_root == null:
		return samples
	for sample_node: Node in proxy_root.get_children():
		var sample: Node3D = sample_node as Node3D
		if sample == null:
			continue
		if not String(sample.name).begins_with("WeaponBodySample_"):
			continue
		samples.append({
			"name": String(sample.name),
			"local_position": held_item.to_local(sample.global_position),
		})
	return samples

func _query_body_point(
	body_restriction_root: Node3D,
	point_world: Vector3,
	constraint_solver
) -> Dictionary:
	if constraint_solver != null and constraint_solver.has_method("query_point_body_restriction"):
		return constraint_solver.call("query_point_body_restriction", body_restriction_root, point_world) as Dictionary
	if constraint_solver != null and constraint_solver.has_method("point_inside_body_restriction"):
		var inside: bool = bool(constraint_solver.call("point_inside_body_restriction", body_restriction_root, point_world))
		return {
			"legal": not inside,
			"inside": inside,
			"estimated_clearance_meters": -1.0 if inside else INF,
			"suggested_correction_world": Vector3.ZERO,
		}
	return {
		"legal": true,
		"inside": false,
		"estimated_clearance_meters": -1.0,
		"suggested_correction_world": Vector3.ZERO,
	}
