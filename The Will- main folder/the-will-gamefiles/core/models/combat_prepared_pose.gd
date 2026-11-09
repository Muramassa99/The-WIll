extends RefCounted
class_name CombatPreparedPose

const MotionNode = preload("res://core/models/combat_animation_motion_node.gd")
const EMPTY_HAND_CURL_FIELDS: Array[StringName] = [
	&"right_hand_finger_curl_degrees", &"left_hand_finger_curl_degrees",
]
## Value contract for a pose already solved and captured during editing.
# Semantic wrist authority replaces the former Hand swing-twist snapshots.
# Retain authored controls, but do not silently restore their obsolete solve.
const SCHEMA_VERSION := 4
const NON_POSE_FIELDS: Array[StringName] = [
	&"node_id", &"node_index", &"draft_notes", &"retarget_node",
	&"prepared_pose", &"prepared_pose_signature", &"transition_duration_seconds",
	&"tip_curve_in_handle", &"tip_curve_out_handle",
	&"pommel_curve_in_handle", &"pommel_curve_out_handle", &"locked_for_authoring",
	# Empty controls did not exist in older signatures. Append only authored
	# digits below, so adding this feature preserves untouched prepared poses.
	&"right_hand_finger_curl_degrees", &"left_hand_finger_curl_degrees",
]
static var _native_pose_capture_kernel: RefCounted

static func node_pose_signature(node: Resource) -> String:
	if node == null:
		return ""
	# The signature format remains unchanged. Sparse-control policy stays with
	# MotionNode; native code only assembles and hashes the same Variant payload.
	# Arbitrary Resources retain the generic script path, which discovers fields.
	if node is MotionNode:
		if _native_pose_capture_kernel == null and ClassDB.class_exists(&"CombatPoseCaptureKernel"):
			_native_pose_capture_kernel = ClassDB.instantiate(&"CombatPoseCaptureKernel") as RefCounted
		if _native_pose_capture_kernel != null:
			var normalized_curls: Dictionary = {}
			for field: StringName in EMPTY_HAND_CURL_FIELDS:
				normalized_curls[field] = MotionNode.normalize_empty_hand_finger_curls(node.get(field))
			return _native_pose_capture_kernel.call("node_pose_signature", node,
				NON_POSE_FIELDS, EMPTY_HAND_CURL_FIELDS, MotionNode.EMPTY_HAND_FINGER_IDS,
				normalized_curls, PROPERTY_USAGE_SCRIPT_VARIABLE | PROPERTY_USAGE_STORAGE)
	return _node_pose_signature_script(node)

