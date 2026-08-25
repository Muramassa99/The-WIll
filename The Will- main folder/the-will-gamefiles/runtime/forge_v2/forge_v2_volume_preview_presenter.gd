extends Node3D
class_name ForgeV2VolumePreviewPresenter

const ForgeV2VolumeStrokeScript = preload("res://runtime/forge_v2/forge_v2_volume_stroke.gd")
const ForgeV2MaterialBodyScript = preload("res://runtime/forge_v2/forge_v2_material_body.gd")
const ForgeV2MaterialCompositionPolicyScript = preload(
	"res://runtime/forge_v2/forge_v2_material_composition_policy.gd"
)
const ForgeV2MaterialPaletteScript = preload("res://runtime/forge_v2/forge_v2_material_palette.gd")
const ForgeV2ProfileShapeLibraryScript = preload("res://runtime/forge_v2/forge_v2_profile_shape_library.gd")
const ForgeV2SplinePathSamplerScript = preload(
	"res://runtime/forge_v2/forge_v2_spline_path_sampler.gd"
)
const PrimaryGripHandleMeshPacketScript = preload(
	"res://core/resolvers/primary_grip_handle_mesh_packet.gd"
)

const PREVIEW_TUBE_SIDES := 12
const PREVIEW_SPHERE_RINGS := 6
const PREVIEW_SPHERE_SIDES := 12
const DEFAULT_PREVIEW_RADIUS_METERS := 0.06
const SPLINE_PREVIEW_RADIUS_METERS := 0.014
const SPLINE_POINT_RADIUS_METERS := 0.028
const SPLINE_SELECTED_POINT_RADIUS_METERS := 0.038
const SPLINE_PREVIEW_BAKE_INTERVAL_METERS := 0.015
const SPLINE_CSG_CIRCLE_SIDES := 24
const SPLINE_CSG_PATH_INTERVAL_RADIUS_RATIO_FALLBACK := 0.55
const SPLINE_CSG_PATH_INTERVAL_MIN_METERS_FALLBACK := 0.00625
const MATERIAL_SURFACE_COLLISION_LAYER := 1 << 20
const DETAILING_BRUSH_TOOL_ID := &"tool_detailing_brush"
const HANDLE_TOOL_ID := &"tool_handles"
const DETAILING_INVALID_LINE_COLOR := Color(1.0, 0.08, 0.04, 0.98)
const NATIVE_STATIC_LIFECYCLE_UNOBSERVED := "unobserved"
const NATIVE_STATIC_LIFECYCLE_ARMED_EMPTY := "armed_empty"
const NATIVE_STATIC_LIFECYCLE_ACTIVE := "active"
const NATIVE_STATIC_LIFECYCLE_DISABLED := "disabled_until_empty"
const BOUNDED_HISTORY_WINDOW_CAPACITY := 5
const NATIVE_STATIC_CSG_READINESS_FRAME_LIMIT := 8
const NATIVE_CAPSULE_OPERAND_BAKE_FRAME_LIMIT := 3
const NATIVE_CAPSULE_OPERAND_CACHE_CAPACITY := 12
const NATIVE_PROTECTED_HANDLE_BOOTSTRAP_NODE_NAME := (
	"NativeProtectedHandleExactMeshBootstrap"
)

var active_stage_controller: Node = null
var preview_mesh_instance: MeshInstance3D = null
var spline_preview_mesh_instance: MeshInstance3D = null
var spline_invalid_preview_mesh_instance: MeshInstance3D = null
var spline_invalid_preview_material: StandardMaterial3D = null
var spline_csg_path: Path3D = null
var spline_csg_polygon: CSGPolygon3D = null
var active_material_body_preview_mesh_instance: MeshInstance3D = null
var active_material_body_add_preview_material: StandardMaterial3D = null
var active_material_body_remove_preview_material: StandardMaterial3D = null
var resolved_material_color_cache: Dictionary = {}
var csg_material_body_root: Node3D = null
var csg_static_body_root: Node3D = null
var csg_active_body_root: Node3D = null
var native_static_body_root: Node3D = null
var placement_cursor_mesh_instance: MeshInstance3D = null
var csg_static_zone_nodes: Dictionary = {}
var csg_static_zone_signatures: Dictionary = {}
var csg_static_zone_body_ids_by_key: Dictionary = {}
var csg_static_body_zone_key_by_id: Dictionary = {}
var csg_static_zones_initialized := false
var csg_static_body_order_snapshot: Array[StringName] = []
var csg_static_body_signatures_by_id: Dictionary = {}
var csg_static_target_metadata_generation := 0
var csg_static_sync_diagnostics := {
	"last_mode": "not_started",
	"no_op_count": 0,
	"incremental_append_count": 0,
	"full_rebuild_count": 0,
	"last_appended_body_id": StringName(),
	"last_fallback_reason": "",
}
var native_static_manifold_backend: Object = null
var native_static_published_node: Node3D = null
var native_static_staged_node: Node3D = null
var native_static_retiring_node: Node3D = null
var native_static_body_order_snapshot: Array[StringName] = []
var native_static_body_signatures_by_id: Dictionary = {}
var native_static_body_bounds_by_id: Dictionary = {}
var native_static_material_variant_id := StringName()
var native_static_expected_revision := 0
var native_static_published_revision := 0
var native_static_staged_revision := 0
var native_static_publication_generation := 0
var native_static_lifecycle := NATIVE_STATIC_LIFECYCLE_UNOBSERVED
var native_static_authoritative := false
var native_static_publication_pending := false
var native_static_state_initialized := false
var native_static_bound_state_instance_id := 0
var native_static_bound_authoring_state: Resource = null
var native_static_consumed_transition_revision := -1
var bounded_csg_fallback_signature := ""
var native_static_active_vertices := PackedVector3Array()
var native_static_active_indices := PackedInt32Array()
var native_capsule_operand_staging_root: Node3D = null
var native_capsule_operand_generation := 0
var native_capsule_operand_cache: Dictionary = {}
var native_capsule_operand_cache_order: Array[String] = []
var native_capsule_operand_pending: Dictionary = {}
var native_capsule_operand_failures: Dictionary = {}
var native_static_deferred_transition_revision := -1
var native_static_bounded_resync_required := false
var native_protected_handle_cache_signature := ""
var native_protected_handle_cache_packet: Dictionary = {}
var native_protected_handle_cache_failure_signature := ""
var native_protected_handle_cache_failure_reason := ""
var native_protected_handle_authority_generation := 0
var native_protected_handle_authority_pending_signature := ""
var native_protected_handle_authority_pending_root: Node3D = null
var native_static_sync_diagnostics := {
	"lifecycle": NATIVE_STATIC_LIFECYCLE_UNOBSERVED,
	"last_mode": "not_started",
	"authoritative": false,
	"state_initialized": false,
	"publication_pending": false,
	"bounded_transition_revision": -1,
	"prefix_body_count": 0,
	"material_variant_id": StringName(),
	"expected_revision": 0,
	"published_revision": 0,
	"staged_revision": 0,
	"reset_count": 0,
	"append_count": 0,
	"undo_count": 0,
	"redo_count_total": 0,
	"restore_count": 0,
	"hot_checkpoint_exports": 0,
	"lazy_checkpoint_exports": 0,
	"publication_count": 0,
	"fallback_count": 0,
	"last_failure_reason": "",
	"last_native_total_ms": 0.0,
	"output_vertices": 0,
	"output_triangles": 0,
	"capsule_operand_request_count": 0,
	"capsule_operand_cache_hit_count": 0,
	"capsule_operand_bake_count": 0,
	"capsule_operand_failure_count": 0,
	"capsule_operand_superseded_count": 0,
	"capsule_operand_pending_count": 0,
	"capsule_operand_cache_count": 0,
	"capsule_operand_last_ready_ms": 0.0,
	"capsule_operand_last_bake_ms": 0.0,
	"protected_composition_mode": "not_attempted",
	"protected_composition_attempt_count": 0,
	"protected_composition_success_count": 0,
	"protected_composition_handle_only_count": 0,
	"protected_composition_csg_fallback_count": 0,
	"protected_composition_last_failure_reason": "",
	"protected_composition_total_ms": 0.0,
	"protected_composition_imports_ms": 0.0,
	"protected_composition_boolean_ms": 0.0,
	"protected_composition_subtract_ms": 0.0,
	"protected_composition_union_ms": 0.0,
	"protected_composition_export_ms": 0.0,
	"protected_composition_output_vertices": 0,
	"protected_composition_output_triangles": 0,
	"protected_composition_ordinary_triangles": 0,
	"protected_composition_protected_triangles": 0,
	"protected_composition_backend_method": "",
	"protected_composition_source_state_revision": -1,
	"protected_composition_subtraction_triangles": 0,
	"protected_handle_cache_signature": "",
	"protected_handle_cache_ready": false,
	"protected_handle_cache_hit_count": 0,
	"protected_handle_cache_miss_count": 0,
	"protected_handle_bootstrap_count": 0,
	"protected_handle_bootstrap_success_count": 0,
	"protected_handle_bootstrap_failure_count": 0,
	"protected_handle_bootstrap_last_failure_reason": "",
	"protected_handle_bootstrap_last_bake_ms": 0.0,
	"protected_handle_bootstrap_pending": false,
	"protected_live_decomposition_attempt_count": 0,
	"protected_live_decomposition_success_count": 0,
	"protected_live_decomposition_last_failure_reason": "",
	"protected_live_backend_method": "",
	"protected_live_source_state_revision": -1,
	"protected_live_clip_total_ms": 0.0,
	"protected_live_clip_imports_ms": 0.0,
	"protected_live_clip_subtract_ms": 0.0,
	"protected_live_clip_export_ms": 0.0,
	"protected_live_lane_array_combine_ms": 0.0,
	"protected_live_material_region_array_mesh_ms": 0.0,
	"protected_live_collision_face_expansion_ms": 0.0,
	"protected_live_collision_set_faces_cook_ms": 0.0,
	"protected_live_node_metadata_setup_ms": 0.0,
	"protected_live_direct_build_total_ms": 0.0,
	"protected_live_clip_vertices": 0,
	"protected_live_clip_triangles": 0,
	"protected_live_clip_ordinary_triangles": 0,
	"protected_live_clip_subtraction_triangles": 0,
	"protected_live_handle_vertices": 0,
	"protected_live_handle_triangles": 0,
	"protected_live_combined_vertices": 0,
	"protected_live_combined_triangles": 0,
	"protected_live_lane_count": 0,
	"protected_live_unfused_geometry": false,
	"protected_live_handle_packet_reused": false,
	"protected_live_combined_collision": false,
	"protected_live_final_union_performed": false,
	"protected_live_final_compose_method": "",
	"protected_live_full_compose_available": false,
	"history_window_enabled": false,
	"history_window_capacity": 0,
	"checkpoint_operation_count": 0,
	"checkpoint_materialization_attempt_count": 0,
	"checkpoint_materialization_count": 0,
	"promotion_count": 0,
	"boolean_count": 0,
	"export_count": 0,
	"retained_state_count": 0,
	"retained_total_vertices": 0,
	"retained_total_triangles": 0,
	"active_tail_cursor": 0,
	"tail_timeline_count": 0,
	"redo_count": 0,
}

func _ready() -> void:
	_ensure_preview_mesh_instance()
	_ensure_spline_preview_mesh_instance()
	_ensure_spline_invalid_preview_mesh_instance()
	_ensure_spline_csg_nodes()
	_ensure_active_material_body_preview_mesh_instance()
	_ensure_csg_material_body_root()
	_ensure_native_capsule_operand_staging_root()
	_ensure_placement_cursor_mesh_instance()

func bind_stage_controller(stage_controller: Node) -> void:
	if active_stage_controller == stage_controller:
		_sync_from_controller()
		return
	var reset_result := _reset_native_static_lane(
		NATIVE_STATIC_LIFECYCLE_UNOBSERVED,
		"stage_controller_changed"
	)
	if not bool(reset_result.get("ok", false)):
		return
	_disconnect_stage_controller()
	_clear_bounded_checkpoint_export_provider()
	_discard_csg_static_zone_cache()
	active_stage_controller = stage_controller
	_connect_stage_controller()
	_sync_from_controller()

func clear_stage_controller() -> bool:
	var reset_result := _reset_native_static_lane(
		NATIVE_STATIC_LIFECYCLE_UNOBSERVED,
		"stage_controller_cleared"
	)
	if not bool(reset_result.get("ok", false)):
		return false
	_disconnect_stage_controller()
	_clear_bounded_checkpoint_export_provider()
	active_stage_controller = null
	_sync_preview_mesh(null)
	_sync_spline_preview_mesh(null)
	_sync_spline_csg_noodle(null)
	_sync_active_material_body_preview_mesh(null)
	_sync_csg_material_body_preview(null)
	_sync_placement_cursor(Vector3.ZERO, false, DEFAULT_PREVIEW_RADIUS_METERS)
	return true

func _connect_stage_controller() -> void:
	if active_stage_controller == null:
		return
	if not active_stage_controller.has_signal("authoring_state_changed"):
		return
	if not active_stage_controller.authoring_state_changed.is_connected(_on_authoring_state_changed):
		active_stage_controller.authoring_state_changed.connect(_on_authoring_state_changed)
	if active_stage_controller.has_signal("material_body_preview_changed"):
		if not active_stage_controller.material_body_preview_changed.is_connected(
			_on_material_body_preview_changed
		):
			active_stage_controller.material_body_preview_changed.connect(
				_on_material_body_preview_changed
			)
	if active_stage_controller.has_signal("placement_cursor_changed"):
		if not active_stage_controller.placement_cursor_changed.is_connected(_on_placement_cursor_changed):
			active_stage_controller.placement_cursor_changed.connect(_on_placement_cursor_changed)
	if active_stage_controller.has_method("get_placement_cursor_state"):
		var cursor_state: Dictionary = active_stage_controller.call("get_placement_cursor_state")
		_sync_placement_cursor(
			cursor_state.get("local_position", Vector3.ZERO) as Vector3,
			bool(cursor_state.get("is_valid", false)),
			float(cursor_state.get("radius_meters", DEFAULT_PREVIEW_RADIUS_METERS))
		)

func _disconnect_stage_controller() -> void:
	if active_stage_controller == null:
		return
	if not active_stage_controller.has_signal("authoring_state_changed"):
		return
	if active_stage_controller.authoring_state_changed.is_connected(_on_authoring_state_changed):
		active_stage_controller.authoring_state_changed.disconnect(_on_authoring_state_changed)
	if active_stage_controller.has_signal("material_body_preview_changed"):
		if active_stage_controller.material_body_preview_changed.is_connected(
			_on_material_body_preview_changed
		):
			active_stage_controller.material_body_preview_changed.disconnect(
				_on_material_body_preview_changed
			)
	if active_stage_controller.has_signal("placement_cursor_changed"):
		if active_stage_controller.placement_cursor_changed.is_connected(_on_placement_cursor_changed):
			active_stage_controller.placement_cursor_changed.disconnect(_on_placement_cursor_changed)

func _on_authoring_state_changed(_state: Resource) -> void:
	_sync_from_controller()

func _on_material_body_preview_changed(state: Resource) -> void:
	_sync_active_material_body_preview_mesh(state)

func _on_placement_cursor_changed(local_position: Vector3, is_valid: bool, radius_meters: float) -> void:
	_sync_placement_cursor(local_position, is_valid, radius_meters)

func _sync_from_controller() -> void:
	if active_stage_controller == null or not active_stage_controller.has_method("get_active_authoring_state"):
		_sync_preview_mesh(null)
		_sync_spline_preview_mesh(null)
		_sync_spline_csg_noodle(null)
		_sync_active_material_body_preview_mesh(null)
		_sync_csg_material_body_preview(null)
		return
	var authoring_state: Resource = active_stage_controller.call("get_active_authoring_state") as Resource
	_sync_preview_mesh(authoring_state)
	_sync_spline_preview_mesh(authoring_state)
	_sync_spline_csg_noodle(authoring_state)
	_sync_active_material_body_preview_mesh(authoring_state)
	_sync_csg_material_body_preview(authoring_state)

func _sync_preview_mesh(authoring_state: Resource) -> void:
	_ensure_preview_mesh_instance()
	if preview_mesh_instance == null:
		return
	if authoring_state == null:
		preview_mesh_instance.visible = false
		preview_mesh_instance.mesh = null
		return
	if _has_csg_material_body_records(authoring_state):
		preview_mesh_instance.visible = false
		preview_mesh_instance.mesh = null
		return
	var active_preview_records: Array = _collect_active_placement_preview_records(authoring_state)
	if not active_preview_records.is_empty():
		var active_preview_mesh: ArrayMesh = _build_preview_mesh(active_preview_records)
		if active_preview_mesh != null and active_preview_mesh.get_surface_count() > 0:
			preview_mesh_instance.mesh = active_preview_mesh
			preview_mesh_instance.material_override = _build_preview_material()
			preview_mesh_instance.visible = true
			return
	var volume_records: Array = authoring_state.get("material_bodies")
	var preview_mesh: ArrayMesh = _build_preview_mesh(volume_records)
	if preview_mesh == null or preview_mesh.get_surface_count() <= 0:
		preview_mesh_instance.visible = false
		preview_mesh_instance.mesh = null
		return
	preview_mesh_instance.mesh = preview_mesh
	preview_mesh_instance.material_override = _build_preview_material()
	preview_mesh_instance.visible = true

func _sync_spline_preview_mesh(authoring_state: Resource) -> void:
	_ensure_spline_preview_mesh_instance()
	_ensure_spline_invalid_preview_mesh_instance()
	if (
		spline_preview_mesh_instance == null
		or spline_invalid_preview_mesh_instance == null
	):
		return
	if authoring_state == null:
		_clear_spline_preview_meshes()
		return
	var spline_points: PackedVector3Array = authoring_state.get("spline_line_points")
	var selected_point_index: int = int(authoring_state.get("selected_spline_point_index"))
	var spline_finished: bool = bool(authoring_state.get("spline_line_finished"))
	var detailing_summary: Dictionary = {}
	if authoring_state.has_method("get_detailing_brush_summary"):
		detailing_summary = authoring_state.call(
			"get_detailing_brush_summary"
		) as Dictionary
	if (
		bool(detailing_summary.get("active", false))
		or StringName(authoring_state.get("active_tool_id"))
		== DETAILING_BRUSH_TOOL_ID
	):
		var detail_meshes := _build_detailing_spline_preview_meshes(
			detailing_summary.get(
				"control_points",
				spline_points
			) as PackedVector3Array,
			detailing_summary.get(
				"resolved_path_points",
				authoring_state.get("detailing_resolved_path_points")
			) as PackedVector3Array,
			detailing_summary.get(
				"span_offsets",
				authoring_state.get("detailing_span_offsets")
			) as PackedInt32Array,
			detailing_summary.get(
				"span_validity",
				authoring_state.get("detailing_span_validity")
			) as Array,
			selected_point_index,
			bool(detailing_summary.get("finished", spline_finished)),
			bool(detailing_summary.get(
				"valid",
				authoring_state.get("detailing_solution_valid")
			))
		)
		_apply_detailing_spline_preview_meshes(detail_meshes)
		return
	_clear_detailing_spline_preview_metadata()
	var handle_span_invalid := _is_handle_span_preview_invalid(
		authoring_state,
		spline_points
	)
	if handle_span_invalid:
		var point_marker_mesh: ArrayMesh = _build_spline_preview_mesh(
			spline_points,
			selected_point_index,
			spline_finished,
			false,
			true,
			false
		)
		var invalid_line_mesh: ArrayMesh = _build_spline_preview_mesh(
			spline_points,
			selected_point_index,
			spline_finished,
			true,
			false,
			true
		)
		spline_preview_mesh_instance.mesh = point_marker_mesh
		spline_preview_mesh_instance.material_override = (
			_build_spline_preview_material()
		)
		spline_preview_mesh_instance.visible = (
			point_marker_mesh != null
			and point_marker_mesh.get_surface_count() > 0
		)
		spline_invalid_preview_mesh_instance.mesh = invalid_line_mesh
		spline_invalid_preview_mesh_instance.material_override = (
			_build_spline_invalid_preview_material()
		)
		spline_invalid_preview_mesh_instance.visible = (
			invalid_line_mesh != null
			and invalid_line_mesh.get_surface_count() > 0
		)
		return
	spline_invalid_preview_mesh_instance.visible = false
	spline_invalid_preview_mesh_instance.mesh = null
	var spline_mesh: ArrayMesh = _build_spline_preview_mesh(spline_points, selected_point_index, spline_finished)
	if spline_mesh == null or spline_mesh.get_surface_count() <= 0:
		spline_preview_mesh_instance.visible = false
		spline_preview_mesh_instance.mesh = null
		return
	spline_preview_mesh_instance.mesh = spline_mesh
	spline_preview_mesh_instance.material_override = _build_spline_preview_material()
	spline_preview_mesh_instance.visible = true

func _is_handle_span_preview_invalid(
	authoring_state: Resource,
	spline_points: PackedVector3Array
) -> bool:
	if (
		authoring_state == null
		or StringName(authoring_state.get("active_tool_id")) != HANDLE_TOOL_ID
		or spline_points.size() != 3
		or not authoring_state.has_method(
			"can_generate_profile_extrusion_from_spline"
		)
	):
		return false
	return not bool(authoring_state.call(
		"can_generate_profile_extrusion_from_spline"
	))

func _apply_detailing_spline_preview_meshes(detail_meshes: Dictionary) -> void:
	var normal_mesh: ArrayMesh = detail_meshes.get(
		"normal_mesh",
		ArrayMesh.new()
	) as ArrayMesh
	var invalid_mesh: ArrayMesh = detail_meshes.get(
		"invalid_mesh",
		ArrayMesh.new()
	) as ArrayMesh
	spline_preview_mesh_instance.mesh = normal_mesh
	spline_preview_mesh_instance.material_override = _build_spline_preview_material()
	spline_preview_mesh_instance.visible = (
		normal_mesh != null and normal_mesh.get_surface_count() > 0
	)
	spline_invalid_preview_mesh_instance.mesh = invalid_mesh
	spline_invalid_preview_mesh_instance.material_override = (
		_build_spline_invalid_preview_material()
	)
	spline_invalid_preview_mesh_instance.visible = (
		invalid_mesh != null and invalid_mesh.get_surface_count() > 0
	)
	for mesh_instance: MeshInstance3D in [
		spline_preview_mesh_instance,
		spline_invalid_preview_mesh_instance,
	]:
		mesh_instance.set_meta(
			"forge_v2_detail_control_points",
			detail_meshes.get(
				"control_points",
				PackedVector3Array()
			)
		)
		mesh_instance.set_meta(
			"forge_v2_detail_resolved_points",
			detail_meshes.get(
				"resolved_points",
				PackedVector3Array()
			)
		)
		mesh_instance.set_meta(
			"forge_v2_detail_span_offsets",
			detail_meshes.get(
				"span_offsets",
				PackedInt32Array()
			)
		)
		mesh_instance.set_meta(
			"forge_v2_detail_span_validity",
			detail_meshes.get("span_validity", [])
		)
		mesh_instance.set_meta(
			"forge_v2_detail_solution_valid",
			bool(detail_meshes.get("solution_valid", false))
		)

func _clear_spline_preview_meshes() -> void:
	for mesh_instance: MeshInstance3D in [
		spline_preview_mesh_instance,
		spline_invalid_preview_mesh_instance,
	]:
		if mesh_instance == null:
			continue
		mesh_instance.visible = false
		mesh_instance.mesh = null
	_clear_detailing_spline_preview_metadata()

func _clear_detailing_spline_preview_metadata() -> void:
	for mesh_instance: MeshInstance3D in [
		spline_preview_mesh_instance,
		spline_invalid_preview_mesh_instance,
	]:
		if mesh_instance == null:
			continue
		for metadata_name: StringName in [
			&"forge_v2_detail_control_points",
			&"forge_v2_detail_resolved_points",
			&"forge_v2_detail_span_offsets",
			&"forge_v2_detail_span_validity",
			&"forge_v2_detail_solution_valid",
		]:
			if mesh_instance.has_meta(metadata_name):
				mesh_instance.remove_meta(metadata_name)

func _sync_spline_csg_noodle(authoring_state: Resource) -> void:
	_ensure_spline_csg_nodes()
	if spline_csg_path == null or spline_csg_polygon == null:
		return
	if (
		authoring_state == null
		or StringName(authoring_state.get("active_tool_id"))
		== DETAILING_BRUSH_TOOL_ID
		or not bool(authoring_state.get("spline_line_csg_noodle_enabled"))
	):
		spline_csg_polygon.visible = false
		spline_csg_path.curve = null
		return
	var spline_points: PackedVector3Array = authoring_state.get("spline_line_points")
	if spline_points.size() < 2:
		spline_csg_polygon.visible = false
		spline_csg_path.curve = null
		return
	var radius_meters: float = maxf(float(authoring_state.get("active_brush_radius_meters")), 0.001)
	var path_interval_meters := _resolve_spline_csg_path_interval(radius_meters)
	spline_csg_path.curve = _build_spline_csg_curve(spline_points, path_interval_meters)
	spline_csg_polygon.mode = CSGPolygon3D.MODE_PATH
	spline_csg_polygon.path_node = spline_csg_polygon.get_path_to(spline_csg_path)
	spline_csg_polygon.path_interval_type = CSGPolygon3D.PATH_INTERVAL_DISTANCE
	spline_csg_polygon.path_interval = path_interval_meters
	spline_csg_polygon.path_rotation = CSGPolygon3D.PATH_ROTATION_PATH_FOLLOW
	spline_csg_polygon.path_rotation_accurate = true
	spline_csg_polygon.path_continuous_u = true
	spline_csg_polygon.path_u_distance = 0.0
	spline_csg_polygon.smooth_faces = true
	spline_csg_polygon.polygon = _build_circle_profile_polygon(radius_meters, SPLINE_CSG_CIRCLE_SIDES)
	spline_csg_polygon.material = _build_spline_csg_material(StringName(authoring_state.get("active_material_variant_id")))
	spline_csg_polygon.visible = true

func _sync_active_material_body_preview_mesh(authoring_state: Resource) -> void:
	_ensure_active_material_body_preview_mesh_instance()
	if active_material_body_preview_mesh_instance == null:
		return
	var active_body := _find_active_material_body(authoring_state)
	if active_body == null:
		active_material_body_preview_mesh_instance.mesh = null
		active_material_body_preview_mesh_instance.visible = false
		_clear_active_material_body_preview_metadata()
		return
	var active_mesh := _build_active_material_body_sweep_mesh(active_body)
	if active_mesh == null or active_mesh.get_surface_count() <= 0:
		active_material_body_preview_mesh_instance.mesh = null
		active_material_body_preview_mesh_instance.visible = false
		_clear_active_material_body_preview_metadata()
		return
	var operation_mode := (
		ForgeV2MaterialCompositionPolicyScript.resolve_effective_operation_mode(
			active_body
		)
	)
	active_material_body_preview_mesh_instance.mesh = active_mesh
	active_material_body_preview_mesh_instance.material_override = (
		_build_active_material_body_preview_material(
			operation_mode
			== ForgeV2VolumeStrokeScript.OPERATION_REMOVE_MATERIAL
		)
	)
	active_material_body_preview_mesh_instance.visible = true
	active_material_body_preview_mesh_instance.set_meta(
		"forge_v2_active_body_id",
		StringName(active_body.get("body_id"))
	)
	active_material_body_preview_mesh_instance.set_meta(
		"forge_v2_profile_vertex_count",
		_resolve_active_body_sweep_polygon(active_body).size()
	)
	active_material_body_preview_mesh_instance.set_meta(
		"forge_v2_path_point_count",
		(active_body.get("path_points") as PackedVector3Array).size()
	)
	active_material_body_preview_mesh_instance.set_meta(
		"forge_v2_path_surface_normal_count",
		(active_body.get("path_surface_normals") as PackedVector3Array).size()
	)
	active_material_body_preview_mesh_instance.set_meta(
		"forge_v2_path_contact_direction_count",
		(active_body.get("path_contact_directions") as PackedVector3Array).size()
	)
	active_material_body_preview_mesh_instance.set_meta(
		"forge_v2_profile_rotation_bias_degrees",
		float(active_body.get("profile_rotation_bias_degrees"))
	)

func _sync_csg_material_body_preview(authoring_state: Resource) -> void:
	_ensure_csg_material_body_root()
	if csg_material_body_root == null:
		return
	if authoring_state == null:
		if _clear_csg_material_body_root():
			csg_material_body_root.visible = false
		return
	var material_bodies: Array = _collect_active_csg_material_bodies(
		authoring_state
	)
	var active_body_id := _get_active_placement_body_id()
	var active_body_index := _find_body_index_by_id(
		material_bodies,
		active_body_id
	)
	var static_bodies: Array = []
	var pending_preview_bodies: Array = []
	for body_variant: Variant in material_bodies:
		if not body_variant is Resource:
			continue
		var body := body_variant as Resource
		if (
			active_body_id != StringName()
			and StringName(body.get("body_id")) == active_body_id
		):
			continue
		if _is_pending_user_material_body(body):
			pending_preview_bodies.append(body)
		else:
			static_bodies.append(body)
	if active_body_index < 0 or not csg_static_zones_initialized:
		_sync_static_csg_zones(static_bodies, authoring_state)
	_prime_authoritative_protected_handle_mesh(material_bodies)
	_apply_static_zone_visibility({})
	_sync_pending_material_body_previews(pending_preview_bodies)
	csg_material_body_root.visible = (
		(csg_static_body_root != null and csg_static_body_root.visible)
		or (native_static_body_root != null and native_static_body_root.visible)
		or (csg_active_body_root != null and csg_active_body_root.visible)
	)

func _sync_static_csg_zones(
	static_bodies: Array,
	authoring_state: Resource = null
) -> void:
	if csg_static_body_root == null:
		return
	var bounded_sync_result := _try_sync_bounded_native_static_fast_lane(
		authoring_state
	)
	if bool(bounded_sync_result.get("available", false)):
		if bool(bounded_sync_result.get("handled", false)):
			csg_static_zones_initialized = true
			if native_static_authoritative:
				csg_static_body_root.visible = false
			return
		var bounded_descriptor: Dictionary = bounded_sync_result.get(
			"presentation_descriptor",
			{}
		) as Dictionary
		if _sync_bounded_checkpoint_csg_fallback(bounded_descriptor):
			csg_static_zones_initialized = true
			_begin_native_static_fallback_retirement()
			return
		if _resolve_bounded_checkpoint_operation_count(
			bounded_descriptor
		) > 0:
			# A legacy body-only rebuild would silently drop the accumulated S0.
			# Keep the last exact publication visible when recovery cannot be built.
			csg_static_zones_initialized = true
			return
	var force_full_rebuild := false
	if static_bodies.is_empty():
		_arm_native_static_lane_from_empty()
	else:
		var native_sync_result := _try_sync_native_static_fast_lane(
			static_bodies
		)
		if bool(native_sync_result.get("handled", false)):
			csg_static_zones_initialized = true
			if native_static_authoritative:
				csg_static_body_root.visible = false
			return
		force_full_rebuild = bool(native_sync_result.get(
			"force_full_csg",
			false
		))
	if force_full_rebuild:
		_discard_csg_static_zone_cache()
	var had_initialized := csg_static_zones_initialized
	csg_static_zones_initialized = true
	if (
		not force_full_rebuild
		and had_initialized
		and _static_body_snapshot_matches(static_bodies)
	):
		csg_static_sync_diagnostics["last_mode"] = "no_op"
		csg_static_sync_diagnostics["no_op_count"] = int(
			csg_static_sync_diagnostics.get("no_op_count", 0)
		) + 1
		csg_static_sync_diagnostics["last_fallback_reason"] = ""
		return
	if had_initialized and not force_full_rebuild:
		var incremental_result := _try_incremental_static_zone_append(
			static_bodies
		)
		if bool(incremental_result.get("ok", false)):
			_capture_static_body_snapshot(static_bodies)
			csg_static_sync_diagnostics["last_mode"] = (
				"incremental_append"
			)
			csg_static_sync_diagnostics["incremental_append_count"] = int(
				csg_static_sync_diagnostics.get(
					"incremental_append_count",
					0
				)
			) + 1
			csg_static_sync_diagnostics["last_appended_body_id"] = (
				StringName(incremental_result.get(
					"appended_body_id",
					StringName()
				))
			)
			csg_static_sync_diagnostics["last_fallback_reason"] = ""
			return
		csg_static_sync_diagnostics["last_fallback_reason"] = String(
			incremental_result.get("reason", "incremental_append_rejected")
		)
	csg_static_sync_diagnostics["last_mode"] = "full_rebuild"
	csg_static_target_metadata_generation += 1
	csg_static_sync_diagnostics["full_rebuild_count"] = int(
		csg_static_sync_diagnostics.get("full_rebuild_count", 0)
	) + 1
	csg_static_sync_diagnostics["last_appended_body_id"] = StringName()
	var zones: Array = _build_csg_body_zones(static_bodies)
	var next_zone_keys: Dictionary = {}
	csg_static_zone_body_ids_by_key = {}
	csg_static_body_zone_key_by_id = {}
	for zone_variant: Variant in zones:
		if not (zone_variant is Dictionary):
			continue
		var zone: Dictionary = zone_variant as Dictionary
		var zone_key: String = String(zone.get("zone_key", ""))
		if zone_key.is_empty():
			continue
		next_zone_keys[zone_key] = true
		var primary_body_ids: Array = zone.get("primary_body_ids", []) as Array
		csg_static_zone_body_ids_by_key[zone_key] = primary_body_ids
		for body_id_variant: Variant in primary_body_ids:
			csg_static_body_zone_key_by_id[StringName(body_id_variant)] = zone_key
		var zone_signature: String = String(zone.get("signature", ""))
		var zone_node: Node = csg_static_zone_nodes.get(zone_key, null) as Node
		if (
			zone_node == null
			or not is_instance_valid(zone_node)
			or String(csg_static_zone_signatures.get(zone_key, "")) != zone_signature
		):
			if zone_node != null and is_instance_valid(zone_node):
				csg_static_body_root.remove_child(zone_node)
				zone_node.free()
			zone_node = _build_csg_zone_node(zone, true, "StaticZone")
			csg_static_body_root.add_child(zone_node)
			csg_static_zone_nodes[zone_key] = zone_node
			csg_static_zone_signatures[zone_key] = zone_signature
	var stale_zone_keys: Array = csg_static_zone_nodes.keys()
	for stale_key_variant: Variant in stale_zone_keys:
		var stale_key := String(stale_key_variant)
		if next_zone_keys.has(stale_key):
			continue
		var stale_node: Node = csg_static_zone_nodes.get(stale_key, null) as Node
		if stale_node != null and is_instance_valid(stale_node):
			csg_static_body_root.remove_child(stale_node)
			stale_node.free()
		csg_static_zone_nodes.erase(stale_key)
		csg_static_zone_signatures.erase(stale_key)
	csg_static_body_root.visible = not zones.is_empty()
	_capture_static_body_snapshot(static_bodies)
	if force_full_rebuild:
		_begin_native_static_fallback_retirement()


func _static_body_snapshot_matches(static_bodies: Array) -> bool:
	if static_bodies.size() != csg_static_body_order_snapshot.size():
		return false
	for body_index in range(static_bodies.size()):
		var body: Resource = static_bodies[body_index] as Resource
		if body == null:
			return false
		var body_id := StringName(body.get("body_id"))
		if body_id != csg_static_body_order_snapshot[body_index]:
			return false
		if String(csg_static_body_signatures_by_id.get(body_id, "")) != _build_csg_body_signature(body):
			return false
	return true


func _capture_static_body_snapshot(static_bodies: Array) -> void:
	csg_static_body_order_snapshot = []
	csg_static_body_signatures_by_id = {}
	for body_variant: Variant in static_bodies:
		if not (body_variant is Resource):
			continue
		var body := body_variant as Resource
		if body == null:
			continue
		var body_id := StringName(body.get("body_id"))
		csg_static_body_order_snapshot.append(body_id)
		csg_static_body_signatures_by_id[body_id] = _build_csg_body_signature(body)


func _try_incremental_static_zone_append(static_bodies: Array) -> Dictionary:
	if static_bodies.size() != csg_static_body_order_snapshot.size() + 1:
		return {"ok": false, "reason": "not_single_append"}
	if not _can_skip_all_csg_clip_discovery(static_bodies):
		return {"ok": false, "reason": "complex_composition"}
	for body_index in range(csg_static_body_order_snapshot.size()):
		var prior_body: Resource = static_bodies[body_index] as Resource
		if prior_body == null:
			return {"ok": false, "reason": "missing_prefix_body"}
		var prior_body_id := StringName(prior_body.get("body_id"))
		if prior_body_id != csg_static_body_order_snapshot[body_index]:
			return {"ok": false, "reason": "body_order_not_append_only"}
		if String(csg_static_body_signatures_by_id.get(prior_body_id, "")) != _build_csg_body_signature(prior_body):
			return {"ok": false, "reason": "prefix_body_changed"}
	var new_body: Resource = static_bodies[static_bodies.size() - 1] as Resource
	if new_body == null:
		return {"ok": false, "reason": "new_body_missing"}
	var new_body_id := StringName(new_body.get("body_id"))
	if new_body_id == StringName() or csg_static_body_signatures_by_id.has(new_body_id):
		return {"ok": false, "reason": "new_body_id_invalid_or_reused"}
	var new_material_id := StringName(new_body.get("material_variant_id"))
	var new_bounds := _build_csg_body_bounds(new_body)
	var intersected_zone_keys: Dictionary = {}
	for body_index in range(static_bodies.size() - 1):
		var old_body: Resource = static_bodies[body_index] as Resource
		if old_body == null or StringName(old_body.get("material_variant_id")) != new_material_id:
			continue
		if not _csg_body_bounds_intersect(new_bounds, _build_csg_body_bounds(old_body)):
			continue
		var old_body_id := StringName(old_body.get("body_id"))
		var old_body_zone_key := String(csg_static_body_zone_key_by_id.get(old_body_id, ""))
		if old_body_zone_key.is_empty():
			return {"ok": false, "reason": "intersected_body_without_zone"}
		intersected_zone_keys[old_body_zone_key] = true
	if intersected_zone_keys.size() != 1:
		return {
			"ok": false,
			"reason": "requires_exactly_one_existing_zone",
		}
	var old_zone_key := String(intersected_zone_keys.keys()[0])
	var old_zone_node := csg_static_zone_nodes.get(old_zone_key, null) as CSGCombiner3D
	if old_zone_node == null or not is_instance_valid(old_zone_node):
		return {"ok": false, "reason": "existing_zone_node_missing"}
	var old_primary_body_ids: Array = csg_static_zone_body_ids_by_key.get(old_zone_key, []) as Array
	if old_primary_body_ids.is_empty() or old_zone_node.get_child_count() != old_primary_body_ids.size():
		return {"ok": false, "reason": "existing_zone_shape_count_mismatch"}
	var new_primary_body_ids: Array[StringName] = []
	for body_id_variant: Variant in old_primary_body_ids:
		var body_id := StringName(body_id_variant)
		if body_id == new_body_id:
			return {"ok": false, "reason": "new_body_already_in_zone"}
		new_primary_body_ids.append(body_id)
	new_primary_body_ids.append(new_body_id)
	new_primary_body_ids.sort()
	var id_parts := PackedStringArray()
	for body_id: StringName in new_primary_body_ids:
		id_parts.append(String(body_id))
	var new_zone_key := "%s:%s" % [String(new_material_id), ",".join(id_parts)]
	var old_signature := String(csg_static_zone_signatures.get(old_zone_key, ""))
	if old_signature.is_empty():
		return {"ok": false, "reason": "existing_zone_signature_missing"}
	if not _append_csg_clipped_body_shape(
		old_zone_node,
		new_body,
		[],
		new_material_id,
		old_zone_node.get_child_count(),
		false
	):
		return {"ok": false, "reason": "new_body_shape_append_failed"}
	var new_signature := old_signature + "\n%s clips[]" % _build_csg_body_signature(new_body)
	var new_surface_target_id := _build_zone_surface_target_id(new_zone_key)
	old_zone_node.name = "StaticZone_%s" % new_zone_key
	# Keep the old target identity on the still-published collision until Godot's
	# deferred CSG rebuild and its physics publication have both had a frame.
	# Updating the metadata synchronously would make the old collision look like
	# the new revision and could let a raycast report a false-ready surface.
	csg_static_target_metadata_generation += 1
	var target_metadata_generation := csg_static_target_metadata_generation
	old_zone_node.collision_layer = 0
	old_zone_node.set_meta("forge_v2_publication_pending", true)
	_publish_incremental_zone_target_metadata_after_update(
		old_zone_node,
		_resolve_zone_collision_body_id(new_primary_body_ids),
		new_surface_target_id,
		target_metadata_generation
	)
	csg_static_zone_nodes.erase(old_zone_key)
	csg_static_zone_signatures.erase(old_zone_key)
	csg_static_zone_body_ids_by_key.erase(old_zone_key)
	csg_static_zone_nodes[new_zone_key] = old_zone_node
	csg_static_zone_signatures[new_zone_key] = new_signature
	csg_static_zone_body_ids_by_key[new_zone_key] = new_primary_body_ids
	for body_id: StringName in new_primary_body_ids:
		csg_static_body_zone_key_by_id[body_id] = new_zone_key
	csg_static_body_root.visible = true
	return {
		"ok": true,
		"appended_body_id": new_body_id,
		"old_zone_key": old_zone_key,
		"new_zone_key": new_zone_key,
	}


