# Skill Crafter playtest audit - 2026-10-23

## Current audit outcome

The slow preparation is reproduced on the user's actual saved Skill 1 in an
isolated library. **Grip acquisition dominates; trajectory sampling and file
writing do not.** Fresh F took 38.388 s; fresh Save took 34.580 s. Existing saved
poses and fresh prepared poses both contain steep arm/hand rotations. No solver
fixes were made. The original library remains byte-identical. UI recreation in
Slot 2 is recorded but is not an equivalent copy; do not publish it as one.

## Scope and authority

User-authorized investigation/playtest, **not a fixing pass**. Preserve the good
calculations; identify why preparation is slow and document mechanical issues
before deciding changes. Trajectory guides are accepted as an approximation for
now; guide accuracy is deferred. Do not interpret this audit as a solver rewrite
or authorization to change joint limits, sampling rate, grip policy or anatomy.

Read current saved Skill 1, recreate its authored movements in Skill 2 through
the normal Skill Crafter editing/input paths, and test Skill 2. Do not copy a
draft/clip into Skill 2 or silently replace the current skill with the earlier
generic fixture. Keep the user's Skill 1 unchanged. Record full skeleton state
and arm axial rotation during recreation and replay. Expose missing or surprising
restrictions as findings, not automatic changes. One substantial Godot run at a time.

## Evidence and preservation

- Project: `C:/WORKSPACE/The Will- main folder/the-will-gamefiles`, Godot 4.7.
- Original library: `C:/Users/ixro1/AppData/Roaming/Godot/app_userdata/The Will-Gamefiles/forge/player_wip_library_state.tres`.
- Initial SHA256: `cd17f90751f905aed66d07511463ea19bc3181cc17eaecbda6f25af8c0c32379`.
- Read-only source backup: `godot_runs/skill_frame_cost_20261023/source_library_before.tres`.
- Resource inspection: `godot_runs/skill_frame_cost_20261023/source_inspection.json`.
- Read-only inspector: `godot_runs/skill_frame_cost_20261023/inspect_saved_skill.gd`.
- Existing preparation profiling is enabled only for diagnostics; no production
  solver behavior has been changed for this audit.
- Initial process check found no running Godot process. Initial Git status was
  dirty; preserve all preexisting work. No Git mutation is authorized.

## Saved Skill 1 as inspected

Weapon `Broken_Balde_v1`, WIP `player_wip_1792291462.519_14`. The current file is
not the old twenty-node fixture. Skill 1 has hidden node 0 plus five visible
nodes. Stored transitions after node 0 are 0.20, 0.30, 0.20, 0.10 and 0.15 s,
totalling **0.95 s**. Its stored solved clip contains **58 frames at 60 Hz**.
Preview speed is **0.11**, acceleration setting 100 and deceleration setting 70.
Playback speed and nominal compiled timeline duration are distinct quantities.
All authored nodes use right primary hand, normal grip, single-hand state;
later nodes also author the free left hand proxy. No grip-style bridges appear
in this saved chain.

| Node | Incoming duration s | Grip station | Body support | Right arm roll deg | Left arm roll deg | Weapon roll deg |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 0 hidden | excluded from duration sum | .20 | .4 | 0 | 0 | 0 |
| 1 | .20 | .50 | 1 | -115.356625 | 0 | 0 |
| 2 | .30 | .50 | 1 | -115.356625 | -173.343621 | 0 |
| 3 | .20 | .50 | .8 | 170.177145 | -175.108863 | -52.5 |
| 4 | .10 | .50 | 1 | -154.014474 | 131.207111 | -185.905670 |
| 5 | .15 | .50 | 1 | -154.014474 | -114.269642 | -164.003798 |

These are saved authored control values, not anatomical joint-angle measurements.
The user's approximately one-prepared-frame-per-second report concerned earlier
manual testing; it has not yet been independently reproduced in this audit.

## Frame-generation facts from current code

1. Station UI explicitly requests **60 Hz** (`combat_animation_station_ui.gd:102,5200`).
   The generic baker's default is 30 Hz, but the station overrides it.
2. Duration is summed from compiled node index 1 onward, with a 0.01 s minimum
   per transition (`combat_runtime_clip_baker.gd:104`). Hidden node 0 contributes
   the starting pose; its own incoming duration is excluded. Generated bridge
   durations can matter when present.
3. Sampling advances a synthetic clock by 1/60 s, includes time zero and the
   exact final pose (`combat_runtime_clip_sample_job.gd:24,43-60`). A compiled
   3.000 s clip therefore has 181 samples. Current saved .95 s clip has 58.
   Display FPS does not determine this count.
4. Playback speed does not alter sampling density: sampling runs its chain player
   at speed 1.0. Replay advances by real delta multiplied by playback speed and
   interpolates cached results. Display cadence and preparation throughput are
   separate from the fixed sample count.
5. A prepared frame is a solved snapshot: sampled controls, body/arm/weapon
   evaluation, legality/contact/grip work, then bones/weapon/anchors captured.
   It is not a screenshot or merely a point on a curve.
6. F uses a nominal 20 ms cooperative work budget. The budget is checked after
   a complete pose frame; one expensive frame can exceed it. Editor/bake state
   is captured/restored between batches. A `process_frame` yield lets normal
   input/rendering run. There is no explicit one-second sleep per prepared frame.
7. Incremental reuse preserves an exact unchanged prefix at a validated
   checkpoint (30-sample spacing), then recomputes the dependent suffix. It
   does not establish an arbitrary fixed three-node dependency window.
8. Save can reuse a valid prepared active clip, but may prepare active skill and
   combat idle synchronously before writing the file. F batching does not alone
   imply shorter Save duration. Measure render and file-write time separately.

## Findings to test, not fixes

### A. Hidden entry changes grip station

**Observed in the saved clip:** frames 0-12 request thirteen distinct stations
from .20 to .50 in .025 steps, at times 0 through .20 s. Later samples remain .50.

**Code:** `combat_animation_chain_player.gd:915` interpolates grip station.
`preview_grip_acquisition.gd:14,1099` includes station in the relationship key
with a 1e-7 m identity grid. Missing relationships use synchronous acquisition
(`:270,600`). End clearance may clamp some requested stations to the same actual
position, and warmed relationships may already exist.

**Hypothesis:** repeated grip acquisition during the hidden entry may dominate
preparation. Do not translate thirteen requested stations into thirteen proven
full solves. Need actual solved/reused relationship counts, stage time and frame
progress from the current test.

### B. Angular wrap crossings

**Observed authored data:** right arm -115.36 -> +170.18 -> -154.01 degrees;
left arm -175.11 -> +131.21 -> -114.27 degrees. Those values cross signed-angle
boundaries. The chain player uses scalar `lerpf` for upper-arm control values.

**Question:** does playback command a long rotation between nearby orientations
across the boundary? Capture quaternions and intermediate values before attributing
the elbow inversion to this. Saved controls alone do not establish actual skin
twist, elbow plane legality or a complete root cause.

**Confirmed command-path detail from the stored samples:**

| Segment | Arm | Sampled command travel | Short equivalent | Prepared frames |
| --- | --- | ---: | ---: | --- |
| 2 -> 3 | Right | +285.533770 deg | -74.466230 deg | 30 -> 42 |
| 3 -> 4 | Right | -324.191619 deg | +35.808381 deg | 42 -> 48 |
| 3 -> 4 | Left | +306.315974 deg | -53.684026 deg | 42 -> 48 |
| 4 -> 5 | Left | -245.476754 deg | +114.523246 deg | 48 -> 57 |

