extends "res://tools/verify_skill_quality_warning_lifecycle.gd"

## Normal station controls on isolated libraries. Each main-hand case edits the
## free opposite arm. Run --hands=R,L --reuse-station=false, never source saves.
## Numeric free-hand placement and real elbow drag/flush/release are distinct.

func _run_thrust(ui: CombatAnimationStationUI, main_side: String, _elevation: float) -> Dictionary:
	allocation_report = {"complete": false, "checks": [], "main_side": main_side,
		"scope": "Isolated normal station free-hand setter, elbow pointer drag/release, R, prepared-node reselection and Save/resource reload. No original save writes."}
	if ui.active_wip_library == null or not ui.active_wip_library.save_file_path.begins_with(output_dir + "/isolated_"):
		return allocation_report.merged({"reason": "isolated_library_required"})
	ui.set_meta("verification_skip_persistence", false)
	if not ui.reset_active_draft_to_baseline(): return allocation_report.merged({"reason": "reset_failed"})
	var ready := await _await_recorded_reset_baseline(ui)
	_check_allocation(ready.ready, "baseline_ready", ready)
	if not ready.ready: return _complete_allocation()
	var actor := _get_preview_actor(ui) as PlayerHumanoidRig
	var prop := _get_preview_held_item(ui)
	var side := "L" if main_side == "R" else "R"
	var slot := _boundary_slot(side)
	var node: CombatAnimationMotionNode = ui.call("_get_active_motion_node")
	ui.set_selected_motion_node_transition_duration(0.2, false)
	var segment: Dictionary = ui.preview_presenter.resolve_hand_proxy_authoring_segment_state(ui.preview_subviewport, node, slot)
	_check_allocation(segment.get("available", false), "free_hand_segment_available", segment)
	if not segment.get("available", false): return _complete_allocation()
	var before := _independent_snapshot(actor, prop, side)
	var delta := Vector3(0.015 if side == "L" else -0.015, 0.02, -0.01)
	var moved := ui.set_selected_motion_node_hand_proxy_segment(slot, segment.tip_position_local + delta, segment.pommel_position_local + delta, false)
	var immediate := _independent_compare(before, _independent_snapshot(actor, prop, side))
	_check_allocation(moved and immediate.fixed and immediate.selected_moved, "free_hand_immediate_moves_only_selected_arm", immediate)
	await _wait_frames(3)
	var settled := _independent_compare(before, _independent_snapshot(actor, prop, side))
	_check_allocation(settled.fixed and settled.selected_moved, "free_hand_keeps_other_arm_weapon_and_shared_ancestors_after_frames", settled)
	var elbow := await _independent_elbow_drag(ui, actor, prop, side)
	allocation_report.elbow = elbow
	_check_allocation(elbow.get("valid", false), "elbow_pointer_drag_and_release_are_independent", elbow)
	if not elbow.get("valid", false): return _complete_allocation()
	var expected := _boundary_bone_channels(actor)
	var frozen := _independent_snapshot(actor, prop, side)
	var added := ui.insert_motion_node_after_selection()
	var recording := await _await_allocation_recording(ui)
	var packet := _boundary_packet_error(node.prepared_pose, expected)
	_check_allocation(added and recording.ready and packet.valid, "R_preserves_independent_arm_endpoint", packet.merged(recording))
	_check_allocation(_independent_compare(frozen, _independent_snapshot(actor, prop, side)).fixed, "R_keeps_frozen_body_and_weapon")
	if not recording.ready: return _complete_allocation()
	var selected := ui.select_motion_node(1)
	var selection_recording := await _await_allocation_recording(ui)
	await _wait_frames(3)
	var restored := _boundary_packet_error(node.prepared_pose, _boundary_bone_channels(actor))
	_check_allocation(selected and selection_recording.ready and restored.valid, "prepared_reselection_restores_exact_endpoint", restored)
	_check_allocation(_independent_compare(frozen, _independent_snapshot(actor, prop, side)).fixed, "prepared_reselection_keeps_frozen_body_and_weapon")
	ui.call("_manual_save_active_editor_state")
	var deadline := Time.get_ticks_msec() + 60000
	while (ui.manual_save_in_progress or ui.is_motion_node_recording_pending()) and Time.get_ticks_msec() < deadline: await _wait_frames(1)
	_check_allocation(not ui.manual_save_in_progress and not ui.footer_status_label.text.begins_with("Not saved"), "isolated_Save_completes", {"status": ui.footer_status_label.text})
	var save_end_pose := _independent_snapshot(actor, prop, main_side)
	await _wait_frames(3)
	allocation_report.save_settling = _independent_compare(save_end_pose, _independent_snapshot(actor, prop, main_side))
	var loaded := ResourceLoader.load(ui.active_wip_library.save_file_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as PlayerForgeWipLibraryState
	var disk_match := false
	if loaded != null:
		for weapon: CraftedItemWIP in loaded.saved_wips:
			if weapon.wip_id != ui.active_wip.wip_id: continue
			for draft: CombatAnimationDraft in weapon.combat_animation_station_state.skill_drafts:
				if draft.legal_slot_id != StringName(String(options.get("slot", "skill_slot_2"))): continue
				for stored: CombatAnimationMotionNode in draft.get_action_motion_node_chain():
					if stored.node_id == node.node_id and _boundary_packet_error(stored.prepared_pose, expected).valid:
						disk_match = true
	_check_allocation(disk_match, "disk_reload_retains_recorded_independent_endpoint")
	# Prepared reselection clears live grip owners. Editing the gripping elbow
	# must still retain the captured wrist/weapon mate, without reacquisition.
	var mate := await _independent_prepared_grip_elbow(ui, actor, prop, main_side)
	allocation_report.prepared_grip_elbow = mate
	_check_allocation(mate.valid, "prepared_grip_elbow_retains_wrist_weapon_relationship", mate)
	return _complete_allocation()

func _independent_prepared_grip_elbow(ui: CombatAnimationStationUI, actor: PlayerHumanoidRig, prop: Node3D, side: String) -> Dictionary:
	var sk := actor.skeleton
	var hand := sk.find_bone("CC_Base_" + side + "_Hand")
	var before_mate := prop.global_transform.affine_inverse() * sk.global_transform * sk.get_bone_global_pose(hand)
	var before_weapon := prop.global_transform
	# The held item belongs to this edited arm. Only the other arm and shared
	# ancestors are frozen here; free-hand edits above also freeze the weapon.
	var before := _independent_snapshot(actor, prop, side, false)
	var node: CombatAnimationMotionNode = ui.call("_get_active_motion_node")
	var prior_roll := node.left_upperarm_roll_degrees if side == "L" else node.right_upperarm_roll_degrees
	var had_live_grip: bool = actor.get_planar_grip_pose_state(_boundary_slot(side)).get("has_grip_pose", false)
	var staged := String(options.get("diagnose-grip-elbow-stages", "false")) == "true"
	var changed := ui.set_selected_motion_node_upperarm_roll(_boundary_slot(side), prior_roll + 10.0, false, true, true, not staged, true)
	var stages: Dictionary = {}
	if staged:
		stages["after_fields"] = _independent_compare(before, _independent_snapshot(actor, prop, side, false))
		stages["helper_result"] = ui.preview_presenter.apply_independent_arm_edit(ui.preview_subviewport, node, _boundary_slot(side), false, false)
		stages["after_helper"] = _independent_compare(before, _independent_snapshot(actor, prop, side, false))
		ui.call("_refresh_preview_scene")
		stages["after_refresh"] = _independent_compare(before, _independent_snapshot(actor, prop, side, false))
	var immediate := _independent_compare(before, _independent_snapshot(actor, prop, side, false))
	var immediate_result: Dictionary = _get_preview_root(ui).get_meta("independent_arm_edit_result", {})
	var retained_meta: Dictionary = _get_preview_root(ui).get_meta("retained_independent_arm_edit", {})
	var immediate_retention: Dictionary = _get_preview_root(ui).get_meta("independent_arm_retention_validation", {}).duplicate(true)
	var immediate_authority := actor.has_authoring_independent_arm_pose_authority(_boundary_slot(side))
	await _wait_frames(3)
	var after_mate := prop.global_transform.affine_inverse() * sk.global_transform * sk.get_bone_global_pose(hand)
	var position_error := before_mate.origin.distance_to(after_mate.origin)
	var angle_error := _allocation_basis_error(before_mate.basis, after_mate.basis)
	var scope := _independent_compare(before, _independent_snapshot(actor, prop, side, false))
	return {"valid": changed and scope.fixed and scope.selected_moved and position_error <= 0.00005 and angle_error <= deg_to_rad(0.025),
		"changed": changed, "had_live_grip_pose": had_live_grip, "scope": scope,
		"immediate": immediate, "immediate_result": immediate_result, "retained_meta_present": not retained_meta.is_empty(), "stages": stages,
		"immediate_retention": immediate_retention, "immediate_authority": immediate_authority,
		"settled_retention": _get_preview_root(ui).get_meta("independent_arm_retention_validation", {}),
		"settled_authority": actor.has_authoring_independent_arm_pose_authority(_boundary_slot(side)),
		"wrist_weapon_position_error_m": position_error, "wrist_weapon_angle_error_degrees": rad_to_deg(angle_error),
		"active_weapon_motion_informational": {"position_m": before_weapon.origin.distance_to(prop.global_position), "angle_degrees": rad_to_deg(_allocation_basis_error(before_weapon.basis, prop.global_basis))},
		"before_wrist_in_weapon": before_mate, "after_wrist_in_weapon": after_mate,
		"status": ui.footer_status_label.text}

func _independent_elbow_drag(ui: CombatAnimationStationUI, actor: PlayerHumanoidRig, prop: Node3D, side: String) -> Dictionary:
	var slot := _boundary_slot(side)
	var focus := &"left_arm_roll" if side == "L" else &"right_arm_roll"
	for step: int in 12:
		if ui.session_state.current_focus == focus: break
		ui.call("_cycle_focus")
	var states: Dictionary = _get_preview_root(ui).get_meta("upperarm_roll_gizmo_state", {})
	var state: Dictionary = states.get(slot, {})
	if state.is_empty(): return {"valid": false, "reason": "elbow_gizmo_missing"}
	var center: Vector3 = state.center_global
	var axis: Vector3 = state.axis_global.normalized()
	var initial: Vector3 = state.initial_normal_global
	var camera: Camera3D = ui.call("_get_preview_camera")
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 1.55
	camera.global_position = center + axis * 2.0
	var up := actor.global_basis.y.normalized()
	if absf(up.dot(axis)) > 0.95: up = actor.global_basis.x.normalized()
	camera.look_at(center, up)
	var node: CombatAnimationMotionNode = ui.call("_get_active_motion_node")
	var display: CombatAnimationMotionNode = ui.call("_build_authoring_motion_node_baseline", node)
	ui.call("_begin_preview_drag_override", display, state.drag_target)
	var press := camera.unproject_position(center + initial * float(state.radius_meters) * 0.999)
	ui.motion_node_editor.begin_upperarm_roll_drag(state.drag_target, state, camera, press)
	var before := _independent_snapshot(actor, prop, side)
	var target := Basis(axis, deg_to_rad(25.0)) * initial
	var pointer := camera.unproject_position(center + target * float(state.radius_meters) * 0.999)
	ui.call("_handle_preview_drag", pointer)
	ui.call("_flush_pending_preview_drag_refresh")
	var deadline := Time.get_ticks_msec() + 2000
	while ui.preview_drag_refresh_pending and Time.get_ticks_msec() < deadline: await process_frame
	var held := _independent_compare(before, _independent_snapshot(actor, prop, side))
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.position = pointer
	ui.call("_on_preview_gui_input", release)
	await _wait_frames(3)
	var released := _independent_compare(before, _independent_snapshot(actor, prop, side))
	return {"valid": not ui.preview_drag_refresh_pending and held.fixed and held.selected_moved and released.fixed and released.selected_moved,
		"held": held, "released": released, "status": ui.footer_status_label.text}

func _independent_snapshot(actor: PlayerHumanoidRig, prop: Node3D, side: String, freeze_weapon: bool = true) -> Dictionary:
	var sk := actor.skeleton
	var selected_upper := sk.find_bone("CC_Base_" + side + "_Upperarm")
	var other_upper := sk.find_bone("CC_Base_" + ("R" if side == "L" else "L") + "_Upperarm")
	var selected: Dictionary = {}
	var frozen: Dictionary = {}
	for bone: int in sk.get_bone_count():
		var cursor := bone
		while cursor >= 0:
			if cursor == selected_upper: selected[sk.get_bone_name(bone)] = sk.global_transform * sk.get_bone_global_pose(bone)
			if cursor == other_upper: frozen[sk.get_bone_name(bone)] = sk.global_transform * sk.get_bone_global_pose(bone)
			cursor = sk.get_bone_parent(cursor)
	var parent := sk.get_bone_parent(sk.find_bone("CC_Base_" + side + "_Clavicle"))
	while parent >= 0:
		frozen[sk.get_bone_name(parent)] = sk.global_transform * sk.get_bone_global_pose(parent)
		parent = sk.get_bone_parent(parent)
	if freeze_weapon: frozen["weapon"] = prop.global_transform
	return {"selected": selected, "frozen": frozen}

func _independent_compare(before: Dictionary, after: Dictionary) -> Dictionary:
	var errors := {"selected_position_m": 0.0, "selected_angle_rad": 0.0, "frozen_position_m": 0.0, "frozen_angle_rad": 0.0}
	for group: String in ["selected", "frozen"]:
		for key: Variant in before[group]:
			var a: Transform3D = before[group][key]
			var b: Transform3D = after[group][key]
			var position_error := a.origin.distance_to(b.origin)
			var angle_error := _allocation_basis_error(a.basis, b.basis)
			if position_error > errors[group + "_position_m"]:
				errors[group + "_peak_position_key"] = String(key)
				errors[group + "_position_m"] = position_error
			if angle_error > errors[group + "_angle_rad"]:
				errors[group + "_peak_angle_key"] = String(key)
				errors[group + "_angle_rad"] = angle_error
			if group == "frozen" and (position_error > 0.00005 or angle_error > deg_to_rad(0.025)):
				if not errors.has("changed_frozen"): errors["changed_frozen"] = []
				errors.changed_frozen.append({"component": String(key), "position_m": position_error, "angle_degrees": rad_to_deg(angle_error)})
	errors["fixed"] = errors.frozen_position_m <= 0.00005 and errors.frozen_angle_rad <= deg_to_rad(0.025)
	errors["selected_moved"] = errors.selected_position_m > 0.0001 or errors.selected_angle_rad > 0.001
	return errors
