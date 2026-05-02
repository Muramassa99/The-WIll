# LIVE EXPORTED KNOB REGISTRY

## Purpose
- dedicated knob/search file
- use this when you want `Ctrl+F` terms like `hurtbox`, `pierce`, `reach`, `grip`, `stow`, `bounds`, `AoE`
- this is the live exported-knob index, not the naming-law file

## Current Snapshot
- source: live `@export var` and `@export_range ... var` usage in `.gd` files
- last full registry sweep date: `04-04-2026` (`DD-MM-YYYY`)
- last incremental update date: `14-04-2026` (`DD-MM-YYYY`)
- current exported lines after count refresh: `664`
- current unique exported names after count refresh: `572`
- line numbers in the main full-registry body below still come from the last full sweep unless an incremental update section says otherwise

## Search / Topic Index
- `hurtbox` / `hitbox` = no final live combat volume system yet
  - names: `WeaponBoundsArea`, `WeaponBoundsShape`, `weapon_bounds_size_meters`, `weapon_bounds_padding_cells`
  - refs: `runtime/player/player_equipped_item_presenter.gd`, `runtime/forge/test_print_mesh_builder.gd`
- `collision` = current placeholder collision/bounds scaffold only
  - names: `collision_layer`, `collision_mask`, `monitoring`, `monitorable`, `self_collision_mode`
  - refs: `runtime/player/player_equipped_item_presenter.gd`, `services/forge_service.gd`
- `AoE` / `area_of_effect` = no dedicated live code knob yet
  - refs: none live yet; add here when introduced
- `pierce` = thrust / penetration profile and capability
  - names: `pierce_score`, `cap_pierce`, `_resolve_optional_pierce_reach_bonus`, `get_pierce_tip_hint_score`
  - refs: `core/models/baked_profile.gd`, `core/resolvers/capability_resolver.gd`, `core/resolvers/shape_classifier_resolver.gd`, `core/defs/materials/base/bone.tres`, `core/defs/materials/base/scale.tres`
- `edge` = cutting profile and capability
  - names: `edge_score`, `cap_edge`
  - refs: `core/models/baked_profile.gd`, `core/resolvers/capability_resolver.gd`
- `blunt` = impact profile and capability
  - names: `blunt_score`, `cap_blunt`
  - refs: `core/models/baked_profile.gd`, `core/resolvers/capability_resolver.gd`
- `guard` = guard profile and capability
  - names: `guard_score`, `cap_guard`
  - refs: `core/models/baked_profile.gd`, `core/resolvers/capability_resolver.gd`
- `flex` = flexibility profile/capability and bow limb flex
  - names: `flex_score`, `cap_flex`, `calculate_limb_flex_score`, `upper_limb_flex_score`, `lower_limb_flex_score`
  - refs: `core/models/baked_profile.gd`, `core/resolvers/capability_resolver.gd`, `core/resolvers/bow_limb_validation_resolver.gd`, `core/resolvers/bow_resolver.gd`
- `launch` = launch/projectile-support profile and capability
  - names: `launch_score`, `cap_launch`
  - refs: `core/models/baked_profile.gd`, `core/resolvers/capability_resolver.gd`
- `reach` = legacy grip-to-geometry extent, not final attack distance
  - names: `reach`, `cap_reach`, `_calculate_reach`, `max_model_arm_reach_meters`, `max_model_arm_reach_combat_meters`, `aim_max_range_meters`
  - refs: `core/models/baked_profile.gd`, `core/resolvers/profile_primary_grip_resolver.gd`, `core/resolvers/capability_resolver.gd`, `runtime/player/player_humanoid_rig.gd`, `runtime/player/player_controller.gd`, `runtime/player/player_motion_presenter.gd`
- `builder path` / `craft path` = forge branch selector for melee, ranged physical, shield, or magic
  - names: `forge_builder_path_id`, `builder_path_melee`, `builder_path_ranged_physical`, `builder_path_shield`, `builder_path_magic`
  - refs: `core/models/crafted_item_wip.gd`, `runtime/forge/forge_wip_builder.gd`, `runtime/forge/crafting_bench_ui.gd`, `runtime/forge/forge_bench_start_menu_presenter.gd`
- `builder component` / `component split` = authored sub-part selector inside one forge path
  - names: `forge_builder_component_id`, `builder_component_primary`, `builder_component_bow`, `builder_component_quiver`
  - refs: `core/models/crafted_item_wip.gd`, `core/defs/forge_rules_def.gd`, `runtime/forge/forge_grid_controller.gd`, `runtime/forge/forge_project_workflow.gd`
- `string anchor` / `builder marker` = ranged bow authored string-endpoint markers
  - names: `builder_marker_positions`, `builder_marker_string_anchor_a1` through `builder_marker_string_anchor_f2`, `string_anchor_source`, `string_anchor_pair_id`
  - refs: `core/models/crafted_item_wip.gd`, `runtime/forge/forge_material_catalog_presenter.gd`, `runtime/forge/forge_workspace_edit_action_presenter.gd`, `core/resolvers/bow_resolver.gd`, `core/resolvers/bow_reference_geometry_resolver.gd`
- `bow string` / `string pull` / `draw` = resolved rest/draw preview and pull points for ranged bow authoring
  - names: `string_rest_path`, `string_pull_point_rest`, `string_pull_point_draw_max`, `string_draw_path`, `string_draw_distance_meters`, `string_draw_length_meters`, `string_anchor_span_meters`, `bow_string_draw_distance_meters`, `workspace_generated_string_color`, `workspace_generated_string_draw_color`, `workspace_generated_string_radius_meters`
  - refs: `core/resolvers/bow_resolver.gd`, `core/resolvers/bow_reference_geometry_resolver.gd`, `core/defs/forge_rules_def.gd`, `runtime/forge/forge_workspace_preview.gd`, `core/defs/forge_view_tuning_def.gd`
- `grip` = authored grip mode and baked primary-grip data
  - names: `grip_style_mode`, `primary_grip_*`, `primary_grip_two_hand_*`
  - refs: `core/models/crafted_item_wip.gd`, `core/models/baked_profile.gd`, `core/resolvers/profile_primary_grip_resolver.gd`, `runtime/forge/forge_project_panel_presenter.gd`, `runtime/player/player_equipped_item_presenter.gd`
- `stow` = authored carry/storage presentation mode
  - names: `stow_position_mode`
  - refs: `core/models/crafted_item_wip.gd`, `runtime/forge/forge_project_workflow.gd`, `runtime/forge/forge_project_panel_presenter.gd`, `runtime/player/player_equipped_item_presenter.gd`, `runtime/player/player_rig_model_presenter.gd`
- `bounds` = forge workspace bounds and held-weapon bounds
  - names: `show_grid_bounds`, `workspace_grid_bounds_color`, `WeaponBoundsArea`, `WeaponBoundsShape`
  - refs: `runtime/forge/crafting_bench_ui.gd`, `core/defs/forge_view_tuning_def.gd`, `runtime/forge/forge_workspace_geometry_presenter.gd`, `runtime/player/player_equipped_item_presenter.gd`
