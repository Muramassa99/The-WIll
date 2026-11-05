extends RefCounted
class_name CombatWeaponMotionRigAdapter

## Scene adapter for the weapon-task allocator. Every candidate is evaluated in
## Skeleton3D coordinates, whose parent chain includes RL_BoneRoot. The weapon
## task itself is world-space; local grip transforms are Hand -> WeaponRoot.
## No finger search, bone translation, rest rewrite or world-axis elbow pole.
const Allocator = preload("res://core/resolvers/combat_weapon_motion_allocator.gd")
const Policy = preload("res://core/defs/weapon_motion_policy_def.gd")
const Wrist = preload("res://core/resolvers/combat_wrist_motion_resolver.gd")
const Shoulder = preload("res://core/resolvers/combat_shoulder_motion_resolver.gd")
const Hinge = preload("res://core/resolvers/combat_arm_hinge_frame_resolver.gd")
const ForearmSkin = preload("res://core/resolvers/combat_forearm_hand_index_resolver.gd")
const UpperBody = preload("res://runtime/player/player_rig_upper_body_pose_presenter.gd")
const Origin = preload("res://core/models/combat_origin_record.gd")
const SLOT_RIGHT := &"hand_right"
const SLOT_LEFT := &"hand_left"
const EPSILON := 1.0e-8

var rig: Node3D
var skeleton: Skeleton3D
var request: Dictionary
var local_poses: Array[Transform3D] = []
var parents := PackedInt32Array()
var names: Array[StringName] = []
var arms: Array[Dictionary] = []
var torso: Array[Dictionary] = []
var q := PackedFloat64Array()
var lower := PackedFloat64Array()
var upper := PackedFloat64Array()
var groups: Array[StringName] = []
var skeleton_world := Transform3D.IDENTITY
var policy: Dictionary = {}
var collision_validator: Callable
var previous_weapon := Transform3D.IDENTITY
var weapon: Node3D
var timings: Dictionary = {"evaluate_count": 0, "evaluate_us": 0, "validate_candidate_count": 0, "validate_candidate_us": 0, "storage_validation_count": 0, "storage_validation_us": 0, "commit_us": 0}
var allocation_start_usec: int = 0
var start_allowance: Dictionary = {}
var storage_validation_failures: Dictionary = {}
var storage_validation_last_failure: Dictionary = {}

func allocate(owner: Node3D, motion_request: Dictionary) -> Dictionary:
	allocation_start_usec = Time.get_ticks_usec()
	var initialized := _initialize(owner, motion_request)
	if not initialized.get("valid", false):
		return initialized
	var result: Dictionary = Allocator.solve(_allocator_input(), Callable(self, "_evaluate"), policy)
	if not result.get("accepted_payload") is Dictionary:
		return result
	var payload: Dictionary = result.accepted_payload
	if not payload.has("local_poses") or not result.get("accepted_weapon") is Transform3D:
		return result
	result["motion_adapter"] = self
	if bool(request.get("commit", true)) and String(result.get("status", "")) in ["ACCEPTED", "SCALED"]:
		if not commit_result(result):
			return result
	result["accepted_pose"] = _pose_packet(payload.local_poses)
	result["accepted_weapon_origin_id"] = &"world"
	result["wrist_states_by_slot"] = payload.get("wrist_states_by_slot", {}).duplicate(true)
	result["shoulder_states_by_slot"] = payload.get("shoulder_states_by_slot", {}).duplicate(true)
	result["origin_id"] = Origin.ORIGIN_RL_BONE_ROOT
	result["coordinate_contract"] = "world_weapon; parent_bone_local_pose; ancestry_to_RL_BoneRoot"
	result["timings"] = _timing_result()
	result["storage_validation_failures"] = storage_validation_failures.duplicate()
	result["storage_validation_last_failure"] = storage_validation_last_failure.duplicate(true)
	return result

