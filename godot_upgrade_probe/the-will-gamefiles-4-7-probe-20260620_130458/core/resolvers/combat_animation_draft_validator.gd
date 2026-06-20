extends RefCounted
class_name CombatAnimationDraftValidator

const CombatAnimationDraftScript = preload("res://core/models/combat_animation_draft.gd")
const CombatAnimationMotionNodeScript = preload("res://core/models/combat_animation_motion_node.gd")

const SEVERITY_ERROR: StringName = &"error"
const SEVERITY_WARNING: StringName = &"warning"

const MIN_SKILL_NODES: int = 2
const MIN_IDLE_NODES: int = 1
const DEGENERATE_HANDLE_THRESHOLD: float = 0.0001


func validate_draft(draft: CombatAnimationDraft) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	if draft == null:
		results.append(_make_result(SEVERITY_ERROR, &"null_draft", "Draft is null."))
		return results
	_validate_minimum_node_count(draft, results)
	_validate_protected_first_node(draft, results)
	_validate_degenerate_handles(draft, results)
	_validate_node_indices(draft, results)
	_validate_transition_durations(draft, results)
	return results


func has_errors(results: Array[Dictionary]) -> bool:
	for result: Dictionary in results:
		if result.get("severity", &"") == SEVERITY_ERROR:
			return true
	return false


func get_error_count(results: Array[Dictionary]) -> int:
	var count: int = 0
	for result: Dictionary in results:
		if result.get("severity", &"") == SEVERITY_ERROR:
			count += 1
	return count


func _validate_minimum_node_count(draft: CombatAnimationDraft, results: Array[Dictionary]) -> void:
	var chain: Array = draft.motion_node_chain
	var required_minimum: int = MIN_IDLE_NODES if draft.draft_kind == CombatAnimationDraft.DRAFT_KIND_IDLE else MIN_SKILL_NODES
	if chain.size() < required_minimum:
		results.append(_make_result(
			SEVERITY_ERROR,
			&"too_few_nodes",
			"Draft needs at least %d motion node(s), has %d." % [required_minimum, chain.size()]
		))


func _validate_protected_first_node(draft: CombatAnimationDraft, results: Array[Dictionary]) -> void:
	var chain: Array = draft.motion_node_chain
	if chain.is_empty():
		return
	var first_node: CombatAnimationMotionNode = chain[0] as CombatAnimationMotionNode
	if first_node == null:
		results.append(_make_result(SEVERITY_ERROR, &"null_first_node", "First motion node is null."))
		return
	if first_node.node_index != 0:
		results.append(_make_result(
			SEVERITY_WARNING,
			&"first_node_index_mismatch",
			"First node index is %d, expected 0." % first_node.node_index
		))


func _validate_degenerate_handles(draft: CombatAnimationDraft, results: Array[Dictionary]) -> void:
	var chain: Array = draft.motion_node_chain
	if chain.size() < 2:
		return
	for node_index: int in range(chain.size()):
		var motion_node: CombatAnimationMotionNode = chain[node_index] as CombatAnimationMotionNode
		if motion_node == null:
			continue
		var is_first: bool = node_index == 0
		var is_last: bool = node_index == chain.size() - 1
		var tip_in_degenerate: bool = motion_node.tip_curve_in_handle.length() < DEGENERATE_HANDLE_THRESHOLD
		var tip_out_degenerate: bool = motion_node.tip_curve_out_handle.length() < DEGENERATE_HANDLE_THRESHOLD
		if not is_first and tip_in_degenerate and (tip_out_degenerate or is_last):
			results.append(_make_result(
				SEVERITY_WARNING,
				&"degenerate_tip_handles",
				"Node %d has near-zero tip curve handles." % node_index
			))
		var pommel_in_degenerate: bool = motion_node.pommel_curve_in_handle.length() < DEGENERATE_HANDLE_THRESHOLD
		var pommel_out_degenerate: bool = motion_node.pommel_curve_out_handle.length() < DEGENERATE_HANDLE_THRESHOLD
		if not is_first and pommel_in_degenerate and (pommel_out_degenerate or is_last):
			results.append(_make_result(
				SEVERITY_WARNING,
				&"degenerate_pommel_handles",
				"Node %d has near-zero pommel curve handles." % node_index
			))


func _validate_node_indices(draft: CombatAnimationDraft, results: Array[Dictionary]) -> void:
	var chain: Array = draft.motion_node_chain
	for expected_index: int in range(chain.size()):
		var motion_node: CombatAnimationMotionNode = chain[expected_index] as CombatAnimationMotionNode
		if motion_node == null:
			results.append(_make_result(SEVERITY_ERROR, &"null_node", "Motion node at index %d is null." % expected_index))
			continue
		if motion_node.node_index != expected_index:
			results.append(_make_result(
				SEVERITY_WARNING,
				&"node_index_mismatch",
				"Node at chain position %d has node_index=%d." % [expected_index, motion_node.node_index]
			))


func _validate_transition_durations(draft: CombatAnimationDraft, results: Array[Dictionary]) -> void:
	var chain: Array = draft.motion_node_chain
	for node_index: int in range(chain.size()):
		var motion_node: CombatAnimationMotionNode = chain[node_index] as CombatAnimationMotionNode
		if motion_node == null:
			continue
		if node_index > 0 and motion_node.transition_duration_seconds <= 0.0:
			results.append(_make_result(
				SEVERITY_WARNING,
				&"zero_transition_duration",
				"Node %d has zero or negative transition duration." % node_index
			))


func _make_result(severity: StringName, code: StringName, message: String) -> Dictionary:
	return {
		"severity": severity,
		"code": code,
		"message": message,
	}
