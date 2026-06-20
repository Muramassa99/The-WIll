extends Resource
class_name SalvageRulesDef

@export var rule_id: StringName = &"salvage_rules_default"
@export_range(0.0, 1.0, 0.01) var material_return_ratio_with_blueprint: float = 0.15
@export_range(0.0, 1.0, 0.01) var material_return_ratio_without_blueprint: float = 0.35
@export_range(0.0, 16.0, 0.01) var higher_tier_priority_weight: float = 1.0
@export_range(0.0, 16.0, 0.01) var skill_core_priority_weight: float = 1.0
@export var allow_manual_salvage_selection: bool = true
