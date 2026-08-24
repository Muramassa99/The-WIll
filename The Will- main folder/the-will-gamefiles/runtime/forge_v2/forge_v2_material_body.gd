extends Resource
class_name ForgeV2MaterialBody

const CraftedItemWIPScript = preload("res://core/models/crafted_item_wip.gd")
const ForgeV2ProfileShapeLibraryScript = preload("res://runtime/forge_v2/forge_v2_profile_shape_library.gd")
const ForgeV2VolumeStrokeScript = preload("res://runtime/forge_v2/forge_v2_volume_stroke.gd")

const BODY_KIND_VOLUME_STROKE := &"body_kind_volume_stroke"
const BODY_KIND_PLATFORM_SEED := &"body_kind_platform_seed"
const BODY_KIND_PROFILE_EXTRUSION := &"body_kind_profile_extrusion"
const BODY_KIND_HANDLE_PROFILE := &"body_kind_handle_profile"
const BODY_KIND_DETAILING_BRUSH := &"body_kind_detailing_brush"
const SHAPE_KIND_CAPSULE_PATH := &"shape_kind_capsule_path"
const SHAPE_KIND_SPLINE_CAPSULE_PATH := &"shape_kind_spline_capsule_path"
const SHAPE_KIND_PROFILE_PATH := &"shape_kind_profile_path"
const SHAPE_KIND_SPLINE_PROFILE_PATH := &"shape_kind_spline_profile_path"

const SEED_ROLE_NONE := &"seed_role_none"
const SEED_ROLE_SHIELD_FIXED_HANDLE := &"seed_role_shield_fixed_handle"
const SEED_ROLE_RANGED_BOW_HANDLE_ANCHOR := &"seed_role_ranged_bow_handle_anchor"
const PROFILE_ROLE_NONE := ForgeV2ProfileShapeLibraryScript.PROFILE_ROLE_NONE
const PROFILE_ROLE_HANDLE := ForgeV2ProfileShapeLibraryScript.PROFILE_ROLE_HANDLE

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
@export var path_surface_normals: PackedVector3Array = PackedVector3Array()
@export var path_contact_directions: PackedVector3Array = PackedVector3Array()
@export var surface_target_kind: StringName = StringName()
@export var surface_target_id: StringName = StringName()
@export var radius_meters: float = 0.02
@export var profile_id: StringName = StringName()
@export var profile_display_name: String = ""
@export var profile_role: StringName = PROFILE_ROLE_NONE
@export var profile_polygon_2d_meters: PackedVector2Array = PackedVector2Array()
@export var profile_anchor_2d_meters: Vector2 = Vector2.ZERO
@export var profile_contact_point_relative_2d_meters: Vector2 = Vector2.ZERO
@export var profile_contact_direction_2d: Vector2 = (
	ForgeV2ProfileShapeLibraryScript.BASIC_PROFILE_LOCAL_SIX
)
@export var profile_contact_distance_meters: float = 0.0
@export var profile_runtime_schema_version: int = 0
@export var profile_rotation_bias_degrees: float = 0.0
@export var profile_twist_degrees_per_meter: float = 0.0
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
	body_kind = _normalize_body_kind(body_kind)
	if body_kind != BODY_KIND_PLATFORM_SEED:
		seed_role = SEED_ROLE_NONE
	if body_kind == BODY_KIND_DETAILING_BRUSH:
		if surface_target_kind == StringName() or surface_target_id == StringName():
			surface_target_kind = StringName()
			surface_target_id = StringName()
		if shape_kind == SHAPE_KIND_SPLINE_PROFILE_PATH:
			shape_kind = SHAPE_KIND_PROFILE_PATH
		elif shape_kind == SHAPE_KIND_SPLINE_CAPSULE_PATH:
			shape_kind = SHAPE_KIND_CAPSULE_PATH
	else:
		surface_target_kind = StringName()
		surface_target_id = StringName()
	if body_kind == BODY_KIND_HANDLE_PROFILE:
		profile_role = PROFILE_ROLE_HANDLE
	builder_path_id = CraftedItemWIPScript.normalize_builder_path_id(builder_path_id)
	builder_component_id = CraftedItemWIPScript.normalize_builder_component_id(builder_path_id, builder_component_id)
	if forge_intent == StringName():
		forge_intent = CraftedItemWIPScript.get_default_forge_intent_for_builder_path(builder_path_id)
	if equipment_context == StringName():
		equipment_context = CraftedItemWIPScript.get_default_equipment_context_for_builder_path(builder_path_id)
	if material_variant_id == StringName() or material_variant_id == &"iron_gray":
		material_variant_id = &"mat_iron_gray"
	if body_kind == BODY_KIND_HANDLE_PROFILE:
		operation_mode = ForgeV2VolumeStrokeScript.OPERATION_ADD_MATERIAL
		placement_policy = ForgeV2VolumeStrokeScript.PLACEMENT_REPLACE_EXISTING
	else:
		if operation_mode != ForgeV2VolumeStrokeScript.OPERATION_REMOVE_MATERIAL:
			operation_mode = ForgeV2VolumeStrokeScript.OPERATION_ADD_MATERIAL
		if placement_policy != ForgeV2VolumeStrokeScript.PLACEMENT_EMPTY_ONLY:
			placement_policy = ForgeV2VolumeStrokeScript.PLACEMENT_REPLACE_EXISTING
	if body_kind == BODY_KIND_PLATFORM_SEED:
		placement_policy = ForgeV2VolumeStrokeScript.PLACEMENT_EMPTY_ONLY
	shape_kind = _normalize_shape_kind(shape_kind)
	_normalize_path_surface_normals()
	_normalize_path_contact_directions()
	if _is_profile_shape_kind():
		_ensure_profile_data()
	radius_meters = maxf(radius_meters, 0.001)
	if _is_profile_shape_kind():
		radius_meters = maxf(radius_meters, ForgeV2ProfileShapeLibraryScript.calculate_polygon_max_radius_meters(profile_polygon_2d_meters))
	amount_ratio = 1.0
	_recalculate_rough_volume()

