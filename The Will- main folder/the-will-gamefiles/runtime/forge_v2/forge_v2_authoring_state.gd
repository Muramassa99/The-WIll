extends Resource
class_name ForgeV2AuthoringState

const CraftedItemWIPScript = preload("res://core/models/crafted_item_wip.gd")
const ForgeV2LayerDataScript = preload("res://runtime/forge_v2/forge_v2_layer_data.gd")
const ForgeV2HistoryCheckpointScript = preload(
	"res://runtime/forge_v2/forge_v2_history_checkpoint.gd"
)
const ForgeV2MaterialBodyScript = preload("res://runtime/forge_v2/forge_v2_material_body.gd")
const ForgeV2MaterialCompositionPolicyScript = preload(
	"res://runtime/forge_v2/forge_v2_material_composition_policy.gd"
)
const ForgeV2MaterialLedgerScript = preload("res://runtime/forge_v2/forge_v2_material_ledger.gd")
const ForgeV2MaterialPaletteScript = preload("res://runtime/forge_v2/forge_v2_material_palette.gd")
const ForgeV2ProfileShapeLibraryScript = preload("res://runtime/forge_v2/forge_v2_profile_shape_library.gd")
const ForgeV2MaterialTierPolicyScript = preload("res://runtime/forge_v2/forge_v2_material_tier_policy.gd")
const ForgeV2MaterialVolumeResolverScript = preload("res://runtime/forge_v2/forge_v2_material_volume_resolver.gd")
const ForgeV2PlatformContractScript = preload("res://runtime/forge_v2/forge_v2_platform_contract.gd")
const ForgeV2PrimitiveCatalogScript = preload("res://runtime/forge_v2/forge_v2_primitive_catalog.gd")
const ForgeV2VolumeStrokeScript = preload("res://runtime/forge_v2/forge_v2_volume_stroke.gd")

const SCHEMA_VERSION := 6
const SCHEMA_ID := &"forge_stage1_v2"

const AUTHORING_SPACE_WORLD_3D := &"authoring_space_world_3d"
const TOOL_VOLUME_STROKE := &"tool_volume_stroke"
const TOOL_SPLINE_LINE := &"tool_spline_line"
const TOOL_HANDLES := &"tool_handles"
const TOOL_DETAILING_BRUSH := &"tool_detailing_brush"
const DETAIL_SOLUTION_REASON_NONE := &"none"
const DETAIL_SOLUTION_REASON_NOT_READY := &"not_ready"
const DETAIL_SOLUTION_REASON_INVALID_PERSISTED := &"invalid_persisted_solution"
const BASIC_SHAPE_SOURCE_PRIMITIVE := &"basic_shape_source_primitive"
const BASIC_SHAPE_SOURCE_SAVED_PROFILE := &"basic_shape_source_saved_profile"
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
const HANDLE_PATH_MODE_THREE_POINT_SPLINE := &"handle_path_3_point_spline"
const HANDLE_PATH_MODE_THREE_POINT_LINEAR := &"handle_path_3_point_linear"
const HANDLE_PATH_MODE_TWO_POINT_LINEAR := &"handle_path_2_point_linear"
const HANDLE_THREE_POINT_COUNT := 3
const HANDLE_TWO_POINT_COUNT := 2
const HANDLE_MIN_AXIAL_SPAN_METERS := (
	ForgeV2ProfileShapeLibraryScript.DEFAULT_CELL_WORLD_SIZE_METERS * 20.0
)
const PROFILE_SIZE_MIN_METERS := ForgeV2ProfileShapeLibraryScript.DEFAULT_CELL_WORLD_SIZE_METERS
const PROFILE_SIZE_MAX_METERS := 4.0
const PROFILE_ROTATION_MIN_DEGREES := -360.0
const PROFILE_ROTATION_MAX_DEGREES := 360.0
const BOUNDED_HISTORY_TAIL_CAPACITY := 5
const BOUNDED_HISTORY_TRANSITION_NONE := &"none"
const BOUNDED_HISTORY_TRANSITION_RESET := &"reset"
const BOUNDED_HISTORY_TRANSITION_APPEND := &"append"
const BOUNDED_HISTORY_TRANSITION_PROMOTION_APPEND := &"promotion_append"
const BOUNDED_HISTORY_TRANSITION_UNDO := &"undo"
const BOUNDED_HISTORY_TRANSITION_REDO := &"redo"
const BOUNDED_HISTORY_TRANSITION_RESTORE := &"restore"
const BOUNDED_HISTORY_TRANSITION_FALLBACK := &"fallback_full_refresh"
const BOUNDED_HISTORY_TRANSITION_PROTECTED_CHANGED := &"protected_changed"
const BOUNDED_HISTORY_SUSPENDED_NONE := &"none"
const EDITOR_TRANSIENT_SNAPSHOT_SCHEMA_ID := (
	&"forge_v2_editor_transient_snapshot_v1"
)
const PENDING_BODY_BUNDLE_SCHEMA_ID := &"forge_v2_pending_body_bundle_v1"
const PROTECTED_HANDLE_SNAPSHOT_SCHEMA_ID := (
	&"forge_v2_protected_handle_snapshot_v1"
)

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
@export var active_basic_shape_source_id: StringName = BASIC_SHAPE_SOURCE_PRIMITIVE
@export var active_saved_basic_profile_id: StringName = StringName()
@export var active_saved_basic_profile_data: Dictionary = {}
@export var active_profile_id: StringName = StringName()
@export var active_profile_width_meters: float = 0.0
@export var active_profile_height_meters: float = 0.0
@export var active_profile_anchor_x_meters: float = 0.0
@export var active_profile_anchor_y_meters: float = 0.0
@export var active_profile_rotation_degrees: float = 0.0
@export var active_profile_display_name: String = ""
@export var active_handle_face_count: int = ForgeV2ProfileShapeLibraryScript.HANDLE_FACE_COUNT_RECTANGLE
@export var active_handle_rounding_enabled: bool = true
@export var active_handle_corner_radius_meters: float = ForgeV2ProfileShapeLibraryScript.HANDLE_DEFAULT_CORNER_RADIUS_METERS
@export var active_handle_control_points_2d_meters: PackedVector2Array = PackedVector2Array()
@export var active_handle_grid_snapping_enabled: bool = false
@export var active_handle_source_profile_id: StringName = StringName()
@export var active_handle_path_mode_id: StringName = (
	HANDLE_PATH_MODE_THREE_POINT_SPLINE
)
@export var active_basic_control_points_2d_meters: PackedVector2Array = PackedVector2Array()
@export var active_basic_corner_metadata: Array[Dictionary] = []
@export var active_basic_next_corner_serial: int = 1
@export var active_basic_grid_snapping_enabled: bool = false
@export var active_operation_mode: StringName = OPERATION_ADD_MATERIAL
@export var placement_policy: StringName = PLACEMENT_REPLACE_EXISTING
@export var active_material_variant_id: StringName = &"mat_iron_gray"
@export var active_brush_radius_meters: float = DEFAULT_POINT_PLACEMENT_RADIUS_METERS
@export var active_amount_ratio: float = DEFAULT_AMOUNT_RATIO
@export var selected_material_body_id: StringName = StringName()
@export var material_bodies: Array[Resource] = []
@export var volume_strokes: Array[Resource] = []
@export var spline_line_points: PackedVector3Array = PackedVector3Array()
@export var spline_line_surface_normals: PackedVector3Array = PackedVector3Array()
@export var spline_line_finished: bool = false
@export var selected_spline_point_index: int = -1
@export var spline_line_csg_noodle_enabled: bool = false
@export var detailing_surface_target_kind: StringName = StringName()
@export var detailing_surface_target_id: StringName = StringName()
@export var detailing_control_contact_directions: PackedVector3Array = PackedVector3Array()
@export var detailing_resolved_path_points: PackedVector3Array = PackedVector3Array()
@export var detailing_resolved_surface_normals: PackedVector3Array = PackedVector3Array()
@export var detailing_resolved_contact_directions: PackedVector3Array = PackedVector3Array()
@export var detailing_span_offsets: PackedInt32Array = PackedInt32Array()
@export var detailing_span_validity: Array[bool] = []
@export var detailing_span_reasons: Array[StringName] = []
@export var detailing_solution_valid: bool = false
@export var detailing_solution_reason: StringName = DETAIL_SOLUTION_REASON_NOT_READY
@export var forge_layers: Array[Resource] = []
@export var undone_forge_layers: Array[Resource] = []
@export var protected_forge_layers: Array[Resource] = []
@export var material_ledger: Resource = null
@export var bounded_history_enabled: bool = true
@export var bounded_history_suspended_reason: StringName = (
	BOUNDED_HISTORY_SUSPENDED_NONE
)
@export var bounded_history_recovery_blocked_reason: StringName = StringName()
@export var bounded_history_checkpoint: Resource = null
@export var bounded_history_lifetime_operation_count: int = 0
@export var bounded_history_transition_revision: int = 0

var material_usage_summary_cache: Dictionary = {}
var material_usage_summary_cache_dirty: bool = true
var committed_volume_resolver: RefCounted = null
var committed_volume_cache_diagnostics: Dictionary = {}
var _bounded_history_transition: Dictionary = {}
var _bounded_history_pending_promotion: Dictionary = {}
var _bounded_history_checkpoint_export_provider: Callable = Callable()
var _runtime_contract_mesh_export_provider: Callable = Callable()
var _bounded_history_normalized_once: bool = false
var _handle_change_original_body: Resource = null
var _handle_change_original_body_index: int = -1
var _handle_change_original_protected_layer: Resource = null
var _handle_change_original_protected_layer_index: int = -1
var _handle_change_initial_profile_signature: String = ""
var _handle_change_source_profile_id: StringName = StringName()
var _handle_change_last_reason: StringName = &"none"

func reset_new_draft(next_project_name: String = "Stage 1 V2 Draft") -> void:
	_reset_committed_volume_cache(&"new_draft")
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
	active_basic_shape_source_id = BASIC_SHAPE_SOURCE_PRIMITIVE
	active_saved_basic_profile_id = StringName()
	active_saved_basic_profile_data = {}
	active_profile_id = ForgeV2ProfileShapeLibraryScript.get_default_profile_id()
	active_profile_width_meters = 0.0
	active_profile_height_meters = 0.0
	active_profile_anchor_x_meters = 0.0
	active_profile_anchor_y_meters = 0.0
	active_profile_rotation_degrees = 0.0
	active_profile_display_name = ""
	active_handle_face_count = ForgeV2ProfileShapeLibraryScript.HANDLE_FACE_COUNT_RECTANGLE
	active_handle_rounding_enabled = true
	active_handle_corner_radius_meters = ForgeV2ProfileShapeLibraryScript.HANDLE_DEFAULT_CORNER_RADIUS_METERS
	active_handle_control_points_2d_meters = PackedVector2Array()
	active_handle_grid_snapping_enabled = false
	active_handle_source_profile_id = StringName()
	active_handle_path_mode_id = HANDLE_PATH_MODE_THREE_POINT_SPLINE
	active_basic_control_points_2d_meters = PackedVector2Array()
	active_basic_corner_metadata = []
	active_basic_next_corner_serial = 1
	active_basic_grid_snapping_enabled = false
	active_operation_mode = OPERATION_ADD_MATERIAL
	placement_policy = PLACEMENT_REPLACE_EXISTING
	active_material_variant_id = &"mat_iron_gray"
	active_brush_radius_meters = DEFAULT_POINT_PLACEMENT_RADIUS_METERS
	active_amount_ratio = DEFAULT_AMOUNT_RATIO
	selected_material_body_id = StringName()
	material_bodies = []
	volume_strokes = []
	spline_line_points = PackedVector3Array()
	spline_line_surface_normals = PackedVector3Array()
	spline_line_finished = false
	selected_spline_point_index = -1
	spline_line_csg_noodle_enabled = false
	_clear_detailing_brush_solution()
	forge_layers = []
	undone_forge_layers = []
	protected_forge_layers = []
	material_ledger = ForgeV2MaterialLedgerScript.new()
	bounded_history_enabled = true
	bounded_history_suspended_reason = BOUNDED_HISTORY_SUSPENDED_NONE
	bounded_history_recovery_blocked_reason = StringName()
	bounded_history_checkpoint = ForgeV2HistoryCheckpointScript.new()
	bounded_history_lifetime_operation_count = 0
	bounded_history_transition_revision = 0
	_bounded_history_transition = {}
	_bounded_history_pending_promotion = {}
	_bounded_history_normalized_once = false
	_clear_handle_change_transaction()
	_mark_material_usage_summary_dirty()
	normalize()

func normalize() -> void:
	_reset_committed_volume_cache(&"state_normalized")
	var loaded_schema_version := schema_version
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
	if not _is_valid_tool_id(active_tool_id):
		active_tool_id = TOOL_VOLUME_STROKE
	active_handle_path_mode_id = _normalize_handle_path_mode_id(
		active_handle_path_mode_id
	)
	active_primitive_id = ForgeV2PrimitiveCatalogScript.normalize_primitive_id(active_primitive_id)
	_normalize_active_basic_shape_authority()
	active_profile_id = ForgeV2ProfileShapeLibraryScript.normalize_profile_id(active_profile_id, _get_active_profile_family())
	_normalize_active_profile_settings()
	if active_operation_mode != OPERATION_REMOVE_MATERIAL:
		active_operation_mode = OPERATION_ADD_MATERIAL
	if placement_policy != PLACEMENT_EMPTY_ONLY:
		placement_policy = PLACEMENT_REPLACE_EXISTING
	active_material_variant_id = ForgeV2MaterialPaletteScript.normalize_material_variant_id(active_material_variant_id)
	active_brush_radius_meters = _normalize_brush_radius(active_brush_radius_meters)
	active_amount_ratio = _normalize_amount_ratio(active_amount_ratio)
	_migrate_legacy_surface_contact_authority(loaded_schema_version)
	_normalize_material_bodies()
	_normalize_active_handle_path_mode_from_body()
	_ensure_platform_seed_bodies()
	_normalize_volume_strokes()
	_normalize_spline_line()
	_normalize_forge_layers()
	_normalize_bounded_history(loaded_schema_version)
	_ensure_material_ledger()
	if (
		(
			not forge_layers.is_empty()
			or not protected_forge_layers.is_empty()
			or _has_bounded_history_checkpoint()
		)
		and (
			not had_valid_material_ledger
			or loaded_schema_version < SCHEMA_VERSION
		)
	):
		_rebuild_material_ledger()
	_normalize_selected_material_body_id()

func capture_editor_transient_snapshot() -> Dictionary:
	# This is deliberately not an authoring-state duplicate. Undoing a point or
	# profile edit must never retain the CSG body stack, layers, ledger, or baked
	# checkpoint through an otherwise lightweight editor action.
	return {
		"schema_id": EDITOR_TRANSIENT_SNAPSHOT_SCHEMA_ID,
		"schema_version": 1,
		"active_tool_id": active_tool_id,
		"active_basic_shape_source_id": active_basic_shape_source_id,
		"active_saved_basic_profile_id": active_saved_basic_profile_id,
		"active_saved_basic_profile_data": (
			active_saved_basic_profile_data.duplicate(true)
		),
		"active_profile_id": active_profile_id,
		"active_profile_width_meters": active_profile_width_meters,
		"active_profile_height_meters": active_profile_height_meters,
		"active_profile_anchor_x_meters": active_profile_anchor_x_meters,
		"active_profile_anchor_y_meters": active_profile_anchor_y_meters,
		"active_profile_rotation_degrees": active_profile_rotation_degrees,
		"active_profile_display_name": active_profile_display_name,
		"active_handle_face_count": active_handle_face_count,
		"active_handle_rounding_enabled": active_handle_rounding_enabled,
		"active_handle_corner_radius_meters": (
			active_handle_corner_radius_meters
		),
		"active_handle_control_points_2d_meters": (
			active_handle_control_points_2d_meters.duplicate()
		),
		"active_handle_grid_snapping_enabled": (
			active_handle_grid_snapping_enabled
		),
		"active_handle_source_profile_id": active_handle_source_profile_id,
		"active_handle_path_mode_id": active_handle_path_mode_id,
		"active_basic_control_points_2d_meters": (
			active_basic_control_points_2d_meters.duplicate()
		),
		"active_basic_corner_metadata": _duplicate_basic_corner_metadata(),
		"active_basic_next_corner_serial": active_basic_next_corner_serial,
		"active_basic_grid_snapping_enabled": (
			active_basic_grid_snapping_enabled
		),
		"spline_line_points": spline_line_points.duplicate(),
		"spline_line_surface_normals": (
			spline_line_surface_normals.duplicate()
		),
		"spline_line_finished": spline_line_finished,
		"selected_spline_point_index": selected_spline_point_index,
		"spline_line_csg_noodle_enabled": spline_line_csg_noodle_enabled,
		"detailing_surface_target_kind": detailing_surface_target_kind,
		"detailing_surface_target_id": detailing_surface_target_id,
		"detailing_control_contact_directions": (
			detailing_control_contact_directions.duplicate()
		),
		"detailing_resolved_path_points": (
			detailing_resolved_path_points.duplicate()
		),
		"detailing_resolved_surface_normals": (
			detailing_resolved_surface_normals.duplicate()
		),
		"detailing_resolved_contact_directions": (
			detailing_resolved_contact_directions.duplicate()
		),
		"detailing_span_offsets": detailing_span_offsets.duplicate(),
		"detailing_span_validity": detailing_span_validity.duplicate(),
		"detailing_span_reasons": detailing_span_reasons.duplicate(),
		"detailing_solution_valid": detailing_solution_valid,
		"detailing_solution_reason": detailing_solution_reason,
	}

func restore_editor_transient_snapshot(snapshot: Dictionary) -> bool:
	if (
		StringName(snapshot.get("schema_id", StringName()))
		!= EDITOR_TRANSIENT_SNAPSHOT_SCHEMA_ID
		or int(snapshot.get("schema_version", 0)) != 1
	):
		return false
	var restored_basic_corner_metadata: Array[Dictionary] = []
	for metadata_variant: Variant in snapshot.get(
		"active_basic_corner_metadata",
		[]
	) as Array:
		if not metadata_variant is Dictionary:
			return false
		restored_basic_corner_metadata.append(
			(metadata_variant as Dictionary).duplicate(true)
		)
	var restored_span_validity: Array[bool] = []
	for validity_variant: Variant in snapshot.get(
		"detailing_span_validity",
		[]
	) as Array:
		restored_span_validity.append(bool(validity_variant))
	var restored_span_reasons: Array[StringName] = []
	for reason_variant: Variant in snapshot.get(
		"detailing_span_reasons",
		[]
	) as Array:
		restored_span_reasons.append(StringName(reason_variant))

	# Assign directly so restoring editor data cannot cancel a Handle-change
	# transaction or publish a material-history transition through a setter.
	active_tool_id = StringName(snapshot.get("active_tool_id", TOOL_VOLUME_STROKE))
	if not _is_valid_tool_id(active_tool_id):
		active_tool_id = TOOL_VOLUME_STROKE
	active_basic_shape_source_id = StringName(snapshot.get(
		"active_basic_shape_source_id",
		BASIC_SHAPE_SOURCE_PRIMITIVE
	))
	active_saved_basic_profile_id = StringName(snapshot.get(
		"active_saved_basic_profile_id",
		StringName()
	))
	active_saved_basic_profile_data = (
		(snapshot.get("active_saved_basic_profile_data", {}) as Dictionary)
		.duplicate(true)
	)
	active_profile_id = StringName(snapshot.get(
		"active_profile_id",
		StringName()
	))
	active_profile_width_meters = float(snapshot.get(
		"active_profile_width_meters",
		0.0
	))
	active_profile_height_meters = float(snapshot.get(
		"active_profile_height_meters",
		0.0
	))
	active_profile_anchor_x_meters = float(snapshot.get(
		"active_profile_anchor_x_meters",
		0.0
	))
	active_profile_anchor_y_meters = float(snapshot.get(
		"active_profile_anchor_y_meters",
		0.0
	))
	active_profile_rotation_degrees = float(snapshot.get(
		"active_profile_rotation_degrees",
		0.0
	))
	active_profile_display_name = String(snapshot.get(
		"active_profile_display_name",
		""
	))
	active_handle_face_count = int(snapshot.get(
		"active_handle_face_count",
		ForgeV2ProfileShapeLibraryScript.HANDLE_FACE_COUNT_RECTANGLE
	))
	active_handle_rounding_enabled = bool(snapshot.get(
		"active_handle_rounding_enabled",
		true
	))
	active_handle_corner_radius_meters = float(snapshot.get(
		"active_handle_corner_radius_meters",
		ForgeV2ProfileShapeLibraryScript.HANDLE_DEFAULT_CORNER_RADIUS_METERS
	))
	active_handle_control_points_2d_meters = (
		(snapshot.get(
			"active_handle_control_points_2d_meters",
			PackedVector2Array()
		) as PackedVector2Array).duplicate()
	)
	active_handle_grid_snapping_enabled = bool(snapshot.get(
		"active_handle_grid_snapping_enabled",
		false
	))
	active_handle_source_profile_id = StringName(snapshot.get(
		"active_handle_source_profile_id",
		StringName()
	))
	active_handle_path_mode_id = _normalize_handle_path_mode_id(StringName(
		snapshot.get(
			"active_handle_path_mode_id",
			HANDLE_PATH_MODE_THREE_POINT_SPLINE
		)
	))
	active_basic_control_points_2d_meters = (
		(snapshot.get(
			"active_basic_control_points_2d_meters",
			PackedVector2Array()
		) as PackedVector2Array).duplicate()
	)
	active_basic_corner_metadata = restored_basic_corner_metadata
	active_basic_next_corner_serial = int(snapshot.get(
		"active_basic_next_corner_serial",
		1
	))
	active_basic_grid_snapping_enabled = bool(snapshot.get(
		"active_basic_grid_snapping_enabled",
		false
	))
	spline_line_points = (
		(snapshot.get("spline_line_points", PackedVector3Array())
		as PackedVector3Array).duplicate()
	)
	spline_line_surface_normals = (
		(snapshot.get("spline_line_surface_normals", PackedVector3Array())
		as PackedVector3Array).duplicate()
	)
	spline_line_finished = bool(snapshot.get("spline_line_finished", false))
	selected_spline_point_index = int(snapshot.get(
		"selected_spline_point_index",
		-1
	))
	spline_line_csg_noodle_enabled = bool(snapshot.get(
		"spline_line_csg_noodle_enabled",
		false
	))
	detailing_surface_target_kind = StringName(snapshot.get(
		"detailing_surface_target_kind",
		StringName()
	))
	detailing_surface_target_id = StringName(snapshot.get(
		"detailing_surface_target_id",
		StringName()
	))
	detailing_control_contact_directions = (
		(snapshot.get(
			"detailing_control_contact_directions",
			PackedVector3Array()
		) as PackedVector3Array).duplicate()
	)
	detailing_resolved_path_points = (
		(snapshot.get(
			"detailing_resolved_path_points",
			PackedVector3Array()
		) as PackedVector3Array).duplicate()
	)
	detailing_resolved_surface_normals = (
		(snapshot.get(
			"detailing_resolved_surface_normals",
			PackedVector3Array()
		) as PackedVector3Array).duplicate()
	)
	detailing_resolved_contact_directions = (
		(snapshot.get(
			"detailing_resolved_contact_directions",
			PackedVector3Array()
		) as PackedVector3Array).duplicate()
	)
	detailing_span_offsets = (
		(snapshot.get("detailing_span_offsets", PackedInt32Array())
		as PackedInt32Array).duplicate()
	)
	detailing_span_validity = restored_span_validity
	detailing_span_reasons = restored_span_reasons
	detailing_solution_valid = bool(snapshot.get(
		"detailing_solution_valid",
		false
	))
	detailing_solution_reason = StringName(snapshot.get(
		"detailing_solution_reason",
		DETAIL_SOLUTION_REASON_NOT_READY
	))

	_normalize_active_basic_shape_authority()
	active_profile_id = ForgeV2ProfileShapeLibraryScript.normalize_profile_id(
		active_profile_id,
		_get_active_profile_family()
	)
	_normalize_active_profile_settings()
	_normalize_spline_line()
	mark_updated()
	return true


## Fast replay lane for the high-frequency spline point actions. It accepts
## only append/remove-last or replace-in-place Vector3 splices plus the selected
## point scalar. Broader editor deltas continue through the complete snapshot
## restorer so this optimization cannot mutate unrelated authoring authority.
func apply_spline_path_action_delta(
	delta: Dictionary,
	use_after: bool
) -> bool:
	var changes := delta.get("changes", {}) as Dictionary
	if changes.is_empty():
		return false
	for key_variant: Variant in changes.keys():
		if String(key_variant) not in [
			"spline_line_points",
			"spline_line_surface_normals",
			"selected_spline_point_index",
		]:
			return false
	var point_change := changes.get("spline_line_points", {}) as Dictionary
	var normal_change := changes.get(
		"spline_line_surface_normals",
		{}
	) as Dictionary
	var selection_change := changes.get(
		"selected_spline_point_index",
		{}
	) as Dictionary
	if (
		not point_change.is_empty()
		and not _simple_path_splice_is_valid(
			spline_line_points,
			point_change,
			use_after
		)
	):
		return false
	if (
		not normal_change.is_empty()
		and not _simple_path_splice_is_valid(
			spline_line_surface_normals,
			normal_change,
			use_after
		)
	):
		return false
	if not selection_change.is_empty():
		if StringName(selection_change.get("mode", StringName())) != &"replace":
			return false
		var source_selection := int(selection_change.get(
			"before" if use_after else "after",
			-2
		))
		if selected_spline_point_index != source_selection:
			return false
	var next_point_count := (
		int(point_change.get(
			"after_size" if use_after else "before_size",
			spline_line_points.size()
		))
		if not point_change.is_empty()
		else spline_line_points.size()
	)
	var next_normal_count := (
		int(normal_change.get(
			"after_size" if use_after else "before_size",
			spline_line_surface_normals.size()
		))
		if not normal_change.is_empty()
		else spline_line_surface_normals.size()
	)
	if next_point_count != next_normal_count:
		return false
	if not point_change.is_empty():
		_apply_simple_path_splice_to_points(point_change, use_after)
	if not normal_change.is_empty():
		_apply_simple_path_splice_to_normals(normal_change, use_after)
	if not selection_change.is_empty():
		selected_spline_point_index = int(selection_change.get(
			"after" if use_after else "before",
			-1
		))
	if spline_line_points.size() != spline_line_surface_normals.size():
		return false
	mark_updated()
	return true


func _simple_path_splice_is_valid(
	current: PackedVector3Array,
	change: Dictionary,
	use_after: bool
) -> bool:
	if (
		StringName(change.get("mode", StringName())) != &"splice"
		or int(change.get("sequence_type", TYPE_NIL))
		!= TYPE_PACKED_VECTOR3_ARRAY
	):
		return false
	var prefix_count := int(change.get("prefix_count", -1))
	var suffix_count := int(change.get("suffix_count", -1))
	var source_middle := change.get(
		"before_middle" if use_after else "after_middle",
		[]
	) as Array
	var target_middle := change.get(
		"after_middle" if use_after else "before_middle",
		[]
	) as Array
	var expected_size := int(change.get(
		"before_size" if use_after else "after_size",
		-1
	))
	if (
		prefix_count < 0
		or suffix_count < 0
		or current.size() != expected_size
		or prefix_count + suffix_count + source_middle.size()
		!= current.size()
		or source_middle.size() > 1
		or target_middle.size() > 1
	):
		return false
	for middle_index in range(source_middle.size()):
		if current[prefix_count + middle_index] != source_middle[middle_index]:
			return false
	var target_size := prefix_count + suffix_count + target_middle.size()
	if target_size == current.size():
		return source_middle.size() == 1 and target_middle.size() == 1
	return suffix_count == 0 and abs(target_size - current.size()) == 1


func _apply_simple_path_splice_to_points(
	change: Dictionary,
	use_after: bool
) -> void:
	var prefix_count := int(change.get("prefix_count", 0))
	var target_middle := change.get(
		"after_middle" if use_after else "before_middle",
		[]
	) as Array
	var target_size := int(change.get(
		"after_size" if use_after else "before_size",
		0
	))
	if target_size < spline_line_points.size():
		spline_line_points.resize(target_size)
	elif target_size > spline_line_points.size():
		spline_line_points.append(target_middle[0] as Vector3)
	else:
		spline_line_points[prefix_count] = target_middle[0] as Vector3


func _apply_simple_path_splice_to_normals(
	change: Dictionary,
	use_after: bool
) -> void:
	var prefix_count := int(change.get("prefix_count", 0))
	var target_middle := change.get(
		"after_middle" if use_after else "before_middle",
		[]
	) as Array
	var target_size := int(change.get(
		"after_size" if use_after else "before_size",
		0
	))
	if target_size < spline_line_surface_normals.size():
		spline_line_surface_normals.resize(target_size)
	elif target_size > spline_line_surface_normals.size():
		spline_line_surface_normals.append(target_middle[0] as Vector3)
	else:
		spline_line_surface_normals[prefix_count] = target_middle[0] as Vector3

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
	active_basic_shape_source_id = BASIC_SHAPE_SOURCE_PRIMITIVE
	active_saved_basic_profile_id = StringName()
	active_saved_basic_profile_data = {}
	mark_updated()

func select_active_saved_basic_profile(profile_data: Dictionary) -> bool:
	if (
		profile_data.is_empty()
		or StringName(profile_data.get("family", StringName()))
		!= ForgeV2ProfileShapeLibraryScript.PROFILE_FAMILY_BASIC
	):
		return false
	var compiled_profile := (
		ForgeV2ProfileShapeLibraryScript.compile_basic_profile_runtime_data(
			profile_data
		)
	)
	var profile_id := StringName(compiled_profile.get(
		"profile_id",
		compiled_profile.get("id", StringName())
	))
	if (
		profile_id == StringName()
		or not ForgeV2ProfileShapeLibraryScript.is_compiled_basic_profile_runtime_valid(
			compiled_profile
		)
	):
		return false
	active_basic_shape_source_id = BASIC_SHAPE_SOURCE_SAVED_PROFILE
	active_saved_basic_profile_id = profile_id
	active_saved_basic_profile_data = compiled_profile.duplicate(true)
	mark_updated()
	return true

func set_active_tool_id(next_tool_id: StringName) -> void:
	var previous_profile_id := active_profile_id
	_assign_active_tool_id(next_tool_id)
	active_profile_id = ForgeV2ProfileShapeLibraryScript.normalize_profile_id(active_profile_id, _get_active_profile_family())
	if active_profile_id != previous_profile_id:
		active_profile_display_name = ""
		_reset_active_profile_dimensions_to_natural()
	_normalize_active_profile_settings()
	_normalize_spline_line()
	mark_updated()

func set_active_handle_path_mode_id(next_mode_id: StringName) -> bool:
	_normalize_spline_line()
	var resolved_mode_id := _normalize_handle_path_mode_id(next_mode_id)
	if active_handle_path_mode_id == resolved_mode_id:
		return false
	var previous_required_point_count := get_active_handle_required_point_count()
	active_handle_path_mode_id = resolved_mode_id
	_convert_handle_path_point_count(
		previous_required_point_count,
		get_active_handle_required_point_count()
	)
	_normalize_spline_line()
	mark_updated()
	return true

