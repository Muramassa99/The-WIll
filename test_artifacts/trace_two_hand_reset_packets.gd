extends SceneTree

const LibraryScript = preload("res://core/models/player_forge_wip_library_state.gd")
const UIScene = preload("res://scenes/ui/combat_animation_station_ui.tscn")
const TARGET_PROJECT_NAME := "Star_Handle_Testing"
const TARGET_SLOT_ID: StringName = &"skill_slot_1"

class FakePlayer:
	extends Node
	var forge_wip_library_state: PlayerForgeWipLibraryState = null
	func get_forge_wip_library_state() -> PlayerForgeWipLibraryState:
		return forge_wip_library_state
	func set_ui_mode_enabled(_enabled: bool) -> void:
		pass

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var source_library: PlayerForgeWipLibraryState = LibraryScript.load_or_create()
	var source_wip: CraftedItemWIP = null
	for candidate: CraftedItemWIP in source_library.get_saved_wips():
		if candidate != null and candidate.forge_project_name == TARGET_PROJECT_NAME:
			source_wip = candidate
			break
	if source_wip == null:
		print("missing_wip")
		quit(1)
		return
	var diagnostic_wip := source_wip.duplicate(true) as CraftedItemWIP
	var diagnostic_library := LibraryScript.new() as PlayerForgeWipLibraryState
	diagnostic_library.saved_wips.clear()
	diagnostic_library.saved_wips.append(diagnostic_wip)
	diagnostic_library.selected_wip_id = diagnostic_wip.wip_id
	var fake := FakePlayer.new()
	fake.forge_wip_library_state = diagnostic_library
	root.add_child(fake)
	var ui := UIScene.instantiate() as CombatAnimationStationUI
	root.add_child(ui)
	await _frames(2)
	ui.open_for(fake, "trace")
	await _frames(2)
	print("open_one=", ui.open_saved_wip_with_hand_setup(diagnostic_wip.wip_id, &"hand_right", false, false))
	await _frames(2)
	print("select_one=", ui.select_skill_slot(TARGET_SLOT_ID, true))
	await _frames(2)
	print("reset_one=", ui.reset_active_draft_to_baseline())
	await _frames(2)
	_dump(ui, "one_after_reset")
	var skip_roll: bool = OS.get_cmdline_user_args().has("skip_roll")
	if not skip_roll:
		print("roll_plus_20=", ui.set_selected_motion_node_weapon_roll(20.0, false, false, true, true, false))
		await _frames(1)
		print("roll_zero=", ui.set_selected_motion_node_weapon_roll(0.0, false, false, true, true, false))
		await _frames(1)
		print("roll_minus_20=", ui.set_selected_motion_node_weapon_roll(-20.0, false, false, true, true, false))
		await _frames(1)
		ui.call("_refresh_preview_scene")
	_dump(ui, "one_after_roll_sequence")
	print("open_two=", ui.open_saved_wip_with_hand_setup(diagnostic_wip.wip_id, &"hand_right", true, false))
	await _frames(2)
	_dump(ui, "two_after_open")
	print("select_two=", ui.select_skill_slot(TARGET_SLOT_ID, true))
	await _frames(2)
	_dump(ui, "two_after_select")
	print("reset_two=", ui.reset_active_draft_to_baseline())
	_dump(ui, "two_immediate_after_reset")
	await _frames(2)
	_dump(ui, "two_reset_plus_2_frames")
	quit()

