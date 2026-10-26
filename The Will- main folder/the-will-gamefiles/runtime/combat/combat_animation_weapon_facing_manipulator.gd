extends RefCounted
class_name CombatAnimationWeaponFacingManipulator

const Origin = preload("res://core/models/combat_origin_record.gd")
const PreparedPose = preload("res://core/models/combat_prepared_pose.gd")
const FrameSolver = preload("res://runtime/combat/combat_animation_weapon_frame_solver.gd")
const FRAME_PROPERTIES: Array[StringName] = [
	&"tip_position_local", &"tip_position_origin_id",
	&"pommel_position_local", &"pommel_position_origin_id",
	&"weapon_orientation_degrees", &"weapon_orientation_authored", &"weapon_roll_degrees",
]

## A weapon-only editor gesture. The caller suspends any active acquisition
## in the same event as begin, and idle acquisition before applying a change.
## It stays suspended until the user explicitly requests a new grip.
## This class never writes a bone, runs IK, or acquires a grip.
var _state: Dictionary = {}
var _frame_solver := FrameSolver.new()

func clear() -> void:
	_state.clear()

func begin(actor: Node3D, weapon: Node3D, trajectory: Node3D, motion: Resource, up_in_weapon: Vector3) -> Dictionary:
	clear()
	if not is_instance_valid(actor) or not is_instance_valid(weapon) or not is_instance_valid(trajectory) or motion == null:
		return _unavailable("missing_weapon_facing_context")
	var skeleton: Skeleton3D = actor.get("skeleton") as Skeleton3D
	if skeleton == null or not up_in_weapon.is_finite():
		return _unavailable("missing_weapon_facing_reference")
	var tip: Variant = weapon.get_meta("weapon_tip_local", null)
	var pommel: Variant = weapon.get_meta("weapon_pommel_local", null)
	if not tip is Vector3 or not pommel is Vector3:
		return _unavailable("missing_weapon_endpoints")
	if not (tip as Vector3).is_finite() or not (pommel as Vector3).is_finite():
		return _unavailable("invalid_weapon_endpoints")
	if StringName(weapon.get_meta("weapon_tip_origin_id", &"")) != Origin.ORIGIN_WEAPON_ROOT or StringName(weapon.get_meta("weapon_pommel_origin_id", &"")) != Origin.ORIGIN_WEAPON_ROOT:
		return _unavailable("invalid_weapon_endpoint_origins")
	var baseline: Transform3D = weapon.global_transform
	var tip_world: Vector3 = baseline * (tip as Vector3)
	var pommel_world: Vector3 = baseline * (pommel as Vector3)
	if not baseline.is_finite() or tip_world.distance_squared_to(pommel_world) <= 0.00000001:
		return _unavailable("missing_weapon_axis")
	var roll: float = float(motion.get("weapon_roll_degrees"))
	var preflight: Dictionary = _frame_solver.encode_transform_for_authoring(
		baseline, tip, pommel, up_in_weapon, trajectory.global_transform, roll, Origin.ORIGIN_WEAPON_ROOT
	)
	if not bool(preflight.get("available", false)):
		return preflight
	var bones: Array[Transform3D] = []
	for bone_index: int in skeleton.get_bone_count():
		bones.append(skeleton.get_bone_pose(bone_index))
	var baseline_properties: Dictionary = {}
	for property: StringName in FRAME_PROPERTIES:
		baseline_properties[property] = motion.get(property)
	_state = {
		"actor": actor, "weapon": weapon, "trajectory": trajectory, "motion": motion,
		"skeleton": skeleton, "skeleton_version": skeleton.get_version(),
		"skeleton_world": skeleton.global_transform, "bones": bones,
		"trajectory_world": trajectory.global_transform,
		"baseline_weapon_world": baseline, "last_weapon_world": baseline,
		"baseline_properties": baseline_properties, "roll_degrees": roll,
		"tip_in_weapon": tip, "pommel_in_weapon": pommel, "up_in_weapon": up_in_weapon,
		"axis_world": (tip_world - pommel_world).normalized(), "pivot_world": pommel_world,
		"expected_signature": PreparedPose.node_pose_signature(motion),
	}
	return {"available": true, "reason": "", "weapon_transform_world": baseline}

