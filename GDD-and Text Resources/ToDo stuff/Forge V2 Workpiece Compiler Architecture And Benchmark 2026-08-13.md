# Forge V2 Workpiece Compiler Architecture And Benchmark

Created: 2026-08-13 Europe/Bucharest

Workspace: `C:\WORKSPACE`

Project: `C:\WORKSPACE\The Will- main folder\the-will-gamefiles`

Branch at creation: `godot-4.7-plus-development`

Recovery base at creation: `40f5048 Save Forge V2 profile deposition before stroke and detailing overhaul`

## Document Role

This is the design and experiment contract for changing Forge V2 from an
unbounded permanent CSG-operation tree into one evolving workpiece with a
bounded compiler lifecycle.

It records decisions made in conversation, current-code findings, the first
repeatable benchmark, backend decision gates, and the boundaries that must not
be guessed during implementation.

This file does **not** claim that:

- a new geometry backend is already selected;
- the isolated rolling-CSG experiment is selected or routed into production;
- native Manifold, a sparse field, or SDF is implemented;
- the current Forge V2 path has been removed;
- the target plane, finalization flow, Island Inspector, or runtime compiler is
  already changed;
- the old Forge V1 Stage 1 or Stage 2 implementation is becoming the new V2
  geometry implementation.

Current Forge V2 remains the working fallback until a candidate passes the
geometry, semantic, persistence, and flow-state gates in this document.

## Source And Resume Links

- [Current SPS and backend investigation](../SPS/SPS_2026_08_12_05-07.md)
- [Stroke, Detailing, and performance implementation contract](Forge%20V2%20Stroke%20Detailing%20Performance%20Implementation%202026-08-10.md)
- [Forge V2 design notes](forge_v2_design_notes.md)
- [Original weapon crafter V2 direction](../UPLOADED/weapon%20crafter%20v2.md)
- [Project orientation and authority map](../../Agent%20law/PROJECT%20ORIENTATION%20AND%20AUTHORITY%20MAP.md)

## Historical Boundary: What V1 Proved And What V2 Must Become

Forge V1 Stage 1 and Stage 2 are proofs of concept, not the intended final
authoring system.

### Forge V1 Stage 1

- Established a general shape and material layout through block/cell
  deposition.
- Proved a WIP could retain rich authoring data and later compile many cells
  into a consolidated boundary mesh.
- Was constrained by pixel/block geometry and an alternating 2D placement
  plane.

### Forge V1 Stage 2

- Attempted the refinement pass: deformation, beveling, rounding, pinching,
  pushing, pulling, and surface detailing.
- Proved that a processed Stage 2 representation could be used to create a
  lightweight game-facing `ArrayMesh` and that equipment could instantiate a
  copy from WIP identity.
- Did not provide a sufficiently usable or satisfying shaping workflow.
- The reference item `Test sword for animations` has no Stage 2 deformation;
  its baseline and current Stage 2 geometry are equal. This reflects the pause
  of that experiment, not a requirement that V2 inherit Stage 2 tools.

### Forge V2 target

Forge V2 combines what was learned from both proofs into one better system:

- organic, continuous geometry rather than visible pixel art;
- direct drawing and shaping in three-dimensional space;
- general construction and refinement in one coherent authoring lifecycle;
- solid Add, Remove, material, Handle, and Detail semantics;
- rich editable WIP data;
- a processed, lightweight game asset for Storage, equipment, Skill Crafter,
  and runtime playback.

The reusable V1 lesson is the lifecycle:

```text
rich authoring state
    -> consolidated current workpiece
    -> processed mesh arrays and gameplay profile
    -> lightweight game-facing asset instance
```

V2 must not inherit the pixel-grid appearance or the rejected Stage 2 editing
experience merely because the lifecycle was useful.

## Observed Current Forge V2 Problem

Current V2 has a combined-looking CSG result, but its persistent geometry is
still construction history:

- every accepted stroke remains a `ForgeV2MaterialBody`;
- every accepted body remains a CSG operand when the presenter reconstructs
  the workpiece;
- intersecting same-material bodies are placed in one CSG zone, but the zone
  still contains the growing set of source operands;
- adding an intersecting operation changes zone membership and reconstructs
  the complete connected zone;
- collision for the zone is regenerated with the resolved CSG result;
- VOID, replacement, Empty Only, and protected Handle clipping can create more
  complicated operand graphs;
- zone connectivity currently uses broad AABB intersection, not exact
  topological connectivity.

Simple same-material source-node count grows approximately linearly, not as a
literal power of `N`. The cumulative work still compounds because operation
`N` rebuilds the result from operations `1..N`. Native Boolean and collision
complexity can make that growth substantially worse than the raw node count.

Reducing undo depth alone does not solve this. Current undo toggles material
bodies active or inactive; it does not absorb active bodies into one accepted
solid.

The existing `ForgeV2MaterialVolumeResolver` contains valuable ordered material
and Handle laws, but its 0.0125-0.025 m accounting sampling is not a geometry
authority for:

- 0.001 m authored fillets;
- 0.0005 m anchor clearance;
- thin walls and small gaps;
- exact asymmetric profile corners;
- organic final surfaces.

Material-economy resolution and geometry resolution must remain explicitly
separate contracts.

## Locked Workpiece Laws

These decisions are backend-independent.

### One logical evolving workpiece

A stroke is an authoring operation, not permanent workpiece geometry.

After an operation is accepted, its effect belongs to the current workpiece
revision. The live operation object may remain briefly for preview, compile,
and bounded undo data, but it must not remain forever as a rendered CSG
operand.

### Solid authoring truth

Forge V2 authoring requires reliable volumetric inside/outside truth.

- An intentional tunnel, ring opening, drilled hole, or other through-hole is
  valid if the remaining boundary is closed.
- A missing face, open crack, zero-thickness seam, or malformed boundary is
  not a valid solid.
- “Shell” is not rejected merely because a runtime mesh consists of boundary
  triangles. A closed watertight boundary is a valid representation of a
  solid. The rejected condition is an unreliable/open paper-like surface.