static func _node_pose_signature_script(node: Resource) -> String:
	if node == null:
		return ""
	var values: Array = []
	var curl_fields: Dictionary = {}
	for property: Dictionary in node.get_property_list():
		var name: StringName = StringName(property.name)
		if name in EMPTY_HAND_CURL_FIELDS:
			var authored: Variant = node.get(name)
			if authored is Dictionary:
				curl_fields[name] = MotionNode.normalize_empty_hand_finger_curls(authored)
		if (int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0 or (int(property.usage) & PROPERTY_USAGE_STORAGE) == 0 or name in NON_POSE_FIELDS:
			continue
		values.append([name, node.get(name)])
	for field: StringName in EMPTY_HAND_CURL_FIELDS:
		var curls: Dictionary = curl_fields.get(field, {})
		if curls.is_empty():
			continue
		var ordered: Array = []
		for digit: StringName in MotionNode.EMPTY_HAND_FINGER_IDS:
			if curls.has(digit):
				ordered.append([digit, curls[digit]])
		values.append([field, ordered])
	return var_to_bytes(values).hex_encode().sha256_text()

static func validate(snapshot: Dictionary, context_signature: String = "") -> Dictionary:
	if not bool(snapshot.get("valid", false)) or int(snapshot.get("schema_version", -1)) != SCHEMA_VERSION:
		return _fail("missing_or_obsolete_prepared_pose")
	if not snapshot.get("attachment_required") is bool:
		return _fail("prepared_pose_missing_attachment_policy")
	if not context_signature.is_empty() and String(snapshot.get("context_signature", "")) != context_signature:
		return _fail("prepared_pose_context_changed")
	var names: Array = snapshot.get("bone_names", [])
	var count: int = names.size()
	if count == 0:
		return _fail("prepared_pose_has_no_bones")
	for field: String in ["pose_positions", "pose_rotations", "pose_scales", "parent_indices", "parent_reference_transforms", "bone_rest_transforms"]:
		if not snapshot.has(field) or snapshot[field].size() != count:
			return _fail("prepared_pose_incomplete_" + field)
	var seen: Dictionary = {}
	for index: int in count:
		if String(names[index]).is_empty() or seen.has(names[index]):
			return _fail("prepared_pose_invalid_bone_names")
		seen[names[index]] = true
		var parent: int = int(snapshot.parent_indices[index])
		if parent < -1 or parent >= count or parent == index:
			return _fail("prepared_pose_invalid_parent")
		if not _valid_vector(snapshot.pose_positions[index]) or not _valid_vector(snapshot.pose_scales[index]) or not _valid_rotation(snapshot.pose_rotations[index]):
			return _fail("prepared_pose_invalid_local_transform")
		if not _valid_transform(snapshot.parent_reference_transforms[index]) or not _valid_transform(snapshot.bone_rest_transforms[index]):
			return _fail("prepared_pose_invalid_reference_transform")
	if not names.has(snapshot.get("primary_hand_bone_name")) or not _valid_transform(snapshot.get("primary_hand_in_weapon")):
		return _fail("prepared_pose_missing_primary_relationship")
	if bool(snapshot.get("support_enabled", false)) and (not names.has(snapshot.get("support_hand_bone_name")) or not _valid_transform(snapshot.get("support_hand_in_weapon"))):
		return _fail("prepared_pose_missing_support_relationship")
	if snapshot.attachment_required:
		var primary_slot: StringName = StringName(snapshot.get("primary_hand_slot", StringName()))
		if not _valid_attachment_constraints(snapshot, names, primary_slot, snapshot.primary_hand_bone_name):
			return _fail("prepared_pose_missing_primary_arm_constraints")
		if bool(snapshot.get("support_enabled", false)):
			var support_slot: StringName = StringName(snapshot.get("support_hand_slot", StringName()))
			if support_slot == primary_slot or not _valid_attachment_constraints(snapshot, names, support_slot, snapshot.support_hand_bone_name):
				return _fail("prepared_pose_missing_support_arm_constraints")
	var arm_packets: Variant = snapshot.get("arm_constraints_by_slot", {})
	if arm_packets is Dictionary:
		for slot: Variant in arm_packets:
			var packet: Variant = arm_packets[slot]
			if packet is Dictionary and packet.has("shoulder_model_revision"):
				if not _valid_shoulder_constraints(packet):
					return _fail("prepared_pose_missing_shoulder_constraints").merged({"hand_slot": slot})
				var shoulder_state: Variant = snapshot.get("shoulder_states_by_slot", {}).get(slot, {})
				if not snapshot.get("shoulder_measurement_failures_by_slot", {}).has(slot):
					if not shoulder_state is Dictionary or not _finite_number(shoulder_state.get("h")):
						return _fail("prepared_pose_missing_shoulder_state").merged({"hand_slot": slot})
				if shoulder_state is Dictionary and shoulder_state.has("held_h") and not _finite_number(shoulder_state.held_h):
					return _fail("prepared_pose_invalid_shoulder_hold_state").merged({"hand_slot": slot})
			if not packet is Dictionary or not packet.has("wrist_model_revision"):
				continue
			if not _valid_wrist_constraints(packet):
				return _fail("prepared_pose_missing_wrist_constraints").merged({"hand_slot": slot})
			# A measured off-mechanism pose remains recordable via its finite bone
			# transforms. It has no fabricated semantic wrist state; playback uses
			# that recorded pose with a warning when guidance cannot represent it.
			if snapshot.get("wrist_measurement_failures_by_slot", {}).get(slot, "") == "wrist_pose_not_representable":
				continue
			var state: Variant = snapshot.get("wrist_states_by_slot", {}).get(slot, {})
			if not state is Dictionary:
				return _fail("prepared_pose_missing_wrist_state").merged({"hand_slot": slot})
			for key: String in ["rho", "beta", "gamma"]:
				var value: Variant = state.get(key)
				if not (value is float or value is int) or not is_finite(float(value)):
					return _fail("prepared_pose_missing_wrist_state").merged({"hand_slot": slot})
	if not _valid_vector(snapshot.get("weapon_position_reference_local")) or not _valid_vector(snapshot.get("weapon_scale_reference_local")) or not snapshot.get("weapon_rotation_reference_local") is Quaternion:
		return _fail("prepared_pose_invalid_weapon_transform")
	var weapon_rotation: Quaternion = snapshot.weapon_rotation_reference_local
	if not weapon_rotation.is_finite() or weapon_rotation.length_squared() < 0.000001:
		return _fail("prepared_pose_invalid_weapon_rotation")
	for field: String in ["reference_bone_name", "reference_origin_id", "weapon_reference_origin_id", "anchor_origin_id"]:
		if String(snapshot.get(field, "")).is_empty():
			return _fail("prepared_pose_missing_" + field)
	var anchors: Array = snapshot.get("anchor_node_paths", [])
	for field: String in ["anchor_positions_weapon_local", "anchor_rotations_weapon_local", "anchor_scales_weapon_local"]:
		if not snapshot.has(field) or snapshot[field].size() != anchors.size():
			return _fail("prepared_pose_incomplete_" + field)
	for index: int in anchors.size():
		if not _valid_vector(snapshot.anchor_positions_weapon_local[index]) or not _valid_vector(snapshot.anchor_scales_weapon_local[index]) or not _valid_rotation(snapshot.anchor_rotations_weapon_local[index]):
			return _fail("prepared_pose_invalid_anchor_transform")
	return {"valid": true, "reason": ""}

static func _valid_attachment_constraints(snapshot: Dictionary, names: Array, slot: StringName, hand: StringName) -> bool:
	if slot not in [&"hand_right", &"hand_left"] or not snapshot.get("arm_constraints_by_slot") is Dictionary:
		return false
	var by_slot: Dictionary = snapshot.arm_constraints_by_slot
	if not by_slot.get(slot) is Dictionary:
		return false
	var constraints: Dictionary = by_slot[slot]
	if not bool(constraints.get("valid", false)) or constraints.get("slot_id") != slot or constraints.get("hand_bone") != hand:
		return false
	if not _valid_wrist_constraints(constraints):
		return false
	for field: String in ["clavicle_bone", "upperarm_bone", "forearm_bone", "hand_bone"]:
		if not names.has(constraints.get(field)):
			return false
	for field: String in ["shoulder_min_degrees", "shoulder_max_degrees", "elbow_min_degrees", "elbow_max_degrees", "joint_epsilon_degrees", "limb_twist_limit_radians", "usable_reach_m"]:
		var value: Variant = constraints.get(field)
		if not (value is float or value is int) or not is_finite(float(value)):
			return false
	for field: String in ["limb_twist_axis", "reference_up"]:
		if not _valid_vector(constraints.get(field)) or (constraints[field] as Vector3).length_squared() <= 0.00000001:
			return false
	if not constraints.get("twist_chains") is Array or not constraints.get("twist_neutral_rotations") is Dictionary:
		return false
	for chain: Variant in constraints.twist_chains:
		if not chain is Array:
			return false
		for bone: Variant in chain:
			if not names.has(bone):
				continue
			var neutral: Variant = constraints.twist_neutral_rotations.get(bone)
			if not neutral is Quaternion or not neutral.is_finite() or neutral.length_squared() <= 0.000001:
				return false
	return true

static func _valid_wrist_constraints(packet: Dictionary) -> bool:
	var revision: String = String(packet.get("wrist_model_revision", ""))
	var calibration: Variant = packet.get("wrist_calibration")
	var profile: Variant = packet.get("wrist_profile")
	if revision.is_empty() or not calibration is Dictionary or not profile is Dictionary:
		return false
	if String(calibration.get("revision", "")) != revision or String(profile.get("revision", "")) != revision:
		return false
	if not bool(calibration.get("valid", false)):
		return false
	for field: String in ["neutral_anatomical_in_forearm", "anatomical_in_hand_bone"]:
		var basis: Variant = calibration.get(field)
		if not basis is Basis or not basis.is_finite() or basis.determinant() <= 0.000001:
			return false
	var radial_sign: Variant = calibration.get("radial_sign")
	if not (radial_sign is float or radial_sign is int) or not is_equal_approx(absf(float(radial_sign)), 1.0):
		return false
	for field: String in ["forearm_roll_limit_radians", "flexion_limit_radians", "extension_limit_radians", "ulnar_limit_radians", "radial_limit_radians", "orientation_tolerance_radians", "angle_epsilon_radians"]:
		var value: Variant = profile.get(field)
		if not (value is float or value is int) or not is_finite(float(value)) or float(value) <= 0.0:
			return false
	# Additive anatomy data retains the geometric meaning of existing rho.
	# Old snapshots keep their own complete profile; new packets must include
	# both the interval and the mapping from thumb-up to imported-rest zero.
	if profile.has("forearm_interval_revision"):
		if String(profile.forearm_interval_revision).is_empty() or calibration.get("forearm_interval_revision") != profile.forearm_interval_revision:
			return false
		for field: String in ["forearm_thumb_up_rho_radians", "forearm_pronation_sign"]:
			var value: Variant = calibration.get(field)
			if not (value is float or value is int) or not is_finite(float(value)):
				return false
		if not is_equal_approx(absf(float(calibration.forearm_pronation_sign)), 1.0):
			return false
		var bends: Variant = profile.get("forearm_elbow_samples_radians")
		if not bends is PackedFloat64Array or bends.size() < 2:
			return false
		for index: int in bends.size():
			if not is_finite(bends[index]) or bends[index] < 0.0 or (index > 0 and bends[index] <= bends[index - 1]):
				return false
		for field: String in ["forearm_pronation_limits_radians", "forearm_supination_limits_radians"]:
			var limits: Variant = profile.get(field)
			if not limits is PackedFloat64Array or limits.size() != bends.size():
				return false
			for angle: float in limits:
				if not is_finite(angle) or angle <= 0.0:
					return false
	return true

static func _valid_vector(value: Variant) -> bool:
	return value is Vector3 and value.is_finite()

static func _finite_number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))

