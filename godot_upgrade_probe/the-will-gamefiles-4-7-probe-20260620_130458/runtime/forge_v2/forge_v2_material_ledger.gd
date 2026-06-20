extends Resource
class_name ForgeV2MaterialLedger

const ForgeV2MaterialVolumeResolverScript = preload("res://runtime/forge_v2/forge_v2_material_volume_resolver.gd")

@export var material_totals: Dictionary = {}
@export var removed_material_records: Array[Dictionary] = []
@export var total_rough_material_centi_units: int = 0
@export var total_rough_volume_cell_equivalents: float = 0.0
@export var updated_timestamp: float = 0.0

func reset() -> void:
	material_totals = {}
	removed_material_records = []
	total_rough_material_centi_units = 0
	total_rough_volume_cell_equivalents = 0.0
	updated_timestamp = Time.get_unix_time_from_system()

func rebuild_from_layers(layers: Array[Resource]) -> void:
	reset()
	var input_shape_records: Array = []
	for layer: Resource in layers:
		if layer == null:
			continue
		if layer.has_method("normalize"):
			layer.call("normalize")
		var layer_input_records: Array = layer.get("input_shape_records") as Array
		for record: Variant in layer_input_records:
			if not (record is Dictionary):
				continue
			var input_record: Dictionary = (record as Dictionary).duplicate(true)
			input_record["layer_id"] = StringName(layer.get("layer_id"))
			input_shape_records.append(input_record)
		var layer_removed_records: Array = layer.get("removed_material_records") as Array
		for removed_record: Variant in layer_removed_records:
			if removed_record is Dictionary:
				removed_material_records.append(removed_record)
	var resolver = ForgeV2MaterialVolumeResolverScript.new()
	var usage_summary: Dictionary = resolver.call("build_usage_summary", input_shape_records) as Dictionary
	material_totals = usage_summary.get("materials", {}) as Dictionary
	total_rough_material_centi_units = int(usage_summary.get("total_rough_material_centi_units", 0))
	total_rough_volume_cell_equivalents = float(usage_summary.get("total_rough_volume_cell_equivalents", 0.0))
	updated_timestamp = Time.get_unix_time_from_system()

func apply_layer(layer: Resource) -> void:
	if layer == null:
		return
	if layer.has_method("normalize"):
		layer.call("normalize")
	var ledger_delta: Dictionary = layer.get("ledger_delta") as Dictionary
	for material_variant_id: StringName in ledger_delta.keys():
		var delta_entry: Dictionary = ledger_delta.get(material_variant_id, {}) as Dictionary
		_apply_material_delta(material_variant_id, delta_entry, StringName(layer.get("layer_id")))
	var layer_removed_records: Array = layer.get("removed_material_records") as Array
	for removed_record: Variant in layer_removed_records:
		if removed_record is Dictionary:
			removed_material_records.append(removed_record)

func get_summary() -> Dictionary:
	var normalized_materials: Dictionary = {}
	for material_variant_id: StringName in material_totals.keys():
		var entry: Dictionary = material_totals[material_variant_id]
		var centi_units: int = maxi(int(entry.get("rough_material_centi_units", 0)), 0)
		var volume_cell_equivalents: float = maxf(float(entry.get("rough_volume_cell_equivalents", 0.0)), 0.0)
		entry["rough_material_centi_units"] = centi_units
		entry["rough_material_units"] = float(centi_units) / 100.0
		entry["rough_volume_cell_equivalents"] = volume_cell_equivalents
		normalized_materials[material_variant_id] = entry
	return {
		"total_rough_material_centi_units": total_rough_material_centi_units,
		"total_rough_material_units": float(total_rough_material_centi_units) / 100.0,
		"total_rough_volume_cell_equivalents": total_rough_volume_cell_equivalents,
		"materials": normalized_materials,
		"removed_material_records": removed_material_records,
		"removed_material_record_count": removed_material_records.size(),
	}

func get_summary_label() -> String:
	var summary: Dictionary = get_summary()
	var parts: PackedStringArray = []
	parts.append("Ledger material: %.2f units" % float(summary.get("total_rough_material_units", 0.0)))
	var materials: Dictionary = summary.get("materials", {}) as Dictionary
	for material_variant_id: StringName in materials.keys():
		var entry: Dictionary = materials[material_variant_id]
		var material_units: float = float(entry.get("rough_material_units", 0.0))
		if material_units <= 0.0:
			continue
		parts.append("%s %.2f" % [String(material_variant_id), material_units])
	var removed_count: int = int(summary.get("removed_material_record_count", 0))
	if removed_count > 0:
		parts.append("VOID cuts: %d rough records" % removed_count)
	return "\n".join(parts)

func _apply_material_delta(material_variant_id: StringName, delta_entry: Dictionary, layer_id: StringName) -> void:
	var centi_units: int = int(delta_entry.get("rough_material_centi_units", 0))
	var volume_cell_equivalents: float = float(delta_entry.get("rough_volume_cell_equivalents", 0.0))
	var total_entry: Dictionary = material_totals.get(material_variant_id, {
		"material_variant_id": material_variant_id,
		"rough_volume_cell_equivalents": 0.0,
		"rough_material_centi_units": 0,
		"rough_material_units": 0.0,
		"layer_ids": [],
	}) as Dictionary
	total_entry["rough_volume_cell_equivalents"] = float(total_entry.get("rough_volume_cell_equivalents", 0.0)) + volume_cell_equivalents
	total_entry["rough_material_centi_units"] = int(total_entry.get("rough_material_centi_units", 0)) + centi_units
	total_entry["rough_material_units"] = float(int(total_entry.get("rough_material_centi_units", 0))) / 100.0
	var layer_ids: Array = total_entry.get("layer_ids", []) as Array
	if layer_id != StringName() and not layer_ids.has(layer_id):
		layer_ids.append(layer_id)
	total_entry["layer_ids"] = layer_ids
	material_totals[material_variant_id] = total_entry
	total_rough_material_centi_units += centi_units
	total_rough_volume_cell_equivalents += volume_cell_equivalents