### CSG is the Forge language, not the permanent memory model

The authoring language remains CSG-like:

- Add solid;
- Remove solid/VOID;
- Replace Existing;
- Fill Empty Space;
- sweep a saved profile;
- protect Handle regions;
- attach Detail material;
- optionally introduce controlled seam blending later.

The permanent unbounded Godot SceneTree CSG operand tree is not the intended
workpiece database.

### Bounded accepted state

The intended steady state is:

```text
one stable workpiece identity
one accepted workpiece revision
one authoritative geometry/material/semantic state
one inexpensive live drawing preview
at most one in-flight candidate compile
at most one coalesced pending revision
zero permanent stroke CSG operands
```

One logical workpiece may internally use several chunks, material surfaces,
mesh instances, or collision regions. Those are implementation details and
must not restore stroke-count scaling.

### One-revision derivation law

Geometry, collision, material totals, protected Handle regions, grip/gameplay
data, connected-component results, and runtime output must identify the same
accepted source revision.

This avoids the V1 risk where Stage 2 visual edits and Stage 1-derived gameplay
facts could become two different truths.

## Solid WIP Versus Lightweight Runtime Asset

### WIP authority

The WIP retains the information needed to continue editing:

- canonical solid or volume authority;
- stable local authoring coordinates and bounds;
- volumetric material ownership, including buried material;
- protected Handle regions and exact Handle authoring records;
- seed/primary-component identity;
- current revision, schema, backend, and compiler versions;
- bounded undo/checkpoint information;
- derived authoring render/collision caches tied to the current revision;
- project, profile, Skill Crafter, and gameplay metadata.

### Runtime asset

Finalization derives a game-facing asset containing only what gameplay needs:

- optimized watertight boundary mesh;
- material surfaces/mapping;
- lightweight collision;
- mass, center of mass, material quantities, and effects;
- Handle/grip regions and anchors;
- tip, pommel, length, reach, and other baked facts;
- WIP ID and accepted revision/hash;
- Skill Crafter and skill-slot identity/data.

Runtime does not need:

- live CSG nodes;
- every authoring operation;
- high-resolution editable volume chunks;
- full undo history;
- mouse/spline path history unless a gameplay system explicitly needs a
  derived result from it.

Equipment and Skill Crafter instantiate or reference the processed payload.
The WIP remains the rich editable source.

### Why surface mesh alone is insufficient for WIP truth

A visible mesh cannot, by itself, preserve:

- buried materials that may become exposed after a later cut;
- interior material interfaces and quantities;
- protected Handle volume/priority;
- seed and component provenance;
- reliable future Add/Remove behavior if the surface is malformed;
- reversible dirty-region data.

One watertight mesh plus separate volumetric/semantic information can be a
viable WIP representation. A visible surface mesh alone is not enough.

## Backend-Neutral Compiler Contract

Forge tools must not know which backend wins.

```text
Tool input
    -> immutable WorkpieceCommand
    -> ForgeV2WorkpieceState revision
    -> interchangeable GeometryBackend
    -> derived render mesh and collision
    -> runtime asset compiler
```

Conceptual compile call:

```text
compile(base_snapshot, ordered_or_coalesced_commands) -> new_snapshot
```

### WorkpieceCommand minimum data

- deterministic command ID and order;
- source/base revision;
- tool family;
- Add, Remove, Replace, or Empty Only policy;
- material `.tres` identity;
- closed operand geometry or deterministic profile/path inputs;
- authored profile polygon, anchor, and contact metadata;
- A-to-B placement result;
- explicit B-to-C depth direction;
- ordered path tangent/travel `T`;
- surface normals when the tool is surface-conforming;
- Handle/Detail semantic role;
- hard seam or future blend radius;
- affected bounds/dirty-region estimate.

### ForgeV2WorkpieceState minimum data

- stable workpiece ID;
- accepted revision;
- schema/compiler/backend versions;
- canonical solid authority;
- volumetric material ownership;
- semantic/protected Handle regions;
- exact authored Handle records;
- seed and primary-component identity;
- material totals;
- component report;
- derived mesh/collision cache revision IDs;
- bounded undo/checkpoint state;
- deterministic content hash or equivalent revision signature.

## Target Plane And Seed Transition

The current target/backdrop plane is legacy scaffolding:

- it came from the V1 directional deposition workflow;
- it provides something raycastable for the first V2 placement;
- it is not workpiece material;
- it was never intended to remain the permanent creation surface.

The `ForgeV2PlacementTargetResolver` seam should be preserved while the target
changes.

Intended future flow:

1. The player creates or selects the initial seed/workpiece.
2. The plane may be used only to position that initial seed.
3. Once real accepted workpiece matter exists, the backdrop becomes
   non-targetable or is removed from the placement route.
4. Later Add and Detail operations target the accepted workpiece.
5. The transparent workspace box remains the local origin, scale/bounds guide,
   and diegetic world-prop presentation. It is not automatically material.

This supports the old no-floating-weapon intent without returning to visible
block/pixel geometry.

Target-plane removal is **not** part of the first benchmark implementation.

## Material And Handle Authority

The future workpiece must preserve these existing laws:

- same-material overlap counts once;
- Replace Existing changes ordinary material ownership;
- Empty Only fills unoccupied volume;
- VOID removes ordinary material;
- buried material remains known and may be exposed later;
- material accounting and geometry derive from the same accepted operation
  ordering.

Handle authority remains semantic and volumetric:

- Handle material may replace/cannibalize ordinary material where authored;
- ordinary Add may overlap/attach visually but cannot replace Handle volume;
- VOID cannot remove protected Handle volume;
- ordinary Replace behaves like Fill Void inside protected Handle volume;
- Detail material does not expand the valid Handle region merely by covering
  it;
- exact Handle records remain available for grip validity, hand placement,
  collision, and Skill Crafter.

This is why a final visible mesh cannot replace the WIP's semantic authority.

## Tool And Orientation Laws To Preserve

### CSG Material Stroke and Detailing Brush

