extends SceneTree

const HandSurfaceSeatSolverScript = preload(
	"res://runtime/player/player_hand_surface_seat_solver.gd"
)
const FingerSurfaceGripSolverScript = preload(
	"res://runtime/player/player_finger_surface_grip_solver.gd"
)
const CombatOriginRecordScript = preload("res://core/models/combat_origin_record.gd")

const RESULT_FILE_PATH := "C:/WORKSPACE/player_hand_surface_seat_solver_results.txt"
const ROOT_ORIGIN: StringName = CombatOriginRecordScript.ORIGIN_RL_BONE_ROOT
const SURFACE_ORIGIN: StringName = CombatOriginRecordScript.ORIGIN_PRIMARY_GRIP_CONTACT_SURFACE
const INDEX_PROBE_ORIGIN: StringName = &"CC_Base_R_Index1"
const MIDDLE_PROBE_ORIGIN: StringName = &"CC_Base_R_Mid1"
const RING_PROBE_ORIGIN: StringName = &"CC_Base_R_Ring1"
const PINKY_PROBE_ORIGIN: StringName = &"CC_Base_R_Pinky1"
const INDEX_RADIUS_SOURCE: StringName = &"PlayerDigitHingeRules.index.section1.capsule_radius"
const PINKY_RADIUS_SOURCE: StringName = &"PlayerDigitHingeRules.pinky.section1.capsule_radius"
const CALIBRATION_REVISION: StringName = &"player_digit_local_z_surface_rules_v1"
const INDEX_SKIN_RADIUS_METERS: float = 0.0105
const PINKY_SKIN_RADIUS_METERS: float = 0.0092
const DISTANCE_EPSILON_METERS: float = 0.000002
const TRANSFORM_EPSILON: float = 0.000002
const EXPECTED_COMPLETED_CASE_COUNT: int = 5

var failures: PackedStringArray = []
var check_count: int = 0
var completed_case_count: int = 0


func _init() -> void:
	call_deferred("_run_verification")


func _run_verification() -> void:
	_run_case({
		"label": "small",
		"section_x": PackedFloat32Array([-0.05, -0.02, 0.0, 0.02, 0.05]),
		"center_y": PackedFloat32Array([0.0, 0.0, 0.0, 0.0, 0.0]),
		"center_z": PackedFloat32Array([0.0, 0.0, 0.0, 0.0, 0.0]),
		"half_y": PackedFloat32Array([0.007, 0.007, 0.007, 0.007, 0.007]),
		"half_z": PackedFloat32Array([0.006, 0.006, 0.006, 0.006, 0.006]),
		"index_station": 3,
		"pinky_station": 1,
		"desired_degrees": 22.0,
	})
	_run_case({
		"label": "large",
		"section_x": PackedFloat32Array([-0.07, -0.03, 0.0, 0.03, 0.07]),
		"center_y": PackedFloat32Array([0.0, 0.0, 0.0, 0.0, 0.0]),
		"center_z": PackedFloat32Array([0.0, 0.0, 0.0, 0.0, 0.0]),
		"half_y": PackedFloat32Array([0.026, 0.026, 0.026, 0.026, 0.026]),
		"half_z": PackedFloat32Array([0.030, 0.030, 0.030, 0.030, 0.030]),
		"index_station": 3,
		"pinky_station": 1,
		"desired_degrees": -18.0,
	})
	_run_case({
		"label": "asymmetric_curved",
		"section_x": PackedFloat32Array([-0.065, -0.028, 0.0, 0.026, 0.064]),
		"center_y": PackedFloat32Array([-0.002, 0.001, 0.0, -0.001, 0.003]),
		"center_z": PackedFloat32Array([0.006, 0.002, 0.0, 0.004, 0.010]),
		"half_y": PackedFloat32Array([0.012, 0.010, 0.013, 0.015, 0.011]),
		"half_z": PackedFloat32Array([0.009, 0.011, 0.010, 0.014, 0.012]),
		"index_station": 3,
		"pinky_station": 1,
		"desired_degrees": 14.0,
	})
	# Reproduces the live lifecycle failure shape: both contact radii have the
	# same positive residual while the source and target chords already match.
	# A chord-only rotation cannot improve it; a C0-radial weapon translation can.
	_run_case({
		"label": "common_radial_gap",
		"section_x": PackedFloat32Array([-0.065, -0.028, 0.0, 0.026, 0.064]),
		"center_y": PackedFloat32Array([0.0, 0.0, 0.0, 0.0, 0.0]),
		"center_z": PackedFloat32Array([0.0, 0.0, 0.0, 0.0, 0.0]),
		"half_y": PackedFloat32Array([0.012, 0.012, 0.012, 0.012, 0.012]),
		"half_z": PackedFloat32Array([0.010, 0.010, 0.010, 0.010, 0.010]),
		"index_station": 3,
		"pinky_station": 1,
		"desired_degrees": 0.0,
		"desired_radial_translation_prepared": Vector3.FORWARD * 0.02885,
	})
	# An off-normal ray against a rectangular side is the regression that the old
	# `first boundary radius + skin radius` approximation could not seat tangentially.
	_run_case({
		"label": "oblique_exact_tangent",
		"section_x": PackedFloat32Array([-0.065, -0.028, 0.0, 0.026, 0.064]),
		"center_y": PackedFloat32Array([0.0, 0.0, 0.0, 0.0, 0.0]),
		"center_z": PackedFloat32Array([0.0, 0.0, 0.0, 0.0, 0.0]),
		"half_y": PackedFloat32Array([0.012, 0.012, 0.012, 0.012, 0.012]),
		"half_z": PackedFloat32Array([0.010, 0.010, 0.010, 0.010, 0.010]),
		"index_station": 3,
		"pinky_station": 1,
		"desired_degrees": 0.0,
		"index_radial_direction": Vector3(0.0, 0.9, 0.4358899),
		"pinky_radial_direction": Vector3(0.0, 0.9, 0.4358899),
	})
	_verify_explicit_failures()
	_finish()


