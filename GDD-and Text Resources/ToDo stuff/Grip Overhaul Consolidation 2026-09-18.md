# Grip overhaul: working plan, ownership and replacement boundary

Date: 2026-09-18, chat 14. Latest direction: October 4 V6 savepoint and palm-first, surface-query grip pivot.

## October 4: current user-authorized pivot and requirements

This section supersedes the circle/slice continuation instructions below as the
next implementation direction. Preserve their history and current source in the
requested `hand overhault v6.0 sub-optimised` Git savepoint before replacement.
The new solver is PLANNED, NOT IMPLEMENTED. The latest strict-guide live run
timed out during Middle, with no new pose applied. This is a recovery snapshot,
not a working-grip release or proof that no improvements to the old method exist.

The user wants a modular, predictable grip that is fast enough for live skill
editing. Seat first, close four fingers second, add a redesigned Thumb later.
Remove live exact slicing and shrinking circles from the replacement acquisition
path. Reuse the prepared character and saved Forge V2 surfaces. Do not reactivate
an entire old solver or leave two owners writing the same hand.

### Finished-result requirements

1. Consume the chosen character's actual dimensions, weighted skin, named bone
   chain, calibrated hinge planes and angular ranges. Derive data from the model;
   do not substitute hardcoded Josie sizes for a modular character resource.
2. Consume the exact saved Forge V2 physical Handle and invisible digit/palm
   targets, including curved/off-center/concave shapes, authored orientation,
   valid Handle span and source signatures. Do not regenerate the wrapper while
   gripping. Preserve its existing inward-curvature treatment and insets.
3. Keep every position, direction and transform traceable through named origins
   to `RL_BoneRoot`. Query-local transformations/scales need explicit provenance.
4. Preserve handle-position semantics, including the existing -1..1 or 0..1
   mapping and normal/reverse direction. Weapon length remains parallel to the
   anatomical Index1-Pinky1 base-joint axis with the correct polarity. Preserve
   authored weapon roll/orientation; seating is translation, not an extra roll.
5. Main-hand acquisition holds Hand, wrist, Index-Pinky reference and upstream
   body fixed. The weapon is the joining object and may translate to seat;
   finger joints may articulate. Handle-% changes retain their existing driver
   that slides the weapon relative to the occupied main hand.
6. Begin in the calibrated open-hand pose. Open Thumb S1 for clearance and
   temporarily disable Thumb closure. Retain an explicit open Thumb pose under
   the same pose owner; do not accidentally retain an old curled Thumb or hand
   it to legacy closure. Thumb geometry still participates in obstruction checks.
7. Palm seating uses the region associated with the Index1 and Pinky1 base
   joints at the selected Handle station. The red proximal reference in the
   user's drawing is fixed reference geometry, never a bone to manipulate.
   CONFIRMED: 90 degrees describes the approach direction toward the palm;
   weapon length still stays parallel to Index-Pinky. Do not reinterpret this
   as a competing perpendicular requirement on the weapon's length.
8. User clarified the drawing's arrows as TWO TRANSLATION STAGES, with no
   rotation: first reposition the weapon axis at the perpendicular reference
   position; then advance along that approach axis toward Index-Pinky until
   palm skin and the weapon's saved palm target reach the allowed overlap
   stopping region. Weapon length stays parallel to Index-Pinky throughout.
   Physical skin caps can stop the approach before the deeper attraction target
   is reached. Then hold the seat while the four non-thumb fingers engage.
   Preserve the selected Handle station; the drawn axial repositioning does
   not mean sliding along the weapon's length or adding weapon roll.
9. Close Index, Middle, Ring and Pinky using bounded 3D surface queries and the
   calibrated hinges. Keep S1/S2/S3 preferences at 20/50/80 percent, Gaussian
   spread 25 percentage points and the current 50% strength. These are soft
   preferences: other valid gripping-side locations can satisfy contact. No
   backside ring of competing targets and no connection through bones/other skin.
10. Keep target depths and permitted intersection separate: saved digit target
    1.5 mm inward, saved palm target 3 mm inward; actual per-section digit caps
    remain authoritative, identified palm/webbing cap stays 2.5 mm. Do not
    increase caps to reach a deeper target. Unassigned/backside tissue does not
    inherit palm or digit privileges.
11. Separate attraction from safety. A few successful rays are not proof that
    an entire finger pad avoids excessive penetration. Use bounded current
    surface/proxy checks with documented coverage, original skin evidence and
    the existing caps; never call an unvalidated proxy exact skin geometry.
12. Respect joint limits, true terminal geometry, same-side approach, and actual
    material contact versus contact with a bridged empty wrapper recess. Preserve
    the established minimum of three distinct actual-contact sections across
    the hand, without disguising a visibly floating required finger as success.
13. Preserve acquired contacts during any bounded correction/reseating, at most
    three attempts. Do not add an unbounded search for an optimum. A numerical
    failure or missing ray hit is not proof of a physical movement limit.
14. Lock a successful weapon/hand relationship for rigid movement. Tip, Pommel,
    Roll and upstream posing must retain it within the existing reach policy;
    the approved present fallback is to stop movement at arm/wrist limits.
    Ordinary rigid movement must not rebuild the grip or weapon geometry.
15. Reacquire when contact geometry changes: handle %, switching weapon/shape,
    character anatomy, normal/reverse grip or a relative orientation change.
    Reuse prior legal contact/pose data as a starting point when still applicable.
    Changed input must cancel/supersede stale asynchronous results.
16. Support-hand addition uses the same contact backend but opposite ownership:
    primary hand and weapon stay fixed; the joining support hand moves into
    its existing aligned starting position, then its fingers engage. Removal
    releases support cleanly without restarting the primary solve. This is a
    required integration seam, not proof that current modern support is complete.
17. Preserve an open/unarmed hand branch. Thumb's extra motion and later full
    Thumb solution are explicitly deferred; label the initial output as a
    four-finger prototype rather than completed full-hand acceptance.
18. Measure cold preparation, seating, each digit, correction, validation,
    application and regrip separately with the chronology tools. Carry forward
    the earlier <=2 s complete-acquisition goal and approximately 250 ms editor
    aspiration as targets, not achieved measurements or a new guarantee.
    Bounded work and responsive cancellation are required; no long hidden wait.

### What can be prepared once and reused

| Data | Existing owner / current truth | Reuse boundary |
| --- | --- | --- |
| Character reference mesh, weights, rest chains, lengths, hinge axes/ranges, true tip extent | `core/models/character_hand_anatomy_def.gd`, Josie's anatomy resource, `character_grip_data.gd` | Character/anatomy identity; rebake only when the character changes. |
| Named FK and original-weight skin evaluation | `prepared_hand_candidate_pose.gd`, `prepared_hand_skin_query.gd` | Reuse transforms and affected-vertex data; only moving finger skin changes per candidate. |
| Gripping-side and identified palm/web domains | `prepared_digit_gripping_surface.gd`, `prepared_palmar_slice_region.gd`, `palmar_reference_geometry.gd` | Existing evidence is reusable, but some preparation currently runs at acquisition time; export/cache the needed 3D domains. |
| Skin 0..100 coordinates and preferred points | `skin_section_contact_preference.gd` | Bias formula exists; CURRENT coordinates come from live sliced-contour arclength. A reusable 3D skin-coordinate/marker preparation is missing. Do not silently replace with bone-length percentages. |
| Physical Handle + separate digit/palm target triangles | `core/models/prepared_grip_target_wrapper.gd`, `saved_wrapper_grip_source.gd` | Already saved 3D geometry with units/origins/configuration; load/validate once, no acquisition wrapper bake. |
| Surface acceleration | Mature helpers in `player_finger_surface_grip_solver.gd`; Godot TriangleMesh candidate | Prepare once per weapon geometry identity and transform queries into that frame. Do not copy the old closure algorithm. |
| Axis, station and orientation mapping | `player_humanoid_rig.gd`, `primary_grip_seat_resolver.gd`, `player_equipped_item_presenter.gd` | Preserve the existing driver contract; recompute frame placement only when its inputs change. |
| Acquired relationship | `hand_grip_pose_binding.gd`, `preview_grip_acquisition.gd` | Recompose under rigid motion; invalidate only when grip-defining inputs change. |

Static reference skin is not current posed skin. A fixed hand BVH cannot be
reused unchanged after finger deformation. Original triangle/barycentric
markers can retain their identity while their weighted positions update.
Likewise, proximity rays starting at a bone to measure its own skin must be
distinguished from attraction connectors that must not travel through a bone.

### Missing preparation and implementation decisions

- The current rig declares S1 as a direct child of Hand; it has no separately
  declared per-finger metacarpal bone. User CONFIRMED wrist/Hand-origin-to-S1
  reference lines, identifying the left/right Hand bones. Use existing canonical
  `CC_Base_L_Hand` / `CC_Base_R_Hand` IDs and the corresponding Index1/Pinky1
  origins. Do not add, rename or move bones; derive the fixed reference lines.
- Establish the no-live-slice skin coordinate export using the existing
  skin-influence transition boundaries and real palmar surface. Its contract
  must preserve what 0%, 100% and the 20/50/80 preferences mean. Preparation may
  be expensive once; repeated live acquisition must consume prepared results.
- The initial Thumb uses a documented calibrated open pose, with no new Thumb
  articulation feature or expanded ranges in this slice.
- Define bounded physical pad validation alongside the targeting rays. Reusing
  the old capsule helper is possible only if its coverage/error is tested; it is
  not identical to the blended skin mesh.
- Existing C++ kernels are planar contact/topology/slice kernels, not a general
  3D ray/skin collision backend. Reuse proven geometry helpers or documented
  native facilities before adding a new custom kernel.

Official Godot 4.7 [TriangleMesh](https://docs.godotengine.org/en/4.7/classes/class_trianglemesh.html)
provides a physicsless BVH and finite segment intersections; preparing immutable
weapon geometry once is a candidate for the new route. Adoption is not yet
decided. Its [4.7 source](https://raw.githubusercontent.com/godotengine/godot/4.7/core/math/triangle_mesh.cpp)
snaps vertices to 0.0001 input units and flips hit normals against the ray.
Metre input would produce a 0.1 mm grid, coarser than the user's 0.05 mm accuracy
allowance. Verify explicit private query scaling or use a suitable existing
native query; retain original triangle winding for outward-side authority.
[PhysicsDirectSpaceState3D](https://docs.godotengine.org/en/4.7/classes/class_physicsdirectspacestate3d.html)
is an alternative, but would require physics-space objects and does not by itself
provide this hand's joint/skin/ownership rules. No solver speedup is measured yet.

### Ordered replacement boundary

1. Write this plan/SPS and push the V6.0 recovery snapshot. No replacement code
   is part of that snapshot.
2. Prepare/visualize the fixed palm references, safe open pose and reusable 3D
   skin targets; verify the native-query metric/orientation behavior separately.
3. Implement and prove palm-only seating against the exact saved weapon with
   fixed main Hand/wrist, unchanged weapon basis/station and measured duration.
4. Add the shared bounded four-finger closure and safety checks, retaining bias
   and hinge constraints. Verify both hands, normal/reverse orientation, round,
   rectangular and difficult saved profiles, size extremes and station changes.
5. Replace the primary acquisition call at its existing owner. Replace the old
   five-digit circle-guidance gate with an explicit four-active/open-Thumb result
   contract. Preserve all 15 owned bone writes and binding so legacy cannot write
   Thumb behind the new solver. Remove obsolete callers/duplicate live closure;
   keep only useful diagnostics and reference geometry functions.
6. Prove retention, regrip invalidation, cancellation and support add/remove using
   the same backend and correct joining-object ownership. Current reverse plus
   two-hand grip is unsupported: preserve an honest boundary until implemented.
7. Thumb redesign/additional motion is the next feature. F/play/save/runtime
   parity remain downstream work; do not pull them into this replacement early.

### State preserved before the pivot

The failed strict-guide experiment introduced same-side visibility checks,
working-guide progression, a pre-write guidance gate and supporting diagnostics.
Last live report: `test_artifacts/live_saved_wrapper_grip_2026-10-04T10-21-05.json`.
It timed out after the 300 s acquisition observation allowance; total harness
duration was 315.597 s. No new grip was applied. The resulting actual-pose HTML
shows the untouched open hand and is not useful grip-success evidence. The user
asked not to present unsolved output as the requested result.

Recorded focused checks from this session, not rerun just to make the snapshot:
visibility 45; working-guide geometry 2,703; preference selection 707; guide
lifecycle 389. These validate narrow rules, not a usable final grip. The native
library remains `d819b1acdef73297ce4491ee5494132f0b816f879c26bc5a6b0004ef2ea7332e`.
The working-guide physical-stop path remains unresolved; do not resume bisection
or enlarge solve budgets as the default next action. Prior older sections below
are archaeological evidence, not the current task queue.

## Historical status before the October 4 pivot

Current correction: the guide must drive finger placement through final closure
and reseating. The prior side-label restriction did not preserve the circle's
contact relationship during the transition to saved-wrapper targeting. Its
passing tests below did not cover target paths crossing another finger section.
Do not treat that historical pose as evidence of a valid guided grip.
Current user scope: all four non-thumb fingers on both hands prefer S1 20%,
S2 50%, S3 80%, with Gaussian spread 25 percentage points. Shared percentage
boundaries use the approved neighbouring skin-influence transitions, measured
along the actual sliced skin contour. Any eligible gripping-side location still
counts as contact. Backside/boundary skin no longer attracts or counts as a
finger contact; physical ownership, overlap caps and joint ranges stay unchanged.
User confirmed 50% preference strength against distance; the live default is
now 0.5. Peaks and spread stay unchanged. Before the continuity correction, the
October 4, 08:30 saved Star Copy right-hand run passed 77 checks and applied the
pose naturally. It reported
eligible S3 contact on Thumb, Index, Ring and Pinky, but not Middle or palm.
Numerical solve: 25.718 s. The earlier unrestricted-side run was 27.284 s;
its five-digit contact result is historical, not current evidence. Both runs
predate guide-continuity enforcement and do not verify the code now being changed.
See below.
The compiled slice and bounded palmar-web attribution repairs are implemented.
The last actual-save run before this preference work reached a material-safe
numerical candidate but rejected application because upstream pose changed
during acquisition. That rejection did not recur in the current 50% run;
the lifecycle guard was not changed. Other weapons, left-hand gameplay and
general whole-hand 3D contact remain outside this fresh run's evidence.
The earlier headless 40-step fixture failed material safety; it is a different
input and must not replace current-save evidence.
Weapon orientation remains an input to seating.

Historical September 28 measurements (not the current runtime duration):
All ten digits are prepared. The complete September 28 diagnostic took 335.736
seconds, including 313.093 seconds of numerical acquisition; actual contact met
the measured condition, but articulation validation remained unresolved. This
does not reproduce the user's longer interactive wait or certify a finished grip.
Next work follows the [agreed Forge preparation and contact-driven IK replacement](#2026-09-28-agreed-forge-preparation-and-contact-driven-ik-replacement).
W1 Forge target preparation/persistence and W2 save progress are implemented and
verified below; W3 now has isolated coarse contact preparation and W4 consumes
exact saved targets with measured, incomplete physical contact. W5, support
cutover and full grip acceptance remained pending at that checkpoint. Later
entries describe the wrapper-cap fixes and October 1 primary live cutover;
preserve historical measurements rather than treating them as current results.

Repository: `C:/WORKSPACE`. Active project:
`The Will- main folder/the-will-gamefiles`.
Historical analyzed HEAD: `03c82dfd11c56364448e5e448e3c70551f85f9bc` on
`recovery/stable-92b8a24-chat14`; backup tag:
`pre-grip-overhaul-and-code-cleanup`.
Previous handoff: [October 3 weld correction before native build](<../SPS/SPS_2026_10_03_23-59.md>).

## How to use this working file

### October 4: preserve guide authority through closure and reseating

User-authorized correction, implementation in progress. Gripping-side surface
contact must follow the concentric guide for every digit, through the saved
wrapper transition and reseating. A nearest or biased target reached through
skin/bone is invalid. Existing section overlap limits stop motion; they do not
replace the guide or authorize an independently chosen pose. The main Hand,
wrist, upstream IK, weapon orientation and the existing two-axis seating
ownership stay fixed. The hand-level acceptance minimum remains three distinct
actual material-contact sections, not three per digit. No caps, bias strength,
joint ranges or projection budgets are increased.

Planned implementation owners:

- `contact_driven_grip_preparation.gd`: each digit attaches to its guide and
  retains that relationship while its working surface approaches the exact
  saved wrapper. Material/guide constraints remain separate. Up to three
  reseats preserve contact; a physical-limit stop is recorded explicitly.
- `saved_wrapper_guide_progression.gd`: reconstruct intermediate working
  surfaces from the already saved targets, sharing the measured handle center.
  This does not regenerate the Forge wrapper or apply a second inset.
- `grip_target_visibility.gd`: reject blocked target connections before ranking
  or fallback. The same rule applies wherever guide attraction is evaluated.
- `preview_grip_acquisition.gd`: fail closed before any pose write unless the
  result explicitly verifies guide following and includes attached, internally
  consistent guidance for all five digits. Material safety alone cannot apply.
- `verify_live_saved_wrapper_grip.gd`: exercise the gate against missing,
  detached and inconsistent records; report actual per-digit guide progress
  and require the contract alongside the existing material/articulation checks.
- The actual slice exporter/viewer: show the recorded working guide separately
  from the saved end target and label blocked nearest connections as rejected.

Result contract: `guide_following_verified`, `per_digit_guidance` and
`working_guides`. Each digit reports attachment, initial radius, progress and a
stop reason. Working-guide progress/radius must match the state being assessed.
These are sampled-state checks, not continuous swept-contact or whole-hand 3D
certification. Source captures/saves remain immutable. No new SPS or Git action
is implied. Official Godot 4.7 Dictionary and Geometry2D documentation informs
the contract and geometry adapters. Fresh verification is pending; append exact
results before calling the correction complete.

### October 4, 08:36: restrict attraction to the anatomical gripping side

User requested removing backside targets and their unnecessary searches.
New `prepared_digit_gripping_surface.gd` prepares each section's gripping half
from original-weight reference skin, named bone origins and authored flexion.
The side is anatomical: it does not depend on weapon position, camera or
current finger pose. Original source-edge interpolation labels each slice.
Both endpoints must be inside the gripping half. Backside, crossing/boundary,
ambiguous and foreign edges are collision-only. Thumb S1 keeps its existing
no-attraction exception; S2/S3 use the same side restriction. Identified palm
still attracts under its existing rules. This does not normalize weights,
change ownership/caps, cut new skin geometry, rotate the weapon or move the arm.

`prepared_grip_slice_contact.gd` attaches the eligibility after the existing
skin-influence percentage map. Ineligible edges lose their preference metadata.
`contact_driven_grip_preparation.gd` filters initial-circle targets, wrapper
targets, preferred points, nearest fallback and retained contact witnesses.
`handle_grip_acquisition.gd` also filters actual counted contacts. Physical
collision checks continue to see every edge. The cheap initial-circle no-entry
check is retained; the expensive saved-wrapper target query is skipped for
ineligible skin. `saved_wrapper_skin_contact.gd` and native
`grip_saved_contact_kernel.cpp` report skipped guide records explicitly, with
no witness and null guide-depth fields, while preserving material records and
their indices. Missing flags retain existing compatibility; malformed flags
are rejected. No second solver, wider iteration budget or different bias strength.

Fresh checks (Godot 4.7, serialized supported-launcher runs):

- Native DLL built successfully using the existing workspace toolchain.
- `native_saved_contact_2026-10-04T08-27-15.json`: 763 checks pass, including
  native/reference parity and excluded skin that still fails physical overlap.
- `skin_section_preference_anatomy_2026-10-04T08-27-26.json`: 1,074 checks pass
  across 30 real hand/digit/pose cases. This verifies preparation/contour data,
  not full live acceptance on both hands.
- `the_will_2026-10-04_08-29-56.log`: 568 selection checks pass, including
  exclusion from preferred and nearest-fallback targets.
- `digit_gripping_surface_2026-10-04T08-31-24.json`: 348 checks pass for both
  hands/all digits, reference transforms/scaling, original nonunit weights,
  source interpolation, ambiguous boundaries and unchanged physical fields.
- `live_saved_wrapper_grip_2026-10-04T08-30-14.json`: 77 checks pass using the
  same saved `Star_Handle_Testing Copy`, no pose injection. Pose applied;
  articulation/material assessment passed, upstream local poses unchanged,
  and existing Tip/Pommel/Roll relationship checks passed. Whole-hand 3D
  contact remains uncertified; this is not proof of a finished visual grip.

Timing: numerical solve 25.718 s versus the previous 27.284 s (one run each,
about 5.7% lower; not a statistical benchmark). Whole verifier 50.389 s.
During the numerical acquisition, all 49,316 physical edge evaluations remain;
12,927 wrapper edge evaluations run and 36,389 are skipped (73.8%). Point
preference queries are 146 versus 549 previously. Workload/pose changes mean
the query reduction is not a claim of an equivalent total-runtime reduction.
Trace: `grip_gripping_side_20261004_0831_chronology.jsonl`.

New actual-pose visual:
`test_artifacts/live_saved_wrapper_grip_2026-10-04T08-30-14_actual_slices.html`
and matching JSON. Solid skin can attract; dashed faded skin is collision-only.
Backside gold preference markers are absent. No marker is invented without
eligible/owned percentage data. Only S2 markers survive in the current
Index/Ring/Pinky slices. Middle's percentage mapper is neutral for this pose:
`missing_ambiguous_or_branched_contour`, reaching a degree-one endpoint at
source edge `0/3838`. It has zero mapped edges before the new side filter.
That separate mapping gap remains unresolved; its reason/walk detail is now
included in the exported JSON. It is not evidence of an inverted side label.

The export initially disagreed on Index S3 because its strict bounded query
upper depth is 0.380057 mm versus the 0.380 mm cap, while live assessment uses
its existing 0.002 mm numerical guard. Export labels now reuse that existing
guard, preserve strict results separately, and match all four live contacts.
No runtime cap changed. Final export log `the_will_2026-10-04_08-38-19.log`:
4.853 s, source hashes unchanged, all five slices exported. HTML JavaScript
was smoke-tested with a DOM/canvas stub and sampled actual data, five panels,
two fit modes and eight toggles; no browser render is claimed.

Open result, not hidden by the passing verifier: current Middle S3's eligible
skin is 7.072 mm from material. The handle is on the outer side of the curled
distal segment; independent joint/contour geometry agrees with the anatomical
side label. A backside touch cannot satisfy contact anymore. The root cause of
that placement/closure outcome is not established by this change and has not
been tuned away. The current hand-level three-section threshold is satisfied
by the other four digits. Full intended grip and Middle seating still need
visual review and a separately scoped follow-up; do not describe this as all
five digits gripping correctly. Current percentages, strength and caps remain.

Official Godot 4.7 Transform3D/Dictionary documentation was reviewed for named
frame conversion and the native/reference metadata contract. No Git mutation
or external application installation was performed for this change.

### October 4: actual applied grip slice export

At the user's request, the 02:34:06 live run now has a standalone colour-coded
HTML of all five right-hand slices:
`test_artifacts/live_saved_wrapper_grip_2026-10-04T02-34-06_actual_slices.html`
(with matching JSON). This observes the recorded `_actual.bin`, not the
solver's proposed candidate. No grip solve, scene pose write or gameplay
change was made for the export. Joint projections include J3 through Tip.

New diagnostic owners: `tools/grip_plane_proof/export_live_grip_slices.gd`
and `live_grip_slices_view.html`. Set `THE_WILL_GRIP_SLICE_REPORT` to the live
JSON and run the exporter through the supported headless launcher. It reuses
the actual-pose observer, named-plane slicer, palm attribution, saved-section
and native contact owners. The immutable saved wrapper is reloaded from the
hash-matched library because the capture's `store_var(false)` retains resource
IDs rather than resource contents; captured transforms and skin stay unchanged.
Saved handle packet equality and input hashes are checked before export.

Fresh export: `godot_runs/the_will_2026-10-04_03-27-55.log`, 4.843 s, all five
slice queries valid and all six contact sections match the live report exactly.
All displayed slices remain within material/guide limits; identified palm is
not in contact. Input capture, library and live report hashes are unchanged.
HTML JavaScript smoke-checked with a DOM/canvas stub using sampled real data:
five panels, both fit modes and all eight layer toggles; no browser rendering
was performed. This remains planar evidence, not whole-hand 3D certification.

### October 4: soft section-location preference (50% live strength enabled)

User-approved definition: Palm/S1 influence crossing is S1 0%; S1/S2 is
S1 100% and S2 0%; S2/S3 is S2 100% and S3 0%; the distal skin tip is S3 100%.
This is contour arclength, not projected bone length. Peaks are 20/50/80 and
spread is 25 percentage points. Scope excludes Thumb. The user subsequently
chose and explicitly confirmed **50% strength**, i.e. 0.5 of section length as
ranking credit; this does not move every section's target to 50%. The live
default is enabled at 0.5. Synthetic tests use 10% explicitly. The subsequent
"I'd go for 90%" comment was tentative; the confirmed 50% run remains the
current baseline unless the user directs another setting.

The imported skin has split render vertices at several seams. Proven duplicate
vertices have byte-identical reference XYZ and complete original bind/weight
tuples. A once-prepared alias map reconnects those sources for preference
contours only. Actual vertices, skin weights, face IDs, ownership and collision
allowances remain unchanged. No posed-space distance weld is used. Ambiguous
or missing contour data stays neutral; it does not exclude physical contact.

Owners: `weighted_skin_plane_slicer.gd` exposes original endpoint provenance;
`prepared_hand_skin_query.gd` prepares exact reference aliases;
`prepared_grip_slice_contact.gd` supplies original Hand influence and named
digit-plane measurements; new `skin_section_contact_preference.gd` resolves
ordered influence boundaries, contour percentages and Gaussian ranking.
`contact_driven_grip_preparation.gd` keeps physical rows separate from attraction
selection. Selection freezes source identity for one numerical response, then
can slide again. Failed preference proposals may use the original nearest
selection within the same 40-iteration budget. There is no additional solver,
no expanded overlap allowance and no altered three-contact acceptance rule.

The original per-edge nearest witness alone cannot target an interior peak on
long mesh edges. The point-query extension supplies a preferred-coordinate
candidate alongside the nearest candidate. A chosen point parameter is fixed
only during that one response/line search, using the existing point Jacobian.
This is alternating contact-target selection, not a claim that the distance
Jacobian differentiates the complete Gaussian ranking score.

Fresh focused checks:

- `skin_section_contact_preference_2026-10-04T02-00-57.json`: 93 synthetic checks
  pass, including exact seam identity and safe neutral fallbacks.
- `skin_section_preference_anatomy_2026-10-04T02-01-00.json`: 2,514 checks pass,
  all 30 real captured hand/digit/pose cases; Thumb remains unannotated.
- `the_will_2026-10-04_02-23-28.log`: 560 solver-selection checks pass, including
  real circle and saved-wrapper point queries within long edges, raw-to-prepared
  target integration, ambiguous-nearest/valid-point cases, reversed endpoint
  correspondence, sliding/reselection, unchanged
  physical records and the actual projection loop's fallback/completion/budget
  control. Those loop cases use explicitly mocked geometry and derivatives;
  they do not prove a full character grip.
- `contact_preference_point_queries_2026-10-04T02-11-19.json`: 39 point-query
  checks pass, with independent full-edge safety unchanged.
- The provenance verifier previously passed 89 checks at 01:48:43.

The complete frozen two-hand fixture was then run twice to natural completion:

| Explicit test strength | Right duration | Left duration | Final full-hand safety |
|---|---:|---:|---|
| 0.10 | 13.651 s | 15.922 s | Fails both hands |
| 0.00 | 12.022 s | 12.237 s | Fails both hands |

Reports: `contact_driven_preparation_2026-10-04T02-18-55.json` and
`contact_driven_preparation_2026-10-04T02-12-41.json`. Both have 83 checks and
the two final material-safety failures. Preference changes 27/37 chosen rows;
it is not an inert setting. However, the changed right-hand placement also
leaves Index unsafe, in addition to Ring/Pinky that fail with strength zero.
Left Ring/Pinky fail in both. Preferred interior points are selected 6/15 times;
231/293 point queries complete with no invalid-target query failures. This is
a measured outcome difference, not a successful-grip or performance claim.
Native full-skin safety remains active
and no candidate is written to gameplay by this frozen-input tool.

The earlier 02:11:38 preference report is superseded for integration evidence:
review found that wrapper point attraction was receiving a raw slice instead
of the prepared target, so those candidates were silently skipped. The solver
now retains `prepared_contact_targets` from its normal contact preparation and
uses that packet for points and translation probes. Source lookup also stays
independent of the ordinary nearest witness's ambiguity; a different point on
the same source edge can have a valid normal. Point-query failure counters make
any future omission visible. The 02:18:55 run includes those corrections.

The game default is now 0.5 after the user's confirmation; `NEEDS_DECISION`
has been removed. `configure_contact_preference()` supports isolated verification; the
existing preparation runner accepts `THE_WILL_GRIP_PREFERENCE_STRENGTH` only as
a test override. Existing physical rows, contact reporting and caps remain
authoritative. Preferred-source reporting is labelled as a candidate for the
next response, not a physical contact verdict.

Fresh 50% actual-save result: `live_saved_wrapper_grip_2026-10-04T02-34-06.json`
and `godot_runs/the_will_2026-10-04_02-34-00.log`. Natural Skill Crafter weapon
and Skill 1 activation, rendered D3D12 run, actual default (no test override),
workspace-isolated user data. 77 checks pass; `preview_applied` occurs naturally.
Measured current skin is material-safe, articulation-valid and has six distinct
contact sections: Middle S3, Thumb S3, Index S2/S3, Ring S3, Pinky S3. No unresolved
digits. The upstream local poses remained unchanged during acquisition.
Solver metrics confirm strength 0.5, 243 selected preference rows, 143 changed
rows, 59 chosen interior points and 549 point queries with no query failures.
Numerical solve 27,283.677 ms; full verifier 51,781.831 ms, including loading,
actual-pose assessment, screenshots and controls. Timing includes instrumentation.

Refresh, small Tip/Pommel moves, +20/-20 degree Roll and an over-limit Pommel
request all actually moved the weapon in this run. They retained the bound
hand/weapon relation within the verifier's guards; digit rotation error is zero.
This confirms the tested motions, not every possible pose or continuous 3D
collision state. The verifier explicitly retains `whole_hand_3d_contact_certified`
false. Rendered closeup B was inspected: fingers visibly close around the handle;
closeup A is occluded, and the thumb is not fully exposed for visual judgement.
The source library SHA256 remains
`1d388e0f20bd997c903448b99c55527ab7fa845fc3c160d70257ed067d4461b4`.
Chronology `grip_bias_50_live_20261004_0234_chronology.jsonl` closes with zero
open spans (14,343 records). The Godot verifier terminated normally.

The focused selection suite also passed 560 checks at 02:33:05; it explicitly
uses test strength 0.1. Its reporting now names the active live default separately
from whether the verifier itself changed that default, to avoid conflating them.

Baseline carried forward, not rerun as preference verification:
`live_saved_wrapper_grip_2026-10-04T00-29-20.json`, actual saved
`Star_Handle_Testing Copy`, solver 25.149021 s. Material attribution no longer
rejects face 0/4216; terminal reason is `source_pose_changed_during_acquisition`.
No pose was applied. Middle S3, palm and Pinky S2/S3 predictions are partial; the report
does not establish a finished full-hand grip. Source-save hash stayed unchanged.
This pose lifecycle issue is distinct from the requested location preference;
do not bypass the source-pose check to report success.

Official version-matched references reviewed before implementation:
[Geometry2D](https://docs.godotengine.org/en/4.7/classes/class_geometry2d.html),
[Curve2D](https://docs.godotengine.org/en/4.7/classes/class_curve2d.html), and
[ArrayMesh](https://docs.godotengine.org/en/4.7/classes/class_arraymesh.html).
Native geometry helpers do not supply the anatomical contour ownership or
influence-transition coordinates; those are derived from existing source data.

Next: user visual review of the current 50% result; any change to 90% is a later
tuning decision. Keep this tested setup distinct from universal grip acceptance. No Git
operation or new SPS is implied by this implementation request.

### October 4: compiled repair verified; partial palm boundary is the next blocker

User approved the previously requested `C:/Windows/System32/cmd.exe` helper for
the existing native link step. CMake/Ninja/Clang rebuilt the grip DLL using the
existing workspace bindings. SHA256:
`cd7645f9226510b9f0ce883a6b8aad2d91460306c8941a450ea882364eae4899`.
No installation, Git mutation or source-save mutation. The 40-iteration edit,
all physical caps, authored angular ranges and seating ownership are preserved.

Fresh reports under `test_artifacts`:

- `native_section_kernels_2026-10-04T00-07-24.json`: 37 repaired-capture checks
  pass, including compiled/reference parity and complete closed topology.
- `native_section_kernels_2026-10-04T00-07-42.json`: 432 regression checks pass.
- `verify_prepared_weapon_plane_section_2026-10-04T00-08-08.json`: 161 checks pass.
- `live_saved_wrapper_grip_2026-10-04T00-08-25.json`: current saved Star Copy
  naturally enters the real UI/worker route, then rejects the proposed pose.
  51 checks, three acceptance failures; solver 17.123 s, whole verifier 39.707 s.
  Numerical work is native with zero fallbacks. No manual pose injection or
  successful full-hand grip. Original workspace library hash remains unchanged.

The closed-slice repair is confirmed. The new terminal reason is
`no_pose_within_material_overlap_limits`, not a slice failure. Middle S3/palm
and Pinky S2/S3 have predicted contact, but Thumb/Index/Ring are unresolved.
Both Thumb and Index final slices intersect unassigned source skin face
`0/4216`, at material lower depths 2.386602 / 2.408111 mm and upper bounds
2.400166 / 2.441038 mm. Unassigned tissue correctly retains zero allowance.
The solver's proposed pose is not written to the live character; observed
upstream local poses stay unchanged. Motion checks are consequently skipped.

Read-only ownership investigation establishes:

- Source vertices are 2408, 2424, 2420, with mixed Hand/Index1/Thumb2/Ring1
  influences. No digit has majority ownership at those vertices.
- The source face enters palmar annotation, but both entire observed intervals
  lie outside the wrist-Index1-Pinky1 bone triangle. Opposite-Pinky barycentric
  coordinates at the endpoints are Thumb -0.173478/-0.193307 and Index
  -0.160618/-0.075367. This is not a tiny numerical boundary fragment.
- Middle does not intersect face 0/4216 and does not grant it a conflicting
  allowance. Its palm contacts use other faces. The exclusion follows the
  current partial-core rule; it does not prove that this tissue is non-palm.

The user subsequently confirmed: positively identified palm-facing Thumb-Index
webbing uses the existing 2.5 mm palm allowance. Do not grant every unassigned
face an allowance or silently borrow a Thumb allowance. Even a resolved overlap
blocker does not prove all follower contacts will complete.

Bounded implementation: `prepared_palmar_slice_region.gd` keeps the old core
triangle and adds source-face domains only where original Hand, Index1 and
Thumb1/Thumb2 influences are all positive, external-hand influence is absent,
and the point lies on the thumb side of Wrist-Index1 within the existing
wrist-to-knuckle longitudinal band. Existing positive-side/first-positive
visibility and occlusion tests still apply. No hull, padding, Thumb3 extension
or face-ID whitelist. Both selected and foreign digit section ownership take
priority over palm annotation. New region revision is
`clipped_reference_palmar_core_and_web_regions_v3`; prepared anatomy is unchanged.
The exact captured edge intervals satisfy the source support/side/band gates;
runtime visibility, downstream derivative and grip outcomes remain to verify.
Official Godot 4.7 Geometry2D intersection/clipping documentation was reviewed.

Visual artifact:
`live_saved_wrapper_grip_2026-10-04T00-08-25_candidate_slices.html` renders the
five exact final candidate planes from the report, highlighting 0/4216 in red.
It is explicitly a rejected numerical candidate, not an applied gameplay pose.
Generated from the existing panel renderer; browser interaction was not run.
The rendered in-game closeup_b PNG was inspected and shows the open hand.
Chronology: `grip_native_weld_live_20261004_0008/chronology.jsonl`; natural
completion, 9,882 records, zero open spans. Timing includes instrumentation.

Verifier limitation found during read-only review: full-hand completion checks
the four followers explicitly but does not itself require a Middle contact.
Always inspect Middle's actual count too; this run fails well before that gap
could affect a success verdict. Motion checks can also pass a rejected/no-op
control request; individual motion rows remain necessary evidence. Neither
condition was altered in this focused compiled repair.

### October 3: deterministic slice welding, reference verified / native build pending

User approved read-only external Git. Status/history/diff were inspected with
`C:/Program Files/Git/cmd/git.exe`; no index/history changes. Existing 20-to-40
iteration edit, settings, unrelated directories and test artifacts preserved.

The exact failed Star Copy query is now captured opt-in from
`prepared_weapon_plane_section.gd` into binary packets. Set
`THE_WILL_GRIP_SLICE_FAILURE_DIR` under workspace test artifacts; at most eight
packets per section owner, no default I/O or changed geometry acceptance.
`contact_driven_grip_preparation.gd::diagnostic_snapshot()` and the worker in
`saved_wrapper_grip_acquisition.gd` preserve counters/revision/time on early
failure and cancellation. Fresh rendered report
`test_artifacts/live_saved_wrapper_grip_2026-10-03T23-45-08.json` still fails the
same Pinky slice, but now truthfully reports native work and solver time.
Capture I/O is included; this is not a performance comparison.

`test_artifacts/grip_slice_capture_20261003_2345/` contains the chronology and
two immutable `slice_failure_*.bin` inputs. Replay via
`tools/grip_plane_proof/run_native_section_kernels.gd` with
`THE_WILL_GRIP_SLICE_REPLAY_DIR` compares native/reference, indexed/full source
and reconstructed graph stages. Report
`native_section_kernels_2026-10-03T23-52-38.json` passes 30 diagnostic checks,
including binary-identical reconstructed segments/contours. This PASS reproduces
the failure; it is not slice or grip acceptance.

Confirmed cause, before clipping:

- Pinky raw intersection is first assigned ID399, then the identical point is
  reassigned ID402 after another neighbour bucket gains a representative.
  Both representatives meet the same 5 micrometre distance bound. Bucket search
  order chooses the newer one and collapses triangle42282, leaving a 7.093353
  micrometre open gap.
- Middle raw crossing is only 3.72529 nanometres from existing ID74, but the
  earlier searched bucket returns newer ID75 at 4.999556 micrometres. Triangle
  32423 collapses and leaves a 5.002345 micrometre gap.
- Disk clipping contributes no endpoint movement/collapsed/discarded edges to
  either failure. Native and reference share the defect; source filtering does
  not omit the missing connection.

Fix: `core/resolvers/primary_grip_seat_resolver.gd` now selects the lowest existing
compatible representative ID across all neighbour buckets. The identical rule
is prepared in `native/grip_contact/src/grip_slice_kernel.cpp`. Merge radius
stays 0.005 mm; plane tolerance, material/guide caps and joint ranges unchanged.
This corrects the demonstrated representative-selection defect, not all possible
mesh/slice degeneracies. The shared resolver also serves handle centering.

Fresh reference-only proof: `grip_slice_capture_20261003_2345/reference_repair.json`
passes both unchanged captured inputs through the reference slicer and complete
prepared-section gate. Middle has 414 segments, Pinky429; both have one contour,
zero abnormal vertices and valid complete topology/centroid. Existing primary
grip slice-center follower and Forge V2 exact Handle grip-surface verifiers pass
(logs `the_will_2026-10-03_23-55-50.log`, `the_will_2026-10-03_23-57-27.log`).
Earlier instrumentation-only prepared-section regression passed161 checks in
`verify_prepared_weapon_plane_section_2026-10-03T23-47-46.json`; rerun after the
compiled correction. Focused `git diff --check` passes.

Native rebuild is pending a separate permission: the supported workspace
CMake/Ninja/Clang build invokes `C:/Windows/System32/cmd.exe` for DLL linking.
The user has not yet answered that exact application request. All compiler,
binding and source files are inside the workspace; no installation is needed.
Existing DLL still has SHA256
`dfa51ae084f3ddd150dd455ee20d8f9f22655c9ea962e62dd6b9ce3ea297d512`.
Do not claim runtime C++ repair, native parity after correction or full grip.

After approval: use the documented prebuilt-bindings native build, then replay
the two captures with `THE_WILL_GRIP_SLICE_REPLAY_EXPECT_CLOSED=1`, run the full
native section regression with replay variables unset, and rerun exact saved
Star Copy through the natural rendered live verifier. Repaired replay also
checks complete simple topology with both kernels. Follow any next observed
blocker rather than loosening caps or assuming this closes the entire grip task.

### October 3: actual current-save rendered verification

The user approved reading/copying the current external Forge library and
explicitly approved Windows PowerShell for inspection, the copy and launching
workspace tools. No source code was changed in this continuation. The existing
40-iteration allowance and authored angular ranges were preserved. No further
optimization, source-save mutation, Git mutation or native rebuild occurred.

Approved source:
`C:/Users/ixro1/AppData/Roaming/Godot/app_userdata/The Will-Gamefiles/forge/player_wip_library_state.tres`.
Immutable test copy:
`test_artifacts/live_grip_current_save_20261003_232851/player_wip_library_state.tres`.
SHA256: `1d388e0f20bd997c903448b99c55527ab7fa845fc3c160d70257ed067d4461b4`.
The adjacent `source_provenance.json` records size, timestamps and matching
source-before/source-after/copy hashes. All verifier runs confirmed the copy
unchanged and disabled persistence in their isolated user directories.

All three runs used `verify_live_saved_wrapper_grip.gd`, the supported launcher,
Godot 4.7, rendered D3D12 and the real Skill Crafter weapon/Skill 1 handlers.
They finished naturally; none was interrupted or given an injected solved pose.

| Exact saved weapon | Fresh report under `test_artifacts` | Result |
|---|---|---|
| `Star_Handle_Testing` | `live_saved_wrapper_grip_2026-10-03T23-30-06.json` | No saved wrapper. Rejects `saved_weapon_requires_forge_wrapper_save` before the worker starts. |
| `Star_Handle_Testing Copy` | `live_saved_wrapper_grip_2026-10-03T23-31-06.json` | Worker runs for about 15.5 s, then `saved_surface_section_failed`: Pinky `digit_target` has 428 emitted segments, zero closed contours and two open/branched vertices. No pose applied. |
| `Handle_test_1` | `live_saved_wrapper_grip_2026-10-03T23-35-52.json` | 77 checks, one failure: incomplete full hand. Solver 17.177 s; owner acquisition plus assessment 21.037 s. Safe partial pose applied; Thumb/Ring unresolved. |

Handle_test_1 has realized Middle/S1/S2/S3, palm, Index/S3 and Pinky/S2/S3
contacts. Actual planar material safety, articulation, freshness and unchanged
non-digit local bone poses pass. Six subsequent refresh/Tip/Pommel/Roll/limit
checks preserve the applied binding and all 15 rotations. This does not certify
a finished grip or whole-hand 3D enclosure. Rendered close-ups were inspected;
the report remains FAIL. Its 34.880 s total verifier duration includes scene
startup, acquisition, capture and controls, and is not the solver duration.

Chronologies beside the copied save are `original_star_trace.jsonl`,
`prepared_star_trace.jsonl` and `handle_test_trace.jsonl`. The prepared Star
trace proves 262 native contact batch calls before failure. Its terminal summary
incorrectly loses accumulated backend statistics on the solver's early return;
the default false/zero fields are not evidence that native work did not run.
Handle_test_1 records 388 native contact batches and 564 native slices/topology
calls, with zero fallbacks.

The Star Copy has the original's exact handle-body signature but is a distinct
saved WIP with differing cached conventions/material volume; never silently
substitute it for the original. Both wrapped saves carry current character
identity and guide configuration. Cached `primary_grip_valid` on all three
describes handle validity, not wrapper availability or successful acquisition.
The original's existing explicit Forge Save/Save As route prepares a missing
wrapper; that re-save has not been run on the user's source.

Narrow next investigation: capture the exact failing Pinky wrapper query and
compare native/reference intersection and contour construction on identical
triangles/plane. Current counts establish graph-closure failure before topology
preparation, but do not distinguish a source crack, proximity-weld branch or
near-plane numeric issue. Do not patch geometry/tolerances based on that guess.
The same trace also records an earlier Middle translation-probe failure with
413 segments and two abnormal vertices (sequence 1509-1512); this is not proven
to be a Pinky-specific anatomy defect. The existing
`tools/grip_plane_proof/run_native_section_kernels.gd::_compare_slice` is the
appropriate replay seam once exact failing packets are available. Compare
indexed and full-source triangles separately, preserving traversal order.
Preserve metrics on early failure so the terminal report matches the chronology.
Separately, Handle_test_1 Thumb proposals encounter the retained Middle palm's
2.5 mm cap (some uncertain bounds, some proven excess); Ring proposals lose
retained palm contact. Neither termination proves physical impossibility. Do
not relax overlap/angular limits or change seating strategy to make them pass.

Repository metadata read directly from `.git` files shows branch
`recovery/stable-92b8a24-chat14`, HEAD
`2cc0f40e48799571dc69d78cef92e54ed34f59ec`. This is newer than the October 1 SPS.
Read-only use of `C:/Program Files/Git/cmd/git.exe` was requested but remains
pending. Working-tree status has not been inspected; do not assume it is clean.
The new AGENTS external-application rule and required pre-edit status check
must be satisfied before code changes. PowerShell authorization does not cover
Git, rg, Python, compilers or other external executables.

### October 1: current priority - live saved-wrapper grip validity

User paused further timing optimization and explicitly requested the current C++
method to function in game. The 11-second result is a usable intermediate timing
target, not permission to hide functional failure. Current work replaces the
live primary acquisition/application path, preserves fixed Hand/wrist/upstream
ownership and verifies the actual realized grip and movement retention.

Correction to the preceding SPS and chat: the frozen preparation already
attempts all five digits. Only Middle and Thumb responses are retained; other
followers have material-safety or retained-contact failures. The 11-second
duration is not merely a two-digit workload. No full-hand success was proved.

Implementation boundaries: expose the already saved Forge wrapper and exact
handle packet from the equipped item; extract the accepted preparation context
into a shared runtime owner; run the existing contact-driven preparation in an
owned cancellable worker; consume its explicit final weapon frame in
`preview_grip_acquisition.gd`; retain existing finger binding, motion retention
and post-modifier realized assessment. Existing support ownership is unchanged
in this primary integration step. No new optimization, Forge bake or blanket
legacy cleanup. Prepared source/config/origin checks remain authoritative.

Verification will use the real Skill Crafter weapon/skill handlers with no
injected solved pose, record native backend activity, full-hand contact/safety
and articulation outcomes, and capture the rendered viewport. Movement checks
follow an actually applied valid result. Current workspace user-library copy is
older and lacks a wrapper; permission to copy the user's current external save
was requested. Until answered, use only existing workspace saved-wrapper inputs.

Current implementation/evidence, before the next palm-boundary verification:

- `saved_wrapper_grip_source.gd`, `saved_wrapper_grip_context.gd` and
  `saved_wrapper_grip_acquisition.gd` are the primary native acquisition bridge.
  `ForgeSavedGripSourceOrigin` traces original Forge meters through the equipped
  visual offset to `WeaponRootOrigin`; the mesh and both guide surfaces share it.
- Actual Idle bone translations differ slightly from imported rest. Each request
  freezes its existing local dimensions; candidate and recaptured articulation
  use that same reference without moving bones or modifying prepared anatomy.
- All five realized digit planes are checked. A safe open follower is reported
  as unresolved, not promoted to success by Middle/Pinky's contact count.
- Natural rendered report `test_artifacts/live_saved_wrapper_grip_2026-10-01T04-25-36.json`
  is deliberately FAIL: four safe contacts, valid actual articulation, but Thumb,
  Index and Ring unresolved. Solver 20.891 s; terminal owner duration 26.016 s.
  Six subsequent movement checks retain the applied relationship/15 rotations.
- Source-frame verification: 461 checks; frozen candidate geometry: 1323;
  saved-wrapper contact/foreign-section caps: 118; cross-digit skin derivatives:
  700. Exact report paths belong in the next SPS. None certify full grip.
- Follower trial validation preserves previously acquired shared-skin contacts.
  Analytic cross-digit constraints predict those effects, then full nonlinear
  checks verify each proposal. No physical caps or reseating budgets increased.
- Fresh trace exposes a numerical palm-boundary defect: ~12–25 nm endpoint
  fragments on faces `0/4202` and `0/4204` become unassigned zero-cap skin due to
  source barycentric roundoff. They block Thumb at an otherwise permitted palm
  overlap. Correct source-boundary classification; do not grant arbitrary skin
  allowance or redesign the closure sequence to bypass this defect.

Continuation: source-boundary correction passed 4493 focused checks. The 04:40:34
rendered rerun now retains Middle/Index/palm contact, but remains FAIL for complete
grip: Thumb hits the genuine palm-cap check; Ring/Pinky exhaust the existing
iteration budget. Actual safety/articulation pass; all non-digit local poses
remain unchanged after macro positioning and all six motion-retention checks
pass on the partial pose. Solver 24.912 s, owner duration 30.000 s. These are
current timings, not the earlier isolated 11-second measurement. No full-grip
claim and no further optimization. Test the user's current weapon after the
pending external-save-copy permission before changing the seating strategy.

### October 3: user-authorized projection allowance experiment

User explicitly requested doubling the search allowance and clarified that the
authored allowed joint-angle ranges are already optimized and must remain fixed.
The only solver edit is `PROJECTION_ITERATIONS := 20` to `40` in
`runtime/player/grip/contact_driven_grip_preparation.gd`. This is a separate
allowance for each projection call: Middle circle, saved-wrapper matching,
reseating, and each follower. Early completion, cancellation, safety rejection
and no-improvement exits remain active. Reseat count, angular ranges, calibration,
joint axes, step sizes and physical contact/overlap caps are unchanged.

Fresh verification uses natural headless acquisition of the existing workspace
`Prepared target straight` saved-wrapper fixture, isolated user directories and
no injected solution. Movement checks were explicitly disabled. It does not
verify the user's external current save or a rendered interactive grip.

| Fresh report under `test_artifacts` | Solver / owner duration | Result |
|---|---|---|
| `live_saved_wrapper_grip_2026-10-03T22-02-23.json` (20) | 21.045 / 25.108 s | 27 checks, one failure: incomplete full hand. Safe partial pose applied; Thumb/Pinky exhausted their projection allowance. |
| `live_saved_wrapper_grip_2026-10-03T23-11-10.json` (40) | 28.113 / 30.273 s | 27 checks, three failures: no pose application, no eligible actual grip acceptance, incomplete full hand. Final predicted material safety rejected. |

The two runs have exactly matching recorded initial/acquisition hand and weapon
transforms, all 15 digit rotations, upstream local poses, all five prepared digit
planes, root/source records, library hash and handle-body signature. There is no
weapon-roll difference between these two October 3 inputs. The separate October 1
rendered capture differs from the 20-step headless fixture by approximately
22.063 degrees of weapon roll; its outcome is not a controlled budget comparison.

With 40 allowed, actual loop counts were Middle circle 19, Middle wrapper 40,
Middle reseat 1, Thumb 36, Index 4, Ring 29 and Pinky 28 (157 total). Thumb retains
a predicted S2 contact and Ring retains S3; Index is unsafe/unaccepted and Pinky
has no accepted contact. Most passes still exit before exhausting the allowance.
The final Index-plane assessment finds off-digit shared skin from
`CC_Base_R_Thumb2`, sources `0/4211` and `0/4212`, with material-depth lower bounds
1.184728 and 1.942696 mm, exceeding their unchanged 1.08 mm allowance. These are
predicted slice bounds, not an observed unsafe applied hand or 3D certification.
The application owner rejects `no_pose_within_material_overlap_limits`; false
actual-acceptance fields reflect the absence of an applied eligible grip.

The preceding October 3 origin investigation found no inconsistent recorded
root propagation in the compared captures/contact-query snapshots. Its evidence
is under `test_artifacts/origin_audit_20261003_215800/`; captured-chain checks do
not independently certify anatomical calibration. The 40-step trace is
`test_artifacts/grip_budget40_20261003_231106/grip_chronology.jsonl`.

The user-authorized allowance remains 40 locally. No joint-range workaround or
further seating/constraint change is authorized by this experiment. Full-hand
validity still needs investigation of the coupled shared-skin safety/retained
contact result, without relaxing authored joint ranges or material limits.
This edit is separate from the already pushed V5.1 savepoint
`2cc0f40e48799571dc69d78cef92e54ed34f59ec`; it has not been staged or pushed.

### October 1: complete contact evaluation in C++ - selected and verified

User selected the C++ consolidation approach. This bounded slice moves the
complete `saved_wrapper_skin_contact.gd` prepare/evaluate boundary into the
existing grip extension: ordered targets, material and digit/palm guide batches,
depth decisions and normalized contact witnesses. The existing numerical segment
kernel remains the single calculation implementation used by the new batch;
the selected backend does not also run the old script path. No geometry,
per-section allowance, depth bound, pose sequence or body ownership change.

New owners: `GripSavedContactKernel` and `prepare_grip_ordered_target` under
`native/grip_contact/src`. GDScript keeps a thin explicit backend selector.
Native prepared data is instance/acquisition owned and bounded; exact identity
checks must reject stale/mutated data. The new batch bypasses the old serialized
segment-result cache, so actual work/cache counters may differ. That is not a
license for different logical depth results, contact choices or final poses.
The original backend remains selectable for parity and timing comparisons.

The complete batch is now selected by default. `THE_WILL_GRIP_CONTACT_BATCH=0|1`
selects the comparison in the existing runner; `CONTACT_BACKEND=gdscript` uses
the retained reference. Ordinary calls run one backend. Geometry caches are
acquisition-owned, each bounded to 64 entries, with at most 192 native targets.
The numerical configuration remains the proven 0.01 mm depth bound.

Current evidence under `test_artifacts`:

- `native_saved_contact_2026-10-01T03-37-19.json`: 522 checks passed. Full packets,
  actual saved slices, caps/ties, mixed signed zero, stale/mutated inputs, exact
  warm reuse, eviction and reset. Four captured cold component medians are
  11.3-16.1x faster than the script reference; not whole-hand timings.
- `saved_wrapper_skin_contact_2026-10-01T03-35-10.json`: 107 mature checks passed
  on the selected default; old adapter cache checks remain explicitly selected.
- Fresh control `contact_driven_preparation_2026-10-01T03-20-39.json`:
  80 checks, right 15.397612 s, left 16.942334 s.
- Final default `contact_driven_preparation_2026-10-01T03-35-22.{json,html}`:
  79 checks, right 11.170773 s, left 11.322146 s, zero fallback. About 30.5%
  combined time saved in this comparison. Counts differ because explicit backend
  override validation is absent from the final no-override run.
- `complete_native_contact_default_comparison_2026-10-01.json`: all 156,089
  compared values match exactly, excluding timing/backend execution statistics.
  Geometry, final poses, contact choices, iterations and logical counts match.
- `grip_complete_batch_default_20261001_033520_448.{jsonl,summary.json,html}`:
  12,523 records, natural completion, no issues/unclosed spans, 29.511 s whole
  cycle including context/section setup and report work.

Port review caught and corrected two issues: canonical signed-zero bounds must
retain Godot's MIN/MAX tie semantics; untyped container script metadata is a
null Object, so recursively rejecting Object values disabled cache hits.
Container schema equality now uses Godot's `is_same_typed`; all actual data
still compares exact type/component bits and source order. The focused verifier
initially lost negative-zero fixture bits through literal constant folding;
it now constructs them from the IEEE-754 byte pattern and all checks pass.
Final prepared/native section hits are 115 right and 119 left. Mutable
noncanonical internal packets are rejected explicitly, a stricter malformed-
input contract than the reference's unchecked internal fields.

The inclusive saved-contact prepare/evaluate cost is now 3.303 / 3.220 s,
previously 8.001 / 8.522 s. Its nested preparation subtotal is 0.307 / 0.316 s;
do not add that again. Candidate pose cost is 1.595 / 1.531 s, skin slicing plus
palm annotation 2.353 / 2.228 s, saved weapon sections 2.030 / 2.066 s. These
boundaries identify the remaining work. The initial post-port run at 03:25:44
also matched exactly but preceded the cache/sign-bit fixes; final evidence above
supersedes it. Current DLL SHA256:
`dfa51ae084f3ddd150dd455ee20d8f9f22655c9ea962e62dd6b9ce3ea297d512`.

The two-second target is not met. Existing isolated results still have two
accepted sections per hand, below three; no grip acceptance is newly claimed.
No live manual run was performed. Section and lower-level numerical verifiers
from the preceding SPS were not rerun; the new full packet tests exercise that
same numerical code through the batch. Git remains untouched.

The live result-application mismatch described below remains an explicit next
integration boundary. This numerical port does not silently substitute a new
live acquisition owner or claim to fix the failed manual game test.

### October 1: two-second target research and failed live baseline

Current user direction: research outside information that fits this workload;
bring acquisition to **two seconds or less**. The user also explicitly reports
that the last actual-game test failed to produce a successful visual grip.
The objective is a visibly working grip with that duration, preserving the
accepted contact model and ownership. A fast rejected or unapplied pose is not
success. This entry records research and a proposed sequence, not implementation
or a new performance result. No engine run was made during this research pass.

**Measured baseline and scope.** Historical current-code evidence remains
`contact_driven_preparation_2026-10-01T02-15-26.json` and
`grip_section_native_chronology_2026-10-01T02-15-00.jsonl` under `test_artifacts`.
Right/left preparation took 14.652 / 15.379 seconds. This is the isolated
middle/thumb preparation, not a timed successful five-digit gameplay grip.
Both cases still report two accepted hand sections and
`minimum_hand_contact_count_met=false`. Material safety and exact numerical
parity do not establish grip completion. The current live owner is still
`preview_grip_acquisition.gd` -> `handle_grip_acquisition.gd`; the proof runner
uses `contact_driven_grip_preparation.gd`. That difference is established, but
does not by itself diagnose the user's last visual failure.

The live application contract also differs: `apply_primary_result()` consumes
the old hypothetical hand translation and seats the weapon with
`base.origin - translation`, checking the old
`rigid_captured_pose_world_translation` packet. The new solver keeps the hand
fixed and returns the actual seated weapon frame in `selected.weapon_to_world`;
its candidate hand translation is zero. A class substitution would therefore
reject the packet or lose/misapply seating. Explicit integration must consume
the new final weapon frame, retain its basis and named origin chain, and derive
the hand/weapon binding from that final frame. Preserve atomic application,
cancellation and stale-result checks, then assess the recaptured realized hand.

Contact preparation/evaluation costs about 7.7 seconds per measured hand. Its
31,169 / 31,467 native segment calls total 0.897 / 0.913 seconds, including
conversion. Cache key/result/target serialization costs 1.448 / 1.420 seconds
within the contact stage. Native target construction is only 0.026 / 0.028
seconds. Therefore simply keeping native targets alive longer is insufficient;
the useful change is keeping more work and data together. Eliminating only the
native arithmetic cannot remove the surrounding seconds. Whole-trace writer
cost is 0.711 seconds across both hands and setup; logging is not the primary
explanation. These nested timings must not be added as disjoint costs.

**Research finding: batch and retain data before choosing more hardware.**
[Godot 4.7 CPU optimization](https://docs.godotengine.org/en/4.7/tutorials/performance/cpu_optimization.html)
supports compiled heavy calculations and contiguous data access. Our next
useful numerical boundary is a complete contact evaluation, rather than one
script/native call per skin segment. Convert inputs once; perform the ordered
segment loop, physical/guide measurements and witness work in native storage;
return the result together. Keep immutable prepared geometry in a bounded,
acquisition-owned context. Do not assume changing planes or translated oblique
sections have unchanged geometry. Existing triangle indexing and section caches
already provide some reuse; extend measured gaps rather than adding another
parallel cache blindly.

[libigl's geometry-query guidance](https://libigl.github.io/tutorial/#signed-distances)
also recommends retaining search structures when geometry is static and query
points change. This is supporting design guidance, not a proposal to install
libigl or replace our contact semantics. Godot's
[physics-space queries](https://docs.godotengine.org/en/4.7/classes/class_physicsdirectspacestate2d.html)
return intersections/contact information, but are not a direct replacement for
our complete per-section depth bounds, ambiguity and witness-selection contract.

**Parallel CPU/GPU options.** Independent segments of a fixed pose can run
together. Later poses depend on earlier accepted contacts, so the approximately
31,000 calls cannot all become one simultaneous job without changing the solve.
[WorkerThreadPool](https://docs.godotengine.org/en/4.7/classes/class_workerthreadpool.html)
provides grouped work but warns that small tasks may become slower. A background
thread alone improves responsiveness, not necessarily completion time. Native
workers would need immutable inputs, separate output ranges and ordered result
reduction; the current mutable target table and last-timing fields must not be
shared concurrently unchanged. Respect
[Godot thread safety](https://docs.godotengine.org/en/4.7/tutorials/performance/thread_safe_apis.html)
and publish scene poses through the existing main-thread owner.

[Godot compute shaders](https://docs.godotengine.org/en/4.7/tutorials/shaders/compute_shaders.html)
fit the current Forward+ renderer family, but repeated GPU waits/readbacks would
sit between dependent solver steps. [NVIDIA's transfer guidance](https://docs.nvidia.com/cuda/cuda-c-best-practices-guide/index.html#data-transfer-between-host-and-device)
likewise favors resident data and batched transfers. GPU remains a later measured
option, not the chosen first implementation or a promised speed factor. A fair
comparison must include upload, dispatch, readback and the real dependency order;
31,000 unrelated replay queries in one artificial batch would be misleading.

**Next bounded sequence.**

1. Establish a real-game acceptance checkpoint through the existing chronology:
   one actual saved weapon, empty Skill 1, solver result, pose application and
   recaptured realized hand. Distinguish rejection, stale-job discard, unapplied
   pose and realized contact failure. Do not infer the last failure's cause or
   quietly replace the live owner while profiling the isolated tool.
2. Optimize the chosen shared evaluator at `saved_wrapper_skin_contact.gd`
   (`prepare`/`evaluate`), `native_cached_planar_skin_overlap_budget.gd`, and
   `native/grip_contact/src/grip_contact_kernel.*`. Start with a complete native
   segment batch and acquisition-scoped data, then include the measured ordered
   target/witness work. Keep pose sequencing, physical caps and decisions intact.
   A paired cache-enabled/disabled comparison can determine whether the old
   serialized cache still pays for itself after compilation; its 10-12% hit rate
   and 12-13 table flushes are evidence to test, not proof to delete it.
3. Re-measure the whole path. Candidate skinning, slicing and palm annotation
   still cost roughly 3.4-3.6 seconds in the isolated case; they may need the same
   prepared native-data treatment. Select the next owner from the new trace.
   Do not stop after reporting a component speed factor.
4. Connect the accepted solver to the live owner through an explicit integration
   slice and verify all five digits, shared weapon placement, existing movement
   retention and support-hand ownership. Normal operation must select one solver.
   Retaining a reference implementation for proof must not run both on each grip.

Acceptance measures cold acquisition separately from cached reuse. Record input
preparation, solve, result application and time to visible completion; whole UI
loading/report generation remain separate scopes. The two-second goal applies
to a completed hand acquisition, not only one kernel or this two-digit fixture.
Check visual outcome and actual contact/cap decisions as well as elapsed time.
Retain the proven 0.01 mm internal depth bound: the prior 0.05 mm experiment
changed contact decisions, so user-visible precision tolerance is not permission
to weaken numerical guards. No source changes, new benchmarks, installs or Git
actions were performed for this research. The two-second outcome is unproven.

### October 1: compiled section calculations completed

User asked to move the remaining slicing/topology bottleneck into C++. This
bounded slice adds `GripSliceKernel` and `GripTopologyKernel` to the existing
grip extension. They port the existing `slice_reachable_surface.gd.slice` and
`skin_plane_contact_query.gd.prepare_target` contracts. Prepared weapon sections
select the backend; named-plane validation, triangle indexing, final centroid,
saved-wrapper ownership and the rest of the grip sequence stay in their owners.
The original script helpers remain reference implementations and an explicit
fallback. Normal calls run one selected implementation, never both.

Preserve vector/scalar precision boundaries, mesh traversal and welding order,
clipping, contour order, topology failures and diagnostic counts. No tolerance
changes, simplified contours, omitted checks or live acquisition-owner switch.
Add full-packet analytic/captured comparisons; run the existing section and
saved-section verifiers, then the current two-hand preparation to natural
completion with chronology and HTML. Compare every recorded pose/decision
against `contact_driven_preparation_2026-10-01T01-43-11.json` before selecting
the default. Measure native overhead and end-to-end cost, not compile time.

Official Godot 4.7 Geometry2D, Vector3 and CPU optimization docs reviewed again:
bulk numerical work fits the existing GDExtension boundary. It does not require
adding physics bodies or changing the contact model. Use the existing workspace
compiler/bindings; no new install, outside application, or Git action.

Implemented and selected C++ for prepared weapon sections. All 431 new kernel
checks passed, covering synthetic failures and clipping, 12 captured triangle
slices and 60 frozen topology cases. The original script helpers are unchanged.
The final default passed 161 existing prepared-section checks and 421 saved-section
checks (straight/curved assets, oblique planes, named origins and immutability).
Native rejection stays rejection; only missing extension classes use the counted
reference fallback. No duplicate normal calculation or skipped geometry checks.

Fresh reference-section full run `contact_driven_preparation_2026-10-01T02-13-41`
passed 72 checks; C++ section run `...02-15-26` passed 74. Both use the established
C++ contact kernel at 0.01 mm. Right 22.243 -> 14.652 s, left 23.967 -> 15.379 s:
about 35% less combined solver time. Full trace cycles 53.454 -> 37.194 s;
these include setup/verification/report output and are not the per-hand solve.
`native_section_pose_comparison_2026-10-01.json` confirms 156,181 existing case
values, including poses, decisions and work counts, exactly match the prior
01:43:11 result after excluding timings; backend counters are additional metadata.
Both hands retain their same two accepted sections and the same known limitation.

Solver weapon sections dropped 9.524 / 10.332 -> 1.862 / 1.971 s right/left.
Inside those new totals, triangle slicing takes 0.329 / 0.349 s, topology
0.556 / 0.584 s. Source queries remain 128 / 137; native slice/topology calls
383/382 and 411/411, with zero reference calls/fallbacks. Remaining largest
disjoint owners are saved-contact evaluation 5.476 / 5.411 s and saved-target
preparation 2.190 / 2.276 s. They include script validation/cache/serialization
and witness work around the already compiled segment kernel. No further port
or live acquisition-owner switch was included in this slice.

Evidence: `native_section_kernels_2026-10-01T02-15-03.json`,
`verify_prepared_weapon_plane_section_2026-10-01T02-17-35.json`,
`prepared_saved_grip_sections_2026-10-01T02-17-52.json`, and the two full reports
above, all under `test_artifacts`. Complete C++ chronology:
`grip_section_native_chronology_2026-10-01T02-15-00.{jsonl,summary.json,html}`,
13,948 records, no issues or unclosed spans. New native README documents APIs,
build provenance, exact scope and timings. No new Git action.

### October 1: compiled contact comparison completed

User approved the compiled contact benchmark and expressed interest in future
measured C++ optimizations. Current scope is the contact/penetration kernel only;
no broader port or live acquisition-owner replacement is implied.
User finished the manual game test and reported no visible grip after roughly
700 seconds, then closed the game. That is an observation of the older live
acquisition path, not a timing of this isolated saved-target preparation solver.
The compiled extension was activated only after that test ended.

Implementation boundary: a standalone `native/grip_contact` GDExtension owns
typed prepared target geometry and one complete numerical segment calculation.
The existing script still owns target validation, exact memoization, section
allowances, witnesses used by movement, stage order, and final grip decisions.
The thin `native_cached_planar_skin_overlap_budget.gd` adapter dispatches through
one cache-miss hook; `saved_wrapper_skin_contact.gd` selects it for the isolated
saved-target solver. One numerical backend executes per successful cache miss.
The script implementation remains the comparison/fallback; fallback use is
counted and forbidden in the C++ proof. Native targets are instance-owned and
released after each synchronous batch; the exact result cache retains its
mature validation, identity and transactional behavior.
Main-hand and support ownership and all named metric-plane origins remain as-is.

Verification: kernel proof passed 420 checks over 2,471 compared segments at
identical settings, with zero measured position/depth differences. The mature
exact-cache regression passed all 114 checks. Complete two-hand C++ preparation
at 0.01 mm passed 70 structural/configuration checks with zero native fallbacks.
All 156,165 compared baseline case values, including stage poses, contact
decisions and work counts, were identical after excluding timings.

Against the 00:31:21 GDScript experiment, right solve 52.504 -> 19.672 seconds;
left 59.618 -> 21.349 seconds (2.67x / 2.79x). Whole report cycle 120.533 ->
47.102 seconds; the separate full trace span including report output is 47.600
seconds. Do not mix these timing scopes. This is a full isolated preparation
comparison, not evidence that the user's 700-second gameplay wait is fixed.

The separate 0.05 mm depth-bound trial took 20.138 / 22.140 seconds. It altered
the trajectory and removed left Thumb S3 from the accepted contacts: its final
material gap changed from -0.274 mm to +1.908 mm. Final weapon placement shifted
0.111 / 0.698 mm right/left. Refinement tolerance feeds contact witnesses and
safety bounds; it is not cosmetic rounding or a bound on final-pose error.
Selected default: C++ with the proven 0.01 mm depth bound. Physical allowances
and numerical/topology guards remain unchanged. Runner overrides are documented
in `tools/grip_plane_proof/GRIP_CHRONOLOGY.md`.

Both retained 0.01 mm results still have two accepted sections, below the
existing three-section minimum. The optimization preserves this limitation;
structural PASS is not a claim of final gameplay grip correctness. Current
live acquisition-owner replacement remains pending.

Remaining measured solver cost: saved weapon sections 8.707 / 9.486 seconds
(128 / 137 calls), roughly 44% of each hand solve. Topology assembly and triangle
slicing are nested inside that cost. Native segment calls including conversion
take 0.788 / 0.825 seconds. A next narrow optimization candidate is section
slicing/topology with exact contour and pose comparisons, not a blanket C++ port.

Evidence under `test_artifacts`: `native_overlap_kernel_2026-10-01T01-32-20.json`,
`verify_exact_cached_planar_skin_overlap_budget_2026-10-01T01-33-50.json`,
`contact_driven_preparation_2026-10-01T01-34-49.{json,html}`,
`native_grip_comparison_001_2026-10-01.json`,
`contact_driven_preparation_2026-10-01T01-40-22.{json,html}`, and
`native_grip_comparison_005_2026-10-01.json`.
Complete chronology: `grip_native_001_chronology_2026-10-01T01-35-10` with
`.jsonl`, `.summary.json`, `.html`; 13,944 records, no unfinished spans/issues.

Final default-settings run `contact_driven_preparation_2026-10-01T01-43-11`
passed 67 checks with zero fallbacks; right 22.264 / left 24.706 seconds. All
156,181 compared case values except timings match the first C++ run exactly
(`native_grip_comparison_default_2026-10-01.json`). Use the observed range,
roughly 20-25 seconds per hand, rather than claiming a fixed duration. Its
`grip_native_default_chronology_2026-10-01T01-44-00` summary has 13,941 records
and no unfinished spans/issues. The existing saved-wrapper-contact verifier
also passed all 106 checks at 01:46:05 using the selected default.

Files: new `native/grip_contact/{CMakeLists.txt,README.md,grip_contact.gdextension,
src/grip_contact_kernel.h,src/grip_contact_kernel.cpp,src/register_types.*}`;
new runtime adapter and `tools/grip_plane_proof/run_native_overlap_kernel.gd`;
small dispatch/configuration changes to the existing cache, saved-contact owner,
preparation owner/runner; current work note and a new completion SPS.
Build uses the workspace compiler and validated already-built godot-cpp bindings.
No installation, outside-workspace Python invocation, Forge behavior change or
Git push is part of this experiment.

### October 1: contact-query research and required accuracy

User requested official Godot research into cheaper built-in contact/overlap
queries and compiled code. User then specified that geometric accuracy finer
than **0.05 mm (0.00005 m)** is unnecessary. This is the requested accuracy for
future optimization; it is not an extra allowance on any section's overlap cap.
Small numerical/topology guards must not all be replaced with that distance.
No solver code, precision setting, build, installation or live behavior changed
during this research.

Current `saved_wrapper_skin_contact.gd` requests a 0.01 mm depth-bound width,
64 evaluations per segment and no refinement after a cap has been decided.
Simply loosening that width can leave a cap-straddling interval unresolved; it
must not turn uncertainty into permission to penetrate. Future comparisons can
use the requested geometric accuracy while retaining cap and contact semantics.

The complete 00:31 experiment attributes 32.285 / 38.400 seconds right/left to
saved-contact evaluation, including 20.069 / 25.839 seconds finding nearest
contact and 4.737 / 5.393 seconds sampling/refining depth. These are nested
timings, not additive independent costs. Weapon sections take another
11.290 / 12.209 seconds. A precision change alone does not remove the dominant
nearest-contact work.

Official [Geometry2D](https://docs.godotengine.org/en/4.7/classes/class_geometry2d.html)
provides useful closest-point, segment and polygon operations.
[PhysicsDirectSpaceState2D](https://docs.godotengine.org/en/4.7/classes/class_physicsdirectspacestate2d.html)
offers overlaps/contact pairs, but not the complete current outside-nearest
witness plus whole-segment penetration bounds. Concave polygon collision shapes
are hollow; no collision against those cannot prove that skin is outside solid
material. These APIs are candidates for parts of the calculation, not an
established replacement for the existing section policy.

Recommended bounded next experiment: compiled contact/overlap computation using
GDExtension, with original prepared target geometry, cached work and section caps.
Keep loops inside compiled code; avoid a scripting/native call for every edge
pair. Compare against captured geometry and the current reference, measure total
cost including transfer, and retain current solver ownership/stage order.
The project already contains `native/forge_v2_manifold` and a workspace-local C++
toolchain; this is an existing build pattern, not permission to alter Forge.
No speedup factor or sub-250 ms solve is established by this research.
Official references: [CPU optimization](https://docs.godotengine.org/en/4.7/tutorials/performance/cpu_optimization.html),
[GDExtension](https://docs.godotengine.org/en/4.7/engine_details/engine_api/gdextension/index.html).

### October 1: four initial contacts, direct saved-wrapper experiment

After publishing checkpoint `15534caa` / `hand-overhault-v5.0-sub-optimised`, the
user requested a controlled sequence test. Add the existing identified neutral
palm region to Middle S1/S2/S3 on the initial circle. Keep Middle-owned transverse
weapon translation, orientation and fixed Hand/wrist/body rules. Attempt the
exact saved Forge V2 target directly, skipping intermediate circle radii and
late palm seating. Then run the existing bounded reseating, up to three attempts,
and the existing fixed-weapon followers. No new envelope, cap, contact checker,
generic optimizer or live controller change is part of this experiment.

Files: `runtime/player/grip/contact_driven_grip_preparation.gd`,
`tools/grip_plane_proof/run_contact_driven_preparation.gd`, its HTML view, and
this note/new SPS. Initial four-point attachment is measured, not assumed;
if unresolved, preserve that outcome and still attempt the saved target, as the
existing preparation path did. Do not silently loosen limits or reinstate removed
checkpoints to make the experiment look successful. Compare both captured hands
visually and record the complete timing trace.

Executed at 00:31:21. Both hands established all four initial circle contacts at
117.111 mm radius. Each went directly to the saved target, then attempted one
reseat; the unchanged no-improvement rule stopped further attempts. Each hand
records eight stages instead of fourteen. All 61 structural checks passed,
including exact saved target slices, unchanged caps, fixed Hand/wrist/orientation
and station, and the new direct stage order. Contact/numerical helper bodies and
the reseating/follower block are byte-identical to checkpoint 15534caa after
normalizing file line endings. This is not final contact equivalence.

Against the previous logged run (same frozen inputs and recording enabled):
right 49.048 -> 52.504 s (7.05% slower); left 68.982 -> 59.618 s (13.57% faster).
Combined solver time 118.031 -> 112.122 s (5.01% lower in this single comparison).
Whole capture including setup/reports 126.409 -> 121.268 s. The direct Middle
wrapper response itself is more expensive: 29.762 / 35.477 s right/left.
No general performance or behavior-preservation claim follows from this test.

The result changed: right retains Middle S2 + Thumb S3 (previously Middle S3 +
Thumb S3); left retains Middle S1 + Thumb S3 (previously Middle S1 + Middle S2 +
palm). Neither new result meets the existing minimum-three-section condition.
Measured Middle skin remains within its physical allowances. Initial palm contact
works, but final palm seating from the old left result is not preserved. Leave
this experiment visible for user review; no automatic retuning or rollback.

Artifacts under `test_artifacts`: `contact_driven_preparation_2026-10-01T00-31-21`
(`.json`, interactive `.html`, inspected `.png`),
`direct_wrapper_comparison_2026-10-01T00-31-21.json`, and
`grip_direct_wrapper_chronology_2026-10-01T00-32-00` (`.jsonl`, `.html`,
`.summary.json`). Chronology closed naturally with 13,934 records, zero issues
and zero unfinished spans. The generated HTML embeds the measured JSON exactly.

Official Godot 4.7 references checked before this slice:
[SkeletonModifier3D](https://docs.godotengine.org/en/4.7/classes/class_skeletonmodifier3d.html)
(pose modification/observation contract) and
[Time](https://docs.godotengine.org/en/4.7/classes/class_time.html)
(monotonic duration measurement).
No native modifier lifecycle or timing API change is needed for stage reordering.

### October 1: checkpoint before the user's next experiment

User requested a Git push named exactly `hand overhault v5.0 sub-optimised`.
Checkpoint tag: `hand-overhault-v5.0-sub-optimised`, on the existing recovery
branch. Preserve current source, prepared anatomy, tools and documentation,
plus required frozen diagnostic inputs. Exclude executables, test-result logs,
generated reports, toolchain/build caches, external game saves and unrelated
workspace projects. Exact-byte attributes protect hash-pinned fixture inputs.
This is a snapshot only; it does not implement the proposed next optimization.
The user has another experiment in mind. After the push, wait for that direction
before proceeding with the nearest-contact changes proposed below.

### September 30, 23:30: current visual and complete action chronology

User requested a current HTML visual first, then the existing action-duration
tool to find further timing reductions. Delivered the accepted 13:34 HTML and
rendered its current PNG; embedded JSON matches the measured result exactly.

The old UI chronology runner still follows live handle_grip_acquisition, not
the accepted isolated contact_driven_grip_preparation owner. A clarification was
offered. Pending further steering, the stated working assumption is to profile
the accepted solver shown in HTML. Reuse grip_chronology.gd and its summarizer;
observe the complete two-hand frozen-input diagnostic, without UI/live cutover.

Instrumentation only: run_contact_driven_preparation.gd, the existing isolated
owner, prepared_weapon_plane_section.gd and planar_skin_overlap_budget.gd.
Pair real cycle/phase spans, record outcomes/repetitions, split actual query
costs without per-edge log writes, and run to natural completion. Returned
solver packets, geometry, rules and budgets must match the 13:34 baseline.
Update GRIP_CHRONOLOGY.md to distinguish UI and accepted-diagnostic routes.
The complete capture finished naturally: 126.409 s including both fixtures and
report writing; solver time was 49.048 s right and 68.982 s left. It contains
20,857 records, zero parser issues and zero unfinished spans. Recorder write time
was 1.195 s; this is only measured write overhead, not all instrumentation cost.
All 51 structural checks passed. The complete recorded result matches the 13:34
baseline exactly after the existing timing/cache/work exclusions. No new solver
optimization was made in this recording slice.

Evidence under `test_artifacts`:
- Current visual: `contact_driven_preparation_2026-09-30T23-38-28.html` / `.json`.
- Full chronology: `grip_preparation_chronology_2026-09-30T23-38-30.jsonl`,
  `.html`, `.summary.json`; per-hand phase analysis: `.analysis.json`.
- Complete equivalence: `grip_chronology_equivalence_2026-09-30T23-38-28.json`.
- Focused cache test: 114 checks at 23:38:00; prepared-section test: 158 at 23:38:12.

There were 13 right / 11 left response cycles, 170 / 122 iterations and 218 / 206
trial evaluations. 166 / 117 trials improved the current response. Rejected
trials are measured algorithm outcomes, not automatically removable work. The
existing accepted result still includes unresolved contacts; do not change those
as part of timing work. Middle reseating ran once right and twice left.

Across both hands, 1,012 overlap queries spent 53.202 s in their bodies: 36.798 s
nearest-contact, 8.202 s depth sampling/refinement, 2.639 s intersections, and
5.562 s validation/cache dispatch/other bookkeeping. There were 5,330,142 actual
nearest-pair tests. Separately, section topology preparation took 22.350 s and
triangle slicing 17.481 s. These section costs are included in weapon-section
and response-cycle spans; do not sum all inclusive stage totals.

Next narrow timing candidate: `planar_skin_overlap_budget.gd::_nearest_contact`.
Keep traversal, strict comparisons, ties, geometry and budgets identical. Remove
per-edge Dictionary counter writes in favor of local totals, and defer provisional
winner tangent/normal/result assembly until the final winner is known. These are
proposals, not implemented savings. Verify exact complete packets against frozen
code and the complete accepted report, then benchmark with recording disabled.
Secondary candidate: conservative source-order representative-block bounds in
`skin_plane_contact_query.gd::_prepare`, preserving the existing weld predicate
and first-ID winner. Do not skip topology checks or repeat the rejected
triangle-copy experiment. No UI cycle, gameplay cutover or new Git action occurred.

### September 30 user priority: preserve the accepted result; optimize duration

The user explicitly accepted the 11:49 result as-is and directed duration-only
work. This supersedes the proposed next focus on improving the right-hand seat.
Do not alter closure, seating, contact acceptance, caps, geometry, iteration
budgets or retained-contact behavior in this slice. The reference is
`contact_driven_preparation_2026-09-30T11-49-45.json`: 85.480 s right, 126.626 s
left. The user also emphasized that weapon orientation influences what can seat
in the hand. The current result is accepted; do not resume the old right-seat
correction as an implied next task.

Profile first; target repeated saved-surface and planar depth/contact work.
Use exact reuse and conservative spatial rejection, retaining the original
narrow geometry calculations and all possible contacts. Preserve source order,
nearest-feature ties and whole-edge depth bounds. Verify against the frozen
pre-optimization kernel and complete two-hand report, not only cap verdicts.
Files: planar_skin_overlap_budget.gd, skin_plane_contact_query.gd,
saved_wrapper_skin_contact.gd, acquisition cache lifecycle in the isolated
contact_driven_grip_preparation.gd, and focused comparison tools. An additional
selected-triangle-copy removal was tried and reverted after showing no useful
gain; prepared_weapon_plane_section.gd and slice_reachable_surface.gd retain
their prior contents. No live cutover,
Forge repair, installed tooling or Git operation is included.

First complete comparison (13:22): 50.138 s right / 71.309 s left, reductions of
41.35% / 43.69%. All recorded poses, contacts, placements, events, counters and
source records match the accepted report exactly after excluding only durations
and cache/work instrumentation. Evidence:
`test_artifacts/grip_duration_comparison_2026-09-30T13-22-52.json`.
The additional contact primitive allocation removal passed an independent
1,333-check original-code comparison. Final combined timing is 45.152 s right /
60.530 s left, reductions of 47.18% / 52.20% from the accepted reference.
`test_artifacts/grip_duration_comparison_2026-09-30T13-34-54.json` confirms the
same complete recorded result and sequence. This is diagnostic timing; live
interactive performance has not been measured or switched to this owner.
The rejected triangle traversal attempt passed 462 checks but took 1,549.528 ms
against 1,532.736 ms for copying in its final bounded comparison. Its verifier
is archived under test_artifacts, outside the active tool folder.

### September 30 next authorized slice: coarse checkpoints and saved-wrapper match

User approved the Middle-first improvement and requested proper size skips and
proper matching to Forge V2 output. Keep radius units: request the existing
approximately 117 -> 50 -> current enclosing radius checkpoints directly; halve an
advance only when its coupled contact projection cannot resolve. Remove fixed
5 mm progression. Keep 50 optional if the enclosing target is larger.

Then consume the actual saved digit/palm target sections, without building a
new envelope or applying another inward offset. Guide shape completion and skin
contact acceptance are different: the saved 1.5/3 mm targets can lie beyond the
existing physical per-section caps, which remain the stopper. Use existing
bounded overlap measurements on the separate actual Handle; never force exact
target tangency through a physical cap. Preserve named planes, shared placement,
fixed Hand/wrist and late palm, and at most 3 reseating attempts. Retain acquired
contacts when followers join. Extend the existing isolated owner and report;
no live cutover or Forge source geometry repair is implicit in this request.

Files: existing contact_driven_grip_preparation.gd/controller proof/viewer,
skin_contact_hinge_jacobian.gd generic point derivative, and a small
saved_wrapper_skin_contact.gd adapter over the existing depth/contact query.
Validate coarse target requests, exact saved polygon consumption, unchanged caps,
physical bounds, shared-seat retention and untouched inputs. Results are in the
11:54 execution entry at the end of this file; fitting remains incomplete.

The first wrapper attempt exposed whole-step rejection at physical limits:
one nearby unassigned skin edge can prevent the entire five-variable response
even while other joints/translation directions remain available. The bounded
correction being tested is to include those material inequalities in the same
small contact solve, allowing tangential motion while retaining full-geometry
acceptance. Keep the existing iteration budget and caps. An uncertain depth
upper bound is a blocker, not evidence for an inward correction. Unassigned
skin retains zero allowance; a separate strict-exterior proof handles the
zero-cap numerical interval without enlarging it. Do not turn this into a new
outer angle-search solver or claim that a rejected direction proves a physical
grip limit.

### September 30 active correction: Middle-first placement and coupled contact

The user rejected W3's alternating guide move / finger chase and competing
whole-hand placement. Current authorized attempt: bind Middle S1/S2/S3 through
sliding tangency, solve their constrained response together with the single
transverse weapon position as the guide contracts, then add palm seating and
solve the other digits against that shared placement. Hand/wrist/upstream body,
weapon orientation and handle percentage remain fixed. Middle's plane supplies
contact measurements; existing lateral translation axes preserve the station.

A smaller circle alone is not an accepted state. Internal constraint iterations
may occur, but recorded accepted contraction states must include the matching
skin pose and weapon position. Do not hide detached target-change frames and
claim continuous attachment. Exact mathematical continuity is distinct from
measured substep tangency; report the actual evidence.

Implementation attempt stays in the isolated preparation owner and proof. Native
CCDIK currently handles sequential rigid marker targets and cannot by itself
enforce simultaneous blended-skin contact. Use the existing prepared skeleton,
limits and geometry with a small coupled contact Jacobian, not another outer
angle trial grid. Preserve actual skin checks and named frames. Query Middle's
saved sections first; other planes join later. Known saved-cap defects remain
explicit and must not be repaired by relaxing contact/topology tolerances.

Files: `contact_driven_grip_preparation.gd`, a measured-skin hinge derivative
helper, `prepared_saved_grip_sections.gd` selected-plane queries, and their
existing proof/verifier/report tools. No live acquisition cutover, upstream IK
change, support rewrite, F/playback change or Git push is included. No additional
design decision is required for this bounded attempt. Results follow below.

This is the active guide for the grip overhaul: dependencies, missing components,
consumer redirection, retirement gates and execution order. Keep the investigation
evidence below; update progress here as the implementation changes. SPS remains
the separate dated handoff and should point back here when this work is paused.

Read the progress table first. Before each implementation slice, inspect its live
callers and identify the input, output, single writer and nearest regression.
After the slice, record exact files, fresh verification, remaining limits and the
next step in the execution record. A planned item is not implemented merely
because this file describes its desired behavior. Do not tick a step on parser
success alone or on a historical result.

This plan does not require a new permission exchange for every routine edit.
Continue within the agreed scope; expose material placement, movement-ownership
or outcome decisions before implementing them. An unclear user instruction or
new dependency is a reason to clarify, not to silently expand this plan.

| Step | State | Completion evidence / dependency |
| --- | --- | --- |
| P0: trace current ownership and select replacement boundary | DONE: source analysis | Findings in this file; no fresh gameplay claim. |
| P1: establish coherent pose and surface input | DONE for current zero-morph character | Complete capture of both single-hand setups; independent reconstruction, missing-pose rejection and immutable-input checks passed. See execution record. |
| P2: compare anatomy, mounting, seating and palm contact | IN PROGRESS: full guide/material/reseat diagnostic measured | September 27: original star left reaches three material sections, right two; subsequent three-template comparison meets that minimum in three of six hand cases. Partial core palm is attributed geometrically. Full tangency, whole palm and shared placement remain unresolved. |
| P3: isolated complete single-hand acquisition | IN PROGRESS: all five digits now articulate and are measured | Offline star run reaches the diagnostic minimum on each hand. Actual skin contact and prepared/live geometry consistency remain unresolved; primary arm movement is not part of acquisition. |
| P4: integrate one application/retention boundary | IN PROGRESS: primary ownership correction verified | Weapon-only transverse seating plus digit rotations; 679 saved-candidate checks and 99 UI lifecycle checks pass. This is not completed contact acceptance or a new full live acquisition run. |
| P5: shared-weapon support and grip combinations | PENDING: needs P4 | Both hands accepted against the same weapon; normal/reverse rules agree. |
| P6: retire replaced execution and finish cost review | PENDING: retirement gates below | No orphan callers; fresh regressions, whole-action timings and visual review. |

Current stopping point: W1/W2 remain implemented with saved cap defects still
open. September 30 replaces the isolated W3 sequential native proposals with
Middle-first coupled skin/weapon contact projection. Both tested Middle digits
reach the enclosing circle while retaining S1/S2/S3 contact; late palm seating
also converges. W4 now consumes exact saved wrapper targets and measures the
separate physical Handle caps. Fitting remains incomplete and is being corrected
within this isolated owner. This work has not replaced live acquisition.
See the September 30 execution entry. Ordinary live grip latency is not fixed
by this proof.
The P0-P6 table records the wider overhaul; the W1-W5 checklist orders current
work. Do not resume arm/wrist correction or expand into support cutover.
The latest primary/support ownership instruction supersedes historical
fixed-weapon/moving-main-hand experiments below. Continuous constrained contact
following is now the intended replacement for frozen finger-pose retention.
Historical limits of the earlier diagnostic evidence remain relevant:
The earlier three-contact minimum was met in only three of six two-digit cases;
none of those six final poses had attributed palm contact. Do not describe those
results as full-hand or live integration evidence.
The corrected guide/material/reseat sequence now runs through the material
phase. Earlier initial-contact gates and two-radius diagnostic cutoffs are
superseded instructions, retained only as experiment history. Do not reintroduce
them while improving tangency. Keep unrelated body geometry visible without
calling it palm contact. The local primary cutover is documented below.

### September 27 user correction: guide preparation is not final grip acceptance

Status: agreed behavior; isolated implementation and measured limits are recorded
under the September 27 full-process execution entry below. The requirements here
are not a claim that all contacts or continuous tangency have been achieved.
This section supersedes the historical next-step advice
to prove initial five-contact acquisition before allowing contraction. The user
identified three premature terminations; do not repeat that controller error.

1. Before the guide reaches the actual handle, aim to maintain sliding tangency
   between guide and hand skin, prioritizing digit sections over palm (Middle
   S1/S2/S3; Thumb primarily S2/S3). A missed contact remains measured, but must
   not terminate shrinking or become the final grip verdict at this preparation
   stage. The guide drives closure; anatomy constrains the response.
2. At the handle, measure actual hand-skin/material contact using the existing
   per-section overlap allowances. Valid overlap counts as contact; merely
   finding a reachable nearest point does not. The intended default is at least
   three distinct hand sections across one hand, not three mesh points on a
   single section and not three required in every digit's plane. Stop shrinking
   when sufficient proper contact is established, or when
   one of the three physical limits prevents further closure: established
   minimum inward bend radius between material-contact bridging points,
   prepared IK motion limits, or per-section skin/material overlap limits.
   The circle's first touch of the handle is not itself a completed hand grip.
3. After shrinking stops, attempt a small reseat. Freeze the stopped wrapper /
   guide geometry; do not resize or reshape it to improve the score. Adjust the
   allowed hand/bone pose, with sliding contact permitted. Preserve acquired
   tangency/contact throughout the accepted adjustment, respect every section's
   overlap cap, and attract sections that missed contact during shrinking.
   Opening one joint and closing another is allowed if those constraints remain
   satisfied. An improvement in total error cannot justify dropping an existing
   contact or exceeding a cap. Keep the prior pose if no legal improvement is
   found. Checking endpoints alone does not prove contact along the adjustment.
   User failsafe: **at most three reseating attempts per hand-grip solve**,
   shared across all sections. Stop earlier when no legal improvement is found;
   three is a ceiling, not a required count. Do not reset the counter for a
   missing section or a different candidate. Budget exhaustion ends reseating
   and triggers final assessment; it does not establish a physical grip limit.

The weapon stays fixed during this grip solve. Guide centers and their actual
handle-slice centers stay coincident. Handle-percent repositioning is a separate
operation and retains its existing weapon movement ownership.

Palm policy supplied by the user: retain an existing palm cap if one exists;
otherwise use a maximum **0.0025 m (2.5 mm)** inward overlap, with the same
orientation/contact-side rules as digits. Source inspection found no existing
numerical palm cap. This is a maximum allowance, not a mandatory penetration
target. Digit caps continue to come from live rules, not replacement constants.

Known input gap: `prepared_palmar_contact_def.gd` explicitly leaves complete
palm partition and overlap policy unverified/undefined. Existing core samples
do not identify the entire palm. `section_owner == -1` is unassigned tissue,
not a palm label; it must not automatically receive 2.5 mm. Establish attributable
palm membership before applying or claiming that rule over the full palm.

User confirmed both clarification answers in chat: count three distinct sections
across one hand; if a physical limit stops shrinking before three contacts,
attempt reseating while preserving the acquired contacts and judge the final
result afterward. Three contacts never override a violated overlap or motion
limit. There are no remaining rule questions from this clarification exchange.

Implementation caution from source audit: the old wrapper match base evaluator
moves the Hand subtree, while the current circle proof translates the captured
presentation rigidly. Reuse the current coherent candidate/skin path; switching
evaluators must not silently change the deformation model. The existing wrapper
builder supplies a final envelope, not a verified continuous circle-to-wrapper
transition. Neither static endpoint matching nor a solver budget exhaustion may
be presented as proof of the full contact-preserving process or a physical limit.

## User intent and chosen approach

"House cleaning" is the grip overhaul already discussed, not general repository
cleanup. The goal is a complete, predictable input-to-grip chain, actual contact,
no loose ends or unnecessary processing, and usable total latency. Correctness
must not be traded for speed. Ordinary manipulation should preserve an accepted
hand/weapon relationship; acquisition frequency may be reconsidered when the
measured complete cost permits it. Perpetual solving is not itself required.

The user authorized choosing between incremental live changes and an isolated
replacement, favoring more mature code when uncertain. Chosen direction:
**build an isolated acquisition/retention core using the established geometry and
anatomy components, then integrate it through the existing callers in bounded
stages.** Do not copy the whole project or duplicate useful query mathematics.
Do not add another series of corrective passes to the current orchestration.

Work backward from the required outcome to its evidence, ordered operations and
inputs. Add missing derived references when a concrete responsibility needs them
(as with the Pinky-Index line), with a measured source and named origin chain.
Do not invent anatomical constants or arbitrary control points to fill a gap.

Make ownership, input contracts, geometry reuse and failure handling lean from
the start. Optimize numerical search after its contact criteria are demonstrated,
with full-cost timing present from the first proof. Old execution is removed when
its replacement and consumers are verified, not merely because it looks old.

### Open-hand and unarmed behavior must survive

User clarification, 2026-09-18: an open hand is useful intentional behavior for a
non-weapon-bearing hand and for unarmed Skill Crafter use. Preserve those branches
and their authored pose/control ownership during this overhaul. An open pose is
not obsolete just because it does not satisfy weapon-contact acceptance.

Distinguish intentional free/unarmed hand poses, temporary acquisition starting
poses and rejected weapon-grip fallbacks. Only the last case must not be presented
as a completed weapon grip. Do not require a free hand to contact a weapon, force
all unarmed poses open, or remove shared open-pose helpers without checking these
consumers. Further unarmed development remains downstream; reusable anatomy,
pose evaluation and origin handling should remain available to it without a
mandatory weapon input.

## Current execution and acceptance

Paths below are relative to the active project. Line numbers refer to the analyzed
HEAD; they are navigation anchors, not permanent identifiers.

| Stage | Current owner / evidence | Consequence |
| --- | --- | --- |
| User edits | `runtime/combat/combat_animation_station_ui.gd`, drag refresh 3437, action setters 6847 | Handle changes and support changes enter acquisition; ordinary Tip/Pommel refresh also permits acquisition after macro alignment. |
| Initial mount | `runtime/player/player_humanoid_rig.gd:620,878`; `player_equipped_item_presenter.gd:619` | An anatomical reference exists: Index/Pinky midpoint plus a bounded perpendicular offset toward cached Thumb/Index geometry. It is not measured palm contact. |
| Macro pose | `runtime/combat/combat_animation_station_preview_presenter.gd:3654,3768`; rig `:4668` | Nominal hand targets/body alignment are reconstructed before exact seating. A rigid user edit can change the Hand-in-surface relationship and make acquisition eligible again. |
| Weapon seat | preview `:5525,5671`; `runtime/player/player_hand_surface_seat_solver.gd:1083` | The weapon correction is applied before digit acceptance. Seat acceptance covers Index/Pinky radial residuals and probe safety, plus optional ordinary proximal capsules. |
| Finger closure | `runtime/player/player_rig_finger_grip_presenter.gd:1432,1734`; `player_finger_surface_grip_solver.gd:189,380` | The presenter can commit 15 safe rotations without requiring all digits solved or all contact targets reached. A valid cached packet can be a safe partial fallback. |
| Final assembly | preview `:6008` | Digit settling returns void; there is no one final whole-grip verdict that commits or rejects placement and fingers together. Restoring rotations does not restore the full previous relationship. |
| Accepted Roll | existing weapon Roll resolver/manipulator and retained preview path | Separate rigid one-handed transaction. Preserve its settled wrist-to-Tip axis, finger articulation and upstream pose. |

Primary seat paths disable the four ordinary proximal-capsule gate; support paths
enable it (`finger_grip_presenter:777-828`). Even with that gate enabled, the seat
does not certify measured palm, thumb or distal skin. Its Index/Pinky authority
probes are spheres at bone points, distinct from full phalanx capsules.

The serial digit solver closes one hinge at a time, with downstream-limit
exceptions, thumb-specific policy, possible final reaccommodation and verified
neutral fallback. Those checks have value, but their aggregate outcome is not the
user's full-grip acceptance contract. Do not simply rename `safe_to_apply` as
`grip_accepted`, or delete its safety checks to obtain a pass.

Authored endpoint metadata is produced before the final surface-seat correction
in part of the preview route. It must remain distinguishable from the final
displayed seated transform; later F/save parity is still a separate integration.

## Retention and processing cost

- Seat caches terminal results, including failures, by context. Finger reuse
  needs a valid state, matching context, 15 rotations and no forced resolve.
- Context includes the actual Hand-in-contact-surface frame along with source,
  geometry, slot, role and authored guide identity (`finger_grip_presenter:2133`).
  Identical failed contexts are suppressed; changed relationships can retry.
- A cached residual weapon correction is not the accepted Hand-in-weapon frame.
  Retaining only finger rotations is also insufficient.
- The UI sets `authoring_drag_lightweight=false` at line 3456. The cheap presenter
  branch is not the ordinary drag route; enabling its legality bypass is not the
  chosen performance strategy.
- Seat and fingers each perform faces -> ArrayMesh -> world triangles -> BVH /
  topology preparation (`finger_grip_presenter:924-975,1579-1677`). Their respective
  solve timers start after this preparation (`:995,1696`). Measure outside these
  boundaries for total acquisition cost.
- `weapon_surface_seat_prepared_attempt_lookup` has declarations, writes and
  clears but no reader in runtime/tools searches. It currently retains prepared
  data without providing reuse. This is a concrete consolidation candidate.
- Support realization includes five extra upper-body blend passes, three contact
  alignment passes, up to six support convergence iterations per call, and up to
  three residual support seat passes. Some repetition may be necessary for the
  current algorithm; count and attribute it before removing it. The comment saying
  two residual passes is stale.

Historical duration evidence remains in
[Performance Recovery](<Skill Crafter Performance Recovery 2026-09-15.md>) and
[Prepared Skin Proof](<Prepared Skin Contact Solver Proof 2026-09-15.md>).
It was not rerun during this source analysis. No new latency or fluidity claim is
made here.

## Geometry responsibilities to preserve or separate

Retain exact geometry identity/transport, actual deposited dimensions, signed
Handle station calculations, named origins and the established closest-pair/BVH
query mathematics. Existing synthetic verifiers cover useful numerical and
transport properties; they do not establish an anatomical whole-hand grip.

The current three-slice seat can remain a baseline/candidate seed. Its radial
correction removes axial displacement and preserves fixed anatomy, but its
inside-center and ray-search assumptions are not a universal solution for all
concave/curved Handle shapes. Contact validation must decide whether a candidate
is acceptable independently of how it was generated.

Protected Handle geometry is intentionally handle-only
(`player_equipped_item_presenter:1551`, `finger_grip_presenter:1868`). Preserve
that eligibility/selection authority. Reachable blade/guard contact needs the
separate whole-object surface input already explored by the proof tools, rather
than silently changing the meaning of a protected Handle packet.

The capsule query distinguishes unsigned distance from valid inside/outside
classification; `valid` alone is insufficient for a signed-contact decision.
Its topology check is edge incidence/degeneracy, not proof of no self-intersection
or nested-shell ambiguity. Its penetration value is not exact physical minimum
translation depth. Reuse the primitive with those semantics intact.

New inputs must validate and compose full frames back to `RL_BoneRoot`; matching
origin-name strings alone does not perform coordinate conversion. Object-local
geometry preparation is a useful target for reuse, but nonuniform scale and
metric tolerances must remain explicit rather than be normalized away.

## Prepared anatomy: useful data, incomplete coherent-pose input

The saved character resource contains original geometry, bind transforms and
unchanged skin weights. It stores two complete mesh surfaces (15,992 vertices,
19,300 triangles, 77 binds), not only isolated finger patches. Prepared motion
data currently covers Middle/Thumb on both hands.

`tools/grip_plane_proof/prepared_digit_skin_query.gd:31` freezes nonselected
contributions at Hand-rebased rest. The September 16 diagnostic can substitute a
common captured 15-bone digit pose (`diagnose_prepared_contact_baseline.gd:171`),
but other bones still use rebased rest. Neither path is yet a general coherent
posed-hand surface evaluator.

A read-only join of source triangle IDs in the saved September 16 reachable slice
windows to the original resource weights found contributions from ForearmTwist01,
ForearmTwist02 and, for the Thumb windows, UpperarmTwist02. These are source
triangle-corner influences, not a claim that every such triangle is touching the
weapon. The known Middle crossing triangles can still be hand-only. The result
means that Hand plus 15 digit frames is not sufficient for every triangle the
current reach query includes.

The next evaluator must resolve every contributing bone of its declared contact
surface from one coherent pose, or explicitly reject missing input. Reading an
upstream bone pose for skinning does not grant permission to change that bone or
its IK. Do not silently substitute rest, discard small weights, normalize them,
or call a truncated patch a closed solid.

Reusable pieces: character fingerprint/storage and origin validation, measured
dimensions, existing FK, unchanged skin weights, triangle-plane slicing,
bounded candidate search and deterministic diagnostics. Incomplete pieces:
coherent all-influence pose input, a declared palm/contact surface, complete 3D
and inter-digit acceptance, and practical whole-grip search cost. The two-digit
proof remains provisional even when a 2D slice has no crossings.

## Replacement contract and first implementation slice

Intended ownership chain:

```text
prepared character data + authoritative object geometry + grip request
-> one coherent captured pose and validated coordinate frames
-> placement and digit candidates without live scene writes
-> shared palm/digit/object acceptance for that same candidate
-> one accepted hand-in-weapon relationship and digit pose packet
-> one controlled application / retention boundary
```

Bounded numerical iteration inside candidate generation is allowed. "Linear"
means clear input/output ownership, not forbidding a necessary iterative solver.
Both hands, when engaged, must be validated against the same weapon candidate.

First implementation slice: establish a reusable coherent posed-surface input
and use it to compare anatomical reference, mounted C0 and seated C0. Determine
which existing frozen captures supply all required contributing frames; extend
the capture only where data is missing. Reuse the prepared resource while its
inputs match. Do not rerun expensive anatomy preparation merely to obtain a
different current pose.

Smallest useful verification: exact reconstruction against an independent full
weighted-skin calculation; both hand fixtures; deliberately changed neighboring
and forearm influences; missing-pose rejection; unchanged source data; named
origin round trips; preparation/evaluation/total timing. This verifies the input
surface, not a completed grip. Then use the comparison to settle the placement
and palm-contact contract before production replacement.

Subsequent boundaries: complete candidate acceptance, single-hand acquisition,
accepted relationship retention, shared-weapon support integration, then removal
of superseded execution and caches. Do not copy the discarded Roll/two-hand
transaction wholesale or apply the parked anchor patch independently.

The current preview explicitly disables support for reverse grip
(`combat_animation_station_preview_presenter.gd:8483`). This contradicts the
current combination requirement and must be addressed at its integration stage;
it is not an intended restriction to reproduce in the new core.

## Missing components, contracts and intended locations

The rows below name responsibilities, not a requirement to create one class/file
per row. Existing functions should absorb a responsibility when ownership stays
clear. Proposed locations are not existing implementations or permission to rename
established files. Prototype under `tools/grip_plane_proof/`; promote reusable
data/math only after verification. Live code must not end up depending on tools.

| Component / current gap | Inputs -> required output | Where it belongs / what connects to it |
| --- | --- | --- |
| Coherent pose capture: current digit snapshots omit some contributing poses | Prepared skin bind identities + one settled skeleton/mesh pose -> immutable complete named bone frames, mesh frame, machine frame, resolve phase and pose identity; missing contributions reject explicitly | First extend the existing acquisition diagnostic only if frozen inputs are insufficient. Live capture belongs to the rig/runtime adapter, not the geometry solver. It feeds the shared surface evaluator. |
| Shared posed-surface evaluator: current proof fixes nonselected bones at rebased rest | Prepared vertices/binds/unchanged weights + coherent capture + all candidate digit poses -> one common skin surface and its affected triangles, with provenance and timings | Prove beside `prepared_digit_skin_query.gd`, reusing established skinning/FK arithmetic. A pure reusable implementation can later live under `core/resolvers/`; no scene writes or character baking during evaluation. |
| Explicit palm/contact domain: palm source geometry exists, contact semantics do not | Character geometry/topology, anatomical references and reach -> declared relevant surface/contact regions, required pose dependencies, completeness limits | Character-owned preparation data plus shared contact evaluation. Establish whether a bounded patch suffices; do not invent a solid at a crop boundary. Persist reusable character measurements; do not store a weapon-dependent answer as character anatomy. |
| Shared object geometry context: seat and fingers prepare separately | Geometry identity/revision + protected Handle packet + whole-object contact surface + validated transforms -> reusable query structures and two distinct surface roles | Provider adapter at the equipped-item boundary; reusable geometry/query data below presentation. Build once per relevant geometry/metric change and transform candidate queries explicitly. Handle selection remains Handle-owned; nearby blade/guard may provide contact. |
| Unified candidate acquisition: current seat and digit results have different acceptance | Grip request, movement permissions, character data, coherent pose, geometry -> candidate placement and digit poses with contact evidence or a specific failure | Isolated proof first; pure resolver below the presenter when ready. Existing seat/FK/query routines may generate candidates. They may not apply partial results. |
| Whole-grip acceptance: no current component certifies all required contact | One candidate hand surface and object pose -> explicit accepted/rejected/unresolved outcome, with palm/digit/inter-digit/3D and origin checks | One shared evaluator used by acquisition and final verification; never reimplement weaker acceptance in each caller. A 2D seed or a safe open pose cannot satisfy it alone. |
| Accepted relationship state: cached residuals/rotations are incomplete | Fully accepted result + source/character/rule revisions -> actual Hand-in-weapon frame, joint pose per participating hand, contact evidence and invalidation dependencies | Runtime data owned by the grip acquisition owner; data definitions may belong under `core/models/`. It is derived state, not a new player-save format. Resources remain data-only. |
| Single application/retention adapter: current writes happen in separate stages | Accepted relationship + current authored motion/legality -> permitted final writes, or explicit rejection retaining a state known to remain valid | Runtime rig/preview integration. UI reports intent; solver returns data; the adapter applies it. This adapter preserves existing arm limits and Roll ownership rather than moving upstream joints to force grip success. |
| Shared-weapon hand assembly: primary/support currently accept separately | Both participating hands, their selected stations and one weapon candidate -> a common accepted result or explicit failure | Same acquisition/acceptance contract with multiple hands; support realization remains a runtime adapter responsibility. Two separate primary-hand captures are not simultaneous two-hand proof. |

Candidate and accepted-state data must identify character/anatomy revision, object
geometry revision, hand roles, authored grip station/style, named origin chains,
resolve phase, relevant rule revision and the pose being evaluated. A result must
distinguish usable input, a provisional candidate, complete acceptance and failure;
one generic `valid` flag cannot safely stand for all four.

Search limits must be deterministic (for example bounded evaluations/iterations
with fixed ordering). Measure elapsed time, but do not choose different grip
answers merely because one machine reaches a wall-clock timeout sooner.

Keep four data owners distinct: the motion node owns requested endpoints and
grip intent; the solver owns temporary candidates; the accepted relationship
owner holds verified derived output; the presenter applies that output. A
placement correction must not silently rewrite authored intent. Every reader of
endpoint/weapon metadata must identify which of these states it consumes.

Lifecycle decisions belong to that owner, not to incidental cache-key drift:

| Intent / dependency change | Required decision |
| --- | --- |
| Handle station/style change or explicit reacquire | Acquire for the requested relationship; an identical geometry cache may be reused, but does not substitute for the requested acquisition. |
| Tip/Pommel or ordinary rigid manipulation | Retain the accepted hand/weapon relationship through existing motion legality when still valid; do not reconstruct a different nominal grip and solve it accidentally. |
| One-handed wrist-Tip Roll | Use the accepted Roll transaction and its settled reference; retain articulation and check its established invalidation conditions. |
| Support engagement/reposition/disengagement | Update participants and acquire/validate the shared-weapon result; do not accept two unrelated single-hand packets. |
| Free hand or unarmed state | Preserve its intended hand-pose/control path, including an intentional open hand. Weapon-contact acceptance applies only to participating weapon-bearing hands. |
| Character geometry/rules, object geometry or relevant scale changes | Invalidate the affected preparation/acceptance dependencies explicitly; unrelated UI changes must not rebuild them. |
| Display-only refresh | Present valid existing state; no acquisition triggered solely by drawing. |
| Failed acquisition | Preserve a still-compatible accepted state or expose the defined failure. Suppress identical automatic retries; explicit reacquire has deliberate retry semantics. |

## Consumer redirection map

| Current connection | Planned connection | Condition before switching |
| --- | --- | --- |
| UI actions -> generic preview refresh -> permissive seat/digit attempts | Same input/authoring interfaces -> explicit acquire or retain decision owned by the grip adapter | Relationship-change triggers and invalidation tests exist; event coalescing and UI lookup reuse survive. |
| Initial mount -> seat correction -> immediate weapon write | Initial mount/anatomical reference -> candidate seed -> shared acceptance -> final writer | P2 placement contract established and P3 complete candidate demonstrated. |
| `resolve_exact_surface_weapon_seat` and `apply_authoring_digit_grip_now` used as separate success paths | Thin runtime adapter consumes one acquisition result and applies its permitted placement and rotations together | No scene writes during search; rejection cannot leave a new weapon pose beside unrelated old fingers. |
| Per-digit rest-based skin query -> isolated digit result | Every candidate uses the same coherent surface state, including neighboring influences | P1 reconstruction and missing-input tests pass; changed bones invalidate every affected surface/plane. |
| Separate seat/finger geometry preparation | Shared geometry context keyed by actual dependencies | Equivalent closest-pair/signed-distance results, transform/scale checks and geometry-change invalidation pass. |
| Rotation cache/residual seat metadata -> supposed retained grip | Accepted complete Hand-in-weapon relationship -> existing macro target/legality adapters -> checked retention | Tip/Pommel and posture edits do not double-apply seating; changed geometry/contact cannot retain stale acceptance. |
| Support inverse correction plus residual loops | One shared-weapon result -> explicit support realization -> acceptance checked for both hands | P5; do not delete convergence work before its necessary responsibility is replaced. |
| Existing wrist-Tip Roll transaction | Keep existing transaction; connect accepted-grip identity/invalidation only where necessary | Roll still fixes Tip/Wrist, retains fingers/upstream pose, and survives release/refresh. No implicit rewrite. |

## What can be sunset, and when

Sunset here means remove a replaced execution responsibility after its consumers
are accounted for. It does not mean deleting all old files, history, fixtures or
V1 behavior. Classify each consumer as migrated, intentionally retained or
explicitly deferred before deleting its provider.

| Candidate for retirement | Replacement / deletion gate | What must survive |
| --- | --- | --- |
| Separate seat-success and safe-rotation success as whole-grip authority | Unified candidate acceptance + application active for the migrated path | Useful seat geometry and safety queries; compatibility for unmigrated consumers. |
| Write-only `weapon_surface_seat_prepared_attempt_lookup` | Confirm no dynamic/reflection consumer, remove its writes/clears together; use real shared preparation if needed | Diagnostics actually consumed by tests/UI. Do not rename an unused cache and call it reuse. |
| Duplicate faces/mesh/BVH/topology setup for the same geometry | Shared context proven equivalent under geometry and metric changes | Closed-surface/topology validity and named transforms. |
| Rest-substitution as current shared-hand pose in the proof | Complete all-influence evaluator available and proof callers redirected | Old frozen diagnostic evidence and explicit historical interpretation. |
| Residual correction metadata pretending to be an accepted relationship | Complete accepted-state owner supplies every migrated reader | Actual grip station, orientation and source identity; no silent save-format change. |
| Serial closure orchestration if replaced by coordinated candidates | New search plus whole-hand acceptance covers all required digits/shapes; check every caller | Reusable FK, hinge limits, exact query math and independent regression oracles. |
| Bypassed legacy finger-target helpers | Enumerate V1/V2/free-hand/unarmed/runtime/tool callers and prove the specific helper unreachable or migrate them | Active V1 plane-curl, open-hand/unarmed behavior and unrelated consumers until explicitly replaced. |
| Extra body/contact/support passes | Show replacement convergence and final legality with fewer passes on the same cases | Actual arm/wrist/body legality; never remove by count alone. |
| Reverse-grip support exclusion | Common two-hand contract and combination tests replace the old restriction | Authored role/station semantics and one shared weapon pose. |

For each actual retirement, record removed symbols, migrated/remaining callers,
replacement owner, fresh tests and any deliberately retained compatibility path.
If F/playback/runtime still requires an old provider, keep it isolated and named;
do not expand into those workflows simply to claim zero old code remains.

## Execution sequence and completion gates

**P1 - coherent input.** Inventory pose coverage before writing an evaluator.
Reuse matching anatomy; obtain missing current frames through the existing
diagnostic/rig seam. Keep every original weight and metric transform. Verify
against an independent complete weighted-skin reconstruction, not a second call
to the implementation under test. Include missing frames, changed neighbors and
forearm contributions, both hands, nontrivial presentation transforms, unchanged
inputs and named-origin round trips. Record preparation and evaluation costs.

**P2 - placement/contact comparison.** Expose anatomical reference, initial Handle
slice center and final seated center together, using the same coherent skin and
object pose. If a frozen capture lacks a phase, label it unavailable or capture it;
do not reconstruct an assumed earlier phase and present it as observed. Establish
what is an invariant, a starting estimate and a shape-dependent offset. Determine
palm/contact region and tolerance meaning. Bring any new permission to move Hand,
weapon, support anchor or upstream IK to the user before implementing it.

**P3 - isolated acquisition.** Solve Middle/Thumb as the bounded first comparison,
then prepare and assemble the remaining digits needed for a complete hand. Keep
the character-save automation deferred, but do not defer the five-digit contact
work necessary to claim a full grip. Use genuine deposited geometry and the
declared reach; nearby non-Handle surfaces can provide contact without becoming
eligible Handle stations. Assemble and validate the same final surface in 3D,
including palm and inter-digit checks. Unknown topology/contact is unresolved,
not a pass. Capture complete cost and deterministic failure reasons.

**P4 - one live boundary and retention.** Connect the verified candidate to the
current preview/rig adapter without dual writers. Before writes, validate all
destinations and permissions. A failed candidate must not leave partial writes;
a previous accepted pose may only be reused when its inputs and relationship
remain valid. Test actual Handle sliders, reacquisition, Tip/Pommel/posture edits,
release, reset and the established one-hand Roll on both sides. Measure complete
input/refresh/release durations, not only inner solver time. Compare automated
geometry evidence with a scoped visual review. Check a weapon-bearing hand beside
a free hand, support disengagement and unarmed/open-hand controls: shared helper
changes must not force those intentional poses into weapon-grip solving.

**P5 - combinations.** Evaluate primary/support together against one weapon and
the selected stations. Cover support engagement/disengagement/reposition, either
dominant hand and normal/reverse grips. Axis relabeling must preserve physical
results; physically reversing an asymmetric handle may require different contact.
Removing the current reverse exclusion is insufficient by itself. Two-hand Roll
has a separate movement-ownership question: do not infer how two constrained
wrists must move from the accepted one-hand rule; resolve that contract before
changing its behavior.

**P6 - retire and measure.** Apply the retirement gates to migrated execution;
update tools and current notes with the same change. Verify the nearest legacy
consumers that remain. Compare whole-operation timings on the same correctness
cases, cache cold/warm, with required checks enabled. Optimize measured repeated
work first. A duration target still needs measured feasibility/user agreement;
do not invent a pass threshold or weaken acceptance to meet one.

Minimum evolving case set: the real difficult Star Handle, simple known-contact
geometry, curved/off-center/concave profiles, supported size and station endpoints,
nearby guard/blade contact, either hand, normal/reverse, support combinations,
transformed presentation and invalid/unreachable inputs. Add cases because they
exercise a contract or observed failure, not to accumulate assertion counts.
Finite tests cannot prove every possible player shape; retain explicit failure
behavior for cases the solver cannot establish within its declared constraints.

## Open decisions and downstream boundaries

| Decision | Evidence needed / when to resolve |
| --- | --- |
| Anatomical seed versus final placement invariants | P2 measured comparison; preserve authored station and accepted Roll while deciding shape-dependent seating. |
| Palm/contact domain and acceptance tolerances | P1 influence coverage + P2 surface comparison; explain any change from existing proxy overlap limits rather than silently copying or enlarging them. |
| What the editor presents after an impossible acquisition | P3 failure categories before P4 integration; never label an open/partial fallback as accepted. Preserve the last valid state only when still valid. |
| Two-hand movement permissions, including Roll | Before the affected P5 behavior; do not invent upstream movement from geometric feasibility alone. |
| Practical complete acquisition latency | Measure each component and whole action from P1 onward; agree the final target from evidence. |

Deferred work remains explicit:
[full-hand character-creation/save integration](<Character Creation Full Hand Preparation TODO 2026-09-15.md>),
F generation, playback/bake/save/reopen/equipped-gameplay parity. Preserve their
provider dependencies during this overhaul; do not claim those workflows passed
because the editor path did. Existing whole-hand preparation needed for P3 can
be run by the tool without automating the character-save workflow yet.
Further unarmed Skill Crafter development is also downstream. Preserving its
existing branch is a regression requirement now; extending its features is not
part of this grip-overhaul slice.

## Execution record

| Date / slice | Actual changes | Verification and limit | Next |
| --- | --- | --- | --- |
| 2026-09-18 initial analysis | Added this note; mapped live placement/digit/retention boundaries, geometry reuse and coherent-skin gaps | Static source/caller/assertion review and saved-data inspection; no engine run or production change | P1 coverage inventory |
| 2026-09-18 working-plan expansion | Added component contracts/locations, consumer redirects, retirement gates, staged checks and open decisions | Documentation consistency/link checks only; planned components remain unimplemented | P1 coverage inventory |
| 2026-09-18 open-hand clarification | Protected intentional free-hand/unarmed poses, shared helpers and future reuse; added lifecycle and regression requirements | User-directed plan clarification only; no production change | P1 coverage inventory |
| 2026-09-18 P1 coherent input | Added `prepared_hand_skin_query.gd`, `capture_coherent_skin_pose.gd`, `verify_prepared_hand_skin_query.gd`; extended existing acquisition diagnostic with opt-in complete pose capture | 190 checks passed; both fresh single-hand captures reconstructed against original-array skinning. Source Resource SHA-256 unchanged. Live grip remains unmodified and unverified | P2 placement-stage capture and palm/contact comparison |
| 2026-09-18 P2 capture-seam analysis | Identified precise missing stage observations in the existing diagnostic; no P2 implementation | Static source plus fresh P1 report. Current captures cannot establish earlier complete poses | Extend the same diagnostic at the three seams below |
| 2026-09-18 P2 observed-stage comparison | Added `capture_grip_placement_stage.gd` and `diagnose_coherent_grip_placement.gd`; extended existing acquisition diagnostic with linked stage transactions | 22 stages passed origin/coherence/geometry checks; all 44 section geometries reproduced on guarded capture rerun; fresh P1 190-check regression passed | Define hand contact domain and candidate/placement acceptance; no production replacement yet |

### P1 implementation and fresh evidence

The old September 15 digit captures lack complete current bind-bone and mesh
frames. The new acquisition capture reads all 77 bind frames, actual mesh and
machine frames synchronously at `finger_solve_input`. It checks source arrays,
binds and rests against the saved definition before attaching its signature.
Unique side/frame/solve identity records which call was observed. It does not
run anatomy preparation or write the pose. Active morphs are explicitly rejected
by this initial capture adapter; general morph-state validation remains future
character-setup work.

The pure evaluator compiles original weighted bind-space points once, then uses
every positively weighted current bone from a supplied complete pose. It never
fills missing contributors with rest, normalizes weights or normalizes affine
frames. All origins resolve through `RL_BoneRoot`. Output topology arrays are
independent of preparation data. Character identity and same-epoch capture are
established by the adapter/setup, not merely asserted by matching label strings.

Fresh Godot 4.7 logs and artifacts (workspace-relative):

- `godot_runs/the_will_2026-09-18_01-58-37.log`: isolated user-directory probe
  passed. Process-local APPDATA/LOCALAPPDATA/TEMP/TMP point into
  `test_artifacts/grip_p1_runtime`; the diagnostic refuses an unexpected user root.
  Eight existing workspace backup save files were copied and hash-checked there.
- `godot_runs/the_will_2026-09-18_02-03-47.log`: actual saved Star Handle acquisition
  diagnostic completed for right and left single-hand setups. New inputs:
  `test_artifacts/grip_solver_inputs_hand_right_2026-09-18T02-04-13.bin` and
  `test_artifacts/grip_solver_inputs_hand_left_2026-09-18T02-04-24.bin`.
  Existing right grip reported three unsafe digits; left reported a degraded
  safe fallback with seat radial tolerance not reached. Neither is an accepted
  complete grip. Two separate setups do not prove simultaneous two-hand behavior.
- `godot_runs/the_will_2026-09-18_02-04-53.log` and
  `test_artifacts/verify_prepared_hand_skin_query_2026-09-18T02-04-54.json`:
  190 checks passed. Original-array skinning oracle, complete captured poses,
  current Hand-frame continuity, synthetic simultaneous neighbor/forearm changes,
  nonunit weights, affine/reflected/sheared transforms, missing inputs, source and
  output ownership, deterministic repetition and origin round trips were checked.

Measured in this run: full 15,992-vertex preparation 25.766 ms; captured right/left
evaluation 10.894/8.775 ms; diagnostic capture with reference validation
1.292/1.409 ms. Maximum world-vertex oracle discrepancy on the captures was
0.000358 mm. These are component timings, not complete acquisition latency or a
frame-rate guarantee. Full-surface evaluation is an initial correctness baseline;
candidate locality/affected-vertex reuse remains a measured optimization task.

The prepared `.tres` SHA-256 remains
`B7F07BF7D79DB331FCB250982A62B31D4ABC1E58D1D4B2BEEFC2754658C27DEA`.
The evaluator does not certify contact, palm completeness, inter-digit clearance,
joint feasibility or gameplay behavior. The saved digit `base_bone_world` values
are neutral/open reconstructions, not current pose observations; do not substitute
them for the new complete capture when comparing placement.

### P2 capture seam identified at the P1 boundary

The fresh right seat reports an accepted 45.484 mm radial candidate correction
and about 7.12 degrees of angular correction, followed by three unsafe digits.
The left reports a rejected candidate with 1.407 mm maximum radial error and a
degraded finger fallback. These are existing solver diagnostics, not measured
whole-skin acceptance. Never present the left proposed correction as applied.

Before the P2 extension the diagnostic dropped `AuditSeat.solve_prepared`'s
C0/Ci/Cp/axis inputs and the full presenter seat return, which
already contains the base/resolved weapon and C0 transforms when applied.
It captured a complete character pose only at the later finger-solver input.
`observation_weapon_world` is read later at serialization; it is not automatically
the object frame corresponding to `posed_character`. The synchronous
`object_contact` snapshot belongs to the finger-input capture instead.

The following extension is now implemented in the same diagnostic, enabled by
`THE_WILL_CAPTURE_GRIP_PLACEMENT=1` (which implies coherent capture):

1. Record the actual mounted-entry pose and held-item transform immediately
   before `AuditPresenter._apply_preview_weapon_surface_seat` calls its super.
2. Record the exact seat inputs and complete pose inside `AuditSeat.solve_prepared`,
   after the existing canonical-open/support-settle calls and before its solve.
3. Record the full seat return and actual complete pose immediately after the
   presenter super returns, before later finger solving. Keep rejected proposals
   and actual applied state distinct.

Tie observations to one seat-transaction serial and explicit stage/frame IDs;
retain independent complete origin packets at each stage. Capture the existing
anatomical reference alongside them as a derived reference, not a promise of
palm contact. Use the new evaluator on each observed stage; do not transplant the
finger-input Hand onto an unobserved earlier mount and call it a capture. Existing
slice/contact mathematics can then attribute the measured placement issue.
No mounting permission or production algorithm change has been decided by this
seam analysis. Palm/contact domain and tolerances remain P2 decisions.

### P2 measured comparison: 2026-09-18 02:32

The capture adds separate complete character/object snapshots before seating,
at exact seat-solver input, immediately after return, and at associated finger
inputs. Transaction/slot/stage/frame identity and origins are explicit. The
existing anatomical target is read only when its animation baseline cache is
already initialized and complete; diagnostics must not trigger that preparation.
Supplied P1 pose data is copied before diagnostic metadata is attached.

The offline comparison extends the old baseline diagnostic only to reuse its
numerical crossing attribution. It uses P1's complete posed surface, never the
old rest-substitution or neutral-pose variants. Original source face IDs and every
skin influence survive. Both selected-digit-influenced and other triangles are
sliced each stage. Object slices and contact queries are bounded by the prepared
digit section-length sum. Missing/failed captures reject, including cross-stage
pose identity, object origin or applied-result/observation mismatch.

Fresh final evidence (workspace-relative):

- Capture log `godot_runs/the_will_2026-09-18_02-30-32.log`;
  `test_artifacts/grip_placement_trace_hand_right_2026-09-18T02-30-57.bin` and
  `test_artifacts/grip_placement_trace_hand_left_2026-09-18T02-31-08.bin`.
  Right: 4 transactions, 15 observations; left: 2 transactions, 7 observations.
  These include 6 actual seat-solver calls and 4 finger-input observations.
- Offline log `godot_runs/the_will_2026-09-18_02-32-01.log` and
  `test_artifacts/coherent_grip_placement_2026-09-18T02-32-06.json`:
  all 22 stages / 44 digit-stage sections processed without diagnostic failures.
  Batch processing took 4,923 ms; this includes loading, full-surface slicing and
  report work, and is not a production acquisition or frame-time claim.
- An independent Python comparison against the first capture/report
  (`coherent_grip_placement_2026-09-18T02-26-37.json`) found identical weapon
  frames, measurement planes, skin segments, target segments and source crossing
  attribution for all 44 sections after the capture guard was added.
- `godot_runs/the_will_2026-09-18_02-32-40.log`: the P1 verifier passed all
  190 checks with the final right/left finger-input captures.
- [Measured section review](<../../test_artifacts/coherent_grip_placement_review_2026-09-18.html>)
  presents 11 equal-scale Middle/Thumb section panels from the final report,
  with source-face weights, stage identity and the rejected-attempt comparison.
  The companion `test_artifacts/render_coherent_grip_placement_review.py`
  reproduces it. SVG structure, geometry counts and unit measurement frames were
  checked; browser appearance has not been visually reviewed. These are local
  diagnostic artifacts, not a new grip acceptance criterion.

Observed results and their exact limits:

1. Right transaction 4 applies a seat accepted by the existing seat solver.
   Middle's section still has four source crossing events on surface 0 triangles
   4203/4204, both immediately after seating and at finger input. Their source
   corners have Hand, Mid1 and neighboring digit influences, but no Mid2/Mid3.
   Changing only Middle joints 2/3 with all other frames fixed cannot move those
   triangles. This does not prove that moving the weapon is the only remedy.
2. Left transaction 5 also applies an accepted seat. Middle triangle 3583 has the
   same lack of Mid2/Mid3 influence. Additional crossings on triangles
   1653/1670/1671 belong to thigh/hip/waist-weighted geometry, not palm geometry.
   The complete source surface includes the body; proximity alone does not make
   a triangle a required gripping contact. No body-avoidance work was added.
3. Left transaction 6 is a later rejected seat attempt. The seat-input pose
   differs at all 15 left digit bones; after return, its observed bone/weapon
   frames and section geometry match before the attempt. This supports the
   existing restore-after-rejection path. The latest finger-input capture belongs
   to transaction 5, not 6. A last solver input is not automatically final display.
4. The existing anatomical target, seat C0 and actual surface remain distinct
   concepts. For the accepted right transaction, C0 is about 50.178 mm from that
   target before seating and 47.578 mm after. Distance between differently owned
   references alone is not proof of a bug or a required correction direction.

Planes are the prepared anatomical measurement planes attached to the Hand of
each observed stage. They are not asserted to be the articulated digit's current
motion plane. Composed plane axes are unit/orthogonal; local links retain model
scale. Source-face crossings can duplicate one physical event. Existing object
slicing uses 1 micrometre plane tolerance / 5 micrometre welding; hand slicing
uses 0.1 micrometre plane tolerance. Cropped/ambiguous topology stays incomplete;
no zero-crossing case can certify palm clearance, containment or a complete grip.

Next: establish the character-owned hand/contact region and acceptance meaning,
including shared tissue and neighboring digit influence. Use the anatomical
reference as an explicitly identified candidate reference while resolving its
placement constraints. Do not tune only distal closure to fix triangles those
joints cannot move; do not silently redefine the whole nearby body as grip skin.
Placement, proximal/neighbor articulation and full-hand acceptance must be compared
on one common candidate before choosing a production correction policy.

### P2 design discussion: contact envelope and coordinated closure

User direction after the measured section review (2026-09-18; conceptual design,
not implemented or verified):

- The three supplied star-section sketches propose an enclosing contact curve
  that first reaches the outer points, then follows recesses only up to a maximum
  inward curvature. The curve preserves protruding material; it is not a uniform
  offset or an edit to the authored weapon geometry.
- The subsequent refinement uses actual hand skin and its permitted articulation
  to determine achievable wrapping. Skin samples remain outputs of the original
  weighted bone transforms; they cannot be moved independently and then assumed
  to be realizable by the skeleton. No exhaustive hand-pose database is requested.
- Proposed initialization: use the Forge V2 maximum perpendicular Handle
  template radius plus 30%, with the existing slice-derived center as the seed.
  Radius should remain adjustable. This is a proposed starting bound, not proof
  that arbitrary oblique/reach-cropped sections fit inside it. Verify containment
  against the relevant actual geometry and retain explicit origin/metric chains.
- The weapon stays fixed during acquisition; the hand may settle around it while
  fingers/thumb close together. Preserve the authored Handle station and grip
  direction. This differs from the current primary seat's fixed anatomy and
  weapon-side correction (`player_hand_surface_seat_solver.gd:8`;
  `combat_animation_station_preview_presenter.gd:5671`). Hand/wrist candidate
  placement and its arm-realization limits need an explicit contract before live
  application. Do not import a new upstream writer through a geometry helper.
- Contact, attainable articulation and local inward-curvature limits govern
  continued closure. A proposed implementation must allow unconstrained regions
  to continue after another region reaches contact or a limit; the first such
  event is not automatically whole-hand completion. Reaching joint limits or a
  search budget does not establish grip acceptance or mathematical infeasibility.
- The initial circle is a guide, not a requirement that the final hand lie on a
  circle. The current skin evaluator includes shared palm/neighbor geometry;
  prepared digit motion/anatomy still covers Middle and Thumb on both hands.
  Multiple digit planes and final common 3D skin acceptance remain necessary.
- Settled contact must distinguish contact with real material from touching an
  artificial bridge over a recess. Curvature, measured skin thickness, any future
  deformation and allowed overlap are separate concepts. Whole-hand contact and
  collision criteria remain unresolved; no success claim follows from the analogy.
- Acquisition settling is distinct from retained wrist-Tip Roll. Preserve the
  accepted Roll's fixed Tip/Wrist and upstream pose after an accepted grip.
- User suggested per-finger closure controls for free/unarmed hands as a possible
  later use. Park that option with the existing unarmed scope; no sliders or UI
  work are part of this design discussion.

Current reusable proof: `prepared_skin_contact_solver.gd:21` already seeds all
three joints of one digit together, then explores coordinated/individual angle
changes. It does not implement a circle, shared whole-hand closure or coupled
hand placement. `slice_reachable_surface.gd` preserves raw sections; its
`skin_padding_m` enlarges the query window and is not the proposed envelope.

Static template check for this discussion: Forge V2's Handle builder uses
`PRESET_HEX_24` and a 0.0125 m cell size
(`forge_v2_profile_shape_library.gd:16`, `:46`, `:1428`;
`primary_grip_slice_profile_library.gd:74`). Its centered six-by-six stepped mask
has 75 x 75 mm bounds and maximum origin-to-boundary distance sqrt(10) * 12.5 mm
= 39.52847 mm. The proposed 1.30 multiplier gives 51.38701 mm. Derive this from
the provider data in an implementation rather than adding a copied constant.
This calculation is not a current runtime slice measurement. A 45-degree plane
through a sufficiently long circular cylinder already has an ellipse semi-major
axis sqrt(2) times its perpendicular radius; template padding alone cannot prove
oblique-slice containment. Profile anchor, template origin and actual slice
centroid also need not coincide. No engine test ran for this design discussion.

Next proof should make the proposal measurable: a known slice and anatomy,
declared movable variables, actual contact/collision observations, deterministic
settling/failure criteria and elapsed component/total cost. Treat circle/envelope
construction and skeleton-realizable closure as distinct responsibilities even
when evaluated together. Do not mark P2 or the grip complete from a tightened
contour alone.

### P2 overlap policy recovered from the pre-rollback backup

User clarification, 2026-09-18: use the existing section-specific skin/Handle
intersection allowances from the pre-rollback Git version for the proposed
contact approach. Controlled overlap with actual Handle material is therefore
part of the requested baseline; do not impose a new blanket zero-overlap rule.
Targets and maximum allowances remain distinct, and overlap with an artificial
envelope alone is not actual material penetration.

Checked `d798cc01` (`Backup unverified Skill Crafter work before review`,
2026-09-12) against current HEAD `03c82dfd`. Git reports no differences for
`runtime/player/player_digit_hinge_rules.gd`,
`runtime/player/player_finger_surface_grip_solver.gd` and
`runtime/player/player_finger_capsule_surface_query.gd`. These values survived
the rollback; no historical solver import or checkout is needed.

Normal acquisition path, with a supplied grip center; both hands share this
policy. Sections run from base (1) to terminal section (3):

| Region | Authored target overlap | Effective maximum overlap |
| --- | --- | --- |
| Index/Middle/Ring/Pinky section 1 | 0.50 mm | 0.50 mm |
| Index/Middle/Ring/Pinky section 2 | 0.40 mm | 0.48 mm |
| Index/Middle/Ring/Pinky section 3 | 0.30 mm | 0.38 mm |
| Thumb section 1 | 0.50 mm recorded, contact requirement bypassed | 5.00 mm |
| Thumb section 2 | 1.00 mm | 1.08 mm |
| Thumb section 3 | 0.30 mm | 0.38 mm |

User-provided tuning history, clarified after this recovery: these overlaps are
intentional visual stand-ins for "flesh give". The user expects more give near
section 1 generally. In particular, tighter Thumb1 limits prevented a usable
thumb position in prior visual testing; the recovered values were deliberately
tuned and the resulting appearance was accepted as good enough for use. This is
reported historical user acceptance, not a fresh test of the new skin evaluator.
Preserve the recovered values as the accepted starting policy. Do not remove the
Thumb1 exception merely because it is larger, infer a new increase for ordinary
section 1 from this explanation, or silently replace the policy with zero
overlap. Any later adjustment should follow measured/visible outcomes in the new
solver. Allowed mesh overlap represents give visually; it does not itself
implement deformation of the skin mesh.

Definition/consumer chain in the current identical files:

- `player_digit_hinge_rules.gd:26` supplies the ordinary 0.50 mm digit cap,
  fallback preferred overlap 0.25 mm, target tolerance 0.08 mm and target arrays.
  `:230` assigns those arrays per digit. There are not separately tuned targets
  for Index/Middle/Ring/Pinky; they share the ordinary array.
- `player_finger_surface_grip_solver.gd:233` clamps the incoming ordinary cap.
  `:431` raises the thumb digit's available headroom to its section-2 target plus
  tolerance (1.08 mm), with an absolute 5 mm ceiling. This is rule-derived, not
  measured geometry adaptation.
- `:2395` computes each section's upper limit as target + 0.08 mm, clamped to
  the digit cap. `:2418` overrides Thumb1 to 5 mm while its contact requirement
  is disabled (`:17`). The 5 mm exception is not a desired tangent-point inset.
- `:2476` and `:3008` apply section caps during downstream safety/final candidate
  evaluation. Numerical comparison epsilon is 0.00005 mm; a 0.00025 mm search
  guard keeps targets at the hard ceiling slightly below it. Neither is extra
  authored compression budget. The no-grip-center fallback has different flow
  and is not represented by the table.
- `tools/verify_player_digit_hinge_debug_visuals.gd:756` already contains explicit
  assertions for these section caps and the Thumb1 exception. Inspected only;
  this verifier was not rerun for the historical policy audit.

Preserve the metric distinction when reusing the policy: the old query measures
capsule-proxy radius minus signed axis-to-actual-Handle-surface distance
(`player_finger_capsule_surface_query.gd:224`), and the consumer additionally
rejects an axis inside the solid/invalid classification. It does not measure
penetration of the actual weighted skin or establish material compression.
The new proof should reuse these named targets/caps as the user's baseline while
measuring the actual skin, exposing the Thumb1 exception separately. It must not
copy the old capsule radii into the measured-anatomy path or convert the 5 mm
ceiling into a 5 mm contact target.

Before this policy can certify a new skin candidate, define relevant section and
shared-skin ownership and a depth/containment check with adequate coverage. The
current planar sampled-inside-depth value is a lower bound; being below a cap
cannot certify that no deeper unsampled intersection exists. The earlier P2
crossing observations remain evidence of intersection, not automatically a
failure under this clarified nonzero-overlap policy. No production changes or
engine tests were made in this audit.

### P2 isolated coordinated-closure experiment: 2026-09-18

Latest user clarification: **Handle-% editing may still move the weapon**, including
when a requested station encounters arm/IK limits. The proposed fixed-weapon rule
applies only inside acquisition after upstream authored positioning has established
its input pose. It is not permission to freeze the weapon during Handle-% edits or
change that control's behavior. Accepted wrist-Tip Roll remains a separate action.

New proof-only components:

- `tools/grip_plane_proof/prepared_hand_candidate_pose.gd` builds candidate
  Hand/digit frames from measured anatomy and the complete coherent capture.
  It retains all original skin contributors, caches fixed contributions and
  recalculates affected vertices only (978 right / 965 left, of 15,992).
  Upstream/other-hand frames stay unchanged. Hand translation here is hypothetical
  geometry placement; the adapter does not claim that an arm can realize it.
- `planar_skin_overlap_budget.gd` measures maximum inward depth of each entire
  supplied skin segment against one complete simple object contour. It returns
  lower/upper bounds and `within`/`exceeds`/`unresolved`, with a separate numerical
  guard and work budget. A low sample is never a cap certificate. Optional bounded
  refinement narrows depth intervals even after a cap decision for contact ranking.
  Zero allowance remains unresolved at exact zero because of the numerical guard.
- `run_coordinated_grip_closure_proof.gd` tests Middle and Thumb independently,
  coordinated three-joint proposals, individual adjustment and one in-plane Hand
  translation direction perpendicular to the current captured weapon span. This
  is not a common whole-hand solve. It freezes the last accepted seat transaction's
  **finger-input** pose (right transaction 4 / left 5), so it evaluates closure
  after the existing surface seat, not a complete replacement for that seat.

The complete object contour supplies inside/outside classification; only contact
witnesses inside the measured digit reach attract that digit. The seed circle is
centered on the actual slice centroid, starts at the larger of provider-derived
Forge V2 radius x 1.30 or actual slice extent, and supplies decreasing-radius soft
guidance. Actual articulated skin is evaluated at every candidate. No independently
deforming membrane, curvature field or tangent-constrained placement has yet been
implemented. Inward-curvature behavior cannot be claimed from this experiment.

Fixed measuring planes have their own `ClosureFrozenPlane_<slot>_<digit>` origin
under `RL_BoneRoot`, separate from the anatomical plane translated with Hand.
Station direction comes from the same frozen object's named span endpoints.
Every report preserves the machine frame and origin chains. The existing scene,
weapon transforms, authored station, prepared resource and production code are
not written by the experiment.

Section contact attribution remains provisional: the same selected bone must own
strictly more than half of all original weight at both segment ends. Its recovered
section cap is then applied to that edge, explicitly labelled trial assignment.
This avoids dropping the Thumb2 allowance merely because skin also has a small
Hand contribution. Unowned shared tissue remains visible and unverified. Hand
weights alone cannot identify palmar rather than dorsal skin. Thumb1's contact
requirement exemption and 5 mm maximum are preserved; 5 mm is not a target.

Initial fresh verification:

- Candidate-pose verifier: **151 checks passed**, 12 cases across both hands,
  combined Middle/Thumb, translation and rigid presentation. Comparison against
  complete P1 skin reconstruction differed by at most approximately 0.000123 mm.
  Missing ancestry/origins, invalid limits and changed metric are rejected;
  source immutability and unchanged upstream frames are checked.
  Report: `test_artifacts/verify_prepared_hand_candidate_pose_2026-09-18T04-22-15.json`;
  log: `godot_runs/the_will_2026-09-18_04-22-13.log`.
- Overlap-bound verifier: **43 assertions passed** including segment-interior
  penetration missed by endpoint checks, concavity, uncertainty, budget exhaustion,
  incomplete/self-intersecting input rejection and post-cap refinement.
  Log: `godot_runs/the_will_2026-09-18_04-25-10.log`.
- Actual-handle closure run: four cases, no diagnostic execution failures; all
  retain `grip_accepted=false`, `palm_contact_verified=false`,
  `arm_realization_verified=false` and `actual_3d_grip_verified=false`.
  Report: `test_artifacts/coordinated_grip_closure_2026-09-18T04-27-44.json`.
  Initial pose means prepared zero angles, **not** the captured live articulation.
  Selected visible-skin gaps in mm: right Middle 1.938 / 0.140 / 0.066;
  right Thumb2/3 1.284 / 2.082; left Middle 0.572 / 46.149 / 62.133;
  left Thumb2/3 0.789 / 0.819. These are distances, not contact successes.
  The left Middle remains open; a fixed search budget does not prove infeasibility.
  Shared unassigned skin still intersects, with observed maximum-depth lower
  bounds approximately 3.8-4.9 mm. No whole-hand safety verdict follows.

This first correct-policy run took 6.97-13.50 seconds per digit search, 88-123
candidate evaluations. Selected candidates cost approximately 77-117 ms: pose
5.7-6.5 ms, skin slicing 1.3-1.4 ms, depth/contact queries 69.5-109.1 ms.
These are offline diagnostic costs, not runtime latency results. Exact query
reuse/pruning was subsequently verified as recorded below; the solver is not snappy.
Synthetic round/square fixtures exist in the runner but have not been exercised
in this implementation pass. The actual-handle shortcomings take priority.

Next work must resolve shared hand placement and contact attribution before live
integration. Independent digits cannot settle different positions for one Hand.
Required contact must remain observed; disappearing geometry is not improvement.
Add palm-region evidence from the character preparation, preserve existing section
allowances, and distinguish a static candidate from a legal arm-realized result.
The present local search is an experiment, not an accepted final algorithm.

User scope clarification after reviewing this experiment: extending the same
measured-anatomy preparation and solver work to Index, Ring and Pinky is authorized
whenever it is needed for an adequate result. No further permission is required
for that extension within this grip overhaul. Middle/Thumb remain the focused
development cases until additional digits materially help establish shared Hand
placement, neighboring-skin behavior or whole-grip acceptance. Similar individual
digit results must not be assumed to establish the combined result. This
authorization does not mean the remaining digit data is already prepared or
verified; the character-owned extraction and validation still need doing.

Continuation authorized after this experiment:

- Extract the already checked per-plane skin/contact observation into
  `prepared_grip_slice_contact.gd`; compare its outputs with the recorded proof
  before using it in the common-Hand experiment.
- Prepare a character-owned **core palmar sample set**, using the wrist/Index1/
  Pinky1 footprint and palmar side signed by documented ordinary-finger closing
  direction. Store original source triangles/barycentric coordinates and full
  origin/recipe provenance. Opposing ray hits are two-sided bracketing evidence,
  not a certificate of a closed palm solid or a complete palmar partition.
- Extend the isolated search to one combined Middle/Thumb pose and one shared
  two-dimensional Hand displacement perpendicular to the current weapon span.
  The current weapon and authored station stay fixed inside this acquisition
  experiment; moved anatomical planes require fresh object slices. Reuse exact
  slices only for identical placement, never across distinct plane offsets.
- Compare deliberately folded seeds with the old zero-only local start to test
  a local-search barrier; do not infer infeasibility from the left Middle result.
- An explicit palm overlap policy has not been found in the recovered digit
  settings. User clarification requested while geometry preparation continues;
  do not silently copy digit/Thumb1 allowances onto the palm.

The measured status of this continuation is recorded below. Live integration
remains behind common-contact, whole-hand and arm-realization gates.

Shared-hand continuation, September 18:

- `prepared_grip_slice_contact.gd` extracts the earlier contact observation without
  changing the section budgets or source-weight policy. Its verifier compares
  eight initial/selected candidates against the unchanged earlier implementation
  and the frozen report. **199 checks passed**, including preservation of signed
  infinity in historical missing-contact fields; no overflow warnings remained.
  Report: `test_artifacts/verify_prepared_grip_slice_contact_2026-09-18T05-00-30.json`.
- `diagnose_shared_closure_seeds.gd` established a local-search barrier for the
  left Middle. At its previously selected placement, zero angles cost 110.053 mm
  of contact-target error; -32.5 degrees per joint worsens this to 128.875 mm,
  while -97.5 degrees improves it to 69.056 mm. The joint signs/limits agree with
  the prepared model. This is not evidence to reverse limits or enlarge them.
  Report: `test_artifacts/shared_closure_seed_diagnostic_2026-09-18T04-48-36.json`.
- `run_shared_hand_closure_proof.gd` evaluates Middle and Thumb in one complete
  candidate skin pose. They share two transverse Hand displacement coordinates;
  axial displacement along the authored weapon span is rejected. Actual object
  geometry is re-sliced in each moving, named anatomical plane. Exact placement
  repeats reuse slices. Multiple whole-pose seeds retain folded alternatives.
- The first shared search completed both sides: right 195 evaluations / 27.670 s;
  left 208 / 25.817 s. Total diagnostic 54.264 s. These are offline proof costs,
  not acceptable interactive latency. Initial means prepared zero joint angles,
  not the captured live hand. Source is still the post-existing-seat finger input.
  Report: `test_artifacts/shared_hand_closure_2026-09-18T04-55-59.json`.
- Selected actual skin gaps, mm: right Middle 3.235 / 9.068 / 0; right Thumb2/3
  0 / 0.377; left Middle 13.680 / 14.809 / 3.633; left Thumb2/3 0 / 4.010.
  Zero gaps include intersections: right Thumb2 depth 1.0380-1.0384 mm, left
  Thumb2 1.0722-1.0775 mm, within their recovered trial section cap. Known-section
  cap excess was zero, but unassigned shared skin still reached depth upper bounds
  6.464 mm right / 3.962 mm left. Neither hand is an accepted grip. The changed
  common-pose problem is not directly comparable to independent digit scores.
- Palm preparation is **not complete**. The proposed nine-point wrist/Index1/
  Pinky1 core grid yields only four paired, strictly Hand-majority samples per
  side. Other first hits have shared digit/Hand influences; all rejection evidence
  is retained. The verifier correctly failed rather than exporting a complete
  palm resource: `test_artifacts/verify_prepared_palmar_contact_2026-09-18T04-59-35.json`.
  This grid is a declared measurement footprint, not an anatomical palm boundary.
  No cap was inferred for blended or palm tissue, and no old anatomy was replaced.
- Follow-up independently reconstructed all 20 reported hits in the ten rejected
  pairs from original reference triangles and weights: source vertex IDs match,
  maximum weight discrepancy 6.94e-16. All nine positions per hand have actual
  paired hits. The failure is the proposed strict ownership rule, not absent
  geometry. Bone weights describe deformation; minority Hand weight does not
  establish that a point lies outside the anatomical palm. Geometry-defined
  region membership and allowable flesh give must be separate decisions.
  The first failed verifier skipped partial-output roundtrip/covariance checks;
  those checks must not be claimed as passed. Source vertex IDs are surface-local.
- Shared-runner review hardened finite-frame and source-face origin checks,
  established trace-path validation, propagation of final geometry failures and
  deterministic seed sorting. Local improvement tolerances and search budget
  remain unchanged. **103 gate checks passed** in
  `test_artifacts/verify_shared_hand_closure_gates_2026-09-18T05-04-18.json`.
  These are synthetic failure/provenance checks, not additional grip evidence.
- Final shared search after that review:
  `test_artifacts/shared_hand_closure_2026-09-18T05-05-25.json`. Both complete
  reports match after excluding timing fields and added final-status fields:
  same source data, candidates, geometry, refinement history, section results
  and evaluation counts. Comparison:
  `test_artifacts/shared_hand_closure_hardening_comparison_2026-09-18.json`.
  The repeated diagnostic took 53.080 s; this is verification of the hardening,
  not a new performance improvement claim.
- A 3D palm observation attempt stopped at its unchanged-surface check:
  the source has 10,849 faces; existing `prepare_surface` retains 10,838.
  It drops faces with squared cross-product length at or below 1e-16 m^4.
  Report: `test_artifacts/shared_palmar_contact_2026-09-18T05-07-03.json`.
  No triangle threshold or runtime preparation was changed. Any continuation
  using that prepared surface must expose the removed source faces and label
  distances/classification as pertaining to the retained surface. This does not
  establish that the original Forge output is invalid, or authorize a Forge fix.
- Final observational report:
  `test_artifacts/shared_palmar_contact_2026-09-18T05-11-24.json`, produced by
  `inspect_shared_palmar_contact.gd`. All 36 point carriers resolve (nine per
  hand, initial and selected), all 36 unsigned prepared-surface queries succeed,
  and **zero signed/inside classifications are valid**. No cap is applied.
  The tool pins the original shared report hash and trace hashes, checks all
  reconstructed origin frames (maximum component discrepancy under 5e-15),
  preserves accepted/rejected attribution labels, and prepares carriers once
  in memory. It saves no character resource and changes no candidate ranking.
- The ordered surface audit verifies that all 11 omissions meet exactly the
  existing threshold, and every retained vertex/order matches. Omitted source
  indices, local/world coordinates and areas remain in the report. The existing
  topology check finds four nonmanifold edges after preparation, with no boundary
  edges. Before filtering, that same numerical rule finds 14 nonmanifold edges,
  nine degenerate edges and 11 degenerate triangles. Both hand captures agree.
  These are observations under the existing quantization/area rules, not a proof
  of a Forge defect or an identified cause. Reliable 3D inside/outside needs that
  input/query seam investigated before grip acceptance can depend on it.
- Example unsigned distances to the retained surface: the right central sample
  `core_1_2` increases from 5.970 to 18.492 mm; left from 5.306 to 7.418 mm.
  Some distal samples get closer, others farther. Unsigned values cannot say
  whether a point moved through the weapon. Digit-score improvement therefore
  must not be reported as improved palm seating.

Next dependency order: distinguish measured core surface membership from skin
allowance attribution; resolve the pending palm allowance with the user; trace
the source/prepared-surface topology ambiguity; then add palm evidence to shared
placement. Do not solve a failed acceptance gate by silently loosening it. The
current data does not yet justify replacing production gripping. Runtime/core
remain unchanged, the original anatomy hash is unchanged, and no commit or push
was made during this continuation.

The independent membrane/maximum-inward-curvature implementation, complete palm
contact attribution, legal arm realization, full-hand coverage and production
performance remain open. This experiment establishes coherent evaluation and
exposes remaining failures; it does not claim the zip-tie grip is finished.

Exact query-cost follow-up, same scope:

- Prepared target-edge bounds and reused intersections remove duplicate nearest
  queries. Conservative box-distance pruning retains possible closest points and
  tied corners. Every edge still participates in intersection/depth classification;
  geometry, section caps and refinement budgets are unchanged. An exhaustive
  nearest-query option remains as the comparison path.
- Final overlap verifier: **80 assertions passed**, including seven concave and
  corner cases with identical geometric output between optimized/exhaustive modes.
  Log: `godot_runs/the_will_2026-09-18_04-33-02.log`.
- Final actual-handle report:
  `test_artifacts/coordinated_grip_closure_2026-09-18T04-33-42.json`.
  Initial/selected skin segments, candidate parameters, per-section results, depth
  bounds, closure-stage choices and evaluation counts match the preceding run
  exactly after excluding timing/work counters and the added scope annotation.
  Comparison record:
  `test_artifacts/coordinated_grip_closure_optimization_comparison_2026-09-18.json`.
- The complete four-case diagnostic decreased from 42.92 s to 27.27 s in this pair
  of runs (about 36%). Individual searches now took 4.10-8.75 s; selected
  depth/contact queries 37.43-62.95 ms. This is useful exact work reduction, not
  an interactive-performance or whole-grip success claim. Contact shortcomings
  above remain unchanged. No broad parameter hunt or live integration followed.
- The saved anatomy SHA256 remains
  `B7F07BF7D79DB331FCB250982A62B31D4ABC1E58D1D4B2BEEFC2754658C27DEA`.
  Runtime/core diffs remain empty relative to the existing backup HEAD. No commit
  or push was made.

[Final planar review](<../../test_artifacts/coordinated_grip_closure_2026-09-18T04-33-42_review.html>)
contains all four actual cases, with 16 equal-scale initial/selected panels.
Section-owned skin and shared/unassigned skin are separated visually, while the
actual contour, circle seed, reachable contact witnesses and numeric bounds remain
visible. Source: `test_artifacts/render_coordinated_grip_closure_review.py`.
Python syntax, HTML structure, all SVG XML panels, finite coordinates and case
coverage passed checks. Browser appearance has not been visually inspected.

### September 26: visual discussion of palm identification

User requested a color-coded slice report and legend before further solver work.
Created [the visual report](<../../test_artifacts/grip_slice_visual_2026-09-26.html>)
and [PNG overview](<../../test_artifacts/grip_slice_visual_2026-09-26.png>) from the
saved September 18 shared-hand and palm observation reports. Middle/Thumb on both
sides each retain their own plane and pose-specific weapon polygon. Initial and
selected views are distinct; this is not a fresh gameplay capture.

Actual skin intersections remain unfilled where their contours are open. Colors
identify trial section ownership, unresolved overlap allowance and contact
witnesses. Joint/wrist markers and optional palm dots are explicitly projections;
hover data retains distance from the slice plane. Allowances are shown in mm,
not drawn as invented skin thickness, collision capsules or a finished envelope.
Orange does not mean an anatomically identified palm, or unmeasured geometry.

Generators: `test_artifacts/render_shared_grip_visual.py` and
`test_artifacts/rasterize_grip_visual.ps1`; source hashes/projection depths are in
`test_artifacts/grip_slice_visual_2026-09-26.manifest.json`. Eight SVG panels,
source correspondence, finite drawing coordinates and local HTML links/controls
were checked. The PNG was visually inspected; browser interaction was not run.
No new application/dependency installed, no engine/solver rerun, no game or tuning
change, and no commit/push. Active next step is discussion using these diagrams.

### September 26: opposing contacts on the proposed membrane

Following the annotated slice drawing, the user clarified that nearest-side
contact witnesses alone do not provide the intended wrap-around targets. Desired
contact candidates must include the opposing side of the Handle section, using
the proposed vacuum membrane as their target surface. This is design direction;
no membrane or opposing-cone implementation has been added by this discussion.

- The green distal section (S3, articulated at J3) is expected to have the greatest
  opportunity to oppose palm-side contact across the Handle. S2 is less likely;
  S1 may be unable because of its motion limits. Preserve these as expectations
  to evaluate using measured reach/joint limits, not hardcoded impossibility or
  mandatory assignments of named sections to fixed angular wedges.
- Search for an opposing envelope contact in an angular region across the slice,
  with the direction related to the finger contact and slice center. In one digit
  plane this is a fan/wedge; other digit/thumb planes retain their own geometry.
  The palm may act as one support region, with contact evaluated against the
  actual coherent skin. This does not authorize treating blended skin vertices
  as a new rigid Hand-only mesh or inventing a collision block.
- The user's "any skin surface" means contact should be discoverable geometrically
  instead of depending on the failing strict Hand-majority label. Candidate skin
  selection still needs a declared participating-hand/contact domain. A point
  touching arbitrary nearby body skin is not yet a defined grip acceptance rule.
- The suggested one-to-nine points are an exploratory sampling idea, not a fixed
  sample-count requirement. Samples belong on the membrane after its outer-point
  bridging and limited inward-curvature stages, with explicit named slice origins.
  Existing source-polygon contacts must not be relabelled membrane contacts.
- Derive candidates from the actual oriented slice so rotating profile geometry
  in Forge changes geometric correspondence naturally. No association with a
  permanently named spike or fixed profile orientation was requested.

The user subsequently proposed combining the opposing fan with four quadrants,
each allowed zero or more contacts, so looking toward one side does not miss
contact elsewhere. They asked how to combine these cleanly; the following is a
design proposal for discussion, not an implemented solver or accepted tuning:

- Maintain one contact/distance map over the complete envelope boundary in each
  digit plane. Quadrants organize coverage and the visual explanation; they do
  not require four occupied regions or prescribe which digit must occupy one.
  Their axes belong to the declared slice frame. Crossing a quadrant boundary
  must not change contact validity or the solve.
- Use the opposing fan to prioritize candidate support contacts across the
  Handle. It must not exclude other boundary regions from collision/depth checks.
  Check contour segments as geometry; displayed sample markers alone do not
  establish that the stretches between them are clear.
  Crossing the slice center alone does not establish useful opposition: local
  surface directions, eligible gripping skin and joint reach also matter.
  Collision participation does not automatically authorize contact attraction
  onto that surface (for example, the back of a finger).
- Record empty regions as no contact in the evaluated pose. This alone does not
  prove those regions unreachable; current gap, prospective reach under joint
  limits, and forbidden penetration are different observations.
- Valid contact is a constraint to retain, not automatically a reason to shift
  the Hand. Excessive overlap or a remaining reachable contact gap can motivate
  a candidate adjustment, followed by rechecking other contacts and limits.
  Digit-plane candidates share one Hand placement; they must not independently
  prescribe incompatible Hand translations.
- Keep membrane support contact separate from actual weapon-material overlap.
  Bridging a recess does not turn its empty space into weapon material, nor
  replace the original surface/allowed-flesh-give acceptance checks.

The fan-apex question was not answered as a choice between the two earlier
options. Full-boundary coverage does not depend on that choice, so it need not
block explaining or visualizing this proposal. Fan geometry/extent, the final
inward-curvature bound and numerical palm allowance remain unspecified; do not
silently choose them as game rules.

Proposed next bounded step: depict full-boundary coverage, quadrant grouping,
opposing search direction and available skin on the same color-coded slice
before using new targets to move the hand. Any conceptual membrane illustration
must be distinguished from the current measured raw contour. Keep envelope
construction, candidate contact discovery, skin correspondence and whole-hand
acceptance distinct. This supplements the earlier topology investigation; it
does not resolve or waive its inside/outside limitation. No runtime, solver,
engine run or Git publication in this design-record update.

### September 26: measured-radius contact envelope proof

Historical first measurement: the 8.70 mm terminal-cap choice below is superseded
by the user's annotated broad-side correction in the next section. The earlier
inputs/reports/visuals and measurement/render scripts are preserved under
`test_artifacts/contact_envelope_terminal_cap_2026-09-26/`. The ordinary artifact
paths now show the revised 22.10 mm side-arc result.

User selected the green S3 fingertip radius as the first inward-bend scale, then
clarified the intended lifecycle: measure all fingertips/thumbs once, retain
their minimum/maximum/average and save a target with the character's prepared
hand data. Forge V2 should eventually export a prepared handle contact wrapper
for Skill Crafter reuse. These are explicit continuation directions, not claims
that a full-hand character bake or Forge export is already implemented.

Radius terminology: the cap is **maximum inward curvature**, equivalently a
**minimum inward radius**. Larger radius bridges more of a recess. Existing
per-section flesh-give budgets remain separate and unchanged.

Implemented an isolated geometric construction under `tools/grip_plane_proof/`:

- `planar_contact_envelope.gd`: one complete simple metric polygon -> disk
  dilation followed by disk erosion using native Godot round offsets. Convex
  inputs are preserved exactly. One-loop output is required; holes/multiple
  loops reject. Named plane/source IDs and the input radius remain explicit.
  This builds the final limited-curvature shape directly; no simulated cloth,
  time-stepped vacuum or hand motion is claimed.
- `run_planar_contact_envelope_proof.gd`: frozen-input runner, 22 cases covering
  eight actual initial/selected Middle/Thumb slices, radius comparisons,
  rotation/reflection/winding, numerical-scale convergence, convex fixtures,
  analytic L-notch and invalid input rejection. Uses the supported launcher and
  existing workspace-isolated environment.
- `test_artifacts/measure_fingertip_radius.py`: repeatable diagnostic fitting of
  actual saved S3 skin. Right Middle reference fit is 8.702241398 mm. It uses the
  distal half of J3-to-extreme skin extent along prepared J2-to-J3, with segment
  length weighting. This cutoff is a disclosed diagnostic choice, not a settled
  anatomical cap boundary. RMS mismatch is 1.233969 mm, maximum over fitted
  segments 3.051881 mm. Cutoffs 40%-70% give about 9.524-7.258 mm, so it is not an
  exact fingertip circle or perfect-seating certificate. Other prepared digits
  are measured for comparison; no ten-digit average is fabricated.
- `test_artifacts/build_contact_envelope_review.py`: validates full named-plane
  frames against recorded ancestry, prepares inputs and renders the actual
  geometric construction and fitted-tip mismatch.
- `test_artifacts/verify_contact_envelope.py`: independent scalar-double polygon
  checks, including edge-interior containment error bounds, known analytic notch,
  covariance and convergence. Source hashes accompany reports.

Native-engine precision finding: Godot 4.7 hardcodes offset arc tolerance 0.25
input units. Working directly in meters is too coarse. The proof recenters only
for arithmetic, scales to 100,000 numeric units/meter and restores coordinates
to the same named metric plane. Nominal arc tolerance is 0.0025 mm. A 400,000
units/meter comparison measures convergence; this is not a changed world scale.
Ordered output validation retains short edges instead of applying the existing
unordered slice reconstructor's 1-micrometer endpoint-welding policy. Only exact
consecutive duplicate output coordinates introduced by real_t conversion are
removed, with counts recorded. No approximate welding, source union repair or
source topology-threshold change was used to obtain a pass.

Final construction run: `godot_runs/the_will_2026-09-26_20-01-31.log`, all 22
expected validity outcomes matched. All 183 independent verification checks
passed; embedded-input comparison retains the exact input byte hash and reports
JSON numeric roundtrip differences (maximum 9.54e-18) separately. The checks use an
explicit 0.01 mm spatial tolerance. Actual-slice source undercut upper bounds
are at most 0.002814 mm; analytic L-notch full-boundary error <=0.003707 mm;
base/fine comparison <=0.002690 mm. These are polygonal approximation bounds,
not exact material containment or certification of smooth curvature everywhere.
Actual-slice construction plus source/output checks cost 13.157-17.191 ms in this
run. This excludes slicing, character preparation, hand solving and acquisition;
it is not a whole-grip performance result. No repeated timing benchmark yet.

Artifacts:

- [Envelope visual review](<../../test_artifacts/contact_envelope_review_2026-09-26.html>)
  and [PNG overview](<../../test_artifacts/contact_envelope_review_2026-09-26.png>).
- `test_artifacts/fingertip_radius_2026-09-26.json` retains exact measurement
  inputs, source triangle IDs, selected segments, fit errors and sensitivity.
- `test_artifacts/contact_envelope_input_2026-09-26.json`, matching output and
  `contact_envelope_verification_2026-09-26.json` retain construction/evidence.

Next boundaries: review this contact surface and the disclosed fingertip fit;
establish reliable full-hand cap measurements/aggregation before saving a final
character target; then define the Forge wrapper export/reuse contract. Preserve
per-digit measurements and fit quality alongside aggregate min/max/mean. Do not
silently equate arithmetic mean with the midpoint of the extreme radii.

The future export must identify actual object geometry, character/anatomy metric
revision, measured radius and construction revision. Closing a perpendicular
profile then slicing it obliquely is generally different from closing an oblique
digit-plane slice. Resolve that 2D/3D reuse seam before promising that a single
Forge profile wrapper supplies every Thumb/finger orientation. The existing
[character-save TODO](<Character Creation Full Hand Preparation TODO 2026-09-15.md>)
now records these measurements and the future export dependency.

This proof has not connected envelope targets to hand motion, identified a
complete palm, fixed signed 3D weapon topology, exported Forge wrapper data or
replaced runtime gripping. Production runtime/core and saved anatomy remain
unchanged. No new commit/push or external application/dependency was used.

Primary engine/math references checked for this slice:
[Godot 4.7 Geometry2D](https://docs.godotengine.org/en/4.7/classes/class_geometry2d.html),
[Godot 4.7 offset implementation](https://raw.githubusercontent.com/godotengine/godot/4.7/core/math/geometry_2d.cpp),
[Clipper round-arc implementation](https://raw.githubusercontent.com/godotengine/godot/4.7/thirdparty/clipper2/src/clipper.offset.cpp),
[disk closing definition](https://docs.scipy.org/doc/scipy/reference/generated/scipy.ndimage.binary_closing.html).
SciPy was consulted as a mathematical reference, not installed or used.

### September 26: user-selected broad S3 side radius replaces terminal cap

The user clarified by drawing a circle against the broad curved side of the
green S3 outline, with the circle center below the outline, and asked to use
that measurement. Do not continue using the 8.70 mm whole-terminal-cap fit or
describe the selected curve as a measured palmar/dorsal anatomical classification.

The saved Right Middle initial slice supplies an exact connected S3 chain.
Starting at its positive-side proximal endpoint, follow its actual contour until
the first reversal along the prepared J2-to-J3 direction. This selects source
segments `0/3793, 0/3794, 0/3832, 0/3812, 0/3845, 0/3847, 0/3848`, from
(78.641310, 11.173235) mm to (102.590777, -1.085352) mm in
`CC_Base_R_Mid1PreparedContactPlaneOrigin`. The later returning underside and
small terminal lip are explicitly excluded from this fit; all original source
segments remain recorded.

Arc-length-weighted measurement: radius **22.099336934 mm**, center
(83.265452, -10.930219) mm, RMS radial residual **0.252529 mm**, maximum residual
**0.509827 mm**. This is a circle approximation of the selected side, not a
perfect skin match or the final all-digit average. The selection is tied to
the user's annotated side for this proof; its later anatomical generalization
must be explicit before ten-digit character baking.

`measure_fingertip_radius.py` now exposes `side_arc_fit` as the active reference
in schema v2. Earlier cap fits remain labeled comparisons. Selection checks cover
terminal-lip exclusion, source-order independence and rigid covariance; an
independent source audit confirmed all seven segment IDs/coordinates exactly.
`build_contact_envelope_review.py` consumes that active reference and redraws the
envelope and circle with two perpendicular radii. The analytic notch fixture is
sized so both walls can accommodate the larger test circle; the actual weapon
slices are unchanged.

Fresh construction: `godot_runs/the_will_2026-09-26_20-23-30.log`, all 22 expected
validity outcomes matched; all 183 independent checks passed again within the
same 0.01 mm proof tolerance. The independent verification and visual report at the
ordinary artifact paths belong to this revised radius. No engine algorithm,
runtime/core, saved anatomy, grip pose, Forge export or Git publication changed
in this correction.

### September 27: 2.3x envelope and first coherent hand-matching attempt

User selected 2.3 times the current measured side radius, then requested using
the hand against it. Preserve the two values separately: measured Right Middle
side arc **22.099336934 mm**, multiplier **2.3**, effective minimum inward radius
**50.828474948 mm**. This is tuning of the contact target, not enlargement of the
skin or a replacement anatomical measurement. Previous 1x artifacts are preserved
in `test_artifacts/contact_envelope_side_arc_1x_2026-09-26/`.

The envelope review now contains 23 construction cases, with comparison radii
0.5x/1x/2x/2.3x derived from the same measurement. Construction log:
`godot_runs/the_will_2026-09-27_00-48-17.log`. Independent geometry verification:
**212 checks passed**, retaining the prior 0.01 mm tolerance. The regular
September 26 artifact paths now display this updated September 27 configuration.

Implemented a separate `run_envelope_hand_match_proof.gd` runner reusing the
mature shared Hand candidate and bounded search. The base runner only gained
report/observation extension points and compact-log omissions. Middle and Thumb
share six authored joint angles and one transverse Hand translation; weapon and
authored handle station remain fixed. The rest of the captured pose is retained.
Arm realization is not solved by this offline candidate experiment.

The observer slices the actual coherent skinned mesh once per digit/candidate.
It measures actual weapon material and the envelope separately. Existing raw
depth fields retain their meaning; `contact_*` measurements describe the wrapper.
Attraction uses the wrapper, with the same recovered per-section flesh-give
targets/caps. Selection prioritizes raw caps, then envelope caps, missing reachable
witnesses, then contact error plus unassigned skin depth. Unknown shared tissue
is still measured and penalized, but no new palm allowance is invented.

`Depth.prepare_ordered_target` provides the target packet for an explicitly
ordered offset loop without endpoint welding or dropping short nonzero edges.
The original unordered source preparation is unchanged. Envelope construction
is cached per exact transverse translation; angle-only candidates reuse it.

Actual attempt: `test_artifacts/envelope_hand_match_2026-09-27T00-58-16.json`,
log `godot_runs/the_will_2026-09-27_00-56-08.log`. Both diagnostic cases completed,
with no invalid candidates. Neither is an accepted full grip.

| Selected candidate | Middle S1/S2/S3 envelope gap, mm | Thumb S2/S3 envelope gap, mm | Raw unassigned skin depth upper bound, mm |
| --- | --- | --- | --- |
| Right | 2.283 / 9.069 / 0 | 0 / 0 | 6.466 |
| Left | 9.621 / 11.186 / 0 | 0 / 16.357 | 3.981 |

Right Thumb S2 envelope depth is 0.890-0.899 mm, S3 0.046-0.056 mm, within
their existing caps. Left Middle S3 reaches the envelope at 0.340-0.348 mm depth
while its nearest actual-material gap remains 2.073 mm. Left Thumb S2 reaches
1.052 mm envelope depth while remaining 2.894 mm from actual material. These
demonstrate wrapper support over a recess, not actual material contact there.
Known assigned skin edges pass raw and envelope caps in these selected slices;
unassigned skin prevents calling the whole hand clear. Unassigned envelope-depth
upper bounds are 13.663 mm right / 9.912 mm left. Thumb S1 retains its documented
required-contact bypass; no new S1 acceptance claim.

Performance: 205 candidates / 67.568 s right, 202 / 58.757 s left, 127.160 s
total diagnostic duration including preparation. Envelope construction/target
preparation totals 1.041 s across 48 builds right and 1.757 s across 80 builds
left, including initial preparation builds. These are single-run offline costs,
not interactive acquisition performance. The new trial is not evidence that
all contacts improved compared with the earlier raw-target search.

Verification completed:

- Ordered-target seam: 32 assertions.
- Existing material-only observation path: 199 exact/frozen comparisons.
- Shared search provenance/sorting/finalization gates: 103 assertions.
- Optional envelope observer: 293 assertions across right/left Middle/Thumb,
  checking raw measurement preservation, equal-target equivalence, distinct
  envelope results, immutable inputs and rejection of invalid origin/completeness.
- Independent saved-output review: 87 checks including source containment in all
  eight new planes within 0.01 mm, separate target identity and depth aggregates.

[Hand/envelope visual comparison](<../../test_artifacts/envelope_hand_match_2026-09-27.html>)
shows initial and selected actual skin, both targets, joint/wrist projections,
separate material/wrapper witnesses and measurements. Initial means prepared
zero angles, not captured gameplay. Paired panels share metric scale. No old palm
overlay is reused on new poses. Renderer and verification retain source hashes.
The original prepared anatomy hash remains
`B7F07BF7D79DB331FCB250982A62B31D4ABC1E58D1D4B2BEEFC2754658C27DEA`.

The next problem exposed is the shared hand/palm/opposing-contact placement and
unresolved tissue policy, not lack of an envelope target. A radius match does not
provide that constraint automatically. Review this attempt before replacing the
search/seat rules. Full-hand character baking, consistent oblique/3D Forge wrapper
export, signed 3D validation, arm realization and runtime integration remain open.
No production runtime/core changes, anatomy rewrites, commit or push in this pass.

User follow-on direction during this attempt: once this approach produces a
decent grip, upgrade Index, Ring and Pinky on both hands to the same preparation,
skin observation, motion-rule and solver level as Middle/Thumb. Then migrate
the appropriate production responsibilities and gracefully retire the superseded
grip logic. Do not leave two active contact solvers writing the same pose. Keep
existing responsibilities the replacement does not yet implement, with explicit
ownership at their boundaries: authored placement/handle percent, reverse and
support-hand semantics, accepted Roll, upstream IK, and open/unarmed hand use.
Inventory consumers and state invalidation before cutting over; retire old paths
only after the replacement is connected and checked end to end. The incomplete
September 27 result does not satisfy the requested condition for production
replacement. Full-hand preparation and production takeover are distinct steps.

The user also raised spherical objects/magic-sphere weapons as a possible later
consumer. Retain this as future direction. A real sphere's slices can be convex,
but general 3D contact/reach and the wrapper export contract still apply; this
pass does not implement a new weapon archetype or expand the visible geometry.

### September 27 continuation: outside 50 mm circles, following and reseating

The user identified the invalid starting condition in the first envelope match:
opening digits at an already-seated Hand position left shared skin intersecting
before the new solve began. Requested test: an exact **50 mm radius circle in
each digit's own plane**, open Hand offset outside, freely sliding tangency,
shrinking, and an animated account of where progress stops. No cylinder and no
fixed anatomical palm point. Start with the prepared Middle/Thumb; do not claim
five prepared zipties already exist.

The user then requested one bounded correction after the normal pass: reopen
angles where useful, shift/reseat and close again, seeking contact on sections
that remained separated. A first joint/contact limit is not global exhaustion.
Accept a better final candidate; otherwise retain the previous result. Record
contact regions as well as count so exchanged contacts are not called additions.

New isolated trial: `run_circle_hand_process_proof.gd`, reusing the existing
candidate anatomy and authored open/closed limits. `prepared_grip_slice_contact`
now exposes its existing validated skin slicing as `slice_candidate`; the old
material-only observer again passed 199 comparisons after extraction. New
`planar_circle_skin_contact.gd` measures exact whole-edge radial clearance,
including an edge crossing the circle with both endpoints outside. Its scene-free
verifier passed 42 checks. A degenerate radial normal remains explicitly undefined.

Starting direction comes from the Wrist/Index1/Pinky1 footprint, signed by the
prepared Middle closing derivative and projected perpendicular to the authored
weapon axis. Per the user's subsequent correction, each circle center is exactly
the area centroid of its **current** weapon slice in that digit's plane. Reuse
the actual section centroid rather than retaining an earlier center along a
weapon-owned axis: oblique slices change as the Hand seats, and those two centers
must not drift apart. Each current center also has an explicit `WeaponRootOrigin`
representation; circle/slice coordinates retain their digit-plane origin and all
frames resolve to `RL_BoneRoot`. This is a two-plane diagnostic, not a cylindrical
3D collider. Changing section coordinates does not move the fixed weapon.

The first trial (`circle_hand_process_2026-09-27T01-41-41.json`) stopped at 48 mm
after losing closest contact under its error objective. It also exposed stretched
shared Hand/forearm skin from moving the Hand independently of captured upstream
bones. This is superseded diagnostic evidence, not the accepted test arrangement.

Correction communicated to user before implementation: for this isolated trial,
translate the complete captured pose presentation rigidly relative to the fixed
weapon, then articulate only selected prepared digits. Preserve source weights,
relative wrist/forearm geometry, named bone-to-machine frames and authored Hand
orientation. Every saved pose carries its actual `machine_to_world`; source case
presentation remains distinct. This does not implement gameplay body translation
or arm IK. Open Thumb1 follows the actual rules (+130 degrees right / -130 left),
not the earlier diagnostic's zero-angle assumption.

The revised follower reapproaches freely to nearest skin tangency after each
adjustment. No material flesh-give settings are changed: this first virtual-circle
phase excludes its interior for all observed skin, with 20 micrometers of target
clearance and a separate 2-micrometer numeric guard. Candidate transitions are
sampled at no more than 0.5 mm translation / 0.5 degree per joint; continuous
swept collision is not certified. All accepted parameter/checkpoint records are
saved; the replay shows retained actual geometry frames without invented poses.
The current slice must also be complete and enclosed by its circle at every
candidate and accepted transition checkpoint. The intermediate rigid-placement
run `circle_hand_process_2026-09-27T01-53-32.json` exposed five Left reseat frames
with up to 0.107332 mm of weapon outside the circle despite clear skin-to-circle
measurements. That run is superseded; it motivated the explicit containment gate.

One reseating cycle explores small coupled open/shift/reclose alternatives with
the same exclusion rules. Contact count uses a disclosed 0.1 mm band. Better
count wins, then lower remaining gap; final region identities show whether a
contact was added or exchanged. The search is bounded, not a proof that no better
pose exists. Circle reduction stops at real weapon outer extent or an explicitly
reported following/budget limit. The noncircular/concave membrane transition is
not silently approximated by shrinking a circle through the weapon.

`test_artifacts/render_circle_hand_process.py` supplies a recorded-state HTML
player (play/pause, step, scrub, separate hand selection, synchronized Middle and
Thumb views). Final [animated replay](<../../test_artifacts/circle_hand_process_2026-09-27.html>)
and [initial/final image](<../../test_artifacts/circle_hand_process_2026-09-27.png>)
use the centroid-locked report
`test_artifacts/circle_hand_process_2026-09-27T02-28-01.json`, source SHA256
`8f84b0fed497c3bacebbc6a05eca3ca648b9d5ac68b33753acdfc0a91c3ad2b5`.
Run log: `godot_runs/the_will_2026-09-27_01-58-36.log`.

| Result | Right | Left |
| --- | ---: | ---: |
| Initial circle radius | 50 mm | 50 mm |
| Final circle radius | 27.125238 mm | 31.223017 mm |
| Final nearest all-skin clearance | 0.020014 mm | 0.020046 mm |
| Required contacts before / after reseat (0.1 mm band) | 0 / 0 | 0 / 0 |
| Summed required-section gap before reseat | 52.422622 mm | 57.588811 mm |
| Summed gap after reseat | 52.418019 mm | 57.258237 mm |
| Candidate evaluations | 14,029 | 12,464 |
| Search duration | 936.928 s | 825.082 s |

Both normal passes stop at the circular outer extent; the stop remains accurate
after correction within the disclosed 0.1 mm progression threshold. Reseating
changes each pose and slightly reduces the summed gap, but adds no required
finger-section contacts. The closest overall carriers are unassigned/shared skin
in the Middle plane; they are not a verified anatomical palm. Final Middle S3 gaps
are 0.475942 / 0.371344 mm and Thumb S3 gaps are 1.657691 / 1.296401 mm (Right/Left).
Other required regions remain much farther away. This is **not a completed grip**
and does not meet the condition for full-hand/runtime migration. The following
noncircular membrane stage and improved coordinated seating remain outstanding.

The total offline run took 1,763.589 s (29.39 minutes), not an acceptable live
acquisition time. It is bounded experimental evidence, not a proof of globally
exhausted motion or all-shape correctness. Both hands retain `grip_accepted=false`.

Independent verification passed 661,630 recorded-data checks with zero failures:
507 retained geometry states (274 Right / 233 Left), whole-edge circle queries,
current area-centroid coincidence, named transforms, and complete enclosed weapon
slices. The 874 denser accepted checkpoint summaries also pass interval, clearance
and containment consistency checks; their omitted skin was not independently
replayed. Results are in the source report's `_independent_verification.json`.
The full original-weight rigid-placement oracle passed 415 checks across four
bounded poses, each with 15,992 skin vertices and 61 upstream machine bones:
`test_artifacts/verify_circle_rigid_placement_2026-09-27T02-28-50.json`.
Maximum independent world-vertex discrepancy was 0.000124 mm. This also verifies
the corrected `posed.machine_to_world` metadata agrees with its pose packet.

The final endpoint PNG was inspected. SVG geometry/frame/centroid checks and
source/output hashes are retained in the visual manifest. Player controls were
previously checked with a mocked DOM; an actual browser session was not run.
Production runtime/core and the original prepared anatomy remain unchanged;
no commit or push was made.

Read-only performance follow-up for this experiment (not implemented or timed
separately): `_targets` recomputes full-object reach per digit, then the slicer
revalidates/scans all weapon triangles and the raw target builder repeats topology
and edge-bound preparation. Immutable source validation, triangle bounds and
projections along each fixed plane normal can be prepared once. A section depends
on plane offset along its normal; tangential origin changes can reuse the same
world section with an explicit coordinate transform and freshly expressed
centroid. Do not reuse a stale center. `_circle_cache` also includes radius, so a
radius-only change repeats unchanged FK/skin preparation: separate exact pose/slice
reuse from the cheap radial query. Measure these seams before production use;
preserve coplanar/closure rejection, original weights and all contact checks.

### September 27 correction: maintained digit tangency, then palm seating

After reviewing the animation, the user clarified the intended control law.
The preceding run is valid recorded geometry but does **not** implement that law:
`_seat_on_circle` keeps the nearest contact anywhere on the skin while `_settle`
merely reduces the sum of other gaps; `_search` shrinks first and lets the hand
chase the smaller target. A shared-skin contact can satisfy its progress check
while all required finger regions remain separated. Do not call those passing
geometry checks evidence that the intended gripping behavior is implemented.

The corrected sequence and acceptance conditions for the next experiment are:

1. Start with oversized per-digit circles and establish an actually seated joint
   configuration before contraction. The previous exact 50 mm starting radius is
   superseded by the user's permission to oversize for initial tangency. Derive
   and verify a feasible starting radius/pose; enlargement alone is not proof
   that all contacts can be met. Circles still share their respective current
   weapon-slice centroids, and all digit planes share one physical hand pose.
2. Prioritize one sliding skin contact for each ordinary finger section S1-S3.
   Thumb primarily requires S2/S3; preserve its existing S1 contact exception and
   bounded flesh-give policy. No equally spaced angular anchors are requested.
   Contact locations may slide along skin and around the target; they are not
   fixed material points. Intended regional contacts must stay tangent within an
   explicit tolerance, with local surface direction checked where defined.
3. Solve radius change, joint angles and allowed shared hand placement together.
   An accepted contraction must maintain the required regional contacts and all
   exclusion/containment constraints. A good nearest point or smaller summed gap
   cannot stand in for this. If a proposed step loses contact, reduce/reject that
   step and attempt coordinated adjustment before advancing. Distinguish an
   exhausted bounded search from a proven anatomical limitation.
4. The palm is the **later seating objective**, not the initial anchor or the
   contact used to declare that the fingers are following. It still participates
   in collision checks before engagement. When the circle reaches actual weapon
   material and the envelope starts becoming noncircular, bias first-joint
   closure toward the palm while preserving the digit contacts. This requests a
   change of objective order, not an automatic new hard freeze of joint 1 during
   the earlier stage. Palm identification remains necessary; unassigned orange
   skin must not silently become certified palm or unrestricted Thumb S1 tissue.
5. Preserve one bounded reseating correction: coordinated opening/sliding/closing
   can seek a better seat, subject to the active contact/penetration rules. Record
   any deliberately released contact during an explicit reseating phase instead
   of labeling it maintained tangency.

Thumb policy rechecked in current runtime source:
`player_finger_surface_grip_solver.gd` defines
`THUMB_PROXIMAL_CONTACT_TARGET_REQUIRED = false` and
`THUMB_PROXIMAL_MAX_ALLOWED_OVERLAP_METERS = 0.005`; the serial section-cap
resolver returns that 5 mm cap specifically for Thumb S1 under the bypass.
Bypassing its contact target does not mean unlimited penetration. The previous
circular trial's uniform strict no-entry guide was a different diagnostic policy;
do not claim it already implemented this exception. Apply recovered allowances
only to correctly identified tissue, with guide and actual-material measurements
kept explicit; do not grant every unassigned/shared skin edge the Thumb S1 cap.

For the next presentation, the user does not need hundreds of tiny early steps.
Use large early advances and halve the remaining radial clearance toward first
weapon contact: `R_next = R_touch + (R_current - R_touch) / 2`, with `R_touch`
derived from the current actual slice and updated if seating changes that slice.
Do not blindly halve the absolute radius through the weapon. Use a finite contact
tolerance/final approach rather than an endless halving sequence. Backtrack a
proposed advance if tangency cannot be preserved. After first weapon contact,
switch to fine steps for noncircular wrapping and palm seating. Replay keyframes
and contact/path verification are separate; fewer shown frames do not justify
skipping necessary geometric checks.

These are recorded design corrections, not changes already made to the solver.
Retain the existing measured anatomy, exact slicing/centroid provenance, analytic
clearance, rigid-presentation verification and replay tooling. Replace the
incorrect contact objective and progression rule, rather than repeating the
29-minute search with larger starting circles and unchanged acceptance logic.

### September 27 implementation attempt: simultaneous initial circle fitting

The user authorized an implementation attempt and visual result. This pass stays
in the isolated proof tools. It does not change production acquisition, Roll,
arm IK, prepared anatomy, or authored joint limits. No commit or push was made.

New `tools/grip_plane_proof/run_tangent_hand_process_proof.gd` replaces the old
nearest-any-skin objective for this experiment with five explicit regional
equalities: Middle S1/S2/S3 and Thumb S2/S3. Six hinge angles, one shared transverse
Hand translation, and independent per-digit circle radii are fitted together.
Every circle retains the area centroid of the current actual weapon section;
there is no free center drift and no separate Hand displacement per digit.
The scaled damped least-squares step includes active no-entry residuals and
re-solves when a joint at its limit would otherwise be pushed beyond that limit.
Final acceptance checks every reachable regional witness, all observed skin, and
per-digit weapon containment. A small summed error alone cannot pass the gate.

This is **initial fitting only**, not a completed implementation of maintained
contraction. Numerical candidate snapshots may violate constraints; they are
labelled rejected and must not be played or interpreted as a physical motion.
Both initial gates failed, so no shrinking path, noncircular wrapping, or later
palm-seating stage was produced. The planned halving progression remains pending
a valid initial seat and checked coordinated continuation. The old circle runner
has only default-preserving observation/radius/target hooks and extra measurement
fields; its old search remains historical evidence, not the new behavior owner.

Bounds and policy used in this attempt:

- Initial nominal radius: largest measured digit reach, about 117.111 mm.
  Each initial fitted radius may independently range from half to twice that
  value. These are diagnostic fitting bounds, not character/Forge authoring caps
  or the separate 50.828 mm wrapper minimum inward radius.
- Initial placement examines five transverse directions and seven distances,
  preferring a clear measured start. Fitting allows a shared transverse offset
  up to three times the initial radius. It does not realize that offset through
  arm IK or change the requested handle-percent station.
- One initial fit plus one bounded reseating cycle containing two seed variants;
  at most 80 iterations per seed. Re-seeds can release candidate contacts because
  none of these trials is an accepted maintained-contact path.
- Guide-skin contact target: +0.020 mm, regional band +/-0.100 mm, all-skin inward
  numerical guard 0.002 mm. This remains the conservative virtual-circle policy,
  **not application of actual-material flesh-give allowances**. Thumb S1 is not a
  required contact. No Thumb S1-owned edges exist in these slices; shared orange
  skin is not granted the 5 mm exception. Correct tissue identification and the
  recovered overlap policy are still prerequisites for the later material phase.
- Only Middle and Thumb articulate. Other captured hand skin stays in collision
  checks; unowned skin is not synonymous with static palm. For example an earlier
  candidate's Middle-plane source triangle `0/4206` has Thumb2, Hand, Thumb1,
  Ring1 and Index1 influences, so treating it as a fixed palm patch is wrong.

Final report:
`test_artifacts/tangent_hand_process_2026-09-27T03-46-41.json`
(SHA256 `18a5213c1da2ab43fc48b7454d95bb81f62348fbf1ec05ac00215b18b771c318`).
All four recorded solver/query source hashes match the final files.

| Final measured candidate | Right | Left |
| --- | ---: | ---: |
| Middle circle radius | 76.468921 mm | 127.456686 mm |
| Thumb circle radius | 99.696890 mm | 124.762603 mm |
| Middle S1 / S2 / S3 gaps | 0.370963 / 0.295078 / 0.018555 mm | 22.182304 / 18.629179 / 10.690450 mm |
| Thumb S2 / S3 gaps | 1.523864 / 0.007820 mm | 5.896941 / 5.590529 mm |
| Required contacts in band | 2 / 5 | 0 / 5 |
| Minimum all-skin clearance | -0.001841 mm | -0.352196 mm |
| Evaluations / search duration | 1,853 / 44.601 s | 951 / 19.713 s |

The Right candidate meets the disclosed numerical exclusion guard but misses
three required contacts. Left also violates exclusion. Right Mid2 and Thumb2/3
are at or within 0.02 degrees of a prepared limit; Left Mid3 is near its limit.
All seed runs ended in bounded local-fit stalls. These facts identify active
constraints and solver failure; they do **not** prove that anatomy, fixed planes,
or the intended concept make a solution impossible. Do not loosen an acceptance
band or relabel orange skin just to report success. Investigate joint/contact
fitting and source attribution before proceeding to contraction. This offline
search is not a measured live acquisition performance result.

Visual outputs: `test_artifacts/tangent_hand_process_2026-09-27.html` and `.png`,
with `.drawing.json` and `.manifest.json`. The HTML provides both hands, independent
digit radii, per-region gaps, source markers, joint/witness toggles, and five saved
numerical snapshots per hand. Initial and selected candidates are compared in the
PNG. No interpolated skin or smoothed invented pose is displayed. Final PNG was
inspected. Twelve control assertions passed in a mocked DOM; an actual browser
session was not run.

New `prepared_weapon_plane_section.gd` prepares immutable fixed-normal source
triangle intervals once, selects conservative candidates, then retains the mature
slicer's exact intersections and complete-loop checks. It rejects rotated frames,
coplanar/open/branched sections, and dropped components; current centroids are
recomputed. It does not certify the source as a valid closed 3D solid. Its verifier
passed **158 checks** on fixtures and frozen translated sections:
`test_artifacts/verify_prepared_weapon_plane_section_2026-09-27T03-36-39.json`.
Matching section queries took 144.644 ms versus 598.079 ms, approximately 4.13x
faster in that bounded comparison; this is not a whole-solver speedup claim.

The new independent `test_artifacts/verify_tangent_hand_process.py` passed
**16,233 checks** on the final report: full segment-circle distances, source
witnesses, reach, individual radii, current centroids, containment, named origin
chains, saved joint angles versus prepared limits, and honest gate rejection.
Six deliberately corrupted reports were rejected. It does not independently
re-skin/re-slice the character, certify anatomical ownership, continuous motion,
or a full 3D grip. The existing coherent-skin/rigid-placement evidence remains
separate. Original prepared-anatomy SHA256 remains
`B7F07BF7D79DB331FCB250982A62B31D4ABC1E58D1D4B2BEEFC2754658C27DEA`.

## September 27 native IK experiment: prescribed envelope authority

User correction: the balloon/envelope prescribes the moving contact surface.
Joint angles are responses constrained by anatomy, not independent closure
drivers, and the IK solver must not change circle radius to improve its fit.
Native Godot facilities were researched before this implementation.

The isolated `run_native_envelope_follow_proof.gd` experiment connects current
measured skin witnesses to `native_digit_contact_ik.gd`. Each temporary target
is converted through the named digit plane and `RL_BoneRoot`; circle centers
remain the current actual weapon-slice centroids. Native `CCDIK3D` processes
each section target with calibrated hinge axes and the prepared angle limits.
The adapter captures `modification_processed`, checks pose conversion, axes and
limits, and returns angles for the existing original-weight skin reconstruction.
Rigid markers approximate contact motion only: actual re-skinned surfaces are
measured again before any contact claim. No skin mesh is directly deformed.

Radius is prescribed by the controller. A bounded response pass can adjust the
shared transverse hand placement using measured contact errors; native IK supplies
joint proposals. Native passes alone failed the multi-contact tests. A subsequent
simultaneous actual-skin correction reuses the mature bounded least-squares
routine with exactly eight pose unknowns (six hinge angles and two offsets).
Its overrides exclude circle radius from the unknowns and retain anatomy limits.
Initial contact
acquisition and maintained-contact contraction remain distinct. If initial
contact is not acquired, two smaller prescribed radii are diagnostic response
trials only, never labeled successful balloon-following or a proven anatomical
stop. Palm attraction and the noncircular wrapper phase remain downstream.
Each native contact now gets newly reconstructed blended skin and a newly chosen
sliding target after the preceding contact changes the pose. Reusing the first
pose's five targets through a whole sweep was measured to move a later appropriate
target by about 10.8 mm in one example. Earlier joints are temporarily held only
when their required sections are already within the contact band; freezing an
unacquired contact prematurely was tested and did not help. The simultaneous
correction can re-seat all permitted joints afterward.

The shared proof harness now awaits `_search`: Godot returns ordinary synchronous
values immediately and awaits a coroutine when the native modifier needs it.
No production grip path is enabled or replaced by this experiment.

Official 4.7 references used:
[IterateIK3D](https://docs.godotengine.org/en/4.7/classes/class_iterateik3d.html),
[ChainIK3D](https://docs.godotengine.org/en/4.7/classes/class_chainik3d.html),
[SkeletonModifier3D](https://docs.godotengine.org/en/4.7/classes/class_skeletonmodifier3d.html),
[GDScript await](https://docs.godotengine.org/en/4.7/tutorials/scripting/gdscript/gdscript_basics.html#awaiting-signals-or-coroutines).
Native settings that share bones execute sequentially; targets can disturb
earlier contacts. Existing dormant runtime finger IK is not sufficient as-is.
Native engine convergence does not certify collision, multi-contact grip, final
joint-limit compliance, or lack of skin pinching. The engine and geometry results
below distinguish adapter checks from actual grip acceptance.

First native engine gate (`verify_native_digit_contact_ik_2026-09-27T05-17-05.json`):
51 checks, four failures. No-motion frame conversion passed, but a deliberately
moved feasible skin target did not move the finger on either hand. Investigation
of the official [4.7 CCD implementation](https://raw.githubusercontent.com/godotengine/godot/4.7/scene/3d/ccd_ik_3d.cpp)
found an absolute approximate-zero check on the product of two squared lengths.
A roughly 24 mm lever can fall below that threshold; increasing iterations does
not address that skip. The adapter was corrected to use an explicitly named
millimetre computational space with reversible conversion to the unchanged
physical geometry. Native source diagnosis is not itself a passing engine test.
The corrected native adapter subsequently passed 57 engine checks. Adding
explicit temporary upstream locks and their violation checks raised the focused
gate to **93 passing checks**, with no engine errors:
`test_artifacts/verify_native_digit_contact_ik_2026-09-27T05-25-18.json`.
Those checks cover the isolated adapter's tested target responses, conversions
and constraints; they do not certify the combined grip.

Final combined experiment:
`test_artifacts/native_envelope_follow_2026-09-27T05-31-23.json`
(SHA256 `2c2b7191b5e10d0efbfd25daef2fbb48f9e1a4c974db41cabcaf2596f8948f97`).
The diagnostic executed successfully; **the grip/contact acceptance failed on
both hands**. Its `ok` flag is diagnostic integrity, not successful gripping.
Initial five-contact acquisition failed, so the two smaller prescribed radii
are explicitly response probes, not a maintained-contact deflation path.

| Selected circular response | Right | Left |
| --- | ---: | ---: |
| Prescribed radius | 51.164970 mm | 54.876600 mm |
| Middle S1 / S2 / S3 gaps | 0.717486 / 0.006789 / 0.566073 mm | 2.975316 / 0.038054 / -0.008563 mm |
| Thumb S2 / S3 gaps | 1.045935 / -0.015810 mm | 4.802652 / -0.023616 mm |
| Required contacts in band | 1 / 5 | 1 / 5 |
| Minimum whole-slice clearance | -0.015810 mm | -0.106561 mm |
| Native calls / measured candidates | 105 / 1,598 | 100 / 1,053 |
| Offline search duration | 40.778 s | 27.317 s |

This remains the previously disclosed strict virtual-guide test (+0.020 mm
target, +/-0.100 mm band, 0.002 mm inward numerical guard). Saved material
flesh-give values were not widened or applied to unassigned skin. Some final
joint limits are active, but stalls and the bounded iteration budget are **not
proof of anatomical impossibility**. Do not claim that native IK automatically
maintains multiple skinned contacts, that the wrapper phase ran, or that this
offline diagnostic is suitable runtime performance. Full diagnostic duration
was 68.943 s across both hands.

Visuals: same report basename with `.html`, `.png`, `.drawing.json` and
`.manifest.json`. HTML steps through recorded states; PNG compares initial and
selected states. No invented skin interpolation is drawn. The final PNG was
inspected; browser execution was not performed. Both prepared anatomy and the
production grip path remain unchanged by this experiment.

The independent saved-output audit passed **21,463 checks** on the final report:
`test_artifacts/verify_native_envelope_follow_2026-09-27T05-31-23.json`.
It recomputes retained segment/circle geometry, source centroids and named
transforms, verifies fixed radius throughout native and numerical correction
records, checks native marker unit conversion and per-call target projection,
and checks saved angles against prepared ranges. Deliberately corrupting a
radius and falsely claiming contact acceptance were both rejected with nonzero
verifier exit codes (`verify_native_envelope_follow_fault_detection_2026-09-27.json`).
These are evidence-integrity checks, not passing grip checks. The Python audit
does not independently re-skin/re-slice the source mesh, replay engine internals,
certify anatomical section attribution or establish continuous/3D collision.

Next bounded investigation: establish the three-contact circular fit for Middle
alone and the two-contact fit for Thumb alone, using the same actual skin,
prepared limits and fixed guide. Then test their shared-hand compatibility.
This separates individual contact/pose problems from coupling through one hand;
it does not authorize changing anatomy or loosening acceptance to conceal gaps.
The later membrane/palm/material seating stages must follow actual verified
contact acquisition. The current native adapter is a tested component, not a
completed gripping replacement.

### September 27: full guide-to-material process and bounded reseating

Implemented in `tools/grip_plane_proof/run_handle_grip_process_proof.gd`,
reusing the coherent original-weight skin reconstruction, fixed-normal weapon
sections, native CCD adapter and bounded simultaneous skin-contact correction.
This is an isolated Middle/Thumb diagnostic for each hand. Guide radius/shape is
prescribed; joint angles and shared transverse placement respond to measured
skin error. The old initial-contact/two-radius cutoff is absent. Preparation
misses are recorded while contraction proceeds to the actual material phase.
Missing reachable witnesses now carry a measured reach penalty rather than
zero error; unrestricted nearest points can supply approach direction but cannot
count as contact or as native contact targets. An earlier aborted experiment's
near-zero error with missing witnesses was misleading and is superseded.

`planar_grip_guide_progression.gd` supplies circle, convex-hull transition and
limited concave wrapper stages around the current actual slice centroid. It
uses the existing measured inward radius, **50.8284749483291 mm**, unchanged.
The source shape remains enclosed within the stated numerical tolerance.
Material contact is evaluated against the actual weapon section separately
from contact with its guide. Three distinct sections across one hand trigger
the sufficient-contact stop only when all measured overlap gates also pass.
Otherwise this run continues to the final established wrapper limit.

`prepared_palmar_slice_region.gd` attributes a conservative palmar core from
Wrist/Index/Pinky reference geometry, authored closing-side orientation,
visible reference skin and original source/barycentric provenance. Only those
unowned fragments receive the new 2.5 mm cap. Digit-owned fragments retain their
existing policy. Hand weight alone is not anatomy: genuine palmar faces include
mixed Hand/Thumb/proximal-digit weights below 50% Hand. The final geometric
partition includes 36 eligible reference faces, 6-7 observed Middle-plane palm
fragments and no attributed Thumb-plane palm fragments in these inputs. It is
not a complete thenar/palm partition. Tiny unrepresentable boundary fragments
are conservatively coalesced without inventing or dropping skin edges.

Reseating freezes the stopped guide geometry and the shared hand translation,
and adjusts the six prepared hinges. This limited freedom was disclosed before
the test. It does not yet implement shared hand translation during reseating.
Acquired guide/material section contacts are retained across accepted steps;
intermediate poses are sampled at up to 0.25-degree increments (bounded at 32
samples per step). These samples do not prove continuous-path contact. The
counter is shared across one hand's solve, capped at three attempts, with early
exit when no legal improvement is found. Frozen guide fingerprints, retained
contacts, joint ranges and per-section depths are checked independently.

Final engine report:
`test_artifacts/handle_grip_process_2026-09-27T07-15-17.json`, SHA256
`afc54bde27d7cc7c391b28d3861612bc745db161a074fb7e9c487ffa6358bc20`.
The run completed with no diagnostic failures. Report `ok` means the diagnostic
ran correctly; it does not mean both grips succeeded.

| Measured final result | Right | Left |
| --- | --- | --- |
| Actual material-contact sections | Middle S1; Thumb S2 | Middle S3; Thumb S2; Thumb S3 |
| Distinct material contacts | 2 | 3 |
| Stop | Established inward-curvature wrapper limit | Sufficient material contact at convex hull |
| Reseat attempts | 1; no legal improvement | 2; first improves, second finds no further improvement |
| Guide/material overlap gates | Pass / pass | Pass / pass |
| Three-section diagnostic minimum | Not met | Met |
| Measured candidates | 1,723 | 1,666 |
| Offline search duration | 255.623 s | 238.013 s |

Left retained all three contacts during its accepted reseat. It did not continue
unnecessarily into the concave wrapper after sufficient material contact.
Right's missing final sections are Middle S2/S3 and Thumb S3; Middle S3 remains
about 0.442 mm clear of actual material, which is not contact. Neither final
pose has attributed palm contact. Both final poses also lack some intended
guide contacts. **Constant tangency to all intended sections has not been
demonstrated.** Right's stalled correction is not proof of anatomical
impossibility. Left's three-contact result is not full-hand or 3D acceptance.

Complete offline diagnostic duration was **495.523 s**, including both hands.
This is expensive measurement/search tooling, not acceptable production grip
latency. All-finger integration, complete palm attribution, shared-hand/arm
reach, reverse/two-handed combinations and runtime cost remain downstream.
Prepared anatomy was not modified; its file SHA256 remains
`b7f07bf7d79db331fcb250982a62b31d4abc1e58d1d4b2beefc2754658c27dea`.

Fresh verification artifacts (all under `test_artifacts`):

- `verify_planar_grip_guide_progression_2026-09-27T06-54-04.json`: 924 checks,
  including non-star-shaped source geometry, nested stages, containment,
  centroids, endpoints and cache isolation.
- `verify_prepared_palmar_slice_region_2026-09-27T07-06-57.json`: 4,549 checks,
  including reference attribution, immutable source/pose, full fragment
  coverage and actual circle/polygon consumers.
- `verify_handle_grip_initial_sample_2026-09-27T07-06-50.json`: both initial
  combined samples pass after fixing the tiny-fragment consumer failure.
- `verify_handle_grip_process_2026-09-27T07-15-17.json`: 110,961 checks with
  6,066 independently queried polygon edges; deliberate false contact count,
  changed frozen guide and fourth reseat are all rejected. This independent
  audit recomputes saved 2D geometry; it does not independently reconstruct
  anatomical membership, reskin the source or certify continuous/3D collision.

Visual review:
[recorded replay](<../../test_artifacts/handle_grip_process_2026-09-27.html>) and
[initial/final comparison](<../../test_artifacts/handle_grip_process_2026-09-27.png>).
The replay provides right/left selection, recorded-state playback, final-focus
view and contact witnesses. Full-process and final-focus views have separate,
explicitly labeled equal-axis scales. PNG was rasterized from the same measured
drawing and visually inspected. No intermediate skin poses were invented or
interpolated; browser execution was not performed. The renderer/manifest retain
source hashes, named frames and the measured section-centroid residuals.

Next bounded work is the contact deficit and seating freedom revealed by these
results, guided by the replay. Keep the agreed full preparation-to-material
sequence and three-attempt failsafe. Do not widen flesh-give caps, redefine
unassigned tissue as palm, or turn a numerical stall into a claimed physical
limit. Production integration and general cleanup remain outside this experiment.

Official documentation rechecked for this implementation:
[Geometry2D](https://docs.godotengine.org/en/4.7/classes/class_geometry2d.html)
and [IterateIK3D](https://docs.godotengine.org/en/4.7/classes/class_iterateik3d.html).

### September 27 completed experiment: three existing straight handle templates

User requested any three existing handle templates as linear sections, tested
against the current grip process. This is a shape-comparison experiment, not
authorization to retune the solver for particular profiles. Executed plan: load saved
Forge V2 handle profiles from the workspace diagnostic library, retain their
actual scale and authored profile orientation, construct straight closed meshes
through the existing Forge sweep implementation, and test both captured hands.
Reuse the same anatomy, motion/overlap limits, guide progression and maximum
three reseats. Preserve source profiles and the previous star-shaped evidence.

Added files: new `tools/grip_plane_proof/linear_handle_template_fixture.gd`
and `run_handle_template_grip_proof.gd`; narrowly extend the existing
`test_artifacts/render_handle_grip_process.py` for unique output prefixes and
add `test_artifacts/render_handle_template_comparison.py`. New measured reports
and visuals remain under `test_artifacts`. Existing grip algorithms are read-only
for this comparison. Register each fixture's profile/sweep placement through
the captured weapon origin to `RL_BoneRoot`; keep fixture provenance distinct
from the original captured weapon. No new gameplay rules need deciding.
Execution, failures and measured outcomes are recorded below.

Input correction before accepted comparison: the first three input reports
(`verify_handle_template_input_*` at 07:35:30 / 07:35:52 / 07:35:56) passed
closed-mesh and coordinate checks, but an independent source-profile comparison
found about 20-51 micrometres of boundary distortion. The fixture used
`Mesh.get_faces()`, whose Godot 4.7 TriangleMesh path snaps vertices to a 0.1 mm
grid. The first full batch (log `the_will_2026-09-27_07-36-17.log`) was stopped;
its partial results are superseded and must not be used as the final comparison.
The fixture extraction was changed to direct surface vertices/indices,
retaining the existing Forge extrusion and unchanged grip code. This precision
correction passed fresh input checks before restarting the three trials.
Official source: [TriangleMesh creation, Godot 4.7](https://github.com/godotengine/godot/blob/4.7/core/math/triangle_mesh.cpp#L127).

Corrected input gate: fresh reports at 07:42:41 (rounded rectangle), 07:42:45
(`rombus`) and 07:42:49 (`odd shape 3`) all pass on both hands. The new fixture
also checks that both complete extrusion rings match the saved polygon and
span within a stated 0.2 micrometre coordinate-roundoff guard. Direct arrays
have maximum profile-plane error about 0.0113 micrometres. Independent tool
`test_artifacts/verify_linear_handle_template_inputs.py` then compares the
analytic straight-prism sections with all twelve reported digit sections:
585 checks pass, maximum discrepancy 0.06993 micrometres; three injected faults
and the old rounded extraction are rejected. Evidence:
`test_artifacts/verify_linear_handle_template_inputs_2026-09-27T07-42-49.json`.
The complete comparison restarted at 07:44:42 and completed at 08:08:15 with
engine exit 0. All three complete reports have `ok=true` and no harness failures;
that is execution success, not acceptance of all six resulting grips.

Saved input provenance: workspace-frozen library
`test_artifacts/pre_grip_overhaul_backup_2026-09-18_00-43-48/external_user_saves/forge/tool_presets/player_tool_profile_library_state.tres`,
SHA-256 `44a66462e706cbdb3fb2d3f829f6f615f28cda0020c9fef48d5c9031cf036133`.
All three saved rotations are zero. Each straight extrusion preserves the
captured span endpoints, direction and midpoint: length **539.407 mm**. Exact
saved profile polygons feed the existing Forge compiler and sweep mesher. Each
fixture has a named profile origin derived from the captured weapon origin,
which remains traceable to `RL_BoneRoot`. Each hand is tested separately;
this is not a simultaneous support-hand solve.

| Saved template / actual outline size | Right final material contacts | Left final material contacts | Minimum accepted |
| --- | --- | --- | --- |
| `handle profile 1testa`, rounded rectangle, 25 x 37.5 mm | 2: Middle S3, Thumb S2 | 2: Middle S2, Thumb S3 | Neither hand |
| `rombus`, 37.5 x 75 mm | 3: Middle S2/S3, Thumb S2 | 3: Middle S2/S3, Thumb S2 | Both hands |
| `odd shape 3`, 49.445696 x 62.759906 mm | 3: Middle S2/S3, Thumb S2 | 2: Thumb S2/S3 | Right only |

Profile IDs, respectively: `handle_profile_1783395703.211_3`,
`handle_profile_1787890891.94_10`, `handle_profile_1787891232.544_14`.
The odd shape's authoring width/height fields say 37.5 x 75 mm, but its saved
final polygon has the larger/different bounds shown above. The fixture preserves
that polygon without rescaling it to those authoring fields.

All six final poses pass the existing measured material/guide safety gates;
all use at most three reseats. Rectangle right/left used 1/2 attempts; rombus
2/3; odd shape 3 used 3/1. The odd right case stopped at the three-attempt cap
despite all three attempts improving. Each three-contact case stopped shrinking
at sufficient material contact at the hull transition. Each two-contact case
reached the final permitted wrapper geometry before final assessment. Neither
an unsuccessful reseat nor that geometry endpoint proves anatomical impossibility.

**Remaining limitations:** no attributed palm contact in any final case;
missing digit contacts and preparation tangency errors remain visible. Only
Middle and Thumb articulate. Shared placement and digit planes remain fixed
during reseating. Sampled accepted paths were checked, but continuous contact,
full 3D collision coverage, the entire palm and full-hand grip are not certified.
Three safe sections meet the diagnostic minimum only, not the complete grip goal.
The three full reports took **1,404.298 seconds (23 min 24.298 s)** in total.
These are offline diagnostic timings; this search is not runtime-ready.

Completed reports under `test_artifacts/`:

- `handle_template_grip_rounded_rectangle_2026-09-27T07-51-49.json`
- `handle_template_grip_rombus_2026-09-27T08-00-20.json`
- `handle_template_grip_odd_shape_3_2026-09-27T08-08-15.json`

The unchanged process verifier passed **344,499 checks** across those reports.
Independent saved-source/analytic-prism checks passed **13,132 checks** across
all **120 retained states**, plus initial/selected records; maximum section
discrepancy **0.079 micrometres**. Detailed `verify_handle_template_grip_*` and
`verify_linear_handle_template_*_full_*` reports sit beside their source reports.
The base process runner, guide progression, palm attribution and saved profile
library hashes were rechecked unchanged. No anatomy or solver retuning occurred.

Visual entry point:
[three-template comparison and recorded replays](../../test_artifacts/handle_template_comparison_2026-09-27.html).
Its manifest records source/output hashes. All 33 local links, six result rows,
replay control references, 120 recorded states, 480 playback SVGs and three exact
profile thumbnails passed static verification. A browser was not launched.
Rasterized initial/final panels were visually inspected for all three templates:
`handle_template_rounded_rectangle_2026-09-27.png`,
`handle_template_rombus_2026-09-27.png`, and
`handle_template_odd_shape_3_2026-09-27.png` under `test_artifacts/`.
These show measured poses; playback does not invent poses between samples.
Production integration, full-hand expansion, Git commit and push remain untouched.

### September 27 full-hand upgrade and integration — active

User direction: existing template results are useful; proper handle orientation
may improve seating. Upgrade the other fingers to the same system and implement
new gripping. No new joint ranges, flesh-give budgets, contact threshold or
three-reseat limit were requested. Keep current measured 2.3x envelope radius;
ten-tip aggregate tuning and character-save automation remain separate work.

Implementation sequence and owners:

1. `bake_character_hand_anatomy.gd` prepares all ten digits using existing authored
   rules and measured skin. New `rest_all_digits_surface_measurements_v1` Resource
   gets its own signature/path. Retain the historical four-digit definition.
   Extend store/signature verification and character-preparation documentation.
2. Generalize the current shared/circle/tangent/native/handle proof controller
   chain and `native_digit_contact_ik.gd` around an explicit ordered digit list.
   Two-digit default remains available for regression. Five-digit order is
   Middle, Thumb, Index, Ring, Pinky: 15 hinge angles plus two shared offsets.
   Inherited bounds, scales and reseat path checks must use that same layout.
3. `extend_prepared_anatomy_capture.gd` validates exact old/new reference-surface,
   character metric and existing-digit equality before reusing a historical
   complete pose with the new definition. Reconstruct skin before/after and
   validate all newly selected chains. Save separate derived traces with original
   provenance; never overwrite or blindly relabel old captures.
4. `run_full_hand_grip_proof.gd` feeds the new preparation into unchanged contact
   policy. Extend `render_handle_grip_process.py`, `verify_handle_grip_process.py`
   and shared prepared-limit reader for explicit five-digit reports. Preserve
   old two-digit evidence; new output gets separate paths.
5. Correct new whole-object capture in `capture_grip_placement_stage.gd` to read
   raw surface/index arrays. Its old `get_faces()` path quantizes like the earlier
   fixture bug; historical captures remain historical geometry. Verify this
   extraction independently without retuning the grip.
6. Live cutover must own the complete exact-surface acquisition transaction:
   current preview seats the weapon before the separate finger presenter writes
   rotations. Replacing only the finger call would retain conflicting ownership.
   Existing arm guidance/contact-basis APIs can realize a target but mutate the
   rig and do not provide atomic acceptance. Convert candidate Hand-in-weapon
   placement to those semantics, realize the actual rig, recapture/revalidate
   skin, then commit or restore the complete relationship. Keep retained Roll,
   free/unarmed hands and nonmigrated providers under their existing ownership.
7. Measure the full acquisition cost before enabling a synchronous live route.
   The current offline free-placement search shifts the captured presentation;
   it is not proof of actual arm reach or final live skin deformation. Runtime
   code must not start depending on SceneTree proof runners or rebake anatomy
   during grip updates. Reusable code needs the documented runtime/core owner.

Pending user decision asked in chat: after at most three reseats without an
accepted result, reject the grip-changing edit and restore the prior valid
relationship, or keep the edit with a safe pose explicitly marked unresolved.
Neither option permits an unsafe pose or calls a partial pose an accepted grip.
Independent preparation/controller work can proceed while this is answered.

Status: full-hand preparation and controller extension implemented and the
five-digit process measured on both hands. No live cutover yet.

Focused evidence from this implementation pass:

- New ten-digit Resource: signature
  `4935fa57cf6cc689121ae6077987b0985fc1fa7d0d3d8718f096418ea3c5b702`,
  revision `rest_all_digits_surface_measurements_v1`. First bake 2269.893 ms;
  repeated export reused it without baking (502.611 ms total). Historical
  `0fb9e5...` Resource remains unchanged. Store checks: 85; signature checks: 52.
- Candidate skin verification: 1,123 passing checks, both hands/all five digits,
  distinct joint perturbations and original-array weighted-skin comparison.
  Maximum world reconstruction error 0.358 micrometers. Report
  `test_artifacts/verify_prepared_hand_candidate_pose_2026-09-27T08-34-38.json`.
- Native chain/layout verification: 415 passing checks, all five chains per hand,
  measured contact proxies and moving targets, unchanged limits, rejected mixed
  hands and legacy eight-parameter regression. Report
  `test_artifacts/verify_full_hand_native_layout_2026-09-27T08-39-01.json`.
  An initial verifier-only untyped-array return failed; corrected typed digit
  constants and reran. This is not evidence of final mesh contact.
- Explicit capture extension: 50 passing checks including 21 injected faults;
  old/new skin vertex identity and original-trace immutability. Report
  `test_artifacts/verify_prepared_anatomy_capture_extension_2026-09-27T08-38-41.json`.
- Raw whole-object capture: 39 passing checks including indexed/nonindexed
  surfaces and 13-37 micrometer geometry. Fresh actual-star traces captured at
  08:33:14 (right) and 08:33:25 (left) supply the new full-hand run. Original
  captures are retained. The capture still observes the old live acquisition;
  its old grip acceptance results are not new-solver evidence.
- Old default Middle/Thumb initial sample is exactly unchanged in the selected
  comparison fields (`verify_handle_grip_initial_sample_2026-09-27T08-29-17.json`).
- Measurement qualification: eight of 360 stored transverse rays hit a different
  digit, including pre-existing Middle rays. They are whole-mesh ray samples,
  not validated finger thickness. Current grip collision uses actual weighted
  skin instead; every consumed terminal ray hits its own S3 surface. Evidence:
  `test_artifacts/saved_digit_measurement_source_audit_2026-09-27.json`.

Runtime extraction findings (not implemented runtime ownership): the proof uses
five inherited SceneTree runners with tool file loading and native-node ownership.
Do not make the editor depend on that stack. Extract one acquisition controller
with supplied prepared anatomy, immutable object snapshot, contact configuration
and native proposal adapter. Keep trace adaptation, fixtures and reports in tools.
Separate the shared triangle-slice operation from old per-digit preparation;
separate anatomy validation from persistence; reuse calibrated FK and flesh-give
rules through one authority. Cache the measured palmar preparation with character
data and give the measured envelope configuration a runtime data owner.

The immediate actual-pose bridge is read-only observation: reconstruct all skin
contributors from a coherent captured pose, retain actual bone frames, register
Hand-derived measurement planes and report actual calibrated articulation limits.
Do not use Candidate.evaluate to "validate" a realized pose: it would replace
the articulation with proposed FK. Compare acquisition identities and recapture
after the rig/modifier phase before any eventual live acceptance. This remains
planar observation, not a certificate of off-plane collision or whole-palm coverage.

Cost audit identifies repeated candidate reconstruction, repeated origin registry
validation (candidate plus observer/palm for each digit), and per-edge depth work.
Existing score, weapon-section and guide caches already remove some repeats.
Profile a saved material-stage sample plus at most 17 finite-difference coordinate
probes (35 sample calls including fallback directions) before selecting an exact
reuse change. Preserve cap bounds, witnesses, original skin and contact decisions;
do not infer an interactive latency improvement from source inspection alone.

Completed full-hand process:

- `test_artifacts/full_hand_grip_process_2026-09-27T09-05-46.json`; both hands
  executed without harness failures. Right: 883.551878 s / 3,434 evaluations;
  left: 705.245120 s / 2,880 evaluations. Total diagnostic: 1592.400535 s.
- Right material contacts: Middle S1/S3, Thumb S2/S3, Index S2, Ring S1. Shrinking
  first reached three; the third reseat added Middle S3 and both Thumb contacts.
  All three reseats improved the objective and preserved acquired contacts.
  Pinky still has no actual material contact. Other individual gaps remain.
- Left material contacts: one attributed palm region, Index S3 and Pinky S3.
  First two reseats improved; third found no legal improvement. Thumb remains
  separated from material (S2 about 8.619 mm; S3 about 7.499 mm). Do not describe
  the minimum contact count as every digit seated or as proof that a better pose
  is anatomically impossible.
- Both stop at sufficient measured material contact before the final concave
  wrapper: right hull transition 1.0; left hull transition 0.75. The agreed early
  sufficient-contact rule is unchanged; no radius/overlap limit was loosened.
- Independent report verification: 236,624 checks, zero failures, injected faults
  rejected. Report `verify_full_hand_grip_process_2026-09-27T09-05-46.json`.
  Renderer: `test_artifacts/full_hand_grip_review_2026-09-27.html` plus source/hash
  manifest and endpoint SVGs. This is recorded numerical-state playback, not
  captured gameplay. Original two-digit and template artifacts remain unchanged.
- Actual-pose observation bridge now exists in `observed_hand_pose_view.gd`.
  Its verifier passed 1,752 checks and 16 fault cases, observing four real capture
  stages with all five planes and original-array skin reconstruction. Maximum
  world skin error 0.3581 micrometers. These are old live input captures, not an
  applied new grip; their measured articulation is not wholly planar. The adapter
  reports that fact without replacing the geometry or granting acceptance.
  Report: `verify_observed_hand_pose_view_2026-09-27T09-06-45.json`.
- Bounded profiling (`profile_full_hand_grip_sample_2026-09-27T09-09-19.json`):
  18 samples per hand (saved material pose plus one probe per coordinate), original
  metrics reproduced within 2.43e-17 m. Right 6.713 s, left 11.235 s. Polygon
  material+guide depth occupies 5.065/6.710 s and 9.510/11.231 s of sample time.
  This supports testing exact per-edge reuse. No interactive speed claim yet.
  Initial profiling rejected JSON round-trip differences at an exact-array guard;
  corrected the profiler to restore the original Float32 offset boundary within
  1e-12, without changing physical limits or solver acceptance.
- Exact query-cache prototype (`exact_cached_planar_skin_overlap_budget.gd`):
  complete target identities are interned without digest-only matching; exact
  edge inputs reuse detached measurement records. Validation still executes,
  invalid outer queries publish no cache entries, and storage is bounded.
  Focused verifier: 114 passing checks, report
  `verify_exact_cached_planar_skin_overlap_budget_2026-09-27T09-13-36.json`.
- Fair instrumented comparison: uncached report `profile_full_hand_grip_sample_2026-09-27T09-14-09.json`
  and cached report `profile_full_hand_grip_sample_cached_2026-09-27T09-17-33.json`.
  All 360 complete measurement packets match exactly, as do all 34 Jacobian
  columns, probe parameters and selected contact decisions. Right local batch:
  6.901 -> 4.100 s (40.6% reduction); left: 11.661 -> 5.892 s (49.5%). This is
  one local 18-sample neighborhood per hand, not full-acquisition latency.
  Accounted persistent edge storage reached its 32 MiB bound with eviction;
  target storage was about 1.31/2.38 MB. The comparison is recorded in
  `verify_exact_depth_cache_profile_comparison_2026-09-27.json`.
  Only the explicit profiler option installs the cache; no live cutover or
  interactive-performance claim follows from this measurement.
- `diagnose_selected_grip_arm_realization.gd` now tests one saved proposal per
  hand on the isolated real preview rig, without running another acquisition.
  It validates exact source/weapon geometry, derives the requested Hand and
  grip-alignment frames through WeaponRootOrigin to RL_BoneRoot, uses the
  existing six-pass arm operator, applies only 15 calibrated digit rotations,
  and captures actual skin inside `Skeleton3D.skeleton_updated`. Actual planes
  and material queries use that capture, not FK-reconstructed substitute skin.
  The isolated test weapon is held fixed independently of attachment ancestry.
- First complete realization evidence:
  `selected_grip_arm_realization_2026-09-27T09-33-53.json`.
  Harness completion is **not grip success**. Right Hand target error: 29.996 mm
  and 21.815 degrees; left: 9.620 mm and 4.749 degrees. Actual material contact
  sets become right attributed palm only / left none, and material caps fail.
  This establishes that the tested existing placement handoff cannot simply
  apply the free-placement proposal; it does not establish anatomical
  impossibility or identify a new solver failure. Do not add arbitrary arm
  correction loops, weaken caps, or claim copying finger angles completes P4.
- Rotation-only writes preserve all 15 digit positions/scales exactly, both
  immediately and after modifiers. Measured joint rotations match the proposed
  hinge angles closely. Live animated local origins differ from the prepared
  chain by up to about 0.098 mm; the original articulation reporting guards flag
  these differences. Their source remains unresolved. The first two diagnostics
  stopped at the geometry preflight (`09-29-58`, `09-31-56`); using canonical
  local FK instead of a world-frame inverse did not remove the mismatch. The
  observation diagnostic now records finite mismatches without changing any
  dimensions, while leaving acceptance false. This is not a relaxed grip rule.
- Realization report classification is deliberately separate from inherited
  planar acceptance. The tool records the raw planar predicate under a
  non-acceptance name and forces nested diagnostic acceptance false. Its
  auxiliary enclosing-circle guide measurements do not certify equivalence to
  the saved frozen wrapper. No production writer or failure policy is enabled.
  Final report with that classification fix:
  `selected_grip_arm_realization_2026-09-27T09-36-21.json`. Source hashes, all
  30 unchanged position/scale records and exact repeat of the previous measured
  frame errors, contacts and articulation diagnostics were checked in
  `verify_selected_grip_realization_evidence_2026-09-27.json`. Both isolated
  observations finish; neither is an accepted grip.

Godot 4.7 official `CCDIK3D`, `SkeletonModifier3D` and `Resource` documentation
was consulted before implementation. Existing native IK proposals remain subject
to original-weight skin validation; native point targeting alone is not a
contact certificate. No commit or push authorized.

## Local game cutover — 2026-09-27 (in progress)

User direction: the full-hand result is good enough to try in the local game.
Implement the shared new grip route in Skill Crafter now; this is not a Git push.
Keep one solver authority and prevent the legacy seat/finger writers from
overwriting owned hands. Open/unarmed behavior remains a separate valid route.

Plan: promote the used prepared-skin/contact mathematics into runtime ownership,
with thin compatibility adapters at tool paths; extract one acquisition controller
used by game and proof; then wire preview acquisition, application and retention.
Prepared character anatomy and the already approved measured envelope radius are
loaded once. Pure calculations run separately from scene updates. Changing the
handle percentage, reacquiring, engaging support or changing support position
requests a fresh seat and grip solve. Ordinary motion and wrist–Tip Roll retain
the solved relationship. Cancelled/outdated jobs cannot apply their result.

Assumptions: current character remains Josie with the prepared ten-digit anatomy;
current eligible provider supplies editable baked weapon mesh and named span.
The approved 0.0508284749483291 m inward radius remains the measured right-middle
side radius times 2.3, not a claimed ten-digit average. No retuning of caps or
new gameplay acceptance rule is authorized by this cutover.

NEEDS_DECISION remains the eventual user-facing failure policy; implementation
must expose unresolved acquisition truth, never relabel a failed actual grip as
successful. The earlier free-placement-to-arm mismatch must be addressed in the
application adapter and checked on the actual rig, without stretching bones.

Files: canonical helpers/controller in `runtime/player/grip/`, character data in
the project's prepared character data owner, compatibility scripts under
`tools/grip_plane_proof/`; `combat_animation_station_preview_presenter.gd`,
`player_humanoid_rig.gd`, and `player_rig_finger_grip_presenter.gd` for active
ownership; a focused live integration verifier. Exact promoted dependency files
are recorded with the resulting implementation. No unrelated cleanup, save/F
workflow expansion, installations, commit or push.

Verification must cover acquisition at the current position, position-change
invalidation, stale-result rejection, unchanged bone sizes, single active writer,
retained Roll, and release to open/unarmed hands. Historical offline passes are
not a live integration pass. Engine work consulted official Godot 4.7
thread-safety and Skeleton3D documentation before this cutover.

### Local cutover implementation and measured boundary

The new route now exists in local Skill Crafter. Runtime-owned helpers live in
`runtime/player/grip/`; historical proof paths are thin compatibility adapters.
`handle_grip_acquisition.gd` owns the common five-digit solve and private worker,
`preview_grip_acquisition.gd` owns capture/request/cancellation/application, and
`hand_grip_pose_binding.gd` retains the single Hand-in-WeaponRoot relationship.
Character data lives under `core/defs/characters/josie/` and is loaded rather than
rebaked during acquisition. No source or test evidence was pushed to Git.

Position changes, explicit reacquisition and support-hand position changes queue
a fresh seat. An unchanged primary hand is not reacquired for a support slider.
Completed Roll retains the relationship. Pending Roll currently cancels an
unfinished acquisition so a late result cannot move the arm after that edit;
the Reacquire grip action restarts at the current station. This is the stated
default for the unanswered optional pending-Roll preference. Playback/bake entry
cancels pending work; this does not implement new F/save/playback grip parity.

Measured evidence (September 27):

- `verify_live_prepared_grip_2026-09-27T14-44-38.json`: 90 integration checks,
  no harness failures. Real UI handle-position edit, stale-result exclusion,
  all-five-digit application, retained Roll and release were exercised. The full
  acquisition took 620.304 s; the maximum observed frame was 361.402 ms. Running
  the search on a worker does not make this acceptable editing latency.
- `verify_handle_grip_acquisition_2026-09-27T14-46-47.json`: 44 checks, both hands,
  tool/runtime measurement equivalence, frozen guide identity, cancellation,
  host removal and worker shutdown. This is extraction/lifecycle evidence.
- `verify_live_prepared_grip_2026-09-27T14-56-07.json`: 99 lifecycle checks, no
  failures, including pending Roll, explicit reacquire, support station isolation,
  close/release and detecting bone changes during asynchronous assessment.
- `verify_realized_grip_assessment_2026-09-27T14-45-38.json` observes the actual
  applied capture. The observation tool succeeds; the grip does not: material
  caps fail and no sections qualify as actual material contacts. Offline proposal
  contacts must not be presented as actual rig contacts.

The applied right-Hand target missed by 1.121 mm and 14.539 degrees after six
existing settling passes, without a reach/body target clamp. The new adapter
still calls the old contact wrist-clamp/reconstruction routine. The saved-pose
probe live_grip_wrist_constraint_2026-09-27T14-57-02.json passed 96 reconstruction
and provenance checks. It measured requested twist 78.664 degrees, the pure
clamp at effectively zero, and the subsequent Index–Pinky basis reconstruction
at 75.037 degrees. The final function reproduces the actual 14.539-degree error.
Thus the nominal zero-degree wrist setting is not consistently enforced by that
legacy routine; this is not proof of anatomical impossibility. The dedicated
twist bones are not Hand ancestors. Their existing allocation formula assigns
61.358/17.306 degrees to Forearm/Upperarm, both below their 90-degree chain limits.
Original runtime neutral-cache/allocation metadata was not captured, so the
probe labels restored twist measurements as relative to model rest. Its first
run had a diagnostic-only Skin constant/native-class name collision; renamed
the constant HandSkin before the successful run.

Design question pending in chat: let the new solved grip own complete Hand
orientation instead of that legacy reorientation, retaining arm reach/elbow,
digit and existing twist-chain limits; or define a separate wrist restriction
and account for it during acquisition. Root recommends the single-owner option.
No joint range, overlap budget or contact requirement has been weakened while
this question remains unanswered.

The independent positional trace isolated a small-angle numerical stall. In
live_grip_wrist_constraint_2026-09-27T15-02-59.json all three arm-joint direction
corrections remain nonzero, but Quaternion(from, to) returns identity. This
matches the near-parallel threshold in official Godot 4.7 quaternion.h.
The existing _rotate_bone_toward_end_target now recovers only that lost small
positive-alignment rotation using the native axis-angle constructor and atan2.
Opposite-direction handling, weights, iteration counts and physical limits are
unchanged. This is a numerical correction in the shared arm operator, independent
of the pending wrist-orientation design choice.

Saved-pose A/B: one existing 24-iteration pass plus the same post-constraints
previously ended 1.044 mm from target; now it ends 0.379 mm away, inside the
existing 0.5 mm tolerance. All bone positions/scales are preserved. Evidence:
live_grip_wrist_constraint_2026-09-27T15-03-56.json (98 diagnostic checks).
Both-side shoulder swing authority and arm reach regression tools passed at
15:04; their timestamped launcher logs are in godot_runs/. This fixes position
precision, not the separately demonstrated wrist orientation error or grip cost.
The local UI lifecycle verifier was rerun after this numerical correction:
verify_live_prepared_grip_2026-09-27T15-04-53.json, 99 checks, zero failures.
The ten-minute full acquisition was not unnecessarily repeated; its earlier
result remains identified separately above.

`realized_grip_assessment.gd` reads a final skeleton capture, not a proposed FK
substitute. Its result covers five digit planes, not complete 3D hand collision
or preserved frozen-wrapper geometry. A realization stamp compares all actual
bone poses and scene frames across the asynchronous query; explicit edit epochs
alone were insufficient. UI wording now distinguishes an applied preview from
unverified contact, failed contact, and unresolved joint verification.

Current incomplete behavior is explicit: failed actual assessment leaves the
applied proposal visible with an unresolved/unverified contact message. It is
not an accepted grip and is not an implemented rollback policy. Application
must still reconcile the solver's full Hand frame with the rig's constraints.
Do not call the local grip production-ready or solve this by increasing passes,
discarding actual-skin checks, or changing limits without design agreement.

## Primary grip ownership correction — 2026-09-27 (verified ownership; contact unresolved)

Current user direction supersedes the arm-target integration and the pending
wrist-orientation question above. Last in the chain is the component that moves:

- Primary acquisition keeps the Hand, wrist, Index–Pinky axis and every upstream
  bone fixed. Only the weapon's transverse seating translation and the fifteen
  digit rotations are applied. Existing macro controls retain their ownership.
- Support joins an already seated primary relationship; only support may approach
  that relationship. Its new solver integration is deferred until primary works.
- Work on one thing at a time. This pass corrects primary application only;
  acquisition performance and support cutover wait. No F/save expansion or push.

The numerical proposal translates the captured hand against a fixed weapon. The
same relative geometry is obtained by leaving the hand fixed and translating the
weapon by the negative of that displacement. Validate its named source frames,
unchanged captured pose, preserved weapon basis and zero axial displacement;
never turn the proposal into an arm or wrist target. Retain the resulting seat
through the existing final weapon-seat seam, without accumulating the offset.

Remove the new arm-target hooks and the unrelated small-angle CCD change made
while pursuing that incorrect integration. Their recorded diagnostic findings
remain historical evidence, not necessary parts of finger closure.

Files for this correction: `runtime/player/grip/hand_grip_pose_binding.gd`,
`runtime/player/grip/preview_grip_acquisition.gd`, `player_humanoid_rig.gd`,
`combat_animation_station_preview_presenter.gd`; focused primary ownership proof
under `tools/grip_plane_proof/` and this record. Prepared geometry, contact rules
and the numerical search remain unchanged. No new design decision is needed.

Verification will reuse a saved full-hand candidate to test fixed non-digit
bones, unchanged bone dimensions, inverse weapon seating, stale-result rejection
and retention without repeating the expensive search. Actual skin observations
must remain separate from application/ownership checks.

Completed this bounded correction:

- `player_humanoid_rig.gd` now adds only claim/release/apply/state for the digit
  writer. Five original arm functions were restored; seven newly introduced
  arm-target/settle helpers and the small-angle CCD addition were removed. The
  binding no longer creates target nodes or redirects arm/wrist targets.
- `preview_grip_acquisition.gd` validates the captured pose stamp, named weapon
  axis and pure translation proposal, applies its inverse to the weapon and
  writes fifteen rotations. Weapon basis and axial station are preserved. The
  retained correction is WeaponRootOrigin-local and the final weapon record
  resolves directly through RL_BoneRoot. No bone dimensions are written.
- The presenter uses this result at the existing final weapon-seat seam and
  refreshes grip guides through the existing reader. Repeated refreshes do not
  accumulate offsets. A changed handle station invalidates the prior seat;
  an unchanged explicit reacquire accumulates only its new residual. Late
  results from changed scene poses are rejected before either pose is written.
- New acquisition ownership is currently primary-only. Existing support drivers
  remain; support integration after asynchronous primary seating is still to do.
  No claim of two-hand completion follows from the lifecycle smoke test.

Fresh evidence:

- `verify_primary_grip_weapon_seating_2026-09-27T15-49-27.json`: **679 checks,
  zero failures**, each side tested separately as primary on an isolated real
  rig. Exact saved input hashes and current selected-state material measurements
  match. The production application adapter preserves every non-digit bone,
  Hand frame, digit dimensions, weapon basis and station. It rejects stale and
  axial proposals without writes, recomposes the seat without accumulation,
  invalidates it on station changes and releases ownership. Search was not run.
- Final-signal skin observation remains a distinct finding: right has Middle
  S1/S3, Thumb S2 and Index S2 contacts but material caps fail; left has palm and
  Pinky S3 contacts and passes caps, below the three-section minimum. All measured
  joint angles remain in their authored ranges. Prepared/live origin differences
  reach 0.097919 mm right and 0.076735 mm left; articulation validation flags
  those differences. This does not by itself prove their cause or explain every
  failed contact. Do not resize bones or loosen overlap limits to hide it.
- `verify_live_prepared_grip_2026-09-27T15-50-38.json`: **99 checks, zero
  failures**, lifecycle-only through the real UI: pending Roll, cancellation,
  reacquire, existing support controls, final capture, pose stamps and release.
  Updated assertions explicitly keep support off the new owner in this stage.
  This is not a rerun of the ten-minute acquisition.
- `git diff --check` passes. Initial parse check caught a unary-minus/Basis
  expression in the new adapter; corrected before the successful runtime tests.
  Official Godot 4.7 Skeleton3D and Transform3D documentation was consulted.

Stop here per the user's one-thing-at-a-time direction. Primary placement
ownership is corrected; complete grip contact and latency are not solved. No
commit, push, fresh anatomy bake or new physical limits were introduced.

## Open-palm investigation — 2026-09-27 (triggers observed; no gameplay fix)

User reports no visible grip after opening, Reset, changing handle %, or weapon
manipulation, including after saving a fresh valid Forge V2 weapon. This pass
investigates that report only; no runtime code, contact limits or numerical
solver behavior changed. Work remains sequential per the user's direction.

Added `THE_WILL_GRIP_TRIGGER_PROBE_ONLY=1` to the existing
`tools/grip_plane_proof/verify_live_prepared_grip.gd`. It exercises actual UI
actions against the existing isolated Star_Handle_Testing save and records a
three-second observation window after each action. No replacement worker,
injected candidate, real player-save access, or full acquisition was used.
The user's refreshed weapon was not imported into this isolated test.

Evidence: `test_artifacts/verify_live_prepared_grip_2026-09-27T16-22-04.json`,
launcher log `godot_runs/the_will_2026-09-27_16-21-25.log`. The harness completed
without script errors. Its successful run means the diagnostic completed, not
that a grip passed. The game run was closed before this isolated Godot run.

Observed sequence:

- Opening: request 1 reaches `solving`; processing is enabled, tree unpaused.
- Reset with unchanged station: still request 1, continuing the original job.
  At roughly six seconds its progress reaches `outside_start`, 36 evaluations.
- Handle % change: request 2 queues and reaches `solving`.
- Roll: request 3 is `cancelled`, with no acquired pose.
- Reset which changes the handle station: request 4 starts a fresh solve.
- Roll followed by Reset at the same station: request 5 stays `cancelled`.
- Reacquire: request 6 queues and reaches `solving`.

Every observation reports `owned=true`, `has_grip_pose=false`, binding state
`planar_grip_pending`. The code explains why: `claim_planar_grip_pose` stores and
reapplies the fifteen current digit rotations immediately, suppressing the old
closure route. `apply_primary_result` is called only after the entire numerical
acquisition returns; no intermediate closure is displayed. Cancellation or a
rejected result retains that ownership. Reset currently does not explicitly
force a new request; an unchanged relationship key preserves the old status.
Therefore an open hand can be waiting on the expensive job or remain open after
cancellation. This is not evidence that the trigger never fired.

Limit of this finding: the user's exact on-screen status was not captured, and
the corrected primary adapter still has no freshly completed full-search proof.
The earlier 620.304-second acquisition remains historical timing, not a new
measurement. Resaving Forge does not correct the demonstrated owner/lifecycle
behavior. Do not claim waiting guarantees a valid grip, restore simultaneous
legacy/new writers, or hide the issue with an unverified intermediate pose.
Discuss the next bounded correction before broadening into solver performance.

Official Godot 4.7 [Node](https://docs.godotengine.org/en/4.7/classes/class_node.html)
and [Thread](https://docs.godotengine.org/en/4.7/classes/class_thread.html)
documentation was checked before extending the diagnostic.

## Inward guide target — 2026-09-27 (Step 1 comparison; awaiting visual review)

The user let the expensive live acquisition finish and reports that the grip
looks good. Tip manipulation then visibly detaches the grip. Preserve both
observations; neither certifies the numerical contact gates, and the Tip issue
is separate from this bounded target-depth change.

The user explicitly orders the next work:

1. Move the guide's target 1.5 mm inward, retain existing hand/joint/overlap
   limits, and produce an HTML hand comparison.
2. Only after visual approval, prepare chronological instrumentation covering
   Skill Crafter opening, weapon double-click, Skill 1 double-click, the entire
   acquisition and afterward. Include elapsed time, events, states, repeated
   calls, cycle counts and outcomes.
3. Run that instrumentation and analyze its output.

No optimization or tracing implementation is authorized by completing Step 1
alone. No Tip fix, support expansion, F/save work or Git action in this pass.
The user has closed the game; the editor remains open.

Clarification resolved by the user's correction: **offset the envelope only**.
The user explicitly says each finger section stays as it is. Keep its existing
desired depths, contact checks and overlap tolerances; do not replace these with
a uniform 1.5 mm section target. The envelope's attraction boundary is 1.5 mm
inward; the existing material limits retain stopping authority. The user then
authorized continuing after briefly interrupting to write that clarification.

Common preparation completed without choosing that policy:

- `runtime/player/grip/planar_grip_guide_progression.gd` has an optional inward
  contact-target operation. Default offset is zero, retaining existing behavior.
  It preserves the named metric plane and supplied slice center, retains original
  guide evidence separately, offsets only the attraction geometry, and rejects
  a collapsed or split target rather than picking an arbitrary island. Actual
  weapon geometry and per-section physical caps are untouched.
- The existing guide verifier passes **1638 assertions, zero failures**:
  `test_artifacts/verify_planar_grip_guide_progression_2026-09-27T17-20-57.json`.
  Coverage includes analytic circles, a known square inset, measured sections,
  cache isolation, named centers and failed/split erosions. This is geometry
  evidence, not a new grip solve.
- `tools/grip_plane_proof/run_inward_guide_grip_comparison.gd` is prepared to
  reacquire the right-hand five-digit frozen baseline with the live character
  configuration, reusing the canonical solver. It requires the explicit 1.5 mm
  setting and isolated workspace user data. Initial Godot check-only passed;
  `godot_runs/the_will_2026-09-27_17-29-02.log`.
- `test_artifacts/render_handle_grip_process.py` can display retained original
  guide evidence beside the actual queried inset. The new
  `test_artifacts/render_inward_guide_comparison.py` reuses its panel rendering
  for baseline/current views at a common scale per digit. It checks identical
  capture/anatomy, unchanged section caps and the saved 1.5 mm offset. Both
  Python files parsed before acquisition; the completed comparison is recorded
  below.

Integration now connects the optional offset at the material-contact phase in
`handle_grip_acquisition.gd`, validates its scalar in the job and character data
loader, and sets `guide_inward_target_offset_m = 0.0015` in Josie's existing
`grip_contact_config.tres`. Preparation circles are unchanged. Neither residual
function, native contact request, section settings, material query nor overlap
acceptance rules were edited.

`verify_inward_guide_acquisition_2026-09-27T19-26-07.json` passes **915 checks**:
the same frozen hand state has identical skin/material geometry, named centers,
actual-material contacts and overlap measurements, section target values and
caps, with and without the offset. It also checks material-phase activation and
unchanged inset geometry during reseating. An initial verifier run used exact
binary equality against decimal JSON and failed on a 5.421e-20 m round-trip
difference; the history comparison now permits 1e-15 m and reports the maximum
error. Live before/after comparisons remain exact; no physical tolerance changed.

The fresh five-digit right-hand solve ran via the supported launcher in
`godot_runs/the_will_2026-09-27_19-26-24.log`. It uses the exact saved baseline
input and current live contact configuration. The read-only Step-1 code review
found no introduced integration defect.

Completed evidence:

- `test_artifacts/inward_guide_grip_comparison_2026-09-27T19-32-53.json`:
  383.116 seconds of acquisition, 2488 evaluations, diagnostic minimum accepted,
  all material/guide overlap checks passing. Reseat 1 improved the retained
  objective while preserving contacts; reseat 2 found no legal improvement and
  stopped. Frozen guide identities match before/after both attempts.
- The envelope offset changes where the **existing stop rule** triggers:
  new result stops at hull-transition amount 0.75 with `middle/S1`, `middle/S3`
  and `thumb/S2` in actual material contact. The unchanged source baseline
  stopped at amount 1.0 and ended with six contacts. In particular, new Thumb S3
  has a 1.986 mm material gap; index/ring/pinky have no accepted actual-material
  section contacts. Do not call this a fully seated hand or blanket improvement.
- The middle finger's S1 depth upper bound is 0.486 mm against its unchanged
  0.500 mm cap; S3 is 0.180 mm against 0.380 mm. Thumb S2 is 0.195 mm against
  1.080 mm. The deeper target did not grant any section a larger overlap budget.
- `test_artifacts/inward_guide_comparison_2026-09-27.html` contains before/after
  views for all five digits, at common scale per digit, with color legend,
  original guide outline, inward queried guide, actual material, skin and section
  measurements. It validates identical frozen capture/anatomy, unchanged
  section caps and desired depths, named frames and saved inset provenance.
  The companion PNG shows Middle and Thumb; it was visually inspected.

Runtime integration is local and enabled in the current character configuration.
This test uses prepared numerical skin; it does not certify captured live 3D
skin or fix the separately observed Tip detachment. No extra acquisition search,
optimization, stop-rule change, section retuning or step-2 tracer was added.
Wait for the user's visual review before advancing to their next stage.

Official Godot 4.7
[Geometry2D.offset_polygon](https://docs.godotengine.org/en/4.7/classes/class_geometry2d.html#class-geometry2d-method-offset-polygon)
was researched before the geometry edit. Negative offset can return multiple
polygons or none. The existing metric recenter/scale procedure is reused; no
new world origin or offset-only recentering is introduced.

## Identified palm target — 2026-09-27 (requested follow-up test)

After the envelope comparison, the user requests a 3 mm target for non-finger
regions. Clarification explicitly selects **the identified palm**, retaining
its existing 2.5 mm maximum overlap and leaving orange other/unclassified skin
unchanged. This is a target-depth experiment, not permission to increase caps or
change the three-section stopping rule.

Implementation: `palm_guide_target_depth_m = 0.003` in the current character
contact config. The canonical acquisition uses that value only for the existing
`palm` region after material assessment begins. A shared desired-clearance
function retains the previous `min(target, cap)` behavior for digits, while the
palm aims 3 mm inside its guide and leaves stopping to the unchanged guide and
actual-material cap checks. The 1.5 mm envelope inset remains in place. No palm
partition expansion, wrist/body ownership change or second grip solver.

Saved geometry now exposes response target clearance, point and named plane
origin separately from the nearest surface witness. The HTML can display the
palm's desired target as a gold diamond; that marker is not an achieved-contact
claim. Existing surface-witness markers continue to describe measured nearest
points rather than desired penetration.

Bounded evidence: `verify_inward_guide_acquisition_2026-09-27T19-44-35.json`,
**1354 checks, no failures**. With pose held identical, only the intended palm
response changes: digit native requests, actual material measurements, caps and
envelope geometry remain the same. The test confirms the palm's desired 3 mm
is not silently clamped to its 2.5 mm cap. Read-only review found no introduced
functional/scope defect. Official Godot 4.7
[Geometry2D closest-segment documentation](https://docs.godotengine.org/en/4.7/classes/class_geometry2d.html#class-geometry2d-method-get-closest-point-to-segment)
was checked before this edit; a nearest surface witness and a deeper attraction
target remain distinct quantities.

The same comparison runner now accepts an explicitly named workspace baseline
and expected SHA256. This experiment compares against the just-completed inset
run `inward_guide_grip_comparison_2026-09-27T19-32-53.json` (SHA256
`897fdf779003e45e127c9b035c59e25feb643df73c78a5b23b604edd650c9846`), so the
only intended behavior change is the palm target.

Full-run evidence: `inward_guide_grip_comparison_2026-09-27T20-06-32.json`,
launcher log `godot_runs/the_will_2026-09-27_19-45-02.log`. Acquisition took
**1277.664 seconds (~21 min 18 s)**, with 3243 evaluations, 238 native processes
and 30 sampled reseat path checks. These are recorded diagnostic totals, not a
controlled performance comparison or the requested future UI timeline.

The guide completed the full wrapper-curvature progression with only `pinky/S2`
in actual-material contact. Reseating mattered: attempt 1 acquired five contacts,
attempt 2 improved placement without changing the count, and attempt 3 found no
legal improvement. The final diagnostic minimum is accepted and guide/material
checks pass, with final contacts `middle/S3`, `thumb/S2`, `thumb/S3`, `index/S2`,
`pinky/S2`. Frozen guide IDs remain identical across all three reseats. The prior
1.5 mm-inset / zero-palm-target run had three contacts. Do not confuse the
pre-reseat one-contact intermediate state with this final five-contact result.

Actual palm gaps improve but remain positive:

| Digit plane | Previous gap | 3 mm palm-target gap |
| --- | ---: | ---: |
| Middle | 3.310 mm | 1.533 mm |
| Ring | 5.172 mm | 2.541 mm |
| Pinky | 7.563 mm | 4.854 mm |

Thumb and index have no assigned palm witness in this capture. Palm has not
achieved actual-material contact, and a desired 3 mm target is not evidence of
3 mm penetration. Caps are unchanged, including the existing 0.002 mm numerical
guard used by acceptance checks. Some individual digit sections still have gaps;
the test does not prove every section is seated or certify live 3D skin.

`test_artifacts/palm_target_3mm_comparison_2026-09-27.html` provides all five
before/after views, explicit targets, palm gaps, unchanged caps, numeric guard,
recorded timings and stopping/reseating results. The companion PNG was visually
inspected. The local character configuration retains the tested 3 mm palm target.
No optimization or contact/stop-rule retuning was performed. Step-2 chronological
instrumentation remains gated on the user's visual approval.

### 2026-09-27 — accepted contact appearance; retain the solved grip during motion

The user accepted the 1.5 mm envelope / 3 mm identified-palm target result as
good enough. Their next priority is preventing weapon manipulation from
separating the held weapon from the solved hand. Check/fix that before the
chronological UI timing investigation and optimization. Handle-station changes
still require a new seat; ordinary Tip/Pommel/Roll movement should retain it.

Initial source findings (not yet a movement-test result):

- `hand_grip_pose_binding.gd` retains fifteen local digit rotations and records
  `hand_in_weapon`, but currently treats the latter as provenance only.
- `preview_grip_acquisition.recompose_primary_seat()` reapplies only a
  WeaponRoot-local translation after the macro control solve; it does not
  enforce the complete solved Hand/weapon relationship.
- Existing arm/wrist control code still derives its target from older contact
  anchors and anatomical alignment, independently of that recorded binding.
  Owned fingers bypass the old closure solver; finger CCDIK is disabled.
- The old saved-candidate seating verifier tests a stationary macro rebuild,
  not moved Tip/Pommel controls. The live verifier covers one Roll operation.

Prepare a bounded real-control replay of the saved selected result in
`tools/grip_plane_proof/verify_prepared_grip_motion.gd`, without repeating the
long acquisition. Source: `inward_guide_grip_comparison_2026-09-27T20-06-32.json`,
SHA256 `e85190a6f4620564c74c9bcf174cf1a961e56a113d915bc856f8a54b37e047c9`.
Report relative translation, basis and digit changes, control responses and
request serials explicitly. Use isolated workspace userdata.

One material authority choice was asked before implementation: when requested
endpoints exceed arm/wrist limits, preserve the rigid grip and limit movement,
or preserve requested endpoints and expose broken contact. Do not silently
choose a new unreachable-movement policy. Initial acquisition must continue to
move only the weapon and fingers, never the upstream arm/body chain.

Official Godot 4.7 [Transform3D](https://docs.godotengine.org/en/4.7/classes/class_transform3d.html)
and [Skeleton3D](https://docs.godotengine.org/en/4.7/classes/class_skeleton3d.html)
documentation checked: use full affine relative transforms, retain scale, and
compose skeleton-relative bone poses with the scene frame only at presentation.
Existing named Wrist -> RL_BoneRoot capture remains the coordinate authority.

Movement replay executed through the supported Godot 4.7 launcher with isolated
workspace userdata. Latest evidence:
`test_artifacts/verify_prepared_grip_motion_2026-09-27T22-33-36.json`
and `godot_runs/the_will_2026-09-27_22-33-12.log`.
**349 checks, 18 failures**, approximately 19.05 seconds for the diagnostic;
no acquisition search. This is a failing baseline, not a completed fix.

- The fixture reconstructs the approved saved right-hand candidate, checks the
  actual UI mesh in WeaponRoot coordinates (largest vertex discrepancy
  0.000325 mm), restores the captured rig pose and uses production primary
  application. Its named station corresponds to normalized Handle coordinate
  0.2. Application preserves all non-digit bones and the solved relative frame.
- During the subsequent ordinary preview rebuild the relative frame changes:
  45.781 mm / 7.122 degrees synchronously, 69.459 mm / 23.150 degrees after two
  frames. These are deviations from this deliberately restored fixture, not a
  measurement of an untouched user's running game.
- Tip/Pommel setters then continue to change that relationship. All fifteen
  digit rotations remain unchanged, request serial remains 1, and no request is
  queued throughout this corrected replay. This isolates movement retention
  from finger closure and acquisition triggering.
- The sequence is cumulative. Roll preserves the already-separated relation
  to numerical precision and its fixed wrist/Tip checks pass; errors measured
  against the original fixture must not be attributed to Roll itself. The
  second Pommel request returns false, accounting for two additional action
  assertions. Sixteen failures are the two observations of the relative frame
  after each of eight actions. Whole-hand skinned-surface rigidity, support
  integration and fresh acquisition are not certified by this test.

Earlier setup evidence is deliberately retained: `22-30-33` stopped because
the diagnostic guessed station 0.55; `22-32-00` mixed the immediate approximate
station setter with its subsequently refreshed UI station and invalidated the
exact relationship key. The current diagnostic derives the station from the
captured span, lets the normal UI refresh settle its representation, verifies
the resulting station and mesh, and does not overwrite their live metadata.
Do not use those two earlier reports as production movement evidence.

At the end of that investigation, production movement code was unchanged. The next implementation
must consume the complete recorded Hand/WeaponRoot relationship in the existing
movement authority rather than independently inferring it from old grip
anchors. It must preserve acquisition ownership, station-change invalidation,
finger rotations and accepted Roll behavior. The unreachable-movement choice
above was still awaiting the user's answer. Chronological optimization tracing
has not started; the connection fix remains first.

### 2026-09-27 — fixed relative grip during manipulation; limit policy accepted

The user approved stopping Tip/Pommel movement at arm or wrist limits while
preserving the grip, for now. This resolves the policy question above. The
following local implementation concerns movement after primary acquisition;
it does not give the acquisition solver authority over the arm/body chain.

- `hand_grip_pose_binding.gd` now exposes the complete acquired
  `hand_in_weapon` transform with its explicit `WeaponRootOrigin`. The same
  weapon identity, relationship key and acquired-state checks remain required.
- The existing arm target path in `player_humanoid_rig.gd` and
  `two_hand_pose_solver.gd` consumes that frame. The saved Hand orientation
  replaces the old anatomy-derived orientation/straightness preference for a
  bound grip. Existing reach/body constraints, limb twist distribution and
  wrist twist clamp still apply. No second arm solver was added.
- `preview_grip_acquisition.gd` retains the final weapon as
  `actual Hand * inverse(acquired Hand-in-WeaponRoot)`. The actual Hand is read
  through the existing named Wrist -> RL_BoneRoot capture. This replaces the
  translation-only correction. The same writer runs after Godot's final
  `skeleton_updated` signal so deferred modifiers cannot detach the weapon.
  It neither writes bones nor advances IK. Clear disconnects that signal.
- The preview presenter publishes actual retained Tip/Pommel endpoints and
  bypasses the legacy dominant handle-station projection for an acquired
  binding. A reach correction must not silently change the selected handle
  percentage. Movement-authority metrics identify retained grip authority.
- Station/geometry changes invalidate the relationship and request a new
  acquisition. Ordinary movement reuses all fifteen solved digit rotations.
  Existing Roll remains responsible for its wrist–Tip motion; this retention
  layer preserves that result. Release still restores the open-hand path.

Evidence uses isolated workspace userdata and the supported Godot 4.7 launcher.
No full acquisition search was repeated:

- `verify_prepared_grip_motion_2026-09-27T22-59-14.json`: **397 checks, no
  failures**, using the approved saved right-hand result and real UI control
  setters. Tip/Pommel/Roll/refresh keep relative position within 0.0002 mm and
  orientation within approximately 0.00000033 radians of the acquired frame.
  Finger rotations and the acquisition request remain unchanged. A 5.657 m
  Pommel request is rejected before movement and leaves the grip intact; this
  is not proof of every possible accepted movement at an exact joint limit.
  Changing handle station clears the acquired binding and queues a new solve;
  the diagnostic does not execute that expensive solve.
- `verify_primary_grip_weapon_seating_2026-09-27T22-59-59.json`: **679 checks,
  no failures** with frozen right/left real-rig proposals. Acquisition retains
  all non-digit bones, preserves dimensions and the transverse-only weapon
  seat, rejects stale/axial-invalid proposals, and retains Roll/release behavior.
- Read-only review found no recursive skeleton update: the final callback reads
  the named Hand and writes the weapon; its listener updates weapon-child
  anchors and metadata only. The macro pass completes its contact passes
  before advancing modifiers. Review also identified the old diagnostic
  authority labels, which were corrected in the presenter.

These tests establish frame/digit retention and acquisition ownership. They do
not certify whole-hand 3D skin contact, new support-hand integration, or
F/save/playback parity. The existing long acquisition cost remains; no
optimization has been implemented. The next task remains the requested
chronological UI/acquisition trace, followed by measured optimization. No
commit or push was requested or performed.

Follow-through review found that retention alone was insufficient to judge
control response. The initial verifier added offsets to stale authored fixture
coordinates: its first nominal 5.385 mm Tip edit actually requested 363.105 mm
from the visible Tip. The diagnostic now uses the real displayed baseline and
records physical travel separately from relative grip error; movement must
exceed 0.1 mm or 0.01 degrees to count as an actual movement.

The corrected replay also exposed missing consumers of the full saved frame:
open-mount returned pre-seat endpoint coordinates, selection-only refresh could
overwrite retained coordinates, legality/shoulder-volume checks used an old
anchor or axis station, and the next endpoint edit reused the old authored
orientation even after wrist limits changed the realized orientation. These are
being brought onto the same acquired relationship without changing the limit
values. The inverse frame encoding is extracted from the existing Roll path
into `combat_animation_weapon_frame_solver.gd` and reused by Roll and bound
display/edit baselines; there is no additional numerical pose solver. Final
follow-through evidence must be recorded below; the earlier passing counts
above must not be presented as proof of small-control response fidelity.

Follow-through implementation and evidence:

- Open-mount now returns final retained endpoints. Selection-only refresh uses
  retained display coordinates for the same selected node. UI endpoint-edit
  baselines encode the actual held transform, including its orientation, and
  carry that orientation when committing the edit. The same existing verified
  inverse conversion is used by Roll, without changing its captured-return
  behavior or named-origin registration.
- Legality and shoulder-volume projection now use the saved Hand point. The
  volume projection translates both requested endpoints by the same correction
  and retains the existing shell/radii. It does not substitute a new reach rule.
- `verify_prepared_grip_motion_2026-09-27T23-13-46.json`: **407 checks, no
  failures**, including actual displayed-frame reconstruction and physical
  movement thresholds. Maximum measured relative grip displacement is about
  **0.000201 mm**; digit rotations remain unchanged and no acquisition runs.
  The distant 5.657 m Pommel request is now limited to 0.852 m travel, remaining
  5.044 m short of the request while retaining the grip. Unlike the earlier
  report, this exercises an accepted limited movement, not an outright refusal.
- `godot_runs/the_will_2026-09-27_23-14-58.log`: existing Roll regression,
  **204 checks, no failures**, both hands. Wrist and non-Hand bones stay fixed,
  Tip stays within floating-point error, and return-to-start behavior survives
  the encoder extraction. No full new grip search was run.

**Unresolved control-response observation:** grip retention is successful but
does not establish acceptable endpoint response. From the actual visible
baseline, a 5.385 mm Tip request moves the Tip 97.382 mm in this frozen-fixture
test; another 4.583 mm Pommel request produces 43.963 mm actual Pommel travel.
The existing arm/wrist solve under the bound target produces a limited pose,
and retaining the grip carries that adjustment into the weapon. Do not label
this as a proven pre-existing defect or a completed movement-feel fix. The
fixture's first ordinary refresh also resets its historical body pose; that
initial transition is not an untouched live-user baseline.

The user has been asked to distinguish two meanings of stop-at-limit: reject
the whole edit and retain the previous complete pose, or permit the limited
arm/wrist pose for now. The latter is the currently tested implementation.
No transactional pose rollback or broader IK retuning has been implemented.
Chronological performance tracing and optimization remain pending this
movement-policy clarification; no optimization result is claimed.

Final display-packet review fixed a related Roll pairing: editing playback
state often omitted Roll, causing full-frame encoding to assume zero while a
display clone retained nonzero Roll. Authored/open-mount results now provide
the current Roll (preserving a supplied playback value), and display-chain
construction copies encoded orientation and Roll together. The shared encoder
retains the original segment solver's collinear-up fallback.
`verify_prepared_grip_motion_2026-09-27T23-17-41.json` passes **428 checks**, now
including display-packet reconstruction at every synchronous/settled sample.
The larger limited-movement observation above remains unresolved. Final parser
check `godot_runs/the_will_2026-09-27_23-18-18.log` passes; whitespace check passes.

## 2026-09-28: chronological grip instrumentation; fixes deferred

The user reported an open hand after about 1,050 seconds, with the displayed
solve counter then unchanged for at least 60 seconds. They explicitly moved
the next task to the requested chronological timing tool, deferring grip fixes
and optimization. The earlier movement-policy question is not a blocker for
this observation-only work. No acceptance rule, IK limit, contact target,
search budget, or pose ownership is changed by this instrumentation.

Implemented an opt-in recorder at
`runtime/player/grip/grip_chronology.gd`, enabled only by
`THE_WILL_GRIP_TRACE_PATH`. It writes workspace-only JSONL with initial UTC time,
monotonic timestamps, paired operation spans, main/worker identification,
request and job identities, progress, cycle outcomes and work counters. Span
boundaries flush immediately; recording overhead is measured. Job identities
are strings because their 64-bit integers lose precision in JSON/HTML readers.
No geometry trace is enabled. High-frequency sample wrappers bypass diagnostic
payload construction when recording is disabled.

Instrumentation lives in the existing acquisition, preview owner and native
digit IK files. It observes preparation/dispatch, native proposals, response
iterations and probes, line-search decisions, reseating, candidate construction,
weapon sections, guide generation, skin slicing, palm annotation, circle and
polygon contacts, pose application and realized assessment. It does not add a
second grip implementation.

New tool files and instructions:

- `tools/grip_plane_proof/trace_skill_crafter_grip.gd`: instantiates the real
  station UI with the existing isolated workspace library, invokes the actual
  weapon activation and Skill 1 handlers, then observes natural acquisition.
  No completed pose is injected. Skill selection uses its real Button handler;
  this is handler replay, not physical mouse input or full game startup.
- The runner captures one-second state/frame/worker heartbeats, existing UI
  latency snapshots, repeated requests, stable terminal states, and five seconds
  afterward. If work resumes, terminal observation restarts. Default timeout is
  1,800 seconds, configurable; timeout is recorded as timeout and followed by
  cancellation and safe worker joining. Main-thread stalls can delay the timeout.
  The library is not saved and its hash is checked afterward.
- `tools/grip_plane_proof/summarize_grip_chronology.gd`: offline HTML/JSON report
  with stage counts, min/average/max/P95 times, outcomes, work totals, chronological
  filtering and unfinished spans. Inclusive durations overlap; do not sum all
  stages as elapsed time. Recorder closure and preview application are not grip
  success certificates.
- `tools/grip_plane_proof/GRIP_CHRONOLOGY.md`: exact supported-launcher commands,
  environment variables, isolation requirements and interpretation limits.

Verification so far:

- Initial natural-UI smoke capture
  `test_artifacts/grip_chronology_smoke_2026-09-28_0019.jsonl`: 35-second configured
  timeout, 9,053 records, zero parsing/pairing issues, zero unfinished spans after
  clean cancellation, unchanged library. It records 203 sample calls, 914 skin
  slices, eight response iterations and 12 native proposals, but does not reach
  material-phase closure or establish full solve duration. This initial capture
  predates the job-ID string and UI timing snapshot refinements.
- That partial run measured weapon activation at 9,105.534 ms and Skill 1
  selection at 5,783.195 ms. Recording writes/flushes accumulated 402.250 ms over
  35,099.185 ms observed time; this excludes other instrumentation overhead and
  is not a whole-solve estimate.
- Existing actual-hand material assessment verifier passes with tracing both
  enabled and disabled. The complete 1,280,980-character output is identical
  after replacing only `assessment_ms`; evidence is
  `test_artifacts/grip_chronology_observer_equivalence_2026-09-28.json` and its two
  referenced assessment reports. This verifies one captured material query,
  not a new successful acquisition or visual grip.
- An intentionally truncated 100-record capture plus an incomplete JSON line
  produces one parse issue and five unfinished spans, correctly marked partial:
  `test_artifacts/grip_chronology_partial_verification_2026-09-28.summary.json`.
- Final runner/report verification:
  `test_artifacts/grip_chronology_verified_2026-09-28_0022.html` (and adjacent
  JSONL/summary), 35-second configured timeout, 10,638 records, zero parse/pair
  issues, zero unfinished spans, unchanged library. It includes exact string
  job IDs and the existing UI latency snapshots. There are 241 sample calls
  (25 cache hits), ten response iterations and 12 native proposals. Recorder
  write/flush time is 437.638 ms over 35,083.633 ms observed. Weapon activation
  takes 8,470.845 ms, including 7,520.812 ms in the existing geometry-seeding
  timer; Skill 1 activation takes 5,571.943 ms. These are bounded headless
  observations, not a full-grip or interactive-rendering benchmark. The input
  is the pre-existing isolated `Star_Handle_Testing` library (SHA and file
  modification timestamp are recorded), not a newly copied user save. Launcher
  log `godot_runs/the_will_2026-09-28_00-21-46.log` has no script error; the
  expected timeout exit is code 2. After cleanup only the user's editor remains.
  All seven instrumentation/tool files pass whitespace checks.

Read-only finding to investigate from a complete natural trace: after solving,
the preview owner can reject a no-longer-current request and clear busy/job
state without replacing the displayed `solving` status. Exact station-key drift
is one possible route. This is a source-supported candidate for the reported
frozen counter, not a confirmed diagnosis of that user's run. The short smoke
also records a stale discard after explicit timeout cancellation; that is
expected cleanup evidence and must not be presented as reproducing the fault.
No stale-status fix is included.

The user then requested the full run explicitly; the 35-second tool check was
not the requested full-duration measurement. Completed capture:
`test_artifacts/grip_chronology_full_2026-09-28_0026.jsonl`, adjacent HTML and
summary JSON. The filename suffix is only a label: the actual launcher start
was local 2026-09-28 00:52:20, log
`godot_runs/the_will_2026-09-28_00-52-20.log`; trace UTC/monotonic timestamps are
authoritative. Observation timeout was set to 3,600 seconds to allow natural
completion. It was not reached. No solver code was edited for this run.

Full-run result:

- Natural completion at **335.736 seconds (5 min 35.736 sec)** including setup,
  terminal confirmation, five seconds after confirmation, and cleanup.
- Numerical acquisition: **313.092919 seconds**; actual skin assessment:
  **2.201858 seconds**; pose application: **1.001 ms**. The preview owner finished
  application/assessment at trace time **328.668514 seconds**.
- Weapon activation: **7.626106 seconds**; Skill 1 activation:
  **5.033041 seconds**. Existing opening timing identifies **6.758511 seconds**
  of geometry seeding within weapon activation.
- Acquisition reports **2,320 evaluations**, **147 native processes** and
  **13 reseat path checks**. Across the captured acquisition plus final assessment,
  there are **2,897 sample calls**, **135 response iterations**, **13 response
  cycles**, **4,240 polygon contact measurements**, and **11,605 skin slices**.
  There are two reseats: first improves cost while retaining the same three
  material-contact sections; second finds no legal improvement and stops.
- Largest recorded component totals: polygon contact measurement **124.412085
  seconds**, skin slicing **65.911065 seconds**, palm annotation **52.703233
  seconds**. These are measured named component totals; do not add them to their
  enclosing sample/worker/response totals.
- The proposal is applied and terminal state is `preview_applied`. Actual
  material query is valid and safe, contact condition is met, and assessment
  is current. **Actual articulation validation is false**: displayed status is
  `Right grip: contact found; joint verification is unresolved.` This is not
  complete grip acceptance or visual certification.
- **119,631 records**, zero parsing/pairing issues, zero unclosed spans,
  unchanged library, normal exit code 0. Recorder write/flush work totals
  **4.255905 seconds**, excluding other instrumentation overhead.
- Exactly one request/acquisition; all 319 heartbeats retain its serial and
  relationship key. No stale discard, owner failure, cancellation, restart or
  timeout occurs. Cleanup begins after terminal observation finishes, so this
  complete trace does not reproduce the earlier frozen-status mechanism.
- This is a headless run with the existing isolated workspace Star_Handle_Testing
  library. It does not reproduce the user's 10–14 minute expectation or earlier
  frozen 1,050-second status. The difference has not been attributed to a cause;
  it is not evidence of an optimization. A comparison against the user's actual
  interactive inputs/environment remains separate work.

Next at the end of the instrumentation pass was to inspect the complete chronology
and choose measured optimization. The later user agreement below now specifies
the next direction; this paragraph preserves the instrumentation handoff history.
Existing production already uses
the exact depth cache; promoting it again is not a new optimization. Potential
polygon-intersection and repeated-validation costs remain investigation leads,
not changes authorized or implemented during this instrumentation step.
No commit, push, external application or installation was performed.

## 2026-09-28: agreed Forge preparation and contact-driven IK replacement

**Status: W1/W2 implemented and verified; W3 isolated implementation is in
progress with unresolved tangency and cap slices. W4/W5 remain pending.**
The user asked to preserve the complete sequence and its clarifications before
changing code. This section is the current implementation guide when older
entries disagree. Keep those entries as experiment history, not competing rules.

Desired result: prepare reusable weapon geometry at Forge save, then let a
contracting guide drive constrained finger IK through sliding skin contact.
After seating, keep that contact response active so manipulation and handle-percent
changes preserve the grip without restarting the present long numerical search.
Keep functionality, geometry accuracy and movement ownership while reducing cost.

### W1 — Prepare and save the weapon-side wrapper

- Integrate preparation of the maximum-shrunken permitted handle wrapper into
  Forge V2 Save / Save As. Store the prepared result with the saved weapon so
  Skill Crafter consumes reusable geometry rather than rebuilding the same
  weapon-side result during every acquisition.
- This wrapper is a contact target around the actual handle. Preserve the actual
  handle geometry separately as the authority for material contact and overlap.
  Each digit still uses its own motion plane, including diagonal thumb sections.
- The saved representation must support the selected handle percentage, changing
  slice planes, normal/reverse grip and both hands. A single perpendicular 2D
  outline is not sufficient for all these consumers.
- Implementation dependency: today's envelope builder is per-plane and depends
  on character-derived inward-curvature data. Trace how to persist reusable
  weapon geometry and identify the curvature/configuration it was prepared for;
  do not silently make one character's wrapper universal or assume arbitrary
  oblique slices of a baked surface satisfy the same 2D curvature rule.
  Resolve that representation before claiming the requested precomputation works.
- Reuse the existing save transaction. Character anatomy and its prepared contact
  measurements remain character-owned. This step does not add character creation.

### W2 — Show progress for that save transaction

- The indicator is hidden when idle. Save or Save As reveals numeric progress
  from **0 to 99** across preparation and persistence.
- Only after all required processing and the save have succeeded does the number
  change from **99** to **Saved**. Then the indicator fades away.
- Report actual transaction progress; do not show successful completion merely
  because wrapper preparation finished while persistence is still pending.
  A failed preparation or write must not reach the Saved state.
- Use the shared Save / Save As path and its existing success/failure handling;
  do not introduce another save writer. Fade duration is a later UI detail.

### W3 — Fit the large guide and contract through preparation

1. Establish the existing weapon orientation and parallel relationship to the
   index-pinky axis. Use the prepared character anatomy and the established
   named coordinate chain. Fit the hand to the current large guide circles.
2. Keep every guide center coincident with its corresponding handle-slice center.
   These are per-digit circles in their own planes, not a replacement cylinder.
   A seating translation moves the weapon/slice center and its guide together.
3. The current initial radius is approximately **117.111 mm**. This stage prepares
   the hand; do not gate it on actual weapon-contact acceptance. The user's
   expectation is that the large guide keeps the hand away from the handle.
   That expectation is not a universal geometric proof for every possible slice.
4. Contract toward a **50.00 mm radius preparation waypoint**, with digit skin
   following sliding tangent targets. Prioritize finger S1/S2/S3; thumb primarily
   S2/S3 with its existing special S1 policy. Palm seating comes later.
5. Keep 50 mm in the first implementation/test to guide the transition and expose
   pinching or poorly timed positioning. **It is optional, not a required solved
   pose:** if the handle or prepared wrapper is encountered before reaching it,
   skip that waypoint and transition to shape-following. Do not force a circle
   through the target, enlarge the waypoint, or declare grip failure to reach 50.

The guide drives closure. Targets may slide on the guide and within the permitted
skin regions; they are not permanently paired surface vertices. Joints respond
within the existing motion planes and ranges. "Unlocked/free to move" means free
inside those limits, not disabling limits or permitting mesh distortion.
Use a few preparation targets rather than an exhaustive series of angle trials.
Numerical progress may be monitored, but preparation gaps are not final grip
failure and must not cause the earlier premature stopping behavior.

### W4 — Follow the saved wrapper, assess contact, then reseat

1. From the preparation stage, bring the circle to the target's enclosing/contact
   stage, then toward the prepared maximum-shrunken wrapper. Keep contact targets
   active across these transitions; do not release them and restart closure.
   The requested coarse stages are target changes, not permission to teleport
   the hand through geometry or ignore limits between their endpoints.
2. The prepared wrapper supplies the guide; the actual handle supplies the
   material-contact/overlap checks. Keep the approved inward guide target and
   individual skin overlap limits described below. Reaching the first circle
   contact with the handle is not itself successful hand contact.
3. Once at the material phase, assess distinct actual-contact sections. Stop
   further contraction when sufficient legal contact exists, or when the
   existing inward-curvature, joint-motion or section-overlap limits prevent
   further contraction. A missed preparation contact does not terminate this
   sequence. If a limit is reached before the contact minimum, still attempt
   reseating and assess the final result afterward.
4. Freeze the stopped wrapper's shape and size for reseating. Allow the weapon
   to translate along **two axes in the slice plane**, toward improved finger
   and palm seating. This is transverse translation: **no weapon rotation and
   no change to the selected percentage along the handle**. Preserve the
   established direction and index-pinky parallelism.
5. Finger IK continues following during that translation. Preserve acquired
   contacts, allow sliding and legal joint opening/closing, and attract missing
   sections. Never improve the fit by exceeding a section's overlap cap or
   dropping an acquired contact. Allow **at most three reseating attempts**,
   stopping earlier when no legal improvement is found; then assess the result.

The two translation coordinates describe one shared weapon placement. Five
digit planes must not independently move the same weapon to incompatible
positions. Preserve a single placement writer and evaluate the combined hand.

Weapon orientation is expected to have been established by the existing Forge /
mounting chain. The user deferred investigating a possible orientation defect;
do not add roll or orientation correction to this reseat as a workaround.
Skipping the 50 mm stage entirely may be compared later (large guide directly
to reposition/final wrapper); it is not the first test requested here.

### W5 — Retain constrained contact following after seating

- Keep the finger joints responsive within their limits, with the established
  contact targets active. Body/weapon manipulation should retain the grip through
  this response instead of holding an obsolete set of fifteen finger rotations.
- A handle-percent change still moves the weapon under the existing position
  ownership rules. Contact targets then slide over the saved wrapper / handle,
  and fingers accommodate the new section. Do not restart the old long acquisition
  for every percentage change; changing geometry still requires appropriate
  queries and bounded IK response, not a claim of zero calculation.
- **Primary acquisition/reseating:** Hand, wrist and upstream body stay fixed;
  the weapon is last to join and seats into the hand. Only the fingers accommodate
  it. The finger-contact controller does not drive arm, shoulder or body IK.
- **Normal authored manipulation:** the existing body-control system remains
  responsible for permitted body movement. Finger following preserves the
  relationship; the accepted wrist-Tip Roll behavior and grip-preserving movement
  limits must survive this replacement.
- **Support hand:** it joins the already held weapon and accommodates that chain;
  it must not reposition the weapon or primary hand. Preserve this contract for
  the later support cutover rather than silently adding that cutover now.
- Preserve non-weapon/open-hand and unarmed behavior. Retire superseded grip
  execution when the replacement takes ownership; never run two finger writers.

### Preserved values and acceptance rules

Use **radius**, not diameter, throughout this plan. Geometry uses metres in code;
human-facing values below are millimetres. The distinct radii have distinct jobs:

| Quantity | Current value / role |
| --- | --- |
| Forge V2 maximum custom-handle enclosing radius | 39.528470752 mm for the current perpendicular template boundary; not a guarantee for oblique slices. |
| Older template-plus-30-percent radius | 51.387011978 mm; not today's initial hand guide. |
| Current initial guide, all five right-hand digits | 117.110907 mm, derived from the prepared hand's maximum digit reach. |
| Current initial guide, all five left-hand digits | 117.111027 mm, derived the same way. |
| Requested preparation waypoint | 50.00 mm, skipped when the target is encountered sooner. |
| Existing minimum inward bend radius | 50.828474948 mm, from the prepared broad S3 side radius multiplied by 2.3; not an enclosing-circle size. |

- The inward guide target remains **1.5 mm** inside the handle surface.
- The identified palm attraction target remains **3 mm**, with a **2.5 mm maximum
  physical overlap**. Other unclassified skin is not automatically palm.
- Keep every digit section's existing target, cap and special policy. A deeper
  guide target does not increase permitted skin penetration; the section checker
  remains the stopper, including the existing special thumb S1 treatment.
- Default success requires **three distinct actual-material contact sections
  across the hand**; several points in one section do not multiply that count.
  Identified palm is one section. Contact count never overrides a violated cap
  or motion limit. Report unresolved final conditions honestly.
- Keep coordinate provenance through the named origin chain to `RL_BoneRoot`;
  register/derive new guide or contact data according to the coordinate law.
- A timeout, exhausted iteration budget or `preview_applied` status is not proof
  of a valid grip. Final actual skin and joint validation remain required.

### Implementation boundary, checks and next action

IK still computes joint angles internally. The intended change removes the
current expensive outer search over angle combinations; it does not mean the
engine automatically solves multiple blended-skin tangencies without targets
and contact checks. Prefer the documented native IK/modifier path, with only
the custom contact/target orchestration it needs. Official Godot 4.7 references
reviewed for this direction:
[CCDIK3D](https://docs.godotengine.org/en/4.7/classes/class_ccdik3d.html) and
[SkeletonModifier3D](https://docs.godotengine.org/en/4.7/classes/class_skeletonmodifier3d.html).
The captured 147 native processes totalled approximately 0.155 seconds; repeated
whole-skin trial evaluation was expensive. This supports investigating that
replacement boundary, not promising an unmeasured final solve time.

| Step | Status and proof required before marking complete |
| --- | --- |
| W1: prepared wrapper in Forge save | Preparation/persistence implemented; 105 focused checks passed on tested cases. W3 later exposed overlapping cap triangles in the saved digit target: source geometry needs correction before live consumption. See W1 evidence and W3 cap addendum; earlier slice checks did not certify caps. |
| W2: save progress | DONE. Actual UI Save/Save As, monotone 0-99, success after persistence, failures, fade/reset, compact refresh, repeated save, close/reopen and pre-write authoring changes verified. See W2 evidence below. |
| W3: contact-driven preparation | IN PROGRESS. Saved-surface adapter and five-digit native response proof exist. 35 structural checks pass; right uses 50 mm, left bypasses it at a larger oblique enclosing section. Required tangency is not achieved. Cap-section ambiguity and unique-query cost remain unresolved; see W3 evidence below. |
| W4: wrapper contact and transverse reseat | PENDING. Measure actual skin/material caps, contact retention, final joints and fixed primary Hand/wrist; visually expose the result. |
| W5: continuous following and retirement | PENDING. Test movement and handle-percent changes, preserve Roll/limit ownership and open hand, remove replaced execution, and measure full duration with the chronology tool. |

Starting source seams to inspect before edits: the shared Forge save transaction
in `runtime/forge_v2/crafting_bench_ui_v2.gd`, persistence in
`core/models/player_forge_wip_library_state.gd`, guide/envelope preparation in
`planar_grip_guide_progression.gd` / `planar_contact_envelope.gd`, and the current
acquisition/application/native IK owners under `runtime/player/grip/`.
Identify the actual saved resource definition and exact affected consumers as
part of W1; do not add a parallel storage format without tracing the existing one.

This direction supersedes frozen finger-pose retention and the current reseat's
frozen transverse-offset restriction. It preserves movement ownership, shape
freeze during reseating, the three-attempt limit and per-section overlap rules.
Implement one step at a time, record evidence here, and use the existing timing
tool for a complete comparable run once the replacement is ready. Do not mix
in support cutover, F generation/playback, unrelated IK fixes or general cleanup.
This planning update performs no code change, Godot run, commit or push.

### W1 investigation after user instruction to start — 2026-09-28

Historical investigation status: source audit completed; representation awaited
the user clarification below. No Godot run or runtime-code change in that pass.
The following implementation entry records the answer and subsequent edits.

Verified save chain:

1. `crafting_bench_ui_v2.gd::_run_v2_save_transaction` awaits
   `forge_v2_stage_controller.gd::prepare_pending_work_for_save` for both Save
   and Save As. Pending authoring and final geometry are resolved before handoff.
2. Both actions use `build_crafted_item_wip_for_save`, whose call to
   `forge_v2_wip_compatibility_adapter.gd::build_runtime_contract` creates the
   saved Stage2 geometry and baked profile. This is the common construction seam.
3. `player_forge_wip_library_state.gd::save_wip` clones, persists through the
   existing writer, and restores library state on failure. Do not add a writer.
4. `services/forge_service.gd::_bake_forge_v2_wip` later reconstructs that runtime
   contract and replaces Stage2/profile. Its mesh-packet reconstruction currently
   forwards material and protected-handle geometry only. New prepared wrapper
   data must be validated and carried through here to survive consumption.

Save As changes identity before contract creation. Keep wrapper geometry identity
separate from display names; track geometry, origin, algorithm and curvature
configuration. Do not mutate shared prepared resources during query. Preserve
saveable empty/unfinished authoring drafts: absent valid grip geometry differs
from failing to prepare a required wrapper for an otherwise valid weapon.

**RESOLVED by subsequent user clarification:** one saved 3D wrapper shared by all digit
slices, or today's exact independently constructed 2D wrappers. Today's builder
applies disk closing in the queried plane. Building a 3D surface first and slicing
it diagonally is generally a different operation. The first option matches the
requested prepare-once surface but changes some oblique results; preserving the
second requires plane-dependent preparation after the finger planes are known.
The user selected the saved 3D handle-only target tube. Skill Crafter slices the
wrapper and the actual handle together; the guide targets the former and actual
material overlap limits stop the hand against the latter. The wrapper is invisible.

A profile-derived 3D candidate can reuse the protected handle's existing CSG
path builder with a cloned body and enveloped profile, preserving its path,
orientation and existing X reflection. This is a candidate, not implemented or
verified containment for curved paths, end caps or adjacent weapon structures.
Closing a profile and sweeping it is not general 3D vacuum closure: it bridges
profile recesses but does not independently smooth longitudinal bends or ends.
It must not mutate the authoritative material/handle cache. Current grip capture
uses the full rendered weapon mesh, retaining contact near guards/blades; a
handle wrapper must not silently remove those material checks or contact options.

Existing checks to extend after choosing the representation:
`tools/verify_forge_v2_save_commits_pending.gd`,
`tools/verify_forge_v2_project_save_as_rename.gd`,
`tools/verify_forge_v2_wip_runtime_contract.gd`, and
`tools/verify_forge_v2_exact_handle_grip_surface.gd`. Use the established workspace
isolated save location. Required proof includes save/reload, Save As, downstream
rebuild retention, stale-input rejection, unchanged material geometry, and the
actual required wrapper slices. These verifiers were inspected, not rerun here.

Official Godot 4.7 references checked for this step:
[Geometry2D](https://docs.godotengine.org/en/4.7/classes/class_geometry2d.html),
[Resource](https://docs.godotengine.org/en/4.7/classes/class_resource.html), and
[ResourceSaver](https://docs.godotengine.org/en/4.7/classes/class_resourcesaver.html).

### W1 implementation and fresh evidence — 2026-09-28

Implemented the user-confirmed division: Forge prepares an invisible handle-only
3D target; Skill Crafter will slice that saved target alongside physical geometry.
No per-digit wrapper construction is added to Forge. No live finger solver,
upstream IK, actual weapon mesh, or physical overlap allowance was changed here.

The baker applies the existing limited-recess profile envelope, makes the already
approved 1.5 mm digit and 3 mm palm inward targets, and sweeps both along the
existing Handle path using its actual CSG orientation/sampling code. This is one
prepared wrapper resource with two target depths, not two grip controllers.
The source profile, curvature/character signature and construction revision travel
with it. All 3D vertices are metres in `WeaponRootOrigin`, which existing equipment
placement resolves to `RL_BoneRoot`; construction profiles identify
`ForgeV2HandleProfileOrigin` and bind to the source body's existing path mapping.
Temporary bake nodes are hidden and freed after extraction. Saved output contains
data arrays only, with no rendered mesh node, material or physics body.

The common Save/Save As preparation awaits this bake. Valid cached geometry is
reused on later saves and after reopening; source, settings or character changes
invalidate it. A fresh save of a valid Handle requires a matching target; an
unprepared/stale packet cannot bypass preparation through a direct save call.
Incomplete authoring drafts remain saveable. Older files without the new resource
remain readable under the current solver, and gain it through Forge resave.
The runtime contract rebuild carries the saved resource forward and validates it
without regenerating the wrapper. Live consumption/cutover belongs to W3-W5.

Files changed/added under the active project:

- `core/models/prepared_grip_target_wrapper.gd`: immutable-consumer saved data.
- `core/resolvers/prepared_grip_target_wrapper_resolver.gd`: identity, source,
  setting, finite geometry and closed/wound indexed topology validation.
- `runtime/forge_v2/forge_v2_grip_target_wrapper_baker.gd`: save-time preparation,
  existing native sweep, deferred readiness and hidden staging cleanup.
- `runtime/forge_v2/forge_v2_stage_controller.gd`: preparation, source/config
  guards, cached reuse and required handoff to persistence.
- `runtime/forge_v2/forge_v2_volume_preview_presenter.gd`: bound bake provider,
  reusing the established Handle geometry implementation.
- `core/models/stage2_item_state.gd`,
  `runtime/forge_v2/forge_v2_wip_compatibility_adapter.gd`,
  `services/forge_service.gd`: exported resource and validated rebuild retention.
- `tools/verify_forge_v2_grip_target_wrapper.gd`: focused proof and visual report.
- `tools/verify_forge_v2_save_commits_pending.gd`: its counted ready-packet fixture
  now uses the actual saved Handle instead of an unrelated tetrahedron lacking
  the required Handle metadata. The exactly-once handoff assertion is retained.

Fresh verification (one Godot process at a time; workspace-isolated save data):

- Final focused run: **105 checks, zero failures**, 24.951 seconds for the complete
  verifier, including setup, eight three-surface slice comparisons, saving,
  reloading, rebuild and fault checks. This is not live grip latency.
  `test_artifacts/forge_v2_grip_target_wrapper_2026-09-28T03-59-21.json`
  and adjacent `.html`/`_straight_slice.png`; engine log
  `godot_runs/the_will_2026-09-28_03-59-19.log`.
- Uses the already saved `odd shape 3` profile on straight and mild curved paths.
  Both digit and palm targets share each physical-material query plane; tested
  perpendicular and 35-degree oblique cuts at two locations on each path.
  Straight slices also verify the established Handle X reflection and dimensions.
- Source packet remains byte-for-byte unchanged. Target arrays survive fresh
  ResourceLoader reload and ForgeService rebuild unchanged. Tests reject stale
  body/mesh/settings/anatomy/origin and a handle edited after preparation; both
  accepted radius configuration representations are exercised.
- `verify_forge_v2_save_commits_pending.gd`: **PASS**, log
  `godot_runs/the_will_2026-09-28_03-55-54.log`. Real UI Save and Save As commit
  pending edits; terminal export failure, bounded timeout and packet handoff pass.
- `verify_forge_v2_project_save_as_rename.gd`: **PASS**, log
  `godot_runs/the_will_2026-09-28_03-58-29.log`. Expected errors from its deliberately
  blocked persistence path test rollback; they are not unexpected engine failures.
- Focused changed tracked-file `git diff --check`: clean. No commit/push or external
  player save modification. No character/hand-grip solve was run.

Scope of proof: the native sweep preserves the prepared cross-profile targets;
this is not general 3D morphological closure of longitudinal bends/end caps.
Closed topology and these slices do not certify every extreme curved handle or
absence of all self-intersection. Curvature settings are the current character's
prepared values, not a new universal body rule. The output contains about 24.7k
digit and 24.5k palm triangles per fixture at the existing precision. Runtime
slice/solver performance still needs measurement during the later integration.
At this W1 checkpoint, W2's numerical save indicator was the next separate step;
its subsequent implementation is recorded below.

Native bake APIs checked before implementation:
[CSGPolygon3D](https://docs.godotengine.org/en/4.7/classes/class_csgpolygon3d.html),
[CSGShape3D](https://docs.godotengine.org/en/4.7/classes/class_csgshape3d.html).

### W2 implementation — 2026-09-28

Save and Save As now share a separate, normally hidden label in the Forge top
action row, immediately before Close. It starts at `0%`; completed preparation
stages advance it to 30 (pending edits committed), 60 (runtime mesh ready), and
90 (wrapper ready). Empty drafts skip inapplicable work. It reaches `99%` before
the existing synchronous WIP construction/persistence call. These are completion
milestones, not an elapsed-time estimate; numbers may jump. There is no simulated
timer advancing progress while work is still pending.

Only a non-null saved WIP from the existing writer changes the label to `Saved`.
It remains for 1.5 seconds, fades over 0.5 seconds and returns to hidden. Failed
preparation/write shows `Save failed`, with the existing status retaining details.
A new save kills the previous fade and restores opacity. Normal refresh and
compact layout do not overwrite or hide the active indicator.

The UI yields two process frames at 0 and at 99 so these states can draw even
on an otherwise synchronous cached/empty save. A transaction generation rejects
old continuations after closing/reopening Forge. Authoring identity/timestamp
are rechecked after the new pre-write yield. Closing before persistence cancels
that pending write; it does not revert already committed authoring edits.

Runtime changes: `runtime/forge_v2/crafting_bench_ui_v2.gd` and
`runtime/forge_v2/forge_v2_stage_controller.gd`. The stage exposes an optional
completion callback; direct callers keep the existing default behavior. No new
writer, saved format, wrapper builder or live grip controller is introduced.

`tools/verify_forge_v2_project_save_as_rename.gd` now waits for the existing UI
transaction before asserting persisted identity, including Ctrl+S; its former
immediate assertions predated the visible-progress frame yields.

Fresh verification (sequential Godot 4.7 headless runs, isolated workspace saves):

- `tools/verify_forge_v2_save_commits_pending.gd`: **PASS**, clean final log
  `godot_runs/the_will_2026-09-28_10-29-12.log`. Actual pending-Handle Save and
  pending-noodle Save As; visible monotone 0-99 followed by Saved; exactly one
  persistence call per successful action; compact layout/refresh; replacement
  of an old fade; preparation and persistence failures; fade to hidden/reset;
  close/reopen at 99 with no stale write; authoring replacement before writing
  rejected and subsequent save recovers. Existing timeout and exactly-once
  runtime packet handoff assertions remain.
- `tools/verify_forge_v2_project_save_as_rename.gd`: **PASS**, log
  `godot_runs/the_will_2026-09-28_10-25-46.log`. Identity, copies, preserved sidecars,
  rename/delete, Ctrl+S after delete and rollback checks pass. Its deliberately
  blocked persistence path emits expected file-save errors.
- Scoped changed-file whitespace check passed. No commit or push. No live grip
  solve or manual visual session was run for this UI step. The engine tests use
  the real UI nodes and production save path; failure injection is test-only.

Next: W3 constrained contact-driven finger preparation, then W4/W5 as ordered
above. W2 does not change the expensive acquisition algorithm or claim reduced
grip duration.

Official Godot 4.7 references checked:
[Tween](https://docs.godotengine.org/en/4.7/classes/class_tween.html),
[Label](https://docs.godotengine.org/en/4.7/classes/class_label.html), and
[SceneTree](https://docs.godotengine.org/en/4.7/classes/class_scenetree.html).

### W2 follow-up: Handle menu clarification — 2026-09-28

The user confirmed the initial profile mismatch followed **Generate CSG Noodle**,
and that **Generate Handle** produces the expected selected profile. At the
user's request, the Shape menu now omits the CSG Noodle generation/status/clear
section while Handles is selected. This is a presentation-only condition in
`runtime/forge_v2/crafting_bench_ui_v2.gd`; noodle generation behavior is unchanged.

Fresh existing menu-flow verifier: **PASS**, Godot 4.7 headless, isolated workspace
saves, `godot_runs/the_will_2026-09-28_11-03-30.log`. It exercises tool-context menu
refresh and existing menu navigation. The new omission was checked in source;
no manual post-change game test was performed. This does not establish a fix for
the separately reported Skill Crafter saved-geometry refresh. No commit/push.
Official [PopupMenu documentation](https://docs.godotengine.org/en/4.7/classes/class_popupmenu.html)
was checked before this change.

### W3 implementation and measured boundary - 2026-09-28

The user asked to continue the W1-W5 list, then requested an SPS when this work
finishes. This pass implements isolated W3 preparation; it does not switch the
live acquisition owner or mark W3 complete. The older numerical live path still
owns gameplay. No W4 material/reseat or W5 movement work was added here.

New files under the project:

- `runtime/player/grip/prepared_saved_grip_sections.gd`: validates the saved
  wrapper, independently supplied physical Handle, current character settings,
  source identity and named plane chains; prepares triangle indices once.
  Each query slices actual Handle, digit target and palm target in each digit's
  fixed plane for one shared transverse weapon translation. The canonical guide
  center is the physical Handle section centroid, not the inset target centroid.
- `runtime/player/grip/contact_driven_grip_preparation.gd`: prescribed large,
  optional 50 mm and target-enclosing circles drive native constrained contact
  proposals. Existing prepared anatomy, skin observation and native IK are reused.
  Only fifteen digit angles and one shared transverse weapon placement respond;
  Hand/wrist/upstream pose, weapon orientation and axial station remain fixed.
  Missing preparation contacts are measured but do not gate later stages.
- `tools/grip_plane_proof/verify_prepared_saved_grip_sections.gd`: saved-target
  slice comparison and provenance/invalid-input checks.
- `tools/grip_plane_proof/run_contact_driven_preparation.gd` plus
  `contact_driven_preparation_view.html`: frozen-capture two-hand diagnostic and
  color-coded stage playback, showing actual skinned sections, joint projections,
  saved surfaces, guide circles and contact gaps. The HTML was generated but not
  manually inspected in a browser during this pass.
- `tools/grip_plane_proof/diagnose_saved_grip_section_coordinates.gd`: separate
  no-IK world/WeaponRoot comparison retaining the original end-cap failure.

The adapter queries immutable source triangles at a translated numerical plane
and rebinds the identical XY coordinates to the actual fixed hand plane. Both
the query and actual plane are named and traced to `RL_BoneRoot`; the translated
WeaponRoot record is emitted too. No approximate polygon, independent per-digit
weapon displacement, wrapper rebuild, tolerance relaxation or hidden axial
seating is introduced. Geometry/orientation/anatomy/plane epoch changes require
new preparation. This adapter covers the Handle and targets; full rendered-weapon
material checks near guards/blades must still be retained by W4.

The controller uses bounded native skin-witness proposals rather than the old
outer finite differences over finger angles. Witnesses may change within their
owned regions. The only finite-difference response here is the two-coordinate
shared weapon translation. Actual blended skin is remeasured after proposals.
Joint angles remain inside prepared ranges. Accepted endpoint proposals retain
already acquired guide contacts and do not introduce guide penetration when
starting clear. This does not prove continuous contact along the transition.
Four sweeps per prescribed stage are a numerical budget, not a physical stop.
No material grip verdict is made at this preparation boundary.

Fresh evidence, sequential Godot 4.7 runs with isolated workspace userdata:

| Evidence under `C:/WORKSPACE` | Result and limit |
| --- | --- |
| `test_artifacts/prepared_saved_grip_sections_2026-09-28T11-21-14.json`; log `godot_runs/the_will_2026-09-28_11-21-01.log` | 236 checks, no failures, 12.066 s. Straight/curved saved inputs, perpendicular/oblique synthetic planes, three translations, direct moved-mesh oracle, unchanged sources and rejected stale/invalid metadata. Not a general cap or whole-hand proof. |
| `test_artifacts/contact_driven_preparation_2026-09-28T11-35-05.json` and `.html`; log `godot_runs/the_will_2026-09-28_11-35-04.log` | Centered fixture, before exact query reuse. 35 structural checks pass. Right 76.087 s / 165 native processes; left 23.497 s / 92. Contact following incomplete on both. |
| `test_artifacts/contact_driven_preparation_2026-09-28T11-37-19.json` and `.html`; log `godot_runs/the_will_2026-09-28_11-37-18.log` | Same centered fixture with exact per-run query reuse. 35 structural checks pass. Right 63.979 s; left 12.222 s. Fixed Hand, named planes, source hashes, angle ranges and stage progression checked. Not successful grip acceptance. |
| `test_artifacts/contact_driven_preparation_cache_comparison_2026-09-28.json` | All recorded non-timing/non-cache results compare exactly equal before/after reuse: poses, geometry, native decisions, placement outcomes and failures. Only `ms`/`*_ms` and section-query request/hit/calculation/failure-count metrics were excluded. |

Exact cache scope is one immutable preparation run; keys are serialized world
translation bytes without rounding. Successes and failures are stored with
independent copies. It avoids 13 of 76 right-hand queries and 16 of 28 left-hand
queries. Actual remaining section work is 57.509 s right / 8.797 s left; native
IK is 0.107 s / 0.061 s. This is a W3-only comparison, not a reduction of the
earlier 313-second full acquisition or the user's longer interactive wait.

The expensive unique-section path performs closed-loop extraction and complete
simple-polygon validation for up to 15 sections per translation. Source review
finds quadratic endpoint/edge-pair validation; separate slicing-versus-topology
timings are still needed before selecting that next optimization. Keep the
topology checks: a closed contour alone does not prove a simple polygon.

Known incomplete behavior:

1. Both final preparation poses still lack required guide contacts. Right
   unrestricted section gaps range roughly 0.340-44.096 mm; left thumb S2/S3
   remain about 132.796/186.195 mm away. These are observed preparation gaps,
   not final material grip failures. W4 has not run. Increasing sweeps, loosening
   limits or describing structural PASS as successful following is not justified.
2. Right visits all three prescribed stages. Left correctly bypasses the 50 mm
   waypoint when the largest saved-target enclosure is 58.091 mm. Its initial
   outside placement is unresolved, but it continues rather than terminating.
3. Original fixture placement preserved the captured old span midpoint while
   substituting a shorter 380 mm saved Handle. The left pinky therefore sliced
   its positive end cap (plane origin x=191.196 mm; end x=190 mm). The independent
   diagnostic preserves this exact case. The current preparation fixture instead
   centers the saved span on the captured Middle plane once during setup, with
   that axial setup displacement recorded separately. Runtime axial motion is
   still rejected; the fixture adjustment is not a grip solver workaround.
4. Centering does not eliminate the geometry dependency. Large transverse movement
   makes the diagonal left thumb intersect the negative cap. Failed contour
   endpoints map to x approximately -190 mm; nearby cap sections can pass.
   Thus cap intersection is not itself invalid. Some resulting contours contain
   tiny backtracks/open or crossed segments that current exact topology checks
   reject in both world and WeaponRoot calculations. The final source-triangle
   review identified overlapping, oppositely wound cap triangles in the saved
   digit target itself; see the cap evidence addendum below. No shared slicer or
   Forge geometry correction was made.

Next narrow work: trace the demonstrated saved cap overlap through native sweep
construction and export, then fix at the evidenced owner with the direct geometry
oracle. In parallel with that source investigation, use W3's per-proposal
records to distinguish shared-placement blockage from skin-target/IK proposal
rejection. Required following remains unresolved even on the right where valid
interior placement probes execute. Do not jump to live cutover, add W4 acceptance
to conceal W3 gaps, or rebuild all grip code again. Keep progress/handoff truthful.

Official Godot 4.7 references read before this work: CCDIK3D, Skeleton3D,
JointLimitationCone3D and Transform3D. Native IK still solves angles internally;
the cheap native timing does not eliminate custom geometry/contact work.
No commit, push, external save mutation, installation or live acquisition run.

#### W3 cap evidence addendum - 2026-09-28 11:45

Final clean no-IK diagnostic:
`test_artifacts/saved_grip_section_coordinates_2026-09-28T11-45-33.json`, log
`godot_runs/the_will_2026-09-28_11-45-20.log`. The tool completes with no harness
or origin-chain failures; left-pinky Handle/digit-target/palm-target sections
still fail in both frames. This is successful observation of a defect, not a
passing geometry result. All original source data remains unchanged.

The original capture has a 539.407 mm span and grip pivot at about 0.8 of that
span. Substituting a 380 mm saved Handle at its midpoint explains the initial
cap placement. That placement is preserved by this diagnostic, independently
of the centered W3 preparation fixture.

The digit target contains source cap triangle **18239 wholly inside 18322** at
WeaponRoot X=189.999998 mm, with opposite winding. Signed YZ areas are
+0.085452702 and -70.446302310 square millimetres. The small triangle's centroid
lies strictly inside the larger; all its vertices have nonnegative barycentric
weights inside the larger. This is computed directly from saved source vertices
using scalar doubles, zero inclusion epsilon, no slicing/welding/offsetting;
an independent Python calculation of the report's raw vertices confirms it.
Both contributing triangles have no vertices classified inside the slicer's
1 micrometre on-plane band. Thus this demonstrated overlap is in the saved
source, not something that can be repaired by changing the slice tolerance.

Scope: this complete-containment certificate applies to **digit_target** only.
Physical Handle cap/side crossings remain observed, but this specific pair proof
must not be generalized to it or to all saved weapons. Native sweep construction,
input profile treatment and exported arrays still need tracing to identify the
actual source operation. No cap regeneration, shared slicer edit, tolerance
change or automatic Forge-output repair was made. Reopen W1's cap correctness
before treating its saved target as a general live-consumption input.

Final source check confirms only proof/verifier callers for the new W3 classes;
they are not attached to live acquisition. All six new W3 source/template files
pass whitespace/conflict-marker checks; the touched Forge menu file passes
`git diff --check`. The user's editor remains; diagnostic processes finished.
Handoff: [SPS September 28, 11:43](<../SPS/SPS_2026_09_28_11-43.md>).

## Verification, engine references and scope

The initial analysis inspected current source, its callers, relevant verifier
assertions and saved evidence. The subsequent planning pass expanded this note.
No Godot test or live game session ran in either pass, no solver timing was
remeasured, and no production file was edited. Implementation progress belongs
in the execution record above so this dated statement is not mistaken for a
future status report.

Official Godot 4.7 references checked:
[Skeleton3D](https://docs.godotengine.org/en/4.7/classes/class_skeleton3d.html),
[SkeletonModifier3D](https://docs.godotengine.org/en/4.7/classes/class_skeletonmodifier3d.html),
[MeshInstance3D](https://docs.godotengine.org/en/4.7/classes/class_meshinstance3d.html).
Bone global poses are skeleton-relative; final modifier completion and scene
presentation must not be confused with intermediate pose reads. These native
facilities do not by themselves supply the game's complete grip acceptance.

Preserve accepted wrist-Tip Roll and upstream IK ownership. F generation,
playback/save/reopen/runtime parity and character-save full-hand preparation
remain recorded downstream work. No commit or push was requested for this pass.
Stay within `C:/WORKSPACE`; additional applications, installations and access
outside it require discussion and permission. Material scope/behavior decisions
must be exposed to the user before implementation.


### September 30 execution: Middle-first coupled contact attempt

Current evidence supersedes September 28's alternating native proposal results.
`runtime/player/grip/contact_driven_grip_preparation.gd` now solves three actual
skin-contact constraints and one shared two-axis weapon translation together.
It uses `skin_contact_hinge_jacobian.gd` to differentiate the original weighted
skin, triangle-plane cuts and sliding contact points; clipped palm endpoints
include the moving reference-domain intersection. Existing hinge limits remain.
Bound-blocked hinge variables are removed from the local linear solve, without
expanding anatomical ranges. The old sequential native proposal loop in this
isolated owner is replaced; live acquisition has not switched to this owner.

Middle binds at R117.111mm, contracts through R50mm to its CURRENT enclosing
radius, then adds identified palm contact. Only converged combined guide/skin
states are committed. Failed numerical attempts are explicit unresolved
implementation results, not physical stops or final grip rejection. Dynamic
radius progress is guarded against no-progress loops. The target and physical
Handle section share the measured Handle centroid. Weapon orientation and
station, Hand/wrist/upstream pose, original skin weights and source files stay
fixed. Other digits cannot reposition the seated weapon.

`prepared_saved_grip_sections.gd` can query only selected named planes, avoiding
premature dependence on unjoined digits. Every queried plane still validates all
three real saved surfaces. Where a numerical derivative neighbour is invalid,
its failure is retained and the opposite neighbour may supply a one-sided
response. Every actual pose trial still requires valid source sections. This
is not a source-geometry repair. Original saved cap overlap remains unresolved;
new open/branched interior-query failures are not automatically attributed to it.

Shared `skin_plane_contact_query.gd` now uses a conservative edge-bound hierarchy.
The exact intersection predicates, tolerances and diagnostic order are unchanged.
The frozen comparison measured1224ms indexed versus4044ms all-pairs across its
cases; this is a geometry microbenchmark, not whole gameplay speed.

Fresh checks:
- `prepared_saved_grip_sections_2026-09-30T11-11-26.json`:382 checks, including
  selected/full-plane equality, source identity and immutable inputs.
- `skin_contact_hinge_jacobian_2026-09-30T11-05-40.json`:343 checks;90 digit
  derivative comparisons plus18 clipped-palmar comparisons,6 with nonzero
  shared-skin motion, using independently regenerated/resliced poses.
- `skin_topology_broad_phase_2026-09-30T10-57-24.json`:169 checks; complete packet
  equality on19 synthetic cases and60 frozen sections, including6 invalid caps.
- `godot_runs/the_will_2026-09-30_11-02-55.log`:existing contact-query33 checks pass.
- `contact_driven_preparation_2026-09-30T11-09-43.json/.html/.png`:43 checks pass.
  Middle/palm remain measured tangent on both hands, with legal hinges, named
  fixed Hand frames, immutable source, unchanged weapon orientation/station and
  no follower authority over its position. PNG geometry was inspected; HTML is
  generated, not browser-interaction-tested.

Final isolated timings: right23.344s, left25.994s. Enclosing radii38.483/39.858mm.
After palm seating, Middle S1/S2/S3 and palm clearances are about0.019-0.021mm.
Earlier accepted contraction errors remain below0.1mm. This measures sampled
constraint states, not a continuous swept-contact proof.

All four remaining digits are still unresolved in the final accepted whole-hand
state. RightIndex can independently reach its guide, but its shared skin moves
Middle's palm boundary about1.3mm away. The new retention check rejects that
proposal and preserves the previous seat. Thumb guide errors remain about
61.419/60.222mm; other failures are reported, not called successful grips.
The11:01 report's structural PASS coexisted with a missing-palm-context script
error; it is superseded and must NOT be used as clean success evidence. The11:08
failure exposed the shared-palm retention issue; the11:09 run verifies rejection.

Next: actual saved-wrapper following and shared-skin contact preservation at
fixed weapon seating, first resolving Thumb's remaining target/reach discrepancy.
No increased hinge/overlap limits, silent Forge geometry fix, live cutover,
support rewrite or F/playback expansion. W4/W5 remain pending; live latency and
final material grip are not fixed by this preparation test. Circle target gaps
alone are not a final physical grip verdict.

Official [Godot 4.7 CCDIK3D](https://docs.godotengine.org/en/4.7/classes/class_ccdik3d.html) and
[SkeletonModifier3D](https://docs.godotengine.org/en/4.7/classes/class_skeletonmodifier3d.html)
documentation was reviewed. Native
sequential bone targets do not automatically impose this simultaneous blended
skin constraint; the custom coupled response above is the implementation.

### September 30, 11:54: coarse radii and exact saved-wrapper following

The isolated controller now requests radius checkpoints directly, with failed
advances halved rather than a fixed 5 mm march. Fresh right sequence is
117.111 -> 100.333 fallback -> 50 -> 38.483 mm; left is
117.111 -> 50 -> 39.858 mm. The next active target is the exact saved Forge V2
digit/palm section, not a newly generated envelope or a second inset.

Attraction and collision remain separate. Saved targets retain their authored
1.5/3 mm depths; original section overlap caps and palm's 2.5 mm cap remain the
stoppers. The saved-wrapper adapter uses the existing bounded whole-edge depth
query. Unassigned skin has zero allowance; strict exterior evidence handles
zero-cap numerical intervals without granting penetration. An uncertain depth
upper bound never requests an inward correction.

The same small local solve now includes physical/guide inequalities, anatomical
bounds and a bounded step. An encountered cap can redirect motion tangentially.
Full nonlinear geometry checks still decide acceptance. Tiny slice fragments
that lack usable derivatives remain in those full checks; only their local
linear predictions are omitted and counted. Acquired-contact retention is also
checked after each reseat/follower proposal. At most three reseats remain allowed.

Files: `contact_driven_grip_preparation.gd`, `saved_wrapper_skin_contact.gd`,
`skin_contact_hinge_jacobian.gd`, the existing preparation runner/viewer, new
`verify_saved_wrapper_skin_contact.gd` and `verify_contact_constraint_step.gd`,
and the workspace snapshot renderer. No live pose writer was switched.

Fresh evidence under `test_artifacts`:

- `contact_driven_preparation_2026-09-30T11-49-45.json/.html/.png`: 51 structural
  checks pass. Exact saved polygons, unchanged sources/caps, fixed Hand and
  named frames, unchanged weapon orientation/station, fixed follower seat and
  reseat count are checked. This PASS is not complete grip acceptance.
- `saved_wrapper_skin_contact_2026-09-30T11-36-37.json`: 98 checks pass.
- `contact_constraint_step_2026-09-30T11-46-28.json`: 538 checks / 53 numerical
  cases pass, including independent 2D optima, active-bound release, duplicates,
  infeasibility, scaling and immutable inputs.
- `skin_contact_hinge_jacobian_2026-09-30T11-28-35.json`: 596 checks pass,
  including the new generic polygon-contact point derivative.

Measured result: left retains Middle S1/S2 plus palm (three distinct material
sections); its first reseat improves the fit, the second finds no legal
improvement. Right retains Middle S3 and Thumb S3 (two sections); its first
reseat does not improve. Right Middle S1/S2/palm still have gaps of about
2.728/0.135/4.553 mm. Left Middle S3 touches the bridged target region but remains
1.876 mm from actual material, so it is not counted as material contact.
Remaining followers are unresolved/rejected. Left Index would undo an acquired
contact and is correctly rejected. Full 3D grip and continuous swept tangency
remain unverified. Hand-level counts are distinct from the displayed Middle
slice's contact list.

Right duration: 85.480 s; left: 126.626 s for this isolated diagnostic. Main costs
are exact guide/material queries and saved-surface slicing; this is not live
performance. A rejected right correction still meets unassigned physical edge
`0/4176` at zero allowance; the rejected step's measured lower penetration is
about 0.000193 mm. That is a rejected local direction, not proof that no better
seat exists. Do not enlarge its allowance to hide the stop.

The earlier 11:29 run had an exact-source comparison failure caused by subtracting
rounded world origins; the oracle now uses the named authored displacement.
The 11:46 structural PASS stopped early on unusable tiny-edge derivatives and
is superseded by 11:49. PNG was rendered and visually inspected. HTML was
generated; no browser interaction is claimed.

Next narrow work: inspect the remaining right contact-bound direction and
shared-skin retention in this same controller. Include retained-contact motion
in the local constraint model if needed, while preserving full geometry checks.
Keep actual cap/topology failures explicit. Do not raise iteration budgets or
allowances blindly, or broaden into Forge cap repair/live/support/F cutover.
Official Geometry2D and CCDIK3D documentation informed this slice; native
nearest-segment geometry is used by the adapter alongside the mature depth query.

### September 30, 13:38: accepted behavior preserved; duration-only work

The user's acceptance of the current model supersedes the preceding proposed
right-seat correction. Preserve the input orientation's influence on seating.
This slice changes how repeated geometry work is executed, not the grip model.

Retained changes:

- `planar_skin_overlap_budget.gd`: derived scalar bounds tree over contiguous
  source-edge ranges. Conservative rejection accelerates ordered topology,
  boundary intersections, signed-distance samples and nearest contact. Original
  narrow arithmetic, source order, first witnesses, ties, bounds and budgets stay.
- `skin_plane_contact_query.gd`: exact repeated endpoints reuse their first
  representative; every weld diagnostic still counts. Intersection/nearest
  primitives avoid temporary candidate arrays/dictionaries; the projection
  direction is computed once with the same Vector2 arithmetic.
- `saved_wrapper_skin_contact.gd`: reuse the existing bounded exact segment
  cache. `contact_driven_grip_preparation.gd` begins one acquisition epoch and
  reports statistics. Full keys, metadata, caps and configuration remain part
  of identity. No quantized coordinates, approximate reuse or larger limits.
- The existing cache's obsolete prototype comment was corrected. No second
  production grip owner, new physical allowance or new exported knob was added.

Final full run: `contact_driven_preparation_2026-09-30T13-34-54.json`, 51 checks.
Comparison against the accepted 11:49 report passes across recorded stages,
poses, contacts, placements, rejected events, source records and non-timing
counters. Only numeric duration fields, work counts and cache statistics are
excluded. The comparison tool is `tools/grip_plane_proof/compare_grip_duration.py`.

| Hand | Accepted reference | Final | Reduction |
| --- | ---: | ---: | ---: |
| Right | 85.480 s | 45.152 s | 47.18% |
| Left | 126.626 s | 60.530 s | 52.20% |

Focused checks on retained code: planar overlap 80; saved-wrapper contact 106;
exact cache 114; independent endpoint/topology comparison 183 (60 captured
sections, six invalid sections retained); independent contact primitive
comparison 1,333; overlap acceleration comparison 246. The latter kernel oracle
shares Contact's preload, so the separate frozen Contact comparison is necessary
and was run. Full poses are also compared with the pre-change recorded result.
Detailed artifact timestamps are in the linked SPS.

The indexed triangle traversal experiment preserved results but did not improve
timing (1,549.528 vs 1,532.736 ms in its final bounded comparison; 462 checks).
Both runtime files were restored from their pinned originals, with hashes
confirmed. Its verifier and evidence are archived in test_artifacts rather than
kept as a new active path. Existing reachable-slice (70) and prepared-section
(158) checks ran during that experiment; the final complete run uses the
restored originals. No claim of a slicing speedup from that attempt.

Remaining cost: section queries 23.129 / 17.231 s right/left; wrapper observation
16.682 / 37.423 s (including target preparation, material/guide measurements and
witness normalization). These timers overlap internally; do not sum inclusive
subtimers again. Exact cache hits are 3,575 / 3,400, misses 19,965 / 36,156.
Default memory bounds and eviction policy remain unchanged; costs are recorded.

Next duration-only focus: measure nearest-contact versus depth-sampling time
inside the existing query, and topology versus triangle intersection inside
section processing. Use aggregate phase timing, not per-edge clock calls. Target
the dominant measured work; verify the complete accepted report again. Do not
resume behavioral correction, live cutover, Forge cap repair, support or F work.
These isolated diagnostics remain far above the interactive timing target.

Official Godot 4.7 [CPU optimization](https://docs.godotengine.org/en/4.7/tutorials/performance/cpu_optimization.html)
and [Geometry2D](https://docs.godotengine.org/en/4.7/classes/class_geometry2d.html)
documentation were reviewed. Existing native geometry calls remain where they
already apply; no profiler installation or external application was used.
