extends RefCounted

const CraftedItemWIPScript = preload("res://core/models/crafted_item_wip.gd")
const ForgeV2AuthoringStateScript = preload(
	"res://runtime/forge_v2/forge_v2_authoring_state.gd"
)
const ForgeV2LayerDataScript = preload(
	"res://runtime/forge_v2/forge_v2_layer_data.gd"
)
const ForgeV2MaterialBodyScript = preload(
	"res://runtime/forge_v2/forge_v2_material_body.gd"
)
const ForgeV2MaterialLedgerScript = preload(
	"res://runtime/forge_v2/forge_v2_material_ledger.gd"
)
const ForgeV2MaterialVolumeResolverScript = preload(
	"res://runtime/forge_v2/forge_v2_material_volume_resolver.gd"
)
const ForgeV2ProfileShapeLibraryScript = preload(
	"res://runtime/forge_v2/forge_v2_profile_shape_library.gd"
)
const ForgeV2VolumeStrokeScript = preload(
	"res://runtime/forge_v2/forge_v2_volume_stroke.gd"
)

const FIXTURE_SCHEMA_VERSION := 1
const FIXTURE_ID := &"forge_v2_workpiece_benchmark_v1"
const FIXTURE_NAME := "Forge V2 Workpiece Benchmark V1"
const FIXTURE_WIP_ID := &"benchmark_forge_v2_workpiece_100_v1"
const FIXTURE_LAYER_ID := &"benchmark_layer_0001"
const FIXTURE_MATERIAL_ID := &"mat_iron_gray"
const FIXED_TIMESTAMP := 1700000000.0
const MAX_OPERATION_COUNT := 100
const PATH_SAMPLE_COUNT := 5
const FIXTURE_WIP_PATH := (
	"C:/WORKSPACE/test_artifacts/"
	+ "forge_v2_workpiece_benchmark_wip.tres"
)
const SCALING_CHECKPOINTS := [1, 10, 25, 50, 100]


static func build_fixture_wip(operation_count: int = MAX_OPERATION_COUNT) -> CraftedItemWIP:
	var normalized_count := clampi(operation_count, 0, MAX_OPERATION_COUNT)
	var authoring_state: Resource = build_authoring_state(normalized_count)
	var wip: CraftedItemWIP = CraftedItemWIPScript.new()
	wip.wip_id = FIXTURE_WIP_ID
	wip.forge_project_name = FIXTURE_NAME
	wip.forge_project_notes = _build_fixture_notes(normalized_count, authoring_state)
	wip.creator_id = &"forge_v2_benchmark"
	wip.created_timestamp = FIXED_TIMESTAMP
	wip.forge_builder_path_id = CraftedItemWIPScript.BUILDER_PATH_MELEE
	wip.forge_builder_component_id = CraftedItemWIPScript.BUILDER_COMPONENT_PRIMARY
	wip.forge_intent = &"intent_melee"
	wip.equipment_context = &"ctx_weapon"
	wip.forge_v2_authoring_state = authoring_state
	wip.layers = []
	wip.latest_baked_profile_snapshot = null
	return wip


