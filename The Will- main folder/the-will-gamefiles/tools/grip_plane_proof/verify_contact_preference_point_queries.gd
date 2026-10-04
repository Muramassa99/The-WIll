extends SceneTree

const Circle = preload("res://runtime/player/grip/planar_circle_skin_contact.gd")
const Saved = preload("res://runtime/player/grip/saved_wrapper_skin_contact.gd")
const Contact = preload("res://runtime/player/grip/skin_plane_contact_query.gd")
const ORIGIN := &"PreferencePointVerifierPlane"
const SOURCE := &"PreferencePointGuide"
var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_circle()
	_wrapper()
	_check(Contact.new()._project(Vector2(4, 5), Vector2(1, 2), Vector2(1, 2)) == Vector2(1, 2),
		"existing projection owner supports legitimate point degeneracy without zero division")
	var result := {"passed": _failures.is_empty(), "checks": _checks, "failures": _failures,
		"scope": "attraction point queries and independent full-edge safety; no grip or motion acceptance"}
	var stamp := Time.get_datetime_string_from_system().replace(":", "-")
	var path := "C:/WORKSPACE/test_artifacts/contact_preference_point_queries_%s.json" % stamp
	var output := FileAccess.open(path, FileAccess.WRITE)
	if output != null: output.store_string(JSON.stringify(result, "\t")); output.close()
	print(JSON.stringify(result)); print(path)
	quit(0 if _failures.is_empty() else 1)


func _circle() -> void:
	var query := Circle.new()
	var segment := _segment(Vector2(-0.125, 0.0625), Vector2(0.125, 0.0625))
	var original := var_to_bytes(segment)
	var whole: Dictionary = query.evaluate([segment], Vector2.ZERO, 0.0625, ORIGIN, SOURCE)
	var point: Dictionary = query.evaluate_point(segment, 0.8, Vector2.ZERO, 0.0625, ORIGIN, SOURCE)
	_check(whole.valid and point.valid, "circle full-edge and selected-point queries both valid")
	if not whole.valid or not point.valid: return
	_near(whole.segments[0].skin_segment_t, 0.5, 0.000000001, "whole edge keeps central closest witness")
	_near(point.skin_segment_t, 0.8, 0.000000001, "selected point can aim inside a long edge away from its nearest witness")
	_near(point.signed_clearance_m, sqrt(0.075 * 0.075 + 0.0625 * 0.0625) - 0.0625, 0.000000001,
		"point query measures selected radial distance")
	_check(point.attraction_only and point.point_parameter_frozen_for_response and not point.grip_accepted,
		"circle point declares attraction scope rather than safety acceptance")
	_check(var_to_bytes(query.evaluate([segment], Vector2.ZERO, 0.0625, ORIGIN, SOURCE)) == var_to_bytes(whole),
		"point query does not change whole-edge observation")
	_check(var_to_bytes(segment) == original, "circle point preserves original edge packet")
	var reversed := _segment(segment.b, segment.a)
	var reverse_point: Dictionary = query.evaluate_point(reversed, 0.2, Vector2.ZERO, 0.0625, ORIGIN, SOURCE)
	_near(reverse_point.signed_clearance_m, point.signed_clearance_m, 0.000000001, "reversing source edge preserves corresponding physical point distance")
	_check(reverse_point.skin_point_m.distance_to(point.skin_point_m) < 0.00000001, "reversed point remains at same skin location")
	var center: Dictionary = query.evaluate_point(_segment(Vector2(-0.01, 0), Vector2(0.01, 0)),
		0.5, Vector2.ZERO, 0.01, ORIGIN, SOURCE)
	_check(center.valid and center.tangent_ambiguous and center.circle_outward_normal == null,
		"circle center remains explicitly ambiguous without invented normal")
	for t: float in [-0.1, 1.1, NAN]:
		_check(not query.evaluate_point(segment, t, Vector2.ZERO, 0.0625, ORIGIN, SOURCE).valid,
			"invalid point parameter rejected")
	_check(not query.evaluate_point(segment, 0.5, Vector2.ZERO, 0.0625, &"WrongPlane", SOURCE).valid,
		"point origin mismatch rejected")


