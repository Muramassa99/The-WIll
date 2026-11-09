extends RefCounted
class_name PrimaryGripSeatResolver

const RATIO_EPSILON := 0.00001
const SLICE_DISTANCE_EPSILON_METERS := 0.000001
const SLICE_POINT_MERGE_EPSILON_METERS := 0.000005
const SLICE_AREA_EPSILON_SQUARED_METERS := 0.000000000001
const HAND_END_PADDING_RATIO := 0.10
const ALIGNMENT_ROOT := &"RL_BoneRoot"
const ALIGNMENT_WEAPON_ROOT := &"WeaponRootOrigin"


## Preparation only: put the selected Handle station at the fixed hand reference
## and align its length to Index-Pinky. The existing surface solver owns depth
## seating and finger closure afterwards. All point values share machine space;
## weapon-local vectors explicitly name their own source origin.
static func resolve_primary_alignment(weapon: Dictionary, hand: Dictionary, reverse: bool) -> Dictionary:
	if weapon.get("frame_origin_id") != ALIGNMENT_ROOT or hand.get("origin_id") != ALIGNMENT_ROOT:
		return {"valid": false, "reason": "primary_alignment_machine_origin_missing"}
	if not weapon.get("frame") is Transform3D:
		return {"valid": false, "reason": "primary_alignment_weapon_frame_missing"}
	var original: Transform3D = weapon.frame
	if not original.is_finite() or original.basis.determinant() <= 0.0:
		return {"valid": false, "reason": "primary_alignment_weapon_frame_invalid"}
	for field: String in ["station", "axis", "tip_direction"]:
		if weapon.get(field + "_origin_id") != ALIGNMENT_WEAPON_ROOT or not weapon.get(field) is Vector3 or not (weapon[field] as Vector3).is_finite():
			return {"valid": false, "reason": "primary_alignment_weapon_reference_invalid"}
	for field: String in ["index", "pinky", "wrist", "target"]:
		if not hand.get(field) is Vector3 or not (hand[field] as Vector3).is_finite():
			return {"valid": false, "reason": "primary_alignment_hand_reference_invalid"}
	for field: String in ["index_origin_id", "pinky_origin_id", "wrist_origin_id", "target_source_origin_id"]:
		if String(hand.get(field, "")).is_empty():
			return {"valid": false, "reason": "primary_alignment_hand_provenance_missing"}
	var source_axis: Vector3 = original.basis * (weapon.axis as Vector3)
	var tip_direction: Vector3 = original.basis * (weapon.tip_direction as Vector3)
	var target_axis: Vector3 = (hand.index as Vector3) - (hand.pinky as Vector3)
	if minf(source_axis.length_squared(), minf(tip_direction.length_squared(), target_axis.length_squared())) < 1.0e-12:
		return {"valid": false, "reason": "primary_alignment_axis_degenerate"}
	# Preserve the established Tip-side polarity, independently of span ordering
	# and anatomical side. Reverse changes polarity, not the selected percentage.
	if source_axis.dot(tip_direction) < 0.0:
		source_axis = -source_axis
	source_axis = source_axis.normalized()
	target_axis = target_axis.normalized() * (-1.0 if reverse else 1.0)
	var cross_axis := source_axis.cross(target_axis)
	var dot_axis := clampf(source_axis.dot(target_axis), -1.0, 1.0)
	var swing := Quaternion.IDENTITY
	if cross_axis.length_squared() > 1.0e-14:
		swing = Quaternion(cross_axis.normalized(), atan2(cross_axis.length(), dot_axis))
	elif dot_axis < 0.0:
		# At exactly 180 degrees the shortest arc is ambiguous. Use the named
		# wrist-to-knuckle reference rather than an arbitrary world axis.
		var reference: Vector3 = ((hand.index as Vector3) + (hand.pinky as Vector3)) * 0.5 - (hand.wrist as Vector3)
		reference -= source_axis * reference.dot(source_axis)
		if reference.length_squared() < 1.0e-12:
			return {"valid": false, "reason": "primary_alignment_half_turn_reference_degenerate"}
		swing = Quaternion(reference.normalized(), PI)
	# Left multiplication rotates the complete basis: existing scale and axial
	# facing travel with it; no new roll reference or orthonormalization is added.
	var basis := Basis(swing) * original.basis
	var result := Transform3D(basis, (hand.target as Vector3) - basis * (weapon.station as Vector3))
	return {"valid": true, "weapon_to_machine": result, "weapon_to_machine_origin_id": ALIGNMENT_ROOT,
		"swing": swing, "source_axis_machine": source_axis, "target_axis_machine": target_axis,
		"vectors_origin_id": ALIGNMENT_ROOT, "selected_station": weapon.station,
		"selected_station_origin_id": ALIGNMENT_WEAPON_ROOT, "hand_reference": hand.duplicate(true)}


