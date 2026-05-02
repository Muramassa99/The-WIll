extends SceneTree

const PlayerForgeWipLibraryStateScript = preload("res://core/models/player_forge_wip_library_state.gd")
const CombatAnimationStationUIScene = preload("res://scenes/ui/combat_animation_station_ui.tscn")
const CombatAnimationStationStateScript = preload("res://core/models/combat_animation_station_state.gd")

const TARGET_PROJECT_NAME := "Test sword for animations"
const RESULT_FILE_PATH := "C:/WORKSPACE/combat_idle_authority_intervention_results.txt"
const TEMP_SAVE_DIR := "C:/WORKSPACE/test_artifacts"
const SAMPLE_INTERVAL_SECONDS := 1.0 / 60.0
const RESET_COUNT := 3
const WAIT_SECONDS_BETWEEN_RESETS := 3.0
const OBSERVE_SECONDS_AFTER_FINAL_RESET := 3.0

const SCENARIOS := [
	{
		"name": "baseline",
		"freeze_station_process": false,
		"freeze_actor_process": false,
		"clear_guidance": false,
	},
	{
		"name": "freeze_station_process_after_final_reset",
		"freeze_station_process": true,
		"freeze_actor_process": false,
		"clear_guidance": false,
	},
	{
		"name": "freeze_actor_process_after_final_reset",
		"freeze_station_process": false,
		"freeze_actor_process": true,
		"clear_guidance": false,
	},
	{
		"name": "freeze_station_process_and_clear_guidance",
		"freeze_station_process": true,
		"freeze_actor_process": false,
		"clear_guidance": true,
	},
]

class FakePlayer:
	extends Node

	var ui_mode_enabled: bool = false
	var forge_wip_library_state: PlayerForgeWipLibraryState = null

	func get_forge_wip_library_state() -> PlayerForgeWipLibraryState:
		return forge_wip_library_state

	func set_ui_mode_enabled(enabled: bool) -> void:
		ui_mode_enabled = enabled

var result_lines: PackedStringArray = []

func _init() -> void:
	call_deferred("_run_diagnostic")

func _run_diagnostic() -> void:
	DirAccess.make_dir_recursive_absolute(TEMP_SAVE_DIR)
	var source_library: PlayerForgeWipLibraryState = PlayerForgeWipLibraryStateScript.load_or_create()
	var source_wip: CraftedItemWIP = _find_saved_wip_by_project_name(source_library, TARGET_PROJECT_NAME)
	result_lines.append("target_project_name=%s" % TARGET_PROJECT_NAME)
	result_lines.append("source_library_loaded=%s" % str(source_library != null))
	result_lines.append("source_wip_found=%s" % str(source_wip != null))
	if source_wip == null:
		_write_results()
		quit()
		return
	for scenario: Dictionary in SCENARIOS:
		await _run_scenario(source_wip, scenario)
	_write_results()
	quit()

func _run_scenario(source_wip: CraftedItemWIP, scenario: Dictionary) -> void:
	var scenario_name: String = String(scenario.get("name", "unnamed"))
	var fake_player := FakePlayer.new()
	var temp_library: PlayerForgeWipLibraryState = _build_temp_library(source_wip, scenario_name)
	fake_player.forge_wip_library_state = temp_library
	root.add_child(fake_player)

	var ui: CombatAnimationStationUI = CombatAnimationStationUIScene.instantiate() as CombatAnimationStationUI
	root.add_child(ui)
	await process_frame
	ui.open_for(fake_player, "Combat Idle Authority Intervention Diagnostic")
	await _wait_frames(6)
	var select_idle_mode_ok: bool = ui.select_authoring_mode(CombatAnimationStationStateScript.AUTHORING_MODE_IDLE)
	await _wait_frames(3)
	var select_combat_idle_ok: bool = ui.select_draft(CombatAnimationStationStateScript.IDLE_CONTEXT_COMBAT, true)
	await _wait_frames(3)

	result_lines.append("")
	result_lines.append("[%s]" % scenario_name)
	result_lines.append("select_idle_mode_ok=%s" % str(select_idle_mode_ok))
	result_lines.append("select_combat_idle_ok=%s" % str(select_combat_idle_ok))
	result_lines.append("active_draft_identifier=%s" % String(ui.get_active_draft_identifier()))
	for reset_index: int in range(RESET_COUNT):
		var reset_ok: bool = ui.reset_active_draft_to_baseline()
		result_lines.append("reset_%d_ok=%s" % [reset_index + 1, str(reset_ok)])
		await _wait_frames(2)
		if reset_index < RESET_COUNT - 1:
			await _wait_seconds(WAIT_SECONDS_BETWEEN_RESETS)

	_apply_intervention(ui, scenario)
	await _wait_frames(2)
	var stats: Dictionary = await _observe(ui, OBSERVE_SECONDS_AFTER_FINAL_RESET)
	result_lines.append_array(_build_stat_lines(stats))
	result_lines.append_array(_build_final_debug_lines(ui))

	ui.queue_free()
	fake_player.queue_free()
	await _wait_frames(4)

