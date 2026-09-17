extends RefCounted

const SkinScript = preload("res://tools/grip_plane_proof/measure_digit_skin_surface.gd")
const SliceScript = preload("res://tools/grip_plane_proof/slice_reachable_surface.gd")
const OriginScript = preload("res://core/models/combat_origin_record.gd")

## Offline samples of actual blended skin in one declared calibration plane.
## The output contains only serializable plane coordinates. It does not fit a
## shape, certify contact, or imply that three samples cover intermediate poses.
func prepare(snapshot: Dictionary, reference_skin: Dictionary, context: Dictionary, plane_to_world: Transform3D, plane_origin_id: StringName, reach_m: float) -> Dictionary:
	var started: int = Time.get_ticks_usec()
	var result: Dictionary = {"valid": false, "samples": [], "elapsed_milliseconds": 0.0}
	var slicer = SliceScript.new()
	if plane_origin_id == StringName() or plane_origin_id == OriginScript.ORIGIN_RL_BONE_ROOT or not slicer._valid_plane(plane_to_world):
		return _failed(result, "invalid_named_metric_plane", started)
	if not is_finite(reach_m) or reach_m <= 0.0:
		return _failed(result, "invalid_reach", started)
	for key: String in ["preferred_angles_rad", "min_angles_rad", "max_angles_rad"]:
		if not snapshot.get(key) is Array or snapshot[key].size() != 3:
			return _failed(result, "missing_three_joint_" + key, started)
		for value: Variant in snapshot[key]:
			if not (value is float or value is int) or not is_finite(float(value)):
				return _failed(result, "nonfinite_or_nonnumeric_" + key, started)
	var poses: Array[Dictionary] = []
	for definition: Array in [[&"zero", 0.0], [&"half_preferred", 0.5], [&"preferred", 1.0]]:
		var angles: Array[float] = []
		for index: int in range(3):
			var minimum: float = float(snapshot["min_angles_rad"][index])
			var maximum: float = float(snapshot["max_angles_rad"][index])
			var angle: float = float(definition[1]) * float(snapshot["preferred_angles_rad"][index])
			if minimum > maximum or angle < minimum or angle > maximum:
				return _failed(result, "sample_outside_declared_joint_range:" + String(definition[0]), started)
			angles.append(angle)
		poses.append({"pose_id": definition[0], "angles_rad": angles})
	var skin_builder = SkinScript.new()
	for pose: Dictionary in poses:
		var skin: Dictionary = skin_builder.build_skin_world(snapshot, reference_skin, context, pose["angles_rad"])
		if not bool(skin.get("valid", false)):
			return _failed(result, "skin_reconstruction_failed:" + String(skin.get("reason", "unknown")), started)
		var registry = skin["registry"]
		if registry.has_origin(plane_origin_id):
			return _failed(result, "plane_origin_conflicts_with_skin_frame", started)
		var plane_record = OriginScript.new()
		plane_record.origin_id = plane_origin_id
		plane_record.parent_origin_id = OriginScript.ORIGIN_RL_BONE_ROOT
		plane_record.transform_to_parent = (skin["machine_to_world"] as Transform3D).affine_inverse() * plane_to_world
		plane_record.owner_system = &"digit_skin_outline_preparation"
		plane_record.resolve_phase = skin["resolve_phase"]
		plane_record.space_type = OriginScript.SPACE_TYPE_BONE_FRAME
		plane_record.is_dynamic = false
		if not registry.register_origin(plane_record) or not bool(registry.validate_origin_chain(plane_origin_id).get("ok", false)):
			return _failed(result, "plane_registration_failed", started)
		var surface: Dictionary = {
			"valid": true, "triangles_world": skin["triangles_world"],
			"surface_source_origin_id": skin["posed_mesh_origin_id"],
			"resolved_world_origin_id": skin["resolved_vertices_origin_id"],
		}
		# Reach clips actual intersection segments. Zero padding adds no capsule,
		# disk-boundary closure or other substitute geometry to the skin slice.
		var sliced: Dictionary = slicer.slice(surface, plane_to_world, plane_origin_id, reach_m, 0.0)
		if not bool(sliced.get("valid", false)):
			return _failed(result, "skin_slice_failed:" + String(sliced.get("status", "unknown")), started)
		result["samples"].append({
			"pose_id": pose["pose_id"], "angles_rad": pose["angles_rad"].duplicate(),
			"origin_id": plane_origin_id, "segments_m": sliced["segments"].duplicate(true),
			"contours_m": sliced["contours"].duplicate(true),
			"classification_incomplete": sliced["classification_incomplete"],
			"counts": sliced["counts"].duplicate(true),
		})
	result["valid"] = true
	result["elapsed_milliseconds"] = float(Time.get_ticks_usec() - started) / 1000.0
	return result


func _failed(result: Dictionary, reason: String, started: int) -> Dictionary:
	result["reason"] = reason
	result["elapsed_milliseconds"] = float(Time.get_ticks_usec() - started) / 1000.0
	return result