func _publish_incremental_zone_target_metadata_after_update(
	zone_node: CSGCombiner3D,
	body_id: StringName,
	surface_target_id: StringName,
	generation: int
) -> void:
	await get_tree().process_frame
	await get_tree().physics_frame
	if (
		generation != csg_static_target_metadata_generation
		or zone_node == null
		or not is_instance_valid(zone_node)
	):
		return
	zone_node.set_meta("forge_v2_body_id", body_id)
	zone_node.set_meta("forge_v2_surface_target_id", surface_target_id)
	zone_node.set_meta("forge_v2_publication_pending", false)
	zone_node.collision_layer = MATERIAL_SURFACE_COLLISION_LAYER


func get_csg_static_sync_diagnostics() -> Dictionary:
	return csg_static_sync_diagnostics.duplicate(true)


func get_native_static_sync_diagnostics() -> Dictionary:
	_refresh_native_static_diagnostics()
	return native_static_sync_diagnostics.duplicate(true)


func _arm_native_static_lane_from_empty() -> void:
	if (
		native_static_lifecycle == NATIVE_STATIC_LIFECYCLE_ARMED_EMPTY
		and native_static_body_order_snapshot.is_empty()
		and not native_static_authoritative
		and not native_static_publication_pending
	):
		return
	var reset_result := _reset_native_static_lane(
		NATIVE_STATIC_LIFECYCLE_ARMED_EMPTY,
		""
	)
	if not bool(reset_result.get("ok", false)):
		return
	native_static_sync_diagnostics["last_mode"] = "armed_empty"
	native_static_sync_diagnostics["last_failure_reason"] = ""
	_refresh_native_static_diagnostics()


func _try_sync_bounded_native_static_fast_lane(
	authoring_state: Resource
) -> Dictionary:
	if (
		authoring_state == null
		or not authoring_state.has_method("get_bounded_history_transition")
		or not authoring_state.has_method(
			"get_bounded_presentation_descriptor"
		)
	):
		return {"available": false}
	var transition := authoring_state.call(
		"get_bounded_history_transition"
	) as Dictionary
	var presentation := authoring_state.call(
		"get_bounded_presentation_descriptor"
	) as Dictionary
	if transition.is_empty() or presentation.is_empty():
		return {"available": false}
	var state_instance_id := int(authoring_state.get_instance_id())
	var state_replaced := (
		native_static_bound_state_instance_id != state_instance_id
	)
	if state_replaced:
		if (
			_resolve_bounded_checkpoint_operation_count(presentation) > 0
			and not bool(presentation.get(
				"checkpoint_restore_ready",
				false
			))
		):
			_mark_bounded_checkpoint_recovery_blocked(
				authoring_state,
				&"replacement_state_checkpoint_not_restore_ready"
			)
			native_static_sync_diagnostics["last_mode"] = (
				"checkpoint_recovery_blocked"
			)
			native_static_sync_diagnostics["last_failure_reason"] = (
				"replacement_state_checkpoint_not_restore_ready"
			)
			_refresh_native_static_diagnostics()
			return {
				"available": true,
				"handled": true,
				"recovery_blocked": true,
				"presentation_descriptor": presentation,
			}
		var replacement_reset := _reset_native_static_lane(
			NATIVE_STATIC_LIFECYCLE_ARMED_EMPTY,
			"bounded_state_replaced"
		)
		if not bool(replacement_reset.get("ok", false)):
			return {
				"available": true,
				"handled": true,
				"recovery_blocked": true,
				"presentation_descriptor": presentation,
			}
		_clear_bounded_checkpoint_export_provider()
		native_static_bound_state_instance_id = state_instance_id
		native_static_bound_authoring_state = authoring_state
		native_static_consumed_transition_revision = -1
		native_static_deferred_transition_revision = -1
		native_static_bounded_resync_required = false
	_install_bounded_checkpoint_export_provider(authoring_state)
	var transition_revision := int(transition.get("revision", -1))
	if (
		native_static_deferred_transition_revision >= 0
		and transition_revision
		!= native_static_deferred_transition_revision
	):
		# A newer authoring transition superseded an operand bake before the
		# prior delta reached the backend.  Deltas and cursor moves are no longer
		# safe against that stale prefix; rebuild the bounded checkpoint + tail.
		if not native_static_bounded_resync_required:
			native_static_bounded_resync_required = true
			native_static_sync_diagnostics[
				"capsule_operand_superseded_count"
			] = int(native_static_sync_diagnostics.get(
				"capsule_operand_superseded_count",
				0
			)) + 1
	if (
		not state_replaced
		and transition_revision >= 0
		and transition_revision
		== native_static_consumed_transition_revision
		and (
			native_static_lifecycle == NATIVE_STATIC_LIFECYCLE_ACTIVE
			or native_static_lifecycle
			== NATIVE_STATIC_LIFECYCLE_ARMED_EMPTY
		)
	):
		return {
			"available": true,
			"handled": true,
			"presentation_descriptor": presentation,
		}
	var protected_validation := _validate_bounded_protected_handle_lane(
		presentation,
		transition
	)
	if not bool(protected_validation.get("ok", false)):
		return _reject_bounded_native_fast_lane(
			authoring_state,
			transition,
			String(protected_validation.get(
				"reason",
				"protected_geometry_ineligible"
			))
		)
	var transition_kind := StringName(transition.get("kind", StringName()))
	var sync_result: Dictionary
	if native_static_bounded_resync_required:
		sync_result = _restore_bounded_native_static_lane(
			authoring_state,
			transition,
			presentation
		)
	else:
		match transition_kind:
			&"reset", &"append", &"promotion_append":
				if (
					not state_replaced
					and (
						native_static_lifecycle
						== NATIVE_STATIC_LIFECYCLE_ACTIVE
						or native_static_lifecycle
						== NATIVE_STATIC_LIFECYCLE_ARMED_EMPTY
					)
				):
					sync_result = _apply_bounded_native_append(
						authoring_state,
						transition,
						presentation
					)
				else:
					sync_result = _restore_bounded_native_static_lane(
						authoring_state,
						transition,
						presentation
					)
			&"undo", &"redo":
				if (
					not state_replaced
					and native_static_lifecycle
					== NATIVE_STATIC_LIFECYCLE_ACTIVE
				):
					sync_result = _apply_bounded_native_cursor_move(
						authoring_state,
						transition,
						presentation,
						transition_kind
					)
				else:
					sync_result = _restore_bounded_native_static_lane(
						authoring_state,
						transition,
						presentation
					)
			&"protected_changed":
				if not state_replaced:
					sync_result = _apply_bounded_protected_handle_change(
						authoring_state,
						transition,
						presentation
					)
				else:
					sync_result = _restore_bounded_native_static_lane(
						authoring_state,
						transition,
						presentation
					)
			_:
				sync_result = _restore_bounded_native_static_lane(
					authoring_state,
					transition,
					presentation
				)
	sync_result["available"] = true
	if bool(sync_result.get("operand_pending", false)):
		# The exact Godot CSG operand is baking for one rendered frame.  Keep
		# the transition retryable: it must not be consumed or acknowledged.
		if native_static_deferred_transition_revision < 0:
			native_static_deferred_transition_revision = transition_revision
		elif (
			transition_revision
			!= native_static_deferred_transition_revision
		):
			native_static_bounded_resync_required = true
		sync_result["handled"] = true
		sync_result["presentation_descriptor"] = presentation
		return sync_result
	if bool(sync_result.get("handled", false)):
		if not bool(sync_result.get("recovery_blocked", false)):
			native_static_deferred_transition_revision = -1
			native_static_bounded_resync_required = false
		native_static_consumed_transition_revision = transition_revision
		var current_presentation := authoring_state.call(
			"get_bounded_presentation_descriptor"
		) as Dictionary
		sync_result["presentation_descriptor"] = current_presentation
	elif not sync_result.has("presentation_descriptor"):
		sync_result["presentation_descriptor"] = authoring_state.call(
			"get_bounded_presentation_descriptor"
		) as Dictionary
	return sync_result


func _validate_bounded_protected_handle_lane(
	presentation: Dictionary,
	transition: Dictionary
) -> Dictionary:
	var protected_bodies: Array = presentation.get(
		"protected_bodies",
		[]
	) as Array
	var protected_layers: Array = presentation.get(
		"protected_layers",
		[]
	) as Array
	if (
		int(presentation.get(
			"protected_body_count",
			protected_bodies.size()
		)) != protected_bodies.size()
		or protected_bodies.size() > 1
		or protected_layers.size() > 1
	):
		return {
			"ok": false,
			"reason": "native_lane_requires_zero_or_one_protected_handle",
		}
	var transition_protected_bodies: Array = transition.get(
		"protected_bodies",
		protected_bodies
	) as Array
	if transition_protected_bodies.size() != protected_bodies.size():
		return {
			"ok": false,
			"reason": "protected_handle_transition_snapshot_mismatch",
		}
	if protected_bodies.is_empty():
		return {"ok": true, "protected_handle": null}
	var protected_handle := protected_bodies[0] as Resource
	if (
		protected_handle == null
		or not ForgeV2MaterialCompositionPolicyScript.is_protected_handle_entry(
			protected_handle
		)
		or StringName(protected_handle.get("body_id")) == StringName()
		or StringName(protected_handle.get("material_variant_id"))
		== StringName()
		or not bool(protected_handle.get("layer_active"))
	):
		return {
			"ok": false,
			"reason": "protected_geometry_is_not_one_normal_active_handle",
		}
	var path_points: PackedVector3Array = protected_handle.get("path_points")
	if path_points.is_empty():
		return {"ok": false, "reason": "protected_handle_path_empty"}
	return {"ok": true, "protected_handle": protected_handle}


func _reject_bounded_native_fast_lane(
	authoring_state: Resource,
	transition: Dictionary,
	reason: String
) -> Dictionary:
	var materialization := (
		_materialize_bounded_checkpoint_before_native_reset(
			authoring_state
		)
	)
	if not bool(materialization.get("ok", false)):
		_mark_bounded_checkpoint_recovery_blocked(
			authoring_state,
			&"checkpoint_export_before_native_rejection_failed"
		)
		native_static_sync_diagnostics["last_mode"] = (
			"checkpoint_recovery_blocked"
		)
		native_static_sync_diagnostics["last_failure_reason"] = (
			"%s:%s" % [
				reason,
				String(materialization.get(
					"reason",
					"checkpoint_materialization_failed"
				)),
			]
		)
		_refresh_native_static_diagnostics()
		return {
			"available": true,
			"handled": true,
			"recovery_blocked": true,
			"presentation_descriptor": materialization.get(
				"presentation_descriptor",
				{}
			) as Dictionary,
		}
	if (
		bool(transition.get("requires_native_ack", false))
		and authoring_state != null
		and authoring_state.has_method(
			"reject_bounded_history_transition"
		)
	):
		authoring_state.call(
			"reject_bounded_history_transition",
			int(transition.get("revision", -1)),
			StringName(reason)
		)
	var rejected := _reject_native_static_fast_lane(reason)
	rejected["available"] = true
	if (
		authoring_state != null
		and authoring_state.has_method(
			"get_bounded_presentation_descriptor"
		)
	):
		rejected["presentation_descriptor"] = authoring_state.call(
			"get_bounded_presentation_descriptor"
		) as Dictionary
	return rejected


func _apply_bounded_native_append(
	authoring_state: Resource,
	transition: Dictionary,
	presentation: Dictionary
) -> Dictionary:
	var appended_body := transition.get("appended_body", null) as Resource
	if appended_body == null:
		return _reject_bounded_native_fast_lane(
			authoring_state,
			transition,
			"bounded_append_body_missing"
		)
	var expected_material_id := _resolve_bounded_material_variant_id(
		presentation
	)
	var body_validation := _validate_native_static_body(
		appended_body,
		expected_material_id
	)
	if not bool(body_validation.get("ok", false)):
		return _reject_bounded_native_fast_lane(
			authoring_state,
			transition,
			String(body_validation.get(
				"reason",
				"bounded_append_body_ineligible"
			))
		)
	var backend_result := _ensure_native_static_backend()
	if not bool(backend_result.get("ok", false)):
		return _reject_bounded_native_fast_lane(
			authoring_state,
			transition,
			String(backend_result.get(
				"reason",
				"native_backend_unavailable"
			))
		)
	var operand_packet := _build_native_static_operand_packet(appended_body)
	if not bool(operand_packet.get("ok", false)):
		if bool(operand_packet.get("pending", false)):
			return _defer_native_operand_sync(
				presentation,
				String(operand_packet.get(
					"reason",
					"bounded_append_operand_pending"
				))
			)
		return _reject_bounded_native_fast_lane(
			authoring_state,
			transition,
			String(operand_packet.get(
				"reason",
				"bounded_append_operand_invalid"
			))
		)
	var state_info := native_static_manifold_backend.call(
		"get_state_info"
	) as Dictionary
	if (
		not bool(state_info.get("ok", false))
		or int(state_info.get("revision", -1))
		!= native_static_expected_revision
	):
		return _reject_bounded_native_fast_lane(
			authoring_state,
			transition,
			"bounded_append_native_state_mismatch"
		)
	var active_tail_bodies: Array = presentation.get(
		"active_tail_bodies",
		[]
	) as Array
	var checkpoint_count := _resolve_bounded_checkpoint_operation_count(
		presentation
	)
	var use_reset := (
		not bool(state_info.get("state_initialized", false))
		and checkpoint_count == 0
		and active_tail_bodies.size() == 1
	)
	if (
		native_static_lifecycle == NATIVE_STATIC_LIFECYCLE_ARMED_EMPTY
		and not use_reset
	):
		return _restore_bounded_native_static_lane(
			authoring_state,
			transition,
			presentation
		)
	var native_result: Dictionary
	var mode := "append"
	if use_reset:
		native_result = native_static_manifold_backend.call(
			"reset_mesh",
			operand_packet.get("vertices", PackedVector3Array()),
			operand_packet.get("indices", PackedInt32Array())
		) as Dictionary
		mode = "reset"
	else:
		native_result = native_static_manifold_backend.call(
			"add_mesh",
			operand_packet.get("vertices", PackedVector3Array()),
			operand_packet.get("indices", PackedInt32Array())
		) as Dictionary
		mode = String(transition.get("kind", &"append"))
	if StringName(transition.get("kind", StringName())) == &"promotion_append":
		var expected_checkpoint_count := int(transition.get(
			"expected_checkpoint_operation_count",
			-1
		))
		if (
			not bool(native_result.get("ok", false))
			or int(native_result.get(
				"checkpoint_operation_count",
				-1
			)) != expected_checkpoint_count
		):
			return _reject_bounded_native_fast_lane(
				authoring_state,
				transition,
				"native_checkpoint_promotion_count_mismatch"
			)
	return _accept_bounded_native_result(
		authoring_state,
		transition,
		presentation,
		native_result,
		mode
	)


func _apply_bounded_native_cursor_move(
	authoring_state: Resource,
	transition: Dictionary,
	presentation: Dictionary,
	transition_kind: StringName
) -> Dictionary:
	var runtime_state := _validate_native_static_runtime_state(true)
	if not bool(runtime_state.get("ok", false)):
		return _restore_bounded_native_static_lane(
			authoring_state,
			transition,
			presentation
		)
	var method_name := "undo_state" if transition_kind == &"undo" else "redo_state"
	var native_result := native_static_manifold_backend.call(
		method_name
	) as Dictionary
	return _accept_bounded_native_result(
		authoring_state,
		transition,
		presentation,
		native_result,
		String(transition_kind)
	)


func _apply_bounded_protected_handle_change(
	authoring_state: Resource,
	transition: Dictionary,
	presentation: Dictionary
) -> Dictionary:
	if native_static_state_initialized:
		var runtime_state := _validate_native_static_runtime_state(true)
		if not bool(runtime_state.get("ok", false)):
			return _reject_bounded_native_fast_lane(
				authoring_state,
				transition,
				String(runtime_state.get(
					"reason",
					"protected_change_native_state_invalid"
				))
			)
		if (
			native_static_active_vertices.is_empty()
			or native_static_active_indices.is_empty()
		):
			return _reject_bounded_native_fast_lane(
				authoring_state,
				transition,
				"protected_change_active_packet_missing"
			)
	return _stage_bounded_current_native_packet(
		authoring_state,
		transition,
		presentation,
		"protected_changed"
	)


func _native_checkpoint_export_is_valid(
	checkpoint_export: Dictionary,
	expected_checkpoint_count: int,
	expected_revision: int
) -> bool:
	if (
		not bool(checkpoint_export.get("ok", false))
		or bool(checkpoint_export.get("committed", true))
		or bool(checkpoint_export.get("changed", true))
		or int(checkpoint_export.get("revision", -1))
		!= expected_revision
		or int(checkpoint_export.get(
			"checkpoint_operation_count",
			-1
		)) != expected_checkpoint_count
		or not bool(checkpoint_export.get(
			"checkpoint_initialized",
			false
		))
	):
		return false
	var vertices: PackedVector3Array = checkpoint_export.get(
		"vertices",
		PackedVector3Array()
	)
	var indices: PackedInt32Array = checkpoint_export.get(
		"indices",
		PackedInt32Array()
	)
	return (
		not vertices.is_empty()
		and not indices.is_empty()
		and indices.size() % 3 == 0
	)


func _accept_bounded_native_result(
	authoring_state: Resource,
	transition: Dictionary,
	presentation: Dictionary,
	native_result: Dictionary,
	mode: String
) -> Dictionary:
	var validation := _validate_native_committed_result(
		native_result,
		native_static_expected_revision
	)
	if not bool(validation.get("ok", false)):
		return _reject_bounded_native_fast_lane(
			authoring_state,
			transition,
			"native_%s_failed:%s" % [
				mode,
				String(validation.get("reason", "invalid_result")),
			]
		)
	var committed_revision := int(native_result.get("revision", -1))
	var state_initialized := bool(native_result.get(
		"state_initialized",
		false
	))
	var output_vertices: PackedVector3Array = native_result.get(
		"vertices",
		PackedVector3Array()
	)
	var output_indices: PackedInt32Array = native_result.get(
		"indices",
		PackedInt32Array()
	)
	native_static_expected_revision = committed_revision
	native_static_lifecycle = NATIVE_STATIC_LIFECYCLE_ACTIVE
	native_static_state_initialized = state_initialized
	native_static_active_vertices = output_vertices
	native_static_active_indices = output_indices
	if bool(transition.get("requires_native_ack", false)):
		if (
			authoring_state == null
			or not authoring_state.has_method(
				"acknowledge_bounded_history_transition"
			)
			or not bool(authoring_state.call(
				"acknowledge_bounded_history_transition",
				int(transition.get("revision", -1)),
				native_result
			))
		):
			return _reject_bounded_native_fast_lane(
				authoring_state,
				transition,
				"bounded_transition_ack_failed"
			)
		presentation = authoring_state.call(
			"get_bounded_presentation_descriptor"
		) as Dictionary
	var revision_node: Node3D = null
	var protected_bodies: Array = presentation.get(
		"protected_bodies",
		[]
	) as Array
	var should_publish_revision := (
		state_initialized or not protected_bodies.is_empty()
	)
	var preview_timeline_bodies: Array = []
	if bool(transition.get("requires_native_ack", false)):
		preview_timeline_bodies.append_array(
			transition.get("promoted_bodies", []) as Array
		)
	preview_timeline_bodies.append_array(
		presentation.get("active_tail_bodies", []) as Array
	)
	preview_timeline_bodies.append_array(
		presentation.get("redo_timeline_bodies", []) as Array
	)
	_mark_native_capsule_operand_previews_accepted(
		preview_timeline_bodies,
		committed_revision
	)
	_prune_native_capsule_operand_previews_to_bodies(
		preview_timeline_bodies
	)
	if should_publish_revision:
		var revision_result := _build_native_static_revision_node(
			output_vertices,
			output_indices,
			presentation.get("active_tail_bodies", []) as Array,
			committed_revision,
			presentation
		)
		if not bool(revision_result.get("ok", false)):
			return _reject_bounded_native_fast_lane(
				authoring_state,
				transition,
				String(revision_result.get(
					"reason",
					"native_publication_build_failed"
				))
			)
		revision_node = revision_result.get("node", null) as Node3D
	if should_publish_revision:
		if not _begin_native_static_publication(
			revision_node,
			committed_revision
		):
			return _reject_bounded_native_fast_lane(
				authoring_state,
				transition,
				"native_publication_stage_failed"
			)
	else:
		_commit_native_static_empty_publication(committed_revision)
	var current_presentation := authoring_state.call(
		"get_bounded_presentation_descriptor"
	) as Dictionary
	_capture_bounded_native_snapshot(current_presentation)
	native_static_sync_diagnostics["last_mode"] = mode
	native_static_sync_diagnostics["last_failure_reason"] = ""
	native_static_sync_diagnostics["last_native_total_ms"] = float(
		native_result.get("total_native_ms", 0.0)
	)
	native_static_sync_diagnostics["output_vertices"] = output_vertices.size()
	native_static_sync_diagnostics["output_triangles"] = output_indices.size() / 3
	_capture_native_static_history_diagnostics(native_result)
	match StringName(mode):
		&"reset":
			native_static_sync_diagnostics["reset_count"] = int(
				native_static_sync_diagnostics.get("reset_count", 0)
			) + 1
		&"append", &"promotion_append":
			native_static_sync_diagnostics["append_count"] = int(
				native_static_sync_diagnostics.get("append_count", 0)
			) + 1
		&"undo":
			native_static_sync_diagnostics["undo_count"] = int(
				native_static_sync_diagnostics.get("undo_count", 0)
			) + 1
		&"redo":
			native_static_sync_diagnostics["redo_count_total"] = int(
				native_static_sync_diagnostics.get("redo_count_total", 0)
			) + 1
		&"restore":
			native_static_sync_diagnostics["restore_count"] = int(
				native_static_sync_diagnostics.get("restore_count", 0)
			) + 1
	_refresh_native_static_diagnostics()
	return {"handled": true, "force_full_csg": false}


func _stage_bounded_current_native_packet(
	authoring_state: Resource,
	transition: Dictionary,
	presentation: Dictionary,
	mode: String
) -> Dictionary:
	var protected_bodies: Array = presentation.get(
		"protected_bodies",
		[]
	) as Array
	if not native_static_state_initialized and protected_bodies.is_empty():
		_commit_native_static_empty_publication(native_static_expected_revision)
		_capture_bounded_native_snapshot(presentation)
		native_static_lifecycle = NATIVE_STATIC_LIFECYCLE_ACTIVE
		native_static_sync_diagnostics["last_mode"] = "%s_empty" % mode
		native_static_sync_diagnostics["last_failure_reason"] = ""
		_refresh_native_static_diagnostics()
		return {"handled": true, "force_full_csg": false}
	var revision_result := _build_native_static_revision_node(
		native_static_active_vertices,
		native_static_active_indices,
		presentation.get("active_tail_bodies", []) as Array,
		native_static_expected_revision,
		presentation
	)
	if not bool(revision_result.get("ok", false)):
		return _reject_bounded_native_fast_lane(
			authoring_state,
			transition,
			String(revision_result.get(
				"reason",
				"bounded_current_packet_publication_build_failed"
			))
		)
	native_static_lifecycle = NATIVE_STATIC_LIFECYCLE_ACTIVE
	if not _begin_native_static_publication(
		revision_result.get("node", null) as Node3D,
		native_static_expected_revision
	):
		return _reject_bounded_native_fast_lane(
			authoring_state,
			transition,
			"bounded_current_packet_publication_stage_failed"
		)
	_capture_bounded_native_snapshot(presentation)
	native_static_sync_diagnostics["last_mode"] = mode
	native_static_sync_diagnostics["last_failure_reason"] = ""
	_refresh_native_static_diagnostics()
	return {"handled": true, "force_full_csg": false}


func _validate_native_committed_result(
	native_result: Dictionary,
	expected_previous_revision: int
) -> Dictionary:
	if not bool(native_result.get("ok", false)):
		return {
			"ok": false,
			"reason": "%s:%s" % [
				String(native_result.get("error_code", "unknown")),
				String(native_result.get("error_message", "unknown")),
			],
		}
	if not bool(native_result.get("committed", false)):
		return {"ok": false, "reason": "result_not_committed"}
	if int(native_result.get("previous_revision", -1)) != expected_previous_revision:
		return {"ok": false, "reason": "previous_revision_mismatch"}
	if int(native_result.get("revision", -1)) != expected_previous_revision + 1:
		return {"ok": false, "reason": "revision_mismatch"}
	if (
		not bool(native_result.get("history_window_enabled", false))
		or int(native_result.get("history_window_capacity", 0))
		!= BOUNDED_HISTORY_WINDOW_CAPACITY
	):
		return {"ok": false, "reason": "history_window_contract_mismatch"}
	var state_initialized := bool(native_result.get(
		"state_initialized",
		false
	))
	var vertices: PackedVector3Array = native_result.get(
		"vertices",
		PackedVector3Array()
	)
	var indices: PackedInt32Array = native_result.get(
		"indices",
		PackedInt32Array()
	)
	if state_initialized:
		if vertices.is_empty() or indices.is_empty() or indices.size() % 3 != 0:
			return {"ok": false, "reason": "initialized_output_invalid"}
	elif not vertices.is_empty() or not indices.is_empty():
		return {"ok": false, "reason": "empty_state_has_output_mesh"}
	return {"ok": true}


func _commit_native_static_empty_publication(revision: int) -> void:
	native_static_publication_generation += 1
	for candidate: Node3D in [
		native_static_published_node,
		native_static_staged_node,
	]:
		if candidate != null and is_instance_valid(candidate):
			candidate.free()
	native_static_published_node = null
	native_static_staged_node = null
	native_static_published_revision = revision
	native_static_staged_revision = 0
	native_static_publication_pending = false
	native_static_authoritative = true
	_clear_native_capsule_operand_previews_through_revision(revision)
	if (
		native_static_retiring_node != null
		and is_instance_valid(native_static_retiring_node)
	):
		native_static_retiring_node.free()
	native_static_retiring_node = null
	if native_static_body_root != null:
		native_static_body_root.visible = false
	_set_csg_static_publication_enabled(false)
	if csg_static_body_root != null:
		csg_static_body_root.visible = false


func _capture_bounded_native_snapshot(presentation: Dictionary) -> void:
	var active_tail_bodies: Array = presentation.get(
		"active_tail_bodies",
		[]
	) as Array
	_capture_native_static_prefix(active_tail_bodies)
	if native_static_material_variant_id == StringName():
		native_static_material_variant_id = _resolve_bounded_material_variant_id(
			presentation
		)


func _restore_bounded_native_static_lane(
	authoring_state: Resource,
	transition: Dictionary,
	presentation: Dictionary
) -> Dictionary:
	var checkpoint_count := _resolve_bounded_checkpoint_operation_count(
		presentation
	)
	var checkpoint_packet := _resolve_bounded_checkpoint_packet(presentation)
	if (
		checkpoint_count > 0
		and not _bounded_checkpoint_packet_is_materialized(
			checkpoint_packet,
			checkpoint_count
		)
	):
		var recovery := _materialize_bounded_checkpoint_before_native_reset(
			authoring_state
		)
		if not bool(recovery.get("ok", false)):
			_mark_bounded_checkpoint_recovery_blocked(
				authoring_state,
				&"bounded_checkpoint_not_materialized_for_restore"
			)
			return {
				"handled": true,
				"recovery_blocked": true,
				"force_full_csg": false,
				"presentation_descriptor": recovery.get(
					"presentation_descriptor",
					presentation
				) as Dictionary,
			}
		presentation = recovery.get(
			"presentation_descriptor",
			presentation
		) as Dictionary
		checkpoint_count = _resolve_bounded_checkpoint_operation_count(
			presentation
		)
		checkpoint_packet = _resolve_bounded_checkpoint_packet(presentation)
	var active_tail_bodies: Array = presentation.get(
		"active_tail_bodies",
		[]
	) as Array
	var redo_timeline_bodies: Array = presentation.get(
		"redo_timeline_bodies",
		[]
	) as Array
	var replays_pending_promotion := (
		StringName(transition.get("kind", StringName()))
		== &"promotion_append"
		and bool(transition.get("requires_native_ack", false))
	)
	var promoted_bodies: Array = (
		transition.get("promoted_bodies", []) as Array
		if replays_pending_promotion
		else []
	)
	if replays_pending_promotion and promoted_bodies.is_empty():
		return _reject_bounded_native_fast_lane(
			authoring_state,
			transition,
			"bounded_promotion_restore_prefix_missing"
		)
	var timeline_bodies: Array = []
	timeline_bodies.append_array(active_tail_bodies)
	timeline_bodies.append_array(redo_timeline_bodies)
	var replay_bodies: Array = []
	replay_bodies.append_array(promoted_bodies)
	replay_bodies.append_array(timeline_bodies)
	var replay_capacity := (
		BOUNDED_HISTORY_WINDOW_CAPACITY + promoted_bodies.size()
		if replays_pending_promotion
		else BOUNDED_HISTORY_WINDOW_CAPACITY
	)
	if replay_bodies.size() > replay_capacity:
		return _reject_bounded_native_fast_lane(
			authoring_state,
			transition,
			"bounded_restore_replay_exceeds_capacity"
		)
	var expected_material_id := _resolve_bounded_material_variant_id(
		presentation
	)
	for body_variant: Variant in replay_bodies:
		var body := body_variant as Resource
		var body_validation := _validate_native_static_body(
			body,
			expected_material_id
		)
		if not bool(body_validation.get("ok", false)):
			return _reject_bounded_native_fast_lane(
				authoring_state,
				transition,
				String(body_validation.get(
					"reason",
					"bounded_restore_body_ineligible"
				))
			)
		if expected_material_id == StringName():
			expected_material_id = StringName(body.get(
				"material_variant_id"
			))
	# Capsule operands are produced by Godot's exact CSG path extrusion one
	# rendered frame after staging.  Request every missing tail packet before
	# resetting the current native publication, then retry this same transition
	# when the bounded batch is ready.
	var replay_operand_packets: Array[Dictionary] = []
	var has_pending_operand := false
	for body_variant: Variant in replay_bodies:
		var packet_candidate := _build_native_static_operand_packet(
			body_variant as Resource
		)
		replay_operand_packets.append(packet_candidate)
		if bool(packet_candidate.get("pending", false)):
			has_pending_operand = true
			continue
		if not bool(packet_candidate.get("ok", false)):
			return _reject_bounded_native_fast_lane(
				authoring_state,
				transition,
				String(packet_candidate.get(
					"reason",
					"bounded_restore_operand_invalid"
				))
			)
	if has_pending_operand:
		return _defer_native_operand_sync(
			presentation,
			"bounded_restore_operand_pending"
		)
	if checkpoint_count == 0 and replay_bodies.is_empty():
		var empty_reset := _reset_native_static_lane(
			NATIVE_STATIC_LIFECYCLE_ARMED_EMPTY,
			""
		)
		if not bool(empty_reset.get("ok", false)):
			return {
				"handled": true,
				"recovery_blocked": true,
				"force_full_csg": false,
			}
		native_static_bound_state_instance_id = int(
			authoring_state.get_instance_id()
		)
		native_static_state_initialized = false
		native_static_active_vertices = PackedVector3Array()
		native_static_active_indices = PackedInt32Array()
		return _stage_bounded_current_native_packet(
			authoring_state,
			transition,
			presentation,
			"restore"
		)
	var restore_reset := _reset_native_static_lane(
		NATIVE_STATIC_LIFECYCLE_ARMED_EMPTY,
		"bounded_restore",
		true,
		true
	)
	if not bool(restore_reset.get("ok", false)):
		return {
			"handled": true,
			"recovery_blocked": true,
			"force_full_csg": false,
		}
	var retained_publication := restore_reset.get(
		"retained_publication",
		null
	) as Node3D
	if (
		retained_publication != null
		and is_instance_valid(retained_publication)
		and csg_material_body_root != null
		and is_instance_valid(csg_material_body_root)
	):
		var retained_parent := retained_publication.get_parent()
		if retained_parent != csg_material_body_root:
			if retained_parent != null:
				retained_parent.remove_child(retained_publication)
			csg_material_body_root.add_child(retained_publication)
		retained_publication.visible = true
		native_static_retiring_node = retained_publication
	native_static_bound_state_instance_id = int(
		authoring_state.get_instance_id()
	)
	var backend_result := _ensure_native_static_backend()
	if not bool(backend_result.get("ok", false)):
		return _reject_bounded_native_fast_lane(
			authoring_state,
			transition,
			String(backend_result.get(
				"reason",
				"native_backend_unavailable"
			))
		)
	var operations: Array[Dictionary] = []
	var first_tail_index := 0
	if checkpoint_count > 0:
		operations.append({
			"method": &"reset_checkpoint_mesh",
			"arguments": [
				checkpoint_packet.get(
					"vertices",
					PackedVector3Array()
				),
				checkpoint_packet.get(
					"indices",
					PackedInt32Array()
				),
				checkpoint_count,
			],
		})
	elif not replay_bodies.is_empty():
		var first_packet := replay_operand_packets[0]
		operations.append({
			"method": &"reset_mesh",
			"arguments": [
				first_packet.get("vertices", PackedVector3Array()),
				first_packet.get("indices", PackedInt32Array()),
			],
		})
		first_tail_index = 1
	for body_index in range(first_tail_index, replay_bodies.size()):
		var operand_packet := replay_operand_packets[body_index]
		operations.append({
			"method": &"add_mesh",
			"arguments": [
				operand_packet.get("vertices", PackedVector3Array()),
				operand_packet.get("indices", PackedInt32Array()),
			],
		})
	for _redo_body: Variant in redo_timeline_bodies:
		operations.append({
			"method": &"undo_state",
			"arguments": [],
		})
	var final_result: Dictionary = {}
	for operation_index in range(operations.size()):
		var operation := operations[operation_index]
		var method_name := StringName(operation.get(
			"method",
			StringName()
		))
		final_result = native_static_manifold_backend.callv(
			method_name,
			operation.get("arguments", []) as Array
		) as Dictionary
		if operation_index == operations.size() - 1:
			continue
		var step_validation := _validate_native_committed_result(
			final_result,
			native_static_expected_revision
		)
		if not bool(step_validation.get("ok", false)):
			return _reject_bounded_native_fast_lane(
				authoring_state,
				transition,
				"bounded_restore_step_failed:%s" % String(
					step_validation.get("reason", "invalid_result")
				)
			)
		native_static_expected_revision = int(final_result.get(
			"revision",
			-1
		))
	return _accept_bounded_native_result(
		authoring_state,
		transition,
		presentation,
		final_result,
		"restore"
	)


func _resolve_bounded_checkpoint_packet(
	presentation: Dictionary
) -> Dictionary:
	var packet_value: Variant = presentation.get("checkpoint_packet", {})
	if packet_value is Dictionary and not (packet_value as Dictionary).is_empty():
		return (packet_value as Dictionary).duplicate(true)
	var checkpoint := presentation.get("checkpoint", null) as Resource
	if checkpoint != null and checkpoint.has_method("to_native_packet"):
		return checkpoint.call("to_native_packet") as Dictionary
	return {}


func _resolve_bounded_checkpoint_operation_count(
	presentation: Dictionary
) -> int:
	if presentation.has("checkpoint_operation_count"):
		return maxi(int(presentation.get(
			"checkpoint_operation_count",
			0
		)), 0)
	var checkpoint := presentation.get("checkpoint", null) as Resource
	if checkpoint != null:
		return maxi(int(checkpoint.get(
			"accumulated_operation_count"
		)), 0)
	var packet := _resolve_bounded_checkpoint_packet(presentation)
	return maxi(int(packet.get("checkpoint_operation_count", 0)), 0)


func _bounded_checkpoint_packet_is_materialized(
	packet: Dictionary,
	checkpoint_count: int
) -> bool:
	if checkpoint_count <= 0:
		return true
	var vertices: PackedVector3Array = packet.get(
		"vertices",
		PackedVector3Array()
	)
	var indices: PackedInt32Array = packet.get(
		"indices",
		PackedInt32Array()
	)
	var materialized_count := int(packet.get(
		"materialized_mesh_operation_count",
		packet.get("checkpoint_operation_count", 0)
	))
	return (
		materialized_count == checkpoint_count
		and not vertices.is_empty()
		and not indices.is_empty()
		and indices.size() % 3 == 0
	)


func _resolve_bounded_material_variant_id(
	presentation: Dictionary
) -> StringName:
	var material_variant_id := StringName(presentation.get(
		"material_variant_id",
		StringName()
	))
	if material_variant_id != StringName():
		return material_variant_id
	var checkpoint := presentation.get("checkpoint", null) as Resource
	if checkpoint != null:
		material_variant_id = StringName(checkpoint.get(
			"material_variant_id"
		))
		if material_variant_id != StringName():
			return material_variant_id
	var packet := _resolve_bounded_checkpoint_packet(presentation)
	material_variant_id = StringName(packet.get(
		"material_variant_id",
		StringName()
	))
	if material_variant_id != StringName():
		return material_variant_id
	for collection_name: String in [
		"active_tail_bodies",
		"redo_timeline_bodies",
		"protected_bodies",
	]:
		var bodies: Array = presentation.get(collection_name, []) as Array
		for body_variant: Variant in bodies:
			var body := body_variant as Resource
			if body == null:
				continue
			material_variant_id = StringName(body.get(
				"material_variant_id"
			))
			if material_variant_id != StringName():
				return material_variant_id
	return StringName()


func _install_bounded_checkpoint_export_provider(
	authoring_state: Resource
) -> void:
	if (
		authoring_state == null
		or not authoring_state.has_method(
			"set_bounded_history_checkpoint_export_provider"
		)
	):
		return
	authoring_state.call(
		"set_bounded_history_checkpoint_export_provider",
		Callable(self, "_provide_bounded_checkpoint_export")
	)
	if authoring_state.has_method("set_runtime_contract_mesh_export_provider"):
		authoring_state.call(
			"set_runtime_contract_mesh_export_provider",
			Callable(self, "_provide_runtime_contract_mesh_export")
		)


