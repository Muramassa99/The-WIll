Good. Here is a **CODEX roadmap + file/module responsibility map** built around the system we already locked, using the proper Godot-side primitives instead of vague guesses.

---

# Stage 2 — CODEX Roadmap

### Adaptive Outer Shell / Refinement Envelope

### Runtime intermediary stage between Stage 1 crafting and WIP testing / export

## Stage naming lock

**Stage 1**
= the current structural crafting system already in the project.
= the authored block/material/anchor/logic WIP truth.

**Stage 2**
= the Adaptive Outer Shell / Refinement Envelope System.
= the refinement layer that happens after Stage 1 authoring and before taking the WIP out for testing.

## 0. Godot-side foundation to use

These are the engine pieces this roadmap assumes:

* **`MeshInstance3D`** to render the current Stage 2 working mesh in the 3D scene. ([Godot Engine documentation][1])
* **`ArrayMesh`** as the committed mesh container for generated/refined shell output.
* **`SurfaceTool`** for building/rebuilding local patch geometry in a sane per-vertex workflow.
* **`MeshDataTool`** when face/edge-aware topology access is needed for selection, patch editing, and commit-back. ([Godot Engine documentation][2])
* **`ImmediateMesh`** for live preview-only geometry that changes constantly, such as the purple brush sphere and temporary selection overlays. Godot explicitly frames it as a good fit for simple geometry that updates every frame. ([Godot Engine documentation][3])
* **`PhysicsDirectSpaceState3D`** + **`PhysicsRayQueryParameters3D`** for runtime picking from the free-look camera into the Stage 2 shell. ([Godot Engine documentation][4])
* **`StandardMaterial3D`** with transparency for all purple previews/selection fills. If transparency ordering becomes ugly, use the engine’s transparency modes rather than inventing a fake workaround.
* **custom `Resource` data + `ResourceSaver`** for saving Stage 2 state as part of the item data. Godot resources serialize custom properties, and `ResourceSaver` is the proper engine-side path for saving them. ([Godot Engine documentation][5])

---

# 1. Folder layout

Use a hard separation between Stage 2 runtime, Stage 2 data, Stage 2 tools, and Stage 2 UI.

```text
res://systems/forge_stage2/
    core/
    data/
    tools/
    ui/
    visual/
    integration/
```

That way Stage 2 stays modular and does not leak into Stage 1 logic files.

---

# 1A. Repo-specific attachment map

The generic folder map above is only a guideline. For this project, Stage 2 should attach to the **existing** code layout instead of pretending the repo starts empty.

## Current live Stage 1 owners

* `res://core/models/crafted_item_wip.gd`
  * authored crafting truth
* `res://runtime/forge/crafting_bench_ui.gd`
  * current live forge authoring shell
* `res://runtime/forge/forge_grid_controller.gd`
  * active WIP owner
  * current test-print spawn handoff
* `res://services/forge_service.gd`
  * bake + test-print packaging
* `res://core/models/test_print_instance.gd`
  * current testing handoff package
* `res://runtime/forge/test_print_mesh_builder.gd`
  * current visible testing mesh builder
* `res://runtime/player/player_equipped_item_presenter.gd`
  * current player-held testing visual path

## Repo-specific Stage 2 placement recommendation

Instead of introducing a disconnected foreign tree first, Stage 2 should begin in the current repo style:

* `res://core/models/`
  * `stage2_item_state.gd`
  * `stage2_patch_state.gd`
  * `stage2_tool_state.gd`
  * `stage2_zone_mask.gd`
* `res://core/resolvers/`
  * `stage2_shell_generator.gd`
  * `stage2_patch_apply_resolver.gd`
  * `stage2_selection_resolver.gd`
* `res://runtime/forge/`
  * `stage2_session_controller.gd`
  * `stage2_shell_view.gd`
  * `stage2_preview_renderer.gd`
  * `stage2_toolbar_presenter.gd`
  * `stage2_tool_panel_presenter.gd`
* `res://services/`
  * `forge_stage2_service.gd`

That keeps Stage 2 aligned with the project’s actual `core / runtime / services` split.

