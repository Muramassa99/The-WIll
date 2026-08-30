extends SceneTree

const PlayerHumanoidRigScene: PackedScene = preload("res://scenes/player/player_humanoid_rig.tscn")
const PlayerDigitHingeRulesScript = preload("res://runtime/player/player_digit_hinge_rules.gd")
const PlayerRigFingerGripPresenterScript = preload("res://runtime/player/player_rig_finger_grip_presenter.gd")
const PlayerFingerSurfaceGripSolverScript = preload(
	"res://runtime/player/player_finger_surface_grip_solver.gd"
)
const CombatOriginRecordScript = preload("res://core/models/combat_origin_record.gd")

const RESULT_FILE_PATH := "C:/WORKSPACE/player_digit_hinge_debug_visuals_results.txt"
const DEBUG_ROOT_NAME := "AuthoringJointRangeDebugRoot"
const EXPECTED_DIGIT_BONE_COUNT: int = 30
const EXPECTED_EXISTING_NON_DIGIT_VISUAL_COUNT: int = 12
const ROTATION_EPSILON_RADIANS: float = 0.001
const DIRECTION_ALIGNMENT_MINIMUM: float = 0.9999
const DESCENDANT_MOVEMENT_EPSILON_METERS: float = 0.000001
const DEBUG_VISIBILITY_SENTINEL_OFFSET := Vector3(0.000731, -0.000419, 0.000283)
const DEBUG_TRANSFORM_EPSILON: float = 0.0000001

var failures: PackedStringArray = []

func _init() -> void:
	call_deferred("_run_verification")

