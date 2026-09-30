extends SceneTree

## One saved live result, restored on an isolated real rig. No acquisition,
## arm solve, gameplay write, range change or new contact acceptance.
## Skeleton3D global pose means skeleton space, not presentation/world space:
## https://docs.godotengine.org/en/4.7/classes/class_skeleton3d.html
const RigScene = preload("res://scenes/player/player_humanoid_rig.tscn")
const RigScript = preload("res://runtime/player/player_humanoid_rig.gd")
const Data = preload("res://runtime/player/grip/character_grip_data.gd")
const HandSkin = preload("res://runtime/player/grip/prepared_hand_skin_query.gd")
const ROOT := &"RL_BoneRoot"
const DEFAULT_REPORT := "C:/WORKSPACE/test_artifacts/verify_live_prepared_grip_2026-09-27T14-44-38.json"
const RESTORE_POSITION_GUARD_M := 0.00002
const RESTORE_BASIS_COMPONENT_GUARD := 0.00002
const JSON_PRINT_POSITION_GUARD_M := 0.000002
var _checks := 0
var _failures: Array[String] = []
var _result: Dictionary = {}

func _init() -> void:
	call_deferred("_run")

func _check(condition: bool, label: String) -> bool:
	_checks += 1
	if not condition:
		_failures.append(label)
		push_error(label)
	return condition

