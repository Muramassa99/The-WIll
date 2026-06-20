extends SceneTree

const ForgeGridControllerScript = preload("res://runtime/forge/forge_grid_controller.gd")
const PlayerForgeWipLibraryStateScript = preload("res://core/models/player_forge_wip_library_state.gd")
const PlayerScene = preload("res://scenes/player/player_character.tscn")

const TARGET_PROJECT_NAME := "Long Glave  Animation  Test"
const RESULT_FILE_PATH := "C:/WORKSPACE/workspace debug home/glave_grip_layout_results.txt"

var lines: PackedStringArray = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(RESULT_FILE_PATH.get_base_dir())
	var library_state: PlayerForgeWipLibraryState = PlayerForgeWipLibraryStateScript.load_or_create()
	lines.append("diagnostic=glave_grip_layout")
	lines.append("target_project_name=%s" % TARGET_PROJECT_NAME)
	lines.append("library_loaded=%s" % str(library_state != null))
	if library_state == null:
		_write_and_quit()
		return

	lines.append("selected_wip_id=%s" % String(library_state.selected_wip_id))
	lines.append("saved_wip_count=%d" % library_state.get_saved_wips().size())
	var target_wip: CraftedItemWIP = _find_saved_wip_by_project_name(library_state, TARGET_PROJECT_NAME)
	lines.append("target_found=%s" % str(target_wip != null))
	if target_wip == null:
		_write_and_quit()
		return

	lines.append("target_wip_id=%s" % String(target_wip.wip_id))
	lines.append("target_forge_intent=%s" % String(target_wip.forge_intent))
	lines.append("target_equipment_context=%s" % String(target_wip.equipment_context))
	lines.append("target_grip_style=%s" % String(target_wip.grip_style_mode))

	var controller: ForgeGridController = ForgeGridControllerScript.new()
	var profile: BakedProfile = controller.get_forge_service().bake_wip(target_wip, controller.build_default_material_lookup())
	var cell_world_size_meters: float = controller.get_cell_world_size_meters()
	lines.append("cell_world_size_meters=%s" % _fmt_float(cell_world_size_meters))
	controller.free()

	_append_profile_lines(profile)

	var player_root: Node = PlayerScene.instantiate()
	root.add_child(player_root)
	await process_frame
	await process_frame
	var player := player_root as PlayerController3D
	if player != null:
		player.forge_wip_library_state = library_state
		var right_layout: Dictionary = player.preview_saved_wip_grip_hold_layout(target_wip.wip_id, &"hand_right")
		var left_layout: Dictionary = player.preview_saved_wip_grip_hold_layout(target_wip.wip_id, &"hand_left")
		_append_layout_lines("right", right_layout)
		_append_layout_lines("left", left_layout)
	else:
		lines.append("player_loaded=false")

	_write_and_quit()

func _find_saved_wip_by_project_name(library_state: PlayerForgeWipLibraryState, project_name: String) -> CraftedItemWIP:
	for saved_wip: CraftedItemWIP in library_state.get_saved_wips():
		if saved_wip == null:
			continue
		if saved_wip.forge_project_name == project_name:
			return saved_wip
	return null

