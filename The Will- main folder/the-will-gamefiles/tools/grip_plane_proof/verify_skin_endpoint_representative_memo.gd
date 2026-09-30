extends SceneTree

## Exact endpoint memo regression, not a grip certification.
## Independent oracle is the hash-pinned entire source before this change.
## Complete packets, diagnostics and source order are compared without scrubbing.
const Query = preload("res://runtime/player/grip/skin_plane_contact_query.gd")
const FROZEN_REPORT := "C:/WORKSPACE/test_artifacts/saved_grip_section_coordinates_2026-09-28T11-45-33.json"
const FROZEN_SHA256 := "56ef1ee23b3d3ed2ccabc03be3d710f67433cae6e3e3544d182c27d92b995d5f"
const SYNTHETIC_PLANE := &"EndpointMemoSyntheticPlane"
const OLD_QUERY_PATH := "C:/WORKSPACE/test_artifacts/skin_plane_contact_query_pre_duration_2026-09-30.gd"
const OLD_QUERY_SHA256 := "56a7ac7dd64852be9a5bddbb1349fabac890b9bc1acf877fc0ecb631a24c135c"

var _indexed := Query.new()
var _oracle: Variant
var _checks: Array[Dictionary] = []
var _cases: Array[Dictionary] = []
var _frozen_sections := 0
var _retained_invalid_sections := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var started := Time.get_ticks_usec()
	if not _check(FileAccess.file_exists(OLD_QUERY_PATH), "old source oracle exists"):
		quit(1)
		return
	if not _check(FileAccess.get_sha256(OLD_QUERY_PATH) == OLD_QUERY_SHA256, "old source oracle hash"):
		quit(1)
		return
	var old_script: Script = load(OLD_QUERY_PATH)
	if not _check(old_script != null and old_script.can_instantiate(), "old source oracle loads"):
		quit(1)
		return
	_oracle = old_script.new()
	_synthetic()
	_memo_specific()
	_frozen()
	var failures := 0
	for check: Dictionary in _checks: failures += int(not check.passed)
	var indexed_ms := 0.0
	var oracle_ms := 0.0
	for test: Dictionary in _cases:
		indexed_ms += float(test.indexed_ms)
		oracle_ms += float(test.old_weld_ms)
	var report := {"tool": "skin_endpoint_representative_memo", "passed": failures == 0,
		"checks": _checks, "cases": _cases, "failures": failures,
		"frozen_report": FROZEN_REPORT, "frozen_sha256": FROZEN_SHA256,
		"old_source": OLD_QUERY_PATH, "old_source_sha256": OLD_QUERY_SHA256,
		"frozen_sections": _frozen_sections, "retained_invalid_sections": _retained_invalid_sections,
		"indexed_ms": indexed_ms, "old_weld_ms": oracle_ms,
		"duration_ms": float(Time.get_ticks_usec() - started) / 1000.0,
		"production_pose_written": false, "geometry_or_tolerances_changed": false}
	var path := "C:/WORKSPACE/test_artifacts/skin_endpoint_representative_memo_" + Time.get_datetime_string_from_system().replace(":", "-") + ".json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write endpoint memo report")
		quit(1)
		return
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("SKIN_ENDPOINT_REPRESENTATIVE_MEMO passed=", failures == 0, " checks=", _checks.size(),
		" frozen_sections=", _frozen_sections, " retained_invalid=", _retained_invalid_sections,
		" indexed_ms=", indexed_ms, " old_weld_ms=", oracle_ms)
	print("SKIN_ENDPOINT_REPRESENTATIVE_MEMO_REPORT=", path)
	quit(0 if failures == 0 else 1)


func _synthetic() -> void:
	for count: int in [4, 63, 64, 65, 500]:
		_compare("round_" + str(count), _polygon(_round(count)), SYNTHETIC_PLANE)
	var star := _round(500)
	for index: int in star.size(): star[index] *= 0.2 if index % 2 else 1.0
	var star_edges := _polygon(star)
	_compare("alternating_concave_500", star_edges, SYNTHETIC_PLANE)
	var reordered: Array = []
	# A coprime permutation breaks contiguous spatial locality without randomness.
	for index: int in star_edges.size(): reordered.append(star_edges[(index * 137) % star_edges.size()])
	_compare("unordered_concave_500", reordered, SYNTHETIC_PLANE)
	var crossing: Array = []
	var ring := _round(128)
	for index: int in ring.size(): crossing.append([ring[index], ring[(index + 63) % ring.size()]])
	_compare("many_crossings_first_twelve_order", crossing, SYNTHETIC_PLANE)
	var duplicates := _polygon(_round(80))
	duplicates.append(duplicates[3].duplicate(true))
	duplicates.append(duplicates[40].duplicate(true))
	_compare("duplicate_edges", duplicates, SYNTHETIC_PLANE)
	var near_weld := _polygon(_round(80))
	near_weld[30]["a"] += Vector2(0.0000002, 0.0)
	near_weld[31]["b"] += Vector2(0.0000011, 0.0)
	_compare("endpoint_weld_boundary", near_weld, SYNTHETIC_PLANE)
	var tiny := _polygon(_round(80))
	tiny.append([Vector2.ZERO, Vector2(0.0000001, 0.0)])
	tiny.append([Vector2(0.0, 0.0000009), Vector2(0.0000001, 0.0000009)])
	_compare("sub_epsilon_close_edges", tiny, SYNTHETIC_PLANE)
	var coplanar := _polygon(_round(80))
	coplanar[20]["coplanar"] = true
	_compare("coplanar_flags", coplanar, SYNTHETIC_PLANE)
	var open := _polygon(_round(80))
	open.remove_at(12)
	_compare("open_boundary", open, SYNTHETIC_PLANE)
	var branch := _polygon(_round(80))
	branch.append([branch[0]["a"], Vector2(-0.3, 0.2)])
	_compare("branched_boundary", branch, SYNTHETIC_PLANE)
	var translated := _round(80)
	for index: int in translated.size(): translated[index] += Vector2(1024.0, -2048.0)
	_compare("larger_float32_coordinates", _polygon(translated), SYNTHETIC_PLANE)
	_compare("empty", [], SYNTHETIC_PLANE)
	_compare("zero_length", [[Vector2.ONE, Vector2.ONE]], SYNTHETIC_PLANE)
	_compare("nonfinite", [[Vector2(NAN, 0.0), Vector2.ONE]], SYNTHETIC_PLANE)
	_compare("missing_origin", star_edges, &"")


