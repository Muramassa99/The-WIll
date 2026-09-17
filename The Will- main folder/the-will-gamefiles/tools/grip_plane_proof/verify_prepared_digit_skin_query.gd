extends SceneTree

const Store = preload("res://tools/grip_plane_proof/character_hand_anatomy_store.gd")
const Query = preload("res://tools/grip_plane_proof/prepared_digit_skin_query.gd")
const Oracle = preload("res://tools/grip_plane_proof/measure_digit_skin_surface.gd")
const RESOURCE_PATH := "res://tools/grip_plane_proof/prepared_characters/josie/0fb9e5dbe88cd71e342f4efe106676026345d283374abede7dc98853dd784bf5.tres"
const MAX_ERROR_M := 0.000005

var failures: Array[String] = []
var checks := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var path := OS.get_environment("THE_WILL_ANATOMY_RESOURCE_PATH")
	if path.is_empty():
		path = RESOURCE_PATH
	var resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	if resource == null or not bool(Store.new().validate(resource).get("valid", false)):
		push_error("A valid prepared character Resource is required.")
		quit(1)
		return
	var original_bytes := var_to_bytes(resource.reference_skin)
	var results: Array[Dictionary] = []
	var helper := Query.new()
	var max_vertex_error := 0.0
	var max_edge_error := 0.0
	for digit: Dictionary in resource.digits:
		var packet := _packet(resource, digit)
		var query := helper.prepare(packet["snapshot"], resource.reference_skin, packet["context"], packet["plane"], digit["plane_origin_id"])
		var label := String(digit["slot_id"]) + "/" + String(digit["digit_id"])
		_check(bool(query.get("valid", false)), label + " coefficient preparation")
		if not bool(query.get("valid", false)):
			continue
		_check(not bool(query["anatomy_measurement_ran"]) and not bool(query["weights_normalized_by_tool"]), label + " no anatomy measurement or weight normalization")
		_check(query["dynamic_vertex_ids"].size() < query["baseline_vertices_world"].size() and not query["dynamic_vertex_ids"].is_empty(), label + " strict nonempty dynamic vertex subset")
		var poses: Array[Dictionary] = [{"name": "zero", "angles": [0.0, 0.0, 0.0]},
			{"name": "intermediate", "angles": [float(digit["preferred_angles_rad"][0]) * 0.371, float(digit["preferred_angles_rad"][1]) * 0.618, float(digit["preferred_angles_rad"][2]) * 0.427]},
			{"name": "preferred", "angles": digit["preferred_angles_rad"]},
			{"name": "minimum", "angles": digit["min_angles_rad"]},
			{"name": "maximum", "angles": digit["max_angles_rad"]}]
		var query_baseline_bytes := var_to_bytes(query["baseline_vertices_world"])
		for pose: Dictionary in poses:
			var angles: Array[float] = []
			angles.assign(pose["angles"])
			var tested: Dictionary = helper.pose(query, angles)
			var oracle: Dictionary = Oracle.new().build_skin_world(packet["snapshot"], resource.reference_skin, packet["context"], angles)
			var case_label := label + "/" + String(pose["name"])
			_check(bool(tested.get("valid", false)) and bool(oracle.get("valid", false)), case_label + " poses valid")
			if not bool(tested.get("valid", false)) or not bool(oracle.get("valid", false)):
				continue
			var oracle_vertices := PackedVector3Array()
			for surface: Dictionary in oracle["surfaces"]:
				oracle_vertices.append_array(surface["vertices_world"])
			var error := 0.0
			for index: int in range(oracle_vertices.size()):
				error = maxf(error, oracle_vertices[index].distance_to(tested["vertices_world"][index]))
			max_vertex_error = maxf(max_vertex_error, error)
			_check(error <= MAX_ERROR_M, case_label + " all vertices match renderer-convention oracle")
			var all_triangle_ids := PackedInt32Array()
			for index: int in range(query["triangle_indices"].size() / 3):
				all_triangle_ids.append(index)
			# Same triangle intersection routine deliberately isolates the exact
			# coefficient/cache equivalence from independent slicing correctness.
			var oracle_edges := helper._slice_triangles(query, oracle_vertices, all_triangle_ids, false)
			var edge_comparison := _edge_error(tested["segments"], oracle_edges)
			max_edge_error = maxf(max_edge_error, float(edge_comparison["maximum_m"]))
			_check(bool(edge_comparison["same_sources"]) and float(edge_comparison["maximum_m"]) <= MAX_ERROR_M, case_label + " full triangle soup and optimized segments match")
			_check(tested["updated_triangle_count"] == query["dynamic_triangle_ids"].size() and tested["static_segment_count"] == query["static_segments"].size(), case_label + " static intersections reused")
			results.append({"case": case_label, "max_vertex_error_m": error, "max_edge_error_m": edge_comparison["maximum_m"],
				"vertex_count": tested["vertex_count"], "updated_vertex_count": tested["updated_vertex_count"], "triangle_count": tested["triangle_count"], "updated_triangle_count": tested["updated_triangle_count"],
				"segment_count": tested["segments"].size(), "static_segment_count": tested["static_segment_count"], "preparation_ms": query["preparation_ms"], "pose_ms": tested["elapsed_ms"], "full_skin_oracle_ms": oracle["elapsed_milliseconds"]})
		_check(query_baseline_bytes == var_to_bytes(query["baseline_vertices_world"]), label + " retained baseline is immutable across poses")
		var outside: Array[float] = []
		outside.assign(digit["max_angles_rad"])
		outside[0] += 0.1
		_check(not bool(helper.pose(query, outside).get("valid", false)), label + " outside joint range rejected")
	_check(original_bytes == var_to_bytes(resource.reference_skin), "saved reference skin unchanged")
	print("PREPARED_DIGIT_SKIN_QUERY_VERIFICATION=" + JSON.stringify({"passed": failures.is_empty(), "checks": checks, "failures": failures, "cases": results,
		"max_vertex_error_m": max_vertex_error, "max_edge_error_m": max_edge_error, "tolerance_m": MAX_ERROR_M,
		"anatomy_measurement_ran": false, "character_scene_instantiated": false, "files_written": false,
		"full_skin_oracle_is_renderer_convention_helper": true, "slice_equivalence_uses_same_intersection_routine": true}))
	quit(0 if failures.is_empty() else 1)

