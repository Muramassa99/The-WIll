extends SceneTree

const CapsuleSurfaceQueryScript = preload(
	"res://runtime/player/player_finger_capsule_surface_query.gd"
)
const FingerSurfaceGripSolverScript = preload(
	"res://runtime/player/player_finger_surface_grip_solver.gd"
)
const CombatOriginRecordScript = preload("res://core/models/combat_origin_record.gd")

const RESULT_FILE_PATH := "C:/WORKSPACE/player_finger_capsule_surface_query_results.txt"
const EPSILON_METERS: float = 0.000002
const START_SOURCE: StringName = &"CC_Base_R_Index1"
const END_SOURCE: StringName = &"CC_Base_R_Index2"
const SURFACE_SOURCE: StringName = &"PrimaryGripContactSurfaceOrigin"

var _failures: Array[String] = []
var _checks: int = 0


func _init() -> void:
	call_deferred("_run_verification")


func _run_verification() -> void:
	var query = CapsuleSurfaceQueryScript.new()
	var triangle_surface: Dictionary = _prepare_surface(
		PackedVector3Array([
			Vector3(0.0, 0.0, 0.0),
			Vector3(1.0, 0.0, 0.0),
			Vector3(0.0, 1.0, 0.0),
		]),
		"single_triangle"
	)
	_check(bool(triangle_surface.get("valid", false)), "single_triangle_preparation_failed")
	var open_topology: Dictionary = query.analyze_prepared_surface_topology(triangle_surface)
	_check(bool(open_topology.get("valid", false)), "open_topology_not_analyzed")
	_check(not bool(open_topology.get("closed", true)), "single_triangle_reported_closed")
	_check(int(open_topology.get("boundary_edge_count", 0)) == 3, "single_triangle_boundary_count_not_3")

	var parallel_above: Dictionary = _query(
		query,
		triangle_surface,
		Vector3(0.2, 0.2, 1.0),
		Vector3(0.4, 0.2, 1.0),
		0.25,
		{"classify_inside_solid": false}
	)
	_check_query_ready(parallel_above, "parallel_above")
	_check_close(float(parallel_above.get("nearest_distance_meters", -1.0)), 1.0, "parallel_above_distance")
	_check_close(float(parallel_above.get("signed_overlap_meters", 99.0)), -0.75, "parallel_above_overlap")
	_check_close(float(parallel_above.get("surface_gap_meters", -1.0)), 0.75, "parallel_above_gap")
	_check(
		(parallel_above.get("closest_triangle_point_world", Vector3.ZERO) as Vector3).z == 0.0,
		"parallel_above_triangle_point_not_on_plane"
	)
	_verify_origins(parallel_above, "parallel_above")

	var parallel_below: Dictionary = _query(
		query,
		triangle_surface,
		Vector3(0.2, 0.2, -1.0),
		Vector3(0.4, 0.2, -1.0),
		0.25,
		{"classify_inside_solid": false}
	)
	_check_query_ready(parallel_below, "parallel_below")
	_check_close(float(parallel_below.get("nearest_distance_meters", -1.0)), 1.0, "parallel_below_distance")
	var below_escape: Vector3 = parallel_below.get("contact_escape_normal_world", Vector3.ZERO) as Vector3
	_check(below_escape.dot(Vector3(0.0, 0.0, -1.0)) > 0.9999, "two_sided_below_escape_not_negative_z")

	var edge_distance: Dictionary = _query(
		query,
		triangle_surface,
		Vector3(-0.5, -0.3, 0.2),
		Vector3(1.5, -0.3, 0.2),
		0.0,
		{"classify_inside_solid": false}
	)
	_check_query_ready(edge_distance, "edge_distance")
	_check_close(
		float(edge_distance.get("nearest_distance_meters", -1.0)),
		sqrt(0.3 * 0.3 + 0.2 * 0.2),
		"segment_edge_distance"
	)
	_check(
		StringName(edge_distance.get("closest_feature", &"")) == &"triangle_edge_ab",
		"segment_edge_feature_not_ab"
	)

	var perpendicular_crossing: Dictionary = _query(
		query,
		triangle_surface,
		Vector3(0.25, 0.25, 1.0),
		Vector3(0.25, 0.25, -1.0),
		0.1,
		{}
	)
	_check_query_ready(perpendicular_crossing, "perpendicular_crossing")
	_check_close(float(perpendicular_crossing.get("nearest_distance_meters", -1.0)), 0.0, "perpendicular_crossing_distance")
	_check_close(float(perpendicular_crossing.get("signed_overlap_meters", -1.0)), 0.1, "perpendicular_crossing_overlap")
	_check(bool(perpendicular_crossing.get("segment_intersects_surface", false)), "perpendicular_crossing_not_flagged")

	var coplanar_crossing: Dictionary = _query(
		query,
		triangle_surface,
		Vector3(-0.2, 0.2, 0.0),
		Vector3(1.0, 0.2, 0.0),
		0.05,
		{}
	)
	_check_query_ready(coplanar_crossing, "coplanar_crossing")
	_check_close(float(coplanar_crossing.get("nearest_distance_meters", -1.0)), 0.0, "coplanar_crossing_distance")
	_check(bool(coplanar_crossing.get("segment_intersects_surface", false)), "coplanar_crossing_not_flagged")

	var point_segment: Dictionary = _query(
		query,
		triangle_surface,
		Vector3(0.25, 0.25, 0.5),
		Vector3(0.25, 0.25, 0.5),
		0.1,
		{"classify_inside_solid": false}
	)
	_check_query_ready(point_segment, "point_segment")
	_check_close(float(point_segment.get("nearest_distance_meters", -1.0)), 0.5, "point_segment_distance")

	var small_surface: Dictionary = _prepare_surface(
		PackedVector3Array([
			Vector3(0.0, 0.0, 0.0),
			Vector3(0.01, 0.0, 0.0),
			Vector3(0.0, 0.01, 0.0),
		]),
		"centimeter_triangle"
	)
	var small_crossing: Dictionary = _query(
		query,
		small_surface,
		Vector3(0.002, 0.002, 0.005),
		Vector3(0.002, 0.002, -0.005),
		0.0005,
		{}
	)
	_check_query_ready(small_crossing, "small_crossing")
	_check(
		absf(float(small_crossing.get("nearest_distance_meters", -1.0))) <= 0.00000001,
		"small_crossing_distance_not_zero"
	)
	_check(
		absf(float(small_crossing.get("signed_overlap_meters", -1.0)) - 0.0005) <= 0.00000001,
		"small_crossing_overlap_wrong"
	)
	var small_parallel: Dictionary = _query(
		query,
		small_surface,
		Vector3(0.002, 0.002, 0.001),
		Vector3(0.004, 0.002, 0.001),
		0.0004,
		{"classify_inside_solid": false}
	)
	_check_query_ready(small_parallel, "small_parallel")
	_check(
		absf(float(small_parallel.get("nearest_distance_meters", -1.0)) - 0.001) <= 0.00000001,
		"small_parallel_distance_wrong"
	)
	_check(
		absf(float(small_parallel.get("signed_overlap_meters", 1.0)) + 0.0006) <= 0.00000001,
		"small_parallel_overlap_wrong"
	)

	var open_default: Dictionary = _query(
		query,
		triangle_surface,
		Vector3(0.25, 0.25, 0.5),
		Vector3(0.25, 0.25, 0.7),
		0.1,
		{}
	)
	_check_query_ready(open_default, "open_default")
	_check(not bool(open_default.get("inside_classification_valid", true)), "open_surface_inside_classification_silently_valid")
	_check(StringName(open_default.get("inside_classification_status", &"")) == &"surface_not_closed", "open_surface_status_missing")
	_check(int(open_default.get("surface_topology_boundary_edge_count", 0)) == 3, "open_surface_boundary_diagnostic_missing")
	_check(not bool(open_default.get("signed_distance_valid", true)), "open_surface_signed_distance_silently_valid")

	var cube_surface: Dictionary = _prepare_surface(_cube_triangles(), "closed_cube")
	_check(bool(cube_surface.get("valid", false)), "cube_preparation_failed")
	var cube_topology: Dictionary = query.analyze_prepared_surface_topology(cube_surface)
	_check(bool(cube_topology.get("valid", false)), "cube_topology_not_analyzed")
	_check(bool(cube_topology.get("closed", false)), "cube_not_closed")
	_check(int(cube_topology.get("boundary_edge_count", -1)) == 0, "cube_has_boundary_edges")
	_check(int(cube_topology.get("nonmanifold_edge_count", -1)) == 0, "cube_has_nonmanifold_edges")

	# Rounded CSG endcaps legitimately emit narrow, non-zero-area triangles.
	# Their cross-product squared is between the dedicated m^4 threshold and
	# the old (dimensionally invalid) positional m^2 threshold.  They must remain
	# in the prepared exact surface so a watertight Handle stays watertight.
	var skinny_tetrahedron: PackedVector3Array = _skinny_closed_tetrahedron()
	var skinny_cross_squared: float = (
		(skinny_tetrahedron[1] - skinny_tetrahedron[0]).cross(
			skinny_tetrahedron[2] - skinny_tetrahedron[0]
		).length_squared()
	)
	_check(
		skinny_cross_squared
		> CapsuleSurfaceQueryScript.TRIANGLE_AREA_EPSILON_SQUARED_M4,
		"skinny_fixture_below_triangle_area_threshold"
	)
	_check(
		skinny_cross_squared <= 0.00000000000001,
		"skinny_fixture_does_not_expose_old_units_bug"
	)
	var skinny_surface: Dictionary = _prepare_surface(
		skinny_tetrahedron,
		"closed_skinny_tetrahedron"
	)
	_check(bool(skinny_surface.get("valid", false)), "skinny_surface_preparation_failed")
	_check(
		int(skinny_surface.get("triangle_count", 0)) == 4,
		"skinny_surface_triangle_was_discarded"
	)
	var skinny_topology: Dictionary = query.analyze_prepared_surface_topology(
		skinny_surface
	)
	_check(bool(skinny_topology.get("closed", false)), "skinny_surface_not_closed")
	_check(
		int(skinny_topology.get("boundary_edge_count", -1)) == 0,
		"skinny_surface_has_boundary_edges"
	)
	_check(
		int(skinny_topology.get("nonmanifold_edge_count", -1)) == 0,
		"skinny_surface_has_nonmanifold_edges"
	)
	_check(
		int(skinny_topology.get("degenerate_triangle_count", -1)) == 0,
		"skinny_surface_triangle_reported_degenerate"
	)

	var inside_cube: Dictionary = _query(
		query,
		cube_surface,
		Vector3(-0.2, 0.0, 0.0),
		Vector3(0.2, 0.0, 0.0),
		0.1,
		{"surface_topology_state": cube_topology}
	)
	_check_query_ready(inside_cube, "inside_cube")
	_check(bool(inside_cube.get("inside_classification_valid", false)), "inside_cube_classification_invalid")
	_check(bool(inside_cube.get("segment_axis_inside_solid", false)), "inside_cube_not_inside")
	_check_close(float(inside_cube.get("nearest_distance_meters", -1.0)), 0.8, "inside_cube_unsigned_distance")
	_check_close(float(inside_cube.get("signed_axis_surface_distance_meters", 99.0)), -0.8, "inside_cube_signed_distance")
	_check_close(float(inside_cube.get("signed_overlap_meters", -1.0)), 0.9, "inside_cube_penetration")
	_check(bool(inside_cube.get("surface_topology_closed", false)), "inside_cube_closed_diagnostic_missing")
	var cube_surface_without_bvh: Dictionary = cube_surface.duplicate(true)
	cube_surface_without_bvh["bvh_nodes"] = []
	cube_surface_without_bvh["bvh_triangle_order"] = []
	var inside_cube_without_bvh: Dictionary = _query(
		query,
		cube_surface_without_bvh,
		Vector3(-0.2, 0.0, 0.0),
		Vector3(0.2, 0.0, 0.0),
		0.1,
		{"surface_topology_state": cube_topology}
	)
	_check_query_ready(inside_cube_without_bvh, "inside_cube_without_bvh")
	_check_close(
		float(inside_cube_without_bvh.get("nearest_distance_meters", -1.0)),
		float(inside_cube.get("nearest_distance_meters", -2.0)),
		"bvh_bruteforce_distance_parity"
	)
	_check(
		bool(inside_cube_without_bvh.get("segment_axis_inside_solid", false)),
		"bruteforce_inside_classification_failed"
	)
	_check(
		not bool((inside_cube_without_bvh.get("counts", {}) as Dictionary).get("used_bvh", true)),
		"bruteforce_query_reported_bvh"
	)

	var outside_cube_overlap: Dictionary = _query(
		query,
		cube_surface,
		Vector3(1.2, 0.0, 0.0),
		Vector3(1.4, 0.0, 0.0),
		0.25,
		{"surface_topology_state": cube_topology}
	)
	_check_query_ready(outside_cube_overlap, "outside_cube_overlap")
	_check(bool(outside_cube_overlap.get("inside_classification_valid", false)), "outside_cube_classification_invalid")
	_check(not bool(outside_cube_overlap.get("segment_axis_inside_solid", true)), "outside_cube_reported_inside")
	_check_close(float(outside_cube_overlap.get("nearest_distance_meters", -1.0)), 0.2, "outside_cube_distance")
	_check_close(float(outside_cube_overlap.get("signed_overlap_meters", -1.0)), 0.05, "outside_cube_overlap")
	_check_close(float(outside_cube_overlap.get("penetration_meters", -1.0)), 0.05, "outside_cube_penetration")

	var cube_crossing: Dictionary = _query(
		query,
		cube_surface,
		Vector3(-2.0, 0.13, 0.17),
		Vector3(2.0, 0.13, 0.17),
		0.12,
		{"surface_topology_state": cube_topology}
	)
	_check_query_ready(cube_crossing, "cube_crossing")
	_check(bool(cube_crossing.get("segment_intersects_surface", false)), "cube_crossing_not_flagged")
	_check_close(float(cube_crossing.get("signed_overlap_meters", -1.0)), 0.12, "cube_crossing_overlap")

	var invalid_origin: Dictionary = query.query_prepared_surface(
		cube_surface,
		Vector3.ZERO,
		StringName(),
		Vector3.RIGHT,
		END_SOURCE,
		0.1,
		SURFACE_SOURCE,
		CombatOriginRecordScript.ORIGIN_RL_BONE_ROOT,
		{}
	)
	_check(not bool(invalid_origin.get("valid", true)), "missing_source_origin_accepted")
	_check(StringName(invalid_origin.get("status", &"")) == &"segment_start_source_origin_missing", "missing_source_origin_status_wrong")

	var counts: Dictionary = inside_cube.get("counts", {}) as Dictionary
	_check(bool(counts.get("used_bvh", false)), "bvh_not_used")
	_check(int(counts.get("bvh_node_test_count", 0)) > 0, "bvh_node_tests_not_counted")
	_check(int(counts.get("triangle_test_count", 0)) > 0, "triangle_tests_not_counted")
	_check(int(counts.get("inside_ray_count", 0)) > 0, "inside_rays_not_counted")
	_check(int(counts.get("inside_ray_triangle_test_count", 0)) > 0, "inside_ray_triangles_not_counted")
	_check(
		String(inside_cube.get("surface_signature", "")) == String(cube_surface.get("surface_signature", "")),
		"surface_signature_not_copied"
	)

	_finish(query.get_revision())


