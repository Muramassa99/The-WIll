extends SceneTree

const PlayerForgeWipLibraryStateScript = preload("res://core/models/player_forge_wip_library_state.gd")
const CombatAnimationStationUIScene = preload("res://scenes/ui/combat_animation_station_ui.tscn")

const TARGET_PROJECT_NAME := "Test sword for animations"
const TARGET_SLOT_ID: StringName = &"skill_slot_1"
const DOMINANT_SLOT_ID: StringName = &"hand_right"
const RESULT_FILE_PATH := "C:/WORKSPACE/DEBUG-LOGS/skill_crafter_pommel_drag_profile_2026-05-03.log"
const TEMP_SAVE_FILE_PATH := "C:/WORKSPACE/test_artifacts/diagnose_skill_crafter_pommel_drag_profile_library.tres"
const DRAG_RADIUS_METERS := 0.07
const DRAG_CUBE_SIDE_METERS := 0.07
const DRAG_DURATION_SECONDS := 2.0
const DRAG_SAMPLE_RATE_HZ := 60.0
const PREVIEW_REFRESH_INTERVAL_SECONDS := 0.083
const PATH_CIRCLE_XY := "circle_xy"
const PATH_TRIANGLE_XY := "triangle_xy"
const PATH_CUBE_DIAGONALS := "cube_diagonals"

class FakePlayer:
	extends Node

	var ui_mode_enabled: bool = false
	var forge_wip_library_state: PlayerForgeWipLibraryState = null

	func get_forge_wip_library_state() -> PlayerForgeWipLibraryState:
		return forge_wip_library_state

	func set_ui_mode_enabled(enabled: bool) -> void:
		ui_mode_enabled = enabled

var lines: PackedStringArray = []

func _init() -> void:
	call_deferred("_run_diagnostic")

func _run_diagnostic() -> void:
	DirAccess.make_dir_recursive_absolute("C:/WORKSPACE/DEBUG-LOGS")
	DirAccess.make_dir_recursive_absolute("C:/WORKSPACE/test_artifacts")
	lines.append("diagnostic=skill_crafter_pommel_drag_profile")
	lines.append("target_project_name=%s" % TARGET_PROJECT_NAME)
	lines.append("target_slot_id=%s" % String(TARGET_SLOT_ID))
	lines.append("drag_radius_m=%.4f" % DRAG_RADIUS_METERS)
	lines.append("drag_cube_side_m=%.4f" % DRAG_CUBE_SIDE_METERS)
	lines.append("drag_duration_s=%.3f" % DRAG_DURATION_SECONDS)
	lines.append("drag_sample_rate_hz=%.1f" % DRAG_SAMPLE_RATE_HZ)
	lines.append("preview_refresh_interval_s=%.3f" % PREVIEW_REFRESH_INTERVAL_SECONDS)

	var source_library: PlayerForgeWipLibraryState = PlayerForgeWipLibraryStateScript.load_or_create()
	var source_wip: CraftedItemWIP = _find_saved_wip_by_project_name(source_library, TARGET_PROJECT_NAME)
	lines.append("source_library_loaded=%s" % str(source_library != null))
	lines.append("source_wip_found=%s" % str(source_wip != null))
	if source_wip == null:
		_write_results()
		quit()
		return
	lines.append("source_wip_id=%s" % String(source_wip.wip_id))
	lines.append("source_project_name=%s" % source_wip.forge_project_name)

	var temp_library: PlayerForgeWipLibraryState = PlayerForgeWipLibraryStateScript.new()
	temp_library.save_file_path = TEMP_SAVE_FILE_PATH
	temp_library.saved_wips.clear()
	var diagnostic_wip: CraftedItemWIP = source_wip.duplicate(true) as CraftedItemWIP
	diagnostic_wip.wip_id = StringName("%s_pommel_drag_profile" % String(source_wip.wip_id))
	diagnostic_wip.forge_project_name = "%s Pommel Drag Profile Diagnostic" % source_wip.forge_project_name
	diagnostic_wip.ensure_combat_animation_station_state()
	temp_library.saved_wips.append(diagnostic_wip)
	temp_library.selected_wip_id = diagnostic_wip.wip_id
	temp_library.persist()
	lines.append("diagnostic_wip_id=%s" % String(diagnostic_wip.wip_id))
	lines.append("diagnostic_save_path=%s" % TEMP_SAVE_FILE_PATH)

	var fake_player := FakePlayer.new()
	fake_player.forge_wip_library_state = temp_library
	root.add_child(fake_player)

	var ui: CombatAnimationStationUI = CombatAnimationStationUIScene.instantiate() as CombatAnimationStationUI
	root.add_child(ui)
	await process_frame
	ui.open_for(fake_player, "Skill Crafter Pommel Drag Profile")
	await _wait_frames(8)
	var open_ok: bool = ui.open_saved_wip_with_hand_setup(diagnostic_wip.wip_id, DOMINANT_SLOT_ID, false, false)
	await _wait_frames(8)
	var select_slot_ok: bool = ui.select_skill_slot(TARGET_SLOT_ID, true)
	await _wait_frames(6)
	_select_first_visible_skill_node(ui)
	await _wait_frames(6)
	lines.append("open_ok=%s" % str(open_ok))
	lines.append("select_skill_slot_1_ok=%s" % str(select_slot_ok))
	lines.append("active_draft_identifier=%s" % String(ui.get_active_draft_identifier()))
	lines.append("selected_motion_node_index=%d" % ui.get_selected_motion_node_index())
	lines.append("active_open_slot=%s" % String(ui.get_active_open_dominant_slot_id()))
	lines.append("active_open_two_hand=%s" % str(ui.is_active_open_two_hand()))

	await _run_drag_pass(ui, "circle_debug_off", false, PATH_CIRCLE_XY)
	await _wait_frames(12)
	await _run_drag_pass(ui, "triangle_debug_off", false, PATH_TRIANGLE_XY)
	await _wait_frames(12)
	await _run_drag_pass(ui, "cube_debug_off", false, PATH_CUBE_DIAGONALS)

	_write_results()
	quit()

