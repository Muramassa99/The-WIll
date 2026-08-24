extends SceneTree

const PresenterScript = preload(
	"res://runtime/forge_v2/forge_v2_volume_preview_presenter.gd"
)
const StressFixtureScript = preload(
	"res://tools/forge_v2_workpiece_stress_fixture.gd"
)

const RESULT_PATH := (
	"C:/WORKSPACE/godot_runs/"
	+ "forge_v2_csg_boolean_collision_split.json"
)
const REPEAT_COUNT := 5
const HEAD_PRESTATE_BODY_COUNT := 3
const TAIL_PRESTATE_BODY_COUNT := 217

var errors: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(RESULT_PATH.get_base_dir())
	var bodies := _build_bodies(TAIL_PRESTATE_BODY_COUNT + 1)
	_require(
		bodies.size() == TAIL_PRESTATE_BODY_COUNT + 1,
		"fixture body count mismatch"
	)
	var rows: Array[Dictionary] = []
	for stage: Dictionary in [
		{"name": "head", "prestate_body_count": HEAD_PRESTATE_BODY_COUNT},
		{"name": "tail", "prestate_body_count": TAIL_PRESTATE_BODY_COUNT},
	]:
		var stage_name := String(stage.get("name", ""))
		var prestate_count := int(stage.get("prestate_body_count", 0))
		for repeat_index in range(REPEAT_COUNT):
			var lane_order := ["automatic_collision", "visual_only"]
			if repeat_index % 2 == 1:
				lane_order.reverse()
			var pair_rows: Dictionary = {}
			for lane_name_variant: Variant in lane_order:
				var lane_name := String(lane_name_variant)
				var row: Dictionary = await _run_lane(
					bodies,
					stage_name,
					prestate_count,
					repeat_index,
					lane_name == "automatic_collision"
				)
				rows.append(row)
				pair_rows[lane_name] = row
				print(
					"FORGE_V2_CSG_PHASE heartbeat stage=%s repeat=%d lane=%s process_ms=%.3f"
					% [
						stage_name,
						repeat_index + 1,
						lane_name,
						float(row.get("first_process_gap_ms", 0.0)),
					]
				)
			_validate_pair(stage_name, repeat_index, pair_rows)
	var report := {
		"schema": "forge_v2_csg_boolean_collision_split_v1",
		"outcome": "pass" if errors.is_empty() else "fail",
		"proof_passed": errors.is_empty(),
		"scope": (
			"tools-only exact organic CSG append; automatic collision versus visual-only, "
			+ "with manual collision extraction/publication timed after visual settle"
		),
		"repeat_count": REPEAT_COUNT,
		"head_prestate_body_count": HEAD_PRESTATE_BODY_COUNT,
		"tail_prestate_body_count": TAIL_PRESTATE_BODY_COUNT,
		"rows": rows,
		"summary": _build_summary(rows),
		"errors": errors,
		"nonclaims": [
			"This isolates a mature append and does not measure controller or UI work.",
			"Automatic-minus-visual is an empirical collision-path delta, not CPU sampling.",
			"Manual collision extraction/publication is diagnostic and not a production proposal.",
		],
	}
	_write_json_atomic(RESULT_PATH, report)
	if errors.is_empty():
		print("FORGE_V2_CSG_BOOLEAN_COLLISION_SPLIT PASS")
		quit(0)
	else:
		for error: String in errors:
			push_error(error)
		quit(1)


func _build_bodies(count: int) -> Array:
	var bodies: Array = []
	for body_index in range(count):
		var body: Resource = (
			StressFixtureScript.build_seed_body()
			if body_index == 0
			else StressFixtureScript.build_operation_body(body_index - 1)
		)
		if body == null:
			_append_error("fixture body %d missing" % body_index)
			continue
		bodies.append(body)
	return bodies