- `stage2` / `refinement` / `refinement envelope` = optional shell-refinement layer between Stage 1 crafting and test print
  - names: `stage2_item_state`, `stage2_version`, `refinement_initialized`, `stage2_single_cell_max_inward_ratio`, `stage2_multi_cell_max_inward_ratio`, `stage2_fillet_max_inward_ratio`, `stage2_chamfer_max_inward_ratio`, `stage2_primary_grip_safe_radius_voxels`, `min_surface_depth_voxels`, `max_inward_offset_meters`, `max_fillet_offset_meters`, `max_chamfer_offset_meters`, `zone_mask_id`, `stage2_zone_primary_grip_safe`, `neighbor_patch_ids`, `workspace_stage2_shell_color`, `workspace_stage2_brush_color`, `workspace_stage2_blocked_brush_color`, `workspace_stage2_hover_face_color`, `workspace_stage2_selected_face_color`, `workspace_stage2_default_brush_radius_meters`, `workspace_stage2_brush_step_ratio`, `stage2_surface_face_fillet`, `stage2_surface_face_chamfer`, `stage2_surface_face_restore`, `stage2_surface_edge_fillet`, `stage2_surface_edge_chamfer`, `stage2_surface_edge_restore`, `stage2_surface_feature_edge_fillet`, `stage2_surface_feature_edge_chamfer`, `stage2_surface_feature_edge_restore`, `stage2_surface_feature_region_fillet`, `stage2_surface_feature_region_chamfer`, `stage2_surface_feature_region_restore`, `stage2_surface_feature_band_fillet`, `stage2_surface_feature_band_chamfer`, `stage2_surface_feature_band_restore`, `stage2_surface_feature_cluster_fillet`, `stage2_surface_feature_cluster_chamfer`, `stage2_surface_feature_cluster_restore`, `stage2_surface_feature_bridge_fillet`, `stage2_surface_feature_bridge_chamfer`, `stage2_surface_feature_bridge_restore`, `stage2_surface_feature_contour_fillet`, `stage2_surface_feature_contour_chamfer`, `stage2_surface_feature_contour_restore`, `stage2_surface_feature_loop_fillet`, `stage2_surface_feature_loop_chamfer`, `stage2_surface_feature_loop_restore`, `surface_feature_region`, `surface_feature_band`, `surface_feature_cluster`, `surface_feature_bridge`, `surface_feature_contour`, `surface_feature_loop`
  - refs: `core/models/crafted_item_wip.gd`, `core/models/test_print_instance.gd`, `core/models/stage2_item_state.gd`, `core/models/stage2_patch_state.gd`, `core/models/stage2_shell_quad_state.gd`, `core/defs/forge_rules_def.gd`, `core/defs/forge_view_tuning_def.gd`, `services/forge_stage2_service.gd`, `services/forge_service.gd`, `runtime/forge/forge_stage2_brush_presenter.gd`, `runtime/forge/forge_stage2_selection_presenter.gd`, `runtime/forge/forge_stage2_preview_presenter.gd`
- `combat animation` / `skill crafter` / `idle draft` / `motion node` = weapon-owned runtime combat animation creator branch
  - names: `combat_animation_station_state`, `station_schema_id`, `selected_authoring_mode`, `selected_skill_id`, `selected_idle_context_id`, `idle_drafts`, `skill_drafts`, `draft_id`, `draft_kind`, `context_id`, `owning_skill_id`, `legal_slot_id`, `motion_node_chain`, `selected_motion_node_index`, `continuity_motion_node_index`, `preview_playback_speed_scale`, `preview_loop_enabled`, `skill_name`, `skill_description`, `node_id`, `node_index`, `weapon_orientation_degrees`, `weapon_orientation_authored`, `tip_position_local`, `tip_curve_in_handle`, `tip_curve_out_handle`, `pommel_position_local`, `pommel_curve_in_handle`, `pommel_curve_out_handle`, `weapon_roll_degrees`, `axial_reposition_offset`, `grip_seat_slide_offset`, `transition_duration_seconds`, `body_support_blend`, `two_hand_state`, `primary_hand_slot`
  - refs: `core/models/crafted_item_wip.gd`, `core/models/combat_animation_station_state.gd`, `core/models/combat_animation_draft.gd`, `core/models/combat_animation_motion_node.gd`, `core/models/combat_animation_session_state.gd`, `runtime/combat/combat_animation_station_ui.gd`, `runtime/combat/combat_animation_station_preview_presenter.gd`, `runtime/combat/combat_animation_chain_player.gd`, `runtime/combat/combat_animation_motion_node_editor.gd`, `runtime/combat/combat_animation_weapon_frame_solver.gd`, `core/resolvers/combat_animation_draft_validator.gd`
- `chain playback` / `chain player` = reusable combat animation playback driver
  - names: `CombatAnimationChainPlayer`, `playback_finished`, `node_reached`, `current_tip_position`, `current_pommel_position`, `current_weapon_roll`, `current_axial_reposition`, `current_grip_seat_slide`, `current_body_support_blend`, `current_primary_hand_slot`, `speed_scale`, `loop_enabled`
  - refs: `runtime/combat/combat_animation_chain_player.gd`, `runtime/combat/combat_animation_station_ui.gd`
- `focus cycling` / `current_focus` = tip↔pommel focus toggle in skill crafter UI
  - names: `current_focus`, `FOCUS_TIP`, `FOCUS_POMMEL`
  - refs: `runtime/combat/combat_animation_station_ui.gd`, `runtime/combat/combat_animation_station_preview_presenter.gd`
- `onion skin` = ghost neighbor markers at ±1/±2 motion node positions
  - names: `ONION_SKIN_MESH_NAME`
  - refs: `runtime/combat/combat_animation_station_preview_presenter.gd`
- `legacy point` = DELETED — older combat-animation resource, fully replaced by CombatAnimationMotionNode
  - names: `CombatAnimationPoint` (DELETED)
  - refs: `core/models/combat_animation_point.gd` (DELETED)
- `skill slot` / `skill bar` / `block` / `evade` = canonical combat slot assignment and HUD surface
  - names: `skill_block`, `skill_evade`, `skill_slot_1` through `skill_slot_12`, `slot_assignments`, `source_weapon_wip_id`, `source_skill_draft_id`, `element_positions`, `element_scales`
  - refs: `runtime/system/user_settings_runtime.gd`, `core/models/player_skill_slot_state.gd`, `core/models/skill_slot_assignment.gd`, `core/models/player_hud_layout_state.gd`, `runtime/ui/player_gameplay_hud_overlay.gd`
