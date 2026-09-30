extends RefCounted

## Isolated native point-target experiment. Real measured skin witnesses become
## temporary rigid child markers; they are NOT a replacement for blended skin.
## The caller must reconstruct actual skin and check every contact/collision.
const ROOT := &"RL_BoneRoot"
const SOLVER_ORIGIN := &"NativeDigitIKMillimetreOrigin"
## CCDIK3D uses is_zero_approx on a product of squared lever lengths.
## Metric finger levers fall below that fixed engine threshold. This explicit
## computational unit frame changes numerical units, never anatomy/world size.
const SOLVER_UNITS_PER_METRE: float = 1000.0
const OWNER := &"native_digit_contact_ik_proof"
const REVISION := &"native_digit_contact_ik_v2"
const DIGITS: Array[StringName] = [&"middle", &"thumb"]
const ANGLE_NUMERIC_TOLERANCE: float = 0.00002
const OFF_AXIS_TOLERANCE: float = 0.0005
const FRAME_TOLERANCE: float = 0.000005
const ITERATIONS: int = 24
const MAX_FRAME_WAITS: int = 4
const Chronology = preload("res://runtime/player/grip/grip_chronology.gd")


func prepare(parent: Node, context: Dictionary) -> Dictionary:
	if parent == null or not parent.is_inside_tree() or not context.get("valid", false) or not context.get("adapter") is Dictionary:
		return _fail("native_ik_requires_tree_parent_and_prepared_context")
	var adapter: Dictionary = context.adapter
	var digits: Array[StringName] = []
	var requested: Variant = context.get("digit_order", DIGITS)
	if not requested is Array or requested.is_empty(): return _fail("missing_ordered_native_digits")
	for value: Variant in requested:
		if not (value is String or value is StringName): return _fail("invalid_ordered_native_digit")
		var digit := StringName(value)
		if digits.has(digit): return _fail("duplicate_ordered_native_digit")
		digits.append(digit)
	for digit: StringName in digits:
		if not adapter.get("digit_inputs", {}).has(digit): return _fail("missing_prepared_native_digit")
		var snapshot: Dictionary = adapter.digit_inputs[digit].snapshot
		if snapshot.get("bone_root_origin_id") != ROOT or snapshot.bone_names.size() != 3:
			return _fail("invalid_native_digit_origin_chain")
		for joint: int in 3:
			if snapshot.hinge_axis_origin_ids[joint] != snapshot.bone_names[joint] or snapshot.relative_transform_origin_ids[joint] == &"":
				return _fail("missing_named_hinge_or_relative_frame")
			var expected_parent: StringName = adapter.hand_bone_name if joint == 0 else snapshot.bone_names[joint - 1]
			if snapshot.relative_transform_origin_ids[joint] != expected_parent:
				return _fail("native_digit_parent_chain_does_not_match_selected_hand")
			if not (snapshot.hinge_axes_local[joint] as Vector3).is_finite() or (snapshot.hinge_axes_local[joint] as Vector3).length_squared() < 0.5:
				return _fail("invalid_prepared_hinge_axis")
	var owner := Node3D.new()
	owner.name = "NativeDigitContactIKProof"
	owner.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	owner.set_meta("owner_system", OWNER)
	parent.add_child(owner)
	var skeleton := Skeleton3D.new()
	skeleton.name = "IsolatedNamedHandSkeleton"
	skeleton.modifier_callback_mode_process = Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_MANUAL
	owner.add_child(skeleton)
	var root_index: int = skeleton.add_bone(String(SOLVER_ORIGIN))
	var hand_index: int = skeleton.add_bone(_native_name(adapter.hand_bone_name))
	skeleton.set_bone_parent(hand_index, root_index)
	skeleton.set_bone_rest(root_index, Transform3D.IDENTITY)
	var indices: Dictionary = {}
	var zero_frames: Dictionary = {}
	var proxies: Dictionary = {}
	for digit: StringName in digits:
		var snapshot: Dictionary = adapter.digit_inputs[digit].snapshot
		var bones: Array[int] = []
		var zeros: Array[Transform3D] = []
		var previous: int = hand_index
		for joint: int in 3:
			var index: int = skeleton.add_bone(_native_name(snapshot.bone_names[joint]))
			skeleton.set_bone_parent(index, previous)
			var relative: Transform3D = snapshot.relative_transforms[joint]
			var zero := Transform3D(relative.basis * Basis(snapshot.neutral_local_rotations[joint]), relative.origin)
			if not _representable(zero): owner.queue_free(); return _fail("native_pose_cannot_represent_prepared_affine_joint")
			skeleton.set_bone_rest(index, _to_solver_frame(zero))
			bones.append(index); zeros.append(zero); previous = index
		indices[digit] = bones; zero_frames[digit] = zeros
		for section: int in [1, 2, 3]:
			if digit == &"thumb" and section == 1: continue
			var id := StringName(String(snapshot.bone_names[section - 1]) + "NativeSkinContactProxyMillimetreOrigin")
			var index: int = skeleton.add_bone(String(id))
			skeleton.set_bone_parent(index, bones[section - 1])
			skeleton.set_bone_rest(index, Transform3D.IDENTITY)
			proxies[_key(digit, section)] = {"index": index, "origin_id": id, "parent_origin_id": StringName(_native_name(snapshot.bone_names[section - 1])), "source_parent_origin_id": snapshot.bone_names[section - 1]}
	var target := Node3D.new()
	target.name = "CurrentContactTarget"
	target.set_meta("position_world_origin_id", ROOT)
	target.set_meta("owner_system", OWNER)
	owner.add_child(target)
	var modifier := CCDIK3D.new()
	modifier.name = "NativeMeasuredSkinPointIK"
	modifier.active = false
	modifier.influence = 1.0
	modifier.deterministic = true
	modifier.mutable_bone_axes = true
	modifier.max_iterations = ITERATIONS
	modifier.min_distance = 0.00001 * SOLVER_UNITS_PER_METRE
	modifier.angular_delta_limit = deg_to_rad(5.0)
	skeleton.add_child(modifier)
	modifier.setting_count = 1
	modifier.set_target_node(0, modifier.get_path_to(target))
	modifier.set_extend_end_bone(0, false)
	return {"valid": true, "revision": REVISION, "owner": owner, "skeleton": skeleton,
		"modifier": modifier, "target": target, "root_index": root_index, "hand_index": hand_index,
		"indices": indices, "zero_frames": zero_frames, "proxies": proxies,
		"digits": digits.duplicate(),
		"inputs": adapter.digit_inputs.duplicate(true), "hand_bone_name": adapter.hand_bone_name,
		"source_signature": adapter.anatomy_signature, "busy": false,
		"native_process_count": 0, "solve_call_count": 0, "owner_system": OWNER,
		"actual_skin_validation_required": true, "production_pose_written": false}


