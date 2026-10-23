extends SceneTree

const Incremental = preload("res://core/resolvers/combat_runtime_clip_incremental_resolver.gd")
const Baker = preload("res://core/resolvers/combat_runtime_clip_baker.gd")
const Clip = preload("res://core/models/combat_runtime_clip.gd")
const MotionNode = preload("res://core/models/combat_animation_motion_node.gd")

var _checks: int = 0
var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var first: CombatAnimationMotionNode = _node(0, 0.0, 0.01)
	var second: CombatAnimationMotionNode = _node(1, 0.0, 0.25)
	var third: CombatAnimationMotionNode = _node(2, 0.0, 0.25)
	var previous: CombatRuntimeClip = _bake([first, second])
	var appended: CombatRuntimeClip = _bake([first, second, third])
	var count: int = previous.get_frame_count()
	_check(count > 2, "fixture_has_sampled_interval")
	_check(Incremental.matching_prefix_count(previous, appended) == count, "append_reuses_equal_global_grid_prefix")
	_check(Incremental.matching_prefix_count(appended, previous) == count, "delete_tail_keeps_shorter_equal_prefix")
	_check(Incremental.matching_prefix_count(previous, previous.duplicate_clip()) == count, "independent_identical_clip")
	_check(Incremental.matching_prefix_count(null, previous) == 0, "null_previous")
	_check(Incremental.matching_prefix_count(previous, null) == 0, "null_next")
	_check(Incremental.matching_prefix_count(Clip.new(), Clip.new()) == 0, "empty_clips")

	var off_grid_node: CombatAnimationMotionNode = _node(1, 0.0, 0.23)
	var off_grid: CombatRuntimeClip = _bake([first, off_grid_node])
	var off_grid_append: CombatRuntimeClip = _bake([first, off_grid_node, third])
	_check(Incremental.matching_prefix_count(off_grid, off_grid_append) == off_grid.get_frame_count() - 1, "append_rejects_old_off_grid_terminal")
	_check(Incremental.matching_prefix_count(off_grid_append, off_grid) == off_grid.get_frame_count() - 1, "delete_rejects_new_off_grid_terminal")
	_check(Incremental.matching_prefix_count(previous, off_grid) == off_grid.get_frame_count() - 1, "shorter_duration_compares_terminal_timestamp")

	var edited_last: CombatRuntimeClip = _bake([first, _node(1, 0.2, 0.25)])
	_check(Incremental.matching_prefix_count(previous, edited_last) == 1, "latest_node_edit_changes_incoming_interval")
	var edited_append: CombatRuntimeClip = _bake([first, second, _node(2, 0.2, 0.25)])
	_check(Incremental.matching_prefix_count(previous, edited_append) == count, "moving_appended_node_keeps_earlier_interval")
	_verify_every_input_channel(previous)
	_verify_metadata(previous)
	_verify_model_field_coverage(previous)
	_verify_solved_prefix(previous)

	print(JSON.stringify({"verifier": "combat_runtime_clip_incremental", "checks": _checks,
		"passed": _failures.is_empty(), "failures": _failures}))
	quit(0 if _failures.is_empty() else 1)

func _verify_every_input_channel(previous: CombatRuntimeClip) -> void:
	var index: int = 3
	for field: StringName in Incremental.INPUT_FRAME_FIELDS:
		var changed: CombatRuntimeClip = previous.duplicate_clip()
		var values: Variant = changed.get(field)
		values[index] = _different(values[index])
		changed.set(field, values)
		_check(Incremental.matching_prefix_count(previous, changed) == index, "channel_change:" + String(field))
		# Equal later samples must not restart reuse after the first mismatch.
		_check(Incremental.matching_prefix_count(changed, previous) == index, "prefix_stops:" + String(field))

	var tiny_float: CombatRuntimeClip = previous.duplicate_clip()
	tiny_float.baked_weapon_roll_degrees[index] = 0.000000000001
	_check(Incremental.matching_prefix_count(previous, tiny_float) == index, "sub_tolerance_float_change_is_not_reused")
	var tiny_vector: CombatRuntimeClip = previous.duplicate_clip()
	var changed_tip: Vector3 = tiny_vector.baked_tip_positions_local[index]
	changed_tip.x = 0.000000000001
	tiny_vector.baked_tip_positions_local[index] = changed_tip
	_check(Incremental.matching_prefix_count(previous, tiny_vector) == index, "sub_tolerance_vector_change_is_not_reused")
	var incomplete: CombatRuntimeClip = previous.duplicate_clip()
	incomplete.baked_secondary_grip_seat_slide_offsets.resize(1)
	_check(Incremental.matching_prefix_count(previous, incomplete) == 0, "incomplete_channel_rejects_selected_node_fallback")
	var bad_value: CombatRuntimeClip = previous.duplicate_clip()
	bad_value.baked_weapon_roll_degrees[index] = INF
	_check(Incremental.matching_prefix_count(bad_value, bad_value) == index, "nonfinite_frame_is_not_reusable")
	var wrong_type: CombatRuntimeClip = previous.duplicate_clip()
	wrong_type.baked_right_hand_proxy_authored[index] = 0
	_check(Incremental.matching_prefix_count(previous, wrong_type) == index, "bool_and_integer_are_not_identical")
	var duplicate_time: CombatRuntimeClip = previous.duplicate_clip()
	duplicate_time.baked_frame_times[index] = duplicate_time.baked_frame_times[index - 1]
	_check(Incremental.matching_prefix_count(duplicate_time, duplicate_time) == index, "nonincreasing_timestamp_stops_prefix")