- `animation effect stub` / `motion threshold fx` = forward-compatible combat-animation-driven material effect stub layer
  - names: `animation_effect_stubs`, `resolved_animation_effect_stubs`, `effect_stub_id`, `trigger_kind`, `effect_kind`, `animation_speed_threshold_ratio`, `particle_scene_path`, `sound_event_id`
  - refs: `core/defs/base_material_def.gd`, `core/defs/material_variant_def.gd`, `core/defs/material_animation_effect_stub.gd`, `core/resolvers/tier_resolver.gd`, `core/resolvers/material_runtime_resolver.gd`
- `rectangle` / `circle` / `oval` / `triangle` / `shape tool` = live structural macro-footprint tool family in the forge bench
  - names: `rectangle_place`, `rectangle_erase`, `circle_place`, `circle_erase`, `oval_place`, `oval_erase`, `triangle_place`, `triangle_erase`, `geometry_shape_rotate_left`, `geometry_shape_rotate_right`, `structural_shape_rotation_quadrant`, `plane_shape_add_preview_alpha`, `plane_shape_remove_preview_color`
  - refs: `runtime/forge/forge_workspace_shape_tool_presenter.gd`, `runtime/forge/crafting_bench_ui.gd`, `runtime/forge/forge_plane_viewport.gd`, `core/defs/forge_view_tuning_def.gd`, `GDD-and Text Resources/Structural Volume Authoring System.md`

## Incremental Updates - 05-04-2026

### Structural Shape Tool Additions
- no new exported knobs were added in this pass
- live search/index terms expanded to cover:
  - `circle_place` / `circle_erase`
  - `oval_place` / `oval_erase`
  - `triangle_place` / `triangle_erase`
  - live shared `structural shape rotation slot` authority via:
    - `geometry_shape_rotate_left`
    - `geometry_shape_rotate_right`
    - `structural_shape_rotation_quadrant`

### Stage 2 Foundation Additions
- `core/models/crafted_item_wip.gd`
  - L31 `stage2_item_state`
- `core/models/test_print_instance.gd`
  - L8 `stage2_item_state`
- `core/defs/forge_rules_def.gd`
  - L58 `stage2_single_cell_max_inward_ratio`
  - L59 `stage2_multi_cell_max_inward_ratio`
  - L60 `stage2_fillet_max_inward_ratio`
  - L61 `stage2_chamfer_max_inward_ratio`
  - L62 `stage2_primary_grip_safe_radius_voxels`
- `core/defs/forge_view_tuning_def.gd`
  - L48 `workspace_stage2_shell_color`
  - L49 `workspace_stage2_brush_color`
  - L50 `workspace_stage2_blocked_brush_color`
  - L51 `workspace_stage2_hover_face_color`
  - L52 `workspace_stage2_selected_face_color`
  - L53 `workspace_stage2_default_brush_radius_meters`
  - L54 `workspace_stage2_brush_step_ratio`
- `core/models/stage2_item_state.gd`
  - L6 `stage2_version`
  - L7 `source_wip_id`
  - L8 `source_stage1_cell_count`
  - L9 `cell_world_size_meters`
  - L10 `baseline_local_aabb_position`
  - L11 `baseline_local_aabb_size`
  - L12 `current_local_aabb_position`
  - L13 `current_local_aabb_size`
  - L14 `patch_states`
  - L15 `refinement_initialized`
  - L16 `dirty`
  - L17 `last_active_tool_id`
- `core/models/stage2_patch_state.gd`
  - L7 `patch_id`
  - L8 `baseline_quad`
  - L9 `current_quad`
  - L10 `min_surface_depth_voxels`
  - L11 `max_inward_offset_ratio`
  - L12 `max_inward_offset_meters`
  - L13 `max_fillet_offset_meters`
  - L14 `max_chamfer_offset_meters`
  - L15 `zone_mask_id`
  - L16 `neighbor_patch_ids`
  - L17 `dirty`
- `core/models/stage2_shell_quad_state.gd`
  - L6 `origin_local`
  - L7 `edge_u_local`
  - L8 `edge_v_local`
  - L9 `normal`
  - L10 `material_variant_id`
  - L11 `width_voxels`
  - L12 `height_voxels`

### Structural Rectangle First Pass Additions
- `core/defs/forge_view_tuning_def.gd`
  - L16 `plane_shape_add_preview_alpha`
  - L17 `plane_shape_remove_preview_color`

## Incremental Updates - 11-04-2026

### Combat Animation Creator Branch Foundation
- scope correction:
  - this is the general runtime combat animation creator branch
  - it is not a two-hand-only weapon fix
  - it sits alongside the forge crafter, disassembly bench, and inventory system as its own branch
- `core/models/crafted_item_wip.gd`
  - L34 `combat_animation_station_state`
- `core/models/combat_animation_point.gd`
  - L8 `point_id`
  - L9 `point_index`
  - L10 `local_target_position`
  - L11 `local_target_rotation_degrees`
  - L12 `curve_in_handle_local`
  - L13 `curve_out_handle_local`
  - L14 `active_plane_origin_local`
  - L15 `active_plane_normal_local`
  - L16 `active_plane_axis_u_local`
  - L17 `active_plane_axis_v_local`
  - L18 `transition_duration_seconds`
  - L19 `body_support_blend`
  - L20 `preferred_grip_style_mode`
  - L21 `two_hand_state`
  - L22 `committed`
- `core/models/combat_animation_draft.gd`
  - L11 `draft_id`
  - L12 `display_name`
  - L13 `draft_kind`
  - L14 `context_id`
  - L15 `owning_skill_id`
  - L16 `legal_slot_id`
  - L17 `preferred_grip_style_mode`
  - L18 `authored_for_two_hand_only`
  - L19 `motion_node_chain`
  - L20 `selected_motion_node_index`
  - L21 `continuity_motion_node_index`
  - L22 `preview_playback_speed_scale`
  - L23 `preview_loop_enabled`
  - L24 `skill_name`
  - L25 `skill_description`
  - L26 `draft_notes`
- `core/models/combat_animation_station_state.gd`
  - L13 `station_version`
  - L14 `station_schema_id`
  - L15 `selected_authoring_mode`
  - L16 `selected_skill_id`
  - L17 `selected_idle_context_id`
  - L18 `uses_stage1_geometry_truth`
  - L19 `uses_stage2_geometry_truth`
  - L20 `auto_save_draft_continuity`
  - L21 `idle_drafts`
  - L22 `skill_drafts`
  - L23 `default_skill_package_initialized`
  - L24 `station_notes`
- `core/defs/material_animation_effect_stub.gd`
  - L10 `effect_stub_id`
  - L11 `trigger_kind`
  - L12 `effect_kind`
  - L13 `animation_speed_threshold_ratio`
  - L14 `particle_scene_path`
  - L15 `sound_event_id`
  - L16 `notes`
- `core/defs/base_material_def.gd`
  - L50 `animation_effect_stubs`
