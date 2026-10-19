# Skill Crafter Body Mobility Preparation - 2026-10-19

## Scope And Latest User Direction

Preparation and investigation for more extensive player control over body/skill
composition. The initial investigation-only scope was superseded by the user's
later direction: obtain usable R-L-R results, then attempt a focused fix and
repeat that procedure. This is not authorization for unrelated body features,
wrist-limit changes or Git operations. The user explicitly permits engine
runs and asks to retain the diagnostic environment for future body-control work.
The user will handle token renewal; do not truncate necessary investigation on
the assumption that the session must stop imminently.

Investigate upstream shoulder/upper-arm/forearm behaviour before changing wrist
limits. The user's suggested reproduction is a normal, single-hand weapon thrust:
move the pommel along the weapon axis to large distances, then retract, preserving
the continuous pose history. Test both main hands, use skill slot 2 and a recent
real saved weapon with a usable handle. Vary elevation when useful. The user
permits modifications to test items; the harness nevertheless uses an isolated
copy because it costs little and makes the experiment repeatable.

Latest timing and order requirements: preserve one station/actor for R-L-R,
exclude the first R as warmup, and start the observation timer only after weapon
opening and starting-pose preparation. The current fixture waits at least ten
seconds after requesting acquisition, plus one continuous second of ready/idle
identity, before moving. Loading time does not count. The motion is extend once,
retract, hold, then move the actual elbow control; never extend again before
the elbow adjustment.

This updates the next-work order from the earlier hypothetical discussion, where
shoulder/wrist defects were assumed solved for design purposes only. It does not
turn that assumption into a claim that the defects were repaired.

Prior discussion, image and future directional-combat ideas remain in
[the full brainstorming note](<Skill Crafter Body Control And Directional Combat Brainstorm 2026-10-19.md>).

## Current Code And Ownership

Normal authoring order in `runtime/player/player_humanoid_rig.gd`:

1. Automatic torso/clavicle following.
2. Arm reach solve, optional arm-shape preference, endpoint reseat.
3. Authored elbow/upper-arm roll preference.
4. Shoulder pure-swing correction and elbow-angle correction.
5. Twist-helper distribution, wrist orientation and fingers.

Important current owners (line numbers are inspection anchors, not stable IDs):

- `player_humanoid_rig.gd:2024`: immediate preview update; 2164-2274: repeated
  contact passes and matching left/right sequence.
- `player_rig_upper_body_pose_presenter.gd:93,329`: automatic torso/clavicle
  rotation relative to cached baseline, direction weights and support blend.
- `player_humanoid_rig.gd:4320`: shoulder correction uses each side's rest frame,
  preserves shoulder-to-elbow direction and restores the forearm's world basis.
  The main upper-arm bone is intended to carry swing; helpers carry axial twist.
- `player_humanoid_rig.gd:3677,3792`: neutral-relative helper rotations; the zero
  request branch returns without restoring earlier helper rotations.
- `player_humanoid_rig.gd:4091,4270`: elbow-plane/radial fallback near straight
  or degenerate configurations. These helpers do not preserve a last-valid plane
  internally. This is an investigation lead, not proof of a visible defect.
- `player_humanoid_rig.gd:3634`: wrist contact twist clamp. Current default is
  0 degrees; zero means a real clamp in this function, not disabled limits.
- Native arm IK is disabled in direct authoring mode (4790); the runtime
  authoring modifier is disabled during preview (5397). Do not assume two active
  IK solvers are fighting without contrary evidence.
- `core/models/combat_animation_motion_node.gd`: weapon paths, timing, roll,
  grip, support blend, arm-roll preferences and free-hand proxies are already
  authored. There are no general independently keyed torso/head/pelvis channels.
- `player_humanoid_rig.gd:79`, `combat_animation_station_preview_presenter.gd:646`
  and `player_runtime_skill_playback_presenter.gd:373`: solved-pose capture/bake/
  replay. Current coverage is not a full head/neck/legs/feet animation contract.

## Fresh Initial Evidence

