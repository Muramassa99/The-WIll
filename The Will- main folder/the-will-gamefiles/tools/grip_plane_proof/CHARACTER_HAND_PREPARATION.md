# Character hand preparation tool

This tool prepares character anatomy once, saves it as a character-linked
Resource, and reuses that Resource while its source data and preparation recipe
match. It does not need a weapon, saved forge library or Skill Crafter session.

As of 2026-09-27, the exporter prepares **all five of Josie's digits on both
hands**, using the existing authored bone names, hinge axes and joint limits.
The original Middle/Thumb resource stays immutable and readable. The resulting
data remains measured anatomy, not a validated contact envelope or completed
grip. Earlier four-digit proof results below keep their original scope; the
all-digit extension is described at the end of this file.

The subsequent [prepared-skin solver proof](<../../../../GDD-and Text Resources/ToDo stuff/Prepared Skin Contact Solver Proof 2026-09-15.md>)
now consumes this output. That experiment verifies reusable pose geometry but
has not established a valid real-weapon grip or acceptable full solve latency.

## Run

From `C:\WORKSPACE`:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File 'The Will- main folder/the-will-gamefiles/tools/launch_the_will_safe.ps1' -Headless -ScriptPath res://tools/grip_plane_proof/export_character_hand_anatomy.gd
```

The tool creates its own isolated rig, lets its normal startup establish model
scale, disables processing/animation/modifiers, and explicitly resets imported
rest poses. It measures that character, rather than an editor's current pose.
The imported rest data is preserved separately from the calibrated digit zero.
Joint 2/3 absolute local rotation is zeroed for that calibrated frame; this is
not described as merely removing animation.

The output is:

```text
res://tools/grip_plane_proof/prepared_characters/josie/<source-signature>.tres
```

If a matching valid file already exists, the tool loads it and reports
`expensive_bake_ran=false`. A mismatched existing file is rejected and is never
overwritten automatically. Changed inputs produce a different filename.

Current verified output:
[Josie preparation data](prepared_characters/josie/0fb9e5dbe88cd71e342f4efe106676026345d283374abede7dc98853dd784bf5.tres).

## Data ownership and contents

`character_hand_anatomy_def.gd` is a data-only Resource. Preparation logic lives
in `bake_character_hand_anatomy.gd`; persistence/validation lives in
`character_hand_anatomy_store.gd`. Consumers treat the saved definition as
read-only and duplicate data before making instance-specific changes.

The output stores:

- Character ID, source scene, schema/preparation revision and source signature.
- Measured bone spans and terminal skin extents, at the resolved character scale.
  A wrist-to-knuckle distance is labelled as a bone span, not outer hand length.
- Original relative bone transforms and explicit calibrated-zero adjustments.
- Current authored hinge axes and angle ranges, with their named bone frames.
  These movement rules are not inferred from the mesh's appearance.
- Actual skin cross-section ray measurements, including asymmetry. There is no
  fallback to the old hardcoded Josie finger radii or terminal dimensions.
- Actual skin-plane slices at calibrated zero, half preferred closure and
  preferred closure. Open contours and incomplete classification stay explicit.
  Three samples do not certify every intermediate angle or a rigid oval fit.
- Shared reference geometry, original weights, bind/rest data and named origins,
  preserving the palm's contribution to skin deformation. This proof retains
  the full reference skin once; it does not duplicate it for each digit.

All saved positions have a named reference frame. Digit-plane coordinates are
physical meters; their complete affine transforms resolve to `RL_BoneRoot`.
Original bone coordinates and local rotations retain their bone/parent IDs.
The Resource contains no live Nodes, registry objects, world-placement snapshots
or per-run timing state. Timings belong in the tool's output/log.

## Reuse and invalidation

The signature covers vertices, triangle indices, bone influences and weights,
bind transforms, the full ordered bone hierarchy/rest transforms, named
reference frames, morph values, character metric scale/handedness, authored
joint rules, source identity, preparation code dependencies and engine revision.
Dictionary insertion order does not change it. The current prototype hashes
the whole model conservatively, so a change away from the hand can also require
a new preparation.

`load_matching(path, expected_signature, expected_revision)` does not invoke the
baker. A missing or stale definition is returned as an explicit failure. The
expected signature belongs to character setup/change handling; it should not
be reconstructed by every grip query.

At eventual runtime integration, load/validate the Resource once during
character setup and retain the reference. Grip acquisition can then read the
prepared values. Weapon geometry and selected hand placement remain variables
that require their own solve; this Resource cannot pre-solve arbitrary future
weapons. Its current skin representation still needs contact-shape validation.

## Verification

Final initial preparation log: `godot_runs/the_will_2026-09-15_11-38-56.log`.
The numerical preparation took 936 ms; complete capture/preparation/save took
1,294 ms. The final matching-file run in
`godot_runs/the_will_2026-09-15_11-48-35.log` reused the saved output without
running the expensive bake. Source checking took 174 ms and Resource loading
plus validation took 293 ms (467 ms total). These are character setup costs,
not the cost of a repeated lookup or a weapon-grip solve.

`verify_character_anatomy_signature.gd` passed **39 checks** in log
`godot_runs/the_will_2026-09-15_11-42-52.log`. It checks determinism, dictionary
ordering, 16 kinds of changed inputs, missing-origin rejection and input
immutability, using one isolated rig without running the expensive bake.

`verify_character_hand_anatomy_store.gd` passed **38 checks** in log
`godot_runs/the_will_2026-09-15_11-45-18.log`, loading the saved definition without
instantiating a character or recomputing anatomy. It verified four digits,
12 outline poses, 144 measured cross-section rays, immutable persistence,
independent duplicate data and rejection of stale or malformed definitions.
The largest difference between stored section lengths and lengths reconstructed
from their calibrated origin chains was 0.000084 mm. These checks validate the
saved measurements and their frames; they do not certify a finished grip.

To verify the saved definition without creating a rig:

```powershell
$env:THE_WILL_ANATOMY_RESOURCE_PATH = 'res://tools/grip_plane_proof/prepared_characters/josie/0fb9e5dbe88cd71e342f4efe106676026345d283374abede7dc98853dd784bf5.tres'
powershell -NoProfile -ExecutionPolicy Bypass -File 'The Will- main folder/the-will-gamefiles/tools/launch_the_will_safe.ps1' -Headless -ScriptPath res://tools/grip_plane_proof/verify_character_hand_anatomy_store.gd
```

This stage changes only the preparation/proof tools and their generated data.
It does not install a new live grip solver, alter the accepted Roll, or change
F generation, saving or two-hand behavior.

## Coherent surface evaluation (September 18 P1)

`prepared_hand_skin_query.gd` reuses the saved reference skin. `prepare(reference,
signature)` compiles unchanged weighted bind-space points; `pose(prepared, packet)`
reconstructs the full surface from supplied current bone frames. Missing positive
contributors reject explicitly. Returned vertex/topology data can be consumed
without changing the prepared coefficients. This is a surface evaluator, not a
contact solver or grip acceptance test, and it requires no weapon.

A pose packet supplies the matching anatomy signature, unique pose ID, one
resolve phase, `RL_BoneRoot` identity, full `machine_to_world`, mesh origin ID,
source-bone-to-origin mapping and complete named origin records. Each record has
parent, full affine transform, owner, phase, space type and dynamic/static flag.
All chains reach `RL_BoneRoot`; rest frames never fill missing current frames.
Setup/capture establishes model correspondence and same-epoch provenance.
Matching signature/pose labels alone do not prove either property.

`capture_coherent_skin_pose.gd` checks the current zero-morph model's original
arrays, binds and rests against this saved reference, then synchronously reads
all current bind/mesh frames. It does not change bones or bake anatomy. Its
reference checking is diagnostic setup cost; eventual runtime reuse must attach
validation to character changes. Active morphs reject pending an explicit
correspondence adapter. This does not restrict future prepared character shapes.

The existing `diagnose_skill_crafter_grip_acquisition.gd` enables complete capture
with `THE_WILL_CAPTURE_COHERENT_SKIN=1`. It stores `posed_character` at
`finger_solve_input`, with side/frame/solve identity. The older digit snapshots'
`base_bone_world` is reconstructed neutral/open data, not current skin pose.

Use an isolated workspace user directory before running this diagnostic:

```powershell
$env:APPDATA = 'C:\WORKSPACE\test_artifacts\grip_p1_runtime\roaming'
$env:LOCALAPPDATA = 'C:\WORKSPACE\test_artifacts\grip_p1_runtime\local'
$env:TEMP = 'C:\WORKSPACE\test_artifacts\grip_p1_runtime\temp'
$env:TMP = $env:TEMP
$env:THE_WILL_DIAGNOSTIC_USER_ROOT = 'C:/WORKSPACE/test_artifacts/grip_p1_runtime/roaming/Godot/app_userdata/The Will-Gamefiles'
$env:THE_WILL_CAPTURE_COHERENT_SKIN = '1'
powershell -NoProfile -ExecutionPolicy Bypass -File 'The Will- main folder/the-will-gamefiles/tools/launch_the_will_safe.ps1' -Headless -ScriptPath res://tools/diagnose_skill_crafter_grip_acquisition.gd
```

The four directories already exist for this run, with copies of workspace backup
saves in the expected user directory. The diagnostic refuses a user directory
different from the declared workspace path before loading the library. This
process-local environment routing does not modify system environment settings.

`verify_prepared_hand_skin_query.gd` runs without a scene. Optionally provide
semicolon-separated workspace capture paths in `THE_WILL_COHERENT_CAPTURE_PATHS`
to check fresh captured poses as well as synthetic ones. Use the same launcher
and isolated environment, with this verifier as `-ScriptPath`.

Fresh P1 result: 190 checks passed in
`godot_runs/the_will_2026-09-18_02-04-53.log`, including both complete captured
single-hand setups, independent source-array reconstruction, missing contributors,
affine transforms, preserved nonunit weights and input/output ownership. Full
15,992-vertex preparation took 25.766 ms; captured evaluations 8.775-10.894 ms.
These are component timings and do not certify a valid grip or live performance.
Detailed inputs, limits and next steps are in
[Grip Overhaul Consolidation](<../../../../GDD-and Text Resources/ToDo stuff/Grip Overhaul Consolidation 2026-09-18.md>).

## Observed placement comparison (September 18 P2)

In the same isolated environment, set `THE_WILL_CAPTURE_GRIP_PLACEMENT=1` and
run `diagnose_skill_crafter_grip_acquisition.gd`. This implies coherent capture.
It prints separate `GRIP_PLACEMENT_TRACE_CAPTURE` paths for each hand. Each trace
groups observed before-seat, exact solver input, actual after-seat and associated
finger inputs by transaction. A rejected proposal is stored separately from what
was actually observed. Anatomical target reads require an already initialized
baseline; the tool cannot silently trigger character/animation preparation.

Set `THE_WILL_GRIP_PLACEMENT_PATHS` to those `.bin` paths separated by `;`, then
run `res://tools/grip_plane_proof/diagnose_coherent_grip_placement.gd` with the
supported launcher. This offline consumer prepares the saved skin once and
compares Middle/Thumb sections for every actual stage. Origin/epoch mismatches
and producer-rejected traces fail explicitly. Reports go to workspace
`test_artifacts/coherent_grip_placement_<timestamp>.json`.