func _query(
	query,
	prepared_surface: Dictionary,
	segment_start_world: Vector3,
	segment_end_world: Vector3,
	radius_meters: float,
	options: Dictionary
) -> Dictionary:
	return query.query_prepared_surface(
		prepared_surface,
		segment_start_world,
		START_SOURCE,
		segment_end_world,
		END_SOURCE,
		radius_meters,
		SURFACE_SOURCE,
		CombatOriginRecordScript.ORIGIN_RL_BONE_ROOT,
		options
	)


func _prepare_surface(triangles: PackedVector3Array, signature: String) -> Dictionary:
	var mesh := ArrayMesh.new()
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = triangles
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var solver = FingerSurfaceGripSolverScript.new()
	return solver.prepare_surface(
		mesh,
		Transform3D.IDENTITY,
		{
			"bvh_leaf_triangles": 2,
			"grip_filter_signature": signature,
		}
	)


func _cube_triangles() -> PackedVector3Array:
	return PackedVector3Array([
		# -X
		Vector3(-1, -1, -1), Vector3(-1, -1, 1), Vector3(-1, 1, 1),
		Vector3(-1, -1, -1), Vector3(-1, 1, 1), Vector3(-1, 1, -1),
		# +X
		Vector3(1, -1, -1), Vector3(1, 1, -1), Vector3(1, 1, 1),
		Vector3(1, -1, -1), Vector3(1, 1, 1), Vector3(1, -1, 1),
		# -Y
		Vector3(-1, -1, -1), Vector3(1, -1, -1), Vector3(1, -1, 1),
		Vector3(-1, -1, -1), Vector3(1, -1, 1), Vector3(-1, -1, 1),
		# +Y
		Vector3(-1, 1, -1), Vector3(-1, 1, 1), Vector3(1, 1, 1),
		Vector3(-1, 1, -1), Vector3(1, 1, 1), Vector3(1, 1, -1),
		# -Z
		Vector3(-1, -1, -1), Vector3(-1, 1, -1), Vector3(1, 1, -1),
		Vector3(-1, -1, -1), Vector3(1, 1, -1), Vector3(1, -1, -1),
		# +Z
		Vector3(-1, -1, 1), Vector3(1, -1, 1), Vector3(1, 1, 1),
		Vector3(-1, -1, 1), Vector3(1, 1, 1), Vector3(-1, 1, 1),
	])


