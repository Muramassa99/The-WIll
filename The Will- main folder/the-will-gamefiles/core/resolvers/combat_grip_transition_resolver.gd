extends RefCounted

## Samples prepared normal/reverse grip changes. This owner never acquires a
## grip, writes a skeleton, resolves collisions or changes the action duration.
## All input transforms and palm_normal share reference_origin_id. The handle
## pivot and weapon axis are WeaponRoot-local; finger rotations are parent-local.
const REVISION: StringName = &"prepared_open_flip_close_v1"
const NORMAL: StringName = &"grip_normal"
const REVERSE: StringName = &"grip_reverse"
const RIGHT: StringName = &"hand_right"
const LEFT: StringName = &"hand_left"
const EPSILON: float = 0.00000001

# Provisional normalized animation tuning for an already prepared destination,
# never a solver deadline. Callers can supply independent phase progress while
# acquisition is pending; entry/animation timing is owned outside this resolver.
const OPEN_COMPLETE_RATIO: float = 0.20
const CLOSE_START_RATIO: float = 0.55


static func is_style_swap(source_style: StringName, destination_style: StringName) -> bool:
	return source_style in [NORMAL, REVERSE] and destination_style in [NORMAL, REVERSE] and source_style != destination_style


static func sample_phases(ratio: float) -> Dictionary:
	var progress: float = clampf(ratio, 0.0, 1.0) if is_finite(ratio) else 0.0
	return {
		"opening_weight": smoothstep(0.0, OPEN_COMPLETE_RATIO, progress),
		"closing_weight": smoothstep(CLOSE_START_RATIO, 1.0, progress),
		"weapon_progress": smoothstep(OPEN_COMPLETE_RATIO, 1.0, progress),
	}


static func create_plan(input: Dictionary) -> Dictionary:
	var source_style: StringName = StringName(input.get("source_style", &""))
	var destination_style: StringName = StringName(input.get("destination_style", &""))
	var slot: StringName = StringName(input.get("hand_slot", &""))
	var reference_origin_id: StringName = StringName(input.get("reference_origin_id", &""))
	if not is_style_swap(source_style, destination_style):
		return _fail("requires_normal_reverse_grip_change")
	if slot not in [RIGHT, LEFT] or reference_origin_id == &"":
		return _fail("missing_hand_or_reference_origin")
	for field: String in ["source_weapon", "destination_weapon", "source_hand", "source_forearm"]:
		if not input.get(field) is Transform3D or not _valid_frame(input[field]):
			return _fail("invalid_" + field)
	for field: String in ["handle_pivot_local", "weapon_axis_local"]:
		if not input.get(field) is Vector3 or not (input[field] as Vector3).is_finite():
			return _fail("invalid_" + field)
	var local_axis: Vector3 = input.weapon_axis_local
	if local_axis.length_squared() < EPSILON:
		return _fail("degenerate_weapon_axis")
	var source: Transform3D = input.source_weapon
	var destination: Transform3D = input.destination_weapon
	var hand: Transform3D = input.source_hand
	var forearm: Transform3D = input.source_forearm
	var palm_normal: Vector3 = input.get("palm_normal", Vector3.ZERO)
	if not palm_normal.is_finite():
		return _fail("invalid_palm_normal")
	var axis: Vector3 = resolve_flip_axis(
		source.basis * local_axis, hand, forearm, slot, source_style, palm_normal)
	if axis.length_squared() < EPSILON:
		return _fail("degenerate_flip_frame")
	var source_fingers: Dictionary = input.get("source_fingers", {})
	var open_fingers: Dictionary = input.get("open_fingers", {})
	var destination_fingers: Dictionary = input.get("destination_fingers", {})
	if not _valid_fingers(source_fingers, open_fingers, destination_fingers):
		return _fail("incomplete_prepared_finger_rotations")
	var pivot: Vector3 = input.handle_pivot_local
	var source_pivot: Vector3 = source * pivot
	var destination_pivot: Vector3 = destination * pivot
	var midpoint_basis: Basis = Basis(axis, PI * 0.5) * source.basis.orthonormalized()
	midpoint_basis = midpoint_basis * Basis.from_scale(source.basis.get_scale().lerp(destination.basis.get_scale(), 0.5))
	var midpoint_pivot: Vector3 = source_pivot.lerp(destination_pivot, 0.5)
	var midpoint := Transform3D(midpoint_basis, midpoint_pivot - midpoint_basis * pivot)
	return {
		"valid": true, "revision": REVISION, "reference_origin_id": reference_origin_id,
		"hand_slot": slot, "source_style": source_style, "destination_style": destination_style,
		"source_weapon": source, "midpoint_weapon": midpoint, "destination_weapon": destination,
		"handle_pivot_local": pivot, "weapon_axis_local": local_axis.normalized(),
		"source_pivot": source_pivot, "destination_pivot": destination_pivot, "flip_axis": axis,
		"source_fingers": source_fingers.duplicate(), "open_fingers": open_fingers.duplicate(),
		"destination_fingers": destination_fingers.duplicate(),
	}


