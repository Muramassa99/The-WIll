extends RefCounted
class_name PlayerRuntimeSkillPlaybackPresenter

const CombatAnimationChainPlayerScript = preload("res://runtime/combat/combat_animation_chain_player.gd")
const CombatAnimationStationPreviewPresenterScript = preload("res://runtime/combat/combat_animation_station_preview_presenter.gd")
const CombatAnimationStationStateScript = preload("res://core/models/combat_animation_station_state.gd")
const CombatAnimationMotionNodeScript = preload("res://core/models/combat_animation_motion_node.gd")
const CraftedItemWIPScript = preload("res://core/models/crafted_item_wip.gd")
const WeaponGripAnchorProviderScript = preload("res://runtime/player/weapon_grip_anchor_provider.gd")
const PlayerRuntimeHiddenBridgeStateScript = preload("res://runtime/player/player_runtime_hidden_bridge_state.gd")
const CombatAnimationRuntimeChainCompilerScript = preload("res://core/resolvers/combat_animation_runtime_chain_compiler.gd")
const CombatRuntimeClipScript = preload("res://core/models/combat_runtime_clip.gd")
const CombatRuntimeClipBakerScript = preload("res://core/resolvers/combat_runtime_clip_baker.gd")
const CombatAnimationWeaponFrameSolverScript = preload("res://runtime/combat/combat_animation_weapon_frame_solver.gd")
const CombatOriginRecordScript = preload("res://core/models/combat_origin_record.gd")

const ENTRY_BRIDGE_DURATION_SECONDS := 0.3
const RECOVERY_BRIDGE_DURATION_SECONDS := 1.2
const DRAW_BRIDGE_DURATION_SECONDS := 0.3
const STOW_BRIDGE_DURATION_SECONDS := 1.2
const DEFAULT_COMBAT_IDLE_EXPIRY_SECONDS := 15.0
const NO_OP_BRIDGE_DURATION_SECONDS := 0.01
const MOTION_NODE_POSITION_EPSILON_METERS := 0.005
const MOTION_NODE_ANGLE_EPSILON_DEGREES := 0.5
const MOTION_NODE_FLOAT_EPSILON := 0.01
const RUNTIME_ENDPOINT_AUTHORITY_ROOT_NAME := "RuntimeCombatEndpointAuthorityRoot"
const RUNTIME_ENDPOINT_AUTHORITY_ACTIVE_META := "runtime_endpoint_authority_active"
const RUNTIME_ENDPOINT_AUTHORITY_ORIGIN_META := "runtime_endpoint_authority_origin_id"
const RUNTIME_ENDPOINT_AUTHORITY_PREVIOUS_ORIGIN_META := "runtime_endpoint_authority_previous_origin_id"
const RUNTIME_SOLVED_REPLAY_REFERENCE_BONE := &"RL_BoneRoot"

var chain_player: CombatAnimationChainPlayer = CombatAnimationChainPlayerScript.new()
var idle_chain_player: CombatAnimationChainPlayer = CombatAnimationChainPlayerScript.new()
var live_pose_presenter: CombatAnimationStationPreviewPresenter = CombatAnimationStationPreviewPresenterScript.new()
var weapon_grip_anchor_provider = WeaponGripAnchorProviderScript.new()
var hidden_bridge_state = PlayerRuntimeHiddenBridgeStateScript.new()
var runtime_chain_compiler = CombatAnimationRuntimeChainCompilerScript.new()
var runtime_clip_baker = CombatRuntimeClipBakerScript.new()
var weapon_frame_solver: CombatAnimationWeaponFrameSolver = CombatAnimationWeaponFrameSolverScript.new()

var active_runtime_skill_result: Dictionary = {}
var active_motion_node_chain: Array = []
var active_dominant_slot_id: StringName = StringName()
var active_support_slot_id: StringName = StringName()
var active_default_two_hand: bool = false
var active_weapons_drawn: bool = true
var active_baseline_local_transform: Transform3D = Transform3D.IDENTITY
var active_baseline_transform_origin_id: StringName = CombatOriginRecordScript.ORIGIN_HAND_GRIP_ALIGNMENT
var active_baseline_transform_valid: bool = false
var playback_finished_pending: bool = false
var runtime_playback_active: bool = false
var last_runtime_pose_state: Dictionary = {}
var active_runtime_clip = null
var active_runtime_idle_result: Dictionary = {}
var active_idle_motion_node_chain: Array = []
var active_idle_dominant_slot_id: StringName = StringName()
var active_idle_support_slot_id: StringName = StringName()
var active_idle_default_two_hand: bool = false
var active_idle_source_key: String = ""
var runtime_idle_active: bool = false
var last_runtime_idle_pose_state: Dictionary = {}
var active_idle_runtime_clip = null
var pending_recovery_motion_node: CombatAnimationMotionNode = null
var pending_recovery_dominant_slot_id: StringName = StringName()
var active_idle_recovery_bridge_active: bool = false
var active_trajectory_volume_config: Dictionary = {}
var active_idle_trajectory_volume_config: Dictionary = {}
var last_entry_bridge_active: bool = false
var last_entry_bridge_duration_seconds: float = 0.0
var last_entry_grip_swap_active: bool = false
var last_entry_hand_swap_active: bool = false
var last_entry_source_grip_style_mode: StringName = StringName()
var last_entry_target_grip_style_mode: StringName = StringName()
var last_recovery_bridge_active: bool = false
var last_recovery_bridge_duration_seconds: float = 0.0
var last_recovery_grip_swap_active: bool = false
var last_recovery_hand_swap_active: bool = false
var last_recovery_source_grip_style_mode: StringName = StringName()
var last_recovery_target_grip_style_mode: StringName = StringName()
var combat_idle_expiry_seconds: float = DEFAULT_COMBAT_IDLE_EXPIRY_SECONDS
var combat_idle_elapsed_seconds: float = 0.0
var combat_idle_expired_pending: bool = false
var combat_action_generation: int = 0

func _init() -> void:
	chain_player.playback_finished.connect(_on_chain_playback_finished)

func _resolve_origin_meta_value(target: Object, meta_name: String, fallback_origin_id: StringName) -> StringName:
	var resolved_origin_id: StringName = fallback_origin_id
	if resolved_origin_id == StringName():
		resolved_origin_id = CombatOriginRecordScript.ORIGIN_RL_BONE_ROOT
	if target == null:
		return resolved_origin_id
	var origin_id: StringName = StringName(target.get_meta(meta_name, StringName()))
	if origin_id != StringName():
		return origin_id
	target.set_meta(meta_name, resolved_origin_id)
	return resolved_origin_id

func _get_origin_tracked_vector3_meta(
	target: Object,
	value_meta_name: String,
	origin_meta_name: String,
	fallback_value: Vector3,
	fallback_origin_id: StringName
) -> Vector3:
	_resolve_origin_meta_value(target, origin_meta_name, fallback_origin_id)
	if target == null or not target.has_meta(value_meta_name):
		return fallback_value
	var value: Variant = target.get_meta(value_meta_name)
	if value is Vector3:
		return value as Vector3
	return fallback_value

func _has_origin_tracked_vector3_meta(
	target: Object,
	value_meta_name: String,
	origin_meta_name: String,
	fallback_origin_id: StringName
) -> bool:
	_resolve_origin_meta_value(target, origin_meta_name, fallback_origin_id)
	return target != null and target.has_meta(value_meta_name)

func _resolve_origin_id_from_state(state: Dictionary, origin_key: String, fallback_origin_id: StringName) -> StringName:
	var resolved_origin_id: StringName = fallback_origin_id
	if resolved_origin_id == StringName():
		resolved_origin_id = CombatOriginRecordScript.ORIGIN_RL_BONE_ROOT
	if state.has(origin_key):
		var state_origin_id: StringName = StringName(state.get(origin_key, StringName()))
		if state_origin_id != StringName():
			return state_origin_id
	state[origin_key] = resolved_origin_id
	return resolved_origin_id

func _get_origin_tracked_vector3_state(
	state: Dictionary,
	value_key: String,
	origin_key: String,
	fallback_value: Vector3,
	fallback_origin_id: StringName
) -> Vector3:
	_resolve_origin_id_from_state(state, origin_key, fallback_origin_id)
	var value: Variant = state.get(value_key, fallback_value)
	if value is Vector3:
		return value as Vector3
	state[value_key] = fallback_value
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

func _get_preview_primary_grip_seat_meta(held_item: Object) -> Vector3:
	return _get_origin_tracked_vector3_meta(
		held_item,
		"preview_primary_grip_seat_local",
		"preview_primary_grip_seat_origin_id",
		Vector3.ZERO,
		CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
	)

func is_playing() -> bool:
	return runtime_playback_active

func set_combat_idle_expiry_seconds(value: float) -> void:
	combat_idle_expiry_seconds = maxf(value, 0.0)
	if combat_idle_expiry_seconds <= 0.0:
		combat_idle_elapsed_seconds = 0.0
		combat_idle_expired_pending = false

func mark_combat_action_used() -> void:
	combat_action_generation += 1
	combat_idle_elapsed_seconds = 0.0
	combat_idle_expired_pending = false

func begin_draw_bridge(slot_id: StringName = StringName()) -> void:
	hidden_bridge_state.begin(
		PlayerRuntimeHiddenBridgeStateScript.KIND_DRAW_TO_COMBAT_IDLE,
		DRAW_BRIDGE_DURATION_SECONDS,
		slot_id,
		CombatAnimationStationStateScript.IDLE_CONTEXT_NONCOMBAT,
		CombatAnimationStationStateScript.IDLE_CONTEXT_COMBAT
	)
	combat_idle_elapsed_seconds = 0.0
	combat_idle_expired_pending = false

func get_debug_state() -> Dictionary:
	return {
		"active": runtime_playback_active,
		"dominant_slot_id": active_dominant_slot_id,
		"support_slot_id": active_support_slot_id,
		"default_two_hand": active_default_two_hand,
		"motion_node_count": active_motion_node_chain.size(),
		"runtime_clip_active": active_runtime_clip != null and active_runtime_clip.is_playable(),
		"runtime_clip_debug_state": _build_runtime_clip_debug_state(active_runtime_clip),
		"playback_finished_pending": playback_finished_pending,
		"last_runtime_pose_state": last_runtime_pose_state.duplicate(true),
		"source_weapon_wip_id": active_runtime_skill_result.get("source_weapon_wip_id", StringName()),
		"source_skill_draft_id": active_runtime_skill_result.get("source_skill_draft_id", StringName()),
		"runtime_compile_diagnostics": active_runtime_skill_result.get("runtime_compile_diagnostics", []),
		"runtime_compile_degraded_node_count": active_runtime_skill_result.get("runtime_compile_degraded_node_count", 0),
		"runtime_compile_hand_swap_bridge_count": active_runtime_skill_result.get("runtime_compile_hand_swap_bridge_count", 0),
		"runtime_compile_retargeted_count": active_runtime_skill_result.get("runtime_compile_retargeted_count", 0),
		"entry_bridge_active": last_entry_bridge_active,
		"entry_bridge_duration_seconds": last_entry_bridge_duration_seconds,
		"entry_grip_swap_active": last_entry_grip_swap_active,
		"entry_hand_swap_active": last_entry_hand_swap_active,
		"entry_source_grip_style_mode": last_entry_source_grip_style_mode,
		"entry_target_grip_style_mode": last_entry_target_grip_style_mode,
		"trajectory_volume_enabled": bool(active_trajectory_volume_config.get("enabled", false)),
		"idle_active": runtime_idle_active,
		"idle_dominant_slot_id": active_idle_dominant_slot_id,
		"idle_source_key": active_idle_source_key,
		"last_runtime_idle_pose_state": last_runtime_idle_pose_state.duplicate(true),
		"recovery_bridge_active": last_recovery_bridge_active,
		"recovery_bridge_duration_seconds": last_recovery_bridge_duration_seconds,
		"recovery_grip_swap_active": last_recovery_grip_swap_active,
		"recovery_hand_swap_active": last_recovery_hand_swap_active,
		"recovery_source_grip_style_mode": last_recovery_source_grip_style_mode,
		"recovery_target_grip_style_mode": last_recovery_target_grip_style_mode,
		"hidden_bridge_state": hidden_bridge_state.to_debug_state(),
		"combat_idle_expiry_seconds": combat_idle_expiry_seconds,
		"combat_idle_elapsed_seconds": combat_idle_elapsed_seconds,
		"combat_idle_expired_pending": combat_idle_expired_pending,
		"combat_action_generation": combat_action_generation,
	}

func get_idle_debug_state() -> Dictionary:
	return {
		"active": runtime_idle_active,
		"dominant_slot_id": active_idle_dominant_slot_id,
		"support_slot_id": active_idle_support_slot_id,
		"default_two_hand": active_idle_default_two_hand,
		"motion_node_count": active_idle_motion_node_chain.size(),
		"runtime_clip_active": active_idle_runtime_clip != null and active_idle_runtime_clip.is_playable(),
		"runtime_clip_debug_state": _build_runtime_clip_debug_state(active_idle_runtime_clip),
		"source_key": active_idle_source_key,
		"last_runtime_idle_pose_state": last_runtime_idle_pose_state.duplicate(true),
		"source_weapon_wip_id": active_runtime_idle_result.get("source_weapon_wip_id", StringName()),
		"source_idle_draft_id": active_runtime_idle_result.get("draft_id", StringName()),
		"runtime_compile_diagnostics": active_runtime_idle_result.get("runtime_compile_diagnostics", []),
		"runtime_compile_degraded_node_count": active_runtime_idle_result.get("runtime_compile_degraded_node_count", 0),
		"runtime_compile_hand_swap_bridge_count": active_runtime_idle_result.get("runtime_compile_hand_swap_bridge_count", 0),
		"runtime_compile_retarget_seeded_count": active_runtime_idle_result.get("runtime_compile_retarget_seeded_count", 0),
		"runtime_compile_retargeted_count": active_runtime_idle_result.get("runtime_compile_retargeted_count", 0),
		"runtime_compile_source_node_count": active_runtime_idle_result.get("runtime_compile_source_node_count", 0),
		"runtime_compile_effective_node_count": active_runtime_idle_result.get("runtime_compile_effective_node_count", 0),
		"recovery_bridge_active": active_idle_recovery_bridge_active,
		"recovery_bridge_duration_seconds": last_recovery_bridge_duration_seconds,
		"recovery_grip_swap_active": last_recovery_grip_swap_active,
		"recovery_hand_swap_active": last_recovery_hand_swap_active,
		"recovery_source_grip_style_mode": last_recovery_source_grip_style_mode,
		"recovery_target_grip_style_mode": last_recovery_target_grip_style_mode,
		"trajectory_volume_enabled": bool(active_idle_trajectory_volume_config.get("enabled", false)),
		"hidden_bridge_state": hidden_bridge_state.to_debug_state(),
		"combat_idle_expiry_seconds": combat_idle_expiry_seconds,
		"combat_idle_elapsed_seconds": combat_idle_elapsed_seconds,
		"combat_idle_expired_pending": combat_idle_expired_pending,
		"combat_action_generation": combat_action_generation,
	}

func start_playback(
	slot_activation_result: Dictionary,
	humanoid_rig: Node3D,
	held_item_nodes: Dictionary,
	equipped_item_presenter: PlayerEquippedItemPresenter,
	equipment_state,
	weapons_drawn: bool
) -> Dictionary:
	var result := {
		"started": false,
		"message": "",
		"dominant_slot_id": StringName(),
	}
	if not bool(slot_activation_result.get("success", false)):
		result["message"] = String(slot_activation_result.get("message", "Skill activation data is unavailable."))
		return result
	var authored_motion_node_chain: Array = slot_activation_result.get("motion_node_chain", []) as Array
	if authored_motion_node_chain.size() < 2:
		result["message"] = "A runtime skill needs at least 2 motion nodes."
		return result
	var dominant_slot_id: StringName = _resolve_source_equipment_slot_id(slot_activation_result, equipment_state)
	if dominant_slot_id == StringName():
		result["message"] = "The equipped slot for this authored skill could not be resolved."
		return result
	var held_item: Node3D = held_item_nodes.get(dominant_slot_id) as Node3D
	if held_item == null or not is_instance_valid(held_item):
		result["message"] = "The equipped weapon visual for this authored skill is not available."
		return result
	var support_slot_id: StringName = _resolve_other_hand_slot_id(dominant_slot_id)
	var default_two_hand: bool = _resolve_default_two_hand_for_support_slot(held_item, held_item_nodes, support_slot_id)
	var support_hand_available: bool = _resolve_support_hand_available_for_item(held_item, held_item_nodes, support_slot_id)
	var trajectory_volume_config: Dictionary = _resolve_runtime_trajectory_volume_config(humanoid_rig, held_item, dominant_slot_id)
	var compile_result: Dictionary = runtime_chain_compiler.compile_skill_chain(
		authored_motion_node_chain,
		_resolve_held_item_weapon_length_meters(held_item),
		trajectory_volume_config,
		{
			"support_hand_available": support_hand_available,
			"two_hand_allowed": default_two_hand and support_hand_available,
			"dominant_slot_id": dominant_slot_id,
			"support_slot_id": support_slot_id,
		}
	)
	if not bool(compile_result.get("compiled", false)):
		result["message"] = "Runtime equipment compilation did not produce a playable motion chain."
		result["runtime_compile_diagnostics"] = compile_result.get("diagnostics", [])
		return result
	var motion_node_chain: Array = compile_result.get("motion_node_chain", []) as Array
	var cached_authored_runtime_clip = _resolve_cached_runtime_clip(slot_activation_result)
	var bridge_source_snapshot: Dictionary = _capture_runtime_solved_replay_bridge_snapshot(
		humanoid_rig,
		held_item,
		cached_authored_runtime_clip
	)
	var inherited_start_node: CombatAnimationMotionNode = _capture_current_motion_node_for_slot(
		dominant_slot_id,
		motion_node_chain[0] as CombatAnimationMotionNode
	)
	var was_runtime_playback_active: bool = runtime_playback_active
	if runtime_idle_active:
		clear_idle_pose(humanoid_rig, equipped_item_presenter, held_item_nodes, equipment_state, weapons_drawn, true)
	if runtime_playback_active:
		stop_playback(humanoid_rig, held_item_nodes, equipped_item_presenter, equipment_state, weapons_drawn, false, false)

	active_runtime_skill_result = slot_activation_result.duplicate(true)
	_store_runtime_compile_debug(active_runtime_skill_result, compile_result)
	var prepared_chain_result: Dictionary = _build_runtime_chain_with_entry(
		motion_node_chain,
		inherited_start_node,
		ENTRY_BRIDGE_DURATION_SECONDS,
		1
	)
	active_motion_node_chain = prepared_chain_result.get("motion_node_chain", []) as Array
	if active_motion_node_chain.size() < 2:
		result["message"] = "Runtime skill entry preparation did not produce a playable motion chain."
		return result
	active_dominant_slot_id = dominant_slot_id
	active_support_slot_id = support_slot_id
	active_default_two_hand = default_two_hand
	active_weapons_drawn = weapons_drawn
	active_baseline_local_transform = held_item.transform
	active_baseline_transform_origin_id = _normalize_baseline_transform_origin_id(
		_resolve_runtime_endpoint_previous_origin_id(held_item)
	)
	active_baseline_transform_valid = true
	active_trajectory_volume_config = trajectory_volume_config
	_claim_runtime_endpoint_authority(humanoid_rig, held_item)
	mark_combat_action_used()
	_apply_entry_bridge_debug(prepared_chain_result)
	_begin_entry_hidden_bridge(prepared_chain_result, active_dominant_slot_id, was_runtime_playback_active, slot_activation_result)
	playback_finished_pending = false
	runtime_playback_active = true
	if humanoid_rig != null and humanoid_rig.has_method("set_upper_body_authoring_auto_apply_enabled"):
		humanoid_rig.call("set_upper_body_authoring_auto_apply_enabled", false)

	var draft: CombatAnimationDraft = slot_activation_result.get("source_skill_draft", null) as CombatAnimationDraft
	var playback_speed: float = draft.preview_playback_speed_scale if draft != null else 1.0
	var should_loop: bool = draft.preview_loop_enabled if draft != null else false
	active_runtime_clip = _bake_runtime_playback_clip(
		active_motion_node_chain,
		{
			"clip_kind": CombatRuntimeClipScript.CLIP_KIND_SKILL_PLAYBACK,
			"source_draft_id": slot_activation_result.get("source_skill_draft_id", StringName()),
			"source_skill_slot_id": slot_activation_result.get("slot_id", StringName()),
			"source_equipment_slot_id": active_dominant_slot_id,
			"source_weapon_wip_id": slot_activation_result.get("source_weapon_wip_id", StringName()),
			"source_weapon_length_meters": _resolve_held_item_weapon_length_meters(held_item),
			"playback_speed_scale": playback_speed,
			"loop_enabled": should_loop,
			"trajectory_volume_config": active_trajectory_volume_config,
			"compile_diagnostics": active_runtime_skill_result.get("runtime_compile_diagnostics", []),
			"degraded_node_count": active_runtime_skill_result.get("runtime_compile_degraded_node_count", 0),
			"hand_swap_bridge_count": active_runtime_skill_result.get("runtime_compile_hand_swap_bridge_count", 0),
			"retargeted_count": active_runtime_skill_result.get("runtime_compile_retargeted_count", 0),
		}
	)
	var cached_pose_track_applied: bool = _copy_cached_upper_body_pose_track(
		active_runtime_clip,
		cached_authored_runtime_clip,
		float(prepared_chain_result.get("entry_bridge_duration_seconds", 0.0)),
		bridge_source_snapshot
	)
	active_runtime_skill_result["cached_runtime_clip_upper_body_pose_track"] = cached_pose_track_applied
	if active_runtime_clip != null and active_runtime_clip.is_playable():
		active_motion_node_chain = active_runtime_clip.motion_node_chain
		active_runtime_skill_result["runtime_clip_baked"] = true
		active_runtime_skill_result["runtime_clip_frame_count"] = active_runtime_clip.get_frame_count()
		active_runtime_skill_result["runtime_clip_duration_seconds"] = active_runtime_clip.total_duration_seconds
	else:
		active_runtime_skill_result["runtime_clip_baked"] = false
	if active_runtime_clip != null and active_runtime_clip.is_playable() and chain_player.has_method("prepare_runtime_clip"):
		chain_player.prepare_runtime_clip(active_runtime_clip, playback_speed, should_loop)
	else:
		var tip_curve: Curve3D = _build_tip_curve(active_motion_node_chain)
		var pommel_curve: Curve3D = _build_pommel_curve(active_motion_node_chain)
		chain_player.prepare(active_motion_node_chain, tip_curve, pommel_curve, playback_speed, should_loop, active_trajectory_volume_config)
	chain_player.start()
	if equipped_item_presenter != null:
		equipped_item_presenter.sync_rig_weapon_guidance(
			humanoid_rig,
			held_item_nodes,
			active_weapons_drawn,
			equipment_state
		)
	last_runtime_pose_state = _apply_current_runtime_pose(humanoid_rig, held_item_nodes)
	result["started"] = true
	result["dominant_slot_id"] = active_dominant_slot_id
	result["message"] = "Runtime skill playback started."
	return result

