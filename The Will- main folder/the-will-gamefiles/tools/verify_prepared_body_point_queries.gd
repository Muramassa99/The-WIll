extends SceneTree

const SolverScript = preload("res://runtime/player/hand_target_constraint_solver.gd")
const CollisionResolverScript = preload("res://runtime/combat/combat_collision_legality_resolver.gd")
const NUMERIC_TOLERANCE := 0.000001
const CLEARANCE_OFFSET := SolverScript.DEFAULT_BODY_CLEARANCE_OFFSET_METERS

class LegacyPointQuery:
	extends RefCounted
	var solver

	func query_point_body_restriction(body: Node3D, point: Vector3) -> Dictionary:
		return solver.query_point_body_restriction(body, point)

class CustomPreparedQuery:
	extends RefCounted
	func prepare_body_point_query(_body: Node3D) -> Array[Dictionary]:
		return []
	func query_point_prepared_body_restriction(_prepared: Array[Dictionary], point: Vector3) -> Dictionary:
		return {"legal": false, "inside": true, "body_region": "custom_region", "attachment_name": "custom_attachment",
			"shape_kind": &"custom", "estimated_clearance_meters": -0.125,
			"suggested_correction_world": Vector3.UP, "point_world": point}

var _solver = SolverScript.new()
var _resolver = CollisionResolverScript.new()
var _legacy := LegacyPointQuery.new()
var _kernel: RefCounted
var _checks := 0
var _failures: Array[String] = []
var _numeric_difference_count := 0
var _max_numeric_delta := 0.0
var _numeric_examples: Array[Dictionary] = []
var _native_point_batches := 0
var _native_pose_batches := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_check(ClassDB.class_exists(&"CombatBodyCollisionKernel"), "native_class_registered")
	if not _failures.is_empty(): _finish(); return
	_kernel = ClassDB.instantiate(&"CombatBodyCollisionKernel") as RefCounted
	_check(_kernel != null and _kernel.has_method("query_points") and _kernel.has_method("evaluate_weapon_pose"), "native_methods_available")
	if not _failures.is_empty(): _finish(); return
	_legacy.solver = _solver
	_compare_batch(null, [Vector3.ZERO, Vector3.ONE], "null_root")
	var body := Node3D.new()
	root.add_child(body)
	_compare_batch(body, [Vector3.ZERO], "empty_root")
	_compare_batch(body, [], "empty_points")
	var empty_body_weapon := _weapon_with_points([Vector3.ZERO])
	_compare_weapon(body, empty_body_weapon, Transform3D.IDENTITY, "empty_body_weapon")
	empty_body_weapon.free()
	var box := BoxShape3D.new()
	box.size = Vector3(2.0, 4.0, 6.0)
	var first := _add_shape(body, "First", box)
	var second_box := BoxShape3D.new()
	second_box.size = box.size
	_add_shape(body, "Second", second_box)
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.5
	capsule.height = 3.0
	var cap_node := _add_shape(body, "Capsule", capsule)
	cap_node.position = Vector3(4.0, 0.0, 0.0)
	# Missing areas/shapes and disabled shapes retain the original query semantics.
	body.add_child(Node.new())
	var missing_area := Node3D.new()
	body.add_child(missing_area)
	_add_shape(body, "NullShape", null)
	first.disabled = true
	var points: Array[Vector3] = [
		Vector3.ZERO, Vector3(1.0, 0.0, 0.0), Vector3(1.0, 2.0, 3.0),
		Vector3(3.0, 0.0, 0.0), Vector3(4.5, 0.0, 0.0),
		Vector3(4.0, 1.5, 0.0), Vector3(4.0, -1.5, 0.0),
		Vector3(4.0, 1.5001, 0.0), Vector3(20.0, 20.0, 20.0),
		Vector3(4.0, 0.0, 0.0), Vector3(4.0, 1.0, 0.0), Vector3(0.0, 0.0, 10.0),
	]
	for x in range(-5, 9):
		for y in range(-4, 5):
			for z in range(-3, 4):
				points.append(Vector3(float(x) * 0.6, float(y) * 0.7, float(z) * 0.8))
	_compare_batch(body, points, "ordered_shapes")
	var prepared: Array[Dictionary] = _solver.prepare_body_point_query(body)
	_check(_solver.query_point_prepared_body_restriction(prepared, Vector3.ZERO).attachment_name == "First", "first_inside_order")
	_check(_solver.query_point_prepared_body_restriction(prepared, Vector3(3.0, 0.0, 0.0)).attachment_name == "Capsule", "nearest_outside")
	var ties: Array = _kernel.call("query_points", prepared, PackedVector3Array([Vector3(1.0, 2.0, 3.0), Vector3(0.0, 0.0, 10.0), Vector3(4.0, 0.0, 0.0)]), CLEARANCE_OFFSET)
	_native_point_batches += 1
	_check(ties.size() == 3, "native_tie_batch_size")
	if ties.size() == 3:
		_check(ties[0].get("inside", false) and ties[0].get("attachment_name", "") == "First" and ties[0].get("suggested_correction_world", Vector3.ZERO) == Vector3.RIGHT * CLEARANCE_OFFSET, "native_surface_and_axis_ties")
		_check(not ties[1].get("inside", true) and ties[1].get("attachment_name", "") == "First", "native_nearest_shape_tie_order")
		var center_correction: Vector3 = ties[2].get("suggested_correction_world", Vector3.ZERO)
		_check(ties[2].get("inside", false) and ties[2].get("attachment_name", "") == "Capsule" and center_correction.x > 0.0 and center_correction.y == 0.0 and center_correction.z == 0.0, "native_capsule_center_axis")

	var weapon := Node3D.new()
	root.add_child(weapon)
	var proxy := Node3D.new()
	proxy.name = "WeaponBodyRestrictionProxy"
	weapon.add_child(proxy)
	for index in range(9):
		var sample := Node3D.new()
		sample.name = "WeaponBodySample_%02d" % index
		proxy.add_child(sample)
		sample.position = points[index]
	_compare_weapon(body, weapon, Transform3D.IDENTITY, "initial_weapon")
	_compare_weapon(null, weapon, Transform3D.IDENTITY, "null_body_weapon")
	_compare_weapon(body, null, Transform3D.IDENTITY, "null_weapon")
	var empty_weapon := _weapon_with_points([])
	_compare_weapon(body, empty_weapon, Transform3D.IDENTITY, "empty_weapon")
	empty_weapon.free()
	var defaults_weapon := Node3D.new()
	root.add_child(defaults_weapon)
	var default_samples: Array[Dictionary] = [{}, {"local_position": Vector3(20.0, 20.0, 20.0)}, {"name": "NamedWithoutPosition", "local_position_origin_id": StringName()}]
	defaults_weapon.set_meta(CollisionResolverScript.WEAPON_PROXY_LOCAL_SAMPLE_CACHE_META, default_samples)
	var default_result := _compare_weapon(body, defaults_weapon, Transform3D.IDENTITY, "missing_sample_name_and_position")
	_check(default_result.get("sample_count", -1) == 3 and default_result.get("illegal_sample_count", -1) == 2 and default_result.get("colliding_sample_name", "missing") == "", "sample_defaults_keep_origin_and_empty_name")
	defaults_weapon.free()
	var ordered_weapon := _weapon_with_points([Vector3(0.0, 0.0, 2.5), Vector3.ZERO, Vector3(4.0, 0.0, 0.0)])
	var ordered_result := _compare_weapon(body, ordered_weapon, Transform3D.IDENTITY, "first_collision_not_deepest")
	_check(ordered_result.get("illegal_sample_count", -1) == 3 and ordered_result.get("colliding_sample_name", "") == "WeaponBodySample_00" and ordered_result.get("estimated_clearance_meters", INF) == -0.5, "aggregate_preserves_first_collision_clearance")
	ordered_weapon.free()
	var outside_weapon := _weapon_with_points([Vector3(0.0, 0.0, 10.0), Vector3(4.75, 0.0, 0.0), Vector3(0.0, 0.0, 8.0)])
	var outside_result := _compare_weapon(body, outside_weapon, Transform3D.IDENTITY, "nearest_clearance")
	_check(outside_result.get("legal", false) and outside_result.get("first_collision", {"missing": true}).is_empty() and outside_result.get("estimated_clearance_meters", INF) == 0.25, "aggregate_uses_minimum_legal_clearance")
	outside_weapon.free()
	_compare_custom_solver(body, weapon)

	var changed_point := Vector3(1.5, 0.0, 0.0)
	var before_mutation: Dictionary = _solver.query_point_prepared_body_restriction(prepared, changed_point)
	box.size.x = 4.0
	_check(not bool(before_mutation.inside), "size_change_starts_outside")
	_check(bool(_solver.query_point_body_restriction(body, changed_point).inside), "size_change_becomes_inside")
	_check(_equal_values(before_mutation, _solver.query_point_prepared_body_restriction(prepared, changed_point)), "snapshot_keeps_copied_dimensions")
	_check_native_snapshot(prepared, changed_point, before_mutation, "native_snapshot_keeps_dimensions")
	_compare_batch(body, points, "shape_size_changed")
	_compare_weapon(body, weapon, Transform3D.IDENTITY, "weapon_after_size_change")
	prepared = _solver.prepare_body_point_query(body)
	var before_move: Dictionary = _solver.query_point_prepared_body_restriction(prepared, changed_point)
	first.position = Vector3(20.0, 0.0, 0.0)
	_check(not bool(_solver.query_point_body_restriction(body, changed_point).inside), "transform_change_becomes_outside")
	_check(_equal_values(before_move, _solver.query_point_prepared_body_restriction(prepared, changed_point)), "snapshot_keeps_copied_transform")
	_check_native_snapshot(prepared, changed_point, before_move, "native_snapshot_keeps_transform")
	_compare_batch(body, points, "shape_transform_changed")
	_compare_weapon(body, weapon, Transform3D.IDENTITY, "weapon_after_transform_change")

	body.transform = Transform3D(Basis.from_euler(Vector3(0.2, 0.7, -0.3)).scaled(Vector3(1.2, 0.8, 1.4)), Vector3(-2.0, 3.0, 1.0))
	first.transform = Transform3D(Basis.from_euler(Vector3(0.3, -0.4, 0.1)).scaled(Vector3(0.7, 1.3, 0.9)), Vector3(-1.0, 0.0, 0.0))
	capsule.radius = 0.8
	capsule.height = 3.4
	var transformed_points: Array[Vector3] = []
	for point: Vector3 in points:
		transformed_points.append(first.global_transform * point)
		transformed_points.append(cap_node.global_transform * point)
	_compare_batch(body, transformed_points, "rotated_scaled_and_capsule_changed")
	_compare_weapon(body, weapon, body.global_transform, "weapon_transformed")

	# Jolt rejects nonuniform sphere scale. The preceding batch already covers
	# scaled analytical queries; keep the unsupported-type fixture uniform.
	body.basis = Basis.from_euler(Vector3(0.2, 0.7, -0.3))
	var unsupported := SphereShape3D.new()
	var unknown := _add_shape(body, "Unknown", unsupported)
	body.move_child(unknown.get_parent().get_parent(), 0)
	_compare_batch(body, transformed_points, "unsupported_shape")
	_compare_weapon(body, weapon, body.global_transform, "weapon_unsupported_shape")
	unknown.shape = null
	_compare_batch(body, transformed_points, "shape_removed")
	first.shape = capsule
	_compare_batch(body, transformed_points, "shape_type_replaced")
	_compare_weapon(body, weapon, body.global_transform, "weapon_shape_type_replaced")

	body.free()
	weapon.free()
	_finish()

