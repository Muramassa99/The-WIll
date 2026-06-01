extends Resource
class_name ForgeV2AuthoringState

const CraftedItemWIPScript = preload("res://core/models/crafted_item_wip.gd")
const ForgeV2LayerDataScript = preload("res://runtime/forge_v2/forge_v2_layer_data.gd")
const ForgeV2MaterialBodyScript = preload("res://runtime/forge_v2/forge_v2_material_body.gd")
const ForgeV2MaterialLedgerScript = preload("res://runtime/forge_v2/forge_v2_material_ledger.gd")
const ForgeV2MaterialPaletteScript = preload("res://runtime/forge_v2/forge_v2_material_palette.gd")
const ForgeV2MaterialTierPolicyScript = preload("res://runtime/forge_v2/forge_v2_material_tier_policy.gd")
const ForgeV2MaterialVolumeResolverScript = preload("res://runtime/forge_v2/forge_v2_material_volume_resolver.gd")
const ForgeV2PlatformContractScript = preload("res://runtime/forge_v2/forge_v2_platform_contract.gd")
const ForgeV2PrimitiveCatalogScript = preload("res://runtime/forge_v2/forge_v2_primitive_catalog.gd")
const ForgeV2VolumeStrokeScript = preload("res://runtime/forge_v2/forge_v2_volume_stroke.gd")

const SCHEMA_VERSION := 1
const SCHEMA_ID := &"forge_stage1_v2"

const AUTHORING_SPACE_WORLD_3D := &"authoring_space_world_3d"
const TOOL_VOLUME_STROKE := &"tool_volume_stroke"
const TOOL_SPLINE_LINE := &"tool_spline_line"
const DEFAULT_ACTIVE_PRIMITIVE_ID := ForgeV2PrimitiveCatalogScript.PRIMITIVE_BLOB
const OPERATION_ADD_MATERIAL := ForgeV2VolumeStrokeScript.OPERATION_ADD_MATERIAL
const OPERATION_REMOVE_MATERIAL := ForgeV2VolumeStrokeScript.OPERATION_REMOVE_MATERIAL
const PLACEMENT_REPLACE_EXISTING := ForgeV2VolumeStrokeScript.PLACEMENT_REPLACE_EXISTING
const PLACEMENT_EMPTY_ONLY := ForgeV2VolumeStrokeScript.PLACEMENT_EMPTY_ONLY
const BRUSH_RADIUS_MIN_METERS := 0.0125
const BRUSH_RADIUS_MAX_METERS := 0.375
const BRUSH_RADIUS_STEP_METERS := 0.0125
const DEFAULT_POINT_PLACEMENT_RADIUS_METERS := 0.025
const DEFAULT_AMOUNT_RATIO := 1.0

@export var schema_version: int = SCHEMA_VERSION
@export var schema_id: StringName = SCHEMA_ID
@export var draft_id: StringName = StringName()
@export var source_wip_id: StringName = StringName()
@export var project_name: String = ""
@export_multiline var project_notes: String = ""
@export var creator_id: StringName = &"stage1_v2"
@export var created_timestamp: float = 0.0
@export var updated_timestamp: float = 0.0
@export var builder_path_id: StringName = CraftedItemWIPScript.BUILDER_PATH_MELEE
@export var builder_component_id: StringName = CraftedItemWIPScript.BUILDER_COMPONENT_PRIMARY
@export var forge_intent: StringName = &"intent_melee"
@export var equipment_context: StringName = &"ctx_weapon"
@export var authoring_space_id: StringName = AUTHORING_SPACE_WORLD_3D
@export var active_tool_id: StringName = TOOL_VOLUME_STROKE
@export var active_primitive_id: StringName = DEFAULT_ACTIVE_PRIMITIVE_ID
@export var active_operation_mode: StringName = OPERATION_ADD_MATERIAL
@export var placement_policy: StringName = PLACEMENT_REPLACE_EXISTING
@export var active_material_variant_id: StringName = &"mat_iron_gray"
@export var active_brush_radius_meters: float = DEFAULT_POINT_PLACEMENT_RADIUS_METERS
@export var active_amount_ratio: float = DEFAULT_AMOUNT_RATIO
@export var selected_material_body_id: StringName = StringName()
@export var material_bodies: Array[Resource] = []
@export var volume_strokes: Array[Resource] = []
@export var spline_line_points: PackedVector3Array = PackedVector3Array()
@export var spline_line_finished: bool = false
@export var selected_spline_point_index: int = -1
@export var spline_line_csg_noodle_enabled: bool = false
@export var forge_layers: Array[Resource] = []
@export var undone_forge_layers: Array[Resource] = []
@export var material_ledger: Resource = null

var material_usage_summary_cache: Dictionary = {}
var material_usage_summary_cache_dirty: bool = true

func reset_new_draft(next_project_name: String = "Stage 1 V2 Draft") -> void:
	schema_version = SCHEMA_VERSION
	schema_id = SCHEMA_ID
	draft_id = StringName("v2_draft_%s" % str(Time.get_unix_time_from_system()))
	source_wip_id = StringName()
	project_name = next_project_name.strip_edges()
	project_notes = ""
	creator_id = &"stage1_v2"
	created_timestamp = Time.get_unix_time_from_system()
	updated_timestamp = created_timestamp
	builder_path_id = CraftedItemWIPScript.BUILDER_PATH_MELEE
	builder_component_id = CraftedItemWIPScript.BUILDER_COMPONENT_PRIMARY
	forge_intent = &"intent_melee"
	equipment_context = &"ctx_weapon"
	authoring_space_id = AUTHORING_SPACE_WORLD_3D
	active_tool_id = TOOL_VOLUME_STROKE
	active_primitive_id = DEFAULT_ACTIVE_PRIMITIVE_ID
	active_operation_mode = OPERATION_ADD_MATERIAL
	placement_policy = PLACEMENT_REPLACE_EXISTING
	active_material_variant_id = &"mat_iron_gray"
	active_brush_radius_meters = DEFAULT_POINT_PLACEMENT_RADIUS_METERS
	active_amount_ratio = DEFAULT_AMOUNT_RATIO
	selected_material_body_id = StringName()
	material_bodies = []
	volume_strokes = []
	spline_line_points = PackedVector3Array()
	spline_line_finished = false
	selected_spline_point_index = -1
	spline_line_csg_noodle_enabled = false
	forge_layers = []
	undone_forge_layers = []
	material_ledger = ForgeV2MaterialLedgerScript.new()
	_mark_material_usage_summary_dirty()
	normalize()