static func resolve_hand_end_bounds(
	handle_length_meters: float,
	index_pinky_span_meters: float
) -> Dictionary:
	# The grip anchor is the Index-Pinky midpoint. Reserve half of that span
	# plus the same configurable padding at each Handle end, in physical units.
	if not is_finite(handle_length_meters) or handle_length_meters <= 0.0:
		return {"valid": false, "reason": &"invalid_handle_length"}
	if not is_finite(index_pinky_span_meters) or index_pinky_span_meters <= 0.0:
		return {"valid": false, "reason": &"missing_hand_grip_span"}
	var padding := index_pinky_span_meters * HAND_END_PADDING_RATIO
	var half_extent := index_pinky_span_meters * 0.5 + padding
	var reserved_width := half_extent * 2.0
	var result := {
		"valid": false,
		"reason": &"handle_shorter_than_hand_footprint",
		"handle_length_meters": handle_length_meters,
		"index_pinky_span_meters": index_pinky_span_meters,
		"padding_per_end_meters": padding,
		"half_extent_meters": half_extent,
		"reserved_width_meters": reserved_width,
	}
	if handle_length_meters < reserved_width:
		return result
	result["valid"] = true
	result["reason"] = StringName()
	result["min_ratio"] = half_extent / handle_length_meters
	result["max_ratio"] = 1.0 - float(result.min_ratio)
	return result


static func build_axis_ratios_from_centers(
	centers: PackedVector3Array,
	centers_origin_id: StringName,
	span_start: Vector3,
	span_start_origin_id: StringName,
	span_end: Vector3,
	span_end_origin_id: StringName
) -> PackedFloat32Array:
	var ratios := PackedFloat32Array()
	if (
		centers.size() < 2
		or centers_origin_id == StringName()
		or centers_origin_id != span_start_origin_id
		or centers_origin_id != span_end_origin_id
	):
		return ratios
	var span_vector := span_end - span_start
	var span_length_squared := span_vector.length_squared()
	if span_length_squared <= RATIO_EPSILON * RATIO_EPSILON:
		return ratios
	ratios.resize(centers.size())
	for center_index: int in range(centers.size()):
		var center := centers[center_index]
		ratios[center_index] = clampf(
			(center - span_start).dot(span_vector) / span_length_squared,
			0.0,
			1.0
		)
	ratios[0] = 0.0
	ratios[ratios.size() - 1] = 1.0
	return ratios


static func profile_has_authoritative_path(profile: BakedProfile) -> bool:
	if profile == null:
		return false
	return sampled_path_is_valid(
		profile.primary_grip_slice_axis_ratios_from_span_start,
		profile.primary_grip_slice_centers
	) and profile.primary_grip_slice_centers_origin_id != StringName()


static func sampled_path_is_valid(
	ratios: PackedFloat32Array,
	centers: PackedVector3Array
) -> bool:
	if ratios.size() < 2 or ratios.size() != centers.size():
		return false
	if absf(float(ratios[0])) > RATIO_EPSILON:
		return false
	if absf(float(ratios[ratios.size() - 1]) - 1.0) > RATIO_EPSILON:
		return false
	var previous_ratio := -INF
	for sample_index: int in range(ratios.size()):
		var ratio := float(ratios[sample_index])
		var center := centers[sample_index]
		if (
			not is_finite(ratio)
			or ratio < -RATIO_EPSILON
			or ratio > 1.0 + RATIO_EPSILON
			or ratio + RATIO_EPSILON < previous_ratio
			or not _vector3_is_finite(center)
		):
			return false
		previous_ratio = ratio
	return true


static func resolve_profile_seat(
	profile: BakedProfile,
	target_ratio: float
) -> Dictionary:
	if profile == null:
		return {"valid": false}
	return resolve_sampled_seat(
		profile.primary_grip_slice_axis_ratios_from_span_start,
		profile.primary_grip_slice_centers,
		profile.primary_grip_slice_centers_origin_id,
		target_ratio
	)


static func resolve_handle_coordinate_axis_ratio(
	handle_coordinate_normalized: float,
	tip_side_axis_ratio_from_span_start: float
) -> float:
	# Runtime and saved Handle positions are always normalized Pommel-to-Tip
	# coordinates in 0..1. The sampled path also remains 0..1, but its authored
	# span-start direction may oppose semantic Tip direction, so convert once.
	var tip_ratio := clampf(tip_side_axis_ratio_from_span_start, 0.0, 1.0)
	var pommel_ratio := 1.0 - tip_ratio
	return clampf(
		lerpf(
			pommel_ratio,
			tip_ratio,
			clampf(handle_coordinate_normalized, 0.0, 1.0)
		),
		0.0,
		1.0
	)


