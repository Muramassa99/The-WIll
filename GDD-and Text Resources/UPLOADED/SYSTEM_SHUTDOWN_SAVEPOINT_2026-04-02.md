# System Shutdown Savepoint - 2026-04-02

Purpose:
- allow next startup to resume immediately without re-orienting
- capture the exact current audit position, verified state, and next task

## Current Authority Files

Read these in this order on next startup:

1. `GDD-and Text Resources/UPLOADED/SYSTEM_SHUTDOWN_SAVEPOINT_2026-04-02.md`
2. `GDD-and Text Resources/UPLOADED/FULL_REPO_AUDIT_FIX_LEDGER_2026-04-01.md`
3. `GDD-and Text Resources/UPLOADED/CURRENT STATE OF THE WILL - IMPLEMENTATION MEMORY.md`
4. `GDD-and Text Resources/UPLOADED/RANGED_PHYSICAL_WEAPON_AND_SHIELD_FOUNDATION_SPEC_2026-04-02.md`

## Repo State

- Branch: `The-WIll-PerlStyle`
- Last commit on branch: `7023547`
- Last commit message: `Snapshot current The Will main folder state`
- No new commit was made after the current audit cleanup work
- Working tree is intentionally dirty and contains many ongoing project docs, result files, and audit changes

Important:
- do not assume dirty files are accidental
- do not reset or clean broadly
- continue from the audited state already on disk

## Project Law In Force

- data can be provisional
- core systems, methods, ownership, pipelines, and runtime behavior cannot be placeholder hacks
- if a foundation is wrong, stop and correct it instead of stacking patches
- do it the correct way the first time
- measure twice, cut once
- use the raw Josie model/skeleton as the foundation
- add small reversible layers only
- check dependencies and correlated code in parallel by default when cleaning architecture

## Godot Safety Rules In Force

- use one headless Godot verification at a time
- always use explicit `--log-file`
- do not run parallel Godot verification jobs
- prefer focused verifier scripts over broad `--check-only` if `--check-only` hangs
- ignore `Failed to read the root certificate store` unless it correlates with a real failure

## Current Audit Position

The ordered audit path we were following was:

1. crafted-item geometry foundation
2. forge production-vs-authoring/sample cleanup
3. remaining mixed-owner cleanup
4. core resolver decision lock
5. ranged physical weapon / shield foundation
6. tooling / output hygiene

Current position:
- steps `1`, `2`, and the major part of `3` have been pushed forward materially
- we are now inside step `4`: `core resolver decision lock`

## What Was Just Finished

### Player-owner cleanup advanced

Added:
- `The Will- main folder/the-will-gamefiles/runtime/player/player_motion_presenter.gd`

Updated:
- `The Will- main folder/the-will-gamefiles/runtime/player/player_controller.gd`

What changed:
- motion/input/aim responsibilities were split out of `player_controller.gd`
- controller now delegates:
  - runtime input-action setup checks
  - mouse look
  - move-direction solve
  - target move-speed solve
  - vertical motion
  - visual facing update
  - locomotion sync
  - minimal aim-context refresh

Current controller size:
- `player_controller.gd`: `356` lines

### Profile bake cleanup advanced

Added:
- `The Will- main folder/the-will-gamefiles/core/resolvers/profile_capability_score_resolver.gd`

Updated:
- `The Will- main folder/the-will-gamefiles/core/resolvers/profile_resolver.gd`

What changed:
- `ProfileResolver` now keeps:
  - mass
  - center of mass
  - connectivity validity
  - primary grip profile application
- capability score math now lives in `ProfileCapabilityScoreResolver`:
  - edge
  - blunt
  - pierce
  - guard
  - flex
  - launch

Current sizes:
- `profile_resolver.gd`: `96` lines
- `profile_capability_score_resolver.gd`: `206` lines

### Small resolver locks were made

Updated:
- `The Will- main folder/the-will-gamefiles/core/resolvers/anchor_resolver.gd`
- `The Will- main folder/the-will-gamefiles/core/resolvers/segment_resolver.gd`

