extends RefCounted
class_name CombatAnimationStationPreviewPresenter

const PlayerHumanoidRigScene: PackedScene = preload("res://scenes/player/player_humanoid_rig.tscn")
const PlayerEquippedItemPresenterScript = preload("res://runtime/player/player_equipped_item_presenter.gd")
const WeaponGripAnchorProviderScript = preload("res://runtime/player/weapon_grip_anchor_provider.gd")
const CharacterFrameResolverScript = preload("res://runtime/player/character_frame_resolver.gd")
const CombatAnimationDraftScript = preload("res://core/models/combat_animation_draft.gd")
const MaterialPipelineServiceScript = preload("res://services/material_pipeline_service.gd")
const ForgeServiceScript = preload("res://services/forge_service.gd")
const TestPrintMeshBuilderScript = preload("res://runtime/forge/test_print_mesh_builder.gd")
const CombatAnimationSessionStateScript = preload("res://core/models/combat_animation_session_state.gd")
const HandTargetConstraintSolverScript = preload("res://runtime/player/hand_target_constraint_solver.gd")
const DEFAULT_FORGE_RULES_RESOURCE: ForgeRulesDef = preload("res://core/defs/forge/forge_rules_default.tres")
const DEFAULT_FORGE_VIEW_TUNING_RESOURCE: ForgeViewTuningDef = preload("res://core/defs/forge/forge_view_tuning_default.tres")
const CombatAnimationMotionNodeScript = preload("res://core/models/combat_animation_motion_node.gd")
const CombatRuntimeClipScript = preload("res://core/models/combat_runtime_clip.gd")
const CombatAnimationWeaponFrameSolverScript = preload("res://runtime/combat/combat_animation_weapon_frame_solver.gd")
const CombatAnimationMotionNodeEditorScript = preload("res://runtime/combat/combat_animation_motion_node_editor.gd")
const CombatAnimationTrajectoryVolumeResolverScript = preload("res://core/resolvers/combat_animation_trajectory_volume_resolver.gd")
const CombatAnimationSpeedStateSamplerScript = preload("res://core/resolvers/combat_animation_speed_state_sampler.gd")
const CombatCollisionLegalityResolverScript = preload("res://runtime/combat/combat_collision_legality_resolver.gd")
const CombatOriginRecordScript = preload("res://core/models/combat_origin_record.gd")

const PREVIEW_ROOT_NAME := "CombatAnimationPreviewRoot3D"
const PREVIEW_CAMERA_NAME := "PreviewCamera3D"
const PREVIEW_ACTOR_NAME := "PreviewActor"
const PREVIEW_ACTOR_PIVOT_NAME := "PreviewActorPivot"
const PREVIEW_FLOOR_NAME := "PreviewFloor"
const TRAJECTORY_ROOT_NAME := "TrajectoryRoot"
const TRAJECTORY_MESH_NAME := "TrajectoryMesh"
const CONTROL_LINE_MESH_NAME := "ControlLineMesh"
const MARKER_ROOT_NAME := "TrajectoryMarkerRoot"
const PREVIEW_SKELETON_PATH := "JosieModel/Josie/Skeleton3D"
const PREVIEW_ROOT_BONE: StringName = &"RL_BoneRoot"
const SOLVED_REPLAY_ANCHOR_NODE_PATHS: Array[StringName] = [
	&"PrimaryGripGuide",
	&"SecondaryGripGuide",
	&"PrimaryGripAnchor",
	&"PrimaryGripAnchor/PrimaryGripBasisAnchor",
	&"SupportGripAnchor",
	&"SupportGripAnchor/SupportGripBasisAnchor",
]
const PREVIEW_TORSO_CHEST_BONE: StringName = &"CC_Base_Spine02"
const PREVIEW_HIP_BONE: StringName = &"CC_Base_Hip"
const PREVIEW_LEFT_CLAVICLE_BONE: StringName = &"CC_Base_L_Clavicle"
const PREVIEW_RIGHT_CLAVICLE_BONE: StringName = &"CC_Base_R_Clavicle"
const PREVIEW_LEFT_UPPERARM_BONE: StringName = &"CC_Base_L_Upperarm"
const PREVIEW_RIGHT_UPPERARM_BONE: StringName = &"CC_Base_R_Upperarm"
const PREVIEW_LEFT_FOREARM_BONE: StringName = &"CC_Base_L_Forearm"
const PREVIEW_RIGHT_FOREARM_BONE: StringName = &"CC_Base_R_Forearm"
const PREVIEW_LEFT_HAND_BONE: StringName = &"CC_Base_L_Hand"
const PREVIEW_RIGHT_HAND_BONE: StringName = &"CC_Base_R_Hand"
const PREVIEW_LEFT_INDEX1_BONE: StringName = &"CC_Base_L_Index1"
const PREVIEW_RIGHT_INDEX1_BONE: StringName = &"CC_Base_R_Index1"
const PREVIEW_LEFT_PINKY1_BONE: StringName = &"CC_Base_L_Pinky1"
const PREVIEW_RIGHT_PINKY1_BONE: StringName = &"CC_Base_R_Pinky1"
const AUTHORING_ROOT_FALLBACK_LOCAL_OFFSET := Vector3(0.0, 1.15, 0.0)
const SHOULDER_SPINE_CENTER_BLEND: float = 0.5
const UNARMED_PROXY_MIN_HALF_LENGTH_METERS := 0.11
const UNARMED_PROXY_MAX_HALF_LENGTH_METERS := 0.18

const ONION_SKIN_MESH_NAME := "OnionSkinRoot"
const SPHERE_VIZ_MESH_NAME := "SphereVisualizationMesh"
const PREVIEW_COLLISION_DEBUG_ROOT_NAME := "PreviewCollisionDebugRoot"
const PREVIEW_WEAPON_BOUNDS_DEBUG_NAME := "WeaponBoundsDebug"
const PREVIEW_GRIP_CONTACT_DEBUG_ROOT_NAME := "GripContactDebugRoot"
const PREVIEW_PROXY_DEBUG_ROOT_NAME := "WeaponProxyDebugRoot"
const PREVIEW_PROXY_DEBUG_MARKER_PREFIX := "WeaponProxyDebug_"
const PREVIEW_GRIP_CONTACT_DEBUG_PREFIX := "GripContactDebug_"
const PREVIEW_POSE_MODE_META := "preview_pose_mode"
const PREVIEW_POSE_MODE_HAND_AUTHORED: StringName = &"hand_authored"
const PREVIEW_POSE_MODE_NONCOMBAT_STOW: StringName = &"noncombat_stow"
const DEBUGGER_VIEW_ENABLED_META: StringName = &"debugger_view_enabled"
const CAMERA_STATE_READY_META := "camera_state_ready"
const CAMERA_FOCUS_POINT_META := "camera_focus_point"
const CAMERA_DISTANCE_META := "camera_distance"
const CAMERA_ORBIT_YAW_META := "camera_orbit_yaw_degrees"
const CAMERA_ORBIT_PITCH_META := "camera_orbit_pitch_degrees"
const DEFAULT_CAMERA_OFFSET := Vector3(1.15, 0.7, 2.35)
const CAMERA_DEFAULT_DISTANCE := 2.7092434
const CAMERA_MIN_DISTANCE := 0.95
const CAMERA_MAX_DISTANCE := 10.1596626
const CAMERA_MIN_PITCH_DEGREES := -55.0
const CAMERA_MAX_PITCH_DEGREES := 70.0
const CAMERA_ORBIT_SENSITIVITY := 0.35
const CAMERA_ZOOM_STEP := 0.12
const CAMERA_FLOOR_HEIGHT := 0.0
const CAMERA_FLOOR_CLEARANCE := 0.08
const WEAPON_ROTATION_GIZMO_HANDLE_DISTANCE := 0.22
const UPPERARM_ROLL_PICK_RADIUS_PIXELS := 26.0
const UPPERARM_ROLL_GIZMO_MIN_RADIUS_METERS := 0.075
const UPPERARM_ROLL_GIZMO_MAX_RADIUS_METERS := 0.18
const CONTROL_MARKER_SIZE_MULTIPLIER := 2.8
const WEAPON_ROLL_MARKER_EXTRA_SCALE := 0.14285715
const BEZIER_CONTROL_MARKER_SIZE_METERS := 0.032 * CONTROL_MARKER_SIZE_MULTIPLIER
const STOW_ANCHOR_MARKER_COLOR := Color(1.0, 0.06, 0.78, 0.88)
const STOW_UPPER_BACK_OFFSET_METERS := 0.18
const STOW_HIP_SIDE_OFFSET_METERS := 0.23
const STOW_LOWER_BACK_OFFSET_METERS := 0.20
const CURVE_HANDLE_VISUAL_MIN_LENGTH_METERS := 0.0001
const SEGMENT_LEGALITY_EPSILON_METERS := 0.001
const AUTHORING_PREVIEW_DOMINANT_SEAT_LOCK_STRENGTH := 1.0
const AUTHORING_DRAG_DOMINANT_SEAT_LOCK_STRENGTH := 1.0
const AUTHORING_PREVIEW_SUPPORT_COUPLING_STRENGTH := 1.0
const AUTHORING_DRAG_SUPPORT_COUPLING_STRENGTH := 0.45
const SUPPORT_COUPLING_MAX_ROTATION_DEGREES := 150.0
const TWO_HAND_PREVIEW_DOMINANT_CONTACT_WEIGHT := 1.0
const TWO_HAND_PREVIEW_SUPPORT_CONTACT_WEIGHT := 1.0
const TWO_HAND_DRAG_DOMINANT_CONTACT_WEIGHT := 0.65
const TWO_HAND_DRAG_SUPPORT_CONTACT_WEIGHT := 0.35
const AUTHORING_CONTACT_TRANSLATION_STRENGTH := 0.34
const AUTHORING_CONTACT_ROTATION_STRENGTH := 0.42
const AUTHORING_CONTACT_MAX_TRANSLATION_METERS := 0.42
const AUTHORING_CONTACT_MAX_ROTATION_DEGREES := 72.0
const AUTHORING_CONTACT_SEAT_LOCK_STRENGTH := 1.0
const PLAYBACK_CONTACT_TRANSLATION_STRENGTH := 0.82
const PLAYBACK_CONTACT_ROTATION_STRENGTH := 0.78
const PLAYBACK_CONTACT_MAX_TRANSLATION_METERS := 0.28
const PLAYBACK_CONTACT_MAX_ROTATION_DEGREES := 54.0
const AUTHORING_CONTACT_TETHER_REACH_MARGIN_METERS := 0.015
const AUTHORING_CONTACT_TETHER_SEAT_MARGIN_METERS := 0.025
const TRAJECTORY_VOLUME_MIN_REACH_RATIO_OF_MAX := 0.0
const AUTHORING_BODY_SEPARATION_ITERATIONS := 4
const AUTHORING_BODY_SEPARATION_MAX_STEP_METERS := 0.20
const AUTHORING_BODY_CONTACT_COUPLED_ITERATIONS := 3
const AUTHORING_BODY_CONTACT_FINAL_SEPARATION_ITERATIONS := 8
const AUTHORING_BODY_CONTACT_SETTLE_EPSILON_METERS := 0.0015
const AUTHORING_BODY_CONTACT_GRIP_EPSILON_METERS := 0.02
const AUTHORING_BODY_CONTACT_GRIP_STALL_EPSILON_METERS := 0.0005

var motion_node_editor: CombatAnimationMotionNodeEditor = CombatAnimationMotionNodeEditorScript.new()
const AUTHORING_CONTACT_TETHER_ITERATIONS := 4
const AUTHORING_CONTACT_TETHER_MODE_TRANSLATE: StringName = &"translate"
const AUTHORING_CONTACT_TETHER_MODE_TIP_PIVOT: StringName = &"tip_pivot"
const PREVIEW_ACTIVE_SLOT_ID_META := "preview_dominant_slot_id"
const PREVIEW_PRIMARY_GRIP_SEAT_LOCAL_META := "preview_primary_grip_seat_local"
const PREVIEW_PRIMARY_GRIP_SEAT_ORIGIN_META := "preview_primary_grip_seat_origin_id"
const PREVIEW_SUPPORT_GRIP_SEAT_LOCAL_META := "preview_support_grip_seat_local"
const PREVIEW_SUPPORT_GRIP_SEAT_ORIGIN_META := "preview_support_grip_seat_origin_id"
const PREVIEW_SECONDARY_GRIP_SEAT_AUTHORED_META := "preview_secondary_grip_seat_authored"
const PREVIEW_HAND_MOUNT_LOCAL_TRANSFORM_META := "hand_mount_local_transform"
const PREVIEW_HAND_MOUNT_LOCAL_TRANSFORM_ORIGIN_META := "hand_mount_local_transform_origin_id"

var material_pipeline_service = MaterialPipelineServiceScript.new()
var forge_service: ForgeService = ForgeServiceScript.new(DEFAULT_FORGE_RULES_RESOURCE)
var held_item_mesh_builder: TestPrintMeshBuilder = TestPrintMeshBuilderScript.new()
var equipped_item_presenter = PlayerEquippedItemPresenterScript.new()
var weapon_grip_anchor_provider = WeaponGripAnchorProviderScript.new()
var hand_target_constraint_solver = HandTargetConstraintSolverScript.new()
var character_frame_resolver = CharacterFrameResolverScript.new()
var weapon_frame_solver = CombatAnimationWeaponFrameSolverScript.new()
var trajectory_volume_resolver = CombatAnimationTrajectoryVolumeResolverScript.new()
var speed_state_sampler = CombatAnimationSpeedStateSamplerScript.new()
var collision_legality_resolver = CombatCollisionLegalityResolverScript.new()
var material_lookup_cache: Dictionary = {}
var preview_dominant_slot_id: StringName = &"hand_right"
var preview_default_two_hand: bool = false

func configure_preview_hand_setup(dominant_slot_id: StringName, default_two_hand: bool) -> void:
	preview_dominant_slot_id = _normalize_preview_slot_id(dominant_slot_id)
	preview_default_two_hand = default_two_hand

func set_debugger_view_enabled(preview_subviewport: SubViewport, enabled: bool) -> void:
	var preview_root: Node3D = _get_preview_root(preview_subviewport)
	if preview_root == null:
		return
	var state: Dictionary = {
		"preview_root": preview_root,
		"actor_pivot": preview_root.get_node_or_null(PREVIEW_ACTOR_PIVOT_NAME),
	}
	_apply_debugger_view_visibility(state, enabled)

func apply_runtime_authored_weapon_pose(
	actor: Node3D,
	held_item: Node3D,
	selected_motion_node: CombatAnimationMotionNode,
	playback_state: Dictionary = {},
	dominant_slot_id: StringName = &"hand_right",
	default_two_hand: bool = false
) -> Dictionary:
	var resolved_playback_state: Dictionary = playback_state.duplicate(true)
	if actor == null or held_item == null or selected_motion_node == null:
		return resolved_playback_state
	var previous_slot_id: StringName = preview_dominant_slot_id
	var previous_default_two_hand: bool = preview_default_two_hand
	configure_preview_hand_setup(dominant_slot_id, default_two_hand)

	var trajectory_root := Node3D.new()
	var local_tip: Vector3 = _get_origin_tracked_vector3_meta(
		held_item,
		"weapon_tip_local",
		"weapon_tip_origin_id",
		Vector3.ZERO,
		CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
	)
	var local_pommel: Vector3 = _get_origin_tracked_vector3_meta(
		held_item,
		"weapon_pommel_local",
		"weapon_pommel_origin_id",
		Vector3.ZERO,
		CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
	)
	if local_tip.is_equal_approx(local_pommel):
		configure_preview_hand_setup(previous_slot_id, previous_default_two_hand)
		return resolved_playback_state
	trajectory_root.top_level = true
	actor.add_child(trajectory_root)
	trajectory_root.global_transform = _resolve_trajectory_authoring_transform(actor)

	_apply_preview_motion_grip_state(held_item, selected_motion_node, playback_state, actor)
	_sync_preview_contact_axis_override(held_item, playback_state, trajectory_root)
	var authored_tip_local: Vector3 = _get_origin_tracked_vector3_state(
		playback_state,
		"tip_position_local",
		"tip_position_origin_id",
		selected_motion_node.tip_position_local,
		selected_motion_node.tip_position_origin_id
	)
	var authored_pommel_local: Vector3 = _get_origin_tracked_vector3_state(
		playback_state,
		"pommel_position_local",
		"pommel_position_origin_id",
		selected_motion_node.pommel_position_local,
		selected_motion_node.pommel_position_origin_id
	)
	var resolved_weapon_orientation_degrees: Vector3 = playback_state.get(
		"weapon_orientation_degrees",
		_resolve_motion_node_weapon_orientation_degrees(selected_motion_node)
	) as Vector3
	var authored_tip_world_for_pose: Vector3 = trajectory_root.to_global(authored_tip_local)
	var authored_pommel_world_for_pose: Vector3 = trajectory_root.to_global(authored_pommel_local)
	var authored_pose_transform: Transform3D = held_item.global_transform
	if authored_tip_world_for_pose.distance_to(authored_pommel_world_for_pose) > SEGMENT_LEGALITY_EPSILON_METERS:
		authored_pose_transform = _solve_weapon_segment_transform(
			held_item,
			trajectory_root,
			selected_motion_node,
			local_tip,
			local_pommel,
			authored_tip_world_for_pose,
			authored_pommel_world_for_pose,
			resolved_weapon_orientation_degrees
		)
	_apply_preview_upper_body_authoring_state(
		actor,
		held_item,
		selected_motion_node,
		playback_state,
		authored_tip_world_for_pose,
		authored_pommel_world_for_pose,
		authored_pose_transform,
		true
	)
	_apply_preview_actor_upper_body_pose_now(actor)
	var constrained_segment_state: Dictionary = _resolve_constrained_authored_segment_local(
		actor,
		held_item,
		trajectory_root,
		selected_motion_node,
		authored_tip_local,
		authored_pommel_local
	)
	authored_tip_local = _get_origin_tracked_vector3_state(
		constrained_segment_state,
		"tip_position_local",
		"tip_position_origin_id",
		authored_tip_local,
		_resolve_origin_tracked_state_origin_id(playback_state, "tip_position_origin_id", selected_motion_node.tip_position_origin_id)
	)
	authored_pommel_local = _get_origin_tracked_vector3_state(
		constrained_segment_state,
		"pommel_position_local",
		"pommel_position_origin_id",
		authored_pommel_local,
		_resolve_origin_tracked_state_origin_id(playback_state, "pommel_position_origin_id", selected_motion_node.pommel_position_origin_id)
	)
	var solved_transform: Transform3D
	if bool(constrained_segment_state.get("has_solved_transform", false)):
		solved_transform = constrained_segment_state.get("solved_transform", Transform3D.IDENTITY) as Transform3D
	else:
		var authored_tip_world: Vector3 = trajectory_root.to_global(authored_tip_local)
		var authored_pommel_world: Vector3 = trajectory_root.to_global(authored_pommel_local)
		solved_transform = _solve_weapon_segment_transform(
			held_item,
			trajectory_root,
			selected_motion_node,
			local_tip,
			local_pommel,
			authored_tip_world,
			authored_pommel_world,
			resolved_weapon_orientation_degrees
		)

	held_item.global_transform = solved_transform
	_apply_preview_resolved_grip_state(held_item)

	var solved_tip_world: Vector3 = held_item.to_global(local_tip)
	var solved_pommel_world: Vector3 = held_item.to_global(local_pommel)
	resolved_playback_state["active"] = bool(resolved_playback_state.get("active", true))
	_set_tip_pommel_position_state(
		resolved_playback_state,
		trajectory_root.to_local(solved_tip_world),
		trajectory_root.to_local(solved_pommel_world),
		CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING
	)
	resolved_playback_state["weapon_orientation_degrees"] = resolved_weapon_orientation_degrees
	_apply_preview_upper_body_authoring_state(actor, held_item, selected_motion_node, resolved_playback_state)
	actor.remove_child(trajectory_root)
	trajectory_root.queue_free()
	configure_preview_hand_setup(previous_slot_id, previous_default_two_hand)
	return resolved_playback_state

func _append_latency_trace_elapsed(trace: Array, label: String, start_usec: int) -> int:
	var now_usec: int = Time.get_ticks_usec()
	trace.append("%s_ms=%.3f" % [label, float(now_usec - start_usec) / 1000.0])
	return now_usec

func refresh_preview(
	preview_container: SubViewportContainer,
	preview_subviewport: SubViewport,
	active_wip: CraftedItemWIP,
	active_draft: Resource,
	selected_node_index: int,
	active_focus: StringName = &"tip",
	baked_profile: BakedProfile = null,
	playback_state: Dictionary = {},
	live_motion_node_override: CombatAnimationMotionNode = null
) -> void:
	var state: Dictionary = _ensure_preview_nodes(preview_container, preview_subviewport)
	_sync_preview_size(preview_container, preview_subviewport)
	var effective_motion_node_chain: Array = _build_effective_motion_node_chain(active_draft, selected_node_index, live_motion_node_override)
	var selected_motion_node: CombatAnimationMotionNode = _resolve_selected_motion_node(effective_motion_node_chain, selected_node_index)
	var visible_motion_node_chain: Array = _build_visible_motion_node_chain(active_draft, effective_motion_node_chain)
	var visible_selected_node_index: int = _resolve_visible_selected_motion_node_index(active_draft, selected_node_index, visible_motion_node_chain.size())
	var playback_motion_node: CombatAnimationMotionNode = _build_effective_preview_motion_node(selected_motion_node, playback_state)
	_refresh_actor_and_weapon(state, active_wip, playback_motion_node, active_draft)
	_prepare_trajectory_root_for_authoring(state)
	var open_mount_seed: Dictionary = playback_state.get("open_mount_seed", {}) as Dictionary
	if active_wip != null and not bool(playback_state.get("active", false)):
		if open_mount_seed.is_empty():
			open_mount_seed = resolve_preview_hand_mounted_motion_seed(
				preview_subviewport,
				{},
				active_wip.wip_id
			)
	var use_open_mount_baseline: bool = (
		not _is_noncombat_idle_draft(active_draft)
		and _motion_node_matches_hand_mounted_seed(playback_motion_node, open_mount_seed)
	)
	var dominant_seat_lock_strength: float = (
		AUTHORING_DRAG_DOMINANT_SEAT_LOCK_STRENGTH
		if live_motion_node_override != null
		else AUTHORING_PREVIEW_DOMINANT_SEAT_LOCK_STRENGTH
	)
	var resolved_playback_state: Dictionary = (
		_apply_preview_open_mount_pose(state, playback_motion_node, playback_state, true)
		if use_open_mount_baseline
		else _apply_authored_weapon_pose(
			state,
			playback_motion_node,
			playback_state,
			true,
			dominant_seat_lock_strength,
			true,
			active_draft,
			live_motion_node_override != null
		)
	)
	var debugger_view_enabled: bool = _resolve_debugger_view_enabled(state, resolved_playback_state)
	var display_motion_node_chain: Array = _build_resolved_display_motion_node_chain(
		visible_motion_node_chain,
		visible_selected_node_index,
		resolved_playback_state
	)
	if bool(resolved_playback_state.get("authoring_drag_budgeted_visuals", false)):
		_refresh_drag_budgeted_visuals(
			state,
			display_motion_node_chain,
			visible_selected_node_index,
			active_focus,
			active_draft
		)
	else:
		var speed_state_config: Dictionary = _build_speed_state_config(active_draft)
		resolved_playback_state["trajectory_static_visual_signature"] = _build_trajectory_static_visual_signature(
			visible_motion_node_chain,
			speed_state_config,
			active_draft,
			bool(resolved_playback_state.get("authoring_drag_lightweight", false))
		)
		_refresh_trajectory_visuals(
			state,
			display_motion_node_chain,
			visible_selected_node_index,
			active_focus,
			resolved_playback_state,
			speed_state_config,
			active_draft
		)
		_refresh_weapon_and_sphere_visuals(state, display_motion_node_chain, visible_selected_node_index, active_focus, baked_profile)
	if not bool(resolved_playback_state.get("authoring_drag_active", false)):
		_refresh_collision_debug_visuals(state)
	else:
		_apply_debugger_view_visibility(state, debugger_view_enabled)

func sync_preview_pose(
	preview_container: SubViewportContainer,
	preview_subviewport: SubViewport,
	active_wip: CraftedItemWIP,
	active_draft: Resource,
	selected_node_index: int,
	playback_state: Dictionary = {},
	live_motion_node_override: CombatAnimationMotionNode = null,
	active_focus: StringName = &"tip",
	baked_profile: BakedProfile = null
) -> void:
	var trace_enabled: bool = bool(get_meta("trace_preview_latency", false))
	var trace: Array = []
	var trace_step_usec: int = Time.get_ticks_usec()
	var state: Dictionary = _ensure_preview_nodes(preview_container, preview_subviewport)
	_sync_preview_size(preview_container, preview_subviewport)
	if trace_enabled:
		trace_step_usec = _append_latency_trace_elapsed(trace, "ensure_nodes_and_size", trace_step_usec)
	var effective_motion_node_chain: Array = _build_effective_motion_node_chain(active_draft, selected_node_index, live_motion_node_override)
	var selected_motion_node: CombatAnimationMotionNode = _resolve_selected_motion_node(effective_motion_node_chain, selected_node_index)
	var visible_motion_node_chain: Array = _build_visible_motion_node_chain(active_draft, effective_motion_node_chain)
	var visible_selected_node_index: int = _resolve_visible_selected_motion_node_index(active_draft, selected_node_index, visible_motion_node_chain.size())
	var playback_motion_node: CombatAnimationMotionNode = _build_effective_preview_motion_node(selected_motion_node, playback_state)
	if trace_enabled:
		trace_step_usec = _append_latency_trace_elapsed(trace, "build_motion_chain", trace_step_usec)
	_refresh_actor_and_weapon(state, active_wip, playback_motion_node, active_draft)
	if trace_enabled:
		trace_step_usec = _append_latency_trace_elapsed(trace, "refresh_actor_and_weapon", trace_step_usec)
	_prepare_trajectory_root_for_authoring(state)
	if trace_enabled:
		trace_step_usec = _append_latency_trace_elapsed(trace, "prepare_trajectory_root", trace_step_usec)
	var open_mount_seed: Dictionary = playback_state.get("open_mount_seed", {}) as Dictionary
	if active_wip != null and not bool(playback_state.get("active", false)):
		if open_mount_seed.is_empty():
			open_mount_seed = resolve_preview_hand_mounted_motion_seed(
				preview_subviewport,
				{},
				active_wip.wip_id
			)
	if trace_enabled:
		trace_step_usec = _append_latency_trace_elapsed(trace, "resolve_open_mount_seed", trace_step_usec)
	var use_open_mount_baseline: bool = (
		not _is_noncombat_idle_draft(active_draft)
		and _motion_node_matches_hand_mounted_seed(playback_motion_node, open_mount_seed)
	)
	var dominant_seat_lock_strength: float = (
		AUTHORING_DRAG_DOMINANT_SEAT_LOCK_STRENGTH
		if live_motion_node_override != null
		else AUTHORING_PREVIEW_DOMINANT_SEAT_LOCK_STRENGTH
	)
	var resolved_playback_state: Dictionary = (
		_apply_preview_open_mount_pose(state, playback_motion_node, playback_state, false)
		if use_open_mount_baseline
		else _apply_authored_weapon_pose(
			state,
			playback_motion_node,
			playback_state,
			false,
			dominant_seat_lock_strength,
			true,
			active_draft,
			live_motion_node_override != null
		)
	)
	if trace_enabled:
		trace_step_usec = _append_latency_trace_elapsed(trace, "apply_authoring_pose", trace_step_usec)
	var debugger_view_enabled: bool = _resolve_debugger_view_enabled(state, resolved_playback_state)
	var display_motion_node_chain: Array = _build_resolved_display_motion_node_chain(
		visible_motion_node_chain,
		visible_selected_node_index,
		resolved_playback_state
	)
	if trace_enabled:
		trace_step_usec = _append_latency_trace_elapsed(trace, "build_display_chain", trace_step_usec)
	if bool(resolved_playback_state.get("authoring_drag_budgeted_visuals", false)):
		_refresh_drag_budgeted_visuals(
			state,
			display_motion_node_chain,
			visible_selected_node_index,
			active_focus,
			active_draft
		)
		if trace_enabled:
			trace_step_usec = _append_latency_trace_elapsed(trace, "refresh_drag_budgeted_visuals", trace_step_usec)
	else:
		var speed_state_config: Dictionary = _build_speed_state_config(active_draft)
		resolved_playback_state["trajectory_static_visual_signature"] = _build_trajectory_static_visual_signature(
			visible_motion_node_chain,
			speed_state_config,
			active_draft,
			bool(resolved_playback_state.get("authoring_drag_lightweight", false))
		)
		_refresh_trajectory_visuals(
			state,
			display_motion_node_chain,
			visible_selected_node_index,
			active_focus,
			resolved_playback_state,
			speed_state_config,
			active_draft
		)
		if trace_enabled:
			trace_step_usec = _append_latency_trace_elapsed(trace, "refresh_trajectory_visuals", trace_step_usec)
		_refresh_weapon_and_sphere_visuals(state, display_motion_node_chain, visible_selected_node_index, active_focus, baked_profile)
		if trace_enabled:
			trace_step_usec = _append_latency_trace_elapsed(trace, "refresh_weapon_and_sphere_visuals", trace_step_usec)
	if not bool(resolved_playback_state.get("authoring_drag_active", false)):
		_refresh_collision_debug_visuals(state)
		if trace_enabled:
			trace_step_usec = _append_latency_trace_elapsed(trace, "refresh_collision_debug_visuals", trace_step_usec)
	else:
		_apply_debugger_view_visibility(state, debugger_view_enabled)
		if trace_enabled:
			trace_step_usec = _append_latency_trace_elapsed(trace, "apply_debugger_view_visibility", trace_step_usec)
	if trace_enabled:
		set_meta("last_sync_preview_pose_latency_trace", trace)

func sync_playback_pose(
	preview_container: SubViewportContainer,
	preview_subviewport: SubViewport,
	active_wip: CraftedItemWIP,
	active_draft: Resource,
	selected_node_index: int,
	playback_state: Dictionary = {},
	live_motion_node_override: CombatAnimationMotionNode = null
) -> void:
	var state: Dictionary = _ensure_preview_nodes(preview_container, preview_subviewport)
	_sync_preview_size(preview_container, preview_subviewport)
	if bool(playback_state.get("runtime_clip_playback", false)) and bool(playback_state.get("solved_replay_available", false)):
		var fast_playback_state: Dictionary = _apply_solved_runtime_clip_preview_pose(state, active_wip, playback_state)
		if bool(fast_playback_state.get("solved_replay_applied", false)):
			_resolve_debugger_view_enabled(state, fast_playback_state)
			_refresh_live_playback_markers(state, fast_playback_state)
			return
	var effective_motion_node_chain: Array = _build_effective_motion_node_chain(active_draft, selected_node_index, live_motion_node_override)
	var selected_motion_node: CombatAnimationMotionNode = _resolve_selected_motion_node(effective_motion_node_chain, selected_node_index)
	var playback_motion_node: CombatAnimationMotionNode = _build_effective_preview_motion_node(selected_motion_node, playback_state)
	_refresh_actor_and_weapon(state, active_wip, playback_motion_node, active_draft)
	_prepare_trajectory_root_for_authoring(state)
	var resolved_playback_state: Dictionary = (
		_apply_runtime_clip_preview_pose(state, playback_motion_node, playback_state, active_draft)
		if bool(playback_state.get("runtime_clip_playback", false))
		else _apply_authored_weapon_pose(
			state,
			playback_motion_node,
			playback_state,
			false,
			AUTHORING_PREVIEW_DOMINANT_SEAT_LOCK_STRENGTH,
			false,
			active_draft,
			live_motion_node_override != null
		)
	)
	_resolve_debugger_view_enabled(state, resolved_playback_state)
	_refresh_live_playback_markers(state, resolved_playback_state)

func bake_runtime_clip_upper_body_pose_track(
	preview_container: SubViewportContainer,
	preview_subviewport: SubViewport,
	active_wip: CraftedItemWIP,
	active_draft: Resource,
	runtime_clip,
	selected_node_index: int = 0
) -> Dictionary:
	var result := {
		"baked": false,
		"reason": "",
		"frame_count": 0,
		"bone_count": 0,
		"anchor_count": 0,
		"solved_replay_track": false,
		"primary_anchor_to_anatomical_grip_max_meters": -1.0,
		"primary_anchor_to_anatomical_grip_avg_meters": -1.0,
		"primary_anchor_to_anatomical_grip_max_frame": -1,
	}
	if preview_container == null or preview_subviewport == null:
		result["reason"] = "missing_preview"
		return result
	if active_wip == null or active_draft == null or runtime_clip == null:
		result["reason"] = "missing_source"
		return result
	if _is_noncombat_idle_draft(active_draft):
		result["reason"] = "noncombat_stow_does_not_use_hand_pose"
		return result
	if not runtime_clip.has_method("get_frame_count"):
		result["reason"] = "runtime_clip_has_no_frames"
		return result
	var frame_count: int = int(runtime_clip.call("get_frame_count"))
	result["frame_count"] = frame_count
	if frame_count <= 0:
		result["reason"] = "runtime_clip_empty"
		return result
	var clip_motion_node_chain: Array = runtime_clip.get("motion_node_chain") as Array
	if clip_motion_node_chain.is_empty():
		result["reason"] = "runtime_clip_has_no_motion_nodes"
		return result
	var state: Dictionary = _ensure_preview_nodes(preview_container, preview_subviewport)
	_sync_preview_size(preview_container, preview_subviewport)
	var base_node_index: int = clampi(selected_node_index, 0, clip_motion_node_chain.size() - 1)
	var base_motion_node: CombatAnimationMotionNode = clip_motion_node_chain[base_node_index] as CombatAnimationMotionNode
	if base_motion_node == null:
		base_motion_node = clip_motion_node_chain[0] as CombatAnimationMotionNode
	if base_motion_node == null:
		result["reason"] = "runtime_clip_has_invalid_motion_node"
		return result
	_refresh_actor_and_weapon(state, active_wip, base_motion_node, active_draft)
	_prepare_trajectory_root_for_authoring(state)
	var preview_root: Node3D = state.get("preview_root", null) as Node3D
	var actor_pivot: Node3D = state.get("actor_pivot", null) as Node3D
	var actor: Node3D = actor_pivot.get_node_or_null(PREVIEW_ACTOR_NAME) as Node3D if actor_pivot != null else null
	if preview_root == null or actor == null:
		result["reason"] = "missing_preview_actor"
		return result
	var held_item: Node3D = _get_node_meta_or_default(preview_root, "preview_held_item", null) as Node3D
	if held_item == null or not is_instance_valid(held_item):
		result["reason"] = "missing_preview_weapon"
		return result
	if not actor.has_method("capture_runtime_upper_body_pose_frame"):
		result["reason"] = "actor_cannot_capture_upper_body_pose"
		return result
	var requested_bone_names: Array = []
	if actor.has_method("get_runtime_upper_body_pose_bone_names"):
		requested_bone_names = actor.call("get_runtime_upper_body_pose_bone_names") as Array
	var resolved_bone_names: Array[StringName] = []
	var captured_position_frames: Array = []
	var captured_rotation_frames: Array = []
	var captured_scale_frames: Array = []
	var solved_weapon_positions := PackedVector3Array()
	var solved_weapon_rotations := PackedVector4Array()
	var solved_weapon_scales := PackedVector3Array()
	var solved_anchor_paths: Array[StringName] = _resolve_solved_replay_anchor_node_paths(held_item)
	var solved_anchor_position_frames: Array = []
	var solved_anchor_rotation_frames: Array = []
	var solved_anchor_scale_frames: Array = []
	var solved_frame_available: Array = []
	var primary_anchor_to_anatomical_grip_max: float = 0.0
	var primary_anchor_to_anatomical_grip_sum: float = 0.0
	var primary_anchor_to_anatomical_grip_count: int = 0
	var primary_anchor_to_anatomical_grip_max_frame: int = -1
	for frame_index: int in range(frame_count):
		var frame_motion_node: CombatAnimationMotionNode = _build_runtime_clip_frame_motion_node(
			runtime_clip,
			frame_index,
			base_motion_node
		)
		var playback_state: Dictionary = _build_runtime_clip_frame_playback_state(
			runtime_clip,
			frame_index,
			frame_motion_node
		)
		playback_state["runtime_clip_playback"] = true
		_apply_runtime_clip_preview_pose(state, frame_motion_node, playback_state, active_draft)
		var frame_capture: Dictionary = actor.call(
			"capture_runtime_upper_body_pose_frame",
			requested_bone_names
		) as Dictionary
		var captured_names: Array = frame_capture.get("bone_names", []) as Array
		var captured_positions: PackedVector3Array = frame_capture.get("pose_positions", PackedVector3Array()) as PackedVector3Array
		var captured_rotations: PackedVector4Array = frame_capture.get("pose_rotations", PackedVector4Array()) as PackedVector4Array
		var captured_scales: PackedVector3Array = frame_capture.get("pose_scales", PackedVector3Array()) as PackedVector3Array
		if captured_positions.is_empty() or captured_rotations.is_empty() or captured_scales.is_empty():
			result["reason"] = "empty_upper_body_capture"
			return result
		if frame_index == 0:
			resolved_bone_names.clear()
			for bone_name_variant: Variant in captured_names:
				resolved_bone_names.append(StringName(bone_name_variant))
			requested_bone_names = resolved_bone_names.duplicate()
		if (
			captured_positions.size() != resolved_bone_names.size()
			or captured_rotations.size() != resolved_bone_names.size()
			or captured_scales.size() != resolved_bone_names.size()
		):
			result["reason"] = "upper_body_capture_size_mismatch"
			return result
		var reference_transform: Transform3D = _resolve_trajectory_authoring_transform(actor)
		var weapon_reference_transform: Transform3D = reference_transform.affine_inverse() * held_item.global_transform
		var anchor_capture: Dictionary = _capture_solved_replay_anchor_frame(held_item, solved_anchor_paths)
		var primary_anchor: Node3D = weapon_grip_anchor_provider.get_primary_grip_anchor(held_item)
		if primary_anchor != null and actor.has_method("resolve_hand_grip_alignment_world_position"):
			var anatomical_grip_world: Vector3 = actor.call(
				"resolve_hand_grip_alignment_world_position",
				_resolve_preview_dominant_slot_id()
			) as Vector3
			if anatomical_grip_world.length_squared() > 0.000001:
				var anchor_error_meters: float = primary_anchor.global_position.distance_to(anatomical_grip_world)
				primary_anchor_to_anatomical_grip_sum += anchor_error_meters
				primary_anchor_to_anatomical_grip_count += 1
				if anchor_error_meters > primary_anchor_to_anatomical_grip_max:
					primary_anchor_to_anatomical_grip_max = anchor_error_meters
					primary_anchor_to_anatomical_grip_max_frame = frame_index
		var anchor_positions: PackedVector3Array = anchor_capture.get("positions", PackedVector3Array()) as PackedVector3Array
		var anchor_rotations: PackedVector4Array = anchor_capture.get("rotations", PackedVector4Array()) as PackedVector4Array
		var anchor_scales: PackedVector3Array = anchor_capture.get("scales", PackedVector3Array()) as PackedVector3Array
		if (
			anchor_positions.size() != solved_anchor_paths.size()
			or anchor_rotations.size() != solved_anchor_paths.size()
			or anchor_scales.size() != solved_anchor_paths.size()
		):
			result["reason"] = "solved_anchor_capture_size_mismatch"
			return result
		captured_position_frames.append(captured_positions)
		captured_rotation_frames.append(captured_rotations)
		captured_scale_frames.append(captured_scales)
		solved_weapon_positions.append(weapon_reference_transform.origin)
		solved_weapon_rotations.append(_pack_quaternion(weapon_reference_transform.basis.orthonormalized().get_rotation_quaternion()))
		solved_weapon_scales.append(weapon_reference_transform.basis.get_scale())
		solved_anchor_position_frames.append(anchor_positions)
		solved_anchor_rotation_frames.append(anchor_rotations)
		solved_anchor_scale_frames.append(anchor_scales)
		solved_frame_available.append(true)
	runtime_clip.set("baked_upper_body_bone_names", resolved_bone_names)
	runtime_clip.set("baked_upper_body_bone_pose_rotations", captured_rotation_frames)
	runtime_clip.set(
		"upper_body_pose_track_source",
		CombatRuntimeClipScript.UPPER_BODY_POSE_TRACK_SOURCE_SKILL_CRAFTER_AUTHORED_POSE
	)
	runtime_clip.set("solved_replay_track_source", CombatRuntimeClipScript.SOLVED_REPLAY_TRACK_SOURCE_SKILL_CRAFTER_F_PLAYBACK)
	runtime_clip.set("solved_replay_reference_bone_name", PREVIEW_ROOT_BONE)
	runtime_clip.set("solved_replay_reference_origin_id", CombatOriginRecordScript.ORIGIN_SOLVED_REPLAY_REFERENCE)
	runtime_clip.set("baked_solved_weapon_reference_origin_id", CombatOriginRecordScript.ORIGIN_SOLVED_REPLAY_REFERENCE)
	runtime_clip.set("baked_solved_anchor_origin_id", CombatOriginRecordScript.ORIGIN_WEAPON_ROOT)
	runtime_clip.set("baked_solved_replay_frame_available", solved_frame_available)
	runtime_clip.set("baked_solved_upper_body_bone_names", resolved_bone_names)
	runtime_clip.set("baked_solved_upper_body_pose_positions", captured_position_frames)
	runtime_clip.set("baked_solved_upper_body_pose_rotations", captured_rotation_frames)
	runtime_clip.set("baked_solved_upper_body_pose_scales", captured_scale_frames)
	runtime_clip.set("baked_solved_weapon_positions_reference_local", solved_weapon_positions)
	runtime_clip.set("baked_solved_weapon_rotations_reference_local", solved_weapon_rotations)
	runtime_clip.set("baked_solved_weapon_scales_reference_local", solved_weapon_scales)
	runtime_clip.set("baked_solved_anchor_node_paths", solved_anchor_paths)
	runtime_clip.set("baked_solved_anchor_positions_weapon_local", solved_anchor_position_frames)
	runtime_clip.set("baked_solved_anchor_rotations_weapon_local", solved_anchor_rotation_frames)
	runtime_clip.set("baked_solved_anchor_scales_weapon_local", solved_anchor_scale_frames)
	if runtime_clip.has_method("normalize"):
		runtime_clip.call("normalize")
	result["baked"] = not resolved_bone_names.is_empty() and captured_rotation_frames.size() == frame_count
	result["solved_replay_track"] = runtime_clip.has_method("has_solved_replay_track") and bool(runtime_clip.call("has_solved_replay_track"))
	result["bone_count"] = resolved_bone_names.size()
	result["anchor_count"] = solved_anchor_paths.size()
	if primary_anchor_to_anatomical_grip_count > 0:
		result["primary_anchor_to_anatomical_grip_max_meters"] = primary_anchor_to_anatomical_grip_max
		result["primary_anchor_to_anatomical_grip_avg_meters"] = primary_anchor_to_anatomical_grip_sum / float(primary_anchor_to_anatomical_grip_count)
		result["primary_anchor_to_anatomical_grip_max_frame"] = primary_anchor_to_anatomical_grip_max_frame
	if not bool(result.get("baked", false)):
		result["reason"] = "no_upper_body_bones_captured"
	return result

func _resolve_solved_replay_anchor_node_paths(held_item: Node3D) -> Array[StringName]:
	var resolved_paths: Array[StringName] = []
	if held_item == null or not is_instance_valid(held_item):
		return resolved_paths
	for path_name: StringName in SOLVED_REPLAY_ANCHOR_NODE_PATHS:
		if held_item.get_node_or_null(NodePath(String(path_name))) != null:
			resolved_paths.append(path_name)
	return resolved_paths

func _capture_solved_replay_anchor_frame(held_item: Node3D, anchor_paths: Array[StringName]) -> Dictionary:
	var positions := PackedVector3Array()
	var rotations := PackedVector4Array()
	var scales := PackedVector3Array()
	if held_item == null or not is_instance_valid(held_item):
		return {
			"positions": positions,
			"rotations": rotations,
			"scales": scales,
		}
	var weapon_inverse: Transform3D = held_item.global_transform.affine_inverse()
	for path_name: StringName in anchor_paths:
		var anchor_node: Node3D = held_item.get_node_or_null(NodePath(String(path_name))) as Node3D
		if anchor_node == null or not is_instance_valid(anchor_node):
			continue
		var anchor_weapon_transform: Transform3D = weapon_inverse * anchor_node.global_transform
		positions.append(anchor_weapon_transform.origin)
		rotations.append(_pack_quaternion(anchor_weapon_transform.basis.orthonormalized().get_rotation_quaternion()))
		scales.append(anchor_weapon_transform.basis.get_scale())
	return {
		"positions": positions,
		"rotations": rotations,
		"scales": scales,
	}

func _pack_quaternion(rotation: Quaternion) -> Vector4:
	var normalized_rotation: Quaternion = rotation.normalized()
	return Vector4(normalized_rotation.x, normalized_rotation.y, normalized_rotation.z, normalized_rotation.w)

func _build_runtime_clip_frame_motion_node(
	runtime_clip,
	frame_index: int,
	fallback_motion_node: CombatAnimationMotionNode
) -> CombatAnimationMotionNode:
	var motion_node: CombatAnimationMotionNode = (
		fallback_motion_node.duplicate_node()
		if fallback_motion_node != null
		else CombatAnimationMotionNodeScript.new() as CombatAnimationMotionNode
	)
	motion_node.tip_position_local = _get_runtime_clip_frame_vector3(
		runtime_clip,
		&"baked_tip_positions_local",
		frame_index,
		motion_node.tip_position_local
	)
	motion_node.tip_position_origin_id = _get_runtime_clip_origin_id(
		runtime_clip,
		&"baked_tip_positions_origin_id",
		CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING
	)
	motion_node.pommel_position_local = _get_runtime_clip_frame_vector3(
		runtime_clip,
		&"baked_pommel_positions_local",
		frame_index,
		motion_node.pommel_position_local
	)
	motion_node.pommel_position_origin_id = _get_runtime_clip_origin_id(
		runtime_clip,
		&"baked_pommel_positions_origin_id",
		CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING
	)
	motion_node.weapon_orientation_degrees = _get_runtime_clip_frame_vector3(
		runtime_clip,
		&"baked_weapon_orientation_degrees",
		frame_index,
		motion_node.weapon_orientation_degrees
	)
	motion_node.weapon_orientation_authored = true
	motion_node.weapon_roll_degrees = _get_runtime_clip_frame_float(
		runtime_clip,
		&"baked_weapon_roll_degrees",
		frame_index,
		motion_node.weapon_roll_degrees
	)
	motion_node.axial_reposition_offset = _get_runtime_clip_frame_float(
		runtime_clip,
		&"baked_axial_reposition_offsets",
		frame_index,
		motion_node.axial_reposition_offset
	)
	motion_node.grip_seat_slide_offset = _get_runtime_clip_frame_float(
		runtime_clip,
		&"baked_grip_seat_slide_offsets",
		frame_index,
		motion_node.grip_seat_slide_offset
	)
	motion_node.secondary_grip_seat_slide_offset = _get_runtime_clip_frame_float(
		runtime_clip,
		&"baked_secondary_grip_seat_slide_offsets",
		frame_index,
		motion_node.secondary_grip_seat_slide_offset
	)
	motion_node.body_support_blend = _get_runtime_clip_frame_float(
		runtime_clip,
		&"baked_body_support_blends",
		frame_index,
		motion_node.body_support_blend
	)
	motion_node.right_upperarm_roll_degrees = _get_runtime_clip_frame_float(
		runtime_clip,
		&"baked_right_upperarm_roll_degrees",
		frame_index,
		motion_node.right_upperarm_roll_degrees
	)
	motion_node.left_upperarm_roll_degrees = _get_runtime_clip_frame_float(
		runtime_clip,
		&"baked_left_upperarm_roll_degrees",
		frame_index,
		motion_node.left_upperarm_roll_degrees
	)
	motion_node.two_hand_state = _get_runtime_clip_frame_string_name(
		runtime_clip,
		&"baked_two_hand_states",
		frame_index,
		motion_node.two_hand_state
	)
	motion_node.primary_hand_slot = _get_runtime_clip_frame_string_name(
		runtime_clip,
		&"baked_primary_hand_slots",
		frame_index,
		motion_node.primary_hand_slot
	)
	motion_node.preferred_grip_style_mode = _get_runtime_clip_frame_string_name(
		runtime_clip,
		&"baked_grip_style_modes",
		frame_index,
		motion_node.preferred_grip_style_mode
	)
	motion_node.normalize()
	return motion_node

func _build_runtime_clip_frame_playback_state(
	runtime_clip,
	frame_index: int,
	motion_node: CombatAnimationMotionNode
) -> Dictionary:
	return {
		"active": true,
		"tip_position_local": motion_node.tip_position_local,
		"tip_position_origin_id": motion_node.tip_position_origin_id,
		"pommel_position_local": motion_node.pommel_position_local,
		"pommel_position_origin_id": motion_node.pommel_position_origin_id,
		"weapon_orientation_degrees": motion_node.weapon_orientation_degrees,
		"weapon_roll_degrees": motion_node.weapon_roll_degrees,
		"axial_reposition_offset": motion_node.axial_reposition_offset,
		"grip_seat_slide_offset": motion_node.grip_seat_slide_offset,
		"secondary_grip_seat_slide_offset": motion_node.secondary_grip_seat_slide_offset,
		"body_support_blend": motion_node.body_support_blend,
		"right_upperarm_roll_degrees": motion_node.right_upperarm_roll_degrees,
		"left_upperarm_roll_degrees": motion_node.left_upperarm_roll_degrees,
		"two_hand_state": motion_node.two_hand_state,
		"primary_hand_slot": motion_node.primary_hand_slot,
		"preferred_grip_style_mode": motion_node.preferred_grip_style_mode,
		"contact_grip_axis_local": _get_runtime_clip_frame_vector3(
			runtime_clip,
			&"baked_contact_grip_axes_local",
			frame_index,
			Vector3.ZERO
		),
		"contact_grip_axis_origin_id": _get_runtime_clip_origin_id(
			runtime_clip,
			&"baked_contact_grip_axes_origin_id",
			CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING
		),
		"contact_grip_axis_local_override_active": _get_runtime_clip_frame_bool(
			runtime_clip,
			&"baked_contact_axis_override_active",
			frame_index,
			false
		),
	}

func _get_runtime_clip_frame_vector3(
	runtime_clip,
	property_name: StringName,
	frame_index: int,
	fallback: Vector3
) -> Vector3:
	if runtime_clip == null:
		return fallback
	var values: PackedVector3Array = runtime_clip.get(property_name) as PackedVector3Array
	if frame_index < 0 or frame_index >= values.size():
		return fallback
	return values[frame_index]

func _get_runtime_clip_frame_float(
	runtime_clip,
	property_name: StringName,
	frame_index: int,
	fallback: float
) -> float:
	if runtime_clip == null:
		return fallback
	var values: PackedFloat32Array = runtime_clip.get(property_name) as PackedFloat32Array
	if frame_index < 0 or frame_index >= values.size():
		return fallback
	return float(values[frame_index])

func _get_runtime_clip_frame_bool(
	runtime_clip,
	property_name: StringName,
	frame_index: int,
	fallback: bool
) -> bool:
	if runtime_clip == null:
		return fallback
	var values: Array = runtime_clip.get(property_name) as Array
	if frame_index < 0 or frame_index >= values.size():
		return fallback
	return bool(values[frame_index])

func _get_runtime_clip_frame_string_name(
	runtime_clip,
	property_name: StringName,
	frame_index: int,
	fallback: StringName
) -> StringName:
	if runtime_clip == null:
		return fallback
	var values: Array = runtime_clip.get(property_name) as Array
	if frame_index < 0 or frame_index >= values.size():
		return fallback
	return StringName(values[frame_index])

func _get_runtime_clip_origin_id(runtime_clip, property_name: StringName, fallback: StringName) -> StringName:
	if runtime_clip == null:
		return fallback
	var origin_id := StringName(runtime_clip.get(property_name))
	if origin_id == StringName():
		return fallback
	return origin_id

func _stamp_tip_pommel_origin_ids(
	target_state: Dictionary,
	origin_id: StringName = CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING
) -> void:
	var resolved_origin_id: StringName = origin_id
	if resolved_origin_id == StringName():
		resolved_origin_id = CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING
	target_state["tip_position_origin_id"] = resolved_origin_id
	target_state["pommel_position_origin_id"] = resolved_origin_id

func _set_tip_pommel_position_state(
	target_state: Dictionary,
	tip_position_local: Vector3,
	pommel_position_local: Vector3,
	origin_id: StringName = CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING
) -> void:
	var resolved_origin_id: StringName = origin_id
	if resolved_origin_id == StringName():
		resolved_origin_id = CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING
	target_state["tip_position_local"] = tip_position_local
	target_state["tip_position_origin_id"] = resolved_origin_id
	target_state["pommel_position_local"] = pommel_position_local
	target_state["pommel_position_origin_id"] = resolved_origin_id

func _resolve_origin_tracked_state_origin_id(
	source_state: Dictionary,
	origin_key: StringName,
	fallback_origin_id: StringName
) -> StringName:
	var resolved_origin_id: StringName = fallback_origin_id
	if resolved_origin_id == StringName():
		resolved_origin_id = CombatOriginRecordScript.ORIGIN_RL_BONE_ROOT
	if not source_state.has(origin_key):
		source_state[origin_key] = resolved_origin_id
		return resolved_origin_id
	var stored_origin_id: StringName = StringName(source_state.get(origin_key, StringName()))
	if stored_origin_id == StringName():
		source_state[origin_key] = resolved_origin_id
		return resolved_origin_id
	return stored_origin_id

func _resolve_origin_meta_value(target: Object, origin_meta_name: StringName, fallback_origin_id: StringName) -> StringName:
	var resolved_origin_id: StringName = fallback_origin_id
	if resolved_origin_id == StringName():
		resolved_origin_id = CombatOriginRecordScript.ORIGIN_RL_BONE_ROOT
	if target == null:
		return resolved_origin_id
	var stored_origin_id: StringName = StringName(target.get_meta(origin_meta_name, StringName()))
	if stored_origin_id != StringName():
		return stored_origin_id
	target.set_meta(origin_meta_name, resolved_origin_id)
	return resolved_origin_id

func _get_origin_tracked_vector3_meta(
	target: Object,
	value_meta_name: StringName,
	origin_meta_name: StringName,
	fallback_value: Vector3,
	fallback_origin_id: StringName
) -> Vector3:
	_resolve_origin_meta_value(target, origin_meta_name, fallback_origin_id)
	if target == null or not target.has_meta(value_meta_name):
		return fallback_value
	var stored_value: Variant = target.get_meta(value_meta_name)
	if stored_value is Vector3:
		return stored_value as Vector3
	return fallback_value

func _set_origin_tracked_vector3_meta(
	target: Object,
	value_meta_name: StringName,
	origin_meta_name: StringName,
	value: Vector3,
	origin_id: StringName
) -> void:
	if target == null:
		return
	var resolved_origin_id: StringName = origin_id
	if resolved_origin_id == StringName():
		resolved_origin_id = CombatOriginRecordScript.ORIGIN_RL_BONE_ROOT
	target.set_meta(value_meta_name, value)
	target.set_meta(origin_meta_name, resolved_origin_id)

func _get_origin_tracked_vector3_state(
	source_state: Dictionary,
	value_key: StringName,
	origin_key: StringName,
	fallback_value: Vector3,
	fallback_origin_id: StringName
) -> Vector3:
	var resolved_origin_id: StringName = fallback_origin_id
	if resolved_origin_id == StringName():
		resolved_origin_id = CombatOriginRecordScript.ORIGIN_RL_BONE_ROOT
	if not source_state.has(origin_key) or StringName(source_state.get(origin_key, StringName())) == StringName():
		source_state[origin_key] = resolved_origin_id
	if not source_state.has(value_key):
		return fallback_value
	var stored_value: Variant = source_state.get(value_key, fallback_value)
	if stored_value is Vector3:
		return stored_value as Vector3
	return fallback_value

func _get_weapon_tip_meta(held_item: Object) -> Vector3:
	return _get_origin_tracked_vector3_meta(
		held_item,
		"weapon_tip_local",
		"weapon_tip_origin_id",
		Vector3.ZERO,
		CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
	)

func _get_weapon_pommel_meta(held_item: Object) -> Vector3:
	return _get_origin_tracked_vector3_meta(
		held_item,
		"weapon_pommel_local",
		"weapon_pommel_origin_id",
		Vector3.ZERO,
		CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
	)

func _get_primary_grip_contact_meta(held_item: Object) -> Vector3:
	return _get_origin_tracked_vector3_meta(
		held_item,
		"primary_grip_contact_local",
		"primary_grip_contact_origin_id",
		Vector3.ZERO,
		CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
	)

func _get_support_grip_contact_meta(held_item: Object) -> Vector3:
	return _get_origin_tracked_vector3_meta(
		held_item,
		"support_grip_contact_local",
		"support_grip_contact_origin_id",
		Vector3.ZERO,
		CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
	)

func _get_preview_primary_grip_seat_meta(held_item: Object) -> Vector3:
	return _get_origin_tracked_vector3_meta(
		held_item,
		PREVIEW_PRIMARY_GRIP_SEAT_LOCAL_META,
		PREVIEW_PRIMARY_GRIP_SEAT_ORIGIN_META,
		_get_primary_grip_contact_meta(held_item),
		CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
	)

func _get_preview_support_grip_seat_meta(held_item: Object) -> Vector3:
	return _get_origin_tracked_vector3_meta(
		held_item,
		PREVIEW_SUPPORT_GRIP_SEAT_LOCAL_META,
		PREVIEW_SUPPORT_GRIP_SEAT_ORIGIN_META,
		Vector3.ZERO,
		CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
	)

func _normalize_combat_origin_id(origin_id: StringName, fallback_origin_id: StringName) -> StringName:
	if origin_id != StringName():
		return origin_id
	if fallback_origin_id != StringName():
		return fallback_origin_id
	return CombatOriginRecordScript.ORIGIN_RL_BONE_ROOT

func _get_preview_primary_grip_seat_origin_id(held_item: Object) -> StringName:
	return _resolve_origin_meta_value(
		held_item,
		PREVIEW_PRIMARY_GRIP_SEAT_ORIGIN_META,
		CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
	)

func _get_preview_support_grip_seat_origin_id(held_item: Object) -> StringName:
	return _resolve_origin_meta_value(
		held_item,
		PREVIEW_SUPPORT_GRIP_SEAT_ORIGIN_META,
		CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
	)

func refresh_focus_visuals(
	preview_container: SubViewportContainer,
	preview_subviewport: SubViewport,
	active_draft: Resource,
	selected_node_index: int,
	active_focus: StringName = &"tip",
	baked_profile: BakedProfile = null
) -> void:
	var state: Dictionary = _ensure_preview_nodes(preview_container, preview_subviewport)
	_sync_preview_size(preview_container, preview_subviewport)
	var preview_root: Node3D = state.get("preview_root", null) as Node3D
	var effective_motion_node_chain: Array = _build_effective_motion_node_chain(active_draft, selected_node_index, null)
	var visible_motion_node_chain: Array = _build_visible_motion_node_chain(active_draft, effective_motion_node_chain)
	var visible_selected_node_index: int = _resolve_visible_selected_motion_node_index(active_draft, selected_node_index, visible_motion_node_chain.size())
	var resolved_playback_state: Dictionary = {}
	if preview_root != null:
		resolved_playback_state = _get_node_meta_or_default(preview_root, "resolved_playback_state", {}) as Dictionary
	var display_motion_node_chain: Array = _build_resolved_display_motion_node_chain(
		visible_motion_node_chain,
		visible_selected_node_index,
		resolved_playback_state
	)
	var speed_state_config: Dictionary = _build_speed_state_config(active_draft)
	resolved_playback_state["trajectory_static_visual_signature"] = _build_trajectory_static_visual_signature(
		visible_motion_node_chain,
		speed_state_config,
		active_draft,
		bool(resolved_playback_state.get("authoring_drag_lightweight", false))
	)
	_refresh_trajectory_visuals(
		state,
		display_motion_node_chain,
		visible_selected_node_index,
		active_focus,
		resolved_playback_state,
		speed_state_config,
		active_draft
	)
	_refresh_weapon_and_sphere_visuals(state, display_motion_node_chain, visible_selected_node_index, active_focus, baked_profile)

func resolve_upperarm_roll_drag_state(preview_subviewport: SubViewport, camera: Camera3D, screen_position: Vector2) -> Dictionary:
	if preview_subviewport == null or camera == null:
		return {}
	var preview_root: Node3D = preview_subviewport.get_node_or_null(PREVIEW_ROOT_NAME) as Node3D
	if preview_root == null:
		return {}
	var gizmo_state: Dictionary = _get_node_meta_or_default(preview_root, "upperarm_roll_gizmo_state", {}) as Dictionary
	if gizmo_state.is_empty():
		return {}
	var best_state: Dictionary = {}
	var best_distance: float = INF
	for slot_key in [&"hand_right", &"hand_left"]:
		var slot_state: Dictionary = gizmo_state.get(slot_key, {}) as Dictionary
		if slot_state.is_empty():
			continue
		var handle_global: Vector3 = slot_state.get("handle_global", Vector3.ZERO) as Vector3
		var screen_distance: float = camera.unproject_position(handle_global).distance_to(screen_position)
		if screen_distance <= UPPERARM_ROLL_PICK_RADIUS_PIXELS and screen_distance < best_distance:
			best_state = slot_state
			best_distance = screen_distance
	if best_state.is_empty():
		return {}
	return {
		"drag_target": best_state.get("drag_target", StringName()),
		"roll_state": best_state,
	}

func _normalize_preview_slot_id(slot_id: StringName) -> StringName:
	if slot_id == &"hand_left":
		return &"hand_left"
	return &"hand_right"

func _resolve_preview_dominant_slot_id() -> StringName:
	return _normalize_preview_slot_id(preview_dominant_slot_id)

func _resolve_preview_support_slot_id() -> StringName:
	return &"hand_right" if _resolve_preview_dominant_slot_id() == &"hand_left" else &"hand_left"

func get_debug_state(preview_subviewport: SubViewport) -> Dictionary:
	var preview_root: Node3D = preview_subviewport.get_node_or_null(PREVIEW_ROOT_NAME) as Node3D if preview_subviewport != null else null
	if preview_root == null:
		return {}
	var actor: Node3D = preview_root.get_node_or_null(PREVIEW_ACTOR_PIVOT_NAME + "/" + PREVIEW_ACTOR_NAME) as Node3D
	var held_item: Node3D = _get_node_meta_or_default(preview_root, "preview_held_item", null) as Node3D
	var marker_root: Node3D = preview_root.find_child(MARKER_ROOT_NAME, true, false) as Node3D
	var trajectory_root: Node3D = preview_root.find_child(TRAJECTORY_ROOT_NAME, true, false) as Node3D
	var primary_grip_debug_root: Node3D = null
	var secondary_grip_debug_root: Node3D = null
	var weapon_proxy_root: Node3D = null
	var weapon_proxy_debug_root: Node3D = null
	var weapon_collision_debug_root: Node3D = null
	if held_item != null:
		primary_grip_debug_root = held_item.get_node_or_null("PrimaryGripGuide/GripShellCenter/" + PREVIEW_GRIP_CONTACT_DEBUG_ROOT_NAME) as Node3D
		secondary_grip_debug_root = held_item.get_node_or_null("SecondaryGripGuide/GripShellCenter/" + PREVIEW_GRIP_CONTACT_DEBUG_ROOT_NAME) as Node3D
		weapon_proxy_root = held_item.get_node_or_null("WeaponBodyRestrictionProxy") as Node3D
		weapon_proxy_debug_root = weapon_proxy_root.get_node_or_null(PREVIEW_PROXY_DEBUG_ROOT_NAME) as Node3D if weapon_proxy_root != null else null
		weapon_collision_debug_root = held_item.get_node_or_null(PREVIEW_COLLISION_DEBUG_ROOT_NAME) as Node3D
	var trajectory_root_parent_name: String = ""
	if trajectory_root != null and trajectory_root.get_parent() != null:
		trajectory_root_parent_name = String(trajectory_root.get_parent().name)
	var resolved_playback_state: Dictionary = _get_node_meta_or_default(preview_root, "resolved_playback_state", {}) as Dictionary
	var grip_contact_debug_state: Dictionary = {}
	if actor != null and actor.has_method("get_grip_contact_debug_state"):
		grip_contact_debug_state = actor.call("get_grip_contact_debug_state") as Dictionary
	var joint_range_debug_state: Dictionary = {}
	if actor != null and actor.has_method("get_authoring_joint_range_debug_state"):
		joint_range_debug_state = actor.call("get_authoring_joint_range_debug_state") as Dictionary
	var body_self_collision_debug_state: Dictionary = {}
	if actor != null and actor.has_method("get_body_self_collision_debug_state"):
		body_self_collision_debug_state = actor.call("get_body_self_collision_debug_state") as Dictionary
	var upper_body_authoring_state: Dictionary = {}
	if actor != null and actor.has_method("get_upper_body_authoring_state"):
		upper_body_authoring_state = actor.call("get_upper_body_authoring_state") as Dictionary
	_resolve_origin_meta_value(preview_root, "stow_anchor_marker_positions_origin_id", CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING)
	var resolved_tip_position: Vector3 = _get_origin_tracked_vector3_state(
		resolved_playback_state,
		"tip_position_local",
		"tip_position_origin_id",
		Vector3.ZERO,
		CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING
	)
	var resolved_pommel_position: Vector3 = _get_origin_tracked_vector3_state(
		resolved_playback_state,
		"pommel_position_local",
		"pommel_position_origin_id",
		Vector3.ZERO,
		CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING
	)
	var display_selected_tip_position: Vector3 = _get_origin_tracked_vector3_meta(
		preview_root,
		"display_selected_tip_position_local",
		"display_selected_tip_position_origin_id",
		Vector3.ZERO,
		CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING
	)
	var display_selected_pommel_position: Vector3 = _get_origin_tracked_vector3_meta(
		preview_root,
		"display_selected_pommel_position_local",
		"display_selected_pommel_position_origin_id",
		Vector3.ZERO,
		CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING
	)
	return {
		"has_preview_actor": actor != null,
		"has_preview_weapon": held_item != null and is_instance_valid(held_item),
		"debugger_view_enabled": bool(_get_node_meta_or_default(preview_root, DEBUGGER_VIEW_ENABLED_META, false)),
		"held_item_is_unarmed_proxy": _is_unarmed_preview_item(held_item),
		"has_primary_grip_anchor": weapon_grip_anchor_provider.get_primary_grip_anchor(held_item) != null if held_item != null else false,
		"motion_node_count": int(_get_node_meta_or_default(preview_root, "motion_node_count", 0)),
		"motion_node_marker_count": int(_get_node_meta_or_default(preview_root, "motion_node_marker_count", 0)),
		"selected_motion_node_index": int(_get_node_meta_or_default(preview_root, "selected_motion_node_index", -1)),
		"draft_point_count": int(_get_node_meta_or_default(preview_root, "draft_point_count", 0)),
		"curve_baked_point_count": int(_get_node_meta_or_default(preview_root, "curve_baked_point_count", 0)),
		"speed_state_sample_count": int(_get_node_meta_or_default(preview_root, "speed_state_sample_count", 0)),
		"speed_state_armed_sample_count": int(_get_node_meta_or_default(preview_root, "speed_state_armed_sample_count", 0)),
		"speed_state_buildup_sample_count": int(_get_node_meta_or_default(preview_root, "speed_state_buildup_sample_count", 0)),
		"speed_state_reset_sample_count": int(_get_node_meta_or_default(preview_root, "speed_state_reset_sample_count", 0)),
		"speed_state_max_effective_speed_mps": float(_get_node_meta_or_default(preview_root, "speed_state_max_effective_speed_mps", 0.0)),
		"speed_state_acceleration_percent": float(_get_node_meta_or_default(preview_root, "speed_state_acceleration_percent", 0.0)),
		"speed_state_deceleration_percent": float(_get_node_meta_or_default(preview_root, "speed_state_deceleration_percent", 0.0)),
		"point_marker_count": int(_get_node_meta_or_default(preview_root, "point_marker_count", 0)),
		"control_handle_marker_count": int(_get_node_meta_or_default(preview_root, "control_handle_marker_count", 0)),
		"stow_anchor_marker_count": int(_get_node_meta_or_default(preview_root, "stow_anchor_marker_count", 0)),
		"stow_anchor_marker_ids": _get_node_meta_or_default(preview_root, "stow_anchor_marker_ids", []),
		"stow_anchor_marker_positions_local": _get_node_meta_or_default(preview_root, "stow_anchor_marker_positions_local", {}),
		"stow_anchor_marker_positions_origin_id": StringName(_get_node_meta_or_default(preview_root, "stow_anchor_marker_positions_origin_id", CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING)),
		"stow_anchor_marker_position_origin_ids": _get_node_meta_or_default(preview_root, "stow_anchor_marker_position_origin_ids", {}),
		"selected_stow_anchor_marker_id": _get_node_meta_or_default(preview_root, "selected_stow_anchor_marker_id", StringName()),
		"selected_stow_anchor_slot_id": _get_node_meta_or_default(preview_root, "selected_stow_anchor_slot_id", StringName()),
		"selected_stow_anchor_mode": _get_node_meta_or_default(preview_root, "selected_stow_anchor_mode", StringName()),
		"selected_stow_anchor_orientation_side": _get_node_meta_or_default(preview_root, "selected_stow_anchor_orientation_side", StringName()),
		"preview_pose_mode": _get_node_meta_or_default(preview_root, PREVIEW_POSE_MODE_META, StringName()),
		"upper_body_authoring_active": bool(upper_body_authoring_state.get("active", false)),
		"upper_body_authoring_state": upper_body_authoring_state,
		"weapon_gizmo_marker_count": int(_get_node_meta_or_default(preview_root, "weapon_gizmo_marker_count", 0)),
		"upperarm_roll_gizmo_count": int(_get_node_meta_or_default(preview_root, "upperarm_roll_gizmo_count", 0)),
		"selected_point_index": int(_get_node_meta_or_default(preview_root, "selected_point_index", -1)),
		"marker_root_exists": marker_root != null,
		"trajectory_root_parent_name": trajectory_root_parent_name,
		"trajectory_root_global_position": trajectory_root.global_position if trajectory_root != null else Vector3.ZERO,
		"body_lock_frame_source": _resolve_preview_body_lock_frame_source(actor),
		"body_lock_frame_origin": _resolve_preview_body_lock_frame(actor).origin,
		"body_lock_frame_origin_id": _resolve_preview_body_lock_frame_origin_id(actor),
		"weapon_tip_alignment_error_meters": float(_get_node_meta_or_default(preview_root, "weapon_tip_alignment_error_meters", -1.0)),
		"weapon_pommel_alignment_error_meters": float(_get_node_meta_or_default(preview_root, "weapon_pommel_alignment_error_meters", -1.0)),
		"authoring_endpoint_legality_result": _get_node_meta_or_default(preview_root, "authoring_endpoint_legality_result", {}),
		"resolved_tip_position_local": resolved_tip_position,
		"resolved_tip_position_origin_id": StringName(resolved_playback_state.get("tip_position_origin_id", CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING)),
		"resolved_pommel_position_local": resolved_pommel_position,
		"resolved_pommel_position_origin_id": StringName(resolved_playback_state.get("pommel_position_origin_id", CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING)),
		"display_selected_tip_position_local": display_selected_tip_position,
		"display_selected_tip_position_origin_id": StringName(_get_node_meta_or_default(preview_root, "display_selected_tip_position_origin_id", CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING)),
		"display_selected_pommel_position_local": display_selected_pommel_position,
		"display_selected_pommel_position_origin_id": StringName(_get_node_meta_or_default(preview_root, "display_selected_pommel_position_origin_id", CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING)),
		"dominant_grip_target_world": _resolve_preview_hand_grip_target_world(actor, _resolve_preview_dominant_slot_id()),
		"dominant_grip_anchor_world": _resolve_preview_grip_anchor_world(held_item, _resolve_preview_dominant_slot_id()),
		"dominant_grip_alignment_error_meters": _resolve_preview_grip_alignment_error(actor, held_item, _resolve_preview_dominant_slot_id()),
		"support_grip_alignment_error_meters": _resolve_preview_grip_alignment_error(actor, held_item, _resolve_preview_support_slot_id()),
		"dominant_finger_contact_readiness": _resolve_preview_finger_contact_readiness(held_item, _resolve_preview_dominant_slot_id()),
		"support_finger_contact_readiness": _resolve_preview_finger_contact_readiness(held_item, _resolve_preview_support_slot_id()),
		"dominant_finger_contact_distance_meters": _resolve_preview_finger_contact_distance(held_item, _resolve_preview_dominant_slot_id()),
		"support_finger_contact_distance_meters": _resolve_preview_finger_contact_distance(held_item, _resolve_preview_support_slot_id()),
		"dominant_finger_contact_ray_debug": _resolve_preview_finger_contact_ray_debug(held_item, _resolve_preview_dominant_slot_id()),
		"support_finger_contact_ray_debug": _resolve_preview_finger_contact_ray_debug(held_item, _resolve_preview_support_slot_id()),
		"grip_contact_debug_state": grip_contact_debug_state,
		"joint_range_debug_state": joint_range_debug_state,
		"joint_range_debug_visible": bool(joint_range_debug_state.get("visible", false)),
		"joint_range_debug_visual_count": int(joint_range_debug_state.get("visual_count", 0)),
		"support_coupling_metrics": _resolve_preview_support_coupling_metrics(actor, held_item),
		"contact_coupling_metrics": _get_node_meta_or_default(preview_root, "contact_coupling_metrics", {}),
		"contact_clearance_settle_metrics": _get_node_meta_or_default(preview_root, "contact_clearance_settle_metrics", {}),
		"final_anchor_reseat_metrics": _get_node_meta_or_default(preview_root, "final_anchor_reseat_metrics", {}),
		"authoring_contact_tether_metrics": _get_node_meta_or_default(preview_root, "authoring_contact_tether_metrics", {}),
		"grip_seat_reseat_error_meters": float(_get_node_meta_or_default(preview_root, "grip_seat_reseat_error_meters", -1.0)),
		"dominant_slot_id": _resolve_preview_dominant_slot_id(),
		"default_two_hand": preview_default_two_hand,
		"camera_distance": float(_get_node_meta_or_default(preview_root, CAMERA_DISTANCE_META, CAMERA_DEFAULT_DISTANCE)),
		"camera_orbit_yaw_degrees": float(_get_node_meta_or_default(preview_root, CAMERA_ORBIT_YAW_META, 0.0)),
		"camera_orbit_pitch_degrees": float(_get_node_meta_or_default(preview_root, CAMERA_ORBIT_PITCH_META, 0.0)),
		"camera_focus_point": _get_vector3_meta(preview_root, CAMERA_FOCUS_POINT_META, Vector3(0.0, 1.1, 0.0)),
		"body_restriction_debug_mesh_count": _count_visible_body_restriction_debug_meshes(actor),
		"weapon_bounds_debug_exists": _is_debug_mesh_visible(weapon_collision_debug_root, PREVIEW_WEAPON_BOUNDS_DEBUG_NAME),
		"weapon_proxy_source": weapon_proxy_root.get_meta("proxy_source", StringName()) if weapon_proxy_root != null else StringName(),
		"weapon_proxy_sample_count": int(weapon_proxy_root.get_meta("weapon_proxy_sample_count", 0)) if weapon_proxy_root != null else 0,
		"weapon_proxy_uses_full_geometry": bool(weapon_proxy_root.get_meta("weapon_proxy_uses_full_geometry", false)) if weapon_proxy_root != null else false,
		"primary_grip_debug_count": _count_visible_mesh_children(primary_grip_debug_root),
		"secondary_grip_debug_count": _count_visible_mesh_children(secondary_grip_debug_root),
		"weapon_proxy_debug_count": _count_visible_mesh_children(weapon_proxy_debug_root),
		"collision_debug_visual_count": int(_get_node_meta_or_default(preview_root, "collision_debug_visual_count", 0)),
		"body_self_collision_state": body_self_collision_debug_state,
		"body_self_collision_legal": bool(body_self_collision_debug_state.get("legal", true)),
		"body_self_collision_checked_pair_count": int(body_self_collision_debug_state.get("checked_pair_count", 0)),
		"body_self_collision_overlap_pair_count": int(body_self_collision_debug_state.get("overlap_pair_count", 0)),
		"body_self_collision_allowed_overlap_pair_count": int(body_self_collision_debug_state.get("allowed_overlap_pair_count", 0)),
		"body_self_collision_illegal_pair_count": int(body_self_collision_debug_state.get("illegal_pair_count", 0)),
		"body_self_collision_first_illegal_pair": body_self_collision_debug_state.get("first_illegal_pair", {}),
		"body_self_collision_illegal_pairs": body_self_collision_debug_state.get("illegal_pairs", []),
		"body_self_collision_minimum_clearance_meters": float(body_self_collision_debug_state.get("minimum_clearance_meters", -1.0)),
		"collision_pose_legal": bool(_get_node_meta_or_default(preview_root, "collision_pose_legal", true)),
		"collision_pose_illegal_sample_count": int(_get_node_meta_or_default(preview_root, "collision_pose_illegal_sample_count", 0)),
		"collision_pose_region": String(_get_node_meta_or_default(preview_root, "collision_pose_region", "")),
		"collision_pose_attachment": String(_get_node_meta_or_default(preview_root, "collision_pose_attachment", "")),
		"collision_pose_sample": String(_get_node_meta_or_default(preview_root, "collision_pose_sample", "")),
		"collision_pose_clearance_meters": float(_get_node_meta_or_default(preview_root, "collision_pose_clearance_meters", -1.0)),
		"collision_path_legal": bool(_get_node_meta_or_default(preview_root, "collision_path_legal", true)),
		"collision_path_sample_count": int(_get_node_meta_or_default(preview_root, "collision_path_sample_count", 0)),
		"collision_path_illegal_pose_count": int(_get_node_meta_or_default(preview_root, "collision_path_illegal_pose_count", 0)),
		"collision_path_first_illegal_index": int(_get_node_meta_or_default(preview_root, "collision_path_first_illegal_index", -1)),
		"collision_path_region": String(_get_node_meta_or_default(preview_root, "collision_path_region", "")),
	}

func resolve_preview_hand_mounted_motion_seed(
	preview_subviewport: SubViewport,
	fallback_seed: Dictionary = {},
	expected_wip_id: StringName = StringName()
) -> Dictionary:
	var preview_root: Node3D = _get_preview_root(preview_subviewport)
	if preview_root == null:
		return fallback_seed.duplicate(true)
	var preview_wip_id: StringName = _get_node_meta_or_default(preview_root, "preview_wip_id", StringName()) as StringName
	var preview_slot_id: StringName = _get_node_meta_or_default(preview_root, PREVIEW_ACTIVE_SLOT_ID_META, StringName()) as StringName
	if expected_wip_id != StringName() and preview_wip_id != expected_wip_id:
		return fallback_seed.duplicate(true)
	if preview_slot_id != StringName() and preview_slot_id != _resolve_preview_dominant_slot_id():
		return fallback_seed.duplicate(true)
	var actor: Node3D = preview_root.get_node_or_null(PREVIEW_ACTOR_PIVOT_NAME + "/" + PREVIEW_ACTOR_NAME) as Node3D
	var held_item: Node3D = _get_node_meta_or_default(preview_root, "preview_held_item", null) as Node3D
	var trajectory_root: Node3D = preview_root.find_child(TRAJECTORY_ROOT_NAME, true, false) as Node3D
	if actor == null or held_item == null or not is_instance_valid(held_item) or trajectory_root == null:
		return fallback_seed.duplicate(true)
	var local_tip: Vector3 = _get_origin_tracked_vector3_meta(
		held_item,
		"weapon_tip_local",
		"weapon_tip_origin_id",
		Vector3.ZERO,
		CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
	)
	var local_pommel: Vector3 = _get_origin_tracked_vector3_meta(
		held_item,
		"weapon_pommel_local",
		"weapon_pommel_origin_id",
		Vector3.ZERO,
		CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
	)
	if local_tip.is_equal_approx(local_pommel):
		return fallback_seed.duplicate(true)
	var resolved_seed: Dictionary = fallback_seed.duplicate(true)
	var requested_grip_style: StringName = StringName(resolved_seed.get(
		"preferred_grip_style_mode",
		held_item.get_meta("grip_style_mode", CraftedItemWIP.GRIP_NORMAL)
	))
	var unarmed_proxy: bool = _is_unarmed_preview_item(held_item)
	if not unarmed_proxy:
		equipped_item_presenter.apply_held_item_grip_style_mode(
			held_item,
			actor,
			_resolve_preview_dominant_slot_id(),
			requested_grip_style
		)
	var requested_slide: float = float(resolved_seed.get("grip_seat_slide_offset", 0.0))
	var requested_axial: float = float(resolved_seed.get("axial_reposition_offset", 0.0))
	var requested_primary_local: Vector3 = _get_origin_tracked_vector3_meta(
		held_item,
		"primary_grip_contact_local",
		"primary_grip_contact_origin_id",
		Vector3.ZERO,
		CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
	)
	if not unarmed_proxy:
		requested_primary_local = _resolve_primary_grip_seat_local_from_offsets(
			held_item,
			requested_slide,
			requested_axial
		)
	_set_origin_tracked_vector3_meta(
		held_item,
		PREVIEW_PRIMARY_GRIP_SEAT_LOCAL_META,
		PREVIEW_PRIMARY_GRIP_SEAT_ORIGIN_META,
		requested_primary_local,
		CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
	)
	_apply_preview_resolved_grip_state(held_item)
	var mounted_transform: Transform3D = _resolve_preview_hand_mounted_transform(actor, held_item)
	trajectory_root.global_transform = _resolve_trajectory_authoring_transform(actor)
	var tip_local: Vector3 = trajectory_root.to_local(mounted_transform * local_tip)
	var pommel_local: Vector3 = trajectory_root.to_local(mounted_transform * local_pommel)
	resolved_seed["tip_position_local"] = tip_local
	resolved_seed["tip_position_origin_id"] = CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING
	resolved_seed["pommel_position_local"] = pommel_local
	resolved_seed["pommel_position_origin_id"] = CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING
	resolved_seed["weapon_total_length_meters"] = maxf(tip_local.distance_to(pommel_local), 0.001)
	return resolved_seed

func resolve_unarmed_hand_authoring_seed(
	preview_subviewport: SubViewport,
	expected_wip_id: StringName = StringName(),
	slot_id: StringName = &"hand_right"
) -> Dictionary:
	var preview_root: Node3D = _get_preview_root(preview_subviewport)
	if preview_root == null:
		return {}
	var preview_wip_id: StringName = _get_node_meta_or_default(preview_root, "preview_wip_id", StringName()) as StringName
	if expected_wip_id != StringName() and preview_wip_id != StringName() and preview_wip_id != expected_wip_id:
		return {}
	var actor: Node3D = preview_root.get_node_or_null(PREVIEW_ACTOR_PIVOT_NAME + "/" + PREVIEW_ACTOR_NAME) as Node3D
	var trajectory_root: Node3D = preview_root.find_child(TRAJECTORY_ROOT_NAME, true, false) as Node3D
	if actor == null or trajectory_root == null:
		return {}
	var hand_proxy_points_state: Dictionary = _resolve_unarmed_hand_proxy_points_state(actor, slot_id)
	if hand_proxy_points_state.is_empty():
		hand_proxy_points_state = _build_fallback_unarmed_proxy_points_state()
	var tip_local_to_hand: Vector3 = _get_origin_tracked_vector3_state(
		hand_proxy_points_state,
		"tip_local",
		"tip_origin_id",
		Vector3(0.12, 0.0, 0.0),
		CombatOriginRecordScript.ORIGIN_HAND_GRIP_ALIGNMENT
	)
	var pommel_local_to_hand: Vector3 = _get_origin_tracked_vector3_state(
		hand_proxy_points_state,
		"pommel_local",
		"pommel_origin_id",
		Vector3(-0.12, 0.0, 0.0),
		CombatOriginRecordScript.ORIGIN_HAND_GRIP_ALIGNMENT
	)
	var hand_anchor: Node3D = _resolve_preview_mount_anchor_for_slot(actor, slot_id)
	var grip_world: Vector3 = _resolve_preview_hand_grip_target_world(actor, slot_id)
	if hand_anchor == null or not is_instance_valid(hand_anchor) or grip_world.length_squared() <= 0.000001:
		return {}
	trajectory_root.global_transform = _resolve_trajectory_authoring_transform(actor)
	var tip_world: Vector3 = grip_world + hand_anchor.global_basis.orthonormalized() * tip_local_to_hand
	var pommel_world: Vector3 = grip_world + hand_anchor.global_basis.orthonormalized() * pommel_local_to_hand
	if tip_world.is_equal_approx(pommel_world):
		return {}
	return {
		"tip_position_local": trajectory_root.to_local(tip_world),
		"tip_position_origin_id": CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING,
		"pommel_position_local": trajectory_root.to_local(pommel_world),
		"pommel_position_origin_id": CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING,
		"weapon_total_length_meters": tip_world.distance_to(pommel_world),
		"unarmed_hand_proxy": true,
	}

func reset_preview_actor_to_mount_seed_baseline(preview_subviewport: SubViewport) -> void:
	var preview_root: Node3D = _get_preview_root(preview_subviewport)
	if preview_root == null:
		return
	var actor: Node3D = preview_root.get_node_or_null(PREVIEW_ACTOR_PIVOT_NAME + "/" + PREVIEW_ACTOR_NAME) as Node3D
	if actor == null:
		return
	var held_item: Node3D = _get_node_meta_or_default(preview_root, "preview_held_item", null) as Node3D
	var baseline_animation_name: StringName = _resolve_preview_authoring_baseline_animation_name(actor, held_item, null)
	if actor.has_method("set_authoring_preview_mode_enabled"):
		actor.call("set_authoring_preview_mode_enabled", true, baseline_animation_name)
	if actor.has_method("reset_authoring_preview_baseline_pose"):
		actor.call("reset_authoring_preview_baseline_pose", baseline_animation_name)
	else:
		if actor.has_method("clear_upper_body_authoring_state"):
			actor.call("clear_upper_body_authoring_state")
		if actor.has_method("clear_authoring_contact_anchor_bases"):
			actor.call("clear_authoring_contact_anchor_bases")
	_apply_preview_actor_upper_body_pose_now(actor)

func constrain_authored_segment_to_preview_actor(
	preview_subviewport: SubViewport,
	_active_wip: CraftedItemWIP,
	motion_node: CombatAnimationMotionNode,
	tip_position_local: Vector3,
	pommel_position_local: Vector3,
	dominant_seat_lock_strength: float = AUTHORING_DRAG_DOMINANT_SEAT_LOCK_STRENGTH
) -> Dictionary:
	var preview_root: Node3D = _get_preview_root(preview_subviewport)
	if preview_root == null or motion_node == null:
		return {
			"tip_position_local": tip_position_local,
			"tip_position_origin_id": CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING,
			"pommel_position_local": pommel_position_local,
			"pommel_position_origin_id": CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING,
		}
	var actor: Node3D = preview_root.get_node_or_null(PREVIEW_ACTOR_PIVOT_NAME + "/" + PREVIEW_ACTOR_NAME) as Node3D
	var held_item: Node3D = _get_node_meta_or_default(preview_root, "preview_held_item", null) as Node3D
	var trajectory_root: Node3D = preview_root.find_child(TRAJECTORY_ROOT_NAME, true, false) as Node3D
	if actor == null or held_item == null or not is_instance_valid(held_item) or trajectory_root == null:
		return {
			"tip_position_local": tip_position_local,
			"tip_position_origin_id": CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING,
			"pommel_position_local": pommel_position_local,
			"pommel_position_origin_id": CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING,
		}
	_apply_preview_motion_grip_state(held_item, motion_node, {}, actor)
	return _resolve_constrained_authored_segment_local(
		actor,
		held_item,
		trajectory_root,
		motion_node,
		tip_position_local,
		pommel_position_local,
		dominant_seat_lock_strength
	)

func constrain_authored_segment_to_endpoint_authority(
	preview_subviewport: SubViewport,
	_active_wip: CraftedItemWIP,
	motion_node: CombatAnimationMotionNode,
	tip_position_local: Vector3,
	pommel_position_local: Vector3
) -> Dictionary:
	var result := {
		"tip_position_local": tip_position_local,
		"tip_position_origin_id": CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING,
		"pommel_position_local": pommel_position_local,
		"pommel_position_origin_id": CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING,
		"progress": 1.0,
		"legal": true,
		"motion_volume_clamped": false,
	}
	var preview_root: Node3D = _get_preview_root(preview_subviewport)
	if preview_root == null or motion_node == null:
		return result
	var actor: Node3D = preview_root.get_node_or_null(PREVIEW_ACTOR_PIVOT_NAME + "/" + PREVIEW_ACTOR_NAME) as Node3D
	var held_item: Node3D = _get_node_meta_or_default(preview_root, "preview_held_item", null) as Node3D
	var trajectory_root: Node3D = preview_root.find_child(TRAJECTORY_ROOT_NAME, true, false) as Node3D
	if actor == null or held_item == null or not is_instance_valid(held_item) or trajectory_root == null:
		return result
	var local_tip: Vector3 = _get_weapon_tip_meta(held_item)
	var local_pommel: Vector3 = _get_weapon_pommel_meta(held_item)
	if local_tip.is_equal_approx(local_pommel):
		return result
	_apply_preview_motion_grip_state(held_item, motion_node, {}, actor)
	var volume_result: Dictionary = _project_preview_segment_local_to_valid_motion_volume(
		actor,
		held_item,
		trajectory_root,
		tip_position_local,
		pommel_position_local
	)
	tip_position_local = _get_origin_tracked_vector3_state(
		volume_result,
		"tip_position",
		"tip_position_origin_id",
		tip_position_local,
		CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING
	)
	pommel_position_local = _get_origin_tracked_vector3_state(
		volume_result,
		"pommel_position",
		"pommel_position_origin_id",
		pommel_position_local,
		CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING
	)
	_set_tip_pommel_position_state(
		result,
		tip_position_local,
		pommel_position_local,
		CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING
	)
	result["motion_volume_clamped"] = bool(volume_result.get("clamped", false))
	result["motion_volume_result"] = volume_result
	var authored_tip_world: Vector3 = trajectory_root.to_global(tip_position_local)
	var authored_pommel_world: Vector3 = trajectory_root.to_global(pommel_position_local)
	if authored_tip_world.distance_to(authored_pommel_world) <= SEGMENT_LEGALITY_EPSILON_METERS:
		return result
	var authored_transform: Transform3D = _solve_weapon_segment_transform(
		held_item,
		trajectory_root,
		motion_node,
		local_tip,
		local_pommel,
		authored_tip_world,
		authored_pommel_world,
		_resolve_motion_node_weapon_orientation_degrees(motion_node)
	)
	var legality_result: Dictionary = _evaluate_preview_segment_legality(
		actor,
		held_item,
		authored_transform,
		motion_node
	)
	result["legal"] = bool(legality_result.get("legal", true))
	result["legality_result"] = legality_result
	if not bool(result.get("legal", true)):
		if bool(legality_result.get("weapon_body_illegal", false)):
			result["collision_region"] = String(legality_result.get("weapon_body_region", ""))
			result["body_clearance_rejected"] = true
		elif (legality_result.get("dominant_correction_delta", Vector3.ZERO) as Vector3).length() > SEGMENT_LEGALITY_EPSILON_METERS:
			result["collision_region"] = "dominant arm reach"
		elif (legality_result.get("support_correction_delta", Vector3.ZERO) as Vector3).length() > SEGMENT_LEGALITY_EPSILON_METERS:
			result["collision_region"] = "support arm reach"
		else:
			result["collision_region"] = "body motion range"
	return result

func constrain_authored_segment_to_contact_tether(
	preview_subviewport: SubViewport,
	_active_wip: CraftedItemWIP,
	motion_node: CombatAnimationMotionNode,
	tip_position_local: Vector3,
	pommel_position_local: Vector3,
	tether_mode: StringName = AUTHORING_CONTACT_TETHER_MODE_TRANSLATE
) -> Dictionary:
	var preview_root: Node3D = _get_preview_root(preview_subviewport)
	if preview_root == null or motion_node == null:
		return {
			"tip_position_local": tip_position_local,
			"tip_position_origin_id": CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING,
			"pommel_position_local": pommel_position_local,
			"pommel_position_origin_id": CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING,
		}
	var actor: Node3D = preview_root.get_node_or_null(PREVIEW_ACTOR_PIVOT_NAME + "/" + PREVIEW_ACTOR_NAME) as Node3D
	var held_item: Node3D = _get_node_meta_or_default(preview_root, "preview_held_item", null) as Node3D
	var trajectory_root: Node3D = preview_root.find_child(TRAJECTORY_ROOT_NAME, true, false) as Node3D
	if actor == null or held_item == null or not is_instance_valid(held_item) or trajectory_root == null:
		return {
			"tip_position_local": tip_position_local,
			"tip_position_origin_id": CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING,
			"pommel_position_local": pommel_position_local,
			"pommel_position_origin_id": CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING,
		}
	var local_tip: Vector3 = _get_weapon_tip_meta(held_item)
	var local_pommel: Vector3 = _get_weapon_pommel_meta(held_item)
	if local_tip.is_equal_approx(local_pommel):
		return {
			"tip_position_local": tip_position_local,
			"tip_position_origin_id": CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING,
			"pommel_position_local": pommel_position_local,
			"pommel_position_origin_id": CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING,
		}
	_apply_preview_motion_grip_state(held_item, motion_node, {}, actor)
	var body_lock_frame: Transform3D = _resolve_preview_body_lock_frame(actor)
	var body_lock_origin_id: StringName = _resolve_preview_body_lock_frame_origin_id(actor)
	trajectory_root.global_transform = body_lock_frame
	var occupied_primary_target_world: Vector3 = Vector3.INF
	var occupied_primary_target_lock_local: Vector3 = Vector3.INF
	var occupied_primary_target_lock_origin_id: StringName = body_lock_origin_id
	var occupied_primary_wrist_world: Vector3 = Vector3.INF
	var occupied_primary_wrist_lock_local: Vector3 = Vector3.INF
	var occupied_primary_wrist_lock_origin_id: StringName = body_lock_origin_id
	var occupied_weapon_transform: Transform3D = held_item.global_transform
	var tip_lock_local: Vector3 = tip_position_local
	var tip_lock_origin_id: StringName = body_lock_origin_id
	var pommel_lock_local: Vector3 = pommel_position_local
	var pommel_lock_origin_id: StringName = body_lock_origin_id
	var tip_world: Vector3 = body_lock_frame * tip_lock_local
	var pommel_world: Vector3 = body_lock_frame * pommel_lock_local
	if tether_mode == AUTHORING_CONTACT_TETHER_MODE_TIP_PIVOT:
		pommel_world = body_lock_frame * pommel_lock_local
		occupied_primary_target_world = _resolve_preview_primary_grip_target_world(actor, held_item)
		if occupied_primary_target_world.length_squared() <= 0.000001:
			var occupied_primary_local: Vector3 = _get_preview_primary_grip_seat_meta(held_item)
			occupied_primary_target_world = held_item.global_transform * occupied_primary_local
		occupied_primary_target_lock_local = body_lock_frame.affine_inverse() * occupied_primary_target_world
		occupied_primary_wrist_world = _resolve_preview_primary_wrist_world(actor)
		if occupied_primary_wrist_world.length_squared() > 0.000001:
			occupied_primary_wrist_lock_local = body_lock_frame.affine_inverse() * occupied_primary_wrist_world
	var candidate_transform: Transform3D = held_item.global_transform
	if tip_world.distance_to(pommel_world) > SEGMENT_LEGALITY_EPSILON_METERS:
		candidate_transform = _solve_weapon_segment_transform(
			held_item,
			trajectory_root,
			motion_node,
			local_tip,
			local_pommel,
			tip_world,
			pommel_world,
			_resolve_motion_node_weapon_orientation_degrees(motion_node)
		)
	held_item.global_transform = candidate_transform
	_apply_preview_resolved_grip_state(held_item)
	_apply_two_hand_preview_state(actor, held_item, motion_node)
	_apply_preview_upper_body_authoring_state(
		actor,
		held_item,
		motion_node,
		{},
		tip_world,
		pommel_world,
		candidate_transform,
		true
	)
	_apply_preview_actor_upper_body_pose_now(actor)
	var tether_result: Dictionary = _resolve_contact_tethered_transform(
		actor,
		held_item,
		motion_node,
		candidate_transform,
		tether_mode,
		local_tip,
		local_pommel,
		tip_world,
		tip_lock_local,
		tip_lock_origin_id,
		trajectory_root,
		occupied_primary_target_world,
		occupied_primary_target_lock_local,
		occupied_primary_target_lock_origin_id,
		occupied_primary_wrist_world,
		occupied_primary_wrist_lock_local,
		occupied_primary_wrist_lock_origin_id,
		body_lock_frame,
		body_lock_origin_id,
		occupied_weapon_transform
	)
	var resolved_transform: Transform3D = tether_result.get("transform", candidate_transform) as Transform3D
	var metrics: Dictionary = tether_result.get("metrics", {}) as Dictionary
	metrics["tip_lock_origin_id"] = tip_lock_origin_id
	metrics["pommel_lock_origin_id"] = pommel_lock_origin_id
	preview_root.set_meta("authoring_contact_tether_metrics", metrics)
	return {
		"tip_position_local": trajectory_root.to_local(resolved_transform * local_tip),
		"tip_position_origin_id": CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING,
		"pommel_position_local": trajectory_root.to_local(resolved_transform * local_pommel),
		"pommel_position_origin_id": CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING,
		"tether_metrics": metrics,
		"tether_clamped": bool(metrics.get("clamped", false)),
	}

func reseat_motion_node_grip_to_occupied_contact(
	preview_subviewport: SubViewport,
	_active_wip: CraftedItemWIP,
	motion_node: CombatAnimationMotionNode
) -> Dictionary:
	var preview_root: Node3D = _get_preview_root(preview_subviewport)
	if preview_root == null or motion_node == null:
		return {}
	var actor: Node3D = preview_root.get_node_or_null(PREVIEW_ACTOR_PIVOT_NAME + "/" + PREVIEW_ACTOR_NAME) as Node3D
	var held_item: Node3D = _get_node_meta_or_default(preview_root, "preview_held_item", null) as Node3D
	var trajectory_root: Node3D = preview_root.find_child(TRAJECTORY_ROOT_NAME, true, false) as Node3D
	if actor == null or held_item == null or not is_instance_valid(held_item) or trajectory_root == null:
		return {}
	var local_tip: Vector3 = _get_weapon_tip_meta(held_item)
	var local_pommel: Vector3 = _get_weapon_pommel_meta(held_item)
	if local_tip.is_equal_approx(local_pommel):
		return {}
	_apply_preview_motion_grip_state(held_item, motion_node, {}, actor)
	var requested_grip_local: Vector3 = _get_preview_primary_grip_seat_meta(held_item)
	var authored_tip_world: Vector3 = trajectory_root.to_global(motion_node.tip_position_local)
	var authored_pommel_world: Vector3 = trajectory_root.to_global(motion_node.pommel_position_local)
	var solved_transform: Transform3D = held_item.global_transform
	if authored_tip_world.distance_to(authored_pommel_world) > SEGMENT_LEGALITY_EPSILON_METERS:
		solved_transform = _solve_weapon_segment_transform(
			held_item,
			trajectory_root,
			motion_node,
			local_tip,
			local_pommel,
			authored_tip_world,
			authored_pommel_world,
			_resolve_motion_node_weapon_orientation_degrees(motion_node)
		)
	else:
		solved_transform = _resolve_preview_hand_mounted_transform(actor, held_item)
	var target_world: Vector3 = _resolve_preview_primary_grip_target_world(actor, held_item)
	var reseated_transform: Transform3D = _lock_preview_transform_to_dominant_grip_target(
		solved_transform,
		requested_grip_local,
		target_world,
		1.0
	)
	held_item.global_transform = reseated_transform
	_apply_preview_resolved_grip_state(held_item)
	var grip_error: float = -1.0
	if target_world.length_squared() > 0.000001:
		grip_error = target_world.distance_to(reseated_transform * requested_grip_local)
	preview_root.set_meta("grip_seat_reseat_error_meters", grip_error)
	return {
		"tip_position_local": trajectory_root.to_local(reseated_transform * local_tip),
		"tip_position_origin_id": CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING,
		"pommel_position_local": trajectory_root.to_local(reseated_transform * local_pommel),
		"pommel_position_origin_id": CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING,
		"grip_seat_reseat_error_meters": grip_error,
	}

func resolve_motion_node_primary_grip_seat_local(
	preview_subviewport: SubViewport,
	motion_node: CombatAnimationMotionNode
) -> Variant:
	var preview_root: Node3D = _get_preview_root(preview_subviewport)
	if preview_root == null or motion_node == null:
		return null
	var actor: Node3D = preview_root.get_node_or_null(PREVIEW_ACTOR_PIVOT_NAME + "/" + PREVIEW_ACTOR_NAME) as Node3D
	var held_item: Node3D = _get_node_meta_or_default(preview_root, "preview_held_item", null) as Node3D
	var trajectory_root: Node3D = preview_root.find_child(TRAJECTORY_ROOT_NAME, true, false) as Node3D
	if held_item == null or not is_instance_valid(held_item) or trajectory_root == null:
		return null
	var local_tip: Vector3 = _get_weapon_tip_meta(held_item)
	var local_pommel: Vector3 = _get_weapon_pommel_meta(held_item)
	if local_tip.is_equal_approx(local_pommel):
		return null
	_apply_preview_motion_grip_state(held_item, motion_node, {}, actor)
	var requested_grip_local: Vector3 = _get_preview_primary_grip_seat_meta(held_item)
	var authored_tip_world: Vector3 = trajectory_root.to_global(motion_node.tip_position_local)
	var authored_pommel_world: Vector3 = trajectory_root.to_global(motion_node.pommel_position_local)
	var solved_transform: Transform3D = _solve_weapon_segment_transform(
		held_item,
		trajectory_root,
		motion_node,
		local_tip,
		local_pommel,
		authored_tip_world,
		authored_pommel_world,
		_resolve_motion_node_weapon_orientation_degrees(motion_node)
	)
	return trajectory_root.to_local(solved_transform * requested_grip_local)

func orbit_camera(preview_subviewport: SubViewport, drag_delta: Vector2) -> bool:
	var preview_root: Node3D = _get_preview_root(preview_subviewport)
	if preview_root == null:
		return false
	_ensure_camera_state(preview_root, _get_vector3_meta(preview_root, CAMERA_FOCUS_POINT_META, _resolve_camera_focus_point(null)))
	var orbit_yaw: float = float(_get_node_meta_or_default(preview_root, CAMERA_ORBIT_YAW_META, 0.0))
	var orbit_pitch: float = float(_get_node_meta_or_default(preview_root, CAMERA_ORBIT_PITCH_META, 0.0))
	orbit_yaw -= drag_delta.x * CAMERA_ORBIT_SENSITIVITY
	orbit_pitch = clampf(orbit_pitch + drag_delta.y * CAMERA_ORBIT_SENSITIVITY, CAMERA_MIN_PITCH_DEGREES, CAMERA_MAX_PITCH_DEGREES)
	preview_root.set_meta(CAMERA_ORBIT_YAW_META, orbit_yaw)
	preview_root.set_meta(CAMERA_ORBIT_PITCH_META, orbit_pitch)
	_apply_camera_transform(preview_root)
	return true

func zoom_camera(preview_subviewport: SubViewport, zoom_steps: int) -> bool:
	var preview_root: Node3D = _get_preview_root(preview_subviewport)
	if preview_root == null or zoom_steps == 0:
		return false
	_ensure_camera_state(preview_root, _get_vector3_meta(preview_root, CAMERA_FOCUS_POINT_META, _resolve_camera_focus_point(null)))
	var distance: float = float(_get_node_meta_or_default(preview_root, CAMERA_DISTANCE_META, CAMERA_DEFAULT_DISTANCE))
	distance = clampf(distance + (float(zoom_steps) * CAMERA_ZOOM_STEP), CAMERA_MIN_DISTANCE, CAMERA_MAX_DISTANCE)
	preview_root.set_meta(CAMERA_DISTANCE_META, distance)
	_apply_camera_transform(preview_root)
	return true

func capture_camera_state(preview_subviewport: SubViewport) -> Dictionary:
	var preview_root: Node3D = _get_preview_root(preview_subviewport)
	if preview_root == null:
		return {}
	var focus_point: Vector3 = _get_vector3_meta(preview_root, CAMERA_FOCUS_POINT_META, _resolve_camera_focus_point(null))
	_ensure_camera_state(preview_root, focus_point)
	return {
		"valid": true,
		"focus_point": _get_vector3_meta(preview_root, CAMERA_FOCUS_POINT_META, focus_point),
		"distance": float(_get_node_meta_or_default(preview_root, CAMERA_DISTANCE_META, CAMERA_DEFAULT_DISTANCE)),
		"orbit_yaw_degrees": float(_get_node_meta_or_default(preview_root, CAMERA_ORBIT_YAW_META, 0.0)),
		"orbit_pitch_degrees": float(_get_node_meta_or_default(preview_root, CAMERA_ORBIT_PITCH_META, 0.0)),
	}

func restore_camera_state(preview_subviewport: SubViewport, camera_state: Dictionary) -> bool:
	var preview_root: Node3D = _get_preview_root(preview_subviewport)
	if preview_root == null or not bool(camera_state.get("valid", false)):
		return false
	preview_root.set_meta(CAMERA_STATE_READY_META, true)
	preview_root.set_meta(CAMERA_FOCUS_POINT_META, camera_state.get("focus_point", Vector3(0.0, 1.1, 0.0)) as Vector3)
	preview_root.set_meta(CAMERA_DISTANCE_META, float(camera_state.get("distance", CAMERA_DEFAULT_DISTANCE)))
	preview_root.set_meta(CAMERA_ORBIT_YAW_META, float(camera_state.get("orbit_yaw_degrees", 0.0)))
	preview_root.set_meta(CAMERA_ORBIT_PITCH_META, float(camera_state.get("orbit_pitch_degrees", 0.0)))
	_apply_camera_transform(preview_root)
	return true

func ensure_baked_profile_snapshot(active_wip: CraftedItemWIP) -> BakedProfile:
	if active_wip == null:
		return null
	if CraftedItemWIP.is_unarmed_authoring_wip(active_wip):
		return null
	if active_wip.latest_baked_profile_snapshot != null:
		return active_wip.latest_baked_profile_snapshot
	return forge_service.bake_wip(active_wip, _get_material_lookup())

func _ensure_preview_nodes(preview_container: SubViewportContainer, preview_subviewport: SubViewport) -> Dictionary:
	if preview_subviewport == null:
		return {}
	preview_subviewport.own_world_3d = true
	preview_subviewport.transparent_bg = false
	preview_subviewport.handle_input_locally = false
	preview_subviewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	if preview_container != null:
		preview_container.stretch = false
	var preview_root: Node3D = preview_subviewport.get_node_or_null(PREVIEW_ROOT_NAME) as Node3D
	if preview_root == null:
		preview_root = Node3D.new()
		preview_root.name = PREVIEW_ROOT_NAME
		preview_subviewport.add_child(preview_root)
		preview_root.set_meta("preview_held_item", null)
		preview_root.set_meta("preview_wip_id", StringName())
		preview_root.set_meta("motion_node_count", 0)
		preview_root.set_meta("motion_node_marker_count", 0)
		preview_root.set_meta("selected_motion_node_index", -1)
		preview_root.set_meta("draft_point_count", 0)
		preview_root.set_meta("curve_baked_point_count", 0)
		preview_root.set_meta("point_marker_count", 0)
		preview_root.set_meta("control_handle_marker_count", 0)
		preview_root.set_meta("stow_anchor_marker_count", 0)
		preview_root.set_meta("stow_anchor_marker_ids", [])
		preview_root.set_meta("stow_anchor_marker_positions_local", {})
		preview_root.set_meta("stow_anchor_marker_positions_origin_id", CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING)
		preview_root.set_meta("stow_anchor_marker_position_origin_ids", {})
		preview_root.set_meta("selected_stow_anchor_marker_id", StringName())
		preview_root.set_meta("selected_stow_anchor_slot_id", StringName())
		preview_root.set_meta("selected_stow_anchor_mode", StringName())
		preview_root.set_meta("selected_stow_anchor_orientation_side", StringName())
		preview_root.set_meta(PREVIEW_POSE_MODE_META, StringName())
		preview_root.set_meta("weapon_gizmo_marker_count", 0)
		preview_root.set_meta("selected_point_index", -1)
		var actor_pivot := Node3D.new()
		actor_pivot.name = PREVIEW_ACTOR_PIVOT_NAME
		actor_pivot.rotation_degrees = Vector3(0.0, 24.0, 0.0)
		preview_root.add_child(actor_pivot)
		var trajectory_root := Node3D.new()
		trajectory_root.name = TRAJECTORY_ROOT_NAME
		preview_root.add_child(trajectory_root)
		var marker_root := Node3D.new()
		marker_root.name = MARKER_ROOT_NAME
		trajectory_root.add_child(marker_root)
		var onion_skin_root := Node3D.new()
		onion_skin_root.name = ONION_SKIN_MESH_NAME
		trajectory_root.add_child(onion_skin_root)
		var sphere_viz := MeshInstance3D.new()
		sphere_viz.name = SPHERE_VIZ_MESH_NAME
		sphere_viz.mesh = ImmediateMesh.new()
		sphere_viz.material_override = _build_line_material(Color(0.8, 0.55, 0.9, 0.3))
		trajectory_root.add_child(sphere_viz)
		var trajectory_mesh_instance := MeshInstance3D.new()
		trajectory_mesh_instance.name = TRAJECTORY_MESH_NAME
		trajectory_mesh_instance.mesh = ImmediateMesh.new()
		trajectory_mesh_instance.material_override = _build_line_material(Color(1.0, 0.86, 0.2, 1.0))
		trajectory_root.add_child(trajectory_mesh_instance)
		var control_mesh_instance := MeshInstance3D.new()
		control_mesh_instance.name = CONTROL_LINE_MESH_NAME
		control_mesh_instance.mesh = ImmediateMesh.new()
		control_mesh_instance.material_override = _build_line_material(Color(0.25, 0.85, 1.0, 1.0))
		trajectory_root.add_child(control_mesh_instance)
		var camera := Camera3D.new()
		camera.name = PREVIEW_CAMERA_NAME
		camera.current = true
		preview_root.add_child(camera)
		var key_light := DirectionalLight3D.new()
		key_light.name = "PreviewKeyLight"
		key_light.light_energy = 2.2
		key_light.rotation_degrees = Vector3(-42.0, 28.0, 0.0)
		preview_root.add_child(key_light)
		var fill_light := DirectionalLight3D.new()
		fill_light.name = "PreviewFillLight"
		fill_light.light_energy = 0.9
		fill_light.rotation_degrees = Vector3(-18.0, -122.0, 0.0)
		preview_root.add_child(fill_light)
		var preview_floor := MeshInstance3D.new()
		preview_floor.name = PREVIEW_FLOOR_NAME
		var floor_mesh := BoxMesh.new()
		floor_mesh.size = Vector3(5.5, 0.02, 5.5)
		preview_floor.mesh = floor_mesh
		preview_floor.position = Vector3(0.0, -0.01, 0.0)
		preview_floor.material_override = _build_surface_material(Color(0.17, 0.19, 0.22, 1.0), 0.92)
		preview_root.add_child(preview_floor)
	_update_camera(preview_root, null)
	return {
		"preview_root": preview_root,
		"actor_pivot": preview_root.find_child(PREVIEW_ACTOR_PIVOT_NAME, true, false) as Node3D,
		"trajectory_root": preview_root.find_child(TRAJECTORY_ROOT_NAME, true, false) as Node3D,
		"marker_root": preview_root.find_child(MARKER_ROOT_NAME, true, false) as Node3D,
		"onion_skin_root": preview_root.find_child(ONION_SKIN_MESH_NAME, true, false) as Node3D,
		"sphere_viz_mesh": preview_root.find_child(SPHERE_VIZ_MESH_NAME, true, false) as MeshInstance3D,
		"trajectory_mesh": preview_root.find_child(TRAJECTORY_MESH_NAME, true, false) as MeshInstance3D,
		"control_mesh": preview_root.find_child(CONTROL_LINE_MESH_NAME, true, false) as MeshInstance3D,
	}

func _sync_preview_size(preview_container: SubViewportContainer, preview_subviewport: SubViewport) -> void:
	if preview_container == null or preview_subviewport == null:
		return
	var target_size := Vector2i(
		maxi(int(round(preview_container.size.x)), 1),
		maxi(int(round(preview_container.size.y)), 1)
	)
	if preview_subviewport.size != target_size:
		preview_subviewport.size = target_size

func _refresh_actor_and_weapon(
	state: Dictionary,
	active_wip: CraftedItemWIP,
	selected_motion_node: CombatAnimationMotionNode,
	active_draft: Resource = null
) -> void:
	var preview_root: Node3D = state.get("preview_root", null) as Node3D
	var actor_pivot: Node3D = state.get("actor_pivot", null) as Node3D
	if preview_root == null or actor_pivot == null:
		return
	var actor: Node3D = actor_pivot.get_node_or_null(PREVIEW_ACTOR_NAME) as Node3D
	if actor == null:
		actor = PlayerHumanoidRigScene.instantiate() as Node3D
		if actor == null:
			return
		actor.name = PREVIEW_ACTOR_NAME
		actor_pivot.add_child(actor)
		if actor.has_method("set_upper_body_authoring_auto_apply_enabled"):
			actor.call("set_upper_body_authoring_auto_apply_enabled", false)
		actor.set_process(false)
	_clear_preview_runtime_solved_replay_state(actor, preview_root)
	var held_item: Node3D = _get_node_meta_or_default(preview_root, "preview_held_item", null) as Node3D
	var current_wip_id: StringName = _get_node_meta_or_default(preview_root, "preview_wip_id", StringName()) as StringName
	var current_slot_id: StringName = _get_node_meta_or_default(preview_root, PREVIEW_ACTIVE_SLOT_ID_META, &"hand_right") as StringName
	var target_slot_id: StringName = _resolve_preview_dominant_slot_id()
	if active_wip == null:
		if actor != null and actor.has_method("clear_arm_guidance_target"):
			actor.call("clear_arm_guidance_target", &"hand_right")
			actor.call("clear_arm_guidance_target", &"hand_left")
		if actor != null and actor.has_method("clear_arm_guidance_active"):
			actor.call("clear_arm_guidance_active", &"hand_right")
			actor.call("clear_arm_guidance_active", &"hand_left")
		if actor != null and actor.has_method("clear_finger_grip_target"):
			actor.call("clear_finger_grip_target", &"hand_right")
			actor.call("clear_finger_grip_target", &"hand_left")
		if actor != null and actor.has_method("set_support_hand_active"):
			actor.call("set_support_hand_active", &"hand_right", false)
			actor.call("set_support_hand_active", &"hand_left", false)
		if actor != null and actor.has_method("clear_upper_body_authoring_state"):
			actor.call("clear_upper_body_authoring_state")
		if held_item != null and is_instance_valid(held_item):
			held_item.queue_free()
		preview_root.set_meta("preview_held_item", null)
		preview_root.set_meta("preview_wip_id", StringName())
		preview_root.set_meta(PREVIEW_ACTIVE_SLOT_ID_META, target_slot_id)
		_update_camera(preview_root, null)
		return
	if held_item == null or not is_instance_valid(held_item) or current_wip_id != active_wip.wip_id or current_slot_id != target_slot_id:
		if held_item != null and is_instance_valid(held_item):
			held_item.queue_free()
		held_item = _build_weapon_preview_node(preview_root, actor, active_wip)
		preview_root.set_meta("preview_held_item", held_item)
		preview_root.set_meta("preview_wip_id", active_wip.wip_id)
		preview_root.set_meta(PREVIEW_ACTIVE_SLOT_ID_META, target_slot_id)
	var body_authored_motion_node: CombatAnimationMotionNode = null if _is_noncombat_idle_draft(active_draft) else selected_motion_node
	_configure_preview_actor_authoring_mode(actor, held_item, body_authored_motion_node)
	_ensure_preview_weapon_parent(preview_root, held_item)
	if selected_motion_node == null:
		_apply_preview_hand_mounted_transform(actor, held_item)
		_apply_two_hand_preview_state(actor, held_item, selected_motion_node)
		_apply_preview_upper_body_authoring_state(actor, held_item, selected_motion_node)
		_apply_preview_actor_upper_body_pose_now(actor)
		_update_camera(preview_root, weapon_grip_anchor_provider.get_primary_grip_anchor(held_item))

func _configure_preview_actor_authoring_mode(
	actor: Node3D,
	held_item: Node3D,
	selected_motion_node: CombatAnimationMotionNode
) -> void:
	if actor == null or not actor.has_method("set_authoring_preview_mode_enabled"):
		return
	actor.call(
		"set_authoring_preview_mode_enabled",
		true,
		_resolve_preview_authoring_baseline_animation_name(actor, held_item, selected_motion_node)
	)
	actor.set_process(false)

func _resolve_preview_authoring_baseline_animation_name(
	actor: Node3D,
	held_item: Node3D,
	selected_motion_node: CombatAnimationMotionNode
) -> StringName:
	if actor == null:
		return StringName()
	var baseline_animation_name: StringName = StringName(actor.get("default_animation_name"))
	if _should_preview_use_support_hand(held_item, selected_motion_node):
		var two_hand_animation_name: StringName = StringName(actor.get("two_hand_idle_animation_name"))
		if two_hand_animation_name != StringName():
			baseline_animation_name = two_hand_animation_name
	return baseline_animation_name

func _build_speed_state_config(active_draft: Resource) -> Dictionary:
	if active_draft == null:
		return {}
	return {
		"acceleration_percent": float(active_draft.get("speed_acceleration_percent")),
		"deceleration_percent": float(active_draft.get("speed_deceleration_percent")),
		"armed_speed_threshold_mps": 1.0,
		"samples_per_segment": 12,
		"startup_segment_count": 0,
	}

func _refresh_drag_budgeted_visuals(
	state: Dictionary,
	motion_node_chain: Array,
	selected_node_index: int,
	active_focus: StringName = &"tip",
	active_draft: Resource = null
) -> void:
	var preview_root: Node3D = state.get("preview_root", null) as Node3D
	var trajectory_root: Node3D = state.get("trajectory_root", null) as Node3D
	var marker_root: Node3D = state.get("marker_root", null) as Node3D
	var trajectory_mesh_instance: MeshInstance3D = state.get("trajectory_mesh", null) as MeshInstance3D
	var control_mesh_instance: MeshInstance3D = state.get("control_mesh", null) as MeshInstance3D
	var sphere_viz_mesh: MeshInstance3D = state.get("sphere_viz_mesh", null) as MeshInstance3D
	var onion_skin_root: Node3D = state.get("onion_skin_root", null) as Node3D
	if preview_root == null or trajectory_root == null or marker_root == null:
		return
	if not bool(preview_root.get_meta("drag_budgeted_markers_active", false)):
		_clear_child_nodes(marker_root)
		_clear_child_nodes(onion_skin_root)
		preview_root.set_meta("drag_budgeted_markers_active", true)
	_clear_immediate_mesh(trajectory_mesh_instance)
	_clear_immediate_mesh(control_mesh_instance)
	_clear_immediate_mesh(sphere_viz_mesh)
	preview_root.set_meta("motion_node_count", motion_node_chain.size())
	preview_root.set_meta("draft_point_count", motion_node_chain.size())
	preview_root.set_meta("curve_baked_point_count", 0)
	preview_root.set_meta("speed_state_sample_count", 0)
	preview_root.set_meta("speed_state_armed_sample_count", 0)
	preview_root.set_meta("speed_state_buildup_sample_count", 0)
	preview_root.set_meta("speed_state_reset_sample_count", 0)
	preview_root.set_meta("collision_path_legal", true)
	preview_root.set_meta("collision_path_sample_count", 0)
	preview_root.set_meta("collision_path_illegal_pose_count", 0)
	preview_root.set_meta("selected_motion_node_index", selected_node_index)
	preview_root.set_meta("selected_point_index", selected_node_index)
	preview_root.set_meta("weapon_gizmo_marker_count", 0)
	preview_root.set_meta("upperarm_roll_gizmo_state", {})
	preview_root.set_meta("upperarm_roll_gizmo_count", 0)
	_clear_stow_anchor_markers(marker_root)
	var stow_anchor_result: Dictionary = _refresh_noncombat_stow_anchor_markers(state, active_draft)
	preview_root.set_meta("stow_anchor_marker_count", int(stow_anchor_result.get("count", 0)))
	preview_root.set_meta("stow_anchor_marker_ids", stow_anchor_result.get("ids", []))
	preview_root.set_meta("stow_anchor_marker_positions_local", stow_anchor_result.get("positions_local", {}))
	preview_root.set_meta("stow_anchor_marker_positions_origin_id", stow_anchor_result.get("positions_origin_id", CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING))
	preview_root.set_meta("stow_anchor_marker_position_origin_ids", stow_anchor_result.get("position_origin_ids", {}))
	preview_root.set_meta("selected_stow_anchor_marker_id", stow_anchor_result.get("selected_id", StringName()))
	preview_root.set_meta("selected_stow_anchor_slot_id", stow_anchor_result.get("slot_id", StringName()))
	preview_root.set_meta("selected_stow_anchor_mode", stow_anchor_result.get("mode", StringName()))
	preview_root.set_meta("selected_stow_anchor_orientation_side", stow_anchor_result.get("orientation_side", StringName()))
	if selected_node_index < 0 or selected_node_index >= motion_node_chain.size():
		_set_drag_visual_markers_visible(marker_root, false)
		return
	var motion_node: CombatAnimationMotionNode = motion_node_chain[selected_node_index] as CombatAnimationMotionNode
	if motion_node == null:
		_set_drag_visual_markers_visible(marker_root, false)
		return
	var tip_active: bool = active_focus == CombatAnimationSessionStateScript.FOCUS_TIP
	var pommel_active: bool = active_focus == CombatAnimationSessionStateScript.FOCUS_POMMEL
	_set_origin_tracked_vector3_meta(
		preview_root,
		"display_selected_tip_position_local",
		"display_selected_tip_position_origin_id",
		motion_node.tip_position_local,
		motion_node.tip_position_origin_id
	)
	_set_origin_tracked_vector3_meta(
		preview_root,
		"display_selected_pommel_position_local",
		"display_selected_pommel_position_origin_id",
		motion_node.pommel_position_local,
		motion_node.pommel_position_origin_id
	)
	_update_drag_point_marker(marker_root, "DragTipMarker", motion_node.tip_position_local, tip_active)
	_update_drag_point_marker(marker_root, "DragPommelMarker", motion_node.pommel_position_local, pommel_active)
	_sync_drag_curve_handle_markers(marker_root, motion_node_chain, selected_node_index, motion_node)
	_sync_drag_weapon_orientation_markers(marker_root, motion_node, active_focus)
	var upperarm_marker_count: int = 0
	if active_focus == CombatAnimationSessionStateScript.FOCUS_ARM_ROLL:
		_clear_upperarm_roll_gizmo_markers(marker_root)
		upperarm_marker_count = _create_upperarm_roll_gizmo_markers(state, motion_node, active_focus)
	preview_root.set_meta("motion_node_marker_count", 2)
	preview_root.set_meta("point_marker_count", 2)
	preview_root.set_meta("weapon_gizmo_marker_count", 2 + upperarm_marker_count)

func _clear_child_nodes(root: Node) -> void:
	if root == null:
		return
	for child_node: Node in root.get_children():
		child_node.queue_free()

func _clear_immediate_mesh(mesh_instance: MeshInstance3D) -> void:
	if mesh_instance != null and mesh_instance.mesh is ImmediateMesh:
		(mesh_instance.mesh as ImmediateMesh).clear_surfaces()

func _set_drag_visual_markers_visible(marker_root: Node3D, visible: bool) -> void:
	if marker_root == null:
		return
	for marker_name in [
		"DragTipMarker",
		"DragPommelMarker",
		"DragTipInHandle",
		"DragTipOutHandle",
		"DragPomInHandle",
		"DragPomOutHandle",
		"DragWeaponCenterMarker",
		"DragWeaponNormalMarker",
		"RightUpperarmRollCenter",
		"RightUpperarmRollHandle",
		"RightUpperarmRollRod",
		"LeftUpperarmRollCenter",
		"LeftUpperarmRollHandle",
		"LeftUpperarmRollRod",
	]:
		var marker: Node3D = marker_root.get_node_or_null(String(marker_name)) as Node3D
		if marker != null:
			marker.visible = visible

func _update_drag_point_marker(marker_root: Node3D, marker_name: String, local_position: Vector3, active: bool) -> void:
	var marker: MeshInstance3D = marker_root.get_node_or_null(marker_name) as MeshInstance3D
	if marker == null:
		marker = MeshInstance3D.new()
		marker.name = marker_name
		var mesh := SphereMesh.new()
		mesh.radius = (0.022 if active else 0.016) * CONTROL_MARKER_SIZE_MULTIPLIER
		mesh.height = mesh.radius * 2.0
		marker.mesh = mesh
		marker_root.add_child(marker)
	marker.visible = true
	marker.position = local_position
	marker.material_override = _build_overlay_surface_material(Color(1.0, 0.33, 0.24, 1.0) if active else Color(0.92, 0.92, 0.92, 1.0), 0.35)

func _sync_drag_curve_handle_markers(
	marker_root: Node3D,
	motion_node_chain: Array,
	selected_node_index: int,
	motion_node: CombatAnimationMotionNode
) -> void:
	var tip_curve_in_handle: Vector3 = motion_node_editor.resolve_effective_curve_handle(motion_node_chain, selected_node_index, true, true)
	var tip_curve_out_handle: Vector3 = motion_node_editor.resolve_effective_curve_handle(motion_node_chain, selected_node_index, true, false)
	var pommel_curve_in_handle: Vector3 = motion_node_editor.resolve_effective_curve_handle(motion_node_chain, selected_node_index, false, true)
	var pommel_curve_out_handle: Vector3 = motion_node_editor.resolve_effective_curve_handle(motion_node_chain, selected_node_index, false, false)
	_update_drag_handle_marker(marker_root, "DragTipInHandle", motion_node.tip_position_local + tip_curve_in_handle, Color(0.2, 0.75, 1.0, 1.0), tip_curve_in_handle.length() >= CURVE_HANDLE_VISUAL_MIN_LENGTH_METERS)
	_update_drag_handle_marker(marker_root, "DragTipOutHandle", motion_node.tip_position_local + tip_curve_out_handle, Color(1.0, 0.55, 0.12, 1.0), tip_curve_out_handle.length() >= CURVE_HANDLE_VISUAL_MIN_LENGTH_METERS)
	_update_drag_handle_marker(marker_root, "DragPomInHandle", motion_node.pommel_position_local + pommel_curve_in_handle, Color(0.2, 0.55, 0.85, 1.0), pommel_curve_in_handle.length() >= CURVE_HANDLE_VISUAL_MIN_LENGTH_METERS)
	_update_drag_handle_marker(marker_root, "DragPomOutHandle", motion_node.pommel_position_local + pommel_curve_out_handle, Color(0.85, 0.4, 0.12, 1.0), pommel_curve_out_handle.length() >= CURVE_HANDLE_VISUAL_MIN_LENGTH_METERS)

func _update_drag_handle_marker(marker_root: Node3D, marker_name: String, local_position: Vector3, color: Color, visible: bool) -> void:
	var marker: MeshInstance3D = marker_root.get_node_or_null(marker_name) as MeshInstance3D
	if marker == null:
		marker = MeshInstance3D.new()
		marker.name = marker_name
		var mesh := BoxMesh.new()
		mesh.size = Vector3.ONE * BEZIER_CONTROL_MARKER_SIZE_METERS
		marker.mesh = mesh
		marker.material_override = _build_surface_material(color, 0.45)
		marker_root.add_child(marker)
	marker.visible = visible
	marker.position = local_position

func _sync_drag_weapon_orientation_markers(marker_root: Node3D, motion_node: CombatAnimationMotionNode, active_focus: StringName) -> void:
	var weapon_focus_active: bool = active_focus == CombatAnimationSessionStateScript.FOCUS_WEAPON
	var weapon_center: Vector3 = motion_node.tip_position_local.lerp(motion_node.pommel_position_local, 0.5)
	var weapon_normal_handle: Vector3 = weapon_center + _resolve_weapon_rotation_normal_local(motion_node) * WEAPON_ROTATION_GIZMO_HANDLE_DISTANCE
	_update_drag_gizmo_marker(marker_root, "DragWeaponCenterMarker", weapon_center, Color(0.95, 0.58, 0.26, 1.0) if weapon_focus_active else Color(0.72, 0.48, 0.22, 0.65), weapon_focus_active)
	_update_drag_gizmo_marker(marker_root, "DragWeaponNormalMarker", weapon_normal_handle, Color(0.42, 0.98, 0.72, 1.0) if weapon_focus_active else Color(0.28, 0.72, 0.56, 0.65), weapon_focus_active)

func _update_drag_gizmo_marker(marker_root: Node3D, marker_name: String, local_position: Vector3, color: Color, visible: bool) -> void:
	var marker: MeshInstance3D = marker_root.get_node_or_null(marker_name) as MeshInstance3D
	if marker == null:
		marker = MeshInstance3D.new()
		marker.name = marker_name
		var mesh := SphereMesh.new()
		mesh.radius = 0.014 * CONTROL_MARKER_SIZE_MULTIPLIER
		mesh.height = mesh.radius * 2.0
		marker.mesh = mesh
		marker_root.add_child(marker)
	marker.visible = visible
	marker.position = local_position
	marker.material_override = _build_overlay_surface_material(color, 0.24)

func _clear_upperarm_roll_gizmo_markers(marker_root: Node3D) -> void:
	if marker_root == null:
		return
	for child_node: Node in marker_root.get_children():
		var child_name: String = String(child_node.name)
		if child_name.begins_with("RightUpperarmRoll") or child_name.begins_with("LeftUpperarmRoll"):
			marker_root.remove_child(child_node)
			child_node.queue_free()

func _clear_stow_anchor_markers(marker_root: Node3D) -> void:
	if marker_root == null:
		return
	for child_node: Node in marker_root.get_children():
		if String(child_node.name).begins_with("StowAnchorMarker_"):
			marker_root.remove_child(child_node)
			child_node.queue_free()

func _refresh_trajectory_visuals(
	state: Dictionary,
	motion_node_chain: Array,
	selected_node_index: int,
	active_focus: StringName = &"tip",
	playback_state: Dictionary = {},
	speed_state_config: Dictionary = {},
	active_draft: Resource = null
) -> void:
	var preview_root: Node3D = state.get("preview_root", null) as Node3D
	var trajectory_root: Node3D = state.get("trajectory_root", null) as Node3D
	var marker_root: Node3D = state.get("marker_root", null) as Node3D
	var trajectory_mesh_instance: MeshInstance3D = state.get("trajectory_mesh", null) as MeshInstance3D
	var control_mesh_instance: MeshInstance3D = state.get("control_mesh", null) as MeshInstance3D
	var onion_skin_root: Node3D = state.get("onion_skin_root", null) as Node3D
	if preview_root == null or trajectory_root == null or marker_root == null or trajectory_mesh_instance == null or control_mesh_instance == null:
		return
	var playback_active: bool = bool(playback_state.get("active", false))
	var authoring_drag_active: bool = bool(playback_state.get("authoring_drag_active", false))
	var authoring_drag_lightweight: bool = authoring_drag_active and bool(playback_state.get("authoring_drag_lightweight", false))
	var static_visual_signature: String = _build_trajectory_static_visual_signature(
		motion_node_chain,
		speed_state_config,
		active_draft,
		authoring_drag_lightweight
	)
	var requested_static_signature: String = String(playback_state.get("trajectory_static_visual_signature", ""))
	if not requested_static_signature.is_empty():
		static_visual_signature = requested_static_signature
	if (
		not playback_active
		and not authoring_drag_active
		and String(preview_root.get_meta("trajectory_static_visual_signature", "")) == static_visual_signature
	):
		_refresh_trajectory_selection_visuals(
			state,
			motion_node_chain,
			selected_node_index,
			active_focus,
			active_draft
		)
		return
	preview_root.set_meta("drag_budgeted_markers_active", false)
	_prepare_trajectory_root_for_authoring(state)
	for child_node: Node in marker_root.get_children():
		child_node.queue_free()
	if onion_skin_root != null:
		for child_node: Node in onion_skin_root.get_children():
			child_node.queue_free()
	var tip_curve: Curve3D = motion_node_editor.build_tip_curve(motion_node_chain)
	var pommel_curve: Curve3D = motion_node_editor.build_pommel_curve(motion_node_chain)
	var node_marker_count: int = 0
	var handle_marker_count: int = 0
	var stow_anchor_result: Dictionary = _refresh_noncombat_stow_anchor_markers(state, active_draft)
	var tip_is_active_focus: bool = active_focus == CombatAnimationSessionStateScript.FOCUS_TIP and not playback_active
	var pommel_is_active_focus: bool = active_focus == CombatAnimationSessionStateScript.FOCUS_POMMEL and not playback_active
	_set_origin_tracked_vector3_meta(
		preview_root,
		"display_selected_tip_position_local",
		"display_selected_tip_position_origin_id",
		Vector3.ZERO,
		CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING
	)
	_set_origin_tracked_vector3_meta(
		preview_root,
		"display_selected_pommel_position_local",
		"display_selected_pommel_position_origin_id",
		Vector3.ZERO,
		CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING
	)
	for node_index: int in range(motion_node_chain.size()):
		var motion_node: CombatAnimationMotionNode = motion_node_chain[node_index] as CombatAnimationMotionNode
		if motion_node == null:
			continue
		var is_selected: bool = node_index == selected_node_index
		var tip_marker_active: bool = is_selected and tip_is_active_focus
		var pommel_marker_active: bool = is_selected and pommel_is_active_focus
		_create_point_marker(marker_root, motion_node.tip_position_local, tip_marker_active)
		_create_point_marker(marker_root, motion_node.pommel_position_local, pommel_marker_active)
		if is_selected:
			_set_origin_tracked_vector3_meta(
				preview_root,
				"display_selected_tip_position_local",
				"display_selected_tip_position_origin_id",
				motion_node.tip_position_local,
				motion_node.tip_position_origin_id
			)
			_set_origin_tracked_vector3_meta(
				preview_root,
				"display_selected_pommel_position_local",
				"display_selected_pommel_position_origin_id",
				motion_node.pommel_position_local,
				motion_node.pommel_position_origin_id
			)
			var tip_curve_in_handle: Vector3 = motion_node_editor.resolve_effective_curve_handle(motion_node_chain, node_index, true, true)
			var tip_curve_out_handle: Vector3 = motion_node_editor.resolve_effective_curve_handle(motion_node_chain, node_index, true, false)
			var pommel_curve_in_handle: Vector3 = motion_node_editor.resolve_effective_curve_handle(motion_node_chain, node_index, false, true)
			var pommel_curve_out_handle: Vector3 = motion_node_editor.resolve_effective_curve_handle(motion_node_chain, node_index, false, false)
			if tip_curve_in_handle.length() >= CURVE_HANDLE_VISUAL_MIN_LENGTH_METERS:
				_create_handle_marker(marker_root, motion_node.tip_position_local + tip_curve_in_handle, Color(0.2, 0.75, 1.0, 1.0), "TipIn")
				handle_marker_count += 1
			if tip_curve_out_handle.length() >= CURVE_HANDLE_VISUAL_MIN_LENGTH_METERS:
				_create_handle_marker(marker_root, motion_node.tip_position_local + tip_curve_out_handle, Color(1.0, 0.55, 0.12, 1.0), "TipOut")
				handle_marker_count += 1
			if pommel_curve_in_handle.length() >= CURVE_HANDLE_VISUAL_MIN_LENGTH_METERS:
				_create_handle_marker(marker_root, motion_node.pommel_position_local + pommel_curve_in_handle, Color(0.2, 0.55, 0.85, 1.0), "PomIn")
				handle_marker_count += 1
			if pommel_curve_out_handle.length() >= CURVE_HANDLE_VISUAL_MIN_LENGTH_METERS:
				_create_handle_marker(marker_root, motion_node.pommel_position_local + pommel_curve_out_handle, Color(0.85, 0.4, 0.12, 1.0), "PomOut")
				handle_marker_count += 1
		node_marker_count += 2
	if playback_active:
		var playback_tip_position_local: Vector3 = _get_origin_tracked_vector3_state(
			playback_state,
			"tip_position_local",
			"tip_position_origin_id",
			Vector3.ZERO,
			CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING
		)
		var playback_pommel_position_local: Vector3 = _get_origin_tracked_vector3_state(
			playback_state,
			"pommel_position_local",
			"pommel_position_origin_id",
			Vector3.ZERO,
			CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING
		)
		_create_playback_marker(marker_root, playback_tip_position_local, Color(1.0, 0.78, 0.22, 1.0), "PlaybackTip")
		_create_playback_marker(marker_root, playback_pommel_position_local, Color(0.56, 0.82, 1.0, 1.0), "PlaybackPommel")
	var speed_state_result: Dictionary = {"sample_count": 0, "samples": []}
	if not authoring_drag_lightweight:
		speed_state_result = speed_state_sampler.sample_motion_chain(
			motion_node_chain,
			tip_curve,
			pommel_curve,
			speed_state_config
		)
	var collision_path_result: Dictionary = {"legal": true, "path_sample_count": 0}
	if not authoring_drag_active:
		collision_path_result = _evaluate_preview_collision_path(state, motion_node_chain, speed_state_result)
	if authoring_drag_lightweight:
		_render_lightweight_curve_mesh(trajectory_mesh_instance.mesh as ImmediateMesh, tip_curve, pommel_curve)
	else:
		_render_speed_colored_curve_mesh(trajectory_mesh_instance.mesh as ImmediateMesh, speed_state_result)
	_render_control_lines(control_mesh_instance.mesh as ImmediateMesh, motion_node_chain, selected_node_index)
	if not authoring_drag_active:
		_refresh_onion_skin(onion_skin_root, motion_node_chain, selected_node_index)
	preview_root.set_meta("motion_node_count", motion_node_chain.size())
	preview_root.set_meta("draft_point_count", motion_node_chain.size())
	var tip_baked_count: int = tip_curve.get_baked_points().size() if _curve_has_distinct_points(tip_curve) else 0
	preview_root.set_meta("curve_baked_point_count", tip_baked_count)
	preview_root.set_meta("speed_state_sample_count", int(speed_state_result.get("sample_count", 0)))
	preview_root.set_meta("speed_state_armed_sample_count", int(speed_state_result.get("armed_sample_count", 0)))
	preview_root.set_meta("speed_state_buildup_sample_count", int(speed_state_result.get("buildup_sample_count", 0)))
	preview_root.set_meta("speed_state_reset_sample_count", int(speed_state_result.get("reset_sample_count", 0)))
	preview_root.set_meta("speed_state_max_effective_speed_mps", float(speed_state_result.get("max_effective_speed_mps", 0.0)))
	preview_root.set_meta("speed_state_acceleration_percent", float(speed_state_result.get("acceleration_percent", 0.0)))
	preview_root.set_meta("speed_state_deceleration_percent", float(speed_state_result.get("deceleration_percent", 0.0)))
	preview_root.set_meta("collision_path_legal", bool(collision_path_result.get("legal", true)))
	preview_root.set_meta("collision_path_sample_count", int(collision_path_result.get("path_sample_count", 0)))
	preview_root.set_meta("collision_path_illegal_pose_count", int(collision_path_result.get("illegal_pose_count", 0)))
	preview_root.set_meta("collision_path_first_illegal_index", int(collision_path_result.get("first_illegal_path_index", -1)))
	preview_root.set_meta("collision_path_region", String(collision_path_result.get("colliding_body_region", "")))
	preview_root.set_meta("motion_node_marker_count", node_marker_count)
	preview_root.set_meta("point_marker_count", node_marker_count)
	preview_root.set_meta("control_handle_marker_count", handle_marker_count)
	preview_root.set_meta("stow_anchor_marker_count", int(stow_anchor_result.get("count", 0)))
	preview_root.set_meta("stow_anchor_marker_ids", stow_anchor_result.get("ids", []))
	preview_root.set_meta("stow_anchor_marker_positions_local", stow_anchor_result.get("positions_local", {}))
	preview_root.set_meta("stow_anchor_marker_positions_origin_id", stow_anchor_result.get("positions_origin_id", CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING))
	preview_root.set_meta("stow_anchor_marker_position_origin_ids", stow_anchor_result.get("position_origin_ids", {}))
	preview_root.set_meta("selected_stow_anchor_marker_id", stow_anchor_result.get("selected_id", StringName()))
	preview_root.set_meta("selected_stow_anchor_slot_id", stow_anchor_result.get("slot_id", StringName()))
	preview_root.set_meta("selected_stow_anchor_mode", stow_anchor_result.get("mode", StringName()))
	preview_root.set_meta("selected_stow_anchor_orientation_side", stow_anchor_result.get("orientation_side", StringName()))
	preview_root.set_meta("selected_motion_node_index", selected_node_index)
	preview_root.set_meta("selected_point_index", selected_node_index)
	preview_root.set_meta("trajectory_static_visual_signature", static_visual_signature if not playback_active and not authoring_drag_active else "")

func _refresh_trajectory_selection_visuals(
	state: Dictionary,
	motion_node_chain: Array,
	selected_node_index: int,
	active_focus: StringName = &"tip",
	active_draft: Resource = null
) -> void:
	var preview_root: Node3D = state.get("preview_root", null) as Node3D
	var marker_root: Node3D = state.get("marker_root", null) as Node3D
	var control_mesh_instance: MeshInstance3D = state.get("control_mesh", null) as MeshInstance3D
	if preview_root == null or marker_root == null or control_mesh_instance == null:
		return
	for child_node: Node in marker_root.get_children():
		child_node.queue_free()
	var node_marker_count: int = 0
	var handle_marker_count: int = 0
	var stow_anchor_result: Dictionary = _refresh_noncombat_stow_anchor_markers(state, active_draft)
	var tip_is_active_focus: bool = active_focus == CombatAnimationSessionStateScript.FOCUS_TIP
	var pommel_is_active_focus: bool = active_focus == CombatAnimationSessionStateScript.FOCUS_POMMEL
	_set_origin_tracked_vector3_meta(
		preview_root,
		"display_selected_tip_position_local",
		"display_selected_tip_position_origin_id",
		Vector3.ZERO,
		CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING
	)
	_set_origin_tracked_vector3_meta(
		preview_root,
		"display_selected_pommel_position_local",
		"display_selected_pommel_position_origin_id",
		Vector3.ZERO,
		CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING
	)
	for node_index: int in range(motion_node_chain.size()):
		var motion_node: CombatAnimationMotionNode = motion_node_chain[node_index] as CombatAnimationMotionNode
		if motion_node == null:
			continue
		var is_selected: bool = node_index == selected_node_index
		_create_point_marker(marker_root, motion_node.tip_position_local, is_selected and tip_is_active_focus)
		_create_point_marker(marker_root, motion_node.pommel_position_local, is_selected and pommel_is_active_focus)
		if is_selected:
			_set_origin_tracked_vector3_meta(
				preview_root,
				"display_selected_tip_position_local",
				"display_selected_tip_position_origin_id",
				motion_node.tip_position_local,
				motion_node.tip_position_origin_id
			)
			_set_origin_tracked_vector3_meta(
				preview_root,
				"display_selected_pommel_position_local",
				"display_selected_pommel_position_origin_id",
				motion_node.pommel_position_local,
				motion_node.pommel_position_origin_id
			)
			var tip_curve_in_handle: Vector3 = motion_node_editor.resolve_effective_curve_handle(motion_node_chain, node_index, true, true)
			var tip_curve_out_handle: Vector3 = motion_node_editor.resolve_effective_curve_handle(motion_node_chain, node_index, true, false)
			var pommel_curve_in_handle: Vector3 = motion_node_editor.resolve_effective_curve_handle(motion_node_chain, node_index, false, true)
			var pommel_curve_out_handle: Vector3 = motion_node_editor.resolve_effective_curve_handle(motion_node_chain, node_index, false, false)
			if tip_curve_in_handle.length() >= CURVE_HANDLE_VISUAL_MIN_LENGTH_METERS:
				_create_handle_marker(marker_root, motion_node.tip_position_local + tip_curve_in_handle, Color(0.2, 0.75, 1.0, 1.0), "TipIn")
				handle_marker_count += 1
			if tip_curve_out_handle.length() >= CURVE_HANDLE_VISUAL_MIN_LENGTH_METERS:
				_create_handle_marker(marker_root, motion_node.tip_position_local + tip_curve_out_handle, Color(1.0, 0.55, 0.12, 1.0), "TipOut")
				handle_marker_count += 1
			if pommel_curve_in_handle.length() >= CURVE_HANDLE_VISUAL_MIN_LENGTH_METERS:
				_create_handle_marker(marker_root, motion_node.pommel_position_local + pommel_curve_in_handle, Color(0.2, 0.55, 0.85, 1.0), "PomIn")
				handle_marker_count += 1
			if pommel_curve_out_handle.length() >= CURVE_HANDLE_VISUAL_MIN_LENGTH_METERS:
				_create_handle_marker(marker_root, motion_node.pommel_position_local + pommel_curve_out_handle, Color(0.85, 0.4, 0.12, 1.0), "PomOut")
				handle_marker_count += 1
		node_marker_count += 2
	_render_control_lines(control_mesh_instance.mesh as ImmediateMesh, motion_node_chain, selected_node_index)
	preview_root.set_meta("selected_motion_node_index", selected_node_index)
	preview_root.set_meta("selected_point_index", selected_node_index)
	preview_root.set_meta("motion_node_marker_count", node_marker_count)
	preview_root.set_meta("point_marker_count", node_marker_count)
	preview_root.set_meta("control_handle_marker_count", handle_marker_count)
	preview_root.set_meta("stow_anchor_marker_count", int(stow_anchor_result.get("count", 0)))
	preview_root.set_meta("stow_anchor_marker_ids", stow_anchor_result.get("ids", []))
	preview_root.set_meta("stow_anchor_marker_positions_local", stow_anchor_result.get("positions_local", {}))
	preview_root.set_meta("stow_anchor_marker_positions_origin_id", stow_anchor_result.get("positions_origin_id", CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING))
	preview_root.set_meta("stow_anchor_marker_position_origin_ids", stow_anchor_result.get("position_origin_ids", {}))
	preview_root.set_meta("selected_stow_anchor_marker_id", stow_anchor_result.get("selected_id", StringName()))
	preview_root.set_meta("selected_stow_anchor_slot_id", stow_anchor_result.get("slot_id", StringName()))
	preview_root.set_meta("selected_stow_anchor_mode", stow_anchor_result.get("mode", StringName()))
	preview_root.set_meta("selected_stow_anchor_orientation_side", stow_anchor_result.get("orientation_side", StringName()))

func _build_trajectory_static_visual_signature(
	motion_node_chain: Array,
	speed_state_config: Dictionary,
	active_draft: Resource,
	authoring_drag_lightweight: bool
) -> String:
	var parts := PackedStringArray()
	parts.append("trajectory_static_v1")
	parts.append(str(authoring_drag_lightweight))
	parts.append(str(speed_state_config))
	if active_draft != null:
		parts.append(String(active_draft.get("draft_id")))
		parts.append(String(active_draft.get("draft_kind")))
		parts.append(String(active_draft.get("stow_anchor_mode")))
		parts.append(str(snapped(float(active_draft.get("stow_contact_ratio")), 0.0001)))
	parts.append(str(motion_node_chain.size()))
	for motion_node_variant: Variant in motion_node_chain:
		var motion_node: CombatAnimationMotionNode = motion_node_variant as CombatAnimationMotionNode
		parts.append(_build_motion_node_static_visual_signature(motion_node))
	return "|".join(parts)

func _build_motion_node_static_visual_signature(motion_node: CombatAnimationMotionNode) -> String:
	if motion_node == null:
		return "null"
	var parts := PackedStringArray()
	parts.append(String(motion_node.node_id))
	parts.append(str(motion_node.node_index))
	parts.append(str(motion_node.tip_position_local.snapped(Vector3(0.0001, 0.0001, 0.0001))))
	parts.append(String(motion_node.tip_position_origin_id))
	parts.append(str(motion_node.pommel_position_local.snapped(Vector3(0.0001, 0.0001, 0.0001))))
	parts.append(String(motion_node.pommel_position_origin_id))
	parts.append(str(motion_node.tip_curve_in_handle.snapped(Vector3(0.0001, 0.0001, 0.0001))))
	parts.append(str(motion_node.tip_curve_out_handle.snapped(Vector3(0.0001, 0.0001, 0.0001))))
	parts.append(str(motion_node.pommel_curve_in_handle.snapped(Vector3(0.0001, 0.0001, 0.0001))))
	parts.append(str(motion_node.pommel_curve_out_handle.snapped(Vector3(0.0001, 0.0001, 0.0001))))
	parts.append(str(motion_node.weapon_orientation_degrees.snapped(Vector3(0.0001, 0.0001, 0.0001))))
	parts.append(str(snapped(motion_node.weapon_roll_degrees, 0.0001)))
	parts.append(str(snapped(motion_node.transition_duration_seconds, 0.0001)))
	parts.append(String(motion_node.two_hand_state))
	parts.append(String(motion_node.primary_hand_slot))
	parts.append(String(motion_node.preferred_grip_style_mode))
	return ",".join(parts)

func _evaluate_preview_collision_path(
	state: Dictionary,
	motion_node_chain: Array,
	speed_state_result: Dictionary
) -> Dictionary:
	var preview_root: Node3D = state.get("preview_root", null) as Node3D
	var actor_pivot: Node3D = state.get("actor_pivot", null) as Node3D
	var trajectory_root: Node3D = state.get("trajectory_root", null) as Node3D
	if preview_root == null or actor_pivot == null or trajectory_root == null or motion_node_chain.size() < 2:
		return {"legal": true, "path_sample_count": 0}
	var actor: Node3D = actor_pivot.get_node_or_null(PREVIEW_ACTOR_NAME) as Node3D
	var held_item: Node3D = _get_node_meta_or_default(preview_root, "preview_held_item", null) as Node3D
	var body_restriction_root: Node3D = _get_preview_actor_body_restriction_root(actor)
	if actor == null or held_item == null or body_restriction_root == null:
		return {"legal": true, "path_sample_count": 0}
	_sync_preview_body_restriction_root(actor, body_restriction_root)
	var local_tip: Vector3 = _get_weapon_tip_meta(held_item)
	var local_tip_origin_id: StringName = _resolve_origin_meta_value(held_item, "weapon_tip_origin_id", CombatOriginRecordScript.ORIGIN_WEAPON_ROOT)
	var local_pommel: Vector3 = _get_weapon_pommel_meta(held_item)
	var local_pommel_origin_id: StringName = _resolve_origin_meta_value(held_item, "weapon_pommel_origin_id", CombatOriginRecordScript.ORIGIN_WEAPON_ROOT)
	if local_tip.is_equal_approx(local_pommel):
		return {"legal": true, "path_sample_count": 0}
	var local_axis: Vector3 = (local_tip - local_pommel).normalized()
	var local_up_reference_origin_id: StringName = CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
	var local_up_reference: Vector3 = _resolve_weapon_local_up_reference(held_item, local_axis)
	var transforms: Array[Transform3D] = []
	for sample_variant: Variant in speed_state_result.get("samples", []):
		var sample: Dictionary = sample_variant as Dictionary
		if sample.is_empty():
			continue
		var sampled_tip: Vector3 = sample.get("tip_position", Vector3.ZERO) as Vector3
		var sampled_pommel: Vector3 = sample.get("pommel_position", Vector3.ZERO) as Vector3
		if sampled_tip.is_equal_approx(sampled_pommel):
			continue
		var segment_index: int = clampi(int(sample.get("segment_index", 1)), 1, motion_node_chain.size() - 1)
		var local_ratio: float = clampf(float(sample.get("local_ratio", 0.0)), 0.0, 1.0)
		var from_node: CombatAnimationMotionNode = motion_node_chain[segment_index - 1] as CombatAnimationMotionNode
		var to_node: CombatAnimationMotionNode = motion_node_chain[segment_index] as CombatAnimationMotionNode
		if from_node == null or to_node == null:
			continue
		var orientation_degrees: Vector3 = _resolve_motion_node_weapon_orientation_degrees(from_node).lerp(
			_resolve_motion_node_weapon_orientation_degrees(to_node),
			local_ratio
		)
		var weapon_roll: float = lerpf(from_node.weapon_roll_degrees, to_node.weapon_roll_degrees, local_ratio)
		transforms.append(weapon_frame_solver.solve_transform_from_segment(
			local_tip,
			local_pommel,
			trajectory_root.to_global(sampled_tip),
			trajectory_root.to_global(sampled_pommel),
			local_up_reference,
			trajectory_root.global_basis,
			orientation_degrees,
			weapon_roll,
			local_tip_origin_id,
			local_pommel_origin_id,
			local_up_reference_origin_id
		))
	return collision_legality_resolver.evaluate_weapon_path(
		body_restriction_root,
		held_item,
		transforms,
		hand_target_constraint_solver
	)

func _evaluate_preview_collision_pose(
	actor: Node3D,
	held_item: Node3D,
	solved_transform: Transform3D
) -> Dictionary:
	var body_restriction_root: Node3D = _get_preview_actor_body_restriction_root(actor)
	if body_restriction_root == null or held_item == null:
		return {"legal": true, "sample_count": 0}
	_sync_preview_body_restriction_root(actor, body_restriction_root)
	return collision_legality_resolver.evaluate_weapon_pose(
		body_restriction_root,
		held_item,
		solved_transform,
		hand_target_constraint_solver
	)

func _separate_preview_weapon_transform_from_body(
	actor: Node3D,
	held_item: Node3D,
	source_transform: Transform3D,
	max_iterations: int = AUTHORING_BODY_SEPARATION_ITERATIONS
) -> Dictionary:
	var body_restriction_root: Node3D = _get_preview_actor_body_restriction_root(actor)
	var result := {
		"transform": source_transform,
		"legal": true,
		"collision_result": {},
		"iterations": 0,
	}
	if actor == null or held_item == null or body_restriction_root == null:
		return result
	_sync_preview_body_restriction_root(actor, body_restriction_root)
	var resolved_transform: Transform3D = source_transform
	var collision_result: Dictionary = {}
	var iteration_count: int = maxi(max_iterations, 0)
	for iteration_index: int in range(iteration_count):
		collision_result = collision_legality_resolver.evaluate_weapon_pose(
			body_restriction_root,
			held_item,
			resolved_transform,
			hand_target_constraint_solver
		)
		if bool(collision_result.get("legal", true)):
			result["transform"] = resolved_transform
			result["collision_result"] = collision_result
			result["iterations"] = iteration_index
			return result
		var correction_world: Vector3 = collision_result.get("suggested_correction_world", Vector3.ZERO) as Vector3
		if correction_world.length_squared() <= 0.0000001:
			correction_world = _resolve_preview_body_clearance_fallback_push(actor)
		if correction_world.length_squared() <= 0.0000001:
			break
		if correction_world.length() > AUTHORING_BODY_SEPARATION_MAX_STEP_METERS:
			correction_world = correction_world.normalized() * AUTHORING_BODY_SEPARATION_MAX_STEP_METERS
		resolved_transform = Transform3D(resolved_transform.basis, resolved_transform.origin + correction_world)
	collision_result = collision_legality_resolver.evaluate_weapon_pose(
		body_restriction_root,
		held_item,
		resolved_transform,
		hand_target_constraint_solver
	)
	result["transform"] = resolved_transform
	result["legal"] = bool(collision_result.get("legal", true))
	result["collision_result"] = collision_result
	result["iterations"] = iteration_count
	return result

func _resolve_preview_body_clearance_fallback_push(actor: Node3D) -> Vector3:
	var torso_frame: Dictionary = _resolve_preview_torso_frame(actor)
	var forward_world: Vector3 = torso_frame.get(
		"forward_world",
		character_frame_resolver.get_default_forward_world()
	) as Vector3
	if forward_world.length_squared() <= 0.000001:
		forward_world = character_frame_resolver.get_default_forward_world()
	return forward_world.normalized() * 0.04

func _apply_runtime_clip_preview_pose(
	state: Dictionary,
	selected_motion_node: CombatAnimationMotionNode,
	playback_state: Dictionary,
	active_draft: Resource = null
) -> Dictionary:
	return _apply_authored_weapon_pose(
		state,
		selected_motion_node,
		playback_state,
		false,
		AUTHORING_PREVIEW_DOMINANT_SEAT_LOCK_STRENGTH,
		false,
		active_draft
	)

func _apply_solved_runtime_clip_preview_pose(
	state: Dictionary,
	active_wip: CraftedItemWIP,
	playback_state: Dictionary
) -> Dictionary:
	var resolved_playback_state: Dictionary = playback_state.duplicate(false)
	var preview_root: Node3D = state.get("preview_root", null) as Node3D
	var actor_pivot: Node3D = state.get("actor_pivot", null) as Node3D
	if preview_root == null or actor_pivot == null or active_wip == null:
		return resolved_playback_state
	var actor: Node3D = actor_pivot.get_node_or_null(PREVIEW_ACTOR_NAME) as Node3D
	var held_item: Node3D = _get_node_meta_or_default(preview_root, "preview_held_item", null) as Node3D
	if actor == null or held_item == null or not is_instance_valid(held_item):
		return resolved_playback_state
	var current_wip_id: StringName = _get_node_meta_or_default(preview_root, "preview_wip_id", StringName()) as StringName
	var current_slot_id: StringName = _get_node_meta_or_default(preview_root, PREVIEW_ACTIVE_SLOT_ID_META, &"hand_right") as StringName
	var target_slot_id: StringName = _resolve_preview_dominant_slot_id()
	if current_wip_id != active_wip.wip_id or current_slot_id != target_slot_id:
		return resolved_playback_state
	if not actor.has_method("apply_runtime_solved_upper_body_pose_frame"):
		return resolved_playback_state
	var bone_names: Array = playback_state.get("solved_upper_body_bone_names", []) as Array
	var bone_positions: Array = playback_state.get("solved_upper_body_pose_positions", []) as Array
	var bone_rotations: Array = playback_state.get("solved_upper_body_pose_rotations", []) as Array
	var bone_scales: Array = playback_state.get("solved_upper_body_pose_scales", []) as Array
	if bone_names.is_empty() or bone_positions.is_empty() or bone_rotations.is_empty() or bone_scales.is_empty():
		return resolved_playback_state
	if not bool(preview_root.get_meta("preview_runtime_solved_replay_fast_path_active", false)):
		_clear_preview_actor_weapon_coupling(actor)
		if actor.has_method("clear_authoring_contact_anchor_bases"):
			actor.call("clear_authoring_contact_anchor_bases")
		preview_root.set_meta("preview_runtime_solved_replay_fast_path_active", true)
	var pose_applied: bool = bool(actor.call(
		"apply_runtime_solved_upper_body_pose_frame",
		bone_names,
		bone_positions,
		bone_rotations,
		bone_scales,
		1.0
	))
	if not pose_applied:
		return resolved_playback_state
	var reference_bone_name: StringName = playback_state.get("solved_replay_reference_bone_name", PREVIEW_ROOT_BONE) as StringName
	if reference_bone_name == StringName():
		reference_bone_name = PREVIEW_ROOT_BONE
	var weapon_position_reference_local: Vector3 = playback_state.get("solved_weapon_position_reference_local", Vector3.ZERO) as Vector3
	var weapon_rotation_reference_local: Quaternion = playback_state.get("solved_weapon_rotation_reference_local", Quaternion.IDENTITY) as Quaternion
	var weapon_scale_reference_local: Vector3 = playback_state.get("solved_weapon_scale_reference_local", Vector3.ONE) as Vector3
	var anchor_paths: Array = playback_state.get("solved_anchor_node_paths", []) as Array
	var anchor_positions: Array = playback_state.get("solved_anchor_positions_weapon_local", []) as Array
	var anchor_rotations: Array = playback_state.get("solved_anchor_rotations_weapon_local", []) as Array
	var anchor_scales: Array = playback_state.get("solved_anchor_scales_weapon_local", []) as Array
	var weapon_frame_registered: bool = false
	if actor.has_method("set_runtime_solved_replay_weapon_frame"):
		weapon_frame_registered = bool(actor.call(
			"set_runtime_solved_replay_weapon_frame",
			held_item,
			reference_bone_name,
			weapon_position_reference_local,
			weapon_rotation_reference_local,
			weapon_scale_reference_local,
			anchor_paths,
			anchor_positions,
			anchor_rotations,
			anchor_scales,
			target_slot_id if bool(playback_state.get("solved_replay_bridge_frame", false)) else StringName(),
			StringName(playback_state.get("solved_replay_reference_origin_id", CombatOriginRecordScript.ORIGIN_SOLVED_REPLAY_REFERENCE)),
			StringName(playback_state.get("solved_weapon_reference_origin_id", CombatOriginRecordScript.ORIGIN_SOLVED_REPLAY_REFERENCE)),
			StringName(playback_state.get("solved_anchor_origin_id", CombatOriginRecordScript.ORIGIN_WEAPON_ROOT))
		))
	if not weapon_frame_registered:
		var reference_transform: Transform3D = _resolve_preview_solved_replay_reference_transform(actor, reference_bone_name)
		held_item.global_transform = reference_transform * _build_preview_replay_transform(
			weapon_position_reference_local,
			weapon_rotation_reference_local,
			weapon_scale_reference_local
		)
		_apply_preview_solved_replay_anchor_transforms(held_item, anchor_paths, anchor_positions, anchor_rotations, anchor_scales)
	held_item.set_meta("dominant_contact_slot_id", target_slot_id)
	var local_tip: Vector3 = _get_weapon_tip_meta(held_item)
	var local_pommel: Vector3 = _get_weapon_pommel_meta(held_item)
	var solved_tip_world: Vector3 = held_item.to_global(local_tip)
	var solved_pommel_world: Vector3 = held_item.to_global(local_pommel)
	var trajectory_reference: Transform3D = _resolve_trajectory_authoring_transform(actor)
	var reference_inverse: Transform3D = trajectory_reference.affine_inverse()
	resolved_playback_state["active"] = bool(resolved_playback_state.get("active", true))
	resolved_playback_state["tip_position_local"] = reference_inverse * solved_tip_world
	resolved_playback_state["tip_position_origin_id"] = CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING
	resolved_playback_state["pommel_position_local"] = reference_inverse * solved_pommel_world
	resolved_playback_state["pommel_position_origin_id"] = CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING
	resolved_playback_state["tip_world"] = solved_tip_world
	resolved_playback_state["pommel_world"] = solved_pommel_world
	resolved_playback_state["solved_replay_applied"] = true
	preview_root.set_meta(PREVIEW_POSE_MODE_META, PREVIEW_POSE_MODE_HAND_AUTHORED)
	preview_root.set_meta("resolved_playback_state", resolved_playback_state)
	preview_root.set_meta("weapon_tip_alignment_error_meters", 0.0)
	preview_root.set_meta("weapon_pommel_alignment_error_meters", 0.0)
	preview_root.set_meta("collision_pose_legal", true)
	preview_root.set_meta("collision_pose_deferred", true)
	return resolved_playback_state

func _clear_preview_runtime_solved_replay_state(actor: Node3D, preview_root: Node3D = null) -> void:
	if actor != null and actor.has_method("clear_runtime_solved_replay_pose_frame"):
		actor.call("clear_runtime_solved_replay_pose_frame")
	if preview_root != null:
		preview_root.set_meta("preview_runtime_solved_replay_fast_path_active", false)

func _resolve_preview_solved_replay_reference_transform(actor: Node3D, reference_bone_name: StringName) -> Transform3D:
	if actor == null:
		return Transform3D(Basis.IDENTITY, AUTHORING_ROOT_FALLBACK_LOCAL_OFFSET)
	var resolved_bone_name: StringName = reference_bone_name if reference_bone_name != StringName() else PREVIEW_ROOT_BONE
	var skeleton: Skeleton3D = actor.get_node_or_null(PREVIEW_SKELETON_PATH) as Skeleton3D
	if skeleton != null and skeleton.find_bone(String(resolved_bone_name)) >= 0:
		return _get_skeleton_bone_world_transform(skeleton, resolved_bone_name)
	return _resolve_trajectory_authoring_transform(actor)

func _build_preview_replay_transform(position: Vector3, rotation: Quaternion, scale: Vector3) -> Transform3D:
	var basis := Basis(rotation.normalized())
	basis = basis.scaled(scale)
	return Transform3D(basis, position)

func _apply_preview_solved_replay_anchor_transforms(
	held_item: Node3D,
	anchor_paths: Array,
	anchor_positions: Array,
	anchor_rotations: Array,
	anchor_scales: Array
) -> void:
	if held_item == null or not is_instance_valid(held_item):
		return
	var count: int = mini(anchor_paths.size(), mini(anchor_positions.size(), mini(anchor_rotations.size(), anchor_scales.size())))
	for anchor_index: int in range(count):
		var anchor_node: Node3D = held_item.get_node_or_null(NodePath(String(anchor_paths[anchor_index]))) as Node3D
		if anchor_node == null or not is_instance_valid(anchor_node):
			continue
		var anchor_weapon_transform: Transform3D = _build_preview_replay_transform(
			anchor_positions[anchor_index] as Vector3,
			_resolve_preview_replay_rotation(anchor_rotations[anchor_index]),
			anchor_scales[anchor_index] as Vector3
		)
		anchor_node.global_transform = held_item.global_transform * anchor_weapon_transform

func _resolve_preview_replay_rotation(rotation_data: Variant) -> Quaternion:
	if rotation_data is Quaternion:
		return rotation_data as Quaternion
	if rotation_data is Vector4:
		var vector_rotation: Vector4 = rotation_data as Vector4
		return Quaternion(vector_rotation.x, vector_rotation.y, vector_rotation.z, vector_rotation.w)
	return Quaternion.IDENTITY

func _apply_authored_weapon_pose(
	state: Dictionary,
	selected_motion_node: CombatAnimationMotionNode,
	playback_state: Dictionary,
	update_camera: bool = true,
	dominant_seat_lock_strength: float = 1.0,
	preserve_authoring_endpoints: bool = true,
	active_draft: Resource = null,
	stow_endpoints_already_display_local: bool = false
) -> Dictionary:
	var preview_root: Node3D = state.get("preview_root", null) as Node3D
	var actor_pivot: Node3D = state.get("actor_pivot", null) as Node3D
	var trajectory_root: Node3D = state.get("trajectory_root", null) as Node3D
	if preview_root == null or trajectory_root == null:
		return playback_state
	var authoring_drag_lightweight: bool = bool(playback_state.get("authoring_drag_lightweight", false))
	preview_root.set_meta("weapon_tip_alignment_error_meters", -1.0)
	preview_root.set_meta("weapon_pommel_alignment_error_meters", -1.0)
	preview_root.set_meta("authoring_endpoint_legality_result", {})
	var held_item: Node3D = _get_node_meta_or_default(preview_root, "preview_held_item", null) as Node3D
	if held_item == null or not is_instance_valid(held_item) or selected_motion_node == null:
		return playback_state
	var local_tip: Vector3 = _get_weapon_tip_meta(held_item)
	var local_pommel: Vector3 = _get_weapon_pommel_meta(held_item)
	if local_tip.is_equal_approx(local_pommel):
		return playback_state
	var actor: Node3D = actor_pivot.get_node_or_null(PREVIEW_ACTOR_NAME) as Node3D if actor_pivot != null else null
	if _is_noncombat_idle_draft(active_draft):
		return _apply_noncombat_stowed_weapon_pose(
			state,
			selected_motion_node,
			playback_state,
			update_camera,
			active_draft,
			stow_endpoints_already_display_local
		)
	preview_root.set_meta(PREVIEW_POSE_MODE_META, PREVIEW_POSE_MODE_HAND_AUTHORED)
	_apply_preview_motion_grip_state(held_item, selected_motion_node, playback_state, actor)
	_sync_preview_contact_axis_override(held_item, playback_state, trajectory_root)
	var authored_tip_local: Vector3 = _get_origin_tracked_vector3_state(
		playback_state,
		"tip_position_local",
		"tip_position_origin_id",
		selected_motion_node.tip_position_local,
		selected_motion_node.tip_position_origin_id
	)
	var authored_pommel_local: Vector3 = _get_origin_tracked_vector3_state(
		playback_state,
		"pommel_position_local",
		"pommel_position_origin_id",
		selected_motion_node.pommel_position_local,
		selected_motion_node.pommel_position_origin_id
	)
	var resolved_weapon_orientation_degrees: Vector3 = playback_state.get(
		"weapon_orientation_degrees",
		_resolve_motion_node_weapon_orientation_degrees(selected_motion_node)
	) as Vector3
	var use_free_authoring_endpoint_authority: bool = false
	var allow_free_authoring_endpoint_authority: bool = preserve_authoring_endpoints or authoring_drag_lightweight
	var solved_transform: Transform3D
	var solved_transform_valid: bool = false
	if actor != null:
		var authored_tip_world_for_pose: Vector3 = trajectory_root.to_global(authored_tip_local)
		var authored_pommel_world_for_pose: Vector3 = trajectory_root.to_global(authored_pommel_local)
		var authored_pose_transform: Transform3D = held_item.global_transform
		if authored_tip_world_for_pose.distance_to(authored_pommel_world_for_pose) > SEGMENT_LEGALITY_EPSILON_METERS:
			authored_pose_transform = _solve_weapon_segment_transform(
				held_item,
				trajectory_root,
				selected_motion_node,
				local_tip,
				local_pommel,
				authored_tip_world_for_pose,
				authored_pommel_world_for_pose,
				resolved_weapon_orientation_degrees
			)
		_apply_preview_upper_body_authoring_state(
			actor,
			held_item,
			selected_motion_node,
			playback_state,
			authored_tip_world_for_pose,
			authored_pommel_world_for_pose,
			authored_pose_transform,
			true
		)
		_apply_preview_actor_upper_body_pose_now(actor)
		if authoring_drag_lightweight:
			var deferred_legality_result: Dictionary = {
				"legal": true,
				"deferred": true,
				"reason": "authoring_drag_lightweight",
			}
			preview_root.set_meta("authoring_endpoint_legality_result", deferred_legality_result)
			use_free_authoring_endpoint_authority = true
		elif allow_free_authoring_endpoint_authority:
			var authored_legality_result: Dictionary = _evaluate_preview_segment_legality(
				actor,
				held_item,
				authored_pose_transform,
				selected_motion_node
			)
			preview_root.set_meta("authoring_endpoint_legality_result", authored_legality_result)
			use_free_authoring_endpoint_authority = bool(authored_legality_result.get("legal", true))
		if not use_free_authoring_endpoint_authority:
			var constrained_segment_state: Dictionary = _resolve_constrained_authored_segment_local(
				actor,
				held_item,
				trajectory_root,
				selected_motion_node,
				authored_tip_local,
				authored_pommel_local,
				dominant_seat_lock_strength
			)
			authored_tip_local = _get_origin_tracked_vector3_state(
				constrained_segment_state,
				"tip_position_local",
				"tip_position_origin_id",
				authored_tip_local,
				_resolve_origin_tracked_state_origin_id(playback_state, "tip_position_origin_id", selected_motion_node.tip_position_origin_id)
			)
			authored_pommel_local = _get_origin_tracked_vector3_state(
				constrained_segment_state,
				"pommel_position_local",
				"pommel_position_origin_id",
				authored_pommel_local,
				_resolve_origin_tracked_state_origin_id(playback_state, "pommel_position_origin_id", selected_motion_node.pommel_position_origin_id)
			)
			solved_transform_valid = bool(constrained_segment_state.get("has_solved_transform", false))
			if solved_transform_valid:
				solved_transform = constrained_segment_state.get("solved_transform", Transform3D.IDENTITY) as Transform3D
	var authored_tip_world: Vector3 = trajectory_root.to_global(authored_tip_local)
	var authored_pommel_world: Vector3 = trajectory_root.to_global(authored_pommel_local)
	if not solved_transform_valid:
		solved_transform = _solve_weapon_segment_transform(
			held_item,
			trajectory_root,
			selected_motion_node,
			local_tip,
			local_pommel,
			authored_tip_world,
			authored_pommel_world,
			resolved_weapon_orientation_degrees
		)
	held_item.global_transform = solved_transform
	_apply_preview_resolved_grip_state(held_item)
	var solved_tip_world: Vector3 = held_item.to_global(local_tip)
	var solved_pommel_world: Vector3 = held_item.to_global(local_pommel)
	preview_root.set_meta("weapon_tip_alignment_error_meters", solved_tip_world.distance_to(authored_tip_world))
	preview_root.set_meta("weapon_pommel_alignment_error_meters", solved_pommel_world.distance_to(authored_pommel_world))
	var resolved_playback_state: Dictionary = playback_state.duplicate(true)
	_set_tip_pommel_position_state(
		resolved_playback_state,
		trajectory_root.to_local(solved_tip_world),
		trajectory_root.to_local(solved_pommel_world),
		CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING
	)
	resolved_playback_state["weapon_orientation_degrees"] = resolved_weapon_orientation_degrees
	preview_root.set_meta("resolved_playback_state", resolved_playback_state)
	if authoring_drag_lightweight:
		if actor != null:
			_apply_two_hand_preview_state(actor, held_item, selected_motion_node)
			_apply_preview_upper_body_authoring_state(actor, held_item, selected_motion_node, resolved_playback_state)
			_apply_preview_actor_upper_body_pose_now(actor)
		var deferred_metrics: Dictionary = {
			"stopped_reason": "authoring_drag_lightweight",
			"weapon_locked_to_moving_hand": false,
			"legality_deferred_until_release": true,
		}
		preview_root.set_meta("contact_coupling_metrics", deferred_metrics)
		preview_root.set_meta("contact_clearance_settle_metrics", deferred_metrics)
		preview_root.set_meta("final_anchor_reseat_metrics", deferred_metrics)
		preview_root.set_meta("collision_pose_legal", true)
		preview_root.set_meta("collision_pose_deferred", true)
		preview_root.set_meta("collision_pose_illegal_sample_count", 0)
		preview_root.set_meta("collision_pose_region", "")
		preview_root.set_meta("collision_pose_attachment", "")
		preview_root.set_meta("collision_pose_sample", "")
		preview_root.set_meta("collision_pose_clearance_meters", -1.0)
		return resolved_playback_state
	if actor != null:
		_apply_two_hand_preview_state(actor, held_item, selected_motion_node)
		_apply_preview_upper_body_authoring_state(actor, held_item, selected_motion_node, resolved_playback_state)
		_apply_preview_actor_upper_body_pose_now(actor)
		if use_free_authoring_endpoint_authority:
			preview_root.set_meta("contact_coupling_metrics", {
				"authoring_endpoint_authority": true,
				"weapon_locked_to_moving_hand": false,
			})
			preview_root.set_meta("contact_clearance_settle_metrics", {
				"stopped_reason": "authoring_endpoint_authority",
				"weapon_locked_to_moving_hand": false,
			})
			preview_root.set_meta("final_anchor_reseat_metrics", {
				"stopped_reason": "authoring_endpoint_authority",
				"weapon_locked_to_moving_hand": false,
			})
			preview_root.set_meta("resolved_playback_state", resolved_playback_state)
			_settle_preview_contact_group_on_resolved_weapon(actor, held_item, selected_motion_node, resolved_playback_state)
		else:
			var final_primary_local: Vector3 = _get_preview_primary_grip_seat_meta(held_item)
			held_item.global_transform = _lock_preview_transform_to_dominant_grip_target(
				held_item.global_transform,
				final_primary_local,
				_resolve_preview_primary_grip_target_world(actor, held_item),
				dominant_seat_lock_strength
			)
			held_item.global_transform = _apply_preview_support_coupling(
				actor,
				held_item,
				selected_motion_node,
				held_item.global_transform,
				dominant_seat_lock_strength
			)
			var playback_coupled_result: Dictionary = _apply_preview_grip_contact_coupling(
				actor,
				held_item,
				selected_motion_node,
				held_item.global_transform,
				false
			)
			held_item.global_transform = playback_coupled_result.get("transform", held_item.global_transform) as Transform3D
			_apply_preview_resolved_grip_state(held_item)
			solved_tip_world = held_item.to_global(local_tip)
			solved_pommel_world = held_item.to_global(local_pommel)
			_set_tip_pommel_position_state(
				resolved_playback_state,
				trajectory_root.to_local(solved_tip_world),
				trajectory_root.to_local(solved_pommel_world),
				CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING
			)
			resolved_playback_state["weapon_orientation_degrees"] = resolved_weapon_orientation_degrees
			preview_root.set_meta("weapon_tip_alignment_error_meters", 0.0)
			preview_root.set_meta("weapon_pommel_alignment_error_meters", 0.0)
			preview_root.set_meta("contact_coupling_metrics", playback_coupled_result.get("metrics", {}))
			preview_root.set_meta("resolved_playback_state", resolved_playback_state)
			_settle_preview_contact_group_on_resolved_weapon(actor, held_item, selected_motion_node, resolved_playback_state)
			var contact_clearance_result: Dictionary = _settle_preview_contact_and_body_clearance(
				actor,
				held_item,
				selected_motion_node,
				resolved_playback_state,
				trajectory_root,
				local_tip,
				local_pommel,
				resolved_weapon_orientation_degrees
			)
			resolved_playback_state = contact_clearance_result.get("playback_state", resolved_playback_state) as Dictionary
			preview_root.set_meta("contact_clearance_settle_metrics", contact_clearance_result.get("metrics", {}))
			preview_root.set_meta("resolved_playback_state", resolved_playback_state)
	var collision_pose_result: Dictionary = _evaluate_preview_collision_pose(actor, held_item, held_item.global_transform)
	if actor != null:
		var pre_anchor_grip_error: float = _resolve_preview_grip_alignment_error(actor, held_item, _resolve_preview_dominant_slot_id())
		var should_reseat_to_hand: bool = (
			not use_free_authoring_endpoint_authority
			or (
				pre_anchor_grip_error >= 0.0
				and pre_anchor_grip_error > AUTHORING_BODY_CONTACT_GRIP_EPSILON_METERS
			)
		)
		if not should_reseat_to_hand:
			preview_root.set_meta("final_anchor_reseat_metrics", {
				"stopped_reason": "authoring_endpoint_authority",
				"pre_anchor_grip_error_meters": pre_anchor_grip_error,
				"weapon_locked_to_moving_hand": false,
			})
			preview_root.set_meta("resolved_playback_state", resolved_playback_state)
			preview_root.set_meta("collision_pose_legal", bool(collision_pose_result.get("legal", true)))
			preview_root.set_meta("collision_pose_illegal_sample_count", int(collision_pose_result.get("illegal_sample_count", 0)))
			preview_root.set_meta("collision_pose_region", String(collision_pose_result.get("colliding_body_region", "")))
			preview_root.set_meta("collision_pose_attachment", String(collision_pose_result.get("colliding_body_attachment_name", "")))
			preview_root.set_meta("collision_pose_sample", String(collision_pose_result.get("colliding_sample_name", "")))
			preview_root.set_meta("collision_pose_clearance_meters", float(collision_pose_result.get("estimated_clearance_meters", -1.0)))
			if update_camera:
				_update_camera(preview_root, weapon_grip_anchor_provider.get_primary_grip_anchor(held_item))
			return resolved_playback_state
		var final_anchor_result: Dictionary = _seat_preview_weapon_to_current_dominant_hand(
			actor,
			held_item,
			resolved_playback_state,
			trajectory_root,
			local_tip,
			local_pommel,
			resolved_weapon_orientation_degrees
		)
		resolved_playback_state = final_anchor_result.get("playback_state", resolved_playback_state) as Dictionary
		var final_anchor_metrics: Dictionary = final_anchor_result.get("metrics", {}) as Dictionary
		var post_anchor_separation_delta: float = 0.0
		if not use_free_authoring_endpoint_authority:
			var post_anchor_separation_result: Dictionary = _separate_preview_weapon_transform_from_body(
				actor,
				held_item,
				held_item.global_transform,
				AUTHORING_BODY_CONTACT_FINAL_SEPARATION_ITERATIONS
			)
			var post_anchor_separated_transform: Transform3D = post_anchor_separation_result.get("transform", held_item.global_transform) as Transform3D
			post_anchor_separation_delta = post_anchor_separated_transform.origin.distance_to(held_item.global_transform.origin)
			if post_anchor_separation_delta > AUTHORING_BODY_CONTACT_SETTLE_EPSILON_METERS:
				held_item.global_transform = post_anchor_separated_transform
				_apply_preview_resolved_grip_state(held_item)
				resolved_playback_state = _resolve_playback_state_from_held_item_transform(
					resolved_playback_state,
					held_item,
					trajectory_root,
					local_tip,
					local_pommel,
					resolved_weapon_orientation_degrees
				)
		final_anchor_metrics["pre_anchor_grip_error_meters"] = pre_anchor_grip_error
		final_anchor_metrics["post_anchor_separation_delta_meters"] = post_anchor_separation_delta
		final_anchor_metrics["grip_error_after_post_separation_meters"] = _resolve_preview_grip_alignment_error(actor, held_item, _resolve_preview_dominant_slot_id())
		preview_root.set_meta("final_anchor_reseat_metrics", final_anchor_metrics)
		preview_root.set_meta("resolved_playback_state", resolved_playback_state)
		collision_pose_result = _evaluate_preview_collision_pose(actor, held_item, held_item.global_transform)
	preview_root.set_meta("collision_pose_legal", bool(collision_pose_result.get("legal", true)))
	preview_root.set_meta("collision_pose_illegal_sample_count", int(collision_pose_result.get("illegal_sample_count", 0)))
	preview_root.set_meta("collision_pose_region", String(collision_pose_result.get("colliding_body_region", "")))
	preview_root.set_meta("collision_pose_attachment", String(collision_pose_result.get("colliding_body_attachment_name", "")))
	preview_root.set_meta("collision_pose_sample", String(collision_pose_result.get("colliding_sample_name", "")))
	preview_root.set_meta("collision_pose_clearance_meters", float(collision_pose_result.get("estimated_clearance_meters", -1.0)))
	if update_camera:
		_update_camera(preview_root, weapon_grip_anchor_provider.get_primary_grip_anchor(held_item))
	return resolved_playback_state

func _apply_noncombat_stowed_weapon_pose(
	state: Dictionary,
	selected_motion_node: CombatAnimationMotionNode,
	playback_state: Dictionary,
	update_camera: bool,
	active_draft: Resource,
	stow_endpoints_already_display_local: bool
) -> Dictionary:
	var preview_root: Node3D = state.get("preview_root", null) as Node3D
	var actor_pivot: Node3D = state.get("actor_pivot", null) as Node3D
	var trajectory_root: Node3D = state.get("trajectory_root", null) as Node3D
	if preview_root == null or trajectory_root == null:
		return playback_state
	var held_item: Node3D = _get_node_meta_or_default(preview_root, "preview_held_item", null) as Node3D
	if held_item == null or not is_instance_valid(held_item) or selected_motion_node == null:
		return playback_state
	var local_tip: Vector3 = _get_weapon_tip_meta(held_item)
	var local_pommel: Vector3 = _get_weapon_pommel_meta(held_item)
	if local_tip.is_equal_approx(local_pommel):
		return playback_state
	var actor: Node3D = actor_pivot.get_node_or_null(PREVIEW_ACTOR_NAME) as Node3D if actor_pivot != null else null
	_prepare_preview_actor_for_noncombat_stow(preview_root, actor, held_item)
	_clear_preview_contact_axis_override(held_item)
	var authored_tip_local: Vector3 = _get_origin_tracked_vector3_state(
		playback_state,
		"tip_position_local",
		"tip_position_origin_id",
		selected_motion_node.tip_position_local,
		selected_motion_node.tip_position_origin_id
	)
	var authored_pommel_local: Vector3 = _get_origin_tracked_vector3_state(
		playback_state,
		"pommel_position_local",
		"pommel_position_origin_id",
		selected_motion_node.pommel_position_local,
		selected_motion_node.pommel_position_origin_id
	)
	if not stow_endpoints_already_display_local:
		var stow_anchor_offset_local: Vector3 = _resolve_selected_noncombat_stow_anchor_position_local(state, active_draft)
		authored_tip_local += stow_anchor_offset_local
		authored_pommel_local += stow_anchor_offset_local
	var resolved_weapon_orientation_degrees: Vector3 = playback_state.get(
		"weapon_orientation_degrees",
		_resolve_motion_node_weapon_orientation_degrees(selected_motion_node)
	) as Vector3
	var authored_tip_world: Vector3 = trajectory_root.to_global(authored_tip_local)
	var authored_pommel_world: Vector3 = trajectory_root.to_global(authored_pommel_local)
	var solved_transform: Transform3D = held_item.global_transform
	if authored_tip_world.distance_to(authored_pommel_world) > SEGMENT_LEGALITY_EPSILON_METERS:
		solved_transform = _solve_weapon_segment_transform(
			held_item,
			trajectory_root,
			selected_motion_node,
			local_tip,
			local_pommel,
			authored_tip_world,
			authored_pommel_world,
			resolved_weapon_orientation_degrees
		)
	held_item.global_transform = solved_transform
	_apply_preview_resolved_grip_state(held_item)
	var solved_tip_world: Vector3 = held_item.to_global(local_tip)
	var solved_pommel_world: Vector3 = held_item.to_global(local_pommel)
	preview_root.set_meta("weapon_tip_alignment_error_meters", solved_tip_world.distance_to(authored_tip_world))
	preview_root.set_meta("weapon_pommel_alignment_error_meters", solved_pommel_world.distance_to(authored_pommel_world))
	var resolved_playback_state: Dictionary = playback_state.duplicate(true)
	_set_tip_pommel_position_state(
		resolved_playback_state,
		trajectory_root.to_local(solved_tip_world),
		trajectory_root.to_local(solved_pommel_world),
		CombatOriginRecordScript.ORIGIN_NONCOMBAT_STOW
	)
	resolved_playback_state["weapon_orientation_degrees"] = resolved_weapon_orientation_degrees
	resolved_playback_state["hands_interact_with_weapon"] = false
	resolved_playback_state["noncombat_stow_decoupled"] = true
	preview_root.set_meta("resolved_playback_state", resolved_playback_state)
	var stow_metrics: Dictionary = {
		"stopped_reason": "noncombat_stow_decoupled",
		"weapon_locked_to_moving_hand": false,
		"hands_interact_with_weapon": false,
	}
	preview_root.set_meta("contact_coupling_metrics", stow_metrics)
	preview_root.set_meta("contact_clearance_settle_metrics", stow_metrics)
	preview_root.set_meta("final_anchor_reseat_metrics", stow_metrics)
	preview_root.set_meta("authoring_endpoint_legality_result", {
		"legal": true,
		"noncombat_stow_decoupled": true,
	})
	var collision_pose_result: Dictionary = _evaluate_preview_collision_pose(actor, held_item, held_item.global_transform)
	preview_root.set_meta("collision_pose_legal", bool(collision_pose_result.get("legal", true)))
	preview_root.set_meta("collision_pose_illegal_sample_count", int(collision_pose_result.get("illegal_sample_count", 0)))
	preview_root.set_meta("collision_pose_region", String(collision_pose_result.get("colliding_body_region", "")))
	preview_root.set_meta("collision_pose_attachment", String(collision_pose_result.get("colliding_body_attachment_name", "")))
	preview_root.set_meta("collision_pose_sample", String(collision_pose_result.get("colliding_sample_name", "")))
	preview_root.set_meta("collision_pose_clearance_meters", float(collision_pose_result.get("estimated_clearance_meters", -1.0)))
	if update_camera:
		_update_camera(preview_root, weapon_grip_anchor_provider.get_primary_grip_anchor(held_item))
	return resolved_playback_state

func _prepare_preview_actor_for_noncombat_stow(preview_root: Node3D, actor: Node3D, held_item: Node3D) -> void:
	if preview_root == null:
		return
	var previous_pose_mode: StringName = _get_node_meta_or_default(preview_root, PREVIEW_POSE_MODE_META, StringName()) as StringName
	_clear_preview_actor_weapon_coupling(actor)
	if actor != null and previous_pose_mode != PREVIEW_POSE_MODE_NONCOMBAT_STOW:
		var baseline_animation_name: StringName = _resolve_preview_authoring_baseline_animation_name(actor, held_item, null)
		if actor.has_method("reset_authoring_preview_baseline_pose"):
			actor.call("reset_authoring_preview_baseline_pose", baseline_animation_name)
		elif actor.has_method("clear_upper_body_authoring_state"):
			actor.call("clear_upper_body_authoring_state")
			_apply_preview_actor_upper_body_pose_now(actor)
		_clear_preview_actor_weapon_coupling(actor)
	preview_root.set_meta(PREVIEW_POSE_MODE_META, PREVIEW_POSE_MODE_NONCOMBAT_STOW)

func _clear_preview_actor_weapon_coupling(actor: Node3D) -> void:
	if actor == null:
		return
	if actor.has_method("clear_upper_body_authoring_state"):
		actor.call("clear_upper_body_authoring_state")
	if actor.has_method("clear_dominant_grip_slot"):
		actor.call("clear_dominant_grip_slot")
	for slot_id: StringName in [&"hand_right", &"hand_left"]:
		if actor.has_method("clear_arm_guidance_target"):
			actor.call("clear_arm_guidance_target", slot_id)
		if actor.has_method("clear_arm_guidance_active"):
			actor.call("clear_arm_guidance_active", slot_id)
		if actor.has_method("clear_finger_grip_target"):
			actor.call("clear_finger_grip_target", slot_id)
		if actor.has_method("set_support_hand_active"):
			actor.call("set_support_hand_active", slot_id, false)

func _prepare_trajectory_root_for_authoring(state: Dictionary) -> void:
	var preview_root: Node3D = state.get("preview_root", null) as Node3D
	var actor_pivot: Node3D = state.get("actor_pivot", null) as Node3D
	var trajectory_root: Node3D = state.get("trajectory_root", null) as Node3D
	if preview_root == null or trajectory_root == null:
		return
	_ensure_trajectory_root_parent(preview_root, trajectory_root)
	var actor: Node3D = actor_pivot.get_node_or_null(PREVIEW_ACTOR_NAME) as Node3D if actor_pivot != null else null
	trajectory_root.global_transform = _resolve_trajectory_authoring_transform(actor)

func _refresh_collision_debug_visuals(state: Dictionary) -> void:
	var preview_root: Node3D = state.get("preview_root", null) as Node3D
	var actor_pivot: Node3D = state.get("actor_pivot", null) as Node3D
	if preview_root == null:
		return
	var actor: Node3D = actor_pivot.get_node_or_null(PREVIEW_ACTOR_NAME) as Node3D if actor_pivot != null else null
	var held_item: Node3D = _get_node_meta_or_default(preview_root, "preview_held_item", null) as Node3D
	var debugger_view_enabled: bool = _resolve_debugger_view_enabled(state, {})
	var collision_debug_visible: bool = debugger_view_enabled and held_item != null and is_instance_valid(held_item)
	_set_preview_actor_collision_debug_visible(actor, collision_debug_visible)
	var debug_visual_count: int = _count_visible_body_restriction_debug_meshes(actor)
	if collision_debug_visible:
		_hide_preview_weapon_bounds_debug(held_item)
		debug_visual_count += _sync_preview_grip_contact_debug(
			held_item.get_node_or_null("PrimaryGripGuide") as Node3D,
			Color(0.12, 0.78, 1.0, 0.22)
		)
		debug_visual_count += _sync_preview_grip_contact_debug(
			held_item.get_node_or_null("SecondaryGripGuide") as Node3D,
			Color(1.0, 0.62, 0.18, 0.22)
		)
		debug_visual_count += _sync_preview_weapon_proxy_debug(held_item)
	else:
		_set_preview_weapon_collision_debug_visible(held_item, false)
	preview_root.set_meta("collision_debug_visual_count", debug_visual_count)

func _build_effective_motion_node_chain(
	active_draft: Resource,
	selected_node_index: int,
	live_motion_node_override: CombatAnimationMotionNode
) -> Array:
	if active_draft == null:
		return []
	var motion_node_chain: Array = active_draft.get("motion_node_chain") as Array
	if live_motion_node_override == null:
		return motion_node_chain
	var resolved_index: int = clampi(selected_node_index, 0, maxi(motion_node_chain.size() - 1, 0))
	if motion_node_chain.is_empty() or resolved_index < 0 or resolved_index >= motion_node_chain.size():
		return motion_node_chain
	var effective_chain: Array = motion_node_chain.duplicate()
	effective_chain[resolved_index] = live_motion_node_override
	return effective_chain

func _draft_uses_hidden_entry_motion_node(active_draft: Resource) -> bool:
	if active_draft == null:
		return false
	if StringName(active_draft.get("draft_kind")) != CombatAnimationDraftScript.DRAFT_KIND_SKILL:
		return false
	return int((active_draft.get("motion_node_chain") as Array).size()) >= 2

func _build_visible_motion_node_chain(active_draft: Resource, motion_node_chain: Array) -> Array:
	if not _draft_uses_hidden_entry_motion_node(active_draft):
		return motion_node_chain
	var visible_chain: Array = []
	for node_index: int in range(1, motion_node_chain.size()):
		visible_chain.append(motion_node_chain[node_index])
	return visible_chain

func _build_resolved_display_motion_node_chain(
	motion_node_chain: Array,
	selected_node_index: int,
	resolved_playback_state: Dictionary
) -> Array:
	if resolved_playback_state.is_empty():
		return motion_node_chain
	if selected_node_index < 0 or selected_node_index >= motion_node_chain.size():
		return motion_node_chain
	var selected_motion_node: CombatAnimationMotionNode = motion_node_chain[selected_node_index] as CombatAnimationMotionNode
	if selected_motion_node == null:
		return motion_node_chain
	var display_motion_node: CombatAnimationMotionNode = selected_motion_node.duplicate_node()
	if display_motion_node == null:
		return motion_node_chain
	if resolved_playback_state.has("tip_position_local"):
		display_motion_node.tip_position_local = _get_origin_tracked_vector3_state(
			resolved_playback_state,
			"tip_position_local",
			"tip_position_origin_id",
			display_motion_node.tip_position_local,
			display_motion_node.tip_position_origin_id
		)
		display_motion_node.tip_position_origin_id = _resolve_origin_tracked_state_origin_id(
			resolved_playback_state,
			"tip_position_origin_id",
			display_motion_node.tip_position_origin_id
		)
	if resolved_playback_state.has("pommel_position_local"):
		display_motion_node.pommel_position_local = _get_origin_tracked_vector3_state(
			resolved_playback_state,
			"pommel_position_local",
			"pommel_position_origin_id",
			display_motion_node.pommel_position_local,
			display_motion_node.pommel_position_origin_id
		)
		display_motion_node.pommel_position_origin_id = _resolve_origin_tracked_state_origin_id(
			resolved_playback_state,
			"pommel_position_origin_id",
			display_motion_node.pommel_position_origin_id
		)
	if resolved_playback_state.has("weapon_orientation_degrees"):
		display_motion_node.weapon_orientation_degrees = resolved_playback_state.get(
			"weapon_orientation_degrees",
			display_motion_node.weapon_orientation_degrees
		) as Vector3
		display_motion_node.weapon_orientation_authored = true
	display_motion_node.normalize()
	var display_chain: Array = motion_node_chain.duplicate()
	display_chain[selected_node_index] = display_motion_node
	return display_chain

func _resolve_visible_selected_motion_node_index(
	active_draft: Resource,
	selected_node_index: int,
	visible_chain_size: int
) -> int:
	if visible_chain_size <= 0:
		return -1
	var hidden_offset: int = 1 if _draft_uses_hidden_entry_motion_node(active_draft) else 0
	return clampi(selected_node_index - hidden_offset, 0, visible_chain_size - 1)

func _resolve_selected_motion_node(motion_node_chain: Array, selected_node_index: int) -> CombatAnimationMotionNode:
	if motion_node_chain.is_empty():
		return null
	var resolved_index: int = clampi(selected_node_index, 0, motion_node_chain.size() - 1)
	return motion_node_chain[resolved_index] as CombatAnimationMotionNode

func _motion_node_matches_hand_mounted_seed(
	motion_node: CombatAnimationMotionNode,
	hand_mount_seed: Dictionary
) -> bool:
	if motion_node == null or hand_mount_seed.is_empty():
		return false
	var seed_tip: Vector3 = hand_mount_seed.get("tip_position_local", Vector3.INF) as Vector3
	var seed_tip_origin_id: StringName = StringName(hand_mount_seed.get(
		"tip_position_origin_id",
		motion_node.tip_position_origin_id
	))
	var seed_pommel: Vector3 = hand_mount_seed.get("pommel_position_local", Vector3.INF) as Vector3
	var seed_pommel_origin_id: StringName = StringName(hand_mount_seed.get(
		"pommel_position_origin_id",
		motion_node.pommel_position_origin_id
	))
	var seed_weapon_orientation: Vector3 = hand_mount_seed.get(
		"weapon_orientation_degrees",
		Vector3.INF
	) as Vector3
	if seed_tip == Vector3.INF or seed_pommel == Vector3.INF or seed_weapon_orientation == Vector3.INF:
		return false
	return (
		motion_node.tip_position_local.is_equal_approx(seed_tip)
		and motion_node.tip_position_origin_id == seed_tip_origin_id
		and motion_node.pommel_position_local.is_equal_approx(seed_pommel)
		and motion_node.pommel_position_origin_id == seed_pommel_origin_id
		and _resolve_motion_node_weapon_orientation_degrees(motion_node).is_equal_approx(seed_weapon_orientation)
		and motion_node.preferred_grip_style_mode == StringName(hand_mount_seed.get(
			"preferred_grip_style_mode",
			motion_node.preferred_grip_style_mode
		))
		and is_equal_approx(
			motion_node.weapon_roll_degrees,
			float(hand_mount_seed.get("weapon_roll_degrees", motion_node.weapon_roll_degrees))
		)
		and is_equal_approx(
			motion_node.axial_reposition_offset,
			float(hand_mount_seed.get("axial_reposition_offset", motion_node.axial_reposition_offset))
		)
		and is_equal_approx(
			motion_node.grip_seat_slide_offset,
			float(hand_mount_seed.get("grip_seat_slide_offset", motion_node.grip_seat_slide_offset))
		)
		and is_equal_approx(
			motion_node.secondary_grip_seat_slide_offset,
			float(hand_mount_seed.get("secondary_grip_seat_slide_offset", motion_node.secondary_grip_seat_slide_offset))
		)
	)

func _apply_preview_open_mount_pose(
	state: Dictionary,
	selected_motion_node: CombatAnimationMotionNode,
	playback_state: Dictionary,
	update_camera: bool = true
) -> Dictionary:
	var preview_root: Node3D = state.get("preview_root", null) as Node3D
	var actor_pivot: Node3D = state.get("actor_pivot", null) as Node3D
	if preview_root == null:
		return playback_state
	preview_root.set_meta("weapon_tip_alignment_error_meters", 0.0)
	preview_root.set_meta("weapon_pommel_alignment_error_meters", 0.0)
	var held_item: Node3D = _get_node_meta_or_default(preview_root, "preview_held_item", null) as Node3D
	var actor: Node3D = actor_pivot.get_node_or_null(PREVIEW_ACTOR_NAME) as Node3D if actor_pivot != null else null
	if held_item == null or not is_instance_valid(held_item):
		return playback_state
	if actor != null:
		if actor.has_method("reset_authoring_preview_baseline_pose"):
			actor.call("reset_authoring_preview_baseline_pose", _resolve_preview_authoring_baseline_animation_name(actor, held_item, selected_motion_node))
		else:
			equipped_item_presenter.clear_rig_weapon_contact_guidance(actor)
			if actor.has_method("clear_upper_body_authoring_state"):
				actor.call("clear_upper_body_authoring_state")
			_apply_preview_actor_upper_body_pose_now(actor)
	_apply_preview_motion_grip_state(held_item, selected_motion_node, playback_state, actor)
	_apply_preview_hand_mounted_transform(actor, held_item)
	_apply_preview_resolved_grip_state(held_item)
	if actor != null:
		equipped_item_presenter.clear_rig_weapon_contact_guidance(actor)
	if update_camera:
		_update_camera(preview_root, weapon_grip_anchor_provider.get_primary_grip_anchor(held_item))
	return playback_state.duplicate(true)

func _build_effective_preview_motion_node(
	selected_motion_node: CombatAnimationMotionNode,
	playback_state: Dictionary
) -> CombatAnimationMotionNode:
	if selected_motion_node == null:
		return null
	if not bool(playback_state.get("active", false)):
		return selected_motion_node
	var effective_motion_node: CombatAnimationMotionNode = selected_motion_node.duplicate_node()
	if effective_motion_node == null:
		return selected_motion_node
	if playback_state.has("tip_position_local"):
		effective_motion_node.tip_position_local = _get_origin_tracked_vector3_state(
			playback_state,
			"tip_position_local",
			"tip_position_origin_id",
			effective_motion_node.tip_position_local,
			effective_motion_node.tip_position_origin_id
		)
		effective_motion_node.tip_position_origin_id = _resolve_origin_tracked_state_origin_id(
			playback_state,
			"tip_position_origin_id",
			effective_motion_node.tip_position_origin_id
		)
	if playback_state.has("pommel_position_local"):
		effective_motion_node.pommel_position_local = _get_origin_tracked_vector3_state(
			playback_state,
			"pommel_position_local",
			"pommel_position_origin_id",
			effective_motion_node.pommel_position_local,
			effective_motion_node.pommel_position_origin_id
		)
		effective_motion_node.pommel_position_origin_id = _resolve_origin_tracked_state_origin_id(
			playback_state,
			"pommel_position_origin_id",
			effective_motion_node.pommel_position_origin_id
		)
	if playback_state.has("weapon_orientation_degrees"):
		effective_motion_node.weapon_orientation_degrees = playback_state.get(
			"weapon_orientation_degrees",
			effective_motion_node.weapon_orientation_degrees
		) as Vector3
		effective_motion_node.weapon_orientation_authored = true
	if playback_state.has("weapon_roll_degrees"):
		effective_motion_node.weapon_roll_degrees = float(playback_state.get(
			"weapon_roll_degrees",
			effective_motion_node.weapon_roll_degrees
		))
	if playback_state.has("axial_reposition_offset"):
		effective_motion_node.axial_reposition_offset = float(playback_state.get(
			"axial_reposition_offset",
			effective_motion_node.axial_reposition_offset
		))
	if playback_state.has("grip_seat_slide_offset"):
		effective_motion_node.grip_seat_slide_offset = float(playback_state.get(
			"grip_seat_slide_offset",
			effective_motion_node.grip_seat_slide_offset
		))
	if playback_state.has("secondary_grip_seat_slide_offset"):
		effective_motion_node.secondary_grip_seat_slide_offset = float(playback_state.get(
			"secondary_grip_seat_slide_offset",
			effective_motion_node.secondary_grip_seat_slide_offset
		))
	if playback_state.has("body_support_blend"):
		effective_motion_node.body_support_blend = float(playback_state.get(
			"body_support_blend",
			effective_motion_node.body_support_blend
		))
	if playback_state.has("two_hand_state"):
		effective_motion_node.two_hand_state = StringName(playback_state.get(
			"two_hand_state",
			effective_motion_node.two_hand_state
		))
	if playback_state.has("primary_hand_slot"):
		effective_motion_node.primary_hand_slot = StringName(playback_state.get(
			"primary_hand_slot",
			effective_motion_node.primary_hand_slot
		))
	if playback_state.has("preferred_grip_style_mode"):
		effective_motion_node.preferred_grip_style_mode = StringName(playback_state.get(
			"preferred_grip_style_mode",
			effective_motion_node.preferred_grip_style_mode
		))
	effective_motion_node.normalize()
	return effective_motion_node

func _build_weapon_preview_node(preview_root: Node3D, actor: Node3D, active_wip: CraftedItemWIP) -> Node3D:
	if preview_root == null or actor == null or active_wip == null:
		return null
	if CraftedItemWIP.is_unarmed_authoring_wip(active_wip):
		return _build_unarmed_preview_node(preview_root, actor, active_wip)
	var held_item: Node3D = equipped_item_presenter.build_equipped_item_node(
		active_wip,
		_resolve_preview_dominant_slot_id(),
		forge_service,
		_get_material_lookup(),
		held_item_mesh_builder,
		actor,
		DEFAULT_FORGE_RULES_RESOURCE,
		DEFAULT_FORGE_VIEW_TUNING_RESOURCE,
		true
	)
	if held_item == null:
		return null
	held_item.set_meta(PREVIEW_HAND_MOUNT_LOCAL_TRANSFORM_META, held_item.transform)
	held_item.set_meta(PREVIEW_HAND_MOUNT_LOCAL_TRANSFORM_ORIGIN_META, CombatOriginRecordScript.ORIGIN_HAND_GRIP_ALIGNMENT)
	preview_root.add_child(held_item)
	_apply_preview_hand_mounted_transform(actor, held_item)
	return held_item

func _build_unarmed_preview_node(preview_root: Node3D, actor: Node3D, active_wip: CraftedItemWIP) -> Node3D:
	var held_root := Node3D.new()
	held_root.name = "UnarmedHandProxy"
	held_root.set_meta("unarmed_hand_proxy", true)
	held_root.set_meta("source_wip_id", active_wip.wip_id)
	held_root.set_meta("grip_style_mode", CraftedItemWIP.GRIP_NORMAL)
	held_root.set_meta("two_hand_character_eligible", false)
	var hand_proxy_points_state: Dictionary = _resolve_unarmed_hand_proxy_points_state(actor, _resolve_preview_dominant_slot_id())
	if hand_proxy_points_state.is_empty():
		hand_proxy_points_state = _build_fallback_unarmed_proxy_points_state()
	var local_tip: Vector3 = _get_origin_tracked_vector3_state(
		hand_proxy_points_state,
		"tip_local",
		"tip_origin_id",
		Vector3(0.12, 0.0, 0.0),
		CombatOriginRecordScript.ORIGIN_HAND_GRIP_ALIGNMENT
	)
	var local_pommel: Vector3 = _get_origin_tracked_vector3_state(
		hand_proxy_points_state,
		"pommel_local",
		"pommel_origin_id",
		Vector3(-0.12, 0.0, 0.0),
		CombatOriginRecordScript.ORIGIN_HAND_GRIP_ALIGNMENT
	)
	var contact_center_local: Vector3 = _get_origin_tracked_vector3_state(
		hand_proxy_points_state,
		"contact_center_local",
		"contact_center_origin_id",
		local_pommel.lerp(local_tip, 0.5),
		CombatOriginRecordScript.ORIGIN_HAND_GRIP_ALIGNMENT
	)
	if local_tip.is_equal_approx(local_pommel):
		hand_proxy_points_state = _build_fallback_unarmed_proxy_points_state()
		local_tip = _get_origin_tracked_vector3_state(
			hand_proxy_points_state,
			"tip_local",
			"tip_origin_id",
			Vector3(0.12, 0.0, 0.0),
			CombatOriginRecordScript.ORIGIN_HAND_GRIP_ALIGNMENT
		)
		local_pommel = _get_origin_tracked_vector3_state(
			hand_proxy_points_state,
			"pommel_local",
			"pommel_origin_id",
			Vector3(-0.12, 0.0, 0.0),
			CombatOriginRecordScript.ORIGIN_HAND_GRIP_ALIGNMENT
		)
		contact_center_local = _get_origin_tracked_vector3_state(
			hand_proxy_points_state,
			"contact_center_local",
			"contact_center_origin_id",
			Vector3.ZERO,
			CombatOriginRecordScript.ORIGIN_HAND_GRIP_ALIGNMENT
		)
	var grip_axis_local: Vector3 = (local_tip - local_pommel).normalized()
	var grip_axis_origin_id: StringName = CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
	var span_half: float = clampf(local_tip.distance_to(local_pommel) * 0.16, 0.025, 0.055)
	var primary_grip_guide := Node3D.new()
	primary_grip_guide.name = "PrimaryGripGuide"
	primary_grip_guide.position = contact_center_local
	held_root.add_child(primary_grip_guide)
	var grip_center := Node3D.new()
	grip_center.name = "GripShellCenter"
	primary_grip_guide.add_child(grip_center)
	var minor_axis_a: Vector3 = _resolve_perpendicular_unit(grip_axis_local, Vector3.UP)
	var minor_axis_b: Vector3 = grip_axis_local.cross(minor_axis_a).normalized()
	grip_center.set_meta("grip_shell_valid", true)
	_set_origin_tracked_vector3_meta(
		grip_center,
		"grip_shell_major_axis_local",
		"grip_shell_major_axis_origin_id",
		grip_axis_local,
		grip_axis_origin_id
	)
	grip_center.set_meta("grip_shell_minor_axis_a_local", minor_axis_a)
	grip_center.set_meta("grip_shell_minor_axis_a_origin_id", CombatOriginRecordScript.ORIGIN_WEAPON_ROOT)
	grip_center.set_meta("grip_shell_minor_axis_b_local", minor_axis_b)
	grip_center.set_meta("grip_shell_minor_axis_b_origin_id", CombatOriginRecordScript.ORIGIN_WEAPON_ROOT)
	grip_center.set_meta("grip_shell_slice_center_local", Vector3.ZERO)
	grip_center.set_meta("grip_shell_slice_center_origin_id", CombatOriginRecordScript.ORIGIN_WEAPON_ROOT)
	held_root.set_meta(PREVIEW_HAND_MOUNT_LOCAL_TRANSFORM_META, Transform3D.IDENTITY)
	held_root.set_meta(PREVIEW_HAND_MOUNT_LOCAL_TRANSFORM_ORIGIN_META, CombatOriginRecordScript.ORIGIN_HAND_GRIP_ALIGNMENT)
	_set_origin_tracked_vector3_meta(held_root, "weapon_tip_local", "weapon_tip_origin_id", local_tip, CombatOriginRecordScript.ORIGIN_WEAPON_ROOT)
	_set_origin_tracked_vector3_meta(held_root, "weapon_pommel_local", "weapon_pommel_origin_id", local_pommel, CombatOriginRecordScript.ORIGIN_WEAPON_ROOT)
	held_root.set_meta("weapon_total_length_meters", local_tip.distance_to(local_pommel))
	_set_origin_tracked_vector3_meta(held_root, "primary_grip_contact_local", "primary_grip_contact_origin_id", contact_center_local, CombatOriginRecordScript.ORIGIN_WEAPON_ROOT)
	_set_origin_tracked_vector3_meta(
		held_root,
		"primary_grip_span_start_local",
		"primary_grip_span_start_origin_id",
		contact_center_local - grip_axis_local * span_half,
		grip_axis_origin_id
	)
	_set_origin_tracked_vector3_meta(
		held_root,
		"primary_grip_span_end_local",
		"primary_grip_span_end_origin_id",
		contact_center_local + grip_axis_local * span_half,
		grip_axis_origin_id
	)
	held_root.set_meta("primary_grip_axis_ratio_from_span_start", 0.5)
	_set_origin_tracked_vector3_meta(
		held_root,
		"primary_grip_slide_axis_local",
		"primary_grip_slide_axis_origin_id",
		grip_axis_local,
		grip_axis_origin_id
	)
	_set_origin_tracked_vector3_meta(
		held_root,
		PREVIEW_PRIMARY_GRIP_SEAT_LOCAL_META,
		PREVIEW_PRIMARY_GRIP_SEAT_ORIGIN_META,
		contact_center_local,
		CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
	)
	weapon_grip_anchor_provider.ensure_grip_anchor_nodes(held_root, primary_grip_guide, null)
	preview_root.add_child(held_root)
	_apply_preview_hand_mounted_transform(actor, held_root)
	return held_root

func _ensure_preview_weapon_parent(preview_root: Node3D, held_item: Node3D) -> void:
	if preview_root == null or held_item == null or not is_instance_valid(held_item):
		return
	if held_item.get_parent() == preview_root:
		return
	var preserved_transform: Transform3D = held_item.global_transform
	var current_parent: Node = held_item.get_parent()
	if current_parent != null:
		current_parent.remove_child(held_item)
	preview_root.add_child(held_item)
	held_item.global_transform = preserved_transform

func _apply_preview_motion_grip_state(
	held_item: Node3D,
	motion_node: CombatAnimationMotionNode,
	playback_state: Dictionary = {},
	actor: Node3D = null
) -> void:
	if held_item == null:
		return
	var unarmed_proxy: bool = _is_unarmed_preview_item(held_item)
	var requested_grip_style: StringName = StringName(playback_state.get(
		"preferred_grip_style_mode",
		motion_node.preferred_grip_style_mode if motion_node != null else held_item.get_meta("grip_style_mode", CraftedItemWIP.GRIP_NORMAL)
	))
	if not unarmed_proxy:
		equipped_item_presenter.apply_held_item_grip_style_mode(
			held_item,
			actor,
			_resolve_preview_dominant_slot_id(),
			requested_grip_style
		)
	held_item.set_meta("align_hand_bone_z_to_weapon_tip", false)
	_clear_preview_contact_axis_override(held_item)
	var requested_slide: float = float(playback_state.get(
		"grip_seat_slide_offset",
		motion_node.grip_seat_slide_offset if motion_node != null else 0.0
	))
	var requested_axial: float = float(playback_state.get(
		"axial_reposition_offset",
		motion_node.axial_reposition_offset if motion_node != null else 0.0
	))
	var requested_secondary_slide: float = float(playback_state.get(
		"secondary_grip_seat_slide_offset",
		motion_node.secondary_grip_seat_slide_offset if motion_node != null else CombatAnimationMotionNodeScript.DEFAULT_SECONDARY_GRIP_SEAT_SLIDE_OFFSET
	))
	var requested_primary_local: Vector3 = _get_primary_grip_contact_meta(held_item)
	if not unarmed_proxy:
		requested_primary_local = _resolve_primary_grip_seat_local_from_offsets(
			held_item,
			requested_slide,
			requested_axial
		)
	_set_origin_tracked_vector3_meta(
		held_item,
		PREVIEW_PRIMARY_GRIP_SEAT_LOCAL_META,
		PREVIEW_PRIMARY_GRIP_SEAT_ORIGIN_META,
		requested_primary_local,
		CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
	)
	var support_anchor: Node3D = weapon_grip_anchor_provider.get_support_grip_anchor(held_item)
	if support_anchor != null:
		var requested_support_local: Vector3 = support_anchor.position
		if not unarmed_proxy:
			requested_support_local = _resolve_secondary_grip_seat_local_from_offsets(
				held_item,
				requested_secondary_slide
			)
		_set_origin_tracked_vector3_meta(
			held_item,
			PREVIEW_SUPPORT_GRIP_SEAT_LOCAL_META,
			PREVIEW_SUPPORT_GRIP_SEAT_ORIGIN_META,
			requested_support_local,
			CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
		)
		held_item.set_meta(PREVIEW_SECONDARY_GRIP_SEAT_AUTHORED_META, true)
	else:
		held_item.set_meta(PREVIEW_SECONDARY_GRIP_SEAT_AUTHORED_META, false)
	_apply_preview_resolved_grip_state(held_item)

func _apply_preview_resolved_grip_state(held_item: Node3D) -> void:
	if held_item == null:
		return
	var primary_local: Vector3 = _get_preview_primary_grip_seat_meta(held_item)
	_apply_preview_grip_local_position(held_item, "PrimaryGripGuide", weapon_grip_anchor_provider.get_primary_grip_anchor(held_item), primary_local)
	if held_item.has_meta(PREVIEW_SUPPORT_GRIP_SEAT_LOCAL_META):
		var support_local: Vector3 = _get_preview_support_grip_seat_meta(held_item)
		_apply_preview_grip_local_position(held_item, "SecondaryGripGuide", weapon_grip_anchor_provider.get_support_grip_anchor(held_item), support_local)

func _sync_preview_contact_axis_override(held_item: Node3D, playback_state: Dictionary, trajectory_root: Node3D) -> void:
	_clear_preview_contact_axis_override(held_item)
	if held_item == null or trajectory_root == null:
		return
	var contact_grip_axis_override_active_origin_id: StringName = StringName(playback_state.get(
		"contact_grip_axis_origin_id",
		CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING
	))
	if not bool(playback_state.get("contact_grip_axis_local_override_active", false)):
		return
	var contact_axis_local: Vector3 = playback_state.get("contact_grip_axis_local", Vector3.ZERO) as Vector3
	if contact_axis_local.length_squared() <= 0.000001:
		return
	var contact_axis_origin_id: StringName = contact_grip_axis_override_active_origin_id
	var contact_axis_world: Vector3 = trajectory_root.global_basis * contact_axis_local.normalized()
	if contact_axis_world.length_squared() <= 0.000001:
		return
	held_item.set_meta("authoring_contact_grip_axis_world_override", contact_axis_world.normalized())
	held_item.set_meta("authoring_contact_grip_axis_origin_id", contact_axis_origin_id)

func _clear_preview_contact_axis_override(held_item: Node3D) -> void:
	if held_item == null:
		return
	if held_item.has_meta("authoring_contact_grip_axis_world_override"):
		held_item.remove_meta("authoring_contact_grip_axis_world_override")
	if held_item.has_meta("authoring_contact_grip_axis_origin_id"):
		held_item.remove_meta("authoring_contact_grip_axis_origin_id")

func _apply_preview_grip_local_position(
	held_item: Node3D,
	guide_name: String,
	anchor_node: Node3D,
	local_position: Vector3
) -> void:
	if held_item == null:
		return
	var guide_node: Node3D = held_item.get_node_or_null(guide_name) as Node3D
	if guide_node != null:
		guide_node.position = local_position
	if anchor_node != null:
		anchor_node.position = local_position

func _resolve_primary_grip_seat_local_from_offsets(
	held_item: Node3D,
	slide_offset: float,
	axial_offset: float
) -> Vector3:
	if held_item == null:
		return Vector3.ZERO
	var base_ratio: float = float(held_item.get_meta("primary_grip_axis_ratio_from_span_start", 0.0))
	var fallback_local: Vector3 = _get_primary_grip_contact_meta(held_item)
	return _resolve_grip_seat_local_from_offsets(
		held_item,
		fallback_local,
		base_ratio,
		slide_offset,
		axial_offset
	)

func _resolve_secondary_grip_seat_local_from_offsets(
	held_item: Node3D,
	slide_offset: float
) -> Vector3:
	if held_item == null:
		return Vector3.ZERO
	var base_local: Vector3 = _resolve_secondary_grip_default_local(held_item)
	var base_ratio: float = _project_grip_span_ratio_for_local(held_item, base_local, 0.0)
	return _resolve_grip_seat_local_from_offsets(
		held_item,
		base_local,
		base_ratio,
		slide_offset,
		0.0
	)

func _resolve_grip_seat_local_from_offsets(
	held_item: Node3D,
	fallback_local: Vector3,
	base_ratio: float,
	slide_offset: float,
	axial_offset: float
) -> Vector3:
	if held_item == null:
		return fallback_local
	var span_start: Vector3 = _get_origin_tracked_vector3_meta(
		held_item,
		"primary_grip_span_start_local",
		"primary_grip_span_start_origin_id",
		fallback_local,
		CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
	)
	var span_end: Vector3 = _get_origin_tracked_vector3_meta(
		held_item,
		"primary_grip_span_end_local",
		"primary_grip_span_end_origin_id",
		fallback_local,
		CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
	)
	var span_vector: Vector3 = span_end - span_start
	if span_vector.length_squared() <= 0.000001:
		return fallback_local
	var clamped_slide: float = clampf(slide_offset, -1.0, 1.0)
	var target_ratio: float = clampf(base_ratio, 0.0, 1.0)
	if clamped_slide > 0.0:
		target_ratio = lerpf(target_ratio, 1.0, clamped_slide)
	elif clamped_slide < 0.0:
		target_ratio = lerpf(target_ratio, 0.0, absf(clamped_slide))
	var clamped_axial: float = clampf(axial_offset, -1.0, 1.0)
	target_ratio = clampf(target_ratio + (clamped_axial * 0.5), 0.0, 1.0)
	return span_start.lerp(span_end, clampf(target_ratio, 0.0, 1.0))

func _resolve_secondary_grip_default_local(held_item: Node3D) -> Vector3:
	if held_item == null:
		return Vector3.ZERO
	if held_item.has_meta("support_grip_contact_local"):
		return _get_support_grip_contact_meta(held_item)
	var secondary_guide: Node3D = held_item.get_node_or_null("SecondaryGripGuide") as Node3D
	if secondary_guide != null:
		var guide_local: Vector3 = secondary_guide.position
		_set_origin_tracked_vector3_meta(
			held_item,
			"support_grip_contact_local",
			"support_grip_contact_origin_id",
			guide_local,
			CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
		)
		return guide_local
	var support_anchor: Node3D = weapon_grip_anchor_provider.get_support_grip_anchor(held_item)
	if support_anchor != null:
		var anchor_local: Vector3 = support_anchor.position
		_set_origin_tracked_vector3_meta(
			held_item,
			"support_grip_contact_local",
			"support_grip_contact_origin_id",
			anchor_local,
			CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
		)
		return anchor_local
	return _get_primary_grip_contact_meta(held_item)

func _project_grip_span_ratio_for_local(
	held_item: Node3D,
	local_position: Vector3,
	fallback_ratio: float
) -> float:
	if held_item == null:
		return fallback_ratio
	var span_start: Vector3 = _get_origin_tracked_vector3_meta(
		held_item,
		"primary_grip_span_start_local",
		"primary_grip_span_start_origin_id",
		local_position,
		CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
	)
	var span_end: Vector3 = _get_origin_tracked_vector3_meta(
		held_item,
		"primary_grip_span_end_local",
		"primary_grip_span_end_origin_id",
		local_position,
		CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
	)
	var span_vector: Vector3 = span_end - span_start
	var span_length_squared: float = span_vector.length_squared()
	if span_length_squared <= 0.000001:
		return clampf(fallback_ratio, 0.0, 1.0)
	return clampf((local_position - span_start).dot(span_vector) / span_length_squared, 0.0, 1.0)

func _apply_two_hand_preview_state(actor: Node3D, held_item: Node3D, selected_motion_node: CombatAnimationMotionNode) -> void:
	if actor == null:
		return
	var dominant_slot_id: StringName = _resolve_preview_dominant_slot_id()
	equipped_item_presenter.clear_rig_weapon_contact_guidance(actor)
	if held_item != null and is_instance_valid(held_item):
		held_item.set_meta("dominant_contact_slot_id", dominant_slot_id)
		equipped_item_presenter.sync_single_weapon_contact_guidance(
			actor,
			held_item,
			dominant_slot_id,
			_should_preview_use_support_hand(held_item, selected_motion_node),
			true,
			true,
			true,
			true
		)
	if actor.has_method("update_locomotion_state"):
		actor.call("update_locomotion_state", 0.0, 0.0, true, 0.0, false)

func _apply_preview_upper_body_authoring_state(
	actor: Node3D,
	held_item: Node3D,
	selected_motion_node: CombatAnimationMotionNode,
	playback_state: Dictionary = {},
	tip_world_override: Vector3 = Vector3.INF,
	pommel_world_override: Vector3 = Vector3.INF,
	transform_override: Transform3D = Transform3D.IDENTITY,
	use_transform_override: bool = false
) -> void:
	if actor == null:
		return
	if held_item == null or not is_instance_valid(held_item):
		if actor.has_method("clear_upper_body_authoring_state"):
			actor.call("clear_upper_body_authoring_state")
		return
	if not actor.has_method("set_upper_body_authoring_state"):
		return
	var payload: Dictionary = _build_preview_upper_body_authoring_payload(
		held_item,
		selected_motion_node,
		playback_state,
		tip_world_override,
		pommel_world_override,
		transform_override,
		use_transform_override
	)
	if payload.is_empty():
		return
	actor.call("set_upper_body_authoring_state", payload)

func _build_preview_upper_body_authoring_payload(
	held_item: Node3D,
	selected_motion_node: CombatAnimationMotionNode,
	playback_state: Dictionary = {},
	tip_world_override: Vector3 = Vector3.INF,
	pommel_world_override: Vector3 = Vector3.INF,
	transform_override: Transform3D = Transform3D.IDENTITY,
	use_transform_override: bool = false
) -> Dictionary:
	if held_item == null or not is_instance_valid(held_item):
		return {}
	var local_tip: Vector3 = _get_weapon_tip_meta(held_item)
	var local_pommel: Vector3 = _get_weapon_pommel_meta(held_item)
	var primary_anchor: Node3D = weapon_grip_anchor_provider.get_primary_grip_anchor(held_item)
	var support_anchor: Node3D = weapon_grip_anchor_provider.get_support_grip_anchor(held_item)
	var authored_blend: float = float(playback_state.get(
		"body_support_blend",
		selected_motion_node.body_support_blend if selected_motion_node != null else 0.0
	))
	var primary_target_world: Vector3 = primary_anchor.global_position if primary_anchor != null else Vector3.ZERO
	var secondary_target_world: Vector3 = support_anchor.global_position if support_anchor != null else Vector3.ZERO
	if use_transform_override:
		if primary_anchor != null:
			primary_target_world = transform_override * primary_anchor.position
		if support_anchor != null:
			secondary_target_world = transform_override * support_anchor.position
	var resolved_tip_world: Vector3 = (
		tip_world_override
		if tip_world_override != Vector3.INF
		else held_item.to_global(local_tip)
	)
	var resolved_pommel_world: Vector3 = (
		pommel_world_override
		if pommel_world_override != Vector3.INF
		else held_item.to_global(local_pommel)
	)
	return {
		"active": true,
		"blend": clampf(authored_blend, 0.0, 1.0),
		"two_hand": _should_preview_use_support_hand(held_item, selected_motion_node),
		"dominant_slot_id": _resolve_preview_dominant_slot_id(),
		"right_upperarm_roll_degrees": float(playback_state.get(
			"right_upperarm_roll_degrees",
			selected_motion_node.right_upperarm_roll_degrees if selected_motion_node != null else 0.0
		)),
		"left_upperarm_roll_degrees": float(playback_state.get(
			"left_upperarm_roll_degrees",
			selected_motion_node.left_upperarm_roll_degrees if selected_motion_node != null else 0.0
		)),
		"primary_target_world": primary_target_world,
		"secondary_target_world": secondary_target_world,
		"tip_world": resolved_tip_world,
		"pommel_world": resolved_pommel_world,
	}

func _apply_preview_actor_upper_body_pose_now(actor: Node3D) -> void:
	if actor == null:
		return
	if actor.has_method("apply_authoring_preview_frame_now"):
		actor.call("apply_authoring_preview_frame_now")
		return
	if actor.has_method("apply_upper_body_authoring_pose_now"):
		actor.call("apply_upper_body_authoring_pose_now")

func _settle_preview_contact_group_on_resolved_weapon(
	actor: Node3D,
	held_item: Node3D,
	selected_motion_node: CombatAnimationMotionNode,
	resolved_playback_state: Dictionary
) -> void:
	if actor == null or held_item == null or selected_motion_node == null:
		return
	if not is_instance_valid(held_item):
		return
	# Contact coupling can move the weapon after the first hand solve. Run one
	# final body/contact pass so fingers and palm seat against the final weapon
	# frame, not the pre-coupled authoring frame.
	_apply_two_hand_preview_state(actor, held_item, selected_motion_node)
	_apply_preview_upper_body_authoring_state(actor, held_item, selected_motion_node, resolved_playback_state)
	_apply_preview_actor_upper_body_pose_now(actor)

func _settle_preview_contact_and_body_clearance(
	actor: Node3D,
	held_item: Node3D,
	selected_motion_node: CombatAnimationMotionNode,
	resolved_playback_state: Dictionary,
	trajectory_root: Node3D,
	local_tip: Vector3,
	local_pommel: Vector3,
	weapon_orientation_degrees: Vector3,
	max_iterations: int = AUTHORING_BODY_CONTACT_COUPLED_ITERATIONS
) -> Dictionary:
	var updated_playback_state: Dictionary = resolved_playback_state.duplicate(true)
	var metrics := {
		"iterations": 0,
		"max_weapon_reseat_delta_meters": 0.0,
		"max_weapon_move_delta_meters": 0.0,
		"final_hand_authority_reseat_delta_meters": 0.0,
		"final_hand_authority_separation_delta_meters": 0.0,
		"dominant_grip_error_before_meters": -1.0,
		"dominant_grip_error_after_meters": -1.0,
		"collision_legal": true,
		"collision_separation_iterations": 0,
		"stopped_reason": "not_started",
	}
	var result := {
		"playback_state": updated_playback_state,
		"metrics": metrics,
		"collision_result": {},
	}
	if actor == null or held_item == null or selected_motion_node == null or trajectory_root == null:
		metrics["stopped_reason"] = "missing_context"
		return result
	if not is_instance_valid(held_item):
		metrics["stopped_reason"] = "missing_weapon"
		return result
	var iteration_count: int = maxi(max_iterations, 0)
	if iteration_count <= 0:
		metrics["stopped_reason"] = "disabled"
		return result
	var dominant_slot_id: StringName = _resolve_preview_dominant_slot_id()
	var previous_grip_error: float = _resolve_preview_grip_alignment_error(actor, held_item, dominant_slot_id)
	metrics["dominant_grip_error_before_meters"] = previous_grip_error
	var final_collision_result: Dictionary = {}
	for iteration_index: int in range(iteration_count):
		_settle_preview_contact_group_on_resolved_weapon(actor, held_item, selected_motion_node, updated_playback_state)
		var primary_local: Vector3 = _resolve_preview_primary_grip_anchor_local(held_item)
		_set_origin_tracked_vector3_meta(
			held_item,
			PREVIEW_PRIMARY_GRIP_SEAT_LOCAL_META,
			PREVIEW_PRIMARY_GRIP_SEAT_ORIGIN_META,
			primary_local,
			CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
		)
		var corrected_hand_target_world: Vector3 = _resolve_preview_primary_grip_target_world(actor, held_item)
		var reseat_before_transform: Transform3D = held_item.global_transform
		var reseated_transform: Transform3D = _lock_preview_transform_to_dominant_grip_target(
			reseat_before_transform,
			primary_local,
			corrected_hand_target_world,
			AUTHORING_CONTACT_SEAT_LOCK_STRENGTH
		)
		reseated_transform = _apply_preview_support_coupling(
			actor,
			held_item,
			selected_motion_node,
			reseated_transform,
			AUTHORING_CONTACT_SEAT_LOCK_STRENGTH
		)
		var reseat_delta: float = reseated_transform.origin.distance_to(reseat_before_transform.origin)
		metrics["max_weapon_reseat_delta_meters"] = maxf(
			float(metrics.get("max_weapon_reseat_delta_meters", 0.0)),
			reseat_delta
		)
		if reseat_delta > AUTHORING_BODY_CONTACT_SETTLE_EPSILON_METERS:
			held_item.global_transform = reseated_transform
			_apply_preview_resolved_grip_state(held_item)
			updated_playback_state = _resolve_playback_state_from_held_item_transform(
				updated_playback_state,
				held_item,
				trajectory_root,
				local_tip,
				local_pommel,
				weapon_orientation_degrees
			)
		var before_transform: Transform3D = held_item.global_transform
		var separation_result: Dictionary = _separate_preview_weapon_transform_from_body(
			actor,
			held_item,
			before_transform
		)
		var separated_transform: Transform3D = separation_result.get("transform", before_transform) as Transform3D
		var weapon_move_delta: float = separated_transform.origin.distance_to(before_transform.origin)
		metrics["iterations"] = iteration_index + 1
		metrics["max_weapon_move_delta_meters"] = maxf(
			float(metrics.get("max_weapon_move_delta_meters", 0.0)),
			weapon_move_delta
		)
		metrics["collision_separation_iterations"] = int(metrics.get("collision_separation_iterations", 0)) + int(separation_result.get("iterations", 0))
		if weapon_move_delta > AUTHORING_BODY_CONTACT_SETTLE_EPSILON_METERS:
			held_item.global_transform = separated_transform
			_apply_preview_resolved_grip_state(held_item)
			updated_playback_state = _resolve_playback_state_from_held_item_transform(
				updated_playback_state,
				held_item,
				trajectory_root,
				local_tip,
				local_pommel,
				weapon_orientation_degrees
			)
		_settle_preview_contact_group_on_resolved_weapon(actor, held_item, selected_motion_node, updated_playback_state)
		final_collision_result = _evaluate_preview_collision_pose(actor, held_item, held_item.global_transform)
		var grip_error: float = _resolve_preview_grip_alignment_error(actor, held_item, dominant_slot_id)
		metrics["dominant_grip_error_after_meters"] = grip_error
		var grip_delta: float = absf(grip_error - previous_grip_error) if grip_error >= 0.0 and previous_grip_error >= 0.0 else INF
		var collision_legal: bool = bool(final_collision_result.get("legal", true))
		metrics["collision_legal"] = collision_legal
		var weapon_delta: float = maxf(reseat_delta, weapon_move_delta)
		if collision_legal and grip_error >= 0.0 and grip_error <= AUTHORING_BODY_CONTACT_GRIP_EPSILON_METERS:
			metrics["stopped_reason"] = "legal_grip"
			break
		if weapon_delta <= AUTHORING_BODY_CONTACT_SETTLE_EPSILON_METERS and grip_delta <= AUTHORING_BODY_CONTACT_GRIP_STALL_EPSILON_METERS:
			metrics["stopped_reason"] = "stalled_bounded"
			break
		previous_grip_error = grip_error
		if iteration_index == iteration_count - 1:
			metrics["stopped_reason"] = "max_iterations"
	var final_grip_error: float = _resolve_preview_grip_alignment_error(actor, held_item, dominant_slot_id)
	if final_grip_error > AUTHORING_BODY_CONTACT_GRIP_EPSILON_METERS:
		var final_reseat_delta: float = 0.0
		for _final_reseat_index: int in range(2):
			var final_primary_local: Vector3 = _resolve_preview_primary_grip_anchor_local(held_item)
			_set_origin_tracked_vector3_meta(
				held_item,
				PREVIEW_PRIMARY_GRIP_SEAT_LOCAL_META,
				PREVIEW_PRIMARY_GRIP_SEAT_ORIGIN_META,
				final_primary_local,
				CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
			)
			var final_hand_target_world: Vector3 = _resolve_preview_primary_grip_target_world(actor, held_item)
			var final_before_transform: Transform3D = held_item.global_transform
			var final_reseated_transform: Transform3D = _lock_preview_transform_to_dominant_grip_target(
				final_before_transform,
				final_primary_local,
				final_hand_target_world,
				AUTHORING_CONTACT_SEAT_LOCK_STRENGTH
			)
			var pass_reseat_delta: float = final_reseated_transform.origin.distance_to(final_before_transform.origin)
			final_reseat_delta = maxf(final_reseat_delta, pass_reseat_delta)
			if pass_reseat_delta <= AUTHORING_BODY_CONTACT_SETTLE_EPSILON_METERS:
				continue
			held_item.global_transform = final_reseated_transform
			_apply_preview_resolved_grip_state(held_item)
			updated_playback_state = _resolve_playback_state_from_held_item_transform(
				updated_playback_state,
				held_item,
				trajectory_root,
				local_tip,
				local_pommel,
				weapon_orientation_degrees
			)
		var final_separation_result: Dictionary = _separate_preview_weapon_transform_from_body(
			actor,
			held_item,
			held_item.global_transform,
			1
		)
		var final_separated_transform: Transform3D = final_separation_result.get("transform", held_item.global_transform) as Transform3D
		var final_separation_delta: float = final_separated_transform.origin.distance_to(held_item.global_transform.origin)
		if final_separation_delta > AUTHORING_BODY_CONTACT_SETTLE_EPSILON_METERS:
			held_item.global_transform = final_separated_transform
			_apply_preview_resolved_grip_state(held_item)
			updated_playback_state = _resolve_playback_state_from_held_item_transform(
				updated_playback_state,
				held_item,
				trajectory_root,
				local_tip,
				local_pommel,
				weapon_orientation_degrees
			)
		metrics["final_hand_authority_reseat_delta_meters"] = final_reseat_delta
		metrics["final_hand_authority_separation_delta_meters"] = final_separation_delta
		final_collision_result = _evaluate_preview_collision_pose(actor, held_item, held_item.global_transform)
		final_grip_error = _resolve_preview_grip_alignment_error(actor, held_item, dominant_slot_id)
		metrics["dominant_grip_error_after_meters"] = final_grip_error
		metrics["collision_legal"] = bool(final_collision_result.get("legal", true))
		if bool(final_collision_result.get("legal", true)) and final_grip_error <= AUTHORING_BODY_CONTACT_GRIP_EPSILON_METERS:
			metrics["stopped_reason"] = "final_hand_reseat"
	result["playback_state"] = updated_playback_state
	result["metrics"] = metrics
	result["collision_result"] = final_collision_result
	return result

func _resolve_playback_state_from_held_item_transform(
	resolved_playback_state: Dictionary,
	held_item: Node3D,
	trajectory_root: Node3D,
	local_tip: Vector3,
	local_pommel: Vector3,
	weapon_orientation_degrees: Vector3
) -> Dictionary:
	var updated_playback_state: Dictionary = resolved_playback_state.duplicate(true)
	if held_item == null or trajectory_root == null or not is_instance_valid(held_item):
		return updated_playback_state
	var solved_tip_world: Vector3 = held_item.to_global(local_tip)
	var solved_pommel_world: Vector3 = held_item.to_global(local_pommel)
	_set_tip_pommel_position_state(
		updated_playback_state,
		trajectory_root.to_local(solved_tip_world),
		trajectory_root.to_local(solved_pommel_world),
		CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING
	)
	updated_playback_state["weapon_orientation_degrees"] = weapon_orientation_degrees
	return updated_playback_state

func _resolve_preview_primary_grip_anchor_local(held_item: Node3D) -> Vector3:
	if held_item == null or not is_instance_valid(held_item):
		return Vector3.ZERO
	var primary_anchor: Node3D = weapon_grip_anchor_provider.get_primary_grip_anchor(held_item)
	if primary_anchor != null and is_instance_valid(primary_anchor):
		return primary_anchor.position
	return _get_preview_primary_grip_seat_meta(held_item)

func _seat_preview_weapon_to_current_dominant_hand(
	actor: Node3D,
	held_item: Node3D,
	resolved_playback_state: Dictionary,
	trajectory_root: Node3D,
	local_tip: Vector3,
	local_pommel: Vector3,
	weapon_orientation_degrees: Vector3
) -> Dictionary:
	var updated_playback_state: Dictionary = resolved_playback_state.duplicate(true)
	var metrics := {
		"max_reseat_delta_meters": 0.0,
		"grip_error_after_meters": -1.0,
	}
	if actor == null or held_item == null or trajectory_root == null or not is_instance_valid(held_item):
		return {
			"playback_state": updated_playback_state,
			"metrics": metrics,
		}
	for _reseat_index: int in range(2):
		var primary_local: Vector3 = _resolve_preview_primary_grip_anchor_local(held_item)
		_set_origin_tracked_vector3_meta(
			held_item,
			PREVIEW_PRIMARY_GRIP_SEAT_LOCAL_META,
			PREVIEW_PRIMARY_GRIP_SEAT_ORIGIN_META,
			primary_local,
			CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
		)
		var target_world: Vector3 = _resolve_preview_hand_grip_target_world(actor, _resolve_preview_dominant_slot_id())
		if target_world.length_squared() <= 0.000001:
			break
		var before_transform: Transform3D = held_item.global_transform
		var reseated_transform: Transform3D = _lock_preview_transform_to_dominant_grip_target(
			before_transform,
			primary_local,
			target_world,
			AUTHORING_CONTACT_SEAT_LOCK_STRENGTH
		)
		var reseat_delta: float = reseated_transform.origin.distance_to(before_transform.origin)
		metrics["max_reseat_delta_meters"] = maxf(float(metrics.get("max_reseat_delta_meters", 0.0)), reseat_delta)
		if reseat_delta <= AUTHORING_BODY_CONTACT_SETTLE_EPSILON_METERS:
			continue
		held_item.global_transform = reseated_transform
		_apply_preview_resolved_grip_state(held_item)
		updated_playback_state = _resolve_playback_state_from_held_item_transform(
			updated_playback_state,
			held_item,
			trajectory_root,
			local_tip,
			local_pommel,
			weapon_orientation_degrees
		)
	metrics["grip_error_after_meters"] = _resolve_preview_grip_alignment_error(actor, held_item, _resolve_preview_dominant_slot_id())
	return {
		"playback_state": updated_playback_state,
		"metrics": metrics,
	}

func _solve_weapon_segment_transform(
	held_item: Node3D,
	trajectory_root: Node3D,
	selected_motion_node: CombatAnimationMotionNode,
	local_tip: Vector3,
	local_pommel: Vector3,
	authored_tip_world: Vector3,
	authored_pommel_world: Vector3,
	weapon_orientation_degrees: Vector3 = Vector3.ZERO,
	local_tip_origin_id: StringName = CombatOriginRecordScript.ORIGIN_WEAPON_ROOT,
	local_pommel_origin_id: StringName = CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
) -> Transform3D:
	var local_axis: Vector3 = (local_tip - local_pommel).normalized()
	var local_up_reference_origin_id: StringName = CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
	var local_up_reference: Vector3 = _resolve_weapon_local_up_reference(held_item, local_axis)
	return weapon_frame_solver.solve_transform_from_segment(
		local_tip,
		local_pommel,
		authored_tip_world,
		authored_pommel_world,
		local_up_reference,
		trajectory_root.global_basis,
		weapon_orientation_degrees,
		selected_motion_node.weapon_roll_degrees,
		local_tip_origin_id,
		local_pommel_origin_id,
		local_up_reference_origin_id
	)

func _solve_weapon_transform_from_tip_and_grip(
	held_item: Node3D,
	trajectory_root: Node3D,
	selected_motion_node: CombatAnimationMotionNode,
	local_tip: Vector3,
	local_grip: Vector3,
	authored_tip_world: Vector3,
	authored_grip_world: Vector3,
	weapon_orientation_degrees: Vector3 = Vector3.ZERO,
	local_tip_origin_id: StringName = CombatOriginRecordScript.ORIGIN_WEAPON_ROOT,
	local_grip_origin_id: StringName = CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
) -> Transform3D:
	var local_axis: Vector3 = (local_tip - local_grip).normalized()
	var local_up_reference_origin_id: StringName = CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
	var local_up_reference: Vector3 = _resolve_weapon_local_up_reference(held_item, local_axis)
	return weapon_frame_solver.solve_transform_from_tip_and_grip(
		local_tip,
		local_grip,
		authored_tip_world,
		authored_grip_world,
		local_up_reference,
		trajectory_root.global_basis,
		weapon_orientation_degrees,
		selected_motion_node.weapon_roll_degrees,
		local_tip_origin_id,
		local_grip_origin_id,
		local_up_reference_origin_id
	)

func _resolve_motion_node_weapon_orientation_degrees(motion_node: CombatAnimationMotionNode) -> Vector3:
	if motion_node == null:
		return Vector3.ZERO
	if motion_node.weapon_orientation_authored:
		return motion_node.weapon_orientation_degrees
	if not motion_node.weapon_orientation_degrees.is_zero_approx():
		return motion_node.weapon_orientation_degrees
	return Vector3.ZERO

func _resolve_weapon_local_up_reference(held_item: Node3D, local_axis: Vector3) -> Vector3:
	var basis_anchor: Node3D = weapon_grip_anchor_provider.get_primary_grip_basis_anchor(held_item)
	var local_up_reference: Vector3 = basis_anchor.transform.basis.y if basis_anchor != null else Vector3.UP
	local_up_reference = (local_up_reference - local_axis * local_up_reference.dot(local_axis))
	if local_up_reference.length_squared() <= 0.000001:
		local_up_reference = Vector3.UP - local_axis * Vector3.UP.dot(local_axis)
	if local_up_reference.length_squared() <= 0.000001:
		local_up_reference = Vector3.RIGHT - local_axis * Vector3.RIGHT.dot(local_axis)
	return local_up_reference.normalized()

func _build_basis_from_axis_and_up(axis: Vector3, up_reference: Vector3) -> Basis:
	var forward: Vector3 = axis.normalized()
	var projected_up: Vector3 = up_reference - forward * up_reference.dot(forward)
	if projected_up.length_squared() <= 0.000001:
		projected_up = Vector3.UP - forward * Vector3.UP.dot(forward)
	if projected_up.length_squared() <= 0.000001:
		projected_up = Vector3.RIGHT - forward * Vector3.RIGHT.dot(forward)
	var up: Vector3 = projected_up.normalized()
	var right: Vector3 = up.cross(forward).normalized()
	up = forward.cross(right).normalized()
	return Basis(right, up, forward).orthonormalized()

func _resolve_constrained_authored_segment_local(
	actor: Node3D,
	held_item: Node3D,
	trajectory_root: Node3D,
	motion_node: CombatAnimationMotionNode,
	tip_position_local: Vector3,
	pommel_position_local: Vector3,
	dominant_seat_lock_strength: float = 1.0
) -> Dictionary:
	if actor == null or held_item == null or trajectory_root == null or motion_node == null:
		return {
			"tip_position_local": tip_position_local,
			"tip_position_origin_id": CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING,
			"pommel_position_local": pommel_position_local,
			"pommel_position_origin_id": CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING,
		}
	var local_tip: Vector3 = _get_weapon_tip_meta(held_item)
	var local_pommel: Vector3 = _get_weapon_pommel_meta(held_item)
	if local_tip.is_equal_approx(local_pommel):
		return {
			"tip_position_local": tip_position_local,
			"tip_position_origin_id": CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING,
			"pommel_position_local": pommel_position_local,
			"pommel_position_origin_id": CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING,
		}
	var resolved_weapon_orientation_degrees: Vector3 = _resolve_motion_node_weapon_orientation_degrees(motion_node)
	var volume_result: Dictionary = _project_preview_segment_local_to_valid_motion_volume(
		actor,
		held_item,
		trajectory_root,
		tip_position_local,
		pommel_position_local
	)
	tip_position_local = _get_origin_tracked_vector3_state(
		volume_result,
		"tip_position",
		"tip_position_origin_id",
		tip_position_local,
		CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING
	)
	pommel_position_local = _get_origin_tracked_vector3_state(
		volume_result,
		"pommel_position",
		"pommel_position_origin_id",
		pommel_position_local,
		CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING
	)
	var authored_tip_world: Vector3 = trajectory_root.to_global(tip_position_local)
	var authored_pommel_world: Vector3 = trajectory_root.to_global(pommel_position_local)
	if authored_tip_world.distance_to(authored_pommel_world) <= SEGMENT_LEGALITY_EPSILON_METERS:
		var preferred_grip_world: Vector3 = _resolve_preview_primary_grip_target_world(actor, held_item)
		var requested_grip_local: Vector3 = _get_preview_primary_grip_seat_meta(held_item)
		_set_origin_tracked_vector3_meta(
			held_item,
			PREVIEW_PRIMARY_GRIP_SEAT_LOCAL_META,
			PREVIEW_PRIMARY_GRIP_SEAT_ORIGIN_META,
			requested_grip_local,
			CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
		)
		var provisional_grip_transform: Transform3D = _resolve_preview_hand_mounted_transform(actor, held_item)
		var grip_legality: Dictionary = _evaluate_preview_segment_legality(
			actor,
			held_item,
			provisional_grip_transform,
			motion_node
		)
		var fallback_resolved_grip_local: Vector3 = _get_origin_tracked_vector3_state(
			grip_legality,
			"dominant_resolved_grip_seat_local",
			"dominant_resolved_grip_seat_origin_id",
			requested_grip_local,
			CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
		)
		var fallback_resolved_grip_origin_id: StringName = _resolve_origin_tracked_state_origin_id(
			grip_legality,
			"dominant_resolved_grip_seat_origin_id",
			CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
		)
		_set_origin_tracked_vector3_meta(
			held_item,
			PREVIEW_PRIMARY_GRIP_SEAT_LOCAL_META,
			PREVIEW_PRIMARY_GRIP_SEAT_ORIGIN_META,
			fallback_resolved_grip_local,
			fallback_resolved_grip_origin_id
		)
		var corrected_grip_world: Vector3 = grip_legality.get(
			"dominant_corrected_target",
			preferred_grip_world
		) as Vector3
		var solved_grip_transform: Transform3D = _lock_preview_transform_to_dominant_grip_target(
			provisional_grip_transform,
			fallback_resolved_grip_local,
			corrected_grip_world,
			dominant_seat_lock_strength
		)
		solved_grip_transform = _apply_preview_support_coupling(
			actor,
			held_item,
			motion_node,
			solved_grip_transform,
			dominant_seat_lock_strength
		)
		var fallback_separation_result: Dictionary = _separate_preview_weapon_transform_from_body(actor, held_item, solved_grip_transform)
		solved_grip_transform = fallback_separation_result.get("transform", solved_grip_transform) as Transform3D
		var fallback_collision_result: Dictionary = fallback_separation_result.get("collision_result", {}) as Dictionary
		var solved_tip_world_from_grip: Vector3 = solved_grip_transform * local_tip
		var solved_pommel_world_from_grip: Vector3 = solved_grip_transform * local_pommel
		return {
			"tip_position_local": trajectory_root.to_local(solved_tip_world_from_grip),
			"tip_position_origin_id": CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING,
			"pommel_position_local": trajectory_root.to_local(solved_pommel_world_from_grip),
			"pommel_position_origin_id": CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING,
			"solved_transform": solved_grip_transform,
			"has_solved_transform": true,
			"legal": bool(fallback_separation_result.get("legal", true)),
			"collision_illegal_sample_count": int(fallback_collision_result.get("illegal_sample_count", 0)),
			"collision_region": String(fallback_collision_result.get("colliding_body_region", "")),
			"collision_sample": String(fallback_collision_result.get("colliding_sample_name", "")),
			"collision_clearance_meters": float(fallback_collision_result.get("estimated_clearance_meters", -1.0)),
		}
	var provisional_transform: Transform3D = _solve_weapon_segment_transform(
		held_item,
		trajectory_root,
		motion_node,
		local_tip,
		local_pommel,
		authored_tip_world,
		authored_pommel_world,
		resolved_weapon_orientation_degrees
	)
	var legality: Dictionary = _evaluate_preview_segment_legality(actor, held_item, provisional_transform, motion_node)
	var resolved_grip_local: Vector3 = _get_origin_tracked_vector3_state(
		legality,
		"dominant_resolved_grip_seat_local",
		"dominant_resolved_grip_seat_origin_id",
		_get_primary_grip_contact_meta(held_item),
		CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
	)
	var resolved_grip_origin_id: StringName = _resolve_origin_tracked_state_origin_id(
		legality,
		"dominant_resolved_grip_seat_origin_id",
		CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
	)
	_set_origin_tracked_vector3_meta(
		held_item,
		PREVIEW_PRIMARY_GRIP_SEAT_LOCAL_META,
		PREVIEW_PRIMARY_GRIP_SEAT_ORIGIN_META,
		resolved_grip_local,
		resolved_grip_origin_id
	)
	var legalized_segment: Dictionary = _build_preview_legalized_segment_world_positions(
		authored_tip_world,
		authored_pommel_world,
		legality
	)
	var resolved_tip_world: Vector3 = legalized_segment.get("tip_world", authored_tip_world) as Vector3
	var resolved_pommel_world: Vector3 = legalized_segment.get("pommel_world", authored_pommel_world) as Vector3
	var combined_volume_result: Dictionary = _project_preview_segment_local_to_valid_motion_volume(
		actor,
		held_item,
		trajectory_root,
		trajectory_root.to_local(resolved_tip_world),
		trajectory_root.to_local(resolved_pommel_world)
	)
	var combined_tip_position_local: Vector3 = _get_origin_tracked_vector3_state(
		combined_volume_result,
		"tip_position",
		"tip_position_origin_id",
		trajectory_root.to_local(resolved_tip_world),
		CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING
	)
	var combined_pommel_position_local: Vector3 = _get_origin_tracked_vector3_state(
		combined_volume_result,
		"pommel_position",
		"pommel_position_origin_id",
		trajectory_root.to_local(resolved_pommel_world),
		CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING
	)
	resolved_tip_world = trajectory_root.to_global(combined_tip_position_local)
	resolved_pommel_world = trajectory_root.to_global(combined_pommel_position_local)
	var solved_transform: Transform3D = _solve_weapon_segment_transform(
		held_item,
		trajectory_root,
		motion_node,
		local_tip,
		local_pommel,
		resolved_tip_world,
		resolved_pommel_world,
		resolved_weapon_orientation_degrees
	)
	solved_transform = _lock_preview_transform_to_dominant_grip_target(
		solved_transform,
		resolved_grip_local,
		_resolve_preview_primary_grip_target_world(actor, held_item),
		dominant_seat_lock_strength
	)
	solved_transform = _apply_preview_support_coupling(
		actor,
		held_item,
		motion_node,
		solved_transform,
		dominant_seat_lock_strength
	)
	var separation_result: Dictionary = _separate_preview_weapon_transform_from_body(actor, held_item, solved_transform)
	solved_transform = separation_result.get("transform", solved_transform) as Transform3D
	var final_collision_result: Dictionary = separation_result.get("collision_result", {}) as Dictionary
	var solved_tip_world: Vector3 = solved_transform * local_tip
	var solved_pommel_world: Vector3 = solved_transform * local_pommel
	return {
		"tip_position_local": trajectory_root.to_local(solved_tip_world),
		"tip_position_origin_id": CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING,
		"pommel_position_local": trajectory_root.to_local(solved_pommel_world),
		"pommel_position_origin_id": CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING,
		"solved_transform": solved_transform,
		"has_solved_transform": true,
		"legal": bool(separation_result.get("legal", true)),
		"collision_illegal_sample_count": int(final_collision_result.get("illegal_sample_count", 0)),
		"collision_region": String(final_collision_result.get("colliding_body_region", "")),
		"collision_sample": String(final_collision_result.get("colliding_sample_name", "")),
		"collision_clearance_meters": float(final_collision_result.get("estimated_clearance_meters", -1.0)),
	}

func _evaluate_preview_segment_legality(
	actor: Node3D,
	held_item: Node3D,
	solved_transform: Transform3D,
	motion_node: CombatAnimationMotionNode
) -> Dictionary:
	var torso_frame: Dictionary = _resolve_preview_torso_frame(actor)
	var default_primary_local: Vector3 = _get_preview_primary_grip_seat_meta(held_item) if held_item != null else Vector3.ZERO
	var default_primary_origin_id: StringName = (
		_resolve_origin_meta_value(
			held_item,
			PREVIEW_PRIMARY_GRIP_SEAT_ORIGIN_META,
			CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
		)
		if held_item != null
		else CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
	)
	var default_support_local: Vector3 = _get_preview_support_grip_seat_meta(held_item) if held_item != null else Vector3.ZERO
	var default_support_origin_id: StringName = (
		_resolve_origin_meta_value(
			held_item,
			PREVIEW_SUPPORT_GRIP_SEAT_ORIGIN_META,
			CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
		)
		if held_item != null
		else CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
	)
	var result := {
		"legal": true,
		"dominant_correction_delta": Vector3.ZERO,
		"support_correction_delta": Vector3.ZERO,
		"dominant_corrected_target": Vector3.ZERO,
		"dominant_resolved_grip_seat_local": default_primary_local,
		"dominant_resolved_grip_seat_origin_id": default_primary_origin_id,
		"support_resolved_grip_seat_local": default_support_local,
		"support_resolved_grip_seat_origin_id": default_support_origin_id,
		"weapon_body_illegal": false,
		"weapon_body_correction_delta": Vector3.ZERO,
		"weapon_body_region": "",
		"torso_frame": torso_frame,
	}
	if actor == null or held_item == null:
		return result
	var body_restriction_root: Node3D = actor.call("get_body_restriction_root") as Node3D if actor.has_method("get_body_restriction_root") else null
	var skeleton: Skeleton3D = actor.get_node_or_null(PREVIEW_SKELETON_PATH) as Skeleton3D
	if body_restriction_root != null and skeleton != null:
		hand_target_constraint_solver.sync_body_restriction_root(body_restriction_root, skeleton)
	var dominant_slot_id: StringName = _resolve_preview_dominant_slot_id()
	var support_slot_id: StringName = _resolve_preview_support_slot_id()
	var dominant_anchor: Node3D = weapon_grip_anchor_provider.get_primary_grip_anchor(held_item)
	var dominant_legality: Dictionary = _evaluate_preview_slot_legality(
		actor,
		held_item,
		body_restriction_root,
		solved_transform,
		dominant_anchor,
		dominant_slot_id,
		torso_frame,
		motion_node
	)
	result["dominant_correction_delta"] = dominant_legality.get("correction_delta", Vector3.ZERO)
	result["dominant_corrected_target"] = dominant_legality.get("corrected_target", Vector3.ZERO)
	var dominant_resolved_anchor_origin_id: StringName = _resolve_origin_tracked_state_origin_id(
		dominant_legality,
		"resolved_anchor_position_origin_id",
		default_primary_origin_id
	)
	result["dominant_resolved_grip_seat_local"] = _get_origin_tracked_vector3_state(
		dominant_legality,
		"resolved_anchor_local_position",
		"resolved_anchor_position_origin_id",
		_get_origin_tracked_vector3_state(
			result,
			"dominant_resolved_grip_seat_local",
			"dominant_resolved_grip_seat_origin_id",
			default_primary_local,
			default_primary_origin_id
		),
		dominant_resolved_anchor_origin_id
	)
	result["dominant_resolved_grip_seat_origin_id"] = dominant_resolved_anchor_origin_id
	if not bool(dominant_legality.get("legal", true)):
		result["legal"] = false
	if _should_preview_use_support_hand(held_item, motion_node):
		var support_anchor: Node3D = weapon_grip_anchor_provider.get_support_grip_anchor(held_item)
		var support_legality: Dictionary = _evaluate_preview_slot_legality(
			actor,
			held_item,
			body_restriction_root,
			solved_transform,
			support_anchor,
			support_slot_id,
			torso_frame,
			motion_node
		)
		result["support_correction_delta"] = support_legality.get("correction_delta", Vector3.ZERO)
		var support_resolved_anchor_origin_id: StringName = _resolve_origin_tracked_state_origin_id(
			support_legality,
			"resolved_anchor_position_origin_id",
			default_support_origin_id
		)
		result["support_resolved_grip_seat_local"] = _get_origin_tracked_vector3_state(
			support_legality,
			"resolved_anchor_local_position",
			"resolved_anchor_position_origin_id",
			_get_origin_tracked_vector3_state(
				result,
				"support_resolved_grip_seat_local",
				"support_resolved_grip_seat_origin_id",
				default_support_local,
				default_support_origin_id
			),
			support_resolved_anchor_origin_id
		)
		result["support_resolved_grip_seat_origin_id"] = support_resolved_anchor_origin_id
		if not bool(support_legality.get("legal", true)):
			result["legal"] = false
	var weapon_body_legality: Dictionary = collision_legality_resolver.evaluate_weapon_pose(
		body_restriction_root,
		held_item,
		solved_transform,
		hand_target_constraint_solver
	)
	if not bool(weapon_body_legality.get("legal", true)):
		result["weapon_body_illegal"] = true
		result["weapon_body_correction_delta"] = weapon_body_legality.get("suggested_correction_world", Vector3.ZERO)
		result["weapon_body_region"] = String(weapon_body_legality.get("colliding_body_region", ""))
		result["legal"] = false
	_set_origin_tracked_vector3_meta(
		held_item,
		PREVIEW_PRIMARY_GRIP_SEAT_LOCAL_META,
		PREVIEW_PRIMARY_GRIP_SEAT_ORIGIN_META,
		_get_origin_tracked_vector3_state(
			result,
			"dominant_resolved_grip_seat_local",
			"dominant_resolved_grip_seat_origin_id",
			default_primary_local,
			default_primary_origin_id
		),
		_resolve_origin_tracked_state_origin_id(
			result,
			"dominant_resolved_grip_seat_origin_id",
			default_primary_origin_id
		)
	)
	_set_origin_tracked_vector3_meta(
		held_item,
		PREVIEW_SUPPORT_GRIP_SEAT_LOCAL_META,
		PREVIEW_SUPPORT_GRIP_SEAT_ORIGIN_META,
		_get_origin_tracked_vector3_state(
			result,
			"support_resolved_grip_seat_local",
			"support_resolved_grip_seat_origin_id",
			default_support_local,
			default_support_origin_id
		),
		_resolve_origin_tracked_state_origin_id(
			result,
			"support_resolved_grip_seat_origin_id",
			default_support_origin_id
		)
	)
	return result

func _evaluate_preview_slot_legality(
	actor: Node3D,
	held_item: Node3D,
	body_restriction_root: Node3D,
	solved_transform: Transform3D,
	grip_anchor: Node3D,
	slot_id: StringName,
	torso_frame: Dictionary,
	motion_node: CombatAnimationMotionNode
) -> Dictionary:
	var resolved_anchor_local_position: Vector3 = grip_anchor.position if grip_anchor != null else Vector3.ZERO
	var result := {
		"legal": true,
		"desired_target": Vector3.ZERO,
		"corrected_target": Vector3.ZERO,
		"correction_delta": Vector3.ZERO,
		"resolved_anchor_local_position": resolved_anchor_local_position,
		"resolved_anchor_position_origin_id": CombatOriginRecordScript.ORIGIN_WEAPON_ROOT,
	}
	if actor == null or grip_anchor == null:
		return result
	var desired_target: Vector3 = (solved_transform * grip_anchor.transform).origin
	var corrected_target: Vector3 = desired_target
	var shoulder_world: Vector3 = _resolve_preview_shoulder_world(actor, slot_id)
	var query_exclusions: Array = _resolve_preview_slot_query_exclusions(body_restriction_root, slot_id)
	if body_restriction_root != null:
		var enforce_front_bias: bool = (
			slot_id != _resolve_preview_dominant_slot_id()
			or _should_preview_use_support_hand(held_item, motion_node)
		)
		var enforce_path_restriction: bool = enforce_front_bias
		var projection: Dictionary = hand_target_constraint_solver.project_target_to_legal_grip_space(
			body_restriction_root,
			shoulder_world,
			desired_target,
			torso_frame.get("origin_world", Vector3.ZERO),
			torso_frame.get("forward_world", character_frame_resolver.get_default_forward_world()),
			torso_frame.get("right_world", Vector3.RIGHT),
			torso_frame.get("up_world", Vector3.UP),
			{
				"allow_alternate_target_correction": false,
				"enforce_path_restriction": enforce_path_restriction,
				"enforce_front_bias": enforce_front_bias,
			},
			query_exclusions
		)
		corrected_target = projection.get("corrected_target", corrected_target) as Vector3
		if (
			bool(projection.get("path_illegal", false))
			or bool(projection.get("point_illegal", false))
			or bool(projection.get("front_bias_failed", false))
		):
			result["legal"] = false
		result["projection"] = projection
	corrected_target = _apply_preview_reach_limit(actor, slot_id, shoulder_world, corrected_target)
	if slot_id == _resolve_preview_dominant_slot_id():
		var grip_span_projection: Dictionary = _project_world_target_to_held_item_grip_span(
			held_item,
			solved_transform,
			corrected_target
		)
		if not grip_span_projection.is_empty():
			var projected_world: Vector3 = grip_span_projection.get("projected_world", corrected_target) as Vector3
			if _preview_world_grip_target_is_legal(actor, body_restriction_root, shoulder_world, projected_world, torso_frame):
				var current_anchor_local: Vector3 = _get_origin_tracked_vector3_state(
					result,
					"resolved_anchor_local_position",
					"resolved_anchor_position_origin_id",
					resolved_anchor_local_position,
					CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
				)
				var projected_local: Vector3 = _get_origin_tracked_vector3_state(
					grip_span_projection,
					"projected_local",
					"projected_origin_id",
					current_anchor_local,
					CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
				)
				result["legal"] = true
				result["corrected_target"] = projected_world
				result["correction_delta"] = Vector3.ZERO
				result["resolved_anchor_local_position"] = projected_local
				result["resolved_anchor_position_origin_id"] = CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
				result["used_grip_span_projection"] = true
				return result
	var correction_delta: Vector3 = corrected_target - desired_target
	if correction_delta.length() > SEGMENT_LEGALITY_EPSILON_METERS:
		result["legal"] = false
	result["desired_target"] = desired_target
	result["corrected_target"] = corrected_target
	result["correction_delta"] = correction_delta
	return result

func _build_preview_legalized_segment_world_positions(
	authored_tip_world: Vector3,
	authored_pommel_world: Vector3,
	legality: Dictionary
) -> Dictionary:
	var tip_world: Vector3 = authored_tip_world
	var pommel_world: Vector3 = authored_pommel_world
	var correction_delta: Vector3 = legality.get("dominant_correction_delta", Vector3.ZERO) as Vector3
	if correction_delta.length_squared() > 0.0000001:
		tip_world += correction_delta
		pommel_world += correction_delta
	elif bool(legality.get("weapon_body_illegal", false)):
		var push_offset: Vector3 = legality.get("weapon_body_correction_delta", Vector3.ZERO) as Vector3
		if push_offset.length_squared() <= 0.0000001:
			var torso_frame: Dictionary = legality.get("torso_frame", {}) as Dictionary
			var forward_world: Vector3 = torso_frame.get(
				"forward_world",
				character_frame_resolver.get_default_forward_world()
			) as Vector3
			if forward_world.length_squared() <= 0.000001:
				forward_world = character_frame_resolver.get_default_forward_world()
			push_offset = forward_world.normalized() * 0.08
		tip_world += push_offset
		pommel_world += push_offset
	return {
		"tip_world": tip_world,
		"pommel_world": pommel_world,
	}

func _apply_preview_support_coupling(
	actor: Node3D,
	held_item: Node3D,
	motion_node: CombatAnimationMotionNode,
	solved_transform: Transform3D,
	dominant_seat_lock_strength: float
) -> Transform3D:
	if actor == null or held_item == null or motion_node == null:
		return solved_transform
	if not _should_preview_use_support_hand(held_item, motion_node):
		return solved_transform
	var support_slot_id: StringName = _resolve_preview_support_slot_id()
	var support_target_world: Vector3 = _resolve_preview_hand_grip_target_world(actor, support_slot_id)
	if support_target_world.length_squared() <= 0.000001:
		return solved_transform
	var dominant_grip_local: Vector3 = _get_preview_primary_grip_seat_meta(held_item)
	var support_grip_local: Vector3 = _get_preview_support_grip_seat_meta(held_item)
	var support_coupling_strength: float = (
		AUTHORING_PREVIEW_SUPPORT_COUPLING_STRENGTH
		if dominant_seat_lock_strength >= 0.5
		else AUTHORING_DRAG_SUPPORT_COUPLING_STRENGTH
	)
	var max_angle: float = deg_to_rad(SUPPORT_COUPLING_MAX_ROTATION_DEGREES)
	var body_restriction_root: Node3D = (
		actor.call("get_body_restriction_root") as Node3D
		if actor.has_method("get_body_restriction_root")
		else null
	)
	var resolved_transform: Transform3D = solved_transform
	for _iteration: int in range(4):
		support_target_world = _resolve_preview_hand_grip_target_world(actor, support_slot_id)
		if support_target_world.length_squared() <= 0.000001:
			break
		var dominant_target_world: Vector3 = _resolve_preview_primary_grip_target_world(actor, held_item)
		if dominant_target_world.length_squared() <= 0.000001:
			dominant_target_world = resolved_transform * dominant_grip_local
		var dominant_grip_origin_id: StringName = _get_preview_primary_grip_seat_origin_id(held_item)
		var support_grip_origin_id: StringName = _get_preview_support_grip_seat_origin_id(held_item)
		support_grip_local = _resolve_preview_support_grip_seat_local_for_target(
			held_item,
			resolved_transform,
			dominant_grip_local,
			support_grip_local,
			support_target_world,
			dominant_target_world,
			dominant_grip_origin_id,
			support_grip_origin_id
		)
		support_grip_origin_id = _get_preview_support_grip_seat_origin_id(held_item)
		_set_origin_tracked_vector3_meta(
			held_item,
			PREVIEW_SUPPORT_GRIP_SEAT_LOCAL_META,
			PREVIEW_SUPPORT_GRIP_SEAT_ORIGIN_META,
			support_grip_local,
			support_grip_origin_id
		)
		var current_support_world: Vector3 = resolved_transform * support_grip_local
		var current_support_error: float = current_support_world.distance_to(support_target_world)
		if current_support_error <= SEGMENT_LEGALITY_EPSILON_METERS:
			break
		var current_vector: Vector3 = current_support_world - dominant_target_world
		var desired_vector: Vector3 = support_target_world - dominant_target_world
		if current_vector.length_squared() <= 0.000001 or desired_vector.length_squared() <= 0.000001:
			break
		var current_dir: Vector3 = current_vector.normalized()
		var desired_dir: Vector3 = desired_vector.normalized()
		var rotation_axis: Vector3 = current_dir.cross(desired_dir)
		if rotation_axis.length_squared() <= 0.000001:
			if current_dir.dot(desired_dir) >= 0.9999:
				break
			rotation_axis = current_dir.cross(actor.global_basis.y)
			if rotation_axis.length_squared() <= 0.000001:
				rotation_axis = current_dir.cross(Vector3.RIGHT)
			if rotation_axis.length_squared() <= 0.000001:
				break
		var desired_angle: float = current_dir.angle_to(desired_dir)
		var resolved_angle: float = minf(desired_angle * support_coupling_strength, max_angle)
		if resolved_angle <= 0.0001:
			break
		var rotation_basis: Basis = Basis(rotation_axis.normalized(), resolved_angle)
		var candidate_basis: Basis = (rotation_basis * resolved_transform.basis).orthonormalized()
		var candidate_transform := Transform3D(
			candidate_basis,
			dominant_target_world - candidate_basis * dominant_grip_local
		)
		var candidate_support_world: Vector3 = candidate_transform * support_grip_local
		var candidate_support_error: float = candidate_support_world.distance_to(support_target_world)
		if candidate_support_error >= current_support_error - 0.0001:
			break
		var base_weapon_body_illegal: bool = _preview_weapon_proxy_intersects_body(
			body_restriction_root,
			held_item,
			resolved_transform
		)
		var candidate_weapon_body_illegal: bool = _preview_weapon_proxy_intersects_body(
			body_restriction_root,
			held_item,
			candidate_transform
		)
		if candidate_weapon_body_illegal and not base_weapon_body_illegal:
			break
		resolved_transform = _apply_preview_two_hand_shared_contact_translation(
			actor,
			held_item,
			candidate_transform,
			dominant_grip_local,
			support_grip_local,
			dominant_grip_origin_id,
			support_grip_origin_id,
			dominant_target_world,
			support_target_world,
			dominant_seat_lock_strength
		)
	return resolved_transform

func _apply_preview_grip_contact_coupling(
	actor: Node3D,
	held_item: Node3D,
	motion_node: CombatAnimationMotionNode,
	solved_transform: Transform3D,
	authoring_mode: bool
) -> Dictionary:
	var result := {
		"transform": solved_transform,
		"metrics": {},
	}
	if actor == null or held_item == null:
		return result
	var dominant_grip_local: Vector3 = _get_preview_primary_grip_seat_meta(held_item)
	var dominant_grip_origin_id: StringName = _get_preview_primary_grip_seat_origin_id(held_item)
	var dominant_target_world: Vector3 = _resolve_preview_hand_grip_target_world(actor, _resolve_preview_dominant_slot_id())
	if dominant_target_world.length_squared() <= 0.000001:
		return result
	var use_support: bool = _should_preview_use_support_hand(held_item, motion_node)
	var support_grip_local: Vector3 = _get_preview_support_grip_seat_meta(held_item)
	var support_grip_origin_id: StringName = _get_preview_support_grip_seat_origin_id(held_item)
	var support_target_world: Vector3 = Vector3.ZERO
	if use_support:
		support_target_world = _resolve_preview_hand_grip_target_world(actor, _resolve_preview_support_slot_id())
		if support_target_world.length_squared() <= 0.000001:
			use_support = false
	var translation_strength: float = AUTHORING_CONTACT_TRANSLATION_STRENGTH if authoring_mode else PLAYBACK_CONTACT_TRANSLATION_STRENGTH
	var rotation_strength: float = AUTHORING_CONTACT_ROTATION_STRENGTH if authoring_mode else PLAYBACK_CONTACT_ROTATION_STRENGTH
	var max_translation: float = AUTHORING_CONTACT_MAX_TRANSLATION_METERS if authoring_mode else PLAYBACK_CONTACT_MAX_TRANSLATION_METERS
	var max_rotation: float = deg_to_rad(AUTHORING_CONTACT_MAX_ROTATION_DEGREES if authoring_mode else PLAYBACK_CONTACT_MAX_ROTATION_DEGREES)
	var coupled_transform: Transform3D = _solve_preview_grip_contact_transform(
		actor,
		held_item,
		solved_transform,
		dominant_grip_local,
		support_grip_local,
		dominant_grip_origin_id,
		support_grip_origin_id,
		dominant_target_world,
		support_target_world,
		use_support,
		translation_strength,
		rotation_strength,
		max_translation,
		max_rotation
	)
	var metrics: Dictionary = _build_preview_grip_contact_metrics(
		solved_transform,
		coupled_transform,
		dominant_grip_local,
		support_grip_local,
		dominant_grip_origin_id,
		support_grip_origin_id,
		dominant_target_world,
		support_target_world,
		use_support
	)
	result["transform"] = coupled_transform
	result["metrics"] = metrics
	return result

func _resolve_contact_tethered_transform(
	actor: Node3D,
	held_item: Node3D,
	motion_node: CombatAnimationMotionNode,
	candidate_transform: Transform3D,
	tether_mode: StringName,
	local_tip: Vector3,
	_local_pommel: Vector3,
	requested_tip_world: Vector3,
	requested_tip_lock_local: Vector3,
	requested_tip_lock_origin_id: StringName,
	trajectory_root: Node3D,
	occupied_primary_target_world: Vector3 = Vector3.INF,
	occupied_primary_target_lock_local: Vector3 = Vector3.INF,
	occupied_primary_target_lock_origin_id: StringName = CombatOriginRecordScript.ORIGIN_RL_BONE_ROOT,
	occupied_primary_wrist_world: Vector3 = Vector3.INF,
	occupied_primary_wrist_lock_local: Vector3 = Vector3.INF,
	occupied_primary_wrist_lock_origin_id: StringName = CombatOriginRecordScript.ORIGIN_RL_BONE_ROOT,
	body_lock_frame: Transform3D = Transform3D.IDENTITY,
	body_lock_origin_id: StringName = CombatOriginRecordScript.ORIGIN_RL_BONE_ROOT,
	occupied_weapon_transform: Transform3D = Transform3D.IDENTITY
) -> Dictionary:
	var metrics := {
		"clamped": false,
		"mode": String(tether_mode),
		"pivot_mode": "",
		"body_lock_origin_id": body_lock_origin_id,
		"requested_tip_lock_origin_id": requested_tip_lock_origin_id,
		"occupied_primary_target_lock_origin_id": occupied_primary_target_lock_origin_id,
		"occupied_primary_wrist_lock_origin_id": occupied_primary_wrist_lock_origin_id,
		"dominant_reach_before_meters": -1.0,
		"dominant_reach_after_meters": -1.0,
		"dominant_reach_limit_meters": -1.0,
		"support_reach_before_meters": -1.0,
		"support_reach_after_meters": -1.0,
		"support_reach_limit_meters": -1.0,
		"translation_delta_meters": 0.0,
		"pivot_delta_meters": 0.0,
		"dominant_seat_error_before_meters": -1.0,
		"dominant_seat_error_after_meters": -1.0,
		"dominant_seat_lock_delta_meters": 0.0,
		"tip_pivot_primary_seat_error_meters": -1.0,
		"tip_pivot_wrist_lock_error_after_meters": -1.0,
		"tip_pivot_trigger": "",
		"reference_space": String(PREVIEW_ROOT_BONE),
		"used_support": false,
	}
	if actor == null or held_item == null:
		return {
			"transform": candidate_transform,
			"metrics": metrics,
		}
	var dominant_slot_id: StringName = _resolve_preview_dominant_slot_id()
	var support_slot_id: StringName = _resolve_preview_support_slot_id()
	var dominant_local: Vector3 = _get_preview_primary_grip_seat_meta(held_item)
	var dominant_origin_id: StringName = _get_preview_primary_grip_seat_origin_id(held_item)
	metrics["dominant_grip_origin_id"] = dominant_origin_id
	var contact_slots: Array[Dictionary] = [
		{
			"slot_id": dominant_slot_id,
			"local_position": dominant_local,
			"local_position_origin_id": dominant_origin_id,
			"weight": 1.0,
			"prefix": "dominant",
		},
	]
	if _should_preview_use_support_hand(held_item, motion_node):
		var support_local: Vector3 = _get_preview_support_grip_seat_meta(held_item)
		var support_origin_id: StringName = _get_preview_support_grip_seat_origin_id(held_item)
		var support_target_world: Vector3 = _resolve_preview_hand_grip_target_world(actor, support_slot_id)
		var dominant_support_target_world: Vector3 = _resolve_preview_hand_grip_target_world(actor, dominant_slot_id)
		if support_target_world.length_squared() > 0.000001:
			support_local = _resolve_preview_support_grip_seat_local_for_target(
				held_item,
				candidate_transform,
				dominant_local,
				support_local,
				support_target_world,
				dominant_support_target_world,
				dominant_origin_id,
				support_origin_id
			)
			support_origin_id = _get_preview_support_grip_seat_origin_id(held_item)
			_set_origin_tracked_vector3_meta(
				held_item,
				PREVIEW_SUPPORT_GRIP_SEAT_LOCAL_META,
				PREVIEW_SUPPORT_GRIP_SEAT_ORIGIN_META,
				support_local,
				support_origin_id
			)
		contact_slots.append({
			"slot_id": support_slot_id,
			"local_position": support_local,
			"local_position_origin_id": support_origin_id,
			"weight": 1.0,
			"prefix": "support",
		})
		metrics["support_grip_origin_id"] = support_origin_id
		metrics["used_support"] = true
	var resolved_transform: Transform3D = candidate_transform
	_record_contact_tether_reach_metrics(actor, contact_slots, candidate_transform, metrics, "before")
	var tip_pivot_uses_contact_anchor: bool = false
	if tether_mode == AUTHORING_CONTACT_TETHER_MODE_TIP_PIVOT:
		metrics["pivot_mode"] = "pommel"
		var pivot_result: Dictionary = _resolve_tip_contact_pivot_tether_transform(
			actor,
			held_item,
			motion_node,
			candidate_transform,
			local_tip,
			CombatOriginRecordScript.ORIGIN_WEAPON_ROOT,
			dominant_local,
			dominant_origin_id,
			requested_tip_world,
			requested_tip_lock_local,
			requested_tip_lock_origin_id,
			trajectory_root,
			occupied_primary_target_world,
			occupied_primary_target_lock_local,
			occupied_primary_target_lock_origin_id,
			occupied_primary_wrist_world,
			occupied_primary_wrist_lock_local,
			occupied_primary_wrist_lock_origin_id,
			body_lock_frame,
			body_lock_origin_id,
			occupied_weapon_transform,
			metrics
		)
		if not pivot_result.is_empty():
			resolved_transform = pivot_result.get("transform", resolved_transform) as Transform3D
			tip_pivot_uses_contact_anchor = true
	var tip_pivot_uses_wrist_lock: bool = String(metrics.get("pivot_mode", "")) == "dominant_wrist"
	if tether_mode != AUTHORING_CONTACT_TETHER_MODE_TIP_PIVOT or (tip_pivot_uses_contact_anchor and not tip_pivot_uses_wrist_lock):
		resolved_transform = _translate_contact_tether_transform_to_reach(actor, contact_slots, resolved_transform, metrics)
	var dominant_target_world: Vector3 = (
		(body_lock_frame * occupied_primary_target_lock_local)
		if tether_mode == AUTHORING_CONTACT_TETHER_MODE_TIP_PIVOT and occupied_primary_target_lock_local != Vector3.INF
		else _resolve_preview_primary_grip_target_world(actor, held_item)
	)
	if (
		dominant_target_world.length_squared() > 0.000001
		and (tether_mode != AUTHORING_CONTACT_TETHER_MODE_TIP_PIVOT or (tip_pivot_uses_contact_anchor and not tip_pivot_uses_wrist_lock))
	):
		var seat_error_before: float = (resolved_transform * dominant_local).distance_to(dominant_target_world)
		resolved_transform = _lock_preview_transform_to_dominant_grip_target(
			resolved_transform,
			dominant_local,
			dominant_target_world,
			AUTHORING_CONTACT_SEAT_LOCK_STRENGTH
		)
		var seat_error_after: float = (resolved_transform * dominant_local).distance_to(dominant_target_world)
		metrics["dominant_seat_error_before_meters"] = seat_error_before
		metrics["dominant_seat_error_after_meters"] = seat_error_after
		metrics["dominant_seat_lock_delta_meters"] = maxf(seat_error_before - seat_error_after, 0.0)
		if seat_error_after < seat_error_before - SEGMENT_LEGALITY_EPSILON_METERS:
			metrics["clamped"] = true
	_record_contact_tether_reach_metrics(actor, contact_slots, resolved_transform, metrics, "after")
	metrics["translation_delta_meters"] = candidate_transform.origin.distance_to(resolved_transform.origin)
	return {
		"transform": resolved_transform,
		"metrics": metrics,
	}

func _resolve_tip_contact_pivot_tether_transform(
	actor: Node3D,
	held_item: Node3D,
	motion_node: CombatAnimationMotionNode,
	candidate_transform: Transform3D,
	local_tip: Vector3,
	local_tip_origin_id: StringName,
	dominant_local: Vector3,
	dominant_local_origin_id: StringName,
	_requested_tip_world: Vector3,
	requested_tip_lock_local: Vector3,
	requested_tip_lock_origin_id: StringName,
	trajectory_root: Node3D,
	occupied_primary_target_world: Vector3,
	occupied_primary_target_lock_local: Vector3,
	occupied_primary_target_lock_origin_id: StringName,
	occupied_primary_wrist_world: Vector3,
	occupied_primary_wrist_lock_local: Vector3,
	occupied_primary_wrist_lock_origin_id: StringName,
	body_lock_frame: Transform3D,
	body_lock_origin_id: StringName,
	occupied_weapon_transform: Transform3D,
	metrics: Dictionary
) -> Dictionary:
	if actor == null or held_item == null or motion_node == null or trajectory_root == null:
		return {}
	if local_tip.is_equal_approx(dominant_local):
		return {}
	var resolved_local_tip_origin_id: StringName = _normalize_combat_origin_id(
		local_tip_origin_id,
		CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
	)
	var resolved_dominant_local_origin_id: StringName = _normalize_combat_origin_id(
		dominant_local_origin_id,
		CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
	)
	metrics["local_tip_origin_id"] = resolved_local_tip_origin_id
	metrics["dominant_local_origin_id"] = resolved_dominant_local_origin_id
	var dominant_slot_id: StringName = _resolve_preview_dominant_slot_id()
	var shoulder_world: Vector3 = _resolve_preview_shoulder_world(actor, dominant_slot_id)
	var shoulder_lock_local: Vector3 = body_lock_frame.affine_inverse() * shoulder_world
	var shoulder_lock_origin_id: StringName = body_lock_origin_id
	var max_reach: float = _resolve_preview_actor_max_reach_meters(actor, dominant_slot_id)
	if max_reach <= 0.00001:
		return {}
	var candidate_grip_world: Vector3 = candidate_transform * dominant_local
	var candidate_grip_lock_local: Vector3 = body_lock_frame.affine_inverse() * candidate_grip_world
	var candidate_grip_lock_origin_id: StringName = body_lock_origin_id
	var primary_target_world: Vector3 = occupied_primary_target_world
	var primary_target_lock_local: Vector3 = occupied_primary_target_lock_local
	var primary_target_lock_origin_id: StringName = occupied_primary_target_lock_origin_id
	if occupied_primary_target_lock_local != Vector3.INF:
		primary_target_world = body_lock_frame * occupied_primary_target_lock_local
	if primary_target_world == Vector3.INF or primary_target_world.length_squared() <= 0.000001:
		primary_target_world = _resolve_preview_primary_grip_target_world(actor, held_item)
		primary_target_lock_local = body_lock_frame.affine_inverse() * primary_target_world
		primary_target_lock_origin_id = body_lock_origin_id
	var primary_seat_error: float = (
		candidate_grip_lock_local.distance_to(primary_target_lock_local)
		if primary_target_lock_local != Vector3.INF
		else -1.0
	)
	metrics["tip_pivot_primary_seat_error_meters"] = primary_seat_error
	metrics["tip_pivot_reference_space"] = String(PREVIEW_ROOT_BONE)
	metrics["shoulder_lock_origin_id"] = shoulder_lock_origin_id
	metrics["candidate_grip_lock_origin_id"] = candidate_grip_lock_origin_id
	metrics["primary_target_lock_origin_id"] = primary_target_lock_origin_id
	var shoulder_to_candidate_lock_local: Vector3 = candidate_grip_lock_local - shoulder_lock_local
	var shoulder_to_candidate_lock_origin_id: StringName = body_lock_origin_id
	var exceeds_reach: bool = shoulder_to_candidate_lock_local.length() > max_reach + AUTHORING_CONTACT_TETHER_REACH_MARGIN_METERS
	var exceeds_seat: bool = primary_seat_error >= 0.0 and primary_seat_error > AUTHORING_CONTACT_TETHER_SEAT_MARGIN_METERS
	if not exceeds_reach and not exceeds_seat:
		return {}
	metrics["tip_pivot_trigger"] = "reach_and_contact" if exceeds_reach and exceeds_seat else ("reach" if exceeds_reach else "contact")
	var pivot_world: Vector3 = occupied_primary_wrist_world
	var pivot_lock_local: Vector3 = occupied_primary_wrist_lock_local
	var pivot_lock_origin_id: StringName = occupied_primary_wrist_lock_origin_id
	if occupied_primary_wrist_lock_local != Vector3.INF:
		pivot_world = body_lock_frame * occupied_primary_wrist_lock_local
	var pivot_mode: String = "dominant_wrist"
	var pivot_local: Vector3 = occupied_weapon_transform.affine_inverse() * pivot_world
	if pivot_world == Vector3.INF or pivot_world.length_squared() <= 0.000001 or pivot_local.is_equal_approx(local_tip):
		pivot_lock_local = primary_target_lock_local
		pivot_lock_origin_id = primary_target_lock_origin_id
		pivot_world = body_lock_frame * pivot_lock_local
		pivot_mode = "dominant_contact"
		pivot_local = dominant_local
	if pivot_world.length_squared() <= 0.000001:
		pivot_lock_local = shoulder_lock_local + shoulder_to_candidate_lock_local.normalized() * max_reach
		pivot_lock_origin_id = body_lock_origin_id
		pivot_world = body_lock_frame * pivot_lock_local
	var shoulder_to_pivot_lock_local: Vector3 = pivot_lock_local - shoulder_lock_local
	var shoulder_to_pivot_lock_origin_id: StringName = body_lock_origin_id
	if shoulder_to_pivot_lock_local.length() > max_reach:
		pivot_lock_local = shoulder_lock_local + shoulder_to_pivot_lock_local.normalized() * max_reach
		pivot_lock_origin_id = body_lock_origin_id
		pivot_world = body_lock_frame * pivot_lock_local
	var requested_axis_lock_local: Vector3 = requested_tip_lock_local - pivot_lock_local
	var requested_axis_lock_origin_id: StringName = body_lock_origin_id
	if requested_axis_lock_local.length_squared() <= 0.000001:
		requested_axis_lock_local = body_lock_frame.affine_inverse() * (candidate_transform * local_tip) - pivot_lock_local
		requested_axis_lock_origin_id = body_lock_origin_id
	if requested_axis_lock_local.length_squared() <= 0.000001:
		return {}
	var tip_pivot_distance: float = local_tip.distance_to(pivot_local)
	if tip_pivot_distance <= 0.000001:
		return {}
	var pivoted_tip_lock_local: Vector3 = pivot_lock_local + requested_axis_lock_local.normalized() * tip_pivot_distance
	var pivoted_tip_lock_origin_id: StringName = body_lock_origin_id
	var pivoted_tip_world: Vector3 = body_lock_frame * pivoted_tip_lock_local
	var pivoted_transform: Transform3D = _solve_weapon_transform_from_tip_and_grip(
		held_item,
		trajectory_root,
		motion_node,
		local_tip,
		pivot_local,
		pivoted_tip_world,
		pivot_world,
		_resolve_motion_node_weapon_orientation_degrees(motion_node)
	)
	metrics["clamped"] = true
	metrics["pivot_mode"] = pivot_mode
	metrics["pivot_lock_origin_id"] = pivot_lock_origin_id
	metrics["shoulder_to_candidate_lock_origin_id"] = shoulder_to_candidate_lock_origin_id
	metrics["shoulder_to_pivot_lock_origin_id"] = shoulder_to_pivot_lock_origin_id
	metrics["requested_axis_lock_origin_id"] = requested_axis_lock_origin_id
	metrics["pivoted_tip_lock_origin_id"] = pivoted_tip_lock_origin_id
	metrics["requested_tip_lock_origin_id"] = requested_tip_lock_origin_id
	metrics["pivot_delta_meters"] = candidate_transform.origin.distance_to(pivoted_transform.origin)
	metrics["tip_pivot_wrist_lock_error_after_meters"] = (
		(pivoted_transform * pivot_local).distance_to(pivot_world)
		if pivot_mode == "dominant_wrist"
		else -1.0
	)
	return {
		"transform": pivoted_transform,
	}

func _translate_contact_tether_transform_to_reach(
	actor: Node3D,
	contact_slots: Array[Dictionary],
	source_transform: Transform3D,
	metrics: Dictionary
) -> Transform3D:
	var resolved_transform: Transform3D = source_transform
	if actor == null:
		return resolved_transform
	for _iteration: int in range(AUTHORING_CONTACT_TETHER_ITERATIONS):
		var weighted_delta := Vector3.ZERO
		var total_weight: float = 0.0
		for slot_data: Dictionary in contact_slots:
			var slot_id: StringName = slot_data.get("slot_id", _resolve_preview_dominant_slot_id())
			var local_position_origin_id: StringName = StringName(slot_data.get(
				"local_position_origin_id",
				CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
			))
			if local_position_origin_id == StringName():
				local_position_origin_id = CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
			var fallback_position_origin_id: StringName = local_position_origin_id
			var fallback_position_local: Vector3 = Vector3.ZERO
			slot_data["local_position_origin_id"] = fallback_position_origin_id
			var local_position: Vector3 = slot_data.get("local_position", fallback_position_local) as Vector3
			var shoulder_world: Vector3 = _resolve_preview_shoulder_world(actor, slot_id)
			var max_reach: float = _resolve_preview_actor_max_reach_meters(actor, slot_id)
			if max_reach <= 0.00001:
				continue
			var target_world: Vector3 = resolved_transform * local_position
			var shoulder_to_target: Vector3 = target_world - shoulder_world
			var reach_distance: float = shoulder_to_target.length()
			if reach_distance <= max_reach + AUTHORING_CONTACT_TETHER_REACH_MARGIN_METERS:
				continue
			var clamped_target: Vector3 = shoulder_world + shoulder_to_target.normalized() * max_reach
			var slot_weight: float = maxf(float(slot_data.get("weight", 1.0)), 0.0)
			weighted_delta += (clamped_target - target_world) * slot_weight
			total_weight += slot_weight
		if total_weight <= 0.000001:
			break
		var step_delta: Vector3 = weighted_delta / total_weight
		if step_delta.length_squared() <= 0.0000001:
			break
		resolved_transform = Transform3D(resolved_transform.basis, resolved_transform.origin + step_delta)
		metrics["clamped"] = true
	return resolved_transform

func _record_contact_tether_reach_metrics(
	actor: Node3D,
	contact_slots: Array[Dictionary],
	solved_transform: Transform3D,
	metrics: Dictionary,
	phase: String
) -> void:
	if actor == null:
		return
	for slot_data: Dictionary in contact_slots:
		var slot_id: StringName = slot_data.get("slot_id", _resolve_preview_dominant_slot_id())
		var prefix: String = String(slot_data.get("prefix", "dominant"))
		var local_position_origin_id: StringName = StringName(slot_data.get(
			"local_position_origin_id",
			CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
		))
		if local_position_origin_id == StringName():
			local_position_origin_id = CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
		var fallback_position_origin_id: StringName = local_position_origin_id
		var fallback_position_local: Vector3 = Vector3.ZERO
		var local_position: Vector3 = slot_data.get("local_position", fallback_position_local) as Vector3
		metrics["%s_local_origin_id" % prefix] = String(local_position_origin_id)
		metrics["%s_local_position_origin_id" % prefix] = String(fallback_position_origin_id)
		var shoulder_world: Vector3 = _resolve_preview_shoulder_world(actor, slot_id)
		var target_world: Vector3 = solved_transform * local_position
		metrics["%s_reach_%s_meters" % [prefix, phase]] = shoulder_world.distance_to(target_world)
		metrics["%s_reach_limit_meters" % prefix] = _resolve_preview_actor_max_reach_meters(actor, slot_id)

func _resolve_preview_actor_max_reach_meters(actor: Node3D, slot_id: StringName = StringName()) -> float:
	if actor == null:
		return 0.0
	if actor.has_method("get_usable_arm_chain_reach_meters"):
		return float(actor.call("get_usable_arm_chain_reach_meters", slot_id))
	return float(actor.call("get_max_model_arm_reach_combat_meters")) if actor.has_method("get_max_model_arm_reach_combat_meters") else 0.0

func build_trajectory_volume_config_for_actor(
	actor: Node3D,
	trajectory_root: Node3D,
	held_item: Node3D,
	slot_id: StringName,
	min_radius_meters: float = -1.0,
	max_radius_meters: float = -1.0
) -> Dictionary:
	if actor == null or trajectory_root == null or held_item == null:
		return {}
	var resolved_slot_id: StringName = _normalize_preview_slot_id(slot_id)
	var shoulder_world: Vector3 = _resolve_preview_shoulder_world(actor, resolved_slot_id)
	var max_radius: float = max_radius_meters
	if max_radius < 0.0:
		max_radius = _resolve_preview_actor_max_reach_meters(actor, resolved_slot_id)
	if max_radius <= 0.00001:
		return {}
	var min_radius: float = min_radius_meters
	if min_radius < 0.0:
		min_radius = max_radius * TRAJECTORY_VOLUME_MIN_REACH_RATIO_OF_MAX
	return trajectory_volume_resolver.make_shell_config(
		trajectory_root.to_local(shoulder_world),
		min_radius,
		max_radius,
		_resolve_held_item_grip_pivot_ratio_from_pommel(held_item),
		true
	)

func _project_preview_segment_local_to_valid_motion_volume(
	actor: Node3D,
	held_item: Node3D,
	trajectory_root: Node3D,
	tip_position_local: Vector3,
	pommel_position_local: Vector3
) -> Dictionary:
	var config: Dictionary = build_trajectory_volume_config_for_actor(
		actor,
		trajectory_root,
		held_item,
		_resolve_preview_dominant_slot_id()
	)
	if config.is_empty():
		return {
			"tip_position": tip_position_local,
			"tip_position_origin_id": CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING,
			"pommel_position": pommel_position_local,
			"pommel_position_origin_id": CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING,
			"clamped": false,
		}
	return trajectory_volume_resolver.project_segment_to_valid_volume(
		tip_position_local,
		pommel_position_local,
		config
	)

func _resolve_held_item_grip_pivot_ratio_from_pommel(held_item: Node3D) -> float:
	if held_item == null:
		return CombatAnimationTrajectoryVolumeResolverScript.DEFAULT_PIVOT_RATIO_FROM_POMMEL
	var local_tip: Vector3 = _get_weapon_tip_meta(held_item)
	var local_pommel: Vector3 = _get_weapon_pommel_meta(held_item)
	var grip_local: Vector3 = _get_preview_primary_grip_seat_meta(held_item)
	var axis: Vector3 = local_tip - local_pommel
	var axis_length_squared: float = axis.length_squared()
	if axis_length_squared <= 0.000001:
		return CombatAnimationTrajectoryVolumeResolverScript.DEFAULT_PIVOT_RATIO_FROM_POMMEL
	return clampf((grip_local - local_pommel).dot(axis) / axis_length_squared, 0.0, 1.0)

func _solve_preview_grip_contact_transform(
	actor: Node3D,
	held_item: Node3D,
	solved_transform: Transform3D,
	dominant_grip_local: Vector3,
	support_grip_local: Vector3,
	dominant_grip_origin_id: StringName,
	support_grip_origin_id: StringName,
	dominant_target_world: Vector3,
	support_target_world: Vector3,
	use_support: bool,
	translation_strength: float,
	rotation_strength: float,
	max_translation: float,
	max_rotation: float
) -> Transform3D:
	var resolved_transform: Transform3D = solved_transform
	var resolved_dominant_grip_origin_id: StringName = _normalize_combat_origin_id(
		dominant_grip_origin_id,
		CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
	)
	var resolved_support_grip_origin_id: StringName = _normalize_combat_origin_id(
		support_grip_origin_id,
		CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
	)
	if use_support:
		resolved_transform = _rotate_preview_weapon_toward_contact_pair(
			resolved_transform,
			dominant_grip_local,
			support_grip_local,
			resolved_dominant_grip_origin_id,
			resolved_support_grip_origin_id,
			dominant_target_world,
			support_target_world,
			rotation_strength,
			max_rotation
		)
	resolved_transform = _translate_preview_weapon_toward_contact_targets(
		resolved_transform,
		dominant_grip_local,
		support_grip_local,
		resolved_dominant_grip_origin_id,
		resolved_support_grip_origin_id,
		dominant_target_world,
		support_target_world,
		use_support,
		translation_strength,
		max_translation
	)
	if _preview_contact_candidate_introduces_body_intersection(actor, held_item, solved_transform, resolved_transform):
		return solved_transform
	return resolved_transform

func _rotate_preview_weapon_toward_contact_pair(
	solved_transform: Transform3D,
	dominant_grip_local: Vector3,
	support_grip_local: Vector3,
	dominant_grip_origin_id: StringName,
	support_grip_origin_id: StringName,
	dominant_target_world: Vector3,
	support_target_world: Vector3,
	rotation_strength: float,
	max_rotation: float
) -> Transform3D:
	var resolved_dominant_grip_origin_id: StringName = _normalize_combat_origin_id(
		dominant_grip_origin_id,
		CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
	)
	var resolved_support_grip_origin_id: StringName = _normalize_combat_origin_id(
		support_grip_origin_id,
		CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
	)
	if resolved_dominant_grip_origin_id == StringName() or resolved_support_grip_origin_id == StringName():
		return solved_transform
	var current_dominant_world: Vector3 = solved_transform * dominant_grip_local
	var current_support_world: Vector3 = solved_transform * support_grip_local
	var current_vector: Vector3 = current_support_world - current_dominant_world
	var desired_vector: Vector3 = support_target_world - dominant_target_world
	if current_vector.length_squared() <= 0.000001 or desired_vector.length_squared() <= 0.000001:
		return solved_transform
	var current_dir: Vector3 = current_vector.normalized()
	var desired_dir: Vector3 = desired_vector.normalized()
	var rotation_axis: Vector3 = current_dir.cross(desired_dir)
	if rotation_axis.length_squared() <= 0.000001:
		return solved_transform
	var desired_angle: float = current_dir.angle_to(desired_dir)
	var resolved_angle: float = minf(desired_angle * clampf(rotation_strength, 0.0, 1.0), max_rotation)
	if resolved_angle <= 0.0001:
		return solved_transform
	var rotation_basis := Basis(rotation_axis.normalized(), resolved_angle)
	var pivot_world: Vector3 = current_dominant_world.lerp(current_support_world, 0.5)
	var rotated_basis: Basis = (rotation_basis * solved_transform.basis).orthonormalized()
	var rotated_origin: Vector3 = pivot_world + rotation_basis * (solved_transform.origin - pivot_world)
	return Transform3D(rotated_basis, rotated_origin)

func _translate_preview_weapon_toward_contact_targets(
	solved_transform: Transform3D,
	dominant_grip_local: Vector3,
	support_grip_local: Vector3,
	dominant_grip_origin_id: StringName,
	support_grip_origin_id: StringName,
	dominant_target_world: Vector3,
	support_target_world: Vector3,
	use_support: bool,
	translation_strength: float,
	max_translation: float
) -> Transform3D:
	var resolved_dominant_grip_origin_id: StringName = _normalize_combat_origin_id(
		dominant_grip_origin_id,
		CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
	)
	var resolved_support_grip_origin_id: StringName = _normalize_combat_origin_id(
		support_grip_origin_id,
		CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
	)
	if resolved_dominant_grip_origin_id == StringName() or resolved_support_grip_origin_id == StringName():
		return solved_transform
	var dominant_world: Vector3 = solved_transform * dominant_grip_local
	var dominant_delta: Vector3 = dominant_target_world - dominant_world
	var weighted_delta: Vector3 = dominant_delta
	if use_support:
		var support_world: Vector3 = solved_transform * support_grip_local
		var support_delta: Vector3 = support_target_world - support_world
		weighted_delta = (dominant_delta * TWO_HAND_PREVIEW_DOMINANT_CONTACT_WEIGHT + support_delta * TWO_HAND_PREVIEW_SUPPORT_CONTACT_WEIGHT) / (
			TWO_HAND_PREVIEW_DOMINANT_CONTACT_WEIGHT + TWO_HAND_PREVIEW_SUPPORT_CONTACT_WEIGHT
		)
	weighted_delta *= clampf(translation_strength, 0.0, 1.0)
	var max_delta: float = maxf(max_translation, 0.0)
	if max_delta > 0.0 and weighted_delta.length() > max_delta:
		weighted_delta = weighted_delta.normalized() * max_delta
	if weighted_delta.length_squared() <= 0.0000001:
		return solved_transform
	return Transform3D(solved_transform.basis, solved_transform.origin + weighted_delta)

func _preview_contact_candidate_introduces_body_intersection(
	actor: Node3D,
	held_item: Node3D,
	base_transform: Transform3D,
	candidate_transform: Transform3D
) -> bool:
	var body_restriction_root: Node3D = (
		actor.call("get_body_restriction_root") as Node3D
		if actor != null and actor.has_method("get_body_restriction_root")
		else null
	)
	var base_illegal: bool = _preview_weapon_proxy_intersects_body(body_restriction_root, held_item, base_transform)
	var candidate_illegal: bool = _preview_weapon_proxy_intersects_body(body_restriction_root, held_item, candidate_transform)
	return candidate_illegal and not base_illegal

func _build_preview_grip_contact_metrics(
	before_transform: Transform3D,
	after_transform: Transform3D,
	dominant_grip_local: Vector3,
	support_grip_local: Vector3,
	dominant_grip_origin_id: StringName,
	support_grip_origin_id: StringName,
	dominant_target_world: Vector3,
	support_target_world: Vector3,
	use_support: bool
) -> Dictionary:
	var resolved_dominant_grip_origin_id: StringName = _normalize_combat_origin_id(
		dominant_grip_origin_id,
		CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
	)
	var resolved_support_grip_origin_id: StringName = _normalize_combat_origin_id(
		support_grip_origin_id,
		CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
	)
	var before_dominant_error: float = (before_transform * dominant_grip_local).distance_to(dominant_target_world)
	var after_dominant_error: float = (after_transform * dominant_grip_local).distance_to(dominant_target_world)
	var before_support_error: float = -1.0
	var after_support_error: float = -1.0
	if use_support:
		before_support_error = (before_transform * support_grip_local).distance_to(support_target_world)
		after_support_error = (after_transform * support_grip_local).distance_to(support_target_world)
	return {
		"dominant_error_before_meters": before_dominant_error,
		"dominant_error_after_meters": after_dominant_error,
		"support_error_before_meters": before_support_error,
		"support_error_after_meters": after_support_error,
		"translation_delta_meters": before_transform.origin.distance_to(after_transform.origin),
		"used_support": use_support,
		"dominant_grip_origin_id": resolved_dominant_grip_origin_id,
		"support_grip_origin_id": resolved_support_grip_origin_id,
	}

func _apply_preview_two_hand_shared_contact_translation(
	actor: Node3D,
	held_item: Node3D,
	solved_transform: Transform3D,
	dominant_grip_local: Vector3,
	support_grip_local: Vector3,
	dominant_grip_origin_id: StringName,
	support_grip_origin_id: StringName,
	dominant_target_world: Vector3,
	support_target_world: Vector3,
	dominant_seat_lock_strength: float
) -> Transform3D:
	if actor == null or held_item == null:
		return solved_transform
	var resolved_dominant_grip_origin_id: StringName = _normalize_combat_origin_id(
		dominant_grip_origin_id,
		CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
	)
	var resolved_support_grip_origin_id: StringName = _normalize_combat_origin_id(
		support_grip_origin_id,
		CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
	)
	if resolved_dominant_grip_origin_id == StringName() or resolved_support_grip_origin_id == StringName():
		return solved_transform
	if dominant_target_world.length_squared() <= 0.000001 or support_target_world.length_squared() <= 0.000001:
		return solved_transform
	var dominant_weight: float = (
		TWO_HAND_PREVIEW_DOMINANT_CONTACT_WEIGHT
		if dominant_seat_lock_strength >= 0.5
		else TWO_HAND_DRAG_DOMINANT_CONTACT_WEIGHT
	)
	var support_weight: float = (
		TWO_HAND_PREVIEW_SUPPORT_CONTACT_WEIGHT
		if dominant_seat_lock_strength >= 0.5
		else TWO_HAND_DRAG_SUPPORT_CONTACT_WEIGHT
	)
	var total_weight: float = dominant_weight + support_weight
	if total_weight <= 0.000001:
		return solved_transform
	var dominant_world: Vector3 = solved_transform * dominant_grip_local
	var support_world: Vector3 = solved_transform * support_grip_local
	var weighted_delta: Vector3 = (
		(dominant_target_world - dominant_world) * dominant_weight
		+ (support_target_world - support_world) * support_weight
	) / total_weight
	if weighted_delta.length_squared() <= 0.0000001:
		return solved_transform
	var candidate_transform := Transform3D(
		solved_transform.basis,
		solved_transform.origin + weighted_delta
	)
	var body_restriction_root: Node3D = (
		actor.call("get_body_restriction_root") as Node3D
		if actor.has_method("get_body_restriction_root")
		else null
	)
	var base_weapon_body_illegal: bool = _preview_weapon_proxy_intersects_body(
		body_restriction_root,
		held_item,
		solved_transform
	)
	var candidate_weapon_body_illegal: bool = _preview_weapon_proxy_intersects_body(
		body_restriction_root,
		held_item,
		candidate_transform
	)
	if candidate_weapon_body_illegal and not base_weapon_body_illegal:
		return solved_transform
	return candidate_transform

func _resolve_preview_support_grip_seat_local_for_target(
	held_item: Node3D,
	solved_transform: Transform3D,
	dominant_grip_local: Vector3,
	current_support_grip_local: Vector3,
	support_target_world: Vector3,
	dominant_target_world: Vector3,
	dominant_grip_origin_id: StringName = CombatOriginRecordScript.ORIGIN_WEAPON_ROOT,
	current_support_grip_origin_id: StringName = CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
) -> Vector3:
	if held_item == null:
		return current_support_grip_local
	var resolved_dominant_grip_origin_id: StringName = _normalize_combat_origin_id(
		dominant_grip_origin_id,
		CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
	)
	var current_support_grip_origin_id_fallback: StringName = _normalize_combat_origin_id(
		current_support_grip_origin_id,
		CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
	)
	var current_support_grip_fallback_state: Dictionary = {
		"current_support_grip_local": current_support_grip_local,
		"current_support_grip_origin_id": current_support_grip_origin_id_fallback,
	}
	if bool(held_item.get_meta(PREVIEW_SECONDARY_GRIP_SEAT_AUTHORED_META, false)):
		return current_support_grip_local
	if support_target_world.length_squared() <= 0.000001 or dominant_target_world.length_squared() <= 0.000001:
		return current_support_grip_local
	var projection: Dictionary = _project_world_target_to_held_item_grip_span(
		held_item,
		solved_transform,
		support_target_world
	)
	if projection.is_empty():
		return _get_origin_tracked_vector3_state(
			current_support_grip_fallback_state,
			"current_support_grip_local",
			"current_support_grip_origin_id",
			current_support_grip_local,
			current_support_grip_origin_id_fallback
		)
	var projected_origin_id: StringName = _resolve_origin_tracked_state_origin_id(
		projection,
		"projected_origin_id",
		CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
	)
	var span_start_origin_id: StringName = _resolve_origin_meta_value(
		held_item,
		"primary_grip_span_start_origin_id",
		CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
	)
	var span_start_local: Vector3 = _get_origin_tracked_vector3_meta(
		held_item,
		"primary_grip_span_start_local",
		"primary_grip_span_start_origin_id",
		current_support_grip_local,
		current_support_grip_origin_id_fallback
	)
	var span_end_origin_id: StringName = _resolve_origin_meta_value(
		held_item,
		"primary_grip_span_end_origin_id",
		CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
	)
	var span_end_local: Vector3 = _get_origin_tracked_vector3_meta(
		held_item,
		"primary_grip_span_end_local",
		"primary_grip_span_end_origin_id",
		current_support_grip_local,
		current_support_grip_origin_id_fallback
	)
	var projected_local: Vector3 = _get_origin_tracked_vector3_state(
		projection,
		"projected_local",
		"projected_origin_id",
		current_support_grip_local,
		current_support_grip_origin_id_fallback
	)
	var candidates: Array[Dictionary] = [
		{
			"candidate_local": current_support_grip_local,
			"candidate_origin_id": current_support_grip_origin_id_fallback,
		},
		{
			"candidate_local": projected_local,
			"candidate_origin_id": projected_origin_id,
		},
		{
			"candidate_local": span_start_local,
			"candidate_origin_id": span_start_origin_id,
		},
		{
			"candidate_local": span_end_local,
			"candidate_origin_id": span_end_origin_id,
		},
	]
	var desired_hand_distance: float = support_target_world.distance_to(dominant_target_world)
	var best_local: Vector3 = current_support_grip_local
	var best_origin_id: StringName = current_support_grip_origin_id_fallback
	var best_score: float = INF
	for candidate_state: Dictionary in candidates:
		var candidate_local: Vector3 = _get_origin_tracked_vector3_state(
			candidate_state,
			"candidate_local",
			"candidate_origin_id",
			current_support_grip_local,
			current_support_grip_origin_id_fallback
		)
		var candidate_origin_id: StringName = StringName(candidate_state.get(
			"candidate_origin_id",
			current_support_grip_origin_id_fallback
		))
		if candidate_origin_id == StringName():
			candidate_origin_id = current_support_grip_origin_id_fallback
		var candidate_world: Vector3 = solved_transform * candidate_local
		var target_error: float = candidate_world.distance_to(support_target_world)
		var seat_distance: float = candidate_local.distance_to(dominant_grip_local)
		var radial_error: float = absf(seat_distance - desired_hand_distance)
		var score: float = target_error + radial_error * 0.5
		if score < best_score:
			best_score = score
			best_local = candidate_local
			best_origin_id = candidate_origin_id
	held_item.set_meta(PREVIEW_SUPPORT_GRIP_SEAT_ORIGIN_META, best_origin_id)
	held_item.set_meta("preview_support_grip_seat_dominant_origin_id", resolved_dominant_grip_origin_id)
	return best_local

func _apply_preview_reach_limit(actor: Node3D, slot_id: StringName, shoulder_world: Vector3, target_world: Vector3) -> Vector3:
	if actor == null:
		return target_world
	var max_reach: float = _resolve_preview_actor_max_reach_meters(actor, slot_id)
	if max_reach <= 0.00001:
		return target_world
	var min_reach: float = max_reach * TRAJECTORY_VOLUME_MIN_REACH_RATIO_OF_MAX
	var projection: Dictionary = trajectory_volume_resolver.project_point_to_valid_volume(
		target_world,
		trajectory_volume_resolver.make_shell_config(
			shoulder_world,
			min_reach,
			max_reach,
			CombatAnimationTrajectoryVolumeResolverScript.DEFAULT_PIVOT_RATIO_FROM_POMMEL,
			true
		)
	)
	return projection.get("point_position", target_world) as Vector3

func _project_world_target_to_held_item_grip_span(
	held_item: Node3D,
	solved_transform: Transform3D,
	target_world: Vector3
) -> Dictionary:
	if held_item == null:
		return {}
	var span_start_origin_id: StringName = _resolve_origin_meta_value(
		held_item,
		"primary_grip_span_start_origin_id",
		CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
	)
	var span_start_local: Vector3 = _get_origin_tracked_vector3_meta(
		held_item,
		"primary_grip_span_start_local",
		"primary_grip_span_start_origin_id",
		Vector3.ZERO,
		CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
	)
	var span_end_origin_id: StringName = _resolve_origin_meta_value(
		held_item,
		"primary_grip_span_end_origin_id",
		CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
	)
	var span_end_local: Vector3 = _get_origin_tracked_vector3_meta(
		held_item,
		"primary_grip_span_end_local",
		"primary_grip_span_end_origin_id",
		Vector3.ZERO,
		CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
	)
	var span_vector_local: Vector3 = span_end_local - span_start_local
	var span_vector_origin_id: StringName = span_start_origin_id if span_start_origin_id == span_end_origin_id else CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
	if span_vector_local.length_squared() <= 0.000001:
		return {}
	var span_start_world: Vector3 = solved_transform * span_start_local
	var span_end_world: Vector3 = solved_transform * span_end_local
	var span_vector_world: Vector3 = span_end_world - span_start_world
	var span_length_squared: float = span_vector_world.length_squared()
	if span_length_squared <= 0.000001:
		return {}
	var ratio: float = clampf((target_world - span_start_world).dot(span_vector_world) / span_length_squared, 0.0, 1.0)
	var projected_local: Vector3 = span_start_local.lerp(span_end_local, ratio)
	return {
		"projected_ratio": ratio,
		"projected_local": projected_local,
		"projected_origin_id": CombatOriginRecordScript.ORIGIN_WEAPON_ROOT,
		"projected_world": solved_transform * projected_local,
		"span_start_origin_id": span_start_origin_id,
		"span_end_origin_id": span_end_origin_id,
		"span_vector_origin_id": span_vector_origin_id,
	}

func _preview_world_grip_target_is_legal(
	actor: Node3D,
	body_restriction_root: Node3D,
	shoulder_world: Vector3,
	target_world: Vector3,
	torso_frame: Dictionary
) -> bool:
	var reach_limited_target: Vector3 = _apply_preview_reach_limit(actor, _resolve_preview_dominant_slot_id(), shoulder_world, target_world)
	if reach_limited_target.distance_to(target_world) > SEGMENT_LEGALITY_EPSILON_METERS:
		return false
	if body_restriction_root == null:
		return true
	var query_exclusions: Array = _resolve_preview_slot_query_exclusions(
		body_restriction_root,
		_resolve_preview_dominant_slot_id()
	)
	var projection: Dictionary = hand_target_constraint_solver.project_target_to_legal_grip_space(
		body_restriction_root,
		shoulder_world,
		target_world,
		torso_frame.get("origin_world", Vector3.ZERO),
		torso_frame.get("forward_world", character_frame_resolver.get_default_forward_world()),
		torso_frame.get("right_world", Vector3.RIGHT),
		torso_frame.get("up_world", Vector3.UP),
		{},
		query_exclusions
	)
	var corrected_target: Vector3 = projection.get("corrected_target", target_world) as Vector3
	return corrected_target.distance_to(target_world) <= SEGMENT_LEGALITY_EPSILON_METERS

func _resolve_preview_slot_query_exclusions(body_restriction_root: Node3D, slot_id: StringName) -> Array:
	if hand_target_constraint_solver == null or not hand_target_constraint_solver.has_method("build_arm_self_query_exclusions"):
		return []
	var exclusion_variant: Variant = hand_target_constraint_solver.call(
		"build_arm_self_query_exclusions",
		body_restriction_root,
		slot_id
	)
	return exclusion_variant as Array if exclusion_variant is Array else []

func _resolve_preview_primary_grip_target_world(actor: Node3D, held_item: Node3D) -> Vector3:
	var grip_target_world: Vector3 = _resolve_preview_hand_grip_target_world(actor, _resolve_preview_dominant_slot_id())
	if grip_target_world.length_squared() > 0.000001:
		return grip_target_world
	var hand_anchor: Node3D = _resolve_preview_mount_anchor(actor)
	if hand_anchor != null and is_instance_valid(hand_anchor):
		return hand_anchor.global_position
	var primary_anchor: Node3D = weapon_grip_anchor_provider.get_primary_grip_anchor(held_item)
	return primary_anchor.global_position if primary_anchor != null else Vector3.ZERO

func _resolve_preview_primary_wrist_world(actor: Node3D) -> Vector3:
	return _resolve_preview_slot_wrist_world(actor, _resolve_preview_dominant_slot_id())

func _resolve_preview_slot_wrist_world(actor: Node3D, slot_id: StringName) -> Vector3:
	if actor == null:
		return Vector3.ZERO
	var skeleton: Skeleton3D = actor.get_node_or_null(PREVIEW_SKELETON_PATH) as Skeleton3D
	var hand_bone: StringName = PREVIEW_LEFT_HAND_BONE if slot_id == &"hand_left" else PREVIEW_RIGHT_HAND_BONE
	var wrist_world: Vector3 = _get_skeleton_bone_world_position(skeleton, hand_bone)
	if wrist_world.length_squared() > 0.000001:
		return wrist_world
	var anchor_method_name: StringName = &"get_left_hand_item_anchor" if slot_id == &"hand_left" else &"get_right_hand_item_anchor"
	if actor.has_method(anchor_method_name):
		var hand_anchor: Node3D = actor.call(anchor_method_name) as Node3D
		if hand_anchor != null and is_instance_valid(hand_anchor):
			return hand_anchor.global_position
	return Vector3.ZERO

func _lock_preview_transform_to_dominant_grip_target(
	solved_transform: Transform3D,
	resolved_grip_local: Vector3,
	dominant_target_world: Vector3,
	seat_lock_strength: float = 1.0
) -> Transform3D:
	if dominant_target_world.length_squared() <= 0.000001:
		return solved_transform
	var current_grip_world: Vector3 = solved_transform * resolved_grip_local
	var correction_delta: Vector3 = dominant_target_world - current_grip_world
	if correction_delta.length_squared() <= 0.0000001:
		return solved_transform
	var resolved_strength: float = clampf(seat_lock_strength, 0.0, 1.0)
	if resolved_strength <= 0.00001:
		return solved_transform
	return Transform3D(
		solved_transform.basis,
		solved_transform.origin + (correction_delta * resolved_strength)
	)

func _resolve_preview_grip_alignment_error(actor: Node3D, held_item: Node3D, slot_id: StringName) -> float:
	if actor == null or held_item == null or not is_instance_valid(held_item):
		return -1.0
	var target_world: Vector3 = _resolve_preview_hand_grip_target_world(actor, slot_id)
	if target_world.length_squared() <= 0.000001:
		return -1.0
	var grip_anchor: Node3D = (
		weapon_grip_anchor_provider.get_primary_grip_anchor(held_item)
		if slot_id == _resolve_preview_dominant_slot_id()
		else weapon_grip_anchor_provider.get_support_grip_anchor(held_item)
	)
	if grip_anchor == null or not is_instance_valid(grip_anchor):
		return -1.0
	return target_world.distance_to(grip_anchor.global_position)

func _resolve_preview_grip_anchor_world(held_item: Node3D, slot_id: StringName) -> Vector3:
	if held_item == null or not is_instance_valid(held_item):
		return Vector3.ZERO
	var grip_anchor: Node3D = (
		weapon_grip_anchor_provider.get_primary_grip_anchor(held_item)
		if slot_id == _resolve_preview_dominant_slot_id()
		else weapon_grip_anchor_provider.get_support_grip_anchor(held_item)
	)
	return grip_anchor.global_position if grip_anchor != null and is_instance_valid(grip_anchor) else Vector3.ZERO

func _resolve_preview_finger_contact_readiness(held_item: Node3D, slot_id: StringName) -> float:
	return _resolve_preview_finger_contact_meta(
		held_item,
		slot_id,
		"finger_grip_contact_readiness",
		-1.0
	)

func _resolve_preview_finger_contact_distance(held_item: Node3D, slot_id: StringName) -> float:
	return _resolve_preview_finger_contact_meta(
		held_item,
		slot_id,
		"finger_grip_contact_distance_meters",
		-1.0
	)

func _resolve_preview_finger_contact_ray_debug(held_item: Node3D, slot_id: StringName) -> Array:
	var guide_node: Node3D = _resolve_preview_grip_guide_for_slot(held_item, slot_id)
	if guide_node == null or not is_instance_valid(guide_node):
		return []
	if guide_node.has_meta("finger_grip_contact_ray_debug"):
		return (guide_node.get_meta("finger_grip_contact_ray_debug", []) as Array).duplicate(true)
	var center_node: Node3D = guide_node.get_node_or_null("GripShellCenter") as Node3D
	if center_node != null and center_node.has_meta("finger_grip_contact_ray_debug"):
		return (center_node.get_meta("finger_grip_contact_ray_debug", []) as Array).duplicate(true)
	return []

func _resolve_preview_finger_contact_meta(
	held_item: Node3D,
	slot_id: StringName,
	meta_key: String,
	default_value: float
) -> float:
	var guide_node: Node3D = _resolve_preview_grip_guide_for_slot(held_item, slot_id)
	if guide_node == null or not is_instance_valid(guide_node):
		return default_value
	if guide_node.has_meta(meta_key):
		return float(guide_node.get_meta(meta_key, default_value))
	var center_node: Node3D = guide_node.get_node_or_null("GripShellCenter") as Node3D
	if center_node != null and center_node.has_meta(meta_key):
		return float(center_node.get_meta(meta_key, default_value))
	return default_value

func _resolve_preview_grip_guide_for_slot(held_item: Node3D, slot_id: StringName) -> Node3D:
	if held_item == null or not is_instance_valid(held_item):
		return null
	var guide_name: String = "PrimaryGripGuide" if slot_id == _resolve_preview_dominant_slot_id() else "SecondaryGripGuide"
	return held_item.get_node_or_null(guide_name) as Node3D

func _resolve_preview_support_coupling_metrics(actor: Node3D, held_item: Node3D) -> Dictionary:
	var result := {
		"weapon_seat_distance_meters": -1.0,
		"hand_target_distance_meters": -1.0,
		"radial_mismatch_meters": -1.0,
	}
	if actor == null or held_item == null or not is_instance_valid(held_item):
		return result
	var primary_anchor: Node3D = weapon_grip_anchor_provider.get_primary_grip_anchor(held_item)
	var support_anchor: Node3D = weapon_grip_anchor_provider.get_support_grip_anchor(held_item)
	if primary_anchor == null or support_anchor == null:
		return result
	var dominant_target_world: Vector3 = _resolve_preview_hand_grip_target_world(actor, _resolve_preview_dominant_slot_id())
	var support_target_world: Vector3 = _resolve_preview_hand_grip_target_world(actor, _resolve_preview_support_slot_id())
	if dominant_target_world.length_squared() <= 0.000001 or support_target_world.length_squared() <= 0.000001:
		return result
	var weapon_seat_distance: float = primary_anchor.global_position.distance_to(support_anchor.global_position)
	var hand_target_distance: float = dominant_target_world.distance_to(support_target_world)
	result["weapon_seat_distance_meters"] = weapon_seat_distance
	result["hand_target_distance_meters"] = hand_target_distance
	result["radial_mismatch_meters"] = absf(weapon_seat_distance - hand_target_distance)
	return result

func _resolve_preview_hand_grip_target_world(actor: Node3D, slot_id: StringName) -> Vector3:
	if actor == null:
		return Vector3.ZERO
	var anchor_method_name: StringName = &"get_left_hand_item_anchor" if slot_id == &"hand_left" else &"get_right_hand_item_anchor"
	if not actor.has_method(anchor_method_name):
		return Vector3.ZERO
	var hand_anchor: Node3D = actor.call(anchor_method_name) as Node3D
	if hand_anchor == null or not is_instance_valid(hand_anchor):
		return Vector3.ZERO
	var hand_alignment_offset_state: Dictionary = _resolve_actor_hand_grip_alignment_offset_state(actor, slot_id)
	if not hand_alignment_offset_state.is_empty():
		var hand_alignment_offset_origin_id: StringName = _resolve_origin_tracked_state_origin_id(
			hand_alignment_offset_state,
			"hand_alignment_offset_origin_id",
			CombatOriginRecordScript.ORIGIN_HAND_GRIP_ALIGNMENT
		)
		var grip_offset_local: Vector3 = _get_origin_tracked_vector3_state(
			hand_alignment_offset_state,
			"hand_alignment_offset_local",
			"hand_alignment_offset_origin_id",
			Vector3.ZERO,
			hand_alignment_offset_origin_id
		)
		return hand_anchor.to_global(grip_offset_local)
	return hand_anchor.global_position

func _resolve_actor_hand_grip_alignment_offset_state(actor: Node3D, slot_id: StringName) -> Dictionary:
	if actor == null:
		return {}
	var result := {
		"hand_alignment_offset_local": Vector3.ZERO,
		"hand_alignment_offset_origin_id": CombatOriginRecordScript.ORIGIN_HAND_GRIP_ALIGNMENT,
	}
	if actor.has_method("resolve_hand_grip_alignment_offset_state"):
		var state_variant: Variant = actor.call("resolve_hand_grip_alignment_offset_state", slot_id)
		if state_variant is Dictionary:
			var source_state: Dictionary = state_variant as Dictionary
			_resolve_origin_tracked_state_origin_id(
				source_state,
				"hand_alignment_offset_origin_id",
				CombatOriginRecordScript.ORIGIN_HAND_GRIP_ALIGNMENT
			)
			return source_state
	if actor.has_method("resolve_hand_grip_alignment_offset_origin_id"):
		var origin_variant: Variant = actor.call("resolve_hand_grip_alignment_offset_origin_id", slot_id)
		if origin_variant is StringName or origin_variant is String:
			var origin_id: StringName = StringName(origin_variant)
			if origin_id != StringName():
				result["hand_alignment_offset_origin_id"] = origin_id
	if actor.has_method("resolve_hand_grip_alignment_offset_local"):
		var offset_variant: Variant = actor.call("resolve_hand_grip_alignment_offset_local", slot_id)
		if offset_variant is Vector3:
			result["hand_alignment_offset_local"] = offset_variant
	return result

func _resolve_preview_mount_anchor(actor: Node3D) -> Node3D:
	return _resolve_preview_mount_anchor_for_slot(actor, _resolve_preview_dominant_slot_id())

func _resolve_preview_mount_anchor_for_slot(actor: Node3D, slot_id: StringName) -> Node3D:
	var anchor_method_name: StringName = &"get_left_hand_item_anchor" if slot_id == &"hand_left" else &"get_right_hand_item_anchor"
	if actor != null and actor.has_method(anchor_method_name):
		var hand_anchor: Node3D = actor.call(anchor_method_name) as Node3D
		if hand_anchor != null and is_instance_valid(hand_anchor):
			return hand_anchor
	return null

func _resolve_unarmed_hand_proxy_points_state(actor: Node3D, slot_id: StringName) -> Dictionary:
	if actor == null:
		return {}
	var hand_anchor: Node3D = _resolve_preview_mount_anchor_for_slot(actor, slot_id)
	if hand_anchor == null or not is_instance_valid(hand_anchor):
		return {}
	var skeleton: Skeleton3D = actor.get_node_or_null(PREVIEW_SKELETON_PATH) as Skeleton3D
	if skeleton == null:
		return {}
	var hand_bone: StringName = PREVIEW_LEFT_HAND_BONE if slot_id == &"hand_left" else PREVIEW_RIGHT_HAND_BONE
	var index_bone: StringName = PREVIEW_LEFT_INDEX1_BONE if slot_id == &"hand_left" else PREVIEW_RIGHT_INDEX1_BONE
	var pinky_bone: StringName = PREVIEW_LEFT_PINKY1_BONE if slot_id == &"hand_left" else PREVIEW_RIGHT_PINKY1_BONE
	var hand_world: Vector3 = _get_skeleton_bone_world_position(skeleton, hand_bone)
	var index_world: Vector3 = _get_skeleton_bone_world_position(skeleton, index_bone)
	var pinky_world: Vector3 = _get_skeleton_bone_world_position(skeleton, pinky_bone)
	if hand_world.length_squared() <= 0.000001 or index_world.length_squared() <= 0.000001 or pinky_world.length_squared() <= 0.000001:
		return {}
	var index_to_pinky: Vector3 = pinky_world - index_world
	if index_to_pinky.length_squared() <= 0.000001:
		return {}
	var line_t: float = (hand_world - index_world).dot(index_to_pinky) / index_to_pinky.length_squared()
	var contact_center_world: Vector3 = index_world + index_to_pinky * line_t
	var tip_axis_world: Vector3 = index_world - pinky_world
	if tip_axis_world.length_squared() <= 0.000001:
		return {}
	tip_axis_world = tip_axis_world.normalized()
	var half_length: float = clampf(index_world.distance_to(pinky_world) * 1.5, UNARMED_PROXY_MIN_HALF_LENGTH_METERS, UNARMED_PROXY_MAX_HALF_LENGTH_METERS)
	var tip_world: Vector3 = contact_center_world + tip_axis_world * half_length
	var pommel_world: Vector3 = contact_center_world - tip_axis_world * half_length
	var grip_world: Vector3 = _resolve_preview_hand_grip_target_world(actor, slot_id)
	if grip_world.length_squared() <= 0.000001:
		grip_world = hand_anchor.global_position
	var anchor_basis_inverse: Basis = hand_anchor.global_basis.orthonormalized().inverse()
	return {
		"tip_local": anchor_basis_inverse * (tip_world - grip_world),
		"tip_origin_id": CombatOriginRecordScript.ORIGIN_HAND_GRIP_ALIGNMENT,
		"pommel_local": anchor_basis_inverse * (pommel_world - grip_world),
		"pommel_origin_id": CombatOriginRecordScript.ORIGIN_HAND_GRIP_ALIGNMENT,
		"contact_center_local": anchor_basis_inverse * (contact_center_world - grip_world),
		"contact_center_origin_id": CombatOriginRecordScript.ORIGIN_HAND_GRIP_ALIGNMENT,
		"contact_center_world": contact_center_world,
		"index1_world": index_world,
		"pinky1_world": pinky_world,
	}

func _build_fallback_unarmed_proxy_points_state() -> Dictionary:
	return {
		"tip_local": Vector3(0.12, 0.0, 0.0),
		"tip_origin_id": CombatOriginRecordScript.ORIGIN_HAND_GRIP_ALIGNMENT,
		"pommel_local": Vector3(-0.12, 0.0, 0.0),
		"pommel_origin_id": CombatOriginRecordScript.ORIGIN_HAND_GRIP_ALIGNMENT,
		"contact_center_local": Vector3.ZERO,
		"contact_center_origin_id": CombatOriginRecordScript.ORIGIN_HAND_GRIP_ALIGNMENT,
	}

func _is_unarmed_preview_item(held_item: Node3D) -> bool:
	return held_item != null and bool(held_item.get_meta("unarmed_hand_proxy", false))

func _resolve_perpendicular_unit(axis: Vector3, preferred: Vector3) -> Vector3:
	var resolved_axis: Vector3 = axis.normalized()
	var resolved: Vector3 = preferred - resolved_axis * preferred.dot(resolved_axis)
	if resolved.length_squared() <= 0.000001:
		resolved = Vector3.UP - resolved_axis * Vector3.UP.dot(resolved_axis)
	if resolved.length_squared() <= 0.000001:
		resolved = Vector3.RIGHT - resolved_axis * Vector3.RIGHT.dot(resolved_axis)
	if resolved.length_squared() <= 0.000001:
		resolved = Vector3.FORWARD - resolved_axis * Vector3.FORWARD.dot(resolved_axis)
	return resolved.normalized() if resolved.length_squared() > 0.000001 else Vector3.UP

func _resolve_preview_hand_mount_local_transform(held_item: Node3D) -> Transform3D:
	if held_item == null:
		return Transform3D.IDENTITY
	return equipped_item_presenter.resolve_hand_mount_local_transform(held_item)

func _resolve_preview_hand_mounted_transform(actor: Node3D, held_item: Node3D) -> Transform3D:
	var hand_anchor: Node3D = _resolve_preview_mount_anchor(actor)
	var mount_local_transform: Transform3D = _resolve_preview_hand_mount_local_transform(held_item)
	if hand_anchor == null or not is_instance_valid(hand_anchor):
		return held_item.global_transform
	var resolved_grip_local: Vector3 = _get_preview_primary_grip_seat_meta(held_item)
	var grip_target_world: Vector3 = _resolve_preview_hand_grip_target_world(actor, _resolve_preview_dominant_slot_id())
	var solved_basis: Basis = (hand_anchor.global_basis * mount_local_transform.basis).orthonormalized()
	if grip_target_world.length_squared() <= 0.000001:
		return Transform3D(solved_basis, (hand_anchor.global_transform * mount_local_transform).origin)
	var solved_origin: Vector3 = grip_target_world - solved_basis * resolved_grip_local
	return Transform3D(solved_basis, solved_origin)

func _apply_preview_hand_mounted_transform(actor: Node3D, held_item: Node3D) -> void:
	if held_item == null or not is_instance_valid(held_item):
		return
	held_item.global_transform = _resolve_preview_hand_mounted_transform(actor, held_item)

func _should_preview_use_support_hand(held_item: Node3D, motion_node: CombatAnimationMotionNode) -> bool:
	if held_item == null:
		return false
	if motion_node != null and motion_node.preferred_grip_style_mode == CraftedItemWIP.GRIP_REVERSE:
		return false
	if not bool(held_item.get_meta("two_hand_character_eligible", false)):
		return false
	var support_anchor: Node3D = weapon_grip_anchor_provider.get_support_grip_anchor(held_item)
	if support_anchor == null:
		return false
	if motion_node != null:
		if motion_node.two_hand_state == CombatAnimationMotionNodeScript.TWO_HAND_STATE_ONE_HAND:
			return false
		if motion_node.two_hand_state == CombatAnimationMotionNodeScript.TWO_HAND_STATE_TWO_HAND:
			return true
	return preview_default_two_hand

func _preview_weapon_proxy_intersects_body(
	body_restriction_root: Node3D,
	held_item: Node3D,
	solved_transform: Transform3D
) -> bool:
	if body_restriction_root == null or held_item == null:
		return false
	var pose_result: Dictionary = collision_legality_resolver.evaluate_weapon_pose(
		body_restriction_root,
		held_item,
		solved_transform,
		hand_target_constraint_solver
	)
	return not bool(pose_result.get("legal", true))

func _collect_preview_weapon_proxy_sample_positions(
	held_item: Node3D,
	solved_transform: Transform3D
) -> Array[Vector3]:
	var sample_positions: Array[Vector3] = []
	if held_item == null:
		return sample_positions
	var proxy_root: Node3D = held_item.get_node_or_null("WeaponBodyRestrictionProxy") as Node3D
	if proxy_root == null:
		return sample_positions
	for sample_node: Node in proxy_root.get_children():
		var sample: Node3D = sample_node as Node3D
		if sample == null:
			continue
		if not String(sample.name).begins_with("WeaponBodySample_"):
			continue
		var local_sample: Vector3 = held_item.to_local(sample.global_position)
		sample_positions.append(solved_transform * local_sample)
	return sample_positions

func _resolve_preview_shoulder_world(actor: Node3D, slot_id: StringName) -> Vector3:
	var skeleton: Skeleton3D = actor.get_node_or_null(PREVIEW_SKELETON_PATH) as Skeleton3D if actor != null else null
	if skeleton == null:
		return actor.global_position if actor != null else Vector3.ZERO
	var bone_name: StringName = PREVIEW_RIGHT_CLAVICLE_BONE if slot_id != &"hand_left" else PREVIEW_LEFT_CLAVICLE_BONE
	var bone_index: int = skeleton.find_bone(String(bone_name))
	if bone_index < 0:
		return actor.global_position
	return skeleton.to_global(skeleton.get_bone_global_pose(bone_index).origin)

func _resolve_preview_torso_frame(actor: Node3D) -> Dictionary:
	var skeleton: Skeleton3D = actor.get_node_or_null(PREVIEW_SKELETON_PATH) as Skeleton3D if actor != null else null
	var origin_world: Vector3 = actor.global_position if actor != null else Vector3.ZERO
	if skeleton != null:
		var chest_index: int = skeleton.find_bone(String(PREVIEW_TORSO_CHEST_BONE))
		if chest_index >= 0:
			origin_world = skeleton.to_global(skeleton.get_bone_global_pose(chest_index).origin)
	var basis_source: Basis = actor.global_basis if actor != null else Basis.IDENTITY
	var basis_frame: Dictionary = character_frame_resolver.resolve_basis_frame(basis_source)
	return {
		"origin_world": origin_world,
		"forward_world": basis_frame.get("forward_world", character_frame_resolver.get_default_forward_world()),
		"right_world": basis_frame.get("right_world", basis_source.x.normalized()),
		"up_world": basis_frame.get("up_world", basis_source.y.normalized()),
	}

func _update_camera(preview_root: Node3D, primary_anchor: Node3D) -> void:
	if preview_root == null:
		return
	var focus_point: Vector3 = _resolve_camera_focus_point(primary_anchor)
	_ensure_camera_state(preview_root, focus_point)
	preview_root.set_meta(CAMERA_FOCUS_POINT_META, focus_point)
	_apply_camera_transform(preview_root)

func _get_preview_root(preview_subviewport: SubViewport) -> Node3D:
	return preview_subviewport.get_node_or_null(PREVIEW_ROOT_NAME) as Node3D if preview_subviewport != null else null

func _resolve_camera_focus_point(primary_anchor: Node3D) -> Vector3:
	var focus_point := Vector3(0.0, 1.1, 0.0)
	if primary_anchor != null:
		focus_point = focus_point.lerp(primary_anchor.global_position, 0.5)
	return focus_point

func _ensure_camera_state(preview_root: Node3D, focus_point: Vector3) -> void:
	if preview_root == null:
		return
	preview_root.set_meta(CAMERA_FOCUS_POINT_META, focus_point)
	if bool(_get_node_meta_or_default(preview_root, CAMERA_STATE_READY_META, false)):
		return
	var orbit_yaw: float = rad_to_deg(atan2(DEFAULT_CAMERA_OFFSET.x, DEFAULT_CAMERA_OFFSET.z))
	var orbit_pitch: float = rad_to_deg(asin(clampf(DEFAULT_CAMERA_OFFSET.y / CAMERA_DEFAULT_DISTANCE, -1.0, 1.0)))
	preview_root.set_meta(CAMERA_DISTANCE_META, CAMERA_DEFAULT_DISTANCE)
	preview_root.set_meta(CAMERA_ORBIT_YAW_META, orbit_yaw)
	preview_root.set_meta(CAMERA_ORBIT_PITCH_META, orbit_pitch)
	preview_root.set_meta(CAMERA_STATE_READY_META, true)

func _apply_camera_transform(preview_root: Node3D) -> void:
	if preview_root == null:
		return
	var camera: Camera3D = preview_root.get_node_or_null(PREVIEW_CAMERA_NAME) as Camera3D
	if camera == null:
		return
	var focus_point: Vector3 = _get_vector3_meta(preview_root, CAMERA_FOCUS_POINT_META, Vector3(0.0, 1.1, 0.0))
	var distance: float = clampf(float(_get_node_meta_or_default(preview_root, CAMERA_DISTANCE_META, CAMERA_DEFAULT_DISTANCE)), CAMERA_MIN_DISTANCE, CAMERA_MAX_DISTANCE)
	var orbit_yaw_radians: float = deg_to_rad(float(_get_node_meta_or_default(preview_root, CAMERA_ORBIT_YAW_META, 0.0)))
	var requested_pitch_radians: float = deg_to_rad(float(_get_node_meta_or_default(preview_root, CAMERA_ORBIT_PITCH_META, 0.0)))
	var minimum_pitch_radians: float = deg_to_rad(CAMERA_MIN_PITCH_DEGREES)
	var floor_limited_min_pitch_radians: float = minimum_pitch_radians
	if distance > 0.00001:
		floor_limited_min_pitch_radians = asin(clampf((CAMERA_FLOOR_HEIGHT + CAMERA_FLOOR_CLEARANCE - focus_point.y) / distance, -1.0, 1.0))
	var orbit_pitch_radians: float = clampf(requested_pitch_radians, maxf(minimum_pitch_radians, floor_limited_min_pitch_radians), deg_to_rad(CAMERA_MAX_PITCH_DEGREES))
	var horizontal_distance: float = cos(orbit_pitch_radians) * distance
	var camera_offset := Vector3(
		sin(orbit_yaw_radians) * horizontal_distance,
		sin(orbit_pitch_radians) * distance,
		cos(orbit_yaw_radians) * horizontal_distance
	)
	var camera_position: Vector3 = focus_point + camera_offset
	camera_position.y = maxf(camera_position.y, CAMERA_FLOOR_HEIGHT + CAMERA_FLOOR_CLEARANCE)
	camera.look_at_from_position(camera_position, focus_point, Vector3.UP)
	preview_root.set_meta(CAMERA_DISTANCE_META, distance)
	preview_root.set_meta(CAMERA_ORBIT_PITCH_META, rad_to_deg(orbit_pitch_radians))

func _get_vector3_meta(node: Node, meta_key: String, default_value: Vector3) -> Vector3:
	if node == null or not node.has_meta(meta_key):
		return default_value
	var value: Variant = node.get_meta(meta_key)
	return value as Vector3 if value is Vector3 else default_value

func _render_speed_colored_curve_mesh(immediate_mesh: ImmediateMesh, speed_state_result: Dictionary) -> void:
	if immediate_mesh == null:
		return
	immediate_mesh.clear_surfaces()
	var samples: Array = speed_state_result.get("samples", []) as Array
	if samples.size() < 2:
		return
	immediate_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for sample_index: int in range(samples.size() - 1):
		var sample_a: Dictionary = samples[sample_index] as Dictionary
		var sample_b: Dictionary = samples[sample_index + 1] as Dictionary
		if sample_a.is_empty() or sample_b.is_empty():
			continue
		var color_a: Color = sample_a.get("color", Color(0.18, 0.85, 0.35, 1.0)) as Color
		var color_b: Color = sample_b.get("color", Color(0.18, 0.85, 0.35, 1.0)) as Color
		immediate_mesh.surface_set_color(color_a)
		immediate_mesh.surface_add_vertex(sample_a.get("tip_position", Vector3.ZERO) as Vector3)
		immediate_mesh.surface_set_color(color_b)
		immediate_mesh.surface_add_vertex(sample_b.get("tip_position", Vector3.ZERO) as Vector3)
		immediate_mesh.surface_set_color(Color(color_a.r, color_a.g, color_a.b, 0.72))
		immediate_mesh.surface_add_vertex(sample_a.get("pommel_position", Vector3.ZERO) as Vector3)
		immediate_mesh.surface_set_color(Color(color_b.r, color_b.g, color_b.b, 0.72))
		immediate_mesh.surface_add_vertex(sample_b.get("pommel_position", Vector3.ZERO) as Vector3)
	immediate_mesh.surface_end()

func _render_lightweight_curve_mesh(immediate_mesh: ImmediateMesh, tip_curve: Curve3D, pommel_curve: Curve3D) -> void:
	if immediate_mesh == null:
		return
	immediate_mesh.clear_surfaces()
	var tip_points: PackedVector3Array = tip_curve.get_baked_points() if tip_curve != null else PackedVector3Array()
	var pommel_points: PackedVector3Array = pommel_curve.get_baked_points() if pommel_curve != null else PackedVector3Array()
	if tip_points.size() < 2 and pommel_points.size() < 2:
		return
	immediate_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	_add_lightweight_curve_vertices(immediate_mesh, tip_points, Color(1.0, 0.82, 0.18, 1.0))
	_add_lightweight_curve_vertices(immediate_mesh, pommel_points, Color(1.0, 0.82, 0.18, 0.62))
	immediate_mesh.surface_end()

func _add_lightweight_curve_vertices(immediate_mesh: ImmediateMesh, points: PackedVector3Array, color: Color) -> void:
	if immediate_mesh == null or points.size() < 2:
		return
	for point_index: int in range(points.size() - 1):
		immediate_mesh.surface_set_color(color)
		immediate_mesh.surface_add_vertex(points[point_index])
		immediate_mesh.surface_set_color(color)
		immediate_mesh.surface_add_vertex(points[point_index + 1])

func _add_speed_colored_vertices(immediate_mesh: ImmediateMesh, curve: Curve3D, baked_points: PackedVector3Array, segment_speeds: Array[float], is_tip: bool) -> void:
	if baked_points.size() < 2:
		return
	var total_length: float = curve.get_baked_length()
	if total_length <= 0.00001:
		return
	var speed_min: float = INF
	var speed_max: float = -INF
	for speed: float in segment_speeds:
		speed_min = minf(speed_min, speed)
		speed_max = maxf(speed_max, speed)
	var speed_range: float = speed_max - speed_min if speed_max > speed_min else 1.0
	var color_fast: Color = Color(1.0, 0.25, 0.18, 1.0) if is_tip else Color(0.9, 0.2, 0.15, 0.7)
	var color_slow: Color = Color(0.18, 0.85, 0.35, 1.0) if is_tip else Color(0.15, 0.7, 0.3, 0.7)
	for point_index: int in range(baked_points.size() - 1):
		var offset_a: float = curve.get_closest_offset(baked_points[point_index])
		var ratio_a: float = offset_a / total_length
		var speed_a: float = _sample_speed_at_ratio(segment_speeds, ratio_a)
		var normalized_a: float = clampf((speed_a - speed_min) / speed_range, 0.0, 1.0)
		var color_a: Color = color_slow.lerp(color_fast, normalized_a)
		var offset_b: float = curve.get_closest_offset(baked_points[point_index + 1])
		var ratio_b: float = offset_b / total_length
		var speed_b: float = _sample_speed_at_ratio(segment_speeds, ratio_b)
		var normalized_b: float = clampf((speed_b - speed_min) / speed_range, 0.0, 1.0)
		var color_b: Color = color_slow.lerp(color_fast, normalized_b)
		immediate_mesh.surface_set_color(color_a)
		immediate_mesh.surface_add_vertex(baked_points[point_index])
		immediate_mesh.surface_set_color(color_b)
		immediate_mesh.surface_add_vertex(baked_points[point_index + 1])

func _calculate_segment_speeds(motion_node_chain: Array) -> Array[float]:
	var speeds: Array[float] = []
	if motion_node_chain.size() < 2:
		speeds.append(1.0)
		return speeds
	for node_index: int in range(motion_node_chain.size()):
		if node_index == 0:
			speeds.append(0.0)
			continue
		var prev_node: CombatAnimationMotionNode = motion_node_chain[node_index - 1] as CombatAnimationMotionNode
		var curr_node: CombatAnimationMotionNode = motion_node_chain[node_index] as CombatAnimationMotionNode
		if prev_node == null or curr_node == null:
			speeds.append(1.0)
			continue
		var segment_distance: float = prev_node.tip_position_local.distance_to(curr_node.tip_position_local)
		var duration: float = maxf(curr_node.transition_duration_seconds, 0.01)
		speeds.append(segment_distance / duration)
	return speeds

func _sample_speed_at_ratio(segment_speeds: Array[float], ratio: float) -> float:
	if segment_speeds.is_empty():
		return 1.0
	var segment_count: int = maxi(segment_speeds.size() - 1, 1)
	var segment_float: float = ratio * float(segment_count)
	var segment_index: int = clampi(int(segment_float), 0, segment_speeds.size() - 1)
	var next_index: int = mini(segment_index + 1, segment_speeds.size() - 1)
	var local_ratio: float = clampf(segment_float - float(segment_index), 0.0, 1.0)
	return lerpf(segment_speeds[segment_index], segment_speeds[next_index], local_ratio)

func _refresh_onion_skin(onion_skin_root: Node3D, motion_node_chain: Array, selected_node_index: int) -> void:
	if onion_skin_root == null:
		return
	if motion_node_chain.size() < 2:
		return
	var offsets: Array[int] = [-2, -1, 1, 2]
	var alpha_map: Dictionary = {-2: 0.15, -1: 0.35, 1: 0.35, 2: 0.15}
	for offset: int in offsets:
		var neighbor_index: int = selected_node_index + offset
		if neighbor_index < 0 or neighbor_index >= motion_node_chain.size():
			continue
		var neighbor_node: CombatAnimationMotionNode = motion_node_chain[neighbor_index] as CombatAnimationMotionNode
		if neighbor_node == null:
			continue
		var alpha_value: float = float(alpha_map.get(offset, 0.2))
		_create_onion_marker(onion_skin_root, neighbor_node.tip_position_local, Color(1.0, 0.86, 0.2, alpha_value))
		_create_onion_marker(onion_skin_root, neighbor_node.pommel_position_local, Color(0.6, 0.5, 0.8, alpha_value))

func _create_onion_marker(parent_root: Node3D, local_position: Vector3, color: Color) -> void:
	var marker := MeshInstance3D.new()
	marker.name = "OnionMarker_%d" % parent_root.get_child_count()
	var mesh := SphereMesh.new()
	mesh.radius = 0.012 * CONTROL_MARKER_SIZE_MULTIPLIER
	mesh.height = mesh.radius * 2.0
	marker.mesh = mesh
	marker.position = local_position
	marker.material_override = _build_overlay_surface_material(color, 0.5)
	parent_root.add_child(marker)

func _refresh_weapon_and_sphere_visuals(state: Dictionary, motion_node_chain: Array, selected_node_index: int, active_focus: StringName, baked_profile: BakedProfile) -> void:
	var preview_root: Node3D = state.get("preview_root", null) as Node3D
	var marker_root: Node3D = state.get("marker_root", null) as Node3D
	var sphere_viz_mesh: MeshInstance3D = state.get("sphere_viz_mesh", null) as MeshInstance3D
	if sphere_viz_mesh != null and sphere_viz_mesh.mesh is ImmediateMesh:
		(sphere_viz_mesh.mesh as ImmediateMesh).clear_surfaces()
	if preview_root != null:
		preview_root.set_meta("weapon_gizmo_marker_count", 0)
		preview_root.set_meta("upperarm_roll_gizmo_state", {})
		preview_root.set_meta("upperarm_roll_gizmo_count", 0)
	if selected_node_index < 0 or selected_node_index >= motion_node_chain.size():
		return
	var motion_node: CombatAnimationMotionNode = motion_node_chain[selected_node_index] as CombatAnimationMotionNode
	if motion_node == null:
		return
	var gizmo_marker_count: int = 0
	if marker_root != null:
		_create_weapon_rotation_gizmo_markers(marker_root, motion_node, active_focus)
		gizmo_marker_count += 2
		gizmo_marker_count += _create_upperarm_roll_gizmo_markers(state, motion_node, active_focus)
		if preview_root != null:
			preview_root.set_meta("weapon_gizmo_marker_count", gizmo_marker_count)
	if sphere_viz_mesh != null and active_focus == CombatAnimationSessionStateScript.FOCUS_TIP:
		var weapon_length: float = baked_profile.weapon_total_length_meters if baked_profile != null and baked_profile.weapon_total_length_meters > 0.001 else 0.5
		_render_endpoint_sphere_wireframe(sphere_viz_mesh.mesh as ImmediateMesh, motion_node.pommel_position_local, weapon_length)

func _create_weapon_rotation_gizmo_markers(marker_root: Node3D, motion_node: CombatAnimationMotionNode, active_focus: StringName) -> void:
	if marker_root == null or motion_node == null:
		return
	var weapon_center: Vector3 = motion_node.tip_position_local.lerp(motion_node.pommel_position_local, 0.5)
	var weapon_normal_handle: Vector3 = weapon_center + _resolve_weapon_rotation_normal_local(motion_node) * WEAPON_ROTATION_GIZMO_HANDLE_DISTANCE
	var weapon_focus_active: bool = active_focus == CombatAnimationSessionStateScript.FOCUS_WEAPON
	var center_color: Color = Color(0.95, 0.58, 0.26, 1.0) if weapon_focus_active else Color(0.72, 0.48, 0.22, 0.9)
	var normal_color: Color = Color(0.42, 0.98, 0.72, 1.0) if weapon_focus_active else Color(0.28, 0.72, 0.56, 0.95)
	_create_control_gizmo_marker(marker_root, weapon_center, center_color, 0.019 if weapon_focus_active else 0.016, "WeaponCenter", WEAPON_ROLL_MARKER_EXTRA_SCALE)
	_create_control_gizmo_marker(marker_root, weapon_normal_handle, normal_color, 0.021 if weapon_focus_active else 0.018, "WeaponNormal")

func _create_upperarm_roll_gizmo_markers(state: Dictionary, motion_node: CombatAnimationMotionNode, active_focus: StringName) -> int:
	var preview_root: Node3D = state.get("preview_root", null) as Node3D
	var trajectory_root: Node3D = state.get("trajectory_root", null) as Node3D
	var marker_root: Node3D = state.get("marker_root", null) as Node3D
	var actor_pivot: Node3D = state.get("actor_pivot", null) as Node3D
	if preview_root == null or trajectory_root == null or marker_root == null or actor_pivot == null or motion_node == null:
		return 0
	var actor: Node3D = actor_pivot.get_node_or_null(PREVIEW_ACTOR_NAME) as Node3D
	var skeleton: Skeleton3D = actor.get_node_or_null(PREVIEW_SKELETON_PATH) as Skeleton3D if actor != null else null
	if skeleton == null:
		return 0
	var held_item: Node3D = _get_node_meta_or_default(preview_root, "preview_held_item", null) as Node3D
	var resolved_state: Dictionary = _get_node_meta_or_default(preview_root, "resolved_playback_state", {}) as Dictionary
	var two_hand_active: bool = bool(resolved_state.get("two_hand", _should_preview_use_support_hand(held_item, motion_node)))
	var dominant_slot_id: StringName = _normalize_preview_slot_id(StringName(resolved_state.get("dominant_slot_id", _resolve_preview_dominant_slot_id())))
	var support_slot_id: StringName = &"hand_right" if dominant_slot_id == &"hand_left" else &"hand_left"
	var active_slots: Array[StringName] = [dominant_slot_id]
	if two_hand_active:
		active_slots.append(support_slot_id)
	var gizmo_state: Dictionary = {}
	var marker_count: int = 0
	for slot_id in active_slots:
		var is_left_slot: bool = slot_id == &"hand_left"
		var slot_state: Dictionary = _build_upperarm_roll_gizmo_state(
			skeleton,
			trajectory_root,
			slot_id,
			PREVIEW_LEFT_UPPERARM_BONE if is_left_slot else PREVIEW_RIGHT_UPPERARM_BONE,
			PREVIEW_LEFT_FOREARM_BONE if is_left_slot else PREVIEW_RIGHT_FOREARM_BONE,
			PREVIEW_LEFT_HAND_BONE if is_left_slot else PREVIEW_RIGHT_HAND_BONE,
			motion_node.left_upperarm_roll_degrees if is_left_slot else motion_node.right_upperarm_roll_degrees
		)
		if not slot_state.is_empty():
			gizmo_state[slot_id] = slot_state
			var slot_color: Color = Color(0.25, 0.72, 1.0, 0.95) if is_left_slot else Color(0.3, 0.95, 0.45, 0.95)
			var slot_prefix: String = "LeftUpperarmRoll" if is_left_slot else "RightUpperarmRoll"
			marker_count += _draw_upperarm_roll_gizmo(marker_root, slot_state, active_focus, slot_color, slot_prefix)
	preview_root.set_meta("upperarm_roll_gizmo_state", gizmo_state)
	preview_root.set_meta("upperarm_roll_gizmo_count", marker_count)
	return marker_count

func _build_upperarm_roll_gizmo_state(
	skeleton: Skeleton3D,
	trajectory_root: Node3D,
	slot_id: StringName,
	upperarm_bone: StringName,
	forearm_bone: StringName,
	hand_bone: StringName,
	current_roll_degrees: float
) -> Dictionary:
	var shoulder_world: Vector3 = _get_preview_bone_world_position(skeleton, upperarm_bone)
	var elbow_world: Vector3 = _get_preview_bone_world_position(skeleton, forearm_bone)
	var hand_world: Vector3 = _get_preview_bone_world_position(skeleton, hand_bone)
	var axis_world: Vector3 = hand_world - shoulder_world
	if axis_world.length_squared() <= 0.000001:
		return {}
	axis_world = axis_world.normalized()
	var center_world: Vector3 = shoulder_world.lerp(hand_world, 0.5)
	var radial_world: Vector3 = elbow_world - center_world
	radial_world -= axis_world * radial_world.dot(axis_world)
	if radial_world.length_squared() <= 0.000001:
		radial_world = _resolve_upperarm_roll_reference_world(slot_id, axis_world)
	if radial_world.length_squared() <= 0.000001:
		return {}
	var radius: float = clampf(radial_world.length(), UPPERARM_ROLL_GIZMO_MIN_RADIUS_METERS, UPPERARM_ROLL_GIZMO_MAX_RADIUS_METERS)
	var normal_world: Vector3 = radial_world.normalized()
	var handle_world: Vector3 = center_world + normal_world * radius
	var target: StringName = (
		CombatAnimationMotionNodeEditorScript.DRAG_TARGET_LEFT_UPPERARM_ROLL
		if slot_id == &"hand_left"
		else CombatAnimationMotionNodeEditorScript.DRAG_TARGET_RIGHT_UPPERARM_ROLL
	)
	var trajectory_inverse: Transform3D = trajectory_root.global_transform.affine_inverse()
	return {
		"slot_id": slot_id,
		"drag_target": target,
		"center_global": center_world,
		"axis_global": axis_world,
		"initial_normal_global": normal_world,
		"initial_roll_degrees": current_roll_degrees,
		"radius_meters": radius,
		"handle_global": handle_world,
		"center_local": trajectory_inverse * center_world,
		"center_origin_id": CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING,
		"handle_local": trajectory_inverse * handle_world,
		"handle_origin_id": CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING,
	}

func _draw_upperarm_roll_gizmo(
	marker_root: Node3D,
	roll_state: Dictionary,
	active_focus: StringName,
	color: Color,
	prefix: String
) -> int:
	var focus_active: bool = active_focus == CombatAnimationSessionStateScript.FOCUS_ARM_ROLL
	var center_local: Vector3 = _get_origin_tracked_vector3_state(
		roll_state,
		"center_local",
		"center_origin_id",
		Vector3.ZERO,
		CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING
	)
	var handle_local: Vector3 = _get_origin_tracked_vector3_state(
		roll_state,
		"handle_local",
		"handle_origin_id",
		Vector3.ZERO,
		CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING
	)
	var marker_color: Color = color if focus_active else Color(color.r, color.g, color.b, 0.55)
	_create_control_gizmo_marker(marker_root, center_local, Color(marker_color.r, marker_color.g, marker_color.b, 0.35), 0.014, "%sCenter" % prefix, 0.7)
	_create_control_gizmo_marker(marker_root, handle_local, marker_color, 0.018 if focus_active else 0.015, "%sHandle" % prefix, 0.9)
	_create_line_gizmo_marker(marker_root, center_local, handle_local, marker_color, "%sRod" % prefix)
	return 3

func _resolve_upperarm_roll_reference_world(slot_id: StringName, axis_world: Vector3) -> Vector3:
	var side_reference: Vector3 = Vector3.LEFT if slot_id == &"hand_left" else Vector3.RIGHT
	var reference_world: Vector3 = side_reference - axis_world * side_reference.dot(axis_world)
	if reference_world.length_squared() <= 0.000001:
		reference_world = Vector3.UP - axis_world * Vector3.UP.dot(axis_world)
	if reference_world.length_squared() <= 0.000001:
		reference_world = Vector3.FORWARD - axis_world * Vector3.FORWARD.dot(axis_world)
	if reference_world.length_squared() <= 0.000001:
		return Vector3.ZERO
	return reference_world.normalized()

func _get_preview_bone_world_position(skeleton: Skeleton3D, bone_name: StringName) -> Vector3:
	var bone_index: int = skeleton.find_bone(String(bone_name)) if skeleton != null else -1
	if bone_index < 0:
		return Vector3.ZERO
	return skeleton.to_global(skeleton.get_bone_global_pose(bone_index).origin)

func _resolve_weapon_rotation_normal_local(motion_node: CombatAnimationMotionNode) -> Vector3:
	if motion_node == null:
		return Vector3.UP
	var axis: Vector3 = motion_node.tip_position_local - motion_node.pommel_position_local
	if axis.length_squared() <= 0.000001:
		return Vector3.UP
	axis = axis.normalized()
	var orientation_source: Vector3 = _resolve_motion_node_weapon_orientation_degrees(motion_node)
	var orientation_rad: Vector3 = orientation_source * (PI / 180.0)
	var desired_normal: Vector3 = Basis.from_euler(orientation_rad) * Vector3.UP
	desired_normal -= axis * desired_normal.dot(axis)
	if desired_normal.length_squared() <= 0.000001:
		desired_normal = Vector3.UP - axis * Vector3.UP.dot(axis)
	if desired_normal.length_squared() <= 0.000001:
		desired_normal = Vector3.RIGHT - axis * Vector3.RIGHT.dot(axis)
	return desired_normal.normalized()

func _render_endpoint_sphere_wireframe(immediate_mesh: ImmediateMesh, center: Vector3, radius: float) -> void:
	if immediate_mesh == null:
		return
	immediate_mesh.clear_surfaces()
	var segments: int = 32
	var sphere_color := Color(0.8, 0.55, 0.9, 0.2)
	immediate_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for ring_index: int in range(3):
		var axis_a: int = ring_index
		var axis_b: int = (ring_index + 1) % 3
		for seg_index: int in range(segments):
			var angle_a: float = TAU * float(seg_index) / float(segments)
			var angle_b: float = TAU * float(seg_index + 1) / float(segments)
			var point_a: Vector3 = center
			var point_b: Vector3 = center
			point_a[axis_a] += cos(angle_a) * radius
			point_a[axis_b] += sin(angle_a) * radius
			point_b[axis_a] += cos(angle_b) * radius
			point_b[axis_b] += sin(angle_b) * radius
			immediate_mesh.surface_set_color(sphere_color)
			immediate_mesh.surface_add_vertex(point_a)
			immediate_mesh.surface_set_color(sphere_color)
			immediate_mesh.surface_add_vertex(point_b)
	immediate_mesh.surface_end()

func _curve_has_distinct_points(curve: Curve3D) -> bool:
	if curve.point_count < 2:
		return false
	var has_any_displacement: bool = false
	for point_index: int in range(curve.point_count - 1):
		var pos_current: Vector3 = curve.get_point_position(point_index)
		var pos_next: Vector3 = curve.get_point_position(point_index + 1)
		if pos_current.is_equal_approx(pos_next):
			var out_length_sq: float = curve.get_point_out(point_index).length_squared()
			var in_length_sq: float = curve.get_point_in(point_index + 1).length_squared()
			if out_length_sq < 0.00001 or in_length_sq < 0.00001:
				return false
		else:
			has_any_displacement = true
	return has_any_displacement

func _render_control_lines(immediate_mesh: ImmediateMesh, motion_node_chain: Array, selected_node_index: int) -> void:
	if immediate_mesh == null:
		return
	immediate_mesh.clear_surfaces()
	if motion_node_chain.is_empty():
		return
	if not _motion_node_chain_has_visible_curve_handles(motion_node_chain, selected_node_index):
		return
	immediate_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for node_index: int in range(motion_node_chain.size()):
		if node_index != selected_node_index:
			continue
		var motion_node: CombatAnimationMotionNode = motion_node_chain[node_index] as CombatAnimationMotionNode
		if motion_node == null:
			continue
		var tip_pos: Vector3 = motion_node.tip_position_local
		var tip_curve_in_handle: Vector3 = motion_node_editor.resolve_effective_curve_handle(motion_node_chain, node_index, true, true)
		var tip_curve_out_handle: Vector3 = motion_node_editor.resolve_effective_curve_handle(motion_node_chain, node_index, true, false)
		var pommel_curve_in_handle: Vector3 = motion_node_editor.resolve_effective_curve_handle(motion_node_chain, node_index, false, true)
		var pommel_curve_out_handle: Vector3 = motion_node_editor.resolve_effective_curve_handle(motion_node_chain, node_index, false, false)
		if tip_curve_in_handle.length() >= CURVE_HANDLE_VISUAL_MIN_LENGTH_METERS:
			immediate_mesh.surface_set_color(Color(0.2, 0.75, 1.0, 1.0))
			immediate_mesh.surface_add_vertex(tip_pos)
			immediate_mesh.surface_set_color(Color(0.2, 0.75, 1.0, 1.0))
			immediate_mesh.surface_add_vertex(tip_pos + tip_curve_in_handle)
		if tip_curve_out_handle.length() >= CURVE_HANDLE_VISUAL_MIN_LENGTH_METERS:
			immediate_mesh.surface_set_color(Color(1.0, 0.55, 0.12, 1.0))
			immediate_mesh.surface_add_vertex(tip_pos)
			immediate_mesh.surface_set_color(Color(1.0, 0.55, 0.12, 1.0))
			immediate_mesh.surface_add_vertex(tip_pos + tip_curve_out_handle)
		var pommel_pos: Vector3 = motion_node.pommel_position_local
		if pommel_curve_in_handle.length() >= CURVE_HANDLE_VISUAL_MIN_LENGTH_METERS:
			immediate_mesh.surface_set_color(Color(0.2, 0.55, 0.85, 1.0))
			immediate_mesh.surface_add_vertex(pommel_pos)
			immediate_mesh.surface_set_color(Color(0.2, 0.55, 0.85, 1.0))
			immediate_mesh.surface_add_vertex(pommel_pos + pommel_curve_in_handle)
		if pommel_curve_out_handle.length() >= CURVE_HANDLE_VISUAL_MIN_LENGTH_METERS:
			immediate_mesh.surface_set_color(Color(0.85, 0.4, 0.12, 1.0))
			immediate_mesh.surface_add_vertex(pommel_pos)
			immediate_mesh.surface_set_color(Color(0.85, 0.4, 0.12, 1.0))
			immediate_mesh.surface_add_vertex(pommel_pos + pommel_curve_out_handle)
	immediate_mesh.surface_end()

func _motion_node_chain_has_visible_curve_handles(motion_node_chain: Array, selected_node_index: int) -> bool:
	if selected_node_index < 0 or selected_node_index >= motion_node_chain.size():
		return false
	return (
		motion_node_editor.resolve_effective_curve_handle(motion_node_chain, selected_node_index, true, true).length() >= CURVE_HANDLE_VISUAL_MIN_LENGTH_METERS
		or motion_node_editor.resolve_effective_curve_handle(motion_node_chain, selected_node_index, true, false).length() >= CURVE_HANDLE_VISUAL_MIN_LENGTH_METERS
		or motion_node_editor.resolve_effective_curve_handle(motion_node_chain, selected_node_index, false, true).length() >= CURVE_HANDLE_VISUAL_MIN_LENGTH_METERS
		or motion_node_editor.resolve_effective_curve_handle(motion_node_chain, selected_node_index, false, false).length() >= CURVE_HANDLE_VISUAL_MIN_LENGTH_METERS
	)

func _refresh_noncombat_stow_anchor_markers(state: Dictionary, active_draft: Resource) -> Dictionary:
	var result: Dictionary = {
		"count": 0,
		"ids": [],
		"positions_local": {},
		"positions_origin_id": CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING,
		"position_origin_ids": {},
		"selected_id": StringName(),
		"slot_id": StringName(),
		"mode": StringName(),
		"orientation_side": StringName(),
	}
	if not _is_noncombat_idle_draft(active_draft):
		return result
	var preview_root: Node3D = state.get("preview_root", null) as Node3D
	var trajectory_root: Node3D = state.get("trajectory_root", null) as Node3D
	var marker_root: Node3D = state.get("marker_root", null) as Node3D
	if preview_root == null or trajectory_root == null or marker_root == null:
		return result
	var stow_selection: Dictionary = _resolve_noncombat_stow_selection(active_draft)
	var selected_anchor_id: StringName = stow_selection.get("selected_id", StringName()) as StringName
	var anchors: Array[Dictionary] = _collect_noncombat_stow_anchor_entries(state)
	var anchor_ids: Array[StringName] = []
	var positions_local: Dictionary = {}
	var positions_origin_id: StringName = CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING
	var position_origin_ids: Dictionary = {}
	for anchor: Dictionary in anchors:
		var anchor_id: StringName = anchor.get("id", StringName()) as StringName
		var anchor_label: String = String(anchor.get("label", String(anchor_id)))
		var position_world: Vector3 = anchor.get("position_world", Vector3.ZERO) as Vector3
		var position_local: Vector3 = trajectory_root.to_local(position_world)
		var position_origin_id: StringName = positions_origin_id
		_create_stow_anchor_marker(marker_root, position_local, anchor_id, anchor_label, anchor_id == selected_anchor_id)
		anchor_ids.append(anchor_id)
		positions_local[anchor_id] = position_local
		position_origin_ids[anchor_id] = position_origin_id
	result["count"] = anchor_ids.size()
	result["ids"] = anchor_ids
	result["positions_local"] = positions_local
	result["positions_origin_id"] = positions_origin_id
	result["position_origin_ids"] = position_origin_ids
	result["selected_id"] = selected_anchor_id
	result["slot_id"] = stow_selection.get("slot_id", StringName())
	result["mode"] = stow_selection.get("mode", StringName())
	result["orientation_side"] = stow_selection.get("orientation_side", StringName())
	return result

func _resolve_noncombat_stow_selection(active_draft: Resource) -> Dictionary:
	var stow_mode: StringName = (
		CombatAnimationDraftScript.normalize_stow_anchor_mode(StringName(active_draft.get("stow_anchor_mode")))
		if active_draft != null
		else CombatAnimationDraftScript.STOW_ANCHOR_SHOULDER_HANGING
	)
	var slot_id: StringName = CombatAnimationDraftScript.normalize_stow_slot_id(_resolve_preview_dominant_slot_id())
	return {
		"selected_id": CombatAnimationDraftScript.resolve_concrete_stow_anchor_id(stow_mode, slot_id),
		"slot_id": slot_id,
		"mode": stow_mode,
		"orientation_side": CombatAnimationDraftScript.resolve_stow_orientation_side(stow_mode, slot_id),
	}

func _resolve_selected_noncombat_stow_anchor_position_local(state: Dictionary, active_draft: Resource) -> Vector3:
	if not _is_noncombat_idle_draft(active_draft):
		return Vector3.ZERO
	var trajectory_root: Node3D = state.get("trajectory_root", null) as Node3D
	if trajectory_root == null:
		return Vector3.ZERO
	var selected_anchor_id: StringName = _resolve_noncombat_stow_selection(active_draft).get("selected_id", StringName()) as StringName
	for anchor: Dictionary in _collect_noncombat_stow_anchor_entries(state):
		var anchor_id: StringName = anchor.get("id", StringName()) as StringName
		if anchor_id != selected_anchor_id:
			continue
		var position_world: Vector3 = anchor.get("position_world", Vector3.ZERO) as Vector3
		return trajectory_root.to_local(position_world)
	return Vector3.ZERO

func _collect_noncombat_stow_anchor_entries(state: Dictionary) -> Array[Dictionary]:
	var anchors: Array[Dictionary] = []
	var actor_pivot: Node3D = state.get("actor_pivot", null) as Node3D
	var actor: Node3D = actor_pivot.get_node_or_null(PREVIEW_ACTOR_NAME) as Node3D if actor_pivot != null else null
	var skeleton: Skeleton3D = actor.get_node_or_null(PREVIEW_SKELETON_PATH) as Skeleton3D if actor != null else null
	if skeleton == null:
		return anchors
	_append_stow_anchor_from_bone(
		anchors,
		skeleton,
		CombatAnimationDraftScript.CONCRETE_STOW_UPPER_BACK_L,
		"Upper Back L",
		PREVIEW_LEFT_CLAVICLE_BONE,
		Vector3(0.0, 0.0, -1.0),
		STOW_UPPER_BACK_OFFSET_METERS
	)
	_append_stow_anchor_from_bone(
		anchors,
		skeleton,
		CombatAnimationDraftScript.CONCRETE_STOW_UPPER_BACK_R,
		"Upper Back R",
		PREVIEW_RIGHT_CLAVICLE_BONE,
		Vector3(0.0, 0.0, -1.0),
		STOW_UPPER_BACK_OFFSET_METERS
	)
	_append_stow_anchor_from_bone(
		anchors,
		skeleton,
		CombatAnimationDraftScript.CONCRETE_STOW_LOWER_BACK_CENTER,
		"Lower Back Center",
		PREVIEW_HIP_BONE,
		Vector3(0.0, 0.0, -1.0),
		STOW_LOWER_BACK_OFFSET_METERS
	)
	_append_hip_side_stow_anchors(anchors, actor, skeleton)
	return anchors

func _append_hip_side_stow_anchors(anchors: Array[Dictionary], actor: Node3D, skeleton: Skeleton3D) -> void:
	var plus_result: Dictionary = _resolve_stow_anchor_from_bone(
		skeleton,
		PREVIEW_HIP_BONE,
		Vector3(1.0, 0.0, 0.0),
		STOW_HIP_SIDE_OFFSET_METERS
	)
	var minus_result: Dictionary = _resolve_stow_anchor_from_bone(
		skeleton,
		PREVIEW_HIP_BONE,
		Vector3(-1.0, 0.0, 0.0),
		STOW_HIP_SIDE_OFFSET_METERS
	)
	if not bool(plus_result.get("ok", false)) or not bool(minus_result.get("ok", false)):
		return
	var right_world: Vector3 = actor.global_basis.x.normalized() if actor != null else Vector3.RIGHT
	var plus_direction_world: Vector3 = plus_result.get("direction_world", Vector3.RIGHT) as Vector3
	var plus_is_right: bool = plus_direction_world.dot(right_world) >= 0.0
	var left_result: Dictionary = minus_result if plus_is_right else plus_result
	var right_result: Dictionary = plus_result if plus_is_right else minus_result
	anchors.append({
		"id": CombatAnimationDraftScript.CONCRETE_STOW_HIP_L,
		"label": "Hip L",
		"position_world": left_result.get("position_world", Vector3.ZERO),
	})
	anchors.append({
		"id": CombatAnimationDraftScript.CONCRETE_STOW_HIP_R,
		"label": "Hip R",
		"position_world": right_result.get("position_world", Vector3.ZERO),
	})

func _append_stow_anchor_from_bone(
	anchors: Array[Dictionary],
	skeleton: Skeleton3D,
	anchor_id: StringName,
	anchor_label: String,
	bone_name: StringName,
	local_direction: Vector3,
	offset_meters: float
) -> void:
	var resolved_anchor: Dictionary = _resolve_stow_anchor_from_bone(
		skeleton,
		bone_name,
		local_direction,
		offset_meters
	)
	if not bool(resolved_anchor.get("ok", false)):
		return
	anchors.append({
		"id": anchor_id,
		"label": anchor_label,
		"position_world": resolved_anchor.get("position_world", Vector3.ZERO),
	})

func _resolve_stow_anchor_from_bone(
	skeleton: Skeleton3D,
	bone_name: StringName,
	local_direction: Vector3,
	offset_meters: float
) -> Dictionary:
	if skeleton == null or bone_name == StringName() or local_direction.length_squared() <= 0.000001:
		return {"ok": false}
	var bone_index: int = skeleton.find_bone(String(bone_name))
	if bone_index < 0:
		return {"ok": false}
	var bone_world_transform: Transform3D = _get_skeleton_bone_world_transform(skeleton, bone_name)
	var direction_world: Vector3 = (bone_world_transform.basis * local_direction.normalized()).normalized()
	if direction_world.length_squared() <= 0.000001:
		return {"ok": false}
	return {
		"ok": true,
		"position_world": bone_world_transform.origin + direction_world * maxf(offset_meters, 0.0),
		"direction_world": direction_world,
	}

func _create_stow_anchor_marker(
	marker_root: Node3D,
	local_position: Vector3,
	anchor_id: StringName,
	anchor_label: String,
	selected: bool
) -> void:
	var marker := MeshInstance3D.new()
	marker.name = "StowAnchorMarker_%s_%d" % [String(anchor_id), marker_root.get_child_count()]
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE * BEZIER_CONTROL_MARKER_SIZE_METERS
	marker.mesh = mesh
	marker.position = local_position
	marker.material_override = _build_surface_material(
		Color(1.0, 0.0, 0.92, 1.0) if selected else STOW_ANCHOR_MARKER_COLOR,
		0.38 if selected else 0.45
	)
	marker.set_meta("stow_anchor_selectable", true)
	marker.set_meta("stow_anchor_id", anchor_id)
	marker.set_meta("stow_anchor_label", anchor_label)
	marker.set_meta("stow_anchor_selected", selected)
	marker_root.add_child(marker)

func _is_noncombat_idle_draft(draft: Resource) -> bool:
	return (
		draft != null
		and StringName(draft.get("draft_kind")) == CombatAnimationDraftScript.DRAFT_KIND_IDLE
		and StringName(draft.get("context_id")) == CombatAnimationDraftScript.IDLE_CONTEXT_NONCOMBAT
	)

func _create_point_marker(marker_root: Node3D, local_position: Vector3, active: bool) -> void:
	var marker := MeshInstance3D.new()
	marker.name = "PointMarker_%d" % marker_root.get_child_count()
	var mesh := SphereMesh.new()
	mesh.radius = (0.022 if active else 0.016) * CONTROL_MARKER_SIZE_MULTIPLIER
	mesh.height = mesh.radius * 2.0
	marker.mesh = mesh
	marker.position = local_position
	marker.material_override = _build_overlay_surface_material(Color(1.0, 0.33, 0.24, 1.0) if active else Color(0.92, 0.92, 0.92, 1.0), 0.35)
	marker_root.add_child(marker)

func _create_handle_marker(marker_root: Node3D, local_position: Vector3, color: Color, prefix: String) -> void:
	var marker := MeshInstance3D.new()
	marker.name = "%sHandleMarker_%d" % [prefix, marker_root.get_child_count()]
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE * BEZIER_CONTROL_MARKER_SIZE_METERS
	marker.mesh = mesh
	marker.position = local_position
	marker.material_override = _build_surface_material(color, 0.45)
	marker_root.add_child(marker)

func _create_control_gizmo_marker(
	marker_root: Node3D,
	local_position: Vector3,
	color: Color,
	radius: float,
	prefix: String,
	extra_scale: float = 1.0
) -> void:
	var marker := MeshInstance3D.new()
	marker.name = "%sMarker_%d" % [prefix, marker_root.get_child_count()]
	var mesh := SphereMesh.new()
	mesh.radius = radius * CONTROL_MARKER_SIZE_MULTIPLIER * maxf(extra_scale, 0.0)
	mesh.height = mesh.radius * 2.0
	marker.mesh = mesh
	marker.position = local_position
	marker.material_override = _build_overlay_surface_material(color, 0.24)
	marker_root.add_child(marker)

func _create_line_gizmo_marker(marker_root: Node3D, start_local: Vector3, end_local: Vector3, color: Color, prefix: String) -> void:
	var marker := MeshInstance3D.new()
	marker.name = "%sLine_%d" % [prefix, marker_root.get_child_count()]
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	mesh.surface_set_color(color)
	mesh.surface_add_vertex(start_local)
	mesh.surface_set_color(color)
	mesh.surface_add_vertex(end_local)
	mesh.surface_end()
	marker.mesh = mesh
	marker.material_override = _build_line_material(color)
	marker_root.add_child(marker)

func _create_playback_marker(marker_root: Node3D, local_position: Vector3, color: Color, prefix: String) -> void:
	var marker := MeshInstance3D.new()
	marker.name = "%sMarker_%d" % [prefix, marker_root.get_child_count()]
	var mesh := SphereMesh.new()
	mesh.radius = 0.026 * CONTROL_MARKER_SIZE_MULTIPLIER
	mesh.height = mesh.radius * 2.0
	marker.mesh = mesh
	marker.position = local_position
	marker.material_override = _build_overlay_surface_material(color, 0.28)
	marker_root.add_child(marker)

func _refresh_live_playback_markers(state: Dictionary, playback_state: Dictionary) -> void:
	var marker_root: Node3D = state.get("marker_root", null) as Node3D
	if marker_root == null:
		return
	_update_live_playback_marker(
		marker_root,
		"PlaybackTipLiveMarker",
		_get_origin_tracked_vector3_state(
			playback_state,
			"tip_position_local",
			"tip_position_origin_id",
			Vector3.ZERO,
			CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING
		),
		Color(1.0, 0.78, 0.22, 1.0)
	)
	_update_live_playback_marker(
		marker_root,
		"PlaybackPommelLiveMarker",
		_get_origin_tracked_vector3_state(
			playback_state,
			"pommel_position_local",
			"pommel_position_origin_id",
			Vector3.ZERO,
			CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING
		),
		Color(0.56, 0.82, 1.0, 1.0)
	)

func _update_live_playback_marker(marker_root: Node3D, marker_name: String, local_position: Vector3, color: Color) -> void:
	var marker: MeshInstance3D = marker_root.get_node_or_null(marker_name) as MeshInstance3D
	if marker == null:
		marker = MeshInstance3D.new()
		marker.name = marker_name
		var mesh := SphereMesh.new()
		mesh.radius = 0.026 * CONTROL_MARKER_SIZE_MULTIPLIER
		mesh.height = mesh.radius * 2.0
		marker.mesh = mesh
		marker.material_override = _build_overlay_surface_material(color, 0.28)
		marker_root.add_child(marker)
	marker.position = local_position

func _set_preview_actor_collision_debug_visible(actor: Node3D, visible: bool) -> void:
	if actor == null:
		return
	actor.set("show_two_hand_grip_debug_markers", visible)
	if actor.has_method("sync_authoring_joint_range_debug_now"):
		actor.call("sync_authoring_joint_range_debug_now", visible)
	if actor.has_method("get_grip_solve_root"):
		var grip_solve_root: Node3D = actor.call("get_grip_solve_root") as Node3D
		if grip_solve_root != null:
			grip_solve_root.visible = visible
	var body_restriction_root: Node3D = _get_preview_actor_body_restriction_root(actor)
	if body_restriction_root == null:
		return
	for attachment_node: Node in body_restriction_root.get_children():
		var attachment: Node3D = attachment_node as Node3D
		if attachment == null:
			continue
		var debug_mesh: MeshInstance3D = attachment.get_node_or_null("RestrictionDebug") as MeshInstance3D
		if debug_mesh != null:
			debug_mesh.visible = visible

func _resolve_debugger_view_enabled(state: Dictionary, playback_state: Dictionary) -> bool:
	var preview_root: Node3D = state.get("preview_root", null) as Node3D
	var enabled: bool = bool(_get_node_meta_or_default(preview_root, DEBUGGER_VIEW_ENABLED_META, false))
	if playback_state.has(DEBUGGER_VIEW_ENABLED_META):
		enabled = bool(playback_state.get(DEBUGGER_VIEW_ENABLED_META, false))
	elif playback_state.has(String(DEBUGGER_VIEW_ENABLED_META)):
		enabled = bool(playback_state.get(String(DEBUGGER_VIEW_ENABLED_META), false))
	_apply_debugger_view_visibility(state, enabled)
	return enabled

func _apply_debugger_view_visibility(state: Dictionary, enabled: bool) -> void:
	var preview_root: Node3D = state.get("preview_root", null) as Node3D
	var actor_pivot: Node3D = state.get("actor_pivot", null) as Node3D
	if preview_root == null:
		return
	preview_root.set_meta(DEBUGGER_VIEW_ENABLED_META, enabled)
	var actor: Node3D = actor_pivot.get_node_or_null(PREVIEW_ACTOR_NAME) as Node3D if actor_pivot != null else null
	var held_item: Node3D = _get_node_meta_or_default(preview_root, "preview_held_item", null) as Node3D
	var visible: bool = enabled and held_item != null and is_instance_valid(held_item)
	_set_preview_actor_collision_debug_visible(actor, visible)
	_set_preview_weapon_collision_debug_visible(held_item, visible)
	if not visible:
		preview_root.set_meta("collision_debug_visual_count", 0)

func _set_preview_weapon_collision_debug_visible(held_item: Node3D, visible: bool) -> void:
	if held_item == null or not is_instance_valid(held_item):
		return
	_set_visible_mesh_children(
		held_item.get_node_or_null("PrimaryGripGuide/GripShellCenter/" + PREVIEW_GRIP_CONTACT_DEBUG_ROOT_NAME) as Node3D,
		visible
	)
	_set_visible_mesh_children(
		held_item.get_node_or_null("SecondaryGripGuide/GripShellCenter/" + PREVIEW_GRIP_CONTACT_DEBUG_ROOT_NAME) as Node3D,
		visible
	)
	_set_visible_mesh_children(
		held_item.get_node_or_null("WeaponBodyRestrictionProxy/" + PREVIEW_PROXY_DEBUG_ROOT_NAME) as Node3D,
		visible
	)
	_set_visible_mesh_children(held_item.get_node_or_null(PREVIEW_COLLISION_DEBUG_ROOT_NAME) as Node3D, visible)

func _set_visible_mesh_children(root: Node3D, visible: bool) -> void:
	if root == null:
		return
	root.visible = visible
	for child_node: Node in root.get_children():
		var debug_mesh: MeshInstance3D = child_node as MeshInstance3D
		if debug_mesh != null:
			debug_mesh.visible = visible

func _get_preview_actor_body_restriction_root(actor: Node3D) -> Node3D:
	if actor == null or not actor.has_method("get_body_restriction_root"):
		return null
	return actor.call("get_body_restriction_root") as Node3D

func _sync_preview_body_restriction_root(actor: Node3D, body_restriction_root: Node3D) -> void:
	if actor == null or body_restriction_root == null:
		return
	var skeleton: Skeleton3D = actor.get_node_or_null(PREVIEW_SKELETON_PATH) as Skeleton3D
	if skeleton == null:
		return
	hand_target_constraint_solver.sync_body_restriction_root(body_restriction_root, skeleton)

func _count_visible_body_restriction_debug_meshes(actor: Node3D) -> int:
	var body_restriction_root: Node3D = _get_preview_actor_body_restriction_root(actor)
	if body_restriction_root == null:
		return 0
	var visible_count: int = 0
	for attachment_node: Node in body_restriction_root.get_children():
		var attachment: Node3D = attachment_node as Node3D
		if attachment == null:
			continue
		var debug_mesh: MeshInstance3D = attachment.get_node_or_null("RestrictionDebug") as MeshInstance3D
		if debug_mesh != null and debug_mesh.visible:
			visible_count += 1
	return visible_count

func _sync_preview_weapon_bounds_debug(held_item: Node3D) -> int:
	if held_item == null:
		return 0
	var bounds_area: Area3D = held_item.get_node_or_null("WeaponBoundsArea") as Area3D
	if bounds_area == null:
		return 0
	var collision_shape: CollisionShape3D = bounds_area.get_node_or_null("WeaponBoundsShape") as CollisionShape3D
	var box_shape: BoxShape3D = null
	if collision_shape != null:
		box_shape = collision_shape.shape as BoxShape3D
	if box_shape == null:
		return 0
	var debug_root: Node3D = _ensure_preview_weapon_collision_debug_root(held_item)
	var debug_mesh: MeshInstance3D = debug_root.get_node_or_null(PREVIEW_WEAPON_BOUNDS_DEBUG_NAME) as MeshInstance3D
	if debug_mesh == null:
		debug_mesh = MeshInstance3D.new()
		debug_mesh.name = PREVIEW_WEAPON_BOUNDS_DEBUG_NAME
		debug_root.add_child(debug_mesh)
	var box_mesh: BoxMesh = debug_mesh.mesh as BoxMesh
	if box_mesh == null:
		box_mesh = BoxMesh.new()
		debug_mesh.mesh = box_mesh
	box_mesh.size = box_shape.size
	debug_mesh.position = collision_shape.position
	debug_mesh.material_override = _build_overlay_surface_material(Color(0.96, 0.96, 0.96, 0.12), 0.35)
	debug_mesh.visible = true
	return 1

func _hide_preview_weapon_bounds_debug(held_item: Node3D) -> void:
	if held_item == null:
		return
	var debug_root: Node3D = held_item.get_node_or_null(PREVIEW_COLLISION_DEBUG_ROOT_NAME) as Node3D
	if debug_root == null:
		return
	var debug_mesh: MeshInstance3D = debug_root.get_node_or_null(PREVIEW_WEAPON_BOUNDS_DEBUG_NAME) as MeshInstance3D
	if debug_mesh != null:
		debug_mesh.visible = false

func _sync_preview_grip_contact_debug(grip_guide: Node3D, debug_color: Color) -> int:
	if grip_guide == null:
		return 0
	var grip_center: Node3D = grip_guide.get_node_or_null("GripShellCenter") as Node3D
	if grip_center == null:
		return 0
	var grip_area: Area3D = grip_center.get_node_or_null("GripContactArea") as Area3D
	if grip_area == null:
		return 0
	var debug_root: Node3D = grip_center.get_node_or_null(PREVIEW_GRIP_CONTACT_DEBUG_ROOT_NAME) as Node3D
	if debug_root == null:
		debug_root = Node3D.new()
		debug_root.name = PREVIEW_GRIP_CONTACT_DEBUG_ROOT_NAME
		grip_center.add_child(debug_root)
	for child_node: Node in debug_root.get_children():
		var debug_mesh: MeshInstance3D = child_node as MeshInstance3D
		if debug_mesh != null:
			debug_mesh.visible = false
	var visible_count: int = 0
	for child_node: Node in grip_area.get_children():
		var collision_shape: CollisionShape3D = child_node as CollisionShape3D
		var box_shape: BoxShape3D = null
		if collision_shape != null:
			box_shape = collision_shape.shape as BoxShape3D
		if box_shape == null:
			continue
		var marker_name: String = "%s%d" % [PREVIEW_GRIP_CONTACT_DEBUG_PREFIX, visible_count]
		var debug_mesh: MeshInstance3D = debug_root.get_node_or_null(marker_name) as MeshInstance3D
		if debug_mesh == null:
			debug_mesh = MeshInstance3D.new()
			debug_mesh.name = marker_name
			debug_root.add_child(debug_mesh)
		var box_mesh: BoxMesh = debug_mesh.mesh as BoxMesh
		if box_mesh == null:
			box_mesh = BoxMesh.new()
			debug_mesh.mesh = box_mesh
		box_mesh.size = box_shape.size
		debug_mesh.position = collision_shape.position
		debug_mesh.material_override = _build_overlay_surface_material(debug_color, 0.22)
		debug_mesh.visible = true
		visible_count += 1
	return visible_count

func _sync_preview_weapon_proxy_debug(held_item: Node3D) -> int:
	if held_item == null:
		return 0
	var proxy_root: Node3D = held_item.get_node_or_null("WeaponBodyRestrictionProxy") as Node3D
	if proxy_root == null:
		return 0
	var debug_root: Node3D = proxy_root.get_node_or_null(PREVIEW_PROXY_DEBUG_ROOT_NAME) as Node3D
	if debug_root == null:
		debug_root = Node3D.new()
		debug_root.name = PREVIEW_PROXY_DEBUG_ROOT_NAME
		proxy_root.add_child(debug_root)
	for child_node: Node in debug_root.get_children():
		var debug_mesh: MeshInstance3D = child_node as MeshInstance3D
		if debug_mesh != null:
			debug_mesh.visible = false
	var visible_count: int = 0
	for child_node: Node in proxy_root.get_children():
		var sample_node: Node3D = child_node as Node3D
		if sample_node == null or not String(sample_node.name).begins_with("WeaponBodySample_"):
			continue
		var marker_name: String = "%s%d" % [PREVIEW_PROXY_DEBUG_MARKER_PREFIX, visible_count]
		var debug_mesh: MeshInstance3D = debug_root.get_node_or_null(marker_name) as MeshInstance3D
		if debug_mesh == null:
			debug_mesh = MeshInstance3D.new()
			debug_mesh.name = marker_name
			debug_root.add_child(debug_mesh)
		var sphere_mesh: SphereMesh = debug_mesh.mesh as SphereMesh
		if sphere_mesh == null:
			sphere_mesh = SphereMesh.new()
			debug_mesh.mesh = sphere_mesh
		sphere_mesh.radius = 0.014
		sphere_mesh.height = 0.028
		debug_mesh.position = sample_node.position
		debug_mesh.material_override = _build_overlay_surface_material(Color(1.0, 0.12, 0.75, 0.32), 0.12)
		debug_mesh.visible = true
		visible_count += 1
	return visible_count

func _ensure_preview_weapon_collision_debug_root(held_item: Node3D) -> Node3D:
	if held_item == null:
		return null
	var debug_root: Node3D = held_item.get_node_or_null(PREVIEW_COLLISION_DEBUG_ROOT_NAME) as Node3D
	if debug_root == null:
		debug_root = Node3D.new()
		debug_root.name = PREVIEW_COLLISION_DEBUG_ROOT_NAME
		held_item.add_child(debug_root)
	return debug_root

func _count_visible_mesh_children(root: Node3D) -> int:
	if root == null:
		return 0
	var visible_count: int = 0
	for child_node: Node in root.get_children():
		var debug_mesh: MeshInstance3D = child_node as MeshInstance3D
		if debug_mesh != null and debug_mesh.visible:
			visible_count += 1
	return visible_count

func _is_debug_mesh_visible(root: Node3D, child_name: String) -> bool:
	if root == null:
		return false
	var debug_mesh: MeshInstance3D = root.get_node_or_null(child_name) as MeshInstance3D
	return debug_mesh != null and debug_mesh.visible

func _build_line_material(albedo_color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.albedo_color = albedo_color
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material

func _build_surface_material(albedo_color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = albedo_color
	material.roughness = roughness
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	if albedo_color.a < 0.999:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material

func _build_overlay_surface_material(albedo_color: Color, roughness: float) -> StandardMaterial3D:
	var material: StandardMaterial3D = _build_surface_material(albedo_color, roughness)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.no_depth_test = true
	return material

func _ensure_trajectory_root_parent(preview_root: Node3D, trajectory_root: Node3D) -> void:
	if preview_root == null or trajectory_root == null:
		return
	if trajectory_root.get_parent() == preview_root:
		return
	var current_parent: Node = trajectory_root.get_parent()
	if current_parent != null:
		current_parent.remove_child(trajectory_root)
	preview_root.add_child(trajectory_root)
	trajectory_root.transform = Transform3D.IDENTITY

func _resolve_trajectory_authoring_transform(actor: Node3D) -> Transform3D:
	if actor == null:
		return Transform3D(Basis.IDENTITY, AUTHORING_ROOT_FALLBACK_LOCAL_OFFSET)
	return _resolve_preview_body_lock_frame(actor)

func _resolve_preview_body_lock_frame(actor: Node3D) -> Transform3D:
	if actor == null:
		return Transform3D(Basis.IDENTITY, AUTHORING_ROOT_FALLBACK_LOCAL_OFFSET)
	var skeleton: Skeleton3D = actor.get_node_or_null(PREVIEW_SKELETON_PATH) as Skeleton3D
	if skeleton != null and skeleton.find_bone(String(PREVIEW_ROOT_BONE)) >= 0:
		return _get_skeleton_bone_world_transform(skeleton, PREVIEW_ROOT_BONE)
	return Transform3D(actor.global_basis.orthonormalized(), actor.global_position)

func _resolve_preview_body_lock_frame_source(actor: Node3D) -> String:
	if actor == null:
		return "fallback"
	var skeleton: Skeleton3D = actor.get_node_or_null(PREVIEW_SKELETON_PATH) as Skeleton3D
	if skeleton != null and skeleton.find_bone(String(PREVIEW_ROOT_BONE)) >= 0:
		return String(PREVIEW_ROOT_BONE)
	return "actor_root"

func _resolve_preview_body_lock_frame_origin_id(actor: Node3D) -> StringName:
	var body_lock_source: String = _resolve_preview_body_lock_frame_source(actor)
	if body_lock_source == String(PREVIEW_ROOT_BONE):
		return CombatOriginRecordScript.ORIGIN_RL_BONE_ROOT
	return CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING

func _get_skeleton_bone_world_transform(skeleton: Skeleton3D, bone_name: StringName) -> Transform3D:
	if skeleton == null or bone_name == StringName():
		return Transform3D.IDENTITY
	var bone_index: int = skeleton.find_bone(String(bone_name))
	if bone_index < 0:
		return Transform3D.IDENTITY
	var bone_pose: Transform3D = skeleton.get_bone_global_pose(bone_index)
	var world_pose: Transform3D = skeleton.global_transform * bone_pose
	return Transform3D(world_pose.basis.orthonormalized(), world_pose.origin)

func _get_skeleton_bone_world_position(skeleton: Skeleton3D, bone_name: StringName) -> Vector3:
	if skeleton == null or bone_name == StringName():
		return Vector3.ZERO
	var bone_index: int = skeleton.find_bone(String(bone_name))
	if bone_index < 0:
		return Vector3.ZERO
	return skeleton.to_global(skeleton.get_bone_global_pose(bone_index).origin)

func _get_material_lookup() -> Dictionary:
	if material_lookup_cache.is_empty():
		material_lookup_cache = material_pipeline_service.build_base_material_lookup()
	return material_lookup_cache

func _get_node_meta_or_default(node: Object, key: StringName, default_value: Variant) -> Variant:
	if node == null or not node.has_meta(key):
		return default_value
	return node.get_meta(key)
