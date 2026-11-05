extends "res://tools/diagnose_skill_crafter_weapon_motion_allocation.gd"

const BoundaryPose = preload("res://core/models/combat_prepared_pose.gd")
var boundary_contact_local := Vector3.ZERO
var boundary_initial_contact_world := Vector3.ZERO
var boundary_hand_in_weapon := Transform3D.IDENTITY
var boundary_clavicle_ancestors: Dictionary = {}
var boundary_recovery_fixture: Node3D
var boundary_original_wrist_failures: Dictionary = {}

## Bounded follow-up to the small-motion verifier: open the user's saved skill
## normally, then walk toward a boundary and reverse from the actual accepted
## state. No Reset unless explicitly requested; never writes source player files.
## --lifecycle=true additionally exercises R/F/Save and reloads the isolated copy.
## --weapon=Broken_Balde_v1 --slot=skill_slot_2 --hands=R --elevations=0
## --out=<fresh-dir> --steps=36 --step-degrees=5 --axis=hinge --reset=false

func _run_thrust(ui: CombatAnimationStationUI, side: String, _elevation: float) -> Dictionary:
	var report := {"complete": false, "side": side, "requests": [],
		"reset_requested": String(options.get("reset", "false")) == "true",
		"scope": "Unchanged player library cloned; repeated Tip inputs, reversal and Pommel. Optional lifecycle=true runs R/F/Save only on the isolated copy; original player files remain read-only."}
	if report.reset_requested:
		ui.reset_active_draft_to_baseline()
		report.readiness = await _await_recorded_reset_baseline(ui)
	else:
		var started := Time.get_ticks_msec()
		while (ui.preview_presenter.is_grip_acquisition_pending(ui.preview_subviewport) or ui.is_motion_node_recording_pending()) and Time.get_ticks_msec() - started < 45000:
			await _wait_frames(1)
		await _wait_frames(3)
		report.readiness = {"wait_ms": Time.get_ticks_msec() - started,
			"acquisition_pending": ui.preview_presenter.is_grip_acquisition_pending(ui.preview_subviewport),
			"recording_pending": ui.is_motion_node_recording_pending(), "status": ui.footer_status_label.text}
	var actor := _get_preview_actor(ui) as PlayerHumanoidRig
	var prop := _get_preview_held_item(ui)
	var node: CombatAnimationMotionNode = ui.call("_get_active_motion_node")
	if actor == null or prop == null or node == null:
		return report.merged({"reason": "missing_opened_scene"})
	if not prop.has_meta("primary_grip_contact_local"):
		return report.merged({"reason": "missing_acquired_contact_reference"})
	boundary_contact_local = prop.get_meta("primary_grip_contact_local")
	boundary_initial_contact_world = prop.global_transform * boundary_contact_local
	var hand_index := actor.skeleton.find_bone("CC_Base_" + side + "_Hand")
	boundary_hand_in_weapon = prop.global_transform.affine_inverse() * actor.skeleton.global_transform * actor.skeleton.get_bone_global_pose(hand_index)
	boundary_clavicle_ancestors.clear()
	var ancestor := actor.skeleton.get_bone_parent(actor.skeleton.find_bone("CC_Base_" + side + "_Clavicle"))
	while ancestor >= 0:
		boundary_clavicle_ancestors[ancestor] = actor.skeleton.get_bone_pose(ancestor)
		ancestor = actor.skeleton.get_bone_parent(ancestor)
	report.initial = _boundary_snapshot(ui, actor, prop, side)
	if String(options.get("recoverability-guards", "false")) == "true":
		report.recovery_guards_before = _boundary_install_recovery_guards(ui, actor, prop, side)
	if String(options.get("lifecycle", "false")) == "true":
		ui.set_selected_motion_node_transition_duration(0.2, false)
	if String(options.get("gesture", "numeric")) == "held":
		return await _boundary_held_mouse(ui, actor, prop, side, report)
	var trajectory: Node3D = ui.call("_get_preview_trajectory_root")
	var axis := Vector3.RIGHT
	var axis_name := String(options.get("axis", "hinge"))
	if axis_name == "y": axis = Vector3.UP
	elif axis_name == "z": axis = Vector3.BACK
	elif axis_name == "hinge":
		var calibration: Dictionary = actor.capture_wrist_constraint_calibration(_boundary_slot(side))
		var hand := actor.skeleton.find_bone("CC_Base_" + side + "_Hand")
		var world_hand := actor.skeleton.global_transform * actor.skeleton.get_bone_global_pose(hand)
		if calibration.has("anatomical_in_hand_bone"):
			axis = (trajectory.global_basis.inverse() * (world_hand.basis.orthonormalized() * calibration.anatomical_in_hand_bone).x).normalized()
	var increment := float(options.get("step-degrees", "5"))
	var max_steps := clampi(int(options.get("steps", "36")), 1, 48)
	report.axis_local = axis
	report.step_degrees = increment
	var accepted := 0
	var first_block := -1
	for index: int in max_steps:
		var sample := await _boundary_tip(ui, actor, prop, side, axis, increment, "forward_%d" % index)
		report.requests.append(sample)
		if sample.changed: accepted += 1
		else:
			first_block = index
			break
	# Reversal and a different control must be attempted without Reset or a grip
	# reacquisition, otherwise a poisoned accepted pose would be hidden.
	for degrees: float in [-increment, -1.0, 1.0]:
		report.requests.append(await _boundary_tip(ui, actor, prop, side, axis, degrees, "recovery_tip_%s" % degrees))
	node = ui.call("_get_active_motion_node")
	var display: CombatAnimationMotionNode = ui.call("_build_authoring_motion_node_baseline", node)
	var before := _boundary_snapshot(ui, actor, prop, side)
	var started := Time.get_ticks_usec()
	var changed := ui.set_selected_motion_node_pommel_position(display.pommel_position_local + Vector3(0.002, 0.0, 0.0), false)
	var pommel_ms := (Time.get_ticks_usec() - started) / 1000.0
	await _wait_frames(3)
	var pommel := _live_allocation_details(ui, actor).merged({"stage": "recovery_pommel", "changed": changed, "setter_ms": pommel_ms,
		"before": before, "after": _boundary_snapshot(ui, actor, prop, side)})
	report.requests.append(pommel)
	_write_boundary_row(pommel)
	report.accepted_forward_steps = accepted
	report.first_block_index = first_block
	report.complete = true
	print("BOUNDARY_SEQUENCE complete side=%s accepted=%d first_block=%d" % [side, accepted, first_block])
	return report

