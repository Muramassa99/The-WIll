# Shared arm material frame — bounded implementation, 2026-10-28

User-authorized BODY-01 slice following the external guide review. The material-frame correction is implemented. Focused and live comparison results are below; this is a bounded correction, not completion of BODY-01.

## Problem and boundary

Live and prepared arm paths rebuild main Upperarm as pure swing and compensate Forearm. That preserves the hand but strips the material hinge orientation required when the elbow plane changes. Sibling UpperarmTwist bones cannot provide the missing parent frame to Forearm.

Replace that conflicting authority with a shared value-only reconstruction. Retain existing reach, elbow-angle, wrist and body-clearance rules. This is not a complete anatomical shoulder envelope, a new IK implementation, a skinning-backend change, or an Unarmed-only rule. No blanket 3% margin is introduced. Do not claim a geometrically reconstructed plane proves every shoulder pose anatomically valid.

## Coordinate paper trail

- Calibration uses each side's immutable imported Forearm rest transform relative to Upperarm, plus Hand rest transform relative to Forearm. Their child offsets define the actual shaft and the imported bent-rest hinge. The imported rests are already included in captured layout/context.
- A model with collinear rest segments reports that explicit calibration is needed; no world-axis or first-current-pose fallback is invented.
- Live inputs are Skeleton3D-relative bone poses, whose ancestry resolves through Upperarm → Clavicle → Spine02 → … → RL_BoneRoot. Godot `global_pose` is skeleton-relative, not world-relative.
- Prepared inputs share the captured replay reference, with bone parent indices and parent-reference transforms preserving the same ancestry. The resolver uses vector differences in that one reference; no absolute position is treated as a direction.
- The desired Upperarm orientation is converted through the current Clavicle basis. Forearm is compensated relative to the new parent to preserve its prior reference orientation. Hand pose and finger locals remain unchanged. Segment positions/scales are not edited.
- Near straight/folded geometry, the currently posed calibrated material hinge supplies continuity; this state is already in captured bone rotations. No external temporal cache.
- The same operation must follow solved-pose interpolation at the shared rig writer, covering F, entry and equipped playback. Derived capture/cache identity must change so old pure-swing semantics do not silently certify new data.

## Selected owners

- New `core/resolvers/combat_arm_hinge_frame_resolver.gd`: shared calibration/reconstruction math.
- `runtime/player/player_humanoid_rig.gd`: replace existing swing authority and normalize shared solved-pose application. Keep public names and authored controls.
- `core/resolvers/combat_prepared_arm_frame_resolver.gd`: same correction including early acceptance.
- Captured-pose and runtime-cache version owners: stale derived-data invalidation; preserve authored node controls.
- New focused material-frame verifier and retained Unarmed diagnostic. Root runs Godot serially; helpers do not launch engines.

## Targeted evidence plan

1. Isolated actual Unarmed SC: both arms, extend → retract → hold → 15–60° elbow changes, level/elevated targets. Record before/after with identical requests, including rejections and complete arm/helper transforms.
2. Shared-frame invariants: real rig sides, idempotence, retained elbow/wrist/Hand orientation, moved/rotated/scaled actor origins, degenerate-calibration rejection.
3. Solved/captured and interpolated playback use the same frame; no finger solve or expensive per-frame search is added.
4. Rendered inspection of representative held-arm states. Separate bone-frame evidence from skin quality and remaining shoulder-range questions.

Source snapshot: `godot_runs/sc_arm_material_frame_20261028/before_sources`. Existing dirty work and prior narrow folded-limit fix are preserved. No real saved weapon/skill is needed for the Unarmed fixture.

## Test fixture correction and user steering

The initial Unarmed attempt could not reach a current recorded baseline. Its Reset branch does not publish the weapon baseline metadata the fixture first expected, and the observed pose was also not current/valid. Capture repeatedly queried absent handle metadata. The user explicitly redirected testing to the established weapon fixture rather than solving unrelated Unarmed gaps here, and reaffirmed that Unarmed must not require weapon checks at all.

Retain `godot_runs/sc_arm_material_frame_20261028/before` as failed setup evidence, not a body test. The new Unarmed diagnostic is unfinished; its unsupported `%g` formatting was corrected, but its readiness contract still needs work. Do not use it as a passing verifier. A code review additionally found that capture currently writes `attachment_required=true` even for Unarmed; this needs a separate lifecycle correction, not an anatomical workaround.

