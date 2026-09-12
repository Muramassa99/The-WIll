extends SceneTree

const LibraryScript = preload("res://core/models/player_forge_wip_library_state.gd")
const UIScene = preload("res://scenes/ui/combat_animation_station_ui.tscn")
const MotionNodeEditorScript = preload(
	"res://runtime/combat/combat_animation_motion_node_editor.gd"
)

const TARGET_PROJECT_NAME := "Star_Handle_Testing"
const SUPPORT_SLOT: StringName = &"hand_left"
const PRIMARY_SLOT: StringName = &"hand_right"
const SUPPORT_BONES: Array[StringName] = [
	&"CC_Base_L_Clavicle",
	&"CC_Base_L_Upperarm",
	&"CC_Base_L_Forearm",
	&"CC_Base_L_Hand",
	&"CC_Base_L_Index1",
	&"CC_Base_L_Index2",
	&"CC_Base_L_Pinky1",
	&"CC_Base_L_Pinky2",
]
const PRIMARY_BONES: Array[StringName] = [
	&"CC_Base_R_Clavicle",
	&"CC_Base_R_Upperarm",
	&"CC_Base_R_Forearm",
	&"CC_Base_R_Hand",
]


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
	var mode := "zero"
	var arguments := OS.get_cmdline_user_args()
	if not arguments.is_empty():
		mode = String(arguments[0])
	var source_library: PlayerForgeWipLibraryState = LibraryScript.load_or_create()
	var source_wip: CraftedItemWIP
	for candidate: CraftedItemWIP in source_library.get_saved_wips():
		if candidate != null and candidate.forge_project_name == TARGET_PROJECT_NAME:
			source_wip = candidate
			break
	if source_wip == null:
		print("missing_wip")
		quit(1)
		return
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
	ui.open_for(fake, "support preactivation comparison")
	await _frames(2)
	var open_two_hand := mode == "trace_zero"
	ui.open_saved_wip_with_hand_setup(
		wip.wip_id,
		PRIMARY_SLOT,
		open_two_hand,
		false
	)
	await _frames(2)
	ui.select_skill_slot(&"skill_slot_1", true)
	await _frames(2)
	ui.reset_active_draft_to_baseline()
	await _frames(2)
	var motion_node: CombatAnimationMotionNode = ui.call(
		"_get_active_motion_node"
	) as CombatAnimationMotionNode
	if motion_node == null:
		print("missing_motion_node")
		quit(1)
		return
	if not is_zero_approx(motion_node.weapon_roll_degrees):
		ui.set_selected_motion_node_weapon_roll(
			0.0,
			false,
			false,
			true,
			true,
			false
		)
		await _frames(1)
		motion_node = ui.call("_get_active_motion_node") as CombatAnimationMotionNode
	if mode in ["roll20", "staged_roll20", "staged_roundtrip0"]:
		ui.call(
			"_begin_preview_drag_override",
			motion_node,
			MotionNodeEditorScript.DRAG_TARGET_WEAPON_ROTATION
		)
		ui.motion_node_editor.begin_drag(
			MotionNodeEditorScript.DRAG_TARGET_WEAPON_ROTATION,
			Vector2.ZERO,
			motion_node
		)
		var drag_node := ui.preview_drag_override_node as CombatAnimationMotionNode
		drag_node.weapon_roll_degrees = 20.0
		drag_node.normalize()
		ui.preview_drag_has_moved = true
		ui.call("_refresh_preview_scene")
		ui.motion_node_editor.end_drag()
		ui.call("_finalize_preview_drag", "support preactivation comparison")
		await _frames(1)
	if mode == "staged_roundtrip0":
		motion_node = ui.call("_get_active_motion_node") as CombatAnimationMotionNode
		ui.call(
			"_begin_preview_drag_override",
			motion_node,
			MotionNodeEditorScript.DRAG_TARGET_WEAPON_ROTATION
		)
		ui.motion_node_editor.begin_drag(
			MotionNodeEditorScript.DRAG_TARGET_WEAPON_ROTATION,
			Vector2.ZERO,
			motion_node
		)
		var return_drag_node := ui.preview_drag_override_node as CombatAnimationMotionNode
		return_drag_node.weapon_roll_degrees = 0.0
		return_drag_node.normalize()
		ui.preview_drag_has_moved = true
		ui.call("_refresh_preview_scene")
		ui.motion_node_editor.end_drag()
		ui.call("_finalize_preview_drag", "support round trip comparison")
		await _frames(1)
	var requested_support_coordinate := 0.4 if mode == "prepass_04" else 0.5
	ui.set_selected_motion_node_secondary_grip_seat_slide(
		requested_support_coordinate,
		false,
		false,
		false,
		false,
		false
	)
	await _frames(1)
	_dump(ui, mode)
	if (
		mode in ["staged_zero", "staged_roll20", "staged_roundtrip0", "fullmacro_zero", "prepass_04"]
		or mode.begins_with("candidate_")
		or mode.begins_with("candidate4_")
		or mode.begins_with("rigcandidate_")
		or mode.begins_with("rigcandidate4_")
	):
		_stage_support_activation(ui, mode)
	quit()


