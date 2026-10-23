extends "res://tools/diagnose_incremental_skill_replay.gd"

## Opt-in real saved-asset checkpoint paths; default replay harness is unchanged.
## Same isolated environment, --cases=short --variant=support|reverse|left|left_reverse.
## Support uses the saved/reset pose, not the forward thrust timing fixture.
## Optional --support-station=0.2 reproduces the earlier real saved-asset support
## proof's UI request. Natural acquisition must succeed; no pose/reach override.
var _variant_active := false
var _variant_hand: StringName = &"hand_right"

func _run_case(label: String, _visible_count: int, _duration: float, _mode: String) -> bool:
	var variant: String = String(_options.get("variant", ""))
	if label != "short" or String(_options.get("cases", "")) != "short" or variant not in ["support", "reverse", "left", "left_reverse"]:
		_report["failure"] = "variant_harness_requires_cases_short_and_supported_variant"
		return false
	_variant_active = true
	_variant_hand = &"hand_left" if variant in ["left", "left_reverse"] else &"hand_right"
	_report["scope"] = "isolated saved-asset optional hand/style checkpoint paths; no grip or reach certification"
	_replay_row = {"case": "incremental_replay_" + variant, "variant": variant,
		"primary_hand": String(_variant_hand), "complete": false, "ok": false, "steps": [],
		"fixture": "unchanged saved/reset baseline, public R and hand/style controls; no thrust relocation"}
	_initial_output_hash = _hash_or_missing(String(_library.save_file_path))
	_previous_clip = null
	if _variant_hand != HAND:
		if not _ui.open_saved_wip_with_hand_setup(_weapon_id, _variant_hand, false, true) or not _ui.select_skill_slot(SLOT, true):
			return _end_replay_case("variant_hand_open_failed")
	if not _ui.reset_active_draft_to_baseline(): return _end_replay_case("variant_reset_failed")
	var draft: Resource = _ui.call("_get_active_draft")
	var first: int = _ui.call("_get_user_visible_motion_node_start_index", draft)
	if first != 1 or draft.motion_node_chain.size() != 2: return _end_replay_case("variant_hidden_entry_missing")
	_ui.select_motion_node(first)
	if not _set_variant_hand_state(CombatAnimationMotionNode.TWO_HAND_STATE_ONE_HAND): return _end_replay_case("variant_single_setup_failed")
	_ui.set_selected_motion_node_transition_duration(0.3, false)
	if variant in ["reverse", "left_reverse"]:
		# Actual generated-style proof: preserved station and roll, followed by
		# the public style setter's locked bridge and editable continuation.
		_replay_row["reverse_station_change_accepted"] = _ui.set_selected_motion_node_grip_seat_slide(0.63, false)
		# The station edit queues ordinary acquisition. The public roll setter
		# requires that work to finish; calling it immediately cancels the owner.
		var station_ready: Dictionary = await _wait_ready(0.0)
		_replay_row["reverse_station_readiness"] = station_ready
		if not bool(station_ready.get("ready", false)): return _end_replay_case("reverse_station_acquisition_unavailable")
		_replay_row["reverse_roll_change_accepted"] = _ui.set_selected_motion_node_weapon_roll(23.0, false)
	var ready: Dictionary = await _wait_ready(0.0)
	_replay_row["initial_variant_readiness"] = ready
	if not bool(ready.get("ready", false)): return _end_replay_case("variant_initial_acquisition_unavailable")
	if not await _prepare_and_check("variant_single_prime", false, true): return _end_replay_case("variant_prime_failed")
	if not await _check_cached_f(): return _end_replay_case("variant_cached_F_failed")
	if variant == "support":
		if not _ui.insert_motion_node_after_selection(): return _end_replay_case("support_R_failed")
		_ui.set_selected_motion_node_transition_duration(0.3, false)
		if _options.has("support-station"):
			var station: String = String(_options["support-station"])
			if not station.is_valid_float() or not is_finite(float(station)): return _end_replay_case("invalid_support_station")
			_ui.set_selected_motion_node_secondary_grip_seat_slide(float(station), false)
		if not _set_variant_hand_state(CombatAnimationMotionNode.TWO_HAND_STATE_TWO_HAND): return _end_replay_case("support_enable_failed")
		ready = await _wait_ready(0.0)
		_replay_row["support_readiness"] = ready
		if not bool(ready.get("ready", false)): return _end_replay_case("natural_support_fixture_unavailable")
		if not await _prepare_and_check("single_to_support", true, true): return _end_replay_case("support_prepare_failed")
		if not _ui.insert_motion_node_after_selection(): return _end_replay_case("release_R_failed")
		_ui.set_selected_motion_node_transition_duration(0.3, false)
		if not _set_variant_hand_state(CombatAnimationMotionNode.TWO_HAND_STATE_ONE_HAND): return _end_replay_case("support_release_failed")
		ready = await _wait_ready(0.0)
		_replay_row["release_readiness"] = ready
		if not bool(ready.get("ready", false)): return _end_replay_case("released_primary_unavailable")
		if not await _prepare_and_check("support_to_single", true, true): return _end_replay_case("release_prepare_failed")
	elif variant in ["reverse", "left_reverse"]:
		var before_count: int = draft.motion_node_chain.size()
		if not _ui.set_selected_motion_node_preferred_grip_style(CraftedItemWIP.GRIP_REVERSE, false):
			return _end_replay_case("real_reverse_transition_insertion_failed")
		if draft.motion_node_chain.size() != before_count + 2: return _end_replay_case("real_reverse_bridge_missing")
		_ui.set_selected_motion_node_transition_duration(0.3, false)
		ready = await _wait_ready(0.0)
		_replay_row["reverse_readiness"] = ready
		if not bool(ready.get("ready", false)): return _end_replay_case("natural_reverse_fixture_unavailable")
		if not await _prepare_and_check("generated_reverse_bridge", true, true): return _end_replay_case("reverse_prepare_failed")
	else:
		if not _ui.insert_motion_node_after_selection(): return _end_replay_case("left_R_failed")
		_ui.set_selected_motion_node_transition_duration(0.3, false)
		if not await _prepare_and_check("left_append", true, true): return _end_replay_case("left_append_failed")
	_ui.set_selected_motion_node_transition_duration(0.413, false)
	if not await _prepare_and_check("variant_terminal_duration_edit", true, true): return _end_replay_case("variant_duration_failed")
	_replay_row["sampled_variant_contract"] = _variant_sample_contract(variant)
	if not bool(_replay_row.sampled_variant_contract.ok): return _end_replay_case("variant_sample_contract_failed")
	if not await _check_save_reload(): return _end_replay_case("variant_save_reload_failed")
	return _end_replay_case("")