func _clear_bounded_checkpoint_export_provider() -> void:
	if (
		native_static_bound_authoring_state != null
		and is_instance_valid(native_static_bound_authoring_state)
	):
		if native_static_bound_authoring_state.has_method(
			"clear_bounded_history_checkpoint_export_provider"
		):
			native_static_bound_authoring_state.call(
				"clear_bounded_history_checkpoint_export_provider",
				Callable(self, "_provide_bounded_checkpoint_export")
			)
		if native_static_bound_authoring_state.has_method(
			"clear_runtime_contract_mesh_export_provider"
		):
			native_static_bound_authoring_state.call(
				"clear_runtime_contract_mesh_export_provider",
				Callable(self, "_provide_runtime_contract_mesh_export")
			)
	native_static_bound_authoring_state = null
	native_static_bound_state_instance_id = 0


func _provide_bounded_checkpoint_export(
	expected_checkpoint_operation_count: int
) -> Dictionary:
	if (
		native_static_manifold_backend == null
		or not is_instance_valid(native_static_manifold_backend)
		or not native_static_manifold_backend.has_method(
			"export_checkpoint_mesh"
		)
	):
		return {
			"ok": false,
			"error_code": "NATIVE_CHECKPOINT_PROVIDER_UNAVAILABLE",
		}
	var checkpoint_export := native_static_manifold_backend.call(
		"export_checkpoint_mesh"
	) as Dictionary
	if not _native_checkpoint_export_is_valid(
		checkpoint_export,
		expected_checkpoint_operation_count,
		native_static_expected_revision
	):
		return {
			"ok": false,
			"error_code": "NATIVE_CHECKPOINT_PROVIDER_PACKET_INVALID",
			"native_result": checkpoint_export,
		}
	native_static_sync_diagnostics["lazy_checkpoint_exports"] = int(
		native_static_sync_diagnostics.get("lazy_checkpoint_exports", 0)
	) + 1
	_capture_native_static_history_diagnostics(checkpoint_export)
	_refresh_native_static_diagnostics()
	return checkpoint_export


func _resolve_authoritative_runtime_mesh_packet(
	allow_empty_ordinary_mesh: bool = false
) -> Dictionary:
	if (
		not native_static_active_vertices.is_empty()
		and not native_static_active_indices.is_empty()
		and native_static_active_indices.size() % 3 == 0
	):
		return {
			"ok": true,
			"vertices": PackedVector3Array(native_static_active_vertices),
			"indices": PackedInt32Array(native_static_active_indices),
			"source": &"forge_v2_native_ordinary_mesh_v1",
			"includes_protected_handle": false,
		}
	var csg_packet := _bake_authoritative_csg_runtime_mesh_packet(
		allow_empty_ordinary_mesh
	)
	if bool(csg_packet.get("ok", false)):
		return csg_packet
	if (
		allow_empty_ordinary_mesh
		and (
			native_static_authoritative
			or native_static_lifecycle == NATIVE_STATIC_LIFECYCLE_ACTIVE
		)
	):
		return {
			"ok": true,
			"vertices": PackedVector3Array(),
			"indices": PackedInt32Array(),
			"source": &"forge_v2_native_handle_only_v1",
			"includes_protected_handle": false,
		}
	return csg_packet


func _bake_authoritative_csg_runtime_mesh_packet(
	includes_protected_handle: bool
) -> Dictionary:
	if (
		csg_static_body_root == null
		or not is_instance_valid(csg_static_body_root)
		or not csg_static_body_root.visible
		or csg_static_body_root.get_child_count() <= 0
	):
		return {
			"ok": false,
			"pending": false,
			"error_code": "RUNTIME_CONTRACT_CSG_PUBLICATION_UNAVAILABLE",
			"reason": "csg_publication_unavailable",
		}
	var merged_vertices := PackedVector3Array()
	var merged_indices := PackedInt32Array()
	var published_to_forge_local := global_transform.affine_inverse()
	for child_index: int in range(csg_static_body_root.get_child_count()):
		var shape := csg_static_body_root.get_child(child_index) as CSGShape3D
		if shape == null:
			continue
		var baked_vertices_are_global := (
			_csg_shape_contains_path_polygon(shape)
		)
		if not _csg_shape_generated_mesh_is_ready(shape):
			return {
				"ok": false,
				"pending": true,
				"error_code": "RUNTIME_CONTRACT_CSG_PUBLICATION_PENDING",
				"reason": "csg_publication_mesh_pending",
			}
		var baked_mesh := shape.bake_static_mesh()
		if baked_mesh == null:
			return {
				"ok": false,
				"pending": true,
				"error_code": "RUNTIME_CONTRACT_CSG_BAKE_PENDING",
				"reason": "csg_publication_bake_empty",
			}
		var flattened := _flatten_native_protected_handle_baked_mesh(
			baked_mesh,
			"runtime_contract_csg_%d_%d" % [
				get_instance_id(),
				child_index,
			],
			false
		)
		if not bool(flattened.get("ok", false)):
			return {
				"ok": false,
				"pending": false,
				"error_code": "RUNTIME_CONTRACT_CSG_BAKE_INVALID",
				"reason": String(flattened.get("reason", "unknown")),
			}
		var child_vertices: PackedVector3Array = flattened.get(
			"vertices",
			PackedVector3Array()
		)
		var child_indices: PackedInt32Array = flattened.get(
			"indices",
			PackedInt32Array()
		)
		var vertex_offset := merged_vertices.size()
		for vertex: Vector3 in child_vertices:
			var published_vertex := (
				vertex
				if baked_vertices_are_global
				else shape.global_transform * vertex
			)
			merged_vertices.append(published_to_forge_local * published_vertex)
		for index_value: int in child_indices:
			merged_indices.append(vertex_offset + index_value)
	if merged_vertices.is_empty() or merged_indices.is_empty():
		return {
			"ok": false,
			"pending": false,
			"error_code": "RUNTIME_CONTRACT_CSG_PUBLICATION_EMPTY",
			"reason": "csg_publication_mesh_empty",
		}
	return {
		"ok": true,
		"vertices": merged_vertices,
		"indices": merged_indices,
		"source": &"forge_v2_published_csg_mesh_v1",
		"includes_protected_handle": includes_protected_handle,
	}


func _csg_shape_contains_path_polygon(node: Node) -> bool:
	if node is CSGPolygon3D:
		var polygon := node as CSGPolygon3D
		if polygon.mode == CSGPolygon3D.MODE_PATH:
			return true
	for child: Node in node.get_children():
		if _csg_shape_contains_path_polygon(child):
			return true
	return false


func _provide_runtime_contract_mesh_export() -> Dictionary:
	if (
		native_static_bound_authoring_state == null
		or not is_instance_valid(native_static_bound_authoring_state)
		or not native_static_bound_authoring_state.has_method(
			"get_bounded_presentation_descriptor"
		)
	):
		return {
			"ok": false,
			"error_code": "RUNTIME_CONTRACT_STATE_UNAVAILABLE",
		}
	var current_transition := native_static_bound_authoring_state.call(
		"get_bounded_history_transition"
	) as Dictionary
	var current_transition_revision := int(current_transition.get(
		"revision",
		-1
	))
	var native_lane_active := (
		native_static_authoritative
		or native_static_lifecycle == NATIVE_STATIC_LIFECYCLE_ACTIVE
		or native_static_lifecycle == NATIVE_STATIC_LIFECYCLE_ARMED_EMPTY
	)
	var native_transition_pending := (
		native_static_deferred_transition_revision >= 0
		or native_static_publication_pending
		or native_static_staged_revision > 0
		or int(native_static_sync_diagnostics.get(
			"capsule_operand_pending_count",
			0
		)) > 0
		or not native_protected_handle_authority_pending_signature.is_empty()
		or (
			native_lane_active
			and current_transition_revision >= 0
			and native_static_consumed_transition_revision
			!= current_transition_revision
		)
		or (
			native_lane_active
			and native_static_expected_revision
			!= native_static_published_revision
		)
	)
	if native_transition_pending:
		return {
			"ok": false,
			"pending": true,
			"error_code": "RUNTIME_CONTRACT_NATIVE_TRANSITION_PENDING",
			"reason": "native_transition_or_publication_pending",
			"state_transition_revision": current_transition_revision,
			"consumed_transition_revision": (
				native_static_consumed_transition_revision
			),
		}
	var presentation := native_static_bound_authoring_state.call(
		"get_bounded_presentation_descriptor"
	) as Dictionary
	var protected_bodies: Array = presentation.get("protected_bodies", []) as Array
	if protected_bodies.size() > 1:
		return {
			"ok": false,
			"error_code": "RUNTIME_CONTRACT_MULTIPLE_PROTECTED_BODIES",
		}
	var published_mesh_packet := _resolve_authoritative_runtime_mesh_packet(
		not protected_bodies.is_empty()
	)
	if not bool(published_mesh_packet.get("ok", false)):
		return published_mesh_packet
	var ordinary_vertices: PackedVector3Array = published_mesh_packet.get(
		"vertices",
		PackedVector3Array()
	)
	var ordinary_indices: PackedInt32Array = published_mesh_packet.get(
		"indices",
		PackedInt32Array()
	)
	var ordinary_mesh_valid := (
		not ordinary_vertices.is_empty()
		and not ordinary_indices.is_empty()
		and ordinary_indices.size() % 3 == 0
	)
	if protected_bodies.is_empty():
		if not ordinary_mesh_valid:
			return {
				"ok": false,
				"error_code": "RUNTIME_CONTRACT_MESH_EMPTY",
			}
		return {
			"ok": true,
			"vertices": ordinary_vertices,
			"indices": ordinary_indices,
			"source_state_revision": native_static_expected_revision,
			"watertight": true,
			"final_union_performed": bool(published_mesh_packet.get(
				"includes_protected_handle",
				false
			)),
			"runtime_mesh_source": StringName(published_mesh_packet.get(
				"source",
				StringName()
			)),
		}
	var protected_body := protected_bodies[0] as Resource
	if protected_body == null:
		return {
			"ok": false,
			"error_code": "RUNTIME_CONTRACT_PROTECTED_BODY_INVALID",
		}
	var protected_signature := PrimaryGripHandleMeshPacketScript.build_body_signature(
		protected_body
	)
	var protected_packet := _resolve_authoritative_protected_handle_packet(
		protected_body
	)
	if not bool(protected_packet.get("ok", false)):
		return {
			"ok": false,
			"pending": bool(protected_packet.get("pending", false)),
			"error_code": "RUNTIME_CONTRACT_PROTECTED_MESH_UNAVAILABLE",
			"reason": String(protected_packet.get("reason", "unknown")),
		}
	var protected_vertices: PackedVector3Array = protected_packet.get(
		"vertices",
		PackedVector3Array()
	)
	var protected_indices: PackedInt32Array = protected_packet.get(
		"indices",
		PackedInt32Array()
	)
	if (
		protected_vertices.is_empty()
		or protected_indices.is_empty()
		or protected_indices.size() % 3 != 0
	):
		return {
			"ok": false,
			"error_code": "RUNTIME_CONTRACT_PROTECTED_MESH_INVALID",
		}
	if bool(published_mesh_packet.get("includes_protected_handle", false)):
		var published_result := {
			"ok": true,
			"vertices": ordinary_vertices,
			"indices": ordinary_indices,
			"source_state_revision": native_static_expected_revision,
			"watertight": true,
			"final_union_performed": true,
			"runtime_mesh_source": StringName(published_mesh_packet.get(
				"source",
				StringName()
			)),
		}
		published_result.merge(
			PrimaryGripHandleMeshPacketScript.build(
				protected_vertices,
				protected_indices,
				protected_signature
			),
			false
		)
		return published_result
	if not ordinary_mesh_valid:
		var handle_only_result := {
			"ok": true,
			"vertices": protected_vertices,
			"indices": protected_indices,
			"source_state_revision": native_static_expected_revision,
			"watertight": true,
			"final_union_performed": false,
			"handle_only": true,
		}
		handle_only_result.merge(
			PrimaryGripHandleMeshPacketScript.build(
				protected_vertices,
				protected_indices,
				protected_signature
			),
			false
		)
		return handle_only_result
	if (
		native_static_manifold_backend == null
		or not is_instance_valid(native_static_manifold_backend)
	):
		return {
			"ok": false,
			"error_code": "RUNTIME_CONTRACT_BOOLEAN_BACKEND_UNAVAILABLE",
		}
	var backend_method := ""
	var composition_variant: Variant
	if native_static_manifold_backend.has_method(
		"compose_current_state_with_protected_mesh"
	):
		backend_method = "compose_current_state_with_protected_mesh"
		composition_variant = native_static_manifold_backend.call(
			backend_method,
			protected_vertices,
			protected_indices
		)
	elif native_static_manifold_backend.has_method("compose_with_protected_mesh"):
		backend_method = "compose_with_protected_mesh"
		composition_variant = native_static_manifold_backend.call(
			backend_method,
			ordinary_vertices,
			ordinary_indices,
			protected_vertices,
			protected_indices
		)
	else:
		return {
			"ok": false,
			"error_code": "RUNTIME_CONTRACT_BOOLEAN_CAPABILITY_UNAVAILABLE",
		}
	if not composition_variant is Dictionary:
		return {
			"ok": false,
			"error_code": "RUNTIME_CONTRACT_BOOLEAN_PACKET_INVALID",
		}
	var composition := composition_variant as Dictionary
	var validation := _validate_native_protected_composition_packet(
		composition,
		backend_method,
		native_static_expected_revision
	)
	if not bool(validation.get("ok", false)):
		return {
			"ok": false,
			"error_code": "RUNTIME_CONTRACT_BOOLEAN_FAILED",
			"reason": String(validation.get("reason", "unknown")),
		}
	validation["watertight"] = true
	validation["final_union_performed"] = true
	validation["backend_method"] = backend_method
	validation.merge(
		PrimaryGripHandleMeshPacketScript.build(
			protected_vertices,
			protected_indices,
			protected_signature
		),
		false
	)
	if composition.has("output_volume_m3"):
		validation["output_volume_m3"] = composition.get("output_volume_m3")
	return validation


func _materialize_bounded_checkpoint_before_native_reset(
	authoring_state: Resource
) -> Dictionary:
	if (
		authoring_state == null
		or not authoring_state.has_method(
			"get_bounded_presentation_descriptor"
		)
	):
		return {"ok": true}
	var presentation := authoring_state.call(
		"get_bounded_presentation_descriptor"
	) as Dictionary
	var checkpoint_count := _resolve_bounded_checkpoint_operation_count(
		presentation
	)
	if checkpoint_count <= 0:
		return {"ok": true, "presentation_descriptor": presentation}
	if bool(presentation.get("checkpoint_restore_ready", false)):
		return {"ok": true, "presentation_descriptor": presentation}
	var packet := _provide_bounded_checkpoint_export(checkpoint_count)
	if not bool(packet.get("ok", false)):
		return {
			"ok": false,
			"reason": "checkpoint_export_before_reset_failed",
			"presentation_descriptor": presentation,
		}
	if (
		not authoring_state.has_method(
			"materialize_bounded_history_checkpoint"
		)
		or not bool(authoring_state.call(
			"materialize_bounded_history_checkpoint",
			packet
		))
	):
		return {
			"ok": false,
			"reason": "checkpoint_state_materialization_failed",
			"presentation_descriptor": presentation,
		}
	presentation = authoring_state.call(
		"get_bounded_presentation_descriptor"
	) as Dictionary
	if not bool(presentation.get("checkpoint_restore_ready", false)):
		return {
			"ok": false,
			"reason": "checkpoint_not_restore_ready_after_materialization",
			"presentation_descriptor": presentation,
		}
	return {"ok": true, "presentation_descriptor": presentation}


func _mark_bounded_checkpoint_recovery_blocked(
	authoring_state: Resource,
	reason: StringName
) -> void:
	if (
		authoring_state == null
		or not is_instance_valid(authoring_state)
		or not authoring_state.has_method(
			"mark_bounded_history_recovery_blocked"
		)
	):
		return
	authoring_state.call(
		"mark_bounded_history_recovery_blocked",
		reason
	)


func _try_sync_native_static_fast_lane(static_bodies: Array) -> Dictionary:
	if native_static_lifecycle == NATIVE_STATIC_LIFECYCLE_DISABLED:
		return {"handled": false, "force_full_csg": false}
	if native_static_lifecycle == NATIVE_STATIC_LIFECYCLE_UNOBSERVED:
		return _reject_native_static_fast_lane(
			"entry_requires_observed_empty_workpiece"
		)
	if native_static_lifecycle == NATIVE_STATIC_LIFECYCLE_ARMED_EMPTY:
		if static_bodies.size() != 1:
			return _reject_native_static_fast_lane(
				"initial_native_entry_requires_exactly_one_body"
			)
		var first_body := static_bodies[0] as Resource
		var first_validation := _validate_native_static_body(
			first_body,
			StringName()
		)
		if not bool(first_validation.get("ok", false)):
			return _reject_native_static_fast_lane(String(
				first_validation.get("reason", "initial_body_ineligible")
			))
		var backend_result := _ensure_native_static_backend()
		if not bool(backend_result.get("ok", false)):
			return _reject_native_static_fast_lane(String(
				backend_result.get("reason", "native_backend_unavailable")
			))
		var first_packet := _build_native_static_operand_packet(first_body)
		if not bool(first_packet.get("ok", false)):
			if bool(first_packet.get("pending", false)):
				return {
					"handled": false,
					"force_full_csg": false,
					"operand_pending": true,
					"reason": String(first_packet.get(
						"reason",
						"initial_operand_pending"
					)),
				}
			return _reject_native_static_fast_lane(String(
				first_packet.get("reason", "initial_operand_mesh_invalid")
			))
		var reset_result := native_static_manifold_backend.call(
			"reset_mesh",
			first_packet.get("vertices", PackedVector3Array()),
			first_packet.get("indices", PackedInt32Array())
		) as Dictionary
		return _accept_native_static_result(
			reset_result,
			static_bodies,
			"reset"
		)
	if native_static_lifecycle != NATIVE_STATIC_LIFECYCLE_ACTIVE:
		return _reject_native_static_fast_lane("native_lifecycle_invalid")
	var runtime_state := _validate_native_static_runtime_state()
	if not bool(runtime_state.get("ok", false)):
		return _reject_native_static_fast_lane(String(
			runtime_state.get("reason", "native_runtime_state_invalid")
		))
	var prefix_result := _validate_native_static_prefix(static_bodies)
	if bool(prefix_result.get("exact_match", false)):
		native_static_sync_diagnostics["last_mode"] = "no_op"
		native_static_sync_diagnostics["last_failure_reason"] = ""
		_refresh_native_static_diagnostics()
		return {"handled": true, "force_full_csg": false}
	if not bool(prefix_result.get("append_only", false)):
		return _reject_native_static_fast_lane(String(
			prefix_result.get("reason", "native_prefix_changed")
		))
	var appended_body := static_bodies[static_bodies.size() - 1] as Resource
	var appended_validation := _validate_native_static_body(
		appended_body,
		native_static_material_variant_id
	)
	if not bool(appended_validation.get("ok", false)):
		return _reject_native_static_fast_lane(String(
			appended_validation.get("reason", "appended_body_ineligible")
		))
	var appended_body_id := StringName(appended_body.get("body_id"))
	if native_static_body_signatures_by_id.has(appended_body_id):
		return _reject_native_static_fast_lane("appended_body_id_reused")
	var appended_bounds: AABB = appended_validation.get(
		"bounds",
		AABB()
	) as AABB
	if not _native_static_bounds_connect_to_prefix(appended_bounds):
		return _reject_native_static_fast_lane(
			"appended_body_creates_second_aabb_zone"
		)
	var appended_packet := _build_native_static_operand_packet(appended_body)
	if not bool(appended_packet.get("ok", false)):
		if bool(appended_packet.get("pending", false)):
			return {
				"handled": false,
				"force_full_csg": false,
				"operand_pending": true,
				"reason": String(appended_packet.get(
					"reason",
					"appended_operand_pending"
				)),
			}
		return _reject_native_static_fast_lane(String(
			appended_packet.get("reason", "appended_operand_mesh_invalid")
		))
	var add_result := native_static_manifold_backend.call(
		"add_mesh",
		appended_packet.get("vertices", PackedVector3Array()),
		appended_packet.get("indices", PackedInt32Array())
	) as Dictionary
	return _accept_native_static_result(
		add_result,
		static_bodies,
		"append"
	)


func _validate_native_static_body(
	body: Resource,
	expected_material_variant_id: StringName
) -> Dictionary:
	if body == null:
		return {"ok": false, "reason": "body_missing"}
	var body_id := StringName(body.get("body_id"))
	if body_id == StringName():
		return {"ok": false, "reason": "body_id_missing"}
	var material_variant_id := StringName(body.get("material_variant_id"))
	if material_variant_id == StringName():
		return {"ok": false, "reason": "material_variant_id_missing"}
	if (
		expected_material_variant_id != StringName()
		and material_variant_id != expected_material_variant_id
	):
		return {"ok": false, "reason": "multiple_materials_unsupported"}
	if ForgeV2MaterialCompositionPolicyScript.is_protected_handle_entry(body):
		return {"ok": false, "reason": "protected_handle_unsupported"}
	if (
		ForgeV2MaterialCompositionPolicyScript.resolve_effective_operation_mode(
			body
		)
		!= ForgeV2VolumeStrokeScript.OPERATION_ADD_MATERIAL
	):
		return {"ok": false, "reason": "effective_operation_not_add"}
	if (
		ForgeV2MaterialCompositionPolicyScript.resolve_effective_placement_policy(
			body
		)
		!= ForgeV2VolumeStrokeScript.PLACEMENT_REPLACE_EXISTING
	):
		return {"ok": false, "reason": "effective_placement_not_replace"}
	var body_kind := StringName(body.get("body_kind"))
	var shape_kind := StringName(body.get("shape_kind"))
	var path_points: PackedVector3Array = body.get("path_points")
	var path_normals: PackedVector3Array = body.get("path_surface_normals")
	var path_contacts: PackedVector3Array = body.get("path_contact_directions")
	if _is_native_capsule_shape_kind(shape_kind):
		if body_kind not in [
			ForgeV2MaterialBodyScript.BODY_KIND_VOLUME_STROKE,
			ForgeV2MaterialBodyScript.BODY_KIND_DETAILING_BRUSH,
		]:
			return {"ok": false, "reason": "capsule_body_kind_unsupported"}
		var minimum_point_count := (
			2
			if shape_kind
			== ForgeV2MaterialBodyScript.SHAPE_KIND_SPLINE_CAPSULE_PATH
			else 1
		)
		if path_points.size() < minimum_point_count:
			return {"ok": false, "reason": "capsule_path_too_short"}
		if path_normals.size() != path_points.size():
			return {"ok": false, "reason": "capsule_normal_count_mismatch"}
		if not path_contacts.is_empty():
			return {"ok": false, "reason": "capsule_contacts_must_be_empty"}
		if int(body.get("profile_runtime_schema_version")) != 0:
			return {"ok": false, "reason": "capsule_profile_schema_must_be_zero"}
		var radius_meters := float(body.get("radius_meters"))
		if not is_finite(radius_meters) or radius_meters <= 0.0:
			return {"ok": false, "reason": "capsule_radius_invalid"}
		for point: Vector3 in path_points:
			if not point.is_finite():
				return {"ok": false, "reason": "capsule_point_nonfinite"}
		for normal: Vector3 in path_normals:
			if not normal.is_finite() or normal.length_squared() <= 0.000001:
				return {"ok": false, "reason": "capsule_normal_invalid"}
	else:
		if (
			not body.has_method("uses_explicit_surface_contact_authority")
			or not bool(body.call("uses_explicit_surface_contact_authority"))
			or not _uses_explicit_surface_profile_frame(body)
		):
			return {
				"ok": false,
				"reason": "explicit_surface_authority_required",
			}
		var profile_polygon: PackedVector2Array = body.get(
			"profile_polygon_2d_meters"
		)
		if path_points.size() < 2:
			return {"ok": false, "reason": "path_requires_two_points"}
		if profile_polygon.size() < 3:
			return {"ok": false, "reason": "profile_requires_three_points"}
		if (
			path_normals.size() != path_points.size()
			or path_contacts.size() != path_points.size()
		):
			return {"ok": false, "reason": "explicit_frame_count_mismatch"}
	return {
		"ok": true,
		"body_id": body_id,
		"material_variant_id": material_variant_id,
		"signature": _build_native_static_body_signature(body),
		"bounds": _build_csg_body_bounds(body),
	}


func _is_native_capsule_shape_kind(shape_kind: StringName) -> bool:
	return shape_kind in [
		ForgeV2MaterialBodyScript.SHAPE_KIND_CAPSULE_PATH,
		ForgeV2MaterialBodyScript.SHAPE_KIND_SPLINE_CAPSULE_PATH,
	]


func _validate_native_static_prefix(static_bodies: Array) -> Dictionary:
	if static_bodies.size() == native_static_body_order_snapshot.size():
		for body_index in range(static_bodies.size()):
			var exact_body := static_bodies[body_index] as Resource
			if exact_body == null:
				return {"exact_match": false, "append_only": false, "reason": "prefix_body_missing"}
			var exact_body_id := StringName(exact_body.get("body_id"))
			if exact_body_id != native_static_body_order_snapshot[body_index]:
				return {"exact_match": false, "append_only": false, "reason": "body_order_changed"}
			if String(native_static_body_signatures_by_id.get(exact_body_id, "")) != _build_native_static_body_signature(exact_body):
				return {"exact_match": false, "append_only": false, "reason": "prefix_body_changed"}
		return {"exact_match": true, "append_only": false, "reason": ""}
	if static_bodies.size() != native_static_body_order_snapshot.size() + 1:
		return {"exact_match": false, "append_only": false, "reason": "not_single_append"}
	for body_index in range(native_static_body_order_snapshot.size()):
		var prior_body := static_bodies[body_index] as Resource
		if prior_body == null:
			return {"exact_match": false, "append_only": false, "reason": "prefix_body_missing"}
		var prior_body_id := StringName(prior_body.get("body_id"))
		if prior_body_id != native_static_body_order_snapshot[body_index]:
			return {"exact_match": false, "append_only": false, "reason": "body_order_not_append_only"}
		if String(native_static_body_signatures_by_id.get(prior_body_id, "")) != _build_native_static_body_signature(prior_body):
			return {"exact_match": false, "append_only": false, "reason": "prefix_body_changed"}
	return {"exact_match": false, "append_only": true, "reason": ""}


func _build_native_static_body_signature(body: Resource) -> String:
	if body == null:
		return ""
	var exact_geometry := [
		body.get("path_points"),
		body.get("path_surface_normals"),
		body.get("path_contact_directions"),
		body.get("profile_polygon_2d_meters"),
		body.get("profile_anchor_2d_meters"),
		body.get("profile_contact_direction_2d"),
		body.get("profile_contact_point_relative_2d_meters"),
		body.get("radius_meters"),
		body.get("profile_rotation_bias_degrees"),
		body.get("profile_twist_degrees_per_meter"),
	]
	var exact_hash := var_to_bytes(exact_geometry).hex_encode().sha256_text()
	return "%s|exact:%s" % [_build_csg_body_signature(body), exact_hash]


func _native_static_bounds_connect_to_prefix(appended_bounds: AABB) -> bool:
	for body_id: StringName in native_static_body_order_snapshot:
		if not native_static_body_bounds_by_id.has(body_id):
			return false
		var prefix_bounds: AABB = native_static_body_bounds_by_id.get(
			body_id,
			AABB()
		) as AABB
		if _csg_body_bounds_intersect(appended_bounds, prefix_bounds):
			return true
	return false


func _ensure_native_static_backend() -> Dictionary:
	if (
		native_static_manifold_backend != null
		and is_instance_valid(native_static_manifold_backend)
	):
		return {"ok": true}
	if not ClassDB.class_exists(&"ForgeV2ManifoldBoolean"):
		return {"ok": false, "reason": "native_class_not_registered"}
	var backend := ClassDB.instantiate(&"ForgeV2ManifoldBoolean") as Object
	if backend == null or not is_instance_valid(backend):
		return {"ok": false, "reason": "native_backend_instantiation_failed"}
	if (
		not backend.has_method("get_state_info")
		or not backend.has_method("get_history_info")
		or not backend.has_method("set_history_window_enabled")
		or not backend.has_method("export_checkpoint_mesh")
		or not backend.has_method("reset_checkpoint_mesh")
		or not backend.has_method("reset_mesh")
		or not backend.has_method("add_mesh")
		or not backend.has_method("undo_state")
		or not backend.has_method("redo_state")
		or not backend.has_method("clear_state")
	):
		return {"ok": false, "reason": "native_backend_contract_missing"}
	var state_info := backend.call("get_state_info") as Dictionary
	if (
		not bool(state_info.get("ok", false))
		or bool(state_info.get("state_initialized", false))
		or int(state_info.get("revision", -1)) != 0
	):
		return {"ok": false, "reason": "native_backend_initial_state_invalid"}
	var history_enable_result := backend.call(
		"set_history_window_enabled",
		true
	) as Dictionary
	if (
		not bool(history_enable_result.get("ok", false))
		or not bool(history_enable_result.get(
			"history_window_enabled",
			false
		))
		or int(history_enable_result.get("history_window_capacity", 0)) != 5
	):
		backend.call("clear_state")
		return {"ok": false, "reason": "native_history_window_enable_failed"}
	native_static_manifold_backend = backend
	native_static_expected_revision = 0
	_capture_native_static_history_diagnostics(history_enable_result)
	return {"ok": true}


func _build_native_static_operand_packet(body: Resource) -> Dictionary:
	if body == null:
		return {"ok": false, "reason": "native_operand_body_missing"}
	var shape_kind := StringName(body.get("shape_kind"))
	if _is_native_capsule_shape_kind(shape_kind):
		var signature := _build_native_static_body_signature(body)
		if signature.is_empty():
			return {"ok": false, "reason": "capsule_operand_signature_empty"}
		if native_capsule_operand_cache.has(signature):
			native_static_sync_diagnostics[
				"capsule_operand_cache_hit_count"
			] = int(native_static_sync_diagnostics.get(
				"capsule_operand_cache_hit_count",
				0
			)) + 1
			var cached_packet := (
				native_capsule_operand_cache.get(signature, {}) as Dictionary
			)
			_touch_native_capsule_operand_cache_key(signature)
			return cached_packet
		if native_capsule_operand_pending.has(signature):
			var ready_entry := native_capsule_operand_pending.get(
				signature,
				{}
			) as Dictionary
			if bool(ready_entry.get("packet_ready", false)):
				var retained_packet := ready_entry.get(
					"packet",
					{}
				) as Dictionary
				if bool(retained_packet.get("ok", false)):
					native_capsule_operand_cache[signature] = retained_packet
					_touch_native_capsule_operand_cache_key(signature)
					_trim_native_capsule_operand_cache()
					return retained_packet
				# A ready marker without either cached or retained geometry cannot
				# ever make progress.  Drop it so the request can be staged again.
				native_capsule_operand_pending.erase(signature)
		if native_capsule_operand_failures.has(signature):
			return native_capsule_operand_failures.get(
				signature,
				{"ok": false, "reason": "capsule_operand_bake_failed"}
			) as Dictionary
		var request_result := _request_native_capsule_operand_bake(
			body,
			signature
		)
		if not bool(request_result.get("ok", false)):
			return request_result
		return {
			"ok": false,
			"pending": true,
			"signature": signature,
			"reason": "capsule_operand_bake_pending",
		}
	var sweep_mesh := _build_active_material_body_sweep_mesh(body)
	if sweep_mesh == null or sweep_mesh.get_surface_count() != 1:
		return {"ok": false, "reason": "explicit_sweep_mesh_missing"}
	var surface_arrays: Array = sweep_mesh.surface_get_arrays(0)
	if surface_arrays.size() < Mesh.ARRAY_MAX:
		return {"ok": false, "reason": "explicit_sweep_arrays_incomplete"}
	var vertices := surface_arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
	var indices := surface_arrays[Mesh.ARRAY_INDEX] as PackedInt32Array
	if vertices.is_empty():
		return {"ok": false, "reason": "explicit_sweep_vertices_empty"}
	if indices.is_empty() or indices.size() % 3 != 0:
		return {"ok": false, "reason": "explicit_sweep_indices_invalid"}
	return {
		"ok": true,
		"signature": _build_native_static_body_signature(body),
		"vertices": vertices,
		"indices": indices,
	}


func _defer_native_operand_sync(
	presentation: Dictionary,
	reason: String
) -> Dictionary:
	native_static_sync_diagnostics["last_mode"] = "capsule_operand_pending"
	native_static_sync_diagnostics["last_failure_reason"] = ""
	_refresh_native_static_diagnostics()
	return {
		"handled": true,
		"force_full_csg": false,
		"operand_pending": true,
		"reason": reason,
		"presentation_descriptor": presentation,
	}


func _ensure_native_capsule_operand_staging_root() -> void:
	if (
		native_capsule_operand_staging_root != null
		and is_instance_valid(native_capsule_operand_staging_root)
	):
		return
	native_capsule_operand_staging_root = get_node_or_null(
		"NativeCapsuleOperandStagingRoot"
	) as Node3D
	if native_capsule_operand_staging_root == null:
		native_capsule_operand_staging_root = Node3D.new()
		native_capsule_operand_staging_root.name = (
			"NativeCapsuleOperandStagingRoot"
		)
		add_child(native_capsule_operand_staging_root)
	# Hidden nodes still receive Godot's deferred CSG mesh update, matching the
	# already-proven protected-Handle bootstrap path without drawing duplicates.
	native_capsule_operand_staging_root.visible = false


func _request_native_capsule_operand_bake(
	body: Resource,
	signature: String
) -> Dictionary:
	if body == null or signature.is_empty():
		return {"ok": false, "reason": "capsule_operand_request_invalid"}
	if native_capsule_operand_pending.has(signature):
		return {"ok": true, "pending": true}
	_ensure_native_capsule_operand_staging_root()
	if (
		native_capsule_operand_staging_root == null
		or not is_instance_valid(native_capsule_operand_staging_root)
		or not native_capsule_operand_staging_root.is_inside_tree()
	):
		return {"ok": false, "reason": "capsule_operand_staging_unavailable"}
	var request_count := int(native_static_sync_diagnostics.get(
		"capsule_operand_request_count",
		0
	)) + 1
	native_static_sync_diagnostics["capsule_operand_request_count"] = (
		request_count
	)
	var staging_combiner := CSGCombiner3D.new()
	staging_combiner.name = "NativeCapsuleOperand_%06d" % request_count
	staging_combiner.operation = CSGShape3D.OPERATION_UNION
	staging_combiner.calculate_tangents = false
	staging_combiner.use_collision = false
	staging_combiner.collision_layer = 0
	staging_combiner.collision_mask = 0
	staging_combiner.visible = true
	native_capsule_operand_staging_root.add_child(staging_combiner)
	if not _append_csg_body_shape(
		staging_combiner,
		body,
		StringName(body.get("material_variant_id")),
		false,
		0
	):
		staging_combiner.free()
		return {"ok": false, "reason": "capsule_operand_shape_build_failed"}
	var request_generation := native_capsule_operand_generation
	native_capsule_operand_pending[signature] = {
		"signature": signature,
		"body": body,
		"body_id": StringName(body.get("body_id")),
		"node": staging_combiner,
		"generation": request_generation,
		"start_usec": Time.get_ticks_usec(),
		"packet_ready": false,
		"accepted_revision": -1,
	}
	_refresh_native_capsule_operand_diagnostics()
	_bake_native_capsule_operand_after_update(signature, request_generation)
	return {"ok": true, "pending": true}


func _bake_native_capsule_operand_after_update(
	signature: String,
	request_generation: int
) -> void:
	for _readiness_frame in range(NATIVE_CAPSULE_OPERAND_BAKE_FRAME_LIMIT):
		await get_tree().process_frame
		if request_generation != native_capsule_operand_generation:
			return
		var pending_entry := native_capsule_operand_pending.get(
			signature,
			{}
		) as Dictionary
		var staging_combiner := pending_entry.get(
			"node",
			null
		) as CSGCombiner3D
		if (
			staging_combiner == null
			or not is_instance_valid(staging_combiner)
			or not staging_combiner.is_inside_tree()
		):
			return
		if not _csg_shape_generated_mesh_is_ready(staging_combiner):
			continue
		var bake_start_usec := Time.get_ticks_usec()
		var baked_mesh := staging_combiner.bake_static_mesh()
		var bake_ms := float(
			Time.get_ticks_usec() - bake_start_usec
		) / 1000.0
		var flatten_result := (
			_flatten_native_protected_handle_baked_mesh(
				baked_mesh,
				signature
			)
			if baked_mesh != null
			else {
				"ok": false,
				"reason": "capsule_operand_bake_returned_empty",
			}
		)
		if not bool(flatten_result.get("ok", false)):
			_record_native_capsule_operand_failure(
				signature,
				String(flatten_result.get(
					"reason",
					"capsule_operand_flatten_failed"
				))
			)
			return
		flatten_result["signature"] = signature
		flatten_result["source"] = "deferred_exact_csg"
		native_capsule_operand_cache[signature] = flatten_result
		_touch_native_capsule_operand_cache_key(signature)
		_trim_native_capsule_operand_cache()
		pending_entry["node"] = null
		pending_entry["packet_ready"] = true
		pending_entry["packet"] = flatten_result
		pending_entry["ready_ms"] = float(
			Time.get_ticks_usec() - int(pending_entry.get(
				"start_usec",
				Time.get_ticks_usec()
			))
		) / 1000.0
		native_capsule_operand_pending[signature] = pending_entry
		staging_combiner.free()
		native_static_sync_diagnostics["capsule_operand_bake_count"] = int(
			native_static_sync_diagnostics.get(
				"capsule_operand_bake_count",
				0
			)
		) + 1
		native_static_sync_diagnostics["capsule_operand_last_ready_ms"] = float(
			pending_entry.get("ready_ms", 0.0)
		)
		native_static_sync_diagnostics["capsule_operand_last_bake_ms"] = bake_ms
		_refresh_native_capsule_operand_diagnostics()
		call_deferred("_retry_native_capsule_operand_sync")
		return
	_record_native_capsule_operand_failure(
		signature,
		"capsule_operand_not_ready_after_frame_limit"
	)


func _record_native_capsule_operand_failure(
	signature: String,
	reason: String
) -> void:
	var pending_entry := native_capsule_operand_pending.get(
		signature,
		{}
	) as Dictionary
	var staging_combiner := pending_entry.get("node", null) as CSGCombiner3D
	if staging_combiner != null and is_instance_valid(staging_combiner):
		staging_combiner.free()
	native_capsule_operand_pending.erase(signature)
	var failure := {
		"ok": false,
		"pending": false,
		"signature": signature,
		"reason": reason,
	}
	native_capsule_operand_failures[signature] = failure
	native_static_sync_diagnostics["capsule_operand_failure_count"] = int(
		native_static_sync_diagnostics.get(
			"capsule_operand_failure_count",
			0
		)
	) + 1
	_refresh_native_capsule_operand_diagnostics()
	call_deferred("_retry_native_capsule_operand_sync")


func _retry_native_capsule_operand_sync() -> void:
	if not is_inside_tree() or active_stage_controller == null:
		return
	_sync_from_controller()


func _touch_native_capsule_operand_cache_key(signature: String) -> void:
	var prior_index := native_capsule_operand_cache_order.find(signature)
	if prior_index >= 0:
		native_capsule_operand_cache_order.remove_at(prior_index)
	native_capsule_operand_cache_order.append(signature)


