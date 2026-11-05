# Weapon motion allocation — 2026-10-29

## Authorized scope

User: adapt `Reserch/The Will Weapon Motion Allocation and Joint Priority Guide.md`
to the current rig and test at the end. Adjust existing components when they
conflict with, or duplicate, the allocator's responsibility. This supersedes the
previous no-engine-testing instruction for the wrist/pivot implementation.

This is the next layer above the existing arm material hinge and semantic wrist
mechanism. It does not introduce new anatomy, shoulder/spine controls, finger
acquisition, Unarmed lifecycle work, or a new equipped animation system.

## Contracts

- Tip requests weapon orientation with no world-space grip pivot (user-directed
  test, 2026-10-30). The acquired hand–weapon relationship stays rigid while the
  hand and weapon can travel with legal arm motion through the clavicle. Spine
  and torso remain in their captured poses. This supersedes the previous fixed
  selected-Handle-station Tip rule; historical evidence below keeps its date.
- Pommel translates the whole weapon while holding its orientation.
- Attached Roll rotates about the selected station parallel to the weapon axis,
  with forearm rotation preferred and legal compensation available. This
  supersedes the old wrist-to-Tip orbit/240-degree UI window as the attached Roll
  authority. Anatomical wrist/forearm limits are retained.
- The dark-green weapon-only roll cube stays separate: stationary body,
  deliberate new weapon facing, manual grip reacquisition.
- Bone length, acquired grip transforms and joint limits constrain allocated
  motion. Joint contribution is a mode-specific preference. Collision/no-go
  checks belong to path evaluation, not permission to manipulate attached
  Tip/Pommel/Roll controls (latest user clarification, 2026-10-30).
- An anatomical limit already exceeded at the start is a warning, not a movement
  lock (2026-10-30 correction). Movement may retain or reduce that existing
  excess; it cannot enlarge it or violate previously legal limits. The baseline
  is captured once per request and used through commit/readback. Normal limits
  apply again as the pose is corrected; no permanent extra range is saved.
- Reverse direction restores inward joint eligibility immediately. The reference
  is the last accepted configuration, not a hidden neutral-return target.
- Relative mouse input is rebased after each accepted/rejected step. Numeric
  edits are absolute requests. No rejected-input backlog.
- Primary and support hands share one weapon pose; the primary contact is pinned
  only for attached Roll. Tip has no position-lock task.
- The acquired hand-to-weapon binding remains the reference across successive
  commands. Attached Roll additionally retains its mode-entry contact anchor.
  Numerical tolerance is not accumulated by recapturing the previous command's
  residual as a new attachment target.
- Shoulder swing and humeral axial rotation use distinct contribution groups,
  derived from the rig's imported material frame, with the same existing DOFs.
- Editor commits body and weapon together. Existing R/F/Save captures store the
  accepted bone channels and weapon frame. Allocation is not rerun per equipped
  playback frame.

## Owners

- `core/defs/weapon_motion_policy_def.gd`: numerical budgets and contribution
  policy, separate from anatomical definitions.
- `core/resolvers/combat_weapon_motion_allocator.gd`: pure constrained task
  allocation, priorities, task scaling and finite candidate validation.
- `runtime/player/combat_weapon_motion_rig_adapter.gd`: calibrated current-rig
  FK, joint constraints, world task to parent-bone-local conversion and commit.
- `player_humanoid_rig.gd`: accepted-pose authority and suppression of conflicting
  legacy body/reach/wrist writers while that editor pose is retained.
- `combat_wrist_motion_resolver.gd`: shared unchecked forward sampling for
  numerical derivatives; existing legal composition still governs acceptance.
- `combat_animation_weapon_motion_manipulator.gd`: editor transaction and
  retained-state identity. Frame encoding happens before committing the rig.
- `combat_animation_station_preview_presenter.gd`: station/scene adaptation,
  existing collision observer, retained pose before legacy scene refresh.
- `combat_animation_station_ui.gd` and `combat_animation_motion_node_editor.gd`:
  control routing and pointer rebasing.
- `combat_animation_render_checkpoint.gd`: retain allocator state across existing
  editor suspension/restore; no camera mutation.
- `combat_runtime_entry_transition.gd`: matching saved calibration must survive
  text-resource numeric round-trip before cold equipped entry restores neutrals.

## Coordinate and lifecycle rules

Weapon tasks use explicitly world-space transforms. Grip landmarks are
WeaponRoot local. Bone local channels derive from the imported hierarchy through
RL_BoneRoot. Existing TrajectoryAuthoringOrigin and solved replay reference
conversions remain the persisted authoring/playback representation.

Moving the camera or switching control mode does not reset the accepted joints.
Reset, a changed acquisition, or another authored body control releases retained
allocation authority. A rejected candidate cannot overwrite the accepted pose.
Transient allocation objects do not belong in saved weapon resources.

## Bounded adaptation and known limits

The guide is adapted to the existing rig rather than importing new anatomical
degrees of freedom. Its existing shoulder/clavicle geometric limits remain;
this pass does not establish a complete independent humeral axial ROM envelope.
The existing coupled wrist model, elbow hinge and forearm limits are enforced.

No new gameplay velocity/acceleration limits, braking phase or automatic
null-space posture recovery is introduced. Numerical step/search budgets bound
work. `SEARCH_EXHAUSTED` means this local attempt failed, not that every possible
pose is physically impossible. Collision validation uses finite intermediate
samples, not a continuous collision-proof trajectory.

This allocator governs editing increments. Recorded endpoints continue through
the existing prepared R/F/Save/equipped path. A legal endpoint pair does not
certify every arbitrary authored curve between them; existing playback
validation remains in place.

## Focused input overhead correction

The actual-station check exposed repeated `ensure_combat_animation_station_state`
calls through nested selection/draft getters. Each call normalizes the station's
drafts. A numeric Tip edit measured about 948–970 ms while the allocator itself
took tens of milliseconds. Wrapping a comparison edit in the existing
synchronous authoring lookup scope measured 35.658 ms.

Tip/Pommel numeric setters and the throttled mouse flush now use that existing
scope, as attached Roll already did. Only repeated preparation in the same
synchronous call is reused; live node/selection values remain live. No anatomy,
grip or collision checks are omitted. This is not a whole-workflow speed claim.

## Verification status

Fresh final-policy/rig checks on Godot 4.7:

- `tools/verify_combat_weapon_motion_allocator.gd`: **23/23**, including ordered
  contributions, fixed contact, scaling/reversal and retained-anchor drift.
- `tools/verify_combat_weapon_motion_rig.gd`: **82/82**, using the actual imported
  rig for R/L Tip, Pommel, Roll, wrist-boundary reversal, shared two-hand contact,
  transformed origins and the shared saved-pose writer.
