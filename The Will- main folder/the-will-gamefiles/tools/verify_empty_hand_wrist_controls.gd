extends "res://tools/verify_unarmed_empty_hand_movement.gd"

## Rendered focused wrist-Z probe. Fresh isolated Glave and Unarmed stations,
## both primary selections; actual green-sphere pick/drag/release plus numeric
## absolute gamma. Native window input is disabled; explicit synthetic events
## enter the production handlers. No F, player Save, acquisition request, or
## engaged-support/reverse/axial-freedom sweep.
## --weapon=Broken_Glave_v1 --out=<fresh workspace directory>
## --case-limit=1 runs only the first armed right-primary diagnostic case.

const WRIST_POSITION_EPSILON := 0.00005
const WRIST_ANGLE_EPSILON := 0.025
var _wrist_source_path := ""
var _wrist_source_hash := ""
var _wrist_weapon_name := "Broken_Glave_v1"
var _wrist_fixture: CraftedItemWIP
var _wrist_is_unarmed := false
var _wrist_primary: StringName
var _wrist_curls: Dictionary = {}
var _wrist_case_limit := 6

func _run() -> void:
	_out = "C:/WORKSPACE/godot_runs/empty_hand_wrist_%d" % int(Time.get_unix_time_from_system())
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			_out = argument.substr(6).replace("\\", "/").trim_suffix("/")
		elif argument.begins_with("--weapon="):
			_wrist_weapon_name = argument.substr(9)
		elif argument.begins_with("--case-limit="):
			_wrist_case_limit = clampi(argument.substr(13).to_int(), 1, 6)
	if not _out.to_lower().begins_with("c:/workspace/") or FileAccess.file_exists(_out.path_join("report.json")) \
			or DirAccess.make_dir_recursive_absolute(_out) != OK:
		push_error("A fresh writable workspace output directory is required.")
		quit(1)
		return
	_report = {"complete": false, "checks": [], "failures": [], "readiness": [], "cases": [],
		"scope": "Empty-hand wrist local Z: actual sphere input, absolute gamma limits, immediate reversal, frozen beta/rho/forearm/body/other hand, finger retention, no extra acquisition, release, targeted prepared node save/load/restore. No F or player Save.",
		"input_route": "Synthetic GUI marker press/release and explicit preview-local pointer samples; native root GUI and station input callbacks disabled.",
		"expected_case_count": _wrist_case_limit, "partial_selection": _wrist_case_limit < 6}
	root.gui_disable_input = true
	create_timer(360.0).timeout.connect(func() -> void:
		if not _finished:
			_check(false, "run_timeout")
			_finish())
	if not _load_wrist_fixture():
		_finish()
		return
	for unarmed: bool in [false, true]:
		if _report.cases.size() >= _wrist_case_limit:
			break
		_wrist_is_unarmed = unarmed
		for primary: StringName in SLOTS:
			if _report.cases.size() >= _wrist_case_limit:
				break
			_wrist_primary = primary
			var opened := false
			if unarmed:
				opened = await _open_movement_station(primary)
			else:
				opened = await _open_armed_wrist_station(primary)
			if not opened:
				_finish()
				return
			_wrist_curls.clear()
			var slots: Array[StringName] = []
			slots.assign(SLOTS if unarmed else [(&"hand_left" if primary == &"hand_right" else &"hand_right")])
			for slot: StringName in slots:
				_wrist_curls[slot] = FingerControls.get_curls(_motion(), slot).duplicate(true)
			_check_wrist_occupancy(slots)
			var exercised_slots: Array[StringName] = []
			for slot: StringName in slots:
				if _report.cases.size() >= _wrist_case_limit:
					break
				_report.cases.append(await _exercise_empty_wrist(slot))
				exercised_slots.append(slot)
				_write_movement_report()
			await _round_trip_wrist_pose(exercised_slots)
			_ui.queue_free()
			_player.queue_free()
			await _frames(4)
			_ui = null
			_player = null
			_actor = null
			_skeleton = null
	_finish()