The active comparison uses isolated copies of `Broken_Balde_v1`, Skill 2, the existing R-L-R fixture, 20° elevation, 0.15 outward pull factor and held pointer increments +15, -25, +35, -45, +60, -60°. First R is warmup. The source library is untouched. The same gesture rules are used before/after; because setup is derived from accepted poses, actual requested coordinates are compared and any differences will be reported.

## Implemented result and evidence

- The shared resolver calibrates from actual imported child offsets rather than assumed +Y. Live and prepared owners replace pure-swing stripping with the same Upperarm/Forearm rotation transaction.
- The shared solved-pose writer normalizes complete successfully applied arms after fractional sampling. Partial/truncated/invalid channel writes do not gain authority over the rest of an arm.
- Preparation normalizes all complete captured body arms after attachment following, including the free arm and release spans. Entry normalizes its prefix samples too. This stores the same policy that F/equipped application consumes. There is no additional grip acquisition or numerical IK search in this operation.
- Prepared-pose schema3, runtime cache `runtime_cache_v14_material_hinge_frame`, and captured `material_hinge_revision` invalidate old derived semantics. Cold-entry compatibility checks include the revision. Existing authored controls are preserved; old derived endpoints/tracks need fresh preparation.
- No joint ranges, wrist limits, contact allowances, node timing, finger solving, skin weights or helper-local distribution percentages changed.

Initial focused verifier:313/313 passed in `godot_runs/sc_arm_material_frame_20261028/checks/report.json`. It exercises real imported sides, world/root rotation and scale, retained elbow/wrist/Hand transforms, idempotence, prepared/live equivalence, actual shared replay writers and partial-payload boundaries. Later stored-track/entry coverage is recorded in the final SPS.

Final expanded verifier:347/347 passed in `checks_final/report.json`, including actual `TrackBuilder.build`, actual `Entry.build`, complete/free-arm normalization, input immutability, idempotence, and agreement between stored rotations and the final rig writer. Fixtures use real imported bone geometry with synthetic motion endpoints; they are not a full player-library F/Save/equip test. Numeric engine calibration arrays are included in this report to avoid offline matrix-layout ambiguity.

Red-node feedback:26/26 passed in `node_feedback_final/report.json`. The first rerun failed because its synthetic attachment fixture declared a Forearm hierarchy inconsistent with its pose parents and had identity rests. The fixture was corrected to a serial chain with a bent rest; production validation was not relaxed. All26 original feedback assertions and the intended interior `prepared_slide_missing_authored_seat` failure are retained.

Existing incoming-bend guard:132/132 passed in `guards/report.json`; the previous signed folded-limit correction remains intact.

Live weapon baseline (`weapon_before`) completed54 samples: L and second R27 each. Initial R warmup failed setup acquisition and is excluded. Updated run (`weapon_after`) completed81 samples, including warmup. Compare L and second R only. Final releases were accepted; authored Tip/Pommel drift during the six held elbow adjustments was exactly zero in both runs. Requested path differences reached4.86mm L and2.02mm R because the fixture derives targets from accepted poses; this is a matched gesture comparison, not bit-identical target replay.

Corrected material-frame comparison:

| Worst geometric-bend/material-hinge disagreement | Before | After |
| --- | ---: | ---: |
| Left measured run |148.47°|0.0636°|
| Second right run |67.07°|0.0204°|

Authority: `before_after_material_analysis_corrected.json` and its raw JSONL source. **Earlier `weapon_before_material_analysis.json` and `before_after_material_analysis.json` are superseded:** the offline TSCN parser originally interpreted serialized basis scalars in the wrong row/column order. The corrected interpretation agrees with Godot's calibration. Initial chat numbers derived from that parser are not final evidence. The erroneous comparison did not prompt production changes.

Original Compatibility-renderer diagnostic images are too dark for skin judgement. `static_arm_views` replays11 recorded torso/arm/helper global transforms on the actual Josie skin with grey material and normal Forward+ lighting, using identical before/after cameras. This is a static arm-region reconstruction, **not live grip/F/equipped playback**; fingers and the unmeasured body remain at rest. The inspected left bent-elbow surface improves; right forearm/wrist narrowing remains visible. No universal skin-quality or anatomical certification follows from aligned material frames.

