extends "res://tools/verify_skill_grip_reopen.gd"

## Focused local-grip lifecycle check, using an isolated clone of saved Glave.
## --out=C:/WORKSPACE/godot_runs/<fresh-directory>
## No Save/F or source-library writes; the node roundtrip uses the audit folder.
func _run_diagnostic() -> void:
	for argument: String in OS.get_cmdline_user_args():
		var pair := argument.trim_prefix("--").split("=", true, 1)
		if pair.size() == 2: options[pair[0]] = pair[1]
	output_dir = String(options.get("out", "")).replace("\\", "/").simplify_path()
	if not output_dir.to_lower().begins_with("c:/workspace/godot_runs/") or FileAccess.file_exists(output_dir.path_join("report.json")):
		push_error("Require a fresh --out directory inside C:/WORKSPACE/godot_runs")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output_dir)
	reopen_trace_path = output_dir.path_join("grip_chronology.jsonl")
	ReopenChronology._requested_path = reopen_trace_path
	ReopenChronology.enabled()
	allocation_report = {"complete": false, "checks": [], "scope": "Actual saved local grip reused after a pose-only invalidation; resource roundtrip and negative identity boundaries. No original library writes."}
	var source_path := ProjectSettings.globalize_path(PlayerForgeWipLibraryStateScript.DEFAULT_SAVE_FILE_PATH)
	var source_hash := FileAccess.get_sha256(source_path)
	allocation_report["source_path"] = source_path
	allocation_report["source_sha256_before"] = source_hash
	var source := ResourceLoader.load(source_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as PlayerForgeWipLibraryState
	var fixture: CraftedItemWIP
	if source != null:
		for item: CraftedItemWIP in source.get_saved_wips():
			if item != null and item.forge_project_name == "Broken_Glave_v1":
				fixture = item.duplicate(true) as CraftedItemWIP
				break
	_check_allocation(fixture != null, "saved_Glave_available")
	if fixture == null:
		_finish_reuse_report()
		return
	var source_draft := _reopen_find_draft(fixture)
	_check_allocation(source_draft != null, "skill_two_available")
	if source_draft == null:
		_finish_reuse_report()
		return
	source_draft.selected_motion_node_index = 1
	var isolated := PlayerForgeWipLibraryStateScript.new()
	isolated.save_file_path = output_dir.path_join("isolated_library.tres")
	isolated.saved_wips.append(fixture)
	isolated.selected_wip_id = fixture.wip_id
	var player := FakePlayer.new()
	player.forge_wip_library_state = isolated
	root.add_child(player)
	var ui := CombatAnimationStationUIScene.instantiate() as CombatAnimationStationUI
	ui.set_meta("verification_skip_persistence", true)
	root.add_child(ui)
	await _wait_frames(3)
	root.gui_disable_input = true
	ui.set_process_input(false)
	ui.set_process_unhandled_input(false)
	ui.open_for(player, "Durable grip verifier")
	var opened := ui.open_saved_wip_with_hand_setup(fixture.wip_id, &"hand_right", false, true)
	var selected := ui.select_skill_slot(&"skill_slot_2", true)
	_check_allocation(opened and selected, "normal_station_open")
	var bound := await _reopen_await_bound(ui, "R")
	_check_allocation(bound.ready, "saved_primary_grip_ready", bound)
	if bound.ready:
		await _reopen_capture(ui)
		await _check_reuse_contract(ui)
	ui.close_ui()
	ui.queue_free()
	player.queue_free()
	await _wait_frames(3)
	allocation_report["source_sha256_after"] = FileAccess.get_sha256(source_path)
	_check_allocation(allocation_report.source_sha256_after == source_hash, "source_library_unchanged")
	_finish_reuse_report()

func _check_reuse_contract(ui: CombatAnimationStationUI) -> void:
	var motion: CombatAnimationMotionNode = ui.call("_get_active_motion_node")
	var actor := _get_preview_actor(ui) as PlayerHumanoidRig
	var weapon := _get_preview_held_item(ui)
	var owner: Node = actor.get_node("PreparedGripAcquisition")
	var saved: Dictionary = BoundaryPose.acquired_grip_for_node(motion).duplicate(true)
	_check_allocation(saved.get("schema_version", 0) == 2 and saved.get("packets", {}).has(&"hand_right"), "completed_grip_promoted_separately")
	if saved.is_empty(): return
	var signature := BoundaryPose.node_pose_signature(motion)
	var clone := motion.duplicate(true) as CombatAnimationMotionNode
	clone.prepared_grip["test_clone_only"] = true
	_check_allocation(not motion.prepared_grip.has("test_clone_only") and BoundaryPose.node_pose_signature(clone) == signature, "node_copies_isolated_and_grip_not_pose_input")
	var draft: CombatAnimationDraft = ui.call("_get_active_draft")
	var baseline: String = draft.call("_build_action_baseline_signature")
	var saved_content: String = draft.get_saved_content_signature()
	motion.prepared_grip["verifier_dirty_probe"] = true
	_check_allocation(draft.call("_build_action_baseline_signature") == baseline and draft.get_saved_content_signature() != saved_content, "grip_only_change_preserves_baseline_and_dirties_saved_content")
	motion.prepared_grip.erase("verifier_dirty_probe")
	var before_pending := var_to_bytes(motion.prepared_grip)
	BoundaryPose.retain_acquired_grip(motion, {"acquired_grip": {}, "grip_acquisition_finished": false})
	_check_allocation(var_to_bytes(motion.prepared_grip) == before_pending, "pending_support_capture_preserves_completed_primary")
	BoundaryPose.retain_acquired_grip(motion, {"acquired_grip": {}, "grip_acquisition_finished": true})
	_check_allocation(var_to_bytes(motion.prepared_grip) == before_pending, "failed_capture_preserves_completed_primary")
	var path := output_dir.path_join("node_roundtrip.tres")
	var saved_ok := ResourceSaver.save(motion, path) == OK
	var loaded := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as CombatAnimationMotionNode
	var roundtrip: Dictionary = {"saved": saved_ok, "loaded": loaded != null}
	var roundtrip_ok := false
	if saved_ok and loaded != null:
		var roundtrip_context := ui.preview_presenter.get_prepared_pose_capture_context(ui.preview_subviewport, motion, false)
		var roundtrip_slots: Array[StringName] = [&"hand_right"]
		var fingers := _reuse_finger_poses(actor)
		var restored: Dictionary = owner.restore_authoring_grip(loaded.prepared_grip,
			String(ui.call("_prepared_pose_context_signature", roundtrip_context)), roundtrip_slots,
			&"hand_right", String(roundtrip_context.grip_context_signature))
		roundtrip["restore"] = restored
		roundtrip["values_equal"] = loaded.prepared_grip == motion.prepared_grip
		roundtrip["top_level_key_order_equal"] = loaded.prepared_grip.keys() == motion.prepared_grip.keys()
		roundtrip["finger_error_radians"] = _reuse_finger_error(fingers, _reuse_finger_poses(actor))
		roundtrip_ok = restored.get("valid", false) and loaded.prepared_grip.get("slot_signatures") == motion.prepared_grip.get("slot_signatures") \
			and loaded.prepared_grip.get("grip_context_signature") == motion.prepared_grip.get("grip_context_signature") \
			and float(roundtrip.finger_error_radians) < 0.00001
	_check_allocation(roundtrip_ok, "durable_grip_resource_roundtrip", roundtrip)
	var count_before := _reopen_solve_count()
	var finger_before := _reuse_finger_poses(actor)
	var endpoints := [motion.tip_position_local, motion.pommel_position_local]
	motion.right_upperarm_roll_degrees += 0.1
	_check_allocation(BoundaryPose.node_pose_signature(motion) != signature, "pose_only_change_invalidates_body_snapshot")
	ui.call("_refresh_preview_scene")
	var bound := await _reopen_await_bound(ui, "R", 5000)
	await _reopen_capture(ui)
	_check_allocation(bound.ready and _reopen_solve_count() == count_before, "pose_only_refresh_reuses_grip_without_acquisition", {"bound": bound, "new_solves": _reopen_solve_count() - count_before})
	_check_allocation([motion.tip_position_local, motion.pommel_position_local] == endpoints, "pose_recovery_preserves_authored_endpoints")
	_check_allocation(_reuse_finger_error(finger_before, _reuse_finger_poses(actor)) < 0.00001, "pose_recovery_retains_acquired_finger_angles")
	var context := ui.preview_presenter.get_prepared_pose_capture_context(ui.preview_subviewport, motion, false)
	var pose_context := String(ui.call("_prepared_pose_context_signature", context))
	var grip_context := String(context.grip_context_signature)
	var slots: Array[StringName] = [&"hand_right"]
	var both: Array[StringName] = [&"hand_right", &"hand_left"]
	var reused: Dictionary = owner.reuse_authoring_grip(saved, pose_context, both, &"hand_right", grip_context)
	_check_allocation(reused.get("valid", false) and reused.get("reused_slots", []) == slots and _reopen_solve_count() == count_before, "adding_support_can_reuse_completed_primary_only", reused)
	owner.reuse_authoring_grip(saved, pose_context, slots, &"hand_right", grip_context)
	await _reuse_check_missing_support_join(ui, motion, actor, weapon, owner)
	count_before = _reopen_solve_count()
	var station: Vector3 = weapon.get_meta("preview_primary_grip_seat_local")
	weapon.set_meta("preview_primary_grip_seat_local", station + Vector3(0.001, 0.0, 0.0))
	reused = owner.reuse_authoring_grip(saved, pose_context, slots, &"hand_right", grip_context)
	weapon.set_meta("preview_primary_grip_seat_local", station)
	_check_allocation(not reused.get("valid", true), "changed_seat_rejected", reused)
	var style: Variant = weapon.get_meta("grip_style_mode")
	weapon.set_meta("grip_style_mode", &"deliberately_changed_style")
	reused = owner.reuse_authoring_grip(saved, pose_context, slots, &"hand_right", grip_context)
	weapon.set_meta("grip_style_mode", style)
	_check_allocation(not reused.get("valid", true), "changed_style_rejected", reused)
	var mesh: MeshInstance3D
	for child: Node in weapon.get_children():
		if child is MeshInstance3D and child.get_meta("visual_mesh_source", StringName()) == &"editable_mesh":
			mesh = child
			break
	_check_allocation(mesh != null, "actual_weapon_geometry_available")
	if mesh != null:
		var previous := mesh.transform
		mesh.position += Vector3(0.001, 0.0, 0.0)
		var changed_context := ui.preview_presenter.get_prepared_pose_capture_context(ui.preview_subviewport, motion, false)
		reused = owner.reuse_authoring_grip(saved, pose_context, slots, &"hand_right", String(changed_context.grip_context_signature))
		mesh.transform = previous
		_check_allocation(not reused.get("valid", true) and changed_context.grip_context_signature != grip_context, "changed_actual_geometry_rejected", reused)
	var wrong_anatomy := saved.duplicate(true)
	wrong_anatomy.packets[&"hand_right"].anatomy_signature = "different_anatomy"
	reused = owner.reuse_authoring_grip(wrong_anatomy, pose_context, slots, &"hand_right", grip_context)
	_check_allocation(not reused.get("valid", true), "changed_anatomy_rejected", reused)
	var left_slots: Array[StringName] = [&"hand_left"]
	reused = owner.reuse_authoring_grip(saved, pose_context, left_slots, &"hand_left", grip_context)
	_check_allocation(not reused.get("valid", true), "changed_hand_rejected", reused)
	for field: String in ["slots", "slot_signatures", "packets"]:
		var malformed := saved.duplicate(true)
		malformed[field] = "invalid_container"
		reused = owner.reuse_authoring_grip(malformed, pose_context, slots, &"hand_right", grip_context)
		_check_allocation(not reused.get("valid", true), "malformed_%s_rejected" % field, reused)
	var malformed_packet := saved.duplicate(true)
	malformed_packet.packets[&"hand_right"] = "invalid_packet"
	reused = owner.reuse_authoring_grip(malformed_packet, pose_context, slots, &"hand_right", grip_context)
	_check_allocation(not reused.get("valid", true), "malformed_slot_packet_rejected", reused)
	var changed := ui.apply_selected_motion_node_weapon_facing_delta(1.0, true)
	_check_allocation(changed and bool(motion.prepared_grip.get("reuse_invalidated", false)) and BoundaryPose.acquired_grip_for_node(motion).is_empty(), "actual_facing_cube_invalidates_reuse")
	_check_allocation(not motion.prepared_grip.get("packets", {}).is_empty(), "manual_invalidation_preserves_prior_provenance")
	_check_allocation(_reopen_solve_count() == count_before, "contract_checks_do_not_run_numeric_acquisition")

func _reuse_check_missing_support_join(ui: CombatAnimationStationUI, motion: CombatAnimationMotionNode,
		actor: PlayerHumanoidRig, weapon: Node3D, owner: Node) -> void:
	var primary_only: bool = not bool(ui.preview_presenter.get_prepared_pose_capture_context(
		ui.preview_subviewport, motion, false).get("support_enabled", true)) \
		and not BoundaryPose.acquired_grip_for_node(motion).get("packets", {}).has(&"hand_left")
	_check_allocation(primary_only, "missing_support_join_starts_with_primary_only_packet")
	if not primary_only: return
	var original_state := motion.two_hand_state
	var hand_index := actor.skeleton.find_bone("CC_Base_R_Hand")
	var hand_before := actor.skeleton.global_transform * actor.skeleton.get_bone_global_pose(hand_index)
	var weapon_before := weapon.global_transform
	var fingers_before := _reuse_finger_poses(actor)
	var request_before: Dictionary = owner.get("_requests")[&"hand_right"].duplicate(true)
	var endpoints := [motion.tip_position_local, motion.pommel_position_local]
	var counts_before := _reuse_solve_counts_by_slot()
	var changed := ui.set_selected_motion_node_two_hand_state(CombatAnimationMotionNode.TWO_HAND_STATE_TWO_HAND)
	var immediate := _reuse_primary_frame_error(actor, weapon, hand_index, hand_before, weapon_before, fingers_before)
	var support_queued := String(owner.status().get(&"hand_left", {}).get("status", "")) == "queued"
	_check_allocation(changed and support_queued and immediate.valid \
		and owner.get("_requests").get(&"hand_right", {}) == request_before,
		"missing_support_join_queues_only_support_and_preserves_primary_immediately", immediate.merged({"support_queued": support_queued}))
	var deadline := Time.get_ticks_msec() + 45000
	while not owner.is_render_checkpoint_idle() and Time.get_ticks_msec() < deadline:
		await _wait_frames(1)
	await _wait_frames(3)
	var settled := _reuse_primary_frame_error(actor, weapon, hand_index, hand_before, weapon_before, fingers_before)
	var counts_after := _reuse_solve_counts_by_slot()
	var new_primary := int(counts_after.hand_right) - int(counts_before.hand_right)
	var new_support := int(counts_after.hand_left) - int(counts_before.hand_left)
	var terminal: bool = owner.is_render_checkpoint_idle()
	var support_status: Dictionary = owner.status().get(&"hand_left", {})
	_check_allocation(terminal and new_primary == 0 and new_support == 1,
		"missing_support_join_runs_exactly_one_support_acquisition", {"terminal": terminal,
			"primary_solves": new_primary, "support_solves": new_support, "support_status": support_status.get("status", ""),
			"support_reason": support_status.get("reason", ""), "grip_accepted": support_status.get("grip_accepted", false),
			"actual_3d_grip_verified": support_status.get("actual_3d_grip_verified", false)})
	_check_allocation(settled.valid and owner.get("_requests").get(&"hand_right", {}) == request_before \
		and [motion.tip_position_local, motion.pommel_position_local] == endpoints,
		"missing_support_join_preserves_settled_primary_and_authored_endpoints", settled)
	ui.set_selected_motion_node_two_hand_state(original_state)
	await _wait_frames(2)

func _reuse_primary_frame_error(actor: PlayerHumanoidRig, weapon: Node3D, hand_index: int,
		hand_before: Transform3D, weapon_before: Transform3D, fingers_before: Dictionary) -> Dictionary:
	var hand := actor.skeleton.global_transform * actor.skeleton.get_bone_global_pose(hand_index)
	var result := {"hand_position_error_m": hand.origin.distance_to(hand_before.origin),
		"hand_angle_error_rad": _allocation_basis_error(hand.basis, hand_before.basis),
		"weapon_position_error_m": weapon.global_position.distance_to(weapon_before.origin),
		"weapon_angle_error_rad": _allocation_basis_error(weapon.global_basis, weapon_before.basis),
		"finger_angle_error_rad": _reuse_finger_error(fingers_before, _reuse_finger_poses(actor))}
	result["valid"] = maxf(result.hand_position_error_m, result.weapon_position_error_m) <= 0.000001 \
		and maxf(result.hand_angle_error_rad, maxf(result.weapon_angle_error_rad, result.finger_angle_error_rad)) <= 0.00001
	return result

func _reuse_solve_counts_by_slot() -> Dictionary:
	var counts := {"hand_right": 0, "hand_left": 0}
	var file := FileAccess.open(reopen_trace_path, FileAccess.READ)
	if file == null: return counts
	while not file.eof_reached():
		var line := file.get_line()
		if line.is_empty(): continue
		var row: Variant = JSON.parse_string(line)
		if row is Dictionary and row.get("kind") == "begin" and row.get("name") == "owner.await_solve":
			var slot := String(row.get("data", {}).get("slot", ""))
			if counts.has(slot): counts[slot] += 1
	file.close()
	return counts

func _reuse_finger_poses(actor: PlayerHumanoidRig) -> Dictionary:
	var poses: Dictionary = {}
	# Read actual digits independently of presenter implementation details.
	for index: int in actor.skeleton.get_bone_count():
		var name := String(actor.skeleton.get_bone_name(index))
		if name.begins_with("CC_Base_R_") and (name.contains("Thumb") or name.contains("Index") or name.contains("Mid") or name.contains("Ring") or name.contains("Pinky")):
			poses[name] = actor.skeleton.get_bone_pose(index)
	return poses

func _reuse_finger_error(before: Dictionary, after: Dictionary) -> float:
	if before.is_empty() or before.size() != after.size(): return INF
	var error := 0.0
	for name: Variant in before:
		if not after.has(name): return INF
		error = maxf(error, _allocation_basis_error(before[name].basis, after[name].basis))
	return error

func _finish_reuse_report() -> void:
	var report := _complete_allocation()
	var file := FileAccess.open(output_dir.path_join("report.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "\t"))
		file.close()
	quit(0 if report.complete else 1)