static func build_authoring_state(operation_count: int) -> Resource:
	var normalized_count := clampi(operation_count, 0, MAX_OPERATION_COUNT)
	var state: Resource = ForgeV2AuthoringStateScript.new()
	state.call("reset_new_draft", FIXTURE_NAME)
	state.set("draft_id", FIXTURE_ID)
	state.set("source_wip_id", FIXTURE_WIP_ID)
	state.set("project_name", FIXTURE_NAME)
	state.set("creator_id", &"forge_v2_benchmark")
	state.set("created_timestamp", FIXED_TIMESTAMP)
	state.set("updated_timestamp", FIXED_TIMESTAMP)
	state.set("builder_path_id", CraftedItemWIPScript.BUILDER_PATH_MELEE)
	state.set("builder_component_id", CraftedItemWIPScript.BUILDER_COMPONENT_PRIMARY)
	state.set("forge_intent", &"intent_melee")
	state.set("equipment_context", &"ctx_weapon")

	var bodies := build_body_sequence(normalized_count)

	var resolver = ForgeV2MaterialVolumeResolverScript.new()
	var usage_summary: Dictionary = resolver.call(
		"build_usage_summary",
		bodies
	) as Dictionary
	var layer: Resource = ForgeV2LayerDataScript.new()
	var existing_bodies: Array[Resource] = []
	layer.call(
		"configure_from_material_bodies",
		1,
		bodies,
		existing_bodies,
		{},
		usage_summary
	)
	layer.set("layer_id", FIXTURE_LAYER_ID)
	layer.set("created_timestamp", FIXED_TIMESTAMP)
	_rewrite_layer_delta_ids(layer)
	for body: Resource in bodies:
		body.set("committed_layer_id", FIXTURE_LAYER_ID)
		body.set("layer_active", true)

	var ledger: Resource = ForgeV2MaterialLedgerScript.new()
	var layers: Array[Resource] = [layer]
	ledger.call("rebuild_from_layers", layers)
	ledger.set("updated_timestamp", FIXED_TIMESTAMP)
	state.set("material_bodies", bodies)
	state.set("volume_strokes", [])
	state.set("forge_layers", layers)
	state.set("undone_forge_layers", [])
	state.set("material_ledger", ledger)
	state.set(
		"project_notes",
		_build_fixture_notes(normalized_count, state)
	)
	state.call("normalize")
	state.set("draft_id", FIXTURE_ID)
	state.set("source_wip_id", FIXTURE_WIP_ID)
	state.set("created_timestamp", FIXED_TIMESTAMP)
	state.set("updated_timestamp", FIXED_TIMESTAMP)
	return state


static func build_body_sequence(
	operation_count: int = MAX_OPERATION_COUNT
) -> Array[Resource]:
	var normalized_count := clampi(operation_count, 0, MAX_OPERATION_COUNT)
	var bodies: Array[Resource] = []
	bodies.append(_build_profile_body(-1, true))
	for operation_index in range(normalized_count):
		bodies.append(_build_profile_body(operation_index, false))
	return bodies


static func save_fixture_wip(
	path: String = FIXTURE_WIP_PATH,
	operation_count: int = MAX_OPERATION_COUNT
) -> Dictionary:
	var normalized_path := path.strip_edges()
	if normalized_path.is_empty():
		return {
			"ok": false,
			"error": "fixture_path_empty",
		}
	DirAccess.make_dir_recursive_absolute(normalized_path.get_base_dir())
	var wip := build_fixture_wip(operation_count)
	var save_error := ResourceSaver.save(wip, normalized_path)
	if save_error != OK:
		return {
			"ok": false,
			"error": "fixture_save_failed",
			"error_code": save_error,
			"path": normalized_path,
		}
	var loaded_wip := ResourceLoader.load(
		normalized_path,
		"",
		ResourceLoader.CACHE_MODE_IGNORE
	) as CraftedItemWIP
	var validation := validate_fixture_wip(loaded_wip, operation_count)
	validation["path"] = normalized_path
	validation["bytes"] = _file_size_bytes(normalized_path)
	return validation


