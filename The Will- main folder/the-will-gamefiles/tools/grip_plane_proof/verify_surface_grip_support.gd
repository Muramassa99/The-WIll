extends "res://tools/grip_plane_proof/verify_surface_grip_save_playback.gd"

## One real UI support add/remove transaction. The inherited tool supplies
## workspace isolation, pose metrics and report cleanup, not a replacement grip.
const SUPPORT := &"hand_left"
const Motion = preload("res://core/models/combat_animation_motion_node.gd")
const Station = preload("res://core/models/combat_animation_station_state.gd")
const Capture = preload("res://runtime/player/grip/capture_grip_placement_stage.gd")

func _run() -> void:
	_prefix = "C:/WORKSPACE/test_artifacts/grip_support_" + Time.get_datetime_string_from_system().replace(":", "-")
	_report = {"scope": "actual_ui_support_add_remove_and_existing_idle_save", "visual_grip_certified": false}
	_source = OS.get_environment("THE_WILL_GRIP_LIVE_LIBRARY").strip_edges()
	var expected := OS.get_environment("THE_WILL_DIAGNOSTIC_USER_ROOT").replace("\\", "/").simplify_path().to_lower()
	if not _check(_workspace(expected) and expected == OS.get_user_data_dir().replace("\\", "/").simplify_path().to_lower(), "incidental writes isolated inside workspace"):
		_finish(); return
	if not _check(_workspace(_source) and FileAccess.file_exists(_source), "input is actual workspace library copy"):
		_finish(); return
	_source_hash = FileAccess.get_sha256(_source)
	var input: Resource = ResourceLoader.load(_source, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	if not _check(input != null, "source library loads"):
		_finish(); return
	var requested := OS.get_environment("THE_WILL_GRIP_LIVE_WEAPON_NAME").strip_edges()
	if requested.is_empty(): requested = "Handle 1"
	var chosen: Resource
	for wip: Resource in input.saved_wips:
		if wip.forge_project_name == requested: chosen = wip
	if not _check(chosen != null, "named actual weapon exists"):
		_finish(); return
	# Inspect the serialized source BEFORE UI baseline generation. Never create an
	# idle pose merely to make this proof pass.
	var existing_idle := false
	if chosen.combat_animation_station_state != null:
		for draft: Resource in chosen.combat_animation_station_state.idle_drafts:
			if draft.context_id == Station.IDLE_CONTEXT_COMBAT and not draft.motion_node_chain.is_empty():
				existing_idle = true
	_report.merge({"source_library": _source, "source_library_sha256": _source_hash,
		"weapon_name": requested, "existing_serialized_combat_idle": existing_idle})
	_library_player = LibraryPlayer.new()
	_library_player.library = input.duplicate(true)
	_library_player.library.save_file_path = _prefix + "_library.tres"
	root.add_child(_library_player)
	_ui = UIScene.instantiate()
	root.add_child(_ui)
	await process_frame
	_ui.open_for(_library_player, "Isolated support/idle grip diagnostic")
	if not _check(_ui.open_saved_wip_with_hand_setup(chosen.wip_id, HAND, false), "open existing one-hand setup"):
		_finish(); return
	_ui.select_skill_slot(SKILL)
	var motion: Resource = _ui._get_active_motion_node()
	if motion.two_hand_state != Motion.TWO_HAND_STATE_ONE_HAND:
		_ui.set_selected_motion_node_two_hand_state(Motion.TWO_HAND_STATE_ONE_HAND, false)
	var primary: Dictionary = await _wait_slot(HAND)
	_report["primary_before_support"] = primary
	if not _check(primary.get("status", "") == "preview_applied", "primary committed before support joins"):
		_finish(); return
	var context: Dictionary = _ui.preview_presenter._weapon_roll_context(_ui.preview_subviewport)
	var owner: Node = context.actor.get_node("PreparedGripAcquisition")
	var primary_key: String = owner._requests.get(HAND, {}).get("key", "")
	var primary_serial: int = primary.get("serial", -1)
	var initial_relative := _primary_relative(context)
	var initial_rotations := _finger_rotations(context.actor, HAND)
	_report["support_station_ratio"] = motion.secondary_grip_seat_slide_offset
	_report["grip_style"] = motion.preferred_grip_style_mode
	if not _check(_ui.set_selected_motion_node_two_hand_state(Motion.TWO_HAND_STATE_TWO_HAND, false), "existing UI activates Two Hand"):
		_finish(); return
	var support: Dictionary = await _wait_slot(SUPPORT, true)
	_report["support_result"] = support
	_check(support.get("status", "") == "preview_applied", "joining support receives new solver pose")
	context = _ui.preview_presenter._weapon_roll_context(_ui.preview_subviewport)
	owner = context.actor.get_node("PreparedGripAcquisition")
	if support.get("status", "") == "preview_applied":
		await _verify_support_refresh_and_capture(context, owner)
	_check(owner._requests.get(HAND, {}).get("key", "") == primary_key and owner._status.get(HAND, {}).get("serial", -2) == primary_serial, "support addition does not reacquire primary")
	var relative_error := _frame_error(initial_relative, _primary_relative(context))
	var finger_error := _finger_error(initial_rotations, _finger_rotations(context.actor, HAND))
	_report.merge({"primary_relative_error_after_add": relative_error, "primary_finger_error_after_add_rad": finger_error})
	_check(relative_error <= 0.00005 and finger_error <= 0.00005, "support addition preserves established primary grip")
	_verify_unreachable_support_rollback(context)
	_check(_ui.set_selected_motion_node_two_hand_state(Motion.TWO_HAND_STATE_ONE_HAND, false), "existing UI removes support")
	for _i: int in 3: await process_frame
	context = _ui.preview_presenter._weapon_roll_context(_ui.preview_subviewport)
	owner = context.actor.get_node("PreparedGripAcquisition")
	_check(not owner.owns(SUPPORT), "support ownership released after removal")
	_check(owner._support_motion_snapshot.is_empty(), "support removal clears retained two-hand motion snapshot")
	_check(owner._requests.get(HAND, {}).get("key", "") == primary_key and owner._status.get(HAND, {}).get("serial", -2) == primary_serial and context.actor.get_planar_grip_pose_state(HAND).get("has_grip_pose", false), "support removal retains committed primary ownership")
	_report["primary_relative_error_after_remove"] = _frame_error(initial_relative, _primary_relative(context))
	_check(_report.primary_relative_error_after_remove <= 0.00005, "support removal preserves primary relationship")
	_report["legacy_solve_count"] = _legacy_solve_count(context.actor)
	_check(_report.legacy_solve_count == 0, "support path does not execute old serial/seat solver")
	if existing_idle and OS.get_environment("THE_WILL_GRIP_SUPPORT_TRACE_ONLY") != "1":
		await _save_existing_idle(chosen.wip_id)
	else:
		_report["idle_save"] = {"skipped": true, "reason": "focused_support_trace" if existing_idle else "no_existing_serialized_combat_idle_pose"}
	_finish()

func _verify_support_refresh_and_capture(context: Dictionary, owner: Node) -> void:
	var skeleton: Skeleton3D = context.actor.skeleton
	var hand_index := skeleton.find_bone("CC_Base_L_Hand")
	var before: Transform3D = context.weapon.global_transform.affine_inverse() * skeleton.global_transform * skeleton.get_bone_global_pose(hand_index)
	var serial: int = owner._status[SUPPORT].serial
	var maximum_error := 0.0
	for _frame: int in 3:
		_ui._sync_preview_pose_only()
		await process_frame
		var actual: Transform3D = context.weapon.global_transform.affine_inverse() * skeleton.global_transform * skeleton.get_bone_global_pose(hand_index)
		maximum_error = maxf(maximum_error, _frame_error(before, actual))
	_report["support_refresh_error_m_or_rad"] = maximum_error
	_check(maximum_error <= 0.00005 and owner._status[SUPPORT].serial == serial, "ordinary preview refresh retains support grip without reacquisition")
	var motion: Resource = _ui._get_active_motion_node()
	var tip_before: Vector3 = motion.tip_position_local
	var pommel_before: Vector3 = motion.pommel_position_local
	var weapon_before: Transform3D = context.weapon.global_transform
	motion.tip_position_local += Vector3(0.015, 0.0, 0.0)
	motion.pommel_position_local += Vector3(0.015, 0.0, 0.0)
	_ui._sync_preview_pose_only()
	await process_frame
	var after_edit: Transform3D = context.weapon.global_transform.affine_inverse() * skeleton.global_transform * skeleton.get_bone_global_pose(hand_index)
	var retained: Dictionary = owner._status[SUPPORT].get("motion_retention", {}).duplicate(true)
	_report["modest_edit"] = {"requested_translation_m": 0.015,
		"realized_weapon_movement_m_or_rad": _frame_error(weapon_before, context.weapon.global_transform),
		"support_relationship_error_m_or_rad": _frame_error(before, after_edit), "retention": retained}
	_check(_frame_error(before, after_edit) <= 0.00005, "modest edit preserves support relationship or explicitly clamps motion")
	_check(motion.tip_position_local == tip_before + Vector3(0.015, 0.0, 0.0) and motion.pommel_position_local == pommel_before + Vector3(0.015, 0.0, 0.0), "motion guard preserves authored control intent")
	motion.tip_position_local = tip_before
	motion.pommel_position_local = pommel_before
	_ui._sync_preview_pose_only()
	await process_frame
	var pivot := {"point_local": context.weapon.get_meta("preview_support_grip_seat_local"),
		"origin_id": context.weapon.get_meta("preview_support_grip_seat_origin_id"), "source": "preview_support_grip_seat"}
	var capture := Capture.new().capture(context.actor, context.weapon, owner._data.anatomy, SUPPORT,
		&"support_post_refresh_observation", serial, 0, {}, pivot)
	if not _check(capture.get("valid", false), "actual support skin capture succeeds"): return
	capture.posed_character["digit_dimension_reference"] = owner._requests[SUPPORT].digit_dimension_reference.duplicate(true)
	var packet: Dictionary = owner._replay_pose_cache[owner._requests[SUPPORT].key].packet
	var assessed: Dictionary = owner.Acquisition.Solver.new().assess_final_pose(owner._data.anatomy, capture, owner._data.config, packet.digit_states)
	_check(assessed.get("valid", false) and assessed.get("material_safe", false), "fresh post-refresh actual support assessment respects physical caps")
	_report["actual_post_refresh_assessment"] = owner._solver_diagnostics(assessed)
	var current_status: Dictionary = owner._status.duplicate(true)
	current_status[SUPPORT].merge(owner._solver_diagnostics(assessed), true)
	current_status[SUPPORT]["actual_assessment_current"] = true
	var capture_path := _prefix + "_actual.bin"
	var output := FileAccess.open(capture_path, FileAccess.WRITE)
	output.store_var(capture, false); output.close()
	var status := {"weapon_name": _report.weapon_name, "owner_status": current_status,
		"actual_capture_path": capture_path, "actual_capture_sha256": FileAccess.get_sha256(capture_path),
		"actual_capture_valid": true, "actual_capture_policy": "ordinary_preview_refresh_observed_pose"}
	output = FileAccess.open(_prefix + "_status.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(status, "\t")); output.close()
	_report["actual_support_status_path"] = _prefix + "_status.json"

func _verify_unreachable_support_rollback(context: Dictionary) -> void:
	var actor: Node3D = context.actor
	var skeleton: Skeleton3D = actor.skeleton
	var hand: Transform3D = skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone("CC_Base_L_Hand"))
	var weapon_before: Transform3D = context.weapon.global_transform
	var bones: Array[Transform3D] = []
	for index: int in skeleton.get_bone_count(): bones.append(skeleton.get_bone_pose(index))
	var unreachable := hand
	unreachable.origin += Vector3(10.0, 0.0, 0.0)
	var attempted: Dictionary = actor.begin_prepared_support_grip_seat(SUPPORT, context.weapon, unreachable)
	actor.finish_prepared_support_grip_seat(false)
	_report["unreachable_support"] = {"valid": attempted.get("valid", false),
		"reason": attempted.get("reason", ""), "position_error_m": attempted.get("position_error_m", 0.0)}
	_check(not attempted.get("valid", true) and attempted.get("reason") == "support_seat_outside_arm_reach", "genuinely unreachable support target is refused")
	var restored := true
	for index: int in bones.size():
		if not skeleton.get_bone_pose(index).is_equal_approx(bones[index]): restored = false
	_check(restored and context.weapon.global_transform == weapon_before, "unreachable support transaction rolls back every bone and preserves weapon")

func _wait_slot(slot: StringName, watch_weapon: bool = false) -> Dictionary:
	var started := Time.get_ticks_usec()
	var status: Dictionary = {}
	var have_fixed_frame := false
	var weapon_start := Transform3D.IDENTITY
	var maximum_motion := 0.0
	while float(Time.get_ticks_usec() - started) / 1000000.0 < 120.0:
		await process_frame
		status = _ui.preview_presenter.get_grip_acquisition_status(_ui.preview_subviewport).get(slot, {})
		if watch_weapon and (status.get("status", "") == "solving" or have_fixed_frame):
			var context: Dictionary = _ui.preview_presenter._weapon_roll_context(_ui.preview_subviewport)
			if not have_fixed_frame:
				weapon_start = context.weapon.global_transform
				have_fixed_frame = true
			maximum_motion = maxf(maximum_motion, _frame_error(weapon_start, context.weapon.global_transform))
		if status.get("status", "") in ["preview_applied", "unresolved", "unavailable"]: break
	if watch_weapon:
		_report["weapon_motion_during_support_m_or_rad"] = maximum_motion
		_check(have_fixed_frame and maximum_motion <= 0.00005, "support solver keeps established weapon fixed")
	return status

func _primary_relative(context: Dictionary) -> Transform3D:
	var skeleton: Skeleton3D = context.actor.skeleton
	return context.weapon.global_transform.affine_inverse() * skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone("CC_Base_R_Hand"))