func _run_drag_pass(ui: CombatAnimationStationUI, pass_label: String, debug_enabled: bool, path_kind: String) -> void:
	_set_debugger_view(ui, debug_enabled)
	await _wait_frames(3)
	var source_motion_node: CombatAnimationMotionNode = ui.call("_get_active_motion_node") as CombatAnimationMotionNode
	if source_motion_node == null:
		lines.append("pass_%s_skipped=missing_motion_node" % pass_label)
		return
	ui.call("_begin_preview_drag_override", source_motion_node)
	var drag_motion_node: CombatAnimationMotionNode = ui.preview_drag_override_node as CombatAnimationMotionNode
	if drag_motion_node == null:
		lines.append("pass_%s_skipped=missing_drag_override" % pass_label)
		return
	var base_pommel: Vector3 = drag_motion_node.pommel_position_local
	var base_tip: Vector3 = drag_motion_node.tip_position_local
	var sample_count: int = int(round(DRAG_DURATION_SECONDS * DRAG_SAMPLE_RATE_HZ))
	var pass_start_usec: int = Time.get_ticks_usec()
	var previous_sample_usec: int = pass_start_usec
	var last_refresh_usec: int = 0
	var refresh_count: int = 0
	var pass_samples: Array[Dictionary] = []
	lines.append("pass_%s_begin_debug_enabled=%s" % [pass_label, str(debug_enabled)])
	lines.append("pass_%s_path_kind=%s" % [pass_label, path_kind])
	lines.append("pass_%s_base_tip=%s" % [pass_label, str(base_tip)])
	lines.append("pass_%s_base_pommel=%s" % [pass_label, str(base_pommel)])
	var last_requested_pommel: Vector3 = base_pommel
	for sample_index: int in range(sample_count):
		var sample_start_usec: int = Time.get_ticks_usec()
		var requested_pommel: Vector3 = base_pommel + _resolve_path_offset(path_kind, sample_index, sample_count)
		last_requested_pommel = requested_pommel
		var row: Dictionary = {
			"sample": sample_index,
			"wall_ms": _elapsed_ms(previous_sample_usec, sample_start_usec),
		}
		var requested_pommel_world: Vector3 = _resolve_current_trajectory_world_position(ui, requested_pommel)
		var t0: int = Time.get_ticks_usec()
		var resolved_segment: Dictionary = ui.call(
			"_resolve_motion_node_segment_for_pommel_target",
			drag_motion_node,
			requested_pommel,
			false
		) as Dictionary
		var t1: int = Time.get_ticks_usec()
		var changed: bool = bool(ui.call("_apply_resolved_segment_to_motion_node", drag_motion_node, resolved_segment))
		var t2: int = Time.get_ticks_usec()
		if changed:
			drag_motion_node.normalize()
			ui.preview_drag_has_moved = true
		var t3: int = Time.get_ticks_usec()
		row["resolve_segment_ms"] = _elapsed_ms(t0, t1)
		row["apply_segment_ms"] = _elapsed_ms(t1, t2)
		row["normalize_ms"] = _elapsed_ms(t2, t3)
		row["changed"] = changed
		row["requested_pommel_local"] = requested_pommel
		row["requested_pommel_world"] = requested_pommel_world
		row["authored_pommel_local"] = drag_motion_node.pommel_position_local
		row["authored_pommel_error_meters"] = drag_motion_node.pommel_position_local.distance_to(requested_pommel)
		var refresh_due: bool = (
			last_refresh_usec <= 0
			or _elapsed_seconds(last_refresh_usec, Time.get_ticks_usec()) >= PREVIEW_REFRESH_INTERVAL_SECONDS
		)
		if refresh_due:
			refresh_count += 1
			last_refresh_usec = Time.get_ticks_usec()
			var refresh_profile: Dictionary = _profile_refresh_preview_scene(ui)
			for key in refresh_profile.keys():
				row[key] = refresh_profile.get(key)
			row["actual_pommel_error_meters"] = (row.get("actual_pommel_local", Vector3.INF) as Vector3).distance_to(requested_pommel)
			row["display_pommel_error_meters"] = (row.get("display_pommel_local", Vector3.INF) as Vector3).distance_to(requested_pommel)
			row["marker_pommel_error_meters"] = (row.get("marker_pommel_local", Vector3.INF) as Vector3).distance_to(requested_pommel)
			row["resolved_pommel_error_meters"] = (row.get("resolved_pommel_local", Vector3.INF) as Vector3).distance_to(requested_pommel)
			row["actual_pommel_world_error_meters"] = (row.get("actual_pommel_world", Vector3.INF) as Vector3).distance_to(requested_pommel_world)
			row["marker_pommel_world_error_meters"] = (row.get("marker_pommel_world", Vector3.INF) as Vector3).distance_to(requested_pommel_world)
		else:
			row["refresh_ran"] = false
		row["sample_total_ms"] = _elapsed_ms(sample_start_usec, Time.get_ticks_usec())
		pass_samples.append(row)
		previous_sample_usec = sample_start_usec
		var next_sample_usec: int = pass_start_usec + int(round(float(sample_index + 1) * 1000000.0 / DRAG_SAMPLE_RATE_HZ))
		var wait_seconds: float = maxf(float(next_sample_usec - Time.get_ticks_usec()) / 1000000.0, 0.0)
		if wait_seconds > 0.0:
			await create_timer(wait_seconds).timeout
		else:
			await process_frame
	var pass_end_usec: int = Time.get_ticks_usec()
	lines.append("pass_%s_elapsed_ms=%.3f" % [pass_label, _elapsed_ms(pass_start_usec, pass_end_usec)])
	lines.append("pass_%s_effective_fps=%.3f" % [pass_label, float(sample_count) / maxf(_elapsed_seconds(pass_start_usec, pass_end_usec), 0.001)])
	lines.append("pass_%s_requested_samples=%d" % [pass_label, sample_count])
	lines.append("pass_%s_refresh_count=%d" % [pass_label, refresh_count])
	var release_result: Dictionary = ui.call("_resolve_preview_drag_commit_motion_node", source_motion_node) as Dictionary
	var release_motion_node: CombatAnimationMotionNode = release_result.get("motion_node", drag_motion_node) as CombatAnimationMotionNode
	var release_validation_result: Dictionary = release_result.get("validation_result", {}) as Dictionary
	lines.append("pass_%s_release_legal=%s" % [pass_label, str(bool(release_result.get("legal", true)))])
	lines.append("pass_%s_release_reason=%s" % [pass_label, String(release_validation_result.get("reason", release_validation_result.get("stopped_reason", "")))])
	if release_motion_node != null:
		lines.append("pass_%s_release_pommel_error_m=%.5f" % [
			pass_label,
			release_motion_node.pommel_position_local.distance_to(last_requested_pommel),
		])
		lines.append("pass_%s_release_authored_to_preview_override_error_m=%.5f" % [
			pass_label,
			release_motion_node.pommel_position_local.distance_to(drag_motion_node.pommel_position_local),
		])
	_append_pass_summary(pass_label, pass_samples)
	_append_pass_samples(pass_label, pass_samples)
	ui.call("_clear_preview_drag_override")

