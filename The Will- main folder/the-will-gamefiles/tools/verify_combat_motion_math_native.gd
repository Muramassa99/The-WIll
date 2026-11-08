extends SceneTree

## Pure native/reference numerical parity, including the imported skeleton's
## local transforms. Does not acquire grip, move the game rig or alter saves.
const Backend = preload("res://core/resolvers/combat_motion_math_backend.gd")
const Model = preload("res://Josie/josie.tscn")
var output_dir := "C:/WORKSPACE/godot_runs/combat_motion_math_native"
var checks: Array[Dictionary] = []
var comparisons: Array[Dictionary] = []
var timings: Dictionary = {}
var kernel: RefCounted
var benchmark_qp: Dictionary = {}
var benchmark_poses: Array[Transform3D] = []
var benchmark_parents := PackedInt32Array()

func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--out-dir="):
			output_dir = argument.trim_prefix("--out-dir=")
	call_deferred("_run")

func _run() -> void:
	_check(ClassDB.class_exists(&"CombatMotionMathKernel"), "native_kernel_registered")
	if ClassDB.class_exists(&"CombatMotionMathKernel"):
		kernel = ClassDB.instantiate(&"CombatMotionMathKernel") as RefCounted
		_test_qp()
		_test_forward()
		_test_backend_dispatch()
		_benchmark()
	var passed := true
	for check: Dictionary in checks:
		passed = passed and bool(check.passed)
	DirAccess.make_dir_recursive_absolute(output_dir)
	var file := FileAccess.open(output_dir.path_join("report.json"), FileAccess.WRITE)
	if file == null:
		push_error("Cannot write native motion math report")
		quit(1)
		return
	file.store_string(JSON.stringify({"passed": passed, "checks": checks, "comparisons": comparisons,
		"timings": timings, "scope": "Pure QP and full FK numerical parity; no anatomy, grip, collision, game motion or playback certification."}, "\t"))
	file.close()
	print("COMBAT_MOTION_MATH_NATIVE passed=%s checks=%d output=%s" % [passed, checks.size(), output_dir])
	quit(0 if passed else 1)

func _check(passed: bool, name: String, details: Dictionary = {}) -> void:
	checks.append({"passed": passed, "name": name, "details": details})

func _case(h: Array, g: Array, equalities: Array = [], inequalities: Array = [],
		limits: Array = [], initial: Array = []) -> Dictionary:
	var result := {"h": [], "g": PackedFloat64Array(g), "eq": [], "ineq": [],
		"limits": PackedFloat64Array(limits), "initial": PackedFloat64Array(initial)}
	for row: Array in h:
		result.h.append(PackedFloat64Array(row))
	for row: Array in equalities:
		result.eq.append(PackedFloat64Array(row))
	for row: Array in inequalities:
		result.ineq.append(PackedFloat64Array(row))
	if initial.is_empty():
		result.initial.resize(g.size())
	return result

func _compare_qp(name: String, input: Dictionary) -> Dictionary:
	var untouched := var_to_bytes(input)
	var reference: Dictionary = Backend.qp_reference(input.h, input.g, input.eq, input.ineq, input.limits, input.initial)
	var native: Dictionary = kernel.call("solve_qp", input.h, input.g, input.eq, input.ineq, input.limits, input.initial)
	var identical := var_to_bytes(reference) == var_to_bytes(native)
	var equivalent := _same_result(reference, native)
	_check(equivalent, name + "_native_reference", {} if equivalent else {"reference": reference, "native": native})
	_check(var_to_bytes(input) == untouched, name + "_inputs_unchanged")
	comparisons.append({"name": name, "valid": native.get("valid", false), "reason": native.get("reason", ""),
		"byte_identical": identical, "x_error": _maximum_scalar_error(reference.get("x", []), native.get("x", []))})
	return native

