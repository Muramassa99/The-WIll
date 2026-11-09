extends RefCounted
class_name PlayerEmptyHandFingerPose

## Independent, formula-driven posing of an empty hand. These are the existing
## digit hinges, not a grip acquisition and not a second finger axis definition.
const HingeRules = preload("res://runtime/player/player_digit_hinge_rules.gd")
const DIGITS: Array[StringName] = [&"index", &"middle", &"ring", &"pinky"]
const MAX_CONTROL_DEGREES: float = 180.0


## Build the entire requested overlay before any skeleton write. The supplied
## Idle rotations are fixed parent-bone-local references. Each hinge axis belongs
## to its named digit bone; the actual parent chain is checked to RL_BoneRoot.
static func compose(skeleton: Skeleton3D, slot: StringName, curls: Dictionary, idle_packet: Dictionary) -> Dictionary:
	if skeleton == null or slot not in [HingeRules.SLOT_RIGHT, HingeRules.SLOT_LEFT]:
		return {"valid": false, "reason": "empty_hand_finger_context_unavailable"}
	if not idle_packet.get("valid", false) or idle_packet.get("hand_slot") != slot \
		or idle_packet.get("rotation_origins") != &"parent_bone_local":
		return {"valid": false, "reason": "empty_hand_finger_idle_reference_missing"}
	var baseline: Dictionary = idle_packet.get("rotations", {})
	var rotations: Dictionary = {}
	var angles: Dictionary = {}
	var parents: Dictionary = {}
	for key: Variant in curls:
		if not (key is String or key is StringName) or StringName(key) not in DIGITS:
			return {"valid": false, "reason": "empty_hand_finger_not_supported"}
		var digit := StringName(key)
		var value: Variant = curls[key]
		if not (value is float or value is int) or not is_finite(float(value)):
			return {"valid": false, "reason": "empty_hand_finger_angle_invalid"}
		var angle := clampf(float(value), 0.0, MAX_CONTROL_DEGREES)
		var rules: Array[Dictionary] = HingeRules.get_chain_rules(slot, digit)
		if rules.size() != 3:
			return {"valid": false, "reason": "empty_hand_finger_chain_missing"}
		for rule: Dictionary in rules:
			var bone: StringName = rule.bone
			if not HingeRules.rule_has_valid_origin_chain(rule, skeleton):
				return {"valid": false, "reason": "empty_hand_finger_origin_chain_invalid", "bone": bone}
			var reference: Variant = baseline.get(bone)
			if not reference is Quaternion or not reference.is_finite() or reference.length_squared() <= 0.00000001:
				return {"valid": false, "reason": "empty_hand_finger_idle_rotation_invalid", "bone": bone}
			var hinge_axis: Vector3 = rule.hinge_axis_local
			if not hinge_axis.is_finite() or hinge_axis.length_squared() <= 0.00000001:
				return {"valid": false, "reason": "empty_hand_finger_hinge_axis_invalid", "bone": bone}
			var hinge_degrees := lerpf(float(rule.open_degrees), float(rule.closed_degrees), angle / MAX_CONTROL_DEGREES)
			rotations[bone] = (reference.normalized() * Quaternion(hinge_axis.normalized(), deg_to_rad(hinge_degrees))).normalized()
			var index: int = skeleton.find_bone(String(bone))
			parents[bone] = StringName(skeleton.get_bone_name(skeleton.get_bone_parent(index)))
		angles[digit] = angle
	return {"valid": true, "hand_slot": slot, "angles_degrees": angles, "rotations": rotations,
		"rotation_origins": &"parent_bone_local", "parent_bones": parents,
		"machine_origin_id": HingeRules.ROOT_ORIGIN_ID, "baseline_source": idle_packet.get("source", &"animation_idle_baseline"),
		"hinge_rule_revision": HingeRules.get_revision()}


