# Middle and Thumb planar grip proof - 2026-09-15

## Current status and boundary

Latest continuation: [Prepared skin contact solver proof](<Prepared Skin Contact Solver Proof 2026-09-15.md>).
The solver now consumes saved anatomy and evaluates actual deforming skin.
Its first bounded real-weapon searches did not establish a valid grip; that
newer note records the placement/baseline findings, verification and timings.

Later on September 15, the user confirmed that expensive character preparation
must export reusable data tied to the character. The standalone tool and saved
Resource now exist; see [Character hand preparation tool](<../../The Will- main folder/the-will-gamefiles/tools/grip_plane_proof/CHARACTER_HAND_PREPARATION.md>).
That newer workflow starts from an isolated character rest pose and does not
depend on the weapon/editor captures used below. It supersedes the earlier
prototype fingerprint limitations for this preparation output. Contact-envelope
validation and live grip integration still remain.

The requested later expansion and lifecycle integration are tracked in
[Character creation/save: full-hand preparation TODO](<Character Creation Full Hand Preparation TODO 2026-09-15.md>).

This is a tool-only preparation and solver experiment. It has not replaced the
live grip solver, changed hand placement, or altered the accepted Wrist-to-Tip
Roll. It has not established a valid grip on the real test weapon yet.

Continue from [Skill Crafter Performance Recovery 2026-09-15.md](<Skill Crafter Performance Recovery 2026-09-15.md>).
The current branch is `recovery/stable-92b8a24-chat14`, HEAD
`92b8a24fcac64e38c2565e56fec6878e22e55e26`. The historical recovery backup is
`d798cc016ba8c150c6b7ca263f3da608a7455a7f` on `godot-4.7-plus-development`.
No new commit or push was authorized/performed for this proof.

## User's intended architecture

- Prepare anatomy from the actual character model before grip consumers need it.
  Keep model-associated lengths, skin envelopes, named planes, joint mapping,
  ranges, and eventually palm contact data. Changing the model must invalidate
  or regenerate that data.
- Prove one generic three-joint 2D digit solver using Middle and diagonal Thumb
  first; remaining digits follow after the proof. Calculations are independent;
  this does not require concurrent writes to the live skeleton.
- Slice the actual finished held object in the positioned digit's motion plane.
  Bound the search by measured reach and skin thickness. Nearby blade, guard or
  other object geometry may support contact; this rule applies to every digit.
  Handle selection remains the authority for hand placement.
- Preserve accuracy and responsiveness together. Character preparation should
  be reusable. Measure slicing, angle search and final validation separately,
  and measure the complete acquisition when integrated. A short failed solve
  does not establish good performance.
- The eventual solver consumes anatomy and geometry, without melee archetype
  assumptions. F generation, saving, two-hand behavior and broad IK changes are
  outside this proof.

## Inputs and named coordinates

Diagnostic captures preserve one coherent pre-finger-solve hand/object placement:

- Right: `test_artifacts/grip_solver_inputs_hand_right_2026-09-15T04-36-47.bin`
- Left: `test_artifacts/grip_solver_inputs_hand_left_2026-09-15T04-36-57.bin`
- Separate character source:
  `test_artifacts/character_contact_samples_2026-09-15T04-48-06.bin`

Do not use the old `character_skin` field embedded in those grip captures; it
contains the rejected dominant-weight extraction. Use the separate source above.

`object_contact.surface` contains 10,838 triangles from the exact equipped Forge
V2 editable mesh, including Handle and other finished geometry. The original
Handle-only prepared surface contains 8,540 triangles. Mesh vertices are already
positioned with the equipped mesh's global transform: do not apply cell scaling
or grip-center subtraction a second time.

The captured machine transform gives the numerical `RL_BoneRoot` frame.
Character reference vertices have `CharacterSkinReferenceMeshOrigin`; skin bind
frames and model rest frames retain named bone records. Prepared planes and the
hand-rebased skin mesh register their own edges back to the same machine root.
World-space values are presentations of those recorded transforms, not separate
authored origins. Reference data and proof copies do not mutate live resources.

## What preparation has established

`tools/grip_plane_proof/prepare_digit_anatomy.gd` prepares joint 2/3 neutral
rotations using the existing collinear Thumb operation. It preserves the first
joint, declared hinge axes and signed limits. Sampled departures from the plane:

