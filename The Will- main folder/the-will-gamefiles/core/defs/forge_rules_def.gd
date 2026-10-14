extends Resource
class_name ForgeRulesDef

@export var rules_id: StringName = &"forge_rules_default"

# Shared saved-coordinate unit retained by the V2 mesh/profile compatibility
# boundary. Handle length eligibility is owned by HandleLengthPolicy in metres.
@export_range(0.001, 1.0, 0.001) var cell_world_size_meters: float = 0.0125