func _build_temp_library(source_wip: CraftedItemWIP, scenario_name: String) -> PlayerForgeWipLibraryState:
	var temp_library: PlayerForgeWipLibraryState = PlayerForgeWipLibraryStateScript.new()
	temp_library.save_file_path = "%s/diagnose_combat_idle_authority_%s.tres" % [TEMP_SAVE_DIR, scenario_name]
	temp_library.saved_wips.clear()
	var diagnostic_wip: CraftedItemWIP = source_wip.duplicate(true) as CraftedItemWIP
	diagnostic_wip.ensure_combat_animation_station_state()
	temp_library.saved_wips.append(diagnostic_wip)
	temp_library.selected_wip_id = diagnostic_wip.wip_id
	temp_library.persist()
	return temp_library

func _apply_intervention(ui: CombatAnimationStationUI, scenario: Dictionary) -> void:
	var actor: Node3D = _get_preview_actor(ui)
	if bool(scenario.get("clear_guidance", false)) and actor != null:
		if actor.has_method("clear_arm_guidance_target"):
			actor.call("clear_arm_guidance_target", &"hand_right")
			actor.call("clear_arm_guidance_target", &"hand_left")
		if actor.has_method("clear_arm_guidance_active"):
			actor.call("clear_arm_guidance_active", &"hand_right")
			actor.call("clear_arm_guidance_active", &"hand_left")
	if bool(scenario.get("freeze_actor_process", false)) and actor != null:
		actor.set_process(false)
	if bool(scenario.get("freeze_station_process", false)):
		ui.set_process(false)

func _observe(ui: CombatAnimationStationUI, seconds: float) -> Dictionary:
	var stats: Dictionary = {}
	var elapsed: float = 0.0
	while elapsed < seconds:
		await create_timer(SAMPLE_INTERVAL_SECONDS).timeout
		elapsed += SAMPLE_INTERVAL_SECONDS
		_sample_ui(ui, stats)
	stats["observed_seconds"] = elapsed
	return stats

func _sample_ui(ui: CombatAnimationStationUI, stats: Dictionary) -> void:
	var actor: Node3D = _get_preview_actor(ui)
	var held_item: Node3D = _get_preview_held_item(ui)
	var skeleton: Skeleton3D = actor.get_node_or_null("JosieModel/Josie/Skeleton3D") as Skeleton3D if actor != null else null
	var right_ik: Node3D = actor.get_node_or_null("IkTargets/RightHandIkTarget") as Node3D if actor != null else null
	var left_ik: Node3D = actor.get_node_or_null("IkTargets/LeftHandIkTarget") as Node3D if actor != null else null
	var primary_grip_anchor: Node3D = held_item.find_child("PrimaryGripAnchor", true, false) as Node3D if held_item != null else null
	_record_vector(stats, "weapon_position", held_item.global_position if held_item != null else Vector3.ZERO)
	_record_vector(stats, "primary_grip_anchor", primary_grip_anchor.global_position if primary_grip_anchor != null else Vector3.ZERO)
	_record_vector(stats, "right_hand_bone", _get_bone_world_position(skeleton, "CC_Base_R_Hand"))
	_record_vector(stats, "left_hand_bone", _get_bone_world_position(skeleton, "CC_Base_L_Hand"))
	_record_vector(stats, "right_ik_target", right_ik.global_position if right_ik != null else Vector3.ZERO)
	_record_vector(stats, "left_ik_target", left_ik.global_position if left_ik != null else Vector3.ZERO)
	if held_item != null:
		_record_basis(stats, "weapon_basis", held_item.global_basis)
	if skeleton != null:
		_record_basis(stats, "right_hand_basis", _get_bone_world_basis(skeleton, "CC_Base_R_Hand"))