For example right frame 42 is +170.177139, frame 45 is +8.081335 and frame 48
is -154.014481 degrees. The intermediate values really pass through zero.
UI endpoints wrap to +/-180 (`combat_animation_station_ui.gd:1125,8200`),
the chain player scalar-interpolates them (`combat_animation_chain_player.gd:918-919`),
and the rig wraps each instantaneous correction, not the whole node-to-node
trajectory (`player_humanoid_rig.gd:4827-4888`). This confirms long **elbow-orbit
commands around shoulder-to-hand**, not a measurement of Upperarm bone twist.
Short equivalents in this table explain the geometry; no shortest-path rule
has been implemented or selected as a fix. Multiple-turn authoring intent and
actual bone response would need consideration before choosing such a rule.

### C. UI recreation and constraint consistency

Numeric position fields snap to 0.01 m; orientation fields to 0.5 degrees and arm
roll to 1 degree. Mouse-authored saved values have finer precision. The saved
last tip curve-in Y is about -2.1197171, outside its numeric field's -2 range.
Free-hand proxies have viewport controls but no equivalent numeric fields.

Use actual UI editing/drag handlers for full-precision requests, preserving all
existing constraints and readiness waits. This is automated UI-owner input, not
manual OS cursor manipulation. Do not set Resource fields or change UI ranges
to force a match. Hidden node 0 is generated from the hand-mounted weapon seed
and cannot be selected through the normal timeline. Verify its natural result;
do not overwrite it. Record any resulting mismatch before claiming equivalence.

## Runtime measurements and full-skeleton observations

Two bounded recreation runs completed; neither has yet established an equivalent
Slot 2. No timing/Save result is being passed off as an exact replica.

Evidence: `godot_runs/skill_frame_cost_20261023/ui_replica_01/results/` and
`ui_replica_02/results/`. Run 2 completed all five visible nodes in 66.402 s,
including scene setup, readiness waits, logging and screenshots. **This is not
skill-render time.** It captured 47 full-skeleton states, each with 77 bones;
offline matrix/topology analysis found no malformed records.

| Visible node | Tip mismatch | Pommel mismatch | Other final differences |
| --- | ---: | ---: | --- |
| 1 | 9.72 mm | 42.04 mm | none in compared controls |
| 2 | 40.45 mm | 108.09 mm | none in compared controls |
| 3 | 44.60 mm | 130.44 mm | orientation changed |
| 4 | 88.27 mm | 197.27 mm | orientation changed; Roll clamped by 17.06 deg |
| 5 | 10.45 mm | 8.69 mm | orientation changed |

Reset also generated a different hidden starting pose: 1.2072 m tip difference
and 0.5007 m pommel difference. The stored source hidden node cannot simply be
selected and edited through the timeline. Full hidden-entry equivalence remains
unproven. The automation uses real UI-owner commands with current constraints;
edit order/history may explain some visible-node differences. These figures do
not establish that all manual reconstruction is impossible.

The isolated in-memory Skill 1 changed only its **derived cache** in this run:
`baked_runtime_clip` became null and `runtime_cache_signature` became empty.
The compared authored Skill 1 fields did not change. The original library file
and source backup remained unchanged. The conservative full-resource guard
reported false because it includes those cache fields; that is not evidence of
lost manual authoring.

Readiness was `preview_applied`, but status also reported
`actual_3d_grip_verified = false` and `contact_condition_met = false` in run 1.
A visible applied pose is therefore not a certified full grip. This audit waits
for acquisition to finish; it does not silently turn that status into success.

Capture all bone names/parents/rests,
then local position/quaternion/scale and global transforms at semantic editing
steps and replay samples. Avoid full-skeleton logging inside every solver
iteration because that would contaminate timing. Local-axis twist is descriptive;
use declared rest/baseline axes and do not label Euler values anatomical limits.
Near straight extension, the elbow plane normal is numerically ill-conditioned.

Report input sampling, pose preparation, grip solve/reuse, checkpoint overhead,
wait time, Save render/idle/file phases, cached F, and source-preservation checks.
If recreation cannot match the source through existing controls, report the
specific obstacle and do not pass off an altered fixture as the same skill.

## First measured performance breakdown: UI-created Slot 2

Run `ui_replica_03` deliberately continued through F and Save **with its known
recreation differences explicitly retained**. It is not an exact Slot 1 timing.
The user subsequently authorized an isolated runtime test of the unchanged
original Slot 1 as well; that comparison is the next measurement.

| Operation / component | Measured time |
| --- | ---: |
| First F, 58 prepared frames | 36.287 s wall |
| Sampling all 58 control/trajectory frames | 17.862 ms work; 47.382 ms wall |
| Grip preparation within pose bake | 31.320 s |
| Apply body/weapon pose across all frames | 402.419 ms |
| Bone/weapon/anchor capture across all frames | 6.382 ms |
| Recorded editor/working checkpoint capture and restore | 2.474 s total |
| Repeat F without editing | 73.131 ms to playback start |
| Save after F | 4.439 s wall |
| Save's authoring restoration/readiness phase | 3.372 s |
| Save's actual file persistence phase | 285.038 ms |

Pose preparation counted **11 newly solved grip relationships and 47 reused
relationships**. The thirteen requested stations are .20, .225 ... .475, .50;
the endpoints were already available in this run. New intermediate stations
cost roughly 2.8-3.2 s apiece. After reaching the steady .50 station, per-slice
wall progress was roughly 80-90 ms. The grip work accounts for about **86% of
first-F wall time**, whereas the measured trajectory sampling is about 0.05%.
This is direct evidence for this fixture, not a universal per-frame rate.

The nominal 20 ms budget is not a hard deadline: maximum measured pose slice
was **3.204 s** and maximum process-frame interval during preparation **3.233 s**.
The budget cannot interrupt a synchronous grip solve already inside one frame.
The editor can process input between slices, but not during those long calls.

Save reused the active 58-frame clip, rendered a one-frame combat idle, and
spent most of its time restoring/waiting for the live authoring grip. The cached
F result metadata still contains the preceding cold-F profile; it is stale
metadata for timing purposes, not another measured 36 s render. The diagnostic
times the actual second F invocation separately.

### Isolation and preservation finding after Save

The isolated Save also refreshed **Slot 1 retarget metadata** for its nodes
(pivot directions/ranges and floating-point weapon lengths), in addition to the
cache clearing observed when opening. Original direct authored endpoint/angle
controls were not identified as changed in the recorded comparison. Nevertheless,
Slot 1's whole Resource is not preserved by that isolated Slot 2 workflow.
Do not publish this test library as though Slot 1 were untouched. The real user
library remains byte-identical to the initial SHA256.

The first diagnostic versions retained initial `complete/ok=false` flags because
Dictionary.merge did not overwrite them. `reason`, terminal log and evidence
files identify their actual completion; this reporting-only issue is corrected
in the helper for subsequent runs. Run 3's preservation guard genuinely failed
on the derived retarget differences described above; no production fix was made.

## Exact saved Skill 1: fresh runtime verification

Explicit user approval received to run the original saved skill in an isolated
library. Runs `exact_source_F_01` and `exact_source_Save_01` load the same backed-up
weapon and select Skill 1 through the normal station. No node controls are edited.
The pre-operation authoring comparison passed; both runs completed, and the
post-Save manual-control comparison passed. Retarget snapshots and prepared clips
are allowed to be rebuilt by the existing application and are recorded separately.

| Operation | F-first run | Save-first run |
| --- | ---: | ---: |
| Fresh preparation and operation completion | F: **38.388 s** | Save: **34.580 s** |
| Grip work inside active-skill preparation | 33.696 s | 33.120 s |
| New / reused grip relationships | 12 / 46 | 12 / 46 |
| Body/weapon pose application, all 58 samples | 407.076 ms | 376.901 ms |
| Control/trajectory sampling work | 17.910 ms | 21.167 ms including synchronous sampling phase |
| Pose data capture, all 58 samples | 6.210 ms | 5.848 ms |
| Recorded checkpoint capture/restore | 2398.604 ms | 7.166 ms |
| Repeat F without edits | 64.010 ms | 69.586 ms after Save |
| Save after already prepared F | 4.329 s | n/a |
| File persistence | 303.556 ms after F | 278.593 ms |
| Maximum process-frame interval during operation | F: 3183.516 ms | Save: 33997.568 ms |

