# Skill Crafter playback availability investigation - 2026-10-25

## Scope and conclusion

User reports F does nothing and equipped assigned skills do nothing; requests
immediate investigation, then specifically comparison against Git before the
33+ second preparation optimization. Investigation only: no production code,
original save, slot assignment, Git index or history changed.

**Links are intact; executable animation is missing, and normal F preparation
cannot restore it from the currently saved node data.** The optimization moved
responsibility from Save rebuilding the animation to editor-captured endpoint
poses, without completing the capture/recapture lifecycle. The historical test
prepared every endpoint before measuring F, masking the normal open-to-F failure.

## Fresh evidence

Evidence root: `C:/WORKSPACE/godot_runs/skill_activation_20261025`.
Read-only copies: `source_library_before.tres`, `equipment_before.tres`,
`slots_before.tres`; original user data stays untouched.
Weapon: Broken_Balde_v1, WIP `player_wip_1792291462.519_14`.

- Actual saved slot assignments point Skills 1 and 2 to that WIP and the correct
  `skill_slot_1_draft` / `skill_slot_2_draft` IDs.
- Neither saved skill contains a `baked_runtime_clip` or `runtime_cache_signature`.
- Skill 1: five visible authored nodes, no captured endpoint poses in the file.
- Skill 2: three visible nodes, all contain structurally valid schema-2 poses.
  However, all three stored pose signatures are the same while current control
  signatures differ; the captures do not match the saved controls.

`unassisted_02` and `unassisted_03` run the real main scene/station, open normally,
wait for the selected grip, and invoke the actual F input action. They deliberately
do NOT visit all motion nodes or combat idle first. Both reproduce:

| Case | Outcome |
| --- | --- |
| Skill 1 F | No playback. Selected node 5 captures; nodes 1-4 lack current poses. Footer asks to visit nodes [1, 2, 3, 4]. |
| Skill 2 F | No playback. Selected node 1 captures; nodes 2-3 fail `prepared_pose_inputs_changed`. Footer asks to visit nodes [2, 3]. |
| Equipped resolution, both skills | Production slot resolver returns `success=false`, `grip_replay_ready=false`: "Saved grip needs refresh. Open this weapon in Skill Crafter and Save." |

The runtime resolution test uses the actual copied equipment/slot resources and
the production resolver. It does not claim a full equipped visual playback run;
activation is rejected before such playback can begin. No missing scene/weapon
or assignment error occurred.

`unassisted_01` stopped at the older diagnostic's preservation guard: this newer
action-only save recreates the hidden Reset baseline on open. The adapted probe
records those derived baseline changes while still rejecting changes to visible
authored controls. This is not an authored-node or file edit by the audit.

`signature_roundtrip.json`: previously stored Skill 2 signatures mismatch as soon
as data loads. Stamping the current loaded node's signature on an isolated copy,
saving/reloading text and binary both retain matching signatures.
`unassisted_03` additionally exports freshly captured live selected nodes from
both skills: signatures match before and after text save/reload, with zero
pose-input value differences. Therefore the tested serializer round trip works;
do not claim serialization precision is the demonstrated cause of these failures.

## Git comparison

Compared read-only, without checkout/revert:

- `cfbc46b0` (2026-10-20): last committed pre-optimization architecture.
- `ce641985` (2026-10-24): stored-endpoint optimization.
- `8aca64c7` (2026-10-24): attachment integration, current HEAD.

The earlier 33+ second measurements concern the previous audit/worktree, not a
fresh timing run of cfbc46b0. This is an architectural comparison, not a newly
measured old-versus-new timing benchmark.

Previously `_refresh_runtime_clip_cache_for_draft()` called the presenter's
`bake_runtime_clip_upper_body_pose_track()`. The presenter iterated sampled frames,
applied body/weapon controls, prepared/reused grip and captured bones, weapon and
anchors. Save did that for both active skill and combat idle. It could generate
animation from authored controls without a preexisting per-node pose cache.

Currently `capture_selected_prepared_pose()` records only the selected settled
editor node. `_complete_stored_pose_track()` requires every endpoint's current
snapshot before interpolation. F and Save finish only the selected capture;
neither rebuilds missing/stale endpoints or automatically visits combat idle.
Even reuse of an existing cached clip requires current endpoint snapshots.

