# Full Repo Audit Fix Ledger

Date: 2026-04-01

Scope: `C:\WORKSPACE\The Will- main folder\the-will-gamefiles`

Project law this audit is measuring against:

- Data can be provisional.
- Core systems, methods, ownership, and pipelines must be built with the end product in mind.
- If a foundation is wrong, stop and correct it instead of stacking patches.
- Do it the correct way the first time.

## Audit Method

This audit included:

- Full `.gd` parser sweep with Godot `--check-only`
- Full `.tscn` and `.tres` recursive load sweep
- Headless startup sanity
- Repo-wide scans for `TODO`, `FIXME`, `HACK`, `placeholder`, `print`, `pass`, and hardcoded workspace paths
- Deep reads on the biggest runtime, forge, resolver, player, and persistence files

Current sweep result:

- All scripts currently parse.
- All scene/resource files currently load.
- The main problems are architectural, methodological, ownership-related, and pipeline-related.

## Resolved So Far

These items have already been moved in the right direction after the audit:

- Canonical crafted-item runtime mesh generation no longer uses the old per-exposed-face shortcut. `runtime/forge/test_print_mesh_builder.gd` now produces a merged hull foundation for usable items.
- Crafted-item geometry authority now has an explicit three-stage path instead of jumping straight from raw cells to render mesh: raw voxel cells -> `CraftedItemCanonicalSolid` -> `CraftedItemCanonicalGeometry` -> mesh/bounds/preview positioning. The forge service now stores both canonical stages on `TestPrintInstance`, the held-item path now builds mesh and bounds from canonical geometry instead of from ad-hoc cell reads, and the forge preview now centers from canonical geometry instead of treating the committed render mesh AABB as the first real processed shape authority.
- The first live Stage 2 refinement path now exists in the real forge/test-print flow. `CraftedItemWIP` and `TestPrintInstance` now carry `stage2_item_state`, `services/forge_stage2_service.gd` now derives per-surface-cell Stage 2 shell patches from Stage 1 canonical geometry using the locked Refinement Envelope ratios, the forge workflow now exposes both `Initialize / Refresh Stage 2` and a real Stage 2 refinement mode, and the forge bench can now preview plus live-edit the Stage 2 shell through the first `Carve / Restore / Fillet / Chamfer` brush layer while `ForgeService.build_test_print_from_wip()` still prefers Stage 2 geometry when present and preserves the Stage 1 fallback path when it is not. The first protected Stage 2 zone rule is also live now: patches around the baked primary grip span resolve to `stage2_zone_primary_grip_safe`, destructive carve/chamfer is blocked there, fillet remains allowed there, and general shell patches remain carveable. The first selection-first feature layer is also live now through `stage2_surface_face_fillet` / `stage2_surface_face_chamfer`, using connected coplanar `surface_face` region selection, a populated `neighbor_patch_ids` graph, hovered/selected face preview fills, and boundary-loop-aware apply targets in Stage 2 mode. The first `surface_edge` path is also now live through `stage2_surface_edge_fillet` / `stage2_surface_edge_chamfer`, using contiguous coplanar patch-boundary edge-run resolution as the first truthful runtime edge target. The first explicit internal `surface_feature_edge` path is also now live through `stage2_surface_feature_edge_fillet` / `stage2_surface_feature_edge_chamfer`, using contiguous coplanar internal shared-edge runs with both patch sides selected as the first truthful runtime internal feature-edge target. The first offset-derived `surface_feature_region`, `surface_feature_band`, `surface_feature_cluster`, `surface_feature_bridge`, `surface_feature_contour`, and `surface_feature_loop` paths are also now live through `stage2_surface_feature_region_*`, `stage2_surface_feature_band_*`, `stage2_surface_feature_cluster_*`, `stage2_surface_feature_bridge_*`, `stage2_surface_feature_contour_*`, and `stage2_surface_feature_loop_*`, using connected coplanar same-offset region resolution, region-plus-boundary-band resolution, higher-continuity cluster closure across connected modified regions/bands on the same topology plane, cross-topology bridge closure across shared topology edges between modified clusters on different topology planes, multi-plane contour resolution as the per-topology-plane transition seam inside a bridged modified family, and adjacent offset-change boundary-loop resolution as the first truthful runtime modified-feature topology targets. CAD-style restore coverage now also exists across the older Stage 2 selection families through `stage2_surface_face_restore`, `stage2_surface_edge_restore`, and `stage2_surface_feature_edge_restore`, while the offset-derived region/band/cluster/bridge/contour/loop families now carry their own restore path through `stage2_surface_feature_region_restore`, `stage2_surface_feature_band_restore`, `stage2_surface_feature_cluster_restore`, `stage2_surface_feature_bridge_restore`, `stage2_surface_feature_contour_restore`, and `stage2_surface_feature_loop_restore`.
- Live forge editing no longer auto-falls back to a sample/debug WIP when no project is active. The production editing path now creates a blank editable WIP, while sample presets remain explicit sample actions.
- Fake no-op player runtime contracts were removed instead of left behind as pretend systems:
  - `request_skill_face_crosshair()`
  - `set_hand_grip_active()`
  - `set_aim_follow_target()`
