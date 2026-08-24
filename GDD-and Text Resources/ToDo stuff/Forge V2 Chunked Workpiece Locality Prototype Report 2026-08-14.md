# Forge V2 Chunked Workpiece Locality Prototype Report

Created: 2026-08-14 Europe/Bucharest

Workspace: `C:\WORKSPACE`

Project: `C:\WORKSPACE\The Will- main folder\the-will-gamefiles`

Status: tools-only experiment; not selected for production

## Purpose And Decision Context

Forge V2 is intended to feel like using the crafter, not fighting the crafter.
The authoring language remains CSG-like—Add, Remove/VOID, Replace, Empty Only,
saved-profile sweeps, protected Handles, and Detail—but accepted strokes must
become one evolving logical solid instead of permanent live construction
operands.

The bounded rolling-CSG experiment proved that stroke history can be absorbed
into one accepted mesh with zero steady CSG operands. Its 5,000-operation stress
run also showed that bounding retained operands is not enough: each new Boolean
still reprocessed the growing whole-workpiece mesh. The next experiment must
therefore bound the edited **spatial region**, not merely the history window.

This report records the first chunked labelled-solid locality proof and the
comparison contract around it. It supplements, and does not replace, the
[Forge V2 Workpiece Compiler Architecture And Benchmark](Forge%20V2%20Workpiece%20Compiler%20Architecture%20And%20Benchmark%202026-08-13.md).

The long-term product intent remains:

- one evolving solid workpiece during authoring;
- organic final geometry, not visible block/pixel geometry;
- a rich, editable WIP authority and a separately compiled lightweight runtime
  asset;
- bounded undo/checkpoints, initially five accepted actions and increased only
  when measured safe;
- eventual replacement of the legacy target plane with a seed-first flow;
- an Island Inspector for finding, focusing, and deleting non-primary floating
  components before finalization.

## Why Whole-Workpiece Rolling CSG Was Stopped At 5,000

The deterministic connected-raster run was intentionally stopped by the
operator after operation 5,000. This was not a harness failure and was not a
completed 10,001-operation result.

At operation 5,000:

| Measurement | Observed value |
| --- | ---: |
| Accepted revision | 5,000 |
| Peak temporary CSG operands | 6 |
| Steady CSG operands | 0 |
| Recent compile p50 | 760.802 ms |
| Recent compile p95 | 850.392 ms |
| Recent compile p99 | 911.475 ms |
| Recent compile maximum | 1,009.502 ms |
| Recent headless frame-gap p95 | 811.729 ms |
| Measured elapsed time | 1,964.607 s |

From operation 500 onward, the affine-linear compile-p95 fit was:

```text
compile p95 ~= 25.7188 ms + 0.160065 ms * accepted operation count
R2 ~= 0.998699
```

The corresponding frame-gap slope was approximately `0.155181 ms` per added
operation with `R2 ~= 0.998285`. Because the per-operation cost rose
approximately linearly, cumulative elapsed time followed an approximately
quadratic curve (`R2 ~= 0.999998`). Throughput fell about 92.3% from the first
complete 100-operation interval to the last measured interval. The final
100-operation interval averaged approximately `794 ms/operation`, or
`1.26 operations/second`.

This separates two facts:

```text
solved:      permanent SceneTree CSG history and steady operand growth
not solved:  Boolean work against the growing accepted whole-workpiece mesh
```

Sampled ordinary Godot static memory rose approximately linearly with occupied
geometry. Excluding collision checkpoints, its fit was about:

```text
61.8509 MiB + 0.002441 MiB * accepted operation count
```

The operation-5,000 geometry/collision checkpoint sampled 86.2 MiB; the highest
non-collision sample was 73.8 MiB. These are sampled Godot static-memory values,
not OS working set, GPU memory, or proof of a retained leak.

A hardened 100-operation diagnostic separated early rolling-CSG phases. Its
final bin measured approximately `0.752 ms` node-build p95, `58.974 ms`
deferred-settle p95, `0.002 ms` static-bake p95, and `1.647 ms`
surface-consolidation p95. In that diagnostic, Godot's deferred CSG settlement
was the dominant phase; `bake_static_mesh()` mostly retrieved an already
resolved result. That phase split was measured at 100 operations and must not
be projected unchanged to operation 5,000 without new instrumentation.

The detailed analysis and charts are:

- [5,000-operation analysis report](../../godot_runs/forge_v2_workpiece_rolling_stress_5000_analysis.report.md)
- [Machine-readable fitted metrics](../../godot_runs/forge_v2_workpiece_rolling_stress_5000_analysis.metrics.json)
- [Latency chart](../../godot_runs/forge_v2_workpiece_rolling_stress_5000_analysis.latency.svg)
- [Elapsed-time and projection chart](../../godot_runs/forge_v2_workpiece_rolling_stress_5000_analysis.elapsed.svg)
- [Interval-cost chart](../../godot_runs/forge_v2_workpiece_rolling_stress_5000_analysis.interval_cost.svg)
- [Throughput chart](../../godot_runs/forge_v2_workpiece_rolling_stress_5000_analysis.throughput.svg)
- [Sampled-memory chart](../../godot_runs/forge_v2_workpiece_rolling_stress_5000_analysis.memory.svg)

## Exact Tools-Only Prototype Files

The new isolated prototype consists of:

```text
res://tools/forge_v2_chunked_labelled_solid_backend.gd
res://tools/benchmark_forge_v2_workpiece_compiler_chunked_field.gd
res://tools/verify_forge_v2_chunked_labelled_solid_backend.gd
```

The benchmark reuses the existing deterministic stress fixture and mesh
analyzer:

```text
res://tools/forge_v2_workpiece_stress_fixture.gd
res://tools/forge_v2_workpiece_benchmark_mesh_analyzer.gd
```

No runtime Forge class, production presenter, player save, or player WIP
library is routed through this backend.

## Current Chunked Design

### Canonical experimental state

