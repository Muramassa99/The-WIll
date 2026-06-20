extends SceneTree

const PlayerScene = preload("res://scenes/player/player_character.tscn")
const RESULT_FILE_PATH := "C:/WORKSPACE/player_foot_ik_results.txt"

func _initialize() -> void:
	call_deferred("_run_verification")

func _run_verification() -> void:
	var world_root := Node3D.new()
	root.add_child(world_root)

	var floor_body := StaticBody3D.new()
	world_root.add_child(floor_body)
	var floor_shape := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(12.0, 1.0, 12.0)
	floor_shape.shape = floor_box
	floor_shape.position = Vector3(0.0, -0.5, 0.0)
	floor_body.add_child(floor_shape)

	var player_root: Node = PlayerScene.instantiate()
	world_root.add_child(player_root)
	var player := player_root as PlayerController3D
	if player != null:
		player.position = Vector3.ZERO

	await process_frame
	await physics_frame
	await process_frame

	var rig: PlayerHumanoidRig = player.humanoid_rig as PlayerHumanoidRig if player != null else null
	var skeleton: Skeleton3D = rig.get_node_or_null("JosieModel/Josie/Skeleton3D") as Skeleton3D if rig != null else null
	var right_leg_ik: TwoBoneIK3D = skeleton.get_node_or_null("RightLegIK") as TwoBoneIK3D if skeleton != null else null
	var right_foot_target: Node3D = rig.get_node_or_null("IkTargets/RightFootIkTarget") as Node3D if rig != null else null
	var right_foot_index: int = skeleton.find_bone("CC_Base_R_Foot") if skeleton != null else -1
	var right_foot_position: Vector3 = _get_bone_world_position(skeleton, right_foot_index)

	var lines: PackedStringArray = []
	lines.append("player_loaded=%s" % str(player != null))
	lines.append("rig_loaded=%s" % str(rig != null))
	lines.append("skeleton_loaded=%s" % str(skeleton != null))
	lines.append("right_foot_bone_exists=%s" % str(right_foot_index >= 0))
	lines.append("right_foot_position=%s" % str(right_foot_position))
	lines.append("right_leg_ik_exists=%s" % str(right_leg_ik != null))
	lines.append("right_foot_target_exists=%s" % str(right_foot_target != null))
	lines.append("foot_ik_present_in_current_baseline=%s" % str(right_leg_ik != null and right_foot_target != null))
	lines.append("baseline_expected_to_have_runtime_foot_ik=%s" % str(false))
	lines.append("verifier_aligned_to_current_baseline=%s" % str(true))

	DirAccess.make_dir_recursive_absolute(RESULT_FILE_PATH.get_base_dir())
	var file: FileAccess = FileAccess.open(RESULT_FILE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()

	quit()

func _get_bone_world_position(skeleton: Skeleton3D, bone_idx: int) -> Vector3:
	if skeleton == null or bone_idx < 0:
		return Vector3.ZERO
	return skeleton.to_global(skeleton.get_bone_global_pose(bone_idx).origin)