func normalize() -> void:
	schema_version = SCHEMA_VERSION
	schema_id = SCHEMA_ID
	if draft_id == StringName():
		draft_id = StringName("v2_draft_%s" % str(Time.get_unix_time_from_system()))
	var had_valid_material_ledger := material_ledger != null and material_ledger.has_method("rebuild_from_layers")
	if project_name.strip_edges().is_empty():
		project_name = "Stage 1 V2 Draft"
	if created_timestamp <= 0.0:
		created_timestamp = Time.get_unix_time_from_system()
	if updated_timestamp <= 0.0:
		updated_timestamp = created_timestamp
	builder_path_id = CraftedItemWIPScript.normalize_builder_path_id(builder_path_id)
	builder_component_id = CraftedItemWIPScript.normalize_builder_component_id(
		builder_path_id,
		builder_component_id
	)
	_apply_builder_path_defaults()
	if authoring_space_id != AUTHORING_SPACE_WORLD_3D:
		authoring_space_id = AUTHORING_SPACE_WORLD_3D
	if active_tool_id != TOOL_SPLINE_LINE:
		active_tool_id = TOOL_VOLUME_STROKE
	active_primitive_id = ForgeV2PrimitiveCatalogScript.normalize_primitive_id(active_primitive_id)
	if active_operation_mode != OPERATION_REMOVE_MATERIAL:
		active_operation_mode = OPERATION_ADD_MATERIAL
	if placement_policy != PLACEMENT_EMPTY_ONLY:
		placement_policy = PLACEMENT_REPLACE_EXISTING
	active_material_variant_id = ForgeV2MaterialPaletteScript.normalize_material_variant_id(active_material_variant_id)
	active_brush_radius_meters = _normalize_brush_radius(active_brush_radius_meters)
	active_amount_ratio = _normalize_amount_ratio(active_amount_ratio)
	_normalize_material_bodies()
	_ensure_platform_seed_bodies()
	_normalize_volume_strokes()
	_normalize_spline_line()
	_normalize_forge_layers()
	_ensure_material_ledger()
	if not had_valid_material_ledger and not forge_layers.is_empty():
		_rebuild_material_ledger()
	_normalize_selected_material_body_id()

func set_builder_path(next_builder_path_id: StringName, next_builder_component_id: StringName = StringName()) -> void:
	builder_path_id = CraftedItemWIPScript.normalize_builder_path_id(next_builder_path_id)
	builder_component_id = CraftedItemWIPScript.normalize_builder_component_id(
		builder_path_id,
		next_builder_component_id
	)
	_apply_builder_path_defaults()
	_ensure_platform_seed_bodies()
	_mark_material_usage_summary_dirty()
	mark_updated()

func set_builder_component(next_builder_component_id: StringName) -> void:
	builder_component_id = CraftedItemWIPScript.normalize_builder_component_id(
		builder_path_id,
		next_builder_component_id
	)
	_apply_builder_path_defaults()
	_ensure_platform_seed_bodies()
	_mark_material_usage_summary_dirty()
	mark_updated()

func set_active_operation_mode(next_operation_mode: StringName) -> void:
	active_operation_mode = OPERATION_REMOVE_MATERIAL if next_operation_mode == OPERATION_REMOVE_MATERIAL else OPERATION_ADD_MATERIAL
	mark_updated()

func set_placement_policy(next_placement_policy: StringName) -> void:
	placement_policy = PLACEMENT_EMPTY_ONLY if next_placement_policy == PLACEMENT_EMPTY_ONLY else PLACEMENT_REPLACE_EXISTING
	mark_updated()

func set_active_primitive_id(next_primitive_id: StringName) -> void:
	active_primitive_id = ForgeV2PrimitiveCatalogScript.normalize_primitive_id(next_primitive_id)
	mark_updated()

func set_active_tool_id(next_tool_id: StringName) -> void:
	active_tool_id = TOOL_SPLINE_LINE if next_tool_id == TOOL_SPLINE_LINE else TOOL_VOLUME_STROKE
	mark_updated()

func set_active_material_variant_id(next_material_variant_id: StringName) -> void:
	if next_material_variant_id == StringName():
		return
	active_material_variant_id = ForgeV2MaterialPaletteScript.normalize_material_variant_id(next_material_variant_id)
	mark_updated()

func set_brush_radius_meters(next_radius_meters: float) -> void:
	active_brush_radius_meters = _normalize_brush_radius(next_radius_meters)
	mark_updated()

func adjust_brush_radius_steps(step_count: int) -> void:
	set_brush_radius_meters(active_brush_radius_meters + (float(step_count) * BRUSH_RADIUS_STEP_METERS))

func set_amount_ratio(_next_amount_ratio: float) -> void:
	var was_default := is_equal_approx(active_amount_ratio, DEFAULT_AMOUNT_RATIO)
	active_amount_ratio = DEFAULT_AMOUNT_RATIO
	if not was_default:
		mark_updated()

func adjust_amount_ratio_steps(_step_count: int) -> void:
	set_amount_ratio(DEFAULT_AMOUNT_RATIO)

func append_empty_volume_stroke() -> Resource:
	var body: Resource = append_empty_material_body()
	return body

func append_empty_material_body() -> Resource:
	var body: Resource = _append_material_body_record(PackedVector3Array(), 0.001, DEFAULT_AMOUNT_RATIO)
	mark_updated()
	return body

func append_sample_volume_stroke() -> Resource:
	var body: Resource = append_sample_material_body()
	return body

func append_sample_material_body() -> Resource:
	var body: Resource = _append_material_body_record(
		_build_sample_stroke_points(get_user_material_body_count()),
		active_brush_radius_meters,
		DEFAULT_AMOUNT_RATIO
	)
	mark_updated()
	return body

func append_active_primitive_deposit() -> Array[Resource]:
	var created_bodies: Array[Resource] = []
	var stroke_specs: Array[Dictionary] = ForgeV2PrimitiveCatalogScript.build_stroke_specs(
		active_primitive_id,
		active_brush_radius_meters,
		DEFAULT_AMOUNT_RATIO
	)
	for stroke_spec: Dictionary in stroke_specs:
		created_bodies.append(_append_material_body_record(
			stroke_spec.get("path_points", PackedVector3Array()) as PackedVector3Array,
			float(stroke_spec.get("radius_meters", active_brush_radius_meters)),
			DEFAULT_AMOUNT_RATIO
		))
	mark_updated()
	return created_bodies

func append_point_volume_stroke(
	local_position: Vector3,
	radius_meters: float = -1.0,
	amount_ratio: float = -1.0
) -> Resource:
	return append_point_material_body(local_position, radius_meters, amount_ratio)

func append_point_material_body(
	local_position: Vector3,
	radius_meters: float = -1.0,
	amount_ratio: float = -1.0
) -> Resource:
	var body: Resource = _append_material_body_record(
		PackedVector3Array([local_position]),
		active_brush_radius_meters if radius_meters <= 0.0 else _normalize_brush_radius(radius_meters),
		DEFAULT_AMOUNT_RATIO
	)
	mark_updated()
	return body

func append_point_to_volume_stroke(
	stroke_id: StringName,
	local_position: Vector3,
	min_spacing_meters: float = 0.0,
	force_endpoint: bool = false
) -> bool:
	return append_point_to_material_body(stroke_id, local_position, min_spacing_meters, force_endpoint)

