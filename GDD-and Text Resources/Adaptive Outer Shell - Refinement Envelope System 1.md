Yes. Here is the **CODEX-facing implementation brief** in the form I think best matches your “measure twice, cut once” workflow.

**Reference material note:** the uploaded purple circle image is **color reference material only** for tool visuals and selection overlays. It is not a texture reference, not a lighting reference, and not a material-finish reference. A good working base pulled from the image is roughly **`#642D91`** / **RGB(100, 45, 145)**, then used with strong transparency for all Stage 2 tool previews.

---

# Stage 2 — Godot Implementation Brief

### Adaptive Outer Shell / Refinement Envelope System

### Runtime only, nested between Stage 1 crafting and WIP testing / export

## 1. Engine fit and Godot-side building blocks

Godot is suitable for this, but the system should be built from the engine’s lower-level mesh and query primitives, not by guessing or by trying to force an editor workflow into runtime. The correct Godot-side references for this are:

* **`ArrayMesh`** for the actual generated/refined mesh data that Stage 2 outputs. ([Godot Engine documentation][1])
* **`SurfaceTool`** for building or rebuilding local patch geometry in a cleaner per-vertex workflow, especially when you want normals/indexing helpers.
* **`MeshDataTool`** when Stage 2 needs face/edge awareness for selectable `surface_face` / `surface_edge` behavior and when patch edits must read/write current topology. It explicitly exposes faces and edges and can commit changes back to a surface. ([Godot Engine documentation][2])
* **`PhysicsDirectSpaceState3D`** with **`PhysicsRayQueryParameters3D`** for runtime 3D picking from the free-look camera into the current working surface. ([Godot Engine documentation][3])
* **`ImmediateMesh`** for light, dynamic, always-changing preview geometry like the brush sphere, face highlights, edge preview strips, and temporary selection overlays. Godot’s docs specifically position it for simple geometry that updates every frame. ([Godot Engine documentation][4])
* **`StandardMaterial3D`** for the transparent purple overlay material used by previews, selection fills, brush markers, and CAD-style highlighted faces. Godot supports transparency through material alpha, and if sorting becomes messy, transparency modes such as Depth Pre-Pass or Alpha Hash are the proper engine-side fallback options. ([Godot Engine documentation][5])

That is the proper engine base. No guessing work, no “maybe use X because it sounds right.”

---

## 2. High-level runtime architecture

### Stage naming lock

**Stage 1**
= the current structural crafting system already in the project.
= the authored block/material/anchor/logic WIP truth.

**Stage 2**
= the Adaptive Outer Shell / Refinement Envelope System.
= the refinement layer that happens after Stage 1 authoring and before taking the WIP out for testing.

The final runtime chain should be:

**Stage 1 Structural Volume / Current Crafting System**
â†’ existing block/material/anchor/logic WIP system
→ existing block/material/anchor/logic system
→ existing save section 1

**Stage 2 Adaptive Outer Shell**
→ generated from Stage 1
→ patch-based refinement layer
→ dedicated save section 2

**Testing / Test Print / Take WIP Out**
→ gameplay truth from Stage 1
→ visible final mesh from Stage 2

**Export / Bake / Final Output**
-> gameplay truth from Stage 1
-> visible final mesh from Stage 2

If the user never touches Stage 2, testing/export must behave exactly like current Stage 1 direct output.

Stage 2 is therefore an **intermediary child stage**, not a replacement system.

---

## 2A. Current project insertion map

This brief must be read against the current live repo, not as a generic sample architecture.

### Stage 1 in the current project means:

* `res://core/models/crafted_item_wip.gd`
  * authored WIP truth
  * layers / cells / builder markers / forge metadata
* `res://runtime/forge/crafting_bench_ui.gd`
  * current live authoring UI shell
* `res://runtime/forge/forge_grid_controller.gd`
  * current live active WIP owner
  * current test-print spawn entry
* `res://services/forge_service.gd`
  * current bake path
  * current test-print build path

### Current take-WIP-out-for-testing path means:

* `ForgeGridController.spawn_test_print_from_active_wip()`
* `ForgeService.build_test_print_from_wip()`
* `res://core/models/test_print_instance.gd`
* `res://runtime/forge/test_print_mesh_builder.gd`
* `res://runtime/player/player_equipped_item_presenter.gd`