## Only the selected phalanges' rotations are written. All translations/scales,
## the wrist, the arm, the thumb and every absent finger remain untouched.
static func apply(skeleton: Skeleton3D, overlay: Dictionary) -> bool:
	if skeleton == null or not overlay.get("valid", false) or overlay.get("rotation_origins") != &"parent_bone_local" \
		or overlay.get("machine_origin_id") != HingeRules.ROOT_ORIGIN_ID:
		return false
	var rotations: Dictionary = overlay.get("rotations", {})
	var parents: Dictionary = overlay.get("parent_bones", {})
	var indices: Dictionary = {}
	for bone: StringName in rotations:
		var index: int = skeleton.find_bone(String(bone))
		var rotation: Variant = rotations[bone]
		if index < 0 or not rotation is Quaternion or not rotation.is_finite() or not rotation.is_normalized():
			return false
		var parent_index: int = skeleton.get_bone_parent(index)
		if parent_index < 0 or StringName(skeleton.get_bone_name(parent_index)) != parents.get(bone):
			return false
		indices[bone] = index
	var changed: bool = false
	for bone: StringName in rotations:
		if skeleton.get_bone_pose_rotation(indices[bone]) != rotations[bone]:
			skeleton.set_bone_pose_rotation(indices[bone], rotations[bone])
			changed = true
	if changed:
		skeleton.force_update_all_bone_transforms()
	return true


## Read-only inference for a not-yet-authored knob. Project each current joint
## onto its fixed Idle hinge and average the normalized per-joint progress. The
## full joint measurements remain available; this does not normalize the pose.
static func describe(skeleton: Skeleton3D, slot: StringName, digit: StringName, idle_packet: Dictionary, overlay: Dictionary = {}) -> Dictionary:
	if digit not in DIGITS:
		return {"valid": false, "reason": "empty_hand_finger_not_supported"}
	var reference: Dictionary = compose(skeleton, slot, {digit: 0.0}, idle_packet)
	if not reference.get("valid", false):
		return reference
	var baseline: Dictionary = idle_packet.rotations
	var joints: Array[Dictionary] = []
	var progress: float = 0.0
	for rule: Dictionary in HingeRules.get_chain_rules(slot, digit):
		var bone: StringName = rule.bone
		var index: int = skeleton.find_bone(String(bone))
		var current: Quaternion = skeleton.get_bone_pose_rotation(index)
		if not current.is_finite() or current.length_squared() <= 0.00000001:
			return {"valid": false, "reason": "empty_hand_finger_current_rotation_invalid", "bone": bone}
		var delta: Quaternion = (baseline[bone].normalized().inverse() * current.normalized()).normalized()
		var axis: Vector3 = (rule.hinge_axis_local as Vector3).normalized()
		var along: float = Vector3(delta.x, delta.y, delta.z).dot(axis)
		var hinge_degrees: float = rad_to_deg(wrapf(2.0 * atan2(along, delta.w), -PI, PI))
		var span: float = float(rule.closed_degrees) - float(rule.open_degrees)
		if absf(span) <= 0.00000001:
			return {"valid": false, "reason": "empty_hand_finger_hinge_range_invalid", "bone": bone}
		var ratio: float = clampf((hinge_degrees - float(rule.open_degrees)) / span, 0.0, 1.0)
		progress += ratio
		joints.append({"bone": bone, "hinge_degrees": hinge_degrees, "control_degrees": ratio * MAX_CONTROL_DEGREES,
			"open_degrees": rule.open_degrees, "closed_degrees": rule.closed_degrees,
			"hinge_axis_local": axis, "hinge_axis_origin_id": rule.hinge_axis_origin_id})
	var angles: Dictionary = overlay.get("angles_degrees", {})
	return {"valid": true, "hand_slot": slot, "digit": digit, "authored": angles.has(digit),
		"angle_degrees": float(angles.get(digit, progress / float(joints.size()) * MAX_CONTROL_DEGREES)),
		"minimum_degrees": 0.0, "maximum_degrees": MAX_CONTROL_DEGREES,
		"joints": joints, "rotation_origins": &"parent_bone_local", "machine_origin_id": HingeRules.ROOT_ORIGIN_ID}