- Share surface-aware A/B/C/T placement and orientation.
- `A -> B` selects contact location.
- explicit `B -> C` selects surface-depth direction.
- ordered `T` controls travel handedness.
- preview, accepted geometry, material volume, and persistence must agree.

The intended Add/Remove four-state mapping remains:

| Operation | Travel | Shape analogy |
| --- | --- | --- |
| Add | forward `T` | `d` |
| Add | reverse `T` | `b` |
| Remove | forward `T` | `q` |
| Remove | reverse `T` | `p` |

Reversing `T` changes travel handedness. Switching Add to Remove reflects the
B-to-C depth relation without requiring a separately authored negative profile.

Detailing Brush ultimately needs a shortest valid path measured along one
connected resolved surface. It must not connect controls with a direct chord
through air. Stable connected-solid identity is a prerequisite.

### Spline Line and Handles

- Remain unrestricted free-space paths.
- Do not inherit the surface-tangent path constraint merely because they use a
  similar profile sweep.
- Their future roll/B-to-C authority needs additional infrastructure.

Benched work remains recorded in `forge_v2_design_notes.md`:

- `Select Solid` magnetic orientation reference;
- deterministic degeneracy fallback;
- live shadow/profile sweep while adding or moving spline/Handle control dots.

### Seam/vacuum-bag control

Observed concave seam filling may later become a meter-based authoring option:

```text
hard/tight union
    -> progressively softer join
    -> fuller filleted or vacuum-bag transition
```

No seam control is implemented or authorized by this note. The exact current
artifact must first be separated into source sweep geometry, Boolean topology,
contact overlap, normals/shading, or some combination. Cross-material ownership
for newly blended volume is also undecided.

## Connectivity And Finalization

Authoring may temporarily produce more than one component, especially after a
Remove operation. A finalized/equippable asset must resolve to exactly one
physical connected component.

Connectivity is evaluated on the canonical accepted solid, not by:

- material ID;
- stroke ID;
- layer;
- CSG node;
- AABB overlap;
- visible proximity;
- operation history.

Different materials may form one connected workpiece. Point-only, edge-only,
tangent, and zero-thickness contact do not count as a valid structural
connection. A nonzero overlap/contact tolerance is required.

### Primary component

Recommended rule:

1. The component containing the persisted seed is primary.
2. If the seed is absent or cannot be resolved, the largest-volume component
   is the fallback primary.
3. If the seed-containing component and largest component differ, warn rather
   than silently protecting both.

### Island Inspector quality-of-life flow

On finalization, if more than one component exists, show every non-primary
island in a list with:

- focus/bring to front;
- highlight while ghosting the primary workpiece;
- dimensions and approximate volume;
- material composition;
- distance from the primary component;
- delete selected island;
- Delete All Floating.

Delete All Floating is one undoable authoring action. The player should never
have to hunt for a near-zero fragment in empty space.

## Undo And Checkpoint Law

Undo is a convenience feature and may be bounded aggressively to protect the
authoring flow.

Initial policy:

- begin with five accepted workpiece actions;
- measure memory and latency;
- permit ten or fifteen only if evidence shows it is safe;
- bound history by both action count and stored bytes because one long stroke
  may change more data than many small strokes.

Reverse mouse replay and inverse Boolean are not general undo solutions.
After a union, discarded internal faces cannot reliably reconstruct the prior
mesh by simply subtracting the same tool.

Preferred forms:

- field backend: before/after dirty-region deltas;
- exact-mesh backend: bounded prior snapshots or checkpoint plus recent command
  replay;
- transient Spline/Handle/Detail point editing: a separate local tool history.

When the budget is exceeded, fold the oldest accepted action into the baseline
checkpoint and discard its reversible payload. Do not leave it as live CSG
geometry.

## Background Compiler Law

Correct synchronous geometry must be proven before background work is added.

The eventual bounded state is:

```text
one accepted front revision
one in-flight immutable compile job
one coalesced pending/dirty revision
one lightweight live preview
```

Rules:

- never build an unbounded job queue;
- increment revision on new input;
- merge overlapping dirty work when safe;
- reject completed results whose source revision is stale;
- publish mesh/collision atomically on the main thread;
- never silently raycast stale collision;
- save the canonical accepted revision, not whichever derived mesh happened to
  finish most recently.

SceneTree CSG is not thread-safe work. A native/background backend must operate
on immutable numeric data and only publish Godot nodes/resources on the main
thread.

## Backend Candidates And Decision Gates

### Candidate A: rolling built-in Godot CSG bake

```text
steady:   one accepted display mesh and zero live CSG operands
compile:  one baked base + a bounded recent command batch
accept:   one new accepted mesh; the temporary CSG tree is discarded
```

This is the cheapest and most informative first proof.

Keep it if:

- repeated bake/refeed remains watertight and manifold;
- authored profile dimensions and handedness remain within tolerance;
- Add/Remove/material/Handle laws remain correct;
- operation latency and worst-frame slope remain acceptable through a mature
  fixture.

Stop this route if:

- repeated baking accumulates slivers, gaps, drift, or topology failures;
- main-thread hitches remain unacceptable;
- cost still rises unacceptably with the consolidated mesh's triangle and
  intersection complexity.

Godot 4.7 CSG updates are deferred by a rendered frame, and official guidance
describes CSG as a prototyping tool with significant CPU cost. Baking reduces
permanent operand count; it does not guarantee constant-time work.

### Candidate B: native Manifold worker

If exact rolling geometry is correct but the remaining failure is Godot's
main-thread CSG lifecycle, a C++ GDExtension may vendor upstream Manifold and
compile immutable mesh arrays off-thread.

This route adds:

- native builds for each target platform;
- job revision/cancellation;
- material and semantic mapping;
- main-thread publication;
- long-term native-code maintenance.

Do not implement a triangle Boolean kernel from scratch. Forge-specific work is
the workpiece lifecycle and semantic authority, not reimplementation of a
mature computational-geometry library.