- Shared persistence boilerplate was reduced by introducing `core/models/persistent_resource_state_io.gd` and routing multiple state resources through it.
- Shared item-stack container behavior was split out of `core/models/player_body_inventory_state.gd` and `core/models/player_personal_storage_state.gd` into `core/models/item_instance_container_support.gd`, so item lookup, stack merge, partial take, generated item-id resolution, and persist-on-mutation rules are no longer duplicated across the two player item-container resources.
- Forge project workflow ownership was split out of `runtime/forge/crafting_bench_ui.gd` into `runtime/forge/forge_project_workflow.gd`, so saved-project/sample-project creation, load, resume, reset, duplicate, delete, naming, and catalog rules are no longer buried directly inside the UI owner.
- Forge material catalog ownership was split out of `runtime/forge/crafting_bench_ui.gd` into `runtime/forge/forge_material_catalog_presenter.gd`, so catalog building, inventory page filtering, selection reconciliation, and material description/stat text generation are no longer mixed directly into the forge bench owner.
- Forge workspace edit-flow ownership was split out of `runtime/forge/crafting_bench_ui.gd` into `runtime/forge/forge_workspace_edit_flow.gd`, so pending edit refresh state, free-view paint state, and free-view drag state are no longer buried directly in the bench owner.
- Forge workspace/status presentation ownership was split out of `runtime/forge/crafting_bench_ui.gd` into `runtime/forge/forge_workspace_presentation.gd`, so workspace viewport refresh orchestration, left-panel status state building, debug/status text building, and shared WIP cell collection/count helpers are no longer buried directly in the bench owner.
- Forge responsive workspace layout ownership was split out of `runtime/forge/crafting_bench_ui.gd` into `runtime/forge/forge_workspace_layout_presenter.gd`, so root panel margins, column sizing, workspace host sync, viewport sizing, inset sizing, and action-button sizing are no longer buried directly in the bench owner.
- Forge workspace interaction ownership was split out of `runtime/forge/crafting_bench_ui.gd` into `runtime/forge/forge_workspace_interaction_presenter.gd`, so material-selection toggle logic, workspace view-mode toggling, plane action routing, free-view input routing, and layer-hold repeat state are no longer buried directly in the bench owner.
- Forge project-action ownership was split out of `runtime/forge/crafting_bench_ui.gd` into `runtime/forge/forge_project_action_presenter.gd`, so save/load/resume/reset/duplicate/delete coordination, project metadata apply, and action-button enable/disable rules are no longer buried directly in the bench owner.
- Forge project-panel refresh ownership was expanded inside `runtime/forge/forge_project_panel_presenter.gd`, so project field enable/disable state, current-project editor text sync, project source text, and project-list population/tooltips are no longer buried directly in the bench owner.
- Forge project-panel view ownership was split out of `runtime/forge/crafting_bench_ui.gd` into `runtime/forge/forge_project_panel_presenter.gd`, so stow/grip option setup, popup hint placement, grip availability refresh, and project-list selection sync are no longer buried directly in the bench owner.
- Forge project-panel event ownership was expanded inside `runtime/forge/forge_project_panel_presenter.gd`, so project metadata commit gating, stow/grip popup-focus hint routing, and project-list click/load routing are no longer buried directly in the bench owner.
- Forge project-action ownership was expanded inside `runtime/forge/forge_project_action_presenter.gd`, so project action-result application, project action-button state application, default forge-project naming, saved/sample project display-name resolution, project-source text resolution, and editable-WIP resolution are no longer buried directly in the bench owner.
- Forge workspace edit-action ownership was split out of `runtime/forge/crafting_bench_ui.gd` into `runtime/forge/forge_workspace_edit_action_presenter.gd`, so voxel mutation, material picking, and inventory swap/refund transaction rules are no longer buried directly in the bench owner.
- Forge bench panel view ownership was split out of `runtime/forge/crafting_bench_ui.gd` into `runtime/forge/forge_bench_panel_presenter.gd`, so inventory-list application, material-panel text application, left-panel widget state application, and debug-status text application are no longer buried directly in the bench owner.
- Forge bench session ownership was split out of `runtime/forge/crafting_bench_ui.gd` into `runtime/forge/forge_bench_session_presenter.gd`, so open/close state, player UI-mode toggling, forge-controller signal hookup, preferred-project restore flow, inventory seed kickoff, and first-refresh session bootstrap are no longer buried directly in the bench owner.
- Forge bench material-state ownership was split out of `runtime/forge/crafting_bench_ui.gd` into `runtime/forge/forge_bench_material_state_presenter.gd`, so default material-lookup cache handling, material-catalog build state, and selected/armed material reconciliation are no longer buried directly in the bench owner.
- Forge bench menu action ownership was expanded inside `runtime/forge/forge_bench_menu_presenter.gd`, so view/geometry/workflow action-id dispatch and menu-driven bounds/slice/tool/plane routing are no longer buried directly in the bench owner.
- Forge bench refresh ownership was split out of `runtime/forge/crafting_bench_ui.gd` into `runtime/forge/forge_bench_refresh_presenter.gd`, so full-bench refresh sequencing, pending-edit panel refresh sequencing, and material-selection refresh application are no longer hand-stitched directly in the bench shell.
- Forge bench refresh ownership was expanded inside `runtime/forge/forge_bench_refresh_presenter.gd`, so project-panel refresh sequencing, hint-hide cleanup, and project action-button state sync are no longer hand-stitched directly in the bench shell.
- Forge bench debug/status lifecycle ownership was split out of `runtime/forge/crafting_bench_ui.gd` into `runtime/forge/forge_bench_debug_presenter.gd`, so debug-popup open flow, active-WIP refresh gating, and active-test-print debug refresh gating are no longer hand-stitched directly in the bench shell.
- Forge project-action ownership was expanded inside `runtime/forge/forge_project_action_presenter.gd`, so project command result-to-layer application is no longer repeated across every forge project command wrapper in the bench shell.
- Forge project metadata commit event wrappers inside `runtime/forge/crafting_bench_ui.gd` were collapsed onto one local helper, so name submit/focus exit, stow selection, grip selection, and notes focus exit no longer duplicate the same presenter commit call block.
- Forge bench shell was regrouped away from the old live left-side control column into top grouped menus and a popup project manager, and save-on-exit / save-before-context-change is now treated as **global crafting law** for all present and future crafting builders, not as a bow-only safeguard.
- That autosave law now lives in the shared forge project workflow / project action presenter path instead of only in the `crafting_bench_ui.gd` shell, so live forge builder transitions inherit the same rule from the project layer.
- Player equipped-item presentation ownership was split out of `runtime/player/player_controller.gd` into `runtime/player/player_equipped_item_presenter.gd`, so hand/stow anchor routing, hold-basis resolution, held-item mesh assembly, bounds attachment, and support-hand guidance wiring are no longer buried directly inside the main movement/controller owner.
- Player equipped-item sync ownership was expanded inside `runtime/player/player_equipped_item_presenter.gd`, so held-item clear/rebuild, saved-WIP visual sync, slot-level anchor selection, and support-guidance refresh are no longer buried directly inside the main movement/controller owner.
- Player runtime persistent-state ownership was split out of `runtime/player/player_controller.gd` into `runtime/player/player_runtime_state_presenter.gd`, so body inventory, personal storage, equipment state, forge inventory, forge WIP library, forge material-lookup cache resolution, and player-side seed flows are no longer buried directly inside the main movement/controller owner.
- Player forge hand-test ownership was split out of `runtime/player/player_controller.gd` into `runtime/player/player_forge_test_presenter.gd`, so saved-WIP preview, grip-layout preview, forge test equip/clear routing, and held-item sync delegation are no longer buried directly inside the main movement/controller owner.
- Player world interaction ownership was split out of `runtime/player/player_controller.gd` into `runtime/player/player_interaction_presenter.gd`, so raycast-first interact routing, nearby interactable fallback search, and interactable-parent resolution are no longer buried directly inside the main movement/controller owner.
- Player UI-surface routing ownership was split out of `runtime/player/player_controller.gd` into `runtime/player/player_ui_surface_presenter.gd`, so system-menu open/toggle flow, inventory overlay open/toggle flow, mouse-mode switching, and crosshair visibility sync are no longer buried directly inside the main movement/controller owner.
- Player motion/input/aim ownership was split out of `runtime/player/player_controller.gd` into `runtime/player/player_motion_presenter.gd`, so runtime input-action setup checks, mouse-look application, movement-direction solve, target move-speed solve, vertical motion, visual facing update, locomotion sync, and minimal aim-context refresh are no longer buried directly inside the main movement/controller owner.
- Player rig structural/model ownership was split out of `runtime/player/player_humanoid_rig.gd` into `runtime/player/player_rig_model_presenter.gd`, so target-height scaling, hand/stow attachment creation, anchor lookup, bone/rest lookup, and model arm-reach derivation are no longer buried directly inside the locomotion/support-IK/grip-math owner.
- Player rig locomotion ownership was split out of `runtime/player/player_humanoid_rig.gd` into `runtime/player/player_rig_locomotion_presenter.gd`, so current-animation tracking, animation availability checks, locomotion-state clip resolution, and animation playback are no longer buried directly inside the support-IK/grip-math owner.
- The stale `tools/verify_player_foot_ik.gd` harness was aligned to the rebuilt player baseline so it no longer probes removed runtime foot-IK properties and instead reports the current intentional absence of runtime foot IK.
- Player rig grip-layout ownership was split out of `runtime/player/player_humanoid_rig.gd` into `runtime/player/player_rig_grip_layout_presenter.gd`, so two-hand span resolution, centered-balance solve, profile-span projection, contact-percent resolution, and combat-reach limit derivation are no longer buried directly inside the support-arm IK owner.
- Player rig support-arm IK ownership was split out of `runtime/player/player_humanoid_rig.gd` into `runtime/player/player_rig_support_arm_ik_presenter.gd`, so arm IK modifier creation, target snapping, runtime target solving, influence refresh, and modifier-state blending are no longer buried directly inside the remaining rig owner.
- Player rig guidance/support-hand state ownership was completed inside `runtime/player/player_rig_guidance_state_presenter.gd`, so per-hand guidance targets and support-hand active state are no longer carried as duplicate dictionaries inside `runtime/player/player_humanoid_rig.gd`.
- Player inventory overlay responsive layout ownership was split out of `runtime/ui/player_inventory_overlay.gd` into `runtime/ui/player_inventory_layout_presenter.gd`, so panel margins, button sizing, and item-list sizing are no longer buried directly in the inventory owner.
- Player inventory overlay text/data formatting ownership was split out of `runtime/ui/player_inventory_overlay.gd` into `runtime/ui/player_inventory_text_presenter.gd`, so equipped-entry labels, stored-item labels, forge-material labels, material display-name resolution, and WIP label/cell counting are no longer buried directly in the inventory owner.
- Player inventory overlay page refresh/detail ownership was split out of `runtime/ui/player_inventory_overlay.gd` into `runtime/ui/player_inventory_page_presenter.gd`, so header text, nav-button state, equipment/body/storage/forge/WIP page population, and detail-panel text generation are no longer buried directly in the inventory owner.
- Player inventory overlay player-action ownership was split out of `runtime/ui/player_inventory_overlay.gd` into `runtime/ui/player_inventory_action_presenter.gd`, so player state access, storage transfers, forge-project selection, WIP test-equip actions, and hand-test clear behavior are no longer buried directly in the inventory owner.
- Player inventory overlay refresh orchestration ownership was split out of `runtime/ui/player_inventory_overlay.gd` into `runtime/ui/player_inventory_refresh_presenter.gd`, so header/nav refresh, per-page refresh sequencing, footer-status defaulting, and refresh-to-layout handoff are no longer hand-stitched directly in the inventory shell.
- Player inventory overlay interaction-shell ownership was split out of `runtime/ui/player_inventory_overlay.gd` into `runtime/ui/player_inventory_interaction_presenter.gd`, so list-selection resolution and button-command result normalization are no longer hand-stitched directly in the inventory shell.
- Player inventory overlay session ownership was split out of `runtime/ui/player_inventory_overlay.gd` into `runtime/ui/player_inventory_session_presenter.gd`, so toggle/open/close state, player UI-mode toggling, and source-label/session bootstrap are no longer buried directly in the inventory owner.
- Player inventory overlay page-navigation ownership was split out of `runtime/ui/player_inventory_overlay.gd` into `runtime/ui/player_inventory_navigation_presenter.gd`, so active-page resolution and tab-index mapping are no longer buried directly in the inventory owner.
- Player inventory overlay surface payload/layout ownership was split out of `runtime/ui/player_inventory_overlay.gd` into `runtime/ui/player_inventory_surface_presenter.gd`, so refresh-payload assembly, layout-config assembly, page-order resolution, button/list grouping, and text/action callable wiring are no longer hand-stitched directly in the inventory shell.
- Player inventory overlay selection ownership was split out of `runtime/ui/player_inventory_overlay.gd` into `runtime/ui/player_inventory_selection_presenter.gd`, so selected equipment/body/storage/WIP ids and selection-result application are no longer carried directly as four overlay fields.
- System menu responsive layout ownership was split out of `runtime/ui/system_menu_overlay.gd` into `runtime/ui/system_menu_layout_presenter.gd`, so panel margins, navigation sizing, footer-button sizing, and page-scroll width reconciliation are no longer buried directly in the overlay owner.
- System menu controls/rebind ownership was split out of `runtime/ui/system_menu_overlay.gd` into `runtime/ui/system_menu_controls_presenter.gd`, so bindings-list building, rebind prompt text, keybinding commit text, and per-category default restore text are no longer buried directly in the overlay owner.
- System menu page/settings presentation ownership was split out of `runtime/ui/system_menu_overlay.gd` into `runtime/ui/system_menu_page_presenter.gd` and `runtime/ui/system_menu_settings_presenter.gd`, so page visibility/title/footer state, reset-button state, static option population, settings-to-UI refresh, and settings-page state mutation helpers are no longer buried directly in the overlay owner.
- System menu session ownership was split out of `runtime/ui/system_menu_overlay.gd` into `runtime/ui/system_menu_session_presenter.gd`, so configure/open/close visibility flow, active-player UI-mode toggling, and shell open-state checks are no longer buried directly in the overlay owner.
- System menu input ownership was split out of `runtime/ui/system_menu_overlay.gd` into `runtime/ui/system_menu_input_presenter.gd`, so overlay shortcut routing, pending-rebind key capture, cancel-rebind handling, and close/open page command resolution are no longer buried directly in the overlay owner.
- System menu state-flow ownership was split out of `runtime/ui/system_menu_overlay.gd` into `runtime/ui/system_menu_state_flow_presenter.gd`, so settings-to-UI refresh orchestration, bindings refresh orchestration, rebind commit flow, apply-and-persist flow, controls-category selection flow, and selected-category default-restore flow are no longer hand-stitched directly in the overlay shell.
- System menu page reset/default flow ownership was expanded inside `runtime/ui/system_menu_state_flow_presenter.gd`, so page-level reset routing is no longer hand-stitched directly in the overlay shell.
- System menu surface payload/layout/page-map ownership was split out of `runtime/ui/system_menu_overlay.gd` into `runtime/ui/system_menu_surface_presenter.gd`, so layout-config assembly, navigation/form label groups, option/control payload assembly, and shared page-id mapping are no longer hand-stitched directly in the overlay shell.
- Forge grid spawned test-print preview ownership was split out of `runtime/forge/forge_grid_controller.gd` into `runtime/forge/forge_test_print_preview_presenter.gd`, so preview mesh-instance creation, preview mesh visibility sync, and preview material construction are no longer buried directly in the grid/editing owner.
- Forge grid runtime material-catalog lookup ownership was split out of `runtime/forge/forge_grid_controller.gd` into `runtime/forge/forge_material_lookup_presenter.gd`, so catalog-entry resolution, material variant creation, directory material discovery, and authored material ordering are no longer buried directly in the grid/editing owner.
- Forge grid WIP-builder ownership was split out of `runtime/forge/forge_grid_controller.gd` into `runtime/forge/forge_wip_builder.gd`, so sample preset WIP construction, blank-project WIP construction, sample-brush voxel expansion, and layer assembly are no longer buried directly in the live grid/editing owner.
- Forge grid WIP cell-state ownership was split out of `runtime/forge/forge_grid_controller.gd` into `runtime/forge/forge_wip_cell_state_presenter.gd`, so active-cell lookup rebuild, voxel set/remove mutation, layer creation, layer sorting, and cell-key construction are no longer buried directly in the live grid/editing owner.
- The live forge controller no longer describes its ready-time preview path as a `sample bake loop`; that surface is now named as an explicit authoring-preview/test-print spawn path (`auto_spawn_test_print_on_ready`, `spawn_test_print_from_active_wip_with_defaults`) so the runtime owner is less misleading about what is sandbox-authoring support versus what is a debug loop.
- Forge authoring-sandbox ownership is now more explicit and less mixed into the live grid controller. `runtime/forge/forge_authoring_sandbox_presenter.gd` now owns active authoring-preset state plus authoring-sandbox preset/inventory metadata reads, while `runtime/forge/forge_grid_controller.gd` delegates through that presenter instead of carrying the preset state directly.
- Forge project/workflow surfaces now describe preset-backed authoring projects as `authoring preset` / `[Preset]` instead of `sample preset` / `[Sample]` in the active project source text and project catalog, so the live forge UI is less misleading about what those preset-backed flows represent.
- Forge workspace interaction ownership was expanded inside `runtime/forge/forge_workspace_interaction_presenter.gd`, so inventory-page selection, active-tool resolution, active-plane state resolution, and stepped-layer resolution are no longer buried directly in the forge bench shell.
- Forge workspace interaction ownership was expanded inside `runtime/forge/forge_workspace_interaction_presenter.gd`, so free-view drag/paint state routing, workspace orbit-button resolution, forge action-input availability checks, and initial/release action gating are no longer buried directly in the forge bench shell.
- Forge workspace plane ownership was split out of `runtime/forge/crafting_bench_ui.gd` into `runtime/forge/forge_workspace_plane_presenter.gd`, so per-plane default layer resolution and per-plane max-layer resolution are no longer buried directly in the forge bench shell.
- Forge authoring sandbox configuration was split out of `core/defs/forge_rules_def.gd` and `core/defs/forge/forge_rules_default.tres` into `core/defs/forge/forge_authoring_sandbox_def.gd` and `core/defs/forge/forge_authoring_sandbox_default.tres`, so sample presets and forge sandbox inventory seeding are no longer mixed into the core forge rules resource.
- Disassembly bench responsive layout ownership was split out of `runtime/disassembly/disassembly_bench_ui.gd` into `runtime/disassembly/disassembly_bench_layout_presenter.gd`, so panel margins, column sizing, warning-panel sizing, item-list sizing, and footer/action-button sizing are no longer buried directly in the bench owner.
- Disassembly bench text/material-display ownership was split out of `runtime/disassembly/disassembly_bench_ui.gd` into `runtime/disassembly/disassembly_bench_text_presenter.gd`, so material lookup refresh, stored-item labels, salvage-output labels, material display-name resolution, and selected-stack counting are no longer buried directly in the bench owner.
- Disassembly bench selection/preview/commit workflow ownership was split out of `runtime/disassembly/disassembly_bench_ui.gd` into `runtime/disassembly/disassembly_bench_workflow_presenter.gd`, so selection pruning, preview refresh, action-button state, irreversible-confirmation gating, disassembly commit, and footer-status messaging are no longer buried directly in the bench owner.
- Forge workspace preview geometry/render ownership was split out of `runtime/forge/forge_workspace_preview.gd` into `runtime/forge/forge_workspace_geometry_presenter.gd`, so voxel multimesh sync, active-plane mesh generation, grid-bounds mesh generation, grid/local coordinate conversion, and material-color resolution are no longer buried directly in the camera/view owner.
- Profile primary-grip ownership was split out of `core/resolvers/profile_resolver.gd` into `core/resolvers/profile_primary_grip_resolver.gd`, so primary-grip anchor choice, grip contact solve, reach/balance/front-heavy math, span projection, and two-hand occupancy metadata are no longer buried directly in the profile material-score resolver.
- Profile capability-score ownership was split out of `core/resolvers/profile_resolver.gd` into `core/resolvers/profile_capability_score_resolver.gd`, so edge/blunt/pierce/guard/flex/launch scoring, segment-mass weighting, and profile material-support ratio logic are no longer buried directly in the profile mass/connectivity/grip owner.
- `AnchorResolver.validate_primary_grip()` now locks primary-grip material legality to the same eligible grip-span rules the live anchor builder already uses, instead of leaving a stale TODO that implied material-backed grip legality was still a future pass.
- `SegmentResolver` now makes its current role scope explicit: it emits first-pass bow-related role hints (`riser`, `bow_string`, `projectile_pass`) and intentionally leaves later limb/non-bow role assignment to follow-on resolvers instead of carrying a hanging `NEEDS_DECISION` comment at the metadata population point.
- `CapabilityResolver` now makes its current first-pass contract explicit instead of carrying live TODOs in the math path: optional pierce reach bonus is intentionally `0.0`, raw reach is clamped directly into `cap_reach`, context bias inputs remain accepted when present, and threshold/display-tier mapping remains intentionally outside the resolver.
- Bow connected-region fallback ownership was split out of `core/resolvers/bow_resolver.gd` into `core/resolvers/bow_connected_region_resolver.gd`, so voxel-axis detection, synthetic riser/limb/string region carving, and synthetic segment reconstruction are no longer buried directly in the main bow validation owner.
- Bow reference geometry ownership was split out of `core/resolvers/bow_resolver.gd` into `core/resolvers/bow_reference_geometry_resolver.gd`, so bow reference-center solve, projectile-pass anchors, bow axes, and segment-center geometry are no longer buried directly in the main bow validation owner.
- Bow limb/string validation ownership was split out of `core/resolvers/bow_resolver.gd` into `core/resolvers/bow_limb_validation_resolver.gd`, so riser selection, limb-pair selection, string validation, limb validation, flex scoring, and bow asymmetry scoring are no longer buried directly in the main bow validation owner.