func _boundary_held_mouse(ui: CombatAnimationStationUI, actor: PlayerHumanoidRig, prop: Node3D,
		side: String, report: Dictionary) -> Dictionary:
	ui.session_state.current_focus = CombatAnimationSessionState.FOCUS_TIP
	var node: CombatAnimationMotionNode = ui.call("_get_active_motion_node")
	var display: CombatAnimationMotionNode = ui.call("_build_display_motion_node_for_viewport_pick", node)
	var camera: Camera3D = ui.call("_get_preview_camera")
	var trajectory: Node3D = ui.call("_get_preview_trajectory_root")
	var pointer := camera.unproject_position(trajectory.to_global(display.tip_position_local))
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = pointer
	ui.call("_on_preview_gui_input", press)
	report.picked_target = String(ui.motion_node_editor.get_drag_target())
	var count := clampi(int(options.get("steps", "20")), 4, 24)
	var pixels := float(options.get("pixels", "4"))
	for index: int in count:
		var before := _boundary_snapshot(ui, actor, prop, side)
		var delta := Vector2(pixels if index < count / 2 else -pixels, 0)
		if String(options.get("screen-axis", "x")) == "y": delta = Vector2(0, delta.x)
		pointer += delta
		var motion := InputEventMouseMotion.new()
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		motion.position = pointer
		motion.relative = delta
		var started := Time.get_ticks_msec()
		var input_started := Time.get_ticks_usec()
		ui.call("_on_preview_gui_input", motion)
		var input_ms := (Time.get_ticks_usec() - input_started) / 1000.0
		var immediate := _boundary_snapshot(ui, actor, prop, side)
		while Time.get_ticks_msec() - started < 100:
			await _wait_frames(1)
		ui.call("_flush_pending_preview_drag_refresh")
		await _wait_frames(3)
		var row := _live_allocation_details(ui, actor).merged({"stage": "held_%d" % index,
			"pointer": pointer, "relative": delta, "input_handler_ms": input_ms, "before": before, "immediate": immediate,
			"after": _boundary_snapshot(ui, actor, prop, side),
			"guard_active": ui.preview_drag_forearm_guard_active,
			"drag_failure": ui.preview_drag_forearm_failure.duplicate(true),
			"refresh_pending": ui.preview_drag_refresh_pending})
		report.requests.append(row)
		_write_boundary_row(row)
		print("BOUNDARY_HELD %d status=%s reason=%s UI=%s" % [index, row.allocation.get("status", ""), row.allocation.get("reason", ""), row.status])
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.position = pointer
	ui.call("_on_preview_gui_input", release)
	await _wait_frames(3)
	report.after_release = _boundary_snapshot(ui, actor, prop, side)
	# Start a second real pointer gesture after committing the first override.
	# This exercises both exact-copy boundaries without another Reset or solve.
	node = ui.call("_get_active_motion_node")
	display = ui.call("_build_display_motion_node_for_viewport_pick", node)
	pointer = camera.unproject_position(trajectory.to_global(display.tip_position_local))
	press = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = pointer
	ui.call("_on_preview_gui_input", press)
	for direction: float in [1.0, -1.0]:
		var delta := Vector2(direction * pixels, 0)
		if String(options.get("screen-axis", "x")) == "y": delta = Vector2(0, delta.x)
		pointer += delta
		var motion := InputEventMouseMotion.new()
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		motion.position = pointer
		motion.relative = delta
		var before := _boundary_snapshot(ui, actor, prop, side)
		var started := Time.get_ticks_msec()
		ui.call("_on_preview_gui_input", motion)
		while Time.get_ticks_msec() - started < 100:
			await _wait_frames(1)
		ui.call("_flush_pending_preview_drag_refresh")
		await _wait_frames(3)
		var row := _live_allocation_details(ui, actor).merged({"stage": "regrab_%s" % direction,
			"before": before, "after": _boundary_snapshot(ui, actor, prop, side),
			"drag_failure": ui.preview_drag_forearm_failure.duplicate(true)})
		report.requests.append(row)
		_write_boundary_row(row)
	release = InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.position = pointer
	ui.call("_on_preview_gui_input", release)
	await _wait_frames(3)
	report.after_regrab_release = _boundary_snapshot(ui, actor, prop, side)
	if String(options.get("expect-free-contact", "false")) == "true":
		var metrics := {"accepted_steps": 0, "first_step_contact_delta_m": 0.0,
			"max_contact_delta_m": 0.0, "max_hand_position_error_m": 0.0, "max_hand_angle_error_degrees": 0.0,
			"max_ancestor_position_error_m": 0.0, "max_ancestor_angle_error_degrees": 0.0,
			"position_constrained_requests": 0, "authority_losses": 0, "drag_failures": 0}
		for sample: Dictionary in report.requests:
			if not String(sample.stage).begins_with("held_") and not String(sample.stage).begins_with("regrab_"): continue
			if not sample.get("drag_failure", {}).is_empty(): metrics.drag_failures += 1
			if sample.allocation.get("valid", false) and sample.get("drag_failure", {}).is_empty(): metrics.accepted_steps += 1
			if not sample.after.has_motion_authority or not sample.after.manipulator_matches_effective: metrics.authority_losses += 1
			if sample.allocation.get("position_constrained", true): metrics.position_constrained_requests += 1
			if sample.stage == "held_0": metrics.first_step_contact_delta_m = sample.after.contact_delta_from_start_m
			metrics.max_contact_delta_m = maxf(metrics.max_contact_delta_m, sample.after.contact_delta_from_start_m)
			metrics.max_hand_position_error_m = maxf(metrics.max_hand_position_error_m, sample.after.hand_position_error_m)
			metrics.max_hand_angle_error_degrees = maxf(metrics.max_hand_angle_error_degrees, sample.after.hand_angle_error_degrees)
			metrics.max_ancestor_position_error_m = maxf(metrics.max_ancestor_position_error_m, sample.after.ancestor_position_error_m)
			metrics.max_ancestor_angle_error_degrees = maxf(metrics.max_ancestor_angle_error_degrees, sample.after.ancestor_angle_error_degrees)
		metrics.valid = metrics.first_step_contact_delta_m > 0.00005 and metrics.accepted_steps > 0 and metrics.authority_losses == 0 and metrics.drag_failures == 0 and metrics.position_constrained_requests == 0 and metrics.max_hand_position_error_m <= 0.00005 and metrics.max_hand_angle_error_degrees <= 0.025 and metrics.max_ancestor_position_error_m <= 0.0000001 and metrics.max_ancestor_angle_error_degrees <= 0.0001
		report.free_contact = metrics
	node = ui.call("_get_active_motion_node")
	display = ui.call("_build_authoring_motion_node_baseline", node)
	var pommel_started := Time.get_ticks_usec()
	var pommel_ok := ui.set_selected_motion_node_pommel_position(display.pommel_position_local + Vector3(0.002, 0, 0), false)
	var pommel_ms := (Time.get_ticks_usec() - pommel_started) / 1000.0
	await _wait_frames(3)
	var recovery := _live_allocation_details(ui, actor).merged({"stage": "held_recovery_pommel", "changed": pommel_ok, "setter_ms": pommel_ms,
		"after": _boundary_snapshot(ui, actor, prop, side)})
	report.requests.append(recovery)
	_write_boundary_row(recovery)
	report.complete = true
	if report.has("free_contact"): report.complete = report.free_contact.valid
	if options.has("warning-fixture"):
		report.warning_ui = _boundary_warning_ui(ui, actor)
		report.complete = report.complete and report.warning_ui.valid
	if report.has("recovery_guards_before"):
		report.recovery_guards_after = _boundary_finish_recovery_guards(ui, actor, prop, report)
		report.complete = report.complete and report.recovery_guards_after.valid
	if String(options.get("lifecycle", "false")) == "true":
		report.lifecycle = await _boundary_lifecycle(ui, actor, prop, side)
		report.complete = report.lifecycle.complete
	print("BOUNDARY_HELD complete side=%s pommel=%s" % [side, pommel_ok])
	return report

