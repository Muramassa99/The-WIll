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
	ui.open_for(fake, "support realization diagnostic")
	await _frames(2)
	ui.open_saved_wip_with_hand_setup(wip.wip_id, &"hand_right", false, false)
	await _frames(2)
	ui.select_skill_slot(&"skill_slot_1", true)
	await _frames(2)
	ui.reset_active_draft_to_baseline()
	await _frames(2)
	ui.set_selected_motion_node_secondary_grip_seat_slide(0.5, false, false, false, false, false)
	var motion_node: CombatAnimationMotionNode = ui.call("_get_active_motion_node") as CombatAnimationMotionNode
	var preview_root := ui.preview_subviewport.get_node_or_null("CombatAnimationPreviewRoot3D") as Node3D
	var actor := preview_root.get_node_or_null("PreviewActorPivot/PreviewActor") as Node3D
	var held := preview_root.get_meta("preview_held_item", null) as Node3D
	var presenter: RefCounted = ui.preview_presenter
	var fixed_weapon_transform := held.global_transform
	motion_node.two_hand_state = MotionNodeScript.TWO_HAND_STATE_TWO_HAND
	motion_node.normalize()
	presenter.call("_apply_preview_motion_grip_state", held, motion_node, {}, actor)
	presenter.call("_compose_preview_support_grip_anchor_from_accumulator", held, Transform3D.IDENTITY)
	held.global_transform = fixed_weapon_transform
	presenter.call("_apply_preview_resolved_grip_state", held, actor)
	presenter.call("_apply_two_hand_preview_state", actor, held, motion_node)
	presenter.call("_apply_preview_upper_body_authoring_state", actor, held, motion_node, {})
	actor.call("settle_authoring_support_grip_macro_pose_now", 0.0001, true)
	_dump(actor, held, "baseline")
	var guide := held.get_node_or_null("SecondaryGripGuide") as Node3D
	var seat: Dictionary = actor.call("resolve_exact_surface_weapon_seat", &"hand_left", true) as Dictionary
	var correction_state: Dictionary = presenter.call("_resolve_preview_support_transaction_correction", seat, guide) as Dictionary
	var correction := correction_state.get("correction_local", Transform3D.IDENTITY) as Transform3D
	print("correction mm=", correction.origin.length() * 1000.0, " deg=", rad_to_deg(correction.basis.get_rotation_quaternion().get_angle()))
	presenter.call("_compose_preview_support_grip_anchor_from_accumulator", held, correction.affine_inverse())
	presenter.equipped_item_presenter.sync_single_weapon_contact_guidance(actor, held, &"hand_right", true, true, true, true, true)
	_dump(actor, held, "anchor_composed_no_settle")
	actor.call("_update_support_arm_ik_targets", 1.0 / 12.0)
	_dump(actor, held, "target_updated")
	for pass_index: int in range(8):
		actor.call("_apply_authoring_precise_contact_alignment_for_slot", &"hand_left", 0.0001, true)
		_dump(actor, held, "precise_%02d" % (pass_index + 1))
		actor.call("_update_support_arm_ik_targets", 1.0 / 12.0)
	actor.call("_apply_ccd_arm_reach_pose", &"CC_Base_L_Upperarm", &"CC_Base_L_Forearm", &"CC_Base_L_Hand", (actor.get("left_hand_ik_target") as Node3D).global_position, 200, 1.0, 1.0, &"CC_Base_L_Clavicle", 1.0, 0.00001)
	_dump(actor, held, "raw_ccd_200")
	quit()

func _dump(actor: Node3D, held: Node3D, label: String) -> void:
	var skeleton := actor.get_node_or_null("JosieModel/Josie/Skeleton3D") as Skeleton3D
	var support_anchor := held.get_node_or_null("SupportGripAnchor") as Node3D
	var hand_index := skeleton.find_bone("CC_Base_L_Hand")
	var clavicle_index := skeleton.find_bone("CC_Base_L_Clavicle")
	var upperarm_index := skeleton.find_bone("CC_Base_L_Upperarm")
	var forearm_index := skeleton.find_bone("CC_Base_L_Forearm")
	var hand_world := skeleton.global_transform * skeleton.get_bone_global_pose(hand_index).origin
	var clavicle_world := skeleton.global_transform * skeleton.get_bone_global_pose(clavicle_index).origin
	var upperarm_world := skeleton.global_transform * skeleton.get_bone_global_pose(upperarm_index).origin
	var forearm_world := skeleton.global_transform * skeleton.get_bone_global_pose(forearm_index).origin
	var geometric_hand_reach := (
		clavicle_world.distance_to(upperarm_world)
		+ upperarm_world.distance_to(forearm_world)
		+ forearm_world.distance_to(hand_world)
	)
	var align_world: Vector3 = actor.call("resolve_hand_grip_alignment_world_position", &"hand_left") as Vector3
	var target := actor.get("left_hand_ik_target") as Node3D
	var seat: Dictionary = actor.call("resolve_exact_surface_weapon_seat", &"hand_left", true) as Dictionary
	var correction := seat.get("seat_correction_grip_local", seat.get("provisional_seat_correction_grip_local", Transform3D.IDENTITY)) as Transform3D
	print(label, " anchor_align_mm=", support_anchor.global_position.distance_to(align_world) * 1000.0,
		" hand_target_mm=", hand_world.distance_to(target.global_position) * 1000.0,
		" clavicle_target_mm=", clavicle_world.distance_to(target.global_position) * 1000.0,
		" geometric_hand_reach_mm=", geometric_hand_reach * 1000.0,
		" hand_alignment_offset_mm=", hand_world.distance_to(align_world) * 1000.0,
		" max_reach_mm=", float(actor.call("get_usable_arm_chain_reach_meters", &"hand_left")) * 1000.0,
		" seat=", seat.get("status", &""), " sample=", seat.get("candidate_sample_index", seat.get("provisional_candidate_sample_index", -1)),
		" corr_mm=", correction.origin.length() * 1000.0, " corr_deg=", rad_to_deg(correction.basis.get_rotation_quaternion().get_angle()))

func _frames(count: int) -> void:
	for _index: int in range(count):
		await process_frame