func _test_qp() -> void:
	var result := _compare_qp("positive_definite", _case([[2.0, 0.0], [0.0, 4.0]], [-4.0, 8.0]))
	_check(result.valid and absf(result.x[0] - 2.0) < 1.0e-12 and absf(result.x[1] + 2.0) < 1.0e-12, "positive_definite_analytic_solution")
	result = _compare_qp("rank_deficient_free_variable", _case([[1.0, 1.0], [1.0, 1.0]], [-2.0, -2.0]))
	_check(result.valid and result.x == PackedFloat64Array([2.0, 0.0]), "rank_deficient_retains_source_pivot_free_zero")
	result = _compare_qp("inconsistent_singular", _case([[0.0]], [1.0]))
	_check(not result.valid and result.reason == "inconsistent_linear_system", "inconsistent_singular_keeps_failure")
	result = _compare_qp("infeasible_initial", _case([[1.0]], [-2.0], [], [[1.0]], [0.0], [1.0]))
	_check(not result.valid and result.reason == "infeasible_start" and result.active == [0], "infeasible_start_keeps_first_row")
	result = _compare_qp("active_upper_bound", _case([[1.0]], [-2.0], [], [[1.0], [-1.0]], [0.5, 0.5]))
	_check(result.valid and absf(result.x[0] - 0.5) < 1.0e-12, "active_upper_bound_solution")
	result = _compare_qp("equality_keeps_initial_value", _case([[1.0, 0.0], [0.0, 1.0]], [-4.0, -4.0], [[1.0, 1.0]], [], [], [0.2, 0.3]))
	_check(result.valid and absf(result.x[0] + result.x[1] - 0.5) < 1.0e-12, "equality_is_directional_not_rezeroed")
	_compare_qp("redundant_equalities", _case([[1.0, 0.0], [0.0, 1.0]], [-1.0, 1.0], [[1.0, 1.0], [2.0, 2.0]]))
	_compare_qp("contact_row_normalization", _case([[1.0, 0.0], [0.0, 1.0]], [-2.0, -1.0], [[1000000.0, 1000000.0]], [[1.0, 0.0], [-1.0, 0.0]], [0.4, 0.4]))
	_compare_qp("duplicate_blocker_tie", _case([[1.0, 0.0], [0.0, 1.0]], [-2.0, -2.0], [], [[1.0, 0.0], [1.0, 0.0], [0.0, 1.0]], [0.25, 0.25, 0.25]))
	_compare_qp("fixed_coordinate", _case([[1.0, 0.0], [0.0, 1.0]], [-2.0, -2.0], [], [[1.0, 0.0], [-1.0, 0.0], [0.0, 1.0]], [0.0, 0.0, 0.5]))
	_compare_qp("all_zero_psd", _case([[0.0, 0.0], [0.0, 0.0]], [0.0, 0.0]))
	_compare_qp("empty_system", _case([], []))
	_compare_qp("pivot_below_threshold", _case([[0.9e-10]], [-0.5e-7]))
	_compare_qp("pivot_above_threshold", _case([[1.1e-10]], [-2.2e-10]))
	var malformed := _case([[1.0]], [0.0])
	malformed.h[0] = PackedFloat64Array([1.0, 2.0])
	result = _compare_qp("bad_dimensions", malformed)
	_check(not result.valid and result.reason == "invalid_dimensions", "invalid_dimensions_rejected")
	var random := RandomNumberGenerator.new()
	random.seed = 172913
	for n: int in [3, 9, 18]:
		for variant: int in 8:
			var h: Array = []
			for i: int in n:
				h.append(Backend._zeros(n))
			var rank: int = n if variant % 2 == 0 else maxi(1, n >> 1)
			for _row: int in rank:
				var r := PackedFloat64Array()
				for i: int in n:
					r.append(random.randf_range(-1.0, 1.0))
				for i: int in n:
					for j: int in n:
						h[i][j] += r[i] * r[j]
			var g := PackedFloat64Array()
			var inequalities: Array = []
			var limits := PackedFloat64Array()
			for i: int in n:
				g.append(random.randf_range(-1.0, 1.0))
				var row := Backend._zeros(n)
				row[i] = 1.0
				inequalities.append(row)
				limits.append(random.randf_range(0.01, 0.4))
				row = Backend._zeros(n)
				row[i] = -1.0
				inequalities.append(row)
				limits.append(random.randf_range(0.01, 0.4))
			var input := {"h": h, "g": g, "eq": [], "ineq": inequalities, "limits": limits, "initial": Backend._zeros(n)}
			if variant >= 4:
				var row := Backend._zeros(n)
				row[0] = 1.0
				row[1] = 1.0
				input.eq.append(row)
			_compare_qp("deterministic_%d_%d" % [n, variant], input)
			if n == 9 and variant == 0:
				benchmark_qp = input

func _compare_forward(name: String, poses: Array[Transform3D], parents: PackedInt32Array) -> Array[Transform3D]:
	var untouched := var_to_bytes([poses, parents])
	var reference: Array[Transform3D] = Backend.forward_reference(poses, parents)
	var native: Array[Transform3D] = kernel.call("forward_pose", poses, parents)
	var exact := var_to_bytes(reference) == var_to_bytes(native)
	_check(exact, name + "_exact_forward_parity", {"count": native.size(), "reference_count": reference.size()})
	_check(untouched == var_to_bytes([poses, parents]), name + "_inputs_unchanged")
	return native

