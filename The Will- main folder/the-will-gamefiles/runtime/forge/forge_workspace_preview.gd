extends Node3D
class_name ForgeWorkspacePreview

const PLANE_XY: StringName = &"xy"
const PLANE_ZX: StringName = &"zx"
const PLANE_ZY: StringName = &"zy"

const DEFAULT_FORGE_RULES_RESOURCE: ForgeRulesDef = preload("res://core/defs/forge/forge_rules_default.tres")
const DEFAULT_FORGE_VIEW_TUNING_RESOURCE: ForgeViewTuningDef = preload("res://core/defs/forge/forge_view_tuning_default.tres")
const ForgeWorkspaceGeometryPresenterScript = preload("res://runtime/forge/forge_workspace_geometry_presenter.gd")
const ForgeStage2PreviewPresenterScript = preload("res://runtime/forge/forge_stage2_preview_presenter.gd")
const CraftedItemWIPScript = preload("res://core/models/crafted_item_wip.gd")
const MaterialRuntimeResolverScript = preload("res://core/resolvers/material_runtime_resolver.gd")

var grid_size: Vector3i = DEFAULT_FORGE_RULES_RESOURCE.grid_size
var cell_world_size: float = DEFAULT_FORGE_RULES_RESOURCE.cell_world_size_meters
var active_plane: StringName = PLANE_XY
var active_layer: int = DEFAULT_FORGE_RULES_RESOURCE.grid_size.z >> 1
var material_lookup: Dictionary = {}
var forge_view_tuning: ForgeViewTuningDef = DEFAULT_FORGE_VIEW_TUNING_RESOURCE
var geometry_presenter = ForgeWorkspaceGeometryPresenterScript.new()
var stage2_preview_presenter = ForgeStage2PreviewPresenterScript.new()
var material_runtime_resolver = MaterialRuntimeResolverScript.new()

var camera_pivot: Node3D
var camera_pitch: Node3D
var camera: Camera3D
var light: DirectionalLight3D
var occupied_cells_instance: MultiMeshInstance3D
var structural_shape_preview_instance: MultiMeshInstance3D
var active_plane_instance: MeshInstance3D
var grid_bounds_instance: MeshInstance3D
var builder_marker_root: Node3D
var generated_string_segment_a: MeshInstance3D
var generated_string_segment_b: MeshInstance3D
var generated_string_draw_segment_a: MeshInstance3D
var generated_string_draw_segment_b: MeshInstance3D
var generated_string_draw_pull_point: MeshInstance3D
var stage2_shell_instance: MeshInstance3D
var stage2_brush_preview_instance: MeshInstance3D
var stage2_hover_face_instance: MeshInstance3D
var stage2_selected_faces_instance: MeshInstance3D
var view_initialized: bool = false
var stage2_shell_preview_visible: bool = false
var stage2_brush_preview_hit_local = null
var stage2_brush_preview_radius_meters: float = 0.0
var stage2_brush_preview_blocked: bool = false
var stage2_hover_patch_ids: PackedStringArray = PackedStringArray()
var stage2_selected_patch_ids: PackedStringArray = PackedStringArray()
var structural_shape_preview_cells: Array[Vector3i] = []
var structural_shape_preview_material_id: StringName = StringName()
var structural_shape_preview_remove_mode: bool = false
var structural_shape_preview_multimesh: MultiMesh

func _ready() -> void:
	_build_scene()
	_apply_view_defaults()
	geometry_presenter.refresh_visuals(occupied_cells_instance, active_plane_instance, grid_bounds_instance)
	_sync_structural_shape_preview_mesh()

func configure(new_grid_size: Vector3i, new_cell_world_size: float, preserve_view: bool = true) -> void:
	var geometry_changed: bool = grid_size != new_grid_size or not is_equal_approx(cell_world_size, new_cell_world_size)
	grid_size = new_grid_size
	cell_world_size = new_cell_world_size
	geometry_presenter.configure(grid_size, cell_world_size)
	geometry_presenter.refresh_visuals(occupied_cells_instance, active_plane_instance, grid_bounds_instance)
	_sync_structural_shape_preview_mesh()
	if not preserve_view or geometry_changed or not view_initialized:
		reset_view()