func _verify_metadata(previous: CombatRuntimeClip) -> void:
	for field: StringName in Incremental.INPUT_METADATA_FIELDS:
		var changed: CombatRuntimeClip = previous.duplicate_clip()
		changed.set(field, _different(changed.get(field)))
		_check(Incremental.matching_prefix_count(previous, changed) == 0, "metadata_change:" + String(field))
	var duration_only: CombatRuntimeClip = previous.duplicate_clip()
	duration_only.total_duration_seconds += 1.0
	duration_only.compile_diagnostics.append({"message": "Additional tail diagnostic"})
	duration_only.hand_swap_bridge_count += 1
	duration_only.retargeted_count += 1
	duration_only.degraded_node_count += 1
	_check(Incremental.matching_prefix_count(previous, duration_only) == previous.get_frame_count(), "duration_and_compile_totals_do_not_invalidate_equal_inputs")
	var nonfinite: CombatRuntimeClip = previous.duplicate_clip()
	nonfinite.sample_rate_hz = INF
	_check(Incremental.matching_prefix_count(nonfinite, nonfinite) == 0, "nonfinite_setting_rejects_prefix")

func _verify_model_field_coverage(clip: CombatRuntimeClip) -> void:
	for property: Dictionary in clip.get_property_list():
		if not (int(property.usage) & PROPERTY_USAGE_STORAGE):
			continue
		var name: StringName = StringName(property.name)
		var text: String = String(name)
		if text.ends_with("_origin_id"):
			_check(Incremental.INPUT_METADATA_FIELDS.has(name), "model_origin_covered:" + text)
		if text.begins_with("baked_") and not text.begins_with("baked_solved_") and not text.begins_with("baked_upper_body_") and not text.ends_with("_origin_id"):
			_check(Incremental.INPUT_FRAME_FIELDS.has(name), "model_input_channel_covered:" + text)

func _verify_solved_prefix(inputs: CombatRuntimeClip) -> void:
	var solved: CombatRuntimeClip = inputs.duplicate_clip()
	_attach_solved_track(solved)
	_check(solved.has_solved_replay_track(), "solved_copy_fixture_complete")
	_check(Incremental.matching_prefix_count(solved, inputs) == inputs.get_frame_count(), "solved_outputs_excluded_from_input_match")
	var prefix: Dictionary = Incremental.solved_prefix_data(solved, 3)
	_check(not prefix.is_empty(), "solved_prefix_available")
	if prefix.is_empty():
		return
	for field: StringName in Incremental.SOLVED_FRAME_FIELDS:
		_check(prefix[field].size() == 3, "copied_solved_frame_count:" + String(field))
	_check(prefix.baked_solved_upper_body_bone_names == solved.baked_solved_upper_body_bone_names, "copied_bone_layout")
	_check(prefix.baked_solved_anchor_node_paths == solved.baked_solved_anchor_node_paths, "copied_anchor_layout")
	var copied_bones: PackedVector3Array = prefix.baked_solved_upper_body_pose_positions[0]
	copied_bones[0] = Vector3(999.0, 0.0, 0.0)
	prefix.baked_solved_upper_body_pose_positions[0] = copied_bones
	prefix.baked_solved_weapon_positions_reference_local[0] = Vector3(999.0, 0.0, 0.0)
	prefix.baked_solved_anchor_node_paths[0] = &"Changed"
	_check(solved.baked_solved_upper_body_pose_positions[0][0] == Vector3.ZERO, "nested_packed_bone_data_is_independent")
	_check(solved.baked_solved_weapon_positions_reference_local[0] == Vector3.ZERO, "packed_weapon_data_is_independent")
	_check(solved.baked_solved_anchor_node_paths[0] == &"PrimaryGripAnchor", "anchor_layout_is_independent")
	_check(Incremental.solved_prefix_data(inputs, 3).is_empty(), "unsolved_source_cannot_supply_pose_prefix")
	_check(Incremental.solved_prefix_data(solved, 0).is_empty(), "empty_solved_prefix")
	_check(Incremental.solved_prefix_data(solved, solved.get_frame_count() + 1).is_empty(), "oversized_solved_prefix")
	solved.baked_solved_replay_frame_available[2] = false
	_check(Incremental.solved_prefix_data(solved, 3).is_empty(), "unavailable_solved_frame_rejected")
	_check(not Incremental.solved_prefix_data(solved, 2).is_empty(), "later_unavailable_frame_does_not_reject_earlier_prefix")
	solved.baked_solved_upper_body_pose_positions[1] = PackedVector3Array()
	_check(Incremental.solved_prefix_data(solved, 2).is_empty(), "incomplete_bone_frame_rejected")

