# Broken_Glave_v1 Skill 1 offhand audit — 2026-11-09

## Scope and source

User requests examination, not a movement/grip rewrite. Examine full Skill 1,
especially the last two nodes. Symptoms confirmed by user: unexpected arm/hand
orientation and movement fighting back/sticking. User suggests failed/illegal
grip may be the upstream problem rather than motion itself.

Actual saved `Broken_Glave_v1`, WIP `player_wip_1794179018.538_16`, Skill Slot 1.
Library: `user://forge/player_wip_library_state.tres`.
SHA256 before and after both runs:
`b9177c144a40ac0ea9e8423e75e70997642cb0626a19d8b26b01b5834f4048b1`.
No saved player data, production code, grip rules or anatomical limits changed.

Read current Agent law, latest SPS `SPS_2026_11_08_20-59.md`, its empty-hand finger
note, current Primary Handle Default note, Glave Opening Stall note, and combat
coordinate law. Earlier opening-stall note describes an older two-node save;
this audit uses the user's newly authored four-visible-node skill.

## Saved node evidence

| Visible node | Hands | Primary normalized seat | Support normalized seat | Incoming duration |
| --- | --- | --- | --- | --- |
| 1 | Right primary, one hand | 0.50 | 0.00, unused | 240 ms |
| 2 | Right primary, one hand | 0.50 | 0.00, unused | 200 ms |
| 3 | Right primary, two hands | 0.45 | 0.50 | 360 ms |
| 4 | Right primary, two hands | 0.45 | 0.50 | 280 ms |

All four use Body Support 0.9. Nodes 3/4 have right upper-arm roll approximately
-110.178 degrees. Neither has free-hand proxy or empty-hand finger edits.

- Nodes 1/2 contain durable `acquired_grip` packets for the right hand.
- Nodes 3/4 contain `acquired_grip={}` and warnings
  `prepared_pose_grip_pending`, `prepared_pose_grip_not_applied` (left),
  `prepared_pose_grip_not_bound` (left).
- Their body and weapon snapshots exist, but the complete two-hand relationship
  was not saved as an acquired packet. `export_authoring_grip` is all-or-nothing
  over requested hands; an unfinished support hand prevents full packet export.
- The .45/.50 seats are about 17.53 cm apart on this 3.505 m Handle. Both are well
  inside physical end bounds. Signed display conversion does not cause this.
- `grip_accepted=false` alone is not useful evidence: current surface diagnostics
  deliberately distinguish an applied pose/binding from full certification.

## Fresh rendered observations

Diagnostic: `tools/diagnose_glave_skill_one_offhand.gd`, extending the existing
read-only Glave opening diagnostic. Real WIP, live Skill Crafter UI handlers,
source hash check and `verification_skip_persistence=true`; no source file copy
or replacement. Only user editor remained running after tests.

### Playback-first observation

Evidence: `godot_runs/glave_skill1_offhand_20261109/`.

- Open saved selected Node 4, observe acquisition, press F once, then select 1–4.
- F actually played and completed. The initial opening observation expired while
  primary was still solving, so it is not proof of a completed initial grip.
- Nodes 1/2 restored primary binding. Subsequent Nodes 3/4 acquired both bindings.
  Node 3 primary/support solve totals approximately 2.26/4.72 seconds;
  Node 4 approximately 2.42/5.09 seconds.
- Node 3's resulting offhand pinky–index line was approximately **25.13 degrees
  away from parallel** to the Handle axis; Node 4 was approximately 0.004 degrees.
  These were calculated from actual bone/weapon frames, not debug overlays.
- Node 3 visibly raises the offhand elbow by the head. Node 4 has a different arm
  configuration. An applied finger pose does not establish correct whole-arm
  alignment or certify every required contact.
- F/selection can update in-memory endpoint captures. This first run therefore
  does not prove the original saved endpoints reproduce identically on reopening.

### Clean sequential observation with movement probes

Evidence: `godot_runs/glave_skill1_offhand_motion_20261109/`.

- Fresh process, select Node 1 initially in the loaded in-memory draft. No F;
  navigate 1 → 2 → 3 → 4 through ordinary UI selection handlers.
- Nodes 1/2 restore primary grip and pass forearm/hand indexing validation.
- Node 3 primary acquisition fails `source_pose_changed_during_acquisition`;
  nested reason **`weapon_in_hand_changed_during_acquisition`**.
- Offhand then fails **`primary_grip_not_ready`**. Node 4 inherits the same
  unresolved request because its .45/.50 relationship keys are unchanged.
- Node 3 offhand reports `wrist_motion_range`, desired-versus-allowed orientation
  residual approximately **78.81 degrees**. Node 4 reports approximately
  **66.03 degrees** for left and **5.99 degrees** for right. These are orientation
  residuals, NOT newly measured anatomical limits or simple excess-roll angles.
