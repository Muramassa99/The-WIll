# Structural Volume Authoring System

## Repo-aligned design note

This document is not a blueprint for a separate `stage1_*` subsystem.

It is a repo-aligned note for how structural authoring tools should be folded into the already existing crafting bench / forge workflow.

The current structural authoring system already exists.
This note defines how to extend it without breaking its authority.

---

## 1. What this system is

This is the **pre-Stage-2 structural authoring layer** of the crafting station.

It is where the player:

- places material mass
- removes material mass
- establishes the parent form
- defines the gameplay-truthful block structure

This layer stays:

- block-authored
- structural
- gameplay-truthful
- pre-refinement

Stage 2 still comes later and remains the refinement layer.

---

## 2. Current live authority

The current structural authoring authority is already present in the forge bench.

Current live ownership:

- `runtime/forge/crafting_bench_ui.gd`
  - top-level bench UI shell and tool routing
- `runtime/forge/forge_bench_menu_presenter.gd`
  - top menu action routing
- `runtime/forge/forge_plane_viewport.gd`
  - plane-view pointer surface and stroke signals
- `runtime/forge/forge_workspace_interaction_presenter.gd`
  - live input interpretation and plane/workspace interaction routing
- `runtime/forge/forge_workspace_edit_action_presenter.gd`
  - structural place/remove/pick action path
- `runtime/forge/forge_grid_controller.gd`
  - active WIP/grid/session authority
- `core/models/crafted_item_wip.gd`
  - authored structural cell truth

That existing path remains authoritative.

---

## 3. Core law

The already in use freehand cell-by-cell system is the correct base system.

Do not replace it.
Do not bypass it.
Do not build a second structural write path beside it.

The next phase should replicate that exact system pattern, but with a larger resolved footprint.

Meaning:

- same material rules
- same add/remove rules
- same plane/layer rules
- same WIP/save/autosave flow
- same refresh path
- same validation path

Only this changes:

- the footprint of targeted cells

So the mental model is:

- freehand = single-cell or dragged-cell footprint
- shape tool = predefined multi-cell footprint using the same write path

---

## 4. Existing live structural tools

Current live structural tools are:

- freehand draw / place
- freehand erase / remove
- pick

Current live behavior already supports:

- single click placement/removal
- click-hold drag placement/removal
- active plane/layer constrained authoring

That behavior should remain intact.

---

## 5. New tool family

This document covers **shape-footprint structural tools** to be integrated into the current forge bench.

These are not a separate crafting system.
They are not a CAD replacement.
They are not Stage 2.

They are structural speed tools layered on top of the existing structural authoring path.

Current candidate family:

- rectangle
- circle
- oval
- triangle

Modes:

- add
- remove

The correct interpretation is:

- these are potential tools to integrate into the current crafting system
- they should be added one by one
- they should use the same structural commit path as freehand

---

## 6. Shape-tool law

Every structural shape tool must:

- operate on the active work plane/layer
- resolve a truthful footprint on that plane/layer
- feed the same placement/removal logic already used by freehand
- stay saved as normal structural cell truth on the WIP

They must not:

- write a separate geometry format
- bypass material consumption/return logic
- bypass placement/removal validity
- pretend to be Stage 2 refinement

---

## 7. Tool behavior intent

### Rectangle

Purpose:

- broad flat structural regions
- fast straight-edged mass establishment

Current first live pass:

- plane-view only
- drag-defined axis-aligned rectangle footprint
- uses the same structural write path as freehand
- current live path now uses the shared structural shape rotation slot

Inputs:

- size A
- size B
- rotation

Modes:

- add
- remove

### Circle

Purpose:

- circular structural regions
- rounded ends / disks / foundations

Inputs:

- radius
- shared structural shape rotation slot

Current live note:

- circle reads the same shared rotation slot as the other structural shapes
- in the current 90-degree first pass, circle footprint stays equivalent under quarter-turn rotation

Modes:

- add
- remove

### Oval

Purpose:

- elongated rounded structural regions
- faster curved silhouettes than freehand alone

Inputs:

- size A
- size B
- rotation

Modes:

- add
- remove

### Triangle

Purpose:

- triangular structural regions without forcing only a right-angle-first workflow

Inputs:

- route A: side A, side B, included angle
- route B: angle A, angle B, base length
- current first live pass uses drag-defined triangle footprint plus the shared structural shape rotation slot

Modes:

- add
- remove

Triangle stays split into two valid input routes.
That keeps it flexible without making it contradictory.

---

## 8. Preview law

The preview must be truthful to the actual structural result.

If a cell will be hit, preview should indicate it.
If a cell will not be hit, preview should not imply it.

That applies to:

- freehand
- rectangle
- circle
- oval
- triangle

No decorative preview disconnected from real effect.

---

## 9. UI law

These tools should be absorbed into the existing forge bench UI direction.

That means:

- top-menu / dropdown driven
- no return to a large side-panel dependency
- shape parameters shown only where needed
- no fake “new modeling app inside the game” behavior

The bench should still read as one authoring system with multiple tool footprints.

---

## 10. Save / load law

Shape tools do not need their own separate save format.

What gets saved is still:

- the resulting structural cell state on the WIP

Optional future saveable helper state may exist for:

- current selected shape tool
- current shape parameters
- reusable presets

But structural truth still lives in the same WIP data path.

---

## 11. Correct repo-shaped placement

Do not build this as a generic `stage1_*` island.

Correct repo-aligned ownership should stay under existing forge naming and responsibility boundaries.

