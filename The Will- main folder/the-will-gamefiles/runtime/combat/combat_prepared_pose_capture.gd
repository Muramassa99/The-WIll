extends RefCounted
class_name CombatPreparedPoseCapture

## Read the already displayed, settled editor pose. This never requests a grip,
## advances a modifier, or changes a bone. The UI owns when the pose is settled.
const Clip = preload("res://core/models/combat_runtime_clip.gd")
const PreparedPose = preload("res://core/models/combat_prepared_pose.gd")

static func capture(
	actor: Node3D,
	weapon: Node3D,
	dominant_slot: StringName,
	anchor_paths: Array = [],
	support_enabled: bool = false,
	context_signature: String = "",
	require_validation: bool = true
) -> Dictionary:
	if actor == null or weapon == null or not is_instance_valid(actor) or not is_instance_valid(weapon):
		return {"valid": false, "reason": "missing_prepared_pose_actor_or_weapon"}
	var skeleton: Skeleton3D = actor.get("skeleton") as Skeleton3D
	if skeleton == null or not actor.has_method("capture_runtime_upper_body_pose_frame") or not actor.has_method("capture_runtime_solved_replay_weapon_frame"):
		return {"valid": false, "reason": "missing_prepared_pose_capture_contract"}
	var reference_name: StringName = Clip.SOLVED_REPLAY_REFERENCE_BONE_NAME
	var reference_index: int = skeleton.find_bone(reference_name)
	var primary_name: StringName = &"CC_Base_L_Hand" if dominant_slot == &"hand_left" else &"CC_Base_R_Hand"
	var support_name: StringName = &"CC_Base_R_Hand" if dominant_slot == &"hand_left" else &"CC_Base_L_Hand"
	var primary_index: int = skeleton.find_bone(primary_name)
	var support_index: int = skeleton.find_bone(support_name)
	if reference_index < 0 or primary_index < 0 or (support_enabled and support_index < 0):
		return {"valid": false, "reason": "missing_prepared_pose_reference_or_hand"}
	var pose: Dictionary = actor.call("capture_runtime_upper_body_pose_frame") as Dictionary
	var mounted: Dictionary = actor.call("capture_runtime_solved_replay_weapon_frame", weapon, reference_name, anchor_paths) as Dictionary
	if not bool(mounted.get("valid", false)) or (pose.get("bone_names", []) as Array).is_empty():
		return {"valid": false, "reason": "prepared_pose_capture_unavailable"}
	pose.merge(mounted, true)
	var names: Array = pose.bone_names
	if not names.has(primary_name) or (support_enabled and not names.has(support_name)):
		return {"valid": false, "reason": "prepared_pose_hand_not_in_capture"}
	var reference_world: Transform3D = skeleton.global_transform * skeleton.get_bone_global_pose(reference_index)
	if not _valid_transform(reference_world) or not _valid_transform(weapon.global_transform):
		return {"valid": false, "reason": "invalid_prepared_pose_reference_frame"}
	# The existing solved replay contract uses a unit-scale reference basis;
	# model scale remains inside captured bone and weapon transforms.
	reference_world.basis = reference_world.basis.orthonormalized()
	var reference_inverse: Transform3D = reference_world.affine_inverse()
	var parents := PackedInt32Array()
	var parent_frames: Array[Transform3D] = []
	var rests: Array[Transform3D] = []
	for name: StringName in names:
		var index: int = skeleton.find_bone(name)
		if index < 0:
			return {"valid": false, "reason": "prepared_pose_bone_disappeared"}
		var parent_index: int = skeleton.get_bone_parent(index)
		var captured_parent: int = names.find(StringName(skeleton.get_bone_name(parent_index))) if parent_index >= 0 else -1
		parents.append(captured_parent)
		var parent_world: Transform3D = skeleton.global_transform
		if parent_index >= 0:
			parent_world *= skeleton.get_bone_global_pose(parent_index)
		parent_frames.append(reference_inverse * parent_world if captured_parent < 0 else Transform3D.IDENTITY)
		rests.append(skeleton.get_bone_rest(index))
	# Godot bone poses are already local parent-relative transforms. Rest is
	# retained as topology/provenance, never multiplied into the pose a second time.
	pose["schema_version"] = PreparedPose.SCHEMA_VERSION
	pose["attachment_required"] = true
	pose["capture_source"] = &"settled_editor_pose"
	pose["context_signature"] = context_signature
	pose["parent_indices"] = parents
	pose["parent_reference_transforms"] = parent_frames
	pose["bone_rest_transforms"] = rests
	pose["primary_hand_bone_name"] = primary_name
	pose["primary_hand_slot"] = dominant_slot
	pose["primary_hand_in_weapon"] = weapon.global_transform.affine_inverse() * skeleton.global_transform * skeleton.get_bone_global_pose(primary_index)
	pose["support_enabled"] = support_enabled
	pose["support_hand_bone_name"] = support_name
	pose["support_hand_slot"] = &"hand_right" if dominant_slot == &"hand_left" else &"hand_left"
	pose["support_hand_in_weapon"] = weapon.global_transform.affine_inverse() * skeleton.global_transform * skeleton.get_bone_global_pose(support_index) if support_index >= 0 else Transform3D.IDENTITY
	pose["arm_constraints_by_slot"] = capture_arm_constraints(actor, reference_world)
	pose["grip_accepted"] = false
	# Snapshot validity describes captured data, not a new contact certification.
	pose["valid"] = true
	var validation: Dictionary = PreparedPose.validate(pose, context_signature)
	if not validation.valid and require_validation:
		return validation
	if not require_validation:
		pose["capture_validation"] = validation
	return pose