The backend holds one sparse dictionary keyed by integer chunk coordinate. It
does **not** hold one GDScript Dictionary entry per cell. Each allocated chunk
contains:

- a `PackedByteArray` material-label channel;
- a `PackedByteArray` protected-mask channel;
- occupied-cell and cached-mesh counts;
- cached naive exposed-face mesh arrays.

The default proof resolution is `0.004 m` per cell with `16 x 16 x 16` cells
per chunk. One chunk therefore spans `0.064 m` on each axis and contains 4,096
cell slots. Negative grid positions use mathematical floor division so chunks
remain stable across the world origin.

There are no CSG nodes. A direct seed establishes revision 0. Every accepted
operation updates the same logical labelled field and advances the workpiece
revision/source count.

### Deliberately narrow command support

The first proof accepts only:

- `VolumeStroke` bodies;
- saved `PROFILE_PATH` shapes with a valid runtime profile;
- explicit surface B-to-C/contact authority;
- finite, straight, collinear, monotonic paths with one constant resolved
  frame;
- Add Material plus Replace Existing;
- the same material as the seed/current workpiece.

VOID, Empty Only, a second material, Handle behavior, curved paths, twist, and
other body/shape kinds are rejected explicitly. An Add must overlap an existing
occupied cell or attach through a face. Rejected commands must leave canonical
state unchanged.

The rasterizer resolves the same explicit profile frame used by the existing
profile logic, bounds the straight closed sweep, and tests grid-cell centers
against its longitudinal extent and asymmetric 2D polygon. The result is a
block-field approximation of that solid, not the exact sweep boundary.

### Local update and mesh cache

Candidate cell indices are grouped by chunk. Acceptance changes only those
packed chunk channels. Only changed chunks and their six face-neighbor chunks
are remeshed. Each chunk emits naive exposed cell faces while querying adjacent
chunks, so internal occupied faces—including faces across chunk boundaries—are
omitted.

The backend maintains total occupied cells, quads, triangles, chunks, revision,
source count, and last-operation locality counts. Operation results separate:

- raster time;
- packed-channel update time;
- local remesh time;
- total backend time;
- candidate/changed cells and changed/remeshed chunks.

`get_combined_mesh()` concatenates cached chunk boundaries deterministically
into one `ArrayMesh` for checkpoints and comparison. That full concatenation is
not required for each accepted edit. Its cost must be measured separately; a
local editor backend would normally display/update chunk meshes and build a
combined final asset only at deliberate checkpoints or compilation boundaries.

### Channel intent versus proof

The material label and protected-mask layout demonstrates a shape that can be
extended toward multiple materials and Handle-protection semantics. It does
not prove those semantics. The current protected mask is storage scaffolding,
not Handle authority.

## Verification State At Time Of This Report

A focused Godot 4.7 headless verifier completed **7/7 checks passing**. It
covered default dimensions, negative-coordinate floor mapping, revision-0 seed,
timing fields, one attached same-material Add, combined-mesh triangle/winding
agreement, and atomic rejection of a second material.

An expanded verifier is still pending acceptance. The latest persisted artifact
at the time this section was written contains 15 checks: 14 pass and the
occupied-cell-volume versus combined-mesh-volume check fails. Passing checks
include strict/authoring watertight topology, atomic second-material/VOID/curve
rejections, ten deterministic Adds, zero built-in CSG nodes, and deterministic
ten-Add replay. The remaining volume mismatch must be diagnosed and the full
expanded verifier rerun before staged benchmark results are treated as valid.
The values under investigation are `0.001534703397 m3` from mesh analysis versus
`0.001534720000 m3` from occupied cells, a difference of about
`0.000000016603 m3` or 10.8 parts per million. Winding, topology, and the cell
count are clean/deterministic in the same run. A numerically more stable volume
calculation is being checked before changing tolerance; this report does not
declare the cause or the expanded verifier passed.

Current verifier artifacts:

```text
C:\WORKSPACE\godot_runs\verify_forge_v2_chunked_labelled_solid_backend.txt
C:\WORKSPACE\godot_runs\verify_forge_v2_chunked_labelled_solid_backend.json
C:\WORKSPACE\godot_runs\verify_forge_v2_chunked_labelled_solid_backend.engine.log
```

## Staged Chunked Results — Pending Root Completion

This section is intentionally left incomplete. Do not infer results from an
unfinished or failed verification run.

| Chunked run | Result | Final chunks | Occupied cells | Final triangles | Total-time p95 | Raster p95 | Update p95 | Remesh p95 | Elapsed |
| ---: | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 100 operations | **PENDING** | — | — | — | — | — | — | — | — |
| 1,000 operations | **PENDING** | — | — | — | — | — | — | — | — |

Before filling this table, record the unique run artifact paths, fixture digest,
Godot build, verifier state, topology/volume gates, memory sample scope, and
whether combined-mesh checkpoint time is included in or separated from ordinary
edit time.

## Explicit Non-Goals And Fidelity Limits

This is a locality/scaling carrier proof, not a selected geometry backend.

- The 4 mm cell field is visibly blocky and cannot meet the organic Forge V2
  target.
- It is not an SDF, sparse-distance brick system, Marching Cubes, Surface Nets,
  Dual Contouring, or a sharp-feature mesher.
- Cell-center rasterization quantizes profile dimensions, corners, thin walls,
  holes, clearances, and contact seams.
- It cannot yet prove the existing 1 mm fillet or 0.5 mm anchor-clearance
  requirements.
- Naive exposed-cell faces are a correctness/locality visualization, not final
  render topology, UVs, smoothing, materials, collision, or optimization.
- It supports only straight same-material Add/Replace strokes. It does not
  implement Remove/VOID, multiple or buried materials, Empty Only, Handle
  priority/protection, Detailing surface geodesics, spline/Handle free-space
  orientation, blending, or seam/vacuum-bag control.
- It has no persistence schema, migration, crash recovery, bounded undo,
  background job publication, stale-revision protection, authoring collision,
  finalization compiler, or runtime payload.
