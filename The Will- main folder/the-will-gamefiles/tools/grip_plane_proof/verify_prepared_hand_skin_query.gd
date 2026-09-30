extends SceneTree

const Query = preload("res://tools/grip_plane_proof/prepared_hand_skin_query.gd")
const Store = preload("res://tools/grip_plane_proof/character_hand_anatomy_store.gd")
const Origins = preload("res://core/models/combat_origin_record.gd")
const SIGNATURE: String = "0fb9e5dbe88cd71e342f4efe106676026345d283374abede7dc98853dd784bf5"
const DEFINITION_PATH: String = "res://tools/grip_plane_proof/prepared_characters/josie/" + SIGNATURE + ".tres"
const SYNTHETIC_SIGNATURE: String = "explicit_numeric_skin_fixture_v1"
const ROOT_ID: StringName = &"RL_BoneRoot"
const PARENT_ID: StringName = &"SkinVerifierParentOrigin"
const MESH_ID: StringName = &"SkinVerifierMeshOrigin"
const ERROR_LIMIT_M: float = 3.0e-6

var _assertions: int = 0
var _failures: Array[String] = []
var _cases: Array[Dictionary] = []
var _capture_checks: Array[Dictionary] = []

# This verifier creates explicit pose fixtures from saved source geometry and
# optionally reads coherent captures explicitly supplied through the environment.
# Synthetic cases are not captured gameplay poses. No case certifies contact/IK.
# The oracle skins ORIGINAL vertices with ORIGINAL bind poses/weights directly;
# it does not read prepared coefficients or resolve the query's origin registry.
func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_numeric_fixture()
	_test_affine_bind_fixture()
	_test_saved_anatomy()
	var report: Dictionary = {
		"schema": "prepared_hand_skin_query_verifier_v1",
		"ok": _failures.is_empty(), "assertion_count": _assertions,
		"failures": _failures, "cases": _cases,
		"anatomy_path": DEFINITION_PATH, "source_signature": SIGNATURE,
		"pose_source": "explicit_synthetic_fixtures_and_optional_supplied_capture_packets",
		"captured_pose_checks": _capture_checks,
		"gameplay_behavior_verified": false, "actual_3d_grip_verified": false,
		"anatomy_recomputed": false, "production_pose_written": false,
		"weapon_input_required": false, "error_limit_m": ERROR_LIMIT_M,
	}
	var stamp: String = Time.get_datetime_string_from_system().replace(":", "-")
	var output: String = "C:/WORKSPACE/test_artifacts/verify_prepared_hand_skin_query_" + stamp + ".json"
	var file: FileAccess = FileAccess.open(output, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write verifier report: " + output)
		quit(1)
		return
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("PREPARED_HAND_SKIN_QUERY_RESULT=" + output)
	print("PREPARED_HAND_SKIN_QUERY_SUMMARY=" + JSON.stringify({"ok": report.ok, "assertions": _assertions, "failures": _failures, "cases": _cases}))
	quit(0 if _failures.is_empty() else 1)


func _test_numeric_fixture() -> void:
	var reference: Dictionary = _numeric_reference()
	var reference_before: PackedByteArray = var_to_bytes(reference)
	var query: RefCounted = Query.new()
	var prepared: Dictionary = query.prepare(reference, SYNTHETIC_SIGNATURE)
	if not _check(bool(prepared.get("valid", false)), "numeric preparation: " + str(prepared.get("reason", ""))):
		return
	var prepared_before: PackedByteArray = var_to_bytes(prepared)
	var frames: Dictionary = {
		ROOT_ID: Transform3D.IDENTITY,
		&"FixtureMiddle": Transform3D(Basis.IDENTITY, Vector3(1.0, 2.0, 0.0)),
		&"FixtureThumb": Transform3D(Basis(Vector3.FORWARD, -PI / 2.0), Vector3(0.0, 3.0, 0.0)),
	}
	var mesh: Transform3D = Transform3D(Basis.IDENTITY, Vector3(4.0, 0.0, 0.0))
	var packet: Dictionary = _packet(reference, SYNTHETIC_SIGNATURE, frames, mesh, Transform3D.IDENTITY, &"numeric")
	var packet_before: PackedByteArray = var_to_bytes(packet)
	var result: Dictionary = query.pose(prepared, packet)
	if not _check(bool(result.get("valid", false)), "numeric pose: " + str(result.get("reason", ""))):
		return
	var vertices: PackedVector3Array = result.get("vertices_world", PackedVector3Array())
	_check(vertices.size() == 6, "indexed and unindexed source surfaces retain all six vertices")
	if vertices.size() == 6:
		# Hand calculated: .25*(3,2,0) + .5*(0,5,0) + .25*(4,0,0).
		_check(vertices[0].distance_to(Vector3(1.75, 3.0, 0.0)) <= ERROR_LIMIT_M, "nonunit weights preserve exact numeric point (1.75,3,0)")
	_check(result.get("triangle_indices", PackedInt32Array()) == PackedInt32Array([0, 1, 2, 3, 4, 5]), "surface triangle indices preserve source ordering and offsets")
	_check(result.get("surface_ranges", []).size() == 2, "both source surfaces retain provenance")
	_compare_oracle("numeric_nonunit_and_unit_weights", result, reference, frames, mesh, Transform3D.IDENTITY)
	_check(var_to_bytes(reference) == reference_before, "prepare and pose preserve numeric anatomy input")
	_check(var_to_bytes(packet) == packet_before, "pose preserves the explicit packet")
	var repeated: Dictionary = query.pose(prepared, packet)
	_check(repeated.get("vertices_world") == result.get("vertices_world"), "repeated identical pose is deterministic")
	_check(var_to_bytes(prepared) == prepared_before, "repeated evaluations preserve prepared anatomy coefficients")
	_test_output_isolation(query, prepared, packet)
	var without_unused: Dictionary = packet.duplicate(true)
	without_unused["bone_origin_ids"].erase(ROOT_ID)
	var unused_result: Dictionary = query.pose(prepared, without_unused)
	_check(bool(unused_result.get("valid", false)) and unused_result.get("vertices_world") == vertices, "zero-weight source bind does not require an unused pose mapping")
	var without_rests: Dictionary = reference.duplicate(true)
	without_rests.erase("bind_global_rests")
	var no_rest_prepared: Dictionary = query.prepare(without_rests, SYNTHETIC_SIGNATURE)
	_check(bool(no_rest_prepared.get("valid", false)), "preparation does not require stored rest transforms as pose fallback")
	# Presentation scale/rotation must be applied once after machine-space skinning.
	var presentation: Transform3D = Transform3D(Basis.from_euler(Vector3(0.2, -0.4, 0.7)).scaled(Vector3(1.7, 0.6, 2.1)), Vector3(2.4, -3.0, 0.8))
	var moved_packet: Dictionary = _packet(reference, SYNTHETIC_SIGNATURE, frames, mesh, presentation, &"numeric_presentation")
	var moved: Dictionary = query.pose(prepared, moved_packet)
	if _check(bool(moved.get("valid", false)), "nonuniform presentation accepted"):
		_compare_oracle("numeric_nonuniform_presentation", moved, reference, frames, mesh, presentation)
		_check(moved.get("vertices_machine") == result.get("vertices_machine"), "presentation change does not change machine-space surface")
	for phase: StringName in [&"bake_time", &"post_final_pose"]:
		var phased: Dictionary = packet.duplicate(true)
		phased["resolve_phase"] = phase
		for record: Dictionary in phased["origin_records"]:
			record["resolve_phase"] = phase
		var phase_result: Dictionary = query.pose(prepared, phased)
		_check(bool(phase_result.get("valid", false)) and phase_result.get("vertices_world") == vertices, "explicit coherent " + String(phase) + " phase accepted")
	_test_pose_rejections(query, prepared, packet)
	_test_preparation_rejections(query, reference)


func _test_output_isolation(query: RefCounted, prepared: Dictionary, packet: Dictionary) -> void:
	var original: PackedByteArray = var_to_bytes(prepared)
	for field: String in ["triangle_indices", "triangle_surface_ids", "triangle_local_ids"]:
		var result: Dictionary = query.pose(prepared, packet)
		if not _check(bool(result.get("valid", false)), "output isolation pose for " + field):
			continue
		var expected: PackedInt32Array = (result[field] as PackedInt32Array).duplicate()
		# Deliberately modify through the returned Dictionary, not a detached local.
		result[field][0] = -1234
		_check(var_to_bytes(prepared) == original, "editing returned " + field + " cannot change prepared anatomy")
		var following: Dictionary = query.pose(prepared, packet)
		_check(bool(following.get("valid", false)) and following.get(field) == expected, "editing returned " + field + " cannot change subsequent output")


func _test_affine_bind_fixture() -> void:
	var reference: Dictionary = _numeric_reference()
	# Columns carry shear and reflection explicitly; no orthonormalization is valid.
	reference["bind_poses"][1] = Transform3D(Basis(Vector3(-1.0, 0.2, 0.0), Vector3(0.3, 1.2, 0.1), Vector3(0.0, 0.15, 0.8)), Vector3(0.12, -0.07, 0.2))
	reference["bind_poses"][2] = Transform3D(Basis(Vector3(0.9, 0.1, 0.2), Vector3(0.4, -0.8, 0.0), Vector3(0.05, 0.2, 1.1)), Vector3(-0.08, 0.04, -0.15))
	var frames: Dictionary = {
		ROOT_ID: Transform3D.IDENTITY,
		&"FixtureMiddle": Transform3D(Basis(Vector3(0.8, 0.0, 0.1), Vector3(0.2, -1.1, 0.0), Vector3(0.3, 0.1, 1.2)), Vector3(0.4, -0.3, 0.7)),
		&"FixtureThumb": Transform3D(Basis(Vector3(-0.7, 0.1, 0.2), Vector3(0.3, 0.9, 0.0), Vector3(0.1, -0.2, 1.3)), Vector3(-0.2, 0.8, 0.1)),
	}
	var mesh: Transform3D = Transform3D(Basis(Vector3(-1.2, 0.1, 0.0), Vector3(0.2, 0.8, 0.0), Vector3(0.0, 0.3, 1.4)), Vector3(0.6, -0.4, 0.9))
	var presentation: Transform3D = Transform3D(Basis.from_euler(Vector3(0.3, -0.1, 0.5)), Vector3(-0.4, 0.3, 0.9))
	var query: RefCounted = Query.new()
	var prepared: Dictionary = query.prepare(reference, SYNTHETIC_SIGNATURE)
	if not _check(bool(prepared.get("valid", false)), "sheared and reflected source binds prepare"):
		return
	var packet: Dictionary = _packet(reference, SYNTHETIC_SIGNATURE, frames, mesh, presentation, &"affine_bind_bone_and_mesh_fixture")
	var result: Dictionary = query.pose(prepared, packet)
	if _check(bool(result.get("valid", false)), "sheared and reflected bone/mesh frames pose"):
		_compare_oracle("sheared_reflected_bind_bone_mesh_fixture", result, reference, frames, mesh, presentation)


func _test_saved_anatomy() -> void:
	var loaded: Dictionary = Store.new().load_matching(DEFINITION_PATH, SIGNATURE, "rest_middle_thumb_surface_measurements_v1")
	if not _check(bool(loaded.get("valid", false)), "saved anatomy matches its existing signature and schema"):
		return
	var definition: Resource = loaded["resource"]
	var reference: Dictionary = definition.get("reference_skin")
	var before: PackedByteArray = var_to_bytes(reference)
	var query: RefCounted = Query.new()
	var prepared: Dictionary = query.prepare(reference, SIGNATURE)
	if not _check(bool(prepared.get("valid", false)), "saved source preparation: " + str(prepared.get("reason", ""))):
		return
	var frames: Dictionary = {}
	for name_value: Variant in reference["bind_bone_names"]:
		var name: StringName = StringName(name_value)
		frames[name] = reference["bone_origin_records"][name]["transform_to_parent"]
	var mesh: Transform3D = reference["mesh_origin_record"]["transform_to_parent"]
	var presentation: Transform3D = Transform3D(Basis.from_euler(Vector3(-0.21, 0.37, 0.48)).scaled(Vector3(1.2, 0.9, 1.6)), Vector3(-2.0, 1.3, 4.0))
	var packet: Dictionary = _packet(reference, SIGNATURE, frames, mesh, presentation, &"saved_geometry_explicit_rest_fixture")
	var packet_before: PackedByteArray = var_to_bytes(packet)
	var baseline: Dictionary = query.pose(prepared, packet)
	if not _check(bool(baseline.get("valid", false)), "saved geometry with explicit complete reference-rest poses"):
		return
	_compare_oracle("saved_geometry_explicit_rest_fixture", baseline, reference, frames, mesh, presentation)
	_check(var_to_bytes(packet) == packet_before, "saved-geometry packet remains immutable")
	var weighted: Dictionary = _weighted_bone_names(reference)
	for side: String in ["L", "R"]:
		var candidate_frames: Dictionary = frames.duplicate(true)
		var changed: Array[String] = []
		for name_value: Variant in reference["bind_bone_names"]:
			var name: StringName = StringName(name_value)
			var text_name: String = String(name)
			if not text_name.begins_with("CC_Base_" + side + "_"):
				continue
			if not (text_name.contains("Hand") or text_name.contains("Mid") or text_name.contains("Thumb") or text_name.contains("Index") or text_name.contains("Ring") or text_name.contains("Pinky") or text_name.contains("Forearm")):
				continue
			# Different simultaneous changes forbid a single selected-digit/rest shortcut.
			var index: int = changed.size() + 1
			var old: Transform3D = candidate_frames[name]
			var rotation: Basis = Basis.from_euler(Vector3(0.019 * index, -0.013 * index, 0.009 * index))
			candidate_frames[name] = Transform3D(rotation * old.basis, old.origin + Vector3(0.0007 * index, -0.0004 * index, 0.0002 * index))
			changed.append(text_name)
		_check(changed.size() >= 19, side + " fixture changes Hand, every digit and forearm simultaneously")
		for token: String in ["Mid", "Thumb", "Index", "Ring", "Pinky", "Forearm"]:
			var has_weighted: bool = false
			for name: String in changed:
				has_weighted = has_weighted or (name.contains(token) and weighted.has(StringName(name)))
			_check(has_weighted, side + " source has positive " + token + " influences")
		var candidate_packet: Dictionary = _packet(reference, SIGNATURE, candidate_frames, mesh, presentation, StringName("saved_geometry_" + side + "_synthetic_simultaneous_pose"))
		var candidate_before: PackedByteArray = var_to_bytes(candidate_packet)
		var posed: Dictionary = query.pose(prepared, candidate_packet)
		if not _check(bool(posed.get("valid", false)), side + " simultaneous all-contributor pose accepted"):
			continue
		_compare_oracle("saved_geometry_" + side + "_synthetic_simultaneous_pose", posed, reference, candidate_frames, mesh, presentation)
		_check(_maximum_error(posed["vertices_world"], baseline["vertices_world"]) > 1.0e-4, side + " coherent surface responds to combined inputs")
		_check(var_to_bytes(candidate_packet) == candidate_before, side + " candidate input remains immutable")
		var again: Dictionary = query.pose(prepared, candidate_packet)
		_check(again.get("vertices_world") == posed.get("vertices_world"), side + " repeated complete candidate remains deterministic")
		var forearm_name: StringName = StringName()
		for name: Variant in weighted:
			if String(name).begins_with("CC_Base_" + side + "_") and String(name).contains("Forearm"):
				forearm_name = StringName(name)
				break
		if forearm_name != StringName():
			var missing: Dictionary = candidate_packet.duplicate(true)
			missing["bone_origin_ids"].erase(forearm_name)
			_expect_rejected(query.pose(prepared, missing), side + " missing contributing forearm mapping")
			missing = candidate_packet.duplicate(true)
			_remove_origin(missing, StringName(missing["bone_origin_ids"][forearm_name]))
			_expect_rejected(query.pose(prepared, missing), side + " missing contributing forearm frame")
	_check(var_to_bytes(reference) == before, "saved reference geometry, weights and binds remain byte-identical")
	_check(not packet.has("weapon") and not packet.has("object_contact"), "shared skin query requires no weapon for open/free-hand use")
	_test_optional_captures(query, prepared, reference)


func _test_optional_captures(query: RefCounted, prepared: Dictionary, reference: Dictionary) -> void:
	var requested: String = OS.get_environment("THE_WILL_COHERENT_CAPTURE_PATHS")
	if requested.strip_edges().is_empty():
		return
	for requested_path: String in requested.split(";", false):
		var path: String = _checked_capture_path(requested_path)
		if not _check(not path.is_empty(), "capture path is an existing .bin inside test_artifacts without links: " + requested_path):
			continue
		var file: FileAccess = FileAccess.open(path, FileAccess.READ)
		if not _check(file != null, "capture opens read-only: " + path):
			continue
		var decoded: Variant = file.get_var(false)
		file.close()
		if not _check(decoded is Dictionary and decoded.get("posed_character") is Dictionary, "capture includes the coherent posed_character packet: " + path):
			continue
		var capture: Dictionary = decoded
		var packet: Dictionary = capture["posed_character"]
		if not _check(bool(packet.get("valid", false)) and packet.get("schema") == &"coherent_skin_pose_capture_v1", "capture declares a complete coherent source pose: " + path):
			continue
		var before: PackedByteArray = var_to_bytes(packet)
		var before_failures: int = _failures.size()
		var result: Dictionary = query.pose(prepared, packet)
		if not _check(bool(result.get("valid", false)), "captured complete pose evaluates: " + path + ": " + str(result.get("reason", ""))):
			_capture_checks.append({"path": path, "ok": false, "reason": result.get("reason")})
			continue
		# The oracle composes the capture's original records independently of the
		# evaluator and its registry. No prepared coefficients or returned frames.
		var frame_state: Dictionary = _direct_capture_frames(packet)
		if not _check(bool(frame_state.get("valid", false)), "capture has complete independent oracle frames: " + path):
			_capture_checks.append({"path": path, "ok": false, "reason": frame_state.get("reason")})
			continue
		var label: String = "captured_" + String(capture.get("slot", &"unspecified")) + "_" + path.get_file()
		_compare_oracle(label, result, reference, frame_state["bones"], frame_state["mesh"], packet["machine_to_world"])
		_compare_capture_seams(capture, packet, frame_state, label)
		_check(var_to_bytes(packet) == before, "captured packet remains unchanged: " + path)
		_capture_checks.append({"path": path, "ok": _failures.size() == before_failures, "slot": capture.get("slot"),
			"pose_id": packet.get("pose_id"), "capture_ms": packet.get("capture_ms"),
			"evaluation_ms": result.get("elapsed_ms"), "actual_3d_grip_verified": false})


func _compare_capture_seams(capture: Dictionary, packet: Dictionary, frame_state: Dictionary, label: String) -> void:
	var captured_frame: Dictionary = capture.get("capture_frame", {})
	var presentation: Transform3D = packet["machine_to_world"]
	_check(captured_frame.get("machine_origin_id") == ROOT_ID and captured_frame.get("machine_to_world") == presentation,
		label + " diagnostic machine frame agrees with coherent capture")
	var parents: Dictionary = packet.get("source_bone_parent_ids", {})
	var digits: Dictionary = capture.get("digits", {})
	_check(not digits.is_empty(), label + " has acquisition digit inputs for capture seam comparison")
	for digit_id: Variant in digits:
		var snapshot: Dictionary = digits[digit_id].get("snapshot", {})
		var names: Array = snapshot.get("bone_names", [])
		if not _check(not names.is_empty() and snapshot.get("root_parent_world") is Transform3D, label + " " + String(digit_id) + " declares the direct current parent frame"):
			continue
		var parent_name: StringName = StringName(parents.get(names[0], StringName()))
		if not _check(frame_state["bones"].has(parent_name), label + " " + String(digit_id) + " parent belongs to coherent capture"):
			continue
		var expected: Transform3D = presentation * (frame_state["bones"][parent_name] as Transform3D)
		var observed: Transform3D = snapshot["root_parent_world"]
		var error: float = maxf(expected.origin.distance_to(observed.origin), maxf(expected.basis.x.distance_to(observed.basis.x), maxf(expected.basis.y.distance_to(observed.basis.y), expected.basis.z.distance_to(observed.basis.z))))
		_check(error <= ERROR_LIMIT_M, label + " " + String(digit_id) + " direct current parent agrees with coherent pose")
	# base_bone_world intentionally is NOT compared: the old solver reconstructs
	# it from cached neutral/open rotations, rather than current digit poses.


func _checked_capture_path(requested: String) -> String:
	var path: String = requested.strip_edges().replace("\\", "/").simplify_path()
	if not path.is_absolute_path() or not path.to_lower().begins_with("c:/workspace/test_artifacts/") or path.get_extension().to_lower() != "bin":
		return ""
	# Reject alternate data streams as well as junction/symlink escape paths.
	if path.substr(3).contains(":"):
		return ""
	var workspace: DirAccess = DirAccess.open("C:/WORKSPACE")
	if workspace == null or workspace.is_link("C:/WORKSPACE"):
		return ""
	var checked: String = "C:/WORKSPACE"
	for segment: String in path.substr("C:/WORKSPACE/".length()).split("/", false):
		checked = checked.path_join(segment)
		if workspace.is_link(checked):
			return ""
	return path if FileAccess.file_exists(path) else ""


func _direct_capture_frames(packet: Dictionary) -> Dictionary:
	var records: Dictionary = {}
	for record: Dictionary in packet["origin_records"]:
		records[StringName(record["origin_id"])] = record
	var bones: Dictionary = {}
	for source_name: Variant in packet["bone_origin_ids"]:
		var resolved: Dictionary = _direct_origin_frame(records, StringName(packet["bone_origin_ids"][source_name]))
		if not bool(resolved.get("valid", false)):
			return resolved
		bones[StringName(source_name)] = resolved["frame"]
	var mesh: Dictionary = _direct_origin_frame(records, StringName(packet["mesh_origin_id"]))
	if not bool(mesh.get("valid", false)):
		return mesh
	return {"valid": true, "bones": bones, "mesh": mesh["frame"]}


func _direct_origin_frame(records: Dictionary, id: StringName) -> Dictionary:
	var result: Transform3D = Transform3D.IDENTITY
	var seen: Dictionary = {}
	var current: StringName = id
	while current != ROOT_ID:
		if not records.has(current) or seen.has(current):
			return {"valid": false, "reason": "oracle_missing_or_cyclic_origin"}
		seen[current] = true
		var record: Dictionary = records[current]
		result = (record["transform_to_parent"] as Transform3D) * result
		current = StringName(record["parent_origin_id"])
	return {"valid": true, "frame": result}


func _compare_oracle(label: String, result: Dictionary, reference: Dictionary, frames: Dictionary, mesh: Transform3D, presentation: Transform3D) -> void:
	var expected_machine: PackedVector3Array = _direct_original_skin(reference, frames, mesh)
	var expected_world: PackedVector3Array = presentation * expected_machine
	var machine_error: float = _maximum_error(result.get("vertices_machine", PackedVector3Array()), expected_machine)
	var world_error: float = _maximum_error(result.get("vertices_world", PackedVector3Array()), expected_world)
	_check(machine_error <= ERROR_LIMIT_M, label + " machine vertices agree with independent original-array LBS")
	_check(world_error <= ERROR_LIMIT_M, label + " world vertices agree after full presentation transform")
	_check(result.get("origin_id") == ROOT_ID, label + " output declares machine origin")
	_check(result.get("machine_to_world") == presentation, label + " output preserves complete presentation frame")
	var round_trip_error: float = 0.0
	var result_machine: PackedVector3Array = result.get("vertices_machine", PackedVector3Array())
	var result_world: PackedVector3Array = result.get("vertices_world", PackedVector3Array())
	if result_machine.size() != result_world.size() or result_machine.is_empty():
		round_trip_error = INF
	else:
		var inverse: Transform3D = presentation.affine_inverse()
		for index: int in range(result_machine.size()):
			round_trip_error = maxf(round_trip_error, result_machine[index].distance_to(inverse * result_world[index]))
	_check(round_trip_error <= ERROR_LIMIT_M, label + " world surface round trips to its named machine frame")
	_check(result.get("actual_3d_grip_verified", true) == false, label + " surface reconstruction makes no grip claim")
	_cases.append({"label": label, "vertices": expected_machine.size(), "max_machine_error_m": machine_error,
		"max_world_error_m": world_error, "preparation_ms": result.get("preparation_ms"),
		"evaluation_ms": result.get("evaluation_ms", result.get("elapsed_ms")), "pose_id": result.get("pose_id")})


func _direct_original_skin(reference: Dictionary, frames: Dictionary, mesh: Transform3D) -> PackedVector3Array:
	var output: PackedVector3Array = PackedVector3Array()
	for source: Dictionary in reference["surfaces"]:
		var vertices: PackedVector3Array = source["vertices"]
		var weights: PackedFloat32Array = source["weights"]
		var bone_indices: PackedInt32Array = source["bones"]
		var width: int = weights.size() / vertices.size()
		for vertex_index: int in range(vertices.size()):
			var point: Vector3 = Vector3.ZERO # Explicitly RL_BoneRoot machine coordinates.
			var total: float = 0.0
			for slot: int in range(width):
				var index: int = vertex_index * width + slot
				var weight: float = weights[index]
				if weight == 0.0:
					continue
				var bind_index: int = bone_indices[index]
				var bone_name: StringName = reference["bind_bone_names"][bind_index]
				var frame: Transform3D = frames[bone_name]
				var bind: Transform3D = reference["bind_poses"][bind_index]
				point += weight * (frame * (bind * vertices[vertex_index]))
				total += weight
			point += (1.0 - total) * mesh.origin
			output.append(point)
	return output


func _test_pose_rejections(query: RefCounted, prepared: Dictionary, packet: Dictionary) -> void:
	for key: String in ["pose_id", "anatomy_signature", "root_origin_id", "resolve_phase", "machine_to_world", "mesh_origin_id", "bone_origin_ids", "origin_records"]:
		var missing: Dictionary = packet.duplicate(true)
		missing.erase(key)
		_expect_rejected(query.pose(prepared, missing), "missing packet " + key)
	var bad: Dictionary = packet.duplicate(true)
	bad["anatomy_signature"] = "a_different_character_revision"
	_expect_rejected(query.pose(prepared, bad), "mismatched anatomy revision")
	bad = packet.duplicate(true)
	bad["resolve_phase"] = &"unknown"
	_expect_rejected(query.pose(prepared, bad), "unknown packet phase")
	bad = packet.duplicate(true)
	bad["origin_records"].append(bad["origin_records"][1].duplicate(true))
	_expect_rejected(query.pose(prepared, bad), "duplicate origin identity")
	bad = packet.duplicate(true)
	_find_origin(bad, PARENT_ID)["parent_origin_id"] = MESH_ID
	_expect_rejected(query.pose(prepared, bad), "cycle through parent and mesh")
	bad = packet.duplicate(true)
	_find_origin(bad, PARENT_ID)["parent_origin_id"] = &"MissingAncestor"
	_expect_rejected(query.pose(prepared, bad), "missing named ancestor")
	bad = packet.duplicate(true)
	_find_origin(bad, ROOT_ID)["transform_to_parent"] = Transform3D(Basis.IDENTITY, Vector3.ONE)
	_expect_rejected(query.pose(prepared, bad), "nonidentity machine root")
	bad = packet.duplicate(true)
	_find_origin(bad, MESH_ID)["resolve_phase"] = &"bake_time"
	_expect_rejected(query.pose(prepared, bad), "mixed resolve phases")
	bad = packet.duplicate(true)
	bad["bone_origin_ids"][&"FixtureThumb"] = bad["bone_origin_ids"][&"FixtureMiddle"]
	_expect_rejected(query.pose(prepared, bad), "two distinct source bones alias one pose identity")
	bad = packet.duplicate(true)
	bad["bone_origin_ids"][&"FixtureThumb"] = MESH_ID
	_expect_rejected(query.pose(prepared, bad), "bone cannot borrow posed mesh identity")
	bad = packet.duplicate(true)
	bad["bone_origin_ids"][&"FixtureThumb"] = ROOT_ID
	_expect_rejected(query.pose(prepared, bad), "nonroot bone cannot borrow machine root identity")
	for key: String in ["owner_system", "resolve_phase", "space_type", "is_dynamic", "transform_to_parent", "parent_origin_id"]:
		bad = packet.duplicate(true)
		_find_origin(bad, MESH_ID).erase(key)
		_expect_rejected(query.pose(prepared, bad), "missing origin record " + key)
	for frame: Transform3D in [Transform3D(Basis(Vector3.ZERO, Vector3.UP, Vector3.BACK), Vector3.ZERO), Transform3D(Basis.IDENTITY, Vector3(NAN, 0.0, 0.0))]:
		bad = packet.duplicate(true)
		bad["machine_to_world"] = frame
		_expect_rejected(query.pose(prepared, bad), "nonfinite or singular presentation")
		bad = packet.duplicate(true)
		_find_origin(bad, MESH_ID)["transform_to_parent"] = frame
		_expect_rejected(query.pose(prepared, bad), "nonfinite or singular posed mesh frame")


func _test_preparation_rejections(query: RefCounted, reference: Dictionary) -> void:
	_expect_rejected(query.prepare(reference, ""), "empty anatomy signature")
	var bad: Dictionary = reference.duplicate(true)
	bad["surfaces"][0]["weights"][0] = -0.25
	_expect_rejected(query.prepare(bad, SYNTHETIC_SIGNATURE), "negative source weight")
	bad = reference.duplicate(true)
	bad["surfaces"][0]["weights"][0] = NAN
	_expect_rejected(query.prepare(bad, SYNTHETIC_SIGNATURE), "nonfinite source weight")
	bad = reference.duplicate(true)
	bad["surfaces"][0]["bones"][0] = 999
	_expect_rejected(query.prepare(bad, SYNTHETIC_SIGNATURE), "invalid contributing bind index")
	bad = reference.duplicate(true)
	bad["surfaces"][0]["indices"][0] = 999
	_expect_rejected(query.prepare(bad, SYNTHETIC_SIGNATURE), "invalid source triangle index")
	bad = reference.duplicate(true)
	bad["surfaces"][0]["vertices"][0] = Vector3(INF, 0.0, 0.0)
	_expect_rejected(query.prepare(bad, SYNTHETIC_SIGNATURE), "nonfinite source vertex")
	bad = reference.duplicate(true)
	bad["bind_poses"][1] = Transform3D(Basis(Vector3.ZERO, Vector3.UP, Vector3.BACK), Vector3.ZERO)
	_expect_rejected(query.prepare(bad, SYNTHETIC_SIGNATURE), "singular source bind")


func _numeric_reference() -> Dictionary:
	var names: Array[StringName] = [ROOT_ID, &"FixtureMiddle", &"FixtureThumb"]
	var records: Dictionary = {}
	for name: StringName in names:
		records[name] = _origin(name, StringName() if name == ROOT_ID else ROOT_ID, Transform3D.IDENTITY, &"bake_time")
	return {"bind_bone_names": names,
		"bind_poses": [Transform3D.IDENTITY, Transform3D.IDENTITY, Transform3D.IDENTITY],
		"bind_global_rests": [Transform3D.IDENTITY, Transform3D.IDENTITY, Transform3D.IDENTITY],
		"vertices_origin_id": &"SyntheticReferenceMeshOrigin",
		"mesh_origin_record": _origin(&"SyntheticReferenceMeshOrigin", ROOT_ID, Transform3D.IDENTITY, &"bake_time"),
		"bone_origin_records": records,
		"surfaces": [
			{"vertices": PackedVector3Array([Vector3(2.0, 0.0, 0.0), Vector3(0.0, 1.0, 0.0), Vector3(0.0, 0.0, 1.0)]),
			"indices": PackedInt32Array([0, 1, 2]), "bones": PackedInt32Array([1, 2, 0, 0, 1, 2, 0, 0, 1, 2, 0, 0]),
			"weights": PackedFloat32Array([0.25, 0.5, 0.0, 0.0, 0.75, 0.5, 0.0, 0.0, 0.5, 0.5, 0.0, 0.0])},
			{"vertices": PackedVector3Array([Vector3(2.0, 1.0, 0.0), Vector3(2.0, 0.0, 1.0), Vector3(3.0, 0.0, 0.0)]),
			"indices": PackedInt32Array(), "bones": PackedInt32Array([1, 2, 0, 0, 1, 2, 0, 0, 1, 2, 0, 0]),
			"weights": PackedFloat32Array([0.4, 0.6, 0.0, 0.0, 0.2, 0.8, 0.0, 0.0, 0.8, 0.2, 0.0, 0.0])},
		]}


func _packet(reference: Dictionary, signature: String, frames: Dictionary, mesh: Transform3D, presentation: Transform3D, pose_id: StringName) -> Dictionary:
	var parent: Transform3D = Transform3D(Basis.from_euler(Vector3(0.17, -0.11, 0.23)), Vector3(0.16, -0.11, 0.23))
	var records: Array[Dictionary] = [
		_origin(ROOT_ID, StringName(), Transform3D.IDENTITY, &"editor_preview"),
		_origin(PARENT_ID, ROOT_ID, parent, &"editor_preview"),
		_origin(MESH_ID, PARENT_ID, parent.affine_inverse() * mesh, &"editor_preview"),
	]
	var ids: Dictionary = {}
	for name_value: Variant in reference["bind_bone_names"]:
		var name: StringName = StringName(name_value)
		if name == ROOT_ID:
			ids[name] = ROOT_ID
			continue
		var id: StringName = StringName("SkinVerifier_" + String(name) + "PoseOrigin")
		ids[name] = id
		records.append(_origin(id, PARENT_ID, parent.affine_inverse() * (frames[name] as Transform3D), &"editor_preview"))
	return {"anatomy_signature": signature, "root_origin_id": ROOT_ID, "pose_id": pose_id,
		"resolve_phase": &"editor_preview", "machine_to_world": presentation,
		"mesh_origin_id": MESH_ID, "bone_origin_ids": ids, "origin_records": records}


func _origin(id: StringName, parent: StringName, frame: Transform3D, phase: StringName) -> Dictionary:
	return {"origin_id": id, "parent_origin_id": parent, "transform_to_parent": frame,
		"owner_system": &"verify_prepared_hand_skin_query", "resolve_phase": phase,
		"space_type": &"machine" if id == ROOT_ID else &"bone_frame", "is_dynamic": phase != &"bake_time"}


func _weighted_bone_names(reference: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for surface: Dictionary in reference["surfaces"]:
		var weights: PackedFloat32Array = surface["weights"]
		var indices: PackedInt32Array = surface["bones"]
		for index: int in range(weights.size()):
			if weights[index] > 0.0:
				result[reference["bind_bone_names"][indices[index]]] = true
	return result


func _find_origin(packet: Dictionary, id: StringName) -> Dictionary:
	for record: Dictionary in packet["origin_records"]:
		if record["origin_id"] == id:
			return record
	return {}


func _remove_origin(packet: Dictionary, id: StringName) -> void:
	var records: Array = packet["origin_records"]
	for index: int in range(records.size() - 1, -1, -1):
		if records[index]["origin_id"] == id:
			records.remove_at(index)


func _maximum_error(a: PackedVector3Array, b: PackedVector3Array) -> float:
	if a.size() != b.size() or a.is_empty():
		return INF
	var maximum: float = 0.0
	for index: int in range(a.size()):
		if not a[index].is_finite() or not b[index].is_finite():
			return INF
		maximum = maxf(maximum, a[index].distance_to(b[index]))
	return maximum


func _expect_rejected(result: Dictionary, label: String) -> void:
	_check(not bool(result.get("valid", false)) and not String(result.get("reason", "")).is_empty(), label + " rejects with an explicit reason")


func _check(condition: bool, label: String) -> bool:
	_assertions += 1
	if not condition:
		_failures.append(label)
		push_error(label)
	return condition