static func resolve_profile_handle_coordinate_mode(
	profile: BakedProfile
) -> StringName:
	if profile == null:
		return BakedProfile.PRIMARY_GRIP_HANDLE_COORDINATE_MODE_DIRECTIONAL_POMMEL_TO_TIP
	if profile.primary_grip_handle_coordinate_mode in [
		BakedProfile.PRIMARY_GRIP_HANDLE_COORDINATE_MODE_BALANCED_SIGNED,
		BakedProfile.PRIMARY_GRIP_HANDLE_COORDINATE_MODE_DIRECTIONAL_POMMEL_TO_TIP,
	]:
		return profile.primary_grip_handle_coordinate_mode
	# Compatibility for V1/cached profiles created before explicit mode metadata:
	# reuse their intrinsic-COM midpoint verdict, never an active hand position.
	if profile.primary_grip_center_balance_valid:
		return BakedProfile.PRIMARY_GRIP_HANDLE_COORDINATE_MODE_BALANCED_SIGNED
	return BakedProfile.PRIMARY_GRIP_HANDLE_COORDINATE_MODE_DIRECTIONAL_POMMEL_TO_TIP


static func resolve_profile_handle_tip_side_axis_ratio_from_span_start(
	profile: BakedProfile
) -> float:
	if profile == null:
		return 1.0
	if profile.primary_grip_handle_coordinate_mode in [
		BakedProfile.PRIMARY_GRIP_HANDLE_COORDINATE_MODE_BALANCED_SIGNED,
		BakedProfile.PRIMARY_GRIP_HANDLE_COORDINATE_MODE_DIRECTIONAL_POMMEL_TO_TIP,
	]:
		return (
			1.0
			if profile.primary_grip_handle_tip_side_axis_ratio_from_span_start >= 0.5
			else 0.0
		)
	var span_vector := (
		profile.primary_grip_span_end - profile.primary_grip_span_start
	)
	var span_length_squared := span_vector.length_squared()
	if span_length_squared <= RATIO_EPSILON * RATIO_EPSILON:
		return 1.0
	var legacy_tip_projection := (
		(profile.weapon_tip_point - profile.primary_grip_span_start).dot(
			span_vector
		)
		/ span_length_squared
	)
	return 1.0 if legacy_tip_projection >= 0.5 else 0.0


static func resolve_profile_handle_zero_axis_ratio_from_span_start(
	profile: BakedProfile
) -> float:
	var coordinate_mode := resolve_profile_handle_coordinate_mode(profile)
	if (
		coordinate_mode
		== BakedProfile.PRIMARY_GRIP_HANDLE_COORDINATE_MODE_BALANCED_SIGNED
	):
		return 0.5
	return 1.0 - resolve_profile_handle_tip_side_axis_ratio_from_span_start(
		profile
	)


static func handle_coordinate_to_display_value(
	handle_coordinate_normalized: float,
	coordinate_mode: StringName
) -> float:
	var normalized_coordinate := clampf(
		handle_coordinate_normalized,
		0.0,
		1.0
	)
	if (
		coordinate_mode
		== BakedProfile.PRIMARY_GRIP_HANDLE_COORDINATE_MODE_BALANCED_SIGNED
	):
		return normalized_coordinate * 2.0 - 1.0
	return normalized_coordinate


static func display_value_to_handle_coordinate(
	display_value: float,
	coordinate_mode: StringName
) -> float:
	if (
		coordinate_mode
		== BakedProfile.PRIMARY_GRIP_HANDLE_COORDINATE_MODE_BALANCED_SIGNED
	):
		return (clampf(display_value, -1.0, 1.0) + 1.0) * 0.5
	return clampf(display_value, 0.0, 1.0)


static func get_handle_coordinate_display_minimum(
	coordinate_mode: StringName
) -> float:
	if (
		coordinate_mode
		== BakedProfile.PRIMARY_GRIP_HANDLE_COORDINATE_MODE_BALANCED_SIGNED
	):
		return -1.0
	return 0.0


static func migrate_legacy_display_coordinates(
	motion_node: CombatAnimationMotionNode,
	coordinate_mode: StringName
) -> bool:
	if motion_node == null:
		return false
	if (
		motion_node.grip_seat_coordinate_schema_version
		>= CombatAnimationMotionNode
		.GRIP_SEAT_COORDINATE_SCHEMA_NORMALIZED_HANDLE
	):
		return false
	# Version-3 fields persisted the Skill Crafter control values. Convert those
	# authored values through the intended UI lens. Do not preserve the old
	# runtime's per-hand hidden-base displacement: that execution path is the
	# coordinate defect this schema migration removes.
	motion_node.grip_seat_slide_offset = display_value_to_handle_coordinate(
		motion_node.grip_seat_slide_offset,
		coordinate_mode
	)
	motion_node.secondary_grip_seat_slide_offset = (
		display_value_to_handle_coordinate(
			motion_node.secondary_grip_seat_slide_offset,
			coordinate_mode
		)
	)
	# Retarget nodes and runtime clips are derived projections of the authored
	# motion node. A legacy retarget snapshot still carries the old coordinate
	# semantics and would overwrite the migrated values when next applied.
	motion_node.retarget_node = null
	motion_node.grip_seat_coordinate_schema_version = (
		CombatAnimationMotionNode.GRIP_SEAT_COORDINATE_SCHEMA_NORMALIZED_HANDLE
	)
	motion_node.normalize()
	return true