func _profile_refresh_preview_scene(ui: CombatAnimationStationUI) -> Dictionary:
	var profile: Dictionary = {"refresh_ran": true}
	var total_start: int = Time.get_ticks_usec()
	var t0: int = total_start
	var baked_profile = ui.call("_get_active_baked_profile")
	var t1: int = Time.get_ticks_usec()
	var playback_state: Dictionary = ui.call("_build_preview_playback_state") as Dictionary
	if ui.preview_drag_override_node != null:
		playback_state["authoring_drag_active"] = true
		playback_state["authoring_drag_lightweight"] = false
		playback_state["authoring_drag_budgeted_visuals"] = true
		playback_state["authoring_drag_target"] = &"pommel"
	var t2: int = Time.get_ticks_usec()
	var presenter = ui.preview_presenter
	presenter.configure_preview_hand_setup(ui.call("_resolve_active_motion_node_primary_slot_id"), ui.active_preview_default_two_hand)
	var t3: int = Time.get_ticks_usec()
	var state: Dictionary = presenter.call("_ensure_preview_nodes", ui.preview_view_container, ui.preview_subviewport) as Dictionary
	var preview_root: Node3D = state.get("preview_root", null) as Node3D
	var trajectory_root: Node3D = state.get("trajectory_root", null) as Node3D
	presenter.call("_sync_preview_size", ui.preview_view_container, ui.preview_subviewport)
	var t4: int = Time.get_ticks_usec()
	var active_draft: Resource = ui.call("_get_active_draft") as Resource
	var selected_node_index: int = ui.get_selected_motion_node_index()
	var effective_chain: Array = presenter.call(
		"_build_effective_motion_node_chain",
		active_draft,
		selected_node_index,
		ui.preview_drag_override_node
	) as Array
	var selected_motion_node: CombatAnimationMotionNode = presenter.call(
		"_resolve_selected_motion_node",
		effective_chain,
		selected_node_index
	) as CombatAnimationMotionNode
	var visible_chain: Array = presenter.call("_build_visible_motion_node_chain", active_draft, effective_chain) as Array
	var visible_selected_index: int = int(presenter.call(
		"_resolve_visible_selected_motion_node_index",
		active_draft,
		selected_node_index,
		visible_chain.size()
	))
	var playback_motion_node: CombatAnimationMotionNode = presenter.call(
		"_build_effective_preview_motion_node",
		selected_motion_node,
		playback_state
	) as CombatAnimationMotionNode
	var t5: int = Time.get_ticks_usec()
	presenter.call("_refresh_actor_and_weapon", state, ui.active_wip, playback_motion_node)
	var t6: int = Time.get_ticks_usec()
	presenter.call("_prepare_trajectory_root_for_authoring", state)
	var t7: int = Time.get_ticks_usec()
	var open_mount_seed: Dictionary = {}
	if ui.active_wip != null and not bool(playback_state.get("active", false)):
		open_mount_seed = presenter.resolve_preview_hand_mounted_motion_seed(
			ui.preview_subviewport,
			{},
			ui.active_wip.wip_id
		)
	var use_open_mount_baseline: bool = bool(presenter.call(
		"_motion_node_matches_hand_mounted_seed",
		playback_motion_node,
		open_mount_seed
	))
	var t8: int = Time.get_ticks_usec()
	var resolved_playback_state: Dictionary = {}
	if use_open_mount_baseline:
		resolved_playback_state = presenter.call(
			"_apply_preview_open_mount_pose",
			state,
			playback_motion_node,
			playback_state,
			true
		) as Dictionary
	else:
		resolved_playback_state = presenter.call(
			"_apply_authored_weapon_pose",
			state,
			playback_motion_node,
			playback_state,
			true,
			1.0
		) as Dictionary
	var t9: int = Time.get_ticks_usec()
	var authoring_endpoint_legality: Dictionary = preview_root.get_meta("authoring_endpoint_legality_result", {}) as Dictionary
	var contact_coupling_metrics: Dictionary = preview_root.get_meta("contact_coupling_metrics", {}) as Dictionary
	var contact_clearance_metrics: Dictionary = preview_root.get_meta("contact_clearance_settle_metrics", {}) as Dictionary
	var final_anchor_metrics: Dictionary = preview_root.get_meta("final_anchor_reseat_metrics", {}) as Dictionary
	var debugger_view_enabled: bool = bool(presenter.call("_resolve_debugger_view_enabled", state, resolved_playback_state))
	var display_chain: Array = presenter.call(
		"_build_resolved_display_motion_node_chain",
		visible_chain,
		visible_selected_index,
		resolved_playback_state
	) as Array
	var t10: int = Time.get_ticks_usec()
	if bool(resolved_playback_state.get("authoring_drag_budgeted_visuals", false)):
		presenter.call(
			"_refresh_drag_budgeted_visuals",
			state,
			display_chain,
			visible_selected_index,
			ui.session_state.current_focus
		)
	else:
		presenter.call(
			"_refresh_trajectory_visuals",
			state,
			display_chain,
			visible_selected_index,
			ui.session_state.current_focus,
			resolved_playback_state,
			presenter.call("_build_speed_state_config", active_draft)
		)
		presenter.call(
			"_refresh_weapon_and_sphere_visuals",
			state,
			display_chain,
			visible_selected_index,
			ui.session_state.current_focus,
			baked_profile
		)
	var t11: int = Time.get_ticks_usec()
	if not bool(resolved_playback_state.get("authoring_drag_active", false)):
		presenter.call("_refresh_collision_debug_visuals", state)
	else:
		presenter.call("_apply_debugger_view_visibility", state, debugger_view_enabled)
	var t12: int = Time.get_ticks_usec()
	var marker_root: Node3D = state.get("marker_root", null) as Node3D
	var held_item: Node3D = null
	if preview_root != null:
		held_item = preview_root.get_meta("preview_held_item", null) as Node3D
	var actual_pommel_local: Vector3 = Vector3.INF
	if held_item != null and is_instance_valid(held_item) and trajectory_root != null:
		var local_pommel: Vector3 = held_item.get_meta("weapon_pommel_local", Vector3.ZERO) as Vector3
		actual_pommel_local = trajectory_root.to_local(held_item.to_global(local_pommel))
	var resolved_state: Dictionary = {}
	var display_pommel_local: Vector3 = Vector3.INF
	if preview_root != null:
		resolved_state = preview_root.get_meta("resolved_playback_state", {}) as Dictionary
		display_pommel_local = preview_root.get_meta("display_selected_pommel_position_local", Vector3.INF) as Vector3
	var marker_pommel_local: Vector3 = Vector3.INF
	if marker_root != null:
		var marker: Node3D = marker_root.get_node_or_null("DragPommelMarker") as Node3D
		if marker != null:
			marker_pommel_local = marker.position
	var actual_pommel_world: Vector3 = Vector3.INF
	if held_item != null and is_instance_valid(held_item):
		actual_pommel_world = held_item.to_global(held_item.get_meta("weapon_pommel_local", Vector3.ZERO) as Vector3)
	var marker_pommel_world: Vector3 = Vector3.INF
	if marker_pommel_local != Vector3.INF and trajectory_root != null:
		marker_pommel_world = trajectory_root.to_global(marker_pommel_local)
	profile["baked_profile_ms"] = _elapsed_ms(t0, t1)
	profile["playback_state_ms"] = _elapsed_ms(t1, t2)
	profile["configure_hand_ms"] = _elapsed_ms(t2, t3)
	profile["ensure_nodes_size_ms"] = _elapsed_ms(t3, t4)
	profile["build_chains_ms"] = _elapsed_ms(t4, t5)
	profile["refresh_actor_weapon_ms"] = _elapsed_ms(t5, t6)
	profile["prepare_trajectory_ms"] = _elapsed_ms(t6, t7)
	profile["open_mount_seed_ms"] = _elapsed_ms(t7, t8)
	profile["apply_pose_ms"] = _elapsed_ms(t8, t9)
	profile["endpoint_legal"] = bool(authoring_endpoint_legality.get("legal", true))
	profile["endpoint_deferred"] = bool(authoring_endpoint_legality.get("deferred", false))
	profile["endpoint_reason"] = String(authoring_endpoint_legality.get("reason", authoring_endpoint_legality.get("stopped_reason", "")))
	profile["endpoint_dominant_correction_meters"] = (authoring_endpoint_legality.get("dominant_correction_delta", Vector3.ZERO) as Vector3).length()
	profile["endpoint_support_correction_meters"] = (authoring_endpoint_legality.get("support_correction_delta", Vector3.ZERO) as Vector3).length()
	profile["endpoint_weapon_body_illegal"] = bool(authoring_endpoint_legality.get("weapon_body_illegal", false))
	profile["endpoint_weapon_body_region"] = String(authoring_endpoint_legality.get("weapon_body_region", ""))
	var endpoint_projection: Dictionary = authoring_endpoint_legality.get("projection", {}) as Dictionary
	profile["endpoint_path_illegal"] = bool(endpoint_projection.get("path_illegal", false))
	profile["endpoint_point_illegal"] = bool(endpoint_projection.get("point_illegal", false))
	profile["endpoint_front_bias_failed"] = bool(endpoint_projection.get("front_bias_failed", false))
	profile["endpoint_alternate_correction_disabled"] = bool(endpoint_projection.get("alternate_target_correction_disabled", false))
	profile["collision_pose_legal"] = bool(preview_root.get_meta("collision_pose_legal", true))
	profile["collision_pose_region"] = String(preview_root.get_meta("collision_pose_region", ""))
	profile["collision_pose_sample"] = String(preview_root.get_meta("collision_pose_sample", ""))
	profile["collision_pose_clearance_meters"] = float(preview_root.get_meta("collision_pose_clearance_meters", -1.0))
	profile["contact_coupling_reason"] = String(contact_coupling_metrics.get("stopped_reason", contact_coupling_metrics.get("reason", "")))
	profile["contact_clearance_reason"] = String(contact_clearance_metrics.get("stopped_reason", contact_clearance_metrics.get("reason", "")))
	profile["final_anchor_reason"] = String(final_anchor_metrics.get("stopped_reason", final_anchor_metrics.get("reason", "")))
	profile["pre_anchor_grip_error_meters"] = float(final_anchor_metrics.get("pre_anchor_grip_error_meters", -1.0))
	profile["post_anchor_separation_delta_meters"] = float(final_anchor_metrics.get("post_anchor_separation_delta_meters", -1.0))
	profile["weapon_tip_alignment_error_meters"] = float(preview_root.get_meta("weapon_tip_alignment_error_meters", -1.0))
	profile["weapon_pommel_alignment_error_meters"] = float(preview_root.get_meta("weapon_pommel_alignment_error_meters", -1.0))
	profile["actual_pommel_local"] = actual_pommel_local
	profile["actual_pommel_world"] = actual_pommel_world
	profile["resolved_pommel_local"] = resolved_state.get("pommel_position_local", Vector3.INF) as Vector3
	profile["display_pommel_local"] = display_pommel_local
	profile["marker_pommel_local"] = marker_pommel_local
	profile["marker_pommel_world"] = marker_pommel_world
	profile["display_chain_ms"] = _elapsed_ms(t9, t10)
	profile["visuals_ms"] = _elapsed_ms(t10, t11)
	profile["debug_collision_ms"] = _elapsed_ms(t11, t12)
	profile["refresh_total_ms"] = _elapsed_ms(total_start, t12)
	profile["use_open_mount_baseline"] = use_open_mount_baseline
	return profile

