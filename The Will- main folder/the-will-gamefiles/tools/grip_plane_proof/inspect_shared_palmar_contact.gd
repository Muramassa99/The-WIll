extends "res://tools/grip_plane_proof/run_shared_hand_closure_proof.gd"

const PalmPreparation = preload("res://tools/grip_plane_proof/prepare_character_palmar_contact.gd")
const Spatial = preload("res://runtime/player/player_finger_surface_grip_solver.gd")
const PointQuery = preload("res://runtime/player/player_finger_capsule_surface_query.gd")
const SOURCE_REPORT := "C:/WORKSPACE/test_artifacts/shared_hand_closure_2026-09-18T04-55-59.json"
const SOURCE_REPORT_SHA256 := "bb217be3f67b3d6369ddb52750bc53fece2439121402d1d8511f085e9f5d9ce8"

var _palm_resource: Resource
var _palm_preparation: Dictionary = {}

func _run() -> void:
	var loaded: Dictionary = Store.new().load_matching(OldInputs.DEFINITION_PATH, OldInputs.SIGNATURE, "rest_middle_thumb_surface_measurements_v1")
	if not loaded.get("valid", false): push_error(str(loaded)); quit(1); return
	var workspace: DirAccess = DirAccess.open("C:/WORKSPACE")
	if workspace == null: push_error("Workspace unavailable"); quit(1); return
	for fixed_path: String in ["C:/WORKSPACE", "C:/WORKSPACE/test_artifacts", SOURCE_REPORT]:
		if workspace.is_link(fixed_path): push_error("Fixed source report uses a redirected path"); quit(1); return
	if FileAccess.get_sha256(SOURCE_REPORT) != SOURCE_REPORT_SHA256:
		push_error("Fixed shared-pose source report hash changed"); quit(1); return
	var baseline: Variant = JSON.parse_string(FileAccess.get_file_as_string(SOURCE_REPORT))
	if not baseline is Dictionary or baseline.get("schema") != "shared_hand_closure_proof_v1" or not baseline.get("ok", false) or baseline.get("anatomy_signature") != loaded.resource.source_signature:
		push_error("Invalid fixed shared-pose source report"); quit(1); return
	var report := {"schema": "shared_palmar_contact_observations_v1", "source_report": SOURCE_REPORT,
		"source_report_sha256": FileAccess.get_sha256(SOURCE_REPORT), "anatomy_signature": loaded.resource.source_signature,
		"cases": [], "failures": [], "palm_contact_verified": false, "palm_overlap_policy_applied": false,
		"grip_accepted": false, "production_pose_written": false, "solver_ranking_changed": false,
		"scope": "accepted_and_rejected_reference_palmar_point_carriers_on_two_fixed_shared_poses",
		"surface_distance_scope": "existing_prepared_triangle_surface_only",
		"full_source_weapon_distance_verified": false, "source_geometry_filtered": false,
		"sample_distances_do_not_certify_whole_palm_or_whole_grip": true}
	for recorded: Dictionary in baseline.cases:
		var result := _observe_case(loaded.resource, recorded)
		report.cases.append(result)
		report.source_geometry_filtered = report.source_geometry_filtered or result.get("source_geometry_filtered", false)
		if not result.get("valid", false): report.failures.append(result)
	report["palmar_preparation"] = _palm_preparation
	report["ok"] = report.failures.is_empty()
	var path := "C:/WORKSPACE/test_artifacts/shared_palmar_contact_" + Time.get_datetime_string_from_system().replace(":", "-") + ".json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null: push_error("Cannot save palmar observations"); quit(1); return
	file.store_string(JSON.stringify(_json(report))); file.close()
	print("SHARED_PALMAR_CONTACT_RESULT=" + path)
	print("SHARED_PALMAR_CONTACT_SUMMARY=" + JSON.stringify({"ok": report.ok, "cases": report.cases.size(), "failures": report.failures.size()}))
	quit(0 if report.ok else 1)


