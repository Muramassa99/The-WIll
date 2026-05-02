extends SceneTree

const CombatAnimationTrajectoryVolumeResolverScript = preload("res://core/resolvers/combat_animation_trajectory_volume_resolver.gd")
const CombatAnimationChainPlayerScript = preload("res://runtime/combat/combat_animation_chain_player.gd")
const CombatAnimationMotionNodeScript = preload("res://core/models/combat_animation_motion_node.gd")

const RESULT_FILE_PATH := "C:/WORKSPACE/combat_animation_trajectory_volume_results.txt"

func _init() -> void:
	call_deferred("_run_verification")

func _run_verification() -> void:
	var resolver = CombatAnimationTrajectoryVolumeResolverScript.new()
	var lines: PackedStringArray = []

	var max_config: Dictionary = resolver.make_shell_config(Vector3.ZERO, 0.0, 1.0, 0.5, true)
	var max_result: Dictionary = resolver.project_segment_to_valid_volume(
		Vector3(1.4, 0.0, 0.0),
		Vector3(1.0, 0.0, 0.0),
		max_config
	)
	var max_tip: Vector3 = max_result.get("tip_position", Vector3.ZERO) as Vector3
	var max_pommel: Vector3 = max_result.get("pommel_position", Vector3.ZERO) as Vector3
	lines.append("max_clamped=%s" % str(bool(max_result.get("max_clamped", false))))
	lines.append("max_distance_after=%.4f" % float(max_result.get("distance_after_meters", -1.0)))
	lines.append("max_segment_length_preserved=%s" % str(absf(max_tip.distance_to(max_pommel) - 0.4) <= 0.0001))
	lines.append("max_pivot_on_shell_ok=%s" % str(absf(float(max_result.get("distance_after_meters", 0.0)) - 1.0) <= 0.0001))

	var min_config: Dictionary = resolver.make_shell_config(
		Vector3.ZERO,
		0.5,
		1.0,
		0.5,
		true
	)
	min_config["fallback_direction_local"] = Vector3.RIGHT
	var min_result: Dictionary = resolver.project_segment_to_valid_volume(
		Vector3(0.1, 0.0, 0.0),
		Vector3(-0.1, 0.0, 0.0),
		min_config
	)
	var min_tip: Vector3 = min_result.get("tip_position", Vector3.ZERO) as Vector3
	var min_pommel: Vector3 = min_result.get("pommel_position", Vector3.ZERO) as Vector3
	lines.append("min_clamped=%s" % str(bool(min_result.get("min_clamped", false))))
	lines.append("min_distance_after=%.4f" % float(min_result.get("distance_after_meters", -1.0)))
	lines.append("min_segment_length_preserved=%s" % str(absf(min_tip.distance_to(min_pommel) - 0.2) <= 0.0001))
	lines.append("min_pivot_on_shell_ok=%s" % str(absf(float(min_result.get("distance_after_meters", 0.0)) - 0.5) <= 0.0001))

	var from_node: CombatAnimationMotionNode = CombatAnimationMotionNodeScript.new()
	from_node.tip_position_local = Vector3(0.2, 0.0, 0.0)
	from_node.pommel_position_local = Vector3(0.0, 0.0, 0.0)
	from_node.transition_duration_seconds = 1.0
	from_node.normalize()

	var to_node: CombatAnimationMotionNode = CombatAnimationMotionNodeScript.new()
	to_node.tip_position_local = Vector3(2.2, 0.0, 0.0)
	to_node.pommel_position_local = Vector3(2.0, 0.0, 0.0)
	to_node.transition_duration_seconds = 1.0
	to_node.normalize()

	var tip_curve := Curve3D.new()
	tip_curve.add_point(from_node.tip_position_local)
	tip_curve.add_point(to_node.tip_position_local)
	var pommel_curve := Curve3D.new()
	pommel_curve.add_point(from_node.pommel_position_local)
	pommel_curve.add_point(to_node.pommel_position_local)

	var chain_player: CombatAnimationChainPlayer = CombatAnimationChainPlayerScript.new()
	chain_player.prepare([from_node, to_node], tip_curve, pommel_curve, 1.0, false, max_config)
	chain_player.start()
	chain_player.advance(0.5)
	var chain_pivot: Vector3 = chain_player.current_pommel_position.lerp(chain_player.current_tip_position, 0.5)
	lines.append("chain_volume_clamped=%s" % str(bool(chain_player.current_trajectory_volume_state.get("clamped", false))))
	lines.append("chain_pivot_distance=%.4f" % chain_pivot.length())
	lines.append("chain_segment_length_preserved=%s" % str(absf(chain_player.current_tip_position.distance_to(chain_player.current_pommel_position) - 0.2) <= 0.0001))
	lines.append("chain_pivot_on_shell_ok=%s" % str(absf(chain_pivot.length() - 1.0) <= 0.0001))

	var file: FileAccess = FileAccess.open(RESULT_FILE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()
	quit()
