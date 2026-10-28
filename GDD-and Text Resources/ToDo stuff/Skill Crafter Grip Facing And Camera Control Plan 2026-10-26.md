# Skill Crafter grip-facing and camera-control plan

Prepared 2026-10-26, Europe/Bucharest. Status: **SC-07 implemented; camera/input stability follow-up implemented 2026-10-27**. The user authorized implementation after confirming the dark-green cube, unrestricted turns and both-hands-stationary behavior, and later explicitly requested the camera-jolt correction. Focused evidence is recorded below. The selected-node duration control is a separate completed change.

## SC-03 — qualified manual acceptance

The user exercised 17 motion positions in a somewhat complex sequence and reported:

- Some hand grips were lost during editing.
- Performance sometimes dropped to a standstill.
- Using the existing manual grip-acquisition button recovered the grip.
- Arm rotation, body rotation and the persistent arm "candy wrapper" deformation remain problematic.

The user accepts this as **"working" with extra manual steps for now** and explicitly does not want the current behavior changed in response to this feedback. Preserve these observations without treating them as a request for solver, anatomy or performance repair. This is user-reported evidence, not an independently reproduced diagnosis of the cause of each symptom.

The 17-position report does not enumerate all combinations in SC-03's L/R main-hand, normal/reverse, support, Save/reopen and equipped-playback matrix. Do not infer a complete matrix pass. Retain the original matrix as the record of coverage still to establish when selected; the user is not blocked on further repair now. Existing anatomy work remains BODY-01 and resource/performance work remains PERF-01, rather than new duplicate tasks.

### Subsequent user report, 2026-10-27: grip loss blocks authoring

The user now reports frequent loss of grip/contact status during movement, requiring manual Reacquire. They explicitly clarify that an unresolved grip prevents **R, F and Save**. This is a workflow blocker, not just a visual defect; the earlier acceptance with extra manual steps must not be read as evidence that this later report is resolved. Exact status text and the preceding control movement have been requested to distinguish an ordinary movement/acquisition fault from the deliberately manual independent-facing workflow. Diagnosis is read-only at this point; no cause or repair is claimed.

Read-only code findings: R (`combat_animation_station_ui.gd`, add-node recording), F preparation and Save all require the current prepared-pose capture. `get_prepared_pose_capture_context()` rejects pending acquisition, a required hand whose status is not `preview_applied`, or a missing live grip binding. Retained partial contact is permitted; this is not a requirement for perfect full-hand contact. A recovery case needs reproduction: `preview_grip_acquisition._finish_failure()` leaves the request `unresolved`, and `synchronize()` skips an unchanged relationship key unless forced. Manual Reacquire forces a new request. Movement during acquisition can fail the motion-rebase proof as `source_pose_changed_during_acquisition`, but this has not been established as the user's actual reason. Do not bypass capture guards or blindly retry all geometry failures. Independent dark-green weapon-facing edits deliberately require manual acquisition under SC-07 and must be distinguished from ordinary Tip/Pommel/wrist movement.

### Screenshot evidence and priority clarification, 2026-10-27

The user supplied both `Preview preparation failed: elbow_range_has_no_circle_solution` and `Not saved: elbow_range_has_no_circle_solution. Edits retained; previous saved skill unchanged.` They clarify that these are the **main failures**. Other hand/weapon failures recover through manual Reacquire and are secondary.

The exact error originates in `core/resolvers/combat_prepared_arm_frame_resolver.gd`, where the attempted shoulder-circle construction cannot meet the elbow-angle range (`abs(ratio) > 1.000001`). This is a constraint on the chosen geometric construction, not proof that every possible arm configuration or the user's authored placement is invalid. Do not simply loosen anatomical limits or assume the grip retry hypothesis explains this message.

