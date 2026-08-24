extends RefCounted
class_name ForgeV2SurfaceSplineResolver

const ForgeV2SplinePathSamplerScript = preload(
	"res://runtime/forge_v2/forge_v2_spline_path_sampler.gd"
)

const DEFAULT_MAX_SPACING_METERS := 0.0125
const DEFAULT_FLATNESS_TOLERANCE_METERS := 0.0002
const DEFAULT_MAX_SUBDIVISION_DEPTH := 10
const DEFAULT_MAX_SAMPLES_PER_SPAN := 257
const MIN_MAX_SAMPLES_PER_SPAN := 3
const PROJECTED_STEP_ALLOWANCE := 2.0
const NORMAL_EPSILON_SQUARED := 0.000000000001

const REASON_NONE := &"none"
const REASON_NO_CONTROLS := &"no_controls"
const REASON_CONTROL_NORMAL_COUNT_MISMATCH := (
	&"control_normal_count_mismatch"
)
const REASON_CONTROL_CONTACT_COUNT_MISMATCH := (
	&"control_contact_count_mismatch"
)
const REASON_INVALID_CONTROL_POSITION := &"invalid_control_position"
const REASON_INVALID_CONTROL_NORMAL := &"invalid_control_normal"
const REASON_INVALID_CONTROL_CONTACT := &"invalid_control_contact"
const REASON_INVALID_LOCKED_TARGET := &"invalid_locked_target"
const REASON_INVALID_CALLBACK := &"invalid_callback"
const REASON_PROJECTION_INVALID := &"projection_invalid"
const REASON_TARGET_MISS := &"target_miss"
const REASON_TARGET_MISMATCH := &"target_mismatch"
const REASON_TARGET_SAMPLE_INVALID := &"target_sample_invalid"
const REASON_PROJECTION_DISCONTINUITY := &"projection_discontinuity"
const REASON_ZERO_LENGTH_SPAN := &"zero_length_span"
const REASON_SUBDIVISION_LIMIT := &"subdivision_limit"
const REASON_SAMPLE_LIMIT := &"sample_limit"