func _weapon_with_points(points: Array[Vector3]) -> Node3D:
	var weapon := Node3D.new()
	root.add_child(weapon)
	var samples: Array[Dictionary] = []
	for index: int in points.size():
		samples.append({"name": "WeaponBodySample_%02d" % index, "local_position": points[index]})
	weapon.set_meta(CollisionResolverScript.WEAPON_PROXY_LOCAL_SAMPLE_CACHE_META, samples)
	return weapon

func _add_shape(body: Node3D, label: String, shape: Shape3D) -> CollisionShape3D:
	var attachment := Node3D.new()
	attachment.name = label
	attachment.set_meta("proxy_region", "region_" + label)
	body.add_child(attachment)
	var area := Area3D.new()
	area.name = "RestrictionArea"
	attachment.add_child(area)
	var collision := CollisionShape3D.new()
	collision.name = "RestrictionShape"
	collision.shape = shape
	area.add_child(collision)
	return collision

func _compare_batch(body: Node3D, points: Array[Vector3], label: String) -> void:
	var prepared: Array[Dictionary] = _solver.prepare_body_point_query(body)
	var native_results: Array = _kernel.call("query_points", prepared, PackedVector3Array(points), CLEARANCE_OFFSET)
	_native_point_batches += 1
	_check(native_results.size() == points.size(), label + "_native_count")
	if native_results.size() != points.size(): return
	for index in range(points.size()):
		var expected: Dictionary = _solver.query_point_body_restriction(body, points[index])
		var actual: Dictionary = _solver.query_point_prepared_body_restriction(prepared, points[index])
		var point_label := "%s_%d" % [label, index]
		_check(_equal_values(expected, actual, point_label + ".prepared"), point_label + "_prepared")
		_check(_equal_values(expected, native_results[index], point_label + ".native"), point_label + "_native")