func _set_variant_hand_state(state: StringName) -> bool:
	var motion: CombatAnimationMotionNode = _ui.call("_get_active_motion_node")
	return motion != null and (motion.two_hand_state == state or _ui.set_selected_motion_node_two_hand_state(state, false))

func _wait_ready(minimum_seconds: float) -> Dictionary:
	if not _variant_active: return await super._wait_ready(minimum_seconds)
	var started := Time.get_ticks_msec()
	var stable_since := started
	var terminal_stable_since := started
	var previous_terminal_state := ""
	var row: Dictionary = {}
	while Time.get_ticks_msec() - started < 120000:
		await process_frame
		var context: Dictionary = _ui.preview_presenter._weapon_roll_context(_ui.preview_subviewport)
		if context.is_empty(): continue
		var actor: Node = context.actor
		var owner: Node = actor.get_node_or_null("PreparedGripAcquisition")
		if owner == null: continue
		var requested: Array[StringName] = [_variant_hand]
		var motion: CombatAnimationMotionNode = _ui.call("_get_active_motion_node")
		if motion != null and motion.two_hand_state == CombatAnimationMotionNode.TWO_HAND_STATE_TWO_HAND:
			requested.append(&"hand_right" if _variant_hand == &"hand_left" else &"hand_left")
		var statuses: Dictionary = owner.call("status")
		var hands: Dictionary = {}
		var owner_idle: bool = bool(owner.call("is_render_checkpoint_idle")) and not _ui.preview_drag_refresh_pending
		var ready: bool = owner_idle
		var terminal_failure := false
		for slot: StringName in requested:
			var status: Dictionary = statuses.get(slot, {})
			var binding: Dictionary = actor.call("get_planar_grip_pose_state", slot)
			hands[String(slot)] = {"status": status.get("status", ""), "reason": status.get("reason", ""),
				"binding_available": bool(binding.get("has_grip_pose", false))}
			ready = ready and status.get("status", "") == "preview_applied" and bool(binding.get("has_grip_pose", false))
			terminal_failure = terminal_failure or status.get("status", "") in ["unresolved", "unavailable", "cancelled"]
		var now := Time.get_ticks_msec()
		if not ready: stable_since = now
		var terminal_state: String = var_to_str(hands) if terminal_failure and owner_idle else ""
		if terminal_state.is_empty() or terminal_state != previous_terminal_state:
			terminal_stable_since = now
		previous_terminal_state = terminal_state
		row = {"ready": ready, "hands": hands, "wait_ms": now - started, "stable_ms": now - stable_since,
			"owner_idle": owner_idle, "terminal_stable_ms": now - terminal_stable_since, "no_reach_override": true}
		if terminal_failure and owner_idle and now - terminal_stable_since >= 1000:
			row["ready"] = false
			return row
		if ready and now - started >= minimum_seconds * 1000.0 and now - stable_since >= 1000: return row
	row["ready"] = false
	row["timeout"] = true
	return row

func _variant_sample_contract(variant: String) -> Dictionary:
	var draft: Resource = _ui.call("_get_active_draft")
	var clip: CombatRuntimeClip = draft.get("baked_runtime_clip") as CombatRuntimeClip
	if clip == null: return {"ok": false, "reason": "missing_clip"}
	var all_primary: bool = not clip.baked_primary_hand_slots.is_empty()
	for slot: Variant in clip.baked_primary_hand_slots: all_primary = all_primary and slot == _variant_hand
	var support_first := -1
	var support_last := -1
	var reverse_first := -1
	for index: int in clip.get_frame_count():
		if clip.baked_two_hand_states[index] == CombatAnimationMotionNode.TWO_HAND_STATE_TWO_HAND:
			if support_first < 0: support_first = index
			support_last = index
		if reverse_first < 0 and clip.baked_grip_style_modes[index] == CraftedItemWIP.GRIP_REVERSE: reverse_first = index
	var support_ok: bool = variant != "support" or (support_first > 0 and support_last < clip.get_frame_count() - 1)
	var reverse_ok: bool = variant not in ["reverse", "left_reverse"] or reverse_first > 0
	return {"ok": all_primary and support_ok and reverse_ok, "all_frames_primary_hand": all_primary,
		"support_first_frame": support_first, "support_last_frame": support_last, "reverse_first_frame": reverse_first,
		"frames": clip.get_frame_count(), "visible_nodes": _ui.call("_get_user_visible_motion_node_count", draft)}
