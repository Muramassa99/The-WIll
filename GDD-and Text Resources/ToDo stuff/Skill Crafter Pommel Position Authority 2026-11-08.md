# Skill Crafter Pommel position authority — 2026-11-08

## User decision and code finding

User requests removal of the old fixed weapon-angle requirement during Pommel
movement. Pommel previously requested both position and orientation (six task
components); Tip requested orientation alone. Arm roll existed but its combined
result had to preserve the weapon's previous world orientation during Pommel
movement. This is separate from the acquired hand-to-weapon attachment.

## Implementation contract

- Pommel requests the world position of the actual WeaponRoot-local Pommel
  landmark. Weapon orientation is free to follow permitted skeletal motion.
- Tip follows the resulting rigid weapon frame; it is not forced to remain at
  the old Tip position plus Pommel translation.
- `task_point_local` is an explicit WeaponRoot-local task landmark, distinct
  from `contact_local`, the selected handle station used by acquired contact.
- Retain rigid acquired hand/weapon relationships, strict initial frame and
  storage readback checks, anatomy limits, fixed Idle references, existing
  independent-arm isolation and shared two-hand attachment constraints.
- Wrist local Z remains fixed during Tip/Pommel edits; its existing green
  control remains its authoring owner. Finger/grip acquisition is unchanged.
- Remove the Pommel fixed-orientation wrist reach shortcut and orientation-first
  clearance fallback. Keep collision constraints and legal sliding/recovery.
- Actual accepted Tip, Pommel and orientation already feed the normal authored
  node encoder. Save/F format and lifecycle are not being redesigned.

## Files and focused verification

Allocator task semantics, rig adapter request, weapon motion manipulator,
Pommel help text, and focused verifiers. Native numerical implementation stays
unchanged. Verify a nonzero Pommel landmark, reachable position requiring
orientation change, strict acquired contact, R/L actual rig, transformed root,
held wrist Z, opposite-arm isolation and shared two-hand contact. Run a focused
live authoring check. Do not claim old fixed-orientation performance/pose parity
as current-task evidence: the user intentionally changed that task.

## Evidence

### Follow-up decision: trailing Tip and held forearm roll

After the first implementation/test below, user supplied two drawings and
clarified the intended behaviour. The 4:1 suggestion was a mental placeholder,
not a ratio to implement. Pommel leads; Tip tends to remain where it was and is
pulled along at rigid weapon length. Pushing/reversing can initially swing Tip
away from the travel line. There is no independent Tip path or time-based lag.

During Pommel use, hold the active arm(s)' existing calibrated forearm axial
`rho`; upper-arm axial roll remains available. This is a relative anatomical
coordinate, not a world-space forearm lock. Tip editing retains existing rho
freedom. Keep existing hand-local Z ownership and acquired contact unchanged.

Implement optional WeaponRoot-local `trailing_tip_local` alongside distinct
Pommel `task_point_local`. Reuse existing FK derivative probes for a secondary
Tip-displacement preference in the existing posture objective. Initial finite
weight is 1 after existing position normalization (tuning, not a physical drag
constant). Primary Pommel progress and all anatomy/contact constraints take
priority. No exact Tip-target test, new blocker, momentum, timer or new solve
after release. Use actual Tip at the start of each accepted spatial substep as
reference; do not update it from rejected trials. No post-drag reference moves.

Files: allocator, weapon-motion policy, motion rig adapter and manipulator,
Pommel help text, focused verifiers. Follow-up implementation and focused
validation complete. Current evidence: `godot_runs/pommel_trailing_20261108/`.

- Pure: 20/20 checks, including the same-start preference comparison, rigid
  length, unavailable trailing yielding to Pommel progress, zero-weight
  equivalence, and forearm/upper-arm channel ownership.
- Actual rig: 74/74, with native arithmetic and forearm clearance enabled.
  Forearm rho stays bit-equal in R/L original and moved/rotated/1.7x-scaled
  roots; wrist gamma remains held too. Actual Tip edits still change rho by
  about 4.76 degrees in each hand. Shared two-hand contact/movement passes.
- Same-start actual-rig comparison: Tip travel decreases from 57.30 to
  12.90 mm on R and 30.61 to 11.49 mm on L, while both Pommel targets are
  fully reached. These are fixture results, not a universal travel ratio.