## The explicit half-turn direction comes from anatomy and handedness, not the
## arbitrary quaternion sign of two orientations 180 degrees apart. Reversing
## the grip change reverses this axis and therefore retraces the prescribed arc.
static func resolve_flip_axis(weapon_axis: Vector3, hand: Transform3D,
		forearm: Transform3D, hand_slot: StringName, source_style: StringName,
		palm_normal: Vector3 = Vector3.ZERO) -> Vector3:
	if not weapon_axis.is_finite() or weapon_axis.length_squared() < EPSILON:
		return Vector3.ZERO
	var longitudinal: Vector3 = weapon_axis.normalized()
	var source_sign: float = -1.0 if source_style == REVERSE else 1.0
	var forearm_direction: Vector3 = hand.origin - forearm.origin
	if forearm_direction.length_squared() < EPSILON:
		forearm_direction = forearm.basis.y
	var reference_normal: Vector3 = palm_normal if palm_normal.length_squared() >= EPSILON else hand.basis.z
	var axis: Vector3 = reference_normal - longitudinal * reference_normal.dot(longitudinal)
	var forearm_normal: Vector3 = (longitudinal * source_sign).cross(forearm_direction)
	if axis.length_squared() < EPSILON:
		axis = forearm_normal
	if axis.length_squared() < EPSILON:
		axis = hand.basis.x - longitudinal * hand.basis.x.dot(longitudinal)
	if axis.length_squared() < EPSILON:
		return Vector3.ZERO
	axis = axis.normalized()
	# Forearm-to-hand direction gives the palm-plane normal a repeatable sign.
	if forearm_normal.length_squared() >= EPSILON and axis.dot(forearm_normal) < 0.0:
		axis = -axis
	var hand_sign: float = -1.0 if hand_slot == LEFT else 1.0
	return axis * hand_sign * source_sign


static func sample_plan(plan: Dictionary, ratio: float, phase_progress: Dictionary = {}) -> Dictionary:
	if not plan.get("valid", false) or plan.get("revision") != REVISION:
		return _fail("invalid_transition_plan")
	var phases: Dictionary = _resolve_phases(ratio, phase_progress)
	var progress: float = phases.weapon_progress
	var source: Transform3D = plan.source_weapon
	var midpoint: Transform3D = plan.midpoint_weapon
	var destination: Transform3D = plan.destination_weapon
	var basis: Basis
	if progress <= 0.5:
		basis = source.basis.orthonormalized().slerp(midpoint.basis.orthonormalized(), progress * 2.0)
	else:
		basis = midpoint.basis.orthonormalized().slerp(destination.basis.orthonormalized(), (progress - 0.5) * 2.0)
	basis = basis * Basis.from_scale(source.basis.get_scale().lerp(destination.basis.get_scale(), progress))
	var pivot: Vector3 = (plan.source_pivot as Vector3).lerp(plan.destination_pivot, progress)
	var frame := Transform3D(basis, pivot - basis * (plan.handle_pivot_local as Vector3))
	# Preserve exact endpoint packets rather than round-tripping their rotations.
	if progress <= 0.0:
		frame = source
	elif progress >= 1.0:
		frame = destination
	var fingers: Dictionary = sample_finger_rotations(
		plan.source_fingers, plan.open_fingers, plan.destination_fingers, ratio, phases)
	return {
		"valid": true, "reference_origin_id": plan.reference_origin_id,
		"weapon_transform": frame, "finger_rotations": fingers,
		"pivot_position": pivot, "midpoint_transform": midpoint,
		"opening_weight": phases.opening_weight, "closing_weight": phases.closing_weight,
		"weapon_progress": progress,
	}