Compatibility also changed: ce641985 introduced cache v12 / clip schema 9 /
pose schema 1; 8aca64c7 changed these to v13 / 10 / 2 plus arm constraints and new
context identity. Existing older caches and poses can therefore be invalidated.
No automatic migration/recapture owner replaced the old preparation traversal.

## Capture lifecycle defect in current code

`runtime/combat/combat_animation_station_ui.gd`:

1. `_finalize_preview_drag()` updates controls, invalidates the derived clip and
   refreshes the preview/capture generation.
2. Automatic capture waits for grip completion and two stable process frames.
3. `select_motion_node()`, `insert_motion_node_after_selection()` and
   `duplicate_selected_motion_node()` call capture once but ignore its result.
   They change selection immediately even if capture reports settling/pending.
4. R duplicates the old node, including its potentially stale pose/signature.
5. No pending capture remains for the outgoing node once selection changes.
   Save only waits for the currently selected node before validating all nodes.

This is a definite control-flow gap and consistent with the saved stale poses.
The user's exact historical input timing was not recorded, and this audit did
not perform a fresh edit-and-immediate-R reproduction; do not claim that history
has been conclusively reconstructed.

## Why it feels silent / why Save is not sufficient

- `_prepare_runtime_clip_cache_bake()` clears the old cache before preparing its
  replacement. Failure can leave authored nodes with no derived playable clip.
- Save persists authoring even when preparation failed, reporting that the cache
  needs review. This persistence behavior existed before, but formerly Save
  rebuilt the necessary poses rather than requiring manual node visits.
- `CombatAnimationDraft._validate_property()` also excludes incompatible cache
  data from serialization. This is a possible historical path to dropped old
  clips, not proof of which exact save produced the current file.
- Equipped `_validate_prepared_grip_replay()` refuses missing/incompatible replay.
  The controller retains its reason internally; the HUD only flashes the slot.
- Entry construction failure is separately obscured as "Preview preparation is
  stale". That is a code-observed reporting defect, not the failure reached in
  this particular normal-open reproduction.

## Verification gap in prior success claims

`tools/diagnose_skill_slot_ui_replica.gd` calls `_prepare_editor_snapshots()` before
its first F measurement. That helper explicitly visits combat idle and every
visible node and waits for capture. Earlier fast-F and equipped tests demonstrate
playback after those prerequisites exist. They do not establish that ordinary
opening, editing/R, saving and reopening maintain those prerequisites.

## Narrow repair direction / decisions

- Guarantee completed, correctly owned endpoint capture when committing/leaving
  a node; never silently carry an obsolete snapshot as a newly captured pose.
- Define a bounded one-time preparation path for old/missing endpoint data.
  How this is initiated/presented remains to be chosen; do not silently restore
  expensive per-frame grip solving or make the user repeatedly visit every node.
- Make authoring-save success and animation-ready status explicit. Avoid implying
  that a persisted but non-executable skill is ready for equipped use.
- Surface the actual F/entry/equipped rejection reason.
- Verify normal open-to-F, edit-to-R/navigation, Save-to-reopen-to-F and actual
  equipped activation using the real saved weapon, without test-only prewarming.
- Keep the fast stored-state interpolation, 60 Hz and 160 ms entry. Broader arm
  limits/attachment rejection, body controls and Forge work remain separate.

Engine reference checked: official Godot 4.7 Object `_validate_property()` and
ResourceSaver documentation. Their property/storage semantics are consistent with
the observed code; no engine serializer fix is proposed by this investigation.

## Authorized lifecycle repair (2026-10-25, implementation in progress)

The user authorized R to finish recording the outgoing endpoint before opening
the next, F to record the final current endpoint and play the complete action,
and Save to persist the same executable result consumed by equipped skills.
Keep the shared 160 ms current-pose entry and 60 Hz stored-state playback.

