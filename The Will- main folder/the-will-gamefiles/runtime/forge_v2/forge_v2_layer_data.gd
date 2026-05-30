extends Resource
class_name ForgeV2LayerData

const OPERATION_ADD_MATERIAL := &"layer_operation_add_material"
const OPERATION_SUBTRACT_VOID := &"layer_operation_subtract_void"
const OPERATION_MIXED_VOLUME := &"layer_operation_mixed_volume"

const CSG_OPERATION_UNION := &"csg_operation_union"
const CSG_OPERATION_SUBTRACTION := &"csg_operation_subtraction"
const CSG_OPERATION_MIXED := &"csg_operation_mixed"

const INPUT_SHAPE_CAPSULE_PATH_BUNDLE := &"input_shape_capsule_path_bundle"
const COMMIT_BACKEND_LEDGER_ONLY := &"commit_backend_ledger_only"
const MATERIAL_VOID := &"mat_void"
const MATERIAL_MIXED := &"mat_mixed"
const MATERIAL_UNKNOWN_REMOVED := &"mat_unknown_removed"

const SOURCE_OPERATION_REMOVE_MATERIAL := &"operation_remove_material"

@export var layer_id: StringName = StringName()
@export var order_index: int = 0
@export var operation_type: StringName = OPERATION_ADD_MATERIAL
@export var operation_material_id: StringName = StringName()
@export var csg_operation: StringName = CSG_OPERATION_UNION
@export var commit_backend_id: StringName = COMMIT_BACKEND_LEDGER_ONLY
@export var input_shape_type: StringName = INPUT_SHAPE_CAPSULE_PATH_BUNDLE
@export var body_ids: Array[StringName] = []
@export var source_record_ids: Array[StringName] = []
@export var input_shape_records: Array[Dictionary] = []
@export var ledger_delta: Dictionary = {}
@export var removed_material_records: Array[Dictionary] = []
@export var rough_volume_cell_equivalents_delta: float = 0.0
@export var rough_material_centi_units_delta: int = 0
@export var rough_void_volume_cell_equivalents: float = 0.0
@export var rough_void_material_centi_units: int = 0
@export var baked_mesh_reference: String = ""
@export var collision_reference: String = ""
@export var created_timestamp: float = 0.0
@export var undoable: bool = true

func configure_from_material_bodies(next_order_index: int, material_bodies: Array[Resource]) -> void:
	order_index = maxi(next_order_index, 1)
	layer_id = StringName("v2_layer_%04d_%s" % [order_index, str(Time.get_ticks_usec())])
	created_timestamp = Time.get_unix_time_from_system()
	body_ids = []
	source_record_ids = []
	input_shape_records = []
	ledger_delta = {}
	removed_material_records = []
	rough_volume_cell_equivalents_delta = 0.0
	rough_material_centi_units_delta = 0
	rough_void_volume_cell_equivalents = 0.0
	rough_void_material_centi_units = 0
	var add_body_count := 0
	var remove_body_count := 0
	var add_material_ids: Array[StringName] = []
	for body: Resource in material_bodies:
		if body == null:
			continue
		if body.has_method("normalize"):
			body.call("normalize")
		_append_body_record(body)
		var body_operation_mode: StringName = StringName(body.get("operation_mode"))
		if body_operation_mode == SOURCE_OPERATION_REMOVE_MATERIAL:
			remove_body_count += 1
			_append_removed_material_record(body)
			continue
		add_body_count += 1
		var material_variant_id: StringName = StringName(body.get("material_variant_id"))
		if not add_material_ids.has(material_variant_id):
			add_material_ids.append(material_variant_id)
		_append_add_material_delta(body)
	_resolve_operation_metadata(add_body_count, remove_body_count, add_material_ids)

func normalize() -> void:
	if layer_id == StringName():
		layer_id = StringName("v2_layer_%04d_%s" % [maxi(order_index, 1), str(Time.get_ticks_usec())])
	order_index = maxi(order_index, 1)
	if created_timestamp <= 0.0:
		created_timestamp = Time.get_unix_time_from_system()
	if operation_type != OPERATION_SUBTRACT_VOID and operation_type != OPERATION_MIXED_VOLUME:
		operation_type = OPERATION_ADD_MATERIAL
	if csg_operation != CSG_OPERATION_SUBTRACTION and csg_operation != CSG_OPERATION_MIXED:
		csg_operation = CSG_OPERATION_UNION
	if operation_material_id == StringName():
		operation_material_id = MATERIAL_VOID if operation_type == OPERATION_SUBTRACT_VOID else MATERIAL_MIXED
	if commit_backend_id == StringName():
		commit_backend_id = COMMIT_BACKEND_LEDGER_ONLY
	if input_shape_type == StringName():
		input_shape_type = INPUT_SHAPE_CAPSULE_PATH_BUNDLE

