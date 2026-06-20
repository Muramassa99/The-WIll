Note: use debugging.md alongside this file. plan.md is for sequencing and checkpoints; debugging.md is for symptoms, root causes, fixes, validation, and repeated-mistake avoidance.


## Menu Direction Checkpoint: 2026-03-24

Use GDD-and Text Resources/UPLOADED/menu system inspiration.md as the active design-direction anchor for the in-game Escape menu. Current implementation already has a partial persistent settings overlay and action-based input categories, but the next menu pass should reshape it toward the locked shell from that note: left navigation, right content panel, top-level pages Resume/Settings/Controls/Interface/Social/Help/Return to Title/Quit, online-safe non-pausing overlay behavior, and a broader data-driven category tree rather than a single compact settings panel.

Immediate implication: do not keep extending the current simple tabbed overlay as the final form by inertia. Treat it as scaffolding to migrate into the control-room overlay structure described in the inspiration note.

## Menu Increment Plan: 2026-03-24

Break the menu task into small vertical slices instead of one broad system pass.

Order for implementation:
1. Stabilize current bootstrap and confirm startup/input-map safety only.
2. Make Escape open/close the overlay reliably without breaking existing interactable Escape behavior.
3. Finish Display settings only: window mode, resolution, VSync, render scale, persistence.
4. Finish Interface sizing only: UI scale and global text scale persistence.
5. Finish Controls only for currently live actions: movement, interface/menu, Forge.
6. Add defaults/reset behavior for the currently live bindings/settings.
7. Reshape the overlay shell from temporary tabs into the left-nav/right-panel layout from the inspiration note.
8. Expand into later families only after the above slices are stable.

Execution rule for menu work:
- one slice at a time
- no more than a few touched files per pass when possible
- validate startup after each slice
- do not combine shell redesign with settings-logic expansion in the same pass

---


---

## Debug Checkpoint: 2026-03-24 Runtime Error Audit

User reports current Godot project cannot be run from executable due to active red runtime/load errors. Before changing code, preserve current forge/naming/workflow progress and audit the active error set. Priority is to identify true blockers first, then fix in order without inventing missing design details.

---


## Resume Checkpoint: 2026-03-23 End Of Day

Current active intent:
- Continue the forge-first vertical slice without losing the explicit split between forge-side temporary project metadata and later finalized item naming.
- Preserve the data-driven/resource-driven approach: authored defs in shared `.tres`, save-backed/player-owned mutable state in models, volatile interaction state in controllers/UI.

What was completed in the latest pass:
- Added forge project duplicate/delete actions to the dedicated project panel.
- Added `forge_project_notes` to `CraftedItemWIP` as forge-only temporary draft metadata.
- Extended `PlayerForgeWipLibraryState` with save-backed duplicate/delete support.
- Added minimal finalized-name/provenance fields to `FinalizedItemInstance` so final naming remains a separate later authority boundary.
- Cleaned current forge-path warning debt in active files:
  - `ForgeWorkspacePreview` no longer uses invalid `MultiMesh.COLOR_8BIT`.
  - `ForgePlaneViewport` no longer shadows `draw_rect` with locals.
  - preload constants renamed where they collided with global class names in reload warnings.
- Updated the main implementation note and repo memory accordingly.

Important current truth:
- `forge_project_name` and `forge_project_notes` are forge-only temporary WIP metadata.
- They must never silently become the final item name.
- Final naming/export flow is still pending and should route through `FinalizedItemInstance`, not through WIP project labels.

Validation state at stop:
- Follow-up completed on 2026-03-24: the updated headless verifier now passes. The blocker was a parse error in `verify_forge_wip_library.gd` caused by `String(bool)`; changing that line to `str(deleted_duplicate)` resolved it. Fresh artifact confirmed notes persistence plus duplicate/delete behavior.

- Editor diagnostics were clean on all touched files.
- Fresh headless verifier artifact now confirms saved-id persistence, forge project name persistence, forge notes persistence, and correct duplicate -> delete behavior.
- Local Godot console executable path that worked in this workspace: `C:\WORKSPACE\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe`.

Most likely next steps when resuming:
1. Re-run the updated headless verifier and confirm fresh output for notes + duplicate/delete persistence.
2. Start the real naming-station/finalization flow using `FinalizedItemInstance` as the export boundary.
3. Continue replacing the provisional bench presentation with the intended forge workstation shell while preserving the current project-panel behavior.

---


## Plan: Parity Alignment And Visual Forge UI

