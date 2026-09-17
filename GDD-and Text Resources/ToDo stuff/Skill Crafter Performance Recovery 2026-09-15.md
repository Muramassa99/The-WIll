# Skill Crafter performance recovery — 2026-09-15, chat 14

## Scope and current state

User wants function and performance together. Preserve the accepted wrist–Tip
Roll. Recover useful earlier performance work without importing the discarded
Roll/support-hand redesign. F generation and saving remain a later stage.

Working branch: `recovery/stable-92b8a24-chat14`, HEAD
`92b8a24fcac64e38c2565e56fec6878e22e55e26`. Preserved source material:
`godot-4.7-plus-development` at `d798cc016ba8c150c6b7ca263f3da608a7455a7f`.
No commit or push for this work. Dedicated RTX 2070 SUPER is available again.

`SPS_2026_09_01_07-04.md` records Skill Crafter performance work that was still
uncommitted above 92b8a24. Consequently rollback removed that work despite the
nearby September 1 push. Forge live-stroke performance work already exists in
92b8a24. Historical SPS performance passes do not establish current contact
correctness; that SPS explicitly records a failed synthetic grip fixture.

## Implemented slice

`runtime/combat/combat_animation_station_ui.gd` reuses station preparation only
within a synchronous authoring call. It also resolves draft/index once where
repeated reads previously repeated expensive preparation. Cached references clear
when the outer call returns. Selection and motion data remain live; explicit
post-edit normalization remains. No solve, collision check, debug function,
grip behavior, F path or save path was disabled or replaced.

This adapts the earlier lookup reuse instead of restoring its whole UI file.
Experimental committed-seat getters were removed after investigation showed
that no safe current consumer had been established.

## Current measurements

These are synchronous action timings, not rendered FPS or manual acceptance.
The diagnostic opens a deep copy of the real `Star_Handle_Testing` library entry,
redirects test persistence, and presses/drags/releases actual viewport controls.
Only the test disables automatic UI processing and explicitly flushes the actual
pending drag refresh, allowing input work and refresh work to be measured once.

| Work | Before UI change | After UI change |
| --- | --- | --- |
| Roll input, four samples | 184–209 ms | 28–33 ms |
| Tip input, excluding refresh | about 25 ms | about 1.4–1.9 ms |
| Pommel input, excluding refresh | about 12–13 ms | about 0.4–0.5 ms |
| Tip/Pommel pose refresh | substantial contact-solver stalls | still unresolved |

Baseline log: `godot_runs/the_will_2026-09-15_01-40-19.log`.
After UI change: `godot_runs/the_will_2026-09-15_01-47-23.log`.
All 15 stored action/release weapon and complete bone-pose snapshots in the
corresponding JSON artifacts compare exactly, including serialized floats.
The existing 114 Roll regression checks passed after the UI change:
`godot_runs/the_will_2026-09-15_01-50-03.log`.
The expanded verifier then passed 204 checks with no failures, including
lookup-scope cleanup after accepted, unchanged and rejected inputs and releases,
and edits in a second draft preserving the first draft. Both hands were tested.
Log: `godot_runs/the_will_2026-09-15_02-03-59.log`. Existing wrist–Tip Roll
invariants still pass; this does not certify initial grip acquisition.

Expanded timing log: `godot_runs/the_will_2026-09-15_01-59-48.log`.
Tip refresh takes 8,227 ms on its first sampled move (7,722 ms in digit settling),
then 726–792 ms. Pommel refresh takes 657–939 ms. Seven of eight sampled
Tip/Pommel seat results report `radial_tolerance_not_reached`.
The seat solver's own timed work is about 343–660 ms on those failures;
the remaining seat-call work is about 200–272 ms. That remainder includes
preparation and surrounding work; it is not a separately measured preparation
duration. Drawing is small in these samples. Geometry caching alone does not
resolve the dominant repeated-solving problem.

## Contact reuse finding — not fixed or disguised