func _observe_case(definition: Resource, recorded: Dictionary) -> Dictionary:
	var source := _exact_source_stage(recorded, definition.source_signature)
	if not source.get("valid", false): return source
	var stage: Dictionary = source.stage
	var context := _prepare(definition, stage)
	if not context.get("valid", false): return context
	var machine: Transform3D = context.adapter.base_packet.machine_to_world
	if _palm_resource == null:
		var baked: Dictionary = PalmPreparation.new().bake(definition, machine)
		# Partial preparation is intentionally observed, never upgraded to valid.
		if not baked.get("resource") is Resource:
			return {"valid": false, "reason": "no_palmar_sample_resource", "details": baked}
		_palm_resource = baked.resource
		_palm_preparation = {"valid": baked.get("valid", false), "complete": baked.get("complete", false),
			"reason": baked.get("reason"), "preparation_ms": baked.get("preparation_ms"),
			"recipe_fingerprint": _palm_resource.recipe_fingerprint, "measurement_status": _palm_resource.measurement_status,
			"reference_machine_to_world": machine, "reference_pose_id": &"PalmarCoreReferenceRest",
			"performed_once_in_memory_only": true, "resource_saved": false,
			"complete_palm_partition_verified": false, "palm_overlap_policy_defined": false}
	var metric: Dictionary = PalmPreparation.new()._validate_metric(definition.source_manifest.character_metric, machine)
	if not metric.get("valid", false): return metric
	var object: Dictionary = stage.object
	var faces: PackedVector3Array = object.local_faces
	if faces.is_empty() or faces.size() % 3 != 0:
		return {"valid": false, "reason": "invalid_captured_weapon_faces"}
	var arrays: Array = []; arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = faces.duplicate()
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var surface: Dictionary = Spatial.new().prepare_surface(mesh, object.mesh_to_world,
		{"surface_source_origin_id": object.local_faces_origin_id, "resolved_world_origin_id": ROOT})
	# Observation of the same topology rule before filtering distinguishes source
	# evidence from the effect of preparation; it does not classify the raw solid.
	var source_topology: Dictionary = PointQuery.new().analyze_prepared_surface_topology(context.surface)
	if not surface.get("valid", false):
		return {"valid": false, "reason": "existing_surface_preparation_rejected_captured_faces"}
	var audit := _audit_prepared_triangles(faces, context.surface.triangles_world, surface.triangles_world, object.local_faces_origin_id)
	if not audit.get("valid", false): return audit
	var prepared_source_ids: PackedInt32Array = audit.retained_source_triangle_indices
	audit.erase("retained_source_triangle_indices")
	var slot: StringName = context.slot
	var metadata: Dictionary = _palm_resource.slot_metadata[slot]
	var accepted: Array = _palm_resource.samples_by_slot[slot]
	var rejected: Array = metadata.rejected_samples
	var wanted_reference := {ROOT: true, _palm_resource.source_mesh_origin_id: true,
		metadata.hand_bone_name: true, metadata.frame_origin_id: true}
	var reference_records := _origin_closure(_palm_resource.origin_records, wanted_reference)
	if not reference_records.get("valid", false): return reference_records
	var result := {"valid": true, "slot": slot, "source_trace": source.path, "source_trace_sha256": recorded.source_trace_sha256,
		"source_transaction": recorded.source_transaction, "source_capture_pose_id": stage.posed_character.pose_id,
		"accepted_pair_count": accepted.size(), "rejected_pair_count": rejected.size(),
		"pair_preparation_complete": metadata.complete, "hand_bone_name": metadata.hand_bone_name,
		"reference_origin_records": reference_records.records, "reference_phase": &"bake_time",
		"source_mesh_origin_id": _palm_resource.source_mesh_origin_id, "machine_to_world": machine,
		"weapon_faces_unchanged": not bool(audit.source_geometry_filtered), "weapon_face_count": faces.size() / 3,
		"source_geometry_filtered": audit.source_geometry_filtered, "surface_preparation_audit": audit,
		"surface_distance_scope": "existing_prepared_triangle_surface_only", "full_source_weapon_distance_verified": false,
		"surface_topology": surface.capsule_surface_topology, "surface_signature": surface.surface_signature,
		"unfiltered_source_topology_under_existing_query_rules": source_topology,
		"poses": [], "palm_contact_verified": false, "palm_overlap_policy_applied": false}
	for label: String in ["initial", "selected"]:
		var saved: Dictionary = recorded[label]
		var values: Array = saved.parameters
		if values.size() != 8: return {"valid": false, "reason": "missing_eight_fixed_pose_parameters"}
		for value: Variant in values:
			if not (value is float or value is int) or not is_finite(float(value)):
				return {"valid": false, "reason": "invalid_fixed_pose_parameter"}
		var angles := {&"middle": [values[0], values[1], values[2]], &"thumb": [values[3], values[4], values[5]]}
		var translation: Vector3 = context.translation_u_world * float(values[6]) + context.translation_v_world * float(values[7])
		var candidate: Dictionary = _builder.evaluate(context.adapter, angles, translation, ROOT)
		if not candidate.get("valid", false): return candidate
		var round_trip := _check_recorded_frames(candidate.pose_packet.origin_records, saved.get("pose_origin_records", []))
		if not round_trip.get("valid", false): return round_trip
		var rows: Array = []
		var records: Array = candidate.pose_packet.origin_records.duplicate(true)
		records.append_array(context.object_origin_records)
		var wanted := {ROOT: true, candidate.pose_packet.mesh_origin_id: true,
			object.origin_record.origin_id: true, object.weapon_origin_record.origin_id: true}
		for pair: Array in [[&"accepted_pair", accepted], [&"rejected_pair", rejected]]:
			for sample: Dictionary in pair[1]:
				rows.append(_observe_sample(sample, pair[0], label, candidate, context.adapter.skin_prepared,
					surface, object.local_faces_origin_id, prepared_source_ids, machine, records, wanted))
		var registered: Dictionary = HandSkin.new()._registry(records, &"editor_preview")
		if not registered.get("valid", false): return registered
		var closure := _origin_closure(records, wanted)
		if not closure.get("valid", false): return closure
		var carrier_count := 0
		var signed_count := 0
		for row: Dictionary in rows:
			carrier_count += int(row.carrier_resolved)
			signed_count += int(row.signed_distance_valid)
		result.poses.append({"stage": label, "recorded_pose_id": saved.pose_id, "evaluated_pose_id": candidate.pose_packet.pose_id,
			"pose_id_matches_recorded_hash": String(candidate.pose_packet.pose_id) == String(saved.pose_id),
			"json_parameter_frame_round_trip": round_trip, "parameters": values,
			"pose_rehydration_policy": "reported_parameters_re_evaluated_and_all_recorded_frames_compared",
			"origin_records": closure.records, "resolve_phase": &"editor_preview", "samples": rows,
			"resolved_carrier_count": carrier_count, "signed_distance_count": signed_count,
			"palm_contact_verified": false, "cap_or_acceptance_applied": false})
	return result


