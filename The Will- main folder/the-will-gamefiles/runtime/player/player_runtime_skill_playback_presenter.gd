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

const ENTRY_BRIDGE_DURATION_SECONDS := 0.3
const RECOVERY_BRIDGE_DURATION_SECONDS := 1.2
const DRAW_BRIDGE_DURATION_SECONDS := 0.3
const STOW_BRIDGE_DURATION_SECONDS := 1.2
const DEFAULT_COMBAT_IDLE_EXPIRY_SECONDS := 15.0
const NO_OP_BRIDGE_DURATION_SECONDS := 0.01
const MOTION_NODE_POSITION_EPSILON_METERS := 0.005
const MOTION_NODE_ANGLE_EPSILON_DEGREES := 0.5
const MOTION_NODE_FLOAT_EPSILON := 0.01

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
var active_baseline_local_transform_valid: bool = false
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
	var inherited_start_node: CombatAnimationMotionNode = _capture_current_motion_node_for_slot(
		dominant_slot_id,
		motion_node_chain[0] as CombatAnimationMotionNode
	)
	var was_runtime_playback_active: bool = runtime_playback_active
	if runtime_idle_active:
		clear_idle_pose(humanoid_rig, equipped_item_presenter, held_item_nodes, equipment_state, weapons_drawn)
	if runtime_playback_active:
		stop_playback(humanoid_rig, held_item_nodes, equipped_item_presenter, equipment_state, weapons_drawn, false, false)

	active_runtime_skill_result = slot_activation_result.duplicate(true)
	active_runtime_skill_result["runtime_compile_diagnostics"] = (compile_result.get("diagnostics", []) as Array).duplicate(true)
	active_runtime_skill_result["runtime_compile_degraded_node_count"] = int(compile_result.get("degraded_node_count", 0))
	active_runtime_skill_result["runtime_compile_hand_swap_bridge_count"] = int(compile_result.get("hand_swap_bridge_count", 0))
	active_runtime_skill_result["runtime_compile_retargeted_count"] = int(compile_result.get("retargeted_count", 0))
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
	active_baseline_local_transform_valid = true
	active_trajectory_volume_config = trajectory_volume_config
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
	var idle_source_key: String = _build_idle_source_key(idle_pose_result, dominant_slot_id, motion_node_chain)
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
		_start_steady_idle_pose_after_recovery(idle_pose_result, motion_node_chain, dominant_slot_id, held_item, humanoid_rig)
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
	weapons_drawn: bool = true
) -> void:
	if not runtime_idle_active and active_idle_dominant_slot_id == StringName():
		_clear_pending_recovery_state()
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
	if humanoid_rig != null and humanoid_rig.has_method("clear_upper_body_authoring_state"):
		humanoid_rig.call("clear_upper_body_authoring_state")
	if equipped_item_presenter != null:
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
	if preserve_recovery_state and playback_finished_pending and runtime_playback_active:
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
	if restore_baseline_transform and held_item != null and is_instance_valid(held_item) and active_baseline_local_transform_valid:
		held_item.transform = active_baseline_local_transform
	if humanoid_rig != null and humanoid_rig.has_method("clear_upper_body_authoring_state"):
		humanoid_rig.call("clear_upper_body_authoring_state")
	if humanoid_rig != null and humanoid_rig.has_method("set_upper_body_authoring_auto_apply_enabled"):
		humanoid_rig.call("set_upper_body_authoring_auto_apply_enabled", true)
	if equipped_item_presenter != null:
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
	active_baseline_local_transform_valid = false
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
		return _apply_lightweight_runtime_clip_pose(
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
	_apply_runtime_support_guidance(humanoid_rig, held_item_nodes, held_item, support_requested)
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
	active_idle_source_key = _build_idle_source_key(idle_pose_result, dominant_slot_id, motion_node_chain)
	runtime_idle_active = true
	idle_chain_player.stop()
	active_idle_trajectory_volume_config = {}
	var recovery_source_node: CombatAnimationMotionNode = pending_recovery_motion_node
	if recovery_source_node != null and pending_recovery_dominant_slot_id == dominant_slot_id:
		var recovery_chain_result: Dictionary = _build_runtime_chain_with_entry(
			motion_node_chain,
			recovery_source_node,
			RECOVERY_BRIDGE_DURATION_SECONDS,
			0,
			false
		)
		active_idle_motion_node_chain = recovery_chain_result.get("motion_node_chain", []) as Array
		active_idle_trajectory_volume_config = _resolve_runtime_trajectory_volume_config(
			humanoid_rig,
			held_item,
			dominant_slot_id
		)
		active_idle_recovery_bridge_active = bool(recovery_chain_result.get("entry_bridge_active", false))
		_apply_recovery_bridge_debug(recovery_chain_result)
		_begin_recovery_hidden_bridge(recovery_chain_result, dominant_slot_id, idle_pose_result)
		_clear_pending_recovery_state()
	else:
		active_idle_motion_node_chain = _duplicate_motion_node_chain(motion_node_chain)
		active_idle_trajectory_volume_config = _resolve_runtime_trajectory_volume_config(
			humanoid_rig,
			held_item,
			dominant_slot_id
		)
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
		}
	)
	if active_idle_runtime_clip != null and active_idle_runtime_clip.is_playable():
		active_idle_motion_node_chain = active_idle_runtime_clip.motion_node_chain
		active_runtime_idle_result["runtime_clip_baked"] = true
		active_runtime_idle_result["runtime_clip_frame_count"] = active_idle_runtime_clip.get_frame_count()
		active_runtime_idle_result["runtime_clip_duration_seconds"] = active_idle_runtime_clip.total_duration_seconds
	else:
		active_runtime_idle_result["runtime_clip_baked"] = false
	if active_idle_motion_node_chain.size() >= 2:
		if active_idle_runtime_clip != null and active_idle_runtime_clip.is_playable() and idle_chain_player.has_method("prepare_runtime_clip"):
			idle_chain_player.prepare_runtime_clip(active_idle_runtime_clip, playback_speed, should_loop_idle)
		else:
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
	humanoid_rig: Node3D
) -> void:
	active_idle_recovery_bridge_active = false
	active_idle_motion_node_chain = _duplicate_motion_node_chain(motion_node_chain)
	active_idle_trajectory_volume_config = _resolve_runtime_trajectory_volume_config(
		humanoid_rig,
		held_item,
		dominant_slot_id
	)
	idle_chain_player.stop()
	if hidden_bridge_state.kind == PlayerRuntimeHiddenBridgeStateScript.KIND_SKILL_RECOVERY:
		hidden_bridge_state.complete()
	var playback_speed: float = float(idle_pose_result.get("preview_playback_speed_scale", 1.0))
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
		}
	)
	if active_idle_runtime_clip != null and active_idle_runtime_clip.is_playable():
		active_idle_motion_node_chain = active_idle_runtime_clip.motion_node_chain
		active_runtime_idle_result["runtime_clip_baked"] = true
		active_runtime_idle_result["runtime_clip_frame_count"] = active_idle_runtime_clip.get_frame_count()
		active_runtime_idle_result["runtime_clip_duration_seconds"] = active_idle_runtime_clip.total_duration_seconds
	else:
		active_runtime_idle_result["runtime_clip_baked"] = false
	if active_idle_motion_node_chain.size() >= 2:
		if active_idle_runtime_clip != null and active_idle_runtime_clip.is_playable() and idle_chain_player.has_method("prepare_runtime_clip"):
			idle_chain_player.prepare_runtime_clip(active_idle_runtime_clip, playback_speed, true)
		else:
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
		return _apply_lightweight_runtime_clip_pose(
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
	_apply_runtime_support_guidance_for_slots(
		humanoid_rig,
		held_item_nodes,
		held_item,
		active_idle_support_slot_id,
		support_requested
	)
	return resolved_pose_state

func _apply_lightweight_runtime_clip_pose(
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
	var local_tip: Vector3 = held_item.get_meta("weapon_tip_local", Vector3.ZERO) as Vector3
	var local_pommel: Vector3 = held_item.get_meta("weapon_pommel_local", Vector3.ZERO) as Vector3
	if local_tip.is_equal_approx(local_pommel):
		return resolved_playback_state
	var previous_slot_id: StringName = live_pose_presenter.preview_dominant_slot_id
	var previous_default_two_hand: bool = live_pose_presenter.preview_default_two_hand
	live_pose_presenter.configure_preview_hand_setup(dominant_slot_id, support_requested)

	var trajectory_transform: Transform3D = live_pose_presenter._resolve_trajectory_authoring_transform(humanoid_rig)
	live_pose_presenter._apply_preview_motion_grip_state(
		held_item,
		effective_motion_node,
		playback_state,
		humanoid_rig
	)
	_sync_runtime_contact_axis_override(held_item, playback_state, trajectory_transform.basis)
	var authored_tip_local: Vector3 = playback_state.get("tip_position_local", effective_motion_node.tip_position_local) as Vector3
	var authored_pommel_local: Vector3 = playback_state.get("pommel_position_local", effective_motion_node.pommel_position_local) as Vector3
	var authored_tip_world: Vector3 = trajectory_transform * authored_tip_local
	var authored_pommel_world: Vector3 = trajectory_transform * authored_pommel_local
	var resolved_weapon_orientation_degrees: Vector3 = playback_state.get(
		"weapon_orientation_degrees",
		effective_motion_node.weapon_orientation_degrees
	) as Vector3
	if authored_tip_world.distance_to(authored_pommel_world) > 0.000001:
		var local_axis: Vector3 = (local_tip - local_pommel).normalized()
		var local_up_reference: Vector3 = _resolve_weapon_local_up_reference(held_item, local_axis)
		var solved_transform: Transform3D = weapon_frame_solver.solve_transform_from_segment(
			local_tip,
			local_pommel,
			authored_tip_world,
			authored_pommel_world,
			local_up_reference,
			trajectory_transform.basis,
			resolved_weapon_orientation_degrees,
			float(playback_state.get("weapon_roll_degrees", effective_motion_node.weapon_roll_degrees))
		)
		held_item.global_transform = solved_transform
	live_pose_presenter._apply_preview_resolved_grip_state(held_item)
	_apply_runtime_support_guidance_for_slots(
		humanoid_rig,
		held_item_nodes,
		held_item,
		support_slot_id,
		support_requested
	)
	var solved_tip_world: Vector3 = held_item.to_global(local_tip)
	var solved_pommel_world: Vector3 = held_item.to_global(local_pommel)
	var trajectory_inverse: Transform3D = trajectory_transform.affine_inverse()
	resolved_playback_state["active"] = bool(resolved_playback_state.get("active", true))
	resolved_playback_state["tip_position_local"] = trajectory_inverse * solved_tip_world
	resolved_playback_state["pommel_position_local"] = trajectory_inverse * solved_pommel_world
	resolved_playback_state["weapon_orientation_degrees"] = resolved_weapon_orientation_degrees
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
	live_pose_presenter.configure_preview_hand_setup(previous_slot_id, previous_default_two_hand)
	return resolved_playback_state

func _sync_runtime_contact_axis_override(
	held_item: Node3D,
	playback_state: Dictionary,
	trajectory_basis: Basis
) -> void:
	_clear_runtime_contact_axis_override(held_item)
	if held_item == null:
		return
	if not bool(playback_state.get("contact_grip_axis_local_override_active", false)):
		return
	var contact_axis_local: Vector3 = playback_state.get("contact_grip_axis_local", Vector3.ZERO) as Vector3
	if contact_axis_local.length_squared() <= 0.000001:
		return
	var contact_axis_world: Vector3 = trajectory_basis * contact_axis_local.normalized()
	if contact_axis_world.length_squared() <= 0.000001:
		return
	held_item.set_meta("authoring_contact_grip_axis_world_override", contact_axis_world.normalized())

func _clear_runtime_contact_axis_override(held_item: Node3D) -> void:
	if held_item == null:
		return
	if held_item.has_meta("authoring_contact_grip_axis_world_override"):
		held_item.remove_meta("authoring_contact_grip_axis_world_override")

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
	var primary_anchor: Node3D = weapon_grip_anchor_provider.get_primary_grip_anchor(held_item)
	var support_anchor: Node3D = weapon_grip_anchor_provider.get_support_grip_anchor(held_item)
	var payload := {
		"active": true,
		"blend": clampf(float(playback_state.get("body_support_blend", effective_motion_node.body_support_blend)), 0.0, 1.0),
		"two_hand": support_requested,
		"dominant_slot_id": dominant_slot_id,
		"primary_target_world": primary_anchor.global_position if primary_anchor != null else Vector3.ZERO,
		"secondary_target_world": support_anchor.global_position if support_requested and support_anchor != null else Vector3.ZERO,
		"tip_world": tip_world,
		"pommel_world": pommel_world,
	}
	humanoid_rig.call("set_upper_body_authoring_state", payload)
	if humanoid_rig.has_method("apply_upper_body_authoring_pose_now"):
		humanoid_rig.call("apply_upper_body_authoring_pose_now")

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
	effective_motion_node.pommel_position_local = chain_player.current_pommel_position
	effective_motion_node.weapon_orientation_degrees = chain_player.current_weapon_orientation_degrees
	effective_motion_node.weapon_orientation_authored = true
	effective_motion_node.weapon_roll_degrees = chain_player.current_weapon_roll
	effective_motion_node.axial_reposition_offset = chain_player.current_axial_reposition
	effective_motion_node.grip_seat_slide_offset = chain_player.current_grip_seat_slide
	effective_motion_node.body_support_blend = chain_player.current_body_support_blend
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
		"pommel_position_local": chain_player.current_pommel_position,
		"weapon_orientation_degrees": chain_player.current_weapon_orientation_degrees,
		"weapon_roll_degrees": chain_player.current_weapon_roll,
		"axial_reposition_offset": chain_player.current_axial_reposition,
		"grip_seat_slide_offset": chain_player.current_grip_seat_slide,
		"body_support_blend": chain_player.current_body_support_blend,
		"two_hand_state": chain_player.current_two_hand_state,
		"primary_hand_slot": chain_player.current_primary_hand_slot,
		"preferred_grip_style_mode": chain_player.current_preferred_grip_style_mode,
		"contact_grip_axis_local": chain_player.current_contact_grip_axis_local,
		"contact_grip_axis_local_override_active": chain_player.current_contact_grip_axis_local_override_active,
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
	if active_idle_motion_node_chain.size() >= 2:
		effective_motion_node.tip_position_local = idle_chain_player.current_tip_position
		effective_motion_node.pommel_position_local = idle_chain_player.current_pommel_position
		effective_motion_node.weapon_orientation_degrees = idle_chain_player.current_weapon_orientation_degrees
		effective_motion_node.weapon_orientation_authored = true
		effective_motion_node.weapon_roll_degrees = idle_chain_player.current_weapon_roll
		effective_motion_node.axial_reposition_offset = idle_chain_player.current_axial_reposition
		effective_motion_node.grip_seat_slide_offset = idle_chain_player.current_grip_seat_slide
		effective_motion_node.body_support_blend = idle_chain_player.current_body_support_blend
		effective_motion_node.two_hand_state = idle_chain_player.current_two_hand_state
		effective_motion_node.primary_hand_slot = idle_chain_player.current_primary_hand_slot
		effective_motion_node.preferred_grip_style_mode = idle_chain_player.current_preferred_grip_style_mode
	effective_motion_node.normalize()
	return effective_motion_node

func _build_idle_playback_state(effective_motion_node: CombatAnimationMotionNode) -> Dictionary:
	if effective_motion_node == null:
		return {}
	var contact_grip_axis_local: Vector3 = idle_chain_player.current_contact_grip_axis_local if active_idle_motion_node_chain.size() >= 2 else Vector3.ZERO
	var contact_grip_axis_override_active: bool = idle_chain_player.current_contact_grip_axis_local_override_active if active_idle_motion_node_chain.size() >= 2 else false
	return {
		"active": runtime_idle_active,
		"tip_position_local": effective_motion_node.tip_position_local,
		"pommel_position_local": effective_motion_node.pommel_position_local,
		"weapon_orientation_degrees": effective_motion_node.weapon_orientation_degrees,
		"weapon_roll_degrees": effective_motion_node.weapon_roll_degrees,
		"axial_reposition_offset": effective_motion_node.axial_reposition_offset,
		"grip_seat_slide_offset": effective_motion_node.grip_seat_slide_offset,
		"body_support_blend": effective_motion_node.body_support_blend,
		"two_hand_state": effective_motion_node.two_hand_state,
		"primary_hand_slot": effective_motion_node.primary_hand_slot,
		"preferred_grip_style_mode": effective_motion_node.preferred_grip_style_mode,
		"contact_grip_axis_local": contact_grip_axis_local,
		"contact_grip_axis_local_override_active": contact_grip_axis_override_active,
		"trajectory_volume_state": idle_chain_player.current_trajectory_volume_state if active_idle_motion_node_chain.size() >= 2 else {},
	}

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
	var tip_local: Vector3 = held_item.get_meta("weapon_tip_local") as Vector3 if held_item.has_meta("weapon_tip_local") else Vector3.ZERO
	var pommel_local: Vector3 = held_item.get_meta("weapon_pommel_local") as Vector3 if held_item.has_meta("weapon_pommel_local") else Vector3.ZERO
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
	snapshot.pommel_position_local = source_chain_player.current_pommel_position
	snapshot.tip_curve_in_handle = Vector3.ZERO
	snapshot.tip_curve_out_handle = Vector3.ZERO
	snapshot.pommel_curve_in_handle = Vector3.ZERO
	snapshot.pommel_curve_out_handle = Vector3.ZERO
	snapshot.weapon_orientation_degrees = source_chain_player.current_weapon_orientation_degrees
	snapshot.weapon_orientation_authored = true
	snapshot.weapon_roll_degrees = source_chain_player.current_weapon_roll
	snapshot.axial_reposition_offset = source_chain_player.current_axial_reposition
	snapshot.grip_seat_slide_offset = source_chain_player.current_grip_seat_slide
	snapshot.body_support_blend = source_chain_player.current_body_support_blend
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
	snapshot.pommel_position_local = pose_state.get("pommel_position_local", snapshot.pommel_position_local) as Vector3
	snapshot.weapon_orientation_degrees = pose_state.get("weapon_orientation_degrees", snapshot.weapon_orientation_degrees) as Vector3
	snapshot.weapon_orientation_authored = true
	snapshot.weapon_roll_degrees = float(pose_state.get("weapon_roll_degrees", snapshot.weapon_roll_degrees))
	snapshot.axial_reposition_offset = float(pose_state.get("axial_reposition_offset", snapshot.axial_reposition_offset))
	snapshot.grip_seat_slide_offset = float(pose_state.get("grip_seat_slide_offset", snapshot.grip_seat_slide_offset))
	snapshot.body_support_blend = float(pose_state.get("body_support_blend", snapshot.body_support_blend))
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
	if absf(from_node.body_support_blend - to_node.body_support_blend) > MOTION_NODE_FLOAT_EPSILON:
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

func _build_idle_source_key(idle_pose_result: Dictionary, dominant_slot_id: StringName, motion_node_chain: Array) -> String:
	return "%s|%s|%s|%s|%d" % [
		String(dominant_slot_id),
		String(idle_pose_result.get("source_weapon_wip_id", StringName())),
		String(idle_pose_result.get("draft_id", StringName())),
		String(idle_pose_result.get("idle_context_id", StringName())),
		motion_node_chain.size(),
	]

func _bake_runtime_playback_clip(motion_node_chain: Array, options: Dictionary):
	if runtime_clip_baker == null or motion_node_chain.is_empty():
		return null
	var clip = runtime_clip_baker.bake_from_motion_node_chain(motion_node_chain, options)
	if clip == null or not clip.is_playable():
		return null
	return clip

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
