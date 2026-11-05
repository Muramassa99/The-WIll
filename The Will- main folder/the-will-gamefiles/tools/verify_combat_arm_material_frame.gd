extends SceneTree

## Focused production material-frame regression. No station/library, grip, IK,
## anatomical ROM certification or performance claims. Fixture snapshots use
## actual imported offsets; synthetic poses are deliberately labelled below.
const RigScene = preload("res://scenes/player/player_humanoid_rig.tscn")
const Hinge = preload("res://core/resolvers/combat_arm_hinge_frame_resolver.gd")
const PreparedArm = preload("res://core/resolvers/combat_prepared_arm_frame_resolver.gd")
const TrackBuilder = preload("res://core/resolvers/combat_prepared_pose_track_builder.gd")
const Entry = preload("res://runtime/combat/combat_runtime_entry_transition.gd")
const Baker = preload("res://core/resolvers/combat_runtime_clip_baker.gd")
const MotionNode = preload("res://core/models/combat_animation_motion_node.gd")
const Clip = preload("res://core/models/combat_runtime_clip.gd")
const PreparedPose = preload("res://core/models/combat_prepared_pose.gd")
const ANGLE_EPSILON_DEGREES := 0.05
const POSITION_EPSILON_METERS := 0.00005

var out_dir := "C:/WORKSPACE/godot_runs/combat_arm_material_frame"
var checks: Array[Dictionary] = []
var samples: Array[Dictionary] = []
var calibrations: Dictionary = {}
var rig: PlayerHumanoidRig
var skeleton: Skeleton3D
var rest_poses: Array[Transform3D] = []


func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for index: int in args.size():
		if args[index].begins_with("--out-dir="):
			out_dir = args[index].trim_prefix("--out-dir=")
		elif args[index] == "--out-dir" and index + 1 < args.size():
			out_dir = args[index + 1]
	call_deferred("_run")


func _run() -> void:
	var actor_parent := Node3D.new()
	root.add_child(actor_parent)
	rig = RigScene.instantiate() as PlayerHumanoidRig
	actor_parent.add_child(rig)
	await process_frame
	await process_frame
	rig.set_authoring_preview_mode_enabled(true)
	rig.set_process(false)
	rig.set_physics_process(false)
	skeleton = rig.get_node("JosieModel/Josie/Skeleton3D") as Skeleton3D
	for tree: Node in rig.find_children("*", "AnimationTree", true, false):
		(tree as AnimationTree).active = false
	skeleton.reset_bone_poses()
	skeleton.force_update_all_bone_transforms()
	for index: int in skeleton.get_bone_count():
		rest_poses.append(skeleton.get_bone_pose(index))
	for side: String in ["R", "L"]:
		var ids: Array[int] = _indices(side)
		var calibration: Dictionary = Hinge.calibration(skeleton.get_bone_rest(ids[2]), skeleton.get_bone_rest(ids[3]))
		_record_calibration(side, ids, calibration)
		_check(calibration.get("valid", false), side + "_real_imported_rest_calibrates", calibration)
		if not calibration.get("valid", false):
			continue
		for root_case: int in 3:
			actor_parent.transform = Transform3D(Basis.from_euler(Vector3(0.31, -0.57, 0.22)), Vector3(2.0, 1.0, -3.0)) if root_case > 0 else Transform3D.IDENTITY
			rig.transform = Transform3D(Basis.from_euler(Vector3(-0.2, 0.42, 0.17)).scaled(Vector3.ONE * (0.75 if root_case == 1 else 1.4)), Vector3(-0.4, 0.2, 0.3)) if root_case > 0 else Transform3D.IDENTITY
			_exercise_orbit(side, root_case)
		actor_parent.transform = Transform3D.IDENTITY
		rig.transform = Transform3D.IDENTITY
		_exercise_replay(side)
		_exercise_partial_payload(side)
		_exercise_stored_tracks(side)
	_exercise_invalid_and_straight()
	var passed := true
	for check: Dictionary in checks:
		passed = passed and bool(check.passed)
	DirAccess.make_dir_recursive_absolute(out_dir)
	var file := FileAccess.open(out_dir.path_join("report.json"), FileAccess.WRITE)
	if file == null:
		push_error("Cannot write material-frame report")
		quit(1)
		return
	file.store_string(JSON.stringify({"passed": passed, "checks": checks, "samples": samples, "engine_calibrations": calibrations,
		"scope": "Real imported L/R rig material frame, endpoint preservation, root transforms/scales, historical pure-swing counterexample, prepared frame operation and actual solved replay writer. Synthetic interpolation is a constructed regression, not a reproduction of every reported body fault."}, "\t"))
	file.close()
	print("COMBAT_ARM_MATERIAL_FRAME passed=%s checks=%d output=%s" % [passed, checks.size(), out_dir])
	quit(0 if passed else 1)


