# Character hand preparation tool

This tool prepares character anatomy once, saves it as a character-linked
Resource, and reuses that Resource while its source data and preparation recipe
match. It does not need a weapon, saved forge library or Skill Crafter session.

The current adapter prepares **Josie's Middle and Thumb on both hands**. This is
the agreed two-digit proof. The resulting data is measured anatomy, not a
validated contact envelope or completed grip. The remaining digits and live
grip integration are later steps.

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