## Capture the same contract for a solve or a read-only post-storage check.
## This does not allocate motion, install poses, or run collision queries.
func _initialize(owner: Node3D, motion_request: Dictionary) -> Dictionary:
	rig = owner
	skeleton = rig.get("skeleton") as Skeleton3D
	request = motion_request
	weapon = request.get("weapon") as Node3D
	if not is_instance_valid(skeleton) or not is_instance_valid(weapon):
		return _failure("missing_weapon_motion_rig", "INVALID_PROFILE")
	if not request.get("previous_weapon") is Transform3D or not request.get("target_weapon") is Transform3D or not request.get("contact_local") is Vector3:
		return _failure("missing_weapon_motion_frames", "INVALID_PROFILE")
	previous_weapon = request.previous_weapon
	var target: Transform3D = request.target_weapon
	if not previous_weapon.is_finite() or not target.is_finite():
		return _failure("nonfinite_weapon_motion_frame", "INVALID_PROFILE")
	if String(request.get("mode", "tip")) == "roll" and request.has("contact_anchor_world") and (not request.contact_anchor_world is Vector3 or not request.contact_anchor_world.is_finite()):
		return _failure("weapon_motion_invalid_contact_anchor", "INVALID_PROFILE")
	var primary := StringName(request.get("primary_slot", SLOT_RIGHT))
	var support := StringName(request.get("support_slot", StringName()))
	if primary not in [SLOT_RIGHT, SLOT_LEFT] or support == primary:
		return _failure("invalid_weapon_motion_slots", "INVALID_PROFILE")
	skeleton.force_update_all_bone_transforms()
	skeleton_world = skeleton.global_transform
	if not skeleton_world.is_finite() or skeleton_world.basis.determinant() <= 0.0:
		return _failure("invalid_weapon_motion_origin", "INVALID_PROFILE")
	_capture_skeleton()
	# Motion distances are world metres. This character's configured standing
	# height is normalized to the existing 2 m reference, not imported mesh units.
	policy = Policy.new().as_dictionary(float(rig.get("standing_height_meters")) / 2.0)
	if request.get("policy") is Dictionary:
		policy.merge(request.policy, true)
	collision_validator = request.get("validate_pose", Callable())
	# Independent one-hand edits stop at that arm's clavicle. Moving shared
	# ancestors would carry the untouched opposite arm through world space even
	# though its own local pose channels did not change. Two-hand Pommel/Roll
	# retain shared torso recruitment; Tip retains its existing clavicle boundary.
	# The reversible editor experiment also removes shared torso parameters
	# from two-hand requests. Keep their current transforms as the FK base.
	if support != StringName() and String(request.get("mode", "tip")) != "tip" and not bool(rig.call("is_authoring_arm_spine_isolation_enabled")):
		_build_torso(true)
	for slot: StringName in [primary, support]:
		if slot == StringName():
			continue
		var built: Dictionary = _build_arm(slot)
		if not built.get("valid", false):
			return built
		arms.append(built)
	# The current pose is the user's correction baseline, not an input lock.
	# Retain this original allowance for every temporary write and final readback;
	# a fresh adapter must not grant a candidate its own larger allowance.
	start_allowance = Allocator.build_start_allowance(_allocator_input(), _evaluate_kinematics(q))
	return {"valid": true}

func _allocator_input() -> Dictionary:
	var input: Dictionary = {
		"mode": String(request.get("mode", "tip")), "q": q, "lower": lower, "upper": upper,
		"joint_groups": groups, "previous_weapon": previous_weapon, "target_weapon": request.target_weapon,
		"contact_local": request.contact_local, "origin_id": &"world",
		"machine_origin_id": Origin.ORIGIN_RL_BONE_ROOT,
		"machine_to_world": skeleton_world * skeleton.get_bone_global_pose(skeleton.find_bone(String(Origin.ORIGIN_RL_BONE_ROOT))),
		"validate_candidate": Callable(self, "_validate_candidate"),
	}
	# A Tip edit may carry the hand/grip through space. Its attachment is checked
	# separately; only attached Roll owns a retained spatial pivot.
	if String(request.get("mode", "tip")) == "roll" and request.has("contact_anchor_world"):
		input["contact_anchor"] = request.contact_anchor_world
	return input

## Complete the already evaluated packet after the UI encodes its exact frame.
## There is no yield between allocation/encoding/commit and no second solve.
func commit_result(result: Dictionary) -> bool:
	if not is_instance_valid(rig) or not is_instance_valid(skeleton) or not is_instance_valid(weapon):
		return false
	if result.get("motion_adapter") != self or not result.get("accepted_payload") is Dictionary or not result.get("accepted_weapon") is Transform3D:
		return false
	if String(result.get("status", "")) not in ["ACCEPTED", "SCALED"]:
		return false
	var before := _capture_commit_state()
	_commit(result.accepted_payload, result.accepted_weapon)
	var readback := _validate_committed_pose(result.accepted_weapon)
	if not readback.get("valid", false):
		_restore_commit_state(before)
		result["valid"] = false
		result["status"] = "SEARCH_EXHAUSTED"
		result["reason"] = "weapon_motion_commit_readback_rejected"
		result["commit_diagnostics"] = readback
		result["accepted_weapon"] = before.weapon_world
		result["accepted_q"] = q.duplicate()
		result["accepted_payload"] = {}
		result["accepted_pose"] = {}
		result["task_scale"] = 0.0
		result["timings"] = _timing_result()
		return false
	result["accepted_pose"] = _pose_packet(result.accepted_payload.local_poses)
	result["commit_readback_valid"] = true
	result["timings"] = _timing_result()
	return true

func _capture_commit_state() -> Dictionary:
	var rotations: Array[Quaternion] = []
	for index: int in skeleton.get_bone_count():
		rotations.append(skeleton.get_bone_pose_rotation(index))
	return {"rotations": rotations, "weapon_world": weapon.global_transform,
		"wrist_states": (rig.get("_wrist_motion_states") as Dictionary).duplicate(true),
		"shoulder_states": (rig.get("_shoulder_motion_states") as Dictionary).duplicate(true),
		"wrist_failures": (rig.get("_wrist_motion_failures") as Dictionary).duplicate(true)}

