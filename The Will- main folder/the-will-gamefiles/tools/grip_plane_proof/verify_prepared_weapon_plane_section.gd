extends "res://tools/grip_plane_proof/run_circle_hand_process_proof.gd"

## Bounded correctness/timing comparison; no pose search or runtime writes.
const FastSection = preload("res://tools/grip_plane_proof/prepared_weapon_plane_section.gd")
const FROZEN_TRACES: Dictionary = {
	"C:/WORKSPACE/test_artifacts/grip_placement_trace_hand_right_2026-09-18T02-30-57.bin": "dab0fbd68489e84ec1196c5a0acfb383a76a8eed099779e00a0f424c65529f89",
	"C:/WORKSPACE/test_artifacts/grip_placement_trace_hand_left_2026-09-18T02-31-08.bin": "c9765e43b465f5a529a07337bc2c9865d440612788960f162e7f40e5172311aa",
}
const COMPARISON_TOLERANCE_M: float = 0.000002
var _section_helper := FastSection.new()
var _section_checks: int = 0
var _section_failures: Array[String] = []
var _section_cases: Array = []
var _section_started: int = 0


func _run() -> void:
	_section_started = Time.get_ticks_usec()
	_test_fixtures()
	var loaded: Dictionary = Store.new().load_matching(OldInputs.DEFINITION_PATH, OldInputs.SIGNATURE, "rest_middle_thumb_surface_measurements_v1")
	if not _section_check(loaded.get("valid", false), "prepared anatomy loads"):
		_finish_sections(); return
	var anatomy_before := var_to_bytes(loaded.resource.reference_skin)
	for path: String in FROZEN_TRACES: _test_frozen_source(loaded.resource, path)
	_section_check(var_to_bytes(loaded.resource.reference_skin) == anatomy_before, "prepared anatomy unchanged")
	_section_check(_section_cases.size() == 10, "five bounded comparisons for each frozen hand")
	_finish_sections()