func _run() -> void:
	var requested := OS.get_environment("THE_WILL_WRIST_DIAGNOSTIC_REPORT")
	var report_path := (DEFAULT_REPORT if requested.is_empty() else requested).replace("\\", "/").simplify_path()
	if not _check(_workspace_artifact(report_path) and report_path.get_extension() == "json", "workspace report path"):
		_finish(); return
	var report_hash := FileAccess.get_sha256(report_path)
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(report_path))
	if not _check(parsed is Dictionary and parsed.get("ok", false), "completed live verification report"):
		_finish(); return
	var saved: Dictionary = parsed.measurements.result
	var saved_realization: Dictionary = saved.get("realization", {})
	var capture_path := str(parsed.measurements.get("actual_capture", "")).replace("\\", "/").simplify_path()
	if not _check(_workspace_artifact(capture_path) and capture_path.get_extension() == "bin", "workspace capture path"):
		_finish(); return
	var capture_hash := FileAccess.get_sha256(capture_path)
	var file := FileAccess.open(capture_path, FileAccess.READ)
	if not _check(file != null, "saved capture exists"):
		_finish(); return
	var loaded: Variant = file.get_var(false)
	file.close()
	if not _check(loaded is Dictionary and loaded.get("valid", false), "valid saved capture"):
		_finish(); return
	var capture: Dictionary = loaded
	var before_bytes := var_to_bytes(capture)
	var desired: Dictionary = _parse_report_frame(saved_realization.get("target_hand_world"))
	var recorded_actual: Dictionary = _parse_report_frame(saved_realization.get("actual_hand_world"))
	if not _check(desired.get("valid", false) and recorded_actual.get("valid", false), "literal numeric report frames"):
		_finish(); return
	if not _check(int(saved.get("serial", -1)) == int(capture.get("transaction_serial", -2)), "capture and result transaction match"):
		_finish(); return
	var rig: Node3D = RigScene.instantiate()
	root.add_child(rig)
	rig.set_process(false)
	for node: Node in rig.find_children("*", "", true, false):
		if node is AnimationPlayer: node.stop()
		if node is AnimationTree: node.active = false
		if node is SkeletonModifier3D: node.active = false
	var data: Dictionary = Data.load_for_actor(rig)
	if not _check(data.get("valid", false), "real rig has exact prepared rest/bind/skin source"):
		_result["data_error"] = data; rig.queue_free(); _finish(); return
	var pose: Dictionary = capture.posed_character
	if not _check(pose.get("anatomy_signature") == data.anatomy.get("source_signature") and pose.get("root_origin_id") == ROOT, "captured anatomy and root identity"):
		rig.queue_free(); _finish(); return
	var registered: Dictionary = HandSkin.new()._registry(pose.origin_records, pose.resolve_phase)
	if not _check(registered.get("valid", false), "captured named origin chain"):
		rig.queue_free(); _finish(); return
	var skeleton: Skeleton3D = rig.get("skeleton")
	var root_index := skeleton.find_bone(ROOT)
	if not _check(root_index >= 0, "actual machine root exists"):
		rig.queue_free(); _finish(); return
	# Preserve the real rig's rest calibration and restore captured presentation.
	# Only this disposable diagnostic instance receives captured pose dimensions.
	var machine: Transform3D = pose.machine_to_world
	skeleton.global_transform = machine * skeleton.get_bone_global_pose(root_index).affine_inverse()
	var entries: Array[Dictionary] = []
	for name: StringName in pose.bone_origin_ids:
		var index := skeleton.find_bone(name)
		if not _check(index >= 0, "captured bone exists: " + str(name)):
			continue
		var frame: Transform3D = registered.registry.resolve_transform_to_machine(pose.bone_origin_ids[name])
		entries.append({"index": index, "name": name, "depth": _depth(skeleton, index), "world": machine * frame})
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.depth < b.depth)
	for entry: Dictionary in entries:
		skeleton.set_bone_global_pose(entry.index, skeleton.global_transform.affine_inverse() * (entry.world as Transform3D))
	skeleton.force_update_all_bone_transforms()
	var position_error := 0.0
	var component_error := 0.0
	for entry: Dictionary in entries:
		var actual: Transform3D = skeleton.global_transform * skeleton.get_bone_global_pose(entry.index)
		position_error = maxf(position_error, actual.origin.distance_to(entry.world.origin))
		component_error = maxf(component_error, _basis_components_error(actual.basis, entry.world.basis))
	_check(position_error <= RESTORE_POSITION_GUARD_M, "restored captured positions within explicit float guard")
	_check(component_error <= RESTORE_BASIS_COMPONENT_GUARD, "restored captured bases within explicit float guard")
	if not _failures.is_empty():
		_result["restoration"] = {"position_error_m": position_error, "basis_component_error": component_error}
		rig.queue_free(); _finish(); return
	var slot := StringName(capture.slot)
	var hand: StringName = &"CC_Base_R_Hand" if slot == &"hand_right" else &"CC_Base_L_Hand"
	var forearm: StringName = &"CC_Base_R_Forearm" if slot == &"hand_right" else &"CC_Base_L_Forearm"
	var hand_index := skeleton.find_bone(hand)
	var forearm_index := skeleton.find_bone(forearm)
	if not _check(hand_index >= 0 and forearm_index >= 0, "target hand and parent forearm exist"):
		rig.queue_free(); _finish(); return
	var actual_hand: Transform3D = skeleton.global_transform * skeleton.get_bone_global_pose(hand_index)
	var actual_forearm: Transform3D = skeleton.global_transform * skeleton.get_bone_global_pose(forearm_index)
	_check(actual_hand.origin.distance_to(recorded_actual.frame.origin) <= JSON_PRINT_POSITION_GUARD_M, "binary actual Hand matches printed source report")
	_check(_basis_components_error(actual_hand.basis, recorded_actual.frame.basis) <= JSON_PRINT_POSITION_GUARD_M, "binary actual Hand basis matches printed source report")
	var desired_basis: Basis = desired.frame.basis.orthonormalized()
	var neutral: Basis = rig.call("_resolve_neutral_hand_world_basis", hand_index)
	var twist_axis: Vector3 = (actual_hand.origin - actual_forearm.origin).normalized()
	var local_contact_axis: Vector3 = rig.resolve_hand_index_pinky_axis_local(slot)
	var desired_delta: Quaternion = (desired_basis.get_rotation_quaternion().normalized() * neutral.get_rotation_quaternion().normalized().inverse()).normalized()
	var requested_twist: Quaternion = rig.call("_extract_quaternion_twist", desired_delta, twist_axis)
	var requested_angle: float = rig.call("_resolve_signed_twist_angle", requested_twist, twist_axis)
	var desired_swing: Quaternion = (desired_delta * requested_twist.inverse()).normalized()
	var limit_deg: float = rig.get("authoring_contact_wrist_twist_limit_degrees")
	var limit_rad := deg_to_rad(clampf(limit_deg, 0.0, 180.0))
	var limited_angle := clampf(requested_angle, -limit_rad, limit_rad)
	var pure_clamp := Basis((desired_swing * Quaternion(twist_axis, limited_angle).normalized() * neutral.get_rotation_quaternion().normalized()).normalized()).orthonormalized()
	var locked_axis := (desired_basis * local_contact_axis).normalized()
	var reconstruction: Basis = rig.call("_build_basis_aligning_local_axis", local_contact_axis, locked_axis, pure_clamp.y)
	var current_output: Basis = rig.call("_clamp_authoring_contact_wrist_twist", slot, hand, forearm, desired_basis)
	_check(_basis_components_error(reconstruction, current_output) <= RESTORE_BASIS_COMPONENT_GUARD, "decomposition matches current production clamp")
	var named_bones: Dictionary = {}
	for name: StringName in [hand, forearm]: named_bones[name] = pose.bone_origin_ids[name]
	var twists: Array = []
	for name: StringName in rig.call("_get_slot_forearm_twist_bones", slot) + rig.call("_get_slot_upperarm_twist_bones", slot):
		var index := skeleton.find_bone(name)
		var detail := {"bone": name, "exists": index >= 0, "is_ancestor_of_hand": _ancestor(skeleton, index, hand_index),
			"captured_origin_id": pose.bone_origin_ids.get(name, StringName())}
		if index >= 0:
			var rest_rotation := skeleton.get_bone_rest(index).basis.orthonormalized().get_rotation_quaternion().normalized()
			var actual_rotation := skeleton.get_bone_pose_rotation(index).normalized()
			var local_delta := (rest_rotation.inverse() * actual_rotation).normalized()
			var local_twist: Quaternion = rig.call("_extract_quaternion_twist", local_delta, RigScript.AUTHORING_LIMB_TWIST_LOCAL_AXIS)
			var local_angle: float = rig.call("_resolve_signed_twist_angle", local_twist, RigScript.AUTHORING_LIMB_TWIST_LOCAL_AXIS)
			detail["actual_local_twist_from_model_rest_degrees"] = rad_to_deg(local_angle)
			detail["local_non_twist_delta_degrees"] = rad_to_deg(local_delta.angle_to(local_twist))
			detail["comparison_reference"] = "Model rest; original runtime neutral cache was not recorded in this capture."
		twists.append(detail)
	_result = {"report_path": report_path, "report_sha256": report_hash, "capture_path": capture_path, "capture_sha256": capture_hash,
		"slot": slot, "capture_pose_id": pose.pose_id, "anatomy_signature": pose.anatomy_signature,
		"rig_script_sha256": FileAccess.get_sha256("res://runtime/player/player_humanoid_rig.gd"),
		"configured_limit_degrees": limit_deg, "requested_twist_degrees": rad_to_deg(requested_angle), "clamped_twist_degrees": rad_to_deg(limited_angle),
		"world_presentation_origin_id": ROOT, "machine_to_world": _frame_values(machine), "bone_origin_ids": named_bones,
		"desired_hand": _frame_values(desired.frame), "actual_hand": _frame_values(actual_hand), "actual_forearm": _frame_values(actual_forearm),
		"twist_axis_world": _vector_values(twist_axis), "index_pinky_axis_hand_local": _vector_values(local_contact_axis),
		"locked_index_pinky_axis_world": _vector_values(locked_axis), "neutral_basis": _basis_values(neutral),
		"basis_stages": {"desired": _describe_basis(rig, desired_basis, neutral, twist_axis, desired_basis, actual_hand.basis),
			"pure_twist_clamp": _describe_basis(rig, pure_clamp, neutral, twist_axis, desired_basis, actual_hand.basis),
			"locked_axis_reconstruction": _describe_basis(rig, reconstruction, neutral, twist_axis, desired_basis, actual_hand.basis),
			"current_function": _describe_basis(rig, current_output, neutral, twist_axis, desired_basis, actual_hand.basis),
			"actual": _describe_basis(rig, actual_hand.basis, neutral, twist_axis, desired_basis, actual_hand.basis)},
		"twist_bone_ancestry": twists, "restoration": {"position_error_m": position_error, "basis_component_error": component_error,
			"position_guard_m": RESTORE_POSITION_GUARD_M, "basis_component_guard": RESTORE_BASIS_COMPONENT_GUARD,
			"source_json_print_precision_guard_m": JSON_PRINT_POSITION_GUARD_M},
		"allocation_policy_from_requested_twist": {
			"forearm_chain_degrees": rad_to_deg(clampf(requested_angle * RigScript.AUTHORING_LIMB_TWIST_FOREARM_SHARE, -RigScript.AUTHORING_LIMB_TWIST_LIMIT_RADIANS, RigScript.AUTHORING_LIMB_TWIST_LIMIT_RADIANS)),
			"upperarm_chain_degrees": rad_to_deg(clampf(requested_angle * RigScript.AUTHORING_LIMB_TWIST_UPPERARM_SHARE, -RigScript.AUTHORING_LIMB_TWIST_LIMIT_RADIANS, RigScript.AUTHORING_LIMB_TWIST_LIMIT_RADIANS)),
			"chain_limit_degrees": rad_to_deg(RigScript.AUTHORING_LIMB_TWIST_LIMIT_RADIANS),
			"original_runtime_allocation_metadata_recorded": false},
		"interpretation": "Stage outputs are diagnostic observations, not a new wrist range or contact acceptance."}
	_result["position_operator_trace"] = _trace_position_operator(rig, skeleton, slot, desired.frame, saved_realization)
	_check(var_to_bytes(capture) == before_bytes, "source capture remains immutable")
	_check(FileAccess.get_sha256(report_path) == report_hash and FileAccess.get_sha256(capture_path) == capture_hash, "source files remain unchanged")
	rig.queue_free()
	_finish()

