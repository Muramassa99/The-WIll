extends Resource
class_name CraftedItemWIP

@export var wip_id: StringName = &""
@export var forge_project_name: String = ""
@export_multiline var forge_project_notes: String = ""
@export var creator_id: StringName = &""
@export var created_timestamp: float = 0.0
@export var forge_intent: StringName = &""
@export var equipment_context: StringName = &""
@export var layers: Array[LayerAtom] = []
@export var latest_baked_profile_snapshot: BakedProfile