func _test_frozen_source(definition: Resource, path: String) -> void:
	if not _section_check(_workspace_trace_path(path) and FileAccess.get_sha256(path) == FROZEN_TRACES[path], "frozen source hash and workspace path"):
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if not _section_check(file != null, "frozen source readable"): return
	var raw: Variant = file.get_var(false); file.close()
	if not _section_check(raw is Dictionary and raw.get("schema") == "grip_placement_trace_v1" and raw.get("valid", false) and raw.get("validation", {}).get("valid", false) and raw.get("capture_errors", []).is_empty() and raw.get("anatomy_signature") == definition.source_signature, "frozen source validation"):
		return
	var trace: Dictionary = raw
	var chosen: Dictionary = {}
	for transaction: Dictionary in trace.transactions:
		if transaction.slot == trace.slot and transaction.get("result", {}).get("applied", false) and not transaction.get("finger_inputs", []).is_empty(): chosen = transaction
	if not _section_check(not chosen.is_empty(), "captured accepted seat exists"): return
	var stage: Dictionary = chosen.finger_inputs[-1]
	if not _section_check(stage.get("valid", false) and stage.get("transaction_serial") == chosen.serial and stage.posed_character.get("transaction_serial") == chosen.serial and stage.posed_character.get("capture_stage") == stage.stage and stage.posed_character.get("engine_process_frame") == stage.get("engine_process_frame"), "coherent captured epoch"):
		return
	var stage_before := var_to_bytes(stage)
	var context: Dictionary = _prepare(definition, stage)
	if not _section_check(context.get("valid", false), "prepare real frozen context"): return
	var prepared: Dictionary = {}
	for digit: StringName in DIGITS:
		var input: Dictionary = context.adapter.digit_inputs[digit]
		prepared[digit] = _section_helper.prepare(context.surface, input.plane_to_world, input.plane_origin_id)
		if not _section_check(prepared[digit].get("valid", false), str(context.slot) + "/" + str(digit) + " section preparation"): return
	var surface_before := var_to_bytes(context.surface)
	var prepared_before := var_to_bytes(prepared)
	var offsets: Array = [[0.0, 0.0], [0.002, 0.0], [-0.002, 0.001], [0.001, -0.003], [float(context.outward_parameters.x) * 0.075, float(context.outward_parameters.y) * 0.075]]
	for offset: Array in offsets:
		var parameters: Array = context.open_parameters.duplicate()
		parameters[6] = offset[0]; parameters[7] = offset[1]
		var shift: Vector3 = context.translation_u_world * float(offset[0]) + context.translation_v_world * float(offset[1])
		var candidate: Dictionary = _rigid_candidate(context, parameters, shift)
		if not _section_check(candidate.get("valid", false), "rigid candidate exists"): continue
		_slice_cache.clear()
		var began := Time.get_ticks_usec()
		var reference: Dictionary = super._targets(context, candidate, offset)
		var old_ms: float = float(Time.get_ticks_usec() - began) / 1000.0
		began = Time.get_ticks_usec()
		var results: Dictionary = {}
		var all_valid := true
		for digit: StringName in DIGITS:
			results[digit] = _section_helper.slice(prepared[digit], candidate.digit_states[digit].plane_to_world)
			all_valid = all_valid and results[digit].get("valid", false)
		var fast_ms: float = float(Time.get_ticks_usec() - began) / 1000.0
		var label := str(context.slot) + "/" + str(offset)
		_section_check(all_valid == reference.get("valid", false), label + ": same acceptance as old targets")
		var case := {"slot": context.slot, "offset": offset, "old_valid": reference.get("valid", false),
			"fast_valid": all_valid, "old_ms": old_ms, "fast_ms": fast_ms, "digits": {}}
		for digit: StringName in DIGITS:
			var result: Dictionary = results[digit]
			case.digits[digit] = {"valid": result.get("valid", false), "reason": result.get("reason"), "counts": result.get("counts")}
			if not reference.get("valid", false) or not result.get("valid", false): continue
			var original: Dictionary = reference.digits[digit]
			var polygon_error: float = _polygon_boundary_error(original.polygon, result.polygon)
			var centroid_error: float = (original.center as Vector2).distance_to(result.center)
			var original_radius: float = 0.0
			for point: Vector2 in original.polygon: original_radius = maxf(original_radius, point.distance_to(original.center))
			_section_check(original.polygon.size() == result.polygon.size(), label + "/" + str(digit) + ": no contour simplification")
			_section_check(polygon_error <= COMPARISON_TOLERANCE_M, label + "/" + str(digit) + ": current contour agrees")
			_section_check(centroid_error <= COMPARISON_TOLERANCE_M, label + "/" + str(digit) + ": current centroid agrees")
			_section_check(absf(original_radius - float(result.required_enclosing_radius_m)) <= COMPARISON_TOLERANCE_M, label + "/" + str(digit) + ": enclosure agrees")
			_section_check(result.origin_id == original.origin_id and result.source_id == context.surface.surface_source_origin_id and result.resolved_world_origin_id == ROOT and result.plane == original.plane, label + "/" + str(digit) + ": named frame chain preserved")
			case.digits[digit].merge({"polygon_error_m": polygon_error, "centroid_error_m": centroid_error, "radius_error_m": absf(original_radius - float(result.required_enclosing_radius_m))})
		_section_cases.append(case)
	_section_check(var_to_bytes(prepared) == prepared_before, "queries leave prepared fixed source immutable")
	_section_check(var_to_bytes(context.surface) == surface_before and var_to_bytes(stage) == stage_before, "queries leave capture and source unchanged")


