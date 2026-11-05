# Shoulder Rig Mapping Audit - 2026-10-28

This is a code-owner and coordinate-frame audit for the shoulder research. It adds no runtime behavior. The current user instruction is to preserve the research and mapping, not implement an anatomical solver or run further tests. The intended first test surface, when resumed, is **Skill Crafter Unarmed mode using its existing controls**.

**Later user decisions, 2026-10-28:** the implementation scope is the shared body for unarmed and all current/future weapon archetypes. Unarmed is the test setup, not a separate solver target. The triangular-return acceptance example is withdrawn; usability and predictable control are the goal. Follow the guide/papers, adding a tolerance only if needed, up to 3% against a stated reference measurement. No numerical threshold was changed by this audit. The [entrypoint](<Shoulder Anatomy And Unarmed Rig Reference 2026-10-28.md#latest-user-decisions-2026-10-28>) records the current direction.

Start with [Shoulder Anatomy And Unarmed Rig Reference 2026-10-28.md](<Shoulder Anatomy And Unarmed Rig Reference 2026-10-28.md>), then read alongside [Shoulder Anatomy Research 2026-10-28.md](<Shoulder Anatomy Research 2026-10-28.md>). The research companion contains the original anatomy papers, coordinate-system references and limits on interpreting their measurements. This document describes the actual game rig; it does not turn those papers into an approved numerical constraint table.

## Snapshot and evidence boundaries

- Inspected checkout: `C:\WORKSPACE`, branch `recovery/stable-92b8a24-chat14`, HEAD `5fb7a66b19ddeba0535ade8a9c6495c9a0475689`.
- The working tree contains later changes. HEAD alone does **not** identify the code audited here. In particular, the live rig includes the narrow signed elbow lower-bound guard from this session, and the UI/builder include node-failure feedback. Preserve these changes.
- Godot project: `C:\WORKSPACE\The Will- main folder\the-will-gamefiles`. `project.godot:15` declares `4.7`, Forward Plus. This identifies the project target, not a newly measured executable version.
- All code paths below are relative to that project. Line numbers are the inspected 2026-10-28 working-tree anchors and will move after edits. Method names are the durable search targets.
- This mapping pass used source inspection. It did not launch Godot, open a real weapon library, modify saved skills, change production code, or prove an anatomical correction.
- Earlier session runs are documented separately in [SPS_2026_10_28_20-11.md](<../SPS/SPS_2026_10_28_20-11.md>). Do not represent them as new unarmed-loop verification.

## 1. Actual bone chain and missing biological relationships

Authoritative asset: `Josie/josie.tscn`.

```text
RL_BoneRoot -> Hip -> Waist -> Spine01 -> Spine02
  Spine02 -> L_Clavicle -> L_Upperarm -> L_Forearm -> L_Hand
  Spine02 -> R_Clavicle -> R_Upperarm -> R_Forearm -> R_Hand

  Upperarm -> UpperarmTwist01 -> UpperarmTwist02
  Forearm  -> ForearmTwist01  -> ForearmTwist02
  Forearm  -> ElbowShareBone
```

The shorthand above omits the common `CC_Base_` prefix. Twist helpers are **branches beside the main downstream joint**, not parents in the Upperarm-to-Forearm-to-Hand chain. Changing an UpperarmTwist helper can deform weighted skin, but cannot by hierarchy alone rotate the Forearm reference frame. The corresponding distinction applies to ForearmTwist and Hand.

| Asset anchor | Bone/index/parent |
| --- | --- |
| `josie.tscn:7230` | Spine02 index 25, parent Spine01 24 |
| `josie.tscn:7258` | L_Clavicle 29, parent Spine02 25 |
| `josie.tscn:7265` | L_Upperarm 30, parent L_Clavicle 29 |
| `josie.tscn:7272` | L_Forearm 31, parent L_Upperarm 30 |
| `josie.tscn:7300` | L_Hand 35, parent L_Forearm 31 |
| `josie.tscn:7412` | L_UpperarmTwist01 51, parent L_Upperarm 30; Twist02 52 follows 51 |
| `josie.tscn:7279` | L_ForearmTwist01 32, parent L_Forearm 31; Twist02 33 follows 32 |
| `josie.tscn:7293` | L_ElbowShareBone 34, parent L_Forearm 31 |
| `josie.tscn:7426` | R_Clavicle 53, parent Spine02 25 |
| `josie.tscn:7433` | R_Upperarm 54, parent R_Clavicle 53 |
| `josie.tscn:7454` | R_Forearm 57, parent R_Upperarm 54 |
| `josie.tscn:7482` | R_Hand 61, parent R_Forearm 57 |
| `josie.tscn:7440` | R_UpperarmTwist01 55, parent R_Upperarm 54; Twist02 56 follows 55 |
| `josie.tscn:7461` | R_ForearmTwist01 58, parent R_Forearm 57; Twist02 59 follows 58 |
| `josie.tscn:7475` | R_ElbowShareBone 60, parent R_Forearm 57 |

No separately named Scapula/Shoulder/Collar bone was found in the asset's bone-name list. The current Clavicle is therefore the available shoulder support link, not an explicit model of all sternoclavicular, acromioclavicular and scapulothoracic motion. A logical scapular support frame or an asset change would need a deliberate mapping decision; neither was implemented here.

The imported arm links are approximately longitudinal local **+Y**. The L/R rest bases differ; using the same Euler signs on both sides is not a calibrated anatomical convention. Use each side's actual rest and parent frames. Skin-weight influence, helper weighting and the role of ElbowShareBone still need direct inspection before treating a bone-space change as a complete skin-deformation fix.

## 2. Unarmed is an existing route through the shared body

The unarmed editor is not a second skeleton implementation. It supplies hand-oriented proxy targets to the same preview actor and `player_humanoid_rig.gd` body solver, while bypassing weapon grip acquisition where applicable. This makes it useful for isolating body behavior. It does **not** mean every armed and unarmed preparation branch is identical.

| Owner and anchor | Actual behavior |
| --- | --- |
| `runtime/combat/combat_animation_station_ui.gd:868`, `select_unarmed_authoring` | Selects the special unarmed WIP, applies opening configuration, refreshes preview, seeds drafts, retargets and realigns to the opening baseline. |
| UI `:4877`, `_get_or_create_unarmed_authoring_wip_clone` | Uses an existing unarmed clone or creates the special unarmed authoring item. |
| UI `:4887`, `_normalize_unarmed_authoring_wip` | Sets the unarmed equipment context, normal grip, no latest baked weapon profile and ensures station state. |
| UI `:4912`, `_normalize_weapon_open_config` | Accepts dominant L/R hand; unarmed forces two-hand use off. |
| UI `:1581`, `set_selected_motion_node_primary_hand_slot` | The unarmed route can change the primary hand; it bypasses the ordinary weapon's equipment-slot lock. |
| UI `:4541`, `_resolve_active_unarmed_geometry_seed_base` | Obtains a hand proxy seed; sets single-hand, zero authored roll and body-support blend 0. |
| UI `:9030`, `_hand_proxy_slot_uses_primary_motion_segment` | The primary unarmed hand uses the main motion segment. Other available hand proxies use their own stored segments. |
| UI `:8019`, `set_selected_motion_node_pommel_position` | Resolves and applies a translated motion segment, normalizes and passes through the ordinary motion-change/preview route. |
| UI `:1486`, `set_selected_motion_node_hand_proxy_segment` | Public setter for an available hand proxy's tip and pommel target pair. |
| `runtime/combat/combat_animation_station_preview_presenter.gd:5275`, `_build_unarmed_preview_node` | Creates `UnarmedHandProxy`, marked both `unarmed_hand_proxy` and `hand_authoring_proxy`; it has guide nodes rather than weapon geometry. |
| Preview presenter `:5295`, `_configure_hand_authoring_proxy_node` | Configures proxy-local tip, pommel, contact center and retained guide transforms. |
| Preview presenter `:9336`, `_resolve_unarmed_hand_proxy_points_state` | Builds proxy points from the hand frame; proxy half-length uses index-pinky distance times 1.5, clamped to 0.11-0.18 m. These are control dimensions, not anatomy limits. |
| Preview presenter `:6156`, `_apply_preview_upper_body_authoring_state` | Sends the common upper-body state to the actor. The payload includes primary/secondary targets, tip/pommel and L/R authored upperarm-roll values. |
| Preview presenter `:6243`, `_apply_hand_authoring_slot_proxy_preview_state` | Adds guidance for authored non-primary proxy slots. It skips the dominant unarmed slot because that is handled through the main segment. |
| Preview presenter `:3949`, `get_prepared_pose_capture_context` | Unarmed bypasses weapon grip readiness and uses the unarmed capture signature instead of the weapon anatomy packet. |
| Preview presenter `:5552` | Unarmed is a bypass condition for ordinary weapon grip acquisition. Shared body posing still applies. |

**Important:** unarmed `body_support_blend = 0` does not disable automatic torso/clavicle support. `player_rig_upper_body_pose_presenter.gd:75` supplies a base one-hand blend of 0.52, and `:220` combines it with the authored value.

### Existing test entry, for later reuse

`tools/verify_unarmed_proxy_translation_orientation_lock.gd:27` already opens the actual station scene with a FakePlayer and isolated library:

1. Create `PlayerForgeWipLibraryState`, give it a unique test save path, clear its saved WIPs and selection.
2. Instantiate `scenes/ui/combat_animation_station_ui.tscn`, then `open_for(fake_player, ...)`.
3. `select_unarmed_authoring(true)`; `select_skill_slot(&"skill_slot_1", true)`.
4. `reset_active_draft_to_baseline()`; select visible motion node 1.
5. Use public production setters, e.g. `set_selected_motion_node_pommel_position(target, false, true, true, true, true)`.

The existing verifier uses fixed frame waits and a fixed test-file path. A new diagnostic should use a unique output/library path, inspect actual readiness and record rejected edits separately. Do not mistake that existing small-translation test for a closed-loop/anatomy test.

Actor path below the viewport: `CombatAnimationPreviewRoot3D/PreviewActorPivot/PreviewActor`; skeleton: `JosieModel/Josie/Skeleton3D`. The root's `preview_held_item` metadata points to the unarmed proxy. Nothing requires loading the real saved weapon for this body-only investigation.

## 3. Live rotation writers and order

Primary owner: `runtime/player/player_humanoid_rig.gd` (abbreviated Rig below).

| Stage | Exact owner/anchor | Writes or influence |
| --- | --- | --- |
| Baseline | Rig `:6248`, `_apply_authoring_preview_baseline_pose` | Resets bone poses; samples the chosen/default animation at time 0, then stops it. |
| Reset transaction | Rig `:2387`, `reset_authoring_preview_baseline_pose` | Clears authoring state, applies baseline, publishes attachments/targets and caches helper neutral rotations. |
| Standard authoring frame | Rig `:2317`, `apply_authoring_preview_frame_now` | Automatic upper body, target updates, contact alignment, fingers, then skeleton modifiers. |
| Drag frame | Rig `:2331`, `apply_authoring_preview_drag_frame_now` | Same broad sequence, but one contact-alignment pass instead of the normal multiple passes. |
| Automatic torso/clavicle pose | Rig `:5941` delegates to `runtime/player/player_rig_upper_body_pose_presenter.gd:93` | Writes Waist/Spine01/Spine02, then L/R Clavicle. |
| Reach transaction | Rig `:2500`, `_apply_authoring_direct_arm_reach_pose` | Per side: usable-target projection; CCD; spline preference; shorter CCD reseat; manual elbow orbit; pure-Upperarm-swing reconstruction; final maximum elbow-angle correction. |
| CCD | Rig `:4541`, `_apply_ccd_arm_reach_pose`; `:5059`, `_rotate_bone_toward_end_target` | Incremental swings from the current posed basis: Forearm, Upperarm, Clavicle. The ordinary Forearm step invokes the signed branch guard; Upperarm/Clavicle steps do not share a calibrated shoulder envelope. |
| Spline preference | Rig `:4645`, `_apply_authoring_arm_spline_preference` | Guides the arm chain using current joint/contact geometry and a cubic preference, then reseats. |
| Manual elbow orbit | Rig `:4836`, `_apply_authoring_manual_upperarm_roll_pose` | Moves the elbow about the shoulder-to-hand axis, then reseats the forearm toward the held hand position. This is an elbow-location control, not simply an independent humeral axial-angle control. |
| Pure-swing authority | Rig `:4902`, `_enforce_authoring_upperarm_swing_authority` | Rebuilds the main Upperarm from its own rest frame in the current Clavicle frame, removing independent longitudinal roll; compensates the Forearm local basis to retain its prior global basis/hand endpoint. |
| Signed Forearm guard | Rig `:5123`, `_limit_authoring_forearm_extension_rotation` | Limits the proposed guarded step to the current signed bend branch between configured minimum and maximum. The incoming bend plane supplies the reference. |
| Wrist orientation | Rig `:2616`, `_apply_authoring_contact_wrist_basis_pose`, and per-slot method `:2641` | Desired hand basis, wrist constraints, twist-helper distribution, then hand-basis application. |
| Twist helpers | Rig `:4054`, `_apply_authoring_limb_twist_distribution_for_slot`; helper writes `:4268` | Uses wrist-orientation demand to distribute longitudinal twist among helper branches, relative to cached neutrals. |
| Precise alignment variant | Rig `:5804`, `_apply_authoring_precise_contact_alignment_for_slot` | Uses a larger CCD budget, spline/reseat and pure-swing authority. It is a separate call path, not literally the manual-elbow transaction above. |
| Runtime authoring overlay | Rig `:2361`, `process_combat_authoring_modifier_frame` | Uses the shared direct authoring/body machinery when that mode is active. |

Some table rows write several joints over several iterations. A correct endpoint does not establish that every intervening writer respected the same rotational reference.

## 4. Current numerical allowances and what they actually mean

These are existing code values, not recommended biological limits.

| Owner | Current values | Interpretation |
| --- | --- | --- |
| Rig `:221-224` | Shoulder 8-155 degrees; elbow 20-168 degrees | Geometric interior angles of chain segments. The shoulder metric is Clavicle-root to Upperarm to Forearm, not a complete GH elevation/plane/axial envelope. |
| Rig `:131-142` | CCD 12 iterations; end-target epsilon 0.006 m; Forearm/Upperarm/Clavicle weights .86/.74/.22; spline weights .14/.30/.50; reseat 2 iterations | Numerical solve budget and blending, not ROM. |
| Rig `:152` | Shoulder endpoint reseat epsilon 0.00005 m | Positional preservation threshold during pure-swing reconstruction; not a shoulder angular restriction. |
| Rig `:154-157` | Helper twist shares .78 Forearm/.22 Upperarm; total per-chain clamp +/-90 degrees; local +Y | Skin/helper distribution policy. Does not supply an actual Upperarm-to-Forearm parent rotation. |
| Rig `:207-213` | Body/contact/twist systems enabled; wrist straightness bias 0; optional contact wrist-twist limit 0 | These configuration switches are distinct from the editor's existing wrist-roll range. Do not interpret the optional zero value as zero wrist freedom. |
| Rig `:4877`, `:5019` | Manual elbow orbit -180 to +180 degrees | Absolute projected reference-angle request about shoulder-to-hand; value near zero bypasses manual correction and leaves automatic positioning active. Zero is therefore not identical to an explicitly enforced zero-degree orbit. |
| Upper-body presenter `:75-84` | Base support .52 one-hand/.74 two-hand; torso yaw 34/52, pitch 22/34; shoulder-driver yaw 62/78, pitch 38/52 degrees | One-/two-hand **driver clamps** before bone weights and blending. They are not final Clavicle joint limits, since other writers subsequently change Clavicle. |
| Upper-body presenter `:51-73`, `:446-466` | Torso direction/application weights; Clavicle yaw/pitch .46/.26; offside multiplier .45 in one-hand mode | Heuristic contribution weights. Upperarm/Forearm appear in the lookup tables but are not members of the actual torso/shoulder bone groups applied at `:152` and `:165`. |

The narrow signed Forearm guard now closes a demonstrated folded-side crossing route. It does not establish a material hinge reference, does not constrain every joint writer, and explicitly leaves an exactly collinear input without an invented incoming-side plane (`Rig:5144-5148`). Do not present it as a full inversion fix.

## 5. Reference-frame conflicts to resolve explicitly

| Topic | Current code/reference | Why it matters |
| --- | --- | --- |
| Neutral pose | Reset samples Idle at time 0 (`Rig:6248`); upper-body presenter caches Idle/2HandIdle at halfway through the animation (`:179-219`). | Both can be valid references, but they are not necessarily the same posture. A future anatomical calibration must state which one defines zero. |
| Main upperarm orientation | Pure swing from imported Upperarm rest, relative to the current Clavicle (`Rig:4931-4999`). | A historical implementation rule removes main humeral roll while compensating downstream orientation. Current user direction permits revisiting this rule if the anatomical model requires it. |
| Manual elbow orientation | Project actor +/-X onto the plane normal to shoulder-to-hand; fallback actor Y/Z (`Rig:5026`). | This is not the imported material hinge plane or a calibrated scapular coordinate system. The reference also changes with the arm direction. |
| Forearm guarded side | Current incoming bend normal (`Rig:5144`). | Preserves continuity of that particular step. An already reversed material frame is not corrected merely by preserving its incoming side. |
| Helper neutral | Cached posed helper rotations (`Rig:4326`), with +Y longitudinal axis. | Helpers cannot silently be treated as though they parent the elbow/hand. Their deformation and the main joint frame need a consistent relationship. |
| Torso/clavicle target | Actor-frame yaw/pitch; live Spine02 origin; current parent basis; partial slerp (`upper-body presenter:112`, `:329`). | Repeated evaluations are a settling process, not a direct absolute solve of every bone from one immutable anatomical reference. |

With a fixed shoulder support frame and wrist position, enforcing both a pure-swing main Upperarm and a strict material elbow hinge generally removes the continuous elbow-orbit freedom. Allowing shoulder support motion or main humeral axial orientation changes that constraint problem. This is a mechanical compatibility observation, not a directive to arbitrarily remove the user's elbow control or invent a new cone angle.

An Upperarm-local bend normal opposite its imported rest normal is useful evidence about the frame relationship. It is **not alone** a certificate that the entire rendered skin is anatomically inverted: helper deformation, calibrated neutral, pronation/supination and the upstream support frame must also be examined.

## 6. Movement history: hypotheses and future observations

The generic rotation step left-multiplies a minimal swing into the current basis (`Rig:5059`). Incremental direction-following can retain path-dependent orientation. The automatic torso/clavicle pass also partially blends from current rotations, and samples a live torso origin. Manual elbow zero falls back to automatic behavior. These are concrete **candidate sources of history dependence**, not proof that one of them alone causes the user's visual fault.

For later shared-body tests using Unarmed controls, distinguish these observations. The earlier exact triangular-return proposal has been withdrawn and is not a pass/fail requirement:

1. Return only the hand position: a different arm orientation may remain underdetermined. Do not declare failure from position equality alone.
2. Record complete authored and continuity state: primary hand, both proxy endpoints, axial/wrist roll or complete hand orientation, manual elbow preference, other-hand state, all body settings and the accepted target. Two endpoints alone specify an axis, not full hand orientation. Compare parent/rest/local/global bases for torso, Clavicle, Upperarm, Forearm, Hand and helpers to locate unexpected changes.
3. Exercise small edits, long movements and reversals. Observe stable, predictable control and validity; do not impose exact return orientation from the withdrawn triangle example.
4. Record attempted target, accepted target, rejection reason, drag pose, release pose and settled pose separately. A clearance rejection plus a re-solve must not be reported as an accepted movement silently flipping.
5. Separate joint coordinate changes from visible mesh deformation. Record bend-normal direction in the calibrated proximal frame and full quaternion/basis differences; one Euler component is insufficient.

Use L/R, raised and cross-body targets, extension/retraction, and explicit elbow preferences. Record the near-zero manual orbit case separately because it currently selects automatic behavior. Fixed frame delays are not evidence of identical settling/readiness. No new test was executed for this note.

## 7. Capture, prepared replay and the shared ownership seam

This is an integration map for the shared body correction. Unarmed isolates its initial tests; armed attachment, capture and replay remain consumers of the same rules, rather than separate anatomical implementations.

| Owner | Existing responsibility / consequence |
| --- | --- |
| `runtime/combat/combat_prepared_pose_capture.gd:91`, `capture_arm_constraints` | Captures shoulder/elbow limits, helper axis/limit/neutrals, chain bone names and usable reach from the actual actor. |
| Capture `:168`, `arm_constraints_context_data` | Builds context identity, omitting per-pose reference-up and quantizing selected data. A new anatomy rule/calibration needs deliberate cache identity/version coverage; source code changing alone does not establish invalidation. |
| `core/resolvers/combat_prepared_arm_frame_resolver.gd:15`, `resolve` | Four-bone analytical attachment correction: Clavicle, Upperarm, Forearm, Hand. It has no explicit scapular joint. |
| Prepared resolver `:199`, `_enforce_upperarm_swing` | Duplicates the main Upperarm pure-swing policy outside the live rig. Updating only the live helper leaves divergent authorities. |
| Prepared resolver `:227`, `_metrics`; `:242`, `_check_helpers` | Validates endpoint/orientation, unsigned shoulder/elbow magnitudes and helper limits. These checks do not constitute a complete anatomical hinge/envelope model. |
| Rig `:1541`, `realize_prepared_support_hand_frame` | Another live four-bone realization route; it also invokes pure-swing authority. Later shared rules must account for it. |
| Rig `:1734`, `capture_runtime_upper_body_pose_frame` | Captures stored local transforms for the selected bone set. The main capture list is at `:79`; it includes torso, arm chains, helpers and fingers, but not ElbowShareBone. |
| Rig `:1833`, `apply_runtime_solved_upper_body_pose_frame`; `:1875`, `process_runtime_solved_replay_modifier_frame`; `:2061`, `_apply_runtime_solved_upper_body_pose_values` | Applies already stored local position/rotation/scale. Applying data does not newly validate its anatomical meaning. |

Suggested future owner seam: a shared, value-only definition/calculation of the calibrated shoulder support and humeral frame, its accepted orientation and elbow relation. Live authoring and prepared arm correction should consume the same rule instead of adding unrelated final clamps. Skin helper distribution should be consistent with the resulting main bone frames. Existing controls, capture and playback must agree on the reference and on invalidation when the rule changes.

This suggestion is architectural groundwork. It does not select a solver algorithm, new bone hierarchy, anatomical angle table, performance budget or UI change.

## 8. Decisions and gaps before implementation

- **NEEDS_DECISION:** map the biological scapular support relationship onto the existing asset (logical frame, existing Clavicle approximation, or a separately approved asset change).
- **NEEDS_CALIBRATION:** define thorax, clavicle/support, humerus and forearm anatomical frames and neutral on each side. Do not equate imported local axes with clinical axes without calibration.
- **NEEDS_DECISION:** absolute-reference versus transported-reference behavior for each control, including manual elbow orbit at zero.
- **NEEDS_DECISION:** resolve the main-humerus versus helper-roll ownership openly. The historical pure-swing rule is not an anatomical law.
- **NEEDS_EVIDENCE:** determine skin/helper/ElbowShareBone weighting before claiming a visual fix.
- **NEEDS_EVIDENCE:** fresh shared-body tests through Unarmed controls, assessing usable/predictable manipulation with accepted/rejected paths and settled pose distinguished. No exact triangular-return criterion.
- **NEEDS_DESIGN:** posture-dependent shoulder allowances based on appropriate references, without pasting population-study means into hard limits.
- **NEEDS_INTEGRATION:** common capture/replay rule identity and equivalent live/prepared references once a correction is selected.

Do not resume grip-solving, restrict the elbow orbit arbitrarily or alter wrist limits merely because this mapping identifies candidate shoulder/reference conflicts. The user's later conditional allowance permits considering tolerances up to 3% where needed; define the measurement, reference and purpose before changing a threshold. Implementation remains on hold during comparison.

## Source fingerprints

SHA-256 of inspected working-tree owners (2026-10-28):

| Project-relative file | SHA-256 |
| --- | --- |
| `runtime/player/player_humanoid_rig.gd` | `3BFB3C6D47A492BBF640EC91DAE7F08074D5950521630BD52C632B4B8FCDA986` |
| `runtime/player/player_rig_upper_body_pose_presenter.gd` | `352DFE5C28B31895F707097CD5010C5BE2BA39F0AB09F5CE5C88FDE4CA46A07D` |
| `runtime/combat/combat_animation_station_ui.gd` | `A8D9CBED914B2B2A3D6279179FB9718428890C54B2ABF26F8CA548C646CBED9E` |
| `runtime/combat/combat_animation_station_preview_presenter.gd` | `0D73E43E7D46E5AF7683E1091E1748EFB0D9D7ACC3C478AB62810D9A60B7A0C4` |
| `core/resolvers/combat_prepared_arm_frame_resolver.gd` | `543E4DAE9435B3985B30C36A3CAFEE3B11725B8806583FB54D38063A1D4EF9DE` |
| `runtime/combat/combat_prepared_pose_capture.gd` | `AD9BBFF03BE9726A2742B32357FE2D98F3916E1C7F0C7F15B7A4D37D6693AA81` |
| `Josie/josie.tscn` | `8960AB5A544834CD136CD49BBF2EDB94521FEB5282D1A606DFAE866EA0ABBE5D` |
