# Skill Crafter upper-body coordination — 2026-11-07

## Scope and checkpoint

User requested a pre-change Git savepoint followed by a coordinated-body fix, with research adapted to Josie's actual rig. Savepoint pushed: `c8a38b996c2521bdd0ee39782c8b0299d667251d`, **Skill Crafter provisional shoulder calibration and body movement savepoint part 2**.

This is a working companion to [Weapon Motion Allocation Implementation 2026-10-29.md](<Weapon Motion Allocation Implementation 2026-10-29.md>). Findings below distinguish implementation from verified behavior. No new code is considered verified merely because it appears here.

## Confirmed starting discrepancies

- Weapon Tip/Pommel/attached Roll use the constrained allocator, but its clavicle coordinates are all fixed.
- Independent elbow/free-hand edits use selected-arm CCD, which may move Clavicle without the newer shoulder envelope checks. These controls can therefore disagree about the same physical pose.
- Multiple lexicographic posture tiers keep proximal motion exactly minimal before allowing the next preference. All joints are technically available, but the preference can create abrupt redistribution at limits.
- The prior accepted-checkpoint correction is already committed. Do not undo that fix or replace fixed anatomical zeros with drag-relative limits.

## Decisions and protected boundaries

- User initially approved 6 degrees, then explicitly replaced it with **provisional 10-degree clavicle swing half-cone (20 degrees across opposite extremes)**, **no additional axial-roll freedom**. User then supplied Inspector screenshots and explicitly defined **Idle bone-local XYZW rotations as home**. The cone centre is those fixed Idle rotations, NOT imported rest. This is test tuning, not clinical calibration. Preserve existing axial orientation as a fixed captured value; the cone never recentres on the current pose.
- Confirmed read-only from the actual scene and Reset baseline: left `(0.174668, -0.030927, -0.808198, 0.561561)`, right `(0.160754, 0.015876, 0.821109, 0.547436)` match the supplied screenshots within 0.000023 degrees. They differ from imported rest by about 21.4 degrees. Evidence: `godot_runs/upper_body_coordination_20261107/clavicle_reference.json`. Imported rest still defines bone lengths/shaft geometry. Existing humeral/forearm anatomical angle conventions are not silently re-zeroed; any future change to their zero must remap the matching limits.
- Derive axes from actual `CC_Base_Spine02 -> Clavicle -> Upperarm` rests. All local poses retain named ancestry through `RL_BoneRoot`; world targets remain explicitly world-space.
- Final chest-to-upperarm shoulder measurement includes clavicle movement once. No extra humeral roll allowance.
- Independent edits freeze shared ancestors and the opposite arm. Shared two-handed weapon movements retain existing coordinated torso participation. Legs excluded.
- Elbow control retains its existing bend-plane/swivel meaning. A fixed wrist must remain fixed; merely clamping upperarm after the solve is not acceptable.
- Grip acquisition/finger solving is protected. Changes belong at the independent-edit entry boundary and in common motion mathematics, not the legacy contact/CCD methods also used by gripping.
- Save/F/equipped systems consume existing solved packets. No rewrites or repeated end-to-end checks unless directly affected.
- Existing invalid poses retain correction/non-worsening movement; do not restore an invalid-start edit lock.

## Implementation plan

1. Pure fixed Idle-reference clavicle measurement/composition plus immutable profile setting.
2. Integrate the cone in common arm FK and validation; preserve scale, translation, and rigid acquired contact.
3. Keep task/anatomical/contact constraints strict. Replace exact posture-freeze tiers with one finite normalized movement-preference objective. Keep diagnostic counterfactual mode.
4. Route independent free-hand/elbow edits through common mechanics. Free hand targets its own pose; elbow targets its position while retaining the current hand pose. No fictitious acquired weapon or new finger solve.
5. Focused body checks: both arms, limits/reversal/regrab, root transform covariance, opposite-arm freeze, wrist contact, mixed control handoff and shared two-hand motion. Then a rendered body-only check and manual testing handoff.

## Evidence and limitations

Historical intermediate evidence follows; the final verified version and remaining blocker are recorded below. Initial pure clavicle suite 543/543 and preference suite 21/21 passed BEFORE subsequent Idle-reference and orbit additions.