For F, acquisition/readiness and endpoint capture are passed before `_complete_stored_pose_track()` invokes `CombatPreparedPoseTrackBuilder.build()`. Its per-frame `CombatPreparedAttachmentResolver.apply()` skips exact endpoints and follows the stored hand/weapon relationship during interior motion samples. That arm-follow calculation emits the reported rejection. Save uses the same track builder; this explains the matching F/Save errors. This is within the authored skill, before the separate 160 ms current-pose-to-node-1 entry. R does not invoke this track builder; a blocked R remains a separate endpoint/acquisition observation unless its own message establishes otherwise.

Next reproduction needs the active weapon/skill and whether the failing edits are saved or only live/unsaved; requested from the user without asking them to discard work. The UI already retains `last_preview_prepare_result.attachment_failure` with `frame_index`, zero-based compiled segment `node_index`, primary/support `hand`, and `elbow_distance_interval` (initial/minimum/maximum). A focused diagnostic should map these to node IDs/time/weight and inspect the requested hand frame, limits and the circle ratio/geometry before deciding whether the path is unreachable or the construction/search is insufficient. No game run or behavior change has been performed for this arm-follow failure.

The user tentatively identifies **Skill 2 on the broken `_1` weapon**, and confirms Save failed so they do not know what persisted. Direct read of the real `forge/player_wip_library_state.tres` identifies `Broken_Balde_v1`, WIP `player_wip_1792291462.519_14`, with selected skill `skill_slot_2`. The library's last-write time is 2026-10-27 19:41:15 Europe/Bucharest. Skill 2 contains only **one** action node (`motion_node_01`, incoming duration 1.0 s), its prepared pose and an existing baked clip. Skill 1 contains five action nodes; Skill 6 contains seventeen; both have prepared poses and clips. Other numbered skills contain one unprepared default node. No newer backup is present beside the real library (only an old unrelated test library). Only the Godot editor, not the running game, was present during inspection. This establishes what is saved, but does not prove which unsaved skill produced the screenshot. Do not claim to reproduce its between-node failure from Skill 2's one-node saved state or overwrite any user skill to manufacture a match. No user data was changed.

Existing verifier review: `tools/verify_combat_prepared_pose_track.gd` is insufficient for this fault because its main fixture sets `attachment_required=false` and expects zero arm IK calls. `tools/verify_prepared_arm_frame.gd` has reusable real-pose input helpers and rig constraints, but is a positive regression, not an existing reproduction of this exact failure. No matching failing fixture was found in the inspected tools, and neither verifier was run in this investigation.

## SC-07 — additional independent weapon roll

### Intended use

Sometimes acquisition leaves the weapon in an undesirable orientation inside the hand. Existing wrist-driven roll cannot independently change which face of the handle sits in the palm: it moves the held hand/weapon relationship together. The user wants a separate deliberate adjustment for the less common cases where this prevents the desired pose.

### Confirmed behavior

1. Keep the existing wrist-driven roll control and its current range-of-motion rules.
2. Add **one additional control point** for independent weapon roll around the **Tip–Pommel axis**.
3. During this adjustment, keep the body and hand stationary; rotate the weapon itself. Do not make the wrist follow this new roll or expand the wrist's anatomical allowance to achieve it.
4. Let the user choose the desired weapon orientation first.
5. The user then deliberately triggers the existing **manual grip acquisition**. Adjusting or releasing the new roll control must not automatically reacquire grip.
6. Preserve the hand-stationary, weapon-to-hand acquisition relationship. The new orientation control is an additional editing operation, not a replacement grip solver or a replacement for wrist roll.
7. Independent weapon roll rotates freely through **360 degrees and beyond**, with no angular stops. This does not change the existing wrist-driven roll limits.
8. In a **two-handed pose, both hands remain stationary while the weapon rotates**. Reacquisition for both hands is manually triggered after the adjustment; dragging or releasing this control does not start it automatically.

