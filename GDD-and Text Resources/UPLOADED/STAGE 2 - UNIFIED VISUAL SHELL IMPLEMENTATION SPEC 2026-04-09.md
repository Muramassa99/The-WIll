# STAGE 2 - UNIFIED VISUAL SHELL IMPLEMENTATION SPEC

Date: 2026-04-09

Authority:
- This file is now the execution-facing Stage 2 implementation spec.
- It compounds:
  - `Adaptive Outer Shell - Refinement Envelope System 1.md`
  - `Adaptive Outer Shell - Refinement Envelope 2.md`
  - the live repo state
  - the 2026-04-09 Godot runtime mesh-editing research pass
- If older Stage 2 docs conflict with this file on implementation direction, this file wins.

## 1. Purpose

Stage 2 exists to turn the Stage 1 crafted structure into a coherent final visible shell that can be refined at runtime.

Stage 2 is not a gameplay-truth replacement.
Stage 2 is not an export-only decoration pass.
Stage 2 is not a layer-based editing mode.

Stage 2 is:
- a child refinement stage of the crafting station
- authored on the same WIP as Stage 1
- full 3D model interaction
- visual-shell truth only

## 2. Locked Stage Laws

### Stage 1

Stage 1 remains the parent authority for:
- structural authored truth
- material placement truth
- grip-point truth
- backend gameplay truth
- future collision/helper truth for melee and shields

Stage 1 must continue to own:
- `CraftedItemWIP` authored cells/layers/markers
- `BakedProfile`
- primary grip validation
- future simple melee/shield containment logic

### Stage 2

Stage 2 remains the child authority for:
- unified visible shell generation
- visual-only surface refinement
- local shell editing
- final visible runtime mesh when the item is seen in game

Stage 2 must not redefine:
- grip semantics
- material stats
- combat semantics
- gameplay validation

### Future Paint Stage

A later paint/recolor/retexturing stage is a future child of Stage 2 visual output, not of Stage 1.

### Future Engraving / Finalization Lock

A later engraving/naming/finalization stage will:
- lock Stage 2 shape editing
- produce the final export-ready version of the item
- become the point where export-side simplification is allowed to run

Until that later lock stage exists:
- Stage 2 should stay biased toward editability, not toward export-time simplification
- the editable Stage 2 shell should keep the topology density it needs for later refinement work

## 3. Zero-Edit Law

Stage 2 editing is optional for the player.

Even if the player never edits Stage 2:
- the system must still auto-generate the Stage 2 baseline visual shell from Stage 1
- that baseline shell becomes the visible runtime asset
- the game must never require manual refinement editing just to produce a valid visible item

So the rule is:
- Stage 2 is optional as an editing activity
- Stage 2 is not optional as the final visual-output layer

Baseline zero-edit shape law:
- zero-edit Stage 2 must still auto-generate a welded editable shell before any manual refinement edits exist
- zero-edit Stage 2 should be edit-ready, not prematurely simplified for export/runtime economy
- the editable Stage 2 shell should generally carry more usable surface topology than the raw Stage 1 surface output so refinement tools have enough points and triangles to work with
- flat Stage 1 forms should still resolve into one coherent welded shell, but not collapse so aggressively that broad untouched surfaces become starved of editing resolution
- example: a `1 x 30 x 30` slab should resolve to one coherent welded shell with enough evenly distributed outer-surface topology to support later carving, chamfering, and filleting across the broad faces
- the baseline shell should not preserve the old dense prototype-style patch spam, but it also should not chase minimum triangle count while the item is still forge-editable

## 4. Godot Tooling Decision

Godot provides the low-level runtime building blocks needed for this system:
- `ArrayMesh`
- `SurfaceTool`
- `MeshDataTool`
- `ImmediateMesh`
- `PhysicsDirectSpaceState3D` with `PhysicsRayQueryParameters3D`
- `StandardMaterial3D`

Important lock:
- Godot does not provide a ready-made runtime sculpt/remesh system that should replace this work for us.
- We must build the Stage 2 remesh/topology logic ourselves using Godot's lower-level mesh APIs.

Practical meaning:
- `MeshDataTool` is for reading/writing live topology and local triangle/vertex data
- `SurfaceTool` is for rebuilding committed mesh output cleanly
- `ImmediateMesh` is preview-only
- `ImporterMesh.generate_lods()` is later optional display LOD support, not Stage 2 authoring/remeshing

## 5. Current Live Code Truth vs Target Truth