Moving the same whole-growing-mesh calculation to a worker protects frames but
does not guarantee throughput. If compilation takes longer than commands arrive,
the backend still fails the flow-state requirement.

### Candidate C: sparse labelled field/SDF

A signed-distance field naturally supports:

```text
hard Add:       min(workpiece, tool)
Remove:         max(workpiece, -tool)
future blend:   smooth_min(workpiece, tool, radius)
```

The workpiece also needs co-registered material and semantic channels. It must
be sparse/chunked and update only affected chunks plus a boundary halo.

Test at minimum:

- 0.002 m;
- 0.001 m;
- 0.0005 m.

The result must preserve organic surfaces while retaining deliberate square
corners, 1 mm fillets, 0.5 mm clearances, thin walls, and holes. A uniform dense
grid or GDScript dictionary per fine voxel is not acceptable final storage.

Candidate meshers include Marching Cubes, Surface Nets, and sharp-feature Dual
Contouring. None is selected by this note.

### Candidate D: hybrid

A field may own materials/targeting/local edits while an exact compiler derives
the presentation/final mesh. This is valid only if preview, targeting, and final
geometry agree within explicit error bounds. Combining two authorities does not
automatically make the system safer.

### Selection gate

- Rolling absorption remains a useful lifecycle proof and bounded bridge, but
  the measured whole-workpiece Godot CSG refeed implementation is rejected as
  the final live authority for a mature workpiece. Its operation latency still
  grows with the complete accepted mesh.
- Instrument the refeed phases before replacing them so the next comparison
  separates command construction, Boolean/settle work, mesh extraction,
  analysis, and collision instead of assigning every cost to one opaque step.
- If exact rolling geometry is otherwise valuable, native Manifold may still
  be tested under the same command/snapshot contract. Moving an unchanged
  whole-workpiece algorithm to a worker is not, by itself, a scaling solution.
- If whole-workpiece exact processing continues scaling with mature geometry,
  move authority toward sparse/local chunks. The 5,000-operation stress result
  below has now triggered this branch.
- If field/SDF fidelity cannot preserve authored small and sharp features
  within memory limits, retain an exact or sharp-feature hybrid route.
- Do not select a backend from average FPS alone. Worst release hitch,
  throughput slope, and preview/final trust are decisive.

## Deterministic Benchmark WIP Contract

### Protected player reference assets

The benchmark must never alter or delete these live saved reference WIPs:

- `Test Glave`;
- `Test sword for animations`.

The benchmark never opens, saves, or rewrites the live player WIP library. Its
fixture and output use workspace-local ignored paths.

### Stable input, measured implementation

The fixed quantity is the logical command stream, not the backend's internal
scene-node count.

Reducing live operands is the experiment target, so operand/node/entity count
must be measured rather than forced equal across implementations.

Fixture schema 1 contains:

```text
one deterministic initial connected seed body (not counted as an operation)
100 deterministic accepted same-material Add operations
one fixed asymmetric five-vertex saved-profile cross-section
five fixed path samples per operation
fixed profile anchor/contact metadata
fixed raw normals and explicit B-to-C directions
fixed material, IDs, timestamps, spacing, coordinates, and ordering
zero random input
zero camera/mouse/UI dependency
zero player-save dependency
```

Scaling checkpoints:

```text
1, 10, 25, 50, 100 accepted operations
```

Optional later stress checkpoints:

```text
250, 500
```

The initial fixture intentionally uses one material and connected overlap to
isolate the current growing-tree failure before adding more semantic variables.

### Paired benchmark artifacts

1. A deterministic code generator is automation authority.
2. A generated `CraftedItemWIP` resource is inspection/load authority.

Current generated fixture path:

```text
C:\WORKSPACE\test_artifacts\forge_v2_workpiece_benchmark_wip.tres
```

It is intentionally not inserted into `user://` or the player WIP library.

### Benchmark lanes

Initial baseline:

- current permanent CSG-tree presentation;
- geometry/collision settling at the fixed checkpoints;
- material-volume truth against the same fixed bodies.

First candidate comparison:

- rolling accepted mesh from one baked base plus a bounded recent operation
  batch;
- exactly one accepted mesh and zero persistent operation CSG nodes after each
  acceptance.

Correctness companion lanes to add after the scaling baseline:

- asymmetric profile forward/reverse `T`;
- 90-degree bend;
- Add then VOID through-hole;
- second material with Replace and Empty Only;
- protected Handle overlap;
- deliberate disconnected island/split;
- persistence and bounded undo;
- Detailing C-surface case only after connected-surface/geodesic authority
  exists.

### Measurement contract

Every row records enough context for a fair comparison:

- fixture schema and deterministic signature;
- Godot version/build;
- backend ID/version;
- checkpoint and repeat;
- seed count, operation count, body count, and path samples;
- synchronous build/commit time;
- deferred settle time and worst observed frame gap;
- mesh bake time;
- collision bake time in a separate lane;
- CSG zone, node, combiner, and operand counts;
- output surfaces, vertices, indices, and triangles;
- output AABB and signed/absolute volume;
- watertight edge validation;
- connected-component count;
- material totals/occupancy signature;
- static-memory and object-count deltas when available;
- WIP save/load size and time;
- future worker queue depth, coalesced jobs, and rejected stale results.

Use a warmup, then at least five fresh measured repeats for decision-quality
data. A smoke run may use one repeat, but must be labelled as such.

Do not use raw mesh-array equality as the only cross-backend golden result;
valid backends may order vertices differently. Compare topology, AABB, volume,
material/semantic results, connected components, and defined tolerances.

### Success statement

The critical result is not merely “operation 100 completed.” It is:

> Operation 100 costs according to the current resolved workpiece and affected
> geometry, rather than replaying 99 permanent live construction operands.

Accepted steady-state entity count must be bounded. Preview and accepted
geometry must not flip, drift, open, lose material, mutate Handle authority, or
target stale collision.

No final millisecond budget is invented before the current hardware baseline
exists. Compare maximum hitch and scaling slope first.

## Benchmark Implementation And First Baseline — 2026-08-13