- Rendered Broken_Balde_v1 / Skill 3, normal Reset/acquisition, actual Pommel
  marker pick, 40 production queued drag samples and GUI release: all accepted,
  no failures. About 0.374 m Pommel travel each way, 35.18 degrees maximum
  weapon-angle change. Grip contact error below 0.271 micrometres; rigid-length
  error below 0.358 micrometres. Authored endpoints/orientation match actual FK.
  Zero release drift; forearm rho and wrist gamma remain held within existing
  tolerances. Full measurements and trailing anchors in `live/manifest.json`.
- Live allocation min/median/max 18.700 / 23.458 / 29.441 ms for this path.
  This is not a claim that every anatomical boundary stall is solved, nor a
  time-lag/FPS measurement. Native implementation and numerical budgets were
  not changed. The preference reuses existing FK samples and posture QP.
- No Save/F lifecycle rerun, no grip logic redesign, no Git/index action.
  Runtime check ended cleanly; only pre-existing editor remains. Next: user
  feel test of trailing strength and held-forearm Pommel manipulation.

The following measurements describe the earlier free-angle pass.

### Prior free-angle pass (before trailing/held-rho follow-up)

Implementation and focused live authoring integration check complete.

- `verify_pommel_position_authority.gd`: 12/12 checks pass. An offset Pommel
  reaches its point through a coupled hinge rotation where the old fixed-angle
  task cannot. Initial actual-frame mismatch is still rejected; Tip/Roll retain
  their original tasks. The one-hinge fixture uses one task substep because the
  straight chord between arc endpoints cannot be followed by that single hinge.
  Runtime subdivision settings are unchanged.
- `verify_pommel_position_authority_rig.gd`: 54/54 pass, actual Josie Idle R/L,
  with native arithmetic and forearm clearance enabled. Requested landmark
  errors: 2.174/0.360 micrometres at original root, 2.844/36.291 micrometres
  after root rotation/translation/1.7x scale (all below 50 micrometres).
  Weapon turns 5.3–7.2 degrees while following the addressed Pommel landmark.
  Acquired contact, held wrist Z, opposite-arm world poses, shared two-hand
  contact, and named parent-local packet reconstruction pass.
- Existing independent-arm/shared-hand integration: 22/22 pass. Old verifier
  assumptions about a fixed-orientation reach bound were updated to test its
  absence and unchanged origin/start-allowance behavior.
- These tests do not certify complete smoothness. Actual-rig requests took
  42–71 ms in the focused single-arm cases; the shared-hand case took 244 ms.
  Task semantics differ from the old benchmark, so these are not an exact
  before/after speed comparison.
- Evidence: `godot_runs/pommel_position_20261108/` (`pure_final.log`, `rig/`,
  `callers/`). No saved-skill lifecycle redesign or Git/index operation.
- `verify_live_pommel_position_authority.gd`: rendered Skill Crafter,
  Broken_Balde_v1 / Skill 3 in the existing isolated-library harness. Normal
  Reset/acquisition, actual visible Pommel pick, 40 queued production drag
  samples, GUI release. All 40 requests accepted; both directions move about
  0.374 m, with maximum weapon-angle change 42.65 degrees. Acquired hand/weapon
  error stays below 0.276 micrometres / 0.0000272 degrees. Encoded Tip/Pommel
  and weapon orientation match the actual accepted frame. No release drift.
  Live allocation min/median/max: 23.201 / 23.792 / 51.576 ms. Total sampled
  step wall time also includes deliberate frame waits; this is not an OS input
  latency or FPS test. Captured start/end images were inspected. Report:
  `godot_runs/pommel_position_20261108/live/manifest.json` (40 entries under
  `cases[0].requests`; inherited `sample_count` is unused/zero).
- The local task point comes from the weapon's actual Pommel metadata and
  remains separate from its acquired handle station. Position-only return
  movement does not promise the same final orientation: that orientation is
  selected by legal coordinated FK, not a world-angle lock.
- No game remains running after the check; only the pre-existing editor.
  User feel-testing remains next. Boundary stalls and broader optimization are
  not declared solved by these results. Save/F were deliberately not rerun.

Prior native/forearm work and timings remain in `Skill Crafter Forearm Clearance
and Native Motion 2026-11-08.md`; preceding SPS: `SPS_2026_11_08_01-21.md`.