### What the current live prototype does

The current live Stage 2 code:
- generates Stage 2 from Stage 1 canonical surface quads
- splits those quads into 1x1 local patch quads
- stores one `baseline_quad` and one `current_quad` per patch
- applies carve/fillet/chamfer/restore by shifting quad origins along their normals

Main current files:
- `res://services/forge_stage2_service.gd`
- `res://core/models/stage2_item_state.gd`
- `res://core/models/stage2_patch_state.gd`
- `res://core/models/stage2_shell_quad_state.gd`
- `res://runtime/forge/forge_stage2_brush_presenter.gd`
- `res://runtime/forge/forge_stage2_selection_presenter.gd`

### Why the current prototype is not the final system

The current prototype is useful as a proof of:
- Stage 2 mode ownership
- grip-safe restriction logic
- preview/input flow
- save/handoff path

But it is not yet the final Stage 2 mesh architecture because:
- it edits drifting quads instead of one coherent shell
- it does not generate new triangles from the altered surface state
- it does not rebuild local topology as edits happen
- it does not let newly formed surface shapes become true future topology

### Final truth to lock now

Do not keep extending the quad-offset Stage 2 prototype as if it is the final geometry model.

The final geometry model must be:
- one welded unified outer shell
- locally editable
- locally retriangulated/remeshed after edits
- still bounded by Stage 1 envelope and protected-zone rules

Stage 1 change propagation law:
- if Stage 1 later changes after Stage 2 already exists, Stage 2 must adapt locally to those Stage 1 changes
- additive Stage 1 changes should push the local Stage 2 shell outward as if the underlying material volume expanded from inside
- subtractive Stage 1 changes should pull/adapt the local Stage 2 shell inward while preserving nearby valid Stage 2 edits where possible
- this adaptation must be local and continuity-aware, not a blind full reset unless no safe local reconciliation is possible

## 5B. Godot-Native Refoundation Path

From this point forward, Stage 2 implementation must prefer the official Godot 4.6 mesh/tool stack before adding more custom shell logic.

Research law:
- before any Stage 2 Godot implementation step, do topic-specific online documentation research first, even for trivial engine/API changes
- official Godot documentation is the first technical authority for Stage 2 engine behavior and tooling choices

Locked foundation order:
1. `Resource` / `ResourceSaver` for persisted Stage 2 state
2. `SurfaceTool` for readable runtime mesh construction / rebuild
3. `ArrayMesh` for committed generated mesh output
4. `MeshDataTool` for topology-aware vertex / edge / face editing support
5. `ImmediateMesh` for preview-only live overlays
6. `PhysicsDirectSpaceState3D` + `PhysicsRayQueryParameters3D` for runtime picking queries

Replacement law:
- do not keep growing the current patch/shell bridge as the long-term Stage 2 foundation
- keep only the parts of the current system that still fit the Godot-native path cleanly
- replace custom bridge layers where the native stack already provides a clearer foundation

Implementation ladder from here:
1. create a persistent editable Stage 2 mesh state derived from canonical geometry through `SurfaceTool`
2. keep the current live path temporarily, but generate the new editable mesh state in parallel during Stage 2 initialization
3. establish `MeshDataTool` creation from that editable state as the topology-edit base
4. migrate picking/selection to official ray-query -> mesh hit -> topology ownership flow
5. migrate carve first onto the editable mesh / topology path
6. migrate fillet and chamfer only after the editable mesh path proves stable
7. retire patch-local deformation once the editable mesh path fully owns Stage 2 edits

Current additive rule:
- the first slices of this refoundation must be additive and non-destructive
- new official-tool-backed state may exist alongside the current live Stage 2 path until the replacement is proven

## 6. Final Architecture

### Final runtime chain

The intended item flow is:

1. Stage 1 authored WIP
2. Stage 1 bake/profile truth
3. Stage 2 baseline unified shell generated from Stage 1
4. Stage 2 optional refinement edits
5. test print / player-visible runtime mesh uses Stage 2 shell
6. gameplay/backend logic still uses Stage 1 truth

### Final authority split

Stage 1 owns:
- gameplay truth
- materials as authored/counted data
- grip logic
- backend shape logic

Stage 2 owns:
- visible shell truth
- local topology edits
- final rendered item mesh

### Player/runtime lock

When the item is shown in game:
- the player sees Stage 2 shell output
- the backend still trusts Stage 1-derived data

## 7. Combat / Collision Simplification Lock

