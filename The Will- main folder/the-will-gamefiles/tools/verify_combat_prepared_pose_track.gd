extends SceneTree

const Builder = preload("res://core/resolvers/combat_prepared_pose_track_builder.gd")
const PreparedPose = preload("res://core/models/combat_prepared_pose.gd")
const MotionNode = preload("res://core/models/combat_animation_motion_node.gd")
const Baker = preload("res://core/resolvers/combat_runtime_clip_baker.gd")
const Clip = preload("res://core/models/combat_runtime_clip.gd")
const Origins = preload("res://core/models/combat_origin_record.gd")
const Compiler = preload("res://core/resolvers/combat_animation_runtime_chain_compiler.gd")
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
		"valid": true, "schema_version": PreparedPose.SCHEMA_VERSION, "context_signature": "synthetic_same_model_and_weapon",
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