The deterministic fixture and current-backend runner now exist as isolated
tooling:

```text
res://tools/forge_v2_workpiece_benchmark_fixture.gd
res://tools/benchmark_forge_v2_workpiece_compiler.gd
C:\WORKSPACE\test_artifacts\forge_v2_workpiece_benchmark_wip.tres
C:\WORKSPACE\godot_runs\forge_v2_workpiece_benchmark_legacy.csv
C:\WORKSPACE\godot_runs\forge_v2_workpiece_benchmark_legacy.json
C:\WORKSPACE\godot_runs\forge_v2_workpiece_benchmark_legacy.txt
```

The fixture generator writes only to the explicit workspace path above. It
does not load or save `user://`, and it never opens the player WIP library.
`Test Glave` and `Test sword for animations` were not changed.

Repeat the decision-quality legacy baseline from PowerShell with:

```powershell
$env:FORGE_V2_BENCHMARK_MAX_OPERATIONS = '100'
$env:FORGE_V2_BENCHMARK_REPEATS = '5'
$env:FORGE_V2_BENCHMARK_COLLISION = 'true'
$env:FORGE_V2_BENCHMARK_MACHINE_LABEL = 'descriptive_machine_name'
$env:FORGE_V2_BENCHMARK_RUN_NOTES = 'controlled_run_conditions'
& 'C:\WORKSPACE\Godot_v4.7\Godot_v4.7-stable_win64.exe' `
  --headless `
  --path 'C:\WORKSPACE\The Will- main folder\the-will-gamefiles' `
  --script 'res://tools/benchmark_forge_v2_workpiece_compiler.gd' `
  --log-file 'C:\WORKSPACE\godot_runs\forge_v2_workpiece_benchmark_run.log'
```

For a cheap harness smoke test, set operation count and repeats to `1` and
disable collision. The generated inspection WIP remains the full immutable
100-operation fixture in both modes.

Fixture schema 1 has the following stable identity:

```text
fixture ID: forge_v2_workpiece_benchmark_v1
100 accepted operations + one seed
five path samples per body
saved WIP size: 272,896 bytes
full fixture signature:
7678c212840f785b26afb4cec3e84f1484aaa87b5ccc184dd8af51bbba40283d
```

The first decision-quality current-backend run used one warmup followed by
five fresh measured captures at every checkpoint. Collision baking was
enabled as a separate recorded phase. All 25 measured results were nonempty,
watertight, finite, nondegenerate, and exactly one edge-connected component.

First baseline summary on the current development machine:

| Accepted operations | Logical bodies including seed | Live CSG operands | Output triangles | Median node build | p95 worst settle-frame gap | p95 full capture |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 2 | 2 | 90 | 0.503 ms | 19.520 ms | 29.413 ms |
| 10 | 11 | 11 | 370 | 1.997 ms | 14.273 ms | 64.154 ms |
| 25 | 26 | 26 | 546 | 4.422 ms | 37.698 ms | 125.267 ms |
| 50 | 51 | 51 | 714 | 7.938 ms | 66.102 ms | 194.575 ms |
| 100 | 101 | 101 | 988 | 15.619 ms | 128.538 ms | 380.839 ms |

This confirms the representation problem without guessing: a single connected
resolved item still retains one permanent live CSG operand per accepted body.
At operation 100 the resolved boundary is only 988 triangles, yet the current
presentation holds 101 source operands, 102 CSG combiners, and 203 total CSG
shapes. The p95 settle hitch crosses 125 ms in this deliberately simple,
same-material case.

These values are a baseline, not a final performance budget. The run was
headless while a separate Godot editor instance was open, so future backend
comparisons must either reproduce that condition or capture a new labelled
baseline under identical controlled conditions. The JSON/CSV output carries a
machine label and free-form run note for that purpose.

The baseline proves the fixture, measurement path, topology gates, and
unchanged legacy-backend scaling needed to compare candidate compilers. The
isolated rolling experiment and its first measurements are recorded below.

## Candidate A Experiment - Bounded Rolling Built-In CSG

The first backend experiment now exists only under `res://tools`. It does not
route the live Forge, replace WIP persistence, or touch player saves:

```text
res://tools/forge_v2_rolling_csg_workpiece_backend.gd
res://tools/forge_v2_workpiece_benchmark_mesh_analyzer.gd
res://tools/benchmark_forge_v2_workpiece_compiler_rolling.gd
```

The experiment directly creates the deterministic seed mesh. Accepted
operation revision therefore starts at zero and excludes the seed. For every
subsequent command it builds one temporary CSG tree from:

```text
last absorbed base mesh + current bounded command batch
```

After Godot resolves that tree, the experiment retains one baked `ArrayMesh`,
publishes it through one `MeshInstance3D`, and deletes the complete temporary
CSG tree. The accepted steady state therefore has zero CSG operands.

The first candidate deliberately supports only:

- connected same-material Add;
- Replace Existing placement;
- saved-profile `PROFILE_PATH` sweeps;
- explicit surface B-to-C contact authority;
- Volume Stroke body provenance.

VOID, Empty Only, multiple materials, Handle bodies/protection, Detailing
Brush provenance, persistence, production targeting, and undo are rejected or
absent rather than being silently treated as proven.

### Absorption batch is not undo history

The tested absorption window controls how many recent commands participate in
one temporary compile before that result becomes the next base. It is not yet
the undo implementation.

A future five-action undo may keep a prior checkpoint plus five compact
commands, mesh snapshots, or dirty-region deltas. Those records need not remain
live CSG nodes. The benchmark must not call the batch size an undo guarantee.

### Independent oracle correction

The first sampled-surface comparison contained an invalid fixed barycentric
cutoff. It classified valid small triangles as having no interior and measured
centroid-to-edge distance, producing a false approximately `0.25 mm` error
even when oriented triangle signatures were identical. The cutoff is now tied
to the benchmark's actual triangle-degeneracy threshold.