func _stage_support_activation(ui: CombatAnimationStationUI, mode: String) -> void:
	var preview_root := ui.preview_subviewport.get_node_or_null(
		"CombatAnimationPreviewRoot3D"
	) as Node3D
	var actor := preview_root.get_node_or_null(
		"PreviewActorPivot/PreviewActor"
	) as Node3D
	var held := preview_root.get_meta("preview_held_item", null) as Node3D
	var motion_node := ui.call("_get_active_motion_node") as CombatAnimationMotionNode
	var presenter: RefCounted = ui.preview_presenter
	var fixed_weapon_transform := held.global_transform
	motion_node.two_hand_state = &"two_hand_two_hand"
	motion_node.normalize()
	presenter.call(
		"_apply_preview_motion_grip_state",
		held,
		motion_node,
		{},
		actor
	)
	presenter.call(
		"_compose_preview_support_grip_anchor_from_accumulator",
		held,
		Transform3D.IDENTITY
	)
	held.global_transform = fixed_weapon_transform
	presenter.call("_apply_preview_resolved_grip_state", held, actor)
	presenter.call("_apply_two_hand_preview_state", actor, held, motion_node)
	print("STAGE=guidance_synced")
	_dump(ui, mode)
	presenter.call(
		"_apply_preview_upper_body_authoring_state",
		actor,
		held,
		motion_node,
		{}
	)
	print("STAGE=upper_body_state_published")
	_dump(ui, mode)
	if mode == "fullmacro_zero":
		actor.call("settle_authoring_grip_relationship_macro_pose_now")
	else:
		actor.call("settle_authoring_support_grip_macro_pose_now")
	print("STAGE=macro_settled_before_transaction")
	_dump(ui, mode)
	if mode.begins_with("candidate_") or mode.begins_with("candidate4_"):
		_seed_support_axial_candidate(presenter, actor, held, mode)
		if mode.begins_with("candidate4_"):
			_apply_one_support_seat_correction(presenter, actor, held)
	elif mode.begins_with("rigcandidate_") or mode.begins_with("rigcandidate4_"):
		var angle_text := (
			mode.trim_prefix("rigcandidate4_")
			if mode.begins_with("rigcandidate4_")
			else mode.trim_prefix("rigcandidate_")
		)
		actor.call(
			"set_authoring_support_contact_roll_candidate_degrees",
			SUPPORT_SLOT,
			float(angle_text)
		)
		actor.call("settle_authoring_support_grip_macro_pose_now")
		print("RIG_CANDIDATE seeded degrees=", float(angle_text))
		if mode.begins_with("rigcandidate4_"):
			_apply_one_support_seat_correction(presenter, actor, held)
	elif mode == "prepass_04":
		_apply_one_support_seat_correction(presenter, actor, held)
	var result: Dictionary = presenter.call(
		"_acquire_preview_support_surface_grip_transaction",
		actor,
		held,
		true
	) as Dictionary
	print("STAGE=transaction_result status=", result.get("status", &""),
		" valid=", result.get("valid", false),
		" committed=", result.get("committed", false))
	for pass_variant: Variant in result.get("transaction_passes", []) as Array:
		var pass_state := pass_variant as Dictionary
		var correction := pass_state.get(
			"correction_local",
			Transform3D.IDENTITY
		) as Transform3D
		print("TX pass=", pass_state.get("pass_index", -1),
			" seat_valid=", pass_state.get("seat_valid", false),
			" sample=", pass_state.get("candidate_sample_index", -1),
			" correction_mm=", correction.origin.length() * 1000.0,
			" correction_deg=", rad_to_deg(
				correction.basis.orthonormalized()
					.get_rotation_quaternion().get_angle()
			))
	var digit_attempt := result.get("support_digit_grip_attempt", {}) as Dictionary
	var digit_diagnostics := digit_attempt.get(
		"last_attempt_diagnostics",
		digit_attempt.get("diagnostics", {})
	) as Dictionary
	print("DIGIT_ATTEMPT status=", digit_attempt.get("status", &""),
		" safe=", digit_diagnostics.get("safe_to_apply", false),
		" solved=", digit_diagnostics.get("solved_digit_count", -1),
		" degraded=", digit_diagnostics.get("degraded_digit_count", -1),
		" unsafe=", digit_diagnostics.get("unsafe_digit_count", -1),
		" error_mm=", float(digit_diagnostics.get(
			"max_contact_error_meters", -1.0
		)) * 1000.0,
		" penetration_mm=", float(digit_diagnostics.get(
			"max_penetration_meters", -1.0
		)) * 1000.0)
	_print_digit_summary("DIGIT_ATTEMPT", digit_diagnostics)
	print("STAGE=after_transaction")
	_dump(ui, mode)