- A sparse chunk dictionary may scale with occupied spatial volume; that is
  expected. The experiment asks whether equal local edits cease scaling with
  historical operation count.

### Known implementation risks from read-only audit

- The attachment gate currently accepts an operation when **any** candidate
  cell overlaps or face-touches existing matter. It does not prove that every
  disconnected component within that candidate also attaches, so a pathological
  raster could introduce a floating candidate island.
- The shared explicit-frame resolver may project a supplied path tangent into
  the surface tangent plane. The prototype currently rasterizes longitudinally
  with the original straight path tangent while reusing the resolver's profile
  axes. A non-tangent path/surface input should be rejected or resolved through
  one consistent tangent before this can be trusted beyond the fixture.
- Raster work currently scans every cell in the sweep's world-axis-aligned
  bounding box and reports only accepted candidate cells. A long diagonal
  stroke can therefore perform substantially more scan work than its candidate
  count reveals. Future measurements need a scanned-cell/AABB count or a more
  direct chunk/profile traversal.

The block field may succeed as a material/semantic/locality authority while a
different exact or smooth representation owns presentation. Such a hybrid is
acceptable only if targeting, preview, canonical state, and final geometry
agree within explicit tolerances; two disagreeing authorities are not a
solution.

## Comparison Gates

### Locality and flow

- Run the identical deterministic connected raster used by rolling CSG.
- At equal local stroke geometry, compare total, raster, update, and remesh p95
  at 100 and 1,000 operations before extending farther.
- Ordinary edit cost should track candidate cells and affected chunks, not the
  total accepted operation count or whole-workpiece triangle count.
- Fit latency against operation count and locality measures. The desired curve
  is approximately flat with operation count for equal local edits; a merely
  smaller intercept is insufficient.
- Keep combined checkpoint mesh generation, topology analysis, and collision
  work out of ordinary edit timing and report them separately.
- Track worst edit, p50/p95/p99, throughput, memory, changed cells/chunks,
  remeshed chunks, and queue depth if background work is later introduced.

### Geometry and determinism

- Expanded verifier passes completely, including occupied-volume agreement.
- Output remains finite, nondegenerate, closed/manifold, and one connected
  component for this connected-Add fixture.
- Adjacent occupied chunks emit no internal seam faces.
- Replaying the same seed and command stream yields the same canonical summary
  and geometry signature.
- Forward/reverse asymmetric-profile handedness is preserved when that lane is
  added.

### Material, Handle, and authoring laws

These are later selection gates, not capabilities of the current proof:

- same-material overlap counts once;
- material ownership, Replace, Empty Only, and buried material remain ordered;
- VOID produces the intended B-to-C reflection and preserves valid holes;
- protected Handle volume survives ordinary Add/Replace/VOID according to the
  locked Handle-priority rules;
- geometry, ledger, targeting collision, and gameplay facts share one accepted
  revision.

### Fidelity and runtime

- Test candidate field resolutions at least at 2 mm, 1 mm, and 0.5 mm, with
  sparse memory and performance reported.
- Compare exact authored dimensions, sharp corners, small fillets, thin walls,
  clearances, holes, and asymmetric orientation.
- Select or prototype a smooth/sharp-feature extraction path that reaches the
  organic visual target without restoring whole-workpiece edit cost.
- Finalization must compile the rich WIP authority into one optimized,
  watertight, lightweight game-facing asset with material surfaces, collision,
  Handle/grip data, mass/gameplay facts, WIP identity, and accepted revision.

## Protected Data And Isolation

The protected player reference WIPs remain:

```text
Test Glave
Test sword for animations
```

Neither item was used as a mutable benchmark fixture. The prototype does not
insert benchmark WIPs into `user://`, alter the player WIP library, or route a
production Forge path through the chunked backend. Production runtime/tools
outside the isolated `res://tools` experiment remain untouched by this report.

## Next Actions

1. Diagnose the expanded verifier's occupied-volume comparison and obtain a
   fully passing, persisted expanded verification result.
2. Run and archive the staged 100-operation chunked benchmark. Separate normal
   edit timing from combined-mesh, topology, and collision checkpoints.
3. Run 1,000 operations only after the 100-operation invariants pass. Compare
   p95 slope and per-phase cost with rolling CSG rather than comparing only one
   final elapsed number.
4. If 100 and 1,000 remain local and stable, extend to 5,000 using the same
   fixture and stop once the scaling conclusion is decisive. A 10,001 run is
   unnecessary if it yields no new information.
5. Inspect memory versus allocated chunks/occupied volume, and inspect whether
   naive remesh or full checkpoint concatenation becomes the next dominant
   phase.
6. Prototype a fidelity route—finer sparse labelled bricks, SDF, sharp-feature
   meshing, exact/local Boolean chunks, or a measured hybrid—without changing
   the locked workpiece laws.
7. Add semantics incrementally with independent gates: VOID, second/buried
   materials, Replace/Empty Only, protected Handles, curved surface-aware
   strokes, and Detailing surface paths.
8. Design bounded undo around prior chunk snapshots/deltas and stored-byte
   limits, beginning with five accepted actions. Do not use inverse Boolean or
   reverse mouse replay as general undo.
9. Only after backend selection, integrate revision-safe preview/compile/swap,
   persistence, targeting collision, and the rich-WIP-to-light-runtime compiler.
10. Later replace the legacy target plane with the seed transition and add
    canonical connectivity plus the Island Inspector before finalization.

No result in this report authorizes production integration.

## Session Stop Addendum — 3 Percent Budget Boundary

This addendum is the latest authority where it differs from earlier status text.
Work stopped deliberately before the staged 100/1,000-operation runs.

- The expanded backend verifier now reports **15/15 PASS**. The original
  world-origin volume sum differed from occupied-cell volume by about 10.8 ppm;
  a bounds-local-origin sum reduced that to about 2.7 ppm, consistent with
  packed-float mesh coordinates. A stronger integer-lattice volume oracle was
  requested but was not completed before the stop.