- `core/defs/material_variant_def.gd`
  - L15 `resolved_animation_effect_stubs`
- verification note:
  - `combat_animation_station_foundation_results.txt` is the focused branch-foundation proof file
  - persistence through `user://forge/...` was also rechecked successfully when rerun outside the workspace sandbox

## Exported Knob Registry By File

## core/atoms/anchor_atom.gd
- L4 `anchor_id`
- L5 `anchor_type`
- L6 `local_position`
- L7 `local_axis`
- L8 `span_length`
- L9 `span_start_local_position`
- L10 `span_end_local_position`
- L11 `span_start_index`
- L12 `span_end_index`
- L13 `span_anchor_material_ratio`

## core/atoms/cell_atom.gd
- L4 `grid_position`
- L5 `layer_index`
- L6 `material_variant_id`

## core/atoms/layer_atom.gd
- L4 `layer_index`
- L5 `cells`

## core/atoms/segment_atom.gd
- L4 `segment_id`
- L5 `role`
- L6 `member_cells`
- L7 `material_mix`
- L8 `major_axis`
- L9 `minor_axis_a`
- L10 `minor_axis_b`
- L11 `length_voxels`
- L12 `cross_width_voxels`
- L13 `cross_thickness_voxels`
- L14 `anchor_material_ratio`
- L15 `joint_support_material_ratio`
- L16 `bow_string_material_ratio`
- L17 `start_slice_anchor_valid`
- L18 `end_slice_anchor_valid`
- L19 `profile_state`
- L20 `has_opposing_bevel_pair`
- L21 `edge_span_overlap`
- L22 `joint_type_hint`
- L23 `link_count`
- L24 `hinge_count`
- L25 `is_riser_candidate`
- L26 `is_upper_limb_candidate`
- L27 `is_lower_limb_candidate`
- L28 `is_bow_string_candidate`
- L29 `projectile_pass_candidate`

## core/atoms/stat_line.gd
- L11 `stat_id`
- L12 `value`
- L13 `value_kind`
- L14 `enum_value`

## core/defs/base_material_def.gd
- L4 `base_material_id`
- L5 `display_name`
- L8 `material_family`
- L11 `density_per_cell`
- L12 `hardness`
- L13 `toughness`
- L14 `elasticity`
- L15 `brittleness`
- L16 `edge_retention`
- L17 `thermal_stability`
- L18 `corrosion_resistance`
- L19 `conductivity`
- L22 `processing_output_count`
- L23 `salvage_priority`
- L24 `can_be_processed`
- L25 `can_be_salvaged`
- L26 `can_be_blueprinted`
- L29 `color_group`
- L30 `albedo_color`
- L31 `metallic_grade`
- L32 `gloss_grade`
- L33 `transparency_grade`
- L36 `material_tags`
- L37 `unlock_tags`
- L38 `block_tags`
- L41 `base_stat_lines`
- L44 `capability_bias_lines`
- L45 `skill_family_bias_lines`
- L46 `elemental_affinity_lines`
- L47 `equipment_context_bias_lines`
- L50 `can_be_anchor_material`
- L51 `can_be_beveled_edge`
- L52 `can_be_blunt_surface`
- L53 `can_be_grip_profile`
- L54 `can_be_guard_surface`
- L55 `can_be_plate_surface`
- L57 `can_be_joint_support`
- L58 `can_be_joint_membrane`
- L59 `can_be_axial_spin_joint`
- L60 `can_be_planar_hinge_joint`
- L62 `can_be_bow_limb`
- L63 `can_be_bow_string`
- L64 `can_be_riser_core`
- L65 `can_be_projectile_support`
- L66 `can_be_bow_grip`

## core/defs/equipment_slot_def.gd
- L4 `slot_id`
- L5 `display_name`
- L6 `category_id`
- L7 `section_id`
- L8 `supports_forge_test_loadout`
- L9 `display_order`

## core/defs/equipment_slot_registry_def.gd
- L4 `entries`

## core/defs/forge/forge_authoring_sandbox_def.gd
- L6 `sandbox_id`
- L9 `default_sample_preset_id`
- L10 `sample_grip_preset_id`
- L11 `sample_flex_preset_id`
- L12 `sample_bow_preset_id`
- L13 `sample_presets`
- L16 `inventory_seed_def`
- L17 `inventory_seed_quantity`
- L18 `inventory_seed_bonus_quantity`

## core/defs/forge/forge_inventory_seed_def.gd
- L4 `seed_id`
- L5 `entries`

## core/defs/forge/forge_inventory_seed_entry_def.gd
- L4 `material_id`
- L5 `quantity`

## core/defs/forge/forge_material_catalog_def.gd
- L4 `catalog_id`
- L5 `entries`

## core/defs/forge/forge_material_catalog_entry_def.gd
- L4 `material_id`
- L5 `material_def`

## core/defs/forge/forge_sample_brush_def.gd
- L4 `offset_voxels`
- L5 `size_voxels`
- L6 `material_variant_id`

## core/defs/forge/forge_sample_preset_def.gd
- L6 `preset_id`
- L7 `display_name`
- L8 `forge_intent`
- L9 `equipment_context`
- L10 `footprint_size_voxels`
- L11 `brushes`

## core/defs/forge_rules_def.gd
- L4 `rules_id`
- L7 `grid_size`
- L8 `melee_grid_size`
- L9 `ranged_physical_grid_size`
- L10 `shield_grid_size`
- L11 `magic_grid_size`
- L12 `ranged_physical_quiver_grid_size`
- L17 `material_catalog_def`
- L18 `default_material_tier_def`
- L21 `primary_grip_min_length_voxels`
- L22 `primary_grip_min_thickness_voxels`
- L23 `primary_grip_max_thickness_voxels`
- L24 `primary_grip_min_width_voxels`
- L25 `primary_grip_max_width_voxels`
- L27 `primary_grip_two_hand_min_length_voxels`
- L32 `joint_min_cross_width_voxels`
- L33 `joint_min_cross_thickness_voxels`
- L34 `joint_min_length_voxels`
- L41 `riser_min_compact_cross_span_voxels`
- L37 `riser_max_length_voxels`
- L39 `bow_string_max_cross_span_voxels`
- L40 `bow_string_min_length_voxels`
- L44 `bow_string_required_cross_span_voxels`
- L45 `bow_limb_min_cross_width_voxels`
- L46 `bow_limb_min_cross_thickness_voxels`
- L47 `bow_limb_min_length_voxels`
- L53 `bow_string_draw_distance_meters`
- L54 `bow_limb_flex_length_reference_voxels`
- L55 `bow_riser_adjacent_slice_compactness_threshold`
- L58 `stage2_single_cell_max_inward_ratio`
- L59 `stage2_multi_cell_max_inward_ratio`
- L60 `stage2_fillet_max_inward_ratio`
- L61 `stage2_chamfer_max_inward_ratio`
- L62 `stage2_primary_grip_safe_radius_voxels`
- L63 `stage2_pointer_tool_min_radius_meters`
- L64 `stage2_pointer_tool_max_radius_meters`
- L65 `stage2_pointer_tool_radius_step_meters`
- L66 `stage2_tool_min_amount_ratio`
- L67 `stage2_tool_max_amount_ratio`
- L68 `stage2_tool_amount_ratio_step`