func advance_playback(delta: float, humanoid_rig: Node3D, held_item_nodes: Dictionary) -> Dictionary:
	hidden_bridge_state.advance(delta)
	if not runtime_playback_active:
		return {}
	var held_item: Node3D = held_item_nodes.get(active_dominant_slot_id) as Node3D
	if held_item == null or not is_instance_valid(held_item):
		playback_finished_pending = true
	else:
		chain_player.advance(delta)
		last_runtime_pose_state = _apply_current_runtime_pose(humanoid_rig, held_item_nodes)
	var result: Dictionary = last_runtime_pose_state.duplicate(true)
	result["active"] = runtime_playback_active
	result["finished"] = playback_finished_pending
	result["dominant_slot_id"] = active_dominant_slot_id
	return result

func apply_idle_pose(
	delta: float,
	idle_pose_result: Dictionary,
	humanoid_rig: Node3D,
	held_item_nodes: Dictionary,
	equipped_item_presenter: PlayerEquippedItemPresenter,
	equipment_state,
	weapons_drawn: bool
) -> Dictionary:
	var result := {
		"applied": false,
		"active": runtime_idle_active,
		"message": "",
	}
	if runtime_playback_active:
		result["message"] = "Runtime skill playback is active; authored idle is waiting."
		return result
	if not bool(idle_pose_result.get("success", false)):
		clear_idle_pose(humanoid_rig, equipped_item_presenter, held_item_nodes, equipment_state, weapons_drawn)
		result["message"] = String(idle_pose_result.get("message", "No authored idle pose is available."))
		return result
	if bool(idle_pose_result.get("stowed_presentation", false)) or not weapons_drawn:
		clear_idle_pose(humanoid_rig, equipped_item_presenter, held_item_nodes, equipment_state, weapons_drawn)
		combat_idle_elapsed_seconds = 0.0
		combat_idle_expired_pending = false
		result["stowed_presentation"] = true
		result["hands_interact_with_weapon"] = false
		result["dominant_slot_id"] = idle_pose_result.get("source_equipment_slot_id", StringName())
		result["idle_context_id"] = idle_pose_result.get("idle_context_id", StringName())
		result["hidden_bridge_state"] = hidden_bridge_state.to_debug_state()
		result["combat_idle_elapsed_seconds"] = combat_idle_elapsed_seconds
		result["combat_idle_expired_pending"] = combat_idle_expired_pending
		result["message"] = String(idle_pose_result.get(
			"message",
			"Noncombat idle uses stowed weapon presentation; hand-contact idle is not applied."
		))
		return result
	var motion_node_chain: Array = idle_pose_result.get("motion_node_chain", []) as Array
	if motion_node_chain.is_empty():
		clear_idle_pose(humanoid_rig, equipped_item_presenter, held_item_nodes, equipment_state, weapons_drawn)
		result["message"] = "The authored idle pose has no motion nodes."
		return result
	var dominant_slot_id: StringName = idle_pose_result.get("source_equipment_slot_id", StringName()) as StringName
	if dominant_slot_id == StringName():
		clear_idle_pose(humanoid_rig, equipped_item_presenter, held_item_nodes, equipment_state, weapons_drawn)
		result["message"] = "The authored idle pose has no equipped weapon slot."
		return result
	var held_item: Node3D = held_item_nodes.get(dominant_slot_id) as Node3D
	if held_item == null or not is_instance_valid(held_item):
		clear_idle_pose(humanoid_rig, equipped_item_presenter, held_item_nodes, equipment_state, weapons_drawn)
		result["message"] = "The authored idle weapon visual is not available."
		return result
	var current_weapon_length_meters: float = _resolve_held_item_weapon_length_meters(held_item)
	var idle_source_key: String = _build_idle_source_key(idle_pose_result, dominant_slot_id, motion_node_chain, current_weapon_length_meters)
	if not runtime_idle_active or active_idle_source_key != idle_source_key:
		_start_idle_pose(idle_pose_result, motion_node_chain, dominant_slot_id, held_item, held_item_nodes, humanoid_rig)
		if equipped_item_presenter != null:
			equipped_item_presenter.sync_rig_weapon_guidance(
				humanoid_rig,
				held_item_nodes,
				weapons_drawn,
				equipment_state
			)
	elif idle_chain_player.is_playing():
		idle_chain_player.advance(delta)
	elif active_idle_recovery_bridge_active:
		_start_steady_idle_pose_after_recovery(idle_pose_result, motion_node_chain, dominant_slot_id, held_item, held_item_nodes, humanoid_rig)
	last_runtime_idle_pose_state = _apply_current_idle_pose(humanoid_rig, held_item_nodes)
	result = last_runtime_idle_pose_state.duplicate(true)
	result["applied"] = not last_runtime_idle_pose_state.is_empty()
	result["active"] = runtime_idle_active
	result["dominant_slot_id"] = active_idle_dominant_slot_id
	result["idle_context_id"] = idle_pose_result.get("idle_context_id", StringName())
	_apply_combat_idle_expiry(delta, idle_pose_result, result)
	result["hidden_bridge_state"] = hidden_bridge_state.to_debug_state()
	result["combat_idle_elapsed_seconds"] = combat_idle_elapsed_seconds
	result["combat_idle_expired_pending"] = combat_idle_expired_pending
	result["message"] = "Authored idle pose applied." if bool(result.get("applied", false)) else "Authored idle pose could not be applied."
	return result

func clear_idle_pose(
	humanoid_rig: Node3D,
	equipped_item_presenter: PlayerEquippedItemPresenter = null,
	held_item_nodes: Dictionary = {},
	equipment_state = null,
	weapons_drawn: bool = true,
	preserve_authoring_authority: bool = false
) -> void:
	if not runtime_idle_active and active_idle_dominant_slot_id == StringName():
		_clear_pending_recovery_state()
		if not preserve_authoring_authority:
			_clear_runtime_solved_replay_pose(humanoid_rig)
			if humanoid_rig != null and humanoid_rig.has_method("clear_upper_body_authoring_state"):
				humanoid_rig.call("clear_upper_body_authoring_state")
			if humanoid_rig != null and humanoid_rig.has_method("set_upper_body_authoring_auto_apply_enabled") and not runtime_playback_active:
				humanoid_rig.call("set_upper_body_authoring_auto_apply_enabled", true)
		return
	idle_chain_player.stop()
	active_runtime_idle_result = {}
	active_idle_motion_node_chain.clear()
	active_idle_runtime_clip = null
	active_idle_dominant_slot_id = StringName()
	active_idle_support_slot_id = StringName()
	active_idle_default_two_hand = false
	active_idle_source_key = ""
	runtime_idle_active = false
	active_idle_recovery_bridge_active = false
	last_runtime_idle_pose_state = {}
	active_idle_trajectory_volume_config = {}
	_clear_pending_recovery_state()
	if humanoid_rig != null and humanoid_rig.has_method("clear_upper_body_authoring_state") and not preserve_authoring_authority:
		humanoid_rig.call("clear_upper_body_authoring_state")
	if not preserve_authoring_authority:
		_clear_runtime_solved_replay_pose(humanoid_rig)
	if humanoid_rig != null and humanoid_rig.has_method("set_upper_body_authoring_auto_apply_enabled") and not runtime_playback_active and not preserve_authoring_authority:
		humanoid_rig.call("set_upper_body_authoring_auto_apply_enabled", true)
	if equipped_item_presenter != null and not preserve_authoring_authority:
		_release_runtime_endpoint_authority(
			humanoid_rig,
			held_item_nodes,
			equipped_item_presenter,
			equipment_state,
			weapons_drawn
		)
		equipped_item_presenter.sync_rig_weapon_guidance(
			humanoid_rig,
			held_item_nodes,
			weapons_drawn,
			equipment_state
		)

func stop_playback(
	humanoid_rig: Node3D,
	held_item_nodes: Dictionary,
	equipped_item_presenter: PlayerEquippedItemPresenter,
	equipment_state,
	weapons_drawn: bool,
	restore_baseline_transform: bool = true,
	preserve_recovery_state: bool = true
) -> void:
	if not runtime_playback_active and active_dominant_slot_id == StringName():
		return
	var held_item: Node3D = held_item_nodes.get(active_dominant_slot_id) as Node3D
	var preserve_recovery_authority: bool = preserve_recovery_state and playback_finished_pending and runtime_playback_active
	if preserve_recovery_authority:
		var recovery_fallback_node: CombatAnimationMotionNode = null
		if not active_motion_node_chain.is_empty():
			recovery_fallback_node = active_motion_node_chain[0] as CombatAnimationMotionNode
		pending_recovery_motion_node = _capture_current_motion_node_for_slot(
			active_dominant_slot_id,
			recovery_fallback_node
		)
		pending_recovery_dominant_slot_id = active_dominant_slot_id
	else:
		_clear_pending_recovery_state()
	if humanoid_rig != null and humanoid_rig.has_method("clear_upper_body_authoring_state") and not preserve_recovery_authority:
		humanoid_rig.call("clear_upper_body_authoring_state")
	if not preserve_recovery_authority:
		_clear_runtime_solved_replay_pose(humanoid_rig)
	if humanoid_rig != null and humanoid_rig.has_method("set_upper_body_authoring_auto_apply_enabled") and not preserve_recovery_authority:
		humanoid_rig.call("set_upper_body_authoring_auto_apply_enabled", true)
	if equipped_item_presenter != null and not preserve_recovery_authority:
		_release_runtime_endpoint_authority(
			humanoid_rig,
			held_item_nodes,
			equipped_item_presenter,
			equipment_state,
			weapons_drawn
		)
	if restore_baseline_transform and not preserve_recovery_authority and held_item != null and is_instance_valid(held_item) and active_baseline_transform_valid:
		active_baseline_transform_origin_id = _normalize_baseline_transform_origin_id(active_baseline_transform_origin_id)
		held_item.transform = active_baseline_local_transform
	if equipped_item_presenter != null and not preserve_recovery_authority:
		equipped_item_presenter.sync_rig_weapon_guidance(
			humanoid_rig,
			held_item_nodes,
			weapons_drawn,
			equipment_state
		)
	chain_player.stop()
	active_runtime_skill_result = {}
	active_motion_node_chain.clear()
	active_runtime_clip = null
	active_dominant_slot_id = StringName()
	active_support_slot_id = StringName()
	active_default_two_hand = false
	active_weapons_drawn = weapons_drawn
	active_baseline_local_transform = Transform3D.IDENTITY
	active_baseline_transform_origin_id = CombatOriginRecordScript.ORIGIN_HAND_GRIP_ALIGNMENT
	active_baseline_transform_valid = false
	active_trajectory_volume_config = {}
	playback_finished_pending = false
	runtime_playback_active = false

func _apply_current_runtime_pose(humanoid_rig: Node3D, held_item_nodes: Dictionary) -> Dictionary:
	var held_item: Node3D = held_item_nodes.get(active_dominant_slot_id) as Node3D
	if humanoid_rig == null or held_item == null or not is_instance_valid(held_item):
		return last_runtime_pose_state.duplicate(true)
	var support_requested: bool = _resolve_support_hand_requested(held_item, held_item_nodes)
	var effective_motion_node: CombatAnimationMotionNode = _build_effective_motion_node(support_requested)
	var playback_state: Dictionary = _build_playback_state()
	if active_runtime_clip != null and active_runtime_clip.is_playable():
		return _apply_contact_group_runtime_clip_pose(
			humanoid_rig,
			held_item_nodes,
			held_item,
			effective_motion_node,
			playback_state,
			active_dominant_slot_id,
			active_support_slot_id,
			support_requested
		)
	var resolved_pose_state: Dictionary = live_pose_presenter.apply_runtime_authored_weapon_pose(
		humanoid_rig,
		held_item,
		effective_motion_node,
		playback_state,
		active_dominant_slot_id,
		support_requested
	)
	_apply_runtime_weapon_contact_guidance_for_slots(
		humanoid_rig,
		held_item_nodes,
		held_item,
		active_dominant_slot_id,
		active_support_slot_id,
		support_requested
	)
	return resolved_pose_state

func _start_idle_pose(
	idle_pose_result: Dictionary,
	motion_node_chain: Array,
	dominant_slot_id: StringName,
	held_item: Node3D,
	held_item_nodes: Dictionary,
	humanoid_rig: Node3D
) -> void:
	active_runtime_idle_result = idle_pose_result.duplicate(true)
	active_idle_dominant_slot_id = dominant_slot_id
	active_idle_support_slot_id = _resolve_other_hand_slot_id(dominant_slot_id)
	active_idle_default_two_hand = _resolve_default_two_hand_for_support_slot(
		held_item,
		held_item_nodes,
		active_idle_support_slot_id
	)
	var current_weapon_length_meters: float = _resolve_held_item_weapon_length_meters(held_item)
	active_idle_source_key = _build_idle_source_key(idle_pose_result, dominant_slot_id, motion_node_chain, current_weapon_length_meters)
	runtime_idle_active = true
	if humanoid_rig != null and humanoid_rig.has_method("set_upper_body_authoring_auto_apply_enabled"):
		humanoid_rig.call("set_upper_body_authoring_auto_apply_enabled", false)
	_claim_runtime_endpoint_authority(humanoid_rig, held_item)
	idle_chain_player.stop()
	active_idle_trajectory_volume_config = _resolve_runtime_trajectory_volume_config(
		humanoid_rig,
		held_item,
		dominant_slot_id
	)
	var cached_idle_runtime_clip = _resolve_cached_runtime_clip(idle_pose_result)
	var recovery_bridge_source_snapshot: Dictionary = _capture_runtime_solved_replay_bridge_snapshot(
		humanoid_rig,
		held_item,
		cached_idle_runtime_clip
	)
	var idle_compile_result: Dictionary = _compile_runtime_idle_chain(
		motion_node_chain,
		held_item,
		held_item_nodes,
		dominant_slot_id,
		active_idle_support_slot_id,
		active_idle_default_two_hand,
		active_idle_trajectory_volume_config
	)
	_store_runtime_compile_debug(active_runtime_idle_result, idle_compile_result)
	var runtime_idle_target_chain: Array = idle_compile_result.get("motion_node_chain", []) as Array
	if runtime_idle_target_chain.is_empty():
		runtime_idle_target_chain = _duplicate_motion_node_chain(motion_node_chain)
	var recovery_source_node: CombatAnimationMotionNode = pending_recovery_motion_node
	if recovery_source_node != null and pending_recovery_dominant_slot_id == dominant_slot_id:
		var recovery_chain_result: Dictionary = _build_runtime_chain_with_entry(
			runtime_idle_target_chain,
			recovery_source_node,
			RECOVERY_BRIDGE_DURATION_SECONDS,
			0,
			false
		)
		active_idle_motion_node_chain = recovery_chain_result.get("motion_node_chain", []) as Array
		active_idle_recovery_bridge_active = bool(recovery_chain_result.get("entry_bridge_active", false))
		_apply_recovery_bridge_debug(recovery_chain_result)
		_begin_recovery_hidden_bridge(recovery_chain_result, dominant_slot_id, idle_pose_result)
		_clear_pending_recovery_state()
	else:
		active_idle_motion_node_chain = runtime_idle_target_chain
		active_idle_recovery_bridge_active = false
		_clear_recovery_bridge_debug()
	var playback_speed: float = float(idle_pose_result.get("preview_playback_speed_scale", 1.0))
	var should_loop_idle: bool = not active_idle_recovery_bridge_active
	active_idle_runtime_clip = _bake_runtime_playback_clip(
		active_idle_motion_node_chain,
		{
			"clip_kind": CombatRuntimeClipScript.CLIP_KIND_BRIDGE if active_idle_recovery_bridge_active else CombatRuntimeClipScript.CLIP_KIND_IDLE,
			"source_draft_id": idle_pose_result.get("draft_id", StringName()),
			"source_idle_context_id": idle_pose_result.get("idle_context_id", StringName()),
			"source_equipment_slot_id": dominant_slot_id,
			"source_weapon_wip_id": idle_pose_result.get("source_weapon_wip_id", StringName()),
			"source_weapon_length_meters": _resolve_held_item_weapon_length_meters(held_item),
			"playback_speed_scale": playback_speed,
			"loop_enabled": should_loop_idle,
			"trajectory_volume_config": active_idle_trajectory_volume_config,
			"compile_diagnostics": active_runtime_idle_result.get("runtime_compile_diagnostics", []),
			"degraded_node_count": active_runtime_idle_result.get("runtime_compile_degraded_node_count", 0),
			"hand_swap_bridge_count": active_runtime_idle_result.get("runtime_compile_hand_swap_bridge_count", 0),
			"retargeted_count": active_runtime_idle_result.get("runtime_compile_retargeted_count", 0),
		}
	)
	var cached_idle_pose_track_applied: bool = _copy_cached_upper_body_pose_track(
		active_idle_runtime_clip,
		cached_idle_runtime_clip,
		last_recovery_bridge_duration_seconds if active_idle_recovery_bridge_active else 0.0,
		recovery_bridge_source_snapshot if active_idle_recovery_bridge_active else {}
	)
	active_runtime_idle_result["cached_runtime_clip_upper_body_pose_track"] = cached_idle_pose_track_applied
	if active_idle_runtime_clip != null and active_idle_runtime_clip.is_playable():
		active_idle_motion_node_chain = active_idle_runtime_clip.motion_node_chain
		active_runtime_idle_result["runtime_clip_baked"] = true
		active_runtime_idle_result["runtime_clip_frame_count"] = active_idle_runtime_clip.get_frame_count()
		active_runtime_idle_result["runtime_clip_duration_seconds"] = active_idle_runtime_clip.total_duration_seconds
	else:
		active_runtime_idle_result["runtime_clip_baked"] = false
	if active_idle_runtime_clip != null and active_idle_runtime_clip.is_playable() and idle_chain_player.has_method("prepare_runtime_clip"):
		idle_chain_player.prepare_runtime_clip(active_idle_runtime_clip, playback_speed, should_loop_idle)
		idle_chain_player.start()
	elif active_idle_motion_node_chain.size() >= 2:
		var tip_curve: Curve3D = _build_tip_curve(active_idle_motion_node_chain)
		var pommel_curve: Curve3D = _build_pommel_curve(active_idle_motion_node_chain)
		idle_chain_player.prepare(
			active_idle_motion_node_chain,
			tip_curve,
			pommel_curve,
			playback_speed,
			should_loop_idle,
			active_idle_trajectory_volume_config
		)
		idle_chain_player.start()