func _trace_position_operator(rig: Node3D, skeleton: Skeleton3D, slot: StringName, desired: Transform3D, saved: Dictionary) -> Dictionary:
	var hand: StringName = RigScript.LEFT_HAND_BONE if slot == &"hand_left" else RigScript.RIGHT_HAND_BONE
	var forearm: StringName = RigScript.LEFT_FOREARM_BONE if slot == &"hand_left" else RigScript.RIGHT_FOREARM_BONE
	var upperarm: StringName = RigScript.LEFT_UPPERARM_BONE if slot == &"hand_left" else RigScript.RIGHT_UPPERARM_BONE
	var clavicle: StringName = RigScript.LEFT_CLAVICLE_BONE if slot == &"hand_left" else RigScript.RIGHT_CLAVICLE_BONE
	var saved_constraints: Dictionary = saved.get("arm_constraints", {})
	# This capture recorded no manual roll. An active roll additionally requires
	# its original actor/body reference, which is not part of this saved packet.
	if not _check(not saved_constraints.get("manual_upperarm_roll_active", false) and is_zero_approx(float(saved_constraints.get("manual_upperarm_roll_degrees", INF))), "saved position trace has recorded inactive manual upper-arm roll"):
		return {"valid": false, "reason": "manual_roll_reference_not_captured"}
	rig.set("upper_body_authoring_state", {})
	var dimensions: Array = []
	for index: int in skeleton.get_bone_count():
		dimensions.append({"position": skeleton.get_bone_pose_position(index), "scale": skeleton.get_bone_pose_scale(index)})
	var reachable: Dictionary = rig.call("_resolve_usable_arm_target_world", slot, desired.origin)
	var target: Vector3 = reachable.get("target_world", desired.origin)
	var stages: Array = [_position_stage(rig, skeleton, hand, upperarm, forearm, desired, target, "initial")]
	rig.call("_apply_ccd_arm_reach_pose", upperarm, forearm, hand, target,
		RigScript.AUTHORING_GRIP_RELATIONSHIP_PRECISE_SOLVE_ITERATIONS,
		RigScript.AUTHORING_DIRECT_ARM_FOREARM_WEIGHT,
		RigScript.AUTHORING_DIRECT_ARM_UPPERARM_WEIGHT,
		clavicle, RigScript.AUTHORING_DIRECT_ARM_CLAVICLE_WEIGHT,
		RigScript.AUTHORING_GRIP_RELATIONSHIP_ALIGNMENT_EPSILON_METERS)
	stages.append(_position_stage(rig, skeleton, hand, upperarm, forearm, desired, target, "after_existing_24_iteration_ccd"))
	rig.call("_apply_authoring_manual_upperarm_roll_pose", slot, upperarm, forearm, hand)
	stages.append(_position_stage(rig, skeleton, hand, upperarm, forearm, desired, target, "after_existing_manual_upperarm_roll"))
	rig.call("_enforce_authoring_upperarm_swing_authority", slot, clavicle, upperarm, forearm, hand)
	stages.append(_position_stage(rig, skeleton, hand, upperarm, forearm, desired, target, "after_existing_upperarm_swing_authority"))
	rig.call("_enforce_authoring_elbow_max_angle", upperarm, forearm, hand)
	stages.append(_position_stage(rig, skeleton, hand, upperarm, forearm, desired, target, "after_existing_elbow_cap"))
	var unchanged := true
	for index: int in skeleton.get_bone_count():
		unchanged = unchanged and skeleton.get_bone_pose_position(index) == dimensions[index].position and skeleton.get_bone_pose_scale(index) == dimensions[index].scale
	_check(unchanged, "isolated one-pass position trace preserves every local bone position and scale")
	return {"valid": true, "stages": stages, "passes": 1, "search_performed": false,
		"final_ccd_rotation_observations": _ccd_rotation_observations(skeleton, hand, target, [
			{"bone": forearm, "weight": RigScript.AUTHORING_DIRECT_ARM_FOREARM_WEIGHT},
			{"bone": upperarm, "weight": RigScript.AUTHORING_DIRECT_ARM_UPPERARM_WEIGHT},
			{"bone": clavicle, "weight": RigScript.AUTHORING_DIRECT_ARM_CLAVICLE_WEIGHT}]),
		"ccd_iteration_budget": RigScript.AUTHORING_GRIP_RELATIONSHIP_PRECISE_SOLVE_ITERATIONS,
		"ccd_stop_epsilon_m": RigScript.AUTHORING_GRIP_RELATIONSHIP_ALIGNMENT_EPSILON_METERS,
		"configured_elbow_max_degrees": rig.get("authoring_elbow_max_plane_angle_degrees"),
		"requested_target_world": _vector_values(desired.origin), "reachable_target_world": _vector_values(target),
		"target_position_origin_id": ROOT, "machine_to_world": _result.machine_to_world,
		"reach_projection": reachable, "local_bone_dimensions_preserved": unchanged,
		"isolated_diagnostic_rotations_written": true, "production_pose_written": false,
		"wrist_basis_step_executed": false, "limits_changed": false}

