# Skill Crafter curve-editing and roll audit - 2026-11-05

## Scope and preservation

User fixture: saved `Broken_Balde_v1`, Skill Slot 3, three visible motion nodes.
Open, await acquisition/readiness, F to completion, then inspect the last visible
node (3). Perform two blue incoming Tip-curve cube gestures in the same instance:
five clockwise circles requested over three seconds, releasing and recording
between gestures. User clarified their own earlier test used node 2, which has
incoming/outgoing handles, and explicitly accepted blue-only testing on node 3.
The saved last node has no nonzero outgoing handle; no orange cube was invented.
Then compare clockwise/counterclockwise Tip gestures from a restored common
post-cube baseline. Shared drag cap: **900 px/s**. Temporary spine isolation remains
enabled. This is investigation, not authorization for a solver or anatomy fix.

Actual rendered Godot 4.7 station/rig, synthetic engine mouse events through the
captured-input route. A fresh diagnostic clones the source weapon into an isolated
in-memory library. No Reset or skill Save. The user's source library SHA256 before
and after both runs, and checked again after completion, is unchanged:
`166bc47ca23a81b6310a30208c80c050c259ddc8ef99bb47fa023c22cec19450`.
Production code and anatomical limits were not edited during this audit.

## Evidence and reproduction

- Harness: `The Will- main folder/the-will-gamefiles/tools/diagnose_skill3_curve_roll.gd`.
  Extends the existing isolated-library reopen harness; overrides its write phase
  to observe only. Actual bone local/world transforms, measured semantic wrist
  angles, cached state, authored/effective nodes, allocator results, status and
  screenshots are captured. The old debug overlay is not measurement authority.
- Evidence directory: `godot_runs/skill3_curve_roll_20261105/`.
- `run1/manifest.json`, `run1/bone_trace.jsonl`, `run1/offline_summary.md`:
  initial view; both blue gestures engaged, but subsequent Tip was offscreen.
  Exit 1 reflects those test limitations, not proof of rejected Tip movement.
- `run2/manifest.json`, `run2/bone_trace.jsonl`: camera-only zoom-out six steps,
  both blue and both Tip gestures engaged. Exit 0 / technical completion does
  not certify correct application behaviour. Four gestures observed.
- Compact directional evidence: `run2/paired_tip_analysis.md` and `.json`.
  Comprehensive bone comparisons: `run2/offline_summary.json` and `.md`.
- `summarize_curve_roll.py` and the paired-analysis script in the evidence
  directory perform offline calculations; no engine run or source-data mutation.

Run arguments (one substantial Godot instance only):
`--path <project> --script res://tools/diagnose_skill3_curve_roll.gd --log-file <fresh-log> -- --phase=write --hands=R --weapon=Broken_Balde_v1 --slot=skill_slot_3 --zoom-out=6 --out=<fresh-output-directory>`.

## Confirmed: curve editing changes the endpoint pose

Run2 changes below are measured separately from the start of each gesture, not
summed scalar distances. Quaternion distances express orientation change, not
signed anatomical roll.

| Blue cube gesture | Weapon orientation change | Actual Tip displacement | Actual Pommel displacement | Stored Tip/Pommel displacement |
| --- | ---: | ---: | ---: | --- |
| First | 9.247 degrees | 196.741 mm | 28.629 mm | Less than 0.001 mm each |
| Second | 23.219 degrees | 523.668 mm | 33.493 mm | 196.741 / 28.629 mm |

The first curve gesture changes the displayed body/weapon while its authored
endpoint positions remain effectively unchanged. The second gesture copies that
previous displaced endpoint pose into stored node data. This is state crossing
from curve editing into endpoint editing, not just an approximate guide drawing.
Run1 independently reproduced the same pattern: approximately 208/514 mm Tip
displacement and 9.763/22.774 degrees weapon change for its two gestures.

Press alone made no pose change. Changes began on processed preview updates,
continued during the gesture and occurred again on release. In run2 release
alone moved the Tip another 34.385 mm, then 48.255 mm for the two gestures.
Ten settling frames added no further change. Curve release calls took about
962/964 ms. Frame gaps during gestures reached 115/78 ms; these are instrumented
run measurements, not physical mouse-to-screen latency.