func _observe_sample(sample: Dictionary, pair_label: StringName, stage: String, candidate: Dictionary, skin: Dictionary,
		surface: Dictionary, surface_origin: StringName, prepared_source_ids: PackedInt32Array, machine: Transform3D, records: Array, wanted: Dictionary) -> Dictionary:
	var hit: Dictionary = sample.get("palmar_hit", {})
	var row := {"sample_id": sample.sample_id, "pair_preparation_label": pair_label,
		"pair_rejection_reason": sample.get("reason", ""), "two_sided_bracketing_verified": sample.two_sided_bracketing_verified,
		"palmar_hit_valid_in_preparation": hit.get("valid", false), "palmar_hit_rejection_reason": hit.get("reason", ""),
		"dorsal_hit_valid_in_preparation": sample.get("dorsal_hit", {}).get("valid", false),
		"hand_weight": hit.get("hand_weight"), "total_weight": hit.get("total_weight"),
		"original_interpolated_influences": hit.get("original_interpolated_influences", {}),
		"weights_normalized": false, "carrier_resolved": false, "point_query_valid": false,
		"signed_distance_valid": false, "signed_distance_m": null, "inside_solid": null,
		"surface_distance_scope": "existing_prepared_triangle_surface_only", "full_source_weapon_distance_verified": false,
		"palm_contact_verified": false, "ownership_label_changed": false}
	if not hit.get("source_vertex_indices") is PackedInt32Array or not hit.get("barycentric") is Vector3:
		row["observation_unavailable_reason"] = "no_source_face_barycentric_carrier"; return row
	var surface_index: int = int(hit.get("surface_index", -1))
	var triangle: int = int(hit.get("global_triangle_index", -1))
	var local_ids: PackedInt32Array = hit.source_vertex_indices
	var barycentric: Vector3 = hit.barycentric
	if surface_index < 0 or surface_index >= skin.surface_ranges.size() or local_ids.size() != 3 or triangle < 0 or triangle >= skin.triangle_count or not barycentric.is_finite() or absf(barycentric.x + barycentric.y + barycentric.z - 1.0) > 0.000001 or barycentric.x < 0.0 or barycentric.y < 0.0 or barycentric.z < 0.0:
		row["observation_unavailable_reason"] = "invalid_source_face_carrier"; return row
	var range_record: Dictionary = skin.surface_ranges[surface_index]
	var global_ids := PackedInt32Array()
	var point := Vector3.ZERO
	for corner: int in range(3):
		var global_id: int = int(range_record.first_vertex) + local_ids[corner]
		if local_ids[corner] < 0 or local_ids[corner] >= int(range_record.vertex_count) or skin.triangle_surface_ids[triangle] != surface_index or skin.triangle_local_ids[triangle] != int(hit.surface_triangle_index) or skin.triangle_indices[triangle * 3 + corner] != global_id:
			row["observation_unavailable_reason"] = "surface_local_index_does_not_match_original_triangle"; return row
		global_ids.append(global_id)
		point += (candidate.posed.vertices_world[global_id] as Vector3) * barycentric[corner]
	for raw_name: Variant in hit.original_interpolated_influences:
		var name := StringName(raw_name)
		if not candidate.pose_packet.bone_origin_ids.has(name):
			row["observation_unavailable_reason"] = "missing_current_contributor_origin"; return row
		wanted[candidate.pose_packet.bone_origin_ids[name]] = true
	var point_id := StringName("%s_%sPalmarObservationOrigin" % [String(sample.sample_id), stage])
	var point_record := {"origin_id": point_id, "parent_origin_id": ROOT,
		"transform_to_parent": Transform3D(Basis.IDENTITY, machine.affine_inverse() * point),
		"owner_system": &"shared_palmar_contact_observer", "resolve_phase": &"editor_preview",
		"space_type": &"collision", "is_dynamic": true}
	records.append(point_record); wanted[point_id] = true
	var query: Dictionary = PointQuery.new().query_prepared_surface(surface, point, point_id, point, point_id,
		0.0, surface_origin, ROOT, {"classify_inside_solid": true, "surface_topology_state": surface.capsule_surface_topology})
	var signed_valid: bool = query.get("valid", false) and query.get("inside_classification_valid", false) and query.get("signed_distance_valid", false) and surface.capsule_surface_topology.get("valid", false) and surface.capsule_surface_topology.get("closed", false)
	var closest_prepared: int = int(query.get("closest_triangle_index", -1))
	row.merge({"carrier_resolved": true, "surface_index": surface_index, "surface_triangle_index": hit.surface_triangle_index,
		"source_vertex_indices_surface_local": local_ids, "source_vertex_indices_full_skin": global_ids,
		"source_surface_first_vertex": range_record.first_vertex, "barycentric": barycentric,
		"reference_point_m": hit.reference_point_m, "reference_point_origin_id": hit.reference_point_origin_id,
		"point_world": point, "point_source_origin_id": point_id, "point_world_origin_id": ROOT,
		"pose_id": candidate.pose_packet.pose_id, "surface_source_origin_id": surface_origin,
		"point_query_valid": query.get("valid", false), "point_query_status": query.get("status"),
		"nearest_unsigned_distance_m": query.get("nearest_distance_meters"),
		"inside_classification_valid": query.get("inside_classification_valid", false),
		"inside_classification_status": query.get("inside_classification_status"),
		"signed_distance_valid": signed_valid,
		"signed_distance_m": query.get("signed_axis_surface_distance_meters") if signed_valid else null,
		"inside_solid": query.get("segment_axis_inside_solid") if signed_valid else null,
		"closest_object_point_world": query.get("closest_triangle_point_world"),
		"closest_object_point_world_origin_id": ROOT, "closest_prepared_object_triangle_index": closest_prepared,
		"closest_captured_source_triangle_index": prepared_source_ids[closest_prepared] if closest_prepared >= 0 and closest_prepared < prepared_source_ids.size() else null,
		"query_counts": query.get("counts", {}), "numeric_geometry_epsilon_m": PointQuery.GEOMETRY_EPSILON_METERS,
		"distance_metric": "zero_radius_point_to_existing_prepared_3d_surface_negative_inside_if_classified"}, true)
	return row