Real source library SHA256 remained `7834B54752FDAE638CC894D989A76BC04D6D9F1790B90D9032928473626DC7D2` and matches the isolated source copy. No real skill save, Git index/history change or push in this pass.

## Remaining scope

- User hand-testing of live body behavior; broader posture-dependent shoulder limits and helper/skin deformation remain BODY-01. The geometric reconstruction is not proof every resulting shoulder orientation is anatomically legal.
- Larger movement changes still occur. The after-run left arm has a50.47° elbow-radial change during one finite pull step and22.87° on retraction release (before7.49°). The after-run second right arm goes from124.36° interior bend while held to82.17° during the first15° elbow-control step. The preceding four right pull rows contain right-forearm clearance blocks in both runs. These need a separate accepted/rejected-pose and control-authority investigation; do not call all discontinuities fixed.
- Zero held endpoint drift means **authored Tip/Pommel values**, not perfect physical contact. Maximum observed grip-alignment residual during held elbow adjustment was5.93mm L/10.20mm R2 after versus4.02mm/10.86mm before. Final elbow releases were accepted, with radial changes1.43° L/1.59° R2. The run readiness state is not an independent full-hand contact certificate.
- No complete new normal/reverse/two-hand full Save→reopen→equipped acceptance matrix. Shared replay/entry integration receives targeted value/rig tests, not a claim that every weapon pose works.
- The original F/Save `elbow_range_has_no_circle_solution` is not independently declared fixed. Reach/clearance rejections remain possible; red offending-node feedback is retained.
- Unarmed must remove weapon-only preparation/attachment requirements in a separate scoped lifecycle pass, then the unfinished Unarmed diagnostic can be repaired and reused.

## Planned Unarmed lifecycle clarification

User clarification after the implementation pass, 2026-10-28. **TODO only; no immediate code changes.** Consolidated under SC-11 in Project TODO.

- No equipped weapon means the character uses Unarmed skills as the runtime fallback. Equipping a weapon selects its skill set; removing it restores Unarmed. Unarmed is presently body poses/motion expressed as skills, with a dedicated combat-archetype expansion left for later.
- The Unarmed editor must operate without weapon assets, grip acquisition, handle metadata, weapon seating or hand-to-weapon attachment validation. These prerequisites must be absent from Unarmed opening, Reset, R recording, F preparation/replay and Save. A presentation/control proxy must not become a required physical weapon or introduce weapon validation.
- Continue using shared body controls, appropriate body/reach rules, motion-node recording, timing, transitions and saved playback. Do not remove body validation merely because there is no weapon, and do not fork the whole skill system for Unarmed.
- Future acceptance: create and reset an Unarmed skill, record multiple nodes, use F, save/reopen and trigger it in the world with no weapon equipped. Confirm weapon-only work is not invoked, then check that equip/unequip selects the appropriate skill set.

The earlier failed Unarmed fixture and the unconditional `attachment_required=true` observation are starting evidence for that future pass. They do not authorize implementation now or prove the complete cause of every Unarmed failure.

## Read-only Skill 1 wrist investigation — 2026-10-29

User likes the preceding correction and requested inspection of unchanged `Broken_Balde_v1`, Skill 1, visible node 1 → node 2 after Tip manipulation. Subsequent direction explicitly excludes torso/spine work. The current focus is **forearm–Hand axial indexing**, not a new elbow, torso or debug-display fix. Debug visualizations are known detached/stale and were not used as evidence. No production change or saved-skill edit was made in this investigation.

### Clarified intended joint rule

- Forearm owns axial roll within its permitted limits; Hand inherits that roll.
- Hand contributes its permitted tilt. It must not independently roll relative to Forearm at the wrist junction.
- Holding tilt constant, 30 degrees of Forearm roll therefore carries Hand by the same 30 degrees. Additional relative wrist roll is zero, measured against the rig's calibrated neutral alignment, not by zeroing all Hand rotation channels.
- The symptom in this skill is the forearm turning underneath the comparatively steady hand, pinching/twisting their junction. Describing only the relative angle without identifying that visible behavior was insufficient.
- This is recorded intent for a focused correction; the present request remains investigation, not implementation.

### Fresh saved-data and mesh evidence

Evidence folder: `C:/WORKSPACE/godot_runs/sc_skill1_tip_pivot_20261029`.

