extends "res://tools/verify_combat_weapon_motion_rig.gd"

## Imported-rig, declared numerical fixtures. No saved skills or user assets.
## The isolated solves pin unrelated q channels ONLY in their test input, so
## wrist/elbow compensation cannot conceal a shoulder-boundary failure.
## Coverage re-entry is an explicit diagnostic, not a claim of solved motion.
const Shoulder = preload("res://core/resolvers/combat_shoulder_motion_resolver.gd")
const MotionAllocator = preload("res://core/resolvers/combat_weapon_motion_allocator.gd")
var coverage_diagnostics: Array[Dictionary] = []

func _run() -> void:
	actor_parent = Node3D.new()
	root.add_child(actor_parent)
	rig = RigScene.instantiate() as PlayerHumanoidRig
	# This verifier preserves the strict coverage/hold contract as a supported
	# policy. The separate provisional verifier exercises the expanded live data.
	rig.shoulder_motion_profile = rig.shoulder_motion_profile.duplicate(true)
	rig.shoulder_motion_profile.set("coverage_mode", "measured_band_only")
	actor_parent.add_child(rig)
	await process_frame
	await process_frame
	rig.set_authoring_preview_mode_enabled(true)
	rig.reset_authoring_preview_baseline_pose()
	rig.set_process(false)
	rig.set_physics_process(false)
	for tree: Node in rig.find_children("*", "AnimationTree", true, false):
		(tree as AnimationTree).active = false
	skeleton = rig.skeleton
	_check(skeleton != null, "imported_rig_available")
	if skeleton == null:
		_finish()
		return
	base_poses = _poses()
	for side: String in ["R", "L"]:
		_check_table_on_imported_rig(side)
		_check_boundary_motion(side, -113.0, -1.0)
		_check_boundary_motion(side, 41.0, 1.0)
		_check_held_reference(side)
		_check_held_swing_transition(side)
		_record_held_swing_chords(side)
		_check_root_transform(side)
		_record_coverage_reentry(side)
	_finish()

