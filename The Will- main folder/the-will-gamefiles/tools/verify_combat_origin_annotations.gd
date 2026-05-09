extends SceneTree

const CombatOriginRecordScript = preload("res://core/models/combat_origin_record.gd")
const CombatAnimationMotionNodeScript = preload("res://core/models/combat_animation_motion_node.gd")
const CombatAnimationRetargetNodeScript = preload("res://core/models/combat_animation_retarget_node.gd")
const CombatRuntimeClipBakerScript = preload("res://core/resolvers/combat_runtime_clip_baker.gd")
const CombatAnimationChainPlayerScript = preload("res://runtime/combat/combat_animation_chain_player.gd")
const AnchorAtomScript = preload("res://core/atoms/anchor_atom.gd")
const CombatAnimationDraftScript = preload("res://core/models/combat_animation_draft.gd")

const RESULT_FILE_PATH := "C:/WORKSPACE/combat_origin_annotations_results.txt"

const STRICT_SOURCE_PAIR_CHECKS := [
	{
		"id": "anchor_atom_local_position_export",
		"path": "res://core/atoms/anchor_atom.gd",
		"local": "@export var local_position",
		"origin": "@export var position_origin_id",
		"max_lines": 2,
	},
	{
		"id": "anchor_atom_local_axis_export",
		"path": "res://core/atoms/anchor_atom.gd",
		"local": "@export var local_axis",
		"origin": "@export var axis_origin_id",
		"max_lines": 2,
	},
	{
		"id": "anchor_atom_span_start_export",
		"path": "res://core/atoms/anchor_atom.gd",
		"local": "@export var span_start_local_position",
		"origin": "@export var span_start_position_origin_id",
		"max_lines": 2,
	},
	{
		"id": "anchor_atom_span_end_export",
		"path": "res://core/atoms/anchor_atom.gd",
		"local": "@export var span_end_local_position",
		"origin": "@export var span_end_position_origin_id",
		"max_lines": 2,
	},
	{
		"id": "anchor_resolver_position_origin_write",
		"path": "res://core/resolvers/anchor_resolver.gd",
		"local": "anchor.local_position = grip_span.get",
		"origin": "anchor.position_origin_id = AnchorAtom.DEFAULT_ANCHOR_ORIGIN_ID",
		"max_lines": 2,
	},
	{
		"id": "anchor_resolver_axis_origin_write",
		"path": "res://core/resolvers/anchor_resolver.gd",
		"local": "anchor.local_axis = _calculate_segment_axis",
		"origin": "anchor.axis_origin_id = AnchorAtom.DEFAULT_ANCHOR_ORIGIN_ID",
		"max_lines": 2,
	},
	{
		"id": "anchor_resolver_span_start_origin_write",
		"path": "res://core/resolvers/anchor_resolver.gd",
		"local": "anchor.span_start_local_position = grip_span.get",
		"origin": "anchor.span_start_position_origin_id = AnchorAtom.DEFAULT_ANCHOR_ORIGIN_ID",
		"max_lines": 2,
	},
	{
		"id": "anchor_resolver_span_end_origin_write",
		"path": "res://core/resolvers/anchor_resolver.gd",
		"local": "anchor.span_end_local_position = grip_span.get",
		"origin": "anchor.span_end_position_origin_id = AnchorAtom.DEFAULT_ANCHOR_ORIGIN_ID",
		"max_lines": 2,
	},
	{
		"id": "motion_node_tip_export",
		"path": "res://core/models/combat_animation_motion_node.gd",
		"local": "@export var tip_position_local",
		"origin": "@export var tip_position_origin_id",
		"max_lines": 2,
	},
	{
		"id": "motion_node_pommel_export",
		"path": "res://core/models/combat_animation_motion_node.gd",
		"local": "@export var pommel_position_local",
		"origin": "@export var pommel_position_origin_id",
		"max_lines": 2,
	},
	{
		"id": "retarget_origin_parent_export",
		"path": "res://core/models/combat_animation_retarget_node.gd",
		"local": "@export var origin_id",
		"origin": "@export var parent_origin_id",
		"max_lines": 2,
	},
	{
		"id": "retarget_pivot_export",
		"path": "res://core/models/combat_animation_retarget_node.gd",
		"local": "@export var pivot_direction_local",
		"origin": "@export var pivot_direction_origin_id",
		"max_lines": 2,
	},
	{
		"id": "retarget_weapon_axis_export",
		"path": "res://core/models/combat_animation_retarget_node.gd",
		"local": "@export var weapon_axis_local",
		"origin": "@export var weapon_axis_origin_id",
		"max_lines": 2,
	},
	{
		"id": "trajectory_shell_origin_local_param",
		"path": "res://core/resolvers/combat_animation_trajectory_volume_resolver.gd",
		"local": "origin_local: Vector3,",
		"origin": "origin_local_origin_id: StringName = StringName()",
		"max_lines": 8,
	},
	{
		"id": "trajectory_shell_origin_local_dictionary",
		"path": "res://core/resolvers/combat_animation_trajectory_volume_resolver.gd",
		"local": "\"origin_local\": origin_local",
		"origin": "\"origin_local_origin_id\": _normalize_origin_id(origin_local_origin_id, resolved_parent_origin_id)",
		"max_lines": 2,
	},
	{
		"id": "trajectory_project_origin_local_dictionary",
		"path": "res://core/resolvers/combat_animation_trajectory_volume_resolver.gd",
		"local": "\"origin_local\": origin_local",
		"origin": "\"origin_local_origin_id\": origin_local_origin_id",
		"max_lines": 2,
	},
	{
		"id": "trajectory_fallback_direction_read_origin",
		"path": "res://core/resolvers/combat_animation_trajectory_volume_resolver.gd",
		"local": "var fallback_direction: Vector3 = config.get(\"fallback_direction_local\"",
		"origin": "config[\"fallback_direction_origin_id\"] = fallback_direction_origin_id",
		"max_lines": 2,
	},
	{
		"id": "trajectory_project_tip_origin_write",
		"path": "res://core/resolvers/combat_animation_trajectory_volume_resolver.gd",
		"local": "result[\"tip_position\"] = tip_position_local + translation",
		"origin": "result[\"tip_position_origin_id\"] = parent_origin_id",
		"max_lines": 2,
	},
	{
		"id": "retarget_normalized_origin_local_read",
		"path": "res://core/resolvers/combat_animation_retarget_resolver.gd",
		"local": "var origin_local: Vector3 = resolved_config[\"origin_local\"] as Vector3",
		"origin": "var origin_local_origin_id: StringName = StringName(resolved_config.get(\"origin_local_origin_id\"",
		"max_lines": 2,
	},
	{
		"id": "retarget_values_origin_local_dictionary",
		"path": "res://core/resolvers/combat_animation_retarget_resolver.gd",
		"local": "\"origin_local\": origin_local",
		"origin": "\"origin_local_origin_id\": origin_local_origin_id",
		"max_lines": 2,
	},
	{
		"id": "retarget_apply_tip_origin_write",
		"path": "res://core/resolvers/combat_animation_retarget_resolver.gd",
		"local": "motion_node.tip_position_local = resolved_values.get(\"tip_position_local\"",
		"origin": "motion_node.tip_position_origin_id = StringName(resolved_values.get(\"tip_position_origin_id\"",
		"max_lines": 2,
	},
	{
		"id": "runtime_clip_tip_export",
		"path": "res://core/models/combat_runtime_clip.gd",
		"local": "@export var baked_tip_positions_local",
		"origin": "@export var baked_tip_positions_origin_id",
		"max_lines": 2,
	},
	{
		"id": "runtime_clip_pommel_export",
		"path": "res://core/models/combat_runtime_clip.gd",
		"local": "@export var baked_pommel_positions_local",
		"origin": "@export var baked_pommel_positions_origin_id",
		"max_lines": 2,
	},
	{
		"id": "runtime_clip_contact_axis_export",
		"path": "res://core/models/combat_runtime_clip.gd",
		"local": "@export var baked_contact_grip_axes_local",
		"origin": "@export var baked_contact_grip_axes_origin_id",
		"max_lines": 2,
	},
	{
		"id": "runtime_clip_reference_export",
		"path": "res://core/models/combat_runtime_clip.gd",
		"local": "@export var solved_replay_reference_bone_name",
		"origin": "@export var solved_replay_reference_origin_id",
		"max_lines": 2,
	},
	{
		"id": "runtime_clip_weapon_reference_export",
		"path": "res://core/models/combat_runtime_clip.gd",
		"local": "@export var baked_solved_weapon_positions_reference_local",
		"origin": "@export var baked_solved_weapon_reference_origin_id",
		"max_lines": 4,
	},
	{
		"id": "runtime_clip_anchor_export",
		"path": "res://core/models/combat_runtime_clip.gd",
		"local": "@export var baked_solved_anchor_positions_weapon_local",
		"origin": "@export var baked_solved_anchor_origin_id",
		"max_lines": 4,
	},
	{
		"id": "clip_baker_volume_config_origin",
		"path": "res://core/resolvers/combat_runtime_clip_baker.gd",
		"local": "var trajectory_volume_config: Dictionary = _normalize_trajectory_volume_config",
		"origin": "var baked_positions_origin_id: StringName = StringName(trajectory_volume_config.get(",
		"max_lines": 6,
	},
	{
		"id": "clip_baker_origin_local_config",
		"path": "res://core/resolvers/combat_runtime_clip_baker.gd",
		"local": "if resolved_config.has(\"origin_local\"):",
		"origin": "resolved_config[\"origin_local_origin_id\"] = origin_local_origin_id",
		"max_lines": 5,
	},
	{
		"id": "runtime_chain_compiler_volume_config_origin",
		"path": "res://core/resolvers/combat_animation_runtime_chain_compiler.gd",
		"local": "var resolved_volume_config: Dictionary = _normalize_volume_config(volume_config)",
		"origin": "result[\"trajectory_volume_origin_local_origin_id\"] = resolved_volume_config.get(",
		"max_lines": 5,
	},
	{
		"id": "runtime_chain_compiler_origin_local_config",
		"path": "res://core/resolvers/combat_animation_runtime_chain_compiler.gd",
		"local": "config[\"origin_local\"] = Vector3.ZERO",
		"origin": "config[\"origin_local_origin_id\"] = origin_local_origin_id",
		"max_lines": 6,
	},
	{
		"id": "chain_player_tip_current",
		"path": "res://runtime/combat/combat_animation_chain_player.gd",
		"local": "var current_tip_position: Vector3",
		"origin": "var current_tip_position_origin_id",
		"max_lines": 2,
	},
	{
		"id": "chain_player_pommel_current",
		"path": "res://runtime/combat/combat_animation_chain_player.gd",
		"local": "var current_pommel_position: Vector3",
		"origin": "var current_pommel_position_origin_id",
		"max_lines": 2,
	},
	{
		"id": "chain_player_contact_axis_current",
		"path": "res://runtime/combat/combat_animation_chain_player.gd",
		"local": "var current_contact_grip_axis_local: Vector3",
		"origin": "var current_contact_grip_axis_origin_id",
		"max_lines": 2,
	},
	{
		"id": "chain_player_solved_weapon_current",
		"path": "res://runtime/combat/combat_animation_chain_player.gd",
		"local": "var current_solved_weapon_position_reference_local: Vector3",
		"origin": "var current_solved_weapon_reference_origin_id",
		"max_lines": 4,
	},
	{
		"id": "chain_player_solved_anchor_current",
		"path": "res://runtime/combat/combat_animation_chain_player.gd",
		"local": "var current_solved_anchor_positions_weapon_local: Array",
		"origin": "var current_solved_anchor_origin_id",
		"max_lines": 4,
	},
	{
		"id": "preview_frame_motion_tip",
		"path": "res://runtime/combat/combat_animation_station_preview_presenter.gd",
		"local": "motion_node.tip_position_local = _get_runtime_clip_frame_vector3",
		"origin": "motion_node.tip_position_origin_id = _get_runtime_clip_origin_id",
		"max_lines": 8,
	},
	{
		"id": "preview_frame_motion_pommel",
		"path": "res://runtime/combat/combat_animation_station_preview_presenter.gd",
		"local": "motion_node.pommel_position_local = _get_runtime_clip_frame_vector3",
		"origin": "motion_node.pommel_position_origin_id = _get_runtime_clip_origin_id",
		"max_lines": 8,
	},
	{
		"id": "preview_playback_tip_dictionary",
		"path": "res://runtime/combat/combat_animation_station_preview_presenter.gd",
		"local": "\"tip_position_local\": motion_node.tip_position_local",
		"origin": "\"tip_position_origin_id\": motion_node.tip_position_origin_id",
		"max_lines": 2,
	},
	{
		"id": "preview_playback_pommel_dictionary",
		"path": "res://runtime/combat/combat_animation_station_preview_presenter.gd",
		"local": "\"pommel_position_local\": motion_node.pommel_position_local",
		"origin": "\"pommel_position_origin_id\": motion_node.pommel_position_origin_id",
		"max_lines": 2,
	},
	{
		"id": "preview_playback_contact_axis_dictionary",
		"path": "res://runtime/combat/combat_animation_station_preview_presenter.gd",
		"local": "\"contact_grip_axis_local\": _get_runtime_clip_frame_vector3",
		"origin": "\"contact_grip_axis_origin_id\": _get_runtime_clip_origin_id",
		"max_lines": 8,
	},
	{
		"id": "skill_playback_effective_tip",
		"path": "res://runtime/player/player_runtime_skill_playback_presenter.gd",
		"local": "effective_motion_node.tip_position_local = chain_player.current_tip_position",
		"origin": "effective_motion_node.tip_position_origin_id = chain_player.current_tip_position_origin_id",
		"max_lines": 2,
	},
	{
		"id": "skill_playback_effective_pommel",
		"path": "res://runtime/player/player_runtime_skill_playback_presenter.gd",
		"local": "effective_motion_node.pommel_position_local = chain_player.current_pommel_position",
		"origin": "effective_motion_node.pommel_position_origin_id = chain_player.current_pommel_position_origin_id",
		"max_lines": 2,
	},
	{
		"id": "skill_playback_state_tip_dictionary",
		"path": "res://runtime/player/player_runtime_skill_playback_presenter.gd",
		"local": "\"tip_position_local\": chain_player.current_tip_position",
		"origin": "\"tip_position_origin_id\": chain_player.current_tip_position_origin_id",
		"max_lines": 2,
	},
	{
		"id": "skill_playback_state_pommel_dictionary",
		"path": "res://runtime/player/player_runtime_skill_playback_presenter.gd",
		"local": "\"pommel_position_local\": chain_player.current_pommel_position",
		"origin": "\"pommel_position_origin_id\": chain_player.current_pommel_position_origin_id",
		"max_lines": 2,
	},
	{
		"id": "skill_playback_state_contact_axis_dictionary",
		"path": "res://runtime/player/player_runtime_skill_playback_presenter.gd",
		"local": "\"contact_grip_axis_local\": chain_player.current_contact_grip_axis_local",
		"origin": "\"contact_grip_axis_origin_id\": chain_player.current_contact_grip_axis_origin_id",
		"max_lines": 2,
	},
	{
		"id": "skill_playback_state_solved_weapon_dictionary",
		"path": "res://runtime/player/player_runtime_skill_playback_presenter.gd",
		"local": "\"solved_weapon_position_reference_local\": chain_player.current_solved_weapon_position_reference_local",
		"origin": "\"solved_weapon_reference_origin_id\": chain_player.current_solved_weapon_reference_origin_id",
		"max_lines": 4,
	},
	{
		"id": "skill_playback_state_solved_anchor_dictionary",
		"path": "res://runtime/player/player_runtime_skill_playback_presenter.gd",
		"local": "\"solved_anchor_positions_weapon_local\": chain_player.current_solved_anchor_positions_weapon_local.duplicate()",
		"origin": "\"solved_anchor_origin_id\": chain_player.current_solved_anchor_origin_id",
		"max_lines": 4,
	},
	{
		"id": "equipped_item_weapon_tip_meta",
		"path": "res://runtime/player/player_equipped_item_presenter.gd",
		"local": "_set_origin_tracked_vector3_meta(held_root, \"weapon_tip_local\"",
		"origin": "\"weapon_tip_origin_id\"",
		"max_lines": 2,
	},
	{
		"id": "equipped_item_weapon_pommel_meta",
		"path": "res://runtime/player/player_equipped_item_presenter.gd",
		"local": "_set_origin_tracked_vector3_meta(held_root, \"weapon_pommel_local\"",
		"origin": "\"weapon_pommel_origin_id\"",
		"max_lines": 2,
	},
	{
		"id": "equipped_item_primary_contact_meta",
		"path": "res://runtime/player/player_equipped_item_presenter.gd",
		"local": "_set_origin_tracked_vector3_meta(held_root, \"primary_grip_contact_local\"",
		"origin": "\"primary_grip_contact_origin_id\"",
		"max_lines": 2,
	},
	{
		"id": "equipped_item_stow_requested_tip_meta",
		"path": "res://runtime/player/player_equipped_item_presenter.gd",
		"local": "\"station_stow_requested_tip_position_local\"",
		"origin": "\"station_stow_requested_tip_position_origin_id\"",
		"max_lines": 2,
	},
	{
		"id": "equipped_item_stow_requested_pommel_meta",
		"path": "res://runtime/player/player_equipped_item_presenter.gd",
		"local": "\"station_stow_requested_pommel_position_local\"",
		"origin": "\"station_stow_requested_pommel_position_origin_id\"",
		"max_lines": 2,
	},
	{
		"id": "equipped_item_stow_tip_meta",
		"path": "res://runtime/player/player_equipped_item_presenter.gd",
		"local": "\"station_stow_tip_position_local\"",
		"origin": "\"station_stow_tip_position_origin_id\"",
		"max_lines": 2,
	},
	{
		"id": "equipped_item_stow_pommel_meta",
		"path": "res://runtime/player/player_equipped_item_presenter.gd",
		"local": "\"station_stow_pommel_position_local\"",
		"origin": "\"station_stow_pommel_position_origin_id\"",
		"max_lines": 2,
	},
	{
		"id": "humanoid_solved_replay_reference_state",
		"path": "res://runtime/player/player_humanoid_rig.gd",
		"local": "\"reference_bone_name\": reference_bone_name",
		"origin": "\"reference_origin_id\": reference_origin_id",
		"max_lines": 2,
	},
	{
		"id": "humanoid_solved_replay_weapon_state",
		"path": "res://runtime/player/player_humanoid_rig.gd",
		"local": "\"weapon_position_reference_local\": weapon_position_reference_local",
		"origin": "\"weapon_reference_origin_id\": weapon_reference_origin_id",
		"max_lines": 4,
	},
	{
		"id": "humanoid_solved_replay_anchor_state",
		"path": "res://runtime/player/player_humanoid_rig.gd",
		"local": "\"anchor_positions_weapon_local\": anchor_positions_weapon_local.duplicate()",
		"origin": "\"anchor_origin_id\": anchor_origin_id",
		"max_lines": 4,
	},
	{
		"id": "humanoid_hip_stow_direction_origin",
		"path": "res://runtime/player/player_humanoid_rig.gd",
		"local": "var hip_stow_right_direction_local: Vector3 = _resolve_hip_stow_right_direction_local()",
		"origin": "var hip_stow_right_direction_origin_id: StringName = stow_anchor_origin_id",
		"max_lines": 3,
	},
	{
		"id": "humanoid_stow_anchor_position_origin",
		"path": "res://runtime/player/player_humanoid_rig.gd",
		"local": "var anchor_position_local: Vector3 = _resolve_stow_anchor_local_position(",
		"origin": "var anchor_position_origin_id: StringName = _resolve_stow_anchor_position_origin_id(",
		"max_lines": 2,
	},
	{
		"id": "humanoid_stow_anchor_rotation_origin",
		"path": "res://runtime/player/player_humanoid_rig.gd",
		"local": "var anchor_rotation_degrees_local: Vector3 = _resolve_stow_anchor_rotation_degrees_local(",
		"origin": "var anchor_rotation_degrees_origin_id: StringName = CombatOriginRecordScript.ORIGIN_STOW_ANCHOR",
		"max_lines": 2,
	},
	{
		"id": "humanoid_stow_attachment_position_call_origin",
		"path": "res://runtime/player/player_humanoid_rig.gd",
		"local": "anchor_position_local,",
		"origin": "anchor_position_origin_id,",
		"max_lines": 5,
	},
	{
		"id": "humanoid_stow_attachment_rotation_call_origin",
		"path": "res://runtime/player/player_humanoid_rig.gd",
		"local": "anchor_rotation_degrees_local,",
		"origin": "anchor_rotation_degrees_origin_id",
		"max_lines": 5,
	},
	{
		"id": "rig_model_anchor_position_meta_origin",
		"path": "res://runtime/player/player_rig_model_presenter.gd",
		"local": "anchor.set_meta(\"anchor_position_local\"",
		"origin": "anchor.set_meta(\"anchor_position_origin_id\"",
		"max_lines": 2,
	},
	{
		"id": "rig_model_anchor_rotation_meta_origin",
		"path": "res://runtime/player/player_rig_model_presenter.gd",
		"local": "anchor.set_meta(\"anchor_rotation_degrees_local\"",
		"origin": "anchor.set_meta(\"anchor_rotation_degrees_origin_id\"",
		"max_lines": 2,
	},
	{
		"id": "draft_noncombat_stow_origin_override",
		"path": "res://core/models/combat_animation_draft.gd",
		"local": "tip_position_origin_id = CombatOriginRecordScript.ORIGIN_STOW_ANCHOR",
		"origin": "pommel_position_origin_id = CombatOriginRecordScript.ORIGIN_STOW_ANCHOR",
		"max_lines": 2,
	},
	{
		"id": "draft_default_tip_origin_write",
		"path": "res://core/models/combat_animation_draft.gd",
		"local": "motion_node.tip_position_local = tip_position",
		"origin": "motion_node.tip_position_origin_id = resolved_tip_origin_id",
		"max_lines": 2,
	},
	{
		"id": "draft_default_pommel_origin_write",
		"path": "res://core/models/combat_animation_draft.gd",
		"local": "motion_node.pommel_position_local = pommel_position",
		"origin": "motion_node.pommel_position_origin_id = resolved_pommel_origin_id",
		"max_lines": 2,
	},
	{
		"id": "draft_default_noncombat_stow_origin_resolver",
		"path": "res://core/models/combat_animation_draft.gd",
		"local": "context_id_value == IDLE_CONTEXT_NONCOMBAT",
		"origin": "return CombatOriginRecordScript.ORIGIN_STOW_ANCHOR",
		"max_lines": 2,
	},
	{
		"id": "station_ui_noncombat_segment_tip_origin",
		"path": "res://runtime/combat/combat_animation_station_ui.gd",
		"local": "\"tip_position_local\": pivot_position_local",
		"origin": "\"tip_position_origin_id\": resolved_pivot_origin_id",
		"max_lines": 2,
	},
	{
		"id": "station_ui_noncombat_segment_pommel_origin",
		"path": "res://runtime/combat/combat_animation_station_ui.gd",
		"local": "\"pommel_position_local\": pivot_position_local",
		"origin": "\"pommel_position_origin_id\": resolved_pivot_origin_id",
		"max_lines": 2,
	},
	{
		"id": "station_ui_noncombat_pivot_origin_param",
		"path": "res://runtime/combat/combat_animation_station_ui.gd",
		"local": "func _build_noncombat_stow_segment_from_axis(",
		"origin": "pivot_position_origin_id: StringName = CombatOriginRecordScript.ORIGIN_STOW_ANCHOR",
		"max_lines": 6,
	},
	{
		"id": "station_ui_noncombat_tip_request_origin_param",
		"path": "res://runtime/combat/combat_animation_station_ui.gd",
		"local": "func _resolve_noncombat_stow_segment_for_tip_target(",
		"origin": "requested_tip_position_origin_id: StringName = CombatOriginRecordScript.ORIGIN_STOW_ANCHOR",
		"max_lines": 5,
	},
	{
		"id": "station_ui_noncombat_pommel_request_origin_param",
		"path": "res://runtime/combat/combat_animation_station_ui.gd",
		"local": "func _resolve_noncombat_stow_segment_for_pommel_target(",
		"origin": "requested_pommel_position_origin_id: StringName = CombatOriginRecordScript.ORIGIN_STOW_ANCHOR",
		"max_lines": 5,
	},
	{
		"id": "station_ui_direct_tip_request_origin_param",
		"path": "res://runtime/combat/combat_animation_station_ui.gd",
		"local": "func _resolve_motion_node_segment_for_tip_target(",
		"origin": "requested_tip_position_origin_id: StringName = StringName()",
		"max_lines": 5,
	},
	{
		"id": "station_ui_direct_pommel_request_origin_param",
		"path": "res://runtime/combat/combat_animation_station_ui.gd",
		"local": "func _resolve_motion_node_segment_for_pommel_target(",
		"origin": "requested_pommel_position_origin_id: StringName = StringName()",
		"max_lines": 5,
	},
	{
		"id": "station_ui_direct_tip_segment_origin",
		"path": "res://runtime/combat/combat_animation_station_ui.gd",
		"local": "\"tip_position_local\": constrained_tip",
		"origin": "\"tip_position_origin_id\": resolved_tip_origin_id",
		"max_lines": 2,
	},
	{
		"id": "station_ui_direct_tip_segment_pommel_origin",
		"path": "res://runtime/combat/combat_animation_station_ui.gd",
		"local": "\"pommel_position_local\": motion_node.pommel_position_local",
		"origin": "\"pommel_position_origin_id\": resolved_pommel_origin_id",
		"max_lines": 2,
	},
	{
		"id": "station_ui_direct_pommel_segment_tip_origin",
		"path": "res://runtime/combat/combat_animation_station_ui.gd",
		"local": "\"tip_position_local\": motion_node.tip_position_local + pommel_translation",
		"origin": "\"tip_position_origin_id\": resolved_tip_origin_id",
		"max_lines": 2,
	},
	{
		"id": "station_ui_direct_pommel_segment_origin",
		"path": "res://runtime/combat/combat_animation_station_ui.gd",
		"local": "\"pommel_position_local\": requested_pommel_position_local",
		"origin": "\"pommel_position_origin_id\": resolved_pommel_origin_id",
		"max_lines": 2,
	},
	{
		"id": "station_ui_apply_segment_tip_origin",
		"path": "res://runtime/combat/combat_animation_station_ui.gd",
		"local": "var resolved_tip: Vector3 = resolved_segment.get(\"tip_position_local\"",
		"origin": "var resolved_tip_origin_id: StringName = StringName(resolved_segment.get(\"tip_position_origin_id\"",
		"max_lines": 4,
	},
	{
		"id": "station_ui_apply_segment_pommel_origin",
		"path": "res://runtime/combat/combat_animation_station_ui.gd",
		"local": "var resolved_pommel: Vector3 = resolved_segment.get(\"pommel_position_local\"",
		"origin": "var resolved_pommel_origin_id: StringName = StringName(resolved_segment.get(\"pommel_position_origin_id\"",
		"max_lines": 4,
	},
	{
		"id": "station_ui_stored_noncombat_stow_origin",
		"path": "res://runtime/combat/combat_animation_station_ui.gd",
		"local": "stored_source.tip_position_local -= stow_anchor_offset_local",
		"origin": "stored_source.tip_position_origin_id = CombatOriginRecordScript.ORIGIN_STOW_ANCHOR",
		"max_lines": 5,
	},
	{
		"id": "station_ui_seed_vector_helper_origin",
		"path": "res://runtime/combat/combat_animation_station_ui.gd",
		"local": "value_key: String,",
		"origin": "origin_key: String,",
		"max_lines": 2,
	},
	{
		"id": "station_ui_motion_seed_tip_apply_origin",
		"path": "res://runtime/combat/combat_animation_station_ui.gd",
		"local": "motion_node.tip_position_local = _get_origin_tracked_seed_vector3(",
		"origin": "motion_node.tip_position_origin_id = seed_tip_origin_id",
		"max_lines": 8,
	},
	{
		"id": "station_ui_motion_seed_pommel_apply_origin",
		"path": "res://runtime/combat/combat_animation_station_ui.gd",
		"local": "motion_node.pommel_position_local = _get_origin_tracked_seed_vector3(",
		"origin": "motion_node.pommel_position_origin_id = seed_pommel_origin_id",
		"max_lines": 8,
	},
	{
		"id": "station_ui_curve_handle_position_origin",
		"path": "res://runtime/combat/combat_animation_station_ui.gd",
		"local": "handle_position_local: Vector3,",
		"origin": "handle_position_origin_id: StringName = CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING",
		"max_lines": 2,
	},
	{
		"id": "station_ui_weapon_geometry_seed_origin",
		"path": "res://runtime/combat/combat_animation_station_ui.gd",
		"local": "var geometry_seed: Dictionary = weapon_geometry_resolver.resolve_motion_seed_data",
		"origin": "_ensure_motion_seed_position_origins(geometry_seed, CombatOriginRecordScript.ORIGIN_WEAPON_ROOT)",
		"max_lines": 5,
	},
	{
		"id": "station_ui_unarmed_fallback_seed_tip_origin",
		"path": "res://runtime/combat/combat_animation_station_ui.gd",
		"local": "\"tip_position_local\": Vector3(0.12, 0.0, 0.0)",
		"origin": "\"tip_position_origin_id\": CombatOriginRecordScript.ORIGIN_HAND_GRIP_ALIGNMENT",
		"max_lines": 2,
	},
	{
		"id": "station_ui_unarmed_fallback_seed_pommel_origin",
		"path": "res://runtime/combat/combat_animation_station_ui.gd",
		"local": "\"pommel_position_local\": Vector3(-0.12, 0.0, 0.0)",
		"origin": "\"pommel_position_origin_id\": CombatOriginRecordScript.ORIGIN_HAND_GRIP_ALIGNMENT",
		"max_lines": 2,
	},
	{
		"id": "station_ui_retarget_origin_local_origin",
		"path": "res://runtime/combat/combat_animation_station_ui.gd",
		"local": "config[\"origin_local\"] = Vector3.ZERO",
		"origin": "config[\"origin_local_origin_id\"] = _normalize_seed_origin_id",
		"max_lines": 8,
	},
	{
		"id": "station_ui_stow_marker_positions_read_origin",
		"path": "res://runtime/combat/combat_animation_station_ui.gd",
		"local": "var marker_positions: Dictionary = preview_debug_state.get(\"stow_anchor_marker_positions_local\"",
		"origin": "var marker_positions_origin_id: StringName = _normalize_seed_origin_id",
		"max_lines": 4,
	},
	{
		"id": "station_ui_playback_state_tip_origin",
		"path": "res://runtime/combat/combat_animation_station_ui.gd",
		"local": "playback_state[\"tip_position_local\"] = chain_player.current_tip_position",
		"origin": "playback_state[\"tip_position_origin_id\"] = chain_player.current_tip_position_origin_id",
		"max_lines": 2,
	},
	{
		"id": "station_ui_playback_state_pommel_origin",
		"path": "res://runtime/combat/combat_animation_station_ui.gd",
		"local": "playback_state[\"pommel_position_local\"] = chain_player.current_pommel_position",
		"origin": "playback_state[\"pommel_position_origin_id\"] = chain_player.current_pommel_position_origin_id",
		"max_lines": 2,
	},
	{
		"id": "station_ui_playback_state_contact_axis_origin",
		"path": "res://runtime/combat/combat_animation_station_ui.gd",
		"local": "playback_state[\"contact_grip_axis_local\"] = chain_player.current_contact_grip_axis_local",
		"origin": "playback_state[\"contact_grip_axis_origin_id\"] = chain_player.current_contact_grip_axis_origin_id",
		"max_lines": 2,
	},
	{
		"id": "station_ui_display_tip_meta_origin",
		"path": "res://runtime/combat/combat_animation_station_ui.gd",
		"local": "display_motion_node.tip_position_local = _get_origin_tracked_vector3_meta",
		"origin": "display_motion_node.tip_position_origin_id = _resolve_origin_meta_value",
		"max_lines": 8,
	},
	{
		"id": "station_ui_display_pommel_meta_origin",
		"path": "res://runtime/combat/combat_animation_station_ui.gd",
		"local": "display_motion_node.pommel_position_local = _get_origin_tracked_vector3_meta",
		"origin": "display_motion_node.pommel_position_origin_id = _resolve_origin_meta_value",
		"max_lines": 8,
	},
	{
		"id": "skill_playback_resolved_tip_origin",
		"path": "res://runtime/player/player_runtime_skill_playback_presenter.gd",
		"local": "resolved_playback_state[\"tip_position_local\"] = trajectory_inverse * solved_tip_world",
		"origin": "resolved_playback_state[\"tip_position_origin_id\"] = CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING",
		"max_lines": 2,
	},
	{
		"id": "skill_playback_resolved_pommel_origin",
		"path": "res://runtime/player/player_runtime_skill_playback_presenter.gd",
		"local": "resolved_playback_state[\"pommel_position_local\"] = trajectory_inverse * solved_pommel_world",
		"origin": "resolved_playback_state[\"pommel_position_origin_id\"] = CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING",
		"max_lines": 2,
	},
	{
		"id": "skill_playback_solved_replay_tip_origin",
		"path": "res://runtime/player/player_runtime_skill_playback_presenter.gd",
		"local": "playback_state[\"tip_position_local\"] = reference_inverse * solved_tip_world",
		"origin": "playback_state[\"tip_position_origin_id\"] = CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING",
		"max_lines": 2,
	},
	{
		"id": "skill_playback_chain_snapshot_tip_origin",
		"path": "res://runtime/player/player_runtime_skill_playback_presenter.gd",
		"local": "snapshot.tip_position_local = source_chain_player.current_tip_position",
		"origin": "snapshot.tip_position_origin_id = source_chain_player.current_tip_position_origin_id",
		"max_lines": 2,
	},
	{
		"id": "skill_playback_pose_state_tip_origin",
		"path": "res://runtime/player/player_runtime_skill_playback_presenter.gd",
		"local": "snapshot.tip_position_local = pose_state.get(\"tip_position_local\"",
		"origin": "snapshot.tip_position_origin_id = StringName(pose_state.get(\"tip_position_origin_id\"",
		"max_lines": 2,
	},
	{
		"id": "skill_playback_contact_axis_override_origin",
		"path": "res://runtime/player/player_runtime_skill_playback_presenter.gd",
		"local": "held_item.set_meta(\"authoring_contact_grip_axis_world_override\"",
		"origin": "held_item.set_meta(\"authoring_contact_grip_axis_origin_id\"",
		"max_lines": 2,
	},
	{
		"id": "skill_playback_contact_axis_override_active_read_origin",
		"path": "res://runtime/player/player_runtime_skill_playback_presenter.gd",
		"local": "playback_state.get(\"contact_grip_axis_local_override_active\"",
		"origin": "var contact_grip_axis_override_active_origin_id: StringName",
		"max_lines": 5,
	},
	{
		"id": "skill_playback_cached_clip_origin_fallback",
		"path": "res://runtime/player/player_runtime_skill_playback_presenter.gd",
		"local": "target_clip.set(\"solved_replay_reference_origin_id\", _get_clip_origin_id",
		"origin": "CombatOriginRecordScript.ORIGIN_SOLVED_REPLAY_REFERENCE",
		"max_lines": 5,
	},
	{
		"id": "preview_tip_pommel_state_writer_tip_origin",
		"path": "res://runtime/combat/combat_animation_station_preview_presenter.gd",
		"local": "target_state[\"tip_position_local\"] = tip_position_local",
		"origin": "target_state[\"tip_position_origin_id\"] = resolved_origin_id",
		"max_lines": 2,
	},
	{
		"id": "preview_tip_pommel_state_writer_pommel_origin",
		"path": "res://runtime/combat/combat_animation_station_preview_presenter.gd",
		"local": "target_state[\"pommel_position_local\"] = pommel_position_local",
		"origin": "target_state[\"pommel_position_origin_id\"] = resolved_origin_id",
		"max_lines": 2,
	},
	{
		"id": "preview_runtime_resolved_tip_origin_writer",
		"path": "res://runtime/combat/combat_animation_station_preview_presenter.gd",
		"local": "_set_tip_pommel_position_state(",
		"origin": "CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING",
		"max_lines": 6,
	},
	{
		"id": "preview_noncombat_stow_origin_stamp",
		"path": "res://runtime/combat/combat_animation_station_preview_presenter.gd",
		"local": "resolved_playback_state[\"noncombat_stow_decoupled\"] = true",
		"origin": "CombatOriginRecordScript.ORIGIN_NONCOMBAT_STOW",
		"max_lines": 12,
	},
	{
		"id": "preview_seed_tip_origin",
		"path": "res://runtime/combat/combat_animation_station_preview_presenter.gd",
		"local": "resolved_seed[\"tip_position_local\"] = tip_local",
		"origin": "resolved_seed[\"tip_position_origin_id\"] = CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING",
		"max_lines": 2,
	},
	{
		"id": "preview_unarmed_seed_tip_origin",
		"path": "res://runtime/combat/combat_animation_station_preview_presenter.gd",
		"local": "\"tip_position_local\": trajectory_root.to_local(tip_world)",
		"origin": "\"tip_position_origin_id\": CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING",
		"max_lines": 2,
	},
	{
		"id": "preview_display_motion_tip_origin",
		"path": "res://runtime/combat/combat_animation_station_preview_presenter.gd",
		"local": "display_motion_node.tip_position_local = _get_origin_tracked_vector3_state(",
		"origin": "display_motion_node.tip_position_origin_id = _resolve_origin_tracked_state_origin_id(",
		"max_lines": 8,
	},
	{
		"id": "preview_effective_motion_tip_origin",
		"path": "res://runtime/combat/combat_animation_station_preview_presenter.gd",
		"local": "effective_motion_node.tip_position_local = _get_origin_tracked_vector3_state(",
		"origin": "effective_motion_node.tip_position_origin_id = _resolve_origin_tracked_state_origin_id(",
		"max_lines": 8,
	},
	{
		"id": "preview_contact_axis_override_origin",
		"path": "res://runtime/combat/combat_animation_station_preview_presenter.gd",
		"local": "held_item.set_meta(\"authoring_contact_grip_axis_world_override\"",
		"origin": "held_item.set_meta(\"authoring_contact_grip_axis_origin_id\"",
		"max_lines": 2,
	},
	{
		"id": "preview_contact_axis_override_active_read_origin",
		"path": "res://runtime/combat/combat_animation_station_preview_presenter.gd",
		"local": "playback_state.get(\"contact_grip_axis_local_override_active\"",
		"origin": "var contact_grip_axis_override_active_origin_id: StringName",
		"max_lines": 5,
	},
	{
		"id": "preview_debug_body_lock_frame_origin",
		"path": "res://runtime/combat/combat_animation_station_preview_presenter.gd",
		"local": "\"body_lock_frame_origin\": _resolve_preview_body_lock_frame(actor).origin",
		"origin": "\"body_lock_frame_origin_id\": _resolve_preview_body_lock_frame_origin_id(actor)",
		"max_lines": 2,
	},
	{
		"id": "preview_contact_tether_body_lock_origin",
		"path": "res://runtime/combat/combat_animation_station_preview_presenter.gd",
		"local": "var body_lock_frame: Transform3D = _resolve_preview_body_lock_frame(actor)",
		"origin": "var body_lock_origin_id: StringName = _resolve_preview_body_lock_frame_origin_id(actor)",
		"max_lines": 2,
	},
	{
		"id": "preview_contact_tether_occupied_target_lock_origin",
		"path": "res://runtime/combat/combat_animation_station_preview_presenter.gd",
		"local": "var occupied_primary_target_lock_local: Vector3 = Vector3.INF",
		"origin": "var occupied_primary_target_lock_origin_id: StringName = body_lock_origin_id",
		"max_lines": 2,
	},
	{
		"id": "preview_contact_tether_tip_lock_origin",
		"path": "res://runtime/combat/combat_animation_station_preview_presenter.gd",
		"local": "var tip_lock_local: Vector3 = tip_position_local",
		"origin": "var tip_lock_origin_id: StringName = body_lock_origin_id",
		"max_lines": 2,
	},
	{
		"id": "preview_contact_tether_signature_requested_tip_origin",
		"path": "res://runtime/combat/combat_animation_station_preview_presenter.gd",
		"local": "requested_tip_lock_local: Vector3",
		"origin": "requested_tip_lock_origin_id: StringName",
		"max_lines": 2,
	},
	{
		"id": "preview_contact_tether_metrics_body_lock_origin",
		"path": "res://runtime/combat/combat_animation_station_preview_presenter.gd",
		"local": "\"body_lock_origin_id\": body_lock_origin_id",
		"origin": "\"requested_tip_lock_origin_id\": requested_tip_lock_origin_id",
		"max_lines": 2,
	},
	{
		"id": "preview_tip_pivot_shoulder_lock_origin",
		"path": "res://runtime/combat/combat_animation_station_preview_presenter.gd",
		"local": "var shoulder_lock_local: Vector3 = body_lock_frame.affine_inverse() * shoulder_world",
		"origin": "var shoulder_lock_origin_id: StringName = body_lock_origin_id",
		"max_lines": 2,
	},
	{
		"id": "preview_tip_pivot_requested_axis_lock_origin",
		"path": "res://runtime/combat/combat_animation_station_preview_presenter.gd",
		"local": "var requested_axis_lock_local: Vector3 = requested_tip_lock_local - pivot_lock_local",
		"origin": "var requested_axis_lock_origin_id: StringName = body_lock_origin_id",
		"max_lines": 2,
	},
	{
		"id": "preview_grip_span_projected_origin",
		"path": "res://runtime/combat/combat_animation_station_preview_presenter.gd",
		"local": "\"projected_local\": projected_local",
		"origin": "\"projected_origin_id\": CombatOriginRecordScript.ORIGIN_WEAPON_ROOT",
		"max_lines": 2,
	},
	{
		"id": "preview_grip_span_projected_read_origin",
		"path": "res://runtime/combat/combat_animation_station_preview_presenter.gd",
		"local": "\"projected_local\",",
		"origin": "\"projected_origin_id\",",
		"max_lines": 3,
	},
	{
		"id": "preview_grip_span_start_meta_read_origin",
		"path": "res://runtime/combat/combat_animation_station_preview_presenter.gd",
		"local": "\"primary_grip_span_start_local\",",
		"origin": "\"primary_grip_span_start_origin_id\",",
		"max_lines": 3,
	},
	{
		"id": "preview_grip_span_end_meta_read_origin",
		"path": "res://runtime/combat/combat_animation_station_preview_presenter.gd",
		"local": "\"primary_grip_span_end_local\",",
		"origin": "\"primary_grip_span_end_origin_id\",",
		"max_lines": 3,
	},
	{
		"id": "preview_unarmed_grip_axis_origin",
		"path": "res://runtime/combat/combat_animation_station_preview_presenter.gd",
		"local": "var grip_axis_local: Vector3 = (local_tip - local_pommel).normalized()",
		"origin": "var grip_axis_origin_id: StringName = CombatOriginRecordScript.ORIGIN_WEAPON_ROOT",
		"max_lines": 2,
	},
	{
		"id": "preview_unarmed_grip_shell_axis_meta_origin",
		"path": "res://runtime/combat/combat_animation_station_preview_presenter.gd",
		"local": "\"grip_shell_major_axis_local\",",
		"origin": "\"grip_shell_major_axis_origin_id\",",
		"max_lines": 3,
	},
	{
		"id": "preview_unarmed_primary_span_start_meta_write_origin",
		"path": "res://runtime/combat/combat_animation_station_preview_presenter.gd",
		"local": "\"primary_grip_span_start_local\",",
		"origin": "\"primary_grip_span_start_origin_id\",",
		"max_lines": 3,
	},
	{
		"id": "preview_unarmed_primary_span_end_meta_write_origin",
		"path": "res://runtime/combat/combat_animation_station_preview_presenter.gd",
		"local": "\"primary_grip_span_end_local\",",
		"origin": "\"primary_grip_span_end_origin_id\",",
		"max_lines": 3,
	},
	{
		"id": "preview_unarmed_primary_slide_axis_meta_write_origin",
		"path": "res://runtime/combat/combat_animation_station_preview_presenter.gd",
		"local": "\"primary_grip_slide_axis_local\",",
		"origin": "\"primary_grip_slide_axis_origin_id\",",
		"max_lines": 3,
	},
	{
		"id": "equipped_item_ensure_origin_meta",
		"path": "res://runtime/player/player_equipped_item_presenter.gd",
		"local": "func _ensure_origin_meta",
		"origin": "target.set_meta(meta_name, fallback_origin_id)",
		"max_lines": 8,
	},
	{
		"id": "equipped_item_stow_segment_tip_origin",
		"path": "res://runtime/player/player_equipped_item_presenter.gd",
		"local": "\"tip_position_local\": stow_motion_node.tip_position_local - contact_position_local",
		"origin": "\"tip_position_origin_id\": CombatOriginRecordScript.ORIGIN_STOW_ANCHOR",
		"max_lines": 2,
	},
	{
		"id": "equipped_item_stow_contact_state_origin",
		"path": "res://runtime/player/player_equipped_item_presenter.gd",
		"local": "\"contact_position_local\": stow_motion_node.pommel_position_local.lerp(",
		"origin": "\"contact_position_origin_id\": contact_position_origin_id",
		"max_lines": 6,
	},
	{
		"id": "equipped_item_stow_contact_read_origin",
		"path": "res://runtime/player/player_equipped_item_presenter.gd",
		"local": "var contact_position_local: Vector3 = _get_origin_tracked_vector3_state(",
		"origin": "\"contact_position_origin_id\",",
		"max_lines": 4,
	},
	{
		"id": "equipped_item_stow_contact_result_origin",
		"path": "res://runtime/player/player_equipped_item_presenter.gd",
		"local": "\"contact_position_local\": contact_position_local",
		"origin": "\"contact_position_origin_id\": contact_position_origin_id",
		"max_lines": 2,
	},
	{
		"id": "equipped_item_stow_read_tip_origin",
		"path": "res://runtime/player/player_equipped_item_presenter.gd",
		"local": "var local_tip: Vector3 = _get_weapon_tip_meta(held_item)",
		"origin": "func _get_weapon_tip_meta",
		"max_lines": 256,
	},
	{
		"id": "preview_primary_grip_seat_meta_origin",
		"path": "res://runtime/combat/combat_animation_station_preview_presenter.gd",
		"local": "const PREVIEW_PRIMARY_GRIP_SEAT_LOCAL_META",
		"origin": "const PREVIEW_PRIMARY_GRIP_SEAT_ORIGIN_META",
		"max_lines": 2,
	},
	{
		"id": "preview_support_grip_seat_meta_origin",
		"path": "res://runtime/combat/combat_animation_station_preview_presenter.gd",
		"local": "const PREVIEW_SUPPORT_GRIP_SEAT_LOCAL_META",
		"origin": "const PREVIEW_SUPPORT_GRIP_SEAT_ORIGIN_META",
		"max_lines": 2,
	},
	{
		"id": "preview_hand_mount_transform_meta_origin",
		"path": "res://runtime/combat/combat_animation_station_preview_presenter.gd",
		"local": "const PREVIEW_HAND_MOUNT_LOCAL_TRANSFORM_META",
		"origin": "const PREVIEW_HAND_MOUNT_LOCAL_TRANSFORM_ORIGIN_META",
		"max_lines": 2,
	},
	{
		"id": "preview_hand_mount_transform_write_origin",
		"path": "res://runtime/combat/combat_animation_station_preview_presenter.gd",
		"local": "held_item.set_meta(PREVIEW_HAND_MOUNT_LOCAL_TRANSFORM_META",
		"origin": "held_item.set_meta(PREVIEW_HAND_MOUNT_LOCAL_TRANSFORM_ORIGIN_META",
		"max_lines": 2,
	},
	{
		"id": "preview_unarmed_hand_mount_transform_write_origin",
		"path": "res://runtime/combat/combat_animation_station_preview_presenter.gd",
		"local": "held_root.set_meta(PREVIEW_HAND_MOUNT_LOCAL_TRANSFORM_META",
		"origin": "held_root.set_meta(PREVIEW_HAND_MOUNT_LOCAL_TRANSFORM_ORIGIN_META",
		"max_lines": 2,
	},
	{
		"id": "preview_unarmed_proxy_tip_source_origin",
		"path": "res://runtime/combat/combat_animation_station_preview_presenter.gd",
		"local": "\"tip_local\": anchor_basis_inverse",
		"origin": "\"tip_origin_id\": CombatOriginRecordScript.ORIGIN_HAND_GRIP_ALIGNMENT",
		"max_lines": 2,
	},
	{
		"id": "preview_unarmed_proxy_fallback_tip_origin",
		"path": "res://runtime/combat/combat_animation_station_preview_presenter.gd",
		"local": "\"tip_local\": Vector3(0.12, 0.0, 0.0)",
		"origin": "\"tip_origin_id\": CombatOriginRecordScript.ORIGIN_HAND_GRIP_ALIGNMENT",
		"max_lines": 2,
	},
	{
		"id": "preview_unarmed_proxy_read_tip_origin",
		"path": "res://runtime/combat/combat_animation_station_preview_presenter.gd",
		"local": "\"tip_local\",",
		"origin": "\"tip_origin_id\",",
		"max_lines": 3,
	},
	{
		"id": "preview_stow_marker_positions_result_origin",
		"path": "res://runtime/combat/combat_animation_station_preview_presenter.gd",
		"local": "\"positions_local\": {}",
		"origin": "\"positions_origin_id\": CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING",
		"max_lines": 2,
	},
	{
		"id": "preview_stow_marker_positions_entry_origin",
		"path": "res://runtime/combat/combat_animation_station_preview_presenter.gd",
		"local": "positions_local[anchor_id] = position_local",
		"origin": "position_origin_ids[anchor_id] = position_origin_id",
		"max_lines": 2,
	},
	{
		"id": "preview_stow_marker_positions_result_entry_origin",
		"path": "res://runtime/combat/combat_animation_station_preview_presenter.gd",
		"local": "result[\"positions_local\"] = positions_local",
		"origin": "result[\"position_origin_ids\"] = position_origin_ids",
		"max_lines": 2,
	},
	{
		"id": "preview_stow_marker_positions_meta_origin",
		"path": "res://runtime/combat/combat_animation_station_preview_presenter.gd",
		"local": "preview_root.set_meta(\"stow_anchor_marker_positions_local\"",
		"origin": "preview_root.set_meta(\"stow_anchor_marker_positions_origin_id\"",
		"max_lines": 2,
	},
	{
		"id": "preview_stow_marker_positions_meta_entry_origin",
		"path": "res://runtime/combat/combat_animation_station_preview_presenter.gd",
		"local": "preview_root.set_meta(\"stow_anchor_marker_positions_local\"",
		"origin": "preview_root.set_meta(\"stow_anchor_marker_position_origin_ids\"",
		"max_lines": 3,
	},
	{
		"id": "equipped_hand_mount_transform_meta_origin",
		"path": "res://runtime/player/player_equipped_item_presenter.gd",
		"local": "const HAND_MOUNT_LOCAL_TRANSFORM_META",
		"origin": "const HAND_MOUNT_LOCAL_TRANSFORM_ORIGIN_META",
		"max_lines": 2,
	},
	{
		"id": "equipped_hand_mount_transform_write_origin",
		"path": "res://runtime/player/player_equipped_item_presenter.gd",
		"local": "held_root.set_meta(HAND_MOUNT_LOCAL_TRANSFORM_META",
		"origin": "held_root.set_meta(HAND_MOUNT_LOCAL_TRANSFORM_ORIGIN_META",
		"max_lines": 2,
	},
	{
		"id": "equipped_hand_mount_transform_restyle_origin",
		"path": "res://runtime/player/player_equipped_item_presenter.gd",
		"local": "held_item.set_meta(HAND_MOUNT_LOCAL_TRANSFORM_META",
		"origin": "held_item.set_meta(HAND_MOUNT_LOCAL_TRANSFORM_ORIGIN_META",
		"max_lines": 2,
	},
	{
		"id": "humanoid_hand_alignment_offset_state_origin",
		"path": "res://runtime/player/player_humanoid_rig.gd",
		"local": "\"hand_alignment_offset_local\": resolve_hand_grip_alignment_offset_local(slot_id)",
		"origin": "\"hand_alignment_offset_origin_id\": resolve_hand_grip_alignment_offset_origin_id(slot_id)",
		"max_lines": 2,
	},
	{
		"id": "equipped_hand_alignment_offset_read_origin",
		"path": "res://runtime/player/player_equipped_item_presenter.gd",
		"local": "var hand_alignment_offset_local: Vector3 = _get_origin_tracked_vector3_state(",
		"origin": "\"hand_alignment_offset_origin_id\",",
		"max_lines": 4,
	},
	{
		"id": "equipped_hand_alignment_offset_spawn_meta_origin",
		"path": "res://runtime/player/player_equipped_item_presenter.gd",
		"local": "_set_origin_tracked_vector3_meta(held_root, \"hand_alignment_offset_local\"",
		"origin": "\"hand_alignment_offset_origin_id\"",
		"max_lines": 2,
	},
	{
		"id": "equipped_hand_alignment_offset_restyle_meta_origin",
		"path": "res://runtime/player/player_equipped_item_presenter.gd",
		"local": "_set_origin_tracked_vector3_meta(held_item, \"hand_alignment_offset_local\"",
		"origin": "\"hand_alignment_offset_origin_id\"",
		"max_lines": 2,
	},
	{
		"id": "preview_hand_alignment_offset_read_origin",
		"path": "res://runtime/combat/combat_animation_station_preview_presenter.gd",
		"local": "var grip_offset_local: Vector3 = _get_origin_tracked_vector3_state(",
		"origin": "\"hand_alignment_offset_origin_id\",",
		"max_lines": 4,
	},
	{
		"id": "equipped_reanchor_target_origin",
		"path": "res://runtime/player/player_equipped_item_presenter.gd",
		"local": "var target_anchor: Node3D = _resolve_cached_equipped_visual_anchor",
		"origin": "var target_anchor_origin_id: StringName = _resolve_equipped_visual_anchor_origin_id(weapons_drawn)",
		"max_lines": 5,
	},
	{
		"id": "equipped_reparent_origin_meta",
		"path": "res://runtime/player/player_equipped_item_presenter.gd",
		"local": "func _reparent_held_item_to_anchor(",
		"origin": "held_item.set_meta(EQUIPPED_VISUAL_ANCHOR_ORIGIN_META",
		"max_lines": 24,
	},
	{
		"id": "equipped_spawn_visual_anchor_origin",
		"path": "res://runtime/player/player_equipped_item_presenter.gd",
		"local": "visual_anchor.add_child(equipped_item_node)",
		"origin": "equipped_item_node.set_meta(",
		"max_lines": 3,
	},
	{
		"id": "grip_layout_dominant_hand_default_origin",
		"path": "res://runtime/player/player_rig_grip_layout_presenter.gd",
		"local": "\"dominant_hand_local_position\": Vector3.ZERO",
		"origin": "\"dominant_hand_position_origin_id\": CombatOriginRecordScript.ORIGIN_WEAPON_ROOT",
		"max_lines": 2,
	},
	{
		"id": "grip_layout_support_hand_default_origin",
		"path": "res://runtime/player/player_rig_grip_layout_presenter.gd",
		"local": "\"support_hand_local_position\": Vector3.ZERO",
		"origin": "\"support_hand_position_origin_id\": CombatOriginRecordScript.ORIGIN_WEAPON_ROOT",
		"max_lines": 2,
	},
	{
		"id": "grip_layout_dominant_hand_assignment_origin",
		"path": "res://runtime/player/player_rig_grip_layout_presenter.gd",
		"local": "layout.dominant_hand_local_position = dominant_position",
		"origin": "layout.dominant_hand_position_origin_id = CombatOriginRecordScript.ORIGIN_WEAPON_ROOT",
		"max_lines": 2,
	},
	{
		"id": "grip_layout_support_hand_assignment_origin",
		"path": "res://runtime/player/player_rig_grip_layout_presenter.gd",
		"local": "layout.support_hand_local_position =",
		"origin": "layout.support_hand_position_origin_id = CombatOriginRecordScript.ORIGIN_WEAPON_ROOT",
		"max_lines": 2,
	},
	{
		"id": "equipped_grip_layout_dominant_hand_read_origin",
		"path": "res://runtime/player/player_equipped_item_presenter.gd",
		"local": "dominant_hand_local_position = _get_origin_tracked_vector3_state(",
		"origin": "\"dominant_hand_position_origin_id\",",
		"max_lines": 4,
	},
	{
		"id": "equipped_grip_layout_support_hand_read_origin",
		"path": "res://runtime/player/player_equipped_item_presenter.gd",
		"local": "support_hand_local_position = _get_origin_tracked_vector3_state(",
		"origin": "\"support_hand_position_origin_id\",",
		"max_lines": 4,
	},
	{
		"id": "equipped_grip_shell_slice_center_result_origin",
		"path": "res://runtime/player/player_equipped_item_presenter.gd",
		"local": "\"slice_center_local\": center_local",
		"origin": "\"slice_center_origin_id\": slice_center_origin_id",
		"max_lines": 2,
	},
	{
		"id": "equipped_grip_shell_major_axis_result_origin",
		"path": "res://runtime/player/player_equipped_item_presenter.gd",
		"local": "\"major_axis_local\": major_axis_local",
		"origin": "\"major_axis_origin_id\": major_axis_origin_id",
		"max_lines": 2,
	},
	{
		"id": "equipped_grip_shell_minor_axis_a_result_origin",
		"path": "res://runtime/player/player_equipped_item_presenter.gd",
		"local": "\"minor_axis_a_local\": _axis_index_to_vector3",
		"origin": "\"minor_axis_a_origin_id\": minor_axis_a_origin_id",
		"max_lines": 2,
	},
	{
		"id": "equipped_grip_shell_minor_axis_b_result_origin",
		"path": "res://runtime/player/player_equipped_item_presenter.gd",
		"local": "\"minor_axis_b_local\": _axis_index_to_vector3",
		"origin": "\"minor_axis_b_origin_id\": minor_axis_b_origin_id",
		"max_lines": 2,
	},
	{
		"id": "equipped_grip_shell_dominant_center_read_origin",
		"path": "res://runtime/player/player_equipped_item_presenter.gd",
		"local": "dominant_grip_center_local = _get_origin_tracked_vector3_state(",
		"origin": "\"slice_center_origin_id\",",
		"max_lines": 4,
	},
	{
		"id": "equipped_grip_shell_support_center_read_origin",
		"path": "res://runtime/player/player_equipped_item_presenter.gd",
		"local": "support_grip_center_local = _get_origin_tracked_vector3_state(",
		"origin": "\"slice_center_origin_id\",",
		"max_lines": 4,
	},
	{
		"id": "equipped_mesh_visual_offset_origin",
		"path": "res://runtime/player/player_equipped_item_presenter.gd",
		"local": "var mesh_visual_offset_local: Vector3 =",
		"origin": "var mesh_visual_offset_origin_id: StringName = CombatOriginRecordScript.ORIGIN_WEAPON_ROOT",
		"max_lines": 2,
	},
	{
		"id": "equipped_support_offset_origin",
		"path": "res://runtime/player/player_equipped_item_presenter.gd",
		"local": "var support_local_offset: Vector3 =",
		"origin": "var support_offset_origin_id: StringName = CombatOriginRecordScript.ORIGIN_WEAPON_ROOT",
		"max_lines": 2,
	},
	{
		"id": "equipped_support_grip_contact_offset_origin",
		"path": "res://runtime/player/player_equipped_item_presenter.gd",
		"local": "support_grip_contact_local = support_local_offset",
		"origin": "support_grip_contact_origin_id = support_offset_origin_id",
		"max_lines": 2,
	},
	{
		"id": "equipped_contact_position_state_origin",
		"path": "res://runtime/player/player_equipped_item_presenter.gd",
		"local": "\"contact_position_local\": contact_position_local",
		"origin": "\"contact_position_origin_id\": contact_position_origin_id",
		"max_lines": 2,
	},
	{
		"id": "equipped_grip_shell_component_center_origin",
		"path": "res://runtime/player/player_equipped_item_presenter.gd",
		"local": "\"center_local\": component_center_local",
		"origin": "\"center_origin_id\": component_center_origin_id",
		"max_lines": 2,
	},
	{
		"id": "equipped_grip_shell_slice_center_meta_origin",
		"path": "res://runtime/player/player_equipped_item_presenter.gd",
		"local": "\"grip_shell_slice_center_local\",",
		"origin": "\"grip_shell_slice_center_origin_id\",",
		"max_lines": 3,
	},
	{
		"id": "equipped_grip_shell_major_axis_meta_origin",
		"path": "res://runtime/player/player_equipped_item_presenter.gd",
		"local": "\"grip_shell_major_axis_local\",",
		"origin": "\"grip_shell_major_axis_origin_id\",",
		"max_lines": 3,
	},
	{
		"id": "equipped_grip_shell_minor_axis_a_meta_origin",
		"path": "res://runtime/player/player_equipped_item_presenter.gd",
		"local": "\"grip_shell_minor_axis_a_local\",",
		"origin": "\"grip_shell_minor_axis_a_origin_id\",",
		"max_lines": 3,
	},
	{
		"id": "equipped_grip_shell_minor_axis_b_meta_origin",
		"path": "res://runtime/player/player_equipped_item_presenter.gd",
		"local": "\"grip_shell_minor_axis_b_local\",",
		"origin": "\"grip_shell_minor_axis_b_origin_id\",",
		"max_lines": 3,
	},
	{
		"id": "equipped_grip_shell_major_axis_area_read_origin",
		"path": "res://runtime/player/player_equipped_item_presenter.gd",
		"local": "var major_axis_index: int = _resolve_axis_index(_get_origin_tracked_vector3_state(",
		"origin": "\"major_axis_origin_id\",",
		"max_lines": 5,
	},
	{
		"id": "equipped_grip_shell_minor_axis_a_area_read_origin",
		"path": "res://runtime/player/player_equipped_item_presenter.gd",
		"local": "var minor_axis_a_local: Vector3 = _get_origin_tracked_vector3_state(",
		"origin": "\"minor_axis_a_origin_id\",",
		"max_lines": 5,
	},
	{
		"id": "equipped_grip_shell_minor_axis_b_area_read_origin",
		"path": "res://runtime/player/player_equipped_item_presenter.gd",
		"local": "var minor_axis_b_local: Vector3 = _get_origin_tracked_vector3_state(",
		"origin": "\"minor_axis_b_origin_id\",",
		"max_lines": 5,
	},
	{
		"id": "equipped_body_proxy_slice_center_read_origin",
		"path": "res://runtime/player/player_equipped_item_presenter.gd",
		"local": "var slice_center_local: Vector3 = _get_origin_tracked_vector3_state(",
		"origin": "\"slice_center_origin_id\",",
		"max_lines": 4,
	},
	{
		"id": "equipped_body_proxy_major_axis_read_origin",
		"path": "res://runtime/player/player_equipped_item_presenter.gd",
		"local": "var major_axis_local: Vector3 = _get_origin_tracked_vector3_state(",
		"origin": "\"major_axis_origin_id\",",
		"max_lines": 5,
	},
	{
		"id": "equipped_bounds_center_read_origin",
		"path": "res://runtime/player/player_equipped_item_presenter.gd",
		"local": "var bounds_center_local: Vector3 = _get_origin_tracked_vector3_state(",
		"origin": "\"center_origin_id\",",
		"max_lines": 5,
	},
	{
		"id": "equipped_bounds_center_meta_origin",
		"path": "res://runtime/player/player_equipped_item_presenter.gd",
		"local": "\"weapon_bounds_center_local\",",
		"origin": "\"weapon_bounds_center_origin_id\",",
		"max_lines": 3,
	},
	{
		"id": "equipped_proxy_grip_center_state_origin",
		"path": "res://runtime/player/player_equipped_item_presenter.gd",
		"local": "\"grip_center_local\": grip_center_local",
		"origin": "\"grip_center_origin_id\": grip_center_origin_id",
		"max_lines": 2,
	},
	{
		"id": "equipped_proxy_sample_meta_origin",
		"path": "res://runtime/player/player_equipped_item_presenter.gd",
		"local": "\"weapon_proxy_sample_local\",",
		"origin": "\"weapon_proxy_sample_origin_id\",",
		"max_lines": 3,
	},
	{
		"id": "equipped_grip_shell_guide_center_offset_origin",
		"path": "res://runtime/player/player_equipped_item_presenter.gd",
		"local": "\"guide_center_offset_local\": guide_center_offset_local",
		"origin": "\"guide_center_offset_origin_id\": guide_center_offset_origin_id",
		"max_lines": 2,
	},
	{
		"id": "equipped_proxy_surface_position_origin",
		"path": "res://runtime/player/player_equipped_item_presenter.gd",
		"local": "var proxy_surface_position_local: Vector3 =",
		"origin": "var proxy_surface_position_origin_id: StringName = resolved_grip_center_origin_id",
		"max_lines": 2,
	},
	{
		"id": "equipped_proxy_surface_expand_origin_param",
		"path": "res://runtime/player/player_equipped_item_presenter.gd",
		"local": "position_meters_local: Vector3,",
		"origin": "position_meters_origin_id: StringName = CombatOriginRecordScript.ORIGIN_WEAPON_ROOT",
		"max_lines": 3,
	},
	{
		"id": "equipped_display_cell_bounds_min_origin",
		"path": "res://runtime/player/player_equipped_item_presenter.gd",
		"local": "var min_local := Vector3(INF, INF, INF)",
		"origin": "var min_origin_id: StringName = cell_origin_id",
		"max_lines": 5,
	},
	{
		"id": "equipped_display_cell_bounds_max_origin",
		"path": "res://runtime/player/player_equipped_item_presenter.gd",
		"local": "var max_local := Vector3(-INF, -INF, -INF)",
		"origin": "var max_origin_id: StringName = cell_origin_id",
		"max_lines": 5,
	},
	{
		"id": "equipped_display_cell_face_sample_origin",
		"path": "res://runtime/player/player_equipped_item_presenter.gd",
		"local": "var face_sample_local: Vector3 = _get_origin_tracked_vector3_state(",
		"origin": "\"face_sample_origin_id\",",
		"max_lines": 5,
	},
	{
		"id": "equipped_contact_axis_state_origin",
		"path": "res://runtime/player/player_equipped_item_presenter.gd",
		"local": "var contact_axis_local: Vector3 = _get_origin_tracked_vector3_state(",
		"origin": "\"contact_axis_origin_id\",",
		"max_lines": 5,
	},
	{
		"id": "equipped_hand_index_pinky_axis_origin",
		"path": "res://runtime/player/player_equipped_item_presenter.gd",
		"local": "resolve_hand_index_pinky_axis_local",
		"origin": "resolve_hand_index_pinky_axis_origin_id",
		"max_lines": 4,
	},
	{
		"id": "equipped_guide_local_origin",
		"path": "res://runtime/player/player_equipped_item_presenter.gd",
		"local": "var guide_local_origin: Vector3",
		"origin": "var guide_origin_origin_id: StringName = CombatOriginRecordScript.ORIGIN_WEAPON_ROOT",
		"max_lines": 2,
	},
	{
		"id": "equipped_signed_contact_axis_origin_params",
		"path": "res://runtime/player/player_equipped_item_presenter.gd",
		"local": "primary_grip_contact_local: Vector3,",
		"origin": "primary_grip_contact_origin_id: StringName,",
		"max_lines": 2,
	},
	{
		"id": "equipped_hand_mount_origin_params",
		"path": "res://runtime/player/player_equipped_item_presenter.gd",
		"local": "target_contact_local: Vector3,",
		"origin": "target_contact_origin_id: StringName,",
		"max_lines": 2,
	},
	{
		"id": "equipped_weapon_tip_direction_origin",
		"path": "res://runtime/player/player_equipped_item_presenter.gd",
		"local": "\"tip_direction_local\": local_tip - guide_local_origin",
		"origin": "\"tip_direction_origin_id\": tip_direction_origin_id",
		"max_lines": 2,
	},
	{
		"id": "equipped_weapon_grip_axis_state_origin",
		"path": "res://runtime/player/player_equipped_item_presenter.gd",
		"local": "\"grip_axis_local\": grip_axis_local.normalized()",
		"origin": "\"grip_axis_origin_id\": grip_axis_origin_id",
		"max_lines": 2,
	},
	{
		"id": "equipped_weapon_tip_direction_alignment_origin",
		"path": "res://runtime/player/player_equipped_item_presenter.gd",
		"local": "var tip_direction_alignment_local: Vector3 = _get_origin_tracked_vector3_state(",
		"origin": "\"tip_direction_alignment_origin_id\",",
		"max_lines": 5,
	},
	{
		"id": "equipped_weapon_grip_axis_alignment_origin",
		"path": "res://runtime/player/player_equipped_item_presenter.gd",
		"local": "var grip_axis_alignment_local: Vector3 = _get_origin_tracked_vector3_state(",
		"origin": "\"grip_axis_alignment_origin_id\",",
		"max_lines": 5,
	},
	{
		"id": "equipped_signed_tip_axis_alignment_origin",
		"path": "res://runtime/player/player_equipped_item_presenter.gd",
		"local": "var tip_axis_alignment_local: Vector3 = _get_origin_tracked_vector3_state(",
		"origin": "\"tip_axis_alignment_origin_id\",",
		"max_lines": 5,
	},
	{
		"id": "equipped_legacy_up_reference_axis_origin",
		"path": "res://runtime/player/player_equipped_item_presenter.gd",
		"local": "func _resolve_weapon_local_up_reference(held_item: Node3D, local_axis: Vector3)",
		"origin": "var axis_origin_id: StringName = CombatOriginRecordScript.ORIGIN_WEAPON_ROOT",
		"max_lines": 2,
	},
	{
		"id": "equipped_cached_stow_compare_origin",
		"path": "res://runtime/player/player_equipped_item_presenter.gd",
		"local": "held_item.set_meta(\"cached_stow_compare_tip_origin_id\", local_tip_origin_id)",
		"origin": "held_item.set_meta(\"cached_stow_compare_stow_pommel_origin_id\", stow_pommel_origin_id)",
		"max_lines": 4,
	},
	{
		"id": "equipped_cached_stow_up_reference_origin",
		"path": "res://runtime/player/player_equipped_item_presenter.gd",
		"local": "var local_up_reference: Vector3 = _get_origin_tracked_vector3_state(",
		"origin": "\"up_reference_origin_id\",",
		"max_lines": 5,
	},
	{
		"id": "equipped_cached_stow_segment_origin",
		"path": "res://runtime/player/player_equipped_item_presenter.gd",
		"local": "held_item.set_meta(\"cached_stow_segment_tip_origin_id\", segment_tip_origin_id)",
		"origin": "held_item.set_meta(\"cached_stow_segment_up_reference_origin_id\", segment_up_reference_origin_id)",
		"max_lines": 3,
	},
	{
		"id": "equipped_grip_contact_shape_size_origin",
		"path": "res://runtime/player/player_equipped_item_presenter.gd",
		"local": "var local_shape_size: Vector3 = Vector3.ONE * cell_world_size",
		"origin": "var shape_size_origin_id: StringName = CombatOriginRecordScript.ORIGIN_WEAPON_ROOT",
		"max_lines": 2,
	},
	{
		"id": "equipped_grip_contact_offset_origin",
		"path": "res://runtime/player/player_equipped_item_presenter.gd",
		"local": "var contact_cell_offset_local: Vector3 = (",
		"origin": "var contact_cell_offset_origin_id: StringName = minor_axis_a_offset_origin_id",
		"max_lines": 2,
	},
	{
		"id": "equipped_grip_contact_offset_meta_origin",
		"path": "res://runtime/player/player_equipped_item_presenter.gd",
		"local": "\"grip_contact_offset_local\",",
		"origin": "\"grip_contact_offset_origin_id\",",
		"max_lines": 3,
	},
	{
		"id": "equipped_station_stow_segment_read_origin",
		"path": "res://runtime/player/player_equipped_item_presenter.gd",
		"local": "var stow_tip_local: Vector3 = _get_origin_tracked_vector3_state(",
		"origin": "\"tip_position_origin_id\",",
		"max_lines": 5,
	},
	{
		"id": "equipped_station_stow_up_reference_origin",
		"path": "res://runtime/player/player_equipped_item_presenter.gd",
		"local": "var local_up_reference_state: Dictionary = _resolve_weapon_local_up_reference_state(",
		"origin": "var local_up_reference_origin_id: StringName = _resolve_origin_tracked_state_origin_id(",
		"max_lines": 3,
	},
	{
		"id": "equipped_station_stow_segment_origin",
		"path": "res://runtime/player/player_equipped_item_presenter.gd",
		"local": "held_item.set_meta(\"station_stow_segment_tip_origin_id\", local_tip_origin_id)",
		"origin": "held_item.set_meta(\"station_stow_segment_up_reference_origin_id\", local_up_reference_origin_id)",
		"max_lines": 3,
	},
	{
		"id": "equipped_weapon_up_reference_state_origin",
		"path": "res://runtime/player/player_equipped_item_presenter.gd",
		"local": "\"local_up_reference\": local_up_reference.normalized()",
		"origin": "\"up_reference_origin_id\": CombatOriginRecordScript.ORIGIN_WEAPON_ROOT",
		"max_lines": 2,
	},
	{
		"id": "runtime_endpoint_claim_origin",
		"path": "res://runtime/player/player_runtime_skill_playback_presenter.gd",
		"local": "held_item.set_meta(RUNTIME_ENDPOINT_AUTHORITY_ACTIVE_META, true)",
		"origin": "RUNTIME_ENDPOINT_AUTHORITY_ORIGIN_META,",
		"max_lines": 5,
	},
	{
		"id": "runtime_endpoint_release_origin",
		"path": "res://runtime/player/player_runtime_skill_playback_presenter.gd",
		"local": "held_item.set_meta(RUNTIME_ENDPOINT_AUTHORITY_ACTIVE_META, false)",
		"origin": "RUNTIME_ENDPOINT_AUTHORITY_ORIGIN_META,",
		"max_lines": 6,
	},
	{
		"id": "runtime_endpoint_root_origin",
		"path": "res://runtime/player/player_runtime_skill_playback_presenter.gd",
		"local": "authority_root.name = RUNTIME_ENDPOINT_AUTHORITY_ROOT_NAME",
		"origin": "RUNTIME_ENDPOINT_AUTHORITY_ORIGIN_META,",
		"max_lines": 4,
	},
	{
		"id": "runtime_endpoint_debug_origin",
		"path": "res://runtime/player/player_runtime_skill_playback_presenter.gd",
		"local": "resolved_playback_state[\"runtime_endpoint_authority_active\"]",
		"origin": "resolved_playback_state[\"runtime_endpoint_authority_origin_id\"]",
		"max_lines": 3,
	},
	{
		"id": "preview_dominant_grip_seat_result_origin",
		"path": "res://runtime/combat/combat_animation_station_preview_presenter.gd",
		"local": "\"dominant_resolved_grip_seat_local\": default_primary_local",
		"origin": "\"dominant_resolved_grip_seat_origin_id\": default_primary_origin_id",
		"max_lines": 2,
	},
	{
		"id": "preview_support_grip_seat_result_origin",
		"path": "res://runtime/combat/combat_animation_station_preview_presenter.gd",
		"local": "\"support_resolved_grip_seat_local\": default_support_local",
		"origin": "\"support_resolved_grip_seat_origin_id\": default_support_origin_id",
		"max_lines": 2,
	},
	{
		"id": "preview_slot_resolved_anchor_result_origin",
		"path": "res://runtime/combat/combat_animation_station_preview_presenter.gd",
		"local": "\"resolved_anchor_local_position\": resolved_anchor_local_position",
		"origin": "\"resolved_anchor_position_origin_id\": CombatOriginRecordScript.ORIGIN_WEAPON_ROOT",
		"max_lines": 2,
	},
	{
		"id": "preview_slot_span_projection_anchor_origin",
		"path": "res://runtime/combat/combat_animation_station_preview_presenter.gd",
		"local": "result[\"resolved_anchor_local_position\"] = projected_local",
		"origin": "result[\"resolved_anchor_position_origin_id\"] = CombatOriginRecordScript.ORIGIN_WEAPON_ROOT",
		"max_lines": 5,
	},
	{
		"id": "preview_dominant_resolved_anchor_read_origin",
		"path": "res://runtime/combat/combat_animation_station_preview_presenter.gd",
		"local": "result[\"dominant_resolved_grip_seat_local\"] = _get_origin_tracked_vector3_state(",
		"origin": "\"resolved_anchor_position_origin_id\",",
		"max_lines": 5,
	},
	{
		"id": "preview_support_resolved_anchor_read_origin",
		"path": "res://runtime/combat/combat_animation_station_preview_presenter.gd",
		"local": "result[\"support_resolved_grip_seat_local\"] = _get_origin_tracked_vector3_state(",
		"origin": "\"resolved_anchor_position_origin_id\",",
		"max_lines": 5,
	},
	{
		"id": "preview_dominant_grip_seat_meta_uses_result_origin",
		"path": "res://runtime/combat/combat_animation_station_preview_presenter.gd",
		"local": "\"dominant_resolved_grip_seat_local\",",
		"origin": "\"dominant_resolved_grip_seat_origin_id\",",
		"max_lines": 4,
	},
	{
		"id": "preview_support_grip_seat_meta_uses_result_origin",
		"path": "res://runtime/combat/combat_animation_station_preview_presenter.gd",
		"local": "\"support_resolved_grip_seat_local\",",
		"origin": "\"support_resolved_grip_seat_origin_id\",",
		"max_lines": 4,
	},
	{
		"id": "preview_contact_tether_dominant_slot_origin",
		"path": "res://runtime/combat/combat_animation_station_preview_presenter.gd",
		"local": "\"local_position\": dominant_local",
		"origin": "\"local_position_origin_id\": dominant_origin_id",
		"max_lines": 2,
	},
	{
		"id": "preview_contact_tether_support_slot_origin",
		"path": "res://runtime/combat/combat_animation_station_preview_presenter.gd",
		"local": "\"local_position\": support_local",
		"origin": "\"local_position_origin_id\": support_origin_id",
		"max_lines": 2,
	},
	{
		"id": "preview_contact_tether_fallback_position_origin",
		"path": "res://runtime/combat/combat_animation_station_preview_presenter.gd",
		"local": "var fallback_position_local: Vector3 = Vector3.ZERO",
		"origin": "var fallback_position_origin_id: StringName = local_position_origin_id",
		"max_lines": 2,
	},
	{
		"id": "preview_grip_contact_metric_origins",
		"path": "res://runtime/combat/combat_animation_station_preview_presenter.gd",
		"local": "\"dominant_grip_origin_id\": resolved_dominant_grip_origin_id",
		"origin": "\"support_grip_origin_id\": resolved_support_grip_origin_id",
		"max_lines": 2,
	},
	{
		"id": "preview_support_grip_resolver_origin_params",
		"path": "res://runtime/combat/combat_animation_station_preview_presenter.gd",
		"local": "current_support_grip_local: Vector3",
		"origin": "current_support_grip_origin_id: StringName",
		"max_lines": 6,
	},
	{
		"id": "preview_support_grip_current_fallback_origin",
		"path": "res://runtime/combat/combat_animation_station_preview_presenter.gd",
		"local": "current_support_grip_local,",
		"origin": "current_support_grip_origin_id_fallback",
		"max_lines": 2,
	},
	{
		"id": "preview_support_grip_current_candidate_origin",
		"path": "res://runtime/combat/combat_animation_station_preview_presenter.gd",
		"local": "\"candidate_local\": current_support_grip_local",
		"origin": "\"candidate_origin_id\": current_support_grip_origin_id_fallback",
		"max_lines": 2,
	},
	{
		"id": "preview_support_grip_candidate_origin",
		"path": "res://runtime/combat/combat_animation_station_preview_presenter.gd",
		"local": "\"candidate_local\": projected_local",
		"origin": "\"candidate_origin_id\": projected_origin_id",
		"max_lines": 2,
	},
	{
		"id": "preview_support_grip_candidate_read_origin",
		"path": "res://runtime/combat/combat_animation_station_preview_presenter.gd",
		"local": "var candidate_local: Vector3 = _get_origin_tracked_vector3_state(",
		"origin": "\"candidate_origin_id\",",
		"max_lines": 4,
	},
	{
		"id": "preview_support_grip_best_origin",
		"path": "res://runtime/combat/combat_animation_station_preview_presenter.gd",
		"local": "best_local = candidate_local",
		"origin": "best_origin_id = candidate_origin_id",
		"max_lines": 2,
	},
	{
		"id": "preview_grip_span_vector_origin",
		"path": "res://runtime/combat/combat_animation_station_preview_presenter.gd",
		"local": "var span_vector_local: Vector3 = span_end_local - span_start_local",
		"origin": "var span_vector_origin_id: StringName =",
		"max_lines": 2,
	},
	{
		"id": "preview_tip_pivot_local_origin_params",
		"path": "res://runtime/combat/combat_animation_station_preview_presenter.gd",
		"local": "local_tip: Vector3,",
		"origin": "local_tip_origin_id: StringName",
		"max_lines": 2,
	},
	{
		"id": "weapon_frame_solver_segment_tip_origin_param",
		"path": "res://runtime/combat/combat_animation_weapon_frame_solver.gd",
		"local": "local_tip: Vector3,",
		"origin": "tip_origin_id: StringName",
		"max_lines": 10,
	},
	{
		"id": "weapon_frame_solver_segment_pommel_origin_param",
		"path": "res://runtime/combat/combat_animation_weapon_frame_solver.gd",
		"local": "local_pommel: Vector3,",
		"origin": "pommel_origin_id: StringName",
		"max_lines": 10,
	},
	{
		"id": "weapon_frame_solver_segment_up_reference_origin_param",
		"path": "res://runtime/combat/combat_animation_weapon_frame_solver.gd",
		"local": "local_up_reference: Vector3,",
		"origin": "up_reference_origin_id: StringName",
		"max_lines": 10,
	},
	{
		"id": "weapon_frame_solver_tip_grip_origin_param",
		"path": "res://runtime/combat/combat_animation_weapon_frame_solver.gd",
		"local": "local_grip: Vector3,",
		"origin": "grip_origin_id: StringName",
		"max_lines": 10,
	},
	{
		"id": "preview_weapon_segment_solver_origin_params",
		"path": "res://runtime/combat/combat_animation_station_preview_presenter.gd",
		"local": "local_pommel: Vector3,",
		"origin": "local_pommel_origin_id: StringName",
		"max_lines": 10,
	},
	{
		"id": "preview_weapon_tip_grip_solver_origin_params",
		"path": "res://runtime/combat/combat_animation_station_preview_presenter.gd",
		"local": "local_grip: Vector3,",
		"origin": "local_grip_origin_id: StringName",
		"max_lines": 10,
	},
	{
		"id": "runtime_skill_weapon_frame_solver_call_origin",
		"path": "res://runtime/player/player_runtime_skill_playback_presenter.gd",
		"local": "local_up_reference,",
		"origin": "local_up_reference_origin_id",
		"max_lines": 12,
	},
	{
		"id": "equipped_station_stow_weapon_frame_solver_call_origin",
		"path": "res://runtime/player/player_equipped_item_presenter.gd",
		"local": "local_up_reference,",
		"origin": "local_up_reference_origin_id",
		"max_lines": 12,
	},
	{
		"id": "preview_upperarm_roll_center_state_origin",
		"path": "res://runtime/combat/combat_animation_station_preview_presenter.gd",
		"local": "\"center_local\": trajectory_inverse * center_world",
		"origin": "\"center_origin_id\": CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING",
		"max_lines": 2,
	},
	{
		"id": "preview_upperarm_roll_handle_state_origin",
		"path": "res://runtime/combat/combat_animation_station_preview_presenter.gd",
		"local": "\"handle_local\": trajectory_inverse * handle_world",
		"origin": "\"handle_origin_id\": CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING",
		"max_lines": 2,
	},
	{
		"id": "preview_upperarm_roll_center_read_origin",
		"path": "res://runtime/combat/combat_animation_station_preview_presenter.gd",
		"local": "var center_local: Vector3 = _get_origin_tracked_vector3_state(",
		"origin": "\"center_origin_id\",",
		"max_lines": 4,
	},
	{
		"id": "preview_upperarm_roll_handle_read_origin",
		"path": "res://runtime/combat/combat_animation_station_preview_presenter.gd",
		"local": "var handle_local: Vector3 = _get_origin_tracked_vector3_state(",
		"origin": "\"handle_origin_id\",",
		"max_lines": 4,
	},
	{
		"id": "preview_weapon_tip_meta_helper",
		"path": "res://runtime/combat/combat_animation_station_preview_presenter.gd",
		"local": "\"weapon_tip_local\"",
		"origin": "\"weapon_tip_origin_id\"",
		"max_lines": 2,
	},
	{
		"id": "weapon_grip_provider_major_axis_origin",
		"path": "res://runtime/player/weapon_grip_anchor_provider.gd",
		"local": "var major_axis_local: Vector3 = grip_center.get_meta(\"grip_shell_major_axis_local\"",
		"origin": "var major_axis_origin_id: StringName = StringName(grip_center.get_meta(",
		"max_lines": 12,
	},
	{
		"id": "weapon_grip_provider_minor_axis_a_origin",
		"path": "res://runtime/player/weapon_grip_anchor_provider.gd",
		"local": "var minor_axis_a_local: Vector3 = grip_center.get_meta(\"grip_shell_minor_axis_a_local\"",
		"origin": "var minor_axis_a_origin_id: StringName = StringName(grip_center.get_meta(",
		"max_lines": 12,
	},
	{
		"id": "weapon_grip_provider_minor_axis_b_origin",
		"path": "res://runtime/player/weapon_grip_anchor_provider.gd",
		"local": "var minor_axis_b_local: Vector3 = grip_center.get_meta(\"grip_shell_minor_axis_b_local\"",
		"origin": "var minor_axis_b_origin_id: StringName = StringName(grip_center.get_meta(",
		"max_lines": 12,
	},
	{
		"id": "finger_grip_major_axis_meta_read_origin",
		"path": "res://runtime/player/player_rig_finger_grip_presenter.gd",
		"local": "\"grip_shell_major_axis_local\",",
		"origin": "\"grip_shell_major_axis_origin_id\",",
		"max_lines": 3,
	},
	{
		"id": "finger_grip_minor_axis_a_meta_read_origin",
		"path": "res://runtime/player/player_rig_finger_grip_presenter.gd",
		"local": "\"grip_shell_minor_axis_a_local\",",
		"origin": "\"grip_shell_minor_axis_a_origin_id\",",
		"max_lines": 3,
	},
	{
		"id": "finger_grip_minor_axis_b_meta_read_origin",
		"path": "res://runtime/player/player_rig_finger_grip_presenter.gd",
		"local": "\"grip_shell_minor_axis_b_local\",",
		"origin": "\"grip_shell_minor_axis_b_origin_id\",",
		"max_lines": 3,
	},
	{
		"id": "finger_grip_baseline_tip_offset_origin",
		"path": "res://runtime/player/player_rig_finger_grip_presenter.gd",
		"local": "var local_tip_offset: Vector3 = (slot_cache.get(\"tip_offsets\", {}) as Dictionary).get(",
		"origin": "var tip_offset_origin_id: StringName = StringName(slot_cache.get(",
		"max_lines": 8,
	},
	{
		"id": "finger_grip_baseline_joint_offset_origin",
		"path": "res://runtime/player/player_rig_finger_grip_presenter.gd",
		"local": "var local_joint_offset: Vector3 = ((slot_cache.get(\"joint_offsets\", {}) as Dictionary).get(",
		"origin": "var joint_offset_origin_id: StringName = StringName(slot_cache.get(",
		"max_lines": 8,
	},
	{
		"id": "upper_body_pose_reference_rotation_cache_origin",
		"path": "res://runtime/player/player_rig_upper_body_pose_presenter.gd",
		"local": "\"rotations\": rotation_lookup,",
		"origin": "\"rotation_origin_id\": CombatOriginRecordScript.ORIGIN_SOLVED_REPLAY_REFERENCE",
		"max_lines": 3,
	},
	{
		"id": "upper_body_pose_current_local_rotation_origin",
		"path": "res://runtime/player/player_rig_upper_body_pose_presenter.gd",
		"local": "var current_local_rotation: Quaternion = skeleton.get_bone_pose_rotation",
		"origin": "var current_rotation_origin_id: StringName = CombatOriginRecordScript.ORIGIN_SOLVED_REPLAY_REFERENCE",
		"max_lines": 2,
	},
	{
		"id": "upper_body_pose_current_rotation_fallback_origin",
		"path": "res://runtime/player/player_rig_upper_body_pose_presenter.gd",
		"local": "var fallback_rotation_origin_id: StringName = _normalize_reference_rotation_origin_id(",
		"origin": "current_rotation_origin_id",
		"max_lines": 3,
	},
	{
		"id": "runtime_skill_active_baseline_transform_origin",
		"path": "res://runtime/player/player_runtime_skill_playback_presenter.gd",
		"local": "active_baseline_local_transform = held_item.transform",
		"origin": "active_baseline_transform_origin_id = _normalize_baseline_transform_origin_id(",
		"max_lines": 4,
	},
	{
		"id": "runtime_skill_restore_baseline_transform_origin",
		"path": "res://runtime/player/player_runtime_skill_playback_presenter.gd",
		"local": "held_item.transform = active_baseline_local_transform",
		"origin": "active_baseline_transform_origin_id = _normalize_baseline_transform_origin_id(",
		"max_lines": 2,
	},
	{
		"id": "runtime_skill_clear_baseline_transform_origin",
		"path": "res://runtime/player/player_runtime_skill_playback_presenter.gd",
		"local": "active_baseline_local_transform = Transform3D.IDENTITY",
		"origin": "active_baseline_transform_origin_id = CombatOriginRecordScript.ORIGIN_HAND_GRIP_ALIGNMENT",
		"max_lines": 2,
	},
	{
		"id": "runtime_skill_weapon_tip_meta_helper",
		"path": "res://runtime/player/player_runtime_skill_playback_presenter.gd",
		"local": "\"weapon_tip_local\"",
		"origin": "\"weapon_tip_origin_id\"",
		"max_lines": 2,
	},
	{
		"id": "runtime_skill_preview_primary_seat_meta_helper",
		"path": "res://runtime/player/player_runtime_skill_playback_presenter.gd",
		"local": "\"preview_primary_grip_seat_local\"",
		"origin": "\"preview_primary_grip_seat_origin_id\"",
		"max_lines": 8,
	},
	{
		"id": "runtime_skill_authored_tip_state_origin",
		"path": "res://runtime/player/player_runtime_skill_playback_presenter.gd",
		"local": "var authored_tip_local: Vector3 = _get_origin_tracked_vector3_state(",
		"origin": "var authored_tip_origin_id: StringName = _resolve_origin_id_from_state(",
		"max_lines": 8,
	},
	{
		"id": "runtime_skill_authored_pommel_state_origin",
		"path": "res://runtime/player/player_runtime_skill_playback_presenter.gd",
		"local": "var authored_pommel_local: Vector3 = _get_origin_tracked_vector3_state(",
		"origin": "var authored_pommel_origin_id: StringName = _resolve_origin_id_from_state(",
		"max_lines": 8,
	},
	{
		"id": "runtime_skill_primary_seat_meta_write_origin",
		"path": "res://runtime/player/player_runtime_skill_playback_presenter.gd",
		"local": "held_item.set_meta(\"preview_primary_grip_seat_local\", primary_local)",
		"origin": "held_item.set_meta(\"preview_primary_grip_seat_origin_id\", primary_origin_id)",
		"max_lines": 2,
	},
	{
		"id": "runtime_skill_support_seat_meta_write_origin",
		"path": "res://runtime/player/player_runtime_skill_playback_presenter.gd",
		"local": "held_item.set_meta(\"preview_support_grip_seat_local\", support_local)",
		"origin": "held_item.set_meta(\"preview_support_grip_seat_origin_id\", support_origin_id)",
		"max_lines": 2,
	},
	{
		"id": "clearance_proxy_descriptor_offset_origin",
		"path": "res://runtime/player/clearance_proxy_builder.gd",
		"local": "\"local_offset\": _resolve_bone_local_offset",
		"origin": "\"offset_origin_id\": CombatOriginRecordScript.ORIGIN_BODY_RESTRICTION_ATTACHMENT",
		"max_lines": 2,
	},
	{
		"id": "collision_legality_sample_position_origin",
		"path": "res://runtime/combat/combat_collision_legality_resolver.gd",
		"local": "\"local_position\": held_item.to_local(sample.global_position)",
		"origin": "\"local_position_origin_id\": CombatOriginRecordScript.ORIGIN_WEAPON_ROOT",
		"max_lines": 2,
	},
	{
		"id": "collision_legality_fallback_position_origin",
		"path": "res://runtime/combat/combat_collision_legality_resolver.gd",
		"local": "var fallback_position_local: Vector3 = Vector3.ZERO",
		"origin": "var fallback_position_origin_id: StringName = sample_position_origin_id",
		"max_lines": 2,
	},
	{
		"id": "body_restriction_capsule_offset_read_origin",
		"path": "res://runtime/player/hand_target_constraint_solver.gd",
		"local": "var capsule_offset_origin_id: StringName = _resolve_origin_tracked_state_origin_id(",
		"origin": "\"offset_origin_id\",",
		"max_lines": 3,
	},
	{
		"id": "body_restriction_box_offset_read_origin",
		"path": "res://runtime/player/hand_target_constraint_solver.gd",
		"local": "var box_offset_origin_id: StringName = _resolve_origin_tracked_state_origin_id(",
		"origin": "\"offset_origin_id\",",
		"max_lines": 3,
	},
	{
		"id": "body_restriction_attachment_offset_meta_origin",
		"path": "res://runtime/player/hand_target_constraint_solver.gd",
		"local": "attachment.set_meta(\"restriction_local_offset\", local_offset)",
		"origin": "attachment.set_meta(\"restriction_offset_origin_id\", resolved_offset_origin_id)",
		"max_lines": 2,
	},
	{
		"id": "body_restriction_child_offset_position_origin",
		"path": "res://runtime/player/hand_target_constraint_solver.gd",
		"local": "target_node.position = local_offset",
		"origin": "target_node.set_meta(\"restriction_offset_origin_id\", offset_origin_id)",
		"max_lines": 2,
	},
]