These are two focused full-scene runs, not a statistical benchmark. Live playback
has full-skeleton diagnostic capture overhead; its display FPS is not being used
as a production performance measurement. Preparation timing is taken before that
playback logging. F checkpoints/yields explain additional overhead relative to
synchronous Save; the runs also have ordinary execution-time variation.

**Output comparison:** the fresh F and fresh Save runs produced float32-exact
matches for all 22 compared sampled-control arrays and all 14 compared solved
output arrays, including all 50 bones across 58 samples, the weapon and six
anchors. Timing differs; the prepared motion agrees in these runs. Evidence:
`fresh_F_vs_cold_Save.json` and `.md` under the evidence root.

### What makes one new relationship expensive

In the Save-first run's completed bake checkpoint, thirteen cached relationships
are present: one acquired before timing at the selected visible node, plus twelve
new relationships during preparation. Do not double-count their duplicate presence
in the combat-idle checkpoint. For the twelve new acquisitions, their own nested
timers sum to:

- Anatomy/posed-carrier preparation: **14.072 s**.
- Initial seat candidate search: **3.482 s**.
- Coupled whole-hand fitting: **13.594 s**.
- Complete acquisition timers: **32.675 s**; outer grip timer includes additional
  cache/application/assessment overhead and is 33.120 s.

Individual new acquisitions took 2.272-2.995 s. Each performs many candidate and
derivative pose evaluations, not a single nearest-point query. Existing C++ code
accelerates skin-point batches, surface queries and intersections. The GDScript
orchestration and optimization work remains. Anatomy has an existing static cache;
this evidence does not mean that every geometry step is uncached.

`preview_grip_acquisition.gd:227` checks a relationship key containing exact local
station, hand/anatomy, geometry identity/epoch and grip style. World pose and Roll
are intentionally excluded. An unseen station reaches `_run_next(true)` and the
acquisition worker synchronously. Ordinary authoring uses its threaded wrapper.
The bake's outer 20 ms budget cannot preempt that synchronous work.

All thirteen captured relationship statuses in this run have
`actual_3d_grip_verified=false` and `contact_condition_met=false`, despite pose
application and successful clip preparation. Record the distinction; it is not
an instruction to reject the user's visually acceptable weapon or alter grip
acceptance during this audit.

### Duration scaling

Longer nominal timeline duration creates more 60 Hz samples. If the added time
is spent at an unchanged grip station, cached grip reuse makes those samples
much cheaper. If added time stretches a changing grip station, it introduces
more distinct interpolated stations and can multiply expensive acquisitions.
For example, an unclamped .20-to-.50 transition lasting .20 s requests thirteen
stations; at 1.00 s it requests sixty-one. That is a code-derived illustration,
not another measured run or a guaranteed number of cache misses.

## Mechanical evidence: whole skeleton and actual prepared output

Run 2 captured 47 authoring states; run 3 captured 328 states including replay;
the exact F run captured 333 states; the exact Save run captured 170. Each state
contains all **77 model bones**, local/skeleton/world transforms and rest data.
Each output animation stores **50 tracked bones**. Offline analysis reported no
malformed capture records. Large changes between different UI operations are
kept separate from changes between animation samples.

The original saved clip's quaternions were inspected directly. The fresh F clip
also shows steep changes in the same regions:

| Bone / interval | Original local change | Fresh F local change | Fresh F skeleton-space change |
| --- | ---: | ---: | ---: |
| Right Forearm, frames 0 -> 1 | 165.217 deg | 168.425 deg | 177.363 deg |
| Left Hand, frames 43 -> 44 | 168.511 deg | 160.012 deg | 164.246 deg |
| Left Forearm, frames 45 -> 46 | 109.085 deg | 104.499 deg | 41.971 deg |
| Right Upperarm, frames 48 -> 49 | 77.362 deg | 78.664 deg | 37.072 deg |

These are quaternion orientation distances between prepared samples 1/60 s apart,
using normalized quaternions and absolute dot products. They are not Euler-angle
wrap artifacts. Parent/child compensation reduces some apparent local changes,
but others remain large in skeleton space. Live playback interpolates between
samples; the table does not assert a single instantaneous on-screen jump.

The original frame 0 -> 1 Right Forearm event is not an undefined straight-elbow
normal: reconstructed inner angles are 113.235 -> 65.596 degrees and plane-cross
magnitudes approximately .07425 -> .07358 m2. This establishes significant saved
pose movement, not the complete cause of the user's manual extension/retraction
inversion. The separate signed elbow-orbit interpolation finding above remains
a concrete command-path problem to review.

Current bake completion (`combat_animation_pose_bake_job.gd:514`) validates track
availability/counts and reports anchor metrics. It does not establish anatomical
continuity or reject these steep adjacent rotations. **A successfully prepared
clip is not an anatomical pass.** No new angular-velocity limit has been invented.

The original stored clip and the fresh prepared clip are not numerically identical.
Their sampled controls differ in only seven float components at frame 30 (maximum
position-component difference about 0.00000203 m), but the resulting weapon poses
differ by up to 36.884 mm and 26.632 degrees at different frames. Some local bone
differences are much larger and partly compensated by parent rotations. Evidence
is retained in `original_vs_fresh_F.json` and `.md`. This comparison does not
identify the cause: historical render state/code, solver starting state and pose
history have not been isolated. It is an unresolved reproducibility finding,
distinct from the fresh F-versus-Save match above.

## Review boundaries and unresolved decisions

- Exact UI reconstruction remains incomplete. Hidden node 0 has no direct editor
  control; endpoint operations consume the displayed solved frame; Roll can
  rewrite endpoints/orientation. Final saved coordinates alone do not encode the
  original interactive edit history. The approximate Slot 2 and its saved library
  remain isolated evidence, not a replacement for the user's Skill 1 or Slot 2.
- Opening this asset clears existing derived skill caches in the isolated copy.
  The code can invalidate all drafts when seeding any clean baseline draft.
  Record that invalidation separately from the intentional invalidation caused
  by editing a skill. Save also refreshes retarget metadata across drafts.
- CLARIFIED BY USER, later 2026-10-23: a fixed saved hidden .20 station must not
  impose an intermediate entry waypoint. The latest clarification below makes
  conceptual node 0 the current pose plus its already solved incoming grip.
  This refines the earlier node-1-grip inheritance description: an actual incoming
  grip can differ from node 1, and that is a separate transition case. The
  measured fixture was preserved, not normalized during testing.
- NEEDS_DECISION: how should signed elbow-orbit values crossing +/-180 represent
  intended direction/multiple turns? Do not silently choose shortest-path behavior.
- No production fixes, native rebuild, joint-limit adjustment, sampling-rate
  change, Git commit/push or actual player-library replacement occurred.
- Trajectory guide approximation remains deferred. A full diagnosis of every
  anatomical issue and testing equipped-world playback are not claimed here.

## Evidence index

- Current-source fields and saved control samples: `godot_runs/skill_frame_cost_20261023/source_inspection.json`.
- UI reconstruction attempts and screenshots: `ui_replica_01`, `ui_replica_02`, `ui_replica_03` under that root.
- Exact F timing/progress/clip/bones: `exact_source_F_01/results/`.
- Exact Save timing/clip/bones/acquisition metrics: `exact_source_Save_01/results/`.
- Source pose analysis: `saved_clip_bone_analysis.json` and `.md`.
- Fresh pose analysis: `exact_source_F_01/results/fresh_F_bone_analysis.json` and `.md`.
- Reusable UI-owner diagnostic: `tools/diagnose_skill_slot_ui_replica.gd`.
- Offline tools: `analyze_bone_audit.py`, `analyze_saved_clip_bones.py` under the evidence root.

