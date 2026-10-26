# Skill Crafter grip-facing and camera-control plan

Prepared 2026-10-26, Europe/Bucharest. Status: **SC-07 implemented; focused verification recorded below**. The user authorized implementation after confirming the dark-green cube, unrestricted turns and both-hands-stationary behavior. Camera behavior remains planned separately. The persistent default duration for new motion nodes is a separate completed change.

## SC-03 — qualified manual acceptance

The user exercised 17 motion positions in a somewhat complex sequence and reported:

- Some hand grips were lost during editing.
- Performance sometimes dropped to a standstill.
- Using the existing manual grip-acquisition button recovered the grip.
- Arm rotation, body rotation and the persistent arm "candy wrapper" deformation remain problematic.

The user accepts this as **"working" with extra manual steps for now** and explicitly does not want the current behavior changed in response to this feedback. Preserve these observations without treating them as a request for solver, anatomy or performance repair. This is user-reported evidence, not an independently reproduced diagnosis of the cause of each symptom.

The 17-position report does not enumerate all combinations in SC-03's L/R main-hand, normal/reverse, support, Save/reopen and equipped-playback matrix. Do not infer a complete matrix pass. Retain the original matrix as the record of coverage still to establish when selected; the user is not blocked on further repair now. Existing anatomy work remains BODY-01 and resource/performance work remains PERF-01, rather than new duplicate tasks.

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

## Editing camera behavior — planned

The user reports that starting interaction with a control point can trace/refocus or relocate the camera. A small intended edit may then become a substantial control-point movement because the view changes during the interaction. Pommel movement is particularly disruptive because it can move the arm and body with it.

The requested behavior is:

- **No automatic camera relocation caused by selecting or manipulating editing control points.** This applies to Tip, Pommel, elbow and other editing controls.
- Keep the view stable while making fine adjustments. A control edit must not itself cause a camera jump that changes the intended edit.
- Retain deliberate camera movement through the user's existing camera controls. This is not a request to disable intentional navigation or explicit focus commands.

This is a user-observed behavior report plus a desired rule, not a verified diagnosis of the current camera owner or event order. Before implementing it, inspect where control selection, focus, drag start and camera updates interact, then test a no-motion press/release and a small drag without unintended view or pose changes.

**No camera-toggle setting has been agreed.** The initially unfinished "need in settings" request was subsequently clarified as the default duration for new motion nodes. Whether this future camera behavior is unconditional or exposed as an option, and any label/default for such an option, remain undecided. Do not conflate the duration setting with this deferred camera work.

## Focused acceptance checks

- New weapon-facing roll changes the weapon around the requested axis while retaining the body/hand pose; existing wrist-driven roll continues to work as before.
- No automatic acquisition occurs while changing or releasing independent roll. The explicit acquisition command still works afterward and preserves the chosen intended facing according to the agreed seating contract.
- Resolved two-hand and authored-data policies are exercised, including R, F, Save/reopen and equipped playback, without claiming untested variants pass.
- Selecting/holding/releasing each relevant control without moving the pointer does not relocate the camera or alter the authored pose. Fine drags remain fine after selection.
- Intentional camera movement still works. Camera/view changes remain outside action Undo history under the existing SC-04 contract.

The camera checks remain future work. The independent-facing checks are covered by the implementation evidence below; coverage limitations remain explicit.

## Sources and supersession

- **Current user feedback, 2026-10-26:** 17-position SC-03 test; accepted manual reacquisition; independent Tip–Pommel roll with stationary body/hand and explicit acquisition; no automatic camera relocation during editing. This is the newest design authority for the additions above.
- [Project TODO](Project%20TODO.md), SC-03, SC-07, BODY-01 and PERF-01: checklist ownership. Avoid duplicate repair or orientation-control entries.
- [SPS 2026-10-13 09:13](../SPS/SPS_2026_10_13_09-13.md), "Current Loaded Worldspace" and "Next Focus": the original distinction between grip-facing and whole-hand roll; mount-axis versus handle-span caveat; no independent facing control at that time.
- [Grip Overhaul Consolidation](Grip%20Overhaul%20Consolidation%202026-09-18.md), October 13 orientation discussion (lines 665–688): a former Reset encoder experiment was withdrawn after support rejection. It is historical evidence, not an authorized fix to reapply. The separate control and storage in existing node orientation fields are now implemented; no weapon-wide inherited default was introduced.
- [Body Mobility Preparation](Skill%20Crafter%20Body%20Mobility%20Preparation%202026-10-19.md), "Default Pose And Limit Authority" (lines 37–69): hand-retained primary seating, forearm-relative wrist allowance and support engagement ownership. Preserve these rules alongside the deliberately separate weapon-facing operation.
- [Action Undo/Redo plan](Skill%20Crafter%20Action%20Undo%20Redo%20Plan%202026-10-26.md): camera/view navigation is not an authored action; future weapon-facing edits must join the agreed node-edit/history lifecycle when that infrastructure is implemented.

Older source documents retain their historical status. The new roll is now implemented; camera changes and the wider anatomy issues are outside this pass.

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