## Sections are 1-based. Contact positions are world presentation coordinates
## explicitly resolved through RL_BoneRoot, never anonymous node-local offsets.
## fixed_upstream_count optionally locks that many initial digit hinges at their
## current angles for this call only. Anatomical ranges remain unchanged.
func solve(prepared: Dictionary, current_candidate: Dictionary, contacts: Array) -> Dictionary:
	if not prepared.get("valid", false) or prepared.get("revision") != REVISION:
		return _fail("invalid_native_ik_handle")
	if not _host_alive(prepared): return _host_freed(prepared)
	if prepared.busy: return _fail("native_ik_handle_already_solving")
	if not current_candidate.get("valid", false) or not current_candidate.get("pose_packet") is Dictionary or contacts.is_empty():
		return _fail("missing_candidate_or_contacts")
	var packet: Dictionary = current_candidate.pose_packet
	if not packet.get("machine_to_world") is Transform3D or not _representable(packet.machine_to_world):
		return _fail("invalid_candidate_machine_presentation")
	var checked: Dictionary = _contacts(prepared, current_candidate, contacts)
	if not checked.get("valid", false): return checked
	prepared.busy = true
	prepared.solve_call_count += 1
	var started := Time.get_ticks_usec()
	var angles: Dictionary = {}
	for digit: StringName in prepared.digits: angles[digit] = current_candidate.digit_states[digit].angles_rad.duplicate()
	var calls: Array = []
	var violations: Array = []
	var solved_origin_records: Array = []
	var max_off_axis: float = 0.0
	var sync: Dictionary = _sync(prepared, current_candidate, angles)
	if not sync.get("valid", false): prepared.busy = false; return sync
	var baseline_error: float = 0.0
	for digit: StringName in prepared.digits:
		for joint: int in 3:
			var actual: Transform3D = prepared.skeleton.global_transform * prepared.skeleton.get_bone_global_pose(prepared.indices[digit][joint])
			actual.basis = actual.basis * SOLVER_UNITS_PER_METRE
			baseline_error = maxf(baseline_error, _frame_error(actual, current_candidate.digit_states[digit].joint_transforms_world[joint]))
	if baseline_error > FRAME_TOLERANCE:
		prepared.busy = false; return _fail("native_initial_pose_round_trip_failed", {"error": baseline_error})
	# One setting per call. Rebase limits after each shared-bone result rather
	# than applying stale current-pose offsets to later CCD settings.
	for contact: Dictionary in checked.contacts:
		sync = _sync(prepared, current_candidate, angles)
		if not sync.get("valid", false): prepared.busy = false; return sync
		var modifier: CCDIK3D = prepared.modifier
		var skeleton: Skeleton3D = prepared.skeleton
		var proxy: Dictionary = prepared.proxies[_key(contact.digit, contact.section)]
		var marker := Transform3D(Basis.IDENTITY, contact.marker_position_local * SOLVER_UNITS_PER_METRE)
		skeleton.set_bone_rest(proxy.index, marker)
		_set_pose(skeleton, proxy.index, marker)
		prepared.target.global_position = contact.target_point_world
		# Rebuild before switching digits: the old end is not a descendant of
		# the new root, and ChainIK3D validates each setter immediately.
		modifier.setting_count = 0
		modifier.setting_count = 1
		modifier.set_target_node(0, modifier.get_path_to(prepared.target))
		modifier.set_root_bone(0, prepared.indices[contact.digit][0])
		modifier.set_end_bone(0, proxy.index)
		modifier.set_extend_end_bone(0, false)
		if modifier.get_joint_count(0) != int(contact.section) + 1:
			prepared.busy = false; return _fail("unexpected_native_contact_chain")
		var snapshot: Dictionary = prepared.inputs[contact.digit].snapshot
		var temporary_constraints: Array = []
		for joint: int in int(contact.section):
			var axis: Vector3 = (snapshot.hinge_axes_local[joint] as Vector3).normalized()
			modifier.set_joint_rotation_axis(0, joint, SkeletonModifier3D.ROTATION_AXIS_CUSTOM)
			modifier.set_joint_rotation_axis_vector(0, joint, axis)
			modifier.set_joint_limitation_right_axis(0, joint, SkeletonModifier3D.SECONDARY_DIRECTION_CUSTOM)
			modifier.set_joint_limitation_right_axis_vector(0, joint, axis)
			var lower: float = snapshot.min_angles_rad[joint]
			var upper: float = snapshot.max_angles_rad[joint]
			if joint < int(contact.fixed_upstream_count):
				temporary_constraints.append({"digit": contact.digit, "section": joint + 1,
					"origin_id": snapshot.bone_names[joint], "fixed_angle_rad": float(angles[contact.digit][joint]),
					"anatomical_min_rad": lower, "anatomical_max_rad": upper,
					"scope": &"current_contact_call_only"})
				lower = float(angles[contact.digit][joint])
				upper = lower
			var cone := JointLimitationCone3D.new()
			cone.angle = upper - lower
			modifier.set_joint_limitation(0, joint, cone)
			modifier.set_joint_limitation_rotation_offset(0, joint, Quaternion(Vector3.RIGHT, (lower + upper) * 0.5 - float(angles[contact.digit][joint])))
		var capture: Dictionary = {"count": 0}
		var callback: Callable = func() -> void:
			if not _host_alive(prepared): return
			capture.count += 1
			var local: Dictionary = {}
			for digit: StringName in prepared.digits:
				var poses: Array[Transform3D] = []
				for index: int in prepared.indices[digit]: poses.append(_from_solver_frame(skeleton.get_bone_pose(index)))
				local[digit] = poses
			capture["local_poses"] = local
			capture["root_pose"] = _from_solver_frame(skeleton.get_bone_pose(prepared.root_index))
			capture["hand_pose"] = _from_solver_frame(skeleton.get_bone_pose(prepared.hand_index))
			capture["proxy_world"] = skeleton.global_transform * skeleton.get_bone_global_pose(proxy.index).origin
			capture["origin_records"] = _origin_records(skeleton)
		modifier.modification_processed.connect(callback)
		modifier.active = true
		var advance_span := Chronology.begin("native.skeleton_advance", {"digit":contact.digit,"section":contact.section})
		skeleton.advance(1.0 / 60.0)
		Chronology.finish(advance_span, {"process_count":capture.count})
		if not _host_alive(prepared): return _host_freed(prepared, callback)
		for _frame: int in MAX_FRAME_WAITS:
			if capture.count > 0: break
			Chronology.event("native.wait_frame", {"digit":contact.digit,"section":contact.section,"frame":_frame})
			await skeleton.get_tree().process_frame
			if not _host_alive(prepared): return _host_freed(prepared, callback)
		modifier.active = false
		modifier.modification_processed.disconnect(callback)
		prepared.native_process_count += int(capture.count)
		if capture.count != 1:
			prepared.busy = false; return _fail("native_modifier_did_not_process_once", {"process_count": capture.count})
		var extracted: Dictionary = _extract(prepared, capture.local_poses, angles)
		var temporary_violations: Array = []
		if extracted.get("valid", false):
			for constraint: Dictionary in temporary_constraints:
				var actual_angle: float = extracted.angles[constraint.digit][constraint.section - 1]
				if absf(actual_angle - float(constraint.fixed_angle_rad)) > ANGLE_NUMERIC_TOLERANCE:
					var violation: Dictionary = constraint.duplicate(true)
					violation["solved_angle_rad"] = actual_angle
					temporary_violations.append(violation)
			if not temporary_violations.is_empty():
				extracted["valid"] = false
				extracted["reason"] = "native_temporary_joint_lock_violation"
		solved_origin_records = capture.origin_records
		max_off_axis = maxf(max_off_axis, float(extracted.get("off_axis_error_rad", 0.0)))
		violations.append_array(extracted.get("joint_limit_violations", []))
		calls.append({"digit": contact.digit, "section": contact.section, "source_id": contact.source_id,
			"fixed_upstream_count": contact.fixed_upstream_count, "temporary_joint_constraints": temporary_constraints,
			"temporary_joint_lock_violations": temporary_violations,
			"proxy_origin_id": proxy.origin_id, "marker_position_local": contact.marker_position_local,
			"marker_position_local_origin_id": proxy.source_parent_origin_id,
			"marker_position_solver_units": marker.origin, "marker_position_solver_origin_id": proxy.parent_origin_id,
			"target_point_world": contact.target_point_world, "target_point_world_origin_id": ROOT,
			"solved_proxy_world": capture.proxy_world, "solved_proxy_world_origin_id": ROOT,
			"proxy_error_m": (capture.proxy_world as Vector3).distance_to(contact.target_point_world),
			"native_process_count": capture.count, "native_iterations_limit": ITERATIONS})
		if not extracted.get("valid", false):
			prepared.busy = false
			return {"valid": false, "reason": extracted.reason, "native_calls": calls,
				"native_process_count": calls.size(), "off_axis_error_rad": max_off_axis,
				"joint_limit_violations": violations, "temporary_joint_lock_violations": temporary_violations,
				"actual_skin_validation_required": true}
		if _frame_error(capture.root_pose, Transform3D.IDENTITY) > FRAME_TOLERANCE or _frame_error(capture.hand_pose, sync.hand_machine) > FRAME_TOLERANCE:
			prepared.busy = false; return _fail("native_ik_changed_upstream_frame")
		angles = extracted.angles
	prepared.busy = false
	return {"valid": true, "angles": angles, "native_calls": calls, "native_process_count": calls.size(),
		"origin_records": solved_origin_records, "machine_to_world": packet.machine_to_world,
		"solver_origin_id": SOLVER_ORIGIN, "solver_units_per_metre": SOLVER_UNITS_PER_METRE,
		"off_axis_error_rad": max_off_axis, "joint_limit_violations": violations,
		"temporary_joint_lock_violations": [],
		"initial_pose_round_trip_error": baseline_error, "solve_ms": float(Time.get_ticks_usec() - started) / 1000.0,
		"solver": &"Godot47_CCDIK3D", "native_limit_resource": &"JointLimitationCone3D",
		"proxy_policy": &"frozen_measured_skin_witness_rigidly_attached_to_selected_section",
		"actual_skin_validation_required": true, "grip_accepted": false, "production_pose_written": false}