func _frame_error(a: Transform3D, b: Transform3D) -> float:
	return maxf(a.origin.distance_to(b.origin), _rotation_error(a.basis.orthonormalized().get_rotation_quaternion(), b.basis.orthonormalized().get_rotation_quaternion()))

func _finger_rotations(actor: Node3D, slot: StringName) -> Array[Quaternion]:
	var out: Array[Quaternion] = []
	for name: StringName in Rules.get_finger_bone_names(slot):
		out.append(actor.skeleton.get_bone_pose_rotation(actor.skeleton.find_bone(name)))
	return out

func _finger_error(a: Array[Quaternion], b: Array[Quaternion]) -> float:
	if a.size() != b.size(): return INF
	var error := 0.0
	for i: int in a.size(): error = maxf(error, _rotation_error(a[i], b[i]))
	return error

func _save_existing_idle(wip_id: StringName) -> void:
	_check(_ui.select_authoring_mode(Station.AUTHORING_MODE_IDLE) and _ui.select_draft(Station.IDLE_CONTEXT_COMBAT), "select only existing combat idle")
	var status: Dictionary = await _wait_slot(HAND)
	var result := {"acquisition": status}
	if not _check(status.get("status", "") == "preview_applied", "existing idle acquisition commits before Save"):
		_report["idle_save"] = result; return
	var draft: Resource = _ui._get_active_draft()
	_ui._mark_active_draft_runtime_clip_cache_dirty()
	_ui.editor_state_dirty = true
	var started := Time.get_ticks_usec()
	await _ui._manual_save_active_editor_state()
	result["save_ms"] = float(Time.get_ticks_usec() - started) / 1000.0
	result["message"] = _ui.footer_status_label.text
	var clip: Resource = draft.baked_runtime_clip
	if _check(clip != null and clip.has_solved_replay_track(), "existing combat idle uses same solved-grip save/bake path"):
		result["frame_count"] = clip.get_frame_count()
		var reloaded: Resource = ResourceLoader.load(_prefix + "_library.tres", "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
		var wip: Resource = reloaded.get_saved_wip_clone(wip_id)
		var persisted_clip: Resource
		for idle: Resource in wip.combat_animation_station_state.idle_drafts:
			if idle.context_id == Station.IDLE_CONTEXT_COMBAT: persisted_clip = idle.baked_runtime_clip
		_check(persisted_clip != null and persisted_clip.has_solved_replay_track() and _track_error(clip, persisted_clip) <= 0.00005, "saved combat idle track survives disk reload")
	_report["idle_save"] = result
