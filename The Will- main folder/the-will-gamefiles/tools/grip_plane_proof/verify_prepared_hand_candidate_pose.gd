extends SceneTree

const Candidate = preload("res://tools/grip_plane_proof/prepared_hand_candidate_pose.gd")
const HandSkin = preload("res://tools/grip_plane_proof/prepared_hand_skin_query.gd")
const Store = preload("res://tools/grip_plane_proof/character_hand_anatomy_store.gd")
const Contact = preload("res://tools/grip_plane_proof/prepared_grip_slice_contact.gd")
const Rules = preload("res://runtime/player/player_digit_hinge_rules.gd")
const SIGNATURE: String = "0fb9e5dbe88cd71e342f4efe106676026345d283374abede7dc98853dd784bf5"
const DEFINITION: String = "res://tools/grip_plane_proof/prepared_characters/josie/" + SIGNATURE + ".tres"
const EPSILON_M: float = 0.000003

var _checks: int = 0
var _failures: Array[String] = []
var _cases: Array[Dictionary] = []
var _anatomy_review: Array[Dictionary] = []
var _selected_digits: Array[StringName] = []

func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var definition_path: String = OS.get_environment("THE_WILL_ANATOMY_RESOURCE_PATH").strip_edges()
	var signature: String = SIGNATURE
	var revision: String = "rest_middle_thumb_surface_measurements_v1"
	if definition_path.is_empty():
		definition_path = DEFINITION
	else:
		if not _check(definition_path.begins_with("res://tools/grip_plane_proof/prepared_characters/josie/") and definition_path.get_extension() == "tres", "explicit prepared anatomy path remains in Josie's resource folder"):
			quit(1); return
		signature = definition_path.get_file().get_basename()
		revision = OS.get_environment("THE_WILL_ANATOMY_PREPARATION_REVISION").strip_edges()
		if revision.is_empty(): revision = Store.FULL_HAND_PREPARATION_REVISION
	for value: String in OS.get_environment("THE_WILL_CANDIDATE_DIGITS").split(",", false):
		var id: StringName = StringName(value.strip_edges())
		if not _check(Rules.DIGIT_IDS.has(id) and not _selected_digits.has(id), "explicit selected digit is known and unique: " + String(id)):
			quit(1); return
		_selected_digits.append(id)
	var loaded: Dictionary = Store.new().load_matching(definition_path, signature, revision)
	if not _check(bool(loaded.get("valid", false)), "load existing measured anatomy"):
		quit(1)
		return
	var slots: Dictionary = {}
	var paths: PackedStringArray = OS.get_environment("THE_WILL_COHERENT_CAPTURE_PATHS").split(";", false)
	_check(not paths.is_empty(), "explicit coherent capture paths supplied")
	for raw_path: String in paths:
		var path: String = raw_path.strip_edges().replace("\\", "/").simplify_path()
		if not _check(_workspace_path(path), "capture confined to workspace test_artifacts: " + path):
			continue
		var file: FileAccess = FileAccess.open(path, FileAccess.READ)
		if not _check(file != null, "read coherent capture: " + path):
			continue
		var raw: Variant = file.get_var(false)
		file.close()
		if not _check(raw is Dictionary, "capture contains a dictionary"):
			continue
		var capture: Dictionary = _capture_entry(raw)
		if not _check(capture.get("posed_character") is Dictionary, "capture or explicit placement trace contains coherent character packet"):
			continue
		var slot: StringName = capture.get("slot", StringName())
		slots[slot] = true
		if _selected_digits.is_empty():
			_test_capture(loaded.resource, capture.posed_character, slot)
		else:
			_test_selected_capture(loaded.resource, capture.posed_character, slot)
	_check(slots.has(&"hand_right") and slots.has(&"hand_left"), "both saved hand setups covered")
	var report: Dictionary = {"schema": "prepared_hand_candidate_pose_verifier_v1", "ok": _failures.is_empty(),
		"checks": _checks, "failures": _failures, "cases": _cases,
		"anatomy_path": definition_path, "anatomy_signature": signature, "preparation_revision": revision,
		"explicit_selected_digits": _selected_digits, "selected_anatomy_review": _anatomy_review,
		"sparse_oracle": "complete_prepared_hand_skin_query_previously_checked_against_original_array_LBS",
		"production_pose_written": false, "arm_realization_verified": false, "actual_3d_grip_verified": false}
	var path: String = "C:/WORKSPACE/test_artifacts/verify_prepared_hand_candidate_pose_" + Time.get_datetime_string_from_system().replace(":", "-") + ".json"
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write verifier report")
		quit(1)
		return
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("HAND_CANDIDATE_RESULT=" + path)
	print("HAND_CANDIDATE_SUMMARY=" + JSON.stringify(report))
	quit(0 if _failures.is_empty() else 1)


