extends RefCounted
class_name PlayerRigFingerGripPresenter

const JosieRigScene = preload("res://Josie/josie.tscn")
const SLOT_RIGHT: StringName = &"hand_right"
const SLOT_LEFT: StringName = &"hand_left"
const FINGER_IDS: Array[StringName] = [&"thumb", &"index", &"middle", &"ring", &"pinky"]
const IDLE_BASELINE_ANIMATION_NAME: StringName = &"Idle"
const IDLE_BASELINE_SAMPLE_RATIO: float = 0.5
const GRIP_BASELINE_ANIMATION_NAMES: Array[StringName] = [&"SlowRun", &"Run"]
const GRIP_BASELINE_SAMPLE_RATIOS: Array[float] = [0.2, 0.5, 0.8]
const CURL_TRAJECTORY_SAMPLE_STEPS: int = 18
const PINKY_MAX_CURL_T: float = 0.58
const CONTACT_GROUP_MAX_CURL_DEGREES: float = 90.0
const CONTACT_READINESS_META := "finger_grip_contact_readiness"
const CONTACT_DISTANCE_META := "finger_grip_contact_distance_meters"
const CONTACT_RAY_DEBUG_META := "finger_grip_contact_ray_debug"
const CONTACT_RAY_DEBUG_LIMIT: int = 96
const CONTACT_FULL_SEAT_MIN_METERS: float = 0.055
const CONTACT_FADE_OUT_MIN_METERS: float = 0.18
const CONTACT_FULL_SEAT_CELL_MULTIPLIER: float = 4.0
const CONTACT_FADE_OUT_CELL_MULTIPLIER: float = 14.0
const SLOT_LABELS := {
	SLOT_RIGHT: "Right",
	SLOT_LEFT: "Left",
}
const FINGER_LABELS := {
	&"thumb": "Thumb",
	&"index": "Index",
	&"middle": "Middle",
	&"ring": "Ring",
	&"pinky": "Pinky",
}
const FINGER_CHAINS := {
	SLOT_RIGHT: {
		&"thumb": {
			"root": &"CC_Base_R_Thumb1",
			"guide": &"CC_Base_R_Thumb2",
			"mid": &"CC_Base_R_Thumb2",
			"end": &"CC_Base_R_Thumb3",
		},
		&"index": {
			"root": &"CC_Base_R_Index1",
			"guide": &"CC_Base_R_Index1",
			"mid": &"CC_Base_R_Index2",
			"end": &"CC_Base_R_Index3",
		},
		&"middle": {
			"root": &"CC_Base_R_Mid1",
			"guide": &"CC_Base_R_Mid1",
			"mid": &"CC_Base_R_Mid2",
			"end": &"CC_Base_R_Mid3",
		},
		&"ring": {
			"root": &"CC_Base_R_Ring1",
			"guide": &"CC_Base_R_Ring1",
			"mid": &"CC_Base_R_Ring2",
			"end": &"CC_Base_R_Ring3",
		},
		&"pinky": {
			"root": &"CC_Base_R_Pinky1",
			"guide": &"CC_Base_R_Pinky1",
			"mid": &"CC_Base_R_Pinky2",
			"end": &"CC_Base_R_Pinky3",
		},
	},
	SLOT_LEFT: {
		&"thumb": {
			"root": &"CC_Base_L_Thumb1",
			"guide": &"CC_Base_L_Thumb2",
			"mid": &"CC_Base_L_Thumb2",
			"end": &"CC_Base_L_Thumb3",
		},
		&"index": {
			"root": &"CC_Base_L_Index1",
			"guide": &"CC_Base_L_Index1",
			"mid": &"CC_Base_L_Index2",
			"end": &"CC_Base_L_Index3",
		},
		&"middle": {
			"root": &"CC_Base_L_Mid1",
			"guide": &"CC_Base_L_Mid1",
			"mid": &"CC_Base_L_Mid2",
			"end": &"CC_Base_L_Mid3",
		},
		&"ring": {
			"root": &"CC_Base_L_Ring1",
			"guide": &"CC_Base_L_Ring1",
			"mid": &"CC_Base_L_Ring2",
			"end": &"CC_Base_L_Ring3",
		},
		&"pinky": {
			"root": &"CC_Base_L_Pinky1",
			"guide": &"CC_Base_L_Pinky1",
			"mid": &"CC_Base_L_Pinky2",
			"end": &"CC_Base_L_Pinky3",
		},
	},
}
const FINGER_BASELINE_ROTATION_BONES := {
	SLOT_RIGHT: [
		&"CC_Base_R_Thumb1",
		&"CC_Base_R_Thumb2",
		&"CC_Base_R_Thumb3",
		&"CC_Base_R_Index1",
		&"CC_Base_R_Index2",
		&"CC_Base_R_Index3",
		&"CC_Base_R_Mid1",
		&"CC_Base_R_Mid2",
		&"CC_Base_R_Mid3",
		&"CC_Base_R_Ring1",
		&"CC_Base_R_Ring2",
		&"CC_Base_R_Ring3",
		&"CC_Base_R_Pinky1",
		&"CC_Base_R_Pinky2",
		&"CC_Base_R_Pinky3",
	],
	SLOT_LEFT: [
		&"CC_Base_L_Thumb1",
		&"CC_Base_L_Thumb2",
		&"CC_Base_L_Thumb3",
		&"CC_Base_L_Index1",
		&"CC_Base_L_Index2",
		&"CC_Base_L_Index3",
		&"CC_Base_L_Mid1",
		&"CC_Base_L_Mid2",
		&"CC_Base_L_Mid3",
		&"CC_Base_L_Ring1",
		&"CC_Base_L_Ring2",
		&"CC_Base_L_Ring3",
		&"CC_Base_L_Pinky1",
		&"CC_Base_L_Pinky2",
		&"CC_Base_L_Pinky3",
	],
}
const PALM_TRIANGULATION_BONES := {
	SLOT_RIGHT: {
		"hand": &"CC_Base_R_Hand",
		"thumb2": &"CC_Base_R_Thumb2",
		"index1": &"CC_Base_R_Index1",
		"mid1": &"CC_Base_R_Mid1",
		"mid2": &"CC_Base_R_Mid2",
		"ring1": &"CC_Base_R_Ring1",
		"pinky1": &"CC_Base_R_Pinky1",
	},
	SLOT_LEFT: {
		"hand": &"CC_Base_L_Hand",
		"thumb2": &"CC_Base_L_Thumb2",
		"index1": &"CC_Base_L_Index1",
		"mid1": &"CC_Base_L_Mid1",
		"mid2": &"CC_Base_L_Mid2",
		"ring1": &"CC_Base_L_Ring1",
		"pinky1": &"CC_Base_L_Pinky1",
	},
}
var animation_grip_baseline_cache: Dictionary = {}
var animation_idle_baseline_cache: Dictionary = {}
var animation_grip_baseline_initialized: bool = false

func ensure_finger_target_nodes(targets_root: Node3D) -> Dictionary:
	var target_lookup: Dictionary = {}
	if targets_root == null:
		return target_lookup
	for slot_id: StringName in [SLOT_RIGHT, SLOT_LEFT]:
		var side_root: Node3D = _ensure_named_child_node(
			targets_root,
			"%sFingerGripTargets" % SLOT_LABELS.get(slot_id, "Hand")
		)
		var side_lookup: Dictionary = {}
		for finger_id: StringName in FINGER_IDS:
			side_lookup[finger_id] = _ensure_named_child_node(
				side_root,
				"%sGripTarget" % FINGER_LABELS.get(finger_id, "Finger")
			)
		target_lookup[slot_id] = side_lookup
	return target_lookup

func ensure_finger_ik_modifiers(
	skeleton: Skeleton3D,
	modifier_lookup: Dictionary,
	finger_target_lookup: Dictionary
) -> Dictionary:
	var resolved_lookup: Dictionary = modifier_lookup.duplicate(true)
	if skeleton == null:
		return resolved_lookup
	for slot_id: StringName in [SLOT_RIGHT, SLOT_LEFT]:
		var side_target_lookup: Dictionary = finger_target_lookup.get(slot_id, {})
		var side_chains: Dictionary = FINGER_CHAINS.get(slot_id, {})
		for finger_id: StringName in FINGER_IDS:
			var chain_def: Dictionary = side_chains.get(finger_id, {})
			var target_node: Node3D = side_target_lookup.get(finger_id) as Node3D
			var modifier_key: StringName = StringName("%s_%s" % [String(slot_id), String(finger_id)])
			resolved_lookup[modifier_key] = _ensure_finger_ik_modifier(
				skeleton,
				"%s%sGripIK" % [SLOT_LABELS.get(slot_id, "Hand"), FINGER_LABELS.get(finger_id, "Finger")],
				chain_def.get("root", StringName()),
				chain_def.get("end", StringName()),
				target_node
			)
	return resolved_lookup