func _run_verification() -> void:
	var rig: PlayerHumanoidRig = PlayerHumanoidRigScene.instantiate() as PlayerHumanoidRig
	root.add_child(rig)
	await process_frame
	await process_frame
	rig.set_process(false)
	rig.set_authoring_preview_mode_enabled(true, &"Idle")
	var skeleton: Skeleton3D = rig.get_node_or_null("JosieModel/Josie/Skeleton3D") as Skeleton3D
	_check(rig != null, "rig_missing")
	_check(skeleton != null, "skeleton_missing")
	if skeleton == null:
		_finish({})
		return

	var rules: Array[Dictionary] = PlayerDigitHingeRulesScript.get_all_rules()
	skeleton.force_update_all_bone_transforms()
	var before_right_hand: Transform3D = _get_bone_world_transform(skeleton, &"CC_Base_R_Hand")
	var before_left_hand: Transform3D = _get_bone_world_transform(skeleton, &"CC_Base_L_Hand")
	var before_rotations: Dictionary = _capture_bone_rotations(skeleton, rules)
	rig.set("show_authoring_joint_range_labels", true)
	rig.sync_authoring_joint_range_debug_now(true)
	var enabled_state: Dictionary = rig.get_authoring_joint_range_debug_state()
	var debug_root: Node3D = rig.get_node_or_null(DEBUG_ROOT_NAME) as Node3D
	var digit_states: Dictionary = enabled_state.get("digit_bones", {}) as Dictionary

	_check(rules.size() == EXPECTED_DIGIT_BONE_COUNT, "rule_count_not_30")
	_check(bool(enabled_state.get("visible", false)), "enabled_state_not_visible")
	_check(int(enabled_state.get("digit_visual_count", 0)) == EXPECTED_DIGIT_BONE_COUNT, "digit_visual_count_not_30")
	_check(digit_states.size() == EXPECTED_DIGIT_BONE_COUNT, "digit_state_count_not_30")
	_check(
		int(enabled_state.get("visual_count", 0)) >= EXPECTED_EXISTING_NON_DIGIT_VISUAL_COUNT + EXPECTED_DIGIT_BONE_COUNT,
		"aggregate_visual_count_below_42"
	)
	_check(debug_root != null, "debug_root_missing")
	_check(debug_root != null and debug_root.visible, "debug_root_not_visible")

	var right_count: int = 0
	var left_count: int = 0
	var right_finger_count: int = 0
	var right_thumb_count: int = 0
	var left_finger_count: int = 0
	var left_thumb_count: int = 0
	var seen_bones: Dictionary = {}
	var per_digit_sections: Dictionary = {}
	var digit_bone_root_chain_count: int = 0
	var digit_origin_pair_count: int = 0
	for rule: Dictionary in rules:
		var bone_name: StringName = rule.get("bone", StringName()) as StringName
		var slot_id: StringName = rule.get("slot_id", StringName()) as StringName
		var digit_id: StringName = rule.get("digit", StringName()) as StringName
		var section_index: int = int(rule.get("section", 0))
		var state: Dictionary = digit_states.get(String(bone_name), {}) as Dictionary
		_check(not seen_bones.has(bone_name), "duplicate_rule_%s" % String(bone_name))
		seen_bones[bone_name] = true
		_check(skeleton.find_bone(String(bone_name)) >= 0, "bone_missing_%s" % String(bone_name))
		_check(
			_bone_chain_reaches_root(
				skeleton,
				bone_name,
				CombatOriginRecordScript.ORIGIN_RL_BONE_ROOT
			),
			"bone_chain_does_not_reach_rl_bone_root_%s" % String(bone_name)
		)
		if _bone_chain_reaches_root(
			skeleton,
			bone_name,
			CombatOriginRecordScript.ORIGIN_RL_BONE_ROOT
		):
			digit_bone_root_chain_count += 1
		_check(not state.is_empty(), "state_missing_%s" % String(bone_name))
		_check(bool(state.get("visible", false)), "state_hidden_%s" % String(bone_name))
		_check(int(state.get("section", 0)) == section_index, "section_mismatch_%s" % String(bone_name))
		var expected_open_degrees: float = _expected_open_degrees(
			slot_id,
			digit_id,
			section_index
		)
		var expected_closed_degrees: float = _expected_closed_degrees(slot_id, digit_id, section_index)
		var is_bidirectional_thumb_root: bool = digit_id == &"thumb" and section_index == 1
		var expected_min_degrees: float = minf(expected_open_degrees, expected_closed_degrees)
		var expected_max_degrees: float = maxf(expected_open_degrees, expected_closed_degrees)
		_check(absf(float(state.get("open_angle_degrees", -999.0)) - expected_open_degrees) <= 0.0001, "open_angle_mismatch_%s" % String(bone_name))
		_check(absf(float(state.get("closed_angle_degrees", -999.0)) - expected_closed_degrees) <= 0.0001, "closed_angle_mismatch_%s" % String(bone_name))
		_check(absf(float(state.get("min_angle_degrees", -999.0)) - expected_min_degrees) <= 0.0001, "min_angle_mismatch_%s" % String(bone_name))
		_check(absf(float(state.get("max_angle_degrees", -999.0)) - expected_max_degrees) <= 0.0001, "max_angle_mismatch_%s" % String(bone_name))
		var expected_sweep_degrees: float = 100.0 if is_bidirectional_thumb_root else 90.0
		_check(
			absf(float(state.get("allowed_sweep_degrees", -999.0)) - expected_sweep_degrees) <= 0.0001,
			"sweep_mismatch_%s" % String(bone_name)
		)
		var hinge_axis_local: Vector3 = state.get("hinge_axis_local", Vector3.ZERO) as Vector3
		var hinge_axis_origin_id: StringName = state.get("hinge_axis_origin_id", StringName()) as StringName
		var zero_direction_local: Vector3 = state.get("zero_direction_local", Vector3.ZERO) as Vector3
		var zero_direction_origin_id: StringName = state.get("zero_direction_origin_id", StringName()) as StringName
		var neutral_rotation_origin_id: StringName = state.get("neutral_rotation_origin_id", StringName()) as StringName
		var bone_root_origin_id: StringName = state.get("bone_root_origin_id", StringName()) as StringName
		var origin_pair_valid := (
			hinge_axis_origin_id == bone_name
			and zero_direction_origin_id == bone_name
			and neutral_rotation_origin_id == bone_name
			and bone_root_origin_id == CombatOriginRecordScript.ORIGIN_RL_BONE_ROOT
			and PlayerDigitHingeRulesScript.rule_has_valid_origin_chain(rule, skeleton)
		)
		if origin_pair_valid:
			digit_origin_pair_count += 1
		_check(origin_pair_valid, "origin_chain_invalid_%s" % String(bone_name))
		_check(hinge_axis_local.distance_to(Vector3(0.0, 0.0, 1.0)) <= 0.0001, "axis_not_local_positive_z_%s" % String(bone_name))
		_check(zero_direction_local.distance_to(Vector3.UP) <= 0.0001, "zero_not_local_positive_y_%s" % String(bone_name))
		var expected_closed_direction_local := _expected_local_direction_for_degrees(expected_closed_degrees)
		var configured_closed_direction_local := (
			Basis(hinge_axis_local, deg_to_rad(expected_closed_degrees)) * zero_direction_local
		).normalized()
		_check(
			configured_closed_direction_local.distance_to(expected_closed_direction_local) <= 0.0001,
			"closed_endpoint_direction_mismatch_%s" % String(bone_name)
		)
		_check(is_finite(float(state.get("angle_degrees", NAN))), "angle_not_finite_%s" % String(bone_name))
		_check(absf(float(state.get("angle_degrees", 999.0))) <= 0.01, "neutral_angle_not_zero_%s" % String(bone_name))
		_check(String(state.get("reference_pose", "")) == "authoring_baseline", "reference_pose_mismatch_%s" % String(bone_name))
		_check(absf(float(state.get("angle_delta_degrees", 999.0))) <= 0.01, "neutral_delta_not_zero_%s" % String(bone_name))
		var hinge_axis_world: Vector3 = state.get("hinge_axis_world", Vector3.ZERO) as Vector3
		_check(absf(hinge_axis_world.length() - 1.0) <= 0.0001, "world_axis_not_normalized_%s" % String(bone_name))
		var actual_hinge_axis_world: Vector3 = state.get("actual_hinge_axis_world", Vector3.ZERO) as Vector3
		_check(absf(actual_hinge_axis_world.length() - 1.0) <= 0.0001, "actual_world_axis_not_normalized_%s" % String(bone_name))
		_check(
			float(state.get("axis_alignment_dot", -1.0)) >= DIRECTION_ALIGNMENT_MINIMUM,
			"neutral_hinge_axis_not_on_authored_bone_%s" % String(bone_name)
		)
		var zero_direction_world: Vector3 = state.get("zero_direction_world", Vector3.ZERO) as Vector3
		var actual_direction_world: Vector3 = state.get("actual_direction_world", Vector3.ZERO) as Vector3
		_check(
			zero_direction_world.dot(actual_direction_world) >= DIRECTION_ALIGNMENT_MINIMUM,
			"neutral_zero_direction_not_on_authored_bone_%s" % String(bone_name)
		)
		_check(_visual_state_has_geometry(rig, state), "visual_geometry_missing_%s" % String(bone_name))
		_check(
			_visual_state_has_directional_label(
				rig,
				state,
				expected_min_degrees,
				expected_max_degrees,
				expected_open_degrees,
				expected_closed_degrees
			),
			"directional_label_mismatch_%s" % String(bone_name)
		)
		var chain_key: String = "%s:%s" % [String(slot_id), String(digit_id)]
		var section_lookup: Dictionary = per_digit_sections.get(chain_key, {}) as Dictionary
		section_lookup[section_index] = true
		per_digit_sections[chain_key] = section_lookup
		if slot_id == &"hand_right":
			right_count += 1
			if digit_id == &"thumb":
				right_thumb_count += 1
			else:
				right_finger_count += 1
		elif slot_id == &"hand_left":
			left_count += 1
			if digit_id == &"thumb":
				left_thumb_count += 1
			else:
				left_finger_count += 1
		else:
			_check(false, "unknown_slot_%s" % String(bone_name))
		var is_thumb: bool = digit_id == &"thumb"
		_check(
			(rule.get("solve_mode", StringName()) as StringName) == &"serial_joint_hinge",
			"solve_mode_mismatch_%s" % String(bone_name)
		)
		_check(absf(float(rule.get("open_degrees", -999.0)) - expected_open_degrees) <= 0.0001, "rule_open_mismatch_%s" % String(bone_name))
		_check(absf(float(rule.get("closed_degrees", -999.0)) - expected_closed_degrees) <= 0.0001, "rule_closed_mismatch_%s" % String(bone_name))
		_check(absf(float(rule.get("motion_direction_sign", 0.0)) - signf(expected_closed_degrees)) <= 0.0001, "rule_motion_sign_mismatch_%s" % String(bone_name))
		_check(bool(rule.get("bidirectional_about_zero", false)) == is_bidirectional_thumb_root, "rule_bidirectional_mismatch_%s" % String(bone_name))
		_check(bool(rule.get("preload_collinear", false)) == is_thumb, "collinear_preload_mismatch_%s" % String(bone_name))
		_check(bool(rule.get("pre_open_required", false)) == is_thumb, "pre_open_mismatch_%s" % String(bone_name))
		_check(
			(rule.get("preload_mode", StringName()) as StringName) == (
				&"collinear_then_clear_open" if is_thumb else &"authored_open_pose"
			),
			"preload_mode_mismatch_%s" % String(bone_name)
		)
		_check(
			absf(float(rule.get("pre_open_step_degrees", -1.0)) - (20.0 if is_thumb else 0.0)) <= 0.0001,
			"pre_open_step_mismatch_%s" % String(bone_name)
		)
		_check(int(rule.get("solve_order", 0)) == section_index, "solve_order_mismatch_%s" % String(bone_name))

	_check(right_count == 15, "right_digit_count_not_15")
	_check(left_count == 15, "left_digit_count_not_15")
	_check(right_finger_count == 12, "right_finger_count_not_12")
	_check(right_thumb_count == 3, "right_thumb_count_not_3")
	_check(left_finger_count == 12, "left_finger_count_not_12")
	_check(left_thumb_count == 3, "left_thumb_count_not_3")
	_check(per_digit_sections.size() == 10, "digit_chain_count_not_10")
	for chain_key_variant: Variant in per_digit_sections.keys():
		var chain_key: String = String(chain_key_variant)
		var section_lookup: Dictionary = per_digit_sections.get(chain_key, {}) as Dictionary
		_check(section_lookup.size() == 3, "chain_does_not_have_three_sections_%s" % chain_key)
		_check(section_lookup.has(1) and section_lookup.has(2) and section_lookup.has(3), "chain_sequence_invalid_%s" % chain_key)
	var thumb_proximal_policy_metrics: Dictionary = (
		_verify_thumb_proximal_penetration_policy()
	)
	var live_solver_authority_probe_count: int = 0
	var grip_presenter: RefCounted = PlayerRigFingerGripPresenterScript.new()
	for rule: Dictionary in rules:
		var bone_name: StringName = rule.get("bone", StringName()) as StringName
		var slot_id: StringName = rule.get("slot_id", StringName()) as StringName
		var digit_id: StringName = rule.get("digit", StringName()) as StringName
		var section_index: int = int(rule.get("section", 0))
		var expected_closed_degrees: float = _expected_closed_degrees(slot_id, digit_id, section_index)
		var expected_endpoint: Vector3 = _expected_local_direction_for_degrees(expected_closed_degrees)
		_check(
			absf(PlayerDigitHingeRulesScript.get_closed_degrees_for_bone(bone_name) - expected_closed_degrees) <= 0.0001,
			"bone_authority_angle_mismatch_%s" % String(bone_name)
		)
		var open_rotation: Quaternion = grip_presenter.call(
			"_resolve_planar_contact_group_rotation",
			skeleton,
			bone_name,
			Quaternion.IDENTITY,
			0.0
		) as Quaternion
		var closed_rotation: Quaternion = grip_presenter.call(
			"_resolve_planar_contact_group_rotation",
			skeleton,
			bone_name,
			Quaternion.IDENTITY,
			1.0
		) as Quaternion
		var underdriven_rotation: Quaternion = grip_presenter.call(
			"_resolve_planar_contact_group_rotation",
			skeleton,
			bone_name,
			Quaternion.IDENTITY,
			-1.0
		) as Quaternion
		var overdriven_rotation: Quaternion = grip_presenter.call(
			"_resolve_planar_contact_group_rotation",
			skeleton,
			bone_name,
			Quaternion.IDENTITY,
			2.0
		) as Quaternion
		var open_basis := Basis(open_rotation).orthonormalized()
		var closed_basis := Basis(closed_rotation).orthonormalized()
		var underdriven_basis := Basis(underdriven_rotation).orthonormalized()
		var overdriven_basis := Basis(overdriven_rotation).orthonormalized()
		_check(open_basis.y.distance_to(Vector3.UP) <= 0.0001, "live_solver_open_not_positive_y_%s" % String(bone_name))
		_check(underdriven_basis.y.distance_to(Vector3.UP) <= 0.0001, "live_solver_moved_below_open_%s" % String(bone_name))
		_check(closed_basis.y.distance_to(expected_endpoint) <= 0.0001, "live_solver_closed_endpoint_mismatch_%s" % String(bone_name))
		_check(closed_basis.z.distance_to(Vector3(0.0, 0.0, 1.0)) <= 0.0001, "live_solver_pivot_changed_%s" % String(bone_name))
		_check(overdriven_basis.y.distance_to(expected_endpoint) <= 0.0001, "live_solver_exceeded_closed_limit_%s" % String(bone_name))
		live_solver_authority_probe_count += 1
	_check(live_solver_authority_probe_count == 30, "live_solver_authority_probe_count_not_30")
	grip_presenter.call("_ensure_animation_grip_baseline_cache")
	var live_solver_chain_joint_probe_count: int = 0
	var live_solver_chain_probes: Array[Dictionary] = [
		{"slot_id": &"hand_right", "digit": &"index"},
		{"slot_id": &"hand_right", "digit": &"thumb"},
		{"slot_id": &"hand_left", "digit": &"index"},
		{"slot_id": &"hand_left", "digit": &"thumb"},
	]
	for chain_probe: Dictionary in live_solver_chain_probes:
		var slot_id: StringName = chain_probe.get("slot_id", StringName()) as StringName
		var digit_id: StringName = chain_probe.get("digit", StringName()) as StringName
		grip_presenter.call("_apply_animation_contact_open_pose", skeleton, slot_id)
		skeleton.force_update_all_bone_transforms()
		var chain_rules: Array[Dictionary] = PlayerDigitHingeRulesScript.get_chain_rules(slot_id, digit_id)
		var open_local_rotations: Dictionary = {}
		for chain_rule: Dictionary in chain_rules:
			var chain_bone_name: StringName = chain_rule.get("bone", StringName()) as StringName
			var chain_bone_index: int = skeleton.find_bone(String(chain_bone_name))
			if chain_bone_index >= 0:
				open_local_rotations[chain_bone_name] = skeleton.get_bone_pose_rotation(chain_bone_index).normalized()
		grip_presenter.call("_apply_plane_curl_pose", skeleton, slot_id, digit_id, 1.0)
		skeleton.force_update_all_bone_transforms()
		for chain_rule: Dictionary in chain_rules:
			var chain_bone_name: StringName = chain_rule.get("bone", StringName()) as StringName
			var chain_section_index: int = int(chain_rule.get("section", 0))
			var expected_chain_closed_degrees: float = _expected_closed_degrees(
				slot_id,
				digit_id,
				chain_section_index
			)
			var expected_endpoint: Vector3 = _expected_local_direction_for_degrees(
				expected_chain_closed_degrees
			)
			var chain_bone_index: int = skeleton.find_bone(String(chain_bone_name))
			if chain_bone_index < 0:
				continue
			var open_local_rotation: Quaternion = open_local_rotations.get(
				chain_bone_name,
				Quaternion.IDENTITY
			) as Quaternion
			var current_local_rotation: Quaternion = skeleton.get_bone_pose_rotation(chain_bone_index).normalized()
			var local_delta_basis := Basis(
				(open_local_rotation.inverse() * current_local_rotation).normalized()
			).orthonormalized()
			_check(
				local_delta_basis.y.distance_to(expected_endpoint) <= 0.0001,
				"live_solver_chain_endpoint_mismatch_%s" % String(chain_bone_name)
			)
			_check(
				local_delta_basis.z.distance_to(Vector3(0.0, 0.0, 1.0)) <= 0.0001,
				"live_solver_chain_pivot_changed_%s" % String(chain_bone_name)
			)
			live_solver_chain_joint_probe_count += 1
	_check(live_solver_chain_joint_probe_count == 12, "live_solver_chain_joint_probe_count_not_12")
	rig.reset_authoring_preview_baseline_pose(&"Idle")
	skeleton.force_update_all_bone_transforms()
	var configured_hinge_probe_count: int = 0
	var configured_hinge_probe_started_usec: int = Time.get_ticks_usec()
	for rule: Dictionary in rules:
		var probe_bone_name: StringName = rule.get("bone", StringName()) as StringName
		var probe_bone_index: int = skeleton.find_bone(String(probe_bone_name))
		if probe_bone_index < 0:
			continue
		var neutral_rotation: Quaternion = before_rotations.get(probe_bone_name, Quaternion.IDENTITY) as Quaternion
		var configured_probe_degrees: float = float(rule.get("closed_degrees", 0.0)) * 0.5
		var configured_hinge_rotation := Quaternion(Vector3(0.0, 0.0, 1.0), deg_to_rad(configured_probe_degrees))
		skeleton.set_bone_pose_rotation(
			probe_bone_index,
			(neutral_rotation * configured_hinge_rotation).normalized()
		)
		skeleton.force_update_all_bone_transforms()
		rig.sync_authoring_joint_range_debug_now(true)
		var probe_state: Dictionary = rig.get_authoring_joint_range_debug_state()
		var probe_digit_states: Dictionary = probe_state.get("digit_bones", {}) as Dictionary
		var probed_bone_state: Dictionary = probe_digit_states.get(String(probe_bone_name), {}) as Dictionary
		_check(
			absf(float(probed_bone_state.get("angle_degrees", -999.0)) - configured_probe_degrees) <= 0.1,
			"configured_hinge_probe_angle_failed_%s" % String(probe_bone_name)
		)
		_check(
			String(probed_bone_state.get("state", "")) == "inside",
			"configured_hinge_probe_state_failed_%s" % String(probe_bone_name)
		)
		var probe_hinge_direction: Vector3 = probed_bone_state.get(
			"current_hinge_direction_world",
			Vector3.ZERO
		) as Vector3
		var probe_actual_direction: Vector3 = probed_bone_state.get(
			"actual_direction_world",
			Vector3.ZERO
		) as Vector3
		_check(
			probe_hinge_direction.dot(probe_actual_direction) >= DIRECTION_ALIGNMENT_MINIMUM,
			"configured_hinge_probe_geometry_failed_%s" % String(probe_bone_name)
		)
		var next_bone_name: StringName = rule.get("next_bone", StringName()) as StringName
		if next_bone_name != StringName():
			var baseline_child_state: Dictionary = digit_states.get(String(next_bone_name), {}) as Dictionary
			var probe_child_state: Dictionary = probe_digit_states.get(String(next_bone_name), {}) as Dictionary
			var baseline_child_joint: Vector3 = baseline_child_state.get("joint_world", Vector3.ZERO) as Vector3
			var probe_child_joint: Vector3 = probe_child_state.get("joint_world", Vector3.ZERO) as Vector3
			_check(
				baseline_child_joint.distance_to(probe_child_joint) > DESCENDANT_MOVEMENT_EPSILON_METERS,
				"configured_hinge_probe_descendant_did_not_follow_%s_to_%s" % [
					String(probe_bone_name),
					String(next_bone_name),
				]
			)
			var next_bone_index: int = skeleton.find_bone(String(next_bone_name))
			var expected_child_joint: Vector3 = skeleton.to_global(
				skeleton.get_bone_global_pose(next_bone_index).origin
			) if next_bone_index >= 0 else Vector3.INF
			_check(
				probe_child_joint.distance_to(expected_child_joint) <= DESCENDANT_MOVEMENT_EPSILON_METERS,
				"configured_hinge_probe_descendant_visual_detached_%s_to_%s" % [
					String(probe_bone_name),
					String(next_bone_name),
				]
			)
		for other_rule: Dictionary in rules:
			var other_bone_name: StringName = other_rule.get("bone", StringName()) as StringName
			if other_bone_name == probe_bone_name:
				continue
			var other_state: Dictionary = probe_digit_states.get(String(other_bone_name), {}) as Dictionary
			_check(
				absf(float(other_state.get("angle_degrees", 999.0))) <= 0.01,
				"configured_hinge_probe_leaked_%s_to_%s" % [String(probe_bone_name), String(other_bone_name)]
			)
		skeleton.set_bone_pose_rotation(probe_bone_index, neutral_rotation.normalized())
		skeleton.force_update_all_bone_transforms()
		configured_hinge_probe_count += 1
	var configured_hinge_probe_elapsed_ms: float = float(
		Time.get_ticks_usec() - configured_hinge_probe_started_usec
	) / 1000.0
	rig.sync_authoring_joint_range_debug_now(true)
	_check(configured_hinge_probe_count == EXPECTED_DIGIT_BONE_COUNT, "configured_hinge_probe_count_not_30")
	var boundary_probe_count: int = 0
	for probe_bone_name: StringName in [
		&"CC_Base_R_Index1",
		&"CC_Base_R_Thumb1",
		&"CC_Base_L_Index1",
		&"CC_Base_L_Thumb1",
	]:
		var probe_bone_index: int = skeleton.find_bone(String(probe_bone_name))
		var neutral_rotation: Quaternion = before_rotations.get(probe_bone_name, Quaternion.IDENTITY) as Quaternion
		var boundary_rule: Dictionary = PlayerDigitHingeRulesScript.get_rule_for_bone(probe_bone_name)
		var min_degrees: float = float(boundary_rule.get("min_degrees", 0.0))
		var max_degrees: float = float(boundary_rule.get("max_degrees", 0.0))
		var boundary_probes: Array[Dictionary] = [
			{
				"name": "below_min",
				"rotation": Quaternion(Vector3(0.0, 0.0, 1.0), deg_to_rad(min_degrees - 10.0)),
				"state": "below_min",
			},
			{
				"name": "above_max",
				"rotation": Quaternion(Vector3(0.0, 0.0, 1.0), deg_to_rad(max_degrees + 10.0)),
				"state": "above_max",
			},
			{"name": "off_axis_x", "rotation": Quaternion(Vector3.RIGHT, deg_to_rad(10.0)), "state": "off_axis"},
			{"name": "off_axis_y", "rotation": Quaternion(Vector3.UP, deg_to_rad(10.0)), "state": "off_axis"},
		]
		if bool(boundary_rule.get("bidirectional_about_zero", false)):
			boundary_probes.append({
				"name": "bidirectional_min_allowed",
				"rotation": Quaternion(Vector3(0.0, 0.0, 1.0), deg_to_rad(min_degrees)),
				"state": "near_min",
			})
			boundary_probes.append({
				"name": "bidirectional_max_allowed",
				"rotation": Quaternion(Vector3(0.0, 0.0, 1.0), deg_to_rad(max_degrees)),
				"state": "near_max",
			})
		for boundary_probe: Dictionary in boundary_probes:
			skeleton.set_bone_pose_rotation(
				probe_bone_index,
				(neutral_rotation * (boundary_probe.get("rotation", Quaternion.IDENTITY) as Quaternion)).normalized()
			)
			skeleton.force_update_all_bone_transforms()
			rig.sync_authoring_joint_range_debug_now(true)
			var boundary_state: Dictionary = (
				rig.get_authoring_joint_range_debug_state().get("digit_bones", {}) as Dictionary
			).get(String(probe_bone_name), {}) as Dictionary
			var expected_state: String = String(boundary_probe.get("state", ""))
			_check(
				String(boundary_state.get("state", "")) == expected_state,
				"%s_probe_state_failed_%s" % [String(boundary_probe.get("name", "")), String(probe_bone_name)]
			)
			if expected_state == "off_axis":
				_check(
					float(boundary_state.get("off_axis_degrees", 0.0))
						> float(boundary_state.get("off_axis_tolerance_degrees", 999.0)),
					"%s_probe_tolerance_failed_%s" % [String(boundary_probe.get("name", "")), String(probe_bone_name)]
				)
			boundary_probe_count += 1
		skeleton.set_bone_pose_rotation(probe_bone_index, neutral_rotation.normalized())
		skeleton.force_update_all_bone_transforms()
	rig.sync_authoring_joint_range_debug_now(true)
	_check(boundary_probe_count == 20, "boundary_probe_count_not_20")

	var after_rotations: Dictionary = _capture_bone_rotations(skeleton, rules)
	var rotation_mismatches: PackedStringArray = _rotation_mismatches(before_rotations, after_rotations)
	_check(rotation_mismatches.is_empty(), "debug_sync_changed_digit_pose")
	_check(_transforms_match(before_right_hand, _get_bone_world_transform(skeleton, &"CC_Base_R_Hand")), "debug_sync_changed_right_hand")
	_check(_transforms_match(before_left_hand, _get_bone_world_transform(skeleton, &"CC_Base_L_Hand")), "debug_sync_changed_left_hand")

	# Debug range geometry is persistent editor state. Visibility must not rebuild
	# it: perturb one marker after the last legitimate pose sync so an accidental
	# OFF/ON resync is observable even when the recomputed result looks identical.
	var visibility_sentinel: Node3D = (
		debug_root.find_child("HingePivotMarker", true, false) as Node3D
		if debug_root != null
		else null
	)
	_check(visibility_sentinel != null, "debug_visibility_sentinel_missing")
	if visibility_sentinel != null:
		visibility_sentinel.global_position += DEBUG_VISIBILITY_SENTINEL_OFFSET
	var enabled_child_count: int = debug_root.get_child_count() if debug_root != null else -1
	var pre_visibility_state: Dictionary = rig.get_authoring_joint_range_debug_state()
	var pre_visibility_nodes: Dictionary = _capture_debug_node_snapshot(debug_root)
	var pre_visibility_rotations: Dictionary = _capture_bone_rotations(skeleton, rules)
	rig.set_authoring_joint_range_debug_visible(false)
	var disabled_state: Dictionary = rig.get_authoring_joint_range_debug_state()
	var disabled_nodes: Dictionary = _capture_debug_node_snapshot(debug_root)
	var disabled_rotations: Dictionary = _capture_bone_rotations(skeleton, rules)
	var disabled_node_mismatches: PackedStringArray = _debug_node_snapshot_mismatches(
		pre_visibility_nodes,
		disabled_nodes
	)
	var disabled_rotation_mismatches: PackedStringArray = _rotation_mismatches(
		pre_visibility_rotations,
		disabled_rotations
	)
	_check(not bool(disabled_state.get("visible", true)), "disabled_state_still_visible")
	_check(
		int(disabled_state.get("visual_count", -1))
			== int(pre_visibility_state.get("visual_count", -2)),
		"disabled_visual_state_not_retained"
	)
	_check(
		int(disabled_state.get("digit_visual_count", -1)) == EXPECTED_DIGIT_BONE_COUNT,
		"disabled_digit_state_not_retained"
	)
	_check(
		(disabled_state.get("digit_bones", {}) as Dictionary).size()
			== EXPECTED_DIGIT_BONE_COUNT,
		"disabled_digit_bone_state_not_retained"
	)
	_check(debug_root != null and not debug_root.visible, "disabled_root_still_visible")
	_check(
		debug_root != null and debug_root.get_child_count() == enabled_child_count,
		"disable_changed_debug_node_count"
	)
	_check(disabled_node_mismatches.is_empty(), "disable_recalculated_debug_nodes")
	_check(disabled_rotation_mismatches.is_empty(), "disable_changed_digit_pose")

	rig.set_authoring_joint_range_debug_visible(true)
	var reenabled_state: Dictionary = rig.get_authoring_joint_range_debug_state()
	var reenabled_nodes: Dictionary = _capture_debug_node_snapshot(debug_root)
	var reenabled_rotations: Dictionary = _capture_bone_rotations(skeleton, rules)
	var reenabled_node_mismatches: PackedStringArray = _debug_node_snapshot_mismatches(
		pre_visibility_nodes,
		reenabled_nodes
	)
	var reenabled_rotation_mismatches: PackedStringArray = _rotation_mismatches(
		pre_visibility_rotations,
		reenabled_rotations
	)
	_check(int(reenabled_state.get("digit_visual_count", 0)) == EXPECTED_DIGIT_BONE_COUNT, "reenabled_digit_count_not_30")
	_check(debug_root != null and debug_root.visible, "reenabled_root_not_visible")
	_check(debug_root != null and debug_root.get_child_count() == enabled_child_count, "reenable_duplicated_visual_nodes")
	_check(reenabled_node_mismatches.is_empty(), "reenable_recalculated_debug_nodes")
	_check(reenabled_rotation_mismatches.is_empty(), "reenable_changed_digit_pose")

	_finish({
		"rule_count": rules.size(),
		"digit_visual_count": int(enabled_state.get("digit_visual_count", 0)),
		"aggregate_visual_count": int(enabled_state.get("visual_count", 0)),
		"right_digit_count": right_count,
		"left_digit_count": left_count,
		"right_finger_count": right_finger_count,
		"right_thumb_count": right_thumb_count,
		"left_finger_count": left_finger_count,
		"left_thumb_count": left_thumb_count,
		"digit_chain_count": per_digit_sections.size(),
		"digit_bone_root_chain_count": digit_bone_root_chain_count,
		"digit_origin_pair_count": digit_origin_pair_count,
		"thumb_proximal_policy_side_count": int(thumb_proximal_policy_metrics.get(
			"side_count",
			0
		)),
		"thumb_proximal_policy_section_cap_probe_count": int(
			thumb_proximal_policy_metrics.get("section_cap_probe_count", 0)
		),
		"thumb_proximal_policy_blocker_probe_count": int(
			thumb_proximal_policy_metrics.get("blocker_probe_count", 0)
		),
		"thumb_proximal_policy_summary_probe_count": int(
			thumb_proximal_policy_metrics.get("summary_probe_count", 0)
		),
		"live_solver_authority_probe_count": live_solver_authority_probe_count,
		"live_solver_chain_joint_probe_count": live_solver_chain_joint_probe_count,
		"configured_hinge_probe_count": configured_hinge_probe_count,
		"configured_hinge_probe_total_ms": configured_hinge_probe_elapsed_ms,
		"configured_hinge_probe_ms_per_sync": configured_hinge_probe_elapsed_ms / maxf(float(configured_hinge_probe_count), 1.0),
		"boundary_probe_count": boundary_probe_count,
		"debug_root_child_count": enabled_child_count,
		"rotation_mismatches": rotation_mismatches,
		"disabled_node_mismatches": disabled_node_mismatches,
		"disabled_rotation_mismatches": disabled_rotation_mismatches,
		"reenabled_node_mismatches": reenabled_node_mismatches,
		"reenabled_rotation_mismatches": reenabled_rotation_mismatches,
	})