func _start_steady_idle_pose_after_recovery(
	idle_pose_result: Dictionary,
	motion_node_chain: Array,
	dominant_slot_id: StringName,
	held_item: Node3D,
	held_item_nodes: Dictionary,
	humanoid_rig: Node3D
) -> void:
	active_idle_recovery_bridge_active = false
	active_idle_trajectory_volume_config = _resolve_runtime_trajectory_volume_config(
		humanoid_rig,
		held_item,
		dominant_slot_id
	)
	var idle_compile_result: Dictionary = _compile_runtime_idle_chain(
		motion_node_chain,
		held_item,
		held_item_nodes,
		dominant_slot_id,
		active_idle_support_slot_id,
		active_idle_default_two_hand,
		active_idle_trajectory_volume_config
	)
	_store_runtime_compile_debug(active_runtime_idle_result, idle_compile_result)
	active_idle_motion_node_chain = idle_compile_result.get("motion_node_chain", []) as Array
	if active_idle_motion_node_chain.is_empty():
		active_idle_motion_node_chain = _duplicate_motion_node_chain(motion_node_chain)
	if humanoid_rig != null and humanoid_rig.has_method("set_upper_body_authoring_auto_apply_enabled"):
		humanoid_rig.call("set_upper_body_authoring_auto_apply_enabled", false)
	_claim_runtime_endpoint_authority(humanoid_rig, held_item)
	idle_chain_player.stop()
	if hidden_bridge_state.kind == PlayerRuntimeHiddenBridgeStateScript.KIND_SKILL_RECOVERY:
		hidden_bridge_state.complete()
	var playback_speed: float = float(idle_pose_result.get("preview_playback_speed_scale", 1.0))
	var cached_idle_runtime_clip = _resolve_cached_runtime_clip(idle_pose_result)
	active_idle_runtime_clip = _bake_runtime_playback_clip(
		active_idle_motion_node_chain,
		{
			"clip_kind": CombatRuntimeClipScript.CLIP_KIND_IDLE,
			"source_draft_id": idle_pose_result.get("draft_id", StringName()),
			"source_idle_context_id": idle_pose_result.get("idle_context_id", StringName()),
			"source_equipment_slot_id": dominant_slot_id,
			"source_weapon_wip_id": idle_pose_result.get("source_weapon_wip_id", StringName()),
			"source_weapon_length_meters": _resolve_held_item_weapon_length_meters(held_item),
			"playback_speed_scale": playback_speed,
			"loop_enabled": true,
			"trajectory_volume_config": active_idle_trajectory_volume_config,
			"compile_diagnostics": active_runtime_idle_result.get("runtime_compile_diagnostics", []),
			"degraded_node_count": active_runtime_idle_result.get("runtime_compile_degraded_node_count", 0),
			"hand_swap_bridge_count": active_runtime_idle_result.get("runtime_compile_hand_swap_bridge_count", 0),
			"retargeted_count": active_runtime_idle_result.get("runtime_compile_retargeted_count", 0),
		}
	)
	var cached_idle_pose_track_applied: bool = _copy_cached_upper_body_pose_track(
		active_idle_runtime_clip,
		cached_idle_runtime_clip,
		0.0
	)
	active_runtime_idle_result["cached_runtime_clip_upper_body_pose_track"] = cached_idle_pose_track_applied
	if active_idle_runtime_clip != null and active_idle_runtime_clip.is_playable():
		active_idle_motion_node_chain = active_idle_runtime_clip.motion_node_chain
		active_runtime_idle_result["runtime_clip_baked"] = true
		active_runtime_idle_result["runtime_clip_frame_count"] = active_idle_runtime_clip.get_frame_count()
		active_runtime_idle_result["runtime_clip_duration_seconds"] = active_idle_runtime_clip.total_duration_seconds
	else:
		active_runtime_idle_result["runtime_clip_baked"] = false
	if active_idle_runtime_clip != null and active_idle_runtime_clip.is_playable() and idle_chain_player.has_method("prepare_runtime_clip"):
		idle_chain_player.prepare_runtime_clip(active_idle_runtime_clip, playback_speed, true)
		idle_chain_player.start()
	elif active_idle_motion_node_chain.size() >= 2:
		var tip_curve: Curve3D = _build_tip_curve(active_idle_motion_node_chain)
		var pommel_curve: Curve3D = _build_pommel_curve(active_idle_motion_node_chain)
		idle_chain_player.prepare(active_idle_motion_node_chain, tip_curve, pommel_curve, playback_speed, true, active_idle_trajectory_volume_config)
		idle_chain_player.start()

func _apply_combat_idle_expiry(delta: float, idle_pose_result: Dictionary, result: Dictionary) -> void:
	if not bool(result.get("applied", false)):
		return
	if combat_idle_expiry_seconds <= 0.0:
		return
	if idle_pose_result.get("idle_context_id", StringName()) != CombatAnimationStationStateScript.IDLE_CONTEXT_COMBAT:
		return
	if active_idle_recovery_bridge_active:
		return
	if hidden_bridge_state.active and hidden_bridge_state.kind == PlayerRuntimeHiddenBridgeStateScript.KIND_SKILL_RECOVERY:
		return
	combat_idle_elapsed_seconds += maxf(delta, 0.0)
	if combat_idle_elapsed_seconds < combat_idle_expiry_seconds and not combat_idle_expired_pending:
		return
	combat_idle_expired_pending = true
	result["combat_idle_expired"] = true
	result["requested_weapons_drawn"] = false
	_begin_stow_hidden_bridge(
		active_idle_dominant_slot_id,
		idle_pose_result.get("preferred_grip_style_mode", StringName()) as StringName
	)

func _begin_stow_hidden_bridge(dominant_slot_id: StringName, source_grip_style_mode: StringName = StringName()) -> void:
	if hidden_bridge_state.active and hidden_bridge_state.kind == PlayerRuntimeHiddenBridgeStateScript.KIND_STOW_TO_NONCOMBAT_IDLE:
		return
	hidden_bridge_state.begin(
		PlayerRuntimeHiddenBridgeStateScript.KIND_STOW_TO_NONCOMBAT_IDLE,
		STOW_BRIDGE_DURATION_SECONDS,
		dominant_slot_id,
		CombatAnimationStationStateScript.IDLE_CONTEXT_COMBAT,
		CombatAnimationStationStateScript.IDLE_CONTEXT_NONCOMBAT,
		source_grip_style_mode,
		source_grip_style_mode,
		false,
		true
	)

func _apply_current_idle_pose(humanoid_rig: Node3D, held_item_nodes: Dictionary) -> Dictionary:
	var held_item: Node3D = held_item_nodes.get(active_idle_dominant_slot_id) as Node3D
	if humanoid_rig == null or held_item == null or not is_instance_valid(held_item):
		return last_runtime_idle_pose_state.duplicate(true)
	var effective_motion_node: CombatAnimationMotionNode = _build_effective_idle_motion_node()
	if effective_motion_node == null:
		return last_runtime_idle_pose_state.duplicate(true)
	var support_requested: bool = _resolve_support_hand_requested_from_values(
		held_item,
		held_item_nodes,
		active_idle_support_slot_id,
		active_idle_default_two_hand,
		effective_motion_node.preferred_grip_style_mode,
		effective_motion_node.two_hand_state
	)
	if not support_requested and effective_motion_node.two_hand_state == CombatAnimationMotionNodeScript.TWO_HAND_STATE_TWO_HAND:
		effective_motion_node.two_hand_state = CombatAnimationMotionNodeScript.TWO_HAND_STATE_ONE_HAND
	var playback_state: Dictionary = _build_idle_playback_state(effective_motion_node)
	if active_idle_runtime_clip != null and active_idle_runtime_clip.is_playable():
		return _apply_contact_group_runtime_clip_pose(
			humanoid_rig,
			held_item_nodes,
			held_item,
			effective_motion_node,
			playback_state,
			active_idle_dominant_slot_id,
			active_idle_support_slot_id,
			support_requested
		)
	var resolved_pose_state: Dictionary = live_pose_presenter.apply_runtime_authored_weapon_pose(
		humanoid_rig,
		held_item,
		effective_motion_node,
		playback_state,
		active_idle_dominant_slot_id,
		support_requested
	)
	_apply_runtime_weapon_contact_guidance_for_slots(
		humanoid_rig,
		held_item_nodes,
		held_item,
		active_idle_dominant_slot_id,
		active_idle_support_slot_id,
		support_requested
	)
	return resolved_pose_state

func _apply_contact_group_runtime_clip_pose(
	humanoid_rig: Node3D,
	held_item_nodes: Dictionary,
	held_item: Node3D,
	effective_motion_node: CombatAnimationMotionNode,
	playback_state: Dictionary,
	dominant_slot_id: StringName,
	support_slot_id: StringName,
	support_requested: bool
) -> Dictionary:
	var resolved_playback_state: Dictionary = playback_state.duplicate(true)
	if humanoid_rig == null or held_item == null or not is_instance_valid(held_item) or effective_motion_node == null:
		return resolved_playback_state
	_claim_runtime_endpoint_authority(humanoid_rig, held_item)
	var local_tip: Vector3 = _get_weapon_tip_meta(held_item)
	var local_pommel: Vector3 = _get_weapon_pommel_meta(held_item)
	if local_tip.is_equal_approx(local_pommel):
		return resolved_playback_state
	var previous_slot_id: StringName = live_pose_presenter.preview_dominant_slot_id
	var previous_default_two_hand: bool = live_pose_presenter.preview_default_two_hand
	live_pose_presenter.configure_preview_hand_setup(dominant_slot_id, support_requested)

	var trajectory_transform: Transform3D = live_pose_presenter._resolve_trajectory_authoring_transform(humanoid_rig)
	if _apply_solved_runtime_replay_frame(
		humanoid_rig,
		held_item_nodes,
		held_item,
		resolved_playback_state,
		dominant_slot_id,
		support_slot_id,
		support_requested
	):
		live_pose_presenter.configure_preview_hand_setup(previous_slot_id, previous_default_two_hand)
		return resolved_playback_state
	_clear_runtime_solved_replay_pose(humanoid_rig)
	live_pose_presenter._apply_preview_motion_grip_state(
		held_item,
		effective_motion_node,
		playback_state,
		humanoid_rig
	)
	_sync_runtime_contact_axis_override(held_item, playback_state, trajectory_transform.basis)
	var authored_tip_origin_id: StringName = _resolve_origin_id_from_state(
		resolved_playback_state,
		"tip_position_origin_id",
		effective_motion_node.tip_position_origin_id
	)
	var authored_tip_local: Vector3 = _get_origin_tracked_vector3_state(
		resolved_playback_state,
		"tip_position_local",
		"tip_position_origin_id",
		effective_motion_node.tip_position_local,
		authored_tip_origin_id
	)
	var authored_pommel_origin_id: StringName = _resolve_origin_id_from_state(
		resolved_playback_state,
		"pommel_position_origin_id",
		effective_motion_node.pommel_position_origin_id
	)
	var authored_pommel_local: Vector3 = _get_origin_tracked_vector3_state(
		resolved_playback_state,
		"pommel_position_local",
		"pommel_position_origin_id",
		effective_motion_node.pommel_position_local,
		authored_pommel_origin_id
	)
	var authored_tip_world: Vector3 = trajectory_transform * authored_tip_local
	var authored_pommel_world: Vector3 = trajectory_transform * authored_pommel_local
	var resolved_weapon_orientation_degrees: Vector3 = playback_state.get(
		"weapon_orientation_degrees",
		effective_motion_node.weapon_orientation_degrees
	) as Vector3
	if authored_tip_world.distance_to(authored_pommel_world) > 0.000001:
		var local_axis: Vector3 = (local_tip - local_pommel).normalized()
		var local_tip_origin_id: StringName = _resolve_origin_meta_value(held_item, "weapon_tip_origin_id", CombatOriginRecordScript.ORIGIN_WEAPON_ROOT)
		var local_pommel_origin_id: StringName = _resolve_origin_meta_value(held_item, "weapon_pommel_origin_id", CombatOriginRecordScript.ORIGIN_WEAPON_ROOT)
		var local_up_reference_origin_id: StringName = CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
		var local_up_reference: Vector3 = _resolve_weapon_local_up_reference(held_item, local_axis)
		var solved_transform: Transform3D = weapon_frame_solver.solve_transform_from_segment(
			local_tip,
			local_pommel,
			authored_tip_world,
			authored_pommel_world,
			local_up_reference,
			trajectory_transform.basis,
			resolved_weapon_orientation_degrees,
			float(playback_state.get("weapon_roll_degrees", effective_motion_node.weapon_roll_degrees)),
			local_tip_origin_id,
			local_pommel_origin_id,
			local_up_reference_origin_id
		)
		held_item.global_transform = solved_transform
	live_pose_presenter._apply_preview_resolved_grip_state(held_item)
	_apply_runtime_weapon_contact_guidance_for_slots(
		humanoid_rig,
		held_item_nodes,
		held_item,
		dominant_slot_id,
		support_slot_id,
		support_requested
	)
	var solved_tip_world: Vector3 = held_item.to_global(local_tip)
	var solved_pommel_world: Vector3 = held_item.to_global(local_pommel)
	var trajectory_inverse: Transform3D = trajectory_transform.affine_inverse()
	resolved_playback_state["active"] = bool(resolved_playback_state.get("active", true))
	resolved_playback_state["tip_position_local"] = trajectory_inverse * solved_tip_world
	resolved_playback_state["tip_position_origin_id"] = CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING
	resolved_playback_state["pommel_position_local"] = trajectory_inverse * solved_pommel_world
	resolved_playback_state["pommel_position_origin_id"] = CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING
	resolved_playback_state["tip_world"] = solved_tip_world
	resolved_playback_state["pommel_world"] = solved_pommel_world
	resolved_playback_state["weapon_orientation_degrees"] = resolved_weapon_orientation_degrees
	resolved_playback_state["runtime_endpoint_authority_active"] = bool(held_item.get_meta(RUNTIME_ENDPOINT_AUTHORITY_ACTIVE_META, false))
	resolved_playback_state["runtime_endpoint_authority_origin_id"] = StringName(held_item.get_meta(
		RUNTIME_ENDPOINT_AUTHORITY_ORIGIN_META,
		StringName()
	))
	resolved_playback_state["held_item_parent_path"] = str(held_item.get_parent().get_path() if held_item.get_parent() != null else NodePath(""))
	if not _apply_baked_runtime_upper_body_pose_frame(
		humanoid_rig,
		held_item,
		effective_motion_node,
		resolved_playback_state,
		dominant_slot_id,
		support_requested,
		solved_tip_world,
		solved_pommel_world
	):
		_apply_runtime_clip_upper_body_authoring_state(
			humanoid_rig,
			held_item,
			effective_motion_node,
			resolved_playback_state,
			dominant_slot_id,
			support_requested,
			solved_tip_world,
			solved_pommel_world
		)
	_reseat_runtime_weapon_to_current_hand_target(
		humanoid_rig,
		held_item,
		effective_motion_node,
		dominant_slot_id,
		support_requested
	)
	solved_tip_world = held_item.to_global(local_tip)
	solved_pommel_world = held_item.to_global(local_pommel)
	resolved_playback_state["tip_position_local"] = trajectory_inverse * solved_tip_world
	resolved_playback_state["tip_position_origin_id"] = CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING
	resolved_playback_state["pommel_position_local"] = trajectory_inverse * solved_pommel_world
	resolved_playback_state["pommel_position_origin_id"] = CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING
	resolved_playback_state["tip_world"] = solved_tip_world
	resolved_playback_state["pommel_world"] = solved_pommel_world
	_settle_runtime_contact_group_on_resolved_weapon(
		humanoid_rig,
		held_item_nodes,
		held_item,
		effective_motion_node,
		resolved_playback_state,
		dominant_slot_id,
		support_slot_id,
		support_requested
	)
	resolved_playback_state["primary_grip_alignment_error_meters"] = _resolve_runtime_primary_grip_alignment_error(
		humanoid_rig,
		held_item,
		dominant_slot_id
	)
	live_pose_presenter.configure_preview_hand_setup(previous_slot_id, previous_default_two_hand)
	return resolved_playback_state

func _clear_runtime_solved_replay_pose(humanoid_rig: Node3D) -> void:
	if humanoid_rig == null:
		return
	if humanoid_rig.has_method("clear_runtime_solved_replay_pose_frame"):
		humanoid_rig.call("clear_runtime_solved_replay_pose_frame")