func _load_wrist_fixture() -> bool:
	_wrist_source_path = ProjectSettings.globalize_path(Library.DEFAULT_SAVE_FILE_PATH)
	_wrist_source_hash = FileAccess.get_sha256(_wrist_source_path)
	var source := ResourceLoader.load(_wrist_source_path, "", ResourceLoader.CACHE_MODE_IGNORE) as PlayerForgeWipLibraryState
	_check(source != null and not _wrist_source_hash.is_empty(), "saved_source_available")
	if source == null:
		return false
	for item: CraftedItemWIP in source.get_saved_wips():
		if item != null and item.latest_baked_profile_snapshot != null and CraftedItemWIP.is_forge_v2_authoring_wip(item) \
				and (item.forge_project_name == _wrist_weapon_name or String(item.wip_id) == _wrist_weapon_name):
			_wrist_fixture = item
			break
	_check(_wrist_fixture != null, "saved_weapon_found", {"requested": _wrist_weapon_name})
	_report["source_path"] = _wrist_source_path
	_report["source_sha256_before"] = _wrist_source_hash
	return _wrist_fixture != null

func _open_armed_wrist_station(primary: StringName) -> bool:
	var library: PlayerForgeWipLibraryState = Library.new()
	library.save_file_path = _out.path_join("isolated_wrist_%s.tres" % primary)
	var fixture := _wrist_fixture.duplicate(true) as CraftedItemWIP
	fixture.grip_style_mode = CraftedItemWIP.GRIP_NORMAL
	fixture.ensure_combat_animation_station_state()
	library.saved_wips.append(fixture)
	library.selected_wip_id = fixture.wip_id
	_player = FakePlayer.new()
	_player.forge_wip_library_state = library
	root.add_child(_player)
	_ui = Station.instantiate() as CombatAnimationStationUI
	_ui.set_meta("verification_skip_persistence", true)
	root.add_child(_ui)
	await _frames(2)
	_ui.set_process_input(false)
	_ui.set_process_unhandled_input(false)
	_ui.open_for(_player, "Empty wrist verification: " + String(primary))
	await _frames(2)
	var opened := _ui.open_saved_wip_with_hand_setup(fixture.wip_id, primary, false, true)
	var selected := _ui.select_skill_slot(&"skill_slot_2", true)
	await _frames(3)
	_check(opened and selected, _station_name() + ":open")
	if not opened or not selected:
		return false
	var reset := _ui.reset_active_draft_to_baseline()
	_ui.select_motion_node(1)
	_check(reset, _station_name() + ":reset")
	var ready := await _wait_ready(_station_name() + ":baseline")
	_check(ready, _station_name() + ":baseline_ready")
	if not ready:
		return false
	_actor = _preview().get_node_or_null("PreviewActorPivot/PreviewActor") as PlayerHumanoidRig
	_check(_actor != null and _actor.skeleton != null, _station_name() + ":rig_available")
	if _actor == null or _actor.skeleton == null:
		return false
	_skeleton = _actor.skeleton
	_check(_motion().prepared_pose_signature == PreparedPose.node_pose_signature(_motion()) \
		and bool(PreparedPose.validate(_motion().prepared_pose).get("valid", false)), _station_name() + ":recorded_baseline")
	var free := &"hand_left" if primary == &"hand_right" else &"hand_right"
	_check(_ui.set_selected_motion_node_finger_curl(free, &"index", 30.0 if free == &"hand_right" else 60.0),
		_station_name() + ":seed_empty_index")
	ready = await _wait_ready(_station_name() + ":finger_seed")
	_check(ready, _station_name() + ":finger_seed_ready")
	return ready

func _station_name() -> String:
	return ("unarmed:" if _wrist_is_unarmed else "armed:") + String(_wrist_primary)

func _wrist_focus(slot: StringName) -> StringName:
	return &"left_hand_wrist" if slot == &"hand_left" else &"right_hand_wrist"

func _wrist_control(slot: StringName) -> Dictionary:
	return _ui.preview_presenter.describe_empty_hand_wrist_control(_ui.preview_subviewport, _motion(), slot)

