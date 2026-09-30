extends SceneTree

const Query = preload("res://tools/grip_plane_proof/planar_circle_skin_contact.gd")
const PLANE: StringName = &"CircleContactVerificationPlane"
const SOURCE: StringName = &"CircleContactVerificationTarget"
const RADIUS: float = 0.05
var _checks: int = 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var query := Query.new()
	var crossing := _segment(Vector2(-0.1,0), Vector2(0.1,0), &"crossing")
	var report: Dictionary = query.evaluate([crossing], Vector2.ZERO, RADIUS, PLANE, SOURCE)
	_check(report.get("valid", false), "whole-segment query accepts valid crossing")
	if not report.get("valid", false):
		_finish(); return
	_check((crossing.a as Vector2).length() > RADIUS and (crossing.b as Vector2).length() > RADIUS, "crossing endpoints are both outside")
	_check(report.min_signed_clearance_m == -RADIUS and report.maximum_inward_depth_m == RADIUS, "interior crossing detects full center depth despite exterior endpoints")
	_check(report.segments[0].skin_segment_t == 0.5 and report.nearest_skin_point_m == Vector2.ZERO, "projection locates interior minimum instead of checking endpoints only")
	_check(report.tangent_ambiguous and report.nearest_circle_point_m == null and report.circle_outward_normal == null, "center contact retains known clearance without inventing normal or circle witness")
	_check(report.segments[0].tangent_ambiguous and report.segments[0].circle_point_m == null, "center degeneracy is explicit on segment record")
	var off_center := _segment(Vector2(-0.1,0.02),Vector2(0.1,0.02),&"off_center")
	var inside: Dictionary = query.evaluate([off_center],Vector2.ZERO,RADIUS,PLANE,SOURCE)
	_near(inside.min_signed_clearance_m,-0.03,0.000000002,"off-center interior minimum gives exact analytic depth within input Vector2 rounding")
	_check(not inside.tangent_ambiguous and (inside.circle_outward_normal as Vector2).distance_to(Vector2(0,1)) < 0.0000001, "noncentral radial normal is defined and points toward positive Y skin")
	_near((inside.nearest_circle_point_m as Vector2).y,RADIUS,0.000000002,"inside witness lies on circle radius")
	var tangent := _segment(Vector2(-0.02,RADIUS),Vector2(0.02,RADIUS),&"tangent")
	var touching: Dictionary = query.evaluate([tangent],Vector2.ZERO,RADIUS,PLANE,SOURCE)
	_near(touching.min_signed_clearance_m,0.0,0.000000002,"50mm tangent accounts only for stored Vector2 rounding")
	_check(not touching.tangent_ambiguous and touching.segments[0].skin_segment_t == 0.5,"tangent has a mobile interior witness and defined normal")
	var exact_tangent := _segment(Vector2(-0.125,0.0625),Vector2(0.125,0.0625),&"binary_tangent")
	_check(query.evaluate([exact_tangent],Vector2.ZERO,0.0625,PLANE,SOURCE).min_signed_clearance_m == 0.0,"binary-exact tangent reports zero without tolerance policy")
	var exterior := _segment(Vector2(0.08,-0.02),Vector2(0.08,0.02),&"exterior")
	var separated: Dictionary = query.evaluate([exterior],Vector2.ZERO,RADIUS,PLANE,SOURCE)
	_near(separated.min_signed_clearance_m,0.03,0.000000003,"outside segment reports positive separation")
	_check(separated.maximum_inward_depth_m == 0.0,"outside segment has no inward depth")
	var endpoint := _segment(Vector2(0.08,0.02),Vector2(0.09,0.03),&"endpoint")
	var clamped: Dictionary = query.evaluate([endpoint],Vector2.ZERO,RADIUS,PLANE,SOURCE)
	_check(clamped.segments[0].skin_segment_t == 0.0 and clamped.nearest_skin_point_m == endpoint.a,"projection clamps to actual segment rather than infinite supporting line")
	var mixed: Dictionary = query.evaluate([exterior,off_center,tangent],Vector2.ZERO,RADIUS,PLANE,SOURCE)
	_check(mixed.nearest_source_id == &"off_center" and mixed.nearest_segment_index == 1 and mixed.segment_count == 3,"aggregate identifies deepest whole-edge witness with original source")
	_check(mixed.min_signed_clearance_m == inside.min_signed_clearance_m,"aggregate clearance matches per-segment minimum")
	var shift := Vector2(0.03125,-0.0625)
	var shifted := _segment((tangent.a as Vector2)+shift,(tangent.b as Vector2)+shift,&"tangent")
	var translated: Dictionary = query.evaluate([shifted],shift,RADIUS,PLANE,SOURCE)
	_near(translated.min_signed_clearance_m,touching.min_signed_clearance_m,0.00000001,"common translation preserves signed clearance")
	_check((translated.nearest_circle_point_m as Vector2).distance_to((touching.nearest_circle_point_m as Vector2)+shift) < 0.00000001,"circle witness transforms with common translation")
	var rotation: float = 0.731
	var rotated := _segment((tangent.a as Vector2).rotated(rotation),(tangent.b as Vector2).rotated(rotation),&"tangent")
	var turned: Dictionary = query.evaluate([rotated],Vector2.ZERO,RADIUS,PLANE,SOURCE)
	_near(turned.min_signed_clearance_m,touching.min_signed_clearance_m,0.00000001,"rotation preserves tangent clearance")
	_check((turned.nearest_circle_point_m as Vector2).distance_to((touching.nearest_circle_point_m as Vector2).rotated(rotation)) < 0.00000001,"circle witness follows rotation")
	_check((turned.nearest_circle_point_m as Vector2).distance_to(touching.nearest_circle_point_m) > 0.01,"contact witness slides to a new location rather than locking first contact")
	_check((turned.circle_outward_normal as Vector2).distance_to((touching.circle_outward_normal as Vector2).rotated(rotation)) < 0.000002,"outward normal follows current tangent")
	var reversed := _segment(tangent.b,tangent.a,&"tangent")
	var reverse_result: Dictionary = query.evaluate([reversed],Vector2.ZERO,RADIUS,PLANE,SOURCE)
	_check(reverse_result.min_signed_clearance_m == touching.min_signed_clearance_m and reverse_result.nearest_skin_point_m == touching.nearest_skin_point_m,"reversing skin edge retains physical clearance and witness")
	var missing_origin := tangent.duplicate()
	missing_origin.erase("origin_id")
	_reject(query.evaluate([missing_origin],Vector2.ZERO,RADIUS,PLANE,SOURCE),"missing segment origin rejected")
	var wrong_origin := tangent.duplicate()
	wrong_origin.origin_id = &"OtherPlane"
	_reject(query.evaluate([wrong_origin],Vector2.ZERO,RADIUS,PLANE,SOURCE),"mismatched segment origin rejected")
	var missing_source := tangent.duplicate()
	missing_source.erase("source_id")
	_reject(query.evaluate([missing_source],Vector2.ZERO,RADIUS,PLANE,SOURCE),"missing segment source rejected")
	var invalid_source := tangent.duplicate()
	invalid_source.source_id = 42
	_reject(query.evaluate([invalid_source],Vector2.ZERO,RADIUS,PLANE,SOURCE),"non-string segment source rejected")
	_reject(query.evaluate([tangent],Vector2.ZERO,RADIUS,StringName(),SOURCE),"missing circle origin rejected")
	_reject(query.evaluate([tangent],Vector2.ZERO,RADIUS,PLANE,StringName()),"missing circle source rejected")
	_reject(query.evaluate([],Vector2.ZERO,RADIUS,PLANE,SOURCE),"empty skin rejected")
	_reject(query.evaluate([null],Vector2.ZERO,RADIUS,PLANE,SOURCE),"non-dictionary skin entry rejected")
	_reject(query.evaluate([_segment(Vector2.ZERO,Vector2.ZERO,&"zero")],Vector2.ZERO,RADIUS,PLANE,SOURCE),"zero-length edge rejected")
	_reject(query.evaluate([_segment(Vector2(INF,0),Vector2.ZERO,&"infinite")],Vector2.ZERO,RADIUS,PLANE,SOURCE),"nonfinite edge rejected")
	_reject(query.evaluate([tangent],Vector2(NAN,0),RADIUS,PLANE,SOURCE),"nonfinite circle center rejected")
	for radius: float in [0.0,-RADIUS,INF,NAN]:
		_reject(query.evaluate([tangent],Vector2.ZERO,radius,PLANE,SOURCE),"nonpositive or nonfinite radius rejected")
	var saved := var_to_bytes([tangent,off_center,shift])
	var first: Dictionary = query.evaluate([tangent,off_center],shift,RADIUS,PLANE,SOURCE)
	var second: Dictionary = query.evaluate([tangent,off_center],shift,RADIUS,PLANE,SOURCE)
	_check(var_to_bytes(first) == var_to_bytes(second),"identical input produces identical numeric records")
	_check(saved == var_to_bytes([tangent,off_center,shift]),"query preserves caller segments and center")
	_check(not first.grip_accepted and not first.actual_3d_grip_verified and not first.inside_solid_skin_classification_verified,"boundary-only analytic result makes no solid hand or 3D acceptance claim")
	_finish()


func _segment(a: Vector2,b: Vector2,source: StringName) -> Dictionary:
	return {"a":a,"b":b,"origin_id":PLANE,"source_id":source}


func _near(actual: float,expected: float,tolerance: float,label: String) -> void:
	_check(is_finite(actual) and absf(actual-expected)<=tolerance,label)


func _reject(result: Dictionary,label: String) -> void:
	_check(not result.get("valid",false),label)


func _check(condition: bool,label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)
		push_error(label)


func _finish() -> void:
	print("PLANAR_CIRCLE_SKIN_CONTACT_RESULT="+JSON.stringify({"ok":_failures.is_empty(),"checks":_checks,"failures":_failures,
		"actual_3d_grip_verified":false,"grip_accepted":false}))
	quit(0 if _failures.is_empty() else 1)
