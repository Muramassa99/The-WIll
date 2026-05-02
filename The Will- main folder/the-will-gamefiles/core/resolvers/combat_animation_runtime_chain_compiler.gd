extends RefCounted
class_name CombatAnimationRuntimeChainCompiler

const CombatAnimationMotionNodeScript = preload("res://core/models/combat_animation_motion_node.gd")
const CombatAnimationRetargetResolverScript = preload("res://core/resolvers/combat_animation_retarget_resolver.gd")

const DIAG_TWO_HAND_DEGRADED: StringName = &"two_hand_degraded_to_one_hand"
const DIAG_AUTO_TWO_HAND_RESOLVED_ONE_HAND: StringName = &"auto_two_hand_resolved_one_hand"
const DIAG_PRIMARY_HAND_SWAP_BRIDGE: StringName = &"primary_hand_swap_bridge_inserted"
const HAND_SWAP_BRIDGE_DURATION_SECONDS := 0.18

var retarget_resolver = CombatAnimationRetargetResolverScript.new()

func compile_skill_chain(
	authored_motion_node_chain: Array,
	current_weapon_length_meters: float,
	volume_config: Dictionary = {},
	equipment_context: Dictionary = {}
) -> Dictionary:
	var result: Dictionary = {
		"compiled": false,
		"motion_node_chain": [],
		"diagnostics": [],
		"source_node_count": authored_motion_node_chain.size(),
		"effective_node_count": 0,
		"retarget_seeded_count": 0,
		"retargeted_count": 0,
		"degraded_node_count": 0,
		"hand_swap_bridge_count": 0,
		"saved_authoring_mutated": false,
	}
	var effective_chain: Array = _duplicate_motion_node_chain(authored_motion_node_chain)
	if effective_chain.size() < 2:
		result["diagnostics"].append(_make_diagnostic(&"error", &"too_few_runtime_nodes", -1, "Runtime chain needs at least 2 motion nodes."))
		return result
	var retarget_result: Dictionary = retarget_resolver.retarget_motion_chain_for_weapon_length(
		effective_chain,
		current_weapon_length_meters,
		volume_config,
		0.001,
		true
	)
	result["retarget_seeded_count"] = int(retarget_result.get("seeded_count", 0))
	result["retargeted_count"] = int(retarget_result.get("retargeted_count", 0))
	_apply_equipment_legality(effective_chain, equipment_context, result)
	effective_chain = _insert_primary_hand_swap_bridges(effective_chain, equipment_context, result)
	for node_index: int in range(effective_chain.size()):
		var motion_node = effective_chain[node_index]
		if motion_node == null:
			continue
		motion_node.node_index = node_index
		if motion_node.has_method("normalize"):
			motion_node.call("normalize")
	result["compiled"] = effective_chain.size() >= 2
	result["motion_node_chain"] = effective_chain
	result["effective_node_count"] = effective_chain.size()
	return result

func _duplicate_motion_node_chain(authored_motion_node_chain: Array) -> Array:
	var duplicated_chain: Array = []
	for node_variant: Variant in authored_motion_node_chain:
		var source_node = node_variant
		if source_node == null:
			continue
		var duplicate_node = source_node.duplicate(true)
		duplicate_node.node_index = duplicated_chain.size()
		if duplicate_node.has_method("normalize"):
			duplicate_node.call("normalize")
		duplicated_chain.append(duplicate_node)
	return duplicated_chain

func _apply_equipment_legality(
	effective_chain: Array,
	equipment_context: Dictionary,
	result: Dictionary
) -> void:
	var support_hand_available: bool = bool(equipment_context.get("support_hand_available", true))
	var two_hand_allowed: bool = bool(equipment_context.get("two_hand_allowed", support_hand_available))
	for node_index: int in range(effective_chain.size()):
		var motion_node = effective_chain[node_index]
		if motion_node == null:
			continue
		if motion_node.two_hand_state == CombatAnimationMotionNodeScript.TWO_HAND_STATE_TWO_HAND and not support_hand_available:
			motion_node.two_hand_state = CombatAnimationMotionNodeScript.TWO_HAND_STATE_ONE_HAND
			result["degraded_node_count"] = int(result.get("degraded_node_count", 0)) + 1
			result["diagnostics"].append(_make_diagnostic(
				&"warning",
				DIAG_TWO_HAND_DEGRADED,
				node_index,
				"Two-hand node degraded to one-hand because the support hand is unavailable."
			))
		elif motion_node.two_hand_state == CombatAnimationMotionNodeScript.TWO_HAND_STATE_AUTO and not two_hand_allowed:
			motion_node.two_hand_state = CombatAnimationMotionNodeScript.TWO_HAND_STATE_ONE_HAND
			result["degraded_node_count"] = int(result.get("degraded_node_count", 0)) + 1
			result["diagnostics"].append(_make_diagnostic(
				&"info",
				DIAG_AUTO_TWO_HAND_RESOLVED_ONE_HAND,
				node_index,
				"Auto two-hand node resolved to one-hand for the current equipment state."
			))