func _record_vector(stats: Dictionary, key: String, value: Vector3) -> void:
	var previous_key := "%s_previous" % key
	var stat_key := "%s_stat" % key
	var stat: Dictionary = stats.get(stat_key, {}) as Dictionary
	var count: int = int(stat.get("count", 0))
	if count <= 0:
		stat["min"] = value
		stat["max"] = value
	else:
		stat["min"] = _min_vec(stat.get("min", value) as Vector3, value)
		stat["max"] = _max_vec(stat.get("max", value) as Vector3, value)
	if stats.has(previous_key):
		var delta: float = (stats.get(previous_key, value) as Vector3).distance_to(value)
		stat["sum_step"] = float(stat.get("sum_step", 0.0)) + delta
		stat["max_step"] = maxf(float(stat.get("max_step", 0.0)), delta)
	stat["count"] = count + 1
	stats[stat_key] = stat
	stats[previous_key] = value

func _record_basis(stats: Dictionary, key: String, value: Basis) -> void:
	var previous_key := "%s_previous" % key
	var stat_key := "%s_stat" % key
	var stat: Dictionary = stats.get(stat_key, {}) as Dictionary
	var count: int = int(stat.get("count", 0))
	if stats.has(previous_key):
		var delta_degrees: float = _basis_delta_degrees(stats.get(previous_key, value) as Basis, value)
		stat["sum_step_degrees"] = float(stat.get("sum_step_degrees", 0.0)) + delta_degrees
		stat["max_step_degrees"] = maxf(float(stat.get("max_step_degrees", 0.0)), delta_degrees)
	stat["count"] = count + 1
	stats[stat_key] = stat
	stats[previous_key] = value

func _build_stat_lines(stats: Dictionary) -> PackedStringArray:
	var lines: PackedStringArray = []
	lines.append("observed_seconds=%.4f" % float(stats.get("observed_seconds", 0.0)))
	for key: String in [
		"weapon_position",
		"primary_grip_anchor",
		"right_hand_bone",
		"left_hand_bone",
		"right_ik_target",
		"left_ik_target",
	]:
		var stat: Dictionary = stats.get("%s_stat" % key, {}) as Dictionary
		var count: int = int(stat.get("count", 0))
		var min_value: Vector3 = stat.get("min", Vector3.ZERO) as Vector3
		var max_value: Vector3 = stat.get("max", Vector3.ZERO) as Vector3
		lines.append("%s_range_meters=%.6f" % [key, (max_value - min_value).length()])
		lines.append("%s_max_step_meters=%.6f" % [key, float(stat.get("max_step", 0.0))])
		lines.append("%s_average_step_meters=%.6f" % [key, float(stat.get("sum_step", 0.0)) / maxf(float(count - 1), 1.0)])
	for key: String in ["weapon_basis", "right_hand_basis"]:
		var stat: Dictionary = stats.get("%s_stat" % key, {}) as Dictionary
		var count: int = int(stat.get("count", 0))
		lines.append("%s_max_step_degrees=%.6f" % [key, float(stat.get("max_step_degrees", 0.0))])
		lines.append("%s_average_step_degrees=%.6f" % [key, float(stat.get("sum_step_degrees", 0.0)) / maxf(float(count - 1), 1.0)])
	return lines