func update_finger_grip_targets(
	skeleton: Skeleton3D,
	source_lookup: Dictionary,
	finger_target_lookup: Dictionary,
	get_bone_world_position_callable: Callable,
	smoothing_speed: float,
	delta: float
) -> void:
	if skeleton == null:
		return
	_ensure_animation_grip_baseline_cache()
	for slot_id: StringName in [SLOT_RIGHT, SLOT_LEFT]:
		var side_targets: Dictionary = finger_target_lookup.get(slot_id, {})
		var grip_guide: Node3D = source_lookup.get(slot_id) as Node3D
		if grip_guide == null or not is_instance_valid(grip_guide):
			continue
		_apply_animation_contact_open_pose(skeleton, slot_id)
		var grip_center_node: Node3D = _resolve_grip_center_node(grip_guide)
		_clear_contact_ray_debug(grip_center_node)
		var profile_offsets: Array = grip_center_node.get_meta("grip_shell_profile_offsets_minor", []) as Array
		if profile_offsets.is_empty():
			continue
		var cell_world_size: float = float(grip_center_node.get_meta("grip_shell_cell_world_size", 0.0))
		if cell_world_size <= 0.0:
			continue
		var major_axis_local: Vector3 = grip_center_node.get_meta("grip_shell_major_axis_local", Vector3.FORWARD)
		var minor_axis_a_local: Vector3 = grip_center_node.get_meta("grip_shell_minor_axis_a_local", Vector3.RIGHT)
		var minor_axis_b_local: Vector3 = grip_center_node.get_meta("grip_shell_minor_axis_b_local", Vector3.UP)
		var center_world: Vector3 = grip_center_node.global_position
		var major_axis_world: Vector3 = (grip_center_node.global_basis * major_axis_local).normalized()
		var minor_axis_a_world: Vector3 = (grip_center_node.global_basis * minor_axis_a_local).normalized()
		var minor_axis_b_world: Vector3 = (grip_center_node.global_basis * minor_axis_b_local).normalized()
		var contact_axes: Dictionary = _resolve_roll_decoupled_contact_axes(
			skeleton,
			slot_id,
			major_axis_world,
			minor_axis_a_world,
			minor_axis_b_world
		)
		minor_axis_a_world = contact_axes.get("minor_axis_a_world", minor_axis_a_world) as Vector3
		minor_axis_b_world = contact_axes.get("minor_axis_b_world", minor_axis_b_world) as Vector3
		var side_chains: Dictionary = FINGER_CHAINS.get(slot_id, {})
		var palm_frame: Dictionary = _build_palm_frame(
			slot_id,
			get_bone_world_position_callable,
			center_world,
			major_axis_world,
			minor_axis_a_world,
			minor_axis_b_world
		)
		if palm_frame.is_empty():
			continue
		var contact_group_center_world: Vector3 = palm_frame.get("center_world", center_world) as Vector3
		var contact_distance_meters: float = contact_group_center_world.distance_to(center_world)
		var contact_readiness: float = _resolve_grip_contact_readiness(contact_distance_meters, cell_world_size)
		_set_source_contact_readiness(grip_guide, grip_center_node, contact_readiness, contact_distance_meters)
		for finger_id: StringName in FINGER_IDS:
			var target_node: Node3D = side_targets.get(finger_id) as Node3D
			var chain_def: Dictionary = side_chains.get(finger_id, {})
			if target_node == null:
				continue
			var desired_position: Vector3 = _resolve_animation_baseline_tip_world_position_from_cache(
				skeleton,
				animation_idle_baseline_cache,
				slot_id,
				finger_id
			)
			if contact_readiness > 0.001:
				if _finger_uses_plane_curl_path(finger_id):
					desired_position = _resolve_plane_curl_finger_target_world_position(
						skeleton,
						slot_id,
						finger_id,
						chain_def,
						grip_center_node,
						cell_world_size,
						contact_readiness
					)
				else:
					desired_position = _resolve_finger_target_world_position(
						skeleton,
						slot_id,
						finger_id,
						chain_def,
						grip_center_node,
						palm_frame,
						center_world,
						profile_offsets,
						cell_world_size,
						major_axis_world,
						minor_axis_a_world,
						minor_axis_b_world,
						get_bone_world_position_callable
					)
			_move_target_toward(target_node, desired_position, smoothing_speed, delta)

func _resolve_roll_decoupled_contact_axes(
	skeleton: Skeleton3D,
	slot_id: StringName,
	major_axis_world: Vector3,
	fallback_minor_axis_a_world: Vector3,
	fallback_minor_axis_b_world: Vector3
) -> Dictionary:
	var major_axis: Vector3 = major_axis_world.normalized()
	if major_axis.length_squared() <= 0.000001:
		return {
			"minor_axis_a_world": fallback_minor_axis_a_world,
			"minor_axis_b_world": fallback_minor_axis_b_world,
		}
	var hand_name: StringName = (PALM_TRIANGULATION_BONES.get(slot_id, {}) as Dictionary).get("hand", StringName())
	var hand_index: int = skeleton.find_bone(String(hand_name)) if skeleton != null else -1
	var preferred_up: Vector3 = fallback_minor_axis_b_world
	if hand_index >= 0:
		var hand_pose: Transform3D = skeleton.get_bone_global_pose(hand_index)
		preferred_up = (skeleton.global_basis * hand_pose.basis).orthonormalized().y
	preferred_up = preferred_up - major_axis * preferred_up.dot(major_axis)
	if preferred_up.length_squared() <= 0.000001:
		preferred_up = fallback_minor_axis_b_world - major_axis * fallback_minor_axis_b_world.dot(major_axis)
	if preferred_up.length_squared() <= 0.000001:
		preferred_up = Vector3.UP - major_axis * Vector3.UP.dot(major_axis)
	if preferred_up.length_squared() <= 0.000001:
		preferred_up = Vector3.RIGHT - major_axis * Vector3.RIGHT.dot(major_axis)
	preferred_up = preferred_up.normalized()
	var minor_axis_a: Vector3 = preferred_up.cross(major_axis).normalized()
	if minor_axis_a.length_squared() <= 0.000001:
		minor_axis_a = fallback_minor_axis_a_world.normalized()
	var minor_axis_b: Vector3 = major_axis.cross(minor_axis_a).normalized()
	if minor_axis_b.length_squared() <= 0.000001:
		minor_axis_b = preferred_up
	return {
		"minor_axis_a_world": minor_axis_a,
		"minor_axis_b_world": minor_axis_b,
	}

func refresh_finger_ik_influences(
	_enable_finger_grip_ik: bool,
	_finger_grip_ik_influence: float,
	modifier_lookup: Dictionary,
	_source_lookup: Dictionary
) -> void:
	# Finger contact is authored by the deterministic open-to-contact curl pass.
	# CCDIK nodes stay inactive so they cannot add unconstrained finger twist.
	for slot_id: StringName in [SLOT_RIGHT, SLOT_LEFT]:
		for finger_id: StringName in FINGER_IDS:
			var modifier: SkeletonModifier3D = modifier_lookup.get(
				StringName("%s_%s" % [String(slot_id), String(finger_id)]),
				null
			) as SkeletonModifier3D
			if modifier == null:
				continue
			var needs_reset: bool = modifier.active or modifier.influence > 0.0
			modifier.active = false
			modifier.influence = 0.0
			if needs_reset and modifier.has_method("reset"):
				modifier.call("reset")

func resolve_hand_grip_alignment_world_position(skeleton: Skeleton3D, slot_id: StringName) -> Vector3:
	if skeleton == null:
		return Vector3.ZERO
	_ensure_animation_grip_baseline_cache()
	return _resolve_hand_grip_center_world_from_cache(skeleton, animation_grip_baseline_cache, slot_id)

func _ensure_named_child_node(parent_node: Node3D, child_name: String) -> Node3D:
	var child_node: Node3D = parent_node.get_node_or_null(child_name) as Node3D
	if child_node == null:
		child_node = Node3D.new()
		child_node.name = child_name
		parent_node.add_child(child_node)
	return child_node

func _ensure_finger_ik_modifier(
	skeleton: Skeleton3D,
	modifier_name: String,
	root_bone_name: StringName,
	end_bone_name: StringName,
	target_node: Node3D
) -> CCDIK3D:
	var modifier: CCDIK3D = skeleton.get_node_or_null(modifier_name) as CCDIK3D
	if modifier == null:
		modifier = CCDIK3D.new()
		modifier.name = modifier_name
		skeleton.add_child(modifier)
	modifier.setting_count = 1
	modifier.mutable_bone_axes = true
	modifier.deterministic = true
	modifier.max_iterations = 6
	modifier.min_distance = 0.0015
	modifier.angular_delta_limit = deg_to_rad(12.0)
	var root_bone_index: int = skeleton.find_bone(String(root_bone_name))
	var end_bone_index: int = skeleton.find_bone(String(end_bone_name))
	if root_bone_index >= 0:
		modifier.set_root_bone(0, root_bone_index)
	modifier.set_root_bone_name(0, String(root_bone_name))
	if end_bone_index >= 0:
		modifier.set_end_bone(0, end_bone_index)
	modifier.set_end_bone_name(0, String(end_bone_name))
	if target_node != null:
		modifier.set_target_node(0, modifier.get_path_to(target_node))
	modifier.active = false
	modifier.influence = 0.0
	return modifier