func append_point_to_material_body(
	body_id: StringName,
	local_position: Vector3,
	min_spacing_meters: float = 0.0,
	force_endpoint: bool = false
) -> bool:
	var body: Resource = _find_editable_material_body(body_id)
	if body == null:
		return false
	var path_points: PackedVector3Array = body.get("path_points")
	var changed := false
	if path_points.is_empty():
		path_points.append(local_position)
		changed = true
	else:
		var last_point: Vector3 = path_points[path_points.size() - 1]
		var spacing: float = maxf(min_spacing_meters, 0.0)
		var is_far_enough := spacing <= 0.0 or last_point.distance_squared_to(local_position) >= spacing * spacing
		if is_far_enough:
			path_points.append(local_position)
			changed = true
		elif force_endpoint and not last_point.is_equal_approx(local_position):
			path_points[path_points.size() - 1] = local_position
			changed = true
	if not changed:
		return false
	body.set("path_points", path_points)
	body.set("updated_timestamp", Time.get_unix_time_from_system())
	if body.has_method("normalize"):
		body.call("normalize")
	_mark_material_usage_summary_dirty()
	mark_updated()
	return true

func clear_volume_strokes() -> void:
	clear_pending_material_bodies()

func clear_pending_material_bodies() -> void:
	_remove_pending_user_material_bodies()
	volume_strokes = []
	selected_material_body_id = StringName()
	spline_line_csg_noodle_enabled = false
	_mark_material_usage_summary_dirty()
	mark_updated()

func append_spline_line_point(local_position: Vector3) -> int:
	_normalize_spline_line()
	if spline_line_finished:
		return -1
	var next_points: PackedVector3Array = spline_line_points
	next_points.append(local_position)
	spline_line_points = next_points
	selected_spline_point_index = spline_line_points.size() - 1
	mark_updated()
	return selected_spline_point_index

func set_spline_line_point(point_index: int, local_position: Vector3) -> bool:
	_normalize_spline_line()
	if point_index < 0 or point_index >= spline_line_points.size():
		return false
	var next_points: PackedVector3Array = spline_line_points
	next_points[point_index] = local_position
	spline_line_points = next_points
	selected_spline_point_index = point_index
	mark_updated()
	return true

func select_spline_line_point(point_index: int) -> bool:
	_normalize_spline_line()
	if point_index < -1 or point_index >= spline_line_points.size():
		return false
	selected_spline_point_index = point_index
	mark_updated()
	return true

func find_nearest_spline_line_point(local_position: Vector3, max_distance_meters: float) -> int:
	_normalize_spline_line()
	if spline_line_points.is_empty() or max_distance_meters <= 0.0:
		return -1
	var nearest_index := -1
	var nearest_distance_squared := max_distance_meters * max_distance_meters
	for point_index in range(spline_line_points.size()):
		var distance_squared := spline_line_points[point_index].distance_squared_to(local_position)
		if distance_squared > nearest_distance_squared:
			continue
		nearest_distance_squared = distance_squared
		nearest_index = point_index
	return nearest_index

func finish_spline_line() -> bool:
	_normalize_spline_line()
	if spline_line_points.size() < 2 or spline_line_finished:
		return false
	spline_line_finished = true
	selected_spline_point_index = -1
	mark_updated()
	return true

func cancel_spline_line() -> bool:
	_normalize_spline_line()
	if spline_line_points.is_empty() and not spline_line_finished and selected_spline_point_index < 0:
		return false
	spline_line_points = PackedVector3Array()
	spline_line_finished = false
	selected_spline_point_index = -1
	spline_line_csg_noodle_enabled = false
	mark_updated()
	return true

func can_generate_spline_line_csg_noodle() -> bool:
	_normalize_spline_line()
	return spline_line_points.size() >= 2

func generate_spline_line_csg_noodle() -> bool:
	_normalize_spline_line()
	if spline_line_points.size() < 2:
		return false
	var body: Resource = _append_spline_line_material_body()
	if body == null:
		return false
	spline_line_points = PackedVector3Array()
	spline_line_finished = false
	selected_spline_point_index = -1
	spline_line_csg_noodle_enabled = false
	selected_material_body_id = StringName(body.get("body_id"))
	mark_updated()
	return true

func clear_spline_line_csg_noodle() -> bool:
	if not spline_line_csg_noodle_enabled:
		return false
	spline_line_csg_noodle_enabled = false
	mark_updated()
	return true

func get_spline_line_point_count() -> int:
	return spline_line_points.size()

func get_spline_line_status_label() -> String:
	var point_count := get_spline_line_point_count()
	if point_count <= 0:
		return "Spline: no points"
	var state_label := "finished" if spline_line_finished else "editing"
	return "Spline: %s points, %s" % [str(point_count), state_label]

func get_spline_line_csg_noodle_status_label() -> String:
	if spline_line_points.size() < 2:
		return "CSG noodle: needs 2 points"
	var radius_label := "radius %.4f m" % active_brush_radius_meters
	return "CSG noodle: active, %s" % radius_label if spline_line_csg_noodle_enabled else "CSG noodle: ready, %s" % radius_label

func get_spline_line_summary() -> Dictionary:
	_normalize_spline_line()
	return {
		"points": spline_line_points,
		"point_count": spline_line_points.size(),
		"finished": spline_line_finished,
		"selected_point_index": selected_spline_point_index,
		"status_label": get_spline_line_status_label(),
		"csg_noodle_enabled": spline_line_csg_noodle_enabled,
		"can_generate_csg_noodle": can_generate_spline_line_csg_noodle(),
		"csg_noodle_status_label": get_spline_line_csg_noodle_status_label(),
		"csg_noodle_radius_meters": active_brush_radius_meters,
	}

func commit_pending_material_bodies_as_layer() -> Resource:
	var pending_bodies: Array[Resource] = _collect_pending_user_material_bodies()
	return _commit_material_bodies_as_layer(pending_bodies)

func commit_material_body_as_layer(body_id: StringName) -> Resource:
	var body: Resource = _find_editable_material_body(body_id)
	if body == null:
		return null
	return _commit_material_bodies_as_layer([body])

func _commit_material_bodies_as_layer(pending_bodies: Array[Resource]) -> Resource:
	if pending_bodies.is_empty():
		return null
	var committed_bodies: Array[Resource] = _collect_committed_active_user_material_bodies()
	var layer: Resource = ForgeV2LayerDataScript.new()
	layer.call("configure_from_material_bodies", forge_layers.size() + 1, pending_bodies, committed_bodies)
	for body: Resource in pending_bodies:
		if body == null:
			continue
		body.set("committed_layer_id", StringName(layer.get("layer_id")))
		body.set("layer_active", true)
	forge_layers.append(layer)
	undone_forge_layers.clear()
	_rebuild_material_ledger()
	_mark_material_usage_summary_dirty()
	mark_updated()
	return layer

func undo_latest_layer() -> bool:
	if forge_layers.is_empty():
		return false
	var layer: Resource = forge_layers.pop_back()
	if layer == null:
		return false
	undone_forge_layers.append(layer)
	_set_layer_bodies_active(layer, false)
	_rebuild_material_ledger()
	_mark_material_usage_summary_dirty()
	mark_updated()
	return true

func redo_latest_layer() -> bool:
	if undone_forge_layers.is_empty():
		return false
	var layer: Resource = undone_forge_layers.pop_back()
	if layer == null:
		return false
	forge_layers.append(layer)
	_set_layer_bodies_active(layer, true)
	_rebuild_material_ledger()
	_mark_material_usage_summary_dirty()
	mark_updated()
	return true

func get_builder_scope_label() -> String:
	return CraftedItemWIPScript.get_builder_scope_label(builder_path_id, builder_component_id)

