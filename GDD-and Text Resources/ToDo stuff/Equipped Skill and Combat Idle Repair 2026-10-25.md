# Equipped skill and Combat Idle repair - 2026-10-25

## Scope and requested reproduction

User requests fixing equipped Skill 1 not playing, the saved in-hand Combat Idle
not applying, and an unintended offhand reaching for the handle. Reproduce in
the normal game with the currently equipped weapon: press 1, then hold W for
four seconds in open space. Inspect visuals and runtime state together.

This is separate from the earlier Skill Crafter reach rejection. The user
confirmed that correcting the authored position resolved their editor F blocker.
Do not extend this pass into anatomy, new body controls, grip optimization,
future wearer scaling, or a state-machine redesign. No Git action is requested.

## Fresh baseline

`godot_runs/equipped_live_20261025/baseline01/` and `baseline02/` load the normal
project main scene, leave physics/locomotion/idle active, and inject physical
key 1 and W events through `Input.parse_input_event`. Current user files are
copied to isolated user data before launch. No player teleport, direct skill
activation, rig preparation or generated clip injection occurs. Screenshots,
final skeleton observations and compact runtime state are preserved.

Source weapon: `Broken_Balde_v1`, WIP `player_wip_1792291462.519_14`.
Current library SHA256:
`1620c9e815d93901d03b167e923cec84f991c2721d8424b0aec5dc153da90127`.
Skill 1 has five visible nodes and a saved replay. Combat Idle has one node,
right primary hand, explicit one-hand state, saved support_enabled=false,
and a current saved replay. One-frame idle playback is supported in code.

Baseline01 walked 21.8467 m over 4003 ms. Both baselines reproduced:

- Skill resolution and saved replay readiness succeed. Entry fails at frame 1
  (0.016667 s) with `requested_hand_scale_differs_from_rig`.
- Saved Combat Idle is copied and available, but application fails with
  `saved_grip_outside_handle_end_bounds`.
- The controller incorrectly reports idle applied because the failure result
  is nonempty. Actual `solved_replay_applied` is false.
- Left support is active and targets `SupportGripAnchor` / `SecondaryGripGuide`,
  despite the saved explicit one-hand state.

## Causes and planned correction

1. Entry independently interpolates weapon scale and inverse hand-relative
   attachment scale. Their product temporarily changes the requested hand size.
   Correct the shared attachment composition; preserve exact endpoints and
   the arm resolver's scale rejection. This is representation math, not a new
   character/weapon scaling feature.
2. Combat Idle's primary anchor projects to ratio 0.777568146227412; current
   maximum is 0.777566670549279 on a 0.212492898106575 m handle. The difference
   is approximately 0.0003136 mm. Live hand measurement/transform roundoff and
   saved precision are enough to exceed the validator's private 1e-6 ratio
   epsilon. The user then explicitly allowed up to **0.05 mm** of boundary
   tolerance. Convert that physical distance to a ratio using the handle's
   resolved length; preserve the footprint/padding and reject real excess.
3. Generic equipment guidance interprets an empty opposite slot as support
   intent, if the handle is eligible. Stop this automatic request; authored
   action/idle one-hand/two-hand state owns support engagement.
4. Report a rejected idle frame as rejected, retaining its diagnostic message.

Production owners selected before editing:

- `core/resolvers/combat_prepared_attachment_resolver.gd`
- `runtime/combat/combat_animation_station_preview_presenter.gd`
- `runtime/player/player_equipped_item_presenter.gd`
- `runtime/player/player_runtime_skill_playback_presenter.gd`

Focused verifier changes may accompany these owners. Official Godot 4.7
[Transform3D](https://docs.godotengine.org/en/4.7/classes/class_transform3d.html)
and [Node3D](https://docs.godotengine.org/en/4.7/classes/class_node3d.html)
documentation was consulted for interpolation, affine composition and inherited
scale. Saved authoring data is not to be rewritten to conceal runtime faults.

## Implemented and freshly verified

The four production corrections above are implemented. Entry scale composition
uses the actual sampled weapon basis and preserves the captured physical hand
scale. The existing arm scale guard remains active. Replay boundary allowance
is 0.00005 m divided by resolved handle length, with a separate 1e-7 ratio
roundoff allowance for inclusive floating-point boundary comparisons. Generic
equipment no longer treats an empty offhand as support intent. A rejected idle
frame reports failure instead of claiming success from a nonempty dictionary.

Focused fresh Godot 4.7 checks:

- `verify_combat_prepared_pose_track.gd`: 60 checks pass.
- `verify_equipped_support_guidance.gd`: 31 checks pass. Both primary hands,
  explicit support, one-hand clearing, ineligible support, dual equipment and
  stow clearing are exercised.
- `verify_solved_replay_end_bounds_scale.gd`: 537 checks pass. Both ends,
  multiple lengths/scales, 0.049/0.050 mm acceptance and 0.051 mm rejection.
- Entry verifier parses. `entry_fixed01/report.json` confirms activation,
  60 Hz, 160 ms entry, unchanged saved body channels, unchanged timestamps
  apart from entry offset, and zero new grip acquisitions. Scale guards pass,
  including rejection of unsupported bases and a genuine hand-size mismatch.
  Independent entry attachment audit passes all ten prefix frames: maximum
  positional error 0.03621 mm, angular error 0.000001085 radians.
- That entry verifier's **overall result is not a full pass**: its isolated
  already-drawn cold source at time zero is rejected by the end-bound check.
  The initial mounted scale is 0.764165 versus saved playback scale 1.0;
  source anchor ratio 0.22243 is below scaled minimum 0.29108. The runtime gate
  also applies to transient bridge frames, so this is a genuinely omitted
  source frame, not just a verifier assertion problem. Authored start,
  middle and terminal samples pass. Do not hide this with broader tolerances.
  This remaining cold-source sample issue was not changed in this pass.

Normal main-scene `fixed01/results/report.json` and screenshots confirm physical
key 1 starts and completes current Skill 1; sampled skill frames actually apply
the saved replay; saved Combat Idle applies after completion; left support and
guidance remain off with no target at every recorded checkpoint. Console error
log is empty. The user watched/tested and reported **"works"**.

W was held 4002 ms. Actual displacement was 6.7197 m: movement stopped near the
Forge bench by two seconds while W remained held. Thus this run proves skill
playback during walking and the return to saved idle, but **not four uninterrupted
seconds of movement in open space**. Earlier baseline walked 21.8467 m. No
teleport or physics suppression was used. This limitation is retained rather
than claiming a stronger movement test.

All eight real user-data source files match the pre-run manifest afterward.
No authored saves were changed. `git diff --check` passes (line-ending notice
only). No Git index/history/push operation was performed.

## Remaining limits

The normal screenshots and runtime checkpoints do not certify every frame's
hand contact or anatomical correctness. The separate cold-source time-zero
boundary issue above remains recorded for focused follow-up if inconvenient.
No broad anatomy, reverse-grip, or authored two-hand live runtime pass was run;
the support ownership verifier covers explicit support calls, not a full authored
two-hand animation. Current user confirmation is of the requested equipped fix.