func _check_wrist_occupancy(slots: Array[StringName]) -> void:
	var ids: Array = _ui.call("_resolve_available_focus_ids")
	_check(root.gui_disable_input and not _ui.is_processing_input() and not _ui.is_processing_unhandled_input(),
		_station_name() + ":native_input_isolated")
	for slot: StringName in SLOTS:
		var available := slots.has(slot)
		_check(ids.has(_wrist_focus(slot)) == available, _station_name() + ":wrist_focus_occupancy:" + String(slot))
		_check(bool(_wrist_control(slot).get("available", false)) == available,
			_station_name() + ":wrist_descriptor_occupancy:" + String(slot))
		if not available:
			var before := _bone_poses()
			var changed := _ui.set_selected_motion_node_empty_hand_wrist_bend(slot, 5.0)
			_check(not changed and before == _bone_poses(), _station_name() + ":occupied_numeric_rejected")
		else:
			for focus: StringName in FingerControls.focus_ids(slot):
				_check(ids.has(focus), _station_name() + ":finger_focus:" + String(focus))
	if not _wrist_is_unarmed:
		_check(ids.has(&"weapon"), _station_name() + ":occupied_primary_green_focus_preserved")

func _exercise_empty_wrist(slot: StringName) -> Dictionary:
	var label := _station_name() + ":" + String(slot)
	var result := {"name": label, "complete": false, "samples": []}
	var focus := _wrist_focus(slot)
	_aim_movement_camera(slot)
	for step: int in 32:
		if _ui.session_state.current_focus == focus:
			break
		_ui.call("_cycle_focus")
	_check(_ui.session_state.current_focus == focus, label + ":space_cycle_reaches_wrist")
	await _frames(2)
	var control := _wrist_control(slot)
	_check(bool(control.get("available", false)), label + ":descriptor_available", control)
	if not control.get("available", false):
		return result
	var camera := _ui.call("_get_preview_camera") as Camera3D
	var screen: Variant = _attached_marker_screen(camera, focus, focus, control.marker_position)
	_check(screen is Vector2, label + ":attached_sphere_visible", {"control": control})
	if not screen is Vector2:
		return result
	var reference := _wrist_reference(slot)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = screen
	_ui.call("_on_preview_gui_input", press)
	var picked := _ui.motion_node_editor.get_drag_target() == focus
	_check(picked, label + ":sphere_picked", {"picked": _ui.motion_node_editor.get_drag_target()})
	if not picked:
		press.pressed = false
		_ui.call("_on_preview_gui_input", press)
		return result
	var pointer: Vector2 = screen
	# The shared allocator intentionally caps substeps per event. Continue the
	# held demand at most four times, then require the strict anatomical bound.
	# A further rejected overshoot must be consumed before the four-pixel reverse.
	for direction: float in [1.0, -1.0]:
		var edge := "maximum" if direction > 0.0 else "minimum"
		var limit: float = _wrist_control(slot)[edge + "_degrees"]
		for attempt: int in 4:
			var before: float = _wrist_control(slot).angle_degrees
			pointer.x += direction * (2000.0 if attempt == 0 else 100.0)
			await _send_wrist_pointer(pointer)
			var name := label + ":pointer_" + edge + "_%d" % attempt
			result.samples.append(_sample_wrist(name, slot, reference, NAN))
			var after: float = _wrist_control(slot).angle_degrees
			_check(absf(limit - after) <= absf(limit - before) + WRIST_ANGLE_EPSILON,
				name + ":approaches_limit", {"before_degrees": before, "after_degrees": after, "limit_degrees": limit})
			if absf(limit - after) <= WRIST_ANGLE_EPSILON:
				break
		var reached: float = _wrist_control(slot).angle_degrees
		_check(absf(reached - limit) <= WRIST_ANGLE_EPSILON, label + ":pointer_" + edge + ":bounded_convergence",
			{"actual_degrees": reached, "limit_degrees": limit, "maximum_samples": 4})
		pointer.x += direction * 100.0
		await _send_wrist_pointer(pointer)
		result.samples.append(_sample_wrist(label + ":pointer_" + edge + ":rejected_overshoot", slot, reference, limit))
		var before_reverse: float = _wrist_control(slot).angle_degrees
		pointer.x -= direction * 4.0
		await _send_wrist_pointer(pointer)
		result.samples.append(_sample_wrist(label + ":pointer_" + edge + ":immediate_reverse", slot, reference, before_reverse - direction * 2.0))
	var held := _movement_hand_world(slot)
	press.pressed = false
	press.position = pointer
	_ui.call("_on_preview_gui_input", press)
	for delay: int in [1, 3, 8]:
		await _frames(delay)
		var name := label + ":release_%d" % delay
		var actual := _movement_hand_world(slot)
		_check(held.origin.distance_to(actual.origin) <= WRIST_POSITION_EPSILON \
			and _movement_basis_angle(held.basis, actual.basis) <= WRIST_ANGLE_EPSILON,
			name + ":retained", {"position_m": held.origin.distance_to(actual.origin),
			"angle_degrees": _movement_basis_angle(held.basis, actual.basis)})
		result.samples.append(_sample_wrist(name, slot, reference, NAN))
	for request: float in [1000.0, -1000.0, 0.0]:
		control = _wrist_control(slot)
		var expected := clampf(request, control.minimum_degrees, control.maximum_degrees)
		for attempt: int in 4:
			var before: float = _wrist_control(slot).angle_degrees
			var changed := _ui.set_selected_motion_node_empty_hand_wrist_bend(slot, request)
			await _frames(2)
			var name := label + ":numeric_%s_%d" % [request, attempt]
			var sample := _sample_wrist(name, slot, reference, NAN)
			sample["setter_changed"] = changed
			result.samples.append(sample)
			var after: float = _wrist_control(slot).angle_degrees
			_check(absf(expected - after) <= absf(expected - before) + WRIST_ANGLE_EPSILON, name + ":approaches_target")
			if absf(after - expected) <= WRIST_ANGLE_EPSILON:
				break
		_check(absf(float(_wrist_control(slot).angle_degrees) - expected) <= WRIST_ANGLE_EPSILON,
			label + ":numeric_%s:bounded_convergence" % request,
			{"actual_degrees": _wrist_control(slot).angle_degrees, "expected_degrees": expected, "maximum_samples": 4})
	result.complete = true
	return result