func _verify_thumb_proximal_penetration_policy() -> Dictionary:
	var solver: RefCounted = PlayerFingerSurfaceGripSolverScript.new()
	var finger_targets: Array[float] = []
	for target_variant: Variant in PlayerDigitHingeRulesScript.SECTION_TARGET_OVERLAPS_METERS:
		finger_targets.append(float(target_variant))
	var thumb_targets: Array[float] = []
	for target_variant: Variant in PlayerDigitHingeRulesScript.THUMB_SECTION_TARGET_OVERLAPS_METERS:
		thumb_targets.append(float(target_variant))
	var global_max_overlap: float = PlayerDigitHingeRulesScript.MAX_CONTACT_OVERLAP_METERS
	var thumb_serial_max_overlap: float = (
		thumb_targets[1] + PlayerDigitHingeRulesScript.CONTACT_OVERLAP_TOLERANCE_METERS
	)
	var expected_finger_caps: Array[float] = [0.0005, 0.00048, 0.00038]
	var expected_thumb_caps: Array[float] = [0.005, 0.00108, 0.00038]
	var side_count := 0
	var section_cap_probe_count := 0
	_check(
		not PlayerFingerSurfaceGripSolverScript.THUMB_PROXIMAL_CONTACT_TARGET_REQUIRED,
		"thumb_proximal_contact_target_not_bypassed"
	)
	_check(
		absf(
			PlayerFingerSurfaceGripSolverScript.THUMB_PROXIMAL_MAX_ALLOWED_OVERLAP_METERS
			- 0.005
		) <= 0.000000001,
		"thumb_proximal_hard_cap_not_5mm"
	)
	for slot_id: StringName in [&"hand_right", &"hand_left"]:
		var side_rules: Dictionary = PlayerDigitHingeRulesScript.get_surface_solver_side_rules(
			slot_id
		)
		var thumb_snapshot: Dictionary = _find_surface_digit_rule(side_rules, &"thumb")
		var index_snapshot: Dictionary = _find_surface_digit_rule(side_rules, &"index")
		_check(not thumb_snapshot.is_empty(), "thumb_surface_rule_missing_%s" % String(slot_id))
		_check(not index_snapshot.is_empty(), "index_surface_rule_missing_%s" % String(slot_id))
		if thumb_snapshot.is_empty() or index_snapshot.is_empty():
			continue
		side_count += 1
		_check(
			thumb_snapshot.get("section_target_overlaps_meters", []) == thumb_targets,
			"thumb_section_targets_mismatch_%s" % String(slot_id)
		)
		_check(
			index_snapshot.get("section_target_overlaps_meters", []) == finger_targets,
			"index_section_targets_changed_%s" % String(slot_id)
		)
		for section_index: int in range(3):
			var thumb_cap: float = float(solver.call(
				"_resolve_serial_section_max_allowed_overlap",
				thumb_snapshot,
				section_index,
				thumb_targets[section_index],
				thumb_serial_max_overlap
			))
			_check(
				absf(thumb_cap - expected_thumb_caps[section_index]) <= 0.000000001,
				"thumb_section_%d_cap_mismatch_%s" % [section_index + 1, String(slot_id)]
			)
			section_cap_probe_count += 1
			var index_cap: float = float(solver.call(
				"_resolve_serial_section_max_allowed_overlap",
				index_snapshot,
				section_index,
				finger_targets[section_index],
				global_max_overlap
			))
			_check(
				absf(index_cap - expected_finger_caps[section_index]) <= 0.000000001,
				"index_section_%d_cap_changed_%s" % [section_index + 1, String(slot_id)]
			)
			section_cap_probe_count += 1
	_check(side_count == 2, "thumb_proximal_policy_side_count_not_2")
	_check(section_cap_probe_count == 12, "thumb_proximal_section_cap_probe_count_not_12")

	var section_2_blocked_states: Array[Dictionary] = [
		_make_serial_policy_state(0, 0.0049, 0.005, thumb_targets[0]),
		_make_serial_policy_state(1, 0.001081, 0.00108, thumb_targets[1]),
		_make_serial_policy_state(2, 0.0003, 0.00038, thumb_targets[2]),
	]
	var section_3_blocked_states: Array[Dictionary] = [
		_make_serial_policy_state(0, 0.0049, 0.005, thumb_targets[0]),
		_make_serial_policy_state(1, 0.001, 0.00108, thumb_targets[1]),
		_make_serial_policy_state(2, 0.000381, 0.00038, thumb_targets[2]),
	]
	var proximal_cap_blocked_states: Array[Dictionary] = [
		_make_serial_policy_state(0, 0.005001, 0.005, thumb_targets[0]),
		_make_serial_policy_state(1, 0.001, 0.00108, thumb_targets[1]),
		_make_serial_policy_state(2, 0.0003, 0.00038, thumb_targets[2]),
	]
	var section_2_blocker: int = int(solver.call(
		"_resolve_downstream_limit_blocker",
		{"section_states": section_2_blocked_states},
		0,
		thumb_targets,
		thumb_serial_max_overlap
	))
	var section_3_blocker: int = int(solver.call(
		"_resolve_downstream_limit_blocker",
		{"section_states": section_3_blocked_states},
		0,
		thumb_targets,
		thumb_serial_max_overlap
	))
	var proximal_cap_blocker: int = int(solver.call(
		"_resolve_downstream_limit_blocker",
		{"section_states": proximal_cap_blocked_states},
		0,
		thumb_targets,
		thumb_serial_max_overlap
	))
	_check(section_2_blocker == 1, "thumb_proximal_not_stopped_by_section_2_cap")
	_check(section_3_blocker == 2, "thumb_proximal_not_stopped_by_section_3_cap")
	_check(proximal_cap_blocker == 0, "thumb_proximal_5mm_emergency_cap_not_enforced")
	var blocker_probe_count := 3

	var safe_summary: Dictionary = solver.call(
		"_summarize_serial_section_states",
		[
			_make_serial_policy_state(0, 0.0049, 0.005, thumb_targets[0]),
			_make_serial_policy_state(1, 0.001, 0.00108, thumb_targets[1]),
			_make_serial_policy_state(2, 0.0003, 0.00038, thumb_targets[2]),
		],
		thumb_targets,
		thumb_serial_max_overlap,
		0.0015
	) as Dictionary
	var thumb_cap_exceeded_summary: Dictionary = solver.call(
		"_summarize_serial_section_states",
		[
			_make_serial_policy_state(0, 0.005001, 0.005, thumb_targets[0]),
			_make_serial_policy_state(1, 0.001, 0.00108, thumb_targets[1]),
			_make_serial_policy_state(2, 0.0003, 0.00038, thumb_targets[2]),
		],
		thumb_targets,
		thumb_serial_max_overlap,
		0.0015
	) as Dictionary
	var index_cap_exceeded_summary: Dictionary = solver.call(
		"_summarize_serial_section_states",
		[
			_make_serial_policy_state(0, 0.000501, 0.0005, finger_targets[0]),
			_make_serial_policy_state(1, 0.0004, 0.00048, finger_targets[1]),
			_make_serial_policy_state(2, 0.0003, 0.00038, finger_targets[2]),
		],
		finger_targets,
		global_max_overlap,
		0.0015
	) as Dictionary
	_check(
		bool(safe_summary.get("overlap_limit_respected", false)),
		"thumb_proximal_4_9mm_rejected_by_final_safety"
	)
	_check(
		int(safe_summary.get("feasible_section_count", -1)) == 2,
		"thumb_proximal_bypass_falsely_reported_target_reached"
	)
	_check(
		not bool(thumb_cap_exceeded_summary.get("overlap_limit_respected", true)),
		"thumb_proximal_above_5mm_accepted_by_final_safety"
	)
	_check(
		not bool(index_cap_exceeded_summary.get("overlap_limit_respected", true)),
		"non_thumb_above_0_5mm_accepted_by_final_safety"
	)
	var summary_probe_count := 4
	return {
		"side_count": side_count,
		"section_cap_probe_count": section_cap_probe_count,
		"blocker_probe_count": blocker_probe_count,
		"summary_probe_count": summary_probe_count,
	}

