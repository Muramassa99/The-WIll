extends RefCounted

const ForgeV2MaterialBodyScript = preload(
	"res://runtime/forge_v2/forge_v2_material_body.gd"
)
const ForgeV2ProfileShapeLibraryScript = preload(
	"res://runtime/forge_v2/forge_v2_profile_shape_library.gd"
)
const ForgeV2VolumeStrokeScript = preload(
	"res://runtime/forge_v2/forge_v2_volume_stroke.gd"
)

const FIXTURE_SCHEMA_VERSION := 1
const FIXTURE_ID := &"forge_v2_workpiece_stress_v1"
const FIXTURE_MATERIAL_ID := &"mat_iron_gray"
const MAX_OPERATION_COUNT := 10001
const GRID_COLUMN_COUNT := 101
const GRID_ROW_COUNT := 100
const GRID_PITCH_METERS := 0.004
const PATH_SAMPLE_COUNT := 5
const FIXED_TIMESTAMP := 1700000000.0
const WORKSPACE_BOUNDS := AABB(
	Vector3(-0.5, -0.5, -0.5),
	Vector3(1.0, 1.0, 1.0)
)
const PROFILE_BOUND_RADIUS_METERS := 0.034
const STRESS_CHECKPOINTS := [
	1, 4, 5, 6, 10, 25, 50, 100, 250, 500, 1000, 2500, 5000,
	7500, 9999, 10000, 10001,
]


static func build_seed_body() -> Resource:
	return _build_profile_body(0, true)


static func build_operation_body(operation_index: int) -> Resource:
	if operation_index < 0 or operation_index >= MAX_OPERATION_COUNT:
		return null
	return _build_profile_body(operation_index + 1, false)


static func build_checkpoint_list(max_operation_count: int) -> PackedInt32Array:
	var normalized_count := clampi(
		max_operation_count,
		1,
		MAX_OPERATION_COUNT
	)
	var result := PackedInt32Array()
	for checkpoint: int in STRESS_CHECKPOINTS:
		if checkpoint <= normalized_count:
			result.append(checkpoint)
	if result.is_empty() or result[-1] != normalized_count:
		result.append(normalized_count)
	return result


static func canonical_body_record(body: Resource) -> String:
	if body == null:
		return "null"
	var parts := PackedStringArray([
		String(body.get("body_id")),
		String(body.get("source_record_id")),
		String(body.get("body_kind")),
		String(body.get("material_variant_id")),
		String(body.get("operation_mode")),
		String(body.get("placement_policy")),
		String(body.get("shape_kind")),
		"R%.6f" % float(body.get("profile_rotation_bias_degrees")),
	])
	var points: PackedVector3Array = body.get("path_points")
	for point: Vector3 in points:
		parts.append("P%.7f,%.7f,%.7f" % [point.x, point.y, point.z])
	var normals: PackedVector3Array = body.get("path_surface_normals")
	for normal: Vector3 in normals:
		parts.append("N%.6f,%.6f,%.6f" % [normal.x, normal.y, normal.z])
	var contacts: PackedVector3Array = body.get("path_contact_directions")
	for contact: Vector3 in contacts:
		parts.append("C%.6f,%.6f,%.6f" % [contact.x, contact.y, contact.z])
	var polygon: PackedVector2Array = body.get("profile_polygon_2d_meters")
	for point: Vector2 in polygon:
		parts.append("S%.6f,%.6f" % [point.x, point.y])
	return "|".join(parts)


static func extend_digest(previous_digest: String, body: Resource) -> String:
	return (
		previous_digest
		+ "\n"
		+ canonical_body_record(body)
	).sha256_text()


