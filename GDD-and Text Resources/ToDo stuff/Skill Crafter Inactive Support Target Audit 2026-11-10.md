# Skill Crafter inactive support target audit - 2026-11-10

## Scope and user rule

Diagnosis only. Inspect saved `Broken_Glave_v1`, Skill 3, visible nodes 1 and 2.
Compare their poses, then use node 2's right-side Support Handle Position field
to change its displayed value from -1.0 to +0.2 while still one-handed.

User clarification: changing this inactive target must not alter the pose. It is
preparation for later engagement, not a body/weapon movement request. Feasibility
of the future target does not give it authority over the currently unengaged arm.

No production changes, Save, F, anatomical/grip changes or Git operation in this
pass. The diagnostic edit was discarded on exit; the real library hash matched
before and after cleanup.

## Current evidence

- Tool: `tools/diagnose_glave_skill_three_support_target.gd`, extending the prior
  Glave observation harness. Runs the actual station and actual SpinBox LineEdit
  with `apply()` (Godot's Enter equivalent), rather than assigning body targets.
- Completed rendered run: `godot_runs/glave_skill3_support_target_verified_20261110_234017/`.
  `report.json`, `support_target_probe.json`, `support_target_analysis.json`,
  `saved_nodes_before.json`, `nodes_before_edit.json`, `nodes_after_edit.json`,
  and before/after screenshots hold the evidence. Runtime error log was empty.
- Source SHA256 before/after:
  `199596bfab8c5eff46622ce6b6ce7655d8190aea72eee3d2c8149930ca2ad514`.
- Initial run `glave_skill3_support_target_20261110_233908` completed the UI
  reproduction but its saved-pose comparison attempted to cast stored Vector4
  rotations directly to Quaternion. Corrected in the diagnostic before the
  completed run. This was a diagnostic error, not a production pose failure.

## Node comparison

The two visible nodes are the same pose. Their authored storage-field comparison
differs only in `node_index`. Tip and Pommel differences are exactly zero in
trajectory-reference units. Saved bone names, positions, rotations and scales
are equal; full serialized rotation-array lines in the backed-up `.tres` also
match exactly. Live weapon and measured bone positions are identical on node
selection; world-quaternion comparison has only tiny numerical residuals.

The diagnostic initially reported 0.03956 degrees for the identical stored left
forearm quaternion because of float32 normalization/dot/acos roundoff. Exact
stored-array comparison and live transforms disprove a physical difference.
The tool now short-circuits exactly equal XYZW values; that final diagnostic-only
guard was not followed by another engine run. Offline analysis records the exact
array equality separately.

## Reproduction

- Before: one hand, displayed support coordinate -1.0, normalized storage 0.0.
- Entered +0.2 through the actual SpinBox; storage became 0.6 in balanced-handle
  coordinates. One-handed state remained unchanged.
- The only authored field changed was node 2's
  `secondary_grip_seat_slide_offset`. Authored Tip/Pommel and other controls were
  untouched.
- No numerical grip acquisition jobs occurred, including during the edit.
- Nevertheless the displayed weapon root moved **390.991 mm and 98.907 degrees**.
  Main Hand moved **12.970 mm and 98.907 degrees**; offhand moved **97.100 mm and
  44.913 degrees**. Spine02 turned **37.048 degrees**. These are world-frame
  differences, not new authored control values or joint-local anatomical angles.
- Before/after screenshots were inspected; the pose visibly changes while the
  UI still reports One Hand. The generic reconstruction also produces pose/
  collision warnings, which are consequences here, not justification for moving
  a dormant target's body.

## Code cause

1. `runtime/combat/combat_animation_station_ui.gd`,
   `set_selected_motion_node_secondary_grip_seat_slide` (~9009-9064), always
   supplies `PREVIEW_GRIP_RESOLVE_REASON_HANDLE_POSITION` to full preview refresh.
   It has no inactive-support data-only branch.
2. `core/models/combat_prepared_pose.gd`, `node_pose_signature`, includes the
   secondary seat even in one-hand mode. Changing it invalidates exact recorded
   pose reuse. The explicit refresh reason independently bypasses retained-pose
   paths. Removing that reason alone is insufficient.
3. The full `_apply_authored_weapon_pose` path reconstructs weapon/body from
   authored scalar targets and performs contact-group settling. This is not an
   identity operation on the already captured, manually authored body.
4. `combat_animation_station_preview_presenter.gd`,
   `_build_preview_upper_body_authoring_payload` (~7386), supplies a nonzero
   `secondary_target_world` from the support anchor regardless of its `two_hand`
   flag. The live post-edit payload confirms `two_hand=false` plus a nonzero
   secondary target.
5. `runtime/player/player_rig_upper_body_pose_presenter.gd`,
   `_resolve_pose_context` (~247 and 260), blends any nonzero secondary target
   into torso targeting (35%) and shoulder targeting (50%) without checking the
   role. Thus an unused handle target influences the body when that legacy macro
   runs. Individual contributions of redundant rebuild and target leakage were
   not isolated by changing production code in this observation pass.
6. The recent support engagement fix applies only to the one-hand/two-hand
   toggle. This numeric setter does not use that handoff path. Grip-data reuse
   is working (zero solves); this is a separate posing/role-ownership defect.

## Narrow correction proposed, not implemented

Treat an inactive support-target edit as stored future intent: retain current
body, weapon and valid primary grip, and do not invalidate/rebuild the current
pose solely because that dormant coordinate changed. Still persist the edited
target and include it in saved-content identity. When support is subsequently
enabled, use the edited target through the existing support-only join path.

Also gate secondary body targets by actual support engagement at the shared
authoring/consumer boundary, so another generic redraw cannot leak the dormant
target into the body later. Preserve legitimate engaged support positioning.
Do not fix this by moving anatomy, relaxing limits or changing the numerical
finger solver.

Focused follow-up: repeat this exact numeric UI test, verify unchanged live and
stored pose, then engage support and verify it alone uses the newly stored
target. Check pose reuse versus saved-content dirtiness across navigation/reopen.

Reference: [Godot 4.7 SpinBox](https://docs.godotengine.org/en/4.7/classes/class_spinbox.html#class-spinbox-method-apply).
