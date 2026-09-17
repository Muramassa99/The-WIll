extends RefCounted
class_name CombatWeaponRollResolver

const CombatOriginRecordScript = preload("res://core/models/combat_origin_record.gd")
const CombatOriginRegistryScript = preload("res://core/resolvers/combat_origin_registry.gd")
const OWNER_SYSTEM: StringName = &"combat_weapon_roll_resolver"
const MIN_WRIST_TIP_DISTANCE_SQUARED: float = 0.000000000001

## Each request uses the same settled gesture capture and its actual weapon frame.
## The input capture stays unchanged. The returned registry describes the rotated
## EDITOR_PREVIEW frames, including their full basis and scale.
static func resolve(
		wrist_capture: Dictionary,
		weapon_transform_world: Transform3D,
		weapon_tip_local: Vector3,
		weapon_tip_origin_id: StringName,
		baseline_roll_degrees: float,
		requested_roll_degrees: float
	) -> Dictionary:
	if not bool(wrist_capture.get("available", false)):
		return _unavailable(&"unavailable_wrist_capture")
	if weapon_tip_origin_id != CombatOriginRecordScript.ORIGIN_WEAPON_ROOT:
		return _unavailable(&"invalid_weapon_tip_origin")
	if not weapon_tip_local.is_finite():
		return _unavailable(&"non_finite_weapon_tip")
	if not is_finite(baseline_roll_degrees) or not is_finite(requested_roll_degrees):
		return _unavailable(&"non_finite_roll_angle")
	var delta_radians: float = deg_to_rad(requested_roll_degrees - baseline_roll_degrees)
	if not is_finite(delta_radians):
		return _unavailable(&"non_finite_roll_delta")
	if not _valid_transform(weapon_transform_world):
		return _unavailable(&"invalid_weapon_world_transform")
	var source_registry = wrist_capture.get("registry")
	if not source_registry is CombatOriginRegistryScript:
		return _unavailable(&"missing_wrist_origin_registry")
	var wrist_origin_id: StringName = wrist_capture.get("wrist_origin_id", &"")
	if (
		wrist_origin_id != CombatOriginRecordScript.ORIGIN_RIGHT_WRIST
		and wrist_origin_id != CombatOriginRecordScript.ORIGIN_LEFT_WRIST
	):
		return _unavailable(&"invalid_wrist_origin_id")
	var chain_error: StringName = _origin_chain_error(
		source_registry, wrist_origin_id, CombatOriginRecordScript.PHASE_POST_FINAL_POSE
	)
	if chain_error != &"":
		return _unavailable(chain_error)
	var source_wrist_record = source_registry.get_origin(wrist_origin_id)
	if wrist_capture.get("origin_record") != source_wrist_record:
		return _unavailable(&"mismatched_wrist_origin_record")
	if (
		source_wrist_record.parent_origin_id != CombatOriginRecordScript.ORIGIN_RL_BONE_ROOT
		or source_wrist_record.space_type != CombatOriginRecordScript.SPACE_TYPE_BONE_FRAME
		or source_wrist_record.owner_system != &"player_humanoid_rig"
		or not source_wrist_record.is_dynamic
	):
		return _unavailable(&"invalid_wrist_origin_metadata")
	var expected_hand_bone: StringName = (
		&"CC_Base_R_Hand" if wrist_origin_id == CombatOriginRecordScript.ORIGIN_RIGHT_WRIST
		else &"CC_Base_L_Hand"
	)
	if wrist_capture.get("hand_bone_name") != expected_hand_bone:
		return _unavailable(&"mismatched_wrist_hand_bone")
	if not wrist_capture.get("machine_to_world") is Transform3D:
		return _unavailable(&"missing_machine_world_transform")
	var machine_to_world: Transform3D = wrist_capture["machine_to_world"]
	if not _valid_transform(machine_to_world):
		return _unavailable(&"invalid_machine_world_transform")
	var wrist_to_machine: Transform3D = source_registry.resolve_transform_to_machine(wrist_origin_id)
	if not source_wrist_record.resolved_transform_to_machine.is_equal_approx(wrist_to_machine):
		return _unavailable(&"stale_wrist_origin_transform")
	var hand_transform_world: Transform3D = machine_to_world * wrist_to_machine
	var world_to_machine: Transform3D = machine_to_world.affine_inverse()
	var weapon_to_machine: Transform3D = world_to_machine * weapon_transform_world
	if not _valid_transform(hand_transform_world) or not _valid_transform(weapon_to_machine):
		return _unavailable(&"invalid_resolved_source_transform")
	# Copy the validated source chain, never the mutable gesture registry itself.
	var registry = CombatOriginRegistryScript.new(false)
	var source_chain: Array = source_registry.resolve_chain(wrist_origin_id)
	source_chain.reverse()
	for source_record in source_chain:
		if not registry.register_origin(source_record):
			return _unavailable(&"source_origin_registration_failed")
	if not _register_frame(
		registry, weapon_tip_origin_id, weapon_to_machine,
		CombatOriginRecordScript.SPACE_TYPE_WEAPON, CombatOriginRecordScript.PHASE_POST_FINAL_POSE
	):
		return _unavailable(&"weapon_origin_registration_failed")
	chain_error = _origin_chain_error(
		registry, weapon_tip_origin_id, CombatOriginRecordScript.PHASE_POST_FINAL_POSE
	)
	if chain_error != &"":
		return _unavailable(chain_error)
	var registered_weapon_world: Transform3D = (
		machine_to_world * registry.resolve_transform_to_machine(weapon_tip_origin_id)
	)
	var tip_world: Vector3 = registered_weapon_world * weapon_tip_local
	var wrist_world: Vector3 = hand_transform_world.origin
	var wrist_to_tip_world: Vector3 = tip_world - wrist_world
	var axis_length_squared: float = wrist_to_tip_world.length_squared()
	if not tip_world.is_finite() or not is_finite(axis_length_squared):
		return _unavailable(&"non_finite_wrist_tip_axis")
	if axis_length_squared <= MIN_WRIST_TIP_DISTANCE_SQUARED:
		return _unavailable(&"degenerate_wrist_tip_axis")
	var rotation_world := Basis(wrist_to_tip_world.normalized(), delta_radians)
	var rolled_weapon_world := Transform3D(
		rotation_world * weapon_transform_world.basis,
		wrist_world + rotation_world * (weapon_transform_world.origin - wrist_world)
	)
	var rolled_hand_world := Transform3D(rotation_world * hand_transform_world.basis, wrist_world)
	var rolled_weapon_to_machine: Transform3D = world_to_machine * rolled_weapon_world
	var rolled_hand_to_machine: Transform3D = world_to_machine * rolled_hand_world
	if (
		not _valid_transform(rolled_weapon_world) or not _valid_transform(rolled_hand_world)
		or not _valid_transform(rolled_weapon_to_machine) or not _valid_transform(rolled_hand_to_machine)
	):
		return _unavailable(&"invalid_rolled_transform")
	# Output records belong to this editor manipulation, not to the captured pose.
	var output_root = registry.get_origin(CombatOriginRecordScript.ORIGIN_RL_BONE_ROOT).duplicate_record()
	output_root.owner_system = OWNER_SYSTEM
	output_root.resolve_phase = CombatOriginRecordScript.PHASE_EDITOR_PREVIEW
	if not registry.register_origin(output_root):
		return _unavailable(&"output_machine_origin_registration_failed")
	if not _register_frame(
		registry, wrist_origin_id, rolled_hand_to_machine,
		CombatOriginRecordScript.SPACE_TYPE_BONE_FRAME, CombatOriginRecordScript.PHASE_EDITOR_PREVIEW
	) or not _register_frame(
		registry, weapon_tip_origin_id, rolled_weapon_to_machine,
		CombatOriginRecordScript.SPACE_TYPE_WEAPON, CombatOriginRecordScript.PHASE_EDITOR_PREVIEW
	):
		return _unavailable(&"output_origin_registration_failed")
	for output_origin_id in [wrist_origin_id, weapon_tip_origin_id]:
		chain_error = _origin_chain_error(registry, output_origin_id, CombatOriginRecordScript.PHASE_EDITOR_PREVIEW)
		if chain_error != &"":
			return _unavailable(chain_error)
	return {
		"available": true,
		"reason": &"ok",
		"weapon_transform_world": rolled_weapon_world,
		"hand_transform_world": rolled_hand_world,
		"rotation_world": rotation_world,
		"wrist_origin_id": wrist_origin_id,
		"weapon_origin_id": weapon_tip_origin_id,
		"machine_to_world": machine_to_world,
		"registry": registry,
		"source_resolve_phase": CombatOriginRecordScript.PHASE_POST_FINAL_POSE,
		"resolve_phase": CombatOriginRecordScript.PHASE_EDITOR_PREVIEW,
	}