## Read the existing rig contract for attachment preparation and verification.
## This does not initialize caches, solve an arm, or change the displayed pose.
## Missing helper neutrals remain unavailable; rest/current pose is no substitute.
static func capture_arm_constraints(actor: Node3D, reference_world: Transform3D) -> Dictionary:
	if not is_instance_valid(actor) or not _valid_transform(reference_world):
		return {}
	var skeleton: Skeleton3D = actor.get("skeleton") as Skeleton3D
	if skeleton == null or not actor.has_method("get_usable_arm_chain_reach_meters"):
		return {}
	var constants: Dictionary = {}
	var actor_script: Script = actor.get_script() as Script
	while actor_script != null:
		constants.merge(actor_script.get_script_constant_map(), false)
		actor_script = actor_script.get_base_script()
	for name: String in ["AUTHORING_JOINT_RANGE_EPSILON_DEGREES", "AUTHORING_LIMB_TWIST_LOCAL_AXIS", "AUTHORING_LIMB_TWIST_LIMIT_RADIANS"]:
		if not constants.has(name):
			return {}
	var properties: Dictionary = {}
	for property: Dictionary in actor.get_property_list():
		properties[String(property.name)] = true
	for name: String in ["authoring_shoulder_min_plane_angle_degrees", "authoring_shoulder_max_plane_angle_degrees", "authoring_elbow_min_plane_angle_degrees", "authoring_elbow_max_plane_angle_degrees", "authoring_limb_twist_neutral_rotation_lookup", "authoring_contact_wrist_twist_limit_degrees", "enable_authoring_contact_wrist_basis", "enable_authoring_limb_twist_distribution"]:
		if not properties.has(name):
			return {}
	var neutrals: Dictionary = actor.get("authoring_limb_twist_neutral_rotation_lookup") as Dictionary
	var reference_up: Vector3 = reference_world.basis.inverse() * actor.global_basis.y
	var result: Dictionary = {}
	for slot: StringName in [&"hand_right", &"hand_left"]:
		var prefix: String = "LEFT_" if slot == &"hand_left" else "RIGHT_"
		var packet: Dictionary = {
			"valid": true, "reason": "", "capture_source": &"live_rig_constraint_read",
			"slot_id": slot,
			"shoulder_min_degrees": actor.get("authoring_shoulder_min_plane_angle_degrees"),
			"shoulder_max_degrees": actor.get("authoring_shoulder_max_plane_angle_degrees"),
			"elbow_min_degrees": actor.get("authoring_elbow_min_plane_angle_degrees"),
			"elbow_max_degrees": actor.get("authoring_elbow_max_plane_angle_degrees"),
			"joint_epsilon_degrees": constants["AUTHORING_JOINT_RANGE_EPSILON_DEGREES"],
			"limb_twist_axis": constants["AUTHORING_LIMB_TWIST_LOCAL_AXIS"],
			"limb_twist_limit_radians": constants["AUTHORING_LIMB_TWIST_LIMIT_RADIANS"],
			"usable_reach_m": float(actor.call("get_usable_arm_chain_reach_meters", slot)),
			"reference_up": reference_up.normalized(),
			# The existing support-frame operation preserves accepted wrist twist;
			# this separate authoring clamp is recorded, not newly imposed here.
			"contact_wrist_twist_limit_degrees": actor.get("authoring_contact_wrist_twist_limit_degrees"),
			"contact_wrist_basis_enabled": actor.get("enable_authoring_contact_wrist_basis"),
			"limb_twist_distribution_enabled": actor.get("enable_authoring_limb_twist_distribution"),
		}
		var missing: Array[StringName] = []
		for role: String in ["clavicle", "upperarm", "forearm", "hand"]:
			var bone: StringName = StringName(constants.get(prefix + role.to_upper() + "_BONE", StringName()))
			packet[role + "_bone"] = bone
			if bone == StringName() or skeleton.find_bone(bone) < 0:
				missing.append(bone)
		var chains: Array = []
		var captured_neutrals: Dictionary = {}
		var missing_neutrals: Array[StringName] = []
		for role: String in ["FOREARM", "UPPERARM"]:
			var chain: Array = (constants.get(prefix + role + "_TWIST_BONES", []) as Array).duplicate()
			chains.append(chain)
			for bone: StringName in chain:
				if skeleton.find_bone(bone) < 0:
					continue
				if not neutrals.has(bone) or not (neutrals[bone] is Quaternion):
					missing_neutrals.append(bone)
				else:
					captured_neutrals[bone] = neutrals[bone]
		packet["twist_chains"] = chains
		packet["twist_neutral_rotations"] = captured_neutrals
		packet["missing_bones"] = missing
		packet["missing_twist_neutrals"] = missing_neutrals
		if not missing.is_empty() or not missing_neutrals.is_empty() or not reference_up.is_finite() or reference_up.length_squared() <= 0.00000001:
			packet["valid"] = false
			packet["reason"] = "arm_constraint_capture_incomplete"
		result[slot] = packet
	return result