Before the cube test, the right forearm's semantic roll was 69.740 degrees.
After the first gesture it was 89.943 degrees, close to the existing +90 stop.
After the second it retained that same semantic roll while the larger arm/weapon
configuration moved further. Thus not every visible change is extra wrist roll.
Full per-bone data is retained rather than reducing all motion to one Euler angle.

Visual comparisons: `run2/blue_in_1_before.png`, `blue_in_1_after.png`,
`blue_in_2_after.png`. These were inspected alongside actual skeleton transforms.

## Source cause and narrow proposed correction

All source paths below are under the active project; line numbers identify the
audited snapshot and may drift after later edits.

1. `core/models/combat_prepared_pose.gd:8-24` deliberately excludes the four
   curve handles from endpoint pose signatures. UI `_apply_curve_handle_drag`
   (`runtime/combat/combat_animation_station_ui.gd:9553-9606`) changes curve
   vectors, not the authored endpoint pose.
2. UI `4184-4225` still sends a curve drag's duplicated live motion node through
   the ordinary full preview refresh. Presenter `_retained_authoring_grip_pose`
   (`combat_animation_station_preview_presenter.gd:4546-4559`) rejects that
   pose-equivalent duplicate because it requires the same Resource identity.
   Prepared-pose restoration also excludes live overrides/active drags
   (`4385-4398`).
3. Presenter `423-474` can therefore fall through to `_apply_authored_weapon_pose`
   and its body/contact work (`4915-4987`). Curve-only input causes unrelated
   posing, although the body payload (`6840-6900`) does not use curve handles.
4. On the next engagement, UI `_build_display_motion_node_for_viewport_pick`
   (`6931-6986`) copies displayed endpoints/orientation into the drag baseline.
   This includes the displaced pose from the previous curve edit.
5. Release uses the generic commit (`7438-7456`). For unlocked nodes,
   `_apply_motion_node_state` copies endpoints/orientation/roll (`7281-7285`)
   as well as curve data, then invokes another full preview refresh. The
   curve-only commit helper is currently used only for locked nodes.

Proposed next slice, **not implemented**: a curve-only edit should preserve the
current body, weapon and acquired grip; modify/commit only curve fields; redraw
the trajectory; invalidate the affected path/replay cache. Presenter already
has `refresh_authoring_motion_visuals` (`1336-1357`), explicitly avoiding another
body/grip solve. Preserve the existing endpoint-editing path. Verify repeated
cube drags and release leave actual and stored endpoint poses unchanged, while
F preparation uses the changed trajectory. Do not loosen anatomy or rewrite
gripping to compensate for this editor-routing fault.

## Tip CW versus CCW: partial support for limit pressure, no one-way lock proved

Both directions started from the same restored post-cube state: authored/effective
nodes, wrist cache, measured wrist state and arm-control references exactly equal;
weapon position/orientation and bone world positions equal. Quaternion numerical
comparison noise stayed below 0.000003 degrees. This comparison is deliberately
after the cube-induced displacement; it is not a clean pre-cube Tip test.

Both directions engaged and moved. Each received 43 synthetic motion samples;
five requested turns took about 3.06/3.09 seconds. All populated allocator
observations were ACCEPTED with task_scale 1 and no reported search failures.
Metadata persists between evaluations, so observation counts are not unique solve
counts. Peak recorded allocation cost was 23.050 ms CW / 25.272 ms CCW.

Right forearm roll during the Tip tests stayed near the upper limit:
CW 89.390-90.000 degrees; CCW 89.943-90.000 degrees. Joint-range markers were
reported in both directions, more often JOINT_RANGE:7 in CCW; CW also exposed
the coupled wrist envelope. This supports direction-dependent constraint
pressure, but does not establish a universal one-direction prohibition, angle
wrap leak, or the old 324 ms exhausted-search case in this fixture.

Both release calls took about 1.16 seconds and changed the footer to
`Movement not accepted: wrist_motion_range (APPROXIMATE)` while leaving the
actual reached pose unchanged. The measured reached wrist stayed within limits;
the last allocator metadata still described an accepted movement. These describe
different stages and must not be treated as one failed allocator result.
The release route has a separate source-level defect, described below.