func _trim_native_capsule_operand_cache() -> void:
	while (
		native_capsule_operand_cache_order.size()
		> NATIVE_CAPSULE_OPERAND_CACHE_CAPACITY
	):
		var stale_signature: String = String(
			native_capsule_operand_cache_order.pop_front()
		)
		native_capsule_operand_cache.erase(stale_signature)
	_refresh_native_capsule_operand_diagnostics()


func _refresh_native_capsule_operand_diagnostics() -> void:
	native_static_sync_diagnostics["capsule_operand_pending_count"] = (
		native_capsule_operand_pending.size()
	)
	native_static_sync_diagnostics["capsule_operand_cache_count"] = (
		native_capsule_operand_cache.size()
	)


func _mark_native_capsule_operand_previews_accepted(
	bodies: Array,
	revision: int
) -> void:
	if revision < 0:
		return
	for body_variant: Variant in bodies:
		var body := body_variant as Resource
		if body == null or not _is_native_capsule_shape_kind(
			StringName(body.get("shape_kind"))
		):
			continue
		var signature := _build_native_static_body_signature(body)
		if not native_capsule_operand_pending.has(signature):
			continue
		var pending_entry := native_capsule_operand_pending.get(
			signature,
			{}
		) as Dictionary
		if not bool(pending_entry.get("packet_ready", false)):
			continue
		pending_entry["accepted_revision"] = revision
		native_capsule_operand_pending[signature] = pending_entry
	_refresh_native_capsule_operand_diagnostics()


func _prune_native_capsule_operand_previews_to_bodies(
	bodies: Array
) -> void:
	var retained_signatures: Dictionary = {}
	for body_variant: Variant in bodies:
		var body := body_variant as Resource
		if body == null:
			continue
		retained_signatures[_build_native_static_body_signature(body)] = true
	var stale_signatures: Array[String] = []
	for signature_variant: Variant in native_capsule_operand_pending.keys():
		var signature := String(signature_variant)
		if retained_signatures.has(signature):
			continue
		var pending_entry := native_capsule_operand_pending.get(
			signature,
			{}
		) as Dictionary
		var staging_node := pending_entry.get("node", null) as Node
		if staging_node != null and is_instance_valid(staging_node):
			staging_node.free()
		stale_signatures.append(signature)
	for signature: String in stale_signatures:
		native_capsule_operand_pending.erase(signature)
	_refresh_native_capsule_operand_diagnostics()


func _clear_native_capsule_operand_previews_through_revision(
	published_revision: int
) -> void:
	var completed_signatures: Array[String] = []
	for signature_variant: Variant in native_capsule_operand_pending.keys():
		var signature := String(signature_variant)
		var pending_entry := native_capsule_operand_pending.get(
			signature,
			{}
		) as Dictionary
		var accepted_revision := int(pending_entry.get(
			"accepted_revision",
			-1
		))
		if accepted_revision >= 0 and accepted_revision <= published_revision:
			completed_signatures.append(signature)
	for signature: String in completed_signatures:
		native_capsule_operand_pending.erase(signature)
	_refresh_native_capsule_operand_diagnostics()


func _accept_native_static_result(
	native_result: Dictionary,
	static_bodies: Array,
	mode: String
) -> Dictionary:
	if not bool(native_result.get("ok", false)):
		return _reject_native_static_fast_lane(
			"native_%s_failed:%s:%s" % [
				mode,
				String(native_result.get("error_code", "unknown")),
				String(native_result.get("error_message", "unknown")),
			]
		)
	if not bool(native_result.get("committed", false)):
		return _reject_native_static_fast_lane(
			"native_%s_did_not_commit" % mode
		)
	if int(native_result.get("previous_revision", -1)) != native_static_expected_revision:
		return _reject_native_static_fast_lane(
			"native_%s_previous_revision_mismatch" % mode
		)
	var committed_revision := int(native_result.get("revision", -1))
	if committed_revision != native_static_expected_revision + 1:
		return _reject_native_static_fast_lane(
			"native_%s_revision_mismatch" % mode
		)
	if not bool(native_result.get("state_initialized", false)):
		return _reject_native_static_fast_lane(
			"native_%s_state_not_initialized" % mode
		)
	var output_vertices: PackedVector3Array = native_result.get(
		"vertices",
		PackedVector3Array()
	)
	var output_indices: PackedInt32Array = native_result.get(
		"indices",
		PackedInt32Array()
	)
	if output_vertices.is_empty() or output_indices.is_empty():
		return _reject_native_static_fast_lane(
			"native_%s_output_empty" % mode
		)
	if output_indices.size() % 3 != 0:
		return _reject_native_static_fast_lane(
			"native_%s_output_indices_invalid" % mode
		)
	var revision_result := _build_native_static_revision_node(
		output_vertices,
		output_indices,
		static_bodies,
		committed_revision
	)
	if not bool(revision_result.get("ok", false)):
		return _reject_native_static_fast_lane(String(
			revision_result.get("reason", "native_publication_build_failed")
		))
	_mark_native_capsule_operand_previews_accepted(
		static_bodies,
		committed_revision
	)
	if mode == "reset":
		_capture_native_static_prefix(static_bodies)
	else:
		_append_native_static_prefix(static_bodies[static_bodies.size() - 1] as Resource)
	native_static_expected_revision = committed_revision
	native_static_lifecycle = NATIVE_STATIC_LIFECYCLE_ACTIVE
	native_static_state_initialized = true
	native_static_active_vertices = output_vertices
	native_static_active_indices = output_indices
	if not _begin_native_static_publication(
		revision_result.get("node", null) as Node3D,
		committed_revision
	):
		return _reject_native_static_fast_lane(
			"native_publication_stage_failed"
		)
	native_static_sync_diagnostics["last_mode"] = mode
	native_static_sync_diagnostics["last_failure_reason"] = ""
	native_static_sync_diagnostics["last_native_total_ms"] = float(
		native_result.get("total_native_ms", 0.0)
	)
	native_static_sync_diagnostics["output_vertices"] = output_vertices.size()
	native_static_sync_diagnostics["output_triangles"] = output_indices.size() / 3
	_capture_native_static_history_diagnostics(native_result)
	if mode == "reset":
		native_static_sync_diagnostics["reset_count"] = int(
			native_static_sync_diagnostics.get("reset_count", 0)
		) + 1
	else:
		native_static_sync_diagnostics["append_count"] = int(
			native_static_sync_diagnostics.get("append_count", 0)
		) + 1
	_refresh_native_static_diagnostics()
	return {"handled": true, "force_full_csg": false}


func _capture_native_static_prefix(static_bodies: Array) -> void:
	native_static_body_order_snapshot = []
	native_static_body_signatures_by_id = {}
	native_static_body_bounds_by_id = {}
	native_static_material_variant_id = StringName()
	for body_variant: Variant in static_bodies:
		if not (body_variant is Resource):
			continue
		var body := body_variant as Resource
		if body == null:
			continue
		var body_id := StringName(body.get("body_id"))
		native_static_body_order_snapshot.append(body_id)
		native_static_body_signatures_by_id[body_id] = (
			_build_native_static_body_signature(body)
		)
		native_static_body_bounds_by_id[body_id] = _build_csg_body_bounds(
			body
		)
		if native_static_material_variant_id == StringName():
			native_static_material_variant_id = StringName(
				body.get("material_variant_id")
			)


func _append_native_static_prefix(body: Resource) -> void:
	if body == null:
		return
	var body_id := StringName(body.get("body_id"))
	native_static_body_order_snapshot.append(body_id)
	native_static_body_signatures_by_id[body_id] = (
		_build_native_static_body_signature(body)
	)
	native_static_body_bounds_by_id[body_id] = _build_csg_body_bounds(body)


func _validate_native_static_runtime_state(
	allow_empty_state: bool = false
) -> Dictionary:
	if (
		native_static_manifold_backend == null
		or not is_instance_valid(native_static_manifold_backend)
	):
		return {"ok": false, "reason": "native_backend_lost"}
	if native_static_body_root == null or not is_instance_valid(native_static_body_root):
		return {"ok": false, "reason": "native_root_lost"}
	var state_info := native_static_manifold_backend.call(
		"get_state_info"
	) as Dictionary
	if (
		not bool(state_info.get("ok", false))
		or int(state_info.get("revision", -1))
		!= native_static_expected_revision
	):
		return {"ok": false, "reason": "native_backend_state_mismatch"}
	var state_initialized := bool(state_info.get(
		"state_initialized",
		false
	))
	if not state_initialized and not allow_empty_state:
		return {"ok": false, "reason": "native_backend_state_empty"}
	if (
		native_static_lifecycle == NATIVE_STATIC_LIFECYCLE_ACTIVE
		and state_initialized != native_static_state_initialized
	):
		return {"ok": false, "reason": "native_initialized_state_mismatch"}
	if state_initialized and native_static_authoritative and (
		native_static_published_node == null
		or not is_instance_valid(native_static_published_node)
	):
		return {"ok": false, "reason": "native_publication_lost"}
	if native_static_publication_pending and (
		native_static_staged_node == null
		or not is_instance_valid(native_static_staged_node)
	):
		return {"ok": false, "reason": "native_stage_lost"}
	if (
		state_initialized
		and not native_static_authoritative
		and not native_static_publication_pending
	):
		return {"ok": false, "reason": "native_publication_state_empty"}
	_capture_native_static_history_diagnostics(state_info)
	return {"ok": true, "state_info": state_info}


func _build_native_static_revision_node(
	vertices: PackedVector3Array,
	indices: PackedInt32Array,
	static_bodies: Array,
	revision: int,
	identity_descriptor: Dictionary = {}
) -> Dictionary:
	for index_value: int in indices:
		if index_value < 0 or index_value >= vertices.size():
			return {"ok": false, "reason": "native_index_out_of_range"}
	var protected_validation := _validate_bounded_protected_handle_lane(
		identity_descriptor,
		identity_descriptor
	)
	if not bool(protected_validation.get("ok", false)):
		return protected_validation
	var protected_handle := protected_validation.get(
		"protected_handle",
		null
	) as Resource
	if protected_handle != null:
		var live_decomposition_result := (
			_try_build_native_static_protected_live_decomposition_revision_node(
				vertices,
				indices,
				static_bodies,
				revision,
				identity_descriptor,
				protected_handle
			)
		)
		if bool(live_decomposition_result.get("ok", false)):
			return live_decomposition_result
		var live_failure_reason := String(live_decomposition_result.get(
			"reason",
			"native_protected_live_decomposition_unavailable"
		))
		if live_failure_reason == "protected_handle_exact_cache_missing":
			_capture_native_protected_handle_bootstrap_pending()
		else:
			_capture_native_protected_composition_fallback(
				live_failure_reason
			)
		return _build_native_static_handle_composite_revision_node(
			vertices,
			indices,
			static_bodies,
			revision,
			identity_descriptor,
			protected_handle
		)
	if vertices.is_empty() or indices.is_empty() or indices.size() % 3 != 0:
		return {"ok": false, "reason": "native_output_mesh_invalid"}
	var surface_tool := SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index_value: int in indices:
		surface_tool.add_vertex(vertices[index_value])
	surface_tool.index()
	surface_tool.generate_normals()
	var render_mesh: ArrayMesh = surface_tool.commit()
	if render_mesh == null or render_mesh.get_surface_count() != 1:
		return {"ok": false, "reason": "native_render_mesh_build_failed"}
	var faces := PackedVector3Array()
	faces.resize(indices.size())
	for index_position in range(indices.size()):
		faces[index_position] = vertices[indices[index_position]]
	var identity := _build_native_static_surface_identity(
		static_bodies,
		identity_descriptor
	)
	var material_variant_id := StringName(identity.get(
		"material_variant_id",
		StringName()
	))
	var body_id := StringName(identity.get("body_id", StringName()))
	var surface_target_id := StringName(identity.get(
		"surface_target_id",
		StringName()
	))
	if material_variant_id == StringName() or surface_target_id == StringName():
		return {"ok": false, "reason": "native_surface_identity_invalid"}
	var revision_node := Node3D.new()
	revision_node.name = "NativeStaticMaterialBodyRevision_%06d" % revision
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "NativeStaticMaterialBodyMesh"
	mesh_instance.mesh = render_mesh
	mesh_instance.material_override = _build_csg_body_material(
		material_variant_id,
		false
	)
	revision_node.add_child(mesh_instance)
	var collision_body := StaticBody3D.new()
	collision_body.name = "NativeStaticMaterialBodyCollision"
	collision_body.collision_layer = 0
	collision_body.collision_mask = 0
	var collision_shape := CollisionShape3D.new()
	collision_shape.name = "NativeStaticMaterialBodyShape"
	var concave_shape := ConcavePolygonShape3D.new()
	# Native Manifold packets can retain inward-facing triangle winding. Forge
	# authoring must remain targetable from the camera side regardless of winding.
	concave_shape.backface_collision = true
	concave_shape.set_faces(faces)
	collision_shape.shape = concave_shape
	collision_body.add_child(collision_shape)
	revision_node.add_child(collision_body)
	revision_node.visible = false
	_configure_native_static_revision_metadata(
		revision_node,
		material_variant_id,
		body_id,
		surface_target_id,
		revision,
		false,
		true
	)
	return {"ok": true, "node": revision_node}


func _try_build_native_static_protected_live_decomposition_revision_node(
	vertices: PackedVector3Array,
	indices: PackedInt32Array,
	static_bodies: Array,
	revision: int,
	identity_descriptor: Dictionary,
	protected_handle: Resource
) -> Dictionary:
	_reset_native_protected_live_decomposition_diagnostics()
	native_static_sync_diagnostics[
		"protected_live_decomposition_attempt_count"
	] = int(native_static_sync_diagnostics.get(
		"protected_live_decomposition_attempt_count",
		0
	)) + 1
	if protected_handle == null:
		return _fail_native_protected_live_decomposition(
			"protected_handle_missing"
		)
	var backend_result := _ensure_native_static_backend()
	if not bool(backend_result.get("ok", false)):
		return _fail_native_protected_live_decomposition(String(
			backend_result.get(
				"reason",
				"native_protected_live_backend_unavailable"
			)
		))
	var final_compose_method := (
		_resolve_native_protected_final_compose_method()
	)
	var full_compose_available := not final_compose_method.is_empty()
	native_static_sync_diagnostics[
		"protected_live_final_compose_method"
	] = final_compose_method
	native_static_sync_diagnostics[
		"protected_live_full_compose_available"
	] = full_compose_available
	var protected_signature := PrimaryGripHandleMeshPacketScript.build_body_signature(
		protected_handle
	)
	var protected_packet := _resolve_authoritative_protected_handle_packet(
		protected_handle
	)
	if not bool(protected_packet.get("ok", false)):
		return _fail_native_protected_live_decomposition(String(
			protected_packet.get(
				"reason",
				"protected_handle_exact_cache_missing"
			)
		))
	var protected_vertices: PackedVector3Array = protected_packet.get(
		"vertices",
		PackedVector3Array()
	)
	var protected_indices: PackedInt32Array = protected_packet.get(
		"indices",
		PackedInt32Array()
	)
	var has_aggregate := not vertices.is_empty() or not indices.is_empty()
	if (
		has_aggregate
		and (
			vertices.is_empty()
			or indices.is_empty()
			or indices.size() % 3 != 0
		)
	):
		return _fail_native_protected_live_decomposition(
			"native_aggregate_mesh_invalid"
		)
	if not has_aggregate:
		var lane_combine_started_usec := Time.get_ticks_usec()
		var handle_sources := PackedInt32Array()
		handle_sources.resize(protected_indices.size() / 3)
		for source_index in range(handle_sources.size()):
			handle_sources[source_index] = 1
		native_static_sync_diagnostics[
			"protected_live_lane_array_combine_ms"
		] = float(
			Time.get_ticks_usec() - lane_combine_started_usec
		) / 1000.0
		var handle_only_metadata := _build_native_protected_live_lane_metadata(
			protected_signature,
			PackedVector3Array(),
			PackedInt32Array(),
			0,
			0,
			protected_vertices,
			protected_indices,
			revision,
			"handle_only_cached_exact",
			final_compose_method,
			full_compose_available,
			false
		)
		var handle_only_result := (
			_build_native_static_protected_direct_revision_node(
				protected_vertices,
				protected_indices,
				handle_sources,
				static_bodies,
				revision,
				identity_descriptor,
				protected_handle,
				&"native_protected_live_decomposition",
				handle_only_metadata
			)
		)
		if not bool(handle_only_result.get("ok", false)):
			return _fail_native_protected_live_decomposition(String(
				handle_only_result.get(
					"reason",
					"native_protected_handle_only_publication_failed"
				)
			))
		_capture_native_protected_handle_only_success(
			protected_vertices.size(),
			protected_indices.size() / 3
		)
		_capture_native_protected_live_decomposition_success(
			{
				"vertices": protected_vertices,
				"indices": protected_indices,
				"ordinary_triangle_count": 0,
				"protected_triangle_count": protected_indices.size() / 3,
				"subtraction_triangle_count": 0,
				"source_state_revision": revision,
			},
			PackedVector3Array(),
			PackedInt32Array(),
			protected_vertices,
			protected_indices,
			"handle_only_cached_exact",
			false
		)
		return handle_only_result
	if (
		native_static_manifold_backend == null
		or not is_instance_valid(native_static_manifold_backend)
	):
		return _fail_native_protected_live_decomposition(
			"native_protected_live_backend_missing"
		)
	const clip_method := "clip_current_state_with_protected_mesh"
	if not native_static_manifold_backend.has_method(clip_method):
		return _fail_native_protected_live_decomposition(
			"native_protected_live_clip_capability_missing"
		)
	native_static_sync_diagnostics[
		"protected_live_backend_method"
	] = clip_method
	native_static_sync_diagnostics[
		"protected_composition_backend_method"
	] = clip_method
	var clip_variant: Variant = native_static_manifold_backend.call(
		clip_method,
		protected_vertices,
		protected_indices
	)
	if not clip_variant is Dictionary:
		return _fail_native_protected_live_decomposition(
			"native_protected_live_clip_result_not_dictionary"
		)
	var clip_result := clip_variant as Dictionary
	_capture_native_protected_composition_timings(clip_result)
	_capture_native_protected_live_clip_timings(clip_result)
	var clip_validation := _validate_native_protected_live_clip_packet(
		clip_result,
		revision
	)
	if not bool(clip_validation.get("ok", false)):
		return _fail_native_protected_live_decomposition(String(
			clip_validation.get(
				"reason",
				"native_protected_live_clip_invalid"
			)
		))
	var lane_combine_started_usec := Time.get_ticks_usec()
	var combined_result := _combine_native_protected_live_lanes(
		clip_validation,
		protected_packet
	)
	native_static_sync_diagnostics[
		"protected_live_lane_array_combine_ms"
	] = float(
		Time.get_ticks_usec() - lane_combine_started_usec
	) / 1000.0
	if not bool(combined_result.get("ok", false)):
		return _fail_native_protected_live_decomposition(String(
			combined_result.get(
				"reason",
				"native_protected_live_lane_combine_failed"
			)
		))
	var clipped_vertices: PackedVector3Array = clip_validation.get(
		"vertices",
		PackedVector3Array()
	)
	var clipped_indices: PackedInt32Array = clip_validation.get(
		"indices",
		PackedInt32Array()
	)
	var source_state_revision := int(clip_validation.get(
		"source_state_revision",
		-1
	))
	var has_clipped_lane := not clipped_indices.is_empty()
	var lane_metadata := _build_native_protected_live_lane_metadata(
		protected_signature,
		clipped_vertices,
		clipped_indices,
		int(clip_validation.get("ordinary_triangle_count", 0)),
		int(clip_validation.get("subtraction_triangle_count", 0)),
		protected_vertices,
		protected_indices,
		source_state_revision,
		clip_method,
		final_compose_method,
		full_compose_available,
		has_clipped_lane
	)
	var direct_result := _build_native_static_protected_direct_revision_node(
		combined_result.get("vertices", PackedVector3Array()) as PackedVector3Array,
		combined_result.get("indices", PackedInt32Array()) as PackedInt32Array,
		combined_result.get(
			"source_original_ids",
			PackedInt32Array()
		) as PackedInt32Array,
		static_bodies,
		revision,
		identity_descriptor,
		protected_handle,
		&"native_protected_live_decomposition",
		lane_metadata
	)
	if not bool(direct_result.get("ok", false)):
		return _fail_native_protected_live_decomposition(String(
			direct_result.get(
				"reason",
				"native_protected_live_publication_failed"
			)
		))
	_capture_native_protected_live_decomposition_success(
		combined_result,
		clipped_vertices,
		clipped_indices,
		protected_vertices,
		protected_indices,
		clip_method,
		has_clipped_lane
	)
	return direct_result


func _validate_native_protected_live_clip_packet(
	packet: Dictionary,
	expected_revision: int
) -> Dictionary:
	if not bool(packet.get("ok", false)):
		return {
			"ok": false,
			"reason": "native_protected_live_clip_failed:%s:%s" % [
				String(packet.get("error_code", "unknown")),
				String(packet.get("error_message", "unknown")),
			],
		}
	if String(packet.get("status", "NotRun")) != "NoError":
		return {
			"ok": false,
			"reason": "native_protected_live_clip_status_invalid",
		}
	if not bool(packet.get("watertight", false)):
		return {
			"ok": false,
			"reason": "native_protected_live_clip_not_watertight",
		}
	var source_state_revision := int(packet.get(
		"source_state_revision",
		-1
	))
	if source_state_revision != expected_revision:
		return {
			"ok": false,
			"reason": "native_protected_live_clip_state_revision_mismatch",
		}
	if (
		String(packet.get("source_id_semantics", ""))
		!= "0=ordinary_base,2=subtraction_cut"
		or not packet.has("base_source_triangle_count")
		or not packet.has("subtraction_source_triangle_count")
		or int(packet.get("protected_source_triangle_count", -1)) != 0
	):
		return {
			"ok": false,
			"reason": "native_protected_live_clip_source_schema_invalid",
		}
	var vertices_variant: Variant = packet.get(
		"vertices",
		PackedVector3Array()
	)
	var indices_variant: Variant = packet.get(
		"indices",
		PackedInt32Array()
	)
	var source_ids_variant: Variant = packet.get(
		"source_original_ids",
		packet.get("source_ids", PackedInt32Array())
	)
	if (
		not vertices_variant is PackedVector3Array
		or not indices_variant is PackedInt32Array
		or not source_ids_variant is PackedInt32Array
	):
		return {
			"ok": false,
			"reason": "native_protected_live_clip_packet_types_invalid",
		}
	var vertices := vertices_variant as PackedVector3Array
	var indices := indices_variant as PackedInt32Array
	var source_ids := source_ids_variant as PackedInt32Array
	if (
		indices.size() % 3 != 0
		or vertices.is_empty() != indices.is_empty()
	):
		return {
			"ok": false,
			"reason": "native_protected_live_clip_mesh_invalid",
		}
	var triangle_count := indices.size() / 3
	if source_ids.size() != triangle_count:
		return {
			"ok": false,
			"reason": "native_protected_live_clip_source_count_mismatch",
		}
	if (
		int(packet.get("output_vertex_count", -1)) != vertices.size()
		or int(packet.get("output_triangle_count", -1)) != triangle_count
	):
		return {
			"ok": false,
			"reason": "native_protected_live_clip_output_count_mismatch",
		}
	var source_face_ids_variant: Variant = packet.get(
		"source_face_ids",
		PackedInt32Array()
	)
	if (
		not source_face_ids_variant is PackedInt32Array
		or (
			(source_face_ids_variant as PackedInt32Array).size() > 0
			and (source_face_ids_variant as PackedInt32Array).size()
			!= triangle_count
		)
	):
		return {
			"ok": false,
			"reason": "native_protected_live_clip_face_count_mismatch",
		}
	var ordinary_triangle_count := 0
	var subtraction_triangle_count := 0
	for triangle_index in range(triangle_count):
		var source_id := source_ids[triangle_index]
		if source_id == 0:
			ordinary_triangle_count += 1
		elif source_id == 2:
			subtraction_triangle_count += 1
		else:
			return {
				"ok": false,
				"reason": "native_protected_live_clip_source_id_invalid",
			}
		var offset := triangle_index * 3
		var a := indices[offset]
		var b := indices[offset + 1]
		var c := indices[offset + 2]
		if (
			a < 0
			or b < 0
			or c < 0
			or a >= vertices.size()
			or b >= vertices.size()
			or c >= vertices.size()
			or a == b
			or b == c
			or c == a
		):
			return {
				"ok": false,
				"reason": "native_protected_live_clip_index_invalid",
			}
	if (
		int(packet.get("base_source_triangle_count", -1))
		!= ordinary_triangle_count
		or int(packet.get("subtraction_source_triangle_count", -1))
		!= subtraction_triangle_count
	):
		return {
			"ok": false,
			"reason": "native_protected_live_clip_region_count_mismatch",
		}
	return {
		"ok": true,
		"vertices": vertices,
		"indices": indices,
		"source_original_ids": source_ids,
		"ordinary_triangle_count": ordinary_triangle_count,
		"protected_triangle_count": 0,
		"subtraction_triangle_count": subtraction_triangle_count,
		"source_state_revision": source_state_revision,
	}


func _combine_native_protected_live_lanes(
	clip_packet: Dictionary,
	protected_packet: Dictionary
) -> Dictionary:
	var clipped_vertices: PackedVector3Array = clip_packet.get(
		"vertices",
		PackedVector3Array()
	)
	var clipped_indices: PackedInt32Array = clip_packet.get(
		"indices",
		PackedInt32Array()
	)
	var clipped_sources: PackedInt32Array = clip_packet.get(
		"source_original_ids",
		PackedInt32Array()
	)
	var protected_vertices: PackedVector3Array = protected_packet.get(
		"vertices",
		PackedVector3Array()
	)
	var protected_indices: PackedInt32Array = protected_packet.get(
		"indices",
		PackedInt32Array()
	)
	if (
		protected_vertices.is_empty()
		or protected_indices.is_empty()
		or protected_indices.size() % 3 != 0
		or clipped_indices.size() % 3 != 0
		or clipped_sources.size() != clipped_indices.size() / 3
	):
		return {
			"ok": false,
			"reason": "native_protected_live_lane_packet_invalid",
		}
	var combined_vertices := PackedVector3Array()
	combined_vertices.append_array(clipped_vertices)
	var protected_vertex_offset := combined_vertices.size()
	combined_vertices.append_array(protected_vertices)
	var combined_indices := PackedInt32Array()
	combined_indices.append_array(clipped_indices)
	for protected_index: int in protected_indices:
		if protected_index < 0 or protected_index >= protected_vertices.size():
			return {
				"ok": false,
				"reason": "native_protected_live_handle_index_invalid",
			}
		combined_indices.append(protected_index + protected_vertex_offset)
	var combined_sources := PackedInt32Array()
	combined_sources.append_array(clipped_sources)
	for _triangle_index in range(protected_indices.size() / 3):
		combined_sources.append(1)
	return {
		"ok": true,
		"vertices": combined_vertices,
		"indices": combined_indices,
		"source_original_ids": combined_sources,
		"ordinary_triangle_count": int(clip_packet.get(
			"ordinary_triangle_count",
			0
		)),
		"protected_triangle_count": protected_indices.size() / 3,
		"subtraction_triangle_count": int(clip_packet.get(
			"subtraction_triangle_count",
			0
		)),
		"source_state_revision": int(clip_packet.get(
			"source_state_revision",
			-1
		)),
	}


func _build_native_protected_live_lane_metadata(
	protected_signature: String,
	clipped_vertices: PackedVector3Array,
	clipped_indices: PackedInt32Array,
	clipped_ordinary_triangle_count: int,
	clipped_subtraction_triangle_count: int,
	protected_vertices: PackedVector3Array,
	protected_indices: PackedInt32Array,
	source_state_revision: int,
	backend_method: String,
	final_compose_method: String,
	full_compose_available: bool,
	has_ordinary_lane: bool
) -> Dictionary:
	var clipped_source_ids := PackedInt32Array()
	if clipped_ordinary_triangle_count > 0:
		clipped_source_ids.append(0)
	if clipped_subtraction_triangle_count > 0:
		clipped_source_ids.append(2)
	var handle_source_ids := PackedInt32Array([1])
	return {
		"forge_v2_native_live_unfused_geometry": has_ordinary_lane,
		"forge_v2_native_live_lane_count": 2 if has_ordinary_lane else 1,
		"forge_v2_native_live_logical_component_count": 2 if has_ordinary_lane else 1,
		"forge_v2_native_live_handle_packet_reused": true,
		"forge_v2_native_live_combined_collision": true,
		"forge_v2_native_live_final_union_performed": false,
		"forge_v2_native_live_clipped_vertex_count": clipped_vertices.size(),
		"forge_v2_native_live_clipped_triangle_count": clipped_indices.size() / 3,
		"forge_v2_native_live_clipped_ordinary_triangle_count": clipped_ordinary_triangle_count,
		"forge_v2_native_live_clipped_subtraction_triangle_count": clipped_subtraction_triangle_count,
		"forge_v2_native_live_clipped_source_ids": clipped_source_ids,
		"forge_v2_native_live_handle_signature": protected_signature,
		"forge_v2_native_live_handle_vertex_count": protected_vertices.size(),
		"forge_v2_native_live_handle_triangle_count": protected_indices.size() / 3,
		"forge_v2_native_live_handle_source_ids": handle_source_ids,
		"forge_v2_native_live_source_state_revision": source_state_revision,
		"forge_v2_native_live_backend_method": backend_method,
		"forge_v2_native_final_compose_method": final_compose_method,
		"forge_v2_native_final_compose_available": full_compose_available,
	}


func _resolve_native_protected_final_compose_method() -> String:
	if (
		native_static_manifold_backend == null
		or not is_instance_valid(native_static_manifold_backend)
	):
		return ""
	if native_static_manifold_backend.has_method(
		"compose_current_state_with_protected_mesh"
	):
		return "compose_current_state_with_protected_mesh"
	if native_static_manifold_backend.has_method(
		"compose_with_protected_mesh"
	):
		return "compose_with_protected_mesh"
	return ""


func _reset_native_protected_live_decomposition_diagnostics() -> void:
	for timing_field: String in [
		"protected_composition_total_ms",
		"protected_composition_imports_ms",
		"protected_composition_boolean_ms",
		"protected_composition_subtract_ms",
		"protected_composition_union_ms",
		"protected_composition_export_ms",
	]:
		native_static_sync_diagnostics[timing_field] = 0.0
	for count_field: String in [
		"protected_composition_output_vertices",
		"protected_composition_output_triangles",
		"protected_composition_ordinary_triangles",
		"protected_composition_protected_triangles",
		"protected_composition_subtraction_triangles",
	]:
		native_static_sync_diagnostics[count_field] = 0
	native_static_sync_diagnostics[
		"protected_composition_backend_method"
	] = ""
	native_static_sync_diagnostics[
		"protected_composition_source_state_revision"
	] = -1
	for timing_field: String in [
		"protected_live_clip_total_ms",
		"protected_live_clip_imports_ms",
		"protected_live_clip_subtract_ms",
		"protected_live_clip_export_ms",
		"protected_live_lane_array_combine_ms",
		"protected_live_material_region_array_mesh_ms",
		"protected_live_collision_face_expansion_ms",
		"protected_live_collision_set_faces_cook_ms",
		"protected_live_node_metadata_setup_ms",
		"protected_live_direct_build_total_ms",
	]:
		native_static_sync_diagnostics[timing_field] = 0.0
	for count_field: String in [
		"protected_live_clip_vertices",
		"protected_live_clip_triangles",
		"protected_live_clip_ordinary_triangles",
		"protected_live_clip_subtraction_triangles",
		"protected_live_handle_vertices",
		"protected_live_handle_triangles",
		"protected_live_combined_vertices",
		"protected_live_combined_triangles",
		"protected_live_lane_count",
	]:
		native_static_sync_diagnostics[count_field] = 0
	native_static_sync_diagnostics[
		"protected_live_decomposition_last_failure_reason"
	] = ""
	native_static_sync_diagnostics["protected_live_backend_method"] = ""
	native_static_sync_diagnostics[
		"protected_live_source_state_revision"
	] = -1
	native_static_sync_diagnostics[
		"protected_live_unfused_geometry"
	] = false
	native_static_sync_diagnostics[
		"protected_live_handle_packet_reused"
	] = false
	native_static_sync_diagnostics[
		"protected_live_combined_collision"
	] = false
	native_static_sync_diagnostics[
		"protected_live_final_union_performed"
	] = false
	native_static_sync_diagnostics[
		"protected_live_final_compose_method"
	] = ""
	native_static_sync_diagnostics[
		"protected_live_full_compose_available"
	] = false
	native_static_sync_diagnostics[
		"protected_handle_bootstrap_pending"
	] = false


func _capture_native_protected_live_clip_timings(
	clip_result: Dictionary
) -> void:
	native_static_sync_diagnostics["protected_live_clip_total_ms"] = float(
		clip_result.get("total_native_ms", 0.0)
	)
	native_static_sync_diagnostics["protected_live_clip_imports_ms"] = float(
		clip_result.get("imports_ms", 0.0)
	)
	native_static_sync_diagnostics["protected_live_clip_subtract_ms"] = float(
		clip_result.get("subtract_ms", 0.0)
	)
	native_static_sync_diagnostics["protected_live_clip_export_ms"] = float(
		clip_result.get("export_ms", 0.0)
	)
	native_static_sync_diagnostics[
		"protected_live_source_state_revision"
	] = int(clip_result.get("source_state_revision", -1))


func _capture_native_protected_live_decomposition_success(
	combined_packet: Dictionary,
	clipped_vertices: PackedVector3Array,
	clipped_indices: PackedInt32Array,
	protected_vertices: PackedVector3Array,
	protected_indices: PackedInt32Array,
	backend_method: String,
	has_ordinary_lane: bool
) -> void:
	native_static_sync_diagnostics["protected_composition_mode"] = (
		"native_live_decomposition"
		if has_ordinary_lane
		else "handle_only_direct"
	)
	native_static_sync_diagnostics[
		"protected_composition_success_count"
	] = int(native_static_sync_diagnostics.get(
		"protected_composition_success_count",
		0
	)) + 1
	native_static_sync_diagnostics[
		"protected_live_decomposition_success_count"
	] = int(native_static_sync_diagnostics.get(
		"protected_live_decomposition_success_count",
		0
	)) + 1
	native_static_sync_diagnostics[
		"protected_composition_last_failure_reason"
	] = ""
	native_static_sync_diagnostics[
		"protected_live_decomposition_last_failure_reason"
	] = ""
	native_static_sync_diagnostics[
		"protected_handle_bootstrap_pending"
	] = false
	native_static_sync_diagnostics[
		"protected_live_backend_method"
	] = backend_method
	native_static_sync_diagnostics[
		"protected_composition_backend_method"
	] = backend_method
	native_static_sync_diagnostics["protected_live_clip_vertices"] = (
		clipped_vertices.size()
	)
	native_static_sync_diagnostics["protected_live_clip_triangles"] = (
		clipped_indices.size() / 3
	)
	native_static_sync_diagnostics[
		"protected_live_clip_ordinary_triangles"
	] = int(combined_packet.get("ordinary_triangle_count", 0))
	native_static_sync_diagnostics[
		"protected_live_clip_subtraction_triangles"
	] = int(combined_packet.get("subtraction_triangle_count", 0))
	native_static_sync_diagnostics["protected_live_handle_vertices"] = (
		protected_vertices.size()
	)
	native_static_sync_diagnostics["protected_live_handle_triangles"] = (
		protected_indices.size() / 3
	)
	var combined_vertices: PackedVector3Array = combined_packet.get(
		"vertices",
		PackedVector3Array()
	)
	var combined_indices: PackedInt32Array = combined_packet.get(
		"indices",
		PackedInt32Array()
	)
	native_static_sync_diagnostics["protected_live_combined_vertices"] = (
		combined_vertices.size()
	)
	native_static_sync_diagnostics["protected_live_combined_triangles"] = (
		combined_indices.size() / 3
	)
	native_static_sync_diagnostics["protected_live_lane_count"] = (
		2 if has_ordinary_lane else 1
	)
	native_static_sync_diagnostics["protected_live_unfused_geometry"] = (
		has_ordinary_lane
	)
	native_static_sync_diagnostics[
		"protected_live_handle_packet_reused"
	] = true
	native_static_sync_diagnostics[
		"protected_live_combined_collision"
	] = true
	native_static_sync_diagnostics[
		"protected_live_final_union_performed"
	] = false
	native_static_sync_diagnostics[
		"protected_live_source_state_revision"
	] = int(combined_packet.get("source_state_revision", -1))
	native_static_sync_diagnostics[
		"protected_composition_source_state_revision"
	] = int(combined_packet.get("source_state_revision", -1))
	native_static_sync_diagnostics[
		"protected_composition_output_vertices"
	] = combined_vertices.size()
	native_static_sync_diagnostics[
		"protected_composition_output_triangles"
	] = combined_indices.size() / 3
	native_static_sync_diagnostics[
		"protected_composition_ordinary_triangles"
	] = int(combined_packet.get("ordinary_triangle_count", 0))
	native_static_sync_diagnostics[
		"protected_composition_protected_triangles"
	] = int(combined_packet.get("protected_triangle_count", 0))
	native_static_sync_diagnostics[
		"protected_composition_subtraction_triangles"
	] = int(combined_packet.get("subtraction_triangle_count", 0))


func _fail_native_protected_live_decomposition(reason: String) -> Dictionary:
	native_static_sync_diagnostics[
		"protected_live_decomposition_last_failure_reason"
	] = reason
	return {"ok": false, "reason": reason}