func _apply_solved_runtime_replay_frame(
	humanoid_rig: Node3D,
	_held_item_nodes: Dictionary,
	held_item: Node3D,
	playback_state: Dictionary,
	dominant_slot_id: StringName,
	support_slot_id: StringName,
	support_requested: bool
) -> bool:
	if humanoid_rig == null or held_item == null or not is_instance_valid(held_item):
		return false
	if not bool(playback_state.get("solved_replay_available", false)):
		return false
	if not humanoid_rig.has_method("apply_runtime_solved_upper_body_pose_frame"):
		return false
	var bone_names: Array = playback_state.get("solved_upper_body_bone_names", []) as Array
	var bone_positions: Array = playback_state.get("solved_upper_body_pose_positions", []) as Array
	var bone_rotations: Array = playback_state.get("solved_upper_body_pose_rotations", []) as Array
	var bone_scales: Array = playback_state.get("solved_upper_body_pose_scales", []) as Array
	if bone_names.is_empty() or bone_positions.is_empty() or bone_rotations.is_empty() or bone_scales.is_empty():
		return false
	if humanoid_rig.has_method("clear_upper_body_authoring_state"):
		humanoid_rig.call("clear_upper_body_authoring_state")
	if humanoid_rig.has_method("clear_authoring_contact_anchor_bases"):
		humanoid_rig.call("clear_authoring_contact_anchor_bases")
	var contact_presenter = live_pose_presenter.equipped_item_presenter if live_pose_presenter != null else null
	if contact_presenter != null and contact_presenter.has_method("clear_rig_weapon_contact_guidance"):
		contact_presenter.call("clear_rig_weapon_contact_guidance", humanoid_rig)
	var pose_applied: bool = bool(humanoid_rig.call(
		"apply_runtime_solved_upper_body_pose_frame",
		bone_names,
		bone_positions,
		bone_rotations,
		bone_scales,
		1.0
	))
	if not pose_applied:
		return false
	var reference_transform: Transform3D = live_pose_presenter._resolve_trajectory_authoring_transform(humanoid_rig)
	var weapon_position_reference_local: Vector3 = playback_state.get("solved_weapon_position_reference_local", Vector3.ZERO) as Vector3
	var weapon_rotation_reference_local: Quaternion = playback_state.get("solved_weapon_rotation_reference_local", Quaternion.IDENTITY) as Quaternion
	var weapon_scale_reference_local: Vector3 = playback_state.get("solved_weapon_scale_reference_local", Vector3.ONE) as Vector3
	var weapon_frame_registered := false
	if humanoid_rig.has_method("set_runtime_solved_replay_weapon_frame"):
		weapon_frame_registered = bool(humanoid_rig.call(
			"set_runtime_solved_replay_weapon_frame",
			held_item,
			playback_state.get("solved_replay_reference_bone_name", RUNTIME_SOLVED_REPLAY_REFERENCE_BONE) as StringName,
			weapon_position_reference_local,
			weapon_rotation_reference_local,
			weapon_scale_reference_local,
			playback_state.get("solved_anchor_node_paths", []) as Array,
			playback_state.get("solved_anchor_positions_weapon_local", []) as Array,
			playback_state.get("solved_anchor_rotations_weapon_local", []) as Array,
			playback_state.get("solved_anchor_scales_weapon_local", []) as Array,
			_normalize_hand_slot_id(dominant_slot_id) if bool(playback_state.get("solved_replay_bridge_frame", false)) else StringName(),
			StringName(playback_state.get("solved_replay_reference_origin_id", CombatOriginRecordScript.ORIGIN_SOLVED_REPLAY_REFERENCE)),
			StringName(playback_state.get("solved_weapon_reference_origin_id", CombatOriginRecordScript.ORIGIN_SOLVED_REPLAY_REFERENCE)),
			StringName(playback_state.get("solved_anchor_origin_id", CombatOriginRecordScript.ORIGIN_WEAPON_ROOT))
		))
	if not weapon_frame_registered:
		var weapon_reference_transform: Transform3D = _build_transform_from_replay_components(
			weapon_position_reference_local,
			weapon_rotation_reference_local,
			weapon_scale_reference_local
		)
		held_item.global_transform = reference_transform * weapon_reference_transform
		_apply_solved_replay_anchor_transforms(held_item, playback_state)
	held_item.set_meta("dominant_contact_slot_id", _normalize_hand_slot_id(dominant_slot_id))
	var local_tip: Vector3 = _get_weapon_tip_meta(held_item)
	var local_pommel: Vector3 = _get_weapon_pommel_meta(held_item)
	var solved_tip_world: Vector3 = held_item.to_global(local_tip)
	var solved_pommel_world: Vector3 = held_item.to_global(local_pommel)
	var reference_inverse: Transform3D = reference_transform.affine_inverse()
	playback_state["active"] = bool(playback_state.get("active", true))
	playback_state["tip_position_local"] = reference_inverse * solved_tip_world
	playback_state["tip_position_origin_id"] = CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING
	playback_state["pommel_position_local"] = reference_inverse * solved_pommel_world
	playback_state["pommel_position_origin_id"] = CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING
	playback_state["tip_world"] = solved_tip_world
	playback_state["pommel_world"] = solved_pommel_world
	playback_state["runtime_endpoint_authority_active"] = bool(held_item.get_meta(RUNTIME_ENDPOINT_AUTHORITY_ACTIVE_META, false))
	playback_state["runtime_endpoint_authority_origin_id"] = StringName(held_item.get_meta(
		RUNTIME_ENDPOINT_AUTHORITY_ORIGIN_META,
		StringName()
	))
	playback_state["held_item_parent_path"] = str(held_item.get_parent().get_path() if held_item.get_parent() != null else NodePath(""))
	playback_state["solved_replay_applied"] = true
	playback_state["solved_replay_support_requested"] = support_requested
	playback_state["solved_replay_support_slot_id"] = support_slot_id
	return true

func _apply_solved_replay_anchor_transforms(held_item: Node3D, playback_state: Dictionary) -> void:
	if held_item == null or not is_instance_valid(held_item):
		return
	var anchor_paths: Array = playback_state.get("solved_anchor_node_paths", []) as Array
	var anchor_positions: Array = playback_state.get("solved_anchor_positions_weapon_local", []) as Array
	var anchor_rotations: Array = playback_state.get("solved_anchor_rotations_weapon_local", []) as Array
	var anchor_scales: Array = playback_state.get("solved_anchor_scales_weapon_local", []) as Array
	var count: int = mini(anchor_paths.size(), mini(anchor_positions.size(), mini(anchor_rotations.size(), anchor_scales.size())))
	for anchor_index: int in range(count):
		var anchor_node: Node3D = held_item.get_node_or_null(NodePath(String(anchor_paths[anchor_index]))) as Node3D
		if anchor_node == null or not is_instance_valid(anchor_node):
			continue
		var anchor_weapon_transform: Transform3D = _build_transform_from_replay_components(
			anchor_positions[anchor_index] as Vector3,
			anchor_rotations[anchor_index] as Quaternion,
			anchor_scales[anchor_index] as Vector3
		)
		anchor_node.global_transform = held_item.global_transform * anchor_weapon_transform

func _build_transform_from_replay_components(position: Vector3, rotation: Quaternion, scale: Vector3) -> Transform3D:
	var basis := Basis(rotation.normalized())
	basis = basis.scaled(scale)
	return Transform3D(basis, position)

func _settle_runtime_contact_group_on_resolved_weapon(
	humanoid_rig: Node3D,
	held_item_nodes: Dictionary,
	held_item: Node3D,
	effective_motion_node: CombatAnimationMotionNode,
	resolved_playback_state: Dictionary,
	dominant_slot_id: StringName,
	support_slot_id: StringName,
	support_requested: bool
) -> void:
	if humanoid_rig == null or held_item == null or not is_instance_valid(held_item):
		return
	_apply_runtime_weapon_contact_guidance_for_slots(
		humanoid_rig,
		held_item_nodes,
		held_item,
		dominant_slot_id,
		support_slot_id,
		support_requested
	)
	if humanoid_rig.has_method("set_upper_body_authoring_state"):
		var payload: Dictionary = _build_runtime_clip_upper_body_authoring_payload(
			held_item,
			effective_motion_node,
			resolved_playback_state,
			dominant_slot_id,
			support_requested,
			resolved_playback_state.get("tip_world", held_item.global_position) as Vector3,
			resolved_playback_state.get("pommel_world", held_item.global_position) as Vector3
		)
		if not payload.is_empty():
			humanoid_rig.call("set_upper_body_authoring_state", payload)
	if humanoid_rig.has_method("apply_runtime_contact_group_frame_now"):
		humanoid_rig.call("apply_runtime_contact_group_frame_now", 1.0 / 60.0)

func _sync_runtime_contact_axis_override(
	held_item: Node3D,
	playback_state: Dictionary,
	trajectory_basis: Basis
) -> void:
	_clear_runtime_contact_axis_override(held_item)
	if held_item == null:
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
	var contact_axis_world: Vector3 = trajectory_basis * contact_axis_local.normalized()
	if contact_axis_world.length_squared() <= 0.000001:
		return
	held_item.set_meta("authoring_contact_grip_axis_world_override", contact_axis_world.normalized())
	held_item.set_meta("authoring_contact_grip_axis_origin_id", contact_axis_origin_id)

func _clear_runtime_contact_axis_override(held_item: Node3D) -> void:
	if held_item == null:
		return
	if held_item.has_meta("authoring_contact_grip_axis_world_override"):
		held_item.remove_meta("authoring_contact_grip_axis_world_override")
	if held_item.has_meta("authoring_contact_grip_axis_origin_id"):
		held_item.remove_meta("authoring_contact_grip_axis_origin_id")

func _resolve_weapon_local_up_reference(held_item: Node3D, local_axis: Vector3) -> Vector3:
	var basis_anchor: Node3D = weapon_grip_anchor_provider.get_primary_grip_basis_anchor(held_item)
	var local_up_reference: Vector3 = basis_anchor.transform.basis.y if basis_anchor != null else Vector3.UP
	local_up_reference = local_up_reference - local_axis * local_up_reference.dot(local_axis)
	if local_up_reference.length_squared() <= 0.000001:
		local_up_reference = Vector3.UP - local_axis * Vector3.UP.dot(local_axis)
	if local_up_reference.length_squared() <= 0.000001:
		local_up_reference = Vector3.RIGHT - local_axis * Vector3.RIGHT.dot(local_axis)
	return local_up_reference.normalized()

func _apply_runtime_clip_upper_body_authoring_state(
	humanoid_rig: Node3D,
	held_item: Node3D,
	effective_motion_node: CombatAnimationMotionNode,
	playback_state: Dictionary,
	dominant_slot_id: StringName,
	support_requested: bool,
	tip_world: Vector3,
	pommel_world: Vector3
) -> void:
	if humanoid_rig == null or held_item == null or not is_instance_valid(held_item):
		return
	if not humanoid_rig.has_method("set_upper_body_authoring_state"):
		return
	var payload: Dictionary = _build_runtime_clip_upper_body_authoring_payload(
		held_item,
		effective_motion_node,
		playback_state,
		dominant_slot_id,
		support_requested,
		tip_world,
		pommel_world
	)
	if payload.is_empty():
		return
	humanoid_rig.call("set_upper_body_authoring_state", payload)
	if humanoid_rig.has_method("apply_runtime_combat_authoring_frame_now"):
		humanoid_rig.call("apply_runtime_combat_authoring_frame_now")
	elif humanoid_rig.has_method("apply_upper_body_authoring_pose_now"):
		humanoid_rig.call("apply_upper_body_authoring_pose_now")

func _apply_baked_runtime_upper_body_pose_frame(
	humanoid_rig: Node3D,
	held_item: Node3D,
	effective_motion_node: CombatAnimationMotionNode,
	playback_state: Dictionary,
	dominant_slot_id: StringName,
	support_requested: bool,
	tip_world: Vector3,
	pommel_world: Vector3
) -> bool:
	if humanoid_rig == null or held_item == null or not is_instance_valid(held_item):
		return false
	if not bool(playback_state.get("upper_body_pose_available", false)):
		return false
	if not humanoid_rig.has_method("apply_runtime_upper_body_pose_frame"):
		return false
	if humanoid_rig.has_method("set_upper_body_authoring_state"):
		var payload: Dictionary = _build_runtime_clip_upper_body_authoring_payload(
			held_item,
			effective_motion_node,
			playback_state,
			dominant_slot_id,
			support_requested,
			tip_world,
			pommel_world
		)
		if not payload.is_empty():
			payload["baked_upper_body_pose_active"] = true
			humanoid_rig.call("set_upper_body_authoring_state", payload)
	var bone_names: Array = playback_state.get("upper_body_bone_names", []) as Array
	var bone_pose_rotations: Array = playback_state.get("upper_body_bone_pose_rotations", []) as Array
	if bone_names.is_empty() or bone_pose_rotations.is_empty():
		return false
	return bool(humanoid_rig.call("apply_runtime_upper_body_pose_frame", bone_names, bone_pose_rotations, 1.0))

func _build_runtime_clip_upper_body_authoring_payload(
	held_item: Node3D,
	effective_motion_node: CombatAnimationMotionNode,
	playback_state: Dictionary,
	dominant_slot_id: StringName,
	support_requested: bool,
	tip_world: Vector3,
	pommel_world: Vector3
) -> Dictionary:
	if held_item == null or effective_motion_node == null or not is_instance_valid(held_item):
		return {}
	var primary_anchor: Node3D = weapon_grip_anchor_provider.get_primary_grip_anchor(held_item)
	var support_anchor: Node3D = weapon_grip_anchor_provider.get_support_grip_anchor(held_item)
	return {
		"active": true,
		"blend": clampf(float(playback_state.get("body_support_blend", effective_motion_node.body_support_blend)), 0.0, 1.0),
		"two_hand": support_requested,
		"dominant_slot_id": dominant_slot_id,
		"right_upperarm_roll_degrees": float(playback_state.get("right_upperarm_roll_degrees", effective_motion_node.right_upperarm_roll_degrees)),
		"left_upperarm_roll_degrees": float(playback_state.get("left_upperarm_roll_degrees", effective_motion_node.left_upperarm_roll_degrees)),
		"primary_target_world": primary_anchor.global_position if primary_anchor != null else Vector3.ZERO,
		"secondary_target_world": support_anchor.global_position if support_requested and support_anchor != null else Vector3.ZERO,
		"tip_world": tip_world,
		"pommel_world": pommel_world,
	}

func _reseat_runtime_weapon_to_current_hand_target(
	humanoid_rig: Node3D,
	held_item: Node3D,
	effective_motion_node: CombatAnimationMotionNode,
	dominant_slot_id: StringName,
	support_requested: bool
) -> void:
	if humanoid_rig == null or held_item == null or not is_instance_valid(held_item):
		return
	var previous_slot_id: StringName = live_pose_presenter.preview_dominant_slot_id
	var previous_default_two_hand: bool = live_pose_presenter.preview_default_two_hand
	live_pose_presenter.configure_preview_hand_setup(dominant_slot_id, support_requested)
	var primary_local: Vector3 = _resolve_runtime_primary_grip_seat_local(held_item)
	var primary_origin_id: StringName = CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
	held_item.set_meta("preview_primary_grip_seat_local", primary_local)
	held_item.set_meta("preview_primary_grip_seat_origin_id", primary_origin_id)
	if support_requested:
		var support_local: Vector3 = live_pose_presenter._resolve_secondary_grip_seat_local_from_offsets(
			held_item,
			effective_motion_node.secondary_grip_seat_slide_offset if effective_motion_node != null else 0.0
		)
		var support_origin_id: StringName = CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
		held_item.set_meta("preview_support_grip_seat_local", support_local)
		held_item.set_meta("preview_support_grip_seat_origin_id", support_origin_id)
		held_item.set_meta("preview_secondary_grip_seat_authored", true)
	else:
		held_item.set_meta("preview_secondary_grip_seat_authored", false)
	var hand_target_world: Vector3 = live_pose_presenter._resolve_preview_primary_grip_target_world(humanoid_rig, held_item)
	if hand_target_world.length_squared() > 0.000001:
		var reseated_transform: Transform3D = live_pose_presenter._lock_preview_transform_to_dominant_grip_target(
			held_item.global_transform,
			primary_local,
			hand_target_world,
			1.0
		)
		if support_requested:
			reseated_transform = live_pose_presenter._apply_preview_support_coupling(
				humanoid_rig,
				held_item,
				effective_motion_node,
				reseated_transform,
				1.0
			)
			reseated_transform = live_pose_presenter._lock_preview_transform_to_dominant_grip_target(
				reseated_transform,
				primary_local,
				hand_target_world,
				1.0
			)
		held_item.global_transform = reseated_transform
		live_pose_presenter._apply_preview_resolved_grip_state(held_item)
	live_pose_presenter.configure_preview_hand_setup(previous_slot_id, previous_default_two_hand)

func _resolve_runtime_primary_grip_seat_local(held_item: Node3D) -> Vector3:
	if held_item == null or not is_instance_valid(held_item):
		return Vector3.ZERO
	if _has_origin_tracked_vector3_meta(
		held_item,
		"preview_primary_grip_seat_local",
		"preview_primary_grip_seat_origin_id",
		CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
	):
		return _get_preview_primary_grip_seat_meta(held_item)
	return live_pose_presenter._resolve_preview_primary_grip_anchor_local(held_item)

func _resolve_runtime_primary_grip_alignment_error(
	humanoid_rig: Node3D,
	held_item: Node3D,
	dominant_slot_id: StringName
) -> float:
	if humanoid_rig == null or held_item == null or not is_instance_valid(held_item):
		return -1.0
	var primary_anchor: Node3D = weapon_grip_anchor_provider.get_primary_grip_anchor(held_item)
	if primary_anchor == null or not is_instance_valid(primary_anchor):
		return -1.0
	if not humanoid_rig.has_method("resolve_hand_grip_alignment_world_position"):
		return -1.0
	var target_variant: Variant = humanoid_rig.call("resolve_hand_grip_alignment_world_position", dominant_slot_id)
	if not (target_variant is Vector3):
		return -1.0
	var hand_grip_target_world: Vector3 = target_variant as Vector3
	if hand_grip_target_world.length_squared() <= 0.000001:
		return -1.0
	return primary_anchor.global_position.distance_to(hand_grip_target_world)

func _apply_runtime_weapon_contact_guidance_for_slots(
	humanoid_rig: Node3D,
	held_item_nodes: Dictionary,
	held_item: Node3D,
	dominant_slot_id: StringName,
	support_slot_id: StringName,
	support_requested: bool
) -> void:
	if humanoid_rig == null or held_item == null or not is_instance_valid(held_item):
		return
	var normalized_dominant_slot_id: StringName = _normalize_hand_slot_id(dominant_slot_id)
	held_item.set_meta("dominant_contact_slot_id", normalized_dominant_slot_id)
	var presenter = live_pose_presenter.equipped_item_presenter if live_pose_presenter != null else null
	if presenter != null and presenter.has_method("sync_single_weapon_contact_guidance"):
		presenter.call(
			"sync_single_weapon_contact_guidance",
			humanoid_rig,
			held_item,
			normalized_dominant_slot_id,
			support_requested,
			true,
			true,
			support_requested,
			true,
			true
		)
		return
	_apply_runtime_support_guidance_for_slots(
		humanoid_rig,
		held_item_nodes,
		held_item,
		support_slot_id,
		support_requested
	)

func _apply_runtime_support_guidance(
	humanoid_rig: Node3D,
	held_item_nodes: Dictionary,
	held_item: Node3D,
	support_requested: bool
) -> void:
	_apply_runtime_support_guidance_for_slots(
		humanoid_rig,
		held_item_nodes,
		held_item,
		active_support_slot_id,
		support_requested
	)

func _apply_runtime_support_guidance_for_slots(
	humanoid_rig: Node3D,
	held_item_nodes: Dictionary,
	held_item: Node3D,
	support_slot_id: StringName,
	support_requested: bool
) -> void:
	if humanoid_rig == null or support_slot_id == StringName():
		return
	var support_item: Node3D = held_item_nodes.get(support_slot_id) as Node3D
	if support_item != null and is_instance_valid(support_item):
		return
	if not support_requested:
		if humanoid_rig.has_method("clear_arm_guidance_target"):
			humanoid_rig.call("clear_arm_guidance_target", support_slot_id)
		if humanoid_rig.has_method("clear_arm_guidance_active"):
			humanoid_rig.call("clear_arm_guidance_active", support_slot_id)
		if humanoid_rig.has_method("clear_finger_grip_target"):
			humanoid_rig.call("clear_finger_grip_target", support_slot_id)
		if humanoid_rig.has_method("set_support_hand_active"):
			humanoid_rig.call("set_support_hand_active", support_slot_id, false)
		return
	var support_anchor: Node3D = weapon_grip_anchor_provider.get_support_grip_anchor(held_item)
	var support_guide: Node3D = held_item.get_node_or_null("SecondaryGripGuide") as Node3D
	if humanoid_rig.has_method("set_arm_guidance_target"):
		humanoid_rig.call(
			"set_arm_guidance_target",
			support_slot_id,
			support_anchor if support_anchor != null else support_guide
		)
	if humanoid_rig.has_method("set_arm_guidance_active"):
		humanoid_rig.call("set_arm_guidance_active", support_slot_id, support_anchor != null or support_guide != null)
	if humanoid_rig.has_method("set_finger_grip_target") and support_guide != null:
		humanoid_rig.call("set_finger_grip_target", support_slot_id, support_guide)
	if humanoid_rig.has_method("set_support_hand_active"):
		humanoid_rig.call("set_support_hand_active", support_slot_id, true)

func _build_effective_motion_node(support_requested: bool) -> CombatAnimationMotionNode:
	var base_motion_node: CombatAnimationMotionNode = active_motion_node_chain[0] as CombatAnimationMotionNode
	var effective_motion_node: CombatAnimationMotionNode = (
		base_motion_node.duplicate_node()
		if base_motion_node != null
		else CombatAnimationMotionNodeScript.new() as CombatAnimationMotionNode
	)
	effective_motion_node.tip_position_local = chain_player.current_tip_position
	effective_motion_node.tip_position_origin_id = chain_player.current_tip_position_origin_id
	effective_motion_node.pommel_position_local = chain_player.current_pommel_position
	effective_motion_node.pommel_position_origin_id = chain_player.current_pommel_position_origin_id
	effective_motion_node.weapon_orientation_degrees = chain_player.current_weapon_orientation_degrees
	effective_motion_node.weapon_orientation_authored = true
	effective_motion_node.weapon_roll_degrees = chain_player.current_weapon_roll
	effective_motion_node.axial_reposition_offset = chain_player.current_axial_reposition
	effective_motion_node.grip_seat_slide_offset = chain_player.current_grip_seat_slide
	effective_motion_node.secondary_grip_seat_slide_offset = chain_player.current_secondary_grip_seat_slide
	effective_motion_node.body_support_blend = chain_player.current_body_support_blend
	effective_motion_node.right_upperarm_roll_degrees = chain_player.current_right_upperarm_roll
	effective_motion_node.left_upperarm_roll_degrees = chain_player.current_left_upperarm_roll
	effective_motion_node.two_hand_state = chain_player.current_two_hand_state
	effective_motion_node.primary_hand_slot = chain_player.current_primary_hand_slot
	effective_motion_node.preferred_grip_style_mode = chain_player.current_preferred_grip_style_mode
	if not support_requested and effective_motion_node.two_hand_state == CombatAnimationMotionNodeScript.TWO_HAND_STATE_TWO_HAND:
		effective_motion_node.two_hand_state = CombatAnimationMotionNodeScript.TWO_HAND_STATE_ONE_HAND
	effective_motion_node.normalize()
	return effective_motion_node