func _run_case(case_state: Dictionary) -> void:
	var label: String = String(case_state.get("label", "case"))
	var prepared_surface: Dictionary = _prepare_surface(case_state, label)
	_check(bool(prepared_surface.get("valid", false)), "%s_surface_not_prepared" % label)
	_check(
		bool((prepared_surface.get("capsule_surface_topology", {}) as Dictionary).get("closed", false)),
		"%s_surface_not_closed" % label
	)
	if not bool(prepared_surface.get("valid", false)):
		return
	var section_x: PackedFloat32Array = case_state.get("section_x") as PackedFloat32Array
	var center_y: PackedFloat32Array = case_state.get("center_y") as PackedFloat32Array
	var center_z: PackedFloat32Array = case_state.get("center_z") as PackedFloat32Array
	var half_z: PackedFloat32Array = case_state.get("half_z") as PackedFloat32Array
	var half_y: PackedFloat32Array = case_state.get("half_y") as PackedFloat32Array
	var index_station: int = int(case_state.get("index_station", 0))
	var pinky_station: int = int(case_state.get("pinky_station", 0))
	var pivot_station: int = section_x.size() / 2
	var c0 := Vector3(
		section_x[pivot_station],
		center_y[pivot_station],
		center_z[pivot_station]
	)
	var ci := Vector3(
		section_x[index_station],
		center_y[index_station],
		center_z[index_station]
	)
	var cp := Vector3(
		section_x[pinky_station],
		center_y[pinky_station],
		center_z[pinky_station]
	)
	var index_radial_direction: Vector3 = (
		case_state.get("index_radial_direction", Vector3.FORWARD) as Vector3
	).normalized()
	var pinky_radial_direction: Vector3 = (
		case_state.get("pinky_radial_direction", Vector3.FORWARD) as Vector3
	).normalized()
	var index_boundary_radius: float = _fixture_rectangular_boundary_radius(
		index_radial_direction,
		half_y[index_station],
		half_z[index_station]
	)
	var pinky_boundary_radius: float = _fixture_rectangular_boundary_radius(
		pinky_radial_direction,
		half_y[pinky_station],
		half_z[pinky_station]
	)
	var index_target_prepared := ci + index_radial_direction * (
		index_boundary_radius + INDEX_SKIN_RADIUS_METERS
	)
	var pinky_target_prepared := cp + pinky_radial_direction * (
		pinky_boundary_radius + PINKY_SKIN_RADIUS_METERS
	)
	var desired_rotation := Basis(
		Vector3.UP,
		deg_to_rad(float(case_state.get("desired_degrees", 0.0)))
	).orthonormalized()
	var desired_radial_translation_prepared: Vector3 = case_state.get(
		"desired_radial_translation_prepared",
		Vector3.ZERO
	) as Vector3
	var desired_radial_translation_world: Vector3 = (
		desired_rotation * desired_radial_translation_prepared
	)
	var desired_correction := _make_weapon_correction(
		desired_rotation,
		c0,
		desired_radial_translation_world
	)
	var anatomy_state: Dictionary = _build_anatomy_state(
		desired_correction * index_target_prepared,
		desired_correction * pinky_target_prepared
	)
	var solver = HandSurfaceSeatSolverScript.new()
	var first: Dictionary = solver.solve_prepared(
		prepared_surface,
		anatomy_state,
		c0,
		ci,
		cp,
		Vector3.RIGHT,
		SURFACE_ORIGIN,
		ROOT_ORIGIN
	)
	var second: Dictionary = solver.solve_prepared(
		prepared_surface,
		anatomy_state,
		c0,
		ci,
		cp,
		Vector3.RIGHT,
		SURFACE_ORIGIN,
		ROOT_ORIGIN
	)

	_check(bool(first.get("valid", false)), "%s_solve_invalid_%s" % [label, String(first.get("status", "missing"))])
	_check(bool(first.get("accepted", false)), "%s_solve_not_accepted" % label)
	_check(bool(first.get("safe_to_apply", false)), "%s_solve_not_safe" % label)
	_check(
		StringName(first.get("status", &"")) == &"weapon_surface_seat_solved",
		"%s_status_not_solved" % label
	)
	_check(
		absf(float(first.get("index_radial_error_meters", INF)))
			<= HandSurfaceSeatSolverScript.ACCEPTED_RADIAL_ERROR_METERS + DISTANCE_EPSILON_METERS,
		"%s_index_outside_acceptance_band" % label
	)
	_check(
		absf(float(first.get("pinky_radial_error_meters", INF)))
			<= HandSurfaceSeatSolverScript.ACCEPTED_RADIAL_ERROR_METERS + DISTANCE_EPSILON_METERS,
		"%s_pinky_outside_acceptance_band" % label
	)
	_check(
		absf(float(first.get("index_target_surface_clearance_error_meters", INF)))
			<= HandSurfaceSeatSolverScript.CLEARANCE_ROOT_TOLERANCE_METERS
			+ DISTANCE_EPSILON_METERS,
		"%s_index_exact_tangent_root_missed" % label
	)
	_check(
		absf(float(first.get("pinky_target_surface_clearance_error_meters", INF)))
			<= HandSurfaceSeatSolverScript.CLEARANCE_ROOT_TOLERANCE_METERS
			+ DISTANCE_EPSILON_METERS,
		"%s_pinky_exact_tangent_root_missed" % label
	)
	_check(
		bool(first.get("index_authority_proximal_safe", false))
		and float(first.get("index_authority_proximal_penetration_meters", INF))
			<= HandSurfaceSeatSolverScript.MAX_AUTHORITY_PROXIMAL_PENETRATION_METERS
			+ DISTANCE_EPSILON_METERS,
		"%s_index_authority_hard_cap_failed" % label
	)
	_check(
		bool(first.get("pinky_authority_proximal_safe", false))
		and float(first.get("pinky_authority_proximal_penetration_meters", INF))
			<= HandSurfaceSeatSolverScript.MAX_AUTHORITY_PROXIMAL_PENETRATION_METERS
			+ DISTANCE_EPSILON_METERS,
		"%s_pinky_authority_hard_cap_failed" % label
	)
	_check(
		(first.get("index_handle_target_point_world", Vector3.ZERO) as Vector3).distance_to(
			anatomy_state.get("index_point_world") as Vector3
		) <= HandSurfaceSeatSolverScript.ACCEPTED_RADIAL_ERROR_METERS + DISTANCE_EPSILON_METERS,
		"%s_index_handle_target_did_not_reach_fixed_bone" % label
	)
	_check(
		(first.get("pinky_handle_target_point_world", Vector3.ZERO) as Vector3).distance_to(
			anatomy_state.get("pinky_point_world") as Vector3
		) <= HandSurfaceSeatSolverScript.ACCEPTED_RADIAL_ERROR_METERS + DISTANCE_EPSILON_METERS,
		"%s_pinky_handle_target_did_not_reach_fixed_bone" % label
	)

	var correction: Transform3D = first.get(
		"candidate_weapon_correction_about_grip_world",
		Transform3D.IDENTITY
	) as Transform3D
	var corrected_axis: Vector3 = (correction.basis * Vector3.RIGHT).normalized()
	var c0_displacement_world: Vector3 = correction * c0 - c0
	_check(
		absf(c0_displacement_world.dot(Vector3.RIGHT)) <= TRANSFORM_EPSILON,
		"%s_c0_moved_axially" % label
	)
	_check(
		absf(float(first.get("grip_pivot_c0_displacement_axial_meters", INF)))
			<= TRANSFORM_EPSILON,
		"%s_reported_c0_axial_displacement" % label
	)
	_check(
		(first.get("corrected_grip_pivot_c0_world", Vector3.ZERO) as Vector3).distance_to(
			correction * c0
		) <= TRANSFORM_EPSILON,
		"%s_corrected_c0_diagnostic_mismatch" % label
	)
	if desired_radial_translation_prepared.length_squared() > 0.0:
		_check(
			c0_displacement_world.distance_to(desired_radial_translation_world)
				<= HandSurfaceSeatSolverScript.ACCEPTED_RADIAL_ERROR_METERS
				+ DISTANCE_EPSILON_METERS,
			"%s_c0_radial_translation_not_recovered" % label
		)
	_check(
		absf(correction.basis.determinant() - 1.0) <= TRANSFORM_EPSILON,
		"%s_correction_not_rigid" % label
	)
	_check(
		(correction * ci).distance_to(
			first.get("corrected_index_slice_center_world", Vector3.ZERO) as Vector3
		) <= TRANSFORM_EPSILON,
		"%s_index_slice_center_not_weapon_composed" % label
	)
	_check(
		(correction * cp).distance_to(
			first.get("corrected_pinky_slice_center_world", Vector3.ZERO) as Vector3
		) <= TRANSFORM_EPSILON,
		"%s_pinky_slice_center_not_weapon_composed" % label
	)
	var expected_axis: Vector3 = (desired_rotation * Vector3.RIGHT).normalized()
	corrected_axis = first.get(
		"corrected_endcap_axis_world",
		Vector3.ZERO
	) as Vector3
	_check(
		corrected_axis.dot(expected_axis) >= 0.995,
		"%s_corrected_axis_did_not_follow_local_handle" % label
	)
	_check(
		correction.basis.y.normalized().dot(Vector3.UP) >= 0.999,
		"%s_shortest_arc_consumed_manual_axial_roll" % label
	)
	_check(
		(first.get("index_point_world", Vector3.ZERO) as Vector3).distance_to(
			anatomy_state.get("index_point_world") as Vector3
		) <= TRANSFORM_EPSILON,
		"%s_index_hand_point_mutated" % label
	)
	_check(
		(first.get("pinky_point_world", Vector3.ZERO) as Vector3).distance_to(
			anatomy_state.get("pinky_point_world") as Vector3
		) <= TRANSFORM_EPSILON,
		"%s_pinky_hand_point_mutated" % label
	)
	_check(
		StringName(first.get("candidate_weapon_correction_about_grip_world_origin_id", &""))
			== ROOT_ORIGIN,
		"%s_correction_origin_missing" % label
	)
	_check(
		StringName(first.get("index_point_source_origin_id", &"")) == INDEX_PROBE_ORIGIN,
		"%s_index_probe_provenance_missing" % label
	)
	_check(
		StringName(first.get("pinky_point_source_origin_id", &"")) == PINKY_PROBE_ORIGIN,
		"%s_pinky_probe_provenance_missing" % label
	)
	_check(
		StringName(first.get("index_skin_to_bone_radius_source_id", &""))
			== INDEX_RADIUS_SOURCE,
		"%s_index_radius_provenance_missing" % label
	)
	_check(
		StringName(first.get("pinky_skin_to_bone_radius_source_id", &""))
			== PINKY_RADIUS_SOURCE,
		"%s_pinky_radius_provenance_missing" % label
	)
	_check(
		StringName(first.get("skin_radius_calibration_revision", &""))
			== CALIBRATION_REVISION,
		"%s_calibration_revision_missing" % label
	)
	_check(not first.has("candidate_hand_basis_world"), "%s_returned_forbidden_hand_candidate" % label)
	_check(not first.has("adjusted_alignment_point_hand_local"), "%s_returned_forbidden_hand_alignment" % label)
	_check(
		String(first.get("seat_signature", "")) == String(second.get("seat_signature", "")),
		"%s_seat_signature_not_deterministic" % label
	)
	var second_correction: Transform3D = second.get(
		"candidate_weapon_correction_about_grip_world",
		Transform3D.IDENTITY
	) as Transform3D
	_check(
		_transform_is_equal_approx(correction, second_correction, TRANSFORM_EPSILON),
		"%s_correction_not_deterministic" % label
	)
	completed_case_count += 1


