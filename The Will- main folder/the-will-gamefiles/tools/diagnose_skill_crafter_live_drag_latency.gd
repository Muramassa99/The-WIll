extends SceneTree

const PlayerForgeWipLibraryStateScript = preload("res://core/models/player_forge_wip_library_state.gd")
const CombatAnimationStationUIScene = preload("res://scenes/ui/combat_animation_station_ui.tscn")
const CombatAnimationMotionNodeEditorScript = preload("res://runtime/combat/combat_animation_motion_node_editor.gd")

const TARGET_PROJECT_NAME := "katana_test_complex"
const TARGET_SLOT_ID: StringName = &"skill_slot_1"
const DOMINANT_SLOT_ID: StringName = &"hand_right"
const SAMPLE_COUNT: int = 7
const DRAG_RADIUS_METERS: float = 0.015
const MAX_BACKGROUND_VALIDATION_FRAMES: int = 300
const RESULT_FILE_PATH := "C:/WORKSPACE/DEBUG-LOGS/skill_crafter_live_drag_latency.log"
const PREVIEW_ACTOR_PATH := "PreviewActorPivot/PreviewActor"
const PREVIEW_SKELETON_PATH := "JosieModel/Josie/Skeleton3D"
const PATH_PARITY_BONES: Array[StringName] = [
	&"RL_BoneRoot",
	&"CC_Base_Hip",
	&"CC_Base_Spine01",
	&"CC_Base_Spine02",
	&"CC_Base_R_Clavicle",
	&"CC_Base_R_Upperarm",
	&"CC_Base_R_Forearm",
	&"CC_Base_R_Hand",
	&"CC_Base_L_Clavicle",
	&"CC_Base_L_Upperarm",
	&"CC_Base_L_Forearm",
	&"CC_Base_L_Hand",
]

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
	DirAccess.make_dir_recursive_absolute(RESULT_FILE_PATH.get_base_dir())
	lines.append("diagnostic=skill_crafter_live_drag_latency")
	lines.append("target_project_name=%s" % TARGET_PROJECT_NAME)
	lines.append("sample_count=%d" % SAMPLE_COUNT)

	var source_library: PlayerForgeWipLibraryState = PlayerForgeWipLibraryStateScript.load_or_create()
	var source_wip: CraftedItemWIP = _find_saved_wip_by_project_name(source_library, TARGET_PROJECT_NAME)
	if source_wip == null:
		lines.append("failure=target_wip_missing")
		_finish(2)
		return

	var diagnostic_library: PlayerForgeWipLibraryState = PlayerForgeWipLibraryStateScript.new()
	diagnostic_library.saved_wips.clear()
	var diagnostic_wip: CraftedItemWIP = source_wip.duplicate(true) as CraftedItemWIP
	if diagnostic_wip == null:
		lines.append("failure=target_wip_duplicate_failed")
		_finish(3)
		return
	diagnostic_library.saved_wips.append(diagnostic_wip)
	diagnostic_library.selected_wip_id = diagnostic_wip.wip_id

	var fake_player := FakePlayer.new()
	fake_player.forge_wip_library_state = diagnostic_library
	root.add_child(fake_player)

	var ui: CombatAnimationStationUI = CombatAnimationStationUIScene.instantiate() as CombatAnimationStationUI
	root.add_child(ui)
	ui.preview_presenter.set_meta("trace_preview_latency", true)
	await process_frame
	ui.open_for(fake_player, "Skill Crafter Live Drag Latency")
	await _wait_frames(2)
	var open_ok: bool = ui.open_saved_wip_with_hand_setup(
		diagnostic_wip.wip_id,
		DOMINANT_SLOT_ID,
		false,
		false
	)
	await _wait_frames(2)
	var select_ok: bool = ui.select_skill_slot(TARGET_SLOT_ID, true)
	await _wait_frames(2)
	lines.append("open_ok=%s" % str(open_ok))
	lines.append("select_ok=%s" % str(select_ok))
	if not open_ok or not select_ok:
		lines.append("failure=skill_editor_open_failed")
		_finish(4)
		return

	var source_motion_node: CombatAnimationMotionNode = ui.call("_get_active_motion_node") as CombatAnimationMotionNode
	if source_motion_node == null:
		lines.append("failure=active_motion_node_missing")
		_finish(5)
		return

	ui.call("_begin_preview_drag_override", source_motion_node)
	ui.motion_node_editor.begin_drag(
		CombatAnimationMotionNodeEditorScript.DRAG_TARGET_TIP,
		Vector2.ZERO,
		source_motion_node
	)
	var drag_motion_node: CombatAnimationMotionNode = ui.preview_drag_override_node as CombatAnimationMotionNode
	if drag_motion_node == null:
		lines.append("failure=drag_override_missing")
		_finish(6)
		return

	var base_tip: Vector3 = drag_motion_node.tip_position_local
	var held_samples_ms: Array[float] = []
	var held_pose_samples: PackedStringArray = []
	var held_weapon_seat_samples: PackedStringArray = []
	var held_digit_surface_samples: PackedStringArray = []
	var max_tip_alignment_error_meters: float = 0.0
	var max_pommel_alignment_error_meters: float = 0.0
	var preview_root: Node3D = ui.preview_subviewport.get_node_or_null("CombatAnimationPreviewRoot3D") as Node3D
	for sample_index: int in range(SAMPLE_COUNT):
		var angle: float = TAU * float(sample_index + 1) / float(SAMPLE_COUNT)
		var requested_tip: Vector3 = base_tip + Vector3(
			0.0,
			cos(angle) * DRAG_RADIUS_METERS,
			sin(angle) * DRAG_RADIUS_METERS
		)
		var resolved_segment: Dictionary = ui.call(
			"_resolve_motion_node_segment_for_tip_target",
			drag_motion_node,
			requested_tip,
			false
		) as Dictionary
		if bool(ui.call("_apply_resolved_segment_to_motion_node", drag_motion_node, resolved_segment)):
			ui.preview_drag_has_moved = true
			drag_motion_node.normalize()
		var refresh_start_usec: int = Time.get_ticks_usec()
		ui.call("_refresh_preview_scene")
		var refresh_elapsed_ms: float = float(Time.get_ticks_usec() - refresh_start_usec) / 1000.0
		held_samples_ms.append(refresh_elapsed_ms)
		if preview_root != null:
			held_pose_samples.append(_capture_path_pose_sample(preview_root))
			var preview_actor: Node3D = preview_root.get_node_or_null(PREVIEW_ACTOR_PATH) as Node3D
			if preview_actor != null and preview_actor.has_method("get_weapon_surface_seat_debug_state"):
				held_weapon_seat_samples.append(_summarize_exact_solve_state(
					preview_actor.call("get_weapon_surface_seat_debug_state", DOMINANT_SLOT_ID) as Dictionary
				))
				var finger_presenter: Variant = preview_actor.get("finger_grip_presenter")
				if finger_presenter != null and finger_presenter.has_method("get_surface_grasp_debug_state"):
					held_digit_surface_samples.append(_summarize_exact_solve_state(
						finger_presenter.call("get_surface_grasp_debug_state", DOMINANT_SLOT_ID) as Dictionary
					))
			max_tip_alignment_error_meters = maxf(
				max_tip_alignment_error_meters,
				float(preview_root.get_meta("weapon_tip_alignment_error_meters", 0.0))
			)
			max_pommel_alignment_error_meters = maxf(
				max_pommel_alignment_error_meters,
				float(preview_root.get_meta("weapon_pommel_alignment_error_meters", 0.0))
			)

	var expected_tip: Vector3 = drag_motion_node.tip_position_local
	var expected_pommel: Vector3 = drag_motion_node.pommel_position_local
	ui.motion_node_editor.end_drag()
	var release_start_usec: int = Time.get_ticks_usec()
	ui.call("_finalize_preview_drag", "Live drag latency diagnostic settled.")
	var release_elapsed_ms: float = float(Time.get_ticks_usec() - release_start_usec) / 1000.0
	var committed_motion_node: CombatAnimationMotionNode = ui.call("_get_active_motion_node") as CombatAnimationMotionNode
	var immediate_release_debug_state: Dictionary = ui.get_preview_debug_state()
	var pending_processed_before_camera: int = int(
		immediate_release_debug_state.get("collision_path_processed_pose_count", 0)
	)
	var camera_state_before: Dictionary = ui.preview_presenter.capture_camera_state(ui.preview_subviewport)
	ui.preview_camera_orbiting = true
	var camera_orbit_start_usec: int = Time.get_ticks_usec()
	var camera_orbit_ok: bool = ui.orbit_preview_camera(Vector2(8.0, -5.0))
	var camera_orbit_elapsed_ms: float = float(Time.get_ticks_usec() - camera_orbit_start_usec) / 1000.0
	await _wait_frames(3)
	var paused_camera_debug_state: Dictionary = ui.get_preview_debug_state()
	var pending_processed_after_camera: int = int(
		paused_camera_debug_state.get("collision_path_processed_pose_count", 0)
	)
	var camera_state_after: Dictionary = ui.preview_presenter.capture_camera_state(ui.preview_subviewport)
	ui.preview_camera_orbiting = false
	ui.preview_camera_validation_pause_until_msec = 0
	var background_validation_start_usec: int = Time.get_ticks_usec()
	var background_validation_frames: int = 0
	while (
		ui.preview_presenter.has_pending_collision_path_validation()
		and background_validation_frames < MAX_BACKGROUND_VALIDATION_FRAMES
	):
		await process_frame
		background_validation_frames += 1
	var background_validation_elapsed_ms: float = float(
		Time.get_ticks_usec() - background_validation_start_usec
	) / 1000.0
	var release_debug_state: Dictionary = ui.get_preview_debug_state()
	var release_weapon_seat_state: String = "missing_actor"
	var release_digit_surface_state: String = "missing_actor"
	if preview_root != null:
		var release_preview_actor: Node3D = preview_root.get_node_or_null(PREVIEW_ACTOR_PATH) as Node3D
		if release_preview_actor != null:
			if release_preview_actor.has_method("get_weapon_surface_seat_debug_state"):
				release_weapon_seat_state = _summarize_exact_solve_state(
					release_preview_actor.call("get_weapon_surface_seat_debug_state", DOMINANT_SLOT_ID) as Dictionary
				)
			var release_finger_presenter: Variant = release_preview_actor.get("finger_grip_presenter")
			if release_finger_presenter != null and release_finger_presenter.has_method("get_surface_grasp_debug_state"):
				release_digit_surface_state = _summarize_exact_solve_state(
					release_finger_presenter.call("get_surface_grasp_debug_state", DOMINANT_SLOT_ID) as Dictionary
				)

	held_samples_ms.sort()
	lines.append("held_refresh_p50_ms=%.3f" % _percentile(held_samples_ms, 0.50))
	lines.append("held_refresh_p95_ms=%.3f" % _percentile(held_samples_ms, 0.95))
	lines.append("held_refresh_max_ms=%.3f" % _percentile(held_samples_ms, 1.00))
	lines.append("release_authoritative_ms=%.3f" % release_elapsed_ms)
	lines.append("release_path_pending_immediately=%s" % str(bool(
		immediate_release_debug_state.get("collision_path_pending", false)
	)))
	lines.append("release_camera_orbit_ok=%s" % str(camera_orbit_ok))
	lines.append("release_camera_orbit_ms=%.3f" % camera_orbit_elapsed_ms)
	lines.append("release_camera_yaw_delta_degrees=%.3f" % (
		float(camera_state_after.get("orbit_yaw_degrees", 0.0))
		- float(camera_state_before.get("orbit_yaw_degrees", 0.0))
	))
	lines.append("release_camera_validation_paused=%s" % str(
		pending_processed_before_camera == pending_processed_after_camera
	))
	lines.append("release_background_validation_frames=%d" % background_validation_frames)
	lines.append("release_background_validation_ms=%.3f" % background_validation_elapsed_ms)
	lines.append("release_background_validation_completed=%s" % str(
		not ui.preview_presenter.has_pending_collision_path_validation()
	))
	lines.append("release_stage_msec=%s" % str(ui.preview_drag_finalize_stage_msec))
	lines.append("release_preview_trace=%s" % str(
		ui.preview_presenter.get_meta("last_refresh_preview_latency_trace", [])
	))
	lines.append("release_trajectory_trace=%s" % str(
		ui.preview_presenter.get_meta("last_trajectory_visual_latency_trace", [])
	))
	lines.append("release_weapon_seat_state=%s" % release_weapon_seat_state)
	lines.append("release_digit_surface_state=%s" % release_digit_surface_state)
	lines.append("release_path_state=speed_samples=%d,proxy_samples=%d,path_samples=%d,legal=%s,illegal_poses=%d,first_illegal=%d,region=%s" % [
		int(release_debug_state.get("speed_state_sample_count", 0)),
		int(release_debug_state.get("weapon_proxy_sample_count", 0)),
		int(release_debug_state.get("collision_path_sample_count", 0)),
		str(bool(release_debug_state.get("collision_path_legal", true))),
		int(release_debug_state.get("collision_path_illegal_pose_count", 0)),
		int(release_debug_state.get("collision_path_first_illegal_index", -1)),
		String(release_debug_state.get("collision_path_region", "")),
	])
	lines.append("release_path_baseline_parity=%s" % str(
		int(release_debug_state.get("collision_path_sample_count", 0)) == 121
		and not bool(release_debug_state.get("collision_path_legal", true))
		and int(release_debug_state.get("collision_path_illegal_pose_count", 0)) == 28
		and int(release_debug_state.get("collision_path_first_illegal_index", -1)) == 20
		and String(release_debug_state.get("collision_path_region", "")) == "right_forearm"
	))
	lines.append("held_max_tip_alignment_error_m=%.6f" % max_tip_alignment_error_meters)
	lines.append("held_max_pommel_alignment_error_m=%.6f" % max_pommel_alignment_error_meters)
	for sample_index: int in range(held_pose_samples.size()):
		lines.append("held_pose_sample_%02d=%s" % [
			sample_index,
			held_pose_samples[sample_index],
		])
	for sample_index: int in range(held_weapon_seat_samples.size()):
		lines.append("held_weapon_seat_sample_%02d=%s" % [
			sample_index,
			held_weapon_seat_samples[sample_index],
		])
	for sample_index: int in range(held_digit_surface_samples.size()):
		lines.append("held_digit_surface_sample_%02d=%s" % [
			sample_index,
			held_digit_surface_samples[sample_index],
		])
	if committed_motion_node != null:
		lines.append("release_tip_commit_error_m=%.8f" % committed_motion_node.tip_position_local.distance_to(expected_tip))
		lines.append("release_pommel_commit_error_m=%.8f" % committed_motion_node.pommel_position_local.distance_to(expected_pommel))
	else:
		lines.append("release_commit_missing=true")
	_finish(0)

