extends RefCounted
class_name CombatRuntimeEntryTransition

## Transient current-pose -> first authored pose. Never stored in a skill.
const Clip = preload("res://core/models/combat_runtime_clip.gd")
const Baker = preload("res://core/resolvers/combat_runtime_clip_baker.gd")
const Channels = preload("res://core/resolvers/combat_runtime_clip_incremental_resolver.gd")
const PreparedCapture = preload("res://runtime/combat/combat_prepared_pose_capture.gd")
const PreparedPose = preload("res://core/models/combat_prepared_pose.gd")
const Attachment = preload("res://core/resolvers/combat_prepared_attachment_resolver.gd")
const ENTRY_DURATION_SECONDS := 0.160

static func capture(actor: Node3D, weapon: Node3D, body: Resource, current_attachment: Dictionary = {}) -> Dictionary:
	if actor == null or weapon == null or body == null or not body.has_solved_replay_track():
		return {}
	if not actor.has_method("capture_runtime_upper_body_pose_frame") or not actor.has_method("capture_runtime_solved_replay_weapon_frame"):
		return {}
	if not body.prepared_entry_destination.is_empty():
		# Replay releases the rig's live acquisition bookkeeping. The owner still
		# knows the current hand intent and may supply it without changing pose.
		var primary_slot: StringName = StringName(current_attachment.get("primary_hand_slot", actor.get("dominant_grip_slot_id")))
		if primary_slot not in [&"hand_right", &"hand_left"]:
			push_warning("Could not capture attached entry: entry_current_primary_hand_unavailable")
			return {"valid": false, "reason": "entry_current_primary_hand_unavailable"}
		var support_slot: StringName = &"hand_left" if primary_slot == &"hand_right" else &"hand_right"
		var support_enabled: bool = bool(current_attachment.get("support_enabled", actor.has_method("is_support_hand_active") and bool(actor.call("is_support_hand_active", support_slot))))
		var captured: Dictionary = PreparedCapture.capture(actor, weapon, primary_slot, body.baked_solved_anchor_node_paths, support_enabled, "", false)
		var validation: Dictionary = PreparedPose.validate(captured)
		if not bool(validation.get("valid", false)) and String(validation.get("reason", "")).contains("constraints"):
			var calibration: Dictionary = _supply_matching_saved_neutrals(captured, body.prepared_entry_destination)
			if bool(calibration.get("valid", false)):
				validation = PreparedPose.validate(captured)
			else:
				validation["calibration_rejection"] = calibration.get("reason", "")
		if not bool(validation.get("valid", false)):
			var constraint_failures := {}
			for slot: Variant in captured.get("arm_constraints_by_slot", {}):
				var packet: Dictionary = captured.arm_constraints_by_slot[slot]
				if not bool(packet.get("valid", false)):
					constraint_failures[slot] = {"reason": packet.get("reason", ""), "missing_bones": packet.get("missing_bones", []), "missing_twist_neutrals": packet.get("missing_twist_neutrals", [])}
			validation["constraint_capture_failures"] = constraint_failures
			push_warning("Could not capture attached entry: " + JSON.stringify(validation))
			return validation
		captured.erase("capture_validation")
		captured["transient_entry_source"] = true
		return captured
	var pose: Dictionary = actor.capture_runtime_upper_body_pose_frame(body.baked_solved_upper_body_bone_names)
	var mounted: Dictionary = actor.capture_runtime_solved_replay_weapon_frame(weapon, body.solved_replay_reference_bone_name, body.baked_solved_anchor_node_paths)
	if not bool(mounted.get("valid", false)):
		return {}
	pose.merge(mounted, true)
	return pose