User's intended boundary: fresh grip solving for Handle-position changes,
reacquisition, support engagement/reposition; retain the hand–weapon relationship
during ordinary manipulation.

The copied saved setup initially has a valid weapon-seat result but an invalid
finger result: `surface_solve_rejected`, `unsafe_no_verified_fallback`, and no
committed 15-rotation packet. A visual hand pose is not proof of a validated grip.

The bounded probe `tools/diagnose_committed_grip_recovery.gd` applies small
transforms to the displayed weapon, invokes existing macro guidance, and attempts
existing committed-digit restoration. Restoration returns false. Hand-in-weapon
position changes by about 49–51 mm. This probe does not implement the full old
seat algorithm, and its successful process exit is not a contact-verification pass.
Evidence: `godot_runs/the_will_2026-09-15_01-51-22.log`; expanded packet inspection
in `godot_runs/the_will_2026-09-15_01-57-36.log`. Tool output was subsequently
reduced to compact packet summaries to avoid dumping full solver diagnostics.

Current flow reconstructs a nominal target/basis from PrimaryGripAnchor and
current anatomy; exact seating then moves the weapon after macro IK. The old
cached correction is relative to a fresh unseated weapon frame. It is not the
actual solved Hand-in-weapon relationship. Applying it to displayed endpoints
risks applying seating twice. Restoring digits alone does not fix this mismatch.

Correct retention needs the actual accepted Hand-in-weapon relationship routed
through existing arm target, wrist restrictions and legality, with explicit
relationship-change invalidation. Do not import the discarded axial Roll layer,
provisional support transactions, hidden-debug early returns, or blanket
lightweight-drag legality bypasses to obtain a timing pass.

The user clarified the decision: correct acquisition first. Grip must adapt to
valid player-built Handle geometry and work predictably across input angles,
positions, posture and Roll. A rejected displayed pose is not an acceptable
substitute. The player should be composing an attack, not repairing IK or fingers.
This is an end-to-end quality requirement; it does not authorize silently widening
the present work into the later F/save integration or unrelated game systems.

## Acquisition investigation and backup comparison

The actual copied right-hand startup rejects three digits: Middle, Ring and Pinky.
Their open proximal capsules overlap the Handle by approximately 1.77, 2.00 and
2.99 mm against the ordinary 0.5 mm limit. Index and Thumb are constrained but safe.
The accepted seat tests spheres at Index1/Pinky1; the digit solver tests the full
bone1-to-bone2 capsules. Right Pinky therefore passes the seat's point test at about
0.04 mm while its full proximal capsule fails at about 2.99 mm. Captured right-hand
anatomy is unchanged across the seat handoff; this is not evidence of an intervening
Hand-bone write. See the 03-03-42 log and 03-04-17 acquisition JSON.

Diagnostic-only experiments, not production changes:

- Enabling the existing full-proximal check for Primary makes the right seat reject;
  it does not produce a valid acquisition (03-05-06 log / 03-05-38 JSON).
- Sampling ordinary proximal closure at 10-degree intervals from 0 to 130 degrees
  finds no safe right Middle/Ring/Pinky pose in that starting relationship
  (03-07-19 log / 03-07-54 JSON). This is a sampled result, not an exhaustive proof.
  The old tool retained right-hand sweep metadata in the subsequent left row:
  **do not use that left-row sweep as left-hand evidence.** The tool now resets and
  tags sweep state per solve/slot, deep-copies rows, and makes the sweep opt-in.

User requested a parallel comparison with the preserved last push before inventing
replacement work. Findings from `92b8a24` versus `d798cc0` and current dirty code:

