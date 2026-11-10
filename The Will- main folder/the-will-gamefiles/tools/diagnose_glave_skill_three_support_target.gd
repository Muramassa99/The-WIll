extends "res://tools/diagnose_glave_skill_two_observation.gd"

## Observation only: real Skill 3, no Save/F, one numeric UI edit on node 2.
const TARGET_SKILL := &"skill_slot_3"

func _find_skill(wip: Resource) -> Resource:
	for draft: Resource in wip.get("combat_animation_station_state").get("skill_drafts"):
		if draft != null and StringName(draft.get("legal_slot_id")) == TARGET_SKILL:
			return draft
	return null

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
	_report = {"scope": "Glave Skill 3 node 1/2 comparison and disengaged support target UI edit only; no Save/F",
		"slot": TARGET_SKILL, "source_sha256_before": _source_hash, "backup_error": copied}
	if copied != OK:
		await _complete("backup_failed")
		return
	_audit_library = ResourceLoader.load(SOURCE_LIBRARY, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	for item: Resource in _audit_library.call("get_saved_wips"):
		if String(item.get("forge_project_name")) == TARGET_NAME:
			_selected_wip = item
	var original := _find_skill(_selected_wip) if _selected_wip != null else null
	if original == null or original.call("get_action_motion_node_chain").size() < 2:
		await _complete("skill_or_nodes_missing")
		return
	ResourceSaver.save(original.duplicate(true), _directory.path_join("skill_before.tres"))
	_write_audit("saved_nodes_before.json", _nodes(original))
	_report["saved_node_1_2"] = _compare_source_nodes(original)
	_player = FakePlayer.new()
	_player.set("forge_wip_library_state", _audit_library)
	root.add_child(_player)
	_ui = (load(UI_SCENE) as PackedScene).instantiate()
	root.add_child(_ui)
	await process_frame
	root.gui_disable_input = true
	_ui.set_process_input(false)
	_ui.set_process_unhandled_input(false)
	_ui.set_meta("verification_skip_persistence", true)
	_ui.call("open_for", _player, "Glave Skill 3 support target audit")
	var opened: bool = _ui.call("select_saved_wip", _selected_wip.get("wip_id"), true)
	var selected: bool = _ui.call("select_skill_slot", TARGET_SKILL, true)
	if not opened or not selected:
		await _complete("opening_failed")
		return
	await _settle("opened")
	var first: int = _ui.call("_get_user_visible_motion_node_start_index", _draft())
	for index: int in [first, first + 1]:
		_ui.call("select_motion_node", index)
		await _settle("node_%02d" % index)
		_write_audit("node_%02d_measure.json" % index, _measure("node_%02d" % index))
		await _snapshot("node_%02d_before" % index)
	var motion: Resource = _ui.call("_get_active_motion_node")
	var control: SpinBox = _ui.get("secondary_grip_seat_slide_spin_box")
	var before := _measure("before_support_target_edit")
	_write_audit("nodes_before_edit.json", _nodes(_draft()))
	_report["edit"] = {"selected_node_index": first + 1, "two_hand_state_before": motion.get("two_hand_state"),
		"display_before": control.value, "normalized_before": motion.get("secondary_grip_seat_slide_offset"),
		"display_requested": 0.2, "method": "SpinBox LineEdit text then apply (Enter equivalent)"}
	_record("before_support_target_edit")
	control.get_line_edit().text = "0.2"
	control.apply()
	var immediate := _measure("immediate_after_support_target_edit")
	await _settle("support_target_edit")
	var settled := _measure("settled_after_support_target_edit")
	_report.edit["display_after"] = control.value
	_report.edit["normalized_after"] = motion.get("secondary_grip_seat_slide_offset")
	_report.edit["two_hand_state_after"] = motion.get("two_hand_state")
	_write_audit("support_target_probe.json", {"before": before, "immediate": immediate, "settled": settled})
	_write_audit("nodes_after_edit.json", _nodes(_draft()))
	await _snapshot("node_02_after_target_edit")
	await _complete("observation_complete")

func _compare_source_nodes(draft: Resource) -> Dictionary:
	var nodes: Array = draft.call("get_action_motion_node_chain")
	var fields := _fields(draft)
	var differences := {}
	for field: String in fields[0]:
		if fields[0][field] != fields[1].get(field):
			differences[field] = {"node1": fields[0][field], "node2": fields[1].get(field)}
	var result := {"authored_differences": differences,
		"tip_distance_reference_units": (nodes[0].tip_position_local as Vector3).distance_to(nodes[1].tip_position_local),
		"pommel_distance_reference_units": (nodes[0].pommel_position_local as Vector3).distance_to(nodes[1].pommel_position_local),
		"prepared_bone_differences": []}
	var a: Dictionary = nodes[0].prepared_pose
	var b: Dictionary = nodes[1].prepared_pose
	if a.get("bone_names", []) == b.get("bone_names", []) and a.has("bone_names"):
		for index: int in a.bone_names.size():
			var distance: float = (a.pose_positions[index] as Vector3).distance_to(b.pose_positions[index])
			var qa: Vector4 = a.pose_rotations[index]
			var qb: Vector4 = b.pose_rotations[index]
			# Identical stored XYZW must not appear different because float32
			# quaternion normalization/dot produces a small acos residual.
			var angle: float = 0.0 if qa == qb else rad_to_deg(Quaternion(qa.x, qa.y, qa.z, qa.w).normalized().angle_to(Quaternion(qb.x, qb.y, qb.z, qb.w).normalized()))
			if distance > 0.000001 or angle > 0.001:
				result.prepared_bone_differences.append({"bone": a.bone_names[index], "local_distance": distance, "local_angle_degrees": angle})
	else:
		result["prepared_comparison_unavailable"] = true
	return result

func _measure(label: String) -> Dictionary:
	var result := super._measure(label)
	var viewport: SubViewport = _ui.get("preview_subviewport")
	var preview: Node3D = viewport.get_node("CombatAnimationPreviewRoot3D")
	var actor: Node3D = preview.get_node("PreviewActorPivot/PreviewActor")
	result["upper_body_authoring_state"] = (actor.get("upper_body_authoring_state") as Dictionary).duplicate(true)
	return result

func _complete(reason: String) -> void:
	if _finished_audit:
		return
	_finished_audit = true
	_report["reason"] = reason
	_report["unsaved_edit_only"] = true
	if is_instance_valid(_ui):
		_ui.queue_free()
	if is_instance_valid(_player):
		_player.queue_free()
	await process_frame
	await process_frame
	_report["source_sha256_after"] = FileAccess.get_sha256(_source_path)
	_write_audit("report.json", _report)
	_record("audit_complete", {"reason": reason})
	quit(0 if reason == "observation_complete" else 1)