The measurement planes are prepared anatomical planes attached to the captured
Hand, not necessarily the articulated finger planes. Queries are reach bounded.
Crossings retain original triangle IDs and every skin weight, including shared
tissue and nearby body geometry; other body triangles are not relabelled palm.
Counts are source-face events, not unique penetrations or contact acceptance.
The tool deliberately does not certify cropped-solid containment or 3D clearance.

Final observed-stage run: `godot_runs/the_will_2026-09-18_02-32-01.log` processed
22 stages / 44 digit-stage sections successfully. Geometry matched the preceding
capture exactly after adding the baseline-read guard. P1's 190 checks passed
again on final inputs in `godot_runs/the_will_2026-09-18_02-32-40.log`.
The working guide records source triangles, rejection/restoration observations
and the remaining placement/contact decisions. Production gripping is unchanged.

A [static section review](<../../../../test_artifacts/coherent_grip_placement_review_2026-09-18.html>)
shows 11 measured panels with equal millimetre axes and source-weight tables.
Its companion Python renderer uses the final report directly. Structural checks
passed; browser appearance has not been visually reviewed.

## Isolated coordinated closure experiment (September 18 P2)

`prepared_hand_candidate_pose.gd` reuses the same complete reference and captured
pose. Selected digit angles are absolute prepared calibration angles, not deltas
from the captured articulation. Hypothetical Hand translation transports its
descendants while preserving every skin influence and all upstream frames.
`verify_prepared_hand_candidate_pose.gd` uses `THE_WILL_COHERENT_CAPTURE_PATHS`
and compares sparse evaluation with complete P1 reconstruction; the first run
passed 151 checks. It does not establish arm realization or grip acceptance.