Every game run was serial and isolated. The final original-library SHA256 remains
`cd17f90751f905aed66d07511463ea19bc3181cc17eaecbda6f25af8c0c32379`.

## Follow-up: node 0 authority, Reset and cross-node grip reuse

### Earlier user clarification, 2026-10-23; refined further below

This records the earlier explanation, not a claim that current code implements
it. The later clarification below supersedes a universal node-1-grip inheritance
interpretation:

- Node 0's solved hand-to-weapon relationship comes from visible node 1. If
  node 1 grips at 50%, entry starts with that 50% relationship; the hidden
  entry must not manufacture a 20%-to-50% regrip.
- Node 0's body and weapon spatial starting pose comes from the actual state
  at skill activation. The transition carries that pose to node 1. Reusing a
  grip relationship does not mean replacing the current body pose with node 1.
- That dynamic entry provides continuity from wherever the previous action
  ended. A prepared combat-idle pose is an acceptable fallback for now.
- Finishing returns to prepared combat idle; unmodified idle uses established
  defaults. Out-of-combat spawning/drawing rules remain future work.
- Earlier hand solving was static and much simpler. Preserve the intended
  ownership/order without assuming its old implementation can be reused intact.
- Current scope remains investigation and documentation. No production fix is
  authorized by this clarification. Sampling stays at the current preparation
  rate; no grip acceptance, joint limit or other solver rule is changed.

### Current entry and recovery are still present, but have different semantics

Current code has two distinct starting states: the stored hidden authored
node 0, and a separate runtime entry snapshot. Equipped activation captures
current bones, weapon and anchors before stopping the previous skill/idle
(`player_runtime_skill_playback_presenter.gd:325`). Control-state continuity
comes from the active skill, active idle or pending recovery; absent those it
falls back to authored hidden node 0 (`:1985`).

For a prepared saved clip, `_build_runtime_skill_chain_with_entry` (`:2085`)
targets authored node **0**. Thus the current route is:

`live pose -> stored hidden node 0 -> visible node 1 -> remaining skill`

For the measured asset that retains the unintended .20 -> .50 grip transition.
Node 1 grip editing updates the selected node, not hidden node 0
(`combat_animation_station_ui.gd:7640`). Normalization and compilation do not
insert the clarified inheritance rule either. Node 0 cannot be selected by the
ordinary authoring UI (`:4860`).

Focused Git history identified a concrete entry change: `ec978c57` on 2026-10-14
changed prepared-clip entry from authored index 1 to index 0 to preserve the
first baked segment. Unsolved fallback still enters index 1. This is evidence
of changed routing, not evidence that all old entry triggers were removed.
The focused history search did not establish an older node-1-to-node-0 grip
synchronization trigger being deleted.

The prepared entry bridge interpolates captured bones/weapon/anchors into the
first cached pose using smoothstep (`player_runtime_skill_playback_presenter.gd:2637`).
It does not run the dynamic finger solver. During the bridge the rig translates
the weapon to keep its primary grip anchor attached to the posed hand
(`player_humanoid_rig.gd:1986`). Default entry is .3 clip seconds, reduced to .01
if control-state comparison calls it a no-op; playback speed scales it. The
no-op decision is not based on comparing the captured bone poses.

Recovery infrastructure also remains: completion captures terminal state and
bridges for 1.2 seconds into prepared combat idle (`player_runtime_skill_playback_presenter.gd:699`).
Default idle resources are created automatically, but a default resource is
not itself a valid prepared idle. Save prepares it; equipped playback checks
its cache. An unavailable idle cache falls back to ordinary rig guidance.
The current default fallback therefore is not guaranteed to be the already
solved combat-idle fallback in the user's clarified contract.

F is distinct: it passes the prepared clip directly to ChainPlayer and applies
sample 0 immediately (`combat_animation_station_ui.gd:5435`,
`combat_animation_chain_player.gd:130`). It does not add the equipped entry or
idle recovery. These runtime routes were traced in current code, not newly
playtested as equipped gameplay in this follow-up.

Additional code-only fidelity finding: equipped startup resamples its control
chain with the baker's default **30 Hz**, then copies nearest samples from the
saved solved pose track (`combat_runtime_clip_baker.gd:9`,
`player_runtime_skill_playback_presenter.gd:2699`). Station preparation/F use
the **60 Hz** prepared clip. This does not alter the earlier measured frame
counts or establish a runtime defect; retain it for fidelity review.

### Grip reuse already exists; the unintended relationship change defeats it

`preview_grip_acquisition.gd:1072` keys primary grip reuse by anatomy signature,
weapon/mesh identity, geometry epoch, hand, grip style and local handle station.
World movement and Roll are intentionally absent. Support reuse additionally
depends on primary station and matching hand-to-weapon placement. Warm primary
relationships reapply their prepared packet; genuinely new keys acquire again.

The measured twelve new acquisitions are therefore relevant to the clarified
entry rule: they occurred while preparing interpolated stations between hidden
.20 and visible .50. Reusing node 1's prepared relationship would remove that
particular unintended station sweep in principle. No corrected timing has been
measured and no speedup is claimed yet. Legitimate regrips, support engagement,
cache invalidation and pose preparation still need their own work.

### Reset: fresh tests separate authored controls from the realized pose

Reset is substantial at the data level (`combat_animation_station_ui.gd:941`):
it stops authoring playback/dragging, resets the actor, rebuilds the selected
draft's motion chain from its mount seed and invalidates its prepared clip.
For a skill, the new chain has independent hidden 0 and visible 1 nodes.
Roll, arm orbit, curves and proxies are reset; draft playback settings return
to defaults. Weapon/selected hand/grip-style/one-or-two-hand opening context
and draft identity/description remain. This is not a global session reset or
a request to restore authored combat idle.

The weapon seed defaults are primary station .2, support station 0, axial 0,
Roll 0, body-support blend .4 and arm orbit 0. Orientation comes from the
weapon grip axis. Reset allows a cached mounted seed via
`_resolve_active_weapon_authored_baseline_seed(true)`; it does not clear that
cache first. The actor reset clears substantial guidance state and reapplies
its baseline animation (`player_humanoid_rig.gd:2387`). These facts do not prove
that the final constrained/gripped pose is repeatable.

Two fresh isolated rendered runs tested the actual Reset button on
`Broken_Balde_v1`, Slot 2, right-main normal single-hand opening context:

1. Capture the initial opened baseline and all 77 model bones.
2. Use normal UI-owner setters to apply the source Skill 1's final-node
   instructions to visible node 1, substantially changing body, weapon, grip
   and arm controls. Existing constraints remain active; this is not an exact
   source-skill recreation claim.
3. Press Reset, wait for grip completion, capture controls and all bones.
4. Press Reset again and repeat.

`reset_probe_01` and `reset_probe_02` both completed without logged engine
errors. Both resets restored all compared authored controls to the initial
baseline, including identical tip/pommel/orientation, .2 grip, Roll 0 and arm
orbit 0. Node count returned to two (one visible). However, realized body
poses did **not** match across those otherwise identical control states.

The second run added passive captures at 1, 3 and 6 seconds after initial
opening and each completed reset. All 77 bone transforms stayed unchanged
through each observation interval. The same between-reset differences were
reproduced, excluding ordinary delayed settling within that six-second window:

| Comparison | Right-hand bone orientation difference, skeleton space | Right-hand bone position difference, world space |
| --- | ---: | ---: |
| Initial opened baseline -> first Reset | 156.955 deg | 50.546 mm |
| First Reset -> second Reset | 30.561 deg | 42.581 mm |

These are quaternion orientation distances, not a wrist joint-limit measure,
and do not classify which pose is anatomically correct. They demonstrate a
repeatability problem in the resulting pose despite matching authored values.
The diagnostic's `ok=true` means its steps completed, not that Reset passed a
solved-pose equivalence test.

Evidence: `reset_probe_02/results/ui_replica.json`, `bones.jsonl`,
`reset_bone_comparison.json`, and `reset_probe_initial_settled.png`,
`reset_probe_0_settled.png`, `reset_probe_1_settled.png`. The earlier run is
retained separately. No Save or F was invoked in either Reset probe.

The isolated library again lost Skill 1's derived clip/signature when opening
the other draft, so `source_slot_preserved=false` records that in-memory cache
invalidation. It does not mean the real saved Skill 1 was changed: no source
authoring fields changed, the original library remains byte-identical, and the
diagnostic source backup also retained its hash. No actual player save was
written. No production behavior was changed and no Git operation was performed.

Read-only code tracing found retained state to inspect next, not a proven cause:

- Rig Reset clears finger targets, but that path clears legacy execution-path
  caches rather than releasing the current planar grip binding
  (`player_humanoid_rig.gd:1402`, `player_rig_finger_grip_presenter.gd:583`).
- Presenter reuses the same actor/weapon. Acquisition-owner configuration returns
  for the same pair, and synchronization skips an unchanged relationship key
  (`preview_grip_acquisition.gd:340`, `:359`). Reset does not unconditionally clear
  the prepared primary seat or replay-pose cache.
- Open-mount presentation later recomposes the retained primary seat
  (`combat_animation_station_preview_presenter.gd:4467`, `:5869`). That operation
  moves the weapon and affects subsequent placement; it is not itself an arm
  bone writer. No causal attribution to it is established by this audit.
- The baseline animation path does explicitly reset bones and sample its
  animation at time zero (`player_humanoid_rig.gd:6237`). Do not describe the
  defect as simply recording the current bent pose as the new rest pose.

Next investigation, if pursued: determine which retained pose/grip input makes
identical reset controls produce different realized poses. Preserve warm-cache
reuse where valid; indiscriminately deleting all caches is not an established
fix and could worsen the preparation cost under investigation.

### Latest clarification: node 0 is the incoming state, not a stored waypoint

The user's next message explicitly defines conceptual node 0 as the current
body/weapon/hand state at an action trigger, using an already solved grip from
the immediately previous action, combat idle, or the appropriate out-of-combat
acquisition path. It is the transition source for the new action's visible
node 1. Skill interruption, and future block/dodge/dash entry, should reuse
that same continuity concept. Those future actions are not implementation scope.

Intended: `live incoming pose + existing solved grip (= conceptual node 0) -> node 1`.

There must not be an additional fixed saved hidden pose that the character has
to visit before reaching node 1. The two meanings of "node 0" in the discussion
were different: the conceptual live entry state versus the current serialized
first element of the author's motion chain. Current prepared playback makes
a new runtime entry node, then appends the serialized hidden node, then visible
node 1. Runtime array reindexing does not remove that additional waypoint.

The incoming grip is not universally node 1's grip. If both relationships match,
entry should preserve the already solved relationship. If they differ, that
is an actual grip-transition case, not permission to snap to node 1's grip or
route through an unrelated default station. The precise policy for differing
grips remains to be established; this explanatory turn does not implement it.
Consequently, removing the fixed hidden station cannot be claimed to remove
every possible entry grip change or its cost.

The current runtime bridge already interpolates captured prepared poses rather
than invoking the full grip acquisition solver. The earlier multi-second
acquisitions were measured during F/Save preparation of the stored 0 -> 1
segment, not during the runtime trigger bridge. Keep those costs separate.
Code was rechecked for this explanation; no new game run or production edit.

### User explains the stored node's origin and proposes separating Reset

In the following message, the user explains that the hidden default node was
introduced as a Reset target during early Skill Crafter development. Deleting
motion nodes did not recover a twisted/broken body stance, making slots unusable
and sometimes requiring replacement of the entire test weapon. Hiding a default
node provided a recovery target. This is user-supplied historical intent, not a
newly verified reconstruction of that earlier implementation.

Proposed direction: retain a dependable default pose for Reset/fallback, but
exclude that default node from skill animation preparation and playback, and
do not serialize it as a motion node in the saved action. Current solved pose
and grip should form the live entry directly to visible node 1. Reset data can
be owned separately by editor/weapon setup; it need not be an action waypoint.

The distinction is between three responsibilities: recovery to a known default
on Reset, authored motion beginning at visible node 1, and a runtime transition
from the current solved state into node 1. Existing runtime snapshot code
already captures bones, weapon pose and grip anchors as a foundation for the
third responsibility.

Implementation must account for existing first-segment and timing assumptions;
simply deleting index 0 is insufficient. A skill with one visible node still
needs its live-entry-to-node-1 transition. Node 1's entry timing must not disappear
when the stored baseline is removed. F currently lacks the runtime entry wrapper,
so its path must participate in this separation as well. Save/cache validation
must distinguish the authored reusable action from the transient incoming pose.
This note records design direction only; no implementation or speedup test.

Current code details for a future implementation review:
- Skill compiler and higher-level playback gates expect two nodes, although
  the lower-level clip/sampler supports one pose. A single visible destination
  must remain usable with its live entry.
- Duration is stored on the destination node; the baker sums from array index 1.
  Making visible node 1 the first stored pose drops its incoming duration from
  that sum. Preserve entry timing explicitly; current equipped entry uses .3 s.
- Cache signatures and incremental checkpoints include node/sample indices.
  The changed boundary needs compatible index mapping and cache invalidation.
- Prepare node 1's valid pose before preparing its outgoing motion. Trimming
  existing baked frames afterward retains history from traversing old node 0
  and does not remove its preparation cost.

### Consolidated proposed change scope after the user's transition discussion

The user requested a complete statement of the changes now understood. This
section consolidates the current design direction; earlier clarification
paragraphs preserve discussion history. No production implementation is being
performed in this planning turn.

1. Separate Reset/fallback baseline data from the action's authored motion.
   Retain the known default body/weapon/grip target, and diagnose/fix the measured
   Reset pose-repeatability defect. This does not by itself authorize changing
   whether the existing Reset command clears authored nodes.
2. Saved action motion starts at visible node 1. Do not serialize the reset
   baseline or a transient live entry as an action node. Preserve authored
   positions, orientations, grip choices, curves and timings during conversion;
   the user's real Skill 1 remains the reference, not material to overwrite.
3. Prepare a valid solved node 1 pose/grip and then its outgoing authored motion.
   Remove the mandatory reset-baseline-to-node-1 preparation, rather than merely
   hiding/trimming already computed frames. Preserve legitimate regrip work and
   the 60 Hz preparation rate; do not claim a speedup until measured.
4. At F or equipped activation, capture the actual current body, weapon, hands
   and solved grip/anchors before releasing the previous action's authority.
   Capture must work during idle, skill playback, hold and recovery. Convert
   reference frames consistently and bridge directly to the new node 1.
5. Entry is transient playback data, separate from the reusable prepared body.
   A different incoming pose must not invalidate or rebake an unchanged authored
   body. F retains its no-save workflow and obtains the same entry semantics as
   equipped activation; it must not simply snap to the first prepared pose.
6. Carry an unchanged solved grip through entry without reacquisition. Preserve
   the hand/weapon attachment relationship. Different stations, styles, primary
   hands or support participation require an explicit transition policy; do not
   invent a mandatory default station or assume interpolation certifies contact.