static func sample_finger_rotations(source: Dictionary, opened: Dictionary,
		destination: Dictionary, ratio: float, phase_progress: Dictionary = {}) -> Dictionary:
	if not _valid_fingers(source, opened, destination):
		return {}
	var phases: Dictionary = _resolve_phases(ratio, phase_progress)
	var result: Dictionary = {}
	for bone: Variant in source:
		var from_rotation: Quaternion = source[bone]
		var open_rotation: Quaternion = opened[bone]
		var destination_rotation: Quaternion = destination[bone]
		if phases.closing_weight > 0.0:
			result[bone] = open_rotation.normalized().slerp(destination_rotation.normalized(), phases.closing_weight).normalized()
		else:
			result[bone] = from_rotation.normalized().slerp(open_rotation.normalized(), phases.opening_weight).normalized()
	return result


## Explicit Tip/Pommel waypoint packet in one named reference frame. Progress
## comes from the destination motion node; this does not wait for acquisition or
## reserve a portion of the movement time for opening/closing.
static func sample_endpoint_arc(source_tip: Vector3, source_pommel: Vector3,
		pivot: Vector3, signed_axis: Vector3, progress: float,
		reference_origin_id: StringName) -> Dictionary:
	if reference_origin_id == &"" or not source_tip.is_finite() or not source_pommel.is_finite() \
			or not pivot.is_finite() or not signed_axis.is_finite() or signed_axis.length_squared() < EPSILON \
			or not is_finite(progress):
		return _fail("invalid_endpoint_arc")
	var axis: Vector3 = signed_axis.normalized()
	var midpoint_rotation := Basis(axis, PI * 0.5)
	var midpoint_tip: Vector3 = pivot + midpoint_rotation * (source_tip - pivot)
	var midpoint_pommel: Vector3 = pivot + midpoint_rotation * (source_pommel - pivot)
	var ratio: float = clampf(progress, 0.0, 1.0)
	var rotation: Basis = Basis(axis, PI * ratio)
	var tip: Vector3
	var pommel: Vector3
	if ratio <= 0.5:
		tip = pivot + rotation * (source_tip - pivot)
		pommel = pivot + rotation * (source_pommel - pivot)
	else:
		var remaining_rotation := Basis(axis, PI * (ratio - 0.5))
		tip = pivot + remaining_rotation * (midpoint_tip - pivot)
		pommel = pivot + remaining_rotation * (midpoint_pommel - pivot)
	return {"valid": true, "tip_position": tip, "pommel_position": pommel,
		"midpoint_tip_position": midpoint_tip, "midpoint_pommel_position": midpoint_pommel,
		"rotation": rotation, "fixed_pivot": pivot, "reference_origin_id": reference_origin_id}


