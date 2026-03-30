extends Node3D
class_name ForgeWorkspacePreview

const PLANE_XY: StringName = &"xy"
const PLANE_ZX: StringName = &"zx"
const PLANE_ZY: StringName = &"zy"

const DEFAULT_FORGE_RULES_RESOURCE: ForgeRulesDef = preload("res://core/defs/forge/forge_rules_default.tres")
const DEFAULT_FORGE_VIEW_TUNING_RESOURCE: ForgeViewTuningDef = preload("res://core/defs/forge/forge_view_tuning_default.tres")
const MaterialRuntimeResolverScript = preload("res://core/resolvers/material_runtime_resolver.gd")

var grid_size: Vector3i = DEFAULT_FORGE_RULES_RESOURCE.grid_size
var cell_world_size: float = DEFAULT_FORGE_RULES_RESOURCE.cell_world_size_meters
var active_plane: StringName = PLANE_XY
var active_layer: int = DEFAULT_FORGE_RULES_RESOURCE.grid_size.z >> 1
var material_lookup: Dictionary = {}
var forge_view_tuning: ForgeViewTuningDef = DEFAULT_FORGE_VIEW_TUNING_RESOURCE
var material_runtime_resolver = MaterialRuntimeResolverScript.new()

var camera_pivot: Node3D
var camera_pitch: Node3D
var camera: Camera3D
var light: DirectionalLight3D
var occupied_cells_instance: MultiMeshInstance3D
var active_plane_instance: MeshInstance3D
var grid_bounds_instance: MeshInstance3D
var view_initialized: bool = false
var occupied_cells_multimesh: MultiMesh
var occupied_cell_mesh: BoxMesh

func _ready() -> void:
	_build_scene()
	_apply_view_defaults()
	_update_plane_mesh()
	_update_grid_bounds_mesh()

func configure(new_grid_size: Vector3i, new_cell_world_size: float, preserve_view: bool = true) -> void:
	var geometry_changed: bool = grid_size != new_grid_size or not is_equal_approx(cell_world_size, new_cell_world_size)
	grid_size = new_grid_size
	cell_world_size = new_cell_world_size
	if geometry_changed:
		_refresh_occupied_cell_mesh()
	_update_plane_mesh()
	_update_grid_bounds_mesh()
	if not preserve_view or geometry_changed or not view_initialized:
		reset_view()

func set_active_slice(plane_id: StringName, layer_index: int) -> void:
	active_plane = plane_id
	active_layer = layer_index
	_update_plane_mesh()

func set_material_lookup(value: Dictionary) -> void:
	material_lookup = value

func set_view_tuning(value: ForgeViewTuningDef) -> void:
	forge_view_tuning = value if value != null else DEFAULT_FORGE_VIEW_TUNING_RESOURCE
	if is_inside_tree():
		_refresh_occupied_cell_mesh()
		_apply_view_tuning()

func sync_from_wip(wip: CraftedItemWIP) -> void:
	if occupied_cells_instance == null:
		return
	var cells: Array[CellAtom] = []
	if wip != null:
		for layer_atom: LayerAtom in wip.layers:
			if layer_atom == null:
				continue
			for cell: CellAtom in layer_atom.cells:
				if cell != null:
					cells.append(cell)

	_ensure_occupied_multimesh()
	occupied_cells_multimesh.instance_count = cells.size()
	for index in range(cells.size()):
		var cell: CellAtom = cells[index]
		var cell_transform: Transform3D = Transform3D(Basis.IDENTITY, _grid_to_local(cell.grid_position))
		occupied_cells_multimesh.set_instance_transform(index, cell_transform)
		occupied_cells_multimesh.set_instance_color(index, _resolve_material_color(cell.material_variant_id))
	occupied_cells_instance.multimesh = occupied_cells_multimesh

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
	if camera == null:
		return null
	var ray_origin: Vector3 = camera.project_ray_origin(screen_position)
	var ray_direction: Vector3 = camera.project_ray_normal(screen_position)
	var plane_normal: Vector3 = _get_plane_normal()
	var plane_point: Vector3 = _get_plane_point()
	var denominator: float = ray_direction.dot(plane_normal)
	if absf(denominator) <= _get_view_tuning().workspace_ray_plane_epsilon:
		return null
	var distance: float = (plane_point - ray_origin).dot(plane_normal) / denominator
	if distance < 0.0:
		return null
	var hit_position: Vector3 = ray_origin + (ray_direction * distance)
	if not _is_local_position_within_grid_bounds(hit_position):
		return null
	return _local_to_grid(hit_position)

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
	occupied_cells_instance.material_override = _build_voxel_material()
	add_child(occupied_cells_instance)
	_ensure_occupied_multimesh()
	_apply_view_tuning()