func _capture_entry(raw: Dictionary) -> Dictionary:
	if raw.get("posed_character") is Dictionary:
		return raw
	# Observe the last recorded finger input without rewriting or relabeling it.
	var selected: Dictionary = {}
	for transaction: Dictionary in raw.get("transactions", []):
		for stage: Dictionary in transaction.get("finger_inputs", []):
			if stage.get("posed_character") is Dictionary:
				selected = stage
	return selected


func _test_selected_capture(definition: Resource, packet: Dictionary, slot: StringName) -> void:
	var source_before: PackedByteArray = var_to_bytes(packet)
	var anatomy: Dictionary = {}
	for field: String in Store.FIELDS: anatomy[field] = definition.get(field)
	var anatomy_before: PackedByteArray = var_to_bytes(anatomy)
	var reference: Dictionary = definition.get("reference_skin")
	var builder := Candidate.new()
	var prepared: Dictionary = builder.prepare(definition, packet, slot, _selected_digits)
	if not _check(prepared.get("valid", false), String(slot) + " prepare all explicitly selected digits: " + str(prepared.get("reason", ""))): return
	var prepared_before: PackedByteArray = var_to_bytes(prepared)
	_check(prepared.selected_bones.size() == _selected_digits.size() * 3, String(slot) + " selected layout has three unique named bones per digit")
	var zero: Dictionary = _angles(prepared, 0.0)
	var distinct: Dictionary = {}
	for digit_index: int in range(_selected_digits.size()):
		var id: StringName = _selected_digits[digit_index]
		var snapshot: Dictionary = prepared.digit_inputs[id].snapshot
		var angles: Array[float] = []
		for joint: int in range(3): angles.append(float(snapshot.preferred_angles_rad[joint]) * (0.17 + 0.085 * digit_index + 0.035 * joint))
		distinct[id] = angles
		var contact: Dictionary = Contact.new().prepare(prepared, id)
		if _check(contact.get("valid", false), String(slot) + "/" + String(id) + " original-weight contact observer prepares"):
			var digit: Dictionary = prepared.digit_inputs[id].digit
			_anatomy_review.append({"slot": slot, "digit": id, "bone_names": digit.bone_names, "plane_origin_id": digit.plane_origin_id,
				"section_lengths_m": digit.section_lengths_m, "hinge_axis_origin_ids": digit.hinge_axis_origin_ids,
				"min_angles_rad": digit.min_angles_rad, "max_angles_rad": digit.max_angles_rad,
				"overlap_targets_m": contact.targets_m, "overlap_caps_m": contact.caps_m,
				"overlap_source": "unchanged_PlayerDigitHingeRules_and_PlayerFingerSurfaceGripSolver_section_allowances",
				"reach_m": contact.reach_m, "source_hand_triangle_count": contact.triangle_ids.size()})
	var plane: Transform3D = prepared.digit_inputs[_selected_digits[0]].plane_to_world
	var translation: Vector3 = plane.basis.x * 0.004 - plane.basis.y * 0.002
	var baseline: Dictionary = builder.evaluate(prepared, zero, Vector3.ZERO, &"RL_BoneRoot")
	var combined: Dictionary = {}
	for row: Dictionary in [
		{"label": "selected_zero", "angles": zero, "translation": Vector3.ZERO},
		{"label": "simultaneous_distinct_digit_and_joint_angles", "angles": distinct, "translation": Vector3.ZERO},
		{"label": "translated_simultaneous_distinct_angles", "angles": distinct, "translation": translation},
	]:
		var label := String(slot) + "/" + String(row.label)
		var result: Dictionary = builder.evaluate(prepared, row.angles, row.translation, &"RL_BoneRoot")
		_verify_candidate(prepared, result, row.translation, label)
		if not result.get("valid", false): continue
		_verify_original_skin(reference, result, label)
		var repeated: Dictionary = builder.evaluate(prepared, row.angles, row.translation, &"RL_BoneRoot")
		_check(repeated.get("valid", false) and repeated.posed.vertices_world == result.posed.vertices_world, label + " is deterministic")
		if row.label == "simultaneous_distinct_digit_and_joint_angles": combined = result
	if baseline.get("valid", false) and combined.get("valid", false):
		for id: StringName in _selected_digits:
			var every_joint_changed := true
			for joint: int in range(3):
				every_joint_changed = every_joint_changed and _frame_error(baseline.digit_states[id].joint_transforms_world[joint], combined.digit_states[id].joint_transforms_world[joint]) > EPSILON_M
			_check(every_joint_changed, String(slot) + "/" + String(id) + " all three joint frames respond to this digit's nonzero angles")
		for id: StringName in [&"index", &"ring", &"pinky"]:
			if not _selected_digits.has(id): continue
			var changed_angles: Dictionary = distinct.duplicate(true)
			changed_angles[id][0] *= 0.8
			var changed: Dictionary = builder.evaluate(prepared, changed_angles, Vector3.ZERO, &"RL_BoneRoot")
			var label := String(slot) + "/isolated_" + String(id) + "_change"
			_verify_candidate(prepared, changed, Vector3.ZERO, label)
			if not changed.get("valid", false): continue
			_verify_original_skin(reference, changed, label)
			var other_digits_unchanged := true
			for other: StringName in _selected_digits:
				if other != id:
					other_digits_unchanged = other_digits_unchanged and changed.digit_states[other].joint_transforms_world == combined.digit_states[other].joint_transforms_world
			_check(other_digits_unchanged, label + " leaves the other selected joint chains unchanged")
			_check(_vertex_error(changed.posed.vertices_world, combined.posed.vertices_world) > EPSILON_M, label + " changes actual skinned vertices")
	var missing: Dictionary = distinct.duplicate(true)
	missing.erase(_selected_digits.back())
	_rejected(builder.evaluate(prepared, missing, Vector3.ZERO, &"RL_BoneRoot"), String(slot) + " missing one selected digit's angles")
	_check(var_to_bytes(prepared) == prepared_before, String(slot) + " all-digit candidates preserve prepared input")
	_check(var_to_bytes(packet) == source_before, String(slot) + " all-digit candidates preserve complete captured source")
	_check(var_to_bytes(anatomy) == anatomy_before, String(slot) + " all-digit candidates preserve every saved anatomy field")


