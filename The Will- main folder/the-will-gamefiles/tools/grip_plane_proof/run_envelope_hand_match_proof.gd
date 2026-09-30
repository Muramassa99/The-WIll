extends "res://tools/grip_plane_proof/run_shared_hand_closure_proof.gd"

## Bounded static Middle+Thumb matching experiment. The weapon and authored
## station stay fixed; the shared Hand may translate transversely. No scene writes.
const Envelope = preload("res://tools/grip_plane_proof/planar_contact_envelope.gd")
const CONFIG_PATH := "C:/WORKSPACE/test_artifacts/contact_envelope_input_2026-09-26.json"
var _envelope_config: Dictionary = {}
var _envelope_build_count: int = 0
var _envelope_build_ms: float = 0.0
var _envelope_max_vertices: int = 0

func _run() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
	if not parsed is Dictionary or parsed.get("schema") != "contact_envelope_input_v1":
		push_error("Missing explicit measured envelope configuration"); quit(1); return
	for field: String in ["measured_radius_m", "envelope_radius_multiplier", "envelope_radius_m"]:
		if not parsed.get(field) is float or not is_finite(parsed[field]) or parsed[field] <= 0.0:
			push_error("Invalid envelope measurement: " + field); quit(1); return
	if absf(parsed.measured_radius_m * parsed.envelope_radius_multiplier - parsed.envelope_radius_m) > 1.0e-12:
		push_error("Envelope radius does not match measurement and multiplier"); quit(1); return
	var measurement_path: String = str(parsed.get("measurement", "")).replace("\\", "/").simplify_path()
	if not measurement_path.begins_with("C:/WORKSPACE/test_artifacts/") or measurement_path.get_extension() != "json" or measurement_path.substr(3).contains(":"):
		push_error("Invalid workspace measurement path"); quit(1); return
	if FileAccess.get_sha256(measurement_path) != parsed.get("measurement_sha256"):
		push_error("Measured anatomy reference changed"); quit(1); return
	_envelope_config = parsed
	super._run()

func _report_extensions() -> Dictionary:
	return {"schema": "envelope_hand_match_proof_v1", "contact_target_kind": "measured_radius_contact_envelope",
		"independent_membrane_curvature_implemented": true, "continuous_curvature_certified": false,
		"measured_radius_m": _envelope_config.measured_radius_m,
		"envelope_radius_multiplier": _envelope_config.envelope_radius_multiplier,
		"envelope_radius_m": _envelope_config.envelope_radius_m,
		"envelope_configuration_path": CONFIG_PATH, "envelope_configuration_sha256": FileAccess.get_sha256(CONFIG_PATH),
		"measurement_path": _envelope_config.measurement, "measurement_sha256": _envelope_config.measurement_sha256,
		"same_provisional_section_allowances_applied_to_raw_and_envelope": true,
		"whole_hand_contact_solved": false, "opposing_contact_constraint_implemented": false,
		"scope": "isolated_shared_middle_thumb_matching_to_envelope_with_separate_raw_material_safety"}

func _report_stem() -> String:
	return "envelope_hand_match"

func _prepare(definition: Resource, stage: Dictionary) -> Dictionary:
	_envelope_build_count = 0
	_envelope_build_ms = 0.0
	_envelope_max_vertices = 0
	return super._prepare(definition, stage)