The control with no absorption boundary through operation 10 then matched the
legacy oracle exactly at the `0.00001 m` signature scale, with approximately
`0.000000015 m` sampled numerical difference. The failed pre-correction
surface-distance interpretation is not evidence against the backend.

### Batch-window exploration

One-repeat exploratory runs used the same seed and 100-command stream:

| Absorption batch | Peak temporary operands | Operation-100 triangles | Result |
| ---: | ---: | ---: | --- |
| 1 | 2 | 1,304 | Failed: two degenerate triangles at operation 25 |
| 5 | 6 | 1,196 | Passed every checkpoint |
| 10 | 11 | 1,176 | Passed every checkpoint |
| 15 | up to 16 | 1,151 | Failed: one degenerate triangle at operation 100 |

The relationship is not monotonic: absorbing after every operation maximized
refeed cycles and triangle growth, while a larger batch did not automatically
become safer. Five was the lowest bounded batch that passed this fixture and
also produced the smaller compile/frame cost of the two passing candidates.

### Five-repeat window-five result

The provisional candidate was rerun with one warmup and five fresh measured
repeats. Collision generation was recorded separately. Every measured
checkpoint was deterministic, finite, nondegenerate, watertight, consistently
wound, genus zero, and exactly one connected component under the declared
authoring-scale topology gate.

| Accepted operations | Peak compile operands | Steady CSG operands | Candidate triangles | Legacy triangles | Candidate compile p95 | Candidate frame-gap p95 | Legacy frame-gap p95 | Legacy full-capture p95 |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 2 | 0 | 90 | 90 | 26.695 ms | 16.082 ms | 19.520 ms | 29.413 ms |
| 10 | 6 | 0 | 402 | 370 | 32.244 ms | 18.100 ms | 14.273 ms | 64.154 ms |
| 25 | 6 | 0 | 576 | 546 | 31.237 ms | 19.667 ms | 37.698 ms | 125.267 ms |
| 50 | 6 | 0 | 774 | 714 | 30.986 ms | 16.445 ms | 66.102 ms | 194.575 ms |
| 100 | 6 | 0 | 1,196 | 988 | 31.309 ms | 21.922 ms | 128.538 ms | 380.839 ms |

At operation 100 this is approximately a `5.9x` reduction in the measured p95
worst frame gap and a `12x` reduction when candidate operation compile p95 is
compared with legacy full-capture p95. These are controlled headless benchmark
figures on the current development machine, not promised gameplay budgets.

The operation-100 candidate differs from the all-at-once legacy surface by at
most approximately `0.000005505 m` in the sampled comparison. Relative volume
error is approximately `0.0000000042`, AABB remains inside the `0.00001 m`
gate, and topology matches. Triangle count is about `21%` higher, so bounded
operands do not imply bounded mesh complexity.

Decision-quality candidate outputs:

```text
C:\WORKSPACE\godot_runs\forge_v2_workpiece_benchmark_rolling_window_5_strict_five_repeat.csv
C:\WORKSPACE\godot_runs\forge_v2_workpiece_benchmark_rolling_window_5_strict_five_repeat.json
C:\WORKSPACE\godot_runs\forge_v2_workpiece_benchmark_rolling_window_5_strict_five_repeat.txt
```

The final confirmation adds a second topology lane welded at `0.0000001 m`,
close enough to catch cracks or vertex collapses hidden by the authoring-scale
`0.00001 m` comparison. Across all five repeats and all checkpoints, that
strict lane also reports one watertight component, zero boundary edges, zero
nonmanifold edges, zero directed-edge mismatches, and zero weld-collapsed
triangles.

A separate focused backend verifier reports 14/14 checks passing. It confirms
seed revision zero, exact window-five promotion, peak six/steady zero CSG
operands, and transactional rejection of VOID, Empty Only, Handle, and a
second material. Every rejected command leaves revision, base, pending batch,
source count, material, mesh identity, triangle count, and geometry signatures
unchanged:

```text
res://tools/verify_forge_v2_rolling_csg_workpiece_backend.gd
C:\WORKSPACE\godot_runs\verify_forge_v2_rolling_csg_workpiece_backend.txt
C:\WORKSPACE\godot_runs\verify_forge_v2_rolling_csg_workpiece_backend.json
```

A 100-cycle no-op refeed control isolates baking from Boolean composition.
Feeding one unchanged accepted mesh through a one-operand transient CSG root
causes one initial raw ArrayMesh byte-layout canonicalization, then the raw
signature stays stable from cycles 1 through 100. Geometric oriented and
unoriented signatures match the direct seed at every checkpoint. Triangle
count remains 46, AABB delta is zero, volume delta is approximately
`1.08e-19 m3`, sampled surface delta is approximately `1.49e-8 m`, and both
strict and authoring-scale topology lanes remain valid:

```text
res://tools/verify_forge_v2_rolling_csg_noop_refeed.gd
C:\WORKSPACE\godot_runs\verify_forge_v2_rolling_csg_noop_refeed.txt
C:\WORKSPACE\godot_runs\verify_forge_v2_rolling_csg_noop_refeed.json
```

Therefore the candidate's triangle growth is associated with repeated Boolean
composition, not with repeatedly baking an unchanged mesh by itself.

### Connected-raster stress experiment through operation 5,000

The fixed 100-operation benchmark is deliberately small. A separate
stress-only fixture and streaming runner were therefore added under
`res://tools`:

```text
res://tools/forge_v2_workpiece_stress_fixture.gd
res://tools/benchmark_forge_v2_workpiece_compiler_rolling_stress.gd
```

This is not the immutable 100-operation WIP with its count increased. Extending
that fixture would have produced an artificial approximately four-metre slab
outside the intended authoring bounds. The stress fixture instead streams one
body at a time through a deterministic, connected, serpentine raster inside the
workspace. It uses a direct seed, a fixed asymmetric saved profile, one iron
material, connected Add/Replace operations, explicit normals and B-to-C
directions, and no camera, mouse, player-save, or WIP-library dependency. It
does not retain a 10,001-body array in memory.

The planned range was 10,001 accepted operations. Separate complete runs at
100 and 1,000 operations established staged checkpoints before the long run:

| Completed run | Final triangles | Recent compile p95 | Recent frame-gap p95 | Total elapsed | Result |
| ---: | ---: | ---: | ---: | ---: | --- |
| 100 | 4,414 | approximately 61.75 ms | approximately 42.75 ms | 3.68 s | Passed; strict watertight single component |
| 1,000 | 16,812 | 187.677 ms | 165.580 ms | 106.204 s | Passed; strict watertight single component |

The 10,001-target run was intentionally stopped by the operator immediately
after the operation-5,000 checkpoint because the scaling pattern was already
decisive. It was not a harness abort and it is not a completed 10,001-operation
result. At the stop point:

```text
accepted revision:               5,000
peak temporary CSG operands:     6
steady accepted CSG operands:    0
recent compile p50:              760.802 ms
recent compile p95:              850.392 ms
recent compile p99:              911.475 ms
recent compile maximum:          1,009.502 ms
recent harness frame-gap p95:    811.729 ms
elapsed time:                    1,964.607 s
```

The bounded entity goal succeeded: the backend still used at most one baked
base plus five pending operands and returned to zero live CSG operands after
acceptance. The flow-state goal failed. From operation 100 through 5,000, a
linear fit to recent compile p95 has a slope of approximately `0.160 ms` per
additional accepted operation and `R2 ~= 0.9987`. Frame-gap p95 follows a
similarly strong linear trend. Because per-operation cost grows approximately
linearly, cumulative elapsed time grows approximately quadratically; its fitted
curve has `R2 ~= 0.999998` over the measured range.

This distinguishes two different scaling problems:

```text
rolling absorption solved:  permanent history/SceneTree operand growth
rolling absorption did not solve: each new Boolean reprocessing the growing
                                  accepted whole-workpiece mesh
```

Normal sampled Godot static memory followed approximately:

```text
61.85 MiB + (0.002441 MiB * accepted operation count)
```

That fit excludes collision checkpoints. The operation-5,000 checkpoint
sample briefly reached `86.2 MiB`, while the preceding ordinary sample was
approximately `73.8 MiB`. This is consistent with temporary checkpoint
analysis/collision allocation, but the current sampling cannot prove its exact
cause. These figures are Godot static memory, not OS working set, GPU memory,
or a continuous allocation trace.

A quadratic extrapolation projects operation 10,001 at approximately
`2 h 06 min` total elapsed time. That value is only a planning signal: no
operations from 5,001 through 10,001 were measured. Raster turns, later
topology, allocator behaviour, or harness gates could have changed the curve.

Analysis artifacts, including latency, cumulative-time, interval-throughput,
and sampled-memory charts, are isolated in:

```text
C:\WORKSPACE\godot_runs\forge_v2_workpiece_rolling_stress_5000_analysis.report.md
C:\WORKSPACE\godot_runs\forge_v2_workpiece_rolling_stress_5000_analysis.metrics.json
C:\WORKSPACE\godot_runs\forge_v2_workpiece_rolling_stress_5000_analysis.samples.csv
C:\WORKSPACE\godot_runs\forge_v2_workpiece_rolling_stress_5000_analysis.*.svg
```

#### Interpretation and harness limits

- This is one deterministic, same-material connected-Add stress shape. It does
  not cover VOID, multiple materials, Handle priority, Detailing geodesics,
  persistence, undo, or player-facing viewport input.
- The 5,000 capture is an operator-stopped partial run. The original runner
  wrote its compact final JSON/CSV/TXT only at normal termination, so the
  engine log and copied heartbeat are the authority for the partial tail.
- `frame-gap p95` is a headless process-frame measurement, not viewport FPS or
  direct input-latency telemetry.
- Geometry analysis and collision checkpoints add work to cumulative elapsed
  time. The current heartbeat does not fully separate operand construction,
  Boolean settle, extraction, analysis, and collision phases.
- The runner reached the operation-5,000 checkpoint without a reported
  topology/invariant failure, but its collision lane was observational rather
  than a sufficiently explicit independent correctness gate.
- The 5,000 checkpoint pulse and partial-run label exposed harness weaknesses.
  The tools-only runner is now schema 2: future checkpoints persist atomically
  under a unique run ID as they occur; timing bins retain node-build, settle,
  static-bake, and surface-consolidation phases; required collision checkpoints
  must produce collision faces; output-write failures fail the run; and metric
  scopes explicitly distinguish headless pre-bake settle gaps, quantized
  edge-manifold checks, and sampled Godot static memory. A collision-enabled
  100-operation smoke passed this hardened path. In that diagnostic run, the
  final 100-operation bin measured approximately `0.752 ms` node-build p95,
  `58.974 ms` deferred-settle p95, `0.002 ms` static-bake p95, and `1.647 ms`
  surface-consolidation p95. This identifies Godot's deferred CSG settlement
  as the dominant early phase; `bake_static_mesh()` only retrieves the already
  resolved root mesh. These improvements do not retroactively create the
  missing detailed operation-5,000 checkpoint row or prove that every later
  phase keeps exactly the same share.

#### Decision from this experiment

Window-five rolling absorption is retained as a useful bounded bridge,
correctness oracle, and proof that accepted strokes need not remain permanent
CSG entities. The tested **whole-workpiece Godot CSG refeed is rejected as the
final live geometry authority for a mature Forge V2 workpiece**. It can still
be useful for small proofs or controlled offline/reference compilation, but it
does not meet the seamless authoring requirement as the accepted mesh grows.

The next geometry experiment must bound the edited spatial region as well as
the live operand count. First harden the harness and instrument phase timings;
then prototype a sparse/chunked labelled solid or SDF authority that remeshes
only intersecting chunks plus a boundary halo. Re-run this identical raster so
success means the latency curve stays approximately flat for equal local edits,
not merely that operation 100 becomes cheaper.

Background compilation remains supplementary. It may protect input and render
frames through immutable jobs, coalescing, and atomic publication, but moving
the same growing whole-workpiece computation off the main thread does not fix
throughput or stale-result pressure.