func _resolve_grip_center_node(grip_guide: Node3D) -> Node3D:
	if grip_guide == null:
		return null
	var grip_center_node: Node3D = grip_guide.get_node_or_null("GripShellCenter") as Node3D
	return grip_center_node if grip_center_node != null else grip_guide

func _build_palm_frame(
	slot_id: StringName,
	get_bone_world_position_callable: Callable,
	shell_center_world: Vector3,
	major_axis_world: Vector3,
	minor_axis_a_world: Vector3,
	minor_axis_b_world: Vector3
) -> Dictionary:
	var bone_names: Dictionary = PALM_TRIANGULATION_BONES.get(slot_id, {})
	if bone_names.is_empty():
		return {}
	var hand_world: Vector3 = get_bone_world_position_callable.call(bone_names.get("hand", StringName()))
	var thumb2_world: Vector3 = get_bone_world_position_callable.call(bone_names.get("thumb2", StringName()))
	var index1_world: Vector3 = get_bone_world_position_callable.call(bone_names.get("index1", StringName()))
	var mid1_world: Vector3 = get_bone_world_position_callable.call(bone_names.get("mid1", StringName()))
	var mid2_world: Vector3 = get_bone_world_position_callable.call(bone_names.get("mid2", StringName()))
	var ring1_world: Vector3 = get_bone_world_position_callable.call(bone_names.get("ring1", StringName()))
	var pinky1_world: Vector3 = get_bone_world_position_callable.call(bone_names.get("pinky1", StringName()))
	var center_world: Vector3 = (
		hand_world
		+ thumb2_world
		+ index1_world
		+ mid1_world
		+ ring1_world
		+ pinky1_world
	) / 6.0
	var knuckle_span_world: Vector3 = pinky1_world - index1_world
	var thumb_span_world: Vector3 = thumb2_world - hand_world
	var palm_normal_world: Vector3 = (index1_world - hand_world).cross(pinky1_world - hand_world)
	if palm_normal_world.length_squared() <= 0.000001:
		palm_normal_world = (mid1_world - hand_world).cross(ring1_world - hand_world)
	if palm_normal_world.length_squared() <= 0.000001:
		palm_normal_world = major_axis_world.cross(knuckle_span_world)
	if palm_normal_world.length_squared() <= 0.000001:
		palm_normal_world = minor_axis_a_world.cross(minor_axis_b_world)
	palm_normal_world = palm_normal_world.normalized()
	var shell_to_palm: Vector3 = center_world - shell_center_world
	if palm_normal_world.dot(shell_to_palm) < 0.0:
		palm_normal_world = -palm_normal_world
	if knuckle_span_world.length_squared() <= 0.000001:
		knuckle_span_world = minor_axis_a_world
	return {
		"center_world": center_world,
		"hand_world": hand_world,
		"thumb2_world": thumb2_world,
		"index1_world": index1_world,
		"mid1_world": mid1_world,
		"mid2_world": mid2_world,
		"ring1_world": ring1_world,
		"pinky1_world": pinky1_world,
		"thumb_close_world": mid2_world - thumb2_world,
		"knuckle_span_world": knuckle_span_world.normalized(),
		"thumb_span_world": thumb_span_world.normalized() if thumb_span_world.length_squared() > 0.000001 else minor_axis_a_world,
		"palm_normal_world": palm_normal_world,
	}

func _resolve_finger_target_world_position(
	skeleton: Skeleton3D,
	slot_id: StringName,
	finger_id: StringName,
	chain_def: Dictionary,
	grip_center_node: Node3D,
	palm_frame: Dictionary,
	center_world: Vector3,
	profile_offsets: Array,
	cell_world_size: float,
	major_axis_world: Vector3,
	minor_axis_a_world: Vector3,
	minor_axis_b_world: Vector3,
	get_bone_world_position_callable: Callable
) -> Vector3:
	var guide_bone_name: StringName = chain_def.get("guide", chain_def.get("root", StringName()))
	var end_bone_name: StringName = chain_def.get("end", guide_bone_name)
	var guide_position: Vector3 = get_bone_world_position_callable.call(guide_bone_name)
	var end_position: Vector3 = get_bone_world_position_callable.call(end_bone_name)
	var palm_center_world: Vector3 = palm_frame.get("center_world", guide_position)
	var palm_shell_vector: Vector3 = center_world - palm_center_world
	if finger_id == &"thumb":
		return _resolve_thumb_target_world_position(
			skeleton,
			slot_id,
			finger_id,
			chain_def,
			grip_center_node,
			palm_frame,
			center_world,
			profile_offsets,
			cell_world_size,
			major_axis_world,
			minor_axis_a_world,
			minor_axis_b_world,
			get_bone_world_position_callable
		)
	return _resolve_non_thumb_target_world_position(
		skeleton,
		slot_id,
		finger_id,
		chain_def,
		grip_center_node,
		palm_frame,
		center_world,
		palm_center_world,
		guide_position,
		end_position,
		profile_offsets,
		cell_world_size,
		major_axis_world,
		minor_axis_a_world,
		minor_axis_b_world,
		palm_shell_vector,
		get_bone_world_position_callable
	)

func _resolve_non_thumb_target_world_position(
	skeleton: Skeleton3D,
	slot_id: StringName,
	finger_id: StringName,
	chain_def: Dictionary,
	grip_center_node: Node3D,
	palm_frame: Dictionary,
	center_world: Vector3,
	palm_center_world: Vector3,
	guide_position: Vector3,
	end_position: Vector3,
	profile_offsets: Array,
	cell_world_size: float,
	major_axis_world: Vector3,
	minor_axis_a_world: Vector3,
	minor_axis_b_world: Vector3,
	palm_shell_vector: Vector3,
	get_bone_world_position_callable: Callable
) -> Vector3:
	var mid_bone_name: StringName = chain_def.get("mid", chain_def.get("guide", chain_def.get("root", StringName())))
	var mid_position: Vector3 = get_bone_world_position_callable.call(mid_bone_name)
	var lane_vector: Vector3 = guide_position - palm_center_world
	lane_vector -= major_axis_world * lane_vector.dot(major_axis_world)
	if lane_vector.length_squared() <= 0.000001:
		lane_vector = palm_frame.get("knuckle_span_world", minor_axis_a_world)
	var palm_normal_world: Vector3 = palm_frame.get("palm_normal_world", Vector3.ZERO)
	var curl_direction_world: Vector3 = -palm_normal_world
	if curl_direction_world.length_squared() <= 0.000001:
		curl_direction_world = (center_world - guide_position).normalized()
	if curl_direction_world.length_squared() <= 0.000001:
		curl_direction_world = -minor_axis_b_world
	var approach_vector: Vector3 = center_world - guide_position
	var major_offset: float = clampf(
		approach_vector.dot(major_axis_world),
		-cell_world_size * 0.4,
		cell_world_size * 0.4
	)
	var lane_2d: Vector2 = Vector2(
		lane_vector.dot(minor_axis_a_world),
		lane_vector.dot(minor_axis_b_world)
	)
	if lane_2d.length_squared() <= 0.000001:
		lane_2d = Vector2.RIGHT
	var radial_direction_2d: Vector2 = lane_2d.normalized()
	var support_point_2d: Vector2 = _resolve_profile_support_point(profile_offsets, radial_direction_2d, cell_world_size)
	var radial_offset_world: Vector3 = (
		minor_axis_a_world * support_point_2d.x
		+ minor_axis_b_world * support_point_2d.y
	)
	var closure_vector: Vector3 = curl_direction_world
	var mid_alignment_vector: Vector3 = end_position - mid_position
	if mid_alignment_vector.length_squared() > 0.000001:
		var blended_alignment: Vector3 = (curl_direction_world.normalized() * 0.8) + (mid_alignment_vector.normalized() * 0.2)
		if blended_alignment.length_squared() > 0.000001:
			closure_vector = blended_alignment.normalized()
	if closure_vector.length_squared() <= 0.000001:
		closure_vector = palm_shell_vector if palm_shell_vector.length_squared() > 0.000001 else lane_vector
	var radial_clearance: float = cell_world_size * 0.08
	var radial_clearance_world: Vector3 = closure_vector.normalized() * radial_clearance
	var predicted_target: Vector3 = center_world \
		+ major_axis_world * major_offset \
		+ radial_offset_world \
		+ radial_clearance_world
	var cast_from_world: Vector3 = end_position
	var baseline_tip_world: Vector3 = _resolve_animation_baseline_tip_world_position(skeleton, slot_id, finger_id)
	if baseline_tip_world.length_squared() > 0.000001:
		cast_from_world = baseline_tip_world
		predicted_target = baseline_tip_world.lerp(predicted_target, 0.42)
	return _resolve_contact_target_world_position(
		grip_center_node,
		cast_from_world,
		predicted_target,
		cell_world_size,
		closure_vector,
		slot_id,
		finger_id,
		&"surface_contact"
	)

