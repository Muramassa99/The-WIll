extends SceneTree

const ForgeV2AuthoringStateScript = preload("res://runtime/forge_v2/forge_v2_authoring_state.gd")
const ForgeV2MaterialBodyScript = preload("res://runtime/forge_v2/forge_v2_material_body.gd")
const ForgeV2MaterialVolumeResolverScript = preload("res://runtime/forge_v2/forge_v2_material_volume_resolver.gd")
const ForgeV2PrimitiveCatalogScript = preload("res://runtime/forge_v2/forge_v2_primitive_catalog.gd")
const ForgeV2VolumeStrokeScript = preload("res://runtime/forge_v2/forge_v2_volume_stroke.gd")

func _init() -> void:
	var lines: PackedStringArray = []
	var failed := false

	var low_amount_body: Resource = _build_test_body(0.05)
	var full_amount_body: Resource = _build_test_body(1.0)
	var body_amount_normalized := is_equal_approx(float(low_amount_body.get("amount_ratio")), 1.0)
	var body_volume_equal := is_equal_approx(
		float(low_amount_body.get("rough_volume_cell_equivalents")),
		float(full_amount_body.get("rough_volume_cell_equivalents"))
	)
	lines.append("body_amount_normalized=%s" % str(body_amount_normalized))
	lines.append("body_volume_equal=%s" % str(body_volume_equal))
	failed = failed or not body_amount_normalized or not body_volume_equal

	var stroke: Resource = ForgeV2VolumeStrokeScript.new()
	stroke.set("amount_ratio", 0.05)
	stroke.call("normalize")
	var legacy_stroke_amount_normalized := is_equal_approx(float(stroke.get("amount_ratio")), 1.0)
	lines.append("legacy_stroke_amount_normalized=%s" % str(legacy_stroke_amount_normalized))
	failed = failed or not legacy_stroke_amount_normalized

	var state: Resource = ForgeV2AuthoringStateScript.new()
	state.call("reset_new_draft", "Amount Consumption Verifier")
	state.call("set_amount_ratio", 0.05)
	var active_amount_normalized := is_equal_approx(float(state.get("active_amount_ratio")), 1.0)
	var point_body: Resource = state.call("append_point_material_body", Vector3.ZERO, 0.05, 0.05) as Resource
	var point_body_amount_normalized := point_body != null and is_equal_approx(float(point_body.get("amount_ratio")), 1.0)
	lines.append("active_amount_normalized=%s" % str(active_amount_normalized))
	lines.append("point_body_amount_normalized=%s" % str(point_body_amount_normalized))
	failed = failed or not active_amount_normalized or not point_body_amount_normalized

	var primitive_specs: Array[Dictionary] = ForgeV2PrimitiveCatalogScript.build_stroke_specs(
		ForgeV2PrimitiveCatalogScript.PRIMITIVE_PLATE,
		0.05,
		0.05
	)
	var primitive_specs_full_amount := true
	for primitive_spec: Dictionary in primitive_specs:
		if not is_equal_approx(float(primitive_spec.get("amount_ratio", 0.0)), 1.0):
			primitive_specs_full_amount = false
	lines.append("primitive_specs_full_amount=%s" % str(primitive_specs_full_amount))
	failed = failed or not primitive_specs_full_amount

	var resolver = ForgeV2MaterialVolumeResolverScript.new()
	var low_amount_resolved := float(resolver.call(
		"estimate_same_material_union_volume_cell_equivalents",
		[_build_test_body(0.05)]
	))
	var full_amount_resolved := float(resolver.call(
		"estimate_same_material_union_volume_cell_equivalents",
		[_build_test_body(1.0)]
	))
	var resolver_ignores_fill_ratio := is_equal_approx(low_amount_resolved, full_amount_resolved)
	lines.append("resolver_ignores_fill_ratio=%s" % str(resolver_ignores_fill_ratio))
	lines.append("resolved_volume_cell_equivalents=%s" % str(full_amount_resolved))
	failed = failed or not resolver_ignores_fill_ratio or full_amount_resolved <= 0.0

	var file: FileAccess = FileAccess.open("c:/WORKSPACE/godot_runs/verify_forge_v2_amount_consumption_model_results.txt", FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()

	quit(1 if failed else 0)

func _build_test_body(amount_ratio: float) -> Resource:
	var body: Resource = ForgeV2MaterialBodyScript.new()
	body.set("path_points", PackedVector3Array([
		Vector3.ZERO,
		Vector3(0.125, 0.0, 0.0),
	]))
	body.set("radius_meters", 0.05)
	body.set("amount_ratio", amount_ratio)
	body.call("normalize")
	return body