static func solve(
	control_positions: PackedVector3Array,
	control_surface_normals: PackedVector3Array,
	locked_target_kind: StringName,
	locked_target_id: StringName,
	local_to_screen: Callable,
	strict_screen_to_target: Callable,
	max_spacing_meters: float = DEFAULT_MAX_SPACING_METERS,
	flatness_tolerance_meters: float = (
		DEFAULT_FLATNESS_TOLERANCE_METERS
	),
	max_subdivision_depth: int = DEFAULT_MAX_SUBDIVISION_DEPTH,
	max_samples_per_span: int = DEFAULT_MAX_SAMPLES_PER_SPAN,
	control_contact_directions: PackedVector3Array = PackedVector3Array()
) -> Dictionary:
	var has_contact_authority := not control_contact_directions.is_empty()
	if control_positions.is_empty():
		return _build_early_failure(
			control_positions,
			control_surface_normals,
			locked_target_kind,
			locked_target_id,
			REASON_NO_CONTROLS,
			control_contact_directions
		)
	if control_surface_normals.size() != control_positions.size():
		return _build_early_failure(
			control_positions,
			PackedVector3Array(),
			locked_target_kind,
			locked_target_id,
			REASON_CONTROL_NORMAL_COUNT_MISMATCH
		)
	if (
		has_contact_authority
		and control_contact_directions.size() != control_positions.size()
	):
		return _build_early_failure(
			control_positions,
			control_surface_normals,
			locked_target_kind,
			locked_target_id,
			REASON_CONTROL_CONTACT_COUNT_MISMATCH,
			control_contact_directions
		)
	for control_position: Vector3 in control_positions:
		if not _vector3_is_finite(control_position):
			return _build_early_failure(
				control_positions,
				control_surface_normals,
				locked_target_kind,
				locked_target_id,
				REASON_INVALID_CONTROL_POSITION
			)
	for control_normal: Vector3 in control_surface_normals:
		if (
			not _vector3_is_finite(control_normal)
			or control_normal.length_squared() <= NORMAL_EPSILON_SQUARED
		):
			return _build_early_failure(
				control_positions,
				control_surface_normals,
				locked_target_kind,
				locked_target_id,
				REASON_INVALID_CONTROL_NORMAL
			)
	if has_contact_authority:
		for control_contact_direction: Vector3 in control_contact_directions:
			if (
				not _vector3_is_finite(control_contact_direction)
				or control_contact_direction.length_squared()
				<= NORMAL_EPSILON_SQUARED
			):
				return _build_early_failure(
					control_positions,
					control_surface_normals,
					locked_target_kind,
					locked_target_id,
					REASON_INVALID_CONTROL_CONTACT,
					control_contact_directions
				)
	if (
		locked_target_kind == StringName()
		or locked_target_id == StringName()
	):
		return _build_early_failure(
			control_positions,
			control_surface_normals,
			locked_target_kind,
			locked_target_id,
			REASON_INVALID_LOCKED_TARGET
		)
	if not local_to_screen.is_valid() or not strict_screen_to_target.is_valid():
		return _build_early_failure(
			control_positions,
			control_surface_normals,
			locked_target_kind,
			locked_target_id,
			REASON_INVALID_CALLBACK
		)

	var resolved_max_spacing := maxf(
		max_spacing_meters,
		ForgeV2SplinePathSamplerScript.MIN_SAMPLE_SPACING_METERS
	)
	var resolved_flatness := maxf(
		flatness_tolerance_meters,
		ForgeV2SplinePathSamplerScript.MIN_FLATNESS_TOLERANCE_METERS
	)
	var resolved_depth_limit := maxi(max_subdivision_depth, 0)
	var resolved_sample_limit := maxi(
		max_samples_per_span,
		MIN_MAX_SAMPLES_PER_SPAN
	)
	# One slot is reserved for a midpoint contact probe when the shared
	# sampler resolves a short, straight span with endpoints alone.
	var sampler_sample_limit := maxi(resolved_sample_limit - 1, 2)
	var sampled_guide: Dictionary = (
		ForgeV2SplinePathSamplerScript.sample_auto_curve(
			control_positions,
			resolved_max_spacing,
			resolved_flatness,
			resolved_depth_limit,
			sampler_sample_limit
		)
	)
	var guide_points: PackedVector3Array = sampled_guide.get(
		"points",
		PackedVector3Array()
	)
	var guide_span_offsets: PackedInt32Array = sampled_guide.get(
		"span_offsets",
		PackedInt32Array()
	)
	var guide_span_validity: Array = sampled_guide.get(
		"span_validity",
		[]
	) as Array
	var guide_span_reasons: Array = sampled_guide.get(
		"span_reasons",
		[]
	) as Array
	var guide_curve := ForgeV2SplinePathSamplerScript.build_auto_curve(
		control_positions,
		resolved_max_spacing,
		false
	)

	var resolved_points := PackedVector3Array([control_positions[0]])
	var resolved_normals := PackedVector3Array([
		control_surface_normals[0],
	])
	var resolved_contacts := PackedVector3Array()
	if has_contact_authority:
		resolved_contacts.append(control_contact_directions[0].normalized())
	var resolved_span_offsets := PackedInt32Array([0])
	var span_validity: Array[bool] = []
	var span_reasons: Array[StringName] = []
	var all_spans_valid := true
	var overall_reason := REASON_NONE
	var projection_sample_count := 0
	var max_projected_step := (
		resolved_max_spacing * PROJECTED_STEP_ALLOWANCE
	)

	for span_index in range(control_positions.size() - 1):
		var span_valid := true
		var span_reason := REASON_NONE
		if (
			span_index >= guide_span_validity.size()
			or not bool(guide_span_validity[span_index])
		):
			span_valid = false
			span_reason = _read_guide_span_reason(
				guide_span_reasons,
				span_index
			)
		else:
			var interior_guide_points := _collect_span_interior_guide_points(
				guide_points,
				guide_span_offsets,
				span_index
			)
			if interior_guide_points.is_empty():
				# Every authored span gets at least one strict target probe. This
				# prevents a short endpoint-to-endpoint chord from silently
				# crossing a void or switching surfaces.
				interior_guide_points.append(
					guide_curve.sample(span_index, 0.5)
				)
			var maximum_interior_count := resolved_sample_limit - 2
			if interior_guide_points.size() > maximum_interior_count:
				span_valid = false
				span_reason = REASON_SAMPLE_LIMIT
			else:
				for guide_point: Vector3 in interior_guide_points:
					var projection_result := _project_guide_point(
						guide_point,
						locked_target_kind,
						locked_target_id,
						local_to_screen,
						strict_screen_to_target
					)
					projection_sample_count += 1
					if not bool(projection_result.get("valid", false)):
						span_valid = false
						span_reason = StringName(projection_result.get(
							"reason",
							REASON_PROJECTION_INVALID
						))
						break
					if has_contact_authority:
						var projected_contact_direction: Vector3 = (
							projection_result.get(
								"local_contact_direction",
								Vector3.ZERO
							) as Vector3
						)
						if (
							not _vector3_is_finite(projected_contact_direction)
							or projected_contact_direction.length_squared()
							<= NORMAL_EPSILON_SQUARED
						):
							span_valid = false
							span_reason = REASON_TARGET_SAMPLE_INVALID
							break
					var projected_position: Vector3 = projection_result.get(
						"local_position",
						Vector3.ZERO
					) as Vector3
					if (
						resolved_points[resolved_points.size() - 1].distance_to(
							projected_position
						) > max_projected_step
					):
						span_valid = false
						span_reason = REASON_PROJECTION_DISCONTINUITY
						break
					_append_intermediate_sample(
						resolved_points,
						resolved_normals,
						resolved_contacts,
						projected_position,
						projection_result.get(
							"local_normal",
							Vector3.FORWARD
						) as Vector3,
						projection_result.get(
							"local_contact_direction",
							Vector3.ZERO
						) as Vector3,
						has_contact_authority
					)
		if span_valid and (
			resolved_points[resolved_points.size() - 1].distance_to(
				control_positions[span_index + 1]
			) > max_projected_step
		):
			span_valid = false
			span_reason = REASON_PROJECTION_DISCONTINUITY
		_append_exact_control_sample(
			resolved_points,
			resolved_normals,
			resolved_contacts,
			control_positions[span_index + 1],
			control_surface_normals[span_index + 1],
			(
				control_contact_directions[span_index + 1]
				if has_contact_authority
				else Vector3.ZERO
			),
			has_contact_authority
		)
		resolved_span_offsets.append(resolved_points.size() - 1)
		span_validity.append(span_valid)
		span_reasons.append(span_reason)
		if not span_valid:
			all_spans_valid = false
			if overall_reason == REASON_NONE:
				overall_reason = span_reason

	return _build_result(
		all_spans_valid,
		overall_reason,
		resolved_points,
		resolved_normals,
		resolved_contacts,
		resolved_span_offsets,
		span_validity,
		span_reasons,
		locked_target_kind,
		locked_target_id,
		projection_sample_count,
		resolved_sample_limit
	)