func _find_surface_digit_rule(side_rules: Dictionary, digit_id: StringName) -> Dictionary:
	for digit_variant: Variant in side_rules.get("digits", []):
		var digit_rule: Dictionary = digit_variant as Dictionary
		if StringName(digit_rule.get("digit_id", StringName())) == digit_id:
			return digit_rule
	return {}

func _make_serial_policy_state(
	section_index: int,
	penetration_meters: float,
	section_cap_meters: float,
	target_meters: float
) -> Dictionary:
	return {
		"section_index": section_index,
		"surface_query_hit": true,
		"inside_classification_valid": true,
		"ray_hit": true,
		"inside_solid": false,
		"inside_solid_sample_count": 0,
		"within_overlap_limit": true,
		"in_contact": true,
		"signed_overlap_meters": penetration_meters,
		"penetration_meters": penetration_meters,
		"contact_error_meters": absf(penetration_meters - target_meters),
		"section_max_allowed_overlap_meters": section_cap_meters,
	}

func _bone_chain_reaches_root(
	skeleton: Skeleton3D,
	bone_name: StringName,
	root_bone_name: StringName
) -> bool:
	if skeleton == null or bone_name == StringName() or root_bone_name == StringName():
		return false
	var bone_index: int = skeleton.find_bone(String(bone_name))
	var visited: Dictionary = {}
	while bone_index >= 0:
		if visited.has(bone_index):
			return false
		visited[bone_index] = true
		if StringName(skeleton.get_bone_name(bone_index)) == root_bone_name:
			return true
		bone_index = skeleton.get_bone_parent(bone_index)
	return false