Implementation owners: `combat_animation_station_ui.gd` for lifecycle sequencing
and save publication; a separate endpoint recording job for missing legacy data;
`tools/verify_combat_pose_recording_lifecycle.gd` for real-UI verification without
the earlier diagnostic's manual snapshot prewarming. Recovery visits missing
authored endpoints in an isolated preview rig, not every playback frame. It must
leave the user's live pose, selection, camera and authored controls intact.

Future shoulder/spine controls are explicitly part of the same recording contract.
Their persistent authored values belong on the motion node; the presenter applies
them; the prepared pose captures their resulting bones/reference frames. R/F/Save
must not gain separate per-control lists. The existing generic pose-input signature
includes stored script properties by default; new body controls must participate
in that signature, capture, interpolation and equipped application. Any rig/schema
change must invalidate incompatible snapshots and use endpoint recovery. This is
an extension seam, not authorization to add the future controls in this pass.

Verification pending. No implementation success is established by these plans.

## Recording lifecycle results and focused baseline follow-up (2026-10-25)

This section supersedes the pending-verification status above. It does not claim
that F or equipped playback has been restored.

### Evidence before the baseline change

The ordinary-UI lifecycle verifier now records outgoing poses before R, Duplicate
or navigation changes selection; F records the final edited pose. The legacy
endpoint job records missing packets in an isolated rig. Save now refuses to
publish a replacement when required animation preparation fails, retaining dirty
edits and the previous saved library. A Noncombat Idle exception preserves its
intentional body-anchor path; that exception parsed but has not been live verified.

Fresh-slot tests had all action-node packets but F still failed attachment. The
read-only `path_readonly_01` diagnostic found that visible node 1 retained raw
weapon controls while its captured weapon was already seated in the hand. Those
two descriptions differed by approximately 745.8 mm. The legacy reach projection
then contributed approximately 721 mm of displacement to the already seated pose.
The failure was visible-node-1 to visible-node-2 interpolation, not F waiting for
an excluded hidden node 0. A diagnostic that disabled projection exposed a
separate small attachment residual. Production projection/arm math was not changed.

### Latest authorized scope and implementation

The user authorized the narrow initial-baseline correction:

- Opening an unused armed skill and explicit Reset share the existing actor/mount
  baseline restoration, geometry seed and explicit grip acquisition.
- Once the existing acquisition reports ready and the pose has settled, the UI
  reads the realized weapon through the existing frame encoder. It writes its
  tip, pommel, origins, orientation and roll to hidden baseline 0 and visible node
  1 before signing and recording the prepared pose.
- The hidden baseline remains editor-only. No node 0 was added to the action
  chain, preparation or saved playback. Entry remains a separate 160 ms transition.
- Pose editing is briefly gated during baseline acquisition/publication, using
  the existing authoring lock check. Camera controls remain available; R/F/Save
  use the existing capture wait. Stale completions do not overwrite changed nodes.
- Old pre-created slots without an untouched-baseline marker are recognized only
  by full authored-content equality with the existing seed factory, including
  curves, timing and body controls. Known legacy/current default durations and
  origin conventions are accepted. A one-node chain or missing snapshot alone
  never authorizes a reset. Descriptive metadata and changed draft timing also
  preserve the existing draft.

Production changes for this follow-up are confined to
`runtime/combat/combat_animation_station_ui.gd`. The existing lifecycle verifier
was extended. No attachment tolerance, arm limits, path projection, per-frame
solver, future body controls or Git history was changed in this follow-up.

### Fresh verification

Authoritative final run:
`godot_runs/skill_activation_20261025/baseline_lifecycle_02/results/pose_recording_lifecycle.json`.
Earlier baseline run: sibling `baseline_lifecycle_01` directory. Both used the
real `Broken_Balde_v1` asset, Skill 3 in an isolated copy of the library, normal
station UI methods and R/F actions; no visit-all packet prewarming or injection.

- Godot 4.7 script parse passed. Final runtime stderr was empty.
- New-slot and explicit Reset each produced internally coherent node-1 controls
  and a current snapshot; endpoint differences were below 0.0003 mm. Hidden
  baseline 0 was excluded from the action chain. Readiness took 4.227 s and
  4.078 s respectively, measured after opening/Reset rather than scene startup.