static func resolve_sampled_seat(
	ratios: PackedFloat32Array,
	centers: PackedVector3Array,
	centers_origin_id: StringName,
	target_ratio: float
) -> Dictionary:
	if centers_origin_id == StringName() or not sampled_path_is_valid(ratios, centers):
		return {"valid": false}
	var clamped_ratio := clampf(target_ratio, 0.0, 1.0)
	if clamped_ratio <= float(ratios[0]) + RATIO_EPSILON:
		return {
			"valid": true,
			"position": centers[0],
			"position_origin_id": centers_origin_id,
			"ratio": 0.0,
			"segment_index": 0,
			"segment_ratio": 0.0,
		}
	for sample_index: int in range(ratios.size() - 1):
		var ratio_a := float(ratios[sample_index])
		var ratio_b := float(ratios[sample_index + 1])
		if clamped_ratio > ratio_b + RATIO_EPSILON:
			continue
		var interval := ratio_b - ratio_a
		if interval <= RATIO_EPSILON:
			if absf(clamped_ratio - ratio_a) <= RATIO_EPSILON:
				return {
					"valid": true,
					"position": centers[sample_index],
					"position_origin_id": centers_origin_id,
					"ratio": clamped_ratio,
					"segment_index": sample_index,
					"segment_ratio": 0.0,
				}
			continue
		var interval_ratio := clampf(
			(clamped_ratio - ratio_a) / interval,
			0.0,
			1.0
		)
		return {
			"valid": true,
			"position": centers[sample_index].lerp(
				centers[sample_index + 1],
				interval_ratio
			),
			"position_origin_id": centers_origin_id,
			"ratio": clamped_ratio,
			"segment_index": sample_index,
			"segment_ratio": interval_ratio,
		}
	return {
		"valid": true,
		"position": centers[centers.size() - 1],
		"position_origin_id": centers_origin_id,
		"ratio": 1.0,
		"segment_index": centers.size() - 2,
		"segment_ratio": 1.0,
	}


static func build_mesh_slice_center_path(
	vertices_meters: PackedVector3Array,
	indices: PackedInt32Array,
	axis_start_meters: Vector3,
	axis_end_meters: Vector3,
	sample_interval_meters: float = 0.001
) -> Dictionary:
	if (
		vertices_meters.size() < 3
		or indices.size() < 3
		or indices.size() % 3 != 0
	):
		return {"valid": false, "error": "slice_mesh_invalid"}
	var axis_span := axis_end_meters - axis_start_meters
	var axis_length := axis_span.length()
	if axis_length <= RATIO_EPSILON:
		return {"valid": false, "error": "slice_axis_degenerate"}
	var axis_normal := axis_span / axis_length
	var sample_count := maxi(
		int(ceil(
			axis_length / maxf(sample_interval_meters, 0.0001)
		)),
		1
	)
	# All stations share one axis. Index triangle projection intervals once,
	# rather than scanning the entire protected Handle at every millimetre.
	# This is only a conservative broad phase: the existing section/centroid
	# calculation (including singular limiting slices) remains authoritative.
	var candidates := _build_mesh_slice_candidates(
		vertices_meters, indices, axis_start_meters, axis_normal,
		axis_length, sample_count
	)
	if candidates.has("error"):
		return {"valid": false, "error": candidates.error, "sample_index": 0, "ratio": 0.0}
	var active_triangles: Dictionary = {}
	var ratios := PackedFloat32Array()
	var centers := PackedVector3Array()
	ratios.resize(sample_count + 1)
	centers.resize(sample_count + 1)
	for sample_index: int in range(sample_count + 1):
		var ratio := float(sample_index) / float(sample_count)
		var plane_origin := axis_start_meters + axis_span * ratio
		var slice_indices := indices
		if not candidates.is_empty():
			for offset: int in candidates.ends[sample_index]:
				active_triangles.erase(offset)
			for offset: int in candidates.starts[sample_index]:
				active_triangles[offset] = true
			# Preserve source triangle order, hence contour welding/rounding order.
			var offsets := active_triangles.keys()
			offsets.sort()
			slice_indices = PackedInt32Array()
			slice_indices.resize(offsets.size() * 3)
			for candidate_index: int in range(offsets.size()):
				var offset: int = offsets[candidate_index]
				for corner: int in range(3):
					slice_indices[candidate_index * 3 + corner] = indices[offset + corner]
		var slice_state := resolve_mesh_plane_slice_center(
			vertices_meters,
			slice_indices,
			plane_origin,
			axis_normal
		)
		if (
			not bool(slice_state.get("valid", false))
			and String(slice_state.get("error", ""))
			== "slice_contour_not_closed"
		):
			# A plane through an exact CSG vertex can merge two valid contour
			# branches into one degree-four node. Resolve the two limiting slices
			# and project their centers back onto this unchanged nominal station.
			slice_state = _resolve_singular_mesh_plane_slice_center(
				vertices_meters,
				slice_indices,
				plane_origin,
				axis_normal
			)
		if not bool(slice_state.get("valid", false)):
			return {
				"valid": false,
				"error": String(slice_state.get(
					"error",
					"slice_center_unresolved"
				)),
				"sample_index": sample_index,
				"ratio": ratio,
			}
		ratios[sample_index] = ratio
		centers[sample_index] = slice_state.get(
			"center_meters",
			Vector3.ZERO
		) as Vector3
	return {
		"valid": sampled_path_is_valid(ratios, centers),
		"ratios": ratios,
		"centers_meters": centers,
		"axis_start_meters": axis_start_meters,
		"axis_end_meters": axis_end_meters,
		"axis_normal": axis_normal,
	}


