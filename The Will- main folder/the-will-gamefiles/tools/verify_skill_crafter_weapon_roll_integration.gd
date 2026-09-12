extends SceneTree

const PlayerForgeWipLibraryStateScript = preload(
	"res://core/models/player_forge_wip_library_state.gd"
)
const CombatAnimationStationUIScene = preload(
	"res://scenes/ui/combat_animation_station_ui.tscn"
)
const CombatAnimationMotionNodeEditorScript = preload(
	"res://runtime/combat/combat_animation_motion_node_editor.gd"
)
const PlayerRigFingerGripPresenterScript = preload(
	"res://runtime/player/player_rig_finger_grip_presenter.gd"
)

const TARGET_PROJECT_NAME := "Star_Handle_Testing"
const TARGET_SLOT_ID: StringName = &"skill_slot_1"
const DOMINANT_SLOT_ID: StringName = &"hand_right"
const LEFT_SLOT_ID: StringName = &"hand_left"
const PREVIEW_ACTOR_PATH := "PreviewActorPivot/PreviewActor"
const PREVIEW_SKELETON_PATH := "JosieModel/Josie/Skeleton3D"
const DOMINANT_MACRO_BONES: Array[StringName] = [
	&"CC_Base_R_Clavicle",
	&"CC_Base_R_Upperarm",
	&"CC_Base_R_Forearm",
]
const DOMINANT_HAND_BONE: StringName = &"CC_Base_R_Hand"
const LEFT_HAND_BONE: StringName = &"CC_Base_L_Hand"
const DOMINANT_DIGIT_BONES: Array[StringName] = [
	&"CC_Base_R_Thumb1",
	&"CC_Base_R_Thumb2",
	&"CC_Base_R_Thumb3",
	&"CC_Base_R_Index1",
	&"CC_Base_R_Index2",
	&"CC_Base_R_Index3",
	&"CC_Base_R_Mid1",
	&"CC_Base_R_Mid2",
	&"CC_Base_R_Mid3",
	&"CC_Base_R_Ring1",
	&"CC_Base_R_Ring2",
	&"CC_Base_R_Ring3",
	&"CC_Base_R_Pinky1",
	&"CC_Base_R_Pinky2",
	&"CC_Base_R_Pinky3",
]
const SUPPORT_MACRO_BONES: Array[StringName] = [
	&"CC_Base_L_Clavicle",
	&"CC_Base_L_Upperarm",
	&"CC_Base_L_Forearm",
]
const SUPPORT_DIGIT_BONES: Array[StringName] = [
	&"CC_Base_L_Thumb1",
	&"CC_Base_L_Thumb2",
	&"CC_Base_L_Thumb3",
	&"CC_Base_L_Index1",
	&"CC_Base_L_Index2",
	&"CC_Base_L_Index3",
	&"CC_Base_L_Mid1",
	&"CC_Base_L_Mid2",
	&"CC_Base_L_Mid3",
	&"CC_Base_L_Ring1",
	&"CC_Base_L_Ring2",
	&"CC_Base_L_Ring3",
	&"CC_Base_L_Pinky1",
	&"CC_Base_L_Pinky2",
	&"CC_Base_L_Pinky3",
]
const POSE_POSITION_TOLERANCE_METERS := 0.000001
const POSE_ROTATION_TOLERANCE_RADIANS := 0.00001
const ENDPOINT_POSITION_TOLERANCE_METERS := 0.00001
const CONTACT_RELATIONSHIP_TOLERANCE_METERS := 0.0005
const CONTACT_RELATIONSHIP_ROTATION_TOLERANCE_DEGREES := 0.05
const ROLL_ANGLE_TOLERANCE_DEGREES := 0.2
const ROLL_SWING_TOLERANCE_DEGREES := 0.05


class FakePlayer:
	extends Node

	var ui_mode_enabled: bool = false
	var forge_wip_library_state: PlayerForgeWipLibraryState = null

	func get_forge_wip_library_state() -> PlayerForgeWipLibraryState:
		return forge_wip_library_state

	func set_ui_mode_enabled(enabled: bool) -> void:
		ui_mode_enabled = enabled


var failures: PackedStringArray = []


func _init() -> void:
	call_deferred("_run_verification")