func _try_build_native_static_protected_composite_revision_node(
	vertices: PackedVector3Array,
	indices: PackedInt32Array,
	static_bodies: Array,
	revision: int,
	identity_descriptor: Dictionary,
	protected_handle: Resource
) -> Dictionary:
	for timing_field: String in [
		"protected_composition_total_ms",
		"protected_composition_imports_ms",
		"protected_composition_boolean_ms",
		"protected_composition_subtract_ms",
		"protected_composition_union_ms",
		"protected_composition_export_ms",
	]:
		native_static_sync_diagnostics[timing_field] = 0.0
	for count_field: String in [
		"protected_composition_output_vertices",
		"protected_composition_output_triangles",
		"protected_composition_ordinary_triangles",
		"protected_composition_protected_triangles",
		"protected_composition_subtraction_triangles",
	]:
		native_static_sync_diagnostics[count_field] = 0
	native_static_sync_diagnostics[
		"protected_composition_backend_method"
	] = ""
	native_static_sync_diagnostics[
		"protected_composition_source_state_revision"
	] = -1
	var protected_signature := PrimaryGripHandleMeshPacketScript.build_body_signature(
		protected_handle
	)
	var protected_packet := _resolve_authoritative_protected_handle_packet(
		protected_handle
	)
	if not bool(protected_packet.get("ok", false)):
		return {
			"ok": false,
			"reason": String(protected_packet.get(
				"reason",
				"protected_handle_exact_cache_missing"
			)),
		}
	var protected_vertices: PackedVector3Array = protected_packet.get(
		"vertices",
		PackedVector3Array()
	)
	var protected_indices: PackedInt32Array = protected_packet.get(
		"indices",
		PackedInt32Array()
	)
	var has_aggregate := not vertices.is_empty() or not indices.is_empty()
	if (
		has_aggregate
		and (
			vertices.is_empty()
			or indices.is_empty()
			or indices.size() % 3 != 0
		)
	):
		return {"ok": false, "reason": "native_aggregate_mesh_invalid"}
	if not has_aggregate:
		var protected_sources := PackedInt32Array()
		protected_sources.resize(protected_indices.size() / 3)
		for source_index in range(protected_sources.size()):
			protected_sources[source_index] = 1
		var handle_only_result := (
			_build_native_static_protected_direct_revision_node(
				protected_vertices,
				protected_indices,
				protected_sources,
				static_bodies,
				revision,
				identity_descriptor,
				protected_handle
			)
		)
		if bool(handle_only_result.get("ok", false)):
			_capture_native_protected_handle_only_success(
				protected_vertices.size(),
				protected_indices.size() / 3
			)
		return handle_only_result
	if (
		native_static_manifold_backend == null
		or not is_instance_valid(native_static_manifold_backend)
	):
		return {
			"ok": false,
			"reason": "native_protected_composition_backend_missing",
		}
	native_static_sync_diagnostics[
		"protected_composition_attempt_count"
	] = int(native_static_sync_diagnostics.get(
		"protected_composition_attempt_count",
		0
	)) + 1
	var backend_method := ""
	var composition_variant: Variant
	if native_static_manifold_backend.has_method(
		"compose_current_state_with_protected_mesh"
	):
		backend_method = "compose_current_state_with_protected_mesh"
		composition_variant = native_static_manifold_backend.call(
			backend_method,
			protected_vertices,
			protected_indices
		)
	elif native_static_manifold_backend.has_method(
		"compose_with_protected_mesh"
	):
		if (
			revision != native_static_expected_revision
			or vertices != native_static_active_vertices
			or indices != native_static_active_indices
		):
			return {
				"ok": false,
				"reason": "stateless_protected_composition_state_unsafe",
			}
		backend_method = "compose_with_protected_mesh"
		composition_variant = native_static_manifold_backend.call(
			backend_method,
			vertices,
			indices,
			protected_vertices,
			protected_indices
		)
	else:
		return {
			"ok": false,
			"reason": "native_protected_composition_capability_missing",
		}
	native_static_sync_diagnostics[
		"protected_composition_backend_method"
	] = backend_method
	if not composition_variant is Dictionary:
		return {
			"ok": false,
			"reason": "native_protected_composition_result_not_dictionary",
		}
	var composition_result := composition_variant as Dictionary
	_capture_native_protected_composition_timings(composition_result)
	var composition_validation := (
		_validate_native_protected_composition_packet(
			composition_result,
			backend_method,
			revision
		)
	)
	if not bool(composition_validation.get("ok", false)):
		return composition_validation
	var direct_result := _build_native_static_protected_direct_revision_node(
		composition_validation.get(
			"vertices",
			PackedVector3Array()
		) as PackedVector3Array,
		composition_validation.get(
			"indices",
			PackedInt32Array()
		) as PackedInt32Array,
		composition_validation.get(
			"source_original_ids",
			PackedInt32Array()
		) as PackedInt32Array,
		static_bodies,
		revision,
		identity_descriptor,
		protected_handle
	)
	if not bool(direct_result.get("ok", false)):
		return direct_result
	_capture_native_protected_composition_success(
		composition_validation
	)
	return direct_result


func _validate_native_protected_composition_packet(
	packet: Dictionary,
	backend_method: String,
	expected_revision: int
) -> Dictionary:
	if not bool(packet.get("ok", false)):
		return {
			"ok": false,
			"reason": "native_protected_composition_failed:%s:%s" % [
				String(packet.get("error_code", "unknown")),
				String(packet.get("error_message", "unknown")),
			],
		}
	if String(packet.get("status", "NotRun")) != "NoError":
		return {
			"ok": false,
			"reason": "native_protected_composition_status_invalid",
		}
	if not bool(packet.get("watertight", false)):
		return {
			"ok": false,
			"reason": "native_protected_composition_not_watertight",
		}
	var source_state_revision := int(packet.get(
		"source_state_revision",
		-1
	))
	if (
		backend_method == "compose_current_state_with_protected_mesh"
		and source_state_revision != expected_revision
	):
		return {
			"ok": false,
			"reason": "native_protected_composition_state_revision_mismatch",
		}
	if (
		String(packet.get("source_id_semantics", ""))
		!= "0=ordinary_base,1=protected,2=subtraction_cut"
		or not packet.has("subtraction_source_triangle_count")
	):
		return {
			"ok": false,
			"reason": "native_protected_composition_source_schema_invalid",
		}
	var vertices_variant: Variant = packet.get(
		"vertices",
		PackedVector3Array()
	)
	var indices_variant: Variant = packet.get(
		"indices",
		PackedInt32Array()
	)
	var source_ids_variant: Variant = packet.get(
		"source_original_ids",
		packet.get("source_ids", PackedInt32Array())
	)
	if (
		not vertices_variant is PackedVector3Array
		or not indices_variant is PackedInt32Array
		or not source_ids_variant is PackedInt32Array
	):
		return {
			"ok": false,
			"reason": "native_protected_composition_packet_types_invalid",
		}
	var vertices := vertices_variant as PackedVector3Array
	var indices := indices_variant as PackedInt32Array
	var source_ids := source_ids_variant as PackedInt32Array
	if vertices.is_empty() or indices.is_empty() or indices.size() % 3 != 0:
		return {
			"ok": false,
			"reason": "native_protected_composition_mesh_invalid",
		}
	var triangle_count := indices.size() / 3
	if source_ids.size() != triangle_count:
		return {
			"ok": false,
			"reason": "native_protected_composition_source_count_mismatch",
		}
	if (
		int(packet.get("output_vertex_count", -1)) != vertices.size()
		or int(packet.get("output_triangle_count", -1))
		!= triangle_count
	):
		return {
			"ok": false,
			"reason": "native_protected_composition_output_count_mismatch",
		}
	var source_face_ids_variant: Variant = packet.get(
		"source_face_ids",
		PackedInt32Array()
	)
	if (
		not source_face_ids_variant is PackedInt32Array
		or (
			(source_face_ids_variant as PackedInt32Array).size() > 0
			and (source_face_ids_variant as PackedInt32Array).size()
			!= triangle_count
		)
	):
		return {
			"ok": false,
			"reason": "native_protected_composition_face_count_mismatch",
		}
	var ordinary_triangle_count := 0
	var protected_triangle_count := 0
	var subtraction_triangle_count := 0
	for triangle_index in range(triangle_count):
		var source_id := source_ids[triangle_index]
		if source_id == 0:
			ordinary_triangle_count += 1
		elif source_id == 1:
			protected_triangle_count += 1
		elif source_id == 2:
			subtraction_triangle_count += 1
		else:
			return {
				"ok": false,
				"reason": "native_protected_composition_source_id_invalid",
			}
		var offset := triangle_index * 3
		var a := indices[offset]
		var b := indices[offset + 1]
		var c := indices[offset + 2]
		if (
			a < 0
			or b < 0
			or c < 0
			or a >= vertices.size()
			or b >= vertices.size()
			or c >= vertices.size()
			or a == b
			or b == c
			or c == a
		):
			return {
				"ok": false,
				"reason": "native_protected_composition_index_invalid",
			}
	if (
		int(packet.get(
			"ordinary_source_triangle_count",
			packet.get("base_source_triangle_count", -1)
		))
		!= ordinary_triangle_count
		or int(packet.get("protected_source_triangle_count", -1))
		!= protected_triangle_count
		or int(packet.get("subtraction_source_triangle_count", -1))
		!= subtraction_triangle_count
	):
		return {
			"ok": false,
			"reason": "native_protected_composition_region_count_mismatch",
		}
	return {
		"ok": true,
		"vertices": vertices,
		"indices": indices,
		"source_original_ids": source_ids,
		"ordinary_triangle_count": ordinary_triangle_count,
		"protected_triangle_count": protected_triangle_count,
		"subtraction_triangle_count": subtraction_triangle_count,
		"source_state_revision": source_state_revision,
	}


func _build_native_static_protected_direct_revision_node(
	vertices: PackedVector3Array,
	indices: PackedInt32Array,
	source_original_ids: PackedInt32Array,
	static_bodies: Array,
	revision: int,
	identity_descriptor: Dictionary,
	protected_handle: Resource,
	revision_kind: StringName = &"native_protected_composite",
	revision_metadata: Dictionary = {}
) -> Dictionary:
	var capture_live_phase_timings := (
		revision_kind == &"native_protected_live_decomposition"
	)
	var direct_build_started_usec := (
		Time.get_ticks_usec() if capture_live_phase_timings else 0
	)
	var material_region_elapsed_usec := 0
	var collision_faces_elapsed_usec := 0
	var collision_cook_elapsed_usec := 0
	if protected_handle == null:
		return {"ok": false, "reason": "protected_handle_missing"}
	var identity := _build_native_static_surface_identity(
		static_bodies,
		identity_descriptor
	)
	var ordinary_material_id := StringName(identity.get(
		"material_variant_id",
		StringName()
	))
	var protected_material_id := StringName(protected_handle.get(
		"material_variant_id"
	))
	var body_id := StringName(identity.get("body_id", StringName()))
	var surface_target_id := StringName(identity.get(
		"surface_target_id",
		StringName()
	))
	if (
		ordinary_material_id == StringName()
		or protected_material_id == StringName()
		or surface_target_id == StringName()
	):
		return {"ok": false, "reason": "native_surface_identity_invalid"}
	var material_region_started_usec := (
		Time.get_ticks_usec() if capture_live_phase_timings else 0
	)
	var mesh_result := _build_native_static_material_region_mesh(
		vertices,
		indices,
		source_original_ids,
		ordinary_material_id,
		protected_material_id
	)
	if capture_live_phase_timings:
		material_region_elapsed_usec = maxi(
			Time.get_ticks_usec() - material_region_started_usec,
			0
		)
		native_static_sync_diagnostics[
			"protected_live_material_region_array_mesh_ms"
		] = float(material_region_elapsed_usec) / 1000.0
	if not bool(mesh_result.get("ok", false)):
		return mesh_result
	var collision_faces_started_usec := (
		Time.get_ticks_usec() if capture_live_phase_timings else 0
	)
	var faces := PackedVector3Array()
	faces.resize(indices.size())
	for index_position in range(indices.size()):
		faces[index_position] = vertices[indices[index_position]]
	if capture_live_phase_timings:
		collision_faces_elapsed_usec = maxi(
			Time.get_ticks_usec() - collision_faces_started_usec,
			0
		)
		native_static_sync_diagnostics[
			"protected_live_collision_face_expansion_ms"
		] = float(collision_faces_elapsed_usec) / 1000.0
	if faces.is_empty():
		return {
			"ok": false,
			"reason": "native_protected_composite_collision_empty",
		}
	var revision_node := Node3D.new()
	revision_node.name = "NativeStaticMaterialBodyRevision_%06d" % revision
	revision_node.set_meta(
		"forge_v2_native_revision_kind",
		revision_kind
	)
	revision_node.set_meta(
		"forge_v2_native_expected_surface_count",
		int(mesh_result.get("surface_count", 0))
	)
	revision_node.set_meta(
		"forge_v2_native_surface_source_ids",
		mesh_result.get("surface_source_ids", PackedInt32Array())
	)
	revision_node.set_meta(
		"forge_v2_native_ordinary_triangle_count",
		int(mesh_result.get("ordinary_triangle_count", 0))
	)
	revision_node.set_meta(
		"forge_v2_native_protected_triangle_count",
		int(mesh_result.get("protected_triangle_count", 0))
	)
	revision_node.set_meta(
		"forge_v2_native_subtraction_triangle_count",
		int(mesh_result.get("subtraction_triangle_count", 0))
	)
	for metadata_key: Variant in revision_metadata.keys():
		revision_node.set_meta(
			StringName(metadata_key),
			revision_metadata[metadata_key]
		)
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "NativeStaticMaterialBodyMesh"
	mesh_instance.mesh = mesh_result.get("mesh", null) as ArrayMesh
	revision_node.add_child(mesh_instance)
	var collision_body := StaticBody3D.new()
	collision_body.name = "NativeStaticMaterialBodyCollision"
	collision_body.collision_layer = 0
	collision_body.collision_mask = 0
	var collision_shape := CollisionShape3D.new()
	collision_shape.name = "NativeStaticMaterialBodyShape"
	var concave_shape := ConcavePolygonShape3D.new()
	# The protected-handle publication shares the same native winding contract.
	# Keep its combined authoring collider targetable from either face as well.
	concave_shape.backface_collision = true
	var collision_cook_started_usec := (
		Time.get_ticks_usec() if capture_live_phase_timings else 0
	)
	concave_shape.set_faces(faces)
	if capture_live_phase_timings:
		collision_cook_elapsed_usec = maxi(
			Time.get_ticks_usec() - collision_cook_started_usec,
			0
		)
		native_static_sync_diagnostics[
			"protected_live_collision_set_faces_cook_ms"
		] = float(collision_cook_elapsed_usec) / 1000.0
	collision_shape.shape = concave_shape
	collision_body.add_child(collision_shape)
	revision_node.add_child(collision_body)
	revision_node.visible = false
	_configure_native_static_revision_metadata(
		revision_node,
		ordinary_material_id,
		body_id,
		surface_target_id,
		revision,
		false,
		true
	)
	if capture_live_phase_timings:
		var direct_build_elapsed_usec := maxi(
			Time.get_ticks_usec() - direct_build_started_usec,
			0
		)
		var node_metadata_elapsed_usec := maxi(
			direct_build_elapsed_usec
			- material_region_elapsed_usec
			- collision_faces_elapsed_usec
			- collision_cook_elapsed_usec,
			0
		)
		native_static_sync_diagnostics[
			"protected_live_node_metadata_setup_ms"
		] = float(node_metadata_elapsed_usec) / 1000.0
		native_static_sync_diagnostics[
			"protected_live_direct_build_total_ms"
		] = float(direct_build_elapsed_usec) / 1000.0
	return {"ok": true, "node": revision_node}


func _build_native_static_material_region_mesh(
	vertices: PackedVector3Array,
	indices: PackedInt32Array,
	source_original_ids: PackedInt32Array,
	ordinary_material_id: StringName,
	protected_material_id: StringName
) -> Dictionary:
	if (
		vertices.is_empty()
		or indices.is_empty()
		or indices.size() % 3 != 0
		or source_original_ids.size() != indices.size() / 3
	):
		return {
			"ok": false,
			"reason": "native_protected_region_mesh_invalid",
		}
	var render_mesh := ArrayMesh.new()
	var surface_source_ids := PackedInt32Array()
	var source_index_partitions: Array[PackedInt32Array] = [
		PackedInt32Array(),
		PackedInt32Array(),
		PackedInt32Array(),
	]
	for triangle_index in range(source_original_ids.size()):
		var source_id := source_original_ids[triangle_index]
		if source_id < 0 or source_id >= source_index_partitions.size():
			return {
				"ok": false,
				"reason": "native_protected_region_source_id_invalid",
			}
		var source_indices := source_index_partitions[source_id]
		var offset := triangle_index * 3
		for corner in range(3):
			var index_value := indices[offset + corner]
			if index_value < 0 or index_value >= vertices.size():
				return {
					"ok": false,
					"reason": "native_protected_region_index_invalid",
				}
			source_indices.append(index_value)
		source_index_partitions[source_id] = source_indices
	var ordinary_triangle_count := source_index_partitions[0].size() / 3
	var protected_triangle_count := source_index_partitions[1].size() / 3
	var subtraction_triangle_count := source_index_partitions[2].size() / 3
	for source_id in [0, 1, 2]:
		var source_indices := source_index_partitions[source_id]
		if source_indices.is_empty():
			continue
		var surface_arrays := []
		surface_arrays.resize(Mesh.ARRAY_MAX)
		surface_arrays[Mesh.ARRAY_VERTEX] = vertices
		surface_arrays[Mesh.ARRAY_INDEX] = source_indices
		var surface_tool := SurfaceTool.new()
		surface_tool.create_from_arrays(
			surface_arrays,
			Mesh.PRIMITIVE_TRIANGLES
		)
		surface_tool.generate_normals()
		var surface_material: Material
		if source_id == 0:
			surface_material = _build_csg_body_material(
				ordinary_material_id,
				false
			)
		elif source_id == 1:
			surface_material = _build_csg_body_material(
				protected_material_id,
				false
			)
		else:
			surface_material = _build_csg_body_material(
				ordinary_material_id,
				true
			)
		surface_tool.set_material(surface_material)
		var committed_mesh := surface_tool.commit(render_mesh)
		if committed_mesh == null:
			return {
				"ok": false,
				"reason": "native_protected_region_surface_commit_failed",
			}
		render_mesh = committed_mesh
		surface_source_ids.append(source_id)
	if (
		render_mesh.get_surface_count() < 1
		or render_mesh.get_surface_count() > 3
		or render_mesh.get_surface_count() != surface_source_ids.size()
	):
		return {
			"ok": false,
			"reason": "native_protected_region_surface_count_invalid",
		}
	return {
		"ok": true,
		"mesh": render_mesh,
		"surface_count": render_mesh.get_surface_count(),
		"surface_source_ids": surface_source_ids,
		"ordinary_triangle_count": ordinary_triangle_count,
		"protected_triangle_count": protected_triangle_count,
		"subtraction_triangle_count": subtraction_triangle_count,
	}


func _capture_native_protected_composition_timings(
	composition_result: Dictionary
) -> void:
	native_static_sync_diagnostics["protected_composition_total_ms"] = float(
		composition_result.get("total_native_ms", 0.0)
	)
	native_static_sync_diagnostics[
		"protected_composition_imports_ms"
	] = float(composition_result.get("imports_ms", 0.0))
	native_static_sync_diagnostics[
		"protected_composition_boolean_ms"
	] = float(composition_result.get("boolean_ms", 0.0))
	native_static_sync_diagnostics[
		"protected_composition_subtract_ms"
	] = float(composition_result.get("subtract_ms", 0.0))
	native_static_sync_diagnostics[
		"protected_composition_union_ms"
	] = float(composition_result.get("union_ms", 0.0))
	native_static_sync_diagnostics[
		"protected_composition_export_ms"
	] = float(composition_result.get("export_ms", 0.0))
	native_static_sync_diagnostics[
		"protected_composition_source_state_revision"
	] = int(composition_result.get("source_state_revision", -1))


func _capture_native_protected_composition_success(
	composition_validation: Dictionary
) -> void:
	native_static_sync_diagnostics["protected_composition_mode"] = (
		"native_composed"
	)
	native_static_sync_diagnostics[
		"protected_composition_success_count"
	] = int(native_static_sync_diagnostics.get(
		"protected_composition_success_count",
		0
	)) + 1
	native_static_sync_diagnostics[
		"protected_composition_last_failure_reason"
	] = ""
	var vertices: PackedVector3Array = composition_validation.get(
		"vertices",
		PackedVector3Array()
	)
	var indices: PackedInt32Array = composition_validation.get(
		"indices",
		PackedInt32Array()
	)
	native_static_sync_diagnostics[
		"protected_composition_output_vertices"
	] = vertices.size()
	native_static_sync_diagnostics[
		"protected_composition_output_triangles"
	] = indices.size() / 3
	native_static_sync_diagnostics[
		"protected_composition_ordinary_triangles"
	] = int(composition_validation.get("ordinary_triangle_count", 0))
	native_static_sync_diagnostics[
		"protected_composition_protected_triangles"
	] = int(composition_validation.get("protected_triangle_count", 0))
	native_static_sync_diagnostics[
		"protected_composition_subtraction_triangles"
	] = int(composition_validation.get("subtraction_triangle_count", 0))
	native_static_sync_diagnostics[
		"protected_composition_source_state_revision"
	] = int(composition_validation.get("source_state_revision", -1))


func _capture_native_protected_handle_only_success(
	vertex_count: int,
	triangle_count: int
) -> void:
	native_static_sync_diagnostics["protected_composition_mode"] = (
		"handle_only_direct"
	)
	native_static_sync_diagnostics[
		"protected_composition_handle_only_count"
	] = int(native_static_sync_diagnostics.get(
		"protected_composition_handle_only_count",
		0
	)) + 1
	native_static_sync_diagnostics[
		"protected_composition_last_failure_reason"
	] = ""
	native_static_sync_diagnostics["protected_composition_total_ms"] = 0.0
	native_static_sync_diagnostics["protected_composition_imports_ms"] = 0.0
	native_static_sync_diagnostics["protected_composition_boolean_ms"] = 0.0
	native_static_sync_diagnostics["protected_composition_subtract_ms"] = 0.0
	native_static_sync_diagnostics["protected_composition_union_ms"] = 0.0
	native_static_sync_diagnostics["protected_composition_export_ms"] = 0.0
	native_static_sync_diagnostics[
		"protected_composition_output_vertices"
	] = vertex_count
	native_static_sync_diagnostics[
		"protected_composition_output_triangles"
	] = triangle_count
	native_static_sync_diagnostics[
		"protected_composition_ordinary_triangles"
	] = 0
	native_static_sync_diagnostics[
		"protected_composition_protected_triangles"
	] = triangle_count
	native_static_sync_diagnostics[
		"protected_composition_subtraction_triangles"
	] = 0


func _capture_native_protected_composition_fallback(reason: String) -> void:
	native_static_sync_diagnostics["protected_composition_mode"] = (
		"csg_fallback"
	)
	native_static_sync_diagnostics[
		"protected_handle_bootstrap_pending"
	] = false
	native_static_sync_diagnostics[
		"protected_composition_csg_fallback_count"
	] = int(native_static_sync_diagnostics.get(
		"protected_composition_csg_fallback_count",
		0
	)) + 1
	native_static_sync_diagnostics[
		"protected_composition_last_failure_reason"
	] = reason


func _capture_native_protected_handle_bootstrap_pending() -> void:
	# The first exact Handle cache cook is initialization, not a published
	# runtime fallback. Its isolated CSG never becomes targetable if the direct
	# restage succeeds, so keep it out of the final-fallback counter.
	native_static_sync_diagnostics["protected_composition_mode"] = (
		"handle_cache_bootstrap_pending"
	)
	native_static_sync_diagnostics[
		"protected_composition_last_failure_reason"
	] = ""
	native_static_sync_diagnostics[
		"protected_handle_bootstrap_pending"
	] = true


func _prime_authoritative_protected_handle_mesh(bodies: Array) -> void:
	for body_variant: Variant in bodies:
		var body := body_variant as Resource
		if (
			body == null
			or not ForgeV2MaterialCompositionPolicyScript.is_protected_handle_entry(
				body
			)
			or _is_pending_user_material_body(body)
		):
			continue
		_resolve_authoritative_protected_handle_packet(body)
		return


func _resolve_authoritative_protected_handle_packet(
	protected_handle: Resource
) -> Dictionary:
	if (
		protected_handle == null
		or not ForgeV2MaterialCompositionPolicyScript.is_protected_handle_entry(
			protected_handle
		)
	):
		return {
			"ok": false,
			"reason": "protected_handle_authority_body_invalid",
		}
	var protected_signature := PrimaryGripHandleMeshPacketScript.build_body_signature(
		protected_handle
	)
	if protected_signature.is_empty():
		return {
			"ok": false,
			"reason": "protected_handle_signature_empty",
		}
	var cached_packet := _resolve_cached_native_protected_handle_packet(
		protected_signature
	)
	if bool(cached_packet.get("ok", false)):
		var authoritative_packet := cached_packet.duplicate(true)
		authoritative_packet.merge(
			PrimaryGripHandleMeshPacketScript.build(
				cached_packet.get("vertices", PackedVector3Array()),
				cached_packet.get("indices", PackedInt32Array()),
				protected_signature
			),
			true
		)
		return authoritative_packet
	if native_protected_handle_cache_failure_signature == protected_signature:
		return cached_packet
	if native_protected_handle_authority_pending_signature == protected_signature:
		return {
			"ok": false,
			"pending": true,
			"signature": protected_signature,
			"reason": "protected_handle_exact_csg_bake_pending",
		}
	if _native_publication_handle_bootstrap_is_pending(protected_signature):
		return {
			"ok": false,
			"pending": true,
			"signature": protected_signature,
			"reason": "protected_handle_exact_csg_publication_pending",
		}
	if not native_protected_handle_authority_pending_signature.is_empty():
		_cancel_authoritative_protected_handle_bake()
	return _request_authoritative_protected_handle_bake(
		protected_handle,
		protected_signature
	)


func _request_authoritative_protected_handle_bake(
	protected_handle: Resource,
	protected_signature: String
) -> Dictionary:
	_ensure_native_capsule_operand_staging_root()
	if (
		native_capsule_operand_staging_root == null
		or not is_instance_valid(native_capsule_operand_staging_root)
		or not native_capsule_operand_staging_root.is_inside_tree()
	):
		return {
			"ok": false,
			"reason": "protected_handle_exact_csg_staging_unavailable",
		}
	var pending_root := Node3D.new()
	pending_root.name = "AuthoritativeProtectedHandleMeshBake"
	native_capsule_operand_staging_root.add_child(pending_root)
	# The forge presenter is scaled and offset in the bench scene. Exact runtime
	# Handle geometry must remain in forge-local meters instead of inheriting
	# that display transform while Godot bakes the isolated CSG shell.
	pending_root.top_level = true
	pending_root.global_transform = Transform3D.IDENTITY
	if not _append_native_protected_handle_bootstrap(
		pending_root,
		protected_handle,
		protected_signature
	):
		pending_root.free()
		return {
			"ok": false,
			"reason": "protected_handle_exact_csg_shape_build_failed",
		}
	native_protected_handle_authority_generation += 1
	var request_generation := native_protected_handle_authority_generation
	native_protected_handle_authority_pending_signature = protected_signature
	native_protected_handle_authority_pending_root = pending_root
	_bake_authoritative_protected_handle_after_update(
		protected_signature,
		request_generation
	)
	return {
		"ok": false,
		"pending": true,
		"signature": protected_signature,
		"reason": "protected_handle_exact_csg_bake_pending",
	}


func _bake_authoritative_protected_handle_after_update(
	protected_signature: String,
	request_generation: int
) -> void:
	for _readiness_frame: int in range(
		NATIVE_STATIC_CSG_READINESS_FRAME_LIMIT
	):
		await get_tree().process_frame
		if (
			request_generation != native_protected_handle_authority_generation
			or native_protected_handle_authority_pending_signature
			!= protected_signature
		):
			return
		var pending_root := native_protected_handle_authority_pending_root
		if (
			pending_root == null
			or not is_instance_valid(pending_root)
			or not pending_root.is_inside_tree()
		):
			return
		var bootstrap_shape := pending_root.get_node_or_null(
			NATIVE_PROTECTED_HANDLE_BOOTSTRAP_NODE_NAME
		) as CSGShape3D
		if (
			bootstrap_shape == null
			or not _csg_shape_generated_mesh_is_ready(bootstrap_shape)
		):
			continue
		var bake_result := _materialize_native_protected_handle_bootstrap(
			pending_root,
			bootstrap_shape
		)
		if is_instance_valid(pending_root):
			pending_root.free()
		native_protected_handle_authority_pending_root = null
		native_protected_handle_authority_pending_signature = ""
		if not bool(bake_result.get("ok", false)):
			return
		call_deferred("_retry_authoritative_protected_handle_sync")
		return
	_record_authoritative_protected_handle_bake_failure(
		protected_signature,
		"protected_handle_exact_csg_not_ready_after_frame_limit"
	)


func _record_authoritative_protected_handle_bake_failure(
	protected_signature: String,
	reason: String
) -> void:
	var pending_root := native_protected_handle_authority_pending_root
	if pending_root != null and is_instance_valid(pending_root):
		pending_root.free()
	native_protected_handle_authority_pending_root = null
	native_protected_handle_authority_pending_signature = ""
	native_protected_handle_cache_failure_signature = protected_signature
	native_protected_handle_cache_failure_reason = reason
	native_static_sync_diagnostics[
		"protected_handle_bootstrap_last_failure_reason"
	] = reason
	_refresh_native_protected_handle_cache_diagnostics()


func _retry_authoritative_protected_handle_sync() -> void:
	if not is_inside_tree() or active_stage_controller == null:
		return
	_sync_from_controller()


func _cancel_authoritative_protected_handle_bake() -> void:
	native_protected_handle_authority_generation += 1
	var pending_root := native_protected_handle_authority_pending_root
	if pending_root != null and is_instance_valid(pending_root):
		pending_root.free()
	native_protected_handle_authority_pending_root = null
	native_protected_handle_authority_pending_signature = ""


func _native_publication_handle_bootstrap_is_pending(
	protected_signature: String
) -> bool:
	if protected_signature.is_empty():
		return false
	for revision_node: Node3D in [
		native_static_staged_node,
		native_static_published_node,
	]:
		if revision_node == null or not is_instance_valid(revision_node):
			continue
		var bootstrap_shape := revision_node.get_node_or_null(
			NATIVE_PROTECTED_HANDLE_BOOTSTRAP_NODE_NAME
		) as CSGShape3D
		if (
			bootstrap_shape != null
			and String(bootstrap_shape.get_meta(
				"forge_v2_native_protected_handle_signature",
				""
			)) == protected_signature
		):
			return true
	return false


func _resolve_cached_native_protected_handle_packet(
	protected_signature: String
) -> Dictionary:
	if protected_signature.is_empty():
		return {
			"ok": false,
			"reason": "protected_handle_signature_empty",
		}
	if (
		not native_protected_handle_cache_signature.is_empty()
		and native_protected_handle_cache_signature != protected_signature
	):
		_invalidate_native_protected_handle_cache()
	if (
		not native_protected_handle_cache_failure_signature.is_empty()
		and native_protected_handle_cache_failure_signature
		!= protected_signature
	):
		native_protected_handle_cache_failure_signature = ""
		native_protected_handle_cache_failure_reason = ""
	if (
		native_protected_handle_cache_signature == protected_signature
		and _native_protected_handle_cache_packet_is_valid(
			native_protected_handle_cache_packet,
			protected_signature
		)
	):
		native_static_sync_diagnostics[
			"protected_handle_cache_hit_count"
		] = int(native_static_sync_diagnostics.get(
			"protected_handle_cache_hit_count",
			0
		)) + 1
		_refresh_native_protected_handle_cache_diagnostics()
		return native_protected_handle_cache_packet.duplicate(true)
	native_static_sync_diagnostics[
		"protected_handle_cache_miss_count"
	] = int(native_static_sync_diagnostics.get(
		"protected_handle_cache_miss_count",
		0
	)) + 1
	_refresh_native_protected_handle_cache_diagnostics()
	if native_protected_handle_cache_failure_signature == protected_signature:
		return {
			"ok": false,
			"reason": "protected_handle_exact_cache_failed:%s" % (
				native_protected_handle_cache_failure_reason
			),
		}
	return {
		"ok": false,
		"reason": "protected_handle_exact_cache_missing",
	}


func _native_protected_handle_cache_packet_is_valid(
	packet: Dictionary,
	expected_signature: String
) -> bool:
	if (
		not bool(packet.get("ok", false))
		or String(packet.get("signature", "")) != expected_signature
	):
		return false
	var vertices_variant: Variant = packet.get(
		"vertices",
		PackedVector3Array()
	)
	var indices_variant: Variant = packet.get(
		"indices",
		PackedInt32Array()
	)
	if (
		not vertices_variant is PackedVector3Array
		or not indices_variant is PackedInt32Array
	):
		return false
	var vertices := vertices_variant as PackedVector3Array
	var indices := indices_variant as PackedInt32Array
	if vertices.is_empty() or indices.is_empty() or indices.size() % 3 != 0:
		return false
	for index_value: int in indices:
		if index_value < 0 or index_value >= vertices.size():
			return false
	return true


func _invalidate_native_protected_handle_cache() -> void:
	native_protected_handle_cache_signature = ""
	native_protected_handle_cache_packet = {}
	_refresh_native_protected_handle_cache_diagnostics()


func _refresh_native_protected_handle_cache_diagnostics() -> void:
	native_static_sync_diagnostics["protected_handle_cache_signature"] = (
		native_protected_handle_cache_signature
	)
	native_static_sync_diagnostics["protected_handle_cache_ready"] = (
		not native_protected_handle_cache_signature.is_empty()
		and _native_protected_handle_cache_packet_is_valid(
			native_protected_handle_cache_packet,
			native_protected_handle_cache_signature
		)
		)


func _native_protected_handle_cache_needs_bootstrap(
	protected_signature: String
) -> bool:
	if protected_signature.is_empty():
		return false
	if (
		not native_protected_handle_cache_signature.is_empty()
		and native_protected_handle_cache_signature != protected_signature
	):
		_invalidate_native_protected_handle_cache()
	if (
		native_protected_handle_cache_signature == protected_signature
		and _native_protected_handle_cache_packet_is_valid(
			native_protected_handle_cache_packet,
			protected_signature
		)
	):
		return false
	if native_protected_handle_authority_pending_signature == protected_signature:
		return false
	return (
		native_protected_handle_cache_failure_signature
		!= protected_signature
	)


func _append_native_protected_handle_bootstrap(
	revision_node: Node3D,
	protected_handle: Resource,
	protected_signature: String
) -> bool:
	if (
		revision_node == null
		or protected_handle == null
		or protected_signature.is_empty()
	):
		return false
	var bootstrap := CSGCombiner3D.new()
	bootstrap.name = NATIVE_PROTECTED_HANDLE_BOOTSTRAP_NODE_NAME
	bootstrap.operation = CSGShape3D.OPERATION_UNION
	bootstrap.calculate_tangents = false
	bootstrap.use_collision = false
	bootstrap.collision_layer = 0
	bootstrap.collision_mask = 0
	bootstrap.visible = true
	bootstrap.set_meta(
		"forge_v2_native_protected_handle_bootstrap",
		true
	)
	bootstrap.set_meta(
		"forge_v2_native_protected_handle_signature",
		protected_signature
	)
	revision_node.add_child(bootstrap)
	if not _append_csg_body_shape(
		bootstrap,
		protected_handle,
		StringName(protected_handle.get("material_variant_id")),
		false,
		0
	):
		revision_node.remove_child(bootstrap)
		bootstrap.free()
		return false
	native_static_sync_diagnostics[
		"protected_handle_bootstrap_count"
	] = int(native_static_sync_diagnostics.get(
		"protected_handle_bootstrap_count",
		0
	)) + 1
	return true


func _build_native_static_handle_composite_revision_node(
	vertices: PackedVector3Array,
	indices: PackedInt32Array,
	static_bodies: Array,
	revision: int,
	identity_descriptor: Dictionary,
	protected_handle: Resource
) -> Dictionary:
	if protected_handle == null:
		return {"ok": false, "reason": "protected_handle_missing"}
	var has_aggregate := not vertices.is_empty() or not indices.is_empty()
	if (
		has_aggregate
		and (
			vertices.is_empty()
			or indices.is_empty()
			or indices.size() % 3 != 0
		)
	):
		return {"ok": false, "reason": "native_aggregate_mesh_invalid"}
	var identity := _build_native_static_surface_identity(
		static_bodies,
		identity_descriptor
	)
	var material_variant_id := StringName(identity.get(
		"material_variant_id",
		StringName()
	))
	var body_id := StringName(identity.get("body_id", StringName()))
	var surface_target_id := StringName(identity.get(
		"surface_target_id",
		StringName()
	))
	if material_variant_id == StringName() or surface_target_id == StringName():
		return {"ok": false, "reason": "native_surface_identity_invalid"}
	var revision_node := Node3D.new()
	revision_node.name = "NativeStaticMaterialBodyRevision_%06d" % revision
	revision_node.set_meta("forge_v2_native_revision_kind", &"handle_composite")
	var outer_combiner := CSGCombiner3D.new()
	outer_combiner.name = "NativeStaticMaterialComposition"
	outer_combiner.operation = CSGShape3D.OPERATION_UNION
	outer_combiner.calculate_tangents = false
	outer_combiner.use_collision = true
	outer_combiner.collision_layer = 0
	outer_combiner.collision_mask = 0
	revision_node.add_child(outer_combiner)
	if has_aggregate:
		var aggregate_mesh_result := _build_indexed_array_mesh(vertices, indices)
		if not bool(aggregate_mesh_result.get("ok", false)):
			revision_node.free()
			return {
				"ok": false,
				"reason": "native_aggregate_csg_mesh_build_failed",
			}
		var ordinary_combiner := CSGCombiner3D.new()
		ordinary_combiner.name = "NativeAggregateMinusProtectedHandle"
		ordinary_combiner.operation = CSGShape3D.OPERATION_UNION
		ordinary_combiner.calculate_tangents = false
		outer_combiner.add_child(ordinary_combiner)
		var aggregate_mesh := CSGMesh3D.new()
		aggregate_mesh.name = "NativeAggregateAddMesh"
		aggregate_mesh.operation = CSGShape3D.OPERATION_UNION
		aggregate_mesh.calculate_tangents = false
		aggregate_mesh.mesh = aggregate_mesh_result.get("mesh", null) as ArrayMesh
		aggregate_mesh.material = _build_csg_body_material(
			material_variant_id,
			false
		)
		ordinary_combiner.add_child(aggregate_mesh)
		if not _append_csg_body_shape(
			ordinary_combiner,
			protected_handle,
			material_variant_id,
			true,
			1
		):
			revision_node.free()
			return {
				"ok": false,
				"reason": "protected_handle_subtraction_shape_invalid",
			}
	var protected_material_id := StringName(protected_handle.get(
		"material_variant_id"
	))
	if not _append_csg_body_shape(
		outer_combiner,
		protected_handle,
		protected_material_id,
		false,
		2 if has_aggregate else 0
	):
		revision_node.free()
		return {
			"ok": false,
			"reason": "protected_handle_union_shape_invalid",
		}
	var protected_signature := PrimaryGripHandleMeshPacketScript.build_body_signature(
		protected_handle
	)
	if _native_protected_handle_cache_needs_bootstrap(protected_signature):
		if not _append_native_protected_handle_bootstrap(
			revision_node,
			protected_handle,
			protected_signature
		):
			revision_node.free()
			return {
				"ok": false,
				"reason": "protected_handle_bootstrap_shape_invalid",
			}
	outer_combiner.visible = true
	revision_node.visible = false
	_configure_native_static_revision_metadata(
		revision_node,
		material_variant_id,
		body_id,
		surface_target_id,
		revision,
		false,
		true
	)
	return {"ok": true, "node": revision_node}


func _build_native_static_surface_identity(
	static_bodies: Array,
	identity_descriptor: Dictionary = {}
) -> Dictionary:
	var active_tail_bodies: Array = identity_descriptor.get(
		"active_tail_bodies",
		static_bodies
	) as Array
	var protected_bodies: Array = identity_descriptor.get(
		"protected_bodies",
		[]
	) as Array
	var body_ids: Array[StringName] = []
	var material_variant_id := _resolve_bounded_material_variant_id(
		identity_descriptor
	)
	for body_variant: Variant in active_tail_bodies:
		if not (body_variant is Resource):
			continue
		var body := body_variant as Resource
		if body == null:
			continue
		body_ids.append(StringName(body.get("body_id")))
		if material_variant_id == StringName():
			material_variant_id = StringName(body.get("material_variant_id"))
	for protected_variant: Variant in protected_bodies:
		var protected_body := protected_variant as Resource
		if protected_body == null:
			continue
		body_ids.append(StringName(protected_body.get("body_id")))
		if material_variant_id == StringName():
			material_variant_id = StringName(protected_body.get(
				"material_variant_id"
			))
	body_ids.sort()
	var id_parts := PackedStringArray()
	var checkpoint_count := _resolve_bounded_checkpoint_operation_count(
		identity_descriptor
	)
	if checkpoint_count > 0:
		var checkpoint_identity := _resolve_bounded_checkpoint_identity(
			identity_descriptor
		)
		id_parts.append("checkpoint_id:%s" % StringName(
			checkpoint_identity.get("checkpoint_id", StringName())
		))
		id_parts.append("checkpoint_revision:%d" % int(
			checkpoint_identity.get("checkpoint_revision", -1)
		))
		id_parts.append("checkpoint_operations:%d" % checkpoint_count)
	id_parts.append("transition_revision:%d" % int(identity_descriptor.get(
		"transition_revision",
		identity_descriptor.get("revision", -1)
	)))
	for body_variant: Variant in active_tail_bodies:
		var body := body_variant as Resource
		if body == null:
			continue
		id_parts.append("tail:%s" % _build_native_static_body_signature(body))
	for protected_variant: Variant in protected_bodies:
		var protected_body := protected_variant as Resource
		if protected_body == null:
			continue
		id_parts.append(
			"protected:%s" % _build_native_static_body_signature(protected_body)
		)
	var zone_key := "%s:%s" % [
		String(material_variant_id),
		"|".join(id_parts),
	]
	return {
		"material_variant_id": material_variant_id,
		"body_id": (
			body_ids[0]
			if body_ids.size() == 1 and checkpoint_count == 0
			else StringName()
		),
		"surface_target_id": _build_zone_surface_target_id(zone_key),
	}