func _contacts(prepared: Dictionary, candidate: Dictionary, contacts: Array) -> Dictionary:
	var out: Array = []
	var seen: Dictionary = {}
	for value: Variant in contacts:
		if not value is Dictionary: return _fail("invalid_native_contact")
		var contact: Dictionary = value
		var digit := StringName(contact.get("digit", &""))
		var section := int(contact.get("section", 0))
		var key: String = _key(digit, section)
		if not prepared.proxies.has(key) or seen.has(key): return _fail("unsupported_or_duplicate_native_section")
		var fixed: Variant = contact.get("fixed_upstream_count", 0)
		if not fixed is int or int(fixed) < 0 or int(fixed) >= section:
			return _fail("invalid_native_fixed_upstream_count")
		seen[key] = true
		if contact.get("skin_origin_id") != ROOT or contact.get("target_origin_id") != ROOT or StringName(contact.get("source_id", &"")) == &"":
			return _fail("missing_native_contact_origin_or_source")
		if not contact.get("skin_point_world") is Vector3 or not contact.get("target_point_world") is Vector3:
			return _fail("missing_native_contact_points")
		if not contact.skin_point_world.is_finite() or not contact.target_point_world.is_finite(): return _fail("nonfinite_native_contact_points")
		var joint: Transform3D = candidate.digit_states[digit].joint_transforms_world[section - 1]
		var local: Vector3 = joint.affine_inverse() * (contact.skin_point_world as Vector3)
		if local.length_squared() < 1.0e-12: return _fail("contact_proxy_at_joint_has_no_rotational_lever")
		var item: Dictionary = contact.duplicate(true)
		item["digit"] = digit; item["section"] = section; item["marker_position_local"] = local
		item["fixed_upstream_count"] = int(fixed)
		out.append(item)
	return {"valid": true, "contacts": out}