These changes do not mean the related areas are "finished forever," but they are no longer in the exact broken state described by the original audit snapshot.

## Critical Fixes

### 1. Canonical crafted-item geometry pipeline is wrong for project intent

Files:

- `runtime/forge/test_print_mesh_builder.gd`
- `runtime/player/player_equipped_item_presenter.gd`
- `services/forge_service.gd`
- `runtime/forge/forge_workspace_preview.gd`

Current behavior:

- Crafted items are authored as occupied voxel cells.
- Runtime usable items now pass through:
  - `CraftedItemCanonicalSolid`
  - `CraftedItemCanonicalGeometry`
  - render mesh generation from canonical geometry
- Held-item bounds and forge preview centering now also read that same canonical geometry stage instead of using separate ad-hoc mesh-first logic.
- The current canonical geometry is still a merged rectilinear surface authority, not yet the final processed solid/chamfer-ready/shape-operator-ready stage.

Why this is a problem:

- The repo is in a materially better place than the old shell-first shortcut, but the geometry authority is still not the final end-product substrate the project wants.
- Future chamfering, rounding, and derived combat volume work still need a more explicitly processed solid/shape stage above the current canonical geometry pass.
- Combat look, weight, silhouette, and readability should not be considered "fully trustworthy forever" until that final processed shape stage is locked.