func _wrapper() -> void:
	var query := Saved.new()
	_check(query.begin_acquisition(&"preference-point-verifier"), "saved point verifier owns an acquisition")
	var prepared: Dictionary = query.prepare(_section(false))
	if not _check(prepared.get("valid", false), "exact saved square target prepared"): return
	var target: Dictionary = prepared.digit_target
	var original := var_to_bytes(prepared)
	var outside := _segment(Vector2(-0.02, 0.015), Vector2(0.02, 0.015))
	var outer: Dictionary = query.evaluate_point(outside, 0.6, target)
	if _check(outer.valid, "outside selected point query valid"):
		_near(outer.signed_clearance_m, 0.005, 0.000000005, "outside point has positive guide gap")
		_check(not outer.gradient_ambiguous and outer.target_outward_normal.distance_to(Vector2.DOWN) < 0.00001,
			"outside point uses existing unique normal normalization")
		_check(outer.skin_segment_t == 0.6 and outer.attraction_only and not outer.grip_accepted,
			"saved point retains caller parameter and attraction-only scope")
		_check(outer.cap_status == &"not_assessed_attraction_only", "point never reports a whole-edge cap decision")
	var inside := _segment(Vector2(-0.005, 0.008), Vector2(0.005, 0.008))
	var inner: Dictionary = query.evaluate_point(inside, 0.5, target)
	if _check(inner.valid, "inside selected point query valid"):
		_near(inner.signed_clearance_m, -0.002, 0.000000005, "inside point has negative guide gap")
		_check(not inner.gradient_ambiguous and inner.target_outward_normal.distance_to(Vector2.DOWN) < 0.00001,
			"inside signed-distance gradient points outward")
	var medial: Dictionary = query.evaluate_point(_segment(Vector2(-0.001, 0), Vector2(0.001, 0)), 0.5, target)
	_check(medial.valid and medial.gradient_ambiguous and medial.gradient_nearest_target_points.size() == 4,
		"interior medial-axis point keeps all four distinct nearest features ambiguous")
	var corner: Dictionary = query.evaluate_point(_segment(Vector2(0.01, 0.01), Vector2(0.015, 0.015)), 0.0, target)
	_check(corner.valid and corner.gradient_ambiguous, "actual polygon corner retains ambiguous zero-distance gradient")
	var corner_outside: Dictionary = query.evaluate_point(_segment(Vector2(0.012, 0.012), Vector2(0.02, 0.02)), 0.0, target)
	_check(corner_outside.valid and not corner_outside.gradient_ambiguous,
		"positive-distance point beyond a polygon vertex has a unique point-distance gradient")
	var clockwise: Dictionary = query.prepare(_section(true))
	var reversed: Dictionary = query.evaluate_point(inside, 0.5, clockwise.digit_target)
	_near(reversed.signed_clearance_m, inner.signed_clearance_m, 0.000000001, "target winding does not change point sign or depth")
	_check(reversed.target_outward_normal.distance_to(inner.target_outward_normal) < 0.000001,
		"target winding does not invert signed-distance gradient")
	var dangerous := _segment(Vector2(0, 0.02), Vector2(0, 0.0))
	var before: Dictionary = query.evaluate(prepared, [dangerous], ORIGIN)
	var harmless_endpoint: Dictionary = query.evaluate_point(dangerous, 0.0, target)
	var after: Dictionary = query.evaluate(prepared, [dangerous], ORIGIN)
	_check(before.valid and after.valid and harmless_endpoint.valid and harmless_endpoint.signed_clearance_m > 0.0,
		"attraction can select exterior endpoint on physically penetrating edge")
	if before.valid and after.valid:
		_check(not before.material_constraint_safe and not after.material_constraint_safe,
			"exterior point never hides the rest of the penetrating skin edge")
		_check(before.segments[0].material_cap_status == after.segments[0].material_cap_status
			and before.segments[0].depth_lower_m == after.segments[0].depth_lower_m
			and before.segments[0].depth_upper_m == after.segments[0].depth_upper_m,
			"full-edge cap and depth measurements remain unchanged")
	_check(var_to_bytes(prepared) == original, "point queries preserve saved target vertices and prepared metadata")
	var wrong := inside.duplicate(true); wrong.origin_id = &"OtherPlane"
	_check(not query.evaluate_point(wrong, 0.5, target).valid, "saved point requires same named plane")
	for t: float in [-0.1, 1.1, NAN]:
		_check(not query.evaluate_point(inside, t, target).valid, "saved point rejects invalid parameter")
	_check(not query.evaluate_point(inside, 0.5, {}).valid, "saved point rejects unprepared target")


func _section(reverse: bool) -> Dictionary:
	var polygon := PackedVector2Array([Vector2(-0.01, -0.01), Vector2(0.01, -0.01), Vector2(0.01, 0.01), Vector2(-0.01, 0.01)])
	if reverse: polygon.reverse()
	var result := {"origin_id": ORIGIN, "center": Vector2.ZERO}
	for kind: StringName in Saved.KINDS:
		result[kind] = {"valid": true, "complete": true, "origin_id": ORIGIN, "source_id": SOURCE,
			"polygon": polygon.duplicate()}
	return result


func _segment(a: Vector2, b: Vector2) -> Dictionary:
	return {"a": a, "b": b, "origin_id": ORIGIN, "source_id": "point/skin", "section_owner": 1,
		"palm_owned": false, "max_inward_depth_m": 0.00048, "allowance_unassigned": false}


func _near(actual: float, expected: float, tolerance: float, label: String) -> void:
	_check(is_finite(actual) and absf(actual - expected) <= tolerance, label + ": " + str(actual))


func _check(condition: bool, label: String) -> bool:
	_checks += 1
	if not condition: _failures.append(label)
	return condition
