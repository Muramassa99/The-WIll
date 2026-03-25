extends Resource
class_name ForgeRulesDef

const ForgeSamplePresetDefScript = preload("res://core/defs/forge/forge_sample_preset_def.gd")

@export var rules_id: StringName = &"forge_rules_default"

@export_group("Workspace")
@export var grid_size: Vector3i = Vector3i(160, 80, 40)
@export_range(0.001, 1.0, 0.001) var cell_world_size_meters: float = 0.025
@export_range(0.0, 1.0, 0.01) var max_fill_ratio: float = 0.35

@export_group("Debug Presets")
@export var default_sample_preset_id: StringName = &"sample_grip"
@export var sample_grip_preset_id: StringName = &"sample_grip"
@export var sample_flex_preset_id: StringName = &"sample_flex"
@export var sample_bow_preset_id: StringName = &"sample_bow"
@export var sample_presets: Array[ForgeSamplePresetDef] = []
@export var debug_inventory_seed_quantity: int = 96

@export_group("Anchor Rules")
@export var primary_grip_min_length_voxels: int = 10
@export var primary_grip_min_thickness_voxels: int = 2
@export var primary_grip_max_thickness_voxels: int = 4
@export var primary_grip_min_width_voxels: int = 3
@export var primary_grip_max_width_voxels: int = 4
@export_range(0.0, 1.0, 0.01) var primary_grip_min_anchor_ratio: float = 0.80

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
@export_range(0.1, 32.0, 0.1) var bow_limb_flex_length_reference_voxels: float = 8.0
@export_range(0.0, 10.0, 0.1) var bow_riser_adjacent_slice_compactness_threshold: float = 1.5