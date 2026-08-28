extends RefCounted
class_name PlayerHandSurfaceSeatSolver

const PlayerFingerCapsuleSurfaceQueryScript = preload(
	"res://runtime/player/player_finger_capsule_surface_query.gd"
)

## Pure three-slice Handle-to-static-hand seat solver.
##
## The hand anatomy is immutable. The returned Transform3D is a rigid weapon-side
## correction around the already-authored C0 grip station. It may rotate by the
## shortest arc and move C0 radially, but its final C0 displacement is constrained
## perpendicular to the input Handle/endcap axis (the selected C0 station plane)
## so it cannot author an axial slide.
## The correction is intended to be left-composed with the weapon/Handle world
## transform. The solver never writes scene, Skeleton3D, weapon, guide, or authored
## endpoint state.

const SOLVER_REVISION: StringName = &"hand_surface_three_slice_weapon_exact_tangent_seat_v3"
const MAX_ITERATIONS: int = 8
const ACCEPTED_RADIAL_ERROR_METERS: float = 0.001
const MAX_AUTHORITY_PROXIMAL_PENETRATION_METERS: float = 0.0005
const CLEARANCE_ROOT_TOLERANCE_METERS: float = 0.000001
const CLEARANCE_BISECTION_STEPS: int = 18
const CLEARANCE_BRACKET_EXPANSION_STEPS: int = 12
const GEOMETRY_EPSILON_METERS: float = 0.0000001
const RAY_EPSILON: float = 0.0000001
const RAY_MARGIN_METERS: float = 0.001
const SCORE_EPSILON: float = 0.000000001
const SIGNATURE_POSITION_STEP_METERS: float = 0.00001
const SIGNATURE_BASIS_STEP: float = 0.000001

var surface_query = PlayerFingerCapsuleSurfaceQueryScript.new()


func get_revision() -> StringName:
	return SOLVER_REVISION