func _resolve_current_trajectory_world_position(ui: CombatAnimationStationUI, local_position: Vector3) -> Vector3:
	var preview_root: Node3D = null
	if ui.preview_subviewport != null:
		preview_root = ui.preview_subviewport.get_node_or_null("CombatAnimationPreviewRoot3D") as Node3D
	if preview_root == null:
		return Vector3.INF
	var trajectory_root: Node3D = preview_root.find_child("TrajectoryRoot", true, false) as Node3D
	if trajectory_root == null:
		return Vector3.INF
	return trajectory_root.to_global(local_position)

func _resolve_path_offset(path_kind: String, sample_index: int, sample_count: int) -> Vector3:
	var progress: float = float(sample_index) / maxf(float(sample_count), 1.0)
	match path_kind:
		PATH_TRIANGLE_XY:
			return _sample_polyline_loop(_build_triangle_points(), progress)
		PATH_CUBE_DIAGONALS:
			return _sample_polyline_loop(_build_cube_diagonal_points(), progress)
		_:
			var angle: float = TAU * progress
			return Vector3(cos(angle) * DRAG_RADIUS_METERS, sin(angle) * DRAG_RADIUS_METERS, 0.0)

func _build_triangle_points() -> Array[Vector3]:
	var radius: float = DRAG_CUBE_SIDE_METERS / sqrt(3.0)
	return [
		Vector3(cos(deg_to_rad(90.0)) * radius, sin(deg_to_rad(90.0)) * radius, 0.0),
		Vector3(cos(deg_to_rad(210.0)) * radius, sin(deg_to_rad(210.0)) * radius, 0.0),
		Vector3(cos(deg_to_rad(330.0)) * radius, sin(deg_to_rad(330.0)) * radius, 0.0),
	]