func _insert_primary_hand_swap_bridges(
	effective_chain: Array,
	equipment_context: Dictionary,
	result: Dictionary
) -> Array:
	if effective_chain.size() < 2:
		return effective_chain
	var two_hand_allowed: bool = bool(equipment_context.get("two_hand_allowed", false))
	var compiled_chain: Array = []
	compiled_chain.append(effective_chain[0])
	for source_index: int in range(1, effective_chain.size()):
		var from_node = compiled_chain[compiled_chain.size() - 1]
		var to_node = effective_chain[source_index]
		if _nodes_need_primary_hand_swap_bridge(from_node, to_node):
			var bridge_node = _build_primary_hand_swap_bridge(from_node, to_node, two_hand_allowed)
			compiled_chain.append(bridge_node)
			result["hand_swap_bridge_count"] = int(result.get("hand_swap_bridge_count", 0)) + 1
			result["diagnostics"].append(_make_diagnostic(
				&"info",
				DIAG_PRIMARY_HAND_SWAP_BRIDGE,
				source_index,
				"Generated primary-hand swap bridge for runtime effective chain."
			))
		compiled_chain.append(to_node)
	return compiled_chain

func _nodes_need_primary_hand_swap_bridge(from_node, to_node) -> bool:
	if from_node == null or to_node == null:
		return false
	var from_slot: StringName = CombatAnimationMotionNodeScript.normalize_primary_hand_slot(from_node.primary_hand_slot)
	var to_slot: StringName = CombatAnimationMotionNodeScript.normalize_primary_hand_slot(to_node.primary_hand_slot)
	if from_slot == CombatAnimationMotionNodeScript.PRIMARY_HAND_AUTO or to_slot == CombatAnimationMotionNodeScript.PRIMARY_HAND_AUTO:
		return false
	return from_slot != to_slot

func _build_primary_hand_swap_bridge(from_node, to_node, two_hand_allowed: bool):
	var bridge_node = from_node.duplicate(true)
	bridge_node.node_id = StringName("generated_primary_hand_swap_%02d" % int(to_node.node_index))
	bridge_node.transition_duration_seconds = HAND_SWAP_BRIDGE_DURATION_SECONDS
	bridge_node.tip_curve_in_handle = Vector3.ZERO
	bridge_node.tip_curve_out_handle = Vector3.ZERO
	bridge_node.pommel_curve_in_handle = Vector3.ZERO
	bridge_node.pommel_curve_out_handle = Vector3.ZERO
	bridge_node.primary_hand_slot = CombatAnimationMotionNodeScript.normalize_primary_hand_slot(to_node.primary_hand_slot)
	bridge_node.two_hand_state = (
		CombatAnimationMotionNodeScript.TWO_HAND_STATE_TWO_HAND
		if two_hand_allowed
		else CombatAnimationMotionNodeScript.TWO_HAND_STATE_ONE_HAND
	)
	bridge_node.generated_transition_node = true
	bridge_node.generated_transition_kind = CombatAnimationMotionNodeScript.TRANSITION_KIND_PRIMARY_HAND_SWAP
	bridge_node.locked_for_authoring = true
	bridge_node.draft_notes = "Generated runtime primary-hand swap bridge. Authored data remains unchanged."
	if bridge_node.has_method("normalize"):
		bridge_node.call("normalize")
	return bridge_node

func _make_diagnostic(
	severity: StringName,
	code: StringName,
	node_index: int,
	message: String
) -> Dictionary:
	return {
		"severity": severity,
		"code": code,
		"node_index": node_index,
		"message": message,
	}
