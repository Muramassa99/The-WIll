extends "res://tools/diagnose_weapon_motion_boundary_reentry.gd"

## Cold-process continuity test. Every Save targets a fresh isolated library.
## Run write and read in SEPARATE Godot processes, using the same hand list:
## --phase=write --weapon=Broken_Balde_v1 --hands=R,L --slot=skill_slot_2 --out=<fresh-dir>
## --phase=read --input=<write-dir> --hands=R,L --out=<different-fresh-dir>
## --legacy=true in read removes only acquired_grip from the isolated fixture;
## its recovered Save can then be passed to a third normal read invocation.
## --two-hand=true creates a dual-grip fixture through the normal UI setters.
## --support-station=<ratio> optionally overrides normal two-hand placement.
## --negative-contract=true in read checks stale/corrupt packet rejection.
## --playback=true in a clean read exercises F/stop, return to editing and Save.
## --manual-facing=true checks intentional manual acquisition across navigation.
const ReopenChronology = preload("res://runtime/player/grip/grip_chronology.gd")
var reopen_trace_path := ""
var reopen_phase := ""

func _run_diagnostic() -> void:
	for argument: String in OS.get_cmdline_user_args():
		var pair := argument.trim_prefix("--").split("=", true, 1)
		if pair.size() == 2: options[pair[0]] = pair[1]
	reopen_phase = String(options.get("phase", ""))
	output_dir = String(options.get("out", "")).replace("\\", "/").simplify_path()
	if reopen_phase not in ["write", "read"] or not output_dir.to_lower().begins_with("c:/workspace/godot_runs/"):
		push_error("Require --phase=write/read and fresh --out inside C:/WORKSPACE/godot_runs")
		quit(1)
		return
	if FileAccess.file_exists(output_dir.path_join("manifest.json")):
		push_error("Refusing to overwrite previous manifest")
		quit(1)
		return
	if DirAccess.make_dir_recursive_absolute(output_dir) != OK:
		quit(1)
		return
	reopen_trace_path = output_dir.path_join("grip_chronology.jsonl")
	ReopenChronology._requested_path = reopen_trace_path
	if not ReopenChronology.enabled():
		quit(1)
		return
	manifest = {"complete": false, "phase": reopen_phase, "cases": [], "options": options,
		"process_id": OS.get_process_id(), "scope": "Separate-process real Skill Crafter Save/reopen. Source files read-only; no direct fabrication of solved grip data."}
	var original := ProjectSettings.globalize_path(PlayerForgeWipLibraryStateScript.DEFAULT_SAVE_FILE_PATH)
	manifest["original_source_sha256_before"] = FileAccess.get_sha256(original)
	var all_passed := true
	for side: String in String(options.get("hands", "R,L")).split(","):
		if side not in ["R", "L"]:
			all_passed = false
			break
		var source_path := String(options.get("input", original)).replace("\\", "/")
		if reopen_phase == "read":
			if not options.has("input"):
				manifest["failure"] = "read_requires_explicit_input"
				all_passed = false
				break
			if DirAccess.dir_exists_absolute(source_path): source_path = source_path.path_join("isolated_%s_library.tres" % side)
		var source := ResourceLoader.load(source_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as PlayerForgeWipLibraryState
		var chosen: CraftedItemWIP
		if source != null:
			for item: CraftedItemWIP in source.get_saved_wips():
				if item == null or item.latest_baked_profile_snapshot == null or not CraftedItemWIP.is_forge_v2_authoring_wip(item): continue
				if options.has("weapon") and item.forge_project_name != String(options.weapon) and String(item.wip_id) != String(options.weapon): continue
				chosen = item
				break
		if chosen == null:
			manifest["failure"] = "source_weapon_not_found: " + source_path
			all_passed = false
			break
		var source_hash := FileAccess.get_sha256(source_path)
		var fixture := chosen.duplicate(true) as CraftedItemWIP
		var legacy := reopen_phase == "read" and String(options.get("legacy", "false")) == "true"
		if legacy:
			var legacy_draft := _reopen_find_draft(fixture)
			if legacy_draft != null:
				for node: CombatAnimationMotionNode in legacy_draft.motion_node_chain:
					node.prepared_pose.erase("acquired_grip")
					if String(options.get("legacy-facing", "false")) == "true":
						var warnings: Array = node.prepared_pose.get("quality_warnings", []).duplicate(true)
						warnings.append({"severity": "warning", "reason": "weapon_facing_requires_manual_reacquisition"})
						node.prepared_pose["quality_warnings"] = warnings
		var isolated := PlayerForgeWipLibraryStateScript.new()
		isolated.save_file_path = output_dir.path_join("isolated_%s_library.tres" % side)
		isolated.saved_wips.append(fixture)
		isolated.selected_wip_id = fixture.wip_id
		var player := FakePlayer.new()
		player.forge_wip_library_state = isolated
		root.add_child(player)
		var ui := CombatAnimationStationUIScene.instantiate() as CombatAnimationStationUI
		ui.set_meta("verification_skip_persistence", false)
		root.add_child(ui)
		await _wait_frames(3)
		var solve_before := _reopen_solve_count()
		ui.open_for(player, "Grip continuity %s %s" % [reopen_phase, side])
		var opened := ui.open_saved_wip_with_hand_setup(fixture.wip_id, _boundary_slot(side), false, true)
		var selected := ui.select_skill_slot(StringName(String(options.get("slot", "skill_slot_2"))), true)
		allocation_report = {"complete": false, "checks": [], "side": side, "source": source_path,
			"isolated_save_path": isolated.save_file_path, "legacy_fixture": legacy}
		_check_allocation(opened and selected, "normal_station_open")
		if opened and selected:
			if reopen_phase == "write": await _reopen_write(ui, side)
			else: await _reopen_read(ui, side, solve_before, legacy)
		_check_allocation(FileAccess.get_sha256(source_path) == source_hash, "source_library_unchanged")
		var result := _complete_allocation()
		all_passed = all_passed and bool(result.complete)
		manifest.cases.append(result)
		_write_manifest()
		ui.close_ui()
		ui.queue_free()
		player.queue_free()
		await _wait_frames(4)
	manifest["original_source_sha256_after"] = FileAccess.get_sha256(original)
	manifest["original_source_unchanged"] = manifest.original_source_sha256_before == manifest.original_source_sha256_after
	manifest.complete = all_passed and manifest.original_source_unchanged
	ReopenChronology.close()
	manifest["actual_acquisition_starts"] = _reopen_solve_count()
	_write_manifest()
	quit(0 if manifest.complete else 1)

func _reopen_write(ui: CombatAnimationStationUI, side: String) -> void:
	_check_allocation(ui.reset_active_draft_to_baseline(), "isolated_reset")
	var ready := await _await_recorded_reset_baseline(ui)
	_check_allocation(ready.get("ready", false), "reset_acquisition_recorded", ready)
	if not ready.get("ready", false): return
	if String(options.get("two-hand", "false")) == "true":
		ui.set_selected_motion_node_two_hand_state(CombatAnimationMotionNode.TWO_HAND_STATE_TWO_HAND, false, true, true, false, true)
		if options.has("support-station"):
			ui.set_selected_motion_node_secondary_grip_seat_slide(float(options["support-station"]), false)
		else:
			ui.call("_refresh_preview_scene", &"handle_position_changed")
		var both_ready := await _reopen_await_bound(ui, side)
		_check_allocation(both_ready.ready, "both_grips_acquired_through_UI", both_ready)
		if not both_ready.ready: return
		await _reopen_capture(ui)
	ui.set_selected_motion_node_transition_duration(0.2, false)
	var original: CombatAnimationMotionNode = ui.call("_get_active_motion_node")
	_check_allocation(_reopen_has_packet(original), "node_1_stores_acquired_grip")
	var added := ui.insert_motion_node_after_selection()
	var recording := await _await_allocation_recording(ui)
	_check_allocation(added and recording.ready and ui.call("_get_active_motion_node") != original, "R_records_and_adds_node_2", recording)
	if not recording.ready: return
	await _wait_frames(4)
	var moved := await _reopen_small_movements(ui, side)
	_check_allocation(moved.valid, "new_node_tip_and_pommel_editable", moved)
	await _reopen_capture(ui)
	await _reopen_save(ui)
	var disk := _reopen_saved_draft(ui)
	_check_allocation(disk != null and disk.baked_runtime_clip != null, "actual_Save_reloads_skill")
	if disk == null: return
	var packets := true
	for node: CombatAnimationMotionNode in disk.get_action_motion_node_chain(): packets = packets and _reopen_has_packet(node)
	_check_allocation(packets and disk.get_action_motion_node_chain().size() == 2, "disk_contains_two_grip_snapshots")

func _reopen_read(ui: CombatAnimationStationUI, side: String, solve_before: int, legacy: bool) -> void:
	var node: CombatAnimationMotionNode = ui.call("_get_active_motion_node")
	var expected := node.prepared_pose.duplicate(true)
	var authored_before := BoundaryPose.node_pose_signature(node)
	var immediate_actor := _get_preview_actor(ui) as PlayerHumanoidRig
	if immediate_actor != null:
		allocation_report["cold_open_before_wait_body"] = _reopen_body_error(expected, _boundary_bone_channels(immediate_actor))
	var ready := await _reopen_await_bound(ui, side)
	_check_allocation(ready.ready, "cold_open_has_live_grip_binding", ready)
	if not ready.ready: return
	var actor := _get_preview_actor(ui) as PlayerHumanoidRig
	var body := _reopen_body_error(expected, _boundary_bone_channels(actor))
	var weapon := _reopen_weapon_error(expected, actor, _get_preview_held_item(ui))
	if legacy:
		# Missing provenance deliberately requests a new solve. Finger differences
		# are evidence, not proof that reusing an intact endpoint failed.
		allocation_report["legacy_recovered_endpoint_delta"] = {"body": body, "weapon": weapon}
	else:
		_check_allocation(body.valid and weapon.valid, "cold_open_preserves_saved_endpoint", {"body": body, "weapon": weapon})
	_check_allocation(BoundaryPose.node_pose_signature(node) == authored_before, "recovery_does_not_rewrite_authored_controls")
	var count_after := _reopen_solve_count()
	var expected_count := (2 if _reopen_support_expected(ui) else 1) if legacy else 0
	_check_allocation(count_after - solve_before == expected_count, "cold_open_acquisition_count", {"expected": expected_count, "actual": count_after - solve_before})
	for repeat: int in 3:
		ui.call("_refresh_preview_scene")
		await _wait_frames(4)
		_check_allocation((await _reopen_await_bound(ui, side)).ready, "refresh_%d_retains_live_binding" % repeat)
	_check_allocation(_reopen_solve_count() == count_after, "refresh_does_not_restart_acquisition")
	await _reopen_capture(ui)
	_check_allocation(_reopen_has_packet(node), "selected_node_has_durable_grip_after_open")
	if legacy:
		await _reopen_recover_all_legacy_nodes(ui, side)
		await _reopen_save(ui)
		var disk := _reopen_saved_draft(ui)
		var all_saved := disk != null
		if disk != null:
			for saved_node: CombatAnimationMotionNode in disk.get_action_motion_node_chain():
				all_saved = all_saved and _reopen_has_packet(saved_node)
		_check_allocation(all_saved, "all_legacy_recoveries_are_saved_for_next_process")
	else:
		if String(options.get("negative-contract", "false")) == "true": _reopen_negative_contract(ui, side)
		await _reopen_navigate_and_edit(ui, side, count_after)
		if String(options.get("playback", "false")) == "true": await _reopen_playback_and_save(ui, side)
		if String(options.get("manual-facing", "false")) == "true": await _reopen_manual_facing(ui, side)

func _reopen_manual_facing(ui: CombatAnimationStationUI, side: String) -> void:
	var draft: CombatAnimationDraft = ui.call("_get_active_draft")
	var target: CombatAnimationMotionNode = ui.call("_get_active_motion_node")
	var target_index := ui.get_selected_motion_node_index()
	var other_index := -1
	for candidate: CombatAnimationMotionNode in draft.get_action_motion_node_chain():
		if candidate != target:
			other_index = draft.motion_node_chain.find(candidate)
			break
	if other_index < 0:
		_check_allocation(false, "manual_facing_requires_second_node")
		return
	var solve_before := _reopen_solve_count()
	var changed := ui.apply_selected_motion_node_weapon_facing_delta(3.0, true)
	_check_allocation(changed and ui.preview_presenter.is_weapon_facing_reacquisition_required(ui.preview_subviewport),
		"manual_facing_edit_requires_explicit_acquisition")
	if not changed: return
	var authored_before := BoundaryPose.node_pose_signature(target)
	# Normal navigation owns the protected warning-aware recording interval;
	# background capture intentionally does not record an unacquired facing edit.
	var away := ui.select_motion_node(other_index)
	var recording := await _await_allocation_recording(ui)
	var away_bound := await _reopen_await_bound(ui, side)
	_check_allocation(away and recording.ready and away_bound.ready, "manual_facing_navigate_away_restores_other_grip",
		{"recording": recording, "bound": away_bound})
	if not away_bound.ready: return
	var expected := target.prepared_pose.duplicate(true)
	var has_manual_warning := false
	for warning: Dictionary in expected.get("quality_warnings", []):
		has_manual_warning = has_manual_warning or warning.get("reason", "") == "weapon_facing_requires_manual_reacquisition"
	_check_allocation(has_manual_warning and not _reopen_has_packet(target), "manual_facing_warning_recorded_without_acquired_packet")
	var back := ui.select_motion_node(target_index)
	recording = await _await_allocation_recording(ui)
	await _wait_frames(4)
	var manual := ui.preview_presenter.is_weapon_facing_reacquisition_required(ui.preview_subviewport)
	var pending := ui.preview_presenter.is_grip_acquisition_pending(ui.preview_subviewport)
	var actor := _get_preview_actor(ui) as PlayerHumanoidRig
	var body := _reopen_body_error(expected, _boundary_bone_channels(actor))
	var weapon := _reopen_weapon_error(expected, actor, _get_preview_held_item(ui))
	_check_allocation(back and recording.ready and manual and not pending and body.valid and weapon.valid
		and BoundaryPose.node_pose_signature(target) == authored_before,
		"manual_facing_navigation_preserves_pose_and_manual_trigger", {"manual_required": manual, "pending": pending,
			"body": body, "weapon": weapon, "recording": recording})
	ui.call("_refresh_preview_scene")
	await _wait_frames(4)
	_check_allocation(ui.preview_presenter.is_weapon_facing_reacquisition_required(ui.preview_subviewport)
		and _reopen_solve_count() == solve_before, "manual_facing_restore_and_refresh_do_not_auto_acquire",
		{"new_acquisitions": _reopen_solve_count() - solve_before})
	if ui.grip_reacquire_button == null:
		_check_allocation(false, "manual_facing_reacquire_button_exists")
		return
	# Invoke the actual button signal; neither owner nor presenter is driven directly.
	ui.grip_reacquire_button.pressed.emit()
	var acquired := await _reopen_await_bound(ui, side)
	_check_allocation(acquired.ready and not ui.preview_presenter.is_weapon_facing_reacquisition_required(ui.preview_subviewport),
		"manual_facing_Reacquire_button_restores_binding", acquired)
	if not acquired.ready: return
	await _reopen_capture(ui)
	var expected_solves := 2 if _reopen_support_expected(ui) else 1
	_check_allocation(_reopen_has_packet(target) and _reopen_solve_count() - solve_before == expected_solves,
		"manual_facing_explicit_reacquisition_captures_packet_once",
		{"expected_acquisitions": expected_solves, "actual_acquisitions": _reopen_solve_count() - solve_before})

func _reopen_recover_all_legacy_nodes(ui: CombatAnimationStationUI, side: String) -> void:
	var draft: CombatAnimationDraft = ui.call("_get_active_draft")
	var deltas: Array[Dictionary] = []
	for target: CombatAnimationMotionNode in draft.get_action_motion_node_chain():
		var index := draft.motion_node_chain.find(target)
		var had_packet := _reopen_has_packet(target)
		var expected := target.prepared_pose.duplicate(true)
		var authored_before := BoundaryPose.node_pose_signature(target)
		var count_before := _reopen_solve_count()
		var selected := ui.select_motion_node(index)
		var recording := await _await_allocation_recording(ui)
		var bound := await _reopen_await_bound(ui, side)
		_check_allocation(selected and recording.ready and bound.ready and ui.get_selected_motion_node_index() == index,
			"legacy_N%02d_navigation_recovers_live_grip" % index, {"recording": recording, "bound": bound})
		if not bound.ready: return
		var expected_solves := 0 if had_packet else (2 if _reopen_support_expected(ui) else 1)
		var count_after := _reopen_solve_count()
		_check_allocation(count_after - count_before == expected_solves, "legacy_N%02d_acquires_only_when_missing" % index,
			{"expected": expected_solves, "actual": count_after - count_before})
		_check_allocation(BoundaryPose.node_pose_signature(target) == authored_before, "legacy_N%02d_preserves_authored_controls" % index)
		var actor := _get_preview_actor(ui) as PlayerHumanoidRig
		deltas.append({"node_index": index, "body": _reopen_body_error(expected, _boundary_bone_channels(actor)),
			"weapon": _reopen_weapon_error(expected, actor, _get_preview_held_item(ui))})
		await _reopen_capture(ui)
		_check_allocation(_reopen_has_packet(target), "legacy_N%02d_captures_durable_grip" % index)
		ui.call("_refresh_preview_scene")
		await _wait_frames(4)
		var retained := await _reopen_await_bound(ui, side)
		_check_allocation(retained.ready and _reopen_solve_count() == count_after, "legacy_N%02d_refresh_does_not_repeat_solve" % index, retained)
	allocation_report["legacy_all_node_endpoint_deltas"] = deltas

func _reopen_playback_and_save(ui: CombatAnimationStationUI, side: String) -> void:
	var solve_before := _reopen_solve_count()
	var selected_index := ui.get_selected_motion_node_index()
	ui.call("_toggle_preview_playback")
	var deadline := Time.get_ticks_msec() + 60000
	while not ui.chain_player.is_playing() and Time.get_ticks_msec() < deadline:
		if not ui.preview_prepare_in_progress and not ui.is_motion_node_recording_pending(): break
		await _wait_frames(1)
	var started := ui.chain_player.is_playing()
	_check_allocation(started, "cold_read_F_starts", {"status": ui.footer_status_label.text})
	if not started: return
	await _wait_frames(2)
	if ui.chain_player.is_playing(): ui.call("_toggle_preview_playback")
	_check_allocation(not ui.chain_player.is_playing(), "cold_read_F_stops")
	# Exercise F-adjust directly. Reselecting first could hide a stop lifecycle
	# bug by restoring the grip in a separate user action.
	await _wait_frames(2)
	var moved := await _reopen_small_movements(ui, side)
	_check_allocation(moved.valid, "F_stop_immediate_tip_and_pommel_editable", moved)
	var bound := await _reopen_await_bound(ui, side, 2000)
	_check_allocation(bound.ready, "F_stop_immediate_edit_retains_live_binding", bound)
	if not moved.valid or not bound.ready:
		# Additional evidence only; this cannot make the preceding checks pass.
		var selected := ui.select_motion_node(selected_index)
		var recording := await _await_allocation_recording(ui)
		bound = await _reopen_await_bound(ui, side, 2000)
		allocation_report["F_stop_reselection_diagnostic"] = {"selected": selected, "recording": recording, "bound": bound}
		if not bound.ready: return
	await _reopen_capture(ui)
	await _reopen_save(ui)
	bound = await _reopen_await_bound(ui, side)
	_check_allocation(bound.ready, "Save_retains_live_grip_binding", bound)
	if bound.ready:
		moved = await _reopen_small_movements(ui, side)
		_check_allocation(moved.valid, "post_Save_tip_and_pommel_editable", moved)
	# Natural completion takes a different UI exit branch from pressing F again.
	ui.call("_toggle_preview_playback")
	deadline = Time.get_ticks_msec() + 60000
	while not ui.chain_player.is_playing() and Time.get_ticks_msec() < deadline:
		if not ui.preview_prepare_in_progress and not ui.is_motion_node_recording_pending(): break
		await _wait_frames(1)
	started = ui.chain_player.is_playing()
	_check_allocation(started, "second_F_starts")
	while ui.chain_player.is_playing() and Time.get_ticks_msec() < deadline:
		await _wait_frames(1)
	_check_allocation(started and not ui.chain_player.is_playing(), "F_finishes_naturally")
	bound = await _reopen_await_bound(ui, side, 2000)
	moved = await _reopen_small_movements(ui, side)
	_check_allocation(bound.ready and moved.valid, "F_finish_restores_binding_and_immediate_editing", {"bound": bound, "movement": moved})
	_check_allocation(_reopen_solve_count() == solve_before, "F_Save_edit_cycle_does_not_reacquire",
		{"actual_new_acquisitions": _reopen_solve_count() - solve_before})

func _reopen_navigate_and_edit(ui: CombatAnimationStationUI, side: String, solve_count: int) -> void:
	var draft: CombatAnimationDraft = ui.call("_get_active_draft")
	if draft == null or draft.get_action_motion_node_chain().size() < 2:
		_check_allocation(false, "navigation_requires_two_authored_nodes")
		return
	for index: int in [2, 1, 2]:
		var target: CombatAnimationMotionNode = draft.motion_node_chain[index]
		var expected := target.prepared_pose.duplicate(true)
		var selected := ui.select_motion_node(index)
		var recording := await _await_allocation_recording(ui)
		var bound := await _reopen_await_bound(ui, side)
		var body := _reopen_body_error(expected, _boundary_bone_channels(_get_preview_actor(ui) as PlayerHumanoidRig))
		_check_allocation(selected and recording.ready and bound.ready and ui.get_selected_motion_node_index() == index and body.valid,
			"navigate_N%02d_restores_endpoint_and_live_grip" % index, {"recording": recording, "bound": bound, "body": body})
		if not bound.ready: return
		var moved := await _reopen_small_movements(ui, side)
		_check_allocation(moved.valid, "navigate_N%02d_tip_and_pommel_editable" % index, moved)
		await _reopen_capture(ui)
		_check_allocation(_reopen_solve_count() == solve_count, "navigate_N%02d_does_not_acquire_again" % index)

func _reopen_negative_contract(ui: CombatAnimationStationUI, side: String) -> void:
	var actor := _get_preview_actor(ui) as PlayerHumanoidRig
	var prop := _get_preview_held_item(ui)
	var owner: Node = actor.get_node_or_null("PreparedGripAcquisition")
	var node: CombatAnimationMotionNode = ui.call("_get_active_motion_node")
	var saved: Dictionary = node.prepared_pose.get("acquired_grip", {})
	if owner == null or saved.is_empty():
		_check_allocation(false, "negative_contract_requires_restored_packet")
		return
	var slots: Array[StringName] = []
	slots.assign(saved.slots)
	var before := _reopen_live_stamp(actor, prop, owner, slots)
	var wrong_context := saved.duplicate(true)
	wrong_context.context_signature = "deliberately_stale_context"
	var rejected: Dictionary = owner.call("restore_authoring_grip", wrong_context, String(saved.context_signature), slots, _boundary_slot(side))
	_check_allocation(not rejected.get("valid", true) and before == _reopen_live_stamp(actor, prop, owner, slots), "wrong_context_rejected_without_scene_or_binding_changes", rejected)
	var station_key := &"preview_primary_grip_seat_local"
	var station: Vector3 = prop.get_meta(station_key)
	prop.set_meta(station_key, station + Vector3(0.001, 0.0, 0.0))
	rejected = owner.call("restore_authoring_grip", saved, String(saved.context_signature), slots, _boundary_slot(side))
	prop.set_meta(station_key, station)
	_check_allocation(not rejected.get("valid", true) and before == _reopen_live_stamp(actor, prop, owner, slots), "changed_handle_station_rejected_without_scene_or_binding_changes", rejected)
	var corrupt := saved.duplicate(true)
	corrupt.packets[slots[0]].digit_states = {}
	rejected = owner.call("restore_authoring_grip", corrupt, String(saved.context_signature), slots, _boundary_slot(side))
	_check_allocation(not rejected.get("valid", true) and before == _reopen_live_stamp(actor, prop, owner, slots), "incomplete_digit_packet_rejected_without_scene_or_binding_changes", rejected)
	corrupt = saved.duplicate(true)
	corrupt.packets[slots[0]].digit_states.middle.angles_rad = [{"invalid": "numeric channel"}, 0.0, 0.0]
	rejected = owner.call("restore_authoring_grip", corrupt, String(saved.context_signature), slots, _boundary_slot(side))
	_check_allocation(not rejected.get("valid", true) and before == _reopen_live_stamp(actor, prop, owner, slots), "malformed_angle_rejected_before_claim", rejected)

func _reopen_live_stamp(actor: PlayerHumanoidRig, prop: Node3D, owner: Node, slots: Array[StringName]) -> PackedByteArray:
	var bindings: Array = []
	for slot: StringName in slots:
		var binding: Dictionary = actor.planar_grip_pose_binding.relationship(slot, prop)
		bindings.append([slot, binding.get("hand_in_weapon"), binding.get("relationship_key"), actor.get_planar_grip_pose_state(slot).get("has_grip_pose", false)])
	return var_to_bytes([_boundary_bone_channels(actor), prop.global_transform, owner.get("_serial"), owner.get("_requests"), owner.call("status"), bindings])

func _reopen_small_movements(ui: CombatAnimationStationUI, side: String) -> Dictionary:
	var node: CombatAnimationMotionNode = ui.call("_get_active_motion_node")
	var display: CombatAnimationMotionNode = ui.call("_build_authoring_motion_node_baseline", node)
	var orbit := ui.preview_presenter.resolve_motion_node_tip_grip_orbit(ui.preview_subviewport, display, display.tip_position_local)
	if not orbit.get("available", false): return {"valid": false, "reason": "grip_orbit_unavailable", "orbit": orbit}
	var pivot: Vector3 = orbit.tip_grip_pivot_local
	var target := pivot + Basis(Vector3.RIGHT, deg_to_rad(1.0)) * (display.tip_position_local - pivot)
	var tip_changed := ui.set_selected_motion_node_tip_position(target, false)
	var tip_status := ui.footer_status_label.text
	await _wait_frames(3)
	display = ui.call("_build_authoring_motion_node_baseline", node)
	var pommel_changed := ui.set_selected_motion_node_pommel_position(display.pommel_position_local + Vector3(0.001 if side == "R" else -0.001, 0.0, 0.0), false)
	await _wait_frames(3)
	return {"valid": tip_changed and pommel_changed, "tip_changed": tip_changed,
		"pommel_changed": pommel_changed, "tip_status": tip_status, "status": ui.footer_status_label.text,
		"allocation": _live_allocation_details(ui, _get_preview_actor(ui) as PlayerHumanoidRig)}

func _reopen_await_bound(ui: CombatAnimationStationUI, side: String, timeout_ms: int = 45000) -> Dictionary:
	var started := Time.get_ticks_msec()
	var state := {}
	while Time.get_ticks_msec() - started < timeout_ms:
		await _wait_frames(1)
		var actor := _get_preview_actor(ui) as PlayerHumanoidRig
		var prop := _get_preview_held_item(ui)
		if actor == null or prop == null: continue
		var slots: Array[StringName] = [_boundary_slot(side)]
		if _reopen_support_expected(ui): slots.append(_boundary_slot("L" if side == "R" else "R"))
		var slot_states: Dictionary = {}
		var has_grip := true
		var has_binding := true
		for slot: StringName in slots:
			var grip := actor.get_planar_grip_pose_state(slot)
			var binding: Dictionary = actor.planar_grip_pose_binding.relationship(slot, prop)
			slot_states[slot] = {"has_grip_pose": grip.get("has_grip_pose", false), "has_binding": binding.get("hand_in_weapon") is Transform3D}
			has_grip = has_grip and slot_states[slot].has_grip_pose
			has_binding = has_binding and slot_states[slot].has_binding
		var pending := ui.preview_presenter.is_grip_acquisition_pending(ui.preview_subviewport)
		state = {"ready": has_grip and has_binding and not pending,
			"has_grip_pose": has_grip, "has_binding": has_binding, "slots": slot_states,
			"pending": pending, "wait_ms": Time.get_ticks_msec() - started, "status": ui.footer_status_label.text}
		if state.ready: return state
		var statuses := ui.preview_presenter.get_grip_acquisition_status(ui.preview_subviewport)
		for slot: StringName in slots:
			if not pending and String(statuses.get(slot, {}).get("status", "")) in ["unresolved", "unavailable", "cancelled"]:
				state["grip_status"] = statuses
				return state
	return state.merged({"ready": false, "timeout": true})

func _reopen_support_expected(ui: CombatAnimationStationUI) -> bool:
	var node: CombatAnimationMotionNode = ui.call("_get_active_motion_node")
	return node != null and (node.two_hand_state == CombatAnimationMotionNode.TWO_HAND_STATE_TWO_HAND or bool(node.prepared_pose.get("support_enabled", false)))

func _reopen_capture(ui: CombatAnimationStationUI) -> void:
	for attempt: int in 12:
		await _wait_frames(1)
		var captured := ui.capture_selected_prepared_pose(false, true)
		if captured.get("valid", false): return

func _reopen_save(ui: CombatAnimationStationUI) -> void:
	ui.call("_manual_save_active_editor_state")
	var deadline := Time.get_ticks_msec() + 60000
	while (ui.manual_save_in_progress or ui.is_motion_node_recording_pending()) and Time.get_ticks_msec() < deadline: await _wait_frames(1)
	_check_allocation(not ui.manual_save_in_progress and ui.footer_status_label.text.begins_with("Saved"), "Save_completed", {"status": ui.footer_status_label.text})

func _reopen_saved_draft(ui: CombatAnimationStationUI) -> CombatAnimationDraft:
	var saved := ResourceLoader.load(ui.active_wip_library.save_file_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as PlayerForgeWipLibraryState
	if saved == null: return null
	for item: CraftedItemWIP in saved.saved_wips:
		if item.wip_id == ui.active_wip.wip_id: return _reopen_find_draft(item)
	return null

func _reopen_find_draft(item: CraftedItemWIP) -> CombatAnimationDraft:
	if item.combat_animation_station_state == null: return null
	for draft: CombatAnimationDraft in item.combat_animation_station_state.skill_drafts:
		if draft.legal_slot_id == StringName(String(options.get("slot", "skill_slot_2"))): return draft
	return null

func _reopen_has_packet(node: CombatAnimationMotionNode) -> bool:
	return node != null and not (node.prepared_pose.get("acquired_grip", {}) as Dictionary).is_empty()

func _reopen_body_error(packet: Dictionary, actual: Dictionary) -> Dictionary:
	var result := _boundary_packet_error(packet, actual)
	var differences: Array[Dictionary] = []
	for index: int in (packet.get("bone_names", []) as Array).size():
		var name: String = String(packet.bone_names[index])
		if not actual.has(name):
			differences.append({"bone": name, "reason": "missing_live_bone"})
			continue
		var pose: Transform3D = actual[name]
		var rotation: Vector4 = packet.pose_rotations[index]
		var expected_rotation := Quaternion(rotation.x, rotation.y, rotation.z, rotation.w)
		var actual_rotation := pose.basis.orthonormalized().get_rotation_quaternion()
		var distance := pose.origin.distance_to(packet.pose_positions[index])
		var angle := rad_to_deg(_allocation_basis_error(pose.basis, Basis(expected_rotation)))
		var scale_error := pose.basis.get_scale().distance_to(packet.pose_scales[index])
		if distance > 0.000001 or angle > 0.001 or scale_error > 0.000001:
			differences.append({"bone": name, "position_error_m": distance, "rotation_error_degrees": angle,
				"scale_error": scale_error, "exceeds_existing_tolerance": distance > 0.00005 or angle > 0.025,
				"expected_local_rotation": [expected_rotation.x, expected_rotation.y, expected_rotation.z, expected_rotation.w],
				"actual_local_rotation": [actual_rotation.x, actual_rotation.y, actual_rotation.z, actual_rotation.w]})
	result["per_bone_differences"] = differences
	return result

func _reopen_weapon_error(packet: Dictionary, actor: PlayerHumanoidRig, prop: Node3D) -> Dictionary:
	var bone := actor.skeleton.find_bone(String(packet.get("reference_bone_name", "")))
	if bone < 0: return {"valid": false, "reason": "missing_reference_bone"}
	var reference := actor.skeleton.global_transform * actor.skeleton.get_bone_global_pose(bone)
	reference.basis = reference.basis.orthonormalized()
	var expected := reference * Transform3D(Basis(packet.weapon_rotation_reference_local).scaled(packet.weapon_scale_reference_local), packet.weapon_position_reference_local)
	var distance := expected.origin.distance_to(prop.global_position)
	var angle := rad_to_deg(_allocation_basis_error(expected.basis, prop.global_basis))
	return {"valid": distance <= 0.00005 and angle <= 0.025, "position_error_m": distance, "angle_error_degrees": angle}

func _reopen_solve_count() -> int:
	var file := FileAccess.open(reopen_trace_path, FileAccess.READ)
	if file == null: return 0
	var count := 0
	while not file.eof_reached():
		var line := file.get_line()
		if line.is_empty(): continue
		var row: Variant = JSON.parse_string(line)
		if row is Dictionary and row.get("kind") == "begin" and row.get("name") == "owner.await_solve": count += 1
	file.close()
	return count