### Release clears Tip identity before its final pending movement is processed

`combat_animation_station_ui.gd:8972-8974` flushes the captured mouse movement,
calls `motion_node_editor.end_drag()`, and then finalizes the edit. `end_drag`
clears the drag target. Flushing input can leave an endpoint pose update pending;
it is not itself the final pose allocation.

Finalization at `7425-7426` then forces `_apply_pending_endpoint_motion_attempt`.
That function selects the Tip allocator path using `get_drag_target() == tip`
at `4292`. The cleared target fails this test, so the remaining candidate goes
through generic preview refresh and `finish_authoring_motion_attempt` at
`4313-4314` instead.

Presenter `_retained_weapon_motion_pose` (`4310-4315`) clears manipulator ownership
when that unallocated changed candidate no longer matches. The finishing function
(`1312-1328`) then runs strict forearm/hand validation instead of recognising the
allocator's previously accepted pose. Its failure can produce exactly
`wrist_motion_range (APPROXIMATE)` and restores the checkpoint. This explains how
the last accepted body and allocator metadata remain unchanged while the footer
reports failure on release. The trace records before/after states, not every
internal temporary validation state; do not identify the precise rejected joint
or candidate angle from the restored pose alone.

Both traces also show the last accepted effective node being committed to the
actual authored node on release. The warning therefore concerns the final pending
sample; it does not mean that the complete drag was discarded. The rejected
transient pose, ownership transitions and `last_endpoint_motion_validation` are
not included in this trace, so their exact residuals remain unmeasured.

Narrow follow-up proposal, not implemented: retain the drag's control identity
until its final pending update is evaluated and committed through the same route
used during movement, then release capture/drag state. Audit normal release,
cancel and focus-loss finalization together. Preserve the last accepted result
and existing recovery behaviour; do not silence the error or loosen the limits.
This is a lifecycle correction, separate from the curve-only transaction above.

## F playback observations

F preparation: 1.694 seconds in run1 / 1.772 seconds in run2. Playback started,
ran to completion, then restored the pre-F editing pose to numerical precision.
The source file remained unchanged. This is evidence for this saved skill,
not a general F/Save/equipped certification.

Run2 sampled right wrist rho 48.962-67.790 degrees, beta 2.098-26.229 degrees,
gamma -16.938-0.787 degrees during playback. No sampled wrist state was invalid
or outside the current limits. Left semantic wrist state stayed constant. Spine
01/02 stayed fixed; left clavicle moved up to 2.827 degrees, carrying the left hand
up to 13.527 mm. This playback follows saved poses; it is not an independent-arm
editing isolation test. No new anatomical correctness claim follows from it.

Sixteen sampled playback poses span 2.133 seconds, with screenshot/readback
overhead. The largest recorded post-entry forearm local orientation change was
19.592 degrees across 155 ms. These sparse samples cannot establish a single-frame
snap or certify continuous playback smoothness. Images F_0000 through F_2200 and
the full skeleton trace are retained for review.

## Boundaries

Five circles are requested mouse input, not proof that a capped marker or weapon
completed five revolutions. Different frame sampling and input clipping explain
some run-to-run numerical differences. No benchmark claim against uninstrumented
manual playback. No scene-tree threading, C++ port, anatomy/grip/allocator edits,
saved-skill migration, Git operations or permanent spine decision in this pass.
The confirmed curve-editing fault is the first bounded correction to discuss.

## Authorized correction, 2026-11-05

The user subsequently authorized the fixes and requested the Body Support
default change from 0.4 to 0.9. Explicit comparison constraint: preserve Skill 3's
existing values (1.0 on each visible node). This supersedes the earlier
read-only/proposed status above; the preceding observations remain historical.

Production changes are limited to two owners:

- `combat_animation_station_ui.gd`: curve drags and numeric curve edits use the
  existing visual-only refresh. They retain the acquired pose and commit only
  the selected curve field, without copying displayed endpoint positions or
  the other automatically calculated curve handles into the stored node.
  Ordinary dirty tracking and runtime-clip invalidation remain active, so F
  rebuilds the changed trajectory from the same recorded endpoint poses.
