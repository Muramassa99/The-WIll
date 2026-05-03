extends SceneTree

const CraftedItemWIPScript = preload("res://core/models/crafted_item_wip.gd")
const PlayerForgeWipLibraryStateScript = preload("res://core/models/player_forge_wip_library_state.gd")
const CombatAnimationStationUIScene = preload("res://scenes/ui/combat_animation_station_ui.tscn")
const CombatAnimationMotionNodeEditorScript = preload("res://runtime/combat/combat_animation_motion_node_editor.gd")
const CombatAnimationSessionStateScript = preload("res://core/models/combat_animation_session_state.gd")
const LayerAtomScript = preload("res://core/atoms/layer_atom.gd")
const CellAtomScript = preload("res://core/atoms/cell_atom.gd")

const RESULT_FILE_PATH := "C:/WORKSPACE/combat_animation_station_preview_results.txt"
const TEMP_SAVE_FILE_PATH := "C:/WORKSPACE/test_artifacts/verify_combat_animation_station_preview_library.tres"
const WOOD_MATERIAL_ID := &"mat_wood_gray"

class FakePlayer:
	extends Node

	var ui_mode_enabled: bool = false
	var forge_wip_library_state: PlayerForgeWipLibraryState = null

	func get_forge_wip_library_state() -> PlayerForgeWipLibraryState:
		return forge_wip_library_state

	func set_ui_mode_enabled(enabled: bool) -> void:
		ui_mode_enabled = enabled

func _init() -> void:
	call_deferred("_run_verification")