`read_skill1.gd` directly loads the real library through ResourceLoader without calling library mutation, normalization, Reset, acquisition, preparation or Save. It records all authored nodes, complete prepared poses, forward kinematics and existing cached playback. Source SHA256 before/after is `839c5d18b28903f94d5a83b1f3349567d49d50807bd0621168d8cfb2c123a6df`. Two visible nodes, both current valid captures; right-hand normal grip, one hand, unchanged authored grip percentage. Saved playback is 2 seconds at 60 Hz, 121 inclusive samples.

`wrist_analysis.json` records:

| Measurement | Node 1 | Node 2 |
| --- | ---: | ---: |
| Current resolver's Hand-versus-Forearm axial-twist metric | 7.9357 degrees | 68.6491 degrees |
| ForearmTwist01 relative to captured cached neutral | -45.0000 degrees | -45.0000 degrees |
| ForearmTwist02 relative to captured cached neutral | -45.0000 degrees | -45.0000 degrees |
| Combined forearm helper twist | -90.0000 degrees | -90.0000 degrees |
| Captured contact-wrist twist limit setting | 0 degrees | 0 degrees |

Helper neutrals are identical. Thus unchanged helper locals are **saturated**, not proof that distribution was skipped. Local helper rotation is distinct from world orientation inherited from Forearm. The saved clip's Hand and helper endpoints match the node captures exactly; F is not inventing a new endpoint wrist pose.

`render_skill1_wrist.gd` applies all 50 saved playback bone channels to the real Josie skin, including the saved fingers, with neutral material and identical cameras across frames 0/60/120. `wrist_images.json` names six images. Inspected images show the forearm turning relative to the hand and the junction narrowing/pinching. This is a static reconstruction of saved samples, with no debug overlay and no weapon rendered; it is not a fresh interactive F lifecycle test or an isolated skin-weight diagnosis. The source library remains unchanged.

### Current ownership conflict

- `player_humanoid_rig.gd:_apply_authoring_contact_wrist_basis_for_slot` independently derives Hand orientation from the acquired hand/weapon frame, distributes helper twist, clamps, and writes Hand basis.
- Helpers form Forearm → ForearmTwist01 → ForearmTwist02, while Hand is a direct child of Forearm. Helper skin deformation therefore does not mechanically carry Hand. The current distribution is a deformation treatment, not an enforced joint-indexing relationship.
- `_clamp_authoring_contact_wrist_twist` computes a clamped orientation but then rebuilds it to restore the locked index–pinky contact axis. A zero configured scalar limit is not proof that the final applied Hand/Forearm relationship has zero axial roll; the saved values above demonstrate that it does not.
- Explicit wrist-roll manipulation has another Hand-only writer (`apply_authoring_wrist_roll_pose`); the user used Tip for this reproduction, so this path is surrounding ownership context, not the proven trigger here.
- Prepared-arm following preserves the sampled wrist relationship. Its helper checks verify per-bone limits, not correspondence between helper deformation and Hand twist. Stored/replayed channels therefore retain the existing mismatch rather than enforce the newly clarified zero-relative-roll rule.
- Helper branch continuity may choose a full-turn-equivalent negative request before applying caps. Captured helper values are consistent with that saturation. Do not label unchanged helpers stale, bypassed or incorrectly calibrated without a stage trace.

The initial wider investigation also found distinct Tip-authoring/playback pivot policies and a body-forward/yaw convention conflict. Those observations remain in the raw report/code trace; **torso/spine investigation and changes are explicitly parked by the user**. Do not let them replace this wrist-junction scope or use the broken debug overlay to validate a future fix.

## Forearm–Hand indexing implementation — 2026-10-29

This section supersedes the investigation-only status above. The user authorized the narrow correction and answered the range decision: **“Stop at the existing forearm limit.”** Hand requests axial movement; forearm skin follows that movement within the existing forearm budget. Existing Hand tilt remains. Upperarm/elbow behavior and torso/spine work are outside this correction.

### Ownership and implementation