## This validates persistent data shape, not pose legality. The resolver owns
## anatomical bounds; a measured out-of-range h is still a recordable pose.
static func _valid_shoulder_constraints(packet: Dictionary) -> bool:
	var revision := String(packet.get("shoulder_model_revision", ""))
	var calibration: Variant = packet.get("shoulder_calibration")
	var profile: Variant = packet.get("shoulder_profile")
	if revision.is_empty() or not calibration is Dictionary or not profile is Dictionary:
		return false
	if not bool(calibration.get("valid", false)) or calibration.get("revision") != revision or profile.get("revision") != revision:
		return false
	for key: String in ["chest_bone_name", "upperarm_bone_name", "forearm_bone_name", "clavicle_bone_name", "origin_id", "parent_origin_id"]:
		if String(calibration.get(key, "")).is_empty():
			return false
	for key: String in ["material_frame_in_upperarm", "chest_anatomical_in_bone"]:
		var basis: Variant = calibration.get(key)
		if not basis is Basis or not basis.is_finite() or basis.determinant() <= 0.000001:
			return false
	for key: String in ["internal_sign", "side_sign"]:
		if not _finite_number(calibration.get(key)) or not is_equal_approx(absf(float(calibration[key])), 1.0):
			return false
	var samples: Variant = profile.get("plane_samples_radians")
	var minimum: Variant = profile.get("minimum_samples_radians")
	var maximum: Variant = profile.get("maximum_samples_radians")
	if not samples is PackedFloat64Array or not minimum is PackedFloat64Array or not maximum is PackedFloat64Array or samples.size() < 2 or minimum.size() != samples.size() or maximum.size() != samples.size():
		return false
	for index: int in samples.size():
		if not is_finite(samples[index]) or not is_finite(minimum[index]) or not is_finite(maximum[index]) or minimum[index] >= maximum[index] or (index > 0 and samples[index] <= samples[index - 1]):
			return false
	return true

static func _valid_rotation(value: Variant) -> bool:
	return value is Vector4 and value.is_finite() and value.length_squared() > 0.000001

static func _valid_transform(value: Variant) -> bool:
	return value is Transform3D and value.is_finite() and value.basis.determinant() > 0.000000000001

static func _fail(reason: String) -> Dictionary:
	return {"valid": false, "reason": reason}
