extends SceneTree

const SolverScript = preload("res://runtime/player/player_finger_surface_grip_solver.gd")
const SliceScript = preload("res://core/resolvers/primary_grip_seat_resolver.gd")
const OriginScript = preload("res://core/models/combat_origin_record.gd")
const RegistryScript = preload("res://core/resolvers/combat_origin_registry.gd")
var solver = SolverScript.new()

## Offline measurement only. Captured triangles and bone frames share the solve
## stage's world presentation. Contours are intersections, not grip acceptance.
func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var started: int = Time.get_ticks_usec()
	var input_path: String = OS.get_environment("THE_WILL_GRIP_CAPTURE_PATH")
	var file := FileAccess.open(input_path, FileAccess.READ)
	if file == null:
		_fail("Provide THE_WILL_GRIP_CAPTURE_PATH.")
		return
	var input_variant: Variant = file.get_var()
	file.close()
	if not input_variant is Dictionary:
		_fail("Capture is not a dictionary.")
		return
	var input: Dictionary = input_variant
	var frame: Dictionary = input.get("capture_frame", {})
	if frame.get("machine_origin_id") != OriginScript.ORIGIN_RL_BONE_ROOT or frame.get("resolve_phase") != OriginScript.PHASE_EDITOR_PREVIEW or frame.get("capture_stage") != &"finger_solve_input" or not frame.get("machine_to_world") is Transform3D:
		_fail("Missing coherent finger-solve RL_BoneRoot frame; no identity substitution.")
		return
	var machine_to_world: Transform3D = frame["machine_to_world"]
	if not _frame_valid(machine_to_world):
		_fail("Captured machine frame is nonfinite or singular.")
		return
	var surface: Dictionary = input.get("surface", {})
	var triangles: PackedVector3Array = surface.get("triangles_world", PackedVector3Array())
	if not bool(surface.get("valid", false)) or surface.get("resolved_world_origin_id") != OriginScript.ORIGIN_RL_BONE_ROOT or StringName(surface.get("surface_source_origin_id", &"")) == StringName() or triangles.is_empty() or triangles.size() % 3 != 0:
		_fail("Missing valid captured Handle triangles/origin.")
		return
	for point: Vector3 in triangles:
		if not point.is_finite():
			_fail("Captured Handle contains nonfinite geometry.")
			return
	var output: Dictionary = {
		"schema": "digit_motion_slices_v1", "input": input_path, "slot": input.get("slot"),
		"root_origin_id": frame["machine_origin_id"], "resolve_phase": frame["resolve_phase"],
		"capture_stage": frame["capture_stage"], "machine_to_world": _transform_numbers(machine_to_world),
		"surface_source_origin_id": surface["surface_source_origin_id"],
		"surface_signature": surface.get("surface_signature"), "triangle_count": triangles.size() / 3,
		"projection_is_not_a_contact_or_planarity_certificate": true, "digits": {},
	}
	var digits: Dictionary = input.get("digits", {})
	for digit_id: String in ["thumb", "index", "middle", "ring", "pinky"]:
		var snapshot: Dictionary = (digits.get(digit_id, {}) as Dictionary).get("snapshot", {})
		var row: Dictionary = {"raw": _measure(snapshot, frame, triangles, "Raw")}
		if digit_id == "thumb" and bool((row["raw"] as Dictionary).get("valid", false)):
			var prepared: Dictionary = solver._build_exact_collinear_thumb_snapshot(snapshot)
			row["preparation_status"] = prepared.get("status")
			row["preparation_is_collinear_zero_only"] = true
			if bool(prepared.get("valid", false)):
				row["prepared"] = _measure(prepared["snapshot"], frame, triangles, "Prepared")
			else:
				row["prepared"] = {"valid": false, "reason": prepared.get("status")}
		output["digits"][digit_id] = row
	output["elapsed_milliseconds"] = float(Time.get_ticks_usec() - started) / 1000.0
	var result_path: String = "C:/WORKSPACE/test_artifacts/digit_motion_slices_" + Time.get_datetime_string_from_system().replace(":", "-") + ".json"
	var result_file := FileAccess.open(result_path, FileAccess.WRITE)
	if result_file == null:
		_fail("Cannot write diagnostic JSON.")
		return
	result_file.store_string(JSON.stringify(output, "\t"))
	result_file.close()
	print("DIGIT_MOTION_SLICES_RESULT=" + result_path)
	quit(0)