func _append_profile_lines(profile: BakedProfile) -> void:
	lines.append("profile_baked=%s" % str(profile != null))
	if profile == null:
		return
	lines.append("profile_validation_error=%s" % profile.validation_error)
	lines.append("profile_total_mass=%s" % _fmt_float(profile.total_mass))
	lines.append("profile_center_of_mass=%s" % _fmt_vec(profile.center_of_mass))
	lines.append("profile_primary_grip_valid=%s" % str(profile.primary_grip_valid))
	lines.append("profile_primary_grip_contact_position=%s" % _fmt_vec(profile.primary_grip_contact_position))
	lines.append("profile_primary_grip_offset=%s" % _fmt_vec(profile.primary_grip_offset))
	lines.append("profile_primary_grip_span_start=%s" % _fmt_vec(profile.primary_grip_span_start))
	lines.append("profile_primary_grip_span_end=%s" % _fmt_vec(profile.primary_grip_span_end))
	lines.append("profile_primary_grip_span_length_voxels=%d" % profile.primary_grip_span_length_voxels)
	lines.append("profile_primary_grip_slide_axis=%s" % _fmt_vec(profile.primary_grip_slide_axis))
	lines.append("profile_primary_grip_axis_ratio_from_span_start=%s" % _fmt_float(profile.primary_grip_axis_ratio_from_span_start))
	lines.append("profile_primary_grip_contact_percent=%s" % _fmt_float(profile.primary_grip_contact_percent))
	lines.append("profile_primary_grip_com_side_position=%s" % _fmt_vec(profile.primary_grip_com_side_position))
	lines.append("profile_primary_grip_far_side_position=%s" % _fmt_vec(profile.primary_grip_far_side_position))
	lines.append("profile_primary_grip_center_balance_valid=%s" % str(profile.primary_grip_center_balance_valid))
	lines.append("profile_primary_grip_center_balance_origin=%s" % _fmt_vec(profile.primary_grip_center_balance_origin))
	lines.append("profile_primary_grip_center_balance_offset_percent=%s" % _fmt_float(profile.primary_grip_center_balance_offset_percent))
	lines.append("profile_primary_grip_two_hand_eligible=%s" % str(profile.primary_grip_two_hand_eligible))
	lines.append("profile_primary_grip_two_hand_negative_limit=%s" % _fmt_float(profile.primary_grip_two_hand_negative_limit))
	lines.append("profile_primary_grip_two_hand_positive_limit=%s" % _fmt_float(profile.primary_grip_two_hand_positive_limit))
	lines.append("profile_front_heavy_score=%s" % _fmt_float(profile.front_heavy_score))
	lines.append("profile_balance_score=%s" % _fmt_float(profile.balance_score))
	lines.append("profile_reach=%s" % _fmt_float(profile.reach))
	lines.append("profile_weapon_total_length_meters=%s" % _fmt_float(profile.weapon_total_length_meters))
	lines.append("profile_weapon_tip_point=%s" % _fmt_vec(profile.weapon_tip_point))
	lines.append("profile_weapon_pommel_point=%s" % _fmt_vec(profile.weapon_pommel_point))

func _append_layout_lines(prefix: String, layout: Dictionary) -> void:
	lines.append("%s_layout_valid=%s" % [prefix, str(bool(layout.get("valid", false)))])
	lines.append("%s_layout_center_balance_valid=%s" % [prefix, str(bool(layout.get("center_balance_valid", false)))])
	lines.append("%s_layout_two_hand_weapon_eligible=%s" % [prefix, str(bool(layout.get("two_hand_weapon_eligible", false)))])
	lines.append("%s_layout_two_hand_character_eligible=%s" % [prefix, str(bool(layout.get("two_hand_character_eligible", false)))])
	lines.append("%s_layout_dominant_slot_id=%s" % [prefix, String(layout.get("dominant_slot_id", StringName()))])
	lines.append("%s_layout_support_slot_id=%s" % [prefix, String(layout.get("support_slot_id", StringName()))])
	lines.append("%s_layout_dominant_hand_local_position=%s" % [prefix, _fmt_vec(layout.get("dominant_hand_local_position", Vector3.ZERO))])
	lines.append("%s_layout_support_hand_local_position=%s" % [prefix, _fmt_vec(layout.get("support_hand_local_position", Vector3.ZERO))])
	lines.append("%s_layout_dominant_axis_ratio=%s" % [prefix, _fmt_float(float(layout.get("dominant_hand_axis_ratio_from_span_start", 0.0)))])
	lines.append("%s_layout_support_axis_ratio=%s" % [prefix, _fmt_float(float(layout.get("support_hand_axis_ratio_from_span_start", 0.0)))])
	lines.append("%s_layout_dominant_contact_percent=%s" % [prefix, _fmt_float(float(layout.get("dominant_hand_contact_percent", 0.0)))])
	lines.append("%s_layout_support_contact_percent=%s" % [prefix, _fmt_float(float(layout.get("support_hand_contact_percent", 0.0)))])
	lines.append("%s_layout_dominant_signed_ratio=%s" % [prefix, _fmt_float(float(layout.get("dominant_hand_signed_ratio", 0.0)))])
	lines.append("%s_layout_support_signed_ratio=%s" % [prefix, _fmt_float(float(layout.get("support_hand_signed_ratio", 0.0)))])
	lines.append("%s_layout_weapon_two_hand_span_meters=%s" % [prefix, _fmt_float(float(layout.get("weapon_two_hand_span_meters", 0.0)))])
	lines.append("%s_layout_effective_two_hand_span_meters=%s" % [prefix, _fmt_float(float(layout.get("effective_two_hand_span_meters", 0.0)))])

func _fmt_vec(value: Vector3) -> String:
	return "(%.6f, %.6f, %.6f)" % [value.x, value.y, value.z]

func _fmt_float(value: float) -> String:
	return "%.6f" % value

func _write_and_quit() -> void:
	var file := FileAccess.open(RESULT_FILE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()
	quit()