## core/defs/forge_storage_rules_def.gd
- L4 `rules_id`
- L5 `weapon_wip_slot_capacity`
- L6 `armor_wip_slot_capacity`
- L7 `accessory_wip_slot_capacity`
- L8 `blueprint_slot_capacity`

## core/defs/forge_view_tuning_def.gd
- L5 `unknown_material_color`
- L8 `plane_empty_color`
- L9 `plane_grid_color`
- L10 `plane_frame_color`
- L11 `plane_margin_pixels`
- L12 `plane_cell_inset_pixels`
- L13 `plane_zoom_step`
- L14 `plane_zoom_min_scale`
- L15 `plane_zoom_max_scale`
- L18 `workspace_camera_fov_degrees`
- L19 `workspace_camera_near`
- L20 `workspace_camera_far`
- L21 `workspace_default_yaw_degrees`
- L22 `workspace_default_pitch_degrees`
- L23 `workspace_pitch_min_degrees`
- L24 `workspace_pitch_max_degrees`
- L25 `workspace_orbit_mouse_button`
- L26 `workspace_pan_modifier_keycode`
- L27 `workspace_capture_mouse_during_drag`
- L28 `workspace_orbit_sensitivity`
- L29 `workspace_pan_sensitivity`
- L30 `workspace_pan_min_distance`
- L31 `workspace_zoom_step`
- L32 `workspace_zoom_min_distance`
- L33 `workspace_zoom_max_distance`
- L34 `workspace_fit_distance_multiplier`
- L35 `workspace_fit_min_distance`
- L36 `workspace_fit_max_distance`
- L37 `workspace_ray_plane_epsilon`
- L38 `workspace_light_follows_camera`
- L39 `workspace_light_follow_offset_degrees`
- L40 `workspace_light_energy`
- L41 `workspace_light_rotation_degrees`
- L42 `workspace_grid_bounds_color`
- L43 `workspace_active_plane_color`
- L44 `workspace_voxel_inset_factor`
- L45 `workspace_voxel_roughness`
- L46 `workspace_voxel_metallic`
- L47 `workspace_plane_thickness_factor`
- L48 `workspace_stage2_shell_color`
- L49 `workspace_stage2_brush_color`
- L50 `workspace_stage2_blocked_brush_color`
- L51 `workspace_stage2_default_brush_radius_meters`
- L52 `workspace_stage2_brush_step_ratio`
- L53 `workspace_generated_string_color`
- L54 `workspace_generated_string_draw_color`
- L55 `workspace_generated_string_radius_meters`
- L57 `test_print_fallback_color`
- L58 `test_print_material_roughness`
- L59 `test_print_material_metallic`
- L62 `ui_inventory_owned_color`
- L63 `ui_inventory_empty_color`
- L64 `ui_button_active_color`
- L65 `ui_button_inactive_color`
- L66 `ui_tab_active_color`
- L67 `ui_tab_inactive_color`

## core/defs/inventory/body_inventory_seed_def.gd
- L4 `seed_id`
- L5 `entries`

## core/defs/inventory/body_inventory_seed_entry_def.gd
- L4 `item_kind`
- L5 `display_name`
- L6 `raw_drop_id`
- L7 `stack_count`
- L8 `is_disassemblable`

## core/defs/material_variant_def.gd
- L4 `variant_id`
- L5 `base_material_id`
- L6 `tier_id`
- L7 `variant_stats`
- L8 `resolved_density_per_cell`
- L9 `resolved_processing_output_count`
- L10 `resolved_value_score`
- L11 `resolved_capability_bias_lines`
- L12 `resolved_skill_family_bias_lines`
- L13 `resolved_elemental_affinity_lines`
- L14 `resolved_equipment_context_bias_lines`

## core/defs/materials/process_rule_registry_def.gd
- L4 `registry_id`
- L5 `entries`

## core/defs/materials/raw_drop_registry_def.gd
- L4 `registry_id`
- L5 `entries`

## core/defs/materials/tier_registry_def.gd
- L4 `registry_id`
- L5 `entries`

## core/defs/process_rule_def.gd
- L4 `rule_id`
- L5 `input_drop_id`
- L6 `output_material_variant_id`
- L7 `output_count_per_input`

## core/defs/raw_drop_def.gd
- L4 `drop_id`
- L5 `display_name`
- L6 `base_material_id`
- L7 `default_tier_id`
- L8 `quantity_min`
- L9 `quantity_max`

## core/defs/salvage_rules_def.gd
- L4 `rule_id`
- L9 `allow_manual_salvage_selection`

## core/defs/skill_core_rules_def.gd
- L4 `rule_id`
- L5 `skill_cores_are_nonmodifiable_in_skill_station`
- L7 `count_toward_special_recovery_logic`

## core/defs/tier_def.gd
- L4 `tier_id`
- L5 `tier_name`
- L6 `stat_multiplier`
- L7 `weight_multiplier`
- L8 `value_multiplier`
- L9 `drop_quality`
- L10 `tier_color`
- L11 `sort_order`

## core/models/baked_profile.gd
- L4 `profile_id`
- L5 `total_mass`
- L6 `center_of_mass`
- L7 `reach`
- L8 `primary_grip_offset`
- L9 `primary_grip_contact_position`
- L10 `primary_grip_axis_ratio_from_span_start`
- L11 `primary_grip_contact_percent`
- L12 `primary_grip_com_side_position`
- L13 `primary_grip_far_side_position`
- L14 `primary_grip_span_start`
- L15 `primary_grip_span_end`
- L16 `primary_grip_span_length_voxels`
- L17 `primary_grip_slide_axis`
- L18 `primary_grip_center_balance_valid`
- L19 `primary_grip_center_balance_origin`
- L20 `primary_grip_center_balance_offset_percent`
- L21 `primary_grip_two_hand_eligible`
- L22 `primary_grip_two_hand_negative_limit`
- L23 `primary_grip_two_hand_positive_limit`
- L24 `front_heavy_score`
- L25 `balance_score`
- L26 `edge_score`
- L27 `blunt_score`
- L28 `pierce_score`
- L29 `guard_score`
- L30 `flex_score`
- L31 `launch_score`
- L32 `capability_scores`
- L33 `material_variant_mix`
- L34 `resolved_material_stat_lines`
- L35 `resolved_capability_bias_lines`
- L36 `resolved_skill_family_bias_lines`
- L37 `resolved_elemental_affinity_lines`
- L38 `resolved_equipment_context_bias_lines`
- L39 `primary_grip_valid`
- L40 `validation_error`