func _audit_prepared_triangles(source_local: PackedVector3Array, source_world: PackedVector3Array,
		prepared_world: PackedVector3Array, source_origin: StringName) -> Dictionary:
	if source_local.size() != source_world.size() or source_world.size() % 3 != 0 or prepared_world.size() % 3 != 0:
		return {"valid": false, "reason": "malformed_surface_arrays_for_preparation_audit"}
	var threshold: float = PointQuery.TRIANGLE_AREA_EPSILON_SQUARED_M4
	var retained := PackedInt32Array()
	var omitted: Array = []
	var prepared_offset := 0
	for source_triangle: int in range(source_world.size() / 3):
		var offset: int = source_triangle * 3
		var a: Vector3 = source_world[offset]
		var b: Vector3 = source_world[offset + 1]
		var c: Vector3 = source_world[offset + 2]
		if not a.is_finite() or not b.is_finite() or not c.is_finite():
			return {"valid": false, "reason": "nonfinite_source_triangle", "source_triangle_index": source_triangle}
		# Match prepare_surface's existing scalar and threshold exactly. The
		# diagnostic does not repair geometry or alter the runtime threshold.
		var cross_length_squared: float = (b - a).cross(c - a).length_squared()
		if cross_length_squared <= threshold:
			omitted.append({"captured_source_triangle_index": source_triangle,
				"captured_local_face_vertex_indices": [offset, offset + 1, offset + 2],
				"source_vertices_local": source_local.slice(offset, offset + 3), "source_local_origin_id": source_origin,
				"source_vertices_world": [a, b, c], "source_world_origin_id": ROOT,
				"cross_length_squared_m4": cross_length_squared, "triangle_area_m2": sqrt(cross_length_squared) * 0.5,
				"removal_reason": "existing_prepare_surface_cross_squared_at_or_below_threshold"})
			continue
		if prepared_offset + 3 > prepared_world.size():
			return {"valid": false, "reason": "preparation_removed_triangle_above_threshold", "source_triangle_index": source_triangle}
		for corner: int in range(3):
			if prepared_world[prepared_offset + corner] != source_world[offset + corner]:
				return {"valid": false, "reason": "retained_triangle_coordinates_or_order_changed", "source_triangle_index": source_triangle,
					"prepared_triangle_index": prepared_offset / 3, "corner": corner}
		retained.append(source_triangle)
		prepared_offset += 3
	if prepared_offset != prepared_world.size():
		return {"valid": false, "reason": "unexpected_extra_prepared_triangles"}
	return {"valid": true, "source_geometry_filtered": not omitted.is_empty(),
		"source_triangle_count": source_world.size() / 3, "retained_triangle_count": retained.size(),
		"omitted_triangle_count": omitted.size(), "omitted_source_triangles": omitted,
		"retained_source_triangle_indices": retained, "retained_coordinates_and_order_exactly_match": true,
		"all_omissions_match_existing_threshold": true, "cross_length_squared_threshold_m4": threshold,
		"threshold_source": "PlayerFingerCapsuleSurfaceQuery.TRIANGLE_AREA_EPSILON_SQUARED_M4",
		"threshold_changed": false, "full_source_weapon_distance_verified": false}