- Actual pinky–index/Handle parallelism error: Node 3 L≈30.55°, R≈0°;
  Node 4 L≈56.13°, R≈28.36°.
- From each settled failing node: ±3 cm Pommel and ±10 cm Tip requests along all
  three trajectory-authoring axes. All **24 requests rejected**, stored endpoint
  displacement zero, footer **`weapon_motion_acquired_grip_missing
  (RECOVERY_REQUIRED)`**. Calls took about **10–17 ms**. These failures occur before
  movement allocation; they are not evidence of an expensive movement search.
- Probes use production numeric endpoint handlers and restore the production
  render checkpoint plus authored node fields between trials. This is not an OS
  mouse-speed/drag-latency benchmark. No probe was saved.
- Both runs exited 0 without script errors. Reports confirm identical library
  hash before/after. The second run deliberately skipped F; inherited opener
  `scope` wording and `F_ever_playing=false` in its report must not be read as an
  F failure. This note describes the actual procedure. The retained diagnostic
  now adds explicit audit-scope/movement-mode metadata for future runs.

## Relevant code and conflict

- `combat_animation_station_preview_presenter.gd:4772–4786`: restored pose enables
  both arm-guidance/contact-basis paths, then restores binding or initiates
  fallback acquisition.
- `player_humanoid_rig.gd:653–674`: ordinary authoring body/arm/wrist processing
  can continue unless retained-authority ownership is active.
- `preview_grip_acquisition.gd:965–1008`: primary preparation seats/orients weapon
  against current Hand; capture at approximately 891–895 records the relationship
  used by the asynchronous numerical solver.
- `grip_acquisition_motion_rebase.gd:78–82`: rejects completion if weapon and Hand
  no longer have the same relative transform. The observed failure is exactly
  this guard. It already permits common rigid motion; it rejects relative drift.
- `preview_grip_acquisition.gd:859–862`: support cannot start until primary binds.
- Same-key synchronization around 625 skips requests; failure around 1445–1458
  leaves unresolved status without queuing another acquisition. A failed request
  is therefore carried into Node 4 even though the posture differs.
- `player_humanoid_rig.gd:6340` support macro settling checks positional/axis
  residuals for its early exit but returns no success/failure result after its
  bounded passes. `_prepare_support_acquisition` around 1017 checks preservation
  of primary, not successful support-axis alignment. This is a concrete gap
  consistent with Node 3 acquiring a diagonal support pose in the first run.
- The settling helper's `_resolve_authoring_contact_axis_error_degrees` at
  `player_humanoid_rig.gd:5435` compares the forearm shaft to its desired contact
  direction. That is not a measurement of actual pinky–index/Handle parallelism;
  successful coarse settling therefore cannot certify that separate requirement.
  The unbound hand-basis builder at 4564 requests pinky–index alignment, but the
  wrist projection at 3355 can reject that basis and record `wrist_motion_range`
  while leaving acquisition able to capture the resulting pose.
- `combat_animation_station_preview_presenter.gd:4496`: missing required grip
  binding causes Tip/Pommel's observed movement refusal.

## Conclusion and narrow next work

Failed grip acquisition is the immediate movement blocker. The data also shows
an orientation disagreement. It does **not** prove the user's desired pose is
intrinsically impossible: the result depends on opening/navigation/playback
history, and other runs can bind after a different macro pose is produced.

The confirmed failure detects hand–weapon relative drift during acquisition.
The code allows macro arm/wrist work while that solve is pending. This audit has
not instrumented the exact individual bone writer responsible for that drift;
do not claim a particular bone/axis has been proven to cause it.

Next targeted fix investigation: acquisition/macro-pose ownership and sequencing
at the single-hand→two-hand boundary; truthful support orientation readiness;
retry/repair of an unresolved relationship when the authored pose changes.
Preserve fixed primary-hand/weapon authority while the offhand joins. Do not
relax anatomical limits, bypass grip validity, rewrite finger solving, or pursue
general motion optimization on the evidence here. No production fix authorized
or made during this read-only examination; no Git operation.