func solve_prepared(
	prepared_surface: Dictionary,
	anatomy_state: Dictionary,
	grip_pivot_c0_world: Vector3,
	index_slice_center_ci_world: Vector3,
	pinky_slice_center_cp_world: Vector3,
	endcap_axis_world: Vector3,
	surface_source_origin_id: StringName,
	resolved_world_origin_id: StringName
) -> Dictionary:
	var result: Dictionary = _make_result()
	var input_state: Dictionary = anatomy_state.duplicate(true)
	input_state["grip_pivot_c0_world"] = grip_pivot_c0_world
	input_state["grip_pivot_c0_world_origin_id"] = resolved_world_origin_id
	input_state["index_slice_center_ci_world"] = index_slice_center_ci_world
	input_state["index_slice_center_ci_world_origin_id"] = resolved_world_origin_id
	input_state["pinky_slice_center_cp_world"] = pinky_slice_center_cp_world
	input_state["pinky_slice_center_cp_world_origin_id"] = resolved_world_origin_id
	input_state["endcap_axis_world"] = endcap_axis_world
	input_state["endcap_axis_world_origin_id"] = resolved_world_origin_id
	input_state["surface_source_origin_id"] = surface_source_origin_id
	input_state["resolved_world_origin_id"] = resolved_world_origin_id
	var validation_status: StringName = _validate_input(prepared_surface, input_state)
	if validation_status != &"ready":
		result["status"] = validation_status
		result["diagnostics"] = {
			"status": validation_status,
			"solver_revision": SOLVER_REVISION,
		}
		return result

	endcap_axis_world = endcap_axis_world.normalized()
	var center_validation: Dictionary = _validate_slice_centers_inside(
		prepared_surface,
		grip_pivot_c0_world,
		index_slice_center_ci_world,
		pinky_slice_center_cp_world,
		surface_source_origin_id,
		resolved_world_origin_id
	)
	if not bool(center_validation.get("valid", false)):
		result["status"] = center_validation.get(
			"status",
			&"slice_center_inside_validation_failed"
		)
		result["diagnostics"] = center_validation
		return result

	var surface_bounds: AABB = _resolve_surface_bounds(prepared_surface)
	if not _aabb_is_finite(surface_bounds):
		result["status"] = &"prepared_surface_bounds_invalid"
		result["diagnostics"] = {
			"status": &"prepared_surface_bounds_invalid",
			"solver_revision": SOLVER_REVISION,
		}
		return result

	var index_bone_world: Vector3 = input_state.get(
		"index_point_world",
		Vector3.ZERO
	) as Vector3
	var pinky_bone_world: Vector3 = input_state.get(
		"pinky_point_world",
		Vector3.ZERO
	) as Vector3
	var index_skin_radius: float = float(input_state.get(
		"index_skin_to_bone_radius_meters",
		0.0
	))
	var pinky_skin_radius: float = float(input_state.get(
		"pinky_skin_to_bone_radius_meters",
		0.0
	))
	var candidate_rotation := Basis.IDENTITY
	var candidate_radial_translation_world := Vector3.ZERO
	var best_overall: Dictionary = {}
	var best_accepted: Dictionary = {}
	var completed_iterations: int = 0
	var ray_count: int = 0
	var bvh_node_test_count: int = 0
	var triangle_test_count: int = 0
	var exact_surface_query_count: int = 0
	var exact_surface_inside_ray_count: int = 0
	var terminal_status: StringName = &"iteration_limit"

	# MAX_ITERATIONS is the number of weapon-side rigid corrections. The ninth
	# sample evaluates the eighth correction without permitting another mutation.
	for sample_index: int in range(MAX_ITERATIONS + 1):
		var sample: Dictionary = _evaluate_candidate(
			prepared_surface,
			surface_bounds,
			candidate_rotation,
			candidate_radial_translation_world,
			grip_pivot_c0_world,
			index_slice_center_ci_world,
			pinky_slice_center_cp_world,
			endcap_axis_world,
			index_bone_world,
			pinky_bone_world,
			index_skin_radius,
			pinky_skin_radius,
			StringName(input_state.get("index_point_source_origin_id")),
			StringName(input_state.get("pinky_point_source_origin_id")),
			surface_source_origin_id,
			resolved_world_origin_id,
			sample_index
		)
		ray_count += int(sample.get("ray_count", 0))
		bvh_node_test_count += int(sample.get("bvh_node_test_count", 0))
		triangle_test_count += int(sample.get("triangle_test_count", 0))
		exact_surface_query_count += int(sample.get("exact_surface_query_count", 0))
		exact_surface_inside_ray_count += int(sample.get(
			"exact_surface_inside_ray_count",
			0
		))
		if not bool(sample.get("valid", false)):
			terminal_status = sample.get(
				"status",
				&"radial_boundary_query_failed"
			) as StringName
			break
		if best_overall.is_empty() or _sample_is_better(sample, best_overall):
			best_overall = sample.duplicate(true)
		if bool(sample.get("accepted", false)):
			if best_accepted.is_empty() or _sample_is_better(sample, best_accepted):
				best_accepted = sample.duplicate(true)
			# The public contract is the explicit +/-1 mm radial band. Once both
			# independent slices satisfy it, further BVH rays only polish an already
			# accepted cosmetic result and make every grip-change event more expensive.
			terminal_status = &"weapon_surface_seat_solved"
			completed_iterations = sample_index
			break
		if sample_index >= MAX_ITERATIONS:
			completed_iterations = MAX_ITERATIONS
			break

		var source_chord: Vector3 = (
			(sample.get("index_target_point_world", Vector3.ZERO) as Vector3)
			- (sample.get("pinky_target_point_world", Vector3.ZERO) as Vector3)
		)
		var target_chord: Vector3 = index_bone_world - pinky_bone_world
		if (
			source_chord.length_squared()
				<= GEOMETRY_EPSILON_METERS * GEOMETRY_EPSILON_METERS
			or target_chord.length_squared()
				<= GEOMETRY_EPSILON_METERS * GEOMETRY_EPSILON_METERS
		):
			terminal_status = &"weapon_pivot_contact_chord_degenerate"
			break
		var incremental_arc: Dictionary = _shortest_arc_state(
			source_chord,
			target_chord
		)
		if not bool(incremental_arc.get("valid", false)):
			terminal_status = incremental_arc.get(
				"status",
				&"weapon_pivot_shortest_arc_invalid"
			) as StringName
			break
		var incremental_rotation := Basis(
			incremental_arc.get("quaternion", Quaternion.IDENTITY) as Quaternion
		).orthonormalized()
		var next_rotation: Basis = (
			incremental_rotation * candidate_rotation
		).orthonormalized()
		var current_c0_world: Vector3 = (
			grip_pivot_c0_world + candidate_radial_translation_world
		)
		var source_midpoint_world: Vector3 = (
			(sample.get("index_target_point_world", Vector3.ZERO) as Vector3)
			+ (sample.get("pinky_target_point_world", Vector3.ZERO) as Vector3)
		) * 0.5
		var target_midpoint_world: Vector3 = (
			index_bone_world + pinky_bone_world
		) * 0.5
		var rotated_source_midpoint_world: Vector3 = (
			current_c0_world
			+ incremental_rotation * (source_midpoint_world - current_c0_world)
		)
		var proposed_translation_world: Vector3 = (
			candidate_radial_translation_world
			+ target_midpoint_world
			- rotated_source_midpoint_world
		)
		# Re-project the complete accumulated C0 displacement into the original C0
		# station plane after every iteration. The axial_reposition_offset authority
		# owns movement along this input endcap axis; this solver owns only the radial
		# plane, regardless of the cosmetic rotation it is also solving.
		candidate_radial_translation_world = (
			proposed_translation_world
			- endcap_axis_world * proposed_translation_world.dot(
				endcap_axis_world
			)
		)
		candidate_rotation = next_rotation
		completed_iterations = sample_index + 1

	var diagnostics: Dictionary = {
		"status": terminal_status,
		"solver_revision": SOLVER_REVISION,
		"surface_signature": String(prepared_surface.get("surface_signature", "")),
		"iteration_limit": MAX_ITERATIONS,
		"completed_iterations": completed_iterations,
		"radial_ray_count": ray_count,
		"radial_bvh_node_test_count": bvh_node_test_count,
		"radial_triangle_test_count": triangle_test_count,
		"exact_surface_query_count": exact_surface_query_count,
		"exact_surface_inside_ray_count": exact_surface_inside_ray_count,
		"accepted_radial_error_min_meters": -ACCEPTED_RADIAL_ERROR_METERS,
		"accepted_radial_error_max_meters": ACCEPTED_RADIAL_ERROR_METERS,
		"authority_proximal_max_penetration_meters": (
			MAX_AUTHORITY_PROXIMAL_PENETRATION_METERS
		),
		"correction_authority": (
			&"weapon_shortest_arc_plus_c0_radial_translation_no_axial_slide"
		),
		"rotation_authority": &"weapon_contact_chord_shortest_arc_no_independent_roll",
		"translation_authority": &"weapon_c0_perpendicular_to_input_endcap_axis",
		"surface_source_origin_id": surface_source_origin_id,
		"resolved_world_origin_id": resolved_world_origin_id,
		"index_point_source_origin_id": input_state.get(
			"index_point_source_origin_id",
			StringName()
		),
		"pinky_point_source_origin_id": input_state.get(
			"pinky_point_source_origin_id",
			StringName()
		),
		"index_skin_to_bone_radius_meters": index_skin_radius,
		"index_skin_to_bone_radius_source_id": input_state.get(
			"index_skin_to_bone_radius_source_id",
			StringName()
		),
		"pinky_skin_to_bone_radius_meters": pinky_skin_radius,
		"pinky_skin_to_bone_radius_source_id": input_state.get(
			"pinky_skin_to_bone_radius_source_id",
			StringName()
		),
		"skin_radius_calibration_revision": input_state.get(
			"skin_radius_calibration_revision",
			StringName()
		),
		"center_inside_validation": center_validation,
	}
	if not best_overall.is_empty():
		diagnostics["best_overall"] = _sample_diagnostics(best_overall)
	if best_accepted.is_empty():
		diagnostics["status"] = (
			terminal_status
			if terminal_status != &"iteration_limit"
			else &"radial_tolerance_not_reached"
		)
		result["status"] = diagnostics["status"]
		result["diagnostics"] = diagnostics
		return result

	var accepted_rotation: Basis = (
		best_accepted.get("weapon_correction_basis_world", Basis.IDENTITY) as Basis
	).orthonormalized()
	var accepted_radial_translation_world: Vector3 = best_accepted.get(
		"weapon_radial_translation_world",
		Vector3.ZERO
	) as Vector3
	var accepted_correction: Transform3D = _make_weapon_correction(
		accepted_rotation,
		grip_pivot_c0_world,
		accepted_radial_translation_world
	)
	var seat_signature: String = _build_seat_signature(
		prepared_surface,
		accepted_correction,
		grip_pivot_c0_world,
		index_slice_center_ci_world,
		pinky_slice_center_cp_world,
		index_bone_world,
		pinky_bone_world,
		index_skin_radius,
		pinky_skin_radius,
		StringName(input_state.get("skin_radius_calibration_revision")),
		surface_source_origin_id,
		resolved_world_origin_id
	)
	diagnostics["status"] = &"weapon_surface_seat_solved"
	diagnostics["best_accepted"] = _sample_diagnostics(best_accepted)
	diagnostics["seat_signature"] = seat_signature
	result["valid"] = true
	result["accepted"] = true
	result["safe_to_apply"] = true
	result["status"] = &"weapon_surface_seat_solved"
	result["solver_revision"] = SOLVER_REVISION
	result["signature"] = seat_signature
	result["seat_signature"] = seat_signature
	result["candidate_weapon_correction_about_grip_world"] = accepted_correction
	result["candidate_weapon_correction_about_grip_world_origin_id"] = (
		resolved_world_origin_id
	)
	result["candidate_weapon_correction_basis_world"] = accepted_rotation
	result["candidate_weapon_correction_basis_world_origin_id"] = (
		resolved_world_origin_id
	)
	result["candidate_weapon_correction_pivot_world"] = grip_pivot_c0_world
	result["candidate_weapon_correction_pivot_world_origin_id"] = (
		resolved_world_origin_id
	)
	result["candidate_weapon_correction_pivot_source_origin_id"] = (
		surface_source_origin_id
	)
	result["candidate_weapon_radial_translation_world"] = (
		accepted_radial_translation_world
	)
	result["candidate_weapon_radial_translation_world_origin_id"] = (
		resolved_world_origin_id
	)
	result["original_grip_pivot_c0_world"] = grip_pivot_c0_world
	result["original_grip_pivot_c0_world_origin_id"] = resolved_world_origin_id
	result["corrected_grip_pivot_c0_world"] = accepted_correction * grip_pivot_c0_world
	result["corrected_grip_pivot_c0_world_origin_id"] = resolved_world_origin_id
	result["grip_pivot_c0_displacement_world"] = accepted_radial_translation_world
	result["grip_pivot_c0_displacement_world_origin_id"] = resolved_world_origin_id
	result["corrected_endcap_axis_world"] = (
		accepted_rotation * endcap_axis_world
	).normalized()
	result["corrected_endcap_axis_world_origin_id"] = resolved_world_origin_id
	var accepted_axial_displacement: float = accepted_radial_translation_world.dot(
		endcap_axis_world
	)
	var accepted_perpendicular_displacement: Vector3 = (
		accepted_radial_translation_world
		- endcap_axis_world * accepted_axial_displacement
	)
	result["grip_pivot_c0_displacement_axis_world"] = endcap_axis_world
	result["grip_pivot_c0_displacement_axis_world_origin_id"] = resolved_world_origin_id
	result["grip_pivot_c0_displacement_axial_meters"] = accepted_axial_displacement
	result["grip_pivot_c0_displacement_perpendicular_world"] = (
		accepted_perpendicular_displacement
	)
	result["grip_pivot_c0_displacement_perpendicular_world_origin_id"] = (
		resolved_world_origin_id
	)
	result["grip_pivot_c0_displacement_perpendicular_meters"] = (
		accepted_perpendicular_displacement.length()
	)
	for field_name: String in [
		"corrected_index_slice_center_world",
		"corrected_pinky_slice_center_world",
		"index_handle_target_point_world",
		"pinky_handle_target_point_world",
		"index_handle_boundary_point_world",
		"pinky_handle_boundary_point_world",
	]:
		result[field_name] = best_accepted.get(field_name, Vector3.ZERO)
		result["%s_origin_id" % field_name] = resolved_world_origin_id
	result["index_point_world"] = index_bone_world
	result["index_point_world_origin_id"] = resolved_world_origin_id
	result["index_point_source_origin_id"] = input_state.get(
		"index_point_source_origin_id",
		StringName()
	)
	result["pinky_point_world"] = pinky_bone_world
	result["pinky_point_world_origin_id"] = resolved_world_origin_id
	result["pinky_point_source_origin_id"] = input_state.get(
		"pinky_point_source_origin_id",
		StringName()
	)
	result["index_radial_error_meters"] = float(best_accepted.get(
		"index_radial_error_meters",
		INF
	))
	result["pinky_radial_error_meters"] = float(best_accepted.get(
		"pinky_radial_error_meters",
		INF
	))
	result["index_handle_boundary_radius_meters"] = float(best_accepted.get(
		"index_handle_boundary_radius_meters",
		0.0
	))
	result["pinky_handle_boundary_radius_meters"] = float(best_accepted.get(
		"pinky_handle_boundary_radius_meters",
		0.0
	))
	for authority_id: String in ["index", "pinky"]:
		for metric_name: String in [
			"target_surface_distance_meters",
			"target_surface_clearance_error_meters",
			"authority_proximal_penetration_meters",
		]:
			var field_name: String = "%s_%s" % [authority_id, metric_name]
			result[field_name] = float(best_accepted.get(field_name, INF))
		result["%s_authority_proximal_safe" % authority_id] = bool(best_accepted.get(
			"%s_authority_proximal_safe" % authority_id,
			false
		))
	result["index_skin_to_bone_radius_meters"] = index_skin_radius
	result["index_skin_to_bone_radius_source_id"] = input_state.get(
		"index_skin_to_bone_radius_source_id",
		StringName()
	)
	result["pinky_skin_to_bone_radius_meters"] = pinky_skin_radius
	result["pinky_skin_to_bone_radius_source_id"] = input_state.get(
		"pinky_skin_to_bone_radius_source_id",
		StringName()
	)
	result["skin_radius_calibration_revision"] = input_state.get(
		"skin_radius_calibration_revision",
		StringName()
	)
	result["diagnostics"] = diagnostics
	return result


