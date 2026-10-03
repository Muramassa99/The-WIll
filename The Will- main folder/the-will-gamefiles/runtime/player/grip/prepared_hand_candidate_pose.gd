extends RefCounted

const HandSkin = preload("res://runtime/player/grip/prepared_hand_skin_query.gd")
const Adapter = preload("res://runtime/player/grip/prepared_anatomy_contact_input.gd")
const Spatial = preload("res://runtime/player/player_finger_surface_grip_solver.gd")
const ROOT: StringName = &"RL_BoneRoot"
const REVISION: StringName = &"prepared_hand_candidate_pose_v1"
const OWNER: StringName = &"prepared_hand_candidate_pose"
const DIMENSION_SCALE_GUARD: float = 0.000005

# Offline candidate articulation/placement only. The caller freezes the weapon
# AFTER its upstream authored placement; this tool does not handle station edits.
# Only explicitly selected digits use prepared anatomy's calibrated FK. Every
# other bone retains its captured articulation, including all skin contributors.
func prepare(definition: Resource, coherent_packet: Dictionary, slot: StringName, digit_ids: Array) -> Dictionary:
	var started: int = Time.get_ticks_usec()
	if definition == null or slot not in [&"hand_right", &"hand_left"] or digit_ids.is_empty():
		return _fail("missing_character_slot_or_selected_digits")
	var signature: Variant = definition.get("source_signature")
	var reference: Variant = definition.get("reference_skin")
	if not signature is String or not reference is Dictionary:
		return _fail("missing_prepared_character_data")
	var skin: RefCounted = HandSkin.new()
	var skin_prepared: Dictionary = skin.prepare(reference, signature)
	if not bool(skin_prepared.get("valid", false)):
		return skin_prepared
	var base: Dictionary = skin.pose(skin_prepared, coherent_packet)
	if not bool(base.get("valid", false)):
		return base
	if coherent_packet.get("resolve_phase") != &"editor_preview" or not coherent_packet.get("source_bone_parent_ids") is Dictionary:
		return _fail("candidate_requires_editor_capture_with_source_hierarchy")
	if coherent_packet.has("digit_dimension_reference") and not coherent_packet.digit_dimension_reference is Dictionary:
		return _fail("invalid_frozen_digit_dimension_reference")
	var parents: Dictionary = coherent_packet.source_bone_parent_ids
	var registered: Dictionary = skin._registry(coherent_packet.origin_records, coherent_packet.resolve_phase)
	var registry: RefCounted = registered.registry
	var frames: Dictionary = {}
	for name: Variant in coherent_packet.bone_origin_ids:
		frames[StringName(name)] = registry.resolve_transform_to_machine(StringName(coherent_packet.bone_origin_ids[name]))
	var hand_name: StringName = StringName()
	for entry: Dictionary in definition.get("digits"):
		if entry.get("slot_id") == slot and digit_ids.has(entry.get("digit_id")):
			var candidate_hand: StringName = StringName(entry.get("hand_bone_name", StringName()))
			if hand_name != StringName() and hand_name != candidate_hand:
				return _fail("selected_digits_disagree_on_character_hand")
			hand_name = candidate_hand
	if not frames.has(hand_name):
		return _fail("missing_current_hand")
	# Source skeleton ancestry differs from flattened origin-record ancestry.
	# Missing intermediate bones reject; no guessed ancestry or rest fallback.
	var descendants: Dictionary = {}
	for name: Variant in frames:
		var ancestry: Dictionary = _ancestry(StringName(name), parents)
		if not bool(ancestry.valid):
			return ancestry
		if ancestry.chain.has(hand_name):
			descendants[StringName(name)] = true
	var hand_world: Transform3D = coherent_packet.machine_to_world * (frames[hand_name] as Transform3D)
	var inputs: Dictionary = {}
	var selected_bones: Dictionary = {}
	for raw_id: Variant in digit_ids:
		if not (raw_id is String or raw_id is StringName):
			return _fail("invalid_selected_digit_id")
		var id: StringName = StringName(raw_id)
		if inputs.has(id):
			return _fail("duplicate_selected_digit")
		var digit: Dictionary = {}
		for entry: Dictionary in definition.get("digits"):
			if entry.slot_id == slot and entry.digit_id == id:
				digit = entry
		if digit.is_empty() or digit.get("hand_bone_name") != hand_name:
			return _fail("missing_matching_prepared_digit")
		var expected_parent: StringName = hand_name
		for name: StringName in digit.bone_names:
			if not frames.has(name) or not descendants.has(name) or parents.get(name) != expected_parent or selected_bones.has(name):
				return _fail("selected_digit_does_not_match_captured_serial_chain")
			selected_bones[name] = true
			expected_parent = name
		var source: Dictionary = {"slot": slot,
			"capture_frame": {"machine_origin_id": ROOT, "machine_to_world": coherent_packet.machine_to_world},
			"digits": {id: {"snapshot": {"bone_root_origin_id": ROOT, "bone_names": digit.bone_names, "root_parent_world": hand_world}}}}
		var input: Dictionary = Adapter.new().build(definition, source, id)
		if not bool(input.get("valid", false)):
			return input
		if coherent_packet.has("digit_dimension_reference"):
			var dimensions: Dictionary = _apply_dimension_reference(input, coherent_packet, frames, hand_name)
			if not bool(dimensions.get("valid", false)):
				return dimensions
		input.erase("registry")
		input["other_bones_use_hand_rebased_rest"] = false
		inputs[id] = input
	var mesh: Transform3D = base.mesh_to_machine
	var constants: PackedVector3Array = PackedVector3Array()
	var affected: PackedInt32Array = PackedInt32Array()
	var dynamic_offsets: PackedInt32Array = PackedInt32Array([0])
	var dynamic_slots: PackedInt32Array = PackedInt32Array()
	var bind_frames: Array[Transform3D] = []
	for name: StringName in skin_prepared.bind_bone_names:
		if not frames.has(name):
			return _fail("candidate_requires_all_captured_bind_frames")
		bind_frames.append(frames[name])
	for vertex: int in range(skin_prepared.vertex_count):
		var point: Vector3 = mesh.origin * float(skin_prepared.residual_weights[vertex])
		var moving_slots: PackedInt32Array = PackedInt32Array()
		for influence: int in range(skin_prepared.vertex_offsets[vertex], skin_prepared.vertex_offsets[vertex + 1]):
			var bind: int = skin_prepared.influence_binds[influence]
			if descendants.has(skin_prepared.bind_bone_names[bind]):
				moving_slots.append(influence)
			else:
				point += bind_frames[bind].basis * (skin_prepared.weighted_bind_points[influence] as Vector3) + bind_frames[bind].origin * float(skin_prepared.influence_weights[influence])
		if not moving_slots.is_empty():
			affected.append(vertex)
			constants.append(point)
			dynamic_slots.append_array(moving_slots)
			dynamic_offsets.append(dynamic_slots.size())
	return {"valid": true, "revision": REVISION, "anatomy_signature": signature,
		"slot": slot, "hand_bone_name": hand_name, "descendant_bones": descendants,
		"source_parent_ids": parents.duplicate(true), "base_frames": frames,
		"base_packet": coherent_packet.duplicate(true), "base_pose": base,
		"baseline_hand_to_world": hand_world, "digit_inputs": inputs,
		"selected_bones": selected_bones, "skin_prepared": skin_prepared,
		"affected_vertex_ids": affected, "fixed_contributions_machine": constants,
		"dynamic_offsets": dynamic_offsets, "dynamic_influence_slots": dynamic_slots,
		"angle_convention": &"absolute_prepared_calibrated_hinges_zero_is_not_captured_pose",
		"preparation_ms": float(Time.get_ticks_usec() - started) / 1000.0,
		"arm_realization_verified": false, "actual_3d_grip_verified": false}