- Reports: `C:/WORKSPACE/godot_runs/weapon_motion_allocator_20261029/policy_final`
  and `rig_final`.

Final actual-station checks through
`tools/diagnose_skill_crafter_weapon_motion_allocation.gd`: **R 23/23, L 23/23**.
Isolated copies of `Broken_Balde_v1`, source ID
`player_wip_1792291462.519_14`, use Skill 2. Sequence: reset/acquire, repeated Tip
and reversal, Pommel, attached Roll, real UI mouse-event Tip drag, R, F, Save and
fresh disk reload. Tests also save combat idle through its own Reset/Save page.

- Retained original contact reference stayed unchanged across four Tip inputs;
  maximum measured C residual was 22.89 micrometres (allowance 50 micrometres).
- Mouse events went through the existing preview GUI handler and throttled
  flush. Both sides accepted actual Tip movement and retained hand contact;
  authoring lookup depth returned to zero.
- Numeric Tip edits: 35.7–48.3 ms for the tested small changes.
- F preparation: R 830 ms, L 843 ms. Actual Save: R 0.71 s, L 0.73 s.
- Reports, screenshots and isolated libraries:
  `C:/WORKSPACE/godot_runs/weapon_motion_allocator_20261029/station_final/`.
- Screenshots were inspected. These small-motion checks do not certify skin
  quality across every pose, reverse grip or every existing authored skill.

An early Save run used an inherited skip-persistence flag: it proved in-memory
preparation only. The final runs above enable disk saving and reload the clip.
An early R-to-L reused-fixture setup timed out waiting for its left baseline;
final sides use separate fresh station instances. Cross-hand switching is not
certified by those separate runs.

The equipped test first found an old combat-idle prerequisite; refreshing only
that idle through the isolated SC page resolved it. The next current-pose
capture exposed exact nested `wrist_profile` equality after disk round-trip.
Godot ResourceSaver/Loader changed two small profile values by only
2.39e-18 and 4.77e-18 radians. That false mismatch prevented the existing cold
entry fallback from restoring saved UpperarmTwist neutral references.

`combat_runtime_entry_transition.gd` now compares the same finite numeric profile
fields using a 1e-12 absolute/relative serialization allowance; keys/revision must
still match. Actual joint/contact tolerances and separate wrist rest/axis checks
are unchanged. `tools/verify_combat_runtime_entry_calibration.gd` passes **11/11**,
including real text save/reload, neutral restoration and rejection of actual
limit/revision/rest changes, NaN and missing fields. Evidence: `entry_calibration_after`
under the same evidence root.

Final equipped-only rerun **passed**, using the unchanged final station file and
the production PlayerController path via controlled verifier ticks:

- Slot 2 activation starts; saved body channels stay unchanged.
- Saved and equipped rates both 60 Hz; transient entry remains 160 ms.
- 13 saved frames become 23 runtime frames over 0.36 s, including entry.
- Zero grip-acquisition starts through activation/playback.
- Final pose matches the saved endpoint within the verifier's precision.
- Report: `equipped_after_calibration.json` under the same evidence root.

This is production-controller verification, not an OS-keypress/walking manual
test. No broad all-weapon/all-gesture certificate is implied. All test engine
processes were closed; the user's existing editor remains open.

The source library must remain unchanged. Starting SHA256:
`839C5D18B28903F94D5A83B1F3349567D49D50807BD0621168D8CFB2C123A6DF`.
The same hash was rechecked after the final station runs.

## Engine references consulted

