extends SceneTree

const Visibility = preload("res://runtime/player/grip/grip_target_visibility.gd")
const PLANE := &"GripTargetVisibilityVerifierPlane"
var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var query := Visibility.new()
	_basic(query)
	_bones(query)
	_skin(query)
	_local_approach(query)
	_invalid(query)
	_recorded_middle(query)
	var result := {"passed":_failures.is_empty(), "checks":_checks, "failures":_failures,
		"scope":"current named-plane target connector: finite joints including tip, skin obstruction, anatomical eligibility and bounded local pad approach; not swept motion or a 3D grip certificate",
		"recorded_regression":"live_saved_wrapper_grip_2026-10-04T08-30-14_actual_slices.json Middle S2"}
	var path := "C:/WORKSPACE/test_artifacts/grip_target_visibility_%s.json" % Time.get_datetime_string_from_system().replace(":", "-")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(result, "\t")); file.close()
	print(JSON.stringify(result)); print(path)
	quit(0 if _failures.is_empty() else 1)


func _basic(query: RefCounted) -> void:
	var fixture := _fixture()
	var source: Dictionary = fixture.skin.segments[0]
	var original := var_to_bytes(fixture)
	var prepared: Dictionary = query.prepare(fixture.skin, fixture.state)
	if not _check(prepared.get("valid", false), "valid named current skin and finite skeleton prepare"): return
	var witness := _witness(source, Vector2(0.02, 0.005), Vector2(0.02, 0.015))
	_expect(query.evaluate(prepared, source, witness), true, "accessible_from_gripping_surface", "outward target")
	var circle := witness.duplicate(true)
	circle.circle_point_m = circle.target_point_m; circle.erase("target_point_m")
	_expect(query.evaluate(prepared, source, circle), true, "accessible_from_gripping_surface", "circle witness schema")
	var coincident := _witness(source, Vector2(0.02, 0.005), Vector2(0.02, 0.005))
	_expect(query.evaluate(prepared, source, coincident), true, "coincident_eligible_contact", "zero-length eligible contact")
	source.grip_attraction_eligible = false
	_expect(query.evaluate(prepared, source, coincident), false, "source_is_not_gripping_surface", "zero-length back-side contact remains ineligible")
	source.grip_attraction_eligible = true
	_check(var_to_bytes(fixture) == original, "preparation and all evaluations leave source geometry, caps, provenance and state unchanged")
	var reversed: Dictionary = source.duplicate(true)
	reversed.a = source.b; reversed.b = source.a
	reversed.a_source = source.b_source; reversed.b_source = source.a_source
	_expect(query.evaluate(prepared, reversed, witness), true, "accessible_from_gripping_surface", "source endpoint order does not flip physical side")
	# Rotate/translate presentation in world while keeping the same named plane.
	var frame := Transform3D(Basis(Vector3(1, 2, 3).normalized(), 0.8), Vector3(0.7, -0.5, 0.9))
	var moved := _fixture(frame)
	var moved_prepared: Dictionary = query.prepare(moved.skin, moved.state)
	_expect(query.evaluate(moved_prepared, moved.skin.segments[0], witness), true, "accessible_from_gripping_surface", "world presentation preserves plane-local decision")
	# Mirror all physical plane data, rather than choosing a world-facing side.
	var mirrored := _fixture()
	for edge: Dictionary in mirrored.skin.segments:
		edge.a.y *= -1.0; edge.b.y *= -1.0
	var mirror_witness := _witness(mirrored.skin.segments[0], Vector2(0.02, -0.005), Vector2(0.02, -0.015))
	_expect(query.evaluate(query.prepare(mirrored.skin, mirrored.state), mirrored.skin.segments[0], mirror_witness), true, "accessible_from_gripping_surface", "mirrored hand-side geometry is preserved")


func _bones(query: RefCounted) -> void:
	for section: int in 3:
		var fixture := _fixture()
		var mid_x: float = [0.02, 0.0525, 0.075][section]
		var source := _edge(Vector2(mid_x - 0.004, 0.005), Vector2(mid_x + 0.004, 0.005), section, "bone_test")
		fixture.skin.segments = [source]
		var result: Dictionary = query.evaluate(query.prepare(fixture.skin, fixture.state), source,
			_witness(source, Vector2(mid_x, 0.005), Vector2(mid_x, -0.005)))
		_expect(result, false, "connector_intersects_joint_chain", "finite bone S%d blocks connector" % (section + 1))
		_check(result.get("details", {}).get("bone_section") == section + 1, "correct finite bone is reported")
	var tip := _fixture()
	var terminal := _edge(Vector2(0.08, 0.005), Vector2(0.09, 0.005), 2, "terminal")
	tip.skin.segments = [terminal]
	var prepared: Dictionary = query.prepare(tip.skin, tip.state)
	_expect(query.evaluate(prepared, terminal, _witness(terminal, Vector2(0.085, 0.005), Vector2(0.085, 0.0))), false,
		"connector_intersects_joint_chain", "true terminal tip is part of the finite collision span")
	var beyond: Dictionary = query.evaluate(prepared, terminal, _witness(terminal, Vector2(0.09, 0.005), Vector2(0.09, -0.005)))
	_check(beyond.get("reason") != "connector_intersects_joint_chain", "extension beyond terminal tip is not treated as an infinite bone")
	var overlap: Dictionary = query._intersection(Vector2(0.03, 0), Vector2(0.08, 0), Vector2(0.04, 0), Vector2(0.065, 0))
	_check(not overlap.is_empty() and float(overlap.end_t) > float(overlap.start_t), "collinear finite-bone overlap is detected despite native parallel exclusion")
	_check(query._intersection(Vector2(0, 0), Vector2(0.01, 0), Vector2(0.02, 0), Vector2(0.03, 0)).is_empty(), "separated collinear spans do not collide")


