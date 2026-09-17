extends RefCounted
class_name CombatAnimationWeaponRollManipulator

const Origin = preload("res://core/models/combat_origin_record.gd")
const RollResolver = preload("res://core/resolvers/combat_weapon_roll_resolver.gd")
const FrameSolver = preload("res://runtime/combat/combat_animation_weapon_frame_solver.gd")

# One editor transaction. Source frames stay immutable until another operation
# changes its node, geometry, actor, weapon, presentation frame or non-Hand pose.
var _state: Dictionary = {}

func clear() -> void:
	_state.clear()

func matches(actor: Node3D, weapon: Node3D, trajectory: Node3D, motion: Resource, slot: StringName) -> bool:
	if not _state.has("expected_properties") or not is_instance_valid(actor) or not is_instance_valid(weapon) or trajectory == null or motion == null:
		return false
	if actor != _state["actor"] or weapon != _state["weapon"] or trajectory != _state["trajectory"] or slot != _state["slot"]:
		return false
	if weapon.get_meta("weapon_tip_local", null) != _state["tip_in_weapon"] or weapon.get_meta("weapon_pommel_local", null) != _state["pommel_in_weapon"]:
		return false
	if StringName(weapon.get_meta("weapon_tip_origin_id", &"")) != Origin.ORIGIN_WEAPON_ROOT or StringName(weapon.get_meta("weapon_pommel_origin_id", &"")) != Origin.ORIGIN_WEAPON_ROOT:
		return false
	if _properties(motion) != _state["expected_properties"] or not trajectory.global_transform.is_equal_approx(_state["trajectory_world"]):
		return false
	var skeleton: Skeleton3D = actor.get("skeleton") as Skeleton3D
	if skeleton == null or skeleton.get_version() != _state["skeleton_version"]:
		return false
	if not skeleton.global_transform.is_equal_approx(_state["skeleton_world"]):
		return false
	if not weapon.global_transform.is_equal_approx(_state["last_weapon_world"]):
		return false
	for bone_index: int in range(skeleton.get_bone_count()):
		if not skeleton.get_bone_pose(bone_index).is_equal_approx(_state["expected_bones"][bone_index]):
			return false
	return true

func apply(actor: Node3D, weapon: Node3D, trajectory: Node3D, motion: Resource, slot: StringName, up_in_weapon: Vector3, requested_degrees: float) -> Dictionary:
	if not is_finite(requested_degrees) or not up_in_weapon.is_finite():
		return {"available": false, "reason": "invalid_roll_input"}
	if not matches(actor, weapon, trajectory, motion, slot):
		clear()
		if actor == null or weapon == null or trajectory == null or motion == null:
			return {"available": false, "reason": "missing_roll_context"}
		var tip_value: Variant = weapon.get_meta("weapon_tip_local", null)
		var pommel_value: Variant = weapon.get_meta("weapon_pommel_local", null)
		if not tip_value is Vector3 or not pommel_value is Vector3:
			return {"available": false, "reason": "missing_weapon_endpoints"}
		if StringName(weapon.get_meta("weapon_tip_origin_id", &"")) != Origin.ORIGIN_WEAPON_ROOT or StringName(weapon.get_meta("weapon_pommel_origin_id", &"")) != Origin.ORIGIN_WEAPON_ROOT:
			return {"available": false, "reason": "invalid_weapon_endpoint_origins"}
		var capture: Dictionary = actor.call("capture_authoring_wrist_origin", slot)
		if not bool(capture.get("available", false)):
			return capture
		_state = {
			"actor": actor, "weapon": weapon, "trajectory": trajectory, "slot": slot,
			"capture": capture, "baseline_weapon_world": weapon.global_transform,
			"baseline_degrees": float(motion.get("weapon_roll_degrees")),
			"baseline_motion": motion.duplicate(true),
			"tip_in_weapon": tip_value, "pommel_in_weapon": pommel_value,
			"weapon_origin_id": Origin.ORIGIN_WEAPON_ROOT, "up_in_weapon": up_in_weapon,
			"trajectory_world": trajectory.global_transform,
		}
	# A geometry edit invalidates the interaction even if the resource ID survived.
	if weapon.get_meta("weapon_tip_local", null) != _state["tip_in_weapon"] or weapon.get_meta("weapon_pommel_local", null) != _state["pommel_in_weapon"] or not up_in_weapon.is_equal_approx(_state["up_in_weapon"]):
		clear()
		return {"available": false, "reason": "weapon_geometry_changed"}
	var requested: float = clampf(requested_degrees, -120.0, 120.0)
	var result: Dictionary = RollResolver.resolve(_state["capture"], _state["baseline_weapon_world"], _state["tip_in_weapon"], _state["weapon_origin_id"], _state["baseline_degrees"], requested)
	if not bool(result.get("available", false)):
		return result
	var encoded: Dictionary = _encode_motion(result, trajectory, motion, requested)
	if not bool(encoded.get("available", false)):
		return encoded
	# Validate the representation before either live writer runs. The rig writer
	# rejects/rolls back an unrepresentable Hand transform without changing its arm.
	if not bool(actor.call("apply_authoring_wrist_roll_pose", slot, result["hand_transform_world"])):
		return {"available": false, "reason": "wrist_pose_rejected"}
	weapon.global_transform = result["weapon_transform_world"]
	var candidate: Resource = encoded["motion"]
	for property_name: StringName in [&"tip_position_local", &"tip_position_origin_id", &"pommel_position_local", &"pommel_position_origin_id", &"weapon_orientation_degrees", &"weapon_orientation_authored", &"weapon_roll_degrees"]:
		motion.set(property_name, candidate.get(property_name))
	var skeleton: Skeleton3D = actor.get("skeleton") as Skeleton3D
	var bones: Array[Transform3D] = []
	for bone_index: int in range(skeleton.get_bone_count()):
		bones.append(skeleton.get_bone_pose(bone_index))
	_state["expected_bones"] = bones
	_state["expected_properties"] = _properties(motion)
	_state["skeleton_version"] = skeleton.get_version()
	_state["skeleton_world"] = skeleton.global_transform
	_state["last_weapon_world"] = weapon.global_transform
	_state["result"] = result
	return result

