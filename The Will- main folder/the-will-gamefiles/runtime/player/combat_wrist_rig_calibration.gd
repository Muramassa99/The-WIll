extends RefCounted
class_name CombatWristRigCalibration

## Read-only imported-rest adapter. The result is fixed calibration, never a
## neutral inferred from a posed Hand or a partially rolled deformation helper.
const WristMotion = preload("res://core/resolvers/combat_wrist_motion_resolver.gd")
const ForearmRotation = preload("res://core/resolvers/combat_forearm_rotation_resolver.gd")
const DigitRules = preload("res://runtime/player/player_digit_hinge_rules.gd")
const ROOT := &"RL_BoneRoot"
const REVISION := WristMotion.REVISION
const DIRECTION_EPSILON_SQUARED := 1.0e-16
# Direction-quality gates, not anatomical ROM or additional motion allowance.
const MIN_CLOSING_ALIGNMENT := 0.1
const MIN_RADIAL_ALIGNMENT := 0.1
const FOREARM_NAMES := {
	&"hand_right": &"CC_Base_R_Forearm",
	&"hand_left": &"CC_Base_L_Forearm",
}

static func build(skeleton: Skeleton3D, slot: StringName) -> Dictionary:
	if not is_instance_valid(skeleton) or not FOREARM_NAMES.has(slot):
		return _fail("missing_wrist_skeleton_or_slot")
	var side: Dictionary = DigitRules.get_surface_solver_side_rules(slot)
	if side.is_empty():
		return _fail("missing_wrist_hand_mapping")
	var hand_name: StringName = side.hand_bone_name
	var forearm_name: StringName = FOREARM_NAMES[slot]
	var hand_index: int = skeleton.find_bone(String(hand_name))
	var forearm_index: int = skeleton.find_bone(String(forearm_name))
	var root_index: int = skeleton.find_bone(String(ROOT))
	if mini(hand_index, mini(forearm_index, root_index)) < 0:
		return _fail("missing_wrist_reference_bone")
	if skeleton.get_bone_parent(hand_index) != forearm_index:
		return _fail("unsupported_wrist_parent_chain")

	var chains: Dictionary = {}
	var required_names: Array[StringName] = [forearm_name, hand_name]
	for digit: StringName in [&"index", &"middle", &"ring", &"pinky"]:
		var chain: Array[Dictionary] = DigitRules.get_chain_rules(slot, digit)
		if chain.size() != 3:
			return _fail("missing_wrist_landmark_chain", {"digit": digit})
		chains[digit] = chain
		required_names.append(StringName(chain[0].bone))
		if digit != &"index":
			required_names.append(StringName(chain[1].bone))
	var thumb_chain: Array[Dictionary] = DigitRules.get_chain_rules(slot, &"thumb")
	var thumb_name := StringName()
	if not thumb_chain.is_empty():
		thumb_name = StringName(thumb_chain[0].bone)
		if skeleton.find_bone(String(thumb_name)) >= 0:
			required_names.append(thumb_name)
		else:
			thumb_name = StringName()

	# Retain every contributing parent rest, including the named machine root.
	# These arrays are parallel and parent-first; the rig can invalidate its
	# cached calibration if any rest or parent in the source chain changes.
	var source_indices: Array[int] = []
	for bone_name: StringName in required_names:
		var bone_index: int = skeleton.find_bone(String(bone_name))
		if bone_index < 0:
			return _fail("missing_wrist_landmark_bone", {"bone": bone_name})
		if bone_index != hand_index and bone_index != forearm_index \
			and not _descends_from(skeleton, bone_index, hand_index):
			return _fail("wrist_landmark_outside_hand_chain", {"bone": bone_name})
		var ancestry: Array[int] = []
		var cursor: int = bone_index
		while cursor >= 0 and ancestry.size() <= skeleton.get_bone_count():
			ancestry.append(cursor)
			if cursor == root_index:
				break
			cursor = skeleton.get_bone_parent(cursor)
		if ancestry.is_empty() or ancestry.back() != root_index:
			return _fail("wrist_reference_does_not_reach_machine_root", {"bone": bone_name})
		ancestry.reverse()
		for ancestor: int in ancestry:
			if ancestor not in source_indices:
				source_indices.append(ancestor)

	var source_names: Array[StringName] = []
	var source_rests: Array[Transform3D] = []
	var source_parents: Array[StringName] = []
	var bone_origin_records: Dictionary = {}
	var global_rests: Dictionary = {}
	for bone_index: int in source_indices:
		var bone_name: StringName = StringName(skeleton.get_bone_name(bone_index))
		var rest: Transform3D = skeleton.get_bone_rest(bone_index)
		var global_rest: Transform3D = skeleton.get_bone_global_rest(bone_index)
		if not _valid_rest(rest) or not _valid_rest(global_rest):
			return _fail("nonrigid_or_reflected_wrist_rest", {"bone": bone_name})
		var parent_index: int = skeleton.get_bone_parent(bone_index)
		var parent_name: StringName = StringName(skeleton.get_bone_name(parent_index)) if parent_index >= 0 else StringName()
		source_names.append(bone_name)
		source_rests.append(rest)
		source_parents.append(parent_name)
		global_rests[bone_name] = global_rest
		bone_origin_records[bone_name] = {
			"origin_id": bone_name,
			"parent_origin_id": StringName() if bone_index == root_index else parent_name,
			"transform_to_parent": Transform3D.IDENTITY if bone_index == root_index else rest,
			"owner_system": &"wrist_rig_calibration", "resolve_phase": &"bake_time",
			"space_type": &"machine" if bone_index == root_index else &"bone_frame", "is_dynamic": false,
		}

	var hand_rest: Transform3D = global_rests[hand_name]
	var forearm_rest: Transform3D = global_rests[forearm_name]
	var wrist: Vector3 = hand_rest.origin
	var index_rest: Transform3D = global_rests[chains[&"index"][0].bone]
	var pinky_rest: Transform3D = global_rests[chains[&"pinky"][0].bone]
	var middle_rest: Transform3D = global_rests[chains[&"middle"][0].bone]
	var longitudinal: Vector3 = middle_rest.origin - wrist
	var area: Vector3 = (index_rest.origin - wrist).cross(pinky_rest.origin - wrist)
	if minf(longitudinal.length_squared(), area.length_squared()) <= DIRECTION_EPSILON_SQUARED:
		return _fail("degenerate_wrist_palm_landmarks")
	longitudinal = longitudinal.normalized()
	var unsigned_normal: Vector3 = area.normalized()
	var palmar_polarity := 0.0
	var closing_evidence: Array[Dictionary] = []
	for digit: StringName in [&"middle", &"ring", &"pinky"]:
		var chain: Array = chains[digit]
		var first: Transform3D = global_rests[chain[0].bone]
		var second: Transform3D = global_rests[chain[1].bone]
		var local_span: Vector3 = first.basis.inverse() * (second.origin - first.origin)
		var hinge_axis: Vector3 = chain[0].hinge_axis_local
		var closing_sign: float = signf(float(chain[0].closed_degrees) - float(chain[0].open_degrees))
		var closing_velocity: Vector3 = first.basis * hinge_axis.cross(local_span) * closing_sign
		if closing_velocity.length_squared() <= DIRECTION_EPSILON_SQUARED:
			return _fail("degenerate_wrist_palmar_closing_reference", {"digit": digit})
		var alignment: float = unsigned_normal.dot(closing_velocity.normalized())
		closing_evidence.append({"digit": digit, "unsigned_normal_alignment": alignment})
		if absf(alignment) < MIN_CLOSING_ALIGNMENT:
			return _fail("ambiguous_wrist_palmar_polarity", {"closing_evidence": closing_evidence})
		if palmar_polarity != 0.0 and signf(alignment) != palmar_polarity:
			return _fail("wrist_closing_references_disagree", {"closing_evidence": closing_evidence})
		palmar_polarity = signf(alignment)

	var dorsal: Vector3 = -unsigned_normal * palmar_polarity
	dorsal -= longitudinal * dorsal.dot(longitudinal)
	if dorsal.length_squared() <= DIRECTION_EPSILON_SQUARED:
		return _fail("degenerate_wrist_dorsal_reference")
	dorsal = dorsal.normalized()
	var across: Vector3 = longitudinal.cross(dorsal).normalized()
	dorsal = across.cross(longitudinal).normalized()
	var anatomical_rest := Basis(across, longitudinal, dorsal)
	if not anatomical_rest.is_finite() or not anatomical_rest.is_equal_approx(anatomical_rest.orthonormalized()) \
		or absf(anatomical_rest.determinant() - 1.0) > 0.00001:
		return _fail("invalid_wrist_anatomical_basis")

	# Positive Z rotation moves +Y toward -X. Measure the thumb side instead
	# of assigning a mirrored sign from slot names or any world-space axis.
	var thumb_side: Vector3 = index_rest.origin - pinky_rest.origin
	var radial_source := &"pinky_to_index_footprint"
	if thumb_name != StringName():
		var thumb_rest: Transform3D = global_rests[thumb_name]
		var thumb_offset: Vector3 = thumb_rest.origin - wrist
		if thumb_offset.length_squared() > DIRECTION_EPSILON_SQUARED \
			and absf(across.dot(thumb_offset.normalized())) >= MIN_RADIAL_ALIGNMENT:
			thumb_side = thumb_offset
			radial_source = thumb_name
	if thumb_side.length_squared() <= DIRECTION_EPSILON_SQUARED:
		return _fail("degenerate_wrist_radial_reference")
	var radial_alignment: float = (-across).dot(thumb_side.normalized())
	if absf(radial_alignment) < MIN_RADIAL_ALIGNMENT:
		return _fail("ambiguous_wrist_radial_reference")
	var neutral_in_forearm: Basis = forearm_rest.basis.orthonormalized().transposed() * anatomical_rest
	var anatomical_in_hand: Basis = hand_rest.basis.orthonormalized().transposed() * anatomical_rest
	var forearm_rotation: Dictionary = ForearmRotation.calibrate(
		skeleton.get_bone_rest(forearm_index), skeleton.get_bone_rest(hand_index),
		neutral_in_forearm, signf(radial_alignment))
	if not forearm_rotation.get("valid", false): return forearm_rotation
	forearm_rotation.erase("valid")
	forearm_rotation["forearm_reference_origin_id"] = forearm_name
	forearm_rotation["forearm_reference_parent_origin_id"] = StringName(skeleton.get_bone_name(skeleton.get_bone_parent(forearm_index)))
	forearm_rotation["forearm_reference_space"] = &"bone_frame"
	var origin_id := StringName(String(hand_name) + "WristAnatomicalOrigin")
	var transform_to_parent := Transform3D(anatomical_in_hand, Vector3.ZERO)
	var origin_record := {
		"origin_id": origin_id, "parent_origin_id": hand_name,
		"transform_to_parent": transform_to_parent, "owner_system": &"wrist_rig_calibration",
		"resolve_phase": &"bake_time", "space_type": &"bone_frame", "is_dynamic": false,
	}
	return {"valid": true, "reason": "rest_wrist_calibration", "revision": REVISION,
		"neutral_anatomical_in_forearm": neutral_in_forearm, "anatomical_in_hand_bone": anatomical_in_hand,
		"radial_sign": signf(radial_alignment), "radial_reference": radial_source,
		"origin_id": origin_id, "parent_origin_id": hand_name, "transform_to_parent": transform_to_parent,
		"origin_record": origin_record, "forearm_bone_name": forearm_name, "hand_bone_name": hand_name,
		"source_bone_names": source_names, "source_rest_transforms": source_rests,
		"source_parent_bone_names": source_parents, "source_rest_transform_space": &"parent_bone",
		"bone_origin_records": bone_origin_records, "closing_evidence": closing_evidence}.merged(forearm_rotation)

static func _descends_from(skeleton: Skeleton3D, bone_index: int, ancestor_index: int) -> bool:
	var cursor: int = bone_index
	for _step: int in range(skeleton.get_bone_count()):
		if cursor == ancestor_index:
			return true
		if cursor < 0:
			return false
		cursor = skeleton.get_bone_parent(cursor)
	return false

static func _valid_rest(rest: Transform3D) -> bool:
	return rest.is_finite() and rest.basis.determinant() > 0.0 and rest.basis.is_conformal()

static func _fail(reason: String, details: Dictionary = {}) -> Dictionary:
	return {"valid": false, "reason": reason, "revision": REVISION, "details": details}
