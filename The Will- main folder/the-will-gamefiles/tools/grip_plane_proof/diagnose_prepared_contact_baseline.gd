extends SceneTree

const Runner = preload("res://tools/grip_plane_proof/run_prepared_skin_contact_proof.gd")
const Store = preload("res://tools/grip_plane_proof/character_hand_anatomy_store.gd")
const Adapter = preload("res://tools/grip_plane_proof/prepared_anatomy_contact_input.gd")
const SkinQuery = preload("res://tools/grip_plane_proof/prepared_digit_skin_query.gd")
const Slicer = preload("res://tools/grip_plane_proof/slice_reachable_surface.gd")
const Contact = preload("res://tools/grip_plane_proof/skin_plane_contact_query.gd")
const Spatial = preload("res://runtime/player/player_finger_surface_grip_solver.gd")
const Origins = preload("res://core/models/combat_origin_record.gd")

# Offline attribution only. All variants keep the captured Hand and object,
# use the SAME registered measurement plane, and retain every skin influence.
# Nonselected bones still use Hand-rebased rest, so this is not a live-pose oracle.
func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var loaded: Dictionary = Store.new().load_matching(Runner.DEFINITION_PATH, Runner.SIGNATURE, "rest_middle_thumb_surface_measurements_v1")
	if not bool(loaded.get("valid", false)):
		push_error(str(loaded))
		quit(1)
		return
	var report := {"schema": "prepared_contact_baseline_attribution_v1", "digits": [],
		"anatomy_path": Runner.DEFINITION_PATH, "source_signature": Runner.SIGNATURE,
		"anatomy_recomputed": false, "production_pose_written": false,
		"neighbor_pose_policy_is_reported_per_variant": true, "actual_3d_grip_verified": false}
	var failed := false
	for path: String in ["C:/WORKSPACE/test_artifacts/grip_solver_inputs_hand_right_2026-09-15T04-36-47.bin", "C:/WORKSPACE/test_artifacts/grip_solver_inputs_hand_left_2026-09-15T04-36-57.bin"]:
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			push_error("Cannot read frozen capture: " + path)
			quit(1)
			return
		var capture: Dictionary = file.get_var()
		file.close()
		for digit_id: StringName in [&"middle", &"thumb"]:
			var result := _digit(loaded.resource, capture, digit_id)
			result["slot"] = capture.slot
			result["digit"] = digit_id
			result["capture_path"] = path
			result["capture_sha256"] = FileAccess.get_sha256(path)
			report.digits.append(result)
			failed = failed or not bool(result.get("valid", false))
			var brief := {"slot": capture.slot, "digit": digit_id, "valid": result.get("valid"), "reason": result.get("reason"), "poses": []}
			for pose: Dictionary in result.get("poses", []):
				brief.poses.append({"label": pose.label, "delta_from_captured": pose.delta_from_captured,
					"dynamic_crossings": pose.contact.dynamic.proper_crossings,
					"fixed_crossings": pose.contact.fixed_static.proper_crossings,
					"source_triangle_ids": pose.crossing_attribution.map(func(c: Dictionary) -> int: return c.surface_triangle_index),
					"neighbor_mode": pose.neighbor_pose.get("mode", "rest"),
					"neighbor_reconstruction_error_m": pose.neighbor_pose.get("maximum_full_reconstruction_error_m")})
			print("CONTACT_BASELINE_DIGIT=" + JSON.stringify(_numbers(brief)))
	var output := "C:/WORKSPACE/test_artifacts/prepared_contact_baseline_" + Time.get_datetime_string_from_system().replace(":", "-") + ".json"
	var file := FileAccess.open(output, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write diagnostic report: " + output)
		quit(1)
		return
	file.store_string(JSON.stringify(_numbers(report), "\t"))
	file.close()
	print("CONTACT_BASELINE_RESULT=" + output)
	quit(1 if failed else 0)

func _digit(definition: Resource, capture: Dictionary, digit_id: StringName) -> Dictionary:
	var input: Dictionary = Adapter.new().build(definition, capture, digit_id)
	if not bool(input.get("valid", false)):
		return input
	var surface: Dictionary = capture.get("object_contact", {}).get("surface", {})
	if not bool(surface.get("valid", false)):
		return {"valid": false, "reason": "missing_whole_object_surface"}
	var plane: Transform3D = input.plane_to_world
	var outer_bound := 0.0
	for point: Vector3 in surface.triangles_world:
		outer_bound = maxf(outer_bound, point.distance_to(plane.origin))
	var target_slice: Dictionary = Slicer.new().slice(surface, plane, input.plane_origin_id, outer_bound + 0.00001, 0.0)
	if not bool(target_slice.get("valid", false)):
		return target_slice
	var contact = Contact.new()
	var target: Dictionary = contact.prepare_target(target_slice.segments, input.plane_origin_id)
	target["classification_incomplete"] = target_slice.classification_incomplete
	var reach := 0.0
	for length_m: float in input.digit.section_lengths_m:
		reach += length_m
	var original: Dictionary = capture.digits[digit_id].snapshot.duplicate(true)
	# The old terminal length must not confound joint/frame comparisons. Skin
	# reconstruction itself does not use this terminal offset.
	original["tip_offset_local"] = input.digit.terminal_skin_offset_local
	original["tip_offset_origin_id"] = input.digit.terminal_skin_offset_origin_id
	var calibrated := original.duplicate(true)
	for joint: int in [1, 2]:
		calibrated.neutral_local_rotations[joint] = (original.base_pose_rotations[joint] as Quaternion).inverse().normalized()
	var rest: Dictionary = input.snapshot.duplicate(true)
	for joint: int in range(3):
		rest.neutral_local_rotations[joint] = Quaternion.IDENTITY
	var variants: Array = [
		{"label": "captured_zero", "snapshot": original},
		{"label": "captured_calibrated", "snapshot": calibrated},
		{"label": "imported_rest", "snapshot": rest},
		{"label": "prepared_zero", "snapshot": input.snapshot},
		{"label": "captured_hand_zero", "snapshot": original, "neighbors": "captured"},
		{"label": "captured_hand_thumb_calibrated", "snapshot": calibrated if digit_id == &"thumb" else original, "neighbors": "captured_thumb_calibrated"},
		{"label": "prepared_pair_captured_others", "snapshot": input.snapshot, "neighbors": "prepared_pair"}]
	var poses: Array = []
	var original_pose: Dictionary = {}
	var skin = SkinQuery.new()
	for variant: Dictionary in variants:
		var started := Time.get_ticks_usec()
		var query: Dictionary = skin.prepare(variant.snapshot, input.reference_skin, input.context, plane, input.plane_origin_id)
		if not bool(query.get("valid", false)):
			return query
		var neighbor_pose := {"other_digit_bones_use_rest": true}
		if variant.has("neighbors"):
			neighbor_pose = _apply_neighbor_pose(query, input, definition, capture, variant.neighbors)
			if not bool(neighbor_pose.get("valid", false)):
				return neighbor_pose
		var posed: Dictionary = skin.pose(query, [0.0, 0.0, 0.0])
		if not bool(posed.get("valid", false)):
			return posed
		if original_pose.is_empty():
			original_pose = posed
		var measured: Dictionary = contact.evaluate(posed.segments, target, input.plane_origin_id, {"reach_m": reach, "skip_skin_solid_classification": true})
		if not bool(measured.get("valid", false)):
			return {"valid": false, "reason": "contact_evaluation_failed", "details": measured}
		var attribution := _crossings(posed, target_slice.segments, input, query, reach)
		for crossing: Dictionary in attribution:
			if not bool(crossing.get("valid", false)):
				return {"valid": false, "reason": "crossing_attribution_failed", "details": crossing}
		var joints_2d: Array = []
		var points: Array = posed.joint_origins_world.duplicate()
		points.append(posed.tip_world)
		for point: Vector3 in points:
			var local: Vector3 = plane.affine_inverse() * point
			joints_2d.append(Vector2(local.x, local.y))
		poses.append({"label": variant.label, "valid": measured.get("valid", false),
			"skin_segments": posed.segments, "joint_points_m": joints_2d, "contact": measured,
			"delta_from_captured": _deltas(original_pose, posed), "crossing_attribution": attribution,
			"neighbor_pose": neighbor_pose,
			"joint_origin_records": posed.joint_origin_records,
			"total_pose_ms": float(Time.get_ticks_usec() - started) / 1000.0})
	return {"valid": true, "poses": poses, "query_radius_m": reach, "target_segments": target_slice.segments,
		"plane_origin_id": input.plane_origin_id, "plane_to_world": plane, "origin_records": input.origin_records,
		"origin_chain": input.origin_chain, "machine_to_world": input.context.machine_to_world,
		"fixed_hand_to_world": original.root_parent_world, "hand_origin_id": input.snapshot.root_parent_origin_id,
		"source_object_origin_record": capture.object_contact.origin_record,
		"source_object_topology": surface.get("capsule_surface_topology", {}),
		"captured_calibration_is_existing_production_rule_only_for_thumb": true,
		"comparison_plane_is_prepared_plane_for_all_variants": true}

func _deltas(original: Dictionary, posed: Dictionary) -> Dictionary:
	var joints: Array = []
	for joint: int in range(3):
		var a: Transform3D = original.joint_transforms_world[joint]
		var b: Transform3D = posed.joint_transforms_world[joint]
		var qa := a.basis.orthonormalized().get_rotation_quaternion()
		var qb := b.basis.orthonormalized().get_rotation_quaternion()
		var difference := (qa.inverse() * qb).normalized()
		var angle := 2.0 * atan2(Vector3(difference.x, difference.y, difference.z).length(), absf(difference.w))
		joints.append({"bone_name": posed.bone_ids[joint], "translation_m": a.origin.distance_to(b.origin), "rotation_deg": rad_to_deg(angle)})
	var maximum := 0.0
	var changed := 0
	for index: int in range(posed.vertices_world.size()):
		var distance: float = (posed.vertices_world[index] as Vector3).distance_to(original.vertices_world[index])
		maximum = maxf(maximum, distance)
		changed += 1 if distance > 0.000001 else 0
	return {"joints": joints, "maximum_skin_vertex_displacement_m": maximum, "skin_vertices_moved_over_1um": changed}

# Diagnostic-only replacement of constant neighboring digit contributions.
# It does not rename posed transforms as rests or mutate the prepared resource.
# Each bone world frame has an explicit origin record back to RL_BoneRoot.
func _apply_neighbor_pose(query: Dictionary, input: Dictionary, definition: Resource, capture: Dictionary, mode: String) -> Dictionary:
	var frames := {}
	var records: Array = []
	var hand: Transform3D = input.snapshot.root_parent_world
	var machine: Transform3D = input.context.machine_to_world
	var spatial = Spatial.new()
	var common_rotations: Dictionary = capture.digits[&"middle"].options.get("base_pose_rotations", {})
	if common_rotations.size() != 15:
		return {"valid": false, "reason": "missing_common_15_bone_rotation_map"}
	var max_capture_frame_error := 0.0
	for digit_id: StringName in [&"thumb", &"index", &"middle", &"ring", &"pinky"]:
		var snapshot: Dictionary = capture.get("digits", {}).get(digit_id, {}).get("snapshot", {}).duplicate(true)
		if snapshot.is_empty():
			return {"valid": false, "reason": "missing_neighbor_digit_capture", "digit": digit_id}
		var source_hand: Transform3D = snapshot.root_parent_world
		if source_hand.origin.distance_to(hand.origin) > 0.000002 or not source_hand.basis.is_equal_approx(hand.basis):
			return {"valid": false, "reason": "captured_digits_do_not_share_hand_frame", "digit": digit_id}
		if capture.digits[digit_id].options.get("base_pose_rotations", {}) != common_rotations:
			return {"valid": false, "reason": "captured_digits_do_not_share_base_rotation_map"}
		var raw_fk: Dictionary = spatial._forward_kinematics(snapshot, [0.0, 0.0, 0.0])
		for joint: int in range(3):
			var current: Quaternion = snapshot.source_current_pose_rotations[joint]
			var base: Quaternion = snapshot.base_pose_rotations[joint]
			if not current.is_equal_approx(base) or not base.is_equal_approx(common_rotations[snapshot.bone_names[joint]]):
				return {"valid": false, "reason": "captured_current_pose_differs_from_common_base_pose", "digit": digit_id}
			var captured: Transform3D = snapshot.base_bone_world[joint]
			var resolved: Transform3D = raw_fk.joint_transforms_world[joint]
			max_capture_frame_error = maxf(max_capture_frame_error, captured.origin.distance_to(resolved.origin))
			if max_capture_frame_error > 0.000002 or not captured.basis.is_equal_approx(resolved.basis):
				return {"valid": false, "reason": "captured_zero_does_not_reconstruct_captured_bone_frame"}
		if mode == "prepared_pair" and digit_id in [&"thumb", &"middle"]:
			var prepared: Dictionary = Adapter.new().build(definition, capture, digit_id)
			if not bool(prepared.get("valid", false)):
				return prepared
			snapshot = prepared.snapshot
		elif mode == "captured_thumb_calibrated" and digit_id == &"thumb":
			var thumb: Dictionary = spatial._build_exact_collinear_thumb_snapshot(snapshot)
			if not bool(thumb.get("valid", false)):
				return {"valid": false, "reason": "existing_thumb_calibration_failed", "details": thumb}
			snapshot = thumb.snapshot
		var fk: Dictionary = spatial._forward_kinematics(snapshot, [0.0, 0.0, 0.0])
		for joint: int in range(3):
			var name: StringName = snapshot.bone_names[joint]
			frames[name] = fk.joint_transforms_world[joint]
			records.append({"origin_id": StringName(String(name) + "CapturedNeighborOrigin"), "source_bone_id": name,
				"parent_origin_id": &"RL_BoneRoot", "transform_to_parent": machine.affine_inverse() * frames[name],
				"owner_system": &"prepared_contact_baseline_diagnostic", "resolve_phase": &"editor_preview", "space_type": &"bone_frame", "is_dynamic": true})
	for data: Dictionary in records:
		var record = Origins.new()
		for field: String in ["origin_id", "parent_origin_id", "transform_to_parent", "owner_system", "resolve_phase", "space_type", "is_dynamic"]:
			record.set(field, data[field])
		if not query.registry.register_origin(record) or not bool(query.registry.validate_origin_chain(record.origin_id).get("ok", false)):
			return {"valid": false, "reason": "neighbor_pose_origin_chain_failed", "bone": data.source_bone_id}
	var reference: Dictionary = input.reference_skin
	var skeleton_to_world: Transform3D = hand * (reference.hand_global_rests[input.digit.hand_bone_name] as Transform3D).affine_inverse()
	var root_bind: int = reference.bind_bone_names.find(&"RL_BoneRoot")
	var mesh_to_world: Transform3D = skeleton_to_world * reference.bind_global_rests[root_bind] * reference.mesh_origin_record.transform_to_parent
	var selected: Dictionary = spatial._forward_kinematics(query.snapshot, [0.0, 0.0, 0.0])
	var old_frames: Array[Transform3D] = []
	var new_frames: Array[Transform3D] = []
	var is_neighbor: Array[bool] = []
	for bind: int in range(reference.bind_bone_names.size()):
		var name: StringName = reference.bind_bone_names[bind]
		var old: Transform3D = skeleton_to_world * reference.bind_global_rests[bind]
		var new: Transform3D = frames.get(name, old)
		var selected_index: int = query.bone_ids.find(name)
		if selected_index >= 0:
			new = selected.joint_transforms_world[selected_index]
		old_frames.append(old * reference.bind_poses[bind])
		new_frames.append(new * reference.bind_poses[bind])
		is_neighbor.append(frames.has(name) and selected_index < 0)
	var max_error := 0.0
	var moved := 0
	for surface_index: int in range(reference.surfaces.size()):
		var source: Dictionary = reference.surfaces[surface_index]
		var influences: int = source.weights.size() / source.vertices.size()
		var start: int = query.surface_ranges[surface_index].first_vertex
		for vertex: int in range(source.vertices.size()):
			var correction := Vector3.ZERO
			var direct := Vector3.ZERO
			var sum := 0.0
			for influence: int in range(influences):
				var offset := vertex * influences + influence
				var weight: float = source.weights[offset]
				if weight == 0.0:
					continue
				var bind: int = source.bones[offset]
				var point: Vector3 = source.vertices[vertex]
				direct += weight * (new_frames[bind] * point)
				sum += weight
				if is_neighbor[bind]:
					correction += weight * ((new_frames[bind] * point) - (old_frames[bind] * point))
			direct += (1.0 - sum) * mesh_to_world.origin
			query.fixed_contributions_world[start + vertex] += correction
			query.baseline_vertices_world[start + vertex] += correction
			max_error = maxf(max_error, direct.distance_to(query.baseline_vertices_world[start + vertex]))
			moved += 1 if correction.length() > 0.000001 else 0
	if max_error > 0.000005:
		return {"valid": false, "reason": "neighbor_coefficient_full_reconstruction_mismatch", "error_m": max_error}
	query.static_segments = SkinQuery.new()._slice_triangles(query, query.baseline_vertices_world, query.static_triangle_ids, false)
	return {"valid": true, "other_digit_bones_use_rest": false, "mode": mode,
		"bone_origin_records": records, "source_is_captured_base_pose_not_final_solved_pose": true,
		"nonhand_bones_still_use_hand_rebased_rest": true,
		"common_15_bone_base_pose_validated": true, "max_captured_frame_reconstruction_error_m": max_capture_frame_error,
		"neighbor_origin_chains_validated": true,
		"maximum_full_reconstruction_error_m": max_error, "vertices_moved_over_1um": moved}

func _crossings(posed: Dictionary, target_segments: Array, input: Dictionary, query: Dictionary, reach: float) -> Array:
	var result: Array = []
	var contact = Contact.new()
	for edge: Dictionary in posed.segments:
		# Exact segment/AABB rejection only; no bone-weight filtering.
		var a: Vector2 = edge.a
		var b: Vector2 = edge.b
		if minf(a.x, b.x) > reach or maxf(a.x, b.x) < -reach or minf(a.y, b.y) > reach or maxf(a.y, b.y) < -reach:
			continue
		for target: Array in target_segments:
			var hit: Dictionary = contact._intersection(a, b, target[0], target[1])
			if not bool(hit.get("proper", false)) or (hit.point as Vector2).length() > reach:
				continue
			result.append(_attribute(edge, hit.point, posed, input, query))
	return result

func _attribute(edge: Dictionary, point: Vector2, posed: Dictionary, input: Dictionary, query: Dictionary) -> Dictionary:
	var source: Dictionary = input.reference_skin.surfaces[edge.surface_index]
	var first_vertex: int = query.surface_ranges[edge.surface_index].first_vertex
	var vertex_ids: Array[int] = []
	var world: Array[Vector3] = []
	for corner: int in range(3):
		var index: int = source.indices[edge.surface_triangle_index * 3 + corner]
		vertex_ids.append(index)
		world.append(posed.vertices_world[first_vertex + index])
	# Intersection lives in the registered plane; all triangle points are its
	# already-resolved world presentation, traceable through machine_to_world.
	var point_world: Vector3 = input.plane_to_world * Vector3(point.x, point.y, 0.0)
	var v0 := world[1] - world[0]
	var v1 := world[2] - world[0]
	var v2 := point_world - world[0]
	var d00 := v0.dot(v0)
	var d01 := v0.dot(v1)
	var d11 := v1.dot(v1)
	var d20 := v2.dot(v0)
	var d21 := v2.dot(v1)
	var denominator := d00 * d11 - d01 * d01
	if absf(denominator) < 1.0e-24:
		return {"valid": false, "reason": "degenerate_crossing_triangle"}
	var beta := (d11 * d20 - d01 * d21) / denominator
	var gamma := (d00 * d21 - d01 * d20) / denominator
	var barycentric := Vector3(1.0 - beta - gamma, beta, gamma)
	var reconstructed := world[0] * barycentric.x + world[1] * barycentric.y + world[2] * barycentric.z
	var error_m := reconstructed.distance_to(point_world)
	if error_m > 0.000002 or minf(barycentric.x, minf(barycentric.y, barycentric.z)) < -0.002:
		return {"valid": false, "reason": "crossing_outside_source_triangle", "error_m": error_m, "barycentric": barycentric}
	var influences: int = source.weights.size() / source.vertices.size()
	var all_weights := {}
	var corners: Array = []
	for corner: int in range(3):
		var weights := {}
		for influence: int in range(influences):
			var offset := vertex_ids[corner] * influences + influence
			var weight: float = source.weights[offset]
			if weight == 0.0:
				continue
			var name: StringName = input.reference_skin.bind_bone_names[source.bones[offset]]
			weights[name] = float(weights.get(name, 0.0)) + weight
			all_weights[name] = float(all_weights.get(name, 0.0)) + weight * barycentric[corner]
		corners.append({"surface_vertex_index": vertex_ids[corner], "weights": weights})
	var sorted: Array = []
	for name: StringName in all_weights:
		sorted.append({"bone_name": name, "weight": all_weights[name], "selected_digit_bone": input.snapshot.bone_names.has(name), "hand_bone": name == input.digit.hand_bone_name})
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.weight) > float(b.weight))
	return {"valid": true, "point_in_plane_m": point, "origin_id": input.plane_origin_id,
		"surface_index": edge.surface_index, "surface_triangle_index": edge.surface_triangle_index,
		"dynamic": edge.dynamic, "all_interpolated_influences": sorted, "source_vertices": corners,
		"barycentric": barycentric, "reconstruction_error_m": error_m}

func _numbers(value: Variant) -> Variant:
	if value is Vector2:
		return [value.x, value.y]
	if value is Vector3:
		return [value.x, value.y, value.z]
	if value is Transform3D:
		return {"basis_columns": [_numbers(value.basis.x), _numbers(value.basis.y), _numbers(value.basis.z)], "origin_m": _numbers(value.origin)}
	if value is Dictionary:
		var out := {}
		for key: Variant in value:
			if not value[key] is Object:
				out[str(key)] = _numbers(value[key])
		return out
	if value is Array or value is PackedVector2Array or value is PackedVector3Array or value is PackedFloat32Array or value is PackedInt32Array:
		var out: Array = []
		for item: Variant in value:
			out.append(_numbers(item))
		return out
	return value
