extends SceneTree

# Exact old/new parity: production traversal, clearance expansion, extrema and
# stride selection are shared; only bulk uniqueness uses the old linear oracle.
const PRESENTER = preload("res://runtime/player/player_equipped_item_presenter.gd")
const ORIGINS = preload("res://core/models/combat_origin_record.gd")
const RULES = preload("res://core/defs/forge/forge_rules_default.tres")
const REPORT := "C:/WORKSPACE/godot_runs/weapon_body_proxy_sampling.json"
const LIBRARY := "user://forge/player_wip_library_state.tres"
const GLAVE_ID := &"player_wip_1794179018.538_16"

class LinearOracle:
	extends "res://runtime/player/player_equipped_item_presenter.gd"

	func _append_unique_proxy_mesh_sample(samples: Array[Vector3], _sample_buckets: Dictionary, sample_position: Vector3) -> void:
		_append_unique_proxy_sample(samples, sample_position)

var checks: Array[Dictionary] = []
var failures := PackedStringArray()
var timings: Array[Dictionary] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var current := PRESENTER.new()
	var previous := LinearOracle.new()
	_test_greedy_streams(current, previous)
	_test_mesh_pipeline(current, previous)
	var actual: Dictionary = {}
	if OS.get_environment("THE_WILL_PROXY_INCLUDE_GLAVE") == "1":
		actual = _measure_saved_glave(current)
	var report := {"ok": failures.is_empty(), "checks": checks, "failures": failures,
		"synthetic_timings": timings, "actual_glave": actual,
		"comparison": "exact ordered samples and count; old oracle only on bounded synthetic inputs"}
	DirAccess.make_dir_recursive_absolute(REPORT.get_base_dir())
	var file := FileAccess.open(REPORT, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "\t") + "\n")
	print("Weapon proxy sampling: %d checks, %d failures" % [checks.size(), failures.size()])
	for failure: String in failures:
		push_error(failure)
	quit(0 if failures.is_empty() else 1)


func _test_greedy_streams(current: RefCounted, previous: RefCounted) -> void:
	var streams: Array[Dictionary] = [
		{"name": "duplicate", "points": PackedVector3Array([Vector3.ZERO, Vector3.ZERO, Vector3.ONE, Vector3.ONE])},
		{"name": "threshold_below_exact_above", "points": PackedVector3Array([Vector3.ZERO,
			Vector3(0.0004999, 0, 0), Vector3(0.0005, 0, 0), Vector3(0.0005001, 0, 0)])},
		{"name": "nontransitive_accepted_only", "points": PackedVector3Array([Vector3.ZERO,
			Vector3(0.0004, 0, 0), Vector3(0.0008, 0, 0)])},
		{"name": "negative_cell_boundary", "points": PackedVector3Array([Vector3(-0.00101, 0, 0),
			Vector3(-0.00099, 0, 0), Vector3(-0.00001, 0, 0), Vector3(0.00001, 0, 0)])},
		{"name": "three_axis_neighbours", "points": PackedVector3Array([Vector3(-0.0001, -0.0001, -0.0001),
			Vector3(0.0001, 0.0001, 0.0001), Vector3(0.0009, 0.0009, 0.0009), Vector3(0.0011, 0.0011, 0.0011)])},
		{"name": "same_cell_but_outside_sphere", "points": PackedVector3Array([Vector3.ZERO,
			Vector3(0.0004, 0.0004, 0.0004), Vector3(0.0008, 0.0008, 0.0008)])},
	]
	for fixture: Dictionary in streams:
		var actual: Array[Vector3] = []
		var expected: Array[Vector3] = []
		var buckets := {}
		for point: Vector3 in fixture.points:
			current.call("_append_unique_proxy_mesh_sample", actual, buckets, point)
			previous.call("_append_unique_proxy_sample", expected, point)
		_check(actual == expected, String(fixture.name) + " preserves exact greedy ordered uniqueness")
		if fixture.name == "nontransitive_accepted_only":
			_check(actual == [Vector3.ZERO, Vector3(0.0008, 0, 0)], "rejected middle point cannot suppress a later valid point")