| Digit | Right | Left |
| --- | ---: | ---: |
| Middle | 0.00462 mm | 0.00384 mm |
| Thumb | 0.03934 mm | 0.03325 mm |

These are sampled values, not a proof over every joint-angle combination.

Two skin-extraction shortcuts were rejected:

1. Strongest bone weight does not identify all anatomical sections. Thumb1 has
   no strongest-weight vertices in this model, but has positive influence.
2. All vertices influenced by a bone do not form that bone's outer skin shell.
   Small weights extend into neighboring tissue; taking their maximum distance
   creates false radius measurements.

`capture_model_skin_samples.gd` therefore also captures the actual reference
mesh, indices, weights and bind data. `measure_digit_skin_surface.gd` reconstructs
the skinned mesh with the supplied three-joint pose and measures nearest actual
triangle hits. It retains missing rays rather than supplying guessed dimensions.
Other bones use the hand-rebased rest pose in this experiment.

## Engine comparison

`verify_character_skin_geometry.gd` applies the captured local position, scale
and output rotation to a disposable real rig, then compares 15,992 vertices
against Godot's skeleton-pose bake. It tests Middle/Thumb, zero/bent, both hands.
All eight cases passed: largest adjusted error was 0.001442 mm on the right and
0.001175 mm on the left. Logs: `godot_runs/the_will_2026-09-15_04-59-59.log` and
`...05-00-17.log`.

The comparison explicitly accounts for a Godot implementation difference:

- The rendering skinning shader uses the weighted transform without normalizing
  weights. Apply the mesh's world translation once, after the blend.
- The CPU skeleton-pose bake additionally preserves a rest-vertex residual when
  weights do not sum to one. The expected bake-minus-render difference is
  `(1 - weight_sum) * mesh_to_world.basis * reference_vertex`.

Current imported weight sums range from 0.999954186 to 1.000000015. This difference
must not be hidden by normalizing weights or widening the contact threshold.
The verifier also checks joint-transform parity. Restoring imported rest
positions instead of the captured animated positions caused an earlier test
mismatch; that was corrected in the disposable test setup.