### Therefore the real intended insertion point is:

`CraftingBenchUI / ForgeGridController active_wip`
-> `Stage 1 authored WIP`
-> `Stage 2 refinement session`
-> `ForgeService.build_test_print_from_wip()`
-> `TestPrintInstance`
-> test print / player-held testing

### Practical law for this repo:

* Stage 2 starts from `CraftedItemWIP`, not from a detached sample mesh
* Stage 2 must complete before `build_test_print_from_wip()` packages the testing result
* Stage 2 is part of the WIP lifecycle, not a later export-only decoration step
* if no Stage 2 data exists, the current Stage 1 direct testing path must still work unchanged

### Current repo consequence:

In this project, “between Stage 1 and export” is too vague.
The exact intended order is:

* current crafting authoring
* Stage 2 refinement
* take WIP out for testing / test print
* later final export / final item bake

---

## 2B. Placement decision for this project

After comparing the Stage 2 requirements against the live repo, the correct placement is:

* **not** inside `ForgeService` as the main home
* **not** after `TestPrintInstance` is already built
* **not** as a final-export-only decoration pass

The correct home is:

* a **second crafting/refinement mode** inside the existing forge station workflow
* authored from the current `CraftedItemWIP`
* saved as part of the same WIP
* resolved into the test print only when the player takes the WIP out for testing

### Why this is the correct placement

Stage 2 needs to:

* read live Stage 1 authored volume
* keep a reversible baseline against that volume
* expose interactive tools and previews
* save in-progress refinement state
* remain editable before testing

Those are authoring-stage responsibilities, not packaging-stage responsibilities.

### Functional split

**Stage 1**
* structural truth
* gameplay truth
* blocks, anchors, materials, grip logic

**Stage 2**
* visible refinement truth
* shell patches
* local preview/tool state
* reversible refinement state

**Take WIP out for testing**
* packages both stages together
* Stage 1 still drives gameplay validation
* Stage 2 provides the refined visible shell when present

### Practical repo law

The intended flow is:

* `CraftingBenchUI`
* Stage 1 structural authoring
* Stage 2 refinement mode
* save both onto `CraftedItemWIP`
* `ForgeService.build_test_print_from_wip()`
* `TestPrintInstance`
* forge preview / player-held testing

That is the most correct place for the system based on what it needs to do.

---

## 3. Stage 2 responsibilities

Stage 2 is responsible for:

* generating a baseline outer shell from Stage 1
* defining the **Refinement Envelope**
* exposing CAD-style surface tools
* exposing local brush-style refinement tools
* storing and committing local shell patch updates
* restoring back toward the Stage 1 baseline
* keeping newly formed faces/edges valid for later operations
* remaining bounded by Stage 1-derived limits

Stage 2 is **not** responsible for:

* changing Stage 1 structural truth
* creating gameplay truth
* inventing new anchor/hurt/handle logic
* recalculating Stage 1 block mass model
* full volumetric destruction logic

---

## 4. Refinement Envelope law

The **Refinement Envelope** is the editable inward shell band derived from Stage 1.

It is a **thickness-aware directional offset system**, not a global volume rule.

### Rule:

For each editable surface direction, Stage 2 checks local Stage 1 depth behind that surface.

* If local thickness in that direction is **1 cell**, max inward offset from that side is **47.5% of cell size**
* If local thickness in that direction is **2 cells or greater**, max inward offset from that side is **95% of cell size**

With your current Stage 1 cell size of **`0.025 m`**, this means:

* **47.5% offset** = `0.011875 m`
* **95% offset** = `0.02375 m`

This keeps single-cell-thick areas from collapsing while allowing aggressive outer carving on thicker areas.

This must be treated as a **directional local envelope**, not a uniform whole-object shrink pass.

---

## 5. Patch update rule

Stage 2 should use **localized shell patch updates**, not full-shell rebuilds as the main editing loop.

### Normal workflow per pass:

1. determine the affected patch region
2. read current shell state in that region
3. apply tool operation only there
4. update local topology there
5. commit the modified patch as the new current shell in that region
6. refresh neighboring patches only if continuity requires it