Evidence:

- `services/forge_service.gd` now stores both canonical solid and canonical geometry on `TestPrintInstance`.
- `runtime/forge/test_print_mesh_builder.gd` now resolves runtime usable geometry from canonical geometry rather than treating raw cell reads as the only processed stage.
- `runtime/player/player_equipped_item_presenter.gd` now mounts held-item visuals and placeholder bounds from canonical geometry.
- `runtime/forge/forge_test_print_preview_presenter.gd` now centers preview placement from canonical geometry.
- `tools/verify_crafted_item_mesh_foundation.gd` now confirms:
  - canonical solid valid
  - canonical geometry valid
  - merged box hull output still correct for simple line/box cases

Fix target:

- Keep the current canonical solid -> canonical geometry split.
- Add the later processed solid / shape-operator stage on top of it instead of bypassing it.
- Keep future shape operators and downstream collision generation attached to that canonical item truth stack, not to ad-hoc render-mesh hacks.

### 1.1 Follow-on dependency: shape-derived collision and combat hit volume generation

Files currently involved:

- `runtime/player/player_equipped_item_presenter.gd`
- `runtime/forge/test_print_mesh_builder.gd`

Current behavior:

- Held items currently use a padded axis-aligned box as placeholder bounds.

Why this matters:

- Future combat hitboxes, edge zones, tip zones, guard zones, and custom expanded combat volumes should come from the same canonical item shape as the render mesh.
- This should not be solved by stacking more box approximations.