static func preflight(max_operation_count: int = MAX_OPERATION_COUNT) -> Dictionary:
	var operation_count := clampi(
		max_operation_count,
		1,
		MAX_OPERATION_COUNT
	)
	var errors: Array[String] = []
	var digest := (
		"schema=%d|fixture=%s"
		% [FIXTURE_SCHEMA_VERSION, String(FIXTURE_ID)]
	).sha256_text()
	var previous_record := ""
	var used_grid_cells: Dictionary = {}
	var previous_bounds := AABB()
	var has_previous_bounds := false
	var generated_bounds := AABB()
	var has_generated_bounds := false
	var maximum_consecutive_center_distance := 0.0
	for serial_index in range(operation_count + 1):
		var body := (
			build_seed_body()
			if serial_index == 0
			else build_operation_body(serial_index - 1)
		)
		if body == null:
			_append_error(errors, "body_%d_missing" % serial_index)
			continue
		var expected_id := StringName("stress_body_%05d" % serial_index)
		if StringName(body.get("body_id")) != expected_id:
			_append_error(errors, "body_%d_id_changed" % serial_index)
		var record := canonical_body_record(body)
		if record == previous_record:
			_append_error(errors, "body_%d_record_repeated" % serial_index)
		previous_record = record
		var grid_cell := _resolve_grid_cell(serial_index)
		if used_grid_cells.has(grid_cell):
			_append_error(errors, "body_%d_grid_cell_repeated" % serial_index)
		used_grid_cells[grid_cell] = true
		if grid_cell.x < 0 or grid_cell.x >= GRID_COLUMN_COUNT:
			_append_error(errors, "body_%d_grid_column_out_of_range" % serial_index)
		if grid_cell.y < 0 or grid_cell.y >= GRID_ROW_COUNT:
			_append_error(errors, "body_%d_grid_row_out_of_range" % serial_index)
		digest = extend_digest(digest, body)
		var validation := _validate_body_contract(body, serial_index)
		for error_variant: Variant in validation.get("errors", []):
			_append_error(errors, String(error_variant))
		var body_bounds := _build_conservative_body_bounds(body)
		if not WORKSPACE_BOUNDS.encloses(body_bounds):
			_append_error(errors, "body_%d_outside_workspace" % serial_index)
		if has_previous_bounds and not previous_bounds.intersects(body_bounds):
			_append_error(errors, "body_%d_not_connected_to_previous" % serial_index)
		if has_previous_bounds:
			var consecutive_center_distance := (
				previous_bounds.get_center().distance_to(body_bounds.get_center())
			)
			maximum_consecutive_center_distance = maxf(
				maximum_consecutive_center_distance,
				consecutive_center_distance
			)
			if consecutive_center_distance > GRID_PITCH_METERS + 0.0000001:
				_append_error(errors, "body_%d_grid_step_changed" % serial_index)
		previous_bounds = body_bounds
		has_previous_bounds = true
		if not has_generated_bounds:
			generated_bounds = body_bounds
			has_generated_bounds = true
		else:
			generated_bounds = generated_bounds.merge(body_bounds)
	return {
		"ok": errors.is_empty(),
		"errors": errors,
		"fixture_schema": FIXTURE_SCHEMA_VERSION,
		"fixture_id": String(FIXTURE_ID),
		"operation_count": operation_count,
		"seed_count": 1,
		"logical_body_count": operation_count + 1,
		"path_samples_per_body": PATH_SAMPLE_COUNT,
		"grid_columns": GRID_COLUMN_COUNT,
		"grid_rows": GRID_ROW_COUNT,
		"grid_pitch_meters": GRID_PITCH_METERS,
		"stream_digest": digest,
		"generated_bounds_position": generated_bounds.position,
		"generated_bounds_size": generated_bounds.size,
		"maximum_consecutive_center_distance_meters": (
			maximum_consecutive_center_distance
		),
		"unique_grid_cell_count": used_grid_cells.size(),
		"connectivity_preflight_scope": (
			"consecutive_unique_grid_cells_with_4mm_center_step_and_"
			+ "conservative_profile_bounds_overlap; exact connectedness_"
			+ "is checkpoint_mesh_analyzer_authority"
		),
	}