func _run_verification() -> void:
	var source_library: PlayerForgeWipLibraryState = (
		PlayerForgeWipLibraryStateScript.load_or_create()
	)
	var source_wip: CraftedItemWIP = _find_saved_wip_by_project_name(
		source_library,
		TARGET_PROJECT_NAME
	)
	if source_wip == null:
		_fail_and_finish("target_wip_missing")
		return
	if "isolated-reset-only" in OS.get_cmdline_user_args():
		await _verify_isolated_primary_reset_with_recreated_ui(
			source_wip,
			LEFT_SLOT_ID
		)
		_finish()
		return
	var diagnostic_wip: CraftedItemWIP = source_wip.duplicate(true) as CraftedItemWIP
	if diagnostic_wip == null:
		_fail_and_finish("target_wip_duplicate_failed")
		return
	var diagnostic_library: PlayerForgeWipLibraryState = (
		PlayerForgeWipLibraryStateScript.new()
	)
	diagnostic_library.save_file_path = (
		"C:/WORKSPACE/test_artifacts/"
		+ "verify_skill_crafter_weapon_roll_integration_main_library.tres"
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
	ui.set_meta("verification_skip_persistence", true)
	root.add_child(ui)
	await _wait_frames(2)
	ui.open_for(fake_player, "Weapon Roll Integration Verification")
	await _wait_frames(2)
	_check(
		"saved_wip_opened",
		ui.open_saved_wip_with_hand_setup(
			diagnostic_wip.wip_id,
			DOMINANT_SLOT_ID,
			false,
			false
		)
	)
	await _wait_frames(2)
	_check("skill_slot_selected", ui.select_skill_slot(TARGET_SLOT_ID, true))
	await _wait_frames(2)
	# The saved fixture may open through its historical mount-seed continuation
	# without a committed surface packet. Reset is the public relationship solve
	# that the editor exposes to establish the active normal/reverse grip.
	_check("grip_relationship_seeded", ui.reset_active_draft_to_baseline())
	await _wait_frames(2)

	var motion_node: CombatAnimationMotionNode = ui.call(
		"_get_active_motion_node"
	) as CombatAnimationMotionNode
	var preview_root: Node3D = ui.preview_subviewport.get_node_or_null(
		"CombatAnimationPreviewRoot3D"
	) as Node3D
	var actor: Node3D = (
		preview_root.get_node_or_null(PREVIEW_ACTOR_PATH) as Node3D
		if preview_root != null
		else null
	)
	var skeleton: Skeleton3D = (
		actor.get_node_or_null(PREVIEW_SKELETON_PATH) as Skeleton3D
		if actor != null
		else null
	)
	var held_item: Node3D = (
		preview_root.get_meta("preview_held_item", null) as Node3D
		if preview_root != null
		else null
	)
	_check("active_motion_node_available", motion_node != null)
	_check("preview_actor_available", actor != null)
	_check("preview_skeleton_available", skeleton != null)
	_check("preview_weapon_available", held_item != null)
	if motion_node == null or actor == null or skeleton == null or held_item == null:
		_finish()
		return
	var right_positive_zero_ready: bool = true
	if not is_zero_approx(motion_node.weapon_roll_degrees):
		right_positive_zero_ready = ui.set_selected_motion_node_weapon_roll(
			0.0,
			false,
			false,
			true,
			true,
			false
		)
		await _wait_frames(1)
		motion_node = ui.call("_get_active_motion_node") as CombatAnimationMotionNode
	_check("right_primary_positive_zero_ready", right_positive_zero_ready)
	if motion_node == null:
		_finish()
		return

	var macro_before: Dictionary = _capture_bone_poses(skeleton, DOMINANT_MACRO_BONES)
	var hand_before: Dictionary = _capture_bone_poses(
		skeleton,
		[DOMINANT_HAND_BONE]
	)
	var digits_before: Dictionary = _capture_bone_poses(
		skeleton,
		DOMINANT_DIGIT_BONES
	)
	var weapon_before: Transform3D = held_item.global_transform
	var weapon_tip_local: Vector3 = held_item.get_meta(
		"weapon_tip_local",
		Vector3.INF
	) as Vector3
	var weapon_pommel_local: Vector3 = held_item.get_meta(
		"weapon_pommel_local",
		Vector3.INF
	) as Vector3
	var dominant_contact_before: Dictionary = _capture_hand_contact_weapon_local(
		actor,
		held_item,
		DOMINANT_SLOT_ID
	)
	var seat_before: Dictionary = actor.call(
		"get_authoring_committed_weapon_surface_seat",
		DOMINANT_SLOT_ID
	) as Dictionary
	var seat_debug_before: Dictionary = actor.call(
		"get_weapon_surface_seat_debug_state",
		DOMINANT_SLOT_ID
	) as Dictionary
	_check("committed_surface_seat_available", bool(seat_before.get("valid", false)))
	var right_relationship_before_roll: Dictionary = _capture_surface_relationship_debug(
		actor,
		held_item,
		DOMINANT_SLOT_ID
	)
	print("right_primary_relationship_before_roll=%s" % var_to_str(
		right_relationship_before_roll
	))
	var right_seat_context_transition: Dictionary = (
		_capture_surface_seat_context_transition(
			actor,
			held_item,
			DOMINANT_SLOT_ID
		)
	)
	print("right_primary_seat_context_transition=%s" % var_to_str(
		right_seat_context_transition
	))
	if "seat-context-only" in OS.get_cmdline_user_args():
		_check(
			"right_primary_seat_context_transition_available",
			bool(right_seat_context_transition.get("valid", false))
		)
		_finish()
		return
	_check(
		"right_primary_current_packet_available_before_roll",
		_surface_relationship_has_current_packet(right_relationship_before_roll)
	)
	print("initial_roll_contact_result=%s" % var_to_str(preview_root.get_meta(
		"weapon_roll_contact_result",
		{}
	)))
	print("initial_dominant_grip_error=%s" % str(float(
		ui.get_preview_debug_state().get("dominant_grip_alignment_error_meters", -1.0)
	)))
	if (
		"support-transaction-only" in OS.get_cmdline_user_args()
		and "support-skip-roll" in OS.get_cmdline_user_args()
	):
		await _verify_staged_support_activation(ui)
		_finish()
		return

	var initial_roll: float = motion_node.weapon_roll_degrees
	var requested_roll: float = clampf(
		20.0,
		CombatAnimationMotionNodeEditorScript.WEAPON_ROLL_MIN_DEGREES,
		CombatAnimationMotionNodeEditorScript.WEAPON_ROLL_MAX_DEGREES
	)
	ui.call(
		"_begin_preview_drag_override",
		motion_node,
		CombatAnimationMotionNodeEditorScript.DRAG_TARGET_WEAPON_ROTATION
	)
	ui.motion_node_editor.begin_drag(
		CombatAnimationMotionNodeEditorScript.DRAG_TARGET_WEAPON_ROTATION,
		Vector2.ZERO,
		motion_node
	)
	var drag_motion_node: CombatAnimationMotionNode = (
		ui.preview_drag_override_node as CombatAnimationMotionNode
	)
	_check("roll_drag_override_available", drag_motion_node != null)
	if drag_motion_node == null:
		_finish()
		return
	drag_motion_node.weapon_roll_degrees = requested_roll
	drag_motion_node.normalize()
	ui.preview_drag_has_moved = true
	ui.call("_refresh_preview_scene")
	var macro_during_drag: Dictionary = _capture_bone_poses(
		skeleton,
		DOMINANT_MACRO_BONES
	)
	_check(
		"dominant_macro_pose_preserved_during_roll_drag",
		_bone_pose_maps_match(macro_before, macro_during_drag)
	)

	ui.motion_node_editor.end_drag()
	ui.call("_finalize_preview_drag", "Weapon Roll verifier settled.")
	var committed_motion_node: CombatAnimationMotionNode = ui.call(
		"_get_active_motion_node"
	) as CombatAnimationMotionNode
	var macro_after_release: Dictionary = _capture_bone_poses(
		skeleton,
		DOMINANT_MACRO_BONES
	)
	var hand_after_release: Dictionary = _capture_bone_poses(
		skeleton,
		[DOMINANT_HAND_BONE]
	)
	var digits_after_release: Dictionary = _capture_bone_poses(
		skeleton,
		DOMINANT_DIGIT_BONES
	)
	var weapon_after_release: Transform3D = held_item.global_transform
	var seat_after: Dictionary = actor.call(
		"get_authoring_committed_weapon_surface_seat",
		DOMINANT_SLOT_ID
	) as Dictionary
	var seat_debug_after: Dictionary = actor.call(
		"get_weapon_surface_seat_debug_state",
		DOMINANT_SLOT_ID
	) as Dictionary
	var right_relationship_after_roll: Dictionary = _capture_surface_relationship_debug(
		actor,
		held_item,
		DOMINANT_SLOT_ID
	)
	print("right_primary_relationship_after_roll=%s" % var_to_str(
		right_relationship_after_roll
	))
	_check(
		"right_primary_current_packet_available_after_roll",
		_surface_relationship_has_current_packet(right_relationship_after_roll)
	)
	print("released_dominant_grip_error=%s" % str(float(
		ui.get_preview_debug_state().get("dominant_grip_alignment_error_meters", -1.0)
	)))
	_check(
		"roll_scalar_committed",
		committed_motion_node != null
		and is_equal_approx(committed_motion_node.weapon_roll_degrees, requested_roll)
	)
	_check(
		"roll_panel_tracks_committed_scalar",
		ui.weapon_roll_spin_box != null
		and is_equal_approx(ui.weapon_roll_spin_box.value, requested_roll)
	)
	_check(
		"dominant_macro_pose_preserved_after_roll_release",
		_bone_pose_maps_match(macro_before, macro_after_release)
	)
	_check(
		"dominant_hand_follows_weapon_roll",
		not _bone_pose_maps_match(hand_before, hand_after_release)
	)
	print(
		"dominant_hand_roll_delta_degrees=%.6f requested_delta_degrees=%.6f" % [
			_pose_rotation_delta_degrees(
				hand_before,
				hand_after_release,
				DOMINANT_HAND_BONE
			),
			absf(requested_roll - initial_roll),
		]
	)
	_check(
		"dominant_hand_roll_is_one_to_one",
		absf(
			_pose_rotation_delta_degrees(
				hand_before,
				hand_after_release,
				DOMINANT_HAND_BONE
			)
			- absf(requested_roll - initial_roll)
		) <= 1.0
	)
	_check(
		"dominant_digit_curl_packet_preserved",
		_bone_pose_maps_match(digits_before, digits_after_release)
	)
	_check(
		"weapon_basis_changed",
		_basis_rotation_delta(weapon_before.basis, weapon_after_release.basis) > 0.01
	)
	_verify_signed_axis_roll_and_endpoints(
		"right_primary_positive",
		weapon_before,
		weapon_after_release,
		weapon_tip_local,
		weapon_pommel_local,
		requested_roll - initial_roll
	)
	_check_contact_relationship_preserved(
		"right_primary_positive",
		dominant_contact_before,
		_capture_hand_contact_weapon_local(actor, held_item, DOMINANT_SLOT_ID)
	)
	_check(
		"committed_surface_seat_unchanged",
		_surface_seat_matches(seat_before, seat_after)
	)
	_check(
		"roll_reuses_surface_seat_without_resolve",
		int(seat_debug_before.get("solve_count", -1))
			== int(seat_debug_after.get("solve_count", -2))
		and int(seat_debug_before.get("surface_geometry_load_count", -1))
			== int(seat_debug_after.get("surface_geometry_load_count", -2))
	)
	var grip_debug_after: Dictionary = actor.call(
		"get_grip_contact_debug_state"
	) as Dictionary
	_check(
		"dominant_twist_helpers_neutralized",
		not bool(grip_debug_after.get(
			"right_authoring_twist_distribution_active",
			true
		))
		and absf(float(grip_debug_after.get(
			"right_authoring_twist_requested_degrees",
			INF
		))) <= 0.01
	)
	if "support-transaction-only" in OS.get_cmdline_user_args():
		if "support-roll-roundtrip-zero" in OS.get_cmdline_user_args():
			var roundtrip_zero_applied: bool = (
				ui.set_selected_motion_node_weapon_roll(
					initial_roll,
					false,
					false,
					true,
					true,
					false
				)
			)
			await _wait_frames(1)
			var roundtrip_motion_node: CombatAnimationMotionNode = ui.call(
				"_get_active_motion_node"
			) as CombatAnimationMotionNode
			_check(
				"support_roll_roundtrip_zero_applied",
				roundtrip_zero_applied
			)
			_check(
				"support_roll_roundtrip_scalar_restored",
				roundtrip_motion_node != null
				and is_equal_approx(
					roundtrip_motion_node.weapon_roll_degrees,
					initial_roll
				)
			)
			_check_transform_stable(
				"support_roll_roundtrip_weapon",
				weapon_before,
				held_item.global_transform
			)
			_print_pose_map_deltas(
				"support_roll_roundtrip_primary_macro_delta",
				macro_before,
				_capture_bone_poses(skeleton, DOMINANT_MACRO_BONES)
			)
			_check(
				"support_roll_roundtrip_primary_macro_restored",
				_bone_pose_maps_match(
					macro_before,
					_capture_bone_poses(skeleton, DOMINANT_MACRO_BONES)
				)
			)
			_print_pose_map_deltas(
				"support_roll_roundtrip_primary_hand_delta",
				hand_before,
				_capture_bone_poses(skeleton, [DOMINANT_HAND_BONE])
			)
			_check(
				"support_roll_roundtrip_primary_hand_restored",
				_bone_pose_maps_match(
					hand_before,
					_capture_bone_poses(skeleton, [DOMINANT_HAND_BONE])
				)
			)
			_check(
				"support_roll_roundtrip_primary_digits_restored",
				_bone_pose_maps_match(
					digits_before,
					_capture_bone_poses(skeleton, DOMINANT_DIGIT_BONES)
				)
			)
			_check_contact_relationship_preserved(
				"support_roll_roundtrip_primary_contact",
				dominant_contact_before,
				_capture_hand_contact_weapon_local(
					actor,
					held_item,
					DOMINANT_SLOT_ID
				)
			)
			var roundtrip_relationship: Dictionary = (
				_capture_surface_relationship_debug(
					actor,
					held_item,
					DOMINANT_SLOT_ID
				)
			)
			print("support_roll_roundtrip_primary_relationship=%s" % var_to_str(
				roundtrip_relationship
			))
			_check(
				"support_roll_roundtrip_primary_packet_current",
				_surface_relationship_has_current_packet(
					roundtrip_relationship
				)
			)
		await _verify_staged_support_activation(ui)
		_finish()
		return

	var macro_before_generic_refresh: Dictionary = _capture_bone_poses(
		skeleton,
		DOMINANT_MACRO_BONES
	)
	ui.call("_refresh_preview_scene")
	var macro_after_generic_refresh: Dictionary = _capture_bone_poses(
		skeleton,
		DOMINANT_MACRO_BONES
	)
	_check(
		"committed_roll_survives_later_refresh",
		_bone_pose_maps_match(
			macro_before_generic_refresh,
			macro_after_generic_refresh
		)
	)
	_check(
		"right_negative_wip_reopened",
		ui.open_saved_wip_with_hand_setup(
			diagnostic_wip.wip_id,
			DOMINANT_SLOT_ID,
			false,
			false
		)
	)
	await _wait_frames(2)
	_check(
		"right_negative_skill_slot_selected",
		ui.select_skill_slot(TARGET_SLOT_ID, true)
	)
	await _wait_frames(2)
	_check(
		"right_negative_grip_relationship_seeded",
		ui.reset_active_draft_to_baseline()
	)
	await _wait_frames(2)
	preview_root = ui.preview_subviewport.get_node_or_null(
		"CombatAnimationPreviewRoot3D"
	) as Node3D
	actor = (
		preview_root.get_node_or_null(PREVIEW_ACTOR_PATH) as Node3D
		if preview_root != null
		else null
	)
	skeleton = (
		actor.get_node_or_null(PREVIEW_SKELETON_PATH) as Skeleton3D
		if actor != null
		else null
	)
	held_item = (
		preview_root.get_meta("preview_held_item", null) as Node3D
		if preview_root != null
		else null
	)
	var right_negative_context_available: bool = (
		actor != null and skeleton != null and held_item != null
	)
	_check(
		"right_negative_preview_context_available",
		right_negative_context_available
	)
	if right_negative_context_available:
		await _verify_signed_roll_from_zero(
			ui,
			actor,
			skeleton,
			held_item,
			DOMINANT_SLOT_ID,
			DOMINANT_HAND_BONE,
			DOMINANT_MACRO_BONES,
			DOMINANT_DIGIT_BONES,
			-20.0,
			"right_primary_negative"
		)
	await _verify_two_hand_roll(ui, diagnostic_wip.wip_id)
	await _verify_left_primary_roll(ui, diagnostic_wip.wip_id)
	await _verify_keyless_recreated_ui_reopen(ui)
	_finish()


func _verify_staged_support_activation(ui: CombatAnimationStationUI) -> void:
	var requested_support_coordinate: float = INF
	if "support-coordinate-half" in OS.get_cmdline_user_args():
		requested_support_coordinate = 0.5
	elif "support-coordinate-six-tenths" in OS.get_cmdline_user_args():
		requested_support_coordinate = 0.6
	elif "support-positive-coordinate" in OS.get_cmdline_user_args():
		requested_support_coordinate = 0.2
	if is_finite(requested_support_coordinate):
		var support_motion_node: CombatAnimationMotionNode = ui.call(
			"_get_active_motion_node"
		) as CombatAnimationMotionNode
		var support_coordinate_ready := false
		if support_motion_node != null:
			support_coordinate_ready = is_equal_approx(
				support_motion_node.secondary_grip_seat_slide_offset,
				requested_support_coordinate
			) or ui.set_selected_motion_node_secondary_grip_seat_slide(
				requested_support_coordinate,
				false,
				false,
				false,
				false,
				false
			)
		_check(
			"staged_support_positive_coordinate_ready",
			support_coordinate_ready
		)
	var preview_root: Node3D = ui.preview_subviewport.get_node_or_null(
		"CombatAnimationPreviewRoot3D"
	) as Node3D
	var actor: Node3D = (
		preview_root.get_node_or_null(PREVIEW_ACTOR_PATH) as Node3D
		if preview_root != null
		else null
	)
	var skeleton: Skeleton3D = (
		actor.get_node_or_null(PREVIEW_SKELETON_PATH) as Skeleton3D
		if actor != null
		else null
	)
	var held_item: Node3D = (
		preview_root.get_meta("preview_held_item", null) as Node3D
		if preview_root != null
		else null
	)
	_check("staged_support_source_actor_available", actor != null)
	_check("staged_support_source_skeleton_available", skeleton != null)
	_check("staged_support_source_weapon_available", held_item != null)
	if actor == null or skeleton == null or held_item == null:
		return
	var weapon_before: Transform3D = held_item.global_transform
	var primary_macro_before: Dictionary = _capture_bone_poses(
		skeleton,
		DOMINANT_MACRO_BONES
	)
	var primary_contact_before: Dictionary = _capture_hand_contact_weapon_local(
		actor,
		held_item,
		DOMINANT_SLOT_ID
	)
	var primary_relationship_before: Dictionary = (
		_capture_surface_relationship_debug(
			actor,
			held_item,
			DOMINANT_SLOT_ID
		)
	)
	_check(
		"staged_support_primary_packet_available_before_activation",
		_surface_relationship_has_current_packet(primary_relationship_before)
	)
	var activation_requested: bool = ui.set_selected_motion_node_two_hand_state(
		&"two_hand_two_hand",
		false,
		false,
		false,
		true,
		false
	)
	_check("staged_support_activation_requested", activation_requested)
	var immediate_preview_root: Node3D = ui.preview_subviewport.get_node_or_null(
		"CombatAnimationPreviewRoot3D"
	) as Node3D
	var immediate_held_item: Node3D = (
		immediate_preview_root.get_meta("preview_held_item", null) as Node3D
		if immediate_preview_root != null
		else null
	)
	var support_transaction_result: Dictionary = {}
	print("staged_support_instance_ids_before_immediate=%s/%s/%s/%s" % [
		preview_root.get_instance_id(),
		held_item.get_instance_id(),
		immediate_preview_root.get_instance_id() if immediate_preview_root != null else 0,
		immediate_held_item.get_instance_id() if immediate_held_item != null else 0,
	])
	if immediate_preview_root != null:
		var gate_state: Dictionary = immediate_preview_root.get_meta(
			"support_activation_gate_state",
			{}
		) as Dictionary
		print("staged_support_activation_gate=was:%s,requested:%s,seat_changed:%s,relationship_changed:%s,ratio:%s->%s,seat:%s,grasp:%s,solve:%s,drag:%s,fixed:%s" % [
			str(bool(gate_state.get("support_was_active", false))),
			str(bool(gate_state.get("support_requested", false))),
			str(bool(gate_state.get("support_seat_changed", false))),
			str(bool(gate_state.get("support_relationship_changed", false))),
			str(float(gate_state.get("support_ratio_before", INF))),
			str(float(gate_state.get("support_ratio_after", INF))),
			str(bool(gate_state.get("primary_seat_current", false))),
			str(bool(gate_state.get("primary_grasp_current", false))),
			str(bool(gate_state.get("allow_exact_surface_solve", false))),
			str(bool(gate_state.get("authoring_drag_active", false))),
			str(bool(gate_state.get(
				"resolve_fixed_primary_unit",
				gate_state.get("activate_fixed_primary_unit", false)
			))),
		])
		support_transaction_result = immediate_preview_root.get_meta(
			"support_grip_transaction_result",
			{}
		) as Dictionary
		print("staged_support_root_transaction=status:%s,valid:%s,applied:%s,committed:%s,corrections:%s,digits:%s" % [
			String(support_transaction_result.get("status", StringName())),
			str(bool(support_transaction_result.get("valid", false))),
			str(bool(support_transaction_result.get("applied", false))),
			str(bool(support_transaction_result.get("committed", false))),
			str(int(support_transaction_result.get("applied_correction_count", -1))),
			str(bool(support_transaction_result.get("support_digit_packet_committed", false))),
		])
		_print_compact_support_transaction_passes(
			support_transaction_result.get("transaction_passes", []) as Array
		)
	# The failed Support transaction restores the presenter's active packet state,
	# but the guide retains the solver diagnostics published immediately before
	# rollback. Capture that live publication before any verifier probe can replace
	# it, so a rejected digit packet is measured at the exact transaction seat.
	var support_transaction_grasp_diagnostics: Dictionary = {}
	if immediate_held_item != null:
		var immediate_secondary_guide: Node3D = immediate_held_item.get_node_or_null(
			"SecondaryGripGuide"
		) as Node3D
		if immediate_secondary_guide != null:
			support_transaction_grasp_diagnostics = (
				immediate_secondary_guide.get_meta(
					"finger_surface_grasp_diagnostics",
					{}
				) as Dictionary
			).duplicate(true)
	_print_raw_digit_solver_diagnostics(
		"staged_support_transaction_live_digit_solver",
		support_transaction_grasp_diagnostics
	)
	if immediate_held_item != null:
		print("staged_support_transaction_immediate=%s" % var_to_str(
			immediate_held_item.get_meta(
				"preview_support_hand_surface_seat_state",
				{}
			)
		))
		print("staged_support_transaction_immediate_present=%s" % str(
			immediate_held_item.has_meta(
				"preview_support_hand_surface_seat_state"
			)
		))
		print("staged_support_relationship_key_immediate=%s" % String(
			immediate_held_item.get_meta(
				"preview_support_grip_relationship_key",
				""
			)
		))
		_print_compact_primary_seat_state(
			"staged_support_primary_seat_immediate",
			immediate_held_item.get_meta("weapon_surface_seat_state", {}) as Dictionary
		)
	var immediate_actor: Node3D = (
		immediate_preview_root.get_node_or_null(PREVIEW_ACTOR_PATH) as Node3D
		if immediate_preview_root != null
		else null
	)
	if immediate_actor != null and immediate_actor.has_method("is_support_hand_active"):
		print("staged_support_active_immediate=right:%s,left:%s" % [
			str(bool(immediate_actor.call("is_support_hand_active", DOMINANT_SLOT_ID))),
			str(bool(immediate_actor.call("is_support_hand_active", LEFT_SLOT_ID))),
		])
	await _wait_frames(2)
	preview_root = ui.preview_subviewport.get_node_or_null(
		"CombatAnimationPreviewRoot3D"
	) as Node3D
	var actor_after: Node3D = (
		preview_root.get_node_or_null(PREVIEW_ACTOR_PATH) as Node3D
		if preview_root != null
		else null
	)
	var skeleton_after: Skeleton3D = (
		actor_after.get_node_or_null(PREVIEW_SKELETON_PATH) as Skeleton3D
		if actor_after != null
		else null
	)
	var held_item_after: Node3D = (
		preview_root.get_meta("preview_held_item", null) as Node3D
		if preview_root != null
		else null
	)
	_check("staged_support_actor_available_after_activation", actor_after != null)
	_check(
		"staged_support_skeleton_available_after_activation",
		skeleton_after != null
	)
	_check(
		"staged_support_weapon_available_after_activation",
		held_item_after != null
	)
	if actor_after == null or skeleton_after == null or held_item_after == null:
		return
	var support_relationship_after: Dictionary = (
		_capture_surface_relationship_debug(
			actor_after,
			held_item_after,
			LEFT_SLOT_ID
		)
	)
	var primary_relationship_after: Dictionary = (
		_capture_surface_relationship_debug(
			actor_after,
			held_item_after,
			DOMINANT_SLOT_ID
		)
	)
	print("staged_support_transaction_result=%s" % var_to_str(
		held_item_after.get_meta(
			"preview_support_hand_surface_seat_state",
			{}
		)
	))
	print("staged_support_instance_ids_after=%s/%s" % [
		preview_root.get_instance_id(),
		held_item_after.get_instance_id(),
	])
	print("staged_support_transaction_after_present=%s" % str(
		held_item_after.has_meta("preview_support_hand_surface_seat_state")
	))
	_print_compact_primary_seat_state(
		"staged_support_primary_seat_after",
		held_item_after.get_meta("weapon_surface_seat_state", {}) as Dictionary
	)
	if actor_after.has_method("is_support_hand_active"):
		print("staged_support_active_after=right:%s,left:%s" % [
			str(bool(actor_after.call("is_support_hand_active", DOMINANT_SLOT_ID))),
			str(bool(actor_after.call("is_support_hand_active", LEFT_SLOT_ID))),
		])
	print("staged_support_primary_relationship_after=%s" % var_to_str(
		primary_relationship_after
	))
	print("staged_support_relationship_after=%s" % var_to_str(
		support_relationship_after
	))
	_print_pose_map_deltas(
		"staged_support_primary_macro_delta",
		primary_macro_before,
		_capture_bone_poses(skeleton_after, DOMINANT_MACRO_BONES)
	)
	_check_transform_stable(
		"staged_support_primary_weapon_unit",
		weapon_before,
		held_item_after.global_transform
	)
	_check(
		"staged_support_primary_macro_preserved",
		_bone_pose_maps_match(
			primary_macro_before,
			_capture_bone_poses(skeleton_after, DOMINANT_MACRO_BONES)
		)
	)
	_check_contact_relationship_preserved(
		"staged_support_primary_contact",
		primary_contact_before,
		_capture_hand_contact_weapon_local(
			actor_after,
			held_item_after,
			DOMINANT_SLOT_ID
		)
	)
	_check(
		"staged_support_primary_packet_preserved",
		_surface_relationship_has_current_packet(primary_relationship_after)
	)
	_check(
		"staged_support_packet_committed",
		_surface_relationship_has_current_packet(support_relationship_after)
	)
	_check(
		"staged_support_transaction_committed",
		not support_transaction_result.is_empty()
		and bool(support_transaction_result.get("valid", false))
		and bool(support_transaction_result.get("applied", false))
		and bool(support_transaction_result.get("committed", false))
		and bool(support_transaction_result.get(
			"support_digit_packet_committed",
			false
		))
	)
	if "support-proximal-comparison" in OS.get_cmdline_user_args():
		_run_support_proximal_safety_comparison(
			ui,
			actor_after,
			skeleton_after,
			held_item_after,
			LEFT_SLOT_ID,
			support_transaction_result
		)
		if "support-skip-left-reference" not in OS.get_cmdline_user_args():
			await _verify_left_primary_digit_solver_reference(
				ui,
				StringName(held_item_after.get_meta(
					"source_wip_id",
					StringName()
				))
			)


func _run_support_proximal_safety_comparison(
	ui: CombatAnimationStationUI,
	actor: Node3D,
	skeleton: Skeleton3D,
	held_item: Node3D,
	support_slot_id: StringName,
	transaction_result: Dictionary
) -> void:
	var secondary_guide: Node3D = held_item.get_node_or_null(
		"SecondaryGripGuide"
	) as Node3D
	if (
		secondary_guide == null
		or not actor.has_method("resolve_hand_surface_seat_anatomy_state")
	):
		print("support_proximal_comparison=unavailable")
		return
	var anatomy_state: Dictionary = actor.call(
		"resolve_hand_surface_seat_anatomy_state",
		support_slot_id
	) as Dictionary
	if not bool(anatomy_state.get("valid", false)):
		print("support_proximal_comparison=anatomy_invalid:%s" % String(
			anatomy_state.get("status", StringName())
		))
		return
	var execution_path_id: StringName = (
		&"right_support"
		if support_slot_id == DOMINANT_SLOT_ID
		else &"left_support"
	)
	var enforced_presenter: RefCounted = PlayerRigFingerGripPresenterScript.new()
	var unenforced_presenter: RefCounted = PlayerRigFingerGripPresenterScript.new()
	var enforced_result: Dictionary = enforced_presenter.call(
		"_resolve_exact_surface_weapon_seat_for_path",
		skeleton,
		support_slot_id,
		secondary_guide,
		anatomy_state.duplicate(true),
		true,
		execution_path_id,
		true
	) as Dictionary
	var unenforced_result: Dictionary = unenforced_presenter.call(
		"_resolve_exact_surface_weapon_seat_for_path",
		skeleton,
		support_slot_id,
		secondary_guide,
		anatomy_state.duplicate(true),
		true,
		execution_path_id,
		false
	) as Dictionary
	_print_compact_proximal_comparison_seat("enforced", enforced_result)
	_print_compact_proximal_comparison_seat("unenforced", unenforced_result)
	print("support_proximal_comparison=same_context:%s" % str(
		String(enforced_result.get("context_key", ""))
			== String(unenforced_result.get("context_key", ""))
	))
	var preview_presenter: Object = ui.get("preview_presenter") as Object
	var support_anchor: Node3D = held_item.get_node_or_null(
		"SupportGripAnchor"
	) as Node3D
	var replay_snapshot: Dictionary = {}
	var replayed_failed_transaction: bool = false
	if (
		not bool(transaction_result.get("committed", false))
		and int(transaction_result.get("applied_correction_count", 0)) > 0
		and preview_presenter != null
		and support_anchor != null
		and preview_presenter.has_method(
			"_capture_preview_support_grip_transaction_snapshot"
		)
		and preview_presenter.has_method(
			"_resolve_preview_support_committed_accumulator"
		)
		and preview_presenter.has_method(
			"_compose_preview_support_grip_anchor_from_accumulator"
		)
	):
		replay_snapshot = preview_presenter.call(
			"_capture_preview_support_grip_transaction_snapshot",
			actor,
			held_item,
			support_anchor,
			support_slot_id,
			DOMINANT_SLOT_ID
		) as Dictionary
		var relationship_key: String = String(held_item.get_meta(
			"preview_support_grip_relationship_key",
			""
		))
		var accumulator: Transform3D = preview_presenter.call(
			"_resolve_preview_support_committed_accumulator",
			support_anchor,
			relationship_key
		) as Transform3D
		var passes: Array = transaction_result.get("transaction_passes", []) as Array
		var correction_count: int = mini(
			int(transaction_result.get("applied_correction_count", 0)),
			passes.size()
		)
		for pass_index: int in range(correction_count):
			var pass_state: Dictionary = passes[pass_index] as Dictionary
			var correction_local: Transform3D = pass_state.get(
				"correction_local",
				Transform3D.IDENTITY
			) as Transform3D
			accumulator = correction_local.affine_inverse() * accumulator
		replayed_failed_transaction = (
			bool(replay_snapshot.get("valid", false))
			and bool(preview_presenter.call(
				"_compose_preview_support_grip_anchor_from_accumulator",
				held_item,
				accumulator
			))
		)
		var equipped_item_presenter: Object = preview_presenter.get(
			"equipped_item_presenter"
		) as Object
		if replayed_failed_transaction and equipped_item_presenter != null:
			equipped_item_presenter.call(
				"sync_single_weapon_contact_guidance",
				actor,
				held_item,
				DOMINANT_SLOT_ID,
				true,
				true,
				true,
				true,
				true
			)
			if actor.has_method("settle_authoring_support_grip_macro_pose_now"):
				actor.call("settle_authoring_support_grip_macro_pose_now", 0.00025)
			anatomy_state = actor.call(
				"resolve_hand_surface_seat_anatomy_state",
				support_slot_id
			) as Dictionary
			var replay_presenter: RefCounted = (
				PlayerRigFingerGripPresenterScript.new()
			)
			unenforced_result = replay_presenter.call(
				"_resolve_exact_surface_weapon_seat_for_path",
				skeleton,
				support_slot_id,
				secondary_guide,
				anatomy_state.duplicate(true),
				true,
				execution_path_id,
				false
			) as Dictionary
			_print_compact_proximal_comparison_seat(
				"replayed_unenforced",
				unenforced_result
			)
		print("support_proximal_comparison=replayed_failed_transaction:%s" % str(
			replayed_failed_transaction
		))

	# The shared 15-bone solver receives the already seated live relationship; it
	# does not consume the pre-seat proximal flag. Only run this probe when the
	# unenforced seat proves that no additional weapon/support-anchor mutation is
	# required, so the result isolates the downstream safety authority itself.
	var unenforced_correction: Transform3D = unenforced_result.get(
		"seat_correction_grip_local",
		Transform3D.IDENTITY
	) as Transform3D
	var unenforced_identity: bool = (
		bool(unenforced_result.get("valid", false))
		and int(unenforced_result.get("candidate_sample_index", -1)) == 0
		and unenforced_correction.origin.length()
			<= POSE_POSITION_TOLERANCE_METERS
		and _basis_rotation_delta(
			Basis.IDENTITY,
			unenforced_correction.basis
		) <= POSE_ROTATION_TOLERANCE_RADIANS
	)
	print("support_proximal_comparison=unenforced_identity:%s" % str(
		unenforced_identity
	))
	_print_support_macro_reach_debug(
		actor,
		"replayed" if replayed_failed_transaction else "committed"
	)
	if (
		not unenforced_identity
		or not actor.has_method("capture_authoring_active_grip_transaction_state")
		or not actor.has_method("restore_authoring_active_grip_transaction_state")
		or not actor.has_method("invalidate_authoring_active_surface_grasp")
		or not actor.has_method("apply_authoring_digit_grip_slot_now")
	):
		_restore_support_proximal_replay_if_needed(
			preview_presenter,
			actor,
			held_item,
			support_anchor,
			support_slot_id,
			replay_snapshot,
			replayed_failed_transaction
		)
		return
	var grip_state_snapshot: Dictionary = {}
	var digit_pose_snapshot: Dictionary = {}
	if not replayed_failed_transaction:
		grip_state_snapshot = actor.call(
			"capture_authoring_active_grip_transaction_state",
			support_slot_id
		) as Dictionary
		digit_pose_snapshot = _capture_bone_poses(
			skeleton,
			SUPPORT_DIGIT_BONES
		)
	actor.call("invalidate_authoring_active_surface_grasp", support_slot_id)
	var digit_packet_committed: bool = bool(actor.call(
		"apply_authoring_digit_grip_slot_now",
		support_slot_id,
		true
	))
	var digit_result: Dictionary = _capture_surface_relationship_debug(
		actor,
		held_item,
		support_slot_id
	)
	_print_compact_digit_solver_result(
		"support_unenforced_seat_digit_solver",
		digit_packet_committed,
		digit_result
	)
	if replayed_failed_transaction:
		_restore_support_proximal_replay_if_needed(
			preview_presenter,
			actor,
			held_item,
			support_anchor,
			support_slot_id,
			replay_snapshot,
			true
		)
	else:
		actor.call(
			"restore_authoring_active_grip_transaction_state",
			support_slot_id,
			grip_state_snapshot
		)
		_restore_bone_poses(skeleton, digit_pose_snapshot)


func _print_support_macro_reach_debug(actor: Node3D, label: String) -> void:
	if not actor.has_method("get_grip_contact_debug_state"):
		return
	var debug_state: Dictionary = actor.call(
		"get_grip_contact_debug_state"
	) as Dictionary
	var two_hand_state: Dictionary = debug_state.get(
		"last_two_hand_solve_result",
		{}
	) as Dictionary
	var support_state: Dictionary = two_hand_state.get(
		"hand_left",
		{}
	) as Dictionary
	var desired_target: Vector3 = support_state.get(
		"desired_target",
		Vector3.ZERO
	) as Vector3
	var corrected_target: Vector3 = support_state.get(
		"corrected_target",
		Vector3.ZERO
	) as Vector3
	print((
		"support_macro_reach_%s=active:%s,clamped:%s,before_m:%.9f,"
		+ "after_m:%.9f,limit_m:%.9f,desired_to_corrected_mm:%.6f,"
		+ "hand_to_target_mm:%.6f,clavicle_to_target_m:%.9f,usable_m:%.9f"
	) % [
		label,
		str(bool(support_state.get("active", false))),
		str(bool(support_state.get("arm_reach_clamped", false))),
		float(support_state.get("arm_reach_before_meters", 0.0)),
		float(support_state.get("arm_reach_after_meters", 0.0)),
		float(support_state.get("arm_reach_limit_meters", 0.0)),
		desired_target.distance_to(corrected_target) * 1000.0,
		float(debug_state.get("left_hand_ik_target_distance_meters", -1.0))
			* 1000.0,
		float(debug_state.get("left_hand_ik_clavicle_distance_meters", -1.0)),
		float(debug_state.get("left_usable_arm_chain_reach_meters", -1.0)),
	])


func _restore_support_proximal_replay_if_needed(
	preview_presenter: Object,
	actor: Node3D,
	held_item: Node3D,
	support_anchor: Node3D,
	support_slot_id: StringName,
	replay_snapshot: Dictionary,
	replayed: bool
) -> void:
	if (
		not replayed
		or preview_presenter == null
		or support_anchor == null
		or not preview_presenter.has_method(
			"_restore_preview_support_grip_transaction_snapshot"
		)
	):
		return
	preview_presenter.call(
		"_restore_preview_support_grip_transaction_snapshot",
		actor,
		held_item,
		support_anchor,
		replay_snapshot,
		support_slot_id,
		DOMINANT_SLOT_ID
	)


func _print_compact_proximal_comparison_seat(
	label: String,
	seat_result: Dictionary
) -> void:
	var diagnostics: Dictionary = seat_result.get("diagnostics", {}) as Dictionary
	var best_overall: Dictionary = diagnostics.get("best_overall", {}) as Dictionary
	var best_provisional: Dictionary = diagnostics.get(
		"best_provisional",
		{}
	) as Dictionary
	var candidate: Dictionary = (
		best_overall if not best_overall.is_empty() else best_provisional
	)
	var correction: Transform3D = seat_result.get(
		"seat_correction_grip_local",
		seat_result.get(
			"provisional_seat_correction_grip_local",
			Transform3D.IDENTITY
		)
	) as Transform3D
	print((
		"support_proximal_comparison_%s="
		+ "status:%s,valid:%s,sample:%d,provisional:%s/%d,enforced:%s,"
		+ "index_radial_mm:%.6f,pinky_radial_mm:%.6f,max_radial_mm:%.6f,"
		+ "proximal_safe:%s,worst_digit:%s,worst_penetration_mm:%.6f,"
		+ "worst_excess_mm:%.6f,correction_translation_mm:%.6f,"
		+ "correction_rotation_deg:%.6f"
	) % [
		label,
		String(seat_result.get("status", StringName())),
		str(bool(seat_result.get("valid", false))),
		int(seat_result.get("candidate_sample_index", -1)),
		str(bool(seat_result.get("provisional_candidate_available", false))),
		int(seat_result.get("provisional_candidate_sample_index", -1)),
		str(bool(diagnostics.get("ordinary_proximal_safety_enforced", false))),
		float(candidate.get("index_radial_error_meters", INF)) * 1000.0,
		float(candidate.get("pinky_radial_error_meters", INF)) * 1000.0,
		float(candidate.get("max_abs_radial_error_meters", INF)) * 1000.0,
		str(bool(candidate.get("ordinary_proximal_capsules_safe", false))),
		String(candidate.get("ordinary_proximal_worst_digit_id", StringName())),
		float(candidate.get(
			"ordinary_proximal_worst_penetration_meters",
			INF
		)) * 1000.0,
		float(candidate.get(
			"ordinary_proximal_worst_excess_penetration_meters",
			INF
		)) * 1000.0,
		correction.origin.length() * 1000.0,
		rad_to_deg(_basis_rotation_delta(Basis.IDENTITY, correction.basis)),
	])


func _print_compact_digit_solver_result(
	label: String,
	committed: bool,
	result: Dictionary
) -> void:
	var digit_statuses: Dictionary = result.get("grasp_digit_statuses", {}) as Dictionary
	var digit_ids: Array = digit_statuses.keys()
	digit_ids.sort()
	var digit_summaries := PackedStringArray()
	for digit_id_variant: Variant in digit_ids:
		var digit_id := StringName(digit_id_variant)
		var digit_state: Dictionary = digit_statuses.get(digit_id_variant, {}) as Dictionary
		digit_summaries.append((
			"%s[%s,ok:%s,contact:%d,accepted:%d,pen_mm:%.6f,"
			+ "attempted_pen_mm:%.6f,unsafe_attempt:%s,neutral:%s/%s,"
			+ "final:%s,attempted:%s]"
		) % [
			String(digit_id),
			String(digit_state.get("status", StringName())),
			str(bool(digit_state.get("overlap_limit_respected", false))),
			int(digit_state.get("contacted_section_count", 0)),
			int(digit_state.get("accepted_section_count", 0)),
			float(digit_state.get("max_penetration_meters", INF)) * 1000.0,
			float(digit_state.get(
				"attempted_max_penetration_meters",
				INF
			)) * 1000.0,
			str(bool(digit_state.get("unsafe_attempt_rejected", false))),
			str(bool(digit_state.get("neutral_fallback_evaluated", false))),
			str(bool(digit_state.get("neutral_fallback_safe", false))),
			_format_digit_solver_sections(
				digit_state.get("final_sections", []) as Array
			),
			_format_digit_solver_sections(
				digit_state.get("attempted_final_sections", []) as Array
			),
		])
	print((
		"%s=committed:%s,state_valid:%s,status:%s,attempt:%s,solver:%s,"
		+ "safe:%s,overlap_ok:%s,solved:%d,degraded:%d,unsafe:%d,"
		+ "rotations:%d,zero_rotations:%d,readiness:%.6f,unsafe_digits:%s,"
		+ "digits:%s"
	) % [
		label,
		str(committed),
		str(bool(result.get("grasp_valid", false))),
		String(result.get("grasp_status", StringName())),
		String(result.get("grasp_attempt_status", StringName())),
		String(result.get("grasp_solver_status", StringName())),
		str(bool(result.get("grasp_attempt_safe_to_apply", false))),
		str(bool(result.get("grasp_solver_overlap_limit_respected", false))),
		int(result.get("grasp_solver_solved_digit_count", 0)),
		int(result.get("grasp_solver_degraded_digit_count", 0)),
		int(result.get("grasp_solver_unsafe_digit_count", 0)),
		int(result.get("grasp_committed_rotation_count", 0)),
		int(result.get("grasp_zero_packet_rotation_count", 0)),
		float(result.get("grasp_last_contact_readiness", 0.0)),
		str(result.get("grasp_unsafe_digits", [])),
		";".join(digit_summaries),
	])


func _print_raw_digit_solver_diagnostics(
	label: String,
	diagnostics: Dictionary
) -> void:
	var digit_results: Dictionary = diagnostics.get("digit_results", {}) as Dictionary
	var digit_ids: Array = digit_results.keys()
	digit_ids.sort()
	var digit_summaries := PackedStringArray()
	var unsafe_digits := PackedStringArray()
	for digit_id_variant: Variant in digit_ids:
		var digit_id := StringName(digit_id_variant)
		var digit_state: Dictionary = digit_results.get(
			digit_id_variant,
			{}
		) as Dictionary
		var overlap_ok: bool = bool(digit_state.get(
			"overlap_limit_respected",
			false
		))
		if not overlap_ok:
			unsafe_digits.append(String(digit_id))
		digit_summaries.append((
			"%s[%s,ok:%s,contact:%d,accepted:%d,pen_mm:%.6f,"
			+ "attempted_pen_mm:%.6f,unsafe_attempt:%s,neutral:%s/%s,"
			+ "final:%s,attempted:%s]"
		) % [
			String(digit_id),
			String(digit_state.get("status", StringName())),
			str(overlap_ok),
			int(digit_state.get("contacted_section_count", 0)),
			int(digit_state.get("accepted_section_count", 0)),
			float(digit_state.get("max_penetration_meters", INF)) * 1000.0,
			float(digit_state.get(
				"attempted_max_penetration_meters",
				digit_state.get("max_penetration_meters", INF)
			)) * 1000.0,
			str(bool(digit_state.get("unsafe_attempt_rejected", false))),
			str(bool(digit_state.get("neutral_fallback_evaluated", false))),
			str(bool(digit_state.get("neutral_fallback_safe", false))),
			_format_digit_solver_sections(
				digit_state.get("final_sections", []) as Array
			),
			_format_digit_solver_sections(
				digit_state.get("attempted_final_sections", []) as Array
			),
		])
	print((
		"%s=present:%s,status:%s,overlap_ok:%s,solved:%d,degraded:%d,"
		+ "unsafe:%d,unsafe_digits:%s,digits:%s"
	) % [
		label,
		str(not diagnostics.is_empty()),
		String(diagnostics.get("status", StringName())),
		str(bool(diagnostics.get("overlap_limit_respected", false))),
		int(diagnostics.get("solved_digit_count", 0)),
		int(diagnostics.get("degraded_digit_count", 0)),
		int(diagnostics.get("unsafe_digit_count", 0)),
		str(unsafe_digits),
		";".join(digit_summaries),
	])


func _format_digit_solver_sections(sections: Array) -> String:
	var summaries := PackedStringArray()
	for section_variant: Variant in sections:
		var section: Dictionary = section_variant as Dictionary
		summaries.append("%d:%s/pen%.6f/cap%.6f/ok%s/inside%s" % [
			int(section.get("section_index", -1)),
			String(section.get("status", StringName())),
			float(section.get("penetration_meters", INF)) * 1000.0,
			float(section.get(
				"section_max_allowed_overlap_meters",
				INF
			)) * 1000.0,
			str(bool(section.get("within_overlap_limit", false))),
			str(bool(section.get("inside_solid", false))),
		])
	return "|".join(summaries)


func _verify_left_primary_digit_solver_reference(
	ui: CombatAnimationStationUI,
	wip_id: StringName
) -> void:
	if wip_id == StringName():
		print("left_primary_digit_solver_reference=wip_id_missing")
		return
	var opened: bool = ui.open_saved_wip_with_hand_setup(
		wip_id,
		LEFT_SLOT_ID,
		false,
		false
	)
	await _wait_frames(2)
	var selected: bool = ui.select_skill_slot(TARGET_SLOT_ID, true)
	await _wait_frames(2)
	var one_hand_state: bool = ui.set_selected_motion_node_two_hand_state(
		&"two_hand_one_hand",
		false,
		false,
		false,
		true,
		false
	)
	await _wait_frames(2)
	var reset: bool = ui.reset_active_draft_to_baseline()
	await _wait_frames(2)
	var preview_root: Node3D = ui.preview_subviewport.get_node_or_null(
		"CombatAnimationPreviewRoot3D"
	) as Node3D
	var actor: Node3D = (
		preview_root.get_node_or_null(PREVIEW_ACTOR_PATH) as Node3D
		if preview_root != null
		else null
	)
	var held_item: Node3D = (
		preview_root.get_meta("preview_held_item", null) as Node3D
		if preview_root != null
		else null
	)
	print("left_primary_digit_solver_reference=lifecycle:%s/%s/%s/%s,context:%s" % [
		str(opened),
		str(selected),
		str(one_hand_state),
		str(reset),
		str(actor != null and held_item != null),
	])
	if actor == null or held_item == null:
		return
	var result: Dictionary = _capture_surface_relationship_debug(
		actor,
		held_item,
		LEFT_SLOT_ID
	)
	_print_compact_digit_solver_result(
		"left_primary_digit_solver_reference_after_reset",
		_surface_relationship_has_current_packet(result),
		result
	)
	if (
		not _surface_relationship_has_current_packet(result)
		and actor.has_method("invalidate_authoring_active_surface_grasp")
		and actor.has_method("apply_authoring_digit_grip_slot_now")
	):
		actor.call("invalidate_authoring_active_surface_grasp", LEFT_SLOT_ID)
		var manually_committed: bool = bool(actor.call(
			"apply_authoring_digit_grip_slot_now",
			LEFT_SLOT_ID,
			true
		))
		var manual_result: Dictionary = _capture_surface_relationship_debug(
			actor,
			held_item,
			LEFT_SLOT_ID
		)
		_print_compact_digit_solver_result(
			"left_primary_digit_solver_reference_manual",
			manually_committed,
			manual_result
		)


func _verify_two_hand_roll(
	ui: CombatAnimationStationUI,
	wip_id: StringName
) -> void:
	_check(
		"two_hand_wip_opened",
		ui.open_saved_wip_with_hand_setup(
			wip_id,
			DOMINANT_SLOT_ID,
			true,
			false
		)
	)
	await _wait_frames(2)
	_check("two_hand_skill_slot_selected", ui.select_skill_slot(TARGET_SLOT_ID, true))
	await _wait_frames(2)
	_check("two_hand_grip_relationship_seeded", ui.reset_active_draft_to_baseline())
	await _wait_frames(2)
	var motion_node: CombatAnimationMotionNode = ui.call(
		"_get_active_motion_node"
	) as CombatAnimationMotionNode
	var preview_root: Node3D = ui.preview_subviewport.get_node_or_null(
		"CombatAnimationPreviewRoot3D"
	) as Node3D
	var actor: Node3D = (
		preview_root.get_node_or_null(PREVIEW_ACTOR_PATH) as Node3D
		if preview_root != null
		else null
	)
	var skeleton: Skeleton3D = (
		actor.get_node_or_null(PREVIEW_SKELETON_PATH) as Skeleton3D
		if actor != null
		else null
	)
	var held_item: Node3D = (
		preview_root.get_meta("preview_held_item", null) as Node3D
		if preview_root != null
		else null
	)
	_check("two_hand_motion_node_available", motion_node != null)
	_check("two_hand_actor_available", actor != null)
	_check("two_hand_skeleton_available", skeleton != null)
	_check("two_hand_weapon_available", held_item != null)
	if motion_node == null or actor == null or skeleton == null or held_item == null:
		return
	var primary_relationship_after_reset: Dictionary = (
		_capture_surface_relationship_debug(actor, held_item, DOMINANT_SLOT_ID)
	)
	var support_relationship_after_reset: Dictionary = (
		_capture_surface_relationship_debug(actor, held_item, LEFT_SLOT_ID)
	)
	print("two_hand_primary_relationship_after_reset=%s" % var_to_str(
		primary_relationship_after_reset
	))
	print("two_hand_support_relationship_after_reset=%s" % var_to_str(
		support_relationship_after_reset
	))
	_check(
		"two_hand_reset_primary_current_packet_available",
		_surface_relationship_has_current_packet(primary_relationship_after_reset)
	)
	_check(
		"two_hand_reset_support_current_packet_available",
		_surface_relationship_has_current_packet(support_relationship_after_reset)
	)
	var two_hand_zero_ready: bool = true
	if not is_zero_approx(motion_node.weapon_roll_degrees):
		two_hand_zero_ready = ui.set_selected_motion_node_weapon_roll(
			0.0,
			false,
			false,
			true,
			true,
			false
		)
		await _wait_frames(1)
		motion_node = ui.call("_get_active_motion_node") as CombatAnimationMotionNode
	_check("two_hand_positive_zero_ready", two_hand_zero_ready)
	if motion_node == null:
		return
	var primary_macro_before: Dictionary = _capture_bone_poses(
		skeleton,
		DOMINANT_MACRO_BONES
	)
	var support_macro_before: Dictionary = _capture_bone_poses(
		skeleton,
		SUPPORT_MACRO_BONES
	)
	var primary_digits_before: Dictionary = _capture_bone_poses(
		skeleton,
		DOMINANT_DIGIT_BONES
	)
	var support_digits_before: Dictionary = _capture_bone_poses(
		skeleton,
		SUPPORT_DIGIT_BONES
	)
	var requested_roll: float = clampf(
		20.0,
		CombatAnimationMotionNodeEditorScript.WEAPON_ROLL_MIN_DEGREES,
		CombatAnimationMotionNodeEditorScript.WEAPON_ROLL_MAX_DEGREES
	)
	ui.call(
		"_begin_preview_drag_override",
		motion_node,
		CombatAnimationMotionNodeEditorScript.DRAG_TARGET_WEAPON_ROTATION
	)
	ui.motion_node_editor.begin_drag(
		CombatAnimationMotionNodeEditorScript.DRAG_TARGET_WEAPON_ROTATION,
		Vector2.ZERO,
		motion_node
	)
	var drag_motion_node: CombatAnimationMotionNode = (
		ui.preview_drag_override_node as CombatAnimationMotionNode
	)
	_check("two_hand_roll_drag_override_available", drag_motion_node != null)
	if drag_motion_node == null:
		return
	drag_motion_node.weapon_roll_degrees = requested_roll
	drag_motion_node.normalize()
	ui.preview_drag_has_moved = true
	ui.call("_refresh_preview_scene")
	var live_roll_result: Dictionary = preview_root.get_meta(
		"weapon_roll_contact_result",
		{}
	) as Dictionary
	_print_bone_pose_deltas(
		"two_hand_live_primary_macro",
		primary_macro_before,
		_capture_bone_poses(skeleton, DOMINANT_MACRO_BONES),
		DOMINANT_MACRO_BONES
	)
	_print_bone_pose_deltas(
		"two_hand_live_support_macro",
		support_macro_before,
		_capture_bone_poses(skeleton, SUPPORT_MACRO_BONES),
		SUPPORT_MACRO_BONES
	)
	_check(
		"two_hand_primary_macro_preserved_during_live_roll",
		_bone_pose_maps_match(
			primary_macro_before,
			_capture_bone_poses(skeleton, DOMINANT_MACRO_BONES)
		)
	)
	_check(
		"two_hand_live_support_settle_deferred",
		bool(live_roll_result.get("support_active", false))
		and not bool(live_roll_result.get("support_macro_settled", true))
	)
	ui.motion_node_editor.end_drag()
	ui.call("_finalize_preview_drag", "Two-hand Weapon Roll verifier settled.")
	var final_roll_result: Dictionary = preview_root.get_meta(
		"weapon_roll_contact_result",
		{}
	) as Dictionary
	print("two_hand_final_roll_result=%s" % var_to_str(final_roll_result))
	_print_bone_pose_deltas(
		"two_hand_released_primary_macro",
		primary_macro_before,
		_capture_bone_poses(skeleton, DOMINANT_MACRO_BONES),
		DOMINANT_MACRO_BONES
	)
	_print_bone_pose_deltas(
		"two_hand_released_support_macro",
		support_macro_before,
		_capture_bone_poses(skeleton, SUPPORT_MACRO_BONES),
		SUPPORT_MACRO_BONES
	)
	var two_hand_debug_after: Dictionary = ui.get_preview_debug_state()
	print("two_hand_dominant_grip_error=%s" % str(float(
		two_hand_debug_after.get("dominant_grip_alignment_error_meters", -1.0)
	)))
	print("two_hand_support_grip_error=%s" % str(float(
		two_hand_debug_after.get("support_grip_alignment_error_meters", -1.0)
	)))
	_check(
		"two_hand_roll_contact_packet_applied",
		bool(final_roll_result.get("applied", false))
		and bool(final_roll_result.get("support_active", false))
		and bool(final_roll_result.get("support_macro_settled", false))
		and bool(final_roll_result.get("support_wrist_applied", false))
	)
	_check(
		"two_hand_primary_macro_preserved_after_release",
		_bone_pose_maps_match(
			primary_macro_before,
			_capture_bone_poses(skeleton, DOMINANT_MACRO_BONES)
		)
	)
	_check(
		"two_hand_digit_packets_preserved",
		_bone_pose_maps_match(
			primary_digits_before,
			_capture_bone_poses(skeleton, DOMINANT_DIGIT_BONES)
		)
		and _bone_pose_maps_match(
			support_digits_before,
			_capture_bone_poses(skeleton, SUPPORT_DIGIT_BONES)
		)
	)
	var primary_before_generic_refresh: Dictionary = _capture_bone_poses(
		skeleton,
		DOMINANT_MACRO_BONES
	)
	var support_before_generic_refresh: Dictionary = _capture_bone_poses(
		skeleton,
		SUPPORT_MACRO_BONES
	)
	ui.call("_refresh_preview_scene")
	_print_bone_pose_deltas(
		"two_hand_generic_refresh_primary_macro",
		primary_before_generic_refresh,
		_capture_bone_poses(skeleton, DOMINANT_MACRO_BONES),
		DOMINANT_MACRO_BONES
	)
	_print_bone_pose_deltas(
		"two_hand_generic_refresh_support_macro",
		support_before_generic_refresh,
		_capture_bone_poses(skeleton, SUPPORT_MACRO_BONES),
		SUPPORT_MACRO_BONES
	)
	_check(
		"two_hand_primary_roll_authority_survives_later_refresh",
		_bone_pose_maps_match(
			primary_before_generic_refresh,
			_capture_bone_poses(skeleton, DOMINANT_MACRO_BONES)
		)
	)
	_check(
		"two_hand_support_pose_stable_on_later_refresh",
		_bone_pose_maps_match(
			support_before_generic_refresh,
			_capture_bone_poses(skeleton, SUPPORT_MACRO_BONES)
		)
	)


func _verify_left_primary_roll(
	ui: CombatAnimationStationUI,
	wip_id: StringName
) -> void:
	_check(
		"left_primary_wip_opened",
		ui.open_saved_wip_with_hand_setup(
			wip_id,
			LEFT_SLOT_ID,
			false,
			false
		)
	)
	await _wait_frames(2)
	_check("left_primary_skill_selected", ui.select_skill_slot(TARGET_SLOT_ID, true))
	await _wait_frames(2)
	_check("left_primary_grip_seeded", ui.reset_active_draft_to_baseline())
	await _wait_frames(2)
	var motion_node: CombatAnimationMotionNode = ui.call(
		"_get_active_motion_node"
	) as CombatAnimationMotionNode
	var preview_root: Node3D = ui.preview_subviewport.get_node_or_null(
		"CombatAnimationPreviewRoot3D"
	) as Node3D
	var actor: Node3D = (
		preview_root.get_node_or_null(PREVIEW_ACTOR_PATH) as Node3D
		if preview_root != null
		else null
	)
	var skeleton: Skeleton3D = (
		actor.get_node_or_null(PREVIEW_SKELETON_PATH) as Skeleton3D
		if actor != null
		else null
	)
	var held_item: Node3D = (
		preview_root.get_meta("preview_held_item", null) as Node3D
		if preview_root != null
		else null
	)
	_check("left_primary_motion_node_available", motion_node != null)
	_check("left_primary_actor_available", actor != null)
	_check("left_primary_skeleton_available", skeleton != null)
	_check("left_primary_weapon_available", held_item != null)
	if motion_node == null or actor == null or skeleton == null or held_item == null:
		return
	var left_positive_zero_ready: bool = true
	if not is_zero_approx(motion_node.weapon_roll_degrees):
		left_positive_zero_ready = ui.set_selected_motion_node_weapon_roll(
			0.0,
			false,
			false,
			true,
			true,
			false
		)
		await _wait_frames(1)
		motion_node = ui.call("_get_active_motion_node") as CombatAnimationMotionNode
	_check("left_primary_positive_zero_ready", left_positive_zero_ready)
	if motion_node == null:
		return
	var left_relationship_before_roll: Dictionary = _capture_surface_relationship_debug(
		actor,
		held_item,
		LEFT_SLOT_ID
	)
	print("left_primary_relationship_before_roll=%s" % var_to_str(
		left_relationship_before_roll
	))
	_check(
		"left_primary_current_packet_available_before_roll",
		_surface_relationship_has_current_packet(left_relationship_before_roll)
	)
	var macro_before: Dictionary = _capture_bone_poses(
		skeleton,
		SUPPORT_MACRO_BONES
	)
	var hand_before: Dictionary = _capture_bone_poses(
		skeleton,
		[LEFT_HAND_BONE]
	)
	var digits_before: Dictionary = _capture_bone_poses(
		skeleton,
		SUPPORT_DIGIT_BONES
	)
	var weapon_before: Transform3D = held_item.global_transform
	var weapon_tip_local: Vector3 = held_item.get_meta(
		"weapon_tip_local",
		Vector3.INF
	) as Vector3
	var weapon_pommel_local: Vector3 = held_item.get_meta(
		"weapon_pommel_local",
		Vector3.INF
	) as Vector3
	var contact_before: Dictionary = _capture_hand_contact_weapon_local(
		actor,
		held_item,
		LEFT_SLOT_ID
	)
	var initial_roll: float = motion_node.weapon_roll_degrees
	var requested_roll: float = clampf(
		20.0,
		CombatAnimationMotionNodeEditorScript.WEAPON_ROLL_MIN_DEGREES,
		CombatAnimationMotionNodeEditorScript.WEAPON_ROLL_MAX_DEGREES
	)
	_check(
		"left_primary_numeric_roll_applied",
		ui.set_selected_motion_node_weapon_roll(
			requested_roll,
			false,
			false,
			true,
			true,
			false
		)
	)
	var left_relationship_after_roll: Dictionary = _capture_surface_relationship_debug(
		actor,
		held_item,
		LEFT_SLOT_ID
	)
	print("left_primary_relationship_after_roll=%s" % var_to_str(
		left_relationship_after_roll
	))
	_check(
		"left_primary_current_packet_available_after_roll",
		_surface_relationship_has_current_packet(left_relationship_after_roll)
	)
	_check(
		"left_primary_macro_preserved",
		_bone_pose_maps_match(
			macro_before,
			_capture_bone_poses(skeleton, SUPPORT_MACRO_BONES)
		)
	)
	_check(
		"left_primary_hand_follows_roll",
		not _bone_pose_maps_match(
			hand_before,
			_capture_bone_poses(skeleton, [LEFT_HAND_BONE])
		)
	)
	print(
		"left_hand_roll_delta_degrees=%.6f requested_delta_degrees=%.6f" % [
			_pose_rotation_delta_degrees(
				hand_before,
				_capture_bone_poses(skeleton, [LEFT_HAND_BONE]),
				LEFT_HAND_BONE
			),
			absf(requested_roll - initial_roll),
		]
	)
	_check(
		"left_primary_hand_roll_is_one_to_one",
		absf(
			_pose_rotation_delta_degrees(
				hand_before,
				_capture_bone_poses(skeleton, [LEFT_HAND_BONE]),
				LEFT_HAND_BONE
			)
			- absf(requested_roll - initial_roll)
		) <= 1.0
	)
	_check(
		"left_primary_digits_preserved",
		_bone_pose_maps_match(
			digits_before,
			_capture_bone_poses(skeleton, SUPPORT_DIGIT_BONES)
		)
	)
	var left_grip_debug_after: Dictionary = actor.call(
		"get_grip_contact_debug_state"
	) as Dictionary
	_check(
		"left_primary_twist_helpers_neutralized",
		not bool(left_grip_debug_after.get(
			"left_authoring_twist_distribution_active",
			true
		))
		and absf(float(left_grip_debug_after.get(
			"left_authoring_twist_requested_degrees",
			INF
		))) <= 0.01
	)
	_verify_signed_axis_roll_and_endpoints(
		"left_primary_positive",
		weapon_before,
		held_item.global_transform,
		weapon_tip_local,
		weapon_pommel_local,
		requested_roll - initial_roll
	)
	_check_contact_relationship_preserved(
		"left_primary_positive",
		contact_before,
		_capture_hand_contact_weapon_local(actor, held_item, LEFT_SLOT_ID)
	)
	var macro_before_generic_refresh: Dictionary = _capture_bone_poses(
		skeleton,
		SUPPORT_MACRO_BONES
	)
	print("left_primary_roll_result_before_generic_refresh=%s" % var_to_str(
		preview_root.get_meta("weapon_roll_contact_result", {})
	))
	print(
		"left_primary_settled_key_before_generic_refresh=%s" % str(
			not ui.settled_weapon_roll_authority_key.is_empty()
		)
	)
	ui.call("_refresh_preview_scene")
	print("left_primary_roll_result_after_generic_refresh=%s" % var_to_str(
		preview_root.get_meta("weapon_roll_contact_result", {})
	))
	var macro_after_generic_refresh: Dictionary = _capture_bone_poses(
		skeleton,
		SUPPORT_MACRO_BONES
	)
	_print_bone_pose_deltas(
		"left_primary_generic_refresh",
		macro_before_generic_refresh,
		macro_after_generic_refresh,
		SUPPORT_MACRO_BONES
	)
	_check(
		"left_primary_roll_survives_later_refresh",
		_bone_pose_maps_match(
			macro_before_generic_refresh,
			macro_after_generic_refresh
		)
	)
	await _verify_signed_roll_from_zero(
		ui,
		actor,
		skeleton,
		held_item,
		LEFT_SLOT_ID,
		LEFT_HAND_BONE,
		SUPPORT_MACRO_BONES,
		SUPPORT_DIGIT_BONES,
		-20.0,
		"left_primary_negative"
	)


func _verify_signed_roll_from_zero(
	ui: CombatAnimationStationUI,
	actor: Node3D,
	skeleton: Skeleton3D,
	held_item: Node3D,
	slot_id: StringName,
	hand_bone: StringName,
	macro_bones: Array[StringName],
	digit_bones: Array[StringName],
	target_roll_degrees: float,
	label: String
) -> void:
	var motion_node: CombatAnimationMotionNode = ui.call(
		"_get_active_motion_node"
	) as CombatAnimationMotionNode
	_check("%s_motion_node_available" % label, motion_node != null)
	if motion_node == null:
		return
	var relationship_before_zero: Dictionary = _capture_surface_relationship_debug(
		actor,
		held_item,
		slot_id
	)
	print("%s_relationship_before_zero=%s" % [
		label,
		var_to_str(relationship_before_zero),
	])
	_check(
		"%s_current_packet_available_before_zero" % label,
		_surface_relationship_has_current_packet(relationship_before_zero)
	)
	var zero_applied: bool = true
	if not is_zero_approx(motion_node.weapon_roll_degrees):
		zero_applied = ui.set_selected_motion_node_weapon_roll(
			0.0,
			false,
			false,
			true,
			true,
			false
		)
	_check("%s_zero_roll_applied" % label, zero_applied)
	await _wait_frames(1)
	var relationship_at_zero: Dictionary = _capture_surface_relationship_debug(
		actor,
		held_item,
		slot_id
	)
	print("%s_relationship_at_zero=%s" % [label, var_to_str(relationship_at_zero)])
	_check(
		"%s_current_packet_available_at_zero" % label,
		_surface_relationship_has_current_packet(relationship_at_zero)
	)
	var macro_at_zero: Dictionary = _capture_bone_poses(skeleton, macro_bones)
	var hand_at_zero: Dictionary = _capture_bone_poses(skeleton, [hand_bone])
	var digits_at_zero: Dictionary = _capture_bone_poses(skeleton, digit_bones)
	var weapon_at_zero: Transform3D = held_item.global_transform
	var contact_at_zero: Dictionary = _capture_hand_contact_weapon_local(
		actor,
		held_item,
		slot_id
	)
	var weapon_tip_local: Vector3 = held_item.get_meta(
		"weapon_tip_local",
		Vector3.INF
	) as Vector3
	var weapon_pommel_local: Vector3 = held_item.get_meta(
		"weapon_pommel_local",
		Vector3.INF
	) as Vector3
	var resolved_target: float = clampf(
		target_roll_degrees,
		CombatAnimationMotionNodeEditorScript.WEAPON_ROLL_MIN_DEGREES,
		CombatAnimationMotionNodeEditorScript.WEAPON_ROLL_MAX_DEGREES
	)
	_check(
		"%s_target_roll_applied" % label,
		ui.set_selected_motion_node_weapon_roll(
			resolved_target,
			false,
			false,
			true,
			true,
			false
		)
	)
	await _wait_frames(1)
	var macro_after: Dictionary = _capture_bone_poses(skeleton, macro_bones)
	var hand_after: Dictionary = _capture_bone_poses(skeleton, [hand_bone])
	var digits_after: Dictionary = _capture_bone_poses(skeleton, digit_bones)
	var relationship_after_roll: Dictionary = _capture_surface_relationship_debug(
		actor,
		held_item,
		slot_id
	)
	print("%s_relationship_after_roll=%s" % [
		label,
		var_to_str(relationship_after_roll),
	])
	_check(
		"%s_current_packet_available_after_roll" % label,
		_surface_relationship_has_current_packet(relationship_after_roll)
	)
	_check(
		"%s_macro_pose_preserved" % label,
		_bone_pose_maps_match(macro_at_zero, macro_after)
	)
	_check(
		"%s_hand_follows_roll" % label,
		not _bone_pose_maps_match(hand_at_zero, hand_after)
	)
	var hand_delta_degrees: float = _pose_rotation_delta_degrees(
		hand_at_zero,
		hand_after,
		hand_bone
	)
	print(
		"%s_hand_delta_degrees=%.6f requested_degrees=%.6f" % [
			label,
			hand_delta_degrees,
			absf(resolved_target),
		]
	)
	_check(
		"%s_hand_roll_is_one_to_one" % label,
		absf(hand_delta_degrees - absf(resolved_target)) <= 1.0
	)
	_check(
		"%s_digit_packet_preserved" % label,
		_bone_pose_maps_match(digits_at_zero, digits_after)
	)
	_verify_signed_axis_roll_and_endpoints(
		label,
		weapon_at_zero,
		held_item.global_transform,
		weapon_tip_local,
		weapon_pommel_local,
		resolved_target
	)
	_check_contact_relationship_preserved(
		label,
		contact_at_zero,
		_capture_hand_contact_weapon_local(actor, held_item, slot_id)
	)


func _verify_signed_axis_roll_and_endpoints(
	label: String,
	before: Transform3D,
	after: Transform3D,
	weapon_tip_local: Vector3,
	weapon_pommel_local: Vector3,
	expected_delta_degrees: float
) -> void:
	var endpoints_valid: bool = (
		weapon_tip_local.is_finite()
		and weapon_pommel_local.is_finite()
		and not weapon_tip_local.is_equal_approx(weapon_pommel_local)
	)
	_check("%s_roll_endpoints_available" % label, endpoints_valid)
	if not endpoints_valid:
		return
	var before_tip_world: Vector3 = before * weapon_tip_local
	var before_pommel_world: Vector3 = before * weapon_pommel_local
	var after_tip_world: Vector3 = after * weapon_tip_local
	var after_pommel_world: Vector3 = after * weapon_pommel_local
	var tip_drift_meters: float = before_tip_world.distance_to(after_tip_world)
	var pommel_drift_meters: float = before_pommel_world.distance_to(
		after_pommel_world
	)
	print(
		"%s_endpoint_drift_meters=tip:%.9f,pommel:%.9f" % [
			label,
			tip_drift_meters,
			pommel_drift_meters,
		]
	)
	_check(
		"%s_tip_endpoint_invariant" % label,
		tip_drift_meters <= ENDPOINT_POSITION_TOLERANCE_METERS
	)
	_check(
		"%s_pommel_endpoint_invariant" % label,
		pommel_drift_meters <= ENDPOINT_POSITION_TOLERANCE_METERS
	)
	var roll_axis_world: Vector3 = before_tip_world - before_pommel_world
	var axis_valid: bool = roll_axis_world.length_squared() > 0.000001
	_check("%s_tip_pommel_axis_available" % label, axis_valid)
	if not axis_valid:
		return
	roll_axis_world = roll_axis_world.normalized()
	var before_basis: Basis = before.basis.orthonormalized()
	var after_basis: Basis = after.basis.orthonormalized()
	var delta_basis: Basis = (
		after_basis * before_basis.inverse()
	).orthonormalized()
	var signed_roll: Dictionary = _resolve_signed_axis_roll_degrees(
		delta_basis,
		roll_axis_world
	)
	var signed_roll_valid: bool = bool(signed_roll.get("valid", false))
	_check("%s_signed_roll_resolved" % label, signed_roll_valid)
	if not signed_roll_valid:
		return
	var actual_delta_degrees: float = float(signed_roll.get(
		"signed_twist_degrees",
		INF
	))
	var swing_degrees: float = float(signed_roll.get("swing_degrees", INF))
	var signed_error_degrees: float = absf(wrapf(
		actual_delta_degrees - expected_delta_degrees,
		-180.0,
		180.0
	))
	print(
		"%s_signed_roll_degrees=actual:%.6f,expected:%.6f,error:%.6f,swing:%.6f" % [
			label,
			actual_delta_degrees,
			expected_delta_degrees,
			signed_error_degrees,
			swing_degrees,
		]
	)
	_check(
		"%s_signed_roll_matches_request" % label,
		signed_error_degrees <= ROLL_ANGLE_TOLERANCE_DEGREES
	)
	_check(
		"%s_roll_has_negligible_swing" % label,
		swing_degrees <= ROLL_SWING_TOLERANCE_DEGREES
	)


func _resolve_signed_axis_roll_degrees(
	delta_basis: Basis,
	axis_world: Vector3
) -> Dictionary:
	if not axis_world.is_finite() or axis_world.length_squared() <= 0.000001:
		return {"valid": false}
	var resolved_axis: Vector3 = axis_world.normalized()
	var delta_quaternion: Quaternion = (
		delta_basis.orthonormalized().get_rotation_quaternion().normalized()
	)
	if delta_quaternion.w < 0.0:
		delta_quaternion = Quaternion(
			-delta_quaternion.x,
			-delta_quaternion.y,
			-delta_quaternion.z,
			-delta_quaternion.w
		)
	var quaternion_vector := Vector3(
		delta_quaternion.x,
		delta_quaternion.y,
		delta_quaternion.z
	)
	var projected_vector: Vector3 = (
		resolved_axis * quaternion_vector.dot(resolved_axis)
	)
	var twist_norm_squared: float = (
		projected_vector.length_squared()
		+ delta_quaternion.w * delta_quaternion.w
	)
	if twist_norm_squared <= 0.000000000001:
		return {"valid": false}
	var inverse_twist_length: float = 1.0 / sqrt(twist_norm_squared)
	var twist_quaternion := Quaternion(
		projected_vector.x * inverse_twist_length,
		projected_vector.y * inverse_twist_length,
		projected_vector.z * inverse_twist_length,
		delta_quaternion.w * inverse_twist_length
	)
	var twist_vector := Vector3(
		twist_quaternion.x,
		twist_quaternion.y,
		twist_quaternion.z
	)
	var twist_sign: float = (
		-1.0 if twist_vector.dot(resolved_axis) < 0.0 else 1.0
	)
	var signed_twist_degrees: float = twist_sign * rad_to_deg(
		2.0 * atan2(twist_vector.length(), twist_quaternion.w)
	)
	var rotated_axis: Vector3 = delta_basis * resolved_axis
	if not rotated_axis.is_finite() or rotated_axis.length_squared() <= 0.000001:
		return {"valid": false}
	var swing_degrees: float = rad_to_deg(
		resolved_axis.angle_to(rotated_axis.normalized())
	)
	return {
		"valid": is_finite(signed_twist_degrees) and is_finite(swing_degrees),
		"signed_twist_degrees": signed_twist_degrees,
		"swing_degrees": swing_degrees,
	}


func _capture_hand_contact_weapon_local(
	actor: Node3D,
	held_item: Node3D,
	slot_id: StringName
) -> Dictionary:
	var result := {
		"valid": false,
		"contact_world": Vector3.INF,
		"contact_weapon_local": Vector3.INF,
		"hand_basis_valid": false,
		"hand_basis_weapon_local": Basis.IDENTITY,
	}
	if (
		actor == null
		or not is_instance_valid(actor)
		or held_item == null
		or not is_instance_valid(held_item)
		or not actor.has_method("resolve_hand_grip_alignment_world_position")
	):
		return result
	var contact_world_variant: Variant = actor.call(
		"resolve_hand_grip_alignment_world_position",
		slot_id
	)
	if not (contact_world_variant is Vector3):
		return result
	var contact_world: Vector3 = contact_world_variant as Vector3
	if not contact_world.is_finite():
		return result
	var contact_weapon_local: Vector3 = held_item.to_local(contact_world)
	if not contact_weapon_local.is_finite():
		return result
	result["valid"] = true
	result["contact_world"] = contact_world
	result["contact_weapon_local"] = contact_weapon_local
	var skeleton: Skeleton3D = actor.get_node_or_null(
		PREVIEW_SKELETON_PATH
	) as Skeleton3D
	var hand_bone_name: StringName = (
		LEFT_HAND_BONE if slot_id == LEFT_SLOT_ID else DOMINANT_HAND_BONE
	)
	var hand_bone_index: int = (
		skeleton.find_bone(hand_bone_name) if skeleton != null else -1
	)
	if hand_bone_index >= 0:
		var hand_basis_world: Basis = (
			skeleton.global_basis
			* skeleton.get_bone_global_pose(hand_bone_index).basis
		).orthonormalized()
		var hand_basis_weapon_local: Basis = (
			held_item.global_basis.inverse()
			* hand_basis_world
		).orthonormalized()
		if (
			hand_basis_weapon_local.x.is_finite()
			and hand_basis_weapon_local.y.is_finite()
			and hand_basis_weapon_local.z.is_finite()
		):
			result["hand_basis_valid"] = true
			result["hand_basis_weapon_local"] = hand_basis_weapon_local
	return result


func _check_contact_relationship_preserved(
	label: String,
	before: Dictionary,
	after: Dictionary
) -> void:
	var samples_valid: bool = (
		bool(before.get("valid", false))
		and bool(after.get("valid", false))
	)
	_check("%s_contact_samples_valid" % label, samples_valid)
	if not samples_valid:
		return
	var before_local: Vector3 = before.get(
		"contact_weapon_local",
		Vector3.INF
	) as Vector3
	var after_local: Vector3 = after.get(
		"contact_weapon_local",
		Vector3.INF
	) as Vector3
	var drift_meters: float = before_local.distance_to(after_local)
	print("%s_contact_weapon_local_drift_meters=%.9f" % [label, drift_meters])
	_check(
		"%s_contact_relationship_preserved" % label,
		drift_meters <= CONTACT_RELATIONSHIP_TOLERANCE_METERS
	)
	var basis_samples_valid: bool = (
		bool(before.get("hand_basis_valid", false))
		and bool(after.get("hand_basis_valid", false))
	)
	_check("%s_contact_basis_samples_valid" % label, basis_samples_valid)
	if not basis_samples_valid:
		return
	var basis_drift_degrees: float = rad_to_deg(_basis_rotation_delta(
		before.get("hand_basis_weapon_local", Basis.IDENTITY) as Basis,
		after.get("hand_basis_weapon_local", Basis.IDENTITY) as Basis
	))
	print("%s_contact_basis_weapon_local_drift_degrees=%.9f" % [
		label,
		basis_drift_degrees,
	])
	_check(
		"%s_contact_basis_relationship_preserved" % label,
		basis_drift_degrees <= CONTACT_RELATIONSHIP_ROTATION_TOLERANCE_DEGREES
	)


func _verify_keyless_recreated_ui_reopen(
	source_ui: CombatAnimationStationUI
) -> void:
	var source_motion_node: CombatAnimationMotionNode = source_ui.call(
		"_get_active_motion_node"
	) as CombatAnimationMotionNode
	_check("reopen_source_motion_node_available", source_motion_node != null)
	_check("reopen_source_wip_available", source_ui.active_wip != null)
	if source_motion_node == null or source_ui.active_wip == null:
		return
	var expected_roll_degrees: float = source_motion_node.weapon_roll_degrees
	_check("reopen_source_roll_is_nonzero", absf(expected_roll_degrees) > 0.01)
	var source_slot_id: StringName = source_ui.active_preview_dominant_slot_id
	var source_slot_valid: bool = source_slot_id in [DOMINANT_SLOT_ID, LEFT_SLOT_ID]
	_check("reopen_source_primary_slot_available", source_slot_valid)
	if not source_slot_valid:
		return
	var reopened_wip: CraftedItemWIP = (
		source_ui.active_wip.duplicate(true) as CraftedItemWIP
	)
	_check("reopen_wip_snapshot_created", reopened_wip != null)
	if reopened_wip == null:
		return
	var reopened_library: PlayerForgeWipLibraryState = (
		PlayerForgeWipLibraryStateScript.new()
	)
	reopened_library.save_file_path = (
		"C:/WORKSPACE/test_artifacts/"
		+ "verify_skill_crafter_weapon_roll_integration_reopened_library.tres"
	)
	reopened_library.saved_wips.clear()
	reopened_library.saved_wips.append(reopened_wip)
	reopened_library.selected_wip_id = reopened_wip.wip_id
	var source_preview_root: Node3D = source_ui.preview_subviewport.get_node_or_null(
		"CombatAnimationPreviewRoot3D"
	) as Node3D
	var source_actor: Node3D = (
		source_preview_root.get_node_or_null(PREVIEW_ACTOR_PATH) as Node3D
		if source_preview_root != null
		else null
	)
	source_ui.close_ui()
	await _verify_isolated_primary_reset_with_recreated_ui(
		reopened_wip,
		source_slot_id
	)
	var reopened_player := FakePlayer.new()
	reopened_player.forge_wip_library_state = reopened_library
	root.add_child(reopened_player)
	var reopened_ui: CombatAnimationStationUI = (
		CombatAnimationStationUIScene.instantiate() as CombatAnimationStationUI
	)
	reopened_ui.set_meta("verification_skip_persistence", true)
	root.add_child(reopened_ui)
	await _wait_frames(2)
	reopened_ui.open_for(reopened_player, "Weapon Roll Reopen Verification")
	await _wait_frames(2)
	_check(
		"reopen_saved_wip_opened",
		reopened_ui.open_saved_wip_with_hand_setup(
			reopened_wip.wip_id,
			source_slot_id,
			false,
			false
		)
	)
	await _wait_frames(2)
	_check(
		"reopen_skill_slot_selected",
		reopened_ui.select_skill_slot(TARGET_SLOT_ID, true)
	)
	await _wait_frames(2)
	_check(
		"reopen_loaded_without_settled_instance_key",
		reopened_ui.settled_weapon_roll_authority_key.is_empty()
	)
	var reopened_motion_node: CombatAnimationMotionNode = reopened_ui.call(
		"_get_active_motion_node"
	) as CombatAnimationMotionNode
	var reopened_preview_root: Node3D = (
		reopened_ui.preview_subviewport.get_node_or_null(
			"CombatAnimationPreviewRoot3D"
		) as Node3D
	)
	var reopened_actor: Node3D = (
		reopened_preview_root.get_node_or_null(PREVIEW_ACTOR_PATH) as Node3D
		if reopened_preview_root != null
		else null
	)
	var reopened_held_item: Node3D = (
		reopened_preview_root.get_meta("preview_held_item", null) as Node3D
		if reopened_preview_root != null
		else null
	)
	_check("reopen_motion_node_available", reopened_motion_node != null)
	_check("reopen_actor_available", reopened_actor != null)
	_check("reopen_weapon_available", reopened_held_item != null)
	_check(
		"reopen_uses_new_actor_instance",
		reopened_actor != null
		and (source_actor == null or reopened_actor.get_instance_id() != source_actor.get_instance_id())
	)
	if (
		reopened_motion_node == null
		or reopened_actor == null
		or reopened_held_item == null
	):
		reopened_ui.queue_free()
		reopened_player.queue_free()
		return
	_check(
		"reopen_roll_scalar_restored",
		is_equal_approx(
			reopened_motion_node.weapon_roll_degrees,
			expected_roll_degrees
		)
	)
	var reopened_relationship_at_load: Dictionary = _capture_surface_relationship_debug(
		reopened_actor,
		reopened_held_item,
		source_slot_id
	)
	print("reopen_relationship_at_load=%s" % var_to_str(
		reopened_relationship_at_load
	))
	_check(
		"reopen_current_packet_available_at_load",
		_surface_relationship_has_current_packet(reopened_relationship_at_load)
	)
	var reopened_rolled_transform: Transform3D = reopened_held_item.global_transform
	var reopened_rolled_contact: Dictionary = _capture_hand_contact_weapon_local(
		reopened_actor,
		reopened_held_item,
		source_slot_id
	)
	var weapon_tip_local: Vector3 = reopened_held_item.get_meta(
		"weapon_tip_local",
		Vector3.INF
	) as Vector3
	var weapon_pommel_local: Vector3 = reopened_held_item.get_meta(
		"weapon_pommel_local",
		Vector3.INF
	) as Vector3
	_check(
		"reopen_zero_roll_applied",
		reopened_ui.set_selected_motion_node_weapon_roll(
			0.0,
			false,
			false,
			true,
			true,
			false
		)
	)
	await _wait_frames(1)
	var zero_transform: Transform3D = reopened_held_item.global_transform
	var zero_contact: Dictionary = _capture_hand_contact_weapon_local(
		reopened_actor,
		reopened_held_item,
		source_slot_id
	)
	_verify_signed_axis_roll_and_endpoints(
		"reopen_keyless_loaded_roll",
		zero_transform,
		reopened_rolled_transform,
		weapon_tip_local,
		weapon_pommel_local,
		expected_roll_degrees
	)
	_check_contact_relationship_preserved(
		"reopen_keyless_loaded_roll",
		zero_contact,
		reopened_rolled_contact
	)
	_check(
		"reopen_roll_reapplied",
		reopened_ui.set_selected_motion_node_weapon_roll(
			expected_roll_degrees,
			false,
			false,
			true,
			true,
			false
		)
	)
	await _wait_frames(1)
	var reapplied_transform: Transform3D = reopened_held_item.global_transform
	_check_transform_stable(
		"reopen_roll_reapply",
		reopened_rolled_transform,
		reapplied_transform
	)
	_check_contact_relationship_preserved(
		"reopen_roll_reapply",
		reopened_rolled_contact,
		_capture_hand_contact_weapon_local(
			reopened_actor,
			reopened_held_item,
			source_slot_id
		)
	)
	var reopened_relationship_after_reapply: Dictionary = _capture_surface_relationship_debug(
		reopened_actor,
		reopened_held_item,
		source_slot_id
	)
	print("reopen_relationship_after_roll_reapply=%s" % var_to_str(
		reopened_relationship_after_reapply
	))
	_check(
		"reopen_current_packet_available_after_roll_reapply",
		_surface_relationship_has_current_packet(reopened_relationship_after_reapply)
	)
	var reopened_skeleton: Skeleton3D = reopened_actor.get_node_or_null(
		PREVIEW_SKELETON_PATH
	) as Skeleton3D
	if reopened_skeleton != null:
		var probe_macro_bones: Array[StringName] = (
			DOMINANT_MACRO_BONES
			if source_slot_id == DOMINANT_SLOT_ID
			else SUPPORT_MACRO_BONES
		)
		var before_guidance_only: Dictionary = _capture_bone_poses(
			reopened_skeleton,
			probe_macro_bones
		)
		reopened_ui.preview_presenter.call(
			"_apply_two_hand_preview_state",
			reopened_actor,
			reopened_held_item,
			reopened_motion_node,
			false
		)
		var after_guidance_only: Dictionary = _capture_bone_poses(
			reopened_skeleton,
			probe_macro_bones
		)
		_print_bone_pose_deltas(
			"reopen_apply_two_hand_state_without_locomotion",
			before_guidance_only,
			after_guidance_only,
			probe_macro_bones
		)
		print(
			"reopen_apply_two_hand_state_without_locomotion_changed=%s" % str(
				not _bone_pose_maps_match(
					before_guidance_only,
					after_guidance_only
				)
			)
		)
		var before_with_locomotion: Dictionary = after_guidance_only
		reopened_ui.preview_presenter.call(
			"_apply_two_hand_preview_state",
			reopened_actor,
			reopened_held_item,
			reopened_motion_node,
			true
		)
		var after_with_locomotion: Dictionary = _capture_bone_poses(
			reopened_skeleton,
			probe_macro_bones
		)
		_print_bone_pose_deltas(
			"reopen_apply_two_hand_state_with_locomotion",
			before_with_locomotion,
			after_with_locomotion,
			probe_macro_bones
		)
		print(
			"reopen_apply_two_hand_state_with_locomotion_changed=%s" % str(
				not _bone_pose_maps_match(
					before_with_locomotion,
					after_with_locomotion
				)
			)
		)
	var keyless_baseline_transform: Transform3D = reopened_held_item.global_transform
	var keyless_baseline_contact: Dictionary = _capture_hand_contact_weapon_local(
		reopened_actor,
		reopened_held_item,
		source_slot_id
	)
	reopened_ui.call("_clear_settled_weapon_roll_authority")
	_check(
		"reopen_instance_key_cleared",
		reopened_ui.settled_weapon_roll_authority_key.is_empty()
	)
	reopened_ui.call("_refresh_preview_scene")
	await _wait_frames(1)
	print("reopen_keyless_generic_refresh_roll_result=%s" % var_to_str(
		reopened_preview_root.get_meta("weapon_roll_contact_result", {})
	))
	var keyless_refreshed_transform: Transform3D = reopened_held_item.global_transform
	_check_transform_stable(
		"reopen_keyless_generic_refresh",
		keyless_baseline_transform,
		keyless_refreshed_transform
	)
	_check_contact_relationship_preserved(
		"reopen_keyless_generic_refresh",
		keyless_baseline_contact,
		_capture_hand_contact_weapon_local(
			reopened_actor,
			reopened_held_item,
			 source_slot_id
		)
	)
	var reopened_relationship_after_keyless_refresh: Dictionary = (
		_capture_surface_relationship_debug(
			reopened_actor,
			reopened_held_item,
			source_slot_id
		)
	)
	print("reopen_relationship_after_keyless_refresh=%s" % var_to_str(
		reopened_relationship_after_keyless_refresh
	))
	_check(
		"reopen_current_packet_available_after_keyless_refresh",
		_surface_relationship_has_current_packet(
			reopened_relationship_after_keyless_refresh
		)
	)
	reopened_ui.queue_free()
	reopened_player.queue_free()
	await _wait_frames(1)


func _verify_isolated_primary_reset_with_recreated_ui(
	source_wip: CraftedItemWIP,
	slot_id: StringName
) -> void:
	var isolated_wip: CraftedItemWIP = source_wip.duplicate(true) as CraftedItemWIP
	_check("isolated_left_primary_wip_snapshot_created", isolated_wip != null)
	if isolated_wip == null:
		return
	var isolated_library: PlayerForgeWipLibraryState = (
		PlayerForgeWipLibraryStateScript.new()
	)
	isolated_library.save_file_path = (
		"C:/WORKSPACE/test_artifacts/"
		+ "verify_skill_crafter_weapon_roll_isolated_left_library.tres"
	)
	isolated_library.saved_wips.clear()
	isolated_library.saved_wips.append(isolated_wip)
	isolated_library.selected_wip_id = isolated_wip.wip_id
	var isolated_player := FakePlayer.new()
	isolated_player.forge_wip_library_state = isolated_library
	root.add_child(isolated_player)
	var isolated_ui: CombatAnimationStationUI = (
		CombatAnimationStationUIScene.instantiate() as CombatAnimationStationUI
	)
	isolated_ui.set_meta("verification_skip_persistence", true)
	root.add_child(isolated_ui)
	await _wait_frames(2)
	isolated_ui.open_for(isolated_player, "Weapon Roll Isolated Left Reset")
	await _wait_frames(2)
	_check(
		"isolated_left_primary_saved_wip_opened",
		isolated_ui.open_saved_wip_with_hand_setup(
			isolated_wip.wip_id,
			slot_id,
			false,
			false
		)
	)
	await _wait_frames(2)
	_check(
		"isolated_left_primary_skill_slot_selected",
		isolated_ui.select_skill_slot(TARGET_SLOT_ID, true)
	)
	await _wait_frames(2)
	await _verify_isolated_primary_reset_relationship(isolated_ui, slot_id)
	isolated_ui.queue_free()
	isolated_player.queue_free()
	await _wait_frames(1)


func _verify_isolated_primary_reset_relationship(
	ui: CombatAnimationStationUI,
	slot_id: StringName
) -> void:
	_check("isolated_primary_reset_uses_left_slot", slot_id == LEFT_SLOT_ID)
	var motion_node_before_reset: CombatAnimationMotionNode = ui.call(
		"_get_active_motion_node"
	) as CombatAnimationMotionNode
	var preview_root_before_reset: Node3D = ui.preview_subviewport.get_node_or_null(
		"CombatAnimationPreviewRoot3D"
	) as Node3D
	var actor_before_reset: Node3D = (
		preview_root_before_reset.get_node_or_null(PREVIEW_ACTOR_PATH) as Node3D
		if preview_root_before_reset != null
		else null
	)
	var held_item_before_reset: Node3D = (
		preview_root_before_reset.get_meta("preview_held_item", null) as Node3D
		if preview_root_before_reset != null
		else null
	)
	var geometry_before_reset: Dictionary = _capture_handle_transition_geometry(
		motion_node_before_reset,
		actor_before_reset,
		held_item_before_reset,
		slot_id
	)
	_print_handle_transition_geometry(
		"isolated_left_primary_before_reset",
		geometry_before_reset
	)
	var reset_applied: bool = ui.reset_active_draft_to_baseline()
	_check(
		"isolated_left_primary_reset_applied",
		reset_applied
	)
	await _wait_frames(2)
	if not reset_applied:
		return
	var motion_node: CombatAnimationMotionNode = ui.call(
		"_get_active_motion_node"
	) as CombatAnimationMotionNode
	var preview_root: Node3D = ui.preview_subviewport.get_node_or_null(
		"CombatAnimationPreviewRoot3D"
	) as Node3D
	var actor: Node3D = (
		preview_root.get_node_or_null(PREVIEW_ACTOR_PATH) as Node3D
		if preview_root != null
		else null
	)
	var held_item: Node3D = (
		preview_root.get_meta("preview_held_item", null) as Node3D
		if preview_root != null
		else null
	)
	_check("isolated_left_primary_reset_motion_node_available", motion_node != null)
	_check("isolated_left_primary_reset_actor_available", actor != null)
	_check("isolated_left_primary_reset_weapon_available", held_item != null)
	if motion_node == null or actor == null or held_item == null:
		return
	var selected_axial_reposition: float = motion_node.axial_reposition_offset
	var selected_handle_coordinate: float = motion_node.grip_seat_slide_offset
	var geometry_after_reset: Dictionary = _capture_handle_transition_geometry(
		motion_node,
		actor,
		held_item,
		slot_id
	)
	_print_handle_transition_geometry(
		"isolated_left_primary_after_reset",
		geometry_after_reset
	)
	_print_handle_transition_delta(
		"isolated_left_primary_reset_from_prior_state",
		geometry_before_reset,
		geometry_after_reset
	)
	var relationship_after_reset: Dictionary = _capture_surface_relationship_debug(
		actor,
		held_item,
		slot_id
	)
	print(
		"isolated_left_primary_selected_handle_state_after_reset="
		+ "axial_reposition:%.6f,grip_seat_coordinate:%.6f"
		% [selected_axial_reposition, selected_handle_coordinate]
	)
	print("isolated_left_primary_relationship_after_reset=%s" % var_to_str(
		relationship_after_reset
	))
	_check(
		"isolated_left_primary_reset_committed_surface_seat_available",
		bool(relationship_after_reset.get("committed_surface_seat_valid", false))
	)
	_check(
		"isolated_left_primary_reset_committed_digit_packet_available",
		_surface_relationship_has_current_packet(relationship_after_reset)
	)
	_check(
		"isolated_left_primary_selected_handle_coordinate_nonzero",
		not is_zero_approx(selected_handle_coordinate)
	)
	var zero_transition_applied: bool = ui.set_selected_motion_node_grip_seat_slide(
		0.0,
		false,
		false,
		true,
		true,
		false
	)
	await _wait_frames(2)
	preview_root = ui.preview_subviewport.get_node_or_null(
		"CombatAnimationPreviewRoot3D"
	) as Node3D
	actor = (
		preview_root.get_node_or_null(PREVIEW_ACTOR_PATH) as Node3D
		if preview_root != null
		else null
	)
	held_item = (
		preview_root.get_meta("preview_held_item", null) as Node3D
		if preview_root != null
		else null
	)
	var relationship_at_explicit_zero: Dictionary = (
		_capture_surface_relationship_debug(actor, held_item, slot_id)
		if actor != null and held_item != null
		else {}
	)
	var zero_motion_node: CombatAnimationMotionNode = ui.call(
		"_get_active_motion_node"
	) as CombatAnimationMotionNode
	var geometry_at_explicit_zero: Dictionary = _capture_handle_transition_geometry(
		zero_motion_node,
		actor,
		held_item,
		slot_id
	)
	_print_handle_transition_geometry(
		"isolated_left_primary_at_explicit_handle_zero",
		geometry_at_explicit_zero
	)
	var reset_to_zero_delta: Dictionary = _print_handle_transition_delta(
		"isolated_left_primary_reset_to_explicit_zero",
		geometry_after_reset,
		geometry_at_explicit_zero
	)
	_check(
		"isolated_left_primary_explicit_zero_moves_authored_endpoints",
		float(reset_to_zero_delta.get("authored_tip_drift_meters", 0.0))
			> ENDPOINT_POSITION_TOLERANCE_METERS
		or float(reset_to_zero_delta.get("authored_pommel_drift_meters", 0.0))
			> ENDPOINT_POSITION_TOLERANCE_METERS
	)
	print("isolated_left_primary_relationship_at_explicit_handle_zero=%s" % var_to_str(
		relationship_at_explicit_zero
	))
	var reset_surface_seat_context_key: String = String(
		relationship_after_reset.get("surface_seat_context_key", "")
	)
	var zero_surface_seat_context_key: String = String(
		relationship_at_explicit_zero.get("surface_seat_context_key", "")
	)
	_check(
		"isolated_left_primary_explicit_zero_surface_seat_context_changed",
		not reset_surface_seat_context_key.is_empty()
		and not zero_surface_seat_context_key.is_empty()
		and zero_surface_seat_context_key != reset_surface_seat_context_key
	)
	var reset_grasp_context_key: String = String(
		relationship_after_reset.get("grasp_context_key", "")
	)
	var selected_transition_applied: bool = false
	if not is_zero_approx(selected_handle_coordinate):
		selected_transition_applied = ui.set_selected_motion_node_grip_seat_slide(
			selected_handle_coordinate,
			false,
			false,
			true,
			true,
			false
		)
		await _wait_frames(2)
	preview_root = ui.preview_subviewport.get_node_or_null(
		"CombatAnimationPreviewRoot3D"
	) as Node3D
	actor = (
		preview_root.get_node_or_null(PREVIEW_ACTOR_PATH) as Node3D
		if preview_root != null
		else null
	)
	held_item = (
		preview_root.get_meta("preview_held_item", null) as Node3D
		if preview_root != null
		else null
	)
	var relationship_after_explicit_resolve: Dictionary = (
		_capture_surface_relationship_debug(actor, held_item, slot_id)
		if actor != null and held_item != null
		else {}
	)
	var selected_motion_node: CombatAnimationMotionNode = ui.call(
		"_get_active_motion_node"
	) as CombatAnimationMotionNode
	var geometry_after_explicit_resolve: Dictionary = (
		_capture_handle_transition_geometry(
			selected_motion_node,
			actor,
			held_item,
			slot_id
		)
	)
	_print_handle_transition_geometry(
		"isolated_left_primary_after_explicit_zero_to_selected",
		geometry_after_explicit_resolve
	)
	var selected_round_trip_delta: Dictionary = _print_handle_transition_delta(
		"isolated_left_primary_explicit_zero_to_selected_round_trip",
		geometry_after_reset,
		geometry_after_explicit_resolve
	)
	_check(
		"isolated_left_primary_zero_to_selected_authored_tip_restored",
		float(selected_round_trip_delta.get("authored_tip_drift_meters", INF))
			<= ENDPOINT_POSITION_TOLERANCE_METERS
	)
	_check(
		"isolated_left_primary_zero_to_selected_authored_pommel_restored",
		float(selected_round_trip_delta.get("authored_pommel_drift_meters", INF))
			<= ENDPOINT_POSITION_TOLERANCE_METERS
	)
	_check(
		"isolated_left_primary_zero_to_selected_endpoint_origins_restored",
		bool(selected_round_trip_delta.get("authored_endpoint_origins_match", false))
	)
	_check(
		"isolated_left_primary_zero_to_selected_rendered_tip_restored",
		float(selected_round_trip_delta.get("rendered_tip_drift_meters", INF))
			<= CONTACT_RELATIONSHIP_TOLERANCE_METERS
	)
	_check(
		"isolated_left_primary_zero_to_selected_rendered_pommel_restored",
		float(selected_round_trip_delta.get("rendered_pommel_drift_meters", INF))
			<= CONTACT_RELATIONSHIP_TOLERANCE_METERS
	)
	_check(
		"isolated_left_primary_zero_to_selected_contact_restored",
		float(selected_round_trip_delta.get("contact_weapon_local_drift_meters", INF))
			<= CONTACT_RELATIONSHIP_TOLERANCE_METERS
	)
	print(
		"isolated_left_primary_explicit_zero_to_selected_transition="
		+ "zero_applied:%s,selected_applied:%s,selected:%.6f"
		% [
			str(zero_transition_applied),
			str(selected_transition_applied),
			selected_handle_coordinate,
		]
	)
	print("isolated_left_primary_relationship_after_explicit_zero_to_selected=%s" % var_to_str(
		relationship_after_explicit_resolve
	))
	_check(
		"isolated_left_primary_explicit_zero_to_selected_executed",
		zero_transition_applied and selected_transition_applied
	)
	_check(
		"isolated_left_primary_explicit_zero_to_selected_committed_surface_seat_available",
		bool(relationship_after_explicit_resolve.get(
			"committed_surface_seat_valid",
			false
		))
	)
	_check(
		"isolated_left_primary_explicit_zero_to_selected_committed_digit_packet_available",
		_surface_relationship_has_current_packet(relationship_after_explicit_resolve)
	)
	_check(
		"isolated_left_primary_restored_selected_surface_seat_context_matches_reset",
		not reset_surface_seat_context_key.is_empty()
		and String(relationship_after_explicit_resolve.get(
			"surface_seat_context_key",
			""
		)) == reset_surface_seat_context_key
	)
	_check(
		"isolated_left_primary_restored_selected_grasp_context_matches_reset",
		not reset_grasp_context_key.is_empty()
		and String(relationship_after_explicit_resolve.get(
			"grasp_context_key",
			""
		)) == reset_grasp_context_key
	)
	_check(
		"isolated_left_primary_explicit_zero_to_selected_surface_seat_resolved_fresh",
		int(relationship_after_explicit_resolve.get(
			"surface_seat_solve_count",
			0
		)) > int(relationship_after_reset.get("surface_seat_solve_count", 0))
	)
	_check(
		"isolated_left_primary_explicit_zero_to_selected_grasp_resolved_fresh",
		int(relationship_after_explicit_resolve.get("grasp_solve_count", 0))
			> int(relationship_after_reset.get("grasp_solve_count", 0))
	)


func _capture_handle_transition_geometry(
	motion_node: CombatAnimationMotionNode,
	actor: Node3D,
	held_item: Node3D,
	slot_id: StringName
) -> Dictionary:
	var result := {
		"authored_valid": motion_node != null,
		"authored_tip_position_local": Vector3.INF,
		"authored_pommel_position_local": Vector3.INF,
		"authored_tip_position_origin_id": StringName(),
		"authored_pommel_position_origin_id": StringName(),
		"rendered_valid": held_item != null and is_instance_valid(held_item),
		"weapon_transform_world": Transform3D.IDENTITY,
		"rendered_tip_world": Vector3.INF,
		"rendered_pommel_world": Vector3.INF,
		"contact_valid": false,
		"contact_world": Vector3.INF,
		"contact_weapon_local": Vector3.INF,
	}
	if motion_node != null:
		result["authored_tip_position_local"] = motion_node.tip_position_local
		result["authored_pommel_position_local"] = motion_node.pommel_position_local
		result["authored_tip_position_origin_id"] = motion_node.tip_position_origin_id
		result["authored_pommel_position_origin_id"] = motion_node.pommel_position_origin_id
	if held_item != null and is_instance_valid(held_item):
		var weapon_transform_world: Transform3D = held_item.global_transform
		var weapon_tip_local: Vector3 = held_item.get_meta(
			"weapon_tip_local",
			Vector3.INF
		) as Vector3
		var weapon_pommel_local: Vector3 = held_item.get_meta(
			"weapon_pommel_local",
			Vector3.INF
		) as Vector3
		result["weapon_transform_world"] = weapon_transform_world
		if weapon_tip_local.is_finite():
			result["rendered_tip_world"] = weapon_transform_world * weapon_tip_local
		if weapon_pommel_local.is_finite():
			result["rendered_pommel_world"] = weapon_transform_world * weapon_pommel_local
	var contact: Dictionary = _capture_hand_contact_weapon_local(
		actor,
		held_item,
		slot_id
	)
	result["contact_valid"] = bool(contact.get("valid", false))
	result["contact_world"] = contact.get("contact_world", Vector3.INF)
	result["contact_weapon_local"] = contact.get(
		"contact_weapon_local",
		Vector3.INF
	)
	return result


func _print_handle_transition_geometry(label: String, state: Dictionary) -> void:
	var weapon_transform_world: Transform3D = state.get(
		"weapon_transform_world",
		Transform3D.IDENTITY
	) as Transform3D
	print(
		(
			"%s_geometry="
			+ "authored_tip:%s,authored_pommel:%s,tip_origin:%s,pommel_origin:%s,"
			+ "weapon_origin:%s,weapon_rotation:%s,rendered_tip:%s,rendered_pommel:%s,"
			+ "contact_world:%s,contact_weapon_local:%s"
		)
		% [
			label,
			str(state.get("authored_tip_position_local", Vector3.INF)),
			str(state.get("authored_pommel_position_local", Vector3.INF)),
			String(state.get("authored_tip_position_origin_id", StringName())),
			String(state.get("authored_pommel_position_origin_id", StringName())),
			str(weapon_transform_world.origin),
			str(weapon_transform_world.basis.orthonormalized().get_rotation_quaternion()),
			str(state.get("rendered_tip_world", Vector3.INF)),
			str(state.get("rendered_pommel_world", Vector3.INF)),
			str(state.get("contact_world", Vector3.INF)),
			str(state.get("contact_weapon_local", Vector3.INF)),
		]
	)


func _print_handle_transition_delta(
	label: String,
	before: Dictionary,
	after: Dictionary
) -> Dictionary:
	var before_weapon_transform: Transform3D = before.get(
		"weapon_transform_world",
		Transform3D.IDENTITY
	) as Transform3D
	var after_weapon_transform: Transform3D = after.get(
		"weapon_transform_world",
		Transform3D.IDENTITY
	) as Transform3D
	var result := {
		"authored_tip_drift_meters": (
			before.get("authored_tip_position_local", Vector3.INF) as Vector3
		).distance_to(after.get("authored_tip_position_local", Vector3.INF) as Vector3),
		"authored_pommel_drift_meters": (
			before.get("authored_pommel_position_local", Vector3.INF) as Vector3
		).distance_to(after.get("authored_pommel_position_local", Vector3.INF) as Vector3),
		"authored_endpoint_origins_match": (
			StringName(before.get("authored_tip_position_origin_id", StringName()))
				== StringName(after.get("authored_tip_position_origin_id", StringName()))
			and StringName(before.get("authored_pommel_position_origin_id", StringName()))
				== StringName(after.get("authored_pommel_position_origin_id", StringName()))
		),
		"weapon_origin_drift_meters": before_weapon_transform.origin.distance_to(
			after_weapon_transform.origin
		),
		"weapon_rotation_drift_degrees": rad_to_deg(_basis_rotation_delta(
			before_weapon_transform.basis,
			after_weapon_transform.basis
		)),
		"rendered_tip_drift_meters": (
			before.get("rendered_tip_world", Vector3.INF) as Vector3
		).distance_to(after.get("rendered_tip_world", Vector3.INF) as Vector3),
		"rendered_pommel_drift_meters": (
			before.get("rendered_pommel_world", Vector3.INF) as Vector3
		).distance_to(after.get("rendered_pommel_world", Vector3.INF) as Vector3),
		"contact_world_drift_meters": (
			before.get("contact_world", Vector3.INF) as Vector3
		).distance_to(after.get("contact_world", Vector3.INF) as Vector3),
		"contact_weapon_local_drift_meters": (
			before.get("contact_weapon_local", Vector3.INF) as Vector3
		).distance_to(after.get("contact_weapon_local", Vector3.INF) as Vector3),
	}
	print(
		(
			"%s_geometry_delta="
			+ "authored_tip:%.9f,authored_pommel:%.9f,origins_match:%s,"
			+ "weapon_origin:%.9f,weapon_rotation_degrees:%.6f,"
			+ "rendered_tip:%.9f,rendered_pommel:%.9f,"
			+ "contact_world:%.9f,contact_weapon_local:%.9f"
		)
		% [
			label,
			float(result["authored_tip_drift_meters"]),
			float(result["authored_pommel_drift_meters"]),
			str(result["authored_endpoint_origins_match"]),
			float(result["weapon_origin_drift_meters"]),
			float(result["weapon_rotation_drift_degrees"]),
			float(result["rendered_tip_drift_meters"]),
			float(result["rendered_pommel_drift_meters"]),
			float(result["contact_world_drift_meters"]),
			float(result["contact_weapon_local_drift_meters"]),
		]
	)
	return result


func _check_transform_stable(
	label: String,
	expected: Transform3D,
	actual: Transform3D
) -> void:
	var position_error_meters: float = expected.origin.distance_to(actual.origin)
	var rotation_error_degrees: float = rad_to_deg(
		_basis_rotation_delta(expected.basis, actual.basis)
	)
	print(
		"%s_transform_error=position_meters:%.9f,rotation_degrees:%.6f" % [
			label,
			position_error_meters,
			rotation_error_degrees,
		]
	)
	_check(
		"%s_position_stable" % label,
		position_error_meters <= CONTACT_RELATIONSHIP_TOLERANCE_METERS
	)
	_check(
		"%s_rotation_stable" % label,
		rotation_error_degrees <= ROLL_SWING_TOLERANCE_DEGREES
	)


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


func _capture_bone_poses(
	skeleton: Skeleton3D,
	bone_names: Array[StringName]
) -> Dictionary:
	var poses: Dictionary = {}
	for bone_name: StringName in bone_names:
		var bone_index: int = skeleton.find_bone(String(bone_name))
		if bone_index >= 0:
			poses[bone_name] = skeleton.get_bone_pose(bone_index)
	return poses


func _restore_bone_poses(skeleton: Skeleton3D, poses: Dictionary) -> void:
	for bone_name_variant: Variant in poses.keys():
		var bone_name := StringName(bone_name_variant)
		var bone_index: int = skeleton.find_bone(String(bone_name))
		if bone_index >= 0:
			skeleton.set_bone_pose(
				bone_index,
				poses[bone_name_variant] as Transform3D
			)
	skeleton.force_update_all_bone_transforms()


func _print_bone_pose_deltas(
	label: String,
	before: Dictionary,
	after: Dictionary,
	bone_names: Array[StringName]
) -> void:
	for bone_name: StringName in bone_names:
		if not before.has(bone_name) or not after.has(bone_name):
			print("%s_%s=missing" % [label, String(bone_name)])
			continue
		var before_pose: Transform3D = before[bone_name] as Transform3D
		var after_pose: Transform3D = after[bone_name] as Transform3D
		var position_delta_local: Vector3 = after_pose.origin - before_pose.origin
		var rotation_delta_basis: Basis = (
			after_pose.basis.orthonormalized()
			* before_pose.basis.orthonormalized().inverse()
		).orthonormalized()
		var rotation_delta_degrees: float = rad_to_deg(
			_basis_rotation_delta(before_pose.basis, after_pose.basis)
		)
		var rotation_delta_euler_degrees: Vector3 = (
			rotation_delta_basis.get_euler() * (180.0 / PI)
		)
		print(
			"%s_%s=position_delta_local:%s,position_meters:%.9f,rotation_degrees:%.6f,rotation_delta_euler_degrees:%s" % [
				label,
				String(bone_name),
				str(position_delta_local),
				position_delta_local.length(),
				rotation_delta_degrees,
				str(rotation_delta_euler_degrees),
			]
		)


func _capture_surface_relationship_debug(
	actor: Node3D,
	held_item: Node3D,
	slot_id: StringName
) -> Dictionary:
	var result := {
		"committed_surface_seat_valid": false,
		"committed_surface_seat_status": &"unavailable",
		"committed_surface_seat_context_key": "",
		"committed_surface_seat_realized_context_key": "",
		"current_committed_surface_seat_valid": false,
		"current_committed_surface_seat_status": &"unavailable",
		"current_committed_surface_seat_context_key": "",
		"current_committed_surface_seat_realized_context_key": "",
		"surface_seat_valid": false,
		"surface_seat_status": &"unavailable",
		"surface_seat_applied": false,
		"surface_seat_committed": false,
		"surface_seat_applied_correction_count": 0,
		"surface_seat_support_digit_packet_committed": false,
		"surface_seat_reused_current_support_relationship": false,
		"surface_seat_context_key": "",
		"surface_seat_realized_context_key": "",
		"surface_seat_solve_count": 0,
		"surface_seat_terminal": false,
		"surface_seat_grip_axis_ratio_from_span_start": INF,
		"published_grip_axis_ratio_from_span_start": INF,
		"surface_seat_accepted_radial_error_min_meters": -INF,
		"surface_seat_accepted_radial_error_max_meters": INF,
		"surface_seat_max_abs_radial_error_meters": INF,
		"surface_seat_index_radial_error_meters": INF,
		"surface_seat_pinky_radial_error_meters": INF,
		"grasp_state_present": false,
		"grasp_valid": false,
		"grasp_status": &"unavailable",
		"grasp_context_key": "",
		"grasp_solve_count": 0,
		"grasp_committed_rotation_count": 0,
		"grasp_zero_packet_valid": false,
		"grasp_zero_packet_status": &"unavailable",
		"grasp_zero_packet_context_key": "",
		"grasp_zero_packet_rotation_count": 0,
		"surface_seat_live_context_key": "",
		"surface_seat_live_context_matches_realized": false,
		"grasp_current_packet_valid": false,
		"grasp_request_status": &"unavailable",
		"grasp_attempt_status": &"unavailable",
		"grasp_attempt_context_key": "",
		"grasp_last_contact_readiness": 0.0,
		"grasp_solver_attempted": false,
		"grasp_attempt_safe_to_apply": false,
		"grasp_solver_status": &"unavailable",
		"grasp_solver_overlap_limit_respected": false,
		"grasp_solver_solved_digit_count": 0,
		"grasp_solver_degraded_digit_count": 0,
		"grasp_solver_unsafe_digit_count": 0,
		"grasp_digit_statuses": {},
		"grasp_unsafe_digits": [],
	}
	if (
		actor == null
		or held_item == null
		or not is_instance_valid(actor)
		or not is_instance_valid(held_item)
		or not actor.has_method("get_authoring_committed_weapon_surface_seat")
	):
		return result
	var committed_surface_seat: Dictionary = actor.call(
		"get_authoring_committed_weapon_surface_seat",
		slot_id
	) as Dictionary
	result["committed_surface_seat_valid"] = bool(committed_surface_seat.get(
		"valid",
		false
	))
	result["committed_surface_seat_status"] = committed_surface_seat.get(
		"status",
		&"unavailable"
	)
	result["committed_surface_seat_context_key"] = String(
		committed_surface_seat.get("context_key", "")
	)
	result["committed_surface_seat_realized_context_key"] = String(
		committed_surface_seat.get("realized_context_key", "")
	)
	if actor.has_method("get_authoring_current_weapon_surface_seat"):
		var current_committed_surface_seat: Dictionary = actor.call(
			"get_authoring_current_weapon_surface_seat",
			slot_id
		) as Dictionary
		result["current_committed_surface_seat_valid"] = bool(
			current_committed_surface_seat.get("valid", false)
		)
		result["current_committed_surface_seat_status"] = (
			current_committed_surface_seat.get("status", &"unavailable")
		)
		result["current_committed_surface_seat_context_key"] = String(
			current_committed_surface_seat.get("context_key", "")
		)
		result["current_committed_surface_seat_realized_context_key"] = (
			String(current_committed_surface_seat.get(
				"realized_context_key",
				""
			))
		)
	var held_dominant_slot_id := StringName(held_item.get_meta(
		"dominant_contact_slot_id",
		StringName()
	))
	var surface_seat_state_meta: StringName = (
		&"weapon_surface_seat_state"
		if held_dominant_slot_id == StringName() or held_dominant_slot_id == slot_id
		else &"preview_support_hand_surface_seat_state"
	)
	var surface_seat_state: Dictionary = held_item.get_meta(
		surface_seat_state_meta,
		{}
	) as Dictionary
	result["surface_seat_valid"] = bool(surface_seat_state.get("valid", false))
	result["surface_seat_status"] = surface_seat_state.get(
		"status",
		&"unavailable"
	)
	result["surface_seat_applied"] = bool(surface_seat_state.get(
		"applied",
		false
	))
	result["surface_seat_committed"] = bool(surface_seat_state.get(
		"committed",
		false
	))
	result["surface_seat_applied_correction_count"] = int(
		surface_seat_state.get("applied_correction_count", 0)
	)
	result["surface_seat_support_digit_packet_committed"] = bool(
		surface_seat_state.get("support_digit_packet_committed", false)
	)
	result["surface_seat_reused_current_support_relationship"] = bool(
		surface_seat_state.get(
			"reused_current_support_relationship",
			false
		)
	)
	result["surface_seat_context_key"] = String(surface_seat_state.get(
		"context_key",
		""
	))
	result["surface_seat_realized_context_key"] = String(
		surface_seat_state.get("realized_context_key", "")
	)
	result["surface_seat_solve_count"] = int(surface_seat_state.get(
		"solve_count",
		0
	))
	result["surface_seat_terminal"] = bool(surface_seat_state.get(
		"terminal",
		false
	))
	result["surface_seat_grip_axis_ratio_from_span_start"] = float(
		surface_seat_state.get("grip_axis_ratio_from_span_start", INF)
	)
	var published_seat_ratio_meta: StringName = (
		&"preview_primary_grip_seat_axis_ratio_from_span_start"
		if held_dominant_slot_id == StringName() or held_dominant_slot_id == slot_id
		else &"preview_support_grip_seat_axis_ratio_from_span_start"
	)
	result["published_grip_axis_ratio_from_span_start"] = float(
		held_item.get_meta(
			published_seat_ratio_meta,
			INF
		)
	)
	var seat_diagnostics: Dictionary = surface_seat_state.get(
		"diagnostics",
		{}
	) as Dictionary
	var best_seat_candidate: Dictionary = seat_diagnostics.get(
		"best_overall",
		{}
	) as Dictionary
	result["surface_seat_accepted_radial_error_min_meters"] = float(
		seat_diagnostics.get("accepted_radial_error_min_meters", -INF)
	)
	result["surface_seat_accepted_radial_error_max_meters"] = float(
		seat_diagnostics.get("accepted_radial_error_max_meters", INF)
	)
	result["surface_seat_max_abs_radial_error_meters"] = float(
		best_seat_candidate.get("max_abs_radial_error_meters", INF)
	)
	result["surface_seat_index_radial_error_meters"] = float(
		best_seat_candidate.get("index_radial_error_meters", INF)
	)
	result["surface_seat_pinky_radial_error_meters"] = float(
		best_seat_candidate.get("pinky_radial_error_meters", INF)
	)
	var finger_grip_presenter: Object = actor.get("finger_grip_presenter") as Object
	if (
		finger_grip_presenter == null
		or not finger_grip_presenter.has_method("get_surface_grasp_debug_state")
	):
		return result
	var grasp_state: Dictionary = finger_grip_presenter.call(
		"get_surface_grasp_debug_state",
		slot_id
	) as Dictionary
	result["grasp_state_present"] = not grasp_state.is_empty()
	result["grasp_valid"] = bool(grasp_state.get("valid", false))
	result["grasp_status"] = grasp_state.get("status", &"unavailable")
	result["grasp_context_key"] = String(grasp_state.get("context_key", ""))
	result["grasp_solve_count"] = int(grasp_state.get("solve_count", 0))
	result["grasp_committed_rotation_count"] = (
		grasp_state.get("rotations", {}) as Dictionary
	).size()
	if finger_grip_presenter.has_method(
		"get_committed_surface_grasp_zero_packet"
	):
		var zero_packet: Dictionary = finger_grip_presenter.call(
			"get_committed_surface_grasp_zero_packet",
			slot_id
		) as Dictionary
		result["grasp_zero_packet_valid"] = bool(zero_packet.get(
			"valid",
			false
		))
		result["grasp_zero_packet_status"] = zero_packet.get(
			"status",
			&"unavailable"
		)
		result["grasp_zero_packet_context_key"] = String(zero_packet.get(
			"context_key",
			""
		))
		result["grasp_zero_packet_rotation_count"] = (
			zero_packet.get("zero_rotations", {}) as Dictionary
		).size()
	if finger_grip_presenter.has_method(
		"resolve_exact_surface_hand_seat_context_key"
	):
		var actor_skeleton: Skeleton3D = actor.get("skeleton") as Skeleton3D
		var grip_source_lookup: Dictionary = actor.get(
			"finger_grip_source_lookup"
		) as Dictionary
		var grip_guide: Node3D = grip_source_lookup.get(slot_id, null) as Node3D
		if (
			actor_skeleton != null
			and is_instance_valid(actor_skeleton)
			and grip_guide != null
			and is_instance_valid(grip_guide)
		):
			var current_seat_context_key: String = String(
				finger_grip_presenter.call(
					"resolve_exact_surface_hand_seat_context_key",
					actor_skeleton,
					slot_id,
					grip_guide
				)
			)
			result["surface_seat_live_context_key"] = (
				current_seat_context_key
			)
			result["surface_seat_live_context_matches_realized"] = (
				not current_seat_context_key.is_empty()
				and current_seat_context_key == String(result.get(
					"committed_surface_seat_realized_context_key",
					""
				))
			)
	if actor.has_method("has_authoring_current_surface_grip"):
		result["grasp_current_packet_valid"] = bool(actor.call(
			"has_authoring_current_surface_grip",
			slot_id
		))
	result["grasp_request_status"] = grasp_state.get(
		"last_request_status",
		&"unavailable"
	)
	result["grasp_attempt_status"] = grasp_state.get(
		"last_attempt_status",
		&"unavailable"
	)
	result["grasp_attempt_context_key"] = String(grasp_state.get(
		"last_attempt_context_key",
		""
	))
	result["grasp_last_contact_readiness"] = float(grasp_state.get(
		"last_contact_readiness",
		0.0
	))
	result["grasp_attempt_safe_to_apply"] = bool(grasp_state.get(
		"last_attempt_safe_to_apply",
		false
	))
	var grasp_diagnostics: Dictionary = grasp_state.get(
		"last_attempt_diagnostics",
		grasp_state.get("diagnostics", {})
	) as Dictionary
	result["grasp_solver_attempted"] = (
		grasp_diagnostics.has("solver_revision")
		or grasp_diagnostics.has("digit_results")
	)
	result["grasp_solver_status"] = grasp_diagnostics.get(
		"status",
		&"unavailable"
	)
	result["grasp_solver_overlap_limit_respected"] = bool(
		grasp_diagnostics.get("overlap_limit_respected", false)
	)
	result["grasp_solver_solved_digit_count"] = int(grasp_diagnostics.get(
		"solved_digit_count",
		0
	))
	result["grasp_solver_degraded_digit_count"] = int(grasp_diagnostics.get(
		"degraded_digit_count",
		0
	))
	result["grasp_solver_unsafe_digit_count"] = int(grasp_diagnostics.get(
		"unsafe_digit_count",
		0
	))
	var digit_results: Dictionary = grasp_diagnostics.get(
		"digit_results",
		{}
	) as Dictionary
	var digit_statuses: Dictionary = {}
	var unsafe_digits: Array[StringName] = []
	for digit_variant: Variant in digit_results.keys():
		var digit_id := StringName(digit_variant)
		var digit_diagnostics: Dictionary = digit_results.get(
			digit_variant,
			{}
		) as Dictionary
		digit_statuses[digit_id] = {
			"status": digit_diagnostics.get("status", &"unavailable"),
			"overlap_limit_respected": bool(digit_diagnostics.get(
				"overlap_limit_respected",
				false
			)),
			"contacted_section_count": int(digit_diagnostics.get(
				"contacted_section_count",
				0
			)),
			"accepted_section_count": int(digit_diagnostics.get(
				"accepted_section_count",
				0
			)),
			"max_contact_error_meters": float(digit_diagnostics.get(
				"max_contact_error_meters",
				INF
			)),
			"max_penetration_meters": float(digit_diagnostics.get(
				"max_penetration_meters",
				INF
			)),
			"attempted_max_penetration_meters": float(digit_diagnostics.get(
				"attempted_max_penetration_meters",
				digit_diagnostics.get("max_penetration_meters", INF)
			)),
			"unsafe_attempt_rejected": bool(digit_diagnostics.get(
				"unsafe_attempt_rejected",
				false
			)),
			"neutral_fallback_evaluated": bool(digit_diagnostics.get(
				"neutral_fallback_evaluated",
				false
			)),
			"neutral_fallback_safe": bool(digit_diagnostics.get(
				"neutral_fallback_safe",
				false
			)),
			"final_sections": (
				digit_diagnostics.get("final_sections", []) as Array
			).duplicate(true),
			"attempted_final_sections": (
				digit_diagnostics.get("attempted_final_sections", []) as Array
			).duplicate(true),
		}
		if not bool(digit_diagnostics.get("overlap_limit_respected", false)):
			unsafe_digits.append(digit_id)
	result["grasp_digit_statuses"] = digit_statuses
	result["grasp_unsafe_digits"] = unsafe_digits
	return result


func _capture_surface_seat_context_transition(
	actor: Node3D,
	held_item: Node3D,
	slot_id: StringName
) -> Dictionary:
	var result := {
		"valid": false,
		"committed_input_context_key": "",
		"committed_realized_context_key": "",
		"current_realized_relationship": {},
		"current_relationship_matches_realized": false,
		"reconstructed_pre_correction": {},
		"reconstructed_pre_correction_matches_input": false,
	}
	if (
		actor == null
		or held_item == null
		or not is_instance_valid(actor)
		or not is_instance_valid(held_item)
		or not actor.has_method("get_authoring_committed_weapon_surface_seat")
	):
		return result
	var committed_seat: Dictionary = actor.call(
		"get_authoring_committed_weapon_surface_seat",
		slot_id
	) as Dictionary
	result["committed_input_context_key"] = String(committed_seat.get(
		"context_key",
		""
	))
	result["committed_realized_context_key"] = String(committed_seat.get(
		"realized_context_key",
		""
	))
	result["current_realized_relationship"] = (
		_capture_surface_seat_context_constituents(
			actor,
			held_item,
			slot_id
		)
	)
	result["current_relationship_matches_realized"] = (
		not String(result.get("committed_realized_context_key", "")).is_empty()
		and String(
			(result["current_realized_relationship"] as Dictionary).get(
				"seat_context_key",
				""
			)
		) == String(result.get("committed_realized_context_key", ""))
	)
	var seat_correction_variant: Variant = committed_seat.get(
		"seat_correction_grip_local",
		null
	)
	if not seat_correction_variant is Transform3D:
		return result
	var seat_correction_local: Transform3D = (
		seat_correction_variant as Transform3D
	)
	if (
		not seat_correction_local.basis.x.is_finite()
		or not seat_correction_local.basis.y.is_finite()
		or not seat_correction_local.basis.z.is_finite()
		or not seat_correction_local.origin.is_finite()
	):
		return result
	var settled_weapon_transform: Transform3D = held_item.global_transform
	held_item.global_transform = (
		settled_weapon_transform * seat_correction_local.affine_inverse()
	)
	result["reconstructed_pre_correction"] = (
		_capture_surface_seat_context_constituents(
			actor,
			held_item,
			slot_id
		)
	)
	held_item.global_transform = settled_weapon_transform
	var reconstructed_context_key: String = String(
		(result["reconstructed_pre_correction"] as Dictionary).get(
			"seat_context_key",
			""
		)
	)
	result["reconstructed_pre_correction_matches_input"] = (
		not reconstructed_context_key.is_empty()
		and reconstructed_context_key == String(result.get(
			"committed_input_context_key",
			""
		))
	)
	result["valid"] = true
	return result


func _capture_surface_seat_context_constituents(
	actor: Node3D,
	held_item: Node3D,
	slot_id: StringName
) -> Dictionary:
	var result := {
		"valid": false,
		"base_grasp_context_key": "",
		"seat_context_key": "",
		"execution_path_id": StringName(),
		"slot_id": slot_id,
		"guide_role": StringName(),
		"source_wip_id": StringName(),
		"body_signature": "",
		"contact_surface_origin_id": StringName(),
		"shape_resource_instance_id": 0,
		"guide_position_origin_id": StringName(),
		"guide_position_local": Vector3.INF,
		"grip_style_mode": StringName(),
		"dominant_slot_id": StringName(),
		"hand_surface_relationship": [],
		"weapon_transform": Transform3D.IDENTITY,
	}
	if actor == null or held_item == null:
		return result
	var presenter: Object = actor.get("finger_grip_presenter") as Object
	var actor_skeleton: Skeleton3D = actor.get("skeleton") as Skeleton3D
	var source_lookup: Dictionary = actor.get(
		"finger_grip_source_lookup"
	) as Dictionary
	var grip_guide: Node3D = source_lookup.get(slot_id, null) as Node3D
	if (
		presenter == null
		or actor_skeleton == null
		or grip_guide == null
		or not is_instance_valid(grip_guide)
		or not presenter.has_method("_resolve_grip_execution_path_id")
		or not presenter.has_method("_resolve_grip_center_node")
		or not presenter.has_method(
			"_resolve_exact_handle_surface_identity_state"
		)
		or not presenter.has_method("_build_surface_grasp_context_key")
		or not presenter.has_method(
			"_resolve_surface_grasp_hand_relationship_signature"
		)
		or not presenter.has_method(
			"resolve_exact_surface_hand_seat_context_key"
		)
	):
		return result
	var execution_path_id := StringName(presenter.call(
		"_resolve_grip_execution_path_id",
		slot_id,
		grip_guide
	))
	var grip_center: Node3D = presenter.call(
		"_resolve_grip_center_node",
		grip_guide
	) as Node3D
	var exact_surface: Dictionary = presenter.call(
		"_resolve_exact_handle_surface_identity_state",
		grip_center,
		execution_path_id
	) as Dictionary
	if not bool(exact_surface.get("valid", false)):
		return result
	var guide_position_origin_id := StringName(grip_guide.get_meta(
		"grip_guide_position_origin_id",
		grip_guide.get_meta(
			"dominant_hand_position_origin_id",
			grip_guide.get_meta(
				"support_hand_position_origin_id",
				&"WeaponRootOrigin"
			)
		)
	))
	var guide_position_local: Vector3 = grip_guide.get_meta(
		"grip_guide_position_local",
		grip_guide.position
	) as Vector3
	var hand_surface_relationship: Array = presenter.call(
		"_resolve_surface_grasp_hand_relationship_signature",
		actor_skeleton,
		slot_id,
		exact_surface
	) as Array
	result["valid"] = true
	result["base_grasp_context_key"] = String(presenter.call(
		"_build_surface_grasp_context_key",
		actor_skeleton,
		slot_id,
		grip_guide,
		grip_center,
		exact_surface,
		execution_path_id
	))
	result["seat_context_key"] = String(presenter.call(
		"resolve_exact_surface_hand_seat_context_key",
		actor_skeleton,
		slot_id,
		grip_guide
	))
	result["execution_path_id"] = execution_path_id
	result["guide_role"] = StringName(grip_guide.name)
	result["source_wip_id"] = StringName(held_item.get_meta(
		"source_wip_id",
		StringName()
	))
	result["body_signature"] = String(exact_surface.get("body_signature", ""))
	result["contact_surface_origin_id"] = StringName(exact_surface.get(
		"contact_surface_origin_id",
		StringName()
	))
	result["shape_resource_instance_id"] = int(exact_surface.get(
		"shape_resource_instance_id",
		0
	))
	result["guide_position_origin_id"] = guide_position_origin_id
	result["guide_position_local"] = guide_position_local
	result["grip_style_mode"] = StringName(held_item.get_meta(
		"grip_style_mode",
		StringName()
	))
	result["dominant_slot_id"] = StringName(held_item.get_meta(
		"dominant_contact_slot_id",
		StringName()
	))
	result["hand_surface_relationship"] = hand_surface_relationship
	result["weapon_transform"] = held_item.global_transform
	return result


func _surface_relationship_has_current_packet(state: Dictionary) -> bool:
	var committed_surface_seat_context_key: String = String(state.get(
		"committed_surface_seat_context_key",
		""
	))
	var committed_surface_seat_realized_context_key: String = String(state.get(
		"committed_surface_seat_realized_context_key",
		""
	))
	var current_committed_surface_seat_context_key: String = String(state.get(
		"current_committed_surface_seat_context_key",
		""
	))
	var current_committed_surface_seat_realized_context_key: String = String(
		state.get("current_committed_surface_seat_realized_context_key", "")
	)
	var grasp_context_key: String = String(state.get("grasp_context_key", ""))
	var grasp_zero_packet_context_key: String = String(state.get(
		"grasp_zero_packet_context_key",
		""
	))
	var surface_seat_live_context_key: String = String(state.get(
		"surface_seat_live_context_key",
		""
	))
	return (
		bool(state.get("committed_surface_seat_valid", false))
		and bool(state.get("current_committed_surface_seat_valid", false))
		and not committed_surface_seat_context_key.is_empty()
		and current_committed_surface_seat_context_key
			== committed_surface_seat_context_key
		and not committed_surface_seat_realized_context_key.is_empty()
		and current_committed_surface_seat_realized_context_key
			== committed_surface_seat_realized_context_key
		and not surface_seat_live_context_key.is_empty()
		and bool(state.get(
			"surface_seat_live_context_matches_realized",
			false
		))
		and committed_surface_seat_realized_context_key
			== surface_seat_live_context_key
		and bool(state.get("grasp_valid", false))
		and int(state.get("grasp_committed_rotation_count", 0))
			== SUPPORT_DIGIT_BONES.size()
		and bool(state.get("grasp_zero_packet_valid", false))
		and int(state.get("grasp_zero_packet_rotation_count", 0))
			== SUPPORT_DIGIT_BONES.size()
		and not grasp_context_key.is_empty()
		and grasp_context_key == grasp_zero_packet_context_key
		and bool(state.get("grasp_current_packet_valid", false))
	)


func _bone_pose_maps_match(before: Dictionary, after: Dictionary) -> bool:
	if before.size() != after.size() or before.is_empty():
		return false
	for bone_name: Variant in before.keys():
		if not after.has(bone_name):
			return false
		var before_pose: Transform3D = before[bone_name] as Transform3D
		var after_pose: Transform3D = after[bone_name] as Transform3D
		if before_pose.origin.distance_to(after_pose.origin) > POSE_POSITION_TOLERANCE_METERS:
			return false
		if _basis_rotation_delta(before_pose.basis, after_pose.basis) > POSE_ROTATION_TOLERANCE_RADIANS:
			return false
	return true


func _basis_rotation_delta(first: Basis, second: Basis) -> float:
	return first.orthonormalized().get_rotation_quaternion().normalized().angle_to(
		second.orthonormalized().get_rotation_quaternion().normalized()
	)


func _pose_rotation_delta_degrees(
	before: Dictionary,
	after: Dictionary,
	bone_name: StringName
) -> float:
	if not before.has(bone_name) or not after.has(bone_name):
		return INF
	var before_pose: Transform3D = before[bone_name] as Transform3D
	var after_pose: Transform3D = after[bone_name] as Transform3D
	return rad_to_deg(_basis_rotation_delta(before_pose.basis, after_pose.basis))


func _surface_seat_matches(before: Dictionary, after: Dictionary) -> bool:
	if not bool(before.get("valid", false)) or not bool(after.get("valid", false)):
		return false
	if String(before.get("context_key", "")) != String(after.get("context_key", "")):
		return false
	if not is_equal_approx(
		float(before.get("grip_axis_ratio_from_span_start", INF)),
		float(after.get("grip_axis_ratio_from_span_start", -INF))
	):
		return false
	var before_correction: Transform3D = before.get(
		"seat_correction_grip_local",
		Transform3D.IDENTITY
	) as Transform3D
	var after_correction: Transform3D = after.get(
		"seat_correction_grip_local",
		Transform3D.IDENTITY
	) as Transform3D
	return (
		before_correction.origin.distance_to(after_correction.origin)
			<= POSE_POSITION_TOLERANCE_METERS
		and _basis_rotation_delta(before_correction.basis, after_correction.basis)
			<= POSE_ROTATION_TOLERANCE_RADIANS
	)


func _print_compact_primary_seat_state(label: String, state: Dictionary) -> void:
	print("%s=valid:%s,applied:%s,status:%s,input:%s,realized_marked:%s,reused:%s,axial_m:%s" % [
		label,
		str(bool(state.get("valid", false))),
		str(bool(state.get("applied", false))),
		String(state.get("status", StringName())),
		String(state.get("context_key", "")),
		str(bool(state.get("realized_context_marked", false))),
		str(bool(state.get(
			"committed_primary_seat_reused_for_support_activation",
			false
		))),
		str(float(state.get("c0_axial_displacement_meters", INF))),
	])


func _print_compact_support_transaction_passes(passes: Array) -> void:
	print("staged_support_root_transaction_pass_count=%d" % passes.size())
	for pass_variant: Variant in passes:
		var pass_state: Dictionary = pass_variant as Dictionary
		var correction: Transform3D = pass_state.get(
			"correction_local",
			Transform3D.IDENTITY
		) as Transform3D
		print("staged_support_root_transaction_pass=%d,seat:%s,seat_valid:%s,sample:%d,provisional:%s/%d,correction:%s/%s,translation_mm:%.6f,rotation_deg:%.6f,hard_excess:%s" % [
			int(pass_state.get("pass_index", -1)),
			String(pass_state.get("seat_status", StringName())),
			str(bool(pass_state.get("seat_valid", false))),
			int(pass_state.get("candidate_sample_index", -1)),
			str(bool(pass_state.get("provisional_available", false))),
			int(pass_state.get("provisional_sample_index", -1)),
			str(bool(pass_state.get("correction_valid", false))),
			String(pass_state.get("correction_kind", StringName())),
			correction.origin.length() * 1000.0,
			rad_to_deg(_basis_rotation_delta(Basis.IDENTITY, correction.basis)),
			str(float(pass_state.get("hard_law_excess_normalized", INF))),
		])


func _print_pose_map_deltas(
	label: String,
	before: Dictionary,
	after: Dictionary
) -> void:
	for bone_name_variant: Variant in before.keys():
		if not after.has(bone_name_variant):
			print("%s=%s,missing:true" % [label, String(bone_name_variant)])
			continue
		var before_pose: Transform3D = before[bone_name_variant] as Transform3D
		var after_pose: Transform3D = after[bone_name_variant] as Transform3D
		print("%s=%s,position_mm:%.6f,rotation_deg:%.6f" % [
			label,
			String(bone_name_variant),
			before_pose.origin.distance_to(after_pose.origin) * 1000.0,
			rad_to_deg(_basis_rotation_delta(before_pose.basis, after_pose.basis)),
		])


func _wait_frames(frame_count: int) -> void:
	for _frame_index: int in range(maxi(frame_count, 0)):
		await process_frame


func _check(label: String, condition: bool) -> void:
	print("%s=%s" % [label, str(condition)])
	if not condition:
		failures.append(label)


func _fail_and_finish(label: String) -> void:
	_check(label, false)
	_finish()


func _finish() -> void:
	if failures.is_empty():
		print("skill_crafter_weapon_roll_integration_ok=true")
		quit(0)
		return
	for failure: String in failures:
		push_error(failure)
	print("skill_crafter_weapon_roll_integration_ok=false")
	quit(1)