Evidence directory:
`C:/WORKSPACE/godot_runs/skill_crafter_body_prep_20261019_191525/`.

1. Unchanged `tools/verify_player_shoulder_swing_authority.gd` completed under
   Godot 4.7, exit 0, both sides passed. Seeded upper-arm roll correction preserved
   elbow/hand endpoints within 0.038 mm; maximum direction error was 0.019782
   degrees. The older report was copied before the run. This verifies a
   single-pose invariant, not extension continuity or visible skin quality.
2. `diagnose_twist_return.gd` in that directory reproduced the zero-return seam
   directly on both arms. After a 54-degree request, a resolved zero request left
   each forearm helper about 21.06 degrees and each upper-arm helper about 5.94
   degrees from its cached baseline. Debug state reported inactive/zero applied
   count. Repeating zero did not restore them. Negative-to-zero also retained
   rotation. Current wrist cap and straightness were not changed.
3. The same isolated runner exercised ordinary preview updates. Its fixed input
   basis did NOT produce a resolved zero anatomical request after the arm changed
   frame. Therefore that portion does not reproduce the direct zero-return bug
   end to end. Its synthetic target/anchor errors must not be reported as a
   diagnosed gameplay grip failure.

The helper defect is demonstrated in isolation. Its contribution to the user's
visible extension/retraction artifact still needs the applied-grip reproduction.

Two exploratory real-weapon sweeps were saved under `godot_runs/body_motion_20261019_192235`
and `body_motion_20261019_192545`. The first had an unsupported `%g` label format,
causing image filenames to collide; corrected in the second. Both collected
164 samples using Broken_Balde_v1, slot 2, both normal single hands and elevations
0/25 degrees, but started after fixed frame waits rather than proven grip
readiness. **Do not treat either as an applied-grip acceptance run.** Images show
open/separated hands; the bound and unbound wrist paths differ (rig 2327-2344).

Those exploratory measurements exposed a concrete signed-angle seam: left,
horizontal, steps 1 to 2 reported -172.55 to +177.53 degrees of requested twist.
Forearm share 0.78, clamped to +/-90 degrees per chain then divided between two
helpers, gives -45 to +45 degrees PER HELPER: a 90-degree jump from crossing a
roughly 10-degree wrap boundary. The scalar-to-helper mapping matches the
observations. It does not prove the same branch occurs with a settled grip.
Main upper-arm rest-relative axial roll remained essentially zero in those runs.

The corrected harness now gates movement on an applied, matching primary binding
and captures pose before authority evaluation, after it, and after preview
refresh. A generic seat `valid=true` is not sufficient: pending acquisition
returns that value too. Preserve failed exploratory runs as evidence of the
fixture correction rather than merging them into later passing results.

## Applied-Grip Sweep Results

Latest evidence: `C:/WORKSPACE/godot_runs/body_motion_20261019_193153/`.
Open [the interactive frame review](<../../godot_runs/body_motion_20261019_193153/review.html>)
for per-step telemetry and rendered frames. `analysis.json` retains the computed
comparisons; `samples.jsonl` and `manifest.json` are the raw capture.

The run completed 164 samples with `Broken_Balde_v1`, WIP
`player_wip_1792291462.519_14`, skill slot 2, both normal single hands. Initial
and post-setup acquisition were applied and bound in all four cases. Engine
stderr was empty. Capture completion is NOT four passed movement/grip tests.

| Case (requested elevation) | Actual setup elevation | Bound samples | Maximum accepted excursion |
| --- | ---: | ---: | ---: |
| Right, 0 degrees | -0.391 degrees | 41 / 41 | 0.364 m |
| Right, 25 degrees | -0.391 degrees | 41 / 41 | 0.403 m |
| Left, 0 degrees | -1.283 degrees | 0 / 41 | 0.446 m |
| Left, 25 degrees | 23.776 degrees | 2 / 41 | 0.484 m |