The cutting-edge / blunt-zone classifier idea is dropped.

Current locked gameplay simplification:
- keep grip-point logic
- do not add extra Stage 1 edge/blunt classifiers

For melee weapons and shields:
- Stage 1 structural truth will later drive a simple containment-style collision/hurt volume
- practical target is a simple enclosing combat volume, capsule-style or similarly simple

For ranged physical and magic:
- held-item/backend collision can still come from Stage 1-style logic later
- actual hurt delivery belongs to projectile/effect systems, not to Stage 2 shell semantics

Therefore:
- Stage 2 does not need combat edge tagging
- Stage 2 does not need hurt-zone semantic ownership

Stage 1 shape branching law:
- the Stage 1 derived geometric output may branch into three independent downstream uses:
  - Stage 2 visual base shell input
  - collision shape input
  - hurt shape input
- the preferred path is to reuse the same Stage 1-derived geometric basis for all three, then let each downstream path specialize independently
- simpler fallback containment primitives such as capsules remain allowed if a specific use case later needs them, but they are not the preferred first assumption

## 8. Unified Shell Requirement

Stage 2 must not remain a stack of interacting surface plates.

The Stage 2 baseline must become:
- one welded outer shell derived from Stage 1 geometry
- with coherent vertices, edges, and triangles
- with no visual gaps
- with no fake transparency unless a future material explicitly supports it
- with enough usable surface density for later refinement while the item remains editable

This shell may still be hollow internally.
It only needs to present as a coherent solid outer surface to the player.

## 9. Editing Density And Final Triangle Economy Law

Stage 2 editing should prioritize usable surface density and truthful manipulation, not early triangle reduction.

Required editing behavior:
- the live editable Stage 2 shell may and should carry more polygons than the raw Stage 1-derived outer surface if that extra density improves refinement flexibility
- local edits may densify topology wherever the shell needs more curvature, transition detail, or deformation control
- during forge editing, remesh/retriangulation should preserve and improve editability rather than trying to minimize triangle count
- broad untouched areas should still avoid meaningless prototype-style patch spam, but they should not be aggressively collapsed if that harms later tool control

Export simplification law:
- topology simplification for runtime economy belongs to the final export/lock side of the process, not to live forge editing
- simplification should happen when the item leaves editable forge ownership and becomes an equip-ready/export-ready asset
- the expected future lock point is the later engraving/naming/finalization workflow
- until that lock/export workflow exists, Stage 2 should prefer edit-ready topology over aggressive simplification

Finalization cleanup law:
- once the item is locked out of shape editing, a stronger cleanup/simplification pass may run
- the preferred path remains a conservative three-pass simplification chain over the newly saved result each time
- this finalization cleanup must preserve silhouette and intended authored shape

Important distinction:
- this is not display LOD
- this is not live-edit simplification
- this is final export-side topology economy

So later optional LOD generation is additive, not a substitute for either:
- a good editable Stage 2 shell
- a clean final export shell

## 10. Full 3D Interaction Law

Stage 2 is not layer-bound.

While Stage 2 refinement is active:
- layer rules are inactive
- slice indicators are not needed
- plane/layer stepping is not part of the workflow
- interaction is always against the 3D shell/model

The only special local restrictions still allowed are Stage 1-derived protected zones, such as the grip-safe area.

Protected-handle restriction law:
- Stage 1 must export handle-worthy/grip-worthy protected regions toward Stage 2
- the Stage 2 protected-handle region should use a cylindrical restriction zone around the valid handle/grip area
- inside that restricted handle zone:
  - fillet is allowed
  - all other Stage 2 modification families are blocked by default
- this restriction must remain explicit and stable; the handle region is not a freeform edit zone

## 11. Tool Law

### User-facing model

Stage 2 tools remain a family plus modifier model:
- family = carve / fillet / chamfer / selection family
- modifier = apply / revert

Do not return to duplicated user-facing tool entries for:
- separate revert-family tools
- separate add/remove family copies

### Pointer tools

Pointer-centered tools act on a local editable region around the hit point on the unified shell.

Current intended pointer family:
- carve
- fillet
- chamfer
- revert

Runtime modifier keybind law:
- `Ctrl + Scroll` changes pointer-footprint size/radius when the current tool supports footprint/radius adjustment
- `V + Scroll` changes tool intensity or secondary shape modifier when the current tool supports that modifier
- these keybind channels must be independent from camera controls
- when one of these modifier keybinds is active in the correct editor/tool context, camera zoom must not also trigger
- these keybinds only act inside the correct editor mode and tool context