func _send_wrist_pointer(pointer: Vector2) -> void:
	_ui.call("_begin_preview_authoring_lookup_scope")
	_ui.call("_handle_preview_drag", pointer)
	_ui.call("_end_preview_authoring_lookup_scope")
	await _frames(2)

func _wrist_reference(slot: StringName) -> Dictionary:
	var hand_index := _skeleton.find_bone("CC_Base_L_Hand" if slot == &"hand_left" else "CC_Base_R_Hand")
	var outside: Dictionary = {}
	var outside_local: Dictionary = {}
	var descendants: Dictionary = {}
	for bone: int in _skeleton.get_bone_count():
		var ancestor := bone
		while ancestor >= 0 and ancestor != hand_index:
			ancestor = _skeleton.get_bone_parent(ancestor)
		if ancestor != hand_index:
			outside[bone] = _skeleton.global_transform * _skeleton.get_bone_global_pose(bone)
			outside_local[bone] = _skeleton.get_bone_pose(bone)
		elif bone != hand_index:
			descendants[bone] = _skeleton.get_bone_pose(bone)
	var weapon := _preview().get_meta("preview_held_item", null) as Node3D
	return {"hand": _movement_hand_world(slot), "wrist": _actor.capture_wrist_motion_start_state(slot),
		"outside": outside, "outside_local": outside_local, "descendants": descendants, "weapon": weapon.global_transform,
		"acquisition": _wrist_acquisition_state()}

func _wrist_acquisition_state() -> Dictionary:
	var owner := _actor.get_node_or_null("PreparedGripAcquisition")
	if owner == null:
		return {"present": false, "serial": 0, "requests": {}, "queue": [], "busy": false, "job": false}
	return {"present": true, "serial": owner.get("_serial"), "requests": (owner.get("_requests") as Dictionary).duplicate(true),
		"queue": (owner.get("_queue") as Array).duplicate(true), "busy": owner.get("_busy"), "job": owner.get("_job") != null}

