# Skill Crafter free-hand marker attachment — 2026-11-08

## Scope

User reports that the offhand hand controls can separate from the physical hand
and travel far away. Keep the independent arm controls attached to the hand
actually displayed, including at movement limits and after release. Preserve the
existing arm solver, grip solver, opposite-arm isolation and weapon controls.

## Cause confirmed in current code

- UI hand-proxy edits store the requested endpoint positions.
- `PlayerHumanoidRig.apply_authoring_independent_arm_frame_now` converts those
  requests into a Hand frame after body projection and arm reach clamping.
- The presenter previously applied `accepted_hand * inverse(requested_hand)`
  to the original endpoints. Here `requested_hand` was already projected, so
  that correction omitted the earlier displacement. Authored endpoints could
  remain far outside the position actually reached by the hand.
- Drawing and drag seeding preferred those authored targets. Rejected edits
  that retained the previous pose also returned before refreshing the markers.
- Elbow edits updated their roll but did not reconcile existing hand-proxy
  endpoints with the resulting hand position.

## Implementation

`combat_animation_station_preview_presenter.gd`:

- Drawing, picking/drag seeding now share physical hand-derived control points.
  Solver requests remain separate; there is no new reach or tolerance rule.
- After an independent hand edit, or an elbow edit with an already authored
  hand proxy, accepted/retained positions are written from actual bone geometry.
- Uses the existing `CC_Base_{L,R}_Hand`, `Index1`, `Pinky1`, hand alignment
  anchor and trajectory-root conversion. Stored endpoint origins remain
  `TrajectoryAuthoringOrigin`; world values are not written into local fields.
- Gripping-hand edits do not create free-hand proxy data.

`combat_animation_station_ui.gd`:

- Retained-pose failures refresh the reconciled control visuals.
- Numeric independent arm edits refresh fields after actual-position readback.

No changes to acquisition, anatomy, motion allocation, native code, R/F/Save,
movement-speed settings or the prior Pommel trailing behavior.

## Verification

- Godot 4.7 parser checks pass for the presenter and the new rendered verifier.
- Rendered Godot 4.7 check passed for both free arms: 22 snapshots across
  translation, rotation, oversized requests, reversal, release and elbow edit.
  The two free hands actually travelled up to 0.213 m and 0.170 m respectively.
- Both drawn marker endpoints and stored endpoints matched the physical hand
  segment in every sample (reported mismatch zero). An independent check of
  the segment centre against Hand/Index1/Pinky1 bones differed by at most
  0.0000000334 m. A deliberately detached 1.346 m authored offset was repaired
  by the ordinary elbow edit on each side.
- Weapon transform stayed unchanged. Opposite-arm differences stayed below
  0.000000329 m / 0.0000424 degrees (floating-point noise).
- Both fully accepted and scaled/partially accepted solver results occurred.
  The retained-previous-pose failure refresh was code-reviewed, but this run
  did not naturally produce that branch. No claim of a new solver speedup or
  comprehensive anatomical validation; this change only reconciles controls.
- Both captured end views were inspected. No engine/script errors; existing
  source skills were preserved. The game exited; only the existing editor
  remains. `git diff --check` passes for the production files.
- Verifier: `tools/verify_live_hand_proxy_attachment.gd`. Existing isolated
  saved-weapon harness, actual marker press, queued production drag/release,
  left and right free hands, translation/rotation/overreach/reversal, old
  detached coordinates followed by an elbow edit. Compares rendered and stored
  endpoints with physical bones, and checks weapon/opposite-arm preservation.
- Evidence destination: `godot_runs/hand_proxy_attachment_20261108/`.
  `live/manifest.json` has two completed cases, 11 `requests` each. The inherited
  harness's top-level `sample_count` is unused/zero for this focused verifier.

This is a narrow follow-up to the independent-arm controls. Earlier Pommel work
and verification remain in `Skill Crafter Pommel Position Authority 2026-11-08.md`.
No Git/index operations are authorized by this task.