func _seed_support_axial_candidate(
	presenter: RefCounted,
	actor: Node3D,
	held: Node3D,
	mode: String
) -> void:
	var angle_text := (
		mode.trim_prefix("candidate4_")
		if mode.begins_with("candidate4_")
		else mode.trim_prefix("candidate_")
	)
	var angle_degrees := float(angle_text)
	var guide := held.get_node_or_null("SecondaryGripGuide") as Node3D
	var anchor := held.get_node_or_null("SupportGripAnchor") as Node3D
	if guide == null or anchor == null:
		print("CANDIDATE unavailable")
		return
	var tip := held.get_meta("weapon_tip_local", Vector3.ZERO) as Vector3
	var pommel := held.get_meta("weapon_pommel_local", Vector3.ZERO) as Vector3
	var axis := (tip - pommel).normalized()
	var pivot := guide.transform.origin
	var rotation := Basis(axis, deg_to_rad(angle_degrees))
	var candidate := Transform3D(rotation, pivot - rotation * pivot)
	var relationship_key := String(held.get_meta(
		"preview_support_grip_relationship_key",
		""
	))
	anchor.set_meta(
		"preview_support_hand_seat_applied_relationship_key",
		relationship_key
	)
	anchor.set_meta(
		"preview_support_hand_seat_accumulated_correction_local",
		candidate
	)
	anchor.set_meta(
		"preview_support_hand_seat_accumulated_correction_origin_id",
		&"WeaponRootOrigin"
	)
	presenter.call(
		"_compose_preview_support_grip_anchor_from_accumulator",
		held,
		candidate
	)
	presenter.equipped_item_presenter.sync_single_weapon_contact_guidance(
		actor,
		held,
		PRIMARY_SLOT,
		true,
		true,
		true,
		true,
		true
	)
	actor.call("settle_authoring_support_grip_macro_pose_now")
	print("CANDIDATE seeded degrees=", angle_degrees,
		" axis=", axis,
		" pivot=", pivot)