All cases requested a 1 m outward excursion followed by return. The right
25-degree setup was constrained back near horizontal: it is another sequence,
NOT demonstrated elevated-right coverage. The manifest records requested and
accepted axes, including a 25.404-degree setup error. Left starts bound before
motion but loses that relationship during the samples counted above.

### Right Arm: Narrower Continuity Finding, Not A Confirmed Candy-Wrapper Reproduction

Both right sequences retained the binding. Maximum adjacent world-hand changes
were 3.06 and 2.29 degrees. Main upper-arm rest-relative axial twist stayed below
0.000014 degrees. The extreme wrist/helper flips of the exploratory unbound run
did not recur in these applied-grip samples.

The elbow bend-plane normal changed by 133.28 degrees at horizontal outward
step 4 (elbow 164.60 -> 168.00 degrees), and 147.98 degrees at the second case's
return step 37 (168.00 -> 167.43 degrees). Those are NOT equal bone rotations:
the corresponding upper-arm / forearm / hand world changes were
8.67 / 17.22 / 1.35 degrees and 7.51 / 16.13 / 1.98 degrees. This supports a
near-extension bend-plane continuity investigation, not a claim that the arm
spun by 133-148 degrees or that the user's visible skin defect was reproduced.
Rendered right frames were inspected; the severe reported wrapping is not
established by this view and these paths.

### User Clarification After The Sweep: Inversion First, Corrective Twist Second

The user describes a two-stage failure: after full extension, bringing the
wrist/pommel back toward the shoulder makes the elbow bend in the inverse
direction WITHOUT an initial twist. Manually repositioning that inverted elbow
into the expected anatomical position then produces the candy-wrapper effect.
The arm's overall silhouette is corrected while the underlying reversed bend
is being contorted back into place. This is the user's observed sequence and
causal interpretation, not yet a separately instrumented reproduction.

This corrects the earlier investigative emphasis: absence of a large bone spin
in the uncorrected thrust does not refute the reported problem. The existing
fixture did not include the subsequent manual elbow-correction action. The
measured near-extension bend-plane changes are directly relevant leads.

Next reproduction priority: extend -> retract until inverse bending appears ->
perform the user's actual corrective manipulation, recording each stage. Identify
which authoring control performs that manipulation before scripting it; do not
assume it is weapon roll or directly overwrite bone transforms. Measure signed
flexion relative to the moving anatomical/rest joint frame, elbow side and helper
rotation, alongside world positions and skin appearance. An unsigned inner
angle alone cannot distinguish forward from reverse bending. A changing world
bend-plane normal is not itself proof of anatomical inversion either: ordinary
shoulder movement can rotate the whole plane.

Continuity alone is insufficient: it can preserve an already incorrect bend
solution. Inspect anatomical bend selection separately from how longitudinal
twist is redistributed while the manual correction retains wrist/grip constraints.

The intended outcome is a correctly directed elbow bend throughout extension
and retraction, without needing a corrective arm twist. Do not lock the elbow
plane to world space, restrict legitimate shoulder rotation, or widen wrist
limits to conceal the inversion. Left binding identity remains a separate
fixture/production-path issue to resolve for reliable left-side coverage.
No new runtime run or production change accompanied this clarification.

### Exact Three-Step Follow-Up Fixture

User clarification: "push, pull, keep position; adjust elbow position". Do NOT
extend again or reset the pose after pulling back. The correction uses the
existing elbow movement control point, which the current UI implements as the
Arm Roll gizmo.

`tools/diagnose_skill_crafter_elbow_correction.gd` reuses the retained real-item
setup but performs this distinct sequence once per hand: extend with the pommel
to the current reach limit; pull from the accepted position toward the shoulder;
release and retain the retracted pose; then drag the actual elbow gizmo. Its
target is the initial applied-grip elbow side projected around the current
shoulder-hand line, a diagnostic reference rather than a universal anatomical
definition. No direct bone writes or second extension are used.