func get_handle_path_mode_options() -> Array[Dictionary]:
	return [
		{
			"id": HANDLE_PATH_MODE_THREE_POINT_SPLINE,
			"label": "3 point spline",
		},
		{
			"id": HANDLE_PATH_MODE_THREE_POINT_LINEAR,
			"label": "3 point linear",
		},
		{
			"id": HANDLE_PATH_MODE_TWO_POINT_LINEAR,
			"label": "2 point linear",
		},
	]

func get_active_handle_path_mode_label() -> String:
	for option: Dictionary in get_handle_path_mode_options():
		if StringName(option.get("id", StringName())) == active_handle_path_mode_id:
			return String(option.get("label", "3 point spline"))
	return "3 point spline"

func get_active_handle_required_point_count() -> int:
	return (
		HANDLE_TWO_POINT_COUNT
		if active_handle_path_mode_id == HANDLE_PATH_MODE_TWO_POINT_LINEAR
		else HANDLE_THREE_POINT_COUNT
	)

func get_active_handle_path_shape_kind() -> StringName:
	return (
		ForgeV2MaterialBodyScript.SHAPE_KIND_SPLINE_PROFILE_PATH
		if active_handle_path_mode_id == HANDLE_PATH_MODE_THREE_POINT_SPLINE
		else ForgeV2MaterialBodyScript.SHAPE_KIND_PROFILE_PATH
	)

func set_active_profile_id(next_profile_id: StringName) -> void:
	active_profile_id = ForgeV2ProfileShapeLibraryScript.normalize_profile_id(next_profile_id, _get_active_profile_family())
	active_profile_display_name = ""
	if active_tool_id == TOOL_HANDLES:
		active_handle_source_profile_id = StringName()
	_reset_active_profile_dimensions_to_natural()
	_normalize_active_profile_settings()
	mark_updated()

func set_active_profile_display_name(next_display_name: String) -> void:
	active_profile_display_name = next_display_name.strip_edges()
	mark_updated()

func reset_active_handle_profile_builder() -> void:
	_assign_active_tool_id(TOOL_HANDLES)
	active_profile_id = ForgeV2ProfileShapeLibraryScript.PROFILE_HANDLE_BUILDER
	active_profile_display_name = ""
	active_handle_source_profile_id = StringName()
	active_profile_width_meters = ForgeV2ProfileShapeLibraryScript.HANDLE_DEFAULT_WIDTH_METERS
	active_profile_height_meters = ForgeV2ProfileShapeLibraryScript.HANDLE_DEFAULT_HEIGHT_METERS
	active_profile_anchor_x_meters = 0.0
	active_profile_anchor_y_meters = 0.0
	active_profile_rotation_degrees = 0.0
	active_handle_face_count = ForgeV2ProfileShapeLibraryScript.HANDLE_FACE_COUNT_RECTANGLE
	active_handle_rounding_enabled = true
	active_handle_corner_radius_meters = ForgeV2ProfileShapeLibraryScript.HANDLE_DEFAULT_CORNER_RADIUS_METERS
	active_handle_control_points_2d_meters = ForgeV2ProfileShapeLibraryScript.build_default_handle_control_points(
		active_handle_face_count,
		active_profile_width_meters,
		active_profile_height_meters
	)
	_normalize_active_profile_settings()
	mark_updated()

func reset_active_basic_profile_builder() -> void:
	_assign_active_tool_id(TOOL_VOLUME_STROKE)
	active_profile_id = ForgeV2ProfileShapeLibraryScript.PROFILE_2D_BUILDER
	active_profile_display_name = ""
	active_profile_width_meters = ForgeV2ProfileShapeLibraryScript.BASIC_BUILDER_DEFAULT_WIDTH_METERS
	active_profile_height_meters = ForgeV2ProfileShapeLibraryScript.BASIC_BUILDER_DEFAULT_HEIGHT_METERS
	active_profile_anchor_x_meters = 0.0
	active_profile_anchor_y_meters = 0.0
	active_profile_rotation_degrees = 0.0
	active_basic_control_points_2d_meters = ForgeV2ProfileShapeLibraryScript.build_default_basic_control_points(
		active_profile_width_meters,
		active_profile_height_meters
	)
	active_basic_corner_metadata = []
	active_basic_next_corner_serial = 1
	active_basic_grid_snapping_enabled = false
	_normalize_active_profile_settings()
	mark_updated()

func set_active_profile_width_meters(next_width_meters: float) -> void:
	active_profile_width_meters = _normalize_profile_size_meters(next_width_meters)
	if _is_active_handle_builder_profile():
		_scale_active_handle_control_points_to_profile_size()
		_normalize_active_profile_settings()
	elif _is_active_basic_builder_profile():
		_scale_active_basic_control_points_to_profile_size()
		_normalize_active_profile_settings()
	mark_updated()

func set_active_profile_height_meters(next_height_meters: float) -> void:
	active_profile_height_meters = _normalize_profile_size_meters(next_height_meters)
	if _is_active_handle_builder_profile():
		_scale_active_handle_control_points_to_profile_size()
		_normalize_active_profile_settings()
	elif _is_active_basic_builder_profile():
		_scale_active_basic_control_points_to_profile_size()
		_normalize_active_profile_settings()
	mark_updated()

func set_active_profile_anchor_x_meters(next_anchor_x_meters: float) -> void:
	if _is_active_handle_builder_profile():
		var preview_anchor := _resolve_active_handle_builder_preview_anchor()
		preview_anchor.x = _normalize_profile_anchor_meters(next_anchor_x_meters)
		_set_active_handle_preview_anchor(preview_anchor)
	elif _is_active_basic_builder_profile():
		var preview_anchor := _resolve_active_basic_builder_preview_anchor()
		preview_anchor.x = _normalize_profile_anchor_meters(next_anchor_x_meters)
		_set_active_basic_preview_anchor(preview_anchor)
	else:
		active_profile_anchor_x_meters = _normalize_profile_anchor_meters(next_anchor_x_meters)
	mark_updated()

func set_active_profile_anchor_y_meters(next_anchor_y_meters: float) -> void:
	if _is_active_handle_builder_profile():
		var preview_anchor := _resolve_active_handle_builder_preview_anchor()
		preview_anchor.y = _normalize_profile_anchor_meters(next_anchor_y_meters)
		_set_active_handle_preview_anchor(preview_anchor)
	elif _is_active_basic_builder_profile():
		var preview_anchor := _resolve_active_basic_builder_preview_anchor()
		preview_anchor.y = _normalize_profile_anchor_meters(next_anchor_y_meters)
		_set_active_basic_preview_anchor(preview_anchor)
	else:
		active_profile_anchor_y_meters = _normalize_profile_anchor_meters(next_anchor_y_meters)
	mark_updated()

func set_active_profile_anchor_2d_meters(next_anchor_position_meters: Vector2) -> void:
	if _is_active_handle_builder_profile():
		_set_active_handle_preview_anchor(next_anchor_position_meters, active_handle_grid_snapping_enabled)
	elif _is_active_basic_builder_profile():
		_set_active_basic_preview_anchor(next_anchor_position_meters, active_basic_grid_snapping_enabled)
	else:
		active_profile_anchor_x_meters = _normalize_profile_anchor_meters(next_anchor_position_meters.x)
		active_profile_anchor_y_meters = _normalize_profile_anchor_meters(next_anchor_position_meters.y)
	mark_updated()

func reset_active_profile_anchor_to_center() -> void:
	if _is_active_handle_builder_profile():
		var center := _resolve_active_handle_builder_base_profile_center()
		active_profile_anchor_x_meters = center.x
		active_profile_anchor_y_meters = center.y
		_constrain_active_handle_anchor()
	elif _is_active_basic_builder_profile():
		var center := _resolve_active_basic_builder_base_profile_center()
		active_profile_anchor_x_meters = center.x
		active_profile_anchor_y_meters = center.y
		_constrain_active_basic_anchor()
	else:
		active_profile_anchor_x_meters = 0.0
		active_profile_anchor_y_meters = 0.0
	mark_updated()

func set_active_profile_rotation_degrees(next_rotation_degrees: float) -> void:
	active_profile_rotation_degrees = _normalize_profile_rotation_degrees(next_rotation_degrees)
	if _is_active_handle_builder_profile():
		_constrain_active_handle_anchor()
	elif _is_active_basic_builder_profile():
		_constrain_active_basic_anchor()
	mark_updated()

func set_active_handle_face_count(next_face_count: int) -> void:
	_assign_active_tool_id(TOOL_HANDLES)
	active_profile_id = ForgeV2ProfileShapeLibraryScript.PROFILE_HANDLE_BUILDER
	active_profile_display_name = ""
	active_handle_face_count = ForgeV2ProfileShapeLibraryScript.normalize_handle_face_count(next_face_count)
	_reset_active_handle_control_points_for_size()
	_normalize_active_profile_settings()
	mark_updated()

func set_active_handle_rounding_enabled(is_enabled: bool) -> void:
	_assign_active_tool_id(TOOL_HANDLES)
	active_profile_id = ForgeV2ProfileShapeLibraryScript.PROFILE_HANDLE_BUILDER
	active_handle_rounding_enabled = is_enabled
	_normalize_active_profile_settings()
	mark_updated()

func set_active_handle_corner_radius_meters(next_corner_radius_meters: float) -> void:
	_assign_active_tool_id(TOOL_HANDLES)
	active_profile_id = ForgeV2ProfileShapeLibraryScript.PROFILE_HANDLE_BUILDER
	active_handle_corner_radius_meters = next_corner_radius_meters
	_normalize_active_profile_settings()
	mark_updated()

func set_active_handle_control_point_2d_meters(point_index: int, point_position_meters: Vector2) -> bool:
	_assign_active_tool_id(TOOL_HANDLES)
	active_profile_id = ForgeV2ProfileShapeLibraryScript.PROFILE_HANDLE_BUILDER
	_normalize_active_profile_settings()
	if point_index < 0 or point_index >= active_handle_control_points_2d_meters.size():
		return false
	var next_points := active_handle_control_points_2d_meters
	var constrained_preview_point := _constrain_active_handle_preview_point_to_guide(
		point_position_meters,
		active_handle_grid_snapping_enabled
	)
	next_points[point_index] = _rotate_profile_point(constrained_preview_point, -active_profile_rotation_degrees)
	active_handle_control_points_2d_meters = next_points
	_sync_active_profile_size_from_handle_control_points()
	_normalize_active_profile_settings()
	mark_updated()
	return true

func set_active_handle_grid_snapping_enabled(is_enabled: bool) -> void:
	_assign_active_tool_id(TOOL_HANDLES)
	active_profile_id = ForgeV2ProfileShapeLibraryScript.PROFILE_HANDLE_BUILDER
	active_handle_grid_snapping_enabled = is_enabled
	_normalize_active_profile_settings()
	mark_updated()

func set_active_basic_control_point_2d_meters(point_index: int, point_position_meters: Vector2) -> bool:
	_assign_active_tool_id(TOOL_VOLUME_STROKE)
	active_profile_id = ForgeV2ProfileShapeLibraryScript.PROFILE_2D_BUILDER
	_normalize_active_profile_settings()
	if point_index < 0 or point_index >= active_basic_control_points_2d_meters.size():
		return false
	var next_points := active_basic_control_points_2d_meters
	var constrained_preview_point := _constrain_active_basic_preview_point_to_guide(
		point_position_meters,
		active_basic_grid_snapping_enabled
	)
	next_points[point_index] = _rotate_profile_point(constrained_preview_point, -active_profile_rotation_degrees)
	active_basic_control_points_2d_meters = next_points
	_sync_active_profile_size_from_basic_control_points()
	_normalize_active_profile_settings()
	mark_updated()
	return true

func insert_active_basic_control_point_on_segment(
	segment_start_corner_id: StringName,
	preview_position_meters: Vector2
) -> StringName:
	if not _is_active_basic_builder_profile():
		return StringName()
	_normalize_active_basic_builder_settings()
	var segment_start_index := _find_active_basic_corner_index(segment_start_corner_id)
	if segment_start_index < 0 or active_basic_control_points_2d_meters.size() < 3:
		return StringName()
	var segment_end_index := (
		segment_start_index + 1
	) % active_basic_control_points_2d_meters.size()
	var preview_points := _resolve_active_basic_builder_preview_control_points()
	var segment_start: Vector2 = preview_points[segment_start_index]
	var segment_end: Vector2 = preview_points[segment_end_index]
	var projected_preview_position := _closest_point_on_segment_2d(
		preview_position_meters,
		segment_start,
		segment_end
	)
	if (
		projected_preview_position.distance_squared_to(segment_start) <= 0.000000000001
		or projected_preview_position.distance_squared_to(segment_end) <= 0.000000000001
	):
		return StringName()
	var base_position := _rotate_profile_point(
		projected_preview_position,
		-active_profile_rotation_degrees
	)
	var insertion_index := segment_start_index + 1
	var next_points := active_basic_control_points_2d_meters
	next_points.insert(insertion_index, base_position)
	var next_metadata := _duplicate_basic_corner_metadata()
	var new_corner_id := _build_next_basic_corner_id()
	next_metadata.insert(insertion_index, {"corner_id": new_corner_id})
	active_basic_control_points_2d_meters = next_points
	active_basic_corner_metadata = next_metadata
	_sync_active_profile_size_from_basic_control_points()
	_normalize_active_basic_builder_settings()
	mark_updated()
	return new_corner_id

func remove_active_basic_control_point(corner_id: StringName) -> bool:
	if not _is_active_basic_builder_profile():
		return false
	_normalize_active_basic_builder_settings()
	if active_basic_control_points_2d_meters.size() <= 3:
		return false
	var point_index := _find_active_basic_corner_index(corner_id)
	if point_index < 0:
		return false
	var next_points := active_basic_control_points_2d_meters
	next_points.remove_at(point_index)
	var next_metadata := _duplicate_basic_corner_metadata()
	next_metadata.remove_at(point_index)
	active_basic_control_points_2d_meters = next_points
	active_basic_corner_metadata = next_metadata
	_sync_active_profile_size_from_basic_control_points()
	_normalize_active_basic_builder_settings()
	mark_updated()
	return true

func add_active_basic_corner_fillet(corner_id: StringName) -> bool:
	if not _is_active_basic_builder_profile():
		return false
	_normalize_active_basic_builder_settings()
	var point_index := _find_active_basic_corner_index(corner_id)
	if point_index < 0:
		return false
	var metadata := active_basic_corner_metadata[point_index].duplicate(true)
	if (
		metadata.has("radius_meters")
		and float(metadata.get("radius_meters", 0.0))
		>= ForgeV2ProfileShapeLibraryScript.BASIC_FILLET_RADIUS_MIN_METERS
	):
		return false
	metadata["radius_meters"] = (
		ForgeV2ProfileShapeLibraryScript.BASIC_FILLET_RADIUS_DEFAULT_METERS
	)
	active_basic_corner_metadata[point_index] = metadata
	_normalize_active_basic_corner_metadata()
	_constrain_active_basic_anchor()
	mark_updated()
	return true

func set_active_basic_corner_fillet_radius(
	corner_id: StringName,
	radius_meters: float
) -> bool:
	if not _is_active_basic_builder_profile():
		return false
	_normalize_active_basic_builder_settings()
	var point_index := _find_active_basic_corner_index(corner_id)
	if point_index < 0:
		return false
	var metadata := active_basic_corner_metadata[point_index].duplicate(true)
	if not metadata.has("radius_meters"):
		return false
	metadata["radius_meters"] = clampf(
		radius_meters,
		ForgeV2ProfileShapeLibraryScript.BASIC_FILLET_RADIUS_MIN_METERS,
		ForgeV2ProfileShapeLibraryScript.BASIC_FILLET_RADIUS_INPUT_MAX_METERS
	)
	active_basic_corner_metadata[point_index] = metadata
	_normalize_active_basic_corner_metadata()
	_constrain_active_basic_anchor()
	mark_updated()
	return true

func remove_active_basic_corner_fillet(corner_id: StringName) -> bool:
	if not _is_active_basic_builder_profile():
		return false
	_normalize_active_basic_builder_settings()
	var point_index := _find_active_basic_corner_index(corner_id)
	if point_index < 0:
		return false
	var metadata := active_basic_corner_metadata[point_index].duplicate(true)
	if not metadata.has("radius_meters"):
		return false
	metadata.erase("radius_meters")
	active_basic_corner_metadata[point_index] = metadata
	_constrain_active_basic_anchor()
	mark_updated()
	return true

func get_active_basic_corner_fillet_settings(corner_id: StringName) -> Dictionary:
	if not _is_active_basic_builder_profile():
		return {}
	_normalize_active_basic_builder_settings()
	var point_index := _find_active_basic_corner_index(corner_id)
	if point_index < 0:
		return {}
	var metadata := active_basic_corner_metadata[point_index]
	var geometry := _resolve_active_basic_builder_fillet_geometry()
	var corner_result := {}
	for result_variant: Variant in geometry.get("corner_results", []):
		if not result_variant is Dictionary:
			continue
		var result := result_variant as Dictionary
		if StringName(result.get("corner_id", StringName())) != corner_id:
			continue
		corner_result = result.duplicate(true)
		break
	return {
		"corner_id": corner_id,
		"point_index": point_index,
		"has_fillet": metadata.has("radius_meters"),
		"radius_meters": float(metadata.get(
			"radius_meters",
			ForgeV2ProfileShapeLibraryScript.BASIC_FILLET_RADIUS_DEFAULT_METERS
		)),
		"minimum_radius_meters": (
			ForgeV2ProfileShapeLibraryScript.BASIC_FILLET_RADIUS_MIN_METERS
		),
		"default_radius_meters": (
			ForgeV2ProfileShapeLibraryScript.BASIC_FILLET_RADIUS_DEFAULT_METERS
		),
		"maximum_radius_meters": (
			ForgeV2ProfileShapeLibraryScript.BASIC_FILLET_RADIUS_INPUT_MAX_METERS
		),
		"effective_radius_meters": float(corner_result.get(
			"effective_radius_meters",
			0.0
		)),
		"status": StringName(corner_result.get("status", &"sharp")),
	}

func set_active_basic_grid_snapping_enabled(is_enabled: bool) -> void:
	_assign_active_tool_id(TOOL_VOLUME_STROKE)
	active_profile_id = ForgeV2ProfileShapeLibraryScript.PROFILE_2D_BUILDER
	active_basic_grid_snapping_enabled = is_enabled
	_normalize_active_profile_settings()
	mark_updated()

func apply_tool_profile_preset(profile_data: Dictionary) -> bool:
	if profile_data.is_empty():
		return false
	var profile_family: StringName = StringName(profile_data.get("family", ForgeV2ProfileShapeLibraryScript.PROFILE_FAMILY_HANDLE))
	match profile_family:
		ForgeV2ProfileShapeLibraryScript.PROFILE_FAMILY_HANDLE:
			_assign_active_tool_id(TOOL_HANDLES)
			active_profile_id = ForgeV2ProfileShapeLibraryScript.PROFILE_HANDLE_BUILDER
			active_handle_source_profile_id = StringName(profile_data.get(
				"profile_id",
				profile_data.get("id", StringName())
			))
			active_profile_display_name = String(profile_data.get("label", ""))
			active_handle_face_count = ForgeV2ProfileShapeLibraryScript.normalize_handle_face_count(int(profile_data.get("face_count", active_handle_face_count)))
			active_handle_rounding_enabled = bool(profile_data.get("rounded_enabled", active_handle_rounding_enabled))
			active_handle_corner_radius_meters = float(profile_data.get("corner_radius_meters", active_handle_corner_radius_meters))
			var handle_preset_points: PackedVector2Array = profile_data.get("control_points_2d_meters", PackedVector2Array())
			if handle_preset_points.size() != active_handle_face_count:
				handle_preset_points = ForgeV2ProfileShapeLibraryScript.build_default_handle_control_points(
					active_handle_face_count,
					float(profile_data.get("width_meters", active_profile_width_meters)),
					float(profile_data.get("height_meters", active_profile_height_meters))
				)
			active_handle_control_points_2d_meters = handle_preset_points
			_sync_active_profile_size_from_handle_control_points()
		ForgeV2ProfileShapeLibraryScript.PROFILE_FAMILY_BASIC:
			if active_tool_id == TOOL_HANDLES:
				_assign_active_tool_id(TOOL_VOLUME_STROKE)
			active_profile_id = ForgeV2ProfileShapeLibraryScript.PROFILE_2D_BUILDER
			active_profile_display_name = String(profile_data.get("label", ""))
			var basic_preset_points: PackedVector2Array = profile_data.get("control_points_2d_meters", PackedVector2Array())
			if basic_preset_points.size() < 3:
				basic_preset_points = ForgeV2ProfileShapeLibraryScript.build_default_basic_control_points(
					float(profile_data.get("width_meters", active_profile_width_meters)),
					float(profile_data.get("height_meters", active_profile_height_meters))
				)
			active_basic_control_points_2d_meters = basic_preset_points
			active_basic_corner_metadata = []
			for metadata_variant: Variant in profile_data.get("basic_corner_metadata", []):
				if metadata_variant is Dictionary:
					active_basic_corner_metadata.append(
						(metadata_variant as Dictionary).duplicate(true)
					)
			active_basic_next_corner_serial = maxi(
				int(profile_data.get("basic_next_corner_serial", 1)),
				1
			)
			active_basic_grid_snapping_enabled = bool(profile_data.get("grid_snapping_enabled", active_basic_grid_snapping_enabled))
			_sync_active_profile_size_from_basic_control_points()
		_:
			return false
	active_profile_anchor_x_meters = _normalize_profile_anchor_meters(float(profile_data.get("anchor_x_meters", active_profile_anchor_x_meters)))
	active_profile_anchor_y_meters = _normalize_profile_anchor_meters(float(profile_data.get("anchor_y_meters", active_profile_anchor_y_meters)))
	active_profile_rotation_degrees = _normalize_profile_rotation_degrees(float(profile_data.get("rotation_degrees", active_profile_rotation_degrees)))
	_normalize_active_profile_settings()
	mark_updated()
	return true

func build_active_tool_profile_preset_data(requested_name: String = "") -> Dictionary:
	_normalize_active_profile_settings()
	var profile_family := ForgeV2ProfileShapeLibraryScript.PROFILE_FAMILY_HANDLE if active_tool_id == TOOL_HANDLES else ForgeV2ProfileShapeLibraryScript.PROFILE_FAMILY_BASIC
	var preset_name := requested_name.strip_edges()
	if preset_name.is_empty():
		preset_name = "handle profile" if profile_family == ForgeV2ProfileShapeLibraryScript.PROFILE_FAMILY_HANDLE else "tool profile"
	var control_points := active_handle_control_points_2d_meters if profile_family == ForgeV2ProfileShapeLibraryScript.PROFILE_FAMILY_HANDLE else active_basic_control_points_2d_meters
	var grid_snapping_enabled := active_handle_grid_snapping_enabled if profile_family == ForgeV2ProfileShapeLibraryScript.PROFILE_FAMILY_HANDLE else active_basic_grid_snapping_enabled
	var base_polygon := (
		_resolve_active_handle_builder_base_polygon()
		if profile_family == ForgeV2ProfileShapeLibraryScript.PROFILE_FAMILY_HANDLE
		else _resolve_active_basic_builder_base_polygon()
	)
	var profile_data := {
		"profile_id": StringName(),
		"id": StringName(),
		"label": preset_name,
		"family": profile_family,
		"profile_id_source": active_profile_id,
		"width_meters": active_profile_width_meters,
		"height_meters": active_profile_height_meters,
		"anchor_x_meters": active_profile_anchor_x_meters,
		"anchor_y_meters": active_profile_anchor_y_meters,
		"rotation_degrees": active_profile_rotation_degrees,
		"face_count": active_handle_face_count,
		"rounded_enabled": active_handle_rounding_enabled,
		"corner_radius_meters": active_handle_corner_radius_meters,
		"control_points_2d_meters": control_points,
		"basic_corner_metadata": (
			_duplicate_basic_corner_metadata()
			if profile_family == ForgeV2ProfileShapeLibraryScript.PROFILE_FAMILY_BASIC
			else []
		),
		"basic_next_corner_serial": active_basic_next_corner_serial,
		"grid_snapping_enabled": grid_snapping_enabled,
		"base_polygon_2d_meters": base_polygon,
		"base_anchor_2d_meters": Vector2(
			active_profile_anchor_x_meters,
			active_profile_anchor_y_meters
		),
		"polygon_2d_meters": _resolve_active_profile_polygon(),
	}
	if profile_family == ForgeV2ProfileShapeLibraryScript.PROFILE_FAMILY_BASIC:
		return ForgeV2ProfileShapeLibraryScript.compile_basic_profile_runtime_data(
			profile_data
		)
	return ForgeV2ProfileShapeLibraryScript.compile_handle_profile_runtime_data(
		profile_data
	)

func set_active_material_variant_id(next_material_variant_id: StringName) -> void:
	if next_material_variant_id == StringName():
		return
	active_material_variant_id = ForgeV2MaterialPaletteScript.normalize_material_variant_id(next_material_variant_id)
	mark_updated()

func set_brush_radius_meters(next_radius_meters: float) -> void:
	if (
		active_tool_id != TOOL_HANDLES
		and is_saved_basic_profile_shape_active()
	):
		return
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
	amount_ratio: float = -1.0,
	local_surface_normal: Vector3 = Vector3.FORWARD,
	local_contact_direction: Vector3 = Vector3.ZERO
) -> Resource:
	return append_point_material_body(
		local_position,
		radius_meters,
		amount_ratio,
		local_surface_normal,
		local_contact_direction
	)

func append_point_material_body(
	local_position: Vector3,
	radius_meters: float = -1.0,
	amount_ratio: float = -1.0,
	local_surface_normal: Vector3 = Vector3.FORWARD,
	local_contact_direction: Vector3 = Vector3.ZERO
) -> Resource:
	if active_tool_id != TOOL_HANDLES and is_saved_basic_profile_shape_active():
		var normalized_contact_direction := _normalize_path_contact_direction(
			local_contact_direction
		)
		if normalized_contact_direction == Vector3.ZERO:
			return null
		var profile_body := _append_active_saved_basic_profile_material_body(
			PackedVector3Array([local_position]),
			PackedVector3Array([
				_normalize_path_surface_normal(local_surface_normal),
			]),
			ForgeV2MaterialBodyScript.SHAPE_KIND_PROFILE_PATH,
			"v2_saved_profile_stroke",
			ForgeV2MaterialBodyScript.BODY_KIND_VOLUME_STROKE,
			StringName(),
			StringName(),
			PackedVector3Array([normalized_contact_direction])
		)
		mark_updated()
		return profile_body
	var body: Resource = _append_material_body_record(
		PackedVector3Array([local_position]),
		active_brush_radius_meters if radius_meters <= 0.0 else _normalize_brush_radius(radius_meters),
		DEFAULT_AMOUNT_RATIO,
		ForgeV2MaterialBodyScript.SHAPE_KIND_CAPSULE_PATH,
		"v2_csg_body",
		ForgeV2MaterialBodyScript.BODY_KIND_VOLUME_STROKE,
		StringName(),
		ForgeV2ProfileShapeLibraryScript.PROFILE_ROLE_NONE,
		PackedVector2Array(),
		Vector2.ZERO,
		0.0,
		PackedVector3Array([
			_normalize_path_surface_normal(local_surface_normal),
		])
	)
	mark_updated()
	return body

func append_point_to_volume_stroke(
	stroke_id: StringName,
	local_position: Vector3,
	min_spacing_meters: float = 0.0,
	force_endpoint: bool = false,
	local_surface_normal: Vector3 = Vector3.FORWARD,
	local_contact_direction: Vector3 = Vector3.ZERO
) -> bool:
	return append_point_to_material_body(
		stroke_id,
		local_position,
		min_spacing_meters,
		force_endpoint,
		local_surface_normal,
		local_contact_direction
	)

func append_point_to_material_body(
	body_id: StringName,
	local_position: Vector3,
	min_spacing_meters: float = 0.0,
	force_endpoint: bool = false,
	local_surface_normal: Vector3 = Vector3.FORWARD,
	local_contact_direction: Vector3 = Vector3.ZERO
) -> bool:
	return append_points_to_material_body(
		body_id,
		PackedVector3Array([local_position]),
		PackedVector3Array([local_surface_normal]),
		min_spacing_meters,
		force_endpoint,
		PackedVector3Array([local_contact_direction])
	) > 0

func append_points_to_material_body(
	body_id: StringName,
	local_positions: PackedVector3Array,
	local_surface_normals: PackedVector3Array = PackedVector3Array(),
	min_spacing_meters: float = 0.0,
	force_final_endpoint: bool = false,
	local_contact_directions: PackedVector3Array = PackedVector3Array()
) -> int:
	if local_positions.is_empty():
		return 0
	var body: Resource = _find_editable_material_body(body_id)
	if body == null:
		return 0
	var path_points: PackedVector3Array = body.get("path_points")
	var path_surface_normals: PackedVector3Array = body.get(
		"path_surface_normals"
	)
	var uses_explicit_contact_authority := (
		body.has_method("uses_explicit_surface_contact_authority")
		and bool(body.call("uses_explicit_surface_contact_authority"))
	)
	if (
		uses_explicit_contact_authority
		and local_contact_directions.size() != local_positions.size()
	):
		return 0
	var path_contact_directions: PackedVector3Array = body.get(
		"path_contact_directions"
	)
	if (
		uses_explicit_contact_authority
		and path_contact_directions.size() != path_points.size()
	):
		return 0
	var changed_sample_count := 0
	var spacing: float = maxf(min_spacing_meters, 0.0)
	for sample_index in range(local_positions.size()):
		var local_position: Vector3 = local_positions[sample_index]
		var local_surface_normal := Vector3.FORWARD
		if sample_index < local_surface_normals.size():
			local_surface_normal = local_surface_normals[sample_index]
		var normalized_surface_normal := _normalize_path_surface_normal(
			local_surface_normal
		)
		var normalized_contact_direction := Vector3.ZERO
		if uses_explicit_contact_authority:
			normalized_contact_direction = _normalize_path_contact_direction(
				local_contact_directions[sample_index]
			)
			if normalized_contact_direction == Vector3.ZERO:
				return 0
		var force_endpoint := (
			force_final_endpoint
			and sample_index == local_positions.size() - 1
		)
		if path_points.is_empty():
			path_points.append(local_position)
			path_surface_normals.append(normalized_surface_normal)
			if uses_explicit_contact_authority:
				path_contact_directions.append(normalized_contact_direction)
			changed_sample_count += 1
			continue
		var last_point: Vector3 = path_points[path_points.size() - 1]
		var is_far_enough := spacing <= 0.0 or last_point.distance_squared_to(local_position) >= spacing * spacing
		if is_far_enough:
			path_points.append(local_position)
			path_surface_normals.append(normalized_surface_normal)
			if uses_explicit_contact_authority:
				path_contact_directions.append(normalized_contact_direction)
			changed_sample_count += 1
		elif force_endpoint and not last_point.is_equal_approx(local_position):
			path_points[path_points.size() - 1] = local_position
			while path_surface_normals.size() < path_points.size():
				path_surface_normals.append(normalized_surface_normal)
			path_surface_normals[path_points.size() - 1] = normalized_surface_normal
			if uses_explicit_contact_authority:
				path_contact_directions[path_points.size() - 1] = (
					normalized_contact_direction
				)
			changed_sample_count += 1
		elif force_endpoint:
			while path_surface_normals.size() < path_points.size():
				path_surface_normals.append(normalized_surface_normal)
			var last_normal_index := path_points.size() - 1
			var endpoint_metadata_changed := false
			if not path_surface_normals[last_normal_index].is_equal_approx(
				normalized_surface_normal
			):
				path_surface_normals[last_normal_index] = normalized_surface_normal
				endpoint_metadata_changed = true
			if (
				uses_explicit_contact_authority
				and not path_contact_directions[last_normal_index].is_equal_approx(
					normalized_contact_direction
				)
			):
				path_contact_directions[last_normal_index] = normalized_contact_direction
				endpoint_metadata_changed = true
			if endpoint_metadata_changed:
				changed_sample_count += 1
	if changed_sample_count <= 0:
		return 0
	body.set("path_points", path_points)
	body.set("path_surface_normals", path_surface_normals)
	if uses_explicit_contact_authority:
		body.set("path_contact_directions", path_contact_directions)
	body.set("updated_timestamp", Time.get_unix_time_from_system())
	if body.has_method("normalize"):
		body.call("normalize")
	_mark_material_usage_summary_dirty()
	mark_updated()
	return changed_sample_count

