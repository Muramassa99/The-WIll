# REPO ALIGNMENT RECOVERY SAVEPOINT 2026-04-13

## Purpose

This file is the recovery handoff after tracker drift and partial off-agent work.

Use it when restarting work after a pause.

It exists to answer four things quickly:

1. what is already recovered
2. what is still missing from the tracker layer
3. what should not be relogged because it is already covered elsewhere
4. what the next safe recovery pass should do

## Current Recovered Truth

The three main tracker files were re-baselined against live code and fresh verifier reruns:

- [CURRENT STATE OF THE WILL - IMPLEMENTATION MEMORY.md](/C:/WORKSPACE/GDD-and%20Text%20Resources/UPLOADED/CURRENT%20STATE%20OF%20THE%20WILL%20-%20IMPLEMENTATION%20MEMORY.md)
- [LIVE_EXPORTED_KNOB_REGISTRY.md](/C:/WORKSPACE/GDD-and%20Text%20Resources/UPLOADED/LIVE_EXPORTED_KNOB_REGISTRY.md)
- [NAMING_LAW.md](/C:/WORKSPACE/GDD-and%20Text%20Resources/UPLOADED/NAMING_LAW.md)

Those files now explicitly include:

- recovery-note language saying latest dated entries and fresh reruns win over older drifted wording
- combat-animation motion-node truth
- canonical combat slot ids:
  - `skill_block`
  - `skill_evade`
  - `skill_slot_1` through `skill_slot_12`
- gameplay HUD / slot-assignment runtime branch
- corrected note that current support-hand seating is not yet visually solved in the current verifier sample

## Fresh Verifier Truth Used In Recovery

The following files were rerun or reread as live truth during recovery:

- [combat_animation_station_workflow_results.txt](/C:/WORKSPACE/combat_animation_station_workflow_results.txt)
- [combat_animation_station_preview_results.txt](/C:/WORKSPACE/combat_animation_station_preview_results.txt)
- [player_weapon_guidance_results.txt](/C:/WORKSPACE/player_weapon_guidance_results.txt)
- [player_locomotion_animation_results.txt](/C:/WORKSPACE/player_locomotion_animation_results.txt)

Important current truth from those:

- combat animation station workflow is live and motion-node based
- combat animation station preview is live
- `2 Hand Idle` exists and resolves in locomotion selection
- current two-hand guidance sample still reports:
  - `left_hand_near_support=false`

## Critical Commit To Recover

The large missing historical logging target is:

- `be2f294`
- subject: `Full workspace push - all current work (exclude .exe via .gitignore)`
- stats:
  - `757 files changed`
  - `93188 insertions`
  - `2776 deletions`

This is the commit that matches the remembered `+93xxx / -27xx` scale.

## Cross-Reference Result

Do not relog `be2f294` blindly.

Large parts of its actual feature truth are already represented later in:
- [CURRENT STATE OF THE WILL - IMPLEMENTATION MEMORY.md](/C:/WORKSPACE/GDD-and%20Text%20Resources/UPLOADED/CURRENT%20STATE%20OF%20THE%20WILL%20-%20IMPLEMENTATION%20MEMORY.md)

Already represented enough to skip duplicate recovery:

- major Stage 2 editable-mesh / shell-apply / unified-selection work
- grip-law and handle-validity migration
- two-hand runtime guidance backbone
- combat animation station foundation / workflow / preview / world-entry
- `2 Hand Idle`
- later motion-node migration
- gameplay HUD / skill-slot branch
- later Skill Crafter UI overhaul and responsive fixes

## Still Under-Logged From `be2f294`

These are the highest-value missing categories still worth logging explicitly:

### 1. Shared grip-slice authority helper

- [primary_grip_slice_profile_library.gd](/C:/WORKSPACE/The%20Will-%20main%20folder/the-will-gamefiles/core/defs/primary_grip_slice_profile_library.gd)

Why it matters:
- it is the shared allowed-slice truth for grip validation and handle presets

### 2. Canonical / shell support classes introduced in the large push

