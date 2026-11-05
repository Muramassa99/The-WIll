extends "res://tools/verify_combat_prepared_pose_track.gd"

## Reuses the prepared-track fixture and real builder. The UI fixture supplies
## only an authored draft, ItemList, and a successful cache-write boundary;
## it does not run a grip solve, load a player library, or claim live pose validity.
class FeedbackUI extends CombatAnimationStationUI:
	var fixture_draft: CombatAnimationDraft
	var readiness: Dictionary = {"valid": true}

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_DISABLED
		point_list = ItemList.new()
		point_list.position = Vector2(20, 20)
		point_list.size = Vector2(1060, 140)
		add_child(point_list)

	func _get_active_draft() -> Resource:
		return fixture_draft

	func _get_active_weapon_total_length() -> float:
		return 0.5

	func get_prepared_action_pose_status(_draft: Resource = null) -> Dictionary:
		return readiness

	func _complete_runtime_clip_cache_bake(_preparation: Dictionary, _pose_track_result: Dictionary) -> Dictionary:
		return {"cached": true}

var evidence: Dictionary = {}

func _run() -> void:
	var output_dir := "C:/WORKSPACE/godot_runs/sc_motion_node_validation_feedback_20261028"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output-dir="):
			output_dir = argument.trim_prefix("--output-dir=")
	DirAccess.make_dir_recursive_absolute(output_dir)
	root.size = Vector2i(1100, 180)
	var ui := FeedbackUI.new()
	root.add_child(ui)
	var a: Resource = _node(1, Vector3.ZERO, 0.2)
	var b: Resource = _node(2, Vector3(0.1, 0, 0), 0.2)
	var draft := CombatAnimationDraft.new()
	draft.motion_node_chain = [_node(0, Vector3.ZERO, 0.2), a, b]
	draft.selected_motion_node_index = 1
	ui.fixture_draft = draft
	ui._refresh_motion_node_list()
	_expect(ui.point_list.item_count == 2 and ui.point_list.get_item_metadata(0) == 1, "hidden_reset_is_not_a_visible_action_row")

	# A real endpoint contract failure must identify only that visible endpoint.
	var endpoints: Array[Dictionary] = [_snapshot(a, 0.0, false), _snapshot(b, 0.0, false)]
	endpoints[1].context_signature = "different_context"
	var result: Dictionary = _prepare(ui, endpoints)
	var failure: Dictionary = result.get("attachment_failure", {})
	evidence["endpoint_failure"] = failure
	_expect(failure.get("failure_scope") == "endpoint" and failure.get("source_node_index") == 1 and failure.get("destination_node_index") == 1, "builder_endpoint_failure_has_explicit_action_index")
	_expect(not _red(ui, 0) and _red(ui, 1), "endpoint_failure_colors_only_visible_node_two")
	_expect(ui.point_list.get_item_tooltip(1).begins_with("N02 could not be prepared:"), "endpoint_tooltip_uses_visible_number")
	draft.selected_motion_node_index = 2
	ui._refresh_motion_node_list()
	_expect(_red(ui, 1), "selection_without_edit_preserves_known_failure")

	# Actual attachment rejection inside a sampled span. It must not mark the
	# source endpoint as invalid, even though legacy node_index names the source.
	endpoints = [_attachment_snapshot(a), _attachment_snapshot(b)]
	b.grip_seat_slide_offset = a.grip_seat_slide_offset + 0.1
	for snapshot: Dictionary in endpoints:
		snapshot.attachment_required = true
		snapshot["primary_hand_slot"] = &"hand_right"
		snapshot["support_hand_slot"] = &"hand_left"
		snapshot["arm_constraints_by_slot"] = {&"hand_right": _constraint_packet(&"hand_right", &"Hand")}
	result = _prepare(ui, endpoints)
	failure = result.get("attachment_failure", {})
	evidence["interior_attachment_failure"] = failure
	_expect(failure.get("reason") == "prepared_slide_missing_authored_seat" and int(failure.get("frame_index", 0)) > 0, "actual_attachment_failure_occurs_inside_transition")
	_expect(failure.get("failure_scope") == "transition" and failure.get("source_node_index") == 0 and failure.get("destination_node_index") == 1, "builder_attachment_failure_disambiguates_source_and_destination")
	_expect(not _red(ui, 0) and _red(ui, 1), "incoming_transition_colors_destination_only")
	_expect(ui.point_list.get_item_text(1).ends_with("incoming transition failed") and ui.point_list.get_item_tooltip(1).contains("N01 -> N02") and ui.point_list.get_item_tooltip(1).contains("does not mean either endpoint pose is invalid"), "transition_label_does_not_blame_endpoint_pose")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output_dir.path_join("incoming_transition_feedback.png"))

	# Legacy IDs can collide after insertion. Resource identity, not an ID
	# lookup, must keep the known failure on the actual destination object.
	a.node_id = &"duplicate_id"
	b.node_id = &"duplicate_id"
	result = _prepare(ui, endpoints)
	_expect(not _red(ui, 0) and _red(ui, 1), "duplicate_ids_do_not_color_the_wrong_resource")
	var replacement: Resource = b.duplicate_node()
	draft.motion_node_chain[2] = replacement
	ui._refresh_motion_node_list()
	_expect(not _red(ui, 0) and not _red(ui, 1), "replacement_with_same_id_does_not_inherit_old_failure")
	draft.motion_node_chain[2] = b
	ui._refresh_motion_node_list()
	ui._stage_active_wip_edit()
	_expect(not _red(ui, 1) and ui._motion_node_validation_feedback.is_empty(), "authored_edit_clears_stale_feedback")

	# A failed normal/reverse transition has different legacy index semantics;
	# it receives the same explicit incoming-transition contract.
	b.grip_seat_slide_offset = a.grip_seat_slide_offset
	b.preferred_grip_style_mode = &"grip_reverse"
	endpoints = [_snapshot(a, 0.0, false), _snapshot(b, 0.0, false)]
	result = _prepare(ui, endpoints)
	failure = result.get("attachment_failure", {})
	evidence["flip_open_packet_failure"] = failure
	_expect(failure.get("reason") == "prepared_pose_missing_open_fingers_for_style_transition" and failure.get("failure_scope") == "transition" and failure.get("source_node_index") == 0 and failure.get("destination_node_index") == 1, "actual_flip_packet_failure_identifies_incoming_transition")
	_expect(_red(ui, 1) and ui.point_list.get_item_tooltip(1).contains("N01 -> N02"), "flip_failure_uses_same_incoming_transition_feedback")

	# Confirmed successful preparation clears the previous failure.
	b.preferred_grip_style_mode = &"grip_normal"
	endpoints = [_snapshot(a, 0.0, false), _snapshot(b, 0.0, false)]
	result = _prepare(ui, endpoints)
	_expect(result.get("cached", false) and not _red(ui, 0) and not _red(ui, 1), "successful_real_builder_preparation_clears_feedback")

	ui.readiness = {"valid": false, "missing_node_indices": [2], "node_reasons": {2: "prepared_pose_inputs_changed"}}
	result = _prepare(ui, endpoints)
	_expect(not _red(ui, 0) and _red(ui, 1) and ui.point_list.get_item_tooltip(1).contains("prepared_pose_inputs_changed"), "readiness_uses_one_based_visible_indices")
	ui.readiness = {"valid": true}
	ui._clear_motion_node_validation_feedback()
	ui._record_motion_node_capture_failure(draft, {"reason": "prepared_pose_grip_not_bound", "node_index": 1})
	_expect(_red(ui, 0) and not _red(ui, 1), "endpoint_recorder_failure_uses_its_visible_index")
	ui._clear_motion_node_validation_feedback()
	ui._record_motion_node_capture_failure(draft, {"reason": "weapon_facing_requires_manual_reacquisition"}, b)
	_expect(not _red(ui, 0) and _red(ui, 1), "selected_capture_failure_identifies_selected_resource")
	ui._clear_motion_node_validation_feedback()
	ui._record_motion_node_capture_failure(draft, {"reason": "missing_prepared_pose_skeleton"}, b)
	_expect(not _red(ui, 0) and not _red(ui, 1), "infrastructure_failure_does_not_blame_a_node")

	# Unmapped or legacy-only failures remain in existing overall status text.
	# Never guess a source/destination row from ambiguous node_index alone.
	var actions: Array = draft.get_action_motion_node_chain()
	var compiled: Array = []
	for node: Resource in actions:
		compiled.append(node.duplicate_node())
	ui._record_motion_node_preparation_failure(draft, {"reason": "unknown_failure", "node_index": 0}, compiled)
	_expect(ui._motion_node_validation_feedback.is_empty(), "ambiguous_legacy_index_is_not_guessed")
	compiled.insert(1, _node(99, Vector3.ZERO, 0.2))
	ui._record_motion_node_preparation_failure(draft, failure, compiled)
	_expect(ui._motion_node_validation_feedback.is_empty(), "runtime_only_bridge_mismatch_is_not_guessed")
	ui.fixture_draft = CombatAnimationDraft.new()
	ui._record_motion_node_preparation_failure(draft, failure, actions)
	_expect(ui._motion_node_validation_feedback.is_empty(), "stale_attempt_for_another_draft_is_ignored")
	ui.fixture_draft = draft
	_expect(not draft.has_meta("motion_node_validation_feedback") and not a.has_meta("motion_node_validation_feedback"), "feedback_is_session_only_not_saved_metadata")
	ui.free()
	var ok := true
	for passed: bool in checks.values():
		ok = ok and passed
	var report := {"ok": ok, "checks": checks, "count": checks.size(), "evidence": evidence,
		"scope": "Actual prepared-track failure generation and shared F/Save UI feedback with synthetic captured endpoints; no live grip, player save, or full station playback claim."}
	DirAccess.make_dir_recursive_absolute(output_dir)
	var file := FileAccess.open(output_dir.path_join("report.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "\t"))
	print(JSON.stringify(report))
	quit(0 if ok else 1)

func _attachment_snapshot(node: Resource) -> Dictionary:
	var snapshot: Dictionary = _snapshot(node, 0.0, false)
	# The base fixture names Support as the Forearm in its constraint packet.
	# Supply a real serial arm with a bent calibration, rather than the base
	# interpolation-only fixture's unrelated Support branch and identity rests.
	# Root -> Upper -> Support (Forearm) -> Hand; list order need not be parent order.
	var upper := Transform3D(Basis.IDENTITY, Vector3(0.12, 0, 0))
	var forearm := Transform3D(Basis(Vector3.RIGHT, deg_to_rad(35.0)), Vector3(0, 0.28, 0))
	var hand := Transform3D(Basis.IDENTITY, Vector3(0, 0.25, 0))
	snapshot.parent_indices = PackedInt32Array([-1, 0, 3, 1])
	snapshot.bone_rest_transforms = [Transform3D.IDENTITY, upper, hand, forearm]
	snapshot.pose_positions = PackedVector3Array([snapshot.pose_positions[0], upper.origin, hand.origin, forearm.origin])
	snapshot.pose_rotations = PackedVector4Array([_pack(Quaternion.IDENTITY), _pack(Quaternion.IDENTITY), _pack(Quaternion.IDENTITY), _pack(forearm.basis.get_rotation_quaternion())])
	# Root and weapon share the fixture origin, so their translations cancel.
	snapshot.primary_hand_in_weapon = upper * forearm * hand
	snapshot.support_hand_in_weapon = upper * forearm
	return snapshot

func _prepare(ui: FeedbackUI, snapshots: Array[Dictionary]) -> Dictionary:
	var actions: Array = ui.fixture_draft.get_action_motion_node_chain()
	for index: int in actions.size():
		actions[index].prepared_pose = snapshots[index]
		actions[index].prepared_pose_signature = PreparedPose.node_pose_signature(actions[index])
	var before: PackedByteArray = var_to_bytes(snapshots)
	# Exercise the real UI preparation -> compiler -> sampler -> completion
	# boundary, so an accidentally changed compiled identity cannot silently
	# turn the runtime feedback off. The WIP is synthetic and never persisted.
	ui.active_wip = CraftedItemWIP.new()
	ui.active_wip.wip_id = &"validation_feedback_fixture"
	var preparation: Dictionary = ui._prepare_runtime_clip_cache_bake(ui.fixture_draft)
	_expect(preparation.has("runtime_clip"), "real_ui_preparation_produces_compiled_runtime_chain")
	if not preparation.has("runtime_clip"):
		ui.active_wip = null
		return preparation.get("result", {})
	_expect(ui._validation_chains_correspond(actions, preparation.runtime_clip.motion_node_chain), "actual_compiler_and_sampler_preserve_mappable_node_identity")
	var result: Dictionary = ui._complete_stored_pose_track(preparation)
	ui.active_wip = null
	_expect(var_to_bytes(snapshots) == before, "feedback_and_builder_leave_captured_packets_unchanged")
	return result

func _red(ui: FeedbackUI, row: int) -> bool:
	return ui.point_list.get_item_custom_fg_color(row).is_equal_approx(Color(1.0, 0.28, 0.28))

func _expect(condition: bool, label: String) -> void:
	super._expect(condition and bool(checks.get(label, true)), label)