- The same UI retains the drag's control identity until finalization completes.
  The final pending Tip update therefore follows the same allocation route as
  updates during the drag, even after the input helper ends its drag. Pommel
  authority uses the same retained identity. Finalization clears that identity
  and restores the pointer; existing cancellation semantics are preserved.
- `combat_animation_weapon_geometry_resolver.gd`: newly seeded weapon poses use
  Body Support 0.9. Existing nodes and cached baseline poses are not migrated;
  the separate unarmed seed remains unchanged.

No anatomy limits, grip solver, allocation search, drag speed settings or spine
isolation setting changed in this correction. Temporary spine isolation remains
on. No source skill was saved, reset or rewritten; no Git operation occurred.

Focused verifier: `tools/verify_skill_curve_pose_neutrality.gd`, extending the
original rendered circle audit. It compares all live bone transforms and the
weapon transform, all non-curve stored node fields, Tip release routing, changed
trajectory generation through F, source-library hashes and Body Support values.
It exercises the repeated blue incoming Tip cube on node 3, outgoing Tip and
incoming Pommel cubes on node 2, and numeric editing of all four curve fields.

Verifier corrections, not production faults: run1's quaternion acos metric
reported rotation for exactly identical transforms. It now measures the relative
quaternion; the 0.025-degree allowance was not widened. Run2's only failing check
included a background prepared-pose capture during an awaited pre-click
screenshot. All live transforms were unchanged. The final verifier takes its
strict baseline immediately before real LMB input and retains the earlier
capture in a separate `pre_input_capture` record. It still checks the actual
press, drag, release and subsequent frames without excluding prepared_pose.

### Fresh verification

Final Godot 4.7 rendered run: `godot_runs/curve_pose_fix_20261105/run3`,
`manifest.json`, `bone_trace.jsonl`, screenshots and adjacent `run3.log`.
Exit 0, 31/31 checks passed. Check-only parsing and scoped diff whitespace
checks also passed. Failed verifier runs 1 and 2 are retained with the causes
described above; production was not changed to suppress those test failures.

- Both node-3 blue-cube gestures, node-2 outgoing Tip/incoming Pommel gestures,
  and all four numeric curve edits recorded **zero** live bone/weapon position
  and rotation change. Non-curve stored fields, including prepared_pose, stayed
  equal from actual input through release/settling. Screenshot inspection agrees.
- Curve changes invalidated the runtime clip. F prepared in 1.527 seconds after
  editing, produced changed path samples in a 125-sample clip and completed.
  Initial F preparation was 1.779 seconds. These are fixture timings, not a
  general preparation speed claim; Save/equipped playback were not rerun.
- Both Tip directions retained their control identity through pending release,
  ended with `Motion node edit locked in.`, and matched the allocator's accepted
  world pose. No generic-release wrist_motion_range fallback occurred.
- Source library SHA256 stayed equal:
  `166bc47ca23a81b6310a30208c80c050c259ddc8ef99bb47fa023c22cec19450`.
  Skill 3 visible nodes remained 1.0 for Body Support; the hidden baseline
  remained 0.0. All edits were in the isolated fixture, with no skill Save.

Remaining limitation: unpolluted Tip CW/CCW tests still met constraints and used
reduced movement; CCW also exposed SEARCH_EXHAUSTED during the gesture. Largest
instrumented frame gaps were 620/674 ms. Curve release cost was about 0.85 seconds
and Tip release about 1.6 seconds. Detailed tracing and screenshots add overhead;
these numbers are not physical mouse-to-display latency measurements. The pose
leak and incorrect release route are fixed, but this is **not** a general stall,
one-direction restriction or anatomical correctness fix. The earlier read-only
Tip comparison started from a pose already changed by the curve bug, so its
ACCEPTED-only outcome is not an equivalent clean-baseline performance comparison.

Run closed normally; only the existing Godot editor remained open. Next useful
step is manual comparison on untouched Skill 3 at Body Support 1.0 and drag cap
900, then a separately bounded investigation of any remaining Tip-limit stalls.