static func _origin_chain_error(registry, origin_id: StringName, resolve_phase: StringName) -> StringName:
	var validation: Dictionary = registry.validate_origin_chain(origin_id)
	if not bool(validation.get("ok", false)):
		return validation.get("reason", &"invalid_origin_chain")
	for record in registry.resolve_chain(origin_id):
		if not record is CombatOriginRecordScript:
			return &"invalid_origin_record"
		if record.resolve_phase != resolve_phase:
			return &"mismatched_origin_resolve_phase"
		if not _valid_transform(record.transform_to_parent) or not _valid_transform(record.resolved_transform_to_machine):
			return &"invalid_origin_transform"
		if record.is_machine_origin() and (
			record.parent_origin_id != &"" or record.space_type != CombatOriginRecordScript.SPACE_TYPE_MACHINE
			or record.transform_to_parent != Transform3D.IDENTITY
			or record.resolved_transform_to_machine != Transform3D.IDENTITY
		):
			return &"invalid_machine_origin_record"
	return &""

static func _register_frame(
		registry, origin_id: StringName, transform_to_machine: Transform3D,
		space_type: StringName, resolve_phase: StringName
	) -> bool:
	var record = CombatOriginRecordScript.new()
	record.origin_id = origin_id
	record.parent_origin_id = CombatOriginRecordScript.ORIGIN_RL_BONE_ROOT
	record.transform_to_parent = transform_to_machine
	record.owner_system = OWNER_SYSTEM
	record.resolve_phase = resolve_phase
	record.space_type = space_type
	record.is_dynamic = true
	return registry.register_origin(record)

static func _valid_transform(value: Transform3D) -> bool:
	if not value.basis.is_finite() or not value.origin.is_finite():
		return false
	var determinant: float = value.basis.determinant()
	return is_finite(determinant) and determinant != 0.0

static func _unavailable(reason: StringName) -> Dictionary:
	return {"available": false, "reason": reason}