- The benchmark runner has a **known parse blocker** at
  `benchmark_forge_v2_workpiece_compiler_chunked_field.gd` in
  `_script_constant()`: it calls non-static `get_script_constant_map()` on the
  script resource. Replace this with direct known backend constants (or a valid
  instance-based query), then run an actual one-operation script smoke before
  any staged benchmark. An editor filesystem scan did not expose this tool-only
  script error.
- Therefore the 100- and 1,000-operation table remains intentionally pending;
  no scaling claim for the chunked prototype has been made yet.
- Read-only audit identified two additional experiment gaps:
  1. Rasterization scans the entire world-axis AABB. The current X-aligned
     fixture hides a potentially severe diagonal-stroke cost (for example, a
     long thin diagonal sweep can examine millions of empty cells). Add an
     `examined_cell_count` metric and a diagonal/rotated-path benchmark before
     claiming general locality.
  2. Attachment currently accepts an operation when *any* candidate cell
     touches the accepted solid. It does not prove every newly introduced
     candidate component is connected. Add a candidate-component/accepted-solid
     connectivity gate before treating this as the one-workpiece law.

Production Forge files and player saves were not routed through this prototype.
`Test Glave` and `Test sword for animations` remain untouched.

## Resume Evidence Correction — 2026-08-15

This section supersedes the earlier verifier/runner status where it differs.
It does not authorize the later rough fixed-chunk or `+2`-halo proposal.

Two evidence-only defects were corrected:

- the runner now reads `BACKEND_ID` and `BACKEND_SCHEMA_VERSION` directly from
  the preloaded backend script instead of calling the instance-only
  `Script.get_script_constant_map()` method as if it were static;
- the verifier diagnostic uses a supported fixed-point `%f` format instead of
  unsupported `%g` formatting.

Fresh focused verification now on record:

- Expanded backend verifier: **15/15 PASS**, process exit `0`, and no
  `ERROR`, `SCRIPT ERROR`, or parse error in
  `C:\WORKSPACE\godot_runs\verify_chunked_field_resume_2026-08-15_exit.engine.log`.
- Its integer-lattice oracle was already present in current source and now has
  clean evidence: `143880 == 143880` six-lattice volume units for 23,980
  occupied cells. The prior SPS statement that this oracle was unfinished was
  stale.
- The first actual chunked runner smoke completed **1/1 operation**, process
  exit `0`, with clean engine output and passing geometry, strict topology,
  exact lattice-volume, occupancy-volume, and zero-CSG gates.
- Unique smoke result prefix:
  `C:\WORKSPACE\godot_runs\forge_v2_workpiece_chunked_field_20260815T103042_375685_pid22128_1ops`
  (`.json`, `.csv`, and `.txt`).
- Smoke output contained 32 allocated chunks, 14,850 occupied cells, and
  12,860 triangles. Its single cold operation measured approximately
  `379.331 ms` total (`77.012 ms` raster, `0.503 ms` packed update,
  `231.274 ms` local remesh). One cold sample is not a latency curve and must
  not be compared as decision-quality performance evidence.

The staged 100- and 1,000-operation rows remain pending. Before those stages,
the existing prototype still needs examined-cell accounting, complete
candidate-component connectivity, tangent/frame consistency handling, and a
diagonal diagnostic lane. The user's later fixed-region/`+2 chunks` idea
remains discussion-only and was not implemented by this repair.

## Contact-Local Prototype Completion - 2026-08-15

This section is the latest authority where it differs from the earlier
pending-status and stop-boundary sections.

The fixed spatial-region idea is now implemented and measured in an isolated
`res://tools` prototype. It is not routed into production Forge V2.

### Implemented locality contract

- Canonical sparse grid: `4 mm` cells grouped into `16 x 16 x 16` cells per
  chunk, so one chunk spans `64 mm` on each axis.
- Missing chunks are implicit empty space. There is no full preallocated
  workspace grid.
- A deterministic chunk DDA follows the stroke, expands only by the profile's
  spatial support, and then performs the exact cell test inside the resulting
  candidate chunks.
- A `+2` Chebyshev chunk halo is available as read-only processing context.
  Halo chunks are not allocated merely because they are near the edit and do
  not become writable geometry.
- Only changed chunks and actual face-dependent neighbor chunks are remeshed.
- Candidate connectivity is checked on newly occupied cells. Every new
  candidate component must face-touch the accepted pre-edit solid. Existing
  overlap remains valid contact evidence but cannot falsely bridge two new
  disconnected islands.
- A full-overlap Add is a valid no-op: zero new components, zero changed cells,
  and zero remesh work.
- No built-in Godot CSG node remains after an accepted operation. The prototype
  uses no CSG nodes during its local edit path.
- A non-colliding guide overlay exists with Off, Active, Active plus Halo, and
  Full Workspace modes. It is an isolated test visualization and is not wired
  into the production Forge UI.

The exact 45-degree diagnostic reduced tested raster cells from a full-AABB
`145,200` to `55,680`, while retaining exactly the same `15,368` occupied
candidate cells as the brute-force reference.

### Correctness gate

The final focused backend verifier completed **21/21 PASS** with process exit
`0`. It covers diagonal DDA/brute-force occupancy parity, newly occupied
component attachment, disconnected-component rejection, no-op transaction
semantics, chunk-boundary meshing, outward winding, strict and authoring
watertight topology, one connected component, exact integer-lattice volume,
deterministic replay, and the non-colliding guide.

Clean verifier log:

```text
C:\WORKSPACE\godot_runs\verify_chunked_locality_final_2026-08-15.engine.log
```

### Final 5,000-operation stress result

The clean final stress run completed **5,000/5,000 PASS** in `533.859 s` with
no engine errors:

```text
C:\WORKSPACE\godot_runs\forge_v2_workpiece_chunked_contact_locality_20260815T135853_400424_pid22028_5000ops.json
C:\WORKSPACE\godot_runs\chunked_contact_locality_5000ops_new_cells_metrics_retry_2026-08-15.engine.log
```