func _verify_explicit_failures() -> void:
	var case_state: Dictionary = {
		"section_x": PackedFloat32Array([-0.05, -0.02, 0.0, 0.02, 0.05]),
		"center_y": PackedFloat32Array([0.0, 0.0, 0.0, 0.0, 0.0]),
		"center_z": PackedFloat32Array([0.0, 0.0, 0.0, 0.0, 0.0]),
		"half_y": PackedFloat32Array([0.01, 0.01, 0.01, 0.01, 0.01]),
		"half_z": PackedFloat32Array([0.01, 0.01, 0.01, 0.01, 0.01]),
	}
	var prepared_surface: Dictionary = _prepare_surface(case_state, "failure")
	if not bool(prepared_surface.get("valid", false)):
		_check(false, "failure_surface_not_prepared")
		return
	var anatomy_state: Dictionary = _build_anatomy_state(
		Vector3(0.02, 0.0, 0.0205),
		Vector3(-0.02, 0.0, 0.0192)
	)
	var solver = HandSurfaceSeatSolverScript.new()
	var missing_radius_source: Dictionary = anatomy_state.duplicate(true)
	missing_radius_source["index_skin_to_bone_radius_source_id"] = StringName()
	var missing_source_result: Dictionary = solver.solve_prepared(
		prepared_surface,
		missing_radius_source,
		Vector3.ZERO,
		Vector3(0.02, 0.0, 0.0),
		Vector3(-0.02, 0.0, 0.0),
		Vector3.RIGHT,
		SURFACE_ORIGIN,
		ROOT_ORIGIN
	)
	_check(not bool(missing_source_result.get("valid", true)), "missing_radius_source_was_accepted")
	_check(
		StringName(missing_source_result.get("status", &""))
			== &"index_skin_to_bone_radius_source_id_missing",
		"missing_radius_source_status_wrong"
	)
	var outside_center_result: Dictionary = solver.solve_prepared(
		prepared_surface,
		anatomy_state,
		Vector3.ZERO,
		Vector3(0.2, 0.0, 0.0),
		Vector3(-0.02, 0.0, 0.0),
		Vector3.RIGHT,
		SURFACE_ORIGIN,
		ROOT_ORIGIN
	)
	_check(not bool(outside_center_result.get("valid", true)), "outside_ci_was_accepted")
	_check(
		StringName(outside_center_result.get("status", &""))
			== &"ci_not_inside_closed_handle",
		"outside_ci_status_wrong"
	)


