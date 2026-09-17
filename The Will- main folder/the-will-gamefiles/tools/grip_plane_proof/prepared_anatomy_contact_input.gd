extends RefCounted

const Store = preload("res://tools/grip_plane_proof/character_hand_anatomy_store.gd")
const Origins = preload("res://core/models/combat_origin_record.gd")
const Registry = preload("res://core/resolvers/combat_origin_registry.gd")
const Spatial = preload("res://runtime/player/player_finger_surface_grip_solver.gd")

## Adapter for immutable character anatomy and one frozen grip-input capture.
## Only the hand placement comes from the capture. Dimensions, relative frames,
## calibrated zero and declared limits come from the prepared character.
func build(definition: Resource, capture: Dictionary, digit_id: StringName) -> Dictionary:
	var frame: Dictionary = capture.get("capture_frame", {})
	var source: Dictionary = capture.get("digits", {}).get(digit_id, {}).get("snapshot", {})
	if frame.get("machine_origin_id") != &"RL_BoneRoot" or source.get("bone_root_origin_id") != &"RL_BoneRoot":
		return _fail("missing_captured_machine_origin")
	if not frame.get("machine_to_world") is Transform3D or not source.get("root_parent_world") is Transform3D:
		return _fail("missing_captured_hand_or_machine_frame")
	var machine: Transform3D = frame["machine_to_world"]
	var hand: Transform3D = source["root_parent_world"]
	if not _valid_frame(machine) or not _valid_frame(hand):
		return _fail("invalid_captured_hand_or_machine_frame")
	var digit: Dictionary = {}
	for entry: Dictionary in definition.digits:
		if entry.digit_id == digit_id and entry.slot_id == StringName(capture.get("slot", "")):
			digit = entry
	if digit.is_empty() or digit.bone_names != source.get("bone_names", []):
		return _fail("prepared_digit_does_not_match_capture")
	var saved: Dictionary = Store.new()._validate_origins(definition.origin_records)
	if not bool(saved.get("valid", false)):
		return _fail("invalid_saved_origin_chain")
	var reference_hand: Transform3D = saved.registry.resolve_transform_to_machine(digit.hand_bone_name)
	var plane: Transform3D = hand * reference_hand.affine_inverse() * digit.plane_to_machine
	# A changed character metric requires preparation again. Do not silently
	# normalize away scale/shear and continue using obsolete measurements.
	if not _metric_plane(plane):
		return _fail("captured_character_metric_does_not_match_prepared_plane")
	# Affine ancestry accumulates Float32 round-off. After the metric check above,
	# create unit measurement axes only; keep the captured hand/FK affine frames
	# unchanged and verify their physical lengths below. Record this correction.
	var raw_plane_basis := plane.basis
	plane.basis = plane.basis.orthonormalized()
	var metric_axis_correction := maxf((raw_plane_basis.x - plane.basis.x).length(), maxf((raw_plane_basis.y - plane.basis.y).length(), (raw_plane_basis.z - plane.basis.z).length()))
	var hand_id := StringName(String(digit.hand_bone_name) + "PreparedContactHandOrigin")
	var plane_id := StringName(String(digit.bone_names[0]) + "PreparedContactPlaneOrigin")
	var registry = Registry.new()
	var hand_record = _record(hand_id, &"RL_BoneRoot", machine.affine_inverse() * hand)
	var plane_record = _record(plane_id, hand_id, hand.affine_inverse() * plane)
	if not registry.register_origin(hand_record) or not registry.register_origin(plane_record) or not bool(registry.validate_origin_chain(plane_id).get("ok", false)):
		return _fail("contact_input_origin_registration_failed")
	var snapshot := {"valid": true, "digit_id": digit_id, "bone_root_origin_id": &"RL_BoneRoot",
		"bone_names": digit.bone_names.duplicate(), "root_parent_world": hand, "root_parent_origin_id": hand_id,
		"relative_transforms": digit.rest_relative_transforms.duplicate(true), "relative_transform_origin_ids": digit.relative_transform_origin_ids.duplicate(),
		"neutral_local_rotations": digit.neutral_local_rotations.duplicate(), "neutral_local_rotation_origin_ids": digit.neutral_local_rotation_origin_ids.duplicate(),
		"hinge_axes_local": digit.hinge_axes_local.duplicate(), "hinge_axis_origin_ids": digit.hinge_axis_origin_ids.duplicate(),
		"min_angles_rad": digit.min_angles_rad.duplicate(), "max_angles_rad": digit.max_angles_rad.duplicate(), "preferred_angles_rad": digit.preferred_angles_rad.duplicate(),
		"tip_offset_local": digit.terminal_skin_offset_local, "tip_offset_origin_id": digit.terminal_skin_offset_origin_id}
	var zero: Dictionary = Spatial.new()._forward_kinematics(snapshot, [0.0, 0.0, 0.0])
	var length_error := 0.0
	for i: int in range(2):
		length_error = maxf(length_error, absf((zero.joint_origins_world[i] as Vector3).distance_to(zero.joint_origins_world[i + 1]) - float(digit.section_lengths_m[i])))
	if length_error > 0.000002 or (plane.origin - zero.joint_origins_world[0]).length() > 0.000002:
		return _fail("prepared_dimensions_or_plane_fail_capture_round_trip")
	return {"valid": true, "snapshot": snapshot, "digit": digit, "reference_skin": definition.reference_skin,
		"context": {"machine_origin_id": &"RL_BoneRoot", "machine_to_world": machine, "resolve_phase": &"editor_preview", "hand_bone_name": digit.hand_bone_name},
		"plane_to_world": plane, "plane_origin_id": plane_id, "registry": registry,
		"origin_records": [_serialize(hand_record), _serialize(plane_record)], "origin_chain": registry.validate_origin_chain(plane_id),
		"section_length_round_trip_error_m": length_error, "anatomy_recomputed": false,
		"metric_axis_roundoff_correction": metric_axis_correction,
		"source_signature": definition.source_signature, "other_bones_use_hand_rebased_rest": true}

func _record(id: StringName, parent: StringName, transform: Transform3D) -> Resource:
	var value = Origins.new()
	value.origin_id = id
	value.parent_origin_id = parent
	value.transform_to_parent = transform
	value.owner_system = &"prepared_anatomy_contact_input"
	value.resolve_phase = &"editor_preview"
	value.space_type = &"bone_frame"
	value.is_dynamic = true
	return value

func _serialize(record: Resource) -> Dictionary:
	return {"origin_id": record.origin_id, "parent_origin_id": record.parent_origin_id,
		"transform_to_parent": record.transform_to_parent, "owner_system": record.owner_system,
		"resolve_phase": record.resolve_phase, "space_type": record.space_type, "is_dynamic": record.is_dynamic}

func _valid_frame(value: Transform3D) -> bool:
	return value.is_finite() and absf(value.basis.determinant()) > 1.0e-12

func _metric_plane(value: Transform3D) -> bool:
	return _valid_frame(value) and value.basis.is_equal_approx(value.basis.orthonormalized()) and value.basis.determinant() > 0.99999

func _fail(reason: String) -> Dictionary:
	return {"valid": false, "reason": reason}