func _validate_input(prepared_surface: Dictionary, input_state: Dictionary) -> StringName:
	if not bool(prepared_surface.get("valid", false)):
		return &"invalid_prepared_surface"
	var topology: Dictionary = prepared_surface.get(
		"capsule_surface_topology",
		{}
	) as Dictionary
	if not bool(topology.get("valid", false)) or not bool(topology.get("closed", false)):
		return &"prepared_surface_not_closed"
	var resolved_world_origin_id: StringName = input_state.get(
		"resolved_world_origin_id",
		StringName()
	) as StringName
	var surface_source_origin_id: StringName = input_state.get(
		"surface_source_origin_id",
		StringName()
	) as StringName
	if resolved_world_origin_id == StringName():
		return &"resolved_world_origin_missing"
	if surface_source_origin_id == StringName():
		return &"surface_source_origin_missing"
	if (
		StringName(prepared_surface.get("resolved_world_origin_id", StringName()))
		!= resolved_world_origin_id
	):
		return &"prepared_world_origin_mismatch"
	if (
		StringName(prepared_surface.get("surface_source_origin_id", StringName()))
		!= surface_source_origin_id
	):
		return &"prepared_surface_origin_mismatch"
	if input_state.has("valid") and not bool(input_state.get("valid", false)):
		return &"anatomy_state_invalid"
	for required_origin_key: String in [
		"index_point_world_origin_id",
		"index_point_source_origin_id",
		"pinky_point_world_origin_id",
		"pinky_point_source_origin_id",
		"index_skin_to_bone_radius_source_id",
		"pinky_skin_to_bone_radius_source_id",
		"skin_radius_calibration_revision",
		"grip_pivot_c0_world_origin_id",
		"index_slice_center_ci_world_origin_id",
		"pinky_slice_center_cp_world_origin_id",
		"endcap_axis_world_origin_id",
	]:
		if StringName(input_state.get(required_origin_key, StringName())) == StringName():
			return StringName("%s_missing" % required_origin_key)
	for world_origin_key: String in [
		"index_point_world_origin_id",
		"pinky_point_world_origin_id",
		"grip_pivot_c0_world_origin_id",
		"index_slice_center_ci_world_origin_id",
		"pinky_slice_center_cp_world_origin_id",
		"endcap_axis_world_origin_id",
	]:
		if StringName(input_state.get(world_origin_key)) != resolved_world_origin_id:
			return StringName("%s_mismatch" % world_origin_key)
	for vector_key: String in [
		"index_point_world",
		"pinky_point_world",
		"grip_pivot_c0_world",
		"index_slice_center_ci_world",
		"pinky_slice_center_cp_world",
		"endcap_axis_world",
	]:
		var value_variant: Variant = input_state.get(vector_key, null)
		if not value_variant is Vector3 or not (value_variant as Vector3).is_finite():
			return StringName("%s_invalid" % vector_key)
	var endcap_axis: Vector3 = input_state.get("endcap_axis_world") as Vector3
	if endcap_axis.length_squared() <= GEOMETRY_EPSILON_METERS * GEOMETRY_EPSILON_METERS:
		return &"endcap_axis_degenerate"
	var index_radius: float = float(input_state.get(
		"index_skin_to_bone_radius_meters",
		-1.0
	))
	var pinky_radius: float = float(input_state.get(
		"pinky_skin_to_bone_radius_meters",
		-1.0
	))
	if not is_finite(index_radius) or index_radius < 0.0:
		return &"index_skin_to_bone_radius_invalid"
	if not is_finite(pinky_radius) or pinky_radius < 0.0:
		return &"pinky_skin_to_bone_radius_invalid"
	return &"ready"