func get_platform_contract() -> Dictionary:
	return ForgeV2PlatformContractScript.build_contract(builder_path_id, builder_component_id)

func get_platform_contract_summary() -> String:
	return ForgeV2PlatformContractScript.build_compact_summary(builder_path_id, builder_component_id)

func get_operation_label() -> String:
	return "Remove Material" if active_operation_mode == OPERATION_REMOVE_MATERIAL else "Add Material"

func get_placement_policy_label() -> String:
	return "Empty Space Only" if placement_policy == PLACEMENT_EMPTY_ONLY else "Replace Existing"

func get_active_primitive_label() -> String:
	return ForgeV2PrimitiveCatalogScript.get_primitive_label(active_primitive_id)

func get_active_primitive_summary() -> String:
	return ForgeV2PrimitiveCatalogScript.get_primitive_summary(active_primitive_id)

func get_active_tool_label() -> String:
	return "Spline Line" if active_tool_id == TOOL_SPLINE_LINE else "CSG Material Stroke"

func get_tool_options() -> Array[Dictionary]:
	return [
		{
			"id": TOOL_VOLUME_STROKE,
			"label": "CSG Material Stroke",
		},
		{
			"id": TOOL_SPLINE_LINE,
			"label": "Spline Line",
		},
	]

func get_primitive_options() -> Array[Dictionary]:
	return ForgeV2PrimitiveCatalogScript.build_option_entries()

func get_material_palette_options() -> Array[Dictionary]:
	return ForgeV2MaterialPaletteScript.build_palette_entries()

func get_active_material_label() -> String:
	return ForgeV2MaterialPaletteScript.get_material_label(active_material_variant_id)

func get_material_tier_policy_summary() -> Dictionary:
	return ForgeV2MaterialTierPolicyScript.build_policy_summary()

func get_brush_radius_label() -> String:
	return "Radius %.4f m" % active_brush_radius_meters

func get_amount_ratio_label() -> String:
	return "Solid material"

func get_volume_stroke_count() -> int:
	var stroke_count := 0
	for stroke: Resource in volume_strokes:
		if stroke != null:
			stroke_count += 1
	return stroke_count

func get_material_body_count() -> int:
	var body_count := 0
	for body: Resource in material_bodies:
		if body != null and _is_material_body_active(body):
			body_count += 1
	return body_count

func get_seed_material_body_count() -> int:
	var seed_body_count := 0
	for body: Resource in material_bodies:
		if (
			body != null
			and _is_material_body_active(body)
			and body.has_method("is_platform_seed")
			and bool(body.call("is_platform_seed"))
		):
			seed_body_count += 1
	return seed_body_count

func get_user_material_body_count() -> int:
	var body_count := 0
	for body: Resource in material_bodies:
		if body == null:
			continue
		if not _is_material_body_active(body):
			continue
		if body.has_method("is_platform_seed") and bool(body.call("is_platform_seed")):
			continue
		body_count += 1
	return body_count

func get_pending_material_body_count() -> int:
	return _collect_pending_user_material_bodies().size()

func get_committed_layer_count() -> int:
	var layer_count := 0
	for layer: Resource in forge_layers:
		if layer != null:
			layer_count += 1
	return layer_count

func get_undone_layer_count() -> int:
	var layer_count := 0
	for layer: Resource in undone_forge_layers:
		if layer != null:
			layer_count += 1
	return layer_count

func get_material_ledger_summary() -> Dictionary:
	_ensure_material_ledger()
	return material_ledger.call("get_summary") if material_ledger != null else {}

func get_material_ledger_label() -> String:
	_ensure_material_ledger()
	return String(material_ledger.call("get_summary_label")) if material_ledger != null else "Ledger material: 0.00 units"

func get_selected_material_body() -> Resource:
	if selected_material_body_id == StringName():
		return null
	for body: Resource in material_bodies:
		if body == null:
			continue
		if not _is_material_body_active(body):
			continue
		if StringName(body.get("body_id")) == selected_material_body_id:
			return body
	return null

func get_material_body_stack_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var body_index := 0
	for body: Resource in material_bodies:
		if body == null:
			continue
		if not _is_material_body_active(body):
			continue
		if body.has_method("normalize"):
			body.call("normalize")
		body_index += 1
		entries.append(_build_material_body_stack_entry(body, body_index))
	return entries

func select_material_body(body_id: StringName) -> bool:
	if body_id == StringName():
		selected_material_body_id = StringName()
		mark_updated()
		return true
	for body: Resource in material_bodies:
		if body == null:
			continue
		if not _is_material_body_active(body):
			continue
		if StringName(body.get("body_id")) != body_id:
			continue
		selected_material_body_id = body_id
		mark_updated()
		return true
	return false

func select_last_user_material_body() -> bool:
	for body_index in range(material_bodies.size() - 1, -1, -1):
		var body: Resource = material_bodies[body_index]
		if body == null:
			continue
		if not _is_material_body_active(body):
			continue
		if body.has_method("is_platform_seed") and bool(body.call("is_platform_seed")):
			continue
		selected_material_body_id = StringName(body.get("body_id"))
		mark_updated()
		return true
	selected_material_body_id = StringName()
	return false

func select_next_material_body(step_count: int = 1) -> bool:
	var selectable_body_ids: Array[StringName] = []
	for body: Resource in material_bodies:
		if body == null:
			continue
		if not _is_material_body_active(body):
			continue
		selectable_body_ids.append(StringName(body.get("body_id")))
	if selectable_body_ids.is_empty():
		selected_material_body_id = StringName()
		return false
	var current_index: int = selectable_body_ids.find(selected_material_body_id)
	var next_index: int = 0 if current_index < 0 else posmod(current_index + step_count, selectable_body_ids.size())
	selected_material_body_id = selectable_body_ids[next_index]
	mark_updated()
	return true

func remove_selected_material_body() -> bool:
	return remove_material_body(selected_material_body_id)

func remove_material_body(body_id: StringName) -> bool:
	if body_id == StringName():
		return false
	var removed_source_record_ids: Array[StringName] = []
	var retained_bodies: Array[Resource] = []
	var removed := false
	var target_is_committed := false
	for body: Resource in material_bodies:
		if body == null:
			continue
		if StringName(body.get("body_id")) != body_id:
			retained_bodies.append(body)
			continue
		if StringName(body.get("committed_layer_id")) != StringName():
			target_is_committed = true
			retained_bodies.append(body)
			continue
		if body.has_method("is_platform_seed") and bool(body.call("is_platform_seed")):
			retained_bodies.append(body)
			continue
		var source_record_id: StringName = StringName(body.get("source_record_id"))
		if source_record_id != StringName():
			removed_source_record_ids.append(source_record_id)
		removed = true
	if target_is_committed or not removed:
		return false
	material_bodies = retained_bodies
	if not removed_source_record_ids.is_empty():
		_remove_volume_strokes_by_id(removed_source_record_ids)
	if selected_material_body_id == body_id:
		selected_material_body_id = StringName()
		select_last_user_material_body()
	_mark_material_usage_summary_dirty()
	mark_updated()
	return true

