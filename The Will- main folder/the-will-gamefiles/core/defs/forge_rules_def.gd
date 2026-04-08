extends Resource
class_name ForgeRulesDef

@export var rules_id: StringName = &"forge_rules_default"

@export_group("Workspace")
@export var grid_size: Vector3i = Vector3i(160, 80, 40)
@export var melee_grid_size: Vector3i = Vector3i(240, 80, 40)
@export var ranged_physical_grid_size: Vector3i = Vector3i(160, 80, 30)
@export var shield_grid_size: Vector3i = Vector3i(100, 80, 30)
@export var magic_grid_size: Vector3i = Vector3i(100, 30, 30)
@export var ranged_physical_quiver_grid_size: Vector3i = Vector3i(70, 30, 30)
@export_range(0.001, 1.0, 0.001) var cell_world_size_meters: float = 0.025
@export_range(0.0, 1.0, 0.01) var max_fill_ratio: float = 0.35

@export_group("Forge Materials")
@export var material_catalog_def: Resource
@export var default_material_tier_def: Resource

@export_group("Anchor Rules")
@export var primary_grip_min_length_voxels: int = 10
@export var primary_grip_min_thickness_voxels: int = 2
@export var primary_grip_max_thickness_voxels: int = 4
@export var primary_grip_min_width_voxels: int = 3
@export var primary_grip_max_width_voxels: int = 4
@export_range(0.0, 1.0, 0.01) var primary_grip_min_anchor_ratio: float = 0.80
@export var primary_grip_two_hand_min_length_voxels: int = 18
@export_range(0.0, 0.5, 0.01) var primary_grip_center_balance_tolerance_percent: float = 0.07
@export_range(0.0, 1.0, 0.01) var primary_grip_two_hand_max_span_usage_percent: float = 0.80

@export_group("Joint Rules")
@export var joint_min_cross_width_voxels: int = 2
@export var joint_min_cross_thickness_voxels: int = 2
@export var joint_min_length_voxels: int = 4
@export_range(0.0, 1.0, 0.01) var joint_min_support_material_ratio: float = 0.80
@export_range(-360.0, 360.0, 0.1) var joint_angle_limit_min_degrees: float = -90.0
@export_range(-360.0, 360.0, 0.1) var joint_angle_limit_max_degrees: float = 90.0

@export_group("Segment Role Rules")
@export_range(0.0, 1.0, 0.01) var riser_min_support_material_ratio: float = 0.80
@export var riser_min_compact_cross_span_voxels: int = 2
@export var riser_max_length_voxels: int = 4
@export_range(0.0, 1.0, 0.01) var bow_string_min_support_material_ratio: float = 0.80
@export var bow_string_max_cross_span_voxels: int = 1
@export var bow_string_min_length_voxels: int = 3
@export_range(0.0, 1.0, 0.01) var projectile_min_support_material_ratio: float = 0.50

@export_group("Bow Rules")
@export var bow_string_required_cross_span_voxels: int = 1
@export var bow_limb_min_cross_width_voxels: int = 2
@export var bow_limb_min_cross_thickness_voxels: int = 2
@export var bow_limb_min_length_voxels: int = 4
@export_range(0.05, 2.0, 0.01) var bow_string_draw_distance_meters: float = 0.45
@export_range(0.1, 32.0, 0.1) var bow_limb_flex_length_reference_voxels: float = 8.0
@export_range(0.0, 10.0, 0.1) var bow_riser_adjacent_slice_compactness_threshold: float = 1.5

@export_group("Stage 2 Refinement Envelope")
@export_range(0.0, 1.0, 0.001) var stage2_single_cell_max_inward_ratio: float = 0.475
@export_range(0.0, 1.0, 0.001) var stage2_multi_cell_max_inward_ratio: float = 0.95
@export_range(0.0, 1.0, 0.001) var stage2_fillet_max_inward_ratio: float = 0.35
@export_range(0.0, 1.0, 0.001) var stage2_chamfer_max_inward_ratio: float = 0.7
@export_range(0.0, 16.0, 0.1) var stage2_primary_grip_safe_radius_voxels: float = 2.5
@export_range(0.0005, 2.0, 0.0005) var stage2_pointer_tool_min_radius_meters: float = 0.0125
@export_range(0.0005, 2.0, 0.0005) var stage2_pointer_tool_max_radius_meters: float = 0.375
@export_range(0.0005, 2.0, 0.0005) var stage2_pointer_tool_radius_step_meters: float = 0.0125

func get_grid_size_for_builder_path(builder_path_id: StringName) -> Vector3i:
	return get_grid_size_for_builder_path_component(
		builder_path_id,
		CraftedItemWIP.get_default_builder_component_id(builder_path_id)
	)

func get_grid_size_for_builder_path_component(builder_path_id: StringName, builder_component_id: StringName) -> Vector3i:
	match CraftedItemWIP.normalize_builder_path_id(builder_path_id):
		CraftedItemWIP.BUILDER_PATH_RANGED_PHYSICAL:
			if CraftedItemWIP.normalize_builder_component_id(builder_path_id, builder_component_id) == CraftedItemWIP.BUILDER_COMPONENT_QUIVER:
				return ranged_physical_quiver_grid_size
			return ranged_physical_grid_size
		CraftedItemWIP.BUILDER_PATH_SHIELD:
			return shield_grid_size
		CraftedItemWIP.BUILDER_PATH_MAGIC:
			return magic_grid_size
		_:
			return melee_grid_size