7. Preserve first-node entry duration and one-visible-node actions. Recommended
   timing proposal: use the first visible node's incoming duration for the bridge.
   This is not yet a confirmed choice: current equipped entry uses .3 seconds.
   Retain authored-body timing and completion-to-prepared-combat-idle recovery.
8. Update compiler/playability checks, cache signatures/schema, time origins,
   incremental checkpoints and node-index mappings together. Distinguish old
   hidden-start clips from the new prepared body; do not blindly reuse old arrays
   or strip the first node from idle data. Preserve useful unchanged grip caches.
   Review the 60 Hz station/30 Hz equipped copy for playback fidelity rather than
   using lower sampling as a speed shortcut.
9. Validate on the unchanged actual skill in an isolated library. Compare cold
   preparation, repeat F, Save after F, new-grip acquisitions and actual resulting
   motion. Cover one visible node, repeated Reset, mid-action interruption, hold,
   recovery, left/right, reverse and support participation. Reuse the existing
   bone captures and document failures; no broad anatomical fix is implied.

Open behavior choices before dependent implementation: exact entry-duration
ownership; transition behavior when source/destination grips differ; handling
an entry path that violates existing reach/body restrictions. Preserve existing
restrictions while deciding these, rather than silently bypassing them.

Future consumers explicitly identified by the user: from-current-pose stow,
unstow, skill-to-skill transitions and other combat actions (including future
block/dodge/dash). They should reuse this capture/transition boundary. This is
architectural direction, not current scope to create those actions. Stow/unstow
still need their own hand contact, weapon attachment and visibility timing;
the shared bridge alone does not define those rules.

### Implementation decisions confirmed after the audit

The user authorized correction of these connected behaviors. This section
supersedes the earlier proposed timing rule, while preserving that discussion.

- Use the name **entry node** for current solved state -> visible node 1.
  Reset has its own default baseline and is not an action waypoint.
- Entry motion takes **160 ms**, constant across the board, regardless of travel
  distance. It must not be multiplied by the skill playback-speed setting.
- At node 1 and later, normal/reverse grip-change motion follows the applicable
  node's authored timing. Do not make the weapon wait for grip acquisition or
  force the solver to finish within that duration. Acquisition has a separate,
  variable processing time. This is the user's final clarification after
  withdrawing the earlier "grip changes wait for their solve" answer.
- Flip sequence: hand opens, weapon follows an explicit intermediate tip AND
  pommel pose around the selected handle-% pivot, hand closes into destination
  grip. Acquisition/closing may overlap motion. Use hand side, forearm/hand
  orientation and source grip style to select a repeatable turning direction.
- Ground intersection during that prescribed flip is allowed. The author is
  responsible for positioning the hand for clearance when desired.
- Prefer 60 Hz in preparation, F playback and equipped playback. If impractical,
  the alternative requires 30 Hz everywhere, not mixed rates.
- Reset restores resting body and both position AND direction of the hand's
  pinky-index reference before seating the weapon. Preserve reusable grip data.
- Functionality first. Measure preparation cost afterward; no speedup assumed.

Implementation in progress: action-only storage and one-visible-pose compiler,
cache version v11, shared transient entry builder, repeated-Reset correction,
and explicit flip geometry. Live asynchronous grip presentation is an open
integration item: acquisition's stale-source checks reject moved source bones
or weapon transforms. Those checks must remain; destination preparation and
displayed motion need independent ownership.

Fresh Reset evidence (`godot_runs/skill_transition_20261023/reset_after_01`):
all 77 captured bones match exactly in local/skeleton/world transforms for
initial -> Reset -> Reset, stable at +1/+3/+6 seconds. Both pinky-index reference
packets and settled weapon transforms repeat exactly. Previous repeated-Reset
right-hand drift was 30.561 degrees / 42.581 mm. This proves repeatability for
this test, not full-hand acceptance (`grip_accepted` remained false). Initial
authored tip/pommel targets and regenerated Reset targets differ by a repeatable
49.632 mm translation, while final settled pose/weapon agree.

Fresh action-storage verifier: 43 checks pass in
`godot_runs/skill_transition_20261023/action_storage_check_02`. Covers legacy
load, action-only save, unchanged visible fields, separate editor placeholder,
idle preservation, single-pose actions, untouched default-slot publication
status, nested serialization, stale-cache omission and failed-save recovery.
Other integration tests remain pending; these results do not certify playback.


### New finding: exact old F cost belongs to hidden entry seat changes

The earlier exact-source cold F run is now attributed per frame, using
`godot_runs/skill_frame_cost_20261023/exact_source_F_01/results/cold_F_progress.json`
and `replica_solved_clip.json` from that same results directory. Extracted table:
`godot_runs/skill_frame_cost_20261023/old_hidden_entry_grip_cost.json`.

- Completed solve count rises from 1 to 12 on frame indices 0 through 11 only.
  These samples request handle seats 0.200, 0.225, 0.250, ... 0.475 at times
  0.000 through 0.183333 seconds. They belong to the stored hidden Reset0 ->
  first visible node interval, whose endpoint is seat 0.500 at 0.200 seconds.
- At frame 12 and all later samples, seat remains 0.500. Those frames reuse
  the prepared primary grip, despite weapon/arm movement. All 12 new solves
  complete; the 58-frame successful preparation reports 12 solves and 46
  relationship reuses. There is no observed sequence of cancelled jobs in
  these progress results. Cancellation was not itself traced by this log.
- Cumulative grip work is 33,617.036 ms by completion of sample 12; subsequent
  relationship reuse adds only a small fraction of total grip time. The old
  cold F wall duration was 38.388 seconds. This is old-run attribution, not a
  speed result for the changed implementation.

Code agrees with this distinction: pose bake calls `prepare_replay_grip` once
per frame; primary cache identity excludes world pose and weapon Roll. It
includes the weapon-local station, hand roles, geometry/anatomy identity and
style. A missing relationship is prepared synchronously to completion through
`_run_next(true)` / `_job._work()`. A currently running asynchronous acquisition
causes a pending result rather than a competing bake solve. The support hand
has an additional tight relative-pose match check and must be investigated
separately if its reuse differs.

The action-only boundary removes precisely this old hidden0 -> visible1
interval from reusable body preparation. It does not remove the intended
current-state entry motion or authored grip changes between visible nodes.
Measure a fresh equivalent run before claiming a speedup. This evidence does
not support same-seat movement interruption as the primary cause of the old
single-main-hand cost; new runtime behavior still requires its own trace.


### Confirmed stored-pose direction and implementation (continuing 2026-10-23)

The user explicitly replaced per-frame pose/grip preparation with reuse of the
actual editor result. Each motion node now stores its solved body, fingers,
weapon and attachment transforms. F and Save interpolate those endpoints; they
must not run another acquisition or an off-screen endpoint-solving pass.
Existing tip/pommel path bias remains part of motion. Endpoint timing regulates
travel. Interior interpolation is accepted without renewed collision/contact
certification; endpoint fidelity and interior attachment drift must still be
measured honestly. Current actual state -> visible node 1 uses the same stored
transform principle, with a fixed 160 ms entry.

Current integration: exported prepared pose packets plus stable pose-input and
geometry/anatomy signatures, capture after two settled editor frames, a pure
track builder, and cache v12_stored_endpoint_tween. Duration, path-handle edits
and renumbering retain captured poses. Pose changes require the editor to settle
again. Legacy nodes without snapshots must be visited once; missing data must
not trigger a hidden expensive solver fallback. The 60 Hz base sampling also
retains exact authored endpoint timestamps when they fall between samples.

Save no longer visits other poses, restores a terminal solver checkpoint or
reacquires a grip after rendering. It builds from stored active/idle data and
writes it. Missing legacy idle data is reported rather than secretly solved.
F waits only for acquisition already started by editing, keeps camera input
available during sampling, and builds private replay data without saving.