`planar_skin_overlap_budget.gd` provides whole-segment inward-depth bounds against
one complete simple polygon and explicit per-segment allowances. Refined bounds,
numerical guard, work-budget uncertainty and nearest-point/tangent witnesses are
separate outputs. `verify_planar_skin_overlap_budget.gd` is its scene-free verifier.
Both run through the supported launcher and isolated process environment above.

`run_coordinated_grip_closure_proof.gd` consumes the same explicit
`THE_WILL_GRIP_PLACEMENT_PATHS`. Set `THE_WILL_CLOSURE_ACTUAL_ONLY=1` to test only
the captured real handle; otherwise the runner also offers synthetic area-matched
circle/square contours. Those additional closure fixtures were not run in this
pass. It writes `test_artifacts/coordinated_grip_closure_<timestamp>.json`.

The experiment freezes the post-seat finger-input weapon pose, uses separately
named fixed measurement planes, and searches Middle/Thumb independently. The
shrinking circle is soft guidance; no separate vacuum membrane or curvature
solver exists yet. Trial source-weight majority assigns section allowances;
unassigned shared skin remains explicitly unresolved. Reports always distinguish
successful diagnostic execution from acceptance of a grip. The first actual
four-case run did not solve the grip, and its offline search cost is too high
for live use. See the working guide for results and subsequent exact query-cost
verification.