## core/models/crafted_item_wip.gd
- L23 `wip_id`
- L24 `forge_project_name`
- L26 `creator_id`
- L27 `created_timestamp`
- L28 `forge_builder_path_id`
- L29 `forge_builder_component_id`
- L30 `builder_marker_positions`
- L31 `forge_intent`
- L32 `equipment_context`
- L33 `stow_position_mode`
- L34 `grip_style_mode`
- L35 `layers`
- L36 `latest_baked_profile_snapshot`

## core/models/equipped_slot_instance.gd
- L7 `slot_id`
- L8 `entry_kind`
- L9 `source_item_instance_id`
- L10 `source_wip_id`
- L11 `display_name`
- L12 `is_forge_internal_only`

## core/models/finalized_item_instance.gd
- L4 `finalized_item_id`
- L5 `final_item_name`
- L6 `source_wip_id`
- L7 `finalized_timestamp`

## core/models/forge_material_stack.gd
- L4 `stack_id`
- L5 `material_variant_id`
- L6 `quantity`
- L7 `variant_stats`

## core/models/player_body_inventory_state.gd
- L8 `owned_items`
- L9 `save_file_path`

## core/models/player_equipment_state.gd
- L8 `equipped_slots`
- L9 `save_file_path`

## core/models/player_forge_inventory_state.gd
- L4 `material_stacks`

## core/models/player_forge_wip_library_state.gd
- L7 `saved_wips`
- L8 `selected_wip_id`
- L9 `save_file_path`

## core/models/player_personal_storage_state.gd
- L8 `stored_items`
- L9 `save_file_path`

## core/models/salvage_result.gd
- L4 `selected_item_snapshots`
- L5 `preview_material_stacks`
- L6 `supported_item_ids`
- L7 `unsupported_item_ids`
- L8 `info_lines`
- L9 `blocking_lines`
- L10 `can_extract_blueprint`
- L11 `can_select_skill`
- L12 `requires_irreversible_confirmation`
- L13 `preview_valid`
- L14 `commit_applied`
- L15 `committed_item_ids`
- L16 `failure_reason`

## core/models/stored_item_instance.gd
- L4 `item_instance_id`
- L5 `item_kind`
- L6 `display_name`
- L7 `stack_count`
- L8 `raw_drop_id`
- L9 `finalized_item`
- L10 `is_disassemblable`

## core/models/test_print_instance.gd
- L4 `test_id`
- L5 `source_wip_id`
- L6 `baked_profile`
- L7 `display_cells`

## core/models/user_settings_state.gd
- L17 `save_file_path`
- L18 `window_mode`
- L19 `display_index`
- L20 `resolution`
- L21 `vsync_enabled`
- L22 `max_fps`
- L23 `render_scale_preset`
- L24 `master_volume_linear`
- L25 `master_muted`
- L26 `ui_scale_preset`
- L27 `text_scale_preset`
- L28 `keybindings`

## runtime/disassembly/disassembly_bench_ui.gd
- L14 `compact_width_breakpoint`
- L15 `compact_height_breakpoint`
- L18 `minimum_outer_margin_px`
- L19 `maximum_outer_margin_px`
- L20 `wide_panel_separation`
- L21 `compact_panel_separation`
- L22 `wide_side_panel_min_width`
- L23 `compact_side_panel_min_width`
- L24 `wide_center_panel_min_width`
- L25 `compact_center_panel_min_width`
- L26 `wide_item_list_min_height`
- L27 `compact_item_list_min_height`
- L28 `wide_warning_panel_min_height`
- L29 `compact_warning_panel_min_height`
- L30 `wide_action_button_min_width`
- L31 `compact_action_button_min_width`
- L32 `wide_action_button_min_height`
- L33 `compact_action_button_min_height`
- L34 `wide_footer_button_min_width`
- L35 `compact_footer_button_min_width`

## runtime/forge/crafting_bench_ui.gd
- L51 `compact_width_breakpoint`
- L52 `compact_height_breakpoint`
- L55 `minimum_outer_margin_px`
- L56 `maximum_outer_margin_px`
- L57 `wide_left_panel_min_width`
- L58 `compact_left_panel_min_width`
- L59 `wide_right_panel_min_width`
- L60 `compact_right_panel_min_width`
- L61 `wide_action_button_min_width`
- L62 `compact_action_button_min_width`
- L63 `wide_action_button_min_height`
- L64 `compact_action_button_min_height`
- L65 `wide_project_panel_min_height`
- L66 `compact_project_panel_min_height`
- L67 `wide_project_notes_min_height`
- L68 `compact_project_notes_min_height`
- L69 `wide_project_list_min_height`
- L70 `compact_project_list_min_height`
- L71 `wide_inventory_list_min_height`
- L72 `compact_inventory_list_min_height`
- L73 `wide_description_panel_min_height`
- L74 `compact_description_panel_min_height`
- L75 `wide_stats_panel_min_height`
- L76 `compact_stats_panel_min_height`
- L77 `wide_workspace_stage_min_height`
- L78 `compact_workspace_stage_min_height`
- L79 `wide_workspace_inset_size`
- L80 `compact_workspace_inset_size`
- L81 `wide_workspace_inset_margin_px`
- L82 `compact_workspace_inset_margin_px`
- L83 `wide_plane_main_viewport_min_size`
- L84 `compact_plane_main_viewport_min_size`
- L85 `wide_plane_inset_viewport_min_size`
- L86 `compact_plane_inset_viewport_min_size`
- L87 `wide_free_main_viewport_min_size`
- L88 `compact_free_main_viewport_min_size`
- L89 `wide_free_inset_viewport_min_size`
- L90 `compact_free_inset_viewport_min_size`
- L91 `wide_debug_popup_min_size`
- L92 `compact_debug_popup_min_size`
- L93 `layer_hold_repeat_delay_seconds`
- L94 `layer_hold_repeat_rate_hz`
- L95 `edit_panel_refresh_interval_seconds`
- L96 `wide_panel_separation`
- L97 `compact_panel_separation`
- L166 `forge_view_tuning`

## runtime/forge/forge_grid_controller.gd
- L22 `forge_rules`
- L23 `forge_authoring_sandbox`
- L24 `forge_view_tuning`
- L25 `auto_spawn_test_print_on_ready`
- L26 `test_print_spawn_root_path`

## runtime/forge/forge_plane_viewport.gd
- L17 `grid_size`
- L18 `forge_view_tuning`

## runtime/player/player_controller.gd
- L19 `move_speed`
- L20 `sprint_speed`
- L22 `acceleration`
- L23 `air_control`
- L24 `jump_velocity`
- L25 `turn_speed`
- L26 `mouse_sensitivity`
- L27 `min_pitch_degrees`
- L28 `max_pitch_degrees`
- L29 `aim_max_range_meters`
- L30 `interaction_distance`
- L31 `weapons_drawn`

