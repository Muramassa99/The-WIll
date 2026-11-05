# Skill Crafter directional Tip stall audit - 2026-11-05

## Scope and user reproduction

Diagnosis requested; no movement-rule or optimization changes authorized by this
slice. Keep Body Support, anatomical limits, current arm isolation, and saved
skills unchanged. Source is Broken_Balde_v1, Skill Slot 3, visible node 3.

User screenshot shows right-main, single hand, normal grip, Body Support 1.0,
Drag speed 180 px/s, Tip approximately (-0.647, -0.284, 2.686), Weapon Roll
-65.6 degrees and right upper-arm roll -100.4 degrees. Pull Tip screen-right
(black arrow), briefly left, then right again. User further describes a ratchet:
12 -> 11 -> 10 o'clock is possible, but 10 -> 11 is not; the apparent stopping
point advances with the allowed direction. This description is the test target,
not proof of the underlying mechanism.

## Current evidence

Evidence root: `godot_runs/tip_direction_stall_20261105`.
Diagnostic: `tools/diagnose_skill3_tip_direction_stall.gd`.
Tests load an isolated source-library copy, select saved node 3 and use captured
mouse input. No Reset, Save, F, grip override, or authored-pose fabrication.
Source-library SHA checks pass. Small differences between screenshot and opening
pose are recorded rather than overwritten to fit the screenshot.

### Run 1: preliminary default view, duration-based input

Completed, but did not reproduce the complete claimed ratchet. Large solve stalls
meant only 4 right / 1 left / 4 right samples arrived. Pending results crossed
phase labels, so use request/accepted transforms rather than labels alone.
The short left excursion was actually retraced. Slow calls accepted only
4.6875-6.25% of requests, taking 506-608 ms and 1,221-1,494 pose evaluations.

### Run 2: matched view and completed steps

Camera yaw -3.6 degrees, pitch 24.17 degrees, distance 3.515 m approximates the
screenshot's projected Tip and hand positions. This is a framing estimate, not a
claim of identical historical camera coordinates. Twelve 3-pixel requests in
each direction; each input and its pending solve drain before the next event.
49 diagnostic checks pass; original saved library unchanged.

- First 36 px rightward demand: Tip x moves only approximately 0.5 px. Each solve
  accepts 4.6875-7.8125%, taking 472-676 ms; failures report search exhaustion.
- 36 px leftward demand: all 12 solves accept 100%, taking 8.468-23.845 ms.
  Actual Tip x moves from 635.534 to 609.980 px.
- Rightward return: first ten requests accept 100%, then the search stalls again
  near x=630 rather than the original x=635. This establishes an advancing
  practical stopping point, but not an absolute ban on every reverse increment.
- Starting and final anatomical warnings remain empty in these attempts. The
  original stalled pose has forearm roll around 69.7 degrees, below its bound,
  and no reported active joint limit. Storage validation reports no failures.
- Shoulder/clavicle increments remain effectively zero. Leftward travel uses
  elbow and wrist until the coupled wrist boundary, then forearm roll increases
  from about 69.65 to 70.74 degrees. Return initially holds that new forearm roll.

`run2/direction_summary.json` summarizes completed-solve directions and timings;
`bone_trace.jsonl` retains the full bones, wrist states, allocator context, input,
camera-related projection, task scales and search failures.

### Run 3: longer left travel and same-request counterfactual

Same camera, source, cap and rightward steps; leftward travel extends to sixty
3-pixel inputs. All sixty left steps accept 100%. Forearm roll grows from
69.648 to 87.896 degrees after the coupled wrist boundary is reached. The first
twelve right-return steps also accept 100%, holding that new forearm angle and
using elbow/wrist. This run does not travel back far enough to establish its
final return wall, and does not demonstrate a universal immediate CW lock.

`tools/diagnose_skill3_tip_convergence_probe.gd` retains the first difficult real
request and its scene checkpoint. After the actual gestures, it compares that
one request using production and an instrumented diagnostic-only copy,
`tools/combat_weapon_motion_allocator_trace.gd`. Counterfactual results are not
committed or saved. Original scene, wrist cache and diagnostic counters are
restored. All diagnostic checks pass; original source-library hash is unchanged.

Live result versus production rerun, and production versus traced copy, match
exactly: accepted weapon, joint vector (maximum difference 0), status, reason,
and task scale. Final scene restoration is exact. No trace events were dropped.

| Comparison | Accepted task | Fit iterations including retries | Pose evaluations |
| --- | ---: | ---: | ---: |
| Original policy | 7.8125% | 90 | 1,422 |
| Original policy, 60-iteration per-fit budget | 98.4375% | 351 | 5,690 |
| Only forearm-hold priority tier removed | 100% | 2 | 17 |

Limits, target, acquired grip, collision/context validator, tolerances and
sampling rules are unchanged in the priority comparison. The diagnostic copy
adds instrumentation overhead; its timings are not production benchmarks.