func _exercise_orbit(side: String, root_case: int) -> void:
	var ids: Array[int] = _indices(side)
	for degrees: float in [-60.0, -25.0, 35.0, 60.0]:
		_restore_rest()
		var before: Array[Transform3D] = _frames(ids)
		var orbit := Basis((before[3].origin - before[1].origin).normalized(), deg_to_rad(degrees))
		_set_global_basis(ids[1], orbit * before[1].basis)
		_set_global_basis(ids[2], orbit * before[2].basis)
		_set_global_basis(ids[3], before[3].basis)
		# The historical operation intentionally appears only in this fixture.
		# It strips main-bone roll while preserving the solved Forearm frame.
		_apply_historical_pure_swing(ids)
		var label := "%s_root%d_orbit%.0f" % [side, root_case, degrees]
		var error_before := _material_error(ids)
		var saved: Array[Transform3D] = _world_frames(ids)
		var old_helpers := _helper_rotations(side)
		var packet := _snapshot()
		var indices: Array[int] = ids.duplicate()
		var prepared_rotations: PackedVector4Array = packet.pose_rotations.duplicate()
		PreparedArm._enforce_material_hinge_frame(packet, prepared_rotations, indices)
		var fk: Dictionary = PreparedArm.forward_kinematics(packet, prepared_rotations)
		_check(fk.get("valid", false), label + "_prepared_fk_valid")
		_apply_live(side)
		var live: Array[Transform3D] = _frames(ids)
		var after: Array[Transform3D] = _world_frames(ids)
		var error_after := _material_error(ids)
		_check(error_before > 1.0, label + "_historical_mismatch_exposed", {"angle_degrees": error_before})
		_check(error_after < ANGLE_EPSILON_DEGREES, label + "_material_hinge_matches_bend", {"angle_degrees": error_after})
		_check(_position_delta(saved, after) < POSITION_EPSILON_METERS, label + "_world_joint_centers_preserved", {"max_m": _position_delta(saved, after)})
		_check(_basis_error(saved[3].basis, after[3].basis) < ANGLE_EPSILON_DEGREES, label + "_hand_orientation_preserved")
		_check(_basis_error(saved[2].basis, after[2].basis) < ANGLE_EPSILON_DEGREES, label + "_forearm_orientation_preserved")
		_check(old_helpers == _helper_rotations(side), label + "_helper_local_rotations_untouched")
		if fk.get("valid", false):
			var prepared: Array = fk.transforms
			_check(_basis_error(live[1].basis, prepared[ids[1]].basis) < ANGLE_EPSILON_DEGREES, label + "_live_prepared_material_parity")
			_check(prepared[ids[3]].origin.distance_to(live[3].origin) < POSITION_EPSILON_METERS, label + "_live_prepared_hand_parity")
		_apply_live(side)
		_check(_basis_error(live[1].basis, skeleton.get_bone_global_pose(ids[1]).basis) < ANGLE_EPSILON_DEGREES, label + "_idempotent")
		samples.append({"case": label, "old_material_error_degrees": error_before, "new_material_error_degrees": error_after, "position_drift_m": _position_delta(saved, after)})