- `combat_forearm_hand_index_resolver.gd` is the shared value calculation. Inputs are actual Forearm/Hand frames, imported local rest bases and captured neutral helper rotations. The forearm shaft is the actual Forearm-to-Hand vector. No arbitrary world axis or neutral inferred from a currently twisted pose is introduced.
- This rig has a serial ForearmTwist01 → ForearmTwist02 skin branch, with Hand as a separate child of Forearm. Aligning only the main Forearm bone would also alter its elbow-related children. The correction therefore makes the two skin helpers follow the accepted Hand axial rotation while preserving all main arm bones, Hand, fingers, positions and scales. The local rest mapping calibrates the distal material frame to Hand; the remaining relative movement is Hand swing/tilt.
- The existing total forearm allowance is ±90 degrees, with ±45 degrees per helper. These values and the existing numerical epsilon are unchanged. The separate 240-degree wrist/weapon-orbit control is not the same axial measurement and was not widened.
- Stable captured neutral helper rotations now also define the explicit wrist control reference. Current animated helper rotations cannot recenter that allowed window after each movement.
- Live contact alignment, explicit wrist-roll input, support-hand realization, prepared-pose normalization and the shared final replay writer use the same calculation. No extra finger acquisition or iterative IK solve was added.
- Tip/Pommel direct edits and throttled drag updates now treat the candidate as one transaction. If the forearm range fails, the previous accepted node/body/weapon/grip state is restored. A coarse pointer jump retains the last accepted position; it does not force a new pose exactly onto the cap. The programmatic `refresh_preview=false` setters retain their existing value-only contract.
- The same-frame motion checkpoint can preserve an acquisition already running, provided job identity, queue/state guards and process/physics frame still match. It does not clone, cancel or rewind a running job. Existing idle render checkpoints retain their stricter requirements.
- Prepared capture adds `forearm_hand_index_revision=forearm_hand_index_v1`; derived runtime cache becomes `runtime_cache_v15_forearm_hand_index`. Original authored controls remain intact. Old derived tracks require preparation under the new policy.
- ChainPlayer extracts existing saved bone names, rest transforms and arm constraints once per clip. SC, entry/snapshot restore and equipped skill/idle playback forward this calibration to the same rig writer. Playback does not need an editor-open side effect or mutate authoring neutral caches. Missing/incompatible calibration and over-limit poses reject atomically; the previous accepted rig state remains. A rejected solved body cannot fall through into legacy live weapon/grip solving.

### Fresh evidence

Evidence root: `C:/WORKSPACE/godot_runs/sc_skill1_wrist_index_20261029`.

- `report.json` is the initial immutable saved-pose prototype: both real Skill 1 endpoints and its middle saved frame normalize within the existing caps, with zero changes to non-helper channels. Node 2's Hand-versus-distal-material axial discrepancy falls from about159.503 degrees to approximately0.000072 degrees. This is relative axial indexing, not a claim that every wrist tilt is anatomically correct.
- `render_candidate.gd` and `wrist_frame_*_view_*.png` render the actual skin from all50 saved channels, changing only the two right forearm helpers. Same cameras as the earlier saved-pose render; no debug overlay. The inspected wrist junction improves. Proximal forearm/elbow skin quality is not universally certified. These are static reconstructed poses, not live F screenshots.
- `live_final/manifest.json`: actual Skill Crafter control methods against an isolated weapon copy, both R and L. Each side passes21 checks: busy-acquisition checkpoint guards, explicit over-limit restoration, Tip numerical edits, Tip drag-controller requests/release and small Pommel numerical edits. Real Tip drag attempts exceeding the forearm cap are rejected; later valid movement is accepted. No source save. This uses real controller code with injected targets, not OS mouse replay or an independent full-hand contact certificate.
- `f_first/manifest.json`: actual F preparation and completed replay of the existing isolated Skill 1, without Reset or authored control changes. Calibration present,53 observed playing updates, zero final-writer rejections, status `Preview finished.` Preparation measured23.720 seconds in this cold/rebuild run. This is not a performance improvement claim; timing optimization is outside this pass.
- The focused real-rig verifier covers L/R limits, tilt, fixed Hand/main-bone channels, repeated application, transformed/scaled references, prepared/live agreement, partial payload authority, cold saved calibration, immutable inputs, and atomic rejection of over-limit/mismatched-rest/missing-calibration payloads. It also reads all121 original saved Skill 1 samples; all121 normalize successfully without editing the source.
- Cold replay's first added position assertion compared against the pre-finalizer pose. A/B measurements isolate existing hinge-only displacement of0.03517mm R and0.01772mm L in world space; adding indexing changes Hand position by exactly zero relative to that existing finalizer. The wrist test therefore compares its added effect against the hinge-only output, preserving strict indexing tolerance. No elbow production adjustment or relaxed indexing tolerance was made to satisfy it.