func _restore_commit_state(before: Dictionary) -> void:
	# Restore the original Quaternion values directly. A second Basis conversion
	# could round the previously accepted boundary pose in a different direction.
	for index: int in skeleton.get_bone_count():
		skeleton.set_bone_pose_rotation(index, before.rotations[index])
	rig.set("_wrist_motion_states", before.wrist_states)
	rig.set("_shoulder_motion_states", before.get("shoulder_states", {}).duplicate(true))
	rig.set("_wrist_motion_failures", before.wrist_failures)
	skeleton.force_update_all_bone_transforms()
	_refresh_hand_attachments()
	weapon.global_transform = before.weapon_world
	rig.call("sync_runtime_body_restriction_root_now")

func _validate_committed_pose(accepted_weapon: Transform3D, enforce_task_anchor: bool = true) -> Dictionary:
	var fixed_bindings: Dictionary = {}
	for arm: Dictionary in arms:
		var hand_in_weapon: Transform3D = arm.hand_in_weapon
		fixed_bindings[arm.slot] = hand_in_weapon
		var actual: Transform3D = skeleton.global_transform * skeleton.get_bone_global_pose(arm.indices[3])
		var expected: Transform3D = accepted_weapon * hand_in_weapon
		var position_error: float = actual.origin.distance_to(expected.origin)
		# Match the wrist resolver's established scalar shortest-angle check.
		# The optimizer's world axis-angle vector has an extra float32 roundtrip
		# and is directional data, not the final physical angular-cap metric.
		var relative: Quaternion = (actual.basis.orthonormalized().get_rotation_quaternion().inverse() * expected.basis.orthonormalized().get_rotation_quaternion()).normalized()
		var angle_error: float = 2.0 * atan2(Vector3(relative.x, relative.y, relative.z).length(), absf(relative.w))
		if position_error > float(policy.position_tolerance) or angle_error > float(policy.orientation_tolerance):
			return {"valid": false, "reason": "stored_grip_outside_physical_tolerance", "slot": arm.slot,
				"position_error_m": position_error, "angle_error_radians": angle_error,
				"position_tolerance_m": policy.position_tolerance, "angle_tolerance_radians": policy.orientation_tolerance}
	# Use fixed acquired relationships even when a standalone fixture originally
	# captured them from the scene, so readback cannot redefine a drifting grip.
	var next_request := request.duplicate()
	next_request["previous_weapon"] = weapon.global_transform
	next_request["target_weapon"] = weapon.global_transform
	next_request["hand_in_weapon_by_slot"] = fixed_bindings
	next_request["commit"] = false
	if not enforce_task_anchor:
		# Internal Newton/transition samples must be legal and storable, but can
		# still carry task error. Only the finished task uses the retained pivot.
		next_request.erase("contact_anchor_world")
	var readback := CombatWeaponMotionRigAdapter.new()
	var initialized := readback._initialize(rig, next_request)
	if not initialized.get("valid", false):
		return initialized
	return Allocator.validate_with_start_allowance(readback._allocator_input(), readback._evaluate_kinematics(readback.q), readback.policy, start_allowance)

func _refresh_hand_attachments() -> void:
	for arm: Dictionary in arms:
		var anchor: Node3D = rig.call("get_left_hand_item_anchor" if arm.slot == SLOT_LEFT else "get_right_hand_item_anchor")
		if is_instance_valid(anchor) and anchor.get_parent() is BoneAttachment3D:
			(anchor.get_parent() as BoneAttachment3D).on_skeleton_update()

func _capture_skeleton() -> void:
	for index: int in skeleton.get_bone_count():
		parents.append(skeleton.get_bone_parent(index))
		names.append(StringName(skeleton.get_bone_name(index)))
		local_poses.append(skeleton.get_bone_pose(index))

func _build_torso(two_hand: bool) -> void:
	if not bool(rig.get("enable_upper_body_authoring_pose")) or not bool(request.get("allow_torso", true)):
		return
	# These are the two direction channels already exposed by the existing
	# upper-body presenter, with its own per-bone distribution and limits.
	# The reference is the accepted pose, not an idle-pose recentering target.
	var yaw_limit: float = deg_to_rad(UpperBody.TORSO_MAX_TWO_HAND_YAW_DEGREES if two_hand else UpperBody.TORSO_MAX_ONE_HAND_YAW_DEGREES)
	var pitch_limit: float = deg_to_rad(UpperBody.TORSO_MAX_TWO_HAND_PITCH_DEGREES if two_hand else UpperBody.TORSO_MAX_ONE_HAND_PITCH_DEGREES)
	var start: int = q.size()
	_append_parameter(0.0, -yaw_limit, yaw_limit, &"torso")
	_append_parameter(0.0, -pitch_limit, pitch_limit, &"torso")
	var presenter: RefCounted = rig.get("upper_body_pose_presenter")
	presenter.call("warm_cache")
	var authored_blend: float = float((rig.get("upper_body_authoring_state") as Dictionary).get("blend", 0.0))
	var blend: float = (UpperBody.TWO_HAND_BASE_SUPPORT_BLEND + authored_blend * (1.0 - UpperBody.TWO_HAND_BASE_SUPPORT_BLEND)) if two_hand else 0.0
	for bone_name: StringName in UpperBody.TORSO_BONES:
		var index: int = names.find(bone_name)
		if index < 0 or parents[index] < 0:
			continue
		var parent_world: Basis = (skeleton_world * skeleton.get_bone_global_pose(parents[index])).basis.orthonormalized()
		var weight: Vector2 = UpperBody.DIRECTION_WEIGHTS[bone_name]
		var neutral: Quaternion = presenter.call("_resolve_reference_pose_rotation", bone_name, blend,
			skeleton.get_bone_pose_rotation(index), Origin.ORIGIN_SOLVED_REPLAY_REFERENCE)
		torso.append({"index": index, "q": start, "yaw_axis": parent_world.transposed() * rig.global_basis.y.normalized(),
			"pitch_axis": parent_world.transposed() * rig.global_basis.x.normalized(), "weight": weight,
			"neutral": Basis(neutral), "yaw_limit": yaw_limit * weight.x, "pitch_limit": pitch_limit * weight.y})