func _exercise_replay(side: String) -> void:
	var ids: Array[int] = _indices(side)
	_seed_semantic_pose(side, 20.0, -80.0)
	var a := _snapshot()
	_seed_semantic_pose(side, 120.0, 80.0)
	var b := _snapshot()
	for ratio: float in [0.25, 0.5, 0.75]:
		var rotations: Array = []
		for index: int in a.pose_rotations.size():
			rotations.append(_quaternion(a.pose_rotations[index]).slerp(_quaternion(b.pose_rotations[index]), ratio).normalized())
		# Observe the raw authored interpolation before the production replay
		# boundary restores the material frame. No solver or grip is invoked.
		_restore_rest()
		for index: int in rotations.size():
			skeleton.set_bone_pose_rotation(index, rotations[index])
		skeleton.force_update_all_bone_transforms()
		var before: Array[Transform3D] = _world_frames(ids)
		var raw_error := _material_error(ids)
		var label := "%s_replay_%.2f" % [side, ratio]
		var applied := rig.apply_runtime_solved_upper_body_pose_frame(a.bone_names, Array(a.pose_positions), rotations, Array(a.pose_scales), 1.0)
		var after: Array[Transform3D] = _world_frames(ids)
		_check(applied, label + "_actual_solved_writer_applied")
		_check(raw_error > 1.0, label + "_slerp_is_not_hinge_closed", {"angle_degrees": raw_error})
		_check(_material_error(ids) < ANGLE_EPSILON_DEGREES, label + "_replay_material_frame_normalized", {"angle_degrees": _material_error(ids)})
		_check(_position_delta(before, after) < POSITION_EPSILON_METERS, label + "_replay_joint_centers_preserved")
		_check(_basis_error(before[3].basis, after[3].basis) < ANGLE_EPSILON_DEGREES, label + "_replay_hand_orientation_preserved")
		rig.process_runtime_solved_replay_modifier_frame()
		_check(_position_delta(after, _world_frames(ids)) < POSITION_EPSILON_METERS, label + "_modifier_reapply_stable")
		rig.clear_runtime_solved_replay_pose_frame()


func _seed_semantic_pose(side: String, flexion_degrees: float, roll_degrees: float) -> void:
	_restore_rest()
	var ids: Array[int] = _indices(side)
	var frames: Array[Transform3D] = _frames(ids)
	var u: Vector3 = (frames[2].origin - frames[1].origin).normalized()
	var v: Vector3 = (frames[3].origin - frames[2].origin).normalized()
	var h: Vector3 = u.cross(v).normalized()
	var upper_material := Basis(h, u, h.cross(u))
	var forearm_material_local: Basis = frames[2].basis.orthonormalized().inverse() * Basis(h, v, h.cross(v))
	var desired_forearm: Basis = upper_material * Basis(Vector3.RIGHT, deg_to_rad(flexion_degrees)) * Basis(Vector3.UP, deg_to_rad(roll_degrees)) * forearm_material_local.inverse()
	_set_global_basis(ids[2], desired_forearm)
	_set_global_basis(ids[3], frames[3].basis)
	_check(_material_error(ids) < ANGLE_EPSILON_DEGREES, "%s_synthetic_endpoint_%.0f_is_hinge_valid" % [side, flexion_degrees])


func _exercise_partial_payload(side: String) -> void:
	var ids: Array[int] = _indices(side)
	for mode: String in ["hand_only", "truncated", "invalid_forearm", "legacy_truncated"]:
		_seed_semantic_pose(side, 70.0, 30.0)
		var seeded: Array[Transform3D] = _frames(ids)
		_set_global_basis(ids[2], Basis((seeded[2].origin - seeded[1].origin).normalized(), deg_to_rad(45.0)) * seeded[2].basis)
		_apply_historical_pure_swing(ids)
		_check(_material_error(ids) > 1.0, "%s_%s_partial_fixture_needs_normalization" % [side, mode])
		var before: Array[Transform3D] = _frames(ids)
		var names: Array = []
		var positions: Array = []
		var rotations: Array = []
		var scales: Array = []
		for index: int in ids:
			names.append(StringName(skeleton.get_bone_name(index)))
			positions.append(skeleton.get_bone_pose_position(index))
			rotations.append(skeleton.get_bone_pose_rotation(index))
			scales.append(skeleton.get_bone_pose_scale(index))
		if mode == "hand_only":
			names = [names[3]]
			positions = [positions[3]]
			rotations = [rotations[3]]
			scales = [scales[3]]
		elif mode == "invalid_forearm":
			rotations[2] = Quaternion(NAN, 0.0, 0.0, 1.0)
		else:
			rotations.pop_back()
		if mode == "legacy_truncated":
			rig.apply_runtime_upper_body_pose_frame(names, rotations)
		else:
			rig.apply_runtime_solved_upper_body_pose_frame(names, positions, rotations, scales)
		_check(_basis_error(before[1].basis, skeleton.get_bone_global_pose(ids[1]).basis) < ANGLE_EPSILON_DEGREES,
			"%s_%s_does_not_normalize_incomplete_arm" % [side, mode])
		rig.clear_runtime_solved_replay_pose_frame()