func _build_anatomy_state(index_world: Vector3, pinky_world: Vector3) -> Dictionary:
	var index_to_pinky: Vector3 = pinky_world - index_world
	var along_chord: Vector3 = (
		index_to_pinky.normalized()
		if index_to_pinky.length_squared() > 0.000000000001
		else Vector3.RIGHT
	)
	var proximal_capsules: Array[Dictionary] = []
	for capsule_record: Dictionary in [
		{
			"digit_id": &"index",
			"start": index_world,
			"end": index_world + along_chord * 0.001,
			"start_source": INDEX_PROBE_ORIGIN,
			"end_source": &"CC_Base_R_Index2",
			"radius": INDEX_SKIN_RADIUS_METERS,
			"radius_source": INDEX_RADIUS_SOURCE,
		},
		{
			"digit_id": &"middle",
			"start": index_world,
			"end": index_world + along_chord * 0.001,
			"start_source": MIDDLE_PROBE_ORIGIN,
			"end_source": &"CC_Base_R_Mid2",
			"radius": INDEX_SKIN_RADIUS_METERS,
			"radius_source": &"PlayerDigitHingeRules.middle.section1.capsule_radius",
		},
		{
			"digit_id": &"ring",
			"start": pinky_world,
			"end": pinky_world - along_chord * 0.001,
			"start_source": RING_PROBE_ORIGIN,
			"end_source": &"CC_Base_R_Ring2",
			"radius": PINKY_SKIN_RADIUS_METERS,
			"radius_source": &"PlayerDigitHingeRules.ring.section1.capsule_radius",
		},
		{
			"digit_id": &"pinky",
			"start": pinky_world,
			"end": pinky_world - along_chord * 0.001,
			"start_source": PINKY_PROBE_ORIGIN,
			"end_source": &"CC_Base_R_Pinky2",
			"radius": PINKY_SKIN_RADIUS_METERS,
			"radius_source": PINKY_RADIUS_SOURCE,
		},
	]:
		proximal_capsules.append({
			"digit_id": capsule_record.get("digit_id", StringName()),
			"section_index": 0,
			"segment_start_world": capsule_record.get("start", Vector3.ZERO),
			"segment_start_world_origin_id": ROOT_ORIGIN,
			"segment_start_source_origin_id": capsule_record.get(
				"start_source",
				StringName()
			),
			"segment_end_world": capsule_record.get("end", Vector3.ZERO),
			"segment_end_world_origin_id": ROOT_ORIGIN,
			"segment_end_source_origin_id": capsule_record.get(
				"end_source",
				StringName()
			),
			"radius_meters": float(capsule_record.get("radius", 0.0)),
			"radius_source_id": capsule_record.get(
				"radius_source",
				StringName()
			),
		})
	return {
		"valid": true,
		"index_point_world": index_world,
		"index_point_world_origin_id": ROOT_ORIGIN,
		"index_point_source_origin_id": INDEX_PROBE_ORIGIN,
		"pinky_point_world": pinky_world,
		"pinky_point_world_origin_id": ROOT_ORIGIN,
		"pinky_point_source_origin_id": PINKY_PROBE_ORIGIN,
		"index_skin_to_bone_radius_meters": INDEX_SKIN_RADIUS_METERS,
		"index_skin_to_bone_radius_source_id": INDEX_RADIUS_SOURCE,
		"pinky_skin_to_bone_radius_meters": PINKY_SKIN_RADIUS_METERS,
		"pinky_skin_to_bone_radius_source_id": PINKY_RADIUS_SOURCE,
		"skin_radius_calibration_revision": CALIBRATION_REVISION,
		"ordinary_proximal_capsules": proximal_capsules,
		"ordinary_proximal_capsules_origin_id": ROOT_ORIGIN,
		"enforce_ordinary_proximal_safety": true,
	}