func is_platform_seed() -> bool:
	return body_kind == BODY_KIND_PLATFORM_SEED

func is_detailing_brush() -> bool:
	return body_kind == BODY_KIND_DETAILING_BRUSH

func uses_explicit_surface_contact_authority() -> bool:
	return (
		shape_kind == SHAPE_KIND_PROFILE_PATH
		and profile_runtime_schema_version > 0
		and (
			body_kind == BODY_KIND_VOLUME_STROKE
			or body_kind == BODY_KIND_DETAILING_BRUSH
		)
	)

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
	var volume_meters_cubed: float = _calculate_capsule_path_volume_meters_cubed()
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
	if _is_profile_shape_kind():
		return _calculate_profile_path_volume_meters_cubed()
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

func _calculate_profile_path_volume_meters_cubed() -> float:
	var profile_area: float = ForgeV2ProfileShapeLibraryScript.calculate_polygon_area_meters_squared(profile_polygon_2d_meters)
	if profile_area <= 0.0 or path_points.size() < 2:
		return 0.0
	var path_length := 0.0
	for point_index in range(path_points.size() - 1):
		path_length += path_points[point_index].distance_to(path_points[point_index + 1])
	return profile_area * path_length

func _normalize_body_kind(next_body_kind: StringName) -> StringName:
	match next_body_kind:
		BODY_KIND_PLATFORM_SEED, BODY_KIND_PROFILE_EXTRUSION, BODY_KIND_HANDLE_PROFILE, BODY_KIND_DETAILING_BRUSH:
			return next_body_kind
		_:
			return BODY_KIND_VOLUME_STROKE

func _normalize_shape_kind(next_shape_kind: StringName) -> StringName:
	match next_shape_kind:
		SHAPE_KIND_SPLINE_CAPSULE_PATH, SHAPE_KIND_PROFILE_PATH, SHAPE_KIND_SPLINE_PROFILE_PATH:
			return next_shape_kind
		_:
			return SHAPE_KIND_CAPSULE_PATH