func _exercise_invalid_and_straight() -> void:
	var zero := Hinge.calibration(Transform3D.IDENTITY, Transform3D.IDENTITY)
	_check(not zero.get("valid", true) and zero.get("reason") == "degenerate_arm_rest_segment", "reject_zero_length_calibration")
	var straight := Hinge.calibration(Transform3D(Basis.IDENTITY, Vector3.UP), Transform3D(Basis.IDENTITY, Vector3.UP))
	_check(not straight.get("valid", true) and straight.get("reason") == "arm_rest_needs_bent_calibration", "straight_rest_requires_explicit_calibration")
	var bad := Transform3D.IDENTITY
	bad.origin.x = NAN
	_check(not Hinge.calibration(bad, Transform3D.IDENTITY).get("valid", true), "reject_nonfinite_calibration")
	for side: String in ["R", "L"]:
		_restore_rest()
		var ids: Array[int] = _indices(side)
		var frames: Array[Transform3D] = _frames(ids)
		var shaft: Vector3 = (frames[2].origin - frames[1].origin).normalized()
		frames[3].origin = frames[2].origin + shaft * frames[2].origin.distance_to(frames[3].origin)
		var solved: Dictionary = Hinge.resolve(frames[1], frames[2], frames[3], skeleton.get_bone_rest(ids[2]), skeleton.get_bone_rest(ids[3]))
		_check(solved.get("valid", false) and solved.get("underdetermined_bend", false), side + "_straight_pose_retains_material_reference")
		if solved.get("valid", false):
			_check(_basis_error(frames[1].basis, solved.upperarm_basis) < ANGLE_EPSILON_DEGREES, side + "_straight_pose_does_not_invent_roll")


func _exercise_stored_tracks(side: String) -> void:
	_seed_semantic_pose(side, 20.0, -80.0)
	var a: Dictionary = _storage_snapshot(side)
	_seed_semantic_pose(side, 120.0, 80.0)
	var b: Dictionary = _storage_snapshot(side)
	var sampled: Dictionary = TrackBuilder.sample_pose(a, b, 0.5)
	var mid: Dictionary = a.duplicate(true)
	for field: String in ["pose_positions", "pose_rotations", "pose_scales", "parent_reference_transforms"]:
		mid[field] = sampled[field]
	var before: PackedByteArray = var_to_bytes(mid)
	var normalized: Dictionary = PreparedArm.normalize_material_frames(mid)
	_check(normalized.get("valid", false), side + "_shared_storage_normalizer_valid")
	_check(var_to_bytes(mid) == before, side + "_shared_storage_input_immutable")
	if not normalized.get("valid", false):
		return
	_check(normalized.diagnostics.checked_slots.size() == 2 and normalized.diagnostics.ik_calls == 0 and normalized.diagnostics.acquisition_calls == 0, side + "_shared_storage_both_arms_no_ik_or_grip")
	_check(normalized.diagnostics.changed, side + "_shared_storage_corrects_interpolated_frame")
	mid.pose_rotations = normalized.pose_rotations
	var repeated: Dictionary = PreparedArm.normalize_material_frames(mid)
	_check(repeated.get("valid", false) and not repeated.diagnostics.changed, side + "_shared_storage_idempotent")
	var node_a: Resource = _storage_node(1)
	var node_b: Resource = _storage_node(2)
	var controls: Resource = Baker.new().bake_from_motion_node_chain([node_a, node_b], {"sample_rate_hz": 60.0, "source_weapon_length_meters": 1.0})
	var snapshots: Array[Dictionary] = [a, b]
	var built: Dictionary = TrackBuilder.build(controls, snapshots)
	_check(built.get("valid", false), side + "_actual_track_builder_valid", {"reason": built.get("reason", "")})
	if not built.get("valid", false):
		return
	_check(built.diagnostics.material_frame_corrected_samples > 0 and built.diagnostics.ik_calls == 0 and built.diagnostics.acquisition_calls == 0, side + "_track_stores_correction_without_solve")
	_assert_stored_track(built.clip, a, side + "_body")
	var combined: Resource = Entry.build(built.clip, b, node_b)
	_check(combined != null, side + "_actual_entry_builder_valid")
	if combined == null:
		return
	var entry_metrics: Dictionary = combined.get_meta("entry_attachment_diagnostics", {})
	var corrected := false
	for row: Dictionary in entry_metrics.get("frames", []):
		corrected = corrected or bool(row.get("material_frames", {}).get("changed", false))
	_check(corrected and entry_metrics.get("arm_follow_calls", -1) == 0 and entry_metrics.get("acquisition_calls", -1) == 0, side + "_entry_stores_correction_without_solve")
	_assert_stored_track(combined, a, side + "_entry_and_body")


