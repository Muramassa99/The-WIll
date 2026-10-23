extends RefCounted
class_name CombatRuntimeEntryTransition

## Transient current-pose -> first authored pose. Never stored in a skill.
const Clip = preload("res://core/models/combat_runtime_clip.gd")
const Baker = preload("res://core/resolvers/combat_runtime_clip_baker.gd")
const Channels = preload("res://core/resolvers/combat_runtime_clip_incremental_resolver.gd")
const ENTRY_DURATION_SECONDS := 0.160

static func capture(actor: Node3D, weapon: Node3D, body: Resource) -> Dictionary:
	if actor == null or weapon == null or body == null or not body.has_solved_replay_track():
		return {}
	if not actor.has_method("capture_runtime_upper_body_pose_frame") or not actor.has_method("capture_runtime_solved_replay_weapon_frame"):
		return {}
	var pose: Dictionary = actor.capture_runtime_upper_body_pose_frame(body.baked_solved_upper_body_bone_names)
	var mounted: Dictionary = actor.capture_runtime_solved_replay_weapon_frame(weapon, body.solved_replay_reference_bone_name, body.baked_solved_anchor_node_paths)
	if not bool(mounted.get("valid", false)):
		return {}
	pose.merge(mounted, true)
	return pose

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
		return false
	if not bool(incoming.get("valid", false)) or not bool(body.baked_solved_replay_frame_available[0]):
		return false
	if incoming.get("bone_names", []) != body.baked_solved_upper_body_bone_names or incoming.get("anchor_node_paths", []) != body.baked_solved_anchor_node_paths:
		return false
	for field: String in ["pose_positions", "pose_rotations", "pose_scales"]:
		if incoming.get(field, []).size() != body.baked_solved_upper_body_bone_names.size():
			return false
	for field: String in ["anchor_positions_weapon_local", "anchor_rotations_weapon_local", "anchor_scales_weapon_local"]:
		if incoming.get(field, []).size() != body.baked_solved_anchor_node_paths.size():
			return false
	return (incoming.get("reference_bone_name") == body.solved_replay_reference_bone_name
		and incoming.get("reference_origin_id") == body.solved_replay_reference_origin_id
		and incoming.get("weapon_reference_origin_id") == body.baked_solved_weapon_reference_origin_id
		and incoming.get("anchor_origin_id") == body.baked_solved_anchor_origin_id
		and incoming.get("weapon_position_reference_local") is Vector3
		and incoming.get("weapon_rotation_reference_local") is Quaternion
		and incoming.get("weapon_scale_reference_local") is Vector3)

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