func _build_arm(slot: StringName) -> Dictionary:
	var prefix := "CC_Base_L_" if slot == SLOT_LEFT else "CC_Base_R_"
	var indices: Array[int] = []
	for suffix: String in ["Clavicle", "Upperarm", "Forearm", "Hand", "ForearmTwist01", "ForearmTwist02"]:
		var index: int = names.find(StringName(prefix + suffix))
		if index < 0:
			return _failure("weapon_motion_missing_bone_" + prefix + suffix, "INVALID_PROFILE")
		indices.append(index)
	for i: int in range(1, 4):
		if parents[indices[i]] != indices[i - 1]:
			return _failure("weapon_motion_nonserial_arm", "INVALID_PROFILE")
	var root_index: int = names.find(Origin.ORIGIN_RL_BONE_ROOT)
	var ancestor: int = indices[0]
	while ancestor >= 0 and ancestor != root_index:
		ancestor = parents[ancestor]
	if root_index < 0 or ancestor != root_index:
		return _failure("weapon_motion_arm_without_machine_origin", "INVALID_PROFILE")
	var calibrated: Dictionary = Hinge.calibration(skeleton.get_bone_rest(indices[2]), skeleton.get_bone_rest(indices[3]))
	var wrist_calibration: Dictionary = rig.call("capture_wrist_constraint_calibration", slot)
	var wrist_profile: Dictionary = rig.get("wrist_motion_profile").call("as_dictionary")
	var shoulder_calibration: Dictionary = rig.call("capture_shoulder_constraint_calibration", slot)
	var shoulder_profile: Dictionary = rig.get("shoulder_motion_profile").call("as_dictionary")
	var shoulder_measurement: Dictionary = rig.call("capture_shoulder_motion_start_state", slot)
	if not shoulder_calibration.get("valid", false) or not shoulder_measurement.get("valid", false):
		return _failure("weapon_motion_invalid_shoulder_calibration", "INVALID_PROFILE")
	if not calibrated.get("valid", false) or not wrist_calibration.get("valid", false):
		return _failure("weapon_motion_invalid_anatomical_calibration", "INVALID_PROFILE")
	var u: Transform3D = skeleton.get_bone_global_pose(indices[1])
	var f: Transform3D = skeleton.get_bone_global_pose(indices[2])
	var h: Transform3D = skeleton.get_bone_global_pose(indices[3])
	var wrist_measurement: Dictionary = rig.call("capture_wrist_motion_start_state", slot)
	if not wrist_measurement.get("valid", false):
		return _failure(String(wrist_measurement.get("reason", "weapon_motion_wrist_measurement_failed")), "INVALID_PROFILE")
	var wrist_state: Dictionary = wrist_measurement.state
	var shaft: Vector3 = (f.origin - u.origin).normalized()
	var distal: Vector3 = (h.origin - f.origin).normalized()
	var hinge_axis: Vector3 = u.basis.orthonormalized() * (calibrated.frame_in_upperarm as Basis).x
	var flexion: float = atan2(hinge_axis.dot(shaft.cross(distal)), shaft.dot(distal))
	# A negative signed hinge angle describes an already inverted elbow. Keep
	# that measured state so the existing allowance can let the user correct it.
	var c: int = q.size()
	# No separately calibrated clavicle local envelope exists yet. The new
	# profile explicitly holds its accepted pose for this control in that case;
	# it must not provide a fresh extra allotment of shoulder turn per request.
	for _coordinate: int in 3:
		_append_parameter(0.0, 0.0, 0.0, &"shoulder_girdle")
	var s: int = q.size()
	# The imported material frame supplies the real humeral shaft (Y), hinge
	# normal (X) and perpendicular swing direction (Z). Express these axes in
	# Clavicle-parent space so Roll can prefer axial contribution separately
	# from the two existing shoulder swing freedoms, without adding any DOF.
	var material: Basis = calibrated.frame_in_upperarm
	var shoulder_axes: Basis = local_poses[indices[1]].basis.orthonormalized() * material
	_append_parameter(0.0, -PI, PI, &"shoulder_swing")
	_append_parameter(0.0, -PI, PI, &"shoulder_swing")
	_append_parameter(0.0, -PI, PI, &"shoulder_roll")
	var e: int = q.size()
	_append_parameter(flexion, PI - deg_to_rad(float(rig.get("authoring_elbow_max_plane_angle_degrees"))), PI - deg_to_rad(float(rig.get("authoring_elbow_min_plane_angle_degrees"))), &"elbow")
	var w: int = q.size()
	var forearm_range: Dictionary = Wrist.forearm_interval(wrist_calibration, wrist_profile)
	if not forearm_range.get("valid", false):
		return _failure("weapon_motion_invalid_forearm_interval", "INVALID_PROFILE")
	_append_parameter(float(wrist_state.rho), float(forearm_range.rho_min), float(forearm_range.rho_max), &"forearm")
	_append_parameter(float(wrist_state.beta), -float(wrist_profile.flexion_limit_radians), float(wrist_profile.extension_limit_radians), &"wrist")
	_append_parameter(float(wrist_state.gamma), -float(wrist_profile.ulnar_limit_radians), float(wrist_profile.radial_limit_radians), &"wrist")
	var hand_world: Transform3D = skeleton_world * h
	var hand_in_weapon: Transform3D = previous_weapon.affine_inverse() * hand_world
	var acquired_bindings: Variant = request.get("hand_in_weapon_by_slot", {})
	if not acquired_bindings is Dictionary:
		return _failure("weapon_motion_invalid_acquired_bindings", "INVALID_PROFILE")
	if not acquired_bindings.is_empty():
		# Production callers supply the acquired WeaponRoot -> Hand binding.
		# Never redefine contact from each accepted-but-tolerant frame: that
		# would turn the numerical allowance into cumulative attachment drift.
		var acquired_hand: Variant = acquired_bindings.get(slot)
		if not acquired_hand is Transform3D or not acquired_hand.is_finite() or acquired_hand.basis.determinant() <= 0.0:
			return _failure("weapon_motion_missing_acquired_binding_" + String(slot), "INVALID_PROFILE")
		hand_in_weapon = acquired_hand
	return {"valid": true, "slot": slot, "indices": indices, "clavicle_q": c, "shoulder_q": s, "elbow_q": e, "wrist_q": w,
		"shoulder_axes": shoulder_axes,
		"initial_flexion": flexion, "hinge_local": (calibrated.frame_in_upperarm as Basis).x,
		"wrist_calibration": wrist_calibration, "wrist_profile": wrist_profile,
		"full_flexion": rig.call("authoring_elbow_full_flexion_radians"),
		"shoulder_calibration": shoulder_calibration, "shoulder_profile": shoulder_profile,
		"shoulder_state": shoulder_measurement.state,
		"chest_index": skeleton.find_bone(String(shoulder_calibration.chest_bone_name)),
		"hand_in_weapon": hand_in_weapon, "hand_to_weapon": hand_in_weapon.affine_inverse(),
		"helper_rests": [skeleton.get_bone_rest(indices[4]).basis, skeleton.get_bone_rest(indices[5]).basis, skeleton.get_bone_rest(indices[3]).basis]}