Final accepted state:

| Measurement | Result |
| --- | ---: |
| Accepted edit operations | 5,000 |
| Resident chunks | 320 |
| Occupied cells | 742,940 |
| Combined checkpoint triangles | 104,016 |
| Steady live CSG nodes | 0 |
| Initial sampled static memory | 60.77 MiB |
| Final sampled static memory | 78.00 MiB |
| Peak sampled static memory | 87.67 MiB |

Every checkpoint remained watertight at both strict and authoring tolerances,
had one connected component, and matched the occupied-cell volume oracle.

Interactive operation timing deliberately excludes whole-workpiece combined
mesh generation, topology inspection, and collision work. Those are explicit
checkpoint/finalization costs. The operation-5,000 global checkpoint analysis
took about `4,587.458 ms`; it is not suitable for the per-stroke path.

### Deterministic random action sample

To answer whether action time is constant, 16 recorded operations were sampled
without replacement from the clean 5,000-operation run using deterministic
seed `20260815`. This samples real positions in the fixed stress stream; it
does not invent random unverified geometry.

`total_ms` is backend entry-to-exit edit time. `remesh occupied` is the amount
of already accepted local matter inside the chunks rebuilt by that edit.

| Revision | Total ms | Raster ms | Attach ms | Remesh ms | Changed cells | Remesh occupied | Resident chunks |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 238 | 79.264 | 74.835 | 1.901 | 0.005 | 0 | 0 | 128 |
| 353 | 82.685 | 78.215 | 1.893 | 0.007 | 0 | 0 | 128 |
| 476 | 84.391 | 79.965 | 1.898 | 0.004 | 0 | 0 | 128 |
| 556 | 108.106 | 74.390 | 3.329 | 28.443 | 220 | 16,280 | 128 |
| 645 | 113.719 | 77.018 | 3.257 | 32.004 | 220 | 18,480 | 128 |
| 718 | 119.315 | 78.255 | 3.352 | 35.766 | 220 | 20,680 | 128 |
| 1,275 | 132.745 | 75.281 | 3.371 | 51.690 | 220 | 29,920 | 168 |
| 2,166 | 114.123 | 78.243 | 3.334 | 30.538 | 220 | 17,380 | 192 |
| 2,338 | 155.628 | 79.858 | 3.319 | 70.453 | 220 | 40,480 | 192 |
| 3,400 | 101.283 | 77.529 | 3.415 | 17.539 | 220 | 9,240 | 256 |
| 3,591 | 84.504 | 79.940 | 1.896 | 0.003 | 0 | 0 | 256 |
| 3,977 | 82.063 | 78.327 | 1.823 | 0.004 | 0 | 0 | 256 |
| 4,286 | 81.504 | 78.344 | 1.782 | 0.003 | 0 | 0 | 256 |
| 4,476 | 83.261 | 79.031 | 1.860 | 0.004 | 0 | 0 | 280 |
| 4,511 | 141.294 | 80.857 | 3.640 | 54.162 | 220 | 28,600 | 304 |
| 4,516 | 84.727 | 80.368 | 1.850 | 0.004 | 0 | 0 | 304 |

Across all 5,000 recorded actions:

| Action class | Count | Mean ms | p50 ms | p95 ms | Minimum ms | Maximum ms |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| All actions | 5,000 | 101.316 | 94.433 | 143.897 | 76.129 | 185.273 |
| Positive local change | 2,672 | 117.813 | 114.972 | 158.933 | 84.960 | 185.273 |
| Valid full-overlap/no-op | 2,328 | 82.382 | 82.398 | 87.759 | 76.129 | 118.104 |

The random rows are not expected to have one identical millisecond value.
They perform different amounts of local remeshing. Raster time stays in a
narrow band, no-op edits stay near `80-85 ms` in the sample, and changed edits
rise with the amount of occupied matter inside the rebuilt local chunks.

For positive edits, remesh time correlates with occupied cells in the remeshed
chunks at `r = 0.994`. The rebuilt-quad correlation is only `r = 0.661` and the
fixed remesh-slot scan correlation is `r = 0.515`. This identifies the remaining
sawtooth as local fill/surface complexity, not accumulated workpiece history.

### The correct constant-time comparison

"Constant" means the same local operation should cost approximately the same
on a young and mature workpiece. It cannot mean that a tiny no-op and a large
local surface rebuild must take identical time.

Within the 5,000-action stream, 456 revision pairs separated by 1,616 actions
matched across all recorded local work counters while global workpiece age and
size differed. Their mature-minus-young timing delta was:

| Matched-pair statistic | Result |
| --- | ---: |
| Mean signed delta | -0.789 ms |
| Median signed delta | +0.111 ms |
| Median absolute delta | 1.512 ms |
| p95 absolute delta | 18.789 ms |

Representative exact-local-work pairs:

| Revisions | Earlier ms | Later ms | Delta ms | Changed | Remesh chunks | Remesh occupied | Rebuilt quads |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 2,274 -> 3,890 | 89.220 | 82.989 | -6.231 | 0 | 0 | 0 | 0 |
| 2,291 -> 3,907 | 135.598 | 117.830 | -17.768 | 220 | 8 | 18,260 | 2,202 |
| 2,429 -> 4,045 | 121.643 | 125.158 | +3.515 | 220 | 8 | 21,780 | 2,266 |
| 2,484 -> 4,100 | 82.875 | 82.985 | +0.110 | 0 | 0 | 0 | 0 |
| 2,495 -> 4,111 | 122.998 | 123.718 | +0.720 | 220 | 8 | 22,000 | 2,270 |
| 2,651 -> 4,267 | 128.480 | 130.500 | +2.020 | 220 | 8 | 25,740 | 2,338 |
| 2,725 -> 4,341 | 112.928 | 113.091 | +0.163 | 330 | 8 | 14,410 | 3,012 |
| 3,335 -> 4,951 | 95.598 | 96.542 | +0.944 | 110 | 8 | 5,060 | 1,852 |