static func _project_guide_point(
	guide_point: Vector3,
	locked_target_kind: StringName,
	locked_target_id: StringName,
	local_to_screen: Callable,
	strict_screen_to_target: Callable
) -> Dictionary:
	var screen_variant: Variant = local_to_screen.call(guide_point)
	var screen_result := _read_screen_position(screen_variant)
	if not bool(screen_result.get("valid", false)):
		return {
			"valid": false,
			"reason": REASON_PROJECTION_INVALID,
		}
	var screen_position: Vector2 = screen_result.get(
		"screen_position",
		Vector2.ZERO
	) as Vector2
	var target_variant: Variant = strict_screen_to_target.call(
		screen_position,
		locked_target_kind,
		locked_target_id
	)
	if not target_variant is Dictionary:
		return {
			"valid": false,
			"reason": REASON_PROJECTION_INVALID,
		}
	var target_result: Dictionary = target_variant as Dictionary
	if not bool(target_result.get("valid", false)):
		return {
			"valid": false,
			"reason": REASON_TARGET_MISS,
		}
	var target_kind := StringName(target_result.get(
		"target_kind",
		StringName()
	))
	var target_id := _read_target_id(target_result)
	if target_kind != locked_target_kind or target_id != locked_target_id:
		return {
			"valid": false,
			"reason": REASON_TARGET_MISMATCH,
		}
	var local_position_variant: Variant = target_result.get(
		"local_position",
		null
	)
	var local_normal_variant: Variant = target_result.get(
		"local_normal",
		null
	)
	var local_contact_direction_variant: Variant = target_result.get(
		"local_contact_direction",
		null
	)
	if (
		not local_position_variant is Vector3
		or not local_normal_variant is Vector3
	):
		return {
			"valid": false,
			"reason": REASON_TARGET_SAMPLE_INVALID,
		}
	var local_position := local_position_variant as Vector3
	var local_normal := local_normal_variant as Vector3
	if (
		not _vector3_is_finite(local_position)
		or not _vector3_is_finite(local_normal)
		or local_normal.length_squared() <= NORMAL_EPSILON_SQUARED
	):
		return {
			"valid": false,
			"reason": REASON_TARGET_SAMPLE_INVALID,
		}
	return {
		"valid": true,
		"reason": REASON_NONE,
		"local_position": local_position,
		"local_normal": local_normal.normalized(),
		"local_contact_direction": (
			(local_contact_direction_variant as Vector3).normalized()
			if (
				local_contact_direction_variant is Vector3
				and _vector3_is_finite(
					local_contact_direction_variant as Vector3
				)
				and (local_contact_direction_variant as Vector3).length_squared()
				> NORMAL_EPSILON_SQUARED
			)
			else Vector3.ZERO
		),
	}