## All declared directions belong to the calibration's anatomical chest frame,
## not world axes. All bone frames below are Skeleton3D-relative through its
## actual imported ancestry to RL_BoneRoot. Only actor_parent is world-space.
func _fixture(side: String, direction: Vector3, h_degrees: float, held_h: float = NAN) -> Dictionary:
	_restore()
	actor_parent.transform = Transform3D.IDENTITY
	rig.get("_wrist_motion_states").clear()
	rig.get("_wrist_motion_failures").clear()
	rig.get("_shoulder_motion_states").clear()
	var slot := _slot(side)
	var calibration: Dictionary = rig.capture_shoulder_constraint_calibration(slot)
	if not calibration.get("valid", false): return calibration
	var c := skeleton.find_bone(String(calibration.chest_bone_name))
	var u := skeleton.find_bone(String(calibration.upperarm_bone_name))
	var f := skeleton.find_bone(String(calibration.forearm_bone_name))
	var hand_index := skeleton.find_bone("CC_Base_" + side + "_Hand")
	# The imported animation baseline includes small translation tracks which
	# differ from rest (R Forearm by about 46 micrometres). This fixture declares
	# rest segment geometry because Shoulder.compose uses the calibrated rest
	# material shaft. Preserve that exact geometry instead of accidentally using
	# animated child offsets and mislabelling a coverage miss as a ROM failure.
	# Production/current-pose handling is NOT changed by this fixture choice.
	var original_forearm_position := skeleton.get_bone_pose_position(f)
	var original_hand_position := skeleton.get_bone_pose_position(hand_index)
	skeleton.set_bone_pose_position(f, skeleton.get_bone_rest(f).origin)
	skeleton.set_bone_pose_position(hand_index, skeleton.get_bone_rest(hand_index).origin)
	skeleton.force_update_all_bone_transforms()
	var chest: Transform3D = skeleton.get_bone_global_pose(c)
	var upperarm: Transform3D = skeleton.get_bone_global_pose(u)
	var distal: Transform3D = skeleton.get_bone_global_pose(f)
	var chest_frame: Basis = chest.basis.orthonormalized() * (calibration.chest_anatomical_in_bone as Basis)
	distal.origin = upperarm.origin + chest_frame * direction.normalized() * upperarm.origin.distance_to(distal.origin)
	var composed: Dictionary = Shoulder.compose(chest, upperarm, distal, calibration, deg_to_rad(h_degrees))
	if not composed.get("valid", false): return composed
	var parent_basis: Basis = skeleton.get_bone_global_pose(skeleton.get_bone_parent(u)).basis.orthonormalized()
	skeleton.set_bone_pose_rotation(u, (parent_basis.transposed() * (composed.upperarm_basis as Basis).orthonormalized()).get_rotation_quaternion().normalized())
	skeleton.force_update_all_bone_transforms()
	var hinge: Dictionary = Hinge.calibration(skeleton.get_bone_rest(f), skeleton.get_bone_rest(hand_index))
	if not hinge.get("valid", false): return hinge
	var flexion: float = rig.capture_elbow_bend_radians(slot)
	var forearm_local: Basis = skeleton.get_bone_pose(f).basis.orthonormalized()
	forearm_local = Basis((hinge.frame_in_upperarm as Basis).x, deg_to_rad(90.0) - flexion) * forearm_local
	skeleton.set_bone_pose_rotation(f, forearm_local.get_rotation_quaternion().normalized())
	skeleton.force_update_all_bone_transforms()
	var wrist_calibration: Dictionary = rig.capture_wrist_constraint_calibration(slot)
	if not wrist_calibration.get("valid", false): return wrist_calibration
	var state := {"rho": wrist_calibration.forearm_thumb_up_rho_radians, "beta": 0.0, "gamma": 0.0}
	var wrist: Dictionary = Wrist.compose(skeleton.get_bone_global_pose(f), skeleton.get_bone_global_pose(hand_index),
		wrist_calibration, rig.wrist_motion_profile.as_dictionary(), state,
		rig.capture_elbow_bend_radians(slot), rig.authoring_elbow_full_flexion_radians())
	if not wrist.get("valid", false): return wrist
	var hand_local: Basis = skeleton.get_bone_global_pose(f).basis.orthonormalized().transposed() * (wrist.accepted_hand_basis as Basis).orthonormalized()
	skeleton.set_bone_pose_rotation(hand_index, hand_local.get_rotation_quaternion().normalized())
	skeleton.force_update_all_bone_transforms()
	rig.get("_wrist_motion_states")[slot] = state
	var measured: Dictionary = rig.capture_shoulder_motion_start_state(slot)
	if not measured.get("valid", false): return measured
	var shoulder_state: Dictionary = measured.state.duplicate()
	if is_finite(held_h): shoulder_state["held_h"] = held_h
	rig.get("_shoulder_motion_states")[slot] = shoulder_state
	measured["fixture_h_degrees"] = h_degrees
	measured["fixture_direction"] = direction
	measured["fixture_flexion_degrees"] = rad_to_deg(rig.capture_elbow_bend_radians(slot))
	measured["fixture_segment_geometry"] = "imported_rest_translations"
	measured["baseline_forearm_offset_from_rest"] = original_forearm_position - skeleton.get_bone_rest(f).origin
	measured["baseline_hand_offset_from_rest"] = original_hand_position - skeleton.get_bone_rest(hand_index).origin
	return measured

func _prop(side: String) -> Node3D:
	var prop := Node3D.new()
	root.add_child(prop)
	prop.global_transform = _hand_world(side)
	# A declared rigid numerical binding, not a claim of acquired finger contact.
	prop.set_meta("fixture_hand_in_weapon", {_slot(side): Transform3D.IDENTITY})
	return prop

func _adapter(side: String, prop: Node3D) -> CombatWeaponMotionRigAdapter:
	var adapter := MotionAdapter.new()
	var request := _request(side, prop, prop.global_transform, "tip")
	request.commit = false
	var initialized: Dictionary = adapter._initialize(rig, request)
	_check(initialized.get("valid", false), side + "_adapter_initialized", initialized)
	return adapter if initialized.get("valid", false) else null

