extends RefCounted
class_name CombatPreparedPoseTrackBuilder

## Pure interpolation of editor-captured destinations. No scene access, IK,
## contact search, acquisition, or mutation of the input clip/snapshots.
const Clip = preload("res://core/models/combat_runtime_clip.gd")
const PreparedPose = preload("res://core/models/combat_prepared_pose.gd")
const ControlBaker = preload("res://core/resolvers/combat_runtime_clip_baker.gd")
const ControlFields = preload("res://core/resolvers/combat_runtime_clip_incremental_resolver.gd")
const GripTransition = preload("res://core/resolvers/combat_grip_transition_resolver.gd")
const EPSILON := 0.000001

static func build(control_clip: Resource, snapshots: Array[Dictionary]) -> Dictionary:
	if control_clip == null or control_clip.motion_node_chain.is_empty() or control_clip.get_frame_count() == 0:
		return _fail("missing_prepared_pose_control_clip")
	if not is_equal_approx(float(control_clip.sample_rate_hz), Clip.SAMPLE_RATE_HZ):
		return _fail("prepared_pose_track_requires_sixty_hertz")
	var chain: Array = control_clip.motion_node_chain
	if snapshots.size() != chain.size():
		return _fail("prepared_pose_count_does_not_match_action")
	var first: Dictionary = snapshots[0]
	for index: int in snapshots.size():
		var validation: Dictionary = PreparedPose.validate(snapshots[index])
		if not validation.valid:
			return validation.merged({"node_index": index})
		var layout: Dictionary = _validate_shared_layout(first, snapshots[index])
		if not layout.valid:
			return layout.merged({"node_index": index})
		for field: String in ["trajectory_to_reference", "primary_hand_in_weapon"]:
			if not snapshots[index].get(field) is Transform3D or not snapshots[index][field].is_finite():
				return _fail("prepared_pose_missing_" + field).merged({"node_index": index})
		for field: String in ["weapon_tip_local", "weapon_pommel_local"]:
			if not snapshots[index].get(field) is Vector3 or not snapshots[index][field].is_finite():
				return _fail("prepared_pose_missing_" + field).merged({"node_index": index})
	var times := PackedFloat64Array([0.0])
	for index: int in range(1, chain.size()):
		times.append(times[index - 1] + maxf(float(chain[index].transition_duration_seconds), 0.0))
	var output: Resource = control_clip.duplicate_clip()
	_retain_exact_endpoint_samples(output, chain, times)
	_clear_solved_arrays(output)
	output.baked_solved_upper_body_bone_names.assign(first.bone_names)
	output.baked_upper_body_bone_names.assign(first.bone_names)
	output.solved_replay_reference_bone_name = first.reference_bone_name
	output.solved_replay_reference_origin_id = first.reference_origin_id
	output.baked_solved_weapon_reference_origin_id = first.weapon_reference_origin_id
	output.baked_solved_anchor_node_paths.clear()
	for path: Variant in first.anchor_node_paths:
		output.baked_solved_anchor_node_paths.append(StringName(str(path)))
	output.baked_solved_anchor_origin_id = first.anchor_origin_id
	var diagnostics := {
		"source": "captured_editor_endpoint_interpolation", "acquisition_calls": 0,
		"ik_calls": 0, "endpoint_count": snapshots.size(), "frame_count": output.get_frame_count(),
		"additional_endpoint_samples": output.get_frame_count() - control_clip.get_frame_count(),
		"max_primary_attachment_position_error_reference_units": 0.0,
		"max_primary_attachment_angle_error_radians": 0.0,
		"max_support_attachment_position_error_reference_units": 0.0,
		"max_support_attachment_angle_error_radians": 0.0,
		"max_requested_tip_error_reference_units": 0.0,
		"interior_contact_validated": false,
	}
	var segment := 0
	for frame_index: int in output.get_frame_count():
		var time: float = float(output.baked_frame_times[frame_index])
		while segment + 1 < times.size() - 1 and time >= times[segment + 1] - EPSILON:
			segment += 1
		var next: int = mini(segment + 1, snapshots.size() - 1)
		var duration: float = times[next] - times[segment]
		var weight: float = clampf((time - times[segment]) / duration, 0.0, 1.0) if duration > EPSILON else 0.0
		if absf(time - times[segment]) < EPSILON:
			weight = 0.0
		elif absf(time - times[next]) < EPSILON:
			weight = 1.0
		var sample: Dictionary = sample_pose(snapshots[segment], snapshots[next], weight)
		if not sample.valid:
			return sample.merged({"frame_index": frame_index})
		# Preserve the existing sampled tip/pommel curve (including explicit grip
		# flip midpoints) as a deviation from its authored endpoint chord. Carry
		# the already-solved endpoint seating correction instead of solving again.
		if weight > 0.0 and weight < 1.0:
			var weapon_path: Dictionary = _sample_weapon_path(output, frame_index, chain[segment], chain[next], snapshots[segment], snapshots[next], weight)
			if not weapon_path.valid:
				return weapon_path.merged({"frame_index": frame_index})
			sample.weapon_transform = weapon_path.transform
			diagnostics.max_requested_tip_error_reference_units = maxf(diagnostics.max_requested_tip_error_reference_units, weapon_path.tip_error)
		var globals: Dictionary = _resolve_globals(sample, first.parent_indices)
		if not globals.valid:
			return globals.merged({"frame_index": frame_index})
		_record_attachment_diagnostics(diagnostics, sample, globals.transforms, first, snapshots[segment], snapshots[next], weight)
		_append_sample(output, sample)
	var finger_result: Dictionary = _apply_finger_style_transitions(output, snapshots, times)
	if not finger_result.valid:
		return finger_result
	diagnostics["finger_style_transition_count"] = finger_result.transition_count
	output.upper_body_pose_track_source = Clip.UPPER_BODY_POSE_TRACK_SOURCE_SKILL_CRAFTER_AUTHORED_POSE
	output.solved_replay_track_source = Clip.SOLVED_REPLAY_TRACK_SOURCE_SKILL_CRAFTER_F_PLAYBACK
	# Prepared snapshots stay on authored nodes; the derived clip needs only its
	# compact controls and sampled tracks, not a second copy of each snapshot.
	for node: Resource in output.motion_node_chain:
		node.set("prepared_pose", {})
		node.set("prepared_pose_signature", "")
	output.set_meta("prepared_endpoint_track_diagnostics", diagnostics.duplicate(true))
	return {"valid": true, "reason": "", "clip": output, "diagnostics": diagnostics}

