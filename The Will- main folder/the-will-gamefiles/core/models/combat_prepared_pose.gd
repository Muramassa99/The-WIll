extends RefCounted
class_name CombatPreparedPose

## Value contract for a pose already solved and captured during editing.
const SCHEMA_VERSION := 1
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

static func _valid_vector(value: Variant) -> bool:
	return value is Vector3 and value.is_finite()

static func _valid_rotation(value: Variant) -> bool:
	return value is Vector4 and value.is_finite() and value.length_squared() > 0.000001

static func _valid_transform(value: Variant) -> bool:
	return value is Transform3D and value.is_finite() and value.basis.determinant() > 0.000000000001

static func _fail(reason: String) -> Dictionary:
	return {"valid": false, "reason": reason}
