extends SceneTree

const ForgeV2AuthoringStateScript = preload(
	"res://runtime/forge_v2/forge_v2_authoring_state.gd"
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
	+ "verify_forge_v2_incremental_material_ledger_2026-08-10.txt"
)
const VOLUME_EPSILON := 0.0001


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(RESULT_PATH.get_base_dir())
	var state: Resource = ForgeV2AuthoringStateScript.new()
	state.call("reset_new_draft", "Incremental Ledger Verify")

	_commit_path(
		state,
		&"mat_iron_gray",
		0.05,
		ForgeV2VolumeStrokeScript.OPERATION_ADD_MATERIAL,
		ForgeV2VolumeStrokeScript.PLACEMENT_REPLACE_EXISTING,
		Vector3(0.0, 0.0, 0.0),
		Vector3(0.30, 0.0, 0.0)
	)
	_assert_ledger_matches_fresh(state, "large-radius add")

	# This forces the resolver from its 0.025 m sampling ceiling down to the
	# 0.0125 m basis. Incremental totals must still equal a fresh full replay.
	_commit_path(
		state,
		&"mat_copper",
		0.0125,
		ForgeV2VolumeStrokeScript.OPERATION_ADD_MATERIAL,
		ForgeV2VolumeStrokeScript.PLACEMENT_REPLACE_EXISTING,
		Vector3(0.08, 0.0, 0.0),
		Vector3(0.24, 0.0, 0.0)
	)
	_assert_ledger_matches_fresh(state, "mixed-radius replacement")

	_commit_path(
		state,
		&"mat_bronze",
		0.025,
		ForgeV2VolumeStrokeScript.OPERATION_ADD_MATERIAL,
		ForgeV2VolumeStrokeScript.PLACEMENT_EMPTY_ONLY,
		Vector3(0.18, 0.0, 0.0),
		Vector3(0.38, 0.0, 0.0)
	)
	_assert_ledger_matches_fresh(state, "empty-only add")

	_commit_path(
		state,
		&"mat_iron_gray",
		0.025,
		ForgeV2VolumeStrokeScript.OPERATION_REMOVE_MATERIAL,
		ForgeV2VolumeStrokeScript.PLACEMENT_REPLACE_EXISTING,
		Vector3(-0.04, 0.0, 0.0),
		Vector3(0.16, 0.0, 0.0)
	)
	_assert_ledger_matches_fresh(state, "VOID removal")

	var stale_ledger: Resource = state.get("material_ledger") as Resource
	_require(stale_ledger != null, "state lost its material ledger")
	stale_ledger.set("material_totals", {
		&"mat_stale_policy": {
			"material_variant_id": &"mat_stale_policy",
			"rough_volume_cell_equivalents": 999999.0,
			"rough_material_centi_units": 999999,
		},
	})
	stale_ledger.set("total_rough_volume_cell_equivalents", 999999.0)
	stale_ledger.set("total_rough_material_centi_units", 999999)
	state.set("schema_version", 2)
	state.call("normalize")
	_assert_ledger_matches_fresh(state, "old-schema ledger migration")

	_write_result([
		"ok=true",
		"mixed_radius_basis_reconciled=true",
		"replace_policy_equivalent=true",
		"empty_only_policy_equivalent=true",
		"void_policy_equivalent=true",
		"zero_material_entries_pruned=true",
		"material_ratios_equivalent=true",
		"old_schema_ledger_rebuilt=true",
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
	_require(body_id != StringName(), "created body has no identity")
	_require(
		bool(state.call(
			"append_point_to_material_body",
			body_id,
			to_point,
			0.0,
			true,
			Vector3.UP
		)),
		"failed to append the body endpoint"
	)
	_require(
		state.call("commit_material_body_as_layer", body_id) != null,
		"failed to commit the material body"
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
	var forge_layers: Array[Resource] = []
	for layer_variant: Variant in state.get("forge_layers") as Array:
		if layer_variant is Resource:
			forge_layers.append(layer_variant as Resource)
	rebuilt_ledger.call("rebuild_from_layers", forge_layers)
	var rebuilt_summary: Dictionary = rebuilt_ledger.call("get_summary") as Dictionary
	_assert_summaries_match(
		incremental_summary,
		rebuilt_summary,
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
				- float(expected_entry.get("rough_volume_cell_equivalents", -2.0))
			) <= VOLUME_EPSILON,
			"%s material volume drifted for %s" % [
				context,
				String(material_variant_id),
			]
		)
		_require(
			absf(
				float(actual_entry.get("ratio", -1.0))
				- float(expected_entry.get("ratio", -2.0))
			) <= 0.000001,
			"%s material ratio drifted for %s" % [
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
