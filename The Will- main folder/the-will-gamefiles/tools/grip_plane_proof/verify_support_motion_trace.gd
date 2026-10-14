extends "res://tools/grip_plane_proof/verify_surface_grip_support.gd"

## Diagnostic only: observe the existing arm result before the retention guard
## rolls it back. Restore the accepted pose after each independent request.
func _verify_support_refresh_and_capture(context: Dictionary, owner: Node) -> void:
	var motion: Resource = _ui._get_active_motion_node()
	var tip: Vector3 = motion.tip_position_local
	var pommel: Vector3 = motion.pommel_position_local
	var saved: Dictionary = owner._support_motion_snapshot.duplicate(true)
	var traces: Array[Dictionary] = []
	for offset: Vector3 in [Vector3.ZERO, Vector3(0.015, 0, 0), Vector3(-0.015, 0, 0), Vector3(0, 0.015, 0), Vector3(0, -0.015, 0), Vector3(0, 0, 0.015), Vector3(0, 0, -0.015)]:
		owner._restoring_support_motion = true
		owner._write_support_motion_snapshot(saved)
		motion.tip_position_local = tip + offset
		motion.pommel_position_local = pommel + offset
		_ui._sync_preview_pose_only()
		var trace := {"offset_m": [offset.x, offset.y, offset.z], "after_ui": _inspect(context, owner, saved)}
		context.actor.settle_authoring_support_grip_macro_pose_now(0.000005)
		trace["after_extra_settle"] = _inspect(context, owner, saved)
		var binding: Dictionary = context.actor.planar_grip_pose_binding.relationship(SUPPORT, context.weapon)
		trace["frame_realization"] = context.actor.realize_prepared_support_hand_frame(SUPPORT, context.weapon.global_transform * (binding.hand_in_weapon as Transform3D), saved.poses[saved.hand_index])
		trace["after_complete_frame"] = _inspect(context, owner, saved)
		traces.append(trace)
		owner._write_support_motion_snapshot(saved)
		owner._restoring_support_motion = false
	_report["pre_guard_motion_traces"] = traces
	motion.tip_position_local = tip
	motion.pommel_position_local = pommel
	owner._restoring_support_motion = true
	owner._write_support_motion_snapshot(saved)
	owner._restoring_support_motion = false

func _inspect(context: Dictionary, owner: Node, saved: Dictionary) -> Dictionary:
	var actor: Node3D = context.actor
	var skeleton: Skeleton3D = actor.skeleton
	var hand_index := skeleton.find_bone("CC_Base_L_Hand")
	var actual: Transform3D = skeleton.global_transform * skeleton.get_bone_global_pose(hand_index)
	var bound: Dictionary = actor.planar_grip_pose_binding.relationship(SUPPORT, context.weapon)
	var desired: Transform3D = context.weapon.global_transform * (bound.hand_in_weapon as Transform3D)
	var clamped: Basis = actor._clamp_authoring_contact_wrist_twist(SUPPORT, &"CC_Base_L_Hand", &"CC_Base_L_Forearm", desired.basis)
	var clamped_again: Basis = actor._clamp_authoring_contact_wrist_twist(SUPPORT, &"CC_Base_L_Hand", &"CC_Base_L_Forearm", clamped)
	return {"weapon_movement_m_or_rad": _frame_error(saved.weapon_world, context.weapon.global_transform),
		"hand_position_error_m": actual.origin.distance_to(desired.origin),
		"hand_orientation_error_rad": _rotation_error(actual.basis.get_rotation_quaternion(), desired.basis.get_rotation_quaternion()),
		"wrist_reclamp_error_rad": _rotation_error(desired.basis.get_rotation_quaternion(), clamped.get_rotation_quaternion()),
		"wrist_clamp_second_pass_error_rad": _rotation_error(clamped.get_rotation_quaternion(), clamped_again.get_rotation_quaternion()),
		"actual_wrist_twist_rad": actor._resolve_authoring_contact_wrist_twist_angle(&"CC_Base_L_Hand", &"CC_Base_L_Forearm", actual.basis),
		"desired_wrist_twist_rad": actor._resolve_authoring_contact_wrist_twist_angle(&"CC_Base_L_Hand", &"CC_Base_L_Forearm", desired.basis),
		"arm": actor.last_two_hand_solve_result.get(SUPPORT, {}).duplicate(true)}