func _sync(prepared: Dictionary, candidate: Dictionary, angles: Dictionary) -> Dictionary:
	if not _host_alive(prepared): return _host_freed(prepared)
	var skeleton: Skeleton3D = prepared.skeleton
	var machine_to_world: Transform3D = candidate.pose_packet.machine_to_world
	skeleton.global_transform = machine_to_world * _solver_to_machine()
	var hand_machine: Transform3D = machine_to_world.affine_inverse() * (candidate.hand_to_world as Transform3D)
	if not _representable(hand_machine): return _fail("native_hand_frame_not_pose_representable")
	skeleton.set_bone_rest(prepared.hand_index, _to_solver_frame(hand_machine))
	_set_pose(skeleton, prepared.root_index, Transform3D.IDENTITY)
	_set_pose(skeleton, prepared.hand_index, _to_solver_frame(hand_machine))
	for digit: StringName in prepared.digits:
		var snapshot: Dictionary = prepared.inputs[digit].snapshot
		for joint: int in 3:
			var zero: Transform3D = prepared.zero_frames[digit][joint]
			var pose := Transform3D(zero.basis * Basis((snapshot.hinge_axes_local[joint] as Vector3).normalized(), float(angles[digit][joint])), zero.origin)
			if not _representable(pose): return _fail("native_joint_frame_not_pose_representable")
			_set_pose(skeleton, prepared.indices[digit][joint], _to_solver_frame(pose))
	return {"valid": true, "hand_machine": hand_machine}


