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

### Follow-up: abrupt movement sharing versus update cadence

User suspects the uneven feel occurs when movement transfers between joints at
their limits, and requests smoother entry/exit rather than assuming FPS loss.
Read-only code review supports investigating that distinction, not a confirmed
cause or a completed fix:

- `combat_weapon_motion_allocator.gd::_fit` and `_hold_order` use strict ordered
  movement preferences. All included joints remain available for necessary
  compensation; there is no literal next-bone unlock switch. Hard active limits
  can change how movement is distributed, and there is no soft near-limit
  recruitment curve. Boundary searches can also cost more computation.
- Main-elbow editing uses `apply_independent_arm_edit` and the rig's direct-arm
  reach/CCD, spline preference, manual elbow guidance and constraint passes,
  not the weapon allocator. An allocator-only curve cannot establish an elbow fix.
- The station's queued drag-refresh path has a 16-83 ms cooldown derived from
  half the previous synchronous refresh cost. The cooldown starts after that
  solve completes. Uneven pose-update cadence can coexist with changes in
  motion response; renderer FPS alone would not distinguish them.

Candidate direction: smoothly redistribute motion approaching and leaving a
limit while preserving actual anatomical limits, acquired contact and independent
opposite-arm isolation. Transition width/shape and effects on strict priorities
need a bounded implementation decision and measurement. No runtime changes,
new tests or confirmed performance result in this follow-up; user testing remains
in progress. Relevant owners: allocator `_fit`/`_hold_order`, station
`_get_preview_drag_refresh_interval_msec`, and rig
`_apply_authoring_direct_arm_reach_pose`.

### User clarification: pointer-to-pose stalls

The latest manual observation refines the earlier description of Tip as smooth:
some Tip movements are perfectly smooth, while movements requiring more arm,
upper-arm and elbow participation become jittery or appear briefly frozen.
The mouse pointer continues moving while the manipulated pose stays stationary
for a moment. This loses placement precision and makes the control feel stuck.
It does not by itself identify renderer FPS, solve cost, input scheduling or
abrupt joint recruitment as the cause.

Acceptance must therefore address continuous, predictable mouse-to-pose response
across these transitions, not only a visually smoother joint-sharing curve.
Measure pointer target, accepted pose, solve duration and update gaps together
on the same drag. Preserve the latest intended target through delayed work;
avoid replaying a backlog or silently discarding pointer travel. Presentation
easing alone cannot establish that input responsiveness is fixed. No runtime
changes made while the user continues testing.

## 2026-11-05 temporary arm/spine isolation experiment

User authorized a reversible diagnostic change: arm-control movement must stop
at each clavicle's attachment to the spine. Both clavicles and arm chains remain
available; the current spine/core pose must not translate or rotate in response
to arm manipulation. This tests whether shared-body involvement contributes to
the uneven control response. It is not a permanent anatomy or smoothing change.

Implemented a single exported rig flag,
`authoring_arm_spine_isolation_enabled = true`. Its query method also requires
`authoring_preview_mode_enabled`, keeping the experiment scoped to Skill Crafter
authoring. Set the flag to `false` to restore the earlier behavior. No settings
menu or saved skill field was added.

- `player_humanoid_rig.gd` supplies the active isolation setting to the existing
  upper-body posing pass.
- `player_rig_upper_body_pose_presenter.gd` skips the Waist/Spine01/Spine02 group
  while isolated, retaining their current transforms rather than resetting them.
  Clavicle posing still runs normally against those unchanged parent frames.
- `combat_weapon_motion_rig_adapter.gd` omits torso degrees of freedom even for
  two-hand Pommel/Roll while isolated. Single-hand allocation and independent
  elbow/free-hand edits already stop at the clavicle.

Reset/node restoration and playback can still apply their authored body poses;
the switch stops new arm edits from recruiting shared ancestors. Existing joint
limits, contact ownership, pointer scheduling and solver budgets are unchanged.
Ordinary R/F/Save still record/use the resulting pose. No disk migration, saved
skill rewrite or Git operation is part of this experiment.