func _exact_source_stage(recorded: Dictionary, signature: String) -> Dictionary:
	var path := String(recorded.get("source_trace", "")).replace("\\", "/").simplify_path()
	if not _workspace_trace_path(path):
		return {"valid": false, "reason": "invalid_workspace_trace_path"}
	if FileAccess.get_sha256(path) != recorded.get("source_trace_sha256"):
		return {"valid": false, "reason": "invalid_or_changed_workspace_trace"}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return {"valid": false, "reason": "unreadable_trace"}
	var trace: Variant = file.get_var(false); file.close()
	if not trace is Dictionary or trace.get("schema") != "grip_placement_trace_v1" or not trace.get("valid", false) or not trace.get("validation", {}).get("valid", false) or not trace.get("capture_errors", []).is_empty() or trace.get("anatomy_signature") != signature or trace.get("slot") != StringName(recorded.slot):
		return {"valid": false, "reason": "invalid_coherent_trace"}
	for transaction: Dictionary in trace.transactions:
		if transaction.serial != int(recorded.source_transaction) or transaction.slot != trace.slot: continue
		if not transaction.get("result", {}).get("applied", false) or transaction.get("finger_inputs", []).is_empty(): break
		var stage: Dictionary = transaction.finger_inputs[-1]
		if not stage.get("valid", false) or stage.get("stage") != &"finger_solve_input" or stage.get("transaction_serial") != transaction.serial or stage.posed_character.get("transaction_serial") != transaction.serial or stage.posed_character.get("capture_stage") != stage.stage or stage.posed_character.get("engine_process_frame") != stage.get("engine_process_frame"):
			return {"valid": false, "reason": "capture_epoch_mismatch"}
		return {"valid": true, "path": path, "stage": stage}
	return {"valid": false, "reason": "exact_recorded_transaction_not_found"}