## Established cause for the reproduced rightward stall

The requested orientation change is approximately 0.5512 degrees. Before the
forearm-hold priority, a simple solution uses approximately -0.531 degrees of
forearm rotation and a small wrist adjustment. The forearm-hold tier instead
selects -8 degrees of elbow, -3.168 degrees wrist beta and +7.411 degrees wrist
gamma to reduce forearm use to approximately -0.440 degrees.

Successive nonlinear fits then oscillate between elbow positions approximately
31.523 and 23.523 degrees. The elbow/wrist orientation Jacobian is nearly
singular in this region: its normalized determinant magnitude is approximately
0.006-0.044 and its sign flips as the fit crosses that configuration. The solver
shrinks its line-search steps, exhausts twelve iterations, restarts with smaller
requested movements, and ultimately returns a tiny accepted task fraction.

Allowing forearm contribution earlier reaches the same target with unchanged
elbow, shoulder and clavicle, and about 0.000928 degrees remaining orientation
error. No active anatomical boundary or validation failure prevents that solve.
The strict preference for preserving forearm rotation drives the ineffective
search route. More iterations alone multiply the work rather than addressing
that preference.

Each new request uses the last accepted joint state as its reference. This is
why the preferred hold orientation follows the arm after leftward travel.
Combined with the ineffective return search, it explains the observed shifted
practical stop in run 2. Do not overstate this as proof that every clockwise
increment is prohibited: both runs include some successful return movement.

Primary evidence: `run3/convergence_probe.json`; full gesture evidence:
`run3/bone_trace.jsonl` and `run3/manifest.json`.

## Code ownership and next decision

- `core/resolvers/combat_weapon_motion_allocator.gd::_hold_order` defines the
  strict Tip preference for holding forearm before minimizing elbow/wrist use.
- `_fit` applies those priority QPs repeatedly against its original start pose,
  then falls back to reduced task sizes after nonlinear search exhaustion.
- `runtime/player/combat_weapon_motion_rig_adapter.gd` provides the calibrated
  kinematics and validates candidate storage/contact. Those checks succeeded
  in the decisive comparison.
- The existing research guide explicitly requires recruiting the next useful
  component when a preferred component is ineffective or singular, not only
  when a scalar joint limit is reached.

No production motion rule was changed in this diagnosis. Removing the priority
tier is an experimental isolation of the cause, not a validated replacement
policy. A focused future fix should retain the intended distal-first behavior
while permitting effective forearm assistance before spending repeated search
budgets on opposing elbow/wrist corrections. Check both movement directions and
the user's longer clock-face sequence before claiming the full symptom fixed.

No anatomical-limit relaxation, grip-solver changes, speed-cap changes, new
threads, native port, saved-skill rewrite, Git operation, or SPS was performed.

## Follow-up: user reports approximately 500 degrees in one direction

After discussing forearm pronation/supination, the user reports approximately
500 degrees of continuous weapon rotation in one direction while reversal is
blocked. This is additional manual evidence; the diagnostic runs above did not
record that complete turn. A weapon's cumulative screen-space arc is not itself
a measurement of one joint's anatomical twist. Record the contributing joints
and their reference frames before attributing the full rotation to forearm roll.

A focused code audit confirms a separate missing restriction in the active
weapon-motion allocator:

- `_build_arm` initializes all three clavicle channels and the three shoulder
  channels to zero, with bounds of +/-PI. These are increments relative to the
  captured current local poses, rebuilt on every movement request.
- `_evaluate_kinematics` composes those increments onto the captured poses. Its
  shoulder checks only constrain the angle between the clavicle-to-shoulder and
  shoulder-to-elbow segments. Axial upper-arm rotation does not change that
  angle. There is no absolute calibrated shoulder-twist interval or absolute
  clavicle orientation envelope in this route.
- Commit readback constructs another adapter and checks the same constraints;
  it does not add the missing anatomical envelope.
- Forearm rho is different: it is measured against rest calibration and bounded
  by the configured +/-90-degree profile. The measurement preserves continuous
  angle branches. It does not receive a fresh full range on every request.
- The torso route already compares against a fixed cached baseline to prevent
  repeated rotation allotments. That mechanism is absent for shoulder/clavicle.
  Torso remains isolated in the current experiment.

This is a confirmed code gap permitting cumulative upstream rotation without a
corresponding absolute twist check. It is a candidate explanation for excessive
weapon rotation, not a runtime attribution of the user's complete 500 degrees.
The research arm guide already calls for a calibrated, pose-dependent shoulder
swing/twist envelope and a constrained girdle reference. A segment-angle check
alone does not implement those requirements.

Consequently, passing the present allocator checks must not be described as
proof of complete human anatomical validity. The priority/convergence defect
and the missing upstream bounds are distinct findings. Any eventual correction
must allow legal local reversal and forearm contribution while retaining stable
anatomical references for the rest of the chain. No production edits or extra
engine runs were made for this follow-up code audit.
