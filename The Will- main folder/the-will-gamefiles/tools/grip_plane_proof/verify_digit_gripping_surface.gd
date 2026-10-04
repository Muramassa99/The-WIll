extends SceneTree

const Surface = preload("res://runtime/player/grip/prepared_digit_gripping_surface.gd")
const HandSkin = preload("res://runtime/player/grip/prepared_hand_skin_query.gd")
const Rules = preload("res://runtime/player/player_digit_hinge_rules.gd")
const ROOT := &"RL_BoneRoot"
const PLANE := &"DigitGrippingSurfaceVerifierPlane"
const SIGNATURE := "synthetic_gripping_surface_original_weight_fixture"
const OWN_METADATA: Array[String] = ["grip_attraction_eligible", "grip_surface_reason",
	"grip_reference_side_a_m", "grip_reference_side_b_m", "grip_surface_reference_section_origin_id"]
var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var query := Surface.new()
	for slot: StringName in [&"hand_right", &"hand_left"]:
		for digit: StringName in [&"middle", &"index", &"ring", &"pinky", &"thumb"]:
			_case(query, slot, digit)
	_sources(query)
	_faults(query)
	var result := {"passed":_failures.is_empty(), "checks":_checks, "failures":_failures,
		"scope":"synthetic reference-side preparation, original source interpolation, pose/orientation independence and physical edge invariance; real character coverage requires separate verification"}
	var stamp := Time.get_datetime_string_from_system().replace(":", "-")
	var path := "C:/WORKSPACE/test_artifacts/digit_gripping_surface_%s.json" % stamp
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(result, "\t")); file.close()
	print(JSON.stringify(result)); print(path)
	quit(0 if _failures.is_empty() else 1)


func _case(query: RefCounted, slot: StringName, digit: StringName) -> void:
	var adapter := _fixture(slot, digit)
	var original := var_to_bytes(adapter)
	var prepared: Dictionary = query.prepare(adapter, digit)
	var label := str(slot) + "/" + str(digit)
	if not _check(prepared.get("valid", false), label + " reference preparation: " + str(prepared.get("reason", ""))): return
	_check(var_to_bytes(adapter) == original, label + " reference preparation does not alter input")
	var edges: Array = []
	for section: int in 3:
		edges.append(_edge(section, _vertex(section * 5), _vertex(section * 5 + 1)))
		edges.append(_edge(section, _vertex(section * 5 + 2), _vertex(section * 5 + 3)))
		edges.append(_edge(section, _vertex(section * 5), _vertex(section * 5 + 4)))
	var untouched := var_to_bytes(edges)
	var result: Dictionary = query.annotate(prepared, edges, PLANE)
	_check(result.valid and result.eligible_segments == (2 if digit == &"thumb" else 3), label + " only anatomical gripping edges attract")
	for section: int in 3:
		var active := not (digit == &"thumb" and section == 0)
		_check(edges[section * 3].grip_attraction_eligible == active, label + " gripping side eligibility S" + str(section + 1))
		_check(not edges[section * 3 + 1].grip_attraction_eligible and not edges[section * 3 + 2].grip_attraction_eligible,
			label + " backside and exact half-boundary remain collision-only S" + str(section + 1))
		if active:
			_near(edges[section * 3].grip_reference_side_a_m, 0.005, 0.00000002, label + " signed reference distance is measured in metres")
	_check(var_to_bytes(_physical(edges)) == untouched, label + " geometry, source IDs, ownership and caps remain byte-identical")
	# The same reference skin under arbitrary character presentation must retain
	# its anatomical side, including both handedness signs and thumb flexion.
	var transformed := _fixture(slot, digit, Transform3D(Basis(Vector3(1, 2, 3).normalized(), 1.2), Vector3(0.4, -0.3, 0.8)))
	var rotated: Dictionary = query.prepare(transformed, digit)
	if _check(rotated.get("valid", false), label + " rotated reference preparation"):
		var rotated_edges: Array = _physical(edges)
		query.annotate(rotated, rotated_edges, PLANE)
		for index: int in edges.size():
			_check(rotated_edges[index].grip_attraction_eligible == edges[index].grip_attraction_eligible,
				label + " global rotation and translation preserve anatomical side")
	# Moving posed coordinates alone cannot change this reference/material label.
	var bent: Array = _physical(edges)
	for edge: Dictionary in bent:
		edge.a = Vector2(-0.25, 0.43); edge.b = Vector2(0.42, -0.36)
	query.annotate(prepared, bent, PLANE)
	for index: int in edges.size():
		_check(bent[index].grip_attraction_eligible == edges[index].grip_attraction_eligible,
			label + " moving posed endpoints does not relabel skin or involve weapon orientation")