func _build_playback_state() -> Dictionary:
	return {
		"active": true,
		"tip_position_local": chain_player.current_tip_position,
		"tip_position_origin_id": chain_player.current_tip_position_origin_id,
		"pommel_position_local": chain_player.current_pommel_position,
		"pommel_position_origin_id": chain_player.current_pommel_position_origin_id,
		"weapon_orientation_degrees": chain_player.current_weapon_orientation_degrees,
		"weapon_roll_degrees": chain_player.current_weapon_roll,
		"axial_reposition_offset": chain_player.current_axial_reposition,
		"grip_seat_slide_offset": chain_player.current_grip_seat_slide,
		"secondary_grip_seat_slide_offset": chain_player.current_secondary_grip_seat_slide,
		"body_support_blend": chain_player.current_body_support_blend,
		"right_upperarm_roll_degrees": chain_player.current_right_upperarm_roll,
		"left_upperarm_roll_degrees": chain_player.current_left_upperarm_roll,
		"two_hand_state": chain_player.current_two_hand_state,
		"primary_hand_slot": chain_player.current_primary_hand_slot,
		"preferred_grip_style_mode": chain_player.current_preferred_grip_style_mode,
		"contact_grip_axis_local": chain_player.current_contact_grip_axis_local,
		"contact_grip_axis_origin_id": chain_player.current_contact_grip_axis_origin_id,
		"contact_grip_axis_local_override_active": chain_player.current_contact_grip_axis_local_override_active,
		"upper_body_pose_available": chain_player.current_upper_body_pose_available,
		"upper_body_bone_names": chain_player.current_upper_body_bone_names.duplicate(),
		"upper_body_bone_pose_rotations": chain_player.current_upper_body_bone_pose_rotations.duplicate(),
		"solved_replay_available": chain_player.current_solved_replay_available,
		"solved_replay_reference_bone_name": chain_player.current_solved_replay_reference_bone_name,
		"solved_replay_reference_origin_id": chain_player.current_solved_replay_reference_origin_id,
		"solved_upper_body_bone_names": chain_player.current_solved_upper_body_bone_names.duplicate(),
		"solved_upper_body_pose_positions": chain_player.current_solved_upper_body_pose_positions.duplicate(),
		"solved_upper_body_pose_rotations": chain_player.current_solved_upper_body_pose_rotations.duplicate(),
		"solved_upper_body_pose_scales": chain_player.current_solved_upper_body_pose_scales.duplicate(),
		"solved_weapon_position_reference_local": chain_player.current_solved_weapon_position_reference_local,
		"solved_weapon_rotation_reference_local": chain_player.current_solved_weapon_rotation_reference_local,
		"solved_weapon_scale_reference_local": chain_player.current_solved_weapon_scale_reference_local,
		"solved_weapon_reference_origin_id": chain_player.current_solved_weapon_reference_origin_id,
		"solved_anchor_node_paths": chain_player.current_solved_anchor_node_paths.duplicate(),
		"solved_anchor_positions_weapon_local": chain_player.current_solved_anchor_positions_weapon_local.duplicate(),
		"solved_anchor_rotations_weapon_local": chain_player.current_solved_anchor_rotations_weapon_local.duplicate(),
		"solved_anchor_scales_weapon_local": chain_player.current_solved_anchor_scales_weapon_local.duplicate(),
		"solved_anchor_origin_id": chain_player.current_solved_anchor_origin_id,
		"solved_replay_bridge_frame": chain_player.current_solved_replay_bridge_frame,
		"trajectory_volume_state": chain_player.current_trajectory_volume_state,
	}

func _build_effective_idle_motion_node() -> CombatAnimationMotionNode:
	if active_idle_motion_node_chain.is_empty():
		return null
	var base_motion_node: CombatAnimationMotionNode = active_idle_motion_node_chain[0] as CombatAnimationMotionNode
	var effective_motion_node: CombatAnimationMotionNode = (
		base_motion_node.duplicate_node()
		if base_motion_node != null
		else CombatAnimationMotionNodeScript.new() as CombatAnimationMotionNode
	)
	if _idle_chain_player_state_available():
		effective_motion_node.tip_position_local = idle_chain_player.current_tip_position
		effective_motion_node.tip_position_origin_id = idle_chain_player.current_tip_position_origin_id
		effective_motion_node.pommel_position_local = idle_chain_player.current_pommel_position
		effective_motion_node.pommel_position_origin_id = idle_chain_player.current_pommel_position_origin_id
		effective_motion_node.weapon_orientation_degrees = idle_chain_player.current_weapon_orientation_degrees
		effective_motion_node.weapon_orientation_authored = true
		effective_motion_node.weapon_roll_degrees = idle_chain_player.current_weapon_roll
		effective_motion_node.axial_reposition_offset = idle_chain_player.current_axial_reposition
		effective_motion_node.grip_seat_slide_offset = idle_chain_player.current_grip_seat_slide
		effective_motion_node.secondary_grip_seat_slide_offset = idle_chain_player.current_secondary_grip_seat_slide
		effective_motion_node.body_support_blend = idle_chain_player.current_body_support_blend
		effective_motion_node.right_upperarm_roll_degrees = idle_chain_player.current_right_upperarm_roll
		effective_motion_node.left_upperarm_roll_degrees = idle_chain_player.current_left_upperarm_roll
		effective_motion_node.two_hand_state = idle_chain_player.current_two_hand_state
		effective_motion_node.primary_hand_slot = idle_chain_player.current_primary_hand_slot
		effective_motion_node.preferred_grip_style_mode = idle_chain_player.current_preferred_grip_style_mode
	effective_motion_node.normalize()
	return effective_motion_node

func _build_idle_playback_state(effective_motion_node: CombatAnimationMotionNode) -> Dictionary:
	if effective_motion_node == null:
		return {}
	var chain_player_state_available: bool = _idle_chain_player_state_available()
	var contact_grip_axis_local: Vector3 = idle_chain_player.current_contact_grip_axis_local if chain_player_state_available else Vector3.ZERO
	var contact_grip_axis_override_active: bool = idle_chain_player.current_contact_grip_axis_local_override_active if chain_player_state_available else false
	return {
		"active": runtime_idle_active,
		"tip_position_local": effective_motion_node.tip_position_local,
		"tip_position_origin_id": effective_motion_node.tip_position_origin_id,
		"pommel_position_local": effective_motion_node.pommel_position_local,
		"pommel_position_origin_id": effective_motion_node.pommel_position_origin_id,
		"weapon_orientation_degrees": effective_motion_node.weapon_orientation_degrees,
		"weapon_roll_degrees": effective_motion_node.weapon_roll_degrees,
		"axial_reposition_offset": effective_motion_node.axial_reposition_offset,
		"grip_seat_slide_offset": effective_motion_node.grip_seat_slide_offset,
		"secondary_grip_seat_slide_offset": effective_motion_node.secondary_grip_seat_slide_offset,
		"body_support_blend": effective_motion_node.body_support_blend,
		"right_upperarm_roll_degrees": effective_motion_node.right_upperarm_roll_degrees,
		"left_upperarm_roll_degrees": effective_motion_node.left_upperarm_roll_degrees,
		"two_hand_state": effective_motion_node.two_hand_state,
		"primary_hand_slot": effective_motion_node.primary_hand_slot,
		"preferred_grip_style_mode": effective_motion_node.preferred_grip_style_mode,
		"contact_grip_axis_local": contact_grip_axis_local,
		"contact_grip_axis_origin_id": idle_chain_player.current_contact_grip_axis_origin_id if chain_player_state_available else CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING,
		"contact_grip_axis_local_override_active": contact_grip_axis_override_active,
		"upper_body_pose_available": idle_chain_player.current_upper_body_pose_available if chain_player_state_available else false,
		"upper_body_bone_names": idle_chain_player.current_upper_body_bone_names.duplicate() if chain_player_state_available else [],
		"upper_body_bone_pose_rotations": idle_chain_player.current_upper_body_bone_pose_rotations.duplicate() if chain_player_state_available else [],
		"solved_replay_available": idle_chain_player.current_solved_replay_available if chain_player_state_available else false,
		"solved_replay_reference_bone_name": idle_chain_player.current_solved_replay_reference_bone_name if chain_player_state_available else StringName(),
		"solved_replay_reference_origin_id": idle_chain_player.current_solved_replay_reference_origin_id if chain_player_state_available else CombatOriginRecordScript.ORIGIN_SOLVED_REPLAY_REFERENCE,
		"solved_upper_body_bone_names": idle_chain_player.current_solved_upper_body_bone_names.duplicate() if chain_player_state_available else [],
		"solved_upper_body_pose_positions": idle_chain_player.current_solved_upper_body_pose_positions.duplicate() if chain_player_state_available else [],
		"solved_upper_body_pose_rotations": idle_chain_player.current_solved_upper_body_pose_rotations.duplicate() if chain_player_state_available else [],
		"solved_upper_body_pose_scales": idle_chain_player.current_solved_upper_body_pose_scales.duplicate() if chain_player_state_available else [],
		"solved_weapon_position_reference_local": idle_chain_player.current_solved_weapon_position_reference_local if chain_player_state_available else Vector3.ZERO,
		"solved_weapon_rotation_reference_local": idle_chain_player.current_solved_weapon_rotation_reference_local if chain_player_state_available else Quaternion.IDENTITY,
		"solved_weapon_scale_reference_local": idle_chain_player.current_solved_weapon_scale_reference_local if chain_player_state_available else Vector3.ONE,
		"solved_weapon_reference_origin_id": idle_chain_player.current_solved_weapon_reference_origin_id if chain_player_state_available else CombatOriginRecordScript.ORIGIN_SOLVED_REPLAY_REFERENCE,
		"solved_anchor_node_paths": idle_chain_player.current_solved_anchor_node_paths.duplicate() if chain_player_state_available else [],
		"solved_anchor_positions_weapon_local": idle_chain_player.current_solved_anchor_positions_weapon_local.duplicate() if chain_player_state_available else [],
		"solved_anchor_rotations_weapon_local": idle_chain_player.current_solved_anchor_rotations_weapon_local.duplicate() if chain_player_state_available else [],
		"solved_anchor_scales_weapon_local": idle_chain_player.current_solved_anchor_scales_weapon_local.duplicate() if chain_player_state_available else [],
		"solved_anchor_origin_id": idle_chain_player.current_solved_anchor_origin_id if chain_player_state_available else CombatOriginRecordScript.ORIGIN_WEAPON_ROOT,
		"solved_replay_bridge_frame": idle_chain_player.current_solved_replay_bridge_frame if chain_player_state_available else false,
		"trajectory_volume_state": idle_chain_player.current_trajectory_volume_state if chain_player_state_available else {},
	}

func _idle_chain_player_state_available() -> bool:
	return (
		active_idle_motion_node_chain.size() >= 2
		or (active_idle_runtime_clip != null and active_idle_runtime_clip.is_playable())
	)

func _compile_runtime_idle_chain(
	motion_node_chain: Array,
	held_item: Node3D,
	held_item_nodes: Dictionary,
	dominant_slot_id: StringName,
	support_slot_id: StringName,
	default_two_hand: bool,
	trajectory_volume_config: Dictionary
) -> Dictionary:
	var support_hand_available: bool = _resolve_support_hand_available_for_item(
		held_item,
		held_item_nodes,
		support_slot_id
	)
	return runtime_chain_compiler.compile_idle_chain(
		motion_node_chain,
		_resolve_held_item_weapon_length_meters(held_item),
		trajectory_volume_config,
		{
			"support_hand_available": support_hand_available,
			"two_hand_allowed": default_two_hand and support_hand_available,
			"dominant_slot_id": dominant_slot_id,
			"support_slot_id": support_slot_id,
		}
	)

func _store_runtime_compile_debug(target_result: Dictionary, compile_result: Dictionary) -> void:
	target_result["runtime_compile_diagnostics"] = (compile_result.get("diagnostics", []) as Array).duplicate(true)
	target_result["runtime_compile_degraded_node_count"] = int(compile_result.get("degraded_node_count", 0))
	target_result["runtime_compile_hand_swap_bridge_count"] = int(compile_result.get("hand_swap_bridge_count", 0))
	target_result["runtime_compile_retarget_seeded_count"] = int(compile_result.get("retarget_seeded_count", 0))
	target_result["runtime_compile_retargeted_count"] = int(compile_result.get("retargeted_count", 0))
	target_result["runtime_compile_source_node_count"] = int(compile_result.get("source_node_count", 0))
	target_result["runtime_compile_effective_node_count"] = int(compile_result.get("effective_node_count", 0))

func _resolve_support_hand_requested(held_item: Node3D, held_item_nodes: Dictionary) -> bool:
	return _resolve_support_hand_requested_from_values(
		held_item,
		held_item_nodes,
		active_support_slot_id,
		active_default_two_hand,
		chain_player.current_preferred_grip_style_mode,
		chain_player.current_two_hand_state
	)

func _resolve_support_hand_requested_from_values(
	held_item: Node3D,
	held_item_nodes: Dictionary,
	support_slot_id: StringName,
	default_two_hand: bool,
	preferred_grip_style_mode: StringName,
	two_hand_state: StringName
) -> bool:
	if held_item == null or not bool(held_item.get_meta("two_hand_character_eligible", false)):
		return false
	if preferred_grip_style_mode == CraftedItemWIPScript.GRIP_REVERSE:
		return false
	if support_slot_id == StringName():
		return false
	var support_item: Node3D = held_item_nodes.get(support_slot_id) as Node3D
	if support_item != null and is_instance_valid(support_item):
		return false
	var support_anchor: Node3D = weapon_grip_anchor_provider.get_support_grip_anchor(held_item)
	if support_anchor == null and held_item.get_node_or_null("SecondaryGripGuide") == null:
		return false
	if two_hand_state == CombatAnimationMotionNodeScript.TWO_HAND_STATE_ONE_HAND:
		return false
	if two_hand_state == CombatAnimationMotionNodeScript.TWO_HAND_STATE_TWO_HAND:
		return true
	return default_two_hand

func _resolve_default_two_hand(held_item: Node3D, held_item_nodes: Dictionary) -> bool:
	return _resolve_default_two_hand_for_support_slot(held_item, held_item_nodes, active_support_slot_id)

func _resolve_support_hand_available_for_item(
	held_item: Node3D,
	held_item_nodes: Dictionary,
	support_slot_id: StringName
) -> bool:
	if held_item == null or not bool(held_item.get_meta("two_hand_character_eligible", false)):
		return false
	if support_slot_id == StringName():
		return false
	var support_item: Node3D = held_item_nodes.get(support_slot_id) as Node3D
	if support_item != null and is_instance_valid(support_item):
		return false
	var support_anchor: Node3D = weapon_grip_anchor_provider.get_support_grip_anchor(held_item)
	return support_anchor != null or held_item.get_node_or_null("SecondaryGripGuide") != null

func _resolve_default_two_hand_for_support_slot(
	held_item: Node3D,
	held_item_nodes: Dictionary,
	support_slot_id: StringName
) -> bool:
	if held_item == null or not bool(held_item.get_meta("two_hand_character_eligible", false)):
		return false
	if support_slot_id == StringName():
		return false
	var support_item: Node3D = held_item_nodes.get(support_slot_id) as Node3D
	return support_item == null or not is_instance_valid(support_item)

func _resolve_held_item_weapon_length_meters(held_item: Node3D) -> float:
	if held_item == null:
		return 0.0
	if held_item.has_meta("weapon_total_length_meters"):
		var meta_length: float = float(held_item.get_meta("weapon_total_length_meters"))
		if meta_length > 0.001:
			return meta_length
	var tip_local: Vector3 = _get_weapon_tip_meta(held_item)
	var pommel_local: Vector3 = _get_weapon_pommel_meta(held_item)
	var segment_length: float = tip_local.distance_to(pommel_local)
	return segment_length if segment_length > 0.001 else 0.0

func _resolve_source_equipment_slot_id(slot_activation_result: Dictionary, equipment_state) -> StringName:
	var result_slot_id: StringName = slot_activation_result.get("source_equipment_slot_id", StringName()) as StringName
	if result_slot_id != StringName():
		return result_slot_id
	var source_weapon_wip_id: StringName = slot_activation_result.get("source_weapon_wip_id", StringName()) as StringName
	if equipment_state == null or source_weapon_wip_id == StringName():
		return StringName()
	for equipped_slot_variant: Variant in equipment_state.get_equipped_slots():
		var equipped_slot: Resource = equipped_slot_variant as Resource
		if equipped_slot == null:
			continue
		if StringName(equipped_slot.get("source_wip_id")) == source_weapon_wip_id:
			return equipped_slot.get("slot_id") as StringName
	return StringName()

func _resolve_other_hand_slot_id(slot_id: StringName) -> StringName:
	if slot_id == &"hand_left":
		return &"hand_right"
	return &"hand_left"

func _claim_runtime_endpoint_authority(humanoid_rig: Node3D, held_item: Node3D) -> void:
	if humanoid_rig == null or held_item == null or not is_instance_valid(held_item):
		return
	var authority_root: Node3D = _ensure_runtime_endpoint_authority_root(humanoid_rig)
	if authority_root == null:
		return
	if humanoid_rig.has_method("sync_runtime_endpoint_authority_root_to_reference"):
		humanoid_rig.call("sync_runtime_endpoint_authority_root_to_reference", RUNTIME_SOLVED_REPLAY_REFERENCE_BONE)
	var previous_origin_id: StringName = _resolve_runtime_endpoint_previous_origin_id(held_item)
	held_item.set_meta(RUNTIME_ENDPOINT_AUTHORITY_ACTIVE_META, true)
	held_item.set_meta(
		RUNTIME_ENDPOINT_AUTHORITY_ORIGIN_META,
		CombatOriginRecordScript.ORIGIN_RUNTIME_ENDPOINT_AUTHORITY_ROOT
	)
	held_item.set_meta(RUNTIME_ENDPOINT_AUTHORITY_PREVIOUS_ORIGIN_META, previous_origin_id)
	if held_item.get_parent() == authority_root:
		return
	var preserved_global_transform: Transform3D = held_item.global_transform
	var current_parent: Node = held_item.get_parent()
	if current_parent != null:
		current_parent.remove_child(held_item)
	authority_root.add_child(held_item)
	held_item.global_transform = preserved_global_transform

func _release_runtime_endpoint_authority(
	humanoid_rig: Node3D,
	held_item_nodes: Dictionary,
	equipped_item_presenter: PlayerEquippedItemPresenter,
	equipment_state,
	weapons_drawn: bool
) -> void:
	if humanoid_rig == null or equipped_item_presenter == null:
		return
	for slot_id: StringName in [&"hand_right", &"hand_left"]:
		var held_item: Node3D = held_item_nodes.get(slot_id) as Node3D
		if held_item == null or not is_instance_valid(held_item):
			continue
		if bool(held_item.get_meta(RUNTIME_ENDPOINT_AUTHORITY_ACTIVE_META, false)):
			held_item.set_meta(RUNTIME_ENDPOINT_AUTHORITY_ACTIVE_META, false)
			held_item.set_meta(
				RUNTIME_ENDPOINT_AUTHORITY_ORIGIN_META,
				StringName(held_item.get_meta(
					RUNTIME_ENDPOINT_AUTHORITY_PREVIOUS_ORIGIN_META,
					CombatOriginRecordScript.ORIGIN_HAND_GRIP_ALIGNMENT
				))
			)
	equipped_item_presenter.reanchor_equipped_item_nodes(
		humanoid_rig,
		held_item_nodes,
		equipment_state,
		weapons_drawn
	)