Later same-day clarification: the existing weapon roll, wrist pivot and wrist range limits remain unchanged. The additional independent Tip–Pommel roll control is a **dark-green cube**, placed on the **opposite side of the existing green roll dot**. Shape and color distinguish the two controls. Insert it immediately after the current roll in the existing selection chain: **Pommel → existing wrist-driven roll → independent Tip–Pommel in-hand roll → remainder of the chain**. Space and Shift+Space retain their forward/backward navigation roles. This records the requested layout and order; implementation must use the current gizmo's actual reference geometry rather than assume a screen-space offset.

### Implementation decisions and remaining scope boundaries

- **Control placement and input — partly resolved:** opposite the existing roll dot, dark-green cube, immediately after existing roll in the cycle as described above. Any additional numeric field is not yet specified. This remains one extra controller, not a redesign of the existing control chain.
- **Rotation policy — confirmed:** unrestricted rotation through full turns and beyond, with no angular stops or borrowed wrist limits. Representation of the authored facing and any turn history must be addressed with motion-node ownership; this input-range decision alone does not prescribe extra revolutions during playback.
- **Two-hand behavior — confirmed:** both hands stay fixed during independent weapon rotation; the user explicitly triggers reacquisition for both afterward. Preserve the existing primary-then-support acquisition relationship rather than inventing a parallel solve or automatically starting it on release.
- **Authored ownership — implemented:** store the final facing in the motion node's existing orientation fields. Preserve its existing wrist-roll scalar. Unlimited editing turns do not author extra revolutions into animation playback. No Forge default or weapon-wide inherited facing was added.
- **Pending adjustment state — implemented:** invalidate the old prepared endpoint and suspend grip acquisition/bindings. R, node navigation, F and Save require explicit manual reacquisition; they cannot certify the old grip or silently acquire a new one. Reset can discard this pending edit through its existing baseline workflow.

Trace the state through R capture, node navigation, prepared-pose invalidation, F, Save/reopen and equipped playback. The implementation reuses the existing authored/prepared lifecycle; no second playback or acquisition system is added. Fresh coverage is recorded below.

The existing distinction between the Tip-to-primary mount axis and the handle-span seating axis matters for eccentric geometry. The requested new rotation axis is explicitly Tip–Pommel; preserve the other axes' meanings rather than replacing them globally.

## Editing camera behavior — implemented 2026-10-27; verification below

The user reports that starting interaction with a control point can trace/refocus or relocate the camera. A small intended edit may then become a substantial control-point movement because the view changes during the interaction. Pommel movement is particularly disruptive because it can move the arm and body with it.

The requested behavior is:

- **No automatic camera relocation caused by selecting or manipulating editing control points.** This applies to Tip, Pommel, elbow and other editing controls.
- Keep the view stable while making fine adjustments. A control edit must not itself cause a camera jump that changes the intended edit.
- Retain deliberate camera movement through the user's existing camera controls. This is not a request to disable intentional navigation or explicit focus commands.

The user's concrete reproduction is: move Tip, cycle controls with Space, select the available control, then make a tiny adjustment. The workspace visibly shifts and the apparent adjustment exceeds the mouse movement.

The 2026-10-27 request authorizes removing automatic camera movement during editing directly; no toggle is added. The earlier "need in settings" request was duration, not camera behavior.

Current diagnosis and change:

