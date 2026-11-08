extends "res://tools/verify_motion_native_performance.gd"

## Actual imported Idle rig. Mathematical acquired bindings stand in for
## already solved grips; this does not run or change finger acquisition.
## No library write or Save/F playback: accepted packet provenance and its
## exact bone-local reconstruction are checked directly.
const Origin = preload("res://core/models/combat_origin_record.gd")
const MotionMath = preload("res://core/resolvers/combat_motion_math_backend.gd")
const POMMEL_LOCAL := Vector3(0.12, -0.35, 0.08)
const TIP_LOCAL := Vector3(0.12, 0.65, 0.08)

func _initialize() -> void:
	output_dir = "C:/WORKSPACE/godot_runs/pommel_position_authority_20261108"
	super._initialize()
	commit_enabled = true

func _run() -> void:
	if ResourceLoader.exists(BACKEND_PATH):
		backend = load(BACKEND_PATH) as Script
		backend.call("configure_native", native_enabled)
		backend.call("configure_profiling", true)
	rig = RigScene.instantiate() as PlayerHumanoidRig
	root.add_child(rig)
	await process_frame
	await process_frame
	rig.set_authoring_preview_mode_enabled(true)
	rig.reset_authoring_preview_baseline_pose()
	rig.set_process(false)
	rig.set_physics_process(false)
	for tree: Node in rig.find_children("*", "AnimationTree", true, false):
		(tree as AnimationTree).active = false
	skeleton = rig.skeleton
	_check(skeleton != null, "actual_josie_skeleton_present")
	if skeleton == null:
		_finish()
		return
	fixture = _capture_fixture()
	var moved_root := Transform3D(Basis.from_euler(Vector3(0.2, -0.6, 0.1)) * Basis.from_scale(Vector3.ONE * 1.7), Vector3(2.0, 1.0, -3.0))
	for side: String in ["R", "L"]:
		var original := _single_hand(side, Transform3D.IDENTITY, "identity")
		var transformed := _single_hand(side, moved_root, "moved_root")
		if not original.is_empty() and not transformed.is_empty():
			_check((original.marker_rig_local as Vector3).distance_to(transformed.marker_rig_local) <= 0.0001,
				side + "_same_task_after_root_rotation_translation_scale",
				{"error_m": (original.marker_rig_local as Vector3).distance_to(transformed.marker_rig_local)})
		_tip_forearm_sentinel(side)
	_shared_hands()
	_finish()

func _request_for(prop: Node3D, slot: StringName, bindings: Dictionary, target: Transform3D, support: StringName = StringName()) -> Dictionary:
	return {"mode": "pommel", "weapon": prop, "primary_slot": slot, "support_slot": support,
		"previous_weapon": prop.global_transform, "target_weapon": target,
		"contact_local": (bindings[slot] as Transform3D).origin, "task_point_local": POMMEL_LOCAL, "trailing_tip_local": TIP_LOCAL,
		"hand_in_weapon_by_slot": bindings, "commit": true,
		"policy": {"forearm_clearance_enabled": clearance_enabled, "cached_storage_readback": cached_storage}}