func get_material_delta_units(material_variant_id: StringName) -> float:
	var delta_entry: Dictionary = ledger_delta.get(material_variant_id, {}) as Dictionary
	if delta_entry.is_empty():
		return 0.0
	return float(delta_entry.get("rough_material_units", 0.0))

func _append_body_record(body: Resource) -> void:
	var body_id: StringName = StringName(body.get("body_id"))
	if body_id != StringName():
		body_ids.append(body_id)
	var source_record_id: StringName = StringName(body.get("source_record_id"))
	if source_record_id != StringName():
		source_record_ids.append(source_record_id)
	input_shape_records.append({
		"body_id": body_id,
		"source_record_id": source_record_id,
		"material_variant_id": StringName(body.get("material_variant_id")),
		"operation_mode": StringName(body.get("operation_mode")),
		"placement_policy": StringName(body.get("placement_policy")),
		"shape_kind": StringName(body.get("shape_kind")),
		"path_points": body.get("path_points"),
		"radius_meters": float(body.get("radius_meters")),
		"amount_ratio": float(body.get("amount_ratio")),
		"rough_volume_cell_equivalents": float(body.get("rough_volume_cell_equivalents")),
		"rough_material_centi_units": int(body.get("rough_material_centi_units")),
	})

func _append_add_material_delta(body: Resource) -> void:
	var material_variant_id: StringName = StringName(body.get("material_variant_id"))
	var material_centi_units: int = int(body.get("rough_material_centi_units"))
	var volume_cell_equivalents: float = float(body.get("rough_volume_cell_equivalents"))
	var entry: Dictionary = ledger_delta.get(material_variant_id, {
		"material_variant_id": material_variant_id,
		"rough_volume_cell_equivalents": 0.0,
		"rough_material_centi_units": 0,
		"rough_material_units": 0.0,
		"layer_ids": [],
	}) as Dictionary
	entry["rough_volume_cell_equivalents"] = float(entry.get("rough_volume_cell_equivalents", 0.0)) + volume_cell_equivalents
	entry["rough_material_centi_units"] = int(entry.get("rough_material_centi_units", 0)) + material_centi_units
	entry["rough_material_units"] = float(int(entry.get("rough_material_centi_units", 0))) / 100.0
	var layer_ids: Array = entry.get("layer_ids", []) as Array
	if not layer_ids.has(layer_id):
		layer_ids.append(layer_id)
	entry["layer_ids"] = layer_ids
	ledger_delta[material_variant_id] = entry
	rough_volume_cell_equivalents_delta += volume_cell_equivalents
	rough_material_centi_units_delta += material_centi_units

func _append_removed_material_record(body: Resource) -> void:
	var material_centi_units: int = int(body.get("rough_material_centi_units"))
	var volume_cell_equivalents: float = float(body.get("rough_volume_cell_equivalents"))
	removed_material_records.append({
		"layer_id": layer_id,
		"material_variant_id": MATERIAL_UNKNOWN_REMOVED,
		"operation_material_id": MATERIAL_VOID,
		"requested_material_hint": StringName(body.get("material_variant_id")),
		"rough_volume_cell_equivalents": volume_cell_equivalents,
		"rough_material_centi_units": material_centi_units,
		"rough_material_units": float(material_centi_units) / 100.0,
	})
	rough_void_volume_cell_equivalents += volume_cell_equivalents
	rough_void_material_centi_units += material_centi_units

func _resolve_operation_metadata(add_body_count: int, remove_body_count: int, add_material_ids: Array[StringName]) -> void:
	if add_body_count > 0 and remove_body_count > 0:
		operation_type = OPERATION_MIXED_VOLUME
		operation_material_id = MATERIAL_MIXED
		csg_operation = CSG_OPERATION_MIXED
	elif remove_body_count > 0:
		operation_type = OPERATION_SUBTRACT_VOID
		operation_material_id = MATERIAL_VOID
		csg_operation = CSG_OPERATION_SUBTRACTION
	else:
		operation_type = OPERATION_ADD_MATERIAL
		operation_material_id = add_material_ids[0] if add_material_ids.size() == 1 else MATERIAL_MIXED
		csg_operation = CSG_OPERATION_UNION
