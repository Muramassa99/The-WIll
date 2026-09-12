extends SceneTree

const PlayerForgeWipLibraryStateScript = preload(
	"res://core/models/player_forge_wip_library_state.gd"
)
const CombatAnimationStationUIScene = preload(
	"res://scenes/ui/combat_animation_station_ui.tscn"
)

const TARGET_PROJECT_NAME := "Star_Handle_Testing"
const TARGET_SLOT_ID: StringName = &"skill_slot_1"
const DOMINANT_SLOT_ID: StringName = &"hand_right"
const SUPPORT_SLOT_ID: StringName = &"hand_left"
const LEFT_SLOT_ID: StringName = &"hand_left"
const PREVIEW_ACTOR_PATH := "PreviewActorPivot/PreviewActor"


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
		push_error("diagnostic target WIP missing")
		quit(1)
		return
	var diagnostic_wip: CraftedItemWIP = source_wip.duplicate(true) as CraftedItemWIP
	var diagnostic_library: PlayerForgeWipLibraryState = (
		PlayerForgeWipLibraryStateScript.new()
	)
	diagnostic_library.saved_wips.clear()
	diagnostic_library.saved_wips.append(diagnostic_wip)
	diagnostic_library.selected_wip_id = diagnostic_wip.wip_id
	var fake_player := FakePlayer.new()
	fake_player.forge_wip_library_state = diagnostic_library
	root.add_child(fake_player)
	var ui: CombatAnimationStationUI = (
		CombatAnimationStationUIScene.instantiate() as CombatAnimationStationUI
	)
	root.add_child(ui)
	await _wait_frames(2)
	ui.open_for(fake_player, "Two-hand packet diagnostic")
	await _wait_frames(2)
	var user_args: PackedStringArray = OS.get_cmdline_user_args()
	var primary_slot_id: StringName = (
		LEFT_SLOT_ID if user_args.has("left_probe") else DOMINANT_SLOT_ID
	)
	var support_slot_id: StringName = (
		DOMINANT_SLOT_ID if primary_slot_id == LEFT_SLOT_ID else SUPPORT_SLOT_ID
	)
	var open_two_hand: bool = (
		not user_args.has("one_hand") and not user_args.has("left_probe")
	)
	print("open=", ui.open_saved_wip_with_hand_setup(
		diagnostic_wip.wip_id,
		primary_slot_id,
		open_two_hand,
		false
	))
	await _wait_frames(2)
	_print_compact_stage(ui, "after_open", primary_slot_id, support_slot_id)
	print("select=", ui.select_skill_slot(TARGET_SLOT_ID, true))
	await _wait_frames(2)
	_print_compact_stage(ui, "after_select", primary_slot_id, support_slot_id)
	print("reset=", ui.reset_active_draft_to_baseline())
	await _wait_frames(2)
	_print_compact_stage(ui, "after_reset", primary_slot_id, support_slot_id)
	var preview_root: Node3D = ui.preview_subviewport.get_node_or_null(
		"CombatAnimationPreviewRoot3D"
	) as Node3D
	var actor: Node3D = preview_root.get_node_or_null(PREVIEW_ACTOR_PATH) as Node3D
	var held_item: Node3D = preview_root.get_meta("preview_held_item", null) as Node3D
	if user_args.has("left_probe"):
		_probe_primary_seat_convergence(
			ui,
			actor,
			held_item,
			primary_slot_id
		)
		ui.queue_free()
		fake_player.queue_free()
		await _wait_frames(2)
		quit(0)
		return
	var grip_presenter: RefCounted = actor.get("finger_grip_presenter") as RefCounted
	for slot_id: StringName in [primary_slot_id, support_slot_id]:
		var seat: Dictionary = actor.call(
			"get_weapon_surface_seat_debug_state",
			slot_id
		) as Dictionary
		var grasp: Dictionary = grip_presenter.call(
			"get_surface_grasp_debug_state",
			slot_id
		) as Dictionary
		var seat_diagnostics: Dictionary = seat.get("diagnostics", {}) as Dictionary
		var seat_best: Dictionary = seat_diagnostics.get("best_overall", {}) as Dictionary
		var grasp_diagnostics: Dictionary = grasp.get(
			"last_attempt_diagnostics",
			grasp.get("diagnostics", {})
		) as Dictionary
		print("slot=", slot_id)
		print(" seat_status=", seat.get("status"), " valid=", seat.get("valid"))
		print(" seat_best=", var_to_str(seat_best))
		print(" seat_diagnostics=", var_to_str(seat_diagnostics))
		print(" grasp_status=", grasp.get("status"), " valid=", grasp.get("valid"))
		print(" grasp_summary=", var_to_str({
			"status": grasp_diagnostics.get("status"),
			"safe_to_apply": grasp.get("last_attempt_safe_to_apply"),
			"unsafe_digit_count": grasp_diagnostics.get("unsafe_digit_count"),
			"solved_digit_count": grasp_diagnostics.get("solved_digit_count"),
			"accepted_section_count": grasp_diagnostics.get("accepted_section_count"),
			"contacted_section_count": grasp_diagnostics.get("contacted_section_count"),
			"max_penetration_meters": grasp_diagnostics.get("max_penetration_meters"),
			"digit_results": grasp_diagnostics.get("digit_results", {}),
		}))
	print("dominant_published_seat=", var_to_str(held_item.get_meta(
		"weapon_surface_seat_state",
		{}
	)))
	print("support_published_seat=", var_to_str(held_item.get_meta(
		"preview_support_hand_surface_seat_state",
		{}
	)))
	ui.queue_free()
	fake_player.queue_free()
	await _wait_frames(2)
	quit(0)