func _ccd_rotation_observations(skeleton: Skeleton3D, hand: StringName, target_world: Vector3, joints: Array) -> Dictionary:
	var target_local := skeleton.to_local(target_world)
	var end_pose := skeleton.get_bone_global_pose(skeleton.find_bone(hand))
	var samples: Array = []
	for joint: Dictionary in joints:
		var pose := skeleton.get_bone_global_pose(skeleton.find_bone(joint.bone))
		var current := end_pose.origin - pose.origin
		var target := target_local - pose.origin
		var from := current.normalized()
		var to := target.normalized()
		var dot_value := from.dot(to)
		var cross_value := from.cross(to)
		var geometric_angle := atan2(cross_value.length(), clampf(dot_value, -1.0, 1.0))
		var constructed := Quaternion(from, to).normalized()
		var weighted := Quaternion.IDENTITY.slerp(constructed, clampf(float(joint.weight), 0.0, 1.0)).normalized()
		samples.append({"bone": joint.bone, "weight": joint.weight,
			"current_end_vector": _vector_values(current), "target_end_vector": _vector_values(target),
			"normalized_current": _vector_values(from), "normalized_target": _vector_values(to),
			"dot": dot_value, "cross": _vector_values(cross_value), "cross_length": cross_value.length(),
			"current_length": current.length(), "target_length": target.length(),
			"atan2_angle_rad": geometric_angle, "expected_weighted_atan2_angle_rad": geometric_angle * float(joint.weight),
			"constructor_quaternion": [constructed.x, constructed.y, constructed.z, constructed.w],
			"constructor_angle_rad": 2.0 * atan2(Vector3(constructed.x, constructed.y, constructed.z).length(), absf(constructed.w)),
			"weighted_quaternion": [weighted.x, weighted.y, weighted.z, weighted.w],
			"weighted_angle_rad": 2.0 * atan2(Vector3(weighted.x, weighted.y, weighted.z).length(), absf(weighted.w)),
			"dot_above_godot47_almost_one": dot_value > 0.99999975})
	var machine: Transform3D = skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone(ROOT))
	return {"samples": samples, "pose_written": false,
		"vector_origin_id": &"WristConstraintDiagnosticSkeletonOrigin",
		"origin_record": {"origin_id": &"WristConstraintDiagnosticSkeletonOrigin", "parent_origin_id": ROOT,
			"transform_to_parent": _frame_values(machine.affine_inverse() * skeleton.global_transform),
			"owner_system": &"live_grip_wrist_constraint_diagnostic", "resolve_phase": &"editor_preview", "space_type": &"presentation"},
		"threshold_reference": "https://github.com/godotengine/godot/blob/4.7/core/math/quaternion.h",
		"godot47_almost_one": 0.99999975}