func _boundary_install_recovery_guards(ui: CombatAnimationStationUI, actor: PlayerHumanoidRig,
		prop: Node3D, side: String) -> Dictionary:
	boundary_original_wrist_failures = (actor.get("_wrist_motion_failures") as Dictionary).duplicate(true)
	var failures := boundary_original_wrist_failures.duplicate(true)
	var inactive: StringName = &"hand_left" if side == "R" else &"hand_right"
	failures[inactive] = {"valid": false, "reason": "diagnostic_stale_inactive_wrist_failure", "hand_slot": inactive}
	actor.set("_wrist_motion_failures", failures)
	var body: Node3D = actor.call("get_body_restriction_root")
	if body == null: return {"valid": false, "reason": "missing_body_restriction_root"}
	# Runtime-only explicit collision. Physics interactions are disabled; the
	# existing sampled legality query must still see this restriction shape.
	boundary_recovery_fixture = Node3D.new()
	boundary_recovery_fixture.name = "BoundaryRecoveryCollisionFixture"
	boundary_recovery_fixture.set_meta("proxy_region", "diagnostic_existing_collision")
	body.add_child(boundary_recovery_fixture)
	boundary_recovery_fixture.global_transform = Transform3D(Basis.IDENTITY, prop.global_position)
	var area := Area3D.new()
	area.name = "RestrictionArea"
	area.collision_layer = 0
	area.collision_mask = 0
	area.monitoring = false
	area.monitorable = false
	boundary_recovery_fixture.add_child(area)
	var shape := CollisionShape3D.new()
	shape.name = "RestrictionShape"
	var box := BoxShape3D.new()
	box.size = Vector3.ONE * 4.0
	shape.shape = box
	area.add_child(shape)
	return _boundary_recovery_guard_observation(ui, actor, prop)