func _skin(query: RefCounted) -> void:
	var fixture := _fixture()
	var source: Dictionary = fixture.skin.segments[0]
	var witness := _witness(source, Vector2(0.02, 0.005), Vector2(0.02, 0.02))
	var blocker := _edge(Vector2(0.01, 0.012), Vector2(0.03, 0.012), -1, "other_skin")
	blocker.grip_attraction_eligible = false
	fixture.skin.segments.append(blocker)
	_expect(query.evaluate(query.prepare(fixture.skin, fixture.state), source, witness), false, "connector_intersects_other_skin", "unowned/back-side skin still blocks")
	blocker.source_id = source.source_id
	_expect(query.evaluate(query.prepare(fixture.skin, fixture.state), source, witness), false, "connector_intersects_other_skin", "same triangle ID never exempts a remote fragment")
	var joined := _fixture()
	var first := _edge(Vector2(0.005, 0.005), Vector2(0.02, 0.005), 0, "left")
	var second := _edge(Vector2(0.02, 0.005), Vector2(0.035, 0.006), 0, "right")
	first.b_source = _source("v:10"); second.a_source = _source("v:10")
	joined.skin.segments = [first, second]
	var joint_witness := _witness(first, first.b, Vector2(0.02, 0.02))
	_expect(query.evaluate(query.prepare(joined.skin, joined.state), first, joint_witness), true, "accessible_from_gripping_surface", "proven adjacent shared endpoint can remain the start")
	second.b = Vector2(0.02, 0.012)
	_expect(query.evaluate(query.prepare(joined.skin, joined.state), first, joint_witness), false, "connector_intersects_other_skin", "incident edge overlapping the connector beyond its start still blocks")
	second.b = Vector2(0.035, 0.006); second.a_source = _source("v:999")
	_expect(query.evaluate(query.prepare(joined.skin, joined.state), first, joint_witness), false, "connector_intersects_other_skin", "unproven coincident topology does not silently weld posed surfaces")
	second.source_id = first.source_id
	_expect(query.evaluate(query.prepare(joined.skin, joined.state), first, joint_witness), true, "accessible_from_gripping_surface", "source-preserving palm fragments can share their actual endpoint")


func _local_approach(query: RefCounted) -> void:
	var fixture := _fixture()
	var source: Dictionary = fixture.skin.segments[0]
	var prepared: Dictionary = query.prepare(fixture.skin, fixture.state)
	var start := Vector2(0.02, 0.005)
	_expect(query.evaluate(prepared, source, _witness(source, start, start + Vector2(0, -0.0004))), true,
		"local_pad_contact_within_existing_cap", "short local pad correction retains existing overlap allowance")
	_expect(query.evaluate(prepared, source, _witness(source, start, start + Vector2(0, -0.0006))), false,
		"target_approaches_through_local_skin", "target inside local tissue beyond cap fails without needing a second-surface crossing")
	_expect(query.evaluate(prepared, source, _witness(source, start, start + Vector2(0.015, -0.0001))), false,
		"target_approaches_through_local_skin", "small normal projection cannot exempt long travel through skin")
	source.allowance_unassigned = true
	_expect(query.evaluate(prepared, source, _witness(source, start, start + Vector2(0, -0.0001))), false,
		"target_approaches_through_local_skin", "unassigned skin gets no local-pad exception")
	var palm := _fixture()
	var palm_edge := _edge(Vector2(-0.04, 0.006), Vector2(-0.01, 0.006), -1, "palm")
	palm_edge.palm_owned = true; palm_edge.max_inward_depth_m = 0.0025
	palm.skin.segments = [palm_edge]
	_expect(query.evaluate(query.prepare(palm.skin, palm.state), palm_edge, _witness(palm_edge, Vector2(-0.02, 0.006), Vector2(-0.02, 0.012))), true,
		"accessible_from_gripping_surface", "identified palm uses its finite wrist-to-digit-base span")
	_expect(query.evaluate(query.prepare(palm.skin, palm.state), palm_edge, _witness(palm_edge, Vector2(-0.02, 0.006), Vector2(-0.02, 0.004))), true,
		"local_pad_contact_within_existing_cap", "existing 2.5 mm palm cap admits a 2 mm local correction")