func _extract(prepared: Dictionary, poses: Dictionary, previous: Dictionary) -> Dictionary:
	var angles: Dictionary = {}
	var violations: Array = []
	var off_axis: float = 0.0
	for digit: StringName in prepared.digits:
		var snapshot: Dictionary = prepared.inputs[digit].snapshot
		var values: Array = []
		for joint: int in 3:
			var zero: Transform3D = prepared.zero_frames[digit][joint]
			var pose: Transform3D = poses[digit][joint]
			if not pose.is_finite(): return _fail("nonfinite_native_joint_result")
			var delta: Basis = zero.basis.inverse() * pose.basis
			var q: Quaternion = delta.orthonormalized().get_rotation_quaternion().normalized()
			var axis: Vector3 = (snapshot.hinge_axes_local[joint] as Vector3).normalized()
			var angle: float = 2.0 * atan2(Vector3(q.x, q.y, q.z).dot(axis), q.w)
			angle = float(previous[digit][joint]) + wrapf(angle - float(previous[digit][joint]), -PI, PI)
			var expected := Quaternion(axis, angle)
			var difference: Quaternion = expected.inverse() * q
			var error: float = 2.0 * atan2(Vector3(difference.x, difference.y, difference.z).length(), absf(difference.w))
			off_axis = maxf(off_axis, error)
			if pose.origin.distance_to(zero.origin) > FRAME_TOLERANCE or _basis_error(delta, Basis(q)) > FRAME_TOLERANCE:
				return _fail("native_joint_changed_position_or_metric")
			var low: float = snapshot.min_angles_rad[joint]
			var high: float = snapshot.max_angles_rad[joint]
			if angle < low - ANGLE_NUMERIC_TOLERANCE or angle > high + ANGLE_NUMERIC_TOLERANCE:
				violations.append({"digit": digit, "section": joint + 1, "angle_rad": angle, "min_rad": low, "max_rad": high})
			values.append(clampf(angle, low, high))
		angles[digit] = values
	if not violations.is_empty() or off_axis > OFF_AXIS_TOLERANCE:
		return {"valid": false, "reason": "native_joint_limit_or_axis_violation", "joint_limit_violations": violations, "off_axis_error_rad": off_axis}
	return {"valid": true, "angles": angles, "joint_limit_violations": [], "off_axis_error_rad": off_axis}