Handle-% editing retains its existing ability to move the weapon. Only the grip
acquisition experiment freezes its resulting input pose. These tools do not
write live poses, change Roll, alter saved anatomy or integrate a replacement.

Final overlap checks passed 80 assertions, including exact optimized/exhaustive
query comparisons. Repeating all four real cases preserved geometry and search
results; total diagnostic time fell from 42.92 s to 27.27 s in the measured runs.
This still does not meet interactive latency or full-grip acceptance.
The [final planar review](<../../../../test_artifacts/coordinated_grip_closure_2026-09-18T04-33-42_review.html>)
shows all four cases. Its standalone Python renderer is next to the artifact;
HTML/SVG structure was checked, browser appearance was not visually reviewed.

## Shared Hand and palm preparation experiment (September 18 P2)

`prepared_grip_slice_contact.gd` observes each digit in a supplied coherent
candidate. `verify_prepared_grip_slice_contact.gd` uses frozen workspace inputs
and compares eight cases with the preceding evaluator: 199 checks passed in
`godot_runs/the_will_2026-09-18_05-00-24.log`. Historical infinite missing-contact
values retain their meaning; they are not converted to zero.

`run_shared_hand_closure_proof.gd` consumes the explicit
`THE_WILL_GRIP_PLACEMENT_PATHS` in the same isolated launcher environment. It
searches six Middle/Thumb joint angles and one shared pair of transverse Hand
translation coordinates. Both observations use the same complete skin pose.
Translation moves the anatomical planes, so each distinct placement requires
fresh slices of the unchanged weapon. Several complete starting poses avoid
discarding folded configurations at the first locally unfavorable bend.