func _print_compact_stage(
	ui: CombatAnimationStationUI,
	label: String,
	primary_slot_id: StringName,
	support_slot_id: StringName
) -> void:
	var preview_root: Node3D = ui.preview_subviewport.get_node_or_null(
		"CombatAnimationPreviewRoot3D"
	) as Node3D
	if preview_root == null:
		print("TRACE stage=", label, " preview=false")
		return
	var actor: Node3D = preview_root.get_node_or_null(PREVIEW_ACTOR_PATH) as Node3D
	var motion_node: CombatAnimationMotionNode = ui.call(
		"_get_active_motion_node"
	) as CombatAnimationMotionNode
	if actor == null:
		print("TRACE stage=", label, " actor=false")
		return
	for slot_id: StringName in [primary_slot_id, support_slot_id]:
		var seat: Dictionary = actor.call(
			"get_authoring_current_weapon_surface_seat",
			slot_id
		) as Dictionary
		var grasp_debug: Dictionary = actor.call(
			"get_authoring_surface_grasp_debug_state",
			slot_id
		) as Dictionary
		var diagnostics: Dictionary = grasp_debug.get(
			"last_attempt_diagnostics",
			grasp_debug.get("diagnostics", {})
		) as Dictionary
		print(
			"TRACE stage=", label,
			" slot=", slot_id,
			" two=", motion_node.two_hand_state if motion_node != null else &"",
			" support_active=", actor.call("is_support_hand_active", slot_id),
			" seat_valid=", seat.get("valid", false),
			" seat_status=", seat.get("status", &""),
			" seat_context=", seat.get("context_key", ""),
			" grasp_current=", actor.call("has_authoring_current_surface_grip", slot_id),
			" grasp_status=", grasp_debug.get("status", &""),
			" attempt_status=", diagnostics.get("status", &""),
			" attempt_safe=", grasp_debug.get("last_attempt_safe_to_apply", false),
			" unsafe=", diagnostics.get("unsafe_digit_count", -1)
		)
		var digit_results: Dictionary = diagnostics.get("digit_results", {}) as Dictionary
		for digit_id_variant: Variant in digit_results.keys():
			var digit_id: StringName = StringName(digit_id_variant)
			var digit: Dictionary = digit_results.get(digit_id_variant, {}) as Dictionary
			if bool(digit.get("overlap_limit_respected", true)):
				continue
			print(
				"TRACE_UNSAFE stage=", label,
				" slot=", slot_id,
				" digit=", digit_id,
				" status=", digit.get("status", &""),
				" accepted=", digit.get("accepted_section_count", -1),
				" contact=", digit.get("contacted_section_count", -1),
				" error_mm=", float(digit.get(
					"attempted_max_contact_error_meters",
					digit.get("max_contact_error_meters", -1.0)
				)) * 1000.0,
				" penetration_mm=", float(digit.get(
					"attempted_max_penetration_meters",
					digit.get("max_penetration_meters", -1.0)
				)) * 1000.0
			)
			for section_variant: Variant in digit.get("attempted_final_sections", []) as Array:
				var section: Dictionary = section_variant as Dictionary
				if bool(section.get("within_overlap_limit", true)):
					continue
				print(
					"TRACE_UNSAFE_SECTION stage=", label,
					" slot=", slot_id,
					" digit=", digit_id,
					" section=", section.get("section_index", -1),
					" status=", section.get("status", &""),
					" penetration_mm=", float(section.get("penetration_meters", -1.0)) * 1000.0,
					" cap_mm=", float(section.get("section_max_allowed_overlap_meters", -1.0)) * 1000.0,
					" gap_mm=", float(section.get("surface_gap_meters", -1.0)) * 1000.0
				)
	print("TRACE stage=", label, " support_gate=", var_to_str(
		preview_root.get_meta("support_activation_gate_state", {})
	), " bootstrap=", (
		ui.preview_presenter.get_meta("diagnostic_last_primary_grip_bootstrap_ok")
		if ui.preview_presenter.has_meta("diagnostic_last_primary_grip_bootstrap_ok")
		else null
	))
	print(
		"TRACE stage=", label,
		" reset_primary_preseed=", var_to_str(preview_root.get_meta(
			"reset_primary_grip_preseed_result",
			{}
		)),
		" refresh_preseed=", var_to_str(preview_root.get_meta(
			"reset_primary_grip_preseed_refresh_result",
			{}
		))
	)