func dispose(prepared: Dictionary) -> void:
	if is_instance_valid(prepared.get("owner")): prepared.owner.queue_free()
	prepared["valid"] = false


func _set_pose(skeleton: Skeleton3D, index: int, pose: Transform3D) -> void:
	skeleton.set_bone_pose_position(index, pose.origin)
	skeleton.set_bone_pose_rotation(index, pose.basis.get_rotation_quaternion())
	skeleton.set_bone_pose_scale(index, pose.basis.get_scale())


func _representable(frame: Transform3D) -> bool:
	if not frame.is_finite() or frame.basis.determinant() <= 1.0e-12: return false
	var rebuilt: Basis = Basis(frame.basis.get_rotation_quaternion()) * Basis.from_scale(frame.basis.get_scale())
	return _basis_error(frame.basis, rebuilt) <= FRAME_TOLERANCE


func _basis_error(a: Basis, b: Basis) -> float:
	return maxf(a.x.distance_to(b.x), maxf(a.y.distance_to(b.y), a.z.distance_to(b.z)))


func _frame_error(a: Transform3D, b: Transform3D) -> float:
	return maxf(a.origin.distance_to(b.origin), _basis_error(a.basis, b.basis))


func _key(digit: StringName, section: int) -> String:
	return String(digit) + "/" + str(section)


func _origin_records(skeleton: Skeleton3D) -> Array:
	var records: Array = [{"origin_id": ROOT, "parent_origin_id": &"", "transform_to_parent": Transform3D.IDENTITY,
		"owner_system": OWNER, "resolve_phase": &"editor_preview", "space_type": &"bone_frame", "is_dynamic": true}]
	for index: int in skeleton.get_bone_count():
		var parent: int = skeleton.get_bone_parent(index)
		records.append({"origin_id": StringName(skeleton.get_bone_name(index)),
			"parent_origin_id": StringName(skeleton.get_bone_name(parent)) if parent >= 0 else ROOT,
			"transform_to_parent": skeleton.get_bone_pose(index) if parent >= 0 else _solver_to_machine() * skeleton.get_bone_pose(index), "owner_system": OWNER,
			"resolve_phase": &"editor_preview", "space_type": &"bone_frame", "is_dynamic": true})
	return records


func _native_name(source_origin: StringName) -> String:
	return String(source_origin) + "NativeIKMillimetreOrigin"


func _solver_to_machine() -> Transform3D:
	return Transform3D(Basis.from_scale(Vector3.ONE / SOLVER_UNITS_PER_METRE), Vector3.ZERO)


func _to_solver_frame(metric_frame: Transform3D) -> Transform3D:
	return Transform3D(metric_frame.basis, metric_frame.origin * SOLVER_UNITS_PER_METRE)


func _from_solver_frame(solver_frame: Transform3D) -> Transform3D:
	return Transform3D(solver_frame.basis, solver_frame.origin / SOLVER_UNITS_PER_METRE)


func _fail(reason: String, detail: Dictionary = {}) -> Dictionary:
	return {"valid": false, "reason": reason, "detail": detail}


## A scene may close while the modifier awaits a frame. No mathematical state
## is changed for a live host; cancellation reports ownership loss explicitly.
func _host_alive(prepared: Dictionary) -> bool:
	for field: String in ["owner", "skeleton", "modifier", "target"]:
		var value: Variant = prepared.get(field)
		if not is_instance_valid(value) or not value is Node:
			return false
		if value.is_queued_for_deletion() or not value.is_inside_tree():
			return false
	return true


func _host_freed(prepared: Dictionary, callback: Callable = Callable()) -> Dictionary:
	var modifier: Variant = prepared.get("modifier")
	if is_instance_valid(modifier):
		modifier.active = false
		if callback.is_valid() and modifier.modification_processed.is_connected(callback):
			modifier.modification_processed.disconnect(callback)
	prepared["busy"] = false
	return _fail("native_host_freed")
