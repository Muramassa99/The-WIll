extends SceneTree

const LibraryScript = preload("res://core/models/player_forge_wip_library_state.gd")
const UIScene = preload("res://scenes/ui/combat_animation_station_ui.tscn")
const TARGET_PROJECT_NAME := "Star_Handle_Testing"
const TEMP_LIBRARY_SAVE_PATH := "C:/WORKSPACE/test_artifacts/trace_support_coord_library.tres"

class CaptureSeatSolver:
	extends RefCounted
	var delegate: Object
	var actor: Node3D
	var held_item: Node3D
	var slot_id: StringName
	var calls: Array[Dictionary] = []
	var apply_test_provisional_guidance: bool = false

	func get_revision() -> StringName:
		return delegate.call("get_revision") as StringName

	func solve_prepared(
		prepared_surface: Dictionary,
		anatomy_state: Dictionary,
		grip_pivot_c0_world: Vector3,
		index_slice_center_ci_world: Vector3,
		pinky_slice_center_cp_world: Vector3,
		endcap_axis_world: Vector3,
		surface_source_origin_id: StringName,
		resolved_world_origin_id: StringName
	) -> Dictionary:
		var captured := {
			"anatomy_state": anatomy_state.duplicate(true),
			"grip_pivot_c0_world": grip_pivot_c0_world,
			"index_slice_center_ci_world": index_slice_center_ci_world,
			"pinky_slice_center_cp_world": pinky_slice_center_cp_world,
			"endcap_axis_world": endcap_axis_world,
			"surface_source_origin_id": surface_source_origin_id,
			"resolved_world_origin_id": resolved_world_origin_id,
			"surface_signature": String(prepared_surface.get("surface_signature", "")),
		}
		var guide: Node3D = (
			held_item.get_node_or_null("PrimaryGripGuide") as Node3D
			if held_item != null
			else null
		)
		if guide != null:
			captured["guide_local_transform"] = guide.transform
			captured["guide_world_transform"] = guide.global_transform
		var basis_anchor: Node3D = (
			held_item.get_node_or_null("PrimaryGripAnchor/PrimaryGripBasisAnchor") as Node3D
			if held_item != null
			else null
		)
		if basis_anchor != null:
			captured["basis_anchor_local_transform"] = basis_anchor.transform
			captured["basis_anchor_world_transform"] = basis_anchor.global_transform
		if actor != null:
			captured["alignment_state"] = actor.call(
				"resolve_hand_grip_alignment_offset_state",
				slot_id
			)
			captured["contact_center_world"] = actor.call(
				"_resolve_hand_index_pinky_contact_center_world",
				slot_id
			)
			var skeleton: Skeleton3D = actor.get("skeleton") as Skeleton3D
			var hand_bone_name: StringName = (
				&"CC_Base_L_Hand" if slot_id == &"hand_left" else &"CC_Base_R_Hand"
			)
			if skeleton != null:
				var hand_index: int = skeleton.find_bone(String(hand_bone_name))
				if hand_index >= 0:
					var hand_world: Transform3D = (
						skeleton.global_transform
						* skeleton.get_bone_global_pose(hand_index)
					)
					captured["hand_world_transform"] = hand_world
					if guide != null:
						captured["guide_in_hand_transform"] = (
							hand_world.affine_inverse() * guide.global_transform
						)
					var hand_anchor: Node3D = (
						actor.call("get_left_hand_item_anchor") as Node3D
						if slot_id == &"hand_left"
						else actor.call("get_right_hand_item_anchor") as Node3D
					)
					if hand_anchor != null:
						captured["hand_anchor_local_transform"] = hand_anchor.transform
						captured["hand_anchor_world_transform"] = hand_anchor.global_transform
						captured["hand_anchor_in_hand_transform"] = (
							hand_world.affine_inverse() * hand_anchor.global_transform
						)
						captured["weapon_in_hand_transform"] = (
							hand_world.affine_inverse() * held_item.global_transform
						)
						captured["weapon_in_anchor_transform"] = (
							hand_anchor.global_transform.affine_inverse()
								* held_item.global_transform
						)
						captured["stored_hand_mount_transform"] = held_item.get_meta(
							"hand_mount_local_transform",
							Transform3D.IDENTITY
						)
		var delegated_anatomy_state: Dictionary = anatomy_state.duplicate(true)
		if apply_test_provisional_guidance:
			delegated_anatomy_state["allow_transaction_provisional_candidate"] = true
		var result: Dictionary = delegate.call(
			"solve_prepared",
			prepared_surface,
			delegated_anatomy_state,
			grip_pivot_c0_world,
			index_slice_center_ci_world,
			pinky_slice_center_cp_world,
			endcap_axis_world,
			surface_source_origin_id,
			resolved_world_origin_id
		) as Dictionary
		captured["result"] = result.duplicate(true)
		var returned_result: Dictionary = result
		if (
			apply_test_provisional_guidance
			and not bool(result.get("valid", false))
			and bool(result.get("provisional_candidate_available", false))
		):
			# Harness-only transaction guidance. Preserve the raw rejected result in
			# `captured`, but expose its explicitly non-committable rigid correction
			# through the accepted correction schema so the existing Primary outer
			# transaction composes it and performs a fresh exact re-query.
			returned_result = result.duplicate(true)
			returned_result["valid"] = true
			returned_result["accepted"] = false
			returned_result["safe_to_apply"] = false
			returned_result["status"] = &"test_transaction_provisional_guidance"
			returned_result["candidate_sample_index"] = int(result.get(
				"provisional_candidate_sample_index",
				-1
			))
			returned_result["candidate_weapon_correction_about_grip_world"] = result.get(
				"provisional_weapon_correction_about_grip_world",
				Transform3D.IDENTITY
			)
			returned_result[
				"candidate_weapon_correction_about_grip_world_origin_id"
			] = result.get(
				"provisional_weapon_correction_about_grip_world_origin_id",
				StringName()
			)
			returned_result["candidate_weapon_correction_basis_world"] = result.get(
				"provisional_weapon_correction_basis_world",
				Basis.IDENTITY
			)
			returned_result[
				"candidate_weapon_correction_basis_world_origin_id"
			] = result.get(
				"provisional_weapon_correction_basis_world_origin_id",
				StringName()
			)
			returned_result["candidate_weapon_correction_pivot_world"] = result.get(
				"provisional_weapon_correction_pivot_world",
				grip_pivot_c0_world
			)
			returned_result[
				"candidate_weapon_correction_pivot_world_origin_id"
			] = result.get(
				"provisional_weapon_correction_pivot_world_origin_id",
				resolved_world_origin_id
			)
			returned_result[
				"candidate_weapon_correction_pivot_source_origin_id"
			] = result.get(
				"provisional_weapon_correction_pivot_source_origin_id",
				surface_source_origin_id
			)
			returned_result["candidate_weapon_radial_translation_world"] = result.get(
				"provisional_weapon_radial_translation_world",
				Vector3.ZERO
			)
		captured["returned_result"] = returned_result.duplicate(true)
		calls.append(captured)
		return returned_result

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
	var coord := 0.0
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		coord = float(args[0])
	var primary_slot_id: StringName = &"hand_right"
	if args.size() > 1 and String(args[1]).to_lower() == "left":
		primary_slot_id = &"hand_left"
	var use_two_hand: bool = not (
		args.size() > 2 and String(args[2]).to_lower() == "single"
	)
	var apply_test_provisional_guidance: bool = (
		args.size() > 3
		and String(args[3]).to_lower() == "provisional3"
	)
	var extended_support_candidate_degrees := PackedFloat64Array()
	if args.size() > 4:
		for degrees_text: String in String(args[4]).split(",", false):
			extended_support_candidate_degrees.append(float(degrees_text))
	var extended_support_candidate_passes: int = 5
	if args.size() > 5:
		extended_support_candidate_passes = maxi(1, int(args[5]))
	var extended_support_disable_limb_twist: bool = (
		args.size() > 6
		and String(args[6]).to_lower() == "no_twist"
	)
	var extended_support_elbow_swivel_degrees := PackedFloat64Array()
	if (
		args.size() > 7
		and String(args[7]).to_lower() not in ["none", "-"]
	):
		for degrees_text: String in String(args[7]).split(",", false):
			extended_support_elbow_swivel_degrees.append(float(degrees_text))
	var extended_support_arm_scan_steps: int = 0
	if args.size() > 8:
		extended_support_arm_scan_steps = maxi(0, int(args[8]))
	var extended_support_arm_swivel_step_degrees: float = 0.0
	if args.size() > 9:
		extended_support_arm_swivel_step_degrees = maxf(0.0, float(args[9]))
	var extended_support_shoulder_azimuth_step_degrees: float = 0.0
	if args.size() > 10:
		extended_support_shoulder_azimuth_step_degrees = maxf(0.0, float(args[10]))
	var extended_support_target_arm_ratio: float = NAN
	if args.size() > 11:
		extended_support_target_arm_ratio = clampf(float(args[11]), 0.0, 1.0)
	var extended_support_target_elbow_swivel_degrees: float = NAN
	if args.size() > 12:
		extended_support_target_elbow_swivel_degrees = float(args[12])
	var extended_support_target_shoulder_azimuth_degrees: float = NAN
	if args.size() > 13:
		extended_support_target_shoulder_azimuth_degrees = float(args[13])
	var shared_torso_scan_mode: String = (
		String(args[14]).to_lower() if args.size() > 14 else ""
	)
	var run_shared_torso_dual_arm_scan: bool = shared_torso_scan_mode in [
		"shared_torso",
		"shared_torso_precheck",
	]
	var shared_torso_precheck_only: bool = (
		shared_torso_scan_mode == "shared_torso_precheck"
	)
	var source_library: PlayerForgeWipLibraryState = LibraryScript.load_or_create()
	var source_wip: CraftedItemWIP
	for candidate: CraftedItemWIP in source_library.get_saved_wips():
		if candidate != null and candidate.forge_project_name == TARGET_PROJECT_NAME:
			source_wip = candidate
			break
	if source_wip == null:
		print("missing")
		quit(1)
		return
	var wip := source_wip.duplicate(true) as CraftedItemWIP
	wip.wip_id = StringName("trace_support_coord_isolated")
	var library := LibraryScript.new() as PlayerForgeWipLibraryState
	library.save_file_path = TEMP_LIBRARY_SAVE_PATH
	library.saved_wips.append(wip)
	library.selected_wip_id = wip.wip_id
	var fake := FakePlayer.new()
	fake.forge_wip_library_state = library
	root.add_child(fake)
	var ui := UIScene.instantiate() as CombatAnimationStationUI
	ui.set_meta("verification_skip_persistence", true)
	root.add_child(ui)
	await _frames(2)
	ui.open_for(fake, "trace")
	await _frames(2)
	ui.open_saved_wip_with_hand_setup(
		wip.wip_id,
		primary_slot_id,
		use_two_hand,
		false
	)
	await _frames(2)
	ui.select_skill_slot(&"skill_slot_1", true)
	await _frames(2)
	var capture_solver := CaptureSeatSolver.new()
	var preview_root := ui.preview_subviewport.get_node_or_null(
		"CombatAnimationPreviewRoot3D"
	) as Node3D
	var actor := (
		preview_root.get_node_or_null("PreviewActorPivot/PreviewActor") as Node3D
		if preview_root != null
		else null
	)
	if actor != null:
		var finger: Object = actor.get("finger_grip_presenter") as Object
		capture_solver.delegate = finger.get("hand_surface_seat_solver") as Object
		capture_solver.actor = actor
		capture_solver.held_item = preview_root.get_meta("preview_held_item", null) as Node3D
		capture_solver.slot_id = primary_slot_id
		capture_solver.apply_test_provisional_guidance = apply_test_provisional_guidance
		finger.set("hand_surface_seat_solver", capture_solver)
		actor.call("invalidate_authoring_active_weapon_surface_seat", primary_slot_id)
		actor.call("invalidate_authoring_active_surface_grasp", primary_slot_id)
	ui.reset_active_draft_to_baseline()
	await _frames(1)
	if not is_zero_approx(coord):
		ui.set_selected_motion_node_secondary_grip_seat_slide(coord, false, false, false, true, false)
		await _frames(1)
	var extended_support_candidates: Array[Dictionary] = []
	for candidate_degrees: float in extended_support_candidate_degrees:
		extended_support_candidates.append(_run_extended_support_candidate(
			ui,
			primary_slot_id,
			candidate_degrees,
			extended_support_candidate_passes,
			extended_support_disable_limb_twist,
			extended_support_elbow_swivel_degrees,
			extended_support_arm_scan_steps,
			extended_support_arm_swivel_step_degrees,
			extended_support_shoulder_azimuth_step_degrees,
			extended_support_target_arm_ratio,
			extended_support_target_elbow_swivel_degrees,
			extended_support_target_shoulder_azimuth_degrees,
			run_shared_torso_dual_arm_scan,
			shared_torso_precheck_only
		))
	_dump(
		ui,
		coord,
		primary_slot_id,
		capture_solver,
		extended_support_candidates
	)
	quit()


func _run_extended_support_candidate(
	ui: CombatAnimationStationUI,
	primary_slot_id: StringName,
	candidate_degrees: float,
	fixed_point_passes: int,
	disable_limb_twist: bool = false,
	elbow_swivel_degrees: PackedFloat64Array = PackedFloat64Array(),
	arm_scan_steps: int = 0,
	arm_swivel_step_degrees: float = 0.0,
	shoulder_azimuth_step_degrees: float = 0.0,
	target_arm_ratio: float = NAN,
	target_elbow_swivel_degrees: float = NAN,
	target_shoulder_azimuth_degrees: float = NAN,
	run_shared_torso_dual_arm_scan: bool = false,
	shared_torso_precheck_only: bool = false
) -> Dictionary:
	var failure := {
		"valid": false,
		"status": &"test_extended_support_candidate_unavailable",
		"candidate_degrees": candidate_degrees,
		"fixed_point_passes": fixed_point_passes,
		"disable_limb_twist": disable_limb_twist,
	}
	var preview_root := ui.preview_subviewport.get_node_or_null(
		"CombatAnimationPreviewRoot3D"
	) as Node3D
	if preview_root == null:
		return failure
	var actor := preview_root.get_node_or_null(
		"PreviewActorPivot/PreviewActor"
	) as Node3D
	var held := preview_root.get_meta("preview_held_item", null) as Node3D
	var presenter: Object = ui.preview_presenter
	if actor == null or held == null or presenter == null:
		return failure
	var support_slot_id: StringName = (
		&"hand_right" if primary_slot_id == &"hand_left" else &"hand_left"
	)
	var secondary_guide := held.get_node_or_null("SecondaryGripGuide") as Node3D
	var support_anchor := held.get_node_or_null("SupportGripAnchor") as Node3D
	var relationship_key: String = String(held.get_meta(
		"preview_support_grip_relationship_key",
		""
	))
	if secondary_guide == null or support_anchor == null or relationship_key.is_empty():
		failure["status"] = &"test_extended_support_candidate_anchor_invalid"
		return failure
	var baseline_arm_range_state: Dictionary = (
		actor.call("get_authoring_arm_joint_range_state", support_slot_id) as Dictionary
	).duplicate(true)
	var baseline_arm_geometry_state: Dictionary = _capture_test_arm_geometry_state(
		actor,
		support_slot_id
	)
	var baseline_joint_frame_state: Dictionary = _capture_test_joint_frame_state(
		actor,
		support_slot_id
	)
	var snapshot: Dictionary = presenter.call(
		"_capture_preview_support_grip_transaction_snapshot",
		actor,
		held,
		support_anchor,
		support_slot_id,
		primary_slot_id
	) as Dictionary
	if not bool(snapshot.get("valid", false)):
		failure["status"] = &"test_extended_support_candidate_snapshot_failed"
		return failure
	if not bool(actor.call(
		"prepare_authoring_surface_grip_open_pose_now",
		support_slot_id
	)):
		failure["status"] = &"test_extended_support_candidate_open_failed"
		return failure
	var base_accumulator: Transform3D = presenter.call(
		"_resolve_preview_support_committed_accumulator",
		support_anchor,
		relationship_key
	) as Transform3D
	var candidate_frame: Dictionary = presenter.call(
		"_resolve_preview_support_axial_candidate_frame",
		held,
		secondary_guide,
		base_accumulator
	) as Dictionary
	var candidate_accumulator: Transform3D = presenter.call(
		"_build_preview_support_axial_candidate_accumulator",
		base_accumulator,
		candidate_frame,
		candidate_degrees
	) as Transform3D
	if not bool(presenter.call(
		"_compose_preview_support_grip_anchor_from_accumulator",
		held,
		candidate_accumulator
	)):
		failure["status"] = &"test_extended_support_candidate_compose_failed"
		return failure
	var equipped_presenter: Object = presenter.get("equipped_item_presenter")
	if (
		equipped_presenter == null
		or not bool(equipped_presenter.call(
			"sync_single_weapon_support_contact_guidance",
			actor,
			held,
			primary_slot_id,
			true,
			true
		))
	):
		failure["status"] = &"test_extended_support_candidate_sync_failed"
		return failure
	var prepared_arm_geometry_state: Dictionary = _capture_test_arm_geometry_state(
		actor,
		support_slot_id
	)
	var prepared_joint_frame_state: Dictionary = _capture_test_joint_frame_state(
		actor,
		support_slot_id
	)
	actor.call(
		"settle_authoring_support_grip_macro_pose_now",
		0.0005,
		not disable_limb_twist
	)
	var attempt: Dictionary
	if disable_limb_twist:
		attempt = _attempt_extended_support_candidate_without_limb_twist(
			presenter,
			equipped_presenter,
			actor,
			held,
			secondary_guide,
			snapshot,
			support_slot_id,
			primary_slot_id,
			candidate_accumulator,
			fixed_point_passes
		)
	else:
		attempt = presenter.call(
			"_attempt_preview_support_surface_grip_candidate",
			actor,
			held,
			secondary_guide,
			snapshot,
			support_slot_id,
			primary_slot_id,
			candidate_accumulator,
			fixed_point_passes
		) as Dictionary
	var seated_joint_frame_state: Dictionary = _capture_test_joint_frame_state(
		actor,
		support_slot_id
	)
	if bool(attempt.get("seat_verified", false)):
		if run_shared_torso_dual_arm_scan:
			attempt["test_post_seat_shared_torso_dual_arm_scan"] = (
				_scan_test_shared_torso_dual_arm_route(
					presenter,
					actor,
					held,
					snapshot,
					support_slot_id,
					primary_slot_id,
					shared_torso_precheck_only
				)
			)
		else:
			attempt["test_post_seat_anatomical_joint_space_scan"] = (
				_scan_test_support_verified_anatomical_joint_space_candidates(
					presenter,
					actor,
					held,
					snapshot,
					support_slot_id,
					primary_slot_id
				)
			)
			attempt["test_post_seat_contact_space_scan"] = (
				_scan_test_support_contact_space_candidates(
					presenter,
					actor,
					held,
					snapshot,
					support_slot_id,
					primary_slot_id
				)
			)
	if (
		bool(attempt.get("seat_verified", false))
		and false # Superseded unsafe free three-link experiment; diagnostic only.
		and actor.has_method("legalize_authoring_support_arm_pose_now")
	):
		if arm_scan_steps > 0:
			attempt["test_post_seat_three_link_candidate_scan"] = (
				_scan_test_support_three_link_arm_candidates(
					presenter,
					actor,
					held,
					snapshot,
					support_slot_id,
					primary_slot_id,
					arm_scan_steps,
					arm_swivel_step_degrees,
					shoulder_azimuth_step_degrees,
					target_arm_ratio,
					target_elbow_swivel_degrees,
					target_shoulder_azimuth_degrees
				)
			)
		attempt["test_post_seat_arm_legalization"] = (
			actor.call(
				"legalize_authoring_support_arm_pose_now",
				support_slot_id
			) as Dictionary
		).duplicate(true)
		attempt["test_post_seat_arm_range_state"] = (
			actor.call(
				"get_authoring_arm_joint_range_state",
				support_slot_id
			) as Dictionary
		).duplicate(true)
		attempt["test_post_seat_body_gate"] = (
			presenter.call(
				"_evaluate_preview_support_body_self_collision_delta",
				actor,
				snapshot,
				support_slot_id
			) as Dictionary
		).duplicate(true)
		actor.call(
			"invalidate_authoring_active_weapon_surface_seat",
			support_slot_id
		)
		attempt["test_post_seat_surface_recheck"] = (
			actor.call(
				"resolve_exact_surface_weapon_seat",
				support_slot_id,
				true,
				true
			) as Dictionary
		).duplicate(true)
	if bool(attempt.get("seat_verified", false)) and not elbow_swivel_degrees.is_empty():
		attempt["test_elbow_swivel_attempts"] = _scan_test_support_elbow_swivel_candidates(
			presenter,
			actor,
			held,
			snapshot,
			support_slot_id,
			primary_slot_id,
			elbow_swivel_degrees
		)
	if (
		bool(attempt.get("seat_verified", false))
		and not bool(attempt.get("digit_packet_committed", false))
	):
		# Diagnostic only: production correctly stops before digit application when
		# the body-delta gate rejects. Query the isolated packet afterward so the two
		# independent predicates are visible without weakening either one.
		actor.call("invalidate_authoring_active_surface_grasp", support_slot_id)
		attempt["test_digit_packet_committed_ignoring_body_gate"] = bool(actor.call(
			"apply_authoring_digit_grip_slot_now",
			support_slot_id,
			true
		))
		attempt["test_digit_packet_state_ignoring_body_gate"] = (
			actor.call(
				"get_authoring_surface_grasp_debug_state",
				support_slot_id
			) as Dictionary
		).duplicate(true)
	attempt["test_support_slot_id"] = support_slot_id
	attempt["test_baseline_arm_range_state"] = baseline_arm_range_state
	attempt["test_baseline_arm_geometry_state"] = baseline_arm_geometry_state
	attempt["test_prepared_arm_geometry_state"] = prepared_arm_geometry_state
	attempt["test_baseline_joint_frame_state"] = baseline_joint_frame_state
	attempt["test_prepared_joint_frame_state"] = prepared_joint_frame_state
	attempt["test_seated_joint_frame_state"] = seated_joint_frame_state
	attempt["test_candidate_arm_range_state"] = (
		actor.call("get_authoring_arm_joint_range_state", support_slot_id) as Dictionary
	).duplicate(true)
	attempt["test_candidate_arm_geometry_state"] = _capture_test_arm_geometry_state(
		actor,
		support_slot_id
	)
	attempt["test_baseline_body_state"] = (
		snapshot.get("body_self_collision_state", {}) as Dictionary
	).duplicate(true)
	attempt["test_candidate_body_state"] = (
		actor.call("get_body_self_collision_debug_state", true) as Dictionary
	).duplicate(true)
	attempt["test_baseline_restored_after_diagnostic"] = bool(presenter.call(
		"_restore_preview_support_candidate_baseline",
		actor,
		held,
		support_anchor,
		snapshot,
		support_slot_id,
		primary_slot_id
	))
	attempt["candidate_degrees"] = candidate_degrees
	attempt["fixed_point_passes"] = fixed_point_passes
	attempt["disable_limb_twist"] = disable_limb_twist
	return attempt


func _scan_test_shared_torso_dual_arm_route(
	presenter: Object,
	actor: Node3D,
	held: Node3D,
	transaction_snapshot: Dictionary,
	support_slot_id: StringName,
	primary_slot_id: StringName,
	precheck_only: bool = false
) -> Dictionary:
	var result := {
		"valid": false,
		"status": &"test_shared_torso_dual_arm_scan_unavailable",
		"point_origin_id": &"RL_BoneRoot",
		"zero_packet_source": &"actor._apply_authoring_preview_baseline_pose.animation_t0",
		"zero_packet_frame": &"parent_local_pose",
		"primary_slot_id": primary_slot_id,
		"support_slot_id": support_slot_id,
		"torso_contract": {
			"CC_Base_Spine01": {
				"parent": &"CC_Base_Waist",
				"axis": &"local_y",
				"minimum_degrees": -35.0,
				"maximum_degrees": 35.0,
			},
			"CC_Base_Spine02": {
				"parent": &"CC_Base_Spine01",
				"axis": &"local_y",
				"minimum_degrees": -55.0,
				"maximum_degrees": 55.0,
			},
		},
		"coarse_torso_count": 0,
		"refined_torso_count": 0,
		"full_torso_count": 0,
		"exact_candidate_count": 0,
		"best_candidate": {},
		"exact_candidate": {},
		"best_primary_independent": {},
		"best_support_independent": {},
		"applied_validation": {},
		"candidate_summaries": [],
	}
	if (
		presenter == null
		or actor == null
		or held == null
		or not bool(transaction_snapshot.get("valid", false))
		or support_slot_id not in [&"hand_right", &"hand_left"]
		or primary_slot_id not in [&"hand_right", &"hand_left"]
		or support_slot_id == primary_slot_id
	):
		return result
	var skeleton: Skeleton3D = actor.get("skeleton") as Skeleton3D
	var support_anchor := held.get_node_or_null("SupportGripAnchor") as Node3D
	if skeleton == null or support_anchor == null:
		result["status"] = &"test_shared_torso_dual_arm_skeleton_or_anchor_missing"
		return result
	var bone_names := {
		"waist": &"CC_Base_Waist",
		"spine_01": &"CC_Base_Spine01",
		"spine_02": &"CC_Base_Spine02",
		"right_clavicle": &"CC_Base_R_Clavicle",
		"right_upperarm": &"CC_Base_R_Upperarm",
		"right_forearm": &"CC_Base_R_Forearm",
		"right_hand": &"CC_Base_R_Hand",
		"left_clavicle": &"CC_Base_L_Clavicle",
		"left_upperarm": &"CC_Base_L_Upperarm",
		"left_forearm": &"CC_Base_L_Forearm",
		"left_hand": &"CC_Base_L_Hand",
	}
	var bone_indices: Dictionary = {}
	for key: String in bone_names:
		var bone_name: StringName = bone_names[key]
		var bone_index: int = skeleton.find_bone(String(bone_name))
		if bone_index < 0:
			result["status"] = &"test_shared_torso_dual_arm_bone_missing"
			result["missing_bone"] = bone_name
			return result
		bone_indices[key] = bone_index
	if (
		skeleton.get_bone_parent(int(bone_indices["spine_01"])) != int(bone_indices["waist"])
		or skeleton.get_bone_parent(int(bone_indices["spine_02"])) != int(bone_indices["spine_01"])
		or not _test_shared_arm_hierarchy_matches(skeleton, bone_indices, "right")
		or not _test_shared_arm_hierarchy_matches(skeleton, bone_indices, "left")
	):
		result["status"] = &"test_shared_torso_dual_arm_hierarchy_mismatch"
		return result
	var support_left: bool = support_slot_id == &"hand_left"
	var primary_left: bool = primary_slot_id == &"hand_left"
	var support_prefix: String = "left" if support_left else "right"
	var primary_prefix: String = "left" if primary_left else "right"
	var support_clavicle_index: int = int(bone_indices[support_prefix + "_clavicle"])
	var support_clavicle_name: StringName = bone_names[support_prefix + "_clavicle"]
	var seated_snapshot: Dictionary = presenter.call(
		"_capture_preview_support_grip_transaction_snapshot",
		actor,
		held,
		support_anchor,
		support_slot_id,
		primary_slot_id
	) as Dictionary
	if not bool(seated_snapshot.get("valid", false)):
		result["status"] = &"test_shared_torso_dual_arm_snapshot_failed"
		return result
	var original_pose_packet: Array[Transform3D] = []
	for pose_index: int in range(skeleton.get_bone_count()):
		original_pose_packet.append(skeleton.get_bone_pose(pose_index))
	var original_weapon_world: Transform3D = held.global_transform
	var primary_hand_index: int = int(bone_indices[primary_prefix + "_hand"])
	var primary_hand_target_skeleton: Transform3D = skeleton.get_bone_global_pose(
		primary_hand_index
	)
	var primary_hand_target_world: Transform3D = (
		skeleton.global_transform * primary_hand_target_skeleton
	)
	var support_anatomy: Dictionary = actor.call(
		"resolve_hand_surface_seat_anatomy_state",
		support_slot_id
	) as Dictionary
	if not bool(support_anatomy.get("valid", false)):
		result["status"] = &"test_shared_torso_dual_arm_support_anatomy_missing"
		return result
	var expected_support_index: StringName = (
		&"CC_Base_L_Index1" if support_left else &"CC_Base_R_Index1"
	)
	var expected_support_pinky: StringName = (
		&"CC_Base_L_Pinky1" if support_left else &"CC_Base_R_Pinky1"
	)
	if (
		StringName(support_anatomy.get("index_point_world_origin_id", StringName())) != &"RL_BoneRoot"
		or StringName(support_anatomy.get("pinky_point_world_origin_id", StringName())) != &"RL_BoneRoot"
		or StringName(support_anatomy.get("index_point_source_origin_id", StringName())) != expected_support_index
		or StringName(support_anatomy.get("pinky_point_source_origin_id", StringName())) != expected_support_pinky
	):
		result["status"] = &"test_shared_torso_dual_arm_support_anatomy_origin_mismatch"
		return result
	var support_index_world: Vector3 = support_anatomy.get(
		"index_point_world",
		Vector3.ZERO
	) as Vector3
	var support_pinky_world: Vector3 = support_anatomy.get(
		"pinky_point_world",
		Vector3.ZERO
	) as Vector3
	var support_target_center_world: Vector3 = support_index_world.lerp(
		support_pinky_world,
		0.5
	)
	var support_target_axis_world: Vector3 = support_index_world - support_pinky_world
	if support_target_axis_world.length_squared() <= 0.000000000001:
		result["status"] = &"test_shared_torso_dual_arm_support_axis_invalid"
		return result
	support_target_axis_world = support_target_axis_world.normalized()
	var support_hand_index: int = int(bone_indices[support_prefix + "_hand"])
	var support_hand_current: Transform3D = skeleton.get_bone_global_pose(
		support_hand_index
	)
	var support_target_center_skeleton: Vector3 = skeleton.to_local(
		support_target_center_world
	)
	var support_target_axis_skeleton: Vector3 = (
		skeleton.global_basis.inverse() * support_target_axis_world
	).normalized()
	var support_center_offset_hand_local: Vector3 = (
		support_hand_current.affine_inverse() * support_target_center_skeleton
	)
	var support_axis_hand_local: Vector3 = (
		support_hand_current.basis.orthonormalized().inverse()
		* support_target_axis_skeleton
	).normalized()
	var baseline_state: Dictionary = _capture_test_authoring_baseline_bone_pose(
		presenter,
		actor,
		held,
		support_anchor,
		seated_snapshot,
		support_slot_id,
		primary_slot_id,
		support_clavicle_index,
		support_clavicle_name
	)
	if not bool(baseline_state.get("valid", false)):
		result["status"] = baseline_state.get(
			"status",
			&"test_shared_torso_dual_arm_zero_packet_missing"
		)
		return result
	var zero_poses: Array = baseline_state.get(
		"all_bone_poses_parent_local",
		[]
	) as Array
	if zero_poses.size() != skeleton.get_bone_count():
		result["status"] = &"test_shared_torso_dual_arm_zero_packet_size_mismatch"
		return result
	var zero_globals: Array[Transform3D] = _build_test_zero_global_pose_packet(
		skeleton,
		zero_poses
	)
	if zero_globals.size() != skeleton.get_bone_count():
		result["status"] = &"test_shared_torso_dual_arm_zero_global_packet_failed"
		return result
	result["pre_support_primary_contract_state"] = (
		_resolve_test_current_arm_contract_state(
			skeleton,
			bone_indices,
			zero_poses,
			primary_slot_id,
			float(actor.get("authoring_shoulder_min_plane_angle_degrees")),
			float(actor.get("authoring_shoulder_max_plane_angle_degrees")),
			float(actor.get("authoring_elbow_min_plane_angle_degrees")),
			float(actor.get("authoring_elbow_max_plane_angle_degrees"))
		)
	)
	result["pre_support_torso_contract_state"] = (
		_resolve_test_current_torso_contract_state(
			skeleton,
			bone_indices,
			zero_poses
		)
	)
	var governed_keys: Array[String] = [
		"spine_01",
		"spine_02",
		"right_clavicle",
		"right_upperarm",
		"right_forearm",
		"right_hand",
		"left_clavicle",
		"left_upperarm",
		"left_forearm",
		"left_hand",
	]
	for governed_key: String in governed_keys:
		var governed_index: int = int(bone_indices[governed_key])
		var current_origin: Vector3 = skeleton.get_bone_pose(governed_index).origin
		var zero_pose: Transform3D = zero_poses[governed_index]
		# Skeleton pose composition can round a restored parent-local origin by a
		# few 1e-7 units.  Keep the guard well below any meaningful authored
		# translation while avoiding a handedness-dependent float false positive.
		if current_origin.distance_to(zero_pose.origin) > 0.000001:
			result["status"] = &"test_shared_torso_dual_arm_local_origin_changed"
			result["changed_origin_bone"] = bone_names[governed_key]
			result["changed_origin_distance_parent_local"] = current_origin.distance_to(
				zero_pose.origin
			)
			return result
	var waist_index: int = int(bone_indices["waist"])
	var waist_current: Transform3D = skeleton.get_bone_global_pose(waist_index)
	var waist_zero: Transform3D = zero_globals[waist_index]
	var waist_position_error_meters: float = (
		skeleton.global_basis
		* (waist_current.origin - waist_zero.origin)
	).length()
	var waist_basis_error_degrees: float = _resolve_test_basis_delta_degrees(
		waist_current.basis,
		waist_zero.basis
	)
	result["waist_anchor_matches_zero_packet"] = (
		waist_position_error_meters <= 0.00005
		and waist_basis_error_degrees <= 0.05
	)
	result["waist_anchor_position_error_meters"] = waist_position_error_meters
	result["waist_anchor_basis_error_degrees"] = waist_basis_error_degrees
	# Waist itself is the fixed parent/origin of the two documented torso joints.
	# Its currently authored global frame is therefore preserved; only the
	# Spine01 local-Y and Spine02 local-Y relationships are rebuilt from Idle t0.
	result["waist_anchor_policy"] = &"preserve_current_waist_global_parent_frame"
	var base_context := {
		"point_origin_id": &"RL_BoneRoot",
		"skeleton_global_basis": skeleton.global_basis,
		"zero_poses": zero_poses,
		"zero_globals": zero_globals,
		"bone_indices": bone_indices,
		"bone_names": bone_names,
		"waist_global": waist_current,
		"shoulder_min_degrees": float(actor.get(
			"authoring_shoulder_min_plane_angle_degrees"
		)),
		"shoulder_max_degrees": float(actor.get(
			"authoring_shoulder_max_plane_angle_degrees"
		)),
		"elbow_min_degrees": float(actor.get(
			"authoring_elbow_min_plane_angle_degrees"
		)),
		"elbow_max_degrees": float(actor.get(
			"authoring_elbow_max_plane_angle_degrees"
		)),
		"primary_slot_id": primary_slot_id,
		"support_slot_id": support_slot_id,
		"primary_target_hand_skeleton": primary_hand_target_skeleton,
		"support_target_center_skeleton": support_target_center_skeleton,
		"support_target_axis_skeleton": support_target_axis_skeleton,
		"support_center_offset_hand_local": support_center_offset_hand_local,
		"support_axis_hand_local": support_axis_hand_local,
	}
	result["primary_target_hand_world"] = primary_hand_target_world
	result["primary_target_source_origin_id"] = bone_names[primary_prefix + "_hand"]
	result["primary_target_transform_chain"] = [
		bone_names[primary_prefix + "_hand"],
		bone_names[primary_prefix + "_forearm"],
		bone_names[primary_prefix + "_upperarm"],
		bone_names[primary_prefix + "_clavicle"],
		&"CC_Base_Spine02",
		&"CC_Base_Spine01",
		&"CC_Base_Waist",
		&"RL_BoneRoot",
	]
	result["support_target_center_world"] = support_target_center_world
	result["support_target_axis_world"] = support_target_axis_world
	result["support_target_center_source_origin_ids"] = [
		expected_support_index,
		expected_support_pinky,
	]
	result["support_target_transform_chain"] = [
		expected_support_index,
		expected_support_pinky,
		bone_names[support_prefix + "_hand"],
		bone_names[support_prefix + "_forearm"],
		bone_names[support_prefix + "_upperarm"],
		bone_names[support_prefix + "_clavicle"],
		&"CC_Base_Spine02",
		&"CC_Base_Spine01",
		&"CC_Base_Waist",
		&"RL_BoneRoot",
	]
	result["weapon_target_world"] = original_weapon_world
	result["weapon_target_origin_id"] = &"WeaponRootOrigin"
	result["zero_animation_name"] = baseline_state.get(
		"baseline_animation_name",
		StringName()
	)
	if precheck_only:
		result["valid"] = true
		result["final_restore_ok"] = true
		result["status"] = &"test_shared_torso_dual_arm_precheck_complete"
		return result

	var coarse_torso_inputs: Array[Dictionary] = []
	for spine_01_integer: int in range(-35, 36, 5):
		for spine_02_integer: int in range(-55, 56, 5):
			coarse_torso_inputs.append({
				"spine_01_degrees": float(spine_01_integer),
				"spine_02_degrees": float(spine_02_integer),
				"torso_deviation": _resolve_test_torso_deviation(
					float(spine_01_integer),
					float(spine_02_integer)
				),
			})
	coarse_torso_inputs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_deviation: float = float(a.get("torso_deviation", INF))
		var b_deviation: float = float(b.get("torso_deviation", INF))
		if absf(a_deviation - b_deviation) > 0.0000001:
			return a_deviation < b_deviation
		var a_spine_01: float = float(a.get("spine_01_degrees", 0.0))
		var b_spine_01: float = float(b.get("spine_01_degrees", 0.0))
		if absf(a_spine_01 - b_spine_01) > 0.0000001:
			return a_spine_01 < b_spine_01
		return float(a.get("spine_02_degrees", 0.0)) < float(
			b.get("spine_02_degrees", 0.0)
		)
	)
	var coarse_seeds: Array[Dictionary] = []
	var coarse_primary_seeds: Array[Dictionary] = []
	var coarse_support_seeds: Array[Dictionary] = []
	for torso_input: Dictionary in coarse_torso_inputs:
		var torso_candidate: Dictionary = _evaluate_test_shared_torso_candidate(
			base_context,
			float(torso_input["spine_01_degrees"]),
			float(torso_input["spine_02_degrees"]),
			true
		)
		result["coarse_torso_count"] = int(result["coarse_torso_count"]) + 1
		_insert_test_shared_torso_seed(coarse_seeds, torso_candidate, 12)
		_insert_test_shared_torso_metric_seed(
			coarse_primary_seeds,
			torso_candidate,
			"primary",
			3
		)
		_insert_test_shared_torso_metric_seed(
			coarse_support_seeds,
			torso_candidate,
			"support",
			3
		)
	var refined_seeds: Array[Dictionary] = []
	for coarse_seed: Dictionary in coarse_seeds:
		var refined_seed: Dictionary = coarse_seed.duplicate(true)
		for torso_step: float in [2.5, 0.5, 0.1, 0.02]:
			var center_spine_01: float = float(refined_seed.get(
				"spine_01_degrees",
				0.0
			))
			var center_spine_02: float = float(refined_seed.get(
				"spine_02_degrees",
				0.0
			))
			for spine_01_offset: int in range(-1, 2):
				for spine_02_offset: int in range(-1, 2):
					var refined_candidate: Dictionary = (
						_evaluate_test_shared_torso_candidate(
							base_context,
							clampf(
								center_spine_01
								+ float(spine_01_offset) * torso_step,
								-35.0,
								35.0
							),
							clampf(
								center_spine_02
								+ float(spine_02_offset) * torso_step,
								-55.0,
								55.0
							),
							true
						)
					)
					result["refined_torso_count"] = (
						int(result["refined_torso_count"]) + 1
					)
					if _test_shared_torso_candidate_better(
						refined_candidate,
						refined_seed
					):
						refined_seed = refined_candidate
		_insert_test_shared_torso_seed(refined_seeds, refined_seed, 12)
	var full_candidates: Array[Dictionary] = []
	for refined_seed: Dictionary in refined_seeds:
		var full_candidate: Dictionary = _evaluate_test_shared_torso_candidate(
			base_context,
			float(refined_seed.get("spine_01_degrees", 0.0)),
			float(refined_seed.get("spine_02_degrees", 0.0)),
			false
		)
		result["full_torso_count"] = int(result["full_torso_count"]) + 1
		_insert_test_shared_torso_seed(full_candidates, full_candidate, 12)
	var independent_primary_candidates: Array[Dictionary] = []
	for primary_seed: Dictionary in coarse_primary_seeds:
		var refined_primary_seed: Dictionary = _refine_test_shared_torso_for_metric(
			base_context,
			primary_seed,
			"primary"
		)
		var full_primary_candidate: Dictionary = _evaluate_test_shared_torso_candidate(
			base_context,
			float(refined_primary_seed.get("spine_01_degrees", 0.0)),
			float(refined_primary_seed.get("spine_02_degrees", 0.0)),
			false
		)
		result["full_torso_count"] = int(result["full_torso_count"]) + 1
		_insert_test_shared_torso_metric_seed(
			independent_primary_candidates,
			full_primary_candidate,
			"primary",
			3
		)
		_insert_test_shared_torso_seed(full_candidates, full_primary_candidate, 16)
	var independent_support_candidates: Array[Dictionary] = []
	for support_seed: Dictionary in coarse_support_seeds:
		var refined_support_seed: Dictionary = _refine_test_shared_torso_for_metric(
			base_context,
			support_seed,
			"support"
		)
		var full_support_candidate: Dictionary = _evaluate_test_shared_torso_candidate(
			base_context,
			float(refined_support_seed.get("spine_01_degrees", 0.0)),
			float(refined_support_seed.get("spine_02_degrees", 0.0)),
			false
		)
		result["full_torso_count"] = int(result["full_torso_count"]) + 1
		_insert_test_shared_torso_metric_seed(
			independent_support_candidates,
			full_support_candidate,
			"support",
			3
		)
		_insert_test_shared_torso_seed(full_candidates, full_support_candidate, 16)
	if not independent_primary_candidates.is_empty():
		result["best_primary_independent"] = _compact_test_shared_torso_candidate(
			independent_primary_candidates[0]
		)
	if not independent_support_candidates.is_empty():
		result["best_support_independent"] = _compact_test_shared_torso_candidate(
			independent_support_candidates[0]
		)
	if not full_candidates.is_empty():
		var final_refined: Array[Dictionary] = []
		for full_seed_index: int in range(mini(4, full_candidates.size())):
			var final_seed: Dictionary = full_candidates[full_seed_index].duplicate(true)
			for final_step: float in [0.01, 0.002]:
				var center_01: float = float(final_seed.get("spine_01_degrees", 0.0))
				var center_02: float = float(final_seed.get("spine_02_degrees", 0.0))
				for offset_01: int in range(-1, 2):
					for offset_02: int in range(-1, 2):
						var candidate: Dictionary = _evaluate_test_shared_torso_candidate(
							base_context,
							clampf(center_01 + float(offset_01) * final_step, -35.0, 35.0),
							clampf(center_02 + float(offset_02) * final_step, -55.0, 55.0),
							false
						)
						result["full_torso_count"] = int(result["full_torso_count"]) + 1
						if _test_shared_torso_candidate_better(candidate, final_seed):
							final_seed = candidate
			_insert_test_shared_torso_seed(final_refined, final_seed, 12)
		for final_candidate: Dictionary in final_refined:
			_insert_test_shared_torso_seed(full_candidates, final_candidate, 12)
	if not full_candidates.is_empty():
		result["best_candidate"] = _compact_test_shared_torso_candidate(
			full_candidates[0]
		)
	for full_candidate: Dictionary in full_candidates:
		if bool(full_candidate.get("exact", false)):
			result["exact_candidate_count"] = int(result["exact_candidate_count"]) + 1
			if result["exact_candidate"].is_empty():
				result["exact_candidate"] = _compact_test_shared_torso_candidate(
					full_candidate
				)
	var summaries: Array[Dictionary] = []
	for summary_index: int in range(mini(12, full_candidates.size())):
		summaries.append(_compact_test_shared_torso_candidate(
			full_candidates[summary_index]
		))
	result["candidate_summaries"] = summaries
	if not full_candidates.is_empty():
		result["applied_validation"] = _apply_and_validate_test_shared_torso_candidate(
			presenter,
			actor,
			held,
			transaction_snapshot,
			seated_snapshot,
			support_anchor,
			skeleton,
			bone_indices,
			bone_names,
			zero_poses,
			original_pose_packet,
			original_weapon_world,
			primary_slot_id,
			support_slot_id,
			primary_hand_target_world,
			support_target_center_world,
			support_target_axis_world,
			full_candidates[0]
		)
	var final_restore_ok: bool = bool(presenter.call(
		"_restore_preview_support_candidate_baseline",
		actor,
		held,
		support_anchor,
		seated_snapshot,
		support_slot_id,
		primary_slot_id
	))
	for restore_index: int in range(mini(
		original_pose_packet.size(),
		skeleton.get_bone_count()
	)):
		var restore_pose: Transform3D = original_pose_packet[restore_index]
		skeleton.set_bone_pose_position(restore_index, restore_pose.origin)
		skeleton.set_bone_pose_rotation(
			restore_index,
			restore_pose.basis.orthonormalized().get_rotation_quaternion()
		)
		skeleton.set_bone_pose_scale(restore_index, restore_pose.basis.get_scale())
	skeleton.force_update_all_bone_transforms()
	var final_weapon_error: Dictionary = _resolve_test_transform_error(
		held.global_transform,
		original_weapon_world
	)
	result["final_restore_ok"] = (
		final_restore_ok
		and float(final_weapon_error.get("position_error_meters", INF)) <= 0.0000001
		and float(final_weapon_error.get("basis_error_degrees", INF)) <= 0.0001
	)
	result["valid"] = bool(result["final_restore_ok"])
	if not bool(result["final_restore_ok"]):
		result["status"] = &"test_shared_torso_dual_arm_final_restore_failed"
	elif (
		not full_candidates.is_empty()
		and bool(full_candidates[0].get("exact", false))
		and bool((result["applied_validation"] as Dictionary).get("exact", false))
	):
		result["status"] = &"test_shared_torso_dual_arm_exact_route_found"
	else:
		result["status"] = &"test_shared_torso_dual_arm_no_exact_route_in_bounded_search"
	return result


func _test_shared_arm_hierarchy_matches(
	skeleton: Skeleton3D,
	bone_indices: Dictionary,
	prefix: String
) -> bool:
	var spine_02: int = int(bone_indices.get("spine_02", -1))
	var clavicle: int = int(bone_indices.get(prefix + "_clavicle", -1))
	var upperarm: int = int(bone_indices.get(prefix + "_upperarm", -1))
	var forearm: int = int(bone_indices.get(prefix + "_forearm", -1))
	var hand: int = int(bone_indices.get(prefix + "_hand", -1))
	return (
		spine_02 >= 0
		and clavicle >= 0
		and upperarm >= 0
		and forearm >= 0
		and hand >= 0
		and skeleton.get_bone_parent(clavicle) == spine_02
		and skeleton.get_bone_parent(upperarm) == clavicle
		and skeleton.get_bone_parent(forearm) == upperarm
		and skeleton.get_bone_parent(hand) == forearm
	)


func _build_test_zero_global_pose_packet(
	skeleton: Skeleton3D,
	zero_poses: Array
) -> Array[Transform3D]:
	var globals: Array[Transform3D] = []
	if skeleton == null or zero_poses.size() != skeleton.get_bone_count():
		return globals
	globals.resize(skeleton.get_bone_count())
	for bone_index: int in range(skeleton.get_bone_count()):
		var local_pose: Transform3D = zero_poses[bone_index]
		var parent_index: int = skeleton.get_bone_parent(bone_index)
		globals[bone_index] = (
			globals[parent_index] * local_pose
			if parent_index >= 0
			else local_pose
		)
	return globals


func _resolve_test_torso_deviation(
	spine_01_degrees: float,
	spine_02_degrees: float
) -> float:
	return sqrt(
		pow(spine_01_degrees / 35.0, 2.0)
		+ pow(spine_02_degrees / 55.0, 2.0)
	)


func _build_test_candidate_spine_global(
	base_context: Dictionary,
	spine_01_degrees: float,
	spine_02_degrees: float
) -> Transform3D:
	var zero_poses: Array = base_context.get("zero_poses", []) as Array
	var bone_indices: Dictionary = base_context.get("bone_indices", {}) as Dictionary
	var waist_global: Transform3D = base_context.get(
		"waist_global",
		Transform3D.IDENTITY
	) as Transform3D
	var spine_01_index: int = int(bone_indices.get("spine_01", -1))
	var spine_02_index: int = int(bone_indices.get("spine_02", -1))
	if (
		spine_01_index < 0
		or spine_02_index < 0
		or spine_01_index >= zero_poses.size()
		or spine_02_index >= zero_poses.size()
	):
		return Transform3D.IDENTITY
	var spine_01_zero: Transform3D = zero_poses[spine_01_index]
	var spine_02_zero: Transform3D = zero_poses[spine_02_index]
	var spine_01_local := Transform3D(
		(
			spine_01_zero.basis.orthonormalized()
			* Basis(Vector3.UP, deg_to_rad(spine_01_degrees))
		).orthonormalized(),
		spine_01_zero.origin
	)
	var spine_02_local := Transform3D(
		(
			spine_02_zero.basis.orthonormalized()
			* Basis(Vector3.UP, deg_to_rad(spine_02_degrees))
		).orthonormalized(),
		spine_02_zero.origin
	)
	return waist_global * spine_01_local * spine_02_local


func _evaluate_test_shared_torso_candidate(
	base_context: Dictionary,
	spine_01_degrees: float,
	spine_02_degrees: float,
	quick: bool
) -> Dictionary:
	var invalid := {
		"valid": false,
		"status": &"test_shared_torso_candidate_invalid",
		"combined_score": INF,
	}
	if (
		not is_finite(spine_01_degrees)
		or not is_finite(spine_02_degrees)
		or spine_01_degrees < -35.0001
		or spine_01_degrees > 35.0001
		or spine_02_degrees < -55.0001
		or spine_02_degrees > 55.0001
	):
		return invalid
	var spine_global: Transform3D = _build_test_candidate_spine_global(
		base_context,
		spine_01_degrees,
		spine_02_degrees
	)
	var primary_context: Dictionary = _build_test_shared_arm_context(
		base_context,
		spine_global,
		StringName(base_context.get("primary_slot_id", StringName())),
		true
	)
	var support_context: Dictionary = _build_test_shared_arm_context(
		base_context,
		spine_global,
		StringName(base_context.get("support_slot_id", StringName())),
		false
	)
	if primary_context.is_empty() or support_context.is_empty():
		return invalid
	var primary_candidate: Dictionary = _find_test_shared_arm_candidate(
		primary_context,
		quick
	)
	var support_candidate: Dictionary = _find_test_shared_arm_candidate(
		support_context,
		quick
	)
	if (
		not bool(primary_candidate.get("valid", false))
		or not bool(support_candidate.get("valid", false))
	):
		return invalid
	var torso_deviation: float = _resolve_test_torso_deviation(
		spine_01_degrees,
		spine_02_degrees
	)
	var combined_score: float = (
		float(primary_candidate.get("shared_arm_score", INF))
		+ float(support_candidate.get("shared_arm_score", INF))
		+ torso_deviation * 0.001
	)
	var exact: bool = (
		bool(primary_candidate.get("shared_arm_exact", false))
		and bool(support_candidate.get("shared_arm_exact", false))
	)
	return {
		"valid": true,
		"status": (
			&"test_shared_torso_candidate_exact"
			if exact
			else &"test_shared_torso_candidate_approximate"
		),
		"exact": exact,
		"quick": quick,
		"spine_01_degrees": spine_01_degrees,
		"spine_02_degrees": spine_02_degrees,
		"torso_deviation": torso_deviation,
		"combined_score": combined_score,
		"candidate_spine_global": spine_global,
		"primary_candidate": primary_candidate,
		"support_candidate": support_candidate,
	}


func _build_test_shared_arm_context(
	base_context: Dictionary,
	spine_global: Transform3D,
	slot_id: StringName,
	primary: bool
) -> Dictionary:
	if slot_id not in [&"hand_right", &"hand_left"]:
		return {}
	var left_side: bool = slot_id == &"hand_left"
	var prefix: String = "left" if left_side else "right"
	var zero_poses: Array = base_context.get("zero_poses", []) as Array
	var bone_indices: Dictionary = base_context.get("bone_indices", {}) as Dictionary
	var clavicle_index: int = int(bone_indices.get(prefix + "_clavicle", -1))
	var upperarm_index: int = int(bone_indices.get(prefix + "_upperarm", -1))
	var forearm_index: int = int(bone_indices.get(prefix + "_forearm", -1))
	var hand_index: int = int(bone_indices.get(prefix + "_hand", -1))
	if (
		clavicle_index < 0
		or upperarm_index < 0
		or forearm_index < 0
		or hand_index < 0
		or hand_index >= zero_poses.size()
	):
		return {}
	var target_hand: Transform3D = base_context.get(
		"primary_target_hand_skeleton",
		Transform3D.IDENTITY
	) as Transform3D
	var alignment_offset: Vector3 = Vector3.ZERO
	var axis_hand_local: Vector3 = Vector3.RIGHT
	var target_alignment: Vector3 = target_hand.origin
	var target_axis: Vector3 = (
		target_hand.basis.orthonormalized() * axis_hand_local
	).normalized()
	if not primary:
		alignment_offset = base_context.get(
			"support_center_offset_hand_local",
			Vector3.ZERO
		) as Vector3
		axis_hand_local = base_context.get(
			"support_axis_hand_local",
			Vector3.ZERO
		) as Vector3
		target_alignment = base_context.get(
			"support_target_center_skeleton",
			Vector3.ZERO
		) as Vector3
		target_axis = base_context.get(
			"support_target_axis_skeleton",
			Vector3.ZERO
		) as Vector3
	return {
		"point_origin_id": &"RL_BoneRoot",
		"slot_id": slot_id,
		"left_side": left_side,
		"primary": primary,
		"spine_global": spine_global,
		"baseline_clavicle_basis": (
			zero_poses[clavicle_index] as Transform3D
		).basis.orthonormalized(),
		"clavicle_pose_origin": (
			zero_poses[clavicle_index] as Transform3D
		).origin,
		"upperarm_pose_origin": (
			zero_poses[upperarm_index] as Transform3D
		).origin,
		"forearm_pose_origin": (
			zero_poses[forearm_index] as Transform3D
		).origin,
		"hand_pose_origin": (
			zero_poses[hand_index] as Transform3D
		).origin,
		"upperarm_zero_basis": (
			zero_poses[upperarm_index] as Transform3D
		).basis.orthonormalized(),
		"forearm_zero_basis": (
			zero_poses[forearm_index] as Transform3D
		).basis.orthonormalized(),
		"hand_zero_basis": (
			zero_poses[hand_index] as Transform3D
		).basis.orthonormalized(),
		"joint_zero_source": &"authoring_baseline_animation_t0_parent_local_pose",
		"alignment_offset_hand_local": alignment_offset,
		"contact_axis_local": axis_hand_local,
		"target_alignment_skeleton": target_alignment,
		"desired_contact_axis_skeleton": target_axis,
		"target_hand_basis_skeleton": target_hand.basis.orthonormalized(),
		"require_full_hand_basis": primary,
		"skeleton_global_basis": base_context.get(
			"skeleton_global_basis",
			Basis.IDENTITY
		),
		"shoulder_min_degrees": base_context.get("shoulder_min_degrees", 8.0),
		"shoulder_max_degrees": base_context.get("shoulder_max_degrees", 155.0),
		"elbow_min_degrees": base_context.get("elbow_min_degrees", 20.0),
		"elbow_max_degrees": base_context.get("elbow_max_degrees", 168.0),
	}


func _find_test_shared_arm_candidate(
	context: Dictionary,
	quick: bool
) -> Dictionary:
	var coarse_step: int = 15 if quick else 5
	var seed_limit: int = 4 if quick else 12
	var seeds: Array[Dictionary] = []
	for clavicle_degrees: float in [-10.0, -5.0, 0.0, 5.0]:
		for elbow_integer: int in range(0, 166, coarse_step):
			for wrist_integer: int in range(-90, 91, coarse_step):
				for order_id: StringName in [
					&"local_x_applied_then_local_z",
					&"local_z_applied_then_local_x",
				]:
					var candidate: Dictionary = _build_test_shared_arm_candidate(
						context,
						clavicle_degrees,
						float(elbow_integer),
						float(wrist_integer),
						order_id
					)
					_insert_test_support_contact_seed(seeds, candidate, seed_limit)
	if seeds.is_empty():
		return {}
	var refined: Array[Dictionary] = []
	var refinement_steps: Array = (
		[5.0, 1.0, 0.2]
		if quick
		else [2.0, 0.5, 0.1, 0.02, 0.005]
	)
	for seed: Dictionary in seeds:
		var best: Dictionary = seed.duplicate(true)
		var order_id: StringName = StringName(best.get("order_id", StringName()))
		for step_degrees: float in refinement_steps:
			var center_clavicle: float = float(best.get("clavicle_delta_degrees", 0.0))
			var center_elbow: float = float(best.get("elbow_hinge_degrees", 0.0))
			var center_wrist: float = float(best.get("wrist_hinge_degrees", 0.0))
			for clavicle_offset: int in range(-1, 2):
				for elbow_offset: int in range(-1, 2):
					for wrist_offset: int in range(-1, 2):
						var candidate: Dictionary = _build_test_shared_arm_candidate(
							context,
							clampf(
								center_clavicle + float(clavicle_offset) * step_degrees,
								-10.0,
								5.0
							),
							clampf(
								center_elbow + float(elbow_offset) * step_degrees,
								0.0,
								165.0
							),
							clampf(
								center_wrist + float(wrist_offset) * step_degrees,
								-90.0,
								90.0
							),
							order_id
						)
						if _test_shared_arm_candidate_better(candidate, best):
							best = candidate
		_insert_test_support_contact_seed(refined, best, seed_limit)
	return refined[0] if not refined.is_empty() else seeds[0]


func _build_test_shared_arm_candidate(
	context: Dictionary,
	clavicle_degrees: float,
	elbow_degrees: float,
	wrist_degrees: float,
	order_id: StringName
) -> Dictionary:
	var candidate: Dictionary = _build_test_support_contact_space_candidate(
		context,
		clavicle_degrees,
		elbow_degrees,
		wrist_degrees,
		order_id
	)
	if not bool(candidate.get("valid", false)):
		return candidate
	var spine_global: Transform3D = context.get(
		"spine_global",
		Transform3D.IDENTITY
	) as Transform3D
	var clavicle_pose := Transform3D(
		candidate.get("candidate_clavicle_local_basis", Basis.IDENTITY) as Basis,
		context.get("clavicle_pose_origin", Vector3.ZERO) as Vector3
	)
	var upperarm_pose := Transform3D(
		candidate.get("candidate_upperarm_local_basis", Basis.IDENTITY) as Basis,
		context.get("upperarm_pose_origin", Vector3.ZERO) as Vector3
	)
	var forearm_pose := Transform3D(
		candidate.get("candidate_forearm_local_basis", Basis.IDENTITY) as Basis,
		context.get("forearm_pose_origin", Vector3.ZERO) as Vector3
	)
	var hand_pose := Transform3D(
		candidate.get("candidate_hand_local_basis", Basis.IDENTITY) as Basis,
		context.get("hand_pose_origin", Vector3.ZERO) as Vector3
	)
	var predicted_hand: Transform3D = (
		spine_global * clavicle_pose * upperarm_pose * forearm_pose * hand_pose
	)
	var target_hand_basis: Basis = context.get(
		"target_hand_basis_skeleton",
		Basis.IDENTITY
	) as Basis
	var hand_basis_error: float = _resolve_test_basis_delta_degrees(
		predicted_hand.basis,
		target_hand_basis
	)
	var require_full_basis: bool = bool(context.get(
		"require_full_hand_basis",
		false
	))
	var documented_elbow_legal: bool = (
		elbow_degrees >= -0.0001 and elbow_degrees <= 165.0001
	)
	var shared_arm_exact: bool = (
		bool(candidate.get("exact_joint_legal", false))
		and documented_elbow_legal
		and (not require_full_basis or hand_basis_error <= 0.05)
	)
	var shared_arm_score: float = float(candidate.get("search_score", INF))
	if require_full_basis:
		shared_arm_score += hand_basis_error / 0.05
	if not documented_elbow_legal:
		shared_arm_score += 1000000.0
	candidate["predicted_hand_skeleton"] = predicted_hand
	candidate["hand_basis_error_degrees"] = hand_basis_error
	candidate["require_full_hand_basis"] = require_full_basis
	candidate["documented_elbow_hinge_legal"] = documented_elbow_legal
	candidate["shared_arm_exact"] = shared_arm_exact
	candidate["shared_arm_score"] = shared_arm_score
	candidate["search_score"] = shared_arm_score
	candidate["status"] = (
		&"test_shared_arm_candidate_exact"
		if shared_arm_exact
		else &"test_shared_arm_candidate_approximate"
	)
	return candidate


func _test_shared_arm_candidate_better(
	candidate: Dictionary,
	incumbent: Dictionary
) -> bool:
	if not bool(candidate.get("valid", false)):
		return false
	if not bool(incumbent.get("valid", false)):
		return true
	var candidate_exact: bool = bool(candidate.get("shared_arm_exact", false))
	var incumbent_exact: bool = bool(incumbent.get("shared_arm_exact", false))
	if candidate_exact != incumbent_exact:
		return candidate_exact
	return float(candidate.get("shared_arm_score", INF)) < float(
		incumbent.get("shared_arm_score", INF)
	)


func _insert_test_shared_torso_seed(
	seeds: Array[Dictionary],
	candidate: Dictionary,
	maximum_count: int
) -> void:
	if not bool(candidate.get("valid", false)):
		return
	var insert_at: int = seeds.size()
	for index: int in range(seeds.size()):
		if _test_shared_torso_candidate_better(candidate, seeds[index]):
			insert_at = index
			break
	seeds.insert(insert_at, candidate)
	if seeds.size() > maximum_count:
		seeds.resize(maximum_count)


func _insert_test_shared_torso_metric_seed(
	seeds: Array[Dictionary],
	candidate: Dictionary,
	arm_role: String,
	maximum_count: int
) -> void:
	if (
		arm_role not in ["primary", "support"]
		or not bool(candidate.get("valid", false))
	):
		return
	var insert_at: int = seeds.size()
	for index: int in range(seeds.size()):
		if _test_shared_torso_metric_better(candidate, seeds[index], arm_role):
			insert_at = index
			break
	seeds.insert(insert_at, candidate)
	if seeds.size() > maximum_count:
		seeds.resize(maximum_count)


func _test_shared_torso_metric_better(
	candidate: Dictionary,
	incumbent: Dictionary,
	arm_role: String
) -> bool:
	if not bool(candidate.get("valid", false)):
		return false
	if not bool(incumbent.get("valid", false)):
		return true
	var candidate_arm: Dictionary = candidate.get(
		arm_role + "_candidate",
		{}
	) as Dictionary
	var incumbent_arm: Dictionary = incumbent.get(
		arm_role + "_candidate",
		{}
	) as Dictionary
	var candidate_exact: bool = bool(candidate_arm.get("shared_arm_exact", false))
	var incumbent_exact: bool = bool(incumbent_arm.get("shared_arm_exact", false))
	if candidate_exact != incumbent_exact:
		return candidate_exact
	var candidate_score: float = float(candidate_arm.get("shared_arm_score", INF))
	var incumbent_score: float = float(incumbent_arm.get("shared_arm_score", INF))
	if absf(candidate_score - incumbent_score) > 0.0000001:
		return candidate_score < incumbent_score
	return float(candidate.get("torso_deviation", INF)) < float(
		incumbent.get("torso_deviation", INF)
	)


func _refine_test_shared_torso_for_metric(
	base_context: Dictionary,
	seed: Dictionary,
	arm_role: String
) -> Dictionary:
	var best: Dictionary = seed.duplicate(true)
	for torso_step: float in [2.5, 0.5, 0.1, 0.02]:
		var center_01: float = float(best.get("spine_01_degrees", 0.0))
		var center_02: float = float(best.get("spine_02_degrees", 0.0))
		for offset_01: int in range(-1, 2):
			for offset_02: int in range(-1, 2):
				var candidate: Dictionary = _evaluate_test_shared_torso_candidate(
					base_context,
					clampf(center_01 + float(offset_01) * torso_step, -35.0, 35.0),
					clampf(center_02 + float(offset_02) * torso_step, -55.0, 55.0),
					true
				)
				if _test_shared_torso_metric_better(candidate, best, arm_role):
					best = candidate
	return best


func _test_shared_torso_candidate_better(
	candidate: Dictionary,
	incumbent: Dictionary
) -> bool:
	if not bool(candidate.get("valid", false)):
		return false
	if not bool(incumbent.get("valid", false)):
		return true
	var candidate_exact: bool = bool(candidate.get("exact", false))
	var incumbent_exact: bool = bool(incumbent.get("exact", false))
	if candidate_exact != incumbent_exact:
		return candidate_exact
	if candidate_exact:
		var candidate_deviation: float = float(candidate.get("torso_deviation", INF))
		var incumbent_deviation: float = float(incumbent.get("torso_deviation", INF))
		if absf(candidate_deviation - incumbent_deviation) > 0.0000001:
			return candidate_deviation < incumbent_deviation
	return float(candidate.get("combined_score", INF)) < float(
		incumbent.get("combined_score", INF)
	)


func _compact_test_shared_torso_candidate(candidate: Dictionary) -> Dictionary:
	if not bool(candidate.get("valid", false)):
		return candidate.duplicate(true)
	return {
		"valid": true,
		"status": candidate.get("status", StringName()),
		"exact": candidate.get("exact", false),
		"spine_01_degrees": candidate.get("spine_01_degrees", NAN),
		"spine_02_degrees": candidate.get("spine_02_degrees", NAN),
		"torso_deviation": candidate.get("torso_deviation", INF),
		"combined_score": candidate.get("combined_score", INF),
		"primary": _compact_test_shared_arm_candidate(
			candidate.get("primary_candidate", {}) as Dictionary
		),
		"support": _compact_test_shared_arm_candidate(
			candidate.get("support_candidate", {}) as Dictionary
		),
	}


func _compact_test_shared_arm_candidate(candidate: Dictionary) -> Dictionary:
	if not bool(candidate.get("valid", false)):
		return candidate.duplicate(true)
	return {
		"valid": true,
		"status": candidate.get("status", StringName()),
		"exact": candidate.get("shared_arm_exact", false),
		"order_id": candidate.get("order_id", StringName()),
		"clavicle_degrees": candidate.get("clavicle_delta_degrees", NAN),
		"shoulder_x_degrees": candidate.get("shoulder_x_degrees", NAN),
		"shoulder_z_degrees": candidate.get("shoulder_z_degrees", NAN),
		"elbow_x_degrees": candidate.get("elbow_hinge_degrees", NAN),
		"wrist_z_degrees": candidate.get("wrist_hinge_degrees", NAN),
		"physical_shoulder_angle_degrees": candidate.get("shoulder_angle_degrees", NAN),
		"physical_elbow_angle_degrees": candidate.get("elbow_angle_degrees", NAN),
		"endpoint_error_meters": candidate.get("endpoint_error_meters", INF),
		"source_vector_length_skeleton": candidate.get(
			"source_vector_length_skeleton",
			NAN
		),
		"target_vector_length_skeleton": candidate.get(
			"target_vector_length_skeleton",
			NAN
		),
		"axis_error_degrees": candidate.get("contact_axis_error_degrees", INF),
		"hand_basis_error_degrees": candidate.get("hand_basis_error_degrees", INF),
		"shoulder_decomposition_error_degrees": candidate.get(
			"shoulder_decomposition_error_degrees",
			INF
		),
		"joint_range_legal": candidate.get("joint_range_legal", false),
		"documented_elbow_hinge_legal": candidate.get(
			"documented_elbow_hinge_legal",
			false
		),
		"score": candidate.get("shared_arm_score", INF),
	}


func _resolve_test_transform_error(
	actual: Transform3D,
	expected: Transform3D
) -> Dictionary:
	return {
		"position_error_meters": actual.origin.distance_to(expected.origin),
		"basis_error_degrees": _resolve_test_basis_delta_degrees(
			actual.basis,
			expected.basis
		),
	}


func _apply_and_validate_test_shared_torso_candidate(
	presenter: Object,
	actor: Node3D,
	held: Node3D,
	transaction_snapshot: Dictionary,
	seated_snapshot: Dictionary,
	support_anchor: Node3D,
	skeleton: Skeleton3D,
	bone_indices: Dictionary,
	bone_names: Dictionary,
	zero_poses: Array,
	original_pose_packet: Array[Transform3D],
	original_weapon_world: Transform3D,
	primary_slot_id: StringName,
	support_slot_id: StringName,
	primary_target_hand_world: Transform3D,
	support_target_center_world: Vector3,
	support_target_axis_world: Vector3,
	candidate: Dictionary
) -> Dictionary:
	var result := {
		"valid": false,
		"exact": false,
		"status": &"test_shared_torso_dual_arm_apply_unavailable",
	}
	if not bool(candidate.get("valid", false)):
		return result
	if not bool(presenter.call(
		"_restore_preview_support_candidate_baseline",
		actor,
		held,
		support_anchor,
		seated_snapshot,
		support_slot_id,
		primary_slot_id
	)):
		result["status"] = &"test_shared_torso_dual_arm_apply_restore_failed"
		return result
	var spine_01_index: int = int(bone_indices["spine_01"])
	var spine_02_index: int = int(bone_indices["spine_02"])
	var spine_01_zero: Transform3D = zero_poses[spine_01_index]
	var spine_02_zero: Transform3D = zero_poses[spine_02_index]
	var spine_01_basis: Basis = (
		spine_01_zero.basis.orthonormalized()
		* Basis(Vector3.UP, deg_to_rad(float(candidate["spine_01_degrees"])))
	).orthonormalized()
	var spine_02_basis: Basis = (
		spine_02_zero.basis.orthonormalized()
		* Basis(Vector3.UP, deg_to_rad(float(candidate["spine_02_degrees"])))
	).orthonormalized()
	skeleton.set_bone_pose_rotation(
		spine_01_index,
		spine_01_basis.get_rotation_quaternion()
	)
	skeleton.set_bone_pose_rotation(
		spine_02_index,
		spine_02_basis.get_rotation_quaternion()
	)
	var expected_local_bases := {
		"spine_01": spine_01_basis,
		"spine_02": spine_02_basis,
	}
	for arm_role: String in ["primary", "support"]:
		var slot_id: StringName = primary_slot_id if arm_role == "primary" else support_slot_id
		var prefix: String = "left" if slot_id == &"hand_left" else "right"
		var arm_candidate: Dictionary = candidate.get(
			arm_role + "_candidate",
			{}
		) as Dictionary
		for bone_part: String in ["clavicle", "upperarm", "forearm", "hand"]:
			var candidate_basis_key: String = "candidate_" + bone_part + "_local_basis"
			var local_basis: Basis = arm_candidate.get(
				candidate_basis_key,
				Basis.IDENTITY
			) as Basis
			var bone_key: String = prefix + "_" + bone_part
			var bone_index: int = int(bone_indices[bone_key])
			skeleton.set_bone_pose_rotation(
				bone_index,
				local_basis.orthonormalized().get_rotation_quaternion()
			)
			expected_local_bases[bone_key] = local_basis.orthonormalized()
	skeleton.force_update_all_bone_transforms()
	var local_basis_errors: Dictionary = {}
	var max_local_basis_error: float = 0.0
	var local_origin_errors: Dictionary = {}
	var max_local_origin_error: float = 0.0
	for bone_key_variant: Variant in expected_local_bases:
		var bone_key: String = String(bone_key_variant)
		var bone_index: int = int(bone_indices[bone_key])
		var expected_basis: Basis = expected_local_bases[bone_key]
		var basis_error: float = _resolve_test_basis_delta_degrees(
			skeleton.get_bone_pose(bone_index).basis,
			expected_basis
		)
		local_basis_errors[bone_names[bone_key]] = basis_error
		max_local_basis_error = maxf(max_local_basis_error, basis_error)
		var zero_pose: Transform3D = zero_poses[bone_index]
		var origin_error: float = skeleton.get_bone_pose(bone_index).origin.distance_to(
			zero_pose.origin
		)
		local_origin_errors[bone_names[bone_key]] = origin_error
		max_local_origin_error = maxf(max_local_origin_error, origin_error)
	var primary_prefix: String = "left" if primary_slot_id == &"hand_left" else "right"
	var primary_hand_index: int = int(bone_indices[primary_prefix + "_hand"])
	var primary_actual_world: Transform3D = (
		skeleton.global_transform * skeleton.get_bone_global_pose(primary_hand_index)
	)
	var primary_error: Dictionary = _resolve_test_transform_error(
		primary_actual_world,
		primary_target_hand_world
	)
	var weapon_error: Dictionary = _resolve_test_transform_error(
		held.global_transform,
		original_weapon_world
	)
	var support_contact: Dictionary = _resolve_test_contact_geometry_match(
		actor,
		support_slot_id,
		support_target_center_world,
		support_target_axis_world
	)
	var primary_physical: Dictionary = _resolve_test_shared_arm_physical_angles(
		skeleton,
		bone_indices,
		primary_prefix,
		float(actor.get("authoring_shoulder_min_plane_angle_degrees")),
		float(actor.get("authoring_shoulder_max_plane_angle_degrees")),
		float(actor.get("authoring_elbow_min_plane_angle_degrees")),
		float(actor.get("authoring_elbow_max_plane_angle_degrees"))
	)
	var support_prefix: String = "left" if support_slot_id == &"hand_left" else "right"
	var support_physical: Dictionary = _resolve_test_shared_arm_physical_angles(
		skeleton,
		bone_indices,
		support_prefix,
		float(actor.get("authoring_shoulder_min_plane_angle_degrees")),
		float(actor.get("authoring_shoulder_max_plane_angle_degrees")),
		float(actor.get("authoring_elbow_min_plane_angle_degrees")),
		float(actor.get("authoring_elbow_max_plane_angle_degrees"))
	)
	var torso_legal: bool = (
		float(candidate["spine_01_degrees"]) >= -35.0001
		and float(candidate["spine_01_degrees"]) <= 35.0001
		and float(candidate["spine_02_degrees"]) >= -55.0001
		and float(candidate["spine_02_degrees"]) <= 55.0001
	)
	var primary_candidate: Dictionary = candidate.get("primary_candidate", {}) as Dictionary
	var support_candidate: Dictionary = candidate.get("support_candidate", {}) as Dictionary
	var documented_joint_legal: bool = (
		bool(primary_candidate.get("joint_range_legal", false))
		and bool(primary_candidate.get("documented_elbow_hinge_legal", false))
		and bool(support_candidate.get("joint_range_legal", false))
		and bool(support_candidate.get("documented_elbow_hinge_legal", false))
	)
	var source_origins_valid: bool = (
		StringName(support_contact.get("index_point_source_origin_id", StringName()))
			== (&"CC_Base_L_Index1" if support_slot_id == &"hand_left" else &"CC_Base_R_Index1")
		and StringName(support_contact.get("pinky_point_source_origin_id", StringName()))
			== (&"CC_Base_L_Pinky1" if support_slot_id == &"hand_left" else &"CC_Base_R_Pinky1")
	)
	var body_gate: Dictionary = presenter.call(
		"_evaluate_preview_support_body_self_collision_delta",
		actor,
		transaction_snapshot,
		support_slot_id
	) as Dictionary
	var exact: bool = (
		bool(candidate.get("exact", false))
		and torso_legal
		and documented_joint_legal
		and bool(primary_physical.get("legal", false))
		and bool(support_physical.get("legal", false))
		# Godot's float Quaternion -> Basis round trip resolves at about 0.0396°
		# in this rig. Keep the same 0.05° verifier tolerance used by the solver.
		and max_local_basis_error <= 0.05
		and max_local_origin_error <= 0.0000001
		and float(primary_error.get("position_error_meters", INF)) <= 0.00005
		and float(primary_error.get("basis_error_degrees", INF)) <= 0.05
		and float(weapon_error.get("position_error_meters", INF)) <= 0.0000001
		and float(weapon_error.get("basis_error_degrees", INF)) <= 0.0001
		and bool(support_contact.get("matches", false))
		and source_origins_valid
	)
	result.merge({
		"valid": true,
		"exact": exact,
		"status": (
			&"test_shared_torso_dual_arm_apply_exact"
			if exact
			else &"test_shared_torso_dual_arm_apply_mismatch"
		),
		"candidate_exact_before_apply": candidate.get("exact", false),
		"torso_legal": torso_legal,
		"documented_joint_legal": documented_joint_legal,
		"local_basis_errors_degrees": local_basis_errors,
		"max_local_basis_error_degrees": max_local_basis_error,
		"local_origin_errors_parent_local": local_origin_errors,
		"max_local_origin_error_parent_local": max_local_origin_error,
		"primary_hand_error": primary_error,
		"primary_hand_source_origin_id": bone_names[primary_prefix + "_hand"],
		"weapon_error": weapon_error,
		"weapon_origin_id": &"WeaponRootOrigin",
		"support_contact": support_contact,
		"source_origins_valid": source_origins_valid,
		"primary_physical_angles": primary_physical,
		"support_physical_angles": support_physical,
		"body_gate": body_gate,
		"body_gate_reported_separately_from_kinematic_exactness": true,
	}, true)
	for restore_index: int in range(mini(
		original_pose_packet.size(),
		skeleton.get_bone_count()
	)):
		var restore_pose: Transform3D = original_pose_packet[restore_index]
		skeleton.set_bone_pose_position(restore_index, restore_pose.origin)
		skeleton.set_bone_pose_rotation(
			restore_index,
			restore_pose.basis.orthonormalized().get_rotation_quaternion()
		)
		skeleton.set_bone_pose_scale(restore_index, restore_pose.basis.get_scale())
	skeleton.force_update_all_bone_transforms()
	return result


func _resolve_test_shared_arm_physical_angles(
	skeleton: Skeleton3D,
	bone_indices: Dictionary,
	prefix: String,
	shoulder_min: float,
	shoulder_max: float,
	elbow_min: float,
	elbow_max: float
) -> Dictionary:
	var clavicle_index: int = int(bone_indices.get(prefix + "_clavicle", -1))
	var upperarm_index: int = int(bone_indices.get(prefix + "_upperarm", -1))
	var forearm_index: int = int(bone_indices.get(prefix + "_forearm", -1))
	var hand_index: int = int(bone_indices.get(prefix + "_hand", -1))
	if min(clavicle_index, upperarm_index, forearm_index, hand_index) < 0:
		return {"valid": false, "legal": false}
	var clavicle_position: Vector3 = skeleton.get_bone_global_pose(clavicle_index).origin
	var shoulder_position: Vector3 = skeleton.get_bone_global_pose(upperarm_index).origin
	var elbow_position: Vector3 = skeleton.get_bone_global_pose(forearm_index).origin
	var hand_position: Vector3 = skeleton.get_bone_global_pose(hand_index).origin
	var shoulder_parent: Vector3 = clavicle_position - shoulder_position
	var shoulder_child: Vector3 = elbow_position - shoulder_position
	var elbow_parent: Vector3 = shoulder_position - elbow_position
	var elbow_child: Vector3 = hand_position - elbow_position
	if (
		shoulder_parent.length_squared() <= 0.000000000001
		or shoulder_child.length_squared() <= 0.000000000001
		or elbow_parent.length_squared() <= 0.000000000001
		or elbow_child.length_squared() <= 0.000000000001
	):
		return {"valid": false, "legal": false}
	var shoulder_degrees: float = rad_to_deg(acos(clampf(
		shoulder_parent.normalized().dot(shoulder_child.normalized()),
		-1.0,
		1.0
	)))
	var elbow_degrees: float = rad_to_deg(acos(clampf(
		elbow_parent.normalized().dot(elbow_child.normalized()),
		-1.0,
		1.0
	)))
	return {
		"valid": true,
		"legal": (
			shoulder_degrees >= shoulder_min - 0.001
			and shoulder_degrees <= shoulder_max + 0.001
			and elbow_degrees >= elbow_min - 0.001
			and elbow_degrees <= elbow_max + 0.001
		),
		"shoulder_degrees": shoulder_degrees,
		"shoulder_min_degrees": shoulder_min,
		"shoulder_max_degrees": shoulder_max,
		"elbow_degrees": elbow_degrees,
		"elbow_min_degrees": elbow_min,
		"elbow_max_degrees": elbow_max,
		"point_origin_id": &"RL_BoneRoot",
	}


func _resolve_test_current_arm_contract_state(
	skeleton: Skeleton3D,
	bone_indices: Dictionary,
	zero_poses: Array,
	slot_id: StringName,
	shoulder_min: float,
	shoulder_max: float,
	elbow_min: float,
	elbow_max: float
) -> Dictionary:
	var invalid := {
		"valid": false,
		"legal": false,
		"status": &"test_current_arm_contract_unavailable",
		"zero_source": &"authoring_baseline_animation_t0_parent_local_pose",
	}
	if skeleton == null or slot_id not in [&"hand_right", &"hand_left"]:
		return invalid
	var left_side: bool = slot_id == &"hand_left"
	var prefix: String = "left" if left_side else "right"
	var clavicle_index: int = int(bone_indices.get(prefix + "_clavicle", -1))
	var upperarm_index: int = int(bone_indices.get(prefix + "_upperarm", -1))
	var forearm_index: int = int(bone_indices.get(prefix + "_forearm", -1))
	var hand_index: int = int(bone_indices.get(prefix + "_hand", -1))
	if (
		min(clavicle_index, upperarm_index, forearm_index, hand_index) < 0
		or hand_index >= zero_poses.size()
	):
		return invalid
	var clavicle_state: Dictionary = _resolve_test_local_axis_delta(
		(zero_poses[clavicle_index] as Transform3D).basis,
		skeleton.get_bone_pose(clavicle_index).basis,
		&"local_x"
	)
	var shoulder_delta: Basis = (
		(zero_poses[upperarm_index] as Transform3D).basis.orthonormalized().inverse()
		* skeleton.get_bone_pose(upperarm_index).basis.orthonormalized()
	).orthonormalized()
	var shoulder_orders: Array[Dictionary] = []
	for order_id: StringName in [
		&"local_x_applied_then_local_z",
		&"local_z_applied_then_local_x",
	]:
		var decomposition: Dictionary = _decompose_test_documented_shoulder_basis(
			shoulder_delta,
			order_id
		)
		decomposition["order_id"] = order_id
		var z_degrees: float = float(decomposition.get("shoulder_z_degrees", NAN))
		if absf(absf(z_degrees) - 180.0) <= 0.0001:
			z_degrees = -180.0 if left_side else 180.0
		decomposition["shoulder_z_degrees"] = z_degrees
		decomposition["side_range_legal"] = (
			z_degrees >= -180.0001 and z_degrees <= 0.0001
			if left_side
			else z_degrees >= -0.0001 and z_degrees <= 180.0001
		)
		shoulder_orders.append(decomposition)
	shoulder_orders.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_legal: bool = bool(a.get("side_range_legal", false))
		var b_legal: bool = bool(b.get("side_range_legal", false))
		if a_legal != b_legal:
			return a_legal
		return float(a.get("basis_error_degrees", INF)) < float(
			b.get("basis_error_degrees", INF)
		)
	)
	var shoulder_state: Dictionary = (
		shoulder_orders[0] if not shoulder_orders.is_empty() else {}
	)
	var elbow_state: Dictionary = _resolve_test_local_axis_delta(
		(zero_poses[forearm_index] as Transform3D).basis,
		skeleton.get_bone_pose(forearm_index).basis,
		&"local_x"
	)
	var wrist_state: Dictionary = _resolve_test_local_axis_delta(
		(zero_poses[hand_index] as Transform3D).basis,
		skeleton.get_bone_pose(hand_index).basis,
		&"local_z"
	)
	var physical: Dictionary = _resolve_test_shared_arm_physical_angles(
		skeleton,
		bone_indices,
		prefix,
		shoulder_min,
		shoulder_max,
		elbow_min,
		elbow_max
	)
	var clavicle_degrees: float = float(clavicle_state.get("degrees", NAN))
	var elbow_degrees: float = float(elbow_state.get("degrees", NAN))
	var wrist_degrees: float = float(wrist_state.get("degrees", NAN))
	var legal: bool = (
		bool(clavicle_state.get("valid", false))
		and float(clavicle_state.get("basis_error_degrees", INF)) <= 0.05
		and clavicle_degrees >= -10.0001
		and clavicle_degrees <= 5.0001
		and bool(shoulder_state.get("valid", false))
		and float(shoulder_state.get("basis_error_degrees", INF)) <= 0.05
		and bool(shoulder_state.get("side_range_legal", false))
		and bool(elbow_state.get("valid", false))
		and float(elbow_state.get("basis_error_degrees", INF)) <= 0.05
		and elbow_degrees >= -0.0001
		and elbow_degrees <= 165.0001
		and bool(wrist_state.get("valid", false))
		and float(wrist_state.get("basis_error_degrees", INF)) <= 0.05
		and wrist_degrees >= -90.0001
		and wrist_degrees <= 90.0001
		and bool(physical.get("legal", false))
	)
	return {
		"valid": true,
		"legal": legal,
		"status": (
			&"test_current_arm_contract_legal"
			if legal
			else &"test_current_arm_contract_illegal"
		),
		"slot_id": slot_id,
		"zero_source": &"authoring_baseline_animation_t0_parent_local_pose",
		"clavicle": clavicle_state,
		"shoulder": shoulder_state,
		"shoulder_all_orders": shoulder_orders,
		"elbow": elbow_state,
		"wrist": wrist_state,
		"physical_angles": physical,
	}


func _resolve_test_current_torso_contract_state(
	skeleton: Skeleton3D,
	bone_indices: Dictionary,
	zero_poses: Array
) -> Dictionary:
	var invalid := {
		"valid": false,
		"legal": false,
		"status": &"test_current_torso_contract_unavailable",
		"zero_source": &"authoring_baseline_animation_t0_parent_local_pose",
	}
	if skeleton == null:
		return invalid
	var spine_01_index: int = int(bone_indices.get("spine_01", -1))
	var spine_02_index: int = int(bone_indices.get("spine_02", -1))
	if (
		spine_01_index < 0
		or spine_02_index < 0
		or spine_02_index >= zero_poses.size()
	):
		return invalid
	var spine_01_state: Dictionary = _resolve_test_local_axis_delta(
		(zero_poses[spine_01_index] as Transform3D).basis,
		skeleton.get_bone_pose(spine_01_index).basis,
		&"local_y"
	)
	var spine_02_state: Dictionary = _resolve_test_local_axis_delta(
		(zero_poses[spine_02_index] as Transform3D).basis,
		skeleton.get_bone_pose(spine_02_index).basis,
		&"local_y"
	)
	var spine_01_degrees: float = float(spine_01_state.get("degrees", NAN))
	var spine_02_degrees: float = float(spine_02_state.get("degrees", NAN))
	var legal: bool = (
		bool(spine_01_state.get("valid", false))
		and float(spine_01_state.get("basis_error_degrees", INF)) <= 0.05
		and spine_01_degrees >= -35.0001
		and spine_01_degrees <= 35.0001
		and bool(spine_02_state.get("valid", false))
		and float(spine_02_state.get("basis_error_degrees", INF)) <= 0.05
		and spine_02_degrees >= -55.0001
		and spine_02_degrees <= 55.0001
	)
	return {
		"valid": true,
		"legal": legal,
		"status": (
			&"test_current_torso_contract_legal"
			if legal
			else &"test_current_torso_contract_illegal"
		),
		"zero_source": &"authoring_baseline_animation_t0_parent_local_pose",
		"spine_01": spine_01_state,
		"spine_01_range_degrees": Vector2(-35.0, 35.0),
		"spine_02": spine_02_state,
		"spine_02_range_degrees": Vector2(-55.0, 55.0),
	}


func _resolve_test_local_axis_delta(
	zero_basis_value: Basis,
	actual_basis_value: Basis,
	axis_id: StringName
) -> Dictionary:
	var zero_basis: Basis = zero_basis_value.orthonormalized()
	var actual_basis: Basis = actual_basis_value.orthonormalized()
	var delta: Basis = (zero_basis.inverse() * actual_basis).orthonormalized()
	var degrees: float = NAN
	var axis: Vector3 = Vector3.ZERO
	if axis_id == &"local_x":
		var rotated_up: Vector3 = delta * Vector3.UP
		degrees = wrapf(rad_to_deg(atan2(rotated_up.z, rotated_up.y)), -180.0, 180.0)
		axis = Vector3.RIGHT
	elif axis_id == &"local_y":
		var rotated_forward: Vector3 = delta * Vector3.BACK
		degrees = wrapf(rad_to_deg(atan2(rotated_forward.x, rotated_forward.z)), -180.0, 180.0)
		axis = Vector3.UP
	elif axis_id == &"local_z":
		var rotated_up: Vector3 = delta * Vector3.UP
		degrees = wrapf(rad_to_deg(atan2(-rotated_up.x, rotated_up.y)), -180.0, 180.0)
		axis = Vector3.BACK
	else:
		return {
			"valid": false,
			"axis_id": axis_id,
			"degrees": NAN,
			"basis_error_degrees": INF,
		}
	var reconstructed: Basis = Basis(axis, deg_to_rad(degrees)).orthonormalized()
	return {
		"valid": true,
		"axis_id": axis_id,
		"degrees": degrees,
		"basis_error_degrees": _resolve_test_basis_delta_degrees(
			delta,
			reconstructed
		),
	}


func _scan_test_support_contact_space_candidates(
	presenter: Object,
	actor: Node3D,
	held: Node3D,
	transaction_snapshot: Dictionary,
	support_slot_id: StringName,
	primary_slot_id: StringName
) -> Dictionary:
	var result := {
		"valid": false,
		"status": &"test_support_contact_space_scan_unavailable",
		"point_origin_id": &"RL_BoneRoot",
		"support_slot_id": support_slot_id,
		"primary_slot_id": primary_slot_id,
		"target_position_source": &"exact_seated_Index1_Pinky1_midpoint",
		"target_position_origin_id": &"RL_BoneRoot",
		"target_axis_source": &"exact_seated_Pinky1_to_Index1_axis",
		"target_axis_origin_id": &"RL_BoneRoot",
		"clavicle_zero_frame": &"authoring_baseline_animation_t0_parent_local_pose",
		"coarse_candidate_count": 0,
		"refined_candidate_count": 0,
		"exact_joint_legal_count": 0,
		"applied_exact_count": 0,
		"primary_weapon_legal_count": 0,
		"surface_identity_count": 0,
		"body_legal_count": 0,
		"digit_legal_count": 0,
		"full_legal_count": 0,
		"best_candidate": {},
		"best_applied_candidate": {},
		"full_legal_candidate": {},
		"candidate_summaries": [],
	}
	if (
		presenter == null
		or actor == null
		or held == null
		or not bool(transaction_snapshot.get("valid", false))
		or support_slot_id not in [&"hand_right", &"hand_left"]
		or primary_slot_id not in [&"hand_right", &"hand_left"]
		or support_slot_id == primary_slot_id
	):
		return result
	var skeleton: Skeleton3D = actor.get("skeleton") as Skeleton3D
	if skeleton == null:
		result["status"] = &"test_support_contact_space_skeleton_missing"
		return result
	var left_side: bool = support_slot_id == &"hand_left"
	var clavicle_bone: StringName = (
		&"CC_Base_L_Clavicle" if left_side else &"CC_Base_R_Clavicle"
	)
	var upperarm_bone: StringName = (
		&"CC_Base_L_Upperarm" if left_side else &"CC_Base_R_Upperarm"
	)
	var forearm_bone: StringName = (
		&"CC_Base_L_Forearm" if left_side else &"CC_Base_R_Forearm"
	)
	var hand_bone: StringName = (
		&"CC_Base_L_Hand" if left_side else &"CC_Base_R_Hand"
	)
	var clavicle_index: int = skeleton.find_bone(String(clavicle_bone))
	var upperarm_index: int = skeleton.find_bone(String(upperarm_bone))
	var forearm_index: int = skeleton.find_bone(String(forearm_bone))
	var hand_index: int = skeleton.find_bone(String(hand_bone))
	if (
		clavicle_index < 0
		or upperarm_index < 0
		or forearm_index < 0
		or hand_index < 0
		or skeleton.get_bone_parent(upperarm_index) != clavicle_index
		or skeleton.get_bone_parent(forearm_index) != upperarm_index
		or skeleton.get_bone_parent(hand_index) != forearm_index
	):
		result["status"] = &"test_support_contact_space_chain_invalid"
		return result
	var spine_index: int = skeleton.get_bone_parent(clavicle_index)
	if spine_index < 0:
		result["status"] = &"test_support_contact_space_spine_missing"
		return result
	var secondary_guide := held.get_node_or_null("SecondaryGripGuide") as Node3D
	var support_anchor := held.get_node_or_null("SupportGripAnchor") as Node3D
	if secondary_guide == null or support_anchor == null:
		result["status"] = &"test_support_contact_space_anchor_missing"
		return result
	var seated_snapshot: Dictionary = presenter.call(
		"_capture_preview_support_grip_transaction_snapshot",
		actor,
		held,
		support_anchor,
		support_slot_id,
		primary_slot_id
	) as Dictionary
	if not bool(seated_snapshot.get("valid", false)):
		result["status"] = &"test_support_contact_space_snapshot_failed"
		return result
	var baseline_clavicle_state: Dictionary = (
		_capture_test_authoring_baseline_bone_pose(
			presenter,
			actor,
			held,
			support_anchor,
			seated_snapshot,
			support_slot_id,
			primary_slot_id,
			clavicle_index,
			clavicle_bone
		)
	)
	if not bool(baseline_clavicle_state.get("valid", false)):
		result["status"] = baseline_clavicle_state.get(
			"status",
			&"test_support_contact_space_baseline_missing"
		)
		return result
	var baseline_clavicle_origin: Vector3 = baseline_clavicle_state.get(
		"origin",
		Vector3.ZERO
	) as Vector3
	var seated_clavicle_origin: Vector3 = skeleton.get_bone_pose(
		clavicle_index
	).origin
	var clavicle_origin_delta_parent_local: float = (
		baseline_clavicle_origin.distance_to(seated_clavicle_origin)
	)
	result["clavicle_origin_delta_parent_local"] = (
		clavicle_origin_delta_parent_local
	)
	result["clavicle_origin_parent_frame"] = skeleton.get_bone_name(spine_index)
	if clavicle_origin_delta_parent_local > 0.0000001:
		result["status"] = &"test_support_contact_space_clavicle_origin_changed"
		return result
	var baseline_bone_poses: Array = baseline_clavicle_state.get(
		"all_bone_poses_parent_local",
		[]
	) as Array
	if baseline_bone_poses.size() != skeleton.get_bone_count():
		result["status"] = &"test_support_contact_space_zero_packet_missing"
		return result
	var baseline_upperarm_pose: Transform3D = baseline_bone_poses[upperarm_index]
	var baseline_forearm_pose: Transform3D = baseline_bone_poses[forearm_index]
	var baseline_hand_pose: Transform3D = baseline_bone_poses[hand_index]
	for joint_origin_state: Dictionary in [
		{
			"bone": upperarm_bone,
			"baseline": baseline_upperarm_pose.origin,
			"seated": skeleton.get_bone_pose(upperarm_index).origin,
		},
		{
			"bone": forearm_bone,
			"baseline": baseline_forearm_pose.origin,
			"seated": skeleton.get_bone_pose(forearm_index).origin,
		},
		{
			"bone": hand_bone,
			"baseline": baseline_hand_pose.origin,
			"seated": skeleton.get_bone_pose(hand_index).origin,
		},
	]:
		var baseline_origin: Vector3 = joint_origin_state.get(
			"baseline",
			Vector3.ZERO
		)
		var seated_origin: Vector3 = joint_origin_state.get(
			"seated",
			Vector3.ZERO
		)
		if baseline_origin.distance_to(seated_origin) > 0.0000001:
			result["status"] = &"test_support_contact_space_joint_origin_changed"
			result["changed_origin_bone"] = joint_origin_state.get(
				"bone",
				StringName()
			)
			return result
	var current_hand_skeleton: Transform3D = skeleton.get_bone_global_pose(
		hand_index
	)
	var seated_anatomy: Dictionary = actor.call(
		"resolve_hand_surface_seat_anatomy_state",
		support_slot_id
	) as Dictionary
	if not bool(seated_anatomy.get("valid", false)):
		result["status"] = &"test_support_contact_space_anatomy_missing"
		return result
	var expected_index_bone: StringName = (
		&"CC_Base_L_Index1" if left_side else &"CC_Base_R_Index1"
	)
	var expected_pinky_bone: StringName = (
		&"CC_Base_L_Pinky1" if left_side else &"CC_Base_R_Pinky1"
	)
	if (
		StringName(seated_anatomy.get(
			"index_point_world_origin_id",
			StringName()
		)) != &"RL_BoneRoot"
		or StringName(seated_anatomy.get(
			"pinky_point_world_origin_id",
			StringName()
		)) != &"RL_BoneRoot"
		or StringName(seated_anatomy.get(
			"index_point_source_origin_id",
			StringName()
		)) != expected_index_bone
		or StringName(seated_anatomy.get(
			"pinky_point_source_origin_id",
			StringName()
		)) != expected_pinky_bone
	):
		result["status"] = &"test_support_contact_space_anatomy_origin_mismatch"
		return result
	var index_point_world: Vector3 = seated_anatomy.get(
		"index_point_world",
		Vector3.ZERO
	) as Vector3
	var pinky_point_world: Vector3 = seated_anatomy.get(
		"pinky_point_world",
		Vector3.ZERO
	) as Vector3
	var target_contact_center_world: Vector3 = index_point_world.lerp(
		pinky_point_world,
		0.5
	)
	var target_contact_axis_world: Vector3 = index_point_world - pinky_point_world
	var target_contact_center_skeleton: Vector3 = skeleton.to_local(
		target_contact_center_world
	)
	var target_contact_axis_skeleton: Vector3 = (
		skeleton.global_basis.inverse() * target_contact_axis_world
	).normalized()
	var contact_center_offset_hand_local: Vector3 = (
		current_hand_skeleton.affine_inverse()
		* target_contact_center_skeleton
	)
	var contact_axis_hand_local: Vector3 = (
		current_hand_skeleton.basis.orthonormalized().inverse()
		* target_contact_axis_skeleton
	).normalized()
	if (
		not target_contact_center_world.is_finite()
		or not target_contact_center_skeleton.is_finite()
		or not target_contact_axis_skeleton.is_finite()
		or not contact_center_offset_hand_local.is_finite()
		or not current_hand_skeleton.origin.is_finite()
		or not current_hand_skeleton.basis.x.is_finite()
		or not current_hand_skeleton.basis.y.is_finite()
		or not current_hand_skeleton.basis.z.is_finite()
		or target_contact_axis_world.length_squared() <= 0.000001
		or contact_axis_hand_local.length_squared() <= 0.000001
	):
		result["status"] = &"test_support_contact_space_target_invalid"
		return result
	target_contact_axis_world = target_contact_axis_world.normalized()
	actor.call(
		"invalidate_authoring_active_weapon_surface_seat",
		support_slot_id
	)
	var current_seat: Dictionary = actor.call(
		"resolve_exact_surface_weapon_seat",
		support_slot_id,
		true,
		false
	) as Dictionary
	var current_correction_state: Dictionary = presenter.call(
		"_resolve_preview_support_transaction_correction",
		current_seat,
		secondary_guide
	) as Dictionary
	var current_correction_local: Transform3D = current_correction_state.get(
		"correction_local",
		Transform3D.IDENTITY
	) as Transform3D
	var expected_execution_path_id: StringName = StringName(current_seat.get(
		"grip_execution_path_id",
		StringName()
	))
	var expected_surface_identity: Dictionary = (
		_resolve_test_exact_surface_identity_for_guide(
			actor,
			secondary_guide,
			expected_execution_path_id
		)
	)
	if (
		not bool(current_seat.get("valid", false))
		or int(current_seat.get("candidate_sample_index", -1)) != 0
		or not bool(current_correction_state.get("valid", false))
		or not bool(presenter.call(
			"_preview_support_correction_is_identity",
			current_correction_local
		))
		or expected_execution_path_id == StringName()
		or not bool(expected_surface_identity.get("valid", false))
	):
		result["status"] = &"test_support_contact_space_surface_identity_missing"
		result["expected_seat_status"] = current_seat.get(
			"status",
			StringName()
		)
		result["expected_seat_valid"] = bool(current_seat.get("valid", false))
		result["expected_seat_sample_index"] = int(current_seat.get(
			"candidate_sample_index",
			-1
		))
		result["expected_seat_correction_valid"] = bool(
			current_correction_state.get("valid", false)
		)
		result["expected_seat_correction_identity"] = (
			bool(current_correction_state.get("valid", false))
			and bool(presenter.call(
				"_preview_support_correction_is_identity",
				current_correction_local
			))
		)
		result["expected_execution_path_id"] = expected_execution_path_id
		result["expected_surface_identity_status"] = (
			expected_surface_identity.get("status", StringName())
		)
		return result
	var static_context := {
		"point_origin_id": &"RL_BoneRoot",
		"left_side": left_side,
		"skeleton_global_basis": skeleton.global_basis,
		"spine_global": skeleton.get_bone_global_pose(spine_index),
		"baseline_clavicle_basis": baseline_clavicle_state.get(
			"basis",
			Basis.IDENTITY
		),
		"clavicle_pose_origin": baseline_clavicle_state.get(
			"origin",
			Vector3.ZERO
		),
		"upperarm_pose_origin": skeleton.get_bone_pose(upperarm_index).origin,
		"forearm_pose_origin": skeleton.get_bone_pose(forearm_index).origin,
		"hand_pose_origin": skeleton.get_bone_pose(hand_index).origin,
		"upperarm_zero_basis": baseline_upperarm_pose.basis.orthonormalized(),
		"forearm_zero_basis": baseline_forearm_pose.basis.orthonormalized(),
		"hand_zero_basis": baseline_hand_pose.basis.orthonormalized(),
		"joint_zero_source": &"authoring_baseline_animation_t0_parent_local_pose",
		"alignment_offset_hand_local": contact_center_offset_hand_local,
		"contact_axis_local": contact_axis_hand_local,
		"target_alignment_skeleton": target_contact_center_skeleton,
		"desired_contact_axis_skeleton": target_contact_axis_skeleton,
		"shoulder_min_degrees": float(actor.get(
			"authoring_shoulder_min_plane_angle_degrees"
		)),
		"shoulder_max_degrees": float(actor.get(
			"authoring_shoulder_max_plane_angle_degrees"
		)),
		"elbow_min_degrees": float(actor.get(
			"authoring_elbow_min_plane_angle_degrees"
		)),
		"elbow_max_degrees": float(actor.get(
			"authoring_elbow_max_plane_angle_degrees"
		)),
	}
	result["clavicle_zero_animation_name"] = baseline_clavicle_state.get(
		"baseline_animation_name",
		StringName()
	)
	result["alignment_offset_hand_local"] = contact_center_offset_hand_local
	result["alignment_offset_origin_id"] = hand_bone
	result["alignment_offset_transform_chain"] = [hand_bone, &"RL_BoneRoot"]
	result["contact_axis_local"] = contact_axis_hand_local
	result["contact_axis_local_origin_id"] = hand_bone
	result["contact_axis_local_transform_chain"] = [hand_bone, &"RL_BoneRoot"]
	result["target_alignment_world"] = target_contact_center_world
	result["target_alignment_skeleton"] = target_contact_center_skeleton
	result["desired_contact_axis_world"] = target_contact_axis_world
	result["desired_contact_axis_skeleton"] = target_contact_axis_skeleton
	result["index_point_source_origin_id"] = seated_anatomy.get(
		"index_point_source_origin_id",
		StringName()
	)
	result["pinky_point_source_origin_id"] = seated_anatomy.get(
		"pinky_point_source_origin_id",
		StringName()
	)
	result["current_surface_context_key"] = String(current_seat.get(
		"context_key",
		""
	))

	var coarse_seeds: Array[Dictionary] = []
	for clavicle_integer: int in range(-10, 6):
		for elbow_integer: int in range(0, 169, 2):
			for wrist_integer: int in range(-90, 91, 2):
				for order_id: StringName in [
					&"local_x_applied_then_local_z",
					&"local_z_applied_then_local_x",
				]:
					var candidate: Dictionary = (
						_build_test_support_contact_space_candidate(
							static_context,
							float(clavicle_integer),
							float(elbow_integer),
							float(wrist_integer),
							order_id
						)
					)
					if not bool(candidate.get("valid", false)):
						continue
					result["coarse_candidate_count"] = (
						int(result["coarse_candidate_count"]) + 1
					)
					_insert_test_support_contact_seed(
						coarse_seeds,
						candidate,
						48
					)
	var refined_candidates: Array[Dictionary] = []
	for seed: Dictionary in coarse_seeds:
		var refined: Dictionary = _refine_test_support_contact_space_candidate(
			static_context,
			seed
		)
		_insert_test_support_contact_seed(refined_candidates, refined, 48)
	result["refined_candidate_count"] = refined_candidates.size()
	if not refined_candidates.is_empty():
		result["best_candidate"] = _compact_test_support_contact_candidate(
			refined_candidates[0]
		)

	var candidate_summaries: Array[Dictionary] = []
	for candidate: Dictionary in refined_candidates:
		if not bool(candidate.get("exact_joint_legal", false)):
			continue
		result["exact_joint_legal_count"] = (
			int(result["exact_joint_legal_count"]) + 1
		)
		if not bool(presenter.call(
			"_restore_preview_support_candidate_baseline",
			actor,
			held,
			support_anchor,
			seated_snapshot,
			support_slot_id,
			primary_slot_id
		)):
			result["status"] = &"test_support_contact_space_restore_failed"
			break
		var applied: Dictionary = _apply_test_support_contact_space_candidate(
			actor,
			support_slot_id,
			clavicle_index,
			upperarm_index,
			forearm_index,
			hand_index,
			baseline_clavicle_state.get("basis", Basis.IDENTITY) as Basis,
			target_contact_center_world,
			target_contact_axis_world,
			contact_axis_hand_local,
			candidate
		)
		var compact: Dictionary = _compact_test_support_contact_candidate(
			candidate
		)
		compact["applied"] = applied.duplicate(true)
		var applied_exact: bool = bool(applied.get("exact", false))
		if applied_exact:
			result["applied_exact_count"] = int(result["applied_exact_count"]) + 1
		var primary_weapon_unchanged: bool = bool(presenter.call(
			"_preview_support_primary_weapon_unit_matches_snapshot",
			held,
			transaction_snapshot,
			actor,
			primary_slot_id
		))
		compact["primary_weapon_unit_unchanged"] = primary_weapon_unchanged
		if primary_weapon_unchanged:
			result["primary_weapon_legal_count"] = (
				int(result["primary_weapon_legal_count"]) + 1
			)
		var surface_attempt: Dictionary = {}
		var surface_match_state: Dictionary = {
			"valid": false,
			"matches": false,
			"status": &"test_surface_recheck_skipped",
		}
		var surface_identity: bool = false
		if applied_exact and primary_weapon_unchanged:
			actor.call(
				"invalidate_authoring_active_weapon_surface_seat",
				support_slot_id
			)
			surface_attempt = actor.call(
				"resolve_exact_surface_weapon_seat",
				support_slot_id,
				true,
				false
			) as Dictionary
			var correction_state: Dictionary = presenter.call(
				"_resolve_preview_support_transaction_correction",
				surface_attempt,
				secondary_guide
			) as Dictionary
			var correction_local: Transform3D = correction_state.get(
				"correction_local",
				Transform3D.IDENTITY
			) as Transform3D
			var actual_surface_identity: Dictionary = (
				_resolve_test_exact_surface_identity_for_guide(
					actor,
					secondary_guide,
					expected_execution_path_id
				)
			)
			surface_match_state = _resolve_test_stable_surface_identity_match(
				current_seat,
				surface_attempt,
				expected_surface_identity,
				actual_surface_identity,
				secondary_guide
			)
			surface_match_state["sample_zero"] = (
				int(surface_attempt.get("candidate_sample_index", -1)) == 0
			)
			surface_match_state["correction_valid"] = bool(
				correction_state.get("valid", false)
			)
			surface_match_state["correction_identity"] = (
				bool(correction_state.get("valid", false))
				and bool(presenter.call(
					"_preview_support_correction_is_identity",
					correction_local
				))
			)
			surface_identity = (
				bool(surface_attempt.get("valid", false))
				and bool(surface_match_state.get("matches", false))
				and bool(surface_match_state.get("sample_zero", false))
				and bool(surface_match_state.get("correction_identity", false))
			)
		compact["surface_status"] = surface_attempt.get(
			"status",
			&"test_surface_recheck_skipped"
		)
		compact["surface_candidate_sample_index"] = int(surface_attempt.get(
			"candidate_sample_index",
			-1
		))
		compact["surface_stable_identity_state"] = surface_match_state
		compact["surface_identity"] = surface_identity
		if surface_identity:
			result["surface_identity_count"] = (
				int(result["surface_identity_count"]) + 1
			)
		var body_gate: Dictionary = {}
		if surface_identity:
			body_gate = presenter.call(
				"_evaluate_preview_support_body_self_collision_delta",
				actor,
				transaction_snapshot,
				support_slot_id
			) as Dictionary
		var body_legal: bool = (
			bool(body_gate.get("valid", false))
			and bool(body_gate.get("legal", false))
		)
		compact["body_status"] = body_gate.get(
			"status",
			&"test_body_recheck_skipped"
		)
		compact["body_legal"] = body_legal
		compact["body_rejected_pair_signature"] = body_gate.get(
			"rejected_pair_signature",
			""
		)
		if body_legal:
			result["body_legal_count"] = int(result["body_legal_count"]) + 1
		var digit_legal: bool = false
		if applied_exact and primary_weapon_unchanged and surface_identity and body_legal:
			actor.call(
				"invalidate_authoring_active_surface_grasp",
				support_slot_id
			)
			digit_legal = bool(actor.call(
				"apply_authoring_digit_grip_slot_now",
				support_slot_id,
				true
			))
		compact["digit_legal"] = digit_legal
		if digit_legal:
			result["digit_legal_count"] = int(result["digit_legal_count"]) + 1
		var final_primary_weapon_unchanged: bool = bool(presenter.call(
			"_preview_support_primary_weapon_unit_matches_snapshot",
			held,
			transaction_snapshot,
			actor,
			primary_slot_id
		))
		compact["final_primary_weapon_unit_unchanged"] = (
			final_primary_weapon_unchanged
		)
		var final_contact_state: Dictionary = {
			"valid": false,
			"matches": false,
			"status": &"test_final_contact_recheck_skipped",
		}
		var final_body_gate: Dictionary = {}
		if digit_legal and final_primary_weapon_unchanged:
			final_contact_state = _resolve_test_contact_geometry_match(
				actor,
				support_slot_id,
				target_contact_center_world,
				target_contact_axis_world
			)
			if bool(final_contact_state.get("matches", false)):
				final_body_gate = presenter.call(
					"_evaluate_preview_support_body_self_collision_delta",
					actor,
					transaction_snapshot,
					support_slot_id
				) as Dictionary
		var final_body_legal: bool = (
			bool(final_body_gate.get("valid", false))
			and bool(final_body_gate.get("legal", false))
		)
		compact["final_contact_state"] = final_contact_state
		compact["final_body_status"] = final_body_gate.get(
			"status",
			&"test_final_body_recheck_skipped"
		)
		compact["final_body_legal"] = final_body_legal
		var full_legal: bool = (
			applied_exact
			and primary_weapon_unchanged
			and surface_identity
			and body_legal
			and digit_legal
			and final_primary_weapon_unchanged
			and bool(final_contact_state.get("matches", false))
			and final_body_legal
		)
		compact["full_legal"] = full_legal
		candidate_summaries.append(compact)
		if result["best_applied_candidate"].is_empty():
			result["best_applied_candidate"] = compact.duplicate(true)
		if full_legal:
			result["full_legal_count"] = int(result["full_legal_count"]) + 1
			result["full_legal_candidate"] = compact.duplicate(true)
			break
	result["candidate_summaries"] = candidate_summaries
	var final_restore_ok: bool = bool(presenter.call(
		"_restore_preview_support_candidate_baseline",
		actor,
		held,
		support_anchor,
		seated_snapshot,
		support_slot_id,
		primary_slot_id
	))
	result["final_seated_snapshot_restored"] = final_restore_ok
	result["valid"] = final_restore_ok
	if not final_restore_ok:
		result["status"] = &"test_support_contact_space_final_restore_failed"
	elif int(result["full_legal_count"]) > 0:
		result["status"] = &"test_support_contact_space_full_legal_found"
	elif int(result["exact_joint_legal_count"]) > 0:
		result["status"] = &"test_support_contact_space_exact_joint_route_rejected"
	else:
		result["status"] = &"test_support_contact_space_no_exact_joint_route"
	return result


func _resolve_test_exact_surface_identity_for_guide(
	actor: Node3D,
	grip_guide: Node3D,
	execution_path_id: StringName
) -> Dictionary:
	var invalid := {
		"valid": false,
		"status": &"test_exact_surface_identity_unavailable",
	}
	if (
		actor == null
		or grip_guide == null
		or not is_instance_valid(grip_guide)
		or execution_path_id == StringName()
	):
		return invalid
	var finger_presenter: Object = actor.get("finger_grip_presenter") as Object
	if (
		finger_presenter == null
		or not finger_presenter.has_method("_resolve_grip_center_node")
		or not finger_presenter.has_method(
			"_resolve_exact_handle_surface_identity_state"
		)
	):
		return invalid
	var grip_center_node: Node3D = finger_presenter.call(
		"_resolve_grip_center_node",
		grip_guide
	) as Node3D
	if grip_center_node == null:
		invalid["status"] = &"test_exact_surface_grip_center_missing"
		return invalid
	return finger_presenter.call(
		"_resolve_exact_handle_surface_identity_state",
		grip_center_node,
		execution_path_id
	) as Dictionary


func _resolve_test_stable_surface_identity_match(
	expected_seat: Dictionary,
	actual_seat: Dictionary,
	expected_identity: Dictionary,
	actual_identity: Dictionary,
	grip_guide: Node3D
) -> Dictionary:
	var expected_diagnostics: Dictionary = expected_seat.get(
		"diagnostics",
		{}
	) as Dictionary
	var actual_diagnostics: Dictionary = actual_seat.get(
		"diagnostics",
		{}
	) as Dictionary
	var expected_path: StringName = StringName(expected_seat.get(
		"grip_execution_path_id",
		StringName()
	))
	var actual_path: StringName = StringName(actual_seat.get(
		"grip_execution_path_id",
		StringName()
	))
	var expected_surface_signature: String = String(expected_diagnostics.get(
		"surface_signature",
		""
	))
	var actual_surface_signature: String = String(actual_diagnostics.get(
		"surface_signature",
		""
	))
	var expected_authority: StringName = StringName(expected_diagnostics.get(
		"surface_authority",
		StringName()
	))
	var actual_authority: StringName = StringName(actual_diagnostics.get(
		"surface_authority",
		StringName()
	))
	var expected_origin: StringName = StringName(expected_diagnostics.get(
		"surface_origin_id",
		StringName()
	))
	var actual_origin: StringName = StringName(actual_diagnostics.get(
		"surface_origin_id",
		StringName()
	))
	var same_station_ratios: bool = true
	for ratio_field: String in [
		"grip_axis_ratio_from_span_start",
		"index_station_ratio_from_span_start",
		"pinky_station_ratio_from_span_start",
	]:
		var expected_ratio: float = float(expected_seat.get(ratio_field, INF))
		var actual_ratio: float = float(actual_seat.get(ratio_field, INF))
		if (
			not is_finite(expected_ratio)
			or not is_finite(actual_ratio)
			or absf(expected_ratio - actual_ratio) > 0.000001
		):
			same_station_ratios = false
			break
	var expected_guide_instance_id: int = (
		grip_guide.get_instance_id()
		if grip_guide != null and is_instance_valid(grip_guide)
		else 0
	)
	var same_source_guide: bool = (
		expected_guide_instance_id != 0
		and int(expected_seat.get("source_instance_id", 0))
			== expected_guide_instance_id
		and int(actual_seat.get("source_instance_id", 0))
			== expected_guide_instance_id
	)
	var expected_body_signature: String = String(expected_identity.get(
		"body_signature",
		""
	))
	var actual_body_signature: String = String(actual_identity.get(
		"body_signature",
		""
	))
	var expected_shape_id: int = int(expected_identity.get(
		"shape_resource_instance_id",
		0
	))
	var actual_shape_id: int = int(actual_identity.get(
		"shape_resource_instance_id",
		0
	))
	var expected_contact_origin: StringName = StringName(expected_identity.get(
		"contact_surface_origin_id",
		StringName()
	))
	var actual_contact_origin: StringName = StringName(actual_identity.get(
		"contact_surface_origin_id",
		StringName()
	))
	var matches: bool = (
		bool(expected_seat.get("valid", false))
		and bool(actual_seat.get("valid", false))
		and bool(expected_identity.get("valid", false))
		and bool(actual_identity.get("valid", false))
		and expected_path != StringName()
		and actual_path == expected_path
		and same_source_guide
		and not expected_surface_signature.is_empty()
		and actual_surface_signature == expected_surface_signature
		and expected_authority != StringName()
		and actual_authority == expected_authority
		and expected_origin == &"SupportGripContactSurfaceOrigin"
		and actual_origin == expected_origin
		and not expected_body_signature.is_empty()
		and actual_body_signature == expected_body_signature
		and expected_shape_id != 0
		and actual_shape_id == expected_shape_id
		and expected_contact_origin == expected_origin
		and actual_contact_origin == expected_contact_origin
		and same_station_ratios
	)
	return {
		"valid": true,
		"matches": matches,
		"status": (
			&"test_stable_surface_identity_matches"
			if matches
			else &"test_stable_surface_identity_mismatch"
		),
		"execution_path_matches": actual_path == expected_path,
		"source_guide_matches": same_source_guide,
		"surface_signature_matches": (
			not expected_surface_signature.is_empty()
			and actual_surface_signature == expected_surface_signature
		),
		"surface_authority_matches": (
			expected_authority != StringName()
			and actual_authority == expected_authority
		),
		"surface_origin_matches": (
			expected_origin == &"SupportGripContactSurfaceOrigin"
			and actual_origin == expected_origin
		),
		"body_signature_matches": (
			not expected_body_signature.is_empty()
			and actual_body_signature == expected_body_signature
		),
		"shape_resource_matches": (
			expected_shape_id != 0 and actual_shape_id == expected_shape_id
		),
		"contact_surface_origin_matches": (
			expected_contact_origin == expected_origin
			and actual_contact_origin == expected_contact_origin
		),
		"station_ratios_match": same_station_ratios,
		"context_key_intentionally_not_compared": true,
	}


func _resolve_test_contact_geometry_match(
	actor: Node3D,
	support_slot_id: StringName,
	target_contact_center_world: Vector3,
	target_contact_axis_world: Vector3
) -> Dictionary:
	var result := {
		"valid": false,
		"matches": false,
		"status": &"test_contact_geometry_unavailable",
		"point_origin_id": &"RL_BoneRoot",
	}
	if actor == null or not target_contact_axis_world.is_normalized():
		return result
	var anatomy: Dictionary = actor.call(
		"resolve_hand_surface_seat_anatomy_state",
		support_slot_id
	) as Dictionary
	if not bool(anatomy.get("valid", false)):
		result["status"] = &"test_contact_geometry_anatomy_missing"
		return result
	var index_world: Vector3 = anatomy.get("index_point_world", Vector3.ZERO)
	var pinky_world: Vector3 = anatomy.get("pinky_point_world", Vector3.ZERO)
	var center_world: Vector3 = index_world.lerp(pinky_world, 0.5)
	var axis_world: Vector3 = index_world - pinky_world
	if axis_world.length_squared() <= 0.000000000001:
		result["status"] = &"test_contact_geometry_axis_invalid"
		return result
	axis_world = axis_world.normalized()
	var center_error_meters: float = center_world.distance_to(
		target_contact_center_world
	)
	var axis_error_degrees: float = rad_to_deg(acos(clampf(
		axis_world.dot(target_contact_axis_world),
		-1.0,
		1.0
	)))
	var matches: bool = (
		center_error_meters <= 0.00005 and axis_error_degrees <= 0.05
	)
	result.merge({
		"valid": true,
		"matches": matches,
		"status": (
			&"test_contact_geometry_matches"
			if matches
			else &"test_contact_geometry_mismatch"
		),
		"center_error_meters": center_error_meters,
		"axis_error_degrees": axis_error_degrees,
		"index_point_source_origin_id": anatomy.get(
			"index_point_source_origin_id",
			StringName()
		),
		"pinky_point_source_origin_id": anatomy.get(
			"pinky_point_source_origin_id",
			StringName()
		),
	}, true)
	return result


func _build_test_support_contact_space_candidate(
	context: Dictionary,
	clavicle_delta_degrees: float,
	elbow_hinge_degrees: float,
	wrist_hinge_degrees: float,
	order_id: StringName
) -> Dictionary:
	var invalid := {
		"valid": false,
		"status": &"test_support_contact_candidate_invalid",
	}
	if (
		not is_finite(clavicle_delta_degrees)
		or not is_finite(elbow_hinge_degrees)
		or not is_finite(wrist_hinge_degrees)
		or order_id not in [
			&"local_x_applied_then_local_z",
			&"local_z_applied_then_local_x",
		]
	):
		return invalid
	var baseline_clavicle_basis: Basis = context.get(
		"baseline_clavicle_basis",
		Basis.IDENTITY
	) as Basis
	var candidate_clavicle_basis: Basis = (
		baseline_clavicle_basis
		* Basis(Vector3.RIGHT, deg_to_rad(clavicle_delta_degrees))
	).orthonormalized()
	var spine_global: Transform3D = context.get(
		"spine_global",
		Transform3D.IDENTITY
	) as Transform3D
	var candidate_clavicle_global: Transform3D = (
		spine_global
		* Transform3D(
			candidate_clavicle_basis,
			context.get("clavicle_pose_origin", Vector3.ZERO) as Vector3
		)
	)
	var upperarm_pose_origin: Vector3 = context.get(
		"upperarm_pose_origin",
		Vector3.ZERO
	) as Vector3
	var forearm_pose_origin: Vector3 = context.get(
		"forearm_pose_origin",
		Vector3.ZERO
	) as Vector3
	var hand_pose_origin: Vector3 = context.get(
		"hand_pose_origin",
		Vector3.ZERO
	) as Vector3
	var upperarm_zero_basis: Basis = context.get(
		"upperarm_zero_basis",
		Basis.IDENTITY
	) as Basis
	var forearm_zero_basis: Basis = context.get(
		"forearm_zero_basis",
		Basis.IDENTITY
	) as Basis
	var hand_zero_basis: Basis = context.get(
		"hand_zero_basis",
		Basis.IDENTITY
	) as Basis
	var alignment_offset_hand_local: Vector3 = context.get(
		"alignment_offset_hand_local",
		Vector3.ZERO
	) as Vector3
	var contact_axis_local: Vector3 = context.get(
		"contact_axis_local",
		Vector3.ZERO
	) as Vector3
	var target_alignment_skeleton: Vector3 = context.get(
		"target_alignment_skeleton",
		Vector3.ZERO
	) as Vector3
	var desired_contact_axis_skeleton: Vector3 = context.get(
		"desired_contact_axis_skeleton",
		Vector3.ZERO
	) as Vector3
	if (
		upperarm_pose_origin.length_squared() <= 0.000000000001
		or forearm_pose_origin.length_squared() <= 0.000000000001
		or contact_axis_local.length_squared() <= 0.000000000001
		or desired_contact_axis_skeleton.length_squared() <= 0.000000000001
	):
		return invalid
	var shoulder_skeleton: Vector3 = (
		candidate_clavicle_global * upperarm_pose_origin
	)
	var upperarm_neutral_global_basis: Basis = (
		candidate_clavicle_global.basis.orthonormalized()
		* upperarm_zero_basis
	).orthonormalized()
	var target_vector_neutral: Vector3 = (
		upperarm_neutral_global_basis.inverse()
		* (target_alignment_skeleton - shoulder_skeleton)
	)
	var target_axis_neutral: Vector3 = (
		upperarm_neutral_global_basis.inverse()
		* desired_contact_axis_skeleton
	).normalized()
	var forearm_hinge_basis := Basis(
		Vector3.RIGHT,
		deg_to_rad(elbow_hinge_degrees)
	)
	var wrist_hinge_basis := Basis(
		Vector3.BACK,
		deg_to_rad(wrist_hinge_degrees)
	)
	var forearm_local_basis: Basis = (
		forearm_zero_basis * forearm_hinge_basis
	).orthonormalized()
	var hand_local_basis: Basis = (
		hand_zero_basis * wrist_hinge_basis
	).orthonormalized()
	var source_vector: Vector3 = (
		forearm_pose_origin
		+ forearm_local_basis * (
			hand_pose_origin
			+ hand_local_basis * alignment_offset_hand_local
		)
	)
	var source_axis: Vector3 = (
		forearm_local_basis * hand_local_basis * contact_axis_local
	).normalized()
	var source_vector_length_skeleton: float = source_vector.length()
	var target_vector_length_skeleton: float = target_vector_neutral.length()
	var source_axis_vector_cosine: float = source_axis.dot(
		source_vector.normalized()
	)
	var target_axis_vector_cosine: float = target_axis_neutral.dot(
		target_vector_neutral.normalized()
	)
	var source_frame: Basis = _build_test_vector_pair_frame(
		source_axis,
		source_vector
	)
	var target_frame: Basis = _build_test_vector_pair_frame(
		target_axis_neutral,
		target_vector_neutral
	)
	if source_frame.determinant() <= 0.0 or target_frame.determinant() <= 0.0:
		return invalid
	var unconstrained_shoulder_basis: Basis = (
		target_frame * source_frame.inverse()
	).orthonormalized()
	var decomposition: Dictionary = _decompose_test_documented_shoulder_basis(
		unconstrained_shoulder_basis,
		order_id
	)
	if not bool(decomposition.get("valid", false)):
		return invalid
	var shoulder_basis: Basis = decomposition.get(
		"shoulder_basis",
		Basis.IDENTITY
	) as Basis
	var upperarm_global_basis: Basis = (
		upperarm_neutral_global_basis * shoulder_basis
	).orthonormalized()
	var forearm_global_basis: Basis = (
		upperarm_global_basis * forearm_local_basis
	).orthonormalized()
	var hand_global_basis: Basis = (
		forearm_global_basis * hand_local_basis
	).orthonormalized()
	var elbow_skeleton: Vector3 = (
		shoulder_skeleton + upperarm_global_basis * forearm_pose_origin
	)
	var hand_skeleton: Vector3 = (
		elbow_skeleton + forearm_global_basis * hand_pose_origin
	)
	var predicted_alignment_skeleton: Vector3 = (
		hand_skeleton + hand_global_basis * alignment_offset_hand_local
	)
	var predicted_contact_axis_skeleton: Vector3 = (
		hand_global_basis * contact_axis_local
	).normalized()
	var skeleton_global_basis: Basis = context.get(
		"skeleton_global_basis",
		Basis.IDENTITY
	) as Basis
	var endpoint_delta_world: Vector3 = (
		skeleton_global_basis
		* (predicted_alignment_skeleton - target_alignment_skeleton)
	)
	var endpoint_error_meters: float = endpoint_delta_world.length()
	var axis_error_degrees: float = rad_to_deg(acos(clampf(
		predicted_contact_axis_skeleton.dot(desired_contact_axis_skeleton),
		-1.0,
		1.0
	)))
	var clavicle_root_skeleton: Vector3 = candidate_clavicle_global.origin
	var shoulder_parent_vector: Vector3 = (
		clavicle_root_skeleton - shoulder_skeleton
	)
	var shoulder_child_vector: Vector3 = elbow_skeleton - shoulder_skeleton
	var elbow_parent_vector: Vector3 = shoulder_skeleton - elbow_skeleton
	var elbow_child_vector: Vector3 = hand_skeleton - elbow_skeleton
	if (
		shoulder_parent_vector.length_squared() <= 0.000000000001
		or shoulder_child_vector.length_squared() <= 0.000000000001
		or elbow_parent_vector.length_squared() <= 0.000000000001
		or elbow_child_vector.length_squared() <= 0.000000000001
	):
		return invalid
	var shoulder_angle_degrees: float = rad_to_deg(acos(clampf(
		shoulder_parent_vector.normalized().dot(
			shoulder_child_vector.normalized()
		),
		-1.0,
		1.0
	)))
	var elbow_angle_degrees: float = rad_to_deg(acos(clampf(
		elbow_parent_vector.normalized().dot(elbow_child_vector.normalized()),
		-1.0,
		1.0
	)))
	var shoulder_min: float = float(context.get("shoulder_min_degrees", 0.0))
	var shoulder_max: float = float(context.get("shoulder_max_degrees", 180.0))
	var elbow_min: float = float(context.get("elbow_min_degrees", 0.0))
	var elbow_max: float = float(context.get("elbow_max_degrees", 180.0))
	var shoulder_range_legal: bool = (
		shoulder_angle_degrees >= shoulder_min - 0.001
		and shoulder_angle_degrees <= shoulder_max + 0.001
	)
	var elbow_range_legal: bool = (
		elbow_angle_degrees >= elbow_min - 0.001
		and elbow_angle_degrees <= elbow_max + 0.001
	)
	var clavicle_range_legal: bool = (
		clavicle_delta_degrees >= -10.0001
		and clavicle_delta_degrees <= 5.0001
	)
	var wrist_range_legal: bool = absf(wrist_hinge_degrees) <= 90.0001
	var decomposition_error_degrees: float = float(decomposition.get(
		"basis_error_degrees",
		INF
	))
	var shoulder_plane_legal: bool = decomposition_error_degrees <= 0.05
	var shoulder_z_degrees: float = float(decomposition.get(
		"shoulder_z_degrees",
		NAN
	))
	var left_side: bool = bool(context.get("left_side", false))
	if absf(absf(shoulder_z_degrees) - 180.0) <= 0.0001:
		shoulder_z_degrees = -180.0 if left_side else 180.0
	var shoulder_side_range_legal: bool = (
		shoulder_z_degrees >= -180.0001
		and shoulder_z_degrees <= 0.0001
		if left_side
		else shoulder_z_degrees >= -0.0001
			and shoulder_z_degrees <= 180.0001
	)
	var joint_range_legal: bool = (
		clavicle_range_legal
		and shoulder_plane_legal
		and shoulder_side_range_legal
		and shoulder_range_legal
		and elbow_range_legal
		and elbow_hinge_degrees >= -0.0001
		and elbow_hinge_degrees <= 168.0001
		and wrist_range_legal
	)
	var exact_joint_legal: bool = (
		joint_range_legal
		and endpoint_error_meters <= 0.00005
		and axis_error_degrees <= 0.05
		and decomposition_error_degrees <= 0.01
	)
	var search_score: float = (
		endpoint_error_meters / 0.00005
		+ axis_error_degrees / 0.05
		+ decomposition_error_degrees / 0.05
		+ (0.0 if joint_range_legal else 1000000.0)
	)
	return {
		"valid": true,
		"status": (
			&"test_support_contact_candidate_exact_joint_legal"
			if exact_joint_legal
			else &"test_support_contact_candidate_approximate"
		),
		"point_origin_id": &"RL_BoneRoot",
		"order_id": order_id,
		"left_side": left_side,
		"clavicle_delta_degrees": clavicle_delta_degrees,
		"shoulder_x_degrees": float(decomposition.get(
			"shoulder_x_degrees",
			NAN
		)),
		"shoulder_z_degrees": shoulder_z_degrees,
		"elbow_hinge_degrees": elbow_hinge_degrees,
		"wrist_hinge_degrees": wrist_hinge_degrees,
		"shoulder_angle_degrees": shoulder_angle_degrees,
		"elbow_angle_degrees": elbow_angle_degrees,
		"shoulder_decomposition_error_degrees": decomposition_error_degrees,
		"endpoint_error_meters": endpoint_error_meters,
		"source_vector_length_skeleton": source_vector_length_skeleton,
		"target_vector_length_skeleton": target_vector_length_skeleton,
		"source_axis_vector_cosine": source_axis_vector_cosine,
		"target_axis_vector_cosine": target_axis_vector_cosine,
		"contact_axis_error_degrees": axis_error_degrees,
		"clavicle_range_legal": clavicle_range_legal,
		"shoulder_plane_legal": shoulder_plane_legal,
		"shoulder_side_range_legal": shoulder_side_range_legal,
		"shoulder_range_legal": shoulder_range_legal,
		"elbow_range_legal": elbow_range_legal,
		"wrist_range_legal": wrist_range_legal,
		"joint_range_legal": joint_range_legal,
		"exact_joint_legal": exact_joint_legal,
		"search_score": search_score,
		"candidate_clavicle_local_basis": candidate_clavicle_basis,
		"candidate_upperarm_local_basis": (
			upperarm_zero_basis * shoulder_basis
		).orthonormalized(),
		"candidate_forearm_local_basis": forearm_local_basis,
		"candidate_hand_local_basis": hand_local_basis,
		"upperarm_zero_basis": upperarm_zero_basis,
		"forearm_zero_basis": forearm_zero_basis,
		"hand_zero_basis": hand_zero_basis,
		"predicted_alignment_skeleton": predicted_alignment_skeleton,
		"predicted_contact_axis_skeleton": predicted_contact_axis_skeleton,
	}


func _build_test_vector_pair_frame(
	primary_axis: Vector3,
	secondary_vector: Vector3
) -> Basis:
	if (
		primary_axis.length_squared() <= 0.000000000001
		or secondary_vector.length_squared() <= 0.000000000001
	):
		return Basis(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO)
	var frame_x: Vector3 = primary_axis.normalized()
	var frame_y: Vector3 = (
		secondary_vector
		- frame_x * secondary_vector.dot(frame_x)
	)
	if frame_y.length_squared() <= 0.000000000001:
		return Basis(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO)
	frame_y = frame_y.normalized()
	var frame_z: Vector3 = frame_x.cross(frame_y).normalized()
	if frame_z.length_squared() <= 0.000000000001:
		return Basis(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO)
	frame_y = frame_z.cross(frame_x).normalized()
	return Basis(frame_x, frame_y, frame_z).orthonormalized()


func _decompose_test_documented_shoulder_basis(
	shoulder_basis: Basis,
	order_id: StringName
) -> Dictionary:
	var desired: Basis = shoulder_basis.orthonormalized()
	var shoulder_x_radians: float = 0.0
	var shoulder_z_radians: float = 0.0
	var reconstructed := Basis.IDENTITY
	if order_id == &"local_x_applied_then_local_z":
		var rotated_right: Vector3 = desired * Vector3.RIGHT
		shoulder_z_radians = atan2(rotated_right.y, rotated_right.x)
		var z_basis := Basis(Vector3.BACK, shoulder_z_radians)
		var x_only: Basis = (z_basis.inverse() * desired).orthonormalized()
		var rotated_up: Vector3 = x_only * Vector3.UP
		shoulder_x_radians = atan2(rotated_up.z, rotated_up.y)
		reconstructed = (
			z_basis * Basis(Vector3.RIGHT, shoulder_x_radians)
		).orthonormalized()
	elif order_id == &"local_z_applied_then_local_x":
		var rotated_back: Vector3 = desired * Vector3.BACK
		shoulder_x_radians = atan2(-rotated_back.y, rotated_back.z)
		var x_basis := Basis(Vector3.RIGHT, shoulder_x_radians)
		var z_only: Basis = (x_basis.inverse() * desired).orthonormalized()
		var rotated_up: Vector3 = z_only * Vector3.UP
		shoulder_z_radians = atan2(-rotated_up.x, rotated_up.y)
		reconstructed = (
			x_basis * Basis(Vector3.BACK, shoulder_z_radians)
		).orthonormalized()
	else:
		return {"valid": false}
	var x_degrees: float = wrapf(
		rad_to_deg(shoulder_x_radians),
		-180.0,
		180.0
	)
	var z_degrees: float = wrapf(
		rad_to_deg(shoulder_z_radians),
		-180.0,
		180.0
	)
	# Side legality is evaluated by the caller from the candidate context. Keep the
	# decomposition itself purely geometric so its result remains reusable.
	return {
		"valid": true,
		"shoulder_x_degrees": x_degrees,
		"shoulder_z_degrees": z_degrees,
		"shoulder_basis": reconstructed,
		"basis_error_degrees": _resolve_test_basis_delta_degrees(
			desired,
			reconstructed
		),
	}


func _insert_test_support_contact_seed(
	seeds: Array[Dictionary],
	candidate: Dictionary,
	maximum_count: int
) -> void:
	if candidate.is_empty() or not bool(candidate.get("valid", false)):
		return
	var insert_at: int = seeds.size()
	var candidate_score: float = float(candidate.get("search_score", INF))
	for index: int in range(seeds.size()):
		if candidate_score < float(seeds[index].get("search_score", INF)):
			insert_at = index
			break
	seeds.insert(insert_at, candidate)
	if seeds.size() > maximum_count:
		seeds.resize(maximum_count)


func _refine_test_support_contact_space_candidate(
	context: Dictionary,
	seed: Dictionary
) -> Dictionary:
	var best: Dictionary = seed.duplicate(true)
	var order_id: StringName = seed.get("order_id", StringName()) as StringName
	for step_degrees: float in [0.2, 0.02, 0.002]:
		var center_clavicle: float = float(best.get(
			"clavicle_delta_degrees",
			0.0
		))
		var center_elbow: float = float(best.get("elbow_hinge_degrees", 0.0))
		var center_wrist: float = float(best.get("wrist_hinge_degrees", 0.0))
		for clavicle_offset: int in range(-3, 4):
			for elbow_offset: int in range(-3, 4):
				for wrist_offset: int in range(-3, 4):
					var candidate: Dictionary = (
						_build_test_support_contact_space_candidate(
							context,
							clampf(
								center_clavicle
								+ float(clavicle_offset) * step_degrees,
								-10.0,
								5.0
							),
							clampf(
								center_elbow
								+ float(elbow_offset) * step_degrees,
								0.0,
								168.0
							),
							clampf(
								center_wrist
								+ float(wrist_offset) * step_degrees,
								-90.0,
								90.0
							),
							order_id
						)
					)
					if (
						bool(candidate.get("valid", false))
						and float(candidate.get("search_score", INF))
							< float(best.get("search_score", INF))
					):
						best = candidate
	return best


func _apply_test_support_contact_space_candidate(
	actor: Node3D,
	support_slot_id: StringName,
	clavicle_index: int,
	upperarm_index: int,
	forearm_index: int,
	hand_index: int,
	baseline_clavicle_basis: Basis,
	target_contact_center_world: Vector3,
	target_contact_axis_world: Vector3,
	contact_axis_local: Vector3,
	candidate: Dictionary
) -> Dictionary:
	var result := {
		"valid": false,
		"exact": false,
		"status": &"test_support_contact_apply_unavailable",
		"point_origin_id": &"RL_BoneRoot",
	}
	var skeleton: Skeleton3D = actor.get("skeleton") as Skeleton3D
	if skeleton == null:
		return result
	if actor.has_method("_neutralize_authoring_limb_twist_distribution_for_slot"):
		actor.call(
			"_neutralize_authoring_limb_twist_distribution_for_slot",
			support_slot_id,
			1.0
		)
	var clavicle_basis: Basis = candidate.get(
		"candidate_clavicle_local_basis",
		Basis.IDENTITY
	) as Basis
	var upperarm_basis: Basis = candidate.get(
		"candidate_upperarm_local_basis",
		Basis.IDENTITY
	) as Basis
	var forearm_basis: Basis = candidate.get(
		"candidate_forearm_local_basis",
		Basis.IDENTITY
	) as Basis
	var hand_basis: Basis = candidate.get(
		"candidate_hand_local_basis",
		Basis.IDENTITY
	) as Basis
	skeleton.set_bone_pose_rotation(
		clavicle_index,
		clavicle_basis.get_rotation_quaternion().normalized()
	)
	skeleton.set_bone_pose_rotation(
		upperarm_index,
		upperarm_basis.get_rotation_quaternion().normalized()
	)
	skeleton.set_bone_pose_rotation(
		forearm_index,
		forearm_basis.get_rotation_quaternion().normalized()
	)
	skeleton.set_bone_pose_rotation(
		hand_index,
		hand_basis.get_rotation_quaternion().normalized()
	)
	skeleton.force_update_all_bone_transforms()
	var actual_anatomy: Dictionary = actor.call(
		"resolve_hand_surface_seat_anatomy_state",
		support_slot_id
	) as Dictionary
	if not bool(actual_anatomy.get("valid", false)):
		result["status"] = &"test_support_contact_apply_anatomy_missing"
		return result
	var actual_index_world: Vector3 = actual_anatomy.get(
		"index_point_world",
		Vector3.ZERO
	) as Vector3
	var actual_pinky_world: Vector3 = actual_anatomy.get(
		"pinky_point_world",
		Vector3.ZERO
	) as Vector3
	var actual_contact_center_world: Vector3 = actual_index_world.lerp(
		actual_pinky_world,
		0.5
	)
	var actual_contact_axis_world: Vector3 = (
		actual_index_world - actual_pinky_world
	).normalized()
	var alignment_error_meters: float = actual_contact_center_world.distance_to(
		target_contact_center_world
	)
	var contact_axis_error_degrees: float = rad_to_deg(acos(clampf(
		actual_contact_axis_world.dot(target_contact_axis_world.normalized()),
		-1.0,
		1.0
	)))
	var clavicle_relative_baseline: Basis = (
		baseline_clavicle_basis.inverse()
		* skeleton.get_bone_pose(clavicle_index).basis.orthonormalized()
	).orthonormalized()
	var clavicle_relative_quaternion: Quaternion = _canonicalize_test_quaternion(
		clavicle_relative_baseline.get_rotation_quaternion()
	)
	var clavicle_off_x_residual: float = sqrt(
		clavicle_relative_quaternion.y * clavicle_relative_quaternion.y
		+ clavicle_relative_quaternion.z * clavicle_relative_quaternion.z
	)
	var arm_range_state: Dictionary = actor.call(
		"get_authoring_arm_joint_range_state",
		support_slot_id
	) as Dictionary
	var actual_clavicle_basis: Basis = skeleton.get_bone_pose(
		clavicle_index
	).basis.orthonormalized()
	var actual_upperarm_basis: Basis = skeleton.get_bone_pose(
		upperarm_index
	).basis.orthonormalized()
	var actual_forearm_basis: Basis = skeleton.get_bone_pose(
		forearm_index
	).basis.orthonormalized()
	var actual_hand_basis: Basis = skeleton.get_bone_pose(
		hand_index
	).basis.orthonormalized()
	var expected_clavicle_basis: Basis = candidate.get(
		"candidate_clavicle_local_basis",
		Basis.IDENTITY
	) as Basis
	var expected_upperarm_basis: Basis = candidate.get(
		"candidate_upperarm_local_basis",
		Basis.IDENTITY
	) as Basis
	var expected_forearm_basis: Basis = candidate.get(
		"candidate_forearm_local_basis",
		Basis.IDENTITY
	) as Basis
	var expected_hand_basis: Basis = candidate.get(
		"candidate_hand_local_basis",
		Basis.IDENTITY
	) as Basis
	var clavicle_basis_error_degrees: float = _resolve_test_basis_delta_degrees(
		actual_clavicle_basis,
		expected_clavicle_basis
	)
	var upperarm_basis_error_degrees: float = _resolve_test_basis_delta_degrees(
		actual_upperarm_basis,
		expected_upperarm_basis
	)
	var forearm_basis_error_degrees: float = _resolve_test_basis_delta_degrees(
		actual_forearm_basis,
		expected_forearm_basis
	)
	var hand_basis_error_degrees: float = _resolve_test_basis_delta_degrees(
		actual_hand_basis,
		expected_hand_basis
	)
	var upperarm_zero_basis: Basis = candidate.get(
		"upperarm_zero_basis",
		Basis.IDENTITY
	) as Basis
	var forearm_zero_basis: Basis = candidate.get(
		"forearm_zero_basis",
		Basis.IDENTITY
	) as Basis
	var hand_zero_basis: Basis = candidate.get(
		"hand_zero_basis",
		Basis.IDENTITY
	) as Basis
	var actual_shoulder_delta: Basis = (
		upperarm_zero_basis.inverse() * actual_upperarm_basis
	).orthonormalized()
	var actual_shoulder_decomposition: Dictionary = (
		_decompose_test_documented_shoulder_basis(
			actual_shoulder_delta,
			StringName(candidate.get("order_id", StringName()))
		)
	)
	var actual_shoulder_z_degrees: float = float(
		actual_shoulder_decomposition.get("shoulder_z_degrees", NAN)
	)
	var left_side: bool = support_slot_id == &"hand_left"
	if absf(absf(actual_shoulder_z_degrees) - 180.0) <= 0.0001:
		actual_shoulder_z_degrees = -180.0 if left_side else 180.0
	var actual_shoulder_side_legal: bool = (
		actual_shoulder_z_degrees >= -180.0001
		and actual_shoulder_z_degrees <= 0.0001
		if left_side
		else actual_shoulder_z_degrees >= -0.0001
			and actual_shoulder_z_degrees <= 180.0001
	)
	var actual_forearm_delta: Basis = (
		forearm_zero_basis.inverse() * actual_forearm_basis
	).orthonormalized()
	var expected_forearm_delta := Basis(
		Vector3.RIGHT,
		deg_to_rad(float(candidate.get("elbow_hinge_degrees", NAN)))
	)
	var forearm_plane_error_degrees: float = _resolve_test_basis_delta_degrees(
		actual_forearm_delta,
		expected_forearm_delta
	)
	var actual_hand_delta: Basis = (
		hand_zero_basis.inverse() * actual_hand_basis
	).orthonormalized()
	var expected_hand_delta := Basis(
		Vector3.BACK,
		deg_to_rad(float(candidate.get("wrist_hinge_degrees", NAN)))
	)
	var hand_plane_error_degrees: float = _resolve_test_basis_delta_degrees(
		actual_hand_delta,
		expected_hand_delta
	)
	var actual_wrist_up: Vector3 = actual_hand_delta * Vector3.UP
	var actual_wrist_hinge_degrees: float = wrapf(
		rad_to_deg(atan2(-actual_wrist_up.x, actual_wrist_up.y)),
		-180.0,
		180.0
	)
	var actual_wrist_range_legal: bool = (
		actual_wrist_hinge_degrees >= -90.0001
		and actual_wrist_hinge_degrees <= 90.0001
	)
	var actual_joint_planes_legal: bool = (
		clavicle_basis_error_degrees <= 0.01
		and upperarm_basis_error_degrees <= 0.01
		and forearm_basis_error_degrees <= 0.01
		and hand_basis_error_degrees <= 0.01
		and clavicle_off_x_residual <= 0.000001
		and bool(actual_shoulder_decomposition.get("valid", false))
		and float(actual_shoulder_decomposition.get(
			"basis_error_degrees",
			INF
		)) <= 0.01
		and actual_shoulder_side_legal
		and forearm_plane_error_degrees <= 0.01
		and hand_plane_error_degrees <= 0.01
		and actual_wrist_range_legal
	)
	var exact: bool = (
		bool(candidate.get("exact_joint_legal", false))
		and alignment_error_meters <= 0.00005
		and contact_axis_error_degrees <= 0.05
		and actual_joint_planes_legal
		and bool(arm_range_state.get("valid", false))
		and bool(arm_range_state.get("legal", false))
	)
	result.merge({
		"valid": true,
		"exact": exact,
		"status": (
			&"test_support_contact_apply_exact"
			if exact
			else &"test_support_contact_apply_mismatch"
		),
		"alignment_error_meters": alignment_error_meters,
		"contact_axis_error_degrees": contact_axis_error_degrees,
		"clavicle_off_x_quaternion_residual": clavicle_off_x_residual,
		"clavicle_basis_error_degrees": clavicle_basis_error_degrees,
		"upperarm_basis_error_degrees": upperarm_basis_error_degrees,
		"forearm_basis_error_degrees": forearm_basis_error_degrees,
		"hand_basis_error_degrees": hand_basis_error_degrees,
		"actual_shoulder_decomposition": (
			actual_shoulder_decomposition.duplicate(true)
		),
		"actual_shoulder_z_degrees": actual_shoulder_z_degrees,
		"actual_shoulder_side_legal": actual_shoulder_side_legal,
		"forearm_plane_error_degrees": forearm_plane_error_degrees,
		"hand_plane_error_degrees": hand_plane_error_degrees,
		"actual_wrist_hinge_degrees": actual_wrist_hinge_degrees,
		"actual_wrist_range_legal": actual_wrist_range_legal,
		"actual_joint_planes_legal": actual_joint_planes_legal,
		"arm_range_state": arm_range_state.duplicate(true),
	}, true)
	return result


func _compact_test_support_contact_candidate(candidate: Dictionary) -> Dictionary:
	return {
		"status": candidate.get("status", StringName()),
		"order_id": candidate.get("order_id", StringName()),
		"clavicle_delta_degrees": candidate.get(
			"clavicle_delta_degrees",
			NAN
		),
		"shoulder_x_degrees": candidate.get("shoulder_x_degrees", NAN),
		"shoulder_z_degrees": candidate.get("shoulder_z_degrees", NAN),
		"elbow_hinge_degrees": candidate.get("elbow_hinge_degrees", NAN),
		"wrist_hinge_degrees": candidate.get("wrist_hinge_degrees", NAN),
		"shoulder_angle_degrees": candidate.get(
			"shoulder_angle_degrees",
			NAN
		),
		"elbow_angle_degrees": candidate.get("elbow_angle_degrees", NAN),
		"endpoint_error_meters": candidate.get("endpoint_error_meters", INF),
		"source_vector_length_skeleton": candidate.get(
			"source_vector_length_skeleton",
			INF
		),
		"target_vector_length_skeleton": candidate.get(
			"target_vector_length_skeleton",
			INF
		),
		"source_axis_vector_cosine": candidate.get(
			"source_axis_vector_cosine",
			INF
		),
		"target_axis_vector_cosine": candidate.get(
			"target_axis_vector_cosine",
			INF
		),
		"contact_axis_error_degrees": candidate.get(
			"contact_axis_error_degrees",
			INF
		),
		"shoulder_decomposition_error_degrees": candidate.get(
			"shoulder_decomposition_error_degrees",
			INF
		),
		"joint_range_legal": candidate.get("joint_range_legal", false),
		"exact_joint_legal": candidate.get("exact_joint_legal", false),
		"search_score": candidate.get("search_score", INF),
	}


func _scan_test_support_verified_anatomical_joint_space_candidates(
	presenter: Object,
	actor: Node3D,
	held: Node3D,
	transaction_snapshot: Dictionary,
	support_slot_id: StringName,
	primary_slot_id: StringName
) -> Dictionary:
	var result := {
		"valid": false,
		"status": &"test_verified_anatomical_joint_scan_unavailable",
		"point_origin_id": &"RL_BoneRoot",
		"support_slot_id": support_slot_id,
		"primary_slot_id": primary_slot_id,
		"clavicle_zero_frame": &"authoring_baseline_animation_t0_parent_local_pose",
		"clavicle_delta_axis": Vector3.RIGHT,
		"clavicle_delta_min_degrees": -10.0,
		"clavicle_delta_max_degrees": 5.0,
		"clavicle_sample_count": 0,
		"hinge_root_count": 0,
		"rom_legal_count": 0,
		"applied_exact_count": 0,
		"primary_weapon_legal_count": 0,
		"body_legal_count": 0,
		"surface_identity_count": 0,
		"full_legal_count": 0,
		"full_legal_candidate": {},
		"best_rejected": {},
		"clavicle_root_states": [],
		"candidate_summaries": [],
		"documented_shoulder_order_summaries": [],
	}
	if (
		presenter == null
		or actor == null
		or held == null
		or support_slot_id not in [&"hand_right", &"hand_left"]
		or primary_slot_id not in [&"hand_right", &"hand_left"]
		or support_slot_id == primary_slot_id
	):
		return result
	var skeleton: Skeleton3D = actor.get("skeleton") as Skeleton3D
	if skeleton == null:
		result["status"] = &"test_verified_anatomical_joint_scan_skeleton_missing"
		return result
	var left_side: bool = support_slot_id == &"hand_left"
	var clavicle_bone: StringName = (
		&"CC_Base_L_Clavicle" if left_side else &"CC_Base_R_Clavicle"
	)
	var upperarm_bone: StringName = (
		&"CC_Base_L_Upperarm" if left_side else &"CC_Base_R_Upperarm"
	)
	var forearm_bone: StringName = (
		&"CC_Base_L_Forearm" if left_side else &"CC_Base_R_Forearm"
	)
	var hand_bone: StringName = (
		&"CC_Base_L_Hand" if left_side else &"CC_Base_R_Hand"
	)
	var clavicle_index: int = skeleton.find_bone(String(clavicle_bone))
	var upperarm_index: int = skeleton.find_bone(String(upperarm_bone))
	var forearm_index: int = skeleton.find_bone(String(forearm_bone))
	var hand_index: int = skeleton.find_bone(String(hand_bone))
	if (
		clavicle_index < 0
		or upperarm_index < 0
		or forearm_index < 0
		or hand_index < 0
		or skeleton.get_bone_parent(upperarm_index) != clavicle_index
		or skeleton.get_bone_parent(forearm_index) != upperarm_index
		or skeleton.get_bone_parent(hand_index) != forearm_index
	):
		result["status"] = &"test_verified_anatomical_joint_scan_chain_invalid"
		return result
	var spine_index: int = skeleton.get_bone_parent(clavicle_index)
	if spine_index < 0:
		result["status"] = &"test_verified_anatomical_joint_scan_spine_missing"
		return result
	var secondary_guide := held.get_node_or_null("SecondaryGripGuide") as Node3D
	var support_anchor := held.get_node_or_null("SupportGripAnchor") as Node3D
	if secondary_guide == null or support_anchor == null:
		result["status"] = &"test_verified_anatomical_joint_scan_contact_node_missing"
		return result
	var seated_outer_snapshot: Dictionary = presenter.call(
		"_capture_preview_support_grip_transaction_snapshot",
		actor,
		held,
		support_anchor,
		support_slot_id,
		primary_slot_id
	) as Dictionary
	if not bool(seated_outer_snapshot.get("valid", false)):
		result["status"] = &"test_verified_anatomical_joint_scan_snapshot_failed"
		return result
	result["candidate_restore_frame"] = &"exact_seated_outer_transaction"
	var baseline_clavicle_state: Dictionary = (
		_capture_test_authoring_baseline_bone_pose(
			presenter,
			actor,
			held,
			support_anchor,
			seated_outer_snapshot,
			support_slot_id,
			primary_slot_id,
			clavicle_index,
			clavicle_bone
		)
	)
	if not bool(baseline_clavicle_state.get("valid", false)):
		result["status"] = baseline_clavicle_state.get(
			"status",
			&"test_verified_anatomical_joint_scan_baseline_missing"
		)
		return result
	var baseline_clavicle_basis: Basis = baseline_clavicle_state.get(
		"basis",
		Basis.IDENTITY
	) as Basis
	result["clavicle_zero_source"] = baseline_clavicle_state.get(
		"source",
		StringName()
	)
	result["clavicle_zero_animation_name"] = baseline_clavicle_state.get(
		"baseline_animation_name",
		StringName()
	)

	# get_bone_pose() is the complete parent-local pose. Imported rest is another
	# complete parent-local frame; rest^-1 * pose is only a diagnostic delta.
	# Clavicle candidates deliberately postmultiply the immutable authoring
	# baseline animation pose. The already-moved transaction pose is not a lawful
	# zero; imported bind/rest is a different complete parent-local frame.
	var spine_global: Transform3D = skeleton.get_bone_global_pose(spine_index)
	var seated_clavicle_pose: Transform3D = skeleton.get_bone_pose(clavicle_index)
	var upperarm_rest: Transform3D = skeleton.get_bone_rest(upperarm_index)
	var forearm_rest: Transform3D = skeleton.get_bone_rest(forearm_index)
	var upperarm_pose: Transform3D = skeleton.get_bone_pose(upperarm_index)
	var forearm_pose: Transform3D = skeleton.get_bone_pose(forearm_index)
	var hand_pose: Transform3D = skeleton.get_bone_pose(hand_index)
	var hand_target_skeleton: Transform3D = skeleton.get_bone_global_pose(hand_index)
	var hand_target_world: Transform3D = skeleton.global_transform * hand_target_skeleton
	var upperarm_child_offset: Vector3 = forearm_pose.origin
	var forearm_child_offset: Vector3 = hand_pose.origin
	var upperarm_rest_basis: Basis = upperarm_rest.basis.orthonormalized()
	var forearm_rest_basis: Basis = forearm_rest.basis.orthonormalized()
	var solve_epsilon: float = 0.000000001
	if (
		upperarm_child_offset.length_squared() <= solve_epsilon
		or forearm_child_offset.length_squared() <= solve_epsilon
	):
		result["status"] = &"test_verified_anatomical_joint_scan_segment_invalid"
		return result
	var clavicle_rest_basis: Basis = skeleton.get_bone_rest(
		clavicle_index
	).basis.orthonormalized()
	var baseline_rest_delta: Basis = (
		clavicle_rest_basis.inverse() * baseline_clavicle_basis
	).orthonormalized()
	result["baseline_clavicle_rest_delta_degrees"] = (
		_resolve_test_basis_delta_degrees(Basis.IDENTITY, baseline_rest_delta)
	)
	result["baseline_clavicle_pose_basis"] = baseline_clavicle_basis
	result["seated_hand_target_skeleton"] = hand_target_skeleton
	result["seated_hand_target_world"] = hand_target_world
	var clavicle_deltas: Array[float] = (
		_build_test_nearest_first_clavicle_deltas(-10, 5)
	)
	result["clavicle_deltas_nearest_first"] = clavicle_deltas.duplicate()
	result["clavicle_sample_count"] = clavicle_deltas.size()
	var shoulder_min_degrees: float = float(actor.get(
		"authoring_shoulder_min_plane_angle_degrees"
	))
	var shoulder_max_degrees: float = float(actor.get(
		"authoring_shoulder_max_plane_angle_degrees"
	))
	var elbow_min_degrees: float = float(actor.get(
		"authoring_elbow_min_plane_angle_degrees"
	))
	var elbow_max_degrees: float = float(actor.get(
		"authoring_elbow_max_plane_angle_degrees"
	))
	result["shoulder_interior_cap_degrees"] = Vector2(
		shoulder_min_degrees,
		shoulder_max_degrees
	)
	result["elbow_interior_cap_degrees"] = Vector2(
		elbow_min_degrees,
		elbow_max_degrees
	)
	var candidate_summaries: Array[Dictionary] = []
	var clavicle_root_states: Array[Dictionary] = []
	var documented_shoulder_order_summaries: Array[Dictionary] = []
	var best_rejected: Dictionary = {}
	var best_rejected_score: int = -1
	var scan_failed: bool = false
	for clavicle_delta_degrees: float in clavicle_deltas:
		var candidate_clavicle_basis: Basis = (
			baseline_clavicle_basis
			* Basis(Vector3.RIGHT, deg_to_rad(clavicle_delta_degrees))
		).orthonormalized()
		var candidate_clavicle_local := Transform3D(
			candidate_clavicle_basis,
			seated_clavicle_pose.origin
		)
		var candidate_clavicle_global: Transform3D = (
			spine_global * candidate_clavicle_local
		)
		var shoulder_skeleton: Vector3 = (
			candidate_clavicle_global * upperarm_pose.origin
		)
		var upperarm_neutral_global_basis: Basis = (
			candidate_clavicle_global.basis.orthonormalized()
			* upperarm_rest_basis
		).orthonormalized()
		var target_neutral: Vector3 = (
			upperarm_neutral_global_basis.inverse()
			* (hand_target_skeleton.origin - shoulder_skeleton)
		)
		var root_context := {
			"point_origin_id": &"RL_BoneRoot",
			"left_side": left_side,
			"clavicle_delta_degrees": clavicle_delta_degrees,
			"candidate_clavicle_local_basis": candidate_clavicle_basis,
			"candidate_clavicle_global_basis": (
				candidate_clavicle_global.basis.orthonormalized()
			),
			"clavicle_root_skeleton": candidate_clavicle_global.origin,
			"shoulder_skeleton": shoulder_skeleton,
			"hand_target_skeleton": hand_target_skeleton,
			"upperarm_neutral_global_basis": upperarm_neutral_global_basis,
			"upperarm_rest_basis": upperarm_rest_basis,
			"forearm_rest_basis": forearm_rest_basis,
			"upperarm_child_offset": upperarm_child_offset,
			"forearm_child_offset": forearm_child_offset,
			"target_neutral": target_neutral,
			"shoulder_min_degrees": shoulder_min_degrees,
			"shoulder_max_degrees": shoulder_max_degrees,
			"elbow_min_degrees": elbow_min_degrees,
			"elbow_max_degrees": elbow_max_degrees,
		}
		var root_state: Dictionary = _solve_test_verified_hinge_roots(
			root_context
		)
		var documented_order_state: Dictionary = (
			_scan_test_documented_shoulder_orders(
				root_context,
				root_state.get("candidates", []) as Array
			)
		)
		documented_order_state["clavicle_delta_degrees"] = (
			clavicle_delta_degrees
		)
		documented_shoulder_order_summaries.append(
			documented_order_state
		)
		if clavicle_root_states.size() < 32:
			clavicle_root_states.append({
				"clavicle_delta_degrees": clavicle_delta_degrees,
				"status": root_state.get("status", StringName()),
				"equation_k": root_state.get("equation_k", NAN),
				"equation_radius": root_state.get("equation_radius", NAN),
				"root_count": (
					(root_state.get("candidates", []) as Array).size()
				),
			})
		var candidates: Array = root_state.get("candidates", []) as Array
		result["hinge_root_count"] = (
			int(result["hinge_root_count"]) + candidates.size()
		)
		for candidate_variant: Variant in candidates:
			if not candidate_variant is Dictionary:
				continue
			var candidate: Dictionary = candidate_variant as Dictionary
			var compact: Dictionary = (
				_build_test_verified_anatomical_candidate_summary(candidate, {})
			)
			if not bool(candidate.get("rom_legal", false)):
				compact["full_legal"] = false
				compact["rejection_stage"] = &"anatomical_rom"
				if candidate_summaries.size() < 64:
					candidate_summaries.append(compact)
				if best_rejected_score < 0:
					best_rejected_score = 0
					best_rejected = compact.duplicate(true)
				continue
			result["rom_legal_count"] = int(result["rom_legal_count"]) + 1
			if not bool(presenter.call(
				"_restore_preview_support_candidate_baseline",
				actor,
				held,
				support_anchor,
				seated_outer_snapshot,
				support_slot_id,
				primary_slot_id
			)):
				result["status"] = &"test_verified_anatomical_joint_scan_restore_failed"
				scan_failed = true
				break
			var applied: Dictionary = _apply_test_verified_anatomical_candidate(
				actor,
				support_slot_id,
				clavicle_index,
				upperarm_index,
				forearm_index,
				hand_index,
				baseline_clavicle_basis,
				upperarm_rest_basis,
				forearm_rest_basis,
				hand_target_skeleton,
				hand_target_world,
				candidate
			)
			compact = _build_test_verified_anatomical_candidate_summary(
				candidate,
				applied
			)
			if bool(applied.get("exact", false)):
				result["applied_exact_count"] = (
					int(result["applied_exact_count"]) + 1
				)
			var primary_weapon_unchanged: bool = bool(presenter.call(
				"_preview_support_primary_weapon_unit_matches_snapshot",
				held,
				seated_outer_snapshot,
				actor,
				primary_slot_id
			))
			compact["primary_weapon_unit_unchanged"] = primary_weapon_unchanged
			if primary_weapon_unchanged:
				result["primary_weapon_legal_count"] = (
					int(result["primary_weapon_legal_count"]) + 1
				)
			var body_gate: Dictionary = presenter.call(
				"_evaluate_preview_support_body_self_collision_delta",
				actor,
				seated_outer_snapshot,
				support_slot_id
			) as Dictionary
			var body_legal: bool = (
				bool(body_gate.get("valid", false))
				and bool(body_gate.get("legal", false))
			)
			compact["body_status"] = body_gate.get("status", StringName())
			compact["body_legal"] = body_legal
			compact["rejected_pair_signature"] = body_gate.get(
				"rejected_pair_signature",
				""
			)
			if body_legal:
				result["body_legal_count"] = int(result["body_legal_count"]) + 1
			actor.call(
				"invalidate_authoring_active_weapon_surface_seat",
				support_slot_id
			)
			var seat_attempt: Dictionary = actor.call(
				"resolve_exact_surface_weapon_seat",
				support_slot_id,
				true,
				true
			) as Dictionary
			var correction_state: Dictionary = presenter.call(
				"_resolve_preview_support_transaction_correction",
				seat_attempt,
				secondary_guide
			) as Dictionary
			var correction_local: Transform3D = correction_state.get(
				"correction_local",
				Transform3D.IDENTITY
			) as Transform3D
			var surface_identity: bool = (
				bool(seat_attempt.get("valid", false))
				and int(seat_attempt.get("candidate_sample_index", -1)) == 0
				and bool(correction_state.get("valid", false))
				and bool(presenter.call(
					"_preview_support_correction_is_identity",
					correction_local
				))
			)
			compact["surface_status"] = seat_attempt.get(
				"status",
				StringName()
			)
			compact["surface_candidate_sample_index"] = int(seat_attempt.get(
				"candidate_sample_index",
				-1
			))
			compact["surface_identity"] = surface_identity
			if surface_identity:
				result["surface_identity_count"] = (
					int(result["surface_identity_count"]) + 1
				)
			var full_legal: bool = (
				bool(applied.get("exact", false))
				and primary_weapon_unchanged
				and body_legal
				and surface_identity
			)
			compact["full_legal"] = full_legal
			if candidate_summaries.size() < 64:
				candidate_summaries.append(compact)
			var passed_gate_count: int = 0
			if bool(applied.get("exact", false)):
				passed_gate_count += 1
			if primary_weapon_unchanged:
				passed_gate_count += 1
			if body_legal:
				passed_gate_count += 1
			if surface_identity:
				passed_gate_count += 1
			if not full_legal and passed_gate_count > best_rejected_score:
				best_rejected_score = passed_gate_count
				best_rejected = compact.duplicate(true)
			if full_legal:
				result["full_legal_count"] = int(result["full_legal_count"]) + 1
				result["full_legal_candidate"] = compact.duplicate(true)
				break
		if scan_failed or int(result["full_legal_count"]) > 0:
			break
	var final_restore_ok: bool = bool(presenter.call(
		"_restore_preview_support_candidate_baseline",
		actor,
		held,
		support_anchor,
		seated_outer_snapshot,
		support_slot_id,
		primary_slot_id
	))
	result["final_seated_snapshot_restored"] = final_restore_ok
	result["best_rejected"] = best_rejected
	result["clavicle_root_states"] = clavicle_root_states
	result["candidate_summaries"] = candidate_summaries
	result["documented_shoulder_order_summaries"] = (
		documented_shoulder_order_summaries
	)
	result["valid"] = not scan_failed and final_restore_ok
	if int(result["full_legal_count"]) > 0:
		result["status"] = &"test_verified_anatomical_joint_scan_full_legal_found"
	elif scan_failed:
		pass
	elif not final_restore_ok:
		result["status"] = &"test_verified_anatomical_joint_scan_final_restore_failed"
	else:
		result["status"] = &"test_verified_anatomical_joint_scan_no_full_legal"
	return result


func _capture_test_authoring_baseline_bone_pose(
	presenter: Object,
	actor: Node3D,
	held: Node3D,
	support_anchor: Node3D,
	seated_snapshot: Dictionary,
	support_slot_id: StringName,
	primary_slot_id: StringName,
	bone_index: int,
	bone_name: StringName
) -> Dictionary:
	var failed := {
		"valid": false,
		"status": &"test_authoring_baseline_pose_unavailable",
		"point_origin_id": &"RL_BoneRoot",
	}
	if (
		presenter == null
		or actor == null
		or held == null
		or support_anchor == null
		or bone_index < 0
		or not actor.has_method("_apply_authoring_preview_baseline_pose")
	):
		return failed
	var skeleton: Skeleton3D = actor.get("skeleton") as Skeleton3D
	if skeleton == null:
		failed["status"] = &"test_authoring_baseline_skeleton_missing"
		return failed
	if (
		bone_index >= skeleton.get_bone_count()
		or StringName(skeleton.get_bone_name(bone_index)) != bone_name
	):
		failed["status"] = &"test_authoring_baseline_bone_identity_mismatch"
		return failed
	var parent_bone_index: int = skeleton.get_bone_parent(bone_index)
	if parent_bone_index < 0:
		failed["status"] = &"test_authoring_baseline_parent_bone_missing"
		return failed
	var parent_bone_name: StringName = StringName(skeleton.get_bone_name(
		parent_bone_index
	))
	var pose_positions := PackedVector3Array()
	var pose_rotations := PackedVector4Array()
	var pose_scales := PackedVector3Array()
	for snapshot_bone_index: int in range(skeleton.get_bone_count()):
		pose_positions.append(skeleton.get_bone_pose_position(snapshot_bone_index))
		var pose_rotation: Quaternion = skeleton.get_bone_pose_rotation(
			snapshot_bone_index
		).normalized()
		pose_rotations.append(Vector4(
			pose_rotation.x,
			pose_rotation.y,
			pose_rotation.z,
			pose_rotation.w
		))
		pose_scales.append(skeleton.get_bone_pose_scale(snapshot_bone_index))
	var animation_player: AnimationPlayer = actor.get(
		"animation_player"
	) as AnimationPlayer
	var animation_was_playing: bool = (
		animation_player.is_playing() if animation_player != null else false
	)
	var animation_assigned_before: StringName = (
		StringName(animation_player.get("assigned_animation"))
		if animation_player != null
		else StringName()
	)
	var animation_position_before: float = (
		animation_player.current_animation_position
		if animation_player != null and animation_was_playing
		else 0.0
	)
	var animation_speed_before: float = (
		animation_player.speed_scale if animation_player != null else 1.0
	)
	var locomotion_presenter: Object = actor.get("locomotion_presenter") as Object
	var locomotion_animation_before: StringName = (
		StringName(locomotion_presenter.get("current_animation_name"))
		if locomotion_presenter != null
		else StringName()
	)
	var baseline_animation_name: StringName = StringName(actor.get(
		"authoring_preview_baseline_animation_name"
	))
	actor.call(
		"_apply_authoring_preview_baseline_pose",
		baseline_animation_name
	)
	skeleton.force_update_all_bone_transforms()
	var applied_baseline_animation_name: StringName = (
		StringName(animation_player.get("assigned_animation"))
		if animation_player != null
		else baseline_animation_name
	)
	var baseline_pose: Transform3D = skeleton.get_bone_pose(bone_index)
	var baseline_bone_poses: Array[Transform3D] = []
	for baseline_bone_index: int in range(skeleton.get_bone_count()):
		baseline_bone_poses.append(skeleton.get_bone_pose(baseline_bone_index))
	if animation_player != null:
		animation_player.speed_scale = animation_speed_before
		if animation_assigned_before != StringName():
			animation_player.play(String(animation_assigned_before), 0.0)
			animation_player.seek(animation_position_before, true)
			if not animation_was_playing:
				animation_player.stop(true)
		else:
			animation_player.stop()
	if locomotion_presenter != null:
		locomotion_presenter.set(
			"current_animation_name",
			locomotion_animation_before
		)
	for restore_bone_index: int in range(skeleton.get_bone_count()):
		var packed_rotation: Vector4 = pose_rotations[restore_bone_index]
		skeleton.set_bone_pose_position(
			restore_bone_index,
			pose_positions[restore_bone_index]
		)
		skeleton.set_bone_pose_rotation(
			restore_bone_index,
			Quaternion(
				packed_rotation.x,
				packed_rotation.y,
				packed_rotation.z,
				packed_rotation.w
			).normalized()
		)
		skeleton.set_bone_pose_scale(
			restore_bone_index,
			pose_scales[restore_bone_index]
		)
	skeleton.force_update_all_bone_transforms()
	var restore_ok: bool = bool(presenter.call(
		"_restore_preview_support_candidate_baseline",
		actor,
		held,
		support_anchor,
		seated_snapshot,
		support_slot_id,
		primary_slot_id
	))
	if not restore_ok:
		failed["status"] = &"test_authoring_baseline_restore_failed"
		return failed
	var full_skeleton_restore_ok: bool = true
	for verify_bone_index: int in range(skeleton.get_bone_count()):
		var expected_rotation_data: Vector4 = pose_rotations[verify_bone_index]
		var expected_rotation := Quaternion(
			expected_rotation_data.x,
			expected_rotation_data.y,
			expected_rotation_data.z,
			expected_rotation_data.w
		).normalized()
		if (
			skeleton.get_bone_pose_position(verify_bone_index).distance_to(
				pose_positions[verify_bone_index]
			) > 0.0000001
			or skeleton.get_bone_pose_scale(verify_bone_index).distance_to(
				pose_scales[verify_bone_index]
			) > 0.0000001
			or rad_to_deg(
				skeleton.get_bone_pose_rotation(verify_bone_index).normalized()
					.angle_to(expected_rotation)
			) > 0.0001
		):
			full_skeleton_restore_ok = false
			break
	if not full_skeleton_restore_ok:
		failed["status"] = &"test_authoring_baseline_full_skeleton_restore_mismatch"
		return failed
	return {
		"valid": true,
		"status": &"test_authoring_baseline_pose_ready",
		"point_origin_id": parent_bone_name,
		"pose_parent_origin_id": parent_bone_name,
		"transform_chain": [parent_bone_name, &"RL_BoneRoot"],
		"bone_name": bone_name,
		"basis": baseline_pose.basis.orthonormalized(),
		"origin": baseline_pose.origin,
		"all_bone_poses_parent_local": baseline_bone_poses,
		"baseline_animation_name": baseline_animation_name,
		"applied_baseline_animation_name": applied_baseline_animation_name,
		"source": &"actor._apply_authoring_preview_baseline_pose.animation_t0",
		"full_skeleton_restore_verified": full_skeleton_restore_ok,
	}


func _resolve_test_transaction_bone_pose_basis(
	transaction_snapshot: Dictionary,
	bone_name: StringName
) -> Dictionary:
	var internal_variant: Variant = transaction_snapshot.get("internal_snapshot", null)
	if not internal_variant is Dictionary:
		return {"valid": false}
	var internal_snapshot: Dictionary = internal_variant as Dictionary
	var frame_variant: Variant = internal_snapshot.get("upper_body_pose_frame", null)
	if not frame_variant is Dictionary:
		return {"valid": false}
	var frame: Dictionary = frame_variant as Dictionary
	var names_variant: Variant = frame.get("bone_names", null)
	var rotations_variant: Variant = frame.get("pose_rotations", null)
	if not names_variant is Array or not rotations_variant is PackedVector4Array:
		return {"valid": false}
	var names: Array = names_variant as Array
	var rotations: PackedVector4Array = rotations_variant as PackedVector4Array
	if names.size() != rotations.size():
		return {"valid": false}
	for pose_index: int in range(names.size()):
		if StringName(names[pose_index]) != bone_name:
			continue
		var packed_rotation: Vector4 = rotations[pose_index]
		var rotation := Quaternion(
			packed_rotation.x,
			packed_rotation.y,
			packed_rotation.z,
			packed_rotation.w
		).normalized()
		return {
			"valid": true,
			"bone_name": bone_name,
			"basis": Basis(rotation).orthonormalized(),
			"rotation": rotation,
			"source": &"transaction_snapshot.internal_snapshot.upper_body_pose_frame",
		}
	return {"valid": false}


func _build_test_nearest_first_clavicle_deltas(
	minimum_delta_degrees: int,
	maximum_delta_degrees: int
) -> Array[float]:
	var result: Array[float] = []
	if minimum_delta_degrees <= 0 and maximum_delta_degrees >= 0:
		result.append(0.0)
	var distance: int = 1
	var maximum_distance: int = maxi(
		absi(minimum_delta_degrees),
		absi(maximum_delta_degrees)
	)
	while distance <= maximum_distance:
		if -distance >= minimum_delta_degrees:
			result.append(float(-distance))
		if distance <= maximum_delta_degrees:
			result.append(float(distance))
		distance += 1
	return result


func _scan_test_documented_shoulder_orders(
	context: Dictionary,
	hinge_candidates: Array
) -> Dictionary:
	var result := {
		"valid": true,
		"status": &"test_documented_shoulder_order_scan_complete",
		"point_origin_id": &"RL_BoneRoot",
		"orders": [],
		"exact_legal_count": 0,
	}
	var order_results: Array[Dictionary] = []
	for order_id: StringName in [
		&"local_x_applied_then_local_z",
		&"local_z_applied_then_local_x",
	]:
		var order_result: Dictionary = _search_test_documented_shoulder_order(
			context,
			hinge_candidates,
			order_id
		)
		order_results.append(order_result)
		if bool(order_result.get("exact_legal", false)):
			result["exact_legal_count"] = int(result["exact_legal_count"]) + 1
	result["orders"] = order_results
	return result


func _search_test_documented_shoulder_order(
	context: Dictionary,
	hinge_candidates: Array,
	order_id: StringName
) -> Dictionary:
	var result := {
		"valid": false,
		"status": &"test_documented_shoulder_order_unavailable",
		"order_id": order_id,
		"best_endpoint": {},
		"best_shoulder_range_legal": {},
		"exact_legal": false,
	}
	var left_side: bool = bool(context.get("left_side", false))
	var z_sign: float = -1.0 if left_side else 1.0
	var best_endpoint: Dictionary = {}
	var best_range_legal: Dictionary = {}
	for hinge_variant: Variant in hinge_candidates:
		if not hinge_variant is Dictionary:
			continue
		var hinge_candidate: Dictionary = hinge_variant as Dictionary
		if (
			not bool(hinge_candidate.get("positive_hinge_legal", false))
			or not bool(hinge_candidate.get("elbow_range_legal", false))
		):
			continue
		var hinge_degrees: float = float(hinge_candidate.get(
			"hinge_angle_degrees",
			NAN
		))
		if not is_finite(hinge_degrees):
			continue
		for x_integer: int in range(-180, 181, 2):
			for z_magnitude_integer: int in range(0, 181, 2):
				var candidate: Dictionary = (
					_build_test_documented_shoulder_candidate(
						context,
						hinge_degrees,
						float(x_integer),
						z_sign * float(z_magnitude_integer),
						order_id
					)
				)
				if not bool(candidate.get("valid", false)):
					continue
				if (
					best_endpoint.is_empty()
					or float(candidate.get("endpoint_error_meters", INF))
						< float(best_endpoint.get("endpoint_error_meters", INF))
				):
					best_endpoint = candidate
				if (
					bool(candidate.get("shoulder_range_legal", false))
					and (
						best_range_legal.is_empty()
						or float(candidate.get("endpoint_error_meters", INF))
							< float(best_range_legal.get(
								"endpoint_error_meters",
								INF
							))
					)
				):
					best_range_legal = candidate
	if best_endpoint.is_empty():
		return result
	best_endpoint = _refine_test_documented_shoulder_candidate(
		context,
		order_id,
		best_endpoint,
		false
	)
	if not best_range_legal.is_empty():
		best_range_legal = _refine_test_documented_shoulder_candidate(
			context,
			order_id,
			best_range_legal,
			true
		)
	result["valid"] = true
	result["status"] = &"test_documented_shoulder_order_ready"
	result["best_endpoint"] = best_endpoint
	result["best_shoulder_range_legal"] = best_range_legal
	result["exact_legal"] = (
		not best_range_legal.is_empty()
		and float(best_range_legal.get("endpoint_error_meters", INF)) <= 0.00005
	)
	return result


func _refine_test_documented_shoulder_candidate(
	context: Dictionary,
	order_id: StringName,
	seed: Dictionary,
	require_shoulder_range: bool
) -> Dictionary:
	var best: Dictionary = seed.duplicate(true)
	var left_side: bool = bool(context.get("left_side", false))
	for step_degrees: float in [0.2, 0.02, 0.002]:
		var center_x: float = float(best.get("shoulder_x_degrees", 0.0))
		var center_z: float = float(best.get("shoulder_z_degrees", 0.0))
		for x_offset: int in range(-10, 11):
			for z_offset: int in range(-10, 11):
				var candidate_x: float = wrapf(
					center_x + float(x_offset) * step_degrees,
					-180.0,
					180.0
				)
				var candidate_z: float = clampf(
					center_z + float(z_offset) * step_degrees,
					-180.0 if left_side else 0.0,
					0.0 if left_side else 180.0
				)
				var candidate: Dictionary = (
					_build_test_documented_shoulder_candidate(
						context,
						float(seed.get("hinge_angle_degrees", NAN)),
						candidate_x,
						candidate_z,
						order_id
					)
				)
				if (
					not bool(candidate.get("valid", false))
					or (
						require_shoulder_range
						and not bool(candidate.get("shoulder_range_legal", false))
					)
				):
					continue
				if (
					float(candidate.get("endpoint_error_meters", INF))
					< float(best.get("endpoint_error_meters", INF))
				):
					best = candidate
	return best


func _build_test_documented_shoulder_candidate(
	context: Dictionary,
	hinge_angle_degrees: float,
	shoulder_x_degrees: float,
	shoulder_z_degrees: float,
	order_id: StringName
) -> Dictionary:
	var invalid := {
		"valid": false,
		"status": &"test_documented_shoulder_candidate_invalid",
	}
	if not is_finite(hinge_angle_degrees):
		return invalid
	var upperarm_offset: Vector3 = context.get(
		"upperarm_child_offset",
		Vector3.ZERO
	) as Vector3
	var hand_offset: Vector3 = context.get(
		"forearm_child_offset",
		Vector3.ZERO
	) as Vector3
	var forearm_rest_basis: Basis = context.get(
		"forearm_rest_basis",
		Basis.IDENTITY
	) as Basis
	var target_neutral: Vector3 = context.get(
		"target_neutral",
		Vector3.ZERO
	) as Vector3
	if (
		upperarm_offset.length_squared() <= 0.000000000001
		or hand_offset.length_squared() <= 0.000000000001
		or target_neutral.length_squared() <= 0.000000000001
	):
		return invalid
	var hinge_basis := Basis(
		Vector3.RIGHT,
		deg_to_rad(hinge_angle_degrees)
	)
	var chain_neutral: Vector3 = (
		upperarm_offset
		+ forearm_rest_basis * (hinge_basis * hand_offset)
	)
	var x_basis := Basis(Vector3.RIGHT, deg_to_rad(shoulder_x_degrees))
	var z_basis := Basis(Vector3.BACK, deg_to_rad(shoulder_z_degrees))
	var shoulder_basis: Basis = (
		z_basis * x_basis
		if order_id == &"local_x_applied_then_local_z"
		else x_basis * z_basis
	).orthonormalized()
	var endpoint_error: float = (
		(shoulder_basis * chain_neutral).distance_to(target_neutral)
	)
	var upperarm_neutral_global_basis: Basis = context.get(
		"upperarm_neutral_global_basis",
		Basis.IDENTITY
	) as Basis
	var shoulder_skeleton: Vector3 = context.get(
		"shoulder_skeleton",
		Vector3.ZERO
	) as Vector3
	var root_skeleton: Vector3 = context.get(
		"clavicle_root_skeleton",
		Vector3.ZERO
	) as Vector3
	var upperarm_global_basis: Basis = (
		upperarm_neutral_global_basis * shoulder_basis
	).orthonormalized()
	var elbow_skeleton: Vector3 = (
		shoulder_skeleton + upperarm_global_basis * upperarm_offset
	)
	var shoulder_parent_vector: Vector3 = root_skeleton - shoulder_skeleton
	var shoulder_child_vector: Vector3 = elbow_skeleton - shoulder_skeleton
	if (
		shoulder_parent_vector.length_squared() <= 0.000000000001
		or shoulder_child_vector.length_squared() <= 0.000000000001
	):
		return invalid
	var shoulder_angle_degrees: float = rad_to_deg(acos(clampf(
		shoulder_parent_vector.normalized().dot(
			shoulder_child_vector.normalized()
		),
		-1.0,
		1.0
	)))
	var shoulder_range_legal: bool = (
		shoulder_angle_degrees
			>= float(context.get("shoulder_min_degrees", 0.0))
		and shoulder_angle_degrees
			<= float(context.get("shoulder_max_degrees", 180.0))
	)
	return {
		"valid": true,
		"status": &"test_documented_shoulder_candidate_ready",
		"point_origin_id": &"RL_BoneRoot",
		"order_id": order_id,
		"hinge_angle_degrees": hinge_angle_degrees,
		"shoulder_x_degrees": shoulder_x_degrees,
		"shoulder_z_degrees": shoulder_z_degrees,
		"shoulder_angle_degrees": shoulder_angle_degrees,
		"shoulder_range_legal": shoulder_range_legal,
		"endpoint_error_meters": endpoint_error,
		"shoulder_basis": shoulder_basis,
		"upperarm_global_basis": upperarm_global_basis,
		"elbow_skeleton": elbow_skeleton,
	}


func _solve_test_verified_hinge_roots(context: Dictionary) -> Dictionary:
	var result := {
		"valid": false,
		"status": &"test_verified_hinge_roots_invalid",
		"equation_k": NAN,
		"equation_radius": NAN,
		"candidates": [],
	}
	var upperarm_offset: Vector3 = context.get(
		"upperarm_child_offset",
		Vector3.ZERO
	) as Vector3
	var hand_offset: Vector3 = context.get(
		"forearm_child_offset",
		Vector3.ZERO
	) as Vector3
	var forearm_rest_basis: Basis = context.get(
		"forearm_rest_basis",
		Basis.IDENTITY
	) as Basis
	var target_neutral: Vector3 = context.get(
		"target_neutral",
		Vector3.ZERO
	) as Vector3
	if (
		upperarm_offset.length_squared() <= 0.000000000001
		or hand_offset.length_squared() <= 0.000000000001
		or target_neutral.length_squared() <= 0.000000000001
	):
		return result
	var c: Vector3 = forearm_rest_basis.inverse() * upperarm_offset
	var equation_a: float = c.y * hand_offset.y + c.z * hand_offset.z
	var equation_b: float = c.z * hand_offset.y - c.y * hand_offset.z
	var equation_k: float = (
		0.5 * (
			target_neutral.length_squared()
			- upperarm_offset.length_squared()
			- hand_offset.length_squared()
		)
		- c.x * hand_offset.x
	)
	var equation_radius: float = sqrt(
		equation_a * equation_a + equation_b * equation_b
	)
	result["equation_k"] = equation_k
	result["equation_radius"] = equation_radius
	if equation_radius <= 0.000000000001:
		result["status"] = &"test_verified_hinge_roots_degenerate"
		return result
	if absf(equation_k) > equation_radius + 0.00000001:
		result["valid"] = true
		result["status"] = &"test_verified_hinge_roots_unreachable"
		return result
	var phase: float = atan2(equation_b, equation_a)
	var alpha: float = acos(clampf(
		equation_k / equation_radius,
		-1.0,
		1.0
	))
	var root_angles: Array[float] = []
	_append_test_unique_wrapped_angle(root_angles, phase + alpha)
	_append_test_unique_wrapped_angle(root_angles, phase - alpha)
	root_angles = _order_test_angles_nearest_zero(root_angles)
	var candidates: Array[Dictionary] = []
	for hinge_angle_radians: float in root_angles:
		var candidate: Dictionary = _build_test_verified_hinge_candidate(
			context,
			hinge_angle_radians
		)
		if bool(candidate.get("valid", false)):
			candidates.append(candidate)
	result["valid"] = true
	result["status"] = &"test_verified_hinge_roots_ready"
	result["candidates"] = candidates
	return result


func _build_test_verified_hinge_candidate(
	context: Dictionary,
	hinge_angle_radians: float
) -> Dictionary:
	var invalid := {
		"valid": false,
		"status": &"test_verified_hinge_candidate_invalid",
	}
	var upperarm_offset: Vector3 = context.get(
		"upperarm_child_offset",
		Vector3.ZERO
	) as Vector3
	var hand_offset: Vector3 = context.get(
		"forearm_child_offset",
		Vector3.ZERO
	) as Vector3
	var target_neutral: Vector3 = context.get(
		"target_neutral",
		Vector3.ZERO
	) as Vector3
	var forearm_rest_basis: Basis = context.get(
		"forearm_rest_basis",
		Basis.IDENTITY
	) as Basis
	var upperarm_rest_basis: Basis = context.get(
		"upperarm_rest_basis",
		Basis.IDENTITY
	) as Basis
	var forearm_hinge_basis := Basis(Vector3.RIGHT, hinge_angle_radians)
	var chain_neutral: Vector3 = (
		upperarm_offset
		+ forearm_rest_basis * (forearm_hinge_basis * hand_offset)
	)
	var swing_state: Dictionary = _build_test_verified_zero_y_twist_swing(
		chain_neutral,
		target_neutral
	)
	if not bool(swing_state.get("valid", false)):
		invalid["status"] = swing_state.get("status", invalid["status"])
		return invalid
	var upperarm_swing_quaternion: Quaternion = swing_state.get(
		"quaternion",
		Quaternion.IDENTITY
	) as Quaternion
	var upperarm_swing_basis: Basis = Basis(
		upperarm_swing_quaternion
	).orthonormalized()
	var upperarm_local_basis: Basis = (
		upperarm_rest_basis * upperarm_swing_basis
	).orthonormalized()
	var forearm_local_basis: Basis = (
		forearm_rest_basis * forearm_hinge_basis
	).orthonormalized()
	var upperarm_neutral_global_basis: Basis = context.get(
		"upperarm_neutral_global_basis",
		Basis.IDENTITY
	) as Basis
	var upperarm_global_basis: Basis = (
		upperarm_neutral_global_basis * upperarm_swing_basis
	).orthonormalized()
	var forearm_global_basis: Basis = (
		upperarm_global_basis * forearm_local_basis
	).orthonormalized()
	var shoulder_skeleton: Vector3 = context.get(
		"shoulder_skeleton",
		Vector3.ZERO
	) as Vector3
	var elbow_skeleton: Vector3 = (
		shoulder_skeleton + upperarm_global_basis * upperarm_offset
	)
	var predicted_hand_skeleton: Vector3 = (
		elbow_skeleton + forearm_global_basis * hand_offset
	)
	var hand_target_skeleton: Transform3D = context.get(
		"hand_target_skeleton",
		Transform3D.IDENTITY
	) as Transform3D
	var endpoint_error: float = predicted_hand_skeleton.distance_to(
		hand_target_skeleton.origin
	)
	var hand_local_basis: Basis = (
		forearm_global_basis.inverse()
		* hand_target_skeleton.basis.orthonormalized()
	).orthonormalized()
	var root_skeleton: Vector3 = context.get(
		"clavicle_root_skeleton",
		Vector3.ZERO
	) as Vector3
	var shoulder_parent_vector: Vector3 = root_skeleton - shoulder_skeleton
	var shoulder_child_vector: Vector3 = elbow_skeleton - shoulder_skeleton
	var elbow_parent_vector: Vector3 = shoulder_skeleton - elbow_skeleton
	var elbow_child_vector: Vector3 = (
		hand_target_skeleton.origin - elbow_skeleton
	)
	if (
		shoulder_parent_vector.length_squared() <= 0.000000000001
		or shoulder_child_vector.length_squared() <= 0.000000000001
		or elbow_parent_vector.length_squared() <= 0.000000000001
		or elbow_child_vector.length_squared() <= 0.000000000001
	):
		return invalid
	var shoulder_angle_degrees: float = rad_to_deg(acos(clampf(
		shoulder_parent_vector.normalized().dot(
			shoulder_child_vector.normalized()
		),
		-1.0,
		1.0
	)))
	var elbow_angle_degrees: float = rad_to_deg(acos(clampf(
		elbow_parent_vector.normalized().dot(elbow_child_vector.normalized()),
		-1.0,
		1.0
	)))
	var shoulder_direction: Vector3 = upperarm_swing_basis * Vector3.UP
	var left_side: bool = bool(context.get("left_side", false))
	var shoulder_half_plane_legal: bool = (
		shoulder_direction.x >= -0.000001
		if left_side
		else shoulder_direction.x <= 0.000001
	)
	var positive_hinge_legal: bool = (
		hinge_angle_radians >= -0.000001
		and hinge_angle_radians <= PI + 0.000001
	)
	var no_upperarm_y_twist_legal: bool = (
		absf(upperarm_swing_quaternion.y) <= 0.000001
	)
	var shoulder_range_legal: bool = (
		shoulder_angle_degrees
			>= float(context.get("shoulder_min_degrees", 0.0))
		and shoulder_angle_degrees
			<= float(context.get("shoulder_max_degrees", 180.0))
	)
	var elbow_range_legal: bool = (
		elbow_angle_degrees
			>= float(context.get("elbow_min_degrees", 0.0))
		and elbow_angle_degrees
			<= float(context.get("elbow_max_degrees", 180.0))
	)
	var rom_legal: bool = (
		endpoint_error <= 0.00005
		and positive_hinge_legal
		and no_upperarm_y_twist_legal
		and shoulder_half_plane_legal
		and shoulder_range_legal
		and elbow_range_legal
	)
	return {
		"valid": true,
		"status": (
			&"test_verified_hinge_candidate_rom_legal"
			if rom_legal
			else &"test_verified_hinge_candidate_rom_rejected"
		),
		"point_origin_id": &"RL_BoneRoot",
		"left_side": left_side,
		"clavicle_delta_degrees": float(context.get(
			"clavicle_delta_degrees",
			0.0
		)),
		"hinge_angle_degrees": rad_to_deg(hinge_angle_radians),
		"shoulder_angle_degrees": shoulder_angle_degrees,
		"elbow_angle_degrees": elbow_angle_degrees,
		"shoulder_direction_rest_local": shoulder_direction,
		"shoulder_half_plane_legal": shoulder_half_plane_legal,
		"positive_hinge_legal": positive_hinge_legal,
		"no_upperarm_y_twist_legal": no_upperarm_y_twist_legal,
		"shoulder_range_legal": shoulder_range_legal,
		"elbow_range_legal": elbow_range_legal,
		"predicted_hand_error_meters_skeleton": endpoint_error,
		"candidate_clavicle_local_basis": context.get(
			"candidate_clavicle_local_basis",
			Basis.IDENTITY
		),
		"candidate_upperarm_local_basis": upperarm_local_basis,
		"candidate_forearm_local_basis": forearm_local_basis,
		"candidate_hand_local_basis": hand_local_basis,
		"upperarm_swing_basis": upperarm_swing_basis,
		"forearm_hinge_basis": forearm_hinge_basis,
		"shoulder_skeleton": shoulder_skeleton,
		"elbow_skeleton": elbow_skeleton,
		"predicted_hand_skeleton": predicted_hand_skeleton,
		"rom_legal": rom_legal,
	}


func _build_test_verified_zero_y_twist_swing(
	source_vector: Vector3,
	target_vector: Vector3
) -> Dictionary:
	if (
		source_vector.length_squared() <= 0.000000000001
		or target_vector.length_squared() <= 0.000000000001
	):
		return {
			"valid": false,
			"status": &"test_verified_swing_zero_vector",
		}
	var source_hat: Vector3 = source_vector.normalized()
	var target_hat: Vector3 = target_vector.normalized()
	var direction_dot: float = clampf(source_hat.dot(target_hat), -1.0, 1.0)
	if direction_dot <= -1.0 + 0.000000001:
		return {
			"valid": false,
			"status": &"test_verified_swing_antipodal_degenerate",
		}
	var shortest_arc := Quaternion.IDENTITY
	if direction_dot < 1.0 - 0.000000001:
		var shortest_axis: Vector3 = source_hat.cross(target_hat)
		if shortest_axis.length_squared() <= 0.000000000001:
			return {
				"valid": false,
				"status": &"test_verified_swing_axis_degenerate",
			}
		shortest_arc = Quaternion(
			shortest_axis.normalized(),
			acos(direction_dot)
		).normalized()
	var shortest_vector := Vector3(
		shortest_arc.x,
		shortest_arc.y,
		shortest_arc.z
	)
	var equation_a: float = shortest_vector.y
	var equation_b: float = (
		shortest_arc.w * source_hat.y
		+ shortest_vector.cross(source_hat).y
	)
	var half_twist: float = 0.0
	if absf(equation_a) > 0.000000000001 or absf(equation_b) > 0.000000000001:
		half_twist = atan2(-equation_a, equation_b)
	var swing: Quaternion = (
		shortest_arc
		* Quaternion(source_hat, 2.0 * half_twist)
	).normalized()
	var mapped: Vector3 = Basis(swing) * source_vector
	var mapping_error: float = mapped.distance_to(target_vector)
	var length_mismatch: float = absf(source_vector.length() - target_vector.length())
	var zero_y_twist_residual: float = absf(swing.y)
	var valid: bool = (
		mapping_error <= 0.00005
		and length_mismatch <= 0.00005
		and zero_y_twist_residual <= 0.000001
	)
	return {
		"valid": valid,
		"status": (
			&"test_verified_swing_ready"
			if valid
			else &"test_verified_swing_verification_failed"
		),
		"quaternion": swing,
		"mapping_error_meters": mapping_error,
		"length_mismatch_meters": length_mismatch,
		"zero_y_twist_residual": zero_y_twist_residual,
	}


func _apply_test_verified_anatomical_candidate(
	actor: Node3D,
	support_slot_id: StringName,
	clavicle_index: int,
	upperarm_index: int,
	forearm_index: int,
	hand_index: int,
	baseline_clavicle_basis: Basis,
	upperarm_rest_basis: Basis,
	forearm_rest_basis: Basis,
	hand_target_skeleton: Transform3D,
	hand_target_world: Transform3D,
	candidate: Dictionary
) -> Dictionary:
	var result := {
		"valid": false,
		"exact": false,
		"status": &"test_verified_anatomical_apply_unavailable",
		"point_origin_id": &"RL_BoneRoot",
	}
	var skeleton: Skeleton3D = actor.get("skeleton") as Skeleton3D
	if skeleton == null:
		return result
	var clavicle_basis: Basis = candidate.get(
		"candidate_clavicle_local_basis",
		Basis.IDENTITY
	) as Basis
	var upperarm_basis: Basis = candidate.get(
		"candidate_upperarm_local_basis",
		Basis.IDENTITY
	) as Basis
	var forearm_basis: Basis = candidate.get(
		"candidate_forearm_local_basis",
		Basis.IDENTITY
	) as Basis
	var hand_basis: Basis = candidate.get(
		"candidate_hand_local_basis",
		Basis.IDENTITY
	) as Basis
	skeleton.set_bone_pose_rotation(
		clavicle_index,
		clavicle_basis.get_rotation_quaternion().normalized()
	)
	skeleton.set_bone_pose_rotation(
		upperarm_index,
		upperarm_basis.get_rotation_quaternion().normalized()
	)
	skeleton.set_bone_pose_rotation(
		forearm_index,
		forearm_basis.get_rotation_quaternion().normalized()
	)
	skeleton.set_bone_pose_rotation(
		hand_index,
		hand_basis.get_rotation_quaternion().normalized()
	)
	skeleton.force_update_all_bone_transforms()
	var actual_clavicle_basis: Basis = skeleton.get_bone_pose(
		clavicle_index
	).basis.orthonormalized()
	var actual_upperarm_basis: Basis = skeleton.get_bone_pose(
		upperarm_index
	).basis.orthonormalized()
	var actual_forearm_basis: Basis = skeleton.get_bone_pose(
		forearm_index
	).basis.orthonormalized()
	var actual_hand_local_basis: Basis = skeleton.get_bone_pose(
		hand_index
	).basis.orthonormalized()
	var actual_hand_skeleton: Transform3D = skeleton.get_bone_global_pose(hand_index)
	var actual_hand_world: Transform3D = skeleton.global_transform * actual_hand_skeleton
	var clavicle_basis_error: float = _resolve_test_basis_delta_degrees(
		clavicle_basis,
		actual_clavicle_basis
	)
	var upperarm_basis_error: float = _resolve_test_basis_delta_degrees(
		upperarm_basis,
		actual_upperarm_basis
	)
	var forearm_basis_error: float = _resolve_test_basis_delta_degrees(
		forearm_basis,
		actual_forearm_basis
	)
	var hand_local_basis_error: float = _resolve_test_basis_delta_degrees(
		hand_basis,
		actual_hand_local_basis
	)
	var hand_position_error_skeleton: float = actual_hand_skeleton.origin.distance_to(
		hand_target_skeleton.origin
	)
	var hand_position_error_world: float = actual_hand_world.origin.distance_to(
		hand_target_world.origin
	)
	var hand_basis_error_world: float = _resolve_test_basis_delta_degrees(
		hand_target_world.basis.orthonormalized(),
		actual_hand_world.basis.orthonormalized()
	)
	var clavicle_relative_baseline: Basis = (
		baseline_clavicle_basis.inverse() * actual_clavicle_basis
	).orthonormalized()
	var upperarm_relative_rest: Basis = (
		upperarm_rest_basis.inverse() * actual_upperarm_basis
	).orthonormalized()
	var forearm_relative_rest: Basis = (
		forearm_rest_basis.inverse() * actual_forearm_basis
	).orthonormalized()
	var clavicle_relative_quaternion: Quaternion = (
		_canonicalize_test_quaternion(
			clavicle_relative_baseline.get_rotation_quaternion()
		)
	)
	var upperarm_relative_quaternion: Quaternion = (
		_canonicalize_test_quaternion(
			upperarm_relative_rest.get_rotation_quaternion()
		)
	)
	var forearm_relative_quaternion: Quaternion = (
		_canonicalize_test_quaternion(
			forearm_relative_rest.get_rotation_quaternion()
		)
	)
	var clavicle_off_axis_residual: float = sqrt(
		clavicle_relative_quaternion.y * clavicle_relative_quaternion.y
		+ clavicle_relative_quaternion.z * clavicle_relative_quaternion.z
	)
	var upperarm_y_twist_residual: float = absf(
		upperarm_relative_quaternion.y
	)
	var forearm_off_x_residual: float = sqrt(
		forearm_relative_quaternion.y * forearm_relative_quaternion.y
		+ forearm_relative_quaternion.z * forearm_relative_quaternion.z
	)
	var actual_clavicle_delta_degrees: float = (
		_resolve_test_signed_axis_twist_degrees(
			clavicle_relative_baseline,
			Vector3.RIGHT
		)
	)
	var actual_hinge_angle_degrees: float = (
		_resolve_test_signed_axis_twist_degrees(
			forearm_relative_rest,
			Vector3.RIGHT
		)
	)
	var arm_range_state: Dictionary = actor.call(
		"get_authoring_arm_joint_range_state",
		support_slot_id
	) as Dictionary
	var range_legal: bool = (
		bool(arm_range_state.get("valid", false))
		and bool(arm_range_state.get("legal", false))
	)
	var expected_clavicle_delta_degrees: float = float(candidate.get(
		"clavicle_delta_degrees",
		0.0
	))
	var expected_hinge_angle_degrees: float = float(candidate.get(
		"hinge_angle_degrees",
		0.0
	))
	var exact: bool = (
		clavicle_basis_error <= 0.01
		and upperarm_basis_error <= 0.01
		and forearm_basis_error <= 0.01
		and hand_local_basis_error <= 0.01
		and hand_position_error_skeleton <= 0.00005
		and hand_position_error_world <= 0.00005
		and hand_basis_error_world <= 0.05
		and clavicle_off_axis_residual <= 0.000001
		and upperarm_y_twist_residual <= 0.000001
		and forearm_off_x_residual <= 0.000001
		and absf(
			actual_clavicle_delta_degrees
			- expected_clavicle_delta_degrees
		) <= 0.01
		and absf(actual_hinge_angle_degrees - expected_hinge_angle_degrees) <= 0.01
		and actual_hinge_angle_degrees >= -0.001
		and bool(candidate.get("shoulder_half_plane_legal", false))
		and range_legal
	)
	result.merge({
		"valid": true,
		"exact": exact,
		"status": (
			&"test_verified_anatomical_apply_exact"
			if exact
			else &"test_verified_anatomical_apply_mismatch"
		),
		"clavicle_basis_error_degrees": clavicle_basis_error,
		"upperarm_basis_error_degrees": upperarm_basis_error,
		"forearm_basis_error_degrees": forearm_basis_error,
		"hand_local_basis_error_degrees": hand_local_basis_error,
		"hand_position_error_meters_skeleton": hand_position_error_skeleton,
		"hand_position_error_meters_world": hand_position_error_world,
		"hand_basis_error_degrees_world": hand_basis_error_world,
		"clavicle_off_axis_quaternion_residual": clavicle_off_axis_residual,
		"upperarm_y_twist_quaternion_residual": upperarm_y_twist_residual,
		"forearm_off_x_quaternion_residual": forearm_off_x_residual,
		"actual_clavicle_delta_degrees": actual_clavicle_delta_degrees,
		"actual_hinge_angle_degrees": actual_hinge_angle_degrees,
		"arm_range_legal": range_legal,
		"arm_range_state": arm_range_state.duplicate(true),
	}, true)
	return result


func _build_test_verified_anatomical_candidate_summary(
	candidate: Dictionary,
	applied: Dictionary
) -> Dictionary:
	return {
		"status": candidate.get("status", StringName()),
		"clavicle_zero_frame": &"authoring_baseline_animation_t0_parent_local_pose",
		"clavicle_delta_degrees": float(candidate.get(
			"clavicle_delta_degrees",
			NAN
		)),
		"hinge_angle_degrees": float(candidate.get("hinge_angle_degrees", NAN)),
		"shoulder_angle_degrees": float(candidate.get(
			"shoulder_angle_degrees",
			NAN
		)),
		"elbow_angle_degrees": float(candidate.get(
			"elbow_angle_degrees",
			NAN
		)),
		"shoulder_direction_rest_local": candidate.get(
			"shoulder_direction_rest_local",
			Vector3.ZERO
		),
		"shoulder_half_plane_legal": bool(candidate.get(
			"shoulder_half_plane_legal",
			false
		)),
		"positive_hinge_legal": bool(candidate.get(
			"positive_hinge_legal",
			false
		)),
		"no_upperarm_y_twist_legal": bool(candidate.get(
			"no_upperarm_y_twist_legal",
			false
		)),
		"shoulder_range_legal": bool(candidate.get(
			"shoulder_range_legal",
			false
		)),
		"elbow_range_legal": bool(candidate.get(
			"elbow_range_legal",
			false
		)),
		"predicted_hand_error_meters_skeleton": float(candidate.get(
			"predicted_hand_error_meters_skeleton",
			INF
		)),
		"rom_legal": bool(candidate.get("rom_legal", false)),
		"apply_status": applied.get("status", StringName()),
		"applied_exact": bool(applied.get("exact", false)),
		"hand_position_error_meters_world": float(applied.get(
			"hand_position_error_meters_world",
			INF
		)),
		"hand_basis_error_degrees_world": float(applied.get(
			"hand_basis_error_degrees_world",
			INF
		)),
		"upperarm_y_twist_quaternion_residual": float(applied.get(
			"upperarm_y_twist_quaternion_residual",
			INF
		)),
		"forearm_off_x_quaternion_residual": float(applied.get(
			"forearm_off_x_quaternion_residual",
			INF
		)),
		"arm_range_legal_after_apply": bool(applied.get(
			"arm_range_legal",
			false
		)),
	}


func _canonicalize_test_quaternion(value: Quaternion) -> Quaternion:
	var normalized: Quaternion = value.normalized()
	if normalized.w < 0.0:
		return Quaternion(
			-normalized.x,
			-normalized.y,
			-normalized.z,
			-normalized.w
		)
	return normalized


func _resolve_test_signed_axis_twist_degrees(
	basis_delta: Basis,
	axis: Vector3
) -> float:
	if axis.length_squared() <= 0.000000000001:
		return NAN
	var rotation: Quaternion = _canonicalize_test_quaternion(
		basis_delta.orthonormalized().get_rotation_quaternion()
	)
	var normalized_axis: Vector3 = axis.normalized()
	var projected_scalar: float = Vector3(
		rotation.x,
		rotation.y,
		rotation.z
	).dot(normalized_axis)
	return rad_to_deg(_wrap_test_angle_radians(
		2.0 * atan2(projected_scalar, rotation.w)
	))


func _resolve_test_basis_delta_degrees(
	from_basis: Basis,
	to_basis: Basis
) -> float:
	return rad_to_deg(
		from_basis.orthonormalized().get_rotation_quaternion().angle_to(
			to_basis.orthonormalized().get_rotation_quaternion()
		)
	)


func _append_test_unique_wrapped_angle(
	angles: Array[float],
	angle_radians: float
) -> void:
	var wrapped: float = _wrap_test_angle_radians(angle_radians)
	for existing: float in angles:
		if absf(_wrap_test_angle_radians(existing - wrapped)) <= 0.0000001:
			return
	angles.append(wrapped)


func _order_test_angles_nearest_zero(angles: Array[float]) -> Array[float]:
	var remaining: Array[float] = angles.duplicate()
	var ordered: Array[float] = []
	while not remaining.is_empty():
		var best_index: int = 0
		var best_distance: float = INF
		var best_value: float = INF
		for angle_index: int in range(remaining.size()):
			var value: float = _wrap_test_angle_radians(remaining[angle_index])
			var distance: float = absf(value)
			if (
				distance < best_distance - 0.0000001
				or (
					absf(distance - best_distance) <= 0.0000001
					and value < best_value
				)
			):
				best_index = angle_index
				best_distance = distance
				best_value = value
		ordered.append(_wrap_test_angle_radians(remaining[best_index]))
		remaining.remove_at(best_index)
	return ordered


func _wrap_test_angle_radians(angle_radians: float) -> float:
	return atan2(sin(angle_radians), cos(angle_radians))


# Kept only so the discarded first frame experiment below remains parseable.
# The executable diagnostic route above never calls this writer.
func _apply_test_anatomical_arm_candidate(
	_actor: Node3D,
	_support_slot_id: StringName,
	_clavicle_bone: StringName,
	_upperarm_bone: StringName,
	_forearm_bone: StringName,
	_hand_bone: StringName,
	_clavicle_index: int,
	_upperarm_index: int,
	_forearm_index: int,
	_hand_index: int,
	_clavicle_rest: Transform3D,
	_upperarm_rest: Transform3D,
	_forearm_rest: Transform3D,
	_hand_world_before: Transform3D,
	_candidate: Dictionary
) -> Dictionary:
	return {
		"valid": false,
		"exact": false,
		"status": &"discarded_first_frame_experiment_not_executed",
	}


func _build_test_anatomical_candidate_summary(
	candidate: Dictionary,
	applied: Dictionary
) -> Dictionary:
	return {
		"status": candidate.get("status", StringName()),
		"clavicle_angle_degrees": candidate.get("clavicle_angle_degrees", NAN),
		"hinge_angle_degrees": candidate.get("hinge_angle_degrees", NAN),
		"shoulder_angle_degrees": candidate.get("shoulder_angle_degrees", NAN),
		"elbow_angle_degrees": candidate.get("elbow_angle_degrees", NAN),
		"rom_legal": candidate.get("rom_legal", false),
		"applied_exact": applied.get("exact", false),
	}


func _scan_test_support_anatomical_joint_space_candidates(
	presenter: Object,
	actor: Node3D,
	held: Node3D,
	transaction_snapshot: Dictionary,
	support_slot_id: StringName,
	primary_slot_id: StringName
) -> Dictionary:
	var result := {
		"valid": false,
		"status": &"test_anatomical_joint_scan_unavailable",
		"point_origin_id": &"RL_BoneRoot",
		"support_slot_id": support_slot_id,
		"primary_slot_id": primary_slot_id,
		"clavicle_angle_min_degrees": -10.0,
		"clavicle_angle_max_degrees": 5.0,
		"clavicle_sample_count": 0,
		"hinge_root_count": 0,
		"rom_legal_count": 0,
		"applied_exact_count": 0,
		"primary_weapon_legal_count": 0,
		"body_legal_count": 0,
		"surface_identity_count": 0,
		"full_legal_count": 0,
		"full_legal_candidate": {},
		"best_rejected": {},
		"candidate_summaries": [],
	}
	if (
		presenter == null
		or actor == null
		or held == null
		or support_slot_id not in [&"hand_right", &"hand_left"]
		or primary_slot_id not in [&"hand_right", &"hand_left"]
		or support_slot_id == primary_slot_id
	):
		return result
	var skeleton: Skeleton3D = actor.get("skeleton") as Skeleton3D
	if skeleton == null:
		result["status"] = &"test_anatomical_joint_scan_skeleton_missing"
		return result
	var left_side: bool = support_slot_id == &"hand_left"
	var clavicle_bone: StringName = (
		&"CC_Base_L_Clavicle" if left_side else &"CC_Base_R_Clavicle"
	)
	var upperarm_bone: StringName = (
		&"CC_Base_L_Upperarm" if left_side else &"CC_Base_R_Upperarm"
	)
	var forearm_bone: StringName = (
		&"CC_Base_L_Forearm" if left_side else &"CC_Base_R_Forearm"
	)
	var hand_bone: StringName = (
		&"CC_Base_L_Hand" if left_side else &"CC_Base_R_Hand"
	)
	var clavicle_index: int = skeleton.find_bone(String(clavicle_bone))
	var upperarm_index: int = skeleton.find_bone(String(upperarm_bone))
	var forearm_index: int = skeleton.find_bone(String(forearm_bone))
	var hand_index: int = skeleton.find_bone(String(hand_bone))
	if (
		clavicle_index < 0
		or upperarm_index < 0
		or forearm_index < 0
		or hand_index < 0
		or skeleton.get_bone_parent(upperarm_index) != clavicle_index
		or skeleton.get_bone_parent(forearm_index) != upperarm_index
		or skeleton.get_bone_parent(hand_index) != forearm_index
	):
		result["status"] = &"test_anatomical_joint_scan_chain_invalid"
		return result
	var spine_index: int = skeleton.get_bone_parent(clavicle_index)
	if spine_index < 0:
		result["status"] = &"test_anatomical_joint_scan_spine_missing"
		return result
	var seated_snapshot: Dictionary = actor.call(
		"capture_authoring_active_grip_transaction_state",
		support_slot_id
	) as Dictionary
	if not bool(seated_snapshot.get("valid", false)):
		result["status"] = &"test_anatomical_joint_scan_snapshot_failed"
		return result
	var secondary_guide := held.get_node_or_null("SecondaryGripGuide") as Node3D
	if secondary_guide == null:
		result["status"] = &"test_anatomical_joint_scan_guide_missing"
		return result

	# Godot exposes the complete parent-local pose here. The imported rest is a
	# second absolute parent-local frame; rest^-1 * pose is therefore the authored
	# local delta. Never multiply parent * rest * pose, which double-counts rest.
	var spine_global: Transform3D = skeleton.get_bone_global_pose(spine_index)
	var clavicle_rest: Transform3D = skeleton.get_bone_rest(clavicle_index)
	var clavicle_pose: Transform3D = skeleton.get_bone_pose(clavicle_index)
	var upperarm_rest: Transform3D = skeleton.get_bone_rest(upperarm_index)
	var upperarm_pose: Transform3D = skeleton.get_bone_pose(upperarm_index)
	var forearm_rest: Transform3D = skeleton.get_bone_rest(forearm_index)
	var forearm_pose: Transform3D = skeleton.get_bone_pose(forearm_index)
	var hand_pose: Transform3D = skeleton.get_bone_pose(hand_index)
	var hand_skeleton: Vector3 = skeleton.get_bone_global_pose(hand_index).origin
	var hand_world_before: Transform3D = (
		skeleton.global_transform * skeleton.get_bone_global_pose(hand_index)
	)
	var upperarm_child_offset: Vector3 = forearm_pose.origin
	var forearm_child_offset: Vector3 = hand_pose.origin
	var solve_epsilon: float = 0.000001
	if (
		upperarm_child_offset.length_squared() <= solve_epsilon * solve_epsilon
		or forearm_child_offset.length_squared() <= solve_epsilon * solve_epsilon
	):
		result["status"] = &"test_anatomical_joint_scan_segment_invalid"
		return result
	var clavicle_delta_basis: Basis = (
		clavicle_rest.basis.orthonormalized().inverse()
		* clavicle_pose.basis.orthonormalized()
	).orthonormalized()
	var baseline_clavicle_angle_degrees: float = (
		_resolve_test_signed_axis_twist_degrees(
			clavicle_delta_basis,
			Vector3.RIGHT
		)
	)
	var clavicle_angles: Array[float] = (
		_build_test_nearest_first_clavicle_angles(
			baseline_clavicle_angle_degrees,
			-10,
			5
		)
	)
	result["baseline_clavicle_angle_degrees"] = baseline_clavicle_angle_degrees
	result["baseline_clavicle_delta_off_axis_degrees"] = (
		_resolve_test_basis_delta_degrees(
			clavicle_delta_basis,
			Basis(
				Vector3.RIGHT,
				deg_to_rad(baseline_clavicle_angle_degrees)
			)
		)
	)
	result["clavicle_angles_nearest_first"] = clavicle_angles.duplicate()
	result["clavicle_sample_count"] = clavicle_angles.size()
	var shoulder_min_degrees: float = float(actor.get(
		"authoring_shoulder_min_plane_angle_degrees"
	))
	var shoulder_max_degrees: float = float(actor.get(
		"authoring_shoulder_max_plane_angle_degrees"
	))
	var elbow_min_degrees: float = float(actor.get(
		"authoring_elbow_min_plane_angle_degrees"
	))
	var elbow_max_degrees: float = float(actor.get(
		"authoring_elbow_max_plane_angle_degrees"
	))
	var baseline_elbow_skeleton: Vector3 = skeleton.get_bone_global_pose(
		forearm_index
	).origin
	var actor_basis_world: Basis = actor.global_basis.orthonormalized()
	var skeleton_basis_world: Basis = skeleton.global_basis
	if absf(skeleton_basis_world.determinant()) <= solve_epsilon:
		result["status"] = &"test_anatomical_joint_scan_basis_invalid"
		return result
	var side_sign: float = -1.0 if left_side else 1.0
	var fallback_pole_skeleton: Vector3 = (
		skeleton_basis_world.inverse()
		* (
			actor_basis_world.x
				* float(actor.get("support_arm_ik_pole_side_offset_meters"))
				* side_sign
			- actor_basis_world.y
				* float(actor.get("support_arm_ik_pole_down_offset_meters"))
		)
	)
	var best_rejected: Dictionary = {}
	var best_rejected_gate_count: int = -1
	var candidate_summaries: Array[Dictionary] = []
	var scan_failed: bool = false
	for clavicle_angle_degrees: float in clavicle_angles:
		var candidate_clavicle_basis: Basis = (
			clavicle_rest.basis.orthonormalized()
			* Basis(Vector3.RIGHT, deg_to_rad(clavicle_angle_degrees))
		).orthonormalized()
		var candidate_clavicle_local := Transform3D(
			candidate_clavicle_basis,
			clavicle_pose.origin
		)
		var candidate_clavicle_global: Transform3D = (
			spine_global * candidate_clavicle_local
		)
		var root_skeleton: Vector3 = candidate_clavicle_global.origin
		var shoulder_skeleton: Vector3 = (
			candidate_clavicle_global * upperarm_pose.origin
		)
		var shoulder_to_hand: Vector3 = hand_skeleton - shoulder_skeleton
		var shoulder_to_hand_distance: float = shoulder_to_hand.length()
		var upperarm_length: float = upperarm_child_offset.length()
		var forearm_length: float = forearm_child_offset.length()
		if (
			shoulder_to_hand_distance
				< absf(upperarm_length - forearm_length) - solve_epsilon
			or shoulder_to_hand_distance
				> upperarm_length + forearm_length + solve_epsilon
		):
			continue
		var arm_axis: Vector3 = shoulder_to_hand / shoulder_to_hand_distance
		var elbow_axis_distance: float = (
			upperarm_length * upperarm_length
			- forearm_length * forearm_length
			+ shoulder_to_hand_distance * shoulder_to_hand_distance
		) / (2.0 * shoulder_to_hand_distance)
		var elbow_radial_squared: float = (
			upperarm_length * upperarm_length
			- elbow_axis_distance * elbow_axis_distance
		)
		if elbow_radial_squared < -(solve_epsilon * solve_epsilon):
			continue
		var elbow_circle_center: Vector3 = (
			shoulder_skeleton + arm_axis * elbow_axis_distance
		)
		var elbow_circle_radius: float = sqrt(maxf(
			elbow_radial_squared,
			0.0
		))
		if elbow_circle_radius <= solve_epsilon:
			continue
		var elbow_reference_radial: Vector3 = (
			baseline_elbow_skeleton - elbow_circle_center
		)
		elbow_reference_radial -= (
			arm_axis * elbow_reference_radial.dot(arm_axis)
		)
		if elbow_reference_radial.length_squared() <= solve_epsilon * solve_epsilon:
			elbow_reference_radial = (
				fallback_pole_skeleton
				- arm_axis * fallback_pole_skeleton.dot(arm_axis)
			)
		if elbow_reference_radial.length_squared() <= solve_epsilon * solve_epsilon:
			continue
		elbow_reference_radial = elbow_reference_radial.normalized()
		var elbow_reference_tangent: Vector3 = arm_axis.cross(
			elbow_reference_radial
		).normalized()
		if elbow_reference_tangent.length_squared() <= solve_epsilon * solve_epsilon:
			continue
		var hinge_context := {
			"valid": true,
			"point_origin_id": &"RL_BoneRoot",
			"root_skeleton": root_skeleton,
			"shoulder_skeleton": shoulder_skeleton,
			"hand_skeleton": hand_skeleton,
			"elbow_circle_center": elbow_circle_center,
			"elbow_circle_radius": elbow_circle_radius,
			"elbow_reference_radial": elbow_reference_radial,
			"elbow_reference_tangent": elbow_reference_tangent,
			"candidate_clavicle_local_basis": candidate_clavicle_basis,
			"candidate_clavicle_global_basis": (
				candidate_clavicle_global.basis.orthonormalized()
			),
			"upperarm_rest_basis": upperarm_rest.basis.orthonormalized(),
			"forearm_rest_basis": forearm_rest.basis.orthonormalized(),
			"upperarm_child_offset": upperarm_child_offset,
			"forearm_child_offset": forearm_child_offset,
			"clavicle_angle_degrees": clavicle_angle_degrees,
			"shoulder_min_degrees": shoulder_min_degrees,
			"shoulder_max_degrees": shoulder_max_degrees,
			"elbow_min_degrees": elbow_min_degrees,
			"elbow_max_degrees": elbow_max_degrees,
		}
		var hinge_candidates: Array[Dictionary] = (
			_find_test_anatomical_elbow_hinge_roots(hinge_context)
		)
		result["hinge_root_count"] = (
			int(result["hinge_root_count"]) + hinge_candidates.size()
		)
		for candidate: Dictionary in hinge_candidates:
			if not bool(candidate.get("rom_legal", false)):
				continue
			result["rom_legal_count"] = int(result["rom_legal_count"]) + 1
			if not bool(actor.call(
				"restore_authoring_active_grip_transaction_state",
				support_slot_id,
				seated_snapshot
			)):
				result["status"] = &"test_anatomical_joint_scan_restore_failed"
				scan_failed = true
				break
			var applied: Dictionary = _apply_test_anatomical_arm_candidate(
				actor,
				support_slot_id,
				clavicle_bone,
				upperarm_bone,
				forearm_bone,
				hand_bone,
				clavicle_index,
				upperarm_index,
				forearm_index,
				hand_index,
				clavicle_rest,
				upperarm_rest,
				forearm_rest,
				hand_world_before,
				candidate
			)
			var compact: Dictionary = _build_test_anatomical_candidate_summary(
				candidate,
				applied
			)
			if bool(applied.get("exact", false)):
				result["applied_exact_count"] = (
					int(result["applied_exact_count"]) + 1
				)
			var primary_weapon_unchanged: bool = bool(presenter.call(
				"_preview_support_primary_weapon_unit_matches_snapshot",
				held,
				transaction_snapshot,
				actor,
				primary_slot_id
			))
			compact["primary_weapon_unit_unchanged"] = primary_weapon_unchanged
			if primary_weapon_unchanged:
				result["primary_weapon_legal_count"] = (
					int(result["primary_weapon_legal_count"]) + 1
				)
			var body_gate: Dictionary = presenter.call(
				"_evaluate_preview_support_body_self_collision_delta",
				actor,
				transaction_snapshot,
				support_slot_id
			) as Dictionary
			var body_legal: bool = (
				bool(body_gate.get("valid", false))
				and bool(body_gate.get("legal", false))
			)
			compact["body_status"] = body_gate.get("status", StringName())
			compact["body_legal"] = body_legal
			compact["rejected_pair_signature"] = body_gate.get(
				"rejected_pair_signature",
				""
			)
			if body_legal:
				result["body_legal_count"] = int(result["body_legal_count"]) + 1
			actor.call(
				"invalidate_authoring_active_weapon_surface_seat",
				support_slot_id
			)
			var seat_attempt: Dictionary = actor.call(
				"resolve_exact_surface_weapon_seat",
				support_slot_id,
				true,
				true
			) as Dictionary
			var correction_state: Dictionary = presenter.call(
				"_resolve_preview_support_transaction_correction",
				seat_attempt,
				secondary_guide
			) as Dictionary
			var correction_local: Transform3D = correction_state.get(
				"correction_local",
				Transform3D.IDENTITY
			) as Transform3D
			var surface_identity: bool = (
				bool(seat_attempt.get("valid", false))
				and int(seat_attempt.get("candidate_sample_index", -1)) == 0
				and bool(correction_state.get("valid", false))
				and bool(presenter.call(
					"_preview_support_correction_is_identity",
					correction_local
				))
			)
			compact["surface_status"] = seat_attempt.get(
				"status",
				StringName()
			)
			compact["surface_candidate_sample_index"] = int(seat_attempt.get(
				"candidate_sample_index",
				-1
			))
			compact["surface_identity"] = surface_identity
			if surface_identity:
				result["surface_identity_count"] = (
					int(result["surface_identity_count"]) + 1
				)
			var full_legal: bool = (
				bool(applied.get("exact", false))
				and primary_weapon_unchanged
				and body_legal
				and surface_identity
			)
			compact["full_legal"] = full_legal
			if candidate_summaries.size() < 64:
				candidate_summaries.append(compact)
			var passed_gate_count: int = (
				int(bool(applied.get("exact", false)))
				+ int(primary_weapon_unchanged)
				+ int(body_legal)
				+ int(surface_identity)
			)
			if not full_legal and passed_gate_count > best_rejected_gate_count:
				best_rejected_gate_count = passed_gate_count
				best_rejected = compact.duplicate(true)
			if full_legal:
				result["full_legal_count"] = int(result["full_legal_count"]) + 1
				result["full_legal_candidate"] = compact.duplicate(true)
				break
		if scan_failed or int(result["full_legal_count"]) > 0:
			break
	actor.call(
		"restore_authoring_active_grip_transaction_state",
		support_slot_id,
		seated_snapshot
	)
	result["best_rejected"] = best_rejected
	result["candidate_summaries"] = candidate_summaries
	result["valid"] = not scan_failed
	result["status"] = (
		&"test_anatomical_joint_scan_full_legal_candidate_found"
		if int(result["full_legal_count"]) > 0
		else (
			&"test_anatomical_joint_scan_no_full_legal_candidate"
			if not scan_failed
			else result["status"]
		)
	)
	return result


func _build_test_nearest_first_clavicle_angles(
	baseline_angle_degrees: float,
	minimum_angle_degrees: int,
	maximum_angle_degrees: int
) -> Array[float]:
	var remaining: Array[float] = []
	var baseline_clamped: float = clampf(
		baseline_angle_degrees,
		float(minimum_angle_degrees),
		float(maximum_angle_degrees)
	)
	remaining.append(baseline_clamped)
	for integer_angle: int in range(
		minimum_angle_degrees,
		maximum_angle_degrees + 1
	):
		var angle_degrees: float = float(integer_angle)
		if absf(angle_degrees - baseline_clamped) > 0.000001:
			remaining.append(angle_degrees)
	var ordered: Array[float] = []
	while not remaining.is_empty():
		var best_index: int = 0
		var best_distance: float = INF
		var best_value: float = INF
		for candidate_index: int in range(remaining.size()):
			var candidate_value: float = remaining[candidate_index]
			var candidate_distance: float = absf(
				candidate_value - baseline_clamped
			)
			if (
				candidate_distance < best_distance - 0.000001
				or (
					absf(candidate_distance - best_distance) <= 0.000001
					and candidate_value < best_value
				)
			):
				best_index = candidate_index
				best_distance = candidate_distance
				best_value = candidate_value
		ordered.append(remaining[best_index])
		remaining.remove_at(best_index)
	return ordered


func _find_test_anatomical_elbow_hinge_roots(
	context: Dictionary
) -> Array[Dictionary]:
	var roots: Array[float] = []
	var sample_count: int = 360
	var residual_epsilon: float = 0.00000001
	var previous_angle: float = -PI
	var previous_state: Dictionary = (
		_evaluate_test_anatomical_elbow_circle_state(
			context,
			previous_angle
		)
	)
	for sample_index: int in range(1, sample_count + 1):
		var current_angle: float = lerpf(
			-PI,
			PI,
			float(sample_index) / float(sample_count)
		)
		var current_state: Dictionary = (
			_evaluate_test_anatomical_elbow_circle_state(
				context,
				current_angle
			)
		)
		if bool(previous_state.get("valid", false)):
			var previous_residual: float = float(previous_state.get(
				"hinge_plane_residual",
				INF
			))
			if absf(previous_residual) <= residual_epsilon:
				_append_test_unique_wrapped_angle(roots, previous_angle)
			if bool(current_state.get("valid", false)):
				var current_residual: float = float(current_state.get(
					"hinge_plane_residual",
					INF
				))
				if previous_residual * current_residual < 0.0:
					var root_angle: float = _refine_test_anatomical_hinge_root(
						context,
						previous_angle,
						current_angle,
						previous_residual,
						current_residual
					)
					_append_test_unique_wrapped_angle(roots, root_angle)
				elif absf(current_residual) <= residual_epsilon:
					_append_test_unique_wrapped_angle(roots, current_angle)
		previous_angle = current_angle
		previous_state = current_state
	var ordered_roots: Array[float] = _order_test_angles_nearest_zero(roots)
	var candidates: Array[Dictionary] = []
	for root_angle: float in ordered_roots:
		var candidate: Dictionary = _evaluate_test_anatomical_elbow_circle_state(
			context,
			root_angle,
			true
		)
		if bool(candidate.get("valid", false)):
			candidates.append(candidate)
	return candidates


func _evaluate_test_anatomical_elbow_circle_state(
	context: Dictionary,
	elbow_circle_angle_radians: float,
	resolve_candidate: bool = false
) -> Dictionary:
	var invalid := {
		"valid": false,
		"status": &"test_anatomical_hinge_state_invalid",
	}
	var circle_center: Vector3 = context.get(
		"elbow_circle_center",
		Vector3.ZERO
	) as Vector3
	var reference_radial: Vector3 = context.get(
		"elbow_reference_radial",
		Vector3.ZERO
	) as Vector3
	var reference_tangent: Vector3 = context.get(
		"elbow_reference_tangent",
		Vector3.ZERO
	) as Vector3
	var circle_radius: float = float(context.get("elbow_circle_radius", 0.0))
	var shoulder_skeleton: Vector3 = context.get(
		"shoulder_skeleton",
		Vector3.ZERO
	) as Vector3
	var hand_skeleton: Vector3 = context.get(
		"hand_skeleton",
		Vector3.ZERO
	) as Vector3
	var upperarm_child_offset: Vector3 = context.get(
		"upperarm_child_offset",
		Vector3.ZERO
	) as Vector3
	var forearm_child_offset: Vector3 = context.get(
		"forearm_child_offset",
		Vector3.ZERO
	) as Vector3
	if (
		circle_radius <= 0.0
		or reference_radial.length_squared() <= 0.000000000001
		or reference_tangent.length_squared() <= 0.000000000001
		or upperarm_child_offset.length_squared() <= 0.000000000001
		or forearm_child_offset.length_squared() <= 0.000000000001
	):
		return invalid
	var elbow_skeleton: Vector3 = (
		circle_center
		+ reference_radial * cos(elbow_circle_angle_radians) * circle_radius
		+ reference_tangent * sin(elbow_circle_angle_radians) * circle_radius
	)
	var shoulder_to_elbow: Vector3 = elbow_skeleton - shoulder_skeleton
	var elbow_to_hand: Vector3 = hand_skeleton - elbow_skeleton
	if (
		shoulder_to_elbow.length_squared() <= 0.000000000001
		or elbow_to_hand.length_squared() <= 0.000000000001
	):
		return invalid
	var clavicle_global_basis: Basis = context.get(
		"candidate_clavicle_global_basis",
		Basis.IDENTITY
	) as Basis
	var upperarm_rest_basis: Basis = context.get(
		"upperarm_rest_basis",
		Basis.IDENTITY
	) as Basis
	var upperarm_target_parent: Vector3 = (
		clavicle_global_basis.inverse() * shoulder_to_elbow.normalized()
	).normalized()
	var upperarm_target_neutral: Vector3 = (
		upperarm_rest_basis.inverse() * upperarm_target_parent
	).normalized()
	var upperarm_source_neutral: Vector3 = upperarm_child_offset.normalized()
	var swing_state: Dictionary = _build_test_pure_swing_rotation(
		upperarm_source_neutral,
		upperarm_target_neutral,
		Vector3.RIGHT
	)
	if not bool(swing_state.get("valid", false)):
		return invalid
	var upperarm_swing_basis: Basis = swing_state.get(
		"basis",
		Basis.IDENTITY
	) as Basis
	var upperarm_local_basis: Basis = (
		upperarm_rest_basis * upperarm_swing_basis
	).orthonormalized()
	var upperarm_global_basis: Basis = (
		clavicle_global_basis * upperarm_local_basis
	).orthonormalized()
	var actual_elbow_skeleton: Vector3 = (
		shoulder_skeleton
		+ upperarm_global_basis * upperarm_child_offset
	)
	var upperarm_endpoint_error: float = actual_elbow_skeleton.distance_to(
		elbow_skeleton
	)
	if upperarm_endpoint_error > 0.00001:
		return invalid
	var forearm_rest_basis: Basis = context.get(
		"forearm_rest_basis",
		Basis.IDENTITY
	) as Basis
	var target_forearm_parent: Vector3 = (
		upperarm_global_basis.inverse() * elbow_to_hand.normalized()
	).normalized()
	var target_forearm_neutral: Vector3 = (
		forearm_rest_basis.inverse() * target_forearm_parent
	).normalized()
	var source_forearm_neutral: Vector3 = forearm_child_offset.normalized()
	var hinge_plane_residual: float = (
		target_forearm_neutral.x - source_forearm_neutral.x
	)
	var state := {
		"valid": true,
		"status": &"test_anatomical_hinge_state_ready",
		"point_origin_id": &"RL_BoneRoot",
		"elbow_circle_angle_degrees": rad_to_deg(
			_wrap_test_angle_radians(elbow_circle_angle_radians)
		),
		"hinge_plane_residual": hinge_plane_residual,
		"upperarm_endpoint_error_meters_skeleton": upperarm_endpoint_error,
	}
	if not resolve_candidate:
		return state
	var source_projected := Vector3(
		0.0,
		source_forearm_neutral.y,
		source_forearm_neutral.z
	)
	var target_projected := Vector3(
		0.0,
		target_forearm_neutral.y,
		target_forearm_neutral.z
	)
	if (
		source_projected.length_squared() <= 0.000000000001
		or target_projected.length_squared() <= 0.000000000001
	):
		return invalid
	source_projected = source_projected.normalized()
	target_projected = target_projected.normalized()
	var hinge_angle_radians: float = atan2(
		Vector3.RIGHT.dot(source_projected.cross(target_projected)),
		clampf(source_projected.dot(target_projected), -1.0, 1.0)
	)
	var forearm_hinge_basis := Basis(Vector3.RIGHT, hinge_angle_radians)
	var forearm_local_basis: Basis = (
		forearm_rest_basis * forearm_hinge_basis
	).orthonormalized()
	var forearm_global_basis: Basis = (
		upperarm_global_basis * forearm_local_basis
	).orthonormalized()
	var predicted_hand_skeleton: Vector3 = (
		actual_elbow_skeleton
		+ forearm_global_basis * forearm_child_offset
	)
	var predicted_hand_error: float = predicted_hand_skeleton.distance_to(
		hand_skeleton
	)
	var root_skeleton: Vector3 = context.get(
		"root_skeleton",
		Vector3.ZERO
	) as Vector3
	var shoulder_to_root: Vector3 = root_skeleton - shoulder_skeleton
	var elbow_to_shoulder: Vector3 = shoulder_skeleton - actual_elbow_skeleton
	var actual_elbow_to_hand: Vector3 = hand_skeleton - actual_elbow_skeleton
	var shoulder_angle_degrees: float = rad_to_deg(acos(clampf(
		shoulder_to_root.normalized().dot(
			(actual_elbow_skeleton - shoulder_skeleton).normalized()
		),
		-1.0,
		1.0
	)))
	var elbow_angle_degrees: float = rad_to_deg(acos(clampf(
		elbow_to_shoulder.normalized().dot(
			actual_elbow_to_hand.normalized()
		),
		-1.0,
		1.0
	)))
	var hinge_angle_degrees: float = rad_to_deg(hinge_angle_radians)
	var hinge_sign_legal: bool = (
		hinge_angle_degrees >= -0.05
		and hinge_angle_degrees <= 180.0 + 0.05
	)
	var rom_legal: bool = (
		predicted_hand_error <= 0.00001
		and absf(hinge_plane_residual) <= 0.000001
		and shoulder_angle_degrees
			>= float(context.get("shoulder_min_degrees", 0.0))
		and shoulder_angle_degrees
			<= float(context.get("shoulder_max_degrees", 180.0))
		and elbow_angle_degrees
			>= float(context.get("elbow_min_degrees", 0.0))
		and elbow_angle_degrees
			<= float(context.get("elbow_max_degrees", 180.0))
		and hinge_sign_legal
	)
	state.merge({
		"status": (
			&"test_anatomical_hinge_candidate_ready"
			if rom_legal
			else &"test_anatomical_hinge_candidate_rom_rejected"
		),
		"root_skeleton": root_skeleton,
		"shoulder_skeleton": shoulder_skeleton,
		"elbow_skeleton": actual_elbow_skeleton,
		"hand_skeleton": hand_skeleton,
		"candidate_clavicle_local_basis": context.get(
			"candidate_clavicle_local_basis",
			Basis.IDENTITY
		),
		"candidate_upperarm_local_basis": upperarm_local_basis,
		"candidate_forearm_local_basis": forearm_local_basis,
		"upperarm_swing_basis": upperarm_swing_basis,
		"forearm_hinge_basis": forearm_hinge_basis,
		"clavicle_angle_degrees": float(context.get(
			"clavicle_angle_degrees",
			0.0
		)),
		"hinge_angle_degrees": hinge_angle_degrees,
		"hinge_sign_legal": hinge_sign_legal,
		"shoulder_angle_degrees": shoulder_angle_degrees,
		"elbow_angle_degrees": elbow_angle_degrees,
		"predicted_hand_error_meters_skeleton": predicted_hand_error,
		"rom_legal": rom_legal,
	}, true)
	return state


func _refine_test_anatomical_hinge_root(
	context: Dictionary,
	lower_angle: float,
	upper_angle: float,
	lower_residual: float,
	upper_residual: float
) -> float:
	var resolved_lower: float = lower_angle
	var resolved_upper: float = upper_angle
	var resolved_lower_residual: float = lower_residual
	var resolved_upper_residual: float = upper_residual
	for _iteration: int in range(40):
		var middle_angle: float = 0.5 * (resolved_lower + resolved_upper)
		var middle_state: Dictionary = (
			_evaluate_test_anatomical_elbow_circle_state(
				context,
				middle_angle
			)
		)
		if not bool(middle_state.get("valid", false)):
			break
		var middle_residual: float = float(middle_state.get(
			"hinge_plane_residual",
			0.0
		))
		if absf(middle_residual) <= 0.0000000001:
			return middle_angle
		if resolved_lower_residual * middle_residual <= 0.0:
			resolved_upper = middle_angle
			resolved_upper_residual = middle_residual
		else:
			resolved_lower = middle_angle
			resolved_lower_residual = middle_residual
	return (
		resolved_lower
		if absf(resolved_lower_residual) <= absf(resolved_upper_residual)
		else resolved_upper
	)


func _build_test_pure_swing_rotation(
	source_axis: Vector3,
	target_axis: Vector3,
	fallback_axis: Vector3
) -> Dictionary:
	if (
		source_axis.length_squared() <= 0.000000000001
		or target_axis.length_squared() <= 0.000000000001
	):
		return {"valid": false}
	var source: Vector3 = source_axis.normalized()
	var target: Vector3 = target_axis.normalized()
	var direction_dot: float = clampf(source.dot(target), -1.0, 1.0)
	if direction_dot >= 1.0 - 0.000000001:
		return {"valid": true, "basis": Basis.IDENTITY}
	var rotation_axis: Vector3 = source.cross(target)
	if rotation_axis.length_squared() <= 0.000000000001:
		rotation_axis = fallback_axis - source * fallback_axis.dot(source)
		if rotation_axis.length_squared() <= 0.000000000001:
			rotation_axis = Vector3.UP - source * Vector3.UP.dot(source)
		if rotation_axis.length_squared() <= 0.000000000001:
			return {"valid": false}
	rotation_axis = rotation_axis.normalized()
	return {
		"valid": true,
		"basis": Basis(rotation_axis, acos(direction_dot)).orthonormalized(),
	}


func _scan_test_support_three_link_arm_candidates(
	presenter: Object,
	actor: Node3D,
	held: Node3D,
	transaction_snapshot: Dictionary,
	support_slot_id: StringName,
	primary_slot_id: StringName,
	scan_steps: int,
	swivel_step_degrees: float = 0.0,
	shoulder_azimuth_step_degrees: float = 0.0,
	target_arm_ratio: float = NAN,
	target_elbow_swivel_degrees: float = NAN,
	target_shoulder_azimuth_degrees: float = NAN
) -> Dictionary:
	var result := {
		"valid": false,
		"status": &"test_three_link_scan_unavailable",
		"sample_count": 0,
		"rom_legal_count": 0,
		"body_legal_count": 0,
		"full_legal_count": 0,
		"best_rejected": {},
		"full_legal_candidates": [],
		"swivel_step_degrees": swivel_step_degrees,
		"shoulder_azimuth_step_degrees": shoulder_azimuth_step_degrees,
		"target_arm_ratio": target_arm_ratio,
		"target_elbow_swivel_degrees": target_elbow_swivel_degrees,
		"target_shoulder_azimuth_degrees": target_shoulder_azimuth_degrees,
	}
	var skeleton: Skeleton3D = actor.get("skeleton") as Skeleton3D
	if skeleton == null or support_slot_id not in [&"hand_right", &"hand_left"]:
		return result
	var seated_snapshot: Dictionary = actor.call(
		"capture_authoring_active_grip_transaction_state",
		support_slot_id
	) as Dictionary
	if not bool(seated_snapshot.get("valid", false)):
		result["status"] = &"test_three_link_scan_snapshot_failed"
		return result
	var left_side: bool = support_slot_id == &"hand_left"
	var clavicle_bone: StringName = (
		&"CC_Base_L_Clavicle" if left_side else &"CC_Base_R_Clavicle"
	)
	var upperarm_bone: StringName = (
		&"CC_Base_L_Upperarm" if left_side else &"CC_Base_R_Upperarm"
	)
	var forearm_bone: StringName = (
		&"CC_Base_L_Forearm" if left_side else &"CC_Base_R_Forearm"
	)
	var hand_bone: StringName = (
		&"CC_Base_L_Hand" if left_side else &"CC_Base_R_Hand"
	)
	var clavicle_index: int = skeleton.find_bone(String(clavicle_bone))
	var upperarm_index: int = skeleton.find_bone(String(upperarm_bone))
	var forearm_index: int = skeleton.find_bone(String(forearm_bone))
	var hand_index: int = skeleton.find_bone(String(hand_bone))
	if (
		clavicle_index < 0
		or upperarm_index < 0
		or forearm_index < 0
		or hand_index < 0
	):
		result["status"] = &"test_three_link_scan_bones_unavailable"
		return result
	var root_skeleton: Vector3 = skeleton.get_bone_global_pose(
		clavicle_index
	).origin
	var baseline_shoulder_skeleton: Vector3 = skeleton.get_bone_global_pose(
		upperarm_index
	).origin
	var baseline_elbow_skeleton: Vector3 = skeleton.get_bone_global_pose(
		forearm_index
	).origin
	var hand_pose_world: Transform3D = (
		skeleton.global_transform * skeleton.get_bone_global_pose(hand_index)
	)
	var hand_skeleton: Vector3 = skeleton.get_bone_global_pose(hand_index).origin
	var clavicle_length: float = root_skeleton.distance_to(
		baseline_shoulder_skeleton
	)
	var upperarm_length: float = baseline_shoulder_skeleton.distance_to(
		baseline_elbow_skeleton
	)
	var forearm_length: float = baseline_elbow_skeleton.distance_to(hand_skeleton)
	var root_to_hand: Vector3 = hand_skeleton - root_skeleton
	var root_to_hand_distance: float = root_to_hand.length()
	var solve_epsilon: float = 0.000001
	if (
		clavicle_length <= solve_epsilon
		or upperarm_length <= solve_epsilon
		or forearm_length <= solve_epsilon
		or root_to_hand_distance <= solve_epsilon
	):
		result["status"] = &"test_three_link_scan_geometry_invalid"
		return result
	var target_axis_skeleton: Vector3 = root_to_hand / root_to_hand_distance
	var actor_basis_world: Basis = actor.global_basis.orthonormalized()
	var side_sign: float = -1.0 if left_side else 1.0
	var pole_hint_world: Vector3 = (
		actor_basis_world.x
			* float(actor.get("support_arm_ik_pole_side_offset_meters"))
			* side_sign
		- actor_basis_world.y
			* float(actor.get("support_arm_ik_pole_down_offset_meters"))
	)
	var skeleton_basis_world: Basis = skeleton.global_basis
	if absf(skeleton_basis_world.determinant()) <= solve_epsilon:
		result["status"] = &"test_three_link_scan_basis_invalid"
		return result
	var pole_hint_skeleton: Vector3 = skeleton_basis_world.inverse() * pole_hint_world
	var target_plane_radial: Vector3 = (
		pole_hint_skeleton
		- target_axis_skeleton * pole_hint_skeleton.dot(target_axis_skeleton)
	)
	if target_plane_radial.length_squared() <= solve_epsilon * solve_epsilon:
		result["status"] = &"test_three_link_scan_pole_invalid"
		return result
	target_plane_radial = target_plane_radial.normalized()
	var baseline_shoulder_radial: Vector3 = (
		baseline_shoulder_skeleton - root_skeleton
	)
	baseline_shoulder_radial -= (
		target_axis_skeleton
		* baseline_shoulder_radial.dot(target_axis_skeleton)
	)
	var shoulder_half_plane_sign: float = 1.0
	if (
		baseline_shoulder_radial.length_squared() > solve_epsilon * solve_epsilon
		and baseline_shoulder_radial.dot(target_plane_radial) < 0.0
	):
		shoulder_half_plane_sign = -1.0
	var shoulder_min_degrees: float = float(actor.get(
		"authoring_shoulder_min_plane_angle_degrees"
	))
	var shoulder_max_degrees: float = float(actor.get(
		"authoring_shoulder_max_plane_angle_degrees"
	))
	var elbow_min_degrees: float = float(actor.get(
		"authoring_elbow_min_plane_angle_degrees"
	))
	var elbow_max_degrees: float = float(actor.get(
		"authoring_elbow_max_plane_angle_degrees"
	))
	var elbow_min_reach: float = sqrt(maxf(
		upperarm_length * upperarm_length
		+ forearm_length * forearm_length
		- 2.0 * upperarm_length * forearm_length
			* cos(deg_to_rad(elbow_min_degrees)),
		0.0
	))
	var elbow_max_reach: float = sqrt(maxf(
		upperarm_length * upperarm_length
		+ forearm_length * forearm_length
		- 2.0 * upperarm_length * forearm_length
			* cos(deg_to_rad(elbow_max_degrees)),
		0.0
	))
	var arm_distance_min: float = maxf(
		absf(root_to_hand_distance - clavicle_length),
		elbow_min_reach
	)
	var arm_distance_max: float = minf(
		root_to_hand_distance + clavicle_length,
		elbow_max_reach
	)
	result["arm_distance_min_meters"] = arm_distance_min
	result["arm_distance_max_meters"] = arm_distance_max
	if arm_distance_min > arm_distance_max + solve_epsilon:
		result["status"] = &"test_three_link_scan_reach_unavailable"
		return result
	var best_rejected: Dictionary = {}
	var best_rejected_clearance_delta: float = -INF
	var full_legal_candidates: Array[Dictionary] = []
	var swivel_degrees_samples: Array[float] = [0.0]
	if is_finite(target_elbow_swivel_degrees):
		swivel_degrees_samples.clear()
		if swivel_step_degrees > 0.0:
			for swivel_offset_index: int in range(-2, 3):
				swivel_degrees_samples.append(
					target_elbow_swivel_degrees
					+ float(swivel_offset_index) * swivel_step_degrees
				)
		else:
			swivel_degrees_samples.append(target_elbow_swivel_degrees)
	elif swivel_step_degrees > 0.0:
		swivel_degrees_samples.clear()
		var swivel_degrees: float = -180.0
		while swivel_degrees <= 180.0 + 0.0001:
			swivel_degrees_samples.append(swivel_degrees)
			swivel_degrees += swivel_step_degrees
	var shoulder_azimuth_samples: Array[float] = [0.0]
	if is_finite(target_shoulder_azimuth_degrees):
		shoulder_azimuth_samples.clear()
		if shoulder_azimuth_step_degrees > 0.0:
			for azimuth_offset_index: int in range(-2, 3):
				shoulder_azimuth_samples.append(
					target_shoulder_azimuth_degrees
					+ float(azimuth_offset_index)
						* shoulder_azimuth_step_degrees
				)
		else:
			shoulder_azimuth_samples.append(target_shoulder_azimuth_degrees)
	elif shoulder_azimuth_step_degrees > 0.0:
		shoulder_azimuth_samples.clear()
		var shoulder_azimuth_degrees: float = -180.0
		while shoulder_azimuth_degrees <= 180.0 + 0.0001:
			shoulder_azimuth_samples.append(shoulder_azimuth_degrees)
			shoulder_azimuth_degrees += shoulder_azimuth_step_degrees
	var arm_ratio_samples: Array[float] = []
	if is_finite(target_arm_ratio):
		if scan_steps > 1:
			for target_sample_index: int in range(scan_steps):
				arm_ratio_samples.append(clampf(
					target_arm_ratio + lerpf(
						-0.125,
						0.125,
						float(target_sample_index) / float(scan_steps - 1)
					),
					0.0,
					1.0
				))
		else:
			arm_ratio_samples.append(target_arm_ratio)
	else:
		for sample_index: int in range(maxi(scan_steps, 1) + 1):
			arm_ratio_samples.append(
				float(sample_index) / float(maxi(scan_steps, 1))
			)
	var orientation_samples: Array[Vector2] = []
	for shoulder_azimuth_degrees: float in shoulder_azimuth_samples:
		for elbow_swivel_degrees: float in swivel_degrees_samples:
			orientation_samples.append(Vector2(
				shoulder_azimuth_degrees,
				elbow_swivel_degrees
			))
	var scan_failed: bool = false
	var full_candidate_found: bool = false
	for sample_index: int in range(arm_ratio_samples.size()):
		var sample_ratio: float = arm_ratio_samples[sample_index]
		var arm_distance: float = lerpf(
			arm_distance_min,
			arm_distance_max,
			sample_ratio
		)
		for orientation_sample: Vector2 in orientation_samples:
			var shoulder_azimuth_degrees: float = orientation_sample.x
			var elbow_swivel_degrees: float = orientation_sample.y
			var candidate: Dictionary = _resolve_test_support_three_link_candidate(
				root_skeleton,
				hand_skeleton,
				clavicle_length,
				upperarm_length,
				forearm_length,
				target_axis_skeleton,
				target_plane_radial,
				pole_hint_skeleton,
				shoulder_half_plane_sign,
				arm_distance,
				shoulder_min_degrees,
				shoulder_max_degrees,
				elbow_min_degrees,
				elbow_max_degrees,
				elbow_swivel_degrees,
				shoulder_azimuth_degrees
			)
			result["sample_count"] = int(result["sample_count"]) + 1
			if not bool(candidate.get("valid", false)):
				continue
			result["rom_legal_count"] = int(result["rom_legal_count"]) + 1
			if not bool(actor.call(
				"restore_authoring_active_grip_transaction_state",
				support_slot_id,
				seated_snapshot
			)):
				result["status"] = &"test_three_link_scan_restore_failed"
				scan_failed = true
				break
			actor.call(
				"_rotate_bone_toward_end_target",
				clavicle_bone,
				upperarm_bone,
				candidate.get("shoulder_skeleton", Vector3.ZERO),
				1.0
			)
			actor.call(
				"_rotate_bone_toward_end_target",
				upperarm_bone,
				forearm_bone,
				candidate.get("elbow_skeleton", Vector3.ZERO),
				1.0
			)
			actor.call(
				"_rotate_bone_toward_end_target",
				forearm_bone,
				hand_bone,
				hand_skeleton,
				1.0
			)
			actor.call(
				"_apply_bone_world_basis",
				hand_bone,
				hand_pose_world.basis.orthonormalized(),
				1.0
			)
			skeleton.force_update_all_bone_transforms()
			var range_state: Dictionary = actor.call(
				"get_authoring_arm_joint_range_state",
				support_slot_id
			) as Dictionary
			var hand_world_after: Transform3D = (
				skeleton.global_transform * skeleton.get_bone_global_pose(hand_index)
			)
			var hand_position_error: float = hand_world_after.origin.distance_to(
				hand_pose_world.origin
			)
			var hand_basis_error: float = rad_to_deg(
				hand_world_after.basis.orthonormalized()
					.get_rotation_quaternion().normalized().angle_to(
						hand_pose_world.basis.orthonormalized()
							.get_rotation_quaternion().normalized()
					)
			)
			if (
				hand_position_error > 0.00005
				or hand_basis_error > 0.05
				or not bool(range_state.get("valid", false))
				or not bool(range_state.get("legal", false))
			):
				continue
			var body_gate: Dictionary = presenter.call(
				"_evaluate_preview_support_body_self_collision_delta",
				actor,
				transaction_snapshot,
				support_slot_id
			) as Dictionary
			var compact := {
				"sample_index": sample_index,
				"sample_ratio": sample_ratio,
				"elbow_swivel_degrees": elbow_swivel_degrees,
				"shoulder_azimuth_degrees": shoulder_azimuth_degrees,
				"arm_distance_meters": arm_distance,
				"shoulder_angle_degrees": float((range_state.get(
					"shoulder",
					{}
				) as Dictionary).get("angle_degrees", INF)),
				"elbow_angle_degrees": float((range_state.get(
					"elbow",
					{}
				) as Dictionary).get("angle_degrees", INF)),
				"hand_position_error_meters": hand_position_error,
				"hand_basis_error_degrees": hand_basis_error,
				"body_status": body_gate.get("status", StringName()),
				"body_legal": bool(body_gate.get("valid", false))
					and bool(body_gate.get("legal", false)),
				"rejected_pair_signature": body_gate.get(
					"rejected_pair_signature",
					""
				),
			}
			if bool(compact["body_legal"]):
				result["body_legal_count"] = int(result["body_legal_count"]) + 1
				compact["primary_weapon_unit_unchanged"] = bool(presenter.call(
					"_preview_support_primary_weapon_unit_matches_snapshot",
					held,
					transaction_snapshot,
					actor,
					primary_slot_id
				))
				actor.call(
					"invalidate_authoring_active_weapon_surface_seat",
					support_slot_id
				)
				var seat_attempt: Dictionary = actor.call(
					"resolve_exact_surface_weapon_seat",
					support_slot_id,
					true,
					true
				) as Dictionary
				var secondary_guide := held.get_node_or_null(
					"SecondaryGripGuide"
				) as Node3D
				var correction_state: Dictionary = presenter.call(
					"_resolve_preview_support_transaction_correction",
					seat_attempt,
					secondary_guide
				) as Dictionary
				var correction_local: Transform3D = correction_state.get(
					"correction_local",
					Transform3D.IDENTITY
				) as Transform3D
				compact["seat_status"] = seat_attempt.get(
					"status",
					StringName()
				)
				compact["seat_identity"] = (
					bool(seat_attempt.get("valid", false))
					and int(seat_attempt.get("candidate_sample_index", -1)) == 0
					and bool(correction_state.get("valid", false))
					and bool(presenter.call(
						"_preview_support_correction_is_identity",
						correction_local
					))
				)
				compact["full_legal"] = (
					bool(compact["primary_weapon_unit_unchanged"])
					and bool(compact["seat_identity"])
				)
				if bool(compact["full_legal"]):
					result["full_legal_count"] = int(result["full_legal_count"]) + 1
					if full_legal_candidates.size() < 16:
						full_legal_candidates.append(compact)
					full_candidate_found = true
					break
			else:
				var rejected_pair: Dictionary = body_gate.get(
					"rejected_pair",
					{}
				) as Dictionary
				var baseline_pair: Dictionary = body_gate.get(
					"baseline_pair",
					{}
				) as Dictionary
				var clearance_delta: float = float(rejected_pair.get(
					"clearance_meters",
					-INF
				)) - float(baseline_pair.get("clearance_meters", 0.0))
				compact["rejected_clearance_meters"] = rejected_pair.get(
					"clearance_meters",
					-INF
				)
				compact["baseline_clearance_meters"] = baseline_pair.get(
					"clearance_meters",
					0.0
				)
				compact["clearance_delta_meters"] = clearance_delta
				if clearance_delta > best_rejected_clearance_delta:
					best_rejected_clearance_delta = clearance_delta
					best_rejected = compact
			if scan_failed or full_candidate_found:
				break
		if scan_failed or full_candidate_found:
			break
	actor.call(
		"restore_authoring_active_grip_transaction_state",
		support_slot_id,
		seated_snapshot
	)
	result["best_rejected"] = best_rejected
	result["full_legal_candidates"] = full_legal_candidates
	result["valid"] = true
	result["status"] = (
		&"test_three_link_scan_full_legal_candidate_found"
		if not full_legal_candidates.is_empty()
		else &"test_three_link_scan_no_full_legal_candidate"
	)
	return result


func _resolve_test_support_three_link_candidate(
	root_skeleton: Vector3,
	hand_skeleton: Vector3,
	clavicle_length: float,
	upperarm_length: float,
	forearm_length: float,
	target_axis_skeleton: Vector3,
	target_plane_radial: Vector3,
	pole_hint_skeleton: Vector3,
	shoulder_half_plane_sign: float,
	arm_distance: float,
	shoulder_min_degrees: float,
	shoulder_max_degrees: float,
	elbow_min_degrees: float,
	elbow_max_degrees: float,
	elbow_swivel_degrees: float = 0.0,
	shoulder_azimuth_degrees: float = 0.0
) -> Dictionary:
	var invalid := {"valid": false}
	var solve_epsilon: float = 0.000001
	var root_to_hand_distance: float = root_skeleton.distance_to(hand_skeleton)
	if arm_distance <= solve_epsilon or root_to_hand_distance <= solve_epsilon:
		return invalid
	var shoulder_axis_distance: float = (
		root_to_hand_distance * root_to_hand_distance
		+ clavicle_length * clavicle_length
		- arm_distance * arm_distance
	) / (2.0 * root_to_hand_distance)
	var shoulder_radial_squared: float = (
		clavicle_length * clavicle_length
		- shoulder_axis_distance * shoulder_axis_distance
	)
	if shoulder_radial_squared < -(solve_epsilon * solve_epsilon):
		return invalid
	var shoulder_radial_direction: Vector3 = target_plane_radial
	if not is_zero_approx(shoulder_azimuth_degrees):
		shoulder_radial_direction = (
			Basis(target_axis_skeleton, deg_to_rad(shoulder_azimuth_degrees))
			* shoulder_radial_direction
		).normalized()
	var candidate_shoulder: Vector3 = (
		root_skeleton
		+ target_axis_skeleton * shoulder_axis_distance
		+ shoulder_radial_direction * shoulder_half_plane_sign
			* sqrt(maxf(shoulder_radial_squared, 0.0))
	)
	var shoulder_to_hand: Vector3 = hand_skeleton - candidate_shoulder
	var resolved_arm_distance: float = shoulder_to_hand.length()
	if resolved_arm_distance <= solve_epsilon:
		return invalid
	var arm_axis_skeleton: Vector3 = shoulder_to_hand / resolved_arm_distance
	var elbow_pole_radial: Vector3 = (
		pole_hint_skeleton
		- arm_axis_skeleton * pole_hint_skeleton.dot(arm_axis_skeleton)
	)
	if elbow_pole_radial.length_squared() <= solve_epsilon * solve_epsilon:
		elbow_pole_radial = target_plane_radial
		elbow_pole_radial -= (
			arm_axis_skeleton * elbow_pole_radial.dot(arm_axis_skeleton)
		)
	if elbow_pole_radial.length_squared() <= solve_epsilon * solve_epsilon:
		return invalid
	elbow_pole_radial = elbow_pole_radial.normalized()
	if not is_zero_approx(elbow_swivel_degrees):
		elbow_pole_radial = (
			Basis(arm_axis_skeleton, deg_to_rad(elbow_swivel_degrees))
			* elbow_pole_radial
		).normalized()
	var elbow_axis_distance: float = (
		upperarm_length * upperarm_length
		- forearm_length * forearm_length
		+ resolved_arm_distance * resolved_arm_distance
	) / (2.0 * resolved_arm_distance)
	var elbow_radial_squared: float = (
		upperarm_length * upperarm_length
		- elbow_axis_distance * elbow_axis_distance
	)
	if elbow_radial_squared < -(solve_epsilon * solve_epsilon):
		return invalid
	var candidate_elbow: Vector3 = (
		candidate_shoulder
		+ arm_axis_skeleton * elbow_axis_distance
		+ elbow_pole_radial * sqrt(maxf(elbow_radial_squared, 0.0))
	)
	var shoulder_to_root: Vector3 = root_skeleton - candidate_shoulder
	var shoulder_to_elbow: Vector3 = candidate_elbow - candidate_shoulder
	var elbow_to_shoulder: Vector3 = candidate_shoulder - candidate_elbow
	var elbow_to_hand: Vector3 = hand_skeleton - candidate_elbow
	if (
		shoulder_to_root.length_squared() <= solve_epsilon * solve_epsilon
		or shoulder_to_elbow.length_squared() <= solve_epsilon * solve_epsilon
		or elbow_to_shoulder.length_squared() <= solve_epsilon * solve_epsilon
		or elbow_to_hand.length_squared() <= solve_epsilon * solve_epsilon
	):
		return invalid
	var shoulder_angle_degrees: float = rad_to_deg(
		shoulder_to_root.normalized().angle_to(shoulder_to_elbow.normalized())
	)
	var elbow_angle_degrees: float = rad_to_deg(
		elbow_to_shoulder.normalized().angle_to(elbow_to_hand.normalized())
	)
	if (
		shoulder_angle_degrees < shoulder_min_degrees
		or shoulder_angle_degrees > shoulder_max_degrees
		or elbow_angle_degrees < elbow_min_degrees
		or elbow_angle_degrees > elbow_max_degrees
	):
		return invalid
	return {
		"valid": true,
		"point_origin_id": &"RL_BoneRoot",
		"shoulder_skeleton": candidate_shoulder,
		"elbow_skeleton": candidate_elbow,
		"hand_skeleton": hand_skeleton,
		"shoulder_angle_degrees": shoulder_angle_degrees,
		"elbow_angle_degrees": elbow_angle_degrees,
	}


func _scan_test_support_elbow_swivel_candidates(
	presenter: Object,
	actor: Node3D,
	held: Node3D,
	transaction_snapshot: Dictionary,
	support_slot_id: StringName,
	primary_slot_id: StringName,
	candidate_degrees: PackedFloat64Array
) -> Array[Dictionary]:
	var attempts: Array[Dictionary] = []
	var seated_snapshot: Dictionary = actor.call(
		"capture_authoring_active_grip_transaction_state",
		support_slot_id
	) as Dictionary
	if not bool(seated_snapshot.get("valid", false)):
		return attempts
	for degrees: float in candidate_degrees:
		if not bool(actor.call(
			"restore_authoring_active_grip_transaction_state",
			support_slot_id,
			seated_snapshot
		)):
			attempts.append({
				"degrees": degrees,
				"valid": false,
				"status": &"test_elbow_swivel_restore_failed",
			})
			break
		var swivel_state: Dictionary = _apply_test_support_elbow_swivel(
			actor,
			support_slot_id,
			degrees
		)
		var body_gate: Dictionary = presenter.call(
			"_evaluate_preview_support_body_self_collision_delta",
			actor,
			transaction_snapshot,
			support_slot_id
		) as Dictionary
		var primary_exact: bool = bool(presenter.call(
			"_preview_support_primary_weapon_unit_matches_snapshot",
			held,
			transaction_snapshot,
			actor,
			primary_slot_id
		))
		var attempt := {
			"degrees": degrees,
			"valid": bool(swivel_state.get("valid", false)),
			"status": swivel_state.get("status", StringName()),
			"hand_position_error_meters": float(swivel_state.get(
				"hand_position_error_meters",
				INF
			)),
			"hand_basis_error_degrees": float(swivel_state.get(
				"hand_basis_error_degrees",
				INF
			)),
			"body_gate": body_gate.duplicate(true),
			"primary_weapon_unit_unchanged": primary_exact,
			"seat_identity": false,
			"digit_packet_committed": false,
		}
		if (
			bool(swivel_state.get("valid", false))
			and primary_exact
			and bool(body_gate.get("valid", false))
			and bool(body_gate.get("legal", false))
		):
			actor.call(
				"invalidate_authoring_active_weapon_surface_seat",
				support_slot_id
			)
			var seat_attempt: Dictionary = actor.call(
				"resolve_exact_surface_weapon_seat",
				support_slot_id,
				true,
				true
			) as Dictionary
			var secondary_guide := held.get_node_or_null(
				"SecondaryGripGuide"
			) as Node3D
			var correction_state: Dictionary = presenter.call(
				"_resolve_preview_support_transaction_correction",
				seat_attempt,
				secondary_guide
			) as Dictionary
			var correction_local: Transform3D = correction_state.get(
				"correction_local",
				Transform3D.IDENTITY
			) as Transform3D
			attempt["seat_identity"] = (
				bool(seat_attempt.get("valid", false))
				and int(seat_attempt.get("candidate_sample_index", -1)) == 0
				and bool(correction_state.get("valid", false))
				and bool(presenter.call(
					"_preview_support_correction_is_identity",
					correction_local
				))
			)
			attempt["seat_status"] = seat_attempt.get("status", StringName())
			if bool(attempt["seat_identity"]):
				actor.call(
					"invalidate_authoring_active_surface_grasp",
					support_slot_id
				)
				attempt["digit_packet_committed"] = bool(actor.call(
					"apply_authoring_digit_grip_slot_now",
					support_slot_id,
					true
				))
				attempt["digit_state"] = (
					actor.call(
						"get_authoring_surface_grasp_debug_state",
						support_slot_id
					) as Dictionary
				).duplicate(true)
		attempts.append(attempt)
	actor.call(
		"restore_authoring_active_grip_transaction_state",
		support_slot_id,
		seated_snapshot
	)
	return attempts


func _apply_test_support_elbow_swivel(
	actor: Node3D,
	slot_id: StringName,
	degrees: float
) -> Dictionary:
	var result := {
		"valid": false,
		"status": &"test_elbow_swivel_unavailable",
	}
	var skeleton: Skeleton3D = actor.get("skeleton") as Skeleton3D
	if skeleton == null or slot_id not in [&"hand_right", &"hand_left"]:
		return result
	var upperarm_bone: StringName = (
		&"CC_Base_L_Upperarm" if slot_id == &"hand_left" else &"CC_Base_R_Upperarm"
	)
	var forearm_bone: StringName = (
		&"CC_Base_L_Forearm" if slot_id == &"hand_left" else &"CC_Base_R_Forearm"
	)
	var hand_bone: StringName = (
		&"CC_Base_L_Hand" if slot_id == &"hand_left" else &"CC_Base_R_Hand"
	)
	var clavicle_bone: StringName = (
		&"CC_Base_L_Clavicle" if slot_id == &"hand_left" else &"CC_Base_R_Clavicle"
	)
	var upperarm_index: int = skeleton.find_bone(String(upperarm_bone))
	var forearm_index: int = skeleton.find_bone(String(forearm_bone))
	var hand_index: int = skeleton.find_bone(String(hand_bone))
	if upperarm_index < 0 or forearm_index < 0 or hand_index < 0:
		return result
	var shoulder_pose: Transform3D = skeleton.get_bone_global_pose(upperarm_index)
	var elbow_pose: Transform3D = skeleton.get_bone_global_pose(forearm_index)
	var hand_pose_before: Transform3D = skeleton.get_bone_global_pose(hand_index)
	var axis: Vector3 = hand_pose_before.origin - shoulder_pose.origin
	if axis.length_squared() <= 0.000001:
		return result
	axis = axis.normalized()
	var shoulder_to_elbow: Vector3 = elbow_pose.origin - shoulder_pose.origin
	var parallel: Vector3 = axis * shoulder_to_elbow.dot(axis)
	var radial: Vector3 = shoulder_to_elbow - parallel
	if radial.length_squared() <= 0.000001:
		return result
	var desired_elbow: Vector3 = (
		shoulder_pose.origin
		+ parallel
		+ Basis(axis, deg_to_rad(degrees)) * radial
	)
	actor.call(
		"_rotate_bone_toward_end_target",
		upperarm_bone,
		forearm_bone,
		desired_elbow,
		1.0
	)
	actor.call(
		"_rotate_bone_toward_end_target",
		forearm_bone,
		hand_bone,
		hand_pose_before.origin,
		1.0
	)
	actor.call(
		"_enforce_authoring_upperarm_swing_authority",
		slot_id,
		clavicle_bone,
		upperarm_bone,
		forearm_bone,
		hand_bone
	)
	skeleton.force_update_all_bone_transforms()
	var hand_parent_index: int = skeleton.get_bone_parent(hand_index)
	if hand_parent_index < 0:
		return result
	var hand_parent_pose: Transform3D = skeleton.get_bone_global_pose(
		hand_parent_index
	)
	var desired_hand_local_basis: Basis = (
		hand_parent_pose.basis.inverse() * hand_pose_before.basis
	).orthonormalized()
	skeleton.set_bone_pose_rotation(
		hand_index,
		desired_hand_local_basis.get_rotation_quaternion().normalized()
	)
	skeleton.force_update_all_bone_transforms()
	var hand_pose_after: Transform3D = skeleton.get_bone_global_pose(hand_index)
	var basis_error_degrees: float = rad_to_deg(
		(hand_pose_before.basis.orthonormalized().inverse()
			* hand_pose_after.basis.orthonormalized()
		).get_rotation_quaternion().get_angle()
	)
	basis_error_degrees = minf(basis_error_degrees, 360.0 - basis_error_degrees)
	result["valid"] = true
	result["status"] = &"test_elbow_swivel_applied"
	result["hand_position_error_meters"] = hand_pose_after.origin.distance_to(
		hand_pose_before.origin
	)
	result["hand_basis_error_degrees"] = basis_error_degrees
	return result


func _attempt_extended_support_candidate_without_limb_twist(
	presenter: Object,
	equipped_presenter: Object,
	actor: Node3D,
	held: Node3D,
	secondary_guide: Node3D,
	snapshot: Dictionary,
	support_slot_id: StringName,
	primary_slot_id: StringName,
	initial_accumulator: Transform3D,
	fixed_point_passes: int
) -> Dictionary:
	var attempt := {
		"seat_verified": false,
		"digit_packet_committed": false,
		"primary_weapon_unit_unchanged": false,
		"result": {
			"valid": false,
			"status": &"test_no_twist_candidate_unavailable",
		},
		"verified_seat_result": {},
		"accumulated_correction_local": initial_accumulator,
		"transaction_passes": [],
		"applied_correction_count": 0,
	}
	var accumulated_correction_local: Transform3D = initial_accumulator
	var verified_seat_result: Dictionary = {}
	var transaction_passes: Array = []
	var applied_correction_count: int = 0
	var result: Dictionary = attempt["result"] as Dictionary
	for pass_index: int in range(fixed_point_passes):
		if pass_index > 0:
			actor.call(
				"invalidate_authoring_active_weapon_surface_seat",
				support_slot_id
			)
		var seat_attempt: Dictionary = actor.call(
			"resolve_exact_surface_weapon_seat",
			support_slot_id,
			true,
			true
		) as Dictionary
		var correction_state: Dictionary = presenter.call(
			"_resolve_preview_support_transaction_correction",
			seat_attempt,
			secondary_guide
		) as Dictionary
		var correction_local: Transform3D = correction_state.get(
			"correction_local",
			Transform3D.IDENTITY
		) as Transform3D
		transaction_passes.append({
			"pass_index": pass_index,
			"seat_status": seat_attempt.get("status", StringName()),
			"seat_valid": bool(seat_attempt.get("valid", false)),
			"candidate_sample_index": int(seat_attempt.get(
				"candidate_sample_index",
				-1
			)),
			"correction_valid": bool(correction_state.get("valid", false)),
			"correction_kind": correction_state.get(
				"correction_kind",
				StringName()
			),
			"hard_law_excess_normalized": float(correction_state.get(
				"hard_law_excess_normalized",
				INF
			)),
			"correction_local": correction_local,
		})
		var accepted_identity: bool = (
			bool(seat_attempt.get("valid", false))
			and int(seat_attempt.get("candidate_sample_index", -1)) == 0
			and bool(correction_state.get("valid", false))
			and bool(presenter.call(
				"_preview_support_correction_is_identity",
				correction_local
			))
		)
		if accepted_identity:
			verified_seat_result = seat_attempt.duplicate(true)
			break
		if (
			not bool(correction_state.get("valid", false))
			or pass_index >= fixed_point_passes - 1
		):
			result = seat_attempt.duplicate(true)
			result["valid"] = false
			result["status"] = (
				&"support_surface_grip_verification_not_identity"
				if bool(correction_state.get("valid", false))
				else correction_state.get("status", seat_attempt.get("status", &""))
			)
			break
		accumulated_correction_local = (
			correction_local.affine_inverse()
			* accumulated_correction_local
		)
		if not bool(presenter.call(
			"_compose_preview_support_grip_anchor_from_accumulator",
			held,
			accumulated_correction_local
		)):
			result = {"valid": false, "status": &"test_no_twist_compose_failed"}
			break
		applied_correction_count += 1
		if not bool(equipped_presenter.call(
			"sync_single_weapon_support_contact_guidance",
			actor,
			held,
			primary_slot_id,
			true,
			true
		)):
			result = {"valid": false, "status": &"test_no_twist_sync_failed"}
			break
		actor.call(
			"settle_authoring_support_grip_macro_pose_now",
			0.0005,
			false
		)
		if not bool(presenter.call(
			"_preview_support_primary_weapon_unit_matches_snapshot",
			held,
			snapshot,
			actor,
			primary_slot_id
		)):
			result = {
				"valid": false,
				"status": &"test_no_twist_moved_primary_weapon_unit",
			}
			break
	attempt["transaction_passes"] = transaction_passes.duplicate(true)
	attempt["applied_correction_count"] = applied_correction_count
	attempt["accumulated_correction_local"] = accumulated_correction_local
	attempt["primary_weapon_unit_unchanged"] = bool(presenter.call(
		"_preview_support_primary_weapon_unit_matches_snapshot",
		held,
		snapshot,
		actor,
		primary_slot_id
	))
	if verified_seat_result.is_empty():
		attempt["result"] = result
		return attempt
	attempt["seat_verified"] = true
	attempt["verified_seat_result"] = verified_seat_result.duplicate(true)
	var body_gate: Dictionary = presenter.call(
		"_evaluate_preview_support_body_self_collision_delta",
		actor,
		snapshot,
		support_slot_id
	) as Dictionary
	result = verified_seat_result.duplicate(true)
	result["support_body_self_collision_gate"] = body_gate.duplicate(true)
	if not bool(body_gate.get("valid", false)) or not bool(body_gate.get("legal", false)):
		result["valid"] = false
		result["status"] = body_gate.get(
			"status",
			&"support_surface_grip_body_collision_state_unavailable"
		)
		attempt["result"] = result
		return attempt
	actor.call("invalidate_authoring_active_surface_grasp", support_slot_id)
	var digit_committed: bool = bool(actor.call(
		"apply_authoring_digit_grip_slot_now",
		support_slot_id,
		true
	))
	attempt["digit_packet_committed"] = digit_committed
	result["valid"] = digit_committed
	result["status"] = (
		&"test_no_twist_candidate_ready"
		if digit_committed
		else &"support_surface_grip_digit_packet_rejected"
	)
	if not digit_committed:
		result["support_digit_grip_attempt"] = (
			actor.call(
				"get_authoring_surface_grasp_debug_state",
				support_slot_id
			) as Dictionary
		).duplicate(true)
	attempt["result"] = result
	return attempt

func _dump(
	ui: CombatAnimationStationUI,
	coord: float,
	primary_slot_id: StringName,
	capture_solver: CaptureSeatSolver,
	extended_support_candidates: Array[Dictionary] = []
) -> void:
	var preview_root := ui.preview_subviewport.get_node_or_null("CombatAnimationPreviewRoot3D") as Node3D
	var actor := preview_root.get_node_or_null("PreviewActorPivot/PreviewActor") as Node3D
	var held := preview_root.get_meta("preview_held_item", null) as Node3D
	var finger = actor.get("finger_grip_presenter")
	print("COORD=", coord)
	_dump_captured_primary_calls(capture_solver, primary_slot_id)
	var primary_transaction: Dictionary = preview_root.get_meta(
		"primary_surface_grip_transaction_result",
		{}
	) as Dictionary
	print(
		"PRIMARY_TRANSACTION status=", primary_transaction.get("status", &""),
		" valid=", primary_transaction.get("valid", false),
		" committed=", primary_transaction.get("committed", false),
		" corrections=", primary_transaction.get("applied_correction_count", -1),
		" rollback=", primary_transaction.get("rollback_succeeded", false)
	)
	var primary_diagnostics: Dictionary = primary_transaction.get(
		"diagnostics",
		{}
	) as Dictionary
	var primary_best: Dictionary = primary_diagnostics.get(
		"best_overall",
		{}
	) as Dictionary
	print(
		" PRIMARY_DIAGNOSTICS provisional=",
		primary_transaction.get("provisional_candidate_available", "absent"),
		" safety_enforced=",
		primary_diagnostics.get("ordinary_proximal_safety_enforced", "absent"),
		" sample=", primary_best.get("sample_index", -1),
		" index_radial=", primary_best.get("index_radial_error_meters", INF),
		" pinky_radial=", primary_best.get("pinky_radial_error_meters", INF),
		" ordinary_safe=", primary_best.get(
			"ordinary_proximal_capsules_safe",
			false
		),
		" ordinary_worst_pen=", primary_best.get(
			"ordinary_proximal_worst_penetration_meters",
			-1
		),
		" ordinary_worst_excess=", primary_best.get(
			"ordinary_proximal_worst_excess_penetration_meters",
			-1
		)
	)
	for primary_pass_variant: Variant in primary_transaction.get(
		"transaction_passes",
		[]
	) as Array:
		if primary_pass_variant is not Dictionary:
			continue
		var primary_pass: Dictionary = primary_pass_variant as Dictionary
		var primary_correction: Transform3D = primary_pass.get(
			"correction_local",
			Transform3D.IDENTITY
		) as Transform3D
		print(
			" PRIMARY_PASS ", primary_pass.get("pass_index", -1),
			" seat=", primary_pass.get("seat_status", &""),
			"/", primary_pass.get("seat_valid", false),
			" sample=", primary_pass.get("candidate_sample_index", -1),
			" kind=", primary_pass.get("correction_kind", &""),
			" correction_mm=", primary_correction.origin.length() * 1000.0,
			" correction_deg=", rad_to_deg(
				primary_correction.basis.orthonormalized()
					.get_rotation_quaternion().get_angle()
			),
			" hard_excess=", primary_pass.get(
				"hard_law_excess_normalized",
				-1
			)
		)
	_dump_primary_first_acquisition_attempt(
		actor,
		held,
		primary_transaction,
		primary_slot_id
	)
	print("GATE=", var_to_str(preview_root.get_meta("support_activation_gate_state", {})))
	var transaction: Dictionary = preview_root.get_meta("support_grip_transaction_result", {}) as Dictionary
	print("TRANSACTION status=", transaction.get("status", &""), " valid=", transaction.get("valid", false), " applied=", transaction.get("applied", false), " committed=", transaction.get("committed", false), " corrections=", transaction.get("applied_correction_count", -1), " rollback=", transaction.get("rollback_succeeded", false))
	print("ROLLBACK_VERIFICATION=", var_to_str(ui.preview_presenter.get_meta(
		"support_grip_last_rollback_verification",
		{}
	)))
	for extended_support_candidate: Dictionary in extended_support_candidates:
		_dump_extended_support_candidate(extended_support_candidate)
	var transaction_passes: Array = transaction.get("transaction_passes", []) as Array
	for pass_variant: Variant in transaction_passes:
		var pass_state := pass_variant as Dictionary
		var correction := pass_state.get("correction_local", Transform3D.IDENTITY) as Transform3D
		var rotation_degrees := rad_to_deg(correction.basis.orthonormalized().get_rotation_quaternion().get_angle())
		rotation_degrees = minf(rotation_degrees, 360.0 - rotation_degrees)
		print(" TXPASS ", pass_state.get("pass_index", -1), " seat=", pass_state.get("seat_status", &""), "/", pass_state.get("seat_valid", false), " sample=", pass_state.get("candidate_sample_index", -1), " kind=", pass_state.get("correction_kind", &""), " correction=", correction, " correction_mm=", correction.origin.length() * 1000.0, " correction_deg=", rotation_degrees, " hard_excess=", pass_state.get("hard_law_excess_normalized", -1))
	var candidate_attempts: Array = transaction.get(
		"support_grip_candidate_attempts",
		[]
	) as Array
	for candidate_variant: Variant in candidate_attempts:
		if candidate_variant is not Dictionary:
			continue
		var candidate: Dictionary = candidate_variant as Dictionary
		print(
			" CANDIDATE index=", candidate.get("candidate_index", -1),
			" kind=", candidate.get("candidate_kind", &""),
			" degrees=", candidate.get("candidate_degrees", 0.0),
			" status=", candidate.get("status", &""),
			" seat_verified=", candidate.get("seat_verified", false),
			" digit_committed=", candidate.get("digit_packet_committed", false),
			" primary_exact=", candidate.get("primary_weapon_unit_unchanged", false),
			" corrections=", candidate.get("applied_correction_count", -1)
		)
		var candidate_body_gate: Dictionary = candidate.get(
			"support_body_self_collision_gate",
			{}
		) as Dictionary
		if not candidate_body_gate.is_empty():
			print(
				"  CANDIDATE_BODY_GATE status=",
				candidate_body_gate.get("status", &""),
				" valid=", candidate_body_gate.get("valid", false),
				" baseline_illegal=",
				candidate_body_gate.get("baseline_illegal_pair_count", -1),
				" candidate_illegal=",
				candidate_body_gate.get("candidate_illegal_pair_count", -1),
				" rejected_signature=",
				candidate_body_gate.get("rejected_pair_signature", ""),
				" baseline_pair=",
				candidate_body_gate.get("baseline_pair", {}),
				" rejected_pair=",
				candidate_body_gate.get("rejected_pair", {})
			)
		var candidate_digit_attempt: Dictionary = candidate.get(
			"support_digit_grip_attempt",
			{}
		) as Dictionary
		if not candidate_digit_attempt.is_empty():
			var candidate_digit_diagnostics: Dictionary = candidate_digit_attempt.get(
				"last_attempt_diagnostics",
				candidate_digit_attempt.get("diagnostics", {})
			) as Dictionary
			print(
				"  CANDIDATE_DIGIT status=", candidate_digit_attempt.get("status", &""),
				" unsafe=", candidate_digit_diagnostics.get("unsafe_digit_count", -1),
				" contact=", candidate_digit_diagnostics.get("max_contact_error_meters", -1),
				" penetration=", candidate_digit_diagnostics.get("max_penetration_meters", -1)
			)
			var candidate_digits: Dictionary = candidate_digit_diagnostics.get(
				"digit_results",
				{}
			) as Dictionary
			for candidate_digit: StringName in [&"thumb", &"index", &"middle", &"ring", &"pinky"]:
				var candidate_digit_state: Dictionary = candidate_digits.get(
					candidate_digit,
					{}
				) as Dictionary
				if candidate_digit_state.is_empty():
					continue
				print(
					"   CANDIDATE_DIGIT ", String(candidate_digit),
					" status=", candidate_digit_state.get("status", &""),
					" safe=", candidate_digit_state.get("safe_to_apply", false),
					" max_pen=", candidate_digit_state.get(
						"attempted_max_penetration_meters",
						candidate_digit_state.get("max_penetration_meters", -1)
					)
				)
		var candidate_passes: Array = candidate.get("transaction_passes", []) as Array
		for candidate_pass_variant: Variant in candidate_passes:
			if candidate_pass_variant is not Dictionary:
				continue
			var candidate_pass: Dictionary = candidate_pass_variant as Dictionary
			var candidate_correction: Transform3D = candidate_pass.get(
				"correction_local",
				Transform3D.IDENTITY
			) as Transform3D
			var candidate_rotation_degrees: float = rad_to_deg(
				candidate_correction.basis.orthonormalized()
					.get_rotation_quaternion().get_angle()
			)
			candidate_rotation_degrees = minf(
				candidate_rotation_degrees,
				360.0 - candidate_rotation_degrees
			)
			print(
				"  CANDIDATE_PASS ", candidate_pass.get("pass_index", -1),
				" seat=", candidate_pass.get("seat_status", &""),
				"/", candidate_pass.get("seat_valid", false),
				" sample=", candidate_pass.get("candidate_sample_index", -1),
				" kind=", candidate_pass.get("correction_kind", &""),
				" correction_mm=", candidate_correction.origin.length() * 1000.0,
				" correction_deg=", candidate_rotation_degrees,
				" hard_excess=", candidate_pass.get(
					"hard_law_excess_normalized",
					-1
				)
			)
	if not bool(transaction.get("committed", false)):
		# Read-only geometric follow-up after the transaction has restored its
		# baseline. This intentionally does not apply the returned correction.
		var support_slot_id: StringName = (
			&"hand_right" if primary_slot_id == &"hand_left" else &"hand_left"
		)
		actor.call("invalidate_authoring_active_weapon_surface_seat", support_slot_id)
		var dry_requery: Dictionary = actor.call(
			"resolve_exact_surface_weapon_seat",
			support_slot_id,
			true
		) as Dictionary
		var dry_correction: Transform3D = dry_requery.get(
			"seat_correction_grip_local",
			Transform3D.IDENTITY
		) as Transform3D
		var dry_rotation_degrees: float = rad_to_deg(
			dry_correction.basis.orthonormalized().get_rotation_quaternion().get_angle()
		)
		dry_rotation_degrees = minf(
			dry_rotation_degrees,
			360.0 - dry_rotation_degrees
		)
		print(
			" POST_REJECTION_DRY seat=",
			dry_requery.get("status", &""),
			"/",
			dry_requery.get("valid", false),
			" sample=",
			dry_requery.get("candidate_sample_index", -1),
			" correction_mm=",
			dry_correction.origin.length() * 1000.0,
			" correction=",
			dry_correction,
			" correction_deg=",
			dry_rotation_degrees,
			" identity=",
			dry_correction.origin.length() <= 0.000001
				and dry_rotation_degrees <= 0.0001
		)
	var support_attempt: Dictionary = transaction.get("support_digit_grip_attempt", {}) as Dictionary
	if not support_attempt.is_empty():
		var attempt_diag: Dictionary = support_attempt.get("last_attempt_diagnostics", support_attempt.get("diagnostics", {})) as Dictionary
		print(" SUPPORT_DIGIT status=", support_attempt.get("status", &""), "/", support_attempt.get("valid", false), " unsafe=", attempt_diag.get("unsafe_digit_count", -1), " solved=", attempt_diag.get("solved_digit_count", -1), " contact=", attempt_diag.get("max_contact_error_meters", -1), " penetration=", attempt_diag.get("max_penetration_meters", -1), " overlap_ok=", attempt_diag.get("overlap_limit_respected", false))
		var attempt_digits: Dictionary = attempt_diag.get("digit_results", {}) as Dictionary
		for digit: StringName in [&"thumb", &"index", &"middle", &"ring", &"pinky"]:
			var dd: Dictionary = attempt_digits.get(digit, {}) as Dictionary
			if not dd.is_empty():
				print("  SUPPORT ", String(digit), " valid=", dd.get("valid", false), " safe=", dd.get("safe_to_apply", false), " status=", dd.get("status", &""), " contacts=", dd.get("contacted_section_count", -1), " accepted=", dd.get("accepted_section_count", -1), " max_err=", dd.get("attempted_max_contact_error_meters", dd.get("max_contact_error_meters", -1)), " max_pen=", dd.get("attempted_max_penetration_meters", dd.get("max_penetration_meters", -1)))
	var primary_guide := held.get_node_or_null("PrimaryGripGuide") as Node3D
	var support_guide := held.get_node_or_null("SecondaryGripGuide") as Node3D
	if primary_guide != null and support_guide != null:
		print("GUIDES primary_local=", primary_guide.position, " support_local=", support_guide.position, " separation_mm=", primary_guide.global_position.distance_to(support_guide.global_position) * 1000.0)
	print("RATIO primary=", held.get_meta("preview_primary_grip_seat_axis_ratio_from_span_start", -1), " support=", held.get_meta("preview_support_grip_seat_axis_ratio_from_span_start", -1))
	for slot: StringName in [&"hand_right", &"hand_left"]:
		var seat: Dictionary = actor.call("get_weapon_surface_seat_debug_state", slot)
		var grasp: Dictionary = finger.call("get_surface_grasp_debug_state", slot)
		var sd: Dictionary = seat.get("diagnostics", {})
		var best: Dictionary = sd.get("best_overall", {})
		var gd: Dictionary = grasp.get("last_attempt_diagnostics", grasp.get("diagnostics", {}))
		print(String(slot), " seat=", seat.get("status", &""), "/", seat.get("valid", false), " radial=", best.get("max_abs_radial_error_meters", -1), " ordinary_safe=", best.get("ordinary_proximal_capsules_safe", false), " seat_worst_digit=", best.get("ordinary_proximal_worst_digit_id", &""), " seat_worst_penetration=", best.get("ordinary_proximal_worst_penetration_meters", -1), " seat_worst_excess=", best.get("ordinary_proximal_worst_excess_penetration_meters", -1), " grasp=", grasp.get("status", &""), "/", grasp.get("valid", false), " rotations=", (grasp.get("rotations", {}) as Dictionary).size(), " unsafe=", gd.get("unsafe_digit_count", -1), " contact=", gd.get("max_contact_error_meters", -1), " penetration=", gd.get("max_penetration_meters", -1))
		var digit_results: Dictionary = gd.get("digit_results", {})
		for digit: StringName in [&"thumb", &"index", &"middle", &"ring", &"pinky"]:
			var dd: Dictionary = digit_results.get(digit, {})
			if not dd.is_empty():
				print(" ", String(digit), " valid=", dd.get("valid", false), " safe=", dd.get("safe_to_apply", false), " status=", dd.get("status", &""), " contacts=", dd.get("contacted_section_count", -1), " accepted=", dd.get("accepted_section_count", -1), " max_err=", dd.get("attempted_max_contact_error_meters", dd.get("max_contact_error_meters", -1)), " max_pen=", dd.get("attempted_max_penetration_meters", dd.get("max_penetration_meters", -1)))
	var two: Dictionary = actor.get("last_two_hand_solve_result")
	for slot: StringName in [&"hand_right", &"hand_left"]:
		var ss: Dictionary = two.get(slot, {})
		print(String(slot), " reach_clamped=", ss.get("arm_reach_clamped", false), " before=", ss.get("arm_reach_before_meters", -1), " after=", ss.get("arm_reach_after_meters", -1), " path_illegal=", ss.get("path_illegal", false), " front_fail=", ss.get("front_bias_failed", false))
	var dbg := ui.get_preview_debug_state()
	print("ALIGN primary=", dbg.get("dominant_grip_alignment_error_meters", -1), " support=", dbg.get("support_grip_alignment_error_meters", -1))


func _dump_extended_support_candidate(attempt: Dictionary) -> void:
	if attempt.is_empty():
		return
	var result: Dictionary = attempt.get("result", {}) as Dictionary
	print(
		"EXTENDED_SUPPORT_CANDIDATE degrees=", attempt.get("candidate_degrees", NAN),
		" passes=", attempt.get("fixed_point_passes", -1),
		" no_twist=", attempt.get("disable_limb_twist", false),
		" status=", result.get("status", attempt.get("status", &"")),
		" seat_verified=", attempt.get("seat_verified", false),
		" digit_committed=", attempt.get("digit_packet_committed", false),
		" primary_exact=", attempt.get("primary_weapon_unit_unchanged", false),
		" corrections=", attempt.get("applied_correction_count", -1),
		" restored=", attempt.get("test_baseline_restored_after_diagnostic", false)
	)
	if attempt.has("test_digit_packet_committed_ignoring_body_gate"):
		var test_digit_state: Dictionary = attempt.get(
			"test_digit_packet_state_ignoring_body_gate",
			{}
		) as Dictionary
		var test_digit_diagnostics: Dictionary = test_digit_state.get(
			"last_attempt_diagnostics",
			test_digit_state.get("diagnostics", {})
		) as Dictionary
		print(
			" EXTENDED_DIGIT_IGNORING_BODY_GATE committed=",
			attempt.get("test_digit_packet_committed_ignoring_body_gate", false),
			" status=", test_digit_state.get("status", &""),
			" valid=", test_digit_state.get("valid", false),
			" rotations=", (test_digit_state.get("rotations", {}) as Dictionary).size(),
			" unsafe=", test_digit_diagnostics.get("unsafe_digit_count", -1),
			" contact=", test_digit_diagnostics.get("max_contact_error_meters", -1),
			" penetration=", test_digit_diagnostics.get("max_penetration_meters", -1)
		)
	for pass_variant: Variant in attempt.get("transaction_passes", []) as Array:
		if pass_variant is not Dictionary:
			continue
		var pass_state: Dictionary = pass_variant as Dictionary
		var correction: Transform3D = pass_state.get(
			"correction_local",
			Transform3D.IDENTITY
		) as Transform3D
		var rotation_degrees: float = rad_to_deg(
			correction.basis.orthonormalized().get_rotation_quaternion().get_angle()
		)
		rotation_degrees = minf(rotation_degrees, 360.0 - rotation_degrees)
		print(
			" EXTENDED_PASS ", pass_state.get("pass_index", -1),
			" seat=", pass_state.get("seat_status", &""),
			"/", pass_state.get("seat_valid", false),
			" sample=", pass_state.get("candidate_sample_index", -1),
			" kind=", pass_state.get("correction_kind", &""),
			" correction_mm=", correction.origin.length() * 1000.0,
			" correction_deg=", rotation_degrees,
			" hard_excess=", pass_state.get("hard_law_excess_normalized", -1)
		)
	var body_gate: Dictionary = result.get(
		"support_body_self_collision_gate",
		{}
	) as Dictionary
	if not body_gate.is_empty():
		print(" EXTENDED_BODY_GATE=", var_to_str(body_gate))
	var digit_attempt: Dictionary = result.get(
		"support_digit_grip_attempt",
		{}
	) as Dictionary
	if not digit_attempt.is_empty():
		print(" EXTENDED_DIGIT_ATTEMPT=", var_to_str(digit_attempt))
	print(
		" EXTENDED_POST_SEAT_ARM=",
		var_to_str(attempt.get("test_post_seat_arm_legalization", {}))
	)
	print(
		" EXTENDED_POST_SEAT_THREE_LINK_SCAN=",
		var_to_str(attempt.get("test_post_seat_three_link_candidate_scan", {}))
	)
	print(
		" EXTENDED_POST_SEAT_ANATOMICAL_JOINT_SCAN=",
		var_to_str(attempt.get(
			"test_post_seat_anatomical_joint_space_scan",
			{}
		))
	)
	print(
		" EXTENDED_POST_SEAT_CONTACT_SPACE_SCAN=",
		var_to_str(attempt.get("test_post_seat_contact_space_scan", {}))
	)
	print(
		" EXTENDED_POST_SEAT_SHARED_TORSO_DUAL_ARM_SCAN=",
		var_to_str(attempt.get(
			"test_post_seat_shared_torso_dual_arm_scan",
			{}
		))
	)
	print(
		" EXTENDED_POST_SEAT_RANGE=",
		var_to_str(attempt.get("test_post_seat_arm_range_state", {}))
	)
	print(
		" EXTENDED_POST_SEAT_BODY=",
		var_to_str(attempt.get("test_post_seat_body_gate", {}))
	)
	print(
		" EXTENDED_POST_SEAT_SURFACE=",
		var_to_str(attempt.get("test_post_seat_surface_recheck", {}))
	)
	print(
		" EXTENDED_ARM_RANGE baseline=",
		var_to_str(attempt.get("test_baseline_arm_range_state", {})),
		" candidate=",
		var_to_str(attempt.get("test_candidate_arm_range_state", {}))
	)
	print(
		" EXTENDED_ARM_GEOMETRY baseline=",
		var_to_str(attempt.get("test_baseline_arm_geometry_state", {})),
		" prepared=",
		var_to_str(attempt.get("test_prepared_arm_geometry_state", {})),
		" candidate=",
		var_to_str(attempt.get("test_candidate_arm_geometry_state", {}))
	)
	print(
		" EXTENDED_JOINT_FRAMES baseline=",
		var_to_str(attempt.get("test_baseline_joint_frame_state", {})),
		" prepared=",
		var_to_str(attempt.get("test_prepared_joint_frame_state", {})),
		" seated=",
		var_to_str(attempt.get("test_seated_joint_frame_state", {}))
	)
	_dump_test_support_body_pairs(
		"BASELINE",
		attempt.get("test_baseline_body_state", {}) as Dictionary,
		StringName(attempt.get("test_support_slot_id", StringName()))
	)
	_dump_test_support_body_pairs(
		"CANDIDATE",
		attempt.get("test_candidate_body_state", {}) as Dictionary,
		StringName(attempt.get("test_support_slot_id", StringName()))
	)
	for swivel_variant: Variant in attempt.get(
		"test_elbow_swivel_attempts",
		[]
	) as Array:
		if swivel_variant is not Dictionary:
			continue
		var swivel: Dictionary = swivel_variant as Dictionary
		var swivel_body_gate: Dictionary = swivel.get("body_gate", {}) as Dictionary
		var swivel_baseline_pair: Dictionary = swivel_body_gate.get(
			"baseline_pair",
			{}
		) as Dictionary
		var swivel_digit_state: Dictionary = swivel.get("digit_state", {}) as Dictionary
		var swivel_digit_diagnostics: Dictionary = swivel_digit_state.get(
			"last_attempt_diagnostics",
			swivel_digit_state.get("diagnostics", {})
		) as Dictionary
		print(
			" EXTENDED_ELBOW_SWIVEL degrees=", swivel.get("degrees", NAN),
			" status=", swivel.get("status", &""),
			" hand_mm=", float(swivel.get("hand_position_error_meters", INF)) * 1000.0,
			" hand_deg=", swivel.get("hand_basis_error_degrees", INF),
			" body=", swivel_body_gate.get("status", &""),
			" rejected=", swivel_body_gate.get("rejected_pair_signature", ""),
			" rejected_clearance=", float((swivel_body_gate.get(
				"rejected_pair",
				{}
			) as Dictionary).get("clearance_meters", INF)),
			" baseline_clearance=", float(swivel_baseline_pair.get(
				"clearance_meters",
				INF
			)),
			" candidate_illegal=", swivel_body_gate.get(
				"candidate_illegal_pair_count",
				-1
			),
			" primary_exact=", swivel.get("primary_weapon_unit_unchanged", false),
			" seat_identity=", swivel.get("seat_identity", false),
			" digit_committed=", swivel.get("digit_packet_committed", false),
			" unsafe=", swivel_digit_diagnostics.get("unsafe_digit_count", -1),
			" penetration=", swivel_digit_diagnostics.get(
				"max_penetration_meters",
				-1
			)
		)


func _dump_test_support_body_pairs(
	label: String,
	body_state: Dictionary,
	support_slot_id: StringName
) -> void:
	var support_region_prefix: String = (
		"left_" if support_slot_id == &"hand_left" else "right_"
	)
	for pair_variant: Variant in body_state.get("illegal_pairs", []) as Array:
		if pair_variant is not Dictionary:
			continue
		var pair: Dictionary = pair_variant as Dictionary
		var first_region: String = String(pair.get("first_region", ""))
		var second_region: String = String(pair.get("second_region", ""))
		if (
			not first_region.begins_with(support_region_prefix)
			and not second_region.begins_with(support_region_prefix)
		):
			continue
		print(
			" EXTENDED_", label, "_SUPPORT_PAIR ",
			pair.get("first_region", ""), "::",
			pair.get("second_region", ""),
			" clearance=", pair.get("clearance_meters", INF),
			" bones=", pair.get("first_bone_name", StringName()), "::",
			pair.get("second_bone_name", StringName())
		)


func _capture_test_arm_geometry_state(
	actor: Node3D,
	slot_id: StringName
) -> Dictionary:
	if actor == null or slot_id not in [&"hand_right", &"hand_left"]:
		return {"valid": false}
	var left_side: bool = slot_id == &"hand_left"
	var clavicle_bone: StringName = (
		&"CC_Base_L_Clavicle" if left_side else &"CC_Base_R_Clavicle"
	)
	var upperarm_bone: StringName = (
		&"CC_Base_L_Upperarm" if left_side else &"CC_Base_R_Upperarm"
	)
	var forearm_bone: StringName = (
		&"CC_Base_L_Forearm" if left_side else &"CC_Base_R_Forearm"
	)
	var hand_bone: StringName = (
		&"CC_Base_L_Hand" if left_side else &"CC_Base_R_Hand"
	)
	var clavicle_world: Vector3 = actor.call(
		"_get_bone_world_position",
		clavicle_bone
	) as Vector3
	var shoulder_world: Vector3 = actor.call(
		"_get_bone_world_position",
		upperarm_bone
	) as Vector3
	var elbow_world: Vector3 = actor.call(
		"_get_bone_world_position",
		forearm_bone
	) as Vector3
	var hand_world: Vector3 = actor.call(
		"_get_bone_world_position",
		hand_bone
	) as Vector3
	# The surface guidance node is the authored Handle frame, not the hand-bone
	# endpoint consumed by the arm solve. Measure against the actual IK target so
	# reachability diagnostics do not mistake the alignment offset for arm reach.
	var guidance_target: Node3D = actor.get(
		"left_hand_ik_target" if left_side else "right_hand_ik_target"
	) as Node3D
	var target_world: Vector3 = (
		guidance_target.global_position if guidance_target != null else hand_world
	)
	return {
		"valid": true,
		"clavicle_world": clavicle_world,
		"shoulder_world": shoulder_world,
		"elbow_world": elbow_world,
		"hand_world": hand_world,
		"target_world": target_world,
		"world_origin_id": &"RL_BoneRoot",
		"clavicle_length_meters": clavicle_world.distance_to(shoulder_world),
		"upperarm_length_meters": shoulder_world.distance_to(elbow_world),
		"forearm_length_meters": elbow_world.distance_to(hand_world),
		"shoulder_target_distance_meters": shoulder_world.distance_to(target_world),
		"hand_target_error_meters": hand_world.distance_to(target_world),
	}


func _capture_test_joint_frame_state(
	actor: Node3D,
	slot_id: StringName
) -> Dictionary:
	var skeleton: Skeleton3D = actor.get("skeleton") as Skeleton3D
	if skeleton == null or slot_id not in [&"hand_right", &"hand_left"]:
		return {"valid": false}
	var left_side: bool = slot_id == &"hand_left"
	var bone_names: Array[StringName] = [
		&"CC_Base_Spine02",
		&"CC_Base_L_Clavicle" if left_side else &"CC_Base_R_Clavicle",
		&"CC_Base_L_Upperarm" if left_side else &"CC_Base_R_Upperarm",
		&"CC_Base_L_Forearm" if left_side else &"CC_Base_R_Forearm",
		&"CC_Base_L_Hand" if left_side else &"CC_Base_R_Hand",
	]
	var bones: Dictionary = {}
	for bone_name: StringName in bone_names:
		var bone_index: int = skeleton.find_bone(String(bone_name))
		if bone_index < 0:
			return {"valid": false, "missing_bone": bone_name}
		var parent_index: int = skeleton.get_bone_parent(bone_index)
		var parent_global_pose: Transform3D = (
			skeleton.get_bone_global_pose(parent_index)
			if parent_index >= 0
			else Transform3D.IDENTITY
		)
		var rest_local: Transform3D = skeleton.get_bone_rest(bone_index)
		var pose_local: Transform3D = skeleton.get_bone_pose(bone_index)
		var actual_global_pose: Transform3D = skeleton.get_bone_global_pose(bone_index)
		var parent_then_pose: Transform3D = parent_global_pose * pose_local
		var rest_then_pose: Transform3D = parent_global_pose * rest_local * pose_local
		var pose_then_rest: Transform3D = parent_global_pose * pose_local * rest_local
		var rest_relative_pose: Transform3D = rest_local.affine_inverse() * pose_local
		bones[bone_name] = {
			"bone_index": bone_index,
			"parent_index": parent_index,
			"parent_name": StringName(skeleton.get_bone_name(parent_index)) if parent_index >= 0 else StringName(),
			"rest_local": rest_local,
			"pose_local": pose_local,
			"rest_relative_pose": rest_relative_pose,
			"actual_global_pose": actual_global_pose,
			"parent_then_pose_origin_error": actual_global_pose.origin.distance_to(parent_then_pose.origin),
			"parent_then_pose_basis_error_degrees": rad_to_deg(actual_global_pose.basis.orthonormalized().get_rotation_quaternion().angle_to(parent_then_pose.basis.orthonormalized().get_rotation_quaternion())),
			"rest_then_pose_origin_error": actual_global_pose.origin.distance_to(rest_then_pose.origin),
			"rest_then_pose_basis_error_degrees": rad_to_deg(actual_global_pose.basis.orthonormalized().get_rotation_quaternion().angle_to(rest_then_pose.basis.orthonormalized().get_rotation_quaternion())),
			"pose_then_rest_origin_error": actual_global_pose.origin.distance_to(pose_then_rest.origin),
			"pose_then_rest_basis_error_degrees": rad_to_deg(actual_global_pose.basis.orthonormalized().get_rotation_quaternion().angle_to(pose_then_rest.basis.orthonormalized().get_rotation_quaternion())),
		}
	return {
		"valid": true,
		"slot_id": slot_id,
		"point_origin_id": &"RL_BoneRoot",
		"bones": bones,
	}


func _dump_captured_primary_calls(
	capture_solver: CaptureSeatSolver,
	primary_slot_id: StringName
) -> void:
	print("PRIMARY_LITERAL_CALL_COUNT=", capture_solver.calls.size())
	for call_index: int in range(capture_solver.calls.size()):
		var call_state: Dictionary = capture_solver.calls[call_index]
		var anatomy: Dictionary = call_state.get("anatomy_state", {}) as Dictionary
		var result: Dictionary = call_state.get("result", {}) as Dictionary
		var diagnostics: Dictionary = result.get("diagnostics", {}) as Dictionary
		var best: Dictionary = diagnostics.get("best_overall", {}) as Dictionary
		var accepted: Dictionary = diagnostics.get("best_accepted", {}) as Dictionary
		var guide_world: Transform3D = call_state.get(
			"guide_world_transform",
			Transform3D.IDENTITY
		) as Transform3D
		var guide_inverse: Transform3D = guide_world.affine_inverse()
		var hand_world: Transform3D = call_state.get(
			"hand_world_transform",
			Transform3D.IDENTITY
		) as Transform3D
		var hand_inverse: Transform3D = hand_world.affine_inverse()
		var c0: Vector3 = call_state.get("grip_pivot_c0_world", Vector3.ZERO) as Vector3
		var ci: Vector3 = call_state.get("index_slice_center_ci_world", Vector3.ZERO) as Vector3
		var cp: Vector3 = call_state.get("pinky_slice_center_cp_world", Vector3.ZERO) as Vector3
		var endcap_axis: Vector3 = call_state.get("endcap_axis_world", Vector3.ZERO) as Vector3
		var index_point: Vector3 = anatomy.get("index_point_world", Vector3.ZERO) as Vector3
		var pinky_point: Vector3 = anatomy.get("pinky_point_world", Vector3.ZERO) as Vector3
		var index_close: Vector3 = anatomy.get(
			"index_authorized_closing_direction_world",
			Vector3.ZERO
		) as Vector3
		var pinky_close: Vector3 = anatomy.get(
			"pinky_authorized_closing_direction_world",
			Vector3.ZERO
		) as Vector3
		var candidate_basis: Basis = result.get(
			"candidate_weapon_correction_basis_world",
			Basis.IDENTITY
		) as Basis
		var candidate_translation: Vector3 = result.get(
			"candidate_weapon_radial_translation_world",
			Vector3.ZERO
		) as Vector3
		print(
			" PRIMARY_LITERAL call=", call_index,
			" slot=", primary_slot_id,
			" status=", result.get("status", &""),
			" valid=", result.get("valid", false),
			" sample=", result.get("candidate_sample_index", -1),
			" surface=", call_state.get("surface_signature", ""),
			" surface_origin=", call_state.get("surface_source_origin_id", &""),
			" world_origin=", call_state.get("resolved_world_origin_id", &"")
		)
		print(
			"  GUIDE local=", call_state.get("guide_local_transform", Transform3D.IDENTITY),
			" world=", guide_world,
			" in_hand=", call_state.get("guide_in_hand_transform", Transform3D.IDENTITY),
			" alignment=", call_state.get("alignment_state", {}),
			" contact_center=", call_state.get("contact_center_world", Vector3.ZERO)
		)
		print(
			"  HAND world=", hand_world,
			" anchor_local=", call_state.get("hand_anchor_local_transform", Transform3D.IDENTITY),
			" anchor_world=", call_state.get("hand_anchor_world_transform", Transform3D.IDENTITY),
			" anchor_in_hand=", call_state.get("hand_anchor_in_hand_transform", Transform3D.IDENTITY),
			" weapon_in_hand=", call_state.get("weapon_in_hand_transform", Transform3D.IDENTITY),
			" weapon_in_anchor=", call_state.get("weapon_in_anchor_transform", Transform3D.IDENTITY),
			" stored_mount=", call_state.get("stored_hand_mount_transform", Transform3D.IDENTITY)
		)
		print(
			"  STATIONS C0=", c0,
			" Ci=", ci,
			" Cp=", cp,
			" axis=", endcap_axis,
			" guide_local=[", guide_inverse * c0,
			",", guide_inverse * ci,
			",", guide_inverse * cp,
			",", guide_world.basis.inverse() * endcap_axis, "]"
		)
		print(
			"  ANATOMY index=", index_point,
			" pinky=", pinky_point,
			" close=[", index_close, ",", pinky_close, "]",
			" guide_local=[", guide_inverse * index_point,
			",", guide_inverse * pinky_point,
			",", guide_world.basis.inverse() * index_close,
			",", guide_world.basis.inverse() * pinky_close, "]",
			" origins=[", anatomy.get("index_point_world_origin_id", &""),
			",", anatomy.get("pinky_point_world_origin_id", &""),
			",", anatomy.get("index_authorized_closing_direction_world_origin_id", &""),
			",", anatomy.get("pinky_authorized_closing_direction_world_origin_id", &""),
			"] sources=[", anatomy.get("index_point_source_origin_id", &""),
			",", anatomy.get("pinky_point_source_origin_id", &""), "]"
		)
		print(
			"  ANATOMY_IN_HAND index=", hand_inverse * index_point,
			" pinky=", hand_inverse * pinky_point,
			" close=[", hand_world.basis.inverse() * index_close,
			",", hand_world.basis.inverse() * pinky_close, "]"
		)
		print(
			"  BEST sample=", best.get("sample_index", -1),
			" accepted=", best.get("accepted", false),
			" errors=[", best.get("index_radial_error_meters", INF),
			",", best.get("pinky_radial_error_meters", INF), "]",
			" close_dots=[", best.get("index_radial_closing_side_dot", INF),
			",", best.get("pinky_radial_closing_side_dot", INF), "]",
			" flipped=[", best.get("index_radial_side_flipped_for_closing_authority", false),
			",", best.get("pinky_radial_side_flipped_for_closing_authority", false), "]",
			" ordinary_safe=", best.get("ordinary_proximal_capsules_safe", false),
			" worst=", best.get("ordinary_proximal_worst_digit_id", &""),
			" worst_pen=", best.get("ordinary_proximal_worst_penetration_meters", -1),
			" worst_excess=", best.get("ordinary_proximal_worst_excess_penetration_meters", -1),
			" rotation_deg=", rad_to_deg(float(best.get("correction_angle_radians", 0.0))),
			" radial_translation=", best.get("weapon_radial_translation_world", Vector3.ZERO),
			" radial_axial=", best.get("weapon_radial_translation_axial_meters", INF),
			" radial_perpendicular=", best.get("weapon_radial_translation_perpendicular_meters", INF),
			" index_clearance_error=", best.get("index_target_surface_clearance_error_meters", INF),
			" pinky_clearance_error=", best.get("pinky_target_surface_clearance_error_meters", INF),
			" index_authority_pen=", best.get("index_authority_proximal_penetration_meters", INF),
			" pinky_authority_pen=", best.get("pinky_authority_proximal_penetration_meters", INF),
			" accepted_sample=", accepted.get("sample_index", -1),
			" candidate_deg=", rad_to_deg(
				candidate_basis.orthonormalized().get_rotation_quaternion().get_angle()
			),
			" candidate_translation=", candidate_translation
		)
		if not accepted.is_empty():
			print(
				"  ACCEPTED sample=", accepted.get("sample_index", -1),
				" errors=[", accepted.get("index_radial_error_meters", INF),
				",", accepted.get("pinky_radial_error_meters", INF), "]",
				" ordinary_safe=", accepted.get(
					"ordinary_proximal_capsules_safe",
					false
				),
				" worst=", accepted.get("ordinary_proximal_worst_digit_id", &""),
				" worst_pen=", accepted.get(
					"ordinary_proximal_worst_penetration_meters",
					-1
				),
				" worst_excess=", accepted.get(
					"ordinary_proximal_worst_excess_penetration_meters",
					-1
				)
			)


func _dump_primary_first_acquisition_attempt(
	actor: Node3D,
	held: Node3D,
	transaction: Dictionary,
	primary_slot_id: StringName
) -> void:
	var primary_guide := held.get_node_or_null("PrimaryGripGuide") as Node3D
	if primary_guide == null:
		print(" PRIMARY_FIRST unavailable=primary_guide_missing")
		return
	var initial_weapon_transform: Transform3D = held.global_transform
	if bool(transaction.get("committed", false)):
		var passes: Array = transaction.get("transaction_passes", []) as Array
		for pass_index: int in range(passes.size() - 1, -1, -1):
			var pass_state: Dictionary = passes[pass_index] as Dictionary
			var correction_local: Transform3D = pass_state.get(
				"correction_local",
				Transform3D.IDENTITY
			) as Transform3D
			initial_weapon_transform = (
				initial_weapon_transform * correction_local.affine_inverse()
			)
	held.global_transform = initial_weapon_transform
	actor.call("set_finger_grip_target", primary_slot_id, primary_guide)
	actor.call("prepare_authoring_surface_grip_open_pose_now", primary_slot_id)
	actor.call(
		"invalidate_authoring_active_weapon_surface_seat",
		primary_slot_id
	)
	var anatomy: Dictionary = actor.call(
		"resolve_hand_surface_seat_anatomy_state",
		primary_slot_id
	) as Dictionary
	var attempt: Dictionary = actor.call(
		"resolve_exact_surface_weapon_seat",
		primary_slot_id,
		true
	) as Dictionary
	var diagnostics: Dictionary = attempt.get("diagnostics", {}) as Dictionary
	var stations: Dictionary = diagnostics.get("stations", {}) as Dictionary
	print(
		" PRIMARY_FIRST slot=", primary_slot_id,
		" status=", attempt.get("status", &""),
		" valid=", attempt.get("valid", false),
		" sample=", attempt.get("candidate_sample_index", -1)
	)
	print(
		" PRIMARY_FIRST_GUIDE local=", primary_guide.transform,
		" global=", primary_guide.global_transform
	)
	print(
		" PRIMARY_FIRST_STATIONS C0=", stations.get("grip_pivot_c0_world", Vector3.ZERO),
		" Ci=", stations.get("index_slice_center_ci_world", Vector3.ZERO),
		" Cp=", stations.get("pinky_slice_center_cp_world", Vector3.ZERO),
		" axis=", stations.get("endcap_axis_world", Vector3.ZERO),
		" origins=[", stations.get("grip_pivot_c0_world_origin_id", &""),
		",", stations.get("index_slice_center_ci_world_origin_id", &""),
		",", stations.get("pinky_slice_center_cp_world_origin_id", &""),
		",", stations.get("endcap_axis_world_origin_id", &""), "]"
	)
	print(
		" PRIMARY_FIRST_ANATOMY index=", anatomy.get("index_point_world", Vector3.ZERO),
		" pinky=", anatomy.get("pinky_point_world", Vector3.ZERO),
		" index_close=", anatomy.get("index_authorized_closing_direction_world", Vector3.ZERO),
		" pinky_close=", anatomy.get("pinky_authorized_closing_direction_world", Vector3.ZERO),
		" origins=[", anatomy.get("index_point_world_origin_id", &""),
		",", anatomy.get("pinky_point_world_origin_id", &""),
		",", anatomy.get("index_authorized_closing_direction_world_origin_id", &""),
		",", anatomy.get("pinky_authorized_closing_direction_world_origin_id", &""), "]"
	)
	var guide_basis_inverse: Basis = primary_guide.global_basis.inverse()
	print(
		" PRIMARY_FIRST_GUIDE_LOCAL Ci=", primary_guide.to_local(
			stations.get("index_slice_center_ci_world", Vector3.ZERO) as Vector3
		),
		" Cp=", primary_guide.to_local(
			stations.get("pinky_slice_center_cp_world", Vector3.ZERO) as Vector3
		),
		" index=", primary_guide.to_local(
			anatomy.get("index_point_world", Vector3.ZERO) as Vector3
		),
		" pinky=", primary_guide.to_local(
			anatomy.get("pinky_point_world", Vector3.ZERO) as Vector3
		),
		" axis=", guide_basis_inverse * (
			stations.get("endcap_axis_world", Vector3.ZERO) as Vector3
		),
		" index_close=", guide_basis_inverse * (
			anatomy.get("index_authorized_closing_direction_world", Vector3.ZERO) as Vector3
		),
		" pinky_close=", guide_basis_inverse * (
			anatomy.get("pinky_authorized_closing_direction_world", Vector3.ZERO) as Vector3
		)
	)
	var skeleton: Skeleton3D = actor.get("skeleton") as Skeleton3D
	var hand_bone_name: StringName = (
		&"CC_Base_L_Hand" if primary_slot_id == &"hand_left" else &"CC_Base_R_Hand"
	)
	if skeleton != null:
		var hand_bone_index: int = skeleton.find_bone(String(hand_bone_name))
		if hand_bone_index >= 0:
			var hand_world: Transform3D = (
				skeleton.global_transform
				* skeleton.get_bone_global_pose(hand_bone_index)
			)
			var hand_inverse: Transform3D = hand_world.affine_inverse()
			print(
				" PRIMARY_FIRST_GUIDE_IN_HAND=",
				hand_inverse * primary_guide.global_transform
			)
			print(
				" PRIMARY_FIRST_ANATOMY_IN_HAND index=",
				hand_inverse * (anatomy.get("index_point_world", Vector3.ZERO) as Vector3),
				" pinky=",
				hand_inverse * (anatomy.get("pinky_point_world", Vector3.ZERO) as Vector3),
				" index_close=",
				hand_world.basis.inverse() * (
					anatomy.get("index_authorized_closing_direction_world", Vector3.ZERO) as Vector3
				),
				" pinky_close=",
				hand_world.basis.inverse() * (
					anatomy.get("pinky_authorized_closing_direction_world", Vector3.ZERO) as Vector3
				)
			)
			var hand_anchor: Node3D = (
				actor.call("get_left_hand_item_anchor") as Node3D
				if primary_slot_id == &"hand_left"
				else actor.call("get_right_hand_item_anchor") as Node3D
			)
			if hand_anchor != null:
				print(
					" PRIMARY_FIRST_HAND_ANCHOR local=", hand_anchor.transform,
					" in_hand=", hand_inverse * hand_anchor.global_transform,
					" guide_in_anchor=", hand_anchor.global_transform.affine_inverse()
						* primary_guide.global_transform,
					" weapon_in_anchor=", hand_anchor.global_transform.affine_inverse()
						* held.global_transform,
					" stored_mount=", held.get_meta(
						"hand_mount_local_transform",
						Transform3D.IDENTITY
					)
				)
			var alignment_state: Dictionary = actor.call(
				"resolve_hand_grip_alignment_offset_state",
				primary_slot_id
			) as Dictionary
			print(
				" PRIMARY_FIRST_ALIGNMENT state=", alignment_state,
				" contact_center_world=",
				actor.call("_resolve_hand_index_pinky_contact_center_world", primary_slot_id),
				" cached_anatomical_world=",
				(actor.get("finger_grip_presenter") as Object).call(
					"resolve_hand_grip_alignment_world_position",
					skeleton,
					primary_slot_id
				)
			)
			var basis_anchor: Node3D = held.get_node_or_null(
				"PrimaryGripAnchor/PrimaryGripBasisAnchor"
			) as Node3D
			if basis_anchor != null:
				print(
					" PRIMARY_FIRST_BASIS_ANCHOR local=", basis_anchor.transform,
					" global=", basis_anchor.global_transform,
					" in_hand=", hand_inverse * basis_anchor.global_transform
				)
	var finger: Object = actor.get("finger_grip_presenter") as Object
	var execution_path: StringName = (
		&"left_primary" if primary_slot_id == &"hand_left" else &"right_primary"
	)
	var prepared_lookup: Dictionary = (
		finger.get("weapon_surface_seat_prepared_attempt_lookup") as Dictionary
		if finger != null
		else {}
	)
	var prepared_record: Dictionary = prepared_lookup.get(
		execution_path,
		{}
	) as Dictionary
	var prepared_surface: Dictionary = prepared_record.get(
		"prepared_surface",
		{}
	) as Dictionary
	var solver: Object = (
		finger.get("hand_surface_seat_solver") as Object
		if finger != null
		else null
	)
	if solver is CaptureSeatSolver:
		solver = (solver as CaptureSeatSolver).delegate
	if solver == null or prepared_surface.is_empty():
		print(" PRIMARY_FIRST unavailable=prepared_surface_missing path=", execution_path)
		return
	var surface_bounds: AABB = solver.call(
		"_resolve_surface_bounds",
		prepared_surface
	) as AABB
	var surface_origin_id: StringName = StringName(diagnostics.get(
		"surface_origin_id",
		StringName()
	))
	var root_origin_id: StringName = StringName(anatomy.get(
		"index_point_world_origin_id",
		StringName()
	))
	var sample_zero: Dictionary = solver.call(
		"_evaluate_candidate",
		prepared_surface,
		surface_bounds,
		Basis.IDENTITY,
		Vector3.ZERO,
		stations.get("grip_pivot_c0_world", Vector3.ZERO) as Vector3,
		stations.get("index_slice_center_ci_world", Vector3.ZERO) as Vector3,
		stations.get("pinky_slice_center_cp_world", Vector3.ZERO) as Vector3,
		stations.get("endcap_axis_world", Vector3.ZERO) as Vector3,
		anatomy.get("index_point_world", Vector3.ZERO) as Vector3,
		anatomy.get("pinky_point_world", Vector3.ZERO) as Vector3,
		anatomy.get("index_authorized_closing_direction_world", Vector3.ZERO) as Vector3,
		anatomy.get("pinky_authorized_closing_direction_world", Vector3.ZERO) as Vector3,
		float(anatomy.get("index_skin_to_bone_radius_meters", 0.0)),
		float(anatomy.get("pinky_skin_to_bone_radius_meters", 0.0)),
		anatomy.get("ordinary_proximal_capsules", []) as Array,
		true,
		StringName(anatomy.get("index_point_source_origin_id", StringName())),
		StringName(anatomy.get("pinky_point_source_origin_id", StringName())),
		surface_origin_id,
		root_origin_id,
		0
	) as Dictionary
	print(
		" PRIMARY_FIRST_SAMPLE0 valid=", sample_zero.get("valid", false),
		" accepted=", sample_zero.get("accepted", false),
		" basis=", sample_zero.get("weapon_correction_basis_world", Basis.IDENTITY),
		" index_target=", sample_zero.get("index_target_point_world", Vector3.ZERO),
		" pinky_target=", sample_zero.get("pinky_target_point_world", Vector3.ZERO),
		" index_boundary=", sample_zero.get("index_handle_boundary_point_world", Vector3.ZERO),
		" pinky_boundary=", sample_zero.get("pinky_handle_boundary_point_world", Vector3.ZERO),
		" index_error=", sample_zero.get("index_radial_error_meters", INF),
		" pinky_error=", sample_zero.get("pinky_radial_error_meters", INF),
		" index_close_dot=", sample_zero.get("index_radial_closing_side_dot", INF),
		" pinky_close_dot=", sample_zero.get("pinky_radial_closing_side_dot", INF),
		" flipped=[", sample_zero.get("index_radial_side_flipped_for_closing_authority", false),
		",", sample_zero.get("pinky_radial_side_flipped_for_closing_authority", false), "]",
		" ordinary_safe=", sample_zero.get("ordinary_proximal_capsules_safe", false),
		" worst=", sample_zero.get("ordinary_proximal_worst_digit_id", StringName()),
		" worst_pen=", sample_zero.get("ordinary_proximal_worst_penetration_meters", -1)
	)
	var diagnostic_anatomy: Dictionary = anatomy.duplicate(true)
	diagnostic_anatomy["enforce_ordinary_proximal_safety"] = true
	diagnostic_anatomy["allow_transaction_provisional_candidate"] = true
	var diagnostic_result: Dictionary = solver.call(
		"solve_prepared",
		prepared_surface,
		diagnostic_anatomy,
		stations.get("grip_pivot_c0_world", Vector3.ZERO) as Vector3,
		stations.get("index_slice_center_ci_world", Vector3.ZERO) as Vector3,
		stations.get("pinky_slice_center_cp_world", Vector3.ZERO) as Vector3,
		stations.get("endcap_axis_world", Vector3.ZERO) as Vector3,
		surface_origin_id,
		root_origin_id
	) as Dictionary
	var candidate_basis: Basis = diagnostic_result.get(
		"candidate_weapon_correction_basis_world",
		diagnostic_result.get(
			"provisional_weapon_correction_basis_world",
			Basis.IDENTITY
		)
	) as Basis
	var candidate_translation: Vector3 = diagnostic_result.get(
		"candidate_weapon_radial_translation_world",
		diagnostic_result.get(
			"provisional_weapon_radial_translation_world",
			Vector3.ZERO
		)
	) as Vector3
	print(
		" PRIMARY_FIRST_BEST status=", diagnostic_result.get("status", StringName()),
		" accepted_sample=", diagnostic_result.get("candidate_sample_index", -1),
		" provisional_sample=", diagnostic_result.get("provisional_candidate_sample_index", -1),
		" basis=", candidate_basis,
		" rotation_deg=", rad_to_deg(
			candidate_basis.orthonormalized().get_rotation_quaternion().get_angle()
		),
		" translation=", candidate_translation,
		" diagnostics=", var_to_str(diagnostic_result.get("diagnostics", {}))
	)

func _frames(count: int) -> void:
	for _i: int in range(count):
		await process_frame