The first common search report is
`test_artifacts/shared_hand_closure_2026-09-18T04-55-59.json`: two completed
diagnostic cases, neither an accepted grip, 54.264 seconds in total. Both sides
still have gaps and unassigned shared-skin intersections. These costs and contact
results do not permit live integration. Arm realization is not simulated.

`prepared_palmar_contact_def.gd` and `prepare_character_palmar_contact.gd` add an
explicit character-preparation experiment: paired rays from nine interior points
of the wrist/Index1/Pinky1 footprint, in the saved reference rest. Authored
ordinary-finger closing directions identify the palmar side. Source faces,
surface-local vertex indices, barycentric coordinates, original influences,
metric and named frame chains remain recorded. The footprint is not a complete
anatomical palm boundary, and ray bracketing is not a solid-enclosure certificate.

Run `verify_prepared_palmar_contact.gd` with explicit
`THE_WILL_COHERENT_CAPTURE_PATHS`; only their physical presentation enters the
baker, not the captured articulation or weapon. The first run failed completion:
four of nine pairs per hand met the proposed strict Hand-majority requirement.
Rejected samples retain their shared influences. No complete palm resource was
saved and the original anatomy remains unchanged. The overlap policy for palm
skin is still undecided. This failed preparation must not be consumed as a
verified whole palm or silently repaired by loosening ownership thresholds.

All nine paired hits do exist: the incomplete state concerns strict weight
attribution. Original blended deformation weights do not establish anatomical
palm membership. Partial-output roundtrip/covariance checks were skipped by the
failed preparation verifier and must not be reported as passed.

`verify_shared_hand_closure_gates.gd` passed 103 synthetic provenance, sorting and
failure-propagation checks. The final shared search at
`test_artifacts/shared_hand_closure_2026-09-18T05-05-25.json` reproduces the first
run's geometry, selected poses and evaluation counts exactly after excluding
timings and added status fields; total diagnostic time was 53.080 seconds.

`inspect_shared_palmar_contact.gd` rehydrates the pinned first report's initial
and selected candidates, checks their recorded frame correspondence and resolves
all nine reference palmar carriers per hand, preserving rejected ownership labels.
It uses the existing 3D point query without setting a palm overlap allowance.
The surface preparation's 11 omitted tiny triangles are audited individually;
retained coordinates/order must match exactly. Distances explicitly concern that
prepared surface, not verified clearance from the complete captured mesh.

Final report: `test_artifacts/shared_palmar_contact_2026-09-18T05-11-24.json`.
All 36 unsigned point queries succeeded; none has a valid signed classification.
The existing topology check reports four nonmanifold edges on the prepared
surface. The same rule on the unfiltered source reports 14 nonmanifold edges,
nine degenerate edges and 11 degenerate triangles. These findings require tracing
the existing geometry/query boundary; they do not establish a Forge defect.
No runtime code, topology threshold or original anatomy was changed.

## Isolated contact envelope proof (September 26)

`planar_contact_envelope.gd` constructs a provisional numerical contact envelope
from one complete simple polygon in a named metric plane and an explicit minimum
inward radius. It uses native round polygon expansion/contraction, with explicit
numeric rescaling for Godot 4.7's fixed arc tolerance. It does not move bones,
replace collision geometry or certify a grip. Existing flesh-give settings are
separate. Multi-loop outputs reject; this is not a general 3D wrapper exporter.

Preparation/verification tools under `C:/WORKSPACE/test_artifacts`:

1. `measure_fingertip_radius.py` measures a disclosed approximate circle from the
   saved green S3 skin; includes fit residual and cap-selection sensitivity.
2. `build_contact_envelope_review.py prepare` validates source frames and writes
   `contact_envelope_input_2026-09-26.json` (22 actual/synthetic/rejection cases).
3. Run `res://tools/grip_plane_proof/run_planar_contact_envelope_proof.gd` through
   the supported headless launcher and isolated process environment above.