- [Godot 4.7 Skeleton3D](https://docs.godotengine.org/en/4.7/classes/class_skeleton3d.html):
  bone global poses are Skeleton3D-relative, not world-space.
- [Godot 4.7 Transform3D](https://docs.godotengine.org/en/4.7/classes/class_transform3d.html):
  explicit affine conversion and basis/scale handling.
- [Godot 4.7 IKModifier3D](https://docs.godotengine.org/en/4.7/classes/class_ikmodifier3d.html):
  native IK integration points; the guide's ordered task allocation needs its own
  resolver above the existing rig constraints.

No Git index/history operations are authorized by this implementation request.

## 2026-10-30 follow-up: small movement followed by lockout

User report: minimal movement works, then controls lock with
`allocator_initial_pose_invalid`; possible conflict between old and new rules.
Scope is the accepted-pose handoff and allocator re-entry, not another anatomy
redesign or a general increase in joint/contact allowances.

### Reproduced causes

1. Held mouse movement could lose the new allocator's ownership. The UI skipped
   near-equal accepted weapon coordinates, while ownership compares an exact
   pose signature. The following refresh then ran the older positioning logic
   and changed the arm away from the accepted pose. Mouse release had the same
   approximate-copy seam.
2. Repeated two-hand commands reproduced the exact initial-pose failure on the
   imported rig. Support constraints used an inscribed component box
   (`tolerance / sqrt(3)` on each axis), while the physical contact contract is
   total distance and total angular error. Skeleton write/readback rounding
   crossed a box face even though total contact stayed legal: R measured
   46.262 micrometres / 0.022666 degrees; L measured 35.737 micrometres /
   0.024228 degrees. No anatomical bounds failed in those samples.

The 0.05 mm and 0.025 degree physical caps remain authoritative. The existing
0.05-degree legacy shoulder/elbow epsilon differs from the new allocator's
numerical epsilon, but it did not cause these reproduced failures; it has not
been changed speculatively.

### Current evidence and limits

Evidence root: `C:/WORKSPACE/godot_runs/weapon_motion_boundary_20261030/`.
Diagnostics: `tools/diagnose_weapon_motion_boundary_reentry.gd` and
`tools/diagnose_weapon_motion_commit_readback.gd`.

- `held_reset` and `held_current`: before correction, 13/20 and 19/20 held
  movement events failed respectively. Reset case also recorded two explicit
  ownership/signature losses. The original small-motion test did not exercise
  a sustained drag and therefore missed this seam.
- `held_reset_after` and `held_current_after`: exact copying in
  `combat_animation_station_ui.gd` preserves all seven encoded weapon fields
  during refresh and release. All 46 requests across the two tests passed,
  including reversal, release/regrab and subsequent Pommel movement. Both
  ownership and signature remained valid after intervening frames.
- `commit_readback_before`: repeated fresh adapter capture with unchanged
  acquired bindings reproduces the exact initial-pose error in R/L two-hand
  cases. One-hand fixture sequences passed. This is an imported-rig/rigid-prop
  test, not a claim of live two-hand grip acquisition on every saved weapon.
- Numeric boundary tests `open_current` and `reset_x` reached a limit and could
  reverse or move Pommel; those tests did not reproduce a deadlock.

### Completed corrections

- `combat_animation_station_ui.gd`: copy all seven accepted weapon fields
  exactly during held-drag refresh and transfer to the stored node on release.
- `combat_weapon_motion_allocator.gd`: separate conservative linear search
  constraints from actual physical legality. A pose outside a search slab is
  not automatically an invalid physical starting pose. Initial and nonlinear
  checks continue using actual constraints. Squared-norm derivatives use the
  chain rule; custom search rows use their own derivative indexing.
- The active-set matrix mixed unit joint rows with contact rows of roughly
  1,000-10,000. Failure traces showed repeated full steps with an unchanged
  active set until the iteration budget expired. Normalize constraint rows
  only when building that matrix, and convert multipliers back to their
  original scale. Original feasibility/line-search predicates, objective,
  physical allowances and the 80-iteration budget are unchanged.
- A requested movement that is scaled below tolerance without changing any
  joint state now reports `allocator_no_task_progress`, rather than falsely
  reporting successful movement. Zero-input/within-tolerance holds still work.
  This is not a universal responsiveness certificate: the regression checks
  actual weapon movement and direction independently.
- `combat_weapon_motion_rig_adapter.gd`: use actual support distance/angular
  norms for hard legality, retaining the original conservative component
  slabs only to guide the search. Preserve exact acquired bindings; do not
  reconstruct them through repeated inverse-transform operations.
- Candidate storage/readback validation and final commit share the same
  physical contract. Internal numerical trials may carry unfinished task
  residual; final commit additionally checks the original retained pivot.
  These checks capture and evaluate the pose, without another motion solve.
- Invalid writes restore exact prior bone Quaternions, wrist states/failures,
  weapon transform and existing authority. Temporary validation restores the
  same exact data, avoiding extra Basis-to-Quaternion round trips.
- Physical angular acceptance uses the same scalar relative-quaternion angle
  as the existing rig check. A world-axis rotation vector remains available
  for directional solving; its float32 vector length is not a separate final
  acceptance rule.
- `combat_animation_weapon_motion_manipulator.gd`: preserve commit rejection
  diagnostics instead of replacing them with a generic error. Initial-pose
  diagnostics identify actual violated bounds/constraints, with bounded detail.

### Final verification and remaining limits

Godot 4.7, one substantial engine run at a time:

- `policy_normalized/policy_report.json`: **26/26**, including physical/search
  separation and the no-op reporting regression.
- `rig_normalized/rig_report.json`: **82/82** after the numerical correction,
  including transformed origins, existing anatomy and the shared pose writer.
- `commit_readback_metric_final/readback_report.json`: **179/179** after the
  final scalar-angle alignment. R/L, one/two hands, retained original bindings,
  six consecutive forward/reverse commands, actual angular progress/sign,
  fresh re-entry, inside/outside physical tolerances and forced-invalid-commit
  exact rollback. All 12 two-hand commands moved in the requested direction.
  Maximum support errors: **49.9765 micrometres / 0.024999931 degrees**.
- `held_lifecycle_verified/manifest.json`: **14/14**, actual isolated
  `Broken_Balde_v1`, Skill 2, right primary hand. Twenty held pointer events,
  release/regrab, Pommel, R, a second-node held drag, F, real Save and disk reload.
  All 23 first-node movement requests retained ownership/signatures. Both
  nodes' 50 recorded bone channels survived R/F/Save/reload, with zero measured
  position change and at most 0.00000935 degrees of rotation difference.
  F prepared in **836 ms**, Save in **0.72 s**.

Single-hand allocation in that final station run averaged **14.757 ms**, maximum
**18.711 ms**; storage checks averaged **3.329 ms**, maximum **4.096 ms**.
The Pommel setter took **36.518 ms**. Mouse-handler timing excludes the queued
flush and is not end-to-end input latency.

**Remaining performance limitation:** one difficult two-hand imported-rig
fixture took **3315.793 ms** for a reversed movement. It produced legal, actual
motion and stayed re-enterable; it is not a quick response. This pass does not
claim all boundary searches are fast and does not raise budgets to hide them.

Earlier intermediate reports containing green acceptance-only checks are not
responsiveness evidence: strengthened tests exposed unchanged poses reported as
scaled movement. The final 179-check report includes actual movement and sign.
One intermediate lifecycle run had a test helper Vector4/Quaternion conversion
error; only `held_lifecycle_verified` is the completed lifecycle evidence.

Actual two-hand station acquisition, all reverse-grip gestures and equipped
playback were not rerun in this follow-up. The shared rig and saved pose path
were exercised; the preceding SPS's equipped result remains historical.
User's exact unsaved failure pose was unavailable. Repeated real single-hand
input and the exact initial-pose error in the two-hand fixture were reproduced.

The original player library retained SHA256
`839C5D18B28903F94D5A83B1F3349567D49D50807BD0621168D8CFB2C123A6DF`.
Only the isolated test library was saved. All owned engine processes exited;
the user's existing editor remained open. No Git index/history operations.

Next: user retest the original held-drag sequence. If a lock remains, inspect
the actual named `initial_diagnostics` / `commit_diagnostics` row first. Do not
relax anatomy or contact caps speculatively. Address the documented two-hand
boundary cost as a separately bounded performance investigation if requested.

### User clarification after verification, 2026-10-30

The user confirmed that the original lockout happened with **one hand**. This
resolves the pending configuration question recorded in the 00:54 SPS.
The corrected single-hand held-drag ownership failure and final single-hand
R/F/Save checks are relevant, but the exact `allocator_initial_pose_invalid`
message was reproduced only in the separate two-hand fixture. Do not attribute
the user's original error to the support-hand constraint defect. Confirmation
that the original single-hand lockout is resolved still requires the user's
retest or reproduction of that particular failing pose.

## 2026-10-30 user-directed test: remove Tip spatial locking

The user rejected the proposed wrist-limit-triggered pivot handoff. For testing,
remove spatial locking during Tip manipulation from the start. This supersedes
the previous fixed-C Tip requirement; it does not remove anatomy, collision or
the acquired hand-to-weapon attachment.

Implementation plan: Tip continues to request weapon orientation, while the
existing joint allocator can move the grip through space. Do not substitute a
fixed Pommel, wrist, elbow or other world-space pivot. Keep Pommel and attached
Roll behavior unchanged. No automatic reacquisition or new UI toggle.

Owners: `combat_weapon_motion_allocator.gd` (angular Tip task and no retained
Tip anchor), `combat_animation_weapon_motion_manipulator.gd` (Tip handoff),
`combat_weapon_motion_rig_adapter.gd` (anchor contract). Update the existing
focused verifiers to check actual grip travel, preserved attachment and joint
limits, plus one bounded isolated actual-weapon held-drag check. No original
save writes or Git operations. Completed verification follows below.

Follow-up direction: Tip influence stops at the clavicle. This is interpreted
as including clavicle motion while keeping the spine, torso and roots in their
captured poses. The Tip adapter therefore does not expose torso motion channels;
it still exposes the existing clavicle and arm channels with their current
anatomical constraints. Pommel and attached Roll retain their existing chain.

### Implementation and focused verification

Tip uses three angular task/Jacobian rows. Position is not part of its fit,
substep budget or target-completion condition. Full position/orientation checks
still protect the acquired hand-to-weapon binding and stored-pose readback.
Only attached Roll receives and enforces a retained world contact anchor. The
accepted weapon frame is actual joint FK and is encoded through the existing
authoring origin conversion; no new world-origin convention or attachment solve.

Fresh Godot 4.7 evidence:
`C:/WORKSPACE/godot_runs/weapon_motion_free_tip_20261030/`.

- `policy/policy_report.json`: **32/32**. Includes an elbow-lever fixture where
  Tip succeeds only by moving the grip, unchanged result for a displaced target
  origin, rigid attachment and preserved wrist limit; the same motion cannot
  complete under attached Roll's fixed pivot.
- `rig/rig_report.json`: **99/99**. Actual imported R/L arms, transformed origins,
  wrist-boundary elbow contribution, unchanged spine/root ancestors, rigid hand
  relationship, support-hand case, unchanged Pommel/Roll contracts and shared
  saved-pose writer.
- `held_actual_weapon/manifest.json`: isolated actual `Broken_Balde_v1`, Skill 2,
  right single hand. Twenty held pointer events plus reversal/regrab, then
  Pommel. All **22 Tip steps** retained accepted-pose authority with no drag
  failure (18 ACCEPTED, 4 SCALED). Tip never sent a position-constrained request.
  Maximum hand attachment error **0.23935 micrometres / 0.00001914 degrees**.
  Above-clavicle ancestors had **0 m** position change and at most
  **0.00002181 degrees** of quaternion round-trip difference.

**Important control-feel limitation:** the first 4-pixel input moved the
allocator contact C by **70.532 mm**. The separately captured acquired surface
reference moved **69.948 mm**, with maximum excursion **140.636 mm** over the
run; these are distinct WeaponRoot-local landmarks. Initial
contributors were elbow and wrist, not shoulder/clavicle/spine. Removing the
position constraint exposes this distal allocation tradeoff; the test confirms
free contact travel, not satisfactory fine-control feel. Allocation averaged
**147.06 ms**, maximum **782.586 ms** overall. The 18 fully accepted steps
averaged **17.958 ms** (maximum **26.186 ms**); the four scaled steps averaged
**728.026 ms**, roughly 609–783 ms each. Do not describe this as universally
smooth or as a performance fix.
User manual evaluation is the next step before further tuning.

This pass did not repeat station R/F/Save or equipped playback; those earlier
results remain historical. The current shared saved-pose writer passed in the
rig check. Original player library SHA256 remained
`839C5D18B28903F94D5A83B1F3349567D49D50807BD0621168D8CFB2C123A6DF`.
All owned engine runs ended; only the user's editor remained. No Git operations.

## 2026-10-30 follow-up: invalid starting pose must not disable movement

User explicitly requests removing the initial-position checker as a movement
blocker. A text notification is acceptable; losing control and requiring Reset
or reacquisition solely because the current anatomy is out of range is not.

Narrow implementation: treat already-existing anatomical excess as a per-request
baseline. New movement may reduce it in stages without having to reach complete
legality in one mouse event. Do not worsen that excess or relax previously legal
limits, acquired attachment or finite-data requirements. Once a subsequent
request begins within the ordinary limit, the allowance disappears. No automatic
recentring or altered anatomical definitions.

This must cover allocator samples and the fresh adapter used for stored-pose
readback, otherwise the same lockout simply moves to commit. Production owners:
`core/resolvers/combat_weapon_motion_allocator.gd`,
`runtime/player/combat_weapon_motion_rig_adapter.gd`, and the existing station
status path in `runtime/combat/combat_animation_station_preview_presenter.gd` /
`runtime/combat/combat_animation_station_ui.gd`.
Retain the free-Tip/clavicle boundary from the preceding test.

The game was closed and the user confirmed closure before testing. No Git or
original save changes are part of this work.

### Implemented behavior and evidence

- The allocator captures initial scalar/named anatomical excess without mutating
  the anatomy profile or input. Its samples, nonlinear checks and intermediate
  motion share that one allowance. Contact/equality checks are not widened.
- The rig adapter retains the original allowance for temporary writes and final
  readback. Fresh readback cannot grant a candidate a bigger allowance. The next
  real user request captures the now-improved pose, so available excess shrinks.
- `initial_warning` describes the starting excess; `pose_warning` describes what
  remains at the accepted pose. The existing station status displays
  **Pose outside anatomical limits. Movement remains available to adjust it.**
  This message does not gate input and clears when the accepted pose is legal.
- No automatic initial pose repair, re-centring, finger reacquisition, anatomy
  change or budget increase. Tip still has no spatial pivot and stops at the
  clavicle inclusive. Separate malformed calibration/data, lost attachment and
  collision checks retain their own errors; this change concerns representable
  existing anatomical excess.

Fresh Godot 4.7 evidence root:
`C:/WORKSPACE/godot_runs/weapon_motion_recovery_20261030/`.

- `policy/policy_report.json`: **43/43**. Scalar and coupled partial correction,
  no worsening, no new violation of previously legal bounds, normal bounds after
  correction, no zero-input recenter, fixed acquired attachment.
- `rig/rig_report.json`: **114/114**. Actual R shoulder at **155.199998°** with
  maximum **155°** commits **155.100018°** with a warning, then a fresh adapter
  commits **154.849650°** with the warning cleared. Actual weapon rotation
  **0.09998° / 0.25036°**; attachment and above-clavicle pose unchanged. Allocation
  **8.700 / 8.384 ms**. Fixture uses the documented contribution-policy override
  to isolate shoulder correction rather than let wrist motion satisfy the task;
  production joint priorities are unchanged.
- `held_status/manifest.json`: short isolated actual-weapon station run,
  **7/7 ACCEPTED** held/regrab/Pommel requests; authority/signatures preserved.
  Allocation average **23.610 ms**, maximum **27.881 ms**. A separate lightweight
  UI routing assertion shows and clears the actual rig warning without changing
  the bones or authority. The invalid-pose correction itself is imported-rig
  evidence; this is not a second end-to-end invalid-pose station reproduction.

R/F/Save and equipped playback were not rerun. Original player library SHA256
remains `839C5D18B28903F94D5A83B1F3349567D49D50807BD0621168D8CFB2C123A6DF`.
All owned engine runs ended; only editor PID 6032 remained. No Git operations.
Next: user manual retest of the pose that triggered the initial-state lockout.

## 2026-10-30 follow-up: wrist measurement is not wrist approval

User reproduced `weapon_motion_requires_legal_wrist_start (RECOVERY_REQUIRED)`.
This occurs before the corrected allocator allowance: `_build_arm` calls
`capture_wrist_constraint_state`, which returns no state for a cached wrist
failure or a failed bounded wrist fit. Requiring legal anatomy before measuring
the actual pose prevents the user from correcting it. The preceding fix did not
cover this separate preflight gate; do not claim that it did.

Authorized narrow correction: add read-only measurement through the existing
rho/beta/gamma wrist mechanism, reconstructing the actual current Hand frame
without clamping to ROM, changing calibration, changing the pose or adding a
new wrist DOF. Use it only to initialize/cross-check movement allocation.
Bounded `resolve` / accepted-state `compose` remain their existing contracts for
other consumers. Cached failure history must not veto measurement of the live
pose. Inherited excess then follows the already-added correction allowance.

Owners: `core/resolvers/combat_wrist_motion_resolver.gd`,
`runtime/player/player_humanoid_rig.gd`, and
`runtime/player/combat_weapon_motion_rig_adapter.gd`, with focused pure/rig tests.
User confirmed game closure for verification. No Git or original save writes.

Additional user question: audit other "must already be valid" gates. The initial
request was a read-only classification, followed by explicit direction below.

### Subsequent user direction and integrated correction

The user rejects Reset/discarding work to escape an existing collision or an
inverted elbow. They explicitly clarified that collision serves path solving and
literal no-go zones, not control-point usability.

- The adapter keeps measured negative elbow flexion instead of rejecting
  `weapon_motion_inverted_start_hinge`. Its starting scalar excess participates
  in the same partial-correction allowance; no automatic elbow flip or recenter.
- Attached Tip/Pommel/Roll no longer receive the presenter callback that vetoed
  control input for collision, hand clearance or the separate reach projection.
  Actual bone lengths/joint allocation and attachment remain authoritative.
  Existing collision/path evaluators are unchanged and remain available to path
  preparation/validation. This does not certify an intersecting skill for use.
- `finish_authoring_motion_attempt` accepts the allocator's already-validated
  current scene instead of applying a second strict validator to both wrists and
  undoing partial recovery. Scene/weapon/origin identity must still match the
  retained manipulator transaction. Other motion paths keep their existing check.

Remaining entry guards found in the attached control routes: missing/active grip
acquisition, missing or detached acquired binding, generated/baseline node edit
locks, active playback, missing checkpoint/changed object identity, and invalid
numeric data/calibration/hierarchy. These are distinct from anatomical-start
approval. Unarmed/noncombat/unsupported fallback paths were not rewritten.
Fresh verification: pure allocator 43/43, imported rig 175/175, real station
7/7 held/regrab/Pommel inputs accepted despite an inactive-wrist cached failure
and collision in all 144 sampled weapon points. Independent pose/path queries
still reported collision. Station allocation averaged 18.066 ms, max 21.744 ms.
Evidence: `godot_runs/weapon_motion_start_recovery_20261030/station_guards/manifest.json`.
Original player library unchanged. This evidence does not cover R/F/Save.

## 2026-10-30 user decision: quality validation is advisory

Current explicit scope supersedes older mechanical approval gates: anatomical
rules guide the body, but an imperfect pose must remain editable, recordable,
saveable and playable. Suggest improvements; do not invalidate the user's work.
Collision/path and anatomical checks may report affected nodes and spans. They
must not make R, F or Save unavailable merely because the pose is poor.

Implementation seam: capture actual finite local bone/weapon channels, retaining
measured wrist state even outside its range. An off-mechanism wrist orientation
is explicitly tagged instead of inventing semantic angles. Keep the existing
guided interpolation when it succeeds; when mechanical guidance fails, retain
the finite recorded-pose interpolation and its warning. Apply the same rule to
the 160 ms entry and the shared F/equipped pose writer. Preserve complete clip
publication with selected-draft disk saving; never save a cleared/missing clip
and call that playable. Malformed/nonfinite data and file-write failure remain
real errors, distinct from quality advice. No new grip search during playback.

Explicit R/F/Save can record the current pose before acquisition succeeds.
Background baseline preparation still waits for acquisition normally. A user's
explicit imperfect Node 1 capture does not replace Reset's default preset with
that imperfect pose. Context/origin IDs, source-generation checks and atomic
publication remain intact. Warnings persist on affected nodes after successful
preparation/cache reuse and clear when the relevant data is improved.

Owners: prepared pose model/capture, prepared track builder, runtime entry,
shared humanoid replay writer, station/equipped playback presenters, station UI
and endpoint-recording job. Focused R/F/Save/reload verification pending.

## 2026-11-04 audit and authorized completion

Read-only reconciliation after token exhaustion confirmed movement implementation
and its historical 43/43 policy, 175/175 rig and 7/7 station evidence. Fresh
parser check passed; prepared-track tests 68/68 and entry tests 419/419 passed.
Evidence: `godot_runs/weapon_motion_audit_20261104/`. These do not prove the full
station lifecycle. A disposable probe reproduced the warning collection type
error that the pure tests missed.

Authorized focused fixes: permit ordinary serialized/UI diagnostic Arrays in
the warning appender, separate advisory endcap flags from fatal playback flags,
and validate public pose channel cardinality before copying/truncation. Follow
with actual isolated R/F/Save/reload and equipped activation checks. Preserve the
original library and existing worktree. No Git operations authorized.

Fresh full-lifecycle attempt exposed a fourth integration defect: R's explicit
warning-tolerant recorder waited for two stable frames while the background
recorder rejected the same manual-facing warning and reset its settling key
every frame. The isolated test timed out after 40 seconds at Node 2; F/Save were
not reached. Background capture is now suppressed while explicit motion-node
recording owns that window, matching the existing F/Save ownership. Retest is
pending; this is not an increase to acquisition budgets or validation tolerance.

Completion evidence (fresh 2026-11-04):
- Prepared-track regression: 70/70. Parser checks passed.
- Isolated real-station lifecycle: 31/31. Normal and deliberately imperfect
  wrist/elbow/manual-facing nodes recorded through R; F, selected-skill Save,
  disk reload and all 50 recorded bone channels passed. This short three-node
  fixture prepared F in 1.476 s and saved in approximately 0.85 s; these are not
  general performance guarantees. The 160 ms entry/shared writer applied all
  34 sampled frames. Mismatched channel lengths and NaN input remained atomic
  data errors; finite endcap quality warnings applied, missing anchors failed.
- Actual equipped PlayerController activation passed: 60 Hz body and 160 ms
  entry, unchanged saved body channels, completed playback, zero new grip
  acquisitions. Equipped endcap warning/fatal separation also passed.
- Evidence: `godot_runs/skill_quality_warning_lifecycle_20261104_rerun/manifest.json`
  and `godot_runs/weapon_motion_audit_20261104/equipped_quality.json`.
  The combat-idle fixture was prepared separately through its own page, never
  bundled into skill Save. All test writes used isolated libraries.
- Original player library SHA256 remained
  `AF5853D73E4D4803111D1AF67B2EDFA3E9C92B0E3391E4F845465DF1EA92ECF1`.

## 2026-11-04 independent-arm motion boundary

User manual testing: positioning a free offhand against the already posed blade
can escalate into torso movement, carrying the prepared main arm and blade away.
For independent right-arm controls, the left Upperarm and its downstream arm
must retain position AND orientation in world space; apply the mirrored rule
for left-arm controls. This includes preserving the opposite hand and held
weapon, rather than freezing local channels while shared ancestors move them.

Clarified by the user: this applies to independent arm edits. Shared two-handed
weapon controls continue moving both gripping arms together. This is an editing
authority boundary, not a new playback constraint or an anatomy-profile change.
Trace shared ancestor writers and implement at the motion owner; do not stretch
bones or restore displaced limbs as a cosmetic after-pass. User will perform
the bulk of visual pose testing; add bounded mechanical checks for opposite-arm
invariance and active-arm motion. Implementation and evidence are recorded below.

Implemented in this pass:
- The weapon-motion rig adapter exposes torso channels only for shared
  two-handed Pommel/Roll. Single-hand Tip/Pommel/Roll preserves captured shared
  ancestors and the opposite arm; Tip retains its clavicle-inclusive boundary.
- Independent hand-proxy and elbow controls route through a selected-arm rig
  frame. Existing selected-side clavicle/arm/wrist mechanics run; the shared
  torso presenter, opposite arm, and finger acquisition do not run for that edit.
- Existing pose ownership retains the live result across held/released frames.
  Node signature, dominant/support roles, scene identity and coordinate frames
  delimit that ownership. Reset, navigation and shared operations release it;
  a rejected weapon request does not discard the previous independent pose.
- R/F/Save still use the ordinary full prepared-pose channels. No new replay
  constraint, alternate skeleton, bone stretch or world-space compensation.
- Files: `runtime/player/combat_weapon_motion_rig_adapter.gd`,
  `runtime/player/player_humanoid_rig.gd`,
  `runtime/combat/combat_animation_station_preview_presenter.gd`,
  `runtime/combat/combat_animation_station_ui.gd` (project-relative).

Fresh imported-rig verification: 212/212, including both sides, transformed
parents, untouched opposite-arm world transforms, no bone stretching and
shared two-hand movement. Evidence:
`godot_runs/weapon_motion_audit_20261104/independent_rig/rig_report.json`.
Final mirrored real-station integration: 24/24 (12 per R-main/L-main), including
free-hand numeric placement, actual elbow pointer drag/held/release, R recording,
prepared-node reselection, isolated Save and disk readback. Opposite arm/shared
ancestors and the untouched hand's weapon measured zero drift. Main-hand elbow
edits also preserved opposite/shared bones; their active weapon followed that
hand, with wrist-to-weapon positional residuals about 0.000000108 m (R) and
0.000000070 m (L). Evidence:
`godot_runs/skill_independent_arm_station_20261104_final/manifest.json`.
The source player library hash above remained unchanged; no Godot run remained
open at completion. Broad visual/anatomical acceptance remains the user's
manual testing, not a claim established by these bounded checks.

Test-contract clarification: the weapon must stay fixed when held by the
opposite, untouched arm. A weapon held by the actively edited arm may follow
that hand. A staged probe initially reported a failure because it mixed this
active weapon with frozen bones; separated measurements showed zero opposite
arm/shared-ancestor drift and retained hand-to-weapon contact. Do not add a
global weapon freeze based on that discarded test assumption.

Separate observation for later manual review: a 10-degree authored main-elbow
roll edit caused a much larger selected-arm pose change (maximum measured bone
orientation change approximately 100 degrees at UpperarmTwist01 in the R
fixture). That is a
world-pose comparison, not a measured 100-degree anatomical joint excursion.
It is outside this opposite-arm boundary pass; do not claim this pass resolves
all elbow sensitivity, anatomical quality or cold restored-grip cases.

## Deferred follow-up: positional undo and redo (2026-11-04)

Low priority, after the lifecycle completion and independent-arm boundary above;
may be implemented in a later session. The user requests Ctrl+Z / Ctrl+Y for
undoing and redoing positional changes within a motion node, so an unsuccessful
pose adjustment can be backed out quickly while prototyping. Preserve the
previously planned [SC-04 action Undo/Redo](Skill%20Crafter%20Action%20Undo%20Redo%20Plan%202026-10-26.md)
work rather than creating a competing system.
This addition is recorded scope, not an instruction to implement it in this pass.

## 2026-11-05 saved grip continuity

User reproduced `weapon_motion_acquired_grip_missing (RECOVERY_REQUIRED)` by
opening an existing skill and manipulating its existing nodes. The free offhand
remained editable; attached Tip/Pommel did not. Read-only tracing found prepared
pose restoration clears the live acquisition owner and its bindings, then
restores bones/weapon without reinstating editing ownership. The saved observed
Hand-in-Weapon transform is not itself the original acquisition packet.

Authorized fix: preserve the acquired relationship with the node and restore it
on reopening, including a fresh game process. Reuse the existing geometry,
anatomy and configuration signatures. No fake acceptance flag, relaxed motion
guard, or new anatomical rule. Missing/obsolete acquisition data may acquire once
at the node's configured handle position and record the replacement for the next
save. Routine refresh must not restart that work. Changed Forge geometry must
not inherit a stale acquisition. R/F/Save retain their advisory-pose policy.

The proposed RMB Solve / Solve All actions were workarounds and are held off by
the user. No timeline menu, Rename or Undo/Redo implementation in this pass.

Implementation owners: `preview_grip_acquisition.gd` exports compact value-only
packets and imports via existing binding validation; station preview presenter
captures those packets with endpoints, restores current scene ownership, and
retains it across unchanged redraws. Process IDs/WeakRefs/runtime checkpoints
are not written as durable grip data. Focused verification uses isolated saves
and separate write/read processes in `tools/verify_skill_grip_reopen.gd`.
Implementation now also distinguishes an exact saved authoring endpoint from
an interpolated playback frame. `player_humanoid_rig.gd` restores the recorded
parent-local channels without reframing already-solved arms, and restores the
endpoint's wrist continuation state. Full channel/type/finite validation stays
in place; ordinary runtime playback keeps its existing arm normalization.
The first cold test exposed a roughly 18-degree free-arm twist change caused by
using the interpolated-frame normalizer on a saved endpoint. That was corrected
at the restore boundary, without changing anatomy or tolerances.

`combat_animation_station_ui.gd` now returns to the selected authored endpoint
when F stops or finishes. Replay clears live editing ownership; this refresh
restores the saved grip before the next edit. Retained endpoint metadata uses
the existing preview-root render checkpoint so Save/F suspension preserves it.

An intentionally unacquired weapon-only facing edit remains manual: its saved
`weapon_facing_requires_manual_reacquisition` warning restores that intent,
instead of triggering the legacy-data fallback. Ordinary missing acquisition
data acquires once per visited node, captures the result, and persists it on
the user's Save. A failed acquisition is retained through redraws rather than
automatically restarted. No full-contact certification is fabricated.

Fresh verification (2026-11-05; original player library hashes unchanged):

- Final right-hand pass on the completed code: 42/42. Cold reopen, alternating
  node selection and Tip/Pommel edits; stale context/station/incomplete/typed
  malformed packet rejection; F stop and natural completion followed by
  immediate editing; Save then edit; intentional weapon-facing warning retained
  through navigation, followed by the actual manual Reacquire button. Zero
  automatic acquisitions; one expected explicit acquisition in the final manual
  facing step. `godot_runs/grip_reopen_final_R_fixed_20261105/manifest.json`.
  Natural completion required invalidating old manipulation ownership on replay
  entry: a matching final weapon transform did not mean its released grip was
  still live. No motion guard was removed to pass this check.

- Real right-hand Save produced two durable acquisition packets. A separate
  process reopened them, navigated N02 -> N01 -> N02, edited Tip/Pommel and
  rejected changed context/station/incomplete packets: 23/23, zero acquisitions.
  `godot_runs/grip_reopen_read_R_exact_20261105/manifest.json`.
- Left-hand Save/read in separate processes, including F-stop-edit and
  Save-edit: 31/31, zero acquisitions on reopen.
  `godot_runs/grip_reopen_read_L_playback_20261105/manifest.json`.
- Legacy fixture removes only acquisition provenance from an isolated saved
  skill. Normal selection recovered both nodes once (two total acquisitions),
  preserved authored control values and saved the replacement packets: 22/22.
  `godot_runs/grip_reopen_legacy_all_R_20261105/manifest.json`.
  A new process then passed 31/31 with zero acquisitions:
  `godot_runs/grip_reopen_recovered_R_20261105/manifest.json`.
  Legacy reacquisition changed some finger angles; this is measured recovery,
  not a claim that obsolete data can reproduce a missing solve exactly.
- Prepared-track regression: 70/70,
  `godot_runs/grip_reopen_track_regression_20261105/report.json` (synthetic
  track/model checks, distinct from rendered station runs).

Honest boundary: two-hand setup on this reset Broken_Balde_v1 fixture failed
before saving with `support_seat_outside_arm_reach`, both with the test's 0.2
support station and with native automatic placement. The failure is recorded in
`godot_runs/grip_reopen_write_dual_20261105/manifest.json` and
`godot_runs/grip_reopen_write_dual_default_20261105/manifest.json`.
Do not describe this as two-hand persistence verified or alter reach to make a
persistence test pass. Actual Forge editing -> regenerated handle -> reacquire
was not exercised; current geometry/content-signature ownership was inspected
and stale-context/station rejection was tested. Equipped gameplay was not rerun.

Godot workflow reference: exported Resource data and ResourceSaver in the
[Godot 4.7 Resource documentation](https://docs.godotengine.org/en/4.7/classes/class_resource.html)
and [ResourceSaver documentation](https://docs.godotengine.org/en/4.7/classes/class_resourcesaver.html).
Cold-read proofs use separate processes and ignore the resource cache.
Original library SHA256 remained
`af5853d73e4d4803111d1af67b2edfa3e9c92b0e3391e4f845465df1ea92ecf1`.
No Git staging, commit, push or user-library replacement was performed. All
diagnostic game processes exited; the user's existing Godot editor stayed open.

## 2026-11-05 acquisition entrance alignment

User testing found both automatic recovery and manual Reacquire close around an
incorrect starting weapon orientation. Current acquisition deliberately fixes
weapon rotation and axial station while fitting transverse seating and fingers;
it assumes the macro alignment is already correct. Durable restore fixed missing
ownership, not that assumption. No decision withdrawing Index-Pinky parallelism
was found. Independent-arm editing restrictions are unrelated: primary acquisition
keeps the hand/wrist and upstream body fixed and moves the joining weapon.

Authorized narrow correction: prepare the resolved Handle-% station and parallel
alignment together at the primary acquisition entrance, before numerical capture.
Use the existing station mapping, normal/reverse polarity and anatomical grip
reference. Transport chosen axial facing by minimum swing and preserve scale;
do not reset facing with a new look-at orientation. Support joins only after the
primary commits. Intact saved bindings restore exactly without running this step.
Keep the surface/finger solver, material caps, iterations and acceptance unchanged.
Tests must distinguish preparation geometry from successful finger acquisition.

Implemented owners: `core/resolvers/primary_grip_seat_resolver.gd` for value-only
alignment; `runtime/player/grip/preview_grip_acquisition.gd` for named-frame
capture and main-thread weapon application before the existing private worker.
All frames resolve through RL_BoneRoot. The reference uses the named wrist and
Index1/Pinky1 bones, the existing anatomical grip offset, and the selected weapon
station. Signed alignment distinguishes normal/reverse; minimum swing transports
the existing facing and scale. Exact half-turns use the hand's transverse
reference rather than an arbitrary world axis. Support acquisition is unchanged.

Focused station tests also exposed a second entrance problem: primary-% refresh
reran the full-body macro after station reseating, moving the wrist about 3-4 cm.
`combat_animation_station_preview_presenter.gd::retain_primary_station_edit_pose`
now retains the current authoring pose for that station edit and invalidates stale
manipulator continuation. The primary-% setter in `combat_animation_station_ui.gd`
uses this retained pose instead of requesting the redundant macro refresh.
General node/context ownership checks and deliberate weapon-facing suspension
remain intact. No finger/contact algorithm, cap, budget or acceptance change.

Godot 4.7 references: [Quaternion](https://docs.godotengine.org/en/4.7/classes/class_quaternion.html)
and [Transform3D](https://docs.godotengine.org/en/4.7/classes/class_transform3d.html).

Fresh final evidence, all under `C:/WORKSPACE/godot_runs/`:

- `grip_alignment_pure_20261105/report.json`: **93/93** value-only checks via
  `tools/verify_primary_grip_alignment.gd`. Signed normal/reverse, mirrored hand,
  span polarity, eccentric station, transported facing, scale, deterministic
  half-turn, idempotence and invalid-reference rejection. This is preparation
  geometry evidence, not a finger-contact certificate.
- `grip_alignment_entry_RL_retained_20261105/manifest.json`: **52/52** real station
  checks via `tools/verify_grip_alignment_entry.gd`, 26 per primary hand.
  Deliberate 25-degree tilt and 6 cm axial displacement, manual Reacquire,
  normal/reverse, actual primary-% edits and Save. Body and both wrist references
  remained fixed during tested acquisition/station edits; selected alignment,
  station and scale checks passed.
- `grip_alignment_cold_reuse_20261105/manifest.json`: **31/31**, separate-process
  intact saved-pose restoration, node navigation, Tip/Pommel editing, F stop and
  natural finish, Save/edit. **Zero acquisitions** for this intact saved fixture.
- `grip_alignment_legacy_recovery_20261105/manifest.json`: **22/22**, two missing
  acquisition packets recovered once each, retained through redraw/navigation,
  and saved. Missing-provenance recovery may change weapon/finger seating; it is
  not the exact restoration promised for intact durable packets.
- Scoped production `git diff --check` passed. Earlier failed diagnostic runs
  remain on disk; they exposed a test bone-name classification error (`Mid`, not
  `Middle`) and the real station-refresh body movement. They are not final passes.

Boundaries: no actual Forge geometry rebuild/reopen cycle or equipped gameplay
was tested here. Two-handed acquisition/persistence was not rerun; the earlier
support fixture could not reach its target. No blanket anatomical or full-hand
contact certification is implied. Generated mixed normal/reverse fixtures still
saved in roughly 22 seconds with six pose warnings: this is a correctness pass,
not a performance improvement. SC-14 cold opening optimisation remains deferred.

Manual next step: on an affected old node use Reacquire, inspect the weapon's
alignment, then Save. Intact saved bindings deliberately skip reacquisition;
their old pose is not silently rewritten just because this preparation changed.
Original source library SHA256 remained
`af5853d73e4d4803111d1af67b2edfa3e9c92b0e3391e4f845465df1ea92ecf1`.
Only isolated test libraries were saved. Diagnostic games exited; editor PID
11104 remains. No Git index/history/branch changes were performed.

## 2026-11-05 reacquisition must update motion-node trajectories

User testing found corrected weapon alignment/seating was not reflected in the
existing trajectory. Current code captures new prepared poses for existing nodes
but writes the seated Tip/Pommel/orientation fields only during baseline setup.
Selection-only refresh does not rebuild curves; a cached resolved visual
signature can also mask changed node coordinates.

Requested outcome: after a fresh primary acquisition moves the weapon, record its
realized endpoints and orientation into that node, then rebuild the guide/path
from the corrected chain. Keep timing, explicit curve offsets and other nodes'
positions. Automatic tangents may change with neighbouring endpoint positions.
No manual nudge, new finger solve, full-body macro pass or automatic disk save.
Intact restoration/navigation/playback must not be treated as new acquisition.

Owners: `preview_grip_acquisition.gd` supplies a one-use live-acquisition receipt;
the station UI consumes it at the existing settled pose capture, signs matching
node data and dirties the prepared clip; the preview presenter rebuilds only
trajectory visuals and retains the recorded grip. Implemented on 2026-11-05.
Godot 4.7 references: [Object signals and calls](https://docs.godotengine.org/en/4.7/classes/class_object.html)
and [Resource change notifications](https://docs.godotengine.org/en/4.7/classes/class_resource.html).

The receipt is issued only by a successful asynchronous primary acquisition,
excluded from replay-cache status copies and absent from durable restoration.
It participates in the capture settling key, so a prior explicit R/F/Save of a
finite unfinished pose cannot suppress the later completed writeback. Existing
nodes update their own endpoints; the hidden Reset baseline is touched only by
its existing baseline-initialization branch. No contact algorithm or joint rule
was changed.

`refresh_recorded_grip_trajectory` retains the newly signed pose, synchronizes
resolved display endpoints/orientation, removes stale trajectory signatures and
uses the existing visual-only curve rebuild. There is no full-body refresh or
new acquisition in that refresh. Timing and explicit curve offsets remain as
authored; neighbours' automatic tangents follow the updated chain normally.

Fresh verification:

- `godot_runs/grip_trajectory_writeback_R_20261105/manifest.json`: **33/33**.
  New `tools/verify_grip_trajectory_writeback.gd` creates three nodes through
  real UI controls, injects stale path coordinates only on the existing middle
  node, and triggers actual Reacquire. Stored and displayed endpoints match the
  realized weapon (measured maximum difference 0 m in this fixture); actual guide
  mesh/signature and adjacent automatic tangent change without a pointer nudge.
  Body/wrists, neighbouring endpoint poses, timing and custom offsets stay fixed.
  Exactly one acquisition performs that correction. Repeated refresh, F and Save
  reuse it; the corrected node and durable grip are present on disk.
- `godot_runs/grip_trajectory_cold_R_20261105/manifest.json`: **31/31**, separate
  process reopening that saved fixture, exact saved endpoint, navigation, edits,
  F stop/natural completion, Save/edit; **zero new acquisitions**.
- Godot script checks completed without errors; scoped production diff-check
  passed. Original source library checksums remained unchanged in both runs.

Boundary: this tests stale trajectory data with the real acquisition and station
pipeline, not a complete Forge geometry rebuild or a new two-hand matrix. Earlier
left/right alignment tests remain historical evidence, not reruns in this slice.
User's next check: reacquire an affected existing node and observe that its guide
updates immediately, then Save. Already saved old mismatches are corrected on
the next acquisition, not silently rewritten during intact cold restoration.

## 2026-11-05 user feedback: uneven editing fluidity

User reports free-offhand and Tip controls as buttery smooth, with main-hand
elbow and Pommel controls feeling like FPS loss. The report explicitly predates
the latest cube-release automatic-acquisition change. No fresh frame-time or
input-latency measurements establish the cause. Track under Project TODO
PERF-01, separately from SC-14 cold opening. Current request is a Git savepoint
while the user tests; no performance tuning or new runtime run is authorized by
this feedback alone.