static func _read_screen_position(screen_variant: Variant) -> Dictionary:
	var screen_position_variant: Variant = null
	if screen_variant is Vector2:
		screen_position_variant = screen_variant
	elif screen_variant is Dictionary:
		var screen_result := screen_variant as Dictionary
		if not bool(screen_result.get("valid", false)):
			return {"valid": false}
		screen_position_variant = screen_result.get(
			"screen_position",
			null
		)
	if not screen_position_variant is Vector2:
		return {"valid": false}
	var screen_position := screen_position_variant as Vector2
	if not _vector2_is_finite(screen_position):
		return {"valid": false}
	return {
		"valid": true,
		"screen_position": screen_position,
	}


static func _read_target_id(target_result: Dictionary) -> StringName:
	if target_result.has("surface_target_id"):
		return StringName(target_result.get(
			"surface_target_id",
			StringName()
		))
	if target_result.has("target_id"):
		return StringName(target_result.get("target_id", StringName()))
	if target_result.has("source_body_id"):
		return StringName(target_result.get(
			"source_body_id",
			StringName()
		))
	if target_result.has("source_record_id"):
		return StringName(target_result.get(
			"source_record_id",
			StringName()
		))
	return StringName()


static func _collect_span_interior_guide_points(
	guide_points: PackedVector3Array,
	guide_span_offsets: PackedInt32Array,
	span_index: int
) -> PackedVector3Array:
	var interior := PackedVector3Array()
	if (
		span_index < 0
		or span_index + 1 >= guide_span_offsets.size()
	):
		return interior
	var start_offset := int(guide_span_offsets[span_index])
	var end_offset := int(guide_span_offsets[span_index + 1])
	for point_index in range(start_offset + 1, end_offset):
		if point_index >= 0 and point_index < guide_points.size():
			interior.append(guide_points[point_index])
	return interior


