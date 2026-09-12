extends SceneTree

const LibraryScript = preload("res://core/models/player_forge_wip_library_state.gd")
const UIScene = preload("res://scenes/ui/combat_animation_station_ui.tscn")
const MotionNodeScript = preload("res://core/models/combat_animation_motion_node.gd")

class FakePlayer:
	extends Node
	var forge_wip_library_state: PlayerForgeWipLibraryState
	func get_forge_wip_library_state() -> PlayerForgeWipLibraryState:
		return forge_wip_library_state
	func set_ui_mode_enabled(_enabled: bool) -> void:
		pass

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var source_library: PlayerForgeWipLibraryState = LibraryScript.load_or_create()
	var source_wip: CraftedItemWIP
	for candidate: CraftedItemWIP in source_library.get_saved_wips():
		if candidate != null and candidate.forge_project_name == "Star_Handle_Testing":
			source_wip = candidate
			break
	var wip := source_wip.duplicate(true) as CraftedItemWIP
	var library := LibraryScript.new() as PlayerForgeWipLibraryState
	library.saved_wips.append(wip)
	library.selected_wip_id = wip.wip_id
	var fake := FakePlayer.new()
	fake.forge_wip_library_state = library
	root.add_child(fake)
	var ui := UIScene.instantiate() as CombatAnimationStationUI
	root.add_child(ui)
	await _frames(2)
	ui.open_for(fake, "trace")
	await _frames(2)
	ui.open_saved_wip_with_hand_setup(wip.wip_id, &"hand_right", false, false)
	await _frames(2)
	ui.select_skill_slot(&"skill_slot_1", true)
	await _frames(2)
	ui.reset_active_draft_to_baseline()
	await _frames(1)
	_dump(ui, "one_reset")
	ui.set_selected_motion_node_two_hand_state(MotionNodeScript.TWO_HAND_STATE_TWO_HAND, false, false, false, true, false)
	await _frames(1)
	_dump(ui, "toggle_two")
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		ui.set_selected_motion_node_secondary_grip_seat_slide(float(args[0]), false, false, false, true, false)
		await _frames(1)
		_dump(ui, "support_coord_" + args[0])
	quit()

func _dump(ui: CombatAnimationStationUI, label: String) -> void:
	var preview_root := ui.preview_subviewport.get_node_or_null("CombatAnimationPreviewRoot3D") as Node3D
	var actor := preview_root.get_node_or_null("PreviewActorPivot/PreviewActor") as Node3D
	var held := preview_root.get_meta("preview_held_item", null) as Node3D
	var finger = actor.get("finger_grip_presenter")
	print("===", label, "===")
	print("ratio p=", held.get_meta("preview_primary_grip_seat_axis_ratio_from_span_start", -1), " s=", held.get_meta("preview_support_grip_seat_axis_ratio_from_span_start", -1))
	for slot: StringName in [&"hand_right", &"hand_left"]:
		var seat: Dictionary = actor.call("get_weapon_surface_seat_debug_state", slot)
		var grasp: Dictionary = finger.call("get_surface_grasp_debug_state", slot)
		var sd: Dictionary = seat.get("diagnostics", {})
		var best: Dictionary = sd.get("best_overall", {})
		var gd: Dictionary = grasp.get("last_attempt_diagnostics", grasp.get("diagnostics", {}))
		print(String(slot), " seat=", seat.get("status", &""), "/", seat.get("valid", false), " radial=", best.get("max_abs_radial_error_meters", -1), " grasp=", grasp.get("status", &""), "/", grasp.get("valid", false), " rotations=", (grasp.get("rotations", {}) as Dictionary).size(), " unsafe=", gd.get("unsafe_digit_count", -1))
	var two: Dictionary = actor.get("last_two_hand_solve_result")
	for slot: StringName in [&"hand_right", &"hand_left"]:
		var ss: Dictionary = two.get(slot, {})
		print(String(slot), " reach_clamped=", ss.get("arm_reach_clamped", false), " before=", ss.get("arm_reach_before_meters", -1), " after=", ss.get("arm_reach_after_meters", -1))
	var dbg := ui.get_preview_debug_state()
	print("align p=", dbg.get("dominant_grip_alignment_error_meters", -1), " s=", dbg.get("support_grip_alignment_error_meters", -1))
	var support_state: Dictionary = held.get_meta(
		"support_hand_surface_seat_state",
		{}
	) as Dictionary
	var dominant_state: Dictionary = held.get_meta(
		"weapon_surface_seat_state",
		{}
	) as Dictionary
	print("support_gate=", preview_root.get_meta("support_activation_gate_state", {}))
	var gate_tx: Dictionary = preview_root.get_meta(
		"support_grip_transaction_result",
		{}
	) as Dictionary
	print(
		"support_gate_tx=",
		gate_tx.get("status", &""),
		"/",
		gate_tx.get("valid", false),
		" corrections=",
		gate_tx.get("applied_correction_count", -1),
		" passes=",
		gate_tx.get("transaction_passes", [])
	)
	var support_digit_attempt: Dictionary = gate_tx.get(
		"support_digit_grip_attempt",
		{}
	) as Dictionary
	var support_digit_diagnostics: Dictionary = support_digit_attempt.get(
		"last_attempt_diagnostics",
		support_digit_attempt.get("diagnostics", {})
	) as Dictionary
	print("support_digit_attempt=", {
		"status": support_digit_attempt.get("status", StringName()),
		"last_attempt_status": support_digit_attempt.get(
			"last_attempt_status",
			StringName()
		),
		"valid": support_digit_attempt.get("valid", false),
		"safe_to_apply": support_digit_attempt.get(
			"last_attempt_safe_to_apply",
			false
		),
		"solver_status": support_digit_diagnostics.get("status", StringName()),
		"unsafe_digit_count": support_digit_diagnostics.get(
			"unsafe_digit_count",
			-1
		),
		"solved_digit_count": support_digit_diagnostics.get(
			"solved_digit_count",
			-1
		),
		"accepted_section_count": support_digit_diagnostics.get(
			"accepted_section_count",
			-1
		),
		"contacted_section_count": support_digit_diagnostics.get(
			"contacted_section_count",
			-1
		),
		"max_penetration_meters": support_digit_diagnostics.get(
			"max_penetration_meters",
			-1.0
		),
		"overlap_limit_respected": support_digit_diagnostics.get(
			"overlap_limit_respected",
			false
		),
		"digit_results": support_digit_diagnostics.get("digit_results", {}),
	})
	print(
		"dominant_tx=",
		dominant_state.get("status", &""),
		"/",
		dominant_state.get("valid", false),
		" applied=",
		dominant_state.get("applied", false),
		" current_reuse=",
		dominant_state.get(
			"committed_primary_seat_reused_for_support_activation",
			false
		)
	)
	print(
		"support_tx=",
		support_state.get("status", &""),
		"/",
		support_state.get("valid", false),
		" committed=",
		support_state.get("committed", false),
		" corrections=",
		support_state.get("applied_correction_count", -1)
	)

func _frames(count: int) -> void:
	for _i: int in range(count):
		await process_frame