func clear_volume_strokes() -> void:
	clear_pending_material_bodies()

func clear_pending_material_bodies() -> void:
	var cancelled_handle_change := false
	if is_handle_change_active():
		cancelled_handle_change = cancel_handle_change()
	_remove_pending_user_material_bodies()
	volume_strokes = []
	selected_material_body_id = StringName()
	spline_line_csg_noodle_enabled = false
	_mark_material_usage_summary_dirty()
	if cancelled_handle_change:
		_publish_bounded_history_transition(
			BOUNDED_HISTORY_TRANSITION_PROTECTED_CHANGED,
			null,
			[]
		)
	mark_updated()

func capture_pending_body_bundle(body_id: StringName) -> Dictionary:
	var body := _find_material_body_by_id(body_id)
	if not _is_pending_user_material_body(body):
		return {
			"ok": false,
			"reason": &"pending_body_missing_or_not_editable",
		}
	var body_copy := body.duplicate(true) as Resource
	if body_copy == null:
		return {
			"ok": false,
			"reason": &"pending_body_duplicate_failed",
		}
	var source_record_id := StringName(body.get("source_record_id"))
	var source_stroke: Resource = null
	var source_stroke_index := -1
	if source_record_id != StringName():
		for stroke_index in range(volume_strokes.size()):
			var candidate_stroke: Resource = volume_strokes[stroke_index]
			if (
				candidate_stroke != null
				and StringName(candidate_stroke.get("stroke_id"))
				== source_record_id
			):
				source_stroke = candidate_stroke
				source_stroke_index = stroke_index
				break
	var source_stroke_copy: Resource = null
	if source_stroke != null:
		source_stroke_copy = source_stroke.duplicate(true) as Resource
		if source_stroke_copy == null:
			return {
				"ok": false,
				"reason": &"pending_source_stroke_duplicate_failed",
			}
	return {
		"ok": true,
		"reason": &"captured",
		"schema_id": PENDING_BODY_BUNDLE_SCHEMA_ID,
		"schema_version": 1,
		"body_id": body_id,
		"body": body_copy,
		"body_index": material_bodies.find(body),
		"source_stroke": source_stroke_copy,
		"source_stroke_index": source_stroke_index,
		"was_selected": selected_material_body_id == body_id,
	}

func remove_pending_body_bundle(body_id: StringName) -> bool:
	var body := _find_material_body_by_id(body_id)
	if not _is_pending_user_material_body(body):
		return false
	var body_index := material_bodies.find(body)
	if body_index < 0:
		return false
	var source_record_id := StringName(body.get("source_record_id"))
	var source_stroke := _find_volume_stroke_by_id(source_record_id)
	var source_stroke_index := (
		volume_strokes.find(source_stroke) if source_stroke != null else -1
	)
	var was_selected := selected_material_body_id == body_id
	material_bodies.remove_at(body_index)
	if source_stroke_index >= 0:
		volume_strokes.remove_at(source_stroke_index)
	if was_selected:
		selected_material_body_id = StringName()
		select_last_user_material_body()
	else:
		_normalize_selected_material_body_id()
	_reset_committed_volume_cache(&"pending_body_bundle_removed")
	_mark_material_usage_summary_dirty()
	mark_updated()
	return true

func restore_pending_body_bundle(bundle: Dictionary) -> bool:
	if (
		StringName(bundle.get("schema_id", StringName()))
		!= PENDING_BODY_BUNDLE_SCHEMA_ID
		or int(bundle.get("schema_version", 0)) != 1
		or not bool(bundle.get("ok", false))
	):
		return false
	var captured_body := bundle.get("body", null) as Resource
	if captured_body == null:
		return false
	var body := captured_body.duplicate(true) as Resource
	if body == null or not _is_pending_user_material_body(body):
		return false
	var body_id := StringName(body.get("body_id"))
	if (
		body_id == StringName()
		or body_id != StringName(bundle.get("body_id", StringName()))
		or _find_material_body_by_id(body_id) != null
	):
		return false
	if (
		_is_user_handle_material_body(body)
		and (
			has_handle_material_body()
			or is_handle_change_active()
		)
	):
		return false
	var captured_stroke := bundle.get("source_stroke", null) as Resource
	var source_stroke: Resource = null
	if captured_stroke != null:
		source_stroke = captured_stroke.duplicate(true) as Resource
		if source_stroke == null:
			return false
		var stroke_id := StringName(source_stroke.get("stroke_id"))
		if (
			stroke_id == StringName()
			or stroke_id != StringName(body.get("source_record_id"))
			or _find_volume_stroke_by_id(stroke_id) != null
		):
			return false
	if body.has_method("normalize"):
		body.call("normalize")
	if not _is_pending_user_material_body(body):
		return false
	if source_stroke != null and source_stroke.has_method("normalize"):
		source_stroke.call("normalize")
	var body_insert_index := clampi(
		int(bundle.get("body_index", material_bodies.size())),
		0,
		material_bodies.size()
	)
	material_bodies.insert(body_insert_index, body)
	if source_stroke != null:
		var stroke_insert_index := clampi(
			int(bundle.get("source_stroke_index", volume_strokes.size())),
			0,
			volume_strokes.size()
		)
		volume_strokes.insert(stroke_insert_index, source_stroke)
	if bool(bundle.get("was_selected", false)):
		selected_material_body_id = body_id
	else:
		_normalize_selected_material_body_id()
	_reset_committed_volume_cache(&"pending_body_bundle_restored")
	_mark_material_usage_summary_dirty()
	mark_updated()
	return true

func get_handle_material_body_count() -> int:
	var handle_count := _collect_live_handle_material_bodies().size()
	if is_handle_change_active():
		handle_count += 1
	return handle_count

func has_handle_material_body() -> bool:
	return get_handle_material_body_count() > 0

func is_handle_change_active() -> bool:
	return (
		_handle_change_original_body != null
		and is_instance_valid(_handle_change_original_body)
	)

func get_handle_change_source_profile_id() -> StringName:
	return (
		_handle_change_source_profile_id
		if is_handle_change_active()
		else active_handle_source_profile_id
	)

func begin_handle_change() -> Dictionary:
	if is_handle_change_active():
		return {
			"ok": true,
			"reason": &"already_editing_handle",
			"handle_change_active": true,
			"handle_source_profile_id": get_handle_change_source_profile_id(),
		}
	var handles := _collect_live_handle_material_bodies()
	if handles.is_empty():
		_handle_change_last_reason = &"handle_missing"
		return {
			"ok": false,
			"reason": _handle_change_last_reason,
			"handle_change_active": false,
			"handle_source_profile_id": StringName(),
		}
	if handles.size() != 1:
		_handle_change_last_reason = &"multiple_handles_require_manual_recovery"
		return {
			"ok": false,
			"reason": _handle_change_last_reason,
			"handle_change_active": false,
			"handle_source_profile_id": StringName(),
		}
	var original_body: Resource = handles[0]
	var original_body_index := material_bodies.find(original_body)
	if original_body_index < 0:
		_handle_change_last_reason = &"handle_body_not_in_material_stack"
		return {
			"ok": false,
			"reason": _handle_change_last_reason,
			"handle_change_active": false,
			"handle_source_profile_id": StringName(),
		}
	var original_layer: Resource = null
	var original_layer_index := -1
	if _is_material_body_committed(original_body):
		var original_body_id := StringName(original_body.get("body_id"))
		for layer_index in range(protected_forge_layers.size()):
			var candidate_layer: Resource = protected_forge_layers[layer_index]
			if candidate_layer == null:
				continue
			var candidate_body_ids: Array = candidate_layer.get("body_ids") as Array
			if candidate_body_ids.has(original_body_id):
				original_layer = candidate_layer
				original_layer_index = layer_index
				break
		if original_layer == null:
			_handle_change_last_reason = &"committed_handle_layer_missing"
			return {
				"ok": false,
				"reason": _handle_change_last_reason,
				"handle_change_active": false,
				"handle_source_profile_id": StringName(),
			}
		var original_layer_body_ids: Array = original_layer.get("body_ids") as Array
		if original_layer_body_ids.size() != 1:
			_handle_change_last_reason = &"committed_handle_layer_not_unique"
			return {
				"ok": false,
				"reason": _handle_change_last_reason,
				"handle_change_active": false,
				"handle_source_profile_id": StringName(),
			}
	_handle_change_original_body = original_body
	_handle_change_original_body_index = original_body_index
	_handle_change_original_protected_layer = original_layer
	_handle_change_original_protected_layer_index = original_layer_index
	_clear_spline_transient_state()
	_seed_handle_editor_from_body(original_body)
	_handle_change_initial_profile_signature = _build_active_handle_profile_signature()
	_handle_change_source_profile_id = active_handle_source_profile_id
	material_bodies.remove_at(original_body_index)
	if original_layer_index >= 0:
		protected_forge_layers.remove_at(original_layer_index)
		_rebuild_material_ledger()
	else:
		_reset_committed_volume_cache(&"pending_handle_change_started")
	selected_material_body_id = StringName()
	_mark_material_usage_summary_dirty()
	_handle_change_last_reason = &"editing_handle"
	_publish_bounded_history_transition(
		BOUNDED_HISTORY_TRANSITION_PROTECTED_CHANGED,
		null,
		[]
	)
	mark_updated()
	return {
		"ok": true,
		"reason": _handle_change_last_reason,
		"handle_change_active": true,
		"handle_source_profile_id": _handle_change_source_profile_id,
	}

func apply_handle_change() -> Dictionary:
	if not is_handle_change_active():
		_handle_change_last_reason = &"handle_change_not_active"
		return {
			"ok": false,
			"reason": _handle_change_last_reason,
			"handle_change_active": false,
		}
	_normalize_spline_line()
	var required_point_count := get_active_handle_required_point_count()
	if spline_line_points.size() != required_point_count:
		_handle_change_last_reason = &"handle_path_point_count_incomplete"
		return {
			"ok": false,
			"reason": _handle_change_last_reason,
			"handle_change_active": true,
		}
	if not _handle_endpoint_span_meets_minimum(spline_line_points):
		_handle_change_last_reason = &"handle_endpoint_span_below_minimum"
		return {
			"ok": false,
			"reason": _handle_change_last_reason,
			"handle_change_active": true,
		}
	var compiled_handle_profile := build_active_tool_profile_preset_data(
		_resolve_handle_profile_snapshot_name()
	)
	var handle_runtime := compiled_handle_profile.get(
		"compiled_profile",
		{}
	) as Dictionary
	if not bool(handle_runtime.get("valid", false)):
		_handle_change_last_reason = &"handle_profile_invalid"
		return {
			"ok": false,
			"reason": _handle_change_last_reason,
			"handle_change_active": true,
		}
	var original_body := _handle_change_original_body
	var profile_unchanged := (
		_build_active_handle_profile_signature()
		== _handle_change_initial_profile_signature
	)
	var replacement_body: Resource = null
	if profile_unchanged:
		replacement_body = original_body.duplicate(true) as Resource
		if replacement_body != null:
			replacement_body.set("body_id", StringName())
			replacement_body.set(
				"source_record_id",
				StringName("v2_handle_change_%s" % str(Time.get_ticks_usec()))
			)
			replacement_body.set("committed_layer_id", StringName())
			replacement_body.set("layer_active", true)
			replacement_body.set(
				"shape_kind",
				get_active_handle_path_shape_kind()
			)
			replacement_body.set("path_points", spline_line_points)
			replacement_body.set(
				"path_surface_normals",
				spline_line_surface_normals
			)
			replacement_body.set("material_variant_id", active_material_variant_id)
			replacement_body.set("builder_path_id", builder_path_id)
			replacement_body.set("builder_component_id", builder_component_id)
			replacement_body.set("forge_intent", forge_intent)
			replacement_body.set("equipment_context", equipment_context)
			replacement_body.set("profile_display_name", active_profile_display_name)
			replacement_body.set(
				"handle_profile_authoring_snapshot",
				_build_handle_profile_authoring_snapshot(true)
			)
			replacement_body.set("created_timestamp", Time.get_unix_time_from_system())
			replacement_body.set("updated_timestamp", Time.get_unix_time_from_system())
			if replacement_body.has_method("normalize"):
				replacement_body.call("normalize")
			material_bodies.append(replacement_body)
	else:
		replacement_body = _append_profile_extrusion_material_body(true)
	if replacement_body == null:
		_handle_change_last_reason = &"handle_replacement_build_failed"
		return {
			"ok": false,
			"reason": _handle_change_last_reason,
			"handle_change_active": true,
		}
	selected_material_body_id = StringName(replacement_body.get("body_id"))
	_clear_spline_transient_state()
	_clear_handle_change_transaction()
	_reset_committed_volume_cache(&"handle_change_applied_pending")
	_mark_material_usage_summary_dirty()
	_handle_change_last_reason = &"handle_change_applied_pending"
	_publish_bounded_history_transition(
		BOUNDED_HISTORY_TRANSITION_PROTECTED_CHANGED,
		null,
		[replacement_body]
	)
	mark_updated()
	return {
		"ok": true,
		"reason": _handle_change_last_reason,
		"handle_change_active": false,
		"replacement_body_id": selected_material_body_id,
	}

func cancel_handle_change() -> bool:
	if not is_handle_change_active():
		return false
	var original_body := _handle_change_original_body
	var original_layer := _handle_change_original_protected_layer
	var body_insert_index := clampi(
		_handle_change_original_body_index,
		0,
		material_bodies.size()
	)
	material_bodies.insert(body_insert_index, original_body)
	if original_layer != null:
		var layer_insert_index := clampi(
			_handle_change_original_protected_layer_index,
			0,
			protected_forge_layers.size()
		)
		protected_forge_layers.insert(layer_insert_index, original_layer)
	selected_material_body_id = StringName(original_body.get("body_id"))
	active_handle_path_mode_id = _resolve_handle_path_mode_id_from_body(
		original_body
	)
	_clear_spline_transient_state()
	_clear_handle_change_transaction()
	_rebuild_material_ledger()
	_mark_material_usage_summary_dirty()
	_handle_change_last_reason = &"handle_change_cancelled"
	_publish_bounded_history_transition(
		BOUNDED_HISTORY_TRANSITION_PROTECTED_CHANGED,
		original_layer,
		[original_body]
	)
	mark_updated()
	return true

func capture_protected_handle_snapshot() -> Dictionary:
	var slot := _resolve_current_protected_handle_slot()
	if not bool(slot.get("ok", false)):
		return {
			"ok": false,
			"reason": StringName(slot.get(
				"reason",
				&"protected_handle_slot_invalid"
			)),
		}
	if bool(slot.get("empty", true)):
		return {
			"ok": true,
			"reason": &"captured_empty",
			"schema_id": PROTECTED_HANDLE_SNAPSHOT_SCHEMA_ID,
			"schema_version": 1,
			"empty": true,
			"body_id": StringName(),
			"layer_id": StringName(),
			"body": null,
			"layer": null,
			"body_index": -1,
			"layer_index": -1,
			"was_selected": false,
		}
	var body := slot.get("body", null) as Resource
	var layer := slot.get("layer", null) as Resource
	if body == null or layer == null:
		return {
			"ok": false,
			"reason": &"protected_handle_slot_missing_resources",
		}
	var body_copy := body.duplicate(true) as Resource
	var layer_copy := layer.duplicate(true) as Resource
	if body_copy == null or layer_copy == null:
		return {
			"ok": false,
			"reason": &"protected_handle_slot_duplicate_failed",
		}
	var body_id := StringName(body.get("body_id"))
	return {
		"ok": true,
		"reason": &"captured",
		"schema_id": PROTECTED_HANDLE_SNAPSHOT_SCHEMA_ID,
		"schema_version": 1,
		"empty": false,
		"body_id": body_id,
		"layer_id": StringName(layer.get("layer_id")),
		"body": body_copy,
		"layer": layer_copy,
		"body_index": int(slot.get("body_index", -1)),
		"layer_index": int(slot.get("layer_index", -1)),
		"was_selected": selected_material_body_id == body_id,
	}

func restore_protected_handle_snapshot(snapshot: Dictionary) -> bool:
	if (
		has_pending_bounded_history_promotion()
		or is_handle_change_active()
		or StringName(snapshot.get("schema_id", StringName()))
		!= PROTECTED_HANDLE_SNAPSHOT_SCHEMA_ID
		or int(snapshot.get("schema_version", 0)) != 1
		or not bool(snapshot.get("ok", false))
	):
		return false
	var current_slot := _resolve_current_protected_handle_slot()
	if not bool(current_slot.get("ok", false)):
		return false
	var current_body := current_slot.get("body", null) as Resource
	var current_layer := current_slot.get("layer", null) as Resource
	var current_body_index := int(current_slot.get("body_index", -1))
	var current_layer_index := int(current_slot.get("layer_index", -1))
	if (
		(current_body == null) != (current_layer == null)
		or (
			current_body != null
			and (
				current_body_index < 0
				or current_body_index >= material_bodies.size()
				or material_bodies[current_body_index] != current_body
				or current_layer_index < 0
				or current_layer_index >= protected_forge_layers.size()
				or protected_forge_layers[current_layer_index]
				!= current_layer
			)
		)
	):
		return false
	var target_is_empty := bool(snapshot.get("empty", false))
	var target_body: Resource = null
	var target_layer: Resource = null
	var target_body_id := StringName()
	var target_layer_id := StringName()
	if not target_is_empty:
		var captured_body := snapshot.get("body", null) as Resource
		var captured_layer := snapshot.get("layer", null) as Resource
		if captured_body == null or captured_layer == null:
			return false
		target_body = captured_body.duplicate(true) as Resource
		target_layer = captured_layer.duplicate(true) as Resource
		if target_body == null or target_layer == null:
			return false
		if target_body.has_method("normalize"):
			target_body.call("normalize")
		if target_layer.has_method("normalize"):
			target_layer.call("normalize")
		target_body_id = StringName(target_body.get("body_id"))
		target_layer_id = StringName(target_layer.get("layer_id"))
		var target_layer_body_ids := target_layer.get("body_ids") as Array
		if (
			target_body_id == StringName()
			or target_layer_id == StringName()
			or target_body_id
			!= StringName(snapshot.get("body_id", StringName()))
			or target_layer_id
			!= StringName(snapshot.get("layer_id", StringName()))
			or not _is_user_handle_material_body(target_body)
			or not _is_material_body_committed(target_body)
			or not _is_material_body_active(target_body)
			or StringName(target_body.get("committed_layer_id"))
			!= target_layer_id
			or not _is_protected_history_layer(target_layer)
			or target_layer_body_ids.size() != 1
			or StringName(target_layer_body_ids[0]) != target_body_id
		):
			return false

	var other_live_handles: Array[Resource] = []
	for candidate_body: Resource in _collect_live_handle_material_bodies():
		if candidate_body != current_body:
			other_live_handles.append(candidate_body)
	if (
		(not target_is_empty and not other_live_handles.is_empty())
		or (target_is_empty and other_live_handles.size() > 1)
	):
		return false
	if target_body != null:
		for candidate_body: Resource in material_bodies:
			if candidate_body == null or candidate_body == current_body:
				continue
			if StringName(candidate_body.get("body_id")) == target_body_id:
				return false
		for layer_group: Array[Resource] in [
			forge_layers,
			undone_forge_layers,
			protected_forge_layers,
		]:
			for candidate_layer: Resource in layer_group:
				if candidate_layer == null or candidate_layer == current_layer:
					continue
				if StringName(candidate_layer.get("layer_id")) == target_layer_id:
					return false

	var previous_selected_body_id := selected_material_body_id
	var removed_selected_body := (
		current_body != null
		and previous_selected_body_id
		== StringName(current_body.get("body_id"))
	)
	if current_body != null:
		material_bodies.remove_at(current_body_index)
	if current_layer != null:
		protected_forge_layers.remove_at(current_layer_index)
	if target_body != null and target_layer != null:
		var target_body_index := clampi(
			int(snapshot.get("body_index", material_bodies.size())),
			0,
			material_bodies.size()
		)
		var target_layer_index := clampi(
			int(snapshot.get(
				"layer_index",
				protected_forge_layers.size()
			)),
			0,
			protected_forge_layers.size()
		)
		material_bodies.insert(target_body_index, target_body)
		protected_forge_layers.insert(target_layer_index, target_layer)
		if bool(snapshot.get("was_selected", false)) or removed_selected_body:
			selected_material_body_id = target_body_id
	else:
		_normalize_selected_material_body_id()
	if removed_selected_body and selected_material_body_id == StringName():
		select_last_user_material_body()
	else:
		_normalize_selected_material_body_id()
	_rebuild_material_ledger()
	_mark_material_usage_summary_dirty()
	_publish_bounded_history_transition(
		BOUNDED_HISTORY_TRANSITION_PROTECTED_CHANGED,
		target_layer,
		[target_body] if target_body != null else []
	)
	mark_updated()
	return true

func replace_detailing_brush_path_solution(
	control_points: PackedVector3Array,
	control_surface_normals: PackedVector3Array,
	locked_target_kind: StringName,
	locked_target_id: StringName,
	resolved_path_points: PackedVector3Array,
	resolved_surface_normals: PackedVector3Array,
	span_offsets: PackedInt32Array,
	span_validity: Array,
	span_reasons: Array,
	solution_valid: bool,
	solution_reason: StringName,
	selected_point_index: int = -2,
	control_contact_directions: PackedVector3Array = PackedVector3Array(),
	resolved_contact_directions: PackedVector3Array = PackedVector3Array()
) -> bool:
	if active_tool_id != TOOL_DETAILING_BRUSH:
		return false
	var validated := _build_validated_detailing_brush_solution(
		control_points,
		control_surface_normals,
		control_contact_directions,
		locked_target_kind,
		locked_target_id,
		resolved_path_points,
		resolved_surface_normals,
		resolved_contact_directions,
		span_offsets,
		span_validity,
		span_reasons,
		solution_valid,
		solution_reason
	)
	if not bool(validated.get("accepted", false)):
		return false
	var resolved_selected_point_index := selected_point_index
	if resolved_selected_point_index == -2:
		resolved_selected_point_index = control_points.size() - 1
	if (
		resolved_selected_point_index < -1
		or resolved_selected_point_index >= control_points.size()
	):
		return false
	spline_line_points = validated.get(
		"control_points",
		PackedVector3Array()
	) as PackedVector3Array
	spline_line_surface_normals = validated.get(
		"control_surface_normals",
		PackedVector3Array()
	) as PackedVector3Array
	detailing_control_contact_directions = validated.get(
		"control_contact_directions",
		PackedVector3Array()
	) as PackedVector3Array
	detailing_surface_target_kind = locked_target_kind
	detailing_surface_target_id = locked_target_id
	detailing_resolved_path_points = validated.get(
		"resolved_path_points",
		PackedVector3Array()
	) as PackedVector3Array
	detailing_resolved_surface_normals = validated.get(
		"resolved_surface_normals",
		PackedVector3Array()
	) as PackedVector3Array
	detailing_resolved_contact_directions = validated.get(
		"resolved_contact_directions",
		PackedVector3Array()
	) as PackedVector3Array
	detailing_span_offsets = span_offsets.duplicate()
	detailing_span_validity = validated.get("span_validity", []) as Array[bool]
	detailing_span_reasons = validated.get("span_reasons", []) as Array[StringName]
	detailing_solution_valid = solution_valid
	detailing_solution_reason = (
		DETAIL_SOLUTION_REASON_NONE
		if solution_valid
		else StringName(validated.get(
			"solution_reason",
			DETAIL_SOLUTION_REASON_NOT_READY
		))
	)
	spline_line_finished = false
	selected_spline_point_index = resolved_selected_point_index
	spline_line_csg_noodle_enabled = false
	mark_updated()
	return true

func append_spline_line_point(
	local_position: Vector3,
	local_surface_normal: Vector3 = Vector3.FORWARD
) -> int:
	if active_tool_id == TOOL_DETAILING_BRUSH:
		return -1
	_normalize_spline_line()
	if spline_line_finished:
		return -1
	if (
		active_tool_id == TOOL_HANDLES
		and has_handle_material_body()
		and not is_handle_change_active()
	):
		return -1
	if (
		active_tool_id == TOOL_HANDLES
		and spline_line_points.size() >= get_active_handle_required_point_count()
	):
		return -1
	spline_line_points.append(local_position)
	spline_line_surface_normals.append(
		_normalize_path_surface_normal(local_surface_normal)
	)
	selected_spline_point_index = spline_line_points.size() - 1
	mark_updated()
	return selected_spline_point_index

func set_spline_line_point(point_index: int, local_position: Vector3) -> bool:
	if active_tool_id == TOOL_DETAILING_BRUSH:
		return false
	_normalize_spline_line()
	if point_index < 0 or point_index >= spline_line_points.size():
		return false
	spline_line_points[point_index] = local_position
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
	if active_tool_id == TOOL_DETAILING_BRUSH and not can_generate_detailing_brush():
		return false
	if (
		active_tool_id == TOOL_HANDLES
		and spline_line_points.size() != get_active_handle_required_point_count()
	):
		return false
	if spline_line_points.size() < 2 or spline_line_finished:
		return false
	spline_line_finished = true
	selected_spline_point_index = -1
	mark_updated()
	return true

func cancel_spline_line() -> bool:
	if is_handle_change_active():
		return cancel_handle_change()
	_normalize_spline_line()
	if not _has_spline_transient_state():
		return false
	_clear_spline_transient_state()
	mark_updated()
	return true

func can_generate_spline_line_csg_noodle() -> bool:
	_normalize_spline_line()
	if active_tool_id == TOOL_DETAILING_BRUSH:
		return can_generate_detailing_brush()
	return (
		spline_line_points.size() >= 2
		and _calculate_spline_line_path_length() > 0.000001
	)

func can_generate_profile_extrusion_from_spline() -> bool:
	_normalize_spline_line()
	if active_tool_id != TOOL_HANDLES:
		return false
	if has_handle_material_body() and not is_handle_change_active():
		return false
	if spline_line_points.size() != get_active_handle_required_point_count():
		return false
	if not _handle_endpoint_span_meets_minimum(spline_line_points):
		return false
	var compiled_handle_profile: Dictionary = (
		build_active_tool_profile_preset_data("Handle Runtime")
	)
	var handle_runtime: Dictionary = compiled_handle_profile.get(
		"compiled_profile",
		{}
	) as Dictionary
	return bool(handle_runtime.get("valid", false))

func generate_spline_line_csg_noodle() -> bool:
	_normalize_spline_line()
	if active_tool_id == TOOL_DETAILING_BRUSH:
		return generate_detailing_brush()
	if spline_line_points.size() < 2:
		return false
	var body: Resource = _append_spline_line_material_body()
	if body == null:
		return false
	spline_line_points = PackedVector3Array()
	spline_line_surface_normals = PackedVector3Array()
	spline_line_finished = false
	selected_spline_point_index = -1
	spline_line_csg_noodle_enabled = false
	selected_material_body_id = StringName(body.get("body_id"))
	mark_updated()
	return true

func can_generate_detailing_brush() -> bool:
	if active_tool_id != TOOL_DETAILING_BRUSH:
		return false
	if not detailing_solution_valid:
		return false
	var validation := _build_validated_detailing_brush_solution(
		spline_line_points,
		spline_line_surface_normals,
		detailing_control_contact_directions,
		detailing_surface_target_kind,
		detailing_surface_target_id,
		detailing_resolved_path_points,
		detailing_resolved_surface_normals,
		detailing_resolved_contact_directions,
		detailing_span_offsets,
		detailing_span_validity,
		detailing_span_reasons,
		true,
		detailing_solution_reason
	)
	return (
		bool(validation.get("accepted", false))
		and spline_line_points.size() >= 2
		and _calculate_polyline_path_length(
			detailing_resolved_path_points
		) > 0.000001
	)

func generate_detailing_brush() -> bool:
	if not can_generate_detailing_brush():
		return false
	var body: Resource = null
	if is_saved_basic_profile_shape_active():
		body = _append_active_saved_basic_profile_material_body(
			detailing_resolved_path_points,
			detailing_resolved_surface_normals,
			ForgeV2MaterialBodyScript.SHAPE_KIND_PROFILE_PATH,
			"v2_detail_profile",
			ForgeV2MaterialBodyScript.BODY_KIND_DETAILING_BRUSH,
			detailing_surface_target_kind,
			detailing_surface_target_id,
			detailing_resolved_contact_directions
		)
	else:
		body = _append_material_body_record(
			detailing_resolved_path_points,
			active_brush_radius_meters,
			DEFAULT_AMOUNT_RATIO,
			ForgeV2MaterialBodyScript.SHAPE_KIND_CAPSULE_PATH,
			"v2_detail_capsule",
			ForgeV2MaterialBodyScript.BODY_KIND_DETAILING_BRUSH,
			StringName(),
			ForgeV2ProfileShapeLibraryScript.PROFILE_ROLE_NONE,
			PackedVector2Array(),
			Vector2.ZERO,
			0.0,
			detailing_resolved_surface_normals,
			Vector2.ZERO,
			ForgeV2ProfileShapeLibraryScript.BASIC_PROFILE_LOCAL_SIX,
			0.0,
			0,
			0.0,
			detailing_surface_target_kind,
			detailing_surface_target_id
		)
	if body == null:
		return false
	_clear_spline_transient_state()
	selected_material_body_id = StringName(body.get("body_id"))
	mark_updated()
	return true