## Exact live insertion points

### Data attachment

* `CraftedItemWIP`
  * future owner of Stage 2 saved refinement section
  * Stage 1 remains section 1
  * Stage 2 becomes section 2

### Testing handoff attachment

* `ForgeService.build_test_print_from_wip()`
  * future point where Stage 2 state is resolved before the test print is packaged
* `TestPrintInstance`
  * future carrier of Stage 2 visible shell / refinement output
* `TestPrintMeshBuilder`
  * future fallback builder when no Stage 2 shell exists
  * or final mesh builder from Stage 2 shell when it does exist

### Player-held testing attachment

* `PlayerEquippedItemPresenter.build_equipped_item_node()`
  * should continue to work through `TestPrintInstance`
  * should not need a separate parallel Stage 2 path if the test print handoff is designed correctly

## Repo-specific law

In this project, Stage 2 should not be introduced as a separate disconnected mini-app.
It should be inserted directly into the existing chain:

* `CraftedItemWIP`
* `ForgeGridController`
* `ForgeService`
* `TestPrintInstance`
* `TestPrintMeshBuilder`
* player-held / forge test presentation

That is the actual code path Stage 2 must adapt to.

## Placement decision

Based on the functionality Stage 2 actually needs, the correct workflow placement is:

* `CraftingBenchUI` owns the user-facing transition into Stage 2
* `ForgeGridController` continues to own the active Stage 1 WIP
* Stage 2 runs as a refinement substage attached to that active WIP
* Stage 2 save data lives on the same `CraftedItemWIP`
* `ForgeService.build_test_print_from_wip()` resolves Stage 2 only when packaging the test print / testing handoff

### Why

Because Stage 2 needs:

* interactive editing
* preview rendering
* patch-local reversible state
* restore-to-baseline behavior
* save/load as part of work-in-progress authoring

That means it is a **crafting-stage editor mode**, not just a service-side mesh modifier.

### What should stay unchanged

* gameplay truth still comes from Stage 1 bake data
* Stage 2 remains optional
* if no Stage 2 state exists, the current Stage 1 -> test print path continues unchanged

### Recommended first real implementation seam

Start by adding:

* Stage 2 saved state on `CraftedItemWIP`
* a Stage 2 entry/exit mode in `CraftingBenchUI`
* a Stage 2 runtime controller under `runtime/forge`
* Stage 2 consumption inside `ForgeService.build_test_print_from_wip()`

Do not start by trying to hide Stage 2 deep inside `ForgeService` alone.

---

# 2. File/module map

## A. Core runtime

### `res://systems/forge_stage2/core/forge_stage2_root.gd`

**Role:** top-level runtime entry for Stage 2.

Responsibilities:

* receives Stage 1 item/session input
* boots the Stage 2 session
* owns all Stage 2 child managers
* coordinates open / close / save / cancel / hand-off to testing / apply-to-export

This is the parent runtime node for the whole Stage 2 flow.

**Project adaptation note:**
In the current repo this should probably begin as `res://runtime/forge/stage2_session_controller.gd` or similar, then only split further if the real code size justifies it.

---

### `res://systems/forge_stage2/core/stage2_session_controller.gd`

**Role:** orchestration brain for one active refinement session.

Responsibilities:

* load Stage 1 source reference
* request shell generation
* switch tools
* route input to active tool
* tell patch manager when a pass begins/ends
* manage dirty state
* request save / restore / rebuild

This should be the main non-UI runtime coordinator.

---

### `res://systems/forge_stage2/core/stage2_shell_generator.gd`

**Role:** generates the baseline Adaptive Outer Shell from Stage 1.

Responsibilities:

* read Stage 1 structural data
* build the Stage 2 baseline shell
* calculate the **Refinement Envelope**
* apply thickness-aware directional offset rules
* output initial patchable shell representation

This is where the Stage 1 → Stage 2 translation happens.

---

### `res://systems/forge_stage2/core/stage2_patch_manager.gd`

**Role:** owns all live Stage 2 shell patches.

Responsibilities:

* create patch objects
* resolve which patch a tool hit belongs to
* update only touched patches
* mark neighbors dirty if continuity is affected
* commit local patch edits as new current shell truth
* support partial rebuild and broader rebuild modes

This is the system that prevents full-shell rebuilds every pass.

---

### `res://systems/forge_stage2/core/stage2_apply_service.gd`

**Role:** receives a fully defined tool action and performs the actual local shell modification.

Responsibilities:

* apply feature-style edits
* apply brush-style edits
* clamp edits to the Refinement Envelope
* clamp restoration to baseline
* enforce zone restrictions
* return a modified patch result

Think of this as the tool execution layer.

---

### `res://systems/forge_stage2/core/stage2_selection_service.gd`

**Role:** runtime selection/picking service for Stage 2.

Responsibilities:

* raycast from free-look camera
* determine hit point / hit patch / hit local topology target
* resolve `surface_face` and `surface_edge`
* build current CAD-style selection set
* feed previews to the preview renderer

Use physics ray queries here. If raw face-index dependence becomes unstable or Jolt gets in the way, keep your own patch/face mapping as the real truth instead of trusting engine triangle indices alone.

---

### `res://systems/forge_stage2/core/stage2_save_service.gd`

**Role:** saves and loads Stage 2 state.

Responsibilities:

* serialize Stage 2 data resources
* merge them into the item’s full save
* restore a session from saved Stage 1 + Stage 2 data
* optionally write an in-session recovery save if you want extra safety

This should use custom `Resource` types and Godot’s normal resource saving path, not ad-hoc text dumping. ([Godot Engine documentation][5])

**Project adaptation note:**
Current save authority already lives through `CraftedItemWIP`, player forge WIP library state, and forge project workflow. Stage 2 save logic should plug into that existing path instead of inventing a second unrelated save stack.

---

## B. Data resources

### `res://systems/forge_stage2/data/stage2_item_state.gd`

**Type:** `Resource`

**Role:** authoritative saved Stage 2 state for one item.

Responsibilities:

* reference Stage 1 parent identity
* store Stage 2 patch list
* store baseline shell metadata
* store version / dirty / upgrade metadata if needed

This is the root Stage 2 save object.

---

### `res://systems/forge_stage2/data/stage2_patch_state.gd`

**Type:** `Resource`

**Role:** saved data for one shell patch.

Responsibilities:

* parent Stage 1 region reference
* baseline patch shell data
* current patch shell data
* refinement envelope data for that patch
* local zone mask / permissions
* neighbor references
* dirty state

This is the direct saved form of a patch.

---

### `res://systems/forge_stage2/data/stage2_tool_state.gd`

**Type:** `Resource` or plain class

**Role:** current tool parameters.

Responsibilities:

* active tool id
* brush size
* aggressiveness
* radius
* mode = apply / restore
* chamfer/fillet parameters
* selection mode state

Useful both for UI state and session restore.

---

### `res://systems/forge_stage2/data/stage2_zone_mask.gd`

**Type:** `Resource` or helper class

**Role:** local restriction data.

Responsibilities:

* handle-safe / anchor-safe zones
* general unrestricted zones
* any future restricted functional regions

This is what blocks destructive tools in grip areas while allowing fillet.

---

## C. Visual/runtime display

### `res://systems/forge_stage2/visual/stage2_shell_view.gd`

**Role:** displays the committed Stage 2 working shell.

Responsibilities:

* own the active `MeshInstance3D`
* swap updated `ArrayMesh` results into view
* keep visuals in sync with patch commits

This is the visible refined item.

---

### `res://systems/forge_stage2/visual/stage2_preview_renderer.gd`

**Role:** displays all live previews.

Responsibilities:

* hovered face highlight
* selected CAD region fill
* edge-chain preview
* brush sphere marker
* affected-area local preview
* blocked-zone preview if needed

This should use `ImmediateMesh` for the live-changing bits and transparent purple materials for readability.

---

### `res://systems/forge_stage2/visual/stage2_preview_materials.gd`

**Role:** centralizes preview colors/material creation.

Responsibilities:

* build the reference purple transparent materials
* hover material
* selected material
* blocked material
* brush body material
* brush outline material

