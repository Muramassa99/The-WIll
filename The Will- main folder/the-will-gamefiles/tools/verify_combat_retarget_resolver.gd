extends SceneTree

const CombatAnimationMotionNodeScript = preload("res://core/models/combat_animation_motion_node.gd")
const CombatAnimationRetargetNodeScript = preload("res://core/models/combat_animation_retarget_node.gd")
const CombatAnimationRetargetResolverScript = preload("res://core/resolvers/combat_animation_retarget_resolver.gd")

const RESULT_FILE_PATH := "C:/WORKSPACE/combat_retarget_resolver_results.txt"
const EPSILON := 0.001

func _init() -> void:
	call_deferred("_run_verification")

func _run_verification() -> void:
	var resolver = CombatAnimationRetargetResolverScript.new()
	var source_node = CombatAnimationMotionNodeScript.new()
	source_node.tip_position_local = Vector3(0.2, 0.1, 0.4)
	source_node.pommel_position_local = Vector3(-0.1, 0.05, 0.0)
	source_node.tip_curve_in_handle = Vector3(-0.04, 0.02, 0.08)
	source_node.tip_curve_out_handle = Vector3(0.12, 0.01, -0.03)
	source_node.pommel_curve_in_handle = Vector3(-0.02, 0.0, 0.04)
	source_node.pommel_curve_out_handle = Vector3(0.05, -0.01, -0.02)
	source_node.weapon_orientation_degrees = Vector3(5.0, 25.0, -10.0)
	source_node.weapon_orientation_authored = true
	source_node.weapon_roll_degrees = 35.0
	source_node.axial_reposition_offset = 0.07
	source_node.grip_seat_slide_offset = -0.03
	source_node.body_support_blend = 0.42
	source_node.transition_duration_seconds = 0.27
	source_node.preferred_grip_style_mode = &"grip_reverse"
	source_node.two_hand_state = CombatAnimationMotionNodeScript.TWO_HAND_STATE_TWO_HAND
	source_node.primary_hand_slot = CombatAnimationMotionNodeScript.PRIMARY_HAND_LEFT
	source_node.normalize()

	var pivot_ratio: float = 0.35
	var volume_config: Dictionary = {
		"origin_local": Vector3.ZERO,
		"origin_space": CombatAnimationRetargetNodeScript.ORIGIN_SPACE_TORSO_FRAME,
		"min_radius_meters": 0.1,
		"max_radius_meters": 1.0,
		"pivot_ratio_from_pommel": pivot_ratio,
	}
	var source_length: float = source_node.tip_position_local.distance_to(source_node.pommel_position_local)
	var source_pivot: Vector3 = source_node.pommel_position_local.lerp(source_node.tip_position_local, pivot_ratio)

	var retarget_node = resolver.call(
		"build_retarget_node_from_legacy_motion_node",
		source_node,
		volume_config
	)
	var same_length_values: Dictionary = resolver.call(
		"resolve_motion_values_from_retarget_node",
		retarget_node,
		source_length,
		volume_config
	)
	var same_tip: Vector3 = same_length_values.get("tip_position_local", Vector3.INF) as Vector3
	var same_pommel: Vector3 = same_length_values.get("pommel_position_local", Vector3.INF) as Vector3
	var same_pivot: Vector3 = same_length_values.get("pivot_position_local", Vector3.INF) as Vector3

	var double_length_values: Dictionary = resolver.call(
		"resolve_motion_values_from_retarget_node",
		retarget_node,
		source_length * 2.0,
		volume_config
	)
	var double_tip: Vector3 = double_length_values.get("tip_position_local", Vector3.INF) as Vector3
	var double_pommel: Vector3 = double_length_values.get("pommel_position_local", Vector3.INF) as Vector3
	var double_pivot: Vector3 = double_length_values.get("pivot_position_local", Vector3.INF) as Vector3

	var applied_node = source_node.duplicate_node()
	var apply_ok: bool = bool(resolver.call(
		"apply_retarget_node_to_motion_node",
		applied_node,
		retarget_node,
		source_length * 1.5,
		volume_config
	))
	var applied_length: float = applied_node.tip_position_local.distance_to(applied_node.pommel_position_local)
	var applied_pivot: Vector3 = applied_node.pommel_position_local.lerp(
		applied_node.tip_position_local,
		pivot_ratio
	)

	var chain_node = source_node.duplicate_node()
	chain_node.retarget_node = null
	var chain_pivot_before: Vector3 = chain_node.pommel_position_local.lerp(
		chain_node.tip_position_local,
		pivot_ratio
	)
	var chain_result: Dictionary = resolver.call(
		"retarget_motion_chain_for_weapon_length",
		[chain_node],
		source_length * 2.0,
		volume_config,
		EPSILON,
		true
	)
	var chain_length_after: float = chain_node.tip_position_local.distance_to(chain_node.pommel_position_local)
	var chain_pivot_after: Vector3 = chain_node.pommel_position_local.lerp(
		chain_node.tip_position_local,
		pivot_ratio
	)
	var snapshot_result: Dictionary = resolver.call(
		"refresh_motion_chain_retarget_authoring_snapshot",
		[chain_node],
		volume_config
	)
	var stable_second_pass: Dictionary = resolver.call(
		"retarget_motion_chain_for_weapon_length",
		[chain_node],
		source_length * 2.0,
		volume_config,
		EPSILON,
		true
	)

	var same_tip_ok: bool = _vector_close(same_tip, source_node.tip_position_local)
	var same_pommel_ok: bool = _vector_close(same_pommel, source_node.pommel_position_local)
	var same_pivot_ok: bool = _vector_close(same_pivot, source_pivot)
	var double_length_ok: bool = _float_close(double_tip.distance_to(double_pommel), source_length * 2.0)
	var double_pivot_ok: bool = _vector_close(double_pivot, source_pivot)
	var copied_orientation_ok: bool = same_length_values.get("weapon_orientation_degrees", Vector3.ZERO) == source_node.weapon_orientation_degrees
	var copied_state_ok: bool = (
		StringName(same_length_values.get("preferred_grip_style_mode", &"")) == source_node.preferred_grip_style_mode
		and StringName(same_length_values.get("two_hand_state", &"")) == source_node.two_hand_state
		and StringName(same_length_values.get("primary_hand_slot", &"")) == source_node.primary_hand_slot
		and _float_close(float(same_length_values.get("transition_duration_seconds", -1.0)), source_node.transition_duration_seconds)
	)
	var curve_handles_roundtrip_ok: bool = (
		_vector_close(same_length_values.get("tip_curve_in_handle", Vector3.INF) as Vector3, source_node.tip_curve_in_handle)
		and _vector_close(same_length_values.get("tip_curve_out_handle", Vector3.INF) as Vector3, source_node.tip_curve_out_handle)
		and _vector_close(same_length_values.get("pommel_curve_in_handle", Vector3.INF) as Vector3, source_node.pommel_curve_in_handle)
		and _vector_close(same_length_values.get("pommel_curve_out_handle", Vector3.INF) as Vector3, source_node.pommel_curve_out_handle)
	)
	var apply_ok_result: bool = (
		apply_ok
		and applied_node.retarget_node == retarget_node
		and _float_close(applied_length, source_length * 1.5)
		and _vector_close(applied_pivot, source_pivot)
	)
	var chain_retarget_ok: bool = (
		int(chain_result.get("seeded_count", 0)) == 1
		and int(chain_result.get("retargeted_count", 0)) == 1
		and int(chain_result.get("endpoint_changed_count", 0)) == 1
		and _float_close(chain_length_after, source_length * 2.0)
		and _vector_close(chain_pivot_after, chain_pivot_before)
	)
	var snapshot_refresh_ok: bool = (
		int(snapshot_result.get("refreshed_count", 0)) == 1
		and chain_node.retarget_node != null
		and _float_close(float(chain_node.retarget_node.source_weapon_length_meters), source_length * 2.0)
		and int(stable_second_pass.get("retargeted_count", 0)) == 0
	)
	var all_checks_passed: bool = (
		retarget_node != null
		and retarget_node.enabled
		and retarget_node.origin_space == CombatAnimationRetargetNodeScript.ORIGIN_SPACE_TORSO_FRAME
		and bool(same_length_values.get("retarget_resolved", false))
		and same_tip_ok
		and same_pommel_ok
		and same_pivot_ok
		and double_length_ok
		and double_pivot_ok
		and copied_orientation_ok
		and copied_state_ok
		and curve_handles_roundtrip_ok
		and apply_ok_result
		and chain_retarget_ok
		and snapshot_refresh_ok
	)

	var lines: PackedStringArray = []
	lines.append("retarget_node_created=%s" % str(retarget_node != null))
	lines.append("retarget_node_enabled=%s" % str(retarget_node.enabled if retarget_node != null else false))
	lines.append("origin_space=%s" % String(retarget_node.origin_space if retarget_node != null else StringName()))
	lines.append("pivot_range_percent=%.4f" % float(retarget_node.pivot_range_percent if retarget_node != null else -1.0))
	lines.append("same_length_tip_roundtrip_ok=%s" % str(same_tip_ok))
	lines.append("same_length_pommel_roundtrip_ok=%s" % str(same_pommel_ok))
	lines.append("same_length_pivot_roundtrip_ok=%s" % str(same_pivot_ok))
	lines.append("double_length_segment_ok=%s" % str(double_length_ok))
	lines.append("double_length_pivot_stable_ok=%s" % str(double_pivot_ok))
	lines.append("copied_orientation_ok=%s" % str(copied_orientation_ok))
	lines.append("copied_state_ok=%s" % str(copied_state_ok))
	lines.append("curve_handles_roundtrip_ok=%s" % str(curve_handles_roundtrip_ok))
	lines.append("apply_retarget_ok=%s" % str(apply_ok_result))
	lines.append("chain_retarget_ok=%s" % str(chain_retarget_ok))
	lines.append("chain_seeded_count=%d" % int(chain_result.get("seeded_count", 0)))
	lines.append("chain_retargeted_count=%d" % int(chain_result.get("retargeted_count", 0)))
	lines.append("snapshot_refresh_ok=%s" % str(snapshot_refresh_ok))
	lines.append("all_checks_passed=%s" % str(all_checks_passed))

	var file: FileAccess = FileAccess.open(RESULT_FILE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()
	quit(0 if all_checks_passed else 1)

func _vector_close(a: Vector3, b: Vector3) -> bool:
	return a.distance_to(b) <= EPSILON

func _float_close(a: float, b: float) -> bool:
	return absf(a - b) <= EPSILON