func _visual_state_has_geometry(rig: Node, state: Dictionary) -> bool:
	var visual_path: String = String(state.get("visual_node_path", ""))
	if visual_path.is_empty():
		return false
	var visual_root: Node3D = rig.get_node_or_null(NodePath(visual_path)) as Node3D
	if visual_root == null:
		visual_root = root.get_node_or_null(NodePath(visual_path)) as Node3D
	if visual_root == null or not visual_root.visible:
		return false
	var plane: MeshInstance3D = visual_root.get_node_or_null("AllowedPlane") as MeshInstance3D
	var lines: MeshInstance3D = visual_root.get_node_or_null("BoundaryLines") as MeshInstance3D
	var min_marker: MeshInstance3D = visual_root.get_node_or_null("HingeMinMarker") as MeshInstance3D
	var max_marker: MeshInstance3D = visual_root.get_node_or_null("HingeMaxMarker") as MeshInstance3D
	var current_marker: MeshInstance3D = visual_root.get_node_or_null("HingeCurrentMarker") as MeshInstance3D
	var pivot_marker: MeshInstance3D = visual_root.get_node_or_null("HingePivotMarker") as MeshInstance3D
	return plane != null and plane.visible and plane.mesh != null and plane.mesh.get_surface_count() > 0 \
		and lines != null and lines.visible and lines.mesh != null and lines.mesh.get_surface_count() > 0 \
		and min_marker != null and min_marker.visible \
		and max_marker != null and max_marker.visible \
		and current_marker != null and current_marker.visible \
		and pivot_marker != null and pivot_marker.visible

