extends Resource
class_name MaterialVariantDef

@export var variant_id: StringName = &""
@export var base_material_id: StringName = &""
@export var tier_id: StringName = &""
@export var variant_stats: Array[StatLine] = []
@export var resolved_density_per_cell: float = 0.0
@export var resolved_processing_output_count: int = 0
@export var resolved_value_score: float = 0.0
@export var resolved_capability_bias_lines: Array[StatLine] = []
@export var resolved_skill_family_bias_lines: Array[StatLine] = []
@export var resolved_elemental_affinity_lines: Array[StatLine] = []
@export var resolved_equipment_context_bias_lines: Array[StatLine] = []