func generate_profile_extrusion_from_spline() -> bool:
	_normalize_spline_line()
	if is_handle_change_active():
		return bool(apply_handle_change().get("ok", false))
	if has_handle_material_body():
		return false
	if not can_generate_profile_extrusion_from_spline():
		return false
	var body: Resource = _append_profile_extrusion_material_body(true)
	if body == null:
		return false
	spline_line_points = PackedVector3Array()
	spline_line_surface_normals = PackedVector3Array()
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
	if active_tool_id == TOOL_DETAILING_BRUSH:
		return get_detailing_brush_status_label()
	var point_count := get_spline_line_point_count()
	if point_count <= 0:
		return "Spline: no points"
	var state_label := "finished" if spline_line_finished else "editing"
	return "Spline: %s points, %s" % [str(point_count), state_label]

func get_spline_line_csg_noodle_status_label() -> String:
	if active_tool_id == TOOL_DETAILING_BRUSH:
		return get_detailing_brush_status_label()
	if spline_line_points.size() < 2:
		return "CSG noodle: needs 2 points"
	if _calculate_spline_line_path_length() <= 0.000001:
		return "CSG noodle: needs nonzero path length"
	var shape_label := (
		get_active_basic_shape_size_label()
		if active_tool_id != TOOL_HANDLES
		else "radius %.4f m" % active_brush_radius_meters
	)
	return (
		"CSG noodle: active, %s" % shape_label
		if spline_line_csg_noodle_enabled
		else "CSG noodle: ready, %s" % shape_label
	)

func get_profile_extrusion_status_label() -> String:
	if active_tool_id != TOOL_HANDLES:
		return "Profile extrusion: select Handles"
	var point_count := spline_line_points.size()
	var required_point_count := get_active_handle_required_point_count()
	if point_count < required_point_count:
		return "Handle: needs %d points" % required_point_count
	if point_count > required_point_count:
		return "Handle: too many points"
	var endpoint_span := _calculate_handle_endpoint_span(spline_line_points)
	if not _handle_endpoint_span_meets_minimum(spline_line_points):
		return "Handle: needs %.3f m axial span (currently %.3f m)" % [
			HANDLE_MIN_AXIAL_SPAN_METERS,
			endpoint_span,
		]
	var compiled_handle_profile: Dictionary = (
		build_active_tool_profile_preset_data("Handle Runtime")
	)
	var handle_runtime: Dictionary = compiled_handle_profile.get(
		"compiled_profile",
		{}
	) as Dictionary
	if not bool(handle_runtime.get("valid", false)):
		return "Handle: red anchor needs a valid 0.5 mm profile inset"
	return "Handle: ready, %.3f m axial span" % endpoint_span

func get_detailing_brush_status_label() -> String:
	if active_tool_id != TOOL_DETAILING_BRUSH:
		return "Detailing Brush: select tool"
	if (
		detailing_surface_target_kind == StringName()
		or detailing_surface_target_id == StringName()
	):
		return "Detailing Brush: select a surface"
	if spline_line_points.size() < 2:
		return "Detailing Brush: needs 2 control points"
	if not detailing_solution_valid:
		var reason_label := String(detailing_solution_reason).replace("_", " ")
		if reason_label.is_empty() or detailing_solution_reason == DETAIL_SOLUTION_REASON_NONE:
			reason_label = "surface path invalid"
		return "Detailing Brush: invalid - %s" % reason_label
	if not can_generate_detailing_brush():
		return "Detailing Brush: resolved path is not generation-ready"
	return "Detailing Brush: ready, %d controls / %d surface samples" % [
		spline_line_points.size(),
		detailing_resolved_path_points.size(),
	]

func get_detailing_brush_summary() -> Dictionary:
	if active_tool_id != TOOL_DETAILING_BRUSH:
		return {
			"active": false,
			"control_points": PackedVector3Array(),
			"control_surface_normals": PackedVector3Array(),
			"control_contact_directions": PackedVector3Array(),
			"locked_target_kind": StringName(),
			"locked_target_id": StringName(),
			"resolved_path_points": PackedVector3Array(),
			"resolved_surface_normals": PackedVector3Array(),
			"resolved_contact_directions": PackedVector3Array(),
			"span_offsets": PackedInt32Array(),
			"span_validity": [],
			"span_reasons": [],
			"valid": false,
			"reason": DETAIL_SOLUTION_REASON_NOT_READY,
			"can_generate": false,
			"finished": false,
			"selected_point_index": -1,
			"status_label": get_detailing_brush_status_label(),
		}
	return {
		"active": true,
		"control_points": spline_line_points,
		"control_surface_normals": spline_line_surface_normals,
		"control_contact_directions": detailing_control_contact_directions,
		"locked_target_kind": detailing_surface_target_kind,
		"locked_target_id": detailing_surface_target_id,
		"resolved_path_points": detailing_resolved_path_points,
		"resolved_surface_normals": detailing_resolved_surface_normals,
		"resolved_contact_directions": detailing_resolved_contact_directions,
		"span_offsets": detailing_span_offsets,
		"span_validity": detailing_span_validity.duplicate(),
		"span_reasons": detailing_span_reasons.duplicate(),
		"valid": detailing_solution_valid,
		"reason": detailing_solution_reason,
		"can_generate": can_generate_detailing_brush(),
		"finished": spline_line_finished,
		"selected_point_index": selected_spline_point_index,
		"status_label": get_detailing_brush_status_label(),
	}

func get_spline_line_summary() -> Dictionary:
	_normalize_spline_line()
	return {
		"points": spline_line_points,
		"surface_normals": spline_line_surface_normals,
		"point_count": spline_line_points.size(),
		"finished": spline_line_finished,
		"selected_point_index": selected_spline_point_index,
		"status_label": get_spline_line_status_label(),
		"csg_noodle_enabled": spline_line_csg_noodle_enabled,
		"can_generate_csg_noodle": can_generate_spline_line_csg_noodle(),
		"csg_noodle_status_label": get_spline_line_csg_noodle_status_label(),
		"csg_noodle_radius_meters": get_active_deposition_envelope_radius_meters(),
		"can_generate_profile_extrusion": can_generate_profile_extrusion_from_spline(),
		"profile_extrusion_status_label": get_profile_extrusion_status_label(),
		"handle_path_mode_id": active_handle_path_mode_id,
		"handle_path_mode_label": get_active_handle_path_mode_label(),
		"handle_required_point_count": get_active_handle_required_point_count(),
		"detailing_brush": get_detailing_brush_summary(),
	}

func commit_pending_material_bodies_as_layer() -> Resource:
	var pending_bodies: Array[Resource] = _collect_pending_user_material_bodies()
	var pending_handle_bodies: Array[Resource] = []
	for pending_body: Resource in pending_bodies:
		if _is_user_handle_material_body(pending_body):
			pending_handle_bodies.append(pending_body)
	if pending_handle_bodies.size() > 1:
		return null
	# A Handle owns a protected layer, so commit it independently from ordinary
	# pending deposition. The save loop will commit the remaining bodies next.
	if pending_handle_bodies.size() == 1:
		return _commit_material_bodies_as_layer(pending_handle_bodies)
	return _commit_material_bodies_as_layer(pending_bodies)

func commit_material_body_as_layer(body_id: StringName) -> Resource:
	var body: Resource = _find_editable_material_body(body_id)
	if body == null or not _is_material_body_commit_ready(body):
		return null
	return _commit_material_bodies_as_layer([body])

func commit_material_body_ids_as_layer(
	body_ids: Array[StringName]
) -> Resource:
	if body_ids.is_empty():
		return null
	var resolved_bodies: Array[Resource] = []
	var resolved_body_ids: Array[StringName] = []
	var seen_body_ids: Dictionary = {}
	for body_id: StringName in body_ids:
		if body_id == StringName() or seen_body_ids.has(body_id):
			return null
		var body: Resource = _find_material_body_by_id(body_id)
		if (
			body == null
			or _find_editable_material_body(body_id) != body
			or not _is_material_body_commit_ready(body)
		):
			return null
		var resolved_body_id := StringName(body.get("body_id"))
		if resolved_body_id != body_id:
			return null
		seen_body_ids[body_id] = true
		resolved_bodies.append(body)
		resolved_body_ids.append(resolved_body_id)
	if resolved_body_ids != body_ids:
		return null
	return _commit_material_bodies_as_layer(resolved_bodies)

func is_material_body_commit_ready(body_id: StringName) -> bool:
	return _is_material_body_commit_ready(
		_find_editable_material_body(body_id)
	)

func _commit_material_bodies_as_layer(pending_bodies: Array[Resource]) -> Resource:
	if has_pending_bounded_history_promotion():
		return null
	var commit_ready_bodies: Array[Resource] = []
	for body: Resource in pending_bodies:
		if _is_material_body_commit_ready(body):
			commit_ready_bodies.append(body)
	if commit_ready_bodies.is_empty():
		return null
	var committing_handle: Resource = null
	for commit_ready_body: Resource in commit_ready_bodies:
		if not _is_user_handle_material_body(commit_ready_body):
			continue
		if committing_handle != null:
			return null
		committing_handle = commit_ready_body
	if committing_handle != null:
		if commit_ready_bodies.size() != 1:
			return null
		var committing_handle_id := StringName(committing_handle.get("body_id"))
		for existing_handle: Resource in _collect_live_handle_material_bodies():
			if existing_handle == committing_handle:
				continue
			if (
				StringName(existing_handle.get("body_id")) != committing_handle_id
			):
				return null
	if _must_reject_unsupported_bounded_commit(commit_ready_bodies):
		return null
	var stages_bounded_promotion := _will_stage_bounded_history_promotion(
		commit_ready_bodies
	)
	var committed_bodies: Array[Resource] = _collect_committed_active_user_material_bodies()
	_ensure_material_ledger()
	var promotion_rollback: Dictionary = {}
	if stages_bounded_promotion:
		promotion_rollback = _build_bounded_promotion_rollback_snapshot(
			commit_ready_bodies
		)
	var committed_usage_before: Dictionary = {}
	if material_ledger != null and material_ledger.has_method("get_summary"):
		committed_usage_before = material_ledger.call("get_summary") as Dictionary
	var committed_resolver := _ensure_committed_volume_resolver()
	_ensure_bounded_resolver_cache(committed_bodies)
	var incremental_resolution: Dictionary = committed_resolver.call(
		"build_incremental_committed_usage_summary",
		committed_bodies,
		commit_ready_bodies,
		_get_bounded_history_checkpoint_token(),
		stages_bounded_promotion
	) as Dictionary
	var authoritative_usage_after := incremental_resolution.get(
		"summary",
		{}
	) as Dictionary
	if (
		stages_bounded_promotion
		and not authoritative_usage_after.has("materials")
	):
		_abort_bounded_promotion_cache_candidate(
			committed_resolver,
			promotion_rollback
		)
		return null
	committed_volume_cache_diagnostics = incremental_resolution.get(
		"diagnostics",
		{}
	) as Dictionary
	var layer: Resource = ForgeV2LayerDataScript.new()
	var resolved_usage_after: Dictionary = layer.call(
		"configure_from_material_bodies",
		bounded_history_lifetime_operation_count + 1,
		commit_ready_bodies,
		committed_bodies,
		committed_usage_before,
		authoritative_usage_after
	) as Dictionary
	if (
		stages_bounded_promotion
		and not _can_commit_layer_to_bounded_add_history(
			layer,
			commit_ready_bodies
		)
	):
		_abort_bounded_promotion_cache_candidate(
			committed_resolver,
			promotion_rollback
		)
		return null
	for body: Resource in commit_ready_bodies:
		if body == null:
			continue
		body.set("committed_layer_id", StringName(layer.get("layer_id")))
		body.set("layer_active", true)
	_discard_abandoned_redo_layers()
	var is_protected_commit := _is_protected_commit_group(commit_ready_bodies)
	if is_protected_commit:
		protected_forge_layers.append(layer)
	else:
		forge_layers.append(layer)
	bounded_history_lifetime_operation_count += 1
	if stages_bounded_promotion:
		var promotion_ledger_candidate: Resource = (
			ForgeV2MaterialLedgerScript.new()
		)
		promotion_ledger_candidate.call(
			"replace_with_summary",
			material_ledger.call("get_summary") as Dictionary
		)
		promotion_ledger_candidate.call("apply_layer", layer)
		material_ledger = promotion_ledger_candidate
	elif material_ledger != null and material_ledger.has_method("apply_layer"):
		material_ledger.call("apply_layer", layer)
	else:
		_rebuild_material_ledger()
	if not authoritative_usage_after.is_empty() and _can_reuse_committed_usage_summary(
		resolved_usage_after,
		committed_bodies,
		commit_ready_bodies
	):
		material_usage_summary_cache = resolved_usage_after.duplicate(true)
		material_usage_summary_cache_dirty = false
	else:
		_mark_material_usage_summary_dirty()
	if is_protected_commit:
		_publish_bounded_history_transition(
			BOUNDED_HISTORY_TRANSITION_PROTECTED_CHANGED,
			layer,
			commit_ready_bodies
		)
	elif _can_commit_layer_to_bounded_add_history(layer, commit_ready_bodies):
		if forge_layers.size() > BOUNDED_HISTORY_TAIL_CAPACITY:
			_stage_bounded_history_promotion(
				layer,
				commit_ready_bodies,
				promotion_rollback
			)
		else:
			_publish_bounded_history_transition(
				(
					BOUNDED_HISTORY_TRANSITION_RESET
					if forge_layers.size() == 1
					and not _has_bounded_history_checkpoint()
					else BOUNDED_HISTORY_TRANSITION_APPEND
				),
				layer,
				commit_ready_bodies
			)
	else:
		_suspend_bounded_history(&"unsupported_committed_layer")
		_publish_bounded_history_transition(
			BOUNDED_HISTORY_TRANSITION_FALLBACK,
			layer,
			commit_ready_bodies
		)
	mark_updated()
	return layer

func peek_latest_undo_layer_id() -> StringName:
	if has_pending_bounded_history_promotion():
		return StringName()
	for layer_index in range(forge_layers.size() - 1, -1, -1):
		var layer: Resource = forge_layers[layer_index]
		if layer != null:
			return StringName(layer.get("layer_id"))
	return StringName()

func peek_latest_redo_layer_id() -> StringName:
	if has_pending_bounded_history_promotion():
		return StringName()
	for layer_index in range(undone_forge_layers.size() - 1, -1, -1):
		var layer: Resource = undone_forge_layers[layer_index]
		if layer != null:
			return StringName(layer.get("layer_id"))
	return StringName()

func discard_abandoned_layer_redo() -> bool:
	if (
		undone_forge_layers.is_empty()
		or has_pending_bounded_history_promotion()
	):
		return false
	_discard_abandoned_redo_layers()
	mark_updated()
	return true

func undo_latest_layer() -> bool:
	if forge_layers.is_empty() or has_pending_bounded_history_promotion():
		return false
	var layer: Resource = forge_layers.pop_back()
	if layer == null:
		return false
	undone_forge_layers.append(layer)
	_set_layer_bodies_active(layer, false)
	_rebuild_material_ledger()
	_mark_material_usage_summary_dirty()
	_publish_bounded_history_transition(
		BOUNDED_HISTORY_TRANSITION_UNDO,
		layer,
		_get_layer_material_bodies(layer)
	)
	mark_updated()
	return true

func redo_latest_layer() -> bool:
	if undone_forge_layers.is_empty() or has_pending_bounded_history_promotion():
		return false
	var layer: Resource = undone_forge_layers.pop_back()
	if layer == null:
		return false
	forge_layers.append(layer)
	_set_layer_bodies_active(layer, true)
	_rebuild_material_ledger()
	_mark_material_usage_summary_dirty()
	_publish_bounded_history_transition(
		BOUNDED_HISTORY_TRANSITION_REDO,
		layer,
		_get_layer_material_bodies(layer)
	)
	mark_updated()
	return true

func get_bounded_history_transition() -> Dictionary:
	if _bounded_history_transition.is_empty():
		return {
			"kind": BOUNDED_HISTORY_TRANSITION_NONE,
			"revision": bounded_history_transition_revision,
			"requires_native_ack": false,
			"bounded_history_enabled": _is_bounded_history_active(),
		}
	return _bounded_history_transition.duplicate()

func get_bounded_presentation_descriptor() -> Dictionary:
	var active_tail_layers := _nonnull_layers(forge_layers)
	var redo_stack_layers := _nonnull_layers(undone_forge_layers)
	var redo_timeline_layers := redo_stack_layers.duplicate()
	redo_timeline_layers.reverse()
	var active_tail_bodies := _collect_layer_bodies(active_tail_layers)
	var redo_stack_bodies := _collect_layer_bodies(redo_stack_layers)
	var redo_timeline_bodies := _collect_layer_bodies(redo_timeline_layers)
	var protected_bodies := _collect_protected_material_bodies()
	var checkpoint_packet := _get_bounded_history_checkpoint_token()
	var checkpoint_identity := _get_bounded_history_checkpoint_identity()
	return {
		"schema_version": 1,
		"bounded_history_enabled": _is_bounded_history_active(),
		"bounded_history_configured_enabled": bounded_history_enabled,
		"suspended_reason": bounded_history_suspended_reason,
		"recovery_blocked": (
			bounded_history_recovery_blocked_reason != StringName()
		),
		"recovery_blocked_reason": bounded_history_recovery_blocked_reason,
		"transition_revision": bounded_history_transition_revision,
		"tail_capacity": BOUNDED_HISTORY_TAIL_CAPACITY,
		"lifetime_operation_count": bounded_history_lifetime_operation_count,
		"checkpoint": bounded_history_checkpoint,
		"checkpoint_packet": checkpoint_packet,
		"checkpoint_identity": checkpoint_identity,
		"checkpoint_operation_count": get_bounded_history_checkpoint_operation_count(),
		"checkpoint_mesh_dirty": bool(checkpoint_packet.get(
			"checkpoint_mesh_dirty",
			false
		)),
		"materialized_mesh_operation_count": int(checkpoint_packet.get(
			"materialized_mesh_operation_count",
			0
		)),
		"checkpoint_restore_ready": bool(checkpoint_packet.get(
			"checkpoint_restore_ready",
			false
		)),
		"active_tail_layers": active_tail_layers,
		"active_tail_layer_ids": _layer_ids(active_tail_layers),
		"active_tail_bodies": active_tail_bodies,
		"active_tail_body_ids": _body_ids(active_tail_bodies),
		"redo_tail_layers": redo_stack_layers,
		"redo_tail_layer_ids": _layer_ids(redo_stack_layers),
		"redo_tail_bodies": redo_stack_bodies,
		"redo_tail_body_ids": _body_ids(redo_stack_bodies),
		"redo_timeline_layers": redo_timeline_layers,
		"redo_timeline_layer_ids": _layer_ids(redo_timeline_layers),
		"redo_timeline_bodies": redo_timeline_bodies,
		"redo_timeline_body_ids": _body_ids(redo_timeline_bodies),
		"protected_layers": _nonnull_layers(protected_forge_layers),
		"protected_layer_count": _nonnull_layers(
			protected_forge_layers
		).size(),
		"protected_bodies": protected_bodies,
		"protected_body_ids": _body_ids(protected_bodies),
		"protected_body_count": protected_bodies.size(),
		"logical_body_count": (
			(1 if _has_bounded_history_checkpoint() else 0)
			+ active_tail_bodies.size()
			+ protected_bodies.size()
		),
		"pending_native_ack": has_pending_bounded_history_promotion(),
	}

func has_pending_bounded_history_promotion() -> bool:
	return not _bounded_history_pending_promotion.is_empty()

func acknowledge_bounded_history_transition(
	revision: int,
	native_history_result: Dictionary = {}
) -> bool:
	if (
		not has_pending_bounded_history_promotion()
		or revision != bounded_history_transition_revision
		or revision != int(_bounded_history_pending_promotion.get(
			"revision",
			-1
		))
	):
		return false
	var expected_checkpoint_operation_count := int(
		_bounded_history_pending_promotion.get(
			"expected_checkpoint_operation_count",
			-1
		)
	)
	if (
		not bool(native_history_result.get("ok", false))
		or not bool(native_history_result.get("history_window_enabled", false))
		or String(native_history_result.get("last_mode", ""))
		!= String(BOUNDED_HISTORY_TRANSITION_PROMOTION_APPEND)
		or int(native_history_result.get("checkpoint_operation_count", -1))
		!= expected_checkpoint_operation_count
		or int(native_history_result.get("promotion_boolean_delta", -1)) != 0
		or int(native_history_result.get("promotion_export_delta", -1)) != 0
	):
		return false
	var promoted_layer := _bounded_history_pending_promotion.get(
		"promoted_layer",
		null
	) as Resource
	var promoted_bodies := _bounded_history_pending_promotion.get(
		"promoted_bodies",
		[]
	) as Array
	if promoted_layer == null or promoted_bodies.is_empty():
		return false
	var resolver := _ensure_committed_volume_resolver()
	var sample_cell_size_meters := float(
		resolver.call("get_incremental_sample_cell_size_meters")
	)
	if sample_cell_size_meters <= 0.0 and _has_bounded_history_checkpoint():
		sample_cell_size_meters = float(bounded_history_checkpoint.get(
			"resolver_sample_cell_size_meters"
		))
	if sample_cell_size_meters <= 0.0:
		return false
	var checkpoint_summary: Dictionary = {}
	if _has_bounded_history_checkpoint():
		checkpoint_summary = bounded_history_checkpoint.call(
			"get_material_ledger_summary"
		) as Dictionary
	_ensure_material_ledger()
	var next_checkpoint_summary := material_ledger.call(
		"build_checkpoint_summary_after_layer",
		checkpoint_summary,
		promoted_layer
	) as Dictionary
	var live_ledger_summary_before := material_ledger.call(
		"get_summary"
	) as Dictionary
	var bounded_ledger_candidate: Resource = ForgeV2MaterialLedgerScript.new()
	bounded_ledger_candidate.call(
		"rebuild_from_checkpoint_and_layers",
		next_checkpoint_summary,
		protected_forge_layers,
		forge_layers
	)
	var bounded_ledger_summary := bounded_ledger_candidate.call(
		"get_summary"
	) as Dictionary
	if not _material_ledger_summaries_match(
		live_ledger_summary_before,
		bounded_ledger_summary
	):
		return false
	if not _bounded_ledger_retains_only_live_layer_ids(
		bounded_ledger_candidate
	):
		return false
	var previous_checkpoint_token := _bounded_history_pending_promotion.get(
		"previous_checkpoint_token",
		{}
	) as Dictionary
	var occupancy_result := resolver.call(
		"build_checkpoint_occupancy_delta",
		previous_checkpoint_token,
		promoted_bodies,
		sample_cell_size_meters
	) as Dictionary
	if not bool(occupancy_result.get("ok", false)):
		return false
	_ensure_bounded_history_checkpoint()
	var next_checkpoint_identity := bounded_history_checkpoint.call(
		"build_next_identity_descriptor",
		expected_checkpoint_operation_count
	) as Dictionary
	if next_checkpoint_identity.is_empty():
		return false
	var next_checkpoint_token := next_checkpoint_identity.duplicate()
	next_checkpoint_token["checkpoint_initialized"] = true
	next_checkpoint_token["checkpoint_restore_ready"] = false
	next_checkpoint_token["material_variant_id"] = StringName(
		promoted_layer.get("operation_material_id")
	)
	next_checkpoint_token["resolver_sample_cell_size_meters"] = (
		sample_cell_size_meters
	)
	var active_rebased_bodies := _collect_committed_active_user_material_bodies()
	var pre_rebase_body_tokens := _bounded_history_pending_promotion.get(
		"pre_rebase_body_tokens",
		[]
	) as Array
	var rebase_plan := resolver.call(
		"build_incremental_committed_cache_rebase_plan",
		next_checkpoint_token,
		active_rebased_bodies,
		pre_rebase_body_tokens,
		previous_checkpoint_token
	) as Dictionary
	if (
		not bool(rebase_plan.get("ok", false))
		or not bool(resolver.call(
			"has_pending_incremental_committed_cache_candidate"
		))
		or not bool(resolver.call(
			"validate_incremental_committed_cache_rebase_plan",
			rebase_plan
		))
		or not bool(bounded_history_checkpoint.call(
			"can_advance_logical_checkpoint_with_occupancy_delta",
			expected_checkpoint_operation_count,
			next_checkpoint_identity,
			StringName(promoted_layer.get("operation_material_id")),
			sample_cell_size_meters,
			occupancy_result
		))
	):
		return false
	var rebase_result := resolver.call(
		"commit_incremental_committed_cache_rebase",
		rebase_plan
	) as Dictionary
	if not bool(rebase_result.get("ok", false)):
		return false
	var checkpoint_advanced := bool(bounded_history_checkpoint.call(
		"advance_logical_checkpoint_with_occupancy_delta",
		expected_checkpoint_operation_count,
		next_checkpoint_identity,
		StringName(promoted_layer.get("operation_material_id")),
		next_checkpoint_summary,
		bounded_history_lifetime_operation_count,
		sample_cell_size_meters,
		occupancy_result
	))
	if not checkpoint_advanced:
		resolver.call(
			"rollback_incremental_committed_cache_rebase",
			rebase_plan
		)
		return false
	# Swap in the candidate only after every pre-ACK validation succeeds.
	# Its prefix has no historical source IDs and its suffix contains at most
	# the protected layer(s) plus the five active tail layer IDs.
	material_ledger = bounded_ledger_candidate
	material_usage_summary_cache = bounded_ledger_summary.duplicate(true)
	material_usage_summary_cache_dirty = false
	resolver.call("commit_incremental_committed_cache_candidate")
	committed_volume_cache_diagnostics = rebase_result.duplicate(true)
	var promoted_source_ids: Array = promoted_layer.get(
		"source_record_ids"
	) as Array
	var normalized_source_ids: Array[StringName] = []
	for source_id_variant: Variant in promoted_source_ids:
		normalized_source_ids.append(StringName(source_id_variant))
	_remove_volume_strokes_by_id(normalized_source_ids)
	_bounded_history_pending_promotion = {}
	_bounded_history_transition["requires_native_ack"] = false
	_bounded_history_transition["pending_native_ack"] = false
	_bounded_history_transition["acknowledged"] = true
	_bounded_history_transition["checkpoint"] = bounded_history_checkpoint
	_bounded_history_transition["checkpoint_packet"] = (
		_get_bounded_history_checkpoint_token()
	)
	_bounded_history_transition["checkpoint_identity"] = (
		_get_bounded_history_checkpoint_identity()
	)
	_bounded_history_transition["checkpoint_operation_count"] = (
		expected_checkpoint_operation_count
	)
	_bounded_history_transition["checkpoint_mesh_dirty"] = true
	_bounded_history_transition["logical_body_count"] = (
		1
		+ int((_bounded_history_transition.get(
			"active_tail_bodies",
			[]
		) as Array).size())
		+ int((_bounded_history_transition.get(
			"protected_bodies",
			[]
		) as Array).size())
	)
	mark_updated()
	return true

func reject_bounded_history_transition(
	revision: int,
	reason: StringName = &"native_promotion_rejected"
) -> bool:
	if (
		not has_pending_bounded_history_promotion()
		or revision != int(_bounded_history_pending_promotion.get(
			"revision",
			-1
		))
	):
		return false
	var rollback_snapshot := _bounded_history_pending_promotion.get(
		"rollback_snapshot",
		{}
	) as Dictionary
	# A later stroke may have been completed while this native promotion was
	# awaiting its asynchronous operand.  It is not part of the older rollback
	# snapshot and must remain pending rather than being silently discarded.
	var retained_pending_bodies := _collect_pending_user_material_bodies()
	var retained_source_ids: Dictionary = {}
	for pending_body: Resource in retained_pending_bodies:
		if pending_body == null:
			continue
		var source_id := StringName(pending_body.get("source_record_id"))
		if source_id != StringName():
			retained_source_ids[source_id] = true
	var retained_pending_strokes: Array[Resource] = []
	for stroke: Resource in volume_strokes:
		if (
			stroke != null
			and retained_source_ids.has(StringName(stroke.get("stroke_id")))
		):
			retained_pending_strokes.append(stroke)
	var retained_selected_body_id := selected_material_body_id
	_abort_bounded_promotion_cache_candidate(
		_ensure_committed_volume_resolver(),
		rollback_snapshot
	)
	_restore_bounded_promotion_rollback_snapshot(rollback_snapshot)
	for pending_body: Resource in retained_pending_bodies:
		if pending_body == null:
			continue
		var pending_body_id := StringName(pending_body.get("body_id"))
		if _find_material_body_by_id(pending_body_id) == null:
			material_bodies.append(pending_body)
	for pending_stroke: Resource in retained_pending_strokes:
		if pending_stroke == null:
			continue
		var pending_stroke_id := StringName(pending_stroke.get("stroke_id"))
		if _find_volume_stroke_by_id(pending_stroke_id) == null:
			volume_strokes.append(pending_stroke)
	if _find_material_body_by_id(retained_selected_body_id) != null:
		selected_material_body_id = retained_selected_body_id
	_normalize_selected_material_body_id()
	_bounded_history_pending_promotion = {}
	_suspend_bounded_history(
		reason if reason != StringName() else &"native_promotion_rejected"
	)
	_publish_bounded_history_transition(
		BOUNDED_HISTORY_TRANSITION_FALLBACK,
		null,
		[]
	)
	mark_updated()
	return true

func set_bounded_history_checkpoint_export_provider(
	provider: Callable
) -> void:
	_bounded_history_checkpoint_export_provider = provider

func clear_bounded_history_checkpoint_export_provider(
	provider: Callable = Callable()
) -> void:
	if (
		provider.is_valid()
		and provider != _bounded_history_checkpoint_export_provider
	):
		return
	_bounded_history_checkpoint_export_provider = Callable()

func set_runtime_contract_mesh_export_provider(provider: Callable) -> void:
	_runtime_contract_mesh_export_provider = provider

func clear_runtime_contract_mesh_export_provider(
	provider: Callable = Callable()
) -> void:
	if provider.is_valid() and provider != _runtime_contract_mesh_export_provider:
		return
	_runtime_contract_mesh_export_provider = Callable()

func request_runtime_contract_mesh_export() -> Dictionary:
	if not _runtime_contract_mesh_export_provider.is_valid():
		return {
			"ok": false,
			"error_code": "RUNTIME_CONTRACT_MESH_PROVIDER_UNAVAILABLE",
		}
	var packet_variant: Variant = _runtime_contract_mesh_export_provider.call()
	if not packet_variant is Dictionary:
		return {
			"ok": false,
			"error_code": "RUNTIME_CONTRACT_MESH_PACKET_INVALID",
		}
	return packet_variant as Dictionary

func mark_bounded_history_recovery_blocked(reason: StringName) -> void:
	bounded_history_recovery_blocked_reason = (
		reason if reason != StringName() else &"checkpoint_recovery_blocked"
	)

func clear_bounded_history_recovery_blocked() -> void:
	bounded_history_recovery_blocked_reason = StringName()