## Read-only retention check. An unrelated node, pose, or geometry edit ends the
## gesture; do not silently rebase it and turn a later pointer move into a jump.
func matches(actor: Node3D, weapon: Node3D, trajectory: Node3D, motion: Resource) -> bool:
	if _state.is_empty() or not is_instance_valid(actor) or not is_instance_valid(weapon) or not is_instance_valid(trajectory) or motion == null:
		return false
	if actor != _state.actor or weapon != _state.weapon or trajectory != _state.trajectory or motion != _state.motion:
		return false
	if PreparedPose.node_pose_signature(motion) != _state.expected_signature:
		return false
	if weapon.get_meta("weapon_tip_local", null) != _state.tip_in_weapon or weapon.get_meta("weapon_pommel_local", null) != _state.pommel_in_weapon:
		return false
	if StringName(weapon.get_meta("weapon_tip_origin_id", &"")) != Origin.ORIGIN_WEAPON_ROOT or StringName(weapon.get_meta("weapon_pommel_origin_id", &"")) != Origin.ORIGIN_WEAPON_ROOT:
		return false
	if not trajectory.global_transform.is_equal_approx(_state.trajectory_world) or not weapon.global_transform.is_equal_approx(_state.last_weapon_world):
		return false
	var skeleton: Skeleton3D = actor.get("skeleton") as Skeleton3D
	if skeleton != _state.skeleton or skeleton == null or skeleton.get_version() != _state.skeleton_version:
		return false
	if not skeleton.global_transform.is_equal_approx(_state.skeleton_world) or skeleton.get_bone_count() != _state.bones.size():
		return false
	for bone_index: int in skeleton.get_bone_count():
		if not skeleton.get_bone_pose(bone_index).is_equal_approx(_state.bones[bone_index]):
			return false
	return true

## delta_degrees is cumulative from begin(), with no turn limit. Only the final
## facing is authored; turns made while editing are not playback spin commands.
func apply_delta(actor: Node3D, weapon: Node3D, trajectory: Node3D, motion: Resource, delta_degrees: float) -> Dictionary:
	if not is_finite(delta_degrees):
		return _unavailable("invalid_weapon_facing_angle")
	if not matches(actor, weapon, trajectory, motion):
		return _unavailable("weapon_facing_context_changed")
	var baseline: Transform3D = _state.baseline_weapon_world
	var pivot: Vector3 = _state.pivot_world
	var rotation := Basis(_state.axis_world as Vector3, deg_to_rad(fposmod(delta_degrees, 360.0)))
	var target := Transform3D(rotation * baseline.basis, pivot + rotation * (baseline.origin - pivot))
	var encoded: Dictionary = _frame_solver.encode_transform_for_authoring(
		target, _state.tip_in_weapon, _state.pommel_in_weapon, _state.up_in_weapon,
		_state.trajectory_world, _state.roll_degrees, Origin.ORIGIN_WEAPON_ROOT
	)
	if not bool(encoded.get("available", false)):
		return encoded
	# A full return to the initial facing restores its exact authored values.
	if is_zero_approx(fposmod(delta_degrees, 360.0)):
		target = baseline
		for property: StringName in FRAME_PROPERTIES:
			encoded[property] = _state.baseline_properties[property]
	weapon.global_transform = target
	for property: StringName in FRAME_PROPERTIES:
		motion.set(property, encoded[property])
	_state.last_weapon_world = target
	_state.expected_signature = PreparedPose.node_pose_signature(motion)
	return {
		"available": true, "reason": "", "weapon_transform_world": target,
		"weapon_origin_id": Origin.ORIGIN_WEAPON_ROOT,
		"applied_delta_degrees": delta_degrees,
		"axis_world": _state.axis_world, "pivot_world": pivot,
		"weapon_roll_degrees": _state.roll_degrees,
	}

func _unavailable(reason: String) -> Dictionary:
	return {"available": false, "reason": reason}