Current Stage 2 modifier meaning:
- carve:
  - `Ctrl + Scroll` = footprint radius
  - `V + Scroll` = per-pass aggressiveness
  - aggressiveness range = `0% -> 100%`
  - aggressiveness step = `5%`
- fillet:
  - `Ctrl + Scroll` = footprint radius when pointer-radius fillet behavior is active
  - `V + Scroll` = fillet radius
  - current target max fillet radius = `0.075 m`
  - fillet must support concave and convex cases
  - fillet must adapt to real adjacent surface angles, not assume perfect 90-degree corners only
- chamfer:
  - `Ctrl + Scroll` = footprint radius when pointer-radius chamfer behavior is active
  - `V + Scroll` = chamfer depth
  - current target max chamfer depth = `0.075 m`
  - chamfer must adapt to real adjacent surface angles, not assume perfect 90-degree corners only

### Selection tools

Selection tools act on topology-derived regions from the current unified shell.

Selection families can survive conceptually:
- face
- edge
- feature edge
- feature region
- feature band
- feature cluster
- feature bridge
- feature contour
- feature loop

But they must stop being driven by drifting Stage 2 quad-patch records.
They must eventually resolve from live unified-shell topology and derived region indices.

Selection rollout law:
- keep the system powerful, but do not overcomplicate the first real unified-shell pass
- Phase 4 should begin with the most useful topology families first
- additional higher-complexity families should only be carried forward if they still provide clear editing value after the unified-shell core is working
- first-pass priority order for the unified-shell rewrite is:
  - face
  - edge
  - feature region
- internal feature-edge, band, cluster, bridge, contour, and loop families are later-expansion candidates rather than mandatory first-pass deliverables

## 12. Preview Law

Purple transparent rendering is preview language only.

Use purple transparency only for:
- brush spheres
- hover previews
- selection previews
- temporary affected-area previews

The committed Stage 2 shell itself must render as:
- opaque
- material-colored
- coherent visible geometry

## 13. Target Data Model

### Keep

Keep:
- `Stage2ItemState` as the root saved Stage 2 authority on the WIP

### Add

Add a new authoritative shell resource family:
- `Stage2ShellMeshState`
  - baseline shell topology/data
  - current shell topology/data
  - local aabb / version / dirty metadata

Recommended minimum contents:
- vertex positions
- triangle indices
- per-vertex normals or rebuild metadata
- material/region assignment data
- envelope/zone association data

Add derived topology/index helpers:
- `Stage2TopologyIndexState` or similarly named derived/cache resource
  - face lookup
  - edge lookup
  - region lookup
  - neighbor/adjacency lookup

### Existing patch records

Current `Stage2PatchState` and `Stage2ShellQuadState` should no longer be treated as final visual-shell authority.

They may:
- be retired entirely
- or be reduced to temporary local region/envelope caches

But they should not remain the source of truth for final Stage 2 geometry.

## 14. File Ownership Decision

### Existing files that should remain central

- `res://core/models/crafted_item_wip.gd`
- `res://services/forge_service.gd`
- `res://core/models/test_print_instance.gd`
- `res://runtime/forge/test_print_mesh_builder.gd`
- `res://runtime/forge/crafting_bench_ui.gd`
- `res://runtime/forge/forge_workspace_preview.gd`

### New files that should be added

Recommended new files:
- `res://core/models/stage2_shell_mesh_state.gd`
- `res://core/models/stage2_topology_index_state.gd`
- `res://core/resolvers/stage2_unified_shell_generator.gd`
- `res://core/resolvers/stage2_shell_apply_resolver.gd`
- `res://core/resolvers/stage2_topology_index_resolver.gd`
- `res://core/resolvers/stage2_surface_region_resolver.gd`

### Existing Stage 2 files that should be refactored, not blindly expanded

- `res://services/forge_stage2_service.gd`
  - refactor from quad-patch generator into Stage 2 orchestration/service owner
- `res://runtime/forge/forge_stage2_brush_presenter.gd`
  - refactor from quad-origin offset edits into calls into unified-shell local apply logic
- `res://runtime/forge/forge_stage2_selection_presenter.gd`
  - refactor from quad-patch graph selection into unified-shell topology-region selection
- `res://runtime/forge/forge_stage2_preview_presenter.gd`
  - preserve as preview owner, but drive from unified-shell truth