func _build_cube_diagonal_points() -> Array[Vector3]:
	var h: float = DRAG_CUBE_SIDE_METERS * 0.5
	return [
		Vector3(-h, -h, -h),
		Vector3(h, -h, -h),
		Vector3(h, h, -h),
		Vector3(-h, h, -h),
		Vector3(-h, -h, -h),
		Vector3(-h, -h, h),
		Vector3(h, -h, h),
		Vector3(h, h, h),
		Vector3(-h, h, h),
		Vector3(-h, -h, h),
		Vector3(h, h, -h),
		Vector3(-h, -h, -h),
		Vector3(h, h, h),
		Vector3(h, -h, -h),
		Vector3(-h, h, h),
		Vector3(-h, -h, -h),
	]

func _sample_polyline_loop(points: Array[Vector3], progress: float) -> Vector3:
	if points.is_empty():
		return Vector3.ZERO
	var segment_lengths: Array[float] = []
	var total_length: float = 0.0
	for point_index: int in range(points.size()):
		var from_point: Vector3 = points[point_index]
		var to_point: Vector3 = points[(point_index + 1) % points.size()]
		var length: float = from_point.distance_to(to_point)
		segment_lengths.append(length)
		total_length += length
	if total_length <= 0.000001:
		return points[0]
	var target_distance: float = fposmod(progress, 1.0) * total_length
	var accumulated: float = 0.0
	for point_index: int in range(points.size()):
		var segment_length: float = segment_lengths[point_index]
		if target_distance <= accumulated + segment_length or point_index == points.size() - 1:
			var ratio: float = 0.0 if segment_length <= 0.000001 else clampf((target_distance - accumulated) / segment_length, 0.0, 1.0)
			return points[point_index].lerp(points[(point_index + 1) % points.size()], ratio)
		accumulated += segment_length
	return points[0]