Fix target:

- After the canonical solid item stage is fully locked, derive collision/hit volumes from that same processed shape with explicit offset rules.
- Treat this as a dependent follow-on to the geometry foundation, not as a separate unrelated system.

### 2. Production forge runtime still owns debug/sample responsibilities

Files:

- `runtime/forge/forge_grid_controller.gd:19`
- `runtime/forge/forge_grid_controller.gd:132`
- `runtime/forge/forge_grid_controller.gd:137`
- `runtime/forge/forge_grid_controller.gd:143`
- `runtime/forge/forge_grid_controller.gd:214-215`
- `runtime/forge/forge_grid_controller.gd:437-462`
- `services/forge_service.gd:74`
- `services/forge_service.gd:165-184`
- `core/defs/forge_rules_def.gd:26-27`
- `core/defs/forge/forge_rules_default.tres:13`
- `core/defs/forge/forge_rules_default.tres:17`

Current behavior:

- The live forge controller still carries debug sample WIP ownership.
- Default material lookup still routes through a debug-named builder.
- The forge service still prints baked profile debug output unconditionally.
- Debug inventory quantities and sample presets still sit directly in the default rules resource.

Why this is a problem:

- Debug and production responsibilities are mixed in the same runtime owner.
- This makes it harder to reason about what is canonical player flow versus temporary author/test flow.
- It also creates log noise and makes the forge controller harder to keep stable.