func get_material_usage_summary() -> Dictionary:
	if not material_usage_summary_cache_dirty and not material_usage_summary_cache.is_empty():
		return material_usage_summary_cache.duplicate(true)
	var active_bodies: Array[Resource] = []
	for body: Resource in material_bodies:
		if body == null:
			continue
		if body.has_method("normalize"):
			body.call("normalize")
		if not _is_material_body_active(body):
			continue
		active_bodies.append(body)
	var resolver = ForgeV2MaterialVolumeResolverScript.new()
	material_usage_summary_cache = resolver.call("build_usage_summary", active_bodies) as Dictionary
	material_usage_summary_cache_dirty = false
	return material_usage_summary_cache.duplicate(true)

func get_material_usage_label() -> String:
	return _build_material_usage_label(get_material_usage_summary())

func get_cached_material_usage_summary() -> Dictionary:
	if material_usage_summary_cache.is_empty():
		return {}
	return material_usage_summary_cache.duplicate(true)

func get_cached_material_usage_label() -> String:
	if material_usage_summary_cache_dirty:
		return "Rough material: updating after placement"
	return _build_material_usage_label(get_cached_material_usage_summary())

func _build_material_usage_label(usage: Dictionary) -> String:
	var total_units: float = float(usage.get("total_rough_material_units", 0.0))
	var materials: Dictionary = usage.get("materials", {})
	if total_units <= 0.0:
		return "Rough material: 0.00 units"
	var parts: Array[String] = ["Rough material: %.2f units" % total_units]
	for material_variant_id: StringName in materials.keys():
		var entry: Dictionary = materials[material_variant_id]
		var material_units: float = float(entry.get("rough_material_units", 0.0))
		if material_units <= 0.0:
			continue
		parts.append("%s %.2f (%.0f%%)" % [
			String(material_variant_id),
			material_units,
			float(entry.get("ratio", 0.0)) * 100.0,
		])
	return "\n".join(parts)

func get_status_summary(include_material_usage: bool = true) -> Dictionary:
	var resolved_material_usage_summary := get_material_usage_summary() if include_material_usage else get_cached_material_usage_summary()
	var resolved_material_usage_label := get_material_usage_label() if include_material_usage else get_cached_material_usage_label()
	return {
		"schema_id": schema_id,
		"draft_id": draft_id,
		"source_wip_id": source_wip_id,
		"project_name": project_name,
		"builder_scope": get_builder_scope_label(),
		"builder_path": builder_path_id,
		"builder_component": builder_component_id,
		"forge_intent": forge_intent,
		"equipment_context": equipment_context,
		"platform_contract": get_platform_contract(),
		"platform_contract_summary": get_platform_contract_summary(),
		"authoring_space": authoring_space_id,
		"active_tool": active_tool_id,
		"active_tool_label": get_active_tool_label(),
		"active_primitive": active_primitive_id,
		"active_primitive_label": get_active_primitive_label(),
		"active_primitive_summary": get_active_primitive_summary(),
		"operation": active_operation_mode,
		"operation_label": get_operation_label(),
		"placement_policy": placement_policy,
		"placement_policy_label": get_placement_policy_label(),
		"active_material": active_material_variant_id,
		"active_material_label": get_active_material_label(),
		"material_palette_entries": get_material_palette_options(),
		"material_tier_policy": get_material_tier_policy_summary(),
		"brush_radius_meters": active_brush_radius_meters,
		"brush_radius_label": get_brush_radius_label(),
		"amount_ratio": active_amount_ratio,
		"amount_ratio_label": get_amount_ratio_label(),
		"volume_stroke_count": get_volume_stroke_count(),
		"spline_line": get_spline_line_summary(),
		"spline_line_point_count": get_spline_line_point_count(),
		"spline_line_finished": spline_line_finished,
		"spline_line_status_label": get_spline_line_status_label(),
		"spline_line_csg_noodle_enabled": spline_line_csg_noodle_enabled,
		"spline_line_csg_noodle_status_label": get_spline_line_csg_noodle_status_label(),
		"can_generate_spline_line_csg_noodle": can_generate_spline_line_csg_noodle(),
		"selected_spline_point_index": selected_spline_point_index,
		"material_body_count": get_material_body_count(),
		"seed_material_body_count": get_seed_material_body_count(),
		"user_material_body_count": get_user_material_body_count(),
		"pending_material_body_count": get_pending_material_body_count(),
		"committed_layer_count": get_committed_layer_count(),
		"undone_layer_count": get_undone_layer_count(),
		"selected_material_body_id": selected_material_body_id,
		"selected_material_body": _build_selected_material_body_summary(),
		"material_body_stack_entries": get_material_body_stack_entries(),
		"material_usage_summary": resolved_material_usage_summary,
		"material_usage_label": resolved_material_usage_label,
		"material_ledger_summary": get_material_ledger_summary(),
		"material_ledger_label": get_material_ledger_label(),
	}

func build_authoring_export_snapshot() -> Dictionary:
	normalize()
	var material_body_snapshots: Array[Dictionary] = []
	for body: Resource in material_bodies:
		if body == null:
			continue
		if body.has_method("normalize"):
			body.call("normalize")
		material_body_snapshots.append(_build_material_body_export_snapshot(body))
	var layer_snapshots: Array[Dictionary] = []
	for layer: Resource in forge_layers:
		if layer == null:
			continue
		if layer.has_method("normalize"):
			layer.call("normalize")
		layer_snapshots.append(_build_layer_export_snapshot(layer))
	return {
		"schema_id": schema_id,
		"schema_version": schema_version,
		"draft_id": draft_id,
		"source_wip_id": source_wip_id,
		"project_name": project_name,
		"creator_id": creator_id,
		"created_timestamp": created_timestamp,
		"updated_timestamp": updated_timestamp,
		"builder_path_id": builder_path_id,
		"builder_component_id": builder_component_id,
		"forge_intent": forge_intent,
		"equipment_context": equipment_context,
		"authoring_space_id": authoring_space_id,
		"active_tool_id": active_tool_id,
		"platform_contract": get_platform_contract(),
		"spline_line": get_spline_line_summary(),
		"material_usage_summary": get_material_usage_summary(),
		"material_ledger_summary": get_material_ledger_summary(),
		"forge_layers": layer_snapshots,
		"material_bodies": material_body_snapshots,
	}

func mark_updated() -> void:
	updated_timestamp = Time.get_unix_time_from_system()

func _apply_builder_path_defaults() -> void:
	forge_intent = CraftedItemWIPScript.get_default_forge_intent_for_builder_path(builder_path_id)
	equipment_context = CraftedItemWIPScript.get_default_equipment_context_for_builder_path(builder_path_id)

func _append_volume_stroke_record(
	path_points: PackedVector3Array,
	radius_meters: float,
	amount_ratio: float
) -> Resource:
	return _append_material_body_record(path_points, radius_meters, amount_ratio)