func _assert_stored_track(clip: Resource, layout: Dictionary, label: String) -> void:
	var max_material := 0.0
	var max_replay_delta := 0.0
	var all_idempotent := true
	for frame: int in clip.get_frame_count():
		var pose: Dictionary = layout.duplicate()
		pose.pose_positions = clip.baked_solved_upper_body_pose_positions[frame]
		pose.pose_rotations = clip.baked_solved_upper_body_pose_rotations[frame]
		pose.pose_scales = clip.baked_solved_upper_body_pose_scales[frame]
		var canonical: Dictionary = PreparedArm.normalize_material_frames(pose)
		all_idempotent = all_idempotent and canonical.get("valid", false) and not canonical.get("diagnostics", {}).get("changed", true)
		rig.apply_runtime_solved_upper_body_pose_frame(pose.bone_names, Array(pose.pose_positions), Array(pose.pose_rotations), Array(pose.pose_scales))
		for index: int in pose.bone_names.size():
			max_replay_delta = maxf(max_replay_delta, _basis_error(Basis(_quaternion(pose.pose_rotations[index])), Basis(skeleton.get_bone_pose_rotation(index))))
		for side: String in ["R", "L"]:
			max_material = maxf(max_material, _material_error(_indices(side)))
		rig.clear_runtime_solved_replay_pose_frame()
	_check(all_idempotent, label + "_stored_samples_already_canonical")
	_check(max_replay_delta < ANGLE_EPSILON_DEGREES, label + "_stored_samples_match_final_rig", {"max_angle_degrees": max_replay_delta})
	_check(max_material < ANGLE_EPSILON_DEGREES, label + "_both_arms_match_material_plane", {"max_angle_degrees": max_material})


func _storage_snapshot(side: String) -> Dictionary:
	var pose: Dictionary = _snapshot()
	var defaults: Resource = Clip.new()
	pose.merge({"valid": true, "schema_version": PreparedPose.SCHEMA_VERSION, "attachment_required": false,
		"context_signature": "material_frame_real_rig_synthetic_unarmed", "primary_hand_bone_name": StringName("CC_Base_%s_Hand" % side),
		"primary_hand_slot": _slot(side), "primary_hand_in_weapon": Transform3D.IDENTITY, "support_enabled": false,
		"weapon_position_reference_local": Vector3.ZERO, "weapon_rotation_reference_local": Quaternion.IDENTITY, "weapon_scale_reference_local": Vector3.ONE,
		"reference_bone_name": defaults.solved_replay_reference_bone_name, "reference_origin_id": defaults.solved_replay_reference_origin_id,
		"weapon_reference_origin_id": defaults.baked_solved_weapon_reference_origin_id, "anchor_origin_id": defaults.baked_solved_anchor_origin_id,
		"anchor_node_paths": [], "anchor_positions_weapon_local": PackedVector3Array(), "anchor_rotations_weapon_local": PackedVector4Array(), "anchor_scales_weapon_local": PackedVector3Array(),
		"trajectory_to_reference": Transform3D.IDENTITY, "weapon_tip_local": Vector3(0.0, 0.0, 0.5), "weapon_pommel_local": Vector3(0.0, 0.0, -0.5),
		"arm_constraints_by_slot": {}}, true)
	for arm: String in ["R", "L"]:
		var packet := {}
		for role: String in ["Clavicle", "Upperarm", "Forearm", "Hand"]:
			packet[role.to_lower() + "_bone"] = StringName("CC_Base_%s_%s" % [arm, role])
		pose.arm_constraints_by_slot[_slot(arm)] = packet
	return pose