- Attempts to edit Roll before each baseline was ready were rejected without
  altering the authored signature. After readiness, a real one-node Roll edit
  followed by reselecting that skill preserved all authored controls.
- Same-tick edit then R/Duplicate and navigation during acquisition retained the
  outgoing node until recording finished. F captured the final edit. All four
  visible nodes had current signatures and valid prepared-pose packets.
- **F did not play.** It failed after 807 ms, with zero new grip acquisitions,
  at frame 1 / segment 0: `complete_arm_frame_residual`. Positional residual was
  0.1110 mm; orientation error was 0.000001425 rad and wrist-twist change was
  0.00001576 rad. The prior large-displacement/circle-feasibility rejection did
  not recur. These timings measure time to rejection, not successful preparation.
- Save after that failed F also rejected publication with the same reason. It
  completed in 22.798 s, retained dirty edits and created no replacement library.
  The existing endpoint/idle preparation cost remains; this is not evidence of a
  successful fast Save. Reopen/equipped playback could not be reached through
  this run because no playable replacement was produced.
- The source copy and real user library still match SHA256
  `05cfde9d95939249994108135e9201981d6f738d7fb69c94f8eeaaade92fa739`.
  Real Skill 1 and the rest of the user's library were not modified. Test engine
  processes exited normally.

### Remaining boundaries

The current blocker has recorded data; it is attachment validation, not a missing
R receipt or missing hidden node 0. The user has said that up to 5 mm positional
error is acceptable. This narrowly authorized follow-up did **not** implement
that tolerance or change angular checks; discuss a focused next change separately.

Internal baseline consistency is not identical repeated placement. The two
baseline operations in run 01 ended about 32.6 mm apart while each one's controls
matched its own captured weapon. No claim is made of identical Reset outcomes,
full-hand contact certification, complete anatomy, repaired old authored skills,
successful F, or successful equipped playback.

## Accepted 5 mm positional tolerance applied and checked (2026-10-25)

The user next authorized applying the previously accepted positional tolerance
and checking playback. This supersedes the earlier statement that the allowance
had not been implemented.

`CombatPreparedArmFrameResolver` now defines
`POSITION_TOLERANCE_METERS = 0.005`. Only the positional residual comparison in
`_metrics()` uses it, both for an already-close frame and after correction. The
existing `FRAME_EPSILON = 0.00005` remains unchanged for orientation/wrist-twist
precision and the internal correction step. Joint limits, reach, helper-twist
limits and geometric feasibility are unchanged. No independent downstream
prepared-playback positional gate was found; the shared attachment resolver is
also used by the 160 ms entry. Live support-grip acquisition is a separate path
and was not changed.

Godot 4.7's documented `Vector3.distance_to()` is the existing positional measure:
https://docs.godotengine.org/en/4.7/classes/class_vector3.html#class-vector3-method-distance-to

Fresh live evidence:
`godot_runs/skill_activation_20261025/position_tolerance_01/results/pose_recording_lifecycle.json`.
The same isolated real-UI Skill 3 lifecycle again passed initialization, Reset,
authored-node preservation and recording checks. F had all four current endpoint
packets and generated all 181 control samples without a new grip acquisition.
The previous frame-1 positional rejection was cleared.

**F still did not start.** It now failed at frame 123 / segment 2 with
`complete_arm_frame_residual` after 952 ms. That is time to failure, not a full
successful preparation benchmark. At this frame:

- Position residual: **0.17026 mm**, within the new 5 mm allowance.
- Orientation residual: **0.0000012623 rad**, within the unchanged 0.00005 rad gate.
- Wrist-twist residual: **0.0000551974 rad** (about **0.00316 degrees**), above the
  unchanged **0.00005 rad** (about **0.00286 degrees**) gate.

This remaining rejection is an angular precision check. The positional policy
has been applied; no angular tolerance was widened to force the run to pass.
Save/reopen/equipped verification was not reached because this run produced no
playable replacement. The real library still matches the pre-test source SHA256.