func set_active_slice(plane_id: StringName, layer_index: int) -> void:
	active_plane = plane_id
	active_layer = layer_index
	geometry_presenter.set_active_slice(active_plane, active_layer)
	geometry_presenter.refresh_visuals(occupied_cells_instance, active_plane_instance, grid_bounds_instance)
	_sync_structural_shape_preview_mesh()

func set_material_lookup(value: Dictionary) -> void:
	material_lookup = value
	geometry_presenter.set_material_lookup(material_lookup)
	_sync_structural_shape_preview_mesh()

func set_view_tuning(value: ForgeViewTuningDef) -> void:
	forge_view_tuning = value if value != null else DEFAULT_FORGE_VIEW_TUNING_RESOURCE
	geometry_presenter.set_view_tuning(forge_view_tuning)
	if is_inside_tree():
		_apply_view_tuning()

func sync_from_wip(
	wip: CraftedItemWIP,
	forge_service: ForgeService = null,
	test_print_mesh_builder: TestPrintMeshBuilder = null,
	show_stage2_shell_preview: bool = false
) -> void:
	geometry_presenter.sync_from_wip(wip, occupied_cells_instance)
	_sync_builder_markers_from_wip(wip)
	_sync_generated_string_from_wip(wip, forge_service)
	stage2_shell_preview_visible = show_stage2_shell_preview
	stage2_preview_presenter.sync_stage2_shell_preview(
		stage2_shell_instance,
		wip.stage2_item_state if wip != null else null,
		test_print_mesh_builder,
		grid_size,
		cell_world_size,
		_get_view_tuning(),
		stage2_shell_preview_visible
	)
	stage2_preview_presenter.sync_stage2_brush_preview(
		stage2_brush_preview_instance,
		stage2_shell_preview_visible,
		stage2_brush_preview_hit_local,
		stage2_brush_preview_radius_meters,
		stage2_brush_preview_blocked,
		grid_size,
		cell_world_size,
		_get_view_tuning()
	)
	stage2_preview_presenter.sync_stage2_selection_preview(
		stage2_hover_face_instance,
		stage2_selected_faces_instance,
		wip.stage2_item_state if wip != null else null,
		stage2_hover_patch_ids,
		stage2_selected_patch_ids,
		test_print_mesh_builder,
		grid_size,
		cell_world_size,
		_get_view_tuning(),
		stage2_shell_preview_visible
	)
	_sync_structural_shape_preview_mesh()
	_apply_stage2_display_priority()

func orbit_by(delta: Vector2) -> void:
	if camera_pivot == null or camera_pitch == null:
		return
	var tuning: ForgeViewTuningDef = _get_view_tuning()
	camera_pivot.rotation.y -= delta.x * tuning.workspace_orbit_sensitivity
	camera_pitch.rotation.x = clampf(camera_pitch.rotation.x - delta.y * tuning.workspace_orbit_sensitivity, deg_to_rad(tuning.workspace_pitch_min_degrees), deg_to_rad(tuning.workspace_pitch_max_degrees))
	_sync_light_anchor()
	view_initialized = true

func zoom_by(amount: float) -> void:
	if camera == null:
		return
	var tuning: ForgeViewTuningDef = _get_view_tuning()
	var new_distance: float = clampf(camera.position.z + amount, tuning.workspace_zoom_min_distance, tuning.workspace_zoom_max_distance)
	camera.position.z = new_distance
	view_initialized = true

func pan_by(delta: Vector2) -> void:
	if camera_pivot == null or camera == null:
		return
	var tuning: ForgeViewTuningDef = _get_view_tuning()
	var camera_basis: Basis = camera.global_transform.basis
	var reference_distance: float = maxf(absf(camera.position.z), tuning.workspace_pan_min_distance)
	var pan_offset: Vector3 = (
		-camera_basis.x.normalized() * delta.x +
		camera_basis.y.normalized() * delta.y
	) * reference_distance * tuning.workspace_pan_sensitivity
	camera_pivot.global_position += pan_offset
	view_initialized = true