func _shoulder_rows(evaluated: Dictionary, side: String) -> Dictionary:
	var found := {}
	if not evaluated.get("valid", false): return found
	var reasons: PackedStringArray = evaluated.constraint_reasons
	var constraints: PackedFloat64Array = evaluated.constraints
	for index: int in reasons.size():
		for name: String in ["shoulder_external", "shoulder_internal"]:
			if reasons[index] in ["JOINT_RANGE:" + name + ":" + String(_slot(side)), "SHOULDER_HOLD:" + name + ":" + String(_slot(side))]:
				found[name] = constraints[index]
	return found

func _measured_h(adapter: CombatWeaponMotionRigAdapter, evaluated: Dictionary, side: String) -> float:
	if not evaluated.get("valid", false): return NAN
	var state: Dictionary = evaluated.payload.shoulder_states_by_slot.get(_slot(side), {})
	return float(state.get("h", NAN))

func _check_table_on_imported_rig(side: String) -> void:
	var side_sign := -1.0 if side == "L" else 1.0
	for row: Array in [[0.0, -107.0, 73.0], [32.5, -103.0, 65.0], [90.0, -113.0, 41.0]]:
		var direction := Vector3(side_sign * cos(deg_to_rad(row[0])), 0.0, -sin(deg_to_rad(row[0])))
		for endpoint: float in [row[1], row[2]]:
			var fixture := _fixture(side, direction, endpoint)
			var label := side + "_plane_" + str(row[0]) + "_endpoint_" + str(endpoint)
			_check(fixture.get("valid", false) and fixture.get("covered", false) and fixture.get("legal", false)
				and absf(rad_to_deg(float(fixture.get("state", {}).get("h", NAN))) - endpoint) < 0.001,
				label, fixture)

## Returns the production allocation with unrelated q channels pinned by the
## fixture. No production budgets, anatomical limits or equations are changed.
func _isolated_solve(adapter: CombatWeaponMotionRigAdapter, target_q: PackedFloat64Array, released: PackedInt32Array) -> Dictionary:
	var input: Dictionary = adapter._allocator_input().duplicate(true)
	var pinned_lower: PackedFloat64Array = adapter.q.duplicate()
	var pinned_upper: PackedFloat64Array = adapter.q.duplicate()
	for index: int in released:
		pinned_lower[index] = adapter.lower[index]
		pinned_upper[index] = adapter.upper[index]
	input.lower = pinned_lower
	input.upper = pinned_upper
	var target: Dictionary = adapter._evaluate_kinematics(target_q)
	if not target.get("valid", false): return target
	input.target_weapon = target.weapon_frame
	var result: Dictionary = MotionAllocator.solve(input, Callable(adapter, "_evaluate"), adapter.policy)
	result["motion_adapter"] = adapter
	return result

func _compact_result(result: Dictionary) -> Dictionary:
	var compact := result.duplicate()
	compact.erase("motion_adapter")
	compact.erase("accepted_payload")
	compact.erase("accepted_pose")
	return compact

func _check_boundary_motion(side: String, endpoint: float, outward: float) -> void:
	var fixture := _fixture(side, Vector3.FORWARD, endpoint)
	var label := side + "_boundary_" + str(endpoint)
	_check(fixture.get("valid", false) and fixture.get("covered", false), label + "_fixture", fixture)
	if not fixture.get("valid", false): return
	var prop := _prop(side)
	var adapter := _adapter(side, prop)
	if adapter == null:
		prop.free()
		return
	var arm: Dictionary = adapter.arms[0]
	var index: int = arm.shoulder_q + 2
	var sign_internal: float = arm.shoulder_calibration.internal_sign
	for direction: float in [outward, -outward]:
		var target_q: PackedFloat64Array = adapter.q.duplicate()
		target_q[index] += deg_to_rad(direction) * sign_internal
		var candidate: Dictionary = adapter._evaluate_kinematics(target_q)
		var rows := _shoulder_rows(candidate, side)
		var is_outward := direction == outward
		_check(rows.size() == 2 and (maxf(float(rows.shoulder_external), float(rows.shoulder_internal)) > deg_to_rad(0.9) if is_outward else maxf(float(rows.shoulder_external), float(rows.shoulder_internal)) < 0.000001),
			label + ("_outward_candidate_violates" if is_outward else "_inward_candidate_legal"), rows)
		var result := _isolated_solve(adapter, target_q, PackedInt32Array([index]))
		var accepted: Dictionary = adapter._evaluate_kinematics(PackedFloat64Array(result.get("accepted_q", adapter.q)))
		var actual_h := _measured_h(adapter, accepted, side)
		var delta_degrees := rad_to_deg(actual_h - deg_to_rad(endpoint))
		var detail := _compact_result(result)
		detail["actual_h_degrees"] = rad_to_deg(actual_h)
		detail["delta_degrees"] = delta_degrees
		if is_outward:
			_check(is_finite(actual_h) and delta_degrees * outward <= 0.001, label + "_allocator_prevents_extra_outward_turn", detail)
		else:
			_check(result.get("valid", false) and delta_degrees * outward < -0.9, label + "_allocator_allows_inward_reversal", detail)
		samples.append({"case": label + ("_outward" if is_outward else "_inward"), "result": detail})
	prop.free()