4. `verify_contact_envelope.py` checks full contour geometry independently, then
   `build_contact_envelope_review.py render` writes the visual HTML/SVG report.
   The existing `rasterize_grip_visual.ps1` renders its `.drawing.json` to PNG.

Final construction run: `godot_runs/the_will_2026-09-26_20-01-31.log`.
Independent verification: 183 checks passed within a declared 0.01 mm spatial
tolerance. Numerical undercut remains explicitly measured, not called exact
containment. See [the visual proof](<../../../../test_artifacts/contact_envelope_review_2026-09-26.html>)
and the active consolidation guide for timing, limitations and source evidence.

The initial 8.702241398 mm Right Middle radius is provisional, not a ten-digit
average or a completed character resource. The user's next preparation direction
is to measure all ten tips, preserve min/max/average and fit quality, and store a
chosen radius with the character data for reuse. The future Forge V2 wrapper
export must retain its geometry/radius identity and resolve oblique-slice reuse.
Those integrations are documented in the full-hand character-creation TODO.

Later September 26 correction: the user selected the broad S3 side curve rather
than the terminal cap. `measure_fingertip_radius.py` schema v2 now marks
`side_arc_fit` as the active reference, radius 22.099336934 mm, with 0.252529 mm
RMS and 0.509827 mm maximum radial residual. The envelope runner consumes that
measurement. Seven actual contour segments, selected from the side's proximal
boundary to its first axial reversal, are recorded; the returning underside and
terminal lip remain source geometry but are excluded from this particular fit.
Old cap data/visuals are preserved in
`test_artifacts/contact_envelope_terminal_cap_2026-09-26/`. The regular review
paths display the new result. This remains a Right Middle diagnostic, not the
final ten-digit character average.

## Envelope tuning and first hand match (September 27)

The working envelope now uses the user's **2.3 multiplier** independently of
the saved 22.099336934 mm side measurement, producing a 50.828474948 mm minimum
inward radius. `build_contact_envelope_review.py` keeps both values explicit.
The construction input now has 23 cases, retaining 0.5/1/2 comparisons against
the measured radius. The independent verifier passed 212 checks at the existing
0.01 mm tolerance. The previous 1x review is preserved under
`test_artifacts/contact_envelope_side_arc_1x_2026-09-26/`.

`run_envelope_hand_match_proof.gd` reuses the shared candidate/search machinery
with two targets per slice: actual material and the contact envelope. It loads
the measured radius/multiplier configuration explicitly and validates its source
measurement hash. The optional contact target in `prepared_grip_slice_contact.gd`
uses the same posed skin segments; raw material measurements retain their old
field meanings and envelope measurements have separate `contact_*` fields.
Both targets apply the existing provisional section depth budgets. Unknown
shared-skin allowances remain unknown. This is an offline matching experiment,
not a production grip or a complete palm/opposition solver.

Run through the supported launcher with the same isolated environment and
explicit `THE_WILL_GRIP_PLACEMENT_PATHS` shown above. Output is
`test_artifacts/envelope_hand_match_<timestamp>.json`. The wrapper target is
cached by exact shared Hand translation, because that determines the digit
planes; angle-only candidates reuse it. `Depth.prepare_ordered_target` preserves
the offset loop's explicit connectivity and every nonzero short edge. Its
dedicated verifier passed 32 checks; the unchanged material-only observer path
passed its 199 comparisons again. The original unordered slice preparation is
unchanged.

The first envelope hand-match output is
`test_artifacts/envelope_hand_match_2026-09-27T00-58-16.json`. Both hand cases
completed, but neither achieves a full grip: Middle S1/S2 gaps remain on both
sides, Left Thumb S3 remains separated, and shared/unassigned skin still
intersects. Raw and envelope caps pass only for the known assigned sections.
Right search: 205 candidates / 67.568 s; left: 202 / 58.757 s. These are offline
diagnostic costs, not acceptable live acquisition times.