## Durable constraint identity excludes the per-pose reference direction. Only
## dimensional/rotation round-trip noise is quantized; configured limits stay exact.
static func capture_arm_context_config(actor: Node3D) -> Dictionary:
	return arm_constraints_context_data(capture_arm_constraints(actor, Transform3D.IDENTITY))

static func arm_constraints_context_data(by_slot: Dictionary) -> Dictionary:
	var result: Dictionary = by_slot.duplicate(true)
	for packet: Dictionary in result.values():
		packet.erase("reference_up")
		if packet.has("usable_reach_m"):
			packet["usable_reach_m"] = snappedf(float(packet.usable_reach_m), 0.00001)
		var neutrals: Dictionary = packet.get("twist_neutral_rotations", {})
		for bone: Variant in neutrals:
			var rotation: Quaternion = neutrals[bone]
			if not rotation.is_finite() or rotation.length_squared() <= 0.000001:
				continue
			rotation = rotation.normalized()
			# q and -q describe the same rotation. Canonicalize before rounding.
			for component: float in [rotation.w, rotation.x, rotation.y, rotation.z]:
				if not is_zero_approx(component):
					if component < 0.0:
						rotation = -rotation
					break
			neutrals[bone] = Vector4(snappedf(rotation.x, 0.00001), snappedf(rotation.y, 0.00001), snappedf(rotation.z, 0.00001), snappedf(rotation.w, 0.00001))
	return result

static func _valid_transform(value: Transform3D) -> bool:
	return value.is_finite() and value.basis.determinant() > 0.000000000001
