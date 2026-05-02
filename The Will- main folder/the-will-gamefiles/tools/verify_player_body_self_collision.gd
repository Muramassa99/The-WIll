extends SceneTree

const PlayerHumanoidRigScene: PackedScene = preload("res://scenes/player/player_humanoid_rig.tscn")
const HandTargetConstraintSolverScript = preload("res://runtime/player/hand_target_constraint_solver.gd")

const RESULT_FILE_PATH := "C:/WORKSPACE/player_body_self_collision_results.txt"

func _init() -> void:
	call_deferred("_run_verification")

func _run_verification() -> void:
	var rig: PlayerHumanoidRig = PlayerHumanoidRigScene.instantiate() as PlayerHumanoidRig
	root.add_child(rig)
	await process_frame
	await process_frame

	var body_restriction_root: Node3D = rig.get_body_restriction_root() if rig != null and rig.has_method("get_body_restriction_root") else null
	var neutral_state: Dictionary = rig.get_body_self_collision_debug_state() if rig != null and rig.has_method("get_body_self_collision_debug_state") else {}

	var solver = HandTargetConstraintSolverScript.new()
	var chest_attachment: Node3D = body_restriction_root.get_node_or_null("ChestRestrictionAttachment_Center") as Node3D if body_restriction_root != null else null
	var right_forearm_attachment: Node3D = body_restriction_root.get_node_or_null("RightForearmRestrictionAttachment") as Node3D if body_restriction_root != null else null
	if chest_attachment != null and right_forearm_attachment != null:
		right_forearm_attachment.global_transform = chest_attachment.global_transform
	var forced_state: Dictionary = solver.evaluate_body_self_collision(body_restriction_root) if body_restriction_root != null else {}
	var forced_pair: Dictionary = forced_state.get("first_illegal_pair", {}) as Dictionary

	var lines: PackedStringArray = []
	lines.append("body_restriction_root_exists=%s" % str(body_restriction_root != null))
	lines.append("neutral_body_self_legal=%s" % str(bool(neutral_state.get("legal", false))))
	lines.append("neutral_checked_pair_count=%d" % int(neutral_state.get("checked_pair_count", 0)))
	lines.append("neutral_overlap_pair_count=%d" % int(neutral_state.get("overlap_pair_count", 0)))
	lines.append("neutral_allowed_overlap_pair_count=%d" % int(neutral_state.get("allowed_overlap_pair_count", 0)))
	lines.append("neutral_illegal_pair_count=%d" % int(neutral_state.get("illegal_pair_count", -1)))
	lines.append("neutral_illegal_pairs=%s" % str(neutral_state.get("illegal_pairs", [])))
	lines.append("forced_body_self_legal=%s" % str(bool(forced_state.get("legal", true))))
	lines.append("forced_illegal_pair_count=%d" % int(forced_state.get("illegal_pair_count", 0)))
	lines.append("forced_first_illegal_first_region=%s" % String(forced_pair.get("first_region", "")))
	lines.append("forced_first_illegal_second_region=%s" % String(forced_pair.get("second_region", "")))
	lines.append("forced_first_illegal_clearance_meters=%s" % str(snapped(float(forced_pair.get("clearance_meters", 0.0)), 0.0001)))
	lines.append("anatomical_self_collision_ok=%s" % str(
		body_restriction_root != null
		and bool(neutral_state.get("legal", false))
		and int(neutral_state.get("checked_pair_count", 0)) > 0
		and int(neutral_state.get("allowed_overlap_pair_count", 0)) > 0
		and not bool(forced_state.get("legal", true))
		and int(forced_state.get("illegal_pair_count", 0)) > 0
	))

	var file := FileAccess.open(RESULT_FILE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()
	quit()