func _dump(ui: CombatAnimationStationUI, label: String) -> void:
	var preview_root := ui.preview_subviewport.get_node_or_null("CombatAnimationPreviewRoot3D") as Node3D
	var actor := preview_root.get_node_or_null("PreviewActorPivot/PreviewActor") as Node3D if preview_root != null else null
	var held := preview_root.get_meta("preview_held_item", null) as Node3D if preview_root != null else null
	print("===", label, "===")
	if actor == null:
		print("actor_missing")
		return
	var finger = actor.get("finger_grip_presenter")
	for slot: StringName in [&"hand_right", &"hand_left"]:
		print(String(slot), " support=", actor.call("is_support_hand_active", slot))
		var seat: Dictionary = actor.call("get_authoring_committed_weapon_surface_seat", slot)
		var seat_debug: Dictionary = actor.call("get_weapon_surface_seat_debug_state", slot)
		print(String(slot), " seat_valid=", seat.get("valid", false), " seat_status=", seat.get("status", &""))
		print(String(slot), " seat_debug_valid=", seat_debug.get("valid", false), " seat_debug_status=", seat_debug.get("status", &""), " seat_diag_status=", (seat_debug.get("diagnostics", {}) as Dictionary).get("status", &""))
		if finger != null:
			var grasp: Dictionary = finger.call("get_surface_grasp_debug_state", slot)
			var packet: Dictionary = finger.call("get_committed_surface_grasp_zero_packet", slot)
			print(String(slot), " grasp_valid=", grasp.get("valid", false), " grasp_status=", grasp.get("status", &""), " grasp_last_request=", grasp.get("last_request_status", &""), " grasp_last_rejected=", grasp.get("last_rejected_status", &""), " rotations=", (grasp.get("rotations", {}) as Dictionary).size())
			var grasp_diag: Dictionary = grasp.get("diagnostics", {})
			print(String(slot), " grasp_diag_status=", grasp_diag.get("status", &""), " solved_digits=", grasp_diag.get("solved_digit_count", -1), " unsafe_digits=", grasp_diag.get("unsafe_digit_count", -1), " max_contact_error=", grasp_diag.get("max_contact_error_meters", -1.0), " max_penetration=", grasp_diag.get("max_penetration_meters", -1.0), " overlap_ok=", grasp_diag.get("overlap_limit_respected", false), " writes=", grasp_diag.get("writes_performed", -1))
			print(String(slot), " zero_packet_valid=", packet.get("valid", false), " zero_packet_status=", packet.get("status", &""))
		var seat_diag: Dictionary = seat_debug.get("diagnostics", {})
		var seat_best: Dictionary = seat_diag.get("best_overall", {})
		print(String(slot), " seat_iterations=", seat_diag.get("completed_iterations", -1), " seat_max_abs_radial=", seat_best.get("max_abs_radial_error_meters", -1.0), " seat_index_radial=", seat_best.get("index_radial_error_meters", -1.0), " seat_pinky_radial=", seat_best.get("pinky_radial_error_meters", -1.0), " seat_index_safe=", seat_best.get("index_authority_proximal_safe", false), " seat_pinky_safe=", seat_best.get("pinky_authority_proximal_safe", false), " ordinary_safe=", seat_best.get("ordinary_proximal_capsules_safe", false))
	if held != null:
		var held_dominant: Dictionary = held.get_meta("weapon_surface_seat_state", {})
		var held_support: Dictionary = held.get_meta("support_hand_surface_seat_state", {})
		print("held_dominant_seat_valid=", held_dominant.get("valid", false), " status=", held_dominant.get("status", &""), " applied=", held_dominant.get("applied", false), " primary_support_handoff=", held_dominant.get("committed_primary_seat_reused_for_support_activation", false))
		print("held_support_seat_valid=", held_support.get("valid", false), " status=", held_support.get("status", &""), " applied=", held_support.get("applied", false))
	var roll: Dictionary = preview_root.get_meta("weapon_roll_contact_result", {})
	print("roll_applied=", roll.get("applied", false), " status=", roll.get("status", &""), " dominant_digits=", roll.get("dominant_digits_restored", false), " support_digits=", roll.get("support_digits_restored", false))
	var dbg: Dictionary = ui.get_preview_debug_state()
	print("align_dominant=", dbg.get("dominant_grip_alignment_error_meters", -1.0), " align_support=", dbg.get("support_grip_alignment_error_meters", -1.0))
	var two_hand: Dictionary = actor.get("last_two_hand_solve_result")
	var motion_node: Resource = ui.call("_get_active_motion_node") as Resource
	if motion_node != null:
		print("motion primary_coord=", motion_node.get("grip_seat_slide_offset"), " support_coord=", motion_node.get("secondary_grip_seat_slide_offset"), " axial=", motion_node.get("axial_reposition_offset"), " two_hand=", motion_node.get("two_hand_state"), " primary_slot=", motion_node.get("primary_hand_slot"))
	if held != null:
		print("held tip_side_ratio=", held.get_meta("primary_grip_handle_tip_side_axis_ratio_from_span_start", -1.0), " primary_ratio=", held.get_meta("preview_primary_grip_seat_ratio_from_span_start", -1.0), " support_ratio=", held.get_meta("preview_support_grip_seat_ratio_from_span_start", -1.0))
		for node_path: String in ["PrimaryGripGuide", "SecondaryGripGuide", "PrimaryGripGuide/PrimaryGripAnchor", "SecondaryGripGuide/SupportGripAnchor"]:
			var anchor := held.get_node_or_null(node_path) as Node3D
			if anchor != null:
				print(node_path, " local=", anchor.position, " world=", anchor.global_position)
	var skeleton := actor.get_node_or_null("Armature/Skeleton3D") as Skeleton3D
	if skeleton == null:
		skeleton = actor.find_child("Skeleton3D", true, false) as Skeleton3D
	if skeleton != null:
		for bone_name: StringName in [&"CC_Base_R_Clavicle", &"CC_Base_R_Upperarm", &"CC_Base_R_Forearm", &"CC_Base_R_Hand", &"CC_Base_L_Clavicle", &"CC_Base_L_Upperarm", &"CC_Base_L_Forearm", &"CC_Base_L_Hand"]:
			var bone_index := skeleton.find_bone(String(bone_name))
			if bone_index >= 0:
				print(String(bone_name), " world=", skeleton.global_transform * skeleton.get_bone_global_pose(bone_index).origin)
	for solve_slot: StringName in [&"hand_right", &"hand_left"]:
		var slot_solve: Dictionary = two_hand.get(solve_slot, {})
		var desired: Vector3 = slot_solve.get("desired_target", Vector3.ZERO)
		var corrected: Vector3 = slot_solve.get("corrected_target", Vector3.ZERO)
		print(String(solve_slot), " arm_active=", slot_solve.get("active", false), " path_illegal=", slot_solve.get("path_illegal", false), " point_illegal=", slot_solve.get("point_illegal", false), " front_bias_failed=", slot_solve.get("front_bias_failed", false), " used_orbit=", slot_solve.get("used_orbit", false), " alt_disabled=", slot_solve.get("alternate_target_correction_disabled", false), " reach_clamped=", slot_solve.get("arm_reach_clamped", false), " reach_before=", slot_solve.get("arm_reach_before_meters", -1.0), " reach_after=", slot_solve.get("arm_reach_after_meters", -1.0), " reach_limit=", slot_solve.get("arm_reach_limit_meters", -1.0), " desired_corrected_delta=", desired.distance_to(corrected))

func _frames(count: int) -> void:
	for _i: int in range(count):
		await process_frame