func _check_held_reference(side: String) -> void:
	var held_h := deg_to_rad(35.0)
	var fixture := _fixture(side, Vector3(0.0, -sin(deg_to_rad(20.0)), -cos(deg_to_rad(20.0))), 35.0)
	_check(fixture.get("valid", false) and not fixture.get("covered", true), side + "_uncovered_fixture", fixture)
	if not fixture.get("valid", false): return
	# A retained hold is derived from an actual accepted measurement, not the
	# ideal requested fixture angle. Introduce only a known sub-epsilon offset
	# to prove fresh adapters preserve held_h instead of replacing it with h.
	held_h = float(fixture.state.h) - MotionAllocator.CONSTRAINT_EPSILON * 0.25
	rig.get("_shoulder_motion_states")[_slot(side)]["held_h"] = held_h
	var prop := _prop(side)
	for iteration: int in 3:
		var adapter := _adapter(side, prop)
		if adapter == null: break
		var arm: Dictionary = adapter.arms[0]
		if iteration == 0: _check_hold_allowance(side, adapter)
		var actual_held: float = arm.shoulder_state.get("held_h", NAN)
		_check(is_finite(actual_held) and absf(actual_held - held_h) < 0.00000001,
			side + "_fresh_adapter_preserves_held_h_" + str(iteration), arm.shoulder_state)
		var target_q: PackedFloat64Array = adapter.q.duplicate()
		target_q[arm.wrist_q + 2] += deg_to_rad(0.5)
		var result := _isolated_solve(adapter, target_q, PackedInt32Array([arm.wrist_q + 2]))
		var committed: bool = bool(result.get("valid", false)) and adapter.commit_result(result)
		_check(committed, side + "_uncovered_wrist_motion_commits_" + str(iteration), _compact_result(result))
		var stored: Dictionary = rig.get("_shoulder_motion_states").get(_slot(side), {})
		_check(stored.has("held_h") and absf(float(stored.held_h) - held_h) < 0.00000001,
			side + "_commit_preserves_held_h_" + str(iteration), stored)
		if not committed: break
	prop.free()

func _check_hold_allowance(side: String, adapter: CombatWeaponMotionRigAdapter) -> void:
	var input: Dictionary = adapter._allocator_input()
	var evaluated: Dictionary = adapter._evaluate_kinematics(adapter.q)
	var reasons: PackedStringArray = evaluated.constraint_reasons
	var values: PackedFloat64Array = evaluated.constraints.duplicate()
	var row := -1
	for index: int in reasons.size():
		if reasons[index] == "SHOULDER_HOLD:shoulder_internal:" + String(_slot(side)):
			row = index
	_check(row >= 0, side + "_uncovered_hold_has_distinct_reason")
	if row < 0: return
	# Use exact residuals here rather than relying on float32 skeleton rounding.
	# Within epsilon is permitted numerically; crossing it cannot gain a fresh
	# anatomical allowance on the next request and gradually ratchet held_h.
	values[row] = MotionAllocator.CONSTRAINT_EPSILON * 0.5
	evaluated.constraints = values
	var allowance: Dictionary = MotionAllocator.build_start_allowance(input, evaluated)
	var permitted: Dictionary = MotionAllocator.apply_start_allowance(evaluated, allowance)
	var valid_small: Dictionary = MotionAllocator.validate_with_start_allowance(input, evaluated, adapter.policy, allowance)
	_check(not allowance.offsets.has(reasons[row]) and permitted.constraints[row] == values[row]
		and bool(valid_small.get("valid", false)), side + "_hold_small_residual_keeps_zero_allowance", valid_small)
	values = values.duplicate()
	values[row] = MotionAllocator.CONSTRAINT_EPSILON * 2.0
	evaluated.constraints = values
	var renewed: Dictionary = MotionAllocator.build_start_allowance(input, evaluated)
	var valid_large: Dictionary = MotionAllocator.validate_with_start_allowance(input, evaluated, adapter.policy, renewed)
	_check(not renewed.offsets.has(reasons[row]) and not bool(valid_large.get("valid", false)),
		side + "_hold_large_residual_cannot_renew_allowance", valid_large)