The independent controlled oracle is stricter about remote workpiece maturity:
eight young/mature probe pairs had exact local-counter parity, while the young
workpiece contained 20,224 cells in 80 chunks and the mature workpiece contained
85,760 cells in 336 chunks. Results:

| Controlled paired result | Value |
| --- | ---: |
| Young mean | 4.099 ms |
| Mature mean | 4.056 ms |
| Mature-minus-young mean | -0.043 ms |
| Paired p50 delta | +0.020 ms |
| Paired p95 delta | +0.084 ms |
| Mature/young p50 ratio | 1.0049 (+0.49%) |
| Mature/young p95 ratio | 1.0209 (+2.09%) |

That is the evidence for the desired property: **equal local edits are
approximately insensitive to remote workpiece size in this isolated
prototype.**

### Durable analysis artifacts

The deterministic analysis can be regenerated with:

```text
res://tools/analyze_forge_v2_chunk_locality.py
```

Fixed output prefix:

```text
C:\WORKSPACE\godot_runs\forge_v2_chunked_contact_locality_analysis
```

It emits `.report.md`, `.metrics.json`, `.samples.csv`, and four SVG charts:
`.timings.svg`, `.locality.svg`, `.memory_checkpoints.svg`, and `.paired.svg`.
Two consecutive regenerations produced byte-identical artifacts; JSON, CSV,
and SVG/XML validation passed. The strongest measured remesh correlation is
now explicitly the occupied-cell count inside remeshed chunks.

### Decision and honest boundary

The locality hypothesis passes for this experiment. The fixed sparse chunk
division plus virtual halo is preferable to a permanently instantiated visual
workspace grid: it gives stable spatial addresses without allocating unused
space, while the guide can still show the active chunks and halo when useful.

This is not yet the final V2 geometry backend. The current proof is visibly
blocky 4 mm labelled occupancy and supports only straight, same-material saved
profile Add/Replace operations. It does not yet prove organic extraction,
curved strokes, VOID/removal, multiple and buried materials, protected Handles,
collision publication, persistence, bounded undo, Detailing surface paths, or
production presenter/accounting locality.

The next technical work should preserve the proven local edit boundary while
replacing the block-face output with an organic-fidelity local surface method.
Production integration should wait until those geometry and semantic gates
pass. Whole-body topology, collision, final mesh compilation, and Island
Inspector work remain explicit checkpoint/finalization operations rather than
ordinary stroke costs.

No player save or production Forge path was modified. `Test Glave` and
`Test sword for animations` remain untouched.

## 2026-08-15 Production Cutover For Manual Testing

The previous honest boundary described the locality carrier before production
authorization. The user has now explicitly authorized a direct engine swap for
manual testing. This is not an experimental toggle and there is no live CSG
fallback.

### Locked one-engine authority

- `runtime/forge_v2/forge_v2_workpiece_solid_engine.gd` is the only accepted
  committed-workpiece geometry engine.
- A completed supported stroke is rasterized into the persistent sparse 4 mm
  labelled solid. Only changed chunks and their actual face dependencies are
  remeshed.
- `MaterialBody` and layer records remain replay, save, and bounded-history
  provenance. They are not rendered as permanent CSG operands.
- The solid engine's maintained occupied-cell count is the authoritative
  material total. Accepted commits do not invoke the old 12.5--25 mm material
  volume resolver or walk all committed bodies.
- Each accepted layer is stamped `chunked_labelled_solid_v1`. Its stored delta
  is replayed by the ledger; ledger rebuild does not reinterpret geometry.
- The presenter publishes one cached `ArrayMesh` and, in the authoring
  workspace only, one local concave collision shape per resident chunk.
  Untouched chunk resources are retained by coordinate and mesh revision.
- All chunk colliders share one draft-stable workpiece target identity. The
  miniature bench presenter is visual-only and creates no targeting collision.
- The legacy `MaterialBodyCsgRoot` is retired and has no caller. Lightweight
  in-progress previews may still exist, but committed matter is never rebuilt
  through the old CSG zone tree.
- Engine epoch changes only when the entire authority is atomically replaced
  by new/load/undo/redo replay. An ordinary stroke changes revision without
  invalidating remote chunks.

### Supported production slice

The first manual slice intentionally supports:

- a fresh Melee draft without a platform seed;
- one selected material;
- Add Material plus Replace Existing;
- a saved `PROFILE_PATH` with explicit surface normal and B-C contact data;
- curved, piecewise Volume Stroke paths with varying explicit frames;
- generated Detailing Brush paths using the same surface-frame authority;
- the first accepted body as the workpiece seed;
- later additions only when every new candidate component overlaps or
  face-connects to already accepted matter;
- transactional save/load replay and layer undo/redo.

Once accepted matter exists, ordinary Volume Stroke placement resolves against
that matter only. The legacy backdrop remains available only to place the first
seed in this supported flow. A disconnected later stroke is rejected rather
than deposited through a hidden fallback.

### Explicit current rejections

The engine visibly and transactionally rejects these until their solid laws are
implemented:

- primitive/capsule deposition;
- Spline Line and spline-profile bodies;
- Handle profiles and protected-Handle composition;
- platform seeds used by Shield/Bow paths;
- Remove Material / VOID;
- Empty Space Only;
- multiple materials;
- profile extrusion bodies outside the supported Volume Stroke/Detail family.

Automatic freehand rejection removes its unfinished body and leaves solid,
layer stack, and ledger unchanged. Manual generated-body rejection retains the
editable pending body but does not accept it. A batch of multiple pending bodies
is rejected before reaching the engine. There is no CSG compatibility route.

### Manual test sequence

Use a disposable fresh V2 WIP. Do not overwrite `Test Glave` or
`Test sword for animations`.

1. Start a fresh Melee draft.
2. Select CSG Material Stroke, Add Material, Replace Existing, one material,
   and a saved 2D profile. The default primitive/capsule is intentionally not a
   supported test input.