static func _build_mesh_slice_candidates(
	vertices_meters: PackedVector3Array,
	indices: PackedInt32Array,
	axis_start_meters: Vector3,
	axis_normal: Vector3,
	axis_length: float,
	sample_count: int
) -> Dictionary:
	var projections := PackedFloat64Array()
	projections.resize(vertices_meters.size())
	var coordinate_extent := axis_start_meters.length() + axis_length
	for vertex_index: int in range(vertices_meters.size()):
		var vertex := vertices_meters[vertex_index]
		if not vertex.is_finite():
			# Leave malformed numeric geometry to the existing exact resolver.
			return {}
		coordinate_extent = maxf(coordinate_extent, vertex.length())
		projections[vertex_index] = axis_normal.dot(vertex - axis_start_meters)
	var starts: Array[Array] = []
	var ends: Array[Array] = []
	starts.resize(sample_count + 1)
	ends.resize(sample_count + 2)
	for station: int in range(sample_count + 2):
		if station <= sample_count:
			starts[station] = []
		ends[station] = []
	# Include the on-plane band, both +/-2 epsilon singular probes, float32
	# vector arithmetic error and one extra station on each end. This may admit
	# extra triangles; it never changes the exact resolver's tolerance.
	var margin := SLICE_DISTANCE_EPSILON_METERS * 3.0 + coordinate_extent * 0.000001
	var stations_per_meter := float(sample_count) / axis_length
	for offset: int in range(0, indices.size(), 3):
		var low := INF
		var high := -INF
		for corner: int in range(3):
			var vertex_index := indices[offset + corner]
			if vertex_index < 0 or vertex_index >= projections.size():
				return {"error": "slice_mesh_index_invalid"}
			low = minf(low, projections[vertex_index])
			high = maxf(high, projections[vertex_index])
		var first := maxi(0, int(floor((low - margin) * stations_per_meter)) - 1)
		var last := mini(sample_count, int(ceil((high + margin) * stations_per_meter)) + 1)
		if first > last:
			continue
		starts[first].append(offset)
		ends[last + 1].append(offset)
	return {"starts": starts, "ends": ends}


static func _resolve_singular_mesh_plane_slice_center(
	vertices_meters: PackedVector3Array,
	indices: PackedInt32Array,
	nominal_plane_origin_meters: Vector3,
	plane_normal: Vector3
) -> Dictionary:
	var normal := plane_normal.normalized()
	if normal.length_squared() <= RATIO_EPSILON * RATIO_EPSILON:
		return {"valid": false, "error": "slice_plane_normal_degenerate"}
	var limiting_centers := PackedVector3Array()
	var limiting_offset_meters := SLICE_DISTANCE_EPSILON_METERS * 2.0
	for direction_sign: float in [-1.0, 1.0]:
		var shifted_state := resolve_mesh_plane_slice_center(
			vertices_meters,
			indices,
			nominal_plane_origin_meters
			+ normal * limiting_offset_meters * direction_sign,
			normal
		)
		if not bool(shifted_state.get("valid", false)):
			continue
		var limiting_center: Vector3 = shifted_state.get(
			"center_meters",
			nominal_plane_origin_meters
		) as Vector3
		limiting_center -= normal * normal.dot(
			limiting_center - nominal_plane_origin_meters
		)
		limiting_centers.append(limiting_center)
	if limiting_centers.is_empty():
		return {"valid": false, "error": "slice_contour_not_closed"}
	var center_meters := Vector3.ZERO
	for limiting_center: Vector3 in limiting_centers:
		center_meters += limiting_center
	center_meters /= float(limiting_centers.size())
	return {
		"valid": true,
		"center_meters": center_meters,
		"singular_limit_resolved": true,
		"limiting_sample_count": limiting_centers.size(),
	}