func _find_saved_wip_by_project_name(
	library_state: PlayerForgeWipLibraryState,
	project_name: String
) -> CraftedItemWIP:
	if library_state == null:
		return null
	for saved_wip: CraftedItemWIP in library_state.get_saved_wips():
		if saved_wip != null and saved_wip.forge_project_name == project_name:
			return saved_wip
	return null

func _percentile(sorted_values: Array[float], ratio: float) -> float:
	if sorted_values.is_empty():
		return 0.0
	var index: int = clampi(
		int(ceil(clampf(ratio, 0.0, 1.0) * float(sorted_values.size()))) - 1,
		0,
		sorted_values.size() - 1
	)
	return sorted_values[index]

func _summarize_exact_solve_state(state: Dictionary) -> String:
	var diagnostics: Dictionary = state.get("diagnostics", {}) as Dictionary
	return "status=%s,solve_ms=%.3f,solve_count=%d,geometry_load_count=%d,cache_hit_count=%d" % [
		String(state.get("status", StringName())),
		float(diagnostics.get("solve_time_msec", -1.0)),
		int(state.get("solve_count", state.get("surface_solve_count", 0))),
		int(state.get("surface_geometry_load_count", 0)),
		int(state.get("cache_hit_count", 0)),
	]

func _capture_path_pose_sample(preview_root: Node3D) -> String:
	var actor: Node3D = preview_root.get_node_or_null(PREVIEW_ACTOR_PATH) as Node3D
	var skeleton: Skeleton3D = (
		actor.get_node_or_null(PREVIEW_SKELETON_PATH) as Skeleton3D
		if actor != null
		else null
	)
	if skeleton == null:
		return "missing_skeleton"
	var values: PackedStringArray = []
	for bone_name: StringName in PATH_PARITY_BONES:
		var bone_index: int = skeleton.find_bone(String(bone_name))
		if bone_index < 0:
			values.append("%s:missing" % String(bone_name))
			continue
		var pose: Transform3D = skeleton.get_bone_global_pose(bone_index)
		var rotation: Quaternion = pose.basis.orthonormalized().get_rotation_quaternion().normalized()
		values.append(
			"%s:%.9f,%.9f,%.9f|%.9f,%.9f,%.9f,%.9f" % [
				String(bone_name),
				pose.origin.x,
				pose.origin.y,
				pose.origin.z,
				rotation.x,
				rotation.y,
				rotation.z,
				rotation.w,
			]
		)
	return ";".join(values)

func _wait_frames(frame_count: int) -> void:
	for _frame_index: int in range(maxi(frame_count, 0)):
		await process_frame

func _finish(exit_code: int) -> void:
	var file: FileAccess = FileAccess.open(RESULT_FILE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()
	for line: String in lines:
		print(line)
	quit(exit_code)