The elbow drag goes through `begin_upperarm_roll_drag`, `_handle_preview_drag`
and the production pointer-ray resolver. Captures include before/after mouse
release, requested and realized elbow directions, authored roll, endpoint drift,
binding readiness and rendered skin. The initial controls are unchanged.
Run with the same real-item arguments but `--elevations=0`; elevation changes
are not part of this three-step fixture. The offline analyzer accepts its
explicit sample count and shows the named phases.

### Three-Step Results: Elbow-Control Discontinuity Reproduced

Latest [three-step review](<../../godot_runs/elbow_correction_20261019_201302/review.html>),
`godot_runs/elbow_correction_20261019_201302/`: 66 samples, 33 per side,
Broken_Balde_v1, slot 2, normal single hands. No second extension or reset after
pulling back. The fixture source used is retained in the evidence directory.

The initial forward pose was configured before starting acquisition, then gated
on applied readiness. User clarification: ordinary grip solving takes about
7-10 seconds; sub-4-second completion should not be assumed. The readiness gate
allows 90 seconds and waits for actual completion, not a short fixed delay.

**Left: all 33 samples remain applied/bound.** Maximum extension reaches the
168-degree cap; retraction reaches about 87.71 degrees before mouse release and
89.67 degrees after it. The elbow correction and release are accepted by the
current UI, but do not restore the intended elbow side correctly.

At correction start, stored roll is 0 degrees while the actual elbow radial is
-114.381 degrees from the rig's angular reference. The pointer requests a
-118.752-degree arc to restore the original elbow side. The first input is
-9.896 degrees at sample 20; the first visible pose update is sample 21, after
the next pointer event, because preview refresh is deferred. That update jumps
the elbow plane by 104.506 degrees, upper arm by 59.789 degrees in world space,
forearm by 104.265 degrees in world space / 92.964 locally, and each forearm
twist helper by 70.423 degrees locally. This reproduces a bound-arm correction
discontinuity. Do not claim a one-event synchronous mapping from sample 20's
input to sample 21's pose.

Authored pommel AND tip remain exactly fixed in all 12 correction samples. The
rendered resolved pommel nevertheless moves about 14.5 mm at the first jump and
23.5 mm by final release as the refreshed hand recomposes the held weapon.
Release reports `Motion node edit locked in.` and retains roll -118.752 degrees;
the elbow radial ends about 114.37 degrees away from the requested initial side.
The production control was exercised; its desired correction did not succeed.

**Right:** setup is ready, but the first extension sample loses binding and the
sequence reaches terminal `source_pose_changed_during_acquisition`. Only 1/33
samples are ready. Its later renders cannot establish a retained-grip right-arm
reproduction. This is a failed state, not a 4-second wait timeout. The precise
cause of this run's invalidation remains to isolate; earlier station-key jitter
is a lead, not automatically proof for every invalidation.

The earlier `elbow_correction_20261019_200904` used the lowered reset pose and is
exploratory. It exposed rejected/reverted edits and is not equivalent to the
forward scenario. `elbow_correction_20261019_201053` failed neutral-pose setup
before any samples; the fixture was corrected to acquire only after final setup.
Both runs are retained with their limitations. Latest stderr is empty; saved
library hashes match, and all diagnostic processes ended. Existing editor stays
open. No production solver or limit changed.

### Concrete Code Findings For The Next Correction Slice

1. **Unsigned elbow acceptance:** `player_humanoid_rig.gd:4098-4120` uses an
   unsigned angle and maximum only, preserving the current cross-product side.
   It does not reject an anatomically reversed bend merely because it is reversed.
   The direct CCD path at 4065-4088 has no stable elbow-pole selection. Native IK's
   separate pole is not active in this authoring path. Near-extension branch
   ambiguity is therefore a specific code concern, not a wrist-limit argument.
2. **Control/reference disagreement:** `combat_animation_motion_node_editor.gd:361-385`
   returns stored roll plus pointer delta from the CURRENT elbow radial.
   `player_humanoid_rig.gd:4278-4304` skips correction at zero, then interprets
   any nonzero value as an ABSOLUTE angle against its own projected side reference.
   The live bound-left jump above is consistent with this mismatch. A small
   pointer movement need not produce a small elbow movement.