static func resolve_mesh_plane_slice_center(
	vertices_meters: PackedVector3Array,
	indices: PackedInt32Array,
	plane_origin_meters: Vector3,
	plane_normal: Vector3
) -> Dictionary:
	var normal := plane_normal.normalized()
	if normal.length_squared() <= RATIO_EPSILON * RATIO_EPSILON:
		return {"valid": false, "error": "slice_plane_normal_degenerate"}
	var reference := Vector3.UP
	if absf(normal.dot(reference)) > 0.9:
		reference = Vector3.RIGHT
	var axis_u := (
		reference - normal * reference.dot(normal)
	).normalized()
	if axis_u.length_squared() <= RATIO_EPSILON * RATIO_EPSILON:
		return {"valid": false, "error": "slice_plane_basis_degenerate"}
	var axis_v := normal.cross(axis_u).normalized()
	var points_2d: Array[Vector2] = []
	var point_ids_by_bucket: Dictionary = {}
	var coplanar_edge_counts: Dictionary = {}
	var crossing_segments: Dictionary = {}
	for triangle_offset: int in range(0, indices.size(), 3):
		var index_a := indices[triangle_offset]
		var index_b := indices[triangle_offset + 1]
		var index_c := indices[triangle_offset + 2]
		if (
			index_a < 0 or index_a >= vertices_meters.size()
			or index_b < 0 or index_b >= vertices_meters.size()
			or index_c < 0 or index_c >= vertices_meters.size()
		):
			return {"valid": false, "error": "slice_mesh_index_invalid"}
		var triangle := PackedVector3Array([
			vertices_meters[index_a],
			vertices_meters[index_b],
			vertices_meters[index_c],
		])
		var distances := PackedFloat32Array()
		distances.resize(3)
		var has_positive := false
		var has_negative := false
		var has_on_plane := false
		for vertex_index: int in range(3):
			var distance := normal.dot(
				triangle[vertex_index] - plane_origin_meters
			)
			distances[vertex_index] = distance
			if distance > SLICE_DISTANCE_EPSILON_METERS:
				has_positive = true
			elif distance < -SLICE_DISTANCE_EPSILON_METERS:
				has_negative = true
			else:
				has_on_plane = true
		if not has_on_plane and not (has_positive and has_negative):
			continue
		if not has_positive and not has_negative:
			var coplanar_ids := PackedInt32Array()
			for vertex_index: int in range(3):
				coplanar_ids.append(_resolve_welded_slice_point_id(
					points_2d,
					point_ids_by_bucket,
					triangle[vertex_index],
					plane_origin_meters,
					axis_u,
					axis_v
				))
			for edge_index: int in range(3):
				_increment_slice_edge_count(
					coplanar_edge_counts,
					coplanar_ids[edge_index],
					coplanar_ids[(edge_index + 1) % 3]
				)
			continue
		var intersection_ids := PackedInt32Array()
		for edge_index: int in range(3):
			var next_index := (edge_index + 1) % 3
			var point_a := triangle[edge_index]
			var point_b := triangle[next_index]
			var distance_a := float(distances[edge_index])
			var distance_b := float(distances[next_index])
			if absf(distance_a) <= SLICE_DISTANCE_EPSILON_METERS:
				_append_unique_slice_point_id(
					intersection_ids,
					_resolve_welded_slice_point_id(
						points_2d,
						point_ids_by_bucket,
						point_a,
						plane_origin_meters,
						axis_u,
						axis_v
					)
				)
			if (
				distance_a > SLICE_DISTANCE_EPSILON_METERS
				and distance_b < -SLICE_DISTANCE_EPSILON_METERS
			) or (
				distance_a < -SLICE_DISTANCE_EPSILON_METERS
				and distance_b > SLICE_DISTANCE_EPSILON_METERS
			):
				var crossing_ratio := distance_a / (distance_a - distance_b)
				_append_unique_slice_point_id(
					intersection_ids,
					_resolve_welded_slice_point_id(
						points_2d,
						point_ids_by_bucket,
						point_a.lerp(point_b, crossing_ratio),
						plane_origin_meters,
						axis_u,
						axis_v
					)
				)
		if intersection_ids.size() >= 2:
			var endpoint_ids := _resolve_farthest_slice_point_pair(
				intersection_ids,
				points_2d
			)
			if endpoint_ids.x >= 0 and endpoint_ids.y >= 0:
				crossing_segments[
					_build_slice_edge_key(endpoint_ids.x, endpoint_ids.y)
				] = true
	if points_2d.size() < 3:
		return {"valid": false, "error": "slice_intersection_open_or_empty"}
	var segments: Array[Vector2i] = []
	if not coplanar_edge_counts.is_empty():
		for edge_key_variant: Variant in coplanar_edge_counts.keys():
			var edge_key := edge_key_variant as Vector2i
			if int(coplanar_edge_counts[edge_key]) % 2 == 1:
				segments.append(edge_key)
	else:
		for edge_key_variant: Variant in crossing_segments.keys():
			segments.append(edge_key_variant as Vector2i)
	var contour_state := _resolve_slice_contour_centroid(
		points_2d,
		segments
	)
	if not bool(contour_state.get("valid", false)):
		return {
			"valid": false,
			"error": String(contour_state.get(
				"error",
				"slice_contour_invalid"
			)),
		}
	var center_2d: Vector2 = contour_state.get("centroid", Vector2.ZERO)
	var center_meters := (
		plane_origin_meters
		+ axis_u * center_2d.x
		+ axis_v * center_2d.y
	)
	center_meters -= normal * normal.dot(center_meters - plane_origin_meters)
	return {
		"valid": true,
		"center_meters": center_meters,
		"axis_u": axis_u,
		"axis_v": axis_v,
		"area_m2": float(contour_state.get("area", 0.0)),
		"contour_count": int(contour_state.get("contour_count", 0)),
	}