func fit_view() -> void:
	if camera == null or camera_pivot == null:
		return
	var width_meters: float = float(grid_size.x) * cell_world_size
	var height_meters: float = float(grid_size.y) * cell_world_size
	var depth_meters: float = float(grid_size.z) * cell_world_size
	var largest_dimension: float = maxf(width_meters, maxf(height_meters, depth_meters))
	var tuning: ForgeViewTuningDef = _get_view_tuning()
	camera_pivot.position = Vector3.ZERO
	camera.position = Vector3(0.0, 0.0, clampf(largest_dimension * tuning.workspace_fit_distance_multiplier, tuning.workspace_fit_min_distance, tuning.workspace_fit_max_distance))
	view_initialized = true

func reset_view() -> void:
	if camera_pivot == null or camera_pitch == null:
		return
	_apply_view_defaults()
	view_initialized = true

func screen_to_grid(screen_position: Vector2) -> Variant:
	return geometry_presenter.screen_to_grid(camera, screen_position)

func resolve_stage2_brush_hit(screen_position: Vector2, wip: CraftedItemWIP) -> Dictionary:
	return stage2_preview_presenter.resolve_stage2_brush_hit(
		camera,
		screen_position,
		wip.stage2_item_state if wip != null else null,
		grid_size,
		cell_world_size,
		self
	)

func set_stage2_brush_preview_hit(
	hit_point_local: Variant,
	brush_radius_meters: float,
	blocked: bool = false
) -> void:
	stage2_brush_preview_hit_local = hit_point_local
	stage2_brush_preview_radius_meters = brush_radius_meters
	stage2_brush_preview_blocked = blocked
	stage2_preview_presenter.sync_stage2_brush_preview(
		stage2_brush_preview_instance,
		stage2_shell_preview_visible,
		stage2_brush_preview_hit_local,
		stage2_brush_preview_radius_meters,
		stage2_brush_preview_blocked,
		grid_size,
		cell_world_size,
		_get_view_tuning()
	)

func clear_stage2_brush_preview() -> void:
	stage2_brush_preview_hit_local = null
	stage2_brush_preview_blocked = false
	stage2_preview_presenter.sync_stage2_brush_preview(
		stage2_brush_preview_instance,
		false,
		null,
		stage2_brush_preview_radius_meters,
		false,
		grid_size,
		cell_world_size,
		_get_view_tuning()
	)

func set_stage2_selection_preview_state(
	stage2_item_state: Resource,
	hovered_patch_ids: PackedStringArray,
	selected_patch_ids: PackedStringArray,
	test_print_mesh_builder: TestPrintMeshBuilder
) -> void:
	stage2_hover_patch_ids = PackedStringArray(hovered_patch_ids)
	stage2_selected_patch_ids = PackedStringArray(selected_patch_ids)
	stage2_preview_presenter.sync_stage2_selection_preview(
		stage2_hover_face_instance,
		stage2_selected_faces_instance,
		stage2_item_state,
		stage2_hover_patch_ids,
		stage2_selected_patch_ids,
		test_print_mesh_builder,
		grid_size,
		cell_world_size,
		_get_view_tuning(),
		stage2_shell_preview_visible
	)

func clear_stage2_selection_preview() -> void:
	stage2_hover_patch_ids = PackedStringArray()
	stage2_selected_patch_ids = PackedStringArray()
	stage2_preview_presenter.sync_stage2_selection_preview(
		stage2_hover_face_instance,
		stage2_selected_faces_instance,
		null,
		stage2_hover_patch_ids,
		stage2_selected_patch_ids,
		null,
		grid_size,
		cell_world_size,
		_get_view_tuning(),
		false
	)

func set_structural_shape_preview_state(
	grid_positions: Array[Vector3i],
	material_id: StringName,
	remove_mode: bool
) -> void:
	structural_shape_preview_cells = grid_positions.duplicate()
	structural_shape_preview_material_id = material_id
	structural_shape_preview_remove_mode = remove_mode
	_sync_structural_shape_preview_mesh()

func clear_structural_shape_preview() -> void:
	structural_shape_preview_cells.clear()
	structural_shape_preview_material_id = StringName()
	structural_shape_preview_remove_mode = false
	_sync_structural_shape_preview_mesh()

