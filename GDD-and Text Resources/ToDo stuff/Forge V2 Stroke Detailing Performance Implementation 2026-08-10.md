# Forge V2 Stroke, Detailing, And Performance Implementation

Created: 2026-08-10 Europe/Bucharest
Workspace: `C:\WORKSPACE`
Project: `C:\WORKSPACE\The Will- main folder\the-will-gamefiles`
Branch: `godot-4.7-plus-development`

## Recovery Baseline

The safe pre-change checkpoint is:

```text
commit: 40f5048fbf6dbc6ca42750da7224364b98e34274
subject: Save Forge V2 profile deposition before stroke and detailing overhaul
```

This note is a task contract and implementation tracker. It is not an SPS, a
Git checkpoint, or proof that the items below are implemented.

## Locked User Decisions

### Top-Level Forge Menus

- The top-level actions are Draft, Build, Material, Shape, Profiles, Layers,
  View, Status, and Settings.
- Clicking a different top-level action closes the currently open top-level
  popup tree and opens the requested one.
- This is an explicit workflow exception to the earlier X-only major-workspace
  closure rule.
- Alt-tab or application focus loss must not dismiss a major workspace.
- Right-click temporary menus keep their existing smallest-layer behavior.
- Selecting a saved Basic profile from
  `Shape -> 2D Profiles -> Saved Profiles` applies the fixed Shape snapshot,
  closes the Shape popup tree, and returns input ownership to the Forge
  workspace.
- Editing a saved profile does not update an already selected Shape snapshot.
  The edited profile is used only after the user explicitly reselects it.

### Volume Stroke Smoothing

- Smoothness `0` preserves direct/current input semantics.
- Smoothness `1..10` is a real delayed freehand stabilizer, not face-normal
  smoothing and not a cosmetic value.
- Raw mouse input is resampled at a deterministic fixed cadence in screen
  space. Stabilized screen samples are then raycast to the actual target so a
  curved surface is not replaced by an averaged chord through its interior.
- Higher values use more buffered history/lookahead, visibly trail the cursor,
  and remove more hand jitter.
- Mouse release stops new raw input but does not discard the tail. Remaining
  buffered samples drain in order and the exact final valid release sample is
  emitted once before commit.
- A drained batch should cause one authoritative state/presentation update,
  not one global refresh per buffered sample.
- Surface wrapping and hand-motion smoothing share a path pipeline but remain
  separate responsibilities. The final path must preserve real per-sample
  surface normals.

### Spline Line And Detailing Brush

- Existing Spline Line remains the structural/free-space authoring mode.
- Surface Aware Spline is the implementation name for the future visible
  `Detailing Brush`.
- Detailing Brush control dots are pass-through constraints on a valid target
  surface. The resolved curve must pass through every dot and remain in
  continuous contact with the same connected material/base surface.
- The base authoring plane and existing deposited material are valid targets.
- Detailing Brush does not jump voids or guess a bridge between disconnected
  objects. An invalid span is refused/marked invalid and Generate is disabled;
  it is never silently rerouted.
- Dragging a surface-aware control point updates its position and normal
  atomically and revalidates adjacent spans. A miss keeps the last valid point.
- Persist the final authoritative sampled path and normals so reopening a WIP
  cannot reinterpret it under different curve code.
- The saved profile red-dot anchor follows this surface path. The existing
  minimum `0.0005 m` contact overlap remains intentional.

### Protected Handle Authority

- Handle volume has material-composition priority over all other material and
  over VOID.
- Incoming additive material may attach to and overlap a Handle, but overlapping
  occupancy remains Handle material. The incoming material fills only empty
  space outside the protected Handle volume.
- Replace Existing is locally overridden by Fill Void wherever an operation
  intersects protected Handle occupancy. Outside that occupancy, the selected
  placement policy still applies.
- VOID/subtraction may remove ordinary surrounding material but cannot remove,
  replace, shorten, or deform Handle occupancy.
- Handle editing/redrawing, plus later explicit Handle extension/shortening
  operations, are the only authorities allowed to change Handle geometry.
- Detail material contributes to the continuous visible/collision shell but
  does not inherit or expand Handle/grip authority.
- Grip validity, interval, axis/frame, and future hand/finger placement read the
  protected authored Handle geometry even if additive detail visually engulfs
  it.
- Forge V2 does not inherit Stage 1's old air-gap/exposed-wood Handle rule.

## Current Code Findings Before This Pass

- The Freehand Smoothing slider is stored but has no drawing-path consumer.
- Every accepted mouse sample currently normalizes the growing body, emits a
  global authoring-state signal, rebuilds broad UI, and recreates active CSG.