func materialize_bounded_history_checkpoint(
	native_checkpoint_packet: Dictionary
) -> bool:
	if not _has_bounded_history_checkpoint():
		return true
	var expected_count := get_bounded_history_checkpoint_operation_count()
	var materialized := bool(bounded_history_checkpoint.call(
		"materialize_from_native_packet",
		native_checkpoint_packet,
		expected_count
	))
	if not materialized:
		return false
	clear_bounded_history_recovery_blocked()
	var resolver := _ensure_committed_volume_resolver()
	if resolver.has_method("rebase_incremental_committed_cache"):
		resolver.call(
			"rebase_incremental_committed_cache",
			_get_bounded_history_checkpoint_token(),
			_collect_committed_active_user_material_bodies()
		)
	if not _bounded_history_transition.is_empty():
		_bounded_history_transition["checkpoint"] = bounded_history_checkpoint
		_bounded_history_transition["checkpoint_packet"] = (
			_get_bounded_history_checkpoint_token()
		)
		_bounded_history_transition["checkpoint_identity"] = (
			_get_bounded_history_checkpoint_identity()
		)
		_bounded_history_transition["checkpoint_mesh_dirty"] = false
		_bounded_history_transition["materialized_mesh_operation_count"] = (
			expected_count
		)
	return true

func materialize_bounded_history_checkpoint_for_persistence() -> bool:
	if not _has_bounded_history_checkpoint():
		return true
	if bool(bounded_history_checkpoint.call("is_restore_ready")):
		return true
	if not _bounded_history_checkpoint_export_provider.is_valid():
		return false
	var packet_variant: Variant = _bounded_history_checkpoint_export_provider.call(
		get_bounded_history_checkpoint_operation_count()
	)
	if not packet_variant is Dictionary:
		return false
	return materialize_bounded_history_checkpoint(packet_variant as Dictionary)

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

func is_saved_basic_profile_shape_active() -> bool:
	return (
		active_basic_shape_source_id == BASIC_SHAPE_SOURCE_SAVED_PROFILE
		and ForgeV2ProfileShapeLibraryScript.is_compiled_basic_profile_runtime_valid(
			active_saved_basic_profile_data
		)
	)

func get_active_basic_shape_label() -> String:
	if is_saved_basic_profile_shape_active():
		var saved_label := String(active_saved_basic_profile_data.get(
			"label",
			String(active_saved_basic_profile_id)
		)).strip_edges()
		return saved_label if not saved_label.is_empty() else "Saved 2D Profile"
	return "Primitive / circular brush"

func get_active_basic_shape_size_label() -> String:
	if (
		active_tool_id == TOOL_HANDLES
		or not is_saved_basic_profile_shape_active()
	):
		return get_brush_radius_label()
	var runtime_data := _get_active_saved_basic_profile_runtime_data()
	var polygon: PackedVector2Array = runtime_data.get(
		"deposition_polygon_2d_meters",
		PackedVector2Array()
	)
	var size := ForgeV2ProfileShapeLibraryScript.calculate_polygon_size_meters(
		polygon
	)
	return "Fixed %.4f x %.4f m" % [size.x, size.y]

func get_active_deposition_envelope_radius_meters() -> float:
	if (
		active_tool_id == TOOL_HANDLES
		or not is_saved_basic_profile_shape_active()
	):
		return active_brush_radius_meters
	var runtime_data := _get_active_saved_basic_profile_runtime_data()
	var polygon: PackedVector2Array = runtime_data.get(
		"deposition_polygon_2d_meters",
		PackedVector2Array()
	)
	return maxf(
		ForgeV2ProfileShapeLibraryScript.calculate_polygon_max_radius_meters(
			polygon
		),
		0.001
	)

func get_active_deposition_sample_radius_meters() -> float:
	if (
		active_tool_id == TOOL_HANDLES
		or not is_saved_basic_profile_shape_active()
	):
		return active_brush_radius_meters
	var runtime_data := _get_active_saved_basic_profile_runtime_data()
	return maxf(
		float(runtime_data.get(
			"contact_distance_meters",
			ForgeV2ProfileShapeLibraryScript.BASIC_PROFILE_ANCHOR_CLEARANCE_METERS
		)),
		ForgeV2ProfileShapeLibraryScript.BASIC_PROFILE_ANCHOR_CLEARANCE_METERS
	)

func get_active_tool_label() -> String:
	match active_tool_id:
		TOOL_SPLINE_LINE:
			return "Spline Line"
		TOOL_HANDLES:
			return "Change Handle" if has_handle_material_body() else "Handles"
		TOOL_DETAILING_BRUSH:
			return "Detailing Brush"
		_:
			return "CSG Material Stroke"

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
		{
			"id": TOOL_HANDLES,
			"label": (
				"Change Handle"
				if has_handle_material_body()
				else "Handles"
			),
		},
		{
			"id": TOOL_DETAILING_BRUSH,
			"label": "Detailing Brush",
		},
	]

func get_primitive_options() -> Array[Dictionary]:
	return ForgeV2PrimitiveCatalogScript.build_option_entries()

func get_profile_options() -> Array[Dictionary]:
	if active_tool_id == TOOL_HANDLES:
		return ForgeV2ProfileShapeLibraryScript.build_handle_profile_entries()
	return ForgeV2ProfileShapeLibraryScript.build_profile_entries(ForgeV2ProfileShapeLibraryScript.PROFILE_FAMILY_BASIC)

func get_active_profile_label() -> String:
	if not active_profile_display_name.strip_edges().is_empty():
		return active_profile_display_name.strip_edges()
	return ForgeV2ProfileShapeLibraryScript.get_profile_label(active_profile_id)

func get_active_profile_settings_summary() -> Dictionary:
	_normalize_active_profile_settings()
	var profile_builder_settings := _build_active_profile_builder_settings_summary()
	var handle_builder_settings := _build_handle_builder_settings_summary()
	var size_max_meters := PROFILE_SIZE_MAX_METERS
	var anchor_min_meters := -PROFILE_SIZE_MAX_METERS
	var anchor_max_meters := PROFILE_SIZE_MAX_METERS
	var preview_anchor := Vector2(active_profile_anchor_x_meters, active_profile_anchor_y_meters)
	if bool(profile_builder_settings.get("is_active", false)):
		var guide_polygon: PackedVector2Array = profile_builder_settings.get("guide_polygon_2d_meters", PackedVector2Array())
		if guide_polygon.size() >= 3:
			var guide_bounds := ForgeV2ProfileShapeLibraryScript.calculate_polygon_bounds(guide_polygon)
			size_max_meters = maxf(maxf(guide_bounds.size.x, guide_bounds.size.y), PROFILE_SIZE_MIN_METERS)
			anchor_min_meters = minf(guide_bounds.position.x, guide_bounds.position.y)
			anchor_max_meters = maxf(guide_bounds.position.x + guide_bounds.size.x, guide_bounds.position.y + guide_bounds.size.y)
		preview_anchor = profile_builder_settings.get("anchor_2d_meters", preview_anchor) as Vector2
	return {
		"profile_id": active_profile_id,
		"profile_label": get_active_profile_label(),
		"width_meters": active_profile_width_meters,
		"height_meters": active_profile_height_meters,
		"anchor_x_meters": preview_anchor.x,
		"anchor_y_meters": preview_anchor.y,
		"rotation_degrees": active_profile_rotation_degrees,
		"size_min_meters": PROFILE_SIZE_MIN_METERS,
		"size_max_meters": size_max_meters,
		"anchor_min_meters": anchor_min_meters,
		"anchor_max_meters": anchor_max_meters,
		"rotation_min_degrees": PROFILE_ROTATION_MIN_DEGREES,
		"rotation_max_degrees": PROFILE_ROTATION_MAX_DEGREES,
		"preview_polygon_2d_meters": _resolve_active_profile_polygon(),
		"profile_builder": profile_builder_settings,
		"handle_builder": handle_builder_settings,
	}

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
	var layer_count := get_bounded_history_checkpoint_operation_count()
	for layer: Resource in protected_forge_layers:
		if layer != null:
			layer_count += 1
	for layer: Resource in forge_layers:
		if layer != null:
			layer_count += 1
	return layer_count

func get_active_tail_layer_count() -> int:
	var layer_count := 0
	for layer: Resource in forge_layers:
		if layer != null:
			layer_count += 1
	return layer_count

func get_protected_layer_count() -> int:
	var layer_count := 0
	for layer: Resource in protected_forge_layers:
		if layer != null:
			layer_count += 1
	return layer_count

func get_bounded_history_checkpoint_operation_count() -> int:
	if not _has_bounded_history_checkpoint():
		return 0
	return int(bounded_history_checkpoint.get("accumulated_operation_count"))

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

func get_committed_volume_cache_diagnostics() -> Dictionary:
	var diagnostics := committed_volume_cache_diagnostics.duplicate(true)
	if committed_volume_resolver != null and committed_volume_resolver.has_method(
		"get_incremental_committed_cache_diagnostics"
	):
		var resolver_diagnostics: Dictionary = committed_volume_resolver.call(
			"get_incremental_committed_cache_diagnostics"
		) as Dictionary
		for diagnostic_key: Variant in resolver_diagnostics.keys():
			diagnostics[diagnostic_key] = resolver_diagnostics[diagnostic_key]
	return diagnostics

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
	if _has_bounded_history_checkpoint():
		_ensure_material_ledger()
		material_usage_summary_cache = (
			material_ledger.call("get_summary") as Dictionary
			if material_ledger != null
			else {}
		)
		material_usage_summary_cache_dirty = false
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


func get_material_spatial_usage_summary() -> Dictionary:
	if has_pending_bounded_history_promotion():
		return {
			"ok": false,
			"reason": &"spatial_usage_bounded_promotion_pending",
		}
	var committed_bodies := _collect_committed_active_user_material_bodies()
	var spatial_resolver := ForgeV2MaterialVolumeResolverScript.new()
	if _has_bounded_history_checkpoint():
		var restore_result := spatial_resolver.call(
			"restore_incremental_committed_cache_from_checkpoint",
			_get_bounded_history_checkpoint_token(),
			committed_bodies
		) as Dictionary
		if not bool(restore_result.get("ok", false)):
			return {
				"ok": false,
				"reason": StringName(restore_result.get(
					"reason",
					&"spatial_usage_checkpoint_restore_failed"
				)),
			}
		return spatial_resolver.call(
			"build_cached_spatial_usage_summary"
		) as Dictionary
	# Pre-checkpoint and legacy-unbounded WIPs are reconstructed once here at
	# save/bake. Current bounded projects take the checkpoint + retained-tail
	# path above; this compatibility path never enters the per-stroke hot loop.
	return spatial_resolver.call(
		"build_spatial_usage_summary",
		committed_bodies
	) as Dictionary

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
		"active_basic_shape_source": active_basic_shape_source_id,
		"active_saved_basic_profile_id": active_saved_basic_profile_id,
		"active_basic_shape_label": get_active_basic_shape_label(),
		"active_basic_shape_size_label": get_active_basic_shape_size_label(),
		"primitive_size_controls_enabled": (
			active_tool_id == TOOL_HANDLES
			or not is_saved_basic_profile_shape_active()
		),
		"active_profile": active_profile_id,
		"active_profile_label": get_active_profile_label(),
		"active_profile_settings": get_active_profile_settings_summary(),
		"has_handle_body": has_handle_material_body(),
		"handle_body_count": get_handle_material_body_count(),
		"handle_change_active": is_handle_change_active(),
		"handle_source_profile_id": get_handle_change_source_profile_id(),
		"handle_change_reason": _handle_change_last_reason,
		"active_handle_path_mode_id": active_handle_path_mode_id,
		"active_handle_path_mode_label": get_active_handle_path_mode_label(),
		"active_handle_required_point_count": get_active_handle_required_point_count(),
		"handle_path_mode_options": get_handle_path_mode_options(),
		"profile_options": get_profile_options(),
		"profile_extrusion_status_label": get_profile_extrusion_status_label(),
		"can_generate_profile_extrusion": can_generate_profile_extrusion_from_spline(),
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
		"detailing_brush": get_detailing_brush_summary(),
		"detailing_brush_status_label": get_detailing_brush_status_label(),
		"can_generate_detailing_brush": can_generate_detailing_brush(),
		"selected_spline_point_index": selected_spline_point_index,
		"material_body_count": get_material_body_count(),
		"seed_material_body_count": get_seed_material_body_count(),
		"user_material_body_count": get_user_material_body_count(),
		"pending_material_body_count": get_pending_material_body_count(),
		"committed_layer_count": get_committed_layer_count(),
		"active_tail_layer_count": get_active_tail_layer_count(),
		"protected_layer_count": get_protected_layer_count(),
		"undone_layer_count": get_undone_layer_count(),
		"bounded_history": get_bounded_presentation_descriptor(),
		"selected_material_body_id": selected_material_body_id,
		"selected_material_body": _build_selected_material_body_summary(),
		"material_body_stack_entries": get_material_body_stack_entries(),
		"material_usage_summary": resolved_material_usage_summary,
		"material_usage_label": resolved_material_usage_label,
		"material_ledger_summary": get_material_ledger_summary(),
		"material_ledger_label": get_material_ledger_label(),
		"committed_volume_cache_diagnostics": get_committed_volume_cache_diagnostics(),
	}

func build_authoring_export_snapshot() -> Dictionary:
	var checkpoint_persistable := (
		materialize_bounded_history_checkpoint_for_persistence()
	)
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
	var protected_layer_snapshots: Array[Dictionary] = []
	for layer: Resource in protected_forge_layers:
		if layer == null:
			continue
		if layer.has_method("normalize"):
			layer.call("normalize")
		protected_layer_snapshots.append(_build_layer_export_snapshot(layer))
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
		"active_primitive_id": active_primitive_id,
		"active_basic_shape_source_id": active_basic_shape_source_id,
		"active_saved_basic_profile_id": active_saved_basic_profile_id,
		"active_saved_basic_profile_data": active_saved_basic_profile_data.duplicate(
			true
		),
		"active_profile_id": active_profile_id,
		"active_profile_width_meters": active_profile_width_meters,
		"active_profile_height_meters": active_profile_height_meters,
		"active_profile_anchor_x_meters": active_profile_anchor_x_meters,
		"active_profile_anchor_y_meters": active_profile_anchor_y_meters,
		"active_profile_rotation_degrees": active_profile_rotation_degrees,
		"active_profile_display_name": active_profile_display_name,
		"active_handle_face_count": active_handle_face_count,
		"active_handle_rounding_enabled": active_handle_rounding_enabled,
		"active_handle_corner_radius_meters": active_handle_corner_radius_meters,
		"active_handle_control_points_2d_meters": active_handle_control_points_2d_meters,
		"active_handle_grid_snapping_enabled": active_handle_grid_snapping_enabled,
		"active_handle_source_profile_id": active_handle_source_profile_id,
		"active_handle_path_mode_id": active_handle_path_mode_id,
		"active_basic_control_points_2d_meters": active_basic_control_points_2d_meters,
		"active_basic_corner_metadata": _duplicate_basic_corner_metadata(),
		"active_basic_next_corner_serial": active_basic_next_corner_serial,
		"active_basic_grid_snapping_enabled": active_basic_grid_snapping_enabled,
		"platform_contract": get_platform_contract(),
		"spline_line": get_spline_line_summary(),
		"detailing_brush": get_detailing_brush_summary(),
		"material_usage_summary": get_material_usage_summary(),
		"material_ledger_summary": get_material_ledger_summary(),
		"forge_layers": layer_snapshots,
		"protected_forge_layers": protected_layer_snapshots,
		"material_bodies": material_body_snapshots,
		"bounded_history": _build_bounded_history_export_snapshot(),
		"bounded_history_checkpoint_persistable": checkpoint_persistable,
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
	source_prefix: String = "v2_csg_body",
	body_kind: StringName = ForgeV2MaterialBodyScript.BODY_KIND_VOLUME_STROKE,
	profile_id: StringName = StringName(),
	profile_role: StringName = ForgeV2ProfileShapeLibraryScript.PROFILE_ROLE_NONE,
	profile_polygon_2d_meters: PackedVector2Array = PackedVector2Array(),
	profile_anchor_2d_meters: Vector2 = Vector2.ZERO,
	profile_twist_degrees_per_meter: float = 0.0,
	path_surface_normals: PackedVector3Array = PackedVector3Array(),
	profile_contact_point_relative_2d_meters: Vector2 = Vector2.ZERO,
	profile_contact_direction_2d: Vector2 = (
		ForgeV2ProfileShapeLibraryScript.BASIC_PROFILE_LOCAL_SIX
	),
	profile_contact_distance_meters: float = 0.0,
	profile_runtime_schema_version: int = 0,
	profile_rotation_bias_degrees: float = 0.0,
	surface_target_kind: StringName = StringName(),
	surface_target_id: StringName = StringName(),
	path_contact_directions: PackedVector3Array = PackedVector3Array()
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
	body.set("path_surface_normals", path_surface_normals)
	body.set("path_contact_directions", path_contact_directions)
	body.set("body_kind", body_kind)
	body.set("surface_target_kind", surface_target_kind)
	body.set("surface_target_id", surface_target_id)
	if ForgeV2MaterialCompositionPolicyScript.is_protected_handle_entry(body):
		body.set(
			"operation_mode",
			ForgeV2MaterialCompositionPolicyScript.resolve_effective_operation_mode(
				body
			)
		)
		body.set(
			"placement_policy",
			ForgeV2MaterialCompositionPolicyScript.resolve_effective_placement_policy(
				body
			)
		)
	body.set("seed_role", ForgeV2MaterialBodyScript.SEED_ROLE_NONE)
	body.set("profile_id", profile_id)
	body.set("profile_role", profile_role)
	body.set("profile_polygon_2d_meters", profile_polygon_2d_meters)
	body.set("profile_anchor_2d_meters", profile_anchor_2d_meters)
	body.set(
		"profile_contact_point_relative_2d_meters",
		profile_contact_point_relative_2d_meters
	)
	body.set(
		"profile_contact_direction_2d",
		profile_contact_direction_2d
	)
	body.set(
		"profile_contact_distance_meters",
		profile_contact_distance_meters
	)
	body.set(
		"profile_runtime_schema_version",
		profile_runtime_schema_version
	)
	body.set(
		"profile_rotation_bias_degrees",
		profile_rotation_bias_degrees
	)
	body.set("profile_twist_degrees_per_meter", profile_twist_degrees_per_meter)
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

func _append_active_saved_basic_profile_material_body(
	path_points: PackedVector3Array,
	path_surface_normals: PackedVector3Array,
	shape_kind: StringName,
	source_prefix: String,
	body_kind: StringName = ForgeV2MaterialBodyScript.BODY_KIND_PROFILE_EXTRUSION,
	surface_target_kind: StringName = StringName(),
	surface_target_id: StringName = StringName(),
	path_contact_directions: PackedVector3Array = PackedVector3Array()
) -> Resource:
	if not is_saved_basic_profile_shape_active():
		return null
	var runtime_data := _get_active_saved_basic_profile_runtime_data()
	var profile_polygon: PackedVector2Array = runtime_data.get(
		"deposition_polygon_2d_meters",
		PackedVector2Array()
	)
	if profile_polygon.size() < 3:
		return null
	var profile_anchor := runtime_data.get(
		"anchor_2d_meters",
		Vector2.ZERO
	) as Vector2
	var contact_point := runtime_data.get(
		"contact_point_relative_2d_meters",
		Vector2.ZERO
	) as Vector2
	var contact_direction := runtime_data.get(
		"contact_direction_2d",
		ForgeV2ProfileShapeLibraryScript.BASIC_PROFILE_LOCAL_SIX
	) as Vector2
	var body := _append_material_body_record(
		path_points,
		maxf(
			ForgeV2ProfileShapeLibraryScript.calculate_polygon_max_radius_meters(
				profile_polygon
			),
			0.001
		),
		DEFAULT_AMOUNT_RATIO,
		shape_kind,
		source_prefix,
		body_kind,
		active_saved_basic_profile_id,
		ForgeV2ProfileShapeLibraryScript.PROFILE_ROLE_NONE,
		profile_polygon,
		profile_anchor,
		0.0,
		path_surface_normals,
		contact_point,
		contact_direction,
		float(runtime_data.get("contact_distance_meters", 0.0)),
		int(runtime_data.get("schema_version", 0)),
		float(active_saved_basic_profile_data.get(
			"rotation_degrees",
			0.0
		)),
		surface_target_kind,
		surface_target_id,
		path_contact_directions
	)
	if body != null:
		body.set(
			"profile_display_name",
			String(active_saved_basic_profile_data.get(
				"label",
				String(active_saved_basic_profile_id)
			))
		)
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
	if active_tool_id != TOOL_HANDLES and is_saved_basic_profile_shape_active():
		return _append_active_saved_basic_profile_material_body(
			spline_line_points,
			spline_line_surface_normals,
			ForgeV2MaterialBodyScript.SHAPE_KIND_SPLINE_PROFILE_PATH,
			"v2_saved_profile_spline"
		)
	return _append_material_body_record(
		spline_line_points,
		active_brush_radius_meters,
		DEFAULT_AMOUNT_RATIO,
		ForgeV2MaterialBodyScript.SHAPE_KIND_SPLINE_CAPSULE_PATH,
		"v2_spline_noodle",
		ForgeV2MaterialBodyScript.BODY_KIND_VOLUME_STROKE,
		StringName(),
		ForgeV2ProfileShapeLibraryScript.PROFILE_ROLE_NONE,
		PackedVector2Array(),
		Vector2.ZERO,
		0.0,
		spline_line_surface_normals
	)

func _append_profile_extrusion_material_body(is_handle_profile: bool) -> Resource:
	var required_family := (
		ForgeV2ProfileShapeLibraryScript.PROFILE_FAMILY_HANDLE
		if is_handle_profile
		else StringName()
	)
	var resolved_profile_id := ForgeV2ProfileShapeLibraryScript.normalize_profile_id(active_profile_id, required_family)
	var profile_record: Dictionary = ForgeV2ProfileShapeLibraryScript.get_profile_record(resolved_profile_id, active_brush_radius_meters)
	var profile_polygon: PackedVector2Array = _resolve_active_profile_polygon(resolved_profile_id)
	var profile_anchor := Vector2(active_profile_anchor_x_meters, active_profile_anchor_y_meters)
	var profile_contact_point_relative := Vector2.ZERO
	var profile_contact_direction := (
		ForgeV2ProfileShapeLibraryScript.BASIC_PROFILE_LOCAL_SIX
	)
	var profile_contact_distance := 0.0
	var profile_runtime_schema_version := 0
	var profile_rotation_bias_degrees := 0.0
	if (
		is_handle_profile
		and _is_active_handle_builder_profile()
		and resolved_profile_id
		== ForgeV2ProfileShapeLibraryScript.PROFILE_HANDLE_BUILDER
	):
		var compiled_handle_profile: Dictionary = (
			build_active_tool_profile_preset_data("Handle Runtime")
		)
		var handle_runtime: Dictionary = compiled_handle_profile.get(
			"compiled_profile",
			{}
		) as Dictionary
		if not bool(handle_runtime.get("valid", false)):
			return null
		profile_polygon = handle_runtime.get(
			"deposition_polygon_2d_meters",
			PackedVector2Array()
		) as PackedVector2Array
		profile_anchor = handle_runtime.get(
			"anchor_2d_meters",
			profile_anchor
		) as Vector2
		profile_contact_point_relative = handle_runtime.get(
			"contact_point_relative_2d_meters",
			Vector2.ZERO
		) as Vector2
		profile_contact_direction = handle_runtime.get(
			"contact_direction_2d",
			ForgeV2ProfileShapeLibraryScript.BASIC_PROFILE_LOCAL_SIX
		) as Vector2
		profile_contact_distance = float(handle_runtime.get(
			"contact_distance_meters",
			0.0
		))
		profile_runtime_schema_version = int(handle_runtime.get(
			"schema_version",
			0
		))
		profile_rotation_bias_degrees = float(compiled_handle_profile.get(
			"rotation_degrees",
			0.0
		))
	var body_kind := (
		ForgeV2MaterialBodyScript.BODY_KIND_HANDLE_PROFILE
		if is_handle_profile
		else ForgeV2MaterialBodyScript.BODY_KIND_PROFILE_EXTRUSION
	)
	var profile_role := (
		ForgeV2ProfileShapeLibraryScript.PROFILE_ROLE_HANDLE
		if is_handle_profile
		else StringName(profile_record.get("role", ForgeV2ProfileShapeLibraryScript.PROFILE_ROLE_NONE))
	)
	var body := _append_material_body_record(
		spline_line_points,
		maxf(
			active_brush_radius_meters,
			ForgeV2ProfileShapeLibraryScript.calculate_polygon_max_radius_meters(profile_polygon)
		),
		DEFAULT_AMOUNT_RATIO,
		(
			get_active_handle_path_shape_kind()
			if is_handle_profile
			else ForgeV2MaterialBodyScript.SHAPE_KIND_SPLINE_PROFILE_PATH
		),
		"v2_handle_profile" if is_handle_profile else "v2_profile_extrusion",
		body_kind,
		resolved_profile_id,
		profile_role,
		profile_polygon,
		profile_anchor,
		0.0,
		spline_line_surface_normals,
		profile_contact_point_relative,
		profile_contact_direction,
		profile_contact_distance,
		profile_runtime_schema_version,
		profile_rotation_bias_degrees
	)
	if body != null and is_handle_profile:
		body.set("profile_display_name", active_profile_display_name)
		body.set(
			"handle_profile_authoring_snapshot",
			_build_handle_profile_authoring_snapshot(false)
		)
	return body

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
	var body_kind: StringName = StringName(body.get("body_kind"))
	if body_kind == ForgeV2MaterialBodyScript.BODY_KIND_HANDLE_PROFILE:
		kind_label = "Handle"
	elif body_kind == ForgeV2MaterialBodyScript.BODY_KIND_PROFILE_EXTRUSION:
		kind_label = "Profile"
	elif body_kind == ForgeV2MaterialBodyScript.BODY_KIND_DETAILING_BRUSH:
		kind_label = "Detail"
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
		"body_kind": body_kind,
		"surface_target_kind": StringName(body.get("surface_target_kind")),
		"surface_target_id": StringName(body.get("surface_target_id")),
		"seed_role": StringName(body.get("seed_role")),
		"profile_id": StringName(body.get("profile_id")),
		"profile_role": StringName(body.get("profile_role")),
		"profile_label": (
			String(body.get("profile_display_name"))
			if not String(body.get("profile_display_name")).strip_edges().is_empty()
			else ForgeV2ProfileShapeLibraryScript.get_profile_label(
				StringName(body.get("profile_id"))
			)
		),
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
		"path_surface_normals": body.get("path_surface_normals"),
		"path_contact_directions": body.get("path_contact_directions"),
		"surface_target_kind": StringName(body.get("surface_target_kind")),
		"surface_target_id": StringName(body.get("surface_target_id")),
		"radius_meters": float(body.get("radius_meters")),
		"profile_id": StringName(body.get("profile_id")),
		"profile_display_name": String(body.get("profile_display_name")),
		"profile_role": StringName(body.get("profile_role")),
		"profile_polygon_2d_meters": body.get("profile_polygon_2d_meters"),
		"profile_anchor_2d_meters": body.get("profile_anchor_2d_meters"),
		"profile_contact_point_relative_2d_meters": body.get(
			"profile_contact_point_relative_2d_meters"
		),
		"profile_contact_direction_2d": body.get(
			"profile_contact_direction_2d"
		),
		"profile_contact_distance_meters": float(body.get(
			"profile_contact_distance_meters"
		)),
		"profile_runtime_schema_version": int(body.get(
			"profile_runtime_schema_version"
		)),
		"profile_rotation_bias_degrees": float(body.get(
			"profile_rotation_bias_degrees"
		)),
		"profile_twist_degrees_per_meter": float(body.get("profile_twist_degrees_per_meter")),
		"handle_profile_authoring_snapshot": (
			body.get("handle_profile_authoring_snapshot") as Dictionary
		).duplicate(true),
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

func _build_bounded_history_export_snapshot() -> Dictionary:
	var checkpoint_packet := _get_bounded_history_checkpoint_token()
	return {
		"configured_enabled": bounded_history_enabled,
		"active": _is_bounded_history_active(),
		"suspended_reason": bounded_history_suspended_reason,
		"recovery_blocked_reason": bounded_history_recovery_blocked_reason,
		"tail_capacity": BOUNDED_HISTORY_TAIL_CAPACITY,
		"lifetime_operation_count": bounded_history_lifetime_operation_count,
		"checkpoint_operation_count": get_bounded_history_checkpoint_operation_count(),
		"checkpoint_materialized_operation_count": int(checkpoint_packet.get(
			"materialized_mesh_operation_count",
			0
		)),
		"checkpoint_mesh_dirty": bool(checkpoint_packet.get(
			"checkpoint_mesh_dirty",
			false
		)),
		"checkpoint_vertex_count": int(checkpoint_packet.get(
			"checkpoint_vertex_count",
			0
		)),
		"checkpoint_triangle_count": int(checkpoint_packet.get(
			"checkpoint_triangle_count",
			0
		)),
		"checkpoint_cell_count": (
			(checkpoint_packet.get(
				"checkpoint_cell_materials",
				{}
			) as Dictionary).size()
		),
		"active_tail_layer_ids": _layer_ids(forge_layers),
		"redo_tail_layer_ids": _layer_ids(undone_forge_layers),
		"protected_layer_ids": _layer_ids(protected_forge_layers),
	}

func _is_material_body_active(body: Resource) -> bool:
	if body == null:
		return false
	var layer_active_value: Variant = body.get("layer_active")
	return not (layer_active_value is bool) or bool(layer_active_value)

func _is_handle_body_path_configuration_valid(body: Resource) -> bool:
	if body == null:
		return false
	var shape_kind := StringName(body.get("shape_kind"))
	var path_points: PackedVector3Array = body.get("path_points")
	return (
		(
			shape_kind
			== ForgeV2MaterialBodyScript.SHAPE_KIND_SPLINE_PROFILE_PATH
			and path_points.size() == HANDLE_THREE_POINT_COUNT
		)
		or (
			shape_kind == ForgeV2MaterialBodyScript.SHAPE_KIND_PROFILE_PATH
			and path_points.size() in [
				HANDLE_TWO_POINT_COUNT,
				HANDLE_THREE_POINT_COUNT,
			]
		)
	)

func _is_material_body_commit_ready(body: Resource) -> bool:
	if body == null:
		return false
	var path_points: PackedVector3Array = body.get("path_points")
	if (
		StringName(body.get("body_kind"))
		== ForgeV2MaterialBodyScript.BODY_KIND_HANDLE_PROFILE
		and (
			not _is_handle_body_path_configuration_valid(body)
			or not _handle_endpoint_span_meets_minimum(path_points)
		)
	):
		return false
	var shape_kind := StringName(body.get("shape_kind"))
	if (
		shape_kind != ForgeV2MaterialBodyScript.SHAPE_KIND_PROFILE_PATH
		and shape_kind
		!= ForgeV2MaterialBodyScript.SHAPE_KIND_SPLINE_PROFILE_PATH
	):
		return true
	if path_points.size() < 2:
		return false
	if (
		body.has_method("uses_explicit_surface_contact_authority")
		and bool(body.call("uses_explicit_surface_contact_authority"))
	):
		var path_contact_directions: PackedVector3Array = body.get(
			"path_contact_directions"
		)
		if path_contact_directions.size() != path_points.size():
			return false
	var path_length := 0.0
	for point_index in range(path_points.size() - 1):
		path_length += path_points[point_index].distance_to(
			path_points[point_index + 1]
		)
	return path_length > 0.000001