static func _resolve_welded_slice_point_id(
	points: Array[Vector2],
	point_ids_by_bucket: Dictionary,
	point_meters: Vector3,
	plane_origin_meters: Vector3,
	axis_u: Vector3,
	axis_v: Vector3
) -> int:
	var relative := point_meters - plane_origin_meters
	var point_2d := Vector2(relative.dot(axis_u), relative.dot(axis_v))
	var bucket := Vector2i(
		roundi(point_2d.x / SLICE_POINT_MERGE_EPSILON_METERS),
		roundi(point_2d.y / SLICE_POINT_MERGE_EPSILON_METERS)
	)
	# Bucket order is spatial, not insertion order. A later point in an earlier
	# bucket must not steal an existing shared intersection and open its contour.
	# Keep the earliest compatible representative; never widen the merge radius.
	var representative_id := -1
	for bucket_x: int in range(bucket.x - 1, bucket.x + 2):
		for bucket_y: int in range(bucket.y - 1, bucket.y + 2):
			var candidate_bucket := Vector2i(bucket_x, bucket_y)
			var candidate_ids: Array = point_ids_by_bucket.get(
				candidate_bucket,
				[]
			) as Array
			for candidate_id_variant: Variant in candidate_ids:
				var candidate_id := int(candidate_id_variant)
				if (
					points[candidate_id].distance_squared_to(point_2d)
					<= SLICE_POINT_MERGE_EPSILON_METERS
					* SLICE_POINT_MERGE_EPSILON_METERS
				):
					if representative_id < 0 or candidate_id < representative_id:
						representative_id = candidate_id
	if representative_id >= 0:
		return representative_id
	var point_id := points.size()
	points.append(point_2d)
	var bucket_ids: Array = point_ids_by_bucket.get(bucket, []) as Array
	bucket_ids.append(point_id)
	point_ids_by_bucket[bucket] = bucket_ids
	return point_id


static func _append_unique_slice_point_id(
	point_ids: PackedInt32Array,
	point_id: int
) -> void:
	if point_id < 0:
		return
	for existing_id: int in point_ids:
		if existing_id == point_id:
			return
	point_ids.append(point_id)


static func _build_slice_edge_key(point_a_id: int, point_b_id: int) -> Vector2i:
	return Vector2i(
		mini(point_a_id, point_b_id),
		maxi(point_a_id, point_b_id)
	)


static func _increment_slice_edge_count(
	edge_counts: Dictionary,
	point_a_id: int,
	point_b_id: int
) -> void:
	if point_a_id < 0 or point_b_id < 0 or point_a_id == point_b_id:
		return
	var edge_key := _build_slice_edge_key(point_a_id, point_b_id)
	edge_counts[edge_key] = int(edge_counts.get(edge_key, 0)) + 1