func _apply_view_defaults() -> void:
	var tuning: ForgeViewTuningDef = _get_view_tuning()
	camera_pivot.position = Vector3.ZERO
	camera_pivot.rotation_degrees.y = tuning.workspace_default_yaw_degrees
	camera_pitch.rotation_degrees.x = tuning.workspace_default_pitch_degrees
	_sync_light_anchor()
	fit_view()

func _build_cell_mesh() -> BoxMesh:
	var cell_mesh: BoxMesh = BoxMesh.new()
	var inset: float = cell_world_size * _get_view_tuning().workspace_voxel_inset_factor
	cell_mesh.size = Vector3.ONE * inset
	return cell_mesh

func _refresh_occupied_cell_mesh() -> void:
	occupied_cell_mesh = _build_cell_mesh()
	if occupied_cells_multimesh != null:
		occupied_cells_multimesh.mesh = occupied_cell_mesh

func _ensure_occupied_multimesh() -> void:
	if occupied_cells_multimesh != null:
		if occupied_cells_multimesh.mesh == null:
			occupied_cells_multimesh.mesh = occupied_cell_mesh if occupied_cell_mesh != null else _build_cell_mesh()
		return
	occupied_cells_multimesh = MultiMesh.new()
	occupied_cells_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	occupied_cells_multimesh.use_colors = true
	if occupied_cell_mesh == null:
		occupied_cell_mesh = _build_cell_mesh()
	occupied_cells_multimesh.mesh = occupied_cell_mesh

func _build_voxel_material() -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = _get_view_tuning().workspace_voxel_roughness
	material.metallic = _get_view_tuning().workspace_voxel_metallic
	return material