## 15. Explicit Implementation Phases

### Phase 1 - Baseline unified shell generation

Deliver:
- one welded Stage 2 baseline shell generated from Stage 1
- saved on `Stage2ItemState`
- visible in forge/test print/player paths
- no editing yet beyond preserving current entry flow
- baseline shell already converted into an edit-ready welded surface with materially more usable topology than the raw Stage 1 face output where refinement needs it
- baseline shell ready to receive later local Stage 1 change adaptation

Required result:
- zero-edit Stage 2 visual output works
- zero-edit output is already a coherent editable shell instead of patch-grid spam
- zero-edit output is ready for later refinement without needing a separate “add more topology first” step

### Phase 2 - Unified-shell rendering handoff

Deliver:
- forge preview uses unified shell
- test print uses unified shell
- player-held render uses unified shell
- Stage 1 backend truth remains untouched

Required result:
- Stage 2 shell becomes the visible item everywhere

### Phase 3 - Local edit core

Deliver:
- local hit region acquisition on unified shell
- local carve
- local revert
- local remesh/retriangulation of edited region
- updated normals
- `Ctrl + Scroll` radius channel integrated without camera overlap
- `V + Scroll` carve aggressiveness channel integrated without camera overlap

Required result:
- visible shell shape changes become real topology, not plate sliding

### Active live implementation addendum - 2026-04-09

The following live findings are now explicitly part of the Stage 2 implementation target and must not be treated as optional polish:

- after a Stage 2 edit, the edited shell face must visually replace the old local face state instead of leaving a ghosted or onion-skin remnant of the original shell silhouette behind in the edited zone
- local Stage 2 edits must progressively stop reading as a stack of block-shaped inset plates and move toward one coherent segmented many-polygon shell surface
- carving must become camera/tool-axis directed:
  - the carve application direction must follow the camera-view axis intersecting the tool volume
  - it must not behave like an indiscriminate contact-surface-only offset pass
- new local surfaces created by deformation must become more truthful and more visibly distinct as the shell changes
- the protected handle/grip restriction is already behaving correctly and must be preserved while the geometry core changes
- `Ctrl + Scroll` and `V + Scroll` runtime modifier channels are part of the required Stage 2 interaction contract and any missing/incorrect behavior there remains active implementation debt until the live editor matches the law in Section 11

### Phase 4 - Topology indexing and selection

Deliver:
- current-shell face/edge/region topology index
- topology-aware selection sets
- current working surface becomes the next selectable surface
- start with the most useful families first instead of reproducing every prototype selection family immediately

Required result:
- newly formed surfaces are truly targetable later
- first-pass unified-shell selection remains powerful without rebuilding the entire prototype selection tree on day one

### Phase 5 - Fillet and chamfer

Deliver:
- fillet and chamfer rebuilt on top of the unified-shell edit core
- no longer just offset-to-limit operations
- `V + Scroll` fillet radius channel
- `V + Scroll` chamfer depth channel
- angle-aware concave/convex handling
- protected-handle restriction support where only fillet remains valid

Required result:
- curvature/transition tools form actual new surface geometry

### Phase 6 - Final export cleanup and topology economy

Deliver:
- export-side coplanar/near-coplanar cleanup where safe
- reduce redundant detail without changing intended shape
- no aggressive live-edit simplification while the item remains forge-editable
- stronger save/finalize cleanup for the finished locked/export-ready asset
- save/finalize cleanup runs as a conservative three-pass simplification chain over the newly saved result each time

Required result:
- the editable shell stays coherent and responsive without sacrificing needed topology density during authoring
- save/finalize produces a cleaner final shell than the dense live editing shell
- the stronger finalization cleanup remains conservative enough that simplification error does not compound into visible breakage across the three passes

### Phase 7 - Future child paint stage prep

Deliver later:
- leave Stage 2 output ready to become the input for a later paint/recolor/retexture child stage

## 16. Handoff Rules

### ForgeService

`ForgeService.build_test_print_from_wip()` should continue to:
- bake Stage 1 gameplay/profile truth from Stage 1 authored data
- package Stage 2 visual shell for display if present

### TestPrintInstance

`TestPrintInstance` should carry both:
- Stage 1 gameplay authority
- Stage 2 visual-shell authority

### PlayerEquippedItemPresenter

The player-held visual should come from Stage 2 shell output.