static func _resolve_farthest_slice_point_pair(
	point_ids: PackedInt32Array,
	points: Array[Vector2]
) -> Vector2i:
	var best_pair := Vector2i(-1, -1)
	var best_distance_squared := -1.0
	for point_a_index: int in range(point_ids.size()):
		for point_b_index: int in range(point_a_index + 1, point_ids.size()):
			var point_a_id := point_ids[point_a_index]
			var point_b_id := point_ids[point_b_index]
			var distance_squared := points[point_a_id].distance_squared_to(
				points[point_b_id]
			)
			if distance_squared <= best_distance_squared:
				continue
			best_distance_squared = distance_squared
			best_pair = Vector2i(point_a_id, point_b_id)
	return best_pair


static func _resolve_slice_contour_centroid(
	points: Array[Vector2],
	segments: Array[Vector2i]
) -> Dictionary:
	if segments.size() < 3:
		return {"valid": false, "error": "slice_contour_has_too_few_edges"}
	var adjacency: Dictionary = {}
	for segment: Vector2i in segments:
		if (
			segment.x < 0 or segment.x >= points.size()
			or segment.y < 0 or segment.y >= points.size()
			or segment.x == segment.y
		):
			return {"valid": false, "error": "slice_contour_edge_invalid"}
		var neighbors_a: Array = adjacency.get(segment.x, []) as Array
		if not neighbors_a.has(segment.y):
			neighbors_a.append(segment.y)
		adjacency[segment.x] = neighbors_a
		var neighbors_b: Array = adjacency.get(segment.y, []) as Array
		if not neighbors_b.has(segment.x):
			neighbors_b.append(segment.x)
		adjacency[segment.y] = neighbors_b
	var node_ids: Array = adjacency.keys()
	node_ids.sort()
	for node_id_variant: Variant in node_ids:
		var node_id := int(node_id_variant)
		var neighbors: Array = adjacency.get(node_id, []) as Array
		if neighbors.size() != 2:
			return {"valid": false, "error": "slice_contour_not_closed"}
		neighbors.sort()
		adjacency[node_id] = neighbors
	var visited_edges: Dictionary = {}
	var weighted_centroid := Vector2.ZERO
	var total_area := 0.0
	var contour_count := 0
	for start_id_variant: Variant in node_ids:
		var start_id := int(start_id_variant)
		var start_neighbors: Array = adjacency.get(start_id, []) as Array
		var has_unvisited_edge := false
		for neighbor_id_variant: Variant in start_neighbors:
			if not visited_edges.has(_build_slice_edge_key(
				start_id,
				int(neighbor_id_variant)
			)):
				has_unvisited_edge = true
				break
		if not has_unvisited_edge:
			continue
		var contour := PackedVector2Array()
		var previous_id := -1
		var current_id := start_id
		var closed := false
		for _walk_index: int in range(segments.size() + 2):
			contour.append(points[current_id])
			var neighbors: Array = adjacency.get(current_id, []) as Array
			var next_id := int(neighbors[0])
			if next_id == previous_id:
				next_id = int(neighbors[1])
			visited_edges[
				_build_slice_edge_key(current_id, next_id)
			] = true
			previous_id = current_id
			current_id = next_id
			if current_id == start_id:
				closed = true
				break
		if not closed or contour.size() < 3:
			return {"valid": false, "error": "slice_contour_walk_failed"}
		var centroid_state := _calculate_polygon_centroid_state(contour)
		if not bool(centroid_state.get("valid", false)):
			return {"valid": false, "error": "slice_contour_area_degenerate"}
		var contour_area := float(centroid_state.get("area", 0.0))
		weighted_centroid += (
			centroid_state.get("centroid", Vector2.ZERO) as Vector2
		) * contour_area
		total_area += contour_area
		contour_count += 1
	if total_area <= SLICE_AREA_EPSILON_SQUARED_METERS:
		return {"valid": false, "error": "slice_contour_total_area_degenerate"}
	return {
		"valid": true,
		"centroid": weighted_centroid / total_area,
		"area": total_area,
		"contour_count": contour_count,
	}


static func _calculate_polygon_centroid_state(
	polygon: PackedVector2Array
) -> Dictionary:
	var signed_area_twice := 0.0
	var centroid_numerator := Vector2.ZERO
	for point_index: int in range(polygon.size()):
		var point_a := polygon[point_index]
		var point_b := polygon[(point_index + 1) % polygon.size()]
		var cross := point_a.cross(point_b)
		signed_area_twice += cross
		centroid_numerator += (point_a + point_b) * cross
	if absf(signed_area_twice) <= SLICE_AREA_EPSILON_SQUARED_METERS:
		return {"valid": false}
	return {
		"valid": true,
		"centroid": centroid_numerator / (3.0 * signed_area_twice),
		"area": absf(signed_area_twice) * 0.5,
	}


static func _vector3_is_finite(value: Vector3) -> bool:
	return is_finite(value.x) and is_finite(value.y) and is_finite(value.z)