3. Draw the first stroke on the backdrop. Confirm the status reports backend
   `chunked_labelled_solid_v1`, revision 1, nonzero chunks/cells/triangles, and
   that the block-solid result is targetable.
4. Add equal-volume connected strokes at several locations. Compare the shown
   last-action time for the same local contact workload on young and mature
   regions. Remote workpiece size should not determine the result.
5. Repeat one stroke exactly over existing matter. It is a valid no-op: source
   revision advances, but cells, material units, chunk mesh resources, and
   colliders remain unchanged.
6. Attempt a disconnected post-seed stroke. It must reject visibly and create
   no ghost geometry, layer, or material charge.
7. Use Detailing Brush with the same material on the accepted surface. Confirm
   its resolved path commits to the chunk solid and remains targetable.
8. Undo and redo the latest accepted layer. Geometry, material total, collision,
   and target identity must return together after candidate replay.
9. Save and reload only the disposable test WIP. Confirm the same solid summary
   and workpiece target return. Unsupported older Forge V2 WIPs should reject
   without replacing the currently open draft.
10. Record any pass whose local work appears equal but whose time grows with
    remote workpiece age. Include the status summary and approximate stroke
    location so its chunk/contact workload can be compared.

### Verification evidence at cutover

- canonical runtime-engine verifier: PASS, 35/35;
- curved ruled-path occupancy: 13,479 cells, exactly equal to the independent
  whole-bounds ruled-frame oracle;
- Detailing Brush production path: PASS;
- touched-chunk mesh replacement plus remote mesh-resource retention: PASS;
- state/controller transaction gate: PASS, including no-op delta, no legacy
  resolver call, undo/redo/load replay, failed-replay rollback, and rejection
  atomicity;
- presenter gate: PASS, including two-world separation, chunk/collider reuse,
  stable metadata, and zero committed CSG under the chunk workpiece;
- real controller -> engine -> presenter end-to-end gate: PASS;
- Godot 4.7 full editor/import scan: exit 0 with no parse or script errors;
- targeted `git diff --check`: clean.

### Honest cutover boundary

This is a functional locality-first engine swap, not the final organic surface
extractor. Its published geometry is still visibly blocky 4 mm cell-face
geometry. Organic reconstruction, VOID, multiple/buried materials, protected
Handles, free-space Spline/Handle orientation infrastructure, bounded undo,
final connected-component inspection, and the lightweight finished-game asset
compiler remain subsequent work. Those missing capabilities must extend the
single solid authority; they must not restore a permanent per-stroke CSG tree.

### Verification-side-effect record

One pre-isolation UI regression run touched two real user settings files before
the fixture was corrected:

- `user://forge/tool_presets/player_tool_profile_library_state.tres` received
  its normal one-time saved-profile schema migration. Existing profile IDs,
  names, and data remain present and the resulting resource is valid.
- `user://settings/forge_v2_keybindings.json` was rewritten as an empty override
  dictionary. No pre-run hash exists, so it cannot be proven whether this was a
  byte change or only an unconditional rewrite of the same defaults.

Neither persistence owner creates a local backup, so no guessed restoration was
attempted. No WIP/draft library, equipment state, `Test Glave`, or
`Test sword for animations` was written. Both UI verifiers now inject isolated
profile-library and keybinding paths under `C:\WORKSPACE\godot_runs`. Final
reruns passed and proved the real settings files' hashes and timestamps remained
unchanged.

## 2026-08-15 Manual-Test Rejection And Organic Local-Boolean Correction

The direct production cutover above was rejected after the first real manual
authoring test. Its locality result remains useful, but its geometry model does
not satisfy Forge V2's profile, placement, or tool contracts.

### The implementation mistake

Two different meanings of "cube" were conflated:

- the intended cube is an invisible spatial jurisdiction used to decide which
  local region must participate in a Boolean operation;
- the prototype cube became a voxel that decided the actual shape of the
  workpiece.

The intended workpiece may occupy an arbitrary curved sliver of a chunk. It
must retain the exact tessellated profile/path surface inside that chunk. It
must never be rounded, filled, or snapped to the chunk boundary merely because
the chunk is active.

The rejected backend center-sampled each 4 mm cell as occupied or empty and
then emitted exposed cube faces. This caused two decisive failures:

1. Detailed saved profiles were reshaped into block occupancy, defeating the
   purpose of authoring and selecting the profile.
2. The target mesh exposed only `+/-X`, `+/-Y`, and `+/-Z` face normals. The
   placement resolver correctly applied ABC sign selection to those normals,
   but no sign rule can recover the continuous normal that was discarded.
   Adjacent staircase faces can therefore rotate B-C by 90 degrees and make a
   subsequent profile fold into already accepted matter.

The targeting collider itself was published correctly. A real
controller/presenter probe measured a roughly 160 ms commit, resolved targets
immediately and after process/physics frames, and hit all six exterior test
rays. That test proved collider availability only; it did not prove surface
normal fidelity. The missing feedback-loop gate was:

```text
commit organic stroke A
-> raycast A's actual accepted surface
-> use returned B and B-C to author stroke B
-> prove continuous orientation and exterior deposition
```

The production cutover also intentionally rejected Capsule, Spline Line,
Handle, Remove/VOID, Empty Only, platform-seed, and multimaterial bodies. Making
that restricted benchmark backend the sole engine consequently made Handle and
Spline generation disappear/reject in ordinary use. That is not an acceptable
production boundary.

### Production rollback

The locality backend, guide, benchmarks, charts, and evidence remain isolated
for research. The production routing has been surgically rolled back to the
organic CSG path while preserving the newer explicit B-C, preview/final,
Detailing Brush, smoothing, and material-policy work. The rollback restores:

- organic committed profile/path geometry and its collision surface;
- Capsule, Spline Line, Handle, Volume Stroke, Detail, and material-operation
  commit routing;
- new/load/undo/redo behavior;
- the prior incremental material-volume resolver and ledger reconstruction;
- the hybrid placement resolver and strict Detail target APIs.