| Component | Result |
| --- | --- |
| Digit hinge rules, finger surface solver, capsule surface query | Identical across all three; no lost range/axis/contact algorithm here. |
| Finger 130-degree ranges, matching neutral/zero debug, thumb exceptions | Already included in the restored history. |
| Hand seat anatomy, including closing directions and ordinary proximal capsules | Whole producer identical between both commits. |
| Current-skeleton hand-item-anchor reader and conversions | Lost in rollback; a separable candidate for recovery. |
| Primary full-proximal safety switch | Backup enables it but also disables it for Support; not a demonstrated fix. |
| Seat provisional candidates | Backup adds retention/ranking for larger acquisition transactions; accepted geometry remains unchanged. |
| Grip reuse | Cached weapon-seat correction is not the accepted full Hand-in-weapon transform. |

The backup's final seat packet can even contain an identity residual after earlier
corrections have been applied to the live weapon. Reapplying that packet to a newly
constructed unseated weapon does not reconstruct the accepted relationship. Its
old Roll writer also resets twist and translates Hand; it is unsuitable for the
accepted wrist–Tip Roll. No whole-file restore or bulk cherry-pick is warranted.

The actual startup diagnostic confirms stale attachment reads at mount calls:
right-hand samples differ from current-bone composition by up to about 49 mm / 22
degrees; hand switching exposes about 387 mm / 19 degrees on the left. These are
attachment-frame differences during setup, not measured final grip errors.
Baseline: `godot_runs/the_will_2026-09-15_03-18-03.log` and
`test_artifacts/grip_acquisition_2026-09-15T03-18-38.json`.

The isolated editor-only anchor recovery was implemented and tested, then **removed
from active production code and preserved as a candidate patch**:
`Skill Crafter Hand Anchor Recovery Candidate 2026-09-15.patch` in this folder.
It contains the full source change, coordinate documentation and its dedicated
verifier. It applies cleanly to the current working version (`git apply --check`
passed). Do not apply it as a standalone performance fix.

The candidate reads the current Hand frame, composes the authored item-anchor
offset, registers the full Anchor -> Wrist -> RL_BoneRoot chain and uses that frame
for mounting and matching alignment conversions. Its contact-point definition is
unchanged. The final verifier passed 161 checks, including both hands, deliberately
stale attachments, transformed/scaled presentation, actual presenter consumers,
invalid-frame rejection and no pose writes:
`godot_runs/the_will_2026-09-15_03-30-38.log`.

An intermediate candidate missed the presenter offset-to-world consumer and lost
the prior left digit packet. That incomplete chain was corrected before the final
candidate was preserved. The complete candidate's copied acquisition run
(`03-26-34` log / `03-27-12` JSON) again reports the prior outcome categories:
right seat accepted but three unsafe digits; left final seat rejected while an
earlier safe digit packet remains. That left packet alone does not verify the
current full seat/grip relationship.

The decisive integration limitation is performance, not the coordinate regression
test. In `godot_runs/the_will_2026-09-15_03-28-49.log` and
`test_artifacts/skill_crafter_latency_2026-09-15T03-29-53.json`, the candidate makes
additional Pommel samples reach digit solving. The first Pommel refresh takes
7,921 ms (7,359 ms in digits), and another takes 2,445 ms. Before this candidate,
the corresponding sampled Pommel refreshes were 657–939 ms. Roll stays around
30–32 ms. A more accurate anchor that exposes more expensive acquisition attempts
is useful source material, but is not ready for independent integration into this
already difficult-to-test working version.

Only this candidate's production edits were reversed. Active source retains the
accepted wrist–Tip Roll, origin documentation and the earlier synchronous UI lookup
improvement. The active tracked diff is again the same seven files / 370 additions /
22 deletions as before this anchor experiment. No solver, hinge/range, Support,
F/save, or runtime behavior was imported from d798. The user library hash remains
`C59A09D3B33D321F482F2C379DF5FD299246544F2229E5A8B12970F769500E0E`.
After removing the candidate, the active Roll/UI regression verifier passed all
204 checks again: `godot_runs/the_will_2026-09-15_03-32-43.log`. This verifies the
restored manipulation slice, not initial grip or completed performance recovery.

