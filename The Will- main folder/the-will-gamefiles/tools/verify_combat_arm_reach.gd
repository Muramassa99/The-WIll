extends SceneTree

## Pure necessary-bound proof checks; no claim of complete IK reachability.
const Reach = preload("res://core/resolvers/combat_arm_reach_resolver.gd")
var checks: Array[Dictionary] = []
var output_dir := "C:/WORKSPACE/godot_runs/combat_arm_reach"

func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--out-dir="): output_dir = argument.trim_prefix("--out-dir=")
	call_deferred("_run")

func _run() -> void:
	# Declared numerical fixtures in a shared reference, not anatomical values.
	var rows := [
		[Vector3(0, 0.3, 0), Vector3(0, 0.25, 0), Vector3.RIGHT, deg_to_rad(12), deg_to_rad(160)],
		[Vector3(0.000046, 0.298, -0.00003), Vector3(-0.000052, 0.22, 0.04), Vector3(1, 0.0002, 0.0001), -0.4, 1.8],
		[Vector3(0.1, 0.3, 0.02), Vector3(0.08, -0.13, 0.22), Vector3.RIGHT, -1.3, 0.8],
		[Vector3(0.2, 0.15, -0.04), Vector3(-0.1, 0.11, 0.19), Vector3(0.5, 0.8, -0.2), -7.0, 7.0],
		[Vector3(0, 0.3, 0), Vector3(0, 0.25, 0), Vector3.RIGHT, -0.35, -0.35],
		[Vector3(0.1, 0, 0), Vector3(0.2, 0, 0), Vector3.RIGHT, -1.0, 2.0]]
	for index: int in rows.size():
		var row: Array = rows[index]
		_grid_check("fixture_" + str(index), row)
		var basis := Basis.from_euler(Vector3(0.23, -0.61, 0.17))
		var transformed: Array = [basis * row[0] * 1.7, basis * row[1] * 1.7, basis * row[2], row[3], row[4]]
		_grid_check("transformed_" + str(index), transformed)
		var a := Reach.maximum_radius(row[0], row[1], row[2], row[3], row[4])
		var b := Reach.maximum_radius(transformed[0], transformed[1], transformed[2], row[3], row[4])
		_check(a.valid and b.valid and absf(float(b.radius) - float(a.radius) * 1.7) < 0.000001, "rotation_scale_invariant_" + str(index))
	var straight := Reach.maximum_radius(Vector3(0, 0.3, 0), Vector3(0, 0.25, 0), Vector3.RIGHT, 0.0, 1.0)
	_check(straight.valid and absf(float(straight.radius) - 0.55) < 0.000001, "includes_straight_recovery_allowance")
	_check(not Reach.maximum_radius(Vector3.ONE, Vector3.ONE, Vector3.ZERO, 0, 1).valid, "missing_axis_no_bound")
	_check(not Reach.maximum_radius(Vector3.ONE, Vector3.ONE, Vector3.RIGHT, 2, 1).valid, "reversed_interval_no_bound")
	_check(not Reach.maximum_radius(Vector3.INF, Vector3.ONE, Vector3.RIGHT, 0, 1).valid, "nonfinite_geometry_no_bound")
	_segment("inside", Vector3.ZERO, Vector3(0.5, 0, 0), 1.0, 1.0)
	_segment("exit", Vector3.ZERO, Vector3(2, 0, 0), 1.0, 0.5)
	_segment("boundary_outward", Vector3.RIGHT, Vector3(2, 0, 0), 1.0, 0.0)
	_segment("boundary_reverse", Vector3.RIGHT, Vector3.ZERO, 1.0, 1.0)
	_segment("boundary_cross", Vector3.RIGHT, Vector3(-3, 0, 0), 1.0, 0.5)
	_segment("boundary_tangent", Vector3.RIGHT, Vector3(1, 1, 0), 1.0, 0.0)
	_segment("no_motion", Vector3.RIGHT, Vector3.RIGHT, 1.0, 1.0)
	_segment("zero_radius", Vector3.ZERO, Vector3.RIGHT, 0.0, 0.0)
	var outside := Reach.translation_fraction(Vector3.ZERO, Vector3(3, 0, 0), Vector3.ZERO, 1.0)
	_check(not outside.valid and outside.maximum_fraction == 1.0, "outside_start_falls_back_without_lockout")
	_finish()

func _grid_check(label: String, row: Array) -> void:
	var result := Reach.maximum_radius(row[0], row[1], row[2], row[3], row[4])
	_check(result.valid, label + "_valid")
	if not result.valid: return
	var observed := 0.0
	var greatest_excess := -INF
	for index: int in 721:
		var angle := lerpf(row[3], row[4], float(index) / 720.0)
		# Independent Rodrigues/Basis FK rather than reusing the scalar formula.
		var distance: float = (row[0] + Basis((row[2] as Vector3).normalized(), angle) * row[1]).length()
		observed = maxf(observed, distance)
		greatest_excess = maxf(greatest_excess, distance - float(result.radius))
	_check(greatest_excess < 0.000001, label + "_all_sampled_fk_inside", greatest_excess)
	var peak_distance: float = (row[0] + Basis((row[2] as Vector3).normalized(), result.extremum_delta) * row[1]).length()
	_check(absf(peak_distance - float(result.radius)) < 0.000001, label + "_extremum_is_real_fk")
	_check(float(result.extremum_delta) >= float(row[3]) - 1.0e-10 and float(result.extremum_delta) <= float(row[4]) + 1.0e-10, label + "_extremum_in_interval")
	_check(observed <= float(result.radius) + 0.000001, label + "_conservative_grid_bound")

func _segment(label: String, start: Vector3, target: Vector3, radius: float, expected: float) -> void:
	var result := Reach.translation_fraction(Vector3.ZERO, start, target, radius)
	_check(result.valid and absf(float(result.maximum_fraction) - expected) < 1.0e-9, label, result)
	var common := Transform3D(Basis.from_euler(Vector3(0.23, -0.61, 0.17)).scaled(Vector3.ONE * 1.7), Vector3(5, -2, 7))
	# Small explicit sphere inflation covers float32 transformed-coordinate noise.
	var moved := Reach.translation_fraction(common.origin, common * start, common * target, radius * 1.7 + 0.000002)
	_check(moved.valid and absf(float(moved.maximum_fraction) - expected) < 0.003, label + "_world_transform", moved)

func _check(passed: bool, label: String, detail: Variant = null) -> void:
	checks.append({"passed": passed, "check": label, "detail": detail})
	if not passed: push_error("ARM_REACH " + label + " " + str(detail))

func _finish() -> void:
	var passed := true
	for item: Dictionary in checks: passed = passed and bool(item.passed)
	DirAccess.make_dir_recursive_absolute(output_dir)
	var file := FileAccess.open(output_dir.path_join("report.json"), FileAccess.WRITE)
	if file == null:
		quit(1)
		return
	file.store_string(JSON.stringify({"passed": passed, "checks": checks, "scope": "Pure necessary reach bound; finite fixtures and dense FK comparison, not complete arm feasibility."}, "\t"))
	file.close()
	print("ARM_REACH passed=%s checks=%d output=%s" % [passed, checks.size(), output_dir])
	quit(0 if passed else 1)