func _run_lane(
	bodies: Array,
	stage_name: String,
	prestate_count: int,
	repeat_index: int,
	automatic_collision: bool
) -> Dictionary:
	var presenter: Node3D = PresenterScript.new()
	presenter.name = "CsgPhase_%s_%d_%s" % [
		stage_name,
		repeat_index + 1,
		"auto" if automatic_collision else "visual",
	]
	root.add_child(presenter)
	await process_frame
	var prestate_bodies: Array = bodies.slice(0, prestate_count)
	presenter.call("_sync_static_csg_zones", prestate_bodies)
	await process_frame
	await physics_frame
	await process_frame
	await physics_frame
	var zone := _single_zone(presenter)
	_require(zone != null, "%s prestate zone missing" % stage_name)
	if zone == null:
		presenter.queue_free()
		await process_frame
		return {"failure": "prestate_zone_missing"}
	var prestate_zone_instance_id := zone.get_instance_id()
	if not automatic_collision:
		zone.use_collision = false
		zone.collision_layer = 0
		await physics_frame
		await process_frame
	var append_bodies: Array = bodies.slice(0, prestate_count + 1)
	var started_usec := Time.get_ticks_usec()
	presenter.call("_sync_static_csg_zones", append_bodies)
	var sync_return_usec := Time.get_ticks_usec()
	await process_frame
	var first_process_usec := Time.get_ticks_usec()
	await physics_frame
	var first_physics_usec := Time.get_ticks_usec()
	await process_frame
	var second_process_usec := Time.get_ticks_usec()
	await physics_frame
	var second_physics_usec := Time.get_ticks_usec()
	zone = _single_zone(presenter)
	_require(zone != null, "%s post-append zone missing" % stage_name)
	var mesh_evidence := _mesh_evidence(zone)
	var collision_bake_started := Time.get_ticks_usec()
	var collision_shape: ConcavePolygonShape3D = zone.bake_collision_shape()
	var collision_bake_returned := Time.get_ticks_usec()
	var collision_face_count := 0
	if collision_shape != null:
		collision_face_count = collision_shape.get_faces().size() / 3
	var manual_publish_ms := 0.0
	if not automatic_collision and collision_shape != null:
		var static_body := StaticBody3D.new()
		var collision_node := CollisionShape3D.new()
		collision_node.shape = collision_shape
		static_body.add_child(collision_node)
		var publish_started := Time.get_ticks_usec()
		presenter.add_child(static_body)
		await physics_frame
		var publish_ready := Time.get_ticks_usec()
		manual_publish_ms = float(publish_ready - publish_started) / 1000.0
	var diagnostics := presenter.call("get_csg_static_sync_diagnostics") as Dictionary
	var row := {
		"stage": stage_name,
		"repeat": repeat_index + 1,
		"lane": "automatic_collision" if automatic_collision else "visual_only",
		"prestate_body_count": prestate_count,
		"post_body_count": prestate_count + 1,
		"prestate_zone_instance_id": prestate_zone_instance_id,
		"post_zone_instance_id": zone.get_instance_id() if zone != null else 0,
		"zone_reused": zone != null and zone.get_instance_id() == prestate_zone_instance_id,
		"post_child_count": zone.get_child_count() if zone != null else 0,
		"use_collision_during_append": automatic_collision,
		"sync_ms": float(sync_return_usec - started_usec) / 1000.0,
		"first_process_gap_ms": float(first_process_usec - sync_return_usec) / 1000.0,
		"first_physics_gap_ms": float(first_physics_usec - first_process_usec) / 1000.0,
		"second_process_gap_ms": float(second_process_usec - first_physics_usec) / 1000.0,
		"second_physics_gap_ms": float(second_physics_usec - second_process_usec) / 1000.0,
		"append_to_second_physics_ms": float(second_physics_usec - started_usec) / 1000.0,
		"manual_collision_bake_ms": float(collision_bake_returned - collision_bake_started) / 1000.0,
		"manual_collision_publish_ms": manual_publish_ms,
		"collision_face_count": collision_face_count,
		"mesh": mesh_evidence,
		"presenter_mode": String(diagnostics.get("last_mode", "")),
	}
	_require(bool(row.get("zone_reused", false)), "%s zone was not reused" % stage_name)
	_require(
		int(row.get("post_child_count", 0)) == prestate_count + 1,
		"%s appended child count mismatch" % stage_name
	)
	_require(
		String(row.get("presenter_mode", "")) == "incremental_append",
		"%s did not exercise incremental append" % stage_name
	)
	_require(collision_face_count > 0, "%s collision bake returned no faces" % stage_name)
	presenter.queue_free()
	await process_frame
	await physics_frame
	return row


func _single_zone(presenter: Node) -> CSGCombiner3D:
	if presenter == null:
		return null
	var zones: Dictionary = presenter.get("csg_static_zone_nodes") as Dictionary
	if zones.size() != 1:
		return null
	return zones.values()[0] as CSGCombiner3D


func _mesh_evidence(zone: CSGCombiner3D) -> Dictionary:
	if zone == null:
		return {}
	var mesh: ArrayMesh = zone.bake_static_mesh()
	if mesh == null:
		return {}
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	var vertex_count := 0
	var triangle_count := 0
	for surface_index in range(mesh.get_surface_count()):
		var arrays: Array = mesh.surface_get_arrays(surface_index)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices := PackedInt32Array()
		var index_variant: Variant = arrays[Mesh.ARRAY_INDEX]
		if index_variant is PackedInt32Array:
			indices = index_variant as PackedInt32Array
		vertex_count += vertices.size()
		triangle_count += indices.size() / 3 if not indices.is_empty() else vertices.size() / 3
		hashing.update(var_to_bytes(vertices))
		hashing.update(var_to_bytes(indices))
	return {
		"sha256": hashing.finish().hex_encode(),
		"surface_count": mesh.get_surface_count(),
		"vertex_count": vertex_count,
		"triangle_count": triangle_count,
		"aabb_position": _vector3_array(mesh.get_aabb().position),
		"aabb_size": _vector3_array(mesh.get_aabb().size),
	}