func _fixture_rectangular_boundary_radius(
	direction: Vector3,
	half_y: float,
	half_z: float
) -> float:
	var y_limit: float = INF if absf(direction.y) <= 0.0000001 else half_y / absf(direction.y)
	var z_limit: float = INF if absf(direction.z) <= 0.0000001 else half_z / absf(direction.z)
	return minf(y_limit, z_limit)


func _prepare_surface(case_state: Dictionary, label: String) -> Dictionary:
	var mesh := ArrayMesh.new()
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _build_swept_prism_triangles(case_state)
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var surface_solver = FingerSurfaceGripSolverScript.new()
	return surface_solver.prepare_surface(
		mesh,
		Transform3D.IDENTITY,
		{
			"bvh_leaf_triangles": 2,
			"grip_filter_signature": "hand_surface_seat_%s" % label,
			"surface_source_origin_id": SURFACE_ORIGIN,
			"resolved_world_origin_id": ROOT_ORIGIN,
		}
	)


func _build_swept_prism_triangles(case_state: Dictionary) -> PackedVector3Array:
	var section_x: PackedFloat32Array = case_state.get("section_x") as PackedFloat32Array
	var center_y: PackedFloat32Array = case_state.get("center_y") as PackedFloat32Array
	var center_z: PackedFloat32Array = case_state.get("center_z") as PackedFloat32Array
	var half_y: PackedFloat32Array = case_state.get("half_y") as PackedFloat32Array
	var half_z: PackedFloat32Array = case_state.get("half_z") as PackedFloat32Array
	var sections: Array[PackedVector3Array] = []
	for section_index: int in range(section_x.size()):
		var x: float = section_x[section_index]
		var y: float = center_y[section_index]
		var z: float = center_z[section_index]
		var hy: float = half_y[section_index]
		var hz: float = half_z[section_index]
		sections.append(PackedVector3Array([
			Vector3(x, y - hy, z - hz),
			Vector3(x, y + hy, z - hz),
			Vector3(x, y + hy, z + hz),
			Vector3(x, y - hy, z + hz),
		]))
	var triangles := PackedVector3Array()
	for section_index: int in range(sections.size() - 1):
		var a: PackedVector3Array = sections[section_index]
		var b: PackedVector3Array = sections[section_index + 1]
		_append_quad(triangles, a[0], b[0], b[1], a[1])
		_append_quad(triangles, a[1], b[1], b[2], a[2])
		_append_quad(triangles, a[3], a[2], b[2], b[3])
		_append_quad(triangles, a[0], a[3], b[3], b[0])
	var first: PackedVector3Array = sections[0]
	var last: PackedVector3Array = sections[sections.size() - 1]
	_append_quad(triangles, first[0], first[1], first[2], first[3])
	_append_quad(triangles, last[0], last[3], last[2], last[1])
	return triangles