func _ensure_runtime_endpoint_authority_root(humanoid_rig: Node3D) -> Node3D:
	if humanoid_rig == null:
		return null
	var authority_root: Node3D = humanoid_rig.get_node_or_null(RUNTIME_ENDPOINT_AUTHORITY_ROOT_NAME) as Node3D
	if authority_root != null:
		authority_root.set_meta(
			RUNTIME_ENDPOINT_AUTHORITY_ORIGIN_META,
			CombatOriginRecordScript.ORIGIN_RUNTIME_ENDPOINT_AUTHORITY_ROOT
		)
		return authority_root
	authority_root = Node3D.new()
	authority_root.name = RUNTIME_ENDPOINT_AUTHORITY_ROOT_NAME
	authority_root.set_meta(
		RUNTIME_ENDPOINT_AUTHORITY_ORIGIN_META,
		CombatOriginRecordScript.ORIGIN_RUNTIME_ENDPOINT_AUTHORITY_ROOT
	)
	humanoid_rig.add_child(authority_root)
	return authority_root

func _resolve_runtime_endpoint_previous_origin_id(held_item: Node3D) -> StringName:
	if held_item == null:
		return CombatOriginRecordScript.ORIGIN_RL_BONE_ROOT
	var previous_origin_id: StringName = StringName(held_item.get_meta(
		RUNTIME_ENDPOINT_AUTHORITY_PREVIOUS_ORIGIN_META,
		StringName()
	))
	if bool(held_item.get_meta(RUNTIME_ENDPOINT_AUTHORITY_ACTIVE_META, false)) and previous_origin_id != StringName():
		return previous_origin_id
	var equipped_anchor_origin_id: StringName = StringName(held_item.get_meta(
		"equipped_visual_anchor_origin_id",
		StringName()
	))
	if equipped_anchor_origin_id != StringName():
		return equipped_anchor_origin_id
	if bool(held_item.get_meta("station_stow_motion_node_applied", false)):
		return CombatOriginRecordScript.ORIGIN_STOW_ANCHOR
	return CombatOriginRecordScript.ORIGIN_HAND_GRIP_ALIGNMENT

func _normalize_baseline_transform_origin_id(origin_id: StringName) -> StringName:
	if origin_id == StringName():
		return CombatOriginRecordScript.ORIGIN_HAND_GRIP_ALIGNMENT
	return origin_id

func _normalize_hand_slot_id(slot_id: StringName) -> StringName:
	if slot_id == &"hand_left":
		return &"hand_left"
	return &"hand_right"

func _capture_current_motion_node_for_slot(slot_id: StringName, fallback_node: CombatAnimationMotionNode = null) -> CombatAnimationMotionNode:
	if slot_id != StringName():
		if runtime_playback_active and active_dominant_slot_id == slot_id and not active_motion_node_chain.is_empty():
			return _build_chain_player_motion_node_snapshot(
				chain_player,
				active_motion_node_chain[0] as CombatAnimationMotionNode,
				&"runtime_skill_current_state"
			)
		if runtime_idle_active and active_idle_dominant_slot_id == slot_id and not active_idle_motion_node_chain.is_empty():
			if active_idle_motion_node_chain.size() >= 2:
				return _build_chain_player_motion_node_snapshot(
					idle_chain_player,
					active_idle_motion_node_chain[0] as CombatAnimationMotionNode,
					&"runtime_idle_current_state"
				)
			return _build_motion_node_from_pose_state(
				last_runtime_idle_pose_state,
				active_idle_motion_node_chain[0] as CombatAnimationMotionNode,
				&"runtime_idle_current_state"
			)
		if pending_recovery_motion_node != null and pending_recovery_dominant_slot_id == slot_id:
			var recovery_node: CombatAnimationMotionNode = pending_recovery_motion_node.duplicate_node()
			recovery_node.node_id = &"runtime_recovery_pending_state"
			recovery_node.node_index = 0
			recovery_node.normalize()
			return recovery_node
	var fallback_copy: CombatAnimationMotionNode = _duplicate_motion_node(fallback_node, &"runtime_authored_hidden_state")
	fallback_copy.node_index = 0
	fallback_copy.normalize()
	return fallback_copy

func _build_chain_player_motion_node_snapshot(
	source_chain_player: CombatAnimationChainPlayer,
	base_motion_node: CombatAnimationMotionNode,
	node_id: StringName
) -> CombatAnimationMotionNode:
	var snapshot: CombatAnimationMotionNode = _duplicate_motion_node(base_motion_node, node_id)
	if source_chain_player == null:
		return snapshot
	snapshot.tip_position_local = source_chain_player.current_tip_position
	snapshot.tip_position_origin_id = source_chain_player.current_tip_position_origin_id
	snapshot.pommel_position_local = source_chain_player.current_pommel_position
	snapshot.pommel_position_origin_id = source_chain_player.current_pommel_position_origin_id
	snapshot.tip_curve_in_handle = Vector3.ZERO
	snapshot.tip_curve_out_handle = Vector3.ZERO
	snapshot.pommel_curve_in_handle = Vector3.ZERO
	snapshot.pommel_curve_out_handle = Vector3.ZERO
	snapshot.weapon_orientation_degrees = source_chain_player.current_weapon_orientation_degrees
	snapshot.weapon_orientation_authored = true
	snapshot.weapon_roll_degrees = source_chain_player.current_weapon_roll
	snapshot.axial_reposition_offset = source_chain_player.current_axial_reposition
	snapshot.grip_seat_slide_offset = source_chain_player.current_grip_seat_slide
	snapshot.secondary_grip_seat_slide_offset = source_chain_player.current_secondary_grip_seat_slide
	snapshot.body_support_blend = source_chain_player.current_body_support_blend
	snapshot.right_upperarm_roll_degrees = source_chain_player.current_right_upperarm_roll
	snapshot.left_upperarm_roll_degrees = source_chain_player.current_left_upperarm_roll
	snapshot.two_hand_state = source_chain_player.current_two_hand_state
	snapshot.primary_hand_slot = source_chain_player.current_primary_hand_slot
	snapshot.preferred_grip_style_mode = source_chain_player.current_preferred_grip_style_mode
	snapshot.generated_transition_node = false
	snapshot.generated_transition_kind = CombatAnimationMotionNodeScript.TRANSITION_KIND_NONE
	snapshot.locked_for_authoring = false
	snapshot.node_index = 0
	snapshot.normalize()
	return snapshot

func _build_motion_node_from_pose_state(
	pose_state: Dictionary,
	base_motion_node: CombatAnimationMotionNode,
	node_id: StringName
) -> CombatAnimationMotionNode:
	var snapshot: CombatAnimationMotionNode = _duplicate_motion_node(base_motion_node, node_id)
	if pose_state.is_empty():
		return snapshot
	snapshot.tip_position_local = pose_state.get("tip_position_local", snapshot.tip_position_local) as Vector3
	snapshot.tip_position_origin_id = StringName(pose_state.get("tip_position_origin_id", snapshot.tip_position_origin_id))
	snapshot.pommel_position_local = pose_state.get("pommel_position_local", snapshot.pommel_position_local) as Vector3
	snapshot.pommel_position_origin_id = StringName(pose_state.get("pommel_position_origin_id", snapshot.pommel_position_origin_id))
	snapshot.weapon_orientation_degrees = pose_state.get("weapon_orientation_degrees", snapshot.weapon_orientation_degrees) as Vector3
	snapshot.weapon_orientation_authored = true
	snapshot.weapon_roll_degrees = float(pose_state.get("weapon_roll_degrees", snapshot.weapon_roll_degrees))
	snapshot.axial_reposition_offset = float(pose_state.get("axial_reposition_offset", snapshot.axial_reposition_offset))
	snapshot.grip_seat_slide_offset = float(pose_state.get("grip_seat_slide_offset", snapshot.grip_seat_slide_offset))
	snapshot.secondary_grip_seat_slide_offset = float(pose_state.get(
		"secondary_grip_seat_slide_offset",
		snapshot.secondary_grip_seat_slide_offset
	))
	snapshot.body_support_blend = float(pose_state.get("body_support_blend", snapshot.body_support_blend))
	snapshot.right_upperarm_roll_degrees = float(pose_state.get("right_upperarm_roll_degrees", snapshot.right_upperarm_roll_degrees))
	snapshot.left_upperarm_roll_degrees = float(pose_state.get("left_upperarm_roll_degrees", snapshot.left_upperarm_roll_degrees))
	snapshot.two_hand_state = StringName(pose_state.get("two_hand_state", snapshot.two_hand_state))
	snapshot.primary_hand_slot = StringName(pose_state.get("primary_hand_slot", snapshot.primary_hand_slot))
	snapshot.preferred_grip_style_mode = StringName(pose_state.get("preferred_grip_style_mode", snapshot.preferred_grip_style_mode))
	snapshot.generated_transition_node = false
	snapshot.generated_transition_kind = CombatAnimationMotionNodeScript.TRANSITION_KIND_NONE
	snapshot.locked_for_authoring = false
	snapshot.node_index = 0
	snapshot.normalize()
	return snapshot

func _build_runtime_chain_with_entry(
	authored_motion_node_chain: Array,
	entry_motion_node: CombatAnimationMotionNode,
	bridge_duration_seconds: float,
	first_authored_index: int,
	include_authored_tail: bool = true
) -> Dictionary:
	var result := {
		"motion_node_chain": [],
		"entry_bridge_active": false,
		"entry_bridge_duration_seconds": 0.0,
		"entry_grip_swap_active": false,
		"entry_hand_swap_active": false,
		"entry_source_grip_style_mode": StringName(),
		"entry_target_grip_style_mode": StringName(),
	}
	if authored_motion_node_chain.is_empty():
		return result
	var target_index: int = clampi(first_authored_index, 0, authored_motion_node_chain.size() - 1)
	var target_source: CombatAnimationMotionNode = authored_motion_node_chain[target_index] as CombatAnimationMotionNode
	if target_source == null:
		return result
	var start_node: CombatAnimationMotionNode = _duplicate_motion_node(entry_motion_node, &"runtime_entry_source")
	start_node.node_index = 0
	start_node.transition_duration_seconds = NO_OP_BRIDGE_DURATION_SECONDS
	start_node.tip_curve_in_handle = Vector3.ZERO
	start_node.tip_curve_out_handle = Vector3.ZERO
	start_node.pommel_curve_in_handle = Vector3.ZERO
	start_node.pommel_curve_out_handle = Vector3.ZERO
	start_node.generated_transition_node = false
	start_node.generated_transition_kind = CombatAnimationMotionNodeScript.TRANSITION_KIND_NONE
	start_node.locked_for_authoring = false
	start_node.normalize()

	var target_node: CombatAnimationMotionNode = _duplicate_motion_node(target_source, target_source.node_id)
	target_node.node_index = 1
	var bridge_active: bool = _motion_nodes_need_bridge(start_node, target_node)
	var grip_swap_active: bool = start_node.preferred_grip_style_mode != target_node.preferred_grip_style_mode
	var hand_swap_active: bool = _motion_nodes_need_primary_hand_swap_bridge(start_node, target_node)
	target_node.transition_duration_seconds = bridge_duration_seconds if bridge_active else NO_OP_BRIDGE_DURATION_SECONDS
	if grip_swap_active:
		target_node.generated_transition_node = true
		target_node.generated_transition_kind = CombatAnimationMotionNodeScript.TRANSITION_KIND_GRIP_STYLE_SWAP
		target_node.locked_for_authoring = true
	elif hand_swap_active:
		target_node.generated_transition_node = true
		target_node.generated_transition_kind = CombatAnimationMotionNodeScript.TRANSITION_KIND_PRIMARY_HAND_SWAP
		target_node.locked_for_authoring = true
	target_node.normalize()

	var prepared_chain: Array = [start_node, target_node]
	if include_authored_tail:
		for authored_index: int in range(target_index + 1, authored_motion_node_chain.size()):
			var authored_node: CombatAnimationMotionNode = authored_motion_node_chain[authored_index] as CombatAnimationMotionNode
			if authored_node == null:
				continue
			var runtime_node: CombatAnimationMotionNode = _duplicate_motion_node(authored_node, authored_node.node_id)
			runtime_node.node_index = prepared_chain.size()
			runtime_node.normalize()
			prepared_chain.append(runtime_node)
	result["motion_node_chain"] = prepared_chain
	result["entry_bridge_active"] = bridge_active
	result["entry_bridge_duration_seconds"] = target_node.transition_duration_seconds
	result["entry_grip_swap_active"] = grip_swap_active
	result["entry_hand_swap_active"] = hand_swap_active
	result["entry_source_grip_style_mode"] = start_node.preferred_grip_style_mode
	result["entry_target_grip_style_mode"] = target_node.preferred_grip_style_mode
	return result

func _motion_nodes_need_primary_hand_swap_bridge(from_node: CombatAnimationMotionNode, to_node: CombatAnimationMotionNode) -> bool:
	if from_node == null or to_node == null:
		return false
	var from_slot: StringName = CombatAnimationMotionNodeScript.normalize_primary_hand_slot(from_node.primary_hand_slot)
	var to_slot: StringName = CombatAnimationMotionNodeScript.normalize_primary_hand_slot(to_node.primary_hand_slot)
	if from_slot == CombatAnimationMotionNodeScript.PRIMARY_HAND_AUTO or to_slot == CombatAnimationMotionNodeScript.PRIMARY_HAND_AUTO:
		return false
	return from_slot != to_slot

func _duplicate_motion_node_chain(motion_node_chain: Array) -> Array:
	var duplicated_chain: Array = []
	for motion_node_variant: Variant in motion_node_chain:
		var motion_node: CombatAnimationMotionNode = motion_node_variant as CombatAnimationMotionNode
		if motion_node == null:
			continue
		var duplicate_node: CombatAnimationMotionNode = _duplicate_motion_node(motion_node, motion_node.node_id)
		duplicate_node.node_index = duplicated_chain.size()
		duplicate_node.normalize()
		duplicated_chain.append(duplicate_node)
	return duplicated_chain

func _duplicate_motion_node(source_node: CombatAnimationMotionNode, node_id: StringName = StringName()) -> CombatAnimationMotionNode:
	var duplicate_node: CombatAnimationMotionNode = (
		source_node.duplicate_node()
		if source_node != null
		else CombatAnimationMotionNodeScript.new() as CombatAnimationMotionNode
	)
	if node_id != StringName():
		duplicate_node.node_id = node_id
	return duplicate_node

func _motion_nodes_need_bridge(from_node: CombatAnimationMotionNode, to_node: CombatAnimationMotionNode) -> bool:
	if from_node == null or to_node == null:
		return true
	if from_node.tip_position_local.distance_to(to_node.tip_position_local) > MOTION_NODE_POSITION_EPSILON_METERS:
		return true
	if from_node.pommel_position_local.distance_to(to_node.pommel_position_local) > MOTION_NODE_POSITION_EPSILON_METERS:
		return true
	if _euler_degrees_delta_exceeds(from_node.weapon_orientation_degrees, to_node.weapon_orientation_degrees, MOTION_NODE_ANGLE_EPSILON_DEGREES):
		return true
	if absf(from_node.weapon_roll_degrees - to_node.weapon_roll_degrees) > MOTION_NODE_ANGLE_EPSILON_DEGREES:
		return true
	if absf(from_node.axial_reposition_offset - to_node.axial_reposition_offset) > MOTION_NODE_FLOAT_EPSILON:
		return true
	if absf(from_node.grip_seat_slide_offset - to_node.grip_seat_slide_offset) > MOTION_NODE_FLOAT_EPSILON:
		return true
	if absf(from_node.secondary_grip_seat_slide_offset - to_node.secondary_grip_seat_slide_offset) > MOTION_NODE_FLOAT_EPSILON:
		return true
	if absf(from_node.body_support_blend - to_node.body_support_blend) > MOTION_NODE_FLOAT_EPSILON:
		return true
	if absf(from_node.right_upperarm_roll_degrees - to_node.right_upperarm_roll_degrees) > MOTION_NODE_ANGLE_EPSILON_DEGREES:
		return true
	if absf(from_node.left_upperarm_roll_degrees - to_node.left_upperarm_roll_degrees) > MOTION_NODE_ANGLE_EPSILON_DEGREES:
		return true
	if from_node.two_hand_state != to_node.two_hand_state:
		return true
	if from_node.primary_hand_slot != to_node.primary_hand_slot:
		return true
	return from_node.preferred_grip_style_mode != to_node.preferred_grip_style_mode

func _euler_degrees_delta_exceeds(from_degrees: Vector3, to_degrees: Vector3, epsilon_degrees: float) -> bool:
	return (
		absf(wrapf(to_degrees.x - from_degrees.x, -180.0, 180.0)) > epsilon_degrees
		or absf(wrapf(to_degrees.y - from_degrees.y, -180.0, 180.0)) > epsilon_degrees
		or absf(wrapf(to_degrees.z - from_degrees.z, -180.0, 180.0)) > epsilon_degrees
	)

func _resolve_runtime_trajectory_volume_config(
	humanoid_rig: Node3D,
	held_item: Node3D,
	slot_id: StringName
) -> Dictionary:
	if humanoid_rig == null or held_item == null or not is_instance_valid(held_item):
		return {}
	var trajectory_root := Node3D.new()
	trajectory_root.top_level = true
	humanoid_rig.add_child(trajectory_root)
	trajectory_root.global_transform = live_pose_presenter._resolve_trajectory_authoring_transform(humanoid_rig)
	var volume_config: Dictionary = live_pose_presenter.build_trajectory_volume_config_for_actor(
		humanoid_rig,
		trajectory_root,
		held_item,
		slot_id
	)
	humanoid_rig.remove_child(trajectory_root)
	trajectory_root.queue_free()
	return volume_config

func _apply_entry_bridge_debug(entry_chain_result: Dictionary) -> void:
	last_entry_bridge_active = bool(entry_chain_result.get("entry_bridge_active", false))
	last_entry_bridge_duration_seconds = float(entry_chain_result.get("entry_bridge_duration_seconds", 0.0))
	last_entry_grip_swap_active = bool(entry_chain_result.get("entry_grip_swap_active", false))
	last_entry_hand_swap_active = bool(entry_chain_result.get("entry_hand_swap_active", false))
	last_entry_source_grip_style_mode = entry_chain_result.get("entry_source_grip_style_mode", StringName()) as StringName
	last_entry_target_grip_style_mode = entry_chain_result.get("entry_target_grip_style_mode", StringName()) as StringName

func _begin_entry_hidden_bridge(
	entry_chain_result: Dictionary,
	dominant_slot_id: StringName,
	was_runtime_playback_active: bool,
	slot_activation_result: Dictionary
) -> void:
	var bridge_kind: StringName = (
		PlayerRuntimeHiddenBridgeStateScript.KIND_SKILL_INTERRUPT_ENTRY
		if was_runtime_playback_active
		else PlayerRuntimeHiddenBridgeStateScript.KIND_SKILL_ENTRY
	)
	var target_context_id: StringName = slot_activation_result.get("slot_id", StringName()) as StringName
	if target_context_id == StringName():
		target_context_id = slot_activation_result.get("source_skill_draft_id", StringName()) as StringName
	hidden_bridge_state.begin(
		bridge_kind,
		float(entry_chain_result.get("entry_bridge_duration_seconds", 0.0)),
		dominant_slot_id,
		&"runtime_skill" if was_runtime_playback_active else CombatAnimationStationStateScript.IDLE_CONTEXT_COMBAT,
		target_context_id,
		entry_chain_result.get("entry_source_grip_style_mode", StringName()) as StringName,
		entry_chain_result.get("entry_target_grip_style_mode", StringName()) as StringName,
		bool(entry_chain_result.get("entry_grip_swap_active", false)),
		bool(entry_chain_result.get("entry_bridge_active", false))
	)

