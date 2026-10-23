extends RefCounted
class_name CombatPreparedPose

## Value contract for a pose already solved and captured during editing.
const SCHEMA_VERSION := 2
const NON_POSE_FIELDS: Array[StringName] = [
	&"node_id", &"node_index", &"draft_notes", &"retarget_node",
	&"prepared_pose", &"prepared_pose_signature", &"transition_duration_seconds",
	&"tip_curve_in_handle", &"tip_curve_out_handle",
	&"pommel_curve_in_handle", &"pommel_curve_out_handle", &"locked_for_authoring",
]

static func node_pose_signature(node: Resource) -> String:
	if node == null:
		return ""
	var values: Array = []
	for property: Dictionary in node.get_property_list():
		var name: StringName = StringName(property.name)
		if (int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0 or (int(property.usage) & PROPERTY_USAGE_STORAGE) == 0 or name in NON_POSE_FIELDS:
			continue
		values.append([name, node.get(name)])
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

static func _valid_vector(value: Variant) -> bool:
	return value is Vector3 and value.is_finite()

static func _valid_rotation(value: Variant) -> bool:
	return value is Vector4 and value.is_finite() and value.length_squared() > 0.000001

static func _valid_transform(value: Variant) -> bool:
	return value is Transform3D and value.is_finite() and value.basis.determinant() > 0.000000000001

static func _fail(reason: String) -> Dictionary:
	return {"valid": false, "reason": reason}