func _is_material_body_committed(body: Resource) -> bool:
	return body != null and StringName(body.get("committed_layer_id")) != StringName()

func _is_pending_user_material_body(body: Resource) -> bool:
	return (
		body != null
		and not _is_material_body_committed(body)
		and _is_material_body_active(body)
		and not (
			body.has_method("is_platform_seed")
			and bool(body.call("is_platform_seed"))
		)
	)

func _is_user_handle_material_body(body: Resource) -> bool:
	return (
		body != null
		and StringName(body.get("body_kind"))
		== ForgeV2MaterialBodyScript.BODY_KIND_HANDLE_PROFILE
		and not (
			body.has_method("is_platform_seed")
			and bool(body.call("is_platform_seed"))
		)
	)

func _collect_live_handle_material_bodies() -> Array[Resource]:
	var handles: Array[Resource] = []
	for body: Resource in material_bodies:
		if (
			_is_user_handle_material_body(body)
			and _is_material_body_active(body)
		):
			handles.append(body)
	return handles

func _resolve_handle_profile_snapshot_name() -> String:
	var resolved_name := active_profile_display_name.strip_edges()
	if resolved_name.is_empty():
		resolved_name = "Handle Profile"
	return resolved_name

func _build_handle_profile_authoring_snapshot(
	preserved_compiled_geometry: bool
) -> Dictionary:
	var snapshot := build_active_tool_profile_preset_data(
		_resolve_handle_profile_snapshot_name()
	)
	snapshot["authoring_snapshot_schema_id"] = &"forge_v2_handle_profile_authoring_v1"
	snapshot["source_profile_id"] = active_handle_source_profile_id
	if active_handle_source_profile_id != StringName():
		snapshot["profile_id"] = active_handle_source_profile_id
		snapshot["id"] = active_handle_source_profile_id
	snapshot["profile_id_source"] = active_profile_id
	snapshot["compiled_geometry_preserved"] = preserved_compiled_geometry
	return snapshot.duplicate(true)

func _build_active_handle_profile_signature() -> String:
	return var_to_str({
		"profile_id_source": active_profile_id,
		"source_profile_id": active_handle_source_profile_id,
		"display_name": active_profile_display_name,
		"width_meters": active_profile_width_meters,
		"height_meters": active_profile_height_meters,
		"anchor_x_meters": active_profile_anchor_x_meters,
		"anchor_y_meters": active_profile_anchor_y_meters,
		"rotation_degrees": active_profile_rotation_degrees,
		"face_count": active_handle_face_count,
		"rounded_enabled": active_handle_rounding_enabled,
		"corner_radius_meters": active_handle_corner_radius_meters,
		"control_points_2d_meters": active_handle_control_points_2d_meters,
		"grid_snapping_enabled": active_handle_grid_snapping_enabled,
	})

func _seed_handle_editor_from_body(body: Resource) -> void:
	_assign_active_tool_id(TOOL_HANDLES)
	active_handle_path_mode_id = _resolve_handle_path_mode_id_from_body(body)
	active_material_variant_id = StringName(body.get("material_variant_id"))
	var snapshot := (
		body.get("handle_profile_authoring_snapshot") as Dictionary
	).duplicate(true)
	var snapshot_family := StringName(snapshot.get(
		"family",
		StringName()
	))
	var snapshot_points: PackedVector2Array = snapshot.get(
		"control_points_2d_meters",
		PackedVector2Array()
	) as PackedVector2Array
	var has_editable_snapshot := (
		not snapshot.is_empty()
		and snapshot_family
		== ForgeV2ProfileShapeLibraryScript.PROFILE_FAMILY_HANDLE
		and snapshot_points.size() in [
			ForgeV2ProfileShapeLibraryScript.HANDLE_FACE_COUNT_RECTANGLE,
			ForgeV2ProfileShapeLibraryScript.HANDLE_FACE_COUNT_OCTAGON,
		]
	)
	if has_editable_snapshot:
		apply_tool_profile_preset(snapshot)
		active_handle_source_profile_id = StringName(snapshot.get(
			"source_profile_id",
			snapshot.get("profile_id", StringName())
		))
	else:
		active_profile_id = ForgeV2ProfileShapeLibraryScript.PROFILE_HANDLE_BUILDER
		active_profile_display_name = String(body.get("profile_display_name"))
		active_handle_source_profile_id = StringName(body.get("profile_id"))
		if (
			active_handle_source_profile_id
			== ForgeV2ProfileShapeLibraryScript.PROFILE_HANDLE_BUILDER
		):
			active_handle_source_profile_id = StringName()
		var legacy_polygon: PackedVector2Array = body.get(
			"profile_polygon_2d_meters"
		) as PackedVector2Array
		var legacy_bounds := (
			ForgeV2ProfileShapeLibraryScript.calculate_polygon_bounds(
				legacy_polygon
			)
		)
		active_profile_width_meters = maxf(
			legacy_bounds.size.x,
			ForgeV2ProfileShapeLibraryScript.HANDLE_DEFAULT_WIDTH_METERS
		)
		active_profile_height_meters = maxf(
			legacy_bounds.size.y,
			ForgeV2ProfileShapeLibraryScript.HANDLE_DEFAULT_HEIGHT_METERS
		)
		active_profile_anchor_x_meters = 0.0
		active_profile_anchor_y_meters = 0.0
		active_profile_rotation_degrees = 0.0
		active_handle_face_count = (
			ForgeV2ProfileShapeLibraryScript.HANDLE_FACE_COUNT_OCTAGON
			if legacy_polygon.size()
			== ForgeV2ProfileShapeLibraryScript.HANDLE_FACE_COUNT_OCTAGON
			else ForgeV2ProfileShapeLibraryScript.HANDLE_FACE_COUNT_RECTANGLE
		)
		active_handle_rounding_enabled = (
			legacy_polygon.size() > active_handle_face_count
		)
		active_handle_corner_radius_meters = (
			ForgeV2ProfileShapeLibraryScript.HANDLE_DEFAULT_CORNER_RADIUS_METERS
		)
		active_handle_control_points_2d_meters = (
			ForgeV2ProfileShapeLibraryScript.build_default_handle_control_points(
				active_handle_face_count,
				active_profile_width_meters,
				active_profile_height_meters
			)
		)
		_normalize_active_profile_settings()
	spline_line_points = (
		body.get("path_points") as PackedVector3Array
	).duplicate()
	spline_line_surface_normals = (
		body.get("path_surface_normals") as PackedVector3Array
	).duplicate()
	_normalize_spline_line()
	spline_line_finished = false
	selected_spline_point_index = -1
	spline_line_csg_noodle_enabled = false

func _clear_handle_change_transaction() -> void:
	_handle_change_original_body = null
	_handle_change_original_body_index = -1
	_handle_change_original_protected_layer = null
	_handle_change_original_protected_layer_index = -1
	_handle_change_initial_profile_signature = ""
	_handle_change_source_profile_id = StringName()

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
	var normalized_protected_layers: Array[Resource] = []
	for layer: Resource in protected_forge_layers:
		if layer == null:
			continue
		if layer.has_method("normalize"):
			layer.call("normalize")
		normalized_protected_layers.append(layer)
	protected_forge_layers = normalized_protected_layers

func _normalize_bounded_history(loaded_schema_version: int) -> void:
	_ensure_bounded_history_checkpoint()
	bounded_history_checkpoint.call("normalize")
	bounded_history_lifetime_operation_count = maxi(
		bounded_history_lifetime_operation_count,
		get_bounded_history_checkpoint_operation_count()
	)
	bounded_history_transition_revision = maxi(
		bounded_history_transition_revision,
		0
	)
	if bounded_history_suspended_reason == StringName():
		bounded_history_suspended_reason = BOUNDED_HISTORY_SUSPENDED_NONE
	# Schema-6 makes committed Handle layers protected/non-undoable and keeps
	# their bodies beside, never inside, the Add history tail.
	var retained_tail_layers: Array[Resource] = []
	for layer: Resource in forge_layers:
		if _is_protected_history_layer(layer):
			if not protected_forge_layers.has(layer):
				protected_forge_layers.append(layer)
			continue
		retained_tail_layers.append(layer)
	forge_layers = retained_tail_layers
	for layer_group: Array[Resource] in [
		forge_layers,
		undone_forge_layers,
		protected_forge_layers,
	]:
		for layer: Resource in layer_group:
			if layer == null:
				continue
			bounded_history_lifetime_operation_count = maxi(
				bounded_history_lifetime_operation_count,
				int(layer.get("order_index"))
			)
	_bounded_history_pending_promotion = {}
	if (
		loaded_schema_version < SCHEMA_VERSION
		and forge_layers.size() > BOUNDED_HISTORY_TAIL_CAPACITY
		and not _has_bounded_history_checkpoint()
	):
		_suspend_bounded_history(&"legacy_unbounded_history")
	elif (
		_is_bounded_history_active()
		and (
			forge_layers.size() + undone_forge_layers.size()
			> BOUNDED_HISTORY_TAIL_CAPACITY
		)
	):
		_suspend_bounded_history(&"invalid_tail_capacity")
	if not _bounded_history_normalized_once:
		_bounded_history_normalized_once = true
		_publish_bounded_history_transition(
			BOUNDED_HISTORY_TRANSITION_RESTORE,
			null,
			[]
		)

func _ensure_bounded_history_checkpoint() -> void:
	if (
		bounded_history_checkpoint == null
		or not bounded_history_checkpoint.has_method(
			"advance_logical_checkpoint_with_occupancy_delta"
		)
	):
		bounded_history_checkpoint = ForgeV2HistoryCheckpointScript.new()

func _has_bounded_history_checkpoint() -> bool:
	return (
		bounded_history_checkpoint != null
		and bounded_history_checkpoint.has_method("is_initialized")
		and bool(bounded_history_checkpoint.call("is_initialized"))
	)

func _is_bounded_history_active() -> bool:
	return (
		bounded_history_enabled
		and bounded_history_suspended_reason
		== BOUNDED_HISTORY_SUSPENDED_NONE
	)

func _suspend_bounded_history(reason: StringName) -> void:
	bounded_history_suspended_reason = (
		reason if reason != StringName() else &"unspecified"
	)

func _get_bounded_history_checkpoint_token() -> Dictionary:
	if not _has_bounded_history_checkpoint():
		return {}
	return bounded_history_checkpoint.call("to_native_packet") as Dictionary

func _get_bounded_history_checkpoint_identity() -> Dictionary:
	_ensure_bounded_history_checkpoint()
	if bounded_history_checkpoint.has_method("get_identity_descriptor"):
		return bounded_history_checkpoint.call(
			"get_identity_descriptor"
		) as Dictionary
	return {
		"checkpoint_id": StringName(),
		"checkpoint_revision": 0,
		"checkpoint_materialization_revision": 0,
		"checkpoint_operation_count": 0,
		"materialized_mesh_operation_count": 0,
		"checkpoint_mesh_dirty": false,
	}

func _ensure_bounded_resolver_cache(
	committed_bodies: Array[Resource]
) -> void:
	if not _has_bounded_history_checkpoint():
		return
	var resolver := _ensure_committed_volume_resolver()
	var diagnostics := resolver.call(
		"get_incremental_committed_cache_diagnostics"
	) as Dictionary
	if bool(diagnostics.get("cache_valid", false)):
		return
	var restore_result := resolver.call(
		"restore_incremental_committed_cache_from_checkpoint",
		_get_bounded_history_checkpoint_token(),
		committed_bodies
	) as Dictionary
	committed_volume_cache_diagnostics = restore_result.get(
		"diagnostics",
		{}
	) as Dictionary

func _is_protected_commit_group(bodies: Array[Resource]) -> bool:
	if bodies.is_empty():
		return false
	for body: Resource in bodies:
		if not _is_history_protected_body(body):
			return false
	return true

func _is_history_protected_body(body: Resource) -> bool:
	if body == null:
		return false
	if ForgeV2MaterialCompositionPolicyScript.is_protected_handle_entry(body):
		return true
	return (
		body.has_method("is_platform_seed")
		and bool(body.call("is_platform_seed"))
	)

func _is_protected_history_layer(layer: Resource) -> bool:
	if layer == null:
		return false
	var records: Array = layer.get("input_shape_records") as Array
	if records.is_empty():
		return false
	for record_variant: Variant in records:
		if not record_variant is Dictionary:
			return false
		if StringName((record_variant as Dictionary).get(
			"body_kind",
			StringName()
		)) != ForgeV2MaterialBodyScript.BODY_KIND_HANDLE_PROFILE:
			return false
	return true

func _resolve_current_protected_handle_slot() -> Dictionary:
	if is_handle_change_active():
		return {
			"ok": false,
			"reason": &"handle_change_transaction_active",
		}
	var live_handles := _collect_live_handle_material_bodies()
	if live_handles.size() > 1:
		return {
			"ok": false,
			"reason": &"multiple_live_handles",
		}
	var handle_layers: Array[Resource] = []
	for layer: Resource in protected_forge_layers:
		if _is_protected_history_layer(layer):
			handle_layers.append(layer)
	if handle_layers.size() > 1:
		return {
			"ok": false,
			"reason": &"multiple_protected_handle_layers",
		}
	var committed_handles: Array[Resource] = []
	for body: Resource in live_handles:
		if _is_material_body_committed(body):
			committed_handles.append(body)
	if handle_layers.is_empty() and committed_handles.is_empty():
		return {
			"ok": true,
			"reason": &"empty",
			"empty": true,
			"body": null,
			"layer": null,
			"body_index": -1,
			"layer_index": -1,
		}
	if handle_layers.size() != 1 or committed_handles.size() != 1:
		return {
			"ok": false,
			"reason": &"protected_handle_body_layer_mismatch",
		}
	var body := committed_handles[0]
	var layer := handle_layers[0]
	var body_id := StringName(body.get("body_id"))
	var layer_id := StringName(layer.get("layer_id"))
	var layer_body_ids := layer.get("body_ids") as Array
	if (
		body_id == StringName()
		or layer_id == StringName()
		or layer_body_ids.size() != 1
		or StringName(layer_body_ids[0]) != body_id
		or StringName(body.get("committed_layer_id")) != layer_id
		or not _is_material_body_active(body)
	):
		return {
			"ok": false,
			"reason": &"protected_handle_link_invalid",
		}
	return {
		"ok": true,
		"reason": &"resolved",
		"empty": false,
		"body": body,
		"layer": layer,
		"body_index": material_bodies.find(body),
		"layer_index": protected_forge_layers.find(layer),
	}

func _must_reject_unsupported_bounded_commit(
	commit_ready_bodies: Array[Resource]
) -> bool:
	# Once bounded history has deliberately fallen back, legacy-compatible
	# bodies must continue to commit through that fallback.  Reapplying the
	# bounded eligibility gate here left every later primitive body pending.
	if not _is_bounded_history_active():
		return false
	if (
		(
			not _has_bounded_history_checkpoint()
			and forge_layers.is_empty()
		)
		or _is_protected_commit_group(commit_ready_bodies)
	):
		return false
	if commit_ready_bodies.size() != 1:
		return true
	return not _is_body_bounded_add_history_eligible(
		commit_ready_bodies[0],
		_get_bounded_history_material_id()
	)


func _will_stage_bounded_history_promotion(
	commit_ready_bodies: Array[Resource]
) -> bool:
	return (
		_is_bounded_history_active()
		and forge_layers.size() >= BOUNDED_HISTORY_TAIL_CAPACITY
		and commit_ready_bodies.size() == 1
		and not _is_history_protected_body(commit_ready_bodies[0])
		and _is_body_bounded_add_history_eligible(
			commit_ready_bodies[0],
			_get_bounded_history_material_id()
		)
	)


func _is_body_bounded_add_history_eligible(
	body: Resource,
	expected_material_variant_id: StringName
) -> bool:
	if body == null:
		return false
	var material_variant_id := StringName(body.get("material_variant_id"))
	var body_kind := StringName(body.get("body_kind"))
	var path_points: PackedVector3Array = body.get("path_points")
	var path_normals: PackedVector3Array = body.get("path_surface_normals")
	var path_contacts: PackedVector3Array = body.get("path_contact_directions")
	var shape_kind := StringName(body.get("shape_kind"))
	if shape_kind in [
		ForgeV2MaterialBodyScript.SHAPE_KIND_CAPSULE_PATH,
		ForgeV2MaterialBodyScript.SHAPE_KIND_SPLINE_CAPSULE_PATH,
	]:
		var minimum_path_point_count := (
			2
			if shape_kind
			== ForgeV2MaterialBodyScript.SHAPE_KIND_SPLINE_CAPSULE_PATH
			else 1
		)
		var radius_meters := float(body.get("radius_meters"))
		if (
			material_variant_id == StringName()
			or (
				expected_material_variant_id != StringName()
				and material_variant_id != expected_material_variant_id
			)
			or StringName(body.get("operation_mode"))
			!= ForgeV2VolumeStrokeScript.OPERATION_ADD_MATERIAL
			or StringName(body.get("placement_policy"))
			!= ForgeV2VolumeStrokeScript.PLACEMENT_REPLACE_EXISTING
			or body_kind not in [
				ForgeV2MaterialBodyScript.BODY_KIND_VOLUME_STROKE,
				ForgeV2MaterialBodyScript.BODY_KIND_DETAILING_BRUSH,
			]
			or int(body.get("profile_runtime_schema_version")) != 0
			or path_points.size() < minimum_path_point_count
			or path_normals.size() != path_points.size()
			or not path_contacts.is_empty()
			or not is_finite(radius_meters)
			or radius_meters <= 0.0
		):
			return false
		for path_point: Vector3 in path_points:
			if not path_point.is_finite():
				return false
		for path_normal: Vector3 in path_normals:
			if (
				not is_finite(path_normal.x)
				or not is_finite(path_normal.y)
				or not is_finite(path_normal.z)
				or path_normal.length_squared() <= 0.000001
			):
				return false
		return true
	return (
		material_variant_id != StringName()
		and (
			expected_material_variant_id == StringName()
			or material_variant_id == expected_material_variant_id
		)
		and StringName(body.get("operation_mode"))
		== ForgeV2VolumeStrokeScript.OPERATION_ADD_MATERIAL
		and StringName(body.get("placement_policy"))
		== ForgeV2VolumeStrokeScript.PLACEMENT_REPLACE_EXISTING
		and body_kind in [
			ForgeV2MaterialBodyScript.BODY_KIND_VOLUME_STROKE,
			ForgeV2MaterialBodyScript.BODY_KIND_DETAILING_BRUSH,
		]
		and StringName(body.get("shape_kind"))
		== ForgeV2MaterialBodyScript.SHAPE_KIND_PROFILE_PATH
		and int(body.get("profile_runtime_schema_version")) > 0
		and path_points.size() >= 2
		and path_normals.size() == path_points.size()
		and path_contacts.size() == path_points.size()
	)


func _build_bounded_promotion_rollback_snapshot(
	commit_ready_bodies: Array[Resource]
) -> Dictionary:
	var body_states: Array[Dictionary] = []
	for body: Resource in commit_ready_bodies:
		if body == null:
			continue
		body_states.append({
			"body": body,
			"committed_layer_id": StringName(body.get("committed_layer_id")),
			"layer_active": bool(body.get("layer_active")),
		})
	return {
		"forge_layers": forge_layers.duplicate(),
		"undone_forge_layers": undone_forge_layers.duplicate(),
		"material_bodies": material_bodies.duplicate(),
		"volume_strokes": volume_strokes.duplicate(),
		"material_ledger": material_ledger,
		"material_usage_summary_cache": material_usage_summary_cache,
		"material_usage_summary_cache_dirty": material_usage_summary_cache_dirty,
		"committed_volume_cache_diagnostics": (
			committed_volume_cache_diagnostics.duplicate(true)
		),
		"bounded_history_lifetime_operation_count": (
			bounded_history_lifetime_operation_count
		),
		"selected_material_body_id": selected_material_body_id,
		"updated_timestamp": updated_timestamp,
		"body_states": body_states,
	}


func _abort_bounded_promotion_cache_candidate(
	resolver: RefCounted,
	rollback_snapshot: Dictionary
) -> void:
	if (
		resolver != null
		and resolver.has_method(
			"abort_incremental_committed_cache_candidate"
		)
	):
		resolver.call("abort_incremental_committed_cache_candidate")
	committed_volume_cache_diagnostics = rollback_snapshot.get(
		"committed_volume_cache_diagnostics",
		{}
	) as Dictionary


func _restore_bounded_promotion_rollback_snapshot(
	rollback_snapshot: Dictionary
) -> void:
	forge_layers = rollback_snapshot.get("forge_layers", []) as Array[Resource]
	undone_forge_layers = rollback_snapshot.get(
		"undone_forge_layers",
		[]
	) as Array[Resource]
	material_bodies = rollback_snapshot.get(
		"material_bodies",
		[]
	) as Array[Resource]
	volume_strokes = rollback_snapshot.get(
		"volume_strokes",
		[]
	) as Array[Resource]
	material_ledger = rollback_snapshot.get("material_ledger", null) as Resource
	material_usage_summary_cache = rollback_snapshot.get(
		"material_usage_summary_cache",
		{}
	) as Dictionary
	material_usage_summary_cache_dirty = bool(rollback_snapshot.get(
		"material_usage_summary_cache_dirty",
		true
	))
	committed_volume_cache_diagnostics = rollback_snapshot.get(
		"committed_volume_cache_diagnostics",
		{}
	) as Dictionary
	bounded_history_lifetime_operation_count = int(rollback_snapshot.get(
		"bounded_history_lifetime_operation_count",
		bounded_history_lifetime_operation_count
	))
	selected_material_body_id = StringName(rollback_snapshot.get(
		"selected_material_body_id",
		StringName()
	))
	updated_timestamp = float(rollback_snapshot.get(
		"updated_timestamp",
		updated_timestamp
	))
	var body_states: Array = rollback_snapshot.get("body_states", []) as Array
	for state_variant: Variant in body_states:
		if not state_variant is Dictionary:
			continue
		var body_state := state_variant as Dictionary
		var body := body_state.get("body", null) as Resource
		if body == null:
			continue
		body.set(
			"committed_layer_id",
			StringName(body_state.get("committed_layer_id", StringName()))
		)
		body.set("layer_active", bool(body_state.get("layer_active", true)))
	_normalize_selected_material_body_id()


func _can_commit_layer_to_bounded_add_history(
	layer: Resource,
	commit_ready_bodies: Array[Resource]
) -> bool:
	if (
		not _is_bounded_history_active()
		or layer == null
		or commit_ready_bodies.size() != 1
		or _is_history_protected_body(commit_ready_bodies[0])
	):
		return false
	var expected_material_variant_id := _get_bounded_history_material_id()
	if expected_material_variant_id == StringName():
		expected_material_variant_id = StringName(
			commit_ready_bodies[0].get("material_variant_id")
		)
	if (
		not layer.has_method("is_bounded_add_history_eligible")
		or not bool(layer.call(
			"is_bounded_add_history_eligible",
			expected_material_variant_id
		))
	):
		return false
	for active_layer: Resource in forge_layers:
		if (
			active_layer == null
			or not active_layer.has_method(
				"is_bounded_add_history_eligible"
			)
			or not bool(active_layer.call(
				"is_bounded_add_history_eligible",
				expected_material_variant_id
			))
		):
			return false
	return true

func _get_bounded_history_material_id() -> StringName:
	if _has_bounded_history_checkpoint():
		return StringName(bounded_history_checkpoint.get("material_variant_id"))
	for layer: Resource in forge_layers:
		if layer == null:
			continue
		var material_id := StringName(layer.get("operation_material_id"))
		if material_id != StringName():
			return material_id
	return StringName()

func _discard_abandoned_redo_layers() -> void:
	if undone_forge_layers.is_empty():
		return
	var abandoned_body_ids: Dictionary = {}
	var abandoned_source_ids: Array[StringName] = []
	for layer: Resource in undone_forge_layers:
		if layer == null:
			continue
		for body_id_variant: Variant in layer.get("body_ids") as Array:
			abandoned_body_ids[StringName(body_id_variant)] = true
		for source_id_variant: Variant in layer.get("source_record_ids") as Array:
			var source_id := StringName(source_id_variant)
			if source_id != StringName():
				abandoned_source_ids.append(source_id)
	var retained_bodies: Array[Resource] = []
	for body: Resource in material_bodies:
		if body == null:
			continue
		if abandoned_body_ids.has(StringName(body.get("body_id"))):
			continue
		retained_bodies.append(body)
	material_bodies = retained_bodies
	_remove_volume_strokes_by_id(abandoned_source_ids)
	undone_forge_layers.clear()
	_normalize_selected_material_body_id()

func _stage_bounded_history_promotion(
	appended_layer: Resource,
	appended_bodies: Array[Resource],
	rollback_snapshot: Dictionary
) -> void:
	var pre_rebase_bodies := _collect_committed_active_user_material_bodies()
	var pre_rebase_body_tokens := _ensure_committed_volume_resolver().call(
		"build_committed_body_cache_tokens",
		pre_rebase_bodies
	) as Array
	var previous_checkpoint_token := _get_bounded_history_checkpoint_token()
	var promoted_layer := forge_layers.pop_front() as Resource
	var promoted_bodies := _get_layer_material_bodies(promoted_layer)
	_remove_material_bodies_for_layer(promoted_layer)
	var expected_checkpoint_operation_count := (
		get_bounded_history_checkpoint_operation_count() + 1
	)
	_publish_bounded_history_transition(
		BOUNDED_HISTORY_TRANSITION_PROMOTION_APPEND,
		appended_layer,
		appended_bodies,
		{
			"requires_native_ack": true,
			"pending_native_ack": true,
			"promoted_layer": promoted_layer,
			"promoted_layer_id": StringName(promoted_layer.get("layer_id")),
			"promoted_bodies": promoted_bodies,
			"promoted_body_ids": _body_ids(promoted_bodies),
			"expected_checkpoint_operation_count": (
				expected_checkpoint_operation_count
			),
		}
	)
	_bounded_history_pending_promotion = {
		"revision": bounded_history_transition_revision,
		"expected_checkpoint_operation_count": (
			expected_checkpoint_operation_count
		),
		"promoted_layer": promoted_layer,
		"promoted_bodies": promoted_bodies,
		"pre_rebase_body_tokens": pre_rebase_body_tokens,
		"previous_checkpoint_token": previous_checkpoint_token,
		"rollback_snapshot": rollback_snapshot,
	}

func _remove_material_bodies_for_layer(layer: Resource) -> void:
	if layer == null:
		return
	var layer_body_ids: Array = layer.get("body_ids") as Array
	var retained_bodies: Array[Resource] = []
	for body: Resource in material_bodies:
		if body == null:
			continue
		if layer_body_ids.has(StringName(body.get("body_id"))):
			continue
		retained_bodies.append(body)
	material_bodies = retained_bodies
	_normalize_selected_material_body_id()

func _publish_bounded_history_transition(
	kind: StringName,
	appended_layer: Resource,
	appended_bodies: Array,
	extra_fields: Dictionary = {}
) -> void:
	bounded_history_transition_revision += 1
	var descriptor := get_bounded_presentation_descriptor()
	descriptor["kind"] = kind
	descriptor["revision"] = bounded_history_transition_revision
	descriptor["requires_native_ack"] = false
	descriptor["pending_native_ack"] = false
	descriptor["appended_layer"] = appended_layer
	descriptor["appended_layer_id"] = (
		StringName(appended_layer.get("layer_id"))
		if appended_layer != null
		else StringName()
	)
	descriptor["appended_bodies"] = appended_bodies
	descriptor["appended_body_ids"] = _body_ids(appended_bodies)
	descriptor["appended_body"] = (
		appended_bodies[0]
		if appended_bodies.size() == 1
		else null
	)
	descriptor["appended_body_id"] = (
		StringName((appended_bodies[0] as Resource).get("body_id"))
		if appended_bodies.size() == 1
		and appended_bodies[0] is Resource
		else StringName()
	)
	for field_key: Variant in extra_fields.keys():
		descriptor[field_key] = extra_fields[field_key]
	_bounded_history_transition = descriptor

func _nonnull_layers(source_layers: Array) -> Array[Resource]:
	var result: Array[Resource] = []
	for layer_variant: Variant in source_layers:
		if layer_variant is Resource and layer_variant != null:
			result.append(layer_variant as Resource)
	return result

func _layer_ids(layers: Array) -> Array[StringName]:
	var result: Array[StringName] = []
	for layer_variant: Variant in layers:
		if layer_variant is Resource and layer_variant != null:
			result.append(StringName((layer_variant as Resource).get("layer_id")))
	return result

func _body_ids(bodies: Array) -> Array[StringName]:
	var result: Array[StringName] = []
	for body_variant: Variant in bodies:
		if body_variant is Resource and body_variant != null:
			result.append(StringName((body_variant as Resource).get("body_id")))
	return result

func _collect_layer_bodies(layers: Array) -> Array[Resource]:
	var result: Array[Resource] = []
	for layer_variant: Variant in layers:
		if not layer_variant is Resource or layer_variant == null:
			continue
		result.append_array(_get_layer_material_bodies(layer_variant as Resource))
	return result

func _get_layer_material_bodies(layer: Resource) -> Array[Resource]:
	var result: Array[Resource] = []
	if layer == null:
		return result
	var layer_body_ids: Array = layer.get("body_ids") as Array
	for body: Resource in material_bodies:
		if body == null:
			continue
		if layer_body_ids.has(StringName(body.get("body_id"))):
			result.append(body)
	return result

func _collect_protected_material_bodies() -> Array[Resource]:
	var result: Array[Resource] = []
	for body: Resource in material_bodies:
		if body != null and _is_history_protected_body(body):
			result.append(body)
	return result

func _ensure_material_ledger() -> void:
	if material_ledger == null or not material_ledger.has_method("rebuild_from_layers"):
		material_ledger = ForgeV2MaterialLedgerScript.new()

func _ensure_committed_volume_resolver() -> RefCounted:
	if (
		committed_volume_resolver == null
		or not committed_volume_resolver.has_method(
			"build_incremental_committed_usage_summary"
		)
	):
		committed_volume_resolver = ForgeV2MaterialVolumeResolverScript.new()
	return committed_volume_resolver

func _reset_committed_volume_cache(reason: StringName) -> void:
	var resolver := _ensure_committed_volume_resolver()
	resolver.call("reset_incremental_committed_cache", reason)
	committed_volume_cache_diagnostics = resolver.call(
		"get_incremental_committed_cache_diagnostics"
	) as Dictionary

func _mark_material_usage_summary_dirty() -> void:
	material_usage_summary_cache_dirty = true
	material_usage_summary_cache = {}