First recorded problem-pose comparison on the initial 6-degree rest-centred version: full task accepted, but weighted policy 707 ms / 1019 evaluations vs same-new-FK lexicographic counterfactual 134 ms / 164. Trace showed shoulder-coverage handoff searches, not clavicle rejection. Pommel axial shoulder roll was disproportionately cheap after coordinate-span normalization. Raising its finite cost from 1 to 6 (keeping swing/elbow 1), plus stable physical-cone normalization, produced full acceptance at 119 ms / 168 evaluations. These are diagnostic captures without external scene collision, not a live UI performance claim or final-version timing.

First actual-rig suite: 131/132 checks passed; failing comparison treated unconstrained Forearm orientation as the elbow task. Elbow tasks constrain elbow position and retain the Hand frame. Both roots individually met their Hand contact tolerances; the test is being corrected to compare those actual contracts while retaining the internal orientation discrepancy as evidence. Larger sweeps added rather than relying on small movements.

Large swivel geometry requires an **orbit task path**, not a straight elbow chord that would shorten the forearm while Hand is pinned. Added explicit world-space orbit path and retained Hand pin for consecutive elbow edits; later replaced the general QP elbow fit with the verified analytic orbit below.

Research donor-coverage transitions remain a separate source of discontinuity; do not claim this pass proves every pose or eliminates every frame hitch.

## Follow-up clarification: fixed home and shaped ranges

User explicitly rejected cumulative re-zeroing: moving to +10 degrees from home must not turn that pose into a fresh zero with another +10 degrees available. Combined parent/child motion is allowed, but each joint's limits retain their declared reference. A parent-relative home moves with that parent; it does not follow the edited joint's latest pose.

The user's sketch illustrates asymmetric/partially excluded swing regions, potentially with a boundary that does not pass through the centre of a cone section, plus a separate axial-roll interval. This is a conceptual requirement for interpreting permitted regions, not new numeric anatomical limits. Do not replace existing shaped envelopes with a full symmetric cone just for convenience. Audit the other upper-body limit sources and invalid-start allowances for accidental re-zeroing; preserve working reference conventions unless a complete mapping of their matching limits is provided.

### Final implementation and focused evidence

Evidence root: `godot_runs/upper_body_coordination_20261107`.

- `clavicle_final`: **561/561** fixed Idle-reference measurement/composition checks passed.
- `preferences_final`: **29/29** weighted preferences and explicit orbit-path checks passed.
- `rig_analytic_final/coordination_report.json`: **274/274** passed on the imported rig. Both hands, actual independent-entry handoff to weapon Tip/Pommel and back, shared two-hand contact, root translation/rotation/uniform scale, opposite-arm freeze, unchanged bone lengths, inherited out-of-cone correction, and repeated +/-20-degree elbow swivels through the production rig entry. Every tested large swivel reached its requested 20 degrees. The same original Hand anchor remained fixed across all three edits: worst cumulative displacement **0.000000430 m**, worst angular difference **0.0000389 degrees**, both far below the unchanged 50 micrometre / 0.025-degree caps.
- Large elbow requests now cost approximately **37.6-40.5 ms / 17-18 FK evaluations**, compared with the failed experimental QP version's multi-second partial swivels. Small elbow samples cost about7.3-7.7ms. Free-hand fixtures29.8-56.4ms, real rig control-family handoffs17.6-18.5ms, shared two-hand sample58.8ms. These are focused diagnostic timings, not general UI frame-rate guarantees.
- The analytic elbow path rotates the captured Upperarm and Forearm frames around Shoulder-to-retained-Hand, then derives common shoulder/wrist coordinates. Shared anatomy, physical pin, original non-worsening allowance and actual stored-bone readback still decide acceptance. It does not move the clavicle or elbow hinge to fabricate a swivel. Samples are bounded; no grip/finger search is involved.
- The earlier `rig_idle_orbit` QP version **failed**: tight Hand-pin edge errors, one target/root comparison, and seconds-long partial motions. It is retained as failed evidence, superseded by the analytic path and strict physical readback. The final report serialized two unset fixture diagnostic elbow angles as JSON null (Godot NaN warning); all measured motion/contact checks passed.

### Rendered result: important remaining limit

`live_pommel`: actual saved Broken_Balde_v1 Skill3 node3, captured Pommel down/back/up input. Script completed and source-library SHA256 remained unchanged. This is **not a smoothness pass**.