func _append_material_body_record(
	path_points: PackedVector3Array,
	radius_meters: float,
	_amount_ratio: float,
	shape_kind: StringName = ForgeV2MaterialBodyScript.SHAPE_KIND_CAPSULE_PATH,
	source_prefix: String = "v2_csg_body"
) -> Resource:
	var body: Resource = ForgeV2MaterialBodyScript.new()
	body.set("source_record_id", StringName("%s_%s" % [source_prefix, str(Time.get_ticks_usec())]))
	body.set("material_variant_id", active_material_variant_id)
	body.set("operation_mode", active_operation_mode)
	body.set("placement_policy", placement_policy)
	body.set("shape_kind", shape_kind)
	body.set("radius_meters", maxf(radius_meters, 0.001))
	body.set("amount_ratio", DEFAULT_AMOUNT_RATIO)
	body.set("path_points", path_points)
	body.set("body_kind", ForgeV2MaterialBodyScript.BODY_KIND_VOLUME_STROKE)
	body.set("seed_role", ForgeV2MaterialBodyScript.SEED_ROLE_NONE)
	body.set("builder_path_id", builder_path_id)
	body.set("builder_component_id", builder_component_id)
	body.set("forge_intent", forge_intent)
	body.set("equipment_context", equipment_context)
	body.set("created_timestamp", Time.get_unix_time_from_system())
	if body.has_method("normalize"):
		body.call("normalize")
	material_bodies.append(body)
	selected_material_body_id = StringName(body.get("body_id"))
	_mark_material_usage_summary_dirty()
	return body

func _build_material_body_from_stroke(stroke: Resource) -> Resource:
	var body: Resource = ForgeV2MaterialBodyScript.new()
	if stroke != null:
		if stroke.has_method("normalize"):
			stroke.call("normalize")
		body.set("source_record_id", StringName(stroke.get("stroke_id")))
		body.set("material_variant_id", StringName(stroke.get("material_variant_id")))
		body.set("operation_mode", StringName(stroke.get("operation_mode")))
		body.set("placement_policy", StringName(stroke.get("placement_policy")))
		body.set("radius_meters", float(stroke.get("radius_meters")))
		body.set("amount_ratio", DEFAULT_AMOUNT_RATIO)
		body.set("path_points", stroke.get("path_points"))
		body.set("created_timestamp", float(stroke.get("created_timestamp")))
	body.set("body_kind", ForgeV2MaterialBodyScript.BODY_KIND_VOLUME_STROKE)
	body.set("seed_role", ForgeV2MaterialBodyScript.SEED_ROLE_NONE)
	body.set("builder_path_id", builder_path_id)
	body.set("builder_component_id", builder_component_id)
	body.set("forge_intent", forge_intent)
	body.set("equipment_context", equipment_context)
	if body.has_method("normalize"):
		body.call("normalize")
	return body

func _append_spline_line_material_body() -> Resource:
	return _append_material_body_record(
		spline_line_points,
		active_brush_radius_meters,
		DEFAULT_AMOUNT_RATIO,
		ForgeV2MaterialBodyScript.SHAPE_KIND_SPLINE_CAPSULE_PATH,
		"v2_spline_noodle"
	)

func _find_material_body_by_id(body_id: StringName) -> Resource:
	if body_id == StringName():
		return null
	for body: Resource in material_bodies:
		if body == null:
			continue
		if StringName(body.get("body_id")) == body_id:
			return body
	return null

func _find_material_body_by_source_record_id(source_record_id: StringName) -> Resource:
	if source_record_id == StringName():
		return null
	for body: Resource in material_bodies:
		if body == null:
			continue
		if StringName(body.get("source_record_id")) == source_record_id:
			return body
	return null

func _find_editable_material_body(body_id_or_source_record_id: StringName) -> Resource:
	var body: Resource = _find_material_body_by_id(body_id_or_source_record_id)
	if body == null:
		body = _find_material_body_by_source_record_id(body_id_or_source_record_id)
	if body == null:
		return null
	if _is_material_body_committed(body):
		return null
	if body.has_method("is_platform_seed") and bool(body.call("is_platform_seed")):
		return null
	if not _is_material_body_active(body):
		return null
	return body

func _find_volume_stroke_by_id(stroke_id: StringName) -> Resource:
	if stroke_id == StringName():
		return null
	for stroke: Resource in volume_strokes:
		if stroke == null:
			continue
		if StringName(stroke.get("stroke_id")) == stroke_id:
			return stroke
	return null

func _is_volume_stroke_committed(stroke_id: StringName) -> bool:
	if stroke_id == StringName():
		return false
	for body: Resource in material_bodies:
		if body == null:
			continue
		if StringName(body.get("source_record_id")) != stroke_id:
			continue
		return _is_material_body_committed(body)
	return false

func _sync_material_body_from_stroke(stroke: Resource) -> void:
	if stroke == null:
		return
	var stroke_id: StringName = StringName(stroke.get("stroke_id"))
	if stroke_id == StringName():
		return
	for body: Resource in material_bodies:
		if body == null:
			continue
		if StringName(body.get("source_record_id")) != stroke_id:
			continue
		body.set("material_variant_id", StringName(stroke.get("material_variant_id")))
		body.set("operation_mode", StringName(stroke.get("operation_mode")))
		body.set("placement_policy", StringName(stroke.get("placement_policy")))
		body.set("radius_meters", float(stroke.get("radius_meters")))
		body.set("amount_ratio", DEFAULT_AMOUNT_RATIO)
		body.set("path_points", stroke.get("path_points"))
		body.set("updated_timestamp", Time.get_unix_time_from_system())
		if body.has_method("normalize"):
			body.call("normalize")
		return

func _build_material_body_stack_entry(body: Resource, body_index: int) -> Dictionary:
	var body_id: StringName = StringName(body.get("body_id"))
	var is_seed_body: bool = body.has_method("is_platform_seed") and bool(body.call("is_platform_seed"))
	var committed_layer_id: StringName = StringName(body.get("committed_layer_id"))
	var is_committed := committed_layer_id != StringName()
	var is_active := _is_material_body_active(body)
	var material_units: float = float(body.call("get_signed_rough_material_units")) if body.has_method("get_signed_rough_material_units") else 0.0
	var operation_mode: StringName = StringName(body.get("operation_mode"))
	var material_variant_id: StringName = StringName(body.get("material_variant_id"))
	var operation_prefix := "-" if operation_mode == OPERATION_REMOVE_MATERIAL else "+"
	var kind_label := "Seed" if is_seed_body else "Body"
	var state_label := "Pending"
	if is_committed:
		state_label = "Layer" if is_active else "Undone"
	return {
		"id": body_id,
		"label": "%s %02d %s %s %s %.2f" % [
			state_label,
			body_index,
			kind_label,
			operation_prefix,
			ForgeV2MaterialPaletteScript.get_material_label(material_variant_id),
			absf(material_units),
		],
		"is_seed": is_seed_body,
		"is_committed": is_committed,
		"committed_layer_id": committed_layer_id,
		"layer_active": is_active,
		"material_variant_id": material_variant_id,
		"material_label": ForgeV2MaterialPaletteScript.get_material_label(material_variant_id),
		"operation_mode": operation_mode,
		"rough_material_units": material_units,
		"body_kind": StringName(body.get("body_kind")),
		"seed_role": StringName(body.get("seed_role")),
	}

func _build_selected_material_body_summary() -> Dictionary:
	var body: Resource = get_selected_material_body()
	if body == null:
		return {}
	return _build_material_body_stack_entry(body, _resolve_material_body_stack_index(selected_material_body_id))