func _check_native_snapshot(prepared: Array[Dictionary], point: Vector3, expected: Dictionary, label: String) -> void:
	var result: Array = _kernel.call("query_points", prepared, PackedVector3Array([point]), CLEARANCE_OFFSET)
	_native_point_batches += 1
	_check(result.size() == 1 and _equal_values(expected, result[0], label), label)

func _compare_weapon(body: Node3D, weapon: Node3D, pose: Transform3D, label: String) -> Dictionary:
	var increment := 1 if body != null and weapon != null else 0
	_resolver.configure_native_kernel(false)
	var previous: Dictionary = _resolver.get_backend_stats()
	var expected: Dictionary = _resolver.evaluate_weapon_pose(body, weapon, pose, _legacy)
	var reference: Dictionary = _resolver.evaluate_weapon_pose(body, weapon, pose, _solver)
	_check(_equal_values(expected, reference, label + ".reference"), label + "_reference")
	_check(_resolver.get_backend_stats().native_calls == previous.native_calls, label + "_forced_reference_route")
	_check(_resolver.get_backend_stats().reference_calls == previous.reference_calls + 2 * increment, label + "_forced_reference_count")
	_resolver.configure_native_kernel(true)
	previous = _resolver.get_backend_stats()
	var legacy_again: Dictionary = _resolver.evaluate_weapon_pose(body, weapon, pose, _legacy)
	_check(_equal_values(expected, legacy_again, label + ".legacy"), label + "_legacy_unchanged")
	_check(_resolver.get_backend_stats().native_calls == previous.native_calls, label + "_legacy_never_native")
	var actual: Dictionary = _resolver.evaluate_weapon_pose(body, weapon, pose, _solver)
	_check(_equal_values(reference, actual, label + ".adapter"), label + "_native_adapter")
	_check(_resolver.get_backend_stats().native_calls == previous.native_calls + increment, label + "_native_route")
	_check(_resolver.get_backend_stats().reference_calls == previous.reference_calls + increment, label + "_native_does_not_repeat_reference")
	var prepared: Array[Dictionary] = _solver.prepare_body_point_query(body)
	var samples: Array[Dictionary] = _resolver._collect_weapon_proxy_local_samples(weapon)
	var direct: Dictionary = _kernel.call("evaluate_weapon_pose", prepared, samples, pose, CLEARANCE_OFFSET)
	_native_pose_batches += 1
	_check(_equal_values(reference, direct, label + ".direct"), label + "_native_direct")
	return actual