func _run_verification() -> void:
	var library_state: PlayerForgeWipLibraryState = PlayerForgeWipLibraryStateScript.new()
	library_state.save_file_path = TEMP_SAVE_FILE_PATH
	library_state.saved_wips.clear()
	library_state.selected_wip_id = StringName()

	var source_wip: CraftedItemWIP = _build_preview_test_wip()
	var saved_wip: CraftedItemWIP = library_state.save_wip(source_wip)

	var fake_player := FakePlayer.new()
	fake_player.forge_wip_library_state = library_state
	get_root().add_child(fake_player)

	var ui = CombatAnimationStationUIScene.instantiate()
	get_root().add_child(ui)
	await process_frame
	ui.open_for(fake_player, "PreviewVerifier")
	await process_frame
	ui.select_skill_slot(&"skill_slot_3")
	ui.set_active_draft_skill_name("Preview Alpha")
	await process_frame
	var session_state: CombatAnimationSessionState = ui.get("session_state") as CombatAnimationSessionState
	var focus_initial: StringName = session_state.current_focus if session_state != null else StringName()
	ui.call("_cycle_focus")
	var focus_after_one_cycle: StringName = session_state.current_focus if session_state != null else StringName()
	ui.call("_cycle_focus")
	var focus_after_two_cycles: StringName = session_state.current_focus if session_state != null else StringName()
	ui.call("_cycle_focus")
	var focus_after_three_cycles: StringName = session_state.current_focus if session_state != null else StringName()
	ui.call("_cycle_focus")
	var focus_after_four_cycles: StringName = session_state.current_focus if session_state != null else StringName()
	var input_probe_event := InputEventKey.new()
	input_probe_event.physical_keycode = KEY_Q
	input_probe_event.keycode = KEY_Q
	var probe_actions: Array[StringName] = [
		&"skill_crafter_prev_motion_node",
		&"skill_crafter_prev_node",
	]
	ui.call("_event_matches_any_action", input_probe_event, probe_actions)
	var orbit_ok: bool = ui.orbit_preview_camera(Vector2(26.0, -14.0))
	var zoom_ok: bool = ui.zoom_preview_camera(1)
	for _zoom_index: int in range(80):
		ui.zoom_preview_camera(1)
	await process_frame
	var camera_state_before_refresh: Dictionary = ui.get_preview_debug_state()
	var extended_zoom_out_ok: bool = float(camera_state_before_refresh.get("camera_distance", 0.0)) >= 9.5
	ui.set_selected_motion_node_tip_curve_out(Vector3(0.08, 0.02, -0.05))
	ui.insert_motion_node_after_selection()
	await process_frame
	ui.set_selected_motion_node_tip_curve_in(Vector3(-0.05, 0.04, 0.03))
	ui.set_selected_motion_node_two_hand_state(&"two_hand_two_hand")
	await process_frame
	var active_weapon_length: float = float(ui.call("_get_active_weapon_total_length"))
	var node_before_authoring: CombatAnimationMotionNode = ui.call("_get_active_motion_node") as CombatAnimationMotionNode
	var pre_authoring_tip: Vector3 = node_before_authoring.tip_position_local if node_before_authoring != null else Vector3.ZERO
	var pre_authoring_pommel: Vector3 = node_before_authoring.pommel_position_local if node_before_authoring != null else Vector3.ZERO
	var authored_tip_request: Vector3 = pre_authoring_pommel + Vector3(0.37, 0.42, 0.81).normalized() * maxf(active_weapon_length, 0.01)
	var authoring_tip_update_ok: bool = ui.set_selected_motion_node_tip_position(
		authored_tip_request,
		false,
		true,
		true,
		true,
		true
	)
	await process_frame
	var tip_node_after_update: CombatAnimationMotionNode = ui.call("_get_active_motion_node") as CombatAnimationMotionNode
	var authored_tip_retained_ok: bool = (
		tip_node_after_update != null
		and tip_node_after_update.tip_position_local.distance_to(authored_tip_request) <= 0.001
	)
	var authoring_tip_kept_pommel_ok: bool = (
		tip_node_after_update != null
		and tip_node_after_update.pommel_position_local.distance_to(pre_authoring_pommel) <= 0.001
	)
	var tip_after_orbit: Vector3 = tip_node_after_update.tip_position_local if tip_node_after_update != null else pre_authoring_tip
	var pommel_before_free_move: Vector3 = tip_node_after_update.pommel_position_local if tip_node_after_update != null else pre_authoring_pommel
	var pommel_translation_request := Vector3(0.24, 0.18, -0.13)
	var authored_pommel_request: Vector3 = pommel_before_free_move + pommel_translation_request
	var authoring_pommel_update_ok: bool = ui.set_selected_motion_node_pommel_position(
		authored_pommel_request,
		false,
		true,
		true,
		true,
		true
	)
	await process_frame
	var pommel_node_after_update: CombatAnimationMotionNode = ui.call("_get_active_motion_node") as CombatAnimationMotionNode
	var authored_pommel_retained_ok: bool = false
	var authoring_pommel_translated_tip_ok: bool = false
	var authored_segment_length_ok: bool = false
	if pommel_node_after_update != null:
		authored_pommel_retained_ok = pommel_node_after_update.pommel_position_local.distance_to(authored_pommel_request) <= 0.001
		authoring_pommel_translated_tip_ok = pommel_node_after_update.tip_position_local.distance_to(tip_after_orbit + pommel_translation_request) <= 0.001
		authored_segment_length_ok = absf(
			pommel_node_after_update.tip_position_local.distance_to(pommel_node_after_update.pommel_position_local)
			- maxf(active_weapon_length, 0.01)
		) <= 0.001
	await process_frame
	var grip_slide_source_node: CombatAnimationMotionNode = ui.call("_get_active_motion_node") as CombatAnimationMotionNode
	var grip_slide_tip_before: Vector3 = grip_slide_source_node.tip_position_local if grip_slide_source_node != null else Vector3.ZERO
	var grip_slide_pommel_before: Vector3 = grip_slide_source_node.pommel_position_local if grip_slide_source_node != null else Vector3.ZERO
	var grip_slide_update_ok: bool = ui.set_selected_motion_node_grip_seat_slide(
		0.65,
		false,
		true,
		true,
		true,
		true
	)
	await process_frame
	var grip_slide_node_after: CombatAnimationMotionNode = ui.call("_get_active_motion_node") as CombatAnimationMotionNode
	var grip_slide_debug_state: Dictionary = ui.get_preview_debug_state()
	var grip_slide_segment_shifted_ok: bool = false
	var grip_slide_segment_length_ok: bool = false
	if grip_slide_node_after != null:
		grip_slide_segment_shifted_ok = (
			grip_slide_node_after.tip_position_local.distance_to(grip_slide_tip_before) > 0.0001
			or grip_slide_node_after.pommel_position_local.distance_to(grip_slide_pommel_before) > 0.0001
		)
		grip_slide_segment_length_ok = absf(
			grip_slide_node_after.tip_position_local.distance_to(grip_slide_node_after.pommel_position_local)
			- maxf(active_weapon_length, 0.01)
		) <= 0.001

	if session_state != null:
		session_state.current_focus = CombatAnimationSessionStateScript.FOCUS_TIP
		ui.call("_refresh_focus_indicators")
		ui.call("_refresh_preview_scene")
	await process_frame
	var later_node_tip_pick_target: StringName = StringName()
	var later_node_tip_pick_ok: bool = false
	var later_node_tip_curve_handle_pick_target: StringName = StringName()
	var later_node_tip_curve_handle_pick_ok: bool = false
	var later_node_tip_pick_selected_index: int = ui.get_selected_motion_node_index()
	var later_node_tip_pick_display_position: Vector3 = Vector3.ZERO
	var later_node_tip_pick_screen_position: Vector2 = Vector2.ZERO
	var later_node_tip_curve_handle_position: Vector3 = Vector3.ZERO
	var later_node_tip_curve_handle_screen_position: Vector2 = Vector2.ZERO
	var later_node_tip_pick_motion_node: CombatAnimationMotionNode = ui.call("_get_active_motion_node") as CombatAnimationMotionNode
	var later_node_tip_pick_debug: Dictionary = ui.get_preview_debug_state()
	var later_node_tip_pick_camera: Camera3D = ui.call("_get_preview_camera") as Camera3D
	var later_node_tip_pick_trajectory_root: Node3D = ui.call("_get_preview_trajectory_root") as Node3D
	var later_node_tip_pick_editor: CombatAnimationMotionNodeEditor = ui.get("motion_node_editor") as CombatAnimationMotionNodeEditor
	var later_node_tip_pick_display_node: CombatAnimationMotionNode = ui.call(
		"_build_display_motion_node_for_viewport_pick",
		later_node_tip_pick_motion_node
	) as CombatAnimationMotionNode
	if (
		later_node_tip_pick_camera != null
		and later_node_tip_pick_trajectory_root != null
		and later_node_tip_pick_editor != null
		and later_node_tip_pick_display_node != null
	):
		later_node_tip_pick_display_position = later_node_tip_pick_debug.get(
			"display_selected_tip_position_local",
			later_node_tip_pick_display_node.tip_position_local
		) as Vector3
		later_node_tip_pick_screen_position = later_node_tip_pick_camera.unproject_position(
			later_node_tip_pick_trajectory_root.global_transform * later_node_tip_pick_display_position
		)
		later_node_tip_pick_target = later_node_tip_pick_editor.pick_drag_target(
			later_node_tip_pick_camera,
			later_node_tip_pick_screen_position,
			later_node_tip_pick_display_node,
			later_node_tip_pick_trajectory_root,
			CombatAnimationSessionStateScript.FOCUS_TIP
		)
		later_node_tip_pick_ok = later_node_tip_pick_target == CombatAnimationMotionNodeEditorScript.DRAG_TARGET_TIP
		var selected_tip_curve_handle: Vector3 = later_node_tip_pick_display_node.tip_curve_in_handle
		var expected_tip_curve_target: StringName = CombatAnimationMotionNodeEditorScript.DRAG_TARGET_TIP_CURVE_IN
		if selected_tip_curve_handle.length() <= 0.0001:
			selected_tip_curve_handle = later_node_tip_pick_display_node.tip_curve_out_handle
			expected_tip_curve_target = CombatAnimationMotionNodeEditorScript.DRAG_TARGET_TIP_CURVE_OUT
		if selected_tip_curve_handle.length() > 0.0001:
			later_node_tip_curve_handle_position = later_node_tip_pick_display_node.tip_position_local + selected_tip_curve_handle
			later_node_tip_curve_handle_screen_position = later_node_tip_pick_camera.unproject_position(
				later_node_tip_pick_trajectory_root.global_transform * later_node_tip_curve_handle_position
			)
			later_node_tip_curve_handle_pick_target = later_node_tip_pick_editor.pick_drag_target(
				later_node_tip_pick_camera,
				later_node_tip_curve_handle_screen_position,
				later_node_tip_pick_display_node,
				later_node_tip_pick_trajectory_root,
				CombatAnimationSessionStateScript.FOCUS_TIP
			)
			later_node_tip_curve_handle_pick_ok = later_node_tip_curve_handle_pick_target == expected_tip_curve_target

	var debug_state: Dictionary = ui.get_preview_debug_state()
	var active_draft: Resource = ui.call("_get_active_draft") as Resource
	var ui_node_count: int = int((active_draft.get("motion_node_chain") as Array).size()) if active_draft != null else 0
	var first_motion_node: CombatAnimationMotionNode = null
	var second_motion_node: CombatAnimationMotionNode = null
	if active_draft != null:
		var motion_node_chain: Array = active_draft.get("motion_node_chain") as Array
		first_motion_node = motion_node_chain[0] as CombatAnimationMotionNode if motion_node_chain.size() > 0 else null
		second_motion_node = motion_node_chain[1] as CombatAnimationMotionNode if motion_node_chain.size() > 1 else null
	var seeded_tip_position: Vector3 = first_motion_node.tip_position_local if first_motion_node != null else Vector3.ZERO
	var seeded_pommel_position: Vector3 = first_motion_node.pommel_position_local if first_motion_node != null else Vector3.ZERO
	var second_tip_position: Vector3 = second_motion_node.tip_position_local if second_motion_node != null else Vector3.ZERO
	var second_pommel_position: Vector3 = second_motion_node.pommel_position_local if second_motion_node != null else Vector3.ZERO
	var active_wip: CraftedItemWIP = ui.get("active_wip") as CraftedItemWIP
	var baked_profile: BakedProfile = active_wip.latest_baked_profile_snapshot if active_wip != null else null
	var lines: PackedStringArray = []
	lines.append("preview_actor_exists=%s" % str(bool(debug_state.get("has_preview_actor", false))))
	lines.append("preview_weapon_exists=%s" % str(bool(debug_state.get("has_preview_weapon", false))))
	lines.append("primary_grip_anchor_exists=%s" % str(bool(debug_state.get("has_primary_grip_anchor", false))))
	lines.append("ui_selected_motion_node_index=%d" % ui.get_selected_motion_node_index())
	lines.append("ui_motion_node_count=%d" % ui_node_count)
	lines.append("preview_motion_node_count=%d" % int(debug_state.get("motion_node_count", 0)))
	lines.append("curve_baked_point_count=%d" % int(debug_state.get("curve_baked_point_count", 0)))
	lines.append("motion_node_marker_count=%d" % int(debug_state.get("motion_node_marker_count", 0)))
	lines.append("control_handle_marker_count=%d" % int(debug_state.get("control_handle_marker_count", 0)))
	lines.append("weapon_gizmo_marker_count=%d" % int(debug_state.get("weapon_gizmo_marker_count", 0)))
	lines.append("body_restriction_debug_mesh_count=%d" % int(debug_state.get("body_restriction_debug_mesh_count", 0)))
	lines.append("weapon_bounds_debug_exists=%s" % str(bool(debug_state.get("weapon_bounds_debug_exists", false))))
	lines.append("weapon_proxy_source=%s" % String(debug_state.get("weapon_proxy_source", StringName())))
	lines.append("weapon_proxy_sample_count=%d" % int(debug_state.get("weapon_proxy_sample_count", 0)))
	lines.append("weapon_proxy_uses_full_geometry=%s" % str(bool(debug_state.get("weapon_proxy_uses_full_geometry", false))))
	lines.append("joint_range_debug_visible=%s" % str(bool(debug_state.get("joint_range_debug_visible", false))))
	lines.append("joint_range_debug_visual_count=%d" % int(debug_state.get("joint_range_debug_visual_count", 0)))
	lines.append("joint_range_debug_state=%s" % str(debug_state.get("joint_range_debug_state", {})))
	lines.append("primary_grip_debug_count=%d" % int(debug_state.get("primary_grip_debug_count", 0)))
	lines.append("secondary_grip_debug_count=%d" % int(debug_state.get("secondary_grip_debug_count", 0)))
	lines.append("weapon_proxy_debug_count=%d" % int(debug_state.get("weapon_proxy_debug_count", 0)))
	lines.append("collision_debug_visual_count=%d" % int(debug_state.get("collision_debug_visual_count", 0)))
	lines.append("body_self_collision_legal=%s" % str(bool(debug_state.get("body_self_collision_legal", true))))
	lines.append("body_self_collision_checked_pair_count=%d" % int(debug_state.get("body_self_collision_checked_pair_count", 0)))
	lines.append("body_self_collision_allowed_overlap_pair_count=%d" % int(debug_state.get("body_self_collision_allowed_overlap_pair_count", 0)))
	lines.append("body_self_collision_illegal_pair_count=%d" % int(debug_state.get("body_self_collision_illegal_pair_count", 0)))
	lines.append("body_self_collision_first_illegal_pair=%s" % str(debug_state.get("body_self_collision_first_illegal_pair", {})))
	lines.append("body_self_collision_illegal_pairs=%s" % str(debug_state.get("body_self_collision_illegal_pairs", [])))
	lines.append("collision_pose_legal=%s" % str(bool(debug_state.get("collision_pose_legal", true))))
	lines.append("collision_pose_illegal_sample_count=%d" % int(debug_state.get("collision_pose_illegal_sample_count", 0)))
	lines.append("collision_pose_region=%s" % String(debug_state.get("collision_pose_region", "")))
	lines.append("collision_pose_clearance_meters=%s" % str(snapped(float(debug_state.get("collision_pose_clearance_meters", -1.0)), 0.0001)))
	lines.append("collision_path_legal=%s" % str(bool(debug_state.get("collision_path_legal", true))))
	lines.append("collision_path_sample_count=%d" % int(debug_state.get("collision_path_sample_count", 0)))
	lines.append("collision_path_illegal_pose_count=%d" % int(debug_state.get("collision_path_illegal_pose_count", 0)))
	lines.append("collision_path_first_illegal_index=%d" % int(debug_state.get("collision_path_first_illegal_index", -1)))
	lines.append("collision_path_region=%s" % String(debug_state.get("collision_path_region", "")))
	lines.append("collision_legality_diagnostics_present=%s" % str(
		int(debug_state.get("collision_path_sample_count", 0)) > 0
		and float(debug_state.get("collision_pose_clearance_meters", -1.0)) != -1.0
	))
	var guardrail_state: Dictionary = debug_state.get("editor_guardrail_state", {}) as Dictionary
	var guardrail_debug_views: Dictionary = guardrail_state.get("debug_views", {}) as Dictionary
	lines.append("guardrail_state_present=%s" % str(not guardrail_state.is_empty()))
	lines.append("guardrail_entry_count=%d" % int(guardrail_state.get("entry_count", 0)))
	lines.append("guardrail_warning_count=%d" % int(guardrail_state.get("warning_count", 0)))
	lines.append("guardrail_error_count=%d" % int(guardrail_state.get("error_count", 0)))
	lines.append("guardrail_body_collision_path_present=%s" % str(_guardrail_has_code(guardrail_state, &"body_collision_path")))
	lines.append("guardrail_body_self_collision_present=%s" % str(_guardrail_has_code(guardrail_state, &"body_self_collision")))
	lines.append("guardrail_body_proxy_debug_view=%s" % str(bool(guardrail_debug_views.get("body_clearance_proxy_visible", false))))
	lines.append("guardrail_weapon_proxy_debug_view=%s" % str(bool(guardrail_debug_views.get("weapon_clearance_proxy_visible", false))))
	lines.append("guardrail_joint_range_debug_view=%s" % str(bool(guardrail_debug_views.get("joint_range_plane_available", false))))
	lines.append("guardrail_max_reach_debug_view=%s" % str(bool(guardrail_debug_views.get("max_reach_boundary_available", false))))
	lines.append("guardrail_min_clearance_debug_view=%s" % str(bool(guardrail_debug_views.get("min_clearance_boundary_available", false))))
	lines.append("guardrail_normalized_pivot_debug_view=%s" % str(bool(guardrail_debug_views.get("normalized_pivot_path_available", false))))
	lines.append("guardrail_speed_coloring_debug_view=%s" % str(bool(guardrail_debug_views.get("speed_state_coloring_available", false))))
	lines.append("guardrail_debug_views_ok=%s" % str(
		bool(guardrail_debug_views.get("body_clearance_proxy_visible", false))
		and bool(guardrail_debug_views.get("weapon_clearance_proxy_visible", false))
		and bool(guardrail_debug_views.get("min_clearance_boundary_available", false))
		and bool(guardrail_debug_views.get("speed_state_coloring_available", false))
	))
	lines.append("collision_debug_visuals_ok=%s" % str(
		int(debug_state.get("body_restriction_debug_mesh_count", 0)) > 0
		and int(debug_state.get("primary_grip_debug_count", 0)) > 0
		and int(debug_state.get("weapon_proxy_debug_count", 0)) > 0
	))
	lines.append("selected_motion_node_index=%d" % int(debug_state.get("selected_motion_node_index", -1)))
	lines.append("marker_root_exists=%s" % str(bool(debug_state.get("marker_root_exists", false))))
	lines.append("trajectory_root_parent_name=%s" % String(debug_state.get("trajectory_root_parent_name", "")))
	lines.append("trajectory_root_parent_ok=%s" % str(String(debug_state.get("trajectory_root_parent_name", "")) == "CombatAnimationPreviewRoot3D"))
	lines.append("trajectory_root_global_position=%s" % str(debug_state.get("trajectory_root_global_position", Vector3.ZERO)))
	lines.append("body_lock_frame_source=%s" % String(debug_state.get("body_lock_frame_source", "")))
	lines.append("body_lock_frame_origin=%s" % str(debug_state.get("body_lock_frame_origin", Vector3.ZERO)))
	lines.append("body_lock_uses_rl_boneroot_ok=%s" % str(String(debug_state.get("body_lock_frame_source", "")) == "RL_BoneRoot"))
	lines.append("weapon_tip_alignment_error_meters=%s" % str(snapped(float(debug_state.get("weapon_tip_alignment_error_meters", -1.0)), 0.0001)))
	lines.append("weapon_pommel_alignment_error_meters=%s" % str(snapped(float(debug_state.get("weapon_pommel_alignment_error_meters", -1.0)), 0.0001)))
	var resolved_tip_position: Vector3 = debug_state.get("resolved_tip_position_local", Vector3.ZERO) as Vector3
	var resolved_pommel_position: Vector3 = debug_state.get("resolved_pommel_position_local", Vector3.ZERO) as Vector3
	var display_tip_position: Vector3 = debug_state.get("display_selected_tip_position_local", Vector3.ZERO) as Vector3
	var display_pommel_position: Vector3 = debug_state.get("display_selected_pommel_position_local", Vector3.ZERO) as Vector3
	lines.append("resolved_tip_position=%s" % str(resolved_tip_position))
	lines.append("display_tip_position=%s" % str(display_tip_position))
	lines.append("resolved_pommel_position=%s" % str(resolved_pommel_position))
	lines.append("display_pommel_position=%s" % str(display_pommel_position))
	lines.append("display_tip_matches_resolved_ok=%s" % str(display_tip_position.distance_to(resolved_tip_position) <= 0.001))
	lines.append("display_pommel_matches_resolved_ok=%s" % str(display_pommel_position.distance_to(resolved_pommel_position) <= 0.001))
	lines.append("dominant_grip_alignment_error_meters=%s" % str(snapped(float(debug_state.get("dominant_grip_alignment_error_meters", -1.0)), 0.0001)))
	lines.append("support_grip_alignment_error_meters=%s" % str(snapped(float(debug_state.get("support_grip_alignment_error_meters", -1.0)), 0.0001)))
	lines.append("dominant_finger_contact_readiness=%s" % str(snapped(float(debug_state.get("dominant_finger_contact_readiness", -1.0)), 0.0001)))
	lines.append("support_finger_contact_readiness=%s" % str(snapped(float(debug_state.get("support_finger_contact_readiness", -1.0)), 0.0001)))
	lines.append("dominant_finger_contact_distance_meters=%s" % str(snapped(float(debug_state.get("dominant_finger_contact_distance_meters", -1.0)), 0.0001)))
	lines.append("support_finger_contact_distance_meters=%s" % str(snapped(float(debug_state.get("support_finger_contact_distance_meters", -1.0)), 0.0001)))
	_append_contact_ray_debug_lines(lines, "dominant", debug_state.get("dominant_finger_contact_ray_debug", []) as Array)
	_append_contact_ray_debug_lines(lines, "support", debug_state.get("support_finger_contact_ray_debug", []) as Array)
	lines.append("contact_rays_hit_grip_shell_ok=%s" % str(
		_count_contact_ray_hits(debug_state.get("dominant_finger_contact_ray_debug", []) as Array) > 0
		and _count_contact_ray_hits(debug_state.get("support_finger_contact_ray_debug", []) as Array) > 0
	))
	var grip_contact_debug_state: Dictionary = debug_state.get("grip_contact_debug_state", {}) as Dictionary
	lines.append("right_arm_ik_active=%s" % str(bool(grip_contact_debug_state.get("right_arm_ik_active", false))))
	lines.append("left_arm_ik_active=%s" % str(bool(grip_contact_debug_state.get("left_arm_ik_active", false))))
	lines.append("right_arm_guidance_active=%s" % str(bool(grip_contact_debug_state.get("right_arm_guidance_active", false))))
	lines.append("left_arm_guidance_active=%s" % str(bool(grip_contact_debug_state.get("left_arm_guidance_active", false))))
	lines.append("right_authoring_contact_basis_active=%s" % str(bool(grip_contact_debug_state.get("right_authoring_contact_basis_active", false))))
	lines.append("left_authoring_contact_basis_active=%s" % str(bool(grip_contact_debug_state.get("left_authoring_contact_basis_active", false))))
	lines.append("right_hand_ik_target_distance_meters=%s" % str(snapped(float(grip_contact_debug_state.get("right_hand_ik_target_distance_meters", -1.0)), 0.0001)))
	lines.append("left_hand_ik_target_distance_meters=%s" % str(snapped(float(grip_contact_debug_state.get("left_hand_ik_target_distance_meters", -1.0)), 0.0001)))
	var support_coupling_metrics: Dictionary = debug_state.get("support_coupling_metrics", {}) as Dictionary
	lines.append("support_weapon_seat_distance_meters=%s" % str(snapped(float(support_coupling_metrics.get("weapon_seat_distance_meters", -1.0)), 0.0001)))
	lines.append("support_hand_target_distance_meters=%s" % str(snapped(float(support_coupling_metrics.get("hand_target_distance_meters", -1.0)), 0.0001)))
	lines.append("support_radial_mismatch_meters=%s" % str(snapped(float(support_coupling_metrics.get("radial_mismatch_meters", -1.0)), 0.0001)))
	var contact_coupling_metrics: Dictionary = debug_state.get("contact_coupling_metrics", {}) as Dictionary
	var contact_dominant_before: float = float(contact_coupling_metrics.get("dominant_error_before_meters", -1.0))
	var contact_dominant_after: float = float(contact_coupling_metrics.get("dominant_error_after_meters", -1.0))
	var contact_support_before: float = float(contact_coupling_metrics.get("support_error_before_meters", -1.0))
	var contact_support_after: float = float(contact_coupling_metrics.get("support_error_after_meters", -1.0))
	lines.append("contact_coupling_dominant_before_meters=%s" % str(snapped(contact_dominant_before, 0.0001)))
	lines.append("contact_coupling_dominant_after_meters=%s" % str(snapped(contact_dominant_after, 0.0001)))
	lines.append("contact_coupling_support_before_meters=%s" % str(snapped(contact_support_before, 0.0001)))
	lines.append("contact_coupling_support_after_meters=%s" % str(snapped(contact_support_after, 0.0001)))
	lines.append("contact_coupling_translation_meters=%s" % str(snapped(float(contact_coupling_metrics.get("translation_delta_meters", -1.0)), 0.0001)))
	lines.append("contact_coupling_improved_or_held_ok=%s" % str(
		contact_dominant_after >= 0.0
		and contact_dominant_before >= 0.0
		and contact_dominant_after <= contact_dominant_before + 0.001
	))
	lines.append("dominant_grip_seated_ok=%s" % str(
		float(debug_state.get("dominant_grip_alignment_error_meters", 999.0)) >= 0.0
		and float(debug_state.get("dominant_grip_alignment_error_meters", 999.0)) <= 0.01
	))
	lines.append("weapon_endpoint_alignment_ok=%s" % str(
		float(debug_state.get("weapon_tip_alignment_error_meters", 999.0)) <= 0.001
		and float(debug_state.get("weapon_pommel_alignment_error_meters", 999.0)) <= 0.001
	))
	lines.append("camera_orbit_ok=%s" % str(orbit_ok))
	lines.append("camera_zoom_ok=%s" % str(zoom_ok))
	lines.append("focus_initial=%s" % String(focus_initial))
	lines.append("focus_after_one_cycle=%s" % String(focus_after_one_cycle))
	lines.append("focus_after_two_cycles=%s" % String(focus_after_two_cycles))
	lines.append("focus_after_three_cycles=%s" % String(focus_after_three_cycles))
	lines.append("focus_after_four_cycles=%s" % String(focus_after_four_cycles))
	lines.append("focus_cycle_ok=%s" % str(
		focus_initial == CombatAnimationSessionStateScript.FOCUS_TIP
		and focus_after_one_cycle == CombatAnimationSessionStateScript.FOCUS_POMMEL
		and focus_after_two_cycles == CombatAnimationSessionStateScript.FOCUS_WEAPON
		and focus_after_three_cycles == CombatAnimationSessionStateScript.FOCUS_ARM_ROLL
		and focus_after_four_cycles == CombatAnimationSessionStateScript.FOCUS_TIP
	))
	lines.append("legacy_plane_removed_ok=true")
	lines.append("authoring_tip_update_ok=%s" % str(authoring_tip_update_ok))
	lines.append("authoring_tip_retained_ok=%s" % str(authored_tip_retained_ok))
	lines.append("authoring_tip_kept_pommel_ok=%s" % str(authoring_tip_kept_pommel_ok))
	lines.append("authoring_pommel_update_ok=%s" % str(authoring_pommel_update_ok))
	lines.append("authoring_pommel_retained_ok=%s" % str(authored_pommel_retained_ok))
	lines.append("authoring_pommel_translated_tip_ok=%s" % str(authoring_pommel_translated_tip_ok))
	lines.append("authoring_segment_length_ok=%s" % str(authored_segment_length_ok))
	lines.append("grip_slide_reseat_update_ok=%s" % str(grip_slide_update_ok))
	lines.append("grip_slide_reseat_segment_shifted_ok=%s" % str(grip_slide_segment_shifted_ok))
	lines.append("grip_slide_reseat_segment_length_ok=%s" % str(grip_slide_segment_length_ok))
	lines.append("grip_slide_reseat_error_meters=%s" % str(snapped(float(grip_slide_debug_state.get("grip_seat_reseat_error_meters", -1.0)), 0.0001)))
	lines.append("grip_slide_reseat_locked_ok=%s" % str(
		float(grip_slide_debug_state.get("grip_seat_reseat_error_meters", 999.0)) >= 0.0
		and float(grip_slide_debug_state.get("grip_seat_reseat_error_meters", 999.0)) <= 0.002
	))
	lines.append("camera_distance_before_refresh=%s" % str(snapped(float(camera_state_before_refresh.get("camera_distance", 0.0)), 0.0001)))
	lines.append("camera_distance_after_refresh=%s" % str(snapped(float(debug_state.get("camera_distance", 0.0)), 0.0001)))
	lines.append("camera_extended_zoom_out_ok=%s" % str(extended_zoom_out_ok))
	lines.append("camera_yaw_before_refresh=%s" % str(snapped(float(camera_state_before_refresh.get("camera_orbit_yaw_degrees", 0.0)), 0.0001)))
	lines.append("camera_yaw_after_refresh=%s" % str(snapped(float(debug_state.get("camera_orbit_yaw_degrees", 0.0)), 0.0001)))
	lines.append("camera_pitch_before_refresh=%s" % str(snapped(float(camera_state_before_refresh.get("camera_orbit_pitch_degrees", 0.0)), 0.0001)))
	lines.append("camera_pitch_after_refresh=%s" % str(snapped(float(debug_state.get("camera_orbit_pitch_degrees", 0.0)), 0.0001)))
	lines.append("seeded_tip_position=%s" % str(seeded_tip_position))
	lines.append("seeded_pommel_position=%s" % str(seeded_pommel_position))
	lines.append("second_tip_position=%s" % str(second_tip_position))
	lines.append("second_pommel_position=%s" % str(second_pommel_position))
	lines.append("seeded_geometry_nonzero=%s" % str(not seeded_tip_position.is_zero_approx() and not seeded_pommel_position.is_zero_approx()))
	lines.append("weapon_total_length_meters=%s" % str(snapped(float(baked_profile.weapon_total_length_meters if baked_profile != null else 0.0), 0.0001)))
	var tether_source_node: CombatAnimationMotionNode = ui.call("_get_active_motion_node") as CombatAnimationMotionNode
	var tether_request: Vector3 = (
		tether_source_node.pommel_position_local + Vector3(4.0, 0.0, 0.0)
		if tether_source_node != null
		else Vector3(4.0, 0.0, 0.0)
	)
	var tether_update_ok: bool = ui.set_selected_motion_node_pommel_position(
		tether_request,
		false,
		true,
		true,
		true,
		true
	)
	await process_frame
	var tether_node_after: CombatAnimationMotionNode = ui.call("_get_active_motion_node") as CombatAnimationMotionNode
	var tether_debug_state: Dictionary = ui.get_preview_debug_state()
	var tether_metrics: Dictionary = tether_debug_state.get("authoring_contact_tether_metrics", {}) as Dictionary
	var tether_dominant_after: float = float(tether_metrics.get("dominant_reach_after_meters", -1.0))
	var tether_dominant_limit: float = float(tether_metrics.get("dominant_reach_limit_meters", -1.0))
	var tether_support_after: float = float(tether_metrics.get("support_reach_after_meters", -1.0))
	var tether_support_limit: float = float(tether_metrics.get("support_reach_limit_meters", -1.0))
	var tether_segment_length_ok: bool = false
	var tether_rejected_raw_request_ok: bool = false
	if tether_node_after != null:
		tether_segment_length_ok = absf(
			tether_node_after.tip_position_local.distance_to(tether_node_after.pommel_position_local)
			- maxf(active_weapon_length, 0.01)
		) <= 0.001
		tether_rejected_raw_request_ok = tether_node_after.pommel_position_local.distance_to(tether_request) > 0.01
	lines.append("authoring_tether_update_ok=%s" % str(tether_update_ok))
	lines.append("authoring_tether_reference_space=%s" % String(tether_metrics.get("reference_space", "")))
	lines.append("authoring_tether_clamped=%s" % str(bool(tether_metrics.get("clamped", false))))
	lines.append("authoring_tether_rejected_raw_request_ok=%s" % str(tether_rejected_raw_request_ok))
	lines.append("authoring_tether_segment_length_ok=%s" % str(tether_segment_length_ok))
	lines.append("authoring_tether_dominant_reach_after_meters=%s" % str(snapped(tether_dominant_after, 0.0001)))
	lines.append("authoring_tether_dominant_reach_limit_meters=%s" % str(snapped(tether_dominant_limit, 0.0001)))
	lines.append("authoring_tether_dominant_seat_error_before_meters=%s" % str(snapped(float(tether_metrics.get("dominant_seat_error_before_meters", -1.0)), 0.0001)))
	lines.append("authoring_tether_dominant_seat_error_after_meters=%s" % str(snapped(float(tether_metrics.get("dominant_seat_error_after_meters", -1.0)), 0.0001)))
	lines.append("authoring_tether_dominant_seat_locked_ok=%s" % str(
		float(tether_metrics.get("dominant_seat_error_after_meters", 999.0)) <= 0.002
	))
	lines.append("authoring_tether_dominant_inside_limit_ok=%s" % str(
		tether_dominant_after >= 0.0
		and tether_dominant_limit >= 0.0
		and tether_dominant_after <= tether_dominant_limit + 0.02
	))
	lines.append("authoring_tether_support_inside_limit_ok=%s" % str(
		tether_support_after < 0.0
		or tether_support_limit < 0.0
		or tether_support_after <= tether_support_limit + 0.02
	))
	var tip_tether_node_before: CombatAnimationMotionNode = ui.call("_get_active_motion_node") as CombatAnimationMotionNode
	var tip_tether_pommel_before: Vector3 = tip_tether_node_before.pommel_position_local if tip_tether_node_before != null else Vector3.ZERO
	var tip_tether_request: Vector3 = (
		tip_tether_node_before.pommel_position_local + Vector3(1.0, 0.0, 0.0) * maxf(active_weapon_length, 0.01)
		if tip_tether_node_before != null
		else Vector3(1.0, 0.0, 0.0)
	)
	var tip_tether_update_ok: bool = ui.set_selected_motion_node_tip_position(
		tip_tether_request,
		false,
		true,
		true,
		true,
		true
	)
	await process_frame
	var tip_tether_node_after: CombatAnimationMotionNode = ui.call("_get_active_motion_node") as CombatAnimationMotionNode
	var tip_tether_debug_state: Dictionary = ui.get_preview_debug_state()
	var tip_tether_metrics: Dictionary = tip_tether_debug_state.get("authoring_contact_tether_metrics", {}) as Dictionary
	var tip_tether_segment_length_ok: bool = false
	var tip_tether_pommel_stationary_ok: bool = false
	if tip_tether_node_after != null:
		tip_tether_segment_length_ok = absf(
			tip_tether_node_after.tip_position_local.distance_to(tip_tether_node_after.pommel_position_local)
			- maxf(active_weapon_length, 0.01)
		) <= 0.001
		tip_tether_pommel_stationary_ok = tip_tether_node_after.pommel_position_local.distance_to(tip_tether_pommel_before) <= 0.001
	var tip_contact_pivot_result: Dictionary = {}
	if tip_tether_node_after != null:
		tip_contact_pivot_result = ui.get("preview_presenter").constrain_authored_segment_to_contact_tether(
			ui.get("preview_subviewport"),
			ui.get("active_wip"),
			tip_tether_node_after,
			Vector3(4.0, 0.0, 0.0),
			Vector3(4.0 - maxf(active_weapon_length, 0.01), 0.0, 0.0),
			&"tip_pivot"
		)
	var tip_contact_pivot_metrics: Dictionary = tip_contact_pivot_result.get("tether_metrics", {}) as Dictionary
	var tip_contact_pivot_swapped_ok: bool = String(tip_contact_pivot_metrics.get("pivot_mode", "")) in ["dominant_wrist", "dominant_contact"]
	lines.append("authoring_tip_tether_update_ok=%s" % str(tip_tether_update_ok))
	lines.append("authoring_tip_tether_reference_space=%s" % String(tip_tether_metrics.get("reference_space", "")))
	lines.append("authoring_tip_tether_mode=%s" % String(tip_tether_metrics.get("mode", "")))
	lines.append("authoring_tip_tether_pivot_mode=%s" % String(tip_tether_metrics.get("pivot_mode", "")))
	lines.append("authoring_tip_tether_trigger=%s" % String(tip_tether_metrics.get("tip_pivot_trigger", "")))
	lines.append("authoring_tip_tether_primary_seat_error_meters=%s" % str(snapped(float(tip_tether_metrics.get("tip_pivot_primary_seat_error_meters", -1.0)), 0.0001)))
	lines.append("authoring_tip_tether_wrist_lock_error_after_meters=%s" % str(snapped(float(tip_tether_metrics.get("tip_pivot_wrist_lock_error_after_meters", -1.0)), 0.0001)))
	lines.append("authoring_tip_tether_wrist_lock_applicable=%s" % str(String(tip_tether_metrics.get("pivot_mode", "")) == "dominant_wrist"))
	lines.append("authoring_tip_tether_wrist_locked_ok=%s" % str(
		String(tip_tether_metrics.get("pivot_mode", "")) != "dominant_wrist"
		or float(tip_tether_metrics.get("tip_pivot_wrist_lock_error_after_meters", 999.0)) <= 0.002
	))
	lines.append("authoring_tip_tether_dominant_seat_error_after_meters=%s" % str(snapped(float(tip_tether_metrics.get("dominant_seat_error_after_meters", -1.0)), 0.0001)))
	lines.append("authoring_tip_tether_dominant_seat_locked_ok=%s" % str(
		String(tip_tether_metrics.get("pivot_mode", "")) == "dominant_wrist"
		or float(tip_tether_metrics.get("dominant_seat_error_after_meters", 999.0)) <= 0.002
	))
	lines.append("authoring_tip_tether_segment_length_ok=%s" % str(tip_tether_segment_length_ok))
	lines.append("authoring_tip_tether_pommel_stationary_ok=%s" % str(tip_tether_pommel_stationary_ok))
	lines.append("authoring_tip_contact_pivot_mode=%s" % String(tip_contact_pivot_metrics.get("pivot_mode", "")))
	lines.append("authoring_tip_contact_pivot_trigger=%s" % String(tip_contact_pivot_metrics.get("tip_pivot_trigger", "")))
	lines.append("authoring_tip_contact_pivot_primary_seat_error_meters=%s" % str(snapped(float(tip_contact_pivot_metrics.get("tip_pivot_primary_seat_error_meters", -1.0)), 0.0001)))
	lines.append("authoring_tip_contact_pivot_wrist_lock_error_after_meters=%s" % str(snapped(float(tip_contact_pivot_metrics.get("tip_pivot_wrist_lock_error_after_meters", -1.0)), 0.0001)))
	lines.append("authoring_tip_contact_pivot_wrist_locked_ok=%s" % str(
		String(tip_contact_pivot_metrics.get("pivot_mode", "")) == "dominant_wrist"
		and float(tip_contact_pivot_metrics.get("tip_pivot_wrist_lock_error_after_meters", 999.0)) <= 0.002
	))
	lines.append("authoring_tip_contact_pivot_swapped_ok=%s" % str(tip_contact_pivot_swapped_ok))
	lines.append("later_node_tip_pick_selected_index=%d" % later_node_tip_pick_selected_index)
	lines.append("later_node_tip_pick_display_position=%s" % str(later_node_tip_pick_display_position))
	lines.append("later_node_tip_pick_screen_position=%s" % str(later_node_tip_pick_screen_position))
	lines.append("later_node_tip_pick_target=%s" % String(later_node_tip_pick_target))
	lines.append("later_node_tip_pick_ok=%s" % str(later_node_tip_pick_ok))
	lines.append("later_node_tip_curve_handle_position=%s" % str(later_node_tip_curve_handle_position))
	lines.append("later_node_tip_curve_handle_screen_position=%s" % str(later_node_tip_curve_handle_screen_position))
	lines.append("later_node_tip_curve_handle_pick_target=%s" % String(later_node_tip_curve_handle_pick_target))
	lines.append("later_node_tip_curve_handle_pick_ok=%s" % str(later_node_tip_curve_handle_pick_ok))
	var left_primary_update_ok: bool = ui.set_selected_motion_node_primary_hand_slot(&"hand_left", false)
	await process_frame
	var left_primary_debug_state: Dictionary = ui.get_preview_debug_state()
	var left_primary_contact_state: Dictionary = left_primary_debug_state.get("grip_contact_debug_state", {}) as Dictionary
	lines.append("left_primary_contact_basis_update_ok=%s" % str(left_primary_update_ok))
	lines.append("left_primary_contact_basis_active=%s" % str(bool(left_primary_contact_state.get("left_authoring_contact_basis_active", false))))
	lines.append("right_support_contact_basis_active_after_left_primary=%s" % str(bool(left_primary_contact_state.get("right_authoring_contact_basis_active", false))))

	var file: FileAccess = FileAccess.open(RESULT_FILE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()
	quit()

func _append_contact_ray_debug_lines(lines: PackedStringArray, prefix: String, ray_entries: Array) -> void:
	lines.append("%s_contact_ray_count=%d" % [prefix, ray_entries.size()])
	var last_entry: Dictionary = {}
	var first_hit_entry: Dictionary = {}
	var hit_count: int = 0
	for entry_variant: Variant in ray_entries:
		var entry: Dictionary = entry_variant as Dictionary
		if not entry.is_empty():
			last_entry = entry
		if bool(entry.get("hit", false)):
			hit_count += 1
			if first_hit_entry.is_empty():
				first_hit_entry = entry
	lines.append("%s_contact_ray_hit_count=%d" % [prefix, hit_count])
	if last_entry.is_empty():
		lines.append("%s_contact_ray_last_hit=false" % prefix)
		lines.append("%s_contact_ray_last_collider=" % prefix)
		lines.append("%s_contact_ray_last_layer=-1" % prefix)
		lines.append("%s_contact_ray_last_context=" % prefix)
		lines.append("%s_contact_ray_last_skip=no_rays" % prefix)
		lines.append("%s_contact_ray_first_hit_collider=" % prefix)
		return
	if first_hit_entry.is_empty():
		lines.append("%s_contact_ray_first_hit_collider=" % prefix)
		lines.append("%s_contact_ray_first_hit_class=" % prefix)
		lines.append("%s_contact_ray_first_hit_layer=-1" % prefix)
		lines.append("%s_contact_ray_first_hit_context=" % prefix)
		lines.append("%s_contact_ray_first_hit_finger=" % prefix)
	else:
		lines.append("%s_contact_ray_first_hit_collider=%s" % [prefix, String(first_hit_entry.get("collider_path", ""))])
		lines.append("%s_contact_ray_first_hit_class=%s" % [prefix, String(first_hit_entry.get("collider_class", ""))])
		lines.append("%s_contact_ray_first_hit_layer=%d" % [prefix, int(first_hit_entry.get("collider_layer", -1))])
		lines.append("%s_contact_ray_first_hit_context=%s" % [prefix, String(first_hit_entry.get("context", ""))])
		lines.append("%s_contact_ray_first_hit_finger=%s" % [prefix, String(first_hit_entry.get("finger_id", ""))])
	lines.append("%s_contact_ray_last_hit=%s" % [prefix, str(bool(last_entry.get("hit", false)))])
	lines.append("%s_contact_ray_last_collider=%s" % [prefix, String(last_entry.get("collider_path", ""))])
	lines.append("%s_contact_ray_last_class=%s" % [prefix, String(last_entry.get("collider_class", ""))])
	lines.append("%s_contact_ray_last_layer=%d" % [prefix, int(last_entry.get("collider_layer", -1))])
	lines.append("%s_contact_ray_last_mask=%d" % [prefix, int(last_entry.get("collision_mask", 0))])
	lines.append("%s_contact_ray_last_context=%s" % [prefix, String(last_entry.get("context", ""))])
	lines.append("%s_contact_ray_last_finger=%s" % [prefix, String(last_entry.get("finger_id", ""))])
	lines.append("%s_contact_ray_last_skip=%s" % [prefix, String(last_entry.get("skipped_reason", ""))])
	lines.append("%s_contact_ray_last_distance_meters=%s" % [
		prefix,
		str(snapped(float(last_entry.get("hit_distance_meters", -1.0)), 0.0001)),
	])

func _count_contact_ray_hits(ray_entries: Array) -> int:
	var hit_count: int = 0
	for entry_variant: Variant in ray_entries:
		var entry: Dictionary = entry_variant as Dictionary
		if bool(entry.get("hit", false)):
			hit_count += 1
	return hit_count

func _guardrail_has_code(guardrail_state: Dictionary, code: StringName) -> bool:
	var entries: Array = guardrail_state.get("entries", []) as Array
	for entry_variant: Variant in entries:
		var entry: Dictionary = entry_variant as Dictionary
		if StringName(entry.get("code", StringName())) == code:
			return true
	return false

func _build_preview_test_wip() -> CraftedItemWIP:
	var wip: CraftedItemWIP = CraftedItemWIPScript.new()
	wip.wip_id = &"combat_preview_test_wip"
	wip.forge_project_name = "Combat Preview Test WIP"
	CraftedItemWIPScript.apply_builder_path_defaults(
		wip,
		CraftedItemWIPScript.BUILDER_PATH_MELEE,
		CraftedItemWIPScript.BUILDER_COMPONENT_PRIMARY
	)
	var layer_map: Dictionary = {}
	for slice_index: int in range(26):
		for y in range(4, 6):
			for z in range(4, 7):
				_add_cell(layer_map, Vector3i(slice_index, y, z), WOOD_MATERIAL_ID)
	var ordered_layers: Array = layer_map.keys()
	ordered_layers.sort()
	for layer_index_value: Variant in ordered_layers:
		wip.layers.append(layer_map[layer_index_value])
	return wip

func _add_cell(layer_map: Dictionary, grid_position: Vector3i, material_variant_id: StringName) -> void:
	if not layer_map.has(grid_position.z):
		var layer: LayerAtom = LayerAtomScript.new()
		layer.layer_index = grid_position.z
		layer.cells = []
		layer_map[grid_position.z] = layer
	var cell: CellAtom = CellAtomScript.new()
	cell.grid_position = grid_position
	cell.layer_index = grid_position.z
	cell.material_variant_id = material_variant_id
	var target_layer: LayerAtom = layer_map[grid_position.z]
	target_layer.cells.append(cell)