func _apply_one_support_seat_correction(
	presenter: RefCounted,
	actor: Node3D,
	held: Node3D
) -> void:
	var guide := held.get_node_or_null("SecondaryGripGuide") as Node3D
	var anchor := held.get_node_or_null("SupportGripAnchor") as Node3D
	actor.call("invalidate_authoring_active_weapon_surface_seat", SUPPORT_SLOT)
	var seat_attempt := actor.call(
		"resolve_exact_surface_weapon_seat",
		SUPPORT_SLOT,
		true
	) as Dictionary
	var correction_state := presenter.call(
		"_resolve_preview_support_transaction_correction",
		seat_attempt,
		guide
	) as Dictionary
	if not bool(correction_state.get("valid", false)):
		print("CANDIDATE4 prepass correction unavailable")
		return
	var accumulator := anchor.get_meta(
		"preview_support_hand_seat_accumulated_correction_local",
		Transform3D.IDENTITY
	) as Transform3D
	var correction := correction_state.get(
		"correction_local",
		Transform3D.IDENTITY
	) as Transform3D
	accumulator = correction.affine_inverse() * accumulator
	anchor.set_meta(
		"preview_support_hand_seat_accumulated_correction_local",
		accumulator
	)
	presenter.call(
		"_compose_preview_support_grip_anchor_from_accumulator",
		held,
		accumulator
	)
	presenter.equipped_item_presenter.sync_single_weapon_contact_guidance(
		actor,
		held,
		PRIMARY_SLOT,
		true,
		true,
		true,
		true,
		true
	)
	actor.call("settle_authoring_support_grip_macro_pose_now")
	print("CANDIDATE4 prepass correction_mm=", correction.origin.length() * 1000.0,
		" correction_deg=", rad_to_deg(
			correction.basis.orthonormalized()
				.get_rotation_quaternion().get_angle()
		))
	var grasp_state := actor.call(
		"get_authoring_surface_grasp_debug_state",
		SUPPORT_SLOT
	) as Dictionary
	var grasp_diagnostics := grasp_state.get(
		"last_attempt_diagnostics",
		grasp_state.get("diagnostics", {})
	) as Dictionary
	print("GRASP status=", grasp_state.get("status", &""),
		" valid=", grasp_state.get("valid", false))
	_print_digit_summary("GRASP", grasp_diagnostics)


func _print_digit_summary(label: String, diagnostics: Dictionary) -> void:
	var results := diagnostics.get("digit_results", {}) as Dictionary
	for digit_id: StringName in [&"thumb", &"index", &"middle", &"ring", &"pinky"]:
		var digit := results.get(digit_id, {}) as Dictionary
		if digit.is_empty():
			continue
		print(label, " ", digit_id,
			" status=", digit.get("status", &""),
			" valid=", digit.get("valid", false),
			" safe=", digit.get("safe_to_apply", false),
			" accepted=", digit.get("accepted_section_count", -1),
			" contact=", digit.get("contacted_section_count", -1),
			" error_mm=", float(digit.get(
				"attempted_max_contact_error_meters",
				digit.get("max_contact_error_meters", -1.0)
			)) * 1000.0,
			" penetration_mm=", float(digit.get(
				"attempted_max_penetration_meters",
				digit.get("max_penetration_meters", -1.0)
			)) * 1000.0)


