extends RefCounted

## Read-only view of an actually captured pose. Candidate.prepare is used for
## validated anatomy/ancestry/measurement planes, never Candidate.evaluate.
## A valid observation is not necessarily a legal calibrated hinge pose.
const Candidate = preload("res://runtime/player/grip/prepared_hand_candidate_pose.gd")
const CoherentSkin = preload("res://runtime/player/grip/prepared_hand_skin_query.gd")
const Store = preload("res://runtime/player/grip/character_hand_anatomy_store.gd")
const Native = preload("res://runtime/player/grip/native_digit_contact_ik.gd")
const ROOT := &"RL_BoneRoot"
const REVISION := &"observed_hand_pose_view_v1"
# Numerical reporting guards are shared with the existing native proposal
# validator. They do not enlarge the character's authored physical ranges.
const ANGLE_TOLERANCE_RAD: float = Native.ANGLE_NUMERIC_TOLERANCE
const OFF_AXIS_TOLERANCE_RAD: float = Native.OFF_AXIS_TOLERANCE
const FRAME_TOLERANCE: float = Native.FRAME_TOLERANCE


func observe(definition: Resource, capture: Dictionary, slot: StringName, digit_ids: Array) -> Dictionary:
	var started: int = Time.get_ticks_usec()
	if capture.get("schema") != &"coherent_skin_pose_capture_v1" or not capture.get("valid", false):
		return _fail("requires_actual_coherent_capture")
	if capture.get("candidate_not_captured_pose", false) or not capture.get("pose_read_without_scene_writes", false) or not capture.get("all_skin_bind_poses_captured", false) or not capture.get("reference_correspondence_verified", false):
		return _fail("missing_actual_capture_provenance")
	var checked: Dictionary = Store.new().validate(definition)
	if not checked.get("valid", false): return _fail("invalid_prepared_anatomy", checked)
	var before: PackedByteArray = var_to_bytes(capture)
	var adapter: Dictionary = Candidate.new().prepare(definition, capture, slot, digit_ids)
	if not adapter.get("valid", false): return _fail("observed_pose_preparation_failed", adapter)
	var original_registry: Dictionary = CoherentSkin.new()._registry(capture.origin_records, capture.resolve_phase)
	if not original_registry.get("valid", false): return _fail("invalid_captured_origin_registry", original_registry)
	var packet: Dictionary = capture.duplicate(true)
	packet["schema"] = &"coherent_skin_pose_observation_view_v1"
	packet["source_capture_schema"] = capture.schema
	packet["source_pose_id"] = capture.pose_id
	packet["observed_pose_view"] = true
	packet["candidate_not_captured_pose"] = false
	packet["geometry_reposed"] = false
	packet["arm_realization_verified"] = false
	packet["actual_3d_grip_verified"] = false
	packet["grip_accepted"] = false
	var added: Dictionary = {}
	var states: Dictionary = {}
	var all_joints: Array = []
	var violations: Array = []
	var maximum_off_axis: float = 0.0
	var maximum_position_error: float = 0.0
	var maximum_metric_error: float = 0.0
	var machine: Transform3D = capture.machine_to_world
	var hand_frame: Transform3D = machine * (adapter.base_frames[adapter.hand_bone_name] as Transform3D)
	for raw_id: Variant in digit_ids:
		var id: StringName = StringName(raw_id)
		var input: Dictionary = adapter.digit_inputs[id]
		for record: Dictionary in input.origin_records:
			if original_registry.registry.has_origin(record.origin_id):
				return _fail("measurement_origin_already_owned_by_capture", {"origin_id": record.origin_id})
			if added.has(record.origin_id):
				if var_to_bytes(added[record.origin_id]) != var_to_bytes(record):
					return _fail("selected_digits_disagree_on_measurement_origin")
			else:
				added[record.origin_id] = record.duplicate(true)
				packet.origin_records.append(record.duplicate(true))
		var snapshot: Dictionary = input.snapshot
		var joint_frames: Array[Transform3D] = []
		var joint_origins: Array[Vector3] = []
		var angles: Array[float] = []
		var joint_reports: Array = []
		var parent_name: StringName = adapter.hand_bone_name
		var parent_world: Transform3D = hand_frame
		for joint: int in range(3):
			var bone: StringName = snapshot.bone_names[joint]
			var actual: Transform3D = machine * (adapter.base_frames[bone] as Transform3D)
			var relative: Transform3D = parent_world.affine_inverse() * actual
			var zero: Transform3D = snapshot.relative_transforms[joint]
			zero.basis = zero.basis * Basis(snapshot.neutral_local_rotations[joint])
			var delta: Basis = zero.basis.inverse() * relative.basis
			if not delta.is_finite() or delta.determinant() <= 0.0:
				return _fail("observed_joint_has_nonrepresentable_rotation", {"digit": id, "section": joint + 1})
			# Orthonormalization is only a rotation MEASUREMENT. The original
			# affine frames, skin and joint transforms below are never replaced.
			var rotation: Quaternion = delta.orthonormalized().get_rotation_quaternion().normalized()
			var axis: Vector3 = (snapshot.hinge_axes_local[joint] as Vector3).normalized()
			var low: float = snapshot.min_angles_rad[joint]
			var high: float = snapshot.max_angles_rad[joint]
			if high - low >= TAU:
				return _fail("capture_cannot_identify_multiturn_hinge_angle", {"digit": id, "section": joint + 1})
			var raw_angle: float = 2.0 * atan2(Vector3(rotation.x,rotation.y,rotation.z).dot(axis), rotation.w)
			var center: float = (low + high) * 0.5
			var angle: float = center + wrapf(raw_angle - center, -PI, PI)
			var difference: Quaternion = Quaternion(axis, angle).inverse() * rotation
			var off_axis: float = 2.0 * atan2(Vector3(difference.x,difference.y,difference.z).length(), absf(difference.w))
			var metric_error: float = _basis_error(delta, Basis(rotation))
			var position_error: float = actual.origin.distance_to(parent_world * zero.origin)
			var within: bool = angle >= low - ANGLE_TOLERANCE_RAD and angle <= high + ANGLE_TOLERANCE_RAD
			var legal: bool = within and off_axis <= OFF_AXIS_TOLERANCE_RAD and metric_error <= FRAME_TOLERANCE and position_error <= FRAME_TOLERANCE
			var result := {"digit": id,"section":joint+1,"bone_name":bone,
				"observed_relative_transform":relative,"observed_relative_transform_origin_id":capture.bone_origin_ids[parent_name],
				"measured_twist_angle_rad":angle,"min_angle_rad":low,"max_angle_rad":high,
				"within_authored_range":angle>=low and angle<=high,"within_range_numeric_guard":within,
				"off_axis_error_rad":off_axis,"position_error_m":position_error,"rotation_metric_error":metric_error,
				"articulation_valid":legal,"angle_was_clamped":false,"pose_was_reprojected":false}
			joint_reports.append(result); all_joints.append(result)
			if not legal: violations.append(result)
			maximum_off_axis = maxf(maximum_off_axis,off_axis)
			maximum_position_error = maxf(maximum_position_error,position_error)
			maximum_metric_error = maxf(maximum_metric_error,metric_error)
			angles.append(angle); joint_frames.append(actual); joint_origins.append(actual.origin)
			parent_name = bone; parent_world = actual
		states[id] = {"angles_rad":angles,"angles_are_twist_measurements_not_reconstructed_pose":true,
			"snapshot":snapshot.duplicate(true),"digit":input.digit.duplicate(true),"hand_to_world":hand_frame,
			"hand_origin_id":snapshot.root_parent_origin_id,"plane_to_world":input.plane_to_world,"plane_origin_id":input.plane_origin_id,
			"joint_transforms_world":joint_frames,"joint_origins_world":joint_origins,
			"tip_world":joint_frames[2]*(snapshot.tip_offset_local as Vector3),"tip_origin_id":capture.bone_origin_ids[snapshot.bone_names[2]],
			"angle_convention":adapter.angle_convention,"articulation_measurements":joint_reports,"observed_not_reposed":true}
	var registered: Dictionary = CoherentSkin.new()._registry(packet.origin_records,packet.resolve_phase)
	if not registered.get("valid",false): return _fail("invalid_observed_measurement_origins",registered)
	for id: Variant in states:
		var state: Dictionary = states[id]
		var resolved: Transform3D = machine * registered.registry.resolve_transform_to_machine(state.plane_origin_id)
		if _frame_error(resolved,state.plane_to_world) > FRAME_TOLERANCE:
			return _fail("observed_digit_plane_disagrees_with_origin_chain",{"digit":id})
	var posed: Dictionary = adapter.base_pose.duplicate(true)
	posed["origin_records"] = packet.origin_records.duplicate(true)
	posed["observed_not_reposed"] = true
	posed["candidate_not_captured_pose"] = false
	posed["arm_realization_verified"] = false
	posed["grip_accepted"] = false
	var articulation := {"valid":violations.is_empty(),"joints":all_joints,"violations":violations,
		"maximum_off_axis_error_rad":maximum_off_axis,"maximum_position_error_m":maximum_position_error,
		"maximum_rotation_metric_error":maximum_metric_error,"angle_numeric_guard_rad":ANGLE_TOLERANCE_RAD,
		"off_axis_numeric_guard_rad":OFF_AXIS_TOLERANCE_RAD,"position_numeric_guard_m":FRAME_TOLERANCE,
		"rotation_metric_numeric_guard":FRAME_TOLERANCE,"physical_ranges_changed":false}
	var view := {"valid":true,"revision":REVISION,"posed":posed,"pose_packet":packet,"digit_states":states,
		"hand_to_world":hand_frame,"hand_to_world_origin_id":ROOT,"observed_not_reposed":true,
		"articulation_valid":articulation.valid,"articulation":articulation,"hypothetical_placement_only":false,
		"production_pose_written":false,"arm_realization_verified":false,"actual_3d_grip_verified":false,"grip_accepted":false,
		"acceptance_requires_articulation_valid":true,"angle_convention":adapter.angle_convention}
	if var_to_bytes(capture) != before: return _fail("source_capture_was_mutated")
	return {"valid":true,"revision":REVISION,"adapter":adapter,"view":view,"articulation":articulation,
		"articulation_valid":articulation.valid,"source_pose_id":capture.pose_id,"source_capture_sha256":_sha256(before),
		"source_capture_unchanged":true,"observed_skin_unchanged":true,"geometry_reposed":false,
		"production_pose_written":false,"arm_realization_verified":false,"actual_3d_grip_verified":false,"grip_accepted":false,
		"observation_ms":float(Time.get_ticks_usec()-started)/1000.0}


func _basis_error(first: Basis, second: Basis) -> float:
	return maxf((first.x-second.x).length(),maxf((first.y-second.y).length(),(first.z-second.z).length()))


func _frame_error(first: Transform3D, second: Transform3D) -> float:
	return maxf(first.origin.distance_to(second.origin),_basis_error(first.basis,second.basis))


func _sha256(bytes: PackedByteArray) -> String:
	var digest := HashingContext.new(); digest.start(HashingContext.HASH_SHA256); digest.update(bytes)
	return digest.finish().hex_encode()


func _fail(reason: String, detail: Dictionary = {}) -> Dictionary:
	return {"valid":false,"reason":reason,"details":detail,"production_pose_written":false,
		"grip_accepted":false,"articulation_valid":false,"arm_realization_verified":false,"actual_3d_grip_verified":false}