3. **Orientation compensation after placement:** manual roll is followed by
   shoulder pure-swing cleanup, which restores the prior forearm global basis
   through a changed local basis (4341-4405). That preserves endpoints, not signed
   anatomical bend validity. Its contribution to visible skin wrapping needs
   separate before/after-pass instrumentation; do not claim it alone is proved.
4. **Release is a separate authority boundary:** UI 6168-6176 can reject an edit
   and restore the prior node. Even an elbow-only drag is seeded from the DISPLAY
   frame, which may differ from stored endpoints; endpoint legality can therefore
   run at release. The latest left release was accepted; some earlier lowered-arm
   releases were rejected. Keep those outcomes separate.

Recommended next implementation order: establish anatomically valid elbow-side
selection through extension/retraction, unify the elbow control's angle reference
with the rig (including zero), then inspect remaining twist compensation and
binding invalidation. Do not widen wrist caps or merely smooth the wrong bend.
This is a proposed correction scope, not production work performed this session.

### Left Arm: Binding Identity Jitter During Rigid Motion

Left horizontal loses readiness on step 0; the raised case loses it on step 2.
Only byte 144 of the 292-byte serialized relationship identity changes: station
X goes from 0.1179542988538742 m to 0.11795440316200256 m, then back. That is
0.104308 micrometres, about one `SEAT_IDENTITY_GRID_M = 1e-7` cell. Other key
bytes, station Y/Z and intended handle percentage are unchanged. Readiness loss
and new acquisition serials coincide with these transitions, ending in
`source_pose_changed_during_acquisition`. Right station X stays constant.

This demonstrates a relationship-key churn problem in this fixture. The precise
producer of the rounding change still needs isolation. Inspect
`combat_animation_station_preview_presenter.gd:4946,5436,5472,5499,5548`
(grip refresh, bounds, station clamp, world-basis length, slice interpolation)
and `runtime/player/grip/preview_grip_acquisition.gd:241,260,937,945`
(identity comparison, claim and quantization). Do not simply widen a tolerance
until the intended identity contract is understood. The later large left flips
belong to the unbound path; they are not settled-grip motion results.

Across all samples, authority evaluation changed bone rotation only by numerical
noise (at most 0.0000035 degrees); meaningful changes appeared during preview
refresh. Applied/bound is also distinct from full contact certification: setup
reports sampled material safety and palm contact, but no sections at maximum
depth and unresolved digit contact targets. No grip success claim is inferred.

The preceding readiness-gated attempt, `body_motion_20261019_193003`, stopped
before motion because reset/selection obsoleted an asynchronous acquisition.
The harness now retries that specific stale SETUP failure once after setup stops;
it never silently retries readiness loss during the measured sweep.

Original saved-library SHA256 was unchanged after the run. All diagnostic
processes ended; the existing editor remained open. No production source,
joint caps, authored controls, save/replay logic or Git index/history changed.
The harness clears its drag override after collection: it does not test a saved
edit, end-drag commit, F replay or equipped gameplay playback.

## Reusable Real-Item Diagnostic

Script:
`The Will- main folder/the-will-gamefiles/tools/diagnose_skill_crafter_body_motion.gd`.
It reuses scene lookup and fixture helper code from the older arm-extension
diagnostic, while overriding its execution entrypoint. The older slot-1 scenario
does not execute. This is diagnostic infrastructure, not a production controller.

Inputs after Godot's `--` separator:

- `--weapon=Broken_Balde_v1`: exact saved project name or WIP ID. Without this,
  choose the newest-created baked Forge V2 item; runtime setup must still prove
  it is usable. The selection is not a generic handle-validity certificate.
- `--slot=skill_slot_2`, `--hands=R,L`.
- `--elevations=0,25`: degrees relative to character forward, which is local +Z.
  These are setup requests; inspect accepted axes before claiming angle coverage.
- `--steps=20`: sample count on each outward/back leg.
- `--travel=1.0`: requested axial excursion in metres; normal constraints remain
  active, so accepted travel may be shorter.