func _visual_state_has_directional_label(
	rig: Node,
	state: Dictionary,
	expected_min_degrees: float,
	expected_max_degrees: float,
	expected_open_degrees: float,
	expected_closed_degrees: float
) -> bool:
	var visual_path: String = String(state.get("visual_node_path", ""))
	if visual_path.is_empty():
		return false
	var visual_root: Node3D = rig.get_node_or_null(NodePath(visual_path)) as Node3D
	if visual_root == null:
		visual_root = root.get_node_or_null(NodePath(visual_path)) as Node3D
	var label: Label3D = visual_root.get_node_or_null("AngleLabel") as Label3D if visual_root != null else null
	return label != null and label.visible \
		and label.text.contains("ROM %.0f..%.0f" % [expected_min_degrees, expected_max_degrees]) \
		and label.text.contains(
			"close %.0f->%.0f" % [expected_open_degrees, expected_closed_degrees]
		)


func _expected_open_degrees(
	slot_id: StringName,
	digit_id: StringName,
	section_index: int
) -> float:
	if digit_id != &"thumb" or section_index != 1:
		return 0.0
	return 70.0 if slot_id == &"hand_right" else -70.0

func _expected_closed_degrees(
	slot_id: StringName,
	digit_id: StringName,
	section_index: int
) -> float:
	if slot_id == &"hand_right":
		if digit_id == &"thumb":
			return -30.0 if section_index == 1 else -90.0
		return 90.0
	if digit_id == &"thumb":
		return 30.0 if section_index == 1 else 90.0
	return -90.0