## runtime/player/player_humanoid_rig.gd
- L22 `right_hand_anchor_position`
- L23 `right_hand_anchor_rotation_degrees`
- L24 `left_hand_anchor_position`
- L25 `left_hand_anchor_rotation_degrees`
- L28 `enable_support_arm_ik`
- L36 `left_shoulder_stow_position`
- L37 `left_shoulder_stow_rotation_degrees`
- L38 `right_shoulder_stow_position`
- L39 `right_shoulder_stow_rotation_degrees`
- L40 `left_side_hip_stow_position`
- L41 `left_side_hip_stow_rotation_degrees`
- L42 `right_side_hip_stow_position`
- L43 `right_side_hip_stow_rotation_degrees`
- L44 `left_lower_back_stow_position`
- L45 `left_lower_back_stow_rotation_degrees`
- L46 `right_lower_back_stow_position`
- L47 `right_lower_back_stow_rotation_degrees`
- L50 `default_animation_name`
- L51 `walk_animation_name`
- L52 `jog_animation_name`
- L53 `sprint_animation_name`
- L54 `jump_animation_name`
- L55 `fall_animation_name`

## runtime/ui/player_crosshair_overlay.gd
- L8 `crosshair_color`
- L9 `outline_color`

## runtime/ui/player_inventory_overlay.gd
- L27 `compact_width_breakpoint`
- L28 `compact_height_breakpoint`
- L31 `minimum_outer_margin_px`
- L32 `maximum_outer_margin_px`
- L33 `compact_page_button_min_width`
- L34 `wide_page_button_min_width`
- L35 `compact_action_button_min_width`
- L36 `wide_action_button_min_width`
- L37 `compact_action_button_min_height`
- L38 `wide_action_button_min_height`
- L39 `compact_item_list_min_height`
- L40 `wide_item_list_min_height`
- L41 `minimum_item_list_min_height`
- L45 `equipment_slot_registry`

## runtime/ui/system_menu_overlay.gd
- L31 `compact_width_breakpoint`
- L32 `compact_height_breakpoint`
- L35 `minimum_outer_margin_px`
- L36 `maximum_outer_margin_px`
- L37 `wide_navigation_panel_min_width`
- L38 `compact_navigation_panel_min_width`
- L39 `wide_navigation_button_min_height`
- L40 `compact_navigation_button_min_height`
- L41 `wide_form_label_min_width`
- L42 `compact_form_label_min_width`
- L43 `wide_footer_button_min_width`
- L44 `compact_footer_button_min_width`
- L45 `wide_close_button_min_width`
- L46 `compact_close_button_min_width`
- L47 `wide_footer_button_min_height`
- L48 `compact_footer_button_min_height`
- L49 `page_scroll_width_padding`

## core/models/combat_animation_motion_node.gd
- L8 `node_id`
- L9 `node_index`
- L12 `weapon_orientation_degrees`
- L13 `weapon_orientation_authored`
- L16 `tip_position_local`
- L17 `tip_curve_in_handle`
- L18 `tip_curve_out_handle`
- L21 `pommel_position_local`
- L22 `pommel_curve_in_handle`
- L23 `pommel_curve_out_handle`
- L26 `weapon_roll_degrees`
- L29 `axial_reposition_offset`
- L30 `grip_seat_slide_offset`
- L33 `transition_duration_seconds`
- L36 `body_support_blend`
- L37 `preferred_grip_style_mode`
- L38 `two_hand_state`
- L39 `primary_hand_slot`
- L41 `draft_notes`

## core/models/combat_animation_draft.gd
- L9 `draft_id`
- L10 `display_name`
- L11 `draft_kind`
- L12 `context_id`
- L13 `owning_skill_id`
- L14 `legal_slot_id`
- L15 `preferred_grip_style_mode`
- L16 `authored_for_two_hand_only`
- L17 `motion_node_chain`
- L18 `selected_motion_node_index`
- L19 `continuity_motion_node_index`
- L20 `preview_playback_speed_scale`
- L21 `preview_loop_enabled`
- L22 `skill_name`
- L23 `skill_description`
- L24 `draft_notes`

## core/models/player_skill_slot_state.gd
- L25 `slot_assignments`
- L26 `save_file_path`

## core/models/skill_slot_assignment.gd
- L4 `slot_id`
- L5 `source_weapon_wip_id`
- L6 `source_skill_draft_id`
- L7 `display_name`

## core/models/player_hud_layout_state.gd
- L7 `element_positions`
- L8 `element_scales`
- L9 `save_file_path`

## runtime/ui/player_gameplay_hud_overlay.gd
- L46 `slot_button_width`
- L47 `slot_button_height`
- L48 `slot_gap_px`
- L49 `group_gap_px`
- L50 `bar_bottom_margin_px`
- L51 `hp_bar_width`
- L52 `hp_bar_height`
- L53 `stamina_bar_width`
- L54 `stamina_bar_height`

## Update Rule
- when a new exported knob appears, add it here or regenerate this file from live code
- keep the search/topic index near the top
- keep `NAMING_LAW.md` for naming meaning, and this file for knob lookup

## Incremental Updates - 11-04-2026
- `runtime/combat/combat_animation_station.gd`, `runtime/combat/combat_animation_station_ui.gd`, `scenes/world/combat_animation_station.tscn`, and `scenes/ui/combat_animation_station_ui.tscn` were added as the first real combat animation station workflow surface
- `core/models/combat_animation_point.gd` now also exposes live Bezier handle offsets:
  - `curve_in_handle_local`
  - `curve_out_handle_local`
- the station now has a first embedded preview layer through:
  - `runtime/combat/combat_animation_station_preview_presenter.gd`
  - `scenes/ui/combat_animation_station_ui.tscn`
- search topics to remember:
  - `combat animation station`
  - `combat animation draft`
  - `curve_in_handle_local`
  - `curve_out_handle_local`
  - `Bezier trajectory`
  - `idle draft authoring`
  - `weapon-owned skill draft`

## Incremental Updates - 13-04-2026

### Registry Count Refresh
- refreshed the snapshot counts directly from live code:
  - `exported_lines=664`
  - `unique_exported_names=572`

### Combat Animation Creator Motion-Node Migration
- live authored combat-animation truth now lives in:
  - `core/models/combat_animation_motion_node.gd`
  - `core/models/combat_animation_draft.gd`
- the active exported field family is now:
  - `motion_node_chain`
  - `selected_motion_node_index`
  - `continuity_motion_node_index`
  - `skill_name`
  - `skill_description`
  - `weapon_orientation_degrees`
  - `weapon_orientation_authored`
  - `tip_position_local`
  - `pommel_position_local`
  - `weapon_roll_degrees`
  - `axial_reposition_offset`
  - `grip_seat_slide_offset`
- legacy wording still exists in compatibility/debug surfaces:
  - `draft_point_count`
  - `selected_point_index`
  - `point_marker_count`
  - `CombatAnimationPoint`

