extends Resource

## Character-owned measured CORE samples. Source faces carry sample provenance;
## they are not a complete palmar partition or a rigid Hand-local skin patch.
@export var schema_revision: String = "prepared_palmar_core_samples_v1"
@export var preparation_revision: String = ""
@export var character_id: StringName = StringName()
@export var anatomy_signature: String = ""
@export var recipe_fingerprint: String = ""
@export var recipe_manifest: Dictionary = {}
@export var root_origin_id: StringName = &"RL_BoneRoot"
@export var source_mesh_origin_id: StringName = StringName()
@export var complete: bool = false
@export var samples_by_slot: Dictionary = {}
@export var slot_metadata: Dictionary = {}
@export var origin_records: Array[Dictionary] = []
@export var measurement_status: StringName = &"unmeasured"
@export var sampling_scope: String = "nine_interior_wrist_index_pinky_core_rays_per_hand"
@export var solid_enclosure_verified: bool = false
@export var complete_palm_partition_verified: bool = false
@export var palm_overlap_policy_defined: bool = false
@export var palm_contact_verified: bool = false
@export var actual_3d_grip_verified: bool = false