- `CombatAnimationStationPreviewPresenter._ensure_preview_nodes()` called `_update_camera(root, null)` even for control-only refreshes. This reset the pivot to the body center. Full pose refreshes then called `_update_camera()` with the current weapon anchor, moving the pivot again.
- `_ensure_camera_state()` also overwrote the pivot before checking whether the camera was initialized. A release-time camera restore could not protect picking/dragging from these intermediate moves.
- Passive `_update_camera()` now initializes framing only once. `_ensure_camera_state()` preserves an existing pivot. Explicit orbit/zoom and saved-camera restoration retain their existing ownership; control/pose refreshes leave the camera transform alone.
- The UI ignores zero-relative mouse-motion events during a control drag. Godot or the OS may emit them while the pointer is stationary; they must not author an adjustment.
- A separate first-motion fault was also identified: ordinary point drags discarded the mouse-down offset and raycast the raw cursor through the control center. Clicking off-center could add up to the pick radius to the first tiny movement (20 px for endpoints, 34 px for curve handles). Point drags now retain their initial screen offset, using the same displayed point that was picked. Tip/Pommel, free-hand endpoints and Bezier handles use that corrected pointer; already press-relative wrist/facing/upper-arm angular paths remain unchanged. The offset resets at every drag start/end.
- Production owners are `runtime/combat/combat_animation_station_preview_presenter.gd`, `runtime/combat/combat_animation_station_ui.gd` and `runtime/combat/combat_animation_motion_node_editor.gd`. No grip, anatomy, path constraints or camera-navigation sensitivity is changed.