The saved pose starts about23.80degrees from fixed Idle clavicle home (13.80degrees outside the new cone), with elbow approximately0.0048degrees below its minimum and an existing uncovered-shoulder hold. Recovery permits retaining/reducing inherited excess rather than locking all editing. Outward requests near that boundary nevertheless search excessively:

| Pose row -> request row (zero based) | Accepted path fraction | Allocation cost |
| --- | --- | --- |
| 5 -> 7 | 5.86% | 4465ms /10400 FK evaluations |
| 8 -> 10 | 0.390625% | 6924ms /16950 FK evaluations |
| 113 -> 115 | 47.66% | 2697ms /6316 FK evaluations |
| 116 -> 118 | 0.390625% | 5980ms /14857 FK evaluations |

Many intervening trace rows repeat the previous allocation metadata; do not count them as additional allocations. Backoff and ordinary returns became fully accepted at roughly58-61ms after initial boundary steps. Screenshot inspection shows the weapon retained in hand; this is not a complete finger-contact or skin-quality certification.

Free clavicle correctly makes the old fixed-shoulder translation reach shortcut inapplicable, which also disables the old conditional stagnation guard. A bounded experiment enabled that guard without the shortcut, but **did not resolve this request and was withdrawn**. Detailed capture shows why a simple guard is insufficient: a trial can meet endpoint limits, yet the linear interpolation of joint coordinates between endpoints violates the fixed shoulder-h relationship. Feasibility restoration can also lose task progress. This needs a coherent constrained path/parameterization or another demonstrated correction, not looser limits or new zeros. Current analytic elbow path solves its own exact orbit; it does not solve this separate Pommel boundary search.

`current_recovery_lexicographic` and `current_recovery_stagnation` contain the diagnostic comparisons. Captured JSON transforms have float loss and omit external collision; those reproductions rejected the tiny remaining progress rather than matching the live0.390625%. Do not present them as exact live timing equivalence. Added Quaternion comparison support to the capture tool for the new Idle profile fields.

### Fixed-reference audit beyond clavicle (read-only)

| Component | Current reference | Result |
| --- | --- | --- |
| Clavicle swing | Immutable supplied Idle quaternions, Spine02-relative | Fixed10degree half-cone. No per-drag renewal. Currently circular, not a newly invented cut/asymmetric cone. |
| Clavicle axial component | Existing reference-relative twist retained per request | No new axial travel parameter. Preservation is not a calibrated axial ROM interval. |
| Upperarm axial roll | Fixed chest-relative anatomical exercise from imported rig calibration | Prior h selects a continuous equivalent angle, not a new anatomical zero. |
| Upperarm swing | Angle between proximal clavicle direction and upperarm shaft | Existing8-155degree relationship; moving parent is intentional. Not an Idle-centred cut-cone implementation. |
| Forearm/wrist | Fixed rest-derived neutral and thumb-up exercise | Elbow bend legitimately changes pronation/supination bounds. Wrist bending keeps its asymmetric ellipse. No fresh per-drag anatomical range found. |
| Elbow hinge | Fixed imported material hinge | Existing12-160degree bounds. Initial flexion is a reconstruction offset, not a new zero. |

Concrete follow-up risks, **not claimed runtime reproductions**:

1. Torso hard-limit neutral currently blends Idle and2HandIdle with Body Support. Changing that setting changes the reference. Owner: `runtime/player/combat_weapon_motion_rig_adapter.gd::_build_torso`; `runtime/player/player_rig_upper_body_pose_presenter.gd::_resolve_reference_pose_rotation`. This differs from one immutable Idle home and needs reconciliation with the user's new clarification before further torso development.
2. If the torso animation baseline/cache is missing, the presenter lookup falls back to current bone rotation. That can create a drag-relative limit reference in that failure case. Preserve a known reference rather than silently adopting current pose; no blanket invalid-start edit lock.
3. Torso applies yaw/pitch increments but checks only absolute Euler yaw/pitch. Repeated noncommuting changes could accumulate its unchecked third rotation component. Needs a declared roll policy and targeted reproduction, not an invented endpoint.
4. `CombatWeaponMotionAllocator.build_start_allowance` captures existing excess, and `_legal` adds1e-6 numerical residual. Repeated accepted boundary frames could accumulate numerical-scale creep. This is not another10degrees per drag; no live long-run accumulation test was performed.
5. Uncovered shoulder held_h is a continuity anchor, not an anatomical endpoint. It persists through an uncovered excursion but explicit prepared-pose replacement can establish a new hold. Anatomical calibration itself stays fixed.