func _build_material_body_export_snapshot(body: Resource) -> Dictionary:
	return {
		"body_id": StringName(body.get("body_id")),
		"body_kind": StringName(body.get("body_kind")),
		"source_record_id": StringName(body.get("source_record_id")),
		"seed_role": StringName(body.get("seed_role")),
		"builder_path_id": StringName(body.get("builder_path_id")),
		"builder_component_id": StringName(body.get("builder_component_id")),
		"forge_intent": StringName(body.get("forge_intent")),
		"equipment_context": StringName(body.get("equipment_context")),
		"material_variant_id": StringName(body.get("material_variant_id")),
		"operation_mode": StringName(body.get("operation_mode")),
		"placement_policy": StringName(body.get("placement_policy")),
		"shape_kind": StringName(body.get("shape_kind")),
		"path_points": body.get("path_points"),
		"radius_meters": float(body.get("radius_meters")),
		"amount_ratio": float(body.get("amount_ratio")),
		"rough_volume_cell_equivalents": float(body.get("rough_volume_cell_equivalents")),
		"rough_material_centi_units": int(body.get("rough_material_centi_units")),
		"rough_material_units": float(body.get("rough_material_units")),
		"signed_rough_material_units": float(body.call("get_signed_rough_material_units")),
		"committed_layer_id": StringName(body.get("committed_layer_id")),
		"layer_active": _is_material_body_active(body),
	}

func _build_layer_export_snapshot(layer: Resource) -> Dictionary:
	return {
		"layer_id": StringName(layer.get("layer_id")),
		"order_index": int(layer.get("order_index")),
		"operation_type": StringName(layer.get("operation_type")),
		"operation_material_id": StringName(layer.get("operation_material_id")),
		"csg_operation": StringName(layer.get("csg_operation")),
		"commit_backend_id": StringName(layer.get("commit_backend_id")),
		"input_shape_type": StringName(layer.get("input_shape_type")),
		"body_ids": layer.get("body_ids"),
		"source_record_ids": layer.get("source_record_ids"),
		"input_shape_records": layer.get("input_shape_records"),
		"ledger_delta": layer.get("ledger_delta"),
		"removed_material_records": layer.get("removed_material_records"),
		"rough_volume_cell_equivalents_delta": float(layer.get("rough_volume_cell_equivalents_delta")),
		"rough_material_centi_units_delta": int(layer.get("rough_material_centi_units_delta")),
		"rough_void_volume_cell_equivalents": float(layer.get("rough_void_volume_cell_equivalents")),
		"rough_void_material_centi_units": int(layer.get("rough_void_material_centi_units")),
		"created_timestamp": float(layer.get("created_timestamp")),
		"undoable": bool(layer.get("undoable")),
	}

func _is_material_body_active(body: Resource) -> bool:
	if body == null:
		return false
	var layer_active_value: Variant = body.get("layer_active")
	return not (layer_active_value is bool) or bool(layer_active_value)

func _is_material_body_committed(body: Resource) -> bool:
	return body != null and StringName(body.get("committed_layer_id")) != StringName()

func _collect_pending_user_material_bodies() -> Array[Resource]:
	var pending_bodies: Array[Resource] = []
	for body: Resource in material_bodies:
		if body == null:
			continue
		if body.has_method("normalize"):
			body.call("normalize")
		if not _is_material_body_active(body):
			continue
		if _is_material_body_committed(body):
			continue
		if body.has_method("is_platform_seed") and bool(body.call("is_platform_seed")):
			continue
		pending_bodies.append(body)
	return pending_bodies

func _collect_committed_active_user_material_bodies() -> Array[Resource]:
	var committed_bodies: Array[Resource] = []
	for body: Resource in material_bodies:
		if body == null:
			continue
		if body.has_method("normalize"):
			body.call("normalize")
		if not _is_material_body_active(body):
			continue
		if not _is_material_body_committed(body):
			continue
		if body.has_method("is_platform_seed") and bool(body.call("is_platform_seed")):
			continue
		committed_bodies.append(body)
	return committed_bodies

func _collect_committed_source_record_ids() -> Array[StringName]:
	var committed_source_record_ids: Array[StringName] = []
	for body: Resource in material_bodies:
		if body == null:
			continue
		if not _is_material_body_committed(body):
			continue
		var source_record_id: StringName = StringName(body.get("source_record_id"))
		if source_record_id != StringName() and not committed_source_record_ids.has(source_record_id):
			committed_source_record_ids.append(source_record_id)
	return committed_source_record_ids

func _remove_pending_volume_strokes() -> void:
	var committed_source_record_ids := _collect_committed_source_record_ids()
	var retained_strokes: Array[Resource] = []
	for stroke: Resource in volume_strokes:
		if stroke == null:
			continue
		if committed_source_record_ids.has(StringName(stroke.get("stroke_id"))):
			retained_strokes.append(stroke)
	volume_strokes = retained_strokes

func _remove_pending_user_material_bodies() -> void:
	var retained_bodies: Array[Resource] = []
	for body: Resource in material_bodies:
		if body == null:
			continue
		if body.has_method("is_platform_seed") and bool(body.call("is_platform_seed")):
			retained_bodies.append(body)
			continue
		if _is_material_body_committed(body):
			retained_bodies.append(body)
	material_bodies = retained_bodies

func _normalize_forge_layers() -> void:
	var normalized_layers: Array[Resource] = []
	for layer: Resource in forge_layers:
		if layer == null:
			continue
		if layer.has_method("normalize"):
			layer.call("normalize")
		normalized_layers.append(layer)
	forge_layers = normalized_layers
	var normalized_undone_layers: Array[Resource] = []
	for layer: Resource in undone_forge_layers:
		if layer == null:
			continue
		if layer.has_method("normalize"):
			layer.call("normalize")
		normalized_undone_layers.append(layer)
	undone_forge_layers = normalized_undone_layers

func _ensure_material_ledger() -> void:
	if material_ledger == null or not material_ledger.has_method("rebuild_from_layers"):
		material_ledger = ForgeV2MaterialLedgerScript.new()

func _mark_material_usage_summary_dirty() -> void:
	material_usage_summary_cache_dirty = true
	material_usage_summary_cache = {}

func _rebuild_material_ledger() -> void:
	_ensure_material_ledger()
	if material_ledger != null:
		material_ledger.call("rebuild_from_layers", forge_layers)

func _set_layer_bodies_active(layer: Resource, is_active: bool) -> void:
	if layer == null:
		return
	var layer_body_ids: Array = layer.get("body_ids") as Array
	for body: Resource in material_bodies:
		if body == null:
			continue
		if layer_body_ids.has(StringName(body.get("body_id"))):
			body.set("layer_active", is_active)
	if not is_active and get_selected_material_body() == null:
		select_last_user_material_body()

func _resolve_material_body_stack_index(body_id: StringName) -> int:
	var body_index := 0
	for body: Resource in material_bodies:
		if body == null:
			continue
		if not _is_material_body_active(body):
			continue
		body_index += 1
		if StringName(body.get("body_id")) == body_id:
			return body_index
	return 0