func _measure(snapshot: Dictionary, frame: Dictionary, triangles: PackedVector3Array, variant_name: String) -> Dictionary:
	var started: int = Time.get_ticks_usec()
	var reason: String = _snapshot_reason(snapshot)
	if not reason.is_empty():
		return {"valid": false, "reason": reason}
	var zero_angles: Array[float] = [0.0, 0.0, 0.0]
	var fk: Dictionary = solver._forward_kinematics(snapshot, zero_angles)
	var points: Array[Vector3] = _fk_points(fk)
	var first_basis: Basis = (fk["joint_transforms_world"][0] as Transform3D).basis
	var normal: Vector3 = first_basis.x.cross(first_basis.y).normalized()
	var first_segment: Vector3 = points[1] - points[0]
	var axis_u: Vector3 = first_segment - normal * first_segment.dot(normal)
	if normal.length_squared() < 0.5 or axis_u.length_squared() < 0.000000000001:
		return {"valid": false, "reason": "degenerate_motion_plane"}
	axis_u = axis_u.normalized()
	var plane_to_world := Transform3D(Basis(axis_u, normal.cross(axis_u).normalized(), normal), points[0])
	var source_bones: Array = snapshot["bone_names"]
	var side: String = "Right" if String(source_bones[0]).begins_with("CC_Base_R_") else "Left"
	var origin = OriginScript.new()
	origin.origin_id = StringName(side + String(snapshot["digit_id"]).capitalize() + variant_name + "MotionPlaneOrigin")
	origin.parent_origin_id = OriginScript.ORIGIN_RL_BONE_ROOT
	origin.transform_to_parent = (frame["machine_to_world"] as Transform3D).affine_inverse() * plane_to_world
	origin.owner_system = &"diagnose_digit_motion_slices"
	origin.resolve_phase = frame["resolve_phase"]
	origin.space_type = OriginScript.SPACE_TYPE_BONE_FRAME
	origin.is_dynamic = true
	var registry = RegistryScript.new()
	if not registry.register_origin(origin) or not bool(registry.validate_origin_chain(origin.origin_id).get("ok", false)):
		return {"valid": false, "reason": "plane_registration_failed"}
	var samples: Array[Dictionary] = [_sample(snapshot, zero_angles, plane_to_world, "zero")]
	var lengths: Array[float] = []
	var radii: Array[float] = []
	var limits: Array = []
	for joint_index: int in range(3):
		lengths.append(points[joint_index].distance_to(points[joint_index + 1]) * 1000.0)
		radii.append(float(snapshot["capsule_radii_m"][joint_index]) * 1000.0)
		limits.append([rad_to_deg(float(snapshot["min_angles_rad"][joint_index])), rad_to_deg(float(snapshot["max_angles_rad"][joint_index]))])
		for bound: String in ["min", "max"]:
			var angles: Array[float] = zero_angles.duplicate()
			angles[joint_index] = float(snapshot[bound + "_angles_rad"][joint_index])
			samples.append(_sample(snapshot, angles, plane_to_world, "joint_%d_%s" % [joint_index + 1, bound]))
	var max_depth: float = 0.0
	var max_tilt: float = 0.0
	for sample: Dictionary in samples:
		for depth: float in sample["depths_mm"]:
			max_depth = maxf(max_depth, absf(depth))
		for tilt: float in sample["normal_tilts_degrees"]:
			max_tilt = maxf(max_tilt, tilt)
	var slice: Dictionary = _slice_contours(triangles, plane_to_world)
	return {
		"valid": true, "plane_origin_id": origin.origin_id, "source_bones": source_bones,
		"tip_offset_source_origin_id": snapshot["tip_offset_origin_id"],
		"root_origin_id": origin.parent_origin_id, "owner_system": origin.owner_system,
		"resolve_phase": origin.resolve_phase, "is_dynamic": origin.is_dynamic,
		"origin_chain_ids": registry.validate_origin_chain(origin.origin_id)["chain_ids"],
		"plane_to_machine": _transform_numbers(origin.transform_to_parent), "plane_to_world": _transform_numbers(plane_to_world),
		"zero_points_2d_mm": samples[0]["points_2d_mm"], "zero_depths_mm": samples[0]["depths_mm"],
		"section_lengths_mm": lengths, "capsule_radii_mm": radii, "angle_limits_degrees": limits,
		"coplanarity_samples": samples, "max_sample_depth_mm": max_depth, "max_sample_normal_tilt_degrees": max_tilt,
		"coplanarity_measurement_is_sampled": true,
		"handle_contours_2d_mm": slice["contours"], "handle_segments_2d_mm": slice["segments"],
		"slice_status": slice["status"], "slice_diagnostics": slice["diagnostics"],
		"timing_ms": float(Time.get_ticks_usec() - started) / 1000.0,
	}


