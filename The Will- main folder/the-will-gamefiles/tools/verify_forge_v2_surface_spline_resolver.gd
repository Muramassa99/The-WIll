extends SceneTree

const ForgeV2SurfaceSplineResolverScript = preload(
	"res://runtime/forge_v2/forge_v2_surface_spline_resolver.gd"
)

const RESULT_PATH := (
	"C:/WORKSPACE/godot_runs/"
	+ "verify_forge_v2_surface_spline_resolver_2026-08-10.txt"
)
const TARGET_KIND := &"target_material_surface"
const TARGET_ID := &"surface_body_a"
const EPSILON := 0.000001


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(RESULT_PATH.get_base_dir())
	var controls := PackedVector3Array([
		_surface_point(Vector2(0.00, 0.00)),
		_surface_point(Vector2(0.18, 0.14)),
		_surface_point(Vector2(0.38, -0.08)),
		_surface_point(Vector2(0.58, 0.10)),
	])
	var control_normals := PackedVector3Array([
		Vector3(0.0, 0.0, 2.0),
		Vector3(0.2, 0.1, 1.0),
		Vector3(-0.1, 0.2, 1.0),
		Vector3(0.0, -0.2, 1.0),
	])
	var local_to_screen := Callable(self, "_local_to_screen")
	var valid_target := Callable(self, "_strict_target").bind(&"valid")

	var first := ForgeV2SurfaceSplineResolverScript.solve(
		controls,
		control_normals,
		TARGET_KIND,
		TARGET_ID,
		local_to_screen,
		valid_target,
		0.025,
		0.0002,
		10,
		129
	)
	var second := ForgeV2SurfaceSplineResolverScript.solve(
		controls,
		control_normals,
		TARGET_KIND,
		TARGET_ID,
		local_to_screen,
		valid_target,
		0.025,
		0.0002,
		10,
		129
	)
	_require(bool(first.get("valid", false)), "valid curved solve failed")
	var resolved_points: PackedVector3Array = first.get(
		"points",
		PackedVector3Array()
	)
	var resolved_normals: PackedVector3Array = first.get(
		"surface_normals",
		PackedVector3Array()
	)
	var span_offsets: PackedInt32Array = first.get(
		"span_offsets",
		PackedInt32Array()
	)
	_require(
		resolved_points.size() > controls.size(),
		"curved surface path was not densely sampled"
	)
	_require(
		resolved_normals.size() == resolved_points.size(),
		"resolved positions and normals were not paired"
	)
	_require(
		span_offsets.size() == controls.size(),
		"resolved span offsets did not match controls"
	)
	for control_index in range(controls.size()):
		var resolved_index := int(span_offsets[control_index])
		_require(
			resolved_points[resolved_index] == controls[control_index],
			"control %d position was not exact" % control_index
		)
		_require(
			resolved_normals[resolved_index] == control_normals[control_index],
			"control %d normal was not exact" % control_index
		)
	for resolved_index in range(resolved_points.size()):
		if span_offsets.has(resolved_index):
			continue
		var point := resolved_points[resolved_index]
		_require(
			absf(point.z - _surface_height(Vector2(point.x, point.y)))
			<= EPSILON,
			"intermediate point left the projected surface"
		)
		_require(
			absf(resolved_normals[resolved_index].length() - 1.0)
			<= EPSILON,
			"intermediate surface normal was not normalized"
		)
	_require(
		_results_match(first, second),
		"identical surface solves were not deterministic"
	)

	var mismatch := ForgeV2SurfaceSplineResolverScript.solve(
		controls,
		control_normals,
		TARGET_KIND,
		TARGET_ID,
		local_to_screen,
		Callable(self, "_strict_target").bind(&"mismatch")
	)
	_require(
		not bool(mismatch.get("valid", true))
		and _result_has_reason(
			mismatch,
			ForgeV2SurfaceSplineResolverScript.REASON_TARGET_MISMATCH
		),
		"target identity switch was not rejected"
	)

	var miss := ForgeV2SurfaceSplineResolverScript.solve(
		controls,
		control_normals,
		TARGET_KIND,
		TARGET_ID,
		local_to_screen,
		Callable(self, "_strict_target").bind(&"miss")
	)
	_require(
		not bool(miss.get("valid", true))
		and _result_has_reason(
			miss,
			ForgeV2SurfaceSplineResolverScript.REASON_TARGET_MISS
		),
		"surface miss was not rejected"
	)

	# Even a span shorter than max spacing receives an interior probe. The
	# simulated void therefore cannot be jumped endpoint-to-endpoint.
	var short_controls := PackedVector3Array([
		_surface_point(Vector2(0.0, 0.0)),
		_surface_point(Vector2(0.01, 0.0)),
	])
	var short_normals := PackedVector3Array([Vector3.UP, Vector3.UP])
	var void_jump := ForgeV2SurfaceSplineResolverScript.solve(
		short_controls,
		short_normals,
		TARGET_KIND,
		TARGET_ID,
		local_to_screen,
		Callable(self, "_strict_target").bind(&"short_void"),
		0.10
	)
	_require(
		not bool(void_jump.get("valid", true))
		and _result_has_reason(
			void_jump,
			ForgeV2SurfaceSplineResolverScript.REASON_TARGET_MISS
		),
		"short span silently jumped a void"
	)

	var invalid_projection := ForgeV2SurfaceSplineResolverScript.solve(
		controls,
		control_normals,
		TARGET_KIND,
		TARGET_ID,
		Callable(self, "_invalid_local_to_screen"),
		valid_target
	)
	_require(
		not bool(invalid_projection.get("valid", true))
		and _result_has_reason(
			invalid_projection,
			ForgeV2SurfaceSplineResolverScript.REASON_PROJECTION_INVALID
		),
		"invalid camera projection was not explicit"
	)

	var ambiguous_target := ForgeV2SurfaceSplineResolverScript.solve(
		controls,
		control_normals,
		TARGET_KIND,
		StringName(),
		local_to_screen,
		valid_target
	)
	_require(
		not bool(ambiguous_target.get("valid", true))
		and StringName(ambiguous_target.get("reason", StringName()))
		== ForgeV2SurfaceSplineResolverScript.REASON_INVALID_LOCKED_TARGET,
		"empty stable surface target identity was accepted"
	)

	var bounded := ForgeV2SurfaceSplineResolverScript.solve(
		controls,
		control_normals,
		TARGET_KIND,
		TARGET_ID,
		local_to_screen,
		valid_target,
		0.0001,
		0.00001,
		10,
		5
	)
	_require(
		not bool(bounded.get("valid", true)),
		"unresolved path silently escaped its sample bound"
	)
	_require(
		(bounded.get("points", PackedVector3Array()) as PackedVector3Array).size()
		<= 1 + (controls.size() - 1) * 4,
		"bounded solve exceeded its declared per-span output cap"
	)

	var zero_span_controls := PackedVector3Array([
		controls[0],
		controls[0],
		controls[1],
	])
	var zero_span_normals := PackedVector3Array([
		control_normals[0],
		control_normals[0],
		control_normals[1],
	])
	var zero_span := ForgeV2SurfaceSplineResolverScript.solve(
		zero_span_controls,
		zero_span_normals,
		TARGET_KIND,
		TARGET_ID,
		local_to_screen,
		valid_target
	)
	_require(
		not bool(zero_span.get("valid", true))
		and _result_has_reason(
			zero_span,
			ForgeV2SurfaceSplineResolverScript.REASON_ZERO_LENGTH_SPAN
		),
		"zero-length authored span was not explicitly invalid"
	)

	_write_result([
		"ok=true",
		"exact_control_pass_through=true",
		"curved_dense_surface_projection=true",
		"paired_surface_normals=true",
		"target_mismatch_rejected=true",
		"surface_miss_rejected=true",
		"void_jump_rejected=true",
		"invalid_projection_explicit=true",
		"ambiguous_target_rejected=true",
		"deterministic=true",
		"bounded_output=true",
		"zero_length_span_rejected=true",
	])
	quit(0)