Working shoulder/forearm calibration does not literally report Idle as angle0. Converting their coordinates to Idle-relative display is possible only with the matching limit transformation. Do not change the zero alone and silently shift the actual permitted anatomy.

### Reset / Node 0 baseline follow-up (2026-11-07)

User manual testing reported that Reset's main arm starts inside the body while
the offhand resembles Idle; ordinary manipulation then crawls or freezes. The
new unsaved Skill 3 pose was not retained. Do not claim to reproduce that exact
pose. User requested copying actual Idle into the default baseline, checking its
legality, and then identified the historic anti-straight-elbow workaround.

Fresh evidence before correction: `godot_runs/initial_anatomy_20261107`.

- `raw_idle`: actual production Idle frame 0 has left elbow bend 6.5585 degrees,
  right 11.7325 degrees. Both fail the unchanged 12-degree minimum; shoulder,
  clavicle and wrist constraints pass. Mid-Idle also fails only that minimum.
- The 168-degree maximum inner elbow angle dates to commit `766a1393`
  (2026-05-02). It is a 12-degree minimum bend, not an anatomical claim. No scene
  overrides were found. Modern signed-angle branch preservation and material
  hinge safeguards are separate; keeping a nonzero bend does not require 12.
- `reset_live`: actual Reset restores Idle, then refreshes using the ordinary
  handle-position-change path. That runs the old weapon-driven body macro and
  CCD before acquisition. The main elbow becomes 41.7413 degrees; its clavicle
  violates the new fixed Idle cone. The offhand keeps its 6.5585-degree bend.
  Body Support 0.9 supplies about 0.952 one-hand macro strength. The geometry
  seed itself only reads the resting hand and positions the weapon.

Narrow correction authorized by user: accept actual Idle with a 174-degree
maximum inner angle (6-degree minimum bend); keep Reset's body authority while
the existing grip owner seats the weapon onto its stationary hand. No grip
algorithm changes, no new per-drag zero, no playable Node 0. The hidden baseline
and visible Node 1 continue using the existing prepared-pose capture, with named
parent-local bones and explicit weapon origins. The persisted Idle animation is
the body source, not a weapon-derived pose preset.

Fresh verification:

- `raw_idle_fixed` passes both arms at frame 0 and mid-Idle with zero
  common-allocator anatomical violations.
- `after_idle_fix`: real right-primary Reset/acquisition, repeated twice.
  All 47 non-digit local bone poses exactly match actual Idle after acquisition;
  both arms remain legal. Both hidden Node 0 and visible Node 1 contain complete
  50-bone prepared packets. Their 20 recorded non-digit channels match Idle
  within 0.000017 degrees, zero position error. Repeat Reset is identical.
  Primary acquisition reports `preview_applied`; existing readiness passes.
- Two ordinary +/-20 mm Pommel requests after Reset were fully accepted, with
  no initial warning or active limit: allocation 57.386/65.467 ms, setter
  90.686/101.698 ms, 56/57 evaluations. This is a small-movement result, not
  universal buttery-smooth motion. The previous 4-7-second boundary reports used
  a different inherited pose and are not an apples-to-apples speed comparison.
- `after_idle_fix_left`: same real workflow with left hand primary, two Reset
  acquisitions. Both arms legal; all 47 non-digit bones exactly Idle; Node 0 and
  Node 1 complete and match Idle. Both +/-20 mm Pommel requests fully accepted,
  allocation 73.722/60.624 ms (70/56 evaluations), setter106.999/94.867 ms. Poses
  remain unchanged across the following three idle frames, so this does not
  leave the controls frozen at the baseline or roll back the accepted motion.
- Source save SHA256 unchanged. No Save/F/equipped workflow rerun or changes.
  Reset reuses the existing persisted Idle animation as canonical body source;
  hidden Node 0 remains excluded from playable/saved action chains. Normal Save
  persists visible Node 1 and its acquired relationship through existing owners.

Baseline authority is distinct from accepted movement authority: it suppresses
only legacy macro body/arm/wrist repositioning during baseline preparation, while
finger acquisition remains active. A new accepted authored movement or restored
node takes body authority normally. `reset_baseline` is a one-refresh command,
not a new persisted node field or grip algorithm.

