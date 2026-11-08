extends RefCounted

## Editor adapter: one accepted body/weapon transaction, not another IK owner.
## All external positions are World; landmarks are explicitly WeaponRoot local.
const Origin = preload("res://core/models/combat_origin_record.gd")
const Pose = preload("res://core/models/combat_prepared_pose.gd")
const Frame = preload("res://runtime/combat/combat_animation_weapon_frame_solver.gd")
var _state: Dictionary = {}

func clear() -> void:
	var actor: Node3D = _state.get("actor")
	if is_instance_valid(actor) and actor.has_method("clear_authoring_weapon_motion_authority"):
		actor.call("clear_authoring_weapon_motion_authority")
	_state.clear()

func capture_state() -> Dictionary:
	return _state.duplicate(true)

func restore_state(state: Dictionary) -> void:
	_state = state.duplicate(true)

func matches(context: Dictionary, motion: Resource) -> bool:
	if motion == null or not _matches_scene(context):
		return false
	if motion.get("node_id") != _state.node_id or Pose.node_pose_signature(motion) != _state.signature:
		return false
	return true

func owns_current_scene(actor: Node, weapon: Node3D) -> bool:
	if _state.is_empty() or not is_instance_valid(actor) or not is_instance_valid(weapon):
		return false
	return _matches_scene({"actor": actor, "weapon": weapon, "trajectory": _state.trajectory})

func _matches_scene(context: Dictionary) -> bool:
	if _state.is_empty() or context.is_empty():
		return false
	if context.actor != _state.actor or context.weapon != _state.weapon or context.trajectory != _state.trajectory:
		return false
	if not context.trajectory.global_transform.is_equal_approx(_state.trajectory_world):
		return false
	if not context.weapon.global_transform.is_equal_approx(_state.weapon_world):
		return false
	var skeleton: Skeleton3D = context.actor.get("skeleton") as Skeleton3D
	if skeleton == null or skeleton.get_version() != _state.skeleton_version or not skeleton.global_transform.is_equal_approx(_state.skeleton_world):
		return false
	if context.weapon.get_meta("weapon_tip_local", null) != _state.tip_local or context.weapon.get_meta("weapon_pommel_local", null) != _state.pommel_local:
		return false
	return bool(context.actor.call("has_authoring_weapon_motion_authority"))

func apply(context: Dictionary, motion: Resource, mode: StringName,
		target_world: Transform3D, contact_local: Vector3, up_local: Vector3,
		primary_slot: StringName, support_slot: StringName, validate_pose: Callable,
		requested_roll: float) -> Dictionary:
	var actor: Node3D = context.actor
	var weapon: Node3D = context.weapon
	var trajectory: Node3D = context.trajectory
	if not actor.has_method("allocate_authoring_weapon_motion"):
		return {"available": false, "reason": "weapon_motion_allocator_unavailable"}
	var tip: Variant = weapon.get_meta("weapon_tip_local", null)
	var pommel: Variant = weapon.get_meta("weapon_pommel_local", null)
	if not tip is Vector3 or not pommel is Vector3 or StringName(weapon.get_meta("weapon_tip_origin_id", &"")) != Origin.ORIGIN_WEAPON_ROOT or StringName(weapon.get_meta("weapon_pommel_origin_id", &"")) != Origin.ORIGIN_WEAPON_ROOT:
		return {"available": false, "reason": "weapon_motion_landmark_origin_invalid"}
	var contact_anchor_world: Vector3 = weapon.global_transform * contact_local
	if mode == &"roll":
		# Keep the mode-entry pivot, not each accepted frame's tiny residual.
		# Display baselines can re-encode endpoint fields, so identify the accepted
		# scene/node here rather than comparing their numeric pose signature.
		if _matches_scene(context) and motion.get("node_id") == _state.node_id and _state.get("mode") == mode and _state.get("contact_local") == contact_local:
			contact_anchor_world = _state.contact_anchor_world
		target_world.origin = contact_anchor_world - target_world.basis * contact_local
	var request: Dictionary = {"mode": mode, "weapon": weapon,
		"previous_weapon": weapon.global_transform, "target_weapon": target_world,
		"contact_local": contact_local, "primary_slot": primary_slot,
		"support_slot": support_slot, "validate_pose": validate_pose, "commit": false}
	# The requested landmark and acquired handle station have different jobs.
	# Pommel follows the pointer while the rigid weapon may rotate with the arm.
	if mode == &"pommel":
		request["task_point_local"] = pommel
		request["trailing_tip_local"] = tip
	# Tip requests orientation with a freely travelling grip. Only attached Roll
	# retains a world-space contact pivot; the acquired grip itself stays rigid.
	if mode == &"roll":
		request["contact_anchor_world"] = contact_anchor_world
	var acquired: Dictionary = {}
	for slot: StringName in [primary_slot, support_slot]:
		if slot == &"":
			continue
		var binding: Dictionary = actor.planar_grip_pose_binding.relationship(slot, weapon)
		if binding.get("hand_in_weapon") is Transform3D:
			acquired[slot] = binding.hand_in_weapon
	request["hand_in_weapon_by_slot"] = acquired
	var result: Dictionary = actor.call("allocate_authoring_weapon_motion", request)
	if result.get("status", &"") not in [&"ACCEPTED", &"SCALED"] or not result.get("accepted_weapon") is Transform3D:
		result["available"] = false
		return result
	var accepted_roll: float = float(motion.get("weapon_roll_degrees"))
	if mode == &"roll":
		accepted_roll = lerpf(accepted_roll, requested_roll, clampf(float(result.get("task_scale", 0.0)), 0.0, 1.0))
	var encoded: Dictionary = Frame.new().encode_transform_for_authoring(result.accepted_weapon,
		tip, pommel, up_local, trajectory.global_transform, accepted_roll, Origin.ORIGIN_WEAPON_ROOT)
	if not encoded.get("available", false):
		return encoded
	# Encoding is checked before commit. The adapter commits the exact evaluated
	# transaction; it must not run a second solve with a potentially different result.
	if not actor.has_method("commit_authoring_weapon_motion"):
		return {"available": false, "reason": "weapon_motion_commit_rejected"}
	if not bool(actor.call("commit_authoring_weapon_motion", result)):
		# Keep the storage/readback diagnosis with the rejected transaction. The
		# previous accepted pose and ownership remain in place after rollback.
		result["available"] = false
		if str(result.get("reason", "")).is_empty():
			result["reason"] = "weapon_motion_commit_rejected"
		return result
	var candidate: Resource = motion.duplicate(true)
	for key: StringName in [&"tip_position_local", &"tip_position_origin_id", &"pommel_position_local", &"pommel_position_origin_id", &"weapon_orientation_degrees", &"weapon_orientation_authored", &"weapon_roll_degrees"]:
		candidate.set(key, encoded[key])
	candidate.call("normalize")
	var skeleton: Skeleton3D = actor.get("skeleton") as Skeleton3D
	_state = {"actor": actor, "weapon": weapon, "trajectory": trajectory,
		"mode": mode, "contact_local": contact_local, "contact_anchor_world": result.get("contact_anchor", weapon.global_transform * contact_local),
		"signature": Pose.node_pose_signature(candidate), "node_id": candidate.get("node_id"), "trajectory_world": trajectory.global_transform,
		"weapon_world": weapon.global_transform, "skeleton_world": skeleton.global_transform,
		"skeleton_version": skeleton.get_version(), "tip_local": tip, "pommel_local": pommel}
	encoded["legal"] = true
	encoded["motion_allocated"] = true
	encoded["allocation"] = result
	return encoded