func _resolve_thumb_target_world_position(
	skeleton: Skeleton3D,
	slot_id: StringName,
	finger_id: StringName,
	chain_def: Dictionary,
	grip_center_node: Node3D,
	palm_frame: Dictionary,
	center_world: Vector3,
	profile_offsets: Array,
	cell_world_size: float,
	major_axis_world: Vector3,
	minor_axis_a_world: Vector3,
	minor_axis_b_world: Vector3,
	get_bone_world_position_callable: Callable
) -> Vector3:
	var thumb_guide_name: StringName = chain_def.get("guide", chain_def.get("root", StringName()))
	var thumb_end_name: StringName = chain_def.get("end", thumb_guide_name)
	var thumb_guide_position: Vector3 = get_bone_world_position_callable.call(thumb_guide_name)
	var thumb_end_position: Vector3 = get_bone_world_position_callable.call(thumb_end_name)
	var mid2_position: Vector3 = palm_frame.get("mid2_world", thumb_guide_position)
	var pinky1_position: Vector3 = palm_frame.get("pinky1_world", thumb_guide_position)
	var open_vector: Vector3 = thumb_guide_position - pinky1_position
	var close_vector: Vector3 = mid2_position - thumb_guide_position
	open_vector -= major_axis_world * open_vector.dot(major_axis_world)
	close_vector -= major_axis_world * close_vector.dot(major_axis_world)
	if open_vector.length_squared() <= 0.000001:
		open_vector = _resolve_fallback_radial_world(minor_axis_a_world, minor_axis_b_world, &"thumb")
	if close_vector.length_squared() <= 0.000001:
		close_vector = palm_frame.get("thumb_close_world", minor_axis_a_world)
	var desired_thumb_plane_vector: Vector3 = (close_vector.normalized() * 0.82) + (open_vector.normalized() * 0.28)
	if desired_thumb_plane_vector.length_squared() <= 0.000001:
		desired_thumb_plane_vector = close_vector if close_vector.length_squared() > 0.000001 else open_vector
	var dir_2d: Vector2 = Vector2(
		desired_thumb_plane_vector.dot(minor_axis_a_world),
		desired_thumb_plane_vector.dot(minor_axis_b_world)
	)
	if dir_2d.length_squared() <= 0.000001:
		dir_2d = Vector2(-1.0 if slot_id == SLOT_RIGHT else 1.0, 0.3).normalized()
	var radial_direction_2d: Vector2 = dir_2d.normalized()
	var support_point_2d: Vector2 = _resolve_profile_support_point(profile_offsets, radial_direction_2d, cell_world_size)
	var radial_offset_world: Vector3 = (
		minor_axis_a_world * support_point_2d.x
		+ minor_axis_b_world * support_point_2d.y
	)
	var approach_vector: Vector3 = center_world - thumb_guide_position
	var major_offset: float = clampf(
		approach_vector.dot(major_axis_world),
		-cell_world_size * 0.3,
		cell_world_size * 0.3
	)
	var shell_closure_vector: Vector3 = (center_world + radial_offset_world) - thumb_guide_position
	if shell_closure_vector.length_squared() <= 0.000001:
		shell_closure_vector = desired_thumb_plane_vector
	var radial_clearance_world: Vector3 = shell_closure_vector.normalized() * (cell_world_size * 0.1)
	var predicted_target: Vector3 = center_world \
		+ major_axis_world * major_offset \
		+ radial_offset_world \
		+ radial_clearance_world
	var cast_from_world: Vector3 = thumb_end_position
	var baseline_tip_world: Vector3 = _resolve_animation_baseline_tip_world_position(skeleton, slot_id, finger_id)
	if baseline_tip_world.length_squared() > 0.000001:
		cast_from_world = baseline_tip_world
		predicted_target = baseline_tip_world.lerp(predicted_target, 0.38)
	return _resolve_contact_target_world_position(
		grip_center_node,
		cast_from_world,
		predicted_target,
		cell_world_size,
		shell_closure_vector,
		slot_id,
		finger_id,
		&"thumb_contact"
	)

func _resolve_profile_support_point(profile_offsets: Array, radial_direction_2d: Vector2, cell_world_size: float) -> Vector2:
	var half_extent: float = cell_world_size * 0.5
	var best_point: Vector2 = Vector2.ZERO
	var best_score: float = -INF
	for offset_variant: Variant in profile_offsets:
		var offset: Vector2 = offset_variant as Vector2
		var candidate_point: Vector2 = Vector2(
			offset.x + (half_extent if radial_direction_2d.x >= 0.0 else -half_extent),
			offset.y + (half_extent if radial_direction_2d.y >= 0.0 else -half_extent)
		)
		var candidate_score: float = candidate_point.dot(radial_direction_2d)
		if candidate_score > best_score:
			best_score = candidate_score
			best_point = candidate_point
	return best_point

func _resolve_contact_target_world_position(
	grip_center_node: Node3D,
	cast_from_world: Vector3,
	predicted_target_world: Vector3,
	cell_world_size: float,
	preferred_direction_world: Vector3 = Vector3.ZERO,
	slot_id: StringName = StringName(),
	finger_id: StringName = StringName(),
	ray_context: StringName = &"contact_target"
) -> Vector3:
	if grip_center_node == null or not is_instance_valid(grip_center_node):
		return predicted_target_world
	var world_3d: World3D = grip_center_node.get_world_3d()
	if world_3d == null:
		_record_contact_ray_debug(
			grip_center_node,
			slot_id,
			finger_id,
			ray_context,
			cast_from_world,
			predicted_target_world,
			0,
			{},
			"missing_world"
		)
		return predicted_target_world
	var direction: Vector3 = predicted_target_world - cast_from_world
	if preferred_direction_world.length_squared() > 0.000001:
		direction = preferred_direction_world.normalized() * maxf(direction.length(), cell_world_size * 3.0)
	if direction.length_squared() <= 0.000001:
		_record_contact_ray_debug(
			grip_center_node,
			slot_id,
			finger_id,
			ray_context,
			cast_from_world,
			predicted_target_world,
			0,
			{},
			"empty_direction"
		)
		return predicted_target_world
	var collision_mask: int = int(grip_center_node.get_meta("grip_shell_collision_layer", 0))
	if collision_mask <= 0:
		_record_contact_ray_debug(
			grip_center_node,
			slot_id,
			finger_id,
			ray_context,
			cast_from_world,
			predicted_target_world,
			collision_mask,
			{},
			"missing_collision_mask"
		)
		return predicted_target_world
	var ray_distance: float = maxf(direction.length() + cell_world_size * 2.0, cell_world_size * 4.0)
	var ray_to_world: Vector3 = cast_from_world + direction.normalized() * ray_distance
	var ray_query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		cast_from_world,
		ray_to_world,
		collision_mask
	)
	ray_query.collide_with_areas = true
	ray_query.collide_with_bodies = false
	ray_query.hit_from_inside = true
	var hit: Dictionary = world_3d.direct_space_state.intersect_ray(ray_query)
	_record_contact_ray_debug(
		grip_center_node,
		slot_id,
		finger_id,
		ray_context,
		cast_from_world,
		ray_to_world,
		collision_mask,
		hit
	)
	if hit.is_empty():
		return predicted_target_world
	var hit_position: Vector3 = hit.get("position", predicted_target_world)
	var hit_normal: Vector3 = hit.get("normal", Vector3.ZERO)
	if hit_normal.length_squared() <= 0.000001:
		hit_normal = -direction.normalized()
	return hit_position + hit_normal.normalized() * (cell_world_size * 0.05)

func _resolve_fallback_radial_world(minor_axis_a_world: Vector3, minor_axis_b_world: Vector3, finger_id: StringName) -> Vector3:
	if finger_id == &"thumb":
		return (-minor_axis_a_world + minor_axis_b_world * 0.2).normalized()
	if finger_id == &"pinky":
		return (minor_axis_a_world - minor_axis_b_world * 0.15).normalized()
	return minor_axis_a_world.normalized()

func _move_target_toward(target_node: Node3D, desired_global_position: Vector3, smoothing_speed: float, delta: float) -> void:
	if target_node == null:
		return
	var blend_factor: float = clampf(smoothing_speed * delta, 0.0, 1.0)
	target_node.global_position = target_node.global_position.lerp(desired_global_position, blend_factor)

func _source_is_valid(source_node_variant: Variant) -> bool:
	var source_node: Node3D = source_node_variant as Node3D
	return source_node != null and is_instance_valid(source_node)