func _storage_node(index: int) -> Resource:
	var node: Resource = MotionNode.new()
	node.node_id = StringName("material_storage_%d" % index)
	node.node_index = index
	node.tip_position_local = Vector3(0.0, 0.0, 0.5)
	node.pommel_position_local = Vector3(0.0, 0.0, -0.5)
	node.transition_duration_seconds = 0.2
	node.normalize()
	return node


func _record_calibration(side: String, ids: Array[int], calibration: Dictionary) -> void:
	var row := {"basis_layout": "columns x,y,z; transforms multiply column vectors", "valid": calibration.get("valid", false), "bones": {}}
	for index: int in ids:
		var local_rest: Transform3D = skeleton.get_bone_rest(index)
		var global_rest: Transform3D = skeleton.get_bone_global_rest(index)
		row.bones[skeleton.get_bone_name(index)] = {"parent_index": skeleton.get_bone_parent(index),
			"local_rest_origin_xyz": _vector_array(local_rest.origin), "local_rest_basis_columns_xyz": _basis_arrays(local_rest.basis),
			"skeleton_rest_origin_xyz": _vector_array(global_rest.origin), "skeleton_rest_basis_columns_xyz": _basis_arrays(global_rest.basis)}
	if calibration.get("valid", false):
		var frame: Basis = calibration.frame_in_upperarm
		row["hinge_in_upperarm_xyz"] = _vector_array(frame.x)
		row["shaft_in_upperarm_xyz"] = _vector_array(frame.y)
		row["material_basis_columns_xyz"] = _basis_arrays(frame)
	calibrations[side] = row


func _vector_array(value: Vector3) -> Array:
	return [value.x, value.y, value.z]


func _basis_arrays(value: Basis) -> Array:
	return [_vector_array(value.x), _vector_array(value.y), _vector_array(value.z)]


func _snapshot() -> Dictionary:
	var packet := {"bone_names": [], "pose_positions": PackedVector3Array(), "pose_rotations": PackedVector4Array(), "pose_scales": PackedVector3Array(), "parent_indices": PackedInt32Array(), "parent_reference_transforms": [], "bone_rest_transforms": []}
	for index: int in skeleton.get_bone_count():
		var q: Quaternion = skeleton.get_bone_pose_rotation(index).normalized()
		packet.bone_names.append(StringName(skeleton.get_bone_name(index)))
		packet.pose_positions.append(skeleton.get_bone_pose_position(index))
		packet.pose_rotations.append(Vector4(q.x, q.y, q.z, q.w))
		packet.pose_scales.append(skeleton.get_bone_pose_scale(index))
		packet.parent_indices.append(skeleton.get_bone_parent(index))
		packet.parent_reference_transforms.append(Transform3D.IDENTITY)
		packet.bone_rest_transforms.append(skeleton.get_bone_rest(index))
	return packet


func _apply_historical_pure_swing(ids: Array[int]) -> void:
	var frames: Array[Transform3D] = _frames(ids)
	var rest: Basis = skeleton.get_bone_rest(ids[1]).basis.orthonormalized()
	var direction: Vector3 = (rest.inverse() * frames[0].basis.orthonormalized().inverse() * (frames[2].origin - frames[1].origin).normalized()).normalized()
	var swing := Quaternion(Vector3.UP, direction)
	_set_global_basis(ids[1], frames[0].basis.orthonormalized() * rest * Basis(swing))
	_set_global_basis(ids[2], frames[2].basis)