Official [Godot 4.7 Camera3D](https://docs.godotengine.org/en/4.7/classes/class_camera3d.html) and [InputEventMouseMotion](https://docs.godotengine.org/en/4.7/classes/class_inputeventmousemotion.html) documentation checked before implementation, including screen/world projection and zero-relative input behavior.

### Camera/input verification, 2026-10-27

- New focused verifier: `tools/verify_combat_camera_edit_stability.gd`. Rendered Godot 4.7, real station and `Broken_Balde_v1`, fresh Skill 3 only in an isolated library. Natural opening acquisition; no injected prepared pose. Mouse events use the production preview input handlers; Space uses the existing action path.
- Camera-only follow-up, before the grab-offset addition: `godot_runs/sc_camera_stability_20261027/run1/output/camera_edit_stability.json`, **69/69 checks passed**.
- Final camera plus grab-offset version: `godot_runs/sc_camera_stability_20261027/run2/output/camera_edit_stability.json`, **111/111 checks passed**, clean engine error log and normal shutdown. Camera transform, pivot/orbit state, projection and viewport rectangle stayed identical through Tip edit, the full available Space cycle, and Pommel edit. Stationary off-center press/hold/zero-relative event/release did not alter authored poses.
- Two-pixel Tip/Pommel motions were exercised with both centered and 4 px off-center grabs. Corrected requested movement excluded the initial click offset. Held projected movement was approximately 2.31/0.48 px for Tip and 0.58/1.19 px for Pommel; existing live constraints influence the realized displacement. These observations are not a new movement tolerance or a guarantee that every constrained target follows the pointer exactly.
- Deliberate RMB orbit and wheel zoom changed the camera without editing the authored pose; subsequent refresh retained that chosen view. Screenshots were inspected. The test process closed; the existing editor remained open.
- Real user-library SHA256 before/after: `7834B54752FDAE638CC894D989A76BC04D6D9F1790B90D9032928473626DC7D2`. Actual saved skills were not modified. No F/Save/equipped, anatomy or full grip-geometry certification was attempted. Free-hand/Bezier offset wiring and unchanged angular paths were reviewed in code; their full gesture matrix was not rerun. Manual user acceptance remains pending.

### Informational endpoint marker size, 2026-10-27

The user reports that the colored endpoint markers remaining after Save cover the active Tip/Pommel controls and make Space selection difficult to recognize. Both informational paths (`_create_playback_marker` and `_update_live_playback_marker`) previously used radius `0.026 * 2.8`, larger than the active control radius `0.022 * 2.8`. They now share `PLAYBACK_MARKER_RADIUS_METERS = 0.0052 * 2.8`: one-fifth the former diameter, approximately one-quarter the active control diameter. Active control size, selection radius, colors and marker positions are unchanged.

Code inspection distinguishes the lifecycle: playback can leave its final informational markers present; Save's field/summary refresh does not clear them. Save itself does not directly construct these markers. This adjustment changes size only. Official [Godot 4.7 SphereMesh](https://docs.godotengine.org/en/4.7/classes/class_spheremesh.html) properties were checked; height remains twice radius. Godot 4.7 `--headless --check-only` on the presenter passed, logged at `godot_runs/sc_camera_stability_20261027/marker_size_parse.log`. No new gameplay run or before/after rendered visual verification was performed for this small size change; manual acceptance remains pending.

## Focused acceptance checks

- New weapon-facing roll changes the weapon around the requested axis while retaining the body/hand pose; existing wrist-driven roll continues to work as before.
- No automatic acquisition occurs while changing or releasing independent roll. The explicit acquisition command still works afterward and preserves the chosen intended facing according to the agreed seating contract.
- Resolved two-hand and authored-data policies are exercised, including R, F, Save/reopen and equipped playback, without claiming untested variants pass.
- Selecting/holding/releasing each relevant control without moving the pointer does not relocate the camera or alter the authored pose. Fine drags remain fine after selection.
- Intentional camera movement still works. Camera/view changes remain outside action Undo history under the existing SC-04 contract.

Camera verification is recorded in the follow-up below. The independent-facing checks are covered by their earlier implementation evidence; coverage limitations remain explicit.

## Sources and supersession

- **Current user feedback, 2026-10-26:** 17-position SC-03 test; accepted manual reacquisition; independent Tip–Pommel roll with stationary body/hand and explicit acquisition; no automatic camera relocation during editing. This is the newest design authority for the additions above.
- [Project TODO](Project%20TODO.md), SC-03, SC-07, BODY-01 and PERF-01: checklist ownership. Avoid duplicate repair or orientation-control entries.
- [SPS 2026-10-13 09:13](../SPS/SPS_2026_10_13_09-13.md), "Current Loaded Worldspace" and "Next Focus": the original distinction between grip-facing and whole-hand roll; mount-axis versus handle-span caveat; no independent facing control at that time.
- [Grip Overhaul Consolidation](Grip%20Overhaul%20Consolidation%202026-09-18.md), October 13 orientation discussion (lines 665–688): a former Reset encoder experiment was withdrawn after support rejection. It is historical evidence, not an authorized fix to reapply. The separate control and storage in existing node orientation fields are now implemented; no weapon-wide inherited default was introduced.
- [Body Mobility Preparation](Skill%20Crafter%20Body%20Mobility%20Preparation%202026-10-19.md), "Default Pose And Limit Authority" (lines 37–69): hand-retained primary seating, forearm-relative wrist allowance and support engagement ownership. Preserve these rules alongside the deliberately separate weapon-facing operation.
- [Action Undo/Redo plan](Skill%20Crafter%20Action%20Undo%20Redo%20Plan%202026-10-26.md): camera/view navigation is not an authored action; future weapon-facing edits must join the agreed node-edit/history lifecycle when that infrastructure is implemented.

Older source documents retain their historical status. The new roll was implemented in the original October 26 pass; the camera/input correction is the October 27 follow-up above. Wider anatomy issues remain outside both passes.

## Implementation and focused verification, 2026-10-26

- `combat_animation_weapon_facing_manipulator.gd` owns the weapon-only axial transform and existing node-frame encoding. It has no bone, IK or acquisition writers. It checks the gesture context rather than rebasing silently after an unrelated edit.
- The presenter preserves the stationary pose during preview refresh. The UI adds a dark-green cube opposite the existing green dot, after wrist roll in Space/Shift+Space navigation. Horizontal dragging uses the established roll sensitivity, without anatomical angular clamps.
- `preview_grip_acquisition.gd` explicitly suspends pending acquisition, releases stale bindings without changing bones, and prevents old worker results or cached primary/support seating from overwriting the chosen facing. Existing Reacquire grip resumes primary then support work.
- A settled no-motion click does not invalidate the grip. Grabbing the cube while acquisition is still running cancels that unfinished work immediately, so it cannot change bones while the cube is held; that case requires manual reacquisition even if the user does not drag.
- Existing R/F/Save/reopen/equipped data paths carry the final orientation and newly acquired endpoint. No extra runtime solver, playback stream, authored spin count, camera setting or anatomy correction was introduced.

Fresh evidence:

- `tmp/weapon_facing_20261026_234414/output/weapon_facing_control.json`: 43 checks passed through single-hand cube input, ±450° editing turns, unchanged bone transforms, no acquisition during drag/release/refresh, manual-only R/F/Save guards, explicit acquisition, R, F, Save and cold-reopen F. Every measured local/world bone transform was unchanged during weapon-only manipulation; the largest measured endpoint displacement was approximately 0.00000018 m, numerical roundoff. F started without new acquisition; isolated Save reported 0.90 s. The combined run then failed its **two-hand baseline acquisition before using the cube**, with `realized_support_pose_outside_overlap_limits`; this is not a complete two-hand pass.
- `tmp/weapon_facing_equipped_20261026_234657/equipped.json`: fresh saved Skill 3 activated in the production equipped consumer; sampled poses and saved tracks passed, 60 Hz body and 160 ms entry retained, no new grip acquisitions, source library unchanged. This is sampled equipped verification, not certification of every weapon or anatomical pose.
- The fixture used `Broken_Balde_v1` in a workspace copy of the real library. The real saved library and skills were not altered.

The focused verifier remains available at `tools/verify_combat_weapon_facing_control.gd`. Existing wrist-roll code and limits remain unchanged; L/R, reverse-grip and all-geometry visual coverage must not be inferred from this single-weapon run.

Follow-up race verification:

- `tmp/weapon_facing_race_20261026_235241/output/weapon_facing_control.json`: **13 checks passed**, with an actual active acquisition interrupted by cube mouse-down. During the 1.8 s stationary hold and subsequent drag/release, all **77 bones** had zero measured local/world matrix change. The cancelled worker drained without applying an old pose or starting new work. Explicit reacquisition afterward retained the weapon facing and primary wrist position/orientation with zero measured difference.
- The preceding race fixture (`tmp/weapon_facing_race_20261026_235106`) did not reach the scenario: its cold restored endpoint had no active acquisition. The corrected fixture first used the normal facing edit and manual button, then observed a real busy worker. No production cold-button behavior was changed to make the fixture pass.

Follow-up two-hand verification and correction:

- `tmp/weapon_facing_two_hand_20261026_235333/output/weapon_facing_control.json`: the forward/chest-level UI-authored pose successfully acquired both hands, then passed the stationary-bone rotation checks. Explicit reacquisition exposed a real integration defect: prepared-pose restoration had cleared the rig's live support role/targets, while the acquisition owner still knew about both slots. Support application rejected with `support_seat_requires_joining_support_hand`.
- The presenter now restores existing contact-guidance roles/targets **at explicit manual reacquisition only**, before calling the existing acquisition owner. This does not run a body pose pass or write bones. Support macro alignment still occurs after the primary seat commits. Neither contact tolerances nor solver rules were changed.
- `tmp/weapon_facing_two_hand_20261026_235625/output/weapon_facing_control.json`: **27 checks passed** after that correction. Both-hand baseline accepted; all 77 local/world bone transforms remained exactly unchanged during cube press, drag, release and refresh. No automatic acquisition started. Explicit reacquisition ran `hand_right` then `hand_left`, produced a current prepared endpoint, and retained primary wrist position/orientation and weapon facing with zero measured difference.
- Source library SHA-256 remains `83d5746a8af2e6bbfc89e969c234c5a02f5f89b4fc6ba8b74b1bbfb6c9276c76`. All test saves remain isolated under `tmp`. No Git index/history action was performed.

Ready for the user's manual check: Space to the dark-green cube immediately after wrist roll, drag horizontally, release, then press **Reacquire grip**. Existing green-ball wrist roll retains its behavior and limits. These checks establish the new control and lifecycle on this weapon; the existing arm/body deformation issues and broader SC-03 matrix remain separate.