func _resolve_grip_contact_readiness(contact_distance_meters: float, cell_world_size: float) -> float:
	var full_seat_distance: float = maxf(
		CONTACT_FULL_SEAT_MIN_METERS,
		cell_world_size * CONTACT_FULL_SEAT_CELL_MULTIPLIER
	)
	var fade_out_distance: float = maxf(
		CONTACT_FADE_OUT_MIN_METERS,
		full_seat_distance + cell_world_size * CONTACT_FADE_OUT_CELL_MULTIPLIER
	)
	if contact_distance_meters <= full_seat_distance:
		return 1.0
	if contact_distance_meters >= fade_out_distance:
		return 0.0
	var fade_t: float = clampf(
		(contact_distance_meters - full_seat_distance) / maxf(fade_out_distance - full_seat_distance, 0.000001),
		0.0,
		1.0
	)
	var smooth_fade_t: float = fade_t * fade_t * (3.0 - 2.0 * fade_t)
	return 1.0 - smooth_fade_t

func _set_source_contact_readiness(
	grip_guide: Node3D,
	grip_center_node: Node3D,
	contact_readiness: float,
	contact_distance_meters: float
) -> void:
	for source_node: Node3D in [grip_guide, grip_center_node]:
		if source_node == null or not is_instance_valid(source_node):
			continue
		source_node.set_meta(CONTACT_READINESS_META, clampf(contact_readiness, 0.0, 1.0))
		source_node.set_meta(CONTACT_DISTANCE_META, maxf(contact_distance_meters, 0.0))

func _clear_contact_ray_debug(grip_center_node: Node3D) -> void:
	if grip_center_node == null or not is_instance_valid(grip_center_node):
		return
	grip_center_node.set_meta(CONTACT_RAY_DEBUG_META, [])

func _record_contact_ray_debug(
	grip_center_node: Node3D,
	slot_id: StringName,
	finger_id: StringName,
	ray_context: StringName,
	from_world: Vector3,
	to_world: Vector3,
	collision_mask: int,
	ray_hit: Dictionary = {},
	skipped_reason: String = ""
) -> void:
	if grip_center_node == null or not is_instance_valid(grip_center_node):
		return
	var has_hit: bool = not ray_hit.is_empty()
	var hit_position: Vector3 = Vector3.ZERO
	var hit_normal: Vector3 = Vector3.ZERO
	var collider_object: Object = null
	if has_hit:
		hit_position = ray_hit.get("position", Vector3.ZERO) as Vector3
		hit_normal = ray_hit.get("normal", Vector3.ZERO) as Vector3
		collider_object = ray_hit.get("collider", null) as Object
	var collider_node: Node = collider_object as Node
	var collider_name: String = ""
	var collider_path: String = ""
	var collider_class: String = ""
	var collider_layer: int = -1
	if collider_object != null:
		collider_class = collider_object.get_class()
	if collider_node != null:
		collider_name = String(collider_node.name)
		collider_path = String(collider_node.get_path())
	var collision_object: CollisionObject3D = collider_node as CollisionObject3D
	if collision_object != null:
		collider_layer = collision_object.collision_layer
	var hit_distance: float = -1.0
	if has_hit:
		hit_distance = from_world.distance_to(hit_position)
	var ray_entries: Array = grip_center_node.get_meta(CONTACT_RAY_DEBUG_META, []) as Array
	ray_entries.append({
		"slot_id": String(slot_id),
		"finger_id": String(finger_id),
		"context": String(ray_context),
		"from_world": from_world,
		"to_world": to_world,
		"collision_mask": collision_mask,
		"hit": has_hit,
		"hit_position": hit_position,
		"hit_normal": hit_normal,
		"hit_distance_meters": hit_distance,
		"collider_name": collider_name,
		"collider_path": collider_path,
		"collider_class": collider_class,
		"collider_layer": collider_layer,
		"skipped_reason": skipped_reason,
	})
	while ray_entries.size() > CONTACT_RAY_DEBUG_LIMIT:
		ray_entries.pop_front()
	grip_center_node.set_meta(CONTACT_RAY_DEBUG_META, ray_entries)

func _resolve_source_contact_readiness(source_node_variant: Variant) -> float:
	if not _source_is_valid(source_node_variant):
		return 0.0
	var source_node: Node3D = source_node_variant as Node3D
	if source_node.has_meta(CONTACT_READINESS_META):
		return clampf(float(source_node.get_meta(CONTACT_READINESS_META, 1.0)), 0.0, 1.0)
	var grip_center_node: Node3D = _resolve_grip_center_node(source_node)
	if grip_center_node != null and grip_center_node.has_meta(CONTACT_READINESS_META):
		return clampf(float(grip_center_node.get_meta(CONTACT_READINESS_META, 1.0)), 0.0, 1.0)
	return 1.0

func _ensure_animation_grip_baseline_cache() -> void:
	if animation_grip_baseline_initialized:
		return
	animation_grip_baseline_initialized = true
	animation_idle_baseline_cache = _build_animation_pose_cache(
		[IDLE_BASELINE_ANIMATION_NAME],
		[IDLE_BASELINE_SAMPLE_RATIO]
	)
	animation_grip_baseline_cache = _build_animation_pose_cache(
		GRIP_BASELINE_ANIMATION_NAMES,
		GRIP_BASELINE_SAMPLE_RATIOS
	)

func _build_animation_pose_cache(animation_names: Array[StringName], sample_ratios: Array[float]) -> Dictionary:
	var baseline_cache: Dictionary = {}
	var rotation_counts: Dictionary = {}
	var tip_counts: Dictionary = {}
	var joint_counts: Dictionary = {}
	for slot_id: StringName in [SLOT_RIGHT, SLOT_LEFT]:
		baseline_cache[slot_id] = {
			"rotations": {},
			"tip_offsets": {},
			"joint_offsets": {},
		}
		rotation_counts[slot_id] = {}
		tip_counts[slot_id] = {}
		joint_counts[slot_id] = {}
	for animation_name: StringName in animation_names:
		for sample_ratio: float in sample_ratios:
			var sample: Dictionary = _sample_animation_hand_pose(animation_name, sample_ratio)
			if sample.is_empty():
				continue
			for slot_id: StringName in [SLOT_RIGHT, SLOT_LEFT]:
				var slot_sample: Dictionary = sample.get(slot_id, {})
				if slot_sample.is_empty():
					continue
				var slot_cache: Dictionary = baseline_cache.get(slot_id, {})
				var slot_rotation_counts: Dictionary = rotation_counts.get(slot_id, {})
				var slot_tip_counts: Dictionary = tip_counts.get(slot_id, {})
				var slot_joint_counts: Dictionary = joint_counts.get(slot_id, {})
				var rotation_cache: Dictionary = slot_cache.get("rotations", {})
				var tip_cache: Dictionary = slot_cache.get("tip_offsets", {})
				var joint_cache: Dictionary = slot_cache.get("joint_offsets", {})
				for bone_name_variant: Variant in (slot_sample.get("rotations", {}) as Dictionary).keys():
					var bone_name: StringName = bone_name_variant as StringName
					var sample_rotation: Quaternion = (slot_sample.get("rotations", {}) as Dictionary).get(
						bone_name,
						Quaternion.IDENTITY
					) as Quaternion
					var count: int = int(slot_rotation_counts.get(bone_name, 0))
					if count <= 0:
						rotation_cache[bone_name] = sample_rotation
					else:
						var blend_weight: float = 1.0 / float(count + 1)
						rotation_cache[bone_name] = (rotation_cache.get(bone_name, Quaternion.IDENTITY) as Quaternion).slerp(
							sample_rotation,
							blend_weight
						)
					slot_rotation_counts[bone_name] = count + 1
				for finger_id_variant: Variant in (slot_sample.get("tip_offsets", {}) as Dictionary).keys():
					var finger_id: StringName = finger_id_variant as StringName
					var sample_offset: Vector3 = (slot_sample.get("tip_offsets", {}) as Dictionary).get(
						finger_id,
						Vector3.ZERO
					) as Vector3
					var tip_count: int = int(slot_tip_counts.get(finger_id, 0))
					if tip_count <= 0:
						tip_cache[finger_id] = sample_offset
					else:
						var blend_weight: float = 1.0 / float(tip_count + 1)
						tip_cache[finger_id] = (tip_cache.get(finger_id, Vector3.ZERO) as Vector3).lerp(
							sample_offset,
							blend_weight
						)
					slot_tip_counts[finger_id] = tip_count + 1
				for finger_id_variant: Variant in (slot_sample.get("joint_offsets", {}) as Dictionary).keys():
					var joint_finger_id: StringName = finger_id_variant as StringName
					var sample_joint_lookup: Dictionary = (slot_sample.get("joint_offsets", {}) as Dictionary).get(
						joint_finger_id,
						{}
					) as Dictionary
					var joint_cache_lookup: Dictionary = joint_cache.get(joint_finger_id, {})
					var joint_count: int = int(slot_joint_counts.get(joint_finger_id, 0))
					for joint_key_variant: Variant in sample_joint_lookup.keys():
						var joint_key: StringName = joint_key_variant as StringName
						var sample_joint_offset: Vector3 = sample_joint_lookup.get(joint_key, Vector3.ZERO) as Vector3
						if joint_count <= 0:
							joint_cache_lookup[joint_key] = sample_joint_offset
						else:
							var joint_blend_weight: float = 1.0 / float(joint_count + 1)
							joint_cache_lookup[joint_key] = (joint_cache_lookup.get(joint_key, Vector3.ZERO) as Vector3).lerp(
								sample_joint_offset,
								joint_blend_weight
							)
					joint_cache[joint_finger_id] = joint_cache_lookup
					slot_joint_counts[joint_finger_id] = joint_count + 1
				slot_cache["rotations"] = rotation_cache
				slot_cache["tip_offsets"] = tip_cache
				slot_cache["joint_offsets"] = joint_cache
				baseline_cache[slot_id] = slot_cache
				rotation_counts[slot_id] = slot_rotation_counts
				tip_counts[slot_id] = slot_tip_counts
				joint_counts[slot_id] = slot_joint_counts
	return baseline_cache