Likely ownership split:

- `runtime/forge/crafting_bench_ui.gd`
  - bench shell and tool/menu wiring
- `runtime/forge/forge_bench_menu_presenter.gd`
  - menu action routing for shape tools
- `runtime/forge/forge_plane_viewport.gd`
  - plane-view input and truthful 2D footprint preview surface
- `runtime/forge/forge_workspace_interaction_presenter.gd`
  - active pointer / hold / layer interaction flow
- `runtime/forge/forge_workspace_edit_action_presenter.gd`
  - same structural commit path as freehand
- `runtime/forge/forge_grid_controller.gd`
  - WIP/grid authority remains unchanged

If new dedicated files are added later, they should follow forge naming, for example:

- `forge_workspace_shape_tool_presenter.gd`
- `forge_workspace_shape_profile_solver.gd`
- `forge_workspace_shape_rasterizer.gd`
- `forge_workspace_shape_preview_presenter.gd`

Those are extensions of the forge workspace system, not a separate subsystem.

---

## 12. Implementation law

The correct technical chain is:

1. resolve pointer/context on the active plane/layer
2. resolve the active footprint for the chosen tool
3. rasterize that footprint into target cells
4. send those target cells into the same structural commit path as freehand
5. refresh the current live bench view the same way as existing edits

Only the footprint-resolution layer changes.

The structural commit layer stays the same.

---

## 13. Recommended implementation order

Recommended order:

1. rectangle
2. circle
3. oval
4. triangle
5. shared rotation slot across all structural shape tools

Current live progress:

- rectangle first pass is now live
- circle first pass is now live
- oval first pass is now live
- triangle first pass is now live
- shared structural shape rotation slot is now live
- current live rotation scope is shared quarter-turn rotation (`0° / 90° / 180° / 270°`) across the structural shape family
- future work is richer shape-specific parameterization on top of that shared slot, not separate rotation rewrites per shape

Rectangle comes first because it is easiest to validate against the current freehand logic.

First pass rules:

- plane-view first
- truthful preview first
- same structural write path
- same autosave safety law
- no new save format

---

## 14. Relationship to Stage 2

This system remains pre-Stage-2.

Meaning:

- structural tools create or remove block truth
- Stage 2 reads that block truth later and refines the outer shell

Do not let structural shape tools drift into refinement behavior.
Do not let Stage 2 replace structural authorship.

The handoff stays:

- structural authoring first
- refinement second

---

## 15. Final summary

This document should now be read as:

- a repo-aligned list of structural authoring tools to integrate into the existing crafting bench
- not a separate Stage 1 subsystem
- not a replacement for freehand

The governing law is:

> keep the current freehand structural system as authority, and add larger tool footprints that feed the same placement/removal path

That is the correct direction.

---

## 16. Layer Sweep Authoring

This is now a live first-pass behavior in the existing crafting bench.

### Name

- `layer sweep authoring`

### Meaning

- simultaneous held structural placement/removal plus continuous held layer stepping

### Current live first pass

- current live scope is plane-view structural authoring
- hold mouse = continuous draw or erase, same as existing freehand behavior
- hold `Q` or `E` = continuous layer stepping, same as existing layer hold behavior
- when both are active together, the current footprint is applied once on each newly entered layer
- current first pass intentionally excludes `pick`

### Intended behavior

- hold mouse = continuous draw or erase, same as current freehand behavior
- hold `Q` or `E` = continuous layer stepping, same as current layer hold behavior
- if both are active together, the current footprint should be applied once on each newly entered layer

This should work for:

- freehand footprints
- current `rectangle` drag footprints
- current `circle` drag footprints
- current `oval` drag footprints
- current `triangle` drag footprints

This should not apply to:

- pick

Current live note:

- this now applies across both freehand and the current structural shape drag family
- current structural shape sweep still uses the same structural commit path as ordinary shape drag
- current live structural shape sweep is verified for:
  - `rectangle`
  - `oval`

### Core law

Layer sweep authoring is not a separate system.
It is the simultaneous use of two already valid systems:

- held structural authoring
- held layer stepping

### Safety rules

- do not apply multiple times on the same layer just because the key is still held
- consume/return material through the normal structural commit path
- respect the same placement/removal validity used by ordinary authoring
- first pass should stay plane-view oriented where layer truth is clearest

### Likely file references

- `runtime/forge/crafting_bench_ui.gd`
  - current shell wrappers for layer hold and tool flow
- `runtime/forge/forge_workspace_interaction_presenter.gd`
  - current live layer-hold repeat behavior
- `runtime/forge/forge_plane_viewport.gd`
  - current held plane stroke signaling
- `runtime/forge/forge_workspace_edit_action_presenter.gd`
  - current structural commit path
- `runtime/forge/forge_grid_controller.gd`
  - active layer / WIP authority

### Implementation note

The clean path is:

1. keep current hold-place / hold-remove behavior
2. keep current held `Q` / `E` layer stepping
3. when the active layer changes during an active structural hold, apply the current footprint once on the newly entered layer

That is now the current first-pass implementation target and live behavior.

## Current UI Contract

Structural placement tools in the crafting bench should be understood as:

- selected footprint family:
  - `freehand`
  - `rectangle`
  - `circle`
  - `oval`
  - `triangle`
- shared structural modifier:
  - `Add`
  - `Remove`
  - `Pick`

Do not treat the footprint tools as separate add/remove tool entries.
The footprint family stays selected while the global modifier changes.