func _append_parameter(value: float, minimum: float, maximum: float, group: StringName) -> void:
	q.append(value)
	lower.append(minimum)
	upper.append(maximum)
	groups.append(group)

func _evaluate(values: PackedFloat64Array) -> Dictionary:
	var started: int = Time.get_ticks_usec()
	var result: Dictionary = _evaluate_kinematics(values)
	timings.evaluate_count += 1
	timings.evaluate_us += Time.get_ticks_usec() - started
	return result

func _evaluate_kinematics(values: PackedFloat64Array) -> Dictionary:
	if values.size() != q.size():
		return {"valid": false, "reason": "weapon_motion_parameter_count"}
	var poses: Array[Transform3D] = local_poses.duplicate()
	for record: Dictionary in torso:
		var index: int = record.index
		poses[index].basis = Basis(record.yaw_axis, values[record.q] * record.weight.x) * Basis(record.pitch_axis, -values[record.q + 1] * record.weight.y) * local_poses[index].basis
	for arm: Dictionary in arms:
		var indices: Array = arm.indices
		poses[indices[0]].basis = _rotation_vector(values, arm.clavicle_q) * local_poses[indices[0]].basis
		var shoulder_axes: Basis = arm.shoulder_axes
		var shoulder_vector: Vector3 = shoulder_axes.x * values[arm.shoulder_q] + shoulder_axes.z * values[arm.shoulder_q + 1] + shoulder_axes.y * values[arm.shoulder_q + 2]
		poses[indices[1]].basis = _rotation_from_vector(shoulder_vector) * local_poses[indices[1]].basis
		poses[indices[2]].basis = Basis(arm.hinge_local, values[arm.elbow_q] - float(arm.initial_flexion)) * local_poses[indices[2]].basis
	var globals: Array[Transform3D] = _forward(poses)
	var constraints := PackedFloat64Array()
	var reasons := PackedStringArray()
	# Absolute bounds refer to the fixed cached animation baseline. A repeated
	# command therefore cannot get a fresh allotment of torso rotation each time.
	for record: Dictionary in torso:
		var parent_global: Basis = (skeleton_world * globals[parents[record.index]]).basis.orthonormalized()
		var neutral_global: Basis = parent_global * (record.neutral as Basis)
		var candidate_global: Basis = (skeleton_world * globals[record.index]).basis.orthonormalized()
		var body_axes: Basis = rig.global_basis.orthonormalized()
		var delta: Basis = body_axes.transposed() * candidate_global * neutral_global.transposed() * body_axes
		var angles: Vector3 = delta.get_euler(EULER_ORDER_YXZ)
		constraints.append(absf(angles.y) / float(record.yaw_limit) - 1.0)
		reasons.append("JOINT_RANGE:torso_yaw:" + String(names[record.index]))
		constraints.append(absf(angles.x) / float(record.pitch_limit) - 1.0)
		reasons.append("JOINT_RANGE:torso_pitch:" + String(names[record.index]))
	var wrist_states: Dictionary = {}
	var shoulder_states: Dictionary = {}
	var weapon_frames: Array[Transform3D] = []
	var hand_frames: Dictionary = {}
	for arm: Dictionary in arms:
		var i: Array = arm.indices
		var w: int = arm.wrist_q
		var state: Dictionary = {"rho": values[w], "beta": values[w + 1], "gamma": values[w + 2]}
		var composed: Dictionary = Wrist.sample_kinematics(globals[i[2]], globals[i[3]], arm.wrist_calibration, arm.wrist_profile, state, values[arm.elbow_q], float(arm.full_flexion))
		if not composed.get("valid", false):
			return composed
		globals[i[3]].basis = composed.hand_basis
		poses[i[3]].basis = globals[i[2]].basis.inverse() * globals[i[3]].basis
		constraints.append(float(composed.envelope_value) - 1.0)
		reasons.append("COUPLED_LIMIT:" + String(arm.slot))
		var interval: Dictionary = Wrist.forearm_interval(arm.wrist_calibration, arm.wrist_profile, values[arm.elbow_q], float(arm.full_flexion))
		constraints.append(float(interval.rho_min) - values[w])
		reasons.append("JOINT_RANGE:forearm_min:" + String(arm.slot))
		constraints.append(values[w] - float(interval.rho_max))
		reasons.append("JOINT_RANGE:forearm_max:" + String(arm.slot))
		var humerus: Dictionary = Shoulder.measure(globals[arm.chest_index], globals[i[1]], globals[i[2]],
			arm.shoulder_calibration, arm.shoulder_profile, arm.shoulder_state)
		if not humerus.get("valid", false):
			return humerus
		# User chose documented coverage only. Outside it hold the measured
		# request-start axial angle, not an invented anatomical zero. Other
		# permitted joint coordinates remain available for correction/return.
		var covered_shoulder: bool = humerus.get("covered", false)
		var held_h: float = arm.shoulder_state.get("held_h", arm.shoulder_state.h)
		var shoulder_min: float = humerus.minimum_radians if covered_shoulder else held_h
		var shoulder_max: float = humerus.maximum_radians if covered_shoulder else held_h
		# A hold is not an anatomical overrange allowance. Offsetting its tiny
		# residual at each fresh request would ratchet the fixed anchor outward.
		var shoulder_reason_prefix := "JOINT_RANGE:" if covered_shoulder else "SHOULDER_HOLD:"
		constraints.append(shoulder_min - float(humerus.state.h))
		reasons.append(shoulder_reason_prefix + "shoulder_external:" + String(arm.slot))
		constraints.append(float(humerus.state.h) - shoulder_max)
		reasons.append(shoulder_reason_prefix + "shoulder_internal:" + String(arm.slot))
		shoulder_states[arm.slot] = humerus.state
		if not covered_shoulder:
			shoulder_states[arm.slot]["held_h"] = held_h
		var shoulder: float = (globals[i[0]].origin - globals[i[1]].origin).angle_to(globals[i[2]].origin - globals[i[1]].origin)
		constraints.append(deg_to_rad(float(rig.get("authoring_shoulder_min_plane_angle_degrees"))) - shoulder)
		reasons.append("JOINT_RANGE:shoulder_min:" + String(arm.slot))
		constraints.append(shoulder - deg_to_rad(float(rig.get("authoring_shoulder_max_plane_angle_degrees"))))
		reasons.append("JOINT_RANGE:shoulder_max:" + String(arm.slot))
		var hand_world: Transform3D = skeleton_world * globals[i[3]]
		weapon_frames.append(hand_world * (arm.hand_to_weapon as Transform3D))
		hand_frames[arm.slot] = hand_world
		wrist_states[arm.slot] = state
	var equalities := PackedFloat64Array()
	var equality_tolerances := PackedFloat64Array()
	var squared_norm_residuals: Dictionary = {}
	var search_constraints := constraints.duplicate()
	var search_constraint_reasons := reasons.duplicate()
	if weapon_frames.size() > 1:
		# Compare at the actual support Hand, not two WeaponRoot origins. A small
		# permitted orientation residual at a far-away root creates a lever error
		# at the contact; this check uses the actual attachment location instead.
		var support_arm: Dictionary = arms[1]
		var actual_hand: Transform3D = hand_frames[support_arm.slot]
		var required_hand: Transform3D = weapon_frames[0] * (support_arm.hand_in_weapon as Transform3D)
		var position_error: Vector3 = actual_hand.origin - required_hand.origin
		var rotation_error: Vector3 = _rotation_error(required_hand.basis, actual_hand.basis)
		var position_tolerance: float = float(policy.position_tolerance)
		var angle_tolerance: float = float(policy.orientation_tolerance)
		var normalized_position := position_error / position_tolerance
		var normalized_angle := rotation_error / angle_tolerance
		# The physical caps apply to vector lengths. The previous inscribed box
		# rejected otherwise legal contacts after tiny storage/readback rounding.
		squared_norm_residuals[constraints.size()] = normalized_position
		constraints.append(normalized_position.length_squared() - 1.0)
		reasons.append("CONTACT_DISTANCE:" + String(support_arm.slot))
		squared_norm_residuals[constraints.size()] = normalized_angle
		constraints.append(normalized_angle.length_squared() - 1.0)
		reasons.append("CONTACT_ORIENTATION:" + String(support_arm.slot))
		# Retain six directional rows for coordination, including at zero error
		# where a squared-norm gradient is zero. These rows are redundant bounds
		# of the physical ball, not a smaller direction-dependent allowance.
		for axis: int in 3:
			equalities.append(normalized_position[axis])
			equality_tolerances.append(1.0)
			search_constraints.append(normalized_position[axis] - 1.0 / sqrt(3.0))
			search_constraints.append(-normalized_position[axis] - 1.0 / sqrt(3.0))
			search_constraint_reasons.append("CONTACT_SEARCH_DISTANCE:" + str(axis) + ":positive")
			search_constraint_reasons.append("CONTACT_SEARCH_DISTANCE:" + str(axis) + ":negative")
		for axis: int in 3:
			equalities.append(normalized_angle[axis])
			equality_tolerances.append(1.0)
			search_constraints.append(normalized_angle[axis] - 1.0 / sqrt(3.0))
			search_constraints.append(-normalized_angle[axis] - 1.0 / sqrt(3.0))
			search_constraint_reasons.append("CONTACT_SEARCH_ORIENTATION:" + str(axis) + ":positive")
			search_constraint_reasons.append("CONTACT_SEARCH_ORIENTATION:" + str(axis) + ":negative")
	return {"valid": true, "weapon_frame": weapon_frames[0], "weapon_transform": weapon_frames[0],
		"constraints": constraints, "constraint_values": constraints, "constraint_reasons": reasons,
		"squared_norm_residuals": squared_norm_residuals,
		# Coordinate slabs guide the linear search without duplicating curved
		# norm boundaries in its active set. They never reject a stored pose;
		# nonlinear/initial/contact legality still uses the physical balls above.
		"search_constraints": search_constraints,
		"search_constraint_reasons": search_constraint_reasons,
		"equalities": equalities, "equality_tolerances": equality_tolerances,
		"payload": {"local_poses": poses, "globals": globals, "hand_frames": hand_frames,
			"wrist_states_by_slot": wrist_states, "shoulder_states_by_slot": shoulder_states,
			"q": values, "origin_id": Origin.ORIGIN_RL_BONE_ROOT}}