func _test_forward() -> void:
	var poses: Array[Transform3D] = [Transform3D(Basis(Vector3.UP, 0.5), Vector3(1.0, 2.0, 3.0)),
		Transform3D(Basis(Vector3.RIGHT, -0.7).scaled(Vector3(0.8, 1.2, 1.1)), Vector3(0.3, -0.5, 0.7)),
		Transform3D(Basis(Vector3.BACK, 1.2), Vector3(-0.2, 0.4, 0.1))]
	var values := _compare_forward("non_topological", poses, PackedInt32Array([2, -1, 1]))
	_check(values.size() == 3 and values[0] == poses[1] * poses[2] * poses[0], "non_topological_named_chain_order")
	_compare_forward("multiple_roots", poses, PackedInt32Array([-1, -1, 0]))
	_check(_compare_forward("cyclic_topology", poses, PackedInt32Array([2, 0, 1])).is_empty(), "cyclic_topology_rejected")
	_check(_compare_forward("parent_out_of_range", poses, PackedInt32Array([-1, 7, 0])).is_empty(), "invalid_parent_rejected")
	_check(_compare_forward("parent_count_mismatch", poses, PackedInt32Array([-1])).is_empty(), "mismatched_topology_rejected")
	_compare_forward("empty_topology", [], PackedInt32Array())
	var model: Node = Model.instantiate()
	var skeletons: Array[Node] = model.find_children("*", "Skeleton3D", true, false)
	_check(not skeletons.is_empty(), "imported_rig_skeleton_available")
	if not skeletons.is_empty():
		var skeleton := skeletons[0] as Skeleton3D
		var local: Array[Transform3D] = []
		var parents := PackedInt32Array()
		for index: int in skeleton.get_bone_count():
			local.append(skeleton.get_bone_rest(index))
			parents.append(skeleton.get_bone_parent(index))
		_compare_forward("josie_imported_rest", local, parents)
		for index: int in local.size():
			# Explicit animated-offset perturbation, not a substituted rest axis.
			local[index].basis = Basis(Vector3(0.3, 0.7, 0.2).normalized(), 0.002 * index) * local[index].basis
			local[index].origin += Vector3(0.00001 * index, -0.000003 * index, 0.000002 * index)
			if parents[index] < 0:
				local[index] = Transform3D(Basis(Vector3.UP, 0.3).scaled(Vector3(0.75, 1.25, 1.1)), Vector3(11.0, -4.0, 7.0)) * local[index]
		_compare_forward("josie_animated_offsets_scaled_root", local, parents)
		var reversed: Array[Transform3D] = []
		var reverse_parents := PackedInt32Array()
		for index: int in range(local.size() - 1, -1, -1):
			reversed.append(local[index])
			reverse_parents.append(local.size() - 1 - parents[index] if parents[index] >= 0 else -1)
		_compare_forward("josie_reversed_bone_indices", reversed, reverse_parents)
		benchmark_poses = local
		benchmark_parents = parents
	model.free()

func _test_backend_dispatch() -> void:
	Backend.configure_native(false)
	Backend.reset_backend_stats()
	var input := _case([[1.0]], [-0.5])
	var reference: Dictionary = Backend.qp(input.h, input.g, input.eq, input.ineq, input.limits, input.initial)
	Backend.forward(benchmark_poses, benchmark_parents)
	var stats: Dictionary = Backend.get_backend_stats()
	_check(stats.reference_qp_calls == 1 and stats.reference_forward_calls == 1 and stats.unavailable_fallback_calls == 0, "explicit_reference_dispatch_only")
	Backend.configure_native(true)
	Backend.reset_backend_stats()
	var native: Dictionary = Backend.qp(input.h, input.g, input.eq, input.ineq, input.limits, input.initial)
	Backend.forward(benchmark_poses, benchmark_parents)
	stats = Backend.get_backend_stats()
	_check(stats.native_qp_calls == 1 and stats.native_forward_calls == 1 and stats.reference_qp_calls == 0 and stats.reference_forward_calls == 0, "native_dispatch_without_double_evaluation")
	_check(_same_result(reference, native), "selected_backend_same_result")

func _benchmark() -> void:
	if benchmark_qp.is_empty() or benchmark_poses.is_empty():
		return
	for native: bool in [false, true]:
		Backend.configure_native(native)
		Backend.reset_backend_stats()
		var q: Dictionary = benchmark_qp
		var start := Time.get_ticks_usec()
		for _i: int in 40:
			Backend.qp(q.h, q.g, q.eq, q.ineq, q.limits, q.initial)
		var qp_us := Time.get_ticks_usec() - start
		start = Time.get_ticks_usec()
		for _i: int in 500:
			Backend.forward(benchmark_poses, benchmark_parents)
		timings["native" if native else "reference"] = {"qp_us_40_calls": qp_us,
			"forward_us_500_calls": Time.get_ticks_usec() - start, "bones": benchmark_poses.size(), "backend": Backend.get_backend_stats()}

func _maximum_scalar_error(a: Variant, b: Variant) -> float:
	if a.size() != b.size():
		return INF
	var largest := 0.0
	for index: int in a.size():
		largest = maxf(largest, absf(float(a[index]) - float(b[index])))
	return largest

func _same_result(a: Variant, b: Variant) -> bool:
	if typeof(a) != typeof(b):
		return false
	if a is float:
		return absf(a - b) <= 1.0e-11 * maxf(1.0, maxf(absf(a), absf(b)))
	if a is Dictionary:
		if a.size() != b.size():
			return false
		for key: Variant in a:
			if not b.has(key) or not _same_result(a[key], b[key]):
				return false
		return true
	if a is Array or a is PackedFloat64Array or a is PackedInt32Array:
		if a.size() != b.size():
			return false
		for index: int in a.size():
			if not _same_result(a[index], b[index]):
				return false
		return true
	return a == b
