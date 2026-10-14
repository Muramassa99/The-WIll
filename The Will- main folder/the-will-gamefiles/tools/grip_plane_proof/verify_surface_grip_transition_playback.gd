extends "res://tools/grip_plane_proof/verify_surface_grip_save_playback.gd"

## Actual Skill Crafter grip-style insertion, Save, reload and equipped replay.
## Reuses the isolated save proof's I/O guards and pose comparisons. The real
## draft chain is retained: no synthetic replacement of the generated bridge.
## Optional THE_WILL_GRIP_SAVE_TWO_HAND=1 adds support to the reverse follow-on.
const WipData = preload("res://core/models/crafted_item_wip.gd")
const TEST_STATION := 0.63
const TEST_ROLL_DEGREES := 23.0
const POSE_EPSILON := 0.00005
var _diagnostic_started_usec := 0
var _diagnostic_finished := false
var _diagnostic_phase := "initializing"

func _run() -> void:
	_prefix = "C:/WORKSPACE/test_artifacts/grip_transition_playback_" + Time.get_datetime_string_from_system().replace(":", "-")
	_report = {"scope": "real_generated_style_bridge_save_reload_equipped_replay", "visual_grip_certified": false}
	_diagnostic_started_usec = Time.get_ticks_usec()
	create_timer(180.0, true, false, true).timeout.connect(_on_diagnostic_timeout)
	_phase("load_source")
	_source = OS.get_environment("THE_WILL_GRIP_LIVE_LIBRARY").strip_edges()
	var isolated := OS.get_environment("THE_WILL_DIAGNOSTIC_USER_ROOT").replace("\\", "/").simplify_path().to_lower()
	if not _check(_workspace(isolated) and isolated == OS.get_user_data_dir().replace("\\", "/").simplify_path().to_lower(), "incidental user writes are isolated inside workspace"):
		_finish(); return
	if not _check(_workspace(_source) and FileAccess.file_exists(_source), "actual input library is a workspace copy"):
		_finish(); return
	_source_hash = FileAccess.get_sha256(_source)
	var input: Resource = ResourceLoader.load(_source, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	if not _check(input != null, "source library loads"):
		_finish(); return
	var requested := OS.get_environment("THE_WILL_GRIP_LIVE_WEAPON_NAME").strip_edges()
	if requested.is_empty(): requested = "Star_Handle_Testing"
	var chosen: Resource
	for item: Resource in input.saved_wips:
		if item.forge_project_name == requested: chosen = item
	if not _check(chosen != null, "named saved weapon exists"):
		_finish(); return
	_report.merge({"source_library": _source, "source_library_sha256": _source_hash,
		"weapon_name": requested, "output_prefix": _prefix, "primary_hand": HAND,
		"requested_station": TEST_STATION, "requested_roll_degrees": TEST_ROLL_DEGREES})
	_library_player = LibraryPlayer.new()
	_library_player.library = input.duplicate(true)
	_library_player.library.save_file_path = _prefix + "_library.tres"
	root.add_child(_library_player)
	_ui = UIScene.instantiate()
	root.add_child(_ui)
	await process_frame
	_phase("open_weapon_and_skill")
	_ui.open_for(_library_player, "Isolated real grip-style transition proof")
	if not _check(_ui.select_saved_wip(chosen.wip_id, true, {"dominant_slot_id": HAND, "use_two_hand": false}), "actual weapon opens right-hand primary"):
		_finish(); return
	_ui._on_skill_slot_selector_pressed(SKILL)
	var context: Dictionary = _ui.preview_presenter._weapon_roll_context(_ui.preview_subviewport)
	if not _check(not context.is_empty(), "real preview context exists"):
		_finish(); return
	if not await _await_grip("initial_normal"):
		_finish(); return
	var draft: Resource = _ui._get_active_draft()
	var source: Resource = _ui._get_active_motion_node()
	if not _check(source != null and source.preferred_grip_style_mode == WipData.GRIP_NORMAL
		and not source.locked_for_authoring, "fixture starts on an editable normal-grip pose"):
		_finish(); return
	_check(source.primary_hand_slot == HAND, "source uses the actual right-hand authority")
	_phase("set_handle_station")
	_ui.set_selected_motion_node_grip_seat_slide(TEST_STATION, false)
	if not await _await_grip("normal_nondefault_station"):
		_finish(); return
	_phase("set_weapon_roll")
	_ui.set_selected_motion_node_weapon_roll(TEST_ROLL_DEGREES, false)
	if not await _await_grip("normal_nondefault_station_roll"):
		_finish(); return
	_check(absf(source.grip_seat_slide_offset - TEST_STATION) < 0.000001
		and absf(source.weapon_roll_degrees - TEST_ROLL_DEGREES) < 0.000001, "normal pose keeps selected nondefault station and roll")
	_report["normal_actual_pose"] = _actual_snapshot(context)
	var source_index: int = draft.selected_motion_node_index
	var initial_count: int = draft.motion_node_chain.size()
	var original_prefix := _node_contracts(draft.motion_node_chain)
	_phase("insert_reverse_bridge")
	if not _check(_ui.set_selected_motion_node_preferred_grip_style(WipData.GRIP_REVERSE, false), "production UI inserts the reverse transition"):
		_finish(); return
	if not _check(draft.motion_node_chain.size() == initial_count + 2
		and draft.selected_motion_node_index == source_index + 2, "real chain adds bridge and selects authored follow-on"):
		_finish(); return
	var bridge_index := source_index + 1
	var follow_index := source_index + 2
	var bridge: Resource = draft.motion_node_chain[bridge_index]
	var follow: Resource = draft.motion_node_chain[follow_index]
	_check(bridge.generated_transition_node and bridge.locked_for_authoring
		and bridge.generated_transition_kind == MotionData.TRANSITION_KIND_GRIP_STYLE_SWAP, "inserted bridge remains generated and locked")
	_check(not follow.generated_transition_node and not follow.locked_for_authoring, "selected reverse follow-on remains editable")
	for node: Resource in [bridge, follow]:
		_check(node.preferred_grip_style_mode == WipData.GRIP_REVERSE and node.primary_hand_slot == HAND
			and absf(node.grip_seat_slide_offset - TEST_STATION) < 0.000001
			and absf(node.weapon_roll_degrees - TEST_ROLL_DEGREES) < 0.000001,
			"inserted node retains reverse style, right hand, station and roll")
	_check(_node_contracts(draft.motion_node_chain.slice(0, source_index + 1))
		== original_prefix.slice(0, source_index + 1), "style insertion preserves original source nodes")
	if not await _await_grip("reverse_follow_on"):
		_finish(); return
	if OS.get_environment("THE_WILL_GRIP_SAVE_TWO_HAND") == "1":
		_verified_hands.append(&"hand_left")
		_check(_ui.set_selected_motion_node_two_hand_state(MotionData.TWO_HAND_STATE_TWO_HAND, false), "reverse follow-on accepts support request")
		if not await _await_grip("reverse_support"):
			_finish(); return
	_report["reverse_actual_pose"] = _actual_snapshot(context)
	_report["authored_chain"] = _node_contracts(draft.motion_node_chain)
	var before_save := _node_contracts(draft.motion_node_chain)
	var reverse_hand: Transform3D = _hand_in_weapon(context.actor, context.weapon, HAND)
	draft.preview_loop_enabled = false
	_ui._mark_active_draft_runtime_clip_cache_dirty()
	_ui.editor_state_dirty = true
	var started := Time.get_ticks_usec()
	_phase("manual_save_actual_transition")
	await _ui._manual_save_active_editor_state()
	_report["save_ms"] = float(Time.get_ticks_usec() - started) / 1000.0
	_report["save_message"] = _ui.footer_status_label.text
	_check(_ui.footer_status_label.text.contains("Preview ready"), "Save restores selected authored preview")
	_check(_ui._get_active_draft() == draft and draft.selected_motion_node_index == follow_index,
		"Save preserves active reverse follow-on selection")
	_check(_node_contracts(draft.motion_node_chain) == before_save, "Save leaves actual authored transition chain intact")
	var after_hand := _hand_in_weapon(context.actor, context.weapon, HAND)
	_check(_transform_error(reverse_hand, after_hand) <= POSE_EPSILON, "Save restores reverse Hand-to-weapon relationship")
	var clip: Resource = draft.baked_runtime_clip
	if not _check(clip != null and clip.has_solved_replay_track(), "real transition Save produces solved replay track"):
		_finish(); return
	_check(_legacy_solve_count(context.actor) == 0, "prepared transition and bake perform no legacy serial solve")
	_report["baked_frame_count"] = clip.get_frame_count()
	_report["baked_chain"] = _node_contracts(clip.motion_node_chain)
	_report["trajectory_continuity"] = _trajectory_continuity(clip)
	_check(_contains_bridge_and_follow(clip.motion_node_chain, bridge.node_id, follow.node_id), "baked clip retains actual generated bridge and authored follow-on")
	_phase("reload_saved_transition")
	var persisted: Resource = ResourceLoader.load(_prefix + "_library.tres", "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	if not _check(persisted != null, "isolated saved library reloads"):
		_finish(); return
	persisted.save_file_path = _prefix + "_library.tres"
	var reloaded_wip: Resource = persisted.get_saved_wip_clone(chosen.wip_id)
	var reloaded_draft: Resource
	for item: Resource in reloaded_wip.combat_animation_station_state.skill_drafts:
		if item.draft_id == draft.draft_id: reloaded_draft = item
	if not _check(reloaded_draft != null and reloaded_draft.baked_runtime_clip != null, "saved transition skill reloads"):
		_finish(); return
	_check(_node_contracts(reloaded_draft.motion_node_chain) == before_save, "reload preserves node identity, bridge lock, station, roll and frame")
	var reloaded: Resource = reloaded_draft.baked_runtime_clip
	if not _check(reloaded.has_solved_replay_track() and reloaded.get_frame_count() == clip.get_frame_count(), "reloaded transition retains every replay frame"):
		_finish(); return
	_check(_track_error(clip, reloaded) <= POSE_EPSILON, "reload preserves recorded bone and weapon tracks")
	_check(reloaded.baked_grip_style_modes == clip.baked_grip_style_modes
		and reloaded.baked_grip_seat_slide_offsets == clip.baked_grip_seat_slide_offsets
		and reloaded.baked_weapon_roll_degrees == clip.baked_weapon_roll_degrees,
		"reload preserves style, station and roll sample tracks")
	var normal_frame := _style_frame(reloaded, WipData.GRIP_NORMAL, false)
	var reverse_frame := _style_frame(reloaded, WipData.GRIP_REVERSE, true)
	if not _check(normal_frame >= 0 and reverse_frame > normal_frame, "saved track contains normal then reverse solved samples"):
		_finish(); return
	_report["sampled_replay_frames"] = []
	_phase("replay_saved_preview_frames")
	for frame: int in [normal_frame, reverse_frame]:
		var chain := ChainPlayer.new()
		chain.prepare_runtime_clip(reloaded)
		chain.start()
		chain._apply_runtime_clip_sample(reloaded.baked_frame_times[frame])
		var state := _transition_frame_state(chain)
		_ui.preview_presenter.sync_playback_pose(_ui.preview_view_container, _ui.preview_subviewport,
			reloaded_wip, reloaded_draft, follow_index, state)
		var applied: Dictionary = context.root.get_meta("resolved_playback_state", {})
		_check(applied.get("solved_replay_applied", false), "recorded style frame applies through actual preview presenter")
		_check(_pose_error(context.actor, context.weapon, state) <= POSE_EPSILON, "preview applies recorded fingers and weapon together")
		_report.sampled_replay_frames.append({"frame": frame, "time_s": reloaded.baked_frame_times[frame],
			"style": chain.current_preferred_grip_style_mode, "station": chain.current_grip_seat_slide,
			"roll_degrees": chain.current_weapon_roll, "metrics": _last_pose_metrics.duplicate(true),
			"actual_pose": _actual_snapshot(context)})
	_ui.preview_presenter.cancel_grip_acquisition(_ui.preview_subviewport)
	_ui.queue_free()
	_ui = null
	await process_frame
	_phase("equipped_saved_transition")
	await _verify_equipped_transition(persisted, reloaded_wip)
	_finish()

func _await_grip(label: String) -> bool:
	_phase("await_" + label)
	var started := Time.get_ticks_usec()
	var statuses: Dictionary = {}
	var last_summary := ""
	while float(Time.get_ticks_usec() - started) / 1000000.0 < 120.0:
		await process_frame
		statuses = _ui.preview_presenter.get_grip_acquisition_status(_ui.preview_subviewport)
		var finished := true
		var summary: Dictionary = {}
		for slot: StringName in _verified_hands:
			var status: Dictionary = statuses.get(slot, {})
			summary[slot] = {"status": status.get("status", ""), "reason": status.get("reason", ""), "serial": status.get("serial", -1)}
			if status.get("status", "") not in ["preview_applied", "unresolved", "unavailable", "cancelled"]:
				finished = false
		var summary_text := JSON.stringify(summary)
		if summary_text != last_summary:
			last_summary = summary_text
			_report["latest_acquisition_state"] = summary
			print(JSON.stringify({"event": "grip_status", "stage": label, "elapsed_ms": _elapsed_ms(), "hands": summary}))
			_checkpoint()
		if finished: break
	_report[label + "_status"] = statuses.duplicate(true)
	_report[label + "_wait_ms"] = float(Time.get_ticks_usec() - started) / 1000.0
	var ready := true
	for slot: StringName in _verified_hands:
		ready = _check(statuses.get(slot, {}).get("status", "") == "preview_applied", label + ": committed " + str(slot)) and ready
	return ready

func _node_contracts(nodes: Array) -> Array:
	var rows: Array = []
	for node: Resource in nodes:
		rows.append({"id": node.node_id, "generated": node.generated_transition_node,
			"kind": node.generated_transition_kind, "locked": node.locked_for_authoring,
			"primary": node.primary_hand_slot, "two_hand": node.two_hand_state,
			"style": node.preferred_grip_style_mode, "station": node.grip_seat_slide_offset,
			"support_station": node.secondary_grip_seat_slide_offset, "roll": node.weapon_roll_degrees,
			"axial": node.axial_reposition_offset, "orientation": node.weapon_orientation_degrees,
			"tip": node.tip_position_local, "pommel": node.pommel_position_local,
			"transition_frame_available": node.grip_style_transition_frame_available,
			"transition_pivot": node.grip_style_transition_pivot_local,
			"transition_axis": node.grip_style_transition_axis_local,
			"transition_source_tip": node.grip_style_transition_source_tip_local,
			"transition_source_pommel": node.grip_style_transition_source_pommel_local,
			"transition_origin_id": node.grip_style_transition_origin_id})
	return rows

func _contains_bridge_and_follow(nodes: Array, bridge_id: StringName, follow_id: StringName) -> bool:
	for index: int in range(nodes.size() - 1):
		var a: Resource = nodes[index]
		var b: Resource = nodes[index + 1]
		if a.node_id == bridge_id and b.node_id == follow_id:
			return a.generated_transition_node and a.locked_for_authoring and not b.generated_transition_node and not b.locked_for_authoring
	return false

func _style_frame(clip: Resource, style: StringName, last: bool) -> int:
	var found := -1
	for frame: int in clip.get_frame_count():
		if clip.baked_grip_style_modes[frame] == style and clip.baked_solved_replay_frame_available[frame]:
			found = frame
			if not last: break
	return found

func _trajectory_continuity(clip: Resource) -> Dictionary:
	var count: int = clip.get_frame_count()
	if not _check(clip.baked_tip_positions_local.size() == count and clip.baked_pommel_positions_local.size() == count,
		"every recorded frame has authored tip and pommel endpoints"):
		return {"available": false, "reason": "endpoint_track_length_mismatch"}
	var rows: Array = []
	var finite_track := true
	var finite_nonzero_segments := true
	var valid_quaternions := true
	var minimum_length := INF
	var maximum_length := 0.0
	var maximum_length_change := 0.0
	var first_length: float = clip.baked_tip_positions_local[0].distance_to(clip.baked_pommel_positions_local[0])
	var max_translation := {"distance_m": 0.0, "from_frame": -1, "to_frame": -1}
	var max_rotation := {"angle_rad": 0.0, "angle_degrees": 0.0, "from_frame": -1, "to_frame": -1}
	for frame: int in count:
		var point: Vector3 = clip.baked_solved_weapon_positions_reference_local[frame]
		var raw: Vector4 = clip.baked_solved_weapon_rotations_reference_local[frame]
		var rotation := Quaternion(raw.x, raw.y, raw.z, raw.w)
		var tip: Vector3 = clip.baked_tip_positions_local[frame]
		var pommel: Vector3 = clip.baked_pommel_positions_local[frame]
		var length := tip.distance_to(pommel)
		var time: float = clip.baked_frame_times[frame]
		var finite := point.is_finite() and raw.is_finite() and tip.is_finite() and pommel.is_finite() and is_finite(time)
		finite_track = finite_track and finite
		finite_nonzero_segments = finite_nonzero_segments and is_finite(length) and length > 0.0
		valid_quaternions = valid_quaternions and rotation.is_finite() and rotation.length_squared() > 0.0
		if is_finite(length):
			minimum_length = minf(minimum_length, length)
			maximum_length = maxf(maximum_length, length)
			maximum_length_change = maxf(maximum_length_change, absf(length - first_length))
		var row := {"frame": frame, "time_s": time, "style": clip.baked_grip_style_modes[frame],
			"solved_available": clip.baked_solved_replay_frame_available[frame],
			"weapon_position_reference_local": point, "weapon_rotation_reference_local": raw,
			"authored_segment_length": length}
		if frame > 0 and finite and valid_quaternions and clip.baked_solved_replay_frame_available[frame] and clip.baked_solved_replay_frame_available[frame - 1]:
			var previous_raw: Vector4 = clip.baked_solved_weapon_rotations_reference_local[frame - 1]
			var previous := Quaternion(previous_raw.x, previous_raw.y, previous_raw.z, previous_raw.w)
			var delta := (rotation.normalized() * previous.normalized().inverse()).normalized()
			var angle := 2.0 * atan2(Vector3(delta.x, delta.y, delta.z).length(), absf(delta.w))
			var distance: float = point.distance_to(clip.baked_solved_weapon_positions_reference_local[frame - 1])
			row["rotation_from_previous_rad"] = angle
			row["translation_from_previous_m"] = distance
			if angle > float(max_rotation.angle_rad):
				max_rotation = {"angle_rad": angle, "angle_degrees": rad_to_deg(angle), "from_frame": frame - 1,
					"to_frame": frame, "from_time_s": clip.baked_frame_times[frame - 1], "to_time_s": time}
			if distance > float(max_translation.distance_m):
				max_translation = {"distance_m": distance, "from_frame": frame - 1, "to_frame": frame,
					"from_time_s": clip.baked_frame_times[frame - 1], "to_time_s": time}
		rows.append(row)
	_check(finite_track, "all recorded transition positions, rotations, times and endpoints are finite")
	_check(valid_quaternions, "all recorded transition rotations have nonzero quaternion length")
	_check(finite_nonzero_segments, "all authored tip-pommel segments remain finite and noncollapsed")
	var bridges: Array = []
	var node_time := 0.0
	for index: int in range(1, clip.motion_node_chain.size()):
		var node: Resource = clip.motion_node_chain[index]
		var end_time: float = node_time + node.transition_duration_seconds
		if node.generated_transition_kind == MotionData.TRANSITION_KIND_GRIP_STYLE_SWAP:
			var neighborhood: Array = []
			var first := 0
			while first + 1 < count and float(clip.baked_frame_times[first + 1]) < node_time: first += 1
			var last := first
			while last + 1 < count and float(clip.baked_frame_times[last]) < end_time: last += 1
			for frame: int in range(maxi(first - 2, 0), mini(last + 3, count)):
				neighborhood.append(rows[frame])
			bridges.append({"node_id": node.node_id, "node_index": index, "start_time_s": node_time,
				"end_time_s": end_time, "samples_including_two_adjacent_frames": neighborhood})
		node_time = end_time
	var maximum_neighborhoods: Dictionary = {}
	for key: String in ["rotation", "translation"]:
		var maximum: Dictionary = max_rotation if key == "rotation" else max_translation
		var at: int = maximum.to_frame
		var samples: Array = []
		if at >= 0:
			for frame: int in range(maxi(at - 2, 0), mini(at + 3, count)): samples.append(rows[frame])
		maximum_neighborhoods[key] = samples
	return {"available": true, "frame_count": count, "finite": finite_track,
		"valid_quaternion_lengths": valid_quaternions, "noncollapsed_authored_segments": finite_nonzero_segments,
		"authored_segment_length_min": minimum_length, "authored_segment_length_max": maximum_length,
		"authored_segment_length_first": first_length, "maximum_length_deviation_from_first": maximum_length_change,
		"source_weapon_length_meters": clip.source_weapon_length_meters,
		"maximum_adjacent_translation": max_translation, "maximum_adjacent_rotation": max_rotation,
		"maximum_neighborhoods": maximum_neighborhoods, "grip_style_bridge_neighborhoods": bridges,
		"smoothness_certified": false, "note": "Exact observed deltas; no new jump acceptance threshold is imposed."}

func _transition_frame_state(chain: RefCounted) -> Dictionary:
	var state := _clip_frame_state(chain)
	state.merge({"preferred_grip_style_mode": chain.current_preferred_grip_style_mode,
		"primary_hand_slot": chain.current_primary_hand_slot, "two_hand_state": chain.current_two_hand_state,
		"grip_seat_slide_offset": chain.current_grip_seat_slide, "secondary_grip_seat_slide_offset": chain.current_secondary_grip_seat_slide,
		"weapon_roll_degrees": chain.current_weapon_roll, "weapon_orientation_degrees": chain.current_weapon_orientation_degrees,
		"axial_reposition_offset": chain.current_axial_reposition,
		"tip_position_local": chain.current_tip_position, "pommel_position_local": chain.current_pommel_position,
		"tip_position_origin_id": chain.current_tip_position_origin_id,
		"pommel_position_origin_id": chain.current_pommel_position_origin_id})
	return state

func _actual_snapshot(context: Dictionary) -> Dictionary:
	var hands: Dictionary = {}
	for slot: StringName in _verified_hands:
		var rotations: Dictionary = {}
		for name: StringName in Rules.get_finger_bone_names(slot):
			rotations[name] = context.actor.skeleton.get_bone_pose_rotation(context.actor.skeleton.find_bone(name))
		hands[slot] = {"hand_in_weapon": _hand_in_weapon(context.actor, context.weapon, slot), "finger_rotations": rotations}
	return {"weapon_world": context.weapon.global_transform, "hands": hands}

func _transform_error(a: Transform3D, b: Transform3D) -> float:
	return maxf(a.origin.distance_to(b.origin), _rotation_error(a.basis.orthonormalized().get_rotation_quaternion(), b.basis.orthonormalized().get_rotation_quaternion()))

func _verify_equipped_transition(persisted: Resource, weapon_data: Resource) -> void:
	var equipment := Equipment.new()
	equipment.save_file_path = _prefix + "_equipment.tres"
	equipment.equip_forge_test_wip(HAND, weapon_data)
	var slots := Slots.new()
	slots.save_file_path = _prefix + "_slots.tres"
	_game_player = PlayerScene.instantiate()
	_game_player.equipment_state = equipment
	_game_player.forge_wip_library_state = persisted
	_game_player.player_skill_slot_state = slots
	_game_player.weapons_drawn = true
	root.add_child(_game_player)
	for _i: int in 4: await process_frame
	_game_player._sync_equipped_test_meshes()
	_game_player._sync_equipped_skill_slots()
	_check_runtime_reverse_support_policy(_game_player.runtime_skill_playback_presenter)
	var legacy_before := _legacy_solve_count(_game_player.humanoid_rig)
	_game_player._activate_skill_slot(SKILL)
	var activation: Dictionary = _game_player.get_last_skill_activation_result()
	_report["activation"] = activation
	if not _check(activation.get("runtime_playback_started", false), "equipped actual transition skill starts"):
		return
	var observed: Dictionary = {}
	for _i: int in 360:
		await physics_frame
		await process_frame
		var state: Dictionary = _game_player.runtime_skill_playback_presenter.last_runtime_pose_state
		if not state.get("solved_replay_applied", false) or state.get("solved_replay_bridge_frame", false): continue
		var style := StringName(state.get("preferred_grip_style_mode", &""))
		if style not in [WipData.GRIP_NORMAL, WipData.GRIP_REVERSE]: continue
		if observed.has(style): continue
		var weapon: Node3D = _game_player.held_item_nodes.get(HAND)
		var error := _pose_error(_game_player.humanoid_rig, weapon, state)
		_check(error <= POSE_EPSILON, "equipped " + str(style) + " applies saved finger and weapon frame")
		observed[style] = {"metrics": _last_pose_metrics.duplicate(true),
			"station": state.get("grip_seat_slide_offset"), "roll": state.get("weapon_roll_degrees")}
		if style == WipData.GRIP_REVERSE:
			_check(absf(float(state.get("grip_seat_slide_offset", -1.0)) - TEST_STATION) <= 0.000001
				and absf(float(state.get("weapon_roll_degrees", -1000.0)) - TEST_ROLL_DEGREES) <= 0.00001,
				"equipped reverse sample retains selected station and roll")
		if observed.has(WipData.GRIP_NORMAL) and observed.has(WipData.GRIP_REVERSE): break
	_report["equipped_observed_styles"] = observed
	_check(observed.has(WipData.GRIP_NORMAL) and observed.has(WipData.GRIP_REVERSE), "equipped playback visits normal and reverse recorded frames")
	_check(_legacy_solve_count(_game_player.humanoid_rig) == legacy_before, "equipped transition consumes recorded solve without legacy serial solve")

func _elapsed_ms() -> float:
	return float(Time.get_ticks_usec() - _diagnostic_started_usec) / 1000.0

func _phase(name: String) -> void:
	_diagnostic_phase = name
	var event := {"stage": name, "elapsed_ms": _elapsed_ms()}
	var events: Array = _report.get("stages", [])
	events.append(event)
	_report["stages"] = events
	_report["current_stage"] = name
	print(JSON.stringify(event))
	_checkpoint()

func _checkpoint() -> void:
	# Written before synchronous calls too, so an external engine timeout retains
	# the last completed evidence even if the engine cannot service its timer.
	_report["elapsed_ms"] = _elapsed_ms()
	var snapshot := _report.duplicate()
	snapshot["checks"] = _checks
	snapshot["failures"] = _failures.duplicate()
	DirAccess.make_dir_recursive_absolute("C:/WORKSPACE/test_artifacts")
	var checkpoint := FileAccess.open(_prefix + "_progress.json", FileAccess.WRITE)
	if checkpoint != null:
		checkpoint.store_string(JSON.stringify(snapshot, "\t"))
		checkpoint.close()

func _on_diagnostic_timeout() -> void:
	if _diagnostic_finished: return
	_report["timed_out"] = true
	_report["timeout_stage"] = _diagnostic_phase
	if is_instance_valid(_ui):
		_report["timeout_grip_status"] = _ui.preview_presenter.get_grip_acquisition_status(_ui.preview_subviewport)
		_report["timeout_save_message"] = _ui.footer_status_label.text
	_check(false, "overall diagnostic deadline reached in " + _diagnostic_phase)
	_finish()

func _finish() -> void:
	if _diagnostic_finished: return
	_diagnostic_finished = true
	_phase("finished")
	super._finish()

func _check_runtime_reverse_support_policy(presenter: RefCounted) -> void:
	# The policy fixture isolates style eligibility from the costly body solve.
	# Optional two-hand mode above additionally exercises real saved support poses.
	var held := Node3D.new()
	held.set_meta("two_hand_character_eligible", true)
	var guide := Node3D.new()
	guide.name = "SecondaryGripGuide"
	held.add_child(guide)
	var items: Dictionary = {HAND: held}
	for style: StringName in [WipData.GRIP_NORMAL, WipData.GRIP_REVERSE]:
		_check(presenter._resolve_support_hand_requested_from_values(held, items, &"hand_left", false,
			style, MotionData.TWO_HAND_STATE_TWO_HAND), "equipped eligible support request survives " + str(style))
	_check(not presenter._resolve_support_hand_requested_from_values(held, items, &"hand_left", true,
		WipData.GRIP_REVERSE, MotionData.TWO_HAND_STATE_ONE_HAND), "reverse explicit one-hand choice still excludes support")
	held.set_meta("two_hand_character_eligible", false)
	_check(not presenter._resolve_support_hand_requested_from_values(held, items, &"hand_left", false,
		WipData.GRIP_REVERSE, MotionData.TWO_HAND_STATE_TWO_HAND), "reverse retains anatomical support eligibility")
	held.set_meta("two_hand_character_eligible", true)
	var occupied := Node3D.new()
	items[&"hand_left"] = occupied
	_check(not presenter._resolve_support_hand_requested_from_values(held, items, &"hand_left", false,
		WipData.GRIP_REVERSE, MotionData.TWO_HAND_STATE_TWO_HAND), "reverse support does not steal an occupied hand")
	occupied.free()
	held.free()
