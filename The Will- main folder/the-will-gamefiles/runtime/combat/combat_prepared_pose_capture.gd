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
	context_signature: String = ""
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
	pose["capture_source"] = &"settled_editor_pose"
	pose["context_signature"] = context_signature
	pose["parent_indices"] = parents
	pose["parent_reference_transforms"] = parent_frames
	pose["bone_rest_transforms"] = rests
	pose["primary_hand_bone_name"] = primary_name
	pose["primary_hand_in_weapon"] = weapon.global_transform.affine_inverse() * skeleton.global_transform * skeleton.get_bone_global_pose(primary_index)
	pose["support_enabled"] = support_enabled
	pose["support_hand_bone_name"] = support_name
	pose["support_hand_in_weapon"] = weapon.global_transform.affine_inverse() * skeleton.global_transform * skeleton.get_bone_global_pose(support_index) if support_index >= 0 else Transform3D.IDENTITY
	pose["grip_accepted"] = false
	# Snapshot validity describes captured data, not a new contact certification.
	pose["valid"] = true
	var validation: Dictionary = PreparedPose.validate(pose, context_signature)
	if not validation.valid:
		return validation
	return pose

static func _valid_transform(value: Transform3D) -> bool:
	return value.is_finite() and value.basis.determinant() > 0.000000000001