Correct the planning baseline first, then define the visual forge implementation in much greater detail before any more UI coding. The corrected baseline is: the first forge slice architecture exists, the runtime bench/player loop is a working test harness, mass and center_of_mass are genuinely live, but grip-dependent profile behavior is only partially realized because upstream segment geometry metadata is not yet computed. The next implementation direction remains a dedicated forge authoring viewport, and the immediate planning focus is the visual/editor shell for that viewport.

**Steps**
1. Establish the corrected 1-to-1 planning baseline:
- Treat materials, cells, WIP editing, bake orchestration, mass, center_of_mass, the runtime bench, and the visible preview path as genuinely live.
- Treat primary grip validation, reach/front_heavy_score/balance_score in practical runtime use, and the remaining profile score fields as only partially realized.
- Do not plan future UX as though the full profile system is already active.

2. Freeze the visual implementation goal before more feature additions:
- The forge editor is a dedicated overlay workspace opened from the bench.
- It is not a player-body tool and not an inventory-like menu.
- It should read as a windowed 3D authoring interface inside the game.
- The viewport is the main workspace and all surrounding UI exists to support editing inside that viewport.

3. Define the editor shell as a five-region layout that should remain stable across later slices:
- Top bar
- Left sidebar
- Center viewport
- Right sidebar
- Bottom summary strip
This is the layout skeleton the next coding pass should build first.

4. Define the visual hierarchy precisely:
- Center viewport is dominant and should occupy roughly 60 percent of the width.
- Left sidebar is secondary and should primarily hold material and tool context.
- Right sidebar is secondary and should primarily hold layer and selection state.
- Bottom strip is tertiary and should show compact result/status data.
- The top bar is utility/navigation, not content-heavy.

5. Define the center viewport region in detail:
- This region hosts the dedicated forge 3D scene.
- It contains the shadow grid, hover highlight, occupied cells, active-layer context, and preview/test-print display.
- The viewport should feel like a focused workspace rather than a decorative 3D embed.
- Empty cells should be visible but visually quiet.
- Occupied cells should be visually stronger than empty cells.
- The hovered cell should be the clearest short-term highlight.
- The active layer should be visually dominant over neighboring layers.
- Ghosted neighboring layers should remain visible enough for spatial context.

6. Define the top bar content in detail:
- Left side: editor identity, such as Forge or Forge Workbench.
- Center-left: current WIP name or placeholder label.
- Center-right: active material and active tool quick indicator.
- Right side: Bake, Reset, Close/Return controls.
- Reserve future space for Save, Load, Clear, Undo/Redo, but do not overload the first slice.
- The top bar should stay shallow and functional.

7. Define the left sidebar in detail:
- Section 1: material palette.
- Material entries should be driven by the actual material defs, not hardcoded fake paint swatches.
- Each entry should show: material name, color cue, and selection state.
- Section 2: active material card.
- This card should show the selected material’s name and a compact summary of why it matters later, such as density as the first live truth.
- Section 3: reserved tool palette area.
- First visible tools can be Place and Erase.
- Reserve visual space for later brushes such as Fill, Chamfer, Round, and other rule-driven tools.

8. Define the right sidebar in detail:
- Section 1: active layer controls.
- Show current layer index clearly.
- Provide layer up and layer down actions.
- Provide a visibility mode indicator such as Active Only or Ghost Adjacent.
- Section 2: hovered cell / selected cell details.
- Show grid coordinate.
- Show layer.
- Show current occupant material if any.
- Section 3: reserved brush settings area.
- Reserve labeled space for future brush radius, shape, and mode settings even if the first slice does not activate them.
- This panel should answer: where am I editing and what will my next action affect?

9. Define the bottom strip in detail:
- Replace long diagnostic text as the default visual mode.
- Default state should be compact summary-first.
- Show: validation state, active cell count, active layer, selected material, last bake result, and 2-4 key baked values.
- Recommended first baked values for compact display: total_mass, center_of_mass, primary_grip_valid, validation_error.
- Keep a reserved expandable details area for the longer text dump later, but do not make that the default presentation.

10. Define the visual language for states:
- Active material: clear highlighted swatch/button state.
- Hovered cell: bright outline or glow.
- Occupied cell: solid readable fill.
- Empty cell: subdued grid/shadow cube.
- Active layer: strong opacity and contrast.
- Ghosted adjacent layers: lower opacity and lower contrast.
- Validation OK: calm positive color cue.
- Validation failed: clear warning/error cue.
This state language should be decided now so later interactions inherit a consistent visual system.