- `--out=C:/WORKSPACE/godot_runs/<fresh-name>`: use a fresh evidence directory.

Example (PowerShell):

```powershell
& 'C:\WORKSPACE\Godot_v4.7\Godot_v4.7-stable_win64_console.exe' `
  --path 'C:\WORKSPACE\The Will- main folder\the-will-gamefiles' `
  --script res://tools/diagnose_skill_crafter_body_motion.gd `
  --resolution 1280x900 --max-fps 30 -- `
  --weapon=Broken_Balde_v1 --slot=skill_slot_2 --hands=R,L `
  --elevations=0,25 --steps=20 --travel=1.0 `
  --out=C:/WORKSPACE/godot_runs/body_motion_new_run
```

Only one substantial Godot run at a time; the editor may remain open. The
rendered run records PNGs; `--headless` produces metrics without screenshots.
The script uses the real saved mesh/rig and station APIs. It gives each side an
isolated library path, disables station persistence and resets only between
independent cases, preserving pose history within each outward/back sequence.
Before movement it polls the existing read-only `_primary_ready_for_support()`
predicate plus `has_grip_pose` after reset and after setup. Despite that predicate's
name, it checks dominant-hand acquisition, the primary-seat key and live binding;
it is relevant for one-handed work too. Terminal failure or timeout stops the
scenario. This proves the sampled acquisition was applied, not exhaustive visual
or physical certification of every finger contact. Current V6 intentionally
leaves the separate `grip_accepted`/`actual_3d_grip_verified` flags false.

Pommel targets use the actual mouse-drag queue and contact-tether authority.
Rejected targets remain rejected; they do not count as achieved motion. The
fixed sweep direction comes from the accepted display weapon axis after setup,
so constraints cannot silently redirect subsequent requested samples.

Outputs: `manifest.json`, incremental `samples.jsonl`, rendered PNGs, and engine
logs supplied by the launcher. A completed run means data collection completed,
not that the movement or grip passed acceptance. Preserve incomplete runs too.

Offline review generator (Python standard library, no Godot launch):

```powershell
python -B 'C:\WORKSPACE\The Will- main folder\the-will-gamefiles\tools\analyze_skill_crafter_body_motion.py' `
  'C:\WORKSPACE\godot_runs\body_motion_20261019_193153'
