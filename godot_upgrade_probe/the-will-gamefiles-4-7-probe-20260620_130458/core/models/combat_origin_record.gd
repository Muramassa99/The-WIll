extends Resource
class_name CombatOriginRecord

const ORIGIN_RL_BONE_ROOT: StringName = &"RL_BoneRoot"
const ORIGIN_TRAJECTORY_AUTHORING: StringName = &"TrajectoryAuthoringOrigin"
const ORIGIN_SOLVED_REPLAY_REFERENCE: StringName = &"SolvedReplayReferenceOrigin"
const ORIGIN_WEAPON_ROOT: StringName = &"WeaponRootOrigin"
const ORIGIN_PRIMARY_GRIP_ANCHOR: StringName = &"PrimaryGripAnchorOrigin"
const ORIGIN_SUPPORT_GRIP_ANCHOR: StringName = &"SupportGripAnchorOrigin"
const ORIGIN_HAND_GRIP_ALIGNMENT: StringName = &"HandGripAlignmentOrigin"
const ORIGIN_PRIMARY_SHOULDER: StringName = &"PrimaryShoulderOrigin"
const ORIGIN_BRIDGE_START: StringName = &"BridgeStartOrigin"
const ORIGIN_BRIDGE_TARGET: StringName = &"BridgeTargetOrigin"
const ORIGIN_COMBAT_IDLE: StringName = &"CombatIdleOrigin"
const ORIGIN_NONCOMBAT_STOW: StringName = &"NonCombatStowOrigin"
const ORIGIN_STOW_ANCHOR: StringName = &"StowAnchorOrigin"
const ORIGIN_BODY_RESTRICTION_ATTACHMENT: StringName = &"BodyRestrictionAttachmentOrigin"
const ORIGIN_RUNTIME_ENDPOINT_AUTHORITY_ROOT: StringName = &"RuntimeEndpointAuthorityRoot"

const OWNER_SYSTEM_COMBAT_ORIGIN_REGISTRY: StringName = &"combat_origin_registry"

const PHASE_UNKNOWN: StringName = &"unknown"
const PHASE_BAKE_TIME: StringName = &"bake_time"
const PHASE_EDITOR_PREVIEW: StringName = &"editor_preview"
const PHASE_PRE_ANIMATION: StringName = &"pre_animation"
const PHASE_POST_LOCOMOTION: StringName = &"post_locomotion"
const PHASE_POST_COMBAT_MODIFIER: StringName = &"post_combat_modifier"
const PHASE_POST_FINAL_POSE: StringName = &"post_final_pose"
const PHASE_RUNTIME_BRIDGE: StringName = &"runtime_bridge"
const PHASE_RUNTIME_STOW: StringName = &"runtime_stow"

const SPACE_TYPE_UNKNOWN: StringName = &"unknown"
const SPACE_TYPE_MACHINE: StringName = &"machine"
const SPACE_TYPE_BONE_FRAME: StringName = &"bone_frame"
const SPACE_TYPE_TRAJECTORY: StringName = &"trajectory"
const SPACE_TYPE_WEAPON: StringName = &"weapon"
const SPACE_TYPE_ANCHOR: StringName = &"anchor"
const SPACE_TYPE_HAND_ALIGNMENT: StringName = &"hand_alignment"
const SPACE_TYPE_SHOULDER: StringName = &"shoulder"
const SPACE_TYPE_BRIDGE: StringName = &"bridge"
const SPACE_TYPE_IDLE: StringName = &"idle"
const SPACE_TYPE_STOW: StringName = &"stow"
const SPACE_TYPE_COLLISION: StringName = &"collision"
const SPACE_TYPE_PRESENTATION: StringName = &"presentation"

@export var origin_id: StringName = &""
@export var parent_origin_id: StringName = &""
@export var transform_to_parent: Transform3D = Transform3D.IDENTITY
@export var resolved_transform_to_machine: Transform3D = Transform3D.IDENTITY
@export var owner_system: StringName = OWNER_SYSTEM_COMBAT_ORIGIN_REGISTRY
@export var resolve_phase: StringName = PHASE_UNKNOWN
@export var space_type: StringName = SPACE_TYPE_UNKNOWN
@export var is_dynamic: bool = false

func normalize() -> void:
	if owner_system == StringName():
		owner_system = OWNER_SYSTEM_COMBAT_ORIGIN_REGISTRY
	if resolve_phase == StringName():
		resolve_phase = PHASE_UNKNOWN
	if space_type == StringName():
		space_type = SPACE_TYPE_UNKNOWN
	if is_machine_origin():
		parent_origin_id = StringName()
		transform_to_parent = Transform3D.IDENTITY
		resolved_transform_to_machine = Transform3D.IDENTITY
		space_type = SPACE_TYPE_MACHINE

func is_machine_origin() -> bool:
	return origin_id == ORIGIN_RL_BONE_ROOT

func has_declared_parent() -> bool:
	return parent_origin_id != StringName()

func is_valid_record() -> bool:
	if origin_id == StringName():
		return false
	if is_machine_origin():
		return parent_origin_id == StringName()
	return has_declared_parent()

func duplicate_record() -> Resource:
	var copied := duplicate(true)
	if copied != null:
		copied.normalize()
	return copied

func to_dictionary() -> Dictionary:
	return {
		"origin_id": origin_id,
		"parent_origin_id": parent_origin_id,
		"transform_to_parent_origin": transform_to_parent.origin,
		"transform_to_parent_basis": str(transform_to_parent.basis),
		"resolved_transform_to_machine_origin": resolved_transform_to_machine.origin,
		"resolved_transform_to_machine_basis": str(resolved_transform_to_machine.basis),
		"owner_system": owner_system,
		"resolve_phase": resolve_phase,
		"space_type": space_type,
		"is_dynamic": is_dynamic,
		"is_valid": is_valid_record(),
	}

func describe() -> String:
	return "%s parent=%s phase=%s type=%s dynamic=%s owner=%s parent_origin=%s resolved_origin=%s" % [
		String(origin_id),
		String(parent_origin_id),
		String(resolve_phase),
		String(space_type),
		str(is_dynamic),
		String(owner_system),
		str(transform_to_parent.origin),
		str(resolved_transform_to_machine.origin),
	]