func _encode_motion(result: Dictionary, trajectory: Node3D, motion: Resource, degrees: float) -> Dictionary:
	var target: Transform3D = result["weapon_transform_world"]
	var tip_in_weapon: Vector3 = _state["tip_in_weapon"]
	var pommel_in_weapon: Vector3 = _state["pommel_in_weapon"]
	var weapon_origin_id: StringName = Origin.ORIGIN_WEAPON_ROOT
	if tip_in_weapon.distance_squared_to(pommel_in_weapon) <= 0.00000001 or not trajectory.global_transform.is_finite() or absf(trajectory.global_basis.determinant()) < 0.00000001:
		return {"available": false, "reason": "invalid_authoring_frame"}
	var solver = FrameSolver.new()
	var intrinsic: Basis = solver.call("_build_basis_from_axis_and_up", (tip_in_weapon - pommel_in_weapon).normalized(), _state["up_in_weapon"])
	var output_basis: Basis = target.basis * intrinsic
	var unrolled_up_world: Vector3 = output_basis.y.rotated(output_basis.z.normalized(), -deg_to_rad(degrees))
	var up_in_trajectory: Vector3 = trajectory.global_basis.inverse() * unrolled_up_world
	var candidate: Resource = motion.duplicate(true)
	candidate.set("tip_position_local", trajectory.to_local(target * tip_in_weapon))
	candidate.set("pommel_position_local", trajectory.to_local(target * pommel_in_weapon))
	candidate.set("tip_position_origin_id", Origin.ORIGIN_TRAJECTORY_AUTHORING)
	candidate.set("pommel_position_origin_id", Origin.ORIGIN_TRAJECTORY_AUTHORING)
	candidate.set("weapon_orientation_degrees", Quaternion(Vector3.UP, up_in_trajectory.normalized()).get_euler() * (180.0 / PI))
	candidate.set("weapon_orientation_authored", true)
	candidate.set("weapon_roll_degrees", degrees)
	candidate.call("normalize")
	var reconstructed: Transform3D = solver.solve_transform_from_segment(tip_in_weapon, pommel_in_weapon, trajectory.to_global(candidate.get("tip_position_local")), trajectory.to_global(candidate.get("pommel_position_local")), _state["up_in_weapon"], trajectory.global_basis, candidate.get("weapon_orientation_degrees"), candidate.get("weapon_roll_degrees"), weapon_origin_id, weapon_origin_id, weapon_origin_id)
	if not reconstructed.is_equal_approx(target) or (reconstructed * tip_in_weapon).distance_to(target * tip_in_weapon) > 0.00001 or (reconstructed * pommel_in_weapon).distance_to(target * pommel_in_weapon) > 0.00001:
		return {"available": false, "reason": "authored_frame_roundtrip_failed"}
	# Returning to the captured starting angle restores its exact authored values.
	# The initial mounted pose can intentionally differ from its abstract seed.
	if is_equal_approx(degrees, _state["baseline_degrees"]):
		candidate = _state["baseline_motion"].duplicate(true)
	var trajectory_record = Origin.new()
	trajectory_record.origin_id = Origin.ORIGIN_TRAJECTORY_AUTHORING
	trajectory_record.parent_origin_id = Origin.ORIGIN_RL_BONE_ROOT
	trajectory_record.transform_to_parent = result["machine_to_world"].affine_inverse() * trajectory.global_transform
	trajectory_record.owner_system = &"combat_animation_weapon_roll_manipulator"
	trajectory_record.resolve_phase = Origin.PHASE_EDITOR_PREVIEW
	trajectory_record.space_type = Origin.SPACE_TYPE_TRAJECTORY
	trajectory_record.is_dynamic = true
	if not result["registry"].register_origin(trajectory_record) or not bool(result["registry"].validate_origin_chain(trajectory_record.origin_id).get("ok", false)):
		return {"available": false, "reason": "trajectory_origin_registration_failed"}
	return {"available": true, "motion": candidate}

func _properties(motion: Resource) -> Dictionary:
	var values: Dictionary = {}
	for property: Dictionary in motion.get_property_list():
		if int(property["usage"]) & PROPERTY_USAGE_STORAGE and String(property["name"]) != "script":
			values[property["name"]] = motion.get(property["name"])
	return values