Focused proof:
`godot_runs/skill_activation_20261025/position_tolerance_proof_01/report.json`.
`verify_prepared_arm_frame.gd` passed all checks on the existing 46-frame fixture,
including unchanged endpoints, bone lengths, unrelated channels, idempotence,
reference-frame transformation and target-variation cases. Added acceptance
boundary checks passed: a 4.9 mm residual is accepted, 5.1 mm is rejected, and
0.0001 rad orientation and wrist-twist residuals are independently rejected.
The updated entry verifier uses the shared positional allowance while retaining
its independent angular checks; it parsed successfully but was not executed on
a newly saved skill in this pass. Runtime stderr was empty and test processes
exited normally. No Git operations were performed.

## Final angular allowance: +/-0.025 degrees; playback checks pass (2026-10-25)

The user's final angular allowance is **+/-0.025 degrees relative to the target**,
a **0.05-degree total band**. `CombatPreparedArmFrameResolver` now defines
`ANGULAR_TOLERANCE_RADIANS = deg_to_rad(0.025)` and uses it only for orientation
and wrist-twist residual acceptance in `_metrics()`. The absolute-error checks
apply equally in both directions. The accepted 5 mm positional allowance remains.
Anatomical ranges, helper-twist limits, reach, geometric feasibility and the
internal correction precision remain unchanged. The implementation uses Godot
4.7's documented `deg_to_rad()` conversion; no degree/radian reinterpretation of
existing joint limits was made.

This section supersedes the preceding F-blocked status for the tested workflow.
It does not rewrite or certify every existing authored skill.

### Skill Crafter lifecycle

Evidence:
`godot_runs/skill_activation_20261025/angular_tolerance_01/results/pose_recording_lifecycle.json`.
The entire verifier finished with `ok=true`. It used a fresh four-visible-node
Skill 3 on the real Broken_Balde_v1 asset in an isolated library, through normal
UI authoring, R/Duplicate/navigation, F, Save and reopening.

- New-slot/Reset coherence, pending-baseline edit protection, authored one-node
  preservation, outgoing-node recording and final-node capture all passed.
- The first F request started playback after **1.012 s** and completed. All four
  recorded packets were current; the final displayed endpoint matched its
  captured pose within the existing numeric comparison. Preparation and playback
  performed zero new grip acquisitions for that edited request.
- Save succeeded and reloaded the same authored controls and prepared packets,
  with a playable saved clip. Save took **23.588 s externally measured** (UI
  reported **23.19 s**). This remaining Save cost was not optimized in this pass.
- F after reopening also completed, starting after **4.567 s**. That request
  included one initial opening acquisition, followed by zero acquisitions during
  playback. Do not describe this as a second one-second cold-open measurement.
- Both playback checks retained **60 Hz**, the separate **160 ms entry**, and
  unchanged saved body channels after entry. The prepared body contained 181
  frames and four action nodes; hidden Reset node 0 was not added to playback.

### Equipped consumption and entry

Evidence: `godot_runs/skill_activation_20261025/angular_equipped_01/report.json`.
`verify_prepared_entry_attachment.gd` consumed the library saved by the lifecycle
run, without rebuilding the authored skill. Actual player activation succeeded,
runtime playback started, sampled skeleton/weapon output passed the existing
saved-track comparisons, and the terminal state finished and matched the save
within those comparison tolerances. No new grip acquisition occurred during
activation and sampled playback. Body channels remained unchanged; only their
timestamps shifted by the 160 ms entry, with 60 Hz preserved.

All ten independently inspected entry samples passed. Maximum entry positional
error was **0.03622 mm**, maximum orientation error **0.000001620 rad**, and
unrelated-bone rotation change was zero. This is a production-consumer/data proof
with selected real-rig playback samples, not continuous visual, collision,
recovery, all-grip-variant or full-hand-contact certification.

### Boundary proof and preservation

Evidence: `godot_runs/skill_activation_20261025/angular_tolerance_proof_01/report.json`.
All existing 46-frame arm-proof checks passed. New independent fixed-FK cases
accepted **-0.024/+0.024 degrees** and rejected **-0.026/+0.026 degrees**, separately
for orientation and wrist twist. The 4.9 mm acceptance and 5.1 mm rejection cases
also passed. Existing endpoint/segment precision, unrelated-channel preservation,
idempotence, reference changes and invalid-input rejection checks remain intact.