func _boundary_recovery_guard_observation(ui: CombatAnimationStationUI, actor: PlayerHumanoidRig,
		prop: Node3D) -> Dictionary:
	var pose: Dictionary = ui.preview_presenter.call("_evaluate_preview_collision_pose", actor, prop, prop.global_transform)
	var frames: Array[Transform3D] = [prop.global_transform]
	var path: Dictionary = ui.preview_presenter.collision_legality_resolver.evaluate_weapon_path(
		actor.call("get_body_restriction_root"), prop, frames, ui.preview_presenter.hand_target_constraint_solver)
	var strict: Dictionary = actor.validate_authoring_forearm_hand_indexing()
	return {"valid": not pose.get("legal", true) and not path.get("legal", true) and not strict.get("valid", true),
		"pose_query": pose, "path_query": path, "strict_wrist_query": strict}

func _boundary_finish_recovery_guards(ui: CombatAnimationStationUI, actor: PlayerHumanoidRig,
		prop: Node3D, report: Dictionary) -> Dictionary:
	var result := _boundary_recovery_guard_observation(ui, actor, prop)
	var accepted := 0
	var failures := 0
	for sample: Dictionary in report.requests:
		if sample.allocation.get("valid", false) and sample.get("drag_failure", {}).is_empty(): accepted += 1
		else: failures += 1
	result["accepted_requests"] = accepted
	result["failed_requests"] = failures
	result["authority_retained"] = actor.has_authoring_weapon_motion_authority()
	result["valid"] = bool(result.valid) and report.recovery_guards_before.get("valid", false) and accepted == report.requests.size() and failures == 0 and result.authority_retained
	result["scope"] = "Real station held input/release/regrab/Pommel with injected stale inactive-wrist flag and runtime collision fixture. Existing pose/path queries remain illegal; original saved data untouched."
	if is_instance_valid(boundary_recovery_fixture): boundary_recovery_fixture.free()
	actor.set("_wrist_motion_failures", boundary_original_wrist_failures)
	return result

