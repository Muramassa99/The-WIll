extends SceneTree

const ForgeGridControllerScript = preload("res://runtime/forge/forge_grid_controller.gd")
const PlayerForgeWipLibraryStateScript = preload("res://core/models/player_forge_wip_library_state.gd")
const PlayerScene = preload("res://scenes/player/player_character.tscn")

const RESULT_FILE_PATH := "C:/WORKSPACE/workspace debug home/selected_grip_layout_results.txt"

var lines: PackedStringArray = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(RESULT_FILE_PATH.get_base_dir())
	var library_state: PlayerForgeWipLibraryState = PlayerForgeWipLibraryStateScript.load_or_create()
	lines.append("diagnostic=selected_grip_layout")
	lines.append("library_loaded=%s" % str(library_state != null))
	if library_state == null:
		_write_and_quit()
		return

	var selected_id: StringName = library_state.selected_wip_id
	var selected_wip: CraftedItemWIP = library_state.get_saved_wip(selected_id)
	lines.append("selected_wip_id=%s" % String(selected_id))
	lines.append("selected_found=%s" % str(selected_wip != null))
	if selected_wip == null:
		_write_and_quit()
		return

	lines.append("selected_project_name=%s" % selected_wip.forge_project_name)
	lines.append("selected_forge_intent=%s" % String(selected_wip.forge_intent))
	lines.append("selected_equipment_context=%s" % String(selected_wip.equipment_context))

	var controller: ForgeGridController = ForgeGridControllerScript.new()
	var profile: BakedProfile = controller.get_forge_service().bake_wip(selected_wip, controller.build_default_material_lookup())
	controller.free()
	_append_profile_lines(profile)

	var player_root: Node = PlayerScene.instantiate()
	root.add_child(player_root)
	await process_frame
	await process_frame
	var player := player_root as PlayerController3D
	if player != null:
		player.forge_wip_library_state = library_state
		var layout: Dictionary = player.preview_saved_wip_grip_hold_layout(selected_id, &"hand_right")
		lines.append("layout_valid=%s" % str(bool(layout.get("valid", false))))
		lines.append("layout_center_balance_valid=%s" % str(bool(layout.get("center_balance_valid", false))))
		lines.append("layout_dominant_axis_ratio=%s" % _fmt_float(float(layout.get("dominant_hand_axis_ratio_from_span_start", 0.0))))
		lines.append("layout_support_axis_ratio=%s" % _fmt_float(float(layout.get("support_hand_axis_ratio_from_span_start", 0.0))))
		lines.append("layout_dominant_position=%s" % _fmt_vec(layout.get("dominant_hand_local_position", Vector3.ZERO)))
		lines.append("layout_support_position=%s" % _fmt_vec(layout.get("support_hand_local_position", Vector3.ZERO)))
	else:
		lines.append("player_loaded=false")

	_write_and_quit()

func _append_profile_lines(profile: BakedProfile) -> void:
	lines.append("profile_baked=%s" % str(profile != null))
	if profile == null:
		return
	lines.append("profile_validation_error=%s" % profile.validation_error)
	lines.append("profile_center_of_mass=%s" % _fmt_vec(profile.center_of_mass))
	lines.append("profile_primary_grip_valid=%s" % str(profile.primary_grip_valid))
	lines.append("profile_primary_grip_span_start=%s" % _fmt_vec(profile.primary_grip_span_start))
	lines.append("profile_primary_grip_span_end=%s" % _fmt_vec(profile.primary_grip_span_end))
	lines.append("profile_primary_grip_axis_ratio_from_span_start=%s" % _fmt_float(profile.primary_grip_axis_ratio_from_span_start))
	lines.append("profile_primary_grip_contact_position=%s" % _fmt_vec(profile.primary_grip_contact_position))
	lines.append("profile_primary_grip_center_balance_valid=%s" % str(profile.primary_grip_center_balance_valid))
	lines.append("profile_primary_grip_center_balance_offset_percent=%s" % _fmt_float(profile.primary_grip_center_balance_offset_percent))
	lines.append("profile_primary_grip_center_balance_origin=%s" % _fmt_vec(profile.primary_grip_center_balance_origin))
	lines.append("profile_primary_grip_two_hand_eligible=%s" % str(profile.primary_grip_two_hand_eligible))

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
