extends Resource
class_name BaseMaterialDef

@export var base_material_id: StringName = &""
@export var display_name: String = ""

# structural / affinity / keystone
@export var material_family: StringName = &"structural"

# physical truth
@export var density_per_cell: float = 0.0
@export var hardness: float = 0.0
@export var toughness: float = 0.0
@export var elasticity: float = 0.0
@export var brittleness: float = 0.0
@export var edge_retention: float = 0.0
@export var thermal_stability: float = 0.0
@export var corrosion_resistance: float = 0.0
@export var conductivity: float = 0.0

# economy / lifecycle
@export var processing_output_count: int = 6
@export var salvage_priority: int = 0
@export var can_be_processed: bool = true
@export var can_be_salvaged: bool = true
@export var can_be_blueprinted: bool = true

# visual identity
@export var color_group: StringName = &"gray"
@export var albedo_color: Color = Color(1.0, 1.0, 1.0, 1.0)
@export var metallic_grade: float = 0.0
@export var gloss_grade: float = 0.0
@export var transparency_grade: float = 0.0

# tags / hard hooks
@export var material_tags: Array[StringName] = []
@export var unlock_tags: Array[StringName] = []
@export var block_tags: Array[StringName] = []

# direct numeric stats
@export var base_stat_lines: Array[StatLine] = []

# hidden biases
@export var capability_bias_lines: Array[StatLine] = []
@export var skill_family_bias_lines: Array[StatLine] = []
@export var elemental_affinity_lines: Array[StatLine] = []
@export var equipment_context_bias_lines: Array[StatLine] = []

# hard support flags
@export var can_be_anchor_material: bool = false
@export var can_be_beveled_edge: bool = false
@export var can_be_blunt_surface: bool = false
@export var can_be_grip_profile: bool = false
@export var can_be_guard_surface: bool = false
@export var can_be_plate_surface: bool = false

@export var can_be_joint_support: bool = false
@export var can_be_joint_membrane: bool = false
@export var can_be_axial_spin_joint: bool = false
@export var can_be_planar_hinge_joint: bool = false

@export var can_be_bow_limb: bool = false
@export var can_be_bow_string: bool = false
@export var can_be_riser_core: bool = false
@export var can_be_projectile_support: bool = false
@export var can_be_bow_grip: bool = false

func has_tag(tag: StringName) -> bool:
	return material_tags.has(tag)

func has_unlock_tag(tag: StringName) -> bool:
	return unlock_tags.has(tag)

func has_block_tag(tag: StringName) -> bool:
	return block_tags.has(tag)

func supports_anchor() -> bool:
	return can_be_anchor_material

func supports_bow_string() -> bool:
	return can_be_bow_string

func supports_joint() -> bool:
	return (
		can_be_joint_support
		or can_be_joint_membrane
		or can_be_axial_spin_joint
		or can_be_planar_hinge_joint
	)