Sources were checked at the installed engine revision `5b4e0cb0f`:
[GLES3 skinning shader](https://github.com/godotengine/godot/blob/5b4e0cb0f/drivers/gles3/shaders/skeleton.glsl),
[MeshInstance3D bake implementation](https://github.com/godotengine/godot/blob/5b4e0cb0f/scene/3d/mesh_instance_3d.cpp).
[Godot 4.7 MeshInstance3D documentation](https://docs.godotengine.org/en/4.7/classes/class_meshinstance3d.html)
warns that mesh baking stalls rendering for data retrieval and ignores blend
shapes. Keep this comparison in preparation/testing, not every closure iteration.

The comparison required a graphics-backed engine; the headless dummy renderer
did not provide the registered skin for baking. The disposable window was hidden.
OpenGL shader-initialization errors occurred under the sandbox even though the
CPU bake returned matching meshes. This was not a framebuffer verification.
Current captured blend-shape values are zero; changed morphs are not yet proven.

## Real weapon result and the next preparation problem

The skin measurement casts 37 rays per digit: one axial terminal ray and four
cardinal rays at three positions along each of the three sections. All required
rays hit in both current hand setups.

The proposed *diagnostic centered-capsule approximation* takes the maximum
cardinal distance for each section. It is unsuitable at the digit/palm junction:

- Right Middle, 20% along section 1: normal-direction hits are 41.44/60.71 mm;
  in-plane hits are 16.65/20.69 mm. At 50%, normal hits drop to 11.85/12.63 mm.
- Right Thumb, section 1: one in-plane side extends 56.77-58.86 mm into shared
  palm tissue; the other side measures 19.38-21.11 mm.

Those actual surface distances cannot be converted into one uniform centered
finger radius. The ray's first surface hit is not an anatomical partition of
shared palm tissue, nor do four rays certify an ellipse or whole skin envelope.
The resulting round proxy blocks the fixed origin before any angle evaluations.
This does not prove the real hand cannot grip the object.

Current raw proof outputs:

- `test_artifacts/two_digit_contact_proof_hand_right_2026-09-15T05-10-54.json`
- `test_artifacts/two_digit_contact_proof_hand_left_2026-09-15T05-10-56.json`

Both explicitly report `actual_skin_contact_verified=false`; no candidate was
applied. All four preserve `blocked_fixed_origin` with zero evaluations; there
is no claim of exhausting the search budget. The preceding 05:02/05:04 captures
had a misleading public headline, with the true reason under `boundary_status`.

[Visual measurement review](../../test_artifacts/two_digit_skin_preparation_review.html)
and [standalone SVG](../../test_artifacts/two_digit_skin_preparation_review.svg)
show all four cases on identical millimeter axes. Orange/purple paths connect
actual in-plane ray hits; they are not fitted or certified skin boundaries.
The rejected centered capsules are gray. The PNG render was visually inspected.

The next useful step is preserving the changing, offset skin outline and the
shared palm/deforming tissue relationship in model preparation. Do not shrink
the measured radius, ignore a ray, loosen penetration limits, or move the hand
just to obtain a passing capsule test. Validate an eventual simplified envelope
against the actual skinned surface before trusting its final joint angles.

## Timing and solver limits

Measured character preparation was 143.6-160.7 ms per digit in these runs,
including 17.1-18.0 ms to reconstruct the complete reference mesh. This is a
prototype preparation cost, intended to be reused; no runtime anatomy cache or
persistent character resource is integrated yet.
The prototype fingerprint is not a complete production cache key: before such
a resource is used, include topology/index buffers and all relevant root/hand
rest-frame data as well as vertices, weights, binds and morph state.

Actual object slicing cost 13.48-16.46 ms per digit. It tested all 10,838 triangle
AABBs and retained local candidates, emitting 96-141 actual intersection edges.
It currently does not traverse the existing BVH. The full object remains intact
for final inside/outside validation; no fake edge closes a cropped contour.

The actual candidates were rejected before search, taking about 0.11-0.14 ms.
Do not present those rejection times as a successful grip or whole-hand latency.

The generic diagnostic search visits a bounded coarse grid followed by joint
neighborhood refinement (normally 1,591 evaluations, default budget 1,700). It
can find synthetic contacts but is not exhaustive. A cropped or incomplete
contour exposes provisional boundary clearance only, never certified safety.
Full 3D capsule checks are a further provisional test; actual skin, palm and
inter-digit validation still remain.

An exact optimization now implemented in the diagnostic solver is per-solve memoization
of identical angle prefixes: section 1 depends on angle 1, section 2 on angles
1/2. It reuses repeated section queries while preserving geometry, candidate
order, evaluation budget and ranking. Keys are the exact unquantized input
floats, and the cache is discarded after each solve. It changes no live solver.

In one comparison run (`godot_runs/the_will_2026-09-15_05-10-36.log`), the
64-edge circle took 656.263 ms without caching and 255.170 ms with caching,
about 2.57 times faster. The entire selected result was byte-identical after
excluding only timing/cache counters: angles, measurements, score, status and
all 1,591 candidate visits stayed the same. There were 3,054 exact cache hits
and 1,719 actual section queries instead of 4,773 queries. This remains too
slow for the intended live whole-hand interaction and is only a synthetic
candidate-search measurement, not complete acquisition or a valid real grip.

## Verification and continuation

Tool sources are under `The Will- main folder/the-will-gamefiles/tools/grip_plane_proof/`.
Use the supported launcher with `-Headless` for numerical proofs and
`-RenderingMethod gl_compatibility -RenderingDriver opengl3` for the bone/mesh bake
comparison. Set `THE_WILL_GRIP_CAPTURE_PATH` and
`THE_WILL_CHARACTER_SAMPLES_PATH` to the explicit files above.

The reachable-slice verifier passed 70 checks. The planar solver verifier passed
18 checks in `godot_runs/the_will_2026-09-15_05-08-08.log`, including incomplete
retained-hole handling, conservative public safety labels, and early-return
status/timing. Its rectangle took 105.014 ms (4 edges), and circle 683.964 ms
(64 edges), each with 1,591 evaluations. These are successful synthetic capsule
contacts, not real skin contacts, and the circle latency is unsuitable for live
acquisition. The later cached/uncached comparison passed all 21 verifier checks,
including complete result equivalence and exact query-count accounting. Final
real right/left runs at 05:10:53 and 05:10:55 completed without script errors and
still correctly rejected the unsuitable centered proxy before search.

Production tracked diff remains the same seven files, 370 insertions/22 deletions
from the accepted Roll and previous performance work. Real WIP library SHA256
remains `C59A09D3B33D321F482F2C379DF5FD299246544F2229E5A8B12970F769500E0E`.
No user's game was stopped, no library was replaced, and no Git push occurred.