func _validate_candidate(evaluation: Dictionary) -> Dictionary:
	var started: int = Time.get_ticks_usec()
	var result: Dictionary = _validate_candidate_collision(evaluation)
	timings.validate_candidate_count += 1
	timings.validate_candidate_us += Time.get_ticks_usec() - started
	return result

func _validate_candidate_collision(evaluation: Dictionary) -> Dictionary:
	var payload: Dictionary = evaluation.payload
	# The initial pose is already installed. Do not rewrite it just to validate
	# it; new candidates must survive the same storage contract as final commit.
	var initial_sample: bool = PackedFloat64Array(payload.q) == q
	var before: Dictionary = {}
	var storage_validation := {"valid": true}
	if not initial_sample:
		var storage_started: int = Time.get_ticks_usec()
		before = _capture_commit_state()
		_commit(payload.duplicate(true), evaluation.weapon_frame, false)
		storage_validation = _validate_committed_pose(evaluation.weapon_frame, false)
		if not storage_validation.get("valid", false):
			var failure_reason := String(storage_validation.get("reason", "unknown"))
			storage_validation_failures[failure_reason] = int(storage_validation_failures.get(failure_reason, 0)) + 1
			storage_validation_last_failure = storage_validation.duplicate(true)
		timings.storage_validation_count += 1
		timings.storage_validation_us += Time.get_ticks_usec() - storage_started
	var checked: Variant = storage_validation
	if bool(storage_validation.get("valid", false)) and collision_validator.is_valid():
		checked = collision_validator.call(evaluation.weapon_frame)
	if not before.is_empty():
		var restore_started: int = Time.get_ticks_usec()
		_restore_commit_state(before)
		timings.storage_validation_us += Time.get_ticks_usec() - restore_started
	if not checked is Dictionary:
		return {"valid": false, "reason": "invalid_motion_collision_result"}
	return {"valid": bool(checked.get("valid", checked.get("legal", false))), "reason": checked.get("reason", "COLLISION")}