static func validate_fixture_wip(
	wip: CraftedItemWIP,
	expected_operation_count: int = MAX_OPERATION_COUNT
) -> Dictionary:
	var expected_count := clampi(
		expected_operation_count,
		0,
		MAX_OPERATION_COUNT
	)
	var errors: Array[String] = []
	if wip == null:
		errors.append("wip_missing")
		return {
			"ok": false,
			"errors": errors,
		}
	if wip.wip_id != FIXTURE_WIP_ID:
		errors.append("wip_id_changed")
	if wip.forge_project_name != FIXTURE_NAME:
		errors.append("wip_name_changed")
	var state: Resource = wip.forge_v2_authoring_state
	if state == null:
		errors.append("authoring_state_missing")
		return {
			"ok": false,
			"errors": errors,
		}
	var bodies: Array = state.get("material_bodies") as Array
	if bodies.size() != expected_count + 1:
		errors.append("body_count_changed")
	var seen_ids: Dictionary = {}
	for body_index in range(bodies.size()):
		var body: Resource = bodies[body_index] as Resource
		if body == null:
			errors.append("body_%d_missing" % body_index)
			continue
		var body_id := StringName(body.get("body_id"))
		if body_id == StringName() or seen_ids.has(body_id):
			errors.append("body_%d_id_invalid" % body_index)
		seen_ids[body_id] = true
		var points: PackedVector3Array = body.get("path_points")
		var normals: PackedVector3Array = body.get("path_surface_normals")
		var contacts: PackedVector3Array = body.get("path_contact_directions")
		if points.size() != PATH_SAMPLE_COUNT:
			errors.append("body_%d_path_count_changed" % body_index)
		if normals.size() != points.size():
			errors.append("body_%d_normal_count_changed" % body_index)
		if contacts.size() != points.size():
			errors.append("body_%d_contact_count_changed" % body_index)
		if StringName(body.get("material_variant_id")) != FIXTURE_MATERIAL_ID:
			errors.append("body_%d_material_changed" % body_index)
		if StringName(body.get("committed_layer_id")) != FIXTURE_LAYER_ID:
			errors.append("body_%d_layer_changed" % body_index)
	var layers: Array = state.get("forge_layers") as Array
	if layers.size() != 1:
		errors.append("layer_count_changed")
	elif StringName((layers[0] as Resource).get("layer_id")) != FIXTURE_LAYER_ID:
		errors.append("layer_id_changed")
	var expected_signature := build_fixture_signature(expected_count)
	var actual_signature := calculate_state_signature(state)
	if actual_signature != expected_signature:
		errors.append("fixture_signature_changed")
	return {
		"ok": errors.is_empty(),
		"errors": errors,
		"fixture_schema": FIXTURE_SCHEMA_VERSION,
		"fixture_id": String(FIXTURE_ID),
		"operation_count": expected_count,
		"seed_count": 1,
		"body_count": bodies.size(),
		"path_samples_per_body": PATH_SAMPLE_COUNT,
		"signature": actual_signature,
	}


static func get_scaling_checkpoints(max_operation_count: int) -> PackedInt32Array:
	var normalized_max := clampi(
		max_operation_count,
		1,
		MAX_OPERATION_COUNT
	)
	var checkpoints := PackedInt32Array()
	for checkpoint: int in SCALING_CHECKPOINTS:
		if checkpoint <= normalized_max:
			checkpoints.append(checkpoint)
	if checkpoints.is_empty() or checkpoints[-1] != normalized_max:
		checkpoints.append(normalized_max)
	return checkpoints


static func build_fixture_signature(operation_count: int) -> String:
	var bodies := build_body_sequence(operation_count)
	return _calculate_body_list_signature(bodies)


static func calculate_state_signature(state: Resource) -> String:
	if state == null:
		return ""
	var bodies: Array = state.get("material_bodies") as Array
	var typed_bodies: Array[Resource] = []
	for body_variant: Variant in bodies:
		if body_variant is Resource:
			typed_bodies.append(body_variant as Resource)
	return _calculate_body_list_signature(typed_bodies)


