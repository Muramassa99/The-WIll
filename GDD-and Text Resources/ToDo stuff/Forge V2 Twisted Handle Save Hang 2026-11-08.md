# Forge V2 twisted Handle save hang — 2026-11-08

## Scope and report

Investigate and repair a new Forge V2 weapon hanging on Ctrl+S. Preserve the
current Skill Crafter work and player libraries. No Git action requested.

User recipe: two-point long Handle, approximately 70% of available workspace
length; saved Medium Round template; 30 twists. Add a short Fluted spline blade
(about 5% of remaining space), then use a box Remove to form a pointed tip.
Ctrl+S hung until the user closed the game. The unsaved exact geometry is no
longer available. Reproduction dimensions are therefore approximations, not
recovered authored positions.

Actual saved profile names in the local profile library are `Medoum rounded`
and `fluted blade`; read them without changing that library.

## Evidence before changes

- Existing `verify_forge_v2_save_commits_pending.gd` passes on the current build;
  includes ordinary Save and changed profile/material/wrapper disk reload.
  Log: `godot_runs/forge_save_baseline_20261108.log`.
- Latest normal log `godot2026-11-08T22.25.10.log` records duplicate parenting of
  `NativeStaticMaterialBodyRevision_000001` during Undo fallback. The retiring
  node can still have `MaterialBodyCsgRoot` as its parent when rejection calls
  `add_child` again. This is confirmed but not proven to cause the Save hang.
- Save synchronously composes the protected Handle with ordinary geometry,
  builds three derived grip-target sweeps, validates their topology repeatedly,
  then builds and persists the runtime contract. The outer Save timeout cannot
  interrupt a synchronous calculation.
- Thirty turns require at least 2,160 longitudinal intervals under the existing
  5-degree sweep sampling rule. Two placed control dots do not mean a small mesh.

## Investigation and acceptance

Use an isolated library and the real templates/controller/Save pipeline. Record
operation times, Save stages, geometry counts, frame gaps and terminal result.
Find the dominant measured cost before changing geometry or validation rules.
Preserve twist, cuts, protected Handle and saved grip-target contracts. Do not
reduce quality or silence invalid geometry to make Save appear successful.

If changed, verify the focused reproduction through disk save/reload plus the
relevant existing regressions. Do not run unrelated Skill Crafter workflow tests.

Official references inspected: Godot 4.7 CSGShape3D and ArrayMesh documentation:
https://docs.godotengine.org/en/4.7/classes/class_csgshape3d.html
https://docs.godotengine.org/en/4.7/tutorials/3d/procedural_geometry/arraymesh.html

## Root cause and narrow change

`ForgeV2WipCompatibilityAdapter._resolve_handle_grip_geometry` calls
`PrimaryGripSeatResolver.build_mesh_slice_center_path` with a 1 mm interval.
Previously each station called the exact section resolver with EVERY protected
Handle triangle. The reproduced 4.2 m, 30-turn Handle has 207,452 triangles:
approximately 4,200 stations multiply that into about 870 million triangle
visits, before singular fallback probes. This synchronous work freezes the UI.

Changed only `core/resolvers/primary_grip_seat_resolver.gd` in production:
build conservative projected-triangle start/end events once, retain the active
triangles per station, then run the SAME section and centroid computation on
that subset. Source triangle order is preserved. Padding includes the on-plane
tolerance, both singular limiting probes and numerical error. Station spacing,
geometry, twist, source origins, grip mechanics and saved contracts are unchanged.

The user also reported trying 300 then 150 turns before 30. High-count creation
performance is a separate remaining cost; do not imply those cases are now fast.

## Fresh verification

- `tools/verify_primary_grip_slice_candidates.gd`: **43 checks, zero failures**.
  Exact equality against exhaustive slices for straight/twisted, transformed and
  curved fixtures; malformed topology/index failures preserved. Dense synthetic
  fixture: 103,660 candidate visits versus 72,610,084 exhaustive visits. Log:
  `godot_runs/forge_slice_candidates_20261108.log`.
- Headless real UI/controller Save reproduction, exact user profiles, 4.2 m
  two-point Handle with 30 turns, 0.09 m Fluted blade, box cut removing volume:
  **Save 15.984 seconds; WIP construction 10.668 seconds**. Fresh library reload
  retained 30-turn authoring, valid prepared wrapper, indices and cut geometry
  (maximum roundtrip coordinate difference 0.0000001192 m). No real player
  library modified. `godot_runs/forge_twisted_cut_save/after.json` and
  `godot_runs/forge_twisted_cut_save_after.log`.
- Earlier reproduction reached 99% and WIP construction then blocked for more
  than 60 seconds until the isolated diagnostic process was stopped. Important
  fixture limitation: that FIRST run loaded profile editor data but still used
  capsule blade/cutter shapes; its 207,452-triangle twisted Handle was correct.
  The corrected successful run explicitly selects saved Fluted/box shapes and
  proves an actual cut before Save. Thus do not publish a precise before/after
  speed ratio or claim the first run was an exact recreation.
- Existing `verify_forge_v2_save_commits_pending.gd` passes again after the
  change, including profile/material/wrapper persistence; log:
  `godot_runs/forge_save_regression_20261108.log`.
- Older `verify_primary_grip_slice_center_follower.gd`: geometry/adapter checks
  pass, but its two Skill Crafter endpoint checks fail. Read-only audit traced
  this to its obsolete null-actor/null-rig fixture with no hand-span metadata;
  current clearance enforcement predates this pass (`ec978c572`, 2026-10-14).
  The fixture expects unrestricted 0%/100% positions. This pass does not alter
  SC grip limits to satisfy that old expectation. Log:
  `godot_runs/forge_slice_center_regression_20261108.log`.

## Current status and limits

Save succeeds for the corrected reported-shape approximation and disk reload
verifies it. This is not the lost exact unsaved model. About 16 seconds is still
a noticeable pause: WIP construction/persistence remain synchronous. The report's
frame-gap maximum does not cover the final synchronous block because the harness
immediately performs disk validation before yielding; use explicit phase timings.
Handle generation also took about 5 seconds to commit in this heavy fixture.
150/300-turn creation has not been optimized or stress-tested here.

The separately observed Undo parenting error remains documented, not silently
claimed as the Save cause or folded into this fix. No Git staging/commit/push.

## Zero-twist comparison requested by user

Same corrected fixture and production code, only `--turns=0` changed:
Save **9.144 seconds**, versus **15.984 seconds** for 30 turns (about 43% shorter
in these single runs). Runtime mesh 61,492 triangles versus 210,344. WIP
construction still takes 7.572 seconds versus 10.668 seconds; substantial work
remains even without twist. Save and fresh disk reload pass, including the box
cut and valid wrapper. Evidence: `godot_runs/forge_twisted_cut_save/zero.json`
and `godot_runs/forge_twisted_cut_save_zero.log`. No additional production edits.
