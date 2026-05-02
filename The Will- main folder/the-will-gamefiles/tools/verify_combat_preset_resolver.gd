extends SceneTree

const CombatAnimationPresetResolverScript = preload("res://core/resolvers/combat_animation_preset_resolver.gd")

const RESULT_FILE_PATH := "C:/WORKSPACE/combat_preset_resolver_results.txt"
const EPSILON := 0.001

func _init() -> void:
	call_deferred("_run_verification")

func _run_verification() -> void:
	var resolver = CombatAnimationPresetResolverScript.new()
	var volume_config: Dictionary = {
		"origin_local": Vector3.ZERO,
		"origin_space": &"primary_shoulder",
		"min_radius_meters": 0.1,
		"max_radius_meters": 1.0,
		"pivot_ratio_from_pommel": 0.5,
	}
	var short_result: Dictionary = resolver.call(
		"resolve_builtin_preset_to_draft",
		&"preset_forward_cut",
		&"skill_slot_1",
		&"skill_slot_1",
		0.4,
		volume_config
	)
	var long_result: Dictionary = resolver.call(
		"resolve_builtin_preset_to_draft",
		&"preset_forward_cut",
		&"skill_slot_1",
		&"skill_slot_1",
		0.8,
		volume_config
	)
	var short_draft = short_result.get("draft", null)
	var long_draft = long_result.get("draft", null)
	var short_chain: Array = short_draft.motion_node_chain if short_draft != null else []
	var long_chain: Array = long_draft.motion_node_chain if long_draft != null else []
	var node_count_ok: bool = short_chain.size() == 3 and long_chain.size() == 3
	var all_short_lengths_ok: bool = _chain_lengths_match(short_chain, 0.4)
	var all_long_lengths_ok: bool = _chain_lengths_match(long_chain, 0.8)
	var pivots_stable_ok: bool = _chain_pivots_match(short_chain, long_chain)
	var all_nodes_have_retarget_ok: bool = _chain_has_retarget_nodes(short_chain) and _chain_has_retarget_nodes(long_chain)
	var timing_ok: bool = (
		short_chain.size() == 3
		and is_equal_approx(short_chain[1].transition_duration_seconds, 0.22)
		and is_equal_approx(short_chain[2].transition_duration_seconds, 0.28)
	)
	var speed_tuning_ok: bool = (
		short_draft != null
		and is_equal_approx(short_draft.speed_acceleration_percent, 30.0)
		and is_equal_approx(short_draft.speed_deceleration_percent, 42.0)
	)
	var validation_ok: bool = (
		bool(short_result.get("validation_passed", false))
		and bool(long_result.get("validation_passed", false))
		and int(short_result.get("validation_error_count", -1)) == 0
		and int(long_result.get("validation_error_count", -1)) == 0
	)
	var all_checks_passed: bool = (
		bool(short_result.get("preset_resolved", false))
		and bool(long_result.get("preset_resolved", false))
		and node_count_ok
		and all_short_lengths_ok
		and all_long_lengths_ok
		and pivots_stable_ok
		and all_nodes_have_retarget_ok
		and timing_ok
		and speed_tuning_ok
		and validation_ok
	)

	var lines: PackedStringArray = []
	lines.append("short_preset_resolved=%s" % str(bool(short_result.get("preset_resolved", false))))
	lines.append("long_preset_resolved=%s" % str(bool(long_result.get("preset_resolved", false))))
	lines.append("short_node_count=%d" % short_chain.size())
	lines.append("long_node_count=%d" % long_chain.size())
	lines.append("node_count_ok=%s" % str(node_count_ok))
	lines.append("all_short_lengths_ok=%s" % str(all_short_lengths_ok))
	lines.append("all_long_lengths_ok=%s" % str(all_long_lengths_ok))
	lines.append("pivots_stable_ok=%s" % str(pivots_stable_ok))
	lines.append("all_nodes_have_retarget_ok=%s" % str(all_nodes_have_retarget_ok))
	lines.append("timing_ok=%s" % str(timing_ok))
	lines.append("speed_tuning_ok=%s" % str(speed_tuning_ok))
	lines.append("validation_ok=%s" % str(validation_ok))
	lines.append("all_checks_passed=%s" % str(all_checks_passed))

	var file: FileAccess = FileAccess.open(RESULT_FILE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()
	quit(0 if all_checks_passed else 1)

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

func _chain_pivots_match(short_chain: Array, long_chain: Array) -> bool:
	if short_chain.size() != long_chain.size() or short_chain.is_empty():
		return false
	for node_index: int in range(short_chain.size()):
		var short_node = short_chain[node_index]
		var long_node = long_chain[node_index]
		if short_node == null or long_node == null:
			return false
		var short_pivot: Vector3 = short_node.pommel_position_local.lerp(short_node.tip_position_local, 0.5)
		var long_pivot: Vector3 = long_node.pommel_position_local.lerp(long_node.tip_position_local, 0.5)
		if short_pivot.distance_to(long_pivot) > EPSILON:
			return false
	return true

func _chain_has_retarget_nodes(chain: Array) -> bool:
	if chain.is_empty():
		return false
	for node_variant: Variant in chain:
		var node = node_variant
		if node == null or node.retarget_node == null:
			return false
	return true