func _verify_original_skin(reference: Dictionary, candidate: Dictionary, label: String) -> void:
	# Original arrays and bind poses; no prepared coefficients, sparse constants
	# or returned bone transforms. Resolve packet records independently.
	var packet: Dictionary = candidate.pose_packet
	var records: Dictionary = {}
	for record: Dictionary in packet.origin_records: records[record.origin_id] = record
	var frames: Dictionary = {}
	for name: StringName in reference.bind_bone_names:
		var resolved: Dictionary = _direct_frame(records, packet.bone_origin_ids[name])
		if not _check(resolved.get("valid", false), label + " independent origin chain for " + String(name)): return
		frames[name] = resolved.frame
	var resolved_mesh: Dictionary = _direct_frame(records, packet.mesh_origin_id)
	if not _check(resolved_mesh.get("valid", false), label + " independent mesh origin chain"): return
	var mesh: Transform3D = resolved_mesh.frame
	var expected_machine := PackedVector3Array()
	for surface: Dictionary in reference.surfaces:
		var vertices: PackedVector3Array = surface.vertices
		var weights: PackedFloat32Array = surface.weights
		var width: int = weights.size() / vertices.size()
		for vertex: int in range(vertices.size()):
			var point := Vector3.ZERO # RL_BoneRoot coordinates, not a fallback origin.
			var total := 0.0
			for influence: int in range(width):
				var index: int = vertex * width + influence
				var weight: float = weights[index]
				if weight == 0.0: continue
				var bind_index: int = surface.bones[index]
				var name: StringName = reference.bind_bone_names[bind_index]
				point += weight * ((frames[name] as Transform3D) * ((reference.bind_poses[bind_index] as Transform3D) * vertices[vertex]))
				total += weight
			point += (1.0 - total) * mesh.origin
			expected_machine.append(point)
	var expected_world: PackedVector3Array = (packet.machine_to_world as Transform3D) * expected_machine
	var machine_error := _vertex_error(candidate.posed.vertices_machine, expected_machine)
	var world_error := _vertex_error(candidate.posed.vertices_world, expected_world)
	_check(machine_error <= EPSILON_M and world_error <= EPSILON_M, label + " agrees with independent original-array full-skin reconstruction")
	_cases.append({"label": label + "/original_array_oracle", "max_machine_error_m": machine_error, "max_world_error_m": world_error, "vertices": expected_machine.size(), "weights_normalized": false})


