extends Resource
class_name SkillCoreRulesDef

@export var rule_id: StringName = &"skill_core_rules_default"
@export var skill_cores_are_nonmodifiable_in_skill_station: bool = true
@export_range(0.0, 16.0, 0.01) var salvage_priority_bonus: float = 1.0
@export var count_toward_special_recovery_logic: bool = true