func _set_debugger_view(ui: CombatAnimationStationUI, enabled: bool) -> void:
	ui.debugger_view_enabled = enabled
	ui.call("_refresh_debugger_view_button")
	ui.preview_presenter.set_debugger_view_enabled(ui.preview_subviewport, enabled)

func _select_first_visible_skill_node(ui: CombatAnimationStationUI) -> void:
	var draft: CombatAnimationDraft = ui.call("_get_active_draft") as CombatAnimationDraft
	if draft == null:
		return
	var node_count: int = draft.motion_node_chain.size()
	if node_count <= 0:
		return
	ui.select_motion_node(1 if node_count > 1 else 0)

func _append_pass_summary(pass_label: String, samples: Array[Dictionary]) -> void:
	var refresh_rows: Array[Dictionary] = []
	var max_wall: Dictionary = {}
	var max_sample_total: Dictionary = {}
	var wall_over_33: int = 0
	var wall_over_50: int = 0
	var wall_over_100: int = 0
	for row in samples:
		if bool(row.get("refresh_ran", false)):
			refresh_rows.append(row)
		if max_wall.is_empty() or float(row.get("wall_ms", 0.0)) > float(max_wall.get("wall_ms", 0.0)):
			max_wall = row
		if max_sample_total.is_empty() or float(row.get("sample_total_ms", 0.0)) > float(max_sample_total.get("sample_total_ms", 0.0)):
			max_sample_total = row
		var wall_ms: float = float(row.get("wall_ms", 0.0))
		if wall_ms > 33.333:
			wall_over_33 += 1
		if wall_ms > 50.0:
			wall_over_50 += 1
		if wall_ms > 100.0:
			wall_over_100 += 1
	lines.append("pass_%s_wall_over_33ms=%d" % [pass_label, wall_over_33])
	lines.append("pass_%s_wall_over_50ms=%d" % [pass_label, wall_over_50])
	lines.append("pass_%s_wall_over_100ms=%d" % [pass_label, wall_over_100])
	lines.append("pass_%s_max_wall_sample=%s" % [pass_label, _summarize_row(max_wall)])
	lines.append("pass_%s_max_sample_total=%s" % [pass_label, _summarize_row(max_sample_total)])
	_append_stage_summary(pass_label, refresh_rows, "refresh_total_ms")
	_append_stage_summary(pass_label, refresh_rows, "apply_pose_ms")
	_append_stage_summary(pass_label, refresh_rows, "visuals_ms")
	_append_stage_summary(pass_label, refresh_rows, "debug_collision_ms")
	_append_stage_summary(pass_label, refresh_rows, "refresh_actor_weapon_ms")
	_append_stage_summary(pass_label, refresh_rows, "open_mount_seed_ms")
	_append_stage_summary(pass_label, refresh_rows, "build_chains_ms")
	_append_stage_summary(pass_label, samples, "authored_pommel_error_meters")
	_append_stage_summary(pass_label, refresh_rows, "actual_pommel_error_meters")
	_append_stage_summary(pass_label, refresh_rows, "display_pommel_error_meters")
	_append_stage_summary(pass_label, refresh_rows, "marker_pommel_error_meters")
	_append_stage_summary(pass_label, refresh_rows, "resolved_pommel_error_meters")
	_append_stage_summary(pass_label, refresh_rows, "actual_pommel_world_error_meters")
	_append_stage_summary(pass_label, refresh_rows, "marker_pommel_world_error_meters")

