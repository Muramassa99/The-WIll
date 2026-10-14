extends "res://tools/grip_plane_proof/verify_surface_grip_save_playback.gd"

## Real Skill Crafter controls and a saved weapon, with acquisition deliberately
## cancelled before it starts. No Save, bake, finger closure or visual-grip claim.
## Inherits the existing workspace isolation, source hash and report lifecycle.
const EndBoundsResolver = preload("res://core/resolvers/primary_grip_seat_resolver.gd")
const ProfileData = preload("res://core/models/baked_profile.gd")
const RuntimeClipData = preload("res://core/models/combat_runtime_clip.gd")
const EXPECTED_HAND_SPAN := 0.078771524


func _run() -> void:
	_prefix = "C:/WORKSPACE/test_artifacts/handle_end_bounds_ui_" + Time.get_datetime_string_from_system().replace(":", "-")
	_report = {"scope": "real_skill_crafter_handle_end_controls_without_closure", "visual_grip_certified": false}
	_source = OS.get_environment("THE_WILL_GRIP_LIVE_LIBRARY").strip_edges()
	var expected := OS.get_environment("THE_WILL_DIAGNOSTIC_USER_ROOT").replace("\\", "/").simplify_path().to_lower()
	if not _check(_workspace(expected) and expected == OS.get_user_data_dir().replace("\\", "/").simplify_path().to_lower(), "incidental user writes are isolated inside workspace"):
		_finish(); return
	if not _check(_workspace(_source) and FileAccess.file_exists(_source), "input library is an existing workspace copy"):
		_finish(); return
	_source_hash = FileAccess.get_sha256(_source)
	_report.merge({"source_library": _source, "source_library_sha256": _source_hash, "output_prefix": _prefix})
	var input: Resource = ResourceLoader.load(_source, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	if not _check(input != null, "actual saved library loads"):
		_finish(); return
	var requested := OS.get_environment("THE_WILL_GRIP_LIVE_WEAPON_NAME").strip_edges()
	if requested.is_empty(): requested = "Stage 1 v2 Draft Copy"
	var chosen: Resource
	for wip: Resource in input.saved_wips:
		if wip.forge_project_name == requested: chosen = wip
	if not _check(chosen != null, "named saved weapon exists: " + requested):
		_finish(); return
	_report["weapon_name"] = requested
	_library_player = LibraryPlayer.new()
	_library_player.library = input.duplicate(true)
	_library_player.library.save_file_path = _prefix + "_unused_library.tres"
	root.add_child(_library_player)
	_ui = UIScene.instantiate()
	_ui.set_meta("verification_skip_persistence", true)
	root.add_child(_ui)
	await process_frame
	_ui.open_for(_library_player, "Isolated handle end-bound controls verification")
	_suppress_acquisition()
	if not _check(_ui.select_saved_wip(chosen.wip_id), "actual UI selects saved weapon"):
		_finish(); return
	_suppress_acquisition()
	_ui._on_skill_slot_selector_pressed(SKILL)
	var context := _suppress_acquisition()
	_ui.set_process(false)
	if not _check(not context.is_empty(), "actual preview actor and equipped weapon exist"):
		_finish(); return
	var actor: Node3D = context.actor
	_verify_live_measurements(actor)
	var motion: Resource = _ui._get_active_motion_node()
	if not _check(motion != null, "selected skill exposes an editable motion node"):
		_finish(); return
	# This copy is an in-memory fixture only. Existing weapon geometry is retained.
	motion.locked_for_authoring = false
	motion.generated_transition_node = false
	motion.primary_hand_slot = HAND
	motion.preferred_grip_style_mode = &"grip_normal"
	motion.two_hand_state = MotionData.TWO_HAND_STATE_ONE_HAND
	motion.grip_seat_coordinate_schema_version = MotionData.GRIP_SEAT_COORDINATE_SCHEMA_NORMALIZED_HANDLE
	motion.grip_seat_slide_offset = 0.5
	motion.secondary_grip_seat_slide_offset = 0.5
	motion.axial_reposition_offset = 0.0
	_ui.preview_presenter.configure_preview_hand_setup(HAND, false)
	var primary: Dictionary = _ui.preview_presenter.get_preview_hand_end_bounds(_ui.preview_subviewport, false)
	var support: Dictionary = _ui.preview_presenter.get_preview_hand_end_bounds(_ui.preview_subviewport, true)
	_report["primary_end_bounds"] = primary
	_report["support_end_bounds"] = support
	if not _check(primary.get("valid", false) and support.get("valid", false), "both actual hand footprints fit the saved handle"):
		_finish(); return
	var profile: Resource = _ui._get_active_baked_profile()
	if not _check(profile != null, "actual UI exposes the selected baked profile"):
		_finish(); return
	for mode: StringName in [ProfileData.PRIMARY_GRIP_HANDLE_COORDINATE_MODE_DIRECTIONAL_POMMEL_TO_TIP,
		ProfileData.PRIMARY_GRIP_HANDLE_COORDINATE_MODE_BALANCED_SIGNED]:
		profile.primary_grip_handle_coordinate_mode = mode
		_verify_raw_field_visibility(motion, mode)
		motion.grip_seat_slide_offset = 0.5
		motion.secondary_grip_seat_slide_offset = 0.5
		motion.axial_reposition_offset = 0.0
		_ui._refresh_editor_fields()
		for endpoint: float in [0.0, 1.0]:
			var expected_primary := float(primary.min_ratio) if endpoint == 0.0 else float(primary.max_ratio)
			var expected_support := float(support.min_ratio) if endpoint == 0.0 else float(support.max_ratio)
			var display: float = EndBoundsResolver.handle_coordinate_to_display_value(endpoint, mode)
			var request: float = EndBoundsResolver.display_value_to_handle_coordinate(display, mode)
			_check(_ui.set_selected_motion_node_grip_seat_slide(request, false, false, false, false, false), "actual primary setter accepts a bounded endpoint edit")
			_close(float(motion.grip_seat_slide_offset), expected_primary, "primary edit stores accepted physical boundary in " + str(mode))
			_check(_ui.set_selected_motion_node_secondary_grip_seat_slide(request, false, false, false, false, false), "actual support setter accepts a bounded endpoint edit")
			_close(float(motion.secondary_grip_seat_slide_offset), expected_support, "support edit stores accepted physical boundary in " + str(mode))
			_verify_resolved_station(context.weapon, motion, primary)
		motion.grip_seat_slide_offset = 0.5
		motion.axial_reposition_offset = 0.0
		for axial: float in [-1.0, 1.0]:
			_check(_ui.set_selected_motion_node_axial_reposition(axial, false, false, false, false, false), "actual axial setter accepts bounded travel")
			var station: float = motion.grip_seat_slide_offset + 0.5 * motion.axial_reposition_offset
			_close(station, float(primary.min_ratio) if axial < 0.0 else float(primary.max_ratio), "combined primary and axial edit stays at the intended physical boundary")
			_verify_resolved_station(context.weapon, motion, primary)
		motion.axial_reposition_offset = 0.0
		motion.grip_seat_slide_offset = 0.5
		_ui._refresh_editor_fields()
		_close(_ui.grip_seat_slide_spin_box.value, 0.0 if mode == ProfileData.PRIMARY_GRIP_HANDLE_COORDINATE_MODE_BALANCED_SIGNED else 0.5,
			"actual midpoint field uses the selected display convention")
	_suppress_acquisition()
	_verify_runtime_clip_end_gate(context.weapon, motion)
	_report["motion_after_edits"] = {"primary": motion.grip_seat_slide_offset,
		"support": motion.secondary_grip_seat_slide_offset, "axial": motion.axial_reposition_offset}
	_check(not FileAccess.file_exists(_prefix + "_unused_library.tres"), "diagnostic never saved the weapon library")
	_finish()


func _suppress_acquisition() -> Dictionary:
	var context: Dictionary = _ui.preview_presenter._weapon_roll_context(_ui.preview_subviewport)
	if context.is_empty(): return context
	var owner: Node = context.actor.get_node_or_null("PreparedGripAcquisition")
	if owner != null:
		_check(not bool(owner._busy), "prepared skin acquisition has not started")
		owner.set_process(false)
		owner.clear()
	return context


func _verify_live_measurements(actor: Node3D) -> void:
	var spans: Dictionary = actor.get_hand_grip_spans_meters()
	_report["actual_hand_spans_meters"] = spans.duplicate()
	for slot: StringName in [&"hand_right", &"hand_left"]:
		_check(absf(float(spans.get(slot, 0.0)) - EXPECTED_HAND_SPAN) <= 0.00005,
			"actual " + str(slot) + " span agrees with the prepared model within 0.05 mm")
	var repeat: Dictionary = actor.get_hand_grip_spans_meters()
	_check(repeat == spans, "unchanged model returns stable cached measurements")
	repeat[HAND] = 0.0
	_check(float(actor.get_hand_grip_spans_meters().get(HAND, 0.0)) > 0.0,
		"callers cannot mutate cached measurements through the returned dictionary")
	var original: Transform3D = actor.transform
	actor.scale *= 1.25
	var enlarged: Dictionary = actor.get_hand_grip_spans_meters()
	for slot: StringName in [&"hand_right", &"hand_left"]:
		_close(float(enlarged.get(slot, 0.0)), float(spans.get(slot, 0.0)) * 1.25,
			"model scale change invalidates cached " + str(slot) + " length")
	actor.transform = original
	var restored: Dictionary = actor.get_hand_grip_spans_meters()
	for slot: StringName in [&"hand_right", &"hand_left"]:
		_close(float(restored.get(slot, 0.0)), float(spans.get(slot, 0.0)), "restoring scale restores measured hand span")


func _verify_raw_field_visibility(motion: Resource, mode: StringName) -> void:
	for high: bool in [false, true]:
		motion.grip_seat_slide_offset = 1.0 if high else 0.0
		motion.secondary_grip_seat_slide_offset = 0.0 if high else 1.0
		motion.axial_reposition_offset = 1.0 if high else -1.0
		var primary_before: float = motion.grip_seat_slide_offset
		var support_before: float = motion.secondary_grip_seat_slide_offset
		var axial_before: float = motion.axial_reposition_offset
		_ui._refresh_editor_fields()
		_close(float(motion.grip_seat_slide_offset), primary_before, "field refresh preserves old authored primary coordinate")
		_close(float(motion.secondary_grip_seat_slide_offset), support_before, "field refresh preserves old authored support coordinate")
		_close(float(motion.axial_reposition_offset), axial_before, "field refresh preserves old authored axial adjustment")
		_close(_ui.grip_seat_slide_spin_box.value, EndBoundsResolver.handle_coordinate_to_display_value(primary_before, mode), "out-of-bounds primary value remains visible for correction")
		_close(_ui.secondary_grip_seat_slide_spin_box.value, EndBoundsResolver.handle_coordinate_to_display_value(support_before, mode), "out-of-bounds support value remains visible for correction")
		_close(_ui.axial_reposition_spin_box.value, axial_before, "out-of-bounds axial value remains visible for correction")


func _verify_resolved_station(held_item: Node3D, motion: Resource, bounds: Dictionary) -> void:
	var station: float = motion.grip_seat_slide_offset + 0.5 * motion.axial_reposition_offset
	_check(station >= float(bounds.min_ratio) - 0.000001 and station <= float(bounds.max_ratio) + 0.000001,
		"stored component combination stays inside the end bounds")
	var actual: Dictionary = _ui.preview_presenter._resolve_primary_grip_seat_state_from_offsets(
		held_item, motion.grip_seat_slide_offset, motion.axial_reposition_offset)
	_check(actual.get("valid", false), "accepted UI edit resolves to an actual handle-path station")
	var axis_ratio: float = EndBoundsResolver.resolve_handle_coordinate_axis_ratio(station,
		float(held_item.get_meta("primary_grip_handle_tip_side_axis_ratio_from_span_start", 1.0)))
	_close(float(actual.get("ratio", -1.0)), axis_ratio, "rendered seat uses the same physical station stored by the controls")


func _verify_runtime_clip_end_gate(held_item: Node3D, motion: Resource) -> void:
	var span_start: Vector3 = held_item.get_meta("primary_grip_span_start_local")
	var span_end: Vector3 = held_item.get_meta("primary_grip_span_end_local")
	var midpoint := span_start.lerp(span_end, 0.5)
	var clip := RuntimeClipData.new()
	clip.baked_frame_times = PackedFloat32Array([0.0, 0.1])
	clip.baked_solved_replay_frame_available = [true, true]
	clip.baked_solved_anchor_node_paths.assign([&"PrimaryGripAnchor"])
	clip.baked_solved_anchor_positions_weapon_local = [PackedVector3Array([midpoint]), [midpoint]]
	clip.baked_two_hand_states = [MotionData.TWO_HAND_STATE_ONE_HAND, MotionData.TWO_HAND_STATE_ONE_HAND]
	clip.baked_primary_hand_slots = [HAND, HAND]
	var original := [motion.grip_seat_slide_offset, motion.secondary_grip_seat_slide_offset, motion.axial_reposition_offset]
	_check(_ui._runtime_clip_respects_handle_ends(clip), "cache end-bound gate accepts every available in-range frame")
	clip.baked_solved_anchor_positions_weapon_local[1] = [span_start]
	_check(not _ui._runtime_clip_respects_handle_ends(clip), "one later saved frame outside the endpoint limits rejects cache reuse")
	_check(clip.baked_solved_anchor_positions_weapon_local[1][0] == span_start,
		"cache validation rejects old solved anchors without silently moving them")
	_check(original == [motion.grip_seat_slide_offset, motion.secondary_grip_seat_slide_offset, motion.axial_reposition_offset],
		"rejecting an old solved clip does not change authored grip controls")


func _close(actual: float, expected: float, label: String) -> void:
	_check(is_finite(actual) and absf(actual - expected) <= 0.000001,
		"%s (actual %.9f, expected %.9f)" % [label, actual, expected])
