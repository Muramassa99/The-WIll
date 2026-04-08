extends SceneTree

const RigScene = preload("res://scenes/player/player_humanoid_rig.tscn")
const RESULT_FILE_PATH := "C:/WORKSPACE/player_ik_baseline_results.txt"

func _init() -> void:
	call_deferred("_run_verification")

func _run_verification() -> void:
	var world_root := Node3D.new()
	root.add_child(world_root)

	var floor_body := StaticBody3D.new()
	floor_body.name = "Floor"
	world_root.add_child(floor_body)

	var floor_shape := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(12.0, 1.0, 12.0)
	floor_shape.shape = floor_box
	floor_shape.position = Vector3(0.0, -0.5, 0.0)
	floor_body.add_child(floor_shape)

	var rig_root: Node = RigScene.instantiate()
	world_root.add_child(rig_root)
	var rig := rig_root as PlayerHumanoidRig
	if rig != null:
		rig.position = Vector3(0.0, 0.9, 0.0)
		rig.enable_arm_ik = true
		rig.enable_foot_ik = true

	await process_frame
	await physics_frame
	await process_frame

	var skeleton: Skeleton3D = rig.get_node_or_null("JosieModel/Josie/Skeleton3D") as Skeleton3D if rig != null else null
	var right_hand_index: int = skeleton.find_bone("CC_Base_R_Hand") if skeleton != null else -1
	var right_foot_index: int = skeleton.find_bone("CC_Base_R_Foot") if skeleton != null else -1

	var right_hand_before: Vector3 = _get_bone_world_position(skeleton, right_hand_index)
	var right_foot_before: Vector3 = _get_bone_world_position(skeleton, right_foot_index)

	if rig != null:
		rig.update_locomotion_state(0.0, 5.5, true, 0.0, false)
		rig.set_aim_follow_target(deg_to_rad(26.0), deg_to_rad(-10.0))
		rig.set_hand_grip_active(&"hand_right", true)
		rig._refresh_runtime_ik_influences()

	for _i in range(18):
		await physics_frame
		await process_frame

	var right_arm_ik: TwoBoneIK3D = skeleton.get_node_or_null("RightArmIK") as TwoBoneIK3D if skeleton != null else null
	var left_arm_ik: TwoBoneIK3D = skeleton.get_node_or_null("LeftArmIK") as TwoBoneIK3D if skeleton != null else null
	var right_leg_ik: TwoBoneIK3D = skeleton.get_node_or_null("RightLegIK") as TwoBoneIK3D if skeleton != null else null
	var left_leg_ik: TwoBoneIK3D = skeleton.get_node_or_null("LeftLegIK") as TwoBoneIK3D if skeleton != null else null

	var right_hand_target: Node3D = rig.get_node_or_null("IkTargets/RightHandIkTarget") as Node3D if rig != null else null
	var right_hand_anchor: Node3D = rig.get_right_hand_item_anchor() if rig != null else null
	var right_foot_target: Node3D = rig.get_node_or_null("IkTargets/RightFootIkTarget") as Node3D if rig != null else null

	var post_modifier_hand: Vector3 = Vector3.ZERO
	var post_modifier_foot: Vector3 = Vector3.ZERO
	if right_arm_ik != null:
		await right_arm_ik.modification_processed
		post_modifier_hand = _get_bone_world_position(skeleton, right_hand_index)
	if right_leg_ik != null:
		await right_leg_ik.modification_processed
		post_modifier_foot = _get_bone_world_position(skeleton, right_foot_index)

	var right_hand_after: Vector3 = post_modifier_hand if post_modifier_hand != Vector3.ZERO else _get_bone_world_position(skeleton, right_hand_index)
	var right_foot_after: Vector3 = post_modifier_foot if post_modifier_foot != Vector3.ZERO else _get_bone_world_position(skeleton, right_foot_index)

	var right_hand_delta: float = right_hand_before.distance_to(right_hand_after)
	var right_foot_delta: float = right_foot_before.distance_to(right_foot_after)
	var right_hand_distance_to_target: float = right_hand_after.distance_to(right_hand_target.global_position) if right_hand_target != null else -1.0
	var right_anchor_distance_to_target: float = right_hand_anchor.global_position.distance_to(right_hand_target.global_position) if right_hand_anchor != null and right_hand_target != null else -1.0
	var right_foot_distance_to_target: float = right_foot_after.distance_to(right_foot_target.global_position) if right_foot_target != null else -1.0
	var right_foot_target_floor_delta: float = absf((right_foot_target.global_position.y if right_foot_target != null else -999.0) - (rig.foot_ik_target_lift_meters if rig != null else 0.0))

	var lines: PackedStringArray = []
	lines.append("rig_loaded=%s" % str(rig != null))
	lines.append("skeleton_loaded=%s" % str(skeleton != null))
	lines.append("right_arm_ik_exists=%s" % str(right_arm_ik != null))
	lines.append("left_arm_ik_exists=%s" % str(left_arm_ik != null))
	lines.append("right_leg_ik_exists=%s" % str(right_leg_ik != null))
	lines.append("left_leg_ik_exists=%s" % str(left_leg_ik != null))
	lines.append("right_hand_target_exists=%s" % str(right_hand_target != null))
	lines.append("right_foot_target_exists=%s" % str(right_foot_target != null))
	lines.append("arm_ik_enabled_for_test=%s" % str(rig != null and rig.enable_arm_ik))
	lines.append("foot_ik_enabled_for_test=%s" % str(rig != null and rig.enable_foot_ik))
	lines.append("right_arm_target_path=%s" % String(right_arm_ik.get_target_node(0) if right_arm_ik != null else NodePath()))
	lines.append("right_arm_target_resolves=%s" % str(right_arm_ik != null and right_arm_ik.get_node_or_null(right_arm_ik.get_target_node(0)) != null))
	lines.append("right_leg_target_path=%s" % String(right_leg_ik.get_target_node(0) if right_leg_ik != null else NodePath()))
	lines.append("right_leg_target_resolves=%s" % str(right_leg_ik != null and right_leg_ik.get_node_or_null(right_leg_ik.get_target_node(0)) != null))
	lines.append("right_arm_influence=%s" % str(snapped(right_arm_ik.influence if right_arm_ik != null else -1.0, 0.0001)))
	lines.append("left_arm_influence=%s" % str(snapped(left_arm_ik.influence if left_arm_ik != null else -1.0, 0.0001)))
	lines.append("right_leg_influence=%s" % str(snapped(right_leg_ik.influence if right_leg_ik != null else -1.0, 0.0001)))
	lines.append("right_hand_moved=%s" % str(right_hand_delta > 0.01))
	lines.append("right_foot_moved=%s" % str(right_foot_delta > 0.01))
	lines.append("right_hand_delta=%s" % str(snapped(right_hand_delta, 0.0001)))
	lines.append("right_foot_delta=%s" % str(snapped(right_foot_delta, 0.0001)))
	lines.append("right_hand_distance_to_target=%s" % str(snapped(right_hand_distance_to_target, 0.0001)))
	lines.append("right_anchor_distance_to_target=%s" % str(snapped(right_anchor_distance_to_target, 0.0001)))
	lines.append("right_foot_distance_to_target=%s" % str(snapped(right_foot_distance_to_target, 0.0001)))
	lines.append("right_hand_near_target=%s" % str(right_anchor_distance_to_target >= 0.0 and right_anchor_distance_to_target < 0.12))
	lines.append("right_foot_near_target=%s" % str(right_foot_distance_to_target >= 0.0 and right_foot_distance_to_target < 0.12))
	lines.append("right_foot_target_on_floor=%s" % str(right_foot_target_floor_delta < 0.08))
	lines.append("right_foot_target_floor_delta=%s" % str(snapped(right_foot_target_floor_delta, 0.0001)))

	var file: FileAccess = FileAccess.open(RESULT_FILE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()

	quit()

func _get_bone_world_position(skeleton: Skeleton3D, bone_idx: int) -> Vector3:
	if skeleton == null or bone_idx < 0:
		return Vector3.ZERO
	return skeleton.to_global(skeleton.get_bone_global_pose(bone_idx).origin)