Next acquisition work must reconcile seat acceptance with the full proximal finger
volumes while respecting the established Index/Pinky seating authority, chosen
Handle coordinate and joint ranges. The stricter existing gate and backup's large
transaction layer do not supply that correction by themselves. After a valid grip
exists, retain its actual full Hand-in-weapon frame and accepted finger rotations
during ordinary manipulation; a cached residual seat correction is insufficient.

## Coordinated closure investigation and the user's 2D direction

The user proposed coordinated tendon-like closure, invited investigation of wider
joint limits, and requested official Godot references. These were investigated in
offline diagnostics; no production finger solver or joint range was changed.

The extended proximal sweep (`03-58-06` log) sampled -45 through 180 degrees.
Extra opening could clear Pinky but could not clear Middle/Ring. The stronger
fixed-base test (`04-00-51` log) found their bone1-centered spheres already overlap
the Handle by 1.770 and 1.984 mm. Those sphere centers cannot move through finger
hinges. Finger-angle changes alone therefore cannot make this seated relationship
pass the ordinary 0.5 mm overlap cap.

The parked `probe_coordinated_digit_closure.gd` is a bounded diagnostic search,
not a production replacement. Its default run (`04-04-16`) did not obtain a full
ordinary grip. An offline relative translation perpendicular to Tip-Pommel of
about 1.505 mm (`04-05-12`) cleared the four fixed bases, but subsequent closure
still produced only partial contact; Pinky also needed extra opening. This neither
accepts a new palm placement rule nor establishes a safe complete grip. Thumb was
not implemented in that prototype. Do not resume additional DLS changes merely
because this tool exists.

The user then redirected the investigation: slice the actual Handle in each
finger/thumb motion plane, use real hand dimensions and solve the smaller 2D
problem; include the palm and account for deposited profile orientation. The
intentionally difficult saved Star Handle remains the baseline. Its geometry
must not be simplified to manufacture acceptance.

Saved-profile findings:

- The real tool profile library contains eight Handle profiles. `Star complex`
  (`handle_profile_1787633048.01_9`) matches all 48 vertices in the current
  `Star_Handle_Testing` Handle exactly. Its rounded polygon is 32.48868 mm square;
  stored width/height metadata says 50 mm square. Use the actual polygon.
- The editor's 75 mm envelope bounds control points, not every final rounded
  outline. Saved `odd shape 2` actually spans 72.408598 by 82.976620 mm.
- Profile coordinates are anchor-relative. Contact alignment, path tangent,
  rotation bias, curved deposition and the explicit CSG X handedness bridge are
  applied later. A raw saved polygon is not automatically a finger-plane section.
- Exact Handle baking excludes the Forge bench's display scale. The runtime
  prepared Handle triangles already carry the actual world transform. Slice those
  triangles without reapplying width metadata, bench scale or profile rotation.
- `PrimaryGripSeatResolver.resolve_mesh_plane_slice_center` already accepts an
  arbitrary plane and builds/welds intersection contours. Its public result keeps
  center/area information but discards the polygons. Diagnostic contour extraction
  can reuse its lower-level helpers without changing production behavior.

Coplanarity must be measured, not inferred from three local `+Z` hinge labels.
The existing thumb collinear preparation does not prove world-plane agreement.
Measure actual joint/tip depths and hinge-plane normals at zero and angle limits.
The 2D drawing uses measured world bone lengths and the existing stored skin-radius
calibration; it is not a new measurement of the complete skinned hand surface.

The acquisition diagnostic now also captures the numerical RL_BoneRoot-to-world
frame at the actual finger-solve input, and preserves the terminal offset's source
bone ID. Fresh coherent inputs are `grip_solver_inputs_hand_right_2026-09-15T04-13-17.bin`
and `grip_solver_inputs_hand_left_2026-09-15T04-13-27.bin` in test_artifacts.
The final observed weapon frame is separate metadata and must not be substituted
for the earlier solve's surface pose. Both hands here are separate primary-hand
acquisitions, not an accepted simultaneous two-handed grip.