func _can_reuse_committed_usage_summary(
	resolved_usage_summary: Dictionary,
	existing_material_bodies: Array[Resource],
	committed_material_bodies: Array[Resource]
) -> bool:
	if resolved_usage_summary.is_empty():
		return false
	var resolved_body_ids: Dictionary = {}
	for body_group: Array[Resource] in [
		existing_material_bodies,
		committed_material_bodies,
	]:
		for body: Resource in body_group:
			if body == null:
				continue
			var body_id := StringName(body.get("body_id"))
			if body_id == StringName():
				return false
			resolved_body_ids[body_id] = true
	var active_body_ids: Dictionary = {}
	for body: Resource in material_bodies:
		if body == null or not _is_material_body_active(body):
			continue
		if body.has_method("is_platform_seed") and bool(body.call("is_platform_seed")):
			continue
		var body_id := StringName(body.get("body_id"))
		if body_id == StringName():
			return false
		active_body_ids[body_id] = true
	if active_body_ids.size() != resolved_body_ids.size():
		return false
	for body_id: StringName in resolved_body_ids.keys():
		if not active_body_ids.has(body_id):
			return false
	return true

func _rebuild_material_ledger() -> void:
	_reset_committed_volume_cache(&"material_ledger_rebuilt")
	_ensure_material_ledger()
	if material_ledger == null:
		return
	if _has_bounded_history_checkpoint():
		material_ledger.call(
			"rebuild_from_checkpoint_and_layers",
			bounded_history_checkpoint.call("get_material_ledger_summary"),
			protected_forge_layers,
			forge_layers
		)
		var resolver := _ensure_committed_volume_resolver()
		if resolver.has_method(
			"restore_incremental_committed_cache_from_checkpoint"
		):
			var restore_result := resolver.call(
				"restore_incremental_committed_cache_from_checkpoint",
				_get_bounded_history_checkpoint_token(),
				_collect_committed_active_user_material_bodies()
			) as Dictionary
			committed_volume_cache_diagnostics = restore_result.get(
				"diagnostics",
				{}
			) as Dictionary
		return
	var all_layers: Array[Resource] = []
	all_layers.append_array(protected_forge_layers)
	all_layers.append_array(forge_layers)
	all_layers.sort_custom(func(first: Resource, second: Resource) -> bool:
		return int(first.get("order_index")) < int(second.get("order_index"))
	)
	material_ledger.call("rebuild_from_layers", all_layers)

func _bounded_ledger_retains_only_live_layer_ids(
	ledger_candidate: Resource
) -> bool:
	if (
		ledger_candidate == null
		or not ledger_candidate.has_method("get_retained_layer_ids")
	):
		return false
	var allowed_ids: Dictionary = {}
	for layer_id: StringName in _layer_ids(protected_forge_layers):
		allowed_ids[layer_id] = true
	for layer_id: StringName in _layer_ids(forge_layers):
		allowed_ids[layer_id] = true
	var retained_ids: Array = ledger_candidate.call(
		"get_retained_layer_ids"
	) as Array
	if retained_ids.size() > allowed_ids.size():
		return false
	for layer_id_variant: Variant in retained_ids:
		if not allowed_ids.has(StringName(layer_id_variant)):
			return false
	return true


func _material_ledger_summaries_match(
	first: Dictionary,
	second: Dictionary
) -> bool:
	if (
		int(first.get("total_rough_material_centi_units", 0))
		!= int(second.get("total_rough_material_centi_units", 0))
		or not is_equal_approx(
			float(first.get("total_rough_volume_cell_equivalents", 0.0)),
			float(second.get("total_rough_volume_cell_equivalents", 0.0))
		)
		or int(first.get("removed_material_record_count", 0))
		!= int(second.get("removed_material_record_count", 0))
	):
		return false
	var first_materials: Dictionary = first.get("materials", {}) as Dictionary
	var second_materials: Dictionary = second.get("materials", {}) as Dictionary
	if first_materials.size() != second_materials.size():
		return false
	for material_key: Variant in first_materials.keys():
		if not second_materials.has(material_key):
			return false
		var first_entry: Dictionary = first_materials[material_key] as Dictionary
		var second_entry: Dictionary = second_materials[material_key] as Dictionary
		if (
			int(first_entry.get("rough_material_centi_units", 0))
			!= int(second_entry.get("rough_material_centi_units", 0))
			or not is_equal_approx(
				float(first_entry.get(
					"rough_volume_cell_equivalents",
					0.0
				)),
				float(second_entry.get(
					"rough_volume_cell_equivalents",
					0.0
				))
			)
		):
			return false
	return true

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

func _normalize_profile_size_meters(value_meters: float) -> float:
	return clampf(value_meters, PROFILE_SIZE_MIN_METERS, PROFILE_SIZE_MAX_METERS)

func _normalize_profile_anchor_meters(value_meters: float) -> float:
	return clampf(value_meters, -PROFILE_SIZE_MAX_METERS, PROFILE_SIZE_MAX_METERS)

func _normalize_profile_rotation_degrees(value_degrees: float) -> float:
	return clampf(float(roundi(value_degrees)), PROFILE_ROTATION_MIN_DEGREES, PROFILE_ROTATION_MAX_DEGREES)

func _normalize_active_profile_settings() -> void:
	if _is_active_handle_builder_profile():
		_normalize_active_handle_builder_settings()
		return
	if _is_active_basic_builder_profile():
		_normalize_active_basic_builder_settings()
		return
	if active_profile_width_meters <= 0.0 or active_profile_height_meters <= 0.0:
		_reset_active_profile_dimensions_to_natural()
	active_profile_width_meters = _normalize_profile_size_meters(active_profile_width_meters)
	active_profile_height_meters = _normalize_profile_size_meters(active_profile_height_meters)
	active_profile_anchor_x_meters = _normalize_profile_anchor_meters(active_profile_anchor_x_meters)
	active_profile_anchor_y_meters = _normalize_profile_anchor_meters(active_profile_anchor_y_meters)
	active_profile_rotation_degrees = _normalize_profile_rotation_degrees(active_profile_rotation_degrees)

func _reset_active_profile_dimensions_to_natural() -> void:
	var natural_size := _resolve_profile_natural_size(active_profile_id)
	active_profile_width_meters = _normalize_profile_size_meters(natural_size.x)
	active_profile_height_meters = _normalize_profile_size_meters(natural_size.y)

func _resolve_profile_natural_size(profile_id: StringName) -> Vector2:
	if profile_id == ForgeV2ProfileShapeLibraryScript.PROFILE_HANDLE_BUILDER:
		return Vector2(
			ForgeV2ProfileShapeLibraryScript.HANDLE_DEFAULT_WIDTH_METERS,
			ForgeV2ProfileShapeLibraryScript.HANDLE_DEFAULT_HEIGHT_METERS
		)
	if profile_id == ForgeV2ProfileShapeLibraryScript.PROFILE_2D_BUILDER:
		return Vector2(
			ForgeV2ProfileShapeLibraryScript.BASIC_BUILDER_DEFAULT_WIDTH_METERS,
			ForgeV2ProfileShapeLibraryScript.BASIC_BUILDER_DEFAULT_HEIGHT_METERS
		)
	var polygon := _resolve_base_profile_polygon(profile_id)
	var natural_size: Vector2 = ForgeV2ProfileShapeLibraryScript.calculate_polygon_size_meters(polygon)
	if natural_size.x <= 0.0:
		natural_size.x = DEFAULT_POINT_PLACEMENT_RADIUS_METERS * 2.0
	if natural_size.y <= 0.0:
		natural_size.y = DEFAULT_POINT_PLACEMENT_RADIUS_METERS * 2.0
	return natural_size

func _resolve_base_profile_polygon(profile_id: StringName = StringName()) -> PackedVector2Array:
	var resolved_profile_id := active_profile_id if profile_id == StringName() else profile_id
	if resolved_profile_id == ForgeV2ProfileShapeLibraryScript.PROFILE_HANDLE_BUILDER and active_tool_id == TOOL_HANDLES:
		return _resolve_active_handle_builder_base_polygon()
	if resolved_profile_id == ForgeV2ProfileShapeLibraryScript.PROFILE_2D_BUILDER and active_tool_id != TOOL_HANDLES:
		return _resolve_active_basic_builder_base_polygon()
	var profile_record: Dictionary = ForgeV2ProfileShapeLibraryScript.get_profile_record(
		resolved_profile_id,
		active_brush_radius_meters
	)
	var profile_polygon: PackedVector2Array = profile_record.get("polygon", PackedVector2Array())
	if profile_polygon.size() >= 3:
		return profile_polygon
	return ForgeV2ProfileShapeLibraryScript.resolve_profile_polygon(resolved_profile_id, active_brush_radius_meters)

func _resolve_active_profile_polygon(profile_id: StringName = StringName()) -> PackedVector2Array:
	if _is_active_handle_builder_profile() and (profile_id == StringName() or profile_id == ForgeV2ProfileShapeLibraryScript.PROFILE_HANDLE_BUILDER):
		return _resolve_active_handle_builder_preview_polygon()
	if _is_active_basic_builder_profile() and (profile_id == StringName() or profile_id == ForgeV2ProfileShapeLibraryScript.PROFILE_2D_BUILDER):
		return _resolve_active_basic_builder_preview_polygon()
	var base_polygon := _resolve_base_profile_polygon(profile_id)
	if base_polygon.size() < 3:
		return base_polygon
	return ForgeV2ProfileShapeLibraryScript.transform_profile_polygon(
		base_polygon,
		Vector2(active_profile_width_meters, active_profile_height_meters),
		Vector2(active_profile_anchor_x_meters, active_profile_anchor_y_meters),
		active_profile_rotation_degrees
	)

func _is_valid_tool_id(tool_id: StringName) -> bool:
	return (
		tool_id == TOOL_VOLUME_STROKE
		or tool_id == TOOL_SPLINE_LINE
		or tool_id == TOOL_HANDLES
		or tool_id == TOOL_DETAILING_BRUSH
	)

func _assign_active_tool_id(next_tool_id: StringName) -> void:
	var resolved_tool_id := (
		next_tool_id
		if _is_valid_tool_id(next_tool_id)
		else TOOL_VOLUME_STROKE
	)
	if (
		active_tool_id != resolved_tool_id
		and is_handle_change_active()
		and resolved_tool_id != TOOL_HANDLES
	):
		cancel_handle_change()
	if (
		active_tool_id != resolved_tool_id
		and (
			active_tool_id == TOOL_DETAILING_BRUSH
			or resolved_tool_id == TOOL_DETAILING_BRUSH
		)
	):
		_clear_spline_transient_state()
	active_tool_id = resolved_tool_id

func _normalize_active_basic_shape_authority() -> void:
	if active_basic_shape_source_id != BASIC_SHAPE_SOURCE_SAVED_PROFILE:
		active_basic_shape_source_id = BASIC_SHAPE_SOURCE_PRIMITIVE
		active_saved_basic_profile_id = StringName()
		active_saved_basic_profile_data = {}
		return
	var compiled_profile := (
		ForgeV2ProfileShapeLibraryScript.compile_basic_profile_runtime_data(
			active_saved_basic_profile_data
		)
	)
	var profile_id := StringName(compiled_profile.get(
		"profile_id",
		compiled_profile.get("id", active_saved_basic_profile_id)
	))
	if (
		profile_id == StringName()
		or not ForgeV2ProfileShapeLibraryScript.is_compiled_basic_profile_runtime_valid(
			compiled_profile
		)
	):
		active_basic_shape_source_id = BASIC_SHAPE_SOURCE_PRIMITIVE
		active_saved_basic_profile_id = StringName()
		active_saved_basic_profile_data = {}
		return
	active_saved_basic_profile_id = profile_id
	active_saved_basic_profile_data = compiled_profile.duplicate(true)

func _get_active_saved_basic_profile_runtime_data() -> Dictionary:
	if not is_saved_basic_profile_shape_active():
		return {}
	return (
		active_saved_basic_profile_data.get("compiled_profile", {}) as Dictionary
	).duplicate(true)

func _get_active_profile_family() -> StringName:
	return (
		ForgeV2ProfileShapeLibraryScript.PROFILE_FAMILY_HANDLE
		if active_tool_id == TOOL_HANDLES
		else ForgeV2ProfileShapeLibraryScript.PROFILE_FAMILY_BASIC
	)

func _is_active_handle_builder_profile() -> bool:
	return active_tool_id == TOOL_HANDLES and active_profile_id == ForgeV2ProfileShapeLibraryScript.PROFILE_HANDLE_BUILDER

func _is_active_basic_builder_profile() -> bool:
	return active_tool_id != TOOL_HANDLES and active_profile_id == ForgeV2ProfileShapeLibraryScript.PROFILE_2D_BUILDER

func _is_active_profile_builder() -> bool:
	return _is_active_handle_builder_profile() or _is_active_basic_builder_profile()

func _normalize_active_basic_builder_settings() -> void:
	active_profile_id = ForgeV2ProfileShapeLibraryScript.PROFILE_2D_BUILDER
	active_profile_rotation_degrees = _normalize_profile_rotation_degrees(active_profile_rotation_degrees)
	if active_profile_width_meters <= 0.0:
		active_profile_width_meters = ForgeV2ProfileShapeLibraryScript.BASIC_BUILDER_DEFAULT_WIDTH_METERS
	if active_profile_height_meters <= 0.0:
		active_profile_height_meters = ForgeV2ProfileShapeLibraryScript.BASIC_BUILDER_DEFAULT_HEIGHT_METERS
	active_profile_width_meters = clampf(
		_normalize_profile_size_meters(active_profile_width_meters),
		PROFILE_SIZE_MIN_METERS,
		PROFILE_SIZE_MAX_METERS
	)
	active_profile_height_meters = clampf(
		_normalize_profile_size_meters(active_profile_height_meters),
		PROFILE_SIZE_MIN_METERS,
		PROFILE_SIZE_MAX_METERS
	)
	if active_basic_control_points_2d_meters.size() < 3:
		_reset_active_basic_control_points_for_size()
	else:
		_sync_active_profile_size_from_basic_control_points()
	_normalize_active_basic_corner_metadata()
	_constrain_active_basic_anchor(active_basic_grid_snapping_enabled)

func _normalize_active_handle_builder_settings() -> void:
	active_profile_id = ForgeV2ProfileShapeLibraryScript.PROFILE_HANDLE_BUILDER
	active_handle_face_count = ForgeV2ProfileShapeLibraryScript.normalize_handle_face_count(active_handle_face_count)
	active_profile_rotation_degrees = _normalize_profile_rotation_degrees(active_profile_rotation_degrees)
	if active_profile_width_meters <= 0.0:
		active_profile_width_meters = ForgeV2ProfileShapeLibraryScript.HANDLE_DEFAULT_WIDTH_METERS
	if active_profile_height_meters <= 0.0:
		active_profile_height_meters = ForgeV2ProfileShapeLibraryScript.HANDLE_DEFAULT_HEIGHT_METERS
	var handle_limit_size := ForgeV2ProfileShapeLibraryScript.get_handle_builder_limit_size_meters()
	active_profile_width_meters = clampf(
		_normalize_profile_size_meters(active_profile_width_meters),
		PROFILE_SIZE_MIN_METERS,
		maxf(handle_limit_size.x, PROFILE_SIZE_MIN_METERS)
	)
	active_profile_height_meters = clampf(
		_normalize_profile_size_meters(active_profile_height_meters),
		PROFILE_SIZE_MIN_METERS,
		maxf(handle_limit_size.y, PROFILE_SIZE_MIN_METERS)
	)
	if active_handle_control_points_2d_meters.size() != active_handle_face_count:
		_reset_active_handle_control_points_for_size()
	else:
		_sync_active_profile_size_from_handle_control_points()
	_constrain_active_handle_anchor()
	var max_corner_radius := ForgeV2ProfileShapeLibraryScript.calculate_max_corner_radius_meters(active_handle_control_points_2d_meters)
	active_handle_corner_radius_meters = clampf(active_handle_corner_radius_meters, 0.0, max_corner_radius)

func _normalize_active_basic_corner_metadata() -> void:
	active_basic_next_corner_serial = maxi(active_basic_next_corner_serial, 1)
	var normalized_metadata: Array[Dictionary] = []
	var used_corner_ids: Dictionary = {}
	for point_index in range(active_basic_control_points_2d_meters.size()):
		var metadata := {}
		if point_index < active_basic_corner_metadata.size():
			metadata = active_basic_corner_metadata[point_index].duplicate(true)
		var corner_id := StringName(metadata.get("corner_id", StringName()))
		if corner_id == StringName() or used_corner_ids.has(corner_id):
			corner_id = _build_next_basic_corner_id()
		metadata["corner_id"] = corner_id
		used_corner_ids[corner_id] = true
		if metadata.has("radius_meters"):
			var radius_meters := float(metadata.get("radius_meters", 0.0))
			if (
				not is_finite(radius_meters)
				or radius_meters
				< ForgeV2ProfileShapeLibraryScript.BASIC_FILLET_RADIUS_MIN_METERS
			):
				metadata.erase("radius_meters")
			else:
				metadata["radius_meters"] = minf(
					radius_meters,
					ForgeV2ProfileShapeLibraryScript.BASIC_FILLET_RADIUS_INPUT_MAX_METERS
				)
		normalized_metadata.append(metadata)
	active_basic_corner_metadata = normalized_metadata

func _duplicate_basic_corner_metadata() -> Array[Dictionary]:
	var duplicated_metadata: Array[Dictionary] = []
	for metadata: Dictionary in active_basic_corner_metadata:
		duplicated_metadata.append(metadata.duplicate(true))
	return duplicated_metadata

func _build_next_basic_corner_id() -> StringName:
	while true:
		var corner_id := StringName(
			"basic_corner_%06d" % active_basic_next_corner_serial
		)
		active_basic_next_corner_serial += 1
		if _find_active_basic_corner_index(corner_id) < 0:
			return corner_id
	return StringName()

func _find_active_basic_corner_index(corner_id: StringName) -> int:
	if corner_id == StringName():
		return -1
	for point_index in range(active_basic_corner_metadata.size()):
		var metadata: Dictionary = active_basic_corner_metadata[point_index]
		if StringName(metadata.get("corner_id", StringName())) == corner_id:
			return point_index
	return -1

func _closest_point_on_segment_2d(
	point: Vector2,
	segment_start: Vector2,
	segment_end: Vector2
) -> Vector2:
	var segment := segment_end - segment_start
	var segment_length_squared := segment.length_squared()
	if segment_length_squared <= 0.000000000001:
		return segment_start
	var segment_weight := clampf(
		(point - segment_start).dot(segment) / segment_length_squared,
		0.0,
		1.0
	)
	return segment_start + segment * segment_weight

func _reset_active_basic_control_points_for_size() -> void:
	active_basic_control_points_2d_meters = ForgeV2ProfileShapeLibraryScript.build_default_basic_control_points(
		active_profile_width_meters,
		active_profile_height_meters
	)
	active_basic_corner_metadata = []
	_sync_active_profile_size_from_basic_control_points()
	_normalize_active_basic_corner_metadata()

func _reset_active_handle_control_points_for_size() -> void:
	active_handle_control_points_2d_meters = ForgeV2ProfileShapeLibraryScript.build_default_handle_control_points(
		active_handle_face_count,
		active_profile_width_meters,
		active_profile_height_meters
	)
	_sync_active_profile_size_from_handle_control_points()

func _scale_active_basic_control_points_to_profile_size() -> void:
	if active_basic_control_points_2d_meters.size() < 3:
		_reset_active_basic_control_points_for_size()
		return
	active_basic_control_points_2d_meters = ForgeV2ProfileShapeLibraryScript.scale_control_points_to_size(
		active_basic_control_points_2d_meters,
		Vector2(active_profile_width_meters, active_profile_height_meters)
	)
	active_basic_control_points_2d_meters = ForgeV2ProfileShapeLibraryScript.constrain_basic_builder_points(active_basic_control_points_2d_meters)
	_sync_active_profile_size_from_basic_control_points()

func _scale_active_handle_control_points_to_profile_size() -> void:
	if active_handle_control_points_2d_meters.size() != active_handle_face_count:
		_reset_active_handle_control_points_for_size()
		return
	active_handle_control_points_2d_meters = ForgeV2ProfileShapeLibraryScript.scale_control_points_to_size(
		active_handle_control_points_2d_meters,
		Vector2(active_profile_width_meters, active_profile_height_meters)
	)
	active_handle_control_points_2d_meters = ForgeV2ProfileShapeLibraryScript.constrain_handle_builder_points(active_handle_control_points_2d_meters)
	_sync_active_profile_size_from_handle_control_points()

func _sync_active_profile_size_from_basic_control_points() -> void:
	if active_basic_control_points_2d_meters.size() < 3:
		return
	var control_size := ForgeV2ProfileShapeLibraryScript.calculate_polygon_size_meters(active_basic_control_points_2d_meters)
	active_profile_width_meters = _normalize_profile_size_meters(control_size.x)
	active_profile_height_meters = _normalize_profile_size_meters(control_size.y)
	var clamped_size := Vector2(active_profile_width_meters, active_profile_height_meters)
	if not control_size.is_equal_approx(clamped_size):
		active_basic_control_points_2d_meters = ForgeV2ProfileShapeLibraryScript.scale_control_points_to_size(
			active_basic_control_points_2d_meters,
			clamped_size
		)
		active_basic_control_points_2d_meters = ForgeV2ProfileShapeLibraryScript.constrain_basic_builder_points(active_basic_control_points_2d_meters)

func _sync_active_profile_size_from_handle_control_points() -> void:
	if active_handle_control_points_2d_meters.size() < 3:
		return
	var control_size := ForgeV2ProfileShapeLibraryScript.calculate_polygon_size_meters(active_handle_control_points_2d_meters)
	active_profile_width_meters = _normalize_profile_size_meters(control_size.x)
	active_profile_height_meters = _normalize_profile_size_meters(control_size.y)
	var clamped_size := Vector2(active_profile_width_meters, active_profile_height_meters)
	if not control_size.is_equal_approx(clamped_size):
		active_handle_control_points_2d_meters = ForgeV2ProfileShapeLibraryScript.scale_control_points_to_size(
			active_handle_control_points_2d_meters,
			clamped_size
		)
		active_handle_control_points_2d_meters = ForgeV2ProfileShapeLibraryScript.constrain_handle_builder_points(active_handle_control_points_2d_meters)

func _resolve_active_basic_builder_base_polygon() -> PackedVector2Array:
	if active_basic_control_points_2d_meters.size() < 3:
		_reset_active_basic_control_points_for_size()
	return (
		_resolve_active_basic_builder_fillet_geometry().get(
			"polygon",
			active_basic_control_points_2d_meters
		)
		as PackedVector2Array
	)

func _resolve_active_basic_builder_fillet_geometry() -> Dictionary:
	_normalize_active_basic_corner_metadata()
	return ForgeV2ProfileShapeLibraryScript.resolve_basic_builder_fillet_geometry(
		active_basic_control_points_2d_meters,
		active_basic_corner_metadata
	)

func _resolve_active_handle_builder_base_polygon() -> PackedVector2Array:
	if active_handle_control_points_2d_meters.size() != active_handle_face_count:
		_reset_active_handle_control_points_for_size()
	return ForgeV2ProfileShapeLibraryScript.build_handle_builder_polygon(
		active_handle_control_points_2d_meters,
		active_handle_rounding_enabled,
		active_handle_corner_radius_meters
	)

func _resolve_active_basic_builder_preview_polygon() -> PackedVector2Array:
	return _rotate_profile_polygon(_resolve_active_basic_builder_base_polygon(), active_profile_rotation_degrees)

func _resolve_active_handle_builder_preview_polygon() -> PackedVector2Array:
	return _rotate_profile_polygon(_resolve_active_handle_builder_base_polygon(), active_profile_rotation_degrees)

func _resolve_active_basic_builder_preview_control_points() -> PackedVector2Array:
	return _rotate_profile_polygon(active_basic_control_points_2d_meters, active_profile_rotation_degrees)

func _resolve_active_basic_builder_preview_fillet_corner_results() -> Array[Dictionary]:
	var preview_results: Array[Dictionary] = []
	var base_geometry := _resolve_active_basic_builder_fillet_geometry()
	for result_variant: Variant in base_geometry.get("corner_results", []):
		if not result_variant is Dictionary:
			continue
		var preview_result := (result_variant as Dictionary).duplicate(true)
		var base_arc_points: PackedVector2Array = preview_result.get(
			"arc_points",
			PackedVector2Array()
		)
		preview_result["arc_points"] = _rotate_profile_polygon(
			base_arc_points,
			active_profile_rotation_degrees
		)
		preview_results.append(preview_result)
	return preview_results

func _resolve_active_handle_builder_preview_control_points() -> PackedVector2Array:
	return _rotate_profile_polygon(active_handle_control_points_2d_meters, active_profile_rotation_degrees)

func _resolve_active_basic_builder_preview_anchor() -> Vector2:
	return _rotate_profile_point(
		Vector2(active_profile_anchor_x_meters, active_profile_anchor_y_meters),
		active_profile_rotation_degrees
	)

func _resolve_active_handle_builder_preview_anchor() -> Vector2:
	return _rotate_profile_point(
		Vector2(active_profile_anchor_x_meters, active_profile_anchor_y_meters),
		active_profile_rotation_degrees
	)

func _resolve_active_basic_builder_preview_guide_polygon() -> PackedVector2Array:
	return PackedVector2Array()

func _resolve_active_handle_builder_preview_guide_polygon() -> PackedVector2Array:
	return _rotate_profile_polygon(
		ForgeV2ProfileShapeLibraryScript.get_handle_builder_limit_polygon(),
		active_profile_rotation_degrees
	)

func _resolve_active_basic_builder_preview_grid_segments() -> Array:
	return []

func _resolve_active_handle_builder_preview_grid_segments() -> Array:
	var rotated_segments: Array = []
	for segment_variant: Variant in ForgeV2ProfileShapeLibraryScript.build_handle_builder_grid_segments():
		var segment: PackedVector2Array = segment_variant
		rotated_segments.append(_rotate_profile_polygon(segment, active_profile_rotation_degrees))
	return rotated_segments

func _resolve_active_handle_builder_preview_grid_snap_points() -> PackedVector2Array:
	return _rotate_profile_polygon(
		ForgeV2ProfileShapeLibraryScript.build_handle_builder_grid_snap_points(),
		active_profile_rotation_degrees
	)

func _resolve_active_basic_builder_preview_grid_snap_points() -> PackedVector2Array:
	return PackedVector2Array()

func _resolve_active_basic_builder_base_profile_center() -> Vector2:
	var profile_polygon := _resolve_active_basic_builder_base_polygon()
	if profile_polygon.size() < 3:
		return Vector2.ZERO
	var bounds := ForgeV2ProfileShapeLibraryScript.calculate_polygon_bounds(profile_polygon)
	return bounds.position + bounds.size * 0.5

func _resolve_active_handle_builder_base_profile_center() -> Vector2:
	var profile_polygon := _resolve_active_handle_builder_base_polygon()
	if profile_polygon.size() < 3:
		return Vector2.ZERO
	var bounds := ForgeV2ProfileShapeLibraryScript.calculate_polygon_bounds(profile_polygon)
	return bounds.position + bounds.size * 0.5

func _set_active_basic_preview_anchor(preview_anchor: Vector2, use_grid_snapping: bool = false) -> void:
	var profile_polygon := _resolve_active_basic_builder_preview_polygon()
	var constrained_anchor := Vector2(
		_normalize_profile_anchor_meters(preview_anchor.x),
		_normalize_profile_anchor_meters(preview_anchor.y)
	)
	if profile_polygon.size() >= 3:
		constrained_anchor = ForgeV2ProfileShapeLibraryScript.clamp_point_to_polygon(constrained_anchor, profile_polygon)
		if use_grid_snapping:
			constrained_anchor = _snap_anchor_to_grid_inside_profile(constrained_anchor, profile_polygon)
	var base_anchor := _rotate_profile_point(constrained_anchor, -active_profile_rotation_degrees)
	active_profile_anchor_x_meters = _normalize_profile_anchor_meters(base_anchor.x)
	active_profile_anchor_y_meters = _normalize_profile_anchor_meters(base_anchor.y)
	_constrain_active_basic_anchor()

func _set_active_handle_preview_anchor(preview_anchor: Vector2, use_grid_snapping: bool = false) -> void:
	var profile_polygon := _resolve_active_handle_builder_preview_polygon()
	var constrained_anchor := Vector2(
		_normalize_profile_anchor_meters(preview_anchor.x),
		_normalize_profile_anchor_meters(preview_anchor.y)
	)
	if profile_polygon.size() >= 3:
		constrained_anchor = ForgeV2ProfileShapeLibraryScript.clamp_point_to_polygon(constrained_anchor, profile_polygon)
		if use_grid_snapping:
			constrained_anchor = _snap_anchor_to_grid_inside_profile(constrained_anchor, profile_polygon)
	var base_anchor := _rotate_profile_point(constrained_anchor, -active_profile_rotation_degrees)
	active_profile_anchor_x_meters = _normalize_profile_anchor_meters(base_anchor.x)
	active_profile_anchor_y_meters = _normalize_profile_anchor_meters(base_anchor.y)
	_constrain_active_handle_anchor()

func _constrain_active_basic_anchor(use_grid_snapping: bool = false) -> void:
	var base_polygon := _resolve_active_basic_builder_base_polygon()
	if base_polygon.size() < 3:
		active_profile_anchor_x_meters = _normalize_profile_anchor_meters(active_profile_anchor_x_meters)
		active_profile_anchor_y_meters = _normalize_profile_anchor_meters(active_profile_anchor_y_meters)
		return
	var anchor := Vector2(active_profile_anchor_x_meters, active_profile_anchor_y_meters)
	var clearance_result := (
		ForgeV2ProfileShapeLibraryScript.constrain_point_inside_polygon_with_clearance(
			anchor,
			base_polygon,
			ForgeV2ProfileShapeLibraryScript.BASIC_PROFILE_ANCHOR_CLEARANCE_METERS
		)
	)
	if bool(clearance_result.get("valid", false)):
		anchor = clearance_result.get("point", anchor) as Vector2
	if use_grid_snapping:
		var profile_polygon := _resolve_active_basic_builder_preview_polygon()
		var preview_anchor := _rotate_profile_point(anchor, active_profile_rotation_degrees)
		preview_anchor = _snap_anchor_to_grid_inside_profile(preview_anchor, profile_polygon)
		anchor = _rotate_profile_point(preview_anchor, -active_profile_rotation_degrees)
		clearance_result = (
			ForgeV2ProfileShapeLibraryScript.constrain_point_inside_polygon_with_clearance(
				anchor,
				base_polygon,
				ForgeV2ProfileShapeLibraryScript.BASIC_PROFILE_ANCHOR_CLEARANCE_METERS
			)
		)
		if bool(clearance_result.get("valid", false)):
			anchor = clearance_result.get("point", anchor) as Vector2
	active_profile_anchor_x_meters = anchor.x
	active_profile_anchor_y_meters = anchor.y

