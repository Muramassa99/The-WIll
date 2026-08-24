extends SceneTree

const ForgeV2AuthoringStateScript = preload(
	"res://runtime/forge_v2/forge_v2_authoring_state.gd"
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
const ForgeV2VolumeStrokeScript = preload(
	"res://runtime/forge_v2/forge_v2_volume_stroke.gd"
)

const RESULT_PATH := (
	"C:/WORKSPACE/godot_runs/"
	+ "verify_forge_v2_incremental_volume_cache_2026-08-10.txt"
)
const RELOAD_PATH := (
	"C:/WORKSPACE/godot_runs/"
	+ "verify_forge_v2_incremental_volume_cache_state.tres"
)
const VOLUME_EPSILON := 0.0001


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(RESULT_PATH.get_base_dir())
	var state: Resource = ForgeV2AuthoringStateScript.new()
	state.call("reset_new_draft", "Incremental Volume Cache Verify")

	_commit_path(
		state,
		&"mat_iron_gray",
		0.05,
		ForgeV2VolumeStrokeScript.OPERATION_ADD_MATERIAL,
		ForgeV2VolumeStrokeScript.PLACEMENT_REPLACE_EXISTING,
		Vector3(0.0, 0.0, 0.0),
		Vector3(0.24, 0.0, 0.0)
	)
	_assert_cache_mode(state, false, true, 1, "first commit")
	_assert_ledger_matches_fresh(state, "first commit")

	_commit_path(
		state,
		&"mat_copper",
		0.05,
		ForgeV2VolumeStrokeScript.OPERATION_ADD_MATERIAL,
		ForgeV2VolumeStrokeScript.PLACEMENT_REPLACE_EXISTING,
		Vector3(0.30, 0.0, 0.0),
		Vector3(0.52, 0.0, 0.0)
	)
	_assert_cache_mode(state, true, false, 1, "same-basis append")
	_assert_ledger_matches_fresh(state, "same-basis append")

	_commit_path(
		state,
		&"mat_bronze",
		0.0125,
		ForgeV2VolumeStrokeScript.OPERATION_ADD_MATERIAL,
		ForgeV2VolumeStrokeScript.PLACEMENT_REPLACE_EXISTING,
		Vector3(0.08, 0.0, 0.0),
		Vector3(0.38, 0.0, 0.0)
	)
	_assert_cache_mode(state, false, true, 3, "smaller-radius rebase")
	var rebase_diagnostics := _get_cache_diagnostics(state)
	_require(
		StringName(rebase_diagnostics.get("invalidation_reason", StringName()))
		== &"sample_basis_changed",
		"smaller-radius commit did not report a sampling-basis rebase"
	)
	_assert_ledger_matches_fresh(state, "smaller-radius rebase")

	_commit_path(
		state,
		&"mat_iron_gray",
		0.025,
		ForgeV2VolumeStrokeScript.OPERATION_ADD_MATERIAL,
		ForgeV2VolumeStrokeScript.PLACEMENT_EMPTY_ONLY,
		Vector3(0.18, 0.04, 0.0),
		Vector3(0.48, 0.04, 0.0)
	)
	_assert_cache_mode(state, true, false, 1, "post-rebase append")
	_assert_ledger_matches_fresh(state, "post-rebase empty-only")

	var handle_body := _append_handle_body(
		state,
		&"mat_wood_gray",
		Vector3(0.12, 0.0, 0.0),
		Vector3(0.34, 0.0, 0.0),
		0.025
	)
	_commit_existing_body(state, handle_body)
	_assert_cache_mode(state, true, false, 1, "protected Handle append")
	_assert_ledger_matches_fresh(state, "protected Handle append")

	_commit_path(
		state,
		&"mat_copper",
		0.025,
		ForgeV2VolumeStrokeScript.OPERATION_ADD_MATERIAL,
		ForgeV2VolumeStrokeScript.PLACEMENT_REPLACE_EXISTING,
		Vector3(0.10, 0.0, 0.0),
		Vector3(0.36, 0.0, 0.0)
	)
	_assert_ledger_matches_fresh(state, "replace across protected Handle")

	_commit_path(
		state,
		&"mat_bronze",
		0.025,
		ForgeV2VolumeStrokeScript.OPERATION_ADD_MATERIAL,
		ForgeV2VolumeStrokeScript.PLACEMENT_EMPTY_ONLY,
		Vector3(0.08, 0.03, 0.0),
		Vector3(0.42, 0.03, 0.0)
	)
	_assert_ledger_matches_fresh(state, "empty-only across mixed material")

	_commit_path(
		state,
		&"mat_iron_gray",
		0.025,
		ForgeV2VolumeStrokeScript.OPERATION_REMOVE_MATERIAL,
		ForgeV2VolumeStrokeScript.PLACEMENT_REPLACE_EXISTING,
		Vector3(0.06, 0.0, 0.0),
		Vector3(0.40, 0.0, 0.0)
	)
	_assert_cache_mode(state, true, false, 1, "VOID across protected Handle")
	_assert_ledger_matches_fresh(state, "VOID across protected Handle")
	var protected_summary := state.call("get_material_ledger_summary") as Dictionary
	var protected_materials: Dictionary = protected_summary.get(
		"materials",
		{}
	) as Dictionary
	_require(
		protected_materials.has(&"mat_wood_gray"),
		"VOID or Replace consumed protected Handle occupancy"
	)

	_require(bool(state.call("undo_latest_layer")), "undo failed")
	_require(
		not bool(_get_cache_diagnostics(state).get("cache_valid", true)),
		"undo did not invalidate the committed-volume cache"
	)
	_require(bool(state.call("redo_latest_layer")), "redo failed")
	_require(
		not bool(_get_cache_diagnostics(state).get("cache_valid", true)),
		"redo did not leave the committed-volume cache invalidated"
	)
	_commit_path(
		state,
		&"mat_iron_gray",
		0.025,
		ForgeV2VolumeStrokeScript.OPERATION_ADD_MATERIAL,
		ForgeV2VolumeStrokeScript.PLACEMENT_EMPTY_ONLY,
		Vector3(0.55, 0.0, 0.0),
		Vector3(0.68, 0.0, 0.0)
	)
	_assert_cache_mode(
		state,
		false,
		true,
		(state.get("forge_layers") as Array).size(),
		"first commit after undo/redo"
	)
	_assert_ledger_matches_fresh(state, "first commit after undo/redo")

	var save_error := ResourceSaver.save(state, RELOAD_PATH)
	_require(save_error == OK, "failed to save reload fixture: %s" % save_error)
	var loaded_state := ResourceLoader.load(
		RELOAD_PATH,
		"",
		ResourceLoader.CACHE_MODE_IGNORE
	) as Resource
	_require(loaded_state != null, "failed to reload authoring state")
	loaded_state.call("normalize")
	_require(
		not bool(_get_cache_diagnostics(loaded_state).get("cache_valid", true)),
		"disk reload unexpectedly retained transient occupancy"
	)
	_commit_path(
		loaded_state,
		&"mat_copper",
		0.025,
		ForgeV2VolumeStrokeScript.OPERATION_ADD_MATERIAL,
		ForgeV2VolumeStrokeScript.PLACEMENT_EMPTY_ONLY,
		Vector3(0.70, 0.0, 0.0),
		Vector3(0.82, 0.0, 0.0)
	)
	_assert_cache_mode(
		loaded_state,
		false,
		true,
		(loaded_state.get("forge_layers") as Array).size(),
		"first commit after disk reload"
	)
	_assert_ledger_matches_fresh(loaded_state, "first commit after disk reload")
	DirAccess.remove_absolute(RELOAD_PATH)

	_write_result([
		"ok=true",
		"first_commit_full_rebuild=true",
		"same_basis_new_only=true",
		"smaller_radius_one_rebuild=true",
		"post_rebase_new_only=true",
		"replace_empty_void_equivalent=true",
		"protected_handle_equivalent=true",
		"ledger_matches_stateless_and_fresh=true",
		"undo_redo_invalidates=true",
		"disk_reload_cache_absent=true",
		"cache_is_bounded=true",
	])
	quit(0)


func _commit_path(
	state: Resource,
	material_variant_id: StringName,
	radius_meters: float,
	operation_mode: StringName,
	placement_policy: StringName,
	from_point: Vector3,
	to_point: Vector3
) -> void:
	state.call("set_active_material_variant_id", material_variant_id)
	state.call("set_brush_radius_meters", radius_meters)
	state.call("set_active_operation_mode", operation_mode)
	state.call("set_placement_policy", placement_policy)
	var body: Resource = state.call(
		"append_point_material_body",
		from_point,
		radius_meters,
		1.0,
		Vector3.UP
	) as Resource
	_require(body != null, "failed to create %s body" % String(material_variant_id))
	var body_id := StringName(body.get("body_id"))
	_require(
		bool(state.call(
			"append_point_to_material_body",
			body_id,
			to_point,
			0.0,
			true,
			Vector3.UP
		)),
		"failed to append body endpoint"
	)
	_commit_existing_body(state, body)


func _append_handle_body(
	state: Resource,
	material_variant_id: StringName,
	from_point: Vector3,
	to_point: Vector3,
	radius_meters: float
) -> Resource:
	var body: Resource = ForgeV2MaterialBodyScript.new()
	body.set("body_kind", ForgeV2MaterialBodyScript.BODY_KIND_HANDLE_PROFILE)
	body.set("material_variant_id", material_variant_id)
	body.set("shape_kind", ForgeV2MaterialBodyScript.SHAPE_KIND_CAPSULE_PATH)
	body.set("path_points", PackedVector3Array([from_point, to_point]))
	body.set("path_surface_normals", PackedVector3Array([Vector3.UP, Vector3.UP]))
	body.set("radius_meters", radius_meters)
	body.set("created_timestamp", Time.get_unix_time_from_system())
	body.call("normalize")
	var state_bodies: Array[Resource] = state.get("material_bodies") as Array[Resource]
	state_bodies.append(body)
	state.set("material_bodies", state_bodies)
	return body


func _commit_existing_body(state: Resource, body: Resource) -> void:
	_require(body != null, "cannot commit a null body")
	var body_id := StringName(body.get("body_id"))
	_require(body_id != StringName(), "body has no identity")
	_require(
		state.call("commit_material_body_as_layer", body_id) != null,
		"failed to commit body %s" % String(body_id)
	)


func _get_cache_diagnostics(state: Resource) -> Dictionary:
	return state.call("get_committed_volume_cache_diagnostics") as Dictionary


func _assert_cache_mode(
	state: Resource,
	expected_reuse: bool,
	expected_full_rebuild: bool,
	expected_sampled_body_count: int,
	context: String
) -> void:
	var diagnostics := _get_cache_diagnostics(state)
	_require(
		bool(diagnostics.get("cache_reused", not expected_reuse))
		== expected_reuse,
		"%s cache reuse mode drifted: %s" % [context, diagnostics]
	)
	_require(
		bool(diagnostics.get("full_rebuild", not expected_full_rebuild))
		== expected_full_rebuild,
		"%s rebuild mode drifted: %s" % [context, diagnostics]
	)
	_require(
		int(diagnostics.get("sampled_body_count", -1))
		== expected_sampled_body_count,
		"%s sampled %s bodies instead of %s: %s" % [
			context,
			str(diagnostics.get("sampled_body_count", -1)),
			str(expected_sampled_body_count),
			diagnostics,
		]
	)
	_require(
		bool(diagnostics.get("cache_retained", false)),
		"%s unexpectedly exceeded the bounded test cache" % context
	)
	_require(
		int(diagnostics.get("cache_cell_limit", 0)) > 0,
		"%s did not expose a finite cache bound" % context
	)


func _assert_ledger_matches_fresh(state: Resource, context: String) -> void:
	var committed_bodies: Array = state.call(
		"_collect_committed_active_user_material_bodies"
	) as Array
	var resolver = ForgeV2MaterialVolumeResolverScript.new()
	var authoritative_summary: Dictionary = resolver.call(
		"build_usage_summary",
		committed_bodies
	) as Dictionary
	var incremental_summary: Dictionary = state.call(
		"get_material_ledger_summary"
	) as Dictionary
	_assert_summaries_match(
		incremental_summary,
		authoritative_summary,
		"%s incremental ledger" % context
	)
	var rebuilt_ledger: Resource = ForgeV2MaterialLedgerScript.new()
	var layers: Array[Resource] = []
	for layer_variant: Variant in state.get("forge_layers") as Array:
		if layer_variant is Resource:
			layers.append(layer_variant as Resource)
	rebuilt_ledger.call("rebuild_from_layers", layers)
	_assert_summaries_match(
		incremental_summary,
		rebuilt_ledger.call("get_summary") as Dictionary,
		"%s fresh layer replay" % context
	)


func _assert_summaries_match(
	actual: Dictionary,
	expected: Dictionary,
	context: String
) -> void:
	_require(
		int(actual.get("total_rough_material_centi_units", -1))
		== int(expected.get("total_rough_material_centi_units", -2)),
		"%s centi-unit total drifted" % context
	)
	_require(
		absf(
			float(actual.get("total_rough_volume_cell_equivalents", -1.0))
			- float(expected.get("total_rough_volume_cell_equivalents", -2.0))
		) <= VOLUME_EPSILON,
		"%s volume total drifted" % context
	)
	var actual_materials: Dictionary = actual.get("materials", {}) as Dictionary
	var expected_materials: Dictionary = expected.get("materials", {}) as Dictionary
	_require(
		actual_materials.size() == expected_materials.size(),
		"%s material key count drifted" % context
	)
	for material_variant: Variant in expected_materials.keys():
		var material_variant_id := StringName(material_variant)
		_require(
			actual_materials.has(material_variant_id),
			"%s lost material %s" % [context, String(material_variant_id)]
		)
		var actual_entry: Dictionary = actual_materials[material_variant_id]
		var expected_entry: Dictionary = expected_materials[material_variant_id]
		_require(
			int(actual_entry.get("rough_material_centi_units", -1))
			== int(expected_entry.get("rough_material_centi_units", -2)),
			"%s material centi units drifted for %s" % [
				context,
				String(material_variant_id),
			]
		)
		_require(
			absf(
				float(actual_entry.get("rough_volume_cell_equivalents", -1.0))
				- float(expected_entry.get(
					"rough_volume_cell_equivalents",
					-2.0
				))
			) <= VOLUME_EPSILON,
			"%s material volume drifted for %s" % [
				context,
				String(material_variant_id),
			]
		)


func _require(condition: bool, message: String) -> void:
	if condition:
		return
	_write_result(["ok=false", "error=%s" % message])
	push_error(message)
	quit(1)


func _write_result(lines: Array[String]) -> void:
	DirAccess.make_dir_recursive_absolute(RESULT_PATH.get_base_dir())
	var file := FileAccess.open(RESULT_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines) + "\n")