func _sources(query: RefCounted) -> void:
	var prepared: Dictionary = query.prepare(_fixture(&"hand_right", &"middle"), &"middle")
	if not _check(prepared.get("valid", false), "source tests prepared"): return
	var inner := _edge(0, _cut(0, 2, 0.25), _cut(1, 3, 0.35))
	var crossing := _edge(0, _cut(0, 2, 0.25), _cut(1, 3, 0.75))
	var reversed: Dictionary = inner.duplicate(true)
	reversed.a_source = inner.b_source; reversed.b_source = inner.a_source
	var edges: Array = [inner, crossing, reversed]
	query.annotate(prepared, edges, PLANE)
	_check(inner.grip_attraction_eligible and reversed.grip_attraction_eligible, "original source-edge interpolation and endpoint reversal preserve eligibility")
	_near(inner.grip_reference_side_a_m, 0.0025, 0.00000001, "low-to-high source interpolation has correct signed distance")
	_near(inner.grip_reference_side_b_m, 0.0015, 0.00000001, "second endpoint uses its own source parameter")
	_check(not crossing.grip_attraction_eligible and crossing.grip_surface_reason == "reference_side_boundary_or_crossing",
		"straddling edge fails closed without clipping or adding a physical edge")
	var biased := _edge(0, _vertex(2), _vertex(3))
	biased["location_bias"] = {"a_percent":20.0, "b_percent":50.0}
	query.annotate(prepared, [biased], PLANE)
	_check(not biased.has("location_bias"), "ineligible skin cannot retain a displayed or ranked preference")
	var scaled: Dictionary = query.prepare(_fixture(&"hand_right", &"middle", Transform3D.IDENTITY, Basis.from_scale(Vector3(0.01, 0.02, 0.03))), &"middle")
	if _check(scaled.get("valid", false), "imported bone-local units do not need to be metres"):
		var scaled_edge := _edge(0, _vertex(0), _vertex(1))
		query.annotate(scaled, [scaled_edge], PLANE)
		_near(scaled_edge.grip_reference_side_a_m, 0.005, 0.00000002, "metric distance survives scaled bone frames")
	var weighted: Dictionary = query.prepare(_fixture(&"hand_right", &"middle", Transform3D.IDENTITY, Basis.IDENTITY, 1.5), &"middle")
	if _check(weighted.get("valid", false), "nonunit original influence sums are supported"):
		var weighted_edge := _edge(0, _vertex(0), _vertex(1))
		query.annotate(weighted, [weighted_edge], PLANE)
		_near(weighted_edge.grip_reference_side_a_m, 0.0075, 0.00000003, "reference evaluation retains original 1.5 skin weight rather than raw XYZ or normalized weights")


func _faults(query: RefCounted) -> void:
	var adapter := _fixture(&"hand_right", &"middle")
	var prepared: Dictionary = query.prepare(adapter, &"middle")
	if not _check(prepared.get("valid", false), "fault tests prepared"): return
	for fault: String in ["missing", "ambiguous", "coplanar", "source_key", "index", "parameter", "plane", "foreign"]:
		var edge := _edge(0, _cut(0, 2, 0.25), _vertex(1))
		match fault:
			"missing": edge.erase("a_source")
			"ambiguous": edge.a_source.topology_ambiguous = true
			"coplanar": edge.a_source.coplanar = true
			"source_key": edge.a_source.topology_key = "e:2:0"
			"index": edge.a_source.vertex_ids = PackedInt32Array([0, 90000])
			"parameter": edge.a_source.t = 1.01
			"plane": edge.origin_id = &"OtherPlane"
			"foreign": edge.section_owner = -1
		var original := var_to_bytes([edge])
		query.annotate(prepared, [edge], PLANE)
		_check(not edge.grip_attraction_eligible, fault + " cannot fall back to unrestricted attraction")
		_check(var_to_bytes(_physical([edge])) == original, fault + " leaves physical collision input intact")
	var edge := _edge(0, _vertex(0), _vertex(1))
	var invalid: Dictionary = query.annotate({}, [edge], PLANE)
	_check(not invalid.valid and not edge.grip_attraction_eligible, "unavailable preparation explicitly suppresses attraction only")
	var broken := adapter.duplicate(true)
	broken.digit_inputs[&"middle"].snapshot.hinge_axis_origin_ids[0] = &"OtherBone"
	_check(not query.prepare(broken, &"middle").get("valid", false), "hinge vectors require their actual named bone origin")
	broken = adapter.duplicate(true)
	broken.digit_inputs[&"middle"].snapshot.hinge_axes_local[1] = Vector3.RIGHT
	_check(not query.prepare(broken, &"middle").get("valid", false), "longitudinal hinge with zero closing derivative is rejected")


