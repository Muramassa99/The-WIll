extends SceneTree

const PlayerHumanoidRigScene: PackedScene = preload("res://scenes/player/player_humanoid_rig.tscn")
const RESULT_FILE_PATH := "C:/WORKSPACE/authoring_baseline_pose_results.txt"

var lines: PackedStringArray = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var actor: PlayerHumanoidRig = PlayerHumanoidRigScene.instantiate() as PlayerHumanoidRig
	root.add_child(actor)
	await process_frame
	_append_pose(actor, "ready")
	actor.reset_authoring_preview_baseline_pose(&"Idle")
	_append_pose(actor, "idle_reset")
	actor.reset_authoring_preview_baseline_pose(&"2 Hand Idle")
	_append_pose(actor, "two_hand_idle_reset")
	_write_results()
	quit()

func _append_pose(actor: PlayerHumanoidRig, label: String) -> void:
	var right_clavicle: Vector3 = actor.call("_get_bone_world_position", &"CC_Base_R_Clavicle") as Vector3
	var right_upperarm: Vector3 = actor.call("_get_bone_world_position", &"CC_Base_R_Upperarm") as Vector3
	var right_forearm: Vector3 = actor.call("_get_bone_world_position", &"CC_Base_R_Forearm") as Vector3
	var right_hand: Vector3 = actor.call("_get_bone_world_position", &"CC_Base_R_Hand") as Vector3
	var left_clavicle: Vector3 = actor.call("_get_bone_world_position", &"CC_Base_L_Clavicle") as Vector3
	var left_hand: Vector3 = actor.call("_get_bone_world_position", &"CC_Base_L_Hand") as Vector3
	var right_anchor: Node3D = actor.get_right_hand_item_anchor()
	var left_anchor: Node3D = actor.get_left_hand_item_anchor()
	lines.append("[%s]" % label)
	lines.append("%s_animation=%s" % [label, String(actor.get_current_animation_name())])
	lines.append("%s_right_clavicle_world=%s" % [label, str(right_clavicle)])
	lines.append("%s_right_upperarm_world=%s" % [label, str(right_upperarm)])
	lines.append("%s_right_forearm_world=%s" % [label, str(right_forearm)])
	lines.append("%s_right_hand_world=%s" % [label, str(right_hand)])
	lines.append("%s_right_hand_from_clavicle=%s" % [label, str(right_hand - right_clavicle)])
	lines.append("%s_right_anchor_world=%s" % [label, str(right_anchor.global_position if right_anchor != null else Vector3.ZERO)])
	lines.append("%s_left_clavicle_world=%s" % [label, str(left_clavicle)])
	lines.append("%s_left_hand_world=%s" % [label, str(left_hand)])
	lines.append("%s_left_hand_from_clavicle=%s" % [label, str(left_hand - left_clavicle)])
	lines.append("%s_left_anchor_world=%s" % [label, str(left_anchor.global_position if left_anchor != null else Vector3.ZERO)])
	lines.append("")

func _write_results() -> void:
	var file: FileAccess = FileAccess.open(RESULT_FILE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string("\n".join(lines))
	file.close()