## Keep the uniform 60 Hz sampling and add authored key times that fall between
## samples. Existing playback consumes timestamps, so no endpoint is rounded
## away. Sampling a single control node is arithmetic only; it solves no pose.
static func _retain_exact_endpoint_samples(clip: Resource, chain: Array, times: PackedFloat64Array) -> void:
	var baker := ControlBaker.new()
	for node_index: int in chain.size():
		var timestamp: float = times[node_index]
		var index := 0
		while index < clip.baked_frame_times.size() and float(clip.baked_frame_times[index]) < timestamp - EPSILON:
			index += 1
		var replace: bool = index < clip.baked_frame_times.size() and absf(float(clip.baked_frame_times[index]) - timestamp) <= EPSILON
		var endpoint: Resource = baker.bake_from_motion_node_chain([chain[node_index]], {"sample_rate_hz": Clip.SAMPLE_RATE_HZ})
		for field: StringName in ControlFields.INPUT_FRAME_FIELDS:
			var values: Variant = clip.get(field)
			var value: Variant = timestamp if field == &"baked_frame_times" else endpoint.get(field)[0]
			if replace:
				values[index] = value
			else:
				values.insert(index, value)
			clip.set(field, values)

static func _apply_finger_style_transitions(clip: Resource, snapshots: Array[Dictionary], times: PackedFloat64Array) -> Dictionary:
	var transitions: Array = []
	var packets: Dictionary = {}
	for index: int in range(1, clip.motion_node_chain.size()):
		var source: Resource = clip.motion_node_chain[index - 1]
		var destination: Resource = clip.motion_node_chain[index]
		if source.primary_hand_slot != destination.primary_hand_slot or not GripTransition.is_style_swap(source.preferred_grip_style_mode, destination.preferred_grip_style_mode):
			continue
		var slots: Array[StringName] = [StringName(source.primary_hand_slot)]
		if bool(snapshots[index - 1].get("support_enabled", false)) and bool(snapshots[index].get("support_enabled", false)):
			slots.append(&"hand_left" if source.primary_hand_slot == &"hand_right" else &"hand_right")
		for slot: StringName in slots:
			var available: Dictionary = snapshots[index].get("default_open_finger_packets", {})
			var packet: Dictionary = available.get(slot, {})
			if not bool(packet.get("valid", false)):
				available = snapshots[index - 1].get("default_open_finger_packets", {})
				packet = available.get(slot, {})
			if not bool(packet.get("valid", false)):
				return _fail("prepared_pose_missing_open_fingers_for_style_transition").merged({"node_index": index, "hand_slot": slot})
			packets[slot] = packet
			transitions.append({"start_time_seconds": times[index - 1], "end_time_seconds": times[index], "hand_slot": slot})
	if transitions.is_empty():
		return {"valid": true, "transition_count": 0}
	var result: Dictionary = GripTransition.build_prepared_finger_track(clip.baked_frame_times, clip.baked_solved_upper_body_bone_names, clip.baked_solved_upper_body_pose_rotations, transitions, packets)
	if not bool(result.get("valid", false)):
		return result
	clip.baked_solved_upper_body_pose_rotations = result.rotation_frames
	clip.baked_upper_body_bone_pose_rotations = result.rotation_frames.duplicate(true)
	return {"valid": true, "transition_count": transitions.size()}