This keeps editing responsive and makes “the current surface” truly become the next working surface.

A broader re-derive/rebuild mode may still exist as a repair/resync tool, but it should not be the normal editing loop.

---

## 6. Shell patch minimum data responsibility

Each local Stage 2 patch must remember at least:

* parent Stage 1 region reference
* baseline shell state for restoration
* current edited shell state
* local refinement-envelope limits
* local zone restriction flags
* dirty/update state
* neighboring patch links

That is the minimum stable patch model. More can be added later, but that is the non-guessing baseline.

---

## 7. Tool visual language

All Stage 2 tool visuals use the uploaded purple as reference color.

### Working base color

* **Base preview color:** `#642D91`
* Use **very high transparency**
* The preview should feel readable but never opaque enough to hide the surface being worked on

### Suggested visual alpha range

* **hover preview:** 0.14 to 0.20
* **selected CAD area fill:** 0.20 to 0.28
* **brush sphere body:** 0.10 to 0.16
* **brush boundary / edge line:** 0.35 to 0.50
* **committed selected face highlight before Apply:** 0.22 to 0.30

These are not art values. They are utility values for readable tool feedback.

### One visual law must be enforced:

The visible tool size must be a **direct truthful representation** of the affected area.

No fake gizmo size.
No soft mismatch between visual marker and actual tool reach.
What the player sees must be what the tool will affect.

---

## 8. CAD-style tool interaction model

This is the correct behavior for precise Stage 2 tools such as chamfer/fillet on `surface_edge` / `surface_face`.

### Workflow:

1. select CAD-style tool from menu
2. hover surface in free-look 3D view
3. valid target area highlights in transparent purple
4. click target to add it to current selection
5. selection remains highlighted in the 3D view
6. user returns to tool menu / parameter panel
7. user adjusts values
8. user presses **Apply**
9. change is computed and displayed in the 3D view
10. affected local patch becomes the new current shell state

### Important target behavior:

* selecting a `surface_edge` applies along the resolved edge run
* selecting a `surface_face` may resolve corresponding face-boundary edges when tool logic requires it
* newly created faces become valid `surface_face` targets for later operations
* newly created surface edges become valid `surface_edge` targets for later operations

### Visual requirements:

* hovered valid target: purple transparent preview
* selected target set: stronger purple transparent fill/outline
* invalid zone: no highlight or visibly blocked state
* restricted zone: highlight may appear, but apply button must be blocked or explain restriction

---

## 9. Freehand / local brush interaction model

This is the correct behavior for the local milling/carving/restore tools.

### Workflow:

1. select brush-style tool from menu
2. adjust brush size in menu
3. a purple transparent spherical marker appears in the 3D view
4. sphere radius exactly matches affected radius
5. hover over shell and preview affected zone
6. click/drag to apply pass
7. each pass updates only the touched patch region
8. result becomes the new current shell state

### Brush marker requirements:

* visible as a transparent purple ball marker
* always readable against the mesh
* exact size match to effect radius
* local affected zone preview should update in real time

### Brush tools must support:

* variable size
* variable aggressiveness
* remove mode
* restore mode
* same tool footprint in both directions

---

## 10. Stage 2 tool catalog

### A. CAD-style feature tools

These are selection-first, apply-second tools.

* `surface_edge` chamfer
* `surface_edge` fillet
* face-driven chamfer
* face-driven fillet
* un-chamfer / restore-toward-baseline
* un-fillet / restore-toward-baseline

These tools should prefer clean selection, clear preview, explicit Apply.

---

### B. Local brush-style tools

These are direct shaping tools.

* local chamfer brush
* local fillet brush
* carving / milling brush
* restoration brush
* profile replacement by restore + reapply workflow

These tools should favor immediate action and tight visual feedback.

---

## 11. Reversible behavior model

From a design and code standpoint, the tools should be treated as:

* **apply profile**
* **restore toward baseline**
* **replace one profile with another**

not as totally separate unrelated systems.

This matches the intended user behavior:
players will absolutely use restoration to erase or replace other tool results.

That is expected behavior and must be supported by design.

### Restore law:

Restore may go **back toward the Stage 1-derived baseline shell**, but never beyond it.

