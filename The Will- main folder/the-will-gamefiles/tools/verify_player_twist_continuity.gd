extends SceneTree

## Actual production helper distribution, not the optional diagnostic candidate.
## No saved item is opened. This does not certify full-arm anatomy or skin.
const RigScene = preload("res://scenes/player/player_humanoid_rig.tscn")
const ANGLE_EPSILON_DEGREES := 0.01

var output_path := "C:/WORKSPACE/godot_runs/verify_player_twist_continuity.json"
var checks: Array[Dictionary] = []


func _init() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			output_path = argument.trim_prefix("--out=")
	call_deferred("_run")


func _run() -> void:
	var rig: PlayerHumanoidRig = RigScene.instantiate() as PlayerHumanoidRig
	root.add_child(rig)
	await process_frame
	await process_frame
	rig.set_authoring_preview_mode_enabled(true)
	rig.set_process(false)
	for side: String in ["R", "L"]:
		_exercise_sequences(rig, side)
		_exercise_partial_and_restore(rig, side)
		_exercise_unusable_references(rig, side)
		_exercise_missing_helpers(rig, side)
	var passed := true
	for check: Dictionary in checks:
		passed = passed and bool(check["passed"])
	DirAccess.make_dir_recursive_absolute(output_path.get_base_dir())
	var file := FileAccess.open(output_path, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write twist continuity verifier result")
		quit(1)
		return
	file.store_string(JSON.stringify({
		"passed": passed, "checks": checks,
		"scope": "Production twist helpers: branch continuity, neutral/partial writes, equivalent quaternions, posed restore, cold reset, absent helpers and conservative invalid-reference fallback. No full-arm skin, grip or gameplay certification.",
	}, "\t"))
	file.close()
	print("PLAYER_TWIST_CONTINUITY passed=%s checks=%d output=%s" % [str(passed), checks.size(), output_path])
	quit(0 if passed else 1)


func _exercise_sequences(rig: PlayerHumanoidRig, side: String) -> void:
	for direction: float in [1.0, -1.0]:
		rig.reset_authoring_preview_baseline_pose()
		var original_hand := _position(rig.skeleton, "CC_Base_%s_Hand" % side)
		var previous: Dictionary = {}
		for angle: float in [170.0, 179.0, 181.0, 190.0, 179.0, 0.0]:
			var label := "%s_sweep_%.0f_%.0f" % [side, direction, angle]
			var state := _apply(rig, side, angle * direction)
			_expect(rig, side, clampf(angle * direction * 0.78, -90.0, 90.0) / 2.0, angle * direction * 0.22 / 2.0, label)
			_check(absf(float(state.get("resolved_degrees", INF)) - angle * direction) < ANGLE_EPSILON_DEGREES, label + "_equivalent_branch")
			if angle == 181.0:
				_check(_max_step(rig, side, previous) < 0.3, label + "_no_wrap_jump")
			_check(_position(rig.skeleton, "CC_Base_%s_Hand" % side).distance_to(original_hand) < 0.000001, label + "_hand_position_preserved")
			previous = _capture_helpers(rig, side)
		_apply(rig, side, 45.0 * direction)
		_expect(rig, side, 17.55 * direction, 4.95 * direction, side + "_45_share")
		_apply(rig, side, 0.0)
		_expect(rig, side, 0.0, 0.0, side + "_zero_neutral")
		_apply(rig, side, 0.0)
		_expect(rig, side, 0.0, 0.0, side + "_repeat_zero_neutral")
	rig.reset_authoring_preview_baseline_pose()
	_apply(rig, side, 179.0)
	var before := _capture_helpers(rig, side)
	_apply(rig, side, 179.0, 1.0, -1.0)
	_check(_max_step(rig, side, before) < ANGLE_EPSILON_DEGREES, side + "_quaternion_sign_equivalent_179")
	_apply(rig, side, 181.0)
	before = _capture_helpers(rig, side)
	_apply(rig, side, 181.0, 1.0, -1.0)
	_check(_max_step(rig, side, before) < ANGLE_EPSILON_DEGREES, side + "_quaternion_sign_equivalent_181")


func _exercise_partial_and_restore(rig: PlayerHumanoidRig, side: String) -> void:
	rig.reset_authoring_preview_baseline_pose()
	_apply(rig, side, 45.0)
	_apply(rig, side, 0.0, 0.5)
	_expect(rig, side, 8.775, 2.475, side + "_half_neutral")
	var before := _capture_helpers(rig, side)
	_apply(rig, side, 0.0, 0.0)
	_check(_max_step(rig, side, before) < ANGLE_EPSILON_DEGREES, side + "_zero_strength_preserves_pose")
	_apply(rig, side, 0.0)
	_expect(rig, side, 0.0, 0.0, side + "_full_neutral_after_partial")
	_apply(rig, side, 179.0)
	_apply(rig, side, 181.0, 0.25)
	_expect(rig, side, 45.0, 19.745, side + "_partial_crossing")
	_apply(rig, side, 181.0, 0.25)
	_expect(rig, side, 45.0, 19.78625, side + "_partial_crossing_repeat")
	_apply(rig, side, 179.0)
	var saved := rig.capture_runtime_upper_body_pose_frame()
	_apply(rig, side, 181.0)
	var expected_after_restore := _capture_helpers(rig, side)
	# Leave debug/last-result data from unrelated speculative calls, then restore
	# only the real pose packet. The next result must follow the restored bones.
	_apply(rig, side, 0.0)
	_apply(rig, side, -170.0)
	var restored := rig.apply_runtime_solved_upper_body_pose_frame(
		saved["bone_names"], Array(saved["pose_positions"]), Array(saved["pose_rotations"]), Array(saved["pose_scales"])
	)
	rig.clear_runtime_solved_replay_pose_frame()
	_check(restored, side + "_production_pose_restore")
	_apply(rig, side, 181.0)
	_check(_max_step(rig, side, expected_after_restore) < ANGLE_EPSILON_DEGREES, side + "_restore_ignores_speculative_requests")
	rig.reset_authoring_preview_baseline_pose()
	var cold_state := _apply(rig, side, 181.0)
	_check(absf(float(cold_state.get("resolved_degrees", INF)) + 179.0) < ANGLE_EPSILON_DEGREES, side + "_cold_seek_principal")
	var cold_pose := _capture_helpers(rig, side)
	_apply(rig, side, 100.0)
	_apply(rig, side, 190.0)
	rig.reset_authoring_preview_baseline_pose()
	_apply(rig, side, 181.0)
	_check(_max_step(rig, side, cold_pose) < ANGLE_EPSILON_DEGREES, side + "_reset_discards_previous_branch")


func _exercise_unusable_references(rig: PlayerHumanoidRig, side: String) -> void:
	rig.reset_authoring_preview_baseline_pose()
	var slot := _slot(side)
	var upper: Array = rig.call("_get_slot_upperarm_twist_bones", slot)
	var forearm: Array = rig.call("_get_slot_forearm_twist_bones", slot)
	rig.call("_apply_authoring_twist_bone_chain", upper, deg_to_rad(90.0), 1.0)
	rig.call("_apply_authoring_twist_bone_chain", forearm, deg_to_rad(90.0), 1.0)
	var saturated := _apply(rig, side, 181.0)
	_check(saturated.get("branch_status") == &"principal_no_pose_reference", side + "_both_saturated_explicit_fallback")
	_expect(rig, side, -45.0, -19.69, side + "_saturated_fallback_keeps_limits")
	_apply(rig, side, 0.0)
	_expect(rig, side, 0.0, 0.0, side + "_saturated_return_neutral")
	rig.reset_authoring_preview_baseline_pose()
	_apply(rig, side, 45.0)
	var first_upper := StringName(upper[0])
	var index := rig.skeleton.find_bone(first_upper)
	var neutral: Quaternion = rig.authoring_limb_twist_neutral_rotation_lookup[first_upper]
	rig.skeleton.set_bone_pose_rotation(index, neutral * Quaternion(Vector3.RIGHT, deg_to_rad(5.0)))
	var reference: Dictionary = rig.call("_infer_authoring_limb_twist_request", upper, 0.22)
	_check(not reference.get("valid", true) and reference.get("reason") == &"off_axis_helper_pose", side + "_off_axis_reference_rejected")
	var fallback := _apply(rig, side, 46.0)
	_check(fallback.get("branch_status") == &"forearm_unsaturated", side + "_valid_forearm_reference_fallback")
	_expect(rig, side, 17.94, 5.06, side + "_fallback_share_preserved")
	rig.skeleton.set_bone_pose_rotation(index, neutral * Quaternion(Vector3.UP, deg_to_rad(10.0)))
	reference = rig.call("_infer_authoring_limb_twist_request", upper, 0.22)
	_check(not reference.get("valid", true) and reference.get("reason") == &"inconsistent_helper_pose", side + "_unequal_helpers_not_inverted_into_request")
	var saved_neutral: Dictionary = rig.authoring_limb_twist_neutral_rotation_lookup.duplicate()
	rig.authoring_limb_twist_neutral_rotation_lookup.erase(first_upper)
	reference = rig.call("_infer_authoring_limb_twist_request", upper, 0.22)
	_check(not reference.get("valid", true) and reference.get("reason") == &"missing_neutral_pose", side + "_missing_neutral_not_inferred")
	rig.authoring_limb_twist_neutral_rotation_lookup = saved_neutral


func _exercise_missing_helpers(rig: PlayerHumanoidRig, side: String) -> void:
	var actual_skeleton := rig.skeleton
	var saved_neutral: Dictionary = rig.authoring_limb_twist_neutral_rotation_lookup.duplicate()
	for counts: Vector2i in [Vector2i(2, 0), Vector2i(0, 2), Vector2i(2, 1), Vector2i(0, 0)]:
		var skeleton := Skeleton3D.new()
		root.add_child(skeleton)
		_add_bone(skeleton, "CC_Base_%s_Forearm" % side, -1, Vector3.ZERO)
		_add_bone(skeleton, "CC_Base_%s_Hand" % side, 0, Vector3.UP)
		for segment: String in ["Forearm", "Upperarm"]:
			var count: int = counts.x if segment == "Forearm" else counts.y
			for helper_index: int in range(count):
				_add_bone(skeleton, "CC_Base_%s_%sTwist%02d" % [side, segment, helper_index + 1], 0, Vector3.ZERO)
		rig.skeleton = skeleton
		rig.authoring_limb_twist_neutral_rotation_lookup.clear()
		rig.call("_cache_authoring_limb_twist_neutral_pose")
		var label := "%s_helpers_%d_%d" % [side, counts.x, counts.y]
		var state := _apply(rig, side, 45.0)
		_check(int(state.get("applied_bone_count", -1)) == counts.x + counts.y, label + "_existing_count")
		var forearm_angle := 22.5 if counts.y == 0 else 17.55
		var upperarm_angle := 22.5 if counts.x == 0 else 9.9
		_expect(rig, side, forearm_angle, upperarm_angle, label + "_share_and_count")
		if counts == Vector2i(2, 1):
			_apply(rig, side, 179.0)
			_apply(rig, side, 181.0)
			_expect(rig, side, 45.0, 39.82, label + "_crossing_one_upper_helper")
		_apply(rig, side, 0.0)
		_expect(rig, side, 0.0, 0.0, label + "_zero")
		rig.skeleton = actual_skeleton
		skeleton.free()
	rig.authoring_limb_twist_neutral_rotation_lookup = saved_neutral


func _add_bone(skeleton: Skeleton3D, bone_name: String, parent: int, position: Vector3) -> void:
	skeleton.add_bone(bone_name)
	var index := skeleton.find_bone(bone_name)
	skeleton.set_bone_parent(index, parent)
	skeleton.set_bone_rest(index, Transform3D(Basis.IDENTITY, position))
	skeleton.set_bone_pose_position(index, position)
	skeleton.set_bone_pose_rotation(index, Quaternion.IDENTITY)
	skeleton.force_update_all_bone_transforms()


func _apply(rig: PlayerHumanoidRig, side: String, degrees: float, strength: float = 1.0, quaternion_sign: float = 1.0) -> Dictionary:
	var hand := StringName("CC_Base_%s_Hand" % side)
	var forearm := StringName("CC_Base_%s_Forearm" % side)
	var neutral: Basis = rig.call("_resolve_neutral_hand_world_basis", rig.skeleton.find_bone(hand))
	var axis := (_position(rig.skeleton, hand) - _position(rig.skeleton, forearm)).normalized()
	var desired := (Quaternion(axis, deg_to_rad(degrees)) * neutral.get_rotation_quaternion().normalized()).normalized()
	desired = Quaternion(desired.x * quaternion_sign, desired.y * quaternion_sign, desired.z * quaternion_sign, desired.w * quaternion_sign)
	rig.call("_apply_authoring_limb_twist_distribution_for_slot", _slot(side), forearm, hand, Basis(desired).orthonormalized(), strength)
	rig.skeleton.force_update_all_bone_transforms()
	return rig.authoring_limb_twist_distribution_state.get(_slot(side), {}).duplicate(true)


func _expect(rig: PlayerHumanoidRig, side: String, forearm_degrees: float, upperarm_degrees: float, label: String) -> void:
	for bone: StringName in _helper_names(rig, side):
		var angle := forearm_degrees if String(bone).contains("Forearm") else upperarm_degrees
		var neutral: Quaternion = rig.authoring_limb_twist_neutral_rotation_lookup[bone]
		var expected := (neutral * Quaternion(Vector3.UP, deg_to_rad(angle))).normalized()
		var actual := rig.skeleton.get_bone_pose_rotation(rig.skeleton.find_bone(bone)).normalized()
		var error := _angle(expected, actual)
		_check(error <= ANGLE_EPSILON_DEGREES, label + "_" + String(bone), {"expected_degrees": angle, "rotation_error_degrees": error})


func _helper_names(rig: PlayerHumanoidRig, side: String) -> Array[StringName]:
	var result: Array[StringName] = []
	for segment: String in ["Forearm", "Upperarm"]:
		for index: int in [1, 2]:
			var bone := StringName("CC_Base_%s_%sTwist%02d" % [side, segment, index])
			if rig.skeleton.find_bone(bone) >= 0:
				result.append(bone)
	return result


func _capture_helpers(rig: PlayerHumanoidRig, side: String) -> Dictionary:
	var result: Dictionary = {}
	for bone: StringName in _helper_names(rig, side):
		result[bone] = rig.skeleton.get_bone_pose_rotation(rig.skeleton.find_bone(bone)).normalized()
	return result


func _max_step(rig: PlayerHumanoidRig, side: String, previous: Dictionary) -> float:
	var maximum := 0.0
	for bone: StringName in _helper_names(rig, side):
		maximum = maxf(maximum, _angle(previous[bone], rig.skeleton.get_bone_pose_rotation(rig.skeleton.find_bone(bone))))
	return maximum


func _angle(first: Quaternion, second: Quaternion) -> float:
	var relative := (first.normalized().inverse() * second.normalized()).normalized()
	return rad_to_deg(2.0 * atan2(Vector3(relative.x, relative.y, relative.z).length(), absf(relative.w)))


func _position(skeleton: Skeleton3D, bone: StringName) -> Vector3:
	return skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone(bone)).origin


func _slot(side: String) -> StringName:
	return &"hand_right" if side == "R" else &"hand_left"


func _check(passed: bool, label: String, details: Dictionary = {}) -> void:
	checks.append({"passed": passed, "label": label, "details": details})
	if not passed:
		push_error("Twist continuity check failed: " + label)