func get_axis_indicator_state() -> Dictionary:
	if camera == null:
		return {
			"screen_vectors": {},
			"local_vectors": {},
		}
	var world_to_camera: Basis = camera.global_transform.basis.orthonormalized().inverse()
	var local_vectors: Dictionary = {
		&"x": world_to_camera * Vector3(1.0, 0.0, 0.0),
		&"y": world_to_camera * Vector3(0.0, 1.0, 0.0),
		&"z": world_to_camera * Vector3(0.0, 0.0, 1.0),
	}
	var screen_vectors: Dictionary = {}
	for axis_id: StringName in local_vectors.keys():
		var local_vector: Vector3 = local_vectors[axis_id]
		screen_vectors[axis_id] = Vector2(local_vector.x, -local_vector.y)
	return {
		"screen_vectors": screen_vectors,
		"local_vectors": local_vectors,
	}

func _build_scene() -> void:
	camera_pivot = Node3D.new()
	camera_pivot.name = "CameraPivot"
	add_child(camera_pivot)

	camera_pitch = Node3D.new()
	camera_pitch.name = "CameraPitch"
	camera_pivot.add_child(camera_pitch)

	camera = Camera3D.new()
	camera.name = "Camera3D"
	camera_pitch.add_child(camera)
	camera.current = true

	light = DirectionalLight3D.new()
	light.name = "DirectionalLight3D"
	camera.add_child(light)

	grid_bounds_instance = MeshInstance3D.new()
	grid_bounds_instance.name = "GridBounds"
	add_child(grid_bounds_instance)

	active_plane_instance = MeshInstance3D.new()
	active_plane_instance.name = "ActivePlane"
	add_child(active_plane_instance)

	occupied_cells_instance = MultiMeshInstance3D.new()
	occupied_cells_instance.name = "OccupiedCells"
	add_child(occupied_cells_instance)

	structural_shape_preview_instance = MultiMeshInstance3D.new()
	structural_shape_preview_instance.name = "StructuralShapePreview"
	add_child(structural_shape_preview_instance)

	builder_marker_root = Node3D.new()
	builder_marker_root.name = "BuilderMarkers"
	add_child(builder_marker_root)

	generated_string_segment_a = MeshInstance3D.new()
	generated_string_segment_a.name = "GeneratedBowStringSegmentA"
	add_child(generated_string_segment_a)

	generated_string_segment_b = MeshInstance3D.new()
	generated_string_segment_b.name = "GeneratedBowStringSegmentB"
	add_child(generated_string_segment_b)

	generated_string_draw_segment_a = MeshInstance3D.new()
	generated_string_draw_segment_a.name = "GeneratedBowStringDrawSegmentA"
	add_child(generated_string_draw_segment_a)

	generated_string_draw_segment_b = MeshInstance3D.new()
	generated_string_draw_segment_b.name = "GeneratedBowStringDrawSegmentB"
	add_child(generated_string_draw_segment_b)

	generated_string_draw_pull_point = MeshInstance3D.new()
	generated_string_draw_pull_point.name = "GeneratedBowStringDrawPullPoint"
	add_child(generated_string_draw_pull_point)

	stage2_shell_instance = MeshInstance3D.new()
	stage2_shell_instance.name = "Stage2ShellPreview"
	add_child(stage2_shell_instance)

	stage2_brush_preview_instance = MeshInstance3D.new()
	stage2_brush_preview_instance.name = "Stage2BrushPreview"
	add_child(stage2_brush_preview_instance)

	stage2_hover_face_instance = MeshInstance3D.new()
	stage2_hover_face_instance.name = "Stage2HoverFacePreview"
	add_child(stage2_hover_face_instance)

	stage2_selected_faces_instance = MeshInstance3D.new()
	stage2_selected_faces_instance.name = "Stage2SelectedFacesPreview"
	add_child(stage2_selected_faces_instance)
	_apply_view_tuning()

func _apply_view_defaults() -> void:
	var tuning: ForgeViewTuningDef = _get_view_tuning()
	camera_pivot.position = Vector3.ZERO
	camera_pivot.rotation_degrees.y = tuning.workspace_default_yaw_degrees
	camera_pitch.rotation_degrees.x = tuning.workspace_default_pitch_degrees
	_sync_light_anchor()
	fit_view()