## Equipped playback does not initialize authoring-only neutral caches. Reuse
## their saved calibration only for the same measured skeleton and constraints;
## current joint rotations never become a substitute neutral pose.
static func _supply_matching_saved_neutrals(current: Dictionary, saved: Dictionary) -> Dictionary:
	if not bool(PreparedPose.validate(saved).get("valid", false)):
		return {"valid": false, "reason": "saved_neutral_source_invalid"}
	for field: String in ["bone_names", "parent_indices"]:
		if current.get(field) != saved.get(field):
			return {"valid": false, "reason": "neutral_calibration_layout_changed:" + field}
	for field: String in ["bone_rest_transforms", "pose_scales"]:
		var a: Variant = current.get(field, [])
		var b: Variant = saved.get(field, [])
		if a.size() != b.size():
			return {"valid": false, "reason": "neutral_calibration_dimensions_changed:" + field}
		for index: int in a.size():
			if not a[index].is_finite() or not b[index].is_finite() or not a[index].is_equal_approx(b[index]):
				return {"valid": false, "reason": "neutral_calibration_dimensions_changed:%s:%s:%s:%s" % [field, current.bone_names[index], a[index], b[index]]}
	# Pose translation of the pelvis/spine is authored motion, not a different
	# hand calibration. Only arm/helper local offsets determine this calibration's
	# link dimensions; all bones still require identical topology, rest and scale.
	var dimension_bones: Array[StringName] = []
	for packet: Dictionary in saved.arm_constraints_by_slot.values():
		for field: String in ["clavicle_bone", "upperarm_bone", "forearm_bone", "hand_bone"]:
			dimension_bones.append(packet[field])
		for chain: Array in packet.twist_chains:
			for bone: StringName in chain: dimension_bones.append(bone)
	if current.get("pose_positions", []).size() != saved.pose_positions.size():
		return {"valid": false, "reason": "neutral_calibration_position_count_changed"}
	var translation_differences: Array[Dictionary] = []
	for index: int in current.pose_positions.size():
		var actual_position: Vector3 = current.pose_positions[index]
		var saved_position: Vector3 = saved.pose_positions[index]
		if not actual_position.is_finite() or not saved_position.is_finite():
			return {"valid": false, "reason": "neutral_calibration_nonfinite_position"}
		if not actual_position.is_equal_approx(saved_position):
			var bone: StringName = current.bone_names[index]
			if dimension_bones.has(bone):
				return {"valid": false, "reason": "neutral_calibration_arm_dimension_changed:%s:%s:%s" % [bone, actual_position, saved_position]}
			translation_differences.append({"bone": bone, "current": actual_position, "saved": saved_position})
	var packets: Dictionary = current.get("arm_constraints_by_slot", {}).duplicate(true)
	var restored: Array[StringName] = []
	for slot: Variant in packets:
		if not saved.arm_constraints_by_slot.has(slot):
			return {"valid": false, "reason": "neutral_calibration_slot_missing"}
		var actual: Dictionary = packets[slot]
		var baseline: Dictionary = saved.arm_constraints_by_slot[slot]
		if not bool(baseline.get("valid", false)) or not (actual.get("missing_bones", []) as Array).is_empty():
			return {"valid": false, "reason": "neutral_calibration_bones_unavailable"}
		for field: String in ["slot_id", "clavicle_bone", "upperarm_bone", "forearm_bone", "hand_bone", "twist_chains", "limb_twist_axis", "shoulder_min_degrees", "shoulder_max_degrees", "elbow_min_degrees", "elbow_max_degrees", "joint_epsilon_degrees", "limb_twist_limit_radians", "usable_reach_m", "contact_wrist_twist_limit_degrees", "contact_wrist_basis_enabled", "limb_twist_distribution_enabled"]:
			if not actual.has(field) or not baseline.has(field):
				return {"valid": false, "reason": "neutral_calibration_constraint_missing:" + field}
			var a: Variant = actual[field]
			var b: Variant = baseline[field]
			var matches: bool = is_equal_approx(float(a), float(b)) if (a is float or a is int) and (b is float or b is int) else a == b
			if not matches:
				return {"valid": false, "reason": "neutral_calibration_constraint_changed:" + field}
		var neutrals: Dictionary = actual.get("twist_neutral_rotations", {})
		for chain: Array in actual.twist_chains:
			for bone: StringName in chain:
				if not current.bone_names.has(bone): continue
				var neutral: Variant = baseline.twist_neutral_rotations.get(bone)
				if not neutral is Quaternion or not neutral.is_finite() or neutral.length_squared() <= 0.000001:
					return {"valid": false, "reason": "saved_neutral_calibration_missing"}
				if neutrals.has(bone):
					var existing: Variant = neutrals[bone]
					if not existing is Quaternion or not existing.is_finite() or existing.length_squared() <= 0.000001 or absf(existing.normalized().dot(neutral.normalized())) < 0.999999:
						return {"valid": false, "reason": "current_neutral_calibration_differs"}
				else:
					neutrals[bone] = neutral
					restored.append(bone)
		actual["twist_neutral_rotations"] = neutrals
		actual["missing_twist_neutrals"] = []
		actual["valid"] = true
		actual["reason"] = ""
	current["arm_constraints_by_slot"] = packets
	current["entry_neutral_calibration_source"] = "matching_saved_skeleton"
	current["entry_restored_neutral_bones"] = restored
	current["entry_nonarm_translation_differences"] = translation_differences
	return {"valid": true, "reason": ""}