func _sample_animation_hand_pose(animation_name: StringName, sample_ratio: float) -> Dictionary:
	var josie_root: Node3D = JosieRigScene.instantiate() as Node3D
	if josie_root == null:
		return {}
	var animation_player: AnimationPlayer = josie_root.get_node_or_null("AnimationPlayer") as AnimationPlayer
	var skeleton: Skeleton3D = josie_root.get_node_or_null("Josie/Skeleton3D") as Skeleton3D
	if animation_player == null or skeleton == null or not animation_player.has_animation(String(animation_name)):
		josie_root.free()
		return {}
	var animation: Animation = animation_player.get_animation(String(animation_name))
	if animation == null:
		josie_root.free()
		return {}
	animation_player.play(String(animation_name))
	animation_player.advance(animation.length * clampf(sample_ratio, 0.0, 1.0))
	skeleton.force_update_all_bone_transforms()
	var sample: Dictionary = {}
	for slot_id: StringName in [SLOT_RIGHT, SLOT_LEFT]:
		var hand_name: StringName = (PALM_TRIANGULATION_BONES.get(slot_id, {}) as Dictionary).get("hand", StringName())
		var hand_index: int = skeleton.find_bone(String(hand_name))
		if hand_index < 0:
			continue
		var hand_pose: Transform3D = skeleton.get_bone_global_pose(hand_index)
		var hand_inverse: Transform3D = hand_pose.affine_inverse()
		var rotation_lookup: Dictionary = {}
		for bone_name: StringName in FINGER_BASELINE_ROTATION_BONES.get(slot_id, []):
			var bone_index: int = skeleton.find_bone(String(bone_name))
			if bone_index < 0:
				continue
			var bone_pose: Transform3D = skeleton.get_bone_global_pose(bone_index)
			var relative_basis: Basis = hand_pose.basis.inverse() * bone_pose.basis
			rotation_lookup[bone_name] = relative_basis.get_rotation_quaternion()
		var tip_lookup: Dictionary = {}
		var joint_lookup: Dictionary = {}
		var slot_chains: Dictionary = FINGER_CHAINS.get(slot_id, {})
		for finger_id: StringName in FINGER_IDS:
			var chain_def: Dictionary = slot_chains.get(finger_id, {})
			var finger_joint_offsets: Dictionary = {}
			for joint_key: StringName in [&"root", &"guide", &"mid", &"end"]:
				var joint_bone_name: StringName = chain_def.get(joint_key, StringName())
				var joint_bone_index: int = skeleton.find_bone(String(joint_bone_name))
				if joint_bone_index < 0:
					continue
				var joint_pose: Transform3D = skeleton.get_bone_global_pose(joint_bone_index)
				finger_joint_offsets[joint_key] = hand_inverse * joint_pose.origin
			if not finger_joint_offsets.is_empty():
				joint_lookup[finger_id] = finger_joint_offsets
			var end_bone_name: StringName = (slot_chains.get(finger_id, {}) as Dictionary).get("end", StringName())
			var end_bone_index: int = skeleton.find_bone(String(end_bone_name))
			if end_bone_index < 0:
				continue
			var end_pose: Transform3D = skeleton.get_bone_global_pose(end_bone_index)
			tip_lookup[finger_id] = hand_inverse * end_pose.origin
		sample[slot_id] = {
			"rotations": rotation_lookup,
			"tip_offsets": tip_lookup,
			"joint_offsets": joint_lookup,
		}
	josie_root.free()
	return sample

func _apply_animation_contact_open_pose(skeleton: Skeleton3D, slot_id: StringName) -> void:
	_apply_animation_pose_cache_to_slot(skeleton, animation_idle_baseline_cache, slot_id)

func _apply_animation_pose_cache_to_slot(
	skeleton: Skeleton3D,
	pose_cache: Dictionary,
	slot_id: StringName
) -> void:
	var slot_cache: Dictionary = pose_cache.get(slot_id, {})
	if slot_cache.is_empty():
		return
	var hand_name: StringName = (PALM_TRIANGULATION_BONES.get(slot_id, {}) as Dictionary).get("hand", StringName())
	var hand_index: int = skeleton.find_bone(String(hand_name))
	if hand_index < 0:
		return
	var hand_pose: Transform3D = skeleton.get_bone_global_pose(hand_index)
	var rotation_lookup: Dictionary = slot_cache.get("rotations", {})
	for bone_name_variant: Variant in rotation_lookup.keys():
		var bone_name: StringName = bone_name_variant as StringName
		var bone_index: int = skeleton.find_bone(String(bone_name))
		if bone_index < 0:
			continue
		var parent_index: int = skeleton.get_bone_parent(bone_index)
		if parent_index < 0:
			continue
		var parent_pose: Transform3D = skeleton.get_bone_global_pose(parent_index)
		var desired_hand_relative_rotation: Quaternion = rotation_lookup.get(bone_name, Quaternion.IDENTITY) as Quaternion
		var desired_global_basis: Basis = hand_pose.basis * Basis(desired_hand_relative_rotation)
		var desired_local_basis: Basis = parent_pose.basis.inverse() * desired_global_basis
		skeleton.set_bone_pose_rotation(
			bone_index,
			desired_local_basis.get_rotation_quaternion().normalized()
		)
	skeleton.force_update_all_bone_transforms()

func _resolve_animation_baseline_tip_world_position(
	skeleton: Skeleton3D,
	slot_id: StringName,
	finger_id: StringName
) -> Vector3:
	return _resolve_animation_baseline_tip_world_position_from_cache(
		skeleton,
		animation_grip_baseline_cache,
		slot_id,
		finger_id
	)

func _resolve_animation_baseline_tip_world_position_from_cache(
	skeleton: Skeleton3D,
	pose_cache: Dictionary,
	slot_id: StringName,
	finger_id: StringName
) -> Vector3:
	var slot_cache: Dictionary = pose_cache.get(slot_id, {})
	if slot_cache.is_empty():
		return Vector3.ZERO
	var local_tip_offset: Vector3 = (slot_cache.get("tip_offsets", {}) as Dictionary).get(finger_id, Vector3.ZERO) as Vector3
	if local_tip_offset.length_squared() <= 0.000001:
		return Vector3.ZERO
	var hand_name: StringName = (PALM_TRIANGULATION_BONES.get(slot_id, {}) as Dictionary).get("hand", StringName())
	var hand_index: int = skeleton.find_bone(String(hand_name))
	if hand_index < 0:
		return Vector3.ZERO
	var hand_pose: Transform3D = skeleton.get_bone_global_pose(hand_index)
	var local_tip_position: Vector3 = hand_pose * local_tip_offset
	return skeleton.to_global(local_tip_position)

func _resolve_animation_joint_world_position_from_cache(
	skeleton: Skeleton3D,
	pose_cache: Dictionary,
	slot_id: StringName,
	finger_id: StringName,
	joint_key: StringName
) -> Vector3:
	var slot_cache: Dictionary = pose_cache.get(slot_id, {})
	if slot_cache.is_empty():
		return Vector3.ZERO
	var local_joint_offset: Vector3 = ((slot_cache.get("joint_offsets", {}) as Dictionary).get(finger_id, {}) as Dictionary).get(
		joint_key,
		Vector3.ZERO
	) as Vector3
	if local_joint_offset.length_squared() <= 0.000001:
		return Vector3.ZERO
	var hand_name: StringName = (PALM_TRIANGULATION_BONES.get(slot_id, {}) as Dictionary).get("hand", StringName())
	var hand_index: int = skeleton.find_bone(String(hand_name))
	if hand_index < 0:
		return Vector3.ZERO
	var hand_pose: Transform3D = skeleton.get_bone_global_pose(hand_index)
	var local_joint_position: Vector3 = hand_pose * local_joint_offset
	return skeleton.to_global(local_joint_position)

func _resolve_hand_grip_center_world_from_cache(
	skeleton: Skeleton3D,
	pose_cache: Dictionary,
	slot_id: StringName
) -> Vector3:
	var sample_points: Array[Vector3] = []
	for finger_id: StringName in [&"thumb", &"index"]:
		for joint_key: StringName in [&"root", &"mid", &"end"]:
			var joint_world: Vector3 = _resolve_animation_joint_world_position_from_cache(
				skeleton,
				pose_cache,
				slot_id,
				finger_id,
				joint_key
			)
			if joint_world.length_squared() > 0.000001:
				sample_points.append(joint_world)
	if sample_points.is_empty():
		return Vector3.ZERO
	var center_world: Vector3 = Vector3.ZERO
	for point_world: Vector3 in sample_points:
		center_world += point_world
	return center_world / float(sample_points.size())

