extends "res://tools/grip_plane_proof/diagnose_prepared_contact_baseline.gd"

const HandSkin = preload("res://tools/grip_plane_proof/prepared_hand_skin_query.gd")
const FRAME_EPSILON := 0.000005

# P2 observed-stage attribution. No candidate search, scene writes or acceptance.
# Reuse only the old diagnostic's numerical slicing/attribution helpers, never
# its Hand-rebased-rest surface or synthetic neutral-pose variants.
var _weight_groups: Dictionary = {}

func _run() -> void:
	var started := Time.get_ticks_usec()
	var loaded: Dictionary = Store.new().load_matching(Runner.DEFINITION_PATH, Runner.SIGNATURE, "rest_middle_thumb_surface_measurements_v1")
	if not bool(loaded.get("valid", false)):
		push_error(str(loaded))
		quit(1)
		return
	var definition: Resource = loaded.resource
	var skin = HandSkin.new()
	var prepared: Dictionary = skin.prepare(definition.reference_skin, definition.source_signature)
	if not bool(prepared.get("valid", false)):
		push_error(str(prepared))
		quit(1)
		return
	# The inherited source-triangle attribution currently requires indexed input.
	for source: Dictionary in definition.reference_skin.surfaces:
		if source.indices.is_empty():
			push_error("P2 attribution requires indexed reference surfaces")
			quit(1)
			return
	var paths := OS.get_environment("THE_WILL_GRIP_PLACEMENT_PATHS").split(";", false)
	var report := {"schema": "coherent_grip_placement_comparison_v1", "captures": [], "failures": [],
		"anatomy_signature": definition.source_signature, "anatomy_recomputed": false,
		"production_pose_written": false, "actual_3d_grip_verified": false,
		"scope": "observed_stage_geometry_and_reachable_planar_boundary_attribution",
		"plane_policy": "prepared_anatomical_plane_attached_to_same_stage_Hand_not_articulated_digit_plane",
		"classification_policy": "bounded_boundary_probe_no_solid_containment_or_palm_clearance_certificate",
		"crossing_count_meaning": "source_face_events_not_unique_penetrations",
		"preparation_ms": prepared.preparation_ms}
	if paths.is_empty():
		report.failures.append("missing_explicit_placement_trace_paths")
	for requested: String in paths:
		var path := requested.strip_edges().replace("\\", "/").simplify_path()
		if not _workspace_trace_path(path):
			report.failures.append("invalid_workspace_trace_path: " + requested)
			continue
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			report.failures.append("cannot_read_trace: " + path)
			continue
		var raw: Variant = file.get_var(false)
		file.close()
		if not raw is Dictionary or raw.get("schema") != "grip_placement_trace_v1" or raw.get("anatomy_signature") != definition.source_signature or not raw.get("transactions") is Array:
			report.failures.append("invalid_trace_schema_or_anatomy: " + path)
			continue
		if not bool(raw.get("valid", false)) or not bool(raw.get("validation", {}).get("valid", false)) or not raw.get("capture_errors", []).is_empty():
			report.failures.append({"path": path, "reason": "producer_rejected_placement_capture", "validation": raw.get("validation")})
			continue
		var capture_report := {"path": path, "sha256": FileAccess.get_sha256(path), "slot": raw.slot, "transactions": []}
		if raw.transactions.is_empty():
			report.failures.append("empty_placement_trace: " + path)
		for transaction: Dictionary in raw.transactions:
			if transaction.get("slot") != raw.slot:
				report.failures.append("transaction_hand_does_not_match_trace: " + path)
				continue
			var entry := {"serial": transaction.serial, "slot": transaction.slot,
				"seat_result": transaction.get("result", {}).duplicate(true), "stages": []}
			var stages: Array = [{"data": transaction.get("before", {}), "expected": &"before_surface_seat"}]
			for stage: Dictionary in transaction.get("solver_inputs", []):
				stages.append({"data": stage, "expected": &"seat_solver_input"})
			stages.append({"data": transaction.get("after", {}), "expected": &"after_surface_seat"})
			for stage: Dictionary in transaction.get("finger_inputs", []):
				stages.append({"data": stage, "expected": &"finger_solve_input"})
			for observation: Dictionary in stages:
				var stage: Dictionary = observation.data
				var measured := _measure_stage(skin, prepared, definition, transaction, stage, observation.expected)
				entry.stages.append(measured)
				if not bool(measured.get("valid", false)):
					report.failures.append({"path": path, "serial": transaction.serial, "stage": stage.get("stage"), "details": measured})
				print("COHERENT_PLACEMENT_STAGE=" + JSON.stringify(_numbers(_brief(measured, transaction))))
			entry["applied_result_observation"] = _applied_result_observation(transaction)
			if not bool(entry.applied_result_observation.get("valid", false)):
				report.failures.append(entry.applied_result_observation)
			capture_report.transactions.append(entry)
		report.captures.append(capture_report)
	report["total_diagnostic_ms"] = float(Time.get_ticks_usec() - started) / 1000.0
	report["ok"] = report.failures.is_empty()
	var output := "C:/WORKSPACE/test_artifacts/coherent_grip_placement_" + Time.get_datetime_string_from_system().replace(":", "-") + ".json"
	var file := FileAccess.open(output, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write " + output)
		quit(1)
		return
	file.store_string(JSON.stringify(_numbers(report), "\t"))
	file.close()
	print("COHERENT_PLACEMENT_RESULT=" + output)
	print("COHERENT_PLACEMENT_SUMMARY=" + JSON.stringify({"ok": report.ok, "failures": report.failures, "total_diagnostic_ms": report.total_diagnostic_ms}))
	quit(0 if report.ok else 1)


func _measure_stage(skin: RefCounted, prepared: Dictionary, definition: Resource, transaction: Dictionary, stage: Dictionary, expected_stage: StringName) -> Dictionary:
	var started := Time.get_ticks_usec()
	if not bool(stage.get("valid", false)) or stage.get("transaction_serial") != transaction.serial or stage.get("slot") != transaction.slot or stage.get("stage") != expected_stage:
		return {"valid": false, "reason": "missing_or_mismatched_observed_stage", "capture": stage}
	var packet: Dictionary = stage.get("posed_character", {})
	if packet.get("transaction_serial") != transaction.serial or packet.get("capture_stage") != expected_stage or packet.get("engine_process_frame") != stage.get("engine_process_frame"):
		return {"valid": false, "reason": "pose_epoch_does_not_match_observed_stage"}
	var object: Dictionary = stage.get("object", {})
	if object.get("local_faces_origin_id", StringName()) == StringName() or object.get("local_faces_origin_id") != object.get("origin_record", {}).get("origin_id"):
		return {"valid": false, "reason": "object_faces_origin_mismatch"}
	var posed: Dictionary = skin.pose(prepared, packet)
	if not bool(posed.get("valid", false)):
		return posed
	if not object.get("local_faces") is PackedVector3Array or object.local_faces.is_empty() or object.local_faces.size() % 3 != 0:
		return {"valid": false, "reason": "missing_stage_object_faces"}
	var records: Array = packet.origin_records.duplicate(true)
	records.append(object.get("origin_record", {}))
	records.append(object.get("weapon_origin_record", {}))
	var registered: Dictionary = skin._registry(records, packet.resolve_phase)
	if not bool(registered.get("valid", false)):
		return registered
	var mesh_frame: Transform3D = packet.machine_to_world * registered.registry.resolve_transform_to_machine(object.origin_record.origin_id)
	var weapon_frame: Transform3D = packet.machine_to_world * registered.registry.resolve_transform_to_machine(object.weapon_origin_record.origin_id)
	if not object.get("mesh_to_world") is Transform3D or not object.get("weapon_to_world") is Transform3D or _frame_error(mesh_frame, object.mesh_to_world) > FRAME_EPSILON or _frame_error(weapon_frame, object.weapon_to_world) > FRAME_EPSILON:
		return {"valid": false, "reason": "observed_object_origin_round_trip_failed"}
	if stage.get("anatomical_reference_origin_id") != &"RL_BoneRoot" or not stage.get("anatomical_reference_world") is Vector3 or not stage.anatomical_reference_world.is_finite():
		return {"valid": false, "reason": "missing_named_anatomical_reference"}
	var faces: PackedVector3Array = mesh_frame * object.local_faces
	for point: Vector3 in faces:
		if not point.is_finite():
			return {"valid": false, "reason": "nonfinite_observed_object_surface"}
	var surface := {"valid": true, "triangles_world": faces,
		"surface_source_origin_id": object.origin_record.origin_id, "resolved_world_origin_id": &"RL_BoneRoot"}
	var out := {"valid": true, "stage": stage.stage, "pose_id": packet.pose_id,
		"engine_process_frame": stage.engine_process_frame, "anatomical_reference_world": stage.anatomical_reference_world,
		"anatomical_reference_origin_id": &"RL_BoneRoot", "reference_is_existing_mount_target_not_palm_contact": true,
		"weapon_to_world": weapon_frame, "mesh_to_world": mesh_frame,
		"machine_to_world": packet.machine_to_world, "origin_records": records,
		"seat_input": stage.get("seat_input", {}), "digits": [], "pose_evaluation_ms": posed.elapsed_ms,
		"capture_ms": stage.get("capture_ms"), "actual_3d_grip_verified": false}
	for digit_id: StringName in [&"middle", &"thumb"]:
		var digit_result := _measure_digit(definition, prepared, posed, surface, packet, transaction.slot, digit_id)
		out.digits.append(digit_result)
		if not bool(digit_result.get("valid", false)):
			out.valid = false
			out["reason"] = "digit_boundary_attribution_failed"
	out["stage_diagnostic_ms"] = float(Time.get_ticks_usec() - started) / 1000.0
	return out


func _measure_digit(definition: Resource, prepared: Dictionary, posed: Dictionary, surface: Dictionary, packet: Dictionary, slot: StringName, digit_id: StringName) -> Dictionary:
	var digit: Dictionary = {}
	for item: Dictionary in definition.digits:
		if item.slot_id == slot and item.digit_id == digit_id:
			digit = item
	if digit.is_empty() or not posed.bone_transforms_to_machine.has(digit.hand_bone_name):
		return {"valid": false, "reason": "missing_prepared_digit_or_current_hand"}
	var hand: Transform3D = packet.machine_to_world * posed.bone_transforms_to_machine[digit.hand_bone_name]
	# Adapter only derives the prepared measurement plane and measured dimensions.
	# Its FK/neutral snapshot is never used to replace the captured skin pose.
	var plane_source := {"slot": slot, "capture_frame": {"machine_origin_id": &"RL_BoneRoot", "machine_to_world": packet.machine_to_world},
		"digits": {digit_id: {"snapshot": {"bone_root_origin_id": &"RL_BoneRoot", "bone_names": digit.bone_names, "root_parent_world": hand}}}}
	var input: Dictionary = Adapter.new().build(definition, plane_source, digit_id)
	if not bool(input.get("valid", false)):
		return input
	var origin_records: Array = packet.origin_records.duplicate(true)
	origin_records.append_array(input.origin_records)
	var registered: Dictionary = HandSkin.new()._registry(origin_records, packet.resolve_phase)
	if not bool(registered.get("valid", false)):
		return registered
	var plane: Transform3D = input.plane_to_world
	var resolved_plane: Transform3D = packet.machine_to_world * registered.registry.resolve_transform_to_machine(input.plane_origin_id)
	if _frame_error(plane, resolved_plane) > FRAME_EPSILON:
		return {"valid": false, "reason": "measurement_plane_origin_round_trip_failed"}
	var key := String(slot) + "/" + String(digit_id)
	if not _weight_groups.has(key):
		_weight_groups[key] = _prepare_weight_groups(definition.reference_skin, prepared, digit.bone_names)
	var groups: Dictionary = _weight_groups[key]
	var query := {"plane_to_world": plane, "plane_origin_id": input.plane_origin_id,
		"triangle_indices": prepared.triangle_indices, "triangle_surface_ids": prepared.triangle_surface_ids,
		"triangle_local_ids": prepared.triangle_local_ids, "surface_ranges": prepared.surface_ranges,
		"bone_ids": digit.bone_names, "selected_weights": groups.weights}
	var slicer := SkinQuery.new()
	var segments: Array = slicer._slice_triangles(query, posed.vertices_world, groups.selected, true)
	segments.append_array(slicer._slice_triangles(query, posed.vertices_world, groups.other, false))
	for edge: Dictionary in segments:
		if edge.get("origin_id") != input.plane_origin_id:
			return {"valid": false, "reason": "skin_edge_plane_origin_mismatch"}
	var reach := 0.0
	for length_m: float in digit.section_lengths_m:
		reach += length_m
	var target_slice: Dictionary = Slicer.new().slice(surface, plane, input.plane_origin_id, reach, 0.0)
	if not bool(target_slice.get("valid", false)):
		return {"valid": false, "reason": "object_slice_failed", "slice": target_slice}
	var contact := Contact.new()
	var local_skin := contact._bounded_edges(segments, reach)
	var measured := {"valid": true, "status": "no_local_target_boundary", "planar_clearance_verified": false,
		"planar_classification_complete": false}
	if not target_slice.segments.is_empty() and local_skin.is_empty():
		measured.status = "no_local_skin_boundary"
	var crossings: Array = []
	if not target_slice.segments.is_empty() and not local_skin.is_empty():
		var target: Dictionary = contact.prepare_target(target_slice.segments, input.plane_origin_id)
		target["classification_incomplete"] = true # Cropped boundary: no solid claim.
		measured = contact.evaluate(segments, target, input.plane_origin_id,
			{"reach_m": reach, "skip_skin_solid_classification": true, "skin_classification_incomplete": true})
		var attributed_pose := {"segments": segments, "vertices_world": posed.vertices_world}
		crossings = _crossings(attributed_pose, target_slice.segments, input, query, reach)
	var valid := bool(measured.get("valid", false))
	for crossing: Dictionary in crossings:
		valid = valid and bool(crossing.get("valid", false))
	return {"valid": valid, "digit": digit_id, "plane_to_world": plane,
		"plane_origin_id": input.plane_origin_id, "origin_records": input.origin_records,
		"hand_to_world": hand, "reach_m": reach, "reach_policy": "prepared_section_length_sum_no_padding",
		"skin_segments": local_skin, "target_segments": target_slice.segments,
		"target_slice_counts": target_slice.counts, "contact": measured, "crossings": crossings,
		"selected_influence_means": "any_positive_original_weight_on_selected_digit_not_actual_motion_or_palm_region",
		"all_contributing_current_poses_used": true, "actual_3d_grip_verified": false}


func _prepare_weight_groups(reference: Dictionary, prepared: Dictionary, selected_names: Array) -> Dictionary:
	var weights := PackedVector3Array()
	for source: Dictionary in reference.surfaces:
		var width: int = source.weights.size() / source.vertices.size()
		for vertex: int in range(source.vertices.size()):
			var selected := Vector3.ZERO # Three scalar weights, not a spatial point.
			for influence: int in range(width):
				var offset := vertex * width + influence
				var weight: float = source.weights[offset]
				if weight <= 0.0:
					continue
				var joint: int = selected_names.find(reference.bind_bone_names[source.bones[offset]])
				if joint >= 0:
					selected[joint] += weight
			weights.append(selected)
	var selected := PackedInt32Array()
	var other := PackedInt32Array()
	for triangle: int in range(prepared.triangle_count):
		var influenced := false
		for corner: int in range(3):
			influenced = influenced or weights[prepared.triangle_indices[triangle * 3 + corner]] != Vector3.ZERO
		if influenced:
			selected.append(triangle)
		else:
			other.append(triangle)
	return {"weights": weights, "selected": selected, "other": other}


func _applied_result_observation(transaction: Dictionary) -> Dictionary:
	var result: Dictionary = transaction.get("result", {})
	if not bool(result.get("applied", false)):
		return {"valid": true, "applied": false, "status": result.get("status"), "proposal_is_not_applied_seat": true}
	if result.get("resolved_weapon_transform_world_origin_id") != &"RL_BoneRoot":
		return {"valid": false, "reason": "applied_result_missing_named_world_origin"}
	var after: Dictionary = transaction.get("after", {}).get("object", {})
	if not result.get("resolved_weapon_transform_world") is Transform3D or not after.get("weapon_to_world") is Transform3D:
		return {"valid": false, "reason": "applied_seat_missing_observed_weapon_frame"}
	var error := _frame_error(result.resolved_weapon_transform_world, after.weapon_to_world)
	return {"valid": error <= FRAME_EPSILON, "applied": true, "frame_component_error": error,
		"reason": "" if error <= FRAME_EPSILON else "applied_result_differs_from_observed_weapon"}


func _brief(measured: Dictionary, transaction: Dictionary) -> Dictionary:
	var summary := {"slot": transaction.slot, "serial": transaction.serial, "stage": measured.get("stage"),
		"valid": measured.get("valid"), "reason": measured.get("reason"), "digits": []}
	for digit: Dictionary in measured.get("digits", []):
		summary.digits.append({"digit": digit.get("digit"), "valid": digit.get("valid"),
			"crossings": digit.get("crossings", []).size(), "planar_overlap_detected": digit.get("contact", {}).get("planar_overlap_detected"),
			"other_influence_crossings": digit.get("contact", {}).get("fixed_static", {}).get("proper_crossings")})
	return summary


func _frame_error(a: Transform3D, b: Transform3D) -> float:
	if not a.is_finite() or not b.is_finite():
		return INF
	return maxf(a.origin.distance_to(b.origin), maxf(a.basis.x.distance_to(b.basis.x), maxf(a.basis.y.distance_to(b.basis.y), a.basis.z.distance_to(b.basis.z))))


func _workspace_trace_path(path: String) -> bool:
	if not path.is_absolute_path() or not path.to_lower().begins_with("c:/workspace/test_artifacts/") or path.get_extension().to_lower() != "bin" or path.substr(3).contains(":"):
		return false
	var directory := DirAccess.open("C:/WORKSPACE")
	if directory == null or directory.is_link("C:/WORKSPACE"):
		return false
	var current := "C:/WORKSPACE"
	for component: String in path.substr("C:/WORKSPACE/".length()).split("/", false):
		current = current.path_join(component)
		if directory.is_link(current):
			return false
	return true
