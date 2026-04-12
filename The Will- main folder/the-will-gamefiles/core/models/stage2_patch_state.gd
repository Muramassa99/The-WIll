extends Resource
class_name Stage2PatchState

const ZONE_GENERAL: StringName = &"stage2_zone_general"
const ZONE_PRIMARY_GRIP_SAFE: StringName = &"stage2_zone_primary_grip_safe"

@export var patch_id: StringName = &""
@export var shell_quad_id: StringName = &""
@export var grid_u_index: int = 0
@export var grid_v_index: int = 0
@export var baseline_quad: Resource
@export var current_quad: Resource
@export var min_surface_depth_voxels: int = 0
@export_range(0.0, 1.0, 0.001) var max_inward_offset_ratio: float = 0.0
@export var max_inward_offset_meters: float = 0.0
@export var max_fillet_offset_meters: float = 0.0
@export var max_chamfer_offset_meters: float = 0.0
@export var current_offset_cells: float = 0.0
@export var zone_mask_id: StringName = ZONE_GENERAL
@export var neighbor_patch_ids: PackedStringArray = PackedStringArray()
@export var dirty: bool = false

func has_current_quad() -> bool:
	return current_quad != null

func is_primary_grip_safe_zone() -> bool:
	return zone_mask_id == ZONE_PRIMARY_GRIP_SAFE