Important later follow-up:
- any backend bounds/helper logic that should remain Stage 1-owned must not accidentally switch to Stage 2 visual geometry if that would blur the authority split
- Stage 1-derived geometry may still be branched into independent visual/collision/hurt downstream uses without changing the Stage 1 authority split

## 17. Acceptance Criteria

This Stage 2 rewrite is only considered correct when all of the following are true:

1. Entering Stage 2 always shows one coherent opaque model shell.
2. The visible model shell is derived from Stage 1 even when the player makes zero refinement edits.
3. Carve/revert visibly alter real shell topology, not overlapping flat plates.
4. Fillet/chamfer create actual new surface form.
5. Newly formed surfaces become valid future targets.
6. Stage 2 remains full 3D and non-layer-bound.
7. Stage 1 grip logic remains authoritative.
8. Stage 1 gameplay/profile/material truth remains authoritative.
9. Test print and player-held runtime visuals show Stage 2 shell output.
10. The editable Stage 2 shell keeps enough usable topology for later shaping and is not prematurely collapsed just because a region is still untouched.
11. Live editing/remeshing keeps the shell coherent without destructive simplification while the item remains forge-editable.
12. Save/finalize performs a stronger simplification pass only after shape editing is locked, without breaking intended silhouette or shape.
13. Zero-edit Stage 2 baseline is already a welded edit-ready shell instead of patch-grid spam and does not require a separate topology-creation step before refinement begins.
14. Stage 2 adapts locally when Stage 1 changes later instead of resetting blindly whenever local reconciliation is possible.
15. `Ctrl + Scroll` and `V + Scroll` modifier channels operate independently from camera zoom in the correct tool context.
16. Protected handle/grip zones export from Stage 1 and only permit fillet inside the restricted cylindrical region.
17. Edited shell regions do not leave a ghosted original shell remnant visible behind the new local surface.
18. Carve direction follows the camera/tool axis through the brush volume instead of behaving like a flat contact-only inset.

## 18. Explicit Non-Goals For This Pass

Do not expand the next implementation pass into:
- Stage 2 combat semantics
- cutting-edge/blunt classifiers
- ranged projectile logic
- magic effect logic
- paint/recolor/retexture editing
- final export pipeline polish

These are separate later concerns.

## 19. Current Main Risk To Avoid

Do not keep iterating the current quad-offset prototype as if it will naturally become the final unified-shell system.

That would create more patching, not more truth.

The correct next implementation branch is:
- unified shell generation
- unified shell storage
- unified shell local remeshing
- topology-aware refinement on that shell

That is the locked Stage 2 direction.

## 20. Resolved Gate Decisions

The earlier gates are now resolved as follows:

### Gate A - Baseline shell character

Locked:
- zero-edit Stage 2 should already be welded and edit-ready before any manual edits exist
- flat Stage 1 shapes should resolve to one coherent shell with enough usable surface density for later refinement
- the baseline shell is for editing readiness and runtime visual output at the same time
- if Stage 1 later changes locally, Stage 2 should adapt that local zone while preserving compatible nearby Stage 2 edits where possible

### Gate B - Local edit behavior profile

Locked:
- `Ctrl + Scroll` = footprint/radius channel
- `V + Scroll` = intensity/secondary modifier channel
- carve aggressiveness uses `0% -> 100%` with `5%` steps
- fillet radius and chamfer depth are independently adjustable through the `V + Scroll` channel
- current target max for fillet radius = `0.075 m`
- current target max for chamfer depth = `0.075 m`
- fillet and chamfer must both adapt to concave/convex and non-perfect-angle situations

### Gate C - Final selection family scope

Locked:
- keep the system powerful, but do not overcomplicate the first real unified-shell pass
- Phase 4 begins with the most useful families first
- higher-complexity selection families expand later only if they still provide clear value once the unified-shell core is working

### Gate D - Save/finalize cleanup aggressiveness

Locked:
- finalization cleanup should simplify as much as possible without breaking intended geometry
- this simplification belongs to the final export/lock side of the process, not the live forge-editing side
- the preferred finalization path is a conservative three-pass cleanup/simplification chain
- each pass works from the newly saved/simplified result of the previous pass
- the cleanup algorithm must remain conservative enough that simplification damage does not compound across passes

### Gate E - Stage 1 combat containment

Locked:
- Stage 1-derived geometry may branch into:
  - Stage 2 visual base
  - collision shape
  - hurt shape
- this keeps one truthful Stage 1-derived shape feeding modular downstream uses
- simpler containment primitives remain fallback options, not the preferred first assumption