static func build(body: Resource, incoming: Dictionary, source_node: Resource, volume_config: Dictionary = {}) -> Resource:
	if not _valid_source(body, incoming) or source_node == null:
		return null
	var start: Resource = source_node.duplicate_node()
	var destination: Resource = body.motion_node_chain[0].duplicate_node()
	start.node_index = 0
	destination.node_index = 1
	destination.transition_duration_seconds = ENTRY_DURATION_SECONDS
	# Entry is a transient motion bridge, not a new authored grip-swap node.
	start.tip_curve_in_handle = Vector3.ZERO
	start.tip_curve_out_handle = Vector3.ZERO
	start.pommel_curve_in_handle = Vector3.ZERO
	start.pommel_curve_out_handle = Vector3.ZERO
	destination.tip_curve_in_handle = Vector3.ZERO
	destination.pommel_curve_in_handle = Vector3.ZERO
	var prefix: Resource = Baker.new().bake_from_motion_node_chain([start, destination], {
		"sample_rate_hz": Clip.SAMPLE_RATE_HZ,
		"source_weapon_length_meters": body.source_weapon_length_meters,
		"trajectory_volume_config": volume_config,
	})
	if prefix == null:
		return null
	var prefix_count := 0
	for time: float in prefix.baked_frame_times:
		if time < ENTRY_DURATION_SECONDS - 0.000001:
			prefix_count += 1
	# Body frame zero is the exact entry endpoint; no duplicated time sample.
	var combined: Resource = body.duplicate_clip()
	for field: StringName in Channels.INPUT_FRAME_FIELDS:
		var body_values: Variant = body.get(field)
		var prefix_values: Variant = prefix.get(field)
		if body_values.size() != body.get_frame_count() or prefix_values.size() < prefix_count:
			return null
		var values: Variant = prefix_values.slice(0, prefix_count)
		for index: int in body.get_frame_count():
			values.append(float(body_values[index]) + ENTRY_DURATION_SECONDS if field == &"baked_frame_times" else body_values[index])
		combined.set(field, values)
	var source_channels := {
		&"baked_solved_upper_body_pose_positions": incoming.pose_positions,
		&"baked_solved_upper_body_pose_rotations": incoming.pose_rotations,
		&"baked_solved_upper_body_pose_scales": incoming.pose_scales,
		&"baked_solved_weapon_positions_reference_local": incoming.weapon_position_reference_local,
		&"baked_solved_weapon_rotations_reference_local": _pack(incoming.weapon_rotation_reference_local),
		&"baked_solved_weapon_scales_reference_local": incoming.weapon_scale_reference_local,
		&"baked_solved_anchor_positions_weapon_local": incoming.anchor_positions_weapon_local,
		&"baked_solved_anchor_rotations_weapon_local": incoming.anchor_rotations_weapon_local,
		&"baked_solved_anchor_scales_weapon_local": incoming.anchor_scales_weapon_local,
	}
	for field: StringName in Channels.SOLVED_FRAME_FIELDS:
		var body_values: Variant = body.get(field)
		var values: Variant = body_values.slice(0, 0)
		for index: int in prefix_count:
			var ratio: float = float(prefix.baked_frame_times[index]) / ENTRY_DURATION_SECONDS
			ratio = ratio * ratio * (3.0 - 2.0 * ratio)
			values.append(true if field == &"baked_solved_replay_frame_available" else _blend(source_channels[field], body_values[0], ratio, String(field).contains("rotation")))
		values.append_array(body_values)
		combined.set(field, values)
	if not body.prepared_entry_destination.is_empty():
		var attached: Dictionary = _attach_prefix(combined, incoming, body.prepared_entry_destination, start, destination, prefix_count)
		if not bool(attached.get("valid", false)):
			push_warning("Could not prepare attached entry: " + JSON.stringify(attached))
			return null
		combined.set_meta("entry_attachment_diagnostics", attached.diagnostics)
	if body.has_upper_body_pose_track():
		var legacy: Array = []
		for index: int in prefix_count:
			var mapped := PackedVector4Array()
			for bone: StringName in body.baked_upper_body_bone_names:
				var solved_index: int = body.baked_solved_upper_body_bone_names.find(bone)
				if solved_index < 0:
					return null
				mapped.append(combined.baked_solved_upper_body_pose_rotations[index][solved_index])
			legacy.append(mapped)
		legacy.append_array(body.baked_upper_body_bone_pose_rotations)
		combined.baked_upper_body_bone_pose_rotations = legacy
	var chain: Array[Resource] = [start, destination]
	for index: int in range(1, body.motion_node_chain.size()):
		chain.append(body.motion_node_chain[index].duplicate_node())
	combined.motion_node_chain = chain
	combined.total_duration_seconds = ENTRY_DURATION_SECONDS + body.total_duration_seconds
	combined.set_meta("entry_duration_seconds", ENTRY_DURATION_SECONDS)
	combined.set_meta("entry_source", "current_solved_pose")
	var bridge_flags: Array = []
	for index: int in combined.get_frame_count():
		bridge_flags.append(index < prefix_count)
	combined.set_meta("baked_solved_replay_bridge_frame", bridge_flags)
	combined.normalize()
	return combined