func _invalid(query: RefCounted) -> void:
	var fixture := _fixture()
	var source: Dictionary = fixture.skin.segments[0]
	var witness := _witness(source, Vector2(0.02, 0.005), Vector2(0.02, 0.015))
	var prepared: Dictionary = query.prepare(fixture.skin, fixture.state)
	for key: String in ["origin_id", "source_id", "skin_point_m", "target_point_m"]:
		var malformed := witness.duplicate(true); malformed.erase(key)
		var result: Dictionary = query.evaluate(prepared, source, malformed)
		_check(not result.valid and not result.accessible, "missing witness " + key + " fails closed")
	var bad := _fixture(); bad.state.erase("tip_world")
	_check(not query.prepare(bad.skin, bad.state).valid, "missing true terminal tip fails preparation")
	bad = _fixture(); bad.state.plane_origin_id = &"OtherPlane"
	_check(not query.prepare(bad.skin, bad.state).valid, "mismatched named plane fails preparation")
	bad = _fixture(); bad.state.plane_to_world.basis = Basis.from_scale(Vector3(2, 1, 1))
	_check(not query.prepare(bad.skin, bad.state).valid, "nonmetric plane is not silently used")
	bad = _fixture(); bad.skin.segments[0].a = Vector2(NAN, 0)
	_check(not query.prepare(bad.skin, bad.state).valid, "nonfinite skin fails preparation")
	var moved: Dictionary = source.duplicate(true); moved.a += Vector2(0.001, 0)
	var unavailable: Dictionary = query.evaluate(prepared, moved, witness)
	_check(not unavailable.valid and not unavailable.accessible, "source ID alone cannot authorize different geometry")
	var off_edge := witness.duplicate(true); off_edge.skin_point_m = Vector2(0.02, 0.006)
	_check(not query.evaluate(prepared, source, off_edge).valid, "witness detached from supplied edge fails closed")


func _recorded_middle(query: RefCounted) -> void:
	var fixture := _fixture()
	var joints: Array[Vector3] = [Vector3.ZERO, Vector3(0.0431861281394959, 0.0180445909500122, 0), Vector3(0.0457516312599182, 0.0431735813617706, 0)]
	fixture.state.joint_origins_world = joints
	fixture.state.tip_world = Vector3(0.0157725811004639, 0.0424794554710388, 0)
	var source := _edge(Vector2(0.0367707163095474, 0.036392904818058), Vector2(0.0346864275634289, 0.0403203144669533), 1, "0/3827")
	source.max_inward_depth_m = 0.00048
	fixture.skin.segments = [source]
	var witness := _witness(source, source.b, Vector2(0.02775913849473, 0.0513444244861603))
	var result: Dictionary = query.evaluate(query.prepare(fixture.skin, fixture.state), source, witness)
	_expect(result, false, "connector_intersects_joint_chain", "recorded 13.0199 mm Middle S2 connector is inaccessible")
	_check(result.get("details", {}).get("bone_section") == 3, "recorded connector crosses J3-to-true-tip, not an infinite extension")
	_check(absf(float(result.get("details", {}).get("connector_fraction", -1)) - 0.23220224) < 0.00001,
		"recorded finite crossing occurs 23.2202 percent along the connector")
	var point: Vector2 = result.get("details", {}).get("blocking_point_m", Vector2.INF)
	_check(point.distance_to(Vector2(0.03307789615, 0.042880138)) < 0.0000001, "recorded crossing reproduces independently measured coordinates")


func _fixture(frame: Transform3D = Transform3D.IDENTITY) -> Dictionary:
	var joints: Array[Vector3] = [frame * Vector3.ZERO, frame * Vector3(0.04, 0, 0), frame * Vector3(0.065, 0, 0)]
	return {"skin":{"valid":true, "plane_origin_id":PLANE,
		"segments":[_edge(Vector2(0.005, 0.005), Vector2(0.035, 0.005), 0, "s1")]},
		"state":{"plane_origin_id":PLANE, "plane_to_world":frame,
			"joint_origins_world":joints, "tip_world":frame * Vector3(0.085, 0, 0),
			"hand_to_world":frame * Transform3D(Basis.IDENTITY, Vector3(-0.05, 0, 0)), "hand_origin_id":&"VerifierHand"}}


func _edge(a: Vector2, b: Vector2, owner: int, source: String) -> Dictionary:
	return {"a":a, "b":b, "section_owner":owner, "source_id":source, "origin_id":PLANE,
		"max_inward_depth_m":0.0005, "allowance_unassigned":false, "grip_attraction_eligible":true,
		"a_source":_source(source + ":a"), "b_source":_source(source + ":b")}


func _source(key: String) -> Dictionary:
	return {"topology_key":key, "topology_ambiguous":false}


func _witness(edge: Dictionary, point: Vector2, target: Vector2) -> Dictionary:
	return {"valid":true, "origin_id":PLANE, "source_id":edge.source_id, "skin_point_m":point, "target_point_m":target}


func _expect(result: Dictionary, accessible: bool, reason: String, label: String) -> void:
	_check(result.get("valid", false) and result.get("accessible", not accessible) == accessible and result.get("reason") == reason,
		label + ": " + str(result))


func _check(condition: bool, label: String) -> bool:
	_checks += 1
	if not condition: _failures.append(label)
	return condition