Fix target:

- Split sample/debug authoring into dedicated tooling or explicit sandbox paths.
- Remove unconditional debug prints from production bake paths.
- Rename or replace debug-named code paths that are now acting as live defaults.

Current status after cleanup:

- The forge side is materially better than the original audit snapshot:
  - ready-time preview flow no longer uses `sample bake loop` naming
  - active authoring-preset state is no longer stored directly on the live grid controller
  - user-facing forge project/workflow text now refers to `authoring preset` rather than `sample preset`
- Remaining work in this bucket is now mostly:
  - removing or relocating any truly unconditional debug-only logging/noise still left in live forge runtime
  - deciding whether the remaining preset-specific controller wrapper names should stay as compatibility shell or be renamed more broadly later

## High Priority Fixes

### 4. Several runtime owners are too large and own too many jobs

Files and current size:

- `runtime/forge/crafting_bench_ui.gd` - 1432 lines
- `runtime/player/player_controller.gd` - 356 lines
- `runtime/player/player_humanoid_rig.gd` - 358 lines
- `runtime/ui/player_inventory_overlay.gd` - 431 lines
- `runtime/ui/system_menu_overlay.gd` - 480 lines
- `runtime/forge/forge_grid_controller.gd` - 316 lines
- `core/resolvers/bow_resolver.gd` - 149 lines
- `core/resolvers/profile_resolver.gd` - 96 lines
- `core/resolvers/profile_capability_score_resolver.gd` - 206 lines
- `runtime/disassembly/disassembly_bench_ui.gd` - 246 lines
- `runtime/forge/forge_workspace_preview.gd` - 149 lines