func _validate_slice_centers_inside(
	prepared_surface: Dictionary,
	grip_pivot_c0_world: Vector3,
	index_slice_center_ci_world: Vector3,
	pinky_slice_center_cp_world: Vector3,
	surface_source_origin_id: StringName,
	resolved_world_origin_id: StringName
) -> Dictionary:
	var diagnostics: Dictionary = {
		"valid": false,
		"status": &"slice_center_inside_validation_failed",
		"solver_revision": SOLVER_REVISION,
		"surface_source_origin_id": surface_source_origin_id,
		"resolved_world_origin_id": resolved_world_origin_id,
	}
	var topology: Dictionary = prepared_surface.get(
		"capsule_surface_topology",
		{}
	) as Dictionary
	for center_record: Dictionary in [
		{"id": &"c0", "point": grip_pivot_c0_world},
		{"id": &"ci", "point": index_slice_center_ci_world},
		{"id": &"cp", "point": pinky_slice_center_cp_world},
	]:
		var center_id: StringName = center_record.get("id", StringName()) as StringName
		var center_world: Vector3 = center_record.get("point", Vector3.ZERO) as Vector3
		var query: Dictionary = surface_query.query_prepared_surface(
			prepared_surface,
			center_world,
			surface_source_origin_id,
			center_world,
			surface_source_origin_id,
			0.0,
			surface_source_origin_id,
			resolved_world_origin_id,
			{
				"classify_inside_solid": true,
				"surface_topology_state": topology,
			}
		)
		diagnostics["%s_query_status" % String(center_id)] = query.get(
			"status",
			&"unknown"
		)
		diagnostics["%s_inside_classification_status" % String(center_id)] = (
			query.get("inside_classification_status", &"unknown")
		)
		if not bool(query.get("valid", false)):
			diagnostics["status"] = StringName("%s_surface_query_failed" % center_id)
			return diagnostics
		if not bool(query.get("inside_classification_valid", false)):
			diagnostics["status"] = StringName("%s_inside_classification_invalid" % center_id)
			return diagnostics
		if not bool(query.get("segment_axis_inside_solid", false)):
			diagnostics["status"] = StringName("%s_not_inside_closed_handle" % center_id)
			return diagnostics
	diagnostics["valid"] = true
	diagnostics["status"] = &"all_slice_centers_inside_closed_handle"
	return diagnostics


func _evaluate_candidate(
	prepared_surface: Dictionary,
	surface_bounds: AABB,
	weapon_correction_basis_world: Basis,
	weapon_radial_translation_world: Vector3,
	grip_pivot_c0_world: Vector3,
	index_slice_center_ci_world: Vector3,
	pinky_slice_center_cp_world: Vector3,
	endcap_axis_world: Vector3,
	index_bone_world: Vector3,
	pinky_bone_world: Vector3,
	index_skin_radius: float,
	pinky_skin_radius: float,
	index_point_source_origin_id: StringName,
	pinky_point_source_origin_id: StringName,
	surface_source_origin_id: StringName,
	resolved_world_origin_id: StringName,
	sample_index: int
) -> Dictionary:
	var correction: Transform3D = _make_weapon_correction(
		weapon_correction_basis_world,
		grip_pivot_c0_world,
		weapon_radial_translation_world
	)
	var inverse_correction: Transform3D = correction.affine_inverse()
	var index_query: Dictionary = _query_radial_target(
		prepared_surface,
		surface_bounds,
		inverse_correction * index_bone_world,
		index_slice_center_ci_world,
		endcap_axis_world,
		index_skin_radius,
		index_point_source_origin_id,
		surface_source_origin_id,
		resolved_world_origin_id
	)
	var pinky_query: Dictionary = _query_radial_target(
		prepared_surface,
		surface_bounds,
		inverse_correction * pinky_bone_world,
		pinky_slice_center_cp_world,
		endcap_axis_world,
		pinky_skin_radius,
		pinky_point_source_origin_id,
		surface_source_origin_id,
		resolved_world_origin_id
	)
	var ray_count: int = int(index_query.get("ray_count", 0)) + int(
		pinky_query.get("ray_count", 0)
	)
	var bvh_node_test_count: int = int(index_query.get("bvh_node_test_count", 0)) + int(
		pinky_query.get("bvh_node_test_count", 0)
	)
	var triangle_test_count: int = int(index_query.get("triangle_test_count", 0)) + int(
		pinky_query.get("triangle_test_count", 0)
	)
	var exact_surface_query_count: int = int(index_query.get(
		"exact_surface_query_count",
		0
	)) + int(pinky_query.get("exact_surface_query_count", 0))
	var exact_surface_inside_ray_count: int = int(index_query.get(
		"exact_surface_inside_ray_count",
		0
	)) + int(pinky_query.get("exact_surface_inside_ray_count", 0))
	if not bool(index_query.get("valid", false)):
		return {
			"valid": false,
			"status": StringName("index_%s" % String(index_query.get("status", &"radial_query_failed"))),
			"ray_count": ray_count,
			"bvh_node_test_count": bvh_node_test_count,
			"triangle_test_count": triangle_test_count,
			"exact_surface_query_count": exact_surface_query_count,
			"exact_surface_inside_ray_count": exact_surface_inside_ray_count,
		}
	if not bool(pinky_query.get("valid", false)):
		return {
			"valid": false,
			"status": StringName("pinky_%s" % String(pinky_query.get("status", &"radial_query_failed"))),
			"ray_count": ray_count,
			"bvh_node_test_count": bvh_node_test_count,
			"triangle_test_count": triangle_test_count,
			"exact_surface_query_count": exact_surface_query_count,
			"exact_surface_inside_ray_count": exact_surface_inside_ray_count,
		}
	var index_target_world: Vector3 = correction * (
		index_query.get("target_point_prepared_world", Vector3.ZERO) as Vector3
	)
	var pinky_target_world: Vector3 = correction * (
		pinky_query.get("target_point_prepared_world", Vector3.ZERO) as Vector3
	)
	var index_boundary_world: Vector3 = correction * (
		index_query.get("boundary_point_prepared_world", Vector3.ZERO) as Vector3
	)
	var pinky_boundary_world: Vector3 = correction * (
		pinky_query.get("boundary_point_prepared_world", Vector3.ZERO) as Vector3
	)
	var corrected_index_center_world: Vector3 = correction * index_slice_center_ci_world
	var corrected_pinky_center_world: Vector3 = correction * pinky_slice_center_cp_world
	var index_error: float = float(index_query.get("radial_error_meters", INF))
	var pinky_error: float = float(pinky_query.get("radial_error_meters", INF))
	var index_authority_safe: bool = bool(index_query.get(
		"authority_proximal_safe",
		false
	))
	var pinky_authority_safe: bool = bool(pinky_query.get(
		"authority_proximal_safe",
		false
	))
	var index_target_distance: float = index_bone_world.distance_to(index_target_world)
	var pinky_target_distance: float = pinky_bone_world.distance_to(pinky_target_world)
	var max_abs_error: float = maxf(absf(index_error), absf(pinky_error))
	var error_balance: float = absf(index_error - pinky_error)
	var sum_abs_error: float = absf(index_error) + absf(pinky_error)
	var max_target_distance: float = maxf(index_target_distance, pinky_target_distance)
	var correction_angle: float = Quaternion(weapon_correction_basis_world).get_angle()
	var corrected_endcap_axis_world: Vector3 = (
		weapon_correction_basis_world * endcap_axis_world
	).normalized()
	var axial_displacement_meters: float = weapon_radial_translation_world.dot(
		endcap_axis_world
	)
	return {
		"valid": true,
		"accepted": (
			absf(index_error) <= ACCEPTED_RADIAL_ERROR_METERS
			and absf(pinky_error) <= ACCEPTED_RADIAL_ERROR_METERS
			and index_authority_safe
			and pinky_authority_safe
		),
		"status": &"candidate_ready",
		"sample_index": sample_index,
		"ray_count": ray_count,
		"bvh_node_test_count": bvh_node_test_count,
		"triangle_test_count": triangle_test_count,
		"exact_surface_query_count": exact_surface_query_count,
		"exact_surface_inside_ray_count": exact_surface_inside_ray_count,
		"weapon_correction_basis_world": weapon_correction_basis_world,
		"weapon_correction_about_grip_world": correction,
		"weapon_radial_translation_world": weapon_radial_translation_world,
		"weapon_radial_translation_axial_meters": axial_displacement_meters,
		"weapon_radial_translation_perpendicular_meters": (
			weapon_radial_translation_world
			- endcap_axis_world * axial_displacement_meters
		).length(),
		"corrected_grip_pivot_c0_world": correction * grip_pivot_c0_world,
		"corrected_endcap_axis_world": corrected_endcap_axis_world,
		"corrected_index_slice_center_world": corrected_index_center_world,
		"corrected_pinky_slice_center_world": corrected_pinky_center_world,
		"index_target_point_world": index_target_world,
		"pinky_target_point_world": pinky_target_world,
		"index_handle_target_point_world": index_target_world,
		"pinky_handle_target_point_world": pinky_target_world,
		"index_handle_boundary_point_world": index_boundary_world,
		"pinky_handle_boundary_point_world": pinky_boundary_world,
		"index_radial_error_meters": index_error,
		"pinky_radial_error_meters": pinky_error,
		"index_handle_boundary_radius_meters": float(index_query.get(
			"boundary_radius_meters",
			0.0
		)),
		"pinky_handle_boundary_radius_meters": float(pinky_query.get(
			"boundary_radius_meters",
			0.0
		)),
		"index_target_surface_distance_meters": float(index_query.get(
			"target_surface_distance_meters",
			INF
		)),
		"pinky_target_surface_distance_meters": float(pinky_query.get(
			"target_surface_distance_meters",
			INF
		)),
		"index_target_surface_clearance_error_meters": float(index_query.get(
			"target_surface_clearance_error_meters",
			INF
		)),
		"pinky_target_surface_clearance_error_meters": float(pinky_query.get(
			"target_surface_clearance_error_meters",
			INF
		)),
		"index_authority_proximal_penetration_meters": float(index_query.get(
			"authority_proximal_penetration_meters",
			INF
		)),
		"pinky_authority_proximal_penetration_meters": float(pinky_query.get(
			"authority_proximal_penetration_meters",
			INF
		)),
		"index_authority_proximal_safe": index_authority_safe,
		"pinky_authority_proximal_safe": pinky_authority_safe,
		"index_target_distance_meters": index_target_distance,
		"pinky_target_distance_meters": pinky_target_distance,
		"max_abs_radial_error_meters": max_abs_error,
		"radial_error_balance_meters": error_balance,
		"sum_abs_radial_error_meters": sum_abs_error,
		"max_target_point_distance_meters": max_target_distance,
		"correction_angle_radians": correction_angle,
		"score": PackedFloat64Array([
			max_abs_error,
			max_target_distance,
			error_balance,
			sum_abs_error,
			correction_angle,
		]),
	}