func _append_stage_summary(pass_label: String, rows: Array[Dictionary], key: String) -> void:
	if rows.is_empty():
		lines.append("pass_%s_%s_avg=0.000 max=0.000 sample=-1" % [pass_label, key])
		return
	var total: float = 0.0
	var max_value: float = -INF
	var max_sample: int = -1
	for row in rows:
		var value: float = float(row.get(key, 0.0))
		total += value
		if value > max_value:
			max_value = value
			max_sample = int(row.get("sample", -1))
	lines.append("pass_%s_%s_avg=%.3f max=%.3f sample=%d" % [
		pass_label,
		key,
		total / maxf(float(rows.size()), 1.0),
		max_value,
		max_sample,
	])

func _append_pass_samples(pass_label: String, samples: Array[Dictionary]) -> void:
	lines.append("pass_%s_samples_csv=sample,wall_ms,sample_total_ms,resolve_segment_ms,apply_segment_ms,normalize_ms,authored_pommel_error_meters,actual_pommel_error_meters,display_pommel_error_meters,marker_pommel_error_meters,resolved_pommel_error_meters,refresh_ran,refresh_total_ms,apply_pose_ms,visuals_ms,debug_collision_ms,refresh_actor_weapon_ms,open_mount_seed_ms,build_chains_ms,endpoint_legal,endpoint_dominant_correction_meters,endpoint_support_correction_meters,endpoint_path_illegal,endpoint_point_illegal,endpoint_front_bias_failed,endpoint_alternate_correction_disabled,endpoint_weapon_body_illegal,endpoint_weapon_body_region,collision_pose_legal,collision_pose_region,collision_pose_sample,contact_clearance_reason,final_anchor_reason,pre_anchor_grip_error_meters,post_anchor_separation_delta_meters,weapon_tip_alignment_error_meters,weapon_pommel_alignment_error_meters" % pass_label)
	for row in samples:
		lines.append("pass_%s_sample=%d,%.3f,%.3f,%.3f,%.3f,%.3f,%.5f,%.5f,%.5f,%.5f,%.5f,%s,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%s,%.5f,%.5f,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%.5f,%.5f,%.5f,%.5f" % [
			pass_label,
			int(row.get("sample", -1)),
			float(row.get("wall_ms", 0.0)),
			float(row.get("sample_total_ms", 0.0)),
			float(row.get("resolve_segment_ms", 0.0)),
			float(row.get("apply_segment_ms", 0.0)),
			float(row.get("normalize_ms", 0.0)),
			float(row.get("authored_pommel_error_meters", -1.0)),
			float(row.get("actual_pommel_error_meters", -1.0)),
			float(row.get("display_pommel_error_meters", -1.0)),
			float(row.get("marker_pommel_error_meters", -1.0)),
			float(row.get("resolved_pommel_error_meters", -1.0)),
			str(bool(row.get("refresh_ran", false))),
			float(row.get("refresh_total_ms", 0.0)),
			float(row.get("apply_pose_ms", 0.0)),
			float(row.get("visuals_ms", 0.0)),
			float(row.get("debug_collision_ms", 0.0)),
			float(row.get("refresh_actor_weapon_ms", 0.0)),
			float(row.get("open_mount_seed_ms", 0.0)),
			float(row.get("build_chains_ms", 0.0)),
			str(bool(row.get("endpoint_legal", true))),
			float(row.get("endpoint_dominant_correction_meters", 0.0)),
			float(row.get("endpoint_support_correction_meters", 0.0)),
			str(bool(row.get("endpoint_path_illegal", false))),
			str(bool(row.get("endpoint_point_illegal", false))),
			str(bool(row.get("endpoint_front_bias_failed", false))),
			str(bool(row.get("endpoint_alternate_correction_disabled", false))),
			str(bool(row.get("endpoint_weapon_body_illegal", false))),
			String(row.get("endpoint_weapon_body_region", "")).replace(",", ";"),
			str(bool(row.get("collision_pose_legal", true))),
			String(row.get("collision_pose_region", "")).replace(",", ";"),
			String(row.get("collision_pose_sample", "")).replace(",", ";"),
			String(row.get("contact_clearance_reason", "")).replace(",", ";"),
			String(row.get("final_anchor_reason", "")).replace(",", ";"),
			float(row.get("pre_anchor_grip_error_meters", -1.0)),
			float(row.get("post_anchor_separation_delta_meters", -1.0)),
			float(row.get("weapon_tip_alignment_error_meters", -1.0)),
			float(row.get("weapon_pommel_alignment_error_meters", -1.0)),
		])