func _sample(snapshot: Dictionary, angles: Array[float], plane: Transform3D, label: String) -> Dictionary:
	var fk: Dictionary = solver._forward_kinematics(snapshot, angles)
	var projected: Array = []
	var depths: Array[float] = []
	var tilts: Array[float] = []
	var signs: Array[float] = []
	var degrees: Array[float] = []
	for point: Vector3 in _fk_points(fk):
		var relative: Vector3 = point - plane.origin
		projected.append([relative.dot(plane.basis.x) * 1000.0, relative.dot(plane.basis.y) * 1000.0])
		depths.append(relative.dot(plane.basis.z) * 1000.0)
	for joint_index: int in range(3):
		var basis: Basis = (fk["joint_transforms_world"][joint_index] as Transform3D).basis
		var dot_normal: float = clampf(basis.x.cross(basis.y).normalized().dot(plane.basis.z), -1.0, 1.0)
		tilts.append(rad_to_deg(acos(absf(dot_normal))))
		signs.append(dot_normal)
		degrees.append(rad_to_deg(angles[joint_index]))
	return {"label": label, "angles_degrees": degrees, "points_2d_mm": projected, "depths_mm": depths, "normal_tilts_degrees": tilts, "oriented_normal_dots": signs}


func _slice_contours(triangles: PackedVector3Array, plane: Transform3D) -> Dictionary:
	# Production slice helpers retain welding/edge conventions but their public
	# result discards contours. This tool retains every edge and closed component;
	# coplanar/open/branched cuts remain explicitly ambiguous, never fabricated shut.
	var points: Array[Vector2] = []
	var buckets: Dictionary = {}
	var crossing: Dictionary = {}
	var coplanar: Dictionary = {}
	var coplanar_count: int = 0
	var epsilon: float = SliceScript.SLICE_DISTANCE_EPSILON_METERS
	for offset: int in range(0, triangles.size(), 3):
		var distances: Array[float] = []
		for index: int in range(3):
			distances.append((triangles[offset + index] - plane.origin).dot(plane.basis.z))
		var all_on: bool = absf(distances[0]) <= epsilon and absf(distances[1]) <= epsilon and absf(distances[2]) <= epsilon
		var ids := PackedInt32Array()
		for edge: int in range(3):
			var next: int = (edge + 1) % 3
			if absf(distances[edge]) <= epsilon:
				var id: int = SliceScript._resolve_welded_slice_point_id(points, buckets, triangles[offset + edge], plane.origin, plane.basis.x, plane.basis.y)
				if not ids.has(id):
					ids.append(id)
			if (distances[edge] > epsilon and distances[next] < -epsilon) or (distances[edge] < -epsilon and distances[next] > epsilon):
				var position: Vector3 = triangles[offset + edge].lerp(triangles[offset + next], distances[edge] / (distances[edge] - distances[next]))
				var id: int = SliceScript._resolve_welded_slice_point_id(points, buckets, position, plane.origin, plane.basis.x, plane.basis.y)
				if not ids.has(id):
					ids.append(id)
		if all_on:
			coplanar_count += 1
			for index: int in range(ids.size()):
				SliceScript._increment_slice_edge_count(coplanar, ids[index], ids[(index + 1) % ids.size()])
		elif ids.size() >= 2:
			var pair: Vector2i = SliceScript._resolve_farthest_slice_point_pair(ids, points)
			if pair.x != pair.y:
				crossing[SliceScript._build_slice_edge_key(pair.x, pair.y)] = true
	for edge: Vector2i in coplanar:
		if int(coplanar[edge]) % 2 == 1:
			crossing[edge] = true
	var segments: Array[Vector2i] = []
	var segment_numbers: Array = []
	var adjacency: Dictionary = {}
	for edge: Vector2i in crossing:
		segments.append(edge)
		segment_numbers.append([_point2_mm(points[edge.x]), _point2_mm(points[edge.y])])
		for pair: Vector2i in [edge, Vector2i(edge.y, edge.x)]:
			if not adjacency.has(pair.x):
				adjacency[pair.x] = []
			adjacency[pair.x].append(pair.y)
	var centroid_check: Dictionary = SliceScript._resolve_slice_contour_centroid(points, segments)
	var contours: Array = []
	var visited: Dictionary = {}
	var node_ids: Array = adjacency.keys()
	node_ids.sort()
	for start: int in node_ids:
		var neighbors: Array = adjacency[start]
		neighbors.sort()
		if neighbors.size() != 2 or visited.has(SliceScript._build_slice_edge_key(start, int(neighbors[0]))):
			continue
		var line: Array = []
		var previous: int = -1
		var current: int = start
		for _step: int in range(segments.size() + 1):
			if (adjacency[current] as Array).size() != 2:
				break
			line.append(_point2_mm(points[current]))
			var options: Array = adjacency[current]
			var next: int = int(options[0]) if int(options[0]) != previous else int(options[1])
			var edge: Vector2i = SliceScript._build_slice_edge_key(current, next)
			if visited.has(edge):
				break
			visited[edge] = true
			previous = current
			current = next
			if current == start:
				if line.size() >= 3:
					contours.append(line)
				break
	var status: String = "closed_contours" if bool(centroid_check.get("valid", false)) else String(centroid_check.get("error", "invalid_slice"))
	if coplanar_count > 0:
		status = "coplanar_face_ambiguity"
	return {"contours": contours, "segments": segment_numbers, "status": status, "diagnostics": {"coplanar_triangle_count": coplanar_count, "point_count": points.size(), "segment_count": segments.size(), "contour_count": contours.size(), "production_contour_check_valid": centroid_check.get("valid", false), "production_contour_check_error": centroid_check.get("error", ""), "filled_region_not_inferred": true}}


