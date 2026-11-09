extends "res://tools/diagnose_broken_glave_skill_open.gd"

## Read-only full-chain follow-up. Uses the real saved WIP and UI handlers;
## persistence remains disabled by the parent opener. No authored pose edits.
var _audited := false
var _observations: Array[Dictionary] = []

func _saved_skill_summary(wip: Resource) -> Dictionary:
	var summary := super._saved_skill_summary(wip)
	_report["audit_scope"] = "Full saved chain inspection; playback-first or sequential selection with reversible endpoint probes; no disk writes to player data."
	_report["movement_audit"] = OS.get_environment("THE_WILL_GLAVE_MOVEMENT_AUDIT") == "1"
	var station: Resource = wip.get("combat_animation_station_state")
	for draft: Resource in station.get("skill_drafts"):
		if draft == null or StringName(draft.get("legal_slot_id")) != SLOT_ID:
			continue
		var saved: Array[Dictionary] = []
		for motion: Resource in draft.call("get_action_motion_node_chain"):
			var entry := {}
			for field: String in ["node_id", "node_index", "tip_position_local", "pommel_position_local", "weapon_orientation_degrees", "weapon_roll_degrees", "grip_seat_slide_offset", "secondary_grip_seat_slide_offset", "two_hand_state", "primary_hand_slot", "body_support_blend", "prepared_pose", "prepared_pose_signature"]:
				entry[field] = motion.get(field)
			saved.append(entry)
		_write_audit("saved_nodes.json", saved)
		if OS.get_environment("THE_WILL_GLAVE_MOVEMENT_AUDIT") == "1":
			draft.set("selected_motion_node_index", 1)
	return summary

func _finish(reason: String, workflow_completed: bool) -> void:
	if reason == "opening_observation_complete" and not _audited:
		_audited = true
		await _snapshot("opened_selected_node")
		_record("audit_before_F" if OS.get_environment("THE_WILL_GLAVE_MOVEMENT_AUDIT") != "1" else "audit_F_deliberately_skipped")
		if OS.get_environment("THE_WILL_GLAVE_MOVEMENT_AUDIT") != "1":
			_ui.call("_toggle_preview_playback")
		var play_started := Time.get_ticks_msec()
		var next_sample := play_started
		var ever_playing := false
		while Time.get_ticks_msec() - play_started < 20000:
			await process_frame
			var player: RefCounted = _ui.get("chain_player")
			var playing := bool(player.call("is_playing"))
			ever_playing = ever_playing or playing
			if Time.get_ticks_msec() >= next_sample:
				_observations.append({"phase": "F", "elapsed_ms": Time.get_ticks_msec() - play_started, "playing": playing, "preparing": _ui.get("preview_prepare_in_progress"), "status": _read_grip_status()})
				next_sample += 150
			if Time.get_ticks_msec() - play_started > 2000 and not playing and not bool(_ui.get("preview_prepare_in_progress")):
				break
		_report["F_ever_playing"] = ever_playing
		await _snapshot("after_F")
		if bool(_ui.get("preview_prepare_in_progress")):
			_ui.call("_cancel_preview_preparation", "Diagnostic observation window ended.")
		var chain_player: RefCounted = _ui.get("chain_player")
		if bool(chain_player.call("is_playing")):
			_ui.call("_toggle_preview_playback")
		var draft: Resource = _ui.call("_get_active_draft")
		var chain: Array = draft.get("motion_node_chain")
		var first: int = _ui.call("_get_user_visible_motion_node_start_index", draft)
		for index: int in range(first, chain.size()):
			_record("audit_before_node_select", {"index": index})
			var accepted := bool(_ui.call("select_motion_node", index))
			var started := Time.get_ticks_msec()
			var sample_at := started
			while Time.get_ticks_msec() - started < 60000:
				await process_frame
				var status := _read_grip_status()
				if Time.get_ticks_msec() >= sample_at:
					_observations.append({"phase": "selection", "requested_index": index, "actual_index": _ui.call("get_selected_motion_node_index"), "elapsed_ms": Time.get_ticks_msec() - started, "status": status})
					sample_at += 500
				if Time.get_ticks_msec() - started > 2500 and not bool(status.get("acquisition_pending", false)) and not bool(_ui.call("is_motion_node_recording_pending")):
					break
			_record("audit_after_node_select", {"index": index, "accepted": accepted, "actual_index": _ui.call("get_selected_motion_node_index"), "elapsed_ms": Time.get_ticks_msec() - started})
			await _snapshot("node_%02d" % index)
			var probe_first := int(OS.get_environment("THE_WILL_GLAVE_PROBE_FIRST")) if not OS.get_environment("THE_WILL_GLAVE_PROBE_FIRST").is_empty() else 3
			if index >= probe_first and OS.get_environment("THE_WILL_GLAVE_MOVEMENT_AUDIT") == "1":
				await _probe_movements(index)
		_write_audit("observations.json", _observations)
	await super._finish(reason, workflow_completed)