func _expected_local_direction_for_degrees(angle_degrees: float) -> Vector3:
	var angle_radians: float = deg_to_rad(angle_degrees)
	return Vector3(-sin(angle_radians), cos(angle_radians), 0.0).normalized()

func _capture_debug_node_snapshot(debug_root: Node3D) -> Dictionary:
	var snapshot: Dictionary = {}
	if debug_root == null:
		return snapshot
	_append_debug_node_snapshot(debug_root, debug_root, snapshot)
	return snapshot

func _append_debug_node_snapshot(
	debug_root: Node3D,
	parent_node: Node,
	snapshot: Dictionary
) -> void:
	for child_node: Node in parent_node.get_children():
		var child_3d: Node3D = child_node as Node3D
		if child_3d != null:
			var relative_path: String = String(debug_root.get_path_to(child_3d))
			snapshot[relative_path] = {
				"instance_id": child_3d.get_instance_id(),
				"transform": child_3d.transform,
			}
		_append_debug_node_snapshot(debug_root, child_node, snapshot)

func _debug_node_snapshot_mismatches(
	expected: Dictionary,
	actual: Dictionary
) -> PackedStringArray:
	var mismatches: PackedStringArray = []
	if expected.size() != actual.size():
		mismatches.append("size:%d->%d" % [expected.size(), actual.size()])
	for path_variant: Variant in expected.keys():
		var relative_path: String = String(path_variant)
		if not actual.has(relative_path):
			mismatches.append("missing:%s" % relative_path)
			continue
		var expected_state: Dictionary = expected.get(relative_path, {}) as Dictionary
		var actual_state: Dictionary = actual.get(relative_path, {}) as Dictionary
		if int(expected_state.get("instance_id", 0)) != int(actual_state.get("instance_id", -1)):
			mismatches.append("instance:%s" % relative_path)
			continue
		var expected_transform: Transform3D = expected_state.get(
			"transform",
			Transform3D.IDENTITY
		) as Transform3D
		var actual_transform: Transform3D = actual_state.get(
			"transform",
			Transform3D.IDENTITY
		) as Transform3D
		if not _debug_local_transforms_match(expected_transform, actual_transform):
			mismatches.append("transform:%s" % relative_path)
	return mismatches