func _apply_recovery_bridge_debug(recovery_chain_result: Dictionary) -> void:
	last_recovery_bridge_active = bool(recovery_chain_result.get("entry_bridge_active", false))
	last_recovery_bridge_duration_seconds = float(recovery_chain_result.get("entry_bridge_duration_seconds", 0.0))
	last_recovery_grip_swap_active = bool(recovery_chain_result.get("entry_grip_swap_active", false))
	last_recovery_hand_swap_active = bool(recovery_chain_result.get("entry_hand_swap_active", false))
	last_recovery_source_grip_style_mode = recovery_chain_result.get("entry_source_grip_style_mode", StringName()) as StringName
	last_recovery_target_grip_style_mode = recovery_chain_result.get("entry_target_grip_style_mode", StringName()) as StringName

func _begin_recovery_hidden_bridge(
	recovery_chain_result: Dictionary,
	dominant_slot_id: StringName,
	idle_pose_result: Dictionary
) -> void:
	hidden_bridge_state.begin(
		PlayerRuntimeHiddenBridgeStateScript.KIND_SKILL_RECOVERY,
		float(recovery_chain_result.get("entry_bridge_duration_seconds", 0.0)),
		dominant_slot_id,
		&"runtime_skill",
		idle_pose_result.get("idle_context_id", CombatAnimationStationStateScript.IDLE_CONTEXT_COMBAT) as StringName,
		recovery_chain_result.get("entry_source_grip_style_mode", StringName()) as StringName,
		recovery_chain_result.get("entry_target_grip_style_mode", StringName()) as StringName,
		bool(recovery_chain_result.get("entry_grip_swap_active", false)),
		bool(recovery_chain_result.get("entry_bridge_active", false))
	)

func _clear_recovery_bridge_debug() -> void:
	last_recovery_bridge_active = false
	last_recovery_bridge_duration_seconds = 0.0
	last_recovery_grip_swap_active = false
	last_recovery_hand_swap_active = false
	last_recovery_source_grip_style_mode = StringName()
	last_recovery_target_grip_style_mode = StringName()

func _clear_pending_recovery_state() -> void:
	pending_recovery_motion_node = null
	pending_recovery_dominant_slot_id = StringName()

func _build_idle_source_key(
	idle_pose_result: Dictionary,
	dominant_slot_id: StringName,
	motion_node_chain: Array,
	current_weapon_length_meters: float = 0.0
) -> String:
	return "%s|%s|%s|%s|%d|%.4f" % [
		String(dominant_slot_id),
		String(idle_pose_result.get("source_weapon_wip_id", StringName())),
		String(idle_pose_result.get("draft_id", StringName())),
		String(idle_pose_result.get("idle_context_id", StringName())),
		motion_node_chain.size(),
		current_weapon_length_meters,
	]

func _bake_runtime_playback_clip(motion_node_chain: Array, options: Dictionary):
	if runtime_clip_baker == null or motion_node_chain.is_empty():
		return null
	var clip = runtime_clip_baker.bake_from_motion_node_chain(motion_node_chain, options)
	if clip == null or not clip.is_playable():
		return null
	return clip

func _resolve_cached_runtime_clip(source_result: Dictionary):
	var runtime_clip = source_result.get("baked_runtime_clip", null)
	if runtime_clip == null:
		return null
	var clip_copy = null
	if runtime_clip.has_method("duplicate_clip"):
		clip_copy = runtime_clip.call("duplicate_clip")
	elif runtime_clip is Resource:
		clip_copy = (runtime_clip as Resource).duplicate(true)
	else:
		clip_copy = runtime_clip
	if clip_copy == null:
		return null
	if clip_copy.has_method("normalize"):
		clip_copy.call("normalize")
	var has_legacy_pose_track: bool = clip_copy.has_method("has_upper_body_pose_track") and bool(clip_copy.call("has_upper_body_pose_track"))
	var has_solved_replay_track: bool = clip_copy.has_method("has_solved_replay_track") and bool(clip_copy.call("has_solved_replay_track"))
	if not has_legacy_pose_track and not has_solved_replay_track:
		return null
	if (
		has_legacy_pose_track
		and StringName(clip_copy.get("upper_body_pose_track_source")) != CombatRuntimeClipScript.UPPER_BODY_POSE_TRACK_SOURCE_SKILL_CRAFTER_AUTHORED_POSE
	):
		return null
	if (
		has_solved_replay_track
		and StringName(clip_copy.get("solved_replay_track_source")) != CombatRuntimeClipScript.SOLVED_REPLAY_TRACK_SOURCE_SKILL_CRAFTER_F_PLAYBACK
	):
		return null
	return clip_copy

func _capture_runtime_solved_replay_bridge_snapshot(
	humanoid_rig: Node3D,
	held_item: Node3D,
	target_source_clip
) -> Dictionary:
	if humanoid_rig == null or held_item == null or not is_instance_valid(held_item) or target_source_clip == null:
		return {}
	if (
		not target_source_clip.has_method("has_solved_replay_track")
		or not bool(target_source_clip.call("has_solved_replay_track"))
	):
		return {}
	if (
		not humanoid_rig.has_method("capture_runtime_upper_body_pose_frame")
		or not humanoid_rig.has_method("capture_runtime_solved_replay_weapon_frame")
	):
		return {}
	var bone_names: Array = target_source_clip.get("baked_solved_upper_body_bone_names") as Array
	if bone_names.is_empty():
		return {}
	var anchor_paths: Array = target_source_clip.get("baked_solved_anchor_node_paths") as Array
	var pose_snapshot: Dictionary = humanoid_rig.call("capture_runtime_upper_body_pose_frame", bone_names) as Dictionary
	var captured_bone_names: Array = pose_snapshot.get("bone_names", []) as Array
	if captured_bone_names.size() != bone_names.size():
		return {}
	var reference_bone_name: StringName = StringName(target_source_clip.get("solved_replay_reference_bone_name"))
	if reference_bone_name == StringName():
		reference_bone_name = RUNTIME_SOLVED_REPLAY_REFERENCE_BONE
	var weapon_snapshot: Dictionary = humanoid_rig.call(
		"capture_runtime_solved_replay_weapon_frame",
		held_item,
		reference_bone_name,
		anchor_paths
	) as Dictionary
	if not bool(weapon_snapshot.get("valid", false)):
		return {}
	return {
		"valid": true,
		"bone_names": captured_bone_names.duplicate(),
		"pose_positions": pose_snapshot.get("pose_positions", PackedVector3Array()),
		"pose_rotations": pose_snapshot.get("pose_rotations", PackedVector4Array()),
		"pose_scales": pose_snapshot.get("pose_scales", PackedVector3Array()),
		"reference_bone_name": weapon_snapshot.get("reference_bone_name", RUNTIME_SOLVED_REPLAY_REFERENCE_BONE),
		"reference_origin_id": weapon_snapshot.get("reference_origin_id", CombatOriginRecordScript.ORIGIN_SOLVED_REPLAY_REFERENCE),
		"weapon_position_reference_local": weapon_snapshot.get("weapon_position_reference_local", Vector3.ZERO),
		"weapon_rotation_reference_local": weapon_snapshot.get("weapon_rotation_reference_local", Quaternion.IDENTITY),
		"weapon_scale_reference_local": weapon_snapshot.get("weapon_scale_reference_local", Vector3.ONE),
		"weapon_reference_origin_id": weapon_snapshot.get("weapon_reference_origin_id", CombatOriginRecordScript.ORIGIN_SOLVED_REPLAY_REFERENCE),
		"anchor_node_paths": weapon_snapshot.get("anchor_node_paths", []),
		"anchor_positions_weapon_local": weapon_snapshot.get("anchor_positions_weapon_local", PackedVector3Array()),
		"anchor_rotations_weapon_local": weapon_snapshot.get("anchor_rotations_weapon_local", PackedVector4Array()),
		"anchor_scales_weapon_local": weapon_snapshot.get("anchor_scales_weapon_local", PackedVector3Array()),
		"anchor_origin_id": weapon_snapshot.get("anchor_origin_id", CombatOriginRecordScript.ORIGIN_WEAPON_ROOT),
	}

func _copy_cached_upper_body_pose_track(
	target_clip,
	source_clip,
	target_time_offset_seconds: float = 0.0,
	bridge_source_snapshot: Dictionary = {}
) -> bool:
	if target_clip == null or source_clip == null:
		return false
	var target_frame_times: PackedFloat32Array = target_clip.get("baked_frame_times") as PackedFloat32Array
	var source_frame_times: PackedFloat32Array = source_clip.get("baked_frame_times") as PackedFloat32Array
	if source_frame_times.is_empty() or target_frame_times.is_empty():
		return false
	var source_duration: float = maxf(float(source_clip.get("total_duration_seconds")), 0.0)
	if source_duration <= 0.000001:
		source_duration = float(source_frame_times[source_frame_times.size() - 1])
	var time_offset: float = maxf(target_time_offset_seconds, 0.0)
	var legacy_pose_copied: bool = false
	if (
		source_clip.has_method("has_upper_body_pose_track")
		and bool(source_clip.call("has_upper_body_pose_track"))
		and StringName(source_clip.get("upper_body_pose_track_source")) == CombatRuntimeClipScript.UPPER_BODY_POSE_TRACK_SOURCE_SKILL_CRAFTER_AUTHORED_POSE
	):
		var source_bone_names: Array = source_clip.get("baked_upper_body_bone_names") as Array
		var source_pose_frames: Array = source_clip.get("baked_upper_body_bone_pose_rotations") as Array
		if not source_bone_names.is_empty() and not source_pose_frames.is_empty():
			var target_pose_frames: Array = []
			for target_time_variant: Variant in target_frame_times:
				var target_time: float = float(target_time_variant)
				if target_time < time_offset - 0.0001:
					target_pose_frames.append(PackedVector4Array())
					continue
				var source_time: float = clampf(target_time - time_offset, 0.0, source_duration)
				var sampled_frame: PackedVector4Array = _sample_cached_upper_body_pose_frame(
					source_frame_times,
					source_pose_frames,
					source_time,
					source_bone_names.size()
				)
				if sampled_frame.is_empty():
					return false
				target_pose_frames.append(sampled_frame)
			target_clip.set("baked_upper_body_bone_names", source_bone_names.duplicate())
			target_clip.set("baked_upper_body_bone_pose_rotations", target_pose_frames)
			target_clip.set("upper_body_pose_track_source", source_clip.get("upper_body_pose_track_source"))
			legacy_pose_copied = true
	var solved_replay_copied: bool = _copy_cached_solved_replay_track(
		target_clip,
		source_clip,
		source_frame_times,
		target_frame_times,
		source_duration,
		time_offset,
		bridge_source_snapshot
	)
	if target_clip.has_method("normalize"):
		target_clip.call("normalize")
	return legacy_pose_copied or solved_replay_copied

func _sample_cached_upper_body_pose_frame(
	source_frame_times: PackedFloat32Array,
	source_pose_frames: Array,
	source_time_seconds: float,
	expected_bone_count: int
) -> PackedVector4Array:
	if source_frame_times.is_empty() or source_pose_frames.is_empty() or expected_bone_count <= 0:
		return PackedVector4Array()
	var frame_count: int = mini(source_frame_times.size(), source_pose_frames.size())
	if frame_count <= 0:
		return PackedVector4Array()
	if frame_count == 1 or source_time_seconds <= float(source_frame_times[0]):
		return _duplicate_cached_upper_body_pose_frame(source_pose_frames[0], expected_bone_count)
	if source_time_seconds >= float(source_frame_times[frame_count - 1]):
		return _duplicate_cached_upper_body_pose_frame(source_pose_frames[frame_count - 1], expected_bone_count)
	var from_index: int = 0
	while from_index < frame_count - 2 and source_time_seconds > float(source_frame_times[from_index + 1]):
		from_index += 1
	var to_index: int = mini(from_index + 1, frame_count - 1)
	var from_time: float = float(source_frame_times[from_index])
	var to_time: float = float(source_frame_times[to_index])
	var ratio: float = 0.0
	if to_time > from_time:
		ratio = clampf((source_time_seconds - from_time) / (to_time - from_time), 0.0, 1.0)
	return _interpolate_cached_upper_body_pose_frame(
		source_pose_frames[from_index],
		source_pose_frames[to_index],
		ratio,
		expected_bone_count
	)

func _duplicate_cached_upper_body_pose_frame(frame_data: Variant, expected_bone_count: int) -> PackedVector4Array:
	var rotations: Array[Quaternion] = _decode_cached_upper_body_pose_frame(frame_data)
	if rotations.size() != expected_bone_count:
		return PackedVector4Array()
	var packed := PackedVector4Array()
	for rotation: Quaternion in rotations:
		var normalized_rotation: Quaternion = rotation.normalized()
		packed.append(Vector4(normalized_rotation.x, normalized_rotation.y, normalized_rotation.z, normalized_rotation.w))
	return packed

func _interpolate_cached_upper_body_pose_frame(
	from_frame_data: Variant,
	to_frame_data: Variant,
	ratio: float,
	expected_bone_count: int
) -> PackedVector4Array:
	var from_rotations: Array[Quaternion] = _decode_cached_upper_body_pose_frame(from_frame_data)
	var to_rotations: Array[Quaternion] = _decode_cached_upper_body_pose_frame(to_frame_data)
	if from_rotations.size() != expected_bone_count or to_rotations.size() != expected_bone_count:
		return PackedVector4Array()
	var clean_ratio: float = clampf(ratio, 0.0, 1.0)
	var packed := PackedVector4Array()
	for rotation_index: int in range(expected_bone_count):
		var interpolated_rotation: Quaternion = from_rotations[rotation_index].slerp(
			to_rotations[rotation_index],
			clean_ratio
		).normalized()
		packed.append(Vector4(
			interpolated_rotation.x,
			interpolated_rotation.y,
			interpolated_rotation.z,
			interpolated_rotation.w
		))
	return packed

func _decode_cached_upper_body_pose_frame(frame_data: Variant) -> Array[Quaternion]:
	var rotations: Array[Quaternion] = []
	if frame_data is PackedVector4Array:
		var packed_rotations: PackedVector4Array = frame_data as PackedVector4Array
		for vector_value: Vector4 in packed_rotations:
			rotations.append(Quaternion(vector_value.x, vector_value.y, vector_value.z, vector_value.w).normalized())
		return rotations
	if frame_data is Array:
		var rotation_array: Array = frame_data as Array
		for rotation_variant: Variant in rotation_array:
			if rotation_variant is Quaternion:
				rotations.append((rotation_variant as Quaternion).normalized())
			elif rotation_variant is Vector4:
				var vector_rotation: Vector4 = rotation_variant as Vector4
				rotations.append(Quaternion(vector_rotation.x, vector_rotation.y, vector_rotation.z, vector_rotation.w).normalized())
	return rotations

func _copy_cached_solved_replay_track(
	target_clip,
	source_clip,
	source_frame_times: PackedFloat32Array,
	target_frame_times: PackedFloat32Array,
	source_duration: float,
	time_offset: float,
	bridge_source_snapshot: Dictionary = {}
) -> bool:
	if target_clip == null or source_clip == null:
		return false
	if not source_clip.has_method("has_solved_replay_track") or not bool(source_clip.call("has_solved_replay_track")):
		return false
	if StringName(source_clip.get("solved_replay_track_source")) != CombatRuntimeClipScript.SOLVED_REPLAY_TRACK_SOURCE_SKILL_CRAFTER_F_PLAYBACK:
		return false
	var source_bone_names: Array = source_clip.get("baked_solved_upper_body_bone_names") as Array
	var source_anchor_paths: Array = source_clip.get("baked_solved_anchor_node_paths") as Array
	var source_position_frames: Array = source_clip.get("baked_solved_upper_body_pose_positions") as Array
	var source_rotation_frames: Array = source_clip.get("baked_solved_upper_body_pose_rotations") as Array
	var source_scale_frames: Array = source_clip.get("baked_solved_upper_body_pose_scales") as Array
	var source_anchor_position_frames: Array = source_clip.get("baked_solved_anchor_positions_weapon_local") as Array
	var source_anchor_rotation_frames: Array = source_clip.get("baked_solved_anchor_rotations_weapon_local") as Array
	var source_anchor_scale_frames: Array = source_clip.get("baked_solved_anchor_scales_weapon_local") as Array
	var source_weapon_positions: PackedVector3Array = source_clip.get("baked_solved_weapon_positions_reference_local") as PackedVector3Array
	var source_weapon_rotations: PackedVector4Array = source_clip.get("baked_solved_weapon_rotations_reference_local") as PackedVector4Array
	var source_weapon_scales: PackedVector3Array = source_clip.get("baked_solved_weapon_scales_reference_local") as PackedVector3Array
	var source_available: Array = source_clip.get("baked_solved_replay_frame_available") as Array
	if (
		source_bone_names.is_empty()
		or source_position_frames.is_empty()
		or source_rotation_frames.is_empty()
		or source_scale_frames.is_empty()
		or source_weapon_positions.is_empty()
		or source_weapon_rotations.is_empty()
		or source_weapon_scales.is_empty()
		or source_available.is_empty()
	):
		return false
	var target_available: Array = []
	var target_position_frames: Array = []
	var target_rotation_frames: Array = []
	var target_scale_frames: Array = []
	var target_weapon_positions := PackedVector3Array()
	var target_weapon_rotations := PackedVector4Array()
	var target_weapon_scales := PackedVector3Array()
	var target_anchor_position_frames: Array = []
	var target_anchor_rotation_frames: Array = []
	var target_anchor_scale_frames: Array = []
	var target_bridge_frame_flags: Array = []
	var first_available_source_frame_index: int = _resolve_first_available_solved_replay_frame_index(source_available)
	var bridge_source_snapshot_valid: bool = (
		time_offset > 0.0001
		and first_available_source_frame_index >= 0
		and _is_valid_solved_replay_bridge_snapshot(bridge_source_snapshot, source_bone_names, source_anchor_paths)
	)
	for target_time_variant: Variant in target_frame_times:
		var target_time: float = float(target_time_variant)
		if target_time < time_offset - 0.0001:
			if bridge_source_snapshot_valid:
				var bridge_ratio: float = clampf(target_time / time_offset, 0.0, 1.0)
				var eased_bridge_ratio: float = bridge_ratio * bridge_ratio * (3.0 - (2.0 * bridge_ratio))
				var bridge_frame_appended: bool = _append_interpolated_solved_replay_bridge_frame(
					target_available,
					target_position_frames,
					target_rotation_frames,
					target_scale_frames,
					target_weapon_positions,
					target_weapon_rotations,
					target_weapon_scales,
					target_anchor_position_frames,
					target_anchor_rotation_frames,
					target_anchor_scale_frames,
					bridge_source_snapshot,
					source_position_frames[first_available_source_frame_index],
					source_rotation_frames[first_available_source_frame_index],
					source_scale_frames[first_available_source_frame_index],
					source_weapon_positions[first_available_source_frame_index],
					_quaternion_from_vector4(source_weapon_rotations[first_available_source_frame_index], Quaternion.IDENTITY),
					source_weapon_scales[first_available_source_frame_index],
					source_anchor_position_frames[first_available_source_frame_index],
					source_anchor_rotation_frames[first_available_source_frame_index],
					source_anchor_scale_frames[first_available_source_frame_index],
					source_bone_names.size(),
					source_anchor_paths.size(),
					eased_bridge_ratio
				)
				if not bridge_frame_appended:
					_append_unavailable_solved_replay_frame(
						target_available,
						target_position_frames,
						target_rotation_frames,
						target_scale_frames,
						target_weapon_positions,
						target_weapon_rotations,
						target_weapon_scales,
						target_anchor_position_frames,
						target_anchor_rotation_frames,
						target_anchor_scale_frames
					)
					target_bridge_frame_flags.append(false)
				else:
					target_bridge_frame_flags.append(true)
			else:
				_append_unavailable_solved_replay_frame(
					target_available,
					target_position_frames,
					target_rotation_frames,
					target_scale_frames,
					target_weapon_positions,
					target_weapon_rotations,
					target_weapon_scales,
					target_anchor_position_frames,
					target_anchor_rotation_frames,
					target_anchor_scale_frames
				)
				target_bridge_frame_flags.append(false)
			continue
		var source_time: float = clampf(target_time - time_offset, 0.0, source_duration)
		var source_frame_index: int = _resolve_nearest_cached_frame_index(source_frame_times, source_time)
		if source_frame_index < 0 or source_frame_index >= source_available.size() or not bool(source_available[source_frame_index]):
			_append_unavailable_solved_replay_frame(
				target_available,
				target_position_frames,
				target_rotation_frames,
				target_scale_frames,
				target_weapon_positions,
				target_weapon_rotations,
				target_weapon_scales,
				target_anchor_position_frames,
				target_anchor_rotation_frames,
				target_anchor_scale_frames
			)
			target_bridge_frame_flags.append(false)
			continue
		var sampled_positions: PackedVector3Array = _duplicate_cached_vector3_frame(
			source_position_frames[source_frame_index],
			source_bone_names.size()
		)
		var sampled_rotations: PackedVector4Array = _duplicate_cached_upper_body_pose_frame(
			source_rotation_frames[source_frame_index],
			source_bone_names.size()
		)
		var sampled_scales: PackedVector3Array = _duplicate_cached_vector3_frame(
			source_scale_frames[source_frame_index],
			source_bone_names.size()
		)
		var sampled_anchor_positions: PackedVector3Array = _duplicate_cached_vector3_frame(
			source_anchor_position_frames[source_frame_index],
			source_anchor_paths.size()
		)
		var sampled_anchor_rotations: PackedVector4Array = _duplicate_cached_upper_body_pose_frame(
			source_anchor_rotation_frames[source_frame_index],
			source_anchor_paths.size()
		)
		var sampled_anchor_scales: PackedVector3Array = _duplicate_cached_vector3_frame(
			source_anchor_scale_frames[source_frame_index],
			source_anchor_paths.size()
		)
		if (
			sampled_positions.is_empty()
			or sampled_rotations.is_empty()
			or sampled_scales.is_empty()
			or (not source_anchor_paths.is_empty() and (sampled_anchor_positions.is_empty() or sampled_anchor_rotations.is_empty() or sampled_anchor_scales.is_empty()))
		):
			return false
		target_available.append(true)
		target_position_frames.append(sampled_positions)
		target_rotation_frames.append(sampled_rotations)
		target_scale_frames.append(sampled_scales)
		target_weapon_positions.append(source_weapon_positions[source_frame_index])
		target_weapon_rotations.append(source_weapon_rotations[source_frame_index])
		target_weapon_scales.append(source_weapon_scales[source_frame_index])
		target_anchor_position_frames.append(sampled_anchor_positions)
		target_anchor_rotation_frames.append(sampled_anchor_rotations)
		target_anchor_scale_frames.append(sampled_anchor_scales)
		target_bridge_frame_flags.append(false)
	target_clip.set("solved_replay_track_source", source_clip.get("solved_replay_track_source"))
	target_clip.set("solved_replay_reference_bone_name", source_clip.get("solved_replay_reference_bone_name"))
	target_clip.set("solved_replay_reference_origin_id", _get_clip_origin_id(
		source_clip,
		&"solved_replay_reference_origin_id",
		CombatOriginRecordScript.ORIGIN_SOLVED_REPLAY_REFERENCE
	))
	target_clip.set("baked_solved_replay_frame_available", target_available)
	target_clip.set("baked_solved_upper_body_bone_names", source_bone_names.duplicate())
	target_clip.set("baked_solved_upper_body_pose_positions", target_position_frames)
	target_clip.set("baked_solved_upper_body_pose_rotations", target_rotation_frames)
	target_clip.set("baked_solved_upper_body_pose_scales", target_scale_frames)
	target_clip.set("baked_solved_weapon_positions_reference_local", target_weapon_positions)
	target_clip.set("baked_solved_weapon_rotations_reference_local", target_weapon_rotations)
	target_clip.set("baked_solved_weapon_scales_reference_local", target_weapon_scales)
	target_clip.set("baked_solved_weapon_reference_origin_id", _get_clip_origin_id(
		source_clip,
		&"baked_solved_weapon_reference_origin_id",
		CombatOriginRecordScript.ORIGIN_SOLVED_REPLAY_REFERENCE
	))
	target_clip.set("baked_solved_anchor_node_paths", source_anchor_paths.duplicate())
	target_clip.set("baked_solved_anchor_positions_weapon_local", target_anchor_position_frames)
	target_clip.set("baked_solved_anchor_rotations_weapon_local", target_anchor_rotation_frames)
	target_clip.set("baked_solved_anchor_scales_weapon_local", target_anchor_scale_frames)
	target_clip.set("baked_solved_anchor_origin_id", _get_clip_origin_id(
		source_clip,
		&"baked_solved_anchor_origin_id",
		CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
	))
	target_clip.set_meta("baked_solved_replay_bridge_frame", target_bridge_frame_flags)
	return true