This section supersedes the production authority statements in
`2026-08-15 Production Cutover For Manual Testing`. The block backend is no
longer production authority.

### Rollback verification completed

The restored organic path passed a clean full editor/import scan and a
sequential 22-verifier Forge V2 regression suite covering profile authoring,
freehand input, active preview, saved-profile deposition, explicit B-C and
handedness, surface targeting, Detailing Brush, Spline Line, Handles, material
composition, undo/cache behavior, and macro-menu routing.

A new end-to-end feedback verifier then exercised the previously missing real
surface loop:

```text
commit curved organic stroke A
-> raycast six actual static-CSG collision faces across bends and seams
-> reuse each returned B, raw normal, and ABC-selected B-C without substitution
-> author and commit stroke B
-> raycast the combined result and prove exterior displacement
```

The focused Godot 4.7 run passed with these diagnostics:

- six of six physical probes resolved the intended organic surface;
- minimum raw-normal fidelity dot product was `1.000000`;
- maximum adjacent-normal continuity error was `0.000045 degrees`;
- all six normals were deliberately oblique rather than axis-aligned;
- B/raw-normal/B-C triplets were reused exactly by stroke B;
- the generated feedback sweep had at least `0.026608 m` outward extent and at
  most `0.000985 m` buried depth;
- all six post-commit witnesses moved outward, by `0.017417 m` to
  `0.023328 m`;
- the accepted result remained authoritative static organic CSG.

The verifier is
`tools/verify_forge_v2_csg_organic_surface_feedback.gd`; its result and clean
run log are under `C:\WORKSPACE\godot_runs`. No production defect was exposed,
so no additional production patch was made.

The two older UI fixtures that had once reached real profile/keybinding storage
were also isolated before final reruns. Hash and timestamp guards proved those
reruns did not touch the real settings. The WIP library, equipment state,
`Test Glave`, and `Test sword for animations` remained untouched throughout
rollback verification.

### Locked corrected meaning of locality

- Tools continue to author one exact closed sweep from the selected profile,
  path, explicit frames, anchor, and rotation rules.
- Chunks are broad-phase ownership/loading addresses only.
- A chunk may own a partial curved solid fragment; its box does not appear in
  the authored surface.
- Only the exact geometry in a closed dirty region participates in the next
  Boolean. Remote fragments remain unchanged.
- Chunk-plane closure faces are compiler-only jurisdiction caps. They are
  never rendered, collided with, or accepted as placement targets.
- B and B-C come from the exact visible surface or retained surface
  provenance. A chunk boundary, voxel face, or debug guide can never be the
  contact-frame authority.
- The active preview and Boolean operand must use the same closed sweep
  geometry builder.

### Recommended exact regional-Boolean flow

The leading design is a chunked closed-fragment representation backed by a
robust manifold mesh Boolean kernel:

1. Generate the exact watertight sweep mesh used by preview/final geometry,
   with material and source-patch provenance.
2. Select intersected chunks from the sweep AABB plus a precision/tessellation
   halo.
3. Assemble all selected fragments into one closed regional solid. Remove
   paired internal jurisdiction caps and keep caps only on the region perimeter.
4. Boolean the complete exact sweep against that regional solid once.
5. Require the region-perimeter seam signature to remain unchanged. If the
   operation touches it, expand the region and retry.
6. Split the one accepted regional result deterministically back into closed
   chunk fragments.
7. Tag new chunk-plane caps as compiler-only and exclude them from rendering,
   collision, and targeting.
8. Validate manifoldness, connectivity, volume, material provenance, seam
   identity, and finite geometry.
9. Atomically replace every affected fragment. Any failure leaves the prior
   accepted workpiece untouched.

Independent per-chunk Booleans are not the preferred design: two independent
solves can triangulate or classify their shared seam differently. One regional
solve followed by one deterministic split gives both sides the same source
result.

Manifold is the leading native-kernel candidate because it operates on closed
triangle-mesh solids, supports Boolean/BatchBoolean and SplitByPlane/
TrimByPlane operations, and retains input face/property relationships useful
for material and surface provenance. It is still finite-precision mesh
geometry, not analytic NURBS; "exact" here means faithful to the authored
tessellated sweep within a declared tolerance. Godot's built-in CSG already
uses Manifold, but SceneTree CSG remains main-thread/deferred and is documented
as a prototyping facility with significant CPU cost. A native worker backend
is therefore the likely production kernel if the isolated regional proof
passes.

Primary references:

- https://github.com/elalish/manifold
- https://raw.githubusercontent.com/elalish/manifold/master/include/manifold/manifold.h
- https://docs.godotengine.org/en/4.7/classes/class_csgshape3d.html

### Offset/forcefield alternative

A smooth offset or forcefield target above the block surface could make B-C
placement less erratic, and the block output may remain useful as an optional
visual/debug style. It does not restore profile detail: the accepted solid
would still be voxelized and the targeting proxy could disagree with the
committed boundary or bridge narrow gaps. It is therefore not the primary
Forge V2 solution.

### Decisive proof before another cutover

Keep the next backend isolated until it passes all of these gates:

- asymmetric detailed profile on an oblique curved path crossing at least
  three chunk boundaries;
- a second overlapping stroke authored from real ray hits on the first result;
- regional result compared against one monolithic Boolean oracle;
- one connected, watertight manifold with matching topology and volume;
- sampled surface deviation within the declared tessellation tolerance;
- unchanged region-perimeter seam hashes and no visible/collidable cap faces;
- B-C normal angular error and adjacent-sample continuity limits;
- the second stroke remains on the intended exterior side;
- tangent, coplanar, tiny-overlap, chunk-corner, and region-expansion cases;
- unchanged resources for remote chunks and stable equal-local-work timing;
- Capsule, Spline, Handle, Detail, Add, Remove, undo/redo, and persistence
  behavior proven before production authority is changed.

No future benchmark-only backend is to be promoted directly. Production swaps
only after a real A-surface-to-B-stroke feedback test passes.