func _single_hand(side: String, root_transform: Transform3D, suffix: String) -> Dictionary:
	_restore_fixture()
	rig.global_transform = root_transform * (fixture.rig_world as Transform3D)
	skeleton.force_update_all_bone_transforms()
	var slot := &"hand_right" if side == "R" else &"hand_left"
	var label := side + "_" + suffix
	var hand := _bone_world("CC_Base_" + side + "_Hand")
	var prop := Node3D.new()
	root.add_child(prop)
	prop.global_transform = hand * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.08, 0.0))
	var binding := prop.global_transform.affine_inverse() * hand
	var bindings: Dictionary = {slot: binding}
	var inspector := Adapter.new()
	var initialized: Dictionary = inspector._initialize(rig, _request_for(prop, slot, bindings, prop.global_transform))
	_check(bool(initialized.get("valid", false)), label + "_cold_idle_initializes", initialized)
	if not initialized.get("valid", false):
		prop.free()
		return {}
	var endpoint := _reachable_endpoint(inspector)
	_check(not endpoint.is_empty(), label + "_known_reachable_significant_landmark_target")
	if endpoint.is_empty():
		prop.free()
		return {}
	var previous := prop.global_transform
	var initial_marker := previous * POMMEL_LOCAL
	var desired_marker: Vector3 = endpoint.weapon_frame * POMMEL_LOCAL
	var target := previous
	target.origin = desired_marker - previous.basis * POMMEL_LOCAL
	var request := _request_for(prop, slot, bindings, target)
	var opposite := _opposite_arm_world_poses(slot)
	var before_gamma: float = inspector.q[inspector.arms[0].wrist_q + 2]
	var before_rho: float = inspector.q[inspector.arms[0].wrist_q]
	_check(inspector.lower[inspector.arms[0].wrist_q] == before_rho and inspector.upper[inspector.arms[0].wrist_q] == before_rho, label + "_pommel_forearm_coordinate_is_fixed")
	var counterfactual: Dictionary = {}
	if suffix == "identity":
		var without_trailing := request.duplicate(true)
		without_trailing.erase("trailing_tip_local")
		without_trailing.commit = false
		var no_preference: Dictionary = Adapter.new().allocate(rig, without_trailing)
		var no_preference_frame: Transform3D = no_preference.get("accepted_weapon", previous)
		counterfactual = {"valid": no_preference.get("valid", false), "task_scale": no_preference.get("task_scale"),
			"tip_travel_m": (no_preference_frame * TIP_LOCAL).distance_to(previous * TIP_LOCAL)}
	var adapter := Adapter.new()
	var started := Time.get_ticks_usec()
	var result: Dictionary = adapter.allocate(rig, request)
	var elapsed := float(Time.get_ticks_usec() - started) / 1000.0
	var actual_marker := prop.global_transform * POMMEL_LOCAL
	var marker_error := actual_marker.distance_to(desired_marker)
	_check(bool(result.get("valid", false)) and marker_error <= 0.00005, label + "_actual_pommel_reaches_pointer",
		{"error_m": marker_error, "status": result.get("status"), "scale": result.get("task_scale")})
	_check(actual_marker.distance_to(initial_marker) >= 0.01, label + "_significant_marker_motion",
		{"travel_m": actual_marker.distance_to(initial_marker)})
	_check(not bool(result.get("orientation_constrained", true)), label + "_orientation_not_a_task_constraint")
	_check_committed_contact(label, slot, prop, binding, opposite)
	var wrist_after: Dictionary = rig.capture_wrist_motion_start_state(slot)
	_check(bool(wrist_after.get("valid", false)) and absf(float(wrist_after.get("state", {}).get("gamma", INF)) - before_gamma) <= deg_to_rad(0.025), label + "_explicit_wrist_z_is_held")
	_check(bool(wrist_after.get("valid", false)) and absf(float(wrist_after.get("state", {}).get("rho", INF)) - before_rho) <= deg_to_rad(0.025), label + "_forearm_roll_is_held")
	var accepted := PackedFloat64Array(result.get("accepted_q", adapter.q))
	var evaluation: Dictionary = adapter._evaluate_kinematics(accepted)
	_check(Allocator._legal(accepted, Allocator.apply_start_allowance(evaluation, adapter.start_allowance), adapter.start_allowance.lower, adapter.start_allowance.upper), label + "_existing_anatomy_and_start_allowance_preserved")
	_check_packet(label, result, slot, binding, actual_marker)
	var compact := result.duplicate()
	for key: String in ["motion_adapter", "accepted_payload", "accepted_pose"]:
		compact.erase(key)
	var record := {"id": label, "elapsed_ms": elapsed, "result": compact,
		"requested_marker_world": desired_marker, "actual_marker_world": actual_marker,
		"marker_error_m": marker_error, "root_marker_displacement_difference_m": (prop.global_position - previous.origin).distance_to(actual_marker - initial_marker),
		"weapon_orientation_change_degrees": rad_to_deg(_angle(prop.global_basis, previous.basis)),
		"tip_travel_m": (prop.global_transform * TIP_LOCAL).distance_to(previous * TIP_LOCAL), "without_trailing_same_start": counterfactual,
		"forearm_rho_before": before_rho, "forearm_rho_after": wrist_after.get("state", {}).get("rho"),
		"marker_rig_local": rig.global_transform.affine_inverse() * actual_marker, "timings": adapter._timing_result()}
	records.append(record)
	print("POMMEL_AUTHORITY %s error_um=%.3f rotation_deg=%.3f elapsed_ms=%.3f" % [label, marker_error * 1000000.0, record.weapon_orientation_change_degrees, elapsed])
	prop.free()
	return record

