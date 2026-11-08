extends "res://tools/diagnose_skill_crafter_elbow_correction.gd"

const Clearance = preload("res://runtime/player/combat_forearm_clearance_snapshot.gd")
const MathBackend = preload("res://core/resolvers/combat_motion_math_backend.gd")

## Focused actual station/body check. No R/F/Save lifecycle, no original save
## mutation. Inherited harness opens an isolated real saved weapon and waits
## for the ordinary Reset/acquisition path before exercising UI movement APIs.
func _run_thrust(ui: CombatAnimationStationUI, side: String, _elevation: float) -> Dictionary:
	var report := {"complete": false, "side": side, "requests": [], "failures": []}
	if not ui.reset_active_draft_to_baseline():
		return report.merged({"reason": "reset_failed"})
	var ready: Dictionary = await _await_recorded_reset_baseline(ui)
	report["readiness"] = ready
	if not ready.get("ready", false):
		return report.merged({"reason": "baseline_not_ready", "status": ui.footer_status_label.text})
	var actor: PlayerHumanoidRig = _get_preview_actor(ui) as PlayerHumanoidRig
	var prop: Node3D = _get_preview_held_item(ui)
	var skeleton: Skeleton3D = actor.skeleton
	var hand := skeleton.find_bone("CC_Base_" + side + "_Hand")
	var binding: Transform3D = prop.global_transform.affine_inverse() * skeleton.global_transform * skeleton.get_bone_global_pose(hand)
	if DisplayServer.get_name() != "headless":
		await _capture_frame(ui, actor, side, output_dir.path_join(side + "_start.png"))
	MathBackend.reset_backend_stats()
	for step: int in 24:
		var node: CombatAnimationMotionNode = ui.call("_get_active_motion_node")
		var display: CombatAnimationMotionNode = ui.call("_build_authoring_motion_node_baseline", node)
		var direction := Vector3(0.004, 0.002, 0.0) if step < 12 else Vector3(-0.004, -0.002, 0.0)
		var started := Time.get_ticks_usec()
		var changed := ui.set_selected_motion_node_pommel_position(display.pommel_position_local + direction, false)
		var elapsed_ms := float(Time.get_ticks_usec() - started) / 1000.0
		await _wait_frames(2)
		var actual: Transform3D = skeleton.global_transform * skeleton.get_bone_global_pose(hand)
		var expected: Transform3D = prop.global_transform * binding
		var difference: Quaternion = (actual.basis.orthonormalized().get_rotation_quaternion().inverse() * expected.basis.orthonormalized().get_rotation_quaternion()).normalized()
		var angle: float = 2.0 * atan2(Vector3(difference.x, difference.y, difference.z).length(), absf(difference.w))
		var sample := {"step": step, "changed": changed, "elapsed_ms": elapsed_ms,
			"contact_error_m": actual.origin.distance_to(expected.origin), "contact_error_degrees": rad_to_deg(angle),
			"status": ui.footer_status_label.text}
		var allocation: Dictionary = _get_preview_root(ui).get_meta("weapon_motion_allocation_result", {})
		for key: String in ["timings", "active_limits", "reason", "status", "task_scale", "clearance_slide", "search_failures", "storage_validation_failures"]:
			if allocation.has(key):
				sample["allocation_" + key] = allocation[key]
		report.requests.append(sample)
		if actual.origin.distance_to(expected.origin) > 0.00005 or angle > deg_to_rad(0.025):
			report.failures.append("stored_contact_out_of_tolerance:" + str(step))
		print("LIVE_FOREARM_MOTION ", JSON.stringify(sample))
	if DisplayServer.get_name() != "headless":
		await _capture_frame(ui, actor, side, output_dir.path_join(side + "_end.png"))
	report["math_backend"] = MathBackend.get_backend_stats()
	report.complete = true
	return report