const STRICT_FORBIDDEN_SOURCE_PATTERNS := [
	{
		"id": "preview_direct_weapon_tip_read",
		"path": "res://runtime/combat/combat_animation_station_preview_presenter.gd",
		"pattern": "held_item.get_meta(\"weapon_tip_local\"",
	},
	{
		"id": "preview_direct_weapon_pommel_read",
		"path": "res://runtime/combat/combat_animation_station_preview_presenter.gd",
		"pattern": "held_item.get_meta(\"weapon_pommel_local\"",
	},
	{
		"id": "preview_direct_primary_contact_read",
		"path": "res://runtime/combat/combat_animation_station_preview_presenter.gd",
		"pattern": "held_item.get_meta(\"primary_grip_contact_local\"",
	},
	{
		"id": "preview_direct_primary_span_start_read",
		"path": "res://runtime/combat/combat_animation_station_preview_presenter.gd",
		"pattern": "held_item.get_meta(\"primary_grip_span_start_local\"",
	},
	{
		"id": "preview_direct_primary_span_end_read",
		"path": "res://runtime/combat/combat_animation_station_preview_presenter.gd",
		"pattern": "held_item.get_meta(\"primary_grip_span_end_local\"",
	},
	{
		"id": "preview_direct_primary_span_start_write",
		"path": "res://runtime/combat/combat_animation_station_preview_presenter.gd",
		"pattern": "held_root.set_meta(\"primary_grip_span_start_local\"",
	},
	{
		"id": "preview_direct_primary_span_end_write",
		"path": "res://runtime/combat/combat_animation_station_preview_presenter.gd",
		"pattern": "held_root.set_meta(\"primary_grip_span_end_local\"",
	},
	{
		"id": "preview_direct_dominant_grip_seat_result_read",
		"path": "res://runtime/combat/combat_animation_station_preview_presenter.gd",
		"pattern": ".get(\"dominant_resolved_grip_seat_local\"",
	},
	{
		"id": "preview_direct_support_grip_seat_result_read",
		"path": "res://runtime/combat/combat_animation_station_preview_presenter.gd",
		"pattern": ".get(\"support_resolved_grip_seat_local\"",
	},
	{
		"id": "preview_direct_resolved_anchor_position_read",
		"path": "res://runtime/combat/combat_animation_station_preview_presenter.gd",
		"pattern": ".get(\"resolved_anchor_local_position\"",
	},
	{
		"id": "preview_constrained_local_dictionary_name",
		"path": "res://runtime/combat/combat_animation_station_preview_presenter.gd",
		"pattern": "constrained_local",
	},
	{
		"id": "preview_unarmed_proxy_local_points_dictionary_name",
		"path": "res://runtime/combat/combat_animation_station_preview_presenter.gd",
		"pattern": "local_points",
	},
	{
		"id": "preview_direct_primary_seat_write",
		"path": "res://runtime/combat/combat_animation_station_preview_presenter.gd",
		"pattern": "held_item.set_meta(PREVIEW_PRIMARY_GRIP_SEAT_LOCAL_META",
	},
	{
		"id": "preview_direct_support_seat_write",
		"path": "res://runtime/combat/combat_animation_station_preview_presenter.gd",
		"pattern": "held_item.set_meta(PREVIEW_SUPPORT_GRIP_SEAT_LOCAL_META",
	},
	{
		"id": "equipped_direct_weapon_tip_read",
		"path": "res://runtime/player/player_equipped_item_presenter.gd",
		"pattern": "held_item.get_meta(\"weapon_tip_local\"",
	},
	{
		"id": "equipped_direct_weapon_pommel_read",
		"path": "res://runtime/player/player_equipped_item_presenter.gd",
		"pattern": "held_item.get_meta(\"weapon_pommel_local\"",
	},
	{
		"id": "equipped_direct_primary_contact_read",
		"path": "res://runtime/player/player_equipped_item_presenter.gd",
		"pattern": "held_item.get_meta(\"primary_grip_contact_local\"",
	},
	{
		"id": "equipped_direct_grip_layout_dominant_hand_read",
		"path": "res://runtime/player/player_equipped_item_presenter.gd",
		"pattern": "grip_hold_layout.get(\"dominant_hand_local_position\"",
	},
	{
		"id": "equipped_direct_grip_layout_support_hand_read",
		"path": "res://runtime/player/player_equipped_item_presenter.gd",
		"pattern": "grip_hold_layout.get(\"support_hand_local_position\"",
	},
	{
		"id": "equipped_direct_grip_shell_slice_center_read",
		"path": "res://runtime/player/player_equipped_item_presenter.gd",
		"pattern": ".get(\"slice_center_local\"",
	},
	{
		"id": "equipped_direct_grip_shell_slice_center_meta_write",
		"path": "res://runtime/player/player_equipped_item_presenter.gd",
		"pattern": "grip_center.set_meta(\"grip_shell_slice_center_local\"",
	},
	{
		"id": "equipped_direct_bounds_center_read",
		"path": "res://runtime/player/player_equipped_item_presenter.gd",
		"pattern": "bounds_data.get(\"center_local\"",
	},
	{
		"id": "equipped_direct_weapon_bounds_center_write",
		"path": "res://runtime/player/player_equipped_item_presenter.gd",
		"pattern": "held_root.set_meta(\"weapon_bounds_center_local\"",
	},
	{
		"id": "equipped_direct_grip_shell_major_axis_read",
		"path": "res://runtime/player/player_equipped_item_presenter.gd",
		"pattern": ".get(\"major_axis_local\", Vector3",
	},
	{
		"id": "equipped_direct_grip_shell_minor_axis_a_read",
		"path": "res://runtime/player/player_equipped_item_presenter.gd",
		"pattern": ".get(\"minor_axis_a_local\", Vector3",
	},
	{
		"id": "equipped_direct_grip_shell_minor_axis_b_read",
		"path": "res://runtime/player/player_equipped_item_presenter.gd",
		"pattern": ".get(\"minor_axis_b_local\", Vector3",
	},
	{
		"id": "equipped_direct_grip_shell_major_axis_meta_write",
		"path": "res://runtime/player/player_equipped_item_presenter.gd",
		"pattern": "grip_center.set_meta(\"grip_shell_major_axis_local\"",
	},
	{
		"id": "equipped_direct_grip_shell_minor_axis_a_meta_write",
		"path": "res://runtime/player/player_equipped_item_presenter.gd",
		"pattern": "grip_center.set_meta(\"grip_shell_minor_axis_a_local\"",
	},
	{
		"id": "equipped_direct_grip_shell_minor_axis_b_meta_write",
		"path": "res://runtime/player/player_equipped_item_presenter.gd",
		"pattern": "grip_center.set_meta(\"grip_shell_minor_axis_b_local\"",
	},
	{
		"id": "equipped_direct_grip_shell_major_axis_meta_read",
		"path": "res://runtime/player/player_equipped_item_presenter.gd",
		"pattern": "grip_center.get_meta(\"grip_shell_major_axis_local\"",
	},
	{
		"id": "equipped_direct_grip_shell_minor_axis_meta_read",
		"path": "res://runtime/player/player_equipped_item_presenter.gd",
		"pattern": "grip_center.get_meta(meta_name",
	},
	{
		"id": "finger_grip_direct_grip_shell_major_axis_meta_read",
		"path": "res://runtime/player/player_rig_finger_grip_presenter.gd",
		"pattern": "grip_center_node.get_meta(\"grip_shell_major_axis_local\"",
	},
	{
		"id": "finger_grip_direct_grip_shell_minor_axis_a_meta_read",
		"path": "res://runtime/player/player_rig_finger_grip_presenter.gd",
		"pattern": "grip_center_node.get_meta(\"grip_shell_minor_axis_a_local\"",
	},
	{
		"id": "finger_grip_direct_grip_shell_minor_axis_b_meta_read",
		"path": "res://runtime/player/player_rig_finger_grip_presenter.gd",
		"pattern": "grip_center_node.get_meta(\"grip_shell_minor_axis_b_local\"",
	},
	{
		"id": "upper_body_direct_idle_rotation_fallback_read",
		"path": "res://runtime/player/player_rig_upper_body_pose_presenter.gd",
		"pattern": "idle_lookup.get(bone_name, current_local_rotation",
	},
	{
		"id": "upper_body_direct_two_hand_rotation_fallback_read",
		"path": "res://runtime/player/player_rig_upper_body_pose_presenter.gd",
		"pattern": "two_hand_lookup.get(bone_name, idle_rotation",
	},
	{
		"id": "runtime_skill_legacy_baseline_local_transform_valid_name",
		"path": "res://runtime/player/player_runtime_skill_playback_presenter.gd",
		"pattern": "active_baseline_local_transform_valid",
	},
	{
		"id": "equipped_direct_stow_contact_position_value",
		"path": "res://runtime/player/player_equipped_item_presenter.gd",
		"pattern": "var contact_position_local: Vector3 = stow_motion_node.pommel_position_local.lerp(",
	},
	{
		"id": "equipped_direct_stow_segment_tip_read",
		"path": "res://runtime/player/player_equipped_item_presenter.gd",
		"pattern": "stow_segment.get(\"tip_position_local\"",
	},
	{
		"id": "equipped_direct_stow_segment_pommel_read",
		"path": "res://runtime/player/player_equipped_item_presenter.gd",
		"pattern": "stow_segment.get(\"pommel_position_local\"",
	},
	{
		"id": "equipped_anonymous_grip_contact_shape_offset",
		"path": "res://runtime/player/player_equipped_item_presenter.gd",
		"pattern": "collision_shape.position = (",
	},
	{
		"id": "station_ui_direct_motion_seed_tip_apply",
		"path": "res://runtime/combat/combat_animation_station_ui.gd",
		"pattern": "motion_node.tip_position_local = geometry_seed.get(\"tip_position_local\"",
	},
	{
		"id": "station_ui_direct_motion_seed_pommel_apply",
		"path": "res://runtime/combat/combat_animation_station_ui.gd",
		"pattern": "motion_node.pommel_position_local = geometry_seed.get(\"pommel_position_local\"",
	},
	{
		"id": "station_ui_curve_handle_drag_uses_anonymous_local",
		"path": "res://runtime/combat/combat_animation_station_ui.gd",
		"pattern": "= handle_position_local - motion_node.",
	},
	{
		"id": "equipped_direct_hand_alignment_offset_spawn_value",
		"path": "res://runtime/player/player_equipped_item_presenter.gd",
		"pattern": "hand_alignment_offset_local = alignment_variant",
	},
	{
		"id": "equipped_direct_hand_alignment_offset_restyle_value",
		"path": "res://runtime/player/player_equipped_item_presenter.gd",
		"pattern": "target_contact_local = alignment_variant as Vector3",
	},
	{
		"id": "preview_direct_hand_alignment_offset_value",
		"path": "res://runtime/combat/combat_animation_station_preview_presenter.gd",
		"pattern": "var grip_offset_local: Vector3 = offset_variant as Vector3",
	},
	{
		"id": "runtime_skill_direct_weapon_tip_read",
		"path": "res://runtime/player/player_runtime_skill_playback_presenter.gd",
		"pattern": "held_item.get_meta(\"weapon_tip_local\"",
	},
	{
		"id": "runtime_skill_direct_weapon_pommel_read",
		"path": "res://runtime/player/player_runtime_skill_playback_presenter.gd",
		"pattern": "held_item.get_meta(\"weapon_pommel_local\"",
	},
	{
		"id": "runtime_skill_direct_preview_primary_seat_read",
		"path": "res://runtime/player/player_runtime_skill_playback_presenter.gd",
		"pattern": "held_item.get_meta(\"preview_primary_grip_seat_local\"",
	},
	{
		"id": "body_restriction_direct_descriptor_offset_read",
		"path": "res://runtime/player/hand_target_constraint_solver.gd",
		"pattern": "descriptor.get(\"local_offset\", Vector3.ZERO",
	},
]

