extends "res://tools/diagnose_skill3_curve_roll.gd"

## Real saved Skill3, isolated library, real captured-input path. Curve editing
## must change path controls without silently reposing the stored checkpoint.
## No Reset/Save or Body Support override. Parent runner supplies the source.
const POSITION_TOLERANCE_METERS := 0.00005
const ROTATION_TOLERANCE_DEGREES := 0.025
const CURVE_PROPERTIES := [&"tip_curve_in_handle", &"tip_curve_out_handle",
	&"pommel_curve_in_handle", &"pommel_curve_out_handle"]

var curve_watch: Dictionary = {}
var release_watch: Dictionary = {}
var curve_checks: Array = []
var initial_clip_tip := PackedVector3Array()
var initial_clip_pommel := PackedVector3Array()
var initial_runtime_signature := ""
var body_support_before: Array = []

func _reopen_write(ui: CombatAnimationStationUI, side: String) -> void:
	# Camera framing only; keep both the endpoint and its curve cubes onscreen.
	if not options.has("zoom-out"):
		options["zoom-out"] = "6"
	await super._reopen_write(ui, side)
	if circle_actor == null or circle_weapon == null:
		return
	var draft: CombatAnimationDraft = ui.call("_get_active_draft")
	var actions := draft.get_action_motion_node_chain()
	if actions.size() != 3:
		return
	var index: int = draft.motion_node_chain.find(actions[1])
	_check_allocation(ui.select_motion_node(index), "curve_coverage_selected_node2")
	await _await_allocation_recording(ui)
	await _reopen_await_bound(ui, side)
	for spec: Array in [["node2_tip_out", &"tip", &"tip_curve_out"],
		["node2_pommel_in", &"pommel", &"pommel_curve_in"]]:
		_set_curve_focus(spec[1])
		await _wait_frames(2)
		var marker: Variant = ui.preview_presenter.get_authoring_marker_screen_position(ui.preview_subviewport, circle_camera, spec[2])
		if not marker is Vector2:
			allocation_report[String(spec[0]) + "_unavailable"] = "No visible existing curve marker; no geometry fabricated."
			continue
		allocation_report.gestures.append(await _circle(spec[0], spec[2], 1.0))
	# Numeric editing shares the same path-only responsibility for all4 handles.
	for spec: Array in [[&"tip_curve_in_handle", "set_selected_motion_node_tip_curve_in"],
		[&"tip_curve_out_handle", "set_selected_motion_node_tip_curve_out"],
		[&"pommel_curve_in_handle", "set_selected_motion_node_pommel_curve_in"],
		[&"pommel_curve_out_handle", "set_selected_motion_node_pommel_curve_out"]]:
		var node: CombatAnimationMotionNode = ui.call("_get_active_motion_node")
		var original: Vector3 = node.get(spec[0])
		_start_curve_watch("numeric_" + String(spec[0]), spec[0])
		ui.call(spec[1], original + Vector3(0.007, -0.003, 0.002))
		_sample("numeric_curve_updated")
		await _wait_frames(2)
		_sample("numeric_curve_settled")
		_finish_curve_watch(true)
		ui.call(spec[1], original)
		await _wait_frames(2)
	allocation_report["curve_pose_checks"] = curve_checks
	var body_support_after: Array = _body_support_values()
	allocation_report["body_support_before"] = body_support_before
	allocation_report["body_support_after"] = body_support_after
	_check_allocation(not body_support_before.is_empty() and body_support_before == body_support_after,
		"saved_body_support_values_unchanged", {"before": body_support_before, "after": body_support_after})
	allocation_report["snapshots"] = snapshots
	allocation_report["trace_rows"] = trace_rows.size()
	var log := FileAccess.open(output_dir.path_join("bone_trace.jsonl"), FileAccess.WRITE)
	for row in trace_rows:
		log.store_line(JSON.stringify(row))
	log.close()