static func _read_guide_span_reason(
	guide_span_reasons: Array,
	span_index: int
) -> StringName:
	if span_index >= 0 and span_index < guide_span_reasons.size():
		var guide_reason := StringName(guide_span_reasons[span_index])
		match guide_reason:
			ForgeV2SplinePathSamplerScript.REASON_ZERO_LENGTH_SPAN:
				return REASON_ZERO_LENGTH_SPAN
			ForgeV2SplinePathSamplerScript.REASON_SUBDIVISION_LIMIT:
				return REASON_SUBDIVISION_LIMIT
			ForgeV2SplinePathSamplerScript.REASON_SAMPLE_LIMIT:
				return REASON_SAMPLE_LIMIT
			_:
				if guide_reason != StringName():
					return guide_reason
	return REASON_SUBDIVISION_LIMIT


static func _append_intermediate_sample(
	points: PackedVector3Array,
	normals: PackedVector3Array,
	contact_directions: PackedVector3Array,
	position: Vector3,
	normal: Vector3,
	contact_direction: Vector3,
	has_contact_authority: bool
) -> void:
	if not points.is_empty() and points[points.size() - 1] == position:
		return
	points.append(position)
	normals.append(normal.normalized())
	if has_contact_authority:
		contact_directions.append(contact_direction.normalized())


static func _append_exact_control_sample(
	points: PackedVector3Array,
	normals: PackedVector3Array,
	contact_directions: PackedVector3Array,
	position: Vector3,
	normal: Vector3,
	contact_direction: Vector3,
	has_contact_authority: bool
) -> void:
	if not points.is_empty() and points[points.size() - 1] == position:
		normals[normals.size() - 1] = normal
		if has_contact_authority:
			contact_directions[contact_directions.size() - 1] = (
				contact_direction.normalized()
			)
		return
	points.append(position)
	normals.append(normal)
	if has_contact_authority:
		contact_directions.append(contact_direction.normalized())


static func _build_early_failure(
	control_positions: PackedVector3Array,
	control_surface_normals: PackedVector3Array,
	locked_target_kind: StringName,
	locked_target_id: StringName,
	reason: StringName,
	control_contact_directions: PackedVector3Array = PackedVector3Array()
) -> Dictionary:
	var span_offsets := PackedInt32Array()
	for control_index in range(control_positions.size()):
		span_offsets.append(control_index)
	var span_validity: Array[bool] = []
	var span_reasons: Array[StringName] = []
	for _span_index in range(maxi(control_positions.size() - 1, 0)):
		span_validity.append(false)
		span_reasons.append(reason)
	return _build_result(
		false,
		reason,
		control_positions,
		control_surface_normals,
		control_contact_directions,
		span_offsets,
		span_validity,
		span_reasons,
		locked_target_kind,
		locked_target_id,
		0,
		DEFAULT_MAX_SAMPLES_PER_SPAN
	)


static func _build_result(
	is_valid: bool,
	reason: StringName,
	resolved_points: PackedVector3Array,
	resolved_surface_normals: PackedVector3Array,
	resolved_contact_directions: PackedVector3Array,
	resolved_span_offsets: PackedInt32Array,
	span_validity: Array[bool],
	span_reasons: Array[StringName],
	locked_target_kind: StringName,
	locked_target_id: StringName,
	projection_sample_count: int,
	max_samples_per_span: int
) -> Dictionary:
	return {
		"valid": is_valid,
		"reason": reason,
		"points": resolved_points,
		"surface_normals": resolved_surface_normals,
		"contact_directions": resolved_contact_directions,
		"span_offsets": resolved_span_offsets,
		"span_validity": span_validity,
		"span_reasons": span_reasons,
		"locked_target_kind": locked_target_kind,
		"locked_target_id": locked_target_id,
		"projection_sample_count": projection_sample_count,
		"max_samples_per_span": max_samples_per_span,
	}


static func _vector2_is_finite(value: Vector2) -> bool:
	return is_finite(value.x) and is_finite(value.y)


static func _vector3_is_finite(value: Vector3) -> bool:
	return (
		is_finite(value.x)
		and is_finite(value.y)
		and is_finite(value.z)
	)