func _query_radial_target(
	prepared_surface: Dictionary,
	surface_bounds: AABB,
	bone_point_prepared_world: Vector3,
	slice_center_prepared_world: Vector3,
	endcap_axis_prepared_world: Vector3,
	skin_radius_meters: float,
	bone_point_source_origin_id: StringName,
	surface_source_origin_id: StringName,
	resolved_world_origin_id: StringName
) -> Dictionary:
	var center_to_bone: Vector3 = bone_point_prepared_world - slice_center_prepared_world
	var radial_vector: Vector3 = (
		center_to_bone
		- endcap_axis_prepared_world * center_to_bone.dot(endcap_axis_prepared_world)
	)
	var current_radius: float = radial_vector.length()
	if current_radius <= GEOMETRY_EPSILON_METERS:
		return {
			"valid": false,
			"status": &"radial_direction_degenerate",
			"ray_count": 0,
			"bvh_node_test_count": 0,
			"triangle_test_count": 0,
		}
	var radial_direction: Vector3 = radial_vector / current_radius
	var boundary: Dictionary = _trace_first_boundary(
		prepared_surface,
		surface_bounds,
		slice_center_prepared_world,
		radial_direction
	)
	if not bool(boundary.get("valid", false)):
		return boundary
	var boundary_radius: float = float(boundary.get("distance_meters", 0.0))
	var clearance_target: Dictionary = _solve_exact_radial_tangent_target(
		prepared_surface,
		surface_bounds,
		slice_center_prepared_world,
		radial_direction,
		boundary_radius,
		skin_radius_meters,
		bone_point_source_origin_id,
		surface_source_origin_id,
		resolved_world_origin_id
	)
	var exact_surface_query_count: int = int(clearance_target.get(
		"exact_surface_query_count",
		0
	))
	var exact_surface_inside_ray_count: int = int(clearance_target.get(
		"exact_surface_inside_ray_count",
		0
	))
	var bvh_node_test_count: int = int(boundary.get("bvh_node_test_count", 0)) + int(
		clearance_target.get("bvh_node_test_count", 0)
	)
	var triangle_test_count: int = int(boundary.get("triangle_test_count", 0)) + int(
		clearance_target.get("triangle_test_count", 0)
	)
	if not bool(clearance_target.get("valid", false)):
		return {
			"valid": false,
			"status": clearance_target.get(
				"status",
				&"exact_radial_tangent_target_failed"
			),
			"ray_count": int(boundary.get("ray_count", 0)),
			"bvh_node_test_count": bvh_node_test_count,
			"triangle_test_count": triangle_test_count,
			"exact_surface_query_count": exact_surface_query_count,
			"exact_surface_inside_ray_count": exact_surface_inside_ray_count,
		}
	var target_radius: float = float(clearance_target.get(
		"target_radius_meters",
		boundary_radius
	))
	var authority_state: Dictionary = _query_exact_point_surface_state(
		prepared_surface,
		bone_point_prepared_world,
		skin_radius_meters,
		bone_point_source_origin_id,
		surface_source_origin_id,
		resolved_world_origin_id,
		true
	)
	exact_surface_query_count += int(authority_state.get("exact_surface_query_count", 0))
	exact_surface_inside_ray_count += int(authority_state.get(
		"exact_surface_inside_ray_count",
		0
	))
	bvh_node_test_count += int(authority_state.get("bvh_node_test_count", 0))
	triangle_test_count += int(authority_state.get("triangle_test_count", 0))
	if not bool(authority_state.get("valid", false)):
		return {
			"valid": false,
			"status": authority_state.get(
				"status",
				&"authority_proximal_surface_query_failed"
			),
			"ray_count": int(boundary.get("ray_count", 0)),
			"bvh_node_test_count": bvh_node_test_count,
			"triangle_test_count": triangle_test_count,
			"exact_surface_query_count": exact_surface_query_count,
			"exact_surface_inside_ray_count": exact_surface_inside_ray_count,
		}
	var authority_penetration: float = float(authority_state.get(
		"penetration_meters",
		INF
	))
	var authority_safe: bool = (
		bool(authority_state.get("signed_distance_valid", false))
		and not bool(authority_state.get("inside_solid", false))
		and authority_penetration
			<= MAX_AUTHORITY_PROXIMAL_PENETRATION_METERS + GEOMETRY_EPSILON_METERS
	)
	return {
		"valid": true,
		"status": &"exact_radial_tangent_target_ready",
		"ray_count": int(boundary.get("ray_count", 0)),
		"bvh_node_test_count": bvh_node_test_count,
		"triangle_test_count": triangle_test_count,
		"exact_surface_query_count": exact_surface_query_count,
		"exact_surface_inside_ray_count": exact_surface_inside_ray_count,
		"radial_direction_prepared_world": radial_direction,
		"current_radius_meters": current_radius,
		"boundary_radius_meters": boundary_radius,
		"skin_radius_meters": skin_radius_meters,
		"target_radius_meters": target_radius,
		"target_surface_clearance_meters": skin_radius_meters,
		"target_surface_distance_meters": float(clearance_target.get(
			"target_surface_distance_meters",
			INF
		)),
		"target_surface_clearance_error_meters": float(clearance_target.get(
			"target_surface_clearance_error_meters",
			INF
		)),
		"clearance_bisection_step_count": int(clearance_target.get(
			"bisection_step_count",
			0
		)),
		"authority_proximal_surface_distance_meters": float(authority_state.get(
			"nearest_distance_meters",
			INF
		)),
		"authority_proximal_penetration_meters": authority_penetration,
		"authority_proximal_inside_solid": bool(authority_state.get(
			"inside_solid",
			false
		)),
		"authority_proximal_safe": authority_safe,
		"radial_error_meters": current_radius - target_radius,
		"boundary_point_prepared_world": boundary.get(
			"position_world",
			slice_center_prepared_world + radial_direction * boundary_radius
		),
		"target_point_prepared_world": (
			slice_center_prepared_world + radial_direction * target_radius
		),
		"triangle_index": int(boundary.get("triangle_index", -1)),
	}