func _fixture(slot: StringName, digit: StringName, machine: Transform3D = Transform3D.IDENTITY,
		bone_basis: Basis = Basis.IDENTITY, weight: float = 1.0) -> Dictionary:
	var chain: Array = Rules.get_chain_rules(slot, digit)
	var names: Array = []
	var frames: Array[Transform3D] = []
	var records := {ROOT:_record(ROOT, &"", Transform3D.IDENTITY, &"machine")}
	var binds: Array = []
	var points := PackedVector3Array()
	var bone_ids := PackedInt32Array()
	var weights := PackedFloat32Array()
	var indices := PackedInt32Array()
	var axes: Array = []
	for section: int in 3:
		var name: StringName = chain[section].bone
		names.append(name); axes.append(chain[section].hinge_axis_local)
		var frame := Transform3D(bone_basis, Vector3(section * 0.03, 0, 0))
		frames.append(frame); binds.append(frame.affine_inverse())
		records[name] = _record(name, ROOT, frame, &"bone_frame")
		var side := signf(float(chain[section].closed_degrees) - float(chain[section].open_degrees))
		var first := points.size()
		for local: Vector3 in [Vector3(0.004, side * 0.005, 0), Vector3(0.016, side * 0.005, 0),
				Vector3(0.004, -side * 0.005, 0), Vector3(0.016, -side * 0.005, 0), Vector3(0.02, 0, 0)]:
			points.append(frame.origin + local); bone_ids.append(section); weights.append(weight)
		indices.append_array(PackedInt32Array([first, first+1, first+2, first+1, first+3, first+2, first, first+4, first+1]))
	var reference := {"bind_bone_names":names, "bind_poses":binds,
		"bone_origin_records":records, "vertices_origin_id":&"GrippingSurfaceReferenceMesh",
		"mesh_origin_record":_record(&"GrippingSurfaceReferenceMesh", ROOT, Transform3D.IDENTITY, &"presentation"),
		"surfaces":[{"vertices":points, "bones":bone_ids, "weights":weights, "indices":indices}]}
	var skin: Dictionary = HandSkin.new().prepare(reference, SIGNATURE)
	var snapshot := {"bone_names":names, "hinge_axes_local":axes, "hinge_axis_origin_ids":names.duplicate(),
		"min_angles_rad":[-2.0,-2.0,-2.0], "max_angles_rad":[2.0,2.0,2.0]}
	var input := {"valid":true, "snapshot":snapshot,
		"digit":{"terminal_skin_offset_local":bone_basis.inverse() * Vector3(0.02,0,0), "terminal_skin_offset_origin_id":names[2]}}
	return {"valid":true, "revision":&"prepared_hand_candidate_pose_v1", "slot":slot,
		"anatomy_signature":SIGNATURE, "skin_prepared":skin,
		"base_packet":{"machine_to_world":machine}, "digit_inputs":{digit:input}}


func _record(id: StringName, parent: StringName, frame: Transform3D, kind: StringName) -> Dictionary:
	return {"origin_id":id, "parent_origin_id":parent, "transform_to_parent":frame,
		"owner_system":&"digit_gripping_surface_verifier", "resolve_phase":&"bake_time",
		"space_type":kind, "is_dynamic":false}


func _vertex(id: int) -> Dictionary:
	return {"kind":"vertex", "vertex_ids":PackedInt32Array([id]), "topology_key":"v:%d" % id,
		"t":0.0, "coplanar":false, "topology_ambiguous":false}


func _cut(a: int, b: int, t: float) -> Dictionary:
	return {"kind":"edge", "vertex_ids":PackedInt32Array([a,b]), "topology_key":"e:%d:%d" % [a,b],
		"t":t, "coplanar":false, "topology_ambiguous":false}


func _edge(section: int, a: Dictionary, b: Dictionary) -> Dictionary:
	return {"a":Vector2(0.005,0.006), "b":Vector2(0.01,0.006), "origin_id":PLANE,
		"a_source":a, "b_source":b, "source_id":"synthetic/" + str(section), "section_owner":section,
		"coplanar":false, "max_inward_depth_m":0.00048, "allowance_unassigned":false}


func _physical(edges: Array) -> Array:
	var copy := edges.duplicate(true)
	for edge: Dictionary in copy:
		for key: String in OWN_METADATA: edge.erase(key)
	return copy


func _near(actual: float, expected: float, tolerance: float, label: String) -> void:
	_check(is_finite(actual) and absf(actual - expected) <= tolerance, label + ": " + str(actual))


func _check(condition: bool, label: String) -> bool:
	_checks += 1
	if not condition: _failures.append(label)
	return condition