Existing authored/saved skills are not silently rewritten. Reopen and use Reset
to test this corrected default. Shared two-hand preparation still invokes the
existing support-only join logic; it was reviewed in code but not freshly run
in this narrow one-hand baseline check. The legacy direct wrist-roll API also
releases baseline authority after a successful commit, consistent with the
current allocator-based UI control.

Separate collision finding: actual weapon restriction samples still exist.
The editing allocator currently receives no collision callback (removed to
avoid invalid-start lockout). This is distinct from the anatomical failures.
Debug visibility did not create the lazily built weapon marker meshes; enabling
Debug now invokes the existing visual refresh. Collision gliding/escape response
remains pending; do not reconnect a reject-on-invalid-start callback.

### Shoulder coverage follow-up after corrected Reset (2026-11-07)

User still could not pose and received `shoulder_direction_not_calibrated`.
This is separate from the now-verified Idle baseline. The active provisional
table used isolated 15-degree neighborhoods around sparse checked directions,
and treated +/-10-degree inspection increments as hard anatomical endpoints.
Those numbers were provisional authoring choices in the research supplement,
not measured movement limits. User previously authorized provisional coverage
adapted to the actual rig; the research is guidance, not a literal specification.

Read-only baseline audit:
`godot_runs/shoulder_coverage_20261107/legacy/coverage_report.json`.
Both sides: forward angular grid has 703 samples, 532 covered, 169 missing and
2 conflicting. Counts repeat poles/seams and are NOT spherical area percentages.
The e60/p22.5 and e45/p22.5 directions are uncovered. Right Idle starts near
e13.73/p23.62 with h32.15; a small elevation change reaches a gap, then a narrow
checked interval. Thus a valid Reset could still lead straight into a coverage
wall. The old donor intersection also jumps at boundaries such as e75/p0.

Scoped correction implemented: continuous provisional regional envelope in
the existing fixed chest-relative h convention. Blend the mapped lowered pair
into the original shoulder-height table, then into the existing conservative
upper-region pair. Posterior/medial directions use an explicit provisional pair
and smooth transitions. Original measured height/plane values stay exact;
new regional interpolation is engineering tuning, not clinical calibration or
body-clearance certification. No current-pose zero, growing allowance, grip
changes, wrist/elbow changes, allocator rewrite or Save/F lifecycle changes.
Old sampled-disk mode remains available for historical evidence/comparison.

Production owners: `core/defs/shoulder_motion_profile_def.gd`,
`core/defs/characters/josie/shoulder_motion_profile.tres`, and
`core/resolvers/combat_shoulder_motion_resolver.gd`.
Fixed regional tuning is explicit in the profile: lowered e2 pair -65.1/+66.9;
original e90 published table; upper e150 pair -10/+10; posterior transition
starts at plane -30 with pair -10/+10. Smoothstep blends between elevation
regions and posterior/medial transitions. The upper/posterior pairs remain
conservative provisional tuning, not demonstrated maximum usable motion.