## Both endpoint bases have the SAME fixed-reference h. A change in shaft
## direction must not manufacture axial turn solely because the allocator
## interpolates its internal coordinates between those legal endpoints.
func _check_held_swing_transition(side: String) -> void:
	var fixture := _fixture(side, Vector3(0.0, -sin(deg_to_rad(20.0)), -cos(deg_to_rad(20.0))), 35.0)
	if not fixture.get("valid", false):
		_check(false, side + "_held_swing_fixture", fixture)
		return
	var prop := _prop(side)
	var adapter := _adapter(side, prop)
	if adapter == null:
		prop.free()
		return
	var arm: Dictionary = adapter.arms[0]
	var chest := skeleton.get_bone_global_pose(arm.chest_index)
	var upperarm := skeleton.get_bone_global_pose(arm.indices[1])
	var distal := skeleton.get_bone_global_pose(arm.indices[2])
	var original_basis := upperarm.basis
	var start_h: float = arm.shoulder_state.h
	var chest_frame: Basis = chest.basis.orthonormalized() * (arm.shoulder_calibration.chest_anatomical_in_bone as Basis)
	var target_direction: Vector3 = (fixture.direction_anatomical + Vector3(0.15 * float(arm.shoulder_calibration.side_sign), -0.08, 0.03)).normalized()
	distal.origin = upperarm.origin + chest_frame * target_direction * upperarm.origin.distance_to(distal.origin)
	var endpoint: Dictionary = Shoulder.compose(chest, upperarm, distal, arm.shoulder_calibration, start_h)
	_check(endpoint.get("valid", false), side + "_held_swing_destination", endpoint)
	if not endpoint.get("valid", false):
		prop.free()
		return
	var target_q := _q_for_shoulder_basis(adapter, endpoint.upperarm_basis, start_h)
	var max_error := 0.0
	var all_legal := true
	for weight: float in [0.0, 0.25, 0.5, 0.75, 1.0]:
		var sample_q: PackedFloat64Array = adapter.q.duplicate()
		for index: int in sample_q.size():
			sample_q[index] = lerpf(sample_q[index], target_q[index], weight)
		var evaluated: Dictionary = adapter._evaluate_kinematics(sample_q)
		var rows := _shoulder_rows(evaluated, side)
		var actual_h := _measured_h(adapter, evaluated, side)
		max_error = maxf(max_error, absf(actual_h - start_h))
		all_legal = all_legal and rows.size() == 2 and maxf(float(rows.get("shoulder_internal", INF)), float(rows.get("shoulder_external", INF))) <= MotionAllocator.CONSTRAINT_EPSILON
		if weight in [0.0, 1.0]:
			_check(is_finite(actual_h) and absf(actual_h - start_h) <= MotionAllocator.CONSTRAINT_EPSILON,
				side + "_held_swing_endpoint_same_h_" + str(weight), {"h": actual_h, "expected_h": start_h})
	_check(all_legal and max_error <= MotionAllocator.CONSTRAINT_EPSILON,
		side + "_held_swing_intermediate_h_remains_fixed", {"maximum_h_error_radians": max_error})
	var released := PackedInt32Array([arm.shoulder_q, arm.shoulder_q + 1, arm.shoulder_q + 2])
	var result := _isolated_solve(adapter, target_q, released)
	var committed: bool = bool(result.get("valid", false)) and float(result.get("task_scale", 0.0)) > 0.99 and adapter.commit_result(result)
	_check(committed, side + "_held_swing_full_request_commits", _compact_result(result))
	if committed:
		var reverse := _adapter(side, prop)
		if reverse != null:
			var return_q := _q_for_shoulder_basis(reverse, original_basis, start_h)
			var reversed := _isolated_solve(reverse, return_q, released)
			_check(bool(reversed.get("valid", false)) and float(reversed.get("task_scale", 0.0)) > 0.99 and reverse.commit_result(reversed),
				side + "_held_swing_reversal_commits", _compact_result(reversed))
	prop.free()