func _apply_view_tuning() -> void:
	var tuning: ForgeViewTuningDef = _get_view_tuning()
	if camera != null:
		camera.fov = tuning.workspace_camera_fov_degrees
		camera.near = tuning.workspace_camera_near
		camera.far = tuning.workspace_camera_far
	if light != null:
		_sync_light_anchor()
		light.light_energy = tuning.workspace_light_energy
	_refresh_generated_string_materials()
	stage2_preview_presenter.sync_stage2_shell_preview(
		stage2_shell_instance,
		null,
		null,
		grid_size,
		cell_world_size,
		tuning,
		false
	)
	stage2_preview_presenter.sync_stage2_brush_preview(
		stage2_brush_preview_instance,
		stage2_shell_preview_visible,
		stage2_brush_preview_hit_local,
		stage2_brush_preview_radius_meters,
		stage2_brush_preview_blocked,
		grid_size,
		cell_world_size,
		tuning
	)
	stage2_preview_presenter.sync_stage2_selection_preview(
		stage2_hover_face_instance,
		stage2_selected_faces_instance,
		null,
		stage2_hover_patch_ids,
		stage2_selected_patch_ids,
		null,
		grid_size,
		cell_world_size,
		tuning,
		false
	)
	geometry_presenter.refresh_visuals(occupied_cells_instance, active_plane_instance, grid_bounds_instance)
	_sync_structural_shape_preview_mesh()
	_apply_stage2_display_priority()

func _sync_light_anchor() -> void:
	if light == null or camera == null:
		return
	var tuning: ForgeViewTuningDef = _get_view_tuning()
	var target_parent: Node = self
	if tuning.workspace_light_follows_camera:
		target_parent = camera
	if light.get_parent() != target_parent:
		light.reparent(target_parent)
	light.position = Vector3.ZERO
	light.rotation_degrees = tuning.workspace_light_follow_offset_degrees if tuning.workspace_light_follows_camera else tuning.workspace_light_rotation_degrees

func _get_view_tuning() -> ForgeViewTuningDef:
	return forge_view_tuning if forge_view_tuning != null else DEFAULT_FORGE_VIEW_TUNING_RESOURCE

func _sync_structural_shape_preview_mesh() -> void:
	if structural_shape_preview_instance == null:
		return
	if stage2_shell_preview_visible or structural_shape_preview_cells.is_empty():
		structural_shape_preview_instance.visible = false
		structural_shape_preview_instance.multimesh = null
		return
	_ensure_structural_shape_preview_multimesh()
	structural_shape_preview_multimesh.instance_count = structural_shape_preview_cells.size()
	for index: int in range(structural_shape_preview_cells.size()):
		var grid_position: Vector3i = structural_shape_preview_cells[index]
		var cell_transform: Transform3D = Transform3D(Basis.IDENTITY, _grid_to_local(grid_position))
		structural_shape_preview_multimesh.set_instance_transform(index, cell_transform)
	structural_shape_preview_instance.multimesh = structural_shape_preview_multimesh
	structural_shape_preview_instance.material_override = _build_structural_shape_preview_material()
	structural_shape_preview_instance.visible = true

func _ensure_structural_shape_preview_multimesh() -> void:
	if structural_shape_preview_multimesh != null:
		structural_shape_preview_multimesh.mesh = _build_structural_shape_preview_mesh()
		return
	structural_shape_preview_multimesh = MultiMesh.new()
	structural_shape_preview_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	structural_shape_preview_multimesh.use_colors = false
	structural_shape_preview_multimesh.mesh = _build_structural_shape_preview_mesh()

func _build_structural_shape_preview_mesh() -> BoxMesh:
	var cell_mesh: BoxMesh = BoxMesh.new()
	var inset: float = cell_world_size * _get_view_tuning().workspace_voxel_inset_factor
	cell_mesh.size = Vector3.ONE * inset
	return cell_mesh