---

## 12. Handle / anchor restrictions

Areas already identified in Stage 1 as valid grip/anchor zones should enforce **tool permissions**.

### Rule:

Handle / anchor zones allow **fillet-style refinement only**.

Reason:
these areas should be allowed to become more rounded and holdable, but they should not be visually destroyed by aggressive carving or other destructive surface modifications.

This means Stage 2 must support **zone permission masks**.

At minimum:

* handle-safe zones = fillet allowed, destructive tools blocked
* general zones = normal Stage 2 rules

First live repo pass:

* the current project now has a first protected Stage 2 zone derived from the baked primary grip span
* live zone ids are currently:
  * `stage2_zone_general`
  * `stage2_zone_primary_grip_safe`
* current enforced rule:
  * `stage2_carve` blocked on `stage2_zone_primary_grip_safe`
  * `stage2_chamfer` blocked on `stage2_zone_primary_grip_safe`
  * `stage2_restore` still allowed
* first useful grip-safe tool pass is now live:
  * `stage2_fillet` allowed on `stage2_zone_primary_grip_safe`
  * current fillet pass is still brush-local / patch-local, not the later CAD edge fillet system
* first selection-first feature pass is now live:
  * `stage2_surface_face_fillet`
  * `stage2_surface_face_chamfer`
  * current first-pass `surface_face` truth = connected coplanar Stage 2 face region
  * current face-tool apply target = selected face region outer boundary loop
  * explicit target apply/clear now exist in the live forge Stage 2 menu flow
* first edge-run feature pass is now live:
  * `stage2_surface_edge_fillet`
  * `stage2_surface_edge_chamfer`
  * current first-pass `surface_edge` truth = contiguous coplanar patch-boundary edge run
* first internal feature-edge path is now live:
  * `stage2_surface_feature_edge_fillet`
  * `stage2_surface_feature_edge_chamfer`
  * `stage2_surface_feature_edge_restore`
  * current first-pass `surface_feature_edge` truth = contiguous coplanar internal shared-edge run with both patch sides selected
* first offset-derived feature-region path is now live:
  * `stage2_surface_feature_region_fillet`
  * `stage2_surface_feature_region_chamfer`
  * `stage2_surface_feature_region_restore`
  * current first-pass `surface_feature_region` truth = connected coplanar same-offset Stage 2 patch region with shared zone mask
* first offset-derived feature-band path is now live:
  * `stage2_surface_feature_band_fillet`
  * `stage2_surface_feature_band_chamfer`
  * `stage2_surface_feature_band_restore`
  * current first-pass `surface_feature_band` truth = same-offset feature region plus its adjacent offset-change boundary loop
* first higher-continuity feature-cluster path is now live:
  * `stage2_surface_feature_cluster_fillet`
  * `stage2_surface_feature_cluster_chamfer`
  * `stage2_surface_feature_cluster_restore`
  * current first-pass `surface_feature_cluster` truth = closure of connected coplanar same-zone offset-derived feature regions plus their adjacent transition bands across the same topology plane
* first cross-topology feature-bridge path is now live:
  * `stage2_surface_feature_bridge_fillet`
  * `stage2_surface_feature_bridge_chamfer`
  * `stage2_surface_feature_bridge_restore`
  * current first-pass `surface_feature_bridge` truth = closure of connected same-zone non-zero-offset feature clusters bridged across shared topology edges between different topology planes
* first multi-plane feature-contour path is now live:
  * `stage2_surface_feature_contour_fillet`
  * `stage2_surface_feature_contour_chamfer`
  * `stage2_surface_feature_contour_restore`
  * current first-pass `surface_feature_contour` truth = per-topology-plane offset-transition contour inside a bridge-connected modified feature family
* first offset-derived feature-loop path is now live:
  * `stage2_surface_feature_loop_fillet`
  * `stage2_surface_feature_loop_chamfer`
  * `stage2_surface_feature_loop_restore`
  * current first-pass `surface_feature_loop` truth = boundary loop around a connected coplanar same-offset Stage 2 feature region, including adjacent offset-change seam patches

---

## 13. Target acquisition and selection