func _commit(payload: Dictionary, accepted_weapon: Transform3D, record_timing: bool = true) -> void:
	var started: int = Time.get_ticks_usec()
	_apply_local_poses(payload.local_poses)
	# Skin helpers consume accepted semantic rho. They cannot alter main bone
	# frames, the weapon task, or the calibrated rigid contact relationship.
	for arm: Dictionary in arms:
		var i: Array = arm.indices
		var state: Dictionary = payload.wrist_states_by_slot[arm.slot]
		var skin: Dictionary = ForearmSkin.distribute(skeleton.get_bone_global_pose(i[2]), skeleton.get_bone_global_pose(i[3]),
			arm.helper_rests[0], arm.helper_rests[1], arm.helper_rests[2], Wrist.forearm_geometry_limit(arm.wrist_calibration, arm.wrist_profile),
			float(arm.wrist_profile.angle_epsilon_radians), float(state.rho))
		if skin.get("valid", false):
			skeleton.set_bone_pose_rotation(i[4], skin.proximal_rotation)
			skeleton.set_bone_pose_rotation(i[5], skin.distal_rotation)
			rig.get("_wrist_motion_states")[arm.slot] = state.duplicate()
			rig.get("_wrist_motion_failures").erase(arm.slot)
		rig.get("_shoulder_motion_states")[arm.slot] = payload.shoulder_states_by_slot[arm.slot].duplicate(true)
	skeleton.force_update_all_bone_transforms()
	weapon.global_transform = accepted_weapon
	_refresh_hand_attachments()
	weapon.global_transform = accepted_weapon
	rig.call("sync_runtime_body_restriction_root_now")
	# Capture helper rotations too, so the replay packet is the committed pose.
	for index: int in skeleton.get_bone_count():
		payload.local_poses[index] = skeleton.get_bone_pose(index)
	if record_timing:
		timings.commit_us += Time.get_ticks_usec() - started