func _direct_frame(records: Dictionary, id: StringName) -> Dictionary:
	var frame := Transform3D.IDENTITY
	var seen: Dictionary = {}
	var current: StringName = id
	while current != &"RL_BoneRoot":
		if seen.has(current) or not records.has(current): return {"valid": false}
		seen[current] = true
		frame = (records[current].transform_to_parent as Transform3D) * frame
		current = StringName(records[current].parent_origin_id)
	return {"valid": true, "frame": frame}


func _test_capture(definition: Resource, packet: Dictionary, slot: StringName) -> void:
	var before: PackedByteArray = var_to_bytes(packet)
	var anatomy_before: PackedByteArray = var_to_bytes(definition.get("reference_skin"))
	var builder: RefCounted = Candidate.new()
	var prepared: Dictionary = builder.prepare(definition, packet, slot, [&"middle"])
	if not _check(bool(prepared.get("valid", false)), String(slot) + " prepare: " + str(prepared.get("reason", ""))):
		return
	var prepared_before: PackedByteArray = var_to_bytes(prepared)
	var input: Dictionary = prepared.digit_inputs[&"middle"]
	var plane: Transform3D = input.plane_to_world
	var zero: Dictionary = {&"middle": [0.0, 0.0, 0.0]}
	var bent: Dictionary = _angles(prepared, 0.35)
	var translation: Vector3 = plane.basis.x * 0.004 + plane.basis.y * -0.002
	for row: Dictionary in [
		{"label": "prepared_zero", "angles": zero, "translation": Vector3.ZERO},
		{"label": "coordinated_bend", "angles": bent, "translation": Vector3.ZERO},
		{"label": "in_plane_hand_translation", "angles": zero, "translation": translation},
		{"label": "translated_coordinated_bend", "angles": bent, "translation": translation},
	]:
		var label: String = String(slot) + "/" + row.label
		var result: Dictionary = builder.evaluate(prepared, row.angles, row.translation, &"RL_BoneRoot")
		_verify_candidate(prepared, result, row.translation, label)
		if bool(result.get("valid", false)):
			var repeated: Dictionary = builder.evaluate(prepared, row.angles, row.translation, &"RL_BoneRoot")
			_check(repeated.get("posed", {}).get("vertices_world") == result.posed.vertices_world, label + " is deterministic")
	_check(var_to_bytes(prepared) == prepared_before, String(slot) + " candidate evaluations preserve prepared data")
	_check(var_to_bytes(packet) == before, String(slot) + " immutable captured packet retained")
	_check(var_to_bytes(definition.get("reference_skin")) == anatomy_before, String(slot) + " original skin remains unchanged")
	var both: Dictionary = builder.prepare(definition, packet, slot, [&"middle", &"thumb"])
	if _check(bool(both.get("valid", false)), String(slot) + " prepare Middle and Thumb together"):
		var combined: Dictionary = builder.evaluate(both, _angles(both, 0.2), translation, &"RL_BoneRoot")
		_verify_candidate(both, combined, translation, String(slot) + "/middle_thumb_coherent_candidate")
	var presentation: Transform3D = Transform3D(Basis.from_euler(Vector3(0.2, -0.3, 0.4)), Vector3(0.4, -0.6, 0.3))
	var moved_packet: Dictionary = packet.duplicate(true)
	moved_packet["machine_to_world"] = presentation * (packet.machine_to_world as Transform3D)
	var moved_prepared: Dictionary = builder.prepare(definition, moved_packet, slot, [&"middle"])
	if _check(bool(moved_prepared.get("valid", false)), String(slot) + " rigid presentation preparation"):
		var moved: Dictionary = builder.evaluate(moved_prepared, bent, presentation.basis * translation, &"RL_BoneRoot")
		_verify_candidate(moved_prepared, moved, presentation.basis * translation, String(slot) + "/rigid_presentation")
		var original: Dictionary = builder.evaluate(prepared, bent, translation, &"RL_BoneRoot")
		if bool(moved.get("valid", false)) and bool(original.get("valid", false)):
			_check(_vertex_error(moved.posed.vertices_world, presentation * (original.posed.vertices_world as PackedVector3Array)) <= EPSILON_M, String(slot) + " rigid world presentation covariance")
	var wrong_metric: Dictionary = packet.duplicate(true)
	wrong_metric["machine_to_world"] = Transform3D(Basis.from_scale(Vector3(1.4, 0.8, 1.2)), Vector3.ZERO) * (packet.machine_to_world as Transform3D)
	_rejected(builder.prepare(definition, wrong_metric, slot, [&"middle"]), String(slot) + " changed metric requires matching prepared anatomy")
	_rejected(builder.evaluate(prepared, zero, translation, &"AnonymousPlane"), String(slot) + " wrong translation origin")
	_rejected(builder.evaluate(prepared, zero, Vector3(NAN, 0.0, 0.0), &"RL_BoneRoot"), String(slot) + " nonfinite translation")
	_rejected(builder.evaluate(prepared, {}, Vector3.ZERO, &"RL_BoneRoot"), String(slot) + " omitted selected angles")
	var invalid: Dictionary = {&"middle": [1000.0, 0.0, 0.0]}
	_rejected(builder.evaluate(prepared, invalid, Vector3.ZERO, &"RL_BoneRoot"), String(slot) + " out-of-range articulation")
	var missing: Dictionary = packet.duplicate(true)
	missing.source_bone_parent_ids.erase(input.digit.bone_names[0])
	_rejected(builder.prepare(definition, missing, slot, [&"middle"]), String(slot) + " missing current ancestry")