Both live-run stderr logs were empty; all test engines exited. The source and
real user library still match the pre-test SHA256 recorded above. Actual Skill 1
and all other real saved data were preserved; the successful test save lives only
inside `angular_tolerance_01/results/profile_library.tres`. No Git operations were
performed. Current follow-up is manual visual testing, with the remaining Save
cost and previously recorded body issues separate from this tolerance change.

## State ownership correction and selected-section Save (2026-10-25)

The user rejected preparing Combat Idle as part of an individual skill Save.
Each skill, Combat Idle, Noncombat Idle, and the transition between states has
its own responsibility. Whole-weapon final packaging belongs to future Engraving.
The transition consumes the current live state and the destination's first pose;
it is not a saved detour through Reset or a dependency on another skill/idle.

Canonical defaults clarified by the user:

- Node 0 is the default fallback. Unmodified Combat Idle uses that default body
  and weapon/hand relationship until its own editor changes it.
- Unmodified Noncombat Idle uses the default node-0 body with the weapon at its
  designated default attachment anchor and orientation.
- Defaults should be established and persisted once on first-ever initialization.
  Later opens load the section being edited, without rebuilding every state.
- Equip reads the weapon's saved sections together; the shared transition joins
  current state to the next action. An individual Save must not acquire or publish
  other states. Existing customized idle data must survive unchanged.

Code distinction: default idle definitions already exist. The factory's
`default_skill_package_initialized` flag marks placeholder creation, not solved
fallback readiness. Missing prepared idle replay data is **not** missing authored
idle data. The actual test weapon has a customized Combat Idle, so replacing it
with a generic Reset pose would destroy user work.

Narrow implementation now under verification: Save records/renders only the
selected draft; the library merges only that draft into the previously saved
weapon. The live editor clone retains other unsaved changes. Save readiness
compares the selected content/cache, while the global unsaved indicator still
accounts for other drafts. Endpoint recovery has its own timing phase rather
than being hidden inside `active_skill_render`.

Separate gaps identified, not fixed by this Save change: there is no durable
first-open solved-default completion owner yet; runtime Combat Idle rejects a
missing prepared replay clip instead of consuming a prepared default fallback;
its existing recovery uses 1.2 seconds rather than the shared 160 ms entry; stow
attachment and its timer have their own older path. These need a focused follow-up,
not another reason to prepare idles while saving an unrelated skill. Hidden skill
Reset node 0 stays excluded from saved action playback.

### Fresh partial verification and independent equipped-entry blocker

`godot_runs/skill_activation_20261025/selected_save_01/results/pose_recording_lifecycle.json`
measured selected Save at **1.052 s externally** (UI reported 0.65 s, excluding
the final refresh). It performed zero acquisitions and reused the active
181-frame clip. Selected content became clean; an unrelated description edited
through UI methods remained unsaved in memory and absent from disk. Nonactive
live and persisted draft comparisons were unchanged. This first run stopped at
an exact saved-cache fingerprint mismatch; authored controls and captured-pose
numeric round trip had already passed. It is partial evidence, not a full pass.

`godot_runs/skill_activation_20261025/selected_save_equipped_01/report.json`
uses optional `--live-entry` in the existing entry verifier. This bypasses only
the test's prepared-Combat-Idle prerequisite and keeps actual live rig/weapon
capture and production slot activation. The selected skill resolves and its
saved replay is ready. Incoming capture is valid, but entry construction fails
at frame 1 (0.0166666675 s) with `requested_hand_scale_differs_from_rig`.
Playback therefore does not start in this cold already-drawn scenario. The
earlier prepared-idle equipped pass remains historical evidence for that
different starting condition; it is not proof of arbitrary live entry.
No scale, joint-limit, transition or idle fallback fix was added in this pass.

The isolated storage proof at
`godot_runs/skill_activation_20261025/selected_save_storage_01/report.json`
passed first-unarmed selected saving, Noncombat Idle anchor-only saving, and
memory rollback after a deliberately rejected filesystem write with a pruned
null library entry. First-unarmed geometry-truth flags remain false. The two
write errors in that proof are intentional. It does not claim protection from
partial disk writes in the existing persistence helper.