What changed:
- `AnchorResolver.validate_primary_grip()` now uses the same eligible grip-span rules as the live anchor builder
- `SegmentResolver` now explicitly treats its current role output as first-pass bow-related hints only:
  - `is_riser_candidate`
  - `is_bow_string_candidate`
  - `projectile_pass_candidate`
- `SegmentResolver` still intentionally does not claim to solve full general segment-role derivation yet

## Verified Current State

These serial verifications passed after the latest player/profile/resolver work:

- `player_aim_baseline_results.txt`
- `player_locomotion_animation_results.txt`
- `player_inventory_slice_results.txt`
- `godot_m2_results.txt`

Key good signals:
- aim context refresh works and aim range is live
- locomotion clip switching still works
- inventory/storage/equip slice still works
- preset bake path still works for grip / flex / bow samples

## Known Residuals

1. `player_aim_baseline_results.txt` currently reports:
- `crosshair_visible=false`

Notes:
- this was not investigated in the last pass
- locomotion, aim range, preset baking, and equip flow all stayed valid
- treat this as a small known residual, not as the current main blocker

2. Crafted-item geometry is improved but still not final final.

Current state:
- raw cells
- `CraftedItemCanonicalSolid`
- `CraftedItemCanonicalGeometry`
- mesh / preview centering / placeholder bounds from that path

Still not done:
- final processed solid / chamfer-ready / shape-operator-ready stage
- shape-derived collision / combat hit volumes

3. Forge production-vs-authoring cleanup is smaller, but not declared finished forever.

The biggest misleading old sample ownership has been reduced already, but broader naming/hygiene cleanup is still later work.

## Exact Next Task

Resume with:
- `core resolver decision lock`

Immediate next file:
- `The Will- main folder/the-will-gamefiles/core/resolvers/capability_resolver.gd`

Why:
- this is now the remaining concentrated place where explicit unresolved decisions still live

Current open decisions there:
- exact reach normalization beyond first-pass max-distance
- optional reach bonus behavior for `cap_pierce`
- exact threshold mapping from `0.0-1.0` to `0/1/2/3/4`
- context bias plumbing exists, but no forge context/page layer is sending lines yet

Important rule for this next task:
- do not invent values blindly
- check uploaded docs first
- if the docs do not lock the rule, leave the decision explicit instead of pretending it is solved

## Resume Procedure

On next startup:

1. Read this file.
2. Read the ledger.
3. Read the implementation memory addendum.
4. Open:
   - `core/resolvers/capability_resolver.gd`
   - `GDD-and Text Resources/UPLOADED/agent-ready rule block for System 4 and System 5.md`
5. Continue the resolver decision-lock pass from there.
6. Verify serially after any capability-resolver change with:
   - `tools/verify_m2_presets.gd`
   - `tools/verify_player_inventory_slice.gd`
   - optionally `tools/verify_player_aim_baseline.gd` if the change could affect player-facing profile use

## Files Most Recently Touched In The Last Active Pass

- `The Will- main folder/the-will-gamefiles/runtime/player/player_motion_presenter.gd`
- `The Will- main folder/the-will-gamefiles/runtime/player/player_controller.gd`
- `The Will- main folder/the-will-gamefiles/core/resolvers/profile_capability_score_resolver.gd`
- `The Will- main folder/the-will-gamefiles/core/resolvers/profile_resolver.gd`
- `The Will- main folder/the-will-gamefiles/core/resolvers/anchor_resolver.gd`
- `The Will- main folder/the-will-gamefiles/core/resolvers/segment_resolver.gd`
- `GDD-and Text Resources/UPLOADED/FULL_REPO_AUDIT_FIX_LEDGER_2026-04-01.md`
- `GDD-and Text Resources/UPLOADED/CURRENT STATE OF THE WILL - IMPLEMENTATION MEMORY.md`

## Short Resume Sentence

Resume at the `capability_resolver.gd` decision-lock pass, using the savepoint + ledger + implementation memory as authority, with serial Godot verification only.