`verify_envelope_hand_observation.gd` passed 293 focused dual-target comparisons.
`test_artifacts/verify_envelope_hand_match.py <report.json>` passed 87 saved-output
checks, including all eight source/envelope containment bounds. Render with
`test_artifacts/render_envelope_hand_match.py <report.json>`; the
[HTML comparison](<../../../../test_artifacts/envelope_hand_match_2026-09-27.html>)
preserves all observed skin, initial/selected scale and separate target witnesses.
Unknown palm/tissue policy and opposing-contact placement remain unresolved.

## Outside circle following and reseating trial (September 27)

`run_circle_hand_process_proof.gd` starts Middle and Thumb at their authored open
angles, with the captured skin moved rigidly outside an exact 50 mm guide circle
in each digit's own metric plane. Other digits retain captured poses. The weapon
stays fixed; only transverse placement and the two prepared digit chains vary.
Every current circle center equals the area centroid of its current actual
weapon slice. Both coordinates have the named digit-plane origin; the same point
is also recorded in `WeaponRootOrigin` coordinates. Oblique slices are recomputed
as the hand moves. No independent circle-center offset or cylinder is used.

All observed skin edges constrain clearance, including unassigned skin. Contacts
slide freely: no fixed palm point is chosen. Each candidate must keep the complete
current weapon section inside its circle. The 20 micrometer circle clearance is
a diagnostic guide policy, separate from real-material flesh-give allowances.
Rigid placement preserves original weights and Hand/forearm shape; this is an
isolated presentation transform, not an implemented gameplay arm-IK solution.

The initial following pass permits opening and closing adjustments. One further
bounded cycle tries eight small opening/translation seeds and recloses, ranking
results by required sections within a 0.1 mm contact band, then remaining gap.
The ranking can exchange contacts or trade gap for a new contact; reports retain
before/after identities and measurements. No change is accepted just because an
attempt ran. Continuous collision and global optimality are not certified:
accepted transitions are sampled at at most 0.5 mm / 0.5 degree per joint.

This experiment covers the circular phase. Once a shrinking circle reaches the
weapon's outer extent, further closure needs the existing noncircular membrane
construction connected to following; this trial does not shrink through material.
It does not certify a complete grip or write a production pose.

Use the supported headless launcher and explicit frozen placement paths from the
earlier shared-hand instructions, setting `-ScriptPath` to
`res://tools/grip_plane_proof/run_circle_hand_process_proof.gd`. Output is
`test_artifacts/circle_hand_process_<timestamp>.json`. Supporting checks:

- `verify_planar_circle_skin_contact.gd`: whole-edge analytic clearance,
  crossing edges and provenance/rejection cases.
- `verify_circle_rigid_placement.gd`: full original-weight skin reconstruction
  against the rigid presentation helper; named Hand, plane and joint frames.
- `test_artifacts/verify_circle_hand_process.py <report.json>`: independent
  retained geometry, centroid coincidence, origin chain, sampled path summaries,
  weapon containment and reseating result checks.
- `test_artifacts/render_circle_hand_process.py <report.json>`: self-contained
  HTML replay with play/pause/step/scrub and synchronized Middle/Thumb views.
  It displays actual retained frames, not interpolated artwork. The accompanying
  `.drawing.json` can be rasterized using `rasterize_grip_visual.ps1`.

Recorded geometry allows independent whole-edge recomputation; the denser accepted
path contains parameter/clearance/containment summaries, not full skin arrays.
Those summaries are not an independent continuous-sweep proof. Engine runs remain
serial. Final run results belong in the active consolidation guide.

## All-ten-digit preparation extension — 2026-09-27

`bake_character_hand_anatomy.gd` now uses all `PlayerDigitHingeRules.DIGIT_IDS`
on both sides. Its preparation revision is
`rest_all_digits_surface_measurements_v1`; the Resource schema remains
`character_hand_anatomy_v1`. The source capture rejects missing or duplicate
hand/digit rule packets before expensive measurements run. Skin sampling,
calibrated zero, authored ranges, source weights, coordinate frames and the
measurement algorithms are unchanged. No measured value is filled from the old
capsule dimensions when a ray is missing.

