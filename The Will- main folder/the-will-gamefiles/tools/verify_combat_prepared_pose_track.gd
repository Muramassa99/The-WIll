extends SceneTree

const Builder = preload("res://core/resolvers/combat_prepared_pose_track_builder.gd")
const PreparedPose = preload("res://core/models/combat_prepared_pose.gd")
const MotionNode = preload("res://core/models/combat_animation_motion_node.gd")
const Baker = preload("res://core/resolvers/combat_runtime_clip_baker.gd")
const Clip = preload("res://core/models/combat_runtime_clip.gd")
const Origins = preload("res://core/models/combat_origin_record.gd")
const Compiler = preload("res://core/resolvers/combat_animation_runtime_chain_compiler.gd")
const Capture = preload("res://runtime/combat/combat_prepared_pose_capture.gd")
const Attachment = preload("res://core/resolvers/combat_prepared_attachment_resolver.gd")
var checks: Dictionary = {}

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var output_dir := "C:/WORKSPACE/godot_runs/skill_transition_20261023/prepared_pose_track_check"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output-dir="):
			output_dir = argument.trim_prefix("--output-dir=")
	DirAccess.make_dir_recursive_absolute(output_dir)
	var a: Resource = _node(0, Vector3.ZERO, 1.0)
	var b: Resource = _node(1, Vector3(1, 0, 0), 0.137)
	var c: Resource = _node(2, Vector3(2, 0, 0), 0.219)
	a.tip_curve_out_handle = Vector3(0, 0.3, 0)
	a.pommel_curve_out_handle = Vector3(0, 0.3, 0)
	b.tip_curve_in_handle = Vector3(0, 0.3, 0)
	b.pommel_curve_in_handle = Vector3(0, 0.3, 0)
	var snapshots: Array[Dictionary] = [_snapshot(a, 0.0, true), _snapshot(b, PI * 0.5, true), _snapshot(c, PI * 0.25, true)]
	var inputs_before: PackedByteArray = var_to_bytes(snapshots)
	var control: Resource = Baker.new().bake_from_motion_node_chain([a, b, c])
	var control_times: PackedFloat32Array = control.baked_frame_times.duplicate()
	var control_tips: PackedVector3Array = control.baked_tip_positions_local.duplicate()
	var result: Dictionary = Builder.build(control, snapshots)
	_expect(result.get("valid", false), "pure_track_build_accepts_captured_endpoints")
	if result.get("valid", false):
		var clip: Resource = result.clip
		_expect(clip.has_solved_replay_track(), "output_has_complete_existing_solved_track_contract")
		_expect(is_equal_approx(clip.sample_rate_hz, 60.0), "base_density_remains_sixty_hertz")
		_expect(clip.get_frame_count() == control.get_frame_count() + 1, "only_off_grid_internal_endpoint_adds_sample")
		var middle: int = _find_time(clip.baked_frame_times, 0.137)
		_expect(middle >= 0, "off_grid_authored_endpoint_is_retained")
		_expect(clip.baked_solved_upper_body_pose_positions[0] == snapshots[0].pose_positions and clip.baked_solved_upper_body_pose_rotations[0] == snapshots[0].pose_rotations, "first_body_endpoint_is_exact")
		_expect(middle >= 0 and clip.baked_solved_upper_body_pose_positions[middle] == snapshots[1].pose_positions and clip.baked_solved_upper_body_pose_rotations[middle] == snapshots[1].pose_rotations, "off_grid_body_endpoint_is_exact")
		_expect(clip.baked_solved_upper_body_pose_positions[-1] == snapshots[2].pose_positions and clip.baked_solved_upper_body_pose_rotations[-1] == snapshots[2].pose_rotations, "last_body_endpoint_is_exact")
		_expect(middle >= 0 and clip.baked_solved_weapon_positions_reference_local[middle].is_equal_approx(snapshots[1].weapon_position_reference_local), "off_grid_weapon_endpoint_is_exact")
		var curve_index: int = _find_time(clip.baked_frame_times, 4.0 / 60.0)
		var expected_y: float = control.baked_pommel_positions_local[4].y + 0.02
		_expect(curve_index >= 0 and is_equal_approx(clip.baked_solved_weapon_positions_reference_local[curve_index].y, expected_y) and expected_y > 0.1, "existing_path_bias_and_endpoint_seating_offset_are_preserved")
		_expect(result.diagnostics.acquisition_calls == 0 and result.diagnostics.ik_calls == 0, "building_calls_no_acquisition_or_ik")
		_expect(result.diagnostics.max_primary_attachment_position_error_reference_units > 0.001, "interior_attachment_difference_is_measured_without_rejection")
		_expect(result.diagnostics.max_support_attachment_position_error_reference_units > 0.001, "support_interior_difference_is_measured_without_rejection")
		_expect(not result.diagnostics.interior_contact_validated, "diagnostics_do_not_claim_new_contact_validation")
		_expect(clip.baked_solved_anchor_positions_weapon_local[0] == snapshots[0].anchor_positions_weapon_local, "weapon_local_anchor_is_preserved")
		_expect(clip.baked_solved_anchor_node_paths.size() == 1 and clip.baked_solved_anchor_node_paths[0] == &"Grip", "nodepath_anchor_name_is_normalized_and_preserved")
	_expect(var_to_bytes(snapshots) == inputs_before, "builder_does_not_mutate_captured_snapshots")
	_expect(control.baked_frame_times == control_times and control.baked_tip_positions_local == control_tips and control.baked_solved_replay_frame_available.is_empty(), "builder_does_not_mutate_input_control_clip")
	var single: Resource = Baker.new().bake_from_motion_node_chain([a])
	var one_snapshot: Array[Dictionary] = [snapshots[0]]
	var one: Dictionary = Builder.build(single, one_snapshot)
	_expect(one.get("valid", false) and one.clip.get_frame_count() == 1, "single_visible_pose_needs_one_frame")
	var slower: Resource = b.duplicate_node()
	slower.transition_duration_seconds = 1.0
	var pair: Array[Dictionary] = [snapshots[0], snapshots[1]]
	var slow_result: Dictionary = Builder.build(Baker.new().bake_from_motion_node_chain([a, slower]), pair)
	_expect(slow_result.get("valid", false) and slow_result.clip.get_frame_count() == 61 and slow_result.diagnostics.acquisition_calls == 0, "longer_duration_only_adds_arithmetic_samples")
	var invalid: Array[Dictionary] = snapshots.duplicate(true)
	invalid[1].context_signature = "changed_character_or_weapon"
	_expect(not Builder.build(control, invalid).get("valid", false), "changed_snapshot_context_is_rejected")
	invalid = snapshots.duplicate(true)
	for snapshot: Dictionary in invalid:
		snapshot.parent_indices[0] = 2
	_expect(not Builder.build(control, invalid).get("valid", false), "parent_cycle_is_rejected_without_scene_access")
	_test_snapshot_identity(a, snapshots[0], output_dir)
	_test_attachment_contract(snapshots[0])
	_test_attachment_relationship_sampling()
	_test_finger_style_transition()
	_test_primary_hand_swap_compilation()
	var ok := true
	for passed: bool in checks.values():
		ok = ok and passed
	var report := {"ok": ok, "checks": checks, "count": checks.size(), "scope": "Synthetic value-only prepared endpoint interpolation. No actor, grip solver, or scene instance is created."}
	var file := FileAccess.open(output_dir.path_join("report.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "\t"))
	print(JSON.stringify(report))
	quit(0 if ok else 1)

func _test_snapshot_identity(node: Resource, snapshot: Dictionary, output_dir: String) -> void:
	var signature: String = PreparedPose.node_pose_signature(node)
	var copy: Resource = node.duplicate_node()
	copy.node_id = &"renumbered"
	copy.node_index = 99
	copy.transition_duration_seconds = 1.9
	copy.tip_curve_in_handle = Vector3(0.2, 0.1, 0)
	copy.prepared_pose = snapshot.duplicate(true)
	copy.prepared_pose_signature = signature
	_expect(PreparedPose.node_pose_signature(copy) == signature, "timing_path_handles_numbering_and_snapshot_do_not_invalidate_endpoint_pose")
	copy.tip_position_local += Vector3(0.1, 0, 0)
	_expect(PreparedPose.node_pose_signature(copy) != signature, "endpoint_position_edit_invalidates_pose_identity")
	var duplicate: Resource = copy.duplicate_node()
	duplicate.prepared_pose.pose_positions[0] += Vector3(5, 0, 0)
	_expect(duplicate.prepared_pose.pose_positions[0] != copy.prepared_pose.pose_positions[0], "deep_node_duplicate_does_not_share_snapshot_arrays")
	var path: String = output_dir.path_join("prepared_pose_node.tres")
	var saved: Error = ResourceSaver.save(copy, path)
	var loaded: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) if saved == OK else null
	_expect(loaded != null and PreparedPose.validate(loaded.prepared_pose).valid and loaded.prepared_pose_signature == signature and loaded.prepared_pose.pose_positions == copy.prepared_pose.pose_positions, "prepared_endpoint_survives_resource_save_and_load")

func _test_attachment_contract(snapshot: Dictionary) -> void:
	var value: Dictionary = snapshot.duplicate(true)
	value.erase("attachment_required")
	_expect(not PreparedPose.validate(value).valid, "attachment_policy_must_be_explicit")
	value = snapshot.duplicate(true)
	value.schema_version = 1
	_expect(not PreparedPose.validate(value).valid, "old_snapshot_schema_requires_editor_recapture")
	value = snapshot.duplicate(true)
	value.attachment_required = true
	value["primary_hand_slot"] = &"hand_right"
	value["support_hand_slot"] = &"hand_left"
	_expect(not PreparedPose.validate(value).valid, "attached_snapshot_requires_live_primary_constraints")
	var primary: Dictionary = _constraint_packet(&"hand_right", &"Hand")
	value["arm_constraints_by_slot"] = {&"hand_right": primary}
	_expect(not PreparedPose.validate(value).valid, "attached_support_snapshot_requires_support_constraints")
	value.arm_constraints_by_slot[&"hand_left"] = _constraint_packet(&"hand_left", &"Support")
	_expect(PreparedPose.validate(value).valid, "attached_snapshot_with_both_constraint_packets_validates")
	value.arm_constraints_by_slot[&"hand_left"].valid = false
	_expect(not PreparedPose.validate(value).valid, "invalid_support_constraint_packet_is_rejected")
	var config: Dictionary = {&"hand_right": primary}
	primary.twist_neutral_rotations[&"Helper"] = Quaternion(Vector3.UP, 0.2)
	var before: PackedByteArray = var_to_bytes(config)
	var stable: Dictionary = Capture.arm_constraints_context_data(config)
	_expect(var_to_bytes(config) == before, "constraint_hash_preparation_preserves_raw_capture")
	var moved: Dictionary = config.duplicate(true)
	moved[&"hand_right"].reference_up = Vector3.RIGHT
	moved[&"hand_right"].twist_neutral_rotations[&"Helper"] = -primary.twist_neutral_rotations[&"Helper"]
	_expect(var_to_bytes(Capture.arm_constraints_context_data(moved)) == var_to_bytes(stable), "reference_direction_and_quaternion_sign_do_not_change_common_context")
	moved[&"hand_right"].shoulder_max_degrees += 0.01
	_expect(var_to_bytes(Capture.arm_constraints_context_data(moved)) != var_to_bytes(stable), "actual_arm_limit_change_invalidates_common_context")

func _constraint_packet(slot: StringName, hand: StringName) -> Dictionary:
	return {"valid": true, "slot_id": slot, "clavicle_bone": &"Root", "upperarm_bone": &"Upper",
		"forearm_bone": &"Support", "hand_bone": hand, "shoulder_min_degrees": 8.0,
		"shoulder_max_degrees": 155.0, "elbow_min_degrees": 20.0, "elbow_max_degrees": 168.0,
		"joint_epsilon_degrees": 0.05, "limb_twist_limit_radians": PI * 0.5, "limb_twist_axis": Vector3.UP,
		"usable_reach_m": 1.0, "reference_up": Vector3.UP, "twist_chains": [], "twist_neutral_rotations": {}}

func _test_attachment_relationship_sampling() -> void:
	var basis := Basis(Quaternion(Vector3(1, 2, 3).normalized(), 0.63)).scaled(Vector3.ONE * 0.764)
	var offset := Vector3(0.025, -0.04, 0.012)
	var fixed := Transform3D(basis, offset)
	var same_a: Dictionary = {"primary_hand_in_weapon": fixed}
	var same_b: Dictionary = same_a.duplicate(true)
	var same: Dictionary = Attachment.sample_relationship(same_a, same_b, "primary", 0.37)
	_expect(same.valid and same.transform.is_equal_approx(fixed) and not same.handle_path_used, "unchanged_captured_attachment_frame_stays_unchanged")
	var start := Vector3(-0.1, 0, 0)
	var bend := Vector3(0, 0.08, 0.035)
	var end := Vector3(0.1, 0, 0)
	var path: Dictionary = {"valid": true, "origin_id": Origins.ORIGIN_WEAPON_ROOT,
		"ratios": PackedFloat32Array([0.0, 0.5, 1.0]), "centers": PackedVector3Array([start, bend, end])}
	var a: Dictionary = {"primary_hand_in_weapon": Transform3D(basis, start + offset),
		"primary_handle_seat": {"valid": true, "ratio": 0.0, "position": start}, "handle_path": path}
	var b: Dictionary = {"primary_hand_in_weapon": Transform3D(basis, end + offset),
		"primary_handle_seat": {"valid": true, "ratio": 1.0, "position": end}, "handle_path": path.duplicate(true)}
	var before: PackedByteArray = var_to_bytes([a, b])
	var middle: Dictionary = Attachment.sample_relationship(a, b, "primary", 0.5)
	_expect(middle.valid and middle.handle_path_used and middle.transform.origin.is_equal_approx(bend + offset), "curved_handle_slide_follows_bend_instead_of_endpoint_chord")
	_expect(middle.valid and (middle.transform.origin - bend).is_equal_approx(offset) and middle.transform.basis.is_equal_approx(basis), "curved_handle_slide_preserves_captured_wrist_to_current_seat_offset_and_basis")
	var reverse: Dictionary = Attachment.sample_relationship(b, a, "primary", 0.5)
	_expect(reverse.valid and reverse.transform.is_equal_approx(middle.transform), "curved_handle_slide_is_consistent_in_both_travel_directions")
	var endpoint_a: Dictionary = Attachment.sample_relationship(a, b, "primary", 0.0)
	var endpoint_b: Dictionary = Attachment.sample_relationship(a, b, "primary", 1.0)
	_expect(endpoint_a.valid and endpoint_a.transform == a.primary_hand_in_weapon, "attachment_relationship_retains_exact_endpoint_a")
	_expect(endpoint_b.valid and endpoint_b.transform == b.primary_hand_in_weapon, "attachment_relationship_retains_exact_endpoint_b")
	var missing: Dictionary = a.duplicate(true)
	missing.erase("handle_path")
	_expect(not Attachment.sample_relationship(missing, b, "primary", 0.5).valid, "known_seat_travel_rejects_missing_handle_path")
	var changed: Dictionary = b.duplicate(true)
	changed.handle_path.centers[1] += Vector3(0.01, 0, 0)
	_expect(not Attachment.sample_relationship(a, changed, "primary", 0.5).valid, "known_seat_travel_rejects_changed_handle_path")
	_expect(var_to_bytes([a, b]) == before, "attachment_relationship_sampling_preserves_inputs")
	var normal: Resource = _node(0, Vector3.ZERO, 1.0)
	var flipped: Resource = _node(1, Vector3(0.1, 0, 0), 1.0)
	flipped.preferred_grip_style_mode = &"grip_reverse"
	var normal_pose: Dictionary = _snapshot(normal, 0.0, false)
	var flipped_pose: Dictionary = _snapshot(flipped, 0.2, false)
	normal_pose.attachment_required = true
	flipped_pose.attachment_required = true
	var sample: Dictionary = Builder.sample_pose(normal_pose, flipped_pose, 0.5)
	var sample_before: PackedByteArray = var_to_bytes(sample)
	var released: Dictionary = Attachment.apply(sample, normal_pose, flipped_pose, 0.5, normal, flipped)
	_expect(released.valid and released.diagnostics.get("released_for_style_change", false) and released.ik_calls == 0, "style_flip_explicitly_releases_mate_without_arm_ik")
	_expect(released.pose_rotations == sample.pose_rotations and var_to_bytes(sample) == sample_before, "style_flip_release_preserves_supplied_tween_sample")
	# Authored percentage travel cannot use entry's unknown-seat fallback. These
	# packets deliberately lack seats and constraints: the metadata guard must
	# reject the slide before any arm realization or sample mutation is attempted.
	flipped.preferred_grip_style_mode = normal.preferred_grip_style_mode
	flipped.grip_seat_slide_offset = normal.grip_seat_slide_offset + 0.1
	var refused_slide: Dictionary = Attachment.apply(sample, normal_pose, flipped_pose, 0.5, normal, flipped)
	_expect(not refused_slide.valid and refused_slide.reason == "prepared_slide_missing_authored_seat" and var_to_bytes(sample) == sample_before, "authored_seat_change_without_captured_seat_rejects_entry_fallback")

func _test_finger_style_transition() -> void:
	var a: Resource = _node(0, Vector3.ZERO, 1.0)
	var b: Resource = _node(1, Vector3(1, 0, 0), 1.0)
	b.preferred_grip_style_mode = &"grip_reverse"
	var endpoints: Array[Dictionary] = [_snapshot(a, 0.0, false), _snapshot(b, 0.0, false)]
	for snapshot: Dictionary in endpoints:
		var opened: Dictionary = {}
		for index: int in 15:
			var name := StringName("Finger_%d" % index)
			snapshot.bone_names.append(name)
			snapshot.parent_indices.append(2)
			snapshot.parent_reference_transforms.append(Transform3D.IDENTITY)
			snapshot.bone_rest_transforms.append(Transform3D.IDENTITY)
			snapshot.pose_positions.append(Vector3(0, 0, 0.01))
			snapshot.pose_scales.append(Vector3.ONE)
			snapshot.pose_rotations.append(_pack(Quaternion(Vector3.RIGHT, 0.8)))
			opened[name] = Quaternion.IDENTITY
		snapshot["default_open_finger_packets"] = {&"hand_right": {"valid": true, "rotations": opened}}
	var result: Dictionary = Builder.build(Baker.new().bake_from_motion_node_chain([a, b]), endpoints)
	_expect(result.get("valid", false), "style_change_uses_captured_open_packets_without_new_solve")
	if not result.get("valid", false):
		return
	var clip: Resource = result.clip
	_expect(result.diagnostics.finger_style_transition_count == 1, "style_change_has_one_explicit_finger_interval")
	_expect(clip.baked_solved_upper_body_pose_rotations[0] == endpoints[0].pose_rotations and clip.baked_solved_upper_body_pose_rotations[-1] == endpoints[1].pose_rotations, "finger_transition_preserves_exact_endpoint_closures")
	_expect(clip.baked_solved_upper_body_pose_rotations[30][4].is_equal_approx(Vector4(0, 0, 0, 1)), "finger_midpoint_is_open_during_flip")
	_expect(clip.baked_solved_upper_body_pose_rotations[30][1] == endpoints[0].pose_rotations[1], "finger_transition_does_not_change_arm_rotation")

func _test_primary_hand_swap_compilation() -> void:
	var a: Resource = _node(0, Vector3.ZERO, 1.0)
	var b: Resource = _node(1, Vector3(1, 0, 0), 0.6)
	b.primary_hand_slot = &"hand_left"
	for node: Resource in [a, b]:
		node.normalize()
		node.prepared_pose = _snapshot(node, 0.0, false)
		node.prepared_pose_signature = PreparedPose.node_pose_signature(node)
	var before: PackedByteArray = var_to_bytes([a.prepared_pose, b.prepared_pose])
	var compiler := Compiler.new()
	var prepared: Dictionary = compiler.compile_skill_chain([a, b], 0.5)
	var chain: Array = prepared.motion_node_chain
	_expect(prepared.compiled and chain.size() == 2 and prepared.hand_swap_bridge_count == 0, "prepared_hand_swap_does_not_invent_an_uncaptured_bridge")
	var pair: Array[Dictionary] = []
	for node: Resource in chain:
		pair.append(node.prepared_pose)
	var result: Dictionary = Builder.build(Baker.new().bake_from_motion_node_chain(chain), pair)
	_expect(result.get("valid", false) and is_equal_approx(result.clip.total_duration_seconds, 0.6), "prepared_hand_swap_uses_only_authored_destination_timing")
	_expect(chain.size() == 2 and var_to_bytes([chain[0].prepared_pose, chain[1].prepared_pose]) == before, "hand_swap_compilation_preserves_both_exact_snapshots")
	_expect(var_to_bytes([a.prepared_pose, b.prepared_pose]) == before, "hand_swap_compilation_preserves_authored_sources")
	b.prepared_pose_signature = "obsolete_pose"
	var stale: Dictionary = compiler.compile_skill_chain([a, b], 0.5)
	_expect(stale.hand_swap_bridge_count == 1 and stale.motion_node_chain.size() == 3, "stale_prepared_pose_keeps_legacy_hand_swap_path")
	_expect(stale.motion_node_chain[1].prepared_pose.is_empty() and stale.motion_node_chain[1].prepared_pose_signature.is_empty(), "legacy_generated_bridge_never_claims_its_sources_prepared_pose")
	b.prepared_pose_signature = PreparedPose.node_pose_signature(b)
	b.prepared_pose = {}
	var missing: Dictionary = compiler.compile_skill_chain([a, b], 0.5)
	_expect(missing.hand_swap_bridge_count == 1, "missing_prepared_pose_keeps_legacy_hand_swap_path")
	b.prepared_pose = _snapshot(b, 0.0, false)
	var retargeted: Dictionary = compiler.compile_skill_chain([a, b], 0.7)
	_expect(retargeted.hand_swap_bridge_count == 1, "retargeted_endpoints_cannot_reuse_old_hand_swap_snapshots")

func _node(index: int, pommel: Vector3, duration: float) -> Resource:
	var node := MotionNode.new()
	node.node_id = StringName("node_%d" % index)
	node.node_index = index
	node.primary_hand_slot = &"hand_right"
	node.two_hand_state = MotionNode.TWO_HAND_STATE_ONE_HAND
	node.pommel_position_local = pommel
	node.tip_position_local = pommel + Vector3(0, 0, 0.5)
	node.transition_duration_seconds = duration
	return node

func _snapshot(node: Resource, upper_angle: float, support: bool) -> Dictionary:
	var origin: Vector3 = node.pommel_position_local + Vector3(0.04, 0.02, 0)
	var weapon := Transform3D(Basis.IDENTITY, origin)
	var root := Transform3D(Basis.IDENTITY, origin)
	var upper := Transform3D(Basis(Quaternion(Vector3.UP, upper_angle)), Vector3(0, 0, 0.2))
	var hand := Transform3D(Basis.IDENTITY, Vector3(0, 0, 0.3))
	var supporting := Transform3D(Basis.IDENTITY, Vector3(0.2, 0, 0.2))
	return {
		"valid": true, "schema_version": PreparedPose.SCHEMA_VERSION, "context_signature": "synthetic_same_model_and_weapon", "attachment_required": false,
		"bone_names": [&"Root", &"Upper", &"Hand", &"Support"],
		"pose_positions": PackedVector3Array([root.origin, upper.origin, hand.origin, supporting.origin]),
		"pose_rotations": PackedVector4Array([_pack(Quaternion.IDENTITY), _pack(upper.basis.get_rotation_quaternion()), _pack(Quaternion.IDENTITY), _pack(Quaternion.IDENTITY)]),
		"pose_scales": PackedVector3Array([Vector3.ONE, Vector3.ONE, Vector3.ONE, Vector3.ONE]),
		"parent_indices": PackedInt32Array([-1, 0, 1, 0]),
		"parent_reference_transforms": [Transform3D.IDENTITY, Transform3D.IDENTITY, Transform3D.IDENTITY, Transform3D.IDENTITY],
		"bone_rest_transforms": [Transform3D.IDENTITY, Transform3D.IDENTITY, Transform3D.IDENTITY, Transform3D.IDENTITY],
		"primary_hand_bone_name": &"Hand", "primary_hand_in_weapon": weapon.affine_inverse() * root * upper * hand,
		"support_enabled": support, "support_hand_bone_name": &"Support", "support_hand_in_weapon": weapon.affine_inverse() * root * supporting,
		"reference_bone_name": Clip.SOLVED_REPLAY_REFERENCE_BONE_NAME,
		"reference_origin_id": Origins.ORIGIN_SOLVED_REPLAY_REFERENCE,
		"weapon_reference_origin_id": Origins.ORIGIN_SOLVED_REPLAY_REFERENCE,
		"weapon_position_reference_local": origin, "weapon_rotation_reference_local": Quaternion.IDENTITY, "weapon_scale_reference_local": Vector3.ONE,
		"anchor_node_paths": [NodePath("Grip")], "anchor_origin_id": Origins.ORIGIN_WEAPON_ROOT,
		"anchor_positions_weapon_local": PackedVector3Array([Vector3(0, 0, 0.25)]),
		"anchor_rotations_weapon_local": PackedVector4Array([_pack(Quaternion.IDENTITY)]),
		"anchor_scales_weapon_local": PackedVector3Array([Vector3.ONE]),
		"trajectory_to_reference": Transform3D.IDENTITY,
		"weapon_tip_local": Vector3(0, 0, 0.5), "weapon_pommel_local": Vector3.ZERO,
	}

func _find_time(times: PackedFloat32Array, target: float) -> int:
	for index: int in times.size():
		if absf(float(times[index]) - target) < 0.000001:
			return index
	return -1

func _pack(value: Quaternion) -> Vector4:
	return Vector4(value.x, value.y, value.z, value.w)

func _expect(condition: bool, label: String) -> void:
	checks[label] = condition
	if not condition:
		push_error("Prepared pose track check failed: " + label)
