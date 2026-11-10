extends "res://tools/diagnose_glave_skill_one_offhand.gd"

## Observation only. Real saved Skill 2, real station Save/F handlers. No Reset,
## reacquire button, endpoint setters, hand-mode setters or control-point motion.
const AUDIT_SLOT := &"skill_slot_2"
const Prepared := preload("res://core/models/combat_prepared_pose.gd")
const AuditChronology := preload("res://runtime/player/grip/grip_chronology.gd")
var _finished_audit := false
var _play_samples: Array = []
var _node_samples: Array = []
var _before_fields: Array = []
var _selected_wip: Resource
var _audit_library: Resource

func _run() -> void:
	_started_usec = Time.get_ticks_usec()
	_directory = OS.get_environment("THE_WILL_GLAVE_OPEN_DIRECTORY")
	if _directory.is_empty() or FileAccess.file_exists(_directory.path_join("report.json")):
		push_error("Fresh audit directory required")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(_directory)
	_log = FileAccess.open(_directory.path_join("stages.jsonl"), FileAccess.WRITE)
	process_frame.connect(_on_process_frame)
	_source_path = ProjectSettings.globalize_path(SOURCE_LIBRARY)
	_source_hash = FileAccess.get_sha256(_source_path)
	var copied := DirAccess.copy_absolute(_source_path, _directory.path_join("player_library_before.tres"))
	_report = {"scope": "Real Glave Skill 2 observation, Save, nodes and full F; no authored control changes", "backup_error": copied,
		"source_sha256_before": _source_hash, "source_path": _source_path, "slot": AUDIT_SLOT}
	if copied != OK:
		await _complete("backup_failed")
		return
	_audit_library = ResourceLoader.load(SOURCE_LIBRARY, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	for item: Resource in _audit_library.call("get_saved_wips"):
		if String(item.get("forge_project_name")) == TARGET_NAME:
			_selected_wip = item
	if _selected_wip == null:
		await _complete("weapon_missing")
		return
	var original := _find_skill(_selected_wip)
	if original == null:
		await _complete("skill_missing")
		return
	ResourceSaver.save(original.duplicate(true), _directory.path_join("skill_before.tres"))
	_before_fields = _fields(original)
	_write_audit("saved_nodes_before.json", _nodes(original))
	_record("source_loaded", {"visible_nodes": original.call("get_action_motion_node_chain").size()})
	_player = FakePlayer.new()
	_player.set("forge_wip_library_state", _audit_library)
	root.add_child(_player)
	_ui = (load(UI_SCENE) as PackedScene).instantiate()
	root.add_child(_ui)
	await process_frame
	# Synthetic station actions only. The camera is orbited below; native input
	# cannot accidentally alter the benchmark while screenshots are captured.
	root.gui_disable_input = true
	_ui.set_process_input(false)
	_ui.set_process_unhandled_input(false)
	_ui.set_meta("trace_save_latency", true)
	_ui.call("open_for", _player, "Glave Skill 2 observation")
	_record("before_weapon_open")
	var opened: bool = _ui.call("select_saved_wip", _selected_wip.get("wip_id"), true)
	var selected: bool = _ui.call("select_skill_slot", AUDIT_SLOT, true)
	_record("slot_opened", {"opened": opened, "selected": selected})
	if not opened or not selected:
		await _complete("opening_failed")
		return
	await _settle("opened")
	await _snapshot("opened")
	_write_audit("nodes_after_open.json", _nodes(_draft()))
	if OS.get_environment("THE_WILL_GLAVE_SUPPORT_JOIN_ONLY") == "1":
		# Focused continuation after Save/navigation/F were already verified.
		# Select the existing endpoint without changing its authored controls.
		var endpoint_chain: Array = _draft().get("motion_node_chain")
		_ui.call("select_motion_node", endpoint_chain.size() - 1)
		await _settle("support_join_endpoint")
		await _snapshot("support_join_endpoint")
		await _probe_support_join()
		await _snapshot("support_join_result")
		await _complete("observation_complete")
		return
	if OS.get_environment("THE_WILL_GLAVE_AUDIT_REPLAY_ONLY") == "1":
		# Second view of the actual saved skill: camera only, no node navigation
		# and no further Save. This avoids selection-triggered acquisition edits.
		_ui.call("zoom_preview_camera", 3)
		_ui.call("orbit_preview_camera", Vector2(90.0, -15.0))
		await _play_audit()
		await _snapshot("after_full_F")
		var replay_clip: Resource = _ui.get("chain_player").get("runtime_clip")
		if replay_clip != null:
			ResourceSaver.save(replay_clip, _directory.path_join("F_clip_with_entry.tres"))
		_report["ui_last_preview"] = _ui.get_meta("last_preview_prepare_result", {})
		_write_audit("nodes_after_F.json", _nodes(_draft()))
		await _complete("observation_complete")
		return
	var continuity_mode := OS.get_environment("THE_WILL_GLAVE_AUDIT_CONTINUITY")
	_report["continuity_mode"] = continuity_mode
	if continuity_mode.is_empty():
		await _save_audit("initial_save")
		await _snapshot("after_initial_save")
		_write_audit("nodes_after_initial_save.json", _nodes(_draft()))
	var chain: Array = _draft().get("motion_node_chain")
	var first: int = _ui.call("_get_user_visible_motion_node_start_index", _draft())
	for index: int in range(first, chain.size()):
		_record("before_node", {"index": index})
		var accepted: bool = _ui.call("select_motion_node", index)
		var immediate := _measure("node_%02d_immediate" % index)
		await _settle("node_%02d" % index)
		var settled := _measure("node_%02d_settled" % index)
		_node_samples.append({"index": index, "accepted": accepted, "immediate": immediate, "settled": settled})
		_write_audit("node_observations.json", _node_samples)
		await _snapshot("node_%02d" % index)
		# Same pose, a second view to inspect forearm/hand skin and contact.
		_ui.call("orbit_preview_camera", Vector2(190.0, -15.0))
		await _image("node_%02d_oblique" % index)
		_ui.call("orbit_preview_camera", Vector2(-190.0, 15.0))
	_write_audit("nodes_after_navigation.json", _nodes(_draft()))
	if continuity_mode == "repair":
		# One-time legacy recovery may lack acquired packets. Visit the real
		# nodes first, then persist only what the production capture completed.
		await _save_audit("continuity_save")
		_write_audit("nodes_after_continuity_save.json", _nodes(_draft()))
	await _play_audit()
	await _snapshot("after_full_F")
	_write_audit("nodes_after_F.json", _nodes(_draft()))
	var clip: Resource = _draft().get("baked_runtime_clip")
	if clip != null:
		ResourceSaver.save(clip, _directory.path_join("runtime_clip_after_F.tres"))
		_report["clip_diagnostics"] = clip.get("compile_diagnostics")
		_report["endpoint_track_diagnostics"] = clip.get_meta("prepared_endpoint_track_diagnostics", {})
	var entry_clip: Resource = _ui.get("chain_player").get("runtime_clip")
	if entry_clip != null:
		ResourceSaver.save(entry_clip, _directory.path_join("F_clip_with_entry.tres"))
	_report["endpoint_recording"] = _ui.get_meta("last_endpoint_recording_result", {})
	_report["node_feedback"] = _ui.get("_motion_node_validation_feedback")
	_report["ui_last_save"] = _ui.get_meta("last_save_latency_trace", {})
	_report["ui_last_render"] = _ui.get_meta("last_save_render_result", {})
	_report["ui_last_preview"] = _ui.get_meta("last_preview_prepare_result", {})
	_report["authored_fields_unchanged_after_observation"] = _before_fields == _fields(_draft())
	ResourceSaver.save(_draft().duplicate(true), _directory.path_join("skill_after_observation.tres"))
	if OS.get_environment("THE_WILL_GLAVE_SUPPORT_JOIN_PROBE") == "1":
		await _probe_support_join()
	await _complete("observation_complete")

func _probe_support_join() -> void:
	# Separate opt-in implementation probe after recording the unchanged
	# benchmark. Production UI changes only, never persisted to the library.
	var node: Resource = _ui.call("_get_active_motion_node")
	var original_state: StringName = node.get("two_hand_state")
	_record("support_join_probe_begin")
	_ui.call("set_selected_motion_node_two_hand_state", &"two_hand_one_hand", false)
	await _settle("support_join_one_hand")
	var before := _measure("before_support_join")
	_ui.call("set_selected_motion_node_two_hand_state", &"two_hand_two_hand", false)
	var immediate := _measure("support_join_immediate")
	await _settle("support_join_two_hand")
	var settled := _measure("support_join_settled")
	_ui.call("_refresh_preview_scene")
	await _settle("support_join_refresh")
	var refreshed := _measure("support_join_refreshed")
	_write_audit("support_join_probe.json", {"before": before, "immediate": immediate, "settled": settled, "refreshed": refreshed,
		"saved_to_library": false, "original_state": original_state})
	if original_state != &"two_hand_two_hand":
		_ui.call("set_selected_motion_node_two_hand_state", original_state, false)
	_record("support_join_probe_end")

func _find_skill(wip: Resource) -> Resource:
	for draft: Resource in wip.get("combat_animation_station_state").get("skill_drafts"):
		if draft != null and StringName(draft.get("legal_slot_id")) == AUDIT_SLOT:
			return draft
	return null

func _draft() -> Resource:
	return _ui.call("_get_active_draft")

func _fields(draft: Resource) -> Array:
	var result: Array = []
	for node: Resource in draft.call("get_action_motion_node_chain"):
		var row := {}
		for property: Dictionary in node.get_property_list():
			var name := String(property.name)
			if int(property.usage) & PROPERTY_USAGE_STORAGE and name != "script" and not name.begins_with("prepared_"):
				row[name] = node.get(name)
		result.append(row)
	return result

func _nodes(draft: Resource) -> Array:
	var result := _fields(draft)
	var chain: Array = draft.call("get_action_motion_node_chain")
	for i: int in chain.size():
		result[i]["prepared_pose"] = chain[i].get("prepared_pose")
		result[i]["prepared_signature"] = chain[i].get("prepared_pose_signature")
		result[i]["signature_matches"] = chain[i].get("prepared_pose_signature") == Prepared.node_pose_signature(chain[i])
		result[i]["packet_validation"] = Prepared.validate(chain[i].get("prepared_pose"))
		result[i]["snapshot_hash"] = hash(chain[i].get("prepared_pose"))
		if "prepared_grip" in chain[i]:
			result[i]["prepared_grip"] = chain[i].get("prepared_grip")
	return result

func _record(stage: String, details: Dictionary = {}, change_stage: bool = true) -> void:
	super._record(stage, details, change_stage)
	AuditChronology.event("audit.phase", {"stage": stage, "details": details})

func _settle(label: String) -> void:
	var started := Time.get_ticks_msec()
	var sample_at := started
	while Time.get_ticks_msec() - started < 45000:
		await process_frame
		var status := _read_grip_status()
		if Time.get_ticks_msec() >= sample_at:
			_record("settling", {"label": label, "elapsed_ms": Time.get_ticks_msec() - started, "grip": status}, false)
			sample_at += 1000
		if Time.get_ticks_msec() - started >= 1500 and not status.get("acquisition_pending", false) and not _ui.call("is_motion_node_recording_pending"):
			break

func _save_audit(label: String) -> void:
	_record(label + "_start")
	var started := Time.get_ticks_msec()
	_ui.call("_on_manual_save_pressed")
	await process_frame
	while (_ui.get("manual_save_in_progress") or _ui.call("is_motion_node_recording_pending")) and Time.get_ticks_msec() - started < 120000:
		await process_frame
	_report[label] = {"elapsed_ms": Time.get_ticks_msec() - started, "footer": _ui.get("footer_status_label").text,
		"still_saving": _ui.get("manual_save_in_progress"), "trace": _ui.get_meta("last_save_latency_trace", {}),
		"source_hash": FileAccess.get_sha256(_source_path)}
	_record(label + "_end", _report[label])

func _measure(label: String) -> Dictionary:
	var viewport: SubViewport = _ui.get("preview_subviewport")
	var preview: Node3D = viewport.get_node("CombatAnimationPreviewRoot3D")
	var actor: Node3D = preview.get_node("PreviewActorPivot/PreviewActor")
	var skeleton: Skeleton3D = actor.get("skeleton")
	var weapon: Node3D = preview.get_meta("preview_held_item")
	var playback: RefCounted = _ui.get("chain_player")
	var result := {"label": label, "selected": _ui.call("get_selected_motion_node_index"), "time": playback.get("_clip_elapsed"),
		"frame": playback.get("_clip_frame_index"), "playing": playback.call("is_playing"), "bones": {}, "contacts": {},
		"weapon": _transform(weapon.global_transform), "grip": _read_grip_status(),
		"runtime_validation": actor.get_meta("last_solved_body_replay_validation", {}),
		"runtime_state": preview.get_meta("resolved_playback_state", {}).get("active", false),
		"wrist_failures": actor.get("_wrist_motion_failures"), "shoulder_states": actor.get("_shoulder_motion_states")}
	result["requested_replay"] = {"names": playback.get("current_solved_upper_body_bone_names"),
		"positions": playback.get("current_solved_upper_body_pose_positions"),
		"rotations": playback.get("current_solved_upper_body_pose_rotations"),
		"scales": playback.get("current_solved_upper_body_pose_scales")}
	result["grip_restore"] = preview.get_meta("prepared_authoring_grip_restore", {}).duplicate(true)
	result["solved_fast_path"] = preview.get_meta("preview_runtime_solved_replay_fast_path_active", false)
	result["rig_replay_active"] = actor.get("runtime_solved_replay_pose_state").get("active", false)
	for i: int in skeleton.get_bone_count():
		var name := String(skeleton.get_bone_name(i))
		if name == "RL_BoneRoot" or name.contains("Spine") or name.contains("Waist") or name.contains("Clavicle") or name.contains("Upperarm") or name.contains("Forearm") or name.ends_with("Hand") or name.ends_with("Index1") or name.ends_with("Pinky1"):
			result.bones[name] = {"parent": skeleton.get_bone_parent(i), "local": _transform(skeleton.get_bone_pose(i)), "world": _transform(skeleton.global_transform * skeleton.get_bone_global_pose(i))}
	for slot: StringName in [&"hand_right", &"hand_left"]:
		var binding: Dictionary = actor.get("planar_grip_pose_binding").call("relationship", slot, weapon)
		var hand_index := skeleton.find_bone("CC_Base_R_Hand" if slot == &"hand_right" else "CC_Base_L_Hand")
		var actual := skeleton.global_transform * skeleton.get_bone_global_pose(hand_index)
		var contact := {"binding_present": binding.get("hand_in_weapon") is Transform3D,
			"wrist": actor.call("capture_wrist_motion_start_state", slot)}
		if contact.binding_present:
			var expected: Transform3D = weapon.global_transform * (binding.hand_in_weapon as Transform3D)
			contact["position_error_m"] = actual.origin.distance_to(expected.origin)
			contact["angle_error_degrees"] = rad_to_deg(actual.basis.orthonormalized().get_rotation_quaternion().angle_to(expected.basis.orthonormalized().get_rotation_quaternion()))
			contact["mate"] = _transform(binding.hand_in_weapon)
		result.contacts[slot] = contact
	# Playback owns and clears its pose arrays each frame. Freeze the observation
	# now instead of retaining references which would later become empty.
	return result.duplicate(true)

func _transform(value: Transform3D) -> Dictionary:
	var q := value.basis.orthonormalized().get_rotation_quaternion()
	return {"p": [value.origin.x, value.origin.y, value.origin.z], "q": [q.x, q.y, q.z, q.w], "scale": [value.basis.get_scale().x, value.basis.get_scale().y, value.basis.get_scale().z]}

func _image(label: String) -> void:
	await RenderingServer.frame_post_draw
	(_ui.get("preview_subviewport") as SubViewport).get_texture().get_image().save_jpg(_directory.path_join(label + ".jpg"), 0.9)

func _play_audit() -> void:
	_record("F_requested")
	_ui.call("_on_play_preview_pressed")
	var started := Time.get_ticks_msec()
	var ever_played := false
	var sample_time := 0
	var image_time := 0
	var image_count := 0
	var previous_clip_time := -1.0
	var resize_probed := false
	while Time.get_ticks_msec() - started < 120000:
		await RenderingServer.frame_post_draw
		var playback: RefCounted = _ui.get("chain_player")
		var playing: bool = playback.call("is_playing")
		var clip_time: float = playback.get("_clip_elapsed")
		if playing and clip_time >= 0.4 and not resize_probed and OS.get_environment("THE_WILL_GLAVE_RESIZE_PROBE") == "1":
			resize_probed = true
			var before_resize := _measure("before_resize_handler")
			_ui.call("_on_preview_container_resized")
			var after_resize := _measure("after_resize_handler")
			_write_audit("resize_pose_probe.json", {"before": before_resize, "after": after_resize})
		if ever_played and playing and clip_time < previous_clip_time - 0.01:
			_record("first_loop_complete")
			_ui.call("_on_play_preview_pressed")
			break
		previous_clip_time = clip_time
		ever_played = ever_played or playing
		var now := Time.get_ticks_msec()
		if playing and now >= sample_time:
			_play_samples.append(_measure("F"))
			sample_time = now + 30
		if playing and now >= image_time:
			(_ui.get("preview_subviewport") as SubViewport).get_texture().get_image().save_jpg(_directory.path_join("F_%04d.jpg" % image_count), 0.85)
			image_count += 1
			image_time = now + 140
		if ever_played and not playing:
			break
		if now - started > 3000 and not playing and not bool(_ui.get("preview_prepare_in_progress")):
			break
	_write_audit("playback_frames.json", _play_samples)
	_report["F"] = {"ever_played": ever_played, "elapsed_ms": Time.get_ticks_msec() - started, "samples": _play_samples.size(), "images": image_count, "footer": _ui.get("footer_status_label").text}
	_record("F_complete", _report.F)

func _complete(reason: String) -> void:
	if _finished_audit:
		return
	_finished_audit = true
	_report["reason"] = reason
	_report["source_sha256_after"] = FileAccess.get_sha256(_source_path)
	_report["no_authored_control_setters_called"] = OS.get_environment("THE_WILL_GLAVE_SUPPORT_JOIN_PROBE") != "1"
	_report["unsaved_support_join_probe"] = OS.get_environment("THE_WILL_GLAVE_SUPPORT_JOIN_PROBE") == "1"
	_write_audit("report.json", _report)
	_record("audit_complete", {"reason": reason})
	if is_instance_valid(_ui):
		_ui.queue_free()
	if is_instance_valid(_player):
		_player.queue_free()
	await process_frame
	quit(0 if reason == "observation_complete" else 1)