func _test_fixtures() -> void:
	var plane := Transform3D.IDENTITY
	var surface := _fixture_surface(_fixture_box(Vector3(-0.01, -0.015, -0.02), Vector3(0.01, 0.015, 0.02)))
	var prepared: Dictionary = _section_helper.prepare(surface, plane, &"FixtureDigitPlane")
	if not _section_check(prepared.get("valid", false), "fixture preparation"): return
	var zero: Dictionary = _section_helper.slice(prepared, plane)
	_section_check(zero.get("valid", false) and zero.center.length() < COMPARISON_TOLERANCE_M, "complete centered fixture")
	var shifted := Transform3D(Basis.IDENTITY, Vector3(0.006, -0.007, 0.003))
	var translated: Dictionary = _section_helper.slice(prepared, shifted)
	_section_check(translated.get("valid", false) and translated.center.distance_to(Vector2(-0.006, 0.007)) < COMPARISON_TOLERANCE_M, "translated current centroid is not frozen")
	var rotated := Transform3D(Basis(Vector3.UP, 0.01), Vector3.ZERO)
	_section_check(not _section_helper.slice(prepared, rotated).get("valid", false), "changed orientation rejected")
	_section_check(not _section_helper.slice(prepared, Transform3D(Basis.from_scale(Vector3(2, 1, 1)), Vector3.ZERO)).get("valid", false), "nonmetric current frame rejected")
	_section_check(not _section_helper.slice(prepared, Transform3D(Basis.IDENTITY, Vector3(0, 0, 0.02))).get("valid", false), "coplanar face rejected")
	_section_check(not _section_helper.slice(prepared, Transform3D(Basis.IDENTITY, Vector3(0, 0, 1))).get("valid", false), "no section rejected")
	_section_check(not _section_helper.prepare(surface, plane, &"").get("valid", false), "missing plane origin rejected")
	var missing: Dictionary = surface.duplicate(true); missing.erase("surface_source_origin_id")
	_section_check(not _section_helper.prepare(missing, plane, &"FixtureDigitPlane").get("valid", false), "missing surface origin rejected")
	missing = surface.duplicate(true); missing.erase("resolved_world_origin_id")
	_section_check(not _section_helper.prepare(missing, plane, &"FixtureDigitPlane").get("valid", false), "missing root origin rejected")
	var bad: Dictionary = surface.duplicate(true); bad.triangles_world[0] = Vector3(INF, 0, 0)
	_section_check(not _section_helper.prepare(bad, plane, &"FixtureDigitPlane").get("valid", false), "nonfinite source rejected")
	var opened: PackedVector3Array = surface.triangles_world.duplicate()
	for _index: int in 6: opened.remove_at(12)
	var open_prepared: Dictionary = _section_helper.prepare(_fixture_surface(opened), plane, &"FixtureDigitPlane")
	_section_check(not _section_helper.slice(open_prepared, plane).get("valid", false), "open contour rejected")
	var doubled: PackedVector3Array = surface.triangles_world.duplicate()
	doubled.append_array(Transform3D(Basis.IDENTITY, Vector3(0.1, 0, 0)) * (surface.triangles_world as PackedVector3Array))
	var multiple: Dictionary = _section_helper.prepare(_fixture_surface(doubled), plane, &"FixtureDigitPlane")
	_section_check(not _section_helper.slice(multiple, plane).get("valid", false), "multiple complete loops rejected")
	# Binary-exact disconnected bowtie has zero signed area. Slicer discards its
	# closed cycle; the remaining good box loop cannot certify the whole slice.
	var bowtie := PackedVector2Array([Vector2(0.0625, -0.0078125), Vector2(0.078125, 0.0078125), Vector2(0.0625, 0.0078125), Vector2(0.078125, -0.0078125)])
	var incomplete: PackedVector3Array = surface.triangles_world.duplicate()
	for index: int in bowtie.size():
		var a: Vector2 = bowtie[index]
		var b: Vector2 = bowtie[(index + 1) % bowtie.size()]
		var corners := PackedVector3Array([Vector3(a.x, a.y, -0.03125), Vector3(b.x, b.y, -0.03125), Vector3(b.x, b.y, 0.03125), Vector3(a.x, a.y, 0.03125)])
		for corner: int in [0, 1, 2, 0, 2, 3]: incomplete.append(corners[corner])
	var discarded: Dictionary = _section_helper.prepare(_fixture_surface(incomplete), plane, &"FixtureDigitPlane")
	# Slice away from the prism midpoint: at its midpoint both diagonal face
	# triangulations introduce the bowtie crossing as a shared degree-4 vertex,
	# exercising the older branch rejection instead of omitted-cycle coverage.
	var omitted: Dictionary = _section_helper.slice(discarded, Transform3D(Basis.IDENTITY, Vector3(0, 0, 0.0078125)))
	_section_check(not omitted.get("valid", false) and omitted.get("reason") == "section_contains_unrepresented_segments", "discarded disconnected zero-area cycle cannot hide behind valid loop: " + str(omitted.get("reason")) + " " + str(omitted.get("detail")))
	var copy_before := var_to_bytes(prepared.triangles_world)
	surface.triangles_world[0] = Vector3(10, 10, 10)
	_section_check(var_to_bytes(prepared.triangles_world) == copy_before, "prepared source is detached from caller mutation")