Use the uploaded image as the color reference. Start from roughly `#642D91` and vary alpha, not hue.

---

## D. Tools

### `res://systems/forge_stage2/tools/base/stage2_tool_base.gd`

**Role:** shared base for all Stage 2 tools.

Responsibilities:

* standard enter/exit hooks
* preview update hooks
* apply hooks
* restore hooks
* parameter validation
* zone restriction checks

All Stage 2 tools inherit from this.

---

### `res://systems/forge_stage2/tools/base/stage2_feature_tool_base.gd`

**Role:** base for CAD-style tools.

Responsibilities:

* face/edge selection handling
* apply-button style operation flow
* selection preview
* bulk target application

Used by chamfer/fillet tools.

---

### `res://systems/forge_stage2/tools/base/stage2_brush_tool_base.gd`

**Role:** base for direct-action tools.

Responsibilities:

* brush sphere radius
* drag-pass handling
* hit accumulation
* local patch stamping
* tool aggressiveness logic
* restore/apply direction mode

Used by carve/restore/local-fillet/local-chamfer tools.

---

### `res://systems/forge_stage2/tools/feature/tool_surface_edge_chamfer.gd`

**Role:** CAD-style chamfer along selected `surface_edge` run.

---

### `res://systems/forge_stage2/tools/feature/tool_surface_edge_fillet.gd`

**Role:** CAD-style fillet along selected `surface_edge` run.

---

### `res://systems/forge_stage2/tools/feature/tool_face_driven_chamfer.gd`

**Role:** select face, resolve corresponding boundary edges, apply chamfer.

---

### `res://systems/forge_stage2/tools/feature/tool_face_driven_fillet.gd`

**Role:** select face, resolve corresponding boundary edges, apply fillet.

---

### `res://systems/forge_stage2/tools/brush/tool_local_carve.gd`

**Role:** subtractive milling/carving brush.

Responsibilities:

* local removal only
* envelope clamp
* patch-local commits
* no structural truth changes

---

### `res://systems/forge_stage2/tools/brush/tool_local_restore.gd`

**Role:** add-back brush toward baseline.

Responsibilities:

* same radius and pass model as carve
* opposite effect direction
* clamp at Stage 1-derived baseline
* used for local undo and finish replacement

This is likely the most-used fine-tuning tool in practice.

---

### `res://systems/forge_stage2/tools/brush/tool_local_chamfer.gd`

**Role:** local brush-based chamfer zone tool.

---

### `res://systems/forge_stage2/tools/brush/tool_local_fillet.gd`

**Role:** local brush-based fillet zone tool.

---

## E. UI

### `res://systems/forge_stage2/ui/stage2_toolbar.gd`

**Role:** tool selection bar.

Responsibilities:

* switch between feature tools and brush tools
* show active tool state
* route selection to session controller

---

### `res://systems/forge_stage2/ui/stage2_tool_panel.gd`

**Role:** current tool parameter panel.

Responsibilities:

* size
* aggressiveness
* chamfer amount
* fillet radius
* restore/apply mode
* Apply button for CAD-style tools

This is where the user goes after selecting CAD targets in the 3D view.

---

### `res://systems/forge_stage2/ui/stage2_status_panel.gd`

**Role:** mode/status visibility.

Responsibilities:

* active tool
* current patch count / dirty state
* selected targets count
* blocked-zone warnings
* rebuild / resync / save feedback

---

## F. Integration layer

### `res://systems/forge_stage2/integration/stage1_stage2_bridge.gd`

**Role:** reads the already-existing Stage 1 system and exposes the clean input Stage 2 needs.

Responsibilities:

* fetch Stage 1 structural volume
* fetch Stage 1 cell size
* fetch Stage 1 functional zones
* fetch Stage 1 handle/anchor masks
* build the Stage 2 input payload

This is where Stage 2 latches onto your existing system cleanly.

---

### `res://systems/forge_stage2/integration/stage2_export_bridge.gd`

**Role:** hands final data to the testing / export pipeline.

Responsibilities:

* provide final visible Stage 2 shell result
* provide Stage 1 logic reference
* provide the refined shell result to the take-WIP-out / test-print path when Stage 2 exists
* confirm “no Stage 2 edits” fallback behavior
* merge the two stages into the final item export process

**Project adaptation note:**
In the current repo this bridge belongs first at the `ForgeService.build_test_print_from_wip()` / `TestPrintInstance` handoff, not only at some later final-export-only path.

---

# 3. Build order

This is the order I would give CODEX so you do not generate spaghetti.

## Phase 1 — Data and shell foundation

Build first:

1. `stage2_item_state.gd`
2. `stage2_patch_state.gd`
3. `stage1_stage2_bridge.gd`
4. `stage2_shell_generator.gd`

Goal:

* Stage 2 can open a Stage 1 item
* build a baseline shell
* create patch data
* save/load empty Stage 2 state

Do **not** build tools first.

---

## Phase 2 — View and preview

Build next:

1. `stage2_shell_view.gd`
2. `stage2_preview_materials.gd`
3. `stage2_preview_renderer.gd`

Goal:

* show baseline shell
* show purple hover/select previews
* show a truthful brush sphere
* confirm visual language works before deformation logic

---

## Phase 3 — Selection and patch update loop

Build next:

1. `stage2_selection_service.gd`
2. `stage2_patch_manager.gd`
3. `stage2_apply_service.gd`
4. `stage2_session_controller.gd`

Goal:

* pick shell
* identify patch
* modify local patch
* commit patch as new current shell
* keep untouched regions stable

This is the real Stage 2 spine.

---

## Phase 4 — First tool pair only

Build first tool pair:

1. `tool_local_carve.gd`
2. `tool_local_restore.gd`

Goal:

* prove patch-local refinement
* prove restoration toward baseline
* prove brush radius preview matches real effect
* prove each pass becomes new current shell

Do **not** start with fillet/chamfer.
Carve + restore will validate the entire patch/refinement loop first.

---

## Phase 5 — CAD tool path

After carve/restore works:

1. `tool_surface_edge_chamfer.gd`
2. `tool_surface_edge_fillet.gd`
3. `tool_face_driven_chamfer.gd`
4. `tool_face_driven_fillet.gd`

Goal:

* prove target selection
* prove apply-button flow
* prove new faces become reusable targets

---

## Phase 6 — Restriction masks

Build:

1. `stage2_zone_mask.gd`
2. handle-safe zone enforcement in tool base classes

Goal:

* handle/anchor regions allow fillet only
* destructive tools respect restrictions

Current repo status:

* first pass is now live through patch `zone_mask_id`
* baked primary grip span is the current zone source
* `stage2_zone_primary_grip_safe` now blocks destructive carve/chamfer
* first brush-level `stage2_fillet` is now the allowed grip-safe edit path
* first selection-first feature path is also now live:
  * `stage2_surface_face_fillet`
  * `stage2_surface_face_chamfer`
  * current `surface_face` truth = connected coplanar Stage 2 face region
  * current face-tool apply target = selected face region outer boundary loop
  * explicit target apply/clear now exist
* first edge-run feature path is also now live:
  * `stage2_surface_edge_fillet`
  * `stage2_surface_edge_chamfer`
  * current `surface_edge` truth = contiguous coplanar patch-boundary edge run
* first internal feature-edge path is also now live:
  * `stage2_surface_feature_edge_fillet`
  * `stage2_surface_feature_edge_chamfer`
  * `stage2_surface_feature_edge_restore`
  * current `surface_feature_edge` truth = contiguous coplanar internal shared-edge run with both patch sides selected
* first offset-derived feature-region path is also now live:
  * `stage2_surface_feature_region_fillet`
  * `stage2_surface_feature_region_chamfer`
  * `stage2_surface_feature_region_restore`
  * current `surface_feature_region` truth = connected coplanar same-offset Stage 2 patch region with shared zone mask
* first offset-derived feature-band path is also now live:
  * `stage2_surface_feature_band_fillet`
  * `stage2_surface_feature_band_chamfer`
  * `stage2_surface_feature_band_restore`
  * current `surface_feature_band` truth = same-offset feature region plus its adjacent offset-change boundary loop