func _snapshot(label: String) -> void:
	var viewport: SubViewport = _ui.get("preview_subviewport")
	var preview_root: Node3D = viewport.get_node_or_null("CombatAnimationPreviewRoot3D")
	var actor: Node3D = preview_root.get_node_or_null("PreviewActorPivot/PreviewActor")
	var weapon: Node3D = preview_root.get_meta("preview_held_item", null)
	var skeleton: Skeleton3D = actor.get("skeleton")
	var data := {"label": label, "selected_index": _ui.call("get_selected_motion_node_index"), "grip": _read_grip_status(), "debug": _ui.call("get_preview_debug_state"), "weapon_world": weapon.global_transform, "actor_world": actor.global_transform, "skeleton_world": skeleton.global_transform, "bones": {}}
	for bone_name: String in ["RL_BoneRoot", "CC_Base_Waist", "CC_Base_Spine01", "CC_Base_Spine02", "CC_Base_L_Clavicle", "CC_Base_R_Clavicle", "CC_Base_L_Upperarm", "CC_Base_R_Upperarm", "CC_Base_L_Forearm", "CC_Base_R_Forearm", "CC_Base_L_Hand", "CC_Base_R_Hand", "CC_Base_L_Index1", "CC_Base_L_Pinky1", "CC_Base_R_Index1", "CC_Base_R_Pinky1"]:
		var index := skeleton.find_bone(bone_name)
		if index >= 0:
			data.bones[bone_name] = {"parent": skeleton.get_bone_parent(index), "parent_local": skeleton.get_bone_pose(index), "skeleton_local": skeleton.get_bone_global_pose(index), "world": skeleton.global_transform * skeleton.get_bone_global_pose(index)}
	for slot: StringName in [&"hand_right", &"hand_left"]:
		data[String(slot) + "_wrist"] = actor.call("capture_wrist_constraint_state", slot)
	data["two_hand_solve"] = actor.get("last_two_hand_solve_result")
	data["wrist_failures"] = actor.get("_wrist_motion_failures")
	data["shoulder_states"] = actor.get("_shoulder_motion_states")
	data["twist_distribution"] = actor.get("authoring_limb_twist_distribution_state")
	data["forearm_hand_validation"] = actor.call("validate_authoring_forearm_hand_indexing")
	data["allocation"] = preview_root.get_meta("weapon_motion_allocation_result", {})
	var owner: Node = actor.get_node_or_null("PreparedGripAcquisition")
	if owner != null:
		data["support_clamp_count"] = owner.get("_support_motion_clamp_count")
		data["last_support_clamp"] = owner.get("_last_support_motion_clamp")
	var span: Vector3 = weapon.global_basis * ((weapon.get_meta("primary_grip_span_end_local") as Vector3) - (weapon.get_meta("primary_grip_span_start_local") as Vector3))
	data["index_pinky_to_handle_angle_degrees"] = {}
	for side: String in ["L", "R"]:
		var index_position := (skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone("CC_Base_" + side + "_Index1"))).origin
		var pinky_position := (skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone("CC_Base_" + side + "_Pinky1"))).origin
		data.index_pinky_to_handle_angle_degrees[side] = rad_to_deg(acos(clampf(absf(span.normalized().dot((index_position - pinky_position).normalized())), 0.0, 1.0)))
	_write_audit(label + ".json", data)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(_directory.path_join(label + ".png"))

func _probe_movements(index: int) -> void:
	var presenter: RefCounted = _ui.get("preview_presenter")
	var viewport: SubViewport = _ui.get("preview_subviewport")
	var preview_root: Node3D = viewport.get_node_or_null("CombatAnimationPreviewRoot3D")
	var motion: Resource = _ui.call("_get_active_motion_node")
	var original: Resource = motion.duplicate(true)
	var results: Array[Dictionary] = []
	for control: String in ["pommel", "tip"]:
		for direction: Vector3 in [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.BACK, Vector3.FORWARD]:
			# Motion checkpoints are same-frame transactions. Never reuse one
			# after awaiting a frame: acquisition guards deliberately reject it.
			var checkpoint: Dictionary = presenter.call("capture_authoring_motion_checkpoint", viewport)
			var target: Vector3 = motion.get(control + "_position_local")
			var request := target + direction * (0.03 if control == "pommel" else 0.10)
			var started := Time.get_ticks_usec()
			var accepted: bool = _ui.call("set_selected_motion_node_" + control + "_position", request, false, false, false, true, false)
			var row := {"node": index, "control": control, "direction": direction, "requested_distance_m": target.distance_to(request), "accepted": accepted, "elapsed_ms": float(Time.get_ticks_usec() - started) / 1000.0, "stored_displacement": (motion.get(control + "_position_local") as Vector3) - target, "validation": _ui.get_meta("last_endpoint_motion_validation", {}), "allocation": preview_root.get_meta("weapon_motion_allocation_result", {}), "grip": _read_grip_status()}
			_restore_probe_node(motion, original)
			row["checkpoint_restored_same_frame"] = presenter.call("restore_authoring_motion_checkpoint", checkpoint)
			results.append(row)
			_write_audit("node_%02d_movements.json" % index, results)
			if not row.checkpoint_restored_same_frame:
				_record("audit_probe_restore_failed", {"node": index, "control": control, "direction": direction})
				return
			await process_frame
	_restore_probe_node(motion, original)
	_ui.call("_refresh_endpoint_motion_visuals")
	await process_frame

func _restore_probe_node(target: Resource, source: Resource) -> void:
	for property: Dictionary in source.get_property_list():
		if int(property.usage) & PROPERTY_USAGE_STORAGE and String(property.name) != "script":
			target.set(property.name, source.get(property.name))

func _write_audit(name: String, data: Variant) -> void:
	var file := FileAccess.open(_directory.path_join(name), FileAccess.WRITE)
	file.store_string(JSON.stringify(data, "\t"))
	file.flush()