Fresh earlier action-only run exact_action_01 (before the new pure builder):
cold F 2.684309 s for 46 body frames, zero new grip solves / 46 relationship
reuses; cached F 0.105341 s; Save after F 6.698784 s. Its overall diagnostic
failed an outdated preservation comparison that counted intentional Reset0
removal and derived-cache changes; that guard was corrected, not waived.
These timings are not yet evidence for the newer stored-pose implementation.

Fresh independent verifiers: entry_check_01 415 checks passed, corrected
flip_check_02 411 checks passed, motion_rebase_check_01 33 checks passed.
The motion-rebase verifier is synthetic; an actual saved-weapon async run is
now in progress. Root owns all engine runs. No Git operation was requested.

### Recovery and fresh stored-pose verification - 2026-10-24

This section supersedes earlier in-progress statements without erasing them.
The user authorized resuming after the Windows crashes and checking the cause
while restoring zero-filled files; this was not a request to repair Windows.

Recovery: `runtime/combat/combat_animation_station_ui.gd` was 402,967 NUL bytes.
Restored its newest prechange copy and replayed all nine recorded mutation
calls (six capture-agent calls plus three integration calls). A 244-byte size
difference from the damaged file remains unexplained, so byte-identical recovery
of the last pre-crash revision is not claimed. The recovered implementation was
checked forward with parsers and tests. Added the explicit current-context guard
before prepared-cache reuse; captured poses themselves are not rounded.

The broader read-only audit found no additional missing or NUL-only files among
1,789 tracked code/document files and 35 current untracked code/document files.
All 23 relevant prechange backup entries have nonempty current counterparts.
Two empty legacy editor caches were already empty in HEAD. No tracked file is
deleted. The real weapon library retains its original SHA256. These checks do
not certify arbitrary binary assets or changes that existed only in memory.
Recovery evidence: `godot_runs/skill_transition_20261024/crash_recovery/Recovery.md`.

Crash cause remains unproven: current Windows records show bugchecks 0x3B and
0xA; readable events do not identify a responsible driver or a Defender block.
Current minidumps are inaccessible to this process. No system settings, drivers,
antivirus exclusions, repair commands or permissions were changed. Detailed
evidence: `crash_recovery/windows_crash_findings.md` in that evidence root.

Fresh focused checks under `skill_transition_20261024/focused_resume_01`:
39 prepared-pose checks, 14 action-boundary checks, 43 action-storage checks,
and the runtime-chain compiler verifier all passed, with empty stderr.
The direct restored-UI parser and diagnostic parsers passed. Refreshing Godot's
global-class cache was necessary after the zero-filled UI disappeared from it.
That editor import logged extension reload-copy conflicts with the already-open
user editor; it is not represented as a clean extension-reload test.

Fresh rendered `stored_pose_action_02` used the original exact Broken_Balde_v1
Skill 1 in an isolated library. The real library was never changed. Its five
visible destinations prepare 46 samples over 0.75 authored seconds (60 Hz).
User-authored controls remain unchanged in the baseline phase. Timings:

| Measured operation | Wall time | New grip acquisitions during F |
|---|---:|---:|
| Cold F from captured editor endpoints | 374.788 ms | 0 |
| Repeat cached F | 142.231 ms | 0 |
| Save after F, complete handler | 834.813 ms | n/a |
| F after changing a node duration through UI | 376.676 ms | 0 |
| F after R append and UI adjustment | 484.750 ms | 0 |
| Save after those isolated edits | 828.544 ms | n/a |

Initial normal editor visits/acquisition/capture cost 13.788 seconds separately;
that includes diagnostic waits for stable state and is not F preparation time.
Do not describe grip solving itself as free. After baseline Save the optional
rolling phase deliberately modifies only the isolated Skill 1. It retains the
pose after a duration edit, captures a UI-created sixth node, includes that
last endpoint (maximum numeric error 1.19e-7), and saves/reloads the packets.
The final edited action is 2.0 seconds / 121 samples. Overall run complete/ok;
stderr empty. Original Skill 1 disk hash remains unchanged. Generalized support,
reverse, interruption and visual acceptance are not established by this run.

Fresh `equipped_stored_pose_01` loads that isolated saved result and uses actual
equipped skill activation and the real skeleton's final-update signal. It passed
saved/runtime 60 Hz, exactly 160 ms entry, all body/control arrays unchanged after
the entry prefix, timestamps shifted only by 160 ms, and zero new acquisitions.
Entry/start/middle/terminal samples apply the stored track correctly. It does
not certify every continuous intermediate contact or all equipment/hand variants.

### Remaining mechanical issue: independent tweens separate hand and weapon

Do not confuse successful data playback and low preparation time with a finished
visually attached grip. The fresh pure builder reports a maximum primary-hand
attachment residual of 0.377069533 metres. Independent offline reconstruction
from the exact baseline clip plus original prepared-node bone traces reproduces
0.377069582 metres. All five endpoints match their captured world hand frames
within 2.38e-7 metres and 0.000025 degrees. This is not the old reference-scale
bug and is not a damaged-file symptom.

Peak position separation occurs at frame 33, authored time 0.55 seconds, halfway
from visible node 3 to node 4. Local joint rotation interpolation produces one
hand path; the authored weapon curve produces another. Their common endpoints
do not make their interiors agree. The maximum angular mismatch is 39.958 degrees.
Evidence: `stored_pose_action_02/attachment_analysis.json` and its accompanying
`analyze_prepared_attachment.py`. No corrective solve or path change was hidden
inside these measurements.

NEEDS_DECISION, asked via chat: which motion owns the interior when they differ?
Recommended: preserve weapon trajectory and use bounded arm kinematics to follow
the already-solved grip relationship, without finger/contact reacquisition.
Alternative: preserve pure bone tweens and make the weapon follow the hand,
accepting a different weapon path. Translating the wrist off the forearm or
moving the shoulder off the torso is not an acceptable shortcut. The selected
rule must also cover the shared 160 ms entry and remain consistent in F and
equipped playback. No implementation of either choice is authorized by silence.

User acceptance of unvalidated interpolation interiors is not treated as approval
for a visibly detached weapon. No broader anatomy redesign, original-library
write, Git operation, or opposite-hand retargeting change was made in recovery.

### User clarification: maintained attachment with axial travel

After asking for time to think, the user defined the desired relationship:
weapon twist follows wrist rotation within the existing wrist limits. Preserve
the acquired hand-to-handle relationship throughout motion. Use wrist W,
pinky-index midpoint P and current selected handle-slice center H as references;
preserve the acquired distances, angles, handle/pinky-index axis alignment and
orientation relative to the hand. The intended plane is parallel to the active
middle-finger bending plane through P, not fixed in world space.

Further concise clarifications: the existing axis needs a second axis and a
plane; the result is a **constant distance with travel allowance when needed**.
For unchanged grip percentage, carry the attachment unchanged. For a changing
percentage, H follows the current target slice along the handle; maintain the
hand offset/facing relative to that moving reference, not a fixed weapon point.
Continue arm/body IK to maintain the attachment, without repeated finger/contact
acquisition. Normal/reverse transitions retain the separate open-flip-close rule.

Code inspection: snapshots already contain complete primary/support
`hand_in_weapon` transforms, including orientation. They are currently used
for diagnostics while arm and weapon interiors move independently. Additional
axes/plane describe the intended full attachment frame; the missing enforcement
is not merely another measurement or another grip search. Capture the actual
acquired frame rather than projecting a valid grip onto a different ideal plane.
This clarification does not itself define unreachable-path handling or how to
reconcile endpoint grips with different radial offsets on a varying handle.
Do not invent those rules or silently stretch anatomy. Read-only investigation
continues while the user refines the definition; no production edits or engine
runs were made during this clarification.