static func sample_pose(from: Dictionary, to: Dictionary, weight: float) -> Dictionary:
	var ratio: float = clampf(weight, 0.0, 1.0)
	var positions: PackedVector3Array = _blend_vectors(from.pose_positions, to.pose_positions, ratio)
	var rotations: PackedVector4Array = _blend_rotations(from.pose_rotations, to.pose_rotations, ratio)
	var scales: PackedVector3Array = _blend_vectors(from.pose_scales, to.pose_scales, ratio)
	var parents: Array[Transform3D] = []
	for index: int in from.parent_reference_transforms.size():
		parents.append(_blend_transform(from.parent_reference_transforms[index], to.parent_reference_transforms[index], ratio))
	var weapon: Transform3D = _blend_transform(_weapon_transform(from), _weapon_transform(to), ratio)
	return {
		"valid": true, "pose_positions": positions, "pose_rotations": rotations, "pose_scales": scales,
		"parent_reference_transforms": parents, "weapon_transform": weapon,
		"anchor_positions": _blend_vectors(from.anchor_positions_weapon_local, to.anchor_positions_weapon_local, ratio),
		"anchor_rotations": _blend_rotations(from.anchor_rotations_weapon_local, to.anchor_rotations_weapon_local, ratio),
		"anchor_scales": _blend_vectors(from.anchor_scales_weapon_local, to.anchor_scales_weapon_local, ratio),
	}