func _test_mesh_pipeline(current: RefCounted, previous: RefCounted) -> void:
	var first := PackedVector3Array([Vector3(-0.002, 0, 0), Vector3(0.002, 0, 0), Vector3(0, 0.004, 0),
		Vector3(0.0004999, 0, 0), Vector3(0.0005, 0, 0), Vector3(0.0005001, 0, 0)])
	var second := PackedVector3Array([first[0], first[1], first[2],
		Vector3(-0.00101, 0, 0), Vector3(-0.00099, 0.0001, 0), Vector3(-0.001, 0, -0.003)])
	var mixed := _mesh([
		{"vertices": first, "indices": PackedInt32Array([0, 1, 2, 3, 4, 5])},
		{"vertices": second, "indices": PackedInt32Array()},
	])
	var many := PackedVector3Array()
	for index in range(180):
		var x := float(index) * 0.006 - 0.54
		many.append(Vector3(x, -0.01, 0.002))
		many.append(Vector3(x + 0.002, 0.01, 0.002))
		many.append(Vector3(x + 0.004, -0.01, -0.002))
	var larger := _mesh([{"vertices": many, "indices": PackedInt32Array()}])
	var fixtures: Array[Dictionary] = [
		{"name": "mixed_indexed_nonindexed_surfaces", "mesh": mixed, "grip": Vector3.ZERO, "cell": 1.0, "clearance": 0.0},
		{"name": "origin_scale_clearance", "mesh": mixed, "grip": Vector3(0.03, -0.02, 0.01), "cell": 2.0, "clearance": 0.01},
		{"name": "cell_space_clearance", "mesh": mixed, "grip": Vector3(-0.1, 0.2, 0.3), "cell": 0.0125, "clearance": 0.005},
		{"name": "over128_candidates_extreme_ties", "mesh": larger, "grip": Vector3.ZERO, "cell": 1.0, "clearance": 0.005},
		{"name": "empty_mesh", "mesh": ArrayMesh.new(), "grip": Vector3.ZERO, "cell": 1.0, "clearance": 0.005},
	]
	for fixture: Dictionary in fixtures:
		var actual: Array[Vector3] = [Vector3.ZERO, Vector3(-0.002, 0, 0)]
		var expected: Array[Vector3] = actual.duplicate()
		var started := Time.get_ticks_usec()
		var old_count := int(previous.call("_append_visual_mesh_proxy_samples", expected, fixture.mesh,
			fixture.grip, ORIGINS.ORIGIN_WEAPON_ROOT, fixture.cell, fixture.clearance))
		var old_ms := float(Time.get_ticks_usec() - started) / 1000.0
		started = Time.get_ticks_usec()
		var new_count := int(current.call("_append_visual_mesh_proxy_samples", actual, fixture.mesh,
			fixture.grip, ORIGINS.ORIGIN_WEAPON_ROOT, fixture.cell, fixture.clearance))
		var new_ms := float(Time.get_ticks_usec() - started) / 1000.0
		_check(actual == expected and var_to_bytes(actual) == var_to_bytes(expected),
			String(fixture.name) + " preserves exact output coordinates, extrema and selection order")
		_check(new_count == old_count and actual.size() == new_count + 2,
			String(fixture.name) + " preserves added count and existing output samples")
		timings.append({"name": fixture.name, "old_ms": old_ms, "new_ms": new_ms, "added_samples": new_count})


func _mesh(surfaces: Array) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	for surface: Dictionary in surfaces:
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = surface.vertices
		if not (surface.indices as PackedInt32Array).is_empty():
			arrays[Mesh.ARRAY_INDEX] = surface.indices
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _measure_saved_glave(current: RefCounted) -> Dictionary:
	var before := FileAccess.get_sha256(LIBRARY)
	var library := ResourceLoader.load(LIBRARY, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as Resource
	if library == null:
		_check(false, "optional actual Glave library loads")
		return {"error": "library_missing"}
	var weapon := library.call("get_saved_wip", GLAVE_ID) as Resource
	if weapon == null or String(weapon.get("forge_project_name")) != "Broken_Glave_v1":
		_check(false, "optional actual Glave exact saved identity exists")
		return {"error": "glave_missing"}
	var stage2 := weapon.get("stage2_item_state") as Resource
	var profile := weapon.get("latest_baked_profile_snapshot") as Resource
	var geometry := stage2.get("current_editable_mesh_state") as Resource if stage2 != null else null
	if geometry == null or profile == null:
		_check(false, "optional actual Glave geometry and cached profile exist")
		return {"error": "geometry_or_cached_profile_missing"}
	var mesh := geometry.call("build_array_mesh") as ArrayMesh
	var samples: Array[Vector3] = [Vector3.ZERO]
	var grip: Vector3 = profile.get("primary_grip_contact_position")
	var started := Time.get_ticks_usec()
	var count := int(current.call("_append_visual_mesh_proxy_samples", samples, mesh, grip,
		ORIGINS.ORIGIN_WEAPON_ROOT, RULES.cell_world_size_meters, 0.005))
	var elapsed := float(Time.get_ticks_usec() - started) / 1000.0
	_check(count > 0 and samples.size() == count + 1, "actual Glave produces full-geometry proxy samples")
	_check(FileAccess.get_sha256(LIBRARY) == before, "actual Glave sampling leaves saved library bytes unchanged")
	return {"weapon": "Broken_Glave_v1", "vertices": geometry.call("get_vertex_count"),
		"triangles": geometry.call("get_triangle_count"), "elapsed_ms": elapsed, "added_samples": count,
		"note": "Direct saved Stage2 mesh with cached primary grip; no slow old oracle and no skill/grip acquisition.",
		"source_sha256": before}


func _check(passed: bool, label: String) -> void:
	checks.append({"ok": passed, "label": label})
	if not passed:
		failures.append(label)