## Encode a declared physical endpoint in the adapter's current internal
## coordinates. Endpoint construction above is independent of this encoding.
func _q_for_shoulder_basis(adapter: CombatWeaponMotionRigAdapter, desired_global: Basis, _desired_h: float) -> PackedFloat64Array:
	var arm: Dictionary = adapter.arms[0]
	var parent_basis := skeleton.get_bone_global_pose(skeleton.get_bone_parent(arm.indices[1])).basis.orthonormalized()
	var desired_local: Basis = parent_basis.transposed() * desired_global.orthonormalized()
	var rotation: Quaternion = (desired_local * adapter.local_poses[arm.indices[1]].basis.orthonormalized().transposed()).get_rotation_quaternion().normalized()
	var vector := rotation.get_axis() * rotation.get_angle()
	var result: PackedFloat64Array = adapter.q.duplicate()
	result[arm.shoulder_q] = vector.dot((arm.shoulder_axes as Basis).x)
	result[arm.shoulder_q + 1] = vector.dot((arm.shoulder_axes as Basis).z)
	result[arm.shoulder_q + 2] = vector.dot((arm.shoulder_axes as Basis).y)
	return result

## Bounded diagnostic of LATER Newton transitions: both ends have nonzero q
## relative to the same accepted pose. Linear rotation-vector interpolation is
## no longer the first-step SLERP. This records any disagreement with the h hold
## without claiming that the complete poses are otherwise feasible or that a
## live input actually takes one of these chords.
func _record_held_swing_chords(side: String) -> void:
	var fixture := _fixture(side, Vector3(0.0, -sin(deg_to_rad(20.0)), -cos(deg_to_rad(20.0))), 35.0)
	if not fixture.get("valid", false): return
	var prop := _prop(side)
	var adapter := _adapter(side, prop)
	if adapter == null:
		prop.free()
		return
	var arm: Dictionary = adapter.arms[0]
	var chest := skeleton.get_bone_global_pose(arm.chest_index)
	var upperarm := skeleton.get_bone_global_pose(arm.indices[1])
	var distal := skeleton.get_bone_global_pose(arm.indices[2])
	var segment_length := upperarm.origin.distance_to(distal.origin)
	var chest_frame: Basis = chest.basis.orthonormalized() * (arm.shoulder_calibration.chest_anatomical_in_bone as Basis)
	var h: float = arm.shoulder_state.h
	var side_sign: float = arm.shoulder_calibration.side_sign
	var directions: Array[Vector3] = [Vector3(0.60, -0.55, -0.58), Vector3(-0.45, -0.60, -0.66),
		Vector3(0.70, 0.20, -0.68), Vector3(0.15, -0.95, -0.20), Vector3(0.80, -0.10, 0.59)]
	var endpoints: Array[PackedFloat64Array] = []
	for direction: Vector3 in directions:
		direction.x *= side_sign
		distal.origin = upperarm.origin + chest_frame * direction.normalized() * segment_length
		var composed: Dictionary = Shoulder.compose(chest, upperarm, distal, arm.shoulder_calibration, h)
		if not composed.get("valid", false): continue
		endpoints.append(_q_for_shoulder_basis(adapter, composed.upperarm_basis, h))
	var records: Array[Dictionary] = []
	for first: int in endpoints.size():
		for second: int in range(first + 1, endpoints.size()):
			var maximum_error := 0.0
			var endpoint_error := 0.0
			for weight: float in [0.0, 0.25, 0.5, 0.75, 1.0]:
				var sample_q: PackedFloat64Array = endpoints[first].duplicate()
				for index: int in sample_q.size(): sample_q[index] = lerpf(sample_q[index], endpoints[second][index], weight)
				var evaluated: Dictionary = adapter._evaluate_kinematics(sample_q)
				var error := absf(_measured_h(adapter, evaluated, side) - h)
				maximum_error = maxf(maximum_error, error)
				if weight in [0.0, 1.0]: endpoint_error = maxf(endpoint_error, error)
			records.append({"from_index": first, "to_index": second, "maximum_h_error_radians": maximum_error,
				"endpoint_h_error_radians": endpoint_error, "constraint_epsilon": MotionAllocator.CONSTRAINT_EPSILON})
	samples.append({"case": side + "_nonzero_q_held_h_chord_diagnostic", "chords": records})
	prop.free()

