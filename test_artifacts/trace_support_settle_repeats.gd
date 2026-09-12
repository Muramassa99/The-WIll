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
	ui.open_for(fake, "trace")
	await _frames(2)
	ui.open_saved_wip_with_hand_setup(wip.wip_id, &"hand_right", false, false)
	await _frames(2)
	ui.select_skill_slot(&"skill_slot_1", true)
	await _frames(2)
	ui.reset_active_draft_to_baseline()
	await _frames(1)
	ui.set_selected_motion_node_two_hand_state(
		MotionNodeScript.TWO_HAND_STATE_TWO_HAND,
		false,
		false,
		false,
		true,
		false
	)
	await _frames(1)
	var preview_root := ui.preview_subviewport.get_node_or_null(
		"CombatAnimationPreviewRoot3D"
	) as Node3D
	var actor := preview_root.get_node_or_null(
		"PreviewActorPivot/PreviewActor"
	) as Node3D
	var held := preview_root.get_meta("preview_held_item", null) as Node3D
	_dump(ui, actor, held, "initial")
	for pass_index: int in range(2):
		actor.call("settle_authoring_support_grip_macro_pose_now", 0.0001, true)
		_dump(ui, actor, held, "pass_%02d" % (pass_index + 1))
	quit()

func _dump(
	ui: CombatAnimationStationUI,
	actor: Node3D,
	held: Node3D,
	label: String
) -> void:
	var two: Dictionary = actor.get("last_two_hand_solve_result")
	var support: Dictionary = two.get(&"hand_left", {}) as Dictionary
	var seat: Dictionary = actor.call(
		"resolve_exact_surface_weapon_seat",
		&"hand_left",
		true
	) as Dictionary
	var best: Dictionary = (
		seat.get("diagnostics", {}) as Dictionary
	).get("best_overall", {}) as Dictionary
	var dbg := ui.get_preview_debug_state()
	var skeleton := actor.get_node_or_null("JosieModel/Josie/Skeleton3D") as Skeleton3D
	var hand_index := skeleton.find_bone("CC_Base_L_Hand")
	var upper_index := skeleton.find_bone("CC_Base_L_Upperarm")
	var hand_world := skeleton.global_transform * skeleton.get_bone_global_pose(hand_index).origin
	var upper_world := skeleton.global_transform * skeleton.get_bone_global_pose(upper_index).origin
	var align_world: Vector3 = actor.call(
		"resolve_hand_grip_alignment_world_position",
		&"hand_left"
	) as Vector3
	var guide := actor.call("get_arm_guidance_target", &"hand_left") as Node3D
	print(
		label,
		" align=", dbg.get("support_grip_alignment_error_meters", -1.0),
		" reach=", support.get("arm_reach_before_meters", -1.0),
		"/", support.get("arm_reach_after_meters", -1.0),
		" clamped=", support.get("arm_reach_clamped", false),
		" seat=", seat.get("status", &""),
		" radial=", best.get("max_abs_radial_error_meters", -1.0),
		" safe=", best.get("ordinary_proximal_capsules_safe", false),
		" support_anchor=", (held.get_node_or_null("SupportGripAnchor") as Node3D).global_position,
		" guide=", guide.global_position,
		" desired=", support.get("desired_target", Vector3.ZERO),
		" corrected=", support.get("corrected_target", Vector3.ZERO),
		" hand=", hand_world,
		" align_point=", align_world,
		" upper=", upper_world
	)

func _frames(count: int) -> void:
	for _index: int in range(count):
		await process_frame