11. Define the recommended scene/layout responsibilities for the eventual implementation:
- Bench world scene remains only the access point.
- Forge editor UI scene owns the layout shell.
- Dedicated forge viewport scene owns the 3D editing space.
- Forge controller bridge continues handling active WIP and bake requests.
- The preview/test-print display remains connected to the existing bake path rather than becoming a separate fake view.

12. Define what is intentionally not part of this immediate visual slice:
- Exact camera interaction behavior beyond reserved space/affordance.
- Full viewport picking logic.
- Continuous paint strokes.
- Chamfer and rounding behavior.
- Full profile/capability display breadth.
These should be added after the shell exists, not before.

13. The next implementation slice after layout should be: wire the dedicated viewport into the center region while keeping the panel structure fixed. Only after that should material placement, layer navigation, and hover picking be added into the already-frozen shell.

**Relevant files**
- `c:\WORKSPACE\GDD-and Text Resources\UPLOADED\CURRENT STATE OF THE WILL - IMPLEMENTATION MEMORY.md` — current living state file that should be mentally corrected by the parity note while planning
- `c:\WORKSPACE\GDD-and Text Resources\UPLOADED\quirky-cuddling-mochi.md` — first-slice authority
- `c:\WORKSPACE\GDD-and Text Resources\UPLOADED\DECISION_LEDGER_FIRST_SLICE.md` — first-slice decision boundary source
- `c:\WORKSPACE\The Will- main folder\the-will-gamefiles\runtime\forge\crafting_bench_ui.gd` — current temporary bench UI logic to be replaced/restructured
- `c:\WORKSPACE\The Will- main folder\the-will-gamefiles\scenes\ui\crafting_bench_ui.tscn` — current temporary panel scene likely to become the shell starting point or be replaced
- `c:\WORKSPACE\The Will- main folder\the-will-gamefiles\runtime\forge\crafting_bench.gd` — in-world access point that should launch the editor shell
- `c:\WORKSPACE\The Will- main folder\the-will-gamefiles\runtime\forge\forge_grid_controller.gd` — controller bridge for active WIP and bake actions
- `c:\WORKSPACE\The Will- main folder\the-will-gamefiles\services\forge_service.gd` — existing bake path that visual UI should continue to surface honestly
- `c:\WORKSPACE\The Will- main folder\the-will-gamefiles\core\models\crafted_item_wip.gd` — authored forge state model
- `c:\WORKSPACE\The Will- main folder\the-will-gamefiles\core\atoms\layer_atom.gd` — layer structure that must become visible in the right sidebar model
- `c:\WORKSPACE\The Will- main folder\the-will-gamefiles\core\atoms\cell_atom.gd` — cell authored truth that the viewport will eventually edit
- `c:\WORKSPACE\The Will- main folder\the-will-gamefiles\node_3d.tscn` — current sandbox host scene that still contains the bench entry flow

**Verification**
1. The planning baseline should no longer assume full grip-dependent profile behavior is already live.
2. The forge editor shell should have a stable five-region layout before new editing behavior is added.
3. The viewport should clearly read as the dominant workspace at first glance.
4. Materials should have an obvious home in the left sidebar.
5. Layer and hovered/selected state should have an obvious home in the right sidebar.
6. Bake/reset/close should live in the top bar, not scattered across the UI.
7. The bottom strip should summarize the most important state without relying on a long scrolling text block.
8. The layout should preserve visual room for future tools so later additions fit inside the shell without another redesign.

**Decisions**
- Immediate fix for alignment: planning will treat the current state document as directionally correct but not fully 1-to-1 for grip-dependent runtime behavior.
- Immediate implementation focus: visual forge shell before more behaviors.
- Recommended UI priority order: viewport first, left material/tool context second, right layer/state context third, bottom summary fourth.
- Recommended default presentation: compact tool workspace, not long diagnostics, not inventory-style menu, not pause-screen styling.
- Deferred until after shell exists: exact camera controls, picking behavior, paint strokes, shaping tools.

**Further Considerations**
1. The current long output text can survive as a collapsible details mode later, but it should not define the default forge editor presentation.
2. If the shell is built correctly first, later behavior can be slotted into already-reserved regions instead of causing another visual redesign.
3. Because the forge tool is an authoring workspace, clarity of regions and state cues is more important than decorative flourish in the first pass.
4. For planning purposes, future visual work should assume mass and center_of_mass are live, but should not visually over-promise grip-dependent outputs until upstream geometry metadata is real.