Runtime picking in the free-look viewport should use 3D ray queries from camera to current surface region, then resolve hit results to the corresponding patch / face / edge selection logic. Godot’s proper runtime query path for this is `World3D.direct_space_state` through `PhysicsDirectSpaceState3D` and `PhysicsRayQueryParameters3D`. ([Godot Engine documentation][3])

One important implementation note: if you rely on physics-returned triangle face indices and you are using Jolt, those indices may default to `-1` unless Jolt’s ray-cast face index option is enabled. If you do not want to depend on that setting, your safer long-term route is to maintain your own patch/face resolution layer instead of trusting raw physics face indices as the sole truth. ([Godot Engine documentation][6])

---

## 14. Rendering the tool previews

Use **`ImmediateMesh`** for:

* brush sphere outline/body
* temporary face highlight strips
* selection boundary loops
* dynamic hover previews

Use **transparent `StandardMaterial3D`** for:

* fill overlays
* face selection color
* active brush marker body

If transparency sorting becomes ugly, use Godot’s proper material-side transparency options rather than inventing hacks. ([Godot Engine documentation][4])

---

## 15. Mesh generation / update responsibility

### Use `ArrayMesh` for:

* committed patch mesh data
* final Stage 2 shell output
* exportable visible mesh state

### Use `SurfaceTool` for:

* easier local patch rebuild logic
* small/medium patch construction
* normals/indexing helpers during patch generation

### Use `MeshDataTool` for:

* reading/modifying current face/edge-aware topology
* turning newly created geometry into later valid selection targets
* commit-back when a patch operation finishes

This is the clean Godot split. ([Godot Engine documentation][2])

---

## 16. Save behavior

The crafted item remains **one saved entity**, but internally stores:

### Save Section 1

Stage 1 structural data

### Save Section 2

Stage 2 shell/refinement data

Stage 2 may also keep a dedicated working-state save/cache if needed for safer in-progress editing, but the authoritative item save should still package both stage representations together.

---

## 17. Non-negotiable behavioral rules

1. Stage 1 remains the parent truth.
2. Stage 2 is always derived from Stage 1.
3. Stage 2 uses a thickness-aware Refinement Envelope.
4. Stage 2 works through localized shell patch updates.
5. Brush size visualization must be truthful.
6. CAD tools are selection-first, apply-second.
7. Brush tools are direct-action, pass-based.
8. Newly created faces/edges become valid future targets.
9. Restore can return only to baseline, never beyond.
10. Handle/anchor zones are fillet-only.
11. Purple preview color is reference-driven and transparent.
12. No Stage 2 edits = same export as current Stage 1-only result.

---

## 18. The intended user experience

The player should feel that:

* Stage 1 builds the object
* Stage 2 refines the object
* CAD tools are deliberate and precise
* brush tools are tactile and immediate
* the purple previews always tell the truth
* the current surface is always the real working surface
* nothing silently overreaches beyond what the UI shows

That is the goal.

---

If you want the next pass, I would turn this into a **module/file responsibility map** for Godot, so CODEX has a direct “build these classes, in this order, with these responsibilities” page.

[1]: https://docs.godotengine.org/en/stable/classes/class_arraymesh.html "https://docs.godotengine.org/en/stable/classes/class_arraymesh.html"
[2]: https://docs.godotengine.org/en/stable/classes/class_meshdatatool.html "https://docs.godotengine.org/en/stable/classes/class_meshdatatool.html"
[3]: https://docs.godotengine.org/en/stable/classes/class_physicsdirectspacestate3d.html "https://docs.godotengine.org/en/stable/classes/class_physicsdirectspacestate3d.html"
[4]: https://docs.godotengine.org/en/stable/tutorials/3d/procedural_geometry/immediatemesh.html "https://docs.godotengine.org/en/stable/tutorials/3d/procedural_geometry/immediatemesh.html"
[5]: https://docs.godotengine.org/en/latest/tutorials/3d/standard_material_3d.html "https://docs.godotengine.org/en/latest/tutorials/3d/standard_material_3d.html"
[6]: https://docs.godotengine.org/es/4.x/tutorials/physics/using_jolt_physics.html "https://docs.godotengine.org/es/4.x/tutorials/physics/using_jolt_physics.html"