static func _sample_weapon_path(control: Resource, frame: int, from_node: Resource, to_node: Resource, from: Dictionary, to: Dictionary, weight: float) -> Dictionary:
	var mapping: Transform3D = _blend_transform(from.trajectory_to_reference, to.trajectory_to_reference, weight)
	var raw_tip: Vector3 = control.baked_tip_positions_local[frame]
	var raw_pommel: Vector3 = control.baked_pommel_positions_local[frame]
	var tip_chord: Vector3 = from_node.tip_position_local.lerp(to_node.tip_position_local, weight)
	var pommel_chord: Vector3 = from_node.pommel_position_local.lerp(to_node.pommel_position_local, weight)
	var a: Transform3D = _weapon_transform(from)
	var b: Transform3D = _weapon_transform(to)
	var tip_local: Vector3 = from.weapon_tip_local
	var pommel_local: Vector3 = from.weapon_pommel_local
	var tip: Vector3 = (a * tip_local).lerp(b * tip_local, weight) + mapping.basis * (raw_tip - tip_chord)
	var pommel: Vector3 = (a * pommel_local).lerp(b * pommel_local, weight) + mapping.basis * (raw_pommel - pommel_chord)
	var base: Transform3D = _blend_transform(a, b, weight)
	var source_axis: Vector3 = base.basis * (tip_local - pommel_local)
	var target_axis: Vector3 = tip - pommel
	if source_axis.length_squared() <= 0.000000000001 or target_axis.length_squared() <= 0.000000000001:
		return _fail("prepared_weapon_path_has_degenerate_axis")
	var alignment := Quaternion(source_axis.normalized(), target_axis.normalized())
	var basis: Basis = Basis(alignment) * base.basis
	var transform := Transform3D(basis, pommel - basis * pommel_local)
	return {"valid": true, "transform": transform, "tip_error": (transform * tip_local).distance_to(tip)}

static func _validate_shared_layout(a: Dictionary, b: Dictionary) -> Dictionary:
	for field: String in ["context_signature", "bone_names", "parent_indices", "bone_rest_transforms", "reference_bone_name", "reference_origin_id", "weapon_reference_origin_id", "anchor_node_paths", "anchor_origin_id", "weapon_tip_local", "weapon_pommel_local"]:
		if a.get(field) != b.get(field):
			return _fail("prepared_pose_layout_changed_" + field)
	return {"valid": true}

static func _resolve_globals(sample: Dictionary, parents: PackedInt32Array) -> Dictionary:
	var local: Array[Transform3D] = []
	var transforms: Array[Transform3D] = []
	var visited := PackedByteArray()
	for index: int in sample.pose_positions.size():
		local.append(_transform(sample.pose_positions[index], sample.pose_rotations[index], sample.pose_scales[index]))
	transforms.resize(local.size())
	visited.resize(local.size())
	for index: int in local.size():
		if not _resolve_bone(index, local, parents, sample.parent_reference_transforms, transforms, visited):
			return _fail("prepared_pose_parent_cycle")
	return {"valid": true, "transforms": transforms}

static func _resolve_bone(index: int, local: Array[Transform3D], parents: PackedInt32Array, roots: Array[Transform3D], transforms: Array[Transform3D], visited: PackedByteArray) -> bool:
	if visited[index] == 2:
		return true
	if visited[index] == 1:
		return false
	visited[index] = 1
	var parent: int = parents[index]
	if parent >= 0:
		if not _resolve_bone(parent, local, parents, roots, transforms, visited):
			return false
		transforms[index] = transforms[parent] * local[index]
	else:
		transforms[index] = roots[index] * local[index]
	visited[index] = 2
	return true

static func _record_attachment_diagnostics(diagnostics: Dictionary, sample: Dictionary, globals: Array[Transform3D], layout: Dictionary, a: Dictionary, b: Dictionary, weight: float) -> void:
	for kind: String in ["primary", "support"]:
		if a.get(kind + "_hand_bone_name") != b.get(kind + "_hand_bone_name"):
			continue
		if kind == "support" and not (bool(a.get("support_enabled", false)) and bool(b.get("support_enabled", false))):
			continue
		var index: int = layout.bone_names.find(a.get(kind + "_hand_bone_name"))
		if index < 0:
			continue
		var relation: Transform3D = _blend_transform(a[kind + "_hand_in_weapon"], b[kind + "_hand_in_weapon"], weight)
		var target: Transform3D = sample.weapon_transform * relation
		var actual: Transform3D = globals[index]
		var position_key: String = "max_" + kind + "_attachment_position_error_reference_units"
		var angle_key: String = "max_" + kind + "_attachment_angle_error_radians"
		diagnostics[position_key] = maxf(diagnostics[position_key], actual.origin.distance_to(target.origin))
		diagnostics[angle_key] = maxf(diagnostics[angle_key], actual.basis.orthonormalized().get_rotation_quaternion().angle_to(target.basis.orthonormalized().get_rotation_quaternion()))

