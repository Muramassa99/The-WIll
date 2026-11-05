extends RefCounted
class_name CombatShoulderRigCalibration

## Read-only calibration of imported Josie rest, never the current accepted pose.
## Chest -> spine ancestry -> RL_BoneRoot; arm material axes -> Upperarm ->
## Clavicle -> Chest. Combined humerothoracic measurement includes Clavicle.
const Hinge = preload("res://core/resolvers/combat_arm_hinge_frame_resolver.gd")
const Shoulder = preload("res://core/resolvers/combat_shoulder_motion_resolver.gd")
const ROOT := &"RL_BoneRoot"
const REVISION := Shoulder.REVISION
const EPSILON_SQUARED := 1.0e-12

static func build(skeleton: Skeleton3D, slot: StringName) -> Dictionary:
	if not is_instance_valid(skeleton) or slot not in [&"hand_right", &"hand_left"]:
		return _fail("shoulder_skeleton_or_slot_missing")
	var prefix: String = "CC_Base_R_" if slot == &"hand_right" else "CC_Base_L_"
	var clavicle_name := StringName(prefix + "Clavicle")
	var upperarm_name := StringName(prefix + "Upperarm")
	var forearm_name := StringName(prefix + "Forearm")
	var hand_name := StringName(prefix + "Hand")
	var chain: Array[int] = []
	for bone: StringName in [clavicle_name, upperarm_name, forearm_name, hand_name]:
		var index: int = skeleton.find_bone(String(bone))
		if index < 0:
			return _fail("shoulder_bone_missing_" + String(bone))
		chain.append(index)
	for i: int in range(1, chain.size()):
		if skeleton.get_bone_parent(chain[i]) != chain[i - 1]:
			return _fail("shoulder_nonserial_arm_chain")
	var chest_index: int = skeleton.get_bone_parent(chain[0])
	if chest_index < 0 or skeleton.get_bone_name(chest_index) != "CC_Base_Spine02":
		return _fail("shoulder_chest_parent_needs_calibration")
	var chest_name := StringName(skeleton.get_bone_name(chest_index))
	var lower_chest_index: int = skeleton.get_bone_parent(chest_index)
	var right_index: int = skeleton.find_bone("CC_Base_R_Upperarm")
	var left_index: int = skeleton.find_bone("CC_Base_L_Upperarm")
	var root_index: int = skeleton.find_bone(String(ROOT))
	if mini(lower_chest_index, mini(right_index, mini(left_index, root_index))) < 0:
		return _fail("shoulder_rest_landmarks_missing")
	var required: Array[int] = [chain[3], right_index, left_index, lower_chest_index]
	var source_indices: Array[int] = []
	for index: int in required:
		var ancestry: Array[int] = []
		var cursor: int = index
		while cursor >= 0 and ancestry.size() <= skeleton.get_bone_count():
			ancestry.append(cursor)
			if cursor == root_index:
				break
			cursor = skeleton.get_bone_parent(cursor)
		if ancestry.back() != root_index:
			return _fail("shoulder_reference_does_not_reach_machine_root")
		ancestry.reverse()
		for ancestor: int in ancestry:
			if ancestor not in source_indices:
				source_indices.append(ancestor)

	var names: Array[StringName] = []
	var rests: Array[Transform3D] = []
	var parents: Array[StringName] = []
	var bone_origins: Dictionary = {}
	for index: int in source_indices:
		var rest: Transform3D = skeleton.get_bone_rest(index)
		var global_rest: Transform3D = skeleton.get_bone_global_rest(index)
		if not _supported(rest) or not _supported(global_rest):
			return _fail("shoulder_rest_nonrigid")
		var name := StringName(skeleton.get_bone_name(index))
		var parent_index: int = skeleton.get_bone_parent(index)
		var parent_name := StringName(skeleton.get_bone_name(parent_index)) if parent_index >= 0 else StringName()
		names.append(name)
		rests.append(rest)
		parents.append(parent_name)
		bone_origins[name] = {"origin_id": name,
			"parent_origin_id": StringName() if index == root_index else parent_name,
			"transform_to_parent": Transform3D.IDENTITY if index == root_index else rest,
			"owner_system": &"shoulder_rig_calibration", "resolve_phase": &"bake_time",
			"space_type": &"machine" if index == root_index else &"bone_frame", "is_dynamic": false}

	var chest_rest: Transform3D = skeleton.get_bone_global_rest(chest_index)
	var lower_rest: Transform3D = skeleton.get_bone_global_rest(lower_chest_index)
	var right_rest: Transform3D = skeleton.get_bone_global_rest(right_index)
	var left_rest: Transform3D = skeleton.get_bone_global_rest(left_index)
	var up: Vector3 = chest_rest.origin - lower_rest.origin
	var right: Vector3 = right_rest.origin - left_rest.origin
	if minf(up.length_squared(), right.length_squared()) <= EPSILON_SQUARED:
		return _fail("shoulder_chest_landmarks_degenerate")
	up = up.normalized()
	right = (right - up * right.dot(up)).normalized()
	if right.length_squared() <= EPSILON_SQUARED:
		return _fail("shoulder_chest_landmarks_collinear")
	# Right / up / back is a right-handed anatomical chest convention. Sources
	# are named rest landmarks, so rotating/scaling the whole rig changes no zero.
	var back: Vector3 = right.cross(up).normalized()
	up = back.cross(right).normalized()
	var chest_frame := Basis(right, up, back)
	var chest_anatomical_in_bone: Basis = chest_rest.basis.orthonormalized().transposed() * chest_frame
	var hinge: Dictionary = Hinge.calibration(skeleton.get_bone_rest(chain[2]), skeleton.get_bone_rest(chain[3]))
	if not hinge.get("valid", false):
		return _fail(String(hinge.get("reason", "shoulder_hinge_calibration_missing")))
	var side: float = 1.0 if slot == &"hand_right" else -1.0
	# Reference exercise in the named chest frame: shaft down, forearm forward.
	# Internal turn moves that forearm toward the abdomen (away from own side).
	var outward := Vector3(side, 0.0, 0.0)
	var internal_sign: float = signf(Vector3.DOWN.cross(Vector3.FORWARD).dot(-outward))
	var origin_id := StringName(String(chest_name) + "ShoulderAnatomicalOrigin")
	var transform_to_parent := Transform3D(chest_anatomical_in_bone, Vector3.ZERO)
	var origin_record := {"origin_id": origin_id, "parent_origin_id": chest_name,
		"transform_to_parent": transform_to_parent, "owner_system": &"shoulder_rig_calibration",
		"resolve_phase": &"bake_time", "space_type": &"bone_frame", "is_dynamic": false}
	return {"valid": true, "reason": "", "revision": REVISION,
		"chest_bone_name": chest_name, "clavicle_bone_name": clavicle_name,
		"upperarm_bone_name": upperarm_name, "forearm_bone_name": forearm_name,
		"material_frame_in_upperarm": hinge.frame_in_upperarm,
		"chest_anatomical_in_bone": chest_anatomical_in_bone,
		"side_sign": side, "internal_sign": internal_sign,
		"zero_convention": "sideways_upperarm_forearm_forward_shortest_swing",
		"reference_exercise": "arm_down_forearm_forward; shoulder_height_forward_forearm_toward_midline",
		"origin_id": origin_id, "parent_origin_id": chest_name,
		"transform_to_parent": transform_to_parent, "origin_record": origin_record,
		"source_bone_names": names, "source_rest_transforms": rests,
		"source_parent_bone_names": parents, "source_rest_transform_space": &"parent_bone",
		"bone_origin_records": bone_origins}

static func _supported(frame: Transform3D) -> bool:
	return frame.is_finite() and frame.basis.determinant() > 0.0 and frame.basis.is_conformal()

static func _fail(reason: String) -> Dictionary:
	return {"valid": false, "reason": reason, "revision": REVISION}