func _apply_live(side: String) -> void:
	rig.call("_enforce_authoring_upperarm_swing_authority", _slot(side), StringName("CC_Base_%s_Clavicle" % side), StringName("CC_Base_%s_Upperarm" % side), StringName("CC_Base_%s_Forearm" % side), StringName("CC_Base_%s_Hand" % side))


func _set_global_basis(index: int, desired: Basis) -> void:
	var parent_index: int = skeleton.get_bone_parent(index)
	var parent_basis: Basis = skeleton.get_bone_global_pose(parent_index).basis.orthonormalized() if parent_index >= 0 else Basis.IDENTITY
	skeleton.set_bone_pose_rotation(index, (parent_basis.inverse() * desired.orthonormalized()).get_rotation_quaternion().normalized())
	skeleton.force_update_all_bone_transforms()


func _restore_rest() -> void:
	rig.clear_runtime_solved_replay_pose_frame()
	for index: int in rest_poses.size():
		skeleton.set_bone_pose(index, rest_poses[index])
	skeleton.force_update_all_bone_transforms()


func _indices(side: String) -> Array[int]:
	var result: Array[int] = []
	for role: String in ["Clavicle", "Upperarm", "Forearm", "Hand"]:
		result.append(skeleton.find_bone("CC_Base_%s_%s" % [side, role]))
	return result


func _frames(ids: Array[int]) -> Array[Transform3D]:
	var result: Array[Transform3D] = []
	for index: int in ids:
		result.append(skeleton.get_bone_global_pose(index))
	return result


func _world_frames(ids: Array[int]) -> Array[Transform3D]:
	var result: Array[Transform3D] = []
	for frame: Transform3D in _frames(ids):
		result.append(skeleton.global_transform * frame)
	return result


func _material_error(ids: Array[int]) -> float:
	# Independent geometric oracle: the imported rest arm's positive normal,
	# carried by Upperarm, must match the actual S/E/W bending normal.
	var forearm_rest: Transform3D = skeleton.get_bone_rest(ids[2])
	var hand_rest: Transform3D = skeleton.get_bone_rest(ids[3])
	var hinge_local: Vector3 = forearm_rest.origin.cross(forearm_rest.basis * hand_rest.origin).normalized()
	var frames: Array[Transform3D] = _frames(ids)
	var actual: Vector3 = (frames[2].origin - frames[1].origin).cross(frames[3].origin - frames[2].origin).normalized()
	return rad_to_deg((frames[1].basis.orthonormalized() * hinge_local).angle_to(actual))


func _helper_rotations(side: String) -> Array[Quaternion]:
	var result: Array[Quaternion] = []
	for role: String in ["UpperarmTwist01", "UpperarmTwist02", "ForearmTwist01", "ForearmTwist02"]:
		var index: int = skeleton.find_bone("CC_Base_%s_%s" % [side, role])
		if index >= 0:
			result.append(skeleton.get_bone_pose_rotation(index))
	return result


func _position_delta(a: Array[Transform3D], b: Array[Transform3D]) -> float:
	var result := 0.0
	for index: int in a.size():
		result = maxf(result, a[index].origin.distance_to(b[index].origin))
	return result


func _basis_error(a: Basis, b: Basis) -> float:
	var q: Quaternion = (a.orthonormalized().get_rotation_quaternion().inverse() * b.orthonormalized().get_rotation_quaternion()).normalized()
	return rad_to_deg(2.0 * atan2(Vector3(q.x, q.y, q.z).length(), absf(q.w)))


func _quaternion(value: Vector4) -> Quaternion:
	return Quaternion(value.x, value.y, value.z, value.w).normalized()


func _slot(side: String) -> StringName:
	return &"hand_left" if side == "L" else &"hand_right"


func _check(passed: bool, label: String, detail: Dictionary = {}) -> void:
	checks.append({"passed": passed, "check": label, "detail": detail})