Palm scope finding: the current seat anatomy supplies Index/Pinky contact points,
closing directions and optional proximal finger capsules. It has no palm skin
patch, thickness or palm collision volume. `_build_palm_frame` is a derived bone
frame, not a surface-contact proof. A full grip needs this shared placement and
clearance question resolved along with the five digit candidates; ten independent
2D successes would not by themselves certify both whole hands.

### Measured plane results and model-preparation clarification

The offline exporter `tools/diagnose_digit_motion_slices.gd` ran successfully on
both fresh captures: logs `04-17-43` and `04-18-01`, corresponding JSON files
`digit_motion_slices_2026-09-15T04-17-43.json` and `...04-18-01.json`.
Each input has 8,540 exact Handle triangles. Every raw digit and both prepared
thumbs produced one closed contour, with no coplanar-face ambiguity. These are
separate hand setups, not simultaneous support-hand acquisition.

| Chain | Right max sampled departure from plane | Left max sampled departure |
| --- | --- | --- |
| Index | 3.095 mm | 2.966 mm |
| Middle | 1.924 mm | 1.835 mm |
| Ring | 2.081 mm | 1.941 mm |
| Pinky | 2.552 mm | 2.471 mm |
| Raw thumb | 32.816 mm | 30.354 mm |
| Existing collinear-prepared thumb | 0.0393 mm | 0.0333 mm |

Ordinary sampled hinge-plane normal differences are about 4.77–8.28 degrees.
These zero-plus-individual-limit samples expose nonplanarity; they do not bound
every combined angle configuration. The existing thumb preparation is useful
evidence that an explicit planar neutral frame can already be constructed. This
is not certification of its contact pose or the complete skinned thumb.

`tools/render_digit_motion_slices.py` produces a standalone review with equal
millimeter axes: `test_artifacts/digit_motion_slices_review.html` and `.svg`.
The PNG was visually inspected. Red contours are actual Handle intersections;
blue volumes are the existing stored contact-radius calibration, not a newly
measured skin mesh. Thin sample chains are angle-limit probes, not grip solutions.
Independent checks reproduced all 12 contour edge sets exactly and confirmed
the registered plane-to-machine-to-world composition with maximum component error
below 9.1e-8. Final exporter numeric-input validation was also run successfully
on the right capture (`04-20-28`); it did not change measured values.

The user clarified the intended architecture after these measurements:

1. Prepare the character before grip consumers use it. Generate a model-associated
   resource containing each digit's three segments, measured skin envelope,
   registered motion plane and mappings to its real joints; include palm contact
   geometry. Establish the planar motion contract during this preparation.
2. At acquisition, load that prepared anatomy, slice the current Handle in each
   digit's actual positioned plane, and use one generic 2D solver to produce its
   three joint angles. Model changes regenerate/invalidate anatomy data rather
   than requiring hardcoded Josie dimensions inside the solver.
3. Independent digit calculations use the same captured hand/Handle placement.
   Their candidate results are assembled and checked together with palm clearance
   and digit overlap before accepting the hand. This independence does not require
   concurrent live Skeleton3D writes or establish that threading is beneficial.

This clarification means current nonplanarity is a model-preparation requirement,
not grounds for rejecting the proposed decomposition. Dimensions can be measured
from the model; intended hinge axes, allowed ranges, neutral pose and contact-side
definitions still need an explicit contract. A finite-thickness finger also reaches
outside its central plane: candidate validation must account for that geometry.