## Only an explicitly frozen acquisition reference can change dimensions. A
## later observed pose must reuse that reference; reading its current positions
## here would make the observed articulation check agree with itself by design.
## Prepared zero rotations, hinge axes, limits and measured skin stay untouched.
func _apply_dimension_reference(input: Dictionary, packet: Dictionary, frames: Dictionary, hand_name: StringName) -> Dictionary:
	var reference: Dictionary = packet.digit_dimension_reference
	var snapshot: Dictionary = input.snapshot
	var changes: Array[Dictionary] = []
	var parent_name: StringName = hand_name
	for joint: int in range(3):
		var name: StringName = snapshot.bone_names[joint]
		var raw: Variant = reference.get(name)
		if not raw is Dictionary or not raw.get("local_transform") is Transform3D:
			return _fail("missing_frozen_digit_local_transform", {"bone_name": name})
		var observed: Dictionary = raw
		var parent_id: StringName = StringName(packet.bone_origin_ids.get(parent_name, StringName()))
		if parent_id == StringName() or observed.get("parent_bone_name") != parent_name or observed.get("parent_origin_id") != parent_id or snapshot.relative_transform_origin_ids[joint] != parent_name:
			return _fail("frozen_digit_dimension_parent_mismatch", {"bone_name": name, "expected_parent_bone_name": parent_name, "expected_parent_origin_id": parent_id})
		var local_transform: Transform3D = observed.local_transform
		var relative: Transform3D = snapshot.relative_transforms[joint]
		if not local_transform.is_finite() or not is_finite(local_transform.basis.determinant()) or local_transform.basis.determinant() <= 1.0e-12:
			return _fail("invalid_frozen_digit_local_transform", {"bone_name": name})
		var scale_error: float = local_transform.basis.get_scale().distance_to(relative.basis.get_scale())
		if not is_finite(scale_error) or scale_error > DIMENSION_SCALE_GUARD:
			return _fail("frozen_digit_metric_requires_anatomy_preparation", {"bone_name": name, "scale_error": scale_error, "scale_guard": DIMENSION_SCALE_GUARD})
		var local_delta: Vector3 = local_transform.origin - relative.origin
		var parent_world: Transform3D = packet.machine_to_world * (frames[parent_name] as Transform3D)
		changes.append({"bone_name": name, "parent_bone_name": parent_name, "parent_origin_id": parent_id,
			"prepared_rest_origin_parent_local": relative.origin, "frozen_origin_parent_local": local_transform.origin,
			"origin_delta_parent_local": local_delta, "origin_delta_world_m": (parent_world.basis * local_delta).length(),
			"scale_error": scale_error, "scale_guard": DIMENSION_SCALE_GUARD,
			"prepared_basis_retained": true})
		relative.origin = local_transform.origin
		snapshot.relative_transforms[joint] = relative
		parent_name = name
	var zero: Dictionary = Spatial.new()._forward_kinematics(snapshot, [0.0, 0.0, 0.0])
	for frame: Transform3D in zero.joint_transforms_world:
		if not frame.is_finite():
			return _fail("nonfinite_frozen_dimension_forward_kinematics")
	# The section plane keeps its prepared orientation but begins at the actual
	# first joint. Update both the convenience frame and its named origin record.
	var plane: Transform3D = input.plane_to_world
	var prepared_plane_origin: Vector3 = plane.origin
	plane.origin = zero.joint_origins_world[0]
	var registry: RefCounted = input.registry
	var plane_record: Resource = registry.get_origin(input.plane_origin_id)
	if plane_record == null:
		return _fail("missing_frozen_dimension_plane_origin")
	plane_record.transform_to_parent = (snapshot.root_parent_world as Transform3D).affine_inverse() * plane
	plane_record.owner_system = OWNER
	if not registry.register_origin(plane_record):
		return _fail("frozen_dimension_plane_registration_failed")
	var updated_records: Array = input.origin_records.duplicate(true)
	var replaced: bool = false
	for record: Dictionary in updated_records:
		if record.origin_id == input.plane_origin_id:
			record.transform_to_parent = plane_record.transform_to_parent
			record.owner_system = OWNER
			replaced = true
	var chain: Dictionary = registry.validate_origin_chain(input.plane_origin_id)
	if not replaced or not bool(chain.get("ok", false)):
		return _fail("invalid_frozen_dimension_plane_origin_chain")
	# Effective reach follows the measured local translations. S3 retains its
	# prepared skin-tip measurement; the prepared anatomy Resource is immutable.
	var digit: Dictionary = input.digit.duplicate(true)
	var prepared_lengths: Array = digit.section_lengths_m.duplicate()
	for section: int in range(2):
		var length_m: float = (zero.joint_origins_world[section] as Vector3).distance_to(zero.joint_origins_world[section + 1])
		if not is_finite(length_m) or length_m <= 0.0:
			return _fail("invalid_frozen_digit_section_length")
		digit.section_lengths_m[section] = length_m
	input["snapshot"] = snapshot
	input["digit"] = digit
	input["plane_to_world"] = plane
	input["origin_records"] = updated_records
	input["origin_chain"] = chain
	input["prepared_rest_section_length_round_trip_error_m"] = input.section_length_round_trip_error_m
	input["section_length_round_trip_error_m"] = 0.0
	input["dimension_reference_applied"] = true
	input["dimension_reference_changes"] = changes
	input["dimension_reference_prepared_section_lengths_m"] = prepared_lengths
	input["dimension_reference_effective_section_lengths_m"] = digit.section_lengths_m.duplicate()
	input["dimension_reference_plane_origin_delta_world"] = plane.origin - prepared_plane_origin
	input["dimension_reference_plane_origin_delta_origin_id"] = ROOT
	return {"valid": true}