func _position_stage(rig: Node3D, skeleton: Skeleton3D, hand: StringName, upperarm: StringName, forearm: StringName, desired: Transform3D, target: Vector3, label: String) -> Dictionary:
	skeleton.force_update_all_bone_transforms()
	var actual: Transform3D = skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone(hand))
	var elbow: Vector3 = rig.call("_get_bone_world_position", forearm)
	var shoulder: Vector3 = rig.call("_get_bone_world_position", upperarm)
	var to_shoulder := shoulder - elbow
	var to_hand := actual.origin - elbow
	var elbow_angle := rad_to_deg(to_shoulder.angle_to(to_hand)) if to_shoulder.length_squared() > 0.000000001 and to_hand.length_squared() > 0.000000001 else INF
	return {"stage": label, "hand_world": _frame_values(actual), "elbow_world": _vector_values(elbow),
		"shoulder_world": _vector_values(shoulder), "position_error_m": actual.origin.distance_to(desired.origin),
		"projected_target_error_m": actual.origin.distance_to(target), "basis_error_degrees": _basis_angle(actual.basis, desired.basis),
		"elbow_angle_degrees": elbow_angle}

func _describe_basis(rig: Node, basis: Basis, neutral: Basis, axis: Vector3, desired: Basis, actual: Basis) -> Dictionary:
	var normalized := basis.orthonormalized()
	var delta := (normalized.get_rotation_quaternion().normalized() * neutral.get_rotation_quaternion().normalized().inverse()).normalized()
	var twist: Quaternion = rig.call("_extract_quaternion_twist", delta, axis)
	var angle: float = rig.call("_resolve_signed_twist_angle", twist, axis)
	return {"basis_columns": _basis_values(normalized), "twist_degrees": rad_to_deg(angle),
		"desired_error_degrees": _basis_angle(normalized, desired), "actual_error_degrees": _basis_angle(normalized, actual)}