static func _valid_source(body: Resource, incoming: Dictionary) -> bool:
	if body == null or not body.has_solved_replay_track() or body.motion_node_chain.is_empty():
		return _source_failure("missing_body_track_or_motion_chain")
	if not bool(incoming.get("valid", false)) or not bool(body.baked_solved_replay_frame_available[0]):
		return _source_failure("incoming_capture_or_body_first_frame_unavailable:" + String(incoming.get("reason", "")))
	if not body.prepared_entry_destination.is_empty():
		var source_check: Dictionary = PreparedPose.validate(incoming)
		if not bool(source_check.get("valid", false)):
			return _source_failure("incoming:" + String(source_check.get("reason", "")))
		var destination_check: Dictionary = PreparedPose.validate(body.prepared_entry_destination)
		if not bool(destination_check.get("valid", false)):
			return _source_failure("destination:" + String(destination_check.get("reason", "")))
		for field: String in ["bone_names", "parent_indices", "bone_rest_transforms"]:
			if incoming.get(field) != body.prepared_entry_destination.get(field):
				return _source_failure("prepared_layout_changed:" + field)
	if incoming.get("bone_names", []) != body.baked_solved_upper_body_bone_names or incoming.get("anchor_node_paths", []) != body.baked_solved_anchor_node_paths:
		return _source_failure("incoming_bone_or_anchor_names_differ")
	for field: String in ["pose_positions", "pose_rotations", "pose_scales"]:
		if incoming.get(field, []).size() != body.baked_solved_upper_body_bone_names.size():
			return _source_failure("incoming_channel_size:" + field)
	for field: String in ["anchor_positions_weapon_local", "anchor_rotations_weapon_local", "anchor_scales_weapon_local"]:
		if incoming.get(field, []).size() != body.baked_solved_anchor_node_paths.size():
			return _source_failure("incoming_anchor_channel_size:" + field)
	var valid: bool = (incoming.get("reference_bone_name") == body.solved_replay_reference_bone_name
		and incoming.get("reference_origin_id") == body.solved_replay_reference_origin_id
		and incoming.get("weapon_reference_origin_id") == body.baked_solved_weapon_reference_origin_id
		and incoming.get("anchor_origin_id") == body.baked_solved_anchor_origin_id
		and incoming.get("weapon_position_reference_local") is Vector3
		and incoming.get("weapon_rotation_reference_local") is Quaternion
		and incoming.get("weapon_scale_reference_local") is Vector3)
	return valid or _source_failure("incoming_coordinate_or_weapon_contract_mismatch")