func _build_grid_material(color: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material

func _update_grid_bounds_mesh() -> void:
	if grid_bounds_instance == null:
		return
	var box_mesh: BoxMesh = BoxMesh.new()
	box_mesh.size = Vector3(
		float(grid_size.x) * cell_world_size,
		float(grid_size.y) * cell_world_size,
		float(grid_size.z) * cell_world_size
	)
	grid_bounds_instance.mesh = box_mesh
	grid_bounds_instance.position = Vector3.ZERO

func _update_plane_mesh() -> void:
	if active_plane_instance == null:
		return
	var plane_mesh: BoxMesh = BoxMesh.new()
	var thickness: float = cell_world_size * _get_view_tuning().workspace_plane_thickness_factor
	var plane_position: Vector3 = _get_plane_point()
	match active_plane:
		PLANE_ZX:
			plane_mesh.size = Vector3(float(grid_size.z) * cell_world_size, thickness, float(grid_size.x) * cell_world_size)
			active_plane_instance.rotation_degrees = Vector3(0.0, 90.0, 0.0)
		PLANE_ZY:
			plane_mesh.size = Vector3(thickness, float(grid_size.y) * cell_world_size, float(grid_size.z) * cell_world_size)
			active_plane_instance.rotation_degrees = Vector3(0.0, 0.0, 0.0)
		_:
			plane_mesh.size = Vector3(float(grid_size.x) * cell_world_size, float(grid_size.y) * cell_world_size, thickness)
			active_plane_instance.rotation_degrees = Vector3(0.0, 0.0, 0.0)
	active_plane_instance.mesh = plane_mesh
	active_plane_instance.position = plane_position

func _get_plane_normal() -> Vector3:
	match active_plane:
		PLANE_ZX:
			return Vector3.UP
		PLANE_ZY:
			return Vector3.RIGHT
		_:
			return Vector3.BACK

func _get_plane_point() -> Vector3:
	match active_plane:
		PLANE_ZX:
			return Vector3(0.0, _get_layer_axis_local_coordinate(grid_size.y, active_layer), 0.0)
		PLANE_ZY:
			return Vector3(_get_layer_axis_local_coordinate(grid_size.x, active_layer), 0.0, 0.0)
		_:
			return Vector3(0.0, 0.0, _get_layer_axis_local_coordinate(grid_size.z, active_layer))

func _get_layer_axis_local_coordinate(axis_size: int, layer_index: int) -> float:
	if axis_size <= 0:
		return 0.0
	var clamped_layer_index: int = clampi(layer_index, 0, axis_size - 1)
	var axis_offset: float = (float(axis_size - 1) * cell_world_size) * 0.5
	return float(clamped_layer_index) * cell_world_size - axis_offset

func _grid_to_local(grid_position: Vector3i) -> Vector3:
	var offset: Vector3 = Vector3(
		(float(grid_size.x - 1) * cell_world_size) * 0.5,
		(float(grid_size.y - 1) * cell_world_size) * 0.5,
		(float(grid_size.z - 1) * cell_world_size) * 0.5
	)
	return Vector3(grid_position) * cell_world_size - offset

func _local_to_grid(local_position: Vector3) -> Variant:
	if not _is_local_position_within_grid_bounds(local_position):
		return null
	var offset: Vector3 = Vector3(
		(float(grid_size.x - 1) * cell_world_size) * 0.5,
		(float(grid_size.y - 1) * cell_world_size) * 0.5,
		(float(grid_size.z - 1) * cell_world_size) * 0.5
	)
	var grid_position: Vector3 = (local_position + offset) / cell_world_size
	var result: Vector3i = Vector3i(
		clampi(int(round(grid_position.x)), 0, grid_size.x - 1),
		clampi(int(round(grid_position.y)), 0, grid_size.y - 1),
		clampi(int(round(grid_position.z)), 0, grid_size.z - 1)
	)
	match active_plane:
		PLANE_ZX:
			result.y = clampi(active_layer, 0, grid_size.y - 1)
		PLANE_ZY:
			result.x = clampi(active_layer, 0, grid_size.x - 1)
		_:
			result.z = clampi(active_layer, 0, grid_size.z - 1)
	return result

func _is_local_position_within_grid_bounds(local_position: Vector3) -> bool:
	var half_extents: Vector3 = Vector3(
		(float(grid_size.x) * cell_world_size) * 0.5,
		(float(grid_size.y) * cell_world_size) * 0.5,
		(float(grid_size.z) * cell_world_size) * 0.5
	)
	var tolerance: float = 0.0001
	return local_position.x >= -half_extents.x - tolerance \
		and local_position.x <= half_extents.x + tolerance \
		and local_position.y >= -half_extents.y - tolerance \
		and local_position.y <= half_extents.y + tolerance \
		and local_position.z >= -half_extents.z - tolerance \
		and local_position.z <= half_extents.z + tolerance

func _resolve_material_color(material_id: StringName) -> Color:
	return material_runtime_resolver.resolve_material_color(
		material_id,
		material_lookup,
		_get_view_tuning().unknown_material_color
	)

func _apply_view_tuning() -> void:
	var tuning: ForgeViewTuningDef = _get_view_tuning()
	if camera != null:
		camera.fov = tuning.workspace_camera_fov_degrees
		camera.near = tuning.workspace_camera_near
		camera.far = tuning.workspace_camera_far
	if light != null:
		_sync_light_anchor()
		light.light_energy = tuning.workspace_light_energy
	if grid_bounds_instance != null:
		grid_bounds_instance.material_override = _build_grid_material(tuning.workspace_grid_bounds_color)
	if active_plane_instance != null:
		active_plane_instance.material_override = _build_grid_material(tuning.workspace_active_plane_color)

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