func _constrain_active_handle_anchor(use_grid_snapping: bool = false) -> void:
	var base_polygon := _resolve_active_handle_builder_base_polygon()
	if base_polygon.size() < 3:
		active_profile_anchor_x_meters = _normalize_profile_anchor_meters(active_profile_anchor_x_meters)
		active_profile_anchor_y_meters = _normalize_profile_anchor_meters(active_profile_anchor_y_meters)
		return
	var anchor := Vector2(active_profile_anchor_x_meters, active_profile_anchor_y_meters)
	var clearance_result := (
		ForgeV2ProfileShapeLibraryScript.constrain_point_inside_polygon_with_clearance(
			anchor,
			base_polygon,
			ForgeV2ProfileShapeLibraryScript.BASIC_PROFILE_ANCHOR_CLEARANCE_METERS
		)
	)
	if bool(clearance_result.get("valid", false)):
		anchor = clearance_result.get("point", anchor) as Vector2
	else:
		anchor = ForgeV2ProfileShapeLibraryScript.clamp_point_to_polygon(
			anchor,
			base_polygon
		)
	if use_grid_snapping:
		var profile_polygon := _resolve_active_handle_builder_preview_polygon()
		var preview_anchor := _rotate_profile_point(anchor, active_profile_rotation_degrees)
		preview_anchor = _snap_anchor_to_grid_inside_profile(preview_anchor, profile_polygon)
		anchor = _rotate_profile_point(preview_anchor, -active_profile_rotation_degrees)
		clearance_result = (
			ForgeV2ProfileShapeLibraryScript.constrain_point_inside_polygon_with_clearance(
				anchor,
				base_polygon,
				ForgeV2ProfileShapeLibraryScript.BASIC_PROFILE_ANCHOR_CLEARANCE_METERS
			)
		)
		if bool(clearance_result.get("valid", false)):
			anchor = clearance_result.get("point", anchor) as Vector2
		else:
			anchor = ForgeV2ProfileShapeLibraryScript.clamp_point_to_polygon(
				anchor,
				base_polygon
			)
	active_profile_anchor_x_meters = anchor.x
	active_profile_anchor_y_meters = anchor.y

func _constrain_active_basic_preview_point_to_guide(preview_point: Vector2, use_grid_snapping: bool = false) -> Vector2:
	if not use_grid_snapping:
		return preview_point
	return ForgeV2ProfileShapeLibraryScript.snap_point_to_grid(
		preview_point,
		ForgeV2ProfileShapeLibraryScript.BASIC_BUILDER_GRID_STEP_METERS,
		active_profile_rotation_degrees
	)

func _constrain_active_handle_preview_point_to_guide(preview_point: Vector2, use_grid_snapping: bool = false) -> Vector2:
	var guide_polygon := _resolve_active_handle_builder_preview_guide_polygon()
	if guide_polygon.size() < 3:
		return preview_point
	var constrained_point := ForgeV2ProfileShapeLibraryScript.clamp_point_to_polygon(preview_point, guide_polygon)
	if not use_grid_snapping:
		return constrained_point
	var snap_points := _resolve_active_handle_builder_preview_grid_snap_points()
	if snap_points.is_empty():
		return constrained_point
	var nearest_point: Vector2 = snap_points[0]
	var nearest_distance := nearest_point.distance_squared_to(constrained_point)
	for snap_point: Vector2 in snap_points:
		var distance := snap_point.distance_squared_to(constrained_point)
		if distance >= nearest_distance:
			continue
		nearest_distance = distance
		nearest_point = snap_point
	return nearest_point

func _snap_anchor_to_grid_inside_profile(anchor: Vector2, profile_polygon: PackedVector2Array) -> Vector2:
	if _is_active_basic_builder_profile():
		return ForgeV2ProfileShapeLibraryScript.snap_point_to_grid_inside_polygon(
			anchor,
			profile_polygon,
			ForgeV2ProfileShapeLibraryScript.BASIC_BUILDER_GRID_STEP_METERS,
			active_profile_rotation_degrees
		)
	var snap_points := (
		_resolve_active_handle_builder_preview_grid_snap_points()
	)
	if snap_points.is_empty():
		return anchor
	var nearest_point := anchor
	var nearest_distance := INF
	for snap_point: Vector2 in snap_points:
		var clamped_snap := ForgeV2ProfileShapeLibraryScript.clamp_point_to_polygon(snap_point, profile_polygon)
		if clamped_snap.distance_squared_to(snap_point) > 0.0000000001:
			continue
		var distance := snap_point.distance_squared_to(anchor)
		if distance >= nearest_distance:
			continue
		nearest_distance = distance
		nearest_point = snap_point
	return nearest_point if nearest_distance < INF else anchor

func _rotate_profile_polygon(polygon: PackedVector2Array, rotation_degrees: float) -> PackedVector2Array:
	if polygon.is_empty():
		return PackedVector2Array()
	var rotated := PackedVector2Array()
	for point: Vector2 in polygon:
		rotated.append(_rotate_profile_point(point, rotation_degrees))
	return rotated

func _rotate_profile_point(point: Vector2, rotation_degrees: float) -> Vector2:
	if is_zero_approx(rotation_degrees):
		return point
	return point.rotated(deg_to_rad(rotation_degrees))

func _build_active_profile_builder_settings_summary() -> Dictionary:
	if _is_active_basic_builder_profile():
		var base_polygon := _resolve_active_basic_builder_base_polygon()
		var anchor_clearance_result := (
			ForgeV2ProfileShapeLibraryScript.constrain_point_inside_polygon_with_clearance(
				Vector2(
					active_profile_anchor_x_meters,
					active_profile_anchor_y_meters
				),
				base_polygon,
				ForgeV2ProfileShapeLibraryScript.BASIC_PROFILE_ANCHOR_CLEARANCE_METERS
			)
		)
		return {
			"is_active": true,
			"family": ForgeV2ProfileShapeLibraryScript.PROFILE_FAMILY_BASIC,
			"rounded_enabled": _active_basic_profile_has_fillet(),
			"control_points_2d_meters": _resolve_active_basic_builder_preview_control_points(),
			"base_control_points_2d_meters": active_basic_control_points_2d_meters,
			"corner_metadata": _duplicate_basic_corner_metadata(),
			"fillet_corner_results": (
				_resolve_active_basic_builder_preview_fillet_corner_results()
			),
			"base_anchor_2d_meters": Vector2(active_profile_anchor_x_meters, active_profile_anchor_y_meters),
			"anchor_2d_meters": _resolve_active_basic_builder_preview_anchor(),
			"geometric_center_2d_meters": Vector2.ZERO,
			"grid_snapping_enabled": active_basic_grid_snapping_enabled,
			"guide_polygon_2d_meters": _resolve_active_basic_builder_preview_guide_polygon(),
			"guide_grid_segments_2d_meters": _resolve_active_basic_builder_preview_grid_segments(),
			"guide_grid_snap_points_2d_meters": _resolve_active_basic_builder_preview_grid_snap_points(),
			"guide_grid_step_meters": ForgeV2ProfileShapeLibraryScript.BASIC_BUILDER_GRID_STEP_METERS,
			"temporary_guide_profile_id": StringName(),
			"anchor_clearance_valid": bool(anchor_clearance_result.get(
				"valid",
				false
			)),
			"anchor_clearance_error": StringName(anchor_clearance_result.get(
				"error",
				&"anchor_clearance_unavailable"
			)),
			"anchor_clearance_meters": (
				ForgeV2ProfileShapeLibraryScript.BASIC_PROFILE_ANCHOR_CLEARANCE_METERS
			),
		}
	if _is_active_handle_builder_profile():
		var handle_base_polygon := _resolve_active_handle_builder_base_polygon()
		var anchor_clearance_result := (
			ForgeV2ProfileShapeLibraryScript.constrain_point_inside_polygon_with_clearance(
				Vector2(
					active_profile_anchor_x_meters,
					active_profile_anchor_y_meters
				),
				handle_base_polygon,
				ForgeV2ProfileShapeLibraryScript.BASIC_PROFILE_ANCHOR_CLEARANCE_METERS
			)
		)
		return {
			"is_active": true,
			"family": ForgeV2ProfileShapeLibraryScript.PROFILE_FAMILY_HANDLE,
			"rounded_enabled": active_handle_rounding_enabled,
			"control_points_2d_meters": _resolve_active_handle_builder_preview_control_points(),
			"base_control_points_2d_meters": active_handle_control_points_2d_meters,
			"base_anchor_2d_meters": Vector2(active_profile_anchor_x_meters, active_profile_anchor_y_meters),
			"anchor_2d_meters": _resolve_active_handle_builder_preview_anchor(),
			"geometric_center_2d_meters": Vector2.ZERO,
			"grid_snapping_enabled": active_handle_grid_snapping_enabled,
			"guide_polygon_2d_meters": _resolve_active_handle_builder_preview_guide_polygon(),
			"guide_grid_segments_2d_meters": _resolve_active_handle_builder_preview_grid_segments(),
			"guide_grid_snap_points_2d_meters": _resolve_active_handle_builder_preview_grid_snap_points(),
			"guide_grid_step_meters": ForgeV2ProfileShapeLibraryScript.HANDLE_BUILDER_GRID_STEP_METERS,
			"temporary_guide_profile_id": ForgeV2ProfileShapeLibraryScript.HANDLE_BUILDER_LIMIT_PRESET_ID,
			"anchor_clearance_valid": bool(anchor_clearance_result.get(
				"valid",
				false
			)),
			"anchor_clearance_error": StringName(anchor_clearance_result.get(
				"error",
				&"anchor_clearance_unavailable"
			)),
			"anchor_clearance_meters": (
				ForgeV2ProfileShapeLibraryScript.BASIC_PROFILE_ANCHOR_CLEARANCE_METERS
			),
		}
	return {}

func _active_basic_profile_has_fillet() -> bool:
	for metadata: Dictionary in active_basic_corner_metadata:
		if (
			metadata.has("radius_meters")
			and float(metadata.get("radius_meters", 0.0))
			>= ForgeV2ProfileShapeLibraryScript.BASIC_FILLET_RADIUS_MIN_METERS
		):
			return true
	return false

func _build_handle_builder_settings_summary() -> Dictionary:
	if not _is_active_handle_builder_profile():
		return {}
	var max_corner_radius := ForgeV2ProfileShapeLibraryScript.calculate_max_corner_radius_meters(active_handle_control_points_2d_meters)
	return {
		"is_active": true,
		"face_count": active_handle_face_count,
		"rounded_enabled": active_handle_rounding_enabled,
		"corner_radius_meters": active_handle_corner_radius_meters,
		"corner_radius_max_meters": max_corner_radius,
		"control_points_2d_meters": _resolve_active_handle_builder_preview_control_points(),
		"base_control_points_2d_meters": active_handle_control_points_2d_meters,
		"base_anchor_2d_meters": Vector2(active_profile_anchor_x_meters, active_profile_anchor_y_meters),
		"anchor_2d_meters": _resolve_active_handle_builder_preview_anchor(),
		"geometric_center_2d_meters": Vector2.ZERO,
		"grid_snapping_enabled": active_handle_grid_snapping_enabled,
		"guide_polygon_2d_meters": _resolve_active_handle_builder_preview_guide_polygon(),
		"guide_grid_segments_2d_meters": _resolve_active_handle_builder_preview_grid_segments(),
		"guide_grid_snap_points_2d_meters": _resolve_active_handle_builder_preview_grid_snap_points(),
		"guide_grid_step_meters": ForgeV2ProfileShapeLibraryScript.HANDLE_BUILDER_GRID_STEP_METERS,
	}

func _migrate_legacy_surface_contact_authority(
	loaded_schema_version: int
) -> void:
	if loaded_schema_version >= 5:
		return
	var migrated_record_fields_by_body_id: Dictionary = {}
	for body: Resource in material_bodies:
		if body == null:
			continue
		if (
			StringName(body.get("shape_kind"))
			!= ForgeV2MaterialBodyScript.SHAPE_KIND_PROFILE_PATH
			or int(body.get("profile_runtime_schema_version")) <= 0
		):
			continue
		var body_kind := StringName(body.get("body_kind"))
		if body_kind == ForgeV2MaterialBodyScript.BODY_KIND_PROFILE_EXTRUSION:
			# Schema 4 saved-profile freehand strokes used the profile-extrusion
			# default even though they were surface Volume Stroke bodies.
			body_kind = ForgeV2MaterialBodyScript.BODY_KIND_VOLUME_STROKE
			body.set("body_kind", body_kind)
		if (
			body_kind != ForgeV2MaterialBodyScript.BODY_KIND_VOLUME_STROKE
			and body_kind != ForgeV2MaterialBodyScript.BODY_KIND_DETAILING_BRUSH
		):
			continue
		var existing_contacts: PackedVector3Array = body.get(
			"path_contact_directions"
		)
		var path_points: PackedVector3Array = body.get("path_points")
		if existing_contacts.is_empty():
			existing_contacts = _build_legacy_contact_directions(
				body.get("path_surface_normals") as PackedVector3Array,
				path_points.size()
			)
			body.set("path_contact_directions", existing_contacts)
		if (
			not existing_contacts.is_empty()
			and existing_contacts.size() == path_points.size()
		):
			var migrated_body_id := StringName(body.get("body_id"))
			if migrated_body_id != StringName():
				migrated_record_fields_by_body_id[migrated_body_id] = {
					"body_kind": body_kind,
					"path_contact_directions": existing_contacts,
				}
	_migrate_legacy_layer_surface_contact_records(
		forge_layers,
		migrated_record_fields_by_body_id
	)
	_migrate_legacy_layer_surface_contact_records(
		undone_forge_layers,
		migrated_record_fields_by_body_id
	)
	_migrate_legacy_layer_surface_contact_records(
		protected_forge_layers,
		migrated_record_fields_by_body_id
	)
	if (
		active_tool_id == TOOL_DETAILING_BRUSH
		and detailing_control_contact_directions.is_empty()
		and spline_line_surface_normals.size() == spline_line_points.size()
	):
		detailing_control_contact_directions = _build_legacy_contact_directions(
			spline_line_surface_normals,
			spline_line_points.size()
		)
	if (
		active_tool_id == TOOL_DETAILING_BRUSH
		and detailing_resolved_contact_directions.is_empty()
		and detailing_resolved_surface_normals.size()
		== detailing_resolved_path_points.size()
	):
		detailing_resolved_contact_directions = _build_legacy_contact_directions(
			detailing_resolved_surface_normals,
			detailing_resolved_path_points.size()
		)

func _migrate_legacy_layer_surface_contact_records(
	layers: Array[Resource],
	migrated_record_fields_by_body_id: Dictionary
) -> void:
	for layer: Resource in layers:
		if layer == null:
			continue
		var source_records: Array = layer.get("input_shape_records") as Array
		var migrated_records: Array[Dictionary] = []
		for record_variant: Variant in source_records:
			if not record_variant is Dictionary:
				continue
			var record := (record_variant as Dictionary).duplicate(true)
			var record_body_id := StringName(record.get("body_id", StringName()))
			if migrated_record_fields_by_body_id.has(record_body_id):
				var migrated_fields: Dictionary = (
					migrated_record_fields_by_body_id[record_body_id] as Dictionary
				)
				record["body_kind"] = StringName(migrated_fields.get(
					"body_kind",
					record.get("body_kind", StringName())
				))
				record["path_contact_directions"] = migrated_fields.get(
					"path_contact_directions",
					PackedVector3Array()
				)
			migrated_records.append(record)
		layer.set("input_shape_records", migrated_records)

func _build_legacy_contact_directions(
	legacy_normals: PackedVector3Array,
	expected_count: int
) -> PackedVector3Array:
	if legacy_normals.size() != expected_count:
		return PackedVector3Array()
	var migrated_contacts := PackedVector3Array()
	for legacy_normal: Vector3 in legacy_normals:
		if (
			not _detail_vector3_is_finite(legacy_normal)
			or legacy_normal.length_squared() <= 0.000001
		):
			return PackedVector3Array()
		# Compatibility only: schema 4 runtime defined B->C as -normal.
		migrated_contacts.append(-legacy_normal.normalized())
	return migrated_contacts

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

func _normalize_handle_path_mode_id(next_mode_id: StringName) -> StringName:
	match next_mode_id:
		HANDLE_PATH_MODE_THREE_POINT_LINEAR, HANDLE_PATH_MODE_TWO_POINT_LINEAR:
			return next_mode_id
		_:
			return HANDLE_PATH_MODE_THREE_POINT_SPLINE

func _resolve_handle_path_mode_id_from_body(body: Resource) -> StringName:
	if body == null:
		return HANDLE_PATH_MODE_THREE_POINT_SPLINE
	var shape_kind := StringName(body.get("shape_kind"))
	var path_points: PackedVector3Array = body.get("path_points")
	if shape_kind == ForgeV2MaterialBodyScript.SHAPE_KIND_PROFILE_PATH:
		return (
			HANDLE_PATH_MODE_TWO_POINT_LINEAR
			if path_points.size() == HANDLE_TWO_POINT_COUNT
			else HANDLE_PATH_MODE_THREE_POINT_LINEAR
		)
	return HANDLE_PATH_MODE_THREE_POINT_SPLINE

func _normalize_active_handle_path_mode_from_body() -> void:
	if is_handle_change_active():
		return
	var handles := _collect_live_handle_material_bodies()
	if handles.size() != 1:
		return
	active_handle_path_mode_id = _resolve_handle_path_mode_id_from_body(
		handles[0]
	)

func _convert_handle_path_point_count(
	previous_required_point_count: int,
	next_required_point_count: int
) -> void:
	if previous_required_point_count == next_required_point_count:
		return
	if (
		previous_required_point_count == HANDLE_THREE_POINT_COUNT
		and next_required_point_count == HANDLE_TWO_POINT_COUNT
		and spline_line_points.size() >= HANDLE_THREE_POINT_COUNT
	):
		var reduced_points := PackedVector3Array([
			spline_line_points[0],
			spline_line_points[spline_line_points.size() - 1],
		])
		var reduced_normals := PackedVector3Array([
			_resolve_spline_line_surface_normal(0),
			_resolve_spline_line_surface_normal(
				spline_line_points.size() - 1
			),
		])
		spline_line_points = reduced_points
		spline_line_surface_normals = reduced_normals
		selected_spline_point_index = -1
		return
	if (
		previous_required_point_count == HANDLE_TWO_POINT_COUNT
		and next_required_point_count == HANDLE_THREE_POINT_COUNT
		and spline_line_points.size() == HANDLE_TWO_POINT_COUNT
	):
		var start_point := spline_line_points[0]
		var end_point := spline_line_points[1]
		var start_normal := _resolve_spline_line_surface_normal(0)
		var end_normal := _resolve_spline_line_surface_normal(1)
		spline_line_points = PackedVector3Array([
			start_point,
			start_point.lerp(end_point, 0.5),
			end_point,
		])
		spline_line_surface_normals = PackedVector3Array([
			start_normal,
			_normalize_path_surface_normal(start_normal.lerp(end_normal, 0.5)),
			end_normal,
		])
		selected_spline_point_index = -1

func _resolve_spline_line_surface_normal(point_index: int) -> Vector3:
	if point_index < 0 or point_index >= spline_line_surface_normals.size():
		return Vector3.FORWARD
	return _normalize_path_surface_normal(
		spline_line_surface_normals[point_index]
	)

func _normalize_spline_line() -> void:
	var required_handle_point_count := get_active_handle_required_point_count()
	if (
		active_tool_id == TOOL_HANDLES
		and spline_line_points.size() > required_handle_point_count
	):
		var capped_points := PackedVector3Array()
		var capped_normals := PackedVector3Array()
		for point_index in range(required_handle_point_count):
			capped_points.append(spline_line_points[point_index])
			var point_normal := Vector3.FORWARD
			if point_index < spline_line_surface_normals.size():
				point_normal = spline_line_surface_normals[point_index]
			capped_normals.append(
				_normalize_path_surface_normal(point_normal)
			)
		spline_line_points = capped_points
		spline_line_surface_normals = capped_normals
	var normalized_surface_normals := PackedVector3Array()
	for point_index in range(spline_line_points.size()):
		var point_normal := Vector3.FORWARD
		if point_index < spline_line_surface_normals.size():
			point_normal = spline_line_surface_normals[point_index]
		normalized_surface_normals.append(
			_normalize_path_surface_normal(point_normal)
		)
	spline_line_surface_normals = normalized_surface_normals
	if selected_spline_point_index >= spline_line_points.size():
		selected_spline_point_index = -1
	if selected_spline_point_index < -1:
		selected_spline_point_index = -1
	if spline_line_points.size() < 2:
		spline_line_finished = false
	_normalize_detailing_brush_solution()

func _normalize_detailing_brush_solution() -> void:
	if active_tool_id != TOOL_DETAILING_BRUSH:
		_clear_detailing_brush_solution()
		return
	if (
		spline_line_points.is_empty()
		and spline_line_surface_normals.is_empty()
		and detailing_surface_target_kind == StringName()
		and detailing_surface_target_id == StringName()
		and detailing_control_contact_directions.is_empty()
		and detailing_resolved_path_points.is_empty()
		and detailing_resolved_surface_normals.is_empty()
		and detailing_resolved_contact_directions.is_empty()
		and detailing_span_offsets.is_empty()
		and detailing_span_validity.is_empty()
		and detailing_span_reasons.is_empty()
	):
		_clear_detailing_brush_solution()
		return
	var validated := _build_validated_detailing_brush_solution(
		spline_line_points,
		spline_line_surface_normals,
		detailing_control_contact_directions,
		detailing_surface_target_kind,
		detailing_surface_target_id,
		detailing_resolved_path_points,
		detailing_resolved_surface_normals,
		detailing_resolved_contact_directions,
		detailing_span_offsets,
		detailing_span_validity,
		detailing_span_reasons,
		detailing_solution_valid,
		detailing_solution_reason
	)
	if not bool(validated.get("accepted", false)):
		_clear_detailing_brush_solution()
		detailing_solution_reason = DETAIL_SOLUTION_REASON_INVALID_PERSISTED
		return
	spline_line_points = validated.get(
		"control_points",
		PackedVector3Array()
	) as PackedVector3Array
	spline_line_surface_normals = validated.get(
		"control_surface_normals",
		PackedVector3Array()
	) as PackedVector3Array
	detailing_control_contact_directions = validated.get(
		"control_contact_directions",
		PackedVector3Array()
	) as PackedVector3Array
	detailing_resolved_path_points = validated.get(
		"resolved_path_points",
		PackedVector3Array()
	) as PackedVector3Array
	detailing_resolved_surface_normals = validated.get(
		"resolved_surface_normals",
		PackedVector3Array()
	) as PackedVector3Array
	detailing_resolved_contact_directions = validated.get(
		"resolved_contact_directions",
		PackedVector3Array()
	) as PackedVector3Array
	detailing_span_validity = validated.get("span_validity", []) as Array[bool]
	detailing_span_reasons = validated.get("span_reasons", []) as Array[StringName]
	detailing_solution_reason = (
		DETAIL_SOLUTION_REASON_NONE
		if detailing_solution_valid
		else StringName(validated.get(
			"solution_reason",
			DETAIL_SOLUTION_REASON_NOT_READY
		))
	)

func _build_validated_detailing_brush_solution(
	control_points: PackedVector3Array,
	control_surface_normals: PackedVector3Array,
	control_contact_directions: PackedVector3Array,
	locked_target_kind: StringName,
	locked_target_id: StringName,
	resolved_path_points: PackedVector3Array,
	resolved_surface_normals: PackedVector3Array,
	resolved_contact_directions: PackedVector3Array,
	span_offsets: PackedInt32Array,
	span_validity: Array,
	span_reasons: Array,
	solution_valid: bool,
	solution_reason: StringName
) -> Dictionary:
	if locked_target_kind == StringName() or locked_target_id == StringName():
		return {"accepted": false}
	if control_surface_normals.size() != control_points.size():
		return {"accepted": false}
	if control_contact_directions.size() != control_points.size():
		return {"accepted": false}
	if resolved_surface_normals.size() != resolved_path_points.size():
		return {"accepted": false}
	if resolved_contact_directions.size() != resolved_path_points.size():
		return {"accepted": false}
	if span_offsets.size() != control_points.size():
		return {"accepted": false}
	var span_count := maxi(control_points.size() - 1, 0)
	if span_validity.size() != span_count or span_reasons.size() != span_count:
		return {"accepted": false}
	var normalized_control_normals := _normalized_detailing_normals(
		control_surface_normals
	)
	var normalized_resolved_normals := _normalized_detailing_normals(
		resolved_surface_normals
	)
	var normalized_control_contacts := _normalized_detailing_normals(
		control_contact_directions
	)
	var normalized_resolved_contacts := _normalized_detailing_normals(
		resolved_contact_directions
	)
	if (
		normalized_control_normals.size() != control_points.size()
		or normalized_resolved_normals.size() != resolved_path_points.size()
		or normalized_control_contacts.size() != control_points.size()
		or normalized_resolved_contacts.size() != resolved_path_points.size()
	):
		return {"accepted": false}
	for point: Vector3 in control_points:
		if not _detail_vector3_is_finite(point):
			return {"accepted": false}
	for point: Vector3 in resolved_path_points:
		if not _detail_vector3_is_finite(point):
			return {"accepted": false}
	if control_points.is_empty():
		if not resolved_path_points.is_empty() or not span_offsets.is_empty():
			return {"accepted": false}
	elif resolved_path_points.is_empty():
		return {"accepted": false}
	else:
		if int(span_offsets[0]) != 0:
			return {"accepted": false}
		if int(span_offsets[span_offsets.size() - 1]) != resolved_path_points.size() - 1:
			return {"accepted": false}
		var previous_offset := -1
		for control_index in range(control_points.size()):
			var resolved_index := int(span_offsets[control_index])
			if (
				resolved_index < previous_offset
				or resolved_index < 0
				or resolved_index >= resolved_path_points.size()
			):
				return {"accepted": false}
			if not resolved_path_points[resolved_index].is_equal_approx(
				control_points[control_index]
			):
				return {"accepted": false}
			if not normalized_resolved_normals[resolved_index].is_equal_approx(
				normalized_control_normals[control_index]
			):
				return {"accepted": false}
			if not normalized_resolved_contacts[resolved_index].is_equal_approx(
				normalized_control_contacts[control_index]
			):
				return {"accepted": false}
			previous_offset = resolved_index
	var normalized_span_validity: Array[bool] = []
	var normalized_span_reasons: Array[StringName] = []
	var all_spans_valid := true
	for span_index in range(span_count):
		var span_is_valid := bool(span_validity[span_index])
		var span_reason := StringName(span_reasons[span_index])
		if span_is_valid:
			span_reason = DETAIL_SOLUTION_REASON_NONE
		elif span_reason == StringName() or span_reason == DETAIL_SOLUTION_REASON_NONE:
			span_reason = DETAIL_SOLUTION_REASON_NOT_READY
		normalized_span_validity.append(span_is_valid)
		normalized_span_reasons.append(span_reason)
		all_spans_valid = all_spans_valid and span_is_valid
	if solution_valid:
		if (
			control_points.size() < 2
			or not all_spans_valid
			or _calculate_polyline_path_length(resolved_path_points) <= 0.000001
		):
			return {"accepted": false}
		solution_reason = DETAIL_SOLUTION_REASON_NONE
	elif solution_reason == StringName() or solution_reason == DETAIL_SOLUTION_REASON_NONE:
		solution_reason = DETAIL_SOLUTION_REASON_NOT_READY
	return {
		"accepted": true,
		"control_points": control_points.duplicate(),
		"control_surface_normals": normalized_control_normals,
		"control_contact_directions": normalized_control_contacts,
		"resolved_path_points": resolved_path_points.duplicate(),
		"resolved_surface_normals": normalized_resolved_normals,
		"resolved_contact_directions": normalized_resolved_contacts,
		"span_validity": normalized_span_validity,
		"span_reasons": normalized_span_reasons,
		"solution_reason": solution_reason,
	}

func _normalized_detailing_normals(normals: PackedVector3Array) -> PackedVector3Array:
	var normalized_normals := PackedVector3Array()
	for normal: Vector3 in normals:
		if (
			not _detail_vector3_is_finite(normal)
			or normal.length_squared() <= 0.000000000001
		):
			return PackedVector3Array()
		normalized_normals.append(normal.normalized())
	return normalized_normals

func _clear_spline_transient_state() -> void:
	spline_line_points = PackedVector3Array()
	spline_line_surface_normals = PackedVector3Array()
	spline_line_finished = false
	selected_spline_point_index = -1
	spline_line_csg_noodle_enabled = false
	_clear_detailing_brush_solution()

func _clear_detailing_brush_solution() -> void:
	detailing_surface_target_kind = StringName()
	detailing_surface_target_id = StringName()
	detailing_control_contact_directions = PackedVector3Array()
	detailing_resolved_path_points = PackedVector3Array()
	detailing_resolved_surface_normals = PackedVector3Array()
	detailing_resolved_contact_directions = PackedVector3Array()
	detailing_span_offsets = PackedInt32Array()
	detailing_span_validity = []
	detailing_span_reasons = []
	detailing_solution_valid = false
	detailing_solution_reason = DETAIL_SOLUTION_REASON_NOT_READY

func _has_spline_transient_state() -> bool:
	return (
		not spline_line_points.is_empty()
		or not spline_line_surface_normals.is_empty()
		or spline_line_finished
		or selected_spline_point_index >= 0
		or spline_line_csg_noodle_enabled
		or detailing_surface_target_kind != StringName()
		or detailing_surface_target_id != StringName()
		or not detailing_control_contact_directions.is_empty()
		or not detailing_resolved_path_points.is_empty()
		or not detailing_resolved_surface_normals.is_empty()
		or not detailing_resolved_contact_directions.is_empty()
		or not detailing_span_offsets.is_empty()
		or not detailing_span_validity.is_empty()
		or not detailing_span_reasons.is_empty()
	)

func _calculate_polyline_path_length(points: PackedVector3Array) -> float:
	var path_length := 0.0
	for point_index in range(points.size() - 1):
		path_length += points[point_index].distance_to(points[point_index + 1])
	return path_length

func _detail_vector3_is_finite(value: Vector3) -> bool:
	return is_finite(value.x) and is_finite(value.y) and is_finite(value.z)

func _normalize_path_surface_normal(surface_normal: Vector3) -> Vector3:
	if surface_normal.length_squared() <= 0.000001:
		return Vector3.FORWARD
	return surface_normal.normalized()

func _normalize_path_contact_direction(contact_direction: Vector3) -> Vector3:
	if (
		not _detail_vector3_is_finite(contact_direction)
		or contact_direction.length_squared() <= 0.000001
	):
		return Vector3.ZERO
	return contact_direction.normalized()

func _calculate_spline_line_path_length() -> float:
	_normalize_spline_line()
	if spline_line_points.size() < 2:
		return 0.0
	var path_length := 0.0
	for point_index in range(spline_line_points.size() - 1):
		path_length += spline_line_points[point_index].distance_to(spline_line_points[point_index + 1])
	return path_length

func _calculate_handle_endpoint_span(path_points: PackedVector3Array) -> float:
	if path_points.size() < 2:
		return 0.0
	return path_points[0].distance_to(path_points[path_points.size() - 1])

func _handle_endpoint_span_meets_minimum(
	path_points: PackedVector3Array
) -> bool:
	return (
		_calculate_handle_endpoint_span(path_points) + 0.000001
		>= HANDLE_MIN_AXIAL_SPAN_METERS
	)

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