func _memo_specific() -> void:
	var a := Vector2.ZERO
	var b := Vector2(0.0000018, 0.0)
	var both := Vector2(0.0000009, 0.0)
	var repeated: Array = [
		[a, Vector2(0.02, 0.02)], [b, Vector2(0.03, 0.03)],
		[both, Vector2(0.04, 0.04)], [both, Vector2(0.05, 0.05)],
		[both, Vector2(0.06, 0.06)], [both, Vector2(0.07, 0.07)],
	]
	var measured := _compare("ambiguous_first_representative_repeated", repeated, SYNTHETIC_PLANE)
	_check(int(measured.topology.noncoincident_endpoint_welds) == 4, "memo hits still count every noncoincident occurrence")
	for index: int in range(2, repeated.size()):
		_check(int(measured.segments[index].vertex_ids[0]) == 0, "memo retains earliest of two valid representatives " + str(index))
	_compare("signed_zero_exact_keys", [
		[Vector2(0.0, -0.0), Vector2(1.0, 0.0)],
		[Vector2(-0.0, 0.0), Vector2(0.0, 1.0)],
		[Vector2(0.0, 0.0), Vector2(-1.0, 0.0)],
	], SYNTHETIC_PLANE)
	var source := _polygon(_round(80))
	var before := var_to_bytes(source)
	var memo_skipped: Dictionary = _indexed._prepare(source, true)
	var old_skipped: Dictionary = _oracle._prepare(source, true)
	_check(var_to_bytes(memo_skipped) == var_to_bytes(old_skipped), "skip-topology path remains identical")
	_check(var_to_bytes(source) == before, "skip-topology source unchanged")


func _frozen() -> void:
	if not _check(FileAccess.file_exists(FROZEN_REPORT), "frozen report exists"): return
	if not _check(FileAccess.get_sha256(FROZEN_REPORT) == FROZEN_SHA256, "frozen report hash"): return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(FROZEN_REPORT))
	if not _check(data is Dictionary and data.get("cases") is Array, "frozen report parses"): return
	for capture: Dictionary in data.cases:
		for kind: String in capture.surfaces:
			for digit: String in capture.surfaces[kind]:
				for frame: String in ["world", "weapon"]:
					var section: Dictionary = capture.surfaces[kind][digit][frame]
					var edges: Array = []
					for raw_contour: Array in section.raw_contours:
						var contour := PackedVector2Array()
						for point: Array in raw_contour: contour.append(Vector2(float(point[0]), float(point[1])))
						if contour.size() > 1 and contour[0] == contour[-1]: contour.remove_at(contour.size() - 1)
						edges.append_array(_polygon(contour))
					var id := StringName(section.coordinate_provenance.query_origin_id)
					var label := str(capture.slot) + "/" + kind + "/" + digit + "/" + frame
					var measured := _compare(label, edges, id)
					_frozen_sections += 1
					if not bool(section.valid):
						var retained := not bool(measured.get("topology_complete", false))
						_check(retained, label + " existing cap defect remains uncertified")
						_retained_invalid_sections += int(retained)
	_check(_frozen_sections == 60, "all sixty recorded source/frame/digit slices checked")
	_check(_retained_invalid_sections >= 6, "known invalid cap sections remain invalid")


func _compare(label: String, edges: Array, origin_id: StringName) -> Dictionary:
	var before := var_to_bytes(edges)
	var started := Time.get_ticks_usec()
	var measured: Dictionary = _indexed.prepare_target(edges, origin_id)
	var indexed_ms := float(Time.get_ticks_usec() - started) / 1000.0
	started = Time.get_ticks_usec()
	var expected: Dictionary = _oracle.prepare_target(edges, origin_id)
	var old_weld_ms := float(Time.get_ticks_usec() - started) / 1000.0
	var equal := var_to_bytes(measured) == var_to_bytes(expected)
	_check(equal, label + " full packet matches independent old-weld oracle")
	_check(before == var_to_bytes(edges), label + " source unchanged")
	_cases.append({"case": label, "edges": edges.size(), "full_packet_equal": equal,
		"indexed_ms": indexed_ms, "old_weld_ms": old_weld_ms,
		"topology_complete": measured.get("topology_complete", false),
		"self_intersections": measured.get("topology", {}).get("self_intersections", 0)})
	return measured


func _round(count: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index: int in count: points.append(Vector2.from_angle(TAU * float(index) / float(count)) * 0.04)
	return points


func _polygon(points: PackedVector2Array) -> Array:
	var edges: Array = []
	for index: int in points.size(): edges.append({"a": points[index], "b": points[(index + 1) % points.size()]})
	return edges


func _check(passed: bool, label: String) -> bool:
	_checks.append({"name": label, "passed": passed})
	if not passed: push_error(label)
	return passed