Original source library SHA256 remains `839C5D18B28903F94D5A83B1F3349567D49D50807BD0621168D8CFB2C123A6DF`. No original Skill 1 mutation, Git staging, commit or push in this pass.

### Remaining verification boundary

Manual judgement of the same node1-to-node2 Tip motion is the next useful check. This correction does not repair the detached debug overlay, change torso/spine control, solve all skin deformation, or certify every normal/reverse/two-hand posture. Equipped playback has shared rig/calibration checks; a complete new Save→reopen→world activation matrix has not been run in this pass. Keep those limits separate from the passing actual F and live control tests above.

## Semantic wrist mechanism — 2026-10-29, implementation awaiting user testing

**This supersedes the helper-only wrist policy and its verification status above.** The user rejected a cosmetic alignment correction and authorized adapting `Reserch/The Will Wrist and Hand Forearm Implementation Guide.md`. Latest instruction: implement; the user will test; do not spend this pass on engine runs or testing. The earlier blue/green/orange sketch is not the implementation authority. Existing shoulder/elbow material-frame behavior and torso/spine are outside this replacement.

### Mechanical contract now implemented

- A shared pure resolver owns three explicit values: forearm pronation/supination `rho`, wrist extension/flexion `beta`, and radial/ulnar deviation `gamma`. Hand orientation is composed from these values; no additional wrist axial-spin freedom is accepted.
- The immutable Josie wrist profile starts with the guide's engineering defaults: forearm roll ±90°, flexion65°, extension60°, ulnar30°, radial15°. Wrist bends share the asymmetric elliptical envelope, rather than each reaching its maximum independently. Orientation matching retains ±0.025° numerical allowance; no blanket3% expansion was introduced.
- The rig adapter calibrates anatomical Hand +Y from wrist to Middle1, dorsal direction from the palm landmarks and existing finger-closing rules, and radial sign from thumb-side evidence. Imported rest transforms and actual parents trace those references through `RL_BoneRoot`. World direction and an arbitrarily posed Hand cannot redefine zero.
- Requested Hand orientation is fitted to this bounded model. A fitting failure reports `wrist_motion_range` or a specific calibration reason. The legal approximate candidate is diagnostic, not permission to detach the Hand from a rigid weapon relationship. No upstream shoulder/spine compensation was added.
- ForearmTwist01/02 receive half/full cumulative **accepted rho**, using imported-rest zero. They no longer infer roll from generic swing/twist of a bent Hand. Upperarm helper behavior remains under its previous owner. Live capture, prepared following and final playback use the same forearm zero.
- Existing Tip/Pommel candidate rollback and explicit wrist-control rejection use the shared check. Support-hand following checks the accepted Hand basis before grip residual acceptance. Its former generic wrist-twist-change gate is diagnostic for the new semantic model; positional, orientation, shoulder and elbow checks remain.
- The separate weapon-only roll cube remains weapon-only. This pass does not make it drive body roll or replace grip acquisition.

### Owners and stored data

- Definition/profile: `core/defs/wrist_motion_profile_def.gd`, `core/defs/characters/josie/wrist_motion_profile.tres`.
- Value owners: `core/resolvers/combat_wrist_motion_resolver.gd` and the now deformation-only `combat_forearm_hand_index_resolver.gd`.
- Imported-rest adapter and live/final writers: `runtime/player/combat_wrist_rig_calibration.gd`, `player_humanoid_rig.gd`.
- Captures store fixed wrist calibration/profile in arm constraints and separate per-pose `{rho,beta,gamma}` states. Dynamic states are not part of the fixed context identity.
- Prepared-arm following and normalization apply the accepted Hand basis and helper rotations, then check contact residuals. Shared F/entry/equipped writers use the saved compatible calibration; both arms are accepted before committing their wrist/helper results.
- Prepared-pose schema is4; runtime cache is `runtime_cache_v16_semantic_wrist_motion`. Existing authored controls remain. Old derived captures/tracks require fresh preparation and are not silently certified under the new law.
- Cold entry can recover semantic state from the actual incoming pose and matching saved calibration without substituting a destination pose or acquiring a grip. It still rejects an incompatible or mechanically invalid incoming pose.