func _append_quad(
	triangles: PackedVector3Array,
	a: Vector3,
	b: Vector3,
	c: Vector3,
	d: Vector3
) -> void:
	triangles.append(a)
	triangles.append(b)
	triangles.append(c)
	triangles.append(a)
	triangles.append(c)
	triangles.append(d)


func _make_weapon_correction(
	rotation: Basis,
	pivot: Vector3,
	radial_translation_world: Vector3
) -> Transform3D:
	return Transform3D(
		rotation,
		pivot + radial_translation_world - rotation * pivot
	)


func _transform_is_equal_approx(
	first: Transform3D,
	second: Transform3D,
	epsilon: float
) -> bool:
	return (
		first.origin.distance_to(second.origin) <= epsilon
		and (first.basis.x - second.basis.x).length() <= epsilon
		and (first.basis.y - second.basis.y).length() <= epsilon
		and (first.basis.z - second.basis.z).length() <= epsilon
	)


func _check(condition: bool, failure: String) -> void:
	check_count += 1
	if not condition and not failures.has(failure):
		failures.append(failure)


func _finish() -> void:
	_check(
		completed_case_count == EXPECTED_COMPLETED_CASE_COUNT,
		"focused_case_completion_count_%d_expected_%d" % [
			completed_case_count,
			EXPECTED_COMPLETED_CASE_COUNT,
		]
	)
	var lines: PackedStringArray = [
		"revision=%s" % String(HandSurfaceSeatSolverScript.SOLVER_REVISION),
		"check_count=%d" % check_count,
		"failure_count=%d" % failures.size(),
	]
	for failure: String in failures:
		lines.append("failure=%s" % failure)
	var file := FileAccess.open(RESULT_FILE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines) + "\n")
		file.close()
	if failures.is_empty():
		print("Player hand surface seat solver verification passed (%d checks)." % check_count)
	else:
		push_error("Player hand surface seat solver verification failed: %s" % "; ".join(failures))
	quit(0 if failures.is_empty() else 1)