func _build_structural_shape_preview_material() -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	var preview_color: Color = _get_view_tuning().plane_shape_remove_preview_color
	if not structural_shape_preview_remove_mode:
		var resolved_color: Color = _resolve_material_color(structural_shape_preview_material_id)
		preview_color = Color(
			resolved_color.r,
			resolved_color.g,
			resolved_color.b,
			_get_view_tuning().plane_shape_add_preview_alpha
		)
	material.albedo_color = preview_color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material

func _apply_stage2_display_priority() -> void:
	var show_stage1_authoring_mass: bool = not stage2_shell_preview_visible
	if occupied_cells_instance != null:
		occupied_cells_instance.visible = show_stage1_authoring_mass
	if structural_shape_preview_instance != null:
		structural_shape_preview_instance.visible = show_stage1_authoring_mass and not structural_shape_preview_cells.is_empty()
	if builder_marker_root != null:
		builder_marker_root.visible = show_stage1_authoring_mass
	if not show_stage1_authoring_mass:
		_hide_generated_string_preview()
		return

func _resolve_material_color(material_id: StringName) -> Color:
	return material_runtime_resolver.resolve_material_color(
		material_id,
		material_lookup,
		_get_view_tuning().unknown_material_color
	)

func _grid_to_local(grid_position: Vector3i) -> Vector3:
	var offset: Vector3 = Vector3(
		(float(grid_size.x - 1) * cell_world_size) * 0.5,
		(float(grid_size.y - 1) * cell_world_size) * 0.5,
		(float(grid_size.z - 1) * cell_world_size) * 0.5
	)
	return Vector3(grid_position) * cell_world_size - offset

func _sync_generated_string_from_wip(wip: CraftedItemWIP, forge_service: ForgeService) -> void:
	if wip == null or not CraftedItemWIPScript.is_ranged_bow_builder_component(wip.forge_builder_path_id, wip.forge_builder_component_id):
		_hide_generated_string_preview()
		return
	var string_preview_data: Dictionary = _resolve_string_preview_data(wip, forge_service)
	var string_rest_path: Array[Vector3] = _coerce_vector3_path(string_preview_data.get("string_rest_path", []))
	if string_rest_path.size() < 3:
		_hide_generated_string_preview()
		return
	_set_string_segment_points(generated_string_segment_a, string_rest_path[0], string_rest_path[1])
	_set_string_segment_points(generated_string_segment_b, string_rest_path[1], string_rest_path[2])
	var string_draw_path: Array[Vector3] = _coerce_vector3_path(string_preview_data.get("string_draw_path", []))
	if string_draw_path.size() >= 3:
		_set_string_segment_points(generated_string_draw_segment_a, string_draw_path[0], string_draw_path[1], true)
		_set_string_segment_points(generated_string_draw_segment_b, string_draw_path[1], string_draw_path[2], true)
		_set_string_draw_pull_point(string_preview_data.get("string_pull_point_draw_max", Vector3.ZERO))
	else:
		_hide_generated_draw_string()

func _resolve_string_preview_data(wip: CraftedItemWIP, forge_service: ForgeService) -> Dictionary:
	var authored_cells: Array[CellAtom] = CraftedItemWIPScript.collect_cells(wip, true)
	var explicit_pair: Dictionary = CraftedItemWIPScript.resolve_first_complete_string_anchor_pair(authored_cells)
	if not bool(explicit_pair.get("valid", false)):
		return {
			"string_rest_path": [],
			"string_draw_path": [],
			"string_pull_point_draw_max": Vector3.ZERO,
		}
	if forge_service == null:
		return {
			"string_rest_path": _build_fallback_string_rest_path(explicit_pair),
			"string_draw_path": [],
			"string_pull_point_draw_max": Vector3.ZERO,
		}
	var bake_cells: Array[CellAtom] = CraftedItemWIPScript.collect_bake_cells(wip)
	var segments: Array[SegmentAtom] = forge_service.build_segments(bake_cells, material_lookup)
	segments = forge_service.classify_joint_segments(segments, material_lookup)
	var bow_data: Dictionary = forge_service.build_bow_data(
		segments,
		material_lookup,
		wip.forge_intent,
		wip.equipment_context,
		authored_cells
	)
	var rest_path: Array[Vector3] = _coerce_vector3_path(bow_data.get("string_rest_path", []))
	if rest_path.size() < 3:
		rest_path = _build_fallback_string_rest_path(explicit_pair)
	return {
		"string_rest_path": rest_path,
		"string_draw_path": _coerce_vector3_path(bow_data.get("string_draw_path", [])),
		"string_pull_point_draw_max": bow_data.get("string_pull_point_draw_max", Vector3.ZERO),
	}