func _solve_exact_radial_tangent_target(
	prepared_surface: Dictionary,
	surface_bounds: AABB,
	center_world: Vector3,
	radial_direction_world: Vector3,
	boundary_radius_meters: float,
	target_clearance_meters: float,
	point_source_origin_id: StringName,
	surface_source_origin_id: StringName,
	resolved_world_origin_id: StringName
) -> Dictionary:
	var result: Dictionary = {
		"valid": false,
		"status": &"exact_radial_tangent_not_bracketed",
		"exact_surface_query_count": 0,
		"exact_surface_inside_ray_count": 0,
		"bvh_node_test_count": 0,
		"triangle_test_count": 0,
		"bisection_step_count": 0,
	}
	if target_clearance_meters <= CLEARANCE_ROOT_TOLERANCE_METERS:
		result["valid"] = true
		result["status"] = &"exact_radial_tangent_on_boundary"
		result["target_radius_meters"] = boundary_radius_meters
		result["target_surface_distance_meters"] = 0.0
		result["target_surface_clearance_error_meters"] = -target_clearance_meters
		return result
	var maximum_radius: float = (
		_resolve_ray_length(center_world, surface_bounds)
		+ target_clearance_meters
		+ RAY_MARGIN_METERS
	)
	var lower_radius: float = boundary_radius_meters
	var bracket_span: float = maxf(target_clearance_meters, RAY_MARGIN_METERS)
	var upper_radius: float = minf(lower_radius + bracket_span, maximum_radius)
	var upper_state: Dictionary = {}
	var bracketed := false
	for _expansion_index: int in range(CLEARANCE_BRACKET_EXPANSION_STEPS + 1):
		upper_state = _query_exact_point_surface_state(
			prepared_surface,
			center_world + radial_direction_world * upper_radius,
			0.0,
			point_source_origin_id,
			surface_source_origin_id,
			resolved_world_origin_id,
			false
		)
		_accumulate_exact_surface_counts(result, upper_state)
		if not bool(upper_state.get("valid", false)):
			result["status"] = upper_state.get(
				"status",
				&"exact_radial_tangent_bracket_query_failed"
			)
			return result
		if float(upper_state.get("nearest_distance_meters", -INF)) >= target_clearance_meters:
			bracketed = true
			break
		if upper_radius >= maximum_radius - GEOMETRY_EPSILON_METERS:
			break
		bracket_span *= 2.0
		upper_radius = minf(lower_radius + bracket_span, maximum_radius)
	if not bracketed:
		return result
	var bisection_step_count := 0
	for _bisection_index: int in range(CLEARANCE_BISECTION_STEPS):
		if upper_radius - lower_radius <= CLEARANCE_ROOT_TOLERANCE_METERS:
			break
		bisection_step_count += 1
		var middle_radius: float = (lower_radius + upper_radius) * 0.5
		var middle_state: Dictionary = _query_exact_point_surface_state(
			prepared_surface,
			center_world + radial_direction_world * middle_radius,
			0.0,
			point_source_origin_id,
			surface_source_origin_id,
			resolved_world_origin_id,
			false
		)
		_accumulate_exact_surface_counts(result, middle_state)
		if not bool(middle_state.get("valid", false)):
			result["status"] = middle_state.get(
				"status",
				&"exact_radial_tangent_bisection_query_failed"
			)
			return result
		if float(middle_state.get("nearest_distance_meters", -INF)) >= target_clearance_meters:
			upper_radius = middle_radius
			upper_state = middle_state
		else:
			lower_radius = middle_radius
	var classified_target_state: Dictionary = _query_exact_point_surface_state(
		prepared_surface,
		center_world + radial_direction_world * upper_radius,
		0.0,
		point_source_origin_id,
		surface_source_origin_id,
		resolved_world_origin_id,
		true
	)
	_accumulate_exact_surface_counts(result, classified_target_state)
	if not bool(classified_target_state.get("valid", false)):
		result["status"] = classified_target_state.get(
			"status",
			&"exact_radial_tangent_classification_failed"
		)
		return result
	if (
		not bool(classified_target_state.get("signed_distance_valid", false))
		or bool(classified_target_state.get("inside_solid", false))
	):
		result["status"] = &"exact_radial_tangent_target_not_outside"
		return result
	result["valid"] = true
	result["status"] = &"exact_radial_tangent_ready"
	result["target_radius_meters"] = upper_radius
	result["target_surface_distance_meters"] = float(classified_target_state.get(
		"nearest_distance_meters",
		INF
	))
	result["target_surface_clearance_error_meters"] = float(
		result["target_surface_distance_meters"]
	) - target_clearance_meters
	result["bisection_step_count"] = bisection_step_count
	return result


func _query_exact_point_surface_state(
	prepared_surface: Dictionary,
	point_world: Vector3,
	radius_meters: float,
	point_source_origin_id: StringName,
	surface_source_origin_id: StringName,
	resolved_world_origin_id: StringName,
	classify_inside_solid: bool
) -> Dictionary:
	var query: Dictionary = surface_query.query_prepared_surface(
		prepared_surface,
		point_world,
		point_source_origin_id,
		point_world,
		point_source_origin_id,
		radius_meters,
		surface_source_origin_id,
		resolved_world_origin_id,
		{
			"classify_inside_solid": classify_inside_solid,
			"surface_topology_state": prepared_surface.get(
				"capsule_surface_topology",
				{}
			),
		}
	)
	var counts: Dictionary = query.get("counts", {}) as Dictionary
	return {
		"valid": bool(query.get("valid", false)),
		"status": query.get("status", &"exact_point_surface_query_failed"),
		"nearest_distance_meters": float(query.get("nearest_distance_meters", INF)),
		"penetration_meters": float(query.get("penetration_meters", INF)),
		"signed_distance_valid": bool(query.get("signed_distance_valid", false)),
		"inside_solid": bool(query.get("segment_axis_inside_solid", false)),
		"closest_surface_point_world": query.get(
			"closest_triangle_point_world",
			point_world
		),
		"closest_surface_triangle_index": int(query.get("closest_triangle_index", -1)),
		"exact_surface_query_count": 1,
		"exact_surface_inside_ray_count": int(counts.get("inside_ray_count", 0)),
		"bvh_node_test_count": int(counts.get("bvh_node_test_count", 0)) + int(
			counts.get("inside_ray_bvh_node_test_count", 0)
		),
		"triangle_test_count": int(counts.get("triangle_test_count", 0)) + int(
			counts.get("inside_ray_triangle_test_count", 0)
		),
	}


func _accumulate_exact_surface_counts(total: Dictionary, sample: Dictionary) -> void:
	for key: String in [
		"exact_surface_query_count",
		"exact_surface_inside_ray_count",
		"bvh_node_test_count",
		"triangle_test_count",
	]:
		total[key] = int(total.get(key, 0)) + int(sample.get(key, 0))