func _get_clip_origin_id(source_clip, property_name: StringName, fallback: StringName) -> StringName:
	if source_clip == null:
		return fallback
	var origin_id: StringName = StringName(source_clip.get(property_name))
	if origin_id == StringName():
		return fallback
	return origin_id

func _resolve_first_available_solved_replay_frame_index(availability: Array) -> int:
	for frame_index: int in range(availability.size()):
		if bool(availability[frame_index]):
			return frame_index
	return -1

func _is_valid_solved_replay_bridge_snapshot(snapshot: Dictionary, bone_names: Array, anchor_paths: Array) -> bool:
	if snapshot.is_empty() or not bool(snapshot.get("valid", false)):
		return false
	var snapshot_bone_names: Array = snapshot.get("bone_names", []) as Array
	if snapshot_bone_names.size() != bone_names.size():
		return false
	for bone_index: int in range(bone_names.size()):
		if StringName(String(snapshot_bone_names[bone_index])) != StringName(String(bone_names[bone_index])):
			return false
	var snapshot_anchor_paths: Array = snapshot.get("anchor_node_paths", []) as Array
	if snapshot_anchor_paths.size() != anchor_paths.size():
		return false
	for anchor_index: int in range(anchor_paths.size()):
		if StringName(String(snapshot_anchor_paths[anchor_index])) != StringName(String(anchor_paths[anchor_index])):
			return false
	var positions: Array[Vector3] = _decode_cached_vector3_frame(snapshot.get("pose_positions", PackedVector3Array()))
	var rotations: Array[Quaternion] = _decode_cached_upper_body_pose_frame(snapshot.get("pose_rotations", PackedVector4Array()))
	var scales: Array[Vector3] = _decode_cached_vector3_frame(snapshot.get("pose_scales", PackedVector3Array()))
	var anchor_positions: Array[Vector3] = _decode_cached_vector3_frame(snapshot.get("anchor_positions_weapon_local", PackedVector3Array()))
	var anchor_rotations: Array[Quaternion] = _decode_cached_upper_body_pose_frame(snapshot.get("anchor_rotations_weapon_local", PackedVector4Array()))
	var anchor_scales: Array[Vector3] = _decode_cached_vector3_frame(snapshot.get("anchor_scales_weapon_local", PackedVector3Array()))
	return (
		positions.size() == bone_names.size()
		and rotations.size() == bone_names.size()
		and scales.size() == bone_names.size()
		and anchor_positions.size() == anchor_paths.size()
		and anchor_rotations.size() == anchor_paths.size()
		and anchor_scales.size() == anchor_paths.size()
		and StringName(snapshot.get("reference_origin_id", StringName())) != StringName()
		and snapshot.get("weapon_position_reference_local", null) is Vector3
		and snapshot.get("weapon_rotation_reference_local", null) is Quaternion
		and snapshot.get("weapon_scale_reference_local", null) is Vector3
		and StringName(snapshot.get("weapon_reference_origin_id", StringName())) != StringName()
		and StringName(snapshot.get("anchor_origin_id", StringName())) != StringName()
	)

func _append_unavailable_solved_replay_frame(
	target_available: Array,
	target_position_frames: Array,
	target_rotation_frames: Array,
	target_scale_frames: Array,
	target_weapon_positions: PackedVector3Array,
	target_weapon_rotations: PackedVector4Array,
	target_weapon_scales: PackedVector3Array,
	target_anchor_position_frames: Array,
	target_anchor_rotation_frames: Array,
	target_anchor_scale_frames: Array
) -> void:
	target_available.append(false)
	target_position_frames.append(PackedVector3Array())
	target_rotation_frames.append(PackedVector4Array())
	target_scale_frames.append(PackedVector3Array())
	target_weapon_positions.append(Vector3.ZERO)
	target_weapon_rotations.append(_pack_quaternion(Quaternion.IDENTITY))
	target_weapon_scales.append(Vector3.ONE)
	target_anchor_position_frames.append(PackedVector3Array())
	target_anchor_rotation_frames.append(PackedVector4Array())
	target_anchor_scale_frames.append(PackedVector3Array())

func _append_interpolated_solved_replay_bridge_frame(
	target_available: Array,
	target_position_frames: Array,
	target_rotation_frames: Array,
	target_scale_frames: Array,
	target_weapon_positions: PackedVector3Array,
	target_weapon_rotations: PackedVector4Array,
	target_weapon_scales: PackedVector3Array,
	target_anchor_position_frames: Array,
	target_anchor_rotation_frames: Array,
	target_anchor_scale_frames: Array,
	source_snapshot: Dictionary,
	target_positions_frame: Variant,
	target_rotations_frame: Variant,
	target_scales_frame: Variant,
	target_weapon_position: Vector3,
	target_weapon_rotation: Quaternion,
	target_weapon_scale: Vector3,
	target_anchor_positions_frame: Variant,
	target_anchor_rotations_frame: Variant,
	target_anchor_scales_frame: Variant,
	expected_bone_count: int,
	expected_anchor_count: int,
	ratio: float
) -> bool:
	var clean_ratio: float = clampf(ratio, 0.0, 1.0)
	var bridge_positions: PackedVector3Array = _interpolate_cached_vector3_frame(
		source_snapshot.get("pose_positions", PackedVector3Array()),
		target_positions_frame,
		clean_ratio,
		expected_bone_count
	)
	var bridge_rotations: PackedVector4Array = _interpolate_cached_upper_body_pose_frame(
		source_snapshot.get("pose_rotations", PackedVector4Array()),
		target_rotations_frame,
		clean_ratio,
		expected_bone_count
	)
	var bridge_scales: PackedVector3Array = _interpolate_cached_vector3_frame(
		source_snapshot.get("pose_scales", PackedVector3Array()),
		target_scales_frame,
		clean_ratio,
		expected_bone_count
	)
	var bridge_anchor_positions: PackedVector3Array = _interpolate_cached_vector3_frame(
		source_snapshot.get("anchor_positions_weapon_local", PackedVector3Array()),
		target_anchor_positions_frame,
		clean_ratio,
		expected_anchor_count
	)
	var bridge_anchor_rotations: PackedVector4Array = _interpolate_cached_upper_body_pose_frame(
		source_snapshot.get("anchor_rotations_weapon_local", PackedVector4Array()),
		target_anchor_rotations_frame,
		clean_ratio,
		expected_anchor_count
	)
	var bridge_anchor_scales: PackedVector3Array = _interpolate_cached_vector3_frame(
		source_snapshot.get("anchor_scales_weapon_local", PackedVector3Array()),
		target_anchor_scales_frame,
		clean_ratio,
		expected_anchor_count
	)
	if (
		bridge_positions.size() != expected_bone_count
		or bridge_rotations.size() != expected_bone_count
		or bridge_scales.size() != expected_bone_count
		or bridge_anchor_positions.size() != expected_anchor_count
		or bridge_anchor_rotations.size() != expected_anchor_count
		or bridge_anchor_scales.size() != expected_anchor_count
	):
		return false
	var source_weapon_position: Vector3 = source_snapshot.get("weapon_position_reference_local", Vector3.ZERO) as Vector3
	var source_weapon_rotation: Quaternion = source_snapshot.get("weapon_rotation_reference_local", Quaternion.IDENTITY) as Quaternion
	var source_weapon_scale: Vector3 = source_snapshot.get("weapon_scale_reference_local", Vector3.ONE) as Vector3
	target_available.append(true)
	target_position_frames.append(bridge_positions)
	target_rotation_frames.append(bridge_rotations)
	target_scale_frames.append(bridge_scales)
	target_weapon_positions.append(source_weapon_position.lerp(target_weapon_position, clean_ratio))
	target_weapon_rotations.append(_pack_quaternion(source_weapon_rotation.normalized().slerp(target_weapon_rotation.normalized(), clean_ratio).normalized()))
	target_weapon_scales.append(source_weapon_scale.lerp(target_weapon_scale, clean_ratio))
	target_anchor_position_frames.append(bridge_anchor_positions)
	target_anchor_rotation_frames.append(bridge_anchor_rotations)
	target_anchor_scale_frames.append(bridge_anchor_scales)
	return true

func _sample_cached_vector3_frame(
	source_frame_times: PackedFloat32Array,
	source_pose_frames: Array,
	source_time_seconds: float,
	expected_count: int
) -> PackedVector3Array:
	if source_frame_times.is_empty() or source_pose_frames.is_empty() or expected_count < 0:
		return PackedVector3Array()
	if expected_count == 0:
		return PackedVector3Array()
	var frame_count: int = mini(source_frame_times.size(), source_pose_frames.size())
	if frame_count <= 0:
		return PackedVector3Array()
	if frame_count == 1 or source_time_seconds <= float(source_frame_times[0]):
		return _duplicate_cached_vector3_frame(source_pose_frames[0], expected_count)
	if source_time_seconds >= float(source_frame_times[frame_count - 1]):
		return _duplicate_cached_vector3_frame(source_pose_frames[frame_count - 1], expected_count)
	var from_index: int = 0
	while from_index < frame_count - 2 and source_time_seconds > float(source_frame_times[from_index + 1]):
		from_index += 1
	var to_index: int = mini(from_index + 1, frame_count - 1)
	var from_time: float = float(source_frame_times[from_index])
	var to_time: float = float(source_frame_times[to_index])
	var ratio: float = 0.0
	if to_time > from_time:
		ratio = clampf((source_time_seconds - from_time) / (to_time - from_time), 0.0, 1.0)
	return _interpolate_cached_vector3_frame(source_pose_frames[from_index], source_pose_frames[to_index], ratio, expected_count)

func _resolve_nearest_cached_frame_index(source_frame_times: PackedFloat32Array, source_time_seconds: float) -> int:
	var frame_count: int = source_frame_times.size()
	if frame_count <= 0:
		return -1
	if source_time_seconds <= float(source_frame_times[0]):
		return 0
	if source_time_seconds >= float(source_frame_times[frame_count - 1]):
		return frame_count - 1
	for frame_index: int in range(1, frame_count):
		var to_time: float = float(source_frame_times[frame_index])
		if source_time_seconds <= to_time:
			var from_time: float = float(source_frame_times[frame_index - 1])
			return frame_index - 1 if absf(source_time_seconds - from_time) <= absf(to_time - source_time_seconds) else frame_index
	return frame_count - 1

func _duplicate_cached_vector3_frame(frame_data: Variant, expected_count: int) -> PackedVector3Array:
	var values: Array[Vector3] = _decode_cached_vector3_frame(frame_data)
	if values.size() != expected_count:
		return PackedVector3Array()
	var packed := PackedVector3Array()
	for value: Vector3 in values:
		packed.append(value)
	return packed

func _interpolate_cached_vector3_frame(
	from_frame_data: Variant,
	to_frame_data: Variant,
	ratio: float,
	expected_count: int
) -> PackedVector3Array:
	var from_values: Array[Vector3] = _decode_cached_vector3_frame(from_frame_data)
	var to_values: Array[Vector3] = _decode_cached_vector3_frame(to_frame_data)
	if from_values.size() != expected_count or to_values.size() != expected_count:
		return PackedVector3Array()
	var clean_ratio: float = clampf(ratio, 0.0, 1.0)
	var packed := PackedVector3Array()
	for value_index: int in range(expected_count):
		packed.append(from_values[value_index].lerp(to_values[value_index], clean_ratio))
	return packed

func _decode_cached_vector3_frame(frame_data: Variant) -> Array[Vector3]:
	var values: Array[Vector3] = []
	if frame_data is PackedVector3Array:
		var packed_values: PackedVector3Array = frame_data as PackedVector3Array
		for value: Vector3 in packed_values:
			values.append(value)
		return values
	if frame_data is Array:
		var value_array: Array = frame_data as Array
		for value_variant: Variant in value_array:
			if value_variant is Vector3:
				values.append(value_variant as Vector3)
	return values

func _sample_cached_vector3_track(
	source_frame_times: PackedFloat32Array,
	source_values: PackedVector3Array,
	source_time_seconds: float,
	fallback: Vector3
) -> Vector3:
	if source_frame_times.is_empty() or source_values.is_empty():
		return fallback
	var frame_count: int = mini(source_frame_times.size(), source_values.size())
	if frame_count == 1 or source_time_seconds <= float(source_frame_times[0]):
		return source_values[0]
	if source_time_seconds >= float(source_frame_times[frame_count - 1]):
		return source_values[frame_count - 1]
	var from_index: int = 0
	while from_index < frame_count - 2 and source_time_seconds > float(source_frame_times[from_index + 1]):
		from_index += 1
	var to_index: int = mini(from_index + 1, frame_count - 1)
	var from_time: float = float(source_frame_times[from_index])
	var to_time: float = float(source_frame_times[to_index])
	var ratio: float = 0.0
	if to_time > from_time:
		ratio = clampf((source_time_seconds - from_time) / (to_time - from_time), 0.0, 1.0)
	return source_values[from_index].lerp(source_values[to_index], ratio)

func _sample_cached_quaternion_track(
	source_frame_times: PackedFloat32Array,
	source_values: PackedVector4Array,
	source_time_seconds: float,
	fallback: Quaternion
) -> Quaternion:
	if source_frame_times.is_empty() or source_values.is_empty():
		return fallback
	var frame_count: int = mini(source_frame_times.size(), source_values.size())
	if frame_count == 1 or source_time_seconds <= float(source_frame_times[0]):
		return _quaternion_from_vector4(source_values[0], fallback)
	if source_time_seconds >= float(source_frame_times[frame_count - 1]):
		return _quaternion_from_vector4(source_values[frame_count - 1], fallback)
	var from_index: int = 0
	while from_index < frame_count - 2 and source_time_seconds > float(source_frame_times[from_index + 1]):
		from_index += 1
	var to_index: int = mini(from_index + 1, frame_count - 1)
	var from_time: float = float(source_frame_times[from_index])
	var to_time: float = float(source_frame_times[to_index])
	var ratio: float = 0.0
	if to_time > from_time:
		ratio = clampf((source_time_seconds - from_time) / (to_time - from_time), 0.0, 1.0)
	return _quaternion_from_vector4(source_values[from_index], fallback).slerp(
		_quaternion_from_vector4(source_values[to_index], fallback),
		ratio
	).normalized()

func _quaternion_from_vector4(value: Vector4, fallback: Quaternion = Quaternion.IDENTITY) -> Quaternion:
	var rotation := Quaternion(value.x, value.y, value.z, value.w)
	if rotation.x * rotation.x + rotation.y * rotation.y + rotation.z * rotation.z + rotation.w * rotation.w <= 0.000001:
		return fallback
	return rotation.normalized()

func _pack_quaternion(rotation: Quaternion) -> Vector4:
	var normalized_rotation: Quaternion = rotation.normalized()
	return Vector4(normalized_rotation.x, normalized_rotation.y, normalized_rotation.z, normalized_rotation.w)

func _build_runtime_clip_debug_state(runtime_clip) -> Dictionary:
	if runtime_clip == null:
		return {}
	return runtime_clip.to_debug_state()

func _build_tip_curve(motion_node_chain: Array) -> Curve3D:
	var curve := Curve3D.new()
	for motion_node_variant: Variant in motion_node_chain:
		var motion_node: CombatAnimationMotionNode = motion_node_variant as CombatAnimationMotionNode
		if motion_node == null:
			continue
		curve.add_point(
			motion_node.tip_position_local,
			motion_node.tip_curve_in_handle,
			motion_node.tip_curve_out_handle
		)
	return curve

func _build_pommel_curve(motion_node_chain: Array) -> Curve3D:
	var curve := Curve3D.new()
	for motion_node_variant: Variant in motion_node_chain:
		var motion_node: CombatAnimationMotionNode = motion_node_variant as CombatAnimationMotionNode
		if motion_node == null:
			continue
		curve.add_point(
			motion_node.pommel_position_local,
			motion_node.pommel_curve_in_handle,
			motion_node.pommel_curve_out_handle
		)
	return curve

func _on_chain_playback_finished() -> void:
	playback_finished_pending = true