Fresh verification (one engine run at a time, after user's closure confirmation):

- `godot_runs/shoulder_coverage_20261107/continuous_verifier_final/report.json`:
  352 checks pass, including 5,402 bilateral grid samples, exact original
  shoulder-height intervals, two-sided region-boundary continuity, fixed-reference
  +/-500-degree rejection, immutable profile and legacy-mode behavior. Invalid
  input is rejected before normalization, avoiding engine warnings in that probe.
- `continuous_audit/coverage_report.json`: 2,701 samples per arm, all covered,
  zero conflicting intervals. The forward subset is now 703/703; the old
  169 missing and two conflicting samples are resolved. These are angular-grid
  counts with duplicated poles/seams, not area percentages. Actual-Idle-to-donor
  paths are sampled at <=1-degree steps.
- `continuous_runtime/report.json`: 104 checks pass on the imported rig,
  both sides, lowered/raised/posterior regions. Finite outward stops, release/
  regrab without rebasing, and inward reversal remain enforced. Captured profile
  survives serialization with matching bounds. Numerical rigid contact fixture;
  no finger-grip or full saved-skill playback claim. This report was generated
  at `godot_runs/provisional_shoulder_runtime/report.json` and copied into the
  scoped evidence directory; the runner takes `--out-dir`, not `--out`.
- `live_reach/initial_anatomy.json`: real Broken_Balde_v1 Skill 3 UI, right
  primary, two actual Reset/acquisition cycles then ordinary Pommel setters.
  Reset body exactly matches Idle; 33 movement requests produce retained,
  anatomically accepted poses, all with shoulder coverage and no missing-
  calibration warning. The sequence uses 30 mm increments in authoring-local
  +Y, -Z, +Z, -Y; those labels are not world-space directions. Source save SHA256
  unchanged. No Save/F/equipped run or changes. New continuous policy has fresh
  bilateral numerical/runtime coverage, but the full live reach probe was R only.

**Remaining user-visible problem, not fixed by this coverage pass:** many reach
requests are only partially accepted near clavicle/coupled wrist limits. In the
live probe, 15 requests were fully accepted (setter about 97-151 ms), while 18
were scaled down. Worst setter 3,270 ms: 10,972 evaluations, clavicle swing and
coupled-limit active, only 0.005208 task fraction accepted. The probe stopped
after that request rather than repeatedly hammering the boundary. Reversal in
the third direction resumed full movement, but this does not establish smooth
or symmetrical usability for arbitrary poses. Coverage is fixed; expensive
boundary search/coordination remains a separate follow-up. No iteration-budget
or acceptance-tolerance changes were made here.

Review caveat: the existing anatomical orientation chart has a warned switch
very near the directly inward shaft direction. New interval bounds are
continuous there; physical hinge/h continuity across that chart is not newly
certified. This is separate from the removed 15-degree coverage holes.

Next manual check: restart the game to load the new profile, reopen Skill 3 and
Reset for the corrected Idle baseline. Do not describe all movement as fixed or
buttery smooth. Grip remains unchanged, and upper/rear provisional ranges still
need eventual tuning. No Git index, commit or push operation in this pass.

### Reference links

- [Coordinated Arm Motion and Posture Selection Guide](<../Reserch/The Will Coordinated Arm Motion and Posture Selection Guide.md>) — constraints vs preferences and coordinated contribution.
- [Weapon Motion Allocation and Joint Priority Guide](<../Reserch/The Will Weapon Motion Allocation and Joint Priority Guide.md>) — task decomposition and chain ownership.
- [Shoulder and Forearm Rotation Limits supplement](<../Reserch/Shoulder and Forearm Rotation Limits for Josie (1).md>) — provisional coverage, not literal rig instructions.
- Godot 4.7 [Quaternion](https://docs.godotengine.org/en/4.7/classes/class_quaternion.html), [SkeletonModifier3D](https://docs.godotengine.org/en/4.7/classes/class_skeletonmodifier3d.html). Continue current kinematic authoring pipeline; physics ConeTwistJoint3D is not a replacement for this skeleton solver.

## Wrist X/Z control ownership — 2026-11-07 late-session addition

User references: `images and refferences/Recording 2026-11-07 231950.mp4`
(right Hand) and `Recording 2026-11-07 232504.mp4` (left Hand), at the Git
root. These demonstrate actual Skeleton3D Hand bone parent-local Euler edits,
not game-world axes. The user superseded the recordings' asymmetric Z endpoints
with **-55 to +55 degrees on both sides**. X is **-65 to +35 degrees**.

Explicit control ownership:

- Tip and Pommel may recruit wrist X bending. They must retain the selected Z
  bend: blade alignment is a user decision, not a solver compensation channel.
- The existing green control now commands wrist Z, retaining X, forearm roll,
  primary elbow/upper arm/clavicle, and the wrist position. The acquired rigid
  Hand/WeaponRoot relationship carries the weapon. A second gripping arm may
  still follow shared weapon movement, as previously authorized.
- There is no independent wrist Y/axial roll. The existing forearm rotation
  owner and its elbow-dependent limits are unchanged. Tip motion still stops
  at the clavicle connection; this pass does not extend its torso authority.
- Dark-green weapon-only roll and grip acquisition/seating are unchanged.
- The existing combined-bend ellipse remains in effect: simultaneous X/Z
  maxima were not demonstrated or requested as independent rectangular corners.

The previous beta/gamma axes were palm-landmark axes around imported Hand rest,
so merely changing endpoint numbers would rotate around the wrong directions.
The new `hand_parent_local_xz` profile selects Hand-parent identity after
forearm roll: `R_forearm(rho) * ForearmFrame * Rx(beta) * Rz(gamma)`.
It is fixed relative to the named Forearm bone in the existing calibration
chain through RL_BoneRoot, never a world origin or a newly recaptured neutral.
The imported anatomy calibration remains unchanged for forearm roll/reference
and older saved profiles. Profiles without the new key retain their original
`rest_anatomical` interpretation.

The remembered perpendicular rule was investigated: primary grip acquisition
aligns the weapon axis to the Index-Pinky axis and seats the selected handle %
against the stationary hand. The perpendicular seating plane prevents axial
slide. Neither rule requires wrist/forearm perpendicularity. Both are preserved.

Production owners for this addition: `wrist_motion_profile_def.gd`, Josie's
`wrist_motion_profile.tres`, `combat_wrist_motion_resolver.gd`,
`combat_weapon_motion_rig_adapter.gd`, and the green-control target/limits in
`combat_animation_station_preview_presenter.gd`. The green target pivots about
the actual Hand origin using its acquired binding; it no longer asks a weapon
axis rotation to find an arbitrary combination of body motion.

Compatibility: the captured arm context includes the complete wrist profile.
Changing this frame/limits therefore invalidates old prepared node contexts;
normal editor recapture is required. The existing current-context gate and
shared-layout gate prevent blending old/new scalar coordinates in an authored
track. No new grip algorithm, skill format, Save/F lifecycle or migration
system is added here.

Transient entry can still connect a current live pose to an older saved skill.
`combat_prepared_pose_track_builder.gd` now omits incompatible wrist scalar
overrides for interior samples of that bridge only, using the existing bone
quaternion interpolation and attachment/material guidance. Exact endpoints and
matching-frame scalar interpolation are unchanged. This is a nine-line frame
compatibility guard, not an additional grip solve or an alternate playback.

Fresh focused verification:

- `godot_runs/wrist_local_bend_20261107/final_bounded/report.json`: **229 checks
  pass** using Godot 4.7 and the imported Josie rig. Both actual Idle wrists
  remain legal. Literal X/Z isolated endpoints, out-of-range rejection,
  combined envelope, transformed-root covariance, immutable profiles and
  unchanged forearm zero/intervals are checked.
- Actual adapter commits check R/L green Z edits, Tip edits and Pommel edits.
  Selected Z is retained during Tip/Pommel. Green retains X/rho and primary
  clavicle/upperarm/forearm/helper transforms. Both Z limits and reversal are
  reached at held X=10 degrees using +limit -> centre -> -limit, without Reset
  or renewed range allowance. The remaining ellipse makes those endpoints
  about +/-52.7 degrees; X=0 permits the full isolated +/-55 degrees.
- Shared two-hand support freedom is checked at the adapter parameter bounds,
  not through a live two-handed grip/acquisition sequence.
- `godot_runs/wrist_local_bend_20261107/prepared_compatibility/report.json`:
  **50 checks pass** in the synthetic prepared-anatomy verifier, including
  old/new-frame transitions in both directions, absent legacy frame keys,
  unchanged endpoints/inputs and persistence of matching-frame interpolation.
  This checks the common sampler, not a complete user skill lifecycle.
- A single ~105-degree reversal request hit the **existing** 60-degree-per-call
  substep budget and correctly returned a partial movement. The final check
  used a continuous sequence of requests within that budget. No iteration,
  tolerance, speed-limit or movement-budget change was made.
- Initial test-only Hand reposing left its forearm skin helpers in Idle's old
  rotations. The verifier now initializes those helpers through the unchanged
  production distributor before recording its comparison baseline; no
  production workaround or tolerance relaxation was used for that fixture.

Full live mouse interaction, visual skin quality, complete F/Save and equipped
playback are not newly certified by these body-focused checks. Ready for manual
testing after restarting to load the new profile. Existing older prepared nodes
need normal recapture because their arm-context profile changed.

Git was not authorized by the wrist implementation request itself. On
2026-11-08 the user manually tested the result, reported "we have usable body
now", and requested a Git push with a **Stable body** tag. The resulting
checkpoint is identified by annotated tag `Stable-body`. This is user acceptance
of current body usability, not a new certification of every pose, skin behavior,
boundary-search cost or complete Save/F/equipped lifecycle.