Why this is a problem:

- These are not just long files. Several of them mix unrelated responsibilities.
- Examples:
  - `player_controller.gd` is much closer to a shell now, but it still owns top-level player lifecycle, physics sequencing, and player-facing delegate API surface.
  - `player_humanoid_rig.gd` is now much closer to a shell owner, but it still coordinates locomotion/support-arm lifecycle and rig-level config payload assembly.
  - `crafting_bench_ui.gd` still mixes bench shell wiring, event routing, project/workspace lifecycle entry, and viewport-specific orchestration.
  - `system_menu_overlay.gd` is still moderately large, but the remaining size is now mostly node references and signal-shell wiring rather than direct ownership of settings/rebind/session/page/layout logic.

Fix target:

- Split owners by responsibility before they grow further.
- Keep the existing naming law and explicit ownership boundaries when decomposing.

### 6. Ranged physical weapon / shield foundation is broader than the current bow-only resolver model

Files:

- `core/resolvers/bow_resolver.gd:15-85`
- `core/resolvers/bow_resolver.gd:140-176`
- `core/resolvers/bow_resolver.gd:178-221`
- `core/resolvers/bow_resolver.gd:223-313`
- future ranged physical crafter split
- future quiver shell/mannequin crafter
- future shield restricted-volume / fixed-handle crafter

Current behavior:

- The bow resolver tries to infer limbs, riser, string, split axes, slice ranges, and synthetic segments when direct authored evidence is missing.
- The current code and older planning still treat this bucket too much like a bow-only resolver problem.
- Newer design intent makes this bucket larger than that:
  - `Ranged Physical Weapon` is the umbrella
  - `bow` and `quiver` are separate crafted components
  - `quiver` depends on a shell/mannequin restriction system
  - `shield` overlaps that mannequin-anchor foundation in parallel
- First live progress now exists:
  - ranged physical has explicit `bow` / `quiver` builder-component identity
  - ranged `bow` now has live authored string-anchor builder markers `A1/A2` through `F1/F2`
  - those markers are non-inventory authoring entries, pinned at the top of the bow builder material list, stored as dedicated WIP marker-position metadata, filtered out of baked/test-print geometry, and preferred by the bow runtime path when a complete pair exists
  - marker erase/pick/render is now marker-aware in both forge views instead of treating markers like normal voxel mass
  - the forge 3D builder preview now also renders:
    - a first-pass generated bow string rest path
    - a first-pass generated max-draw string path
    - a first-pass generated max-draw pull point
  - legacy/sample bow fallback still remains active when no explicit authored pair exists

Why this is a problem:

- The amount of heuristic inference is high.
- This creates hidden assumptions that may be hard to align with final design rules.
- It also risks solving the wrong problem first, because resolver cleanup alone does not lock the real authored foundation for ranged physical and shield work.
- A large heuristic fallback path can become “mystery truth” instead of explicit authored truth.

Fix target:

- Follow `RANGED_PHYSICAL_WEAPON_AND_SHIELD_FOUNDATION_SPEC_2026-04-02.md`.
- Decide what the canonical authored ranged physical structure evidence is across:
  - bow
  - quiver
  - explicit bow string-anchor creator points
  - runtime four-point string mapping / release behavior
  - slot/stow behavior
  - arrow visual anchor
  - shield mannequin-anchor overlap
- Reduce reliance on synthetic reconstruction where possible.
- Lock the ranged physical / shield pipeline to stable intent instead of allowing too much inference.