func _probe_primary_seat_convergence(
	ui: CombatAnimationStationUI,
	actor: Node3D,
	held_item: Node3D,
	primary_slot_id: StringName
) -> void:
	var primary_guide: Node3D = held_item.get_node_or_null(
		"PrimaryGripGuide"
	) as Node3D
	var motion_node: CombatAnimationMotionNode = ui.call(
		"_get_active_motion_node"
	) as CombatAnimationMotionNode
	if primary_guide == null or motion_node == null:
		print("PRIMARY_PROBE unavailable")
		return
	var authored_tip_before: Vector3 = motion_node.tip_position_local
	var authored_pommel_before: Vector3 = motion_node.pommel_position_local
	var weapon_before: Transform3D = held_item.global_transform
	var local_tip: Vector3 = held_item.get_meta(
		"weapon_tip_local",
		Vector3.INF
	) as Vector3
	var local_pommel: Vector3 = held_item.get_meta(
		"weapon_pommel_local",
		Vector3.INF
	) as Vector3
	var contact_before: Vector3 = actor.call(
		"resolve_hand_grip_alignment_world_position",
		primary_slot_id
	) as Vector3
	var verified_seat: Dictionary = {}
	var pass_budget: int = 5
	for pass_index: int in range(pass_budget):
		if pass_index > 0:
			actor.call(
				"invalidate_authoring_active_weapon_surface_seat",
				primary_slot_id
			)
		var seat_attempt: Dictionary = actor.call(
			"resolve_exact_surface_weapon_seat",
			primary_slot_id,
			true
		) as Dictionary
		var correction_state: Dictionary = ui.preview_presenter.call(
			"_resolve_preview_support_transaction_correction",
			seat_attempt,
			primary_guide
		) as Dictionary
		var diagnostics: Dictionary = seat_attempt.get(
			"diagnostics",
			{}
		) as Dictionary
		var best: Dictionary = diagnostics.get(
			"best_overall",
			{}
		) as Dictionary
		var correction_local: Transform3D = correction_state.get(
			"correction_local",
			Transform3D.IDENTITY
		) as Transform3D
		var correction_angle_degrees: float = rad_to_deg(
			correction_local.basis.orthonormalized()
				.get_rotation_quaternion().get_angle()
		)
		var correction_is_identity: bool = bool(ui.preview_presenter.call(
			"_preview_support_correction_is_identity",
			correction_local
		))
		print(
			"PRIMARY_PROBE pass=", pass_index,
			" seat_status=", seat_attempt.get("status", &""),
			" seat_valid=", seat_attempt.get("valid", false),
			" sample=", seat_attempt.get("candidate_sample_index", -1),
			" correction_kind=", correction_state.get("correction_kind", &""),
			" correction_valid=", correction_state.get("valid", false),
			" correction_identity=", correction_is_identity,
			" correction_mm=", correction_local.origin.length() * 1000.0,
			" correction_degrees=", correction_angle_degrees,
			" radial_max_mm=", float(best.get(
				"max_abs_radial_error_meters",
				INF
			)) * 1000.0,
			" radial_index_mm=", float(best.get(
				"index_radial_error_meters",
				INF
			)) * 1000.0,
			" radial_pinky_mm=", float(best.get(
				"pinky_radial_error_meters",
				INF
			)) * 1000.0
		)
		if (
			bool(seat_attempt.get("valid", false))
			and int(seat_attempt.get("candidate_sample_index", -1)) == 0
			and bool(correction_state.get("valid", false))
			and correction_is_identity
		):
			verified_seat = seat_attempt.duplicate(true)
			break
		if (
			not bool(correction_state.get("valid", false))
			or pass_index >= pass_budget - 1
		):
			break
		held_item.global_transform = (
			held_item.global_transform * correction_local
		)
		ui.preview_presenter.call(
			"_apply_preview_resolved_grip_state",
			held_item,
			actor
		)
	var contact_before_digits: Vector3 = actor.call(
		"resolve_hand_grip_alignment_world_position",
		primary_slot_id
	) as Vector3
	var digit_packet_committed: bool = false
	var realized_marked: bool = false
	if not verified_seat.is_empty():
		actor.call(
			"invalidate_authoring_active_surface_grasp",
			primary_slot_id
		)
		digit_packet_committed = bool(actor.call(
			"apply_authoring_digit_grip_slot_now",
			primary_slot_id,
			true
		))
		if digit_packet_committed:
			realized_marked = bool(actor.call(
				"mark_authoring_weapon_surface_seat_realized",
				primary_slot_id
			))
	var contact_after: Vector3 = actor.call(
		"resolve_hand_grip_alignment_world_position",
		primary_slot_id
	) as Vector3
	var weapon_after: Transform3D = held_item.global_transform
	var rendered_tip_before: Vector3 = weapon_before * local_tip
	var rendered_pommel_before: Vector3 = weapon_before * local_pommel
	var rendered_tip_after: Vector3 = weapon_after * local_tip
	var rendered_pommel_after: Vector3 = weapon_after * local_pommel
	print(
		"PRIMARY_PROBE_RESULT seat_verified=", not verified_seat.is_empty(),
		" digits=", digit_packet_committed,
		" realized=", realized_marked,
		" current_seat=", bool((actor.call(
			"get_authoring_current_weapon_surface_seat",
			primary_slot_id
		) as Dictionary).get("valid", false)),
		" current_grasp=", actor.call(
			"has_authoring_current_surface_grip",
			primary_slot_id
		),
		" authored_tip_drift_mm=", authored_tip_before.distance_to(
			motion_node.tip_position_local
		) * 1000.0,
		" authored_pommel_drift_mm=", authored_pommel_before.distance_to(
			motion_node.pommel_position_local
		) * 1000.0,
		" weapon_origin_drift_mm=", weapon_before.origin.distance_to(
			weapon_after.origin
		) * 1000.0,
		" rendered_tip_drift_mm=", rendered_tip_before.distance_to(
			rendered_tip_after
		) * 1000.0,
		" rendered_pommel_drift_mm=", rendered_pommel_before.distance_to(
			rendered_pommel_after
		) * 1000.0,
		" length_drift_mm=", rendered_tip_before.distance_to(
			rendered_pommel_before
		) - rendered_tip_after.distance_to(rendered_pommel_after),
		" hand_world_drift_before_digits_mm=", contact_before.distance_to(
			contact_before_digits
		) * 1000.0,
		" hand_world_drift_after_digits_mm=", contact_before.distance_to(
			contact_after
		) * 1000.0,
		" final_alignment_error_mm=", float(ui.preview_presenter.call(
			"_resolve_preview_grip_alignment_error",
			actor,
			held_item,
			primary_slot_id
		)) * 1000.0
	)


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
	for _frame: int in range(frame_count):
		await process_frame
