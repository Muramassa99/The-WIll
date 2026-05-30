extends Resource
class_name ForgeV2MaterialBody

const CraftedItemWIPScript = preload("res://core/models/crafted_item_wip.gd")
const ForgeV2VolumeStrokeScript = preload("res://runtime/forge_v2/forge_v2_volume_stroke.gd")

const BODY_KIND_VOLUME_STROKE := &"body_kind_volume_stroke"
const BODY_KIND_PLATFORM_SEED := &"body_kind_platform_seed"
const SHAPE_KIND_CAPSULE_PATH := &"shape_kind_capsule_path"

const SEED_ROLE_NONE := &"seed_role_none"
const SEED_ROLE_SHIELD_FIXED_HANDLE := &"seed_role_shield_fixed_handle"
const SEED_ROLE_RANGED_BOW_HANDLE_ANCHOR := &"seed_role_ranged_bow_handle_anchor"

const REFERENCE_CELL_WORLD_SIZE_METERS := 0.0125
const CELL_EQUIVALENTS_PER_MATERIAL_UNIT := 200.0
const MATERIAL_UNIT_SCALE := 100

@export var body_id: StringName = StringName()
@export var body_kind: StringName = BODY_KIND_VOLUME_STROKE
@export var source_record_id: StringName = StringName()
@export var seed_role: StringName = SEED_ROLE_NONE
@export var builder_path_id: StringName = CraftedItemWIPScript.BUILDER_PATH_MELEE
@export var builder_component_id: StringName = CraftedItemWIPScript.BUILDER_COMPONENT_PRIMARY
@export var forge_intent: StringName = &"intent_melee"
@export var equipment_context: StringName = &"ctx_weapon"
@export var material_variant_id: StringName = &"mat_iron_gray"
@export var operation_mode: StringName = ForgeV2VolumeStrokeScript.OPERATION_ADD_MATERIAL
@export var placement_policy: StringName = ForgeV2VolumeStrokeScript.PLACEMENT_REPLACE_EXISTING
@export var shape_kind: StringName = SHAPE_KIND_CAPSULE_PATH
@export var path_points: PackedVector3Array = PackedVector3Array()
@export var radius_meters: float = 0.02
@export var amount_ratio: float = 1.0
@export var rough_volume_cell_equivalents: float = 0.0
@export var rough_material_units: float = 0.0
@export var rough_material_centi_units: int = 0
@export var committed_layer_id: StringName = StringName()
@export var layer_active: bool = true
@export var created_timestamp: float = 0.0
@export var updated_timestamp: float = 0.0

func normalize() -> void:
	if body_id == StringName():
		body_id = _build_body_id()
	if created_timestamp <= 0.0:
		created_timestamp = Time.get_unix_time_from_system()
	if updated_timestamp <= 0.0:
		updated_timestamp = created_timestamp
	body_kind = BODY_KIND_PLATFORM_SEED if body_kind == BODY_KIND_PLATFORM_SEED else BODY_KIND_VOLUME_STROKE
	if body_kind != BODY_KIND_PLATFORM_SEED:
		seed_role = SEED_ROLE_NONE
	builder_path_id = CraftedItemWIPScript.normalize_builder_path_id(builder_path_id)
	builder_component_id = CraftedItemWIPScript.normalize_builder_component_id(builder_path_id, builder_component_id)
	if forge_intent == StringName():
		forge_intent = CraftedItemWIPScript.get_default_forge_intent_for_builder_path(builder_path_id)
	if equipment_context == StringName():
		equipment_context = CraftedItemWIPScript.get_default_equipment_context_for_builder_path(builder_path_id)
	if material_variant_id == StringName() or material_variant_id == &"iron_gray":
		material_variant_id = &"mat_iron_gray"
	if operation_mode != ForgeV2VolumeStrokeScript.OPERATION_REMOVE_MATERIAL:
		operation_mode = ForgeV2VolumeStrokeScript.OPERATION_ADD_MATERIAL
	if placement_policy != ForgeV2VolumeStrokeScript.PLACEMENT_EMPTY_ONLY:
		placement_policy = ForgeV2VolumeStrokeScript.PLACEMENT_REPLACE_EXISTING
	if body_kind == BODY_KIND_PLATFORM_SEED:
		placement_policy = ForgeV2VolumeStrokeScript.PLACEMENT_EMPTY_ONLY
	shape_kind = SHAPE_KIND_CAPSULE_PATH
	radius_meters = maxf(radius_meters, 0.001)
	amount_ratio = clampf(amount_ratio, 0.01, 1.0)
	_recalculate_rough_volume()

func is_platform_seed() -> bool:
	return body_kind == BODY_KIND_PLATFORM_SEED

func is_committed_to_layer() -> bool:
	return committed_layer_id != StringName()

func is_active_in_layer_stack() -> bool:
	return layer_active

func get_signed_rough_volume_cell_equivalents() -> float:
	return -rough_volume_cell_equivalents if operation_mode == ForgeV2VolumeStrokeScript.OPERATION_REMOVE_MATERIAL else rough_volume_cell_equivalents

func get_signed_rough_material_centi_units() -> int:
	return -rough_material_centi_units if operation_mode == ForgeV2VolumeStrokeScript.OPERATION_REMOVE_MATERIAL else rough_material_centi_units

func get_signed_rough_material_units() -> float:
	return float(get_signed_rough_material_centi_units()) / float(MATERIAL_UNIT_SCALE)

func _recalculate_rough_volume() -> void:
	var volume_meters_cubed: float = _calculate_capsule_path_volume_meters_cubed() * amount_ratio
	var cell_volume_meters_cubed: float = pow(REFERENCE_CELL_WORLD_SIZE_METERS, 3.0)
	rough_volume_cell_equivalents = maxf(volume_meters_cubed / cell_volume_meters_cubed, 0.0)
	var raw_material_units: float = rough_volume_cell_equivalents / CELL_EQUIVALENTS_PER_MATERIAL_UNIT
	rough_material_centi_units = int(round(raw_material_units * float(MATERIAL_UNIT_SCALE)))
	if rough_volume_cell_equivalents > 0.0:
		rough_material_centi_units = maxi(rough_material_centi_units, 1)
	rough_material_units = float(rough_material_centi_units) / float(MATERIAL_UNIT_SCALE)

func _calculate_capsule_path_volume_meters_cubed() -> float:
	if path_points.is_empty():
		return 0.0
	var radius: float = maxf(radius_meters, 0.001)
	if path_points.size() == 1:
		return _sphere_volume(radius)
	var path_length: float = 0.0
	for point_index in range(path_points.size() - 1):
		path_length += path_points[point_index].distance_to(path_points[point_index + 1])
	var cylinder_volume: float = PI * radius * radius * path_length
	var endpoint_volume: float = _sphere_volume(radius)
	return cylinder_volume + endpoint_volume

func _sphere_volume(radius: float) -> float:
	return (4.0 / 3.0) * PI * radius * radius * radius

func _build_body_id() -> StringName:
	if body_kind == BODY_KIND_PLATFORM_SEED and seed_role != SEED_ROLE_NONE:
		return StringName("v2_seed_%s_%s_%s" % [
			String(builder_path_id),
			String(builder_component_id),
			String(seed_role),
		])
	return StringName("v2_body_%s" % str(Time.get_ticks_usec()))