### What this proves and what it does not

It proves that the simple same-material connected-Add fixture can be presented
as one accepted mesh with zero persistent CSG operands, while compile cost no
longer follows the number of historical strokes in the same way as the legacy
tree.

It also proves that bounded live operands do not produce bounded live-edit
cost. The 5,000-operation connected raster meets the stop condition declared
for Candidate A: main-thread hitches and cost against the consolidated mesh
rise far beyond an interactive authoring budget. Whole-workpiece Godot CSG
refeed is therefore not awaiting production selection; it is rejected as the
final mature-workpiece live authority.

The lifecycle pattern remains useful, but the next backend still needs:

- Add/VOID depth and through-hole parity;
- multi-material and buried-material ownership;
- Replace and Empty Only ordering;
- protected Handle authority;
- persistence, bounded undo, and revision-safe collision/targeting;
- curved/detailing/manual visual cases;
- the same 5,000-operation stress comparison with spatially local work.

No result in this section routes a candidate into production.

## Experiment And Integration Order

1. **Complete:** Generate and verify the immutable 100-operation benchmark
   WIP.
2. **Complete:** Capture the unchanged current permanent-tree baseline at
   fixed checkpoints.
3. **Complete for the experiment:** Define the isolated rolling backend seam
   without routing the production Forge through it.
4. **Complete for the narrow Add lane:** Build the isolated rolling-bake
   compiler.
5. **Complete for connected single-material Add:** Replay the exact same
   benchmark commands and compare counts, latency slope, topology, volume,
   material summary, and bounded state.
6. **Complete for the scaling decision:** Build the separate streaming,
   connected-raster stress fixture; complete staged 100/1,000 runs; and stop
   the 10,001-target run after its operation-5,000 checkpoint.
7. **Complete:** Retain rolling absorption as a bounded lifecycle bridge but
   reject whole-workpiece Godot CSG refeed as the final live authority for a
   mature workpiece.
8. **Complete for future runs:** Harden the stress harness with unique run
   artifacts, atomic partial checkpoints, output-write failures, explicit
   collision gates, honest metric scopes, and separate node-build, settle,
   static-bake, consolidation, analysis, and collision timings.
9. Build a sparse/chunked labelled-solid or SDF proof that updates the edited
   region and halo rather than refeeding the whole workpiece.
10. Replay the identical raster and require a substantially flatter latency
    curve for equal local edits, while preserving topology and dimensions.
11. Add Add/VOID/material/Handle correctness lanes to the viable local
    authority. Test native exact processing where it provides useful parity or
    sharp-feature support, not as an assumed cure for whole-body throughput.
12. Integrate the selected compiler behind a fallback/selectable boundary,
    beginning with CSG Material Stroke only.
13. Add bounded undo/checkpoints.
14. Add canonical connectivity and the Island Inspector.
15. Build the finalized runtime asset/profile pipeline from the same accepted
    workpiece revision.
16. Add revision-safe background/coalesced compilation only after synchronous
    correctness; treat it as responsiveness infrastructure, not a substitute
    for local-update scaling.

## Verification Gates

### Geometry

- closed/manifold output;
- finite, nondegenerate triangles;
- intentional through-holes preserved;
- no missing shell faces or visible gaps;
- authored asymmetric profile orientation preserved;
- preview and accepted geometry agree;
- small features remain within defined tolerance;
- component count is correct.

### Materials and semantics

- same-material overlap counted once;
- buried material survives and reappears after cuts;
- Replace, Empty Only, and VOID remain ordered;
- protected Handle volume survives every ordinary operation;
- geometry and material ledger describe the same result;
- exact Handle records remain available.

### Performance and flow

- accepted live entity count remains bounded;
- worst release hitch is captured;
- cost slope is compared at 1/10/25/50/100;
- no unbounded background queue;
- targeting never silently uses stale geometry;
- save/load does not reconstruct permanent stroke CSG trees.

### Runtime

- processed mesh has no authoring CSG dependency;
- collision is appropriate for runtime use;
- BakedProfile/gameplay facts share source revision with geometry;
- Storage, equipment, and Skill Crafter consume the lightweight processed
  payload;
- WIP remains independently editable.

## NEEDS_DECISION

Do not guess these during the first prototype:

- exact backend and final solid representation;
- acceptable maximum release hitch and compile throughput budget;
- exact first-seed tool and UI;
- whether transparent workspace-box faces may ever remain valid targets after
  the seed exists;
- whether normal Add is rejected immediately when it would create a floating
  component or whether temporary floating Add is allowed during WIP editing;
- contact/overlap tolerance that counts as structural connectivity;
- behavior when seed-containing and largest-volume components differ;
- whether Detailing shortest-surface paths may route around hidden/back faces;
- final seam-blend range and cross-material ownership;
- final authoring geometry resolution and mesher;
- five, ten, or fifteen undo actions after memory/latency measurement;
- runtime mesh simplification tolerances for material and Handle boundaries.

## Honest Boundary At Creation

This document establishes the architecture and benchmark contract. The
fixture/runner establishes a repeatable current-backend baseline. The isolated
tools-only rolling compiler proves that permanent stroke CSG entities can be
absorbed into a bounded accepted state, but the 5,000-operation stress evidence
rejects its whole-workpiece Godot CSG refeed as the final live authority for a
mature workpiece. The next candidate is a spatially local/chunked labelled
solid or SDF proof under the same command/snapshot and benchmark contract.

Nothing in this document routes the experiment into the production Forge,
changes WIP persistence, or selects the final backend. The 10,001-operation
projection is not a completed measurement.

The following remain separate active or benched work and must not be silently
folded into the benchmark:

- Remove-material B-to-C depth reflection;
- Detailing Brush surface geodesics;
- seam/vacuum-bag tuning;
- Spline/Handle magnetic orientation and shadow preview;
- Handle gameplay/equip recognition;
- target-plane removal and seed UI;
- Island Inspector;
- finalized V2 runtime asset generation.

No commit or push is implied by this note.