func _build_fallback_string_rest_path(explicit_pair: Dictionary) -> Array[Vector3]:
	var endpoint_one_cell: CellAtom = explicit_pair.get("endpoint_one_cell") as CellAtom
	var endpoint_two_cell: CellAtom = explicit_pair.get("endpoint_two_cell") as CellAtom
	if endpoint_one_cell == null or endpoint_two_cell == null:
		return []
	var endpoint_one_position: Vector3 = endpoint_one_cell.get_center_position()
	var endpoint_two_position: Vector3 = endpoint_two_cell.get_center_position()
	var upper_anchor: Vector3 = endpoint_one_position
	var lower_anchor: Vector3 = endpoint_two_position
	if endpoint_two_position.y > endpoint_one_position.y:
		upper_anchor = endpoint_two_position
		lower_anchor = endpoint_one_position
	var pull_point: Vector3 = (upper_anchor + lower_anchor) * 0.5
	return [
		upper_anchor,
		pull_point,
		lower_anchor,
	]

func _set_string_segment_points(segment_instance: MeshInstance3D, start_point: Vector3, end_point: Vector3, use_draw_style: bool = false) -> void:
	if segment_instance == null:
		return
	var start_local: Vector3 = _grid_point_to_local(start_point)
	var end_local: Vector3 = _grid_point_to_local(end_point)
	var direction: Vector3 = end_local - start_local
	var length: float = direction.length()
	if length <= 0.0001:
		segment_instance.visible = false
		return
	segment_instance.mesh = _build_generated_string_mesh()
	segment_instance.material_override = _build_generated_string_material(use_draw_style)
	segment_instance.position = start_local + (direction * 0.5)
	segment_instance.scale = Vector3.ONE
	var alignment_basis: Basis = _build_segment_alignment_basis(direction)
	segment_instance.transform.basis = alignment_basis.scaled(Vector3(1.0, length, 1.0))
	segment_instance.visible = true

func _build_generated_string_mesh() -> CylinderMesh:
	var cylinder_mesh: CylinderMesh = CylinderMesh.new()
	cylinder_mesh.top_radius = _get_view_tuning().workspace_generated_string_radius_meters
	cylinder_mesh.bottom_radius = _get_view_tuning().workspace_generated_string_radius_meters
	cylinder_mesh.height = 1.0
	cylinder_mesh.radial_segments = 8
	cylinder_mesh.rings = 1
	return cylinder_mesh

func _build_generated_string_material(use_draw_style: bool = false) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = (
		_get_view_tuning().workspace_generated_string_draw_color
		if use_draw_style
		else _get_view_tuning().workspace_generated_string_color
	)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material

func _refresh_generated_string_materials() -> void:
	for segment_instance: MeshInstance3D in [generated_string_segment_a, generated_string_segment_b]:
		if segment_instance == null:
			continue
		segment_instance.material_override = _build_generated_string_material()
	for draw_segment_instance: MeshInstance3D in [generated_string_draw_segment_a, generated_string_draw_segment_b]:
		if draw_segment_instance == null:
			continue
		draw_segment_instance.material_override = _build_generated_string_material(true)
	if generated_string_draw_pull_point != null:
		generated_string_draw_pull_point.material_override = _build_generated_draw_pull_point_material()

func _sync_builder_markers_from_wip(wip: CraftedItemWIP) -> void:
	if builder_marker_root == null:
		return
	for child: Node in builder_marker_root.get_children():
		child.queue_free()
	if wip == null:
		return
	for marker_cell: CellAtom in CraftedItemWIPScript.collect_builder_marker_cells(wip):
		if marker_cell == null:
			continue
		var marker_instance: MeshInstance3D = MeshInstance3D.new()
		marker_instance.name = "BuilderMarker_%s" % CraftedItemWIPScript.get_builder_marker_short_label(marker_cell.material_variant_id)
		marker_instance.mesh = _build_builder_marker_mesh()
		marker_instance.material_override = _build_builder_marker_material(marker_cell.material_variant_id)
		marker_instance.position = _grid_point_to_local(marker_cell.get_center_position())
		builder_marker_root.add_child(marker_instance)