func evaluate(prepared: Dictionary, angles_by_digit: Dictionary, translation_world: Vector3, translation_origin_id: StringName) -> Dictionary:
	var started: int = Time.get_ticks_usec()
	if not bool(prepared.get("valid", false)) or prepared.get("revision") != REVISION:
		return _fail("invalid_prepared_candidate")
	if translation_origin_id != ROOT or not translation_world.is_finite():
		return _fail("invalid_named_world_translation")
	if angles_by_digit.size() != prepared.digit_inputs.size():
		return _fail("angles_must_cover_exactly_selected_digits")
	var base_packet: Dictionary = prepared.base_packet
	var machine: Transform3D = base_packet.machine_to_world
	var world_to_machine: Transform3D = machine.affine_inverse()
	var hand_world: Transform3D = prepared.baseline_hand_to_world
	hand_world.origin += translation_world
	var base_hand: Transform3D = prepared.base_frames[prepared.hand_bone_name]
	var machine_delta: Vector3 = machine.basis.inverse() * translation_world
	var hand_machine: Transform3D = base_hand
	hand_machine.origin += machine_delta
	var frames: Dictionary = prepared.base_frames.duplicate(true)
	for name: Variant in prepared.descendant_bones:
		var moved_frame: Transform3D = prepared.base_frames[name]
		moved_frame.origin += machine_delta
		frames[name] = moved_frame
	var digit_states: Dictionary = {}
	var plane_records: Array[Dictionary] = []
	for id: Variant in prepared.digit_inputs:
		if not angles_by_digit.has(id) or not angles_by_digit[id] is Array or angles_by_digit[id].size() != 3:
			return _fail("missing_three_selected_digit_angles")
		var input: Dictionary = prepared.digit_inputs[id]
		var snapshot: Dictionary = input.snapshot.duplicate(true)
		var angles: Array[float] = []
		for joint: int in range(3):
			var value: Variant = angles_by_digit[id][joint]
			if not (value is float or value is int) or not is_finite(float(value)):
				return _fail("nonfinite_or_invalid_joint_angle")
			var angle: float = float(value)
			if angle < float(snapshot.min_angles_rad[joint]) or angle > float(snapshot.max_angles_rad[joint]):
				return _fail("angle_outside_prepared_limits")
			angles.append(angle)
		snapshot["root_parent_world"] = hand_world
		var fk: Dictionary = Spatial.new()._forward_kinematics(snapshot, angles)
		for joint: int in range(3):
			frames[snapshot.bone_names[joint]] = world_to_machine * (fk.joint_transforms_world[joint] as Transform3D)
		var plane: Transform3D = input.plane_to_world
		plane.origin += translation_world
		var hand_id: StringName = snapshot.root_parent_origin_id
		plane_records.append(_record(hand_id, ROOT, hand_machine, base_packet.resolve_phase))
		plane_records.append(_record(input.plane_origin_id, hand_id, hand_world.affine_inverse() * plane, base_packet.resolve_phase))
		digit_states[id] = {"angles_rad": angles, "snapshot": snapshot,
			"digit": input.digit.duplicate(true), "hand_to_world": hand_world,
			"hand_origin_id": hand_id,
			"plane_to_world": plane, "plane_origin_id": input.plane_origin_id,
			"joint_transforms_world": fk.joint_transforms_world,
			"joint_origins_world": fk.joint_origins_world, "tip_world": fk.tip_world,
			"tip_origin_id": base_packet.bone_origin_ids[snapshot.bone_names[2]],
			"angle_convention": prepared.angle_convention}
	# Any extra descendants follow the nearest explicitly posed digit ancestor.
	# Other digits retain captured local articulation under the translated Hand.
	for name: Variant in prepared.descendant_bones:
		if prepared.selected_bones.has(name):
			continue
		var ancestor: StringName = StringName(prepared.source_parent_ids.get(name, StringName()))
		while ancestor != StringName() and ancestor != ROOT:
			if prepared.selected_bones.has(ancestor):
				frames[name] = (frames[ancestor] as Transform3D) * (prepared.base_frames[ancestor] as Transform3D).affine_inverse() * (prepared.base_frames[name] as Transform3D)
				break
			ancestor = StringName(prepared.source_parent_ids.get(ancestor, StringName()))
	var packet: Dictionary = base_packet.duplicate(true)
	packet["schema"] = &"coherent_hand_candidate_pose_v1"
	packet["source_pose_id"] = base_packet.pose_id
	packet["pose_id"] = StringName("%sCandidate%s" % [String(base_packet.pose_id), str(hash([angles_by_digit, translation_world]))])
	packet["candidate_not_captured_pose"] = true
	packet["source_capture_metadata"] = {}
	for field: String in ["capture_stage", "engine_process_frame", "transaction_serial", "all_skin_bind_poses_captured", "pose_read_without_scene_writes", "capture_ms", "reference_validation_ms", "capture_timing_scope"]:
		if packet.has(field):
			packet.source_capture_metadata[field] = packet[field]
			packet.erase(field)
	packet["all_contributing_poses_supplied"] = true
	packet["translation_world"] = translation_world
	packet["translation_world_origin_id"] = ROOT
	packet["angle_convention"] = prepared.angle_convention
	packet["arm_realization_verified"] = false
	packet["actual_3d_grip_verified"] = false
	var records: Array[Dictionary] = [_record(ROOT, StringName(), Transform3D.IDENTITY, packet.resolve_phase)]
	for name: Variant in packet.bone_origin_ids:
		if StringName(name) != ROOT:
			records.append(_record(packet.bone_origin_ids[name], ROOT, frames[name], packet.resolve_phase))
	var mesh_record: Dictionary = _record(packet.mesh_origin_id, ROOT, prepared.base_pose.mesh_to_machine, packet.resolve_phase)
	mesh_record["space_type"] = &"presentation"
	records.append(mesh_record)
	# Shared Hand-origin IDs across selected digits are one authority, not duplicates.
	var seen: Dictionary = {}
	for record: Dictionary in records:
		seen[record.origin_id] = true
	for record: Dictionary in plane_records:
		if not seen.has(record.origin_id):
			records.append(record)
			seen[record.origin_id] = true
	packet["origin_records"] = records
	var validation_started: int = Time.get_ticks_usec()
	var checked: Dictionary = HandSkin.new()._registry(records, packet.resolve_phase)
	if not bool(checked.get("valid", false)):
		return checked
	var validation_ms: float = float(Time.get_ticks_usec() - validation_started) / 1000.0
	var skin: Dictionary = prepared.skin_prepared
	var bind_frames: Array[Transform3D] = []
	for name: StringName in skin.bind_bone_names:
		bind_frames.append(frames[name])
	var machine_vertices: PackedVector3Array = prepared.base_pose.vertices_machine.duplicate()
	var world_vertices: PackedVector3Array = prepared.base_pose.vertices_world.duplicate()
	var moved: int = 0
	for changed: int in range(prepared.affected_vertex_ids.size()):
		var point: Vector3 = prepared.fixed_contributions_machine[changed]
		for local_slot: int in range(prepared.dynamic_offsets[changed], prepared.dynamic_offsets[changed + 1]):
			var influence: int = prepared.dynamic_influence_slots[local_slot]
			var frame: Transform3D = bind_frames[skin.influence_binds[influence]]
			point += frame.basis * (skin.weighted_bind_points[influence] as Vector3) + frame.origin * float(skin.influence_weights[influence])
		var world_point: Vector3 = machine * point
		if not point.is_finite() or not world_point.is_finite():
			return _fail("nonfinite_candidate_vertex")
		var vertex: int = prepared.affected_vertex_ids[changed]
		moved += 1 if world_vertices[vertex] != world_point else 0
		machine_vertices[vertex] = point
		world_vertices[vertex] = world_point
	var posed: Dictionary = prepared.base_pose.duplicate(true)
	posed["vertices_machine"] = machine_vertices
	posed["vertices_world"] = world_vertices
	posed["pose_id"] = packet.pose_id
	posed["origin_records"] = records.duplicate(true)
	posed["bone_transforms_to_machine"] = frames.duplicate(true)
	posed["candidate_not_captured_pose"] = true
	posed["arm_realization_verified"] = false
	posed["actual_3d_grip_verified"] = false
	posed["pose_validation_ms"] = validation_ms
	posed["candidate_preparation_ms"] = prepared.preparation_ms
	posed["elapsed_ms"] = float(Time.get_ticks_usec() - started) / 1000.0
	return {"valid": true, "posed": posed, "pose_packet": packet, "digit_states": digit_states,
		"affected_vertex_count": prepared.affected_vertex_ids.size(), "moved_vertex_count": moved,
		"full_vertex_count": skin.vertex_count, "hand_to_world": hand_world,
		"translation_world": translation_world, "translation_world_origin_id": ROOT,
		"hypothetical_placement_only": true, "weapon_action_scope": &"frozen_after_upstream_authored_placement",
		"angle_convention": prepared.angle_convention,
		"arm_realization_verified": false, "actual_3d_grip_verified": false,
		"evaluation_timing_scope": &"candidate_FK_origin_validation_sparse_skin_and_full_output_copy",
		"evaluation_ms": float(Time.get_ticks_usec() - started) / 1000.0}


func _ancestry(name: StringName, parents: Dictionary) -> Dictionary:
	var chain: Array[StringName] = []
	var current: StringName = name
	while current != ROOT:
		if current == StringName() or chain.has(current) or not parents.has(current):
			return _fail("missing_or_cyclic_captured_skeleton_ancestry")
		chain.append(current)
		current = StringName(parents[current])
	chain.append(ROOT)
	return {"valid": true, "chain": chain}


func _record(id: StringName, parent: StringName, frame: Transform3D, phase: StringName) -> Dictionary:
	return {"origin_id": id, "parent_origin_id": parent, "transform_to_parent": frame,
		"owner_system": OWNER, "resolve_phase": phase,
		"space_type": &"machine" if id == ROOT else &"bone_frame", "is_dynamic": id != ROOT}


func _fail(reason: String, details: Dictionary = {}) -> Dictionary:
	return {"valid": false, "reason": reason, "details": details, "arm_realization_verified": false, "actual_3d_grip_verified": false}
