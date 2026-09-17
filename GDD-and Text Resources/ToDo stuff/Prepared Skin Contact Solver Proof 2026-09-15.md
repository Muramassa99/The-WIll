# Prepared skin contact solver proof - 2026-09-15

**2026-09-16 continuation:** the baseline investigation below confirms crossings
in the reconstructed captured open hand as well as the prepared pose. It also
identifies shared skin deformation between digits. See
[Baseline investigation](#2026-09-16-baseline-investigation) before treating the
earlier independent-digit searches as evidence about placement or clearance.

## Current result and scope

The solver experiment now consumes the saved character anatomy and calculates
actual deforming skin slices at candidate joint angles. It no longer uses the
rejected centered round capsule as the finger's geometry.

**No valid real-weapon grip has been established.** The bounded search has run
for Middle and Thumb on both hands using the existing frozen test-weapon
captures. No live grip solver, Hand placement, wrist/arm IK, accepted Roll,
F generation, saving or two-hand behavior was changed. Character creation/save
integration remains the separate [full-hand TODO](<Character Creation Full Hand Preparation TODO 2026-09-15.md>).

This continues [the two-digit proof](<Two Digit Grip Plane Proof 2026-09-15.md>)
and uses [the standalone character preparation output](<../../The Will- main folder/the-will-gamefiles/tools/grip_plane_proof/CHARACTER_HAND_PREPARATION.md>).

## Code and data path

All new executable files are isolated under
`The Will- main folder/the-will-gamefiles/tools/grip_plane_proof/`:

1. `prepared_anatomy_contact_input.gd` combines the saved rest-relative frames,
   calibrated zero, measured dimensions and authored limits with the frozen
   capture's Hand placement. It registers Hand and plane chains back to
   `RL_BoneRoot` and checks physical length agreement. It does not measure the
   character again or reposition the Hand.
2. `prepared_digit_skin_query.gd` prepares weighted skin coefficients once for
   this fixed hand/query. It keeps all weights, including shared palm tissue,
   caches unchanged triangle intersections, and updates only positively affected
   vertices and incident triangles for each candidate. This is pose evaluation
   of saved anatomy, not another anatomy bake.
3. `skin_plane_contact_query.gd` measures actual segment gaps/intersections in
   the named metric plane. Full boundaries are retained for classification;
   contact candidates are clipped to the measured reach disk without fake caps.
4. `prepared_skin_contact_solver.gd` tries coordinated closure seeds and a small
   full-range grid, then refines angle combinations within the authored limits.
   It has a fixed evaluation budget and exact angle-tuple caching. Its three
   weight-based ranking regions are heuristics, not anatomical partitions or
   proof of three valid phalanx contacts.
5. `run_prepared_skin_contact_proof.gd` runs the frozen fixtures, reports duration
   and uncertainty, and exports raw evidence. `render_prepared_skin_contact.py`
   produces SVG/HTML views of those actual segments and joint positions.

Saved source signature:
`0fb9e5dbe88cd71e342f4efe106676026345d283374abede7dc98853dd784bf5`.
This runner deliberately targets that known proof resource. General source
validation during character setup remains necessary for live integration;
matching bone names alone cannot detect a changed skin mesh.

The captured Hand affine transforms remain unchanged. Composing saved and
captured frames introduced about 1e-6 relative axis round-off; only the metric
measurement axes are orthonormalized after checking scale compatibility. The
physical section-length round-trip errors in these fixtures stayed below
0.000041 mm. No model scale or joint limit was relaxed to pass.

## Fresh test-weapon findings

Final run: `godot_runs/the_will_2026-09-15_12-24-15.log`.
Raw result: `test_artifacts/prepared_skin_contact_2026-09-15T12-24-29.json`.

| Digit | Selected result within the bounded search |
| --- | --- |
| Right Middle | Two skin/weapon crossings remain; no clear candidate. |
| Right Thumb | Two crossings remain; no clear candidate. |
| Left Middle | No detected boundary crossings, but no ranking-region contact within tolerance. Provisional only. |
| Left Thumb | Two crossings remain; no clear candidate. |

The right Middle's zero pose already crosses the weapon in skin behind its
first joint, around (-27.4, +25.2) mm in that digit's plane. The retained crossing
is near the palm/digit junction; it is not created only by distal closure.
The observations make the captured Hand placement and the prepared neutral-pose
baseline the next investigation. They do **not** prove which upstream owner is
wrong, nor that all allowed configurations are impossible. Do not move the Hand,
shrink skin, discard shared tissue or enlarge limits merely to force a pass.

The target's complete planar contour is closed in these four slices, but the
captured 3D mesh's own topology report says `surface_not_closed`: four
nonmanifold edges on each side, plus four boundary edges on the right. This
upstream limitation is preserved. Distance and crossing tests still run;
the tool does not certify solid inside/outside classification or penetration
depth from those inputs. These are captured-fixture findings, not a fresh audit
of every current Forge output or evidence that the export topology itself is
necessarily the source of the visual grip problem.

Full character-plane intersections also include unrelated body/clothing
components with open or overlapping boundaries. Candidate mode skips that
expensive global skin-solid classification explicitly, retains the actual
geometry, and cannot return certified clearance. Independent digit evaluation
holds other bones at hand-rebased rest. Combined Middle/Thumb deformation,
palm contact, inter-digit/self-intersection checks and final 3D validation remain
required before a grip can be accepted.

## Precision and performance evidence

- `verify_prepared_digit_skin_query.gd`: **101 checks passed** at 12:15:19.
  Four digits x five poses; all 15,992 vertices compared with the existing full
  renderer-convention skin reconstruction. Maximum vertex difference 0.000382 mm;
  maximum slice-endpoint difference 0.003294 mm, under the declared 0.005 mm
  comparison tolerance. The full and optimized slice paths share intersection
  code; this verifies coefficient/cache equivalence, not an independent proof
  of the intersection algorithm.
- Only 234-312 vertices and 189-220 triangles update per candidate, out of
  15,992 vertices and 19,300 skin triangles. Pose plus slice update took
  0.7-0.84 ms in the focused verifier; the full skin reconstruction alone took
  17-19 ms. Shared skin weights were retained.
- `verify_skin_plane_contact_query.gd`: **33 checks passed** at 12:19:42,
  including holes, containment, cropped reach, crossings, incomplete boundaries,
  coincident edges, origin mismatch and preservation of tiny real edges.
- `verify_prepared_skin_contact_solver.gd`: **39 checks passed** at 12:23:51,
  covering a known coupled synthetic objective, deterministic results, exact
  limits, budgets, caching, invalid evaluations and both containment directions.
  A seed interpolation endpoint-rounding defect found by this test was fixed
  by clamping to the exact authored range, not widening the range.
- Final real searches used 220-231 unique evaluations and roughly 2.9-3.3 seconds
  per digit. Query coefficient setup costs about 80 ms per fixed query; object
  slicing/setup about 27-30 ms. Candidate contact checks dominate the search.
  These timings are **not suitable live whole-hand performance**, and the
  searches did not produce a verified real grip. Character loading and query
  setup are accounted separately from candidate solving.

## Reproduce and continue

From `C:\WORKSPACE`:

```powershell
$env:THE_WILL_PREPARED_SKIN_SEARCH = '1'
powershell -NoProfile -ExecutionPolicy Bypass -File 'The Will- main folder/the-will-gamefiles/tools/launch_the_will_safe.ps1' -Headless -ScriptPath res://tools/grip_plane_proof/run_prepared_skin_contact_proof.gd
```

Without that search flag, the runner evaluates five coordinated closure poses
per digit. `THE_WILL_GRIP_CAPTURE_PATH` optionally selects one existing capture;
otherwise the right 04:36:47 and left 04:36:57 fixtures from the earlier proof
are used. The tool does not open or rewrite the player's weapon library.

[Visual comparison](../../test_artifacts/prepared_skin_contact_2026-09-15T12-24-29.html)
shows the final sampled and selected poses. Their complete plotted geometry
matches the preceding 12:20:09 render, which was visually inspected; final
timings and reports come from the 12:24:29 JSON/log.

Next narrow decision: inspect the input Hand placement and neutral-pose mapping
against the actual hand/weapon geometry, identifying why the existing zero pose
already intersects. Communicate any required upstream seat or calibration change
before implementing it. Increasing the search budget alone does not establish
that the input relationship is correct.

Production tracked diff stayed at the prior seven files, 370 insertions and
22 deletions. The real WIP library SHA256 remained
`C59A09D3B33D321F482F2C379DF5FD299246544F2229E5A8B12970F769500E0E`.
No Git commit/push or live-game pose write occurred.

## 2026-09-16 baseline investigation

The narrow restart task was to distinguish captured placement from prepared-pose
substitution and neighboring-bone reconstruction assumptions. The new isolated
`tools/grip_plane_proof/diagnose_prepared_contact_baseline.gd` compares seven
starting poses for Middle/Thumb on both sides, holding the captured Hand,
weapon and one registered measurement plane fixed. It loads the existing anatomy;
there is no bake, search, live skeleton write or placement change.

### Findings

1. **The prepared and captured starting postures differ.** Prepared first-bone
   orientation differs from captured Idle by 15.16/15.92 degrees for right/left
   Middle and 30.37/30.63 degrees for Thumb. Prepared joints 2/3 use the explicit
   calibrated zero; captured raw Thumb precedes its existing production
   neutralization. The diagnostic compares that neutralization separately.
   Matching segment lengths did not establish matching posture. This substitution
   is an intentional preparation choice to inspect, not automatically a defect.
2. **The right Middle crossings survive both baselines.** With neighboring digits
   at rest, source skin triangles 4202/4204 cross in captured and prepared zero.
   At the prepared crossing points, Middle contributes only about 3.7/7.4% of
   deformation; Hand contributes 34-36%, Thumb2 29-35%, and Ring1 19-21%, with
   remaining Index/Pinky/Thumb1 influences retained. Distal Middle calibration
   cannot move those particular triangles because they have no Mid2/Mid3 weights.
3. **Resting neighbors are not the complete captured hand.** The diagnostic now
   also reconstructs all five captured digit baselines together. All five share
   the same Hand, one identical 15-bone base-rotation map, matching current/base
   rotations, and zero FK frames matching their captured base frames. Producer
   inspection confirms the sequential solver captures do not write bones between
   digits. Restoring these neighboring poses changes the skin near the crossings;
   it does not remove the starting intersections.
4. **Shared skin couples otherwise modular digit solves.** A Thumb pose changes
   some skin intersected by Middle's plane. Contact must therefore evaluate a
   coherent common hand pose, including the retained palm and neighboring weights.
   Separate digit calculations are still useful; independently accepting them
   against incompatible neighboring poses does not establish a valid full grip.

Proper skin/weapon boundary crossings inside the measured query window:

| Reconstructed zero pose | Right Middle | Right Thumb | Left Middle | Left Thumb |
| --- | ---: | ---: | ---: | ---: |
| Prepared selected digit; other digits at rest | 2 | 4 | 0 | 2 |
| Complete captured Idle-open hand | 4 | 2 | 2 | 6 |
| Captured hand with existing Thumb neutralization | 6 | 2 | 2 | 6 |
| Prepared Middle+Thumb; other digits at captured Idle | 2 | 4 | 0 | 2 |

These are starting-state intersections, not proof that no joint combination can
resolve them. Zero detected crossings is still not certified clearance. The
source mesh topology and missing final 3D/self-contact checks remain as described
above. Nonhand bones still use Hand-rebased rest, but every influence on the
reported crossing triangles belongs to the reconstructed same-hand bones.

### Placement ownership and next scope boundary

The existing preview seat opens cached Idle fingers, asks the rig for an exact
surface seat, and applies its correction to the **weapon**, keeping Hand fixed.
The seam is `combat_animation_station_preview_presenter.gd`,
`_apply_preview_weapon_surface_seat` (around lines 5525-5672), followed by the
digit-settle call that produced these captures.

`player_humanoid_rig.gd`, `resolve_hand_surface_seat_anatomy_state`, supplies
Index1/Pinky1 bone points and fixed declared radii of 10.5/9.2 mm. The seat checks
the selected Handle's triangle surface at centerline stations; it does not
consume measured palm skin. Primary paths pass
`enforce_ordinary_proximal_safety=false`. Initial mount alignment also comes from
bone positions and cached Run/SlowRun animation samples rather than measured palm
contact. A successful current seat therefore does not certify palm clearance.

**Proposed next step, not implemented:** give the two-digit proof a single shared
posed-hand surface and explicitly evaluate palm contact at its starting
relationship. Establish the required contact/placement contract before replacing
the live seat's proxies. A placement correction would change the starting
hand/weapon relationship and needs discussion with the user before implementation.
Do not widen joint limits, move Hand, discard shared tissue, or change accepted
Roll just to hide these crossings. The investigation has not proved the amount or
direction of any necessary placement correction.

### Follow-up design constraints from the user (2026-09-16)

The user clarified that the existing offset was deliberately based on hand skin
extent from the Index-Pinky reference and Handle center-to-surface extent in the
required direction. Preserve this existing work as the starting point. The
current `_query_radial_target` and `_solve_exact_radial_tangent_target` already
refine the facing-boundary estimate against actual nearest-triangle clearance;
they are not merely a radius sum.

The user proposed additional axes / triangulation to improve centering. Source
inspection distinguishes movement permission from the measurements choosing it:

- The seat already permits translation throughout the two-dimensional plane
  perpendicular to the input Handle axis; it removes axial displacement after
  each iteration (`player_hand_surface_seat_solver.gd`, around lines 280-289).
- Its update follows Index/Pinky contact-chord alignment and midpoint recentering,
  with an optional proximal escape. It does not independently search that entire
  plane. Each Index/Pinky query follows one inferred radial direction.
- Additional measured palm/contact constraints could guide those existing two
  translation components. A third reference away from the Index-Pinky line is
  worth testing, but three points alone are not a universal solution: their
  contact directions must provide independent information, and all relevant skin
  must still pass contact checks. This is a proposal, not an implemented search.

**Explicit user requirement: weapon-direction-neutral behavior**, including
normal and reverse grip, two-handed setups and other hand/grip combinations.
The geometric solve must use actual anatomy, selected Handle location, local
weapon surfaces and relative transforms. Do not assume Index is nearer the tip,
Pinky nearer the pommel, a particular world-up direction, or a particular hand
being primary. Current station sampling already uses signed projections of actual
Index/Pinky positions; preserve that geometry-based intent.

Proposed validation must distinguish two cases: changing only the representation
of an axis/frame must preserve the physical answer; physically reversing an
asymmetric weapon may legitimately produce a different offset/contact solution.
Both physical grip orientations must satisfy the same acceptance rules.

For two hands, evaluate both against one common weapon pose and retain each hand's
own anatomy, Handle station and role. An accepted correction for one hand cannot
invalidate the other. Contact requirements and permission to move the weapon,
support anchor or other controlled element remain separate responsibilities under
the existing ownership rules. Report infeasibility within those permissions;
do not silently move additional IK joints or invent an accepted fit. These broader
requirements constrain the modular design; this note does not claim two-handed
validation has been implemented or expand the current two-digit proof into a
production two-hand rewrite.

### Evidence and reproduction

Final engine run: `godot_runs/the_will_2026-09-16_12-10-44.log`.
[Raw report](../../test_artifacts/prepared_contact_baseline_2026-09-16T12-10-49.json).
[Three-pose visual comparison](../../test_artifacts/prepared_contact_baseline_2026-09-16T12-10-49_review.html).
The final plotted geometry was checked equal to the preceding 12:07:52 render,
which was visually inspected. The review JSON is only a selection of three
reported poses; it neither interpolates nor alters geometry.

- 28 pose cases completed, with **272 report assertions passed**: case validity,
  agreement between crossing counts and triangle attribution, complete influence
  ownership, zero self-comparison deltas, common captured pose checks, registered
  neighbor origin chains, full-reconstruction agreement, and equality to the
  inspected geometry.
- Maximum crossing barycentric reconstruction error: **0.000064 mm**. This maps
  each crossing back to its indexed skin triangle and interpolates all original
  weights without normalization or dominant-bone geometry filtering.
- Neighbor coefficient updates matched full weighted reconstruction over all
  15,992 vertices within **0.000122 mm**. This is an offline arithmetic check,
  not a new live renderer comparison. Earlier renderer checks remain historical.
- The seven diagnostic poses took roughly one second per digit including repeated
  setup, full reconstruction comparisons, contact queries and attribution.
  These are diagnostic timings, not production grip performance measurements.
- Godot 4.7 exited 0. It emitted the environment's root-certificate-store warning;
  these calculations use local files and performed no network operation.
- The prepared anatomy SHA256 stayed
  `B7F07BF7D79DB331FCB250982A62B31D4ABC1E58D1D4B2BEEFC2754658C27DEA`.
  The real WIP library SHA256 stayed
  `C59A09D3B33D321F482F2C379DF5FD299246544F2229E5A8B12970F769500E0E`.
  Tracked production diff remains seven files, 370 insertions/22 deletions. New
  diagnostic code is untracked; the tracked diff is not the whole local work.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File 'The Will- main folder/the-will-gamefiles/tools/launch_the_will_safe.ps1' -Headless -ScriptPath res://tools/grip_plane_proof/diagnose_prepared_contact_baseline.gd
```

No commit/push, production grip change, seat change, Roll change or player-library
write was made in this continuation.
