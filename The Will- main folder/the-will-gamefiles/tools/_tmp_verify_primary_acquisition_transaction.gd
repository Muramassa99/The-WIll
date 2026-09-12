extends SceneTree

const PlayerForgeWipLibraryStateScript = preload(
	"res://core/models/player_forge_wip_library_state.gd"
)
const CombatAnimationStationUIScene = preload(
	"res://scenes/ui/combat_animation_station_ui.tscn"
)

const TARGET_PROJECT_NAME := "Star_Handle_Testing"
const TARGET_SKILL_SLOT: StringName = &"skill_slot_1"


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
	var source_library: PlayerForgeWipLibraryState = (
		PlayerForgeWipLibraryStateScript.load_or_create()
	)
	var source_wip: CraftedItemWIP = _find_saved_wip_by_project_name(
		source_library,
		TARGET_PROJECT_NAME
	)
	if source_wip == null:
		push_error("Star_Handle_Testing is absent")
		quit(1)
		return
	var all_ok: bool = true
	for slot_id: StringName in [&"hand_right", &"hand_left"]:
		all_ok = await _run_slot(source_wip, slot_id) and all_ok
	quit(0 if all_ok else 1)


func _run_slot(source_wip: CraftedItemWIP, slot_id: StringName) -> bool:
	var diagnostic_wip: CraftedItemWIP = source_wip.duplicate(true) as CraftedItemWIP
	diagnostic_wip.wip_id = StringName(
		"%s_primary_transaction_%s" % [String(source_wip.wip_id), String(slot_id)]
	)
	var library := PlayerForgeWipLibraryStateScript.new()
	library.saved_wips.clear()
	library.saved_wips.append(diagnostic_wip)
	library.selected_wip_id = diagnostic_wip.wip_id
	var fake_player := FakePlayer.new()
	fake_player.forge_wip_library_state = library
	root.add_child(fake_player)
	var ui: CombatAnimationStationUI = (
		CombatAnimationStationUIScene.instantiate() as CombatAnimationStationUI
	)
	root.add_child(ui)
	await _wait_frames(2)
	ui.open_for(fake_player, "Primary transaction verification")
	await _wait_frames(2)
	var open_ok: bool = ui.open_saved_wip_with_hand_setup(
		diagnostic_wip.wip_id,
		slot_id,
		false,
		false
	)
	await _wait_frames(2)
	var select_ok: bool = ui.select_skill_slot(TARGET_SKILL_SLOT, true)
	await _wait_frames(2)
	var reset_ok: bool = ui.reset_active_draft_to_baseline()
	await _wait_frames(4)
	var preview_root: Node3D = ui.preview_subviewport.get_node_or_null(
		"CombatAnimationPreviewRoot3D"
	) as Node3D
	var actor: Node3D = preview_root.get_node_or_null(
		"PreviewActorPivot/PreviewActor"
	) as Node3D
	var held_item: Node3D = preview_root.get_meta(
		"preview_held_item",
		null
	) as Node3D
	var trajectory_root: Node3D = preview_root.find_child(
		"TrajectoryRoot",
		true,
		false
	) as Node3D
	var transaction: Dictionary = preview_root.get_meta(
		"primary_surface_grip_transaction_result",
		{}
	) as Dictionary
	var seat: Dictionary = actor.call(
		"get_authoring_current_weapon_surface_seat",
		slot_id
	) as Dictionary
	var grasp: Dictionary = actor.call(
		"get_authoring_surface_grasp_debug_state",
		slot_id
	) as Dictionary
	var rotations: Dictionary = grasp.get("rotations", {}) as Dictionary
	var draft: CombatAnimationDraft = ui.call("_get_active_draft") as CombatAnimationDraft
	var motion_node: CombatAnimationMotionNode = (
		draft.motion_node_chain[0] as CombatAnimationMotionNode
		if draft != null and not draft.motion_node_chain.is_empty()
		else null
	)
	var rendered_tip: Vector3 = trajectory_root.to_local(held_item.to_global(
		held_item.get_meta("weapon_tip_local", Vector3.ZERO) as Vector3
	))
	var rendered_pommel: Vector3 = trajectory_root.to_local(held_item.to_global(
		held_item.get_meta("weapon_pommel_local", Vector3.ZERO) as Vector3
	))
	var transaction_valid: bool = (
		bool(transaction.get("attempted", false))
		and bool(transaction.get("valid", false))
		and bool(transaction.get("committed", false))
		and StringName(transaction.get("status", StringName()))
			== &"primary_surface_grip_transaction_committed"
		and StringName(transaction.get("tip_position_origin_id", StringName()))
			== &"TrajectoryAuthoringOrigin"
		and StringName(transaction.get("pommel_position_origin_id", StringName()))
			== &"TrajectoryAuthoringOrigin"
		and int(transaction.get("committed_packet_bone_count", 0)) == 15
	)
	var node_matches: bool = (
		motion_node != null
		and motion_node.tip_position_local.is_equal_approx(rendered_tip)
		and motion_node.pommel_position_local.is_equal_approx(rendered_pommel)
	)
	var ok: bool = (
		open_ok
		and select_ok
		and reset_ok
		and transaction_valid
		and bool(seat.get("valid", false))
		and bool(actor.call("has_authoring_current_surface_grip", slot_id))
		and rotations.size() == 15
		and node_matches
	)
	print("PRIMARY_TRANSACTION_SLOT=", slot_id)
	print(" open=", open_ok, " select=", select_ok, " reset=", reset_ok)
	print(" transaction_status=", transaction.get("status"),
		" valid=", transaction.get("valid"),
		" committed=", transaction.get("committed"),
		" rollback=", transaction.get("rollback_succeeded"),
		" corrections=", transaction.get("applied_correction_count"),
		" packet=", transaction.get("committed_packet_bone_count"),
		" passes=", transaction.get("transaction_passes"))
	print(" rollback_verification=", transaction.get("rollback_verification"))
	var digit_attempt: Dictionary = transaction.get("digit_grip_attempt", {}) as Dictionary
	print(" digit_attempt_status=", digit_attempt.get("status"),
		" diagnostics_status=", (digit_attempt.get("diagnostics", {}) as Dictionary).get("status"),
		" solved_digits=", (digit_attempt.get("diagnostics", {}) as Dictionary).get("solved_digit_count"),
		" unsafe_digits=", (digit_attempt.get("diagnostics", {}) as Dictionary).get("unsafe_digit_count"))
	var digit_results: Dictionary = (
		digit_attempt.get("diagnostics", {}) as Dictionary
	).get("digit_results", {}) as Dictionary
	for digit_id_variant: Variant in digit_results.keys():
		var digit_state: Dictionary = digit_results.get(digit_id_variant, {}) as Dictionary
		print("  digit=", digit_id_variant,
			" status=", digit_state.get("status"),
			" overlap_ok=", digit_state.get("overlap_limit_respected"),
			" attempted_pen=", digit_state.get("attempted_max_penetration_meters"),
			" final_pen=", digit_state.get("max_penetration_meters"),
			" neutral_safe=", digit_state.get("neutral_fallback_safe"),
			" accepted=", digit_state.get("accepted_section_count"),
			" contacted=", digit_state.get("contacted_section_count"),
			" angles=", digit_state.get("joint_angles_rad"))
	print(" current_seat_status=", seat.get("status"), " valid=", seat.get("valid"))
	print(" current_grasp_status=", grasp.get("status"), " rotations=", rotations.size())
	var current_grasp_diagnostics: Dictionary = grasp.get(
		"last_attempt_diagnostics",
		grasp.get("diagnostics", {})
	) as Dictionary
	print(" current_grasp_solver=", current_grasp_diagnostics.get("status"),
		" unsafe=", current_grasp_diagnostics.get("unsafe_digit_count"),
		" solved=", current_grasp_diagnostics.get("solved_digit_count"))
	var current_digit_results: Dictionary = current_grasp_diagnostics.get(
		"digit_results",
		{}
	) as Dictionary
	for digit_id_variant: Variant in current_digit_results.keys():
		var digit_state: Dictionary = current_digit_results.get(digit_id_variant, {}) as Dictionary
		print("  current_digit=", digit_id_variant,
			" status=", digit_state.get("status"),
			" overlap_ok=", digit_state.get("overlap_limit_respected"),
			" attempted_pen=", digit_state.get("attempted_max_penetration_meters"),
			" final_pen=", digit_state.get("max_penetration_meters"),
			" neutral_safe=", digit_state.get("neutral_fallback_safe"))
	print(" rendered_tip=", rendered_tip, " rendered_pommel=", rendered_pommel)
	print(" node_tip=", motion_node.tip_position_local if motion_node != null else Vector3.ZERO)
	print(" node_pommel=", motion_node.pommel_position_local if motion_node != null else Vector3.ZERO)
	print(" node_matches_rendered=", node_matches, " ok=", ok)
	ui.queue_free()
	fake_player.queue_free()
	await _wait_frames(3)
	return ok


func _find_saved_wip_by_project_name(
	library: PlayerForgeWipLibraryState,
	project_name: String
) -> CraftedItemWIP:
	if library == null:
		return null
	for saved_wip: CraftedItemWIP in library.get_saved_wips():
		if saved_wip != null and saved_wip.forge_project_name == project_name:
			return saved_wip
	return null


func _wait_frames(frame_count: int) -> void:
	for _frame_index: int in range(frame_count):
		await process_frame
