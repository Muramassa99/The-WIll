extends SceneTree

const PresenterScript = preload(
	"res://runtime/forge_v2/forge_v2_volume_preview_presenter.gd"
)
const StressFixtureScript = preload(
	"res://tools/forge_v2_workpiece_stress_fixture.gd"
)
const VolumeStrokeScript = preload(
	"res://runtime/forge_v2/forge_v2_volume_stroke.gd"
)

const RESULT_PATH := "C:/WORKSPACE/godot_runs/verify_forge_v2_csg_zone_sweep_parity.txt"

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(RESULT_PATH.get_base_dir())
	var presenter: Node3D = PresenterScript.new()
	root.add_child(presenter)

	var stress := _build_stress_bodies(300)
	_check_case(presenter, "connected_300", stress)
	_require(
		bool(presenter.call("_can_skip_all_csg_clip_discovery", stress)),
		"connected stress case did not take the proven empty-clip path"
	)

	var disconnected := _build_stress_bodies(90)
	for index in range(disconnected.size()):
		var group := int(index / 30)
		var offset := Vector3(0.0, 0.0, float(group) * 2.0)
		var body: Resource = disconnected[index]
		var points: PackedVector3Array = body.get("path_points")
		for point_index in range(points.size()):
			points[point_index] += offset
		body.set("path_points", points)
	_check_case(presenter, "disconnected_90", disconnected)

	var mixed := _build_stress_bodies(18)
	(mixed[4] as Resource).set(
		"placement_policy",
		VolumeStrokeScript.PLACEMENT_EMPTY_ONLY
	)
	(mixed[9] as Resource).set(
		"operation_mode",
		VolumeStrokeScript.OPERATION_REMOVE_MATERIAL
	)
	for index in range(12, mixed.size()):
		(mixed[index] as Resource).set("material_variant_id", &"mat_test_second")
	_require(
		not bool(presenter.call("_can_skip_all_csg_clip_discovery", mixed)),
		"mixed semantics incorrectly skipped clip discovery"
	)
	_check_case(presenter, "mixed_fallback_18", mixed)

	var result_lines := PackedStringArray([
		"ok=%s" % str(failures.is_empty()).to_lower(),
		"connected_body_count=300",
		"disconnected_body_count=90",
		"mixed_fallback_body_count=18",
		"failures=%s" % JSON.stringify(failures),
	])
	var file := FileAccess.open(RESULT_PATH, FileAccess.WRITE)
	file.store_string("\n".join(result_lines) + "\n")
	file.flush()
	if failures.is_empty():
		print("FORGE_V2_CSG_ZONE_SWEEP_PARITY PASS")
		quit(0)
	else:
		push_error("; ".join(failures))
		quit(1)


func _check_case(presenter: Node, case_name: String, bodies: Array) -> void:
	var optimized: Array = presenter.call("_build_csg_body_zones", bodies) as Array
	var brute := _build_brute_zones(presenter, bodies)
	var optimized_record := _canonical_zones(optimized)
	var brute_record := _canonical_zones(brute)
	_require(
		optimized_record == brute_record,
		"%s optimized/brute zones differ" % case_name
	)


func _build_brute_zones(presenter: Node, bodies: Array) -> Array:
	var records: Array = []
	for body_index in range(bodies.size()):
		var body: Resource = bodies[body_index] as Resource
		if body == null or bool(presenter.call("_is_remove_material_body", body)):
			continue
		records.append({
			"body": body,
			"body_index": body_index,
			"material_variant_id": StringName(body.get("material_variant_id")),
			"bounds": presenter.call("_build_csg_body_bounds", body) as AABB,
			"clip_bodies": presenter.call(
				"_collect_csg_clip_bodies_for_add_body",
				bodies,
				body_index
			) as Array,
			"is_active_body": false,
		})
	var parents: Array[int] = []
	for index in range(records.size()):
		parents.append(index)
	for first_index in range(records.size()):
		var first := records[first_index] as Dictionary
		for second_index in range(first_index + 1, records.size()):
			var second := records[second_index] as Dictionary
			if (
				StringName(first.get("material_variant_id"))
				!= StringName(second.get("material_variant_id"))
			):
				continue
			if bool(presenter.call(
				"_csg_bounds_intersect",
				first.get("bounds", AABB()) as AABB,
				second.get("bounds", AABB()) as AABB
			)):
				_union(parents, first_index, second_index)
	var groups: Dictionary = {}
	for index in range(records.size()):
		var root_index := _find(parents, index)
		var group: Array = groups.get(root_index, []) as Array
		group.append(records[index])
		groups[root_index] = group
	var zones: Array = []
	for root_variant: Variant in groups.keys():
		zones.append(presenter.call(
			"_build_csg_zone_from_records",
			groups[root_variant] as Array
		) as Dictionary)
	return zones


func _canonical_zones(zones: Array) -> String:
	var records: Array[String] = []
	for zone_variant: Variant in zones:
		var zone := zone_variant as Dictionary
		var body_parts: Array[String] = []
		for body_record_variant: Variant in zone.get("body_records", []):
			var body_record := body_record_variant as Dictionary
			var body: Resource = body_record.get("body", null) as Resource
			var clip_ids: Array[String] = []
			for clip_variant: Variant in body_record.get("clip_bodies", []):
				clip_ids.append(String((clip_variant as Resource).get("body_id")))
			body_parts.append("%s[%s]" % [
				String(body.get("body_id")),
				",".join(clip_ids),
			])
		records.append("%s|%s|%s|%s" % [
			String(zone.get("zone_key", "")),
			String(zone.get("signature", "")),
			",".join(zone.get("primary_body_ids", []) as Array),
			";".join(body_parts),
		])
	records.sort()
	return "\n".join(records)


func _build_stress_bodies(count: int) -> Array:
	var bodies: Array = []
	for index in range(count):
		bodies.append(
			StressFixtureScript.build_seed_body()
			if index == 0
			else StressFixtureScript.build_operation_body(index - 1)
		)
	return bodies


func _find(parents: Array[int], index: int) -> int:
	var current := index
	while parents[current] != current:
		current = parents[current]
	var root_index := current
	current = index
	while parents[current] != current:
		var next := parents[current]
		parents[current] = root_index
		current = next
	return root_index


func _union(parents: Array[int], first: int, second: int) -> void:
	var first_root := _find(parents, first)
	var second_root := _find(parents, second)
	if first_root != second_root:
		parents[second_root] = first_root


func _require(condition: bool, message: String) -> void:
	if not condition and not failures.has(message):
		failures.append(message)