func _resolve_bounded_checkpoint_identity(
	identity_descriptor: Dictionary
) -> Dictionary:
	var supplied_identity: Variant = identity_descriptor.get(
		"checkpoint_identity",
		{}
	)
	if supplied_identity is Dictionary:
		var supplied := supplied_identity as Dictionary
		if not supplied.is_empty():
			return supplied
	var checkpoint := identity_descriptor.get("checkpoint", null) as Resource
	if checkpoint != null:
		return {
			"checkpoint_id": StringName(checkpoint.get("checkpoint_id")),
			"checkpoint_revision": int(checkpoint.get("revision")),
			"checkpoint_operation_count": int(checkpoint.get(
				"accumulated_operation_count"
			)),
		}
	var packet := _resolve_bounded_checkpoint_packet(identity_descriptor)
	return {
		"checkpoint_id": StringName(packet.get(
			"checkpoint_id",
			StringName()
		)),
		"checkpoint_revision": int(packet.get(
			"checkpoint_revision",
			-1
		)),
		"checkpoint_operation_count": int(packet.get(
			"checkpoint_operation_count",
			0
		)),
	}


func _configure_native_static_revision_metadata(
	revision_node: Node3D,
	material_variant_id: StringName,
	body_id: StringName,
	surface_target_id: StringName,
	revision: int,
	enabled: bool,
	publication_pending: bool
) -> void:
	if revision_node == null:
		return
	var mesh_instance := revision_node.get_node_or_null(
		"NativeStaticMaterialBodyMesh"
	) as MeshInstance3D
	var collision_body := revision_node.get_node_or_null(
		"NativeStaticMaterialBodyCollision"
	) as StaticBody3D
	var composition_shape := revision_node.get_node_or_null(
		"NativeStaticMaterialComposition"
	) as CSGShape3D
	for metadata_node: Node in [
		revision_node,
		mesh_instance,
		collision_body,
		composition_shape,
	]:
		if metadata_node == null:
			continue
		metadata_node.set_meta("forge_v2_material_surface", enabled)
		metadata_node.set_meta(
			"forge_v2_material_variant_id",
			material_variant_id
		)
		metadata_node.set_meta("forge_v2_body_id", body_id)
		metadata_node.set_meta(
			"forge_v2_surface_target_id",
			surface_target_id
		)
		metadata_node.set_meta(
			"forge_v2_publication_pending",
			publication_pending
		)
		metadata_node.set_meta("forge_v2_native_revision", revision)
	if collision_body != null:
		collision_body.collision_layer = (
			MATERIAL_SURFACE_COLLISION_LAYER if enabled else 0
		)
		collision_body.collision_mask = 0
	if composition_shape != null:
		# CSG collision is cooked while staged on layer zero. Publication only
		# changes its layer after the generated mesh has crossed a physics frame.
		composition_shape.use_collision = true
		composition_shape.collision_layer = (
			MATERIAL_SURFACE_COLLISION_LAYER if enabled else 0
		)
		composition_shape.collision_mask = 0


func _begin_native_static_publication(
	revision_node: Node3D,
	revision: int
) -> bool:
	if (
		revision_node == null
		or native_static_body_root == null
		or not is_instance_valid(native_static_body_root)
		or not is_inside_tree()
	):
		if revision_node != null and is_instance_valid(revision_node):
			revision_node.free()
		return false
	native_static_publication_generation += 1
	var publication_generation := native_static_publication_generation
	if (
		native_static_staged_node != null
		and is_instance_valid(native_static_staged_node)
	):
		native_static_staged_node.free()
	native_static_staged_node = revision_node
	native_static_staged_revision = revision
	native_static_publication_pending = true
	revision_node.visible = false
	native_static_body_root.add_child(revision_node)
	native_static_body_root.visible = native_static_authoritative
	_publish_native_static_stage_after_update(
		revision_node,
		revision,
		publication_generation
	)
	return true


func _publish_native_static_stage_after_update(
	revision_node: Node3D,
	revision: int,
	publication_generation: int
) -> void:
	var stage_ready := false
	for _readiness_frame in range(NATIVE_STATIC_CSG_READINESS_FRAME_LIMIT):
		await get_tree().process_frame
		await get_tree().physics_frame
		if publication_generation != native_static_publication_generation:
			if (
				revision_node != null
				and is_instance_valid(revision_node)
				and revision_node != native_static_staged_node
			):
				revision_node.free()
			return
		if (
			native_static_lifecycle != NATIVE_STATIC_LIFECYCLE_ACTIVE
			or revision != native_static_expected_revision
			or revision_node != native_static_staged_node
			or revision_node == null
			or not is_instance_valid(revision_node)
		):
			_handle_native_static_publication_failure(
				"native_stage_generation_guard_failed"
			)
			return
		if _native_static_revision_node_is_complete(revision_node):
			stage_ready = true
			break
	if not stage_ready:
		_handle_native_static_publication_failure(
			"native_stage_readiness_guard_failed"
		)
		return
	var bootstrap_shape := revision_node.get_node_or_null(
		NATIVE_PROTECTED_HANDLE_BOOTSTRAP_NODE_NAME
	) as CSGShape3D
	if bootstrap_shape != null:
		var bootstrap_result := _materialize_native_protected_handle_bootstrap(
			revision_node,
			bootstrap_shape
		)
		if bool(bootstrap_result.get("ok", false)):
			var restage_result := (
				_try_restage_native_protected_composite_after_bootstrap(
					revision_node,
					revision,
					publication_generation
				)
			)
			if bool(restage_result.get("restaged", false)):
				return
			_record_native_protected_bootstrap_restage_failure(
				String(restage_result.get(
					"reason",
					"bootstrap_direct_restage_failed"
				))
			)
		else:
			_record_native_protected_bootstrap_restage_failure(
				String(bootstrap_result.get(
					"reason",
					"protected_handle_bootstrap_failed"
				))
			)
	var prior_published := native_static_published_node
	_set_native_static_revision_targetable(revision_node, true, false)
	revision_node.visible = true
	if prior_published != null and is_instance_valid(prior_published):
		_set_native_static_revision_targetable(
			prior_published,
			false,
			false
		)
	_set_csg_static_publication_enabled(false)
	native_static_published_node = revision_node
	native_static_published_revision = revision
	native_static_staged_node = null
	native_static_staged_revision = 0
	native_static_authoritative = true
	native_static_publication_pending = false
	_clear_native_capsule_operand_previews_through_revision(revision)
	if prior_published != null and is_instance_valid(prior_published):
		prior_published.free()
	if (
		native_static_retiring_node != null
		and is_instance_valid(native_static_retiring_node)
	):
		_set_native_static_revision_targetable(
			native_static_retiring_node,
			false,
			false
		)
		native_static_retiring_node.free()
	native_static_retiring_node = null
	if native_static_body_root != null:
		native_static_body_root.visible = true
	if csg_static_body_root != null:
		csg_static_body_root.visible = false
	if csg_material_body_root != null:
		csg_material_body_root.visible = true
	native_static_sync_diagnostics["publication_count"] = int(
		native_static_sync_diagnostics.get("publication_count", 0)
	) + 1
	native_static_sync_diagnostics["last_failure_reason"] = ""
	_refresh_native_static_diagnostics()
	_sync_from_controller()


func _materialize_native_protected_handle_bootstrap(
	revision_node: Node3D,
	bootstrap_shape: CSGShape3D
) -> Dictionary:
	if (
		revision_node == null
		or bootstrap_shape == null
		or bootstrap_shape.get_parent() != revision_node
		or not bool(bootstrap_shape.get_meta(
			"forge_v2_native_protected_handle_bootstrap",
			false
		))
	):
		return {
			"ok": false,
			"reason": "protected_handle_bootstrap_identity_invalid",
		}
	var protected_signature := String(bootstrap_shape.get_meta(
		"forge_v2_native_protected_handle_signature",
		""
	))
	var bake_start_usec := Time.get_ticks_usec()
	var baked_mesh := bootstrap_shape.bake_static_mesh()
	var bake_ms := float(Time.get_ticks_usec() - bake_start_usec) / 1000.0
	native_static_sync_diagnostics[
		"protected_handle_bootstrap_last_bake_ms"
	] = bake_ms
	var flatten_result: Dictionary
	if baked_mesh == null:
		flatten_result = {
			"ok": false,
			"reason": "protected_handle_bootstrap_bake_failed",
		}
	else:
		flatten_result = _flatten_native_protected_handle_baked_mesh(
			baked_mesh,
			protected_signature
		)
	revision_node.remove_child(bootstrap_shape)
	bootstrap_shape.free()
	if not bool(flatten_result.get("ok", false)):
		native_protected_handle_cache_failure_signature = protected_signature
		native_protected_handle_cache_failure_reason = String(
			flatten_result.get("reason", "bootstrap_flatten_failed")
		)
		native_static_sync_diagnostics[
			"protected_handle_bootstrap_last_failure_reason"
		] = native_protected_handle_cache_failure_reason
		return flatten_result
	native_protected_handle_cache_signature = protected_signature
	native_protected_handle_cache_packet = flatten_result.duplicate(true)
	native_protected_handle_cache_failure_signature = ""
	native_protected_handle_cache_failure_reason = ""
	native_static_sync_diagnostics[
		"protected_handle_bootstrap_success_count"
	] = int(native_static_sync_diagnostics.get(
		"protected_handle_bootstrap_success_count",
		0
	)) + 1
	native_static_sync_diagnostics[
		"protected_handle_bootstrap_last_failure_reason"
	] = ""
	_refresh_native_protected_handle_cache_diagnostics()
	return flatten_result


func _flatten_native_protected_handle_baked_mesh(
	baked_mesh: ArrayMesh,
	protected_signature: String,
	reject_degenerate_triangles: bool = true
) -> Dictionary:
	if (
		baked_mesh == null
		or baked_mesh.get_surface_count() <= 0
		or protected_signature.is_empty()
	):
		return {
			"ok": false,
			"reason": "protected_handle_bootstrap_mesh_empty",
		}
	var flattened_vertices := PackedVector3Array()
	var flattened_indices := PackedInt32Array()
	var vertex_index_by_position: Dictionary = {}
	for surface_index in range(baked_mesh.get_surface_count()):
		if (
			baked_mesh.surface_get_primitive_type(surface_index)
			!= Mesh.PRIMITIVE_TRIANGLES
		):
			return {
				"ok": false,
				"reason": "protected_handle_bootstrap_primitive_invalid",
			}
		var surface_arrays: Array = baked_mesh.surface_get_arrays(
			surface_index
		)
		if surface_arrays.size() < Mesh.ARRAY_MAX:
			return {
				"ok": false,
				"reason": "protected_handle_bootstrap_arrays_incomplete",
			}
		var surface_vertices_variant: Variant = surface_arrays[
			Mesh.ARRAY_VERTEX
		]
		var surface_indices_variant: Variant = surface_arrays[
			Mesh.ARRAY_INDEX
		]
		if not surface_vertices_variant is PackedVector3Array:
			return {
				"ok": false,
				"reason": "protected_handle_bootstrap_vertices_invalid",
			}
		var surface_vertices := (
			surface_vertices_variant as PackedVector3Array
		)
		var surface_indices := PackedInt32Array()
		if surface_indices_variant is PackedInt32Array:
			surface_indices = surface_indices_variant as PackedInt32Array
		if surface_vertices.is_empty():
			continue
		if surface_indices.is_empty():
			if surface_vertices.size() % 3 != 0:
				return {
					"ok": false,
					"reason": "protected_handle_bootstrap_nonindexed_unaligned",
				}
			surface_indices.resize(surface_vertices.size())
			for sequential_index in range(surface_vertices.size()):
				surface_indices[sequential_index] = sequential_index
		elif surface_indices.size() % 3 != 0:
			return {
				"ok": false,
				"reason": "protected_handle_bootstrap_indices_unaligned",
			}
		var local_to_flattened := PackedInt32Array()
		local_to_flattened.resize(surface_vertices.size())
		for local_vertex_index in range(surface_vertices.size()):
			var vertex := surface_vertices[local_vertex_index]
			if not vertex.is_finite():
				return {
					"ok": false,
					"reason": "protected_handle_bootstrap_vertex_nonfinite",
				}
			if vertex_index_by_position.has(vertex):
				local_to_flattened[local_vertex_index] = int(
					vertex_index_by_position[vertex]
				)
			else:
				var flattened_index := flattened_vertices.size()
				flattened_vertices.append(vertex)
				vertex_index_by_position[vertex] = flattened_index
				local_to_flattened[local_vertex_index] = flattened_index
		for index_value: int in surface_indices:
			if index_value < 0 or index_value >= surface_vertices.size():
				return {
					"ok": false,
					"reason": "protected_handle_bootstrap_index_invalid",
				}
			flattened_indices.append(local_to_flattened[index_value])
	if (
		flattened_vertices.is_empty()
		or flattened_indices.is_empty()
		or flattened_indices.size() % 3 != 0
	):
		return {
			"ok": false,
			"reason": "protected_handle_bootstrap_flattened_empty",
		}
	var validated_indices := PackedInt32Array()
	var signed_volume := 0.0
	for triangle_offset in range(0, flattened_indices.size(), 3):
		var a := flattened_indices[triangle_offset]
		var b := flattened_indices[triangle_offset + 1]
		var c := flattened_indices[triangle_offset + 2]
		if a == b or b == c or c == a:
			if reject_degenerate_triangles:
				return {
					"ok": false,
					"reason": "protected_handle_bootstrap_degenerate_index",
				}
			continue
		var va := flattened_vertices[a]
		var vb := flattened_vertices[b]
		var vc := flattened_vertices[c]
		var area_cross := (vb - va).cross(vc - va)
		if not area_cross.is_finite() or area_cross.length_squared() <= 0.0:
			if reject_degenerate_triangles:
				return {
					"ok": false,
					"reason": "protected_handle_bootstrap_degenerate_triangle",
				}
			continue
		validated_indices.append(a)
		validated_indices.append(b)
		validated_indices.append(c)
		signed_volume += va.dot(vb.cross(vc)) / 6.0
	if (
		validated_indices.is_empty()
		or not is_finite(signed_volume)
		or is_zero_approx(signed_volume)
	):
		return {
			"ok": false,
			"reason": "protected_handle_bootstrap_volume_invalid",
		}
	return {
		"ok": true,
		"signature": protected_signature,
		"vertices": flattened_vertices,
		"indices": validated_indices,
		"vertex_count": flattened_vertices.size(),
		"triangle_count": validated_indices.size() / 3,
		"signed_volume_m3": signed_volume,
	}


func _try_restage_native_protected_composite_after_bootstrap(
	fallback_revision_node: Node3D,
	revision: int,
	publication_generation: int
) -> Dictionary:
	if (
		publication_generation != native_static_publication_generation
		or fallback_revision_node != native_static_staged_node
		or revision != native_static_expected_revision
		or native_static_lifecycle != NATIVE_STATIC_LIFECYCLE_ACTIVE
		or native_static_bound_authoring_state == null
		or not is_instance_valid(native_static_bound_authoring_state)
		or not native_static_bound_authoring_state.has_method(
			"get_bounded_presentation_descriptor"
		)
	):
		return {
			"ok": false,
			"reason": "bootstrap_restage_generation_guard_failed",
		}
	var presentation := native_static_bound_authoring_state.call(
		"get_bounded_presentation_descriptor"
	) as Dictionary
	var protected_validation := _validate_bounded_protected_handle_lane(
		presentation,
		presentation
	)
	if not bool(protected_validation.get("ok", false)):
		return protected_validation
	var protected_handle := protected_validation.get(
		"protected_handle",
		null
	) as Resource
	if (
		protected_handle == null
		or PrimaryGripHandleMeshPacketScript.build_body_signature(protected_handle)
		!= native_protected_handle_cache_signature
	):
		return {
			"ok": false,
			"reason": "bootstrap_restage_handle_signature_mismatch",
		}
	var direct_result := (
		_try_build_native_static_protected_live_decomposition_revision_node(
			native_static_active_vertices,
			native_static_active_indices,
			presentation.get("active_tail_bodies", []) as Array,
			revision,
			presentation,
			protected_handle
		)
	)
	if not bool(direct_result.get("ok", false)):
		return {
			"ok": false,
			"reason": "bootstrap_direct_restage_failed:%s" % String(
				direct_result.get("reason", "unknown")
			),
		}
	if not _begin_native_static_publication(
		direct_result.get("node", null) as Node3D,
		revision
	):
		return {
			"ok": false,
			"reason": "bootstrap_direct_restage_begin_failed",
		}
	return {"ok": true, "restaged": true}


func _record_native_protected_bootstrap_restage_failure(reason: String) -> void:
	_capture_native_protected_composition_fallback(reason)
	native_static_sync_diagnostics[
		"protected_handle_bootstrap_last_failure_reason"
	] = reason
	native_static_sync_diagnostics[
		"protected_handle_bootstrap_failure_count"
	] = int(native_static_sync_diagnostics.get(
		"protected_handle_bootstrap_failure_count",
		0
	)) + 1


func _native_static_revision_node_is_complete(revision_node: Node3D) -> bool:
	if revision_node == null or not is_instance_valid(revision_node):
		return false
	var mesh_instance := revision_node.get_node_or_null(
		"NativeStaticMaterialBodyMesh"
	) as MeshInstance3D
	var collision_body := revision_node.get_node_or_null(
		"NativeStaticMaterialBodyCollision"
	) as StaticBody3D
	var collision_shape := revision_node.get_node_or_null(
		"NativeStaticMaterialBodyCollision/NativeStaticMaterialBodyShape"
	) as CollisionShape3D
	var composition_shape := revision_node.get_node_or_null(
		"NativeStaticMaterialComposition"
	) as CSGShape3D
	var bootstrap_shape := revision_node.get_node_or_null(
		NATIVE_PROTECTED_HANDLE_BOOTSTRAP_NODE_NAME
	) as CSGShape3D
	if (
		bootstrap_shape != null
		and not _csg_shape_generated_mesh_is_ready(bootstrap_shape)
	):
		return false
	if composition_shape != null:
		if not composition_shape.use_collision:
			return false
		return _csg_shape_generated_mesh_is_ready(composition_shape)
	var expected_surface_count := maxi(int(revision_node.get_meta(
		"forge_v2_native_expected_surface_count",
		1
	)), 1)
	var concave_shape := (
		collision_shape.shape as ConcavePolygonShape3D
		if collision_shape != null
		else null
	)
	return (
		mesh_instance != null
		and mesh_instance.mesh != null
		and mesh_instance.mesh.get_surface_count() == expected_surface_count
		and expected_surface_count <= 3
		and collision_body != null
		and collision_shape != null
		and concave_shape != null
		and not concave_shape.get_faces().is_empty()
	)


func _csg_shape_generated_mesh_is_ready(shape: CSGShape3D) -> bool:
	if shape == null or not is_instance_valid(shape) or not shape.is_inside_tree():
		return false
	var generated_meshes: Array = shape.get_meshes()
	for mesh_value: Variant in generated_meshes:
		if not mesh_value is Mesh:
			continue
		var generated_mesh := mesh_value as Mesh
		if generated_mesh != null and generated_mesh.get_surface_count() > 0:
			return true
	return false


func _set_native_static_revision_targetable(
	revision_node: Node3D,
	enabled: bool,
	publication_pending: bool
) -> void:
	if revision_node == null or not is_instance_valid(revision_node):
		return
	_configure_native_static_revision_metadata(
		revision_node,
		StringName(revision_node.get_meta(
			"forge_v2_material_variant_id",
			StringName()
		)),
		StringName(revision_node.get_meta(
			"forge_v2_body_id",
			StringName()
		)),
		StringName(revision_node.get_meta(
			"forge_v2_surface_target_id",
			StringName()
		)),
		int(revision_node.get_meta("forge_v2_native_revision", 0)),
		enabled,
		publication_pending
	)


func _set_csg_static_publication_enabled(enabled: bool) -> void:
	var publication_nodes: Array[CSGShape3D] = []
	for zone_variant: Variant in csg_static_zone_nodes.values():
		var zone_node := zone_variant as CSGShape3D
		if zone_node == null or not is_instance_valid(zone_node):
			continue
		if not publication_nodes.has(zone_node):
			publication_nodes.append(zone_node)
	if csg_static_body_root != null and is_instance_valid(csg_static_body_root):
		for child: Node in csg_static_body_root.get_children():
			var bounded_or_zone_node := child as CSGShape3D
			if (
				bounded_or_zone_node != null
				and not publication_nodes.has(bounded_or_zone_node)
			):
				publication_nodes.append(bounded_or_zone_node)
	for zone_node: CSGShape3D in publication_nodes:
		zone_node.collision_layer = (
			MATERIAL_SURFACE_COLLISION_LAYER if enabled else 0
		)
		zone_node.set_meta("forge_v2_material_surface", enabled)


func _reject_native_static_fast_lane(reason: String) -> Dictionary:
	var reset_result := _reset_native_static_lane(
		NATIVE_STATIC_LIFECYCLE_DISABLED,
		reason,
		true
	)
	if not bool(reset_result.get("ok", false)):
		return {
			"handled": true,
			"force_full_csg": false,
			"recovery_blocked": true,
			"reason": String(reset_result.get(
				"reason",
				"checkpoint_recovery_blocked"
			)),
		}
	var retained_publication := reset_result.get(
		"retained_publication",
		null
	) as Node3D
	if (
		retained_publication != null
		and is_instance_valid(retained_publication)
		and csg_material_body_root != null
		and is_instance_valid(csg_material_body_root)
	):
		csg_material_body_root.add_child(retained_publication)
		retained_publication.visible = true
		native_static_retiring_node = retained_publication
	native_static_sync_diagnostics["last_mode"] = "fallback_csg"
	native_static_sync_diagnostics["fallback_count"] = int(
		native_static_sync_diagnostics.get("fallback_count", 0)
	) + 1
	native_static_sync_diagnostics["last_failure_reason"] = reason
	_refresh_native_static_diagnostics()
	return {"handled": false, "force_full_csg": true, "reason": reason}


func _reset_native_static_lane(
	next_lifecycle: String,
	reason: String,
	retain_published_for_fallback: bool = false,
	retain_ready_capsule_previews: bool = false
) -> Dictionary:
	var recovery := _materialize_bounded_checkpoint_before_native_reset(
		native_static_bound_authoring_state
	)
	if not bool(recovery.get("ok", false)):
		var blocked_reason := StringName(
			"checkpoint_export_before_native_reset_failed"
		)
		_mark_bounded_checkpoint_recovery_blocked(
			native_static_bound_authoring_state,
			blocked_reason
		)
		native_static_sync_diagnostics["last_mode"] = (
			"checkpoint_recovery_blocked"
		)
		native_static_sync_diagnostics["last_failure_reason"] = (
			"%s:%s" % [
				reason,
				String(recovery.get(
					"reason",
					"checkpoint_materialization_failed"
				)),
			]
		)
		_refresh_native_static_diagnostics()
		return {
			"ok": false,
			"reason": native_static_sync_diagnostics.get(
				"last_failure_reason",
				"checkpoint_recovery_blocked"
			),
			"presentation_descriptor": recovery.get(
				"presentation_descriptor",
				{}
			) as Dictionary,
		}
	var retained_publication: Node3D = null
	if (
		retain_published_for_fallback
		and native_static_authoritative
		and native_static_published_node != null
		and is_instance_valid(native_static_published_node)
	):
		retained_publication = native_static_published_node
		var retained_parent := retained_publication.get_parent()
		if retained_parent != null:
			retained_parent.remove_child(retained_publication)
	elif (
		retain_published_for_fallback
		and native_static_retiring_node != null
		and is_instance_valid(native_static_retiring_node)
	):
		# A prior catch-up may still be cooking its replacement.  Preserve the
		# already-visible retiring revision across another superseding restore.
		retained_publication = native_static_retiring_node
		native_static_retiring_node = null
	_discard_native_static_lane(
		next_lifecycle,
		reason,
		retain_ready_capsule_previews
	)
	return {
		"ok": true,
		"retained_publication": retained_publication,
		"presentation_descriptor": recovery.get(
			"presentation_descriptor",
			{}
		) as Dictionary,
	}


func _discard_native_static_lane(
	next_lifecycle: String,
	reason: String,
	retain_ready_capsule_previews: bool = false
) -> void:
	native_static_publication_generation += 1
	_cancel_native_capsule_operand_staging(retain_ready_capsule_previews)
	if not retain_ready_capsule_previews:
		native_static_deferred_transition_revision = -1
		native_static_bounded_resync_required = false
	if (
		native_static_retiring_node != null
		and is_instance_valid(native_static_retiring_node)
	):
		native_static_retiring_node.free()
	native_static_retiring_node = null
	if (
		native_static_manifold_backend != null
		and is_instance_valid(native_static_manifold_backend)
		and native_static_manifold_backend.has_method("clear_state")
	):
		native_static_manifold_backend.call("clear_state")
	native_static_manifold_backend = null
	if native_static_body_root != null and is_instance_valid(native_static_body_root):
		_clear_node_children(native_static_body_root)
		native_static_body_root.visible = false
	native_static_published_node = null
	native_static_staged_node = null
	native_static_body_order_snapshot = []
	native_static_body_signatures_by_id = {}
	native_static_body_bounds_by_id = {}
	native_static_material_variant_id = StringName()
	native_static_expected_revision = 0
	native_static_published_revision = 0
	native_static_staged_revision = 0
	native_static_authoritative = false
	native_static_publication_pending = false
	native_static_state_initialized = false
	native_static_active_vertices = PackedVector3Array()
	native_static_active_indices = PackedInt32Array()
	native_static_lifecycle = next_lifecycle
	native_static_sync_diagnostics["last_failure_reason"] = reason
	native_static_sync_diagnostics["output_vertices"] = 0
	native_static_sync_diagnostics["output_triangles"] = 0
	native_static_sync_diagnostics["protected_composition_mode"] = (
		"not_attempted"
	)
	native_static_sync_diagnostics[
		"protected_composition_last_failure_reason"
	] = ""
	native_static_sync_diagnostics["protected_composition_total_ms"] = 0.0
	native_static_sync_diagnostics["protected_composition_imports_ms"] = 0.0
	native_static_sync_diagnostics["protected_composition_boolean_ms"] = 0.0
	native_static_sync_diagnostics["protected_composition_subtract_ms"] = 0.0
	native_static_sync_diagnostics["protected_composition_union_ms"] = 0.0
	native_static_sync_diagnostics["protected_composition_export_ms"] = 0.0
	native_static_sync_diagnostics[
		"protected_composition_output_vertices"
	] = 0
	native_static_sync_diagnostics[
		"protected_composition_output_triangles"
	] = 0
	native_static_sync_diagnostics[
		"protected_composition_ordinary_triangles"
	] = 0
	native_static_sync_diagnostics[
		"protected_composition_protected_triangles"
	] = 0
	native_static_sync_diagnostics[
		"protected_composition_subtraction_triangles"
	] = 0
	native_static_sync_diagnostics[
		"protected_composition_backend_method"
	] = ""
	native_static_sync_diagnostics[
		"protected_composition_source_state_revision"
	] = -1
	_reset_native_protected_live_decomposition_diagnostics()
	_refresh_native_protected_handle_cache_diagnostics()
	native_static_sync_diagnostics["history_window_enabled"] = false
	native_static_sync_diagnostics["history_window_capacity"] = 0
	native_static_sync_diagnostics["checkpoint_operation_count"] = 0
	native_static_sync_diagnostics["checkpoint_materialization_attempt_count"] = 0
	native_static_sync_diagnostics["checkpoint_materialization_count"] = 0
	native_static_sync_diagnostics["promotion_count"] = 0
	native_static_sync_diagnostics["boolean_count"] = 0
	native_static_sync_diagnostics["export_count"] = 0
	native_static_sync_diagnostics["retained_state_count"] = 0
	native_static_sync_diagnostics["retained_total_vertices"] = 0
	native_static_sync_diagnostics["retained_total_triangles"] = 0
	native_static_sync_diagnostics["active_tail_cursor"] = 0
	native_static_sync_diagnostics["tail_timeline_count"] = 0
	native_static_sync_diagnostics["redo_count"] = 0
	if next_lifecycle == NATIVE_STATIC_LIFECYCLE_UNOBSERVED:
		native_static_sync_diagnostics["last_mode"] = "cleared"
	_refresh_native_static_diagnostics()


func _cancel_native_capsule_operand_staging(
	retain_ready_previews: bool = false
) -> void:
	_cancel_authoritative_protected_handle_bake()
	native_capsule_operand_generation += 1
	if (
		native_capsule_operand_staging_root != null
		and is_instance_valid(native_capsule_operand_staging_root)
	):
		_clear_node_children(native_capsule_operand_staging_root)
	var retained_pending: Dictionary = {}
	if retain_ready_previews:
		for signature_variant: Variant in native_capsule_operand_pending.keys():
			var signature := String(signature_variant)
			var pending_entry := native_capsule_operand_pending.get(
				signature,
				{}
			) as Dictionary
			if not bool(pending_entry.get("packet_ready", false)):
				continue
			pending_entry["node"] = null
			retained_pending[signature] = pending_entry
	native_capsule_operand_pending = retained_pending
	native_capsule_operand_failures.clear()
	_refresh_native_capsule_operand_diagnostics()


func _begin_native_static_fallback_retirement() -> void:
	if (
		native_static_retiring_node == null
		or not is_instance_valid(native_static_retiring_node)
	):
		return
	var replacement_nodes: Array[CSGShape3D] = []
	if csg_static_body_root != null and is_instance_valid(csg_static_body_root):
		for child: Node in csg_static_body_root.get_children():
			var replacement_shape := child as CSGShape3D
			if replacement_shape == null or not replacement_shape.visible:
				continue
			replacement_shape.use_collision = true
			replacement_shape.collision_layer = 0
			replacement_shape.set_meta("forge_v2_material_surface", false)
			replacement_shape.set_meta("forge_v2_publication_pending", true)
			replacement_nodes.append(replacement_shape)
	if replacement_nodes.is_empty():
		return
	var retiring_node := native_static_retiring_node
	var retirement_generation := native_static_publication_generation
	var csg_generation := csg_static_target_metadata_generation
	_retire_native_static_fallback_after_update(
		retiring_node,
		replacement_nodes,
		retirement_generation,
		csg_generation
	)


func _retire_native_static_fallback_after_update(
	retiring_node: Node3D,
	replacement_nodes: Array[CSGShape3D],
	retirement_generation: int,
	csg_generation: int
) -> void:
	var replacements_ready := false
	for _frame_index in range(NATIVE_STATIC_CSG_READINESS_FRAME_LIMIT):
		await get_tree().process_frame
		await get_tree().physics_frame
		if (
			retirement_generation != native_static_publication_generation
			or csg_generation != csg_static_target_metadata_generation
			or retiring_node != native_static_retiring_node
			or retiring_node == null
			or not is_instance_valid(retiring_node)
		):
			return
		replacements_ready = true
		for replacement_node: CSGShape3D in replacement_nodes:
			if (
				replacement_node == null
				or not is_instance_valid(replacement_node)
				or not _csg_shape_generated_mesh_is_ready(replacement_node)
			):
				replacements_ready = false
				break
		if replacements_ready:
			break
	if not replacements_ready:
		native_static_sync_diagnostics["last_failure_reason"] = (
			"fallback_csg_readiness_guard_failed"
		)
		_refresh_native_static_diagnostics()
		return
	for replacement_node: CSGShape3D in replacement_nodes:
		replacement_node.collision_layer = MATERIAL_SURFACE_COLLISION_LAYER
		replacement_node.set_meta("forge_v2_material_surface", true)
		replacement_node.set_meta("forge_v2_publication_pending", false)
	_set_native_static_revision_targetable(retiring_node, false, false)
	native_static_retiring_node = null
	retiring_node.free()


func _refresh_native_static_diagnostics() -> void:
	native_static_sync_diagnostics["lifecycle"] = native_static_lifecycle
	native_static_sync_diagnostics["authoritative"] = (
		native_static_authoritative
	)
	native_static_sync_diagnostics["state_initialized"] = (
		native_static_state_initialized
	)
	native_static_sync_diagnostics["bounded_transition_revision"] = (
		native_static_consumed_transition_revision
	)
	native_static_sync_diagnostics["publication_pending"] = (
		native_static_publication_pending
	)
	native_static_sync_diagnostics["prefix_body_count"] = (
		native_static_body_order_snapshot.size()
	)
	native_static_sync_diagnostics["material_variant_id"] = (
		native_static_material_variant_id
	)
	native_static_sync_diagnostics["expected_revision"] = (
		native_static_expected_revision
	)
	native_static_sync_diagnostics["published_revision"] = (
		native_static_published_revision
	)
	native_static_sync_diagnostics["staged_revision"] = (
		native_static_staged_revision
	)
	native_static_sync_diagnostics["capsule_operand_deferred_revision"] = (
		native_static_deferred_transition_revision
	)
	native_static_sync_diagnostics["capsule_operand_resync_required"] = (
		native_static_bounded_resync_required
	)


func _capture_native_static_history_diagnostics(source: Dictionary) -> void:
	for field_name: String in [
		"history_window_enabled",
		"history_window_capacity",
		"checkpoint_operation_count",
		"checkpoint_materialization_attempt_count",
		"checkpoint_materialization_count",
		"promotion_count",
		"boolean_count",
		"export_count",
		"retained_state_count",
		"retained_total_vertices",
		"retained_total_triangles",
		"active_tail_cursor",
		"tail_timeline_count",
		"redo_count",
	]:
		if source.has(field_name):
			native_static_sync_diagnostics[field_name] = source[field_name]


func _discard_csg_static_zone_cache() -> void:
	csg_static_target_metadata_generation += 1
	if csg_static_body_root != null and is_instance_valid(csg_static_body_root):
		_clear_node_children(csg_static_body_root)
		csg_static_body_root.visible = false
	csg_static_zone_nodes = {}
	csg_static_zone_signatures = {}
	csg_static_zone_body_ids_by_key = {}
	csg_static_body_zone_key_by_id = {}
	csg_static_body_order_snapshot = []
	csg_static_body_signatures_by_id = {}
	csg_static_zones_initialized = false
	bounded_csg_fallback_signature = ""


func _handle_native_static_publication_failure(reason: String) -> void:
	if native_static_lifecycle != NATIVE_STATIC_LIFECYCLE_ACTIVE:
		return
	if (
		active_stage_controller == null
		or not active_stage_controller.has_method("get_active_authoring_state")
	):
		_reject_native_static_fast_lane(reason)
		return
	var authoring_state := active_stage_controller.call(
		"get_active_authoring_state"
	) as Resource
	if authoring_state == null:
		_reject_native_static_fast_lane(reason)
		return
	if (
		authoring_state.has_method("get_bounded_history_transition")
		and authoring_state.has_method(
			"get_bounded_presentation_descriptor"
		)
	):
		var bounded_rejection := _reject_bounded_native_fast_lane(
			authoring_state,
			authoring_state.call(
				"get_bounded_history_transition"
			) as Dictionary,
			reason
		)
		if bool(bounded_rejection.get("recovery_blocked", false)):
			return
		_discard_csg_static_zone_cache()
		var bounded_descriptor: Dictionary = bounded_rejection.get(
			"presentation_descriptor",
			{}
		) as Dictionary
		if _sync_bounded_checkpoint_csg_fallback(bounded_descriptor):
			csg_static_zones_initialized = true
			_begin_native_static_fallback_retirement()
			_apply_static_zone_visibility({})
		return
	_reject_native_static_fast_lane(reason)
	_discard_csg_static_zone_cache()
	var material_bodies := _collect_active_csg_material_bodies(authoring_state)
	var active_body_id := _get_active_placement_body_id()
	var static_bodies := _filter_body_list_excluding_id(
		material_bodies,
		active_body_id
	)
	_sync_static_csg_zones(static_bodies, authoring_state)
	_begin_native_static_fallback_retirement()
	_apply_static_zone_visibility({})
	if csg_material_body_root != null:
		csg_material_body_root.visible = (
			(csg_static_body_root != null and csg_static_body_root.visible)
			or (
				native_static_body_root != null
				and native_static_body_root.visible
			)
			or (csg_active_body_root != null and csg_active_body_root.visible)
		)

func _sync_bounded_checkpoint_csg_fallback(
	presentation: Dictionary
) -> bool:
	if presentation.is_empty() or csg_static_body_root == null:
		return false
	var checkpoint_count := _resolve_bounded_checkpoint_operation_count(
		presentation
	)
	var checkpoint_packet := _resolve_bounded_checkpoint_packet(presentation)
	if (
		checkpoint_count > 0
		and not _bounded_checkpoint_packet_is_materialized(
			checkpoint_packet,
			checkpoint_count
		)
	):
		return false
	var active_tail_bodies: Array = presentation.get(
		"active_tail_bodies",
		[]
	) as Array
	var protected_bodies: Array = presentation.get(
		"protected_bodies",
		[]
	) as Array
	var material_variant_id := _resolve_bounded_material_variant_id(
		presentation
	)
	for body_variant: Variant in active_tail_bodies:
		var body := body_variant as Resource
		if body == null:
			return false
		var validation := _validate_native_static_body(
			body,
			material_variant_id
		)
		if not bool(validation.get("ok", false)):
			return false
	var fallback_signature := _build_bounded_csg_fallback_signature(
		presentation
	)
	if (
		fallback_signature == bounded_csg_fallback_signature
		and csg_static_body_root.get_child_count() == 1
	):
		csg_static_body_root.visible = true
		return true
	_discard_csg_static_zone_cache()
	var combiner := CSGCombiner3D.new()
	combiner.name = "BoundedCheckpointTailFallback"
	combiner.operation = CSGShape3D.OPERATION_UNION
	combiner.calculate_tangents = false
	var shape_count := 0
	if checkpoint_count > 0:
		if protected_bodies.is_empty():
			if not _append_bounded_checkpoint_csg_mesh(
				combiner,
				checkpoint_packet,
				material_variant_id,
				false,
				shape_count
			):
				combiner.free()
				return false
		else:
			var checkpoint_combiner := CSGCombiner3D.new()
			checkpoint_combiner.name = "CheckpointResolved"
			checkpoint_combiner.operation = CSGShape3D.OPERATION_UNION
			checkpoint_combiner.calculate_tangents = false
			combiner.add_child(checkpoint_combiner)
			if not _append_bounded_checkpoint_csg_mesh(
				checkpoint_combiner,
				checkpoint_packet,
				material_variant_id,
				false,
				0
			):
				combiner.free()
				return false
			var checkpoint_clip_index := 1
			for protected_variant: Variant in protected_bodies:
				var protected_body := protected_variant as Resource
				if protected_body == null:
					continue
				if _append_csg_body_shape(
					checkpoint_combiner,
					protected_body,
					material_variant_id,
					true,
					checkpoint_clip_index
				):
					checkpoint_clip_index += 1
		shape_count += 1
	for body_variant: Variant in active_tail_bodies:
		var body := body_variant as Resource
		if _append_csg_clipped_body_shape(
			combiner,
			body,
			protected_bodies,
			material_variant_id,
			shape_count,
			false
		):
			shape_count += 1
	for protected_variant: Variant in protected_bodies:
		var protected_body := protected_variant as Resource
		if protected_body == null:
			continue
		var protected_material_id := StringName(protected_body.get(
			"material_variant_id"
		))
		if _append_csg_body_shape(
			combiner,
			protected_body,
			protected_material_id,
			false,
			shape_count
		):
			shape_count += 1
	if shape_count <= 0:
		combiner.free()
		csg_static_body_root.visible = false
		bounded_csg_fallback_signature = fallback_signature
		return true
	var primary_body_ids: Array[StringName] = []
	for body_collection: Array in [active_tail_bodies, protected_bodies]:
		for body_variant: Variant in body_collection:
			var body := body_variant as Resource
			if body == null:
				continue
			primary_body_ids.append(StringName(body.get("body_id")))
	var fallback_identity := _build_native_static_surface_identity(
		active_tail_bodies,
		presentation
	)
	var checkpoint_surface_id := StringName(fallback_identity.get(
		"surface_target_id",
		StringName()
	))
	_configure_material_surface_collision(
		combiner,
		material_variant_id,
		true,
		_resolve_zone_collision_body_id(primary_body_ids),
		checkpoint_surface_id
	)
	combiner.visible = true
	csg_static_body_root.add_child(combiner)
	csg_static_body_root.visible = true
	bounded_csg_fallback_signature = fallback_signature
	csg_static_sync_diagnostics["last_mode"] = (
		"bounded_checkpoint_tail_fallback"
	)
	return true