### 7. Core gameplay resolvers still contain unresolved decision markers

Files:

- `core/resolvers/anchor_resolver.gd:38`
- `core/resolvers/capability_resolver.gd:35-37`
- `core/resolvers/capability_resolver.gd:63`
- `core/resolvers/segment_resolver.gd:31`

Current behavior:

- The current first-pass capability behavior is now explicit, but later expansion rules around richer reach normalization baselines, non-zero optional pierce reach bonus weighting, and any display-tier mapping still remain future decisions.

Why this is a problem:

- These are not side notes in tooling.
- They are unresolved design decisions sitting inside core gameplay logic.

Fix target:

- Convert these from open comments to concrete locked rule decisions.
- Keep the decision record in documentation and make the resolver behavior explicit.

## Medium Priority Fixes

### 8. Tooling and verification output paths are heavily hardcoded to workspace-local paths

Files:

- `tools/audit_load_resources.gd:3`
- `tools/diagnose_extensive_testing_1_geometry.gd:9`
- `tools/diagnose_left_grip_correction_axis.gd:8-9`
- `tools/diagnose_player_idle_legs.gd:4`
- `tools/verify_crafting_bench_grip_ui.gd:5`
- `tools/verify_grip_occupancy_metadata.gd:5`
- `tools/verify_player_grip_hold_layout.gd:6-7`
- `tools/verify_player_hand_mount_orientation.gd:8-9`
- `tools/verify_player_held_item_materials.gd:8-9`
- Many other files in `tools/`

Current behavior:

- Internal tools write directly to `C:/WORKSPACE/...` or `c:/WORKSPACE/...`.

Why this is a problem:

- This is acceptable for internal-only tooling in the short term.
- It is not portable, and it makes audit/test output sprawl directly into the workspace root.

Fix target:

- Move tool outputs under a dedicated project-local or `user://` audit/test-results structure.
- Keep tooling isolated from source and docs.

### 9. Repo hygiene is poor: generated artifacts, logs, docs, and probes are mixed with source work

Evidence:

- Current working tree includes a very large amount of generated logs, result files, docs, temporary reports, and probe scripts.
- Project-local untracked files from recent work include:
  - `tools/audit_load_resources.gd`
  - `tools/diagnose_extensive_testing_1_geometry.gd`
- Workspace root contains many verification outputs and log artifacts.

Why this is a problem:

- It becomes hard to see what is source, what is generated, what is provisional, and what is intended to ship.

Fix target:

- Define clear homes for:
  - source
  - uploaded documentation
  - generated verification results
  - temporary audit probes
  - runtime logs

### 10. Placeholder world meshes and temporary UI copy are still present in user-facing scenes

Files:

- `scenes/world/crafting_bench.tscn:25`
- `scenes/world/disassembly_bench.tscn:24`
- `scenes/world/storage_box.tscn:23`
- `scenes/ui/crafting_bench_ui.tscn:126`
- `scenes/ui/crafting_bench_ui.tscn:177`
- `scenes/ui/player_inventory_overlay.tscn:196`

Current behavior:

- World interactables still use `PlaceholderCube`.
- Some UI copy still explicitly says “Temporary” or “placeholder”.

Why this is a problem:

- These are lower severity than pipeline issues.
- They still belong in the ledger because they are visible, non-final, and easy to forget.

Fix target:

- Replace placeholder visuals and temporary copy when the corresponding systems are stabilized.

## Lower Priority But Worth Logging

### 11. Startup/runtime noise is still not clean

Files:

- `services/forge_service.gd:165-184`

Current behavior:

- `ForgeService baked profile` debug output still prints to log.
- The recurring Windows root certificate store warning is external/system-level noise, not a game-logic bug, but it still pollutes runtime logs.

Fix target:

- Remove game-side unconditional debug print noise.
- Keep external warning documented as non-project noise unless it blocks a real feature.

### 12. Tools directory is large and growing without clear tiering

Observation:

- `tools/` currently contains 97 files.

Why this is a problem:

- Verification tools are useful.
- Without clear separation between permanent verifiers, temporary diagnostics, upgrade scripts, and one-off probes, the tools directory becomes hard to trust.

Fix target:

- Split tools into durable categories or document tool retention rules.

## Current Strengths

These are not fix items, but they matter:

- The full script parser sweep currently passes.
- The full scene/resource load sweep currently passes.
- Recent player shell rebuild is much cleaner than the earlier forced animation stack.
- The project does have a large amount of explicit test/verification coverage, even if the tooling organization is messy.

## Recommended Fix Order

1. Fix the canonical crafted-item geometry pipeline.
2. Strip debug/sample ownership out of live forge runtime paths.
3. Split the largest mixed-responsibility runtime owners.
4. Lock unresolved core resolver decisions.
5. Lock the ranged physical / shield foundation to the authored component split and then reduce heuristic inference where it conflicts with explicit design intent.
6. Add shape-derived collision/hit-volume generation only after the canonical geometry stage is truly stable.
7. Clean tooling outputs and repo hygiene.
8. Replace remaining placeholder scene/UI surfaces.

## Closing Rule

This repo should be judged by one permanent rule:

- data can be provisional
- core systems cannot be provisional hacks
- if the foundation is wrong, stop and correct it
- do it the correct way the first time
