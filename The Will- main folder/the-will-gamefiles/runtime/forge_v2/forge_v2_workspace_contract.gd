extends Resource
class_name ForgeV2WorkspaceContract

const CONTRACT_ID := &"forge_v2_workspace_contract_v1"
const AUTHORING_SPACE_DIEGETIC_BOX := &"authoring_space_diegetic_box"
const PLACEMENT_MODE_PLANE := &"placement_mode_plane"
const FREEHAND_SMOOTHING_MIN := 0
const FREEHAND_SMOOTHING_MAX := 10

@export var contract_id: StringName = CONTRACT_ID
@export var authoring_space_id: StringName = AUTHORING_SPACE_DIEGETIC_BOX
@export var placement_mode: StringName = PLACEMENT_MODE_PLANE
@export var local_min: Vector3 = Vector3(-3.0, -1.0, -0.5)
@export var local_max: Vector3 = Vector3(3.0, 1.0, 0.5)
@export var placement_plane_z: float = 0.0
@export var plane_visual_z_offset: float = -0.002
@export var grid_visual_z_offset: float = 0.001
@export var axes_visual_z_offset: float = 0.004
@export var grid_step_meters: float = 0.125
@export var fit_size_meters: float = 6.0
@export var stroke_sample_spacing_radius_ratio: float = 0.55
@export var stroke_sample_spacing_min_meters: float = 0.00625
@export_range(0, 10, 1) var freehand_smoothing_steps: int = 0
@export var show_bounds_box: bool = true
@export var world_prop_anchor_id: StringName = &"forge_v2_authoring_box"

func normalize() -> void:
	contract_id = CONTRACT_ID
	authoring_space_id = AUTHORING_SPACE_DIEGETIC_BOX
	placement_mode = PLACEMENT_MODE_PLANE
	if local_min.x > local_max.x:
		var swap_x := local_min.x
		local_min.x = local_max.x
		local_max.x = swap_x
	if local_min.y > local_max.y:
		var swap_y := local_min.y
		local_min.y = local_max.y
		local_max.y = swap_y
	if local_min.z > local_max.z:
		var swap_z := local_min.z
		local_min.z = local_max.z
		local_max.z = swap_z
	if local_min.is_equal_approx(local_max):
		local_min = Vector3(-3.0, -1.0, -0.5)
		local_max = Vector3(3.0, 1.0, 0.5)
	placement_plane_z = clampf(placement_plane_z, local_min.z, local_max.z)
	grid_step_meters = maxf(grid_step_meters, 0.001)
	fit_size_meters = maxf(fit_size_meters, maxf(get_local_size().x, get_local_size().y))
	stroke_sample_spacing_radius_ratio = clampf(stroke_sample_spacing_radius_ratio, 0.1, 2.0)
	stroke_sample_spacing_min_meters = maxf(stroke_sample_spacing_min_meters, 0.001)
	freehand_smoothing_steps = normalize_freehand_smoothing_steps(freehand_smoothing_steps)
	if world_prop_anchor_id == StringName():
		world_prop_anchor_id = &"forge_v2_authoring_box"

func get_local_size() -> Vector3:
	return local_max - local_min

func get_local_center() -> Vector3:
	return (local_min + local_max) * 0.5

func get_plane_size() -> Vector2:
	var local_size: Vector3 = get_local_size()
	return Vector2(maxf(local_size.x, 0.001), maxf(local_size.y, 0.001))

func get_placement_plane_origin_local() -> Vector3:
	return Vector3(0.0, 0.0, placement_plane_z)

func clamp_local_position(local_position: Vector3) -> Vector3:
	return Vector3(
		clampf(local_position.x, local_min.x, local_max.x),
		clampf(local_position.y, local_min.y, local_max.y),
		clampf(local_position.z, local_min.z, local_max.z)
	)

func contains_local_position(local_position: Vector3, epsilon: float = 0.0001) -> bool:
	return (
		local_position.x >= local_min.x - epsilon
		and local_position.x <= local_max.x + epsilon
		and local_position.y >= local_min.y - epsilon
		and local_position.y <= local_max.y + epsilon
		and local_position.z >= local_min.z - epsilon
		and local_position.z <= local_max.z + epsilon
	)

func resolve_stroke_sample_spacing(radius_meters: float) -> float:
	return maxf(maxf(radius_meters, 0.001) * stroke_sample_spacing_radius_ratio, stroke_sample_spacing_min_meters)

func normalize_freehand_smoothing_steps(step_count: int) -> int:
	return clampi(step_count, FREEHAND_SMOOTHING_MIN, FREEHAND_SMOOTHING_MAX)

func set_freehand_smoothing_steps(step_count: int) -> void:
	freehand_smoothing_steps = normalize_freehand_smoothing_steps(step_count)

func get_freehand_smoothing_ratio() -> float:
	return float(normalize_freehand_smoothing_steps(freehand_smoothing_steps)) / float(FREEHAND_SMOOTHING_MAX)

func build_summary() -> Dictionary:
	return {
		"contract_id": contract_id,
		"authoring_space_id": authoring_space_id,
		"placement_mode": placement_mode,
		"local_min": local_min,
		"local_max": local_max,
		"local_size": get_local_size(),
		"placement_plane_z": placement_plane_z,
		"grid_step_meters": grid_step_meters,
		"fit_size_meters": fit_size_meters,
		"stroke_sample_spacing_radius_ratio": stroke_sample_spacing_radius_ratio,
		"stroke_sample_spacing_min_meters": stroke_sample_spacing_min_meters,
		"freehand_smoothing_steps": freehand_smoothing_steps,
		"freehand_smoothing_ratio": get_freehand_smoothing_ratio(),
		"show_bounds_box": show_bounds_box,
		"world_prop_anchor_id": world_prop_anchor_id,
	}
