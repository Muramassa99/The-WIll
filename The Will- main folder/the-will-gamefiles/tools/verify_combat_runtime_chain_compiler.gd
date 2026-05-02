extends SceneTree

const CombatAnimationMotionNodeScript = preload("res://core/models/combat_animation_motion_node.gd")
const CombatAnimationRuntimeChainCompilerScript = preload("res://core/resolvers/combat_animation_runtime_chain_compiler.gd")

const RESULT_FILE_PATH := "C:/WORKSPACE/combat_runtime_chain_compiler_results.txt"
const EPSILON := 0.001

func _init() -> void:
	call_deferred("_run_verification")

func _run_verification() -> void:
	var compiler = CombatAnimationRuntimeChainCompilerScript.new()
	var authored_chain: Array = _build_authored_chain()
	var authored_second_before = authored_chain[1]
	var volume_config: Dictionary = {
		"origin_local": Vector3.ZERO,
		"origin_space": &"primary_shoulder",
		"min_radius_meters": 0.1,
		"max_radius_meters": 1.0,
		"pivot_ratio_from_pommel": 0.5,
	}
	var blocked_result: Dictionary = compiler.call(
		"compile_skill_chain",
		authored_chain,
		0.8,
		volume_config,
		{
			"support_hand_available": false,
			"two_hand_allowed": false,
		}
	)
	var allowed_result: Dictionary = compiler.call(
		"compile_skill_chain",
		authored_chain,
		0.8,
		volume_config,
		{
			"support_hand_available": true,
			"two_hand_allowed": true,
		}
	)
	var blocked_chain: Array = blocked_result.get("motion_node_chain", []) as Array
	var allowed_chain: Array = allowed_result.get("motion_node_chain", []) as Array
	var blocked_bridge = blocked_chain[1] if blocked_chain.size() > 1 else null
	var blocked_second = blocked_chain[2] if blocked_chain.size() > 2 else null
	var allowed_bridge = allowed_chain[1] if allowed_chain.size() > 1 else null
	var allowed_second = allowed_chain[2] if allowed_chain.size() > 2 else null
	var compiled_ok: bool = bool(blocked_result.get("compiled", false)) and bool(allowed_result.get("compiled", false))
	var duplicated_ok: bool = (
		blocked_chain.size() == authored_chain.size() + 1
		and blocked_chain.size() > 2
		and blocked_chain[2] != authored_chain[1]
		and not bool(blocked_result.get("saved_authoring_mutated", true))
	)
	var original_unchanged_ok: bool = (
		authored_second_before.two_hand_state == CombatAnimationMotionNodeScript.TWO_HAND_STATE_TWO_HAND
		and authored_second_before.primary_hand_slot == CombatAnimationMotionNodeScript.PRIMARY_HAND_LEFT
	)
	var degradation_ok: bool = (
		blocked_second != null
		and blocked_second.two_hand_state == CombatAnimationMotionNodeScript.TWO_HAND_STATE_ONE_HAND
		and int(blocked_result.get("degraded_node_count", 0)) == 1
		and _diagnostics_have_code(blocked_result.get("diagnostics", []) as Array, &"two_hand_degraded_to_one_hand")
	)
	var allowed_preserves_two_hand_ok: bool = (
		allowed_second != null
		and allowed_second.two_hand_state == CombatAnimationMotionNodeScript.TWO_HAND_STATE_TWO_HAND
		and int(allowed_result.get("degraded_node_count", -1)) == 0
	)
	var hand_swap_bridge_ok: bool = (
		int(blocked_result.get("hand_swap_bridge_count", 0)) == 1
		and int(allowed_result.get("hand_swap_bridge_count", 0)) == 1
		and blocked_bridge != null
		and allowed_bridge != null
		and blocked_bridge.generated_transition_node
		and allowed_bridge.generated_transition_node
		and blocked_bridge.generated_transition_kind == CombatAnimationMotionNodeScript.TRANSITION_KIND_PRIMARY_HAND_SWAP
		and allowed_bridge.generated_transition_kind == CombatAnimationMotionNodeScript.TRANSITION_KIND_PRIMARY_HAND_SWAP
		and blocked_bridge.primary_hand_slot == CombatAnimationMotionNodeScript.PRIMARY_HAND_LEFT
		and allowed_bridge.primary_hand_slot == CombatAnimationMotionNodeScript.PRIMARY_HAND_LEFT
	)
	var retarget_ok: bool = (
		_chain_lengths_match(blocked_chain, 0.8)
		and int(blocked_result.get("retarget_seeded_count", 0)) == authored_chain.size()
		and int(blocked_result.get("retargeted_count", 0)) == authored_chain.size()
	)
	var all_checks_passed: bool = (
		compiled_ok
		and duplicated_ok
		and original_unchanged_ok
		and degradation_ok
		and allowed_preserves_two_hand_ok
		and hand_swap_bridge_ok
		and retarget_ok
	)

	var lines: PackedStringArray = []
	lines.append("compiled_ok=%s" % str(compiled_ok))
	lines.append("duplicated_ok=%s" % str(duplicated_ok))
	lines.append("original_unchanged_ok=%s" % str(original_unchanged_ok))
	lines.append("degradation_ok=%s" % str(degradation_ok))
	lines.append("allowed_preserves_two_hand_ok=%s" % str(allowed_preserves_two_hand_ok))
	lines.append("hand_swap_bridge_ok=%s" % str(hand_swap_bridge_ok))
	lines.append("retarget_ok=%s" % str(retarget_ok))
	lines.append("blocked_degraded_node_count=%d" % int(blocked_result.get("degraded_node_count", -1)))
	lines.append("blocked_hand_swap_bridge_count=%d" % int(blocked_result.get("hand_swap_bridge_count", -1)))
	lines.append("blocked_retarget_seeded_count=%d" % int(blocked_result.get("retarget_seeded_count", -1)))
	lines.append("blocked_retargeted_count=%d" % int(blocked_result.get("retargeted_count", -1)))
	lines.append("all_checks_passed=%s" % str(all_checks_passed))

	var file: FileAccess = FileAccess.open(RESULT_FILE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()
	quit(0 if all_checks_passed else 1)

func _build_authored_chain() -> Array:
	var first_node = CombatAnimationMotionNodeScript.new()
	first_node.node_index = 0
	first_node.node_id = &"motion_node_00"
	first_node.tip_position_local = Vector3(0.2, 0.0, 0.2)
	first_node.pommel_position_local = Vector3(-0.2, 0.0, -0.2)
	first_node.two_hand_state = CombatAnimationMotionNodeScript.TWO_HAND_STATE_ONE_HAND
	first_node.primary_hand_slot = CombatAnimationMotionNodeScript.PRIMARY_HAND_RIGHT
	first_node.transition_duration_seconds = 0.01
	first_node.normalize()
	var second_node = CombatAnimationMotionNodeScript.new()
	second_node.node_index = 1
	second_node.node_id = &"motion_node_01"
	second_node.tip_position_local = Vector3(0.1, 0.2, 0.35)
	second_node.pommel_position_local = Vector3(-0.1, -0.05, -0.15)
	second_node.two_hand_state = CombatAnimationMotionNodeScript.TWO_HAND_STATE_TWO_HAND
	second_node.primary_hand_slot = CombatAnimationMotionNodeScript.PRIMARY_HAND_LEFT
	second_node.transition_duration_seconds = 0.25
	second_node.normalize()
	return [first_node, second_node]

func _chain_lengths_match(chain: Array, expected_length: float) -> bool:
	if chain.is_empty():
		return false
	for node_variant: Variant in chain:
		var node = node_variant
		if node == null:
			return false
		if absf(node.tip_position_local.distance_to(node.pommel_position_local) - expected_length) > EPSILON:
			return false
	return true

func _diagnostics_have_code(diagnostics: Array, code: StringName) -> bool:
	for diagnostic_variant: Variant in diagnostics:
		var diagnostic: Dictionary = diagnostic_variant as Dictionary
		if StringName(diagnostic.get("code", StringName())) == code:
			return true
	return false