func _sample_wrist(name: String, slot: StringName, reference: Dictionary, expected: float) -> Dictionary:
	var control := _wrist_control(slot)
	var actual := _movement_hand_world(slot)
	var measured: Dictionary = _actor.capture_wrist_motion_start_state(slot)
	var row := {"name": name, "control": control, "measured": measured, "expected_gamma_degrees": expected if is_finite(expected) else null}
	_check(bool(control.get("available", false)) and bool(measured.get("valid", false)), name + ":measurement_available")
	if not control.get("available", false) or not measured.get("valid", false):
		return row
	var state: Dictionary = measured.state
	var prior: Dictionary = reference.wrist.get("state", {})
	_check(not prior.is_empty(), name + ":reference_measurement_available")
	if prior.is_empty():
		return row
	var gamma := rad_to_deg(float(state.gamma))
	_check(gamma >= float(control.minimum_degrees) - WRIST_ANGLE_EPSILON \
		and gamma <= float(control.maximum_degrees) + WRIST_ANGLE_EPSILON, name + ":gamma_inside_limits")
	_check(absf(gamma - float(control.angle_degrees)) <= WRIST_ANGLE_EPSILON, name + ":descriptor_matches_actual_gamma")
	if is_finite(expected):
		_check(absf(gamma - expected) <= WRIST_ANGLE_EPSILON, name + ":requested_gamma_reached",
			{"actual_degrees": gamma, "expected_degrees": expected})
	_check(absf(rad_to_deg(float(state.beta) - float(prior.beta))) <= WRIST_ANGLE_EPSILON \
		and absf(rad_to_deg(float(state.rho) - float(prior.rho))) <= WRIST_ANGLE_EPSILON,
		name + ":beta_rho_held", {"beta_delta_degrees": rad_to_deg(float(state.beta) - float(prior.beta)),
		"rho_delta_degrees": rad_to_deg(float(state.rho) - float(prior.rho))})
	_check(actual.origin.distance_to(reference.hand.origin) <= WRIST_POSITION_EPSILON, name + ":hand_origin_fixed")
	_check(actual.origin.distance_to(control.origin) <= WRIST_POSITION_EPSILON \
		and actual.basis.z.normalized().distance_to(control.axis) <= 0.0001, name + ":descriptor_uses_actual_wrist_local_z")
	var position_error := 0.0
	var angle_error := 0.0
	var worst_position: Dictionary = {}
	var worst_angle: Dictionary = {}
	for bone: int in reference.outside:
		var frame: Transform3D = _skeleton.global_transform * _skeleton.get_bone_global_pose(bone)
		var position: float = frame.origin.distance_to(reference.outside[bone].origin)
		var angle: float = _movement_basis_angle(frame.basis, reference.outside[bone].basis)
		if position > position_error or angle > angle_error:
			var diagnostic := {"bone": _skeleton.get_bone_name(bone), "index": bone,
				"position_error_m": position, "angle_error_degrees": angle,
				"before_world": reference.outside[bone], "after_world": frame,
				"before_local": reference.outside_local[bone], "after_local": _skeleton.get_bone_pose(bone)}
			if position > position_error:
				worst_position = diagnostic
			if angle > angle_error:
				worst_angle = diagnostic
		position_error = maxf(position_error, position)
		angle_error = maxf(angle_error, angle)
	row["frozen_worst"] = {"position": worst_position, "angle": worst_angle}
	_check(position_error <= WRIST_POSITION_EPSILON and angle_error <= WRIST_ANGLE_EPSILON,
		name + ":forearm_other_arm_and_body_frozen", {"max_position_m": position_error, "max_angle_degrees": angle_error,
		"worst_position_bone": worst_position.get("bone", ""), "worst_angle_bone": worst_angle.get("bone", "")})
	var finger_position_error := 0.0
	var finger_angle_error := 0.0
	for bone: int in reference.descendants:
		var frame := _skeleton.get_bone_pose(bone)
		finger_position_error = maxf(finger_position_error, frame.origin.distance_to(reference.descendants[bone].origin))
		finger_angle_error = maxf(finger_angle_error, _movement_basis_angle(frame.basis, reference.descendants[bone].basis))
	_check(not reference.descendants.is_empty() and finger_position_error <= WRIST_POSITION_EPSILON \
		and finger_angle_error <= WRIST_ANGLE_EPSILON, name + ":finger_local_poses_retained",
		{"max_position_m": finger_position_error, "max_angle_degrees": finger_angle_error})
	for empty_slot: StringName in _wrist_curls:
		_check(FingerControls.get_curls(_motion(), empty_slot) == _wrist_curls[empty_slot], name + ":authored_curl_retained:" + String(empty_slot))
	var weapon := _preview().get_meta("preview_held_item", null) as Node3D
	if not _wrist_is_unarmed or slot != _wrist_primary:
		_check(weapon.global_position.distance_to(reference.weapon.origin) <= WRIST_POSITION_EPSILON \
			and _movement_basis_angle(weapon.global_basis, reference.weapon.basis) <= WRIST_ANGLE_EPSILON, name + ":weapon_or_opposite_virtual_proxy_frozen")
	else:
		row["primary_frame"] = _check_primary_authoring_frame(name)
	var acquisition := _wrist_acquisition_state()
	_check(acquisition == reference.acquisition, name + ":no_extra_acquisition",
		{"serial_before": reference.acquisition.serial, "serial_after": acquisition.serial,
		"busy": acquisition.busy, "job": acquisition.job, "queue_size": acquisition.queue.size()})
	if _wrist_is_unarmed:
		_check_no_grip(name)
	_check(not bool(_actor.get_planar_grip_pose_state(slot).get("has_grip_pose", false)), name + ":edited_hand_has_no_binding")
	var marker_error := _nearest_marker_error(_wrist_focus(slot), _wrist_focus(slot), control.marker_position)
	_check(marker_error <= WRIST_POSITION_EPSILON, name + ":sphere_attached", {"error_m": marker_error})
	var edit: Dictionary = _preview().get_meta("independent_arm_edit_result", {})
	row["allocation"] = {}
	for field: String in ["valid", "status", "reason", "task_scale", "iterations", "hand_control_mode", "active_limits", "retained_previous_pose"]:
		if edit.has(field):
			row.allocation[field] = edit[field]
	_check(String(edit.get("authoring_frame_warning", "")).is_empty(), name + ":no_authoring_frame_warning")
	row["marker_error_m"] = marker_error
	return row