func _polygon_boundary_error(first: PackedVector2Array, second: PackedVector2Array) -> float:
	if first.is_empty() or second.is_empty(): return INF
	var error: float = 0.0
	for pair: Array in [[first, second], [second, first]]:
		for point: Vector2 in pair[0]:
			var nearest: float = INF
			for other: Vector2 in pair[1]: nearest = minf(nearest, point.distance_to(other))
			error = maxf(error, nearest)
	return error


func _fixture_surface(triangles: PackedVector3Array) -> Dictionary:
	return {"valid": true, "triangles_world": triangles, "surface_source_origin_id": &"FixtureWeaponMesh", "resolved_world_origin_id": ROOT}


func _fixture_box(low: Vector3, high: Vector3) -> PackedVector3Array:
	var vertices := PackedVector3Array([Vector3(low.x, low.y, low.z), Vector3(high.x, low.y, low.z), Vector3(high.x, high.y, low.z), Vector3(low.x, high.y, low.z), Vector3(low.x, low.y, high.z), Vector3(high.x, low.y, high.z), Vector3(high.x, high.y, high.z), Vector3(low.x, high.y, high.z)])
	var triangles := PackedVector3Array()
	for face: Array in [[0, 3, 2, 1], [4, 5, 6, 7], [0, 1, 5, 4], [1, 2, 6, 5], [2, 3, 7, 6], [3, 0, 4, 7]]:
		for index: int in [face[0], face[1], face[2], face[0], face[2], face[3]]: triangles.append(vertices[index])
	return triangles


func _section_check(condition: bool, label: String) -> bool:
	_section_checks += 1
	if not condition: _section_failures.append(label); push_error(label)
	return condition


func _finish_sections() -> void:
	var backend := _section_helper.backend_statistics()
	_section_check(backend.section_backend == ("cpp" if FastSection.DEFAULT_USE_NATIVE else "gdscript"), "configured section backend actually used")
	_section_check(backend.fallback_calls == 0, "prepared section verification has no hidden backend fallback")
	if FastSection.DEFAULT_USE_NATIVE:
		_section_check(backend.native_slice_calls > 0 and backend.native_topology_calls > 0, "both compiled section kernels execute")
	var old_ms: float = 0.0
	var fast_ms: float = 0.0
	for case: Dictionary in _section_cases:
		old_ms += float(case.old_ms); fast_ms += float(case.fast_ms)
	var report := {"schema": "prepared_weapon_plane_section_verifier_v1", "ok": _section_failures.is_empty(),
		"backend_statistics":backend,
		"checks": _section_checks, "failures": _section_failures, "cases": _section_cases,
		"comparison_tolerance_m": COMPARISON_TOLERANCE_M, "old_total_ms": old_ms, "fast_total_ms": fast_ms,
		"warm_query_speed_ratio": old_ms / fast_ms if fast_ms > 0.0 else 0.0,
		"total_ms": float(Time.get_ticks_usec() - _section_started) / 1000.0,
		"production_pose_written": false, "grip_accepted": false}
	var path := "C:/WORKSPACE/test_artifacts/verify_prepared_weapon_plane_section_" + Time.get_datetime_string_from_system().replace(":", "-") + ".json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null: push_error("Cannot save section verifier"); quit(1); return
	file.store_string(JSON.stringify(_json(report), "\t")); file.close()
	print("PREPARED_WEAPON_SECTION_RESULT=" + path)
	print("PREPARED_WEAPON_SECTION_SUMMARY=" + JSON.stringify({"ok": report.ok, "checks": report.checks, "failures": report.failures, "old_total_ms": old_ms, "fast_total_ms": fast_ms, "warm_query_speed_ratio": report.warm_query_speed_ratio}))
	quit(0 if report.ok else 1)