### Attachment implementation checkpoint - 2026-10-24

User authorized a checkpoint, SPS and continued work. Commit `ce641985`
(`skill crafter optimisation F rotation integration`) is pushed to origin branch
`recovery/stable-92b8a24-chat14`; remote hash verified. SPS 2026-10-24 01:29 is in
that checkpoint. The continuation below is later work, not part of that commit.

First bounded experiment: extract the existing analytic support-frame arm math
into a pure value resolver and exercise the original 46 prepared frames. The
read-only positional feasibility pass found all frames geometrically reachable
under the existing shoulder/elbow limits, with 22 using existing wrist-swing
freedom. This does not yet establish valid rotations or elbow continuity.

Implementation gate: verify complete hand frame, unchanged local translations,
scales and fingers, existing shoulder/elbow/helper-twist limits, wrist-twist
preservation, exact endpoints and bend-plane continuity. Initial files are
`core/resolvers/combat_prepared_arm_frame_resolver.gd` and
`tools/verify_prepared_arm_frame.gd`, plus their UID companions. No production
playback call site changes until this proof succeeds. Then capture current
constraints as data and share attachment enforcement between prepared action
tracks and the transient entry. Measure actual preparation cost again.

Unreachable paths and incompatible radial offsets remain explicit decisions;
do not silently change limits, stretch bones, or substitute a new weapon curve.

Capture-only continuation adds actual arm constraints and handle path/seat
metadata in `combat_prepared_pose_capture.gd` and the station preview presenter.
Both parse in Godot 4.7. They do not activate playback correction or invalidate
existing poses yet. These values are needed for a proof with actual limits,
particularly the helper-twist baseline which the old trace did not contain.

Read-only review also identified a separate rotation-branch concern: endpoint
quaternion shortest-path interpolation does not by itself respect a 240-degree
authored Roll interval. Existing Roll orbits Wrist-to-Tip (and can move pommel),
not the longitudinal tip-pommel axis. A correction around the wrong axis would
change the control's meaning. The bounded same-grip frame proof must not be
described as verifying all Roll branches. The current baseline has unchanged
grip placement; broad roll-orbit reconstruction remains to be tested separately.

User scope reaffirmation during implementation: do not wander into parallel
elbow/wrist fixes. Finish the attachment/replay integration and timing checks;
broader anatomy stays deferred. Low token warning does not authorize skipping
the current integration checks or declaring an unfinished result successful.

Pure following proof `prepared_arm_frame_03.json`: 36/36 checks pass, all 46
original frames plus rotated/translated-reference and 10/15 mm path variations.
46 resolver calls cost 39.977 ms. Same-grip hand residual is at most .0365 mm;
positions/scales/fingers and original endpoints remain unchanged. First attempt
chose the opposite elbow branch at the last endpoint. Transporting the authored
bend plane toward the requested hand direction resolves that specific problem;
this is not a general elbow repair. No new joint ranges were introduced.

The integrated first rendered run (`attached_pose_action_01`) prepares cold F in
462.265 ms with zero acquisitions and .0365 mm attachment residual. Repeated F
does not start playback yet, despite successfully reusing the body cache.
Investigating the new entry validation boundary before accepting integration.
This failed run is retained as evidence; it is not a successful F/edit/F result.
# 2026-10-24 continuation: attachment integration closeout

## Final checkpoint evidence and remaining gap

User requested Git checkpoint, then discussion/planning; explicitly HOLD OFF on
SPS until that discussion finishes. No new SPS was created for this continuation.

Implemented captured arm constraints and full hand-in-weapon frame following in
the pure prepared-track builder and shared entry. Retained actual displayed hand
ownership across replay clearing live acquisition flags. Equipped entry can reuse
missing twist-neutral calibration only from a matching saved skeleton/rest/arm
dimension/config packet. A small animated hip translation is correctly treated
as pose motion rather than an arm-dimension change. Existing neutral values are
never overwritten and the current posed arm is never used as a neutral baseline.

Final evidence under `godot_runs/skill_transition_20261024`:

- `attached_pose_action_04`: cold F 434.649 ms, repeated F 175.472 ms,
  duration-edit F 448.681 ms; Save 836.446 ms. Those F phases have zero new
  acquisitions. Original five visible nodes pass. Save produced an isolated
  real library usable by the actual equipped activation test.
- `equipped_attached_03`: PASS. Actual equipped idle-to-skill entry, 60 Hz,
  exactly 160 ms, 10 prefix samples, nine bounded arm-follow calls, unchanged
  body tail, zero new acquisitions. Maximum attachment error 0.03636 mm,
  orientation error 1.393e-6 radians; unrelated bone rotations unchanged.
  Live source weapon is 0.84983 m from destination. Calibration guards reject
  changed rest/arm limit/conflicting existing neutral; source stays unchanged.
- `final_checks`: 60/60 prepared-pose, 14/14 action-boundary, 43/43 storage.
- `final_arm_proof/report.json`: PASS, fresh single-attempt resolver proof;
  original 46 frames, transformed reference and small path variations included.
- Real library SHA256 remains
  `cd17f90751f905aed66d07511463ea19bc3181cc17eaecbda6f25af8c0c32379`.

NOT COMPLETE: appended-node F still rejects `elbow_range_has_no_circle_solution`
at prepared frame 71 / zero-based segment 4. The test's post-replay recaptured
last node and appended node do not pass the new contact-preserving arm constraint.
A bounded nine-distance experiment also failed within the available interval
0.405943..0.406515 m; it was withdrawn, retaining single-attempt behavior and
failure diagnostics. This is not proof of global unreachability and not a solved
elbow bug. Do not describe the entire rolling/appending workflow as passing.
The UI result now retains attachment failure details rather than only a reason.

Next discussion: how to handle incompatible authored/intermediate arm/weapon
paths without grip separation, changing anatomical limits or silently replacing
weapon motion. Broader elbow, wrist, left-hand, support/reverse, interruptions and
full-hand visual certification remain separate/unverified. No fresh large test
or anatomy implementation is authorized merely by this note. All owned Godot
runs finished; user's editor remains open. This is a scoped code checkpoint,
not a clean-worktree claim; unrelated settings and fixture changes are preserved.

Scope remains stored grip attachment during prepared F/body playback and the
shared 160 ms entry. User explicitly deferred broader elbow/wrist repairs and
requested finishing this slice under low tokens, with another Git checkpoint
if worthwhile. A checkpoint is warranted for this integration.

Fresh intermediate evidence `skill_transition_20261024/attached_pose_action_03`:
cold F 429.979 ms, repeated F 154.908 ms, duration-edit F 444.887 ms, Save 859.157 ms.
Those F phases performed zero new acquisitions; Save produced the isolated
`results/profile_library.tres`. The real user Skill 1 remains untouched.
The complete rolling test did NOT pass: appended-node F rejected
`elbow_range_has_no_circle_solution`. This means the selected root-to-elbow
distance has no legal shoulder-circle solution, not proof the hand target is
globally unreachable. The formula matches existing live arm-following code.
A bounded alternative-distance fallback is being checked without widening limits.

Fresh equipped entry run `equipped_attached_01` exposed uninitialized twist-neutral
calibration caches on the equipped rig. The editor's captured destination contains
that immutable calibration. A guarded reuse must verify identical skeleton/rests
and dimensions, fill only missing calibration, then revalidate the packet; it must
not invent neutral angles from the currently posed character. This run failed and
is not a successful equipped playback result.

Repeated F initially failed because live acquisition ownership flags are cleared
after saved replay. Current hand/support intent must be retained from the actual
applied frame; opening defaults and destination-node intent are not sufficient.
