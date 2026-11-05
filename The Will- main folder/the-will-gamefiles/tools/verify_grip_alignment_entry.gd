extends "res://tools/verify_skill_grip_reopen.gd"

var alignment_body_differences: Array[Dictionary] = []

## Same isolated library/real station harness as the cold-process verifier.
## --phase=write --hands=R,L --weapon=Broken_Balde_v1 --out=<fresh godot_runs dir>
## Perturbation represents a stale placement, not proof of a full Forge edit.
func _reopen_write(ui: CombatAnimationStationUI, side: String) -> void:
	_check_allocation(ui.reset_active_draft_to_baseline(), "isolated_reset")
	var ready := await _await_recorded_reset_baseline(ui)
	_check_allocation(ready.get("ready", false), "reset_grip_ready", ready)
	if not ready.get("ready", false): return
	for reverse: bool in [false, true]:
		if reverse:
			_check_allocation(ui.set_selected_motion_node_preferred_grip_style(CraftedItemWIP.GRIP_REVERSE, false), "UI_reverse_transition")
			ready = await _reopen_await_bound(ui, side)
			_check_allocation(ready.ready, "reverse_grip_ready", ready)
			if not ready.ready: return
		var actor := _get_preview_actor(ui) as PlayerHumanoidRig
		var weapon := _get_preview_held_item(ui)
		var owner := actor.get_node("PreparedGripAcquisition")
		var skeleton := actor.skeleton
		var bones := _alignment_body_snapshot(skeleton)
		var original := weapon.global_transform
		# Suspend the old mate before simulating a misaligned old/changed asset.
		owner.suspend_for_weapon_facing()
		var axis: Vector3 = (original.basis * ((weapon.get_meta("primary_grip_span_end_local") as Vector3) - (weapon.get_meta("primary_grip_span_start_local") as Vector3))).normalized()
		var reference := actor.capture_authoring_wrist_origin(_boundary_slot(side))
		var hand_world: Transform3D = reference.machine_to_world * reference.origin_record.resolved_transform_to_machine
		var tilt_axis := axis.cross(hand_world.basis.y).normalized()
		if tilt_axis.length_squared() < 0.1: tilt_axis = axis.cross(hand_world.basis.z).normalized()
		weapon.global_transform = Transform3D(Basis(tilt_axis, deg_to_rad(25.0)) * original.basis, original.origin + axis * 0.06)
		var stale := weapon.global_transform
		# Exercise the real manual-acquisition owner through the UI button.
		ui.grip_reacquire_button.pressed.emit()
		ready = await _reopen_await_bound(ui, side)
		var label := "reverse" if reverse else "normal"
		_check_allocation(ready.ready, label + "_manual_reacquire_ready", ready)
		var check := _alignment_geometry(actor, weapon, side, reverse)
		_check_allocation(check.valid, label + "_signed_axis_and_station", check)
		_check_allocation(not weapon.global_transform.is_equal_approx(stale), label + "_weapon_corrected")
		var body_unchanged := _alignment_body_unchanged(skeleton, bones)
		_check_allocation(body_unchanged, label + "_body_and_both_wrists_unchanged", {"bones": alignment_body_differences.duplicate(true)})
		_check_allocation(weapon.global_basis.get_scale().is_equal_approx(original.basis.get_scale()), label + "_weapon_scale_preserved")
		if String(options.get("probe-only", "false")) == "true": return
		if not ready.ready: return
		# The normal slider must enter the same preparation path.
		var node: CombatAnimationMotionNode = ui.call("_get_active_motion_node")
		var prior := node.grip_seat_slide_offset
		bones = _alignment_body_snapshot(skeleton)
		var change := ui.set_selected_motion_node_grip_seat_slide(prior + (0.08 if prior < 0.5 else -0.08), false)
		_check_allocation(change, label + "_UI_station_changed")
		ready = await _reopen_await_bound(ui, side)
		_check_allocation(ready.ready, label + "_station_reacquire_ready", ready)
		check = _alignment_geometry(actor, weapon, side, reverse)
		_check_allocation(check.valid, label + "_slider_signed_axis_and_station", check)
		body_unchanged = _alignment_body_unchanged(skeleton, bones)
		_check_allocation(body_unchanged, label + "_slider_body_unchanged", {"bones": alignment_body_differences.duplicate(true)})
		if not ready.ready: return
	await _reopen_capture(ui)
	await _reopen_save(ui)
	var disk := _reopen_saved_draft(ui)
	_check_allocation(disk != null and disk.baked_runtime_clip != null, "aligned_endpoints_saved_for_playback")

func _alignment_body_snapshot(skeleton: Skeleton3D) -> Dictionary:
	var result := {}
	for index: int in skeleton.get_bone_count():
		var name := skeleton.get_bone_name(index)
		if ["Index", "Mid", "Ring", "Pinky", "Thumb"].any(func(part: String): return name.contains("_R_" + part) or name.contains("_L_" + part)): continue
		result[index] = skeleton.get_bone_global_pose(index)
	return result

func _alignment_body_unchanged(skeleton: Skeleton3D, previous: Dictionary) -> bool:
	alignment_body_differences.clear()
	for index: int in previous:
		var before: Transform3D = previous[index]
		var after := skeleton.get_bone_global_pose(index)
		var distance := before.origin.distance_to(after.origin)
		var basis_error := maxf((before.basis.x - after.basis.x).length(), maxf((before.basis.y - after.basis.y).length(), (before.basis.z - after.basis.z).length()))
		if distance > 0.000005 or basis_error > 0.00001:
			alignment_body_differences.append({"bone": skeleton.get_bone_name(index), "distance": distance, "basis_error": basis_error})
	return alignment_body_differences.is_empty()

func _alignment_geometry(actor: PlayerHumanoidRig, weapon: Node3D, side: String, reverse: bool) -> Dictionary:
	var skeleton := actor.skeleton
	var index := skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone("CC_Base_%s_Index1" % side)).origin
	var pinky := skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone("CC_Base_%s_Pinky1" % side)).origin
	var target := (index - pinky).normalized() * (-1.0 if reverse else 1.0)
	var axis: Vector3 = weapon.global_basis * ((weapon.get_meta("primary_grip_span_end_local") as Vector3) - (weapon.get_meta("primary_grip_span_start_local") as Vector3))
	var tip: Vector3 = weapon.global_basis * ((weapon.get_meta("weapon_tip_local") as Vector3) - (weapon.get_meta("weapon_pommel_local") as Vector3))
	if axis.dot(tip) < 0: axis = -axis
	axis = axis.normalized()
	var station := weapon.to_global(weapon.get_meta("preview_primary_grip_seat_local"))
	var axial_error := absf((station - (index + pinky) * 0.5).dot(target))
	var direction_error := (axis - target).length()
	return {"valid": direction_error < 0.0001 and axial_error <= 0.00005, "direction_error": direction_error, "axial_error_m": axial_error,
		"alignment_preparation": weapon.get_meta("primary_grip_alignment", {})}