func _append_bounded_checkpoint_csg_mesh(
	parent: Node,
	checkpoint_packet: Dictionary,
	material_variant_id: StringName,
	is_subtraction: bool,
	shape_index: int
) -> bool:
	if parent == null:
		return false
	var vertices: PackedVector3Array = checkpoint_packet.get(
		"vertices",
		PackedVector3Array()
	)
	var indices: PackedInt32Array = checkpoint_packet.get(
		"indices",
		PackedInt32Array()
	)
	var mesh_result := _build_indexed_array_mesh(vertices, indices)
	if not bool(mesh_result.get("ok", false)):
		return false
	var csg_mesh := CSGMesh3D.new()
	csg_mesh.name = "CheckpointMesh_%03d" % shape_index
	csg_mesh.operation = (
		CSGShape3D.OPERATION_SUBTRACTION
		if is_subtraction
		else CSGShape3D.OPERATION_UNION
	)
	csg_mesh.calculate_tangents = false
	csg_mesh.mesh = mesh_result.get("mesh", null) as ArrayMesh
	csg_mesh.material = _build_csg_body_material(
		material_variant_id,
		is_subtraction
	)
	csg_mesh.set_meta("forge_v2_bounded_checkpoint", true)
	parent.add_child(csg_mesh)
	return true


func _build_indexed_array_mesh(
	vertices: PackedVector3Array,
	indices: PackedInt32Array
) -> Dictionary:
	if vertices.is_empty() or indices.is_empty() or indices.size() % 3 != 0:
		return {"ok": false, "reason": "indexed_mesh_empty_or_unaligned"}
	var surface_tool := SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index_value: int in indices:
		if index_value < 0 or index_value >= vertices.size():
			return {"ok": false, "reason": "indexed_mesh_index_invalid"}
		surface_tool.add_vertex(vertices[index_value])
	surface_tool.index()
	surface_tool.generate_normals()
	var mesh: ArrayMesh = surface_tool.commit()
	if mesh == null or mesh.get_surface_count() != 1:
		return {"ok": false, "reason": "indexed_mesh_commit_failed"}
	return {"ok": true, "mesh": mesh}


func _build_bounded_csg_fallback_signature(
	presentation: Dictionary
) -> String:
	var signature_parts := PackedStringArray([
		str(int(presentation.get(
			"transition_revision",
			presentation.get("revision", -1)
		))),
		str(_resolve_bounded_checkpoint_operation_count(presentation)),
	])
	var checkpoint := presentation.get("checkpoint", null) as Resource
	if checkpoint != null:
		signature_parts.append(str(int(checkpoint.get("revision"))))
		signature_parts.append(str(int(checkpoint.get(
			"materialized_mesh_operation_count"
		))))
	for collection_name: String in [
		"active_tail_bodies",
		"protected_bodies",
	]:
		var bodies: Array = presentation.get(collection_name, []) as Array
		for body_variant: Variant in bodies:
			var body := body_variant as Resource
			signature_parts.append(_build_native_static_body_signature(body))
	return "|".join(signature_parts)


func _build_csg_zone_node(
	zone: Dictionary,
	enable_collision: bool,
	name_prefix: String
) -> CSGCombiner3D:
	var material_variant_id: StringName = StringName(zone.get("material_variant_id", StringName()))
	var primary_body_ids: Array = zone.get("primary_body_ids", []) as Array
	var combiner := CSGCombiner3D.new()
	combiner.name = "%s_%s" % [name_prefix, String(zone.get("zone_key", String(material_variant_id)))]
	combiner.operation = CSGShape3D.OPERATION_UNION
	combiner.calculate_tangents = false
	var body_shape_index := 0
	var body_records: Array = zone.get("body_records", []) as Array
	for body_record_variant: Variant in body_records:
		if not (body_record_variant is Dictionary):
			continue
		var body_record: Dictionary = body_record_variant as Dictionary
		var body: Resource = body_record.get("body", null) as Resource
		var clip_bodies: Array = body_record.get("clip_bodies", []) as Array
		var is_active_body := bool(body_record.get("is_active_body", false))
		if _append_csg_clipped_body_shape(
			combiner,
			body,
			clip_bodies,
			material_variant_id,
				body_shape_index,
				false
			):
			body_shape_index += 1
	combiner.visible = body_shape_index > 0
	_configure_material_surface_collision(
		combiner,
		material_variant_id,
		enable_collision and body_shape_index > 0,
		_resolve_zone_collision_body_id(primary_body_ids),
		StringName(zone.get(
			"surface_target_id",
			_build_zone_surface_target_id(String(zone.get("zone_key", "")))
		))
	)
	return combiner

func _ensure_preview_mesh_instance() -> void:
	if preview_mesh_instance != null and is_instance_valid(preview_mesh_instance):
		return
	preview_mesh_instance = get_node_or_null("VolumeStrokePreviewMesh") as MeshInstance3D
	if preview_mesh_instance != null:
		return
	preview_mesh_instance = MeshInstance3D.new()
	preview_mesh_instance.name = "VolumeStrokePreviewMesh"
	add_child(preview_mesh_instance)

func _ensure_spline_preview_mesh_instance() -> void:
	if spline_preview_mesh_instance != null and is_instance_valid(spline_preview_mesh_instance):
		return
	spline_preview_mesh_instance = get_node_or_null("SplineLinePreviewMesh") as MeshInstance3D
	if spline_preview_mesh_instance != null:
		return
	spline_preview_mesh_instance = MeshInstance3D.new()
	spline_preview_mesh_instance.name = "SplineLinePreviewMesh"
	add_child(spline_preview_mesh_instance)

func _ensure_spline_invalid_preview_mesh_instance() -> void:
	if (
		spline_invalid_preview_mesh_instance != null
		and is_instance_valid(spline_invalid_preview_mesh_instance)
	):
		return
	spline_invalid_preview_mesh_instance = get_node_or_null(
		"SplineLineInvalidPreviewMesh"
	) as MeshInstance3D
	if spline_invalid_preview_mesh_instance == null:
		spline_invalid_preview_mesh_instance = MeshInstance3D.new()
		spline_invalid_preview_mesh_instance.name = (
			"SplineLineInvalidPreviewMesh"
		)
		add_child(spline_invalid_preview_mesh_instance)
	spline_invalid_preview_mesh_instance.cast_shadow = (
		GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	)
	spline_invalid_preview_mesh_instance.visible = false

func _ensure_spline_csg_nodes() -> void:
	if spline_csg_path == null or not is_instance_valid(spline_csg_path):
		spline_csg_path = get_node_or_null("SplineCsgPath") as Path3D
		if spline_csg_path == null:
			spline_csg_path = Path3D.new()
			spline_csg_path.name = "SplineCsgPath"
			add_child(spline_csg_path)
	if spline_csg_polygon == null or not is_instance_valid(spline_csg_polygon):
		spline_csg_polygon = get_node_or_null("SplineCsgNoodle") as CSGPolygon3D
		if spline_csg_polygon == null:
			spline_csg_polygon = CSGPolygon3D.new()
			spline_csg_polygon.name = "SplineCsgNoodle"
			add_child(spline_csg_polygon)
	spline_csg_polygon.calculate_tangents = false
	spline_csg_polygon.visible = false

func _ensure_active_material_body_preview_mesh_instance() -> void:
	if (
		active_material_body_preview_mesh_instance != null
		and is_instance_valid(active_material_body_preview_mesh_instance)
	):
		return
	active_material_body_preview_mesh_instance = get_node_or_null(
		"ActiveMaterialBodySweepPreviewMesh"
	) as MeshInstance3D
	if active_material_body_preview_mesh_instance == null:
		active_material_body_preview_mesh_instance = MeshInstance3D.new()
		active_material_body_preview_mesh_instance.name = (
			"ActiveMaterialBodySweepPreviewMesh"
		)
		add_child(active_material_body_preview_mesh_instance)
	active_material_body_preview_mesh_instance.cast_shadow = (
		GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	)
	active_material_body_preview_mesh_instance.set_meta(
		"forge_v2_non_authoritative_live_preview",
		true
	)
	active_material_body_preview_mesh_instance.visible = false

func _ensure_csg_material_body_root() -> void:
	if csg_material_body_root != null and is_instance_valid(csg_material_body_root):
		_ensure_csg_material_body_branch_roots()
		return
	csg_material_body_root = get_node_or_null("MaterialBodyCsgRoot") as Node3D
	if csg_material_body_root == null:
		csg_material_body_root = Node3D.new()
		csg_material_body_root.name = "MaterialBodyCsgRoot"
		add_child(csg_material_body_root)
	_ensure_csg_material_body_branch_roots()

func _ensure_csg_material_body_branch_roots() -> void:
	if csg_material_body_root == null:
		return
	if csg_static_body_root == null or not is_instance_valid(csg_static_body_root):
		csg_static_body_root = csg_material_body_root.get_node_or_null("StaticMaterialBodyCsgRoot") as Node3D
		if csg_static_body_root == null:
			csg_static_body_root = Node3D.new()
			csg_static_body_root.name = "StaticMaterialBodyCsgRoot"
			csg_material_body_root.add_child(csg_static_body_root)
	if csg_active_body_root == null or not is_instance_valid(csg_active_body_root):
		csg_active_body_root = csg_material_body_root.get_node_or_null("ActiveMaterialBodyCsgRoot") as Node3D
		if csg_active_body_root == null:
			csg_active_body_root = Node3D.new()
			csg_active_body_root.name = "ActiveMaterialBodyCsgRoot"
			csg_material_body_root.add_child(csg_active_body_root)
	if native_static_body_root == null or not is_instance_valid(native_static_body_root):
		native_static_body_root = csg_material_body_root.get_node_or_null(
			"NativeStaticMaterialBodyRoot"
		) as Node3D
		if native_static_body_root == null:
			native_static_body_root = Node3D.new()
			native_static_body_root.name = "NativeStaticMaterialBodyRoot"
			csg_material_body_root.add_child(native_static_body_root)
		native_static_body_root.visible = native_static_authoritative

func _clear_csg_material_body_root() -> bool:
	if csg_material_body_root == null:
		return true
	var reset_result := _reset_native_static_lane(
		NATIVE_STATIC_LIFECYCLE_UNOBSERVED,
		"presenter_cleared"
	)
	if not bool(reset_result.get("ok", false)):
		return false
	for child: Node in csg_material_body_root.get_children():
		csg_material_body_root.remove_child(child)
		child.free()
	csg_static_body_root = null
	csg_active_body_root = null
	native_static_body_root = null
	csg_static_zone_nodes = {}
	csg_static_zone_signatures = {}
	csg_static_zone_body_ids_by_key = {}
	csg_static_body_zone_key_by_id = {}
	csg_static_zones_initialized = false
	csg_static_body_order_snapshot = []
	csg_static_body_signatures_by_id = {}
	csg_static_target_metadata_generation += 1
	csg_static_sync_diagnostics["last_mode"] = "cleared"
	csg_static_sync_diagnostics["last_appended_body_id"] = StringName()
	csg_static_sync_diagnostics["last_fallback_reason"] = ""
	_ensure_csg_material_body_branch_roots()
	return true

func _clear_node_children(parent: Node) -> void:
	if parent == null:
		return
	for child: Node in parent.get_children():
		parent.remove_child(child)
		child.free()

func _configure_material_surface_collision(
	shape: CSGShape3D,
	material_variant_id: StringName,
	enabled: bool,
	body_id: StringName = StringName(),
	surface_target_id: StringName = StringName()
) -> void:
	if shape == null:
		return
	shape.use_collision = enabled
	shape.collision_layer = MATERIAL_SURFACE_COLLISION_LAYER if enabled else 0
	shape.collision_mask = 0
	shape.set_meta("forge_v2_material_surface", enabled)
	shape.set_meta("forge_v2_material_variant_id", material_variant_id)
	shape.set_meta("forge_v2_body_id", body_id)
	shape.set_meta("forge_v2_surface_target_id", surface_target_id)

func _get_active_placement_body_id() -> StringName:
	if active_stage_controller == null or not active_stage_controller.has_method("get_active_placement_body_id"):
		return StringName()
	return StringName(active_stage_controller.call("get_active_placement_body_id"))

func _find_active_material_body(authoring_state: Resource) -> Resource:
	var active_body_id := _get_active_placement_body_id()
	if active_body_id == StringName() or authoring_state == null:
		return null
	var material_bodies: Array = authoring_state.get("material_bodies")
	for body_variant: Variant in material_bodies:
		if not (body_variant is Resource):
			continue
		var body: Resource = body_variant as Resource
		if StringName(body.get("body_id")) != active_body_id:
			continue
		if body.get("layer_active") is bool and not bool(body.get("layer_active")):
			return null
		return body
	return null

func _is_pending_user_material_body(body: Resource) -> bool:
	if body == null:
		return false
	if StringName(body.get("committed_layer_id")) != StringName():
		return false
	return not (
		body.has_method("is_platform_seed")
		and bool(body.call("is_platform_seed"))
	)

func _sync_pending_material_body_previews(
	pending_bodies: Array
) -> void:
	if csg_active_body_root == null:
		return
	_clear_node_children(csg_active_body_root)
	var preview_bodies: Array = []
	var preview_body_ids: Dictionary = {}
	for body_variant: Variant in pending_bodies:
		var pending_body := body_variant as Resource
		if pending_body == null:
			continue
		var pending_body_id := StringName(pending_body.get("body_id"))
		preview_bodies.append(pending_body)
		preview_body_ids[pending_body_id] = true
	# A committed capsule remains visible as a non-authoritative overlay while
	# its exact one-body CSG mesh and the resulting native publication finish.
	for entry_variant: Variant in native_capsule_operand_pending.values():
		var pending_entry := entry_variant as Dictionary
		var native_pending_body := pending_entry.get("body", null) as Resource
		if native_pending_body == null:
			continue
		if (
			native_pending_body.get("layer_active") is bool
			and not bool(native_pending_body.get("layer_active"))
		):
			continue
		var native_pending_body_id := StringName(native_pending_body.get(
			"body_id"
		))
		if preview_body_ids.has(native_pending_body_id):
			continue
		preview_bodies.append(native_pending_body)
		preview_body_ids[native_pending_body_id] = true
	for body_index in range(preview_bodies.size()):
		var body := preview_bodies[body_index] as Resource
		if body == null:
			continue
		var pending_mesh := _build_active_material_body_sweep_mesh(body)
		if pending_mesh == null or pending_mesh.get_surface_count() <= 0:
			continue
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.name = "PendingMaterialBodyPreview_%03d" % body_index
		mesh_instance.mesh = pending_mesh
		mesh_instance.material_override = (
			_build_active_material_body_preview_material(
				_is_remove_material_body(body)
			)
		)
		mesh_instance.cast_shadow = (
			GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		)
		mesh_instance.set_meta(
			"forge_v2_non_authoritative_pending_preview",
			true
		)
		mesh_instance.set_meta(
			"forge_v2_pending_body_id",
			StringName(body.get("body_id"))
		)
		csg_active_body_root.add_child(mesh_instance)
	csg_active_body_root.visible = csg_active_body_root.get_child_count() > 0

func _clear_active_material_body_preview_metadata() -> void:
	if active_material_body_preview_mesh_instance == null:
		return
	for metadata_name: StringName in [
		&"forge_v2_active_body_id",
		&"forge_v2_profile_vertex_count",
		&"forge_v2_path_point_count",
		&"forge_v2_path_surface_normal_count",
		&"forge_v2_path_contact_direction_count",
		&"forge_v2_profile_rotation_bias_degrees",
	]:
		if active_material_body_preview_mesh_instance.has_meta(metadata_name):
			active_material_body_preview_mesh_instance.remove_meta(metadata_name)

func _collect_active_placement_preview_records(authoring_state: Resource) -> Array:
	var active_body_id := _get_active_placement_body_id()
	if active_body_id == StringName() or authoring_state == null:
		return []
	var preview_records: Array = []
	var material_bodies: Array = authoring_state.get("material_bodies")
	for body_variant: Variant in material_bodies:
		if not (body_variant is Resource):
			continue
		var body: Resource = body_variant as Resource
		if StringName(body.get("body_id")) != active_body_id:
			continue
		if body.get("layer_active") is bool and not bool(body.get("layer_active")):
			continue
		preview_records.append(body)
		return preview_records
	return preview_records

func _has_csg_material_body_records(authoring_state: Resource) -> bool:
	if authoring_state == null:
		return false
	var material_bodies: Array = authoring_state.get("material_bodies")
	for body_variant: Variant in material_bodies:
		if not (body_variant is Resource):
			continue
		var body: Resource = body_variant as Resource
		if body.get("layer_active") is bool and not bool(body.get("layer_active")):
			continue
		var path_points: PackedVector3Array = body.get("path_points")
		if not path_points.is_empty():
			return true
	return false

func _collect_csg_material_body_groups(authoring_state: Resource) -> Dictionary:
	if authoring_state == null:
		return {}
	var material_bodies: Array = _collect_active_csg_material_bodies(authoring_state)
	return _collect_csg_material_body_groups_from_bodies(material_bodies)

func _collect_csg_material_body_groups_from_bodies(material_bodies: Array) -> Dictionary:
	var material_groups: Dictionary = {}
	var active_body_id := _get_active_placement_body_id()
	for body_index in range(material_bodies.size()):
		var body: Resource = material_bodies[body_index] as Resource
		if _is_remove_material_body(body):
			continue
		var material_variant_id: StringName = StringName(body.get("material_variant_id"))
		var group_record: Dictionary = material_groups.get(material_variant_id, {
			"body_records": [],
		}) as Dictionary
		var body_records: Array = group_record.get("body_records", []) as Array
		body_records.append({
			"body": body,
			"clip_bodies": _collect_csg_clip_bodies_for_add_body(material_bodies, body_index),
			"is_active_body": active_body_id != StringName() and StringName(body.get("body_id")) == active_body_id,
		})
		group_record["body_records"] = body_records
		material_groups[material_variant_id] = group_record
	return material_groups

func _find_body_index_by_id(material_bodies: Array, body_id: StringName) -> int:
	if body_id == StringName():
		return -1
	for body_index in range(material_bodies.size()):
		var body: Resource = material_bodies[body_index] as Resource
		if body != null and StringName(body.get("body_id")) == body_id:
			return body_index
	return -1

func _filter_body_list_excluding_id(material_bodies: Array, excluded_body_id: StringName) -> Array:
	var filtered_bodies: Array = []
	for body_variant: Variant in material_bodies:
		if not (body_variant is Resource):
			continue
		var body: Resource = body_variant as Resource
		if excluded_body_id != StringName() and StringName(body.get("body_id")) == excluded_body_id:
			continue
		filtered_bodies.append(body)
	return filtered_bodies

func _collect_direct_dirty_primary_body_ids(material_bodies: Array, active_body_index: int) -> Array[StringName]:
	var dirty_body_ids: Array[StringName] = []
	if active_body_index < 0 or active_body_index >= material_bodies.size():
		return dirty_body_ids
	var active_body: Resource = material_bodies[active_body_index] as Resource
	var active_bounds: AABB = _build_csg_body_bounds(active_body)
	for body_index in range(material_bodies.size()):
		if body_index == active_body_index:
			continue
		var body: Resource = material_bodies[body_index] as Resource
		if body == null or _is_remove_material_body(body):
			continue
		if _csg_body_bounds_intersect(active_bounds, _build_csg_body_bounds(body)):
			dirty_body_ids.append(StringName(body.get("body_id")))
	return dirty_body_ids

func _resolve_static_zone_keys_for_body_ids(body_ids: Array[StringName]) -> Dictionary:
	var zone_keys: Dictionary = {}
	for body_id: StringName in body_ids:
		var zone_key := String(csg_static_body_zone_key_by_id.get(body_id, ""))
		if not zone_key.is_empty():
			zone_keys[zone_key] = true
	return zone_keys

func _resolve_static_primary_body_ids_for_zone_keys(zone_keys: Dictionary) -> Array[StringName]:
	var body_ids: Array[StringName] = []
	for zone_key_variant: Variant in zone_keys.keys():
		var zone_key := String(zone_key_variant)
		var zone_body_ids: Array = csg_static_zone_body_ids_by_key.get(zone_key, []) as Array
		for body_id_variant: Variant in zone_body_ids:
			var body_id := StringName(body_id_variant)
			if not body_ids.has(body_id):
				body_ids.append(body_id)
	return body_ids

func _apply_static_zone_visibility(hidden_zone_keys: Dictionary) -> void:
	if csg_static_body_root == null:
		return
	if native_static_body_root != null:
		native_static_body_root.visible = native_static_authoritative
	if native_static_authoritative:
		csg_static_body_root.visible = false
		return
	var has_visible_zone := false
	for zone_key_variant: Variant in csg_static_zone_nodes.keys():
		var zone_key := String(zone_key_variant)
		var zone_node: Node = csg_static_zone_nodes.get(zone_key, null) as Node
		if zone_node == null or not is_instance_valid(zone_node):
			continue
		var is_visible := not hidden_zone_keys.has(zone_key)
		zone_node.visible = is_visible
		has_visible_zone = has_visible_zone or is_visible
	csg_static_body_root.visible = has_visible_zone

func _collect_active_dirty_zone_bodies(
	material_bodies: Array,
	active_body_index: int,
	dirty_primary_body_ids: Array[StringName]
) -> Array:
	var dirty_bodies: Array = []
	if active_body_index < 0 or active_body_index >= material_bodies.size():
		return dirty_bodies
	var dirty_bounds: Array[AABB] = []
	var active_body: Resource = material_bodies[active_body_index] as Resource
	if active_body == null:
		return dirty_bodies
	dirty_bodies.append(active_body)
	dirty_bounds.append(_build_csg_body_bounds(active_body))
	for body_variant: Variant in material_bodies:
		if not (body_variant is Resource):
			continue
		var body: Resource = body_variant as Resource
		var body_id := StringName(body.get("body_id"))
		if body_id == StringName(active_body.get("body_id")):
			continue
		if dirty_primary_body_ids.has(body_id):
			dirty_bodies.append(body)
			dirty_bounds.append(_build_csg_body_bounds(body))
	for body_variant: Variant in material_bodies:
		if not (body_variant is Resource):
			continue
		var body: Resource = body_variant as Resource
		if dirty_bodies.has(body):
			continue
		if _csg_body_intersects_any_bounds(body, dirty_bounds):
			dirty_bodies.append(body)
	return dirty_bodies

func _build_csg_body_zones(material_bodies: Array) -> Array:
	var records: Array = []
	var active_body_id := _get_active_placement_body_id()
	# The overwhelmingly common authoring case is one material, additive Replace,
	# with no handles or subtractive bodies.  In that case the clip list is
	# provably empty for every body; avoid scanning the full history once/body.
	var skip_clip_discovery := _can_skip_all_csg_clip_discovery(material_bodies)
	for body_index in range(material_bodies.size()):
		var body: Resource = material_bodies[body_index] as Resource
		if body == null or _is_remove_material_body(body):
			continue
		records.append({
			"body": body,
			"body_index": body_index,
			"material_variant_id": StringName(body.get("material_variant_id")),
			"bounds": _build_csg_body_bounds(body),
			"clip_bodies": (
				[]
				if skip_clip_discovery
				else _collect_csg_clip_bodies_for_add_body(material_bodies, body_index)
			),
			"is_active_body": active_body_id != StringName() and StringName(body.get("body_id")) == active_body_id,
		})
	if records.is_empty():
		return []
	var parents: Array[int] = []
	for record_index in range(records.size()):
		parents.append(record_index)
	_union_csg_zone_records_sweep(records, parents)
	var grouped_records: Dictionary = {}
	for record_index in range(records.size()):
		var root_index := _find_zone_parent(parents, record_index)
		var group_records: Array = grouped_records.get(root_index, []) as Array
		group_records.append(records[record_index])
		grouped_records[root_index] = group_records
	var zones: Array = []
	for root_key: Variant in grouped_records.keys():
		var group_records: Array = grouped_records[root_key] as Array
		zones.append(_build_csg_zone_from_records(group_records))
	return zones


func _can_skip_all_csg_clip_discovery(material_bodies: Array) -> bool:
	var shared_material_id := StringName()
	var found_body := false
	for body_variant: Variant in material_bodies:
		if not (body_variant is Resource):
			continue
		var body := body_variant as Resource
		if body == null:
			continue
		found_body = true
		if (
			_is_remove_material_body(body)
			or ForgeV2MaterialCompositionPolicyScript.is_protected_handle_entry(body)
			or ForgeV2MaterialCompositionPolicyScript.resolve_effective_placement_policy(body)
			== ForgeV2VolumeStrokeScript.PLACEMENT_EMPTY_ONLY
		):
			return false
		var material_id := StringName(body.get("material_variant_id"))
		if shared_material_id == StringName():
			shared_material_id = material_id
		elif material_id != shared_material_id:
			return false
	return found_body


func _union_csg_zone_records_sweep(records: Array, parents: Array[int]) -> void:
	if records.size() < 2:
		return
	var sweep_axis := _select_csg_zone_sweep_axis(records)
	var sorted_indices: Array[int] = []
	for record_index in range(records.size()):
		sorted_indices.append(record_index)
	sorted_indices.sort_custom(func(first_index: int, second_index: int) -> bool:
		var first_bounds: AABB = (records[first_index] as Dictionary).get("bounds", AABB()) as AABB
		var second_bounds: AABB = (records[second_index] as Dictionary).get("bounds", AABB()) as AABB
		var first_min := _csg_axis_component(first_bounds.position, sweep_axis)
		var second_min := _csg_axis_component(second_bounds.position, sweep_axis)
		return first_min < second_min or (is_equal_approx(first_min, second_min) and first_index < second_index)
	)
	# _csg_bounds_intersect grows both AABBs by 0.1 mm.  The 0.2 mm
	# conservative interval keeps every pair that could pass that exact test.
	const SWEEP_PAIR_MARGIN := 0.0002
	for first_sorted_index in range(sorted_indices.size()):
		var first_index := sorted_indices[first_sorted_index]
		var first_record := records[first_index] as Dictionary
		var first_bounds: AABB = first_record.get("bounds", AABB()) as AABB
		var first_max := (
			_csg_axis_component(first_bounds.position, sweep_axis)
			+ _csg_axis_component(first_bounds.size, sweep_axis)
		)
		for second_sorted_index in range(first_sorted_index + 1, sorted_indices.size()):
			var second_index := sorted_indices[second_sorted_index]
			var second_record := records[second_index] as Dictionary
			var second_bounds: AABB = second_record.get("bounds", AABB()) as AABB
			var second_min := _csg_axis_component(second_bounds.position, sweep_axis)
			if second_min > first_max + SWEEP_PAIR_MARGIN:
				break
			if (
				StringName(first_record.get("material_variant_id"))
				!= StringName(second_record.get("material_variant_id"))
			):
				continue
			if _csg_bounds_intersect(first_bounds, second_bounds):
				_union_zone_parent(parents, first_index, second_index)


func _select_csg_zone_sweep_axis(records: Array) -> int:
	var best_axis := 0
	var best_score := -INF
	for axis in range(3):
		var minimum := INF
		var maximum := -INF
		var total_extent := 0.0
		for record_variant: Variant in records:
			var bounds: AABB = (record_variant as Dictionary).get("bounds", AABB()) as AABB
			var axis_min := _csg_axis_component(bounds.position, axis)
			var axis_extent := maxf(_csg_axis_component(bounds.size, axis), 0.000001)
			minimum = minf(minimum, axis_min)
			maximum = maxf(maximum, axis_min + axis_extent)
			total_extent += axis_extent
		var average_extent := total_extent / float(records.size())
		var score := (maximum - minimum) / maxf(average_extent, 0.000001)
		if score > best_score:
			best_score = score
			best_axis = axis
	return best_axis


func _csg_axis_component(value: Vector3, axis: int) -> float:
	if axis == 1:
		return value.y
	if axis == 2:
		return value.z
	return value.x

func _build_csg_zone_from_records(records: Array) -> Dictionary:
	var primary_body_ids: Array[StringName] = []
	var body_records: Array = []
	var material_variant_id := StringName()
	for record_variant: Variant in records:
		if not (record_variant is Dictionary):
			continue
		var record: Dictionary = record_variant as Dictionary
		var body: Resource = record.get("body", null) as Resource
		if body == null:
			continue
		material_variant_id = StringName(record.get("material_variant_id", material_variant_id))
		var body_id := StringName(body.get("body_id"))
		if not primary_body_ids.has(body_id):
			primary_body_ids.append(body_id)
		body_records.append({
			"body": body,
			"clip_bodies": record.get("clip_bodies", []) as Array,
			"is_active_body": bool(record.get("is_active_body", false)),
		})
	primary_body_ids.sort()
	var id_parts: PackedStringArray = []
	for body_id: StringName in primary_body_ids:
		id_parts.append(String(body_id))
	var zone_key := "%s:%s" % [String(material_variant_id), ",".join(id_parts)]
	return {
		"zone_key": zone_key,
		"surface_target_id": _build_zone_surface_target_id(zone_key),
		"material_variant_id": material_variant_id,
		"primary_body_ids": primary_body_ids,
		"body_records": body_records,
		"signature": _build_csg_zone_signature(body_records),
	}

func _build_zone_surface_target_id(zone_key: String) -> StringName:
	if zone_key.is_empty():
		return StringName()
	return StringName("forge_v2_surface_zone_%s" % zone_key.sha256_text())

func _build_csg_zone_signature(body_records: Array) -> String:
	var parts: PackedStringArray = []
	for body_record_variant: Variant in body_records:
		if not (body_record_variant is Dictionary):
			continue
		var body_record: Dictionary = body_record_variant as Dictionary
		var body: Resource = body_record.get("body", null) as Resource
		var clip_bodies: Array = body_record.get("clip_bodies", []) as Array
		var clip_parts: PackedStringArray = []
		for clip_body_variant: Variant in clip_bodies:
			if clip_body_variant is Resource:
				clip_parts.append(_build_csg_body_signature(clip_body_variant as Resource))
		parts.append("%s clips[%s]" % [_build_csg_body_signature(body), " / ".join(clip_parts)])
	return "\n".join(parts)

func _resolve_zone_collision_body_id(primary_body_ids: Array) -> StringName:
	if primary_body_ids.size() == 1:
		return StringName(primary_body_ids[0])
	return StringName()

func _find_zone_parent(parents: Array[int], index: int) -> int:
	var current := index
	while parents[current] != current:
		current = parents[current]
	var root := current
	current = index
	while parents[current] != current:
		var next := parents[current]
		parents[current] = root
		current = next
	return root

func _union_zone_parent(parents: Array[int], first_index: int, second_index: int) -> void:
	var first_root := _find_zone_parent(parents, first_index)
	var second_root := _find_zone_parent(parents, second_index)
	if first_root != second_root:
		parents[second_root] = first_root

func _build_csg_body_bounds(body: Resource) -> AABB:
	if body == null:
		return AABB()
	var path_points: PackedVector3Array = body.get("path_points")
	if path_points.is_empty():
		return AABB()
	var min_point: Vector3 = path_points[0]
	var max_point: Vector3 = path_points[0]
	for point: Vector3 in path_points:
		min_point.x = minf(min_point.x, point.x)
		min_point.y = minf(min_point.y, point.y)
		min_point.z = minf(min_point.z, point.z)
		max_point.x = maxf(max_point.x, point.x)
		max_point.y = maxf(max_point.y, point.y)
		max_point.z = maxf(max_point.z, point.z)
	var radius := maxf(float(body.get("radius_meters")), 0.001)
	var margin := Vector3.ONE * radius
	return AABB(min_point - margin, (max_point - min_point) + (margin * 2.0))

func _csg_body_intersects_any_bounds(body: Resource, bounds_list: Array[AABB]) -> bool:
	var body_bounds := _build_csg_body_bounds(body)
	for bounds: AABB in bounds_list:
		if _csg_bounds_intersect(body_bounds, bounds):
			return true
	return false

func _csg_body_bounds_intersect(first_bounds: AABB, second_bounds: AABB) -> bool:
	return _csg_bounds_intersect(first_bounds, second_bounds)

func _csg_bounds_intersect(first_bounds: AABB, second_bounds: AABB) -> bool:
	var margin := 0.0001
	var grown_first := AABB(
		first_bounds.position - (Vector3.ONE * margin),
		first_bounds.size + (Vector3.ONE * margin * 2.0)
	)
	var grown_second := AABB(
		second_bounds.position - (Vector3.ONE * margin),
		second_bounds.size + (Vector3.ONE * margin * 2.0)
	)
	return grown_first.intersects(grown_second)

func _build_csg_body_list_signature(material_bodies: Array) -> String:
	if material_bodies.is_empty():
		return ""
	var parts: PackedStringArray = []
	for body_variant: Variant in material_bodies:
		if body_variant is Resource:
			parts.append(_build_csg_body_signature(body_variant as Resource))
	return "\n".join(parts)

func _build_csg_body_signature(body: Resource) -> String:
	if body == null:
		return ""
	var path_points: PackedVector3Array = body.get("path_points")
	var point_parts: PackedStringArray = []
	for point: Vector3 in path_points:
		point_parts.append("%.5f,%.5f,%.5f" % [point.x, point.y, point.z])
	var profile_polygon: PackedVector2Array = body.get("profile_polygon_2d_meters")
	var profile_point_parts: PackedStringArray = []
	for profile_point: Vector2 in profile_polygon:
		profile_point_parts.append("%.5f,%.5f" % [profile_point.x, profile_point.y])
	var profile_anchor_value: Variant = body.get("profile_anchor_2d_meters")
	var profile_anchor := Vector2.ZERO
	if profile_anchor_value is Vector2:
		profile_anchor = profile_anchor_value as Vector2
	var path_surface_normals: PackedVector3Array = body.get(
		"path_surface_normals"
	)
	var normal_parts: PackedStringArray = []
	for surface_normal: Vector3 in path_surface_normals:
		normal_parts.append("%.5f,%.5f,%.5f" % [
			surface_normal.x,
			surface_normal.y,
			surface_normal.z,
		])
	var path_contact_directions: PackedVector3Array = body.get(
		"path_contact_directions"
	)
	var contact_direction_parts: PackedStringArray = []
	for contact_direction_3d: Vector3 in path_contact_directions:
		contact_direction_parts.append("%.5f,%.5f,%.5f" % [
			contact_direction_3d.x,
			contact_direction_3d.y,
			contact_direction_3d.z,
		])
	var profile_contact_direction: Vector2 = body.get(
		"profile_contact_direction_2d"
	)
	var profile_contact_point_relative: Vector2 = body.get(
		"profile_contact_point_relative_2d_meters"
	)
	return "|".join([
		String(body.get("body_id")),
		String(body.get("body_kind")),
		String(body.get("material_variant_id")),
		String(body.get("operation_mode")),
		String(body.get("placement_policy")),
		String(body.get("shape_kind")),
		str(float(body.get("radius_meters"))),
		String(body.get("profile_id")),
		String(body.get("profile_role")),
		"%.5f,%.5f" % [profile_anchor.x, profile_anchor.y],
		"%.5f,%.5f" % [
			profile_contact_direction.x,
			profile_contact_direction.y,
		],
		"%.5f,%.5f" % [
			profile_contact_point_relative.x,
			profile_contact_point_relative.y,
		],
		str(int(body.get("profile_runtime_schema_version"))),
		str(float(body.get("profile_rotation_bias_degrees"))),
		str(float(body.get("profile_twist_degrees_per_meter"))),
		str(StringName(body.get("committed_layer_id"))),
		str(bool(body.get("layer_active"))),
		str(float(body.get("updated_timestamp"))),
		";".join(point_parts),
		";".join(normal_parts),
		";".join(contact_direction_parts),
		";".join(profile_point_parts),
	])

func _collect_active_csg_material_bodies(authoring_state: Resource) -> Array:
	var active_bodies: Array = []
	if authoring_state == null:
		return active_bodies
	var material_bodies: Array = authoring_state.get("material_bodies")
	for body_variant: Variant in material_bodies:
		if not (body_variant is Resource):
			continue
		var body: Resource = body_variant as Resource
		if body.get("layer_active") is bool and not bool(body.get("layer_active")):
			continue
		var path_points: PackedVector3Array = body.get("path_points")
		if path_points.is_empty():
			continue
		active_bodies.append(body)
	return active_bodies

func _collect_csg_clip_bodies_for_add_body(material_bodies: Array, body_index: int) -> Array:
	var clip_bodies: Array = []
	if body_index < 0 or body_index >= material_bodies.size():
		return clip_bodies
	var body: Resource = material_bodies[body_index] as Resource
	var body_bounds := _build_csg_body_bounds(body)
	var material_variant_id: StringName = StringName(body.get("material_variant_id"))
	var is_protected_handle := (
		ForgeV2MaterialCompositionPolicyScript.is_protected_handle_entry(body)
	)
	var placement_policy := (
		ForgeV2MaterialCompositionPolicyScript.resolve_effective_placement_policy(
			body
		)
	)
	if not is_protected_handle:
		for other_index in range(material_bodies.size()):
			if other_index == body_index:
				continue
			var other_body: Resource = material_bodies[other_index] as Resource
			if (
				other_body != null
				and ForgeV2MaterialCompositionPolicyScript.is_protected_handle_entry(
					other_body
				)
				and _csg_body_bounds_intersect(
					body_bounds,
					_build_csg_body_bounds(other_body)
				)
			):
				clip_bodies.append(other_body)
	if placement_policy == ForgeV2VolumeStrokeScript.PLACEMENT_EMPTY_ONLY:
		for previous_index in range(body_index):
			var previous_body: Resource = material_bodies[previous_index] as Resource
			if (
				previous_body != null
				and not _is_remove_material_body(previous_body)
				and not clip_bodies.has(previous_body)
				and _csg_body_bounds_intersect(body_bounds, _build_csg_body_bounds(previous_body))
			):
				clip_bodies.append(previous_body)
	for next_index in range(body_index + 1, material_bodies.size()):
		var next_body: Resource = material_bodies[next_index] as Resource
		if next_body == null:
			continue
		if not _csg_body_bounds_intersect(body_bounds, _build_csg_body_bounds(next_body)):
			continue
		var next_is_protected_handle := (
			ForgeV2MaterialCompositionPolicyScript.is_protected_handle_entry(
				next_body
			)
		)
		if next_is_protected_handle:
			if (
				is_protected_handle
				and StringName(next_body.get("material_variant_id"))
				!= material_variant_id
				and not clip_bodies.has(next_body)
			):
				clip_bodies.append(next_body)
			continue
		if is_protected_handle:
			continue
		if _is_remove_material_body(next_body):
			if not clip_bodies.has(next_body):
				clip_bodies.append(next_body)
			continue
		var next_policy: StringName = StringName(next_body.get("placement_policy"))
		var next_material_variant_id: StringName = StringName(next_body.get("material_variant_id"))
		if (
			next_policy == ForgeV2VolumeStrokeScript.PLACEMENT_REPLACE_EXISTING
			and next_material_variant_id != material_variant_id
		):
			if not clip_bodies.has(next_body):
				clip_bodies.append(next_body)
	return clip_bodies