func _circle(label: String, target: StringName, direction: float) -> Dictionary:
	var is_curve: bool = String(target).contains("curve")
	if label == "blue_in_1":
		var draft: CombatAnimationDraft = circle_ui.call("_get_active_draft")
		initial_runtime_signature = draft.runtime_cache_signature
		var clip: CombatRuntimeClip = draft.baked_runtime_clip as CombatRuntimeClip
		if clip != null:
			initial_clip_tip = clip.baked_tip_positions_local.duplicate()
			initial_clip_pommel = clip.baked_pommel_positions_local.duplicate()
	if is_curve:
		_start_curve_watch(label, _curve_property(target))
		# The parent takes a screenshot before pressing. Observe that wait, but
		# baseline the gesture after it so asynchronous preparation is separate.
		curve_watch["awaiting_press"] = true
	elif target == &"tip":
		release_watch = {"label": label}
	var result: Dictionary = await super._circle(label, target, direction)
	if is_curve:
		_finish_curve_watch(bool(result.get("engaged", false)) and int(result.get("delivered_samples", 0)) > 0)
	elif target == &"tip":
		_check_tip_release(result)
		release_watch.clear()
	if label == "blue_in_2":
		await _verify_F_after_curves()
	return result

func _engine_button(local_position: Vector2, pressed: bool) -> void:
	if pressed and bool(curve_watch.get("awaiting_press", false)):
		var label: String = curve_watch.label
		var property: StringName = curve_watch.property
		_sample(label + "_before_input")
		var before_input: Dictionary = curve_watch.duplicate()
		for key: String in ["row", "pose_fields", "label", "property", "original_curve", "awaiting_press"]:
			before_input.erase(key)
		before_input["scope"] = "Before actual LMB press; separate from gesture neutrality."
		# No await occurs between this baseline and the real input below.
		_start_curve_watch(label, property)
		curve_watch["pre_input_capture"] = before_input
	if not pressed and not release_watch.is_empty():
		release_watch["target_before_release"] = String(circle_ui.motion_node_editor.get_drag_target())
		release_watch["saved_target_before_release"] = String(circle_ui.get("preview_drag_target"))
		release_watch["solver_pending"] = circle_ui.preview_drag_refresh_pending
		release_watch["captured_pending_px"] = (circle_ui.marker_drag_input.get("_pending_relative") as Vector2).length()
	super._engine_button(local_position, pressed)

func _sample(label: String, extra: Dictionary = {}) -> Dictionary:
	var row: Dictionary = super._sample(label, extra)
	if not curve_watch.is_empty():
		_accumulate_curve_watch(row)
	return row

func _snapshot(label: String) -> void:
	if label == "before_F":
		body_support_before = _body_support_values()
	super._snapshot(label)

func _node(node: CombatAnimationMotionNode) -> Dictionary:
	var result: Dictionary = super._node(node)
	if node != null:
		result["body_support_blend"] = node.body_support_blend
	return result

func _body_support_values() -> Array:
	var result: Array = []
	var draft: CombatAnimationDraft = circle_ui.call("_get_active_draft")
	for node: CombatAnimationMotionNode in draft.motion_node_chain:
		result.append({"id": String(node.node_id), "value": node.body_support_blend})
	return result

func _start_curve_watch(label: String, property: StringName) -> void:
	var node: CombatAnimationMotionNode = circle_ui.call("_get_active_motion_node")
	var row: Dictionary = super._sample(label + "_neutrality_baseline")
	curve_watch = {"label": label, "property": property, "row": row,
		"pose_fields": _stored_pose_fields(node), "original_curve": node.get(property),
		"samples": 0, "position_error_m": 0.0, "rotation_error_deg": 0.0,
		"curve_change_m": 0.0, "stored_fields_equal": true}

func _accumulate_curve_watch(row: Dictionary) -> void:
	var baseline: Dictionary = curve_watch.row
	curve_watch.samples += 1
	for key: String in ["weapon_world", "skeleton_world"]:
		_accumulate_transform_error(baseline[key], row[key])
	for index: int in range((baseline.bones as Array).size()):
		for space: String in ["local", "world"]:
			_accumulate_transform_error(baseline.bones[index][space], row.bones[index][space])
	var node: CombatAnimationMotionNode = circle_ui.call("_get_active_motion_node")
	var current_fields: Dictionary = _stored_pose_fields(node)
	var fields_equal: bool = current_fields == curve_watch.pose_fields
	if not fields_equal and not curve_watch.has("first_stored_mismatch"):
		var differences := {}
		var keys: Array = current_fields.keys()
		for key: Variant in (curve_watch.pose_fields as Dictionary).keys():
			if not keys.has(key):
				keys.append(key)
		for key: Variant in keys:
			var before: Variant = curve_watch.pose_fields.get(key)
			var after: Variant = current_fields.get(key)
			if before == after:
				continue
			var difference := {"before": _brief_stored_value(before), "after": _brief_stored_value(after)}
			if before is Dictionary and after is Dictionary:
				var changed_keys: Array = []
				for nested_key: Variant in before.keys():
					if before.get(nested_key) != after.get(nested_key):
						changed_keys.append(String(nested_key))
				for nested_key: Variant in after.keys():
					if not before.has(nested_key):
						changed_keys.append(String(nested_key))
				difference["changed_dictionary_keys"] = changed_keys
			differences[String(key)] = difference
		curve_watch["first_stored_mismatch"] = {"phase": row.phase, "fields": differences}
	curve_watch.stored_fields_equal = bool(curve_watch.stored_fields_equal) and fields_equal
	var effective: CombatAnimationMotionNode = circle_ui.call("_get_effective_preview_motion_node")
	var value: Vector3 = effective.get(curve_watch.property)
	curve_watch.curve_change_m = maxf(float(curve_watch.curve_change_m), value.distance_to(curve_watch.original_curve))

