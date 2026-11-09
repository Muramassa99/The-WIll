# Skill Crafter empty-hand finger controls - 2026-11-08

## User scope and decisions

- Empty offhand and both empty hands in Unarmed can pose index, middle, ring
  and pinky independently. No thumb control in this first slice.
- Mathematical joint curves replace the proposed invisible camshaft. No
  helper collision geometry and no grip acquisition for an empty hand.
- Each selected finger has a 180-degree controller arc around the actual
  pinky-index axis. This is controller travel, not a new 180-degree joint limit.
- Space order: index, middle, ring, pinky immediately before each empty hand's
  existing movement control. Shift+Space reverses the same list.
- Finger edits must preserve the hand, arm, other fingers and held weapon.
- Store independent values with each motion node; record/tween the resulting
  finger bone poses through the existing prepared-pose and playback path.
- A hand holding an item remains owned by the existing grip system. Never
  run this pose overlay over acquired or acquiring weapon grips.

## Savepoint and ownership

Prior work pushed before this feature: `8426443d`,
`Skill Crafter motion engine and control refinements`, branch
`recovery/stable-92b8a24-chat14`.

Unarmed movement-engine consolidation, dual wield, thumb gestures, gesture
effects, buff triggers and preset libraries remain future scope. This addition
does not change grip solving, arm anatomy, motion allocation or weapon controls.

## Implementation contract

- Motion node: sparse per-side `*_hand_finger_curl_degrees` dictionaries,
  four named digits, finite values clamped to 0-180. Missing key means unauthored;
  explicit zero means authored open. Existing empty-data fingerprints stay valid.
- Runtime finger helper: fixed Idle parent-local reference rotations and the
  existing `player_digit_hinge_rules.gd` named bone axes, limits and root chain.
  Initial mapping is linear progress from each existing open bound to closed
  bound. This deliberately reuses existing ranges; manual visual tuning of the
  curl profile may follow. No changes to those shared gripping limits.
- Rig: empty-hand authoring overlay writes only requested digit rotations after
  authoring modifiers. It yields to acquired grips and prepared playback poses.
- Presenter: selected finger cube and semicircle derive from current named Hand,
  Index1 and Pinky1 bones through Skeleton3D/global transforms. These world points
  are transient display data, never saved as originless authored positions.
- UI: visible-mesh picking and captured mouse drag use the existing marker input
  path and drag-speed cap. Finger edits avoid body/grip solving. Normal R, node
  navigation, F and Save capture the already displayed finger bone rotations.

### Narrow Unarmed recording repair discovered during integration

The fresh Unarmed check could edit and retain all eight curls, but recording
returned `prepared_pose_capture_unavailable`. The existing capture passed the
complete real-weapon anchor list to the virtual Unarmed helper, which does not
contain those anchors. It also attempted to read physical handle slice/seat data.

- For Unarmed only, capture now uses the existing actual-anchor discovery helper.
- `combat_prepared_pose_capture.gd` records Unarmed with `attachment_required=false`,
  using the existing body-only prepared-pose policy. Named bones, parent origins,
  transforms and anatomy data remain recorded and validated.
- Unarmed handle-path/seat metadata explicitly reports `unarmed_no_handle`.
- Real-weapon anchor requirements, acquisition and contact rules are unchanged.

The rig also recognizes matching-slot `hand_authoring_slot_proxy` as an empty
hand's positioning helper, alongside the main `unarmed_hand_proxy`. Actual planar
grip ownership still takes precedence. Otherwise moving a free hand could wrongly
make its new finger control appear occupied.

## Reference

Godot 4.7 [Skeleton3D](https://docs.godotengine.org/en/4.7/classes/class_skeleton3d.html)
and [Quaternion](https://docs.godotengine.org/en/4.7/classes/class_quaternion.html):
bone-global transforms are relative to the skeleton; pose rotations are relative
to the parent bone. Use normalized quaternions and the existing replay interpolation.

## Verification status

- Godot 4.7 parse checks pass. Model verifier: **28 checks passed**, including
  old-signature compatibility, normalization, independent duplication and real
  ResourceSaver/ResourceLoader round trip.
- Control maths: **68 checks passed**, including camera-facing and edge-on arcs,
  endpoint overshoot with immediate reversal, transformed skeleton origins and
  forward/backward focus order.
- Rendered real-weapon station: both free-hand sides passed **20 numeric samples
  and 8 arc samples per hand**, plus occupied-hand rejection and prepared-pose
  capture/resource round trip. Unrelated bone positions/rotations/scales and weapon
  transform reported zero change. Joint rotation error stayed below 0.000004 degrees.
- The measured synchronous drag-handler calls were approximately **2.0-2.24 ms**
  in these runs; this excludes frame waiting, OS input latency and broader editor
  work. Numeric committed edits additionally refresh fields/summary. Finger drag
  samples use the existing lookup scope and redraw only their arc/rod/cube.
- Fresh Unarmed rendered check: **146 checks passed**, both hands, each finger,
  unchanged other bones, hand-helper ownership after hand editing, ordinary editor
  refresh and all 24 recorded phalange rotations. Final headless confirmation after
  metadata cleanup also passes all 146 checks, exits 0 and logs no engine errors.
- Initial live-test failures were verifier issues: large synthetic pointer jumps
  were throttled by the normal drag-speed cap; stored Vector4 rotations needed
  decoding; physical/OS mouse input interfered with deterministic arc samples.
  Final arc checks use real GUI pick/release, then deterministic production handler
  samples with physical input excluded. They do not certify OS pointer latency.
- Visual closeups of full curl were inspected. Initial curl progression is the
  existing full hinge-range mapping, not a newly calibrated fist or thumb pose.
- No full equipped combat or complete F/Save playback sweep was rerun. The named
  finger pose capture/reload contract is checked; existing replay reads those bones.

Evidence under `godot_runs/empty_hand_fingers_20261108/`:

- `math/report.json` (math verifier's output files).
- `live_corrected/manifest.json`: main R / empty L case passes; subsequent main L
  arc was affected by test input interference, retained as historical evidence.
- `right_arc_diagnostic/manifest.json`: main L / empty R case passes with isolated
  input. The inherited top-level `sample_count` is unused; per-case requests/checks
  contain the meaningful results.
- `unarmed_final/report.json`: all 146 checks pass; logs still exposed missing
  Unarmed handle-seat metadata, repaired after that run.
- `unarmed_clean/report.json` and `unarmed_clean.log`: final 146/146 pass and clean
  engine log after the Unarmed handle-seat metadata correction.

Verifiers: `verify_empty_hand_finger_state.gd`,
`verify_empty_hand_finger_control_math.gd`, `verify_live_empty_hand_finger_controls.gd`,
`verify_unarmed_empty_hand_fingers.gd`. Test libraries and node resources are isolated;
existing player weapon saves were not replaced. Feature changes remain local after
the pre-feature Git savepoint above.