Read-only follow-up on the cold-entry rejection found a specific scale-composition
case. The initially equipped weapon inherits scale approximately **0.764165**
from `RightHandItemAnchor`; its saved replay destination uses weapon scale **1**.
Entry independently blends weapon scale and the inverse hand-relative attachment
scale, then multiplies them. Their product temporarily requests a different hand
size, although the rig's hand scale remains fixed. The arm resolver rejects that
request before IK. At entry frame 1 the estimated scale excess is about 0.001634
(dimensionless, not a distance). The earlier prepared-Combat-Idle test first moved
the weapon under `RuntimeCombatEndpointAuthorityRoot` at scale 1, hiding this case.
Old/new saved destination bone scales, rest transforms, parent transforms and
weapon scale match exactly; there is no evidence this Save change corrupted them.
Next focused diagnostic: log both endpoint weapon/attachment scales, the rig's
hand scale, and their composed result at frame 1. Do not weaken positional/angular
tolerances to address a scale-composition error.

The first lifecycle run's exact cache fingerprint issue was traced to the test:
recursively expanded serialized clips in `working_draft.tres` and
`profile_library.tres` are identical (SHA256
`9e392727e0016635835eee625c3e2e167a6ea47469ebf510efd2f3be5dda0649`).
Raw dictionary serialization is order-sensitive. The verifier now retains exact
live-cache and input-signature checks, and checks every reloaded clip key, array,
ID and numeric value with its existing 0.000001 numeric bound. Exact hash/equality
and maximum numeric difference remain in the report instead of being hidden.

### Completed selected-Save lifecycle verification

Final evidence:
`godot_runs/skill_activation_20261025/selected_save_02/results/pose_recording_lifecycle.json`
finished with `ok=true`. This supersedes the first run's verifier-only cache
fingerprint failure, but does not supersede the independent equipped-entry failure.

- Edited four-node F preparation: **1.086 s**, no new acquisition during
  preparation or playback, playback completed. The body retained 60 Hz and the
  separate 160 ms entry without changing the saved body channels.
- Selected Save: **1.012 s external wall time**, UI reported 0.59 s before final
  UI refresh. The previous comparable lifecycle Save was 23.588 s and included
  another state's preparation. This pass removes that unrelated work; it does
  not weaken skill preparation or omit saved endpoint/replay data.
- Save recorded zero acquisitions and one cached/skipped render call for the
  selected draft only. Live cache content was unchanged; all authored controls,
  prepared endpoint packets and replay channels survived saving/reloading.
  The clip's maximum numeric serialization difference was **2.050934e-8**,
  below the existing verifier bound of 1e-6. Exact-byte hashes are therefore not
  the right acceptance rule for live-to-text-to-loaded numeric data.
- A real UI description edit in another authored skill remained live and dirty,
  was not published, and kept the global unsaved indicator true. The selected
  saved skill was clean. Nonactive live and persisted comparisons were unchanged.
- Reopened F completed after **4.800 s**, including one opening acquisition and
  zero acquisitions during playback. This is not proof that opening already
  reuses a durable solved default; that lifecycle work remains outstanding.
- The edited F diagnostic observed a maximum process-frame interval of about
  **488 ms**. Faster total preparation does not certify stutter-free preparation.

All test engines exited. Final lifecycle stderr was empty; the equipped diagnostic
contains the expected scale rejection and the storage proof its deliberate IO
failures. Real user library SHA256 remains
`05cfde9d95939249994108135e9201981d6f738d7fb69c94f8eeaaade92fa739`.
No real saved skill was overwritten, and no Git operations were performed.

Next scope to discuss: persist/reuse a correctly owned solved default once,
without overwriting customized idle states; fix composed entry scale continuity
from an actual live equipped pose. Keep unrelated anatomical fixes and idle
timer/stow redesign outside this selected-Save pass.

## Manual-test checkpoint and scale ownership clarification