func _reachable_endpoint(adapter: RefCounted) -> Dictionary:
	var arm: Dictionary = adapter.arms[0]
	var initial: Vector3 = adapter.previous_weapon * POMMEL_LOCAL
	# Targets are produced by actual FK using existing permitted wrist-X and
	# elbow coordinates, with Z unchanged. This proves endpoint feasibility;
	# the allocator is free to use a different legal coordinated pose.
	for channel: int in [int(arm.wrist_q) + 1, int(arm.elbow_q)]:
		for amount: float in [10.0, -10.0, 6.0, -6.0]:
			var values: PackedFloat64Array = adapter.q.duplicate()
			values[channel] += deg_to_rad(amount)
			var evaluation: Dictionary = adapter._evaluate_kinematics(values)
			if Allocator._legal(values, Allocator.apply_start_allowance(evaluation, adapter.start_allowance), adapter.start_allowance.lower, adapter.start_allowance.upper):
				var marker: Vector3 = evaluation.weapon_frame * POMMEL_LOCAL
				if initial.distance_to(marker) >= 0.01:
					return {"weapon_frame": evaluation.weapon_frame, "q": values}
	return {}

func _shared_hands() -> void:
	_restore_fixture()
	var prop := Node3D.new()
	root.add_child(prop)
	prop.global_transform = _bone_world("CC_Base_R_Hand") * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.08, 0.0))
	var bindings: Dictionary = {}
	var initial_hands: Dictionary = {}
	var gamma_before: Dictionary = {}
	var rho_before: Dictionary = {}
	for side: String in ["R", "L"]:
		var slot := &"hand_right" if side == "R" else &"hand_left"
		var hand := _bone_world("CC_Base_" + side + "_Hand")
		bindings[slot] = prop.global_transform.affine_inverse() * hand
		initial_hands[slot] = hand
		gamma_before[slot] = rig.capture_wrist_motion_start_state(slot).state.gamma
		rho_before[slot] = rig.capture_wrist_motion_start_state(slot).state.rho
	var initial_marker := prop.global_transform * POMMEL_LOCAL
	var target := prop.global_transform
	target.origin += rig.global_basis.y.normalized() * 0.005
	var adapter := Adapter.new()
	var started := Time.get_ticks_usec()
	var result: Dictionary = adapter.allocate(rig, _request_for(prop, &"hand_right", bindings, target, &"hand_left"))
	var elapsed := float(Time.get_ticks_usec() - started) / 1000.0
	_check(bool(result.get("valid", false)) and (prop.global_transform * POMMEL_LOCAL).distance_to(initial_marker) > 0.0005, "shared_both_hands_make_real_progress", {"status": result.get("status"), "reason": result.get("reason"), "scale": result.get("task_scale")})
	for side: String in ["R", "L"]:
		var slot := &"hand_right" if side == "R" else &"hand_left"
		var actual := _bone_world("CC_Base_" + side + "_Hand")
		var expected: Transform3D = prop.global_transform * bindings[slot]
		_check(actual.origin.distance_to(expected.origin) <= 0.00005 and _angle(actual.basis, expected.basis) <= deg_to_rad(0.025), "shared_" + side + "_acquired_contact_is_unchanged")
		_check(actual.origin.distance_to((initial_hands[slot] as Transform3D).origin) > 0.0001, "shared_" + side + "_hand_actually_moves")
		var measured: Dictionary = rig.capture_wrist_motion_start_state(slot)
		_check(bool(measured.get("valid", false)) and absf(float(measured.get("state", {}).get("gamma", INF)) - float(gamma_before[slot])) <= deg_to_rad(0.025), "shared_" + side + "_wrist_z_held")
		_check(bool(measured.get("valid", false)) and absf(float(measured.get("state", {}).get("rho", INF)) - float(rho_before[slot])) <= deg_to_rad(0.025), "shared_" + side + "_forearm_roll_held")
	var compact := result.duplicate()
	for key: String in ["motion_adapter", "accepted_payload", "accepted_pose"]:
		compact.erase(key)
	records.append({"id": "shared_hands", "elapsed_ms": elapsed, "result": compact, "timings": adapter._timing_result()})
	prop.free()

