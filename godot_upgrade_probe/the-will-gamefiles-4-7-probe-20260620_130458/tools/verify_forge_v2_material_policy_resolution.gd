extends SceneTree

const ForgeV2AuthoringStateScript = preload("res://runtime/forge_v2/forge_v2_authoring_state.gd")
const ForgeV2MaterialBodyScript = preload("res://runtime/forge_v2/forge_v2_material_body.gd")
const ForgeV2MaterialVolumeResolverScript = preload("res://runtime/forge_v2/forge_v2_material_volume_resolver.gd")
const ForgeV2VolumePreviewPresenterScript = preload("res://runtime/forge_v2/forge_v2_volume_preview_presenter.gd")
const ForgeV2VolumeStrokeScript = preload("res://runtime/forge_v2/forge_v2_volume_stroke.gd")

const MATERIAL_IRON := &"mat_iron_gray"
const MATERIAL_COPPER := &"mat_copper_gray"
const TEST_RADIUS_METERS := 0.05

func _init() -> void:
	var resolver = ForgeV2MaterialVolumeResolverScript.new()
	var single_iron_summary: Dictionary = resolver.call("build_usage_summary", [
		_build_body(MATERIAL_IRON, ForgeV2VolumeStrokeScript.PLACEMENT_REPLACE_EXISTING),
	]) as Dictionary
	var single_iron_volume := _material_volume(single_iron_summary, MATERIAL_IRON)

	var replace_summary: Dictionary = resolver.call("build_usage_summary", [
		_build_body(MATERIAL_IRON, ForgeV2VolumeStrokeScript.PLACEMENT_REPLACE_EXISTING),
		_build_body(MATERIAL_COPPER, ForgeV2VolumeStrokeScript.PLACEMENT_REPLACE_EXISTING),
	]) as Dictionary
	var replace_removes_old_material := is_zero_approx(_material_volume(replace_summary, MATERIAL_IRON))
	var replace_keeps_new_material := _material_volume(replace_summary, MATERIAL_COPPER) > 0.0

	var empty_only_summary: Dictionary = resolver.call("build_usage_summary", [
		_build_body(MATERIAL_IRON, ForgeV2VolumeStrokeScript.PLACEMENT_REPLACE_EXISTING),
		_build_body(MATERIAL_COPPER, ForgeV2VolumeStrokeScript.PLACEMENT_EMPTY_ONLY),
	]) as Dictionary
	var empty_only_keeps_existing_material := is_equal_approx(
		_material_volume(empty_only_summary, MATERIAL_IRON),
		single_iron_volume
	)
	var empty_only_blocks_new_overlap := is_zero_approx(_material_volume(empty_only_summary, MATERIAL_COPPER))

	var same_material_summary: Dictionary = resolver.call("build_usage_summary", [
		_build_body(MATERIAL_IRON, ForgeV2VolumeStrokeScript.PLACEMENT_REPLACE_EXISTING),
		_build_body(MATERIAL_IRON, ForgeV2VolumeStrokeScript.PLACEMENT_REPLACE_EXISTING),
	]) as Dictionary
	var same_material_overlap_not_double_counted := is_equal_approx(
		_material_volume(same_material_summary, MATERIAL_IRON),
		single_iron_volume
	)

	var replace_ledger_summary := _build_two_layer_ledger_summary(ForgeV2VolumeStrokeScript.PLACEMENT_REPLACE_EXISTING)
	var ledger_replace_removes_old_material := is_zero_approx(_material_volume(replace_ledger_summary, MATERIAL_IRON))
	var ledger_replace_keeps_new_material := _material_volume(replace_ledger_summary, MATERIAL_COPPER) > 0.0
	var replace_second_layer_delta: Dictionary = _build_two_layer_second_layer_delta(ForgeV2VolumeStrokeScript.PLACEMENT_REPLACE_EXISTING)
	var layer_delta_replace_subtracts_old_material := _material_delta_centi_units(replace_second_layer_delta, MATERIAL_IRON) < 0
	var layer_delta_replace_adds_new_material := _material_delta_centi_units(replace_second_layer_delta, MATERIAL_COPPER) > 0

	var empty_only_ledger_summary := _build_two_layer_ledger_summary(ForgeV2VolumeStrokeScript.PLACEMENT_EMPTY_ONLY)
	var ledger_empty_only_keeps_existing_material := is_equal_approx(
		_material_volume(empty_only_ledger_summary, MATERIAL_IRON),
		single_iron_volume
	)
	var ledger_empty_only_blocks_new_overlap := is_zero_approx(_material_volume(empty_only_ledger_summary, MATERIAL_COPPER))
	var empty_only_second_layer_delta: Dictionary = _build_two_layer_second_layer_delta(ForgeV2VolumeStrokeScript.PLACEMENT_EMPTY_ONLY)
	var layer_delta_empty_only_no_material_change := empty_only_second_layer_delta.is_empty()

	var presenter := ForgeV2VolumePreviewPresenterScript.new()
	var replace_visual_groups: Dictionary = presenter.call("_collect_csg_material_body_groups", _build_authoring_state_with_bodies([
		_build_body(MATERIAL_IRON, ForgeV2VolumeStrokeScript.PLACEMENT_REPLACE_EXISTING),
		_build_body(MATERIAL_COPPER, ForgeV2VolumeStrokeScript.PLACEMENT_REPLACE_EXISTING),
	])) as Dictionary
	var replace_visual_old_material_clipped := _first_group_clip_count(replace_visual_groups, MATERIAL_IRON) >= 1

	var empty_visual_groups: Dictionary = presenter.call("_collect_csg_material_body_groups", _build_authoring_state_with_bodies([
		_build_body(MATERIAL_IRON, ForgeV2VolumeStrokeScript.PLACEMENT_REPLACE_EXISTING),
		_build_body(MATERIAL_COPPER, ForgeV2VolumeStrokeScript.PLACEMENT_EMPTY_ONLY),
	])) as Dictionary
	var empty_visual_new_material_clipped := _first_group_clip_count(empty_visual_groups, MATERIAL_COPPER) >= 1
	presenter.free()

	var csg_presenter := ForgeV2VolumePreviewPresenterScript.new()
	csg_presenter.call("_sync_csg_material_body_preview", _build_authoring_state_with_bodies([
		_build_body(MATERIAL_IRON, ForgeV2VolumeStrokeScript.PLACEMENT_REPLACE_EXISTING),
		_build_body(MATERIAL_COPPER, ForgeV2VolumeStrokeScript.PLACEMENT_REPLACE_EXISTING),
	]))
	var csg_preview_created := csg_presenter.csg_material_body_root != null and csg_presenter.csg_material_body_root.get_child_count() >= 2
	csg_presenter.free()

	var lines: PackedStringArray = []
	lines.append("replace_removes_old_material=%s" % str(replace_removes_old_material))
	lines.append("replace_keeps_new_material=%s" % str(replace_keeps_new_material))
	lines.append("empty_only_keeps_existing_material=%s" % str(empty_only_keeps_existing_material))
	lines.append("empty_only_blocks_new_overlap=%s" % str(empty_only_blocks_new_overlap))
	lines.append("same_material_overlap_not_double_counted=%s" % str(same_material_overlap_not_double_counted))
	lines.append("ledger_replace_removes_old_material=%s" % str(ledger_replace_removes_old_material))
	lines.append("ledger_replace_keeps_new_material=%s" % str(ledger_replace_keeps_new_material))
	lines.append("layer_delta_replace_subtracts_old_material=%s" % str(layer_delta_replace_subtracts_old_material))
	lines.append("layer_delta_replace_adds_new_material=%s" % str(layer_delta_replace_adds_new_material))
	lines.append("ledger_empty_only_keeps_existing_material=%s" % str(ledger_empty_only_keeps_existing_material))
	lines.append("ledger_empty_only_blocks_new_overlap=%s" % str(ledger_empty_only_blocks_new_overlap))
	lines.append("layer_delta_empty_only_no_material_change=%s" % str(layer_delta_empty_only_no_material_change))
	lines.append("replace_visual_old_material_clipped=%s" % str(replace_visual_old_material_clipped))
	lines.append("empty_visual_new_material_clipped=%s" % str(empty_visual_new_material_clipped))
	lines.append("csg_preview_created=%s" % str(csg_preview_created))
	lines.append("single_iron_volume=%s" % str(single_iron_volume))
	lines.append("replace_summary=%s" % str(replace_summary))
	lines.append("empty_only_summary=%s" % str(empty_only_summary))
	lines.append("replace_visual_groups=%s" % str(replace_visual_groups))
	lines.append("empty_visual_groups=%s" % str(empty_visual_groups))

	var failed := (
		not replace_removes_old_material
		or not replace_keeps_new_material
		or not empty_only_keeps_existing_material
		or not empty_only_blocks_new_overlap
		or not same_material_overlap_not_double_counted
		or not ledger_replace_removes_old_material
		or not ledger_replace_keeps_new_material
		or not layer_delta_replace_subtracts_old_material
		or not layer_delta_replace_adds_new_material
		or not ledger_empty_only_keeps_existing_material
		or not ledger_empty_only_blocks_new_overlap
		or not layer_delta_empty_only_no_material_change
		or not replace_visual_old_material_clipped
		or not empty_visual_new_material_clipped
		or not csg_preview_created
	)
	var file: FileAccess = FileAccess.open("c:/WORKSPACE/godot_runs/verify_forge_v2_material_policy_resolution_results.txt", FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()
	quit(1 if failed else 0)

func _build_body(
	material_variant_id: StringName,
	placement_policy: StringName,
	operation_mode: StringName = ForgeV2VolumeStrokeScript.OPERATION_ADD_MATERIAL
) -> Resource:
	var body: Resource = ForgeV2MaterialBodyScript.new()
	body.set("material_variant_id", material_variant_id)
	body.set("operation_mode", operation_mode)
	body.set("placement_policy", placement_policy)
	body.set("radius_meters", TEST_RADIUS_METERS)
	body.set("path_points", PackedVector3Array([Vector3.ZERO]))
	body.call("normalize")
	return body

func _build_authoring_state_with_bodies(material_body_values: Array) -> Resource:
	var authoring_state: Resource = ForgeV2AuthoringStateScript.new()
	authoring_state.call("reset_new_draft", "Material Policy Visual Verifier")
	var material_bodies: Array[Resource] = []
	for material_body_value: Variant in material_body_values:
		if material_body_value is Resource:
			material_bodies.append(material_body_value as Resource)
	authoring_state.set("material_bodies", material_bodies)
	authoring_state.call("normalize")
	return authoring_state

func _build_two_layer_ledger_summary(second_layer_policy: StringName) -> Dictionary:
	var authoring_state: Resource = _build_two_layer_state(second_layer_policy)
	return authoring_state.call("get_material_ledger_summary") as Dictionary

func _build_two_layer_second_layer_delta(second_layer_policy: StringName) -> Dictionary:
	var authoring_state: Resource = _build_two_layer_state(second_layer_policy)
	var forge_layers: Array = authoring_state.get("forge_layers") as Array
	if forge_layers.size() < 2:
		return {}
	var second_layer: Resource = forge_layers[1] as Resource
	return second_layer.get("ledger_delta") as Dictionary

func _build_two_layer_state(second_layer_policy: StringName) -> Resource:
	var authoring_state: Resource = ForgeV2AuthoringStateScript.new()
	authoring_state.call("reset_new_draft", "Material Policy Ledger Verifier")
	authoring_state.call("set_active_material_variant_id", MATERIAL_IRON)
	authoring_state.call("set_placement_policy", ForgeV2VolumeStrokeScript.PLACEMENT_REPLACE_EXISTING)
	authoring_state.call("append_point_material_body", Vector3.ZERO, TEST_RADIUS_METERS)
	authoring_state.call("commit_pending_material_bodies_as_layer")
	authoring_state.call("set_active_material_variant_id", MATERIAL_COPPER)
	authoring_state.call("set_placement_policy", second_layer_policy)
	authoring_state.call("append_point_material_body", Vector3.ZERO, TEST_RADIUS_METERS)
	authoring_state.call("commit_pending_material_bodies_as_layer")
	return authoring_state

func _material_volume(summary: Dictionary, material_variant_id: StringName) -> float:
	var materials: Dictionary = summary.get("materials", {}) as Dictionary
	var entry: Dictionary = materials.get(material_variant_id, {}) as Dictionary
	return float(entry.get("rough_volume_cell_equivalents", 0.0))

func _material_delta_centi_units(ledger_delta: Dictionary, material_variant_id: StringName) -> int:
	var entry: Dictionary = ledger_delta.get(material_variant_id, {}) as Dictionary
	return int(entry.get("rough_material_centi_units", 0))

func _first_group_clip_count(material_groups: Dictionary, material_variant_id: StringName) -> int:
	var group_record: Dictionary = material_groups.get(material_variant_id, {}) as Dictionary
	var body_records: Array = group_record.get("body_records", []) as Array
	if body_records.is_empty() or not (body_records[0] is Dictionary):
		return 0
	var body_record: Dictionary = body_records[0] as Dictionary
	var clip_bodies: Array = body_record.get("clip_bodies", []) as Array
	return clip_bodies.size()