func _trace_first_boundary(
	prepared_surface: Dictionary,
	surface_bounds: AABB,
	center_world: Vector3,
	direction_world: Vector3
) -> Dictionary:
	var ray_length: float = _resolve_ray_length(center_world, surface_bounds)
	if ray_length <= RAY_EPSILON:
		return {
			"valid": false,
			"status": &"radial_ray_extent_invalid",
			"ray_count": 1,
			"bvh_node_test_count": 0,
			"triangle_test_count": 0,
		}
	var ray_vector: Vector3 = direction_world.normalized() * ray_length
	var triangles: PackedVector3Array = prepared_surface.get(
		"triangles_world",
		PackedVector3Array()
	) as PackedVector3Array
	var triangle_count: int = triangles.size() / 3
	var bvh_nodes: Array = prepared_surface.get("bvh_nodes", []) as Array
	var triangle_order: Array = prepared_surface.get("bvh_triangle_order", []) as Array
	var use_bvh: bool = (
		not bvh_nodes.is_empty()
		and triangle_order.size() >= triangle_count
	)
	var best_fraction: float = INF
	var best_triangle: int = -1
	var bvh_node_test_count: int = 0
	var triangle_test_count: int = 0
	if use_bvh:
		var stack: Array[int] = [0]
		while not stack.is_empty():
			var node_index: int = stack.pop_back()
			if node_index < 0 or node_index >= bvh_nodes.size():
				continue
			bvh_node_test_count += 1
			var node: Dictionary = bvh_nodes[node_index] as Dictionary
			if not _segment_intersects_aabb(
				center_world,
				ray_vector,
				node.get("bounds", AABB()) as AABB,
				best_fraction
			):
				continue
			var count: int = int(node.get("count", 0))
			if count > 0:
				var start: int = int(node.get("start", 0))
				for order_index: int in range(start, start + count):
					if order_index < 0 or order_index >= triangle_order.size():
						continue
					var triangle_index: int = int(triangle_order[order_index])
					if triangle_index < 0 or triangle_index >= triangle_count:
						continue
					triangle_test_count += 1
					var vertex_offset: int = triangle_index * 3
					var fraction: float = _ray_triangle_fraction(
						center_world,
						ray_vector,
						triangles[vertex_offset],
						triangles[vertex_offset + 1],
						triangles[vertex_offset + 2]
					)
					if _ray_hit_is_better(
						fraction,
						triangle_index,
						best_fraction,
						best_triangle
					):
						best_fraction = fraction
						best_triangle = triangle_index
				continue
			var right_index: int = int(node.get("right", -1))
			var left_index: int = int(node.get("left", -1))
			if right_index >= 0:
				stack.append(right_index)
			if left_index >= 0:
				stack.append(left_index)
	else:
		for triangle_index: int in range(triangle_count):
			triangle_test_count += 1
			var vertex_offset: int = triangle_index * 3
			var fraction: float = _ray_triangle_fraction(
				center_world,
				ray_vector,
				triangles[vertex_offset],
				triangles[vertex_offset + 1],
				triangles[vertex_offset + 2]
			)
			if _ray_hit_is_better(
				fraction,
				triangle_index,
				best_fraction,
				best_triangle
			):
				best_fraction = fraction
				best_triangle = triangle_index
	if best_triangle < 0 or not is_finite(best_fraction):
		return {
			"valid": false,
			"status": &"first_radial_boundary_missing",
			"ray_count": 1,
			"bvh_node_test_count": bvh_node_test_count,
			"triangle_test_count": triangle_test_count,
		}
	return {
		"valid": true,
		"status": &"first_radial_boundary_ready",
		"ray_count": 1,
		"bvh_node_test_count": bvh_node_test_count,
		"triangle_test_count": triangle_test_count,
		"fraction": best_fraction,
		"distance_meters": ray_length * best_fraction,
		"position_world": center_world + ray_vector * best_fraction,
		"triangle_index": best_triangle,
	}


func _ray_hit_is_better(
	fraction: float,
	triangle_index: int,
	best_fraction: float,
	best_triangle: int
) -> bool:
	if fraction <= RAY_EPSILON or fraction > 1.0 + RAY_EPSILON:
		return false
	if fraction < best_fraction - RAY_EPSILON:
		return true
	return (
		absf(fraction - best_fraction) <= RAY_EPSILON
		and (best_triangle < 0 or triangle_index < best_triangle)
	)


func _ray_triangle_fraction(
	origin: Vector3,
	direction: Vector3,
	a: Vector3,
	b: Vector3,
	c: Vector3
) -> float:
	var edge_ab: Vector3 = b - a
	var edge_ac: Vector3 = c - a
	var p_vector: Vector3 = direction.cross(edge_ac)
	var determinant: float = edge_ab.dot(p_vector)
	if absf(determinant) <= RAY_EPSILON:
		return -1.0
	var inverse_determinant: float = 1.0 / determinant
	var t_vector: Vector3 = origin - a
	var u: float = t_vector.dot(p_vector) * inverse_determinant
	if u < -RAY_EPSILON or u > 1.0 + RAY_EPSILON:
		return -1.0
	var q_vector: Vector3 = t_vector.cross(edge_ab)
	var v: float = direction.dot(q_vector) * inverse_determinant
	if v < -RAY_EPSILON or u + v > 1.0 + RAY_EPSILON:
		return -1.0
	var fraction: float = edge_ac.dot(q_vector) * inverse_determinant
	if fraction < -RAY_EPSILON or fraction > 1.0 + RAY_EPSILON:
		return -1.0
	return clampf(fraction, 0.0, 1.0)


func _segment_intersects_aabb(
	origin: Vector3,
	direction: Vector3,
	bounds: AABB,
	maximum_fraction: float
) -> bool:
	var minimum_t: float = 0.0
	var maximum_t: float = minf(1.0, maximum_fraction)
	var bounds_end: Vector3 = bounds.end
	for axis_index: int in range(3):
		var origin_component: float = origin[axis_index]
		var direction_component: float = direction[axis_index]
		var minimum_component: float = bounds.position[axis_index]
		var maximum_component: float = bounds_end[axis_index]
		if absf(direction_component) <= RAY_EPSILON:
			if origin_component < minimum_component or origin_component > maximum_component:
				return false
			continue
		var inverse_direction: float = 1.0 / direction_component
		var first_t: float = (minimum_component - origin_component) * inverse_direction
		var second_t: float = (maximum_component - origin_component) * inverse_direction
		if first_t > second_t:
			var swap_t: float = first_t
			first_t = second_t
			second_t = swap_t
		minimum_t = maxf(minimum_t, first_t)
		maximum_t = minf(maximum_t, second_t)
		if minimum_t > maximum_t:
			return false
	return true


func _resolve_surface_bounds(prepared_surface: Dictionary) -> AABB:
	var bvh_nodes: Array = prepared_surface.get("bvh_nodes", []) as Array
	if not bvh_nodes.is_empty():
		var root_node: Dictionary = bvh_nodes[0] as Dictionary
		var root_bounds_variant: Variant = root_node.get("bounds", null)
		if root_bounds_variant is AABB:
			return root_bounds_variant as AABB
	var triangles: PackedVector3Array = prepared_surface.get(
		"triangles_world",
		PackedVector3Array()
	) as PackedVector3Array
	if triangles.is_empty():
		return AABB(Vector3.INF, Vector3.INF)
	var minimum: Vector3 = triangles[0]
	var maximum: Vector3 = triangles[0]
	for vertex: Vector3 in triangles:
		minimum = minimum.min(vertex)
		maximum = maximum.max(vertex)
	return AABB(minimum, maximum - minimum)


func _resolve_ray_length(center_world: Vector3, bounds: AABB) -> float:
	var farthest_distance: float = 0.0
	for corner_index: int in range(8):
		var corner := Vector3(
			bounds.position.x + (bounds.size.x if (corner_index & 1) != 0 else 0.0),
			bounds.position.y + (bounds.size.y if (corner_index & 2) != 0 else 0.0),
			bounds.position.z + (bounds.size.z if (corner_index & 4) != 0 else 0.0)
		)
		farthest_distance = maxf(farthest_distance, center_world.distance_to(corner))
	return farthest_distance + maxf(RAY_MARGIN_METERS, bounds.size.length() * 0.01)