func _skinny_closed_tetrahedron() -> PackedVector3Array:
	var a := Vector3(0.0, 0.0, 0.0)
	var b := Vector3(0.0012, 0.0, 0.0)
	var c := Vector3(0.0006, 0.0000147, 0.0)
	var d := Vector3(0.0006, 0.00000735, 0.001)
	return PackedVector3Array([
		# Skinny lower cap, followed by the three regular side faces.
		a, c, b,
		a, b, d,
		b, c, d,
		c, a, d,
	])


func _verify_origins(result: Dictionary, label: String) -> void:
	var world_origin: StringName = CombatOriginRecordScript.ORIGIN_RL_BONE_ROOT
	_check(StringName(result.get("segment_start_world_origin_id", &"")) == world_origin, "%s_start_world_origin" % label)
	_check(StringName(result.get("segment_end_world_origin_id", &"")) == world_origin, "%s_end_world_origin" % label)
	_check(StringName(result.get("closest_segment_point_world_origin_id", &"")) == world_origin, "%s_segment_point_world_origin" % label)
	_check(StringName(result.get("closest_triangle_point_world_origin_id", &"")) == world_origin, "%s_triangle_point_world_origin" % label)
	_check(StringName(result.get("closest_triangle_normal_world_origin_id", &"")) == world_origin, "%s_triangle_normal_world_origin" % label)
	_check(StringName(result.get("closest_segment_point_source_start_origin_id", &"")) == START_SOURCE, "%s_segment_start_provenance" % label)
	_check(StringName(result.get("closest_segment_point_source_end_origin_id", &"")) == END_SOURCE, "%s_segment_end_provenance" % label)
	_check(StringName(result.get("closest_triangle_point_source_origin_id", &"")) == SURFACE_SOURCE, "%s_surface_provenance" % label)


func _check_query_ready(result: Dictionary, label: String) -> void:
	_check(bool(result.get("valid", false)), "%s_query_invalid_%s" % [label, String(result.get("status", "missing"))])
	_check(StringName(result.get("status", &"")) == &"ready", "%s_query_not_ready" % label)


func _check_close(actual: float, expected: float, label: String) -> void:
	_check(absf(actual - expected) <= EPSILON_METERS, "%s_actual_%s_expected_%s" % [label, str(actual), str(expected)])


func _check(condition: bool, failure: String) -> void:
	_checks += 1
	if not condition and not _failures.has(failure):
		_failures.append(failure)


func _finish(revision: StringName) -> void:
	var lines: PackedStringArray = [
		"revision=%s" % String(revision),
		"check_count=%d" % _checks,
		"failure_count=%d" % _failures.size(),
	]
	for failure: String in _failures:
		lines.append("failure=%s" % failure)
	var file := FileAccess.open(RESULT_FILE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines) + "\n")
		file.close()
	if not _failures.is_empty():
		push_error("Player finger capsule surface query verification failed: %s" % "; ".join(_failures))
	else:
		print("Player finger capsule surface query verification passed (%d checks)." % _checks)
	quit(0 if _failures.is_empty() else 1)