## Builds new local-rotation frames after the source and destination grips have
## already been prepared. Only named finger bones change. Callers commit the
## returned frames atomically; failure never partially modifies their clip.
## Each transition has start_time_seconds, end_time_seconds and hand_slot.
static func build_prepared_finger_track(frame_times: PackedFloat32Array,
		bone_names: Array, rotation_frames: Array, transitions: Array,
		open_packets: Dictionary) -> Dictionary:
	if frame_times.size() != rotation_frames.size() or frame_times.is_empty():
		return _fail("invalid_prepared_frame_counts")
	var indices: Dictionary = {}
	for index: int in range(bone_names.size()):
		indices[StringName(bone_names[index])] = index
	for frame: Variant in rotation_frames:
		if not frame is PackedVector4Array or frame.size() != bone_names.size():
			return _fail("incomplete_prepared_rotation_frame")
	var output: Array = rotation_frames.duplicate()
	var changed_frames: int = 0
	for transition: Dictionary in transitions:
		var start_time: float = float(transition.get("start_time_seconds", -1.0))
		var end_time: float = float(transition.get("end_time_seconds", -1.0))
		var slot: StringName = StringName(transition.get("hand_slot", &""))
		if not is_finite(start_time) or not is_finite(end_time) or end_time <= start_time \
				or start_time < float(frame_times[0]) - 0.0001 or end_time > float(frame_times[-1]) + 0.0001:
			return _fail("invalid_prepared_grip_interval")
		var packet: Dictionary = open_packets.get(slot, {})
		var opened: Dictionary = packet.get("rotations", {})
		if not packet.get("valid", false) or opened.size() != 15:
			return _fail("missing_prepared_open_hand")
		var source_frame: PackedVector4Array = _sample_rotation_frame(frame_times, rotation_frames, start_time)
		var destination_frame: PackedVector4Array = _sample_rotation_frame(frame_times, rotation_frames, end_time)
		var source: Dictionary = {}
		var destination: Dictionary = {}
		for bone: Variant in opened:
			var bone_name: StringName = StringName(bone)
			if not indices.has(bone_name):
				return _fail("prepared_clip_missing_finger_bone")
			var index: int = indices[bone_name]
			source[bone] = _quaternion(source_frame[index])
			destination[bone] = _quaternion(destination_frame[index])
		if not _valid_fingers(source, opened, destination):
			return _fail("invalid_prepared_finger_endpoint")
		for frame_index: int in range(frame_times.size()):
			var time: float = float(frame_times[frame_index])
			if time <= start_time or time >= end_time:
				continue
			var rotations: Dictionary = sample_finger_rotations(source, opened, destination,
				(time - start_time) / (end_time - start_time))
			var frame: PackedVector4Array = (output[frame_index] as PackedVector4Array).duplicate()
			for bone: Variant in rotations:
				var value: Quaternion = rotations[bone]
				frame[indices[StringName(bone)]] = Vector4(value.x, value.y, value.z, value.w)
			output[frame_index] = frame
			changed_frames += 1
	return {"valid": true, "rotation_frames": output, "transition_count": transitions.size(),
		"changed_frames": changed_frames, "source": REVISION}


static func _sample_rotation_frame(times: PackedFloat32Array, frames: Array,
		time: float) -> PackedVector4Array:
	if time <= float(times[0]):
		return frames[0]
	if time >= float(times[-1]):
		return frames[-1]
	var first: int = 0
	while first + 1 < times.size() - 1 and float(times[first + 1]) < time:
		first += 1
	var span: float = float(times[first + 1]) - float(times[first])
	var ratio: float = clampf((time - float(times[first])) / span, 0.0, 1.0) if span > 0.0 else 0.0
	var source: PackedVector4Array = frames[first]
	var destination: PackedVector4Array = frames[first + 1]
	var result := PackedVector4Array()
	result.resize(source.size())
	for index: int in range(source.size()):
		var rotation: Quaternion = _quaternion(source[index]).slerp(_quaternion(destination[index]), ratio).normalized()
		result[index] = Vector4(rotation.x, rotation.y, rotation.z, rotation.w)
	return result


static func _quaternion(value: Vector4) -> Quaternion:
	return Quaternion(value.x, value.y, value.z, value.w).normalized()


static func _resolve_phases(ratio: float, overrides: Dictionary) -> Dictionary:
	var phases: Dictionary = sample_phases(ratio)
	for key: String in ["opening_weight", "closing_weight", "weapon_progress"]:
		if overrides.has(key) and is_finite(float(overrides[key])):
			phases[key] = clampf(float(overrides[key]), 0.0, 1.0)
	return phases


static func _valid_fingers(source: Dictionary, opened: Dictionary, destination: Dictionary) -> bool:
	if source.size() != opened.size() or source.size() != destination.size():
		return false
	for bone: Variant in source:
		if not opened.has(bone) or not destination.has(bone):
			return false
		for values: Dictionary in [source, opened, destination]:
			var rotation: Variant = values[bone]
			if not rotation is Quaternion or not rotation.is_finite() or rotation.length_squared() < EPSILON:
				return false
	return true


static func _valid_frame(frame: Transform3D) -> bool:
	return frame.is_finite() and frame.basis.determinant() > EPSILON


static func _fail(reason: String) -> Dictionary:
	return {"valid": false, "reason": reason}