func _compare_custom_solver(body: Node3D, weapon: Node3D) -> void:
	var custom := CustomPreparedQuery.new()
	_resolver.configure_native_kernel(false)
	var expected: Dictionary = _resolver.evaluate_weapon_pose(body, weapon, Transform3D.IDENTITY, custom)
	_resolver.configure_native_kernel(true)
	var before: Dictionary = _resolver.get_backend_stats()
	var actual: Dictionary = _resolver.evaluate_weapon_pose(body, weapon, Transform3D.IDENTITY, custom)
	var after: Dictionary = _resolver.get_backend_stats()
	_check(not actual.legal and actual.colliding_body_region == "custom_region" and actual.estimated_clearance_meters == -0.125, "custom_prepared_semantics")
	_check(_equal_values(expected, actual, "custom_prepared"), "custom_prepared_packet_unchanged")
	_check(after.native_calls == before.native_calls and after.reference_calls == before.reference_calls + 1, "custom_prepared_not_native")

func _equal_values(expected: Variant, actual: Variant, path: String = "snapshot") -> bool:
	if typeof(expected) != typeof(actual):
		return false
	if expected is Dictionary:
		if expected.size() != actual.size():
			return false
		var matches := true
		for key: Variant in expected:
			matches = (actual.has(key) and _equal_values(expected[key], actual[key], path + "." + str(key))) and matches
		return matches
	if expected is Vector3:
		var matches := true
		for axis: int in 3:
			matches = _equal_values(expected[axis], actual[axis], path + "." + str(axis)) and matches
		return matches
	if expected is float:
		if expected == actual: return true
		if not is_finite(expected) or not is_finite(actual): return false
		var delta := absf(expected - actual)
		_numeric_difference_count += 1
		_max_numeric_delta = maxf(_max_numeric_delta, delta)
		if _numeric_examples.size() < 8: _numeric_examples.append({"path": path, "expected": expected, "actual": actual, "delta": delta})
		return delta <= NUMERIC_TOLERANCE
	return expected == actual

func _finish() -> void:
	var stats: Dictionary = _resolver.get_backend_stats()
	if _kernel != null:
		_check(stats.native_calls > 0 and stats.reference_calls > 0 and stats.unavailable_fallback_calls == 0, "both_routes_exercised_without_fallback")
	print(JSON.stringify({"verifier": "prepared_body_point_queries", "checks": _checks, "passed": _failures.is_empty(), "failures": _failures,
		"numeric_exact": _numeric_difference_count == 0, "numeric_tolerance": NUMERIC_TOLERANCE,
		"numeric_difference_count": _numeric_difference_count, "max_numeric_delta": _max_numeric_delta, "numeric_examples": _numeric_examples,
		"direct_native_point_batches": _native_point_batches, "direct_native_pose_batches": _native_pose_batches, "backend_stats": stats}, "\t"))
	quit(0 if _failures.is_empty() else 1)

func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition and _failures.size() < 40:
		_failures.append(label)