func _build_final_debug_lines(ui: CombatAnimationStationUI) -> PackedStringArray:
	var lines: PackedStringArray = []
	var final_debug: Dictionary = ui.get_preview_debug_state()
	var final_grip_debug: Dictionary = final_debug.get("grip_contact_debug_state", {}) as Dictionary
	lines.append("final_dominant_grip_alignment_error_meters=%.6f" % float(final_debug.get("dominant_grip_alignment_error_meters", -1.0)))
	lines.append("final_support_grip_alignment_error_meters=%.6f" % float(final_debug.get("support_grip_alignment_error_meters", -1.0)))
	lines.append("final_right_arm_guidance_active=%s" % str(bool(final_grip_debug.get("right_arm_guidance_active", false))))
	lines.append("final_left_arm_guidance_active=%s" % str(bool(final_grip_debug.get("left_arm_guidance_active", false))))
	lines.append("final_right_arm_ik_active=%s" % str(bool(final_grip_debug.get("right_arm_ik_active", false))))
	lines.append("final_left_arm_ik_active=%s" % str(bool(final_grip_debug.get("left_arm_ik_active", false))))
	return lines

func _get_preview_actor(ui: CombatAnimationStationUI) -> Node3D:
	var preview_root: Node3D = _get_preview_root(ui)
	return preview_root.get_node_or_null("PreviewActorPivot/PreviewActor") as Node3D if preview_root != null else null

func _get_preview_held_item(ui: CombatAnimationStationUI) -> Node3D:
	var preview_root: Node3D = _get_preview_root(ui)
	return preview_root.get_meta("preview_held_item", null) as Node3D if preview_root != null else null

func _get_preview_root(ui: CombatAnimationStationUI) -> Node3D:
	if ui == null or ui.preview_subviewport == null:
		return null
	return ui.preview_subviewport.get_node_or_null("CombatAnimationPreviewRoot3D") as Node3D

func _wait_frames(frame_count: int) -> void:
	for _frame_index: int in range(maxi(frame_count, 0)):
		await process_frame

func _wait_seconds(seconds: float) -> void:
	var elapsed: float = 0.0
	while elapsed < seconds:
		await create_timer(SAMPLE_INTERVAL_SECONDS).timeout
		elapsed += SAMPLE_INTERVAL_SECONDS

func _find_saved_wip_by_project_name(library_state: PlayerForgeWipLibraryState, project_name: String) -> CraftedItemWIP:
	if library_state == null:
		return null
	for saved_wip: CraftedItemWIP in library_state.get_saved_wips():
		if saved_wip != null and saved_wip.forge_project_name == project_name:
			return saved_wip
	return null

func _get_bone_world_position(skeleton: Skeleton3D, bone_name: String) -> Vector3:
	if skeleton == null:
		return Vector3.ZERO
	var bone_index: int = skeleton.find_bone(bone_name)
	if bone_index < 0:
		return Vector3.ZERO
	return skeleton.to_global(skeleton.get_bone_global_pose(bone_index).origin)

func _get_bone_world_basis(skeleton: Skeleton3D, bone_name: String) -> Basis:
	if skeleton == null:
		return Basis.IDENTITY
	var bone_index: int = skeleton.find_bone(bone_name)
	if bone_index < 0:
		return Basis.IDENTITY
	return (skeleton.global_basis * skeleton.get_bone_global_pose(bone_index).basis).orthonormalized()

func _basis_delta_degrees(first: Basis, second: Basis) -> float:
	return maxf(
		_axis_delta_degrees(first.x, second.x),
		maxf(
			_axis_delta_degrees(first.y, second.y),
			_axis_delta_degrees(first.z, second.z)
		)
	)

func _axis_delta_degrees(first: Vector3, second: Vector3) -> float:
	if first.length_squared() <= 0.000001 or second.length_squared() <= 0.000001:
		return 0.0
	return rad_to_deg(acos(clampf(first.normalized().dot(second.normalized()), -1.0, 1.0)))

func _min_vec(first: Vector3, second: Vector3) -> Vector3:
	return Vector3(minf(first.x, second.x), minf(first.y, second.y), minf(first.z, second.z))

func _max_vec(first: Vector3, second: Vector3) -> Vector3:
	return Vector3(maxf(first.x, second.x), maxf(first.y, second.y), maxf(first.z, second.z))

func _write_results() -> void:
	var file: FileAccess = FileAccess.open(RESULT_FILE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(result_lines))
		file.close()