func _is_remove_material_body(body: Resource) -> bool:
	return (
		body != null
		and ForgeV2MaterialCompositionPolicyScript.resolve_effective_operation_mode(
			body
		) == ForgeV2VolumeStrokeScript.OPERATION_REMOVE_MATERIAL
	)

func _append_csg_clipped_body_shape(
	parent: Node,
	body: Resource,
	clip_bodies: Array,
	material_variant_id: StringName,
	body_shape_index: int,
	enable_collision: bool
) -> bool:
	if parent == null or body == null:
		return false
	var body_combiner := CSGCombiner3D.new()
	body_combiner.name = "BodyResolved_%03d" % body_shape_index
	body_combiner.operation = CSGShape3D.OPERATION_UNION
	body_combiner.calculate_tangents = false
	parent.add_child(body_combiner)
	var child_shape_index := 0
	if not _append_csg_body_shape(body_combiner, body, material_variant_id, false, child_shape_index):
		parent.remove_child(body_combiner)
		body_combiner.free()
		return false
	child_shape_index += 1
	for clip_body_variant: Variant in clip_bodies:
		if not (clip_body_variant is Resource):
			continue
		var clip_body: Resource = clip_body_variant as Resource
		if _append_csg_body_shape(body_combiner, clip_body, material_variant_id, true, child_shape_index):
			child_shape_index += 1
	body_combiner.visible = true
	_configure_material_surface_collision(
		body_combiner,
		material_variant_id,
		enable_collision,
		StringName(body.get("body_id"))
	)
	return true

func _append_csg_body_shape(
	parent: Node,
	body: Resource,
	material_variant_id: StringName,
	is_subtraction: bool,
	body_shape_index: int
) -> bool:
	if parent == null or body == null:
		return false
	var path_points: PackedVector3Array = body.get("path_points")
	if path_points.is_empty():
		return false
	var radius_meters: float = maxf(float(body.get("radius_meters")), 0.001)
	var operation := CSGShape3D.OPERATION_SUBTRACTION if is_subtraction else CSGShape3D.OPERATION_UNION
	var shape_kind: StringName = StringName(body.get("shape_kind"))
	if _is_profile_shape_kind(shape_kind) and path_points.size() < 2:
		return false
	if path_points.size() == 1:
		var sphere := CSGSphere3D.new()
		sphere.name = "BodySphere_%03d" % body_shape_index
		sphere.operation = operation
		sphere.calculate_tangents = false
		sphere.radius = radius_meters
		sphere.position = path_points[0]
		sphere.material = _build_csg_body_material(material_variant_id, is_subtraction)
		parent.add_child(sphere)
		return true
	var path_sampling_radius_meters := radius_meters
	if int(body.get("profile_runtime_schema_version")) > 0:
		path_sampling_radius_meters = maxf(
			float(body.get("profile_contact_distance_meters")),
			ForgeV2ProfileShapeLibraryScript.BASIC_PROFILE_ANCHOR_CLEARANCE_METERS
		)
	var path_interval_meters := _resolve_spline_csg_path_interval(
		path_sampling_radius_meters
	)
	if _is_profile_shape_kind(shape_kind):
		var profile_polygon := _resolve_body_profile_polygon(body)
		if _uses_explicit_surface_profile_frame(body):
			return _append_csg_body_explicit_surface_sweep(
				parent,
				body,
				material_variant_id,
				is_subtraction,
				operation,
				body_shape_index
			)
		var curve: Curve3D = (
			_build_spline_csg_curve(path_points, path_interval_meters)
			if shape_kind == ForgeV2MaterialBodyScript.SHAPE_KIND_SPLINE_PROFILE_PATH
			else _build_linear_csg_curve(path_points, path_interval_meters)
		)
		if int(body.get("profile_runtime_schema_version")) > 0:
			_apply_profile_curve_orientation(
				curve,
				path_points,
				body.get("path_surface_normals") as PackedVector3Array,
				body.get("profile_contact_direction_2d") as Vector2,
				float(body.get("profile_rotation_bias_degrees"))
			)
		return _append_csg_body_path_shape(
			parent,
			curve,
			radius_meters,
			material_variant_id,
			is_subtraction,
			operation,
			body_shape_index,
			0,
			profile_polygon
		)
	if shape_kind == ForgeV2MaterialBodyScript.SHAPE_KIND_SPLINE_CAPSULE_PATH:
		return _append_csg_body_path_shape(
			parent,
			_build_spline_csg_curve(path_points, path_interval_meters),
			radius_meters,
			material_variant_id,
			is_subtraction,
			operation,
			body_shape_index,
			0
		)
	return _append_csg_body_path_shape(
		parent,
		_build_linear_csg_curve(path_points, path_interval_meters),
		radius_meters,
		material_variant_id,
		is_subtraction,
		operation,
		body_shape_index,
		0
	)

func _append_csg_body_explicit_surface_sweep(
	parent: Node,
	body: Resource,
	material_variant_id: StringName,
	is_subtraction: bool,
	operation: int,
	body_shape_index: int
) -> bool:
	if parent == null or body == null:
		return false
	var sweep_mesh := _build_active_material_body_sweep_mesh(body)
	if sweep_mesh == null or sweep_mesh.get_surface_count() <= 0:
		return false
	var csg_mesh := CSGMesh3D.new()
	csg_mesh.name = "BodySurfaceSweep_%03d" % body_shape_index
	csg_mesh.operation = operation
	csg_mesh.calculate_tangents = false
	csg_mesh.mesh = sweep_mesh
	csg_mesh.material = _build_csg_body_material(
		material_variant_id,
		is_subtraction
	)
	csg_mesh.set_meta("forge_v2_explicit_surface_frame", true)
	parent.add_child(csg_mesh)
	return true

func _append_csg_body_path_shape(
	parent: Node,
	curve: Curve3D,
	radius_meters: float,
	material_variant_id: StringName,
	is_subtraction: bool,
	operation: int,
	body_shape_index: int,
	span_index: int,
	profile_polygon_2d_meters: PackedVector2Array = PackedVector2Array()
) -> bool:
	if parent == null or curve == null or curve.point_count < 2:
		return false
	var path := Path3D.new()
	path.name = "BodyPath_%03d_%03d" % [body_shape_index, span_index]
	path.curve = curve
	parent.add_child(path)
	var polygon := CSGPolygon3D.new()
	polygon.name = "BodyNoodle_%03d_%03d" % [body_shape_index, span_index]
	parent.add_child(polygon)
	polygon.operation = operation
	polygon.calculate_tangents = false
	polygon.mode = CSGPolygon3D.MODE_PATH
	polygon.path_node = polygon.get_path_to(path)
	polygon.path_interval_type = CSGPolygon3D.PATH_INTERVAL_DISTANCE
	polygon.path_interval = maxf(curve.bake_interval, 0.001)
	polygon.path_rotation = CSGPolygon3D.PATH_ROTATION_PATH_FOLLOW
	polygon.path_rotation_accurate = true
	polygon.path_continuous_u = true
	polygon.path_u_distance = 0.0
	polygon.smooth_faces = true
	if profile_polygon_2d_meters.size() >= 3:
		polygon.polygon = profile_polygon_2d_meters
	else:
		polygon.polygon = _build_circle_profile_polygon(radius_meters, SPLINE_CSG_CIRCLE_SIDES)
	polygon.material = _build_csg_body_material(material_variant_id, is_subtraction)
	return true

func _ensure_placement_cursor_mesh_instance() -> void:
	if placement_cursor_mesh_instance != null and is_instance_valid(placement_cursor_mesh_instance):
		return
	placement_cursor_mesh_instance = get_node_or_null("PlacementCursorMesh") as MeshInstance3D
	if placement_cursor_mesh_instance == null:
		placement_cursor_mesh_instance = MeshInstance3D.new()
		placement_cursor_mesh_instance.name = "PlacementCursorMesh"
		add_child(placement_cursor_mesh_instance)
	placement_cursor_mesh_instance.visible = false
	placement_cursor_mesh_instance.material_override = _build_placement_cursor_material()

func _sync_placement_cursor(local_position: Vector3, is_valid: bool, radius_meters: float) -> void:
	_ensure_placement_cursor_mesh_instance()
	if placement_cursor_mesh_instance == null:
		return
	placement_cursor_mesh_instance.visible = is_valid
	if not is_valid:
		return
	var sphere_mesh: SphereMesh = placement_cursor_mesh_instance.mesh as SphereMesh
	if sphere_mesh == null:
		sphere_mesh = SphereMesh.new()
		placement_cursor_mesh_instance.mesh = sphere_mesh
	var cursor_radius: float = maxf(radius_meters, 0.004)
	sphere_mesh.radius = cursor_radius
	sphere_mesh.height = cursor_radius * 2.0
	placement_cursor_mesh_instance.position = local_position

func _build_active_material_body_sweep_mesh(body: Resource) -> ArrayMesh:
	if body == null:
		return ArrayMesh.new()
	var path_points: PackedVector3Array = body.get("path_points")
	if path_points.is_empty():
		return ArrayMesh.new()
	var profile_polygon := _resolve_active_body_sweep_polygon(body)
	if profile_polygon.size() < 3:
		return ArrayMesh.new()
	profile_polygon = _ensure_counter_clockwise_profile_polygon(profile_polygon)
	var surface_tool := SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var preview_color := _resolve_active_material_body_preview_color(body)
	var added_vertices := 0
	if path_points.size() == 1:
		if _is_profile_shape_kind(StringName(body.get("shape_kind"))):
			added_vertices = _append_single_profile_preview(
				surface_tool,
				body,
				profile_polygon,
				preview_color
			)
		else:
			added_vertices = _append_sphere(
				surface_tool,
				path_points[0],
				maxf(float(body.get("radius_meters")), 0.001),
				preview_color
			)
	else:
		added_vertices = _append_linear_profile_sweep_preview(
			surface_tool,
			body,
			profile_polygon,
			preview_color
		)
	if added_vertices <= 0:
		return ArrayMesh.new()
	surface_tool.index()
	surface_tool.generate_normals()
	return surface_tool.commit()

func _resolve_active_body_sweep_polygon(body: Resource) -> PackedVector2Array:
	if body == null:
		return PackedVector2Array()
	var shape_kind := StringName(body.get("shape_kind"))
	if _is_profile_shape_kind(shape_kind):
		return _resolve_body_profile_polygon(body)
	return _build_circle_profile_polygon(
		maxf(float(body.get("radius_meters")), 0.001),
		PREVIEW_TUBE_SIDES
	)

func _ensure_counter_clockwise_profile_polygon(
	profile_polygon: PackedVector2Array
) -> PackedVector2Array:
	var signed_area_twice := 0.0
	for point_index in range(profile_polygon.size()):
		var point_a: Vector2 = profile_polygon[point_index]
		var point_b: Vector2 = profile_polygon[
			(point_index + 1) % profile_polygon.size()
		]
		signed_area_twice += point_a.cross(point_b)
	if signed_area_twice >= 0.0:
		return profile_polygon
	var reversed_polygon := PackedVector2Array()
	for point_index in range(profile_polygon.size() - 1, -1, -1):
		reversed_polygon.append(profile_polygon[point_index])
	return reversed_polygon

func _append_single_profile_preview(
	surface_tool: SurfaceTool,
	body: Resource,
	profile_polygon: PackedVector2Array,
	color: Color
) -> int:
	var path_points: PackedVector3Array = body.get("path_points")
	if path_points.is_empty():
		return 0
	var tangent := Vector3.RIGHT
	var ring := _build_profile_sweep_ring(
		body,
		profile_polygon,
		0,
		tangent
	)
	return _append_profile_sweep_caps(
		surface_tool,
		ring,
		profile_polygon,
		color,
		true,
		Geometry2D.triangulate_polygon(profile_polygon)
	)

func _append_linear_profile_sweep_preview(
	surface_tool: SurfaceTool,
	body: Resource,
	profile_polygon: PackedVector2Array,
	color: Color
) -> int:
	var path_points: PackedVector3Array = body.get("path_points")
	if path_points.size() < 2:
		return 0
	var rings: Array[PackedVector3Array] = []
	for point_index in range(path_points.size()):
		rings.append(_build_profile_sweep_ring(
			body,
			profile_polygon,
			point_index,
			_resolve_linear_path_point_tangent(path_points, point_index)
		))
	var cap_indices := Geometry2D.triangulate_polygon(profile_polygon)
	var added_vertices := 0
	for ring_index in range(rings.size() - 1):
		var from_ring: PackedVector3Array = rings[ring_index]
		var to_ring: PackedVector3Array = rings[ring_index + 1]
		for profile_index in range(profile_polygon.size()):
			var next_profile_index := (
				(profile_index + 1) % profile_polygon.size()
			)
			added_vertices += _append_triangle(
				surface_tool,
				from_ring[profile_index],
				to_ring[next_profile_index],
				to_ring[profile_index],
				color
			)
			added_vertices += _append_triangle(
				surface_tool,
				from_ring[profile_index],
				from_ring[next_profile_index],
				to_ring[next_profile_index],
				color
			)
	added_vertices += _append_profile_sweep_caps(
		surface_tool,
		rings[0],
		profile_polygon,
		color,
		false,
		cap_indices
	)
	added_vertices += _append_profile_sweep_caps(
		surface_tool,
		rings[rings.size() - 1],
		profile_polygon,
		color,
		true,
		cap_indices
	)
	return added_vertices

func _build_profile_sweep_ring(
	body: Resource,
	profile_polygon: PackedVector2Array,
	point_index: int,
	path_tangent: Vector3
) -> PackedVector3Array:
	var path_points: PackedVector3Array = body.get("path_points")
	var path_surface_normals: PackedVector3Array = body.get(
		"path_surface_normals"
	)
	var surface_normal := Vector3.FORWARD
	if point_index >= 0 and point_index < path_surface_normals.size():
		surface_normal = path_surface_normals[point_index]
	var frame: Dictionary
	if _uses_explicit_surface_profile_frame(body):
		var path_contact_directions: PackedVector3Array = body.get(
			"path_contact_directions"
		)
		var explicit_contact_direction := Vector3.ZERO
		if point_index >= 0 and point_index < path_contact_directions.size():
			explicit_contact_direction = path_contact_directions[point_index]
		frame = (
			ForgeV2ProfileShapeLibraryScript.resolve_explicit_surface_profile_path_frame(
				path_tangent,
				surface_normal,
				body.get("profile_contact_direction_2d") as Vector2,
				body.get("profile_contact_point_relative_2d_meters") as Vector2,
				explicit_contact_direction,
				float(body.get("profile_rotation_bias_degrees"))
			)
		)
	else:
		frame = ForgeV2ProfileShapeLibraryScript.resolve_profile_path_frame(
			path_tangent,
			surface_normal,
			body.get("profile_contact_direction_2d") as Vector2,
			float(body.get("profile_rotation_bias_degrees"))
		)
	var axis_x: Vector3 = frame.get("axis_x", Vector3.RIGHT) as Vector3
	var axis_y: Vector3 = frame.get("axis_y", Vector3.UP) as Vector3
	var center_point: Vector3 = path_points[point_index]
	var ring := PackedVector3Array()
	for profile_point: Vector2 in profile_polygon:
		ring.append(
			center_point
			+ axis_x * profile_point.x
			+ axis_y * profile_point.y
		)
	return ring

func _uses_explicit_surface_profile_frame(body: Resource) -> bool:
	if body == null:
		return false
	if (
		StringName(body.get("shape_kind"))
		!= ForgeV2MaterialBodyScript.SHAPE_KIND_PROFILE_PATH
		or int(body.get("profile_runtime_schema_version")) <= 0
	):
		return false
	var body_kind := StringName(body.get("body_kind"))
	if (
		body_kind != ForgeV2MaterialBodyScript.BODY_KIND_VOLUME_STROKE
		and body_kind != ForgeV2MaterialBodyScript.BODY_KIND_DETAILING_BRUSH
	):
		return false
	var path_points: PackedVector3Array = body.get("path_points")
	var path_contact_directions: PackedVector3Array = body.get(
		"path_contact_directions"
	)
	return (
		not path_points.is_empty()
		and path_contact_directions.size() >= path_points.size()
	)

func _resolve_linear_path_point_tangent(
	path_points: PackedVector3Array,
	point_index: int
) -> Vector3:
	return (
		ForgeV2ProfileShapeLibraryScript.resolve_linear_path_point_tangent(
			path_points,
			point_index
		)
	)

func _append_profile_sweep_caps(
	surface_tool: SurfaceTool,
	ring: PackedVector3Array,
	profile_polygon: PackedVector2Array,
	color: Color,
	forward_facing: bool,
	triangulated_indices: PackedInt32Array
) -> int:
	if ring.size() != profile_polygon.size() or ring.size() < 3:
		return 0
	if triangulated_indices.size() < 3:
		return 0
	var added_vertices := 0
	for triangle_offset in range(0, triangulated_indices.size(), 3):
		var index_a := int(triangulated_indices[triangle_offset])
		var index_b := int(triangulated_indices[triangle_offset + 1])
		var index_c := int(triangulated_indices[triangle_offset + 2])
		if forward_facing:
			added_vertices += _append_triangle(
				surface_tool,
				ring[index_a],
				ring[index_b],
				ring[index_c],
				color
			)
		else:
			added_vertices += _append_triangle(
				surface_tool,
				ring[index_c],
				ring[index_b],
				ring[index_a],
				color
			)
	return added_vertices

func _build_preview_mesh(volume_strokes: Array) -> ArrayMesh:
	if volume_strokes.is_empty():
		return ArrayMesh.new()
	var surface_tool := SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var added_vertices := 0
	for stroke: Resource in volume_strokes:
		if stroke == null:
			continue
		if stroke.get("layer_active") is bool and not bool(stroke.get("layer_active")):
			continue
		added_vertices += _append_stroke_preview(surface_tool, stroke)
	if added_vertices <= 0:
		return ArrayMesh.new()
	surface_tool.index()
	surface_tool.generate_normals()
	return surface_tool.commit()

func _build_spline_preview_mesh(
	spline_points: PackedVector3Array,
	selected_point_index: int,
	spline_finished: bool,
	draw_line: bool = true,
	draw_points: bool = true,
	invalid_line: bool = false
) -> ArrayMesh:
	if spline_points.is_empty():
		return ArrayMesh.new()
	var surface_tool := SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var added_vertices := 0
	var line_color := (
		DETAILING_INVALID_LINE_COLOR
		if invalid_line
		else Color(0.18, 0.52, 1.0, 0.92)
		if not spline_finished
		else Color(0.42, 0.92, 0.78, 0.94)
	)
	var point_color := Color(0.76, 0.9, 1.0, 1.0)
	var selected_color := Color(1.0, 0.88, 0.22, 1.0)
	if draw_line and spline_points.size() >= 2:
		var spline_curve: Curve3D = _build_spline_curve(spline_points, SPLINE_PREVIEW_BAKE_INTERVAL_METERS)
		var baked_points: PackedVector3Array = spline_curve.get_baked_points()
		if baked_points.size() < 2:
			baked_points = _deduplicate_spline_points(spline_points)
		for point_index in range(baked_points.size() - 1):
			var from_point: Vector3 = baked_points[point_index]
			var to_point: Vector3 = baked_points[point_index + 1]
			if from_point.distance_squared_to(to_point) <= 0.000001:
				continue
			added_vertices += _append_tube_segment(
				surface_tool,
				from_point,
				to_point,
				SPLINE_PREVIEW_RADIUS_METERS,
				line_color
			)
	if draw_points:
		for point_index in range(spline_points.size()):
			var point_radius := SPLINE_SELECTED_POINT_RADIUS_METERS if point_index == selected_point_index else SPLINE_POINT_RADIUS_METERS
			var color := selected_color if point_index == selected_point_index else point_color
			added_vertices += _append_sphere(surface_tool, spline_points[point_index], point_radius, color)
	if added_vertices <= 0:
		return ArrayMesh.new()
	surface_tool.index()
	surface_tool.generate_normals()
	return surface_tool.commit()

func _build_detailing_spline_preview_meshes(
	control_points: PackedVector3Array,
	resolved_points: PackedVector3Array,
	span_offsets: PackedInt32Array,
	span_validity: Array,
	selected_point_index: int,
	spline_finished: bool,
	solution_valid: bool
) -> Dictionary:
	var normal_surface_tool := SurfaceTool.new()
	normal_surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var invalid_surface_tool := SurfaceTool.new()
	invalid_surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var normal_vertex_count := 0
	var invalid_vertex_count := 0
	var line_color := (
		Color(0.18, 0.52, 1.0, 0.92)
		if not spline_finished
		else Color(0.42, 0.92, 0.78, 0.94)
	)
	var partition_is_usable := _detail_span_partition_is_usable(
		resolved_points,
		span_offsets,
		span_validity
	)
	if resolved_points.size() >= 2:
		if partition_is_usable:
			for span_index in range(span_validity.size()):
				var span_surface_tool := (
					normal_surface_tool
					if bool(span_validity[span_index])
					else invalid_surface_tool
				)
				var span_color := (
					line_color
					if bool(span_validity[span_index])
					else DETAILING_INVALID_LINE_COLOR
				)
				var span_vertex_count := _append_detailing_path_span(
					span_surface_tool,
					resolved_points,
					int(span_offsets[span_index]),
					int(span_offsets[span_index + 1]),
					span_color
				)
				if bool(span_validity[span_index]):
					normal_vertex_count += span_vertex_count
				else:
					invalid_vertex_count += span_vertex_count
		else:
			invalid_vertex_count += _append_detailing_path_span(
				invalid_surface_tool,
				resolved_points,
				0,
				resolved_points.size() - 1,
				DETAILING_INVALID_LINE_COLOR
			)
	var point_color := Color(0.76, 0.9, 1.0, 1.0)
	var selected_color := Color(1.0, 0.88, 0.22, 1.0)
	for point_index in range(control_points.size()):
		var point_radius := (
			SPLINE_SELECTED_POINT_RADIUS_METERS
			if point_index == selected_point_index
			else SPLINE_POINT_RADIUS_METERS
		)
		var point_marker_color := (
			selected_color
			if point_index == selected_point_index
			else point_color
		)
		normal_vertex_count += _append_sphere(
			normal_surface_tool,
			control_points[point_index],
			point_radius,
			point_marker_color
		)
	return {
		"normal_mesh": _commit_preview_surface(
			normal_surface_tool,
			normal_vertex_count
		),
		"invalid_mesh": _commit_preview_surface(
			invalid_surface_tool,
			invalid_vertex_count
		),
		"control_points": control_points,
		"resolved_points": resolved_points,
		"span_offsets": span_offsets,
		"span_validity": span_validity.duplicate(),
		"solution_valid": solution_valid,
		"partition_is_usable": partition_is_usable,
		"normal_vertex_count": normal_vertex_count,
		"invalid_vertex_count": invalid_vertex_count,
	}

func _append_detailing_path_span(
	surface_tool: SurfaceTool,
	resolved_points: PackedVector3Array,
	start_offset: int,
	end_offset: int,
	color: Color
) -> int:
	if surface_tool == null or resolved_points.size() < 2:
		return 0
	var resolved_start := clampi(
		start_offset,
		0,
		resolved_points.size() - 1
	)
	var resolved_end := clampi(
		end_offset,
		resolved_start,
		resolved_points.size() - 1
	)
	var added_vertices := 0
	for point_index in range(resolved_start, resolved_end):
		var from_point: Vector3 = resolved_points[point_index]
		var to_point: Vector3 = resolved_points[point_index + 1]
		if from_point.distance_squared_to(to_point) <= 0.000001:
			continue
		added_vertices += _append_tube_segment(
			surface_tool,
			from_point,
			to_point,
			SPLINE_PREVIEW_RADIUS_METERS,
			color
		)
	return added_vertices

func _detail_span_partition_is_usable(
	resolved_points: PackedVector3Array,
	span_offsets: PackedInt32Array,
	span_validity: Array
) -> bool:
	if resolved_points.is_empty():
		return span_offsets.is_empty() and span_validity.is_empty()
	if (
		span_offsets.size() < 1
		or span_offsets.size() != span_validity.size() + 1
		or int(span_offsets[0]) != 0
		or int(span_offsets[span_offsets.size() - 1])
		!= resolved_points.size() - 1
	):
		return false
	var previous_offset := -1
	for offset: int in span_offsets:
		if (
			offset < previous_offset
			or offset < 0
			or offset >= resolved_points.size()
		):
			return false
		previous_offset = offset
	return true

func _commit_preview_surface(
	surface_tool: SurfaceTool,
	vertex_count: int
) -> ArrayMesh:
	if surface_tool == null or vertex_count <= 0:
		return ArrayMesh.new()
	surface_tool.index()
	surface_tool.generate_normals()
	return surface_tool.commit()

func _build_spline_csg_curve(spline_points: PackedVector3Array, path_interval_meters: float) -> Curve3D:
	return _build_spline_curve(spline_points, maxf(path_interval_meters, 0.001))

func _build_linear_csg_curve(path_points: PackedVector3Array, path_interval_meters: float) -> Curve3D:
	var curve := Curve3D.new()
	curve.bake_interval = maxf(path_interval_meters, 0.001)
	var control_points := _deduplicate_spline_points(path_points)
	for point: Vector3 in control_points:
		curve.add_point(point)
	return curve

func _apply_profile_curve_orientation(
	curve: Curve3D,
	source_points: PackedVector3Array,
	source_surface_normals: PackedVector3Array,
	contact_direction_2d: Vector2,
	rotation_bias_degrees: float
) -> void:
	if curve == null or curve.point_count < 2:
		return
	var previous_tilt := 0.0
	var has_previous_tilt := false
	var has_aligned_point_normals := (
		curve.point_count == source_points.size()
		and source_surface_normals.size() >= source_points.size()
	)
	for point_index in range(curve.point_count):
		var tangent := _resolve_curve_point_tangent(curve, point_index)
		var point_position := curve.get_point_position(point_index)
		var use_aligned_normal := (
			has_aligned_point_normals
			and point_position.is_equal_approx(source_points[point_index])
		)
		var surface_normal := Vector3.FORWARD
		if use_aligned_normal:
			surface_normal = (
				ForgeV2ProfileShapeLibraryScript.interpolate_path_surface_normal(
					source_surface_normals,
					point_index,
					0.0
				)
			)
		else:
			surface_normal = (
				ForgeV2ProfileShapeLibraryScript.resolve_path_surface_normal(
					point_position,
					source_points,
					source_surface_normals
				)
			)
		var frame := ForgeV2ProfileShapeLibraryScript.resolve_profile_path_frame(
			tangent,
			surface_normal,
			contact_direction_2d,
			rotation_bias_degrees
		)
		var tilt := float(frame.get("tilt_radians", 0.0))
		if has_previous_tilt:
			while tilt - previous_tilt > PI:
				tilt -= TAU
			while tilt - previous_tilt < -PI:
				tilt += TAU
		curve.set_point_tilt(point_index, tilt)
		previous_tilt = tilt
		has_previous_tilt = true

func _resolve_curve_point_tangent(
	curve: Curve3D,
	point_index: int
) -> Vector3:
	if curve == null or curve.point_count < 2:
		return Vector3.RIGHT
	var current_position := curve.get_point_position(point_index)
	var tangent := Vector3.ZERO
	if point_index > 0:
		tangent += current_position - curve.get_point_position(point_index - 1)
	if point_index < curve.point_count - 1:
		tangent += curve.get_point_position(point_index + 1) - current_position
	if tangent.length_squared() <= 0.000001:
		return Vector3.RIGHT
	return tangent.normalized()

func _resolve_spline_csg_path_interval(radius_meters: float) -> float:
	if active_stage_controller != null and active_stage_controller.has_method("get_workspace_contract"):
		var contract: Object = active_stage_controller.call("get_workspace_contract") as Object
		if contract != null and contract.has_method("resolve_stroke_sample_spacing"):
			return maxf(float(contract.call("resolve_stroke_sample_spacing", radius_meters)), 0.001)
	return maxf(
		maxf(radius_meters, 0.001) * SPLINE_CSG_PATH_INTERVAL_RADIUS_RATIO_FALLBACK,
		SPLINE_CSG_PATH_INTERVAL_MIN_METERS_FALLBACK
	)

func _build_spline_curve(spline_points: PackedVector3Array, bake_interval: float) -> Curve3D:
	return ForgeV2SplinePathSamplerScript.build_auto_curve(
		spline_points,
		maxf(bake_interval, 0.001),
		true
	)

func _build_circle_profile_polygon(radius_meters: float, side_count: int) -> PackedVector2Array:
	var polygon := PackedVector2Array()
	var resolved_side_count := maxi(side_count, 8)
	var resolved_radius := maxf(radius_meters, 0.001)
	for side_index in range(resolved_side_count):
		var angle := TAU * float(side_index) / float(resolved_side_count)
		polygon.append(Vector2(cos(angle), sin(angle)) * resolved_radius)
	return polygon

func _is_profile_shape_kind(shape_kind: StringName) -> bool:
	return (
		shape_kind == ForgeV2MaterialBodyScript.SHAPE_KIND_PROFILE_PATH
		or shape_kind == ForgeV2MaterialBodyScript.SHAPE_KIND_SPLINE_PROFILE_PATH
	)

func _resolve_body_profile_polygon(body: Resource) -> PackedVector2Array:
	if body == null:
		return PackedVector2Array()
	var profile_polygon: PackedVector2Array = body.get("profile_polygon_2d_meters")
	if profile_polygon.size() >= 3:
		return profile_polygon
	var radius_meters: float = maxf(float(body.get("radius_meters")), 0.001)
	var profile_id: StringName = StringName(body.get("profile_id"))
	if profile_id != StringName():
		return ForgeV2ProfileShapeLibraryScript.resolve_profile_polygon(profile_id, radius_meters)
	return ForgeV2ProfileShapeLibraryScript.build_circle_polygon(radius_meters)

func _deduplicate_spline_points(points: PackedVector3Array) -> PackedVector3Array:
	return ForgeV2SplinePathSamplerScript.deduplicate_points(points)

func _append_stroke_preview(surface_tool: SurfaceTool, stroke: Resource) -> int:
	var path_points: PackedVector3Array = stroke.get("path_points")
	if path_points.is_empty():
		return 0
	var raw_radius_meters := float(stroke.get("radius_meters"))
	var radius_meters := raw_radius_meters if raw_radius_meters > 0.0 else DEFAULT_PREVIEW_RADIUS_METERS
	var color: Color = _resolve_stroke_color(stroke)
	var added_vertices := 0
	if path_points.size() == 1:
		return _append_sphere(surface_tool, path_points[0], radius_meters, color)
	for point_index in range(path_points.size() - 1):
		var from_point: Vector3 = path_points[point_index]
		var to_point: Vector3 = path_points[point_index + 1]
		if from_point.distance_squared_to(to_point) <= 0.000001:
			continue
		added_vertices += _append_tube_segment(surface_tool, from_point, to_point, radius_meters, color)
	for point: Vector3 in path_points:
		added_vertices += _append_sphere(surface_tool, point, radius_meters, color)
	return added_vertices

func _append_tube_segment(
	surface_tool: SurfaceTool,
	from_point: Vector3,
	to_point: Vector3,
	radius_meters: float,
	color: Color
) -> int:
	var tangent: Vector3 = (to_point - from_point).normalized()
	if tangent == Vector3.ZERO:
		return 0
	var normal: Vector3 = _resolve_perpendicular_normal(tangent)
	var binormal: Vector3 = tangent.cross(normal).normalized()
	var added_vertices := 0
	for side_index in range(PREVIEW_TUBE_SIDES):
		var next_side_index := (side_index + 1) % PREVIEW_TUBE_SIDES
		var angle_a := TAU * float(side_index) / float(PREVIEW_TUBE_SIDES)
		var angle_b := TAU * float(next_side_index) / float(PREVIEW_TUBE_SIDES)
		var offset_a: Vector3 = (normal * cos(angle_a) + binormal * sin(angle_a)) * radius_meters
		var offset_b: Vector3 = (normal * cos(angle_b) + binormal * sin(angle_b)) * radius_meters
		var from_a: Vector3 = from_point + offset_a
		var from_b: Vector3 = from_point + offset_b
		var to_a: Vector3 = to_point + offset_a
		var to_b: Vector3 = to_point + offset_b
		added_vertices += _append_triangle(surface_tool, from_a, to_a, to_b, color)
		added_vertices += _append_triangle(surface_tool, from_a, to_b, from_b, color)
	return added_vertices

func _append_sphere(
	surface_tool: SurfaceTool,
	center_point: Vector3,
	radius_meters: float,
	color: Color
) -> int:
	var added_vertices := 0
	for ring_index in range(PREVIEW_SPHERE_RINGS):
		var theta_a := PI * float(ring_index) / float(PREVIEW_SPHERE_RINGS)
		var theta_b := PI * float(ring_index + 1) / float(PREVIEW_SPHERE_RINGS)
		for side_index in range(PREVIEW_SPHERE_SIDES):
			var next_side_index := (side_index + 1) % PREVIEW_SPHERE_SIDES
			var phi_a := TAU * float(side_index) / float(PREVIEW_SPHERE_SIDES)
			var phi_b := TAU * float(next_side_index) / float(PREVIEW_SPHERE_SIDES)
			var point_aa: Vector3 = center_point + _sphere_offset(theta_a, phi_a, radius_meters)
			var point_ab: Vector3 = center_point + _sphere_offset(theta_a, phi_b, radius_meters)
			var point_ba: Vector3 = center_point + _sphere_offset(theta_b, phi_a, radius_meters)
			var point_bb: Vector3 = center_point + _sphere_offset(theta_b, phi_b, radius_meters)
			added_vertices += _append_triangle(surface_tool, point_aa, point_ba, point_bb, color)
			added_vertices += _append_triangle(surface_tool, point_aa, point_bb, point_ab, color)
	return added_vertices

func _append_triangle(
	surface_tool: SurfaceTool,
	point_a: Vector3,
	point_b: Vector3,
	point_c: Vector3,
	color: Color
) -> int:
	surface_tool.set_color(color)
	surface_tool.add_vertex(point_a)
	surface_tool.set_color(color)
	surface_tool.add_vertex(point_b)
	surface_tool.set_color(color)
	surface_tool.add_vertex(point_c)
	return 3

func _sphere_offset(theta: float, phi: float, radius_meters: float) -> Vector3:
	var sin_theta := sin(theta)
	return Vector3(
		sin_theta * cos(phi),
		cos(theta),
		sin_theta * sin(phi)
	) * radius_meters

func _resolve_perpendicular_normal(tangent: Vector3) -> Vector3:
	var reference := Vector3.UP
	if absf(tangent.dot(reference)) > 0.92:
		reference = Vector3.RIGHT
	var normal: Vector3 = reference.cross(tangent).normalized()
	if normal == Vector3.ZERO:
		return Vector3.FORWARD
	return normal

func _resolve_stroke_color(stroke: Resource) -> Color:
	if stroke.get("operation_mode") == ForgeV2VolumeStrokeScript.OPERATION_REMOVE_MATERIAL:
		return Color(0.95, 0.22, 0.18, 0.74)
	var material_variant_id: StringName = stroke.get("material_variant_id")
	if material_variant_id == &"mat_iron_gray" or material_variant_id == &"iron_gray":
		return Color(0.62, 0.66, 0.67, 1.0)
	return Color(0.35, 0.78, 0.7, 1.0)

func _resolve_active_material_body_preview_color(body: Resource) -> Color:
	if _is_remove_material_body(body):
		return Color(1.0, 0.08, 0.04, 0.88)
	var material_color := _resolve_material_color(
		StringName(body.get("material_variant_id"))
	)
	material_color.a = 0.88
	return material_color

func _resolve_material_color(material_variant_id: StringName) -> Color:
	if resolved_material_color_cache.has(material_variant_id):
		return resolved_material_color_cache[material_variant_id] as Color
	for entry: Dictionary in ForgeV2MaterialPaletteScript.build_palette_entries():
		if StringName(entry.get("id", StringName())) == material_variant_id:
			var resolved_color := entry.get(
				"albedo_color",
				Color(0.8, 0.82, 0.84, 1.0)
			) as Color
			resolved_material_color_cache[material_variant_id] = resolved_color
			return resolved_color
	var fallback_color := Color(0.8, 0.82, 0.84, 1.0)
	resolved_material_color_cache[material_variant_id] = fallback_color
	return fallback_color

func _build_preview_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = 0.64
	material.metallic = 0.08
	return material

func _build_active_material_body_preview_material(
	is_subtractive: bool
) -> StandardMaterial3D:
	if (
		is_subtractive
		and active_material_body_remove_preview_material != null
	):
		return active_material_body_remove_preview_material
	if (
		not is_subtractive
		and active_material_body_add_preview_material != null
	):
		return active_material_body_add_preview_material
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = 0.58
	material.metallic = 0.0 if is_subtractive else 0.08
	if is_subtractive:
		material.emission_enabled = true
		material.emission = Color(0.78, 0.015, 0.005, 1.0)
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		active_material_body_remove_preview_material = material
	else:
		active_material_body_add_preview_material = material
	return material

func _build_placement_cursor_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.35, 0.86, 0.78, 0.46)
	material.emission_enabled = true
	material.emission = Color(0.16, 0.62, 0.58, 1.0)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material

func _build_spline_preview_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.emission_enabled = true
	material.emission = Color(0.12, 0.36, 0.9, 1.0)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = 0.52
	return material

func _build_spline_invalid_preview_material() -> StandardMaterial3D:
	if spline_invalid_preview_material != null:
		return spline_invalid_preview_material
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.albedo_color = DETAILING_INVALID_LINE_COLOR
	material.emission_enabled = true
	material.emission = Color(0.82, 0.005, 0.002, 1.0)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = 0.46
	spline_invalid_preview_material = material
	return material

func _build_csg_body_material(material_variant_id: StringName, is_subtraction: bool) -> StandardMaterial3D:
	var base_color := Color(0.95, 0.22, 0.18, 0.78) if is_subtraction else _resolve_material_color(material_variant_id)
	if not is_subtraction:
		base_color.a = 1.0
	var material := StandardMaterial3D.new()
	material.albedo_color = base_color
	material.emission_enabled = true
	material.emission = base_color.darkened(0.35)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if is_subtraction else BaseMaterial3D.TRANSPARENCY_DISABLED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = 0.54
	material.metallic = 0.12 if not is_subtraction else 0.0
	return material

func _build_spline_csg_material(material_variant_id: StringName) -> StandardMaterial3D:
	var base_color := _resolve_material_color(material_variant_id)
	base_color.a = 0.72
	var material := StandardMaterial3D.new()
	material.albedo_color = base_color
	material.emission_enabled = true
	material.emission = base_color.darkened(0.35)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = 0.54
	material.metallic = 0.12
	return material
