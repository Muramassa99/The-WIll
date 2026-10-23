extends RefCounted
class_name CombatRuntimeClipIncrementalResolver

## Value-only comparison; never normalizes or changes either clip. The caller
## must separately match actor/weapon/configuration, effective base-node fields,
## and the solver continuation checkpoint. Matching inputs alone cannot restore
## accumulated solver state. Total duration and compiled-chain size may differ.
const INPUT_FRAME_FIELDS: Array[StringName] = [
	&"baked_frame_times",
	&"baked_tip_positions_local", &"baked_pommel_positions_local",
	&"baked_weapon_orientation_degrees", &"baked_weapon_roll_degrees",
	&"baked_axial_reposition_offsets", &"baked_grip_seat_slide_offsets",
	&"baked_secondary_grip_seat_slide_offsets", &"baked_body_support_blends",
	&"baked_right_upperarm_roll_degrees", &"baked_left_upperarm_roll_degrees",
	&"baked_right_hand_proxy_authored", &"baked_right_hand_proxy_tip_positions_local",
	&"baked_right_hand_proxy_pommel_positions_local", &"baked_left_hand_proxy_authored",
	&"baked_left_hand_proxy_tip_positions_local", &"baked_left_hand_proxy_pommel_positions_local",
	&"baked_contact_grip_axes_local", &"baked_contact_axis_override_active",
	&"baked_two_hand_states", &"baked_primary_hand_slots", &"baked_grip_style_modes",
]

const INPUT_METADATA_FIELDS: Array[StringName] = [
	&"schema_version", &"clip_id", &"clip_kind", &"source_draft_id",
	&"source_skill_slot_id", &"source_idle_context_id", &"source_equipment_slot_id",
	&"source_weapon_wip_id", &"source_weapon_length_meters",
	&"playback_speed_scale", &"loop_enabled", &"sample_rate_hz",
	&"baked_tip_positions_origin_id", &"baked_pommel_positions_origin_id",
	&"baked_right_hand_proxy_tip_positions_origin_id", &"baked_right_hand_proxy_pommel_positions_origin_id",
	&"baked_left_hand_proxy_tip_positions_origin_id", &"baked_left_hand_proxy_pommel_positions_origin_id",
	&"baked_contact_grip_axes_origin_id", &"solved_replay_reference_bone_name",
	&"solved_replay_reference_origin_id", &"baked_solved_weapon_reference_origin_id",
	&"baked_solved_anchor_origin_id",
]

const SOLVED_FRAME_FIELDS: Array[StringName] = [
	&"baked_solved_replay_frame_available",
	&"baked_solved_upper_body_pose_positions", &"baked_solved_upper_body_pose_rotations",
	&"baked_solved_upper_body_pose_scales", &"baked_solved_weapon_positions_reference_local",
	&"baked_solved_weapon_rotations_reference_local", &"baked_solved_weapon_scales_reference_local",
	&"baked_solved_anchor_positions_weapon_local", &"baked_solved_anchor_rotations_weapon_local",
	&"baked_solved_anchor_scales_weapon_local",
]

const SOLVED_METADATA_FIELDS: Array[StringName] = [
	&"upper_body_pose_track_source", &"baked_upper_body_bone_names",
	&"solved_replay_track_source", &"solved_replay_reference_bone_name",
	&"solved_replay_reference_origin_id", &"baked_solved_upper_body_bone_names",
	&"baked_solved_weapon_reference_origin_id", &"baked_solved_anchor_node_paths",
	&"baked_solved_anchor_origin_id",
]

static func matching_prefix_count(previous_clip: CombatRuntimeClip, next_clip: CombatRuntimeClip) -> int:
	if previous_clip == null or next_clip == null:
		return 0
	for field: StringName in INPUT_METADATA_FIELDS:
		if not _same_finite_value(previous_clip.get(field), next_clip.get(field)):
			return 0
	var previous_count: int = previous_clip.get_frame_count()
	var next_count: int = next_clip.get_frame_count()
	var count: int = mini(previous_count, next_count)
	if count <= 0:
		return 0
	var previous_arrays: Array = []
	var next_arrays: Array = []
	for field: StringName in INPUT_FRAME_FIELDS:
		var previous_values: Variant = previous_clip.get(field)
		var next_values: Variant = next_clip.get(field)
		if typeof(previous_values) != typeof(next_values):
			return 0
		# Incomplete packets could fall back to the selected node during baking.
		# They cannot prove a reusable prefix even if their available values match.
		if previous_values.size() != previous_count or next_values.size() != next_count:
			return 0
		previous_arrays.append(previous_values)
		next_arrays.append(next_values)
	for frame: int in count:
		var timestamp: float = previous_clip.baked_frame_times[frame]
		if timestamp < 0.0 or (frame > 0 and timestamp <= previous_clip.baked_frame_times[frame - 1]):
			return frame
		for channel: int in INPUT_FRAME_FIELDS.size():
			if not _same_finite_value(previous_arrays[channel][frame], next_arrays[channel][frame]):
				return frame
	return count

## Returns independently owned solved arrays under their clip-property keys.
## Empty means no usable requested prefix. This does not restore solver state,
## copy motion inputs, mark a destination ready, or publish a partial clip.
static func solved_prefix_data(previous_clip: CombatRuntimeClip, count: int) -> Dictionary:
	if previous_clip == null or count <= 0 or count > previous_clip.get_frame_count():
		return {}
	if not previous_clip.has_solved_replay_track():
		return {}
	var bone_count: int = previous_clip.baked_solved_upper_body_bone_names.size()
	var anchor_count: int = previous_clip.baked_solved_anchor_node_paths.size()
	for frame: int in count:
		if previous_clip.baked_solved_replay_frame_available[frame] != true:
			return {}
		for field: StringName in SOLVED_FRAME_FIELDS:
			if field == &"baked_solved_replay_frame_available":
				continue
			var value: Variant = previous_clip.get(field)[frame]
			if value is Array or value is PackedVector3Array or value is PackedVector4Array:
				var expected: int = anchor_count if String(field).contains("anchor") else bone_count
				if value.size() != expected:
					return {}
				for component: Variant in value:
					if not _same_finite_value(component, component):
						return {}
			elif not _same_finite_value(value, value):
				return {}
	var data: Dictionary = {}
	for field: StringName in SOLVED_METADATA_FIELDS:
		var value: Variant = previous_clip.get(field)
		data[field] = value.duplicate(true) if value is Array else value
	for field: StringName in SOLVED_FRAME_FIELDS:
		data[field] = _copy_frame_prefix(previous_clip.get(field), count)
	var legacy: Array = previous_clip.baked_upper_body_bone_pose_rotations
	data[&"baked_upper_body_bone_pose_rotations"] = _copy_frame_prefix(legacy, count) if legacy.size() >= count else []
	return data

static func _same_finite_value(left: Variant, right: Variant) -> bool:
	if typeof(left) != typeof(right):
		return false
	if left is float and (not is_finite(left) or not is_finite(right)):
		return false
	if left is Vector3 or left is Vector4 or left is Quaternion:
		if not left.is_finite() or not right.is_finite():
			return false
	return left == right

static func _copy_frame_prefix(values: Variant, count: int) -> Variant:
	if not values is Array:
		return values.slice(0, count)
	var result: Array = []
	for frame: int in count:
		var value: Variant = values[frame]
		if value is Array:
			result.append(value.duplicate(true))
		elif value is PackedVector3Array or value is PackedVector4Array:
			result.append(value.duplicate())
		else:
			result.append(value)
	return result