The user requested a Git checkpoint before manual testing. Current verification
supports Skill Crafter R/edit/F/Save/reopen testing on the exercised normal,
single-hand four-node flow. General reverse/support/left-hand variants remain
uncertified. Direct equipped activation from the initially mounted pose still
fails at entry scale composition as documented above; it is not a clean
end-to-end equipped-playback build yet.

The scale in that failure originates in existing model-height normalization:
`PlayerRigModelPresenter.apply_target_height_scale()` sizes `JosieModel` to
`standing_height_meters` (default 2.0). Those lines were already present in Git
on 2026-04-08. The skeleton, hand anchors, and ordinarily mounted weapon inherit
that model scale. Saved playback uses a unit-scale reference and applies stored
weapon position/scale. Reparenting preserves world transform; application of the
saved pose introduces the different scale. This is not a newly introduced
wearer-hand/reference-hand ratio implementation.

The user's intended uniform size adaptation can use inheritance as its foundation.
Do not multiply already-scaled children by the same factor again. Current saved
trajectory/attachment/reach data does not yet consistently share that scaling
frame, and the main player collision capsule and camera are outside `JosieModel`.
No 1.5 m/2.5 m comparison or resizing implementation was performed in this
discussion. First-open fallback reuse and coherent scale handling remain future
focused work; no additional gameplay changes were made while discussing them.

## Skill Crafter reverse control selection (2026-10-25)

User requested Forge-style backward navigation for the existing Space control
selection. Space still cycles forward through the current available Tip, Pommel,
Weapon, arm and free-hand controls; Shift + Space cycles backward through the
same list, wrapping from first to last. This is active-control selection, not
motion-node timeline navigation. Shift modifies the existing cycle action, so
the action ID, aliases and ordinary custom key assignments remain intact.

`CombatAnimationSessionState.cycle_focus()` now accepts a direction, defaulting
to forward. The station passes the event's Shift modifier and shows the reverse
shortcut in its hints. Existing text-entry/popup guards and release/echo handling
remain. No skill serialization, pose solving or replay changes are involved.

Checked official Godot 4.7 documentation for
[action matching](https://docs.godotengine.org/en/4.7/classes/class_inputevent.html#class-inputevent-method-is-action-pressed)
and the [Shift modifier](https://docs.godotengine.org/en/4.7/classes/class_inputeventwithmodifiers.html#class-inputeventwithmodifiers-property-shift-pressed).
The focused station-verifier script and its scene dependencies passed Godot's
`--check-only` parse check. Diff whitespace check passed. No new runtime input
run was performed for this small change; forward/reverse visual operation remains
for manual confirmation. This addition is after Git checkpoint `5e511a1e`.

## Active-control visibility (2026-10-25)

User requested that inactive control markers disappear while the trajectory
splines remain visible. On the selected motion node, Tip shows its endpoint,
Bezier cubes and connecting rods; Pommel shows its corresponding controls.
Weapon, right/left upper-arm and free-hand controls appear for their own active
focus. Inactive endpoint spheres on other motion nodes are hidden as well;
those spheres were not an independent mouse-selection route.

The preview presenter applies the same filtering to full, cached-selection and
budgeted-drag refreshes. The budgeted drag now retains the last evaluated
trajectory mesh instead of clearing it; normal path refresh still happens on
edit finalization. This adds no path/collision recalculation during that mode.
Existing focus-specific picking remains. Space / Shift + Space finishes an
existing drag before changing focus, preventing a hidden old control from
continuing to follow the mouse.

Implementation is limited to `combat_animation_station_preview_presenter.gd`
and `combat_animation_station_ui.gd`; no stored motion, grip or playback data
changes. Consulted official Godot 4.7
[Node3D visibility documentation](https://docs.godotengine.org/en/4.7/classes/class_node3d.html#class-node3d-property-visible).
The existing focus-guard verifier and station dependencies passed Godot
`--check-only` after this change, and the diff whitespace check passed.
Read-only review confirmed new drags were already focus-restricted. This is
code/parse verification, not a fresh interactive visual pass; manual checking
of Space / Shift + Space across controls and while dragging remains appropriate.
No library writes, commit or push were performed for this UI change.
