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
				removed_material_records.append(
					(removed_record as Dictionary).duplicate(true)
				)
	var resolver = ForgeV2MaterialVolumeResolverScript.new()
	var usage_summary: Dictionary = resolver.call("build_usage_summary", input_shape_records) as Dictionary
	material_totals = usage_summary.get("materials", {}) as Dictionary
	total_rough_material_centi_units = int(usage_summary.get("total_rough_material_centi_units", 0))
	total_rough_volume_cell_equivalents = float(usage_summary.get("total_rough_volume_cell_equivalents", 0.0))
	updated_timestamp = Time.get_unix_time_from_system()

func rebuild_from_checkpoint_and_layers(
	checkpoint_summary: Dictionary,
	protected_layers: Array[Resource],
	active_tail_layers: Array[Resource]
) -> void:
	replace_with_summary(checkpoint_summary)
	for layer_group: Array[Resource] in [protected_layers, active_tail_layers]:
		for layer: Resource in layer_group:
			apply_layer(layer)
	updated_timestamp = Time.get_unix_time_from_system()

func replace_with_summary(summary: Dictionary) -> void:
	reset()
	var source_materials: Dictionary = summary.get("materials", {}) as Dictionary
	for material_key: Variant in source_materials.keys():
		var material_variant_id := StringName(material_key)
		if material_variant_id == StringName():
			continue
		var source_entry_variant: Variant = source_materials[material_key]
		if not source_entry_variant is Dictionary:
			continue
		var source_entry := source_entry_variant as Dictionary
		var centi_units := int(source_entry.get(
			"rough_material_centi_units",
			0
		))
		var volume_cell_equivalents := float(source_entry.get(
			"rough_volume_cell_equivalents",
			0.0
		))
		if centi_units <= 0 and volume_cell_equivalents <= 0.000001:
			continue
		material_totals[material_variant_id] = {
			"material_variant_id": material_variant_id,
			"rough_volume_cell_equivalents": maxf(
				volume_cell_equivalents,
				0.0
			),
			"rough_material_centi_units": maxi(centi_units, 0),
			"rough_material_units": float(maxi(centi_units, 0)) / 100.0,
			# The checkpoint is one bounded authority; retaining every source
			# layer ID here would quietly recreate unbounded history.
			"layer_ids": [],
		}
	var source_removed_records: Array = summary.get(
		"removed_material_records",
		[]
	) as Array
	for record_variant: Variant in source_removed_records:
		if record_variant is Dictionary:
			removed_material_records.append(
				(record_variant as Dictionary).duplicate(true)
			)
	_recalculate_totals_from_material_entries()
	updated_timestamp = Time.get_unix_time_from_system()

func build_checkpoint_summary_after_layer(
	checkpoint_summary: Dictionary,
	layer: Resource
) -> Dictionary:
	var checkpoint_ledger := ForgeV2MaterialLedger.new()
	checkpoint_ledger.replace_with_summary(checkpoint_summary)
	checkpoint_ledger.apply_layer(layer)
	return checkpoint_ledger.get_checkpoint_summary()

func get_checkpoint_summary() -> Dictionary:
	var summary := get_summary()
	var checkpoint_materials: Dictionary = {}
	var materials: Dictionary = summary.get("materials", {}) as Dictionary
	for material_key: Variant in materials.keys():
		var entry_variant: Variant = materials[material_key]
		if not entry_variant is Dictionary:
			continue
		var entry := (entry_variant as Dictionary).duplicate(true)
		entry["layer_ids"] = []
		checkpoint_materials[StringName(material_key)] = entry
	summary["materials"] = checkpoint_materials
	return summary

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
			removed_material_records.append(
				(removed_record as Dictionary).duplicate(true)
			)
	updated_timestamp = Time.get_unix_time_from_system()

func get_summary() -> Dictionary:
	var normalized_materials: Dictionary = {}
	var normalized_total_centi_units := 0
	for material_variant_id: StringName in material_totals.keys():
		var entry := (
			material_totals[material_variant_id] as Dictionary
		).duplicate(true)
		var centi_units: int = maxi(int(entry.get("rough_material_centi_units", 0)), 0)
		var volume_cell_equivalents: float = maxf(float(entry.get("rough_volume_cell_equivalents", 0.0)), 0.0)
		if centi_units <= 0 and volume_cell_equivalents <= 0.000001:
			continue
		entry["rough_material_centi_units"] = centi_units
		entry["rough_material_units"] = float(centi_units) / 100.0
		entry["rough_volume_cell_equivalents"] = volume_cell_equivalents
		normalized_materials[material_variant_id] = entry
		normalized_total_centi_units += centi_units
	for material_variant_id: StringName in normalized_materials.keys():
		var entry: Dictionary = normalized_materials[material_variant_id]
		entry["ratio"] = (
			float(entry.get("rough_material_centi_units", 0))
			/ float(normalized_total_centi_units)
			if normalized_total_centi_units > 0
			else 0.0
		)
		normalized_materials[material_variant_id] = entry
	return {
		"total_rough_material_centi_units": total_rough_material_centi_units,
		"total_rough_material_units": float(total_rough_material_centi_units) / 100.0,
		"total_rough_volume_cell_equivalents": total_rough_volume_cell_equivalents,
		"materials": normalized_materials,
		"removed_material_records": removed_material_records.duplicate(true),
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

func get_retained_layer_ids() -> Array[StringName]:
	var retained_ids: Array[StringName] = []
	for material_key: Variant in material_totals.keys():
		var entry_variant: Variant = material_totals[material_key]
		if not entry_variant is Dictionary:
			continue
		var layer_ids: Array = (entry_variant as Dictionary).get(
			"layer_ids",
			[]
		) as Array
		for layer_id_variant: Variant in layer_ids:
			var layer_id := StringName(layer_id_variant)
			if layer_id != StringName() and not retained_ids.has(layer_id):
				retained_ids.append(layer_id)
	return retained_ids


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
	if (
		int(total_entry.get("rough_material_centi_units", 0)) <= 0
		and float(total_entry.get("rough_volume_cell_equivalents", 0.0))
		<= 0.000001
	):
		material_totals.erase(material_variant_id)
	else:
		material_totals[material_variant_id] = total_entry
	total_rough_material_centi_units += centi_units
	total_rough_volume_cell_equivalents += volume_cell_equivalents

func _recalculate_totals_from_material_entries() -> void:
	total_rough_material_centi_units = 0
	total_rough_volume_cell_equivalents = 0.0
	for material_key: Variant in material_totals.keys():
		var entry_variant: Variant = material_totals[material_key]
		if not entry_variant is Dictionary:
			continue
		var entry := entry_variant as Dictionary
		total_rough_material_centi_units += maxi(int(entry.get(
			"rough_material_centi_units",
			0
		)), 0)
		total_rough_volume_cell_equivalents += maxf(float(entry.get(
			"rough_volume_cell_equivalents",
			0.0
		)), 0.0)