func _check_root_transform(side: String) -> void:
	var fixture := _fixture(side, Vector3.FORWARD, 25.0)
	if not fixture.get("valid", false):
		_check(false, side + "_root_fixture", fixture)
		return
	var prop := _prop(side)
	var before := _adapter(side, prop)
	if before == null:
		prop.free()
		return
	var prior: Dictionary = before._evaluate_kinematics(before.q)
	var transforms: Array[Transform3D] = [
		Transform3D(Basis.IDENTITY, Vector3(2.0, 1.0, -3.0)),
		Transform3D(Basis.from_euler(Vector3(0.2, -0.6, 0.1)), Vector3.ZERO),
		Transform3D(Basis.from_euler(Vector3(0.2, -0.6, 0.1)).scaled(Vector3.ONE * 1.25), Vector3(2.0, 1.0, -3.0))]
	for index: int in transforms.size():
		actor_parent.transform = transforms[index]
		prop.global_transform = _hand_world(side)
		var after := _adapter(side, prop)
		if after == null: continue
		var current: Dictionary = after._evaluate_kinematics(after.q)
		var actual_h := _measured_h(after, current, side)
		var before_h := _measured_h(before, prior, side)
		var old_rows := _shoulder_rows(prior, side)
		var new_rows := _shoulder_rows(current, side)
		var rows_match := old_rows.size() == 2 and new_rows.size() == 2
		for key: String in old_rows:
			rows_match = rows_match and absf(float(old_rows[key]) - float(new_rows.get(key, INF))) < 0.00001
		_check(is_finite(actual_h) and absf(actual_h - before_h) < 0.00001 and rows_match,
			side + "_root_transform_preserves_h_and_limits_" + str(index), {"h_degrees": rad_to_deg(actual_h), "constraints": new_rows})
	prop.free()