func _boundary_warning_ui(ui: CombatAnimationStationUI, actor: PlayerHumanoidRig) -> Dictionary:
	# UI routing check only: the imported-rig verifier separately proves real
	# invalid-pose correction. Reuse its emitted warning without deforming this
	# station fixture or changing any authored/saved node.
	var fixture: Variant = JSON.parse_string(FileAccess.get_file_as_string(String(options["warning-fixture"])))
	var warning := {}
	if fixture is Dictionary:
		for sample: Dictionary in fixture.get("samples", []):
			if sample.get("case", "") == "outside_shoulder_correction_0":
				warning = sample.get("result", {}).get("pose_warning", {})
	if warning.is_empty(): return {"valid": false, "reason": "missing_real_rig_warning_fixture"}
	var preview: Node3D = _get_preview_root(ui)
	var original: Dictionary = preview.get_meta("weapon_motion_allocation_result", {}).duplicate(true)
	var original_text := ui.footer_status_label.text
	var original_bones := var_to_bytes(_boundary_bone_channels(actor))
	preview.set_meta("weapon_motion_allocation_result", original.merged({"pose_warning": warning}, true))
	ui.call("_refresh_weapon_motion_pose_warning")
	var shown := ui.footer_status_label.text == "Pose outside anatomical limits. Movement remains available to adjust it."
	preview.set_meta("weapon_motion_allocation_result", original.merged({"pose_warning": {}}, true))
	ui.call("_refresh_weapon_motion_pose_warning")
	var cleared := ui.footer_status_label.text == "Position updated."
	var preserved := var_to_bytes(_boundary_bone_channels(actor)) == original_bones and actor.has_authoring_weapon_motion_authority()
	preview.set_meta("weapon_motion_allocation_result", original)
	ui.footer_status_label.text = original_text
	return {"valid": shown and cleared and preserved, "warning_shown": shown,
		"warning_cleared": cleared, "pose_and_authority_preserved": preserved,
		"scope": "UI warning routing from real-rig diagnostic packet; not a second end-to-end invalid-pose station test."}