func _targets(context: Dictionary, candidate: Dictionary, translation: Array) -> Dictionary:
	var result: Dictionary = super._targets(context, candidate, translation)
	if not result.get("valid", false): return result
	for digit: StringName in DIGITS:
		var slice: Dictionary = result.digits[digit]
		if slice.has("contact_target"): continue
		var started: int = Time.get_ticks_usec()
		var built: Dictionary = Envelope.new().build(slice.polygon, slice.origin_id,
			context.surface.surface_source_origin_id, _envelope_config.envelope_radius_m, true)
		if not built.get("valid", false): return {"valid": false, "reason": "envelope_construction_failed", "details": built}
		var target: Dictionary = Depth.new().prepare_ordered_target(built.envelope_polygon_m, slice.origin_id,
			StringName(str(context.surface.surface_source_origin_id) + ":contact_envelope"), true)
		if not target.get("valid", false): return {"valid": false, "reason": "envelope_target_invalid", "details": target}
		slice["contact_target"] = target
		slice["contact_envelope_metadata"] = {"radius_m": built.inward_min_radius_m,
			"construction": built.construction, "numeric_units_per_meter": built.numeric_units_per_meter,
			"nominal_offset_arc_tolerance_m": built.nominal_offset_arc_tolerance_m,
			"source_outside_area_m2": built.source_outside_area_m2, "source_outside_loop_count": built.source_outside_loop_count,
			"envelope_verified": false, "continuous_curvature_certified": false}
		_envelope_build_count += 1
		_envelope_build_ms += float(Time.get_ticks_usec() - started) / 1000.0
		_envelope_max_vertices = maxi(_envelope_max_vertices, target.polygon.size())
	return result

func _observe_slice(context: Dictionary, candidate: Dictionary, slice: Dictionary, digit: StringName, keep_geometry: bool) -> Dictionary:
	var result: Dictionary = _observer.evaluate(context.observations[digit], candidate, slice.plane, slice.origin_id,
		slice.target, context.guide_initial_radius_m, keep_geometry, slice.contact_target)
	if keep_geometry and result.get("valid", false):
		result["contact_target_polygon_m"] = slice.contact_target.polygon
		result["contact_envelope_metadata"] = slice.contact_envelope_metadata
	return result

func _evaluate(context: Dictionary, parameters: Array, keep_geometry: bool = false) -> Dictionary:
	var result: Dictionary = super._evaluate(context, parameters, keep_geometry)
	if not result.get("valid", false): return result
	for key: String in ["contact_known_excess_depth_lower_m", "contact_exceeding_known_segment_count", "contact_unresolved_known_segment_count", "contact_unassigned_skin_depth_upper_m"]:
		result[key] = 0
	for digit: Dictionary in result.digits:
		for key: String in ["contact_known_excess_depth_lower_m", "contact_unassigned_skin_depth_upper_m"]:
			result[key] = maxf(float(result[key]), float(digit[key]))
		for key: String in ["contact_exceeding_known_segment_count", "contact_unresolved_known_segment_count"]:
			result[key] += digit[key]
	return result

func _search(context: Dictionary) -> Dictionary:
	var result: Dictionary = super._search(context)
	result["envelope_build_count"] = _envelope_build_count
	result["envelope_build_ms"] = _envelope_build_ms
	result["envelope_max_vertices"] = _envelope_max_vertices
	result["selection_policy"] = "raw_caps_then_envelope_caps_then_missing_contacts_then_envelope_error_plus_unassigned_depth"
	return result

func _rank_keys() -> Array[String]:
	return ["known_excess_depth_lower_m", "exceeding_known_segment_count", "unresolved_known_segment_count",
		"contact_known_excess_depth_lower_m", "contact_exceeding_known_segment_count", "contact_unresolved_known_segment_count",
		"missing_required_contact_regions"]

func _combined_error(value: Dictionary) -> float:
	return float(value.target_error_upper_sum_m) + maxf(float(value.unassigned_skin_depth_upper_m), float(value.contact_unassigned_skin_depth_upper_m))

func _seed_less(a: Dictionary, b: Dictionary) -> bool:
	for key: String in _rank_keys():
		if a[key] != b[key]: return a[key] < b[key]
	if _combined_error(a) != _combined_error(b): return _combined_error(a) < _combined_error(b)
	for index: int in mini(a.parameters.size(), b.parameters.size()):
		if a.parameters[index] != b.parameters[index]: return a.parameters[index] < b.parameters[index]
	return a.parameters.size() < b.parameters.size()

func _better(a: Dictionary, b: Dictionary) -> bool:
	for key: String in _rank_keys():
		var epsilon: float = 0.000001 if key.ends_with("depth_lower_m") else 0.0
		if absf(float(a[key]) - float(b[key])) > epsilon: return a[key] < b[key]
	return _combined_error(a) < _combined_error(b) - 0.0000001