func _packet(resource: Resource, digit: Dictionary) -> Dictionary:
	# This offline verifier presents the saved calibration plane as world XY.
	# The explicit machine presentation retains the prepared physical scale.
	var machine: Transform3D = (digit["plane_to_machine"] as Transform3D).affine_inverse()
	var hand: Transform3D = resource.reference_skin["bone_origin_records"][digit["hand_bone_name"]]["transform_to_parent"]
	var snapshot := {"bone_names": digit["bone_names"].duplicate(), "bone_root_origin_id": &"RL_BoneRoot",
		"root_parent_world": machine * hand, "relative_transforms": digit["rest_relative_transforms"].duplicate(true),
		"neutral_local_rotations": digit["neutral_local_rotations"].duplicate(), "hinge_axes_local": digit["hinge_axes_local"].duplicate(),
		"tip_offset_local": digit["terminal_skin_offset_local"], "tip_offset_origin_id": digit["terminal_skin_offset_origin_id"],
		"min_angles_rad": digit["min_angles_rad"].duplicate(), "max_angles_rad": digit["max_angles_rad"].duplicate()}
	return {"snapshot": snapshot, "context": {"machine_origin_id": &"RL_BoneRoot", "machine_to_world": machine, "resolve_phase": &"bake_time", "hand_bone_name": digit["hand_bone_name"]},
		"plane": machine * digit["plane_to_machine"]}

func _edge_error(actual: Array, expected: Array) -> Dictionary:
	var groups: Dictionary = {}
	for edge: Dictionary in expected:
		var key := Vector2i(edge["surface_index"], edge["surface_triangle_index"])
		if not groups.has(key):
			groups[key] = []
		groups[key].append(edge)
	var maximum := 0.0
	var same_sources := actual.size() == expected.size()
	for edge: Dictionary in actual:
		var key := Vector2i(edge["surface_index"], edge["surface_triangle_index"])
		var choices: Array = groups.get(key, [])
		var best := INF
		var selected := -1
		for index: int in range(choices.size()):
			var candidate: Dictionary = choices[index]
			var forward := maxf((edge["a"] as Vector2).distance_to(candidate["a"]), (edge["b"] as Vector2).distance_to(candidate["b"]))
			var reverse := maxf((edge["a"] as Vector2).distance_to(candidate["b"]), (edge["b"] as Vector2).distance_to(candidate["a"]))
			if minf(forward, reverse) < best:
				best = minf(forward, reverse)
				selected = index
		if selected < 0:
			same_sources = false
		else:
			choices.remove_at(selected)
		maximum = maxf(maximum, best)
	return {"same_sources": same_sources, "maximum_m": maximum}

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_error("FAIL: " + label)