- Saved-profile curve orientation currently performs a nearest-source-segment
  normal scan for every curve point. On a freehand polyline this is quadratic
  per rebuild and is repeated while the path grows.
- Stroke release synchronously performs repeated full material-volume resolves
  through layer delta, ledger rebuild, and material-usage refresh, then rebuilds
  a connected static CSG zone with collision.
- Current Spline point dragging uses a camera-facing plane and does not update
  the point's stored surface normal.
- Current Spline legality checks only point count/nonzero length; an auto curve
  can pass through existing material.

## Godot 4.7 Research Constraints

- Official `CSGShape3D` documentation says CSG nodes have significant CPU cost,
  are intended for prototyping, and recommends baking final results to static
  mesh/collision. CSG mesh updates are deferred by a rendered frame.
- `CSGShape3D.calculate_tangents = false` can slightly reduce generation cost
  when normal/height maps are not needed during authoring preview.
- Official Input documentation recommends disabling accumulated input while
  freehand drawing when precise input is required. This should be scoped to an
  active stroke and restored afterward, not changed globally forever.
- `Curve3D` maintains a baked cache. `tessellate()` provides curvature-adaptive
  samples and `tessellate_even_length()` bounds neighboring sample distance;
  subdivision depth must remain bounded.
- Godot's procedural geometry guidance identifies `ArrayMesh`/`SurfaceTool` for
  generated geometry and `ImmediateMesh` for simple frequently changing
  geometry. All documented procedural mesh generation is CPU-side.

Official references:

- `https://docs.godotengine.org/en/4.7/classes/class_csgshape3d.html`
- `https://docs.godotengine.org/en/4.7/classes/class_curve3d.html`
- `https://docs.godotengine.org/en/4.7/classes/class_input.html`
- `https://docs.godotengine.org/en/4.7/tutorials/3d/procedural_geometry/index.html`

## Implementation Order

1. Top-menu sibling closure and close-after-Shape-selection behavior.
2. Deterministic isolated screen-space stabilizer with focused tests.
3. Batched controller/state append API and one update per stabilizer batch.
4. Integrate stroke-time input accumulation ownership and release-tail drain.
5. Remove repeated full release resolution by reusing authoritative before/after
   summaries and applying the committed layer delta once.
6. Replace nearest-segment normal scans with aligned/direct sampled normals
   wherever path and normal indices share authority.
7. Introduce a lightweight live swept-profile preview; reserve authoritative
   CSG/volume/collision work for bounded update/commit points.
8. Extract one shared path sampler for preview, material resolution, legality,
   and persistence.
9. Add explicit free-space versus surface-aware spline state; fix stale normal
   updates; implement connected-surface legality for Detailing Brush.
10. Enforce protected Handle occupancy in the authoritative material resolver,
    then make visual CSG composition follow the same priority.

## Verification Targets

- Menu sibling closure, Profiles/Settings replacement, Shape selection closure,
  alt-tab persistence, Escape order, and RMB regression.
- Stabilizer determinism under different raw event frequencies, level `0`
  direct behavior, monotonic output order, bounded memory, and exact final
  endpoint after release drain.
- Batched append produces the same ordered point/normal pairs as single append
  with one authoring-state update.
- Instrumented release proves resolver pass count and live CSG rebuild count do
  not scale one-for-one with raw mouse events.
- Flat and changing-normal Volume Stroke, off-center anchor, rotation bias, and
  WIP/body/layer roundtrip regressions.
- Free-space Spline remains unrestricted; surface-aware mode rejects missed or
  disconnected spans and preserves surface normals after drag.
- Add/replace/VOID against protected Handle occupancy leaves the Handle cells
  and Handle semantic interval unchanged while allowing attached material
  outside the protected volume.

## Honest Boundary At Creation

None of today's new behavior is claimed implemented by this note. The baseline
commit is green for saved Basic-profile deposition. Interactive performance,
surface wrapping, Detailing Brush legality, and protected Handle composition
remain the implementation/test work begun after this document.

## Wrap-Up Status

Implementation proceeded after the recovery baseline and is recorded in
`GDD-and Text Resources/SPS/SPS_2026_08_10_22-49.md`. The current working tree
contains the menu-flow change, real freehand stabilization, lightweight live
sweep preview, incremental committed-volume cache, protected Handle composition,
and the first strict same-surface Detailing Brush. Focused automated verification
is green. Interactive visual and frame-time testing remains the next authority;
in particular, final native static CSG/collision commit cost is not claimed
solved until it is measured in the running Forge.