func _dump(ui: CombatAnimationStationUI, mode: String) -> void:
	var preview_root := ui.preview_subviewport.get_node_or_null(
		"CombatAnimationPreviewRoot3D"
	) as Node3D
	var actor := preview_root.get_node_or_null(
		"PreviewActorPivot/PreviewActor"
	) as Node3D
	var held := preview_root.get_meta("preview_held_item", null) as Node3D
	var skeleton := actor.get_node_or_null(
		"JosieModel/Josie/Skeleton3D"
	) as Skeleton3D
	var motion_node := ui.call("_get_active_motion_node") as CombatAnimationMotionNode
	var primary_guide := held.get_node_or_null("PrimaryGripGuide") as Node3D
	var secondary_guide := held.get_node_or_null("SecondaryGripGuide") as Node3D
	var primary_anchor := held.get_node_or_null("PrimaryGripAnchor") as Node3D
	var support_anchor := held.get_node_or_null("SupportGripAnchor") as Node3D
	var anatomy: Dictionary = actor.call(
		"resolve_hand_surface_seat_anatomy_state",
		SUPPORT_SLOT
	) as Dictionary
	var finger_sources: Dictionary = actor.get("finger_grip_source_lookup") as Dictionary
	var contact_bases: Dictionary = actor.get(
		"authoring_contact_anchor_basis_lookup"
	) as Dictionary
	var support_source := finger_sources.get(SUPPORT_SLOT, null) as Node3D
	var support_guidance := actor.call("get_arm_guidance_target", SUPPORT_SLOT) as Node3D
	print("MODE=", mode)
	print("MOTION roll=", motion_node.weapon_roll_degrees,
		" two=", motion_node.two_hand_state,
		" primary_slide=", motion_node.grip_seat_slide_offset,
		" axial=", motion_node.axial_reposition_offset,
		" support_slide=", motion_node.secondary_grip_seat_slide_offset)
	_print_transform("WEAPON", held.global_transform)
	_print_node("PRIMARY_GUIDE", primary_guide)
	_print_node("SECONDARY_GUIDE", secondary_guide)
	_print_node("PRIMARY_ANCHOR", primary_anchor)
	_print_node("SUPPORT_ANCHOR", support_anchor)
	print("SOURCES support_id=", support_source.get_instance_id() if support_source != null else 0,
		" support_name=", support_source.name if support_source != null else &"",
		" guidance_id=", support_guidance.get_instance_id() if support_guidance != null else 0,
		" guidance_name=", support_guidance.name if support_guidance != null else &"",
		" support_active=", actor.call("is_support_hand_active", SUPPORT_SLOT))
	_print_basis("CONTACT_BASIS", contact_bases.get(SUPPORT_SLOT, Basis.IDENTITY) as Basis)
	_print_roll_derivation(actor, skeleton, contact_bases)
	print("ANATOMY valid=", anatomy.get("valid", false),
		" index=", anatomy.get("index_point_world", Vector3.INF),
		" pinky=", anatomy.get("pinky_point_world", Vector3.INF),
		" index_close=", anatomy.get("index_authorized_closing_direction_world", Vector3.INF),
		" pinky_close=", anatomy.get("pinky_authorized_closing_direction_world", Vector3.INF))
	var capsules: Array = anatomy.get("ordinary_proximal_capsules", []) as Array
	for capsule_variant: Variant in capsules:
		var capsule := capsule_variant as Dictionary
		print("CAP ", capsule.get("digit_id", &""),
			" start=", capsule.get("segment_start_world", Vector3.INF),
			" end=", capsule.get("segment_end_world", Vector3.INF))
	for bone_name: StringName in SUPPORT_BONES:
		var index := skeleton.find_bone(String(bone_name))
		if index < 0:
			continue
		_print_transform(
			"BONE_%s" % String(bone_name),
			skeleton.global_transform * skeleton.get_bone_global_pose(index)
		)
	for bone_name: StringName in PRIMARY_BONES:
		var index := skeleton.find_bone(String(bone_name))
		if index < 0:
			continue
		_print_transform(
			"BONE_%s" % String(bone_name),
			skeleton.global_transform * skeleton.get_bone_global_pose(index)
		)
	var two_hand_state := actor.get("last_two_hand_solve_result") as Dictionary
	for slot_id: StringName in [PRIMARY_SLOT, SUPPORT_SLOT]:
		var solve_state := two_hand_state.get(slot_id, {}) as Dictionary
		print("REACH slot=", slot_id,
			" before=", solve_state.get("arm_reach_before_meters", -1.0),
			" after=", solve_state.get("arm_reach_after_meters", -1.0),
			" desired=", solve_state.get("desired_target", Vector3.INF),
			" corrected=", solve_state.get("corrected_target", Vector3.INF))
	print("ALIGN support_world=", actor.call(
		"resolve_hand_grip_alignment_world_position",
		SUPPORT_SLOT
	))
	print("SEAT_META primary_ratio=", held.get_meta(
		"preview_primary_grip_seat_axis_ratio_from_span_start",
		INF
	), " support_ratio=", held.get_meta(
		"preview_support_grip_seat_axis_ratio_from_span_start",
		INF
	), " relationship=", held.get_meta(
		"preview_support_grip_relationship_key",
		""
	))