static func _build_profile_body(
	operation_index: int,
	is_seed: bool
) -> Resource:
	var body: Resource = ForgeV2MaterialBodyScript.new()
	var body_serial := 0 if is_seed else operation_index + 1
	var path_points := _build_path_points(operation_index, is_seed)
	var normals := PackedVector3Array()
	var contacts := PackedVector3Array()
	for _point: Vector3 in path_points:
		normals.append(Vector3.BACK)
		contacts.append(Vector3.FORWARD)
	body.set(
		"body_id",
		StringName("benchmark_body_%04d" % body_serial)
	)
	body.set(
		"source_record_id",
		StringName("benchmark_command_%04d" % body_serial)
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
	body.set("profile_id", &"benchmark_asymmetric_profile_v1")
	body.set("profile_display_name", "Benchmark Asymmetric Profile V1")
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
	body.set("created_timestamp", FIXED_TIMESTAMP + float(body_serial))
	body.set("updated_timestamp", FIXED_TIMESTAMP + float(body_serial))
	body.call("normalize")
	body.set("body_id", StringName("benchmark_body_%04d" % body_serial))
	body.set(
		"source_record_id",
		StringName("benchmark_command_%04d" % body_serial)
	)
	body.set("created_timestamp", FIXED_TIMESTAMP + float(body_serial))
	body.set("updated_timestamp", FIXED_TIMESTAMP + float(body_serial))
	return body


static func _build_path_points(
	operation_index: int,
	is_seed: bool
) -> PackedVector3Array:
	var points := PackedVector3Array()
	var row := 0 if is_seed else operation_index % 10
	var layer := 0 if is_seed else int(operation_index / 10)
	var y_offset := 0.0 if is_seed else (float(row) - 4.5) * 0.006
	var z_offset := 0.0 if is_seed else (float(layer) - 4.5) * 0.004
	var x_min := -0.22 if is_seed else -0.20 + float(operation_index % 3) * 0.001
	var x_max := 0.22 if is_seed else 0.20 - float(operation_index % 4) * 0.001
	for point_index in range(PATH_SAMPLE_COUNT):
		var ratio := float(point_index) / float(PATH_SAMPLE_COUNT - 1)
		var point := Vector3(
			lerpf(x_min, x_max, ratio),
			y_offset,
			z_offset
		)
		points.append(point)
	if not is_seed and operation_index % 2 == 1:
		points.reverse()
	return points


static func _build_profile_polygon() -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(-0.020, -0.016),
		Vector2(0.026, -0.013),
		Vector2(0.033, 0.006),
		Vector2(0.009, 0.026),
		Vector2(-0.022, 0.018),
	])


static func _calculate_body_list_signature(bodies: Array[Resource]) -> String:
	var lines := PackedStringArray([
		"fixture_schema=%d" % FIXTURE_SCHEMA_VERSION,
		"fixture_id=%s" % String(FIXTURE_ID),
	])
	for body: Resource in bodies:
		lines.append(_build_body_signature(body))
	return "\n".join(lines).sha256_text()


static func _build_body_signature(body: Resource) -> String:
	if body == null:
		return "null"
	var parts := PackedStringArray([
		String(body.get("body_id")),
		String(body.get("material_variant_id")),
		String(body.get("operation_mode")),
		String(body.get("placement_policy")),
		String(body.get("shape_kind")),
	])
	var path_points: PackedVector3Array = body.get("path_points")
	for point: Vector3 in path_points:
		parts.append("P%.6f,%.6f,%.6f" % [point.x, point.y, point.z])
	var path_normals: PackedVector3Array = body.get("path_surface_normals")
	for normal: Vector3 in path_normals:
		parts.append("N%.6f,%.6f,%.6f" % [normal.x, normal.y, normal.z])
	var contact_directions: PackedVector3Array = body.get(
		"path_contact_directions"
	)
	for contact: Vector3 in contact_directions:
		parts.append("C%.6f,%.6f,%.6f" % [contact.x, contact.y, contact.z])
	var profile_polygon: PackedVector2Array = body.get(
		"profile_polygon_2d_meters"
	)
	for profile_point: Vector2 in profile_polygon:
		parts.append("S%.6f,%.6f" % [profile_point.x, profile_point.y])
	return "|".join(parts)


static func _rewrite_layer_delta_ids(layer: Resource) -> void:
	var ledger_delta: Dictionary = layer.get("ledger_delta") as Dictionary
	for material_id_variant: Variant in ledger_delta.keys():
		var material_id := StringName(material_id_variant)
		var entry: Dictionary = ledger_delta.get(material_id, {}) as Dictionary
		entry["layer_ids"] = [FIXTURE_LAYER_ID]
		ledger_delta[material_id] = entry
	layer.set("ledger_delta", ledger_delta)


static func _build_fixture_notes(
	operation_count: int,
	state: Resource
) -> String:
	return "\n".join(PackedStringArray([
		"Deterministic Forge V2 workpiece compiler benchmark fixture.",
		"Never insert this fixture into the live player WIP library.",
		"Seed count: 1 (not included in operation count).",
		"Accepted operation count: %d." % operation_count,
		"Path samples per body: %d." % PATH_SAMPLE_COUNT,
		"Fixture schema: %d." % FIXTURE_SCHEMA_VERSION,
		"Fixture signature: %s." % calculate_state_signature(state),
	]))


static func _file_size_bytes(path: String) -> int:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return -1
	var size := file.get_length()
	file.close()
	return size