The same existing exporter writes a new signature-named Resource under
`prepared_characters/josie/`. It still refuses to replace an existing file and
reuses an existing matching definition before expensive baking. The added
selected bone samples, digit rule packets and changed recipe revision/code are
part of the source signature. Historical proof resources and captures keep
their original signatures. A historical coherent capture must not be silently
relabelled: using it with the new definition requires explicit evidence that
the reference skin, character identity and existing digit definitions agree,
or a genuinely new capture.

For this revision, `character_hand_anatomy_store.gd` requires exactly Thumb,
Index, Middle, Ring and Pinky on each hand. Its old-revision loading behavior is
retained. `verify_character_hand_anatomy_store.gd` understands both scopes and
checks authored rules, named origins, skin-derived lengths and complete
measurement records. A full preparation has 30 recorded outline poses and 360
cross-section skin rays. The verifier removes each of the ten digit entries in
turn to ensure partial data cannot pass as a full hand.

`verify_character_anatomy_signature.gd` checks ten source rule packets and adds
independent Index/Ring/Pinky rule invalidation checks on both hands. Run the
exporter first, then the store verifier with
`THE_WILL_ANATOMY_RESOURCE_PATH` set to its reported new path, the signature
verifier, and the exporter again to check matching-definition reuse. Engine
runs remain serial. Actual execution results belong in the active work record;
this section describes the preparation contract, not a passed runtime grip.

The Resource is associated with Josie through character ID, source scene,
signature and its character-specific path. Character-creation/save integration,
full-hand envelope-radius selection, and altered anatomical limits are outside
this extension. The existing diagnostic radius is unchanged. This code continues
to use Godot's original mesh arrays, named Skin bind poses and Skeleton3D rest
transforms; relevant official references were rechecked for this extension:
[Mesh](https://docs.godotengine.org/en/latest/classes/class_mesh.html),
[Skin](https://docs.godotengine.org/en/latest/classes/class_skin.html),
[Skeleton3D](https://docs.godotengine.org/en/latest/classes/class_skeleton3d.html),
[Resource](https://docs.godotengine.org/en/latest/classes/class_resource.html).

### Known transverse-ray limitation and current consumption

The saved cross-section rays are nearest positive **whole-mesh** intersections,
not qualified measurements of local finger thickness. The 2026-09-27 source
audit found eight of the 360 rays landing on triangles with no contribution
from the selected digit: Index S1 at 20% and Middle S1 at 20% hit Pinky skin;
Pinky S1 at 20% and 50% hit Index/palm-region skin, on both hands. The Middle
case already exists in the historical four-entry resource. Other proximal
rays can cross web/palm tissue. Positive digit weights alone also do not certify
an anatomical boundary. These ray distances must not be used as finger radii
or thickness without explicit upstream source qualification; current stored
data are retained as measured intersections, not corrected or silently replaced.

The current prepared-skin candidate and contact observer do not use these
transverse rays as collision dimensions. They use the original weighted skin,
authored joint rules, two measured interjoint lengths, and the separately
verified terminal axial extent. An independent read-only reconstruction of all
ten calibrated-zero skins and nearest terminal rays found every terminal hit
on a triangle wholly influenced by that digit's own S3. Stored lengths agreed
within 0.2245 micrometers under decimal/double versus Godot Float32 arithmetic.
The terminal offsets and summed reach used by the current solver therefore
remain supported by source evidence. This is not a claim that all prepared
cross-section measurements are qualified anatomy.

Exact resource hash, method, ten terminal hits, eight transverse mismatches and
the consumer trace are recorded in
[the source audit](../../../../test_artifacts/saved_digit_measurement_source_audit_2026-09-27.json).
The all-five candidate check is
[the 08:34:38 verification report](../../../../test_artifacts/verify_prepared_hand_candidate_pose_2026-09-27T08-34-38.json).
Its explicit selection mode compares simultaneous different joint angles
against both the complete skin evaluator and independent original-array
reconstruction, checks isolated Index/Ring/Pinky changes, and verifies input
immutability. No anatomy rebake or rule changes were made for this audit.