### Combat Animation Session State, Motion Node Editor, and Draft Validator (M4, M6, M9)
- new files added:
  - `core/models/combat_animation_session_state.gd` — editor session state (M4)
  - `runtime/combat/combat_animation_motion_node_editor.gd` — tip, pommel sphere, and weapon-orientation drag interaction (M6)
  - `runtime/combat/combat_animation_weapon_frame_solver.gd` — clean tip/pommel/weapon-orientation transform solver
  - `core/resolvers/combat_animation_draft_validator.gd` — draft validation (M9)
- validator constants:
  - `MIN_SKILL_NODES = 2` — minimum motion nodes for a skill draft
  - `MIN_IDLE_NODES = 1` — minimum motion nodes for an idle draft
  - `DEGENERATE_HANDLE_THRESHOLD = 0.0001` — zero-handle detection epsilon
- visualization colors (hardcoded in combat_animation_station_preview_presenter.gd):
  - pommel constraint sphere: `Color(0.8, 0.55, 0.9, 0.2)`
- session state fields:
  - `FOCUS_TIP`, `FOCUS_POMMEL`, `FOCUS_WEAPON` — focus mode constants
  - `current_weapon_wip_id`, `current_draft_ref`, `current_motion_node_index`, `current_focus`
  - `playback_active`, `onion_skin_enabled`
  - `cycle_focus()`, `is_tip_focused()`, `reset()`
- motion node editor fields:
  - `raycast_tip_on_view_drag_plane()`, `raycast_pommel_on_sphere()`, `constrain_pommel_to_sphere()`
  - `begin_drag()`, `end_drag()`, `is_dragging()`, `get_drag_target()`, `resolve_weapon_orientation_drag()`
- search topics to remember:
  - `session state separation`
  - `weapon frame solver`
  - `sphere constraint`
  - `draft validator`
  - `MIN_SKILL_NODES`
  - `DEGENERATE_HANDLE_THRESHOLD`
  - `grip axis default orientation`

### Canonical Combat Skill Slot / HUD Surface
- live canonical combat slot ids now exist in code:
  - `skill_block`
  - `skill_evade`
  - `skill_slot_1` through `skill_slot_12`
- slot assignment and HUD layout state now live through:
  - `core/models/player_skill_slot_state.gd`
  - `core/models/skill_slot_assignment.gd`
  - `core/models/player_hud_layout_state.gd`
  - `runtime/ui/player_gameplay_hud_overlay.gd`
- note:
  - the HUD shell exists and reads the canonical slot family
  - block/evade dedicated refresh methods are still placeholder code in the current overlay

### Skill Crafter UI Scaling and Layout Internals
- `runtime/combat/combat_animation_station_ui.gd`:
  - `var scale_factor: float` — viewport-proportional multiplier, computed as `minf(viewport_w / 1920.0, viewport_h / 1080.0)`
  - `_spi(px: int) -> int` — scale integer pixel values (fonts, separations) by scale_factor, min 1
  - `_spf(px: float) -> float` — scale float pixel values (content margins) by scale_factor, min 1.0
  - base font constants (unscaled reference): `FONT_TITLE=20`, `FONT_SECTION=13`, `FONT_BODY=12`, `FONT_HINT=11`
  - three-column stretch ratios: sidebar `0.22`, center `1.0`, inspector `0.26` (all `SIZE_EXPAND_FILL`)
  - collapsible section helper: `_build_collapsible_section(parent, title, initially_expanded)` — returns content VBoxContainer
- search topics:
  - `scale_factor`
  - `_spi` / `_spf`
  - `collapsible section`
  - `stretch_ratio`

- `authoring contact tether` = Skill Crafter occupied-hand reach-bound acceptance clamp for authored tip/pommel edits
  - names: `constrain_authored_segment_to_contact_tether`, `authoring_contact_tether_metrics`, `AUTHORING_CONTACT_TETHER_REACH_MARGIN_METERS`, `AUTHORING_CONTACT_TETHER_ITERATIONS`, `AUTHORING_CONTACT_SEAT_LOCK_STRENGTH`
  - modes: `AUTHORING_CONTACT_TETHER_MODE_TRANSLATE`, `AUTHORING_CONTACT_TETHER_MODE_TIP_PIVOT`
  - metrics: `mode`, `pivot_mode`, `pivot_delta_meters`, `dominant_seat_error_before_meters`, `dominant_seat_error_after_meters`, `dominant_seat_lock_delta_meters`
  - law: live drag uses hard occupied-hand seating; the dominant Contact Group should remain seated instead of allowing loose shoulder-bubble wandering
  - refs: `runtime/combat/combat_animation_station_preview_presenter.gd`, `runtime/combat/combat_animation_station_ui.gd`, `tools/verify_combat_animation_station_preview.gd`

- `authoring Contact Group wrist basis` = Skill Crafter preview-only hand-anchor basis alignment before finger IK
  - names: `enable_authoring_contact_wrist_basis`, `authoring_contact_wrist_basis_strength`, `authoring_contact_wrist_twist_limit_degrees`, `set_authoring_contact_anchor_basis`, `clear_authoring_contact_anchor_basis`, `clear_authoring_contact_anchor_bases`
  - law: default `authoring_contact_wrist_twist_limit_degrees = 0.0`; the Contact Group wrist may swing/aim, but should not roll around its own forearm-to-hand axis
  - debug: `right_authoring_contact_basis_active`, `left_authoring_contact_basis_active`
  - refs: `runtime/player/player_humanoid_rig.gd`, `runtime/combat/combat_animation_station_preview_presenter.gd`, `tools/verify_combat_animation_station_preview.gd`

- `finger grip contact ray debug` = runtime/debug metadata trail for Contact Group raycasts against grip shells
  - meta: `finger_grip_contact_ray_debug`
  - limit: `CONTACT_RAY_DEBUG_LIMIT = 96`
  - payload: `slot_id`, `finger_id`, `context`, `from_world`, `to_world`, `collision_mask`, `hit`, `hit_position`, `hit_normal`, `hit_distance_meters`, `collider_name`, `collider_path`, `collider_class`, `collider_layer`, `skipped_reason`
  - fallback contexts: `plane_curl_profile_fallback`, `plane_curl_idle_profile_fallback`
  - fallback law: if plane curl misses, cast to actual occupied grip profile cell centers, not only the abstract grip-shell midpoint
  - preview debug: `dominant_finger_contact_ray_debug`, `support_finger_contact_ray_debug`
  - UI summary: Skill Crafter `CURRENT CONTEXT` dominant/support contact ray lines
  - refs: `runtime/player/player_rig_finger_grip_presenter.gd`, `runtime/combat/combat_animation_station_preview_presenter.gd`, `runtime/combat/combat_animation_station_ui.gd`, `tools/verify_combat_animation_station_preview.gd`
