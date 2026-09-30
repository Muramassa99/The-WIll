extends Resource

## Forge-prepared, invisible handle contact targets. These arrays are data only:
## they do not create a rendered mesh, material, physics body, or runtime node.
## Skill Crafter slices them alongside the actual handle. The handle remains
## the authority for physical overlap limits; these surfaces provide targets.
const SCHEMA_VERSION := 1
const CONSTRUCTION_REVISION: StringName = &"forge_v2_profile_envelope_sweep_v1"
const PROFILE_ORIGIN_ID: StringName = &"ForgeV2HandleProfileOrigin"
const CombatOriginRecordScript = preload("res://core/models/combat_origin_record.gd")

@export var schema_version: int = SCHEMA_VERSION
@export var construction_revision: StringName = CONSTRUCTION_REVISION

## All source and target 3D vertices are metres in the same named weapon frame.
## Existing equipment placement resolves WeaponRootOrigin back to RL_BoneRoot.
@export var vertices_origin_id: StringName = CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
@export var source_body_signature: String = ""
@export var source_handle_vertices_m: PackedVector3Array = PackedVector3Array()
@export var source_handle_indices: PackedInt32Array = PackedInt32Array()

## Identity and settings of the prepared character whose curvature was used.
@export var character_id: StringName = StringName()
@export var anatomy_signature: String = ""
@export var inward_min_radius_m: float = 0.0
@export var guide_inward_target_offset_m: float = 0.0
@export var palm_guide_target_depth_m: float = 0.0

## Construction profiles in the source handle's authored 2D profile frame.
## These retain preparation evidence, not per-digit Skill Crafter slices.
## The source body signature binds the existing CSG path-frame mapping into
## vertices_origin_id. Equipment placement then resolves that frame to the root.
@export var profile_origin_id: StringName = PROFILE_ORIGIN_ID
@export var source_profile_m: PackedVector2Array = PackedVector2Array()
@export var envelope_profile_m: PackedVector2Array = PackedVector2Array()
@export var target_profile_m: PackedVector2Array = PackedVector2Array()
@export var palm_target_profile_m: PackedVector2Array = PackedVector2Array()

## Closed indexed triangle surfaces, both in vertices_origin_id.
@export var target_vertices_m: PackedVector3Array = PackedVector3Array()
@export var target_indices: PackedInt32Array = PackedInt32Array()
@export var palm_target_vertices_m: PackedVector3Array = PackedVector3Array()
@export var palm_target_indices: PackedInt32Array = PackedInt32Array()
@export var build_ms: float = 0.0