func _summarize_row(row: Dictionary) -> String:
	if row.is_empty():
		return "{}"
	return "{sample=%d wall=%.3f total=%.3f refresh=%s refresh_total=%.3f pose=%.3f visuals=%.3f debug=%.3f actor_weapon=%.3f}" % [
		int(row.get("sample", -1)),
		float(row.get("wall_ms", 0.0)),
		float(row.get("sample_total_ms", 0.0)),
		str(bool(row.get("refresh_ran", false))),
		float(row.get("refresh_total_ms", 0.0)),
		float(row.get("apply_pose_ms", 0.0)),
		float(row.get("visuals_ms", 0.0)),
		float(row.get("debug_collision_ms", 0.0)),
		float(row.get("refresh_actor_weapon_ms", 0.0)),
	]

func _find_saved_wip_by_project_name(library_state: PlayerForgeWipLibraryState, project_name: String) -> CraftedItemWIP:
	if library_state == null:
		return null
	for saved_wip: CraftedItemWIP in library_state.get_saved_wips():
		if saved_wip == null:
			continue
		if saved_wip.forge_project_name == project_name:
			return saved_wip
	return null

func _elapsed_ms(start_usec: int, end_usec: int) -> float:
	return float(end_usec - start_usec) / 1000.0

func _elapsed_seconds(start_usec: int, end_usec: int) -> float:
	return float(end_usec - start_usec) / 1000000.0

func _wait_frames(frame_count: int) -> void:
	for _frame_index: int in range(maxi(frame_count, 0)):
		await process_frame

func _write_results() -> void:
	var file := FileAccess.open(RESULT_FILE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()