func _resolve_plane_curl_finger_target_world_position(
	skeleton: Skeleton3D,
	slot_id: StringName,
	finger_id: StringName,
	chain_def: Dictionary,
	grip_center_node: Node3D,
	cell_world_size: float,
	contact_readiness: float
) -> Vector3:
	var curl_stop: Dictionary = _resolve_plane_curl_stop(
		skeleton,
		slot_id,
		finger_id,
		chain_def,
		grip_center_node,
		cell_world_size
	)
	var curl_t: float = float(curl_stop.get("t", _resolve_max_curl_t_for_finger(finger_id)))
	var resolved_readiness: float = clampf(contact_readiness, 0.0, 1.0)
	_apply_plane_curl_pose(skeleton, slot_id, finger_id, curl_t * resolved_readiness)
	skeleton.force_update_all_bone_transforms()
	var target_world: Vector3 = curl_stop.get("target_world", Vector3.ZERO) as Vector3
	if resolved_readiness < 0.999:
		var baseline_tip_world: Vector3 = _resolve_animation_baseline_tip_world_position_from_cache(
			skeleton,
			animation_grip_baseline_cache,
			slot_id,
			finger_id
		)
		if baseline_tip_world.length_squared() > 0.000001:
			target_world = baseline_tip_world.lerp(target_world, resolved_readiness)
	return target_world

func _resolve_plane_curl_stop(
	skeleton: Skeleton3D,
	slot_id: StringName,
	finger_id: StringName,
	chain_def: Dictionary,
	grip_center_node: Node3D,
	cell_world_size: float
) -> Dictionary:
	var max_curl_t: float = _resolve_max_curl_t_for_finger(finger_id)
	var idle_mid_world: Vector3 = _resolve_animation_joint_world_position_from_cache(
		skeleton,
		animation_idle_baseline_cache,
		slot_id,
		finger_id,
		&"mid"
	)
	var idle_tip_world: Vector3 = _resolve_animation_joint_world_position_from_cache(
		skeleton,
		animation_idle_baseline_cache,
		slot_id,
		finger_id,
		&"end"
	)
	var grip_mid_world: Vector3 = _resolve_animation_joint_world_position_from_cache(
		skeleton,
		animation_grip_baseline_cache,
		slot_id,
		finger_id,
		&"mid"
	)
	var grip_tip_world: Vector3 = _resolve_animation_joint_world_position_from_cache(
		skeleton,
		animation_grip_baseline_cache,
		slot_id,
		finger_id,
		&"end"
	)
	if idle_tip_world.length_squared() <= 0.000001 or grip_tip_world.length_squared() <= 0.000001:
		return {
			"t": max_curl_t,
			"target_world": _get_current_chain_end_world_position(skeleton, chain_def),
		}
	var capped_grip_mid_world: Vector3 = idle_mid_world.lerp(grip_mid_world, max_curl_t)
	var capped_grip_tip_world: Vector3 = idle_tip_world.lerp(grip_tip_world, max_curl_t)
	var control_a_world: Vector3 = idle_tip_world.lerp(idle_mid_world, 0.45)
	var control_b_world: Vector3 = capped_grip_tip_world.lerp(capped_grip_mid_world, 0.45)
	var previous_point_world: Vector3 = idle_tip_world
	var previous_t: float = 0.0
	for step_index in range(1, CURL_TRAJECTORY_SAMPLE_STEPS + 1):
		var curve_t: float = max_curl_t * (float(step_index) / float(CURL_TRAJECTORY_SAMPLE_STEPS))
		var sample_point_world: Vector3 = _sample_cubic_bezier_3d(
			idle_tip_world,
			control_a_world,
			control_b_world,
			capped_grip_tip_world,
			curve_t / maxf(max_curl_t, 0.000001)
		)
		var hit: Dictionary = _resolve_contact_hit_on_segment(
			grip_center_node,
			previous_point_world,
			sample_point_world,
			slot_id,
			finger_id,
			&"plane_curl"
		)
		if not hit.is_empty():
			var segment_length: float = previous_point_world.distance_to(sample_point_world)
			var local_fraction: float = 0.0
			if segment_length > 0.000001:
				local_fraction = clampf(
					previous_point_world.distance_to(hit.get("position", sample_point_world) as Vector3) / segment_length,
					0.0,
					1.0
				)
			var stopped_t: float = lerpf(previous_t, curve_t, local_fraction)
			var hit_position: Vector3 = hit.get("position", sample_point_world) as Vector3
			var hit_normal: Vector3 = hit.get("normal", Vector3.ZERO) as Vector3
			if hit_normal.length_squared() <= 0.000001:
				hit_normal = (previous_point_world - sample_point_world).normalized()
			return {
				"t": stopped_t,
				"target_world": hit_position + hit_normal.normalized() * (cell_world_size * 0.05),
			}
		previous_point_world = sample_point_world
		previous_t = curve_t
	var fallback_hit: Dictionary = _resolve_contact_hit_against_profile_cells(
		grip_center_node,
		capped_grip_tip_world,
		slot_id,
		finger_id,
		&"plane_curl_profile_fallback"
	)
	if fallback_hit.is_empty():
		fallback_hit = _resolve_contact_hit_against_profile_cells(
			grip_center_node,
			idle_tip_world,
			slot_id,
			finger_id,
			&"plane_curl_idle_profile_fallback"
		)
	if not fallback_hit.is_empty():
		var fallback_hit_position: Vector3 = fallback_hit.get("position", capped_grip_tip_world) as Vector3
		var fallback_hit_normal: Vector3 = fallback_hit.get("normal", Vector3.ZERO) as Vector3
		if fallback_hit_normal.length_squared() <= 0.000001:
			fallback_hit_normal = (capped_grip_tip_world - grip_center_node.global_position).normalized()
		if fallback_hit_normal.length_squared() <= 0.000001:
			fallback_hit_normal = Vector3.UP
		return {
			"t": max_curl_t,
			"target_world": fallback_hit_position + fallback_hit_normal.normalized() * (cell_world_size * 0.05),
		}
	return {
		"t": max_curl_t,
		"target_world": capped_grip_tip_world,
	}

func _resolve_contact_hit_against_profile_cells(
	grip_center_node: Node3D,
	from_world: Vector3,
	slot_id: StringName,
	finger_id: StringName,
	ray_context: StringName
) -> Dictionary:
	if grip_center_node == null or not is_instance_valid(grip_center_node):
		return {}
	var profile_offsets: Array = grip_center_node.get_meta("grip_shell_profile_offsets_minor", []) as Array
	if profile_offsets.is_empty():
		return _resolve_contact_hit_on_segment(
			grip_center_node,
			from_world,
			grip_center_node.global_position,
			slot_id,
			finger_id,
			ray_context
		)
	var minor_axis_a_local: Vector3 = grip_center_node.get_meta("grip_shell_minor_axis_a_local", Vector3.RIGHT) as Vector3
	var minor_axis_b_local: Vector3 = grip_center_node.get_meta("grip_shell_minor_axis_b_local", Vector3.UP) as Vector3
	var minor_axis_a_world: Vector3 = (grip_center_node.global_basis * minor_axis_a_local).normalized()
	var minor_axis_b_world: Vector3 = (grip_center_node.global_basis * minor_axis_b_local).normalized()
	if minor_axis_a_world.length_squared() <= 0.000001:
		minor_axis_a_world = grip_center_node.global_basis.x.normalized()
	if minor_axis_b_world.length_squared() <= 0.000001:
		minor_axis_b_world = grip_center_node.global_basis.y.normalized()
	var closest_index: int = -1
	var closest_distance_squared: float = INF
	for profile_index in range(profile_offsets.size()):
		var offset_minor: Vector2 = profile_offsets[profile_index] as Vector2
		var candidate_world: Vector3 = grip_center_node.global_position \
			+ minor_axis_a_world * offset_minor.x \
			+ minor_axis_b_world * offset_minor.y
		var distance_squared: float = from_world.distance_squared_to(candidate_world)
		if distance_squared < closest_distance_squared:
			closest_distance_squared = distance_squared
			closest_index = profile_index
	if closest_index >= 0:
		var closest_hit: Dictionary = _resolve_contact_hit_against_profile_cell_index(
			grip_center_node,
			from_world,
			profile_offsets,
			closest_index,
			minor_axis_a_world,
			minor_axis_b_world,
			slot_id,
			finger_id,
			ray_context
		)
		if not closest_hit.is_empty():
			return closest_hit
	for profile_index in range(profile_offsets.size()):
		if profile_index == closest_index:
			continue
		var profile_hit: Dictionary = _resolve_contact_hit_against_profile_cell_index(
			grip_center_node,
			from_world,
			profile_offsets,
			profile_index,
			minor_axis_a_world,
			minor_axis_b_world,
			slot_id,
			finger_id,
			ray_context
		)
		if not profile_hit.is_empty():
			return profile_hit
	return {}