```

It writes `analysis.json` and `review.html` alongside the preserved raw files.
Keep both diagnostic tools and this usage note for later torso/head/hip work.

Telemetry includes spine/clavicle/upper-arm/forearm/hand/helper quaternions,
elbow angle and bend plane, reach, requested and accepted pommel positions,
constraint results, acquisition/binding readiness and existing grip debug data.
Snapshots before/after target authority and after preview refresh separate
candidate evaluation side effects from subsequent pose updates. Local-Y twist values are
diagnostic decompositions, not anatomical-range certifications. Comparing two
different swings can itself yield a twist component: use rest-relative upper-arm
measurements and raw transforms, not only baseline-relative numbers or Euler
angle differences. A 25-degree adjacent-sample flag only requests a screenshot;
it is not an approved motion limit.

## R-L-R Follow-Up And Authorized Fix Attempt

The user authorized a focused correction after usable R-L-R evidence. First R
is warmup; compare L and the second R. Use one station/actor, the actual weapon
hand-setup path and the actual Space focus path. An earlier diagnostic called
selection-only refresh, which did not rebuild the elbow gizmo. That fixture
defect is fixed; shortened later passes are explicitly incomplete, not passes.

Fresh complete pre-change reference:
`godot_runs/elbow_rlr_focus_20261019_203223` (99 samples). The same station and
actor survive all passes. Each starting pose gets ten seconds after acquisition
is requested; opening/loading time is recorded separately. L retains its applied
binding for 33/33 samples; second R retains it only for 1/33. This is not a claim
of complete physical/visual finger-contact certification.

Confirmed causes and narrow changes:

1. Elbow gizmo started from the visible elbow radial but added drag angle to the
   saved roll value (usually automatic zero). The rig interprets roll as an
   absolute angle in its actor-relative reference. Fresh L evidence: about
   10.55 degrees of pointer movement caused a 101.50-degree bend-plane jump.
   The rig now exposes a read-only measurement in that exact reference, and the
   presenter uses it as the drag's starting angle. Existing zero-auto semantics
   and saved-data formats remain unchanged.
2. Primary unbound placement projected onto Handle end bounds using the SUPPORT
   hand's width. The model's unequal widths caused a 3.8-micrometre right station
   change at first movement, discarded its binding and started a solve that then
   became stale. The shared projection now requires an explicit hand slot; both
   callers supply the hand actually being placed. No overlap or identity-grid
   tolerance was widened.
3. Once the side mismatch was removed, rotated float32 world-length noise could
   still cross the existing station identity grid. End-bound length now caches
   by span vector and physical scale metric B-transpose times B. Genuine scale
   changes, nonuniform parent scale and relative item rotation invalidate it.
   Relative metric comparison also preserves genuine miniature-scale changes.
4. Review found rear-facing/off-centre sphere picks could count as movement even
   at the same pixel. Input now calibrates from the actual press position and
   follows the sphere intersection nearest the grabbed/previous radial. The UI
   and diagnostic supply the real press ray. Oblique/rear-view tests cover
   unchanged presses, small motion, return to press and positive angular motion.

First integrated attempt: `godot_runs/elbow_rlr_fixed_20261019_203951`.
L remained applied for 33/33 samples and the largest manual bend-plane step fell
from 101.50 to 10.56 degrees, matching the approximately 10.55-degree pointer
steps. Authored Tip/Pommel drift during the drag was zero. Second R improved from
1 to 3 ready samples, then exposed the float-length identity issue above. This
run predates the metric-cache and final pointer-calibration changes and is not
their verification.

Focused checks so far: 48 control-reference checks, existing shoulder-swing and
upper-body verifiers passed in `godot_runs/upperarm_roll_verify_20261019_203822`;
the first verifier-only parse failure was fixed before the successful run.
Hand-slot/end-bound contract passed in
`godot_runs/hand_projection_verify_20261019_203935`.

### Final verification with all corrections

- `godot_runs/upperarm_roll_press_20261019_2048/final_result.json`: 96/96
  control/input checks passed, exit 0, empty stderr. Earlier test attempts caught
  a 64x64 headless viewport assumption and sphere-silhouette precision; those
  attempts remain preserved. The final fixture uses 1280x720.
- `godot_runs/hand_projection_final_20261019_204714`: expanded end-bound contract
  PASS, empty stderr. Covers both queried hands/dominance/endcaps, exact station
  stability during rigid rotations, changed geometry, real item/parent scale,
  child rotation under nonuniform parent scale, and miniature relative scaling.
- `godot_runs/elbow_rlr_final_20261019_204728`: complete 99 samples, empty stderr,
  actual saved Broken_Balde_v1, skill_slot_2, normal single hand, same station and
  actor. First R is excluded as warmup. All three passes retained applied binding
  for 33/33 samples. L and second R releases both report `Motion node edit locked
  in`. Ten-second observation begins AFTER pose setup/acquisition request:
  10017/10017/10018 ms; total open-to-settled time was about 33.8/32.6/32.5 seconds.

| Final compared passes | Left | Second right |
| --- | ---: | ---: |
| Ready samples | 33/33 | 33/33 |
| First pointer delta | -11.135 degrees | +7.746 degrees |
| First observed elbow-plane delta | 11.138 degrees | 7.735 degrees |
| Maximum manual elbow-plane step | 11.143 degrees | 7.759 degrees |
| Requested / achieved total radial arc | -133.623 / -133.500 degrees | +92.957 / +92.409 degrees |
| Final desired-direction error | 4.061 degrees | 2.625 degrees |
| Final / maximum rendered pommel movement from held pose | 7.23 / 22.80 mm | 22.24 / 26.64 mm |

Authored Tip/Pommel drift during correction is zero for both. Rendered endpoint
movement above is a remaining limitation; do not equate authored immutability
with a fixed world-space weapon. Baseline left's first correction jump was
101.498 degrees. Baseline second right was unbound after its first sample, so
its older 143-degree jump is not a matched bound-grip comparison.

Actual R2 held/released renders were inspected. The manual movement follows its
intended direction; automatic extension-to-held retraction still changes the
plane by 175.29 degrees left / 165.68 degrees right. These are directional
measurements, not an anatomical validity certificate.

Source saved-library SHA256 remained
`45F9B68F80BC8B4BAEAD920B12211967E70243EDC079DC8FC0590C5E39939558`.
Only the existing editor process remained after the diagnostic. No index,
branch, commit or push operations were performed. Retain fixture scripts,
raw samples, source snapshots and the offline HTML review for subsequent work.

Automatic inverse bending remains a distinct question: the current maximum
elbow-angle check is unsigned. No signed anatomical hinge rule, wrist-cap change,
new world-space elbow pole or torso-control feature is introduced by these fixes.
Rest-frame hinge constraints require care because the UpperarmTwist bones are
deformation siblings, not parents of the Forearm; a fixed hinge can conflict with
the existing pure-swing shoulder and manual elbow orbit. Do not silently impose
that larger policy based only on an unsigned angle or a world-side label.

## Bounded Implementation Order After Investigation

1. Establish the stage that first introduces the reproduced rotation/mesh defect.
   Compare outward/back poses, repeated targets, both arms and the near-straight
   bend plane. Distinguish reach rejection, continuity, residual helper rotation,
   reference-frame error and skin deformation. Fix only demonstrated causes in
   an authorized implementation slice. The confirmed reference/identity fixes
   above are now implemented and verified in this slice; anatomical bend policy
   remains open.
2. Recommend torso turn, forward/back lean and side lean as the first artistic
   controls. Define whether these are offsets from automatic following and how
   that automatic layer must respect authored choices. Reuse existing arm-roll/
   elbow-preference concepts rather than adding a competing elbow system.
3. Add head direction and hip twist in bounded increments. Head channels require
   corresponding capture/replay coverage. Hip twist requires a deliberate stance
   policy; it does not automatically authorize feet IK, stepping or root motion.
4. Define what torso POSITION means before adding translation: lean above fixed
   hips, pelvis shift or whole-character travel are different operations.
5. Reassess wrist limits after upstream motion is trustworthy. Distinguish weapon
   roll authoring limits, contact orientation policy and anatomical wrist range.
6. For each new control, complete authored data, interpolation, save/load and
   solved F/equipped replay together. Neutral defaults preserve older skills;
   switching UI complexity must not erase authored advanced values.

NEEDS_DECISION before implementing artistic controls:

- Should torso edits hold the authored weapon fixed while the body adapts?
  Recommended here, but not yet an explicit final user rule.
- If a body edit makes a grip unreachable, clamp the edit, keep the last valid
  pose, or display an invalid authoring pose? Never silently choose a policy.
- Torso position reference/anchors; pelvis and feet ownership; head direction's
  reference frame; actual per-control ranges and interpolation.
- Ground front-direction arrow versus the earlier optional 80%-range target.

Keep damage classification, projectiles, a general bone/graph editor and broader
combat mechanics out of this implementation slice.

## Technical References

- [Godot 4.7 SkeletonModifier3D](https://docs.godotengine.org/en/4.7/classes/class_skeletonmodifier3d.html): modifier ordering and final-pose observation.
- [Godot 4.7 Skeleton3D](https://docs.godotengine.org/en/4.7/classes/class_skeleton3d.html): bone global pose is skeleton-relative; convert deliberately to world space.
- [Godot 4.7 Viewport](https://docs.godotengine.org/en/4.7/classes/class_viewport.html): capture rendered viewport textures after rendering.
- [Godot 4.7 command line](https://docs.godotengine.org/en/4.7/tutorials/editor/command_line_tutorial.html): scripted diagnostic launch and user arguments.
