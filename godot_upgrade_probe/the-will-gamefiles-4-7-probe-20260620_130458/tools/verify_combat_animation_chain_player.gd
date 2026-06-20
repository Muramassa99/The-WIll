extends SceneTree

const CombatAnimationChainPlayerScript = preload("res://runtime/combat/combat_animation_chain_player.gd")
const CombatAnimationMotionNodeScript = preload("res://core/models/combat_animation_motion_node.gd")
const CombatAnimationMotionNodeEditorScript = preload("res://runtime/combat/combat_animation_motion_node_editor.gd")

const RESULT_FILE_PATH := "C:/WORKSPACE/combat_animation_chain_player_results.txt"

func _init() -> void:
	call_deferred("_run_verification")

func _run_verification() -> void:
	var from_node: CombatAnimationMotionNode = CombatAnimationMotionNodeScript.new()
	from_node.tip_position_local = Vector3(0.15, 0.0, 0.0)
	from_node.pommel_position_local = Vector3(-0.15, 0.0, 0.0)
	from_node.weapon_orientation_degrees = Vector3(0.0, 45.0, 0.0)
	from_node.weapon_orientation_authored = false
	from_node.two_hand_state = CombatAnimationMotionNodeScript.TWO_HAND_STATE_ONE_HAND
	from_node.primary_hand_slot = CombatAnimationMotionNodeScript.PRIMARY_HAND_RIGHT
	from_node.preferred_grip_style_mode = &"grip_normal"
	from_node.transition_duration_seconds = 0.5
	from_node.normalize()

	var to_node: CombatAnimationMotionNode = CombatAnimationMotionNodeScript.new()
	to_node.tip_position_local = Vector3(0.25, 0.0, 0.0)
	to_node.pommel_position_local = Vector3(-0.25, 0.0, 0.0)
	to_node.weapon_orientation_degrees = Vector3(0.0, 90.0, 0.0)
	to_node.weapon_orientation_authored = false
	to_node.two_hand_state = CombatAnimationMotionNodeScript.TWO_HAND_STATE_TWO_HAND
	to_node.primary_hand_slot = CombatAnimationMotionNodeScript.PRIMARY_HAND_LEFT
	to_node.preferred_grip_style_mode = &"grip_reverse"
	to_node.transition_duration_seconds = 1.0
	to_node.normalize()

	var tip_curve := Curve3D.new()
	tip_curve.add_point(from_node.tip_position_local)
	tip_curve.add_point(to_node.tip_position_local)
	var pommel_curve := Curve3D.new()
	pommel_curve.add_point(from_node.pommel_position_local)
	pommel_curve.add_point(to_node.pommel_position_local)

	var chain_player: CombatAnimationChainPlayer = CombatAnimationChainPlayerScript.new()
	chain_player.prepare([from_node, to_node], tip_curve, pommel_curve, 1.0, false)
	chain_player.start()

	var start_orientation_y: float = snapped(chain_player.current_weapon_orientation_degrees.y, 0.0001)
	var start_two_hand_state: StringName = chain_player.current_two_hand_state
	var start_primary_hand_slot: StringName = chain_player.current_primary_hand_slot
	var start_grip_mode: StringName = chain_player.current_preferred_grip_style_mode

	chain_player.advance(0.25)
	var quarter_orientation_y: float = snapped(chain_player.current_weapon_orientation_degrees.y, 0.0001)
	var quarter_two_hand_state: StringName = chain_player.current_two_hand_state
	var quarter_primary_hand_slot: StringName = chain_player.current_primary_hand_slot
	var quarter_grip_mode: StringName = chain_player.current_preferred_grip_style_mode

	chain_player.stop()
	chain_player.prepare([from_node, to_node], tip_curve, pommel_curve, 1.0, false)
	chain_player.start()
	chain_player.advance(0.75)
	var three_quarter_orientation_y: float = snapped(chain_player.current_weapon_orientation_degrees.y, 0.0001)
	var three_quarter_two_hand_state: StringName = chain_player.current_two_hand_state
	var three_quarter_primary_hand_slot: StringName = chain_player.current_primary_hand_slot
	var three_quarter_grip_mode: StringName = chain_player.current_preferred_grip_style_mode

	var lines: PackedStringArray = []
	lines.append("start_orientation_y=%s" % str(start_orientation_y))
	lines.append("quarter_orientation_y=%s" % str(quarter_orientation_y))
	lines.append("three_quarter_orientation_y=%s" % str(three_quarter_orientation_y))
	lines.append("start_two_hand_state=%s" % String(start_two_hand_state))
	lines.append("quarter_two_hand_state=%s" % String(quarter_two_hand_state))
	lines.append("three_quarter_two_hand_state=%s" % String(three_quarter_two_hand_state))
	lines.append("start_primary_hand_slot=%s" % String(start_primary_hand_slot))
	lines.append("quarter_primary_hand_slot=%s" % String(quarter_primary_hand_slot))
	lines.append("three_quarter_primary_hand_slot=%s" % String(three_quarter_primary_hand_slot))
	lines.append("start_grip_mode=%s" % String(start_grip_mode))
	lines.append("quarter_grip_mode=%s" % String(quarter_grip_mode))
	lines.append("three_quarter_grip_mode=%s" % String(three_quarter_grip_mode))
	lines.append("weapon_orientation_applied=%s" % str(is_equal_approx(start_orientation_y, 45.0)))
	lines.append("quarter_orientation_interpolated=%s" % str(is_equal_approx(quarter_orientation_y, 56.25)))
	lines.append("three_quarter_orientation_interpolated=%s" % str(is_equal_approx(three_quarter_orientation_y, 78.75)))
	lines.append("quarter_state_uses_from_node=%s" % str(
		quarter_two_hand_state == CombatAnimationMotionNodeScript.TWO_HAND_STATE_ONE_HAND
		and quarter_primary_hand_slot == CombatAnimationMotionNodeScript.PRIMARY_HAND_RIGHT
		and quarter_grip_mode == &"grip_normal"
	))
	lines.append("three_quarter_state_uses_to_node=%s" % str(
		three_quarter_two_hand_state == CombatAnimationMotionNodeScript.TWO_HAND_STATE_TWO_HAND
		and three_quarter_primary_hand_slot == CombatAnimationMotionNodeScript.PRIMARY_HAND_LEFT
		and three_quarter_grip_mode == &"grip_reverse"
	))

	var bezier_from_node: CombatAnimationMotionNode = CombatAnimationMotionNodeScript.new()
	bezier_from_node.tip_position_local = Vector3(0.0, 0.0, 0.0)
	bezier_from_node.tip_curve_out_handle = Vector3(0.0, 0.45, 0.0)
	bezier_from_node.pommel_position_local = Vector3(-0.2, 0.0, 0.0)
	bezier_from_node.transition_duration_seconds = 0.5
	bezier_from_node.normalize()
	var bezier_to_node: CombatAnimationMotionNode = CombatAnimationMotionNodeScript.new()
	bezier_to_node.tip_position_local = Vector3(1.0, 0.0, 0.0)
	bezier_to_node.tip_curve_in_handle = Vector3(0.0, 0.45, 0.0)
	bezier_to_node.pommel_position_local = Vector3(0.8, 0.0, 0.0)
	bezier_to_node.transition_duration_seconds = 1.0
	bezier_to_node.normalize()
	var bezier_tip_curve := Curve3D.new()
	bezier_tip_curve.bake_interval = 0.01
	bezier_tip_curve.add_point(
		bezier_from_node.tip_position_local,
		bezier_from_node.tip_curve_in_handle,
		bezier_from_node.tip_curve_out_handle
	)
	bezier_tip_curve.add_point(
		bezier_to_node.tip_position_local,
		bezier_to_node.tip_curve_in_handle,
		bezier_to_node.tip_curve_out_handle
	)
	var bezier_pommel_curve := Curve3D.new()
	bezier_pommel_curve.bake_interval = 0.01
	bezier_pommel_curve.add_point(bezier_from_node.pommel_position_local)
	bezier_pommel_curve.add_point(bezier_to_node.pommel_position_local)
	chain_player.prepare([bezier_from_node, bezier_to_node], bezier_tip_curve, bezier_pommel_curve, 1.0, false)
	chain_player.start()
	chain_player.advance(0.5)
	var bezier_half_tip: Vector3 = chain_player.current_tip_position
	var bezier_half_length: float = chain_player.current_tip_position.distance_to(chain_player.current_pommel_position)
	lines.append("bezier_half_tip_position=%s" % str(bezier_half_tip))
	lines.append("bezier_half_length=%.4f" % bezier_half_length)
	lines.append("bezier_tip_uses_handles_ok=%s" % str(bezier_half_tip.y > 0.05))
	lines.append("bezier_tip_not_linear_ok=%s" % str(bezier_half_tip.distance_to(Vector3(0.5, 0.0, 0.0)) > 0.05))
	lines.append("bezier_segment_length_locked_ok=%s" % str(absf(bezier_half_length - 0.2) <= 0.005))

	var swap_from_node: CombatAnimationMotionNode = CombatAnimationMotionNodeScript.new()
	swap_from_node.tip_position_local = Vector3(0.0, 1.0, 0.0)
	swap_from_node.tip_curve_out_handle = Vector3(0.65, 0.0, 0.0)
	swap_from_node.pommel_position_local = Vector3(0.0, -0.5, 0.0)
	swap_from_node.pommel_curve_out_handle = Vector3(-0.35, 0.0, 0.0)
	swap_from_node.preferred_grip_style_mode = &"grip_normal"
	swap_from_node.transition_duration_seconds = 1.0
	swap_from_node.normalize()
	var swap_to_node: CombatAnimationMotionNode = CombatAnimationMotionNodeScript.new()
	swap_to_node.tip_position_local = Vector3(0.0, -1.0, 0.0)
	swap_to_node.tip_curve_in_handle = Vector3(0.65, 0.0, 0.0)
	swap_to_node.pommel_position_local = Vector3(0.0, 0.5, 0.0)
	swap_to_node.pommel_curve_in_handle = Vector3(-0.35, 0.0, 0.0)
	swap_to_node.preferred_grip_style_mode = &"grip_reverse"
	swap_to_node.generated_transition_node = true
	swap_to_node.generated_transition_kind = CombatAnimationMotionNodeScript.TRANSITION_KIND_GRIP_STYLE_SWAP
	swap_to_node.transition_duration_seconds = 1.0
	swap_to_node.normalize()
	var swap_tip_curve := Curve3D.new()
	swap_tip_curve.bake_interval = 0.01
	swap_tip_curve.add_point(
		swap_from_node.tip_position_local,
		swap_from_node.tip_curve_in_handle,
		swap_from_node.tip_curve_out_handle
	)
	swap_tip_curve.add_point(
		swap_to_node.tip_position_local,
		swap_to_node.tip_curve_in_handle,
		swap_to_node.tip_curve_out_handle
	)
	var swap_pommel_curve := Curve3D.new()
	swap_pommel_curve.bake_interval = 0.01
	swap_pommel_curve.add_point(
		swap_from_node.pommel_position_local,
		swap_from_node.pommel_curve_in_handle,
		swap_from_node.pommel_curve_out_handle
	)
	swap_pommel_curve.add_point(
		swap_to_node.pommel_position_local,
		swap_to_node.pommel_curve_in_handle,
		swap_to_node.pommel_curve_out_handle
	)
	chain_player.prepare([swap_from_node, swap_to_node], swap_tip_curve, swap_pommel_curve, 1.0, false)
	chain_player.start()
	chain_player.advance(0.5)
	var swap_half_tip: Vector3 = chain_player.current_tip_position
	var swap_half_pommel: Vector3 = chain_player.current_pommel_position
	var swap_half_axis: Vector3 = swap_half_tip - swap_half_pommel
	var swap_pivot_ratio: float = 0.3333333
	var swap_half_pivot: Vector3 = swap_half_pommel + swap_half_axis * swap_pivot_ratio
	var swap_source_contact_axis: Vector3 = (swap_from_node.tip_position_local - Vector3.ZERO).normalized()
	var swap_half_contact_axis: Vector3 = chain_player.current_contact_grip_axis_local
	var swap_half_contact_axis_override_active: bool = chain_player.current_contact_grip_axis_local_override_active
	lines.append("grip_swap_half_tip=%s" % str(swap_half_tip))
	lines.append("grip_swap_half_pommel=%s" % str(swap_half_pommel))
	lines.append("grip_swap_half_length=%.4f" % swap_half_axis.length())
	lines.append("grip_swap_half_pivot=%s" % str(swap_half_pivot))
	lines.append("grip_swap_half_grip_mode=%s" % String(chain_player.current_preferred_grip_style_mode))
	lines.append("grip_swap_half_contact_axis=%s" % str(swap_half_contact_axis))
	lines.append("grip_swap_length_locked_ok=%s" % str(absf(swap_half_axis.length() - 1.5) <= 0.005))
	lines.append("grip_swap_fixed_pivot_ok=%s" % str(swap_half_pivot.length() <= 0.005))
	lines.append("grip_swap_holds_source_grip_until_node_reached=%s" % str(chain_player.current_preferred_grip_style_mode == &"grip_normal"))
	lines.append("grip_swap_contact_axis_override_active_ok=%s" % str(swap_half_contact_axis_override_active))
	lines.append("grip_swap_contact_axis_holds_source_ok=%s" % str(swap_half_contact_axis.dot(swap_source_contact_axis) >= 0.99))

	var auto_curve_editor: CombatAnimationMotionNodeEditor = CombatAnimationMotionNodeEditorScript.new()
	var auto_node_a: CombatAnimationMotionNode = CombatAnimationMotionNodeScript.new()
	auto_node_a.tip_position_local = Vector3(-1.0, 0.0, 0.0)
	auto_node_a.pommel_position_local = Vector3(-1.0, -0.3, 0.0)
	auto_node_a.transition_duration_seconds = 0.5
	auto_node_a.normalize()
	var auto_node_b: CombatAnimationMotionNode = CombatAnimationMotionNodeScript.new()
	auto_node_b.tip_position_local = Vector3(0.0, 0.7, 0.0)
	auto_node_b.pommel_position_local = Vector3(0.0, 0.4, 0.0)
	auto_node_b.transition_duration_seconds = 0.5
	auto_node_b.normalize()
	var auto_node_c: CombatAnimationMotionNode = CombatAnimationMotionNodeScript.new()
	auto_node_c.tip_position_local = Vector3(1.0, 0.0, 0.0)
	auto_node_c.pommel_position_local = Vector3(1.0, -0.3, 0.0)
	auto_node_c.transition_duration_seconds = 0.5
	auto_node_c.normalize()
	var auto_chain: Array = [auto_node_a, auto_node_b, auto_node_c]
	var auto_middle_tip_in: Vector3 = auto_curve_editor.resolve_effective_curve_handle(auto_chain, 1, true, true)
	var auto_middle_tip_out: Vector3 = auto_curve_editor.resolve_effective_curve_handle(auto_chain, 1, true, false)
	var auto_tip_curve: Curve3D = auto_curve_editor.build_tip_curve(auto_chain)
	var auto_pommel_curve: Curve3D = auto_curve_editor.build_pommel_curve(auto_chain)
	lines.append("auto_middle_tip_in_handle=%s" % str(auto_middle_tip_in))
	lines.append("auto_middle_tip_out_handle=%s" % str(auto_middle_tip_out))
	lines.append("auto_tip_curve_baked_count=%d" % auto_tip_curve.get_baked_points().size())
	lines.append("auto_curve_handles_generated_ok=%s" % str(auto_middle_tip_in.length() > 0.01 and auto_middle_tip_out.length() > 0.01))
	lines.append("auto_curve_has_baked_path_ok=%s" % str(auto_tip_curve.get_baked_points().size() > 3 and auto_pommel_curve.get_baked_points().size() > 3))

	var file: FileAccess = FileAccess.open(RESULT_FILE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()
	quit()