### Verification and explicit limits

No game run, parser run, test suite or visual certification was performed for this implementation, at the user's request. Static code review and whitespace checks are the only checks for this new policy. Earlier passing helper-only tests and F timings are historical and **do not validate this replacement**. The old helper-only verifier contract now reports that the semantic wrist model is required; its previous pass counts must not be reused.

Current motion paths retain the existing sampling/attachment-following pipeline and are checked against the new model at application. This pass does not introduce semantic scalar animation tracks or automatically find a different trajectory when the existing interpolation leaves the legal wrist region. Such an interval can reject preparation/playback despite legal endpoints. This is a known integration boundary for manual testing, not evidence that every transition works.

Next manual focus: the unchanged Skill1 node1-to-node2 Tip movement, then ordinary Tip/Pommel and wrist-roll adjustments on each hand. Observe actual skin/bones, not the detached debug overlay. F and a fresh Save/reopen/equipped use need user verification under the new revision. Leave torso/spine, broad range retuning, performance optimization and Unarmed lifecycle out of this pass.

The original player-library file and authored Skill1 were not edited by this implementation. No Git index/history changes or push were performed.

## Tip control pivot at the primary grip — 2026-10-29

Subsequent user instruction: replace Pommel as the fixed Tip-manipulation pivot
with the weapon center at the gripping station associated with the index-pinky
midpoint. This removes the large grip-position arc caused by rotating a held
weapon about its distant Pommel, particularly with long handles.

Implemented in `combat_animation_weapon_frame_solver.gd`,
`combat_animation_station_preview_presenter.gd` and
`combat_animation_station_ui.gd`:

- Armed, in-hand Tip dragging and numeric Tip edits use the primary selected
  Handle slice center, including its grip percentage, axial adjustment and
  existing hand/end bounds. This is the weapon's grip-center reference, not its
  overall midpoint, the wrist bone, or an assumed world origin. The existing
  normal/reverse orientation and dominant-hand selection supply the frame.
- A rigid rotation takes the current grip-to-Tip direction toward the requested
  direction while fixing that grip center. Both Tip and Pommel move through the
  same rotation; weapon length and relative geometry remain fixed. The full
  orientation is re-encoded with the existing weapon-frame encoder, avoiding an
  independent unintended axial roll. The numerical Roll channel is retained.
- Each calculation uses the supplied motion-node/display baseline, not a fresh
  moving hand reference during throttled mouse updates. Inputs are explicitly
  WeaponRoot landmarks and TrajectoryAuthoringOrigin endpoints, converted through
  the existing world/trajectory transform chain. A half-turn uses the weapon's
  own up reference to choose its otherwise ambiguous turn axis.
- Numeric endpoint-authority checks may reject a movement, but cannot silently
  translate this fixed pivot to satisfy the reach volume. Existing body/arm/wrist
  acceptance and drag rollback remain. Missing Handle station or degenerate
  pivot returns an explicit failure; no hidden Pommel fallback for armed Tip.
- The Tip orbit sphere now uses the same grip center and grip-to-Tip radius.
  The on-screen helper text describes the new behavior.
- Pommel continues to translate the whole weapon. Two-handed usage pivots about
  the primary grip; support follows under its existing rules. Unarmed hand proxies
  and noncombat stow controls retain their separate placement behavior.

Existing authored nodes/saves are not rewritten. Newly edited endpoints and
orientation flow into the current R/F/Save pipeline; this does not add a new
playback path representation. The old skill's stored Pommel-fixed motion will
not turn into a new grip-pivot motion until the user edits it.

This change does not disable automatic torso following or promise a stationary
body: body direction response, wrist-center offset from the Handle slice, and
joint/reach limits still participate. Those are separate from the removed
Pommel lever effect. It also does not add a fixed-pivot interpolation constraint
between separately authored nodes.

Verification: static code review and whitespace checks only. No game, parser,
test suite or source-player-library writes, following the user's testing policy.
Manual check: from a settled grip, move Tip and observe Pommel rotate while the
selected Handle station remains the authored pivot; then confirm Pommel still
translates the complete weapon. Include a long handle and either hand when useful.

Native reference consulted:
[Godot4.7 Transform3D](https://docs.godotengine.org/en/4.7/classes/class_transform3d.html).
No Git stage/commit/push was performed.