func _check_recorded_frames(actual: Array, serialized: Array) -> Dictionary:
	if actual.size() != serialized.size(): return {"valid": false, "reason": "recorded_pose_frame_count_mismatch"}
	var expected := {}
	for record: Dictionary in serialized: expected[StringName(record.origin_id)] = record
	if expected.size() != serialized.size(): return {"valid": false, "reason": "duplicate_recorded_pose_origin"}
	var maximum := 0.0
	for record: Dictionary in actual:
		if not expected.has(record.origin_id): return {"valid": false, "reason": "recorded_pose_frame_missing"}
		var saved: Dictionary = expected[record.origin_id]
		if String(record.parent_origin_id) != String(saved.parent_origin_id): return {"valid": false, "reason": "recorded_pose_parent_mismatch"}
		var frame: Transform3D = record.transform_to_parent
		if not frame.is_finite(): return {"valid": false, "reason": "nonfinite_rehydrated_pose_frame"}
		if not saved.get("transform_to_parent") is Dictionary:
			return {"valid": false, "reason": "missing_serialized_pose_frame"}
		var encoded: Dictionary = saved.transform_to_parent
		if not encoded.get("origin") is Array or encoded.origin.size() != 3 or not encoded.get("basis") is Array or encoded.basis.size() != 3:
			return {"valid": false, "reason": "malformed_serialized_pose_frame"}
		for axis: int in range(3):
			if not (encoded.origin[axis] is float or encoded.origin[axis] is int) or not is_finite(float(encoded.origin[axis])) or not encoded.basis[axis] is Array or encoded.basis[axis].size() != 3:
				return {"valid": false, "reason": "invalid_or_nonfinite_serialized_pose_origin"}
			maximum = maxf(maximum, absf(frame.origin[axis] - float(encoded.origin[axis])))
			for component: int in range(3):
				if not (encoded.basis[axis][component] is float or encoded.basis[axis][component] is int) or not is_finite(float(encoded.basis[axis][component])):
					return {"valid": false, "reason": "invalid_or_nonfinite_serialized_pose_basis"}
				maximum = maxf(maximum, absf(frame.basis[axis][component] - float(encoded.basis[axis][component])))
	return {"valid": maximum <= 0.000001, "max_frame_component_error": maximum, "comparison_tolerance": 0.000001,
		"reason": "" if maximum <= 0.000001 else "rehydrated_pose_differs_from_recorded_frames"}


func _origin_closure(records: Array, initial: Dictionary) -> Dictionary:
	var lookup := {}
	for record: Dictionary in records: lookup[record.origin_id] = record
	var wanted := initial.duplicate()
	var pending: Array = wanted.keys()
	while not pending.is_empty():
		var id: Variant = pending.pop_back()
		if not lookup.has(id): return {"valid": false, "reason": "observation_origin_missing", "origin_id": id}
		var parent: StringName = lookup[id].parent_origin_id
		if parent != StringName() and not wanted.has(parent):
			wanted[parent] = true; pending.append(parent)
	var selected: Array = []
	for record: Dictionary in records:
		if wanted.has(record.origin_id): selected.append(record)
	return {"valid": true, "records": selected}