func _snapshot_reason(snapshot: Dictionary) -> String:
	if not bool(snapshot.get("valid", false)) or snapshot.get("bone_root_origin_id") != OriginScript.ORIGIN_RL_BONE_ROOT:
		return "missing_valid_digit_snapshot"
	for key: String in ["bone_names", "relative_transforms", "neutral_local_rotations", "hinge_axes_local", "min_angles_rad", "max_angles_rad", "capsule_radii_m"]:
		if not snapshot.get(key) is Array or (snapshot[key] as Array).size() != 3:
			return "missing_" + key
	if not snapshot.get("root_parent_world") is Transform3D or not _frame_valid(snapshot["root_parent_world"]):
		return "invalid_digit_parent_frame"
	if not snapshot.get("tip_offset_local") is Vector3 or not (snapshot["tip_offset_local"] as Vector3).is_finite() or (snapshot["tip_offset_local"] as Vector3).length_squared() <= 0.0 or snapshot.get("tip_offset_origin_id") != snapshot["bone_names"][2]:
		return "missing_named_terminal_offset"
	for index: int in range(3):
		for key: String in ["min_angles_rad", "max_angles_rad", "capsule_radii_m"]:
			if not (snapshot[key][index] is float or snapshot[key][index] is int) or not is_finite(float(snapshot[key][index])):
				return "invalid_numeric_" + key
		if float(snapshot["min_angles_rad"][index]) > float(snapshot["max_angles_rad"][index]) or float(snapshot["capsule_radii_m"][index]) <= 0.0:
			return "invalid_digit_limits_or_radius"
		if not snapshot["relative_transforms"][index] is Transform3D or not _frame_valid(snapshot["relative_transforms"][index]):
			return "invalid_digit_relative_frame"
		if not snapshot["neutral_local_rotations"][index] is Quaternion or not (snapshot["neutral_local_rotations"][index] as Quaternion).is_finite() or (snapshot["neutral_local_rotations"][index] as Quaternion).length_squared() <= 0.0:
			return "invalid_digit_neutral_rotation"
		if not snapshot["hinge_axes_local"][index] is Vector3 or not (snapshot["hinge_axes_local"][index] as Vector3).is_equal_approx(Vector3(0.0, 0.0, 1.0)):
			return "unexpected_local_hinge_axis"
	return ""


func _fk_points(fk: Dictionary) -> Array[Vector3]:
	var points: Array[Vector3] = []
	for point: Vector3 in fk["joint_origins_world"]:
		points.append(point)
	points.append(fk["tip_world"])
	return points


func _frame_valid(frame: Transform3D) -> bool:
	return frame.is_finite() and is_finite(frame.basis.determinant()) and frame.basis.determinant() != 0.0


func _transform_numbers(frame: Transform3D) -> Dictionary:
	return {"basis_columns": [_point3(frame.basis.x), _point3(frame.basis.y), _point3(frame.basis.z)], "origin_m": _point3(frame.origin)}


func _point3(point: Vector3) -> Array:
	return [point.x, point.y, point.z]


func _point2_mm(point: Vector2) -> Array:
	return [point.x * 1000.0, point.y * 1000.0]


func _fail(reason: String) -> void:
	push_error(reason)
	quit(1)