func _print_roll_derivation(
	actor: Node3D,
	skeleton: Skeleton3D,
	contact_bases: Dictionary
) -> void:
	if skeleton == null or not contact_bases.has(SUPPORT_SLOT):
		return
	var contact_basis := (
		contact_bases.get(SUPPORT_SLOT, Basis.IDENTITY) as Basis
	).orthonormalized()
	var axis_local := actor.call(
		"resolve_hand_index_pinky_axis_local",
		SUPPORT_SLOT
	) as Vector3
	var locked_axis := (contact_basis * axis_local).normalized()
	var forearm_to_hand := actor.call(
		"_resolve_hand_anatomical_axis_world",
		&"CC_Base_L_Forearm",
		&"CC_Base_L_Hand"
	) as Vector3
	var hand_index := skeleton.find_bone("CC_Base_L_Hand")
	var hand_basis := (
		skeleton.global_basis * skeleton.get_bone_global_pose(hand_index).basis
	).orthonormalized()
	var neutral_basis := actor.call(
		"_resolve_neutral_hand_world_basis",
		hand_index
	) as Basis
	print("ROLL_DERIVE axis_local=", axis_local,
		" locked=", locked_axis,
		" forearm_y=", forearm_to_hand,
		" forearm_to_contact_y_deg=", _signed_projected_angle_degrees(
			forearm_to_hand, contact_basis.y, locked_axis),
		" forearm_to_hand_y_deg=", _signed_projected_angle_degrees(
			forearm_to_hand, hand_basis.y, locked_axis),
		" forearm_to_neutral_y_deg=", _signed_projected_angle_degrees(
			forearm_to_hand, neutral_basis.y, locked_axis),
		" hand_y_to_contact_y_deg=", _signed_projected_angle_degrees(
			hand_basis.y, contact_basis.y, locked_axis),
		" neutral_y_to_contact_y_deg=", _signed_projected_angle_degrees(
			neutral_basis.y, contact_basis.y, locked_axis))


func _signed_projected_angle_degrees(
	from_world: Vector3,
	to_world: Vector3,
	axis_world: Vector3
) -> float:
	var from_projected := from_world - axis_world * from_world.dot(axis_world)
	var to_projected := to_world - axis_world * to_world.dot(axis_world)
	if (
		from_projected.length_squared() <= 0.000001
		or to_projected.length_squared() <= 0.000001
	):
		return NAN
	from_projected = from_projected.normalized()
	to_projected = to_projected.normalized()
	return rad_to_deg(atan2(
		axis_world.dot(from_projected.cross(to_projected)),
		clampf(from_projected.dot(to_projected), -1.0, 1.0)
	))


func _print_node(label: String, node: Node3D) -> void:
	if node == null:
		print(label, " missing")
		return
	_print_transform(label + "_LOCAL", node.transform)
	_print_transform(label + "_WORLD", node.global_transform)


func _print_transform(label: String, value: Transform3D) -> void:
	print(label, " origin=", value.origin,
		" q=", value.basis.orthonormalized().get_rotation_quaternion())


func _print_basis(label: String, value: Basis) -> void:
	print(label, " q=", value.orthonormalized().get_rotation_quaternion(),
		" x=", value.x, " y=", value.y, " z=", value.z)


func _frames(count: int) -> void:
	for _index: int in range(count):
		await process_frame
