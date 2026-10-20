extends SceneTree

## Isolated helper-branch observation. This is not a grip/skin acceptance test.
## No saved weapon or player library is opened or changed.
## Run with -- --out=C:/WORKSPACE/godot_runs/<run>/twist_branch.json
## Add --candidate=true for isolated pose-derived branch/zero-reset exploration.

const RigScene = preload("res://scenes/player/player_humanoid_rig.tscn")

var output_path := "C:/WORKSPACE/godot_runs/authoring_twist_branch.json"
var candidate_enabled := false


func _init() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			output_path = argument.trim_prefix("--out=")
		elif argument == "--candidate=true":
			candidate_enabled = true
	call_deferred("_run")


func _run() -> void:
	var rig: PlayerHumanoidRig = RigScene.instantiate() as PlayerHumanoidRig
	root.add_child(rig)
	await process_frame
	await process_frame
	rig.set_authoring_preview_mode_enabled(true)
	rig.set_process(false)
	var skeleton: Skeleton3D = rig.get_node("JosieModel/Josie/Skeleton3D") as Skeleton3D
	var cases: Array[Dictionary] = []
	for side: String in ["R", "L"]:
		cases.append(_exercise(rig, skeleton, side, "positive_branch", [170.0, 179.0, 181.0, 190.0, 179.0, 0.0]))
		cases.append(_exercise(rig, skeleton, side, "negative_branch", [-170.0, -179.0, -181.0, -190.0, -179.0, 0.0]))
		cases.append(_exercise(rig, skeleton, side, "positive_zero_return", [45.0, 0.0, 0.0]))
		cases.append(_exercise(rig, skeleton, side, "negative_zero_return", [-45.0, 0.0, 0.0]))
		cases.append(_exercise(rig, skeleton, side, "quaternion_sign_equivalence", [179.0, 179.0, 181.0, 181.0], [1.0, -1.0, 1.0, -1.0]))
	var result := {
		"scope": "Isolated actual-rig twist distribution; empirical measurements only, no anatomical/skin/grip certification.",
		"candidate_enabled": candidate_enabled,
		"candidate_scope": "Optional diagnostic-only pose-derived equivalent branch, existing shares/limits/writers, explicit zero reset. No production policy changed. Saturated references, long winding, arbitrary imported helper poses and seek policy remain outside validation.",
		"sequence_policy": "Each case resets the preview baseline. Samples within a case preserve helper history. Desired basis uses the current neutral hand basis and forearm-hand axis.",
		"nearest_equivalent_policy": "Diagnostic-only unwrapping relative to the previous row; never supplied to production or used to alter bone poses.",
		"quaternion_distance_policy": "Shortest orientation distance, invariant under quaternion sign.",
		"engine_version": Engine.get_version_info(),
		"wrist_cap_degrees_unchanged": rig.authoring_contact_wrist_twist_limit_degrees,
		"straightness_bias_unchanged": rig.authoring_contact_wrist_straightness_bias,
		"cases": cases,
	}
	DirAccess.make_dir_recursive_absolute(output_path.get_base_dir())
	var file := FileAccess.open(output_path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write twist-branch observations: " + output_path)
		quit(1)
		return
	file.store_string(JSON.stringify(result, "\t"))
	file.close()
	print("AUTHORING_TWIST_BRANCH_REPORT=" + output_path)
	# Successful capture is not an assertion that observed production behavior passes.
	quit(0)


func _exercise(
	rig: PlayerHumanoidRig,
	skeleton: Skeleton3D,
	side: String,
	case_name: String,
	input_degrees: Array,
	quaternion_signs: Array = []
) -> Dictionary:
	rig.reset_authoring_preview_baseline_pose()
	var slot: StringName = &"hand_right" if side == "R" else &"hand_left"
	var hand := StringName("CC_Base_%s_Hand" % side)
	var forearm := StringName("CC_Base_%s_Forearm" % side)
	var hand_index := skeleton.find_bone(hand)
	var helper_names: Array[StringName] = [
		StringName("CC_Base_%s_ForearmTwist01" % side),
		StringName("CC_Base_%s_ForearmTwist02" % side),
		StringName("CC_Base_%s_UpperarmTwist01" % side),
		StringName("CC_Base_%s_UpperarmTwist02" % side),
	]
	var baseline: Dictionary = _capture_helper_rotations(skeleton, helper_names)
	var previous_helpers: Dictionary = baseline.duplicate()
	var initial_hand_position := _world_position(skeleton, hand)
	var initial_elbow_position := _world_position(skeleton, forearm)
	var previous_desired := Quaternion.IDENTITY
	var previous_request := 0.0
	var previous_nearest := 0.0
	var rows: Array[Dictionary] = []
	for index: int in range(input_degrees.size()):
		var requested_degrees := float(input_degrees[index])
		var neutral_basis: Basis = rig.call("_resolve_neutral_hand_world_basis", hand_index)
		var axis_world := (_world_position(skeleton, hand) - _world_position(skeleton, forearm)).normalized()
		var delta := Quaternion(axis_world, deg_to_rad(requested_degrees)).normalized()
		var input_sign := float(quaternion_signs[index]) if index < quaternion_signs.size() else 1.0
		var signed_delta := Quaternion(delta.x * input_sign, delta.y * input_sign, delta.z * input_sign, delta.w * input_sign)
		var source_desired := (signed_delta * neutral_basis.get_rotation_quaternion().normalized()).normalized()
		var desired_basis := Basis(source_desired).orthonormalized()
		var desired_rotation := desired_basis.get_rotation_quaternion().normalized()
		var production_twist: Quaternion = rig.call("_extract_quaternion_twist", signed_delta, axis_world)
		var direct_short_degrees := rad_to_deg(float(rig.call("_resolve_signed_twist_angle", production_twist, axis_world)))
		var measured_short_degrees := rad_to_deg(float(rig.call("_resolve_authoring_contact_wrist_twist_angle", hand, forearm, desired_basis)))
		var nearest_equivalent := measured_short_degrees
		if index > 0:
			nearest_equivalent = previous_nearest + wrapf(measured_short_degrees - previous_nearest, -180.0, 180.0)
		var candidate: Dictionary = {"enabled": false}
		if candidate_enabled:
			candidate = _apply_candidate_distribution(rig, skeleton, slot, measured_short_degrees)
		else:
			rig.call("_apply_authoring_limb_twist_distribution_for_slot", slot, forearm, hand, desired_basis, 1.0)
		skeleton.force_update_all_bone_transforms()
		var current_helpers := _capture_helper_rotations(skeleton, helper_names)
		var helpers: Dictionary = {}
		for helper: StringName in helper_names:
			var current: Quaternion = current_helpers[helper]
			var neutral: Quaternion = baseline[helper]
			var previous: Quaternion = previous_helpers[helper]
			var relative := (neutral.inverse() * current).normalized()
			var helper_index := skeleton.find_bone(helper)
			var parent_index := skeleton.get_bone_parent(helper_index)
			helpers[String(helper)] = {
				"parent": skeleton.get_bone_name(parent_index) if parent_index >= 0 else "",
				"local_quaternion": _quaternion_array(current),
				"neutral_relative_quaternion": _quaternion_array(relative),
				"neutral_relative_y_twist_degrees": rad_to_deg(float(rig.call("_resolve_signed_twist_angle", rig.call("_extract_quaternion_twist", relative, Vector3.UP), Vector3.UP))),
				"delta_from_baseline_degrees": _rotation_distance_degrees(neutral, current),
				"step_degrees": _rotation_distance_degrees(previous, current),
			}
		var distribution: Dictionary = rig.authoring_limb_twist_distribution_state.get(slot, {}).duplicate(true)
		rows.append({
			"index": index,
			"source_requested_degrees": requested_degrees,
			"input_quaternion_sign": input_sign,
			"source_delta_quaternion": _quaternion_array(signed_delta),
			"desired_hand_world_quaternion": _quaternion_array(desired_rotation),
			"neutral_hand_world_quaternion": _quaternion_array(neutral_basis.get_rotation_quaternion().normalized()),
			"forearm_axis_world": _vector_array(axis_world),
			"direct_short_request_degrees": direct_short_degrees,
			"production_short_request_degrees": measured_short_degrees,
			"short_request_scalar_step_degrees": measured_short_degrees - previous_request if index > 0 else null,
			"diagnostic_nearest_equivalent_degrees": nearest_equivalent,
			"desired_orientation_step_degrees": _rotation_distance_degrees(previous_desired, desired_rotation) if index > 0 else null,
			"distribution_state": distribution,
			"candidate": candidate,
			"helpers": helpers,
			"hand_position_drift_meters": _world_position(skeleton, hand).distance_to(initial_hand_position),
			"elbow_position_drift_meters": _world_position(skeleton, forearm).distance_to(initial_elbow_position),
		})
		previous_helpers = current_helpers
		previous_desired = desired_rotation
		previous_request = measured_short_degrees
		previous_nearest = nearest_equivalent
	return {"side": side, "case": case_name, "samples": rows}


func _apply_candidate_distribution(rig: PlayerHumanoidRig, skeleton: Skeleton3D, slot: StringName, short_degrees: float) -> Dictionary:
	var forearm_bones: Array = rig.call("_get_slot_forearm_twist_bones", slot)
	var upperarm_bones: Array = rig.call("_get_slot_upperarm_twist_bones", slot)
	var forearm_count := int(rig.call("_count_existing_bones", forearm_bones))
	var upperarm_count := int(rig.call("_count_existing_bones", upperarm_bones))
	var forearm_share: float = PlayerHumanoidRig.AUTHORING_LIMB_TWIST_FOREARM_SHARE
	var upperarm_share: float = PlayerHumanoidRig.AUTHORING_LIMB_TWIST_UPPERARM_SHARE
	if forearm_count <= 0:
		forearm_share = 0.0
		upperarm_share = 1.0
	elif upperarm_count <= 0:
		forearm_share = 1.0
		upperarm_share = 0.0
	var upper_reference := _infer_unsaturated_request(rig, skeleton, upperarm_bones, upperarm_share, "upperarm")
	var forearm_reference := _infer_unsaturated_request(rig, skeleton, forearm_bones, forearm_share, "forearm")
	var reference: Dictionary = upper_reference if upper_reference.get("valid", false) else forearm_reference
	var inferred := float(reference.get("inferred_request_degrees", 0.0))
	var choices: Array[float] = [short_degrees, short_degrees - 360.0, short_degrees + 360.0]
	var chosen := short_degrees
	var is_zero := absf(deg_to_rad(short_degrees)) <= 0.0001
	var confidence := "no_unsaturated_chain_principal_fallback"
	if is_zero:
		chosen = 0.0
		confidence = "canonical_zero_override"
	elif reference.get("valid", false):
		confidence = "unsaturated_pose_reference"
		var best_distance := absf(chosen - inferred)
		for choice: float in choices:
			var distance := absf(choice - inferred)
			# Principal angle wins exact ties. No stored previous-request scalar.
			if distance < best_distance - 0.000001:
				best_distance = distance
				chosen = choice
	var chosen_radians := deg_to_rad(chosen)
	var limit: float = PlayerHumanoidRig.AUTHORING_LIMB_TWIST_LIMIT_RADIANS
	var forearm_total := clampf(chosen_radians * forearm_share, -limit, limit)
	var upperarm_total := clampf(chosen_radians * upperarm_share, -limit, limit)
	var applied_count := 0
	# Existing production bone writers also accept zero; calling them restores
	# neutral instead of retaining a previous request's helper deformation.
	if forearm_count > 0:
		applied_count += int(rig.call("_apply_authoring_twist_bone_chain", forearm_bones, forearm_total, 1.0))
	if upperarm_count > 0:
		applied_count += int(rig.call("_apply_authoring_twist_bone_chain", upperarm_bones, upperarm_total, 1.0))
	rig.call("_record_authoring_limb_twist_state", slot, not is_zero and applied_count > 0, chosen_radians, forearm_total, upperarm_total, applied_count)
	return {
		"enabled": true,
		"chosen_request_degrees": chosen,
		"equivalent_choices_degrees": choices,
		"reference_confidence": confidence,
		"reference": reference,
		"upperarm_reference": upper_reference,
		"forearm_reference": forearm_reference,
		"principal_fallback_used": not is_zero and not reference.get("valid", false),
		"zero_reset_written": is_zero,
		"applied_helper_count": applied_count,
	}


func _infer_unsaturated_request(rig: PlayerHumanoidRig, skeleton: Skeleton3D, bone_names: Array, share: float, chain_name: String) -> Dictionary:
	var count := int(rig.call("_count_existing_bones", bone_names))
	if count <= 0 or share <= 0.000001:
		return {"valid": false, "chain": chain_name, "reason": "missing_chain_or_zero_share"}
	var per_bone_limit: float = PlayerHumanoidRig.AUTHORING_LIMB_TWIST_LIMIT_RADIANS / float(count)
	var saturation_margin := deg_to_rad(PlayerHumanoidRig.AUTHORING_JOINT_RANGE_EPSILON_DEGREES)
	var total_twist := 0.0
	var observed: Dictionary = {}
	for bone_variant: Variant in bone_names:
		var bone := StringName(bone_variant)
		var index := skeleton.find_bone(bone)
		if index < 0:
			continue
		if not rig.authoring_limb_twist_neutral_rotation_lookup.has(bone):
			return {"valid": false, "chain": chain_name, "reason": "missing_cached_neutral", "bone": String(bone)}
		var neutral: Quaternion = rig.authoring_limb_twist_neutral_rotation_lookup[bone]
		var relative := (neutral.normalized().inverse() * skeleton.get_bone_pose_rotation(index).normalized()).normalized()
		var axis: Vector3 = PlayerHumanoidRig.AUTHORING_LIMB_TWIST_LOCAL_AXIS
		var twist_rotation: Quaternion = rig.call("_extract_quaternion_twist", relative, axis)
		var twist := float(rig.call("_resolve_signed_twist_angle", twist_rotation, axis))
		observed[String(bone)] = rad_to_deg(twist)
		if absf(twist) >= per_bone_limit - saturation_margin:
			return {"valid": false, "chain": chain_name, "reason": "saturated_chain_cannot_recover_request", "observed_helper_degrees": observed}
		total_twist += twist
	return {
		"valid": true,
		"chain": chain_name,
		"reason": "unsaturated_chain_inverse_share",
		"inferred_request_degrees": rad_to_deg(total_twist / share),
		"observed_helper_degrees": observed,
		"share": share,
		"existing_helper_count": count,
	}


func _capture_helper_rotations(skeleton: Skeleton3D, helper_names: Array[StringName]) -> Dictionary:
	var result: Dictionary = {}
	for helper: StringName in helper_names:
		result[helper] = skeleton.get_bone_pose_rotation(skeleton.find_bone(helper)).normalized()
	return result


func _world_position(skeleton: Skeleton3D, bone: StringName) -> Vector3:
	return skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone(bone)).origin


func _rotation_distance_degrees(first: Quaternion, second: Quaternion) -> float:
	var relative := (first.normalized().inverse() * second.normalized()).normalized()
	return rad_to_deg(2.0 * atan2(Vector3(relative.x, relative.y, relative.z).length(), absf(relative.w)))


func _quaternion_array(value: Quaternion) -> Array[float]:
	return [value.x, value.y, value.z, value.w]


func _vector_array(value: Vector3) -> Array[float]:
	return [value.x, value.y, value.z]
