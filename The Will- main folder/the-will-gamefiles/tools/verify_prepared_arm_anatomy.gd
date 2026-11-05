extends SceneTree

## Value-only persistence and shared sample contract. Synthetic arm geometry is
## explicit; this is not evidence of visual correctness on Josie's skin.
const Pose = preload("res://core/models/combat_prepared_pose.gd")
const Arm = preload("res://core/resolvers/combat_prepared_arm_frame_resolver.gd")
const Track = preload("res://core/resolvers/combat_prepared_pose_track_builder.gd")
const Entry = preload("res://runtime/combat/combat_runtime_entry_transition.gd")
const Hinge = preload("res://core/resolvers/combat_arm_hinge_frame_resolver.gd")
const Shoulder = preload("res://core/resolvers/combat_shoulder_motion_resolver.gd")
const ShoulderProfile = preload("res://core/defs/shoulder_motion_profile_def.gd")
const Wrist = preload("res://core/resolvers/combat_wrist_motion_resolver.gd")
const WristProfile = preload("res://core/defs/wrist_motion_profile_def.gd")
const ForearmIndex = preload("res://core/resolvers/combat_forearm_hand_index_resolver.gd")
const Clip = preload("res://core/models/combat_runtime_clip.gd")
var checks: Dictionary = {}

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var output := "C:/WORKSPACE/godot_runs/shoulder_forearm_20261106/prepared"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output-dir="):
			output = argument.trim_prefix("--output-dir=")
	DirAccess.make_dir_recursive_absolute(output)
	var a := _pose(-100.0, -20.0)
	var b := _pose(70.0, 40.0)
	a.shoulder_states_by_slot.hand_right["held_h"] = deg_to_rad(-100.0)
	var before := var_to_bytes([a, b])
	_expect(Pose.validate(a).valid and Pose.validate(b).valid, "complete_anatomical_packets_validate")
	var sample := Track.sample_pose(a, b, 0.5)
	_expect(sample.get("valid", false), "shared_sampler_accepts_anatomical_packets")
	if sample.get("valid", false):
		_expect(is_equal_approx(sample.shoulder_states_by_slot.hand_right.h, deg_to_rad(-15.0)), "shoulder_signed_scalar_branch_is_interpolated")
		_expect(is_equal_approx(sample.wrist_states_by_slot.hand_right.rho, deg_to_rad(10.0)), "forearm_scalar_branch_is_interpolated")
		var middle := a.duplicate(true)
		for field: String in ["pose_positions", "pose_rotations", "pose_scales", "parent_reference_transforms", "wrist_states_by_slot", "shoulder_states_by_slot"]:
			middle[field] = sample[field]
		var measurement := Arm.measure_shoulder_states(middle)
		_expect(measurement.valid and absf(measurement.states.hand_right.h - deg_to_rad(-15.0)) < 0.00001, "sampled_pose_realizes_signed_shoulder_value")
		var shifted := middle.duplicate(true)
		shifted.parent_reference_transforms[0] = Transform3D(Basis(Vector3.UP, 0.7).scaled(Vector3.ONE * 2.5), Vector3(100.0, -30.0, 55.0))
		var shifted_measurement := Arm.measure_shoulder_states(shifted)
		_expect(shifted_measurement.valid and absf(shifted_measurement.states.hand_right.h - measurement.states.hand_right.h) < 0.00001, "root_translation_rotation_scale_do_not_change_anatomical_angle")
	_expect(Track.sample_pose(a, b, 0.0).pose_rotations == a.pose_rotations and Track.sample_pose(a, b, 1.0).pose_rotations == b.pose_rotations, "authored_endpoint_rotations_remain_exact")
	var long_arc := Track.sample_pose(_pose(-100.0, 0.0), _pose(100.0, 0.0), 0.5)
	var long_arc_pose := a.duplicate(true)
	for field: String in ["pose_positions", "pose_rotations", "pose_scales", "parent_reference_transforms", "wrist_states_by_slot", "shoulder_states_by_slot"]:
		long_arc_pose[field] = long_arc[field]
	var long_arc_measured := Arm.measure_shoulder_states(long_arc_pose)
	_expect(long_arc_measured.valid and absf(long_arc_measured.states.hand_right.h) < 0.00001, "shoulder_branch_crosses_zero_instead_of_quaternion_shortcut")
	_expect(var_to_bytes([a, b]) == before, "sampling_preserves_source_snapshots")
	var outside := _pose(100.0, 0.0)
	var measured := Arm.measure_shoulder_states(outside)
	_expect(Pose.validate(outside).valid and measured.valid and not measured.quality_warnings.is_empty(), "out_of_range_finite_pose_is_recordable_with_warning")
	var incomplete := a.duplicate(true)
	incomplete.arm_constraints_by_slot.hand_right.shoulder_calibration.erase("origin_id")
	_expect(not Pose.validate(incomplete).valid, "anonymous_shoulder_origin_is_rejected_as_incomplete_data")
	var bad_hold := a.duplicate(true)
	bad_hold.shoulder_states_by_slot.hand_right.held_h = NAN
	_expect(not Pose.validate(bad_hold).valid, "nonfinite_shoulder_hold_anchor_is_rejected")
	var legacy := a.duplicate(true)
	for key: String in ["shoulder_model_revision", "shoulder_calibration", "shoulder_profile"]:
		legacy.arm_constraints_by_slot.hand_right.erase(key)
	legacy.erase("shoulder_states_by_slot")
	_expect(Pose.validate(legacy).valid, "older_complete_pose_without_shoulder_extension_remains_readable")
	var wrapper := Resource.new()
	wrapper.set_meta("prepared_pose", a)
	var path := output.path_join("anatomy_pose.tres")
	var error := ResourceSaver.save(wrapper, path)
	var loaded: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) if error == OK else null
	_expect(loaded != null, "resource_roundtrip_completes")
	if loaded != null:
		var stored: Dictionary = loaded.get_meta("prepared_pose")
		_expect(Pose.validate(stored).valid, "saved_pose_retains_anatomy_contract")
		_expect(is_equal_approx(stored.shoulder_states_by_slot.hand_right.held_h, a.shoulder_states_by_slot.hand_right.held_h), "saved_pose_retains_shoulder_hold_anchor")
		_expect(Entry._matching_wrist_profile(a.arm_constraints_by_slot.hand_right.shoulder_profile, stored.arm_constraints_by_slot.hand_right.shoulder_profile), "serialized_shoulder_profile_matches")
		_expect(Entry._matching_shoulder_calibration(a.arm_constraints_by_slot.hand_right.shoulder_calibration, stored.arm_constraints_by_slot.hand_right.shoulder_calibration), "serialized_calibration_matches_named_rest_chain")
		_expect(Entry._matching_wrist_profile(a.arm_constraints_by_slot.hand_right.wrist_profile, stored.arm_constraints_by_slot.hand_right.wrist_profile), "serialized_forearm_table_matches")
		var replay := Track.sample_pose(stored, b, 0.5)
		_expect(replay.get("valid", false) and _rotations_match(replay.pose_rotations, sample.pose_rotations), "disk_loaded_and_editor_samples_match")
	_test_legacy_cold_entry()
	_test_entry_scalar_sampling()
	var ok := not checks.values().has(false)
	var report := {"ok": ok, "count": checks.size(), "checks": checks, "scope": "Synthetic prepared anatomy persistence and root-invariant shared sampling; no scene or acquisition."}
	var file := FileAccess.open(output.path_join("report.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "\t"))
	print(JSON.stringify(report))
	quit(0 if ok else 1)

func _pose(h_degrees: float, rho_degrees: float) -> Dictionary:
	var names: Array[StringName] = [&"RL_BoneRoot", &"Chest", &"Clavicle", &"Upper", &"Forearm", &"Hand", &"Twist1", &"Twist2"]
	var parents := PackedInt32Array([-1, 0, 1, 2, 3, 4, 4, 6])
	var positions := PackedVector3Array([Vector3.ZERO, Vector3(0, 1, 0), Vector3(0.1, 0, 0), Vector3(0.1, 0, 0), Vector3(0.3, 0, 0), Vector3(0.25, 0, -0.05), Vector3(0.05, 0, 0), Vector3(0.15, 0, 0)])
	var rotations := PackedVector4Array()
	var scales := PackedVector3Array()
	var roots: Array[Transform3D] = []
	var rests: Array[Transform3D] = []
	var parent_names: Array[StringName] = []
	for i: int in names.size():
		rotations.append(Vector4(0, 0, 0, 1))
		scales.append(Vector3.ONE)
		roots.append(Transform3D.IDENTITY)
		rests.append(Transform3D(Basis.IDENTITY, positions[i]))
		parent_names.append(names[parents[i]] if parents[i] >= 0 else StringName())
	var shoulder_calibration := {"valid": true, "revision": Shoulder.REVISION, "chest_bone_name": names[1], "clavicle_bone_name": names[2], "upperarm_bone_name": names[3], "forearm_bone_name": names[4],
		"material_frame_in_upperarm": Hinge.calibration(rests[4], rests[5]).frame_in_upperarm,
		"chest_anatomical_in_bone": Basis.IDENTITY, "internal_sign": -1.0, "side_sign": 1.0,
		"origin_id": &"ChestShoulderAnatomicalOrigin", "parent_origin_id": names[1],
		"source_bone_names": names, "source_rest_transforms": rests, "source_parent_bone_names": parent_names}
	var wrist_calibration := {"valid": true, "revision": Wrist.REVISION, "radial_sign": 1.0,
		"neutral_anatomical_in_forearm": Basis.IDENTITY, "anatomical_in_hand_bone": Basis.IDENTITY,
		"forearm_interval_revision": WristProfile.FOREARM_INTERVAL_REVISION, "forearm_thumb_up_rho_radians": 0.0, "forearm_pronation_sign": 1.0}
	var packet := {"valid": true, "slot_id": &"hand_right", "clavicle_bone": names[2], "upperarm_bone": names[3], "forearm_bone": names[4], "hand_bone": names[5],
		"shoulder_model_revision": Shoulder.REVISION, "shoulder_calibration": shoulder_calibration, "shoulder_profile": ShoulderProfile.new().as_dictionary(),
		"wrist_model_revision": Wrist.REVISION, "wrist_calibration": wrist_calibration, "wrist_profile": WristProfile.new().as_dictionary(),
		"elbow_min_degrees": 20.0, "elbow_max_degrees": 168.0}
	var pose := {"valid": true, "schema_version": Pose.SCHEMA_VERSION, "attachment_required": false,
		"bone_names": names, "parent_indices": parents, "parent_reference_transforms": roots, "bone_rest_transforms": rests, "pose_positions": positions, "pose_rotations": rotations, "pose_scales": scales,
		"primary_hand_bone_name": names[5], "primary_hand_in_weapon": Transform3D.IDENTITY, "support_enabled": false,
		"reference_bone_name": names[0], "reference_origin_id": names[0], "weapon_reference_origin_id": names[0], "anchor_origin_id": &"WeaponRuntimeRootOrigin",
		"weapon_position_reference_local": Vector3.ZERO, "weapon_rotation_reference_local": Quaternion.IDENTITY, "weapon_scale_reference_local": Vector3.ONE,
		"anchor_node_paths": [], "anchor_positions_weapon_local": PackedVector3Array(), "anchor_rotations_weapon_local": PackedVector4Array(), "anchor_scales_weapon_local": PackedVector3Array(),
		"arm_constraints_by_slot": {&"hand_right": packet}, "shoulder_states_by_slot": {&"hand_right": {"h": deg_to_rad(h_degrees)}},
		"wrist_states_by_slot": {&"hand_right": {"rho": deg_to_rad(rho_degrees), "beta": 0.0, "gamma": 0.0}}}
	var fk := Arm.forward_kinematics(pose)
	var composed := Shoulder.compose(fk.transforms[1], fk.transforms[3], fk.transforms[4], shoulder_calibration, deg_to_rad(h_degrees))
	Arm._set_reference_basis(pose, rotations, 3, composed.upperarm_basis)
	fk = Arm.forward_kinematics(pose, rotations)
	var wrist := Wrist.sample_kinematics(fk.transforms[4], fk.transforms[5], wrist_calibration, packet.wrist_profile, pose.wrist_states_by_slot.hand_right)
	Arm._set_reference_basis(pose, rotations, 5, wrist.hand_basis)
	pose.pose_rotations = rotations
	return pose

func _entry_pose(h_degrees: float = 0.0, rho_degrees: float = 0.0) -> Dictionary:
	var pose := _pose(h_degrees, rho_degrees)
	var packet: Dictionary = pose.arm_constraints_by_slot.hand_right
	packet.merge({"material_hinge_revision": Hinge.REVISION, "forearm_hand_index_revision": ForearmIndex.REVISION,
		"twist_chains": [[&"Twist1", &"Twist2"], []],
		"twist_neutral_rotations": {&"Twist1": Quaternion.IDENTITY, &"Twist2": Quaternion.IDENTITY},
		"missing_bones": [], "missing_twist_neutrals": [], "limb_twist_axis": Vector3.RIGHT,
		"shoulder_min_degrees": 10.0, "shoulder_max_degrees": 170.0, "joint_epsilon_degrees": 0.05,
		"limb_twist_limit_radians": deg_to_rad(150.0), "usable_reach_m": 0.55, "reference_up": Vector3.UP,
		"contact_wrist_twist_limit_degrees": 90.0, "contact_wrist_basis_enabled": true,
		"limb_twist_distribution_enabled": true}, true)
	for field: String in ["source_bone_names", "source_parent_bone_names", "source_rest_transforms"]:
		packet.wrist_calibration[field] = packet.shoulder_calibration[field].duplicate()
	return pose

func _legacy_pose(source: Dictionary) -> Dictionary:
	var pose := source.duplicate(true)
	for packet: Dictionary in pose.arm_constraints_by_slot.values():
		for field: String in ["shoulder_model_revision", "shoulder_profile", "shoulder_calibration"]:
			packet.erase(field)
		for field: String in ["forearm_interval_revision", "forearm_elbow_samples_radians", "forearm_pronation_limits_radians", "forearm_supination_limits_radians"]:
			packet.wrist_profile.erase(field)
		for field: String in ["forearm_interval_revision", "forearm_thumb_up_rho_radians", "forearm_pronation_sign"]:
			packet.wrist_calibration.erase(field)
	pose.erase("shoulder_states_by_slot")
	return pose

func _cold_pose(source: Dictionary) -> Dictionary:
	var pose := source.duplicate(true)
	for packet: Dictionary in pose.arm_constraints_by_slot.values():
		packet.twist_neutral_rotations.clear()
		packet.missing_twist_neutrals = [&"Twist1", &"Twist2"]
		packet.valid = false
	return pose

func _test_legacy_cold_entry() -> void:
	var live := _entry_pose(-10.0, 10.0)
	var saved := _legacy_pose(live)
	var saved_bytes := var_to_bytes(saved)
	var current_packet: Dictionary = live.arm_constraints_by_slot.hand_right
	var profile_bytes := var_to_bytes(current_packet.wrist_profile)
	var calibration_bytes := var_to_bytes(current_packet.wrist_calibration)
	_expect(Pose.validate(saved).valid, "legacy_cold_source_is_complete")
	_expect(not Entry._matching_wrist_profile(current_packet.wrist_profile, saved.arm_constraints_by_slot.hand_right.wrist_profile), "generic_profile_matching_remains_strict")
	var cold := _cold_pose(live)
	var restored := Entry._supply_matching_saved_neutrals(cold, saved)
	_expect(restored.valid and Pose.validate(cold).valid and cold.entry_restored_neutral_bones.size() == 2, "legacy_cold_entry_restores_matching_helper_neutrals")
	_expect(var_to_bytes(cold.arm_constraints_by_slot.hand_right.wrist_profile) == profile_bytes and var_to_bytes(cold.arm_constraints_by_slot.hand_right.wrist_calibration) == calibration_bytes,
		"legacy_recovery_keeps_current_forearm_limits_and_calibration")
	_expect(cold.arm_constraints_by_slot.hand_right.shoulder_model_revision == Shoulder.REVISION and cold.shoulder_states_by_slot.has(&"hand_right"), "legacy_recovery_keeps_current_shoulder_model")
	_expect(var_to_bytes(saved) == saved_bytes, "legacy_saved_skill_is_not_migrated_or_mutated")
	for change: String in ["rest", "scale", "length", "topology", "wrist_basis", "old_limit", "incomplete_legacy_extension", "new_profile_change"]:
		cold = _cold_pose(live)
		var baseline := saved.duplicate(true)
		match change:
			"rest": cold.bone_rest_transforms[4].origin.x += 0.001
			"scale": cold.pose_scales[4].x += 0.001
			"length": cold.pose_positions[4].x += 0.001
			"topology": cold.parent_indices[4] = 2
			"wrist_basis": cold.arm_constraints_by_slot.hand_right.wrist_calibration.anatomical_in_hand_bone = Basis(Vector3.UP, 0.1)
			"old_limit": cold.arm_constraints_by_slot.hand_right.wrist_profile.flexion_limit_radians += 0.01
			"incomplete_legacy_extension": baseline.arm_constraints_by_slot.hand_right.wrist_profile.forearm_pronation_limits_radians = PackedFloat64Array([1.0])
			"new_profile_change":
				baseline = live.duplicate(true)
				cold.arm_constraints_by_slot.hand_right.wrist_profile.forearm_pronation_limits_radians[0] += 0.01
		_expect(not Entry._supply_matching_saved_neutrals(cold, baseline).valid, "legacy_recovery_rejects_" + change)

func _test_entry_scalar_sampling() -> void:
	var a := _entry_pose(-100.0, 0.0)
	var b := _entry_pose(100.0, 0.0)
	var clip := Clip.new()
	clip.baked_frame_times = PackedFloat32Array([0.08])
	clip.baked_solved_weapon_rotations_reference_local = PackedVector4Array([Vector4(0, 0, 0, 1)])
	clip.baked_solved_weapon_scales_reference_local = PackedVector3Array([Vector3.ONE])
	clip.baked_solved_weapon_positions_reference_local = PackedVector3Array([Vector3.ZERO])
	clip.baked_solved_upper_body_pose_rotations = [Track.sample_pose(a, b, 0.5).pose_rotations]
	var result := Entry._attach_prefix(clip, a, b, null, null, 1)
	_expect(result.valid, "entry_uses_shared_scalar_anatomy_sampler")
	if result.valid:
		var measured_pose := a.duplicate(true)
		measured_pose.pose_rotations = clip.baked_solved_upper_body_pose_rotations[0]
		measured_pose.shoulder_states_by_slot.hand_right.h = 0.0
		var measured := Arm.measure_shoulder_states(measured_pose)
		_expect(measured.valid and absf(measured.states.hand_right.h) < 0.00001, "entry_shoulder_branch_matches_body_sampler")

func _rotations_match(a: PackedVector4Array, b: PackedVector4Array) -> bool:
	if a.size() != b.size(): return false
	for i: int in a.size():
		if absf(Quaternion(a[i].x, a[i].y, a[i].z, a[i].w).dot(Quaternion(b[i].x, b[i].y, b[i].z, b[i].w))) < 0.999999:
			return false
	return true

func _expect(value: bool, label: String) -> void:
	checks[label] = value
