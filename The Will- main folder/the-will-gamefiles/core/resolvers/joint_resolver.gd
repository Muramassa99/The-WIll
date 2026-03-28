extends RefCounted
class_name JointResolver

const DEFAULT_FORGE_RULES_RESOURCE: ForgeRulesDef = preload("res://core/defs/forge/forge_rules_default.tres")

var forge_rules: ForgeRulesDef = DEFAULT_FORGE_RULES_RESOURCE

func _init(rules: ForgeRulesDef = null) -> void:
	forge_rules = rules if rules != null else DEFAULT_FORGE_RULES_RESOURCE

func classify_joint_segments(segments: Array[SegmentAtom], material_lookup: Dictionary) -> Array[SegmentAtom]:
	for segment: SegmentAtom in segments:
		if segment == null:
			continue
		if not validate_joint_chain(segment, material_lookup):
			segment.joint_type_hint = &"none"
			segment.link_count = 0
			segment.hinge_count = 0
			continue
		var joint_properties: Dictionary = resolve_joint_properties(segment)
		segment.joint_type_hint = joint_properties.get("joint_type", &"none")
		segment.link_count = joint_properties.get("link_count", 0)
		segment.hinge_count = joint_properties.get("hinge_count", 0)
	return segments

func validate_joint_chain(segment: SegmentAtom, _material_lookup: Dictionary) -> bool:
	if segment == null:
		return false
	if not _is_valid_joint_envelope(segment):
		return false
	if not _has_valid_joint_material_ratio(segment):
		return false
	return true

func resolve_joint_properties(segment: SegmentAtom) -> Dictionary:
	var joint_type: StringName = _determine_joint_type(segment)
	var rules: ForgeRulesDef = forge_rules
	return {
		"joint_chain_valid": segment != null and _is_valid_joint_envelope(segment) and _has_valid_joint_material_ratio(segment),
		"joint_type": joint_type,
		"joint_axis": Vector3(segment.major_axis),
		"motion_plane": _determine_motion_plane(segment),
		"link_count": _calculate_link_count(segment),
		"hinge_count": _calculate_hinge_count(segment),
		"angle_limit_min": rules.joint_angle_limit_min_degrees if joint_type != &"none" else 0.0,
		"angle_limit_max": rules.joint_angle_limit_max_degrees if joint_type != &"none" else 0.0,
		"supports_axial_spin": joint_type == &"axial_spin",
		"supports_planar_hinge": joint_type != &"none",
		"self_collision_mode": _determine_self_collision_mode(segment),
		"validation_error": _get_validation_error(segment),
	}

func _is_valid_joint_envelope(segment: SegmentAtom) -> bool:
	if segment == null:
		return false
	var rules: ForgeRulesDef = forge_rules
	var a: int = segment.cross_width_voxels
	var b: int = segment.cross_thickness_voxels
	var c: int = segment.length_voxels
	return a >= rules.joint_min_cross_width_voxels and b >= rules.joint_min_cross_thickness_voxels and c >= rules.joint_min_length_voxels and (c % 2) == 0

func _has_valid_joint_material_ratio(segment: SegmentAtom) -> bool:
	if segment == null:
		return false
	return segment.joint_support_material_ratio >= forge_rules.joint_min_support_material_ratio

func _is_square_cross_plane(segment: SegmentAtom) -> bool:
	if segment == null:
		return false
	return segment.cross_width_voxels == segment.cross_thickness_voxels

func _is_rectangular_cross_plane(segment: SegmentAtom) -> bool:
	if segment == null:
		return false
	return segment.cross_width_voxels != segment.cross_thickness_voxels

func _calculate_link_count(segment: SegmentAtom) -> int:
	if segment == null:
		return 0
	return int(segment.length_voxels / 2.0)

func _calculate_hinge_count(segment: SegmentAtom) -> int:
	var link_count: int = _calculate_link_count(segment)
	return maxi(link_count - 1, 0)

func _determine_joint_type(segment: SegmentAtom) -> StringName:
	if not _is_valid_joint_envelope(segment) or not _has_valid_joint_material_ratio(segment):
		return &"none"
	if _is_square_cross_plane(segment):
		return &"axial_spin"
	if _is_rectangular_cross_plane(segment):
		return &"planar_forced"
	return &"none"

func _determine_motion_plane(segment: SegmentAtom) -> StringName:
	if segment == null:
		return &""
	if _is_square_cross_plane(segment):
		return _build_plane_name(segment.major_axis, segment.minor_axis_a)
	var shorter_axis: Vector3i = segment.minor_axis_a if segment.cross_width_voxels >= segment.cross_thickness_voxels else segment.minor_axis_b
	return _build_plane_name(segment.major_axis, shorter_axis)

func _determine_self_collision_mode(segment: SegmentAtom) -> StringName:
	if segment == null or not validate_joint_chain(segment, {}):
		return &"none"
	return &"adjacent_pair_exempt"

func _get_validation_error(segment: SegmentAtom) -> StringName:
	if segment == null:
		return &"missing_segment"
	if not _is_valid_joint_envelope(segment):
		return &"invalid_joint_envelope"
	if not _has_valid_joint_material_ratio(segment):
		return &"insufficient_joint_support_material"
	return &""

func _build_plane_name(axis_a: Vector3i, axis_b: Vector3i) -> StringName:
	var letters: PackedStringArray = [_axis_to_letter(axis_a), _axis_to_letter(axis_b)]
	letters.sort()
	return StringName("".join(letters))

func _axis_to_letter(axis: Vector3i) -> String:
	if axis == Vector3i.RIGHT or axis == Vector3i.LEFT:
		return "x"
	if axis == Vector3i.UP or axis == Vector3i.DOWN:
		return "y"
	return "z"