static func _source_failure(reason: String) -> bool:
	push_warning("Could not prepare entry source: " + reason)
	return false

static func _attach_prefix(combined: Resource, incoming: Dictionary, destination: Dictionary, source_node: Resource, destination_node: Resource, prefix_count: int) -> Dictionary:
	var rows: Array[Dictionary] = []
	var calls := 0
	for index: int in prefix_count:
		var ratio: float = float(combined.baked_frame_times[index]) / ENTRY_DURATION_SECONDS
		ratio = ratio * ratio * (3.0 - 2.0 * ratio)
		var parents: Array[Transform3D] = []
		for parent: int in incoming.parent_reference_transforms.size():
			parents.append((incoming.parent_reference_transforms[parent] as Transform3D).interpolate_with(destination.parent_reference_transforms[parent], ratio))
		var rotation: Vector4 = combined.baked_solved_weapon_rotations_reference_local[index]
		var weapon := Transform3D(Basis(Quaternion(rotation.x, rotation.y, rotation.z, rotation.w).normalized()).scaled(combined.baked_solved_weapon_scales_reference_local[index]), combined.baked_solved_weapon_positions_reference_local[index])
		var sample := {
			"pose_positions": combined.baked_solved_upper_body_pose_positions[index],
			"pose_rotations": combined.baked_solved_upper_body_pose_rotations[index],
			"pose_scales": combined.baked_solved_upper_body_pose_scales[index],
			"parent_reference_transforms": parents,
			"weapon_transform": weapon,
		}
		var result: Dictionary = Attachment.apply(sample, incoming, destination, ratio, source_node, destination_node)
		if not bool(result.get("valid", false)):
			return result.merged({"frame_index": index, "entry_time_seconds": combined.baked_frame_times[index]})
		combined.baked_solved_upper_body_pose_rotations[index] = result.pose_rotations
		calls += int(result.get("ik_calls", 0))
		rows.append(result.get("diagnostics", {}))
	return {"valid": true, "diagnostics": {"arm_follow_calls": calls, "acquisition_calls": 0, "frames": rows}}

static func _blend(source: Variant, destination: Variant, ratio: float, rotation: bool) -> Variant:
	if source is Vector3:
		return source.lerp(destination, ratio)
	if source is Vector4:
		return _pack(Quaternion(source.x, source.y, source.z, source.w).slerp(Quaternion(destination.x, destination.y, destination.z, destination.w), ratio).normalized())
	var result: Variant = source.slice(0, 0)
	for index: int in source.size():
		result.append(_blend(source[index], destination[index], ratio, rotation))
	return result

static func _pack(value: Quaternion) -> Vector4:
	return Vector4(value.x, value.y, value.z, value.w)
