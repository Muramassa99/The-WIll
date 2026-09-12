extends SceneTree

const LibraryScript = preload("res://core/models/player_forge_wip_library_state.gd")
const UIScene = preload("res://scenes/ui/combat_animation_station_ui.tscn")
const TARGET_PROJECT_NAME := "Star_Handle_Testing"
const TEMP_LIBRARY_SAVE_PATH := "C:/WORKSPACE/test_artifacts/diagnose_arm_path_legality_library.tres"
const BODY_RESTRICTION_COLLISION_LAYER := 1 << 25

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
		if candidate != null and candidate.forge_project_name == TARGET_PROJECT_NAME:
			source_wip = candidate
			break
	if source_wip == null:
		print("missing_target_wip")
		quit(1)
		return
	var wip := source_wip.duplicate(true) as CraftedItemWIP
	wip.wip_id = &"diagnose_arm_path_legality_isolated"
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
	ui.open_for(fake, "diagnose_arm_path_legality")
	await _frames(2)
	ui.open_saved_wip_with_hand_setup(wip.wip_id, &"hand_right", true, false)
	await _frames(2)
	ui.select_skill_slot(&"skill_slot_1", true)
	await _frames(2)
	ui.reset_active_draft_to_baseline()
	await _frames(2)
	ui.set_selected_motion_node_secondary_grip_seat_slide(0.3, false, false, false, true, false)
	await _frames(3)
	var preview_root := ui.preview_subviewport.get_node_or_null(
		"CombatAnimationPreviewRoot3D"
	) as Node3D
	var actor := preview_root.get_node_or_null(
		"PreviewActorPivot/PreviewActor"
	) as Node3D
	if actor.has_method("get_body_self_collision_debug_state"):
		print(
			"BODY_SELF=",
			actor.call("get_body_self_collision_debug_state") as Dictionary
		)
	_dump_slot(actor, &"hand_right")
	_dump_slot(actor, &"hand_left")
	quit()


func _frames(count: int) -> void:
	for _index: int in range(count):
		await process_frame
		await physics_frame


func _dump_slot(actor: Node3D, slot_id: StringName) -> void:
	var skeleton: Skeleton3D = actor.get("skeleton") as Skeleton3D
	var restriction_root: Node3D = actor.get("body_restriction_root") as Node3D
	var constraint_solver: Object = actor.get("hand_target_constraint_solver") as Object
	var summary: Dictionary = actor.get("last_two_hand_solve_result") as Dictionary
	var slot_summary: Dictionary = summary.get(slot_id, {}) as Dictionary
	var upperarm_name: StringName = (
		&"CC_Base_R_Upperarm" if slot_id == &"hand_right" else &"CC_Base_L_Upperarm"
	)
	var forearm_name: StringName = (
		&"CC_Base_R_Forearm" if slot_id == &"hand_right" else &"CC_Base_L_Forearm"
	)
	var hand_name: StringName = (
		&"CC_Base_R_Hand" if slot_id == &"hand_right" else &"CC_Base_L_Hand"
	)
	var shoulder_world := _bone_world(skeleton, upperarm_name)
	var elbow_world := _bone_world(skeleton, forearm_name)
	var hand_world := _bone_world(skeleton, hand_name)
	var desired_world: Vector3 = slot_summary.get("desired_target", hand_world) as Vector3
	var corrected_world: Vector3 = slot_summary.get("corrected_target", desired_world) as Vector3
	var exclusions: Array = constraint_solver.call(
		"build_arm_self_query_exclusions",
		restriction_root,
		slot_id
	) as Array
	print("SLOT=", slot_id, " SUMMARY=", slot_summary)
	_print_ray_hit(restriction_root, hand_world, desired_world, exclusions, "hand_to_desired")
	_print_ray_hit(restriction_root, hand_world, corrected_world, exclusions, "hand_to_corrected")
	_print_ray_hit(restriction_root, shoulder_world, desired_world, exclusions, "shoulder_to_desired")
	_print_ray_hit(restriction_root, shoulder_world, corrected_world, exclusions, "shoulder_to_corrected")
	_print_ray_hit(restriction_root, shoulder_world, elbow_world, exclusions, "actual_upperarm")
	_print_ray_hit(restriction_root, elbow_world, hand_world, exclusions, "actual_forearm")


func _bone_world(skeleton: Skeleton3D, bone_name: StringName) -> Vector3:
	var bone_index: int = skeleton.find_bone(String(bone_name))
	if bone_index < 0:
		return Vector3.ZERO
	return skeleton.to_global(skeleton.get_bone_global_pose(bone_index).origin)


func _print_ray_hit(
	restriction_root: Node3D,
	from_world: Vector3,
	to_world: Vector3,
	exclusions: Array,
	label: String
) -> void:
	var query := PhysicsRayQueryParameters3D.create(
		from_world,
		to_world,
		BODY_RESTRICTION_COLLISION_LAYER
	)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	query.hit_from_inside = true
	query.exclude = exclusions
	var hit: Dictionary = restriction_root.get_world_3d().direct_space_state.intersect_ray(query)
	var collider: Object = hit.get("collider") as Object
	var collider_name := ""
	var attachment_name := ""
	var region := ""
	if collider is Node:
		collider_name = String((collider as Node).name)
		var attachment: Node = (collider as Node).get_parent()
		if attachment != null:
			attachment_name = String(attachment.name)
			region = String(attachment.get_meta("proxy_region", ""))
	print(
		"RAY ", label,
		" distance=", from_world.distance_to(to_world),
		" from=", from_world,
		" to=", to_world,
		" hit=", not hit.is_empty(),
		" hit_distance=", (
			from_world.distance_to(hit.get("position", from_world) as Vector3)
			if not hit.is_empty()
			else -1.0
		),
		" collider=", collider_name,
		" attachment=", attachment_name,
		" region=", region,
		" position=", hit.get("position", Vector3.ZERO)
	)