func _shortest_arc_state(from_direction: Vector3, to_direction: Vector3) -> Dictionary:
	var from_normalized: Vector3 = from_direction.normalized()
	var to_normalized: Vector3 = to_direction.normalized()
	if (
		from_normalized.length_squared() <= GEOMETRY_EPSILON_METERS
		or to_normalized.length_squared() <= GEOMETRY_EPSILON_METERS
	):
		return {
			"valid": false,
			"status": &"weapon_pivot_shortest_arc_direction_degenerate",
		}
	var arc_dot: float = clampf(from_normalized.dot(to_normalized), -1.0, 1.0)
	if arc_dot >= 1.0 - 0.000001:
		return {
			"valid": true,
			"status": &"weapon_pivot_shortest_arc_identity",
			"quaternion": Quaternion.IDENTITY,
		}
	if arc_dot <= -1.0 + 0.000001:
		# A 180-degree correction has no unique no-roll plane. Do not invent one and
		# accidentally consume the separate manual axial-rotation authority.
		return {
			"valid": false,
			"status": &"weapon_pivot_shortest_arc_antiparallel_ambiguous",
		}
	var arc_axis: Vector3 = from_normalized.cross(to_normalized).normalized()
	return {
		"valid": true,
		"status": &"weapon_pivot_shortest_arc_ready",
		"quaternion": Quaternion(arc_axis, acos(arc_dot)).normalized(),
	}


func _make_weapon_correction(
	rotation_world: Basis,
	pivot_world: Vector3,
	radial_translation_world: Vector3
) -> Transform3D:
	var rotation: Basis = rotation_world.orthonormalized()
	return Transform3D(
		rotation,
		pivot_world + radial_translation_world - rotation * pivot_world
	)


func _sample_is_better(candidate: Dictionary, incumbent: Dictionary) -> bool:
	var candidate_score: PackedFloat64Array = candidate.get(
		"score",
		PackedFloat64Array()
	) as PackedFloat64Array
	var incumbent_score: PackedFloat64Array = incumbent.get(
		"score",
		PackedFloat64Array()
	) as PackedFloat64Array
	var score_count: int = mini(candidate_score.size(), incumbent_score.size())
	for score_index: int in range(score_count):
		var delta: float = candidate_score[score_index] - incumbent_score[score_index]
		if absf(delta) <= SCORE_EPSILON:
			continue
		return delta < 0.0
	return int(candidate.get("sample_index", 0)) < int(incumbent.get("sample_index", 0))


func _sample_diagnostics(sample: Dictionary) -> Dictionary:
	return {
		"sample_index": int(sample.get("sample_index", -1)),
		"accepted": bool(sample.get("accepted", false)),
		"index_radial_error_meters": float(sample.get(
			"index_radial_error_meters",
			INF
		)),
		"pinky_radial_error_meters": float(sample.get(
			"pinky_radial_error_meters",
			INF
		)),
		"max_abs_radial_error_meters": float(sample.get(
			"max_abs_radial_error_meters",
			INF
		)),
		"radial_error_balance_meters": float(sample.get(
			"radial_error_balance_meters",
			INF
		)),
		"max_target_point_distance_meters": float(sample.get(
			"max_target_point_distance_meters",
			INF
		)),
		"correction_angle_radians": float(sample.get(
			"correction_angle_radians",
			0.0
		)),
		"weapon_radial_translation_world": sample.get(
			"weapon_radial_translation_world",
			Vector3.ZERO
		),
		"weapon_radial_translation_axial_meters": float(sample.get(
			"weapon_radial_translation_axial_meters",
			INF
		)),
		"weapon_radial_translation_perpendicular_meters": float(sample.get(
			"weapon_radial_translation_perpendicular_meters",
			0.0
		)),
		"index_target_surface_distance_meters": float(sample.get(
			"index_target_surface_distance_meters",
			INF
		)),
		"pinky_target_surface_distance_meters": float(sample.get(
			"pinky_target_surface_distance_meters",
			INF
		)),
		"index_target_surface_clearance_error_meters": float(sample.get(
			"index_target_surface_clearance_error_meters",
			INF
		)),
		"pinky_target_surface_clearance_error_meters": float(sample.get(
			"pinky_target_surface_clearance_error_meters",
			INF
		)),
		"index_authority_proximal_penetration_meters": float(sample.get(
			"index_authority_proximal_penetration_meters",
			INF
		)),
		"pinky_authority_proximal_penetration_meters": float(sample.get(
			"pinky_authority_proximal_penetration_meters",
			INF
		)),
		"index_authority_proximal_safe": bool(sample.get(
			"index_authority_proximal_safe",
			false
		)),
		"pinky_authority_proximal_safe": bool(sample.get(
			"pinky_authority_proximal_safe",
			false
		)),
	}


func _build_seat_signature(
	prepared_surface: Dictionary,
	correction: Transform3D,
	grip_pivot_c0_world: Vector3,
	index_slice_center_ci_world: Vector3,
	pinky_slice_center_cp_world: Vector3,
	index_bone_world: Vector3,
	pinky_bone_world: Vector3,
	index_skin_radius: float,
	pinky_skin_radius: float,
	calibration_revision: StringName,
	surface_source_origin_id: StringName,
	resolved_world_origin_id: StringName
) -> String:
	var digest: Array = [
		String(SOLVER_REVISION),
		String(prepared_surface.get("surface_signature", "")),
		String(surface_source_origin_id),
		String(resolved_world_origin_id),
		String(calibration_revision),
		_quantize_basis(correction.basis, SIGNATURE_BASIS_STEP),
		_quantize_vector(correction.origin, SIGNATURE_POSITION_STEP_METERS),
		_quantize_vector(grip_pivot_c0_world, SIGNATURE_POSITION_STEP_METERS),
		_quantize_vector(index_slice_center_ci_world, SIGNATURE_POSITION_STEP_METERS),
		_quantize_vector(pinky_slice_center_cp_world, SIGNATURE_POSITION_STEP_METERS),
		_quantize_vector(index_bone_world, SIGNATURE_POSITION_STEP_METERS),
		_quantize_vector(pinky_bone_world, SIGNATURE_POSITION_STEP_METERS),
		roundi(index_skin_radius / SIGNATURE_POSITION_STEP_METERS),
		roundi(pinky_skin_radius / SIGNATURE_POSITION_STEP_METERS),
	]
	return "%s:%s" % [String(SOLVER_REVISION), str(hash(digest))]


func _quantize_vector(value: Vector3, step: float) -> PackedInt64Array:
	var resolved_step: float = maxf(step, GEOMETRY_EPSILON_METERS)
	return PackedInt64Array([
		roundi(value.x / resolved_step),
		roundi(value.y / resolved_step),
		roundi(value.z / resolved_step),
	])


func _quantize_basis(value: Basis, step: float) -> PackedInt64Array:
	var resolved_step: float = maxf(step, GEOMETRY_EPSILON_METERS)
	return PackedInt64Array([
		roundi(value.x.x / resolved_step),
		roundi(value.x.y / resolved_step),
		roundi(value.x.z / resolved_step),
		roundi(value.y.x / resolved_step),
		roundi(value.y.y / resolved_step),
		roundi(value.y.z / resolved_step),
		roundi(value.z.x / resolved_step),
		roundi(value.z.y / resolved_step),
		roundi(value.z.z / resolved_step),
	])


func _basis_is_finite(value: Basis) -> bool:
	return value.x.is_finite() and value.y.is_finite() and value.z.is_finite()


func _aabb_is_finite(value: AABB) -> bool:
	return value.position.is_finite() and value.size.is_finite()


func _make_result() -> Dictionary:
	return {
		"valid": false,
		"accepted": false,
		"safe_to_apply": false,
		"status": &"invalid_input",
		"solver_revision": SOLVER_REVISION,
		"signature": "",
		"seat_signature": "",
		"diagnostics": {},
	}