func _resolve_contact_hit_against_profile_cell_index(
	grip_center_node: Node3D,
	from_world: Vector3,
	profile_offsets: Array,
	profile_index: int,
	minor_axis_a_world: Vector3,
	minor_axis_b_world: Vector3,
	slot_id: StringName,
	finger_id: StringName,
	ray_context: StringName
) -> Dictionary:
	if profile_index < 0 or profile_index >= profile_offsets.size():
		return {}
	var offset_minor: Vector2 = profile_offsets[profile_index] as Vector2
	var cell_center_world: Vector3 = grip_center_node.global_position \
		+ minor_axis_a_world * offset_minor.x \
		+ minor_axis_b_world * offset_minor.y
	return _resolve_contact_hit_on_segment(
		grip_center_node,
		from_world,
		cell_center_world,
		slot_id,
		finger_id,
		ray_context
	)

func _apply_plane_curl_pose(
	skeleton: Skeleton3D,
	slot_id: StringName,
	finger_id: StringName,
	curl_t: float
) -> void:
	var slot_idle_cache: Dictionary = animation_idle_baseline_cache.get(slot_id, {})
	var slot_grip_cache: Dictionary = animation_grip_baseline_cache.get(slot_id, {})
	if slot_idle_cache.is_empty() or slot_grip_cache.is_empty():
		return
	var hand_name: StringName = (PALM_TRIANGULATION_BONES.get(slot_id, {}) as Dictionary).get("hand", StringName())
	var hand_index: int = skeleton.find_bone(String(hand_name))
	if hand_index < 0:
		return
	var hand_pose: Transform3D = skeleton.get_bone_global_pose(hand_index)
	var plane_bones: Array[StringName] = _resolve_ordered_finger_bones(slot_id, finger_id)
	for bone_name: StringName in plane_bones:
		if bone_name == StringName():
			continue
		var bone_index: int = skeleton.find_bone(String(bone_name))
		if bone_index < 0:
			continue
		var parent_index: int = skeleton.get_bone_parent(bone_index)
		if parent_index < 0:
			continue
		var parent_pose: Transform3D = skeleton.get_bone_global_pose(parent_index)
		var open_rotation: Quaternion = ((slot_idle_cache.get("rotations", {}) as Dictionary).get(
			bone_name,
			Quaternion.IDENTITY
		) as Quaternion).normalized()
		var closed_rotation: Quaternion = ((slot_grip_cache.get("rotations", {}) as Dictionary).get(
			bone_name,
			open_rotation
		) as Quaternion).normalized()
		var desired_hand_relative_rotation: Quaternion = _resolve_planar_contact_group_rotation(
			slot_id,
			open_rotation,
			closed_rotation,
			curl_t
		)
		var desired_global_basis: Basis = hand_pose.basis * Basis(desired_hand_relative_rotation)
		var desired_local_basis: Basis = parent_pose.basis.inverse() * desired_global_basis
		skeleton.set_bone_pose_rotation(
			bone_index,
			desired_local_basis.get_rotation_quaternion().normalized()
		)

func _resolve_ordered_finger_bones(slot_id: StringName, finger_id: StringName) -> Array[StringName]:
	var chain_def: Dictionary = (FINGER_CHAINS.get(slot_id, {}) as Dictionary).get(finger_id, {})
	var ordered_bones: Array[StringName] = []
	for joint_key: StringName in [&"root", &"guide", &"mid", &"end"]:
		var bone_name: StringName = chain_def.get(joint_key, StringName())
		if bone_name == StringName() or bone_name in ordered_bones:
			continue
		ordered_bones.append(bone_name)
	return ordered_bones

func _resolve_planar_contact_group_rotation(
	slot_id: StringName,
	open_rotation: Quaternion,
	_closed_rotation: Quaternion,
	curl_t: float
) -> Quaternion:
	var open_basis: Basis = Basis(open_rotation.normalized()).orthonormalized()
	var axis_hand: Vector3 = open_basis.z.normalized()
	if axis_hand.length_squared() <= 0.000001:
		return open_rotation.normalized()
	var hand_direction: float = -1.0 if slot_id == SLOT_LEFT else 1.0
	var tween_t: float = _smooth_contact_group_tween_t(curl_t)
	var max_closed_angle: float = deg_to_rad(CONTACT_GROUP_MAX_CURL_DEGREES)
	var resolved_angle: float = hand_direction * max_closed_angle * tween_t
	var resolved_basis: Basis = (Basis(axis_hand, resolved_angle) * open_basis).orthonormalized()
	return resolved_basis.get_rotation_quaternion().normalized()

func _smooth_contact_group_tween_t(raw_t: float) -> float:
	var resolved_t: float = clampf(raw_t, 0.0, 1.0)
	return resolved_t * resolved_t * (3.0 - 2.0 * resolved_t)

func _resolve_max_curl_t_for_finger(finger_id: StringName) -> float:
	if finger_id == &"pinky":
		return PINKY_MAX_CURL_T
	return 1.0

func _finger_uses_plane_curl_path(finger_id: StringName) -> bool:
	return finger_id in FINGER_IDS

func _get_current_chain_end_world_position(skeleton: Skeleton3D, chain_def: Dictionary) -> Vector3:
	var end_bone_name: StringName = chain_def.get("end", StringName())
	var end_bone_index: int = skeleton.find_bone(String(end_bone_name))
	if end_bone_index < 0:
		return Vector3.ZERO
	return skeleton.to_global(skeleton.get_bone_global_pose(end_bone_index).origin)

func _sample_cubic_bezier_3d(
	p0: Vector3,
	p1: Vector3,
	p2: Vector3,
	p3: Vector3,
	t: float
) -> Vector3:
	var u: float = 1.0 - t
	var tt: float = t * t
	var uu: float = u * u
	var uuu: float = uu * u
	var ttt: float = tt * t
	return (p0 * uuu) + (p1 * 3.0 * uu * t) + (p2 * 3.0 * u * tt) + (p3 * ttt)

func _resolve_contact_hit_on_segment(
	grip_center_node: Node3D,
	from_world: Vector3,
	to_world: Vector3,
	slot_id: StringName = StringName(),
	finger_id: StringName = StringName(),
	ray_context: StringName = &"contact_segment"
) -> Dictionary:
	if grip_center_node == null or not is_instance_valid(grip_center_node):
		return {}
	var world_3d: World3D = grip_center_node.get_world_3d()
	if world_3d == null:
		_record_contact_ray_debug(
			grip_center_node,
			slot_id,
			finger_id,
			ray_context,
			from_world,
			to_world,
			0,
			{},
			"missing_world"
		)
		return {}
	var collision_mask: int = int(grip_center_node.get_meta("grip_shell_collision_layer", 0))
	if collision_mask <= 0:
		_record_contact_ray_debug(
			grip_center_node,
			slot_id,
			finger_id,
			ray_context,
			from_world,
			to_world,
			collision_mask,
			{},
			"missing_collision_mask"
		)
		return {}
	if from_world.distance_to(to_world) <= 0.000001:
		_record_contact_ray_debug(
			grip_center_node,
			slot_id,
			finger_id,
			ray_context,
			from_world,
			to_world,
			collision_mask,
			{},
			"empty_segment"
		)
		return {}
	var ray_query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		from_world,
		to_world,
		collision_mask
	)
	ray_query.collide_with_areas = true
	ray_query.collide_with_bodies = false
	ray_query.hit_from_inside = true
	var hit: Dictionary = world_3d.direct_space_state.intersect_ray(ray_query)
	_record_contact_ray_debug(
		grip_center_node,
		slot_id,
		finger_id,
		ray_context,
		from_world,
		to_world,
		collision_mask,
		hit
	)
	return hit

func _resolve_baseline_contact_target_world_position(
	grip_center_node: Node3D,
	center_world: Vector3,
	baseline_tip_world: Vector3,
	cell_world_size: float
) -> Vector3:
	if baseline_tip_world.length_squared() <= 0.000001:
		return Vector3.ZERO
	var hit: Dictionary = _resolve_contact_hit_on_segment(
		grip_center_node,
		baseline_tip_world,
		center_world,
		StringName(),
		StringName(),
		&"baseline_contact_tip_to_center"
	)
	if hit.is_empty():
		hit = _resolve_contact_hit_on_segment(
			grip_center_node,
			center_world,
			baseline_tip_world,
			StringName(),
			StringName(),
			&"baseline_contact_center_to_tip"
		)
	if hit.is_empty():
		return baseline_tip_world
	var hit_position: Vector3 = hit.get("position", baseline_tip_world)
	var hit_normal: Vector3 = hit.get("normal", Vector3.ZERO)
	if hit_normal.length_squared() <= 0.000001:
		hit_normal = (baseline_tip_world - center_world).normalized()
	return hit_position + hit_normal.normalized() * (cell_world_size * 0.05)