func _build_builder_marker_mesh() -> SphereMesh:
	var sphere_mesh: SphereMesh = SphereMesh.new()
	sphere_mesh.radius = maxf(cell_world_size * 0.16, 0.01)
	sphere_mesh.height = sphere_mesh.radius * 2.0
	sphere_mesh.radial_segments = 10
	sphere_mesh.rings = 6
	return sphere_mesh

func _build_builder_marker_material(material_id: StringName) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	var marker_color: Color = CraftedItemWIPScript.get_builder_marker_color(material_id)
	material.albedo_color = Color(marker_color.r, marker_color.g, marker_color.b, 0.92)
	material.emission_enabled = true
	material.emission = marker_color
	material.emission_energy_multiplier = 0.8
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material

func _set_string_draw_pull_point(draw_pull_point: Vector3) -> void:
	if generated_string_draw_pull_point == null:
		return
	if draw_pull_point.is_equal_approx(Vector3.ZERO):
		generated_string_draw_pull_point.visible = false
		return
	generated_string_draw_pull_point.mesh = _build_generated_draw_pull_point_mesh()
	generated_string_draw_pull_point.material_override = _build_generated_draw_pull_point_material()
	generated_string_draw_pull_point.position = _grid_point_to_local(draw_pull_point)
	generated_string_draw_pull_point.scale = Vector3.ONE
	generated_string_draw_pull_point.visible = true

func _build_generated_draw_pull_point_mesh() -> SphereMesh:
	var sphere_mesh: SphereMesh = SphereMesh.new()
	var radius: float = maxf(_get_view_tuning().workspace_generated_string_radius_meters * 2.8, 0.004)
	sphere_mesh.radius = radius
	sphere_mesh.height = radius * 2.0
	sphere_mesh.radial_segments = 10
	sphere_mesh.rings = 6
	return sphere_mesh

func _build_generated_draw_pull_point_material() -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = _get_view_tuning().workspace_generated_string_draw_color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material

func _hide_generated_string_preview() -> void:
	if generated_string_segment_a != null:
		generated_string_segment_a.visible = false
	if generated_string_segment_b != null:
		generated_string_segment_b.visible = false
	_hide_generated_draw_string()

func _hide_generated_draw_string() -> void:
	if generated_string_draw_segment_a != null:
		generated_string_draw_segment_a.visible = false
	if generated_string_draw_segment_b != null:
		generated_string_draw_segment_b.visible = false
	if generated_string_draw_pull_point != null:
		generated_string_draw_pull_point.visible = false

func _coerce_vector3_path(path_variant: Variant) -> Array[Vector3]:
	var resolved_path: Array[Vector3] = []
	if path_variant is not Array:
		return resolved_path
	for point_variant: Variant in path_variant:
		if point_variant is Vector3:
			resolved_path.append(point_variant)
	return resolved_path

func _grid_point_to_local(grid_point: Vector3) -> Vector3:
	var offset: Vector3 = Vector3(
		(float(grid_size.x - 1) * cell_world_size) * 0.5,
		(float(grid_size.y - 1) * cell_world_size) * 0.5,
		(float(grid_size.z - 1) * cell_world_size) * 0.5
	)
	return (grid_point * cell_world_size) - offset

func _build_segment_alignment_basis(direction: Vector3) -> Basis:
	var normalized_direction: Vector3 = direction.normalized()
	var up_vector: Vector3 = Vector3.UP
	if absf(normalized_direction.dot(up_vector)) > 0.99:
		up_vector = Vector3.FORWARD
	var alignment_basis: Basis = Basis.looking_at(normalized_direction, up_vector)
	return alignment_basis * Basis.from_euler(Vector3(deg_to_rad(90.0), 0.0, 0.0))