func _round_trip_wrist_pose(slots: Array[StringName]) -> void:
	var label := _station_name() + ":prepared_round_trip"
	var acquisition_before := _wrist_acquisition_state()
	# End with a nonzero angle so a stale/default snapshot cannot pass.
	for slot: StringName in slots:
		var control := _wrist_control(slot)
		if control.get("available", false):
			_ui.set_selected_motion_node_empty_hand_wrist_bend(slot, lerpf(control.minimum_degrees, control.maximum_degrees, 0.73))
	await _frames(4)
	var capture: Dictionary = {}
	for attempt: int in 12:
		capture = _ui.capture_selected_prepared_pose(false, true)
		if capture.get("valid", false) or capture.get("reason", "") != "prepared_pose_settling":
			break
		await _frames(3)
	_check(bool(capture.get("valid", false)), label + ":capture", capture)
	if not capture.get("valid", false):
		return
	var motion := _motion()
	var signature := PreparedPose.node_pose_signature(motion)
	_check(motion.prepared_pose_signature == signature, label + ":current_signature")
	var held: Dictionary = {}
	var held_fingers: Dictionary = {}
	for slot: StringName in slots:
		held[slot] = _movement_hand_world(slot)
		for rule: Dictionary in FingerHinges.get_chain_rules(slot, &"index"):
			var bone := _skeleton.find_bone(String(rule.bone))
			held_fingers[bone] = _skeleton.get_bone_pose_rotation(bone)
		var stored: Dictionary = motion.prepared_pose.get("wrist_states_by_slot", {}).get(slot, {})
		var measured: Dictionary = _actor.capture_wrist_motion_start_state(slot)
		_check(not stored.is_empty() and measured.get("valid", false), label + ":stored_wrist_available:" + String(slot))
		if not stored.is_empty() and measured.get("valid", false):
			for channel: String in ["rho", "beta", "gamma"]:
				_check(absf(rad_to_deg(float(stored[channel]) - float(measured.state[channel]))) <= WRIST_ANGLE_EPSILON,
					label + ":stored_" + channel + ":" + String(slot))
	var path := _out.path_join(_station_name().replace(":", "_") + "_wrist_node.tres")
	var saved := ResourceSaver.save(motion.duplicate_node(), path)
	var loaded: CombatAnimationMotionNode = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as CombatAnimationMotionNode if saved == OK else null
	_check(loaded != null and bool(PreparedPose.validate(loaded.prepared_pose).get("valid", false)) \
		and loaded.prepared_pose_signature == signature and PreparedPose.node_pose_signature(loaded) == signature,
		label + ":serialized_node_valid")
	if loaded == null:
		return
	var edited_slot: StringName = slots[0]
	var control := _wrist_control(edited_slot)
	_ui.set_selected_motion_node_empty_hand_wrist_bend(edited_slot, control.minimum_degrees)
	await _frames(2)
	_check(_movement_basis_angle(held[edited_slot].basis, _movement_hand_world(edited_slot).basis) > 0.1,
		label + ":live_pose_changed_before_restore")
	var draft: Resource = _ui.call("_get_active_draft")
	var chain: Array = draft.get("motion_node_chain")
	chain[_ui.get_selected_motion_node_index()] = loaded
	_ui.call("_refresh_preview_scene")
	await _frames(4)
	var restored: Dictionary = _preview().get_meta("prepared_authoring_pose_restore", {})
	_check(bool(restored.get("applied", false)), label + ":normal_refresh_restored_loaded_pose", restored)
	for slot: StringName in slots:
		var actual := _movement_hand_world(slot)
		_check(actual.origin.distance_to(held[slot].origin) <= WRIST_POSITION_EPSILON \
			and _movement_basis_angle(actual.basis, held[slot].basis) <= WRIST_ANGLE_EPSILON,
			label + ":restored_hand:" + String(slot), {"position_m": actual.origin.distance_to(held[slot].origin),
			"angle_degrees": _movement_basis_angle(actual.basis, held[slot].basis)})
		_check(FingerControls.get_curls(_motion(), slot) == _wrist_curls[slot], label + ":restored_curl:" + String(slot))
	var finger_error := 0.0
	for bone: int in held_fingers:
		finger_error = maxf(finger_error, _angle(held_fingers[bone], _skeleton.get_bone_pose_rotation(bone)))
	_check(finger_error <= WRIST_ANGLE_EPSILON, label + ":restored_finger_pose", {"max_angle_degrees": finger_error})
	var acquisition_after := _wrist_acquisition_state()
	_check(not acquisition_after.busy and not acquisition_after.job and acquisition_after.queue.is_empty(), label + ":restored_owner_idle")
	if _wrist_is_unarmed:
		_check(acquisition_after == acquisition_before, label + ":no_extra_acquisition")
		_check_no_grip(label)
	else:
		# Importing the saved ownership packet legitimately renews serials. The
		# restored reason and empty worker/queue distinguish it from acquisition.
		var grip_restore: Dictionary = _preview().get_meta("prepared_authoring_grip_restore", {})
		var owner := _actor.get_node_or_null("PreparedGripAcquisition")
		var statuses: Dictionary = owner.get("_status") if owner != null else {}
		var primary_status: Dictionary = statuses.get(_wrist_primary, {})
		_check(bool(grip_restore.get("valid", false)) and primary_status.get("reason", "") == "authoring_acquisition_restored",
			label + ":saved_binding_restored_without_acquisition", {"restore": grip_restore, "primary_status": primary_status,
			"serial_before": acquisition_before.serial, "serial_after": acquisition_after.serial})
		for slot: StringName in SLOTS:
			_check(bool(_actor.get_planar_grip_pose_state(slot).get("has_grip_pose", false)) == (slot == _wrist_primary),
				label + ":restored_binding_occupancy:" + String(slot))

func _finish() -> void:
	if _finished:
		return
	_finished = true
	if not _wrist_source_path.is_empty() and not _wrist_source_hash.is_empty():
		var after := FileAccess.get_sha256(_wrist_source_path)
		_report["source_sha256_after"] = after
		_check(after == _wrist_source_hash, "player_source_library_unchanged")
	_check(_report.cases.size() == _wrist_case_limit, "all_selected_empty_wrist_cases_executed")
	for entry: Dictionary in _report.cases:
		_check(bool(entry.get("complete", false)), "case_complete:" + String(entry.get("name", "")))
	_report.complete = _report.failures.is_empty()
	_write_movement_report()
	print("EMPTY_HAND_WRIST checks=%d failures=%d report=%s" % [_report.checks.size(), _report.failures.size(), _out])
	if is_instance_valid(_ui):
		_ui.queue_free()
	if is_instance_valid(_player):
		_player.queue_free()
	quit(0 if _report.failures.is_empty() else 1)