func _boundary_lifecycle(ui: CombatAnimationStationUI, actor: PlayerHumanoidRig, prop: Node3D, side: String) -> Dictionary:
	allocation_report = {"complete": false, "checks": []}
	if ui.active_wip_library == null or not ui.active_wip_library.save_file_path.begins_with(output_dir + "/isolated_"):
		return allocation_report.merged({"reason": "isolated_library_required"})
	ui.set_meta("verification_skip_persistence", false)
	var first: CombatAnimationMotionNode = ui.call("_get_active_motion_node")
	var first_signature := BoundaryPose.node_pose_signature(first)
	var first_bones := _boundary_bone_channels(actor)
	var added := ui.insert_motion_node_after_selection()
	var recording := await _await_allocation_recording(ui)
	_check_allocation(added and recording.ready, "held_R_records_and_adds_node", recording)
	_check_allocation(first.prepared_pose_signature == first_signature and BoundaryPose.validate(first.prepared_pose).get("valid", false), "held_R_records_matching_pose_signature")
	var packet_error := _boundary_packet_error(first.prepared_pose, first_bones)
	_check_allocation(packet_error.valid, "held_R_records_accepted_body_pose", packet_error)
	if not added or not recording.ready: return _complete_allocation()
	# Another actual held pointer gesture on the new node; two flushes before release.
	ui.session_state.current_focus = CombatAnimationSessionState.FOCUS_TIP
	var second: CombatAnimationMotionNode = ui.call("_get_active_motion_node")
	var display: CombatAnimationMotionNode = ui.call("_build_display_motion_node_for_viewport_pick", second)
	var camera: Camera3D = ui.call("_get_preview_camera")
	var trajectory: Node3D = ui.call("_get_preview_trajectory_root")
	var pointer := camera.unproject_position(trajectory.to_global(display.tip_position_local))
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = pointer
	ui.call("_on_preview_gui_input", press)
	for step: int in 2:
		pointer += Vector2(4, 0)
		var motion := InputEventMouseMotion.new()
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		motion.position = pointer
		motion.relative = Vector2(4, 0)
		var started := Time.get_ticks_msec()
		ui.call("_on_preview_gui_input", motion)
		while Time.get_ticks_msec() - started < 100: await _wait_frames(1)
		ui.call("_flush_pending_preview_drag_refresh")
		await _wait_frames(3)
		var snapshot := _boundary_snapshot(ui, actor, prop, side)
		_check_allocation(ui.preview_drag_forearm_failure.is_empty() and snapshot.has_motion_authority and snapshot.manipulator_matches_effective,
			"held_second_node_retains_authority_%d" % step, {"failure": ui.preview_drag_forearm_failure, "authority": snapshot.has_motion_authority, "matches": snapshot.manipulator_matches_effective})
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.position = pointer
	ui.call("_on_preview_gui_input", release)
	await _wait_frames(3)
	var second_signature := BoundaryPose.node_pose_signature(second)
	var second_bones := _boundary_bone_channels(actor)
	var playback := await _exercise_allocation_f(ui, actor)
	allocation_report.playback = playback
	_check_allocation(playback.played and playback.rejections.is_empty(), "held_F_prepares_and_plays", playback)
	_check_allocation(second.prepared_pose_signature == second_signature and BoundaryPose.validate(second.prepared_pose).get("valid", false), "held_F_records_final_matching_pose")
	packet_error = _boundary_packet_error(second.prepared_pose, second_bones)
	_check_allocation(packet_error.valid, "held_F_records_final_accepted_body_pose", packet_error)
	if not playback.played: return _complete_allocation()
	ui.call("_manual_save_active_editor_state")
	var deadline := Time.get_ticks_msec() + 60000
	while (ui.manual_save_in_progress or ui.is_motion_node_recording_pending()) and Time.get_ticks_msec() < deadline: await _wait_frames(1)
	_check_allocation(not ui.manual_save_in_progress and not ui.footer_status_label.text.begins_with("Not saved"), "held_Save_finishes", {"status": ui.footer_status_label.text})
	allocation_report.isolated_save_path = ui.active_wip_library.save_file_path
	var reloaded := ResourceLoader.load(ui.active_wip_library.save_file_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as PlayerForgeWipLibraryState
	var draft: CombatAnimationDraft
	if reloaded != null:
		for saved_weapon: CraftedItemWIP in reloaded.saved_wips:
			if saved_weapon.wip_id != ui.active_wip.wip_id: continue
			for saved_draft: CombatAnimationDraft in saved_weapon.combat_animation_station_state.skill_drafts:
				if saved_draft.legal_slot_id == StringName(String(options.get("slot", "skill_slot_2"))): draft = saved_draft
	_check_allocation(draft != null and draft.baked_runtime_clip != null and draft.baked_runtime_clip.has_solved_replay_track(), "held_saved_clip_reloads")
	if draft != null:
		for authored: CombatAnimationMotionNode in [first, second]:
			var found := false
			for loaded: CombatAnimationMotionNode in draft.get_action_motion_node_chain():
				if loaded.node_id != authored.node_id: continue
				found = true
				var expected := first_bones if authored == first else second_bones
				packet_error = _boundary_packet_error(loaded.prepared_pose, expected)
				_check_allocation(BoundaryPose.validate(loaded.prepared_pose).get("valid", false) and packet_error.valid,
					"held_saved_node_%s_preserves_recorded_body" % authored.node_id, packet_error)
			_check_allocation(found, "held_saved_node_%s_present" % authored.node_id)
	return _complete_allocation()

func _boundary_bone_channels(actor: PlayerHumanoidRig) -> Dictionary:
	var result := {}
	for index: int in actor.skeleton.get_bone_count():
		result[actor.skeleton.get_bone_name(index)] = actor.skeleton.get_bone_pose(index)
	return result

func _boundary_packet_error(packet: Dictionary, expected: Dictionary) -> Dictionary:
	var result := {"valid": false, "max_position_m": 0.0, "max_rotation_degrees": 0.0, "bones": 0}
	if not BoundaryPose.validate(packet).get("valid", false): return result
	for index: int in packet.bone_names.size():
		var name: String = packet.bone_names[index]
		if not expected.has(name): return result
		var pose: Transform3D = expected[name]
		var rotation: Vector4 = packet.pose_rotations[index]
		result.max_position_m = maxf(result.max_position_m, pose.origin.distance_to(packet.pose_positions[index]))
		result.max_rotation_degrees = maxf(result.max_rotation_degrees, rad_to_deg(_allocation_basis_error(pose.basis, Basis(Quaternion(rotation.x, rotation.y, rotation.z, rotation.w)))))
		result.bones += 1
	result.valid = result.max_position_m <= 0.00005 and result.max_rotation_degrees <= 0.025
	return result

func _boundary_tip(ui: CombatAnimationStationUI, actor: PlayerHumanoidRig, prop: Node3D, side: String,
		axis: Vector3, degrees: float, stage: String) -> Dictionary:
	var before := _boundary_snapshot(ui, actor, prop, side)
	var node: CombatAnimationMotionNode = ui.call("_get_active_motion_node")
	var display: CombatAnimationMotionNode = ui.call("_build_authoring_motion_node_baseline", node)
	var orbit: Dictionary = ui.preview_presenter.resolve_motion_node_tip_grip_orbit(ui.preview_subviewport, display, display.tip_position_local)
	if not orbit.get("available", false):
		var failed := {"stage": stage, "degrees": degrees, "changed": false, "reason": "orbit_unavailable", "orbit": orbit, "before": before}
		_write_boundary_row(failed)
		return failed
	var pivot: Vector3 = orbit.tip_grip_pivot_local
	var target := pivot + Basis(axis, deg_to_rad(degrees)) * (display.tip_position_local - pivot)
	var started := Time.get_ticks_usec()
	var changed := ui.set_selected_motion_node_tip_position(target, false)
	var elapsed_ms := (Time.get_ticks_usec() - started) / 1000.0
	var immediate := _boundary_snapshot(ui, actor, prop, side)
	await _wait_frames(3)
	var row := _live_allocation_details(ui, actor).merged({"stage": stage, "degrees": degrees, "changed": changed, "setter_ms": elapsed_ms,
		"requested_tip_local": target, "before": before, "immediate": immediate, "after": _boundary_snapshot(ui, actor, prop, side)})
	_write_boundary_row(row)
	print("BOUNDARY_SEQUENCE %s changed=%s status=%s reason=%s ms=%.2f" % [stage, changed, row.allocation.get("status", ""), row.allocation.get("reason", ""), elapsed_ms])
	return row

func _boundary_snapshot(ui: CombatAnimationStationUI, actor: PlayerHumanoidRig, prop: Node3D, side: String) -> Dictionary:
	var node: CombatAnimationMotionNode = ui.call("_get_active_motion_node")
	var effective: CombatAnimationMotionNode = ui.call("_get_effective_preview_motion_node")
	var trajectory: Node3D = ui.call("_get_preview_trajectory_root")
	var context := {"actor": actor, "weapon": prop, "trajectory": trajectory}
	var state: Dictionary = ui.preview_presenter.weapon_motion_manipulator.capture_state()
	var hand_index := actor.skeleton.find_bone("CC_Base_" + side + "_Hand")
	var actual_hand := actor.skeleton.global_transform * actor.skeleton.get_bone_global_pose(hand_index)
	var expected_hand := prop.global_transform * boundary_hand_in_weapon
	var contact_world := prop.global_transform * boundary_contact_local
	var ancestor_position_error := 0.0
	var ancestor_angle_error := 0.0
	for ancestor: int in boundary_clavicle_ancestors:
		var actual: Transform3D = actor.skeleton.get_bone_pose(ancestor)
		var expected: Transform3D = boundary_clavicle_ancestors[ancestor]
		ancestor_position_error = maxf(ancestor_position_error, actual.origin.distance_to(expected.origin))
		ancestor_angle_error = maxf(ancestor_angle_error, rad_to_deg(_allocation_basis_error(actual.basis, expected.basis)))
	var bones := {}
	for region: String in ["Clavicle", "Upperarm", "Forearm", "Hand"]:
		var bone := actor.skeleton.find_bone("CC_Base_" + side + "_" + region)
		bones[region] = {"local": actor.skeleton.get_bone_pose(bone), "global": actor.skeleton.get_bone_global_pose(bone)}
	return {"node_id": node.node_id, "selected_index": ui.get_selected_motion_node_index(),
		"tip": node.tip_position_local, "pommel": node.pommel_position_local,
		"effective_tip": effective.tip_position_local if effective != null else Vector3.ZERO,
		"effective_pommel": effective.pommel_position_local if effective != null else Vector3.ZERO,
		"contact_world": contact_world, "contact_delta_from_start_m": contact_world.distance_to(boundary_initial_contact_world),
		"hand_position_error_m": actual_hand.origin.distance_to(expected_hand.origin),
		"hand_angle_error_degrees": rad_to_deg(_allocation_basis_error(actual_hand.basis, expected_hand.basis)),
		"ancestor_position_error_m": ancestor_position_error, "ancestor_angle_error_degrees": ancestor_angle_error,
		"has_motion_authority": actor.has_authoring_weapon_motion_authority(),
		"manipulator_matches_effective": ui.preview_presenter.weapon_motion_manipulator.matches(context, effective),
		"stored_motion_signature": state.get("signature", ""),
		"effective_motion_signature": BoundaryPose.node_pose_signature(effective) if effective != null else "",
		"weapon_world": prop.global_transform, "bones": bones,
		"wrist": actor.capture_wrist_constraint_state(_boundary_slot(side)),
		"wrist_validity": actor.validate_authoring_forearm_hand_indexing(),
		"allocation_state": actor.get_authoring_weapon_motion_state(),
		"status": ui.footer_status_label.text}

func _boundary_slot(side: String) -> StringName:
	return &"hand_right" if side == "R" else &"hand_left"

func _write_boundary_row(row: Dictionary) -> void:
	samples_file.store_line(JSON.stringify(row))
	samples_file.flush()