Godot 4.7 [Skeleton3D pose and hierarchy documentation](https://docs.godotengine.org/en/4.7/classes/class_skeleton3d.html)
was consulted. Preserve parent-relative bone poses and the existing origin chain;
do not detach/reparent bones or freeze a second skeleton in world space.

Fresh focused verification:

- `tools/verify_authoring_arm_spine_isolation.gd` extends the existing imported-rig
  harness without running its broader boundary-search matrix.
- `godot_runs/arm_spine_isolation_20261105/arm_spine_isolation_report.json`:
  **132/132 passed**, Godot 4.7 headless exit 0. Nondefault shared ancestors stay
  fixed under one/two-hand macro inputs on both sides while clavicles respond;
  disabling the flag restores torso contribution. Outside preview the flag is
  inactive and the macro retains its former behavior.
- Allocator parameter checks cover both sides, one/two hands and Tip/Pommel/Roll,
  with the switch on/off. Small actual one-hand movements retain attachment and
  fixed core/opposite arm; independent-arm checks also pass.
- Scoped diff-check passed. No player-library writes or saved skill changes.

Boundaries: imported real skeleton with a synthetic rigid prop; this is not a
fresh saved-weapon grip test, a two-hand movement matrix, full F/Save/equipped
certification or a pointer-latency measurement. Manual control feel remains the
user's test. Source changes and this experiment are uncommitted; the pushed
baseline remains `29876da3`.

## 2026-11-05 continuous pointer-speed diagnostic

User manual follow-up: slow movement feels smooth; normal and faster movement
become jittery or briefly frozen. The spine-isolation experiment did not remove
the symptom, so shared-core propagation is no longer the leading explanation.
The user explicitly requires continuous flow along an irregular mouse path;
quick arrival at an endpoint after a pause/jump is not successful responsiveness.

Read-only code findings:

- The station holds one pending target, not one queued solver job per mouse
  event. Tip updates the candidate and Pommel overwrites its requested position.
- Larger changes can require multiple allocator substeps and repeated fitting
  searches. This runs synchronously. The editor then waits a further 16-83 ms
  based on half the previous refresh cost before its next queued pose update.
- `_apply_pending_endpoint_motion_attempt` rebases the pointer to the accepted
  pose even for a valid SCALED result. Remaining demand is discarded. That avoids
  boundary wind-up, but does not distinguish exhausted numerical search from an
  established anatomical boundary. A faster implementation alone would not
  correct that input-consumption rule.

Fresh bounded rendered diagnostic, no production changes in this pass:
`tools/diagnose_skill_pointer_speed.gd`, extending the existing isolated-library
station harness. Report: `godot_runs/skill_pointer_speed_20261105/manifest.json`.
Same acquired Reset body/weapon pose and camera restored before each trial;
reported baseline pose differences were zero. Right-main single-hand
`Broken_Balde_v1`, isolated Skill 2, spine isolation enabled. Actual station
Tip press/motion/release handlers receive a nominal 120 Hz, wall-clock-driven
irregular six-vertex path at constant arclength speed. If the engine stalls,
only the latest pointer position is delivered, not a backlog. This is synthetic
input through the real UI path, not an OS input-to-display latency measurement.

| Intended time for the same ~150 px path | Pose updates | Largest scene-update gap | Largest Tip movement between sampled frames |
| --- | ---: | ---: | ---: |
| Slow: 6 s | 158 | 32.527 ms | 2.170 px |
| Normal: 1.5 s | 27 | 337.518 ms | 36.223 px |
| Fast: 0.45 s | 9 | 59.215 ms | 22.593 px |

The worst normal-speed update took 335 ms, of which allocation took 324.347 ms.
It performed 54 fitting iterations, 764 kinematic evaluations (78.074 ms), and
202 candidate validations (128.961 ms). Those validations include 201 storage
checks (127.909 ms); do not add the nested storage time again. The result was
SCALED to 0.7109375 with `allocator_search_exhausted`; reported active limits
were empty, and contributing joint groups were elbow and wrist. This is numerical
search exhaustion, not a demonstrated hard anatomical stop. Slow had 158 ACCEPTED
results; normal had 26 ACCEPTED and one SCALED; fast had nine ACCEPTED. Delivered
input handlers themselves peaked below 2.4 ms in these trials.

The result supports real synchronous calculation stalls plus sparse pose updates,
not just a cosmetic handoff discontinuity. It is not monotonically worse with
speed: the normal-speed sample hit the particularly expensive search branch,
while fast took fewer, larger accepted steps. All three gestures completed, but
completion is not a performance pass. Raw frame/pointer/solver samples are kept
in the report. Source library hashes remained unchanged; no skill Save occurred.
The diagnostic exited 0 and the editor was left open.

Next focused work, not implemented: separate numerical-budget partial progress
from genuine boundary saturation, preserve appropriate pending pointer demand,
and control expensive solving without adding scene freezes or a growing input
backlog. Native C++ may help measured math, but is not a substitute for correct
input ownership/scheduling. Do not change anatomy/grip acceptance or claim this
single fixture proves every elbow/Pommel case. Isolation remains enabled pending
the user's decision; the diagnostic made no production changes.

## 2026-11-05 marker capture, precise picking and input speed tuning

User chose a narrower experiment before parallelizing the solver: throttle
incoming marker movement. During scene-marker LMB dragging, capture/hide the
ordinary cursor and use relative motion so window edges do not end the gesture.
Release restores the pointer at the actual marker. Only scene controls qualify;
the duration slider, new speed slider, arrows, text inputs and menus retain the
visible ordinary pointer. Improve sphere/cube selection against visible markers,
including curve cubes, weapon-facing cube and arm/free-hand controls.

Add a temporary left-side control matching the duration slider's visual style.
One shared input limit for all scene-marker types, adjustable live, numerical
readout in screen pixels per second; initial range 10-20000, step 10, default
180. Continuous nonlinear slider gives low-speed precision; arrows hold-repeat
as the duration widget. This regulates editing input, not saved node timing or
playback speed. Do not bank excess pointer movement or stalled-frame time for a
later catch-up jump. Keep existing constraints and spine-isolation experiment.

Scope owners: combat_animation_station_ui.gd (capture/lifecycle/routing),
combat_animation_motion_node_editor.gd and station_preview_presenter (picking),
new combat_marker_drag_input.gd (bounded input), new combat_drag_speed_control.gd
(temporary UI). Undo/Redo remains a separate deferred item. No native port or
solver rewrite in this pass. Verification/results to follow implementation;
the existence of a speed valve is not proof that all solver stalls are fixed.

### Implementation and focused evidence

The three input changes are implemented. Only a successful scene-marker pick
captures/hides the pointer; captured relative screen movement drives the existing
manipulator. Release returns the ordinary pointer to the rendered marker.
Escape, focus navigation, window focus loss, editor closure and tree exit release
capture too. Duration and speed controls retain ordinary visible-pointer input.
Selection now intersects the visible sphere/box meshes, choosing the nearest
surface among active controls rather than a 20/34-pixel circular pick halo.

The new left-side Drag speed (px/s) widget uses a continuous logarithmic track,
10-pixel/s increments, 200 ms initial arrow-repeat delay and 50 ms repeats. Its
10-20000 range and default 180 are experimental tuning values. It remains shared
by all scene controls for this editor instance; it is not saved into skill data
or persisted across game restarts. The right-side node-duration control remains
independent. UI and helper explicitly describe this as an input maximum: elapsed
time per accepted input sample is capped at 1/60 second, so solver stalls/idle time
cannot bank a large subsequent jump. At a slower update cadence the effective
speed can be below the displayed ceiling. Excess relative motion is discarded,
not replayed later. Existing anatomy, acquisition, F/Save and scheduling rules
were not rewritten; temporary spine isolation is still enabled.

Fresh Godot 4.7 checks under godot_runs/marker_drag_precision_20261105:
- verify_combat_marker_picking.gd: final 55/55 passed, picking_final.json/log,
  exit 0. Sphere/box hit surfaces, overlap/front-surface priority, parent transforms,
  hidden/queued/decorative exclusions and all control mappings. Final 17 cases
  cover same-frame repeated focus/selection refresh plus frame-boundary survival
  and replacement of lightweight markers. Marker roots now detach old visuals
  before deferred deletion; selection-only refresh rebuilds active non-endpoint
  gizmos. This last focused fix followed the rendered station3 run and was
  verified by these regressions, without repeating the entire station fixture.
- verify_combat_marker_drag_input.gd: 41/41 passed, input/results.json; bounded
  diagonal movement, reversal, no stored excess/idle budget, widget mapping,
  numerical entry, arrow repeat and focus/hide handling. The deliberate numeric
  overflow case emits Godot's "Exponent too high" warning and is rejected.
- verify_skill_marker_drag.gd: rendered station3/manifest.json, exit 0, 55/55
  checks. Isolated Broken_Balde_v1 / Skill 2 / right-main single hand; original
  library hash unchanged, no skill Save. Marker press/release and overlay arrows
  dispatch through Input.parse_input_event and Control hit testing; motion uses
  synthetic relative events. Tip, Pommel, arm roll, free hand, wrist roll and
  weapon-facing cube exercised, including focus-loss and Space-release cleanup.
  The run does not measure physical OS input-to-display latency or certify the
  user's manual feel. Final screenshot: station3/editor_controls.png.
- Same ~150 px requested irregular Tip route at slow/normal/fast input durations:
  largest sampled update gaps 35.805 / 31.871 / 31.549 ms; largest actual Tip
  frame steps 1.897 / 3.034 / 3.166 px. These are bounded-input fixture results,
  not identical endpoint travel or a general solver-speed guarantee. Release
  finalization still took 805-885 ms; this pass did not optimize that separate
  recording/refresh cost. F/Save/equipped playback were not rerun.

Earlier station and station2 runs are retained as failed verifier setup evidence:
the fixture used selection-only refresh where full focus gizmo rebuilding was
needed, and performed redundant same-frame refreshes. Station2 measured zero
distance between its reconstructed endpoint and actual marker, so the initially
suspected endpoint-position mismatch was not established. Investigation exposed
real marker lifecycle hazards as well: queued visuals still occupied fixed node
names, and selection-only refresh removed non-endpoint gizmos. Those receive
focused lifecycle coverage with the precise picker; no geometry/solver change.

Next: user tunes the shared input limit during ordinary editing and reports the
number plus which control/pose behaves poorly. Do not treat a low ceiling as proof
of a complete performance fix. Leave native porting, parallel solvers, retained
target pursuit, Undo/Redo and restoration of spine propagation for separate
decisions. Do not silently restore spine propagation while comparing this pass.

## 2026-11-05 saved Skill 3 circle/roll investigation

User supplied `Broken_Balde_v1`, Skill Slot 3. Rendered observation with captured
input at 900 px/s, F followed by repeated five-circle / three-second blue Tip
curve-handle gestures on visible node 3. User clarified original manual test
was node 2 and accepted blue-only use on the last node. Two runs; source library
hash unchanged, no Reset/Save, no production solver/anatomy edits.

Detailed evidence, exact source routes, limits and proposed narrow next changes:
[Skill Crafter Curve Editing Roll Audit 2026-11-05](<Skill Crafter Curve Editing Roll Audit 2026-11-05.md>).

Confirmed: curve-only editing runs full body/weapon posing, changes the displayed
endpoint pose, then a later curve drag can commit that drift into authored Tip
and Pommel positions. First run2 gesture moved actual Tip ~197 mm despite unchanged
stored endpoints; second moved it ~524 mm and copied the preceding ~197 mm drift
into the stored endpoint. Forearm roll moved from 69.74 to 89.94 degrees.

Matched-baseline Tip CW/CCW both moved, with near-limit forearm states but no
recorded allocator search exhaustion or reduced task_scale. Both release paths
reported wrist_motion_range / APPROXIMATE. Read-only code trace found control
identity cleared before the final pending Tip attempt, causing fallback through
generic posing/strict validation and rollback. Do not treat retained ACCEPTED
allocator metadata and the release error as a single allocator result.

Next proposed discussion: isolate curve-field editing from endpoint posing and
retain control identity through final drag commit. Neither correction is yet
implemented or authorised by this audit. F completed (1.694/1.772 s preparation);
sparse screenshot-spaced bone samples cannot certify frame-to-frame smoothness.
Evidence: godot_runs/skill3_curve_roll_20261105/run1 and run2. Temporary spine
isolation remains enabled. Preserve the user's original Skill 3 and dirty tree.

## 2026-11-05 authorized curve-pose and release corrections

Supersedes the proposed/not-authorized status in the preceding audit entry:
the user requested implementation, plus Body Support default 0.9 instead of 0.4,
while explicitly preserving Skill 3's existing 1.0 values for comparison.

Implemented in the station UI: curve-only drags and numeric edits update visuals
and trajectory cache state without reposing the body or weapon; release commits
only the edited curve field. Drag control identity now survives until the final
pending movement is evaluated, so Tip release uses Tip allocation rather than
falling through generic posing/strict wrist validation. Geometry seed default
is now 0.9; saved nodes, cached baselines and unarmed seed are unchanged.

Focused rendered Godot 4.7 verification, `godot_runs/curve_pose_fix_20261105/run3`:
31/31 checks, exit 0. Repeated node-3 blue-cube circles, node-2 outgoing Tip and
incoming Pommel circles, all four numeric curve fields: zero measured live
bone/weapon pose change; stored non-curve fields unchanged throughout input.
F rebuilt the changed path (1.527 seconds preparation) and completed. Both Tip
release routes retained their allocation result. Original saved library hash
unchanged; Skill 3 visible Body Support values all remain 1.0. No Reset/Save.

Residual Tip-limit/search stalls remain: the clean baseline still produced
reduced movement and a SEARCH_EXHAUSTED sample, with instrumented update gaps
up to 674 ms. Neither search optimization nor general anatomical changes belong
to this correction. Temporary spine isolation remains on; no Git action.
Final code/evidence and verifier corrections are detailed in
[Skill Crafter Curve Editing Roll Audit 2026-11-05](<Skill Crafter Curve Editing Roll Audit 2026-11-05.md>).

## 2026-11-05 timeline visibility correction

User reported the motion-node list disappearing while the preview gained space.
Confirmed layout fault: UI created SubViewportContainer with stretch=true, but
presenter `_ensure_preview_nodes` forced false and `_sync_preview_size` copied
the displayed size back to the viewport. That size became a minimum-size floor.
After enlarging then shrinking the window, the preview could not shrink and
pushed the timeline outside the clipped station panel.

Narrow fix in `combat_animation_station_preview_presenter.gd`: keep stretch=true
and skip manual viewport-size assignment while the container owns resizing.
Existing 3:1 preview/timeline allocation and list/button behavior are unchanged.
Engine reference: [Godot 4.7 SubViewportContainer](https://docs.godotengine.org/en/4.7/classes/class_subviewportcontainer.html).

Fresh rendered layout-only reproduction, no weapon/skill changes:
`godot_runs/timeline_layout_20261105/inspect_layout.gd`, before.log and after.log,
plus screenshots. Actual station UI at 1280x720, 1920x1080, 2560x1440, then back
to 1280x720. Before correction the last timeline rectangle began at y=1084 with
height zero; after correction it returned to y=544 with height 90 and visible
action buttons. Both runs exited normally; final screenshots inspected and
scoped diff whitespace check passed. No full skill or grip regression run for
this layout-only fix. No Git operations.

## 2026-11-05 directional Tip stall diagnosis

User supplied an exact Skill 3 / node 3 screenshot and right-left-right
reproduction, later describing an advancing clock-face stopping point.
Read-only source tests reproduced severe directional resistance and a shifted
practical stopping point. The same captured rightward request is legal: keeping
all limits and grip checks, removing only the forearm-hold preference in an
uncommitted diagnostic solves 100% in 17 evaluations versus 7.8125% in 1,422
evaluations under production policy. The strict preference drives large opposing
elbow/wrist corrections through a nearly singular configuration. Increasing the
iteration budget alone requires 5,690 evaluations and still scales the request.

This is diagnosis, not a production fix. Some reverse increments succeeded;
do not claim a universal one-way lock or a finished remedy. Original library
unchanged; current spine isolation and Body Support values retained. No Git.
Detailed evidence, reproduction limits and next focused decision:
[Skill Crafter Directional Tip Stall Audit 2026-11-05](<Skill Crafter Directional Tip Stall Audit 2026-11-05.md>).

## 2026-11-06 shoulder and forearm profile implementation in progress

User authorized adapting `Reserch/Shoulder and Forearm Rotation Limits for Josie.md`.
Preserve established names, bone-local ownership and explicit ancestry through
RL_BoneRoot. The same stored pose/calibration must serve SC, F and equipped use.
Scope: stable chest-relative humeral rotation; elbow-dependent forearm limits;
useful distal/axial motion allocation; recorded anatomical state and focused tests.
No grip algorithm rewrite, new wrist DOF, world-locked Tip pivot, collision-based
editing lockout, spine-isolation change, or source weapon/Skill 3 mutation.

The live elbow span is 12–160 degrees flexion. Preserve it; map the proposed
full-flexion forearm sample to the configured full bend. The paper's forearm
table is proposed rig tuning, not universal clinical bounds. Keep stored rho's
geometric convention and record the thumb-up anatomical offset/sign explicitly.
Absent separate validated clavicle limits, the document specifies holding its
accepted local pose during allocation, while measuring composed shoulder turn
relative to chest. Existing invalid poses remain measurable and correctable.

USER DECISION: restrict shoulder rotation to documented coverage for now.
The supplied shoulder-height sideways-to-forward interval is enforced against
the fixed chest reference. Outside that coverage, retain the accepted humeral
turn in a stable hold anchor; do not grant another turn allowance per mouse
event. Other permitted channels remain editable, including aiming back toward
documented coverage. This is deliberately limited coverage, not a completed
whole-sphere anatomical envelope. Never invent missing clinical endpoints.
The fixed-contact sword example is a
test fixture, not permission to reintroduce a world-space lock for ordinary Tip.
The combined test stops at the remaining feasible motion boundary, not necessarily
at the first joint limit when another permitted joint can contribute.

Implementation owners: existing wrist profile/calibration/resolver and prepared
pose/replay owners; new shoulder profile/calibration/resolver; motion rig adapter,
allocator and PlayerHumanoidRig glue. Tests/evidence will be appended after runs;
this entry is a plan and does not establish completion or test success. No Git
index/history changes authorized in this pass.

Fresh progress evidence (2026-11-06; final integration checks still in progress):

- Forearm profile and actual adapter coupling: 59/59 checks.
- Shoulder calibration, composition, range and root-frame checks: 74/74.
- Prepared-pose anatomy persistence/interpolation: 36/36, including explicit
  legacy helper-neutral recovery with unchanged structural guards, current-limit
  retention, stable hold serialization and the shared entry sampler.
- Imported-rig movement checks: 212/212; allocator policy: 43/43.
- Origin registry: all 17 registered origins resolve correctly through
  RL_BoneRoot.
- Rendered real Skill 3 right-left-right Tip gesture: all 36 samples accepted at
  full task scale; allocation approximately 13.6-19 ms per sample. The new
  profile caused one opening acquisition and changed the starting pose, so this
  is evidence of current reversal working, not an identical-pose speed ratio
  against the old stall run. Original player library unchanged. Screenshots
  inspected; no whole-hand or whole-ROM certification implied.

Evidence root: `godot_runs/shoulder_forearm_20261106`. Retain failed early runs
alongside final results; do not present them as current regressions or erase
their history. Current tests do not establish that every prior motion stall,
all unsupported shoulder directions or every authored weapon/skill are fixed.

Additional integration evidence and boundaries:

- Imported shoulder allocation verifier: 91/91 after correcting a declared
  fixture mismatch. Josie's authored pose translations differ from imported rest
  translations by about 46 micrometres right / 52 micrometres left. The controlled
  geometry fixture now explicitly uses rest translations; no production pose or
  tolerance was altered to make this test pass. Earlier failure is retained in
  `shoulder_allocation`; corrected result in `shoulder_allocation2`.
- Uncovered hold constraints use `SHOULDER_HOLD`, not anatomical recovery rows.
  Otherwise each fresh request could forgive a tiny positive residual and slowly
  move the stopping point. The shared anatomical recovery mechanism is unchanged.
- Real isolated SC UI: Reset/acquire, R, movement, Save, separate-process reopen,
  F/stop, F/finish and immediate further editing passed. Cold reopened newly
  recorded nodes needed zero acquisitions. `lifecycle_write` and `lifecycle_read`
  contain reports. These are two-node test skills in cloned libraries; the user's
  three-node Skill 3 and its Body Support 1.0 values were not overwritten.
- Equipped playback passed after combat idle was prepared through its own UI
  in the isolated library (`idle_fixture`, `equipped_ready.json`). It consumed
  the saved skill at 60 Hz, used 160 ms entry and retained all authored body
  channels unchanged. Earlier `equipped.json` stopped on the existing unprepared
  combat-idle data; preserve that failed setup result, not a false playback pass.
- Generic prepared-track tests: 70/70. Origin annotation and registry checks
  pass. Final imported-rig run: 212/212 (`rig_final`).

Remaining scope gaps, explicitly NOT complete:

1. Independent elbow/free-hand/upper-arm-roll editing still takes the legacy
   direct-arm solver route. Forearm/wrist checks are shared, but chest-relative
   shoulder enforcement and the clavicle hold are currently integrated into
   weapon Tip/Pommel/attached Roll allocation only. Capturing and warning about
   independent edits does not enforce their shoulder limits. Do not claim that
   every SC control now uses the new shoulder model. A future integration must
   validate complete candidates and accepted UI targets; post-clamping upperarm
   after solving can break hand contact and is not an acceptable shortcut.
2. Unsupported shoulder directions retain their accepted turn. A controlled
   R/L test starting outside coverage at h=100 degrees could not enter the
   forward h=40-degree destination, whose maximum is 41 degrees. It returned no
   progress / SEARCH_EXHAUSTED, not an invalid-start lock. This discontinuous
   coverage/re-entry case needs an explicit future rule or more calibration.
3. The user requested exaggerated real gestures, pushing past each apparent
   stopping point and reversing, after observing that the hand looked stationary.
   Small-drag input-pose data showed hand and weapon both rotating 6.64 degrees
   with wrist position nearly fixed and attachment drift below 0.001 mm. That is
   not final skin evidence. A separate final-skin, full-range test is pending.

### Large-motion observations and handover boundary (2026-11-06)

The first large rendered run is retained in `full_range`. It included physical
mouse movement by the user during injected gestures, confirmed in chat. Do NOT
attribute its largest jumps to the nominal 10-pixel injected requests. Of 557
visible intervals, 522 had the intended pointer delta; their largest Tip travel
was 10.49 pixels. The other 35 contained additional movement. The 131.69-pixel
Tip jump accompanied an actual pointer change of (+132.85, -75.25) pixels.
The run also contained a drain timeout; it is not a passed full-range test.

Final `Skeleton3D.skeleton_updated` observations showed the held hand and weapon
remaining attached: maximum relative variation about 0.000443 mm / 0.0000312
degrees. This distinguishes a nearly stationary wrist position from a hand
that fails to rotate with the weapon; no such detachment was demonstrated here.

A separate remaining input-mapping issue was identified in clean intervals.
Tip dragging raycasts onto a camera-facing plane, then normalizes the requested
direction around the grip. Near a horizontal projected weapon direction, a
horizontal pointer movement changes mostly radial distance, discarded by that
normalization. At one endpoint, a reverse 10-pixel input requested only 0.059
degrees, all accepted, and moved the Tip about 0.27 pixels. A fresh capture had
the same response. This is not proof of another anatomical one-way stop.
Owners: `combat_animation_motion_node_editor.gd::raycast_tip_on_view_drag_plane`
and `combat_animation_weapon_frame_solver.gd::orbit_tip_around_grip`.
Detailed evidence: `godot_runs/shoulder_forearm_20261106/input_mapping_findings.md`.
No production mapping change was made during this final diagnostic pass.

The user reported their OWN mouse movements during this test felt smoother than
the previous live build, and requested prompt handover for manual testing.
The remaining clean exaggerated limit run is deferred rather than presented as
passed. Test-only input filtering / circular-input delivery tools are separate
from the normal game; they do not disable or alter ordinary user mouse control.
No additional production changes or Git operations during this wrap-up.

### Research supplement received after handover (2026-11-06)

Read in full and compared: `Reserch/Shoulder and Forearm Rotation Limits for
Josie (1).md`. It adds the previously missing lowered/overhead/posterior guidance
and a provisional coverage policy. No code changes made from this supplement yet;
the user is testing the handed-over build.

- Complete lowered-arm reference pair: [-65.1, +66.9] degrees from one protocol,
  requiring a mapped neutral. Do not mix it with the old isolated -67 endpoint.
- Small local coverage gaps: proposed 15-degree donor search, fixed anatomical
  zero transport and offset correction, no chaining provisional donor rows.
- Distant regions: inspect a fixed Josie centre and candidate endpoints at
  10-degree authoring increments. This does not supply already inspected poses
  or automatically authorize a +/-10-degree anatomical interval.
- Overhead information still provides outward reference endpoints only; inward
  limits and forward-overhead samples need rig calibration. Posterior 14.8
  degrees is additional passive test travel, not an absolute signed endpoint.
- Requires persistent provisional provenance, consistent bounds across reload,
  and coordinated return into narrower intervals during region transitions.

The supplement proposes broader provisional coverage than the user's earlier
explicit decision to restrict shoulder rotation to documented coverage. Apply
that distinction deliberately in the next implementation discussion. It does
not itself fix independent-arm routing or camera-plane Tip input sensitivity.

### Manual feedback after checkpoint 4be15c15: sticky grab/release

User reports the mouse-to-marker interaction feels sticky, with noticeable delay
both on engagement and release. This is failed usability acceptance despite
earlier reports that some movement during the diagnostic felt smoother.

Read-only inspection: `_on_preview_gui_input` captures the pointer only after
the pick/setup path completes. That path builds a deep display-node copy and
creates override/accepted-node copies. Start cost has not been freshly measured.
On release, `_handle_captured_marker_input` flushes pending motion and calls
`_finalize_preview_drag`; that function completes synchronous commit/refresh
work before `_release_marker_pointer` restores normal mouse control. This can
make release visibly wait behind editing bookkeeping. Earlier marker tests
recorded 805-885 ms release/finalization, not a new measurement of this build.

Next narrow investigation: immediate engagement/release feedback and the work
currently blocking those boundaries. Merely hiding/unhiding the pointer earlier
will not cure a main-thread stall; preserve correct accepted-pose recording and
input ordering while separating nonessential work. No code or solver changes,
no engine run and no new Git push for this feedback note. Large implementations
remain suspended at the user's request.

### Focused drag-release correction (2026-11-06 02:05)

User estimated 300-500 ms at both engagement and release and explicitly asked
for responsive control. Authorized scope narrowed to these interaction boundaries.

Measured on the isolated original Broken_Balde_v1 Skill 3, node 3, cap 900:
stationary click then one 10-pixel Tip drag. Before: press 6.456 / 5.548 ms,
stationary release 4.063 ms, changed release 898.254 ms. After: press 5.485 /
5.786 ms, stationary release 3.480 ms, changed release 33.123 ms (~96% reduction).

Root cause corrected in `combat_animation_station_ui.gd::_finalize_preview_drag`:
captured release arrived through `_input` outside the existing scoped station
lookup. Commit/list/field/summary getters repeatedly normalized the entire
station. The outer synchronous finalization now shares one lookup scope. Keep
the explicit post-mutation ensure in `_stage_active_wip_edit`; live selected
node values remain live. No deferred stale commits, shared mutable pose-copy
shortcut, changed solver rules, or grip/arm limit changes were introduced.
Opt-in boundary timing is off by default and retained for focused diagnostics.

Evidence: `godot_runs/marker_lifecycle_20261106/before/manifest.json` and
`after_scope/manifest.json`; reusable `tools/diagnose_skill_marker_lifecycle.gd`.
Both processes completed and original source hashes stayed unchanged. Stationary
click preserved authored node/body/weapon. Changed release preserved the exact
accepted bone and weapon transforms and copied accepted Tip/Pommel/orientation/
roll/arm/body-support fields correctly; mouse capture ended immediately within
the measured handler. Scoped whitespace check passed.

Boundary: the reported 300-500 ms engagement delay was NOT reproduced as a press
handler delay here. The instrumentation's movement-through-post-draw span was
127/133 ms before/after and includes observation work; it is not hardware pointer
latency. Do not claim all first-motion or during-drag stalls are solved. User
manual retest is next. No additional engine run, implementation expansion or
Git push is implied. The fix is currently local after checkpoint 4be15c15.

Manual follow-up (2026-11-06 02:08): user confirmed "it works well now" and
concluded the session. The sticky grab/release report is resolved for this
manual retest; no additional implementation or engine run followed. This is
interaction confirmation, not exhaustive anatomical/playback validation.
Release fix remains local, not pushed. Resume handoff: SPS_2026_11_06_02-08.md.

### Shoulder restriction report and isolation switched off (2026-11-06 22:32)

User reports near-total Pommel restriction, substantial Tip restriction and
elbow snap-back with `shoulder_direction_not_calibrated`. Static inspection:
the exact message is advisory, but uncovered directions hold humeral h fixed;
coverage is elevation 90 degrees +/-0.000573 degrees, plane 0..90 degrees.
Clavicle is separately held by the newer allocation contract. Intermediate
linear joint-parameter checks may also leave the curved fixed-h surface;
this numerical explanation and the elbow cause are NOT runtime verified.

At explicit user request, turned the reversible spine-isolation experiment OFF:
`player_humanoid_rig.gd::authoring_arm_spine_isolation_enabled = false`.
Updated the existing isolation verifier's default assertion, without executing
it. No scene/resource overrides of the setting were found. This restores torso
recruitment only where existing controls allow it; independent one-arm and Tip
allocator boundaries, the new clavicle hold and uncovered h hold are unchanged.
Do not describe this switch as a confirmed fix for shoulder restriction.

No engine runs or tests, as requested due to low token allowance. Static diff
inspection only. User will compare manually after restarting the game. Earlier
pointer-speed diagnostic explicitly assumes isolation ON; re-enable it in that
fixture if intentionally repeating the historical isolation experiment.
No Git commit/push. Resume: SPS_2026_11_06_22-32.md.

### Manual feedback and calibration comparison checkpoint (2026-11-06 23:06)

After disabling temporary spine isolation, user estimates Pommel restriction
reduced from 98% to 60%, and Tip restriction from 70% to 30%. These are user
impressions, not measured travel limits. Save and F work in the tested setup;
`shoulder_direction_not_calibrated` persists. Main-side edits appear to update
in jumps around 3-15 positions/second despite reported rendering around 210 FPS.
Do not turn those observations into a measured solver rate or a proven cause.

Static diagnosis remains: uncovered h hold and separate clavicle hold restrict
motion; intermediate joint-coordinate interpolation may violate a constant-h
condition even between valid endpoints. No confirming run or code correction
for that possible numerical conflict. Independent elbow snap-back remains
unresolved. Do not claim the shoulder issue is fixed by spine-isolation removal.

User requests a Git checkpoint before experimenting with the shoulder resource.
Potential user intervention within `shoulder_motion_profile.tres` must be audited
on resume against the exact code baseline recorded in the next SPS. Include the
profile definition, calibration, coverage resolver, allocator, rig, editor and
prepared-pose/replay consumers; do not assume only the .tres will change or erase
manual changes. At this checkpoint the resource and shoulder definition/resolver
have no local changes. No game runs/tests were requested or performed now.

## 2026-11-07 resumed shoulder movement correction

User lifted the no-run rule and requested working motion. Read the latest SPS
including its appended calibration example and the Coordinated Arm Motion and
Posture Selection Guide. Scope begins with the existing shoulder hold/solver
interaction, not a whole-guide compiler rewrite. Existing Save/F advisory
quality policy, grip bindings and fixed anatomical references remain authority.

Fresh comparison against `154a6db2`: all three profile sample arrays had been
emptied after the SPS append, with three unknown null properties added. This
fails `shoulder_profile_sample_count`, independently of uncovered directions.
Preserved that exact resource and user scene in
`godot_runs/shoulder_motion_20261107/user_*_before.*`; restored the documented
sample arrays and removed the unknown null properties. Scene changes are only
resource/node UID metadata and remain untouched.

Initial hypothesis was to separate shoulder swing coordinates from fixed-reference
humeral rotation. Targeted tests did not reproduce the proposed large curved-h
transition failure, so that production rewrite was NOT made. Actual Josie axial
calibration passed 105/105 checks; allocation checks passed 107/107 with added
held-h swing cases. These establish those fixtures only, not complete usability.

Isolated real Broken_Balde_v1 Skill 3: Tip right/left/right accepted all tested
requests (roughly 215/221/219 pixels), whereas Pommel vertical travel reproduced
the stall. First 10-pixel request took 549.815 ms / 782 evaluations for about
0.104 pixels of movement. Source library hashes remained unchanged. Evidence:
`godot_runs/shoulder_motion_20261107/before_live` and `before_pommel`.

A captured-pose reproduction (named local bones, same scaled/rotated skeleton;
declared 50-mm camera-plane target; no external collision callback) reproduced
SCALED 0.0104167. Opt-in rejection diagnostics showed task-error stagnation,
not intermediate shoulder-h violation. The arm was already at elbow extension
minimum: 11.995 degrees versus nominal 12. The requested direction increases
shoulder-to-wrist distance; the reverse 50-mm direction succeeds fully. The
original 50-mm target exceeds even a completely straight arm's reach.

Current narrow correction: a conservative analytic reach bound for single-arm
Pommel translation with a fixed shoulder socket. Use actual posed offsets,
existing elbow interval plus original invalid-start allowance, and explicit
world/RL_BoneRoot provenance. It only excludes proven unreachable task fractions;
normal FK, contact, anatomy, storage and collision checks remain authoritative.
Do not call this wider shoulder calibration or a complete smoothness fix.
Fresh verification pending while implementation is in progress.

User subsequently chose **Build provisional coverage from the research guidance**.
This supersedes the earlier strict measured-band-only selection for the live
profile. Existing coordinate zeros and signed angle conventions stay fixed.
Use the paired lowered-arm reference and explicitly checked local Josie rows;
borrow only within 15 degrees of original/checked donors, transport donor zeros,
and intersect overlapping intervals. Do not chain provisional donors around the
shoulder or claim that local geometry checks establish clinical anatomy.

User also permits alteration of all saved skills for testing and intends to
rebuild them later. Existing isolated evidence may still be reused where convenient;
no requirement to preserve a particular experimental skill blocks this work.

Stage A fresh evidence: pure reach 87/87, allocator policy 67/67, actual rig
250/250, shoulder strict-mode regression 109/109. The rig report emitted one
NaN-to-null JSON diagnostic warning; no assertion failed. Captured blocked
Pommel: 590.203 ms / 862 evaluations -> 148.575 ms / 252, within unchanged pose
tolerances. Real editor first update: 549.815 -> 209.307 ms. This remains too
slow for smooth continuous manipulation and is not a whole-solver speed claim.
The reverse captured 50-mm motion remains fully accepted with identical endpoint.
Real Save/cold reopen/F/stop/edit/Save/finish cycle: 10 write + 31 read checks,
source library hash unchanged. Evidence folders: `reach_*`, `shoulder_final_clean`,
`captured_pommel*_final`, `after_pommel`, `lifecycle_write`, `lifecycle_read`.

Stage B in progress: extend `shoulder_motion_profile_def.gd`, add a typed sample
definition, extend shared `combat_shoulder_motion_resolver.gd`, then populate
the live Josie resource only from inspected fixed-pose trials. Prepared captures
must retain the same profile data/provenance used by editing and equipped playback.

Stage B enabled the fixed `measured_plus_provisional` policy and 29 typed rows:
one paired lowered reference (2-degree abduction, -65.1/+66.9 degrees in our
internal-positive convention), plus 14 inspected centres per arm with -10/+10
degree initial intervals. The two 180-degree overhead candidates overlap the
head and were NOT enabled. The other 28 centres were inspected at all three
trial angles, front and side, with no illegal body-proxy overlap in those poses.
This does not certify the complete 15-degree neighborhood, all elbow bends,
weapon contact, skin under clothing, or clinical anatomy. The lowered-right
zero fixture overlaps an abdomen proxy; its published joint interval is not a
claim of collision-free whole-body motion. Evidence: `provisional_pose_review`.

Fixed references remain `CC_Base_Spine02ShoulderAnatomicalOrigin` ->
`CC_Base_Spine02` -> named parent chain -> `RL_BoneRoot`. Prepared arm constraints
capture the complete same profile. Original measured directions keep priority;
local borrowing transports both endpoints by the same zero offset, intersects
overlapping donors, stops beyond 15 degrees and cannot chain provisional donors.
Coverage remains incomplete. Ten degrees is an inspected authoring increment,
not an invented human endpoint or a final desired motion range.

Fresh checks after enabling: pure provisional policy 41/41; imported profile
strict regression 74/74; general imported rig 250/250; strict allocation109/109;
live provisional endpoint/backoff/regrab/capture checks104/104. The latter uses
actual imported offsets and current-direction intervals; tiny shaft changes
must stay within existing 0.025-degree/50-micrometre tolerances. Earlier failed
test attempts remain as evidence, not passes (initial helper arity parse error;
then comparing different shaft directions as though their bounds were identical).

Real isolated station lifecycle: Save10/10, cold reopen/F/stop/edit/Save/finish
31/31, no new acquisition during that F/edit cycle. Save1.58s with two advisory
pose warnings. Existing real player source unchanged. Equipped test initially
stopped at an OLD Combat Idle packet (`saved_grip_end_bounds_anchor_missing`),
before skill activation. Prepare that idle through its own normal editor page
for the fixture; do not add idle work to production skill Save.

Live saved Skill3 Pommel test after coverage: first reach-bound request203.779ms,
172 evaluations. Most later accepted steps about70-100ms, but one2,282.344ms
step/4,870 evaluations at the 15-degree donor boundary. Direction moved from
13.906 to14.991 degrees from the forward measured arc endpoint, then the next
step crossed15.559degrees and entered the old fixed-h hold. This is distinct
from StageA full reach: elbow about30.55degrees, reach fraction cap1. The covered
candidate can change h, but an uncovered candidate abruptly must use request-
start h. Boundary search still needs attention; NOT a smoothness pass.

### Final bounded body pass and current scope (2026-11-07 20:26)

Added a search-only cap for repeated Pommel covered-to-held shoulder trials:
after three iterations encountering an actual same-arm SHOULDER_HOLD violation,
stop that fit and retain the ordinary legal path-fraction result. Unrelated
constraint failures do not count. No limit, anatomical zero, acquired binding,
candidate validation or evaluator state was changed by this cap. This is a
bounded search improvement, not a continuous handoff between coverage regions.

Recorded-request reproduction restores named bones from trace row104 and request/
binding from row106. Its q/bounds/profile/calibration/previous-weapon comparisons
match. It omits the external scene collision validator and reconstructs JSON
transforms, so do not call it an exact full-UI replay. Before:3,182.103ms/7,355
evaluations, accepted0.91015625. Final:383.724ms/551, accepted0.87890625 (about
0.47mm less of this15mm request). Physical acceptance tolerances unchanged.
Evidence: `captured_boundary_before`, `captured_boundary_final`.

Real body-only drag comparison:2,282.344ms ->387.282ms at the difficult step;
next steps continue, including return movement. Other accepted steps about70-100ms;
this remains visibly slower than smooth rendering. Evidence:`final_live_pommel`.
That rendered run preceded the final stricter same-arm violation classifier;
the final classifier passed the captured comparison and74/74 allocator checks.
The actual player library hash remained unchanged throughout.

Earlier lifecycle checks are recorded above and need NOT be repeated during
further body refinement. Equipped sampling passed after independently preparing
Combat Idle via its own UI page (fixture14/14, Skill3 unchanged); acquired no new
grip during playback. Both freshly saved Skill3 node warnings were
`weapon_body_intersection` at `right_thigh`, not shoulder calibration failures.
Red text is a generic pose warning, not proof that every warning is calibration.

User clarified final scope: focus on BODY movement, fixed ranges, reversal,
coverage transitions and cost. Group related body changes and test those together.
Treat Save/F as established; do not run a full workflow after each body edit.
Revisit those systems only after direct changes or a reported manual regression.
All experimental saved skills may be altered; isolated fixtures are optional.
Next body target is the covered/uncovered shoulder transition, not persistence,
idle lifecycle, grip redesign, UI or full Coordinated Guide compiler work.

### 2026-11-07 accepted shoulder checkpoints and upper-body chain audit

User requested a Git savepoint before continuing movement work. Committed and
pushed `222a4c73fd2ae43740fcf9fbb971ae80aaa8a2ef` on
`recovery/stable-92b8a24-chat14` (remote verified). It contains the preceding
calibration/search work and evidence tools, not the changes below. Unrelated
editor settings, scene UID metadata, generated test libraries and worldbuilding
notes were left outside that commit. Subsequent body corrections remain local.

Latest scope clarification: research is guidance to adapt to Josie's real bones,
not an instruction to replace working systems. Inspect the full upper-body chain
to RL_BoneRoot, excluding legs, because an older surrounding mechanism can cause
a bad handoff. Grip acquisition remains protected. Save/F/equipped playback are
established consumers; do not repeatedly retest their complete lifecycle during
body-only refinement. Shared definitions and fixed anatomical origins remain
authoritative; no new anatomical endpoints were invented in this pass.

#### Confirmed mechanical cause and correction

The allocator already splits movement into bounded task substeps. However, its
adapter kept the shoulder hold reference from the beginning of the entire
request even after completing an accepted substep. A subsequent trial outside
calibrated coverage then tried to return to that older h, undoing legitimate
progress and causing repeated searches.

- `CombatWeaponMotionAllocator` now notifies an optional adapter checkpoint only
  after a completed, validated fit on the ORIGINAL requested task path and actual
  q progress. FK probes, line search and bisection trials cannot advance it.
- `CombatWeaponMotionRigAdapter` updates only request-local accepted shoulder
  continuation state. Covered poses supply the current h; an existing uncovered
  `held_h` stays fixed until covered re-entry. No anatomical zero, profile, grip,
  bone pose or persistent rig state is written by this notification.
- When a coverage failure yields a validated partial task checkpoint, at most
  two bounded continuations can resume the remaining original request. Original
  fractions, contact tolerances and original invalid-start allowance remain.
- Fixed-coordinate finite-difference columns are now left zero without full FK
  evaluations. Equality is exact on EFFECTIVE bounds: narrow nonzero intervals
  and recovery allowance still remain movable.
- Cleared a recovered failure diagnostic so a later substep-budget stop does
  not incorrectly report an earlier resolved coverage failure.

Production files touched in this slice: `core/resolvers/combat_weapon_motion_allocator.gd`
and `runtime/player/combat_weapon_motion_rig_adapter.gd`. Existing anatomy,
profile rows, opposite-arm isolation and shared two-hand authority were retained.
Official Godot4.7 Callable, Skeleton3D and Transform3D docs were consulted;
Skeleton3D global bone poses remain skeleton-relative, with explicit root/world
conversion through the existing adapter.

#### Fresh focused evidence

Root: `godot_runs/shoulder_continuity_20261107`.

- `fixed_coordinates`:32/32; locked-column work, mixed/reduced equivalence,
  reversal, narrow intervals, recovery allowance and all-fixed inputs.
- `allocator_policy`:74/74 existing movement/contact/coverage policy checks.
- `continuation_policy_affine`:54/54. A small serial mechanism stops at75%
  without continuation and reaches100% with it; hold remains unchanged through
  repeated outside regrabs, reverse/re-cross succeed, invalid/rejected/stationary
  inputs generate no checkpoint. This is API/constraint proof, not human anatomy.
  Earlier `continuation_policy` used an ill-conditioned synthetic helical
  fixture and failed before reaching coverage; it remains recorded as a failed
  fixture, not a passing body result. Production was not changed to force it.
- `imported_endpoints`:104/104 actual imported R/L lowered/raised/posterior
  endpoint, reversal, regrab and constraint-capture checks. No full lifecycle run.
- `captured_control_comparison`:same recorded real pose/request and unchanged
  profile/calibration/contact. New handoff ACCEPTED100%,91.979ms/112evaluations.
  With only the checkpoint callback removed (fixed-column optimization still
  present), SCALED87.890625%,311.823ms/485evaluations. This separates the handoff
  correction from the derivative optimization. This diagnostic omits external
  scene collision and reconstructs JSON transforms; it is not a full UI replay.
- `live_pommel`:actual saved Broken_Balde_v1 Skill3 node3, same rendered
  forward/reverse/forward input sequence as previous pass. Previously troublesome
  return step8:partial387.282ms/555evaluations -> full74.733ms/66. Following
  steps also fully accepted at about66–78ms; retained held_h stayed constant
  within1e-6radians. Other ordinary return steps about56–60ms. Separate initial
  near-extension demand still reaches a real limit and costs131.655ms; it is
  not evidence that the entire solver is now smooth.
- Live root/hip/torso/opposite-arm comparison at each drag end:9named bones,
  maximum world-position difference0.000000894m, zero reported angular change.
  User source library unchanged. No Godot process left running.
- Live run preceded only the final no-op-checkpoint guard and recovered-failure
  reporting cleanup. Final synthetic verifier covers those changes. Do not call
  that rendered run proof of unrelated grip, Save/F or equipped workflows.

#### Full upper-body audit: what remains

Current control paths are not mechanically identical:

| Control | Contributors |
| --- | --- |
| Single-hand Tip/Pommel/attached Roll | Shoulder, elbow, forearm, wrist; clavicle and torso held |
| Two-hand Tip | Both arms; clavicles and shared torso held |
| Two-hand Pommel/Roll | Both arms plus existing shared torso yaw/pitch; clavicles held |
| Independent elbow/free hand | Older selected-arm CCD, including clavicle movement |

Independent elbow/free-hand CCD does not apply the new shoulder envelope during
its solve and has no separately calibrated clavicle envelope. It can therefore
produce a pose the next weapon-control edit treats as an invalid-start pose.
That is a genuine coordination gap, separate from the reproduced Pommel hitch.
The old body's accepted-allocation guards suppress late direct-IK/torso writers;
no evidence was found of ordinary late torso overwrite causing this reproduction.

Single-arm torso exclusion protects the user's opposite-arm world-space freeze.
Do not simply unlock torso and drag that arm along. The next coordinated-body
slice should reconcile shoulder/clavicle constraints across control paths using
actual rig reference axes and a declared local clavicle envelope. Older heuristic
pose-direction weights are NOT independently calibrated clavicle ROM limits.
Root and legs were not altered. The shoulder donor field still has abrupt
inclusion/intersection boundaries; this pass fixes accepted-state handoff, not
all spatial interval discontinuities. Remaining56–78ms ordinary updates are
still above a smooth interactive frame budget. Keep those limitations explicit
and use manual feedback before expanding the next implementation.
