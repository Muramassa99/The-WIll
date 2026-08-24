extends SceneTree

const ForgeV2SplinePathSamplerScript = preload(
	"res://runtime/forge_v2/forge_v2_spline_path_sampler.gd"
)

const RESULT_PATH := (
	"C:/WORKSPACE/godot_runs/"
	+ "verify_forge_v2_spline_path_sampler_2026-08-10.txt"
)


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(RESULT_PATH.get_base_dir())
	var controls := PackedVector3Array([
		Vector3(0.0, 0.0, 0.0),
		Vector3(0.20, 0.18, 0.06),
		Vector3(0.45, -0.04, 0.12),
		Vector3(0.70, 0.10, 0.18),
	])
	var first: Dictionary = ForgeV2SplinePathSamplerScript.sample_auto_curve(
		controls,
		0.025,
		0.0002
	)
	var second: Dictionary = ForgeV2SplinePathSamplerScript.sample_auto_curve(
		controls,
		0.025,
		0.0002
	)
	_require(bool(first.get("valid", false)), "curved reference path was invalid")
	var sampled_points: PackedVector3Array = first.get(
		"points",
		PackedVector3Array()
	)
	var span_offsets: PackedInt32Array = first.get(
		"span_offsets",
		PackedInt32Array()
	)
	_require(
		sampled_points.size() > controls.size(),
		"curved path was not adaptively subdivided"
	)
	_require(
		span_offsets.size() == controls.size(),
		"span offset contract did not match the control count"
	)
	for control_index in range(controls.size()):
		_require(
			sampled_points[span_offsets[control_index]]
			== controls[control_index],
			"sampled path did not pass through control %d" % control_index
		)
	_require(
		sampled_points == second.get("points", PackedVector3Array())
		and span_offsets == second.get("span_offsets", PackedInt32Array()),
		"identical sampling input was not deterministic"
	)

	var straight_controls := PackedVector3Array([
		Vector3.ZERO,
		Vector3(0.1, 0.0, 0.0),
		Vector3(0.2, 0.0, 0.0),
	])
	var straight: Dictionary = ForgeV2SplinePathSamplerScript.sample_auto_curve(
		straight_controls,
		0.02,
		0.0001
	)
	_require(bool(straight.get("valid", false)), "straight path was invalid")
	for point: Vector3 in straight.get("points", PackedVector3Array()):
		_require(absf(point.y) <= 0.000001, "straight path bowed in Y")
		_require(absf(point.z) <= 0.000001, "straight path bowed in Z")

	var limited: Dictionary = ForgeV2SplinePathSamplerScript.sample_auto_curve(
		controls,
		0.0001,
		0.00001,
		1,
		3
	)
	_require(
		not bool(limited.get("valid", true)),
		"hard subdivision/sample limits silently accepted an unresolved path"
	)
	var limited_points: PackedVector3Array = limited.get(
		"points",
		PackedVector3Array()
	)
	_require(
		limited_points.size() <= 1 + (controls.size() - 1) * 3,
		"bounded sampler exceeded its per-span sample ceiling"
	)

	var duplicate_controls := PackedVector3Array([
		Vector3.ZERO,
		Vector3.ZERO,
		Vector3.RIGHT * 0.1,
	])
	var duplicate_result: Dictionary = (
		ForgeV2SplinePathSamplerScript.sample_auto_curve(
			duplicate_controls,
			0.02,
			0.0001
		)
	)
	_require(
		not bool(duplicate_result.get("valid", true))
		and StringName((duplicate_result.get(
			"span_reasons",
			[]
		) as Array)[0]) == ForgeV2SplinePathSamplerScript.REASON_ZERO_LENGTH_SPAN,
		"zero-length authored span was not explicitly invalid"
	)

	_write_result([
		"ok=true",
		"exact_control_pass_through=true",
		"adaptive_curve_sampling=true",
		"deterministic_output=true",
		"straight_line_stability=true",
		"bounded_failure=true",
		"zero_length_span_rejected=true",
	])
	quit(0)


func _require(condition: bool, message: String) -> void:
	if condition:
		return
	_write_result(["ok=false", "error=%s" % message])
	push_error(message)
	quit(1)


func _write_result(lines: Array[String]) -> void:
	var file := FileAccess.open(RESULT_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines) + "\n")