static func _append_sample(clip: Resource, sample: Dictionary) -> void:
	clip.baked_solved_replay_frame_available.append(true)
	clip.baked_solved_upper_body_pose_positions.append(sample.pose_positions)
	clip.baked_solved_upper_body_pose_rotations.append(sample.pose_rotations)
	clip.baked_solved_upper_body_pose_scales.append(sample.pose_scales)
	clip.baked_upper_body_bone_pose_rotations.append(sample.pose_rotations)
	var weapon: Transform3D = sample.weapon_transform
	clip.baked_solved_weapon_positions_reference_local.append(weapon.origin)
	clip.baked_solved_weapon_rotations_reference_local.append(_pack(weapon.basis.orthonormalized().get_rotation_quaternion()))
	clip.baked_solved_weapon_scales_reference_local.append(weapon.basis.get_scale())
	clip.baked_solved_anchor_positions_weapon_local.append(sample.anchor_positions)
	clip.baked_solved_anchor_rotations_weapon_local.append(sample.anchor_rotations)
	clip.baked_solved_anchor_scales_weapon_local.append(sample.anchor_scales)

static func _clear_solved_arrays(clip: Resource) -> void:
	for field: String in ["baked_solved_replay_frame_available", "baked_solved_upper_body_pose_positions", "baked_solved_upper_body_pose_rotations", "baked_solved_upper_body_pose_scales", "baked_upper_body_bone_pose_rotations", "baked_solved_anchor_positions_weapon_local", "baked_solved_anchor_rotations_weapon_local", "baked_solved_anchor_scales_weapon_local"]:
		clip.set(field, [])
	clip.baked_solved_weapon_positions_reference_local = PackedVector3Array()
	clip.baked_solved_weapon_rotations_reference_local = PackedVector4Array()
	clip.baked_solved_weapon_scales_reference_local = PackedVector3Array()

static func _blend_vectors(a: PackedVector3Array, b: PackedVector3Array, weight: float) -> PackedVector3Array:
	if weight <= 0.0:
		return a.duplicate()
	if weight >= 1.0:
		return b.duplicate()
	var values := PackedVector3Array()
	for index: int in a.size():
		values.append(a[index].lerp(b[index], weight))
	return values

static func _blend_rotations(a: PackedVector4Array, b: PackedVector4Array, weight: float) -> PackedVector4Array:
	if weight <= 0.0:
		return a.duplicate()
	if weight >= 1.0:
		return b.duplicate()
	var values := PackedVector4Array()
	for index: int in a.size():
		values.append(_pack(_quaternion(a[index]).slerp(_quaternion(b[index]), weight).normalized()))
	return values

static func _blend_transform(a: Transform3D, b: Transform3D, weight: float) -> Transform3D:
	if weight <= 0.0:
		return a
	if weight >= 1.0:
		return b
	return a.interpolate_with(b, weight)

static func _weapon_transform(snapshot: Dictionary) -> Transform3D:
	return Transform3D(Basis(snapshot.weapon_rotation_reference_local).scaled(snapshot.weapon_scale_reference_local), snapshot.weapon_position_reference_local)

static func _transform(position: Vector3, rotation: Vector4, scale: Vector3) -> Transform3D:
	return Transform3D(Basis(_quaternion(rotation)).scaled(scale), position)

static func _quaternion(value: Vector4) -> Quaternion:
	return Quaternion(value.x, value.y, value.z, value.w).normalized()

static func _pack(value: Quaternion) -> Vector4:
	return Vector4(value.x, value.y, value.z, value.w)

static func _fail(reason: String) -> Dictionary:
	return {"valid": false, "reason": reason}