func _brief_stored_value(value: Variant) -> Dictionary:
	var result := {"type": type_string(typeof(value))}
	if value is Dictionary or value is Array:
		result["size"] = value.size()
	elif value is Resource:
		result["class"] = value.get_class()
		result["instance_id"] = value.get_instance_id()
		result["path"] = value.resource_path
	else:
		result["value"] = str(value).left(180)
	return result

func _accumulate_transform_error(before: Dictionary, after: Dictionary) -> void:
	curve_watch.position_error_m = maxf(float(curve_watch.position_error_m), _array_vector(before.p).distance_to(_array_vector(after.p)))
	curve_watch.rotation_error_deg = maxf(float(curve_watch.rotation_error_deg), _quaternion_angle(before.q, after.q))

func _finish_curve_watch(input_delivered: bool) -> void:
	if curve_watch.is_empty():
		return
	var result: Dictionary = curve_watch.duplicate()
	result.erase("row")
	result.erase("pose_fields")
	result["input_delivered"] = input_delivered
	result["passed"] = input_delivered and int(result.samples) > 0 and bool(result.stored_fields_equal) \
		and float(result.position_error_m) <= POSITION_TOLERANCE_METERS \
		and float(result.rotation_error_deg) <= ROTATION_TOLERANCE_DEGREES \
		and float(result.curve_change_m) > POSITION_TOLERANCE_METERS
	curve_checks.append(result)
	_check_allocation(result.passed, String(result.label) + "_curve_changes_pose_stays", result)
	curve_watch.clear()

func _stored_pose_fields(node: CombatAnimationMotionNode) -> Dictionary:
	var result := {}
	# Prepared signature tracks the edited node, but the solved pose and all
	# non-curve stored inputs must remain exactly the same during curve editing.
	for property: Dictionary in node.get_property_list():
		var name: StringName = property.name
		if (int(property.usage) & PROPERTY_USAGE_STORAGE) == 0 or name in CURVE_PROPERTIES \
			or name in [&"script", &"prepared_pose_signature"]:
			continue
		var value: Variant = node.get(name)
		result[name] = value.duplicate(true) if value is Dictionary or value is Array else value
	return result

