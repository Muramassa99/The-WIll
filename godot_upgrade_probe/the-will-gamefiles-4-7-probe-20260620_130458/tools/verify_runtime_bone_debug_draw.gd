extends SceneTree

const PlayerHumanoidRigScene: PackedScene = preload("res://scenes/player/player_humanoid_rig.tscn")

const RESULT_FILE_PATH := "C:/WORKSPACE/DEBUG-LOGS/verify_runtime_bone_debug_draw_results.txt"

func _init() -> void:
	call_deferred("_run_verification")

func _run_verification() -> void:
	var rig = PlayerHumanoidRigScene.instantiate()
	root.add_child(rig)
	await process_frame
	await process_frame

	var skeleton: Skeleton3D = rig.get_node_or_null("JosieModel/Josie/Skeleton3D") as Skeleton3D
	var modifier: SkeletonModifier3D = skeleton.get_node_or_null("RuntimeBoneDebugModifier") as SkeletonModifier3D if skeleton != null else null
	var body_sync_modifier: SkeletonModifier3D = skeleton.get_node_or_null("RuntimeBodyRestrictionSyncModifier") as SkeletonModifier3D if skeleton != null else null
	rig.call("set_runtime_bone_debug_visible", true)
	rig.call("process_runtime_bone_debug_modifier_frame", 1.0 / 60.0)
	var enabled_state: Dictionary = rig.call("get_runtime_bone_debug_state") as Dictionary
	var debug_root: Node3D = rig.get_node_or_null("RuntimeBoneDebugRoot") as Node3D
	var line_mesh: MeshInstance3D = debug_root.get_node_or_null("BoneLines") as MeshInstance3D if debug_root != null else null
	var axis_mesh: MeshInstance3D = debug_root.get_node_or_null("BoneAxes") as MeshInstance3D if debug_root != null else null
	var forearm_attachment_error: float = _measure_synced_attachment_error(rig, skeleton)
	var modifier_exists: bool = modifier != null
	var modifier_active: bool = modifier != null and modifier.active
	var body_sync_modifier_exists: bool = body_sync_modifier != null
	var body_sync_modifier_active: bool = body_sync_modifier != null and body_sync_modifier.active
	var body_sync_attachment_aligned: bool = forearm_attachment_error >= 0.0 and forearm_attachment_error <= 0.0001
	var root_visible: bool = debug_root != null and debug_root.visible
	var line_segments_positive: bool = int(enabled_state.get("line_segment_count", 0)) > 0
	var axis_count_positive: bool = int(enabled_state.get("axis_bone_count", 0)) > 0
	var reference_found: bool = bool(enabled_state.get("reference_bone_found", false))
	var line_mesh_visible: bool = line_mesh != null and line_mesh.visible
	var axis_mesh_visible: bool = axis_mesh != null and axis_mesh.visible

	rig.call("set_runtime_bone_debug_visible", false)
	var disabled_state: Dictionary = rig.call("get_runtime_bone_debug_state") as Dictionary
	var disabled_hidden: bool = debug_root != null and not debug_root.visible and not bool(disabled_state.get("visible", true))
	var all_checks_passed: bool = (
		skeleton != null
		and modifier_exists
		and modifier_active
		and body_sync_modifier_exists
		and body_sync_modifier_active
		and body_sync_attachment_aligned
		and root_visible
		and line_segments_positive
		and axis_count_positive
		and reference_found
		and line_mesh_visible
		and axis_mesh_visible
		and disabled_hidden
	)
	var lines := PackedStringArray()
	lines.append("skeleton_exists=%s" % str(skeleton != null))
	lines.append("modifier_exists=%s" % str(modifier_exists))
	lines.append("modifier_active=%s" % str(modifier_active))
	lines.append("body_sync_modifier_exists=%s" % str(body_sync_modifier_exists))
	lines.append("body_sync_modifier_active=%s" % str(body_sync_modifier_active))
	lines.append("body_sync_forearm_attachment_error_m=%.6f" % forearm_attachment_error)
	lines.append("root_visible=%s" % str(root_visible))
	lines.append("line_segment_count=%d" % int(enabled_state.get("line_segment_count", 0)))
	lines.append("axis_bone_count=%d" % int(enabled_state.get("axis_bone_count", 0)))
	lines.append("reference_bone_found=%s" % str(reference_found))
	lines.append("line_mesh_visible=%s" % str(line_mesh_visible))
	lines.append("axis_mesh_visible=%s" % str(axis_mesh_visible))
	lines.append("disabled_hidden=%s" % str(disabled_hidden))
	lines.append("all_checks_passed=%s" % str(all_checks_passed))
	DirAccess.make_dir_recursive_absolute("C:/WORKSPACE/DEBUG-LOGS")
	var file: FileAccess = FileAccess.open(RESULT_FILE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()
	quit(0 if all_checks_passed else 1)

func _measure_synced_attachment_error(rig: Node, skeleton: Skeleton3D) -> float:
	if rig == null or skeleton == null:
		return -1.0
	var restriction_root: Node3D = rig.call("get_body_restriction_root") as Node3D if rig.has_method("get_body_restriction_root") else null
	var attachment: Node3D = restriction_root.get_node_or_null("RightForearmRestrictionAttachment") as Node3D if restriction_root != null else null
	var forearm_index: int = skeleton.find_bone("CC_Base_R_Forearm")
	if attachment == null or forearm_index < 0:
		return -1.0
	skeleton.set_bone_pose_rotation(forearm_index, Quaternion(Vector3.UP, 0.35).normalized())
	skeleton.force_update_all_bone_transforms()
	rig.call("process_runtime_body_restriction_sync_modifier_frame", 1.0 / 60.0)
	var expected_transform: Transform3D = skeleton.global_transform * skeleton.get_bone_global_pose(forearm_index)
	return attachment.global_position.distance_to(expected_transform.origin)