func _normalize_selected_material_body_id() -> void:
	if selected_material_body_id == StringName():
		return
	for body: Resource in material_bodies:
		if (
			body != null
			and _is_material_body_active(body)
			and StringName(body.get("body_id")) == selected_material_body_id
		):
			return
	selected_material_body_id = StringName()

func _remove_volume_strokes_by_id(stroke_ids: Array[StringName]) -> void:
	var retained_strokes: Array[Resource] = []
	for stroke: Resource in volume_strokes:
		if stroke == null:
			continue
		if stroke_ids.has(StringName(stroke.get("stroke_id"))):
			continue
		retained_strokes.append(stroke)
	volume_strokes = retained_strokes

func _normalize_brush_radius(radius_meters: float) -> float:
	var clamped_radius: float = clampf(radius_meters, BRUSH_RADIUS_MIN_METERS, BRUSH_RADIUS_MAX_METERS)
	var snapped_steps: int = roundi((clamped_radius - BRUSH_RADIUS_MIN_METERS) / BRUSH_RADIUS_STEP_METERS)
	return clampf(
		BRUSH_RADIUS_MIN_METERS + (float(snapped_steps) * BRUSH_RADIUS_STEP_METERS),
		BRUSH_RADIUS_MIN_METERS,
		BRUSH_RADIUS_MAX_METERS
	)

func _normalize_amount_ratio(_amount_ratio: float) -> float:
	return DEFAULT_AMOUNT_RATIO

func _normalize_material_bodies() -> void:
	var normalized_bodies: Array[Resource] = []
	for body: Resource in material_bodies:
		if body == null:
			continue
		if body.has_method("normalize"):
			body.call("normalize")
		normalized_bodies.append(body)
	material_bodies = normalized_bodies

func _ensure_platform_seed_bodies() -> void:
	var expected_seed_specs: Array[Dictionary] = _build_expected_platform_seed_specs()
	var expected_seed_roles: Array[StringName] = []
	for seed_spec: Dictionary in expected_seed_specs:
		expected_seed_roles.append(StringName(seed_spec.get("seed_role", StringName())))
	var retained_bodies: Array[Resource] = []
	for body: Resource in material_bodies:
		if body == null:
			continue
		var is_seed_body: bool = body.has_method("is_platform_seed") and bool(body.call("is_platform_seed"))
		if is_seed_body:
			var matches_current_scope := (
				StringName(body.get("builder_path_id")) == builder_path_id
				and StringName(body.get("builder_component_id")) == builder_component_id
				and expected_seed_roles.has(StringName(body.get("seed_role")))
			)
			if not matches_current_scope:
				continue
		retained_bodies.append(body)
	material_bodies = retained_bodies
	for seed_spec: Dictionary in expected_seed_specs:
		var seed_role: StringName = StringName(seed_spec.get("seed_role", StringName()))
		if _has_platform_seed_body(seed_role):
			continue
		material_bodies.append(_build_platform_seed_body(seed_spec))

func _build_platform_seed_body(seed_spec: Dictionary) -> Resource:
	var body: Resource = ForgeV2MaterialBodyScript.new()
	body.set("body_kind", ForgeV2MaterialBodyScript.BODY_KIND_PLATFORM_SEED)
	body.set("seed_role", StringName(seed_spec.get("seed_role", StringName())))
	body.set("builder_path_id", builder_path_id)
	body.set("builder_component_id", builder_component_id)
	body.set("forge_intent", forge_intent)
	body.set("equipment_context", equipment_context)
	body.set("material_variant_id", active_material_variant_id)
	body.set("operation_mode", OPERATION_ADD_MATERIAL)
	body.set("placement_policy", PLACEMENT_EMPTY_ONLY)
	body.set("path_points", seed_spec.get("path_points", PackedVector3Array()) as PackedVector3Array)
	body.set("radius_meters", float(seed_spec.get("radius_meters", 0.02)))
	body.set("created_timestamp", Time.get_unix_time_from_system())
	if body.has_method("normalize"):
		body.call("normalize")
	return body

func _build_expected_platform_seed_specs() -> Array[Dictionary]:
	match builder_path_id:
		CraftedItemWIPScript.BUILDER_PATH_SHIELD:
			return [{
				"seed_role": ForgeV2MaterialBodyScript.SEED_ROLE_SHIELD_FIXED_HANDLE,
				"path_points": PackedVector3Array([
					Vector3(-0.14, 0.0, 0.0),
					Vector3(0.14, 0.0, 0.0),
				]),
				"radius_meters": 0.021,
			}]
		CraftedItemWIPScript.BUILDER_PATH_RANGED_PHYSICAL:
			if builder_component_id == CraftedItemWIPScript.BUILDER_COMPONENT_BOW:
				return [{
					"seed_role": ForgeV2MaterialBodyScript.SEED_ROLE_RANGED_BOW_HANDLE_ANCHOR,
					"path_points": PackedVector3Array([
						Vector3(0.0, -0.18, 0.0),
						Vector3(0.0, 0.18, 0.0),
					]),
					"radius_meters": 0.019,
				}]
	return []

func _has_platform_seed_body(seed_role: StringName) -> bool:
	for body: Resource in material_bodies:
		if body == null:
			continue
		if not body.has_method("is_platform_seed") or not bool(body.call("is_platform_seed")):
			continue
		if (
			StringName(body.get("seed_role")) == seed_role
			and StringName(body.get("builder_path_id")) == builder_path_id
			and StringName(body.get("builder_component_id")) == builder_component_id
		):
			return true
	return false

func _remove_non_seed_material_bodies() -> void:
	var retained_bodies: Array[Resource] = []
	for body: Resource in material_bodies:
		if body == null:
			continue
		if body.has_method("is_platform_seed") and bool(body.call("is_platform_seed")):
			retained_bodies.append(body)
	material_bodies = retained_bodies

func _normalize_volume_strokes() -> void:
	var migrated_any := false
	for stroke: Resource in volume_strokes:
		if stroke == null:
			continue
		if stroke.has_method("normalize"):
			stroke.call("normalize")
		var stroke_id := StringName(stroke.get("stroke_id"))
		if stroke_id == StringName():
			continue
		if _find_material_body_by_source_record_id(stroke_id) != null:
			continue
		material_bodies.append(_build_material_body_from_stroke(stroke))
		migrated_any = true
	volume_strokes = []
	if migrated_any:
		_mark_material_usage_summary_dirty()

func _normalize_spline_line() -> void:
	if selected_spline_point_index >= spline_line_points.size():
		selected_spline_point_index = -1
	if selected_spline_point_index < -1:
		selected_spline_point_index = -1
	if spline_line_points.size() < 2:
		spline_line_finished = false

func _build_sample_stroke_points(stroke_index: int) -> PackedVector3Array:
	var z_offset := (float(stroke_index % 4) - 1.5) * 0.12
	var y_offset := float(stroke_index / 4) * 0.10
	return PackedVector3Array([
		Vector3(-0.42, -0.02 + y_offset, z_offset),
		Vector3(-0.20, 0.05 + y_offset, z_offset + 0.04),
		Vector3(0.04, -0.03 + y_offset, z_offset - 0.04),
		Vector3(0.25, 0.04 + y_offset, z_offset + 0.03),
		Vector3(0.42, 0.00 + y_offset, z_offset),
	])