func _validate_pair(stage_name: String, repeat_index: int, pair_rows: Dictionary) -> void:
	var automatic: Dictionary = pair_rows.get("automatic_collision", {}) as Dictionary
	var visual: Dictionary = pair_rows.get("visual_only", {}) as Dictionary
	_require(not automatic.is_empty() and not visual.is_empty(), "%s pair missing lane" % stage_name)
	if automatic.is_empty() or visual.is_empty():
		return
	_require(
		automatic.get("mesh", {}) == visual.get("mesh", {}),
		"%s repeat %d visual mesh differs between collision lanes" % [stage_name, repeat_index + 1]
	)
	_require(
		int(automatic.get("collision_face_count", 0))
		== int(visual.get("collision_face_count", 0)),
		"%s repeat %d collision face count differs" % [stage_name, repeat_index + 1]
	)


func _build_summary(rows: Array[Dictionary]) -> Dictionary:
	var result: Dictionary = {}
	for stage_name in ["head", "tail"]:
		var automatic := _filter_rows(rows, stage_name, "automatic_collision")
		var visual := _filter_rows(rows, stage_name, "visual_only")
		var auto_process := _metric(automatic, "first_process_gap_ms")
		var visual_process := _metric(visual, "first_process_gap_ms")
		var paired_deltas := PackedFloat64Array()
		for repeat_index in range(REPEAT_COUNT):
			var auto_row := _row_for_repeat(automatic, repeat_index + 1)
			var visual_row := _row_for_repeat(visual, repeat_index + 1)
			paired_deltas.append(
				float(auto_row.get("first_process_gap_ms", 0.0))
				- float(visual_row.get("first_process_gap_ms", 0.0))
			)
		result[stage_name] = {
			"automatic_collision_first_process_ms": _stats(auto_process),
			"visual_only_first_process_ms": _stats(visual_process),
			"paired_auto_minus_visual_ms": _stats(paired_deltas),
			"visual_manual_collision_bake_ms": _stats(_metric(visual, "manual_collision_bake_ms")),
			"visual_manual_collision_publish_ms": _stats(_metric(visual, "manual_collision_publish_ms")),
			"automatic_total_to_second_physics_ms": _stats(_metric(automatic, "append_to_second_physics_ms")),
			"visual_total_to_second_physics_ms": _stats(_metric(visual, "append_to_second_physics_ms")),
		}
	return result


func _filter_rows(rows: Array[Dictionary], stage_name: String, lane_name: String) -> Array[Dictionary]:
	var filtered: Array[Dictionary] = []
	for row: Dictionary in rows:
		if String(row.get("stage", "")) == stage_name and String(row.get("lane", "")) == lane_name:
			filtered.append(row)
	return filtered


func _row_for_repeat(rows: Array[Dictionary], repeat_number: int) -> Dictionary:
	for row: Dictionary in rows:
		if int(row.get("repeat", 0)) == repeat_number:
			return row
	return {}


func _metric(rows: Array[Dictionary], key: String) -> PackedFloat64Array:
	var values := PackedFloat64Array()
	for row: Dictionary in rows:
		values.append(float(row.get(key, 0.0)))
	return values


func _stats(source: PackedFloat64Array) -> Dictionary:
	var values := Array(source)
	values.sort()
	if values.is_empty():
		return {"count": 0, "mean": 0.0, "p50": 0.0, "min": 0.0, "max": 0.0}
	var total := 0.0
	for value_variant: Variant in values:
		total += float(value_variant)
	return {
		"count": values.size(),
		"mean": total / float(values.size()),
		"p50": float(values[int((values.size() - 1) / 2)]),
		"min": float(values[0]),
		"max": float(values[-1]),
	}


func _vector3_array(value: Vector3) -> Array[float]:
	return [value.x, value.y, value.z]


func _require(condition: bool, message: String) -> void:
	if not condition:
		_append_error(message)


func _append_error(message: String) -> void:
	if not errors.has(message):
		errors.append(message)


func _write_json_atomic(path: String, value: Dictionary) -> void:
	var temporary_path := path + ".tmp"
	var file := FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		_append_error("could not open result file")
		return
	file.store_string(JSON.stringify(value, "  "))
	file.flush()
	file.close()
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	if DirAccess.rename_absolute(temporary_path, path) != OK:
		_append_error("could not publish result file")