func _timing_result() -> Dictionary:
	return {"allocate_ms": float(Time.get_ticks_usec() - allocation_start_usec) / 1000.0,
		"evaluate_count": timings.evaluate_count, "evaluate_ms": float(timings.evaluate_us) / 1000.0,
		"validate_candidate_count": timings.validate_candidate_count, "validate_candidate_ms": float(timings.validate_candidate_us) / 1000.0,
		"storage_validation_count": timings.storage_validation_count, "storage_validation_ms": float(timings.storage_validation_us) / 1000.0,
		"commit_ms": float(timings.commit_us) / 1000.0, "parameter_count": q.size(), "bone_count": local_poses.size()}

func _apply_local_poses(poses: Array) -> void:
	for index: int in poses.size():
		skeleton.set_bone_pose_rotation(index, (poses[index] as Transform3D).basis.orthonormalized().get_rotation_quaternion())
	skeleton.force_update_all_bone_transforms()

func _forward(poses: Array[Transform3D]) -> Array[Transform3D]:
	var globals: Array[Transform3D] = []
	globals.resize(poses.size())
	var done := PackedByteArray()
	done.resize(poses.size())
	for index: int in poses.size():
		_forward_bone(index, poses, globals, done)
	return globals

func _forward_bone(index: int, poses: Array[Transform3D], globals: Array[Transform3D], done: PackedByteArray) -> void:
	if done[index] != 0:
		return
	var parent: int = parents[index]
	if parent >= 0:
		_forward_bone(parent, poses, globals, done)
		globals[index] = globals[parent] * poses[index]
	else:
		globals[index] = poses[index]
	done[index] = 1

func _pose_packet(poses: Array) -> Dictionary:
	var positions := PackedVector3Array()
	var rotations := PackedVector4Array()
	var scales := PackedVector3Array()
	for frame: Transform3D in poses:
		var rotation: Quaternion = frame.basis.orthonormalized().get_rotation_quaternion()
		positions.append(frame.origin)
		rotations.append(Vector4(rotation.x, rotation.y, rotation.z, rotation.w))
		scales.append(frame.basis.get_scale())
	return {"bone_names": names.duplicate(), "pose_positions": positions, "pose_rotations": rotations,
		"pose_scales": scales, "origin_id": Origin.ORIGIN_SOLVED_REPLAY_REFERENCE}

static func _rotation_vector(values: PackedFloat64Array, start: int) -> Basis:
	var vector := Vector3(values[start], values[start + 1], values[start + 2])
	return _rotation_from_vector(vector)

static func _rotation_from_vector(vector: Vector3) -> Basis:
	var angle: float = vector.length()
	return Basis(vector / angle, angle) if angle > EPSILON else Basis.IDENTITY

static func _rotation_error(source: Basis, destination: Basis) -> Vector3:
	var rotation: Quaternion = (destination.orthonormalized().get_rotation_quaternion() * source.orthonormalized().get_rotation_quaternion().inverse()).normalized()
	if rotation.w < 0.0:
		rotation = -rotation
	var vector := Vector3(rotation.x, rotation.y, rotation.z)
	var length: float = vector.length()
	return vector * (2.0 * atan2(length, rotation.w) / length) if length > EPSILON else vector * 2.0

static func _failure(reason: String, status: String = "BLOCKED") -> Dictionary:
	return {"valid": false, "available": false, "status": status, "reason": reason}