- [crafted_item_canonical_surface_triangle.gd](/C:/WORKSPACE/The%20Will-%20main%20folder/the-will-gamefiles/core/models/crafted_item_canonical_surface_triangle.gd)
- [stage2_shell_mesh_state.gd](/C:/WORKSPACE/The%20Will-%20main%20folder/the-will-gamefiles/core/models/stage2_shell_mesh_state.gd)

Why they matter:
- they represent structural groundwork that can easily disappear from memory if not named explicitly

### 3. Preset cleanup / default sandbox state in the large push

- sample preset removals
- [forge_authoring_sandbox_default.tres](/C:/WORKSPACE/The%20Will-%20main%20folder/the-will-gamefiles/core/defs/forge/forge_authoring_sandbox_default.tres)

Why it matters:
- this is part of the “remove obsolete authoring scaffolds” truth and affects runtime expectations

### 4. Authored reference docs/specs added in the same push

- [Runtime Melee Combat Editor Visual-System.md](/C:/WORKSPACE/GDD-and%20Text%20Resources/Runtime%20Melee%20Combat%20Editor%20Visual-System.md)
- [Runtime Combat Editor Visual and System Addendum.md](/C:/WORKSPACE/GDD-and%20Text%20Resources/Runtime%20Combat%20Editor%20Visual%20and%20System%20Addendum.md)
- [Runtime Weapon-Owned Melee Skill Crafter 1.md](/C:/WORKSPACE/GDD-and%20Text%20Resources/Runtime%20Weapon-Owned%20Melee%20Skill%20Crafter%201.md)
- [Runtime Weapon-Owned Melee Skill Crafter-2.md](/C:/WORKSPACE/GDD-and%20Text%20Resources/Runtime%20Weapon-Owned%20Melee%20Skill%20Crafter-2.md)
- [STAGE 2 - UNIFIED VISUAL SHELL IMPLEMENTATION SPEC 2026-04-09.md](/C:/WORKSPACE/GDD-and%20Text%20Resources/UPLOADED/STAGE%202%20-%20UNIFIED%20VISUAL%20SHELL%20IMPLEMENTATION%20SPEC%202026-04-09.md)

Why they matter:
- they became part of the repo in the same giant push and should be treated as branch-intent references, not accidental file noise

### 5. Verifier harness expansion as infrastructure

Examples:
- [verify_branch_grip_validity.gd](/C:/WORKSPACE/The%20Will-%20main%20folder/the-will-gamefiles/tools/verify_branch_grip_validity.gd)
- [verify_primary_grip_clearance_and_drift.gd](/C:/WORKSPACE/The%20Will-%20main%20folder/the-will-gamefiles/tools/verify_primary_grip_clearance_and_drift.gd)
- [verify_handle_preset_grip_validity.gd](/C:/WORKSPACE/The%20Will-%20main%20folder/the-will-gamefiles/tools/verify_handle_preset_grip_validity.gd)
- [verify_player_finger_grip_ik.gd](/C:/WORKSPACE/The%20Will-%20main%20folder/the-will-gamefiles/tools/verify_player_finger_grip_ik.gd)

Why it matters:
- even when feature behavior is already logged, the harness growth itself is part of repo maturity and recovery confidence

## What Is Not Worth Relogging

Do not spend recovery time on these as if they were core implementation state:

- `.uid` files
- raw `godot_runs/*` logs
- `test_artifacts/*`
- result text snapshots by themselves
- `.godot` editor/cache files
- packaging / deleted executable noise

## Next Safe Recovery Order

If continuing recovery later, use this order:

1. log the still-missing `be2f294` subsystem truths listed above
2. keep using live code plus verifier reruns as authority
3. do not duplicate already superseded entries in implementation memory
4. mark uncertainty explicitly instead of smoothing contradictions over

## Working Rule

When in doubt:

- code truth beats memory
- fresh verifier truth beats older optimistic wording
- later dated entries beat earlier summaries
- under-logging is better than false certainty
