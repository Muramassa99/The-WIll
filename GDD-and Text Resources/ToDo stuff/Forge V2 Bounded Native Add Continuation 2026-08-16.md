# Forge V2 Bounded Native Add - Continuation Contract

Date: 2026-08-16  
Companion SPS: `GDD-and Text Resources/SPS/SPS_2026_08_16_22-37.md`

## One-Sentence Objective

Make current-quality Add deposition remain targetable with nearly flat tail
latency by retaining one native accumulated checkpoint, five undoable Add
states, and one protected Handle, then prove it in the real full-UI path.

## Locked State Law

For `N` deposited Add passes:

```text
N <= 5: empty S0 + N undoable states
N > 5:  checkpoint contains N-5 passes + five undoable states
Handle: protected, separate, non-undoable
```

Examples:

- N=6 -> checkpoint 1 + tail 5.
- N=20 -> checkpoint 15 + tail 5.
- N=20,000 -> checkpoint 19,995 + tail 5.
- Retained native states never exceed six; logical bodies with one Handle never
  exceed seven.

Promotion is ownership movement only. It must add no Boolean, no mesh export,
no whole-checkpoint dictionary copy, and no history replay.

## Current Verified Native Contract

`ForgeV2ManifoldBoolean` supports opt-in history and these calls:

- `set_history_window_enabled(true)` before reset;
- `reset_mesh`, `add_mesh`, `undo_state`, `redo_state`;
- `get_history_info`, `get_state_info`;
- `export_checkpoint_mesh` only for explicit persistence/recovery;
- `reset_checkpoint_mesh` for restore.

Successful Add performs one native Boolean and one active-state export. S0
promotion performs neither. Native history verification is archived at:

- `C:\WORKSPACE\godot_runs\verify_forge_v2_native_history_window.json`

## Remaining Implementation Slices

### 1. Atomic Promotion Metadata

Replace reference-mutation of checkpoint occupancy with a one-body touched-cell
delta:

- collect affected cells and their prior material/protected values;
- compute count changes without changing checkpoint authority;
- validate next checkpoint count, material, ledger candidate, and resolver
  sample basis;
- commit checkpoint metadata, touched cells, material counts, and bounded ledger
  as one logical transaction;
- on failure, state, revision, layer/body arrays, checkpoint, resolver cache, and
  ledger remain byte/semantic unchanged.

Never solve this by duplicating the full checkpoint occupancy dictionaries on
every promotion.

### 2. Safe Native Lifecycle

Create one centralized guard used by every non-destructive native reset:

```text
if logical checkpoint is dirty:
    export S0 from still-live backend
    validate count/revision/mesh
    install packet into checkpoint Resource
    only then clear provider/backend/publication
else:
    reset normally
```

Cover controller rebind, AuthoringState replacement, presenter clear, restore,
unsupported transition, async publication failure, and save. If export fails,
retain the old backend/publication and mark recovery blocked. A deliberately
destructive new-draft discard may bypass recovery only through an explicit
separate path.

### 3. Protected Handle Without Unbounded History

Do not reject native history merely because one normal protected Handle exists.

Use the current native active Add packet as a single aggregate operand and
construct a constant-size staged CSG publication:

```text
outer union
  inner ordinary material
    native aggregate Add mesh
    subtract protected Handle
  protected Handle union
```

This is set-equivalent to clipping every Add stroke by the Handle and then
unioning the Handle, while preserving the Handle material. Native S0+5 remains
the Add history authority; the Handle remains non-undoable state. Do not export
S0 during normal publication or promotion.

Initial eligibility should be narrow and explicit:

- same connected explicit-profile Add/Replace lane already accepted by native;
- exactly one valid protected Handle;
- Handle sweep valid under the current CSG builder;
- no Remove, EmptyOnly, second Add material, multiple Handle chronology, or
  platform seed until separately proven.

Reuse the existing staged generation/revision swap. Keep the prior collider live
until the new CSG composition is physics-ready; never relabel stale collision.

### 4. Unsupported Operation Safety

Until chronological multi-material/Remove fallback is complete, reject an
unsupported commit before it mutates AuthoringState once S0 exists. Do not
accept a layer that the presenter cannot publish. Remove is the next product
slice only after Add manual approval.

### 5. Target Identity

Surface identity must include:

- checkpoint ID;
- checkpoint revision or exact geometry digest;
- checkpoint operation count;
- active tail body IDs/signatures;
- protected Handle IDs/signatures;
- branch/transition revision.

Undo, redo, branch, load, and same-count different geometry must never share a
false-ready target ID.

## Focused Verification Before Stress

The first executable gate is 6-20 strokes, not 1,000.

Require:

- N6 = checkpoint1 + tail5; N20 = checkpoint15 + tail5;
- app active source bodies <=5, one protected Handle separate;
- native retained states <=6;
- exactly five undo and five redo; branch deletes redo;
- promotion adds one normal Add Boolean/export and zero promotion
  Boolean/export;
- live ledger layer-ID collections remain bounded;
- resolver checkpoint occupancy and material totals equal an independent full
  replay oracle at N5, N6, N20, undo, redo, and branch;
- normal Add has zero checkpoint materialization attempts/successes;
- Handle geometry/material survives every Add and undo/redo;
- current-CSG surface parity, topology, bounds, volume, normals, material,
  collision, and real A/B/C target probes pass;
- lifecycle rebind/save/restore cannot lose dirty S0;
- no stale or duplicate target collider.

Then run 20 full-UI strokes, 100, and finally 1,000.

## 1,000-Stroke Acceptance Record

Archive all rows and report:

- strokes per minute;
- release-to-first-target and release-to-stable-target p50/p95/p99/max;
- finish-call and post-finish/deferred phases;
- max frame gap;
- head strokes 2-4 and tail three full cycles;
- worst stroke +/-3 context;
- 100-stroke window metrics and fitted tail slope;
- native Boolean/import/export, mesh publication, collision, UI, state, ledger,
  and resolver phase counters;
- checkpoint/tail/native retained counts each checkpoint;
- fallback, recovery-blocked, stale-result, and checkpoint-materialization
  counts.

Final N=1,000 invariants:

```text
checkpoint_operation_count = 995
active_tail_count = 5
native_retained_state_count <= 6
protected_handle_count = 1 (Handle fixture lane)
hot checkpoint materialization attempts = 0
fallback/failure/stale target counts = 0
```

Compare against the accepted 60-second reference (469 SPM, 170.944 ms p95,
194.485 ms max release-to-stable-target). Tail/max and head-to-tail consistency
are primary. The optimal target remains <=100 ms targetability with a nearly
flat head/tail distribution. Never accept worse SPM merely because one internal
phase became faster.

## Kill Rules

Stop and fix rather than extending the run when:

- history/body/ledger counts grow beyond the contract;
- any promotion materializes S0;
- Handle presence disables promotion;
- state commits but publication retains the previous revision;
- targeting uses stale collision metadata;
- geometry/material/normal parity changes;
- max latency or mature-window slope is worse than the accepted reference;
- a focused gate fails.

## Non-Goals For This Slice

- Python publication atlas.
- Voxel/SDF replacement of the drawn profile.
- Approximate proxy targeting.
- Hidden final-drain time.
- Remove/VOID implementation.
- Multi-material Add generalization before the single-material + protected
  Handle lane passes.

The continuation succeeds only when the real application, not an isolated
kernel, demonstrates bounded state and better end-to-end flow.