func _record_coverage_reentry(side: String) -> void:
	var held_h := deg_to_rad(100.0)
	var fixture := _fixture(side, Vector3(0.0, -sin(deg_to_rad(20.0)), -cos(deg_to_rad(20.0))), 100.0, held_h)
	if not fixture.get("valid", false):
		_check(false, side + "_reentry_fixture", fixture)
		return
	var prop := _prop(side)
	var adapter := _adapter(side, prop)
	if adapter == null:
		prop.free()
		return
	var arm: Dictionary = adapter.arms[0]
	var i: Array = arm.indices
	var chest := skeleton.get_bone_global_pose(arm.chest_index)
	var upperarm := skeleton.get_bone_global_pose(i[1])
	var distal := skeleton.get_bone_global_pose(i[2])
	var chest_frame: Basis = chest.basis.orthonormalized() * (arm.shoulder_calibration.chest_anatomical_in_bone as Basis)
	distal.origin = upperarm.origin + chest_frame * Vector3.FORWARD * upperarm.origin.distance_to(distal.origin)
	var composed: Dictionary = Shoulder.compose(chest, upperarm, distal, arm.shoulder_calibration, held_h)
	_check(composed.get("valid", false), side + "_reentry_destination_constructed", composed)
	if not composed.get("valid", false):
		prop.free()
		return
	var parent_basis := skeleton.get_bone_global_pose(skeleton.get_bone_parent(i[1])).basis.orthonormalized()
	var desired_local: Basis = parent_basis.transposed() * (composed.upperarm_basis as Basis).orthonormalized()
	var rotation: Quaternion = (desired_local * adapter.local_poses[i[1]].basis.orthonormalized().transposed()).get_rotation_quaternion().normalized()
	var vector := rotation.get_axis() * rotation.get_angle()
	var q_target: PackedFloat64Array = adapter.q.duplicate()
	q_target[arm.shoulder_q] = vector.dot((arm.shoulder_axes as Basis).x)
	q_target[arm.shoulder_q + 1] = vector.dot((arm.shoulder_axes as Basis).z)
	q_target[arm.shoulder_q + 2] = vector.dot((arm.shoulder_axes as Basis).y)
	var evaluated: Dictionary = adapter._evaluate_kinematics(q_target)
	var rows := _shoulder_rows(evaluated, side)
	var actual_h := _measured_h(adapter, evaluated, side)
	var record := {"side": side, "source_covered": fixture.covered,
		"source_held_h_degrees": rad_to_deg(held_h), "destination_h_degrees": rad_to_deg(actual_h),
		"destination_constraints": rows,
		"finding": "Known coverage re-entry risk: h=100 degrees is held outside the measured band but exceeds the forward-band internal limit of 41 degrees. A separate bounded solve below requests a legal forward h40 endpoint; its status is diagnostic, not a claimed successful editor return path."}
	# Also try a genuinely legal endpoint, not merely the impossible unchanged-h
	# endpoint above. Retain production search budgets and measured coverage.
	var legal_destination: Dictionary = Shoulder.compose(chest, upperarm, distal, arm.shoulder_calibration, deg_to_rad(40.0))
	if legal_destination.get("valid", false):
		desired_local = parent_basis.transposed() * (legal_destination.upperarm_basis as Basis).orthonormalized()
		rotation = (desired_local * adapter.local_poses[i[1]].basis.orthonormalized().transposed()).get_rotation_quaternion().normalized()
		vector = rotation.get_axis() * rotation.get_angle()
		q_target[arm.shoulder_q] = vector.dot((arm.shoulder_axes as Basis).x)
		q_target[arm.shoulder_q + 1] = vector.dot((arm.shoulder_axes as Basis).z)
		q_target[arm.shoulder_q + 2] = vector.dot((arm.shoulder_axes as Basis).y)
		var target_evaluation: Dictionary = adapter._evaluate_kinematics(q_target)
		var legal_rows := _shoulder_rows(target_evaluation, side)
		_check(legal_rows.size() == 2 and maxf(float(legal_rows.get("shoulder_internal", INF)), float(legal_rows.get("shoulder_external", INF))) <= 0.000001,
			side + "_reentry_legal_destination", legal_rows)
		var result := _isolated_solve(adapter, q_target, PackedInt32Array([arm.shoulder_q, arm.shoulder_q + 1, arm.shoulder_q + 2]))
		var accepted: Dictionary = adapter._evaluate_kinematics(PackedFloat64Array(result.get("accepted_q", adapter.q)))
		record["legal_endpoint_attempt"] = _compact_result(result)
		record["accepted_h_degrees"] = rad_to_deg(_measured_h(adapter, accepted, side))
		record["initial_allowance"] = adapter.start_allowance
	coverage_diagnostics.append(record)
	_check(rows.size() == 2 and float(rows.get("shoulder_internal", 0.0)) > deg_to_rad(58.0),
		side + "_reentry_exposes_out_of_band_held_h", record)
	prop.free()

func _finish() -> void:
	var passed := true
	for check: Dictionary in checks: passed = passed and bool(check.passed)
	DirAccess.make_dir_recursive_absolute(output_dir)
	var path := output_dir.path_join("shoulder_report.json")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		quit(1)
		return
	file.store_string(JSON.stringify({"passed": passed, "checks": checks, "samples": samples,
		"coverage_reentry_diagnostics": coverage_diagnostics,
		"scope": "Imported R/L rig, declared chest-relative shoulder directions, isolated axial boundary solves, repeated fresh adapters/commits outside measured coverage, and world-root transform invariance. No saved skill, acquisition, visual or full editor lifecycle certification."}, "\t"))
	file.close()
	print("SHOULDER_MOTION_ALLOCATION passed=%s checks=%d output=%s" % [passed, checks.size(), path])
	quit(0 if passed else 1)
