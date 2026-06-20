extends SceneTree

const PlayerScene = preload("res://scenes/player/player_character.tscn")
const RESULT_FILE_PATH := "C:/WORKSPACE/player_idle_leg_diagnosis.txt"

func _initialize() -> void:
	call_deferred("_run_diagnosis")

func _run_diagnosis() -> void:
	var with_ik: Dictionary = await _capture_idle_leg_state(true)
	var without_ik: Dictionary = await _capture_idle_leg_state(false)

	var lines: PackedStringArray = []
	lines.append("with_ik_loaded=%s" % str(with_ik.get("loaded", false)))
	lines.append("without_ik_loaded=%s" % str(without_ik.get("loaded", false)))
	lines.append("with_ik_hip_y=%s" % str(snapped(float(with_ik.get("hip_y", -1.0)), 0.0001)))
	lines.append("without_ik_hip_y=%s" % str(snapped(float(without_ik.get("hip_y", -1.0)), 0.0001)))
	lines.append("with_ik_right_foot_y=%s" % str(snapped(float(with_ik.get("right_foot_y", -1.0)), 0.0001)))
	lines.append("without_ik_right_foot_y=%s" % str(snapped(float(without_ik.get("right_foot_y", -1.0)), 0.0001)))
	lines.append("with_ik_right_target_y=%s" % str(snapped(float(with_ik.get("right_target_y", -1.0)), 0.0001)))
	lines.append("without_ik_right_target_y=%s" % str(snapped(float(without_ik.get("right_target_y", -1.0)), 0.0001)))
	lines.append("with_ik_right_leg_influence=%s" % str(snapped(float(with_ik.get("right_leg_influence", -1.0)), 0.0001)))
	lines.append("without_ik_right_leg_influence=%s" % str(snapped(float(without_ik.get("right_leg_influence", -1.0)), 0.0001)))
	lines.append("with_ik_right_foot_distance_to_target=%s" % str(snapped(float(with_ik.get("right_foot_distance_to_target", -1.0)), 0.0001)))
	lines.append("without_ik_right_foot_distance_to_target=%s" % str(snapped(float(without_ik.get("right_foot_distance_to_target", -1.0)), 0.0001)))
	lines.append("hip_lowered_by_ik=%s" % str(float(with_ik.get("hip_y", 0.0)) < float(without_ik.get("hip_y", 0.0)) - 0.01))
	lines.append("foot_target_hovering_above_floor=%s" % str(absf(float(with_ik.get("right_target_y", 0.0)) - float(with_ik.get("target_lift", 0.0))) < 0.01))
	lines.append("right_foot_higher_with_ik=%s" % str(float(with_ik.get("right_foot_y", 0.0)) > float(without_ik.get("right_foot_y", 0.0)) + 0.005))

	DirAccess.make_dir_recursive_absolute(RESULT_FILE_PATH.get_base_dir())
	var file: FileAccess = FileAccess.open(RESULT_FILE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()

	quit()

func _capture_idle_leg_state(enable_foot_ik: bool) -> Dictionary:
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
	if player == null:
		world_root.queue_free()
		await process_frame
		return {"loaded": false}

	player.position = Vector3.ZERO
	await process_frame
	await physics_frame
	await process_frame

	var rig: PlayerHumanoidRig = player.humanoid_rig as PlayerHumanoidRig
	if rig == null:
		world_root.queue_free()
		await process_frame
		return {"loaded": false}

	rig.enable_arm_ik = false
	rig.enable_foot_ik = enable_foot_ik
	rig.update_locomotion_state(0.0, 5.5, true, 0.0, false)
	rig._refresh_runtime_ik_influences()

	for _i in range(18):
		await physics_frame
		await process_frame

	var skeleton: Skeleton3D = rig.get_node_or_null("JosieModel/Josie/Skeleton3D") as Skeleton3D
	var hip_index: int = skeleton.find_bone("CC_Base_Hip") if skeleton != null else -1
	var right_foot_index: int = skeleton.find_bone("CC_Base_R_Foot") if skeleton != null else -1
	var right_target: Node3D = rig.get_node_or_null("IkTargets/RightFootIkTarget") as Node3D
	var right_leg_ik: TwoBoneIK3D = skeleton.get_node_or_null("RightLegIK") as TwoBoneIK3D if skeleton != null else null
	if enable_foot_ik and right_leg_ik != null:
		for _i in range(8):
			await physics_frame
			await process_frame
	var hip_position: Vector3 = _get_bone_world_position(skeleton, hip_index)
	var right_foot_position: Vector3 = _get_bone_world_position(skeleton, right_foot_index)

	var result := {
		"loaded": true,
		"hip_y": hip_position.y,
		"right_foot_y": right_foot_position.y,
		"right_target_y": right_target.global_position.y if right_target != null else -1.0,
		"right_leg_influence": right_leg_ik.influence if right_leg_ik != null else -1.0,
		"right_foot_distance_to_target": right_foot_position.distance_to(right_target.global_position) if right_target != null else -1.0,
		"target_lift": rig.foot_ik_target_lift_meters
	}

	world_root.queue_free()
	await process_frame
	return result

func _get_bone_world_position(skeleton: Skeleton3D, bone_idx: int) -> Vector3:
	if skeleton == null or bone_idx < 0:
		return Vector3.ZERO
	return skeleton.to_global(skeleton.get_bone_global_pose(bone_idx).origin)
