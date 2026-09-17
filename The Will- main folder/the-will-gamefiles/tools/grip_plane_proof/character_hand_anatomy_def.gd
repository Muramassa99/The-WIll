extends Resource

## Prototype persistent anatomy data. Preparation and IO belong to separate
## tools. This definition carries no runtime nodes, timers, or bake-on-load work.
@export var schema_revision: String = "character_hand_anatomy_v1"
@export var preparation_revision: String = ""
@export var character_id: StringName = StringName()
@export var character_scene_path: String = ""
@export var source_signature: String = ""
@export var source_manifest: Dictionary = {}
@export var root_origin_id: StringName = &"RL_BoneRoot"
@export var measurement_status: StringName = &"measured_anatomy_proof"
@export var contact_shape_validated: bool = false
@export var reference_skin: Dictionary = {}
@export var digits: Array[Dictionary] = []
@export var character_measurements: Dictionary = {}
@export var origin_records: Array[Dictionary] = []