Diagnostic APIs checked against official Godot 4.7
[Skeleton3D](https://docs.godotengine.org/en/4.7/classes/class_skeleton3d.html) and
[Resource](https://docs.godotengine.org/en/4.7/classes/class_resource.html).
Recorded bone frames keep skeleton/world/parent distinctions and named chain
back to `RL_BoneRoot`; angle comparisons use a common world frame.

## Updated Skill 1 retest: valid grip followed by movement lockout

User requested a retest after their new experiment, closed the game, and reported
valid grip with no movement. This is a fresh saved chain, not the original
four-node case above. Source library SHA256:
`0b77401566d9e9c77ca9e80b2449fa4189df934cf9633a00adbd12e56c7ab2de`.
Three visible nodes: Node 1 single-handed; Nodes 2/3 two-handed, primary seat
0.50 and support 0.55 normalized, Body Support 0.9. Node 2 has a durable acquired
grip packet; Node 3's saved packet is empty and acquisition supplies its binding.

Evidence directories:
- `godot_runs/glave_skill1_horizontal_20261109/`: first sequential/probe retest.
- **`godot_runs/glave_skill1_continuous_20261109/`**: decisive continuous test,
  production numeric UI handlers, no checkpoint restoration between edits.
  `continuous_movements.json` records before/immediate/1/4/12-frame observations.

Confirmed on Node 2:
1. Both stored bindings restore; movement preflight returns valid. No pending
   acquisition, wrist failures, or forearm/hand indexing failure.
2. Pommel +30 mm along trajectory-authoring X accepts 9.779 mm in 814.914 ms.
   Allocation is SCALED (32.552%), with valid commit readback and bindings.
3. Exactly one subsequent frame later, support retention restores the previous
   weapon transform. Its failure is `support_twist_range` on
   `CC_Base_L_ForearmTwist01`.
4. Authored endpoint values still describe the accepted new movement. Primary
   hand/weapon mismatch becomes 4.8566 mm and 0.69516 degrees. Grip ownership
   remains present, explaining why grip status can appear ready while movement
   is blocked. The disagreement persists through 4 and 12 frames.
5. Following Pommel +X, Pommel +Y, and Tip +X requests all reject immediately
   with `weapon_motion_acquired_grip_mismatch (RECOVERY_REQUIRED)` (~9-10 ms).

### Competing rules and pose ownership

- Allocator commit validates against 0.05 mm / 0.025 degrees and records motion
  authority (`combat_animation_weapon_motion_manipulator.gd:92-123`,
  `player_humanoid_rig.gd:1189-1204`).
- Independently, `PreviewGripAcquisition`'s `skeleton_updated` callback still
  recomposes the primary seat and invokes support retention
  (`preview_grip_acquisition.gd:1287-1292`).
- Retention uses 0.00005 **radians**, approximately 0.002865 degrees, rather than
  the allocator's 0.025-degree allowance (`:1327-1347`). The observed residual
  was about 0.02484 degrees. The first contact-distance read was also just over
  its 0.05 mm boundary (0.050018 mm); subsequent reads were 0.049853 mm. Both
  angular disagreement and boundary/readback robustness matter.
- That path invokes older `realize_prepared_support_hand_frame`, including a
  helper-bone twist guard of 90/2 degrees plus 0.05-degree epsilon
  (`player_humanoid_rig.gd:1975-1985`). Current semantic left forearm rho is
  approximately -90.466 degrees; its skin distribution gives approximately
  -45.233 degrees per helper, beyond the older 45.05-degree guard even though
  the current motion system accepts the semantic pose.
- The failed correction restores an earlier complete support snapshot
  (`preview_grip_acquisition.gd:1340-1365`) without reconciling the accepted
  authored endpoint state. This overrides the committed motion transaction.

This is a reproduced post-commit ownership/rule conflict, distinct from the
earlier missing-primary-acquisition case. It does not justify blaming the pose,
loosening every anatomical limit, bypassing bindings, or changing finger solving.
Next fix should reconcile accepted movement ownership, support-retention policy,
and current semantic twist validation. The first allocation's high cost/partial
travel is recorded, but is separate from the demonstrated next-frame lockout.

### Diagnostic correction and verification limits

The older multi-direction probe attempted to reuse one synchronous motion
checkpoint across awaited frames. Acquisition guards deliberately reject that
restore; its return value was not checked. Therefore those trials cannot be
claimed to be independent resets to the same pose. First-request observations
remain usable. The new continuous test uses **no restoration between requests**
and independently reproduces the lockout. The multi-direction tool now captures
and checks restoration within each synchronous request; that diagnostic-only
correction has not been rerun. It is not evidence of a production fix.

Both fresh processes exited 0; no script errors, library hashes unchanged.
No Save/F/equipped playback was exercised in this targeted movement retest.
Only diagnostic scripts and this note changed; no production fix or Git action.

## Authorized update: accepted motion owns grip retention

User authorized implementation with "update to new system :D" after the
continuous test above. This section supersedes the earlier read-only status,
not the historical observations. The change addresses the demonstrated
post-commit rollback, not numerical finger acquisition or general search cost.

### Production changes

- `runtime/player/player_humanoid_rig.gd`: after validated movement is committed
  and retained motion authority is established, hand that accepted pose to
  `PreparedGripAcquisition.accept_authoring_weapon_motion()` synchronously.
- `runtime/player/grip/preview_grip_acquisition.gd`: verify the existing fixed
  Hand-to-WeaponRoot mates, remember the current support pose and semantic
  wrist/shoulder state, and let the motion engine retain ownership through later
  skeleton updates. Those updates no longer re-seat the weapon or restore an
  acquisition-time support pose over the accepted movement.
- The handoff is tied to the actual grip requests, participating hands, primary
  hand, geometry epoch and active rig authority. Unchanged synchronization keeps
  it. Changed requests, reacquisition, imported/restored grip data, release and
  weapon-facing changes release it normally. It is runtime continuation data,
  included in synchronous render checkpoints, not a new saved-grip schema.
- `runtime/combat/combat_animation_station_preview_presenter.gd`: movement
  binding preflight now reads the same motion policy as retention/commit.
  Position and rotation comparisons use the same world-space construction and
  quaternion order as commit readback, avoiding the inverse-WeaponRoot rounding
  discrepancy. The default policy remains 0.05 mm / 0.025 degrees; no anatomical
  limits or numerical finger-contact acceptance rules were widened.
- The support fallback snapshot also retains semantic wrist/shoulder state, so
  restoring a pose outside allocated ownership cannot leave its continuation
  angles describing a different pose.

Acquisition and nonallocated motion still use their existing support-frame
solver. This is an ownership integration with the current motion engine, not a
claim that every older acquisition path has been replaced. F, Save, anatomical
profiles and the numerical finger solver were not changed in this pass.

### Fresh verification

Real rendered Glave retest:
`godot_runs/glave_skill1_retention_fixed_20261109/continuous_movements.json`,
`report.json`, node snapshots and engine log at the matching parent prefix.

Same saved Skill 1, same Node 2, same four consecutive production UI requests,
no checkpoint restores between edits and no saved-data changes:

| Request | Accepted authored displacement | Calculation time | Result after 1, 4 and 12 frames |
| --- | --- | --- | --- |
| Pommel +30 mm X | X +9.779 mm | 824.111 ms | Bindings valid; accepted weapon transform retained |
| Pommel +30 mm X again | X +10.722 mm | 1626.564 ms | Bindings valid; accepted weapon transform retained |
| Pommel +30 mm Y | Y +7.459 mm | 1838.820 ms | Bindings valid; accepted weapon transform retained |
| Tip +100 mm X | X +88.917 mm, with rotation-induced Y/Z change | 232.858 ms | Bindings valid; accepted weapon transform retained |

All twelve delayed observations have zero support rollback clamps, valid
movement bindings and the same recorded weapon transform as their immediately
accepted commit. The first move accepts the same displacement as the failing
baseline; the material difference is that it now survives the next frame and
the next three requests remain usable. The Pommel requests remain partially
accepted by the existing nonlinear movement search; this is not a claim that
all requested travel is reachable or that dragging is now fast.

The rendered process exited 0 without engine/script errors. The source library
SHA256 remained
`0b77401566d9e9c77ca9e80b2449fa4189df934cf9633a00adbd12e56c7ab2de`.
The test did not Save, Reset, run F or exercise equipped playback. Binding
continuity is not a fresh full-finger contact certificate. Numeric production
UI handlers were used; OS mouse drag smoothness remains for manual testing.

Focused verifier:
`tools/grip_plane_proof/verify_allocated_grip_retention.gd`;
`godot_runs/verify_allocated_grip_retention_20261109_final.log`.
**67 checks, zero failures, exit 0.** Covers both dominant hands, one/two-hand
ownership, retained fixed bindings/finger poses, contact tolerance consistency,
newest-pose fallback and semantic state, unchanged-request continuation,
changed support station and explicit reacquisition. This fixture mocks the
allocator/anatomical solve; the real rendered test above supplies integration
evidence. Two initial fixture failures were exact Basis-equality assertions:
the transformed-parent round trip measured zero positional error and
2.98e-8 Basis-column error. The final assertion uses 1e-7 numerical precision;
production tolerances were not changed to satisfy it.

### Remaining scope

- Manual usability check on the current Glave is ready.
- Pommel search cost is still substantial (up to 1.84 seconds in this sequence).
  Profile that separately if requested; do not call this an optimization fix.
- The earlier four-node acquisition-drift case is historical and was not
  reproduced/fixed by this ownership pass.
- No Git stage, commit or push performed. Existing unrelated changes preserved.

Implementation sequencing checked against official Godot 4.7
[Skeleton3D](https://docs.godotengine.org/en/4.7/classes/class_skeleton3d.html)
and [SkeletonModifier3D](https://docs.godotengine.org/en/4.7/classes/class_skeletonmodifier3d.html).
Named bone and coordinate ownership stays rooted in the existing rig; no
alternative world origin or saved coordinate convention was introduced.