func _verify_candidate(prepared: Dictionary, result: Dictionary, translation: Vector3, label: String) -> void:
	if not _check(bool(result.get("valid", false)), label + " evaluates: " + str(result.get("reason", ""))):
		return
	var full: Dictionary = HandSkin.new().pose(prepared.skin_prepared, result.pose_packet)
	if not _check(bool(full.get("valid", false)), label + " complete evaluator accepts candidate origins"):
		return
	var world_error: float = _vertex_error(result.posed.vertices_world, full.vertices_world)
	var machine_error: float = _vertex_error(result.posed.vertices_machine, full.vertices_machine)
	_check(world_error <= EPSILON_M and machine_error <= EPSILON_M, label + " sparse evaluation equals full reconstruction")
	_check(result.posed.triangle_indices == full.triangle_indices and result.posed.triangle_surface_ids == full.triangle_surface_ids and result.posed.triangle_local_ids == full.triangle_local_ids,
		label + " full source triangle identity preserved")
	_check(result.affected_vertex_count < result.full_vertex_count, label + " updates a strict dependency subset")
	_check(result.get("arm_realization_verified", true) == false and result.get("actual_3d_grip_verified", true) == false, label + " remains hypothetical placement without grip acceptance")
	var records: Dictionary = {}
	for record: Dictionary in result.pose_packet.origin_records:
		records[record.origin_id] = record
	var machine: Transform3D = prepared.base_packet.machine_to_world
	var delta: Vector3 = machine.basis.inverse() * translation
	var unchanged: bool = true
	var transported: bool = true
	for name: Variant in prepared.base_frames:
		var original: Transform3D = prepared.base_frames[name]
		var actual: Transform3D = records[result.pose_packet.bone_origin_ids[name]].transform_to_parent
		if not prepared.descendant_bones.has(name):
			unchanged = unchanged and original == actual
		elif not prepared.selected_bones.has(name):
			# This fixture has no auxiliary descendant below a selected terminal.
			var desired: Transform3D = original
			desired.origin += delta
			transported = transported and _frame_error(desired, actual) <= EPSILON_M
	_check(unchanged, label + " forearm/upstream/opposite-hand frames unchanged")
	_check(transported, label + " other hand descendants preserve captured articulation")
	_check(records[result.pose_packet.mesh_origin_id].transform_to_parent == prepared.base_pose.mesh_to_machine, label + " mesh residual frame stays unchanged")
	_cases.append({"label": label, "max_world_error_m": world_error, "max_machine_error_m": machine_error,
		"vertices": result.full_vertex_count, "recomputed_vertices": result.affected_vertex_count,
		"candidate_ms": result.evaluation_ms, "full_evaluator_ms": full.elapsed_ms,
		"preparation_ms": prepared.preparation_ms})