func _tip_forearm_sentinel(side: String) -> void:
	_restore_fixture()
	var slot := &"hand_right" if side == "R" else &"hand_left"
	var prop := Node3D.new()
	root.add_child(prop)
	var hand := _bone_world("CC_Base_" + side + "_Hand")
	prop.global_transform = hand * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.08, 0.0))
	var binding := prop.global_transform.affine_inverse() * hand
	var request := _request_for(prop, slot, {slot: binding}, prop.global_transform)
	request.mode = "tip"
	var inspector := Adapter.new()
	var initialized: Dictionary = inspector._initialize(rig, request)
	_check(bool(initialized.get("valid", false)), side + "_tip_forearm_sentinel_initializes", initialized)
	if not initialized.get("valid", false):
		prop.free()
		return
	var wrist_index: int = inspector.arms[0].wrist_q
	var initial_rho: float = inspector.q[wrist_index]
	var endpoint: Dictionary = {}
	for degrees: float in [6.0, -6.0]:
		var values: PackedFloat64Array = inspector.q.duplicate()
		values[wrist_index] += deg_to_rad(degrees)
		var candidate: Dictionary = inspector._evaluate_kinematics(values)
		if Allocator._legal(values, Allocator.apply_start_allowance(candidate, inspector.start_allowance), inspector.start_allowance.lower, inspector.start_allowance.upper):
			endpoint = candidate
			break
	_check(not endpoint.is_empty(), side + "_significant_legal_forearm_tip_target_exists")
	if endpoint.is_empty():
		prop.free()
		return
	request.target_weapon = endpoint.weapon_frame
	var opposite := _opposite_arm_world_poses(slot)
	var adapter := Adapter.new()
	var result: Dictionary = adapter.allocate(rig, request)
	var measured: Dictionary = rig.capture_wrist_motion_start_state(slot)
	var change: float = absf(float(measured.get("state", {}).get("rho", initial_rho)) - initial_rho)
	_check(bool(result.get("valid", false)) and change > deg_to_rad(1.0), side + "_tip_actually_uses_forearm_roll", {"rho_change_degrees": rad_to_deg(change), "status": result.get("status")})
	_check_committed_contact(side + "_tip_sentinel", slot, prop, binding, opposite)
	prop.free()

func _check_packet(label: String, result: Dictionary, slot: StringName, binding: Transform3D, expected_marker: Vector3) -> void:
	var packet: Dictionary = result.get("accepted_pose", {})
	var names: Array = packet.get("bone_names", [])
	var count := skeleton.get_bone_count()
	var complete: bool = names.size() == count and packet.get("pose_positions", []).size() == count and packet.get("pose_rotations", []).size() == count and packet.get("pose_scales", []).size() == count
	_check(complete and packet.get("origin_id") == Origin.ORIGIN_SOLVED_REPLAY_REFERENCE and names == _bone_names() and names.has(Origin.ORIGIN_RL_BONE_ROOT), label + "_complete_named_parent_local_packet")
	if not complete:
		return
	var poses: Array[Transform3D] = []
	var parent_indices := PackedInt32Array()
	for index: int in count:
		var rotation: Vector4 = packet.pose_rotations[index]
		poses.append(Transform3D(Basis(Quaternion(rotation.x, rotation.y, rotation.z, rotation.w)) * Basis.from_scale(packet.pose_scales[index]), packet.pose_positions[index]))
		parent_indices.append(skeleton.get_bone_parent(index))
	var globals: Array[Transform3D] = MotionMath.forward(poses, parent_indices)
	var hand_id := skeleton.find_bone("CC_Base_R_Hand" if slot == &"hand_right" else "CC_Base_L_Hand")
	var reconstructed_weapon: Transform3D = skeleton.global_transform * globals[hand_id] * binding.affine_inverse()
	_check((reconstructed_weapon * POMMEL_LOCAL).distance_to(expected_marker) <= 0.00005, label + "_stored_packet_reconstructs_same_pommel_in_root_chain")