func _debug_local_transforms_match(first: Transform3D, second: Transform3D) -> bool:
	return (
		first.origin.distance_to(second.origin) <= DEBUG_TRANSFORM_EPSILON
		and first.basis.x.distance_to(second.basis.x) <= DEBUG_TRANSFORM_EPSILON
		and first.basis.y.distance_to(second.basis.y) <= DEBUG_TRANSFORM_EPSILON
		and first.basis.z.distance_to(second.basis.z) <= DEBUG_TRANSFORM_EPSILON
	)

func _capture_bone_rotations(skeleton: Skeleton3D, rules: Array[Dictionary]) -> Dictionary:
	var rotations: Dictionary = {}
	for rule: Dictionary in rules:
		var bone_name: StringName = rule.get("bone", StringName()) as StringName
		var bone_index: int = skeleton.find_bone(String(bone_name))
		if bone_index >= 0:
			rotations[bone_name] = skeleton.get_bone_pose_rotation(bone_index).normalized()
	return rotations

func _rotation_mismatches(before: Dictionary, after: Dictionary) -> PackedStringArray:
	var mismatches: PackedStringArray = []
	if before.size() != after.size():
		mismatches.append("size:%d->%d" % [before.size(), after.size()])
	for bone_name_variant: Variant in before.keys():
		var bone_name: StringName = bone_name_variant as StringName
		var before_rotation: Quaternion = before.get(bone_name, Quaternion.IDENTITY) as Quaternion
		var after_rotation: Quaternion = after.get(bone_name, Quaternion.IDENTITY) as Quaternion
		var distance: float = _quaternion_rotation_distance(before_rotation, after_rotation)
		if distance > ROTATION_EPSILON_RADIANS:
			mismatches.append("%s:%.9f" % [String(bone_name), distance])
	return mismatches

func _get_bone_world_transform(skeleton: Skeleton3D, bone_name: StringName) -> Transform3D:
	var bone_index: int = skeleton.find_bone(String(bone_name))
	if bone_index < 0:
		return Transform3D.IDENTITY
	return skeleton.global_transform * skeleton.get_bone_global_pose(bone_index)

func _transforms_match(a: Transform3D, b: Transform3D) -> bool:
	return a.origin.distance_to(b.origin) <= 0.000001 \
		and _quaternion_rotation_distance(
			a.basis.get_rotation_quaternion(),
			b.basis.get_rotation_quaternion()
		) <= ROTATION_EPSILON_RADIANS

func _quaternion_rotation_distance(a: Quaternion, b: Quaternion) -> float:
	var normalized_a: Quaternion = a.normalized()
	var normalized_b: Quaternion = b.normalized()
	var absolute_dot: float = clampf(absf(normalized_a.dot(normalized_b)), 0.0, 1.0)
	return 2.0 * acos(absolute_dot)

func _check(condition: bool, failure_name: String) -> void:
	if not condition:
		failures.append(failure_name)

func _finish(metrics: Dictionary) -> void:
	var lines: PackedStringArray = []
	for metric_key: Variant in metrics.keys():
		lines.append("%s=%s" % [String(metric_key), str(metrics.get(metric_key))])
	lines.append("failure_count=%d" % failures.size())
	for failure: String in failures:
		lines.append("failure=%s" % failure)
	lines.append("all_checks_passed=%s" % str(failures.is_empty()))
	var result_file: FileAccess = FileAccess.open(RESULT_FILE_PATH, FileAccess.WRITE)
	if result_file != null:
		result_file.store_string("\n".join(lines))
		result_file.close()
	quit(0 if failures.is_empty() else 1)