func _local_to_screen(local_position: Vector3) -> Vector2:
	return Vector2(local_position.x, local_position.y)


func _invalid_local_to_screen(_local_position: Vector3) -> Dictionary:
	return {"valid": false}


func _strict_target(
	screen_position: Vector2,
	_locked_target_kind: StringName,
	_locked_target_id: StringName,
	mode: StringName
) -> Dictionary:
	if mode == &"miss" and screen_position.x > 0.20:
		return {"valid": false, "reject_reason": &"surface_miss"}
	if mode == &"short_void" and (
		screen_position.x > 0.004
		and screen_position.x < 0.006
	):
		return {"valid": false, "reject_reason": &"void_gap"}
	var target_id := TARGET_ID
	if mode == &"mismatch" and screen_position.x > 0.20:
		target_id = &"surface_body_b"
	return {
		"valid": true,
		"target_kind": TARGET_KIND,
		"surface_target_id": target_id,
		"local_position": _surface_point(screen_position),
		"local_normal": _surface_normal(screen_position),
	}


func _surface_point(screen_position: Vector2) -> Vector3:
	return Vector3(
		screen_position.x,
		screen_position.y,
		_surface_height(screen_position)
	)


func _surface_height(screen_position: Vector2) -> float:
	return (
		0.035 * sin(screen_position.x * 9.0)
		+ 0.022 * cos(screen_position.y * 7.0)
	)


func _surface_normal(screen_position: Vector2) -> Vector3:
	var derivative_x := 0.315 * cos(screen_position.x * 9.0)
	var derivative_y := -0.154 * sin(screen_position.y * 7.0)
	return Vector3(-derivative_x, -derivative_y, 1.0).normalized()


func _results_match(first: Dictionary, second: Dictionary) -> bool:
	return (
		bool(first.get("valid", false)) == bool(second.get("valid", false))
		and StringName(first.get("reason", StringName()))
		== StringName(second.get("reason", StringName()))
		and (first.get("points", PackedVector3Array()) as PackedVector3Array)
		== (second.get("points", PackedVector3Array()) as PackedVector3Array)
		and (
			first.get("surface_normals", PackedVector3Array())
			as PackedVector3Array
		) == (
			second.get("surface_normals", PackedVector3Array())
			as PackedVector3Array
		)
		and (
			first.get("span_offsets", PackedInt32Array())
			as PackedInt32Array
		) == (
			second.get("span_offsets", PackedInt32Array())
			as PackedInt32Array
		)
		and (first.get("span_validity", []) as Array)
		== (second.get("span_validity", []) as Array)
		and (first.get("span_reasons", []) as Array)
		== (second.get("span_reasons", []) as Array)
	)


func _result_has_reason(result: Dictionary, reason: StringName) -> bool:
	if StringName(result.get("reason", StringName())) == reason:
		return true
	for span_reason: Variant in result.get("span_reasons", []) as Array:
		if StringName(span_reason) == reason:
			return true
	return false


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