func _parse_report_frame(value: Variant) -> Dictionary:
	if not value is String or not value.begins_with("[X: (") or not value.contains(", Y: (") or not value.contains(", Z: (") or not value.contains(", O: (") or not value.ends_with(")]"):
		return {"valid": false}
	var pattern := RegEx.new()
	pattern.compile("[-+]?(?:[0-9]+(?:\\.[0-9]*)?|\\.[0-9]+)(?:[eE][-+]?[0-9]+)?")
	var numbers := pattern.search_all(value)
	if numbers.size() != 12: return {"valid": false}
	var points: Array[Vector3] = []
	for offset: int in [0, 3, 6, 9]:
		points.append(Vector3(float(numbers[offset].get_string()), float(numbers[offset + 1].get_string()), float(numbers[offset + 2].get_string())))
	var frame := Transform3D(Basis(points[0], points[1], points[2]), points[3])
	return {"valid": frame.is_finite() and frame.basis.determinant() > 0.000000001, "frame": frame}

func _workspace_artifact(path: String) -> bool:
	return path.to_lower().begins_with("c:/workspace/test_artifacts/")

func _depth(skeleton: Skeleton3D, index: int) -> int:
	var depth := 0
	while index >= 0:
		depth += 1
		index = skeleton.get_bone_parent(index)
	return depth

func _ancestor(skeleton: Skeleton3D, ancestor: int, index: int) -> bool:
	if ancestor < 0: return false
	while index >= 0:
		if ancestor == index: return true
		index = skeleton.get_bone_parent(index)
	return false

func _basis_angle(a: Basis, b: Basis) -> float:
	return rad_to_deg(a.orthonormalized().get_rotation_quaternion().normalized().angle_to(b.orthonormalized().get_rotation_quaternion().normalized()))

func _basis_components_error(a: Basis, b: Basis) -> float:
	return maxf((a.x - b.x).length(), maxf((a.y - b.y).length(), (a.z - b.z).length()))

func _vector_values(value: Vector3) -> Array: return [value.x, value.y, value.z]
func _basis_values(value: Basis) -> Array: return [_vector_values(value.x), _vector_values(value.y), _vector_values(value.z)]
func _frame_values(value: Transform3D) -> Dictionary: return {"basis_columns": _basis_values(value.basis), "origin": _vector_values(value.origin)}

func _finish() -> void:
	var report := {"schema": "live_grip_wrist_constraint_diagnostic_v1", "ok": _failures.is_empty(), "checks": _checks,
		"failures": _failures, "measurements": _result, "search_performed": false, "production_pose_written": false,
		"isolated_rig_restored_from_capture": true, "limits_changed": false, "grip_accepted": false}
	var path := "C:/WORKSPACE/test_artifacts/live_grip_wrist_constraint_" + Time.get_datetime_string_from_system().replace(":", "-") + ".json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t")); file.close()
	print("WRIST_CONSTRAINT_RESULT=" + path + " ok=" + str(report.ok))
	quit(0 if report.ok else 1)