func _verify_F_after_curves() -> void:
	var draft: CombatAnimationDraft = circle_ui.call("_get_active_draft")
	var new_signature: String = circle_ui.call("_build_runtime_clip_cache_signature", draft)
	if new_signature == initial_runtime_signature:
		# An exactly closed circle can legitimately restore the original path.
		# A small explicit curve-only offset gives cache invalidation a real edit.
		var node: CombatAnimationMotionNode = circle_ui.call("_get_active_motion_node")
		_start_curve_watch("cache_invalidation_offset", &"tip_curve_in_handle")
		circle_ui.set_selected_motion_node_tip_curve_in(node.tip_curve_in_handle + Vector3(0.008, 0, 0))
		_sample("cache_invalidation_offset_applied")
		_finish_curve_watch(true)
		new_signature = circle_ui.call("_build_runtime_clip_cache_signature", draft)
	_check_allocation(new_signature != initial_runtime_signature, "curve_edit_changes_runtime_signature")
	_check_allocation(draft.baked_runtime_clip == null and draft.runtime_cache_signature.is_empty(), "curve_edit_invalidates_runtime_cache")
	var started := Time.get_ticks_msec()
	var deadline := started + 30000
	circle_ui.call("_toggle_preview_playback")
	while not circle_ui.chain_player.is_playing() and Time.get_ticks_msec() < deadline:
		if not circle_ui.preview_prepare_in_progress and not circle_ui.is_motion_node_recording_pending():
			break
		await process_frame
	var played: bool = circle_ui.chain_player.is_playing()
	_check_allocation(played, "F_after_curve_started", {"preparation_ms": Time.get_ticks_msec() - started, "status": circle_ui.footer_status_label.text})
	var clip: CombatRuntimeClip = draft.baked_runtime_clip as CombatRuntimeClip
	if clip != null:
		var changed: bool = clip.baked_tip_positions_local != initial_clip_tip or clip.baked_pommel_positions_local != initial_clip_pommel
		_check_allocation(changed, "F_after_curve_contains_changed_path_samples", {"samples": clip.baked_frame_times.size()})
	else:
		_check_allocation(false, "F_after_curve_has_runtime_clip")
	while circle_ui.chain_player.is_playing() and Time.get_ticks_msec() < deadline:
		_sample("F_after_curve_playback")
		await process_frame
	_check_allocation(played and not circle_ui.chain_player.is_playing(), "F_after_curve_finished_naturally")
	if circle_ui.chain_player.is_playing():
		circle_ui.call("_toggle_preview_playback")
	await _wait_frames(3)

func _check_tip_release(result: Dictionary) -> void:
	var row: Dictionary = snapshots.get(String(result.label) + "_immediate_release", {})
	var allocation: Dictionary = row.get("allocator", {})
	var expected: Dictionary = allocation.get("accepted_weapon", {})
	var actual: Dictionary = row.get("weapon_world", {})
	var pending: bool = bool(release_watch.get("solver_pending", false)) or float(release_watch.get("captured_pending_px", 0.0)) > 0.0
	var delivered: bool = bool(result.get("engaged", false)) and int(result.get("delivered_samples", 0)) > 0
	var pose_matches: bool = false
	if allocation.get("accepted_weapon_origin_id") == "world" and not expected.is_empty() and not actual.is_empty():
		pose_matches = _array_vector(expected.p).distance_to(_array_vector(actual.p)) <= POSITION_TOLERANCE_METERS \
			and _quaternion_angle(expected.q, actual.q) <= ROTATION_TOLERANCE_DEGREES
	var details: Dictionary = release_watch.duplicate()
	details.merge({"delivered": delivered, "allocator_status": allocation.get("status"), "accepted_world_pose_matches": pose_matches,
		"final_status": result.get("final_status", ""), "release_ms": result.get("release_ms")})
	_check_allocation(delivered and pending and release_watch.get("target_before_release") == "tip" \
		and release_watch.get("saved_target_before_release") == "tip" and pose_matches \
		and not String(result.get("final_status", "")).contains("wrist_motion_range"),
		String(result.label) + "_pending_release_uses_tip_allocator", details)

func _set_curve_focus(focus: StringName) -> void:
	circle_ui.session_state.current_focus = focus
	circle_ui.preview_presenter.refresh_focus_visuals(circle_ui.preview_view_container, circle_ui.preview_subviewport,
		circle_ui.call("_get_active_draft"), circle_ui.get_selected_motion_node_index(), focus, circle_ui.call("_get_active_baked_profile"))

func _curve_property(target: StringName) -> StringName:
	return {&"tip_curve_in": &"tip_curve_in_handle", &"tip_curve_out": &"tip_curve_out_handle",
		&"pommel_curve_in": &"pommel_curve_in_handle", &"pommel_curve_out": &"pommel_curve_out_handle"}.get(target, StringName())

func _array_vector(value: Array) -> Vector3:
	return Vector3(value[0], value[1], value[2])

func _quaternion_angle(a: Array, b: Array) -> float:
	var qa := Quaternion(a[0], a[1], a[2], a[3]).normalized()
	var qb := Quaternion(b[0], b[1], b[2], b[3]).normalized()
	# acos(dot) magnifies float32 normalization error near identical rotations:
	# even q compared with itself can falsely report about 0.056 degrees.
	var relative := qa.inverse() * qb
	var vector_length := Vector3(relative.x, relative.y, relative.z).length()
	return rad_to_deg(2.0 * atan2(vector_length, absf(relative.w)))