func _angles(prepared: Dictionary, fraction: float) -> Dictionary:
	var result: Dictionary = {}
	for id: Variant in prepared.digit_inputs:
		var snapshot: Dictionary = prepared.digit_inputs[id].snapshot
		var angles: Array[float] = []
		for angle: float in snapshot.preferred_angles_rad:
			angles.append(angle * fraction)
		result[id] = angles
	return result


func _vertex_error(a: PackedVector3Array, b: PackedVector3Array) -> float:
	if a.size() != b.size() or a.is_empty():
		return INF
	var error: float = 0.0
	for index: int in range(a.size()):
		if not a[index].is_finite() or not b[index].is_finite():
			return INF
		error = maxf(error, a[index].distance_to(b[index]))
	return error


func _frame_error(a: Transform3D, b: Transform3D) -> float:
	return maxf(a.origin.distance_to(b.origin), maxf(a.basis.x.distance_to(b.basis.x), maxf(a.basis.y.distance_to(b.basis.y), a.basis.z.distance_to(b.basis.z))))


func _workspace_path(path: String) -> bool:
	if not path.is_absolute_path() or not path.to_lower().begins_with("c:/workspace/test_artifacts/") or path.get_extension().to_lower() != "bin" or path.substr(3).contains(":"):
		return false
	var directory: DirAccess = DirAccess.open("C:/WORKSPACE")
	if directory == null or directory.is_link("C:/WORKSPACE"):
		return false
	var current: String = "C:/WORKSPACE"
	for component: String in path.substr("C:/WORKSPACE/".length()).split("/", false):
		current = current.path_join(component)
		if directory.is_link(current):
			return false
	return true


func _rejected(result: Dictionary, label: String) -> void:
	_check(not bool(result.get("valid", false)) and not String(result.get("reason", "")).is_empty(), label + " rejects explicitly")


func _check(condition: bool, label: String) -> bool:
	_checks += 1
	if not condition:
		_failures.append(label)
		push_error(label)
	return condition