The current code's stored radius/terminal tables are explicitly Josie-specific
constants in `PlayerDigitHingeRules`, not regenerated per-model anatomy resources.
The existing model owner is `PlayerHumanoidRig`, whose scene instances Josie and
whose startup already prepares height/reach/body proxies before Skill Crafter.
`PlayerRigModelPresenter` has rest-transform reach measurements to reuse; no
persistent per-model hand calibration/fingerprint was found in the inspected
core/runtime paths. The current solver's calculate-candidates-then-assemble-packet
boundary is useful, but its safety aggregation does not test palm skin or
finger-versus-finger contact.
The existing mesh/skin diagnostic provides a measurement precedent, not that
missing resource or a complete palm extractor. No new character-resource schema,
planarization rule, palm placement behavior or production solver has been applied
during this investigation. The next bounded proof is one prepared digit and its
Handle section before generalizing to both hands.

Official Godot 4.7 references reviewed:

- [JacobianIK3D](https://docs.godotengine.org/en/4.7/classes/class_jacobianik3d.html)
  and [IterateIK3D](https://docs.godotengine.org/en/4.7/classes/class_iterateik3d.html):
  useful joint/endpoint mechanisms, not a complete multi-surface hand-fit solver.
- [Skeleton3D](https://docs.godotengine.org/en/4.7/classes/class_skeleton3d.html)
  and [SkeletonModifier3D](https://docs.godotengine.org/en/4.7/classes/class_skeletonmodifier3d.html):
  skeleton-relative bone poses and ordered custom modification are the relevant
  integration seams. They do not remove this project's coordinate/ownership rules.
- [PhysicsDirectSpaceState3D](https://docs.godotengine.org/en/4.7/classes/class_physicsdirectspacestate3d.html):
  motion casts ignore shapes already overlapping; contact APIs do not replace the
  existing signed surface-distance checks.
- [MeshInstance3D](https://docs.godotengine.org/en/4.7/classes/class_meshinstance3d.html#class-meshinstance3d-method-bake-mesh-from-current-skeleton-pose):
  current-pose mesh baking can support a one-time hand-surface diagnostic, but is
  expensive and ignores blendshapes. Do not put it in every closure iteration.

## Tools and continuation

The later Middle/Thumb model-preparation experiment, full-object contact scope,
engine skinning comparison, measured timings and current anatomy-proxy limitation
are recorded in [Two Digit Grip Plane Proof 2026-09-15.md](<Two Digit Grip Plane Proof 2026-09-15.md>).
That tool-only proof has not established a valid real grip or replaced the live solver.

- `tools/diagnose_skill_crafter_control_latency.gd`: actual Roll/Tip/Pommel input,
  explicit refresh, release and full pose snapshots. JSON under
  `C:/WORKSPACE/test_artifacts/skill_crafter_latency_<timestamp>.json`.
- `tools/skill_crafter_drag_profile_presenter.gd`: diagnostic subclass only;
  inclusive stage durations, seat status, solve counts and solver milliseconds.
  Nested timings overlap; do not add every stage together.
- `tools/diagnose_committed_grip_recovery.gd`: contact-availability/guidance probe,
  not an assertion that contact is correct.
- `tools/diagnose_skill_crafter_grip_acquisition.gd`: actual copied startup for both
  hands, seat/finger outcomes, anatomy before/after seat, and attachment lag samples.
  Optional process environment `THE_WILL_PROBE_FULL_PROXIMAL=1` enables the existing
  gate only in the diagnostic subclass; `THE_WILL_PROBE_PROXIMAL_SWEEP=1` adds sampled
  failed-digit closure measurements. Neither switch changes production rules.
- Older `diagnose_skill_crafter_pommel_drag_profile.gd` manually assembles an older
  drag pipeline and uses a different weapon; its numbers are not directly
  interchangeable with current actual-event measurements.

Run with the supported launcher, for example:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File 'C:\WORKSPACE\The Will- main folder\the-will-gamefiles\tools\launch_the_will_safe.ps1' -Headless -ScriptPath res://tools/diagnose_skill_crafter_control_latency.gd
```

Keep one owned Godot test process at a time and leave the user's open game alone.
Do not push executables, generated logs or test results.