func _is_profile_shape_kind() -> bool:
	return shape_kind == SHAPE_KIND_PROFILE_PATH or shape_kind == SHAPE_KIND_SPLINE_PROFILE_PATH

func _ensure_profile_data() -> void:
	var required_family := (
		ForgeV2ProfileShapeLibraryScript.PROFILE_FAMILY_HANDLE
		if profile_role == PROFILE_ROLE_HANDLE or body_kind == BODY_KIND_HANDLE_PROFILE
		else StringName()
	)
	var record: Dictionary = {}
	if profile_polygon_2d_meters.size() < 3:
		profile_id = ForgeV2ProfileShapeLibraryScript.normalize_profile_id(
			profile_id,
			required_family
		)
		record = ForgeV2ProfileShapeLibraryScript.get_profile_record(
			profile_id,
			radius_meters
		)
	if profile_role == StringName():
		profile_role = PROFILE_ROLE_NONE
	if not record.is_empty():
		if profile_role == PROFILE_ROLE_NONE:
			profile_role = StringName(record.get("role", PROFILE_ROLE_NONE))
		if profile_polygon_2d_meters.size() < 3:
			profile_polygon_2d_meters = record.get("polygon", PackedVector2Array())
		if profile_anchor_2d_meters == Vector2.ZERO:
			profile_anchor_2d_meters = record.get("anchor_2d_meters", Vector2.ZERO) as Vector2
	if profile_polygon_2d_meters.size() < 3:
		profile_polygon_2d_meters = ForgeV2ProfileShapeLibraryScript.build_circle_polygon(radius_meters)
	if profile_contact_direction_2d.length_squared() <= 0.0000000001:
		profile_contact_direction_2d = (
			ForgeV2ProfileShapeLibraryScript.BASIC_PROFILE_LOCAL_SIX
		)
	else:
		profile_contact_direction_2d = profile_contact_direction_2d.normalized()
	profile_contact_distance_meters = maxf(
		profile_contact_distance_meters,
		0.0
	)
	profile_rotation_bias_degrees = wrapf(
		profile_rotation_bias_degrees,
		-180.0,
		180.0
	)

func _normalize_path_surface_normals() -> void:
	var normalized_normals := PackedVector3Array()
	for point_index in range(path_points.size()):
		var normal := Vector3.FORWARD
		if point_index < path_surface_normals.size():
			normal = path_surface_normals[point_index]
		if normal.length_squared() <= 0.000001:
			normal = Vector3.FORWARD
		normalized_normals.append(normal.normalized())
	path_surface_normals = normalized_normals

func _normalize_path_contact_directions() -> void:
	if not uses_explicit_surface_contact_authority():
		return
	if path_contact_directions.is_empty():
		return
	if path_contact_directions.size() != path_points.size():
		path_contact_directions = PackedVector3Array()
		return
	var normalized_directions := PackedVector3Array()
	for contact_direction: Vector3 in path_contact_directions:
		if (
			not is_finite(contact_direction.x)
			or not is_finite(contact_direction.y)
			or not is_finite(contact_direction.z)
			or contact_direction.length_squared() <= 0.000001
		):
			path_contact_directions = PackedVector3Array()
			return
		normalized_directions.append(contact_direction.normalized())
	path_contact_directions = normalized_directions

func _build_body_id() -> StringName:
	if body_kind == BODY_KIND_PLATFORM_SEED and seed_role != SEED_ROLE_NONE:
		return StringName("v2_seed_%s_%s_%s" % [
			String(builder_path_id),
			String(builder_component_id),
			String(seed_role),
		])
	if body_kind == BODY_KIND_HANDLE_PROFILE:
		return StringName("v2_handle_%s" % str(Time.get_ticks_usec()))
	if body_kind == BODY_KIND_PROFILE_EXTRUSION:
		return StringName("v2_profile_%s" % str(Time.get_ticks_usec()))
	if body_kind == BODY_KIND_DETAILING_BRUSH:
		return StringName("v2_detail_%s" % str(Time.get_ticks_usec()))
	return StringName("v2_body_%s" % str(Time.get_ticks_usec()))