func _attach_solved_track(clip: CombatRuntimeClip) -> void:
	clip.upper_body_pose_track_source = Clip.UPPER_BODY_POSE_TRACK_SOURCE_SKILL_CRAFTER_AUTHORED_POSE
	clip.solved_replay_track_source = Clip.SOLVED_REPLAY_TRACK_SOURCE_SKILL_CRAFTER_F_PLAYBACK
	clip.baked_upper_body_bone_names = [&"ProbeBone"]
	clip.baked_solved_upper_body_bone_names = [&"ProbeBone"]
	clip.baked_solved_anchor_node_paths = [&"PrimaryGripAnchor"]
	for frame: int in clip.get_frame_count():
		var position: Vector3 = Vector3(float(frame), 0.0, 0.0)
		clip.baked_upper_body_bone_pose_rotations.append(PackedVector4Array([Vector4(0.0, 0.0, 0.0, 1.0)]))
		clip.baked_solved_replay_frame_available.append(true)
		clip.baked_solved_upper_body_pose_positions.append(PackedVector3Array([position]))
		clip.baked_solved_upper_body_pose_rotations.append(PackedVector4Array([Vector4(0.0, 0.0, 0.0, 1.0)]))
		clip.baked_solved_upper_body_pose_scales.append(PackedVector3Array([Vector3.ONE]))
		clip.baked_solved_weapon_positions_reference_local.append(position)
		clip.baked_solved_weapon_rotations_reference_local.append(Vector4(0.0, 0.0, 0.0, 1.0))
		clip.baked_solved_weapon_scales_reference_local.append(Vector3.ONE)
		clip.baked_solved_anchor_positions_weapon_local.append(PackedVector3Array([Vector3.ZERO]))
		clip.baked_solved_anchor_rotations_weapon_local.append(PackedVector4Array([Vector4(0.0, 0.0, 0.0, 1.0)]))
		clip.baked_solved_anchor_scales_weapon_local.append(PackedVector3Array([Vector3.ONE]))

func _node(index: int, offset: float, duration: float) -> CombatAnimationMotionNode:
	var node: CombatAnimationMotionNode = MotionNode.new()
	node.node_id = StringName("incremental_%d" % index)
	node.node_index = index
	node.tip_position_local = Vector3(offset, 0.0, -1.0)
	node.pommel_position_local = Vector3(offset, 0.0, 0.0)
	node.transition_duration_seconds = duration
	node.primary_hand_slot = MotionNode.PRIMARY_HAND_RIGHT
	node.two_hand_state = MotionNode.TWO_HAND_STATE_ONE_HAND
	return node

func _bake(nodes: Array) -> CombatRuntimeClip:
	return Baker.new().bake_from_motion_node_chain(nodes, {
		"source_draft_id": &"incremental_probe", "source_weapon_wip_id": &"probe_weapon",
		"source_weapon_length_meters": 1.0, "sample_rate_hz": 60.0,
	}) as CombatRuntimeClip

func _different(value: Variant) -> Variant:
	if value is Vector3:
		return value + Vector3(0.001, 0.0, 0.0)
	if value is float:
		return value + 0.000001
	if value is int:
		return value + 1
	if value is bool:
		return not value
	if value is StringName:
		return StringName(String(value) + "_changed")
	return str(value) + "_changed"

func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)