* first higher-continuity feature-cluster path is also now live:
  * `stage2_surface_feature_cluster_fillet`
  * `stage2_surface_feature_cluster_chamfer`
  * `stage2_surface_feature_cluster_restore`
  * current `surface_feature_cluster` truth = closure of connected coplanar same-zone offset-derived feature regions plus their adjacent transition bands across the same topology plane
* first cross-topology feature-bridge path is also now live:
  * `stage2_surface_feature_bridge_fillet`
  * `stage2_surface_feature_bridge_chamfer`
  * `stage2_surface_feature_bridge_restore`
  * current `surface_feature_bridge` truth = closure of connected same-zone non-zero-offset feature clusters bridged across shared topology edges between different topology planes
* first multi-plane feature-contour path is also now live:
  * `stage2_surface_feature_contour_fillet`
  * `stage2_surface_feature_contour_chamfer`
  * `stage2_surface_feature_contour_restore`
  * current `surface_feature_contour` truth = per-topology-plane offset-transition contour inside a bridge-connected modified feature family
* first offset-derived feature-loop path is also now live:
  * `stage2_surface_feature_loop_fillet`
  * `stage2_surface_feature_loop_chamfer`
  * `stage2_surface_feature_loop_restore`
  * current `surface_feature_loop` truth = boundary loop around a connected coplanar same-offset Stage 2 feature region, including adjacent offset-change seam patches
* broader anchor-safe / fillet-only families still remain future expansion work

---

## Phase 7 — Save/export integration

Build:

1. `stage2_save_service.gd`
2. `stage2_export_bridge.gd`

Goal:

* one-item save with two stage sections
* stable return to session
* no-edit Stage 2 fallback exports like current Stage 1

---

# 4. Tool UX rules CODEX must follow

## CAD-style tools

* select tool
* select target in 3D view
* purple transparent target stays highlighted
* return to panel
* change values
* click Apply
* result appears in 3D view
* local patch becomes new current shell

## Brush-style tools

* select brush tool
* purple transparent sphere appears
* sphere size exactly matches affected area
* drag to apply passes
* local patch updates live or at pass cadence
* restoration uses same tool footprint in reverse

## Visual law

The preview is always truthful.
No fake marker scale.
No mismatch between highlight and effect range.

---

# 5. Purple visual scheme

Use the uploaded circle as **reference material only**.

### Base purple

* `#642D91` / RGB(100, 45, 145)

### Suggested preview usage

* hover face: same purple, low alpha
* selected CAD region: same purple, slightly stronger alpha
* brush sphere fill: same purple, very low alpha
* brush outline / edge strip: same purple, higher alpha
* blocked zone: same hue family, darker / lower saturation or add a warning outline

Keep the hue consistent so the user always reads “purple = Stage 2 working preview.”

---

# 6. Final implementation law

Tell CODEX this clearly:

> Do not build Stage 2 as a monolithic mesh-rebuild system. Build it as a patch-based refinement system derived from Stage 1, with local patch commits, truthful visual previews, reversible brush behavior, and CAD-style feature application on selectable surface targets.

That one sentence protects the architecture.

---


[1]: https://docs.godotengine.org/en/stable/classes/class_meshinstance3d.html?utm_source=chatgpt.com "MeshInstance3D — Godot Engine (stable) documentation in ..."
[2]: https://docs.godotengine.org/en/stable/classes/class_meshdatatool.html "https://docs.godotengine.org/en/stable/classes/class_meshdatatool.html"
[3]: https://docs.godotengine.org/en/stable/tutorials/3d/procedural_geometry/immediatemesh.html "https://docs.godotengine.org/en/stable/tutorials/3d/procedural_geometry/immediatemesh.html"
[4]: https://docs.godotengine.org/en/stable/classes/class_physicsdirectspacestate3d.html "https://docs.godotengine.org/en/stable/classes/class_physicsdirectspacestate3d.html"
[5]: https://docs.godotengine.org/en/stable/tutorials/scripting/resources.html?utm_source=chatgpt.com "Resources — Godot Engine (stable) documentation in English"