func _init() -> void:
	call_deferred("_run_verification")

func _run_verification() -> void:
	var lines: PackedStringArray = []
	var motion_node = CombatAnimationMotionNodeScript.new()
	motion_node.normalize()
	var motion_node_ok: bool = (
		motion_node.tip_position_origin_id == CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING
		and motion_node.pommel_position_origin_id == CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING
	)
	lines.append("motion_node_origin_ids_ok=%s" % str(motion_node_ok))

	var retarget_node = CombatAnimationRetargetNodeScript.new()
	retarget_node.normalize()
	var retarget_node_ok: bool = (
		retarget_node.origin_id == CombatOriginRecordScript.ORIGIN_PRIMARY_SHOULDER
		and retarget_node.parent_origin_id == CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING
		and retarget_node.pivot_direction_origin_id == CombatOriginRecordScript.ORIGIN_PRIMARY_SHOULDER
		and retarget_node.weapon_axis_origin_id == CombatOriginRecordScript.ORIGIN_PRIMARY_SHOULDER
	)
	lines.append("retarget_node_origin_ids_ok=%s" % str(retarget_node_ok))

	var chain: Array = [
		_build_motion_node(0, Vector3(0.0, 0.0, -0.3), Vector3(0.0, 0.0, 0.1)),
		_build_motion_node(1, Vector3(0.15, 0.0, -0.3), Vector3(0.15, 0.0, 0.1)),
	]
	var baker = CombatRuntimeClipBakerScript.new()
	var clip = baker.bake_from_motion_node_chain(chain, {"source_draft_id": &"verify_origin_annotations"})
	var clip_ok: bool = (
		clip != null
		and clip.baked_tip_positions_origin_id == CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING
		and clip.baked_pommel_positions_origin_id == CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING
		and clip.baked_contact_grip_axes_origin_id == CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING
		and clip.solved_replay_reference_origin_id == CombatOriginRecordScript.ORIGIN_SOLVED_REPLAY_REFERENCE
		and clip.baked_solved_weapon_reference_origin_id == CombatOriginRecordScript.ORIGIN_SOLVED_REPLAY_REFERENCE
		and clip.baked_solved_anchor_origin_id == CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
	)
	lines.append("runtime_clip_origin_ids_ok=%s" % str(clip_ok))

	var chain_player = CombatAnimationChainPlayerScript.new()
	chain_player.prepare_runtime_clip(clip, 1.0, false)
	chain_player.start()
	var chain_player_ok: bool = (
		chain_player.current_tip_position_origin_id == CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING
		and chain_player.current_pommel_position_origin_id == CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING
		and chain_player.current_contact_grip_axis_origin_id == CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING
	)
	lines.append("chain_player_origin_ids_ok=%s" % str(chain_player_ok))

	var anchor_atom = AnchorAtomScript.new()
	anchor_atom.normalize()
	var anchor_atom_ok: bool = (
		anchor_atom.position_origin_id == CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
		and anchor_atom.axis_origin_id == CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
		and anchor_atom.span_start_position_origin_id == CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
		and anchor_atom.span_end_position_origin_id == CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
	)
	lines.append("anchor_atom_origin_ids_ok=%s" % str(anchor_atom_ok))

	var skill_draft = CombatAnimationDraftScript.create_default_skill_baseline(
		&"verify_skill_origin_draft",
		"Verify Skill Origin Draft",
		&"verify_skill"
	)
	var skill_node_0: CombatAnimationMotionNode = skill_draft.motion_node_chain[0] as CombatAnimationMotionNode if skill_draft != null and skill_draft.motion_node_chain.size() > 0 else null
	var skill_node_1: CombatAnimationMotionNode = skill_draft.motion_node_chain[1] as CombatAnimationMotionNode if skill_draft != null and skill_draft.motion_node_chain.size() > 1 else null
	var skill_draft_ok: bool = (
		skill_node_0 != null
		and skill_node_1 != null
		and skill_node_0.tip_position_origin_id == CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING
		and skill_node_0.pommel_position_origin_id == CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING
		and skill_node_1.tip_position_origin_id == CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING
		and skill_node_1.pommel_position_origin_id == CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING
	)
	lines.append("draft_default_skill_origin_ids_ok=%s" % str(skill_draft_ok))

	var combat_idle_draft = CombatAnimationDraftScript.create_default_idle_baseline(
		&"verify_combat_idle_origin_draft",
		"Verify Combat Idle Origin Draft",
		CombatAnimationDraftScript.IDLE_CONTEXT_COMBAT
	)
	var combat_idle_node: CombatAnimationMotionNode = combat_idle_draft.motion_node_chain[0] as CombatAnimationMotionNode if combat_idle_draft != null and combat_idle_draft.motion_node_chain.size() > 0 else null
	var combat_idle_draft_ok: bool = (
		combat_idle_node != null
		and combat_idle_node.tip_position_origin_id == CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING
		and combat_idle_node.pommel_position_origin_id == CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING
	)
	lines.append("draft_default_combat_idle_origin_ids_ok=%s" % str(combat_idle_draft_ok))

	var noncombat_idle_draft = CombatAnimationDraftScript.create_default_idle_baseline(
		&"verify_noncombat_idle_origin_draft",
		"Verify Noncombat Idle Origin Draft",
		CombatAnimationDraftScript.IDLE_CONTEXT_NONCOMBAT
	)
	var noncombat_idle_node: CombatAnimationMotionNode = noncombat_idle_draft.motion_node_chain[0] as CombatAnimationMotionNode if noncombat_idle_draft != null and noncombat_idle_draft.motion_node_chain.size() > 0 else null
	var noncombat_idle_draft_ok: bool = (
		noncombat_idle_node != null
		and noncombat_idle_node.tip_position_origin_id == CombatOriginRecordScript.ORIGIN_STOW_ANCHOR
		and noncombat_idle_node.pommel_position_origin_id == CombatOriginRecordScript.ORIGIN_STOW_ANCHOR
	)
	lines.append("draft_default_noncombat_idle_origin_ids_ok=%s" % str(noncombat_idle_draft_ok))

	var strict_source_pairs_ok: bool = _run_strict_source_pair_checks(lines)
	var strict_forbidden_patterns_ok: bool = _run_strict_forbidden_source_checks(lines)
	var all_checks_passed: bool = (
		motion_node_ok
		and retarget_node_ok
		and clip_ok
		and chain_player_ok
		and anchor_atom_ok
		and skill_draft_ok
		and combat_idle_draft_ok
		and noncombat_idle_draft_ok
		and strict_source_pairs_ok
		and strict_forbidden_patterns_ok
	)
	lines.append("strict_source_pairs_ok=%s" % str(strict_source_pairs_ok))
	lines.append("strict_forbidden_patterns_ok=%s" % str(strict_forbidden_patterns_ok))
	lines.append("all_checks_passed=%s" % str(all_checks_passed))
	var file: FileAccess = FileAccess.open(RESULT_FILE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()
	for line in lines:
		print(line)
	quit(0 if all_checks_passed else 1)

func _build_motion_node(node_index: int, tip_position: Vector3, pommel_position: Vector3):
	var motion_node = CombatAnimationMotionNodeScript.new()
	motion_node.node_index = node_index
	motion_node.node_id = StringName("verify_origin_node_%02d" % node_index)
	motion_node.tip_position_local = tip_position
	motion_node.pommel_position_local = pommel_position
	motion_node.transition_duration_seconds = 0.1
	motion_node.normalize()
	return motion_node

func _run_strict_source_pair_checks(lines: PackedStringArray) -> bool:
	var all_pairs_ok: bool = true
	for check: Dictionary in STRICT_SOURCE_PAIR_CHECKS:
		var check_id: String = String(check.get("id", "unnamed_check"))
		var source_path: String = String(check.get("path", ""))
		var local_pattern: String = String(check.get("local", ""))
		var origin_pattern: String = String(check.get("origin", ""))
		var max_lines: int = int(check.get("max_lines", 4))
		var pair_ok: bool = _source_file_has_nearby_pair(source_path, local_pattern, origin_pattern, max_lines)
		if not pair_ok:
			all_pairs_ok = false
		lines.append("strict_pair_%s=%s" % [check_id, str(pair_ok)])
	return all_pairs_ok

func _run_strict_forbidden_source_checks(lines: PackedStringArray) -> bool:
	var all_forbidden_ok: bool = true
	for check: Dictionary in STRICT_FORBIDDEN_SOURCE_PATTERNS:
		var check_id: String = String(check.get("id", "unnamed_forbidden_check"))
		var source_path: String = String(check.get("path", ""))
		var pattern: String = String(check.get("pattern", ""))
		var pattern_absent: bool = _source_file_lacks_pattern(source_path, pattern)
		if not pattern_absent:
			all_forbidden_ok = false
		lines.append("strict_forbidden_%s=%s" % [check_id, str(pattern_absent)])
	return all_forbidden_ok

func _source_file_has_nearby_pair(
	source_path: String,
	local_pattern: String,
	origin_pattern: String,
	max_lines: int
) -> bool:
	if source_path.is_empty() or local_pattern.is_empty() or origin_pattern.is_empty():
		return false
	if not FileAccess.file_exists(source_path):
		return false
	var source_text: String = FileAccess.get_file_as_string(source_path)
	if source_text.is_empty():
		return false
	var source_lines: PackedStringArray = source_text.split("\n")
	for line_index: int in range(source_lines.size()):
		var source_line: String = source_lines[line_index]
		if not source_line.contains(local_pattern):
			continue
		var start_index: int = maxi(0, line_index - max_lines)
		var end_index: int = mini(source_lines.size() - 1, line_index + max_lines)
		for nearby_index: int in range(start_index, end_index + 1):
			if source_lines[nearby_index].contains(origin_pattern):
				return true
	return false

func _source_file_lacks_pattern(source_path: String, pattern: String) -> bool:
	if source_path.is_empty() or pattern.is_empty():
		return false
	if not FileAccess.file_exists(source_path):
		return false
	var source_text: String = FileAccess.get_file_as_string(source_path)
	if source_text.is_empty():
		return false
	return not source_text.contains(pattern)