static func _build_profile_body(serial_index: int, is_seed: bool) -> Resource:
	var body: Resource = ForgeV2MaterialBodyScript.new()
	var path_points := _build_path_points(serial_index)
	var normals := PackedVector3Array()
	var contacts := PackedVector3Array()
	for _point: Vector3 in path_points:
		normals.append(Vector3.BACK)
		contacts.append(Vector3.FORWARD)
	body.set("body_id", StringName("stress_body_%05d" % serial_index))
	body.set(
		"source_record_id",
		StringName("stress_command_%05d" % serial_index)
	)
	body.set("body_kind", ForgeV2MaterialBodyScript.BODY_KIND_VOLUME_STROKE)
	body.set("material_variant_id", FIXTURE_MATERIAL_ID)
	body.set(
		"operation_mode",
		ForgeV2VolumeStrokeScript.OPERATION_ADD_MATERIAL
	)
	body.set(
		"placement_policy",
		ForgeV2VolumeStrokeScript.PLACEMENT_REPLACE_EXISTING
	)
	body.set("shape_kind", ForgeV2MaterialBodyScript.SHAPE_KIND_PROFILE_PATH)
	body.set("path_points", path_points)
	body.set("path_surface_normals", normals)
	body.set("path_contact_directions", contacts)
	body.set("profile_id", &"stress_asymmetric_profile_v1")
	body.set("profile_display_name", "Stress Asymmetric Profile V1")
	body.set("profile_polygon_2d_meters", _build_profile_polygon())
	body.set("profile_anchor_2d_meters", Vector2.ZERO)
	body.set(
		"profile_contact_point_relative_2d_meters",
		Vector2(0.0, -0.016)
	)
	body.set(
		"profile_contact_direction_2d",
		ForgeV2ProfileShapeLibraryScript.BASIC_PROFILE_LOCAL_SIX
	)
	body.set("profile_contact_distance_meters", 0.016)
	body.set("profile_runtime_schema_version", 1)
	body.set("profile_rotation_bias_degrees", 0.0)
	body.set("created_timestamp", FIXED_TIMESTAMP + float(serial_index))
	body.set("updated_timestamp", FIXED_TIMESTAMP + float(serial_index))
	body.call("normalize")
	body.set("body_id", StringName("stress_body_%05d" % serial_index))
	body.set(
		"source_record_id",
		StringName("stress_command_%05d" % serial_index)
	)
	body.set("created_timestamp", FIXED_TIMESTAMP + float(serial_index))
	body.set("updated_timestamp", FIXED_TIMESTAMP + float(serial_index))
	body.set_meta("forge_v2_stress_seed", is_seed)
	return body


static func _build_path_points(serial_index: int) -> PackedVector3Array:
	var cell := _resolve_grid_cell(serial_index)
	var center_y := (float(cell.x) - 50.0) * GRID_PITCH_METERS
	var center_z := (float(cell.y) - 49.5) * GRID_PITCH_METERS
	var x_min := -0.22
	var x_max := 0.22
	var points := PackedVector3Array()
	for point_index in range(PATH_SAMPLE_COUNT):
		var ratio := float(point_index) / float(PATH_SAMPLE_COUNT - 1)
		points.append(Vector3(
			lerpf(x_min, x_max, ratio),
			center_y,
			center_z
		))
	if serial_index % 2 == 1:
		points.reverse()
	return points


static func _resolve_grid_cell(serial_index: int) -> Vector2i:
	var row := int(serial_index / GRID_COLUMN_COUNT)
	var column_in_row := serial_index % GRID_COLUMN_COUNT
	var column := (
		column_in_row
		if row % 2 == 0
		else GRID_COLUMN_COUNT - 1 - column_in_row
	)
	return Vector2i(column, row)


static func _build_profile_polygon() -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(-0.020, -0.016),
		Vector2(0.026, -0.013),
		Vector2(0.033, 0.006),
		Vector2(0.009, 0.026),
		Vector2(-0.022, 0.018),
	])


static func _validate_body_contract(body: Resource, serial_index: int) -> Dictionary:
	var errors: Array[String] = []
	var points: PackedVector3Array = body.get("path_points")
	var normals: PackedVector3Array = body.get("path_surface_normals")
	var contacts: PackedVector3Array = body.get("path_contact_directions")
	if points.size() != PATH_SAMPLE_COUNT:
		errors.append("body_%d_path_count_changed" % serial_index)
	if normals.size() != points.size():
		errors.append("body_%d_normal_count_changed" % serial_index)
	if contacts.size() != points.size():
		errors.append("body_%d_contact_count_changed" % serial_index)
	for point: Vector3 in points:
		if not point.is_finite():
			errors.append("body_%d_nonfinite_point" % serial_index)
			break
	if StringName(body.get("material_variant_id")) != FIXTURE_MATERIAL_ID:
		errors.append("body_%d_material_changed" % serial_index)
	if not bool(body.call("uses_explicit_surface_contact_authority")):
		errors.append("body_%d_explicit_contact_missing" % serial_index)
	return {"errors": errors}


static func _build_conservative_body_bounds(body: Resource) -> AABB:
	var points: PackedVector3Array = body.get("path_points")
	if points.is_empty():
		return AABB()
	var result := AABB(points[0], Vector3.ZERO)
	for point: Vector3 in points:
		result = result.expand(point)
	return result.grow(PROFILE_BOUND_RADIUS_METERS)


static func _append_error(errors: Array[String], error: String) -> void:
	if errors.size() < 32 and not errors.has(error):
		errors.append(error)